# 2026 UI Playability Research Notes

Access date: 2026-05-01

Scope: TowerDefenseGodot player-facing UI, readability, responsive layout, mobile/Fire tablet readiness, and performance-safe visual feedback. This document is source-backed planning input only. It does not authorize balance changes or simulation/UI coupling.

## Source Index

### Godot responsive UI guidance

1. **Godot Engine 4.6 documentation: Multiple resolutions**  
   URL: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html  
   Version/date shown: Godot Engine 4.6 stable documentation; no page-level last-updated date shown.  
   Takeaways:
   - Recommended non-pixel-art setup is `canvas_items` stretch mode with `expand` aspect for multiple aspect ratios. **Recommended.**
   - `expand` makes better use of tall phone screens and varied aspect ratios. **Recommended.**
   - Control anchors should snap HUD elements to the relevant corners/edges when using expandable aspect ratios. **Mandatory for mobile-safe HUD.**
   - UI scale can be exposed for accessibility, and default theme scale matters for readable base sizes. **Recommended.**
   - Viewport stretch scale can reduce rendering resolution for performance, but it changes pixel feel. **Optional for future settings.**
   Project application:
   - Keep the 900x600 simulation/map coordinate system, but screen-space HUD must be driven by viewport-aware layout, not raw world coordinates.
   - The game should test 16:9, 16:10, 3:2, and phone-wide landscape shapes before any full polish pass.

2. **Godot Engine 4.6 documentation: Size and anchors**  
   URL: https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html  
   Version/date shown: Godot Engine 4.6 stable documentation; no page-level last-updated date shown.  
   Takeaways:
   - Devices vary in aspect ratio, resolution, and user scaling; fixed pixel positioning is fragile. **Mandatory.**
   - Anchors define how Control offsets relate to parent size. **Mandatory for top/bottom/side HUD.**
   - Controls can resize with parent changes when opposite anchors differ. **Recommended.**
   - Anchor presets are intended for common alignment cases. **Recommended.**
   Project application:
   - Floating placement confirm UI should continue to convert world positions to screen positions and clamp to viewport.
   - HUD regions should be defined in screen space through `ResponsiveLayout` and containers.

3. **Godot Engine 4.6 documentation: Using Containers**  
   URL: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html  
   Version/date shown: Godot Engine 4.6 stable documentation; no page-level last-updated date shown.  
   Takeaways:
   - Containers take over positioning of child Controls and reflow them on parent resize. **Mandatory for dense HUD/card work.**
   - Size flags such as Fill, Expand, and stretch ratio determine how Controls share space. **Mandatory for responsive cards.**
   - `GridContainer` supports grid layouts; `FlowContainer` wraps children when space runs out. **Recommended for wave shop/card rows.**
   - `AspectRatioContainer` preserves proportions for dynamic layouts. **Optional.**
   Project application:
   - Wave shop cards should move toward container-driven layout instead of hard fixed card widths.
   - Shop/tower buttons need minimum target sizes plus wrapping/scrolling rules for small screens.

### Godot rendering/performance guidance

4. **Godot Engine 4.6 documentation: General optimization tips**  
   URL: https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html  
   Version/date shown: Godot Engine 4.6 stable documentation; no page-level last-updated date shown.  
   Takeaways:
   - Measure performance to identify bottlenecks and verify optimization results. **Mandatory.**
   - Different hardware can shift bottlenecks, especially on mobile. **Mandatory for Fire tablet QA.**
   - CPU profilers do not always reveal GPU bottlenecks; GPU work and OS spikes can dominate. **Recommended.**
   - Optimize the parts that matter; avoid broad premature optimization. **Mandatory for small-phase work.**
   - Performance should be considered at design time. **Recommended.**
   Project application:
   - Add UI clarity effects only if they avoid per-frame allocations and remain simple to profile.
   - Use the existing benchmark as a smoke check, then add manual device checks for actual UI/rendering performance.

