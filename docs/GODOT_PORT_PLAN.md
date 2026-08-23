# Godot Port Plan — Tower Defense (TowerDefenseKivy)

## Context

The current game runs on Kivy (Python) targeting Android. Performance issues stem primarily from Kivy's lack of GPU sprite batching (~80 separate draw calls/frame) and no spatial indexing. The goal is to port to Godot 4 using GDScript, targeting Android + PC (Windows/Linux/Mac), with **performance improvements and feature parity delivered together** rather than sequentially.

The Python simulation (`core.py`, `progression.py`) is already framework-agnostic — no Kivy imports. Only the UI layer (`draw_kivy.py`, `screens/`, `input_controller_kivy.py`) needs full replacement. This is the key architectural advantage.

---

## Project Structure (Target)

```
godot_td/
├── project.godot
├── autoloads/
│   └── Progression.gd          # Global singleton (replaces progression.py)
├── simulation/
│   ├── GameState.gd             # Port of core.py GameState
│   ├── Tower.gd                 # Port of Tower class
│   ├── Enemy.gd                 # Port of Enemy + subclasses
│   ├── Projectile.gd            # Port of Projectile class
│   ├── UpgradePathTracker.gd    # Port of UpgradePathTracker state machine
│   ├── Effect.gd                # Port of Effect dataclass
│   └── Particle.gd              # Port of Particle dataclass (or use GPUParticles2D)
├── scenes/
│   ├── Main.tscn                # App entry (replaces kivy_app.py)
│   ├── GameScreen.tscn          # replaces screens/game.py
│   ├── MenuScreen.tscn          # replaces screens/menu.py
│   ├── MapSelectScreen.tscn     # replaces screens/map_select.py
│   ├── RoboBaseScreen.tscn      # replaces screens/robobase.py
│   ├── EndScreen.tscn           # replaces screens/end.py
│   └── SettingsScreen.tscn      # replaces screens/settings.py
├── rendering/
│   ├── GameRenderer.gd          # Replaces draw_kivy.py (Canvas2D draw calls)
│   └── ViewState.gd             # Replaces view_state.py (screen shake, animations)
├── input/
│   └── InputController.gd      # Replaces input_controller_kivy.py
├── data/
│   ├── tower_types.gd           # TOWER_TYPES dict → const Resource
│   ├── maps.gd                  # MAPS waypoints → const Resource
│   └── upgrade_paths.gd        # UPGRADE_PATHS → const Resource
└── assets/
    └── (sprites, audio, fonts)
```

---

## Phase 1 — Project Setup & Data Layer (Week 1)

**Goal**: Godot project boots, data constants exist, save/load works.

### Steps
1. Create Godot 4 project, configure Android export template + PC export.
2. Set display resolution to 900×600 (logical) with `stretch_mode = canvas_items` and `aspect = expand` — mirrors Kivy's scaling.
3. Port `TOWER_TYPES`, `MAPS` (waypoints), and `UPGRADE_PATHS` dicts to GDScript constants in `data/`.
4. Create `Progression.gd` autoload (singleton):
   - Port `load_profile()`, `save_profile()` using `FileAccess` to `user://td_progression.json`
   - Port `compute_rp()` formula exactly: `(waves*8) + (perfects*7) + (lives*5) + clamp(int(gold_spent/gold_earned * 20), 0, 40)`
   - Port `record_run()`, `get_run_config()`, `get_variant_for_type()`
   - Atomic save: write to `user://td_progression.tmp` then `DirAccess.rename()`
5. Port `UpgradePathTracker` as `simulation/UpgradePathTracker.gd` — this is the most complex logic, do it early to validate understanding:
   - 5 state transitions: `can_attempt_upgrade`, `would_trigger_promotion_preview`, `start_promotion_preview`, `confirm_promotion`, `apply_non_promotion_upgrade`
   - Primary capped at T5, secondary capped at T2, third path locked after primary chosen

**Files replaced**: `progression.py`, `simulation/core.py` (UpgradePathTracker only)

---

## Phase 2 — Core Simulation (Weeks 2–3)

**Goal**: `GameState.gd` runs a full game loop in pure GDScript with no rendering.

### Steps
1. Port `Enemy` base class + 5 subclasses (`FastScout`, `ArmoredTank`, `FlyingDrone`, `SwarmMinion`, `HeavyBrute`) to `Enemy.gd`. Key methods: `move(now_ms, speed_mult)`, `take_damage(dmg)`, `rewind_by_distance(fraction)`.
2. Port `Tower.gd`:
   - `effective_range()`, `effective_cooldown()`, `get_effective_damage(now_ms)`
   - `select_target(enemies)` — **add spatial optimization**: partition map into a 2D grid (~8×8 cells); each tower only queries its cell + neighbors. Reduces O(towers×enemies) to O(towers×local_enemies).
   - `shoot(now_ms, enemies, projectiles, speed_mult)`
