# PROJECT_CONTEXT.md — ManaNet

Ordinary project documentation: factual context, structure, and commands.
Repository agent authority lives in the root [`AGENTS.md`](../AGENTS.md).

## What This Is

Godot 4 port of the Python/Kivy tower-defense game in the sibling `TowerDefenseKivy` repository.

## Ship program

**Ship A** in the locked 90-day mobile program (workspace ship-program doc).  
Parallel polish with SimLife (Ship B). Prefer open polish items in `IMPROVEMENT_PLAN.md` (#7 finish, #8 bosses, #9 Cannon, #12 Map 3, #13 variants). **Skip #14 Fire TV** for this program.

**Identity:** `docs/IDENTITY_AND_UX_DIRECTION.md` + `ui/theme/BrandCopy.gd` — network defense fantasy; player terms: Credits, Integrity, Shards, Cyber-Deck, Patches.

## Project Structure

```
├── scenes/         ← All .tscn files (Main, GameScreen, MenuScreen, MapSelectScreen,
│                     RoboBaseScreen, SettingsScreen, EndScreen, SimTest)
├── simulation/     ← Core game logic (GDScript classes, no UI)
├── scripts/        ← Non-simulation scripts (SimulationBot.gd, benchmark.gd)
├── autoloads/      ← Godot autoload singletons
├── ui/             ← Reusable UI components
├── data/           ← JSON data files (towers, enemies, maps, upgrades)
├── assets/         ← Art and audio
├── rendering/      ← Rendering helpers
├── input/          ← Input handling
└── android/        ← Android export config
```

## Key Files

| File | Role |
|------|------|
| `simulation/GameState.gd` | Authoritative game state (lives, gold, wave, score) |
| `simulation/Tower.gd` | Tower base class — stats, targeting, attack logic |
| `simulation/Enemy.gd` | Enemy base class — path following, health, rewards |
| `simulation/Projectile.gd` | Projectile physics and hit logic |
| `simulation/Effect.gd` | Status effects (slow, burn, etc.) |
| `simulation/UpgradePathTracker.gd` | Tracks tower upgrade paths and variant unlocks |
| `simulation/Particle.gd` | Visual-only particle effects |
| `scenes/GameScreen.tscn` | Main gameplay scene |
| `scenes/RoboBaseScreen.tscn` | Robo-Base shop screen |
| `scripts/SimulationBot.gd` | Headless sim runner for balance testing |
| `scripts/benchmark.gd` | Performance benchmark harness |

## Stack

- **Engine**: Godot 4.6, GDScript
- **Target**: Android + desktop (Mobile feature set)
- **Reference impl**: sibling `TowerDefenseKivy` repository (Python/Kivy)

## Architecture & Invariants

- `simulation/` must stay UI-free. Do not add Node references or scene coupling there.
- `scenes/`, `ui/`, `rendering/`, and `input/` own presentation, reusable UI, rendering helpers, and input handling.
- `ui/controllers/` holds cohesive subsystems extracted from `GameScreen.gd` (wave-shop modal, tower-details overlay, run setup, placement hints); GameScreen remains the scene entry point and orchestrator.
- `scripts/SimulationBot.gd` is the headless simulation harness for mechanics and balance checks.
- When porting from `TowerDefenseKivy`, translate the existing mechanics faithfully. Do not invent new mechanics without user approval.

## Verification & Commands

Run from the repository root.

- Headless simulation: `godot --headless -s scripts/SimulationBot.gd`
- Benchmark: `godot --headless -s scripts/benchmark.gd`
- Simulation regression checks: `godot --headless -s tests/simulation/regression_checks.gd`
- UI regression harness (hermetic — backs up/restores the user save): `godot --headless tests/ui/UIRegressionTest.tscn`
- Run locally: Godot 4.6 editor playback

If the `godot` executable is not on `PATH`, report verification as blocked and include the command you would run.

## Risk Zones

- Upgrade paths, Research Point progression, balance tuning, and any behavior that must match the Python/Kivy original.
- Android export config and generated mobile build artifacts.
- Moving game logic from `simulation/` into scene/UI scripts.
