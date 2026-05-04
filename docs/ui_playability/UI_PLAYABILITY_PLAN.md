# UI Playability Improvement Plan

Last updated: 2026-05-01

Status: Phase G complete. UI/playability v1 is ready for mobile device QA, but not ready for full visual polish or store-prep signoff without device evidence.

Primary evidence:
- `docs/ui_playability/2026_research_notes.md`
- `docs/ui_playability/LAYOUT_RULES.md`
- `docs/ui_playability/DEVICE_QA_CHECKLIST.md`
- `docs/ui_playability/PERFORMANCE_BUDGET.md`
- `docs/ui_playability/PHASE_LOG.md`
- `scenes/GameScreen.gd`
- `ui/layout/ResponsiveLayout.gd`
- `rendering/GameRenderer.gd`
- `input/InputController.gd`

## 1. Current Game UI Status

The game loop is playable and mechanically stable. SimulationBot seed `71240` clears 10 waves, regression checks pass, and `simulation/` remains UI-free.

Current player-facing strengths:
- Tower placement now has live valid/invalid banner text.
- Invalid drag placement now produces a UI toast.
- Invalid placement still shows a red range preview.
- Pending invalid placement explains why it cannot be confirmed.
- Floating placement confirm controls are converted from world position to screen position and clamped to viewport.
- Wave shop copy now makes the choose-or-skip gate clearer.
- Wave shop cards now use a responsive grid with separate title, description, and choose action.
- Wave shop skip now reads as a full primary continue action with the next wave number.
- HUD and placement controls now use the documented touch-height helpers for key actions.
- Placement banner text now wraps inside a wider viewport-clamped container.
- Combat rendering now uses larger HP/shield bars, status pips, clearer projectile trails, and more legible damage numbers.
- Combat uses batched rendering paths for enemies, towers, and projectiles.
- Phase B now documents viewport classes, tap-target rules, wave-shop density rules, and shop-strip compaction risk.
- `ResponsiveLayout.gd` now exposes non-invasive helpers for layout class, touch height, wave-shop card columns, card minimum size, and shop-strip compaction checks.

Current player-facing risks:
- `GameScreen.gd` still uses several fixed widths/heights in the HUD and wave shop.
- Shop strip behavior on narrow landscape widths is documented, but full compaction is not yet implemented.
- Combat HP/status readability has a rendering-only v1 pass, but still needs real screen/device QA.
- Fire tablet performance and launch/readiness metrics are documented, but not yet measured on a physical device.
- Final readiness gate is YELLOW until Android/Fire screenshots, touch checks, launch timing, memory, and FPS observations are recorded.

## 2. Non-Negotiable Project Constraints

- Do not change tower damage.
- Do not change enemy HP.
- Do not change economy.
- Do not change wave counts.
- Do not change enemy speed.
- Do not change tower range or fire rate.
- Do not change card effects.
- Do not move folders unless absolutely required.
- Do not perform a large architecture refactor.
- Keep `simulation/` UI-free.
- Do not add `Node`, `Control`, rendering, input, audio, scene, or `ViewState` coupling to `simulation/`.
- Keep every phase small and reviewable.
- Prefer clarity, readability, and device usability over decoration.
- Do not claim real-device QA unless a real device or emulator check was actually run.

## 3. Source-Backed Principles

From `2026_research_notes.md`:

- Use viewport-aware Control layout for HUD and modals; fixed pixel placement is fragile across phones, tablets, and user scaling.
- Prefer Godot Containers, size flags, wrapping, or scrolling for dense UI such as shop and wave-shop cards.
- Use screen-space layout for HUD and world-space drawing only for map/combat/ghost visuals.
- Target at least 48 logical px for tappable controls, with 52-56 px for primary choices when space allows.
- Test 16:9, 16:10, 3:2, and phone-wide landscape shapes before declaring UI polish-ready.
- Keep readability effects compatible with existing batched rendering; do not replace enemies/towers/projectiles with many per-actor UI nodes.
- Measure performance before and after effect-heavy changes; desktop headless checks do not replace Fire tablet profiling.
- Amazon Appstore criteria require clear success/failure indication and a UX that does not confuse users.

## 4. Phase List

### Phase A - Commit/Verify Current UI Clarity Pass

Goal:
- Preserve the placement banner, invalid placement hints, invalid range preview, confirm-bar clamping, and wave-shop copy improvements.

Current status:
- Complete. Commit: `f83c1d28ff9f8f942c81fabda324b3bc7727e646`.

Likely files touched:
- `input/InputController.gd`
- `rendering/GameRenderer.gd`
- `scenes/GameScreen.gd`

Acceptance criteria:
- Current UI clarity changes are committed.
- Only the intended UI/input/rendering files changed.
- Godot import, SimulationBot, benchmark, and regression checks pass.

Verification commands:
- `git status --short`
- `git diff --stat`
- `git diff --check`
- `godot --headless --import`
- `godot --headless -s scripts/SimulationBot.gd`
- `godot --headless -s scripts/benchmark.gd`
- `godot --headless -s tests/simulation/regression_checks.gd`