5. **Godot Engine 4.6 documentation: MultiMeshInstance2D**  
   URL: https://docs.godotengine.org/en/stable/classes/class_multimeshinstance2d.html  
   Version/date shown: Godot Engine 4.6 stable documentation; no page-level last-updated date shown.  
   Takeaways:
   - `MultiMeshInstance2D` instances a `MultiMesh` in 2D. **Recommended for repeated enemies/projectiles/towers.**
   - It can render faster than many `Sprite2D` nodes with large transparent areas at high viewport resolutions. **Recommended.**
   - It reduces fill-rate waste when meshes fit opaque sprite areas, trading some vertex work. **Optional for deeper asset optimization.**
   Project application:
   - Keep enemy/tower/projectile readability improvements compatible with the existing batched rendering path.
   - Avoid replacing batched actors with many individual Control or Sprite nodes for HP/status.

6. **Godot Engine 4.6 documentation: Overview of renderers**  
   URL: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html  
   Version/date shown: Godot Engine 4.6 stable documentation; no page-level last-updated date shown.  
   Takeaways:
   - Godot 4 has Forward+, Mobile, and Compatibility renderers. **Observed context.**
   - Compatibility targets older or low-end mobile and desktop hardware. **Recommended consideration for Fire coverage.**
   - Mobile is suited to newer mobile devices; Forward+ is desktop-oriented. **Recommended consideration.**
   - Compatibility is usually sufficient for 2D games and can offer broad hardware support. **Recommended consideration.**
   Project application:
   - Do not add visual effects that require advanced renderer features before renderer/device targets are verified.
   - Prefer simple CanvasItem drawing and existing MultiMesh usage for clarity improvements.

### Android large-screen/mobile game guidance

7. **Android Developers: Android game optimization**  
   URL: https://developer.android.com/games/optimize/overview  
   Version/date shown: Last updated 2026-02-26 UTC.  
   Takeaways:
   - Android recommends profiling tools such as Android GPU Inspector, Android Performance Tuner, ADPF, Memory Advice API, Perfetto, CPU Profiler, and meminfo. **Recommended.**
   - The goal is sustainable performance across thermal, CPU, GPU, and memory constraints. **Mandatory for mobile readiness.**
   - Memory and performance diagnostics should use device data, not only desktop assumptions. **Mandatory for store-prep.**
   Project application:
   - Headless Godot checks are necessary but not sufficient for mobile polish signoff.
   - Device QA should include FPS/thermal/memory observations and adb meminfo.

8. **Android Developers: Analyze and optimize game performance**  
   URL: https://developer.android.com/games/optimize/gameperformance  
   Version/date shown: Last updated 2026-03-20 UTC.  
   Takeaways:
   - Measure overall performance per scene before optimizing. **Mandatory.**
   - Determine whether performance is CPU-bound or GPU-bound before choosing fixes. **Mandatory.**
   - Identify scenes/layouts with unexpected CPU/GPU usage. **Recommended.**
   - Verify optimizations by comparing measurements before and after. **Mandatory.**
   Project application:
   - Wave shop, active combat, and crowded wave scenes need separate QA notes.
   - Combat readability effects should be gated by benchmark and future device profiling.

9. **Android Developers: Support large screen resizability**  
   URL: https://developer.android.com/games/develop/multiplatform/support-large-screen-resizability  
   Version/date shown: Last updated 2026-02-26 UTC.  
   Takeaways:
   - Android tablets/foldables on Android 12L+ with width over 600dp may run games in resizable multi-window mode. **Recommended.**
   - Games should explicitly declare resizability or aspect-ratio limits. **Recommended for Android export review.**
   - Landscape games should support at least 16:9; best experience includes 21:9, 16:10, and 3:2. **Recommended.**
   - Test multi-window sizes and ensure gameplay/UI is not cut off or inaccessible. **Mandatory for large-screen readiness.**
   Project application:
   - The project should document target viewport classes before redesigning HUD.
   - Fire tablets should be tested at 16:10 and 3:2-like landscape shapes.

