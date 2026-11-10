extends SceneTree

# Destructive-failure tests for player-save persistence (Workstream A3).
#
# Every test drives a fresh Progression instance against a scratch path under
# user://. The verifier runs this with MANANET_PROFILE_PATH set, so user:// is
# already an isolated directory — the real player profile is never opened.
#
# Run: godot --headless --path . --script tests/simulation/save_faults.gd

const ProgressionScript := preload("res://autoloads/Progression.gd")
const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")

const SCRATCH := "user://save_faults"

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("--- SAVE FAULT INJECTION ---")
	_ensure_scratch()
	_test_save_before_initialize_persists()
	_test_invalid_json_is_quarantined()
	_test_invalid_schema_is_normalized()
	_test_missing_fields_get_defaults()
	_test_unsupported_version_is_preserved()
	_test_failed_temp_write_reports_failure()
	_test_failed_commit_reports_failure()
	_test_interrupted_save_ignores_orphan_temp()
	_test_failed_quarantine_reports_failure()
	_test_settings_persist_across_reload()
	_test_purchase_persists_across_reload()
	_test_run_record_persists_for_all_outcomes()
	_test_future_save_blocks_later_writes()
	_test_failed_quarantine_blocks_overwrite()
	_test_unreadable_profile_blocks_overwrite()
	_test_path_switch_does_not_contaminate()
	_test_old_save_migrates_without_data_loss()
	_test_current_save_keeps_bytes_until_explicit_write()
	_test_recovery_then_retry_awards_once()
	_test_environment_override_isolates_autoload()
	_clean_scratch()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	quit(1 if _fail > 0 else 0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _ensure_scratch() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))

func _path(name: String) -> String:
	return "%s/%s" % [SCRATCH, name]

func _fresh(name: String) -> Node:
	var node = ProgressionScript.new()
	node.initialize(_path(name))
	return node

func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)

func _chmod(path: String, mode: String) -> void:
	OS.execute("chmod", [mode, ProjectSettings.globalize_path(path)])

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _clean_scratch() -> void:
	var dir := DirAccess.open(SCRATCH)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [SCRATCH, file_name]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))

func _make_run_state(outcome: String) -> GameState:
	var gs := GameStateScript.new(_MAPS.MAPS[0]["path"], {}, 0)
	gs.game_state = outcome
	gs.stat_waves_survived = 7
	gs.stat_perfect_waves = 2
	gs.lives = 4
	gs.gold = 120
	gs.stat_gold_earned = 900
	gs.stat_tower_use_by_type["archer"] = 6
	gs.stat_tower_kills_by_type["archer"] = 41
	return gs

# ---------------------------------------------------------------------------
# A2 — save before initialization must actually persist
# ---------------------------------------------------------------------------

func _test_save_before_initialize_persists() -> void:
	var p = ProgressionScript.new()
	# No initialize() call: this used to hit "Refusing to save an
	# uninitialized progression profile" and silently drop the write.
	p.set_save_path(_path("before_init.json"))
	var ok: bool = p.save_profile()
	_check(ok, "save_profile() succeeds without an explicit initialize()")
	_check(FileAccess.file_exists(_path("before_init.json")),
		"save before initialize creates the profile file")
	var parsed = JSON.parse_string(_read_text(_path("before_init.json")))
	_check(parsed is Dictionary and parsed.has("version"),
		"saved profile has a version field")
	p.free()

# ---------------------------------------------------------------------------
# A2/A3 — corrupt and malformed files
# ---------------------------------------------------------------------------

func _test_invalid_json_is_quarantined() -> void:
	var path := _path("corrupt.json")
	_write_text(path, "{ this is not json")
	var p = ProgressionScript.new()
	p.initialize(path)
	_check(not FileAccess.file_exists(path),
		"unparseable save is moved out of the live path (never overwritten)")
	var dir := DirAccess.open(SCRATCH)
	var found: bool = false
	for fname in dir.get_files():
		if fname.begins_with("corrupt.json.corrupt-"):
			found = true
	_check(found, "corrupt save is quarantined under a timestamped name")
	_check(p.get_banked_rp() == 0, "corrupt save falls back to a default profile")
	p.free()

