# ManaNet — W1 Inventory & Boss Contracts

**Program:** Ship A · Week 1 (2026-07-18)  
**Baseline audit:** `full_audit.gd` → **81/81 PASS** (2026-07-18)

---

## 1. Open-item inventory vs code reality

| # | Plan status (old) | Code reality (W1) | W1 action | W2+ owner |
|---|-------------------|-------------------|-----------|-----------|
| **7** JuiceManager | Partial — missing call sites | **Wired in W1:** `BTN_PRESS` (GameTheme), `ENEMY_DEATH` + `WAVE_CLEAR` (GameScreen rising edges). Already had place/upgrade/sell/boss appear/win/lose/shop open | Done code; device listen on Friday | Device QA |
| **8** Boss waves W5/W10/W15 | Open | **Core + 60% trash done:** subclasses, spawn, mechanics, BOSS_APPEAR, milestone shop; `get_wave_spawn_total()` = 1 boss + 60% base trash + 600ms post-boss delay | Device feel pass still open | Feel pass + shield VFX |
| **9** Cannon paths | Open | Upgrade path data exists; Shock chill ability still the real gap | Inventory only | W5–W6 |
| **12** Map 3 Spiral dead zone | Open | **Path already matches plan fix** in `data/maps.gd` (inner corridor `300,180` / exit `450,310`). Dead-zone claim may be stale | Validate with bot or demote Map 3 from demo | W3–W4 if still broken in play |
| **13** Variant mechanics | Open | Still mostly stat bumps | Deferred | Phase 2 |
| **14** Fire TV FocusManager | Open | **Out of program** (ship lock) | Skip | Never (this 90d) |

### Juice call-site map (post-W1)

| SFX | Where | Status |
|-----|--------|--------|
| BTN_PRESS | `ui/theme/GameTheme.gd` `_on_button_pressed` | **W1 wired** |
| TOWER_PLACE / UPGRADE / PROMOTE / SELL | `GameScreen.gd` action responses | Was already wired |
| ENEMY_DEATH | `GameScreen.gd` after sim step (`stat_enemies_killed` rising edge) | **W1 wired** |
| WAVE_CLEAR | `GameScreen.gd` (`wave_shop_pending` rising edge) | **W1 wired** |
| WAVE_START / BOSS_APPEAR | `_show_wave_banner` | Already wired |
| WAVE_SHOP_OPEN | `_show_wave_shop` | Already wired (after WAVE_CLEAR on same transition — acceptable double-cue) |
| WIN / GAME_OVER | run end | Already wired |

**Note:** Multi-kill same frame plays one `ENEMY_DEATH` (edge, not per-kill). Acceptable for W1; per-kill optional later if spam is desirable.

---

## 2. Boss contracts (W5 / W10 / W15) — locked for W2+

### Shared wave rules

| Rule | Spec | Current code | Gap |
|------|------|--------------|-----|
| Boss waves | `wave in [5, 10, 15]` | `_is_boss_wave()` | None |
| First spawn | Boss first, then trash | `enemies_spawned == 0` | None |
| Trash density | Plan: ~60% normal count after boss | `get_wave_spawn_total()` = 1 + round(base×0.6); base progression unchanged | Done (W2 code) |
| Telegraph | Banner + BOSS_APPEAR SFX | Implemented | Confirm readable on device |
| Milestone shop | Exclusive cards at 5/10/15 | `wave_shop_cards.gd` milestone pool | Playtest card power |

### Wave 5 — BossShieldBrute

| Field | Contract |
|-------|----------|
| **Fantasy** | Armored cyber hulk; early “oh shit” peak |
| **Role** | Teach focus fire + don’t waste DPS on shield ticks |
| **Stats (base, pre wave mult)** | HP 750, speed 1.0, armor 0.22, radius 23, reward 120 |
| **Mechanic** | `shield_hp = 3` — first 3 hits fully absorbed in `apply_hit`; HP untouched until shield gone |
| **Player read** | Distinct size + shield VFX (verify renderer shows shield state) |
| **Fail if** | Dies before shield is noticed, or immortal with wrong tower setup |
| **Pass feel** | Players switch target / stack DPS after shield break |

### Wave 10 — BossSwarmCarrier

| Field | Contract |
|-------|----------|
| **Fantasy** | Flying stealth carrier that dumps a swarm |
| **Role** | Mid-run chaos; punish single-target only compositions |
| **Stats** | HP 400, speed 2.4, flying, stealthed, radius 20, reward 100 |
| **Mechanic** | On death: spawn 4 `SwarmMinion` near body (once) |
| **Player read** | Stealth until revealed; death explosion + minions |
| **Fail if** | Minions ignored / path free win; or instant wipe unfair |
| **Pass feel** | “I killed it and made it worse for a second” then cleanup |

### Wave 15 — BossRegenerator

| Field | Contract |
|-------|----------|
| **Fantasy** | Final tank that out-heals weak DPS |
| **Role** | Endpeak; reward sustained DPS (Frost/Cannon identity) |
| **Stats** | HP 600, speed 1.5, armor 0.15, shields 80, regen 8 HP/s, reward 110 |
| **Mechanic** | Regen while alive and below max HP in movement step |
| **Player read** | HP bar ticks up; needs continuous fire |
| **Fail if** | Solo archer stalls forever; or melts in 2s |
| **Pass feel** | Race to the exit vs regen; clear feels earned |

### Demo path recommendation (Gate A1)

- **Primary demo map:** Map 0 S-Curve (balanced).  
- **Map 2 Spiral:** Keep unlocked; do not require for A1 until coverage validated.  
- **Boss feel sessions:** 3 blind-ish runs to W5 minimum; at least one full 15 if time.

---

## 3. Map 3 Spiral — coverage note

Current path (`data/maps.gd` MAPS[2]):

```text
(-40,300)→(200,300)→(200,100)→(750,100)→(750,500)→(300,500)
→(300,180)→(600,180)→(600,390)→(450,390)→(450,310)→(940,310)
```

This already applies the improvement-plan coordinate tweak. **W1 does not re-edit path.**  
W3–W4: place Frost+Sniper in SimulationBot / manual play; if inner coil still unhittable, widen further or mark Map 3 non-demo.

---

## 4. W2 handoff (ManaNet Mon–Tue)

1. Play boss waves on device with SFX on — confirm #7 juice + 60% trash pacing.  
2. ~~Optional: boss-wave trash density 60%.~~ **Done** (`GameState.get_wave_spawn_total` + post-boss delay).  
3. Shield VFX readability for BossShieldBrute.  
4. Start Cannon Shock chill if feel pass is already green.

---

## 5. Verification (W1)

```powershell
cd C:\Workspace\Project_Games\ManaNet
C:\Workspace\tools\Godot\v4.6.2\Godot_v4.6.2-stable_win64_console.exe --headless --path . -s scripts/full_audit.gd
# Expected: 81/81 PASS
```
