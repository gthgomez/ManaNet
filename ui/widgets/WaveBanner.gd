extends Control
class_name TDWaveBanner

const _THEME := preload("res://ui/theme/GameTheme.gd")

var _label: Label
var _bg: PanelContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_bg = PanelContainer.new()
	_bg.custom_minimum_size = Vector2(400.0, 80.0)
	_THEME.apply_panel(_bg, "modal")
	add_child(_bg)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	_bg.add_child(margin)
	
	_label = Label.new()
	_label.text = "WAVE START"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_THEME.apply_label(_label, "title")
	_label.add_theme_font_size_override("font_size", 32)
	margin.add_child(_label)
	
	_bg.pivot_offset = _bg.custom_minimum_size * 0.5
	modulate.a = 0.0

func display(text: String) -> void:
	_label.text = text
	var viewport_size := get_viewport_rect().size
	_bg.position = (viewport_size - _bg.custom_minimum_size) * 0.5
	
	var tween := create_tween()
	tween.set_parallel(false)
	
	# Fade in and scale up
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_bg, "scale", Vector2(1.1, 1.1), 0.2).from(Vector2(0.8, 0.8))
	
	# Settle
	tween.tween_property(_bg, "scale", Vector2.ONE, 0.1)
	
	# Wait
	tween.tween_interval(1.2)
	
	# Fade out and slide
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_bg, "position:x", _bg.position.x + 100, 0.4)
	
	tween.tween_callback(queue_free)
