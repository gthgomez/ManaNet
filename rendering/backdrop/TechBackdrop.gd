extends Control
class_name TDTechBackdrop

const _THEME := preload("res://ui/theme/GameTheme.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	if _THEME.shader_effects_enabled():
		shader_rect.material = ShaderMaterial.new()
		shader_rect.material.shader = preload("res://assets/shaders/MenuScanning.gdshader")
		shader_rect.material.set_shader_parameter("line_color", Color(0.290, 0.565, 0.851, 0.14))
	add_child(shader_rect)

var _time: float = 0.0
var _flicker: float = 1.0

func _process(delta: float) -> void:
	_time += delta
	if randf() < 0.02:
		_flicker = randf_range(0.85, 1.0)
	else:
		_flicker = lerp(_flicker, 1.0, 0.1)
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), _THEME.BG)
	var step: float = 72.0
	var x: float = fmod(s.x * 0.17, step)
	var grid_color := Color(0.08, 0.16, 0.32, 0.14 * _flicker)
	while x < s.x:
		draw_line(Vector2(x, 0.0), Vector2(x - s.y * 0.18, s.y), grid_color, 1.0)
		x += step
	var y: float = fmod(s.y * 0.23, step)
	var grid_color_h := Color(0.08, 0.16, 0.32, 0.09 * _flicker)
	while y < s.y:
		draw_line(Vector2(0.0, y), Vector2(s.x, y), grid_color_h, 1.0)
		y += step
	draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, 70.0)), Color(0.0, 0.0, 0.0, 0.14))
	draw_line(Vector2(0.0, 70.0), Vector2(s.x, 70.0), Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.18 * _flicker), 1.0)
