# Visual QA — screenshot and interaction evidence

This directory holds the repeatable rendered-game capture workflow. Captures
themselves are generated locally and are gitignored; the scripts and this
document are committed.

## Why

Headless tests prove layout math and state transitions, not pixels. The capture
harness mounts the shipped scenes under a real display (Xvfb is fine), drives
the real controls/state, and saves a PNG per screen at every supported logical
viewport size.

## Run

```bash
# One-time: a graphical display. On a headless host:
#   sudo apt install xvfb   (already present on the CI image used here)

# Capture the matrix (writes docs/qa/captures/<size>/<scenario>/*.png)
QA_SIZES="568x320 640x360 800x600 900x600 1024x600 1280x720 1280x800 1440x900 1600x720" \
  xvfb-run -a -s "-screen 0 1920x1080x24" \
  tools/qa/capture_matrix.sh docs/qa/captures

# A subset while iterating
QA_SIZES="568x320 900x600" xvfb-run -a -s "-screen 0 1920x1080x24" \
  tools/qa/capture_matrix.sh docs/qa/captures maps game_selected game_pause end_win
```

Every capture process uses a temporary `MANANET_PROFILE_PATH` and XDG dirs, so
no player save is read or written. The harness forces the window size to be the
logical viewport size (the same trick as `ViewportGeometryTest`); otherwise
Godot's stretch setting renders the 900×600 design scaled down and hides real
short-screen defects.

## Scenarios

`menu`, `menu_returning`, `maps`, `maps_modifiers`, `maps_modifiers_all`,
`settings`, `cyberdeck_shop`, `cyberdeck_variants`, `game_start`,
`game_selected`, `game_details`, `game_placement`, `game_wave_shop`,
`game_promotion`, `game_combat`, `game_combat_3x`, `game_boss`, `game_pause`,
`end_win`, `end_loss`, `end_save_fail`.

## How to judge a capture

- Primary actions (map PLAY, Start Wave, Choose/Skip, pause actions, end-screen
  actions) must be inside the viewport without scrolling; secondary lists may
  scroll.
- No label may be cut mid-character or hidden under a panel. Scroll regions must
  show an affordance (scrollbar or partial next row).
- Modal content must be dimmed behind, inside safe bounds, and above the HUD.
- Buttons must be at least 48 logical px tall and their visual and hit boxes must
  match the same rect.
- Combat must remain readable at 1×, 2× and 3× (`game_combat`, `game_combat_3x`).

## Limits

These captures are desktop/OpenGL (`llvmpipe`) evidence. They do not replace
Android/Fire tablet density, safe-area, touch, thermal or performance QA.
Portrait is intentionally not a supported gameplay mode and is not captured as
a playable configuration.
