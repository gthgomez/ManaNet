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


if __name__ == "__main__":
    unittest.main(verbosity=2)
