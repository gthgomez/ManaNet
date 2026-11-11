# QA capture harness: drives shipped scenes and saves real rendered frames.
# Run through tools/qa/capture_matrix.sh so each capture gets an isolated profile.
extends SceneTree

const SCREEN_DIR := "res://scenes/"
const OUT_ENV := "QA_SHOT_DIR"
const SCENARIO_ENV := "QA_SCENARIO"

var scene: Node = null
var out_dir: String = ""
var scenario: String = ""

func _initialize() -> void:
	out_dir = OS.get_environment(OUT_ENV)
	scenario = OS.get_environment(SCENARIO_ENV)
	if out_dir.is_empty() or scenario.is_empty():
		push_error("Set QA_SHOT_DIR and QA_SCENARIO")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _show(path: String) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	scene = load(path).instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png(out_dir.path_join(name + ".png"))
	if err != OK:
		push_error("screenshot failed: " + name)
	else:
		print("QA_SHOT ", name, " ", image.get_width(), "x", image.get_height())

func _seed_returning(with_modifiers: bool = false) -> void:
	var progression := root.get_node("Progression")
	var profile: Dictionary = progression.get_profile()
	profile["banked_rp"] = 480
	profile["total_rp"] = 1500
	profile["run_history"] = [
		{"map_id": 0, "waves": 15, "perfect": 9, "lives": 8, "won": true,
			"gold_earned": 3120, "gold_spent": 2400, "rp_earned": 780},
		{"map_id": 1, "waves": 9, "perfect": 3, "lives": 0, "won": false,
			"gold_earned": 1800, "gold_spent": 1500, "rp_earned": 180},
	]
	if with_modifiers:
		for mod_id in ["mod_iron_economy", "mod_glass_cannon", "mod_blitz"]:
			if not mod_id in profile["unlocked"]:
				profile["unlocked"].append(mod_id)
	progression.save_profile()
	progression.load_profile()
	if with_modifiers:
		progression.set_active_modifier("mod_iron_economy")
		progression.load_profile()

func _seed_all_modifiers() -> void:
	var progression := root.get_node("Progression")
	var profile: Dictionary = progression.get_profile()
	for mod_id in ["mod_iron_economy", "mod_glass_cannon", "mod_blitz",
			"mod_hardened", "mod_sudden_death"]:
		if not mod_id in profile["unlocked"]:
			profile["unlocked"].append(mod_id)
	progression.save_profile()
	progression.load_profile()

func _game(map_id: int = 0) -> Node:
	var progression := root.get_node("Progression")
	progression.pending_map_id = map_id
	await _show(SCREEN_DIR + "GameScreen.tscn")
	scene.view_state.show_onboarding = false
	scene.view_state.onboarding_dismissed = true
	scene.view_state.clear_instruction()
	await create_timer(0.35).timeout
	return scene

func _place(ttype: String, pos: Vector2) -> void:
	scene._dispatch({"type": "place_tower", "tower_type": ttype, "pos": pos}, Time.get_ticks_msec())
	await create_timer(0.2).timeout

