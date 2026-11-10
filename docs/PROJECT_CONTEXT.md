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
│                     CyberDeckScreen, SettingsScreen, EndScreen, SimTest)
├── simulation/     ← Core game logic (GDScript classes, no UI):
│                     core/GameState.gd, entities/{Tower,Enemy,Projectile}.gd,
│                     effects/{Effect,Particle}.gd, upgrades/UpgradePathTracker.gd
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
| `simulation/core/GameState.gd` | Authoritative game state (lives, gold, wave, score) |
| `simulation/entities/Tower.gd` | Tower base class — stats, targeting, attack logic |
| `simulation/entities/Enemy.gd` | Enemy base class — path following, health, rewards |
| `simulation/entities/Projectile.gd` | Projectile physics and hit logic |
| `simulation/effects/Effect.gd` | Status effects (slow, burn, etc.) |
| `simulation/upgrades/UpgradePathTracker.gd` | Tracks tower upgrade paths and variant unlocks |
| `simulation/effects/Particle.gd` | Visual-only particle effects |
| `scenes/GameScreen.tscn` | Main gameplay scene |
| `scenes/CyberDeckScreen.tscn` | Meta-progression shop |
| `scripts/SimulationBot.gd` | Headless sim runner for balance testing |
| `scripts/benchmark.gd` | Live-wave performance benchmark (percentiles + liveness) |

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

- Full verification, every gate (parse, audit, simulation regression, UI
  regression, player journey, viewport geometry, speed parity, save fault
  injection, full-run qualification, verifier contract, smoke): `python3
  tools/verify_game.py --all`. Every child process runs with an isolated
  profile, so no gate can read or write a real player save.
- Full audit only (parse gate + check audit): `python3 tools/verify_game.py`
- Headless simulation: `godot --headless -s scripts/SimulationBot.gd`
- Benchmark (live wave, p50/p95/p99 + liveness assertion): `godot --headless -s scripts/benchmark.gd`
- Simulation regression checks: `godot --headless -s tests/simulation/regression_checks.gd`
- Simulation speed parity (1x/2x/3x at equal simulated time): `godot --headless -s tests/simulation/speed_parity.gd`
- Save fault injection (corrupt/failed-write/version/quarantine): `godot --headless -s tests/simulation/save_faults.gd`
- Full 15-wave qualification (all maps, all modifiers, strategies): `godot --headless -s tests/simulation/full_run.gd`
- Economy probe (prints wave-by-wave resource curves): `godot --headless -s tests/simulation/economy_probe.gd`
- UI regression harness: `godot --headless tests/ui/UIRegressionTest.tscn`
- Player journey through real scenes: `godot --headless tests/ui/PlayerJourneyTest.tscn`
- Viewport geometry across desktop/mobile sizes: `godot --headless tests/ui/ViewportGeometryTest.tscn`
- Early-run smoke test (exits after wave 3; not a 15-wave balance test): `godot --headless scenes/SimTest.tscn`
- Verifier exit-status contract: `python3 tests/verifier_exit/test_verifier_exit.py`
- Run locally: Godot 4.6 editor playback

Save isolation: set `MANANET_PROFILE_PATH` to redirect Progression persistence
(including autoload startup) away from the player profile. `verify_game.py`
does this automatically for every gate.

If the `godot` executable is not on `PATH`, report verification as blocked and include the command you would run.

## Risk Zones

- Upgrade paths, Research Point progression, balance tuning, and any behavior that must match the Python/Kivy original.
- Android export config and generated mobile build artifacts.
- Moving game logic from `simulation/` into scene/UI scripts.
