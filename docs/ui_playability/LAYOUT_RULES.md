# UI Layout Rules

Last updated: 2026-05-01

Purpose: convert the research-backed mobile/card-density risks into concrete rules that future UI phases can implement without overbuilding.

## Viewport Classes

The code-level source of truth is `ui/layout/ResponsiveLayout.gd`.

- `small`: viewport width `< 700` or height `< 430`.
  - Represents constrained landscape phones, split-screen windows, and the smallest viable gameplay viewport.
  - Target behavior: one-column modal/card content, compact HUD, avoid side-by-side dense controls unless they scroll or wrap.
- `medium`: viewport width `< 960` or height `< 600`, excluding `small`.
  - Represents Fire 7/8 class constraints and smaller tablet/window sizes.
  - Target behavior: two-column card content where readable, otherwise one-column; primary controls remain 52-56 logical px tall.
- `large`: viewport width `>= 960` and height `>= 600`.
  - Represents Fire HD 10/11, desktop, and TV-like views.
  - Target behavior: three wave-shop cards can sit in one row if descriptions remain readable.

These are logical viewport sizes, not physical device pixels. Real-device QA is still required because density and viewing distance affect readability.

## Tap Target Rules

- Minimum interactive target: `48` logical px high.
- Preferred primary action height: `56` logical px.
- Wave shop card minimum: `170 x 96` logical px before Phase C redesign work.
- Do not shrink primary text below readability just to fit more controls.
- If a row cannot fit within viewport margins, prefer wrapping, scrolling, or a simpler hierarchy.

## Wave Shop Rules

- The choose-or-skip gate must remain visible and obvious.
- Small layout: one card per row or a scrollable/card stack.
- Medium layout: two cards per row only if descriptions fit without truncating essential meaning.
- Large layout: three cards per row allowed.
- Card effects and `card_id` values must not change in UI readability phases.

## HUD and Shop Strip Rules

- The top HUD should remain screen-space and viewport-clamped.
- The shop strip should not require the player to tap under or behind system bars.
- The shop strip currently risks compaction when `tower_count * 122 > viewport_width - margins`.
- If compaction is needed, Phase D should choose one of:
  - horizontal scroll with clear affordance,
  - smaller icon-first tower buttons with readable cost,
  - row wrapping above the bottom safe margin.

## Placement UI Rules

- Placement hints must continue to show valid/invalid state.
- Invalid placement must keep visible range preview and an explicit reason.
- Confirm/cancel controls must use screen-space coordinates and stay inside viewport bounds.
- Avoid raw world-coordinate placement for HUD Controls.

## Combat Readability Rules

- HP/status readability stays in rendering/UI layers, not simulation.
- Prefer drawing through existing `CanvasItem`/MultiMesh-compatible paths.
- Avoid per-enemy `Control` nodes.
- Avoid heavy shaders or particle inflation until measured.

## Phase B Decision

Phase B does not redesign card layout. It establishes viewport classes and target rules so Phase C can safely change wave-shop layout with explicit acceptance criteria.
