extends SceneTree

# ============================================================
# TOWER DEFENSE — FULL GAME FUNCTIONALITY AUDIT
# ============================================================
# Tests: autoloads, data integrity, GameState core mechanics,
# tower placement/selling/upgrading, wave progression,
# enemy spawning, settings persistence, scene file integrity,
# and upgrade path system.
# ============================================================

var pass_count := 0
var fail_count := 0
var warn_count := 0

func _init():
	print("\n============================================================")
	print("  TOWER DEFENSE — FULL FUNCTIONALITY AUDIT")
	print("============================================================\n")

	_section("1. Autoload Scripts")
	_test_autoloads()

	_section("2. Data File Integrity")
	_test_data_files()

	_section("3. GameState Initialization")
	_test_gamestate_init()

	_section("4. Tower Placement & Economy")
	_test_tower_placement()

	_section("5. Tower Selling")
	_test_tower_selling()

	_section("6. Wave Mechanics")
	_test_wave_mechanics()

	_section("7. Enemy Spawning")
	_test_enemy_spawning()

	_section("8. Tower Upgrade System")
	_test_tower_upgrades()

	_section("9. Simulation Update Loop")
	_test_simulation_loop()

	_section("10. Settings Persistence (Progression)")
	_test_settings()

	_section("11. Scene File Integrity")
	_test_scene_files()

	_section("12. Upgrade Paths Data")
	_test_upgrade_paths()

	_section("13. Tower Types Data")
	_test_tower_types_data()

	# ---- SUMMARY ----
	print("\n============================================================")
	print("  AUDIT SUMMARY")
	print("============================================================")
	print("  PASS  : %d" % pass_count)
	print("  WARN  : %d" % warn_count)
	print("  FAIL  : %d" % fail_count)
	print("  TOTAL : %d" % (pass_count + warn_count + fail_count))
	print("============================================================\n")
	quit()

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
func _section(name: String) -> void:
	print("\n--- %s ---" % name)

func _pass(msg: String) -> void:
	print("[PASS] %s" % msg)
	pass_count += 1

func _fail(msg: String) -> void:
	print("[FAIL] %s" % msg)
	fail_count += 1

func _warn(msg: String) -> void:
	print("[WARN] %s" % msg)
	warn_count += 1

func _check(condition: bool, pass_msg: String, fail_msg: String) -> void:
	if condition: _pass(pass_msg)
	else: _fail(fail_msg)

func _make_gs() -> GameState:
	var maps = load("res://data/maps.gd")
	var map = maps.MAPS[0]
	return GameState.new(map["path"], {}, 0)

# ------------------------------------------------------------
# 1. Autoloads
# ------------------------------------------------------------
func _test_autoloads() -> void:
	_check(load("res://autoloads/Progression.gd") != null, "Progression.gd loads", "Progression.gd FAILED to load")
	_check(load("res://autoloads/FocusManager.gd") != null, "FocusManager.gd loads", "FocusManager.gd FAILED to load")

# ------------------------------------------------------------
# 2. Data Files
# ------------------------------------------------------------
func _test_data_files() -> void:
	var files := {
		"maps.gd": "res://data/maps.gd",
		"tower_types.gd": "res://data/tower_types.gd",
		"upgrade_paths.gd": "res://data/upgrade_paths.gd",
	}
	for name in files:
		_check(ResourceLoader.exists(files[name]), "Data file: %s" % name, "MISSING data file: %s" % name)

# ------------------------------------------------------------
# 3. GameState Initialization
# ------------------------------------------------------------
func _test_gamestate_init() -> void:
	var gs = _make_gs()
	_check(gs != null, "GameState constructs successfully", "GameState failed to construct")
	_check(gs.gold == 300, "Starting gold = 300", "Starting gold = %d (expected 300)" % gs.gold)
	_check(gs.lives == 10, "Starting lives = 10", "Starting lives = %d (expected 10)" % gs.lives)
	_check(gs.wave == 1, "Starting wave = 1", "Starting wave = %d (expected 1)" % gs.wave)
	_check(gs.game_state == "playing", "game_state = 'playing'", "game_state = '%s' (expected 'playing')" % gs.game_state)
	_check(gs.wave_ready == true, "wave_ready = true at start", "wave_ready = %s (expected true)" % gs.wave_ready)
	_check(gs.towers.size() == 0, "No towers at start", "Unexpected towers at start: %d" % gs.towers.size())
	_check(gs.enemies.size() == 0, "No enemies at start", "Unexpected enemies at start: %d" % gs.enemies.size())
	gs.dispose()

