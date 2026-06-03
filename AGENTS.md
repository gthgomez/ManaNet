# AGENTS.md - godot_td

Agent-neutral startup router for the Godot tower defense port. Root `ENGINEERING.md` and root `AGENTS.md` remain authoritative for safety, verification, deletion, scope, and truthfulness.

## Startup Sequence

1. Read `C:\Workspace\ENGINEERING.md`.
2. Read `C:\Workspace\AGENTS.md`.
3. Read `PROJECT_CONTEXT.md` in this directory.
4. Read a model adapter only when it applies to the active tool:
   - `CLAUDE.md` for Claude
   - `CODEX.md` for Codex, if present
   - `GEMINI.md` for Gemini, if present
5. If porting from Kivy, inspect the matching source in `C:\Workspace\Project_Games\TowerDefenseKivy` before translating behavior.

## Local Rules

- `PROJECT_CONTEXT.md` is the canonical project context for all agents.
- `simulation/` must stay UI-free. Do not add Node references or scene coupling there.
- Port mechanics faithfully from `td_v712`; do not invent new mechanics without user approval.
- Treat upgrade paths, Research Point progression, balance tuning, and Android export config as risk zones.

## Verification

Use the headless simulation and benchmark commands in `PROJECT_CONTEXT.md` when applicable. If `godot` is unavailable on `PATH`, report verification as blocked.
