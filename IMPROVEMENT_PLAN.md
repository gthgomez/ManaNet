# TowerDefenseGodot — Improvement Plan
> Audit date: 2026-04-27
> Based on: Godot port audit + 2026 RPG/TD genre research
> Kivy issues resolved by port: path cache scale key (#6), screen-transform caching (#10), placement toggles in pause modal (#8) — not carried forward.

---

## Priority Queue

| # | Area | Issue | Effort | Impact |
|---|------|-------|--------|--------|
| 1 | UX | Affordability visual state — shop buttons + RoboBase | Low | High |
| 2 | UX | Live tower stats in detail panel (damage / range / cooldown) | Low | High |
| 3 | UX | Milestone visibility — variant progress bars in RoboBase | Low | High |
| 4 | Gameplay | In-run wave shop (between-wave upgrade cards) | Medium | Very High |
| 5 | UX | Wave progress indicator (enemies remaining bar) | Low | Medium |
| 6 | UX | Run recap — milestone deltas on EndScreen | Low | Medium |
| 7 | Audio | JuiceManager implementation (SFX + haptics) | Medium | High |
| 8 | Gameplay | Boss waves at W5 / W10 / W15 | Medium | High |
| 9 | Content | Cannon tower — implement path abilities (Siege/Rapid/Shock) | Low | Medium |
| 10 | UX | Restart confirmation visual timer bar | Low | Medium |
| 11 | Gameplay | Challenge modifier stacking (compatible pairs + RP multiplier) | Low | Medium |
| 12 | Map | Map 3 "Spiral" inner loop dead zone fix | Low | Medium |
| 13 | Content | Rethink tower variants — mechanics not stat bumps | Medium | Medium |
| 14 | Platform | FocusManager — complete Fire TV dpad integration | Medium | Medium |
| 15 | UX | Banner channel split (instruction vs. action toast) | Medium | Medium |

---

## Detailed Issue Breakdown

---

### 1 — Affordability Visual State on Shop Buttons

**Files:**
- `scenes/GameScreen.gd` — tower shop button build loop (`_build_hud`)
- `scenes/RoboBaseScreen.gd` — unlock grid render

**Problem:** Tower shop buttons and RoboBase unlock buttons give no visual signal when the player cannot afford them. A text banner fires but is easy to miss. Players cannot build cost intuition without inline feedback.

**Fix — GameScreen tower shop:**
In `_build_hud()` and any per-frame HUD refresh, after building each tower button, apply modulate and re-color the cost label based on `game_state.gold`:

```gdscript
var affordable: bool = game_state.gold >= tower_cost
btn.modulate.a = 1.0 if affordable else 0.4
cost_label.add_theme_color_override("font_color",
    Color(1.0, 0.8, 0.0) if affordable else Color(1.0, 0.3, 0.3))
```

**Fix — RoboBaseScreen unlock grid:**
Same pattern for RP cost vs `Progression.banked_rp`. Already has a locked/unlocked state — add a third "visible but unaffordable" state with 40% modulate.

---

### 2 — Live Tower Stats in Detail Panel

**File:** `scenes/GameScreen.gd` — tower info panel section (tower selected state)

**Problem:** When a tower is selected the panel shows the tower name, sell value, and upgrade paths but no numeric stats. Players cannot make informed upgrade decisions without seeing actual damage, range, and fire rate.

**Fix:** Add a 3-stat row below the tower name. `Tower.gd` already exposes `effective_damage()`, `effective_range()`, `effective_cooldown()`:

```gdscript
var stats_label := Label.new()
stats_label.text = "⚔ %d   ◎ %d   ⏱ %dms" % [
    int(tower.effective_damage()),
    int(tower.effective_range()),
    int(tower.effective_cooldown())
]
stats_label.add_theme_color_override("font_color", Color(0.63, 0.63, 0.63))
stats_label.add_theme_font_size_override("font_size", 13)
```

Refresh on every tower select and after each upgrade confirmation.

---

### 3 — Milestone Visibility — Variant Progress Bars

**Files:**
- `autoloads/Progression.gd` — `profile.tower_stats` (already tracks use/kill counts)
- `scenes/RoboBaseScreen.gd` — Variants tab grid

**Problem:** Tower variants unlock at hidden kill/use thresholds. Players with no progress indicator disengage from the system entirely. The data is already tracked; it just isn't shown.

**Fix:** In the Variants tab, below each locked variant card, render a dual progress bar (uses / kills):

```gdscript
var use_prog  := float(profile.tower_stats[ttype]["uses"])  / float(variant.use_threshold)
var kill_prog := float(profile.tower_stats[ttype]["kills"]) / float(variant.kill_threshold)
# draw two thin ProgressBar nodes (or custom draw_rect) clamped to [0, 1]
# label: "8 / 15 uses   127 / 200 kills"
```

For already-unlocked variants, show a checkmark + unlock message ("Unlocked after 15 uses").

---

### 4 — In-Run Wave Shop (Between-Wave Upgrade Cards)

**Files:**
- `simulation/GameState.gd` — wave completion hook
- `scenes/GameScreen.gd` — modal system
- New: `data/wave_shop_cards.gd` — card pool definitions

**Problem:** The between-wave moment currently provides no player agency. In 2026, this is the single most-praised feature in roguelite TDs (standardized by Brotato, used in Drill Core, Dawn of Defense, Infamous Keepers). Our run structure already provides a natural pause point.

**Design:**
- On wave complete, present a modal with 3 randomly drawn cards (Choose One).
- Card categories: Gold Injection, Temporary Buff, Enemy Debuff (next wave only), Tower Discount, Passive Bonus.
- Card pool is filtered by active modifiers — Blitz Mode excludes Frost cards; Hardened excludes Archer cards.
- "Skip" option always available (no punishment for skipping).

**Implementation sketch:**
```gdscript
# data/wave_shop_cards.gd
const CARDS := [
    { "id": "gold_15",    "label": "+15 Gold",         "tag": "gold",   "mods_blocked": [] },
    { "id": "dmg_buff",   "label": "+10% Dmg (1 wave)", "tag": "buff",  "mods_blocked": [] },
    { "id": "slow_next",  "label": "Enemies -15% Speed next wave", "tag": "debuff", "mods_blocked": ["blitz"] },
    { "id": "frost_disc", "label": "Frost costs -20 this wave",    "tag": "discount", "mods_blocked": ["blitz"] },
    # ... expand pool to 12-15 cards
]
```

```gdscript
# GameScreen — on wave_complete signal
func _on_wave_complete() -> void:
    var pool := _filter_card_pool(active_modifiers)
    var drawn := _draw_cards(pool, 3)
    _show_wave_shop_modal(drawn)
```

Apply card effects to a transient `RunBonuses` struct in `GameState` that expires at run end.

---

### 5 — Wave Progress Indicator

**File:** `scenes/GameScreen.gd` — wave card / HUD top bar

**Problem:** No visual of enemies remaining during an active wave. Players can't judge whether to hold gold or spend immediately.

**Fix:** `GameState` already tracks `enemies_spawned`. Add `enemies_killed_this_wave` (increment in cleanup step):

```gdscript
# GameState.gd — cleanup step
enemies_killed_this_wave += 1

# GameScreen HUD — thin bar under wave label
var frac := 1.0 - float(game_state.enemies_alive()) / float(game_state.wave_enemy_count)
wave_progress_bar.value = frac  # ProgressBar, width fills top bar edge-to-edge
```

Color: green while frac < 0.75, amber < 0.95, red at last few enemies.

---

### 6 — Run Recap — Milestone Deltas on EndScreen

**Files:**
- `scenes/EndScreen.gd` — stat display section
- `autoloads/Progression.gd` — `last_run_stats` (already saved)

**Problem:** The end screen shows RP earned but gives no feedback on long-term progression milestones. Players don't know how close they are to the next variant unlock, so they have less reason to queue another run.

**Fix:** After updating `tower_stats` in `Progression.save_profile()`, compute per-tower deltas and pass them to EndScreen:

```gdscript
# Example output on end screen:
# "Archer: +23 kills → 127 / 200  (73 to go)"
# "Frost: variant unlocked!"
```

Keep it to 2-3 lines maximum. Only show towers that were used in the run. If a variant was unlocked this run, show it prominently with a highlight color.

---

### 7 — JuiceManager — SFX and Haptics

**File:** `ui/JuiceManager.gd` (currently a stub)

**Problem:** The stub exists but nothing calls it. Audio feedback is a 2026 mobile UX baseline — micro-sounds on button press, wave start, enemy death, and upgrade confirmation are considered core engagement mechanics, not decoration.

**Implementation plan:**
1. Add an `AudioStreamPlayer` pool (5-8 pooled players) as children of JuiceManager (autoload Node).
2. Define a sound catalogue:
   ```gdscript
   enum SFX { BTN_PRESS, TOWER_PLACE, TOWER_UPGRADE, ENEMY_DEATH, WAVE_START, WAVE_CLEAR, GAME_OVER, WIN }
   ```
3. Wire call sites in `GameScreen.gd` after each `apply_action()` response — `JuiceManager.play(SFX.TOWER_PLACE)`.
4. Android: use `Input.vibrate_handheld(duration_ms)` for heavy events (wave start, lives lost).
5. Gate all audio behind `Settings.sfx_enabled` (add to SettingsScreen toggle list).

Asset sourcing: Kenney.nl free SFX packs are license-clear for commercial use.

---

### 8 — Boss Waves at W5 / W10 / W15

**Files:**
- `simulation/Enemy.gd` — new boss subclasses
- `simulation/GameState.gd` — wave spawn logic
- `rendering/GameRenderer.gd` — boss sprite slot

**Problem:** 15 waves of scaling stats gets monotonous. Boss waves are standard in TD games and give the wave structure dramatic shape. Our architecture supports this with minimal changes.

**Three bosses (one per milestone wave):**

| Wave | Boss | Mechanic |
|------|------|----------|
| 5 | **Shielded Brute** | 3× ArmoredTank HP, absorbs first 3 hits with a breakable shield (renders separately); shield breaks into 2 ArmoredTanks |
| 10 | **Swarm Carrier** | FlyingDrone HP × 5 but spawns 4 SwarmMinions on death |
| 15 | **Regenerator** | HeavyBrute HP × 4, regens 8 HP/sec; Frost/Cannon must outpace regen |

```gdscript
# Enemy.gd additions
class BossShieldBrute extends Enemy:
    var shield_hp: int = 3
    func on_hit(dmg: float) -> float:
        if shield_hp > 0:
            shield_hp -= 1
            return 0.0  # absorb hit
        return dmg

class BossSwarmCarrier extends Enemy:
    # on_death: spawn 4 SwarmMinion at current position
    pass

class BossRegenerator extends Enemy:
    func tick_regen(delta: float) -> void:
        hp = min(hp + 8.0 * delta, max_hp)
```

Boss waves contain: 1 boss + a reduced normal wave (60% usual enemy count, slightly delayed after boss spawn). Add `is_boss_wave` flag to `GameState.start_wave()`.

---

### 9 — Cannon Tower Path Abilities

**Files:**
- `simulation/Tower.gd` — `shoot()` and `get_effective_*()` methods
- `data/upgrade_paths.gd` — Cannon paths already defined (Siege / Rapid / Shock)

**Problem:** Cannon's three paths (Siege, Rapid, Shock) are defined in `upgrade_paths.gd` with multipliers and descriptions but `Tower.gd` has no ability logic for them. Archer, Mage, Sniper, Frost, and Lightning all have coded special abilities; Cannon is the gap.

**Fix:**
- **Siege (Top):** Each tier increases `splash_bonus` (already in Tower data) — no new logic needed beyond multiplier passthrough. Confirm `apply_hit()` splash uses `tower.splash_bonus` correctly. ✓ likely already works.
- **Rapid (Middle):** Cooldown reduction. Confirm `effective_cooldown()` applies `cooldown_bonus` multiplier. ✓ likely already works.
- **Shock (Bottom):** On splash hit, apply a 300ms `chilled` effect to all enemies in radius. This needs a new `on_splash_hit` callback in `apply_hit()`:

```gdscript
# GameState.apply_hit() — splash loop addition
if tower.type == "cannon" and tower.has_path_ability("shock"):
    for nearby in splash_targets:
        nearby.apply_status("chilled", 300)
```

Verify all three paths in a headless sim run before marking complete.

---

### 10 — Restart Confirmation Visual Timer Bar

**File:** `scenes/GameScreen.gd` — pause modal or in-game restart button

**Problem:** The double-tap confirmation window has no visual countdown. Players either miss the window or re-tap too fast. A decaying bar makes the mechanic readable.

**Fix:** When `view_state.pending_confirmation == "restart"`, render a thin bar beneath the Restart button that decays to zero over the confirmation window:

```gdscript
# In _process or _draw — restart button area
if view_state.pending_confirmation == "restart":
    var frac := clampf((view_state.pending_confirmation_until - Time.get_ticks_msec()) / 1800.0, 0.0, 1.0)
    draw_rect(Rect2(restart_btn.position.x, restart_btn.position.y + restart_btn.size.y - 3,
                    restart_btn.size.x * frac, 3), Color(1, 0.5, 0))
```

---

### 11 — Challenge Modifier Stacking

**Files:**
- `autoloads/Progression.gd` — modifier purchase and run config
- `scenes/MapSelectScreen.gd` or `RoboBaseScreen.gd` — modifier selection UI

**Problem:** Modifiers are single-pick. Allowing compatible pairs to stack creates free depth and a higher RP reward ceiling without adding new content.

**Compatibility matrix:**

| Modifier A | Modifier B | Compatible? |
|---|---|---|
| Iron Economy | Sudden Death | ✓ (stack cleanly) |
| Iron Economy | Glass Cannon | ✓ |
| Glass Cannon | Blitz | ✓ (high risk / high reward) |
| Blitz | Hardened | ✗ (Blitz disables Frost; Hardened disables Archer — too punishing combined) |
| Sudden Death | Hardened | ✓ (extreme challenge, 4× RP) |

**RP multiplier stacking rule:** `total_rp_mult = max(mod_a_mult, mod_b_mult) + 0.5` (not additive — prevents single-run farming abuse).

**UI change:** In modifier selection, show incompatible second modifiers as greyed-out when a first is active. Show combined RP multiplier preview.

---

### 12 — Map 3 "Spiral" Inner Loop Dead Zone

**File:** `data/maps.gd` — MAPS[2].path

**Problem:** (Carried from Kivy plan, same design issue.) The inner coil segment creates a zone that standard-range towers cannot cover. Enemies in the inner loop are effectively invulnerable to placement outside the coil.

**Current path (Godot):**
```gdscript
Vector2(-40,300), Vector2(200,300), Vector2(200,100), Vector2(750,100),
Vector2(750,500), Vector2(300,500), Vector2(300,220), Vector2(600,220),
Vector2(600,390), Vector2(450,390), Vector2(450,300), Vector2(940,300)
```

**Proposed fix:** Push the top inner corridor higher and widen the exit:
```gdscript
# Change (300,220) → (300,180) and (450,300) → (450,310)
Vector2(300,180), Vector2(600,180), Vector2(600,390),
Vector2(450,390), Vector2(450,310), Vector2(940,310)
```

Validate with `SimulationBot` at Wave 10+ with Frost+Sniper loadout; confirm coverage improvement without creating new dead zones on the outer path.

---

### 13 — Rethink Tower Variants — Mechanics Not Stat Bumps

**Files:**
- `autoloads/Progression.gd` — variant stat delta definitions
- `simulation/Tower.gd` — ability dispatch

**Problem:** Current variants apply +5–20% stat deltas with minor mechanic tweaks. 2026 players expect milestone unlocks to open a meaningfully different playstyle, not just be "the same tower but slightly better."

**Proposed rework (keep thresholds, change rewards):**

| Variant | Current | Proposed Mechanic |
|---|---|---|
| Veteran Archer | +10% dmg, +5% range | **Volley:** Every 5th shot fires a 3-projectile spread at no extra cost |
| Permafrost Tower | +8% dmg, +20% chill | **Ice Trap:** Places a passive ground frost node after each wave (slows first enemy to cross it) |
| Runic Mage | +12% dmg, +1 chain | **Resonance:** Chains that jump to an already-burned enemy reset the burn timer instead of consuming it |
| Siege Mk.II | +8% dmg, +15% splash | **Aftershock:** 400ms after impact, a second smaller AoE (40% radius, 30% dmg) fires automatically |
| Longshot Sniper | +5% dmg, +20% range | **Marked:** First hit on any enemy marks it for 3s; all towers deal +15% to a marked target |
| Overclocked Tesla | +8% dmg, -10% cooldown | **Arc Overflow:** Chain jumps that hit the same enemy twice in one shot deal +50% to the second hit |

Keep stat deltas as secondary bonuses alongside the new mechanic. Implement in `Tower.gd` behind `tower.has_variant_ability("volley")` etc.

---

### 14 — FocusManager — Complete Fire TV Dpad Integration

**File:** `autoloads/FocusManager.gd` (currently ~40% complete)

**Problem:** Fire TV is a viable distribution channel for a polished TD game and Godot's export pipeline supports it. FocusManager handles dpad navigation in principle but is not wired into all screens.

**Remaining work:**
- Map dpad navigation through `RoboBaseScreen` tab bar and scroll grid
- Wire `ui_accept` / `ui_cancel` to modal confirm/dismiss in GameScreen
- Highlight focused element with `SelectionRing.gd` shader (already exists)
- Add focus entry points per screen (which node receives focus on scene load)
- Test with `Input.joy_button_index` emulation in editor

This is not blocking for Android/desktop but is required before any Fire TV store submission.

---

### 15 — Banner Channel Split (Instruction vs. Action Toast)

**Files:**
- `rendering/ViewState.gd` — banner state fields
- `scenes/GameScreen.gd` — banner display and routing

**Problem:** (Carried from Kivy plan.) A single `info_banner` field means placement instructions can be overwritten by sell confirmations mid-action. The collision is particularly bad during upgrade flows.

**Fix:** Split into two channels in `ViewState`:

```gdscript
# ViewState.gd additions
var instruction_banner: String = ""      # persistent, bottom of field
var action_toast: String = ""            # 2.2s fade, floats above shop bar
var action_toast_until: int = 0

func show_toast(msg: String) -> void:
    action_toast = msg
    action_toast_until = Time.get_ticks_msec() + 2200
```

- **instruction_banner**: placement hints, onboarding copy, modifier reminders. Stays until explicitly cleared.
- **action_toast**: sell confirmation, upgrade feedback, affordability errors. Auto-expires.

Render instruction_banner at the bottom of the field (above shop bar). Render action_toast as a floating label that fades via `modulate.a` once `Time.get_ticks_msec() > action_toast_until`.

---

## What's Already Good (Do Not Break)

- **3-path upgrade tree with promotion lock** — `UpgradePathTracker.gd` is clean and complete. Don't touch the state machine.
- **Spatial grid targeting** — `_build_enemy_spatial_grid()` in `GameState.gd` is a real optimization. Don't regress it.
- **MultiMesh batching in GameRenderer** — 13 draw calls vs. 900+. Don't add per-entity Node2D children.
- **Named upgrade paths** (Sylvan, Pyromancy, Assassin, Glacier, Tesla, etc.) — much better than Top/Middle/Bottom. Keep and extend.
- **Extended status effects** (Rooted, Burned, Transmuted, Disrupted, Revealed) — these are new relative to the Kivy version and enable the richer variant mechanics above. Don't remove any.
- **Five targeting modes** (first, last, strong, weak, close) — an expansion over the Kivy 3. Keep all five.
- **8 shaders** — LiquidGlass, TowerFidelity, SelectionRing, etc. are a visual differentiator. Don't simplify them.
- **Atomic save writes** — `Progression.gd` temp→rename pattern prevents corruption. Don't change the save flow.
- **SimulationBot headless harness** — use it to validate every balance change.
- **Screen fade transitions (0.25s)** — well-tuned. Don't speed up or remove.

---

## Roadmap View

### Phase A — Polish Pass (items 1, 2, 3, 5, 10, 15)
Low-effort UX fixes that close the gap between "functional" and "feels finished." All are display-only or minor state additions.

### Phase B — Audio (item 7)
JuiceManager implementation. Adds perceived production value disproportionate to code effort.

### Phase C — Content Depth (items 8, 9, 13)
Boss waves + Cannon abilities + variant rework. These three together change how the game *feels* over a run progression.

### Phase D — Systemic Additions (items 4, 6, 11)
Wave shop (biggest systemic change), run recap, modifier stacking. These change the roguelite loop.

### Phase E — Map + Platform (items 12, 14)
Spiral dead zone fix + Fire TV completion. Ship-blocking for Fire TV; low-risk for Android.

---

## Notes for Future Phases

- A **4th map** should introduce a mid-run gimmick (collapsing slot, dual-path merge) rather than just different waypoints. `GameState` supports a `map_event` hook; route it from `start_wave()`.
- If **co-op seed sharing** is added, implement as a run-seed hash (map + modifiers + wave_shop_seed) encoded as a short string. No network infrastructure needed — just encode/decode + a share button on EndScreen.
- A **roguelite run draft** (choose starting tower + modifier + bonus from 3-card offer at run start) is a medium-effort high-impact feature that fits naturally after the wave shop is in.
- The **WaveAnnouncer** full-width banner (mentioned in Kivy plan) is trivially implementable using the existing `WaveBanner.gd` — just scale it to full width and show wave number on `start_wave()`.
