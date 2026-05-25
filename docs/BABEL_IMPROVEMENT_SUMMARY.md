# How to Improve Babel — TowerDefenseGodot Polish Session

Product feedback from a **2026-05-22** agent session that implemented UI/audio polish in `godot_td` (`C:\Workspace\Project_Games\TowerDefenseGodot`) under an explicit **Babel local mode** requirement. No `docs/BABEL_POLISH_SESSION.md` existed; this file is the canonical write-up.

---

## 1. Session context

An implementation agent was asked to ship a bounded polish batch (SFX wiring, settings persistence, shop/wave/restart UX) and to use Babel local CLI for governance and evidence. Work completed via direct Godot edits and `godot --headless -s tests/simulation/regression_checks.gd` (12/12 PASS). Babel was used opportunistically after launcher friction: workspace `babel.ps1` for `doctor` / `inspect`, not a full `run-babel-local-cli.ps1` session with `-TaskPrompt`.

---

## 2. What Babel did well

- **Workspace `babel.ps1` passthrough** — Agents can call `node … babel-cli/dist/index.js <subcommand>` without starting a local-learning session; `inspect outcome --help` returned immediately and documented the inspect surface.
- **`babel doctor --scope repos --json`** — Fast, structured repo-map validation; `godot_td` resolution and path checks **passed** in ~25–35s, confirming the mapped project path is sane for agents routing to this repo.
- **Repo-map slug clarity (when known)** — `config/repo-map.json` key `godot_td` matches `AGENTS.md` / `PROJECT_CONTEXT.md` naming; `-Project godot_td -ProjectPath …\TowerDefenseGodot` is the correct pairing for local mode.
- **Dry-run off by default** — `Babel-private/config/runtime-flags.json` had `"dryRun": false`, so agents were not blocked by dry-run when using the main CLI; session work was not falsely marked complete by a no-op run.
- **Project-local launcher discovery** — `TowerDefenseGodot/babel-local.ps1` and `Project_Games/babel-local.ps1` correctly walk up to workspace `babel-local.ps1`; no duplicate Babel install in the game repo.

---

## 3. What held agents back

- **`babel-local.ps1 --help` fails** — From `C:\Workspace\Project_Games`, `.\babel-local.ps1 --help` forwarded to `run-babel-local-cli.ps1`, which has **no** `-Help` / `-?` handler; PowerShell error: parameter `-help` not found. Agents cannot discover required flags without reading `Babel-private/tools/run-babel-local-cli.ps1`.
- **Bare `babel-local.ps1` hangs** — `cd TowerDefenseGodot && .\babel-local.ps1` with no args ran ~7+ minutes and produced no output before abort; looks like a stuck session start, not a fast “usage” failure.
- **Mandatory `-TaskPrompt` for local mode** — `run-babel-local-cli.ps1` requires `-TaskCategory`, `-Model`, and `-TaskPrompt` for any real invocation. Polish/verification tasks do not need a full `babel run` + session lifecycle; agents default to skipping Babel or over-invoking it.
- **`doctor` aggregate noise** — `babel doctor --scope repos` returned top-level `"status": "fail"` while `godot_td` checks passed; failure was `resolution.app_test_babel` (`RESOLVER_INVALID`, duplicate path with `montecarlo_ledger` in `repo-map.json`). Agents may report “Babel failed” for unrelated workspace issues.
- **Project slug vs folder name** — Folder is `TowerDefenseGodot`; Babel project is `godot_td`. Agents guessing `-Project TowerDefenseGodot` or `global` will mis-route overlays and run pointers unless they read `repo-map.json`.
- **No lightweight “verify only” local entry** — No documented one-liner for “record evidence + run project verification command” without `-TaskPrompt` and model session overhead.
- **`babel.ps1 --help` latency** — Workspace `babel.ps1 --help` was slow enough to background/timeout in the same session; discoverability path is weaker than `doctor --help` via direct `node` invocation.
- **Dry-run discoverability** — `BABEL_DRY_RUN` / `runtime-flags.json` behavior is not surfaced at launcher help; agents cannot tell if a run would be simulated without reading Babel-private config.

---

## 4. Prioritized recommendations for Babel maintainers

1. **Add first-class help to `run-babel-local-cli.ps1` and workspace `babel-local.ps1`** (S) — On `-Help` / no args / `-?`, print required parameters, example one-liners, and link to `babel doctor` / `babel inspect` for governance-only workflows.
2. **Fail fast when local launcher is invoked with zero args** (S) — Exit in &lt;2s with usage text instead of starting `start-local-session.ps1` or blocking for minutes.
3. **Add `babel verify` or `local-cli -VerifyOnly`** (M) — Accept `-Project`, `-ProjectPath`, `-Command` (e.g. Godot regression script); write session manifest + exit code without `-TaskPrompt` or model run.
4. **Scope `doctor` success to requested project** (M) — Flags such as `--project godot_td` or `--only godot_td` so aggregate status reflects the target repo, not unrelated `repo-map` collisions.
5. **Fix or quarantine `app_test_babel` in `repo-map.json`** (S) — Remove duplicate path mapping or alias correctly so `doctor --scope repos` is green for routine game work.
6. **Document project slug ↔ path in launcher help** (S) — Emit `godot_td → Project_Games\TowerDefenseGodot` from `repo-map.json` at help time.
7. **Publish “governance-only” agent recipe** (S) — In `Babel-private` docs: when to use `babel doctor` / `inspect outcome` vs full local mode; include copy-paste commands for game repos.
8. **Optional `-DryRun` switch on local wrapper** (S) — Override `runtime-flags.json` per invocation and print `BABEL_DRY_RUN_SOURCE` in stdout for audit trails.
9. **Per-project doctor profile** (L) — Game/mobile subsets of checks (PATH tools, headless sim, export presets) without full workspace `all` scope.