10. **Android Developers: Layout basics**  
    URL: https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-basics  
    Version/date shown: Last updated 2026-04-23 UTC.  
    Takeaways:
    - Consider aspect ratios, size classes, resolutions, landscape, portrait, and form factors. **Mandatory.**
    - Honor safe areas including cutouts, edge-to-edge insets, edge displays, keyboards, and system bars. **Recommended for exported Android.**
    - Keep essential interactions reachable. **Recommended.**
    - Group related content and actions through containment. **Recommended.**
    - Maintain consistent alignment and spacing. **Recommended.**
    Project application:
    - HUD, shop, wave button, and wave shop cards need documented containment and spacing rules.
    - No card redesign should proceed without explicit small/medium/large layout targets.

11. **Android Developers: Make apps more accessible**  
    URL: https://developer.android.com/guide/topics/ui/accessibility/apps  
    Version/date shown: page opened 2026-05-01; no page-level last-updated date visible in opened excerpt.  
    Takeaways:
    - Text contrast should be at least 4.5:1 for smaller text and 3:1 for larger text. **Recommended.**
    - Touch UI should provide at least 48dp x 48dp focusable/tappable area; larger is better. **Mandatory for mobile touch readiness.**
    - UI elements need clear descriptions and distinct purposes. **Recommended.**
    Project application:
    - Godot pixel sizes are not dp, but the project can enforce a practical minimum touch height of about 48 logical px, with larger buttons for Fire tablets.
    - Card and HUD text should avoid small, low-contrast labels.

12. **Android Developers: Screen compatibility overview**  
    URL: https://developer.android.com/guide/practices/screens_support  
    Version/date shown: Last updated 2026-02-26 UTC.  
    Takeaways:
    - Android devices vary by screen size and density. **Mandatory context.**
    - Apps must account for orientation, system decorations, and multi-window changes. **Recommended.**
    - Avoid hardcoded position/size; use flexible layouts that stretch and preserve relative order. **Mandatory.**
    - Use alternative layouts or behavior for different available space. **Recommended.**
    - Preserve physical size across densities with density-independent sizing concepts. **Recommended.**
    Project application:
    - Current hard-coded shop/card/button sizes need breakpoints and/or scroll/wrap rules.
    - Future visual polish should not assume one desktop viewport.

### Amazon Fire tablet testing/performance guidance

13. **Amazon Developer: App Performance Scripts for Fire Tablet**  
    URL: https://developer.amazon.com/docs/app-testing/app-performance-scripts-fire-tablet.html  
    Version/date shown: Last updated Jan 30, 2026.  
    Takeaways:
    - Performance testing should cover compatibility, reliability, speed, response time, stability, and resource usage. **Mandatory for Fire store readiness.**
    - KPIs include TTFF, TTFD, and memory after core functionality. **Mandatory for QA docs.**
    - Recommended iteration counts: TTFF 50, TTFD 10, memory 5. **Recommended.**
    - Fire tablet apps should show first frame within 2 seconds on cold start. **Recommended target.**
    - Gaming apps should be ready to use within 15 seconds; foreground memory should stay under 1600 MB. **Recommended target.**
    - Recommended devices include Fire HD 10 (2023) and Fire Max 11 (2023). **Recommended device targets.**
    Project application:
    - Add manual QA checklists for launch timing, fully drawn state, 15-minute core play memory, and repeated iterations.
    - Do not claim Fire tablet performance without a device run.

14. **Amazon Developer: Test Criteria for Amazon Appstore Apps**  
    URL: https://developer.amazon.com/docs/app-testing/test-criteria.html  
    Version/date shown: Last updated Feb 17, 2026.  
    Takeaways:
    - Amazon expects a simple, well-thought-out UX that does not confuse users. **Mandatory.**
    - Apps should be thoroughly tested and free of crashes/obvious defects. **Mandatory.**
    - User actions should provide visual success/failure indication. **Mandatory.**
    - Unsupported functionality should fail gracefully with useful messaging. **Mandatory.**
    - Fire tablet apps should use the screen area and launch without errors. **Recommended.**
    - If loading exceeds 15 seconds, the app must show loading feedback. **Mandatory if applicable.**
    Project application:
    - Placement success/failure messaging and wave shop gating are store-relevant UX, not decorative polish.
    - Phase work must keep visible failure states and avoid hidden blocked states.

