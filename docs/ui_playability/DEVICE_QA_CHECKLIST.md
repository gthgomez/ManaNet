# Device QA Checklist

Last updated: 2026-05-01

Purpose: define the manual checks required before claiming mobile or Fire tablet readiness. No physical device or emulator results are recorded here unless explicitly marked with evidence.

## Desktop Verification

Run after every code UI phase:

```powershell
godot --headless --import
godot --headless -s scripts/SimulationBot.gd
godot --headless -s scripts/benchmark.gd
godot --headless -s tests/simulation/regression_checks.gd
git diff --check
```

Boundary checks:

```powershell
rg -n "view_state|start_screen_shake" simulation -g "*.gd" -S
rg -n "preload\\(\"res://(rendering|input|ui)|load\\(\"res://(rendering|input|ui)|extends (Node|Control|Node2D|CanvasLayer)|Button|Label|PanelContainer|CanvasItem|Texture|Sprite" simulation -g "*.gd" -S
git diff -- data simulation
```

## Viewports To Inspect

Manual screenshot/device TODO:

- 16:9 landscape: desktop baseline and Android landscape.
- 16:10 landscape: Fire HD 8/10 style tablet shape.
- 3:2 landscape: large-screen Android tablet/foldable shape.
- Narrow landscape: width below `700` or height below `430` logical px.
- Medium tablet: width below `960` or height below `600` logical px.
- Large tablet/desktop: width at least `960` and height at least `600` logical px.
- Portrait or multi-window: TODO only if Android export allows it.

## Core Play Loop Checks

Manual TODO:

- Start a new run and verify gold, lives, wave, speed, and start-wave controls are readable.
- Place each tower type using tap/click and confirm invalid placement shows a readable reason.
- Verify valid placement preview range is readable.
- Verify invalid placement range preview remains visible and red.
- Start waves 1-3 and confirm the player can read leaks, life loss, projectiles, enemy HP, and status pips.
- Open the wave shop and verify the choose-or-skip gate is obvious.
- Choose each visible wave-shop card and verify the card effect description is not misleading.
- Skip the wave shop and verify the next wave can start.
- Pause, resume, restart confirmation, and quit-to-menu controls are reachable.

## Wave Shop Density Checks

Manual TODO:

- Small layout uses one card column or scrolls without hiding the skip action.
- Medium layout uses two card columns only when descriptions remain readable.
- Large layout can show three cards without clipped essential text.
- `Choose` buttons are at least the documented minimum touch height.
- D-pad/controller focus moves between card choices and the skip action.
- Card IDs/effects are unchanged from `data/wave_shop_cards.gd`.

## Combat Readability Checks

Manual TODO:

- HP bars remain visible at actual tablet viewing distance.
- Shield bars are distinguishable from health bars.
- Frozen/chilled/revealed status pips are visible without covering enemies.
- Projectile trails are visible over map backgrounds.
- Damage numbers are readable during crowded combat.
- Life-loss toast and shake are noticeable but do not hide critical controls.
- Effects remain readable on boss and dense waves.

## Touch Target Checks

Manual TODO:

- Wave button, speed buttons, pause, shop buttons, placement confirm/cancel, wave-shop choose, and skip controls are easy to tap.
- Controls are not under Android navigation/system bars.
- Floating placement confirm/cancel remains inside the viewport.
- No HUD panel blocks normal map placement unexpectedly.

## Fire Tablet Checks

Manual TODO:

- Fire 7 or equivalent small tablet.
- Fire HD 8 class tablet.
- Fire HD 10 or Fire Max 11 class tablet.
- App starts without errors.
- App uses the screen area without cut-off controls.
- Core loop remains usable for at least 15 minutes.
- Foreground memory should be captured after core functionality.

Known warning to monitor:
- `Detected another project.godot at res://android/src/instrumented/assets. The folder will be ignored.`

## Result Recording Template

Use one entry per device or emulator:

```text
Device:
OS / Fire OS:
Build:
Viewport / orientation:
Input method:
TTFF:
TTFD:
FPS observation:
Memory observation:
Wave shop verdict:
HUD/placement verdict:
Combat readability verdict:
Blockers:
Evidence path:
```
