extends Node2D
class_name VirtualCursor

# A high-fidelity tactical crosshair for Fire TV / Controller users.
# Controlled via D-pad to move the placement ghost.

var color : Color = Color(0.22, 0.88, 0.95, 0.8) # Electric Teal
var speed : float = 450.0
var thickness : float = 2.0
var size : float = 32.0

func _draw() -> void:
	# Outer tactical brackets
	var s := size * 0.5
	var l := size * 0.2
	
	# Top Left
	draw_polyline(PackedVector2Array([Vector2(-s, -s+l), Vector2(-s, -s), Vector2(-s+l, -s)]), color, thickness)
	# Top Right
	draw_polyline(PackedVector2Array([Vector2(s-l, -s), Vector2(s, -s), Vector2(s, -s+l)]), color, thickness)
	# Bottom Left
	draw_polyline(PackedVector2Array([Vector2(-s, s-l), Vector2(-s, s), Vector2(-s+l, s)]), color, thickness)
	# Bottom Right
	draw_polyline(PackedVector2Array([Vector2(s-l, s), Vector2(s, s), Vector2(s, s-l)]), color, thickness)
	
	# Center dot
	draw_circle(Vector2.ZERO, 2.0, color)
	
	# Add a faint scanning grid within the cursor
	draw_line(Vector2(-s, 0), Vector2(s, 0), Color(color.r, color.g, color.b, 0.2), 1.0)
	draw_line(Vector2(0, -s), Vector2(0, s), Color(color.r, color.g, color.b, 0.2), 1.0)

func _process(delta: float) -> void:
	queue_redraw()
