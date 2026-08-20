class_name TDResponsiveLayout

const BASE_SIZE: Vector2 = Vector2(900.0, 600.0)
const BG_COLOR: Color = Color(0.015, 0.018, 0.028, 1.0)
const CONTENT_MAX_WIDTH: float = 1360.0
const CONTENT_MIN_MARGIN: float = 20.0
const LAYOUT_SMALL: String = "small"
const LAYOUT_MEDIUM: String = "medium"
const LAYOUT_LARGE: String = "large"
const SMALL_MAX_WIDTH: float = 700.0
const SMALL_MAX_HEIGHT: float = 430.0
const MEDIUM_MAX_WIDTH: float = 960.0
const MEDIUM_MAX_HEIGHT: float = 600.0
const SHORT_HEIGHT_MAX: float = 640.0
const PHONE_ULTRAWIDE_ASPECT: float = 1.85
const MIN_TOUCH_HEIGHT: float = 48.0
const TOUCH_HEIGHT: float = 56.0
const PRIMARY_TOUCH_HEIGHT: float = 56.0
const WAVE_SHOP_CARD_MIN_WIDTH: float = 170.0
const WAVE_SHOP_CARD_MIN_HEIGHT: float = 96.0
const SAFE_INSET_CAP_RATIO: float = 0.14

static func viewport_size(node: Node) -> Vector2:
	if node == null or node.get_viewport() == null:
		return BASE_SIZE
	return node.get_viewport().get_visible_rect().size

## Logical safe-area insets (left, top, right, bottom) in viewport pixels.
static func compute_safe_insets(node: Node, viewport: Vector2) -> Vector4:
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		return Vector4.ZERO
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var win_pos: Vector2i = DisplayServer.window_get_position()
	var win_rect := Rect2i(win_pos, window_size)
	var inter: Rect2i = safe.intersection(win_rect)
	var left_px: float
	var top_px: float
	var right_px: float
	var bottom_px: float
	if inter.size.x > 0 and inter.size.y > 0:
		left_px = float(inter.position.x - win_rect.position.x)
		top_px = float(inter.position.y - win_rect.position.y)
		right_px = float(win_rect.end.x - inter.end.x)
		bottom_px = float(win_rect.end.y - inter.end.y)
	else:
		# Fallback: ratio of full-screen safe rect (handles some multi-window edge cases).
		var screen: Vector2i = DisplayServer.screen_get_size()
		if screen.x <= 0 or screen.y <= 0:
			return Vector4.ZERO
		left_px = float(safe.position.x) * float(window_size.x) / float(screen.x)
		top_px = float(safe.position.y) * float(window_size.y) / float(screen.y)
		right_px = float(screen.x - safe.end.x) * float(window_size.x) / float(screen.x)
		bottom_px = float(screen.y - safe.end.y) * float(window_size.y) / float(screen.y)
	var sx: float = viewport.x / float(window_size.x)
	var sy: float = viewport.y / float(window_size.y)
	var left: float = clampf(left_px * sx, 0.0, viewport.x * SAFE_INSET_CAP_RATIO)
	var top: float = clampf(top_px * sy, 0.0, viewport.y * SAFE_INSET_CAP_RATIO)
	var right: float = clampf(right_px * sx, 0.0, viewport.x * SAFE_INSET_CAP_RATIO)
	var bottom: float = clampf(bottom_px * sy, 0.0, viewport.y * SAFE_INSET_CAP_RATIO)
	# Silence unused-node warning while keeping a stable call signature for future Window APIs.
	if node != null:
		pass
	return Vector4(left, top, right, bottom)

## Returns { "left", "top", "right", "bottom" } combining base margins and safe area.
static func content_margins(viewport: Vector2, node: Node = null) -> Dictionary:
	var insets: Vector4 = compute_safe_insets(node, viewport)
	var base_edge: float = clampf(viewport.x * 0.028, CONTENT_MIN_MARGIN, 42.0)
	if is_tablet(viewport):
		base_edge *= 1.4
	var base_top: float = clampf(viewport.y * 0.022, 12.0, 24.0)
	var base_bottom: float = clampf(viewport.y * 0.022, 12.0, 24.0)
	if is_tablet(viewport):
		base_top *= 1.1
		base_bottom *= 1.1
	if is_phone_ultrawide(viewport) or is_short_height(viewport):
		base_edge = maxf(base_edge, 16.0)
		base_top = maxf(base_top, 10.0)
		base_bottom = maxf(base_bottom, 10.0)
	return {
		"left": maxf(base_edge, insets.x),
		"top": maxf(base_top, insets.y),
		"right": maxf(base_edge, insets.z),
		"bottom": maxf(base_bottom, insets.w),
	}

