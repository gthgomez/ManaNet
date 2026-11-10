extends Node

## One-shot viewport capture. CAPTURE_DIR and CAPTURE_LABEL come from the environment.
## Graphical only — headless viewports have no framebuffer image.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_environment("CAPTURE_DIR")
	if out == "":
		out = "/tmp/mananet_capture"
	var label := OS.get_environment("CAPTURE_LABEL")
	if label == "":
		label = "shot"
	DirAccess.make_dir_recursive_absolute(out)
	var sizes: Array = [
		Vector2i(568, 320),
		Vector2i(640, 360),
		Vector2i(800, 600),
		Vector2i(900, 600),
		Vector2i(1280, 720),
		Vector2i(1440, 900),
	]
	for size in sizes:
		var root := get_tree().root
		root.content_scale_size = size
		root.size = size
		DisplayServer.window_set_size(size)
		await get_tree().process_frame
		await get_tree().process_frame
		var packed := load("res://scenes/MenuScreen.tscn") as PackedScene
		var scene: Node = packed.instantiate()
		get_tree().root.add_child(scene)
		# Let the menu fade-in finish so the capture is the settled composition.
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path := "%s/%s_menu_%dx%d.png" % [out, label, size.x, size.y]
		var err := image.save_png(path)
		print("CAPTURE %s err=%s image=%s" % [path, err, image.get_size()])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