func _test_invalid_schema_is_normalized() -> void:
	var path := _path("bad_schema.json")
	_write_text(path, JSON.stringify({
		"version": 1,
		"unlocked": "not-an-array",
		"unlocked_variants": [123, "archer_veteran", ""],
		"tower_use_counts": [],
		"settings": 42,
		"total_rp": "lots",
		"banked_rp": null,
		"active_variants": {"archer": "nonexistent_variant"},
		"run_history": [1, "x", {"waves": 3}],
	}))
	var p = ProgressionScript.new()
	p.initialize(path)
	var profile: Dictionary = p.get_profile()
	_check(profile["unlocked"] is Array and profile["unlocked"].is_empty(),
		"wrong-typed 'unlocked' becomes an empty array")
	_check(profile["unlocked_variants"] == ["archer_veteran"],
		"non-string entries are dropped from unlocked_variants")
	_check(profile["tower_use_counts"] is Dictionary,
		"wrong-typed tower_use_counts becomes a dictionary")
	_check(profile["settings"] is Dictionary,
		"wrong-typed settings becomes a dictionary")
	_check(profile["total_rp"] == 0, "non-numeric total_rp falls back to 0")
	_check(profile["banked_rp"] == 0, "null banked_rp falls back to 0")
	_check(profile["active_variants"]["archer"] == "",
		"unknown active variant is cleared on load")
	_check(profile["run_history"].size() == 1,
		"only dictionary run_history entries survive normalization")
	p.free()

func _test_missing_fields_get_defaults() -> void:
	var path := _path("sparse.json")
	_write_text(path, JSON.stringify({"version": 1, "banked_rp": 55}))
	var p = ProgressionScript.new()
	p.initialize(path)
	var profile: Dictionary = p.get_profile()
	_check(profile.get("banked_rp") == 55, "present field is preserved")
	_check(profile.has("settings") and profile["settings"].has("reduce_motion"),
		"missing settings are filled from defaults")
	_check(profile.has("tower_use_counts") and profile["tower_use_counts"].has("mage"),
		"missing tower counters are filled from defaults")
	_check(p.get_settings().has("audio_muted"), "get_settings survives a sparse profile")
	p.free()

func _test_unsupported_version_is_preserved() -> void:
	var path := _path("future.json")
	var payload := JSON.stringify({"version": 99, "banked_rp": 777, "mystery": true})
	_write_text(path, payload)
	var before := _read_text(path)
	var p = ProgressionScript.new()
	p.initialize(path)
	_check(_read_text(path) == before,
		"a newer-than-supported save version is never rewritten")
	_check(p.get_banked_rp() == 0,
		"load falls back to defaults rather than guessing a future schema")
	p.free()

# ---------------------------------------------------------------------------
# A2/A3 — failed writes and commits must never be reported as success
# ---------------------------------------------------------------------------

func _test_failed_temp_write_reports_failure() -> void:
	var p = ProgressionScript.new()
	# Parent directory does not exist, so opening the temp file for write fails.
	p.set_save_path("user://no_such_dir_xyz/profile.json")
	p.initialize("user://no_such_dir_xyz/profile.json")
	var ok: bool = p.save_profile()
	_check(ok == false, "unwritable temp path reports save failure (not success)")
	_check(not FileAccess.file_exists("user://no_such_dir_xyz/profile.json"),
		"failed save leaves no partial profile file behind")
	p.free()

