# AGENTS.md - ManaNet

Agent-neutral startup router for the Godot tower defense port. Root `ENGINEERING.md` and root `AGENTS.md` remain authoritative for safety, verification, deletion, scope, and truthfulness.

## Startup Sequence

1. Read `C:\\Workspace\\ENGINEERING.md`.
2. Read `C:\\Workspace\\AGENTS.md`.
3. Read `PROJECT_CONTEXT.md` in this directory.
4. If the task touches art, sprites, icons, towers-as-visuals, or AGES asset promotion, also read:
   - `art/ART_DIRECTION.md` (first section is the generation lock; AGES injects ~1000 chars)
   - `docs/SPRITE_AND_WEAPON_DIRECTION.md` (theme, critique, Tesla/Edgeworld brief, future weapons)
   - `.agent-game/manifest.yaml` → `art_direction` and `governance`
   - matching `assets/contracts/*.asset.yaml`
5. Read a model adapter only when it applies to the active tool:
   - `CLAUDE.md` for Claude
   - `CODEX.md` for Codex, if present
   - `GEMINI.md` for Gemini, if present
6. If porting from Kivy, inspect the matching source in `C:\\Workspace\\Project_Games\\TowerDefenseKivy` before translating behavior.

## Local Rules

- `PROJECT_CONTEXT.md` is the canonical project context for all agents.
- `simulation/` must stay UI-free. Do not add Node references or scene coupling there.
- Port mechanics faithfully from `TowerDefenseKivy`; do not invent new mechanics without user approval.
- Treat upgrade paths, Research Point progression, balance tuning, and Android export config as risk zones.

## Art / sprite rules

- Fantasy lock: medieval **weapon forms** built as modern energy hardware on a data grid. Not castle TD. Not pixel art.
- Runtime sprites are 256px (boss 384) **PNG RGBA**. JPEG navy cards in `assets/sprites/**` are legacy key art — do not add more.
- Icons are 64/128 PNG RGBA weapon-head crops.
- Tesla (`lightning`) must read as an Edgeworld-style industrial coil, not a toy orb.
- AGES `allow_agent_asset_promotion` is false. Generate candidates only. Do not overwrite shipped sprites without a human promote step.
- New towers in `docs/SPRITE_AND_WEAPON_DIRECTION.md` §7 are roster proposals, not permission to add sim types.

## Verification

Use the headless simulation and benchmark commands in `PROJECT_CONTEXT.md` when applicable. If `godot` is unavailable on `PATH`, report verification as blocked. Visual sprite work additionally needs `visual_checkpoint_smoke` (no navy plates on the 900×600 capture).