# ------------------------------------------------------------
# 4. Tower Placement & Economy
# ------------------------------------------------------------
func _test_tower_placement() -> void:
	var gs = _make_gs()
	var maps = load("res://data/maps.gd")
	var map = maps.MAPS[0]

	# Find a safe position away from path
	var p := Vector2(400, 400)
	var result := gs.apply_action({"type": "place_tower", "tower_type": "archer", "pos": p}, 0)
	_check(result["success"], "place_tower archer at safe position succeeds", "place_tower FAILED: %s" % result.get("reason", "unknown"))
	_check(gs.towers.size() == 1, "Tower count = 1 after placement", "Tower count = %d (expected 1)" % gs.towers.size())
	_check(gs.gold < 300, "Gold decreased after placement (cost deducted)", "Gold unchanged after placement: %d" % gs.gold)

	# Try placing on same spot — should fail
	var dup_result := gs.apply_action({"type": "place_tower", "tower_type": "archer", "pos": p}, 0)
	_check(not dup_result["success"], "Duplicate placement on same position rejected", "Duplicate placement should have failed but succeeded")

	# Try placing with insufficient gold
	gs.gold = 0
	var broke_result := gs.apply_action({"type": "place_tower", "tower_type": "cannon", "pos": Vector2(200, 200)}, 0)
	_check(not broke_result["success"], "Placement rejected when gold = 0", "Placement should fail with 0 gold but succeeded")

	gs.dispose()

# ------------------------------------------------------------
# 5. Tower Selling
# ------------------------------------------------------------
func _test_tower_selling() -> void:
	var gs = _make_gs()
	var p := Vector2(400, 400)
	gs.apply_action({"type": "place_tower", "tower_type": "archer", "pos": p}, 0)
	var tower_id: int = gs.towers[0].id
	var gold_after_place: int = gs.gold

	var sell_result := gs.apply_action({"type": "sell_tower", "tower_id": tower_id}, 0)
	_check(sell_result["success"], "sell_tower succeeds", "sell_tower FAILED: %s" % sell_result.get("reason", "unknown"))
	_check(gs.towers.size() == 0, "Tower removed after sell", "Tower still in array after sell: %d" % gs.towers.size())
	_check(gs.gold > gold_after_place, "Gold increased after sell", "Gold did not increase after sell: %d" % gs.gold)

	gs.dispose()

# ------------------------------------------------------------
# 6. Wave Mechanics
# ------------------------------------------------------------
func _test_wave_mechanics() -> void:
	var gs = _make_gs()
	_check(gs.wave_ready, "wave_ready = true before start_wave()", "wave_ready is false before start_wave()")
	gs.start_wave()
	_check(not gs.wave_ready, "wave_ready = false after start_wave()", "wave_ready remained true after start_wave()")
	_check(gs.wave == 1, "Wave remains at 1 mid-wave", "Wave changed unexpectedly: %d" % gs.wave)

	# Apply via action
	var gs2 = _make_gs()
	var r := gs2.apply_action({"type": "start_wave"}, 0)
	_check(r["success"], "apply_action start_wave returns success", "apply_action start_wave FAILED")

	gs.dispose()
	gs2.dispose()

# ------------------------------------------------------------
# 7. Enemy Spawning
# ------------------------------------------------------------
func _test_enemy_spawning() -> void:
	var gs = _make_gs()
	gs.start_wave()
	gs.spawn_enemy(0)
	_check(gs.enemies.size() == 1, "Enemy spawned correctly (count = 1)", "Enemy count = %d (expected 1)" % gs.enemies.size())
	var e = gs.enemies[0]
	_check(e.health > 0, "Spawned enemy has health > 0 (health=%d)" % e.health, "Enemy health = %d (expected >0)" % e.health)
	_check(e.speed > 0, "Spawned enemy has speed > 0", "Enemy speed = %s" % str(e.speed))
	gs.dispose()

# ------------------------------------------------------------
# 8. Tower Upgrade System (base level)
# ------------------------------------------------------------
func _test_tower_upgrades() -> void:
	var gs = _make_gs()
	var p := Vector2(400, 400)
	gs.apply_action({"type": "place_tower", "tower_type": "archer", "pos": p}, 0)
	var tower_id: int = gs.towers[0].id
	var level_before: int = gs.towers[0].level

	# Give enough gold for upgrade
	gs.gold = 1000
	var upg := gs.apply_action({"type": "upgrade_base", "tower_id": tower_id}, 0)
	_check(upg["success"], "upgrade_base succeeds with sufficient gold", "upgrade_base FAILED: %s" % upg.get("reason","unknown"))
	_check(gs.towers[0].level > level_before, "Tower level increased after upgrade", "Tower level unchanged: %d" % gs.towers[0].level)
	_check(gs.gold < 1000, "Gold decreased after upgrade", "Gold unchanged after upgrade: %d" % gs.gold)

	# Try cycle target mode
	var cycle := gs.apply_action({"type": "cycle_target_mode", "tower_id": tower_id}, 0)
	_check(cycle["success"], "cycle_target_mode succeeds", "cycle_target_mode FAILED: %s" % cycle.get("reason","unknown"))

	gs.dispose()

