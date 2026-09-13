extends Node

# Headless UI regression: executes the P0-fixed screen code paths with real
# data shapes. Run with:
#   godot --headless --path . res://tests/ui/UIRegressionTest.tscn
#
# Hermetic by design:
# - EndScreen test uses only the in-memory pending_end_stats autoload var.
# - Menu/GameScreen tests swap user://td_progression.json for a seeded profile,
#   then restore the original bytes and verify restoration. A second copy of
#   the original save is written to a separate (portable) harness path before
#   anything is touched.

const SAVE_PATH := "user://td_progression.json"
const BACKUP_PATH := "user://td_progression.harness_backup.json"
const EXT_BACKUP_PATH := "user://td_progression.harness_ext_backup.json"

var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _run() -> void:
	print("--- UI REGRESSION CHECKS ---")
	await _test_end_screen_milestones()
	var sandbox_open := _open_save_sandbox()
	if sandbox_open:
		await _test_menu_with_seeded_history()
		await _test_restart_with_clean_meta()
		_close_save_sandbox_and_verify()
	else:
		_fail += 1
		push_error("[FAIL] could not open save sandbox; skipping disk-dependent tests")
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _collect_labels(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		out += _collect_labels(child)
	if node is Label or node is RichTextLabel or node is Button:
		out += str(node.text) + "\n"
	return out

func _mount(scene_path: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene

func _unmount(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# 1) EndScreen — milestone contract (producer keys from Progression.record_run)
# ---------------------------------------------------------------------------

func _test_end_screen_milestones() -> void:
	Progression.pending_end_stats = {
		"won": false, "waves": 10, "perfect_waves": 3, "lives": 4,
		"map_id": 0, "towers_placed": 9, "enemies_killed": 88,
		"gold_earned": 4200, "rp_earned": 150,
		"newly_unlocked_variants": ["Veteran Archer"],
		"milestone_deltas": [{
			"label": "Permafrost Tower",
			"uses_now": 10, "uses_max": 12, "kills_now": 75, "kills_max": 150,
			"run_uses": 2, "run_kills": 20,
		}],
	}
	var screen: Node = await _mount("res://scenes/EndScreen.tscn")
	var text := _collect_labels(screen)
	_check(text.contains("GAME OVER"), "EndScreen renders loss title")
	_check(text.contains("UNLOCKED") and text.contains("Veteran Archer"),
		"newly-unlocked variant callout renders")
	_check(text.contains("TOWER PROGRESS"), "milestone section header renders")
	_check(text.contains("Permafrost Tower"), "milestone row renders producer 'label' key")
	_check(text.contains("Place 83%") and text.contains("Kill 50%"),
		"progress percentages computed from uses_now/uses_max + kills_now/kills_max")
	await _unmount(screen)
	Progression.pending_end_stats = {}

# ---------------------------------------------------------------------------
# Save sandbox — swap real profile for a seeded one, restore afterwards
# ---------------------------------------------------------------------------

var _had_save: bool = false
var _original_bytes: PackedByteArray = PackedByteArray()

func _open_save_sandbox() -> bool:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_original_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
		var ext := FileAccess.open(EXT_BACKUP_PATH, FileAccess.WRITE)
		if ext:
			ext.store_buffer(_original_bytes)
			ext.close()
	_write_seed_profile()
	return FileAccess.file_exists(SAVE_PATH)

func _write_seed_profile() -> void:
	var zeros := {"archer": 0, "mage": 0, "cannon": 0, "sniper": 0, "frost": 0, "lightning": 0}
	var av := {"archer": "", "mage": "", "cannon": "", "sniper": "", "frost": "", "lightning": ""}
	var profile := {
		"version": 1, "engine": "godot", "total_rp": 120, "banked_rp": 120,
		"unlocked": [], "unlocked_variants": [],
		"tower_use_counts": zeros.duplicate(),
		"tower_kill_counts": zeros.duplicate(),
		"settings": {"confirm_restart": true},
		"active_starting_tower": "", "active_modifier": "", "active_modifier_2": "",
		"active_variants": av,
		# Last entry has map_id as float — the exact post-JSON round-trip shape
		# that used to be assigned into a String-typed local and error out.
		"run_history": [
			{"map_id": 1, "waves": 7, "perfect": 2, "lives": 3,
				"gold_earned": 3000, "gold_spent": 2400, "rp_earned": 90, "won": false},
			{"map_id": 2.0, "waves": 12, "perfect": 5, "lives": 6,
				"gold_earned": 6000, "gold_spent": 5200, "rp_earned": 160, "won": false},
		],
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(profile))
	f.close()

func _close_save_sandbox_and_verify() -> void:
	if _had_save:
		var rf := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		rf.store_buffer(_original_bytes)
		rf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var now_bytes: PackedByteArray = (
		FileAccess.get_file_as_bytes(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH)
		else PackedByteArray())
	_check(now_bytes == _original_bytes, "real save file byte-identical after harness run")
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	if FileAccess.file_exists(EXT_BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EXT_BACKUP_PATH))

# ---------------------------------------------------------------------------
# 2) MenuScreen — run-history driven labels (int AND float map_id entries)
# ---------------------------------------------------------------------------

func _test_menu_with_seeded_history() -> void:
	var menu: Node = await _mount("res://scenes/MenuScreen.tscn")
	var text := _collect_labels(menu)
	_check(not text.is_empty(), "MenuScreen mounts and builds labels")
	_check(text.contains("Spiral"), "play-context resolves float map_id 2.0 to map name 'Spiral'")
	_check(text.contains("Last reached Wave 12"), "play-context shows last-run wave")
	_check(text.contains("Best: Wave 12"), "last-run label shows best wave")
	_check(text.contains("0W / 2L"), "win/loss tally renders from history")
	await _unmount(menu)

# ---------------------------------------------------------------------------
# 3) GameScreen — world-tap restart must rebuild through _restart_current_run
# ---------------------------------------------------------------------------

func _test_restart_with_clean_meta() -> void:
	Progression.pending_map_id = 0
	var gs: Node = await _mount("res://scenes/GameScreen.tscn")
	var old_state: GameState = gs.game_state
	old_state.gold = 9999
	old_state.lives = 3
	gs.view_state.confirm_restart = true
	var action: Dictionary = gs.input_ctrl.handle_press(Vector2(400, 300), Time.get_ticks_msec())
	_check(str(action.get("type")) == "restart_game",
		"confirmed world-tap emits restart_game action")
	gs._dispatch(action, Time.get_ticks_msec())
	await get_tree().process_frame
	_check(gs.game_state != old_state,
		"restart rebuilds GameState instance (not apply_action's in-place _init)")
	_check(gs.game_state.gold == 300, "credits reset to base after restart (got %d)" % gs.game_state.gold)
	_check(gs.game_state.lives == 10, "integrity reset to base after restart")
	_check(gs.view_state != null and gs.view_state.confirm_restart == false,
		"fresh ViewState created and confirm flag cleared")
	_check(gs._prev_lives == gs.game_state.lives and gs._prev_wave == gs.game_state.wave,
		"_prev_* edge trackers resynced after rebuild")
	await _unmount(gs)
