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
const MIN_TOUCH_HEIGHT: float = 48.0
const TOUCH_HEIGHT: float = 56.0
const PRIMARY_TOUCH_HEIGHT: float = 56.0
const WAVE_SHOP_CARD_MIN_WIDTH: float = 170.0
const WAVE_SHOP_CARD_MIN_HEIGHT: float = 96.0

static func viewport_size(node: Node) -> Vector2:
	if node == null or node.get_viewport() == null:
		return BASE_SIZE
	return node.get_viewport().get_visible_rect().size

static func layout_class(viewport: Vector2) -> String:
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
	var klass: String = layout_class(viewport)
	if klass == LAYOUT_SMALL:
		return 1
	if klass == LAYOUT_MEDIUM:
		return 2
	return 3

static func wave_shop_card_min_size() -> Vector2:
	return Vector2(WAVE_SHOP_CARD_MIN_WIDTH, WAVE_SHOP_CARD_MIN_HEIGHT)

static func shop_strip_needs_compaction(viewport: Vector2, tower_count: int) -> bool:
	var margin: float = edge_margin(viewport)
	var available: float = maxf(0.0, viewport.x - margin * 2.0)
	var desired: float = float(tower_count) * 122.0
	return desired > available

static func is_tablet(viewport: Vector2) -> bool:
	# Amazon Fire tablets are typically 16:10 or 17:10. 
	# Phones are usually much wider (19:9+).
	var aspect = viewport.x / viewport.y if viewport.y > 0 else 1.0
	if viewport.y > viewport.x: aspect = viewport.y / viewport.x # handle portrait
	
	# Large resolution + moderate aspect ratio = Tablet/Desktop
	return viewport.length() > 1000.0 and aspect < 1.8

static func is_tv(viewport: Vector2) -> bool:
	# Fire TV is strictly 16:9 and large resolution
	var aspect = viewport.x / viewport.y if viewport.y > 0 else 1.0
	return viewport.x >= 1920.0 and abs(aspect - 1.777) < 0.1

static func edge_margin(viewport: Vector2) -> float:
	var base = clampf(viewport.x * 0.028, CONTENT_MIN_MARGIN, 42.0)
	return base * 1.4 if is_tablet(viewport) else base

static func top_margin(viewport: Vector2) -> float:
	var base = clampf(viewport.y * 0.022, 12.0, 24.0)
	return base * 1.1 if is_tablet(viewport) else base

static func bottom_margin(viewport: Vector2) -> float:
	var base = clampf(viewport.y * 0.022, 12.0, 24.0)
	return base * 1.1 if is_tablet(viewport) else base

static func content_width(viewport: Vector2, max_width: float = CONTENT_MAX_WIDTH) -> float:
	var margin: float = edge_margin(viewport)
	return minf(max_width, maxf(0.0, viewport.x - margin * 2.0))

static func centered_rect(viewport: Vector2, top: float, bottom: float, max_width: float = CONTENT_MAX_WIDTH) -> Rect2:
	var width: float = content_width(viewport, max_width)
	var height: float = maxf(0.0, viewport.y - top - bottom)
	return Rect2(Vector2((viewport.x - width) * 0.5, top), Vector2(width, height))

static func game_world_rect(viewport: Vector2) -> Rect2:
	var scale: float = minf(viewport.x / BASE_SIZE.x, viewport.y / BASE_SIZE.y)
	scale = minf(scale, 1.0)
	var size: Vector2 = BASE_SIZE * scale
	return Rect2((viewport - size) * 0.5, size)

static func modal_rect(viewport: Vector2, desired: Vector2) -> Rect2:
	var margin: float = edge_margin(viewport)
	var size: Vector2 = Vector2(
		minf(desired.x, maxf(220.0, viewport.x - margin * 2.0)),
		minf(desired.y, maxf(120.0, viewport.y - margin * 2.0))
	)
	return Rect2((viewport - size) * 0.5, size)

static func apply_rect(ctrl: Control, rect: Rect2) -> void:
	if ctrl == null:
		return
	ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ctrl.position = rect.position
	ctrl.size = rect.size
