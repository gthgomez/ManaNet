# UI Playability Phase Log

Last updated: 2026-05-01

Purpose: record each UI/playability phase with scope, verification evidence, discovered risks, and the next recommended action. This log is documentation evidence, not a substitute for real-device QA.

## Phase A - Commit/Verify Current UI Clarity Pass

Status: GREEN

Commit:
- `f83c1d28ff9f8f942c81fabda324b3bc7727e646` - `ui: improve placement and wave shop clarity`

Files changed:
- `input/InputController.gd`
- `rendering/GameRenderer.gd`
- `scenes/GameScreen.gd`

What changed:
- Preserved and committed the existing placement clarity pass.
- Added live valid/invalid placement banner text.
- Kept invalid placement range preview visible and red.
- Routed invalid drag release through a UI-only placement failure action.
- Improved invalid placement confirm text.
- Clamped floating placement confirm controls inside the viewport.
- Clarified wave-shop choose-or-skip copy.

Verification evidence:
- `godot --headless --import` passed.
- `godot --headless -s scripts/SimulationBot.gd` passed; seed `71240` reached Victory and cleared 10 waves.
- `godot --headless -s scripts/benchmark.gd` passed.
- `godot --headless -s tests/simulation/regression_checks.gd` passed with `PASS: 12`, `FAIL: 0`.
- `git diff --check` passed before commit.

Risks discovered:
- The changes improve placement and shop-state clarity, but they do not solve small-screen card density.
- Headless verification cannot prove touch comfort or visual overlap on Fire tablets.

Next phase recommendation:
- Proceed to Phase B to convert mobile/card-density concerns into explicit layout rules.

## Phase 1 - Research Notes

Status: GREEN

Commit:
- `b63b16cc0e78c0cbd6b418da160ef1bf7856e703` - `docs: add ui playability research notes`

Files changed:
- `docs/ui_playability/2026_research_notes.md`

What changed:
- Recorded official Godot, Android, and Amazon guidance for responsive UI, rendering/performance, large screens, Fire tablet testing, and Appstore criteria.

Verification evidence:
- Documentation-only phase.
- Sources were opened/read before notes were written.

Risks discovered:
- The research supports responsive containers and measured performance, but it does not replace device-specific QA.

Next phase recommendation:
- Proceed to Phase 2 and turn the research into a project-specific implementation plan.

## Phase 2 - Implementation Plan

Status: GREEN

Commit:
- `27cd715037fcd284972f36b64a1c7eb7d91e5354` - `docs: add ui playability implementation plan`

Files changed:
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`

What changed:
- Added a phase-gated UI/playability plan from Phase A through Phase G.
- Captured constraints, source-backed principles, acceptance criteria, verification commands, rollback criteria, risks, and "what not to do yet."

Verification evidence:
- Documentation-only phase.

Risks discovered:
- Future implementation phases need strict scope control to avoid drifting into visual redesign or balance work.

Next phase recommendation:
- Proceed to Phase B only.

## Phase B - Mobile Layout/Card Density Audit and Docs

Status: GREEN

Commit:
- `06109b3247eb65ce4baf9b92cdd6e2b3ebe2b9fd` - `docs: define mobile layout rules`

Files changed:
- `docs/ui_playability/LAYOUT_RULES.md`
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`
- `ui/layout/ResponsiveLayout.gd`

What changed:
- Added explicit viewport classes: `small`, `medium`, and `large`.
- Added code-level layout helpers for viewport class checks, minimum touch height, wave-shop card columns, wave-shop card minimum size, and shop-strip compaction risk.
- Added layout rules for tap targets, wave-shop density, HUD/shop strip behavior, placement UI, and combat readability.
- Updated the plan to mark Phase B complete and Phase C next.

Verification evidence:
- `godot --headless --import` passed; warning observed for nested `res://android/src/instrumented/assets/project.godot`.
- `godot --headless -s scripts/SimulationBot.gd` passed; seed `71240` reached Victory and cleared 10 waves with 7 lives remaining.
- `godot --headless -s scripts/benchmark.gd` passed; 5000 frames, total execution time `5.232ms`, theoretical FPS `955657.49235474`.
- `godot --headless -s tests/simulation/regression_checks.gd` passed with `PASS: 12`, `FAIL: 0`.
- `git diff --check` passed.
- Boundary check found no `view_state` or `start_screen_shake` references in `simulation/`.
- Boundary check found no rendering/input/ui imports or UI node types in `simulation/**/*.gd`.
- `git diff -- data simulation` was empty.

