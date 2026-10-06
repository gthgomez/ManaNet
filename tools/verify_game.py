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

EXPECTED_ENGINE = "4.6.2"
TIMEOUT_SECONDS = 600
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fail(msg, code=2):
    print("verify_game: %s" % msg, file=sys.stderr)
    return code


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


def engine_version(godot):
    try:
        out = subprocess.run(
            [godot, "--version"],
            capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return (out.stdout + out.stderr).strip()


def run(godot, args, timeout=TIMEOUT_SECONDS):
    """Run the engine; return (exit_code_or_None, elapsed_ok)."""
    try:
        proc = subprocess.run(
            [godot] + args, cwd=REPO_ROOT,
            timeout=timeout,
        )
        return proc.returncode
    except subprocess.TimeoutExpired:
        return None


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
    opts = parser.parse_args()

    godot = find_godot()
    if not godot:
        return fail("Godot engine not found. Set GODOT_BIN to a Godot %s "
                    "executable or put 'godot' on PATH." % EXPECTED_ENGINE)
    print("verify_game: engine = %s" % godot)

    version = engine_version(godot)
    print("verify_game: engine version = %s" % (version or "<unknown>"))
    if EXPECTED_ENGINE not in (version or ""):
        msg = ("engine version mismatch: expected %s, got '%s'"
               % (EXPECTED_ENGINE, version or "unknown"))
        if opts.allow_engine_mismatch:
            print("verify_game: WARNING %s" % msg, file=sys.stderr)
        else:
            return fail(msg)

    if opts.raw is not None and opts.raw:
        code = run(godot, opts.raw)
        return fail("engine timed out") if code is None else code

    if opts.quit:
        code = run(godot, ["--headless", "--path", REPO_ROOT, "--quit"])
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
        code = run(godot, base + ["--", "--negative-control"])
        if code is None:
            return fail("engine timed out during negative-control run")
        if code == 0:
            return fail("NEGATIVE CONTROL FAILED: audit reported failures on stdout "
                        "but exited 0; a printed PASS summary must not hide failures")
        print("verify_game: PASS negative control (exit %d as required)" % code)
        return code

    code = run(godot, base)
    if code is None:
        return fail("engine timed out during full audit")
    if code != 0:
        print("verify_game: FAIL audit exited %d" % code, file=sys.stderr)
        return code
    print("verify_game: PASS full audit (exit 0)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
