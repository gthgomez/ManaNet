extends Node

# Player journey driven by mouse and keyboard events on the live controls.
# This node clears itself as the current scene so later scene changes do not
# free the harness. Desktop synthetic input does not certify Android touch.

const SANDBOX := "/tmp/mananet_input_journey/profile.json"

var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/mananet_input_journey")
	if FileAccess.file_exists(SANDBOX):
		DirAccess.remove_absolute(SANDBOX)
	await get_tree().process_frame
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	Progression.set_save_path(SANDBOX)
	Progression.load_profile()
	var profile: Dictionary = Progression.get_profile()
	profile["banked_rp"] = 400
	Progression.save_profile()
	await _run()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	# The last button cue is still playing. Stop it and let the audio server
	# drop the playback before process exit, or the Ogg stream is reported leaked.
	if JuiceManager != null and JuiceManager.has_method("stop_all"):
		JuiceManager.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _fit_viewport() -> void:
	# Headless boots a 64×64 window. Controls laid out in the 1280×720 design
	# viewport sit outside that window, so the GUI discards the click.
	var root := get_tree().root
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))

func _mouse_click(ctrl: Control) -> void:
	var point := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	down.global_position = point
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	up.global_position = point
	vp.push_input(up)
	Input.flush_buffered_events()
	await get_tree().process_frame

func _accept_focused() -> void:
	var down := InputEventAction.new()
	down.action = "ui_accept"
	down.pressed = true
	down.strength = 1.0
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = "ui_accept"
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame

func _activate(ctrl: Button, done: Callable) -> void:
	await _mouse_click(ctrl)
	if done.call():
		return
	ctrl.grab_focus()
	await _accept_focused()

## Navigation fades for 0.25s, so a second input during the fade can hit a
## different focused control. Try the focused keyboard action once, then the
## mouse, and stop as soon as the destination scene is current.
func _open_via(ctrl: Button, scene_part: String) -> Node:
	ctrl.grab_focus()
	await _accept_focused()
	await get_tree().create_timer(0.45).timeout
	var arrived := await _wait_scene(scene_part, 20)
	if arrived != null:
		return arrived
	await _mouse_click(ctrl)
	await get_tree().create_timer(0.45).timeout
	return await _wait_scene(scene_part, 40)

func _world_click(screen: Node, world: Vector2) -> void:
	var point: Vector2 = screen._world_to_screen(world)
	var before_towers: int = screen.game_state.towers.size()
	var before_sel: int = screen.view_state.selected_tower_id
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	down.global_position = point
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen.get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	up.global_position = point
	screen.get_viewport().push_input(up)
	await get_tree().process_frame
	var changed: bool = screen.game_state.towers.size() != before_towers \
		or screen.view_state.selected_tower_id != before_sel \
		or not screen.view_state.placement_active
	if changed:
		return
	screen._input(down)
	var release := down.duplicate()
	release.pressed = false
	screen._input(release)
	await get_tree().process_frame

func _wait_scene(path_part: String, frames: int = 180) -> Node:
	for _i in range(frames):
		var current := get_tree().current_scene
		if current != null and current.get_script() != null:
			if str(current.get_script().resource_path).find(path_part) >= 0:
				await get_tree().process_frame
				return current
		await get_tree().process_frame
	return null

func _find_button(node: Node, text: String) -> Button:
	if node is Button and str(node.text) == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _find_label(node: Node, text: String) -> Label:
	if node is Label and str(node.text) == text:
		return node
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null

func _shop_fingerprint(gs) -> String:
	return "%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		gs.gold, gs.lives, gs._ws_damage_boost, gs._ws_cost_discount,
		gs._ws_kill_reward_bonus, gs._ws_spawn_interval_mult,
		gs._ws_frost_vanguard_remaining, gs._ws_expose_active,
		gs._ws_next_spawn_speed_mult, gs._perm_cd_mult, gs._perm_range_mult,
		gs._perm_kill_bonus,
	]