Risks discovered:
- Phase B defines layout rules and helpers only; it does not make the wave-shop cards easier to read yet.
- Shop strip compaction remains a documented risk for narrow viewports.
- Real Fire tablet/device QA has not been run.

Next phase recommendation:
- Proceed to Phase C if the Phase B commit remains clean. Limit Phase C to wave-shop hierarchy, density, skip clarity, and touch targets while preserving card effects exactly.

## Phase C - Wave Shop Card Readability v1

Status: GREEN

Commit:
- `f5af7ad7095601be172c191302619202f05830cd` - `ui: improve wave shop card readability`

Files changed:
- `scenes/GameScreen.gd`
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

What changed:
- Replaced the dense single-row wave-shop card buttons with a responsive `GridContainer` inside a `ScrollContainer`.
- Used Phase B layout helpers to select one, two, or three card columns from the current viewport class.
- Split each card into separate title, description, and `Choose` button controls so labels and effects are easier to scan.
- Raised card action height to the documented minimum touch height.
- Changed skip text to `Skip Bonus - Start Wave N` so the continue action is explicit.
- Preserved card draw count, card IDs, descriptions, and card effect data.

Verification evidence:
- `godot --headless --import` passed; warning observed for nested `res://android/src/instrumented/assets/project.godot`.
- `godot --headless -s scripts/SimulationBot.gd` passed; seed `71240` reached Victory and cleared 10 waves with 7 lives remaining.
- `godot --headless -s scripts/benchmark.gd` passed; 5000 frames, total execution time `4.757ms`, theoretical FPS `1051082.61509355`.
- `godot --headless -s tests/simulation/regression_checks.gd` passed with `PASS: 12`, `FAIL: 0`.
- `git diff --check` passed.
- `git diff -- data/wave_shop_cards.gd simulation` was empty.
- Boundary check found no `view_state` or `start_screen_shake` references in `simulation/`.
- Boundary check found no rendering/input/ui imports or UI node types in `simulation/**/*.gd`.

Risks discovered:
- Headless checks cannot confirm the card grid's visual density on real Fire tablet screens.
- D-pad focus remains on the `Choose` buttons, not the whole card panel; this is acceptable for Phase C but should be checked manually.
- The surrounding HUD/shop strip still uses fixed sizes and remains Phase D work.

Next phase recommendation:
- Proceed to Phase D if the Phase C commit remains clean. Keep the next pass focused on HUD spacing, placement banner readability, confirm/cancel usability, and safe viewport bounds.

## Phase D - HUD and Placement Ergonomics v1

Status: GREEN

Commit:
- `3abe572816257927a626424971a391367433a9c4` - `ui: improve hud placement ergonomics`

Files changed:
- `scenes/GameScreen.gd`
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

What changed:
- Raised pause, speed, wave, tower upgrade, tower action, placement confirm, and placement cancel controls to the Phase B touch-height helper values.
- Made the placement instruction banner wider within viewport margins and enabled smart wrapping/vertical centering.
- Scaled placement banner font through responsive layout rather than leaving it fixed.
- Increased the placement confirmation modal height to fit larger buttons.
- Clamped the floating placement confirm bar to responsive viewport margins.

Verification evidence:
- `godot --headless --import` passed; warning observed for nested `res://android/src/instrumented/assets/project.godot`.
- `godot --headless -s scripts/SimulationBot.gd` passed; seed `71240` reached Victory and cleared 10 waves with 7 lives remaining.
- `godot --headless -s scripts/benchmark.gd` passed; 5000 frames, total execution time `5.135ms`, theoretical FPS `973709.834469328`.
- `godot --headless -s tests/simulation/regression_checks.gd` passed with `PASS: 12`, `FAIL: 0`.
- `git diff --check` passed.
- `git diff -- data simulation` was empty.
- Boundary check found no `view_state` or `start_screen_shake` references in `simulation/`.
- Boundary check found no rendering/input/ui imports or UI node types in `simulation/**/*.gd`.

Risks discovered:
- Full shop-strip compaction is still intentionally deferred; Phase D only improved key fixed controls and placement ergonomics.
- Headless checks cannot prove banner overlap on all physical Fire tablet densities.

Next phase recommendation:
- Proceed to Phase E if the Phase D commit remains clean. Keep combat readability in `rendering/` or UI feedback only and avoid combat math changes.

## Phase E - Combat Readability v1

Status: GREEN

Commit:
- `5d85a6da18ae90dda7f53fb9c7d6a2b46676949e` - `ui: improve combat readability feedback`