15. **Amazon Developer: Fire Tablet Device Specifications: Overview**  
    URL: https://developer.amazon.com/docs/device-specs/ft-device-specifications.html  
    Version/date shown: Last updated Jan 28, 2026.  
    Takeaways:
    - Fire tablet specs are developer-facing and cover all current and older models. **Recommended reference.**
    - Fire tablets include Fire HD, Fire, and Fire HDX lines. **Observed context.**
    - Consumers may still use discontinued older devices. **Recommended compatibility consideration.**
    - Device lines include 7, 8, 10, and 11 inch classes across generations. **Recommended layout coverage.**
    Project application:
    - Do not optimize only for one desktop or one recent tablet.
    - Minimum viable QA should cover smaller 7/8 inch tablet constraints and larger 10/11 inch Fire tablets.

16. **Amazon Developer: Device Filtering and Compatibility on Fire OS**  
    URL: https://developer.amazon.com/docs/app-submission/device-filtering-and-compatibility.html  
    Version/date shown: Last updated Mar 26, 2026.  
    Takeaways:
    - Use `minSdkVersion` thoughtfully for maximum compatible device coverage. **Recommended for export review.**
    - Manifest permissions can imply required hardware features and reduce device compatibility. **Mandatory for store-prep.**
    - Refer to Fire Tablet specs for target hardware/software capabilities. **Recommended.**
    Project application:
    - UI plans should remain compatible with broad Fire OS targets and not assume unavailable sensors/controllers.
    - Export manifest review belongs to a store-prep pass, not this UI clarity pass.

## Project-Specific Implications

- **Mandatory:** `simulation/` remains UI-free. All readability and feedback improvements stay in `scenes/`, `rendering/`, `input/`, `ui/`, or docs.
- **Mandatory:** Avoid balance-adjacent changes. UI phases must not alter tower damage, enemy HP, economy, wave counts, speed, range, fire rate, or card effects.
- **Mandatory:** Every phase must be verifiable with headless import, SimulationBot, benchmark, regression checks, `git diff --check`, and boundary grep.
- **Recommended:** Establish layout classes before redesign:
  - Small landscape: width < 700 or height < 430 logical px after viewport scaling.
  - Medium landscape / Fire 7-8: 700-959 width or 430-599 height.
  - Large / Fire HD 10-11 / desktop: width >= 960 and height >= 600.
- **Recommended:** Minimum tap target policy:
  - Standard interactive controls: at least 48 logical px high.
  - Primary combat actions and modal choices: 52-56 logical px high when space allows.
  - Dense secondary labels may be smaller, but not primary actions.
- **Recommended:** Prefer container-driven wrapping or scrolling over fixed-width HUD/card rows.
- **Recommended:** Use screen-space layout for HUD and world-space drawing only for map/combat/ghost visuals.
- **Recommended:** Device QA must distinguish "desktop headless passed" from "Fire tablet manual verified."

## Things We Should Avoid

- Do not use research as permission for a full art overhaul.
- Do not add shader-heavy glow, bloom, or particle layers before profiling.
- Do not replace batched enemy/tower rendering with many per-actor UI nodes.
- Do not fix mobile overflow by shrinking text below readable sizes.
- Do not hide wave shop or placement gating behind unclear disabled states.
- Do not document device results that were not actually run.
- Do not add Godot `Node`, `Control`, rendering, input, audio, scene, or view references to `simulation/`.

## Open Questions Requiring Real-Device QA

- Does the Godot export run fullscreen/immersive correctly on Fire OS target devices?
- Are the shop strip, wave button, and instruction banner readable on Fire 7/8 inch landscape screens?
- Does the wave shop fit 3 cards without truncating essential card descriptions on Fire HD 8/10?
- Are enemy HP bars/status effects readable at actual tablet pixel density and viewing distance?
- Do leak/life-loss effects read clearly when many enemies/projectiles are on screen?
- Does the Android exported app meet Amazon TTFF and TTFD expectations?
- What is foreground PSS after 15 minutes of core gameplay on a Fire tablet?
- Is the renderer GPU-bound or CPU-bound on representative Fire tablet hardware?
