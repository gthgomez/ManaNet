extends Control
class_name CorporateDistrictBackdrop

## Layered 2.5D corporate-defense plaza for menu / map-select screens.
## Matches Nov 2026 reference composition: Arcana façade left, holo billboard
## right, skyline depth, foreground plaza + showcase towers.

const _THEME := preload("res://ui/theme/GameTheme.gd")
const _CUTOUT := preload("res://assets/shaders/tower_cutout.gdshader")

const _TOWER_PATHS: Array[String] = [
	"res://assets/sprites/production/towers/plasma_repeater.svg",
	"res://assets/sprites/production/towers/nova_bombard.svg",
	"res://assets/sprites/production/towers/tesla_spire.svg",
]

var _time: float = 0.0
var _flicker: float = 1.0
var _tower_views: Array[TextureRect] = []
var _holo_phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for path in _TOWER_PATHS:
		if ResourceLoader.exists(path, "Texture2D"):
			var tex: Texture2D = load(path) as Texture2D
			var view := TextureRect.new()
			view.texture = tex
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var mat := ShaderMaterial.new()
			mat.shader = _CUTOUT
			view.material = mat
			add_child(view)
			_tower_views.append(view)

func _process(delta: float) -> void:
	if bool(Progression.get_settings().get("reduce_motion", false)):
		return
	_time += delta
	_holo_phase += delta * 0.35
	if randf() < 0.018:
		_flicker = randf_range(0.88, 1.0)
	else:
		_flicker = lerp(_flicker, 1.0, 0.08)
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	if s.x < 8.0 or s.y < 8.0:
		return
	var reduce: bool = bool(Progression.get_settings().get("reduce_motion", false))

	# Sky gradient
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.04, 0.09, 1.0))
	for i in 12:
		var t: float = float(i) / 11.0
		var y0: float = s.y * 0.02 + t * s.y * 0.55
		var y1: float = y0 + s.y * 0.05
		var c: Color = Color(0.04, 0.08, 0.16, 0.35 * (1.0 - t)).lerp(Color(0.01, 0.02, 0.05, 0.0), t)
		draw_rect(Rect2(0.0, y0, s.x, y1 - y0), c)

	_draw_skyline(s)
	_draw_arcana_facade(s)
	_draw_holo_billboard(s, reduce)
	_draw_plaza(s)
	_layout_foreground_towers(s)
	_draw_vignette(s)

	if not reduce:
		_draw_ambient_sparks(s)

func _draw_skyline(s: Vector2) -> void:
	var base_y: float = s.y * 0.42
	var blocks: Array = [
		[s.x * 0.08, 120.0, 0.14],
		[s.x * 0.18, 185.0, 0.18],
		[s.x * 0.28, 95.0, 0.12],
		[s.x * 0.52, 210.0, 0.20],
		[s.x * 0.62, 140.0, 0.15],
		[s.x * 0.72, 175.0, 0.17],
		[s.x * 0.85, 130.0, 0.14],
	]
	for b in blocks:
		var x: float = float(b[0])
		var h: float = float(b[1]) * (s.y / 600.0)
		var w: float = s.x * float(b[2])
		var top: float = base_y - h
		draw_rect(Rect2(x, top, w, h), Color(0.05, 0.07, 0.12, 0.92))
		draw_rect(Rect2(x, top, w, 4.0), Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.22 * _flicker))
		# Window strip
		var wy: float = top + h * 0.25
		while wy < base_y - 8.0:
			draw_rect(Rect2(x + 6.0, wy, w - 12.0, 2.0), Color(0.85, 0.55, 0.18, 0.12 * _flicker))
			wy += 14.0

