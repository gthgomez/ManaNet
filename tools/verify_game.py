#!/usr/bin/env python3
"""Portable verifier wrapper for ManaNet (Godot 4.6.2).

Resolves the engine without any hard-coded workstation paths:
  1. GODOT_BIN environment variable (path to a Godot 4.6.2 executable), or
  2. `godot` / `godot4` found on PATH.

All project paths are repository-relative (anchored at this script's
parent directory), so the checkout can live anywhere, including paths
with spaces.

Exit status contract (never rely on stdout text):
  0  all checks passed (or clean quit smoke test)
  1  the engine/audit itself failed (propagated verbatim)
  2  setup error: engine not found, wrong engine version, or timeout

Usage:
  python tools/verify_game.py                    # full audit, must exit 0
  python tools/verify_game.py --quit             # headless boot smoke test
  python tools/verify_game.py --negative-control # injected failure must exit nonzero
  python tools/verify_game.py --raw [args...]    # run engine directly, propagate exit
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

EXPECTED_ENGINE = "4.6.2"
TIMEOUT_SECONDS = 600
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fail(msg, code=2):
    print("verify_game: %s" % msg, file=sys.stderr)
    return code


def isolated_env():
    """Environment that keeps every verification process off the real profile.

    MANANET_PROFILE_PATH redirects Progression's persistence (including autoload
    startup) to a scratch file. A separate XDG_DATA_HOME also isolates Godot's
    user:// directory, so even a tool that ignores the override cannot touch the
    player's save.
    """
    env = dict(os.environ)
    scratch = tempfile.mkdtemp(prefix="mananet-verify-")
    profile_dir = os.path.join(scratch, "profile")
    os.makedirs(profile_dir, exist_ok=True)
    env["MANANET_PROFILE_PATH"] = os.path.join(profile_dir, "td_progression.json")
    env["XDG_DATA_HOME"] = os.path.join(scratch, "xdg")
    env["MANANET_VERIFY_SCRATCH"] = scratch
    return env


def find_godot():
    """Return path to the Godot executable or None."""
    env_bin = os.environ.get("GODOT_BIN")
    if env_bin:
        if os.path.isfile(env_bin):
            return env_bin
        found = shutil.which(env_bin)
        if found:
            return found
        return None
    for name in ("godot", "godot4"):
        found = shutil.which(name)
        if found:
            return found
    return None


def engine_version(godot, env=None):
    try:
        out = subprocess.run(
            [godot, "--version"],
            capture_output=True, text=True, timeout=60, env=env,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return (out.stdout + out.stderr).strip()


def run(godot, args, timeout=TIMEOUT_SECONDS, env=None, must_exit_zero=False):
    """Run the engine; return its exit code, or None on timeout.

    When must_exit_zero is set a nonzero exit is treated as a test failure and
    returned as-is so the caller cannot mistake it for success.
    """
    try:
        proc = subprocess.run(
            [godot] + args, cwd=REPO_ROOT,
            timeout=timeout, env=env,
        )
        return proc.returncode
    except subprocess.TimeoutExpired:
        return None


def run_parse_gate(godot, env=None):
    """Import the project and fail on fatal parse/load errors.

    A per-file GDScript loader cannot be used here: running with --script does
    not register autoloads, so valid scripts that reference Progression/
    FocusManager report false compilation failures. The editor import resolves
    the real project context (this mirrors the CI import gate).
    """
    try:
        proc = subprocess.run(
            [godot, "--headless", "--path", REPO_ROOT, "--import"],
            capture_output=True, text=True, timeout=TIMEOUT_SECONDS, env=env,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 2, "import timed out or failed to start"
    output = proc.stdout + proc.stderr
    bad = []
    for line in output.splitlines():
        if "android/" in line:
            continue  # nested Android plugin fixture project
        if "Parse Error" in line or "Failed to load script" in line:
            bad.append(line.strip())
    if bad:
        for line in bad[:20]:
            print("verify_game: PARSE: %s" % line, file=sys.stderr)
        return 1, "parse/load errors in import"
    return 0, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quit", action="store_true",
                        help="headless boot smoke test (--quit) instead of the full audit")
    parser.add_argument("--negative-control", action="store_true",
                        help="run the audit with a deliberately injected failure; "
                             "the run MUST exit nonzero")
    parser.add_argument("--raw", nargs=argparse.REMAINDER, metavar="ARGS",
                        help="pass ARGS straight to the engine and propagate its exit code")
    parser.add_argument("--allow-engine-mismatch", action="store_true",
                        help="warn instead of failing when the engine is not %s" % EXPECTED_ENGINE)
    parser.add_argument("--all", action="store_true",
                        help="run every gate: parse, audit, simulation regression, "
                             "UI regression, verifier exit contract, and early-run smoke")
    opts = parser.parse_args()

    godot = find_godot()
    if not godot:
        return fail("Godot engine not found. Set GODOT_BIN to a Godot %s "
                    "executable or put 'godot' on PATH." % EXPECTED_ENGINE)
    print("verify_game: engine = %s" % godot)

    env = isolated_env()
    print("verify_game: isolated profile = %s" % env["MANANET_PROFILE_PATH"])

    version = engine_version(godot, env=env)
    print("verify_game: engine version = %s" % (version or "<unknown>"))
    if EXPECTED_ENGINE not in (version or ""):
        msg = ("engine version mismatch: expected %s, got '%s'"
               % (EXPECTED_ENGINE, version or "unknown"))
        if opts.allow_engine_mismatch:
            print("verify_game: WARNING %s" % msg, file=sys.stderr)
        else:
            return fail(msg)

    # Local parse gate: the project must import with no fatal script errors.
    code, msg = run_parse_gate(godot, env=env)
    if code != 0:
        return fail("script parse gate failed: %s" % msg, code)
    print("verify_game: PASS script parse gate")

    if opts.raw is not None and opts.raw:
        code = run(godot, opts.raw, env=env)
        return fail("engine timed out") if code is None else code

    if opts.quit:
        code = run(godot, ["--headless", "--path", REPO_ROOT, "--quit"], env=env)
        if code is None:
            return fail("engine timed out during --quit smoke test")
        if code != 0:
            print("verify_game: FAIL boot smoke test exited %d" % code, file=sys.stderr)
            return code
        print("verify_game: PASS boot smoke test")
        return 0

    base = ["--headless", "--path", REPO_ROOT, "--script", "scripts/full_audit.gd"]
    if opts.negative_control:
        # Test-only invocation: inject one deliberate failure after "--".
        code = run(godot, base + ["--", "--negative-control"], env=env)
        if code is None:
            return fail("engine timed out during negative-control run")
        if code == 0:
            return fail("NEGATIVE CONTROL FAILED: audit reported failures on stdout "
                        "but exited 0; a printed PASS summary must not hide failures")
        print("verify_game: PASS negative control (exit %d as required)" % code)
        return code

    code = run(godot, base, env=env)
    if code is None:
        return fail("engine timed out during full audit")
    if code != 0:
        print("verify_game: FAIL audit exited %d" % code, file=sys.stderr)
        return code
    print("verify_game: PASS full audit (exit 0)")

    if not opts.all:
        return 0

    legs = [
        ("simulation regression",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/regression_checks.gd"]),
        ("UI regression",
         ["--headless", "--path", REPO_ROOT,
          "res://tests/ui/UIRegressionTest.tscn"]),
        ("player journey",
         ["--headless", "--path", REPO_ROOT,
          "res://tests/ui/PlayerJourneyTest.tscn"]),
        ("speed parity",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/speed_parity.gd"]),
        ("save fault injection",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/save_faults.gd"]),
        ("full-run qualification",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/full_run.gd"]),
        ("verifier exit contract", None),
        ("early-run smoke",
         ["--headless", "--path", REPO_ROOT, "scenes/SimTest.tscn"]),
    ]
    for name, args in legs:
        if args is None:
            # A Python test, not an engine script.
            try:
                proc = subprocess.run(
                    [sys.executable,
                     os.path.join(REPO_ROOT, "tests/verifier_exit/test_verifier_exit.py")],
                    cwd=REPO_ROOT, env=env, timeout=TIMEOUT_SECONDS)
                code = proc.returncode
            except (OSError, subprocess.TimeoutExpired):
                code = None
        else:
            code = run(godot, args, env=env)
        if code is None:
            return fail("%s timed out" % name)
        if code != 0:
            print("verify_game: FAIL %s exited %d" % (name, code), file=sys.stderr)
            return code
        print("verify_game: PASS %s (exit 0)" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
