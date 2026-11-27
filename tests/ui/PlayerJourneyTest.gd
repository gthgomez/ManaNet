extends Node

# End-to-end player journey through REAL scenes (Workstream D3).
#
# The simulation harness proves the rules; this proves the player can actually
# reach them: Main Menu -> Map Select -> Game -> place/upgrade -> wave shop ->
# pause/quit -> End screen -> Cyber-Deck purchase -> second run.
#
# Isolation: redirects Progression to a scratch profile before mounting anything,
# so no real player save is opened. Asserts the real profile is untouched.
#
# Run: godot --headless --path . res://tests/ui/PlayerJourneyTest.tscn

const REAL_SAVE_PATH := "user://td_progression.json"
const SANDBOX_PATH := "user://td_progression.journey.json"

var _pass: int = 0
var _fail: int = 0
var _real_before: PackedByteArray = PackedByteArray()
var _real_existed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_real_existed = FileAccess.file_exists(REAL_SAVE_PATH)
	if _real_existed:
		_real_before = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	Progression.set_save_path(SANDBOX_PATH)
	Progression.load_profile()
	await _run()
	_verify_real_save_untouched()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _mount(scene_path: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene

func _unmount(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame

func _labels(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		out += _labels(child)
	if node is Label or node is RichTextLabel or node is Button:
		out += str(node.text) + "\n"
	return out

func _run() -> void:
	print("--- PLAYER JOURNEY ---")
	# Give the player a bank so Cyber-Deck has something to spend.
	var profile: Dictionary = Progression.get_profile()
	profile["banked_rp"] = 400
	Progression.save_profile()

	await _journey_main_to_game()
	await _journey_play_and_end_screen()
	await _journey_cyberdeck_purchase()
	await _journey_second_run()

# ---------------------------------------------------------------------------
# Menu -> Map Select -> Game
# ---------------------------------------------------------------------------

func _journey_main_to_game() -> void:
	var menu: Node = await _mount("res://scenes/MenuScreen.tscn")
	var text := _labels(menu)
	_check(text.contains("PLAY") or text.contains("Play") or text.contains("START"),
		"main menu exposes a play affordance")
	await _unmount(menu)

	var map_sel: Node = await _mount("res://scenes/MapSelectScreen.tscn")
	var map_text := _labels(map_sel)
	_check(map_text.contains("S-CURVE") or map_text.contains("S-Curve"), "map select lists the S-Curve map")
	_check(map_text.contains("GAUNTLET") or map_text.contains("Gauntlet"), "map select lists the Gauntlet map")
	_check(map_text.contains("SPIRAL") or map_text.contains("Spiral"), "map select lists the Spiral map")

	# Select a map the same way the button does, then enter the game screen.
	Progression.pending_map_id = 0
	await _unmount(map_sel)

	var game: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame
	_check(game.game_state != null, "game screen builds a GameState")
	_check(game.game_state.gold == 300, "run starts with 300 credits (got %d)"
		% game.game_state.gold)
	_check(game.game_state.wave == 1, "run starts at wave 1")
	await _unmount(game)

# ---------------------------------------------------------------------------
# Play: place a tower, upgrade it, run a wave, reach the wave shop, quit
# ---------------------------------------------------------------------------

func _journey_play_and_end_screen() -> void:
	Progression.pending_map_id = 0
	var gs_screen: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame
	var gs: GameState = gs_screen.game_state

	# Place a tower through the same action path the UI dispatches.
	var placed_id: int = -1
	for pos in [Vector2(300, 240), Vector2(400, 240), Vector2(500, 300), Vector2(250, 300)]:
		var res: Dictionary = gs.apply_action(
			{"type": "place_tower", "tower_type": "archer", "pos": pos}, Time.get_ticks_msec())
		if res.get("success", false):
			placed_id = int(res.get("tower_id", -1))
			break
	_check(placed_id >= 0, "tower placement succeeds from the game screen")
	_check(gs.towers.size() >= 1, "placed tower is registered in the run")

	# Upgrade it.
	gs.gold = 1000
	var up: Dictionary = gs.apply_action({"type": "upgrade_base", "tower_id": placed_id},
		Time.get_ticks_msec())
	_check(up.get("success", false), "base upgrade succeeds with credits")
	_check(gs.get_tower_by_id(placed_id).level >= 2, "tower level increases after upgrade")

	# Real interaction path: selecting a tower in the world, cycling targeting,
	# and the two-tap sell confirmation.
	var tower_before = gs.get_tower_by_id(placed_id)
	var select_action: Dictionary = gs_screen.input_ctrl.handle_press(
		tower_before.pos, Time.get_ticks_msec())
	_check(str(select_action.get("type", "")) == "select_tower",
		"world tap selects a placed tower")
	_check(gs_screen.view_state.selected_tower_id == placed_id,
		"selected tower id matches the world tap target")
	var mode_before: String = tower_before.target_mode
	var tgt: Dictionary = gs.apply_action(
		{"type": "cycle_target_mode", "tower_id": placed_id}, Time.get_ticks_msec())
	_check(tgt.get("success", false) and tower_before.target_mode != mode_before,
		"target mode cycles and changes the tower's targeting (%s -> %s)"
			% [mode_before, tower_before.target_mode])
	var towers_before: int = gs.towers.size()
	gs_screen._on_sell_pressed()
	_check(gs.towers.size() == towers_before,
		"first sell tap arms confirmation without selling")
	gs_screen._on_sell_pressed()
	_check(gs.towers.size() == towers_before - 1,
		"second sell tap sells the selected tower")
	# Replace the sold tower so the wave test still has a defender.
	var replacement_id: int = -1
	for pos in [Vector2(300, 240), Vector2(400, 240), Vector2(500, 300), Vector2(250, 300)]:
		var res2: Dictionary = gs.apply_action(
			{"type": "place_tower", "tower_type": "archer", "pos": pos}, Time.get_ticks_msec())
		if res2.get("success", false):
			replacement_id = int(res2.get("tower_id", -1))
			break
	_check(replacement_id >= 0, "a replacement tower can be placed after selling")

	# Start and finish a wave, then confirm the wave-shop gate appears and the
	# modal is what the UI shows.
	gs.wave_enemy_total = 6
	gs.start_wave()
	var guard: int = 0
	while not gs.wave_shop_pending and guard < 20000:
		gs.update_simulation(gs.wall_now() + 16)
		guard += 1
	_check(gs.wave_shop_pending, "finishing a wave opens the wave-shop gate")
	var offers: Array = gs.get_wave_shop_offers()
	_check(offers.size() == 3, "wave shop offers 3 cards (got %d)" % offers.size())

	# Pick the first offered card through the authoritative action.
	var pick: Dictionary = gs.apply_action(
		{"type": "wave_shop_pick", "card_id": str(offers[0].get("id", ""))},
		Time.get_ticks_msec())
	_check(pick.get("success", false), "a UI-rendered offer is accepted by the simulation")
	_check(not gs.wave_shop_pending, "wave-shop gate closes after a pick")

	# Quit/abandon flow must bank once and route to the end screen.
	var survived_before: int = gs.stat_waves_survived
	gs.stat_waves_survived = maxi(1, survived_before)
	var rp_before: int = Progression.get_banked_rp()
	gs_screen.view_state.confirm_quit = true
	gs_screen._on_quit_pressed()
	_check(Progression.get_banked_rp() >= rp_before,
		"abandoning a run banks progression without losing RP")
	await get_tree().process_frame
	# GameScreen fades out then changes scene; clean up whatever is mounted.
	for child in get_tree().root.get_children():
		if child != self and child is Node and child.scene_file_path != "":
			child.queue_free()
	await get_tree().process_frame

	# End screen renders a terminal summary from the recorded stats.
	Progression.pending_end_stats = {
		"won": false, "waves": 5, "perfect_waves": 1, "lives": 3, "map_id": 0,
		"towers_placed": 4, "enemies_killed": 40, "gold_earned": 1800, "rp_earned": 60,
		"newly_unlocked_variants": [], "milestone_deltas": [],
	}
	var end_screen: Node = await _mount("res://scenes/EndScreen.tscn")
	var end_text := _labels(end_screen)
	_check(end_text.contains("GAME OVER"), "end screen renders the loss state")
	_check(end_text.contains("Credits") or end_text.contains("CREDITS"),
		"end screen uses product terminology (Credits)")
	await _unmount(end_screen)
	Progression.pending_end_stats = {}

# ---------------------------------------------------------------------------
# Cyber-Deck: buy an upgrade and prove it persists
# ---------------------------------------------------------------------------

func _journey_cyberdeck_purchase() -> void:
	var deck: Node = await _mount("res://scenes/CyberDeckScreen.tscn")
	await get_tree().process_frame
	var text := _labels(deck)
	_check(not text.is_empty(), "Cyber-Deck renders its catalogue")
	var rp_before: int = Progression.get_banked_rp()
	var result: Dictionary = Progression.purchase_upgrade("start_archer")
	_check(result.get("success", false), "Cyber-Deck purchase succeeds with banked RP")
	_check(Progression.is_unlocked("start_archer"), "purchased upgrade is unlocked")
	_check(Progression.get_banked_rp() < rp_before, "purchase spends banked RP")
	await _unmount(deck)

	# The purchase must survive a reload from disk (not just memory).
	var reloaded = load("res://autoloads/Progression.gd").new()
	reloaded.initialize(SANDBOX_PATH)
	_check(reloaded.is_unlocked("start_archer"),
		"Cyber-Deck purchase persists across a profile reload")
	reloaded.free()

# ---------------------------------------------------------------------------
# Second run: the purchased upgrade must actually take effect
# ---------------------------------------------------------------------------

func _journey_second_run() -> void:
	Progression.set_active_starting_tower("start_archer")
	var cfg: Dictionary = Progression.get_run_config()
	_check(str(cfg.get("starting_tower_type", "")) == "archer",
		"active starting tower resolves into the run config")
	Progression.pending_map_id = 0
	var game: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame
	_check(game.game_state.towers.size() >= 1,
		"second run starts with the purchased free tower already placed (%d towers)"
			% game.game_state.towers.size())
	_check(game.game_state.wave == 1 and game.game_state.game_state == "playing",
		"second run begins in a fresh playable state")
	await _unmount(game)

func _verify_real_save_untouched() -> void:
	var now := PackedByteArray()
	var exists_now: bool = FileAccess.file_exists(REAL_SAVE_PATH)
	if exists_now:
		now = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	_check(exists_now == _real_existed, "real profile existence unchanged by journey test")
	_check(now == _real_before, "real profile byte-identical after journey test")
	for path in [SANDBOX_PATH, SANDBOX_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