Rollback criteria:
- Revert Phase A commit if UI scripts fail import or headless gameplay behavior changes unexpectedly.

### Phase B - Mobile Layout/Card Density Audit and Docs

Goal:
- Turn mobile/card risks into concrete layout rules and lightweight code checks.

Current status:
- Complete. Commit: `06109b3247eb65ce4baf9b92cdd6e2b3ebe2b9fd`.

Allowed implementation:
- Add or update docs.
- Add non-invasive layout constants/helpers.
- Add comments explaining layout assumptions.
- Make only small safe UI adjustments directly supported by the plan.

Likely files touched:
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`
- `ui/layout/ResponsiveLayout.gd`
- optionally `scenes/GameScreen.gd` only for comments or tiny safe layout use of helpers.

Acceptance criteria:
- [x] Viewport classes are documented and available in code.
- [x] Minimum tap-target and modal/card density rules are documented.
- [x] No full card redesign.
- [x] No simulation files modified.
- [x] Verification and boundary checks pass.

Verification commands:
- `godot --headless --import`
- `godot --headless -s scripts/SimulationBot.gd`
- `godot --headless -s scripts/benchmark.gd`
- `godot --headless -s tests/simulation/regression_checks.gd`
- `git diff --check`
- Boundary grep for UI/rendering coupling in `simulation/`.

Rollback criteria:
- Revert Phase B if layout helpers break script import or if any simulation file changes.

### Phase C - Wave Shop Card Readability v1

Goal:
- Reduce wave-shop density and improve card hierarchy while preserving every card effect exactly.

Current status:
- Complete. Commit: `f5af7ad7095601be172c191302619202f05830cd`.

Likely files touched:
- `scenes/GameScreen.gd`
- maybe `ui/theme/GameTheme.gd` only if existing button/label styles are insufficient.
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

Acceptance criteria:
- [x] Three cards remain selectable.
- [x] Card label and description are visually separated.
- [x] Skip/continue remains clear.
- [x] Tap targets remain at or above the documented minimum.
- [x] No changes to `data/wave_shop_cards.gd` card effects.

Verification commands:
- Standard Godot import/simulation/benchmark/regression suite.
- `git diff -- data/wave_shop_cards.gd simulation`
- `git diff --check`
- Boundary grep.

Rollback criteria:
- Revert Phase C if card selection fails, card IDs are changed, descriptions become materially misleading, or mobile sizing regresses.

### Phase D - HUD and Placement Ergonomics v1

Goal:
- Improve HUD spacing, placement banner readability, and confirm/cancel usability without changing gameplay.

Current status:
- Complete. Commit: `3abe572816257927a626424971a391367433a9c4`.

Likely files touched:
- `scenes/GameScreen.gd`
- `ui/layout/ResponsiveLayout.gd`
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

Acceptance criteria:
- [x] Placement banner text remains visible and does not overlap top controls.
- [x] Confirm/cancel placement UI stays within viewport.
- [x] Shop, wave button, speed buttons, and top bar have documented spacing behavior.
- [x] No raw world-coordinate HUD placement unless converted to screen space.

Verification commands:
- Standard Godot import/simulation/benchmark/regression suite.
- `git diff --check`
- Boundary grep.

Rollback criteria:
- Revert Phase D if HUD captures block valid map placement, controls overlap, or input dispatch changes gameplay behavior.

### Phase E - Combat Readability v1

Goal:
- Improve HP/status/leak/fired-hit readability with performance-safe rendering/UI feedback.

Current status:
- Complete. Commit: `5d85a6da18ae90dda7f53fb9c7d6a2b46676949e`.

Likely files touched:
- `rendering/GameRenderer.gd`
- maybe `scenes/GameScreen.gd` for UI-only feedback.
- `docs/ui_playability/UI_PLAYABILITY_PLAN.md`
- `docs/ui_playability/PHASE_LOG.md`

Acceptance criteria:
- [x] HP/status information is easier to read.
- [x] Leak/life-loss feedback is clear.
- [x] Feedback remains in rendering/UI layers.
- [x] No combat math changes.
- [x] No excessive particles, per-enemy Control nodes, heavy shaders, or per-frame allocation-heavy structures.

Verification commands:
- Standard Godot import/simulation/benchmark/regression suite.
- `git diff -- data simulation`
- `git diff --check`
- Boundary grep.

Rollback criteria:
- Revert Phase E if benchmark regresses materially, import fails, or any combat stat/math changes.

### Phase F - Device/Performance QA Harness

Goal:
- Document desktop and Android/Fire tablet QA procedures without faking unavailable device results.

Current status:
- Complete. Commit: `e10603a39059b1de68646e9a5ad7055320559e1d`.

Likely files touched:
- `docs/ui_playability/DEVICE_QA_CHECKLIST.md`
- `docs/ui_playability/PERFORMANCE_BUDGET.md`
- `docs/ui_playability/PHASE_LOG.md`

Acceptance criteria:
- [x] Desktop verification commands are listed.
- [x] Android/Fire tablet manual checklist covers screen sizes, touch targets, wave-shop density, HP/status, TTFF, TTFD, memory, and FPS.
- [x] Physical device checks are marked TODO/manual unless actually run.
- [x] Known warnings, such as nested Android `project.godot`, are documented if still present.

Verification commands:
- `git diff --check`
- Optional standard Godot suite if docs are the only changed files.

Rollback criteria:
- Revert Phase F if docs imply unrun device results or conflict with project constraints.

### Phase G - Final Review and Polish Readiness Gate

Goal:
- Decide whether the game is ready for a full visual polish pass.

Current status:
- Complete. Verdict: YELLOW.

Likely files touched:
- `docs/ui_playability/PHASE_LOG.md`
- optionally `docs/ui_playability/UI_PLAYABILITY_PLAN.md`

Acceptance criteria:
- [x] Final GREEN/YELLOW/RED verdict includes evidence.
- [x] Remaining mobile/performance risks are explicit.
- [x] Next prompt is concrete.
- [x] No code changes unless a tiny doc-related correction is required.

Verification commands:
- `git status --short`
- Standard suite if code has changed since last phase.

Rollback criteria:
- Revert only if final docs contain false claims or unverified device results.

## 5. Acceptance Criteria Per Phase

Each phase is GREEN only if:
- Scope stays within that phase.
- No forbidden balance/stat/card-effect changes appear in diff.
- `simulation/` remains UI-free.
- Required verification passes.
- Docs are updated with what changed and remaining risk.
- The phase is committed locally.

YELLOW means:
- Implementation is correct but requires manual/device QA before proceeding.
- Verification passes but risk is not resolved enough for the next implementation phase.

RED means:
- Verification fails.
- Simulation/UI boundary is violated.
- Gameplay/balance data is modified.
- The phase expanded beyond the approved scope.

## 6. Verification Commands Per Phase

Default code-phase suite:

```powershell
godot --headless --import
godot --headless -s scripts/SimulationBot.gd
godot --headless -s scripts/benchmark.gd
godot --headless -s tests/simulation/regression_checks.gd
git diff --check
```

Default boundary suite:

```powershell
rg -n "view_state|start_screen_shake" simulation -g "*.gd" -S
rg -n "preload\\(\"res://(rendering|input|ui)|load\\(\"res://(rendering|input|ui)|extends (Node|Control|Node2D|CanvasLayer)|Button|Label|PanelContainer|CanvasItem|Texture|Sprite" simulation -g "*.gd" -S
```

Default no-balance suite:

```powershell
git diff -- data simulation
```

## 7. Rollback Criteria Per Phase

- Any failed Godot import after code changes: stop and fix or revert the phase.
- Any failing SimulationBot/regression check after UI-only changes: stop and inspect for unintended coupling.
- Any `simulation/` UI reference: stop and remove before continuing.
- Any card-effect or combat/economy stat diff: stop and revert that part.
- Any unverified real-device claim in docs: correct docs before committing.

## 8. Files Likely Touched Per Phase

- Phase A: `input/InputController.gd`, `rendering/GameRenderer.gd`, `scenes/GameScreen.gd`
- Phase B: docs, `ui/layout/ResponsiveLayout.gd`
- Phase C: `scenes/GameScreen.gd`, maybe `ui/theme/GameTheme.gd`
- Phase D: `scenes/GameScreen.gd`, `ui/layout/ResponsiveLayout.gd`
- Phase E: `rendering/GameRenderer.gd`, maybe `scenes/GameScreen.gd`
- Phase F: docs only
- Phase G: docs only unless final verification reveals a tiny correction

## 9. Risks and Mitigations

- **Risk:** Wave shop density fixes become a redesign.  
  **Mitigation:** Phase C is limited to hierarchy, tap targets, and responsive sizing.

- **Risk:** Mobile HUD fixes break desktop layout.  
  **Mitigation:** Centralize rules in `ResponsiveLayout.gd` and verify multiple viewport classes manually where possible.

- **Risk:** Combat readability effects hurt performance.  
  **Mitigation:** Keep effects in existing drawing paths, avoid per-enemy UI nodes, and compare benchmark output.

- **Risk:** Headless checks miss visual overlap.  
  **Mitigation:** Document manual screenshot/device QA requirements and do not mark device status GREEN without evidence.

- **Risk:** Future agents use research as permission to overbuild.  
  **Mitigation:** Keep constraints and "what not to do" in this plan and phase log.

## 10. What Not To Do Yet

- Do not perform a full visual redesign.
- Do not add new mechanics or card effects.
- Do not extract large systems.
- Do not move folders.
- Do not tune balance.
- Do not add shader-heavy, particle-heavy, or bloom-style effects without profiling.
- Do not replace batched rendering with many per-actor UI nodes.
- Do not treat desktop headless pass as Fire tablet QA.
- Do not proceed from a YELLOW phase to the next implementation phase.
