extends Node

# Automation script to verify UI/UX pass.
# Run with: godot scenes/AutomatedTest.tscn

func _ready():
	_run_verification()

func _run_verification():
	await get_tree().process_frame
	print("--- Starting Runtime Verification ---")
	
	# 1. Main Menu
	var main_scene = load("res://scenes/MenuScreen.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(1.0)
	await _take_screenshot("C:/Workspace/Project_Games/TowerDefenseGodot/verify_1_menu.png")
	
	# 2. Map Select
	main_scene.queue_free()
	var map_scene = load("res://scenes/MapSelectScreen.tscn").instantiate()
	get_tree().root.add_child(map_scene)
	await _wait(1.0)
	await _take_screenshot("C:/Workspace/Project_Games/TowerDefenseGodot/verify_2_map_select.png")
	
	# 3. Gameplay Before Wave
	map_scene.queue_free()
	# Setup Progression for S-Curve (Map 0)
	Progression.pending_map_id = 0
	var game_scene = load("res://scenes/GameScreen.tscn").instantiate()
	get_tree().root.add_child(game_scene)
	await _wait(1.5)
	await _take_screenshot("C:/Workspace/Project_Games/TowerDefenseGodot/verify_3_gameplay_prewave.png")
	
	# 4. Place Tower
	var archer_pos = Vector2(160, 440) # Better position for S-Curve
	game_scene._dispatch({"type": "place_tower", "tower_type": "archer", "pos": archer_pos}, Time.get_ticks_msec())
	await _wait(0.5)
	await _take_screenshot("C:/Workspace/Project_Games/TowerDefenseGodot/verify_3_placed.png")
	
	# 5. Start Combat
	if game_scene.has_method("_on_wave_btn_pressed"):
		game_scene._on_wave_btn_pressed()
	
	print("Combat active. Observing for 5s...")
	await _wait(5.0)
	await _take_screenshot("C:/Workspace/Project_Games/TowerDefenseGodot/verify_4_combat_early.png")
	await _wait(10.0)
	await _take_screenshot("C:/Workspace/Project_Games/TowerDefenseGodot/verify_4_combat_mid.png")
	
	print("--- Verification Complete ---")
	get_tree().quit()

func _wait(seconds: float):
	await get_tree().create_timer(seconds).timeout

func _take_screenshot(path: String):
	await get_tree().process_frame
	await get_tree().process_frame
	var img = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Screenshot saved: ", path)