3. Port `Projectile.gd`: `move()`, hit detection on `target` ref.
4. Port `Effect` and `Particle` as plain GDScript classes (no Nodes — they're data, not scene objects).
5. Port `GameState.gd` main class:
   - Constructor accepts run config from `Progression.get_run_config()`
   - `update_simulation(now_ms)` — exact same 8-step order as Python:
     1. Spawn enemies
     2. Move enemies, detect leaks
     3. Tower shooting
     4. Projectile movement + hit detection
     5. Remove dead enemies, award gold
     6. Expire effects
     7. Particle physics (`vel *= pow(friction, delta/0.016)` — frame-rate independent)
     8. Wave completion check
   - `apply_action(action, now_ms)` — port all 11 action types
6. Write a headless GDScript test scene that runs 15 waves with no renderer and prints gold/lives/RP at end — validates simulation correctness before any visual work.

**Performance improvement here**: spatial grid in `select_target()` cuts targeting from ~5,000 to ~500 distance checks/frame at wave 15.

**Files replaced**: `simulation/core.py` (full)

---

## Phase 3 — Rendering (Weeks 3–4)

**Goal**: Game is visually complete, 60 FPS on mid-range Android.

### Steps
1. Create `GameRenderer.gd` extending `Node2D`, called from `GameScreen.gd` each frame via `queue_redraw()` + `_draw()`.
2. Port all draw layers from `draw_kivy.py` in the same order:
   - **Background**: `draw_texture_rect()` for map texture; fallback procedural starfield using `draw_circle()`
   - **Path terrain**: 9-layer path rendered once to a `SubViewport` texture at scene load (cached, not per-frame). Only redraw if window resizes. This replaces `_PATH_CACHE_IG`.
   - **Range circle**: `draw_arc()` + glow via `draw_circle()` at reduced alpha
   - **Effects**: iterate `game_state.effects[]`, dispatch by type (flash, ring, lightning bolt, explosion, ice spike, damage numbers)
   - **Enemies**: **use `MultiMeshInstance2D`** — one draw call for all enemies of the same type. Port sprite chromakey shader to Godot shader language (`discard` on dark pixels). This replaces 50 separate `Rectangle` calls with 6 batched calls.
   - **Towers**: `MultiMeshInstance2D` per tower type. Badges (level, path) drawn as a separate pass via `CanvasItem`.
   - **Projectiles**: `MultiMeshInstance2D` per projectile type.
   - **Particles**: Custom `_draw()` loop (same as Kivy); 200 particles/frame is fine in GDScript's draw API.
   - **HUD**: Godot `Control` nodes (Button, Label, Panel) — don't hand-draw HUD, use the UI system.
3. Port `ViewState.gd`: screen shake (Lissajous offset: `sin(t*3.8)*amp`, `cos(t*4.9)*amp*0.45`), animation timers, panel visibility flags.
4. Port chromakey fragment shader (Kivy `_TRIM_FS`) to Godot shader:
   ```glsl
   shader_type canvas_item;
   void fragment() {
       vec4 col = texture(TEXTURE, UV);
       if (col.r < 0.15 && col.g < 0.15 && col.b < 0.20) discard;
       COLOR = col;
   }
   ```
5. Label caching: Godot's `Label` nodes handle font rendering natively. Use `RichTextLabel` for colored/styled text. No manual LRU cache needed.

**Performance improvement here**: `MultiMeshInstance2D` batches 50 enemies into 1 draw call (was 50 in Kivy). Same for towers and projectiles. Total draw calls drop from ~930 canvas instructions to ~30–40.

**Files replaced**: `ui/draw_kivy.py`, `ui/view_state.py`

---

## Phase 4 — Input & Screens (Week 5)

**Goal**: All 6 screens navigable, full touch + mouse input working.

### Steps
1. Port `InputController.gd`:
   - Map Godot `InputEventScreenTouch` and `InputEventMouse` to the same action dict format as Python: `{"type": "place_tower", "tower_type": "archer", "pos": [x, y]}`
   - Port placement ghost logic (drag to position, release to place)
   - `handle_input(event) -> Dictionary` — returns action or empty dict
2. `GameScreen.gd`:
   - `_process(delta)`: call `game_state.update_simulation(Time.get_ticks_msec())` then `renderer.queue_redraw()`
   - `_input(event)`: call `input_controller.handle_input(event)` → `game_state.apply_action(action)`
   - Handle confirmation flows (sell confirm, promotion confirm, restart confirm) via `ViewState` flags
3. Port remaining screens using Godot Control nodes:
   - `MenuScreen.tscn`: title, play button, robobase button, settings button
   - `MapSelectScreen.tscn`: 3 map cards with difficulty, FadeTransition via `Tween`
   - `RoboBaseScreen.tscn`: unlock grid, RP display, buy/activate buttons — reads from `Progression` autoload
   - `EndScreen.tscn`: wave count, RP earned, unlock notifications
   - `SettingsScreen.tscn`: fast promotion toggle, speed default, target mode default
4. Wire `SceneTree` transitions (Godot's `change_scene_to_file()`) with 0.25s fade — replaces Kivy `ScreenManager` FadeTransition.

**Files replaced**: `screens/game.py`, `screens/menu.py`, `screens/map_select.py`, `screens/robobase.py`, `screens/end.py`, `screens/settings.py`, `ui/input_controller_kivy.py`

---

## Phase 5 — Polish, Export & Validation (Week 6)

### Steps
1. **Android export**: Configure Godot Android export template, set min SDK 21, sign APK. Test on a physical budget device (2019–2021 era).
2. **PC export**: Windows + Linux exports from Godot editor.
3. **Performance profiling**: Use Godot's built-in profiler. Target: frame time < 8ms (120 FPS headroom) on mid-range Android.
4. **Save file migration**: On first run, check if old `td_progression.json` exists in Kivy's user_data_dir and import it. One-time migration path.
5. **Regression checklist** (play through manually):
   - All 6 tower types fire, upgrade through all 3 paths to T5/T2
   - UpgradePathTracker promotion flow (invest in 2nd path → confirm → lock 3rd)
   - All 5 enemy types spawn and take correct damage/status effects
   - Screen shake on life loss
   - RP formula matches Python output for a known run
   - All map modifier effects active (Iron Economy, Glass Cannon, Blitz, Hardened, Sudden Death)
   - Tower variants unlock at correct milestones
   - Save/load round-trip (close and reopen game, verify state restored)

---

## Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| UpgradePathTracker promotion flow has subtle edge cases | Port it in Phase 1, test with the headless sim runner before rendering |
| MultiMeshInstance2D requires fixed mesh count or dynamic resizing | Pre-allocate max expected count (enemies: 100, towers: 50) and use instance count property |
| Godot shader chromakey may differ from Kivy's threshold | Test chromakey shader on all 6 tower sprites early in Phase 3 |
| Android APK size / export issues | Set up Android export in Phase 1 (not Phase 5) to catch build issues early |
| Progression JSON format drift between Kivy and Godot versions | Keep JSON schema identical; add `"engine": "godot"` field to distinguish saves |

---

## Source File Mapping

| Python file | Godot equivalent |
|-------------|-----------------|
| `simulation/core.py` | `simulation/GameState.gd` + `Tower.gd` + `Enemy.gd` + `Projectile.gd` + `UpgradePathTracker.gd` |
| `progression.py` | `autoloads/Progression.gd` |
| `ui/draw_kivy.py` | `rendering/GameRenderer.gd` |
| `ui/view_state.py` | `rendering/ViewState.gd` |
| `ui/input_controller_kivy.py` | `input/InputController.gd` |
| `screens/game.py` | `scenes/GameScreen.tscn` + `GameScreen.gd` |
| `screens/menu.py` | `scenes/MenuScreen.tscn` |
| `screens/map_select.py` | `scenes/MapSelectScreen.tscn` |
| `screens/robobase.py` | `scenes/RoboBaseScreen.tscn` |
| `screens/end.py` | `scenes/EndScreen.tscn` |
| `screens/settings.py` | `scenes/SettingsScreen.tscn` |
| `kivy_app.py` | `scenes/Main.tscn` (SceneTree root) |

---

## Timeline Summary

| Week | Phase | Deliverable |
|------|-------|-------------|
| 1 | Setup + Data | Project boots, progression save/load works, UpgradePathTracker ported |
| 2–3 | Simulation | Full headless game loop runs 15 waves correctly |
| 3–4 | Rendering | Game is visually complete, MultiMesh batching active |
| 5 | Input + Screens | All 6 screens navigable, full input working |
| 6 | Polish + Export | APK signed, PC builds, regression checklist passed |