func _run() -> void:
	print("--- INPUT JOURNEY ---")
	_fit_viewport()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/MenuScreen.tscn")
	var menu: Node = await _wait_scene("MenuScreen")
	_check(menu != null, "menu scene is current after launch")
	if menu == null:
		return
	var maps: Node = await _open_via(menu._play_btn, "MapSelectScreen")
	_check(maps != null, "Play opens map select")
	if maps == null:
		return
	_check(maps._play_btns.size() >= 1, "map select exposes play controls")

	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	maps.get_viewport().push_input(cancel)
	await get_tree().create_timer(0.45).timeout
	var menu_back: Node = await _wait_scene("MenuScreen", 30)
	if menu_back == null:
		menu_back = await _open_via(maps._back_btn, "MenuScreen")
	_check(menu_back != null, "map select back returns to the menu")
	if menu_back == null:
		return
	maps = await _open_via(menu_back._play_btn, "MapSelectScreen")
	_check(maps != null, "Play opens map select again")
	if maps == null:
		return

	var game: Node = await _open_via(maps._play_btns[0], "GameScreen")
	_check(game != null, "clicking a map play control opens the game")
	if game == null:
		return
	await get_tree().process_frame
	_check(game.game_state.gold == 300, "run starts at 300 credits")

	_fit_viewport()
	await get_tree().process_frame
	await get_tree().process_frame
	var before_towers: int = game.game_state.towers.size()
	await _activate(game._shop_btns["archer"], func() -> bool:
		return game.view_state.placement_active)
	await _world_click(game, Vector2(200, 200))
	_check(game.game_state.towers.size() == before_towers + 1, "map click places the selected archer")
	if game.game_state.towers.is_empty():
		return
	var tower: Tower = game.game_state.towers[0]
	await _world_click(game, tower.pos)
	game._update_hud(Time.get_ticks_msec())
	_check(game.view_state.selected_tower_id == tower.id, "clicking the tower selects it")
	var level_before: int = tower.level
	await _activate(game._base_upg_btn, func() -> bool: return tower.level > level_before)
	_check(tower.level == level_before + 1, "upgrade button raises the tower level")

	await _activate(game._speed_btns[1], func() -> bool:
		return is_equal_approx(game.game_state.speed_multiplier, 2.0))
	game._update_hud(Time.get_ticks_msec())
	_check(is_equal_approx(game.game_state.speed_multiplier, 2.0), "speed button selects 2x")
	_check(game._speed_btns[1].button_pressed, "2x button shows the selected state")
	await _activate(game._speed_btns[2], func() -> bool:
		return is_equal_approx(game.game_state.speed_multiplier, 3.0))
	_check(is_equal_approx(game.game_state.speed_multiplier, 3.0), "speed button selects 3x")

	await _activate(game._pause_btn, func() -> bool: return game.game_state.paused)
	_check(game.game_state.paused, "pause control pauses the run")
	game._update_hud(Time.get_ticks_msec())
	await _activate(game._resume_btn, func() -> bool: return not game.game_state.paused)
	_check(not game.game_state.paused, "resume control leaves the run unpaused")

	var towers_now: int = game.game_state.towers.size()
	await _activate(game._shop_btns["archer"], func() -> bool:
		return game.view_state.placement_active)
	await _world_click(game, Vector2(250, 300))
	_check(game.game_state.towers.size() == towers_now, "a click on the path does not place a tower")

	await _world_click(game, tower.pos)
	game.game_state.gold = 2000
	game._update_hud(Time.get_ticks_msec())
	await _activate(game._path_upg_btns[0], func() -> bool:
		return tower.tracker.path_levels["Top"] > 0)
	await _activate(game._path_upg_btns[1], func() -> bool:
		return tower.tracker.has_pending_promotion())
	game._update_hud(Time.get_ticks_msec())
	_check(tower.tracker.has_pending_promotion(), "path button opens a promotion")
	await _activate(game._promotion_cancel_btn, func() -> bool:
		return not tower.tracker.has_pending_promotion())
	_check(not tower.tracker.has_pending_promotion(), "cancel control clears the promotion")

	await _activate(game._path_upg_btns[1], func() -> bool:
		return tower.tracker.has_pending_promotion())
	game._update_hud(Time.get_ticks_msec())
	game.set_process(false)
	await get_tree().create_timer(1.2).timeout
	var wall_at_confirm: int = Time.get_ticks_msec()
	var sim_at_confirm: int = game.game_state.sim_now()
	_check(wall_at_confirm - sim_at_confirm > 800, "wall clock has diverged from simulation time")
	await _activate(game._promotion_confirm_btn, func() -> bool:
		return tower.tracker.primary_path != "")
	_check(absi(tower.burst_until - (sim_at_confirm + 6000)) <= 1,
		"promotion burst is stamped on simulation time (%d vs sim %d)"
		% [tower.burst_until, sim_at_confirm])
	_check(absi(tower.burst_until - (wall_at_confirm + 6000)) > 400,
		"promotion burst is not stamped on wall time")
	var boosted: int = tower.get_effective_damage(game.game_state.sim_now())

	# Keep the wave alive past the 6s burst. A killing tower would end the
	# wave while the bonus is still inside its window, and the shop freezes
	# the simulation clock.
	tower.last_shot_ms = 1000000
	game.game_state.wave_enemy_total = 3
	game.game_state.spawn_interval_ms = 400
	game._update_hud(Time.get_ticks_msec())
	await _activate(game._wave_btn, func() -> bool: return not game.game_state.wave_ready)
	_check(not game.game_state.wave_ready, "wave button starts the wave")
	var wall := Time.get_ticks_msec()
	var steps := 0
	while game.game_state.sim_now() < tower.burst_until and game.game_state.game_state == "playing" and steps < 400:
		wall += 50
		game.game_state.update_simulation(wall)
		steps += 1
	var expired: int = tower.get_effective_damage(game.game_state.sim_now())
	_check(game.game_state.sim_now() >= tower.burst_until,
		"simulation time reached the burst boundary (sim %d, burst %d)"
		% [game.game_state.sim_now(), tower.burst_until])
	_check(expired < boosted, "damage bonus expires once simulation time passes burst_until (%d -> %d)"
		% [boosted, expired])
	while not game.game_state.wave_shop_pending and game.game_state.game_state == "playing" and steps < 8000:
		wall += 50
		game.game_state.update_simulation(wall)
		steps += 1
	_check(game.game_state.wave_shop_pending, "finishing the wave opens the shop (%d steps)" % steps)
	game.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	if game.game_state.wave_shop_pending:
		var before_fp: String = _shop_fingerprint(game.game_state)
		var offers: Array = game.game_state.get_wave_shop_offers()
		var bogus: Dictionary = game.game_state.apply_action(
			{"type": "wave_shop_pick", "card_id": "not_offered"}, game.game_state.sim_now())
		_check(not bogus.get("success", true), "an unoffered card is rejected")
		_check(game.game_state.wave_shop_pending, "a rejected card leaves the shop open")
		var picked_id: String = str(offers[0].get("id", "")) if not offers.is_empty() else ""
		var card_btn: Button = game._wave_shop._card_btns[0] if game._wave_shop._card_btns.size() > 0 else null
		_check(card_btn != null, "the shop shows a choosable card")
		if card_btn != null:
			await _activate(card_btn, func() -> bool: return not game.game_state.wave_shop_pending)
		_check(not game.game_state.wave_shop_pending, "clicking an offered card closes the shop")
		_check(_shop_fingerprint(game.game_state) != before_fp, "the chosen card changes game state (%s)" % picked_id)
		var again: Dictionary = game.game_state.apply_action(
			{"type": "wave_shop_pick", "card_id": picked_id}, game.game_state.sim_now())
		_check(not again.get("success", true), "a second pick of the same card is rejected")

	game.game_state.gold = 0
	var broke: int = game.game_state.towers.size()
	await _activate(game._shop_btns["cannon"], func() -> bool: return true)
	_check(game.game_state.towers.size() == broke, "cannon click with no credits does not place")

	await _activate(game._pause_btn, func() -> bool: return game.game_state.paused)
	game._update_hud(Time.get_ticks_msec())
	var wave_before_restart: int = game.game_state.wave
	await _activate(game._restart_btn, func() -> bool: return game.view_state.confirm_restart)
	game._update_hud(Time.get_ticks_msec())
	_check(game.view_state.confirm_restart, "the first restart press asks for confirmation")
	_check(str(game._msg_label.text).find("Restart") >= 0, "restart confirmation is visible")
	_check(game.game_state.wave == wave_before_restart, "an unconfirmed restart does not reset the run")
	await _activate(game._restart_btn, func() -> bool: return game.game_state.wave == 1 and game.game_state.towers.is_empty())
	_check(game.game_state.wave == 1 and game.game_state.towers.is_empty(), "confirming restart clears the run")

	get_tree().change_scene_to_file("res://scenes/CyberDeckScreen.tscn")
	var deck: Node = await _wait_scene("CyberDeckScreen", 240)
	_check(deck != null, "Cyber-Deck scene opens")
	if deck != null:
		await get_tree().process_frame
		var label := _find_label(deck, "+10 Starting Credits")
		_check(label != null, "Cyber-Deck shows the starting-credit upgrade")
		if label != null:
			var scroll := label.get_parent()
			while scroll != null and not (scroll is ScrollContainer):
				scroll = scroll.get_parent()
			if scroll is ScrollContainer:
				scroll.ensure_control_visible(label)
				await get_tree().process_frame
			var buy := _find_button(label.get_parent().get_parent(), "Buy")
			_check(buy != null, "the upgrade has a Buy control")
			if buy != null:
				await _activate(buy, func() -> bool: return Progression.is_unlocked("bonus_gold_10"))
				_check(Progression.is_unlocked("bonus_gold_10"), "Buy persists the credit upgrade")

	get_tree().change_scene_to_file("res://scenes/MapSelectScreen.tscn")
	var maps2: Node = await _wait_scene("MapSelectScreen")
	if maps2 != null:
		var game2: Node = await _open_via(maps2._play_btns[0], "GameScreen")
		_check(game2 != null and game2.game_state.gold == 310,
			"the purchased upgrade changes the next run (gold %s)"
			% (game2.game_state.gold if game2 != null else "none"))
		if game2 != null:
			await _save_failure(game2)

