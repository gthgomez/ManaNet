# Menu Screen — Audit Gaps

**Status: All 9 items implemented on 2026-04-29.**
See `scenes/MenuScreen.gd` for all implementations.

Items below are documented for reference.
Ordered roughly by visual impact.

---

## 1. Ambient Particles

**What's missing:** No floating ambient particles on the title screen.
Every top-tier mobile strategy game (Clash of Clans, Kingdom Rush: Vengeance,
Bloons 6) has small drifting dots, sparks, or energy motes at 10–15% alpha.

**How to fix:**
Add a `CPUParticles2D` node to the MenuScreen scene (or instantiate in `_ready()`).
Suggested config:
- Amount: 24
- Lifetime: 4.0 s, one-shot: false
- Direction: Vector2(0, -1), spread: 45°
- Initial velocity: 20–40 px/s
- Scale: 2–4 px, random
- Color: `Color(CYAN.r, CYAN.g, CYAN.b, 0.12)` with modulate fade to alpha 0 at end
- Emission shape: Rectangle covering full viewport

**Effort:** Low (30 min). High visual payoff — makes the backdrop feel alive.

---

## 2. Glass Panel Behind VBox Content

**What's missing:** The button group / title area floats directly on the raw
backdrop with no material housing. The Settings screen has a glass panel behind
its content; the main menu does not. The eye has no defined anchor point.

**How to fix:**
In `_apply_layout()`, after calculating the VBox rect, draw a glass-panel
`Panel` node behind it (same pattern as `_ensure_glass()` in SettingsScreen):

```gdscript
func _ensure_glass() -> void:
    if _glass != null:
        return
    _glass = Panel.new()
    _glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_glass)
    move_child(_glass, 2)
    _THEME.apply_glass_panel(_glass)
```

Then in `_apply_layout()`:
```gdscript
_ensure_glass()
var glass_rect := Rect2(Vector2(x - 24.0, y - 16.0), Vector2(width + 48.0, height + 32.0))
_LAYOUT.apply_rect(_glass, glass_rect)
```

**Effort:** Low (20 min). Gives the menu a clean "content card" feel vs.
floating UI on a void.

---

## 3. Dynamic Version String

**What's missing:** `"v7.1.2"` is hardcoded in `_add_version_label()`.
Every time the version bumps, it requires a manual code change.

**How to fix:**
Add a `const VERSION := "v7.1.2"` to a shared `GameConstants.gd` (or
`ProjectSettings.get_setting("application/config/version")`), then reference it:

```gdscript
_version_lbl.text = ProjectSettings.get_setting("application/config/version", "v7.1.2")
```

**Effort:** Trivial (5 min). Eliminates a recurring maintenance debt.

---

## 4. Mute / Audio Toggle

**What's missing:** No audio control on the main menu.
Industry standard since ~2018 — virtually every mobile game has a speaker icon
or SFX/Music toggle accessible from the title screen without entering Settings.

**How to fix:**
Add a small icon-Button (speaker emoji or SVG) anchored top-left or top-right
(next to RP pill) that toggles `AudioServer.set_bus_mute("Master", ...)` and
persists state to `Progression`.

**Effort:** Medium (1–2 hours including icon + persistence).

---

## 5. Logo Texture vs. Text Title

**What's missing:** `"TOWER DEFENSE"` is still rendered as a plain `Label`
with overridden font/outline. The CYAN halo helps, but it still reads as
"text" not "logo". Premium games (and even mid-tier ones post-2022) ship with
a dedicated title logo texture: custom lettering, subtle emboss/extrude, maybe
a thin decorative rule or icon integrated into the wordmark.

**How to fix (two options):**

**Option A (quick):** Load a custom bitmap/SVG font specifically for the title
(`add_theme_font_override("font", preload("res://assets/fonts/TitleFont.ttf"))`).
Even a free military/techy font from Google Fonts dramatically elevates the
logo read.

**Option B (proper):** Create a `title_logo.svg` or `title_logo.png` in
Figma/Inkscape and use a `TextureRect` instead of a Label. This gives full
creative control over letter forms, glow treatment, and sub-elements.

**Effort:** Option A: 30 min. Option B: 2–4 hours (depends on design work).

---

## 6. Returning-Player Re-engagement Hooks

**What's missing:** The last-run stat (Wave X) is now shown, but there is no
deeper pull: no win/loss record, no "Daily Challenge", no unlocked-since-last-
visit indicator, no RP-gain-since-last-visit summary.

**How to fix (incremental):**
- Show a "New content available" badge on the Robo Base button if unspent RP > 0
  (this is partially done via `just_won()` glow — extend the condition).
- Show total wins/losses below the last-run stat:
  `"Wins: X  ·  Losses: Y"` from `profile.get("wins", 0)` / `profile.get("losses", 0)`.
- Eventually: a "Daily Modifier Active" chip that shows the current run modifier
  before the player even taps Play.

**Effort:** Low per item (15–30 min each), depends on what Progression stores.

---

## 7. Tower Showcase Color Tinting

**What's missing:** The four showcase towers (archer, cannon, frost, lightning)
currently render at full white tint (`modulate = Color(1,1,1, 0.82)`). This
looks clean but misses an opportunity for each tower to carry its accent color,
which teaches the player the color vocabulary before the game starts.

**How to fix:**
Assign each tower its gameplay color as a soft modulate tint:
```gdscript
var tints := [
    Color(0.90, 0.82, 0.60, 0.82),  # archer  — warm parchment
    Color(0.85, 0.55, 0.30, 0.82),  # cannon  — burnt orange
    Color(0.55, 0.80, 1.00, 0.82),  # frost   — ice blue
    Color(0.85, 0.92, 0.40, 0.82),  # lightning — electric yellow
]
```

**Effort:** Trivial (10 min).

---

## 8. Map Select / Play Button Micro-context

**What's missing:** The Play button has no context text. In 2026-standard mobile
games, primary CTAs often carry micro-copy under or within them:
`PLAY  ↓  (15 waves · Normal)` or a small tag showing the last selected map.

**How to fix:**
Add a `RichTextLabel` as a child of `PlayBtn` positioned below the text, or
use `Button.text` with a newline and smaller second line. Requires a custom
font_size for the second line, which Godot's default Button doesn't support
natively — use a `VBoxContainer` inside a styled `PanelContainer` as a
button-replacement (or subclass Button and override `_draw()`).

**Effort:** Medium (1–2 hours for a clean implementation).

---

## 9. Screen Reader / Accessibility Pass

**What's missing:** No `focus_mode`, `tooltip_text`, or accessibility metadata
on any menu elements. Not a visual gap, but required for platform certification
on Amazon Fire TV and increasingly expected on Android.

**How to fix:**
- Set `tooltip_text` on all Buttons.
- Ensure all interactive elements have `focus_mode = FOCUS_ALL`.
- Add `AccessibilityHandler` autoload (future task) that maps D-pad to focus
  navigation (FocusManager already partially handles this).

**Effort:** Low-Medium (2–3 hours for a thorough pass).

---

*Generated: 2026-04-29 — based on audit against 2026 AAA mobile menu standards.*
*Implemented in the same pass: tower showcase, RP pill, last-run stat, version corner, title CYAN glow.*
