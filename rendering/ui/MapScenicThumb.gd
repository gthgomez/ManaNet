extends Control
class_name MapScenicThumb

## Map card thumbnail: production environment plate + authoritative path geometry.

const _MAPS := preload("res://data/maps.gd")
const MAP_ENV: Dictionary = {
	0: "res://assets/sprites/production/environment/s_curve.svg",
	1: "res://assets/sprites/production/environment/gauntlet.svg",
	2: "res://assets/sprites/production/environment/spiral.svg",
}

var _path: Array = []
var _map_id: int = 0
var _env_tex: Texture2D = null

func _init(map_def: Dictionary) -> void:
	_map_id = int(map_def.get("id", 0))
	_path = map_def.get("path", [])
	var env_path: String = str(MAP_ENV.get(_map_id, ""))
	if env_path != "" and ResourceLoader.exists(env_path, "Texture2D"):
		_env_tex = load(env_path)

func _draw() -> void:
	var draw_size: Vector2 = size if size.x > 1.0 and size.y > 1.0 else custom_minimum_size
	draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.03, 0.05, 0.09, 1.0))
	if _env_tex != null:
		draw_texture_rect(_env_tex, Rect2(Vector2.ZERO, draw_size), false)
		draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.02, 0.03, 0.06, 0.08))
	if _map_id == 0:
		draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.85, 0.12, 0.55, 0.12))
	elif _map_id == 1:
		draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.95, 0.55, 0.15, 0.06))
	_draw_path_overlay(draw_size)
	# Beveled frame
	draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.29, 0.56, 0.85, 0.35), false, 1.5)

func _draw_path_overlay(draw_size: Vector2) -> void:
	if _path.size() < 2:
		return
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for p_variant in _path:
		var p: Vector2 = p_variant
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	var span_x: float = maxf(max_x - min_x, 1.0)
	var span_y: float = maxf(max_y - min_y, 1.0)
	var pad: float = 10.0
	var s: float = minf((draw_size.x - pad * 2.0) / span_x, (draw_size.y - pad * 2.0) / span_y)
	var off_x: float = pad + ((draw_size.x - pad * 2.0) - span_x * s) / 2.0
	var off_y: float = pad + ((draw_size.y - pad * 2.0) - span_y * s) / 2.0

	var pts: PackedVector2Array = []
	for p_variant in _path:
		var p: Vector2 = p_variant
		pts.append(Vector2(off_x + (p.x - min_x) * s, off_y + (p.y - min_y) * s))

	draw_polyline(pts, Color(0, 0, 0, 0.65), 6.5)
	draw_polyline(pts, Color(0.071, 0.086, 0.149, 1.0), 5.0)
	draw_polyline(pts, Color(0.141, 0.165, 0.267, 1.0), 3.8)
	draw_polyline(pts, Color(0.204, 0.573, 1.0, 0.75), 2.2)
	for i in range(pts.size() - 1):
		draw_dashed_line(pts[i], pts[i + 1], Color(0.35, 0.95, 1.0, 0.88), 2.4, 7.0, true)
	draw_circle(pts[0], 5.0, Color(0.95, 0.2, 0.25, 0.9))
	draw_circle(pts[0], 5.0, Color(1.0, 0.35, 0.45, 0.55), false, 1.5)
	draw_circle(pts[-1], 5.0, Color(0.0, 0.9, 1.0, 0.85))
	draw_circle(pts[-1], 5.0, Color(0.35, 0.95, 1.0, 0.45), false, 1.5)