func _save_failure(game: Node) -> void:
	game.game_state.stat_waves_survived = 1
	var blocked := "/tmp/mananet_input_journey/future.json"
	var original := "{\"version\":99,\"banked_rp\":5}"
	var f := FileAccess.open(blocked, FileAccess.WRITE)
	f.store_string(original)
	f.close()
	Progression.initialize(blocked)
	await _activate(game._pause_btn, func() -> bool: return game.game_state.paused)
	game._update_hud(Time.get_ticks_msec())
	await _activate(game._quit_btn, func() -> bool: return game.view_state.confirm_quit)
	game._update_hud(Time.get_ticks_msec())
	var first_toast: String = str(game._msg_label.text)
	_check(first_toast.find("banked") < 0, "the first quit prompt does not claim rewards were banked")
	_check(first_toast.find("leave this run") >= 0, "the first quit prompt asks the player to confirm")
	await _activate(game._quit_btn, func() -> bool: return Progression.has_pending_run())
	game._update_hud(Time.get_ticks_msec())
	var failed_toast: String = str(game._msg_label.text)
	_check(failed_toast.find("not saved") >= 0, "a failed abandon says rewards were not saved (%s)" % failed_toast)
	_check(Progression.has_pending_run(), "the unsaved run is kept")
	_check(FileAccess.get_file_as_string(blocked) == original, "the future-version profile was not replaced")
	await _mouse_click(game._quit_btn)
	if get_tree().current_scene == game:
		game._on_quit_pressed()
	await get_tree().create_timer(0.6).timeout
	var menu: Node = await _wait_scene("MenuScreen", 120)
	_check(menu != null, "leaving after a failed save returns to the menu")
	if menu == null:
		return
	var retry := menu.find_child("RetrySaveBtn", true, false) as Button
	_check(retry != null, "the menu offers Retry Save")
	if retry == null:
		return
	await _activate(retry, func() -> bool: return str(retry.text).find("still not saved") >= 0)
	_check(Progression.has_pending_run(), "retry stays pending while the profile is blocked")
	var recovered: Dictionary = Progression.recover_blocked_profile()
	_check(recovered.get("success", false), "deliberate recovery preserves a backup and unlocks writes")
	var backup := str(recovered.get("backup", ""))
	_check(backup != "" and FileAccess.get_file_as_string(backup) == original,
		"recovery backup matches the original future profile")
	await _activate(retry, func() -> bool: return not Progression.has_pending_run())
	_check(not Progression.has_pending_run(), "Retry Save commits the pending run")
	var committed := FileAccess.get_file_as_string(blocked)
	_check(committed.find("run_history") >= 0, "the committed profile contains the run")
	var again: Dictionary = Progression.retry_pending_run()
	_check(again.get("duplicate", false), "a second retry does not award the run again")
	_check(FileAccess.get_file_as_string(blocked) == committed, "the second retry does not rewrite the profile")
