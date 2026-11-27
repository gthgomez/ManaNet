extends Control

## Draws an authoritative reference image fitted inside the control.
## Interactive controls should be positioned with map_norm() so they cover the
## painted buttons instead of drawing a second UI on top.

var texture: Texture2D = null

## Desktop reads the source PNG so captures stay pixel-identical to the plate.
## An exported pack does not contain that source file, so callers also preload
## the imported texture and pass it here for device builds.
static func texture_for_plate(source_path: String, packed: Texture2D) -> Texture2D:
	var image := Image.new()
	if image.load(source_path) == OK:
		return ImageTexture.create_from_image(image)
	return packed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func displayed_rect() -> Rect2:
	var bounds := Rect2(Vector2.ZERO, size)
	if texture == null or size.x < 2.0 or size.y < 2.0:
		return bounds
	var tex_size := texture.get_size()
	if tex_size.x < 1.0 or tex_size.y < 1.0:
		return bounds
	var scale: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var drawn := tex_size * scale
	return Rect2((size - drawn) * 0.5, drawn)

func map_norm(nx: float, ny: float, nw: float, nh: float) -> Rect2:
	var area := displayed_rect()
	return Rect2(area.position + Vector2(nx, ny) * area.size, Vector2(nw, nh) * area.size)

func _draw() -> void:
	var area := displayed_rect()
	if texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 1.0))
	draw_texture_rect(texture, area, false)