---

## 5. Suggested CLI / API / script changes

| Change | Detail |
|--------|--------|
| **`run-babel-local-cli.ps1`** | Add `[switch]$Help`; if `$Help` or (`$PSBoundParameters.Count -eq 0` and no `@CliArgs`), call `Show-BabelLocalCliUsage` and `exit 0`. |
| **`run-babel-local-cli.ps1`** | Add optional `-VerifyCommand <string>` + `-Project` / `-ProjectPath`; run command, capture stdout/stderr to `runs/local-learning/...`, set exit code from command only (no `babel run`). |
| **`babel-local.ps1` (workspace)** | Forward `-Help` / `-?` before delegating to wrapper; document: `.\babel-local.ps1 -Help`. |
| **`babel doctor`** | `--project <slug>` filters checks and sets top-level `status` from filtered set only. |
| **`config/repo-map.json`** | Resolve `app_test_babel` duplicate: use unique path or mark deprecated slug non-resolving with explicit skip in doctor. |
| **Agent task templates** | Replace “run `babel-local.ps1 --help`” with “run `.\babel-local.ps1 -Help`” or `babel doctor --scope repos --project godot_td --json`. |
| **Example local mode (full)** | `.\babel-local.ps1 -TaskCategory game -Project godot_td -ProjectPath C:\Workspace\Project_Games\TowerDefenseGodot -Model codex -Mode verified -TaskPrompt "Run godot headless regression; list changed files."` |

**Commands exercised this session**

```powershell
# Failed — no -Help on wrapper
cd C:\Workspace\Project_Games
.\babel-local.ps1 --help

# Aborted — no args, long hang, no output
cd C:\Workspace\Project_Games\TowerDefenseGodot
.\babel-local.ps1

# OK — inspect surface
cd C:\Workspace
node --env-file=Babel-private/babel-cli/.env Babel-private/babel-cli/dist/index.js inspect outcome --help

# OK for godot_td; overall fail due to app_test_babel
node --env-file=Babel-private/babel-cli/.env Babel-private/babel-cli/dist/index.js doctor --scope repos --json
```

---

## 6. What to keep unchanged

- **Session → run → inspect outcome pipeline** for real Babel-gated implementation work (overlays, evidence, learning runs).
- **Mandatory `-TaskCategory` / `-Model` / `-TaskPrompt`** for full local mode — do not weaken for production agent runs; add a *separate* lightweight path instead.
- **Workspace-root `babel-local.ps1` discovery** from project nested launchers (`TowerDefenseGodot`, `Project_Games`).
- **`repo-map.json` as path authority** — keep `godot_td` slug; improve discoverability, not rename to folder name.
- **`runtime-flags.json` persisted dry-run** — keep default `dryRun: false` for real verification; expose override, do not force dry-run on by default.
- **Autoload-style separation** — Babel governance should not require loading `BABEL_BIBLE.md` for non-Babel game polish (aligns with root `AGENTS.md` gating).
- **Direct `babel.ps1` / `node … babel-cli`** for read-only diagnostics — agents already succeed with this when full local mode is overkill.

---

*Maintainers: treat failures in §3 as reproducible from this session; re-run §5 commands after fixes to confirm help and doctor scoping.*

---

## Post-upgrade (2026-05-22)

Shared Babel CLI fixes documented in [BABEL_UPGRADE_APPLIED.md](./BABEL_UPGRADE_APPLIED.md) and workspace [BABEL_LOCAL_MODE_IMPROVEMENTS.md](../../../docs/agent-policy/BABEL_LOCAL_MODE_IMPROVEMENTS.md).

| Item (§4 / session) | Status |
| --- | --- |
| ~~Help / fail-fast on `babel-local.ps1`~~ | **Fixed** — `-Help`, `--help`, no-args usage |
| ~~`TaskPrompt` → `start-local-session`~~ | **Fixed** — `$startParams.TaskPrompt` in `run-babel-local-cli.ps1` |
| ~~`doctor` / `app_test_babel` duplicate path~~ | **Fixed** — `app_test_babel` → `Babel-private` in `config/repo-map.json` |
| Full local pipeline end-to-end | **Blocked** — `end-local-session` hashtable splat (workspace P0); use Godot regression as primary evidence |
| `-VerifyOnly` / scoped doctor `--project` | Still open (recommendations unchanged) |
