# ManaNet Polish Campaign — 2026-11-11

Base: `feat/gameplay-reliability-overhaul` @ `c6ce30c` (main was `a21d21b`).
Engine: Godot 4.6.2 stable, GL Compatibility, `llvmpipe` under Xvfb for captures.

## Verdict

The game is materially closer to a finished, dependable experience. The
blocking short-landscape failures are fixed, the visual system renders
consistently on desktop and mobile paths, modal/hitbox behavior is covered by a
new real-click test, and the audio placeholder set is replaced with normalized
original cues. Remaining risk is concentrated in physical-device qualification
(density, safe area, touch comfort, thermal/perf), not in the desktop-verified
UI/state logic.

## Findings and disposition

| Severity | Finding | Evidence | Disposition |
| --- | --- | --- | --- |
| P0 | Map PLAY buttons clipped below a 320px landscape viewport (cards forced to 390px, vertical scroll disabled) | 568×320 capture before fix | Fixed: cards fit available height; descriptions hide first; all three PLAYs visible/touch-sized |
| P0 | Pause modal collapsed to a one-character-wide column ("P a u s e d") with actions unreachable | 568×320 capture before fix | Fixed: modal body width follows the modal; all five controls reachable by scroll; touch-sized |
| P0 | Tower panel hidden entirely at short heights → upgrade/sell/target unreachable | 568×320 `game_selected` before fix | Fixed: short screens use a full-width tower sheet with close control; all rows visible at 568×320 |
| P0 | Shop card click toggled placement OFF on release (button_down entered, pressed re-entered/cancelled) | New `InteractionTest` click assertion | Fixed: repeat press is an explicit cancel; normal click starts placement |
| P0 | End-screen actions (Play Again/Map/Cyber-Deck/Menu) below the viewport at 568×320 | capture before fix | Fixed: scrollable stats region + fixed action/footer; all actions reachable |
| P1 | Card/glass panels invisible on desktop (shader paired with `StyleBoxEmpty` never drew) | Map/Cyber-Deck captures before fix | Fixed: real `StyleBoxFlat` card/glass styling on every renderer; one code path |
| P1 | Instruction banner over speed buttons; clipped top-bar message; placement bar over speed strip | 568/900 captures before fix | Fixed: banner below speed strip, compact HUD hides the long status line and surfaces toasts in the banner, confirm bar docks at the bottom |
| P1 | Touch targets 34–44 px across menu/map/Cyber-Deck/settings/pause | geometry probe | Raised to 48/56 logical px; tests now enforce 48 ±1 |
| P1 | Upgrade names truncated with `.left(7)`; missing emoji glyphs showed as tofu | 900 capture before fix; interaction test | Fixed: branch labels (`Top +10% · 80c`), full name in tooltip/info overlay; ASCII stat labels |
| P1 | Wave-shop titles rendered missing emoji as a close-looking box; descriptions clipped | 568/900 captures | Fixed: label + textual category chip; four description lines |
| P1 | Modifier strip overflowed when 5 modifiers unlocked | 568 capture with all modifiers | Fixed: horizontally scrollable strip; all chips reachable |
| P1 | 60ms, −34dBFS SFX were effectively inaudible placeholders | `soundfile` measurement | Replaced with 15 original synthesized, peak-normalized cues; dedicated integrity/error/purchase cues |
| P1 | Save failure showed as "+0 Shards" with no explanation | code review + new capture | Fixed: explicit red "PROGRESS NOT SAVED" warning; reward line fixed above scroll |
| P1 | Test assertions measured size but not reachability (false passes) | independent review | Fixed: scroll-into-view assertions for pause/tower/settings/Cyber-Deck, lower-half tower branch, no-overlap checks, 48px tolerance |
| P2 | Trap: `follow_focus` absent, so D-pad focus could target off-screen controls | review | Added to all scroll surfaces |
| P2 | Map card hover pivot fixed at (150,210) outside compact cards | review | Pivot follows actual card size |
| P2 | Short tower sheet overflowed its rect by the inner scrollbar width / clipped 4px | review | Width budget includes the bar; margins/separation tightened |
| P2 | Settings first row clipped at scroll top | review | 8px top pad |
| P2 | Tower header buttons adjacent to name instead of right edge | captures | Expanding spacer added |
| P2 | Menu mute control looked like a label; emoji tofu | capture | Styled navy pill with "SFX/MUTED" text |