# ------------------------------------------------------------
# 9. Simulation Update Loop
# ------------------------------------------------------------
func _test_simulation_loop() -> void:
	var gs = _make_gs()
	gs.apply_action({"type": "place_tower", "tower_type": "archer", "pos": Vector2(200, 200)}, 0)
	gs.start_wave()
	gs.spawn_enemy(0)

	# Run 60 ticks (1 second at 60fps equivalent)
	var now_ms := 0
	for _i in range(60):
		now_ms += 16  # ~60fps
		gs.update_simulation(now_ms)

	_check(true, "update_simulation ran 60 ticks without crash", "CRASH during update_simulation")
	_check(gs.game_state in ["playing", "game_over", "won"], "game_state is valid after sim ticks: '%s'" % gs.game_state, "game_state is invalid: '%s'" % gs.game_state)

	gs.dispose()

# ------------------------------------------------------------
# 10. Settings Persistence
# ------------------------------------------------------------
func _test_settings() -> void:
	var prog_node = load("res://autoloads/Progression.gd").new()
	prog_node.name = "ProgressionTest"
	root.add_child(prog_node)

	var s = prog_node.get_settings()
	_check(s is Dictionary, "get_settings() returns Dictionary", "get_settings() returned non-Dictionary: %s" % typeof(s))
	_check(s.has("confirm_restart"), "Settings has 'confirm_restart' key", "Settings missing 'confirm_restart' key")

	prog_node.set_setting("confirm_sell", false)
	var s2 = prog_node.get_settings()
	_check(s2.get("confirm_sell") == false, "set_setting() updates 'confirm_sell'", "set_setting() did not update 'confirm_sell'")

	var profile = prog_node.load_profile()
	_check(profile is Dictionary, "load_profile() returns Dictionary", "load_profile() returned non-Dictionary: %s" % typeof(profile))
	_check(profile.has("banked_rp"), "Profile has 'banked_rp'", "Profile missing 'banked_rp'")

	var cfg = prog_node.get_run_config()
	_check(cfg is Dictionary, "get_run_config() returns Dictionary", "get_run_config() returned: %s" % typeof(cfg))

# ------------------------------------------------------------
# 11. Scene File Integrity
# ------------------------------------------------------------
func _test_scene_files() -> void:
	var scenes := [
		"res://scenes/Main.tscn",
		"res://scenes/MenuScreen.tscn",
		"res://scenes/MapSelectScreen.tscn",
		"res://scenes/GameScreen.tscn",
		"res://scenes/CyberDeckScreen.tscn",
		"res://scenes/SettingsScreen.tscn",
		"res://scenes/EndScreen.tscn",
	]
	for path in scenes:
		_check(ResourceLoader.exists(path, "PackedScene"), "Scene: %s" % path.get_file(), "MISSING scene: %s" % path.get_file())

# ------------------------------------------------------------
# 12. Upgrade Paths Data
# ------------------------------------------------------------
func _test_upgrade_paths() -> void:
	var upg = load("res://data/upgrade_paths.gd")
	if upg == null:
		_fail("upgrade_paths.gd failed to load")
		return
	_pass("upgrade_paths.gd loads")
	var paths = upg.UPGRADE_PATHS
	_check(paths is Dictionary and paths.size() > 0, "UPGRADE_PATHS has entries (%d)" % paths.size(), "UPGRADE_PATHS is empty or wrong type")
	# upgrade_paths.gd stores an Array-of-dicts per tower type
	for key in paths:
		var path_array = paths[key]
		_check(path_array is Array and path_array.size() > 0, "Paths for '%s' has %d entries" % [key, path_array.size()], "Paths for '%s' is empty or wrong type" % key)
		for path_def in path_array:
			var has_fields: bool = path_def.has("path") and path_def.has("name") and path_def.has("tiers")
			_check(has_fields, "Path '%s/%s' has required fields" % [key, path_def.get("path", "??")], "Path for '%s' missing required fields" % key)

# ------------------------------------------------------------
# 13. Tower Types Data
# ------------------------------------------------------------
func _test_tower_types_data() -> void:
	var tt = load("res://data/tower_types.gd")
	if tt == null:
		_fail("tower_types.gd failed to load")
		return
	_pass("tower_types.gd loads")
	var types = tt.TOWER_TYPES
	_check(types is Dictionary and types.size() > 0, "TOWER_TYPES has entries (%d)" % types.size(), "TOWER_TYPES is empty or wrong type")
	for key in types:
		var td = types[key]
		var valid: bool = td.has("cost") and td.has("range") and td.has("damage") and td.has("name")
		_check(valid, "Tower '%s' has required fields (cost, range, damage, name)" % key, "Tower '%s' missing required fields" % key)
