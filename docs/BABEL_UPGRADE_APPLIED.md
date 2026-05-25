# Babel upgrade applied — TowerDefenseGodot (2026-05-22)

Reversible workspace changes from `docs/BABEL_IMPROVEMENT_SUMMARY.md` and `docs/agent-policy/BABEL_LOCAL_MODE_IMPROVEMENTS.md`. No game simulation or balance files were modified.

---

## What changed

| Path | Change |
|------|--------|
| `Babel-private/tools/run-babel-local-cli.ps1` | `-Help` + fail-fast usage; non-mandatory params validated in-script; **TaskPrompt forwarded** to `start-local-session.ps1`; CLI output `-join` pipeline fix |
| `Babel-private/tools/lib/BabelLocalCli.ps1` | `Show-BabelLocalCliUsage`; PS5-safe `return if` / hashtable `if` / CLI output `-join` |
| `babel-local.ps1` (workspace root) | Maps `--help` / no args → `-Help` on wrapper (no hang) |
| `config/repo-map.json` | `app_test_babel` path → `Babel-private` (was duplicate `MonteCarloLedger`) |

---

## Why

- Agents hit **empty Prompt / session start failures** because the wrapper required `TaskPrompt` for `babel run` but never passed it to `start-local-session.ps1`.
- **Bare `babel-local.ps1`** passed only `-Root` and blocked ~7+ minutes on missing mandatory params.
- **`babel doctor --scope repos`** reported workspace **fail** while `godot_td` checks passed, due to duplicate repo-map path for `app_test_babel` (same as `montecarlo_ledger`).

---

## Old behavior

| Scenario | Result |
|----------|--------|
| `.\babel-local.ps1` (no args) | Long hang / interactive param wait; no usage text |
| `.\babel-local.ps1 --help` | PowerShell error: unknown parameter `-help` |
| Full local run with `-TaskPrompt "…"` | `babel run` received prompt; **session start / kickoff often empty** |
| `babel doctor --scope repos` | Top-level **fail** (`resolution.app_test_babel` / `RESOLVER_INVALID`) |

---

## New behavior

| Scenario | Result |
|----------|--------|
| `.\babel-local.ps1` or `.\babel-local.ps1 -Help` | Usage printed in **&lt;2s**, exit **0** (help) or **2** (missing params) |
| `.\babel-local.ps1 --help` | Same as `-Help` (workspace launcher normalizes flags) |
| Full local run with `-TaskPrompt "…"` | `$startParams.TaskPrompt` set before `start-local-session.ps1` (`# BABEL_UPGRADE_2026-05-22`) |
| `babel doctor --scope repos` | `app_test_babel` resolves to unique `Babel-public` path (rollback restores MonteCarloLedger line) |

---

## Rollback steps

```powershell
cd C:\Workspace

# 1) Revert Babel wrapper + launcher + helper
git checkout -- Babel-private/tools/run-babel-local-cli.ps1
git checkout -- Babel-private/tools/lib/BabelLocalCli.ps1
git checkout -- babel-local.ps1

# 2) Restore prior app_test_babel path (MonteCarloLedger alias)
git checkout -- config/repo-map.json
```

Pre-upgrade `app_test_babel` value:

```json
"app_test_babel": "C:\\Workspace\\Project_Android\\MonteCarloLedger"
```

---

## TowerDefenseGodot — agent recipes

**Project slug:** `godot_td` (folder name `TowerDefenseGodot`).

**Governance-only (scoped sanity — filter JSON for `godot_td` / `resolution.godot_td`):**

```powershell
cd C:\Workspace
node --env-file=Babel-private/babel-cli/.env Babel-private/babel-cli/dist/index.js doctor --scope repos --json
```

`babel doctor` does not yet expose `--project godot_td` for aggregate status; inspect check rows for `godot_td` or use:

```powershell
node ... doctor --scope repos --json | Select-String godot_td
```

**Full local mode (after upgrade):**

```powershell
cd C:\Workspace\Project_Games
.\babel-local.ps1 -TaskCategory game -Project godot_td `
  -ProjectPath "C:\Workspace\Project_Games\TowerDefenseGodot" `
  -Model codex -Mode verified `
  -TaskPrompt "Smoke: confirm TaskPrompt reaches session start."
```

**Note:** `-Model` must be `codex`, `claude`, or `gemini` (not `composer`). `-Project godot_td` is recommended; `-Project global` with `-ProjectPath` also works.

**Project_Games launcher:** `Project_Games/babel-local.ps1` forwards `@CliArgs` only. Named parameters (`-TaskCategory`, `-Model`, `-TaskPrompt`, …) must be passed as tokens after the script name, or run from workspace root: `cd C:\Workspace; .\babel-local.ps1 ...`.

**Primary game verification (unchanged):**

```powershell
cd C:\Workspace\Project_Games\TowerDefenseGodot
godot --headless -s tests/simulation/regression_checks.gd
```

---

## Verification (2026-05-22)

| Check | Command | Expected |
|-------|---------|----------|
| Help / fail-fast | `.\babel-local.ps1 -Help` | Usage, exit 0 |
| TaskPrompt gate | `.\babel-local.ps1 -TaskCategory game -Model codex -TaskPrompt smoke -Project godot_td -ProjectPath ...` | No "TaskPrompt must be non-empty" / empty Prompt at param bind |
| Full pipeline teardown | Same command through `babel run` | May fail at `end-local-session` until `@endParams` splat (workspace P0) |
| Godot regression | `godot --headless -s tests/simulation/regression_checks.gd` | 12/12 PASS |

---

## Not changed (by design)

- Full `babel run` → `inspect outcome` pipeline for real local-learning sessions
- Mandatory `TaskCategory` / `Model` / `TaskPrompt` for non-help invocations
- `Babel-private/config/runtime-flags.json` default `dryRun: false`
- No `-VerifyOnly` switch (deferred; use native Godot regression + doctor JSON filter)
