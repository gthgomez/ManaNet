# Scripted operation of shipped scenes; no simulated frames or altered balance.
# Run with an isolated XDG_DATA_HOME and a graphical display. See docs/showcase/README.md.
extends SceneTree

var scene: Node
var output_dir: String

func _initialize() -> void:
	output_dir = OS.get_environment("SHOWCASE_OUTPUT")
	if output_dir.is_empty():
		push_error("Set SHOWCASE_OUTPUT to an output directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run.call_deferred()

func _show(path: String) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	scene = load(path).instantiate()
	root.add_child(scene)
	await create_timer(1.5).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output_dir.path_join(name + ".png"))
	if result != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
	print("SHOWCASE screenshot: ", name)

func _run() -> void:
	await _show("res://scenes/MenuScreen.tscn")
	await _shot("menu")
	await create_timer(1.0).timeout
	await _show("res://scenes/MapSelectScreen.tscn")
	await _shot("maps")
	await create_timer(1.0).timeout
	root.get_node("Progression").pending_map_id = 0
	await _show("res://scenes/GameScreen.tscn")
	scene.view_state.show_onboarding = false
	scene.view_state.onboarding_dismissed = true
	scene.view_state.clear_instruction()
	for position in [Vector2(160, 230), Vector2(320, 230), Vector2(380, 180)]:
		scene._dispatch({"type": "place_tower", "tower_type": "archer", "pos": position}, Time.get_ticks_msec())
		await create_timer(0.7).timeout
	if scene.game_state.towers.size() != 3:
		push_error("Expected three towers at normal cost")
		quit(1)
		return
	await _shot("placement")
	scene._wave_btn.pressed.emit()
	await create_timer(6.0).timeout
	await _shot("combat")
	await create_timer(6.0).timeout
	var record := {"map": "S-Curve", "wave": scene.game_state.wave,
		"towers": scene.game_state.towers.size(), "kills": scene.game_state.stat_enemies_killed,
		"credits": scene.game_state.gold, "integrity": scene.game_state.lives,
		"engine": Engine.get_version_info().string,
		"method": "Scripted shipped-scene actions at normal costs and speed"}
	var file := FileAccess.open(output_dir.path_join("runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t") + "\n")
	file.close()
	print("SHOWCASE result: ", JSON.stringify(record))
	if scene.game_state.stat_enemies_killed < 1:
		push_error("No combat kill observed")
		quit(1)
		return
	quit(0)