func _draw_arcana_facade(s: Vector2) -> void:
	var w: float = s.x * 0.34
	var h: float = s.y * 0.52
	var x: float = s.x * 0.02
	var y: float = s.y * 0.22
	draw_rect(Rect2(x, y, w, h), Color(0.07, 0.09, 0.14, 0.96))
	draw_rect(Rect2(x, y, w, 3.0), Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.35))
	# Triangle insignia
	var cx: float = x + w * 0.22
	var cy: float = y + h * 0.18
	var tri: PackedVector2Array = [
		Vector2(cx, cy - 28.0),
		Vector2(cx - 34.0, cy + 22.0),
		Vector2(cx + 34.0, cy + 22.0),
	]
	draw_colored_polygon(tri, Color(0.12, 0.18, 0.28, 1.0))
	draw_polyline(tri, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.7), 2.0, true)
	# Label blocks (procedural stand-in for billboard art)
	draw_string(ThemeDB.fallback_font, Vector2(x + w * 0.08, y + h * 0.32), "ARCANA", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.92, 0.94, 0.98, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(x + w * 0.08, y + h * 0.38), "INDUSTRIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.62, 0.75, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(x + w * 0.08, y + h * 0.44), "NETWORK DIVISION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.52, 0.65, 0.85))
	# Ground-floor glow
	draw_rect(Rect2(x, y + h - 36.0, w, 36.0), Color(0.95, 0.72, 0.22, 0.08 * _flicker))

func _draw_holo_billboard(s: Vector2, reduce: bool) -> void:
	var w: float = s.x * 0.30
	var h: float = s.y * 0.40
	var x: float = s.x * 0.66
	var y: float = s.y * 0.20
	var pulse: float = 1.0 if reduce else (0.85 + sin(_holo_phase) * 0.15)
	draw_rect(Rect2(x, y, w, h), Color(0.04, 0.10, 0.22, 0.92))
	draw_rect(Rect2(x, y, w, h), Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.25 * pulse), false, 2.0)
	# Face oval
	var face_c: Vector2 = Vector2(x + w * 0.5, y + h * 0.42)
	draw_circle(face_c, minf(w, h) * 0.14, Color(0.15, 0.45, 0.85, 0.35 * pulse))
	draw_arc(face_c, minf(w, h) * 0.14, 0.0, TAU, 32, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.55 * pulse), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(x + w * 0.06, y + h * 0.78), "AI MANAGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.88, 1.0, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(x + w * 0.06, y + h * 0.86), "INFRASTRUCTURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.88, 1.0, 0.92))

func _draw_plaza(s: Vector2) -> void:
	var ground_y: float = s.y * 0.68
	draw_rect(Rect2(0.0, ground_y, s.x, s.y - ground_y), Color(0.06, 0.07, 0.10, 1.0))
	# Curved lane markings
	var lane_pts: PackedVector2Array = []
	var steps: int = 24
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var lx: float = lerpf(-s.x * 0.05, s.x * 1.05, t)
		var ly: float = ground_y + sin(t * PI) * s.y * 0.06 + t * s.y * 0.12
		lane_pts.append(Vector2(lx, ly))
	draw_polyline(lane_pts, Color(_THEME.GOLD.r, _THEME.GOLD.g, _THEME.GOLD.b, 0.18 * _flicker), 3.0)
	# Center readability wash — keeps UI stack legible
	var center: Rect2 = Rect2(s.x * 0.28, s.y * 0.12, s.x * 0.44, s.y * 0.76)
	draw_rect(center, Color(0.02, 0.04, 0.08, 0.42))

func _layout_foreground_towers(s: Vector2) -> void:
	if _tower_views.is_empty():
		return
	var ground_y: float = s.y * 0.72
	var slots: Array = [
		[s.x * 0.16, 0.30],
		[s.x * 0.48, 0.36],
		[s.x * 0.82, 0.32],
	]
	for i in mini(_tower_views.size(), slots.size()):
		var slot: Array = slots[i]
		var tx: float = float(slot[0])
		var display: float = s.y * float(slot[1])
		var view: TextureRect = _tower_views[i]
		view.position = Vector2(tx - display * 0.5, ground_y - display)
		view.size = Vector2(display, display)
		view.modulate = Color(1.0, 1.0, 1.0, 0.95)

func _draw_vignette(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, s.y * 0.08)), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(Rect2(0.0, s.y * 0.92, s.x, s.y * 0.08), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(Vector2.ZERO, Vector2(s.x * 0.06, s.y)), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(Rect2(s.x * 0.94, 0.0, s.x * 0.06, s.y), Color(0.0, 0.0, 0.0, 0.25))

func _draw_ambient_sparks(s: Vector2) -> void:
	var count: int = 8
	for i in count:
		var seed: float = float(i) * 1.73 + _time * 0.2
		var px: float = fposmod(sin(seed) * 437.0, s.x)
		var py: float = s.y * 0.25 + fposmod(cos(seed * 1.1) * 251.0, s.y * 0.5)
		draw_circle(Vector2(px, py), 1.5, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.12))