func _test_failed_commit_reports_failure() -> void:
	var target := _path("blocked_target.json")
	# A directory at the final path makes the file→path rename fail, so the
	# commit cannot succeed even though the temp write did.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	var p = ProgressionScript.new()
	p.set_save_path(target)
	p.initialize(target)
	var ok: bool = p.save_profile()
	_check(ok == false, "failed commit/rename reports save failure (not success)")
	_check(not FileAccess.file_exists(target + ".tmp"),
		"failed commit cleans up its temp file")
	var dir := DirAccess.open(ProjectSettings.globalize_path(target))
	_check(dir != null, "previous target is left intact after a failed commit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	p.free()

func _test_interrupted_save_ignores_orphan_temp() -> void:
	var path := _path("interrupted.json")
	var p1 = ProgressionScript.new()
	p1.initialize(path)
	p1.set_setting("sfx_enabled", false)
	_check(FileAccess.file_exists(path), "baseline save written")
	# Simulate a crash after writing the temp file but before the rename.
	_write_text(path + ".tmp", JSON.stringify({"version": 1, "banked_rp": 999999}))
	var p2 = ProgressionScript.new()
	p2.initialize(path)
	_check(p2.get_banked_rp() == 0,
		"an uncommitted temp file is never adopted as the real profile")
	_check(p2.get_settings().get("sfx_enabled") == false,
		"the last committed save is what loads after an interruption")
	p1.free()
	p2.free()

func _test_failed_quarantine_reports_failure() -> void:
	var p = ProgressionScript.new()
	p.initialize(_path("quarantine_probe.json"))
	var ok: bool = p._quarantine(_path("does_not_exist.json"), "corrupt")
	_check(ok == false, "a quarantine that cannot rename reports failure")
	p.free()

# ---------------------------------------------------------------------------
# Persistence contracts — values must survive a real reload
# ---------------------------------------------------------------------------

func _test_settings_persist_across_reload() -> void:
	var path := _path("settings.json")
	var p1 = ProgressionScript.new()
	p1.initialize(path)
	_check(p1.set_setting("reduce_motion", true), "setting write is reported committed")
	p1.set_setting("default_speed", 2.0)
	p1.free()
	var p2 = ProgressionScript.new()
	p2.initialize(path)
	_check(p2.get_settings().get("reduce_motion") == true,
		"reduce_motion survives a reload")
	_check(is_equal_approx(float(p2.get_settings().get("default_speed")), 2.0),
		"default_speed survives a reload")
	p2.free()

func _test_purchase_persists_across_reload() -> void:
	var path := _path("purchase.json")
	var p1 = ProgressionScript.new()
	p1.initialize(path)
	var profile: Dictionary = p1.get_profile()
	profile["banked_rp"] = 500
	p1.save_profile()
	var result: Dictionary = p1.purchase_upgrade("start_archer")
	_check(result.get("success", false), "purchase succeeds with enough RP")
	_check(p1.get_banked_rp() == 460, "purchase deducts the listed cost (500 -> 460)")
	p1.free()
	var p2 = ProgressionScript.new()
	p2.initialize(path)
	_check(p2.is_unlocked("start_archer"), "purchase survives a reload")
	_check(p2.get_banked_rp() == 460, "deducted balance survives a reload")
	p2.free()

func _test_run_record_persists_for_all_outcomes() -> void:
	for outcome in ["won", "game_over"]:
		var path := _path("run_%s.json" % outcome)
		var p1 = ProgressionScript.new()
		p1.initialize(path)
		var gs := _make_run_state(outcome)
		var result: Dictionary = p1.record_run(gs, 0, false)
		_check(not result.get("save_failed", false),
			"record_run(%s) reports a committed save" % outcome)
		_check(int(result.get("rp", 0)) > 0, "record_run(%s) awards RP" % outcome)
		gs.dispose()
		p1.free()
		var p2 = ProgressionScript.new()
		p2.initialize(path)
		_check(p2.get_banked_rp() > 0, "RP from a %s run survives a reload" % outcome)
		_check(p2.get_profile()["run_history"].size() == 1,
			"run history entry for a %s run survives a reload" % outcome)
		p2.free()

	# Abandonment is recorded but flagged, and must persist too.
	var path := _path("run_abandoned.json")
	var p1 = ProgressionScript.new()
	p1.initialize(path)
	var gs := _make_run_state("playing")
	p1.record_run(gs, 0, true)
	gs.dispose()
	p1.free()
	var p2 = ProgressionScript.new()
	p2.initialize(path)
	var history: Array = p2.get_profile()["run_history"]
	_check(history.size() == 1 and history[0].get("abandoned", false) == true,
		"abandoned run is persisted with its abandoned flag")
	p2.free()

# ---------------------------------------------------------------------------
# A1 — environment override protects the autoload path
# ---------------------------------------------------------------------------

func _test_future_save_blocks_later_writes() -> void:
	var path := _path("future_writes.json")
	var payload := JSON.stringify({"version": 99, "banked_rp": 777, "mystery": true})
	_write_text(path, payload)
	var before := _bytes(path)
	var p = ProgressionScript.new()
	p.initialize(path)
	var status: Dictionary = p.persistence_status()
	_check(status.get("state") == "unsupported_future",
		"future save reports unsupported_future (got %s)" % str(status.get("state")))
	_check(status.get("writes_blocked") == true, "future save blocks writes")
	_check(status.get("loaded_player_data") == false,
		"future save is not reported as a loaded player profile")
	_check(p.save_profile() == false, "save_profile refuses a future-version file")
	p._profile["banked_rp"] = 500
	var purchase: Dictionary = p.purchase_upgrade("start_archer")
	_check(purchase.get("success", true) == false, "purchase after a blocked load does not succeed")
	_check(p.set_setting("sfx_enabled", false) == false,
		"settings change after a blocked load is not committed")
	var gs := _make_run_state("won")
	var run: Dictionary = p.record_run(gs, 1, false)
	gs.dispose()
	_check(run.get("save_failed", false), "run completion after a blocked load reports save_failed")
	_check(p.has_pending_run(), "the unsaved run is retained for retry")
	_check(_bytes(path) == before, "no later write replaced the future-version bytes")
	var again := ProgressionScript.new()
	again.initialize(path)
	_check(_bytes(path) == before, "reloading the future save still does not rewrite it")
	again.free()
	p.free()

func _test_failed_quarantine_blocks_overwrite() -> void:
	var folder := _path("locked_dir")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := "%s/profile.json" % folder
	var payload := "{ not json"
	_write_text(path, payload)
	var before := _bytes(path)
	_chmod(folder, "555")
	var p = ProgressionScript.new()
	p.initialize(path)
	var status: Dictionary = p.persistence_status()
	_check(status.get("state") == "failed_quarantine",
		"unmovable corrupt save reports failed_quarantine (got %s)" % str(status.get("state")))
	_check(p.save_profile() == false, "failed quarantine refuses a follow-up save")
	var gs := _make_run_state("game_over")
	var run: Dictionary = p.record_run(gs, 0, false)
	gs.dispose()
	_check(run.get("save_failed", false), "run record after failed quarantine does not persist")
	_chmod(folder, "755")
	_check(_bytes(path) == before, "failed quarantine left the original bytes in place")
	p.free()

func _test_unreadable_profile_blocks_overwrite() -> void:
	var path := _path("unreadable.json")
	var payload := JSON.stringify({"version": 1, "banked_rp": 321, "engine": "godot"})
	_write_text(path, payload)
	var before := _bytes(path)
	_chmod(path, "000")
	var p = ProgressionScript.new()
	p.initialize(path)
	_check(p.persistence_status().get("state") == "unreadable",
		"unreadable save reports unreadable (got %s)" % str(p.persistence_status().get("state")))
	_check(p.save_profile() == false, "unreadable save is not replaced with defaults")
	var recovery: Dictionary = p.recover_blocked_profile()
	_check(recovery.get("success", true) == false,
		"recovery refuses when the original bytes cannot be preserved")
	_chmod(path, "644")
	_check(_bytes(path) == before, "unreadable save bytes survive the blocked load")
	p.free()

func _test_path_switch_does_not_contaminate() -> void:
	var path_a := _path("profile_a.json")
	var path_b := _path("profile_b.json")
	var a = ProgressionScript.new()
	a.initialize(path_a)
	a._profile["banked_rp"] = 111
	_check(a.save_profile(), "profile A commits")
	var bytes_a := _bytes(path_a)
	# Unsaved edit on A must not be flushed when the destination changes.
	a._profile["banked_rp"] = 999
	a.initialize(path_b)
	_check(not FileAccess.file_exists(path_b) or _read_text(path_b).find("999") < 0,
		"switching to B does not create B from A's unsaved memory")
	_check(_bytes(path_a) == bytes_a, "switching away from A does not rewrite A")
	a._profile["banked_rp"] = 222
	_check(a.save_profile(), "profile B commits its own data")
	a.free()
	var reload_a = ProgressionScript.new()
	reload_a.initialize(path_a)
	_check(reload_a.get_banked_rp() == 111, "profile A still has 111 after B was saved (got %d)"
		% reload_a.get_banked_rp())
	var reload_b = ProgressionScript.new()
	reload_b.initialize(path_b)
	_check(reload_b.get_banked_rp() == 222, "profile B has its own balance (got %d)"
		% reload_b.get_banked_rp())
	reload_a.free()
	reload_b.free()

func _test_old_save_migrates_without_data_loss() -> void:
	var path := _path("legacy_v0.json")
	var original := JSON.stringify({"banked_rp": 42, "total_rp": 42})
	_write_text(path, original)
	var before := _bytes(path)
	var p = ProgressionScript.new()
	p.initialize(path)
	_check(p.persistence_status().get("state") == "migrated",
		"a versionless save is migrated (got %s)" % str(p.persistence_status().get("state")))
	_check(p.get_banked_rp() == 42, "migrated save keeps banked shards")
	_check(_bytes(path) == before, "loading an old save does not rewrite it")
	_check(p.save_profile(), "explicit save commits the migrated profile")
	p.free()
	var p2 = ProgressionScript.new()
	p2.initialize(path)
	_check(p2.get_banked_rp() == 42, "migrated shards survive a reload")
	_check(int(p2.get_profile().get("version", 0)) == 1, "committed save is the current version")
	_check(p2.persistence_status().get("loaded_player_data") == true,
		"reloaded current save is player data, not fresh defaults")
	p2.free()

func _test_current_save_keeps_bytes_until_explicit_write() -> void:
	var path := _path("current.json")
	var p1 = ProgressionScript.new()
	p1.initialize(path)
	_check(p1.set_setting("reduce_motion", true), "current profile accepts a setting")
	var committed := _bytes(path)
	p1.free()
	var p2 = ProgressionScript.new()
	p2.initialize(path)
	_check(_bytes(path) == committed, "loading a current save does not rewrite its bytes")
	_check(p2.get_settings().get("reduce_motion") == true, "the loaded setting matches the file")
	p2.free()

func _test_recovery_then_retry_awards_once() -> void:
	var path := _path("recover.json")
	var payload := JSON.stringify({"version": 7, "banked_rp": 50})
	_write_text(path, payload)
	var original := _bytes(path)
	var p = ProgressionScript.new()
	p.initialize(path)
	var gs := _make_run_state("won")
	var failed: Dictionary = p.record_run(gs, 2, false)
	gs.dispose()
	_check(failed.get("save_failed", false), "run against a future save is unsaved")
	var recovery: Dictionary = p.recover_blocked_profile()
	_check(recovery.get("success", false), "explicit recovery succeeds after a verified backup")
	var backup := str(recovery.get("backup", ""))
	_check(backup != "" and _bytes(backup) == original,
		"recovery backup matches the original future-version bytes")
	var retried: Dictionary = p.retry_pending_run()
	_check(retried.get("persisted", false) and not retried.get("save_failed", true),
		"retry commits the pending run once")
	var banked_after: int = p.get_banked_rp()
	var gs_again := _make_run_state("won")
	var second: Dictionary = p.record_run(gs_again, 2, false)
	gs_again.dispose()
	_check(second.get("duplicate", false), "a second record of the same run does not award again")
	_check(p.get_banked_rp() == banked_after, "duplicate record leaves the balance unchanged")
	p.free()
	var reloaded = ProgressionScript.new()
	reloaded.initialize(path)
	_check(reloaded.get_profile()["run_history"].size() == 1,
		"reloaded profile contains the retried run exactly once")
	_check(reloaded.get_banked_rp() == banked_after, "reloaded balance matches the single award")
	reloaded.free()

func _test_environment_override_isolates_autoload() -> void:
	var p = ProgressionScript.new()
	# _init() resolves MANANET_PROFILE_PATH. When the harness sets it, the
	# default save path must not be the player's real profile.
	var env_path: String = OS.get_environment("MANANET_PROFILE_PATH")
	if env_path == "":
		_check(p._save_path == "user://td_progression.json",
			"without an override the default path is the player profile")
	else:
		_check(p._save_path == env_path,
			"MANANET_PROFILE_PATH override redirects the default save path")
		_check(p._save_path != "user://td_progression.json",
			"override keeps the autoload off the real player profile")
	p.free()