func _run() -> void:
	# Force the window size to be the LOGICAL viewport size, matching
	# ViewportGeometryTest. Otherwise stretch/aspect-expand renders the 900x600
	# design scaled down, which hides real short-viewport layout defects.
	var win: Vector2i = DisplayServer.window_get_size()
	root.content_scale_size = win
	root.size = win
	await process_frame
	await process_frame
	# Watchdog: a script error inside a coroutine must not leave the process
	# alive forever (a capture hang looked like a rendering failure).
	create_timer(50.0).timeout.connect(func():
		push_error("capture watchdog timeout: " + scenario)
		quit(3))
	match scenario:
		"menu":
			await _show(SCREEN_DIR + "MenuScreen.tscn")
			await create_timer(1.0).timeout
			await _shot("menu")
		"menu_returning":
			_seed_returning()
			await _show(SCREEN_DIR + "MenuScreen.tscn")
			await create_timer(1.0).timeout
			await _shot("menu_returning")
		"maps_modifiers":
			_seed_returning(true)
			await _show(SCREEN_DIR + "MapSelectScreen.tscn")
			await create_timer(0.4).timeout
			await _shot("maps_modifiers")
		"maps_modifiers_all":
			_seed_all_modifiers()
			await _show(SCREEN_DIR + "MapSelectScreen.tscn")
			await create_timer(0.4).timeout
			await _shot("maps_modifiers_all")
			scene._mod_scroll.scroll_horizontal = 10000
			await create_timer(0.3).timeout
			await _shot("maps_modifiers_all_end")
		"maps":
			await _show(SCREEN_DIR + "MapSelectScreen.tscn")
			await create_timer(0.4).timeout
			await _shot("maps")
			scene._card_container.get_child(0).get_meta("thumb").queue_redraw()
			await _shot("maps_redraw")
		"settings":
			await _show(SCREEN_DIR + "SettingsScreen.tscn")
			await _shot("settings")
			if scene._scroll:
				scene._scroll.scroll_vertical = 100000
				await create_timer(0.4).timeout
				await _shot("settings_bottom")
		"cyberdeck_shop":
			await _show(SCREEN_DIR + "CyberDeckScreen.tscn")
			await create_timer(0.4).timeout
			await _shot("cyberdeck_shop")
			scene._scroll.scroll_vertical = 100000
			await create_timer(0.4).timeout
			await _shot("cyberdeck_shop_bottom")
		"cyberdeck_variants":
			await _show(SCREEN_DIR + "CyberDeckScreen.tscn")
			scene._show_tab("variants")
			await create_timer(0.5).timeout
			await _shot("cyberdeck_variants")
		"game_start":
			await _game(0)
			await _shot("game_start")
		"game_selected":
			await _game(0)
			await _place("archer", Vector2(180, 250))
			await _place("frost", Vector2(330, 250))
			var tower = scene.game_state.towers[0]
			scene.view_state.selected_tower_id = tower.id
			await create_timer(0.5).timeout
			await _shot("game_selected")
		"game_details":
			await _game(0)
			await _place("archer", Vector2(180, 250))
			var tower = scene.game_state.towers[0]
			scene.view_state.selected_tower_id = tower.id
			await create_timer(0.3).timeout
			scene._on_info_pressed()
			await create_timer(0.5).timeout
			await _shot("game_details")
		"game_placement":
			await _game(0)
			scene.view_state.enter_placement("archer")
			scene.view_state.placement_mode = "drop"
			scene.view_state.set_pending_placement(Vector2(180, 80), "archer", false)
			await create_timer(0.4).timeout
			await _shot("game_placement_invalid")
			scene.view_state.set_pending_placement(Vector2(180, 250), "archer", true)
			await create_timer(0.4).timeout
			await _shot("game_placement_valid")
		"game_wave_shop":
			await _game(0)
			scene.game_state.wave = 3
			scene.game_state.wave_shop_pending = true
			scene.game_state.wave_ready = false
			scene._show_wave_shop(Time.get_ticks_msec())
			await create_timer(0.6).timeout
			await _shot("game_wave_shop")
		"game_combat":
			await _game(0)
			await _place("archer", Vector2(180, 250))
			await _place("cannon", Vector2(330, 250))
			scene.game_state.gold = 2000
			scene.game_state.start_wave()
			await create_timer(7.0).timeout
			await _shot("game_combat")
			await create_timer(4.0).timeout
			await _shot("game_combat_dense")
		"game_combat_3x":
			await _game(0)
			await _place("archer", Vector2(180, 250))
			await _place("cannon", Vector2(330, 250))
			scene.game_state.gold = 2000
			scene.game_state.set_speed(3.0)
			scene.game_state.start_wave()
			await create_timer(5.0).timeout
			await _shot("game_combat_3x")
		"game_boss":
			await _game(0)
			await _place("archer", Vector2(180, 250))
			await _place("cannon", Vector2(330, 250))
			await _place("frost", Vector2(120, 250))
			scene.game_state.gold = 3000
			scene.game_state.wave = 4
			scene.game_state.start_wave()
			await create_timer(6.0).timeout
			await _shot("game_boss")
		"game_promotion":
			await _game(0)
			await _place("archer", Vector2(180, 250))
			var tower = scene.game_state.towers[0]
			scene.view_state.selected_tower_id = tower.id
			scene.view_state.promotion_pending = true
			tower.tracker.path_levels["Top"] = 1
			tower.tracker.pending_promotion_path = "Top"
			await create_timer(0.5).timeout
			await _shot("game_promotion")
		"game_pause":
			await _game(0)
			scene.game_state.paused = true
			await create_timer(0.5).timeout
			await _shot("game_pause")
			scene.view_state.confirm_restart = true
			scene._restart_confirm_start_ms = Time.get_ticks_msec()
			await create_timer(0.3).timeout
			await _shot("game_pause_restart")
		"end_win":
			root.get_node("Progression").pending_end_stats = {
				"won": true, "rp_earned": 780, "waves": 15, "perfect_waves": 9,
				"lives": 8, "map_id": 0, "towers_placed": 22, "enemies_killed": 214,
				"gold_earned": 3120, "newly_unlocked_variants": ["Cryo Arc"],
				"milestone_deltas": [
					{"label": "Archer Mk.II", "uses_now": 12, "uses_max": 20, "kills_now": 140, "kills_max": 200},
				],
			}
			await _show(SCREEN_DIR + "EndScreen.tscn")
			await create_timer(0.5).timeout
			await _shot("end_win")
		"end_save_fail":
			root.get_node("Progression").pending_end_stats = {
				"won": false, "rp_earned": 0, "waves": 7, "perfect_waves": 1,
				"lives": 0, "map_id": 0, "towers_placed": 8, "enemies_killed": 54,
				"gold_earned": 1100, "newly_unlocked_variants": [],
				"milestone_deltas": [], "save_failed": true,
			}
			await _show(SCREEN_DIR + "EndScreen.tscn")
			await create_timer(0.5).timeout
			await _shot("end_save_fail")
		"end_loss":
			root.get_node("Progression").pending_end_stats = {
				"won": false, "rp_earned": 120, "waves": 6, "perfect_waves": 2,
				"lives": 0, "map_id": 1, "towers_placed": 9, "enemies_killed": 61,
				"gold_earned": 890, "newly_unlocked_variants": [], "milestone_deltas": [],
			}
			await _show(SCREEN_DIR + "EndScreen.tscn")
			await create_timer(0.5).timeout
			await _shot("end_loss")
		_:
			push_error("Unknown scenario: " + scenario)
			quit(2)
			return
	var juice = root.get_node_or_null("JuiceManager")
	if juice != null and juice.has_method("stop_all"):
		juice.stop_all()
	await process_frame
	quit(0)
