extends Node

# Interaction test: pushes real mouse events at real control rects and verifies
# the resulting state. This is the layer headless geometry tests cannot cover:
# a control that is on-screen and correctly sized but does not receive clicks.
#
# Run: godot --headless --path . res://tests/ui/InteractionTest.tscn

const REAL_SAVE_PATH := "user://td_progression.json"
const SANDBOX_PATH := "user://td_progression.interaction.json"

var _pass: int = 0
var _fail: int = 0
var _real_before: PackedByteArray = PackedByteArray()
var _real_existed: bool = false

func _ready() -> void:
	var root: Window = get_tree().root
	root.content_scale_size = Vector2i(900, 600)
	root.size = Vector2i(900, 600)
	await get_tree().process_frame
	await get_tree().process_frame
	_real_existed = FileAccess.file_exists(REAL_SAVE_PATH)
	if _real_existed:
		_real_before = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	Progression.set_save_path(SANDBOX_PATH)
	Progression.load_profile()
	Progression.reset_settings()
	await _run()
	_verify_real_save_untouched()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _mount(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene

func _unmount(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame

func _click_control(ctrl: Control) -> void:
	var pos: Vector2 = ctrl.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	get_viewport().push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	get_viewport().push_input(up)
	await get_tree().process_frame
	await get_tree().process_frame

func _click_at(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	get_viewport().push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	get_viewport().push_input(up)
	await get_tree().process_frame
	await get_tree().process_frame

func _run() -> void:
	await _test_game_screen_clicks()
	await _test_settings_and_deck_clicks()
	await _test_modifier_clicks()

# ---------------------------------------------------------------------------
# Gameplay HUD: shop -> placement -> select -> upgrade -> speed -> pause ->
# sell confirmation -> wave shop -> modal input priority.
# ---------------------------------------------------------------------------

func _test_game_screen_clicks() -> void:
	print("--- GAMEPLAY HUD CLICKS ---")
	Progression.pending_map_id = 0
	var game: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame
	var gs: GameState = game.game_state
	gs.gold = 0
	await _click_control(game._shop_btns["archer"])
	_check(not game.view_state.placement_active
			and game.view_state.get_toast(Time.get_ticks_msec()).contains("Need"),
		"clicking an unaffordable shop card explains the shortfall")
	gs.gold = 1000

	# Shop click enters placement.
	await _click_control(game._shop_btns["archer"])
	_check(game.view_state.placement_active and game.view_state.placement_tower_type == "archer",
		"clicking a shop card enters placement for that tower")

	# A second click on the same card cancels, and a third re-enters.
	await _click_control(game._shop_btns["archer"])
	_check(not game.view_state.placement_active,
		"clicking the active shop card again cancels placement")
	await _click_control(game._shop_btns["archer"])
	_check(game.view_state.placement_active,
		"clicking the shop card after cancelling re-enters placement")

	# World click places at the clicked location.
	var world_pos := Vector2(300, 240)
	await _click_at(game._world_to_screen(world_pos))
	_check(gs.towers.size() == 1, "clicking the map places the selected tower (got %d)" % gs.towers.size())
	if gs.towers.size() != 1:
		await _unmount(game)
		return
	var tower: Tower = gs.towers[0]
	_check(tower.pos.distance_to(world_pos) < 40.0,
		"tower lands near the clicked map position (%.1f px)" % tower.pos.distance_to(world_pos))

	# Click the tower and upgrade it through the panel button.
	await _click_control(game._shop_btns["archer"])   # placement on; click tower cancels into selection
	await _click_at(game._world_to_screen(tower.pos))
	_check(game.view_state.selected_tower_id == tower.id, "clicking a placed tower selects it")
	await get_tree().process_frame
	game._update_hud(Time.get_ticks_msec())
	await get_tree().process_frame
	var level_before: int = tower.level
	await _click_control(game._base_upg_btn)
	_check(tower.level > level_before, "clicking the upgrade button raises the tower level")
	var path_texts: Array = game._path_upg_btns.map(func(b): return (b as Button).text)
	_check(path_texts.any(func(t): return str(t).contains("Top +")),
		"path upgrade buttons show the full branch choice, not a 7-char truncation")
	_check(game._tower_stats_label.text.contains("DMG") and not game._tower_stats_label.text.contains("⚔"),
		"tower stats use readable labels instead of missing emoji glyphs")

	# Speed and pause/resume.
	await _click_control(game._speed_btns[1])
	_check(gs.speed_multiplier == 2.0, "clicking x2 sets run speed to 2x")
	await _click_control(game._pause_btn)
	_check(gs.paused, "clicking pause pauses the simulation")
	await _click_control(game._resume_btn)
	_check(not gs.paused, "clicking Resume resumes the simulation")

	# Sell confirmation: first click arms, second sells.
	var towers_before: int = gs.towers.size()
	await _click_control(game._sell_btn)
	_check(gs.towers.size() == towers_before and game.view_state.confirm_sell,
		"first Sell click arms confirmation without selling")
	await _click_control(game._sell_btn)
	_check(gs.towers.size() == towers_before - 1, "second Sell click sells the tower")

	# Wave button starts the wave.
	gs.wave_ready = true
	game._update_hud(Time.get_ticks_msec())
	await get_tree().process_frame
	await _click_control(game._wave_btn)
	_check(not gs.wave_ready, "clicking Start Wave begins the wave")

	# Wave shop: click the real Choose button.
	gs.wave_shop_pending = true
	gs.wave_ready = false
	game._update_hud(Time.get_ticks_msec())
	await get_tree().process_frame
	_check(game._wave_shop_modal.visible, "wave-shop modal opens from the simulation gate")
	if game._wave_shop_modal.visible:
		game._wave_shop._card_btns[0].grab_focus()
		await _click_control(game._wave_shop._card_btns[0])
		_check(not gs.wave_shop_pending, "clicking Choose accepts the offered wave-shop card")

	# Modal priority: a click on the HUD behind the modal must do nothing.
	gs.wave_shop_pending = true
	gs.wave_ready = false
	game._update_hud(Time.get_ticks_msec())
	await get_tree().process_frame
	var speed_before: float = gs.speed_multiplier
	var gold_before: int = gs.gold
	await _click_control(game._speed_btns[0])
	_check(gs.speed_multiplier == speed_before,
		"a modal backdrop blocks HUD clicks behind the wave-shop dialog")
	_check(gs.gold == gold_before and game._wave_shop_modal.visible,
		"a blocked HUD click does not trigger a secondary action")

	await _unmount(game)

# ---------------------------------------------------------------------------
# Settings toggle and Cyber-Deck buy through real button clicks.
# ---------------------------------------------------------------------------

func _test_settings_and_deck_clicks() -> void:
	print("--- SETTINGS / CYBER-DECK CLICKS ---")
	Progression.reset_settings()
	var settings: Node = await _mount("res://scenes/SettingsScreen.tscn")
	var before: bool = Progression.get_settings().get("fast_promotion_enabled", false)
	var toggle: Button = null
	for row in settings._rows_box.get_children():
		if not row is HBoxContainer:
			continue
		var row_text := ""
		for node in row.get_children():
			for lbl in _find_labels(node, []):
				row_text += lbl.text + "\n"
		if row_text.contains("Fast Promotion"):
			for child in row.get_children():
				if child is Button:
					toggle = child
					break
		if toggle != null:
			break
	_check(toggle != null, "settings exposes a clickable toggle")
	if toggle != null:
		await _click_control(toggle)
		var after: bool = Progression.get_settings().get("fast_promotion_enabled", false)
		_check(after != before, "clicking a settings toggle flips the persisted setting")
	await _unmount(settings)

	# Seed Shards so the first shop purchase is affordable.
	Progression.get_profile()["banked_rp"] = 500
	Progression.save_profile()
	Progression.load_profile()
	var deck: Node = await _mount("res://scenes/CyberDeckScreen.tscn")
	await get_tree().process_frame
	var buy: Button = null
	for btn in _find_buttons(deck, []):
		if btn.text == "Buy":
			buy = btn
			break
	_check(buy != null, "Cyber-Deck exposes a clickable Buy button")
	if buy != null:
		deck._scroll.ensure_control_visible(buy)
		await get_tree().process_frame
		var rp_before: int = Progression.get_banked_rp()
		await _click_control(buy)
		_check(Progression.get_banked_rp() < rp_before,
			"clicking Buy spends Shards (%d -> %d)" % [rp_before, Progression.get_banked_rp()])
		_check(Progression.get_profile().get("unlocked", []).size() > 0,
			"clicking Buy unlocks the first starting-tower upgrade")
	await _unmount(deck)

func _find_labels(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Label:
			out.append(child)
		_find_labels(child, out)
	return out

func _find_buttons(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_find_buttons(child, out)
	return out

# ---------------------------------------------------------------------------
# Map modifier chips are real toggle controls, not decoration.
# ---------------------------------------------------------------------------

func _test_modifier_clicks() -> void:
	print("--- MAP MODIFIER CLICKS ---")
	var profile: Dictionary = Progression.get_profile()
	for mod_id in ["mod_iron_economy", "mod_glass_cannon"]:
		if not mod_id in profile["unlocked"]:
			profile["unlocked"].append(mod_id)
	Progression.save_profile()
	Progression.load_profile()
	Progression.set_active_modifier("")
	var maps: Node = await _mount("res://scenes/MapSelectScreen.tscn")
	await get_tree().process_frame
	_check(maps._mod_btns.has("mod_iron_economy"), "map select renders owned modifier chips")
	if maps._mod_btns.has("mod_iron_economy"):
		await _click_control(maps._mod_btns["mod_iron_economy"])
		_check(Progression.get_active_modifier() == "mod_iron_economy",
			"clicking a modifier chip activates it")
	await _unmount(maps)
	Progression.set_active_modifier("")

func _verify_real_save_untouched() -> void:
	var now := PackedByteArray()
	var exists_now: bool = FileAccess.file_exists(REAL_SAVE_PATH)
	if exists_now:
		now = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	_check(exists_now == _real_existed, "real profile existence unchanged by interaction test")
	_check(now == _real_before, "real profile byte-identical after interaction test")
	for path in [SANDBOX_PATH, SANDBOX_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