static func available_content_rect(viewport: Vector2, node: Node = null) -> Rect2:
	var m: Dictionary = content_margins(viewport, node)
	var left: float = float(m["left"])
	var top: float = float(m["top"])
	var right: float = float(m["right"])
	var bottom: float = float(m["bottom"])
	return Rect2(
		Vector2(left, top),
		Vector2(maxf(0.0, viewport.x - left - right), maxf(0.0, viewport.y - top - bottom))
	)

static func is_short_height(viewport: Vector2) -> bool:
	return viewport.y > 0.0 and viewport.y < SHORT_HEIGHT_MAX

static func is_phone_ultrawide(viewport: Vector2) -> bool:
	# Ultra-wide phone landscape (e.g. S25 Ultra ~1300x600 logical): short height + wide aspect.
	var w: float = maxf(viewport.x, viewport.y)
	var h: float = minf(viewport.x, viewport.y)
	if h <= 1.0:
		return false
	return h <= SHORT_HEIGHT_MAX and (w / h) >= PHONE_ULTRAWIDE_ASPECT

static func layout_class(viewport: Vector2) -> String:
	# Height-first: short / ultra-wide phones must not inherit tablet "large" rules.
	if is_phone_ultrawide(viewport) or is_short_height(viewport):
		if viewport.x < SMALL_MAX_WIDTH or viewport.y < SMALL_MAX_HEIGHT:
			return LAYOUT_SMALL
		return LAYOUT_MEDIUM
	if viewport.x < SMALL_MAX_WIDTH or viewport.y < SMALL_MAX_HEIGHT:
		return LAYOUT_SMALL
	if viewport.x < MEDIUM_MAX_WIDTH or viewport.y < MEDIUM_MAX_HEIGHT:
		return LAYOUT_MEDIUM
	return LAYOUT_LARGE

static func is_small(viewport: Vector2) -> bool:
	return layout_class(viewport) == LAYOUT_SMALL

static func is_medium(viewport: Vector2) -> bool:
	return layout_class(viewport) == LAYOUT_MEDIUM

static func is_large(viewport: Vector2) -> bool:
	return layout_class(viewport) == LAYOUT_LARGE

static func min_touch_height(primary: bool = false) -> float:
	return PRIMARY_TOUCH_HEIGHT if primary else MIN_TOUCH_HEIGHT

static func wave_shop_card_columns(viewport: Vector2) -> int:
	# Phone / short-height: never force 3 dense columns (S25 Ultra class).
	if is_phone_ultrawide(viewport) or is_short_height(viewport):
		if viewport.y < SMALL_MAX_HEIGHT or viewport.x < 520.0:
			return 1
		return 2
	var klass: String = layout_class(viewport)
	if klass == LAYOUT_SMALL:
		return 1
	if klass == LAYOUT_MEDIUM:
		return 2
	return 3

static func wave_shop_card_min_size() -> Vector2:
	return Vector2(WAVE_SHOP_CARD_MIN_WIDTH, WAVE_SHOP_CARD_MIN_HEIGHT)

static func wave_shop_desired_size(viewport: Vector2, node: Node = null) -> Vector2:
	var cols: int = wave_shop_card_columns(viewport)
	var desired_w: float = 640.0
	if cols == 1:
		desired_w = 340.0
	elif cols == 2:
		desired_w = 520.0
	var desired_h: float = 360.0 if cols < 3 else 300.0
	if is_short_height(viewport) or is_phone_ultrawide(viewport):
		desired_h = minf(desired_h, maxf(240.0, viewport.y * 0.86))
	var avail: Rect2 = available_content_rect(viewport, node)
	return Vector2(
		minf(desired_w, maxf(240.0, avail.size.x)),
		minf(desired_h, maxf(180.0, avail.size.y))
	)

