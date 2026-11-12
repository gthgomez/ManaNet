extends RefCounted
class_name CorporateSceneryDraw

## Static draw helpers for Arcana corporate scenery inside the 900×600 playfield.

const _THEME := preload("res://ui/theme/GameTheme.gd")
const _FONT_SIZE := 9

static func draw_playfield_decor(canvas: CanvasItem, shake: Vector2, now_ms: int, reduce_motion: bool) -> void:
	var font: Font = ThemeDB.fallback_font
	var pulse: float = 1.0 if reduce_motion else (0.82 + sin(float(now_ms) * 0.0025) * 0.18)
	_draw_plaza_tiles(canvas, shake)
	_draw_deploy_marks(canvas, shake)
	_draw_planters(canvas, shake)

	# Left Arcana façade (does not block central path lanes).
	var facade := Rect2(shake + Vector2(18.0, 48.0), Vector2(168.0, 196.0))
	canvas.draw_rect(facade, Color(0.07, 0.09, 0.14, 0.78))
	canvas.draw_rect(facade, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.28), false, 1.5)
	var tri: PackedVector2Array = [
		facade.position + Vector2(42.0, 28.0),
		facade.position + Vector2(16.0, 68.0),
		facade.position + Vector2(68.0, 68.0),
	]
	canvas.draw_colored_polygon(tri, Color(0.12, 0.18, 0.28, 0.9))
	canvas.draw_string(font, facade.position + Vector2(10.0, 96.0), "ARCANA", HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE,
		Color(0.75, 0.82, 0.92, 0.85))
	canvas.draw_string(font, facade.position + Vector2(10.0, 108.0), "INDUSTRIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.75))

	# Right holo billboard
	var board := Rect2(shake + Vector2(672.0, 44.0), Vector2(208.0, 168.0))
	canvas.draw_rect(board, Color(0.04, 0.10, 0.22, 0.82))
	canvas.draw_rect(board, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.42 * pulse), false, 2.0)
	var face_c: Vector2 = board.position + board.size * 0.5 + Vector2(0.0, -8.0)
	canvas.draw_circle(face_c, 28.0, Color(0.14, 0.42, 0.82, 0.32 * pulse))
	canvas.draw_arc(face_c, 28.0, 0.0, TAU, 24, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.5 * pulse), 1.5)
	canvas.draw_string(font, board.position + Vector2(18.0, 142.0), "AI MANAGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(0.55, 0.88, 1.0, 0.72 * pulse))
	canvas.draw_string(font, board.position + Vector2(18.0, 154.0), "INFRASTRUCTURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(0.45, 0.72, 0.92, 0.62 * pulse))

	# Ground lane accents near path edges (subtle, not gameplay-blocking).
	canvas.draw_rect(Rect2(shake + Vector2(0.0, 520.0), Vector2(900.0, 12.0)), Color(_THEME.GOLD.r, _THEME.GOLD.g, _THEME.GOLD.b, 0.06))


static func _draw_plaza_tiles(canvas: CanvasItem, shake: Vector2) -> void:
	var tile: float = 48.0
	for x in range(0, 19):
		for y in range(0, 13):
			var r := Rect2(shake + Vector2(float(x) * tile, float(y) * tile), Vector2(tile - 1.0, tile - 1.0))
			var alt: float = 0.03 + 0.008 * float((x + y) % 2)
			canvas.draw_rect(r, Color(alt, alt + 0.01, alt + 0.02, 0.35))


static func _draw_planters(canvas: CanvasItem, shake: Vector2) -> void:
	var slots: Array = [
		Vector2(120.0, 420.0), Vector2(520.0, 80.0), Vector2(780.0, 420.0), Vector2(340.0, 520.0),
	]
	for p in slots:
		var base: Vector2 = shake + p
		canvas.draw_rect(Rect2(base, Vector2(54.0, 22.0)), Color(0.08, 0.10, 0.14, 0.75))
		canvas.draw_rect(Rect2(base + Vector2(4.0, 4.0), Vector2(46.0, 14.0)), Color(0.08, 0.22, 0.14, 0.65))
		canvas.draw_circle(base + Vector2(18.0, 2.0), 8.0, Color(0.12, 0.38, 0.22, 0.5))
		canvas.draw_circle(base + Vector2(36.0, 2.0), 7.0, Color(0.10, 0.32, 0.20, 0.45))


static func _draw_deploy_marks(canvas: CanvasItem, shake: Vector2) -> void:
	var cells: Array = [
		Vector2(160.0, 220.0), Vector2(240.0, 360.0), Vector2(360.0, 160.0),
		Vector2(480.0, 280.0), Vector2(560.0, 400.0), Vector2(640.0, 180.0),
		Vector2(200.0, 480.0), Vector2(700.0, 320.0),
	]
	var mark_c := Color(0.85, 0.88, 0.92, 0.14)
	for c in cells:
		var p: Vector2 = shake + c
		var h: float = 11.0
		canvas.draw_line(p + Vector2(-h, -h), p + Vector2(h, h), mark_c, 1.2)
		canvas.draw_line(p + Vector2(-h, h), p + Vector2(h, -h), mark_c, 1.2)
		canvas.draw_rect(Rect2(p + Vector2(-14.0, -14.0), Vector2(28.0, 28.0)), Color(0.12, 0.16, 0.22, 0.12), false, 1.0)
