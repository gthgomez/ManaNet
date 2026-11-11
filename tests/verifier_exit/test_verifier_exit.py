#!/usr/bin/env python3
"""Exit-status contract tests for the ManaNet verifier (MN01).

Runs tools/verify_game.py through its contract and asserts exit statuses.
Runnable standalone (`python tests/verifier_exit/test_verifier_exit.py`)
or under pytest. Requires a Godot 4.6.2 engine via GODOT_BIN or PATH;
otherwise the engine-availability cases report a clear setup failure.

Contract under test:
  1. Clean audit exits 0.
  2. Injected failure (--negative-control) exits nonzero (1).
  3. Missing engine exits 2 (never 0).
"""

import os
import subprocess
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WRAPPER = os.path.join(REPO_ROOT, "tools", "verify_game.py")


def run_wrapper(args, extra_env=None):
    env = dict(os.environ)
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        [sys.executable, WRAPPER] + args,
        cwd=REPO_ROOT, env=env,
        capture_output=True, text=True, timeout=900,
    )


def engine_available():
    probe = run_wrapper(["--allow-engine-mismatch", "--raw", "--version"])
    return probe.returncode == 0


class TestVerifierExit(unittest.TestCase):

    def test_missing_engine_exits_nonzero(self):
        """With GODOT_BIN pointing nowhere, the wrapper must fail (exit 2), not pass."""
        r = run_wrapper([], extra_env={"GODOT_BIN": os.path.join(REPO_ROOT, "does-not-exist")})
        self.assertEqual(r.returncode, 2)
        self.assertIn("not found", r.stderr)

    @unittest.skipUnless(engine_available(), "Godot 4.6.2 engine not available (GODOT_BIN/PATH)")
    def test_clean_suite_exits_zero(self):
        r = run_wrapper([])
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)
        self.assertIn("PASS full audit", r.stdout)

    @unittest.skipUnless(engine_available(), "Godot 4.6.2 engine not available (GODOT_BIN/PATH)")
    def test_injected_failure_exits_one(self):
        """Negative control: printed FAIL summary must be backed by exit 1."""
        r = run_wrapper(["--negative-control"])
        self.assertEqual(r.returncode, 1, msg=r.stdout + r.stderr)
        self.assertIn("[FAIL] DELIBERATE injected failure", r.stdout)
        self.assertIn("PASS negative control", r.stdout)


class TestParseGateClassification(unittest.TestCase):
    """Negative controls for the import gate. No engine required."""

    def setUp(self):
        sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
        global verify_game
        import verify_game as verify_mod
        self.mod = verify_mod

    def test_clean_exit_passes(self):
        code, msg = self.mod.classify_import_result(0, "Godot Engine\nImport done\n")
        self.assertEqual(code, 0)
        self.assertIsNone(msg)

    def test_nonzero_with_fatal_text_fails(self):
        code, msg = self.mod.classify_import_result(1, "Parse Error: bad.gd\n")
        self.assertNotEqual(code, 0)
        self.assertIn("exited", msg)

    def test_nonzero_silent_fails(self):
        code, msg = self.mod.classify_import_result(7, "")
        self.assertEqual(code, 7)
        self.assertIn("no diagnostic text", msg)

    def test_zero_with_script_error_fails(self):
        code, msg = self.mod.classify_import_result(0, "SCRIPT ERROR: boom\n")
        self.assertEqual(code, 1)
        self.assertIn("despite exit 0", msg)

    def test_timeout_fails(self):
        code, msg = self.mod.classify_import_result(None, "", timed_out=True)
        self.assertEqual(code, 2)
        self.assertIn("timed out", msg)

    def test_launch_failure(self):
        code, msg = self.mod.classify_import_result(None, "", launch_error="not found")
        self.assertEqual(code, 2)
        self.assertIn("failed to start", msg)

    def test_fake_process_modes(self):
        import stat
        import tempfile
        fake = os.path.join(tempfile.mkdtemp(), "fake-godot")
        with open(fake, "w", encoding="utf-8") as handle:
            handle.write(
                "#!/usr/bin/env python3\n"
                "import os, sys, time\n"
                "mode = os.environ.get('FAKE_GODOT_MODE', 'clean')\n"
                "if mode == 'clean':\n"
                "    sys.exit(0)\n"
                "if mode == 'fatal':\n"
                "    sys.stderr.write('Parse Error: boom\\n')\n"
                "    sys.exit(1)\n"
                "if mode == 'silent':\n"
                "    sys.exit(7)\n"
                "if mode == 'script-zero':\n"
                "    sys.stdout.write('SCRIPT ERROR: boom\\n')\n"
                "    sys.exit(0)\n"
                "if mode == 'timeout':\n"
                "    time.sleep(30)\n"
                "sys.exit(0)\n"
            )
        os.chmod(fake, os.stat(fake).st_mode | stat.S_IEXEC)
        cases = [
            ("clean", 0),
            ("fatal", 1),
            ("silent", 7),
            ("script-zero", 1),
        ]
        for mode, expected in cases:
            env = dict(os.environ)
            env["FAKE_GODOT_MODE"] = mode
            code, _msg = self.mod.run_parse_gate(fake, env=env, timeout=5)
            self.assertEqual(code, expected, mode)
        env = dict(os.environ)
        env["FAKE_GODOT_MODE"] = "timeout"
        code, msg = self.mod.run_parse_gate(fake, env=env, timeout=1)
        self.assertEqual(code, 2, msg)
        code, msg = self.mod.run_parse_gate(os.path.join(tempfile.mkdtemp(), "missing-godot"))
        self.assertEqual(code, 2)
        self.assertIn("failed to start", msg)


if __name__ == "__main__":
    unittest.main(verbosity=2)