static func shop_strip_needs_compaction(viewport: Vector2, tower_count: int) -> bool:
	var margin: float = edge_margin(viewport)
	var available: float = maxf(0.0, viewport.x - margin * 2.0)
	var desired: float = float(tower_count) * 126.0 + float(max(0, tower_count - 1)) * 6.0
	return desired > available

static func is_tablet(viewport: Vector2) -> bool:
	# Amazon Fire tablets are typically 16:10 or 17:10.
	# Phones are usually much wider (19:9+). Never classify ultra-wide phones as tablets.
	if is_phone_ultrawide(viewport):
		return false
	var aspect = viewport.x / viewport.y if viewport.y > 0 else 1.0
	if viewport.y > viewport.x:
		aspect = viewport.y / viewport.x
	return viewport.length() > 1000.0 and aspect < 1.8

static func is_tv(viewport: Vector2) -> bool:
	var aspect = viewport.x / viewport.y if viewport.y > 0 else 1.0
	return viewport.x >= 1920.0 and abs(aspect - 1.777) < 0.1

static func edge_margin(viewport: Vector2, node: Node = null) -> float:
	var m: Dictionary = content_margins(viewport, node)
	return maxf(float(m["left"]), float(m["right"]))

static func top_margin(viewport: Vector2, node: Node = null) -> float:
	return float(content_margins(viewport, node)["top"])

static func bottom_margin(viewport: Vector2, node: Node = null) -> float:
	return float(content_margins(viewport, node)["bottom"])

static func content_width(viewport: Vector2, max_width: float = CONTENT_MAX_WIDTH, node: Node = null) -> float:
	var m: Dictionary = content_margins(viewport, node)
	return minf(max_width, maxf(0.0, viewport.x - float(m["left"]) - float(m["right"])))

static func centered_rect(viewport: Vector2, top: float, bottom: float, max_width: float = CONTENT_MAX_WIDTH, node: Node = null) -> Rect2:
	var m: Dictionary = content_margins(viewport, node)
	var left: float = float(m["left"])
	var right: float = float(m["right"])
	var width: float = minf(max_width, maxf(0.0, viewport.x - left - right))
	var height: float = maxf(0.0, viewport.y - top - bottom)
	return Rect2(Vector2(left + (viewport.x - left - right - width) * 0.5, top), Vector2(width, height))

static func game_world_rect(viewport: Vector2) -> Rect2:
	var scale: float = minf(viewport.x / BASE_SIZE.x, viewport.y / BASE_SIZE.y)
	scale = minf(scale, 1.0)
	var size: Vector2 = BASE_SIZE * scale
	return Rect2((viewport - size) * 0.5, size)

## desired is preferred size; result is always fully inside available content rect.
## Optional center_on (e.g. playfield world rect) keeps modals over the map, not side letterboxes.
static func modal_rect(
	viewport: Vector2,
	desired: Vector2,
	node: Node = null,
	center_on: Rect2 = Rect2()
) -> Rect2:
	var avail: Rect2 = available_content_rect(viewport, node)
	var size: Vector2 = Vector2(
		minf(desired.x, maxf(220.0, avail.size.x)),
		minf(desired.y, maxf(120.0, avail.size.y))
	)
	var center: Vector2 = avail.get_center()
	if center_on.size.x > 1.0 and center_on.size.y > 1.0:
		center = center_on.get_center()
	var pos: Vector2 = center - size * 0.5
	pos.x = clampf(pos.x, avail.position.x, maxf(avail.position.x, avail.position.x + avail.size.x - size.x))
	pos.y = clampf(pos.y, avail.position.y, maxf(avail.position.y, avail.position.y + avail.size.y - size.y))
	return Rect2(pos, size)

static func apply_rect(ctrl: Control, rect: Rect2) -> void:
	if ctrl == null:
		return
	ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ctrl.position = rect.position
	ctrl.size = rect.size

## Apply modal size as a hard cap: min size cannot exceed the laid-out rect (prevents overflow).
static func apply_modal(ctrl: Control, rect: Rect2) -> void:
	if ctrl == null:
		return
	# Floor at zero so content cannot force the panel past the available rect.
	ctrl.custom_minimum_size = Vector2.ZERO
	ctrl.clip_contents = true
	apply_rect(ctrl, rect)
