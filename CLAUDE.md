# CLAUDE.md — godot_td (Tower Defense)

Godot 4 port of the Python/Kivy tower-defense game (`td_v712`). The original Kivy implementation lives at `C:\Workspace\td_v712\` and is the reference for game rules and progression. See `C:\Workspace\GODOT_PORT_PLAN.md` for the port strategy.

## Startup Sequence

1. Read this file.
2. If porting logic from Kivy: read `C:\Workspace\GODOT_PORT_PLAN.md`.
3. If resuming existing Godot work: inspect `scenes/` and `simulation/` to re-orient.

## Project Structure

```
godot_td/
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
- **Reference impl**: `C:\Workspace\td_v712\` (Python/Kivy)

## Architecture Rules

- `simulation/` must stay UI-free — no Node references, no scene coupling.
- `SimulationBot.gd` is the headless test harness; use it to verify balance changes before touching UI.
- When porting logic from `td_v712/`, read the Kivy source first, then translate — don't invent new mechanics without user approval.
- Upgrade paths and RP system are defined in `td_v712/` progression layer; port faithfully.
