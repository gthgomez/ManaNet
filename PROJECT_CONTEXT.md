# PROJECT_CONTEXT.md — ManaNet

## What This Is

Godot 4 port of the Python/Kivy tower-defense game in `C:\Workspace\Project_Games\TowerDefenseKivy`.

This file is the agent-neutral project context. `CLAUDE.md` is a Claude adapter; it should not be required for Codex, Gemini, or other agents unless they are specifically using that adapter.

## Ship program

**Ship A** in the locked 90-day mobile program: `C:\Workspace\Project_Games\SHIP_PROGRAM_90_DAY.md`.  
Parallel polish with SimLife (Ship B). Prefer open polish items in `IMPROVEMENT_PLAN.md` (#7 finish, #8 bosses, #9 Cannon, #12 Map 3, #13 variants). **Skip #14 Fire TV** for this program.

**Identity:** `docs/IDENTITY_AND_UX_DIRECTION.md` + `ui/theme/BrandCopy.gd` — network defense fantasy; player terms: Credits, Integrity, Shards, Cyber-Deck, Patches.

## Startup Sequence

1. Read workspace root `ENGINEERING.md`.
2. Read workspace root `AGENTS.md`.
3. Read `C:\Workspace\Project_Games\SHIP_PROGRAM_90_DAY.md` when doing ship/polish work.
4. Read this file.
5. Read a model adapter only when it applies to the active tool:
   - `CLAUDE.md` for Claude
   - `CODEX.md` for Codex, if present
   - `GEMINI.md` for Gemini, if present
6. If porting logic from Kivy, inspect the matching source in `C:\Workspace\Project_Games\TowerDefenseKivy`.

## Architecture & Invariants

- `simulation/` must stay UI-free. Do not add Node references or scene coupling there.
- `scenes/`, `ui/`, `rendering/`, and `input/` own presentation, reusable UI, rendering helpers, and input handling.
- `ui/controllers/` holds cohesive subsystems extracted from `GameScreen.gd` (wave-shop modal, tower-details overlay, run setup, placement hints); GameScreen remains the scene entry point and orchestrator.
- `scripts/SimulationBot.gd` is the headless simulation harness for mechanics and balance checks.
- When porting from `TowerDefenseKivy`, translate the existing mechanics faithfully. Do not invent new mechanics without user approval.

## Verification & Commands

Run from `C:\Workspace\Project_Games\ManaNet`.

- Headless simulation: `godot --headless -s scripts/SimulationBot.gd`
- Benchmark: `godot --headless -s scripts/benchmark.gd`
- Run locally: Godot 4.6 editor playback

If the `godot` executable is not on `PATH`, report verification as blocked and include the command you would run.

## Risk Zones

- Upgrade paths, Research Point progression, balance tuning, and any behavior that must match the Python/Kivy original.
- Android export config and generated mobile build artifacts.
- Moving game logic from `simulation/` into scene/UI scripts.
