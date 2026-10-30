# ManaNet showcase evidence

Captured on 2026-10-30 from game source
[`72746968259ad5f2f2de33f9b4a0d81b4a0af327`](https://github.com/gthgomez/ManaNet/tree/72746968259ad5f2f2de33f9b4a0d81b4a0af327)
with the capture-only driver added in this branch. No game logic or shipped art
was changed. ManaNet is the Godot port of the owner's
[TowerDefenseKivy](https://github.com/gthgomez/TowerDefenseKivy), not an unrelated original implementation.

## What the media shows

| File | Actual recorded state |
| --- | --- |
| `menu.png` | Shipped menu, including the existing branding/art |
| `maps.png` | S-Curve, Gauntlet, and Spiral selection screen |
| `placement.png` | Three archers / Plasma Repeaters purchased for 80 Credits each from the normal 300-Credit starting balance |
| `combat.png` | Active first-wave combat on S-Curve at 1x speed |
| `gameplay.mp4` | 626 real rendered frames at fixed 30 FPS; ~20.87 seconds; audio omitted |
| `gameplay-preview.gif` | An 8 FPS, 600px-wide excerpt from seconds 8–18 of that movie |
| `runtime.json` | Final observed state: wave 1, 3 towers, 3 kills, 124 Credits, 8 Integrity |

The driver scripts the shipped scene transitions, normal-cost placement actions,
and the actual wave-button signal. It dismisses onboarding in the isolated test
session. Simulation, rendering, balances, and combat run through the shipped
code. It does not synthesize frames, inject kills/credits, unlock content, or
claim a human playthrough or a cleared level.

Capture environment: Linux x86_64, official Godot **4.6.2**
(`71f334935`), Xorg dummy display at 1280×800, Mesa llvmpipe OpenGL compatibility,
900×600 viewport. Godot Movie Maker records at fixed 30 FPS; the shipped game loop retains its
wall-clock timing, so playback speed is not a real-time measurement. The first
626-frame capture took ~48 seconds wall time. The movie is a rendered demonstration,
not a performance benchmark. Output video is silent.

## Reproduce

Install Godot 4.6.2 and FFmpeg; use a graphical desktop session or an isolated
Xorg/Xvfb display with OpenGL software rendering. From the repository root:

```sh
GODOT_BIN=/path/to/godot-4.6.2 tools/showcase/capture.sh
```

The wrapper imports resources, runs `tools/showcase/capture.gd` with Godot Movie
Maker, encodes the temporary AVI into a small H.264 MP4, and extracts the GIF.
Temporary XDG data/config/cache directories isolate the operator's saves. It
replaces the showcase PNG/movie/JSON files intentionally. Regenerate provenance
when changing media; do not imply old hashes certify a new capture.

For this capture the same Godot Movie Maker and FFmpeg commands were run directly
with isolated XDG directories, then the complete checked-in shell wrapper was
rerun successfully with fresh isolated directories (~34 seconds wall time).
The final published media and `runtime.json` come from that wrapper run.
The initial capture-driver attempt used a
nonexistent statistics property; that error was corrected to the shipped
`stat_enemies_killed` and the complete recording reran with exit 0. An external
X11 grab was discarded; published video comes from Godot's own movie writer.

## Verification and limits

- Pinned-engine import and `python3 tools/verify_game.py`: **81 PASS, 0 WARN, 0 FAIL**, exit 0.
- Final scripted runtime capture: exit 0; all four screenshots written and actual combat kills observed.
- MP4/GIF decoding, dimensions, file sizes, hashes, and visual frame inspection are checked for this showcase.
- No Android export, physical-device, touch, audio playback, multiplayer, store, or hosted-demo check is claimed.
- This documentation/media work does not change the proprietary [license](../../LICENSE).
