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


def classify_import_result(returncode, output, timed_out=False, launch_error=""):
    """Decide the parse-gate result from a process outcome.

    Success requires exit 0 and no recognized script/parse diagnostic.
    A nonzero exit is a failure even when the output is empty. A zero exit
    that still printed a script error is a failure. Timeouts and launch
    errors are setup failures (exit 2). This does not scan for a bare
    ``ERROR`` token, so fault-injection tests that print expected errors
    are not judged here.
    """
    if launch_error:
        return 2, "import failed to start: %s" % launch_error
    if timed_out or returncode is None:
        return 2, "import timed out"
    text = output or ""
    bad = []
    for line in text.splitlines():
        if "android/" in line:
            continue  # nested Android plugin fixture project
        if ("Parse Error" in line or "Failed to load script" in line
                or line.startswith("SCRIPT ERROR")):
            bad.append(line.strip())
    if returncode != 0:
        detail = bad[0] if bad else "no diagnostic text"
        code = returncode if returncode > 0 else 1
        return code, "import exited %s (%s)" % (returncode, detail)
    if bad:
        return 1, "parse/load errors in import despite exit 0"
    return 0, None


def run_parse_gate(godot, env=None, timeout=None):
    """Import the project and fail on fatal parse/load errors.

    A per-file GDScript loader cannot be used here: running with --script does
    not register autoloads, so valid scripts that reference Progression/
    FocusManager report false compilation failures. The editor import resolves
    the real project context (this mirrors the CI import gate).
    """
    limit = TIMEOUT_SECONDS if timeout is None else timeout
    try:
        proc = subprocess.run(
            [godot, "--headless", "--path", REPO_ROOT, "--import"],
            capture_output=True, text=True, timeout=limit, env=env,
        )
    except OSError as exc:
        return classify_import_result(None, "", launch_error=str(exc))
    except subprocess.TimeoutExpired as exc:
        output = ""
        if exc.stdout or exc.stderr:
            output = (exc.stdout or "") + (exc.stderr or "")
            if not isinstance(output, str):
                output = output.decode("utf-8", "replace")
        return classify_import_result(None, output, timed_out=True)
    output = proc.stdout + proc.stderr
    code, msg = classify_import_result(proc.returncode, output)
    if code != 0 and msg and "parse/load errors" in msg:
        for line in output.splitlines():
            if "Parse Error" in line or "Failed to load script" in line or line.startswith("SCRIPT ERROR"):
                print("verify_game: PARSE: %s" % line.strip(), file=sys.stderr)
    return code, msg


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
        ("viewport geometry",
         ["--headless", "--path", REPO_ROOT,
          "res://tests/ui/ViewportGeometryTest.tscn"]),
        ("interaction clicks",
         ["--headless", "--path", REPO_ROOT,
          "res://tests/ui/InteractionTest.tscn"]),
        ("speed parity",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/speed_parity.gd"]),
        ("save fault injection",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/save_faults.gd"]),
        ("full-run qualification",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/full_run.gd"]),
        ("clock authority",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/clock_authority.gd"]),
        ("rng isolation",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/rng_isolation.gd"]),
        ("victory qualification",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/simulation/victory_qualification.gd"]),
        ("input journey",
         ["--headless", "--path", REPO_ROOT,
          "res://tests/ui/InputJourneyTest.tscn"]),
        ("audio assets",
         ["--headless", "--path", REPO_ROOT, "--script",
          "tests/audio/sfx_assets.gd"]),
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
                    cwd=REPO_ROOT, env=env, timeout=TIMEOUT_SECONDS,
                    capture_output=True, text=True)
                code = proc.returncode
                output = proc.stdout + proc.stderr
            except (OSError, subprocess.TimeoutExpired):
                code = None
                output = ""
        else:
            try:
                proc = subprocess.run(
                    [godot] + args, cwd=REPO_ROOT, timeout=TIMEOUT_SECONDS, env=env,
                    capture_output=True, text=True)
                code = proc.returncode
                output = proc.stdout + proc.stderr
            except subprocess.TimeoutExpired:
                code = None
                output = ""
        if code is None:
            return fail("%s timed out" % name)
        if code != 0:
            print(output, file=sys.stderr)
            print("verify_game: FAIL %s exited %d" % (name, code), file=sys.stderr)
            return code
        # Godot harnesses only. The Python contract test prints SCRIPT ERROR
        # on purpose while classifying a fake import, and CI excludes that log
        # from the same scan.
        if args is None:
            print("verify_game: PASS %s (exit 0)" % name)
            continue
        problems = [ln for ln in output.splitlines()
                    if "SCRIPT ERROR" in ln
                    or "ObjectDB instances leaked at exit" in ln
                    or "resources still in use at exit" in ln]
        if problems:
            for ln in problems[:10]:
                print("verify_game: %s: %s" % (name, ln.strip()), file=sys.stderr)
            return fail("%s reported runtime errors/leaks" % name)
        print("verify_game: PASS %s (exit 0)" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
