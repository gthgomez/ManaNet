extends Node2D
class_name SelectionRing

# A holographic selection ring that rotates and pulses around a selected tower.

var radius: float = 40.0
var color: Color = Color(0.18, 0.69, 1.0, 0.8) # Theme Cyan
var thickness: float = 2.0
var rotation_speed: float = 1.5
var pulse_speed: float = 2.0
var _time: float = 0.0

@onready var _rect := ColorRect.new()

func _ready() -> void:
	_rect.custom_minimum_size = Vector2(256, 256)
	_rect.position = Vector2(-128, -128)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = ShaderMaterial.new()
	_rect.material.shader = preload("res://assets/shaders/SelectionRing.gdshader")
	add_child(_rect)

func set_color(new_color: Color) -> void:
	color = new_color
	if _rect and _rect.material:
		_rect.material.set_shader_parameter("ring_color", new_color)

func _process(delta: float) -> void:
	# Keep rotation for extra dynamism
	rotation += rotation_speed * delta