Files changed:
- `rendering/GameRenderer.gd`
- `scenes/GameScreen.gd`
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

What changed:
- Enlarged enemy HP bars and extended their visible window after damage.
- Kept HP bars visible while shield/status information is active.
- Added small status pips for frozen/chilled/revealed enemies.
- Strengthened shield-bar contrast and added HP segment ticks.
- Made projectile trails slightly wider/brighter.
- Added a subtle shadow and larger size for damage numbers.
- Added a UI-only life-loss toast alongside the existing screen shake.

Verification evidence:
- `godot --headless --import` passed; warning observed for nested `res://android/src/instrumented/assets/project.godot`.
- `godot --headless -s scripts/SimulationBot.gd` passed; seed `71240` reached Victory and cleared 10 waves with 7 lives remaining.
- `godot --headless -s scripts/benchmark.gd` passed; 5000 frames, total execution time `5.065ms`, theoretical FPS `987166.831194472`.
- `godot --headless -s tests/simulation/regression_checks.gd` passed with `PASS: 12`, `FAIL: 0`.
- `git diff --check` passed.
- `git diff -- data simulation` was empty.
- Boundary check found no `view_state` or `start_screen_shake` references in `simulation/`.
- Boundary check found no rendering/input/ui imports or UI node types in `simulation/**/*.gd`.

Risks discovered:
- The HP/status changes are visually plausible but still unverified on actual tablet pixel density and viewing distance.
- Projectile and damage-number readability should be compared in a real active-combat screenshot before a full polish pass.

Next phase recommendation:
- Proceed to Phase F device/performance QA docs. Mark all unavailable physical-device checks as TODO/manual.

## Phase F - Device/Performance QA Harness

Status: GREEN

Commit:
- `e10603a39059b1de68646e9a5ad7055320559e1d` - `docs: add device qa performance checklist`

Files changed:
- `docs/ui_playability/DEVICE_QA_CHECKLIST.md`
- `docs/ui_playability/PERFORMANCE_BUDGET.md`
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

What changed:
- Added desktop verification and boundary-check commands.
- Added manual viewport, wave-shop density, combat readability, touch target, and Fire tablet checklists.
- Added TTFF, TTFD, FPS, memory, and stability recording templates.
- Added a performance budget that distinguishes desktop smoke checks from real Android/Fire device evidence.
- Documented the nested Android `project.godot` warning as a known item to monitor.

Verification evidence:
- Documentation-only phase.
- `git diff --check` required before commit.

Risks discovered:
- No physical device or emulator QA was run in this phase.
- Device-readiness remains TODO/manual until evidence is recorded.

Next phase recommendation:
- Proceed to Phase G final review and readiness gate. Expect a YELLOW readiness verdict for full polish/store prep until real-device QA is completed.

## Phase G - Final Review and Polish Readiness Gate

Status: YELLOW

Commit:
- Pending at time of log entry.

Files changed:
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

Evidence:
- Phase A through Phase F completed and committed locally.
- Latest code-phase verification from Phase E passed:
  - `godot --headless --import`
  - `godot --headless -s scripts/SimulationBot.gd`
  - `godot --headless -s scripts/benchmark.gd`
  - `godot --headless -s tests/simulation/regression_checks.gd`
  - `git diff --check`
  - no-balance diff
  - simulation/UI boundary grep
- Phase F added device/performance checklists, but no physical device or emulator QA was run.

Readiness verdict:
- Full UI polish: YELLOW. Safe UI clarity foundations are in place, but polish should wait for screenshots/device observations.
- Mobile device QA: GREEN to start. The checklist and budget are ready for manual testing.
- Balance audit: YELLOW. SimulationBot remains stable, but UI work did not validate human balance feel.
- Store-prep pass: RED/YELLOW. Store prep requires Android export, manifest compatibility, launch timing, memory, FPS, and stability evidence.

Remaining risks:
- Shop strip compaction on narrow viewports is documented but not fully implemented.
- Combat readability has only headless/import evidence and needs real screenshots.
- Fire tablet TTFF, TTFD, memory, FPS, and thermal behavior are unmeasured.
- Known nested Android `project.godot` warning still needs a store-prep decision.

Recommended next prompt:
- "Run the TowerDefenseGodot device QA checklist on Android/Fire tablet targets, capture screenshots and timing/memory evidence, then update `docs/ui_playability/PHASE_LOG.md` with findings and decide whether Phase D/E need follow-up fixes."
