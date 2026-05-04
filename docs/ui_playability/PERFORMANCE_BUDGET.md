# Performance Budget

Last updated: 2026-05-01

Purpose: keep UI readability work performance-safe before adding any full visual polish. Desktop headless numbers are smoke checks only; Android/Fire device measurements are required before store-readiness claims.

## Non-Negotiable Guardrails

- Do not change tower damage, enemy HP, economy, wave counts, enemy speed, tower range, tower fire rate, or card effects in UI/performance passes.
- Keep `simulation/` free of rendering, input, audio, scene, `Node`, and `Control` coupling.
- Avoid per-enemy `Control` nodes.
- Avoid shader-heavy glow, bloom, or particle-heavy effects until measured.
- Prefer existing batched rendering and simple `CanvasItem` drawing.
- Compare performance before and after effect-heavy changes.

## Desktop Smoke Budget

Required commands:

```powershell
godot --headless --import
godot --headless -s scripts/SimulationBot.gd
godot --headless -s scripts/benchmark.gd
godot --headless -s tests/simulation/regression_checks.gd
```

Current observed smoke baseline from Phase E:

- SimulationBot: seed `71240`, Victory, 10 waves cleared, 7 lives remaining.
- Benchmark: 5000 frames, total execution time `5.065ms`, theoretical FPS `987166.831194472`.
- Regression checks: `PASS: 12`, `FAIL: 0`.

Budget interpretation:
- Any import or regression failure is RED.
- Any SimulationBot failure after UI-only changes is RED until explained.
- A large benchmark regression after rendering/UI work is YELLOW/RED depending on scope and cause.
- Headless benchmark values are not a real FPS promise.

## Android / Fire Manual Budget

Manual TODO until device evidence exists:

- TTFF target: first frame within 2 seconds on cold start where practical.
- TTFD target: ready for core gameplay within 15 seconds.
- Foreground memory target: stay below 1600 MB during core gameplay.
- FPS target: stable and comfortable on target Fire tablet hardware.
- Thermal target: no obvious throttling during a 15-minute core loop.
- Stability target: no crashes, stuck modal states, or hidden blocked controls.

Recommended measurements:

- Cold-start first frame timing.
- Time to first playable/menu-ready state.
- Foreground memory after core loop.
- FPS or frame pacing during:
  - idle map,
  - wave shop,
  - wave 1 placement/combat,
  - crowded late-wave combat,
  - boss/milestone wave.

## Suggested Tooling

Manual/TODO:

- Godot editor/game screenshots at target viewport sizes.
- Android Studio Profiler or Android GPU Inspector for device profiling.
- Perfetto for deeper frame/memory traces if needed.
- `adb shell dumpsys meminfo <package>` for memory snapshots.
- Amazon Fire tablet performance scripts for TTFF, TTFD, and memory iterations if available.

## UI Effect Budget

Allowed before device profiling:

- Slightly larger HP bars.
- Simple `draw_rect`, `draw_line`, `draw_circle`, and text shadow calls.
- Small status pips.
- Layout/container changes that reduce overlap.
- Short UI toasts.

Avoid until measured:

- Per-enemy Control/Label nodes.
- Full-screen shader stacks.
- Bloom/glow post-processing.
- Large particle-count increases.
- Runtime texture generation in active combat.
- Expensive per-frame allocations in render loops.

## Readiness Gates

Full UI polish readiness:
- Requires desktop verification plus manual screenshot/device QA of HUD, wave shop, placement, and combat readability.

Mobile QA readiness:
- Current docs and Phase A-E changes make the project ready to test, but not ready to claim verified mobile quality.

Store-prep readiness:
- Requires Android export review, manifest/device compatibility review, launch timing, memory, and stability evidence.