No simulation/economy/tower stat/card-effect file was modified.

## Implemented changes (files)

- `scenes/GameScreen.gd` — responsive HUD/banner/confirm bar, tower sheet,
  explicit unaffordable-shop feedback,
  pause/promotion touch sizes and scroll widths, modal backdrop, live wave
  count, boss banner, readable labels, warning colors, shop click semantics,
  per-frame restyle caches.
- `scenes/MapSelectScreen.gd` — adaptive card height, fit-to-width cards,
  scrollable modifier strip, pivot fix.
- `scenes/MenuScreen.gd` — compact identity layout, transparent decor PNG,
  styled mute control, touch-sized actions, version/decor hidden when compact.
- `scenes/CyberDeckScreen.gd` / `scenes/SettingsScreen.gd` — card padding,
  48px controls, focus-following scrolls, settings top pad.
- `scenes/EndScreen.gd` / `.tscn` — fixed reward line, scrollable stats,
  save-failure warning, compact fonts, touch actions.
- `ui/theme/GameTheme.gd` — real card/glass styleboxes, visible disabled text.
- `ui/controllers/WaveShopModalController.gd` — label/tag layout, 4-line
  descriptions, one-column card height, focus-following scroll.
- `feedback/JuiceManager.gd` — dedicated SFX paths, stop_all, headless silence.
- `assets/sfx/*.ogg` + `tools/audio/generate_sfx.py` + `assets/sfx/README.md`.
- Tests: `tests/ui/InteractionTest.*` (new), hardened
  `ViewportGeometryTest.gd`, `UIRegressionTest.gd`, `PlayerJourneyTest.gd`,
  `tests/audio/sfx_assets.gd`; `tools/verify_game.py` and CI include the new
  gates.
- Capture harness: `tools/qa/capture_screens.gd`,
  `tools/qa/capture_matrix.sh`, `docs/qa/README.md`.

## Verification (actual runs)

All commands run on this workstation, Godot 4.6.2, isolated profile:

```
python3 tools/verify_game.py --all
  PASS script parse gate
  PASS full audit (84/84)
  PASS simulation regression
  PASS UI regression (36)
  PASS player journey (34)
  PASS viewport geometry (328)
  PASS interaction clicks (29)
  PASS speed parity
  PASS save fault injection
  PASS full-run qualification
  PASS audio assets (63)
  PASS verifier exit contract
  PASS early-run smoke
```

Additional measurements:

- `godot --headless -s scripts/benchmark.gd`: 3000 frames after warm-up,
  p50/p95/p99 = 0.608/0.768/0.849 ms, max 0.984 ms, theoretical 1619 FPS
  (simulation/CPU only; not rendered GPU evidence).
- `godot --headless -s tests/simulation/strategy_benchmark.gd`:
  11/30 wins, winning-run ending credits min 1936 / max 6310 / avg 4298.
  This reproduces the documented economy-first outcome (prior baseline 13/30,
  avg 4790) within seed/strategy variation. No tuning applied: no Kivy
  reference is available here and the mission forbids guessing at balance.
- SFX measured with `soundfile`: 0.05–1.40 s, peaks −5 to −14 dBFS, RMS −10.6
  to −24.1 dBFS, zero clipped samples.
- Rendered captures: 112 PNGs across 568×320, 640×360, 800×600, 900×600,
  1024×600, 1280×720, 1280×800, 1440×900, 1600×720 (see
  `docs/qa/captures/`, gitignored). Inspected for clipping, overlap, hitboxes,
  modal stacking, and combat readability at 1× and 3×.

## Remaining gaps / blockers

1. **Android device qualification is blocked.** No Godot Android export
   templates are installed, no `export_presets.cfg` exists, and no device is
   attached (`adb devices` empty). Desktop/Xvfb captures and headless tests are
   the verified surface; do not treat them as Fire/phone density QA.
2. **Safe-area insets** are implemented via `DisplayServer.get_display_safe_area`
   but cannot be exercised on this desktop display; needs device verification.
3. **Audio quality** is validated structurally and by measurement, not by a
   listening panel; subjective fatigue/level tuning remains a device check.
4. **Balance** remains intentionally unchanged; the 37% bot win rate and high
   end-of-run credit surplus are documented, not "fixed" without evidence.
5. **Pixel-perfect visual baselines** are not committed; captures are a
   repeatable inspection workflow, not a pixel-equality gate.
