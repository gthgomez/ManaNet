extends Node

# Port of progression.py — persistent meta-progression singleton.
# Loaded as autoload "Progression" in project.godot.
#
# Save file: user://td_progression.json
# Atomic write: user://td_progression.tmp → rename
#
# Test/tooling isolation: set MANANET_PROFILE_PATH in the environment (or call
# initialize(path) before the first save) to redirect *all* persistence —
# including autoload startup — away from the player's real profile.

# ---------------------------------------------------------------------------
# Catalogue constants (mirrors of Python STARTING_TOWER_CHAIN etc.)
# ---------------------------------------------------------------------------

const STARTING_TOWER_CHAIN: Array = [
	# [id, cost, tower_type, label]
	["start_archer",    40,  "archer",    "Start: Free Archer"],
	["start_frost",     70,  "frost",     "Start: Free Frost"],
	["start_mage",     100,  "mage",      "Start: Free Mage"],
	["start_lightning",130,  "lightning", "Start: Free Lightning"],
	["start_sniper",   160,  "sniper",    "Start: Free Sniper"],
	["start_cannon",   200,  "cannon",    "Start: Free Cannon"],
	["start_choice",   280,  "choice",    "Start: Choose Any Tower"],
]

const MAP_MODIFIERS: Array = [
	# [id, cost, label, desc]
	["mod_iron_economy",  60, "Iron Economy",
	 "Start with -50 Credits, cannot sell towers, but earn +15% per kill"],
	["mod_glass_cannon",  80, "Glass Cannon",
	 "Start with 5 Integrity; Archer and Sniper gain +18% damage; waves give +30% Credit bonus"],
	["mod_blitz",        100, "Blitz Mode",
	 "Frost towers disabled; Lightning damage +35%; enemies move 25% faster; kill rewards +20%"],
	["mod_hardened",     120, "Hardened",
	 "Archer towers disabled; Cannon splash +25%; Mage splash +20%; all enemies have +40% HP; wave bonuses doubled"],
	["mod_sudden_death", 150, "Sudden Death",
	 "Only 1 life; tower selling disabled; earn 3x RP on clear"],
]

const MODIFIER_RP_MULT: Dictionary = {
	"mod_iron_economy":  1.2,
	"mod_glass_cannon":  1.3,
	"mod_blitz":         1.5,
	"mod_hardened":      1.8,
	"mod_sudden_death":  3.0,
}

# Pairs that CANNOT be stacked together (order-independent)
const MODIFIER_INCOMPATIBLE: Array = [
	["mod_blitz", "mod_hardened"],
	# Both override starting lives; stacking voided Glass Cannon's 5-life cost
	# while keeping its damage/gold bonus and a 3.5x RP multiplier.
	["mod_sudden_death", "mod_glass_cannon"],
]

const CONVENIENCE_UPGRADES: Array = [
	# [id, cost, label, desc]
	["bonus_gold_10",  30, "+10 Starting Credits",  "Each run begins with 10 extra Credits"],
	["bonus_gold_25",  80, "+25 Starting Credits",  "Each run begins with 25 extra Credits (replaces +10)"],
	["bonus_life_1",   50, "+1 Starting Integrity",   "Each run begins with 11 Integrity"],
	["bonus_life_2",  110, "+2 Starting Integrity",  "Each run begins with 12 Integrity (replaces +1)"],
	["unlock_geomancer", 250, "Terrestrial Resonance", "Unlock the 4th Element: Earth. Grants access to the Geomancer variant."],
]

const TOWER_VARIANTS: Array = [
	{
		"variant_key":    "archer_veteran",
		"tower_type":     "archer",
		"label":          "Veteran Archer",
		"desc":           "Seasoned marksman. +10% damage, +5% range. Unlocked by experience.",
		"use_threshold":  15,
		"kill_threshold": 200,
		"stat_delta":     {"damage": 0.10, "range": 0.05, "cooldown": 0.0, "cost": 0},
		"badge":          "V",
		"visual_tint":    Color(0.329, 0.863, 0.486),
	},
	{
		"variant_key":    "frost_permafrost",
		"tower_type":     "frost",
		"label":          "Permafrost Tower",
		"desc":           "Deeper cold. Chill duration +20%, +8% damage. Costs 10 more Credits.",
		"use_threshold":  12,
		"kill_threshold": 150,
		"stat_delta":     {"damage": 0.08, "range": 0.0, "cooldown": 0.0, "cost": 10},
		"chill_bonus":    0.20,
		"badge":          "P",
		"visual_tint":    Color(0.565, 0.933, 1.0),
	},
	{
		"variant_key":    "mage_runic",
		"tower_type":     "mage",
		"label":          "Runic Mage",
		"desc":           "Ancient runes amplify spells. +12% damage, chain jumps +1. Costs 15 more Credits.",
		"use_threshold":  10,
		"kill_threshold": 180,
		"stat_delta":     {"damage": 0.12, "range": 0.0, "cooldown": 0.0, "cost": 15},
		"chain_bonus":    1,
		"badge":          "R",
		"visual_tint":    Color(0.729, 0.518, 1.0),
	},
	{
		"variant_key":    "cannon_siege_mk2",
		"tower_type":     "cannon",
		"label":          "Siege Mk.II",
		"desc":           "Upgraded barrel. +15% splash radius, +8% damage. Costs 20 more Credits.",
		"use_threshold":  10,
		"kill_threshold": 160,
		"stat_delta":     {"damage": 0.08, "range": 0.0, "cooldown": 0.0, "cost": 20},
		"splash_bonus":   0.15,
		"badge":          "II",
		"visual_tint":    Color(1.0, 0.667, 0.337),
	},
	{
		"variant_key":    "sniper_longshot",
		"tower_type":     "sniper",
		"label":          "Longshot Sniper",
		"desc":           "Extended barrel. +20% range, +5% damage. Costs 15 more Credits.",
		"use_threshold":  10,
		"kill_threshold": 140,
		"stat_delta":     {"damage": 0.05, "range": 0.20, "cooldown": 0.0, "cost": 15},
		"badge":          "L",
		"visual_tint":    Color(0.902, 0.925, 1.0),
	},
	{
		"variant_key":    "lightning_overclocked",
		"tower_type":     "lightning",
		"label":          "Overclocked Tesla",
		"desc":           "Souped-up coils. -10% cooldown, +8% damage. Costs 15 more Credits.",
		"use_threshold":  10,
		"kill_threshold": 160,
		"stat_delta":     {"damage": 0.08, "range": 0.0, "cooldown": -0.10, "cost": 15},
		"badge":          "O",
		"visual_tint":    Color(1.0, 0.957, 0.463),
	},
	{
		"variant_key":    "mage_geomancer",
		"tower_type":     "mage",
		"label":          "Geomancer",
		"desc":           "Earth: The 4th Element. Massive crushing damage. +25% damage, ignores 20% armor.",
		"use_threshold":  15,
		"kill_threshold": 300,
		"stat_delta":     {"damage": 0.25, "range": 0.0, "cooldown": 0.0, "cost": 30},
		"armor_ignore":   0.20,
		"badge":          "G",
		"visual_tint":    Color(0.588, 0.435, 0.314),
	},
]

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Current on-disk save schema. Bumped only for breaking layout changes; older
## files are migrated forward by _normalize_profile().
const SAVE_VERSION: int = 1

## Persistence gate. Writes are allowed only from a profile this build actually
## understood. Future, unreadable, and failed-quarantine files stay byte-for-byte
## until an explicit recover_blocked_profile() call.
enum PersistState {
	UNINITIALIZED,
	READY,
	MIGRATED,
	UNSUPPORTED_FUTURE,
	CORRUPT,
	FAILED_QUARANTINE,
	UNREADABLE,
	FAILED_WRITE,
	UNSAVED_CHANGES,
}

const PERSIST_STATE_NAMES: Dictionary = {
	PersistState.UNINITIALIZED: "uninitialized",
	PersistState.READY: "ready",
	PersistState.MIGRATED: "migrated",
	PersistState.UNSUPPORTED_FUTURE: "unsupported_future",
	PersistState.CORRUPT: "corrupt",
	PersistState.FAILED_QUARANTINE: "failed_quarantine",
	PersistState.UNREADABLE: "unreadable",
	PersistState.FAILED_WRITE: "failed_write",
	PersistState.UNSAVED_CHANGES: "unsaved_changes",
}

var _profile: Dictionary = {}
var _save_path: String = "user://td_progression.json"
var _tmp_path: String = "user://td_progression.tmp"
var _initialized: bool = false
var _persist_state: int = PersistState.UNINITIALIZED
var _loaded_player_data: bool = false
var _load_origin: String = "uninitialized"
var _last_save_error: String = ""
## Run result that was computed but not committed. Retry applies this once.
var _pending_run: Dictionary = {}
var _committed_fingerprint: String = ""
var _last_commit_result: Dictionary = {}

func _init() -> void:
	# Resolve isolation before anything can load or save. Tests and tooling set
	# MANANET_PROFILE_PATH so even autoload startup never touches the real file.
	var override: String = OS.get_environment("MANANET_PROFILE_PATH")
	if override != "":
		_save_path = override
		_tmp_path = override + ".tmp"

## Redirect persistence. Changing the destination drops the in-memory profile
## without flushing it, so profile A can never be written into profile B.
func set_save_path(path: String) -> void:
	if path == "":
		return
	if path == _save_path:
		return
	_save_path = path
	_tmp_path = path + ".tmp"
	if _initialized:
		_discard_memory_for_path_switch()

func _discard_memory_for_path_switch() -> void:
	_initialized = false
	_profile = {}
	_persist_state = PersistState.UNINITIALIZED
	_loaded_player_data = false
	_load_origin = "uninitialized"
	_last_save_error = ""
	_pending_run = {}
	_committed_fingerprint = ""
	_last_commit_result = {}

## Explicit profile initialization. Calling it again with a different path
## reloads that path. It never copies the previous profile onto the new file.
func initialize(path: String = "") -> void:
	if path != "":
		set_save_path(path)
	if _initialized and _persist_state != PersistState.UNINITIALIZED:
		return
	load_profile()

func is_initialized() -> bool:
	return _initialized

func writes_blocked() -> bool:
	return _persist_state == PersistState.UNINITIALIZED \
		or _persist_state == PersistState.UNSUPPORTED_FUTURE \
		or _persist_state == PersistState.FAILED_QUARANTINE \
		or _persist_state == PersistState.UNREADABLE

func persistence_status() -> Dictionary:
	return {
		"state": str(PERSIST_STATE_NAMES.get(_persist_state, "unknown")),
		"writes_blocked": writes_blocked(),
		"loaded_player_data": _loaded_player_data,
		"origin": _load_origin,
		"last_save_error": _last_save_error,
		"pending_run": not _pending_run.is_empty(),
	}

func has_pending_run() -> bool:
	return not _pending_run.is_empty()
# Legacy desktop save from the Kivy predecessor (TowerDefenseKivy writes
# td_progression.json at its repo root as the desktop fallback). res://../
# is not portable, so resolve the sibling project path absolutely; on Android
# exports the file simply does not exist and file_exists() returns false.
func _legacy_desktop_save_path() -> String:
	return ProjectSettings.globalize_path("res://") + "../TowerDefenseKivy/td_progression.json"

# Transient: map id chosen on MapSelectScreen, read by GameScreen on load
var pending_map_id: int = 0
var pending_end_stats: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	initialize()

# ---------------------------------------------------------------------------
# Default profile / settings
# ---------------------------------------------------------------------------

func _default_settings() -> Dictionary:
	return {
		"gold_efficiency_enabled":   true,
		"show_upgrade_tutorial":     true,
		"fast_promotion_enabled":    false,
		"confirm_restart":           true,
		"confirm_sell":              true,
		"placement_mode":            "drag",
		"confirm_placement_enabled": false,
		"continuous_placement":      true,
		"default_speed":             1.0,
		"default_target_mode":       "first",
		"cursor_acceleration":       true,
		"cursor_sensitivity":        1.0,
		"pause_on_tower_info":       true,
		"audio_muted":               false,
		"sfx_enabled":               true,
		"sfx_volume_db":             0.0,
		"haptics_enabled":           true,
		"reduce_motion":             false,
	}

func _default_profile() -> Dictionary:
	var ttypes: Array = ["archer", "mage", "cannon", "sniper", "frost", "lightning"]
	var use_counts: Dictionary = {}
	var kill_counts: Dictionary = {}
	var active_variants: Dictionary = {}
	for t in ttypes:
		use_counts[t] = 0
		kill_counts[t] = 0
		active_variants[t] = ""
	return {
		"version":               1,
		"engine":                "godot",
		"total_rp":              0,
		"banked_rp":             0,
		"unlocked":              [],
		"unlocked_variants":     [],
		"tower_use_counts":      use_counts,
		"tower_kill_counts":     kill_counts,
		"settings":              _default_settings(),
		"active_starting_tower": "",
		"active_modifier":       "",
		"active_modifier_2":     "",
		"active_variants":       active_variants,
		"run_history":           [],
	}

# ---------------------------------------------------------------------------
# Load / save
# ---------------------------------------------------------------------------

func load_profile() -> Dictionary:
	_initialized = true
	# A crash between parking the old file and committing the temp file leaves
	# the previous profile at .bak and no live file. Put it back. An orphan
	# .tmp is never adopted.
	_restore_parked_backup_if_needed()
	var outcome := _inspect_save_file(_save_path)
	var kind: String = str(outcome.get("kind", "missing"))
	if kind == "supported":
		_profile = outcome["profile"]
		_loaded_player_data = true
		var migrated: bool = bool(outcome.get("migrated", false))
		_load_origin = "migrated" if migrated else "current"
		_persist_state = PersistState.MIGRATED if migrated else PersistState.READY
		_last_save_error = ""
		return _profile
	if kind == "future":
		push_warning("Progression save version is newer than supported %d; leaving it untouched" % SAVE_VERSION)
		_adopt_blocked_defaults("unsupported_future", PersistState.UNSUPPORTED_FUTURE)
		return _profile
	if kind == "unreadable":
		push_error("Progression save could not be read; refusing to replace it")
		_adopt_blocked_defaults("unreadable", PersistState.UNREADABLE)
		return _profile
	if kind == "corrupt":
		if _quarantine(_save_path, "corrupt"):
			_profile = _default_profile()
			_loaded_player_data = false
			_load_origin = "quarantined_corrupt"
			_persist_state = PersistState.CORRUPT
			_last_save_error = ""
			return _profile
		push_error("Progression save is corrupt and could not be quarantined; refusing to replace it")
		_adopt_blocked_defaults("failed_quarantine", PersistState.FAILED_QUARANTINE)
		return _profile

	# Nothing at the live path. A legacy desktop file may be adopted, but only
	# when this build understands it — and it is written to the Godot path,
	# never back over an unreadable sibling file.
	var legacy := _inspect_save_file(_legacy_desktop_save_path())
	if str(legacy.get("kind", "")) == "supported":
		_profile = legacy["profile"]
		_profile["engine"] = "godot"
		_loaded_player_data = true
		_load_origin = "legacy_desktop"
		_persist_state = PersistState.MIGRATED
		_last_save_error = ""
		save_profile()
		return _profile

	_profile = _default_profile()
	_loaded_player_data = false
	_load_origin = "defaults_fresh"
	_persist_state = PersistState.READY
	_last_save_error = ""
	return _profile

func _adopt_blocked_defaults(origin: String, state: int) -> void:
	_profile = _default_profile()
	_loaded_player_data = false
	_load_origin = origin
	_persist_state = state

## Classify a file without mutating it. "missing" is the only kind that means
## "there is no player data here". Every other kind is a real file that must
## not be confused with a fresh profile.
func _inspect_save_file(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {"kind": "missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"kind": "unreadable"}
	var text := f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return {"kind": "corrupt"}
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"kind": "corrupt"}
	if parsed.has("version"):
		var file_version: int = _as_int(parsed.get("version"), -1)
		if file_version < 0:
			return {"kind": "corrupt"}
		if file_version > SAVE_VERSION:
			return {"kind": "future"}
	var default := _default_profile()
	_deep_merge(default, parsed)
	_normalize_profile(default)
	default["engine"] = "godot"
	default["version"] = SAVE_VERSION
	var migrated: bool = (not parsed.has("version")) or _as_int(parsed.get("version"), 0) < SAVE_VERSION
	return {"kind": "supported", "profile": default, "migrated": migrated}

## Move a damaged save aside with a checked rename. Returns true only when the
## file really moved; a failed quarantine is reported, never treated as success.
func _quarantine(path: String, reason: String) -> bool:
	var stamp: int = int(Time.get_unix_time_from_system())
	var quarantine: String = "%s.%s-%d" % [path, reason, stamp]
	var err: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(quarantine)
	)
	if err != OK:
		push_error("Could not quarantine %s save (error %d); file left in place" % [reason, err])
		return false
	push_warning("Progression save quarantined as %s" % quarantine)
	return true

func _as_int(value, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback

func _normalize_profile(profile: Dictionary) -> void:
	for key in ["active_starting_tower", "active_modifier", "active_modifier_2"]:
		var v = profile.get(key)
		profile[key] = "" if v == null else str(v)

	# Type-validate persisted collections. A parseable save with wrong-typed
	# keys used to crash record_run() at the end of a run.
	for key in ["unlocked", "unlocked_variants"]:
		if not profile.get(key) is Array:
			profile[key] = []
		else:
			var cleaned: Array = []
			for entry in profile[key]:
				if entry is String and entry != "":
					cleaned.append(entry)
			profile[key] = cleaned
	for key in ["tower_use_counts", "tower_kill_counts", "active_variants", "settings"]:
		if not profile.get(key) is Dictionary:
			profile[key] = _default_profile()[key]
	for key in ["total_rp", "banked_rp"]:
		profile[key] = _as_int(profile.get(key), 0)

	_normalize_settings(profile["settings"])

	var default_variants: Dictionary = _default_profile()["active_variants"]
	for ttype in default_variants:
		if not ttype in profile["active_variants"] or profile["active_variants"][ttype] == null:
			profile["active_variants"][ttype] = ""
		else:
			var vkey: String = str(profile["active_variants"][ttype])
			# Drop references to variants this build does not know about.
			if vkey != "" and not _variant_exists(vkey):
				vkey = ""
			profile["active_variants"][ttype] = vkey
	for key in ["tower_use_counts", "tower_kill_counts"]:
		for ttype in default_variants:
			profile[key][ttype] = _as_int(profile[key].get(ttype), 0)

	if not profile.get("run_history") is Array:
		profile["run_history"] = []
	var clean_history: Array = []
	for entry in profile["run_history"]:
		if entry is Dictionary:
			clean_history.append(entry)
	profile["run_history"] = clean_history

	# Modifier compatibility must hold for loaded saves too, not just when the
	# player toggles them in the UI: an old/malformed file could otherwise start
	# a run with an invalid stack (e.g. Sudden Death + Glass Cannon life clash).
	if profile["active_modifier"] != "" and not profile["active_modifier"] in profile["unlocked"]:
		profile["active_modifier"] = ""
	if profile["active_modifier_2"] != "" and (
			not profile["active_modifier_2"] in profile["unlocked"]
			or profile["active_modifier_2"] == profile["active_modifier"]
			or not _modifiers_compatible(profile["active_modifier"], profile["active_modifier_2"])):
		profile["active_modifier_2"] = ""

## Validate settings values against their default types so a corrupt save cannot
## put a String into a bool setting and silently break runtime behavior.
func _normalize_settings(settings: Dictionary) -> void:
	var defaults := _default_settings()
	for key in defaults.keys():
		if not key in settings:
			settings[key] = defaults[key]
			continue
		var dflt = defaults[key]
		var value = settings[key]
		if dflt is bool and not value is bool:
			settings[key] = dflt
		elif dflt is int and not (value is int or value is float):
			settings[key] = dflt
		elif dflt is int:
			settings[key] = int(value)
		elif dflt is float and not (value is int or value is float):
			settings[key] = dflt
		elif dflt is float:
			settings[key] = float(value)
		elif dflt is String and not value is String:
			settings[key] = dflt
	# A persisted speed that this build does not offer would make speed buttons
	# disagree with the simulation; snap it to a supported value.
	var speed: float = float(settings.get("default_speed", 1.0))
	if not is_equal_approx(speed, 1.0) and not is_equal_approx(speed, 2.0) and not is_equal_approx(speed, 3.0):
		settings["default_speed"] = 1.0
	if not str(settings.get("default_target_mode", "first")) in ["first", "last", "strong", "weak", "close"]:
		settings["default_target_mode"] = "first"
	if not str(settings.get("placement_mode", "drag")) in ["drag", "tap"]:
		settings["placement_mode"] = "drag"

func _variant_exists(variant_key: String) -> bool:
	for variant in TOWER_VARIANTS:
		if variant["variant_key"] == variant_key:
			return true
	return false

## Persist the profile atomically. Returns true only when the new bytes were
## really committed to _save_path. Every failure path is reported and leaves the
## previous save intact.
func save_profile() -> bool:
	# Root-cause fix for the old "Refusing to save an uninitialized profile"
	# error: initialize on demand instead of dropping the write. Callers that
	# update a setting always get that setting persisted — unless the file on
	# disk is one this build is not allowed to replace.
	if not _initialized or _profile.is_empty() or not _profile.has("version"):
		initialize()
	if writes_blocked():
		_last_save_error = "writes_blocked:%s" % str(PERSIST_STATE_NAMES.get(_persist_state, "unknown"))
		push_error("Refusing to overwrite progression (%s)" % _last_save_error)
		return false
	if _profile.is_empty() or not _profile.has("version"):
		_last_save_error = "uninitialized"
		push_error("Cannot save progression: profile failed to initialize")
		return false

	_profile["version"] = SAVE_VERSION
	_profile["engine"] = "godot"
	if not _profile_schema_ok(_profile):
		_last_save_error = "schema_invalid"
		_persist_state = PersistState.FAILED_WRITE
		push_error("Cannot save progression: in-memory profile failed schema checks")
		return false

	var text := JSON.stringify(_profile, "\t")
	var f := FileAccess.open(_tmp_path, FileAccess.WRITE)
	if f == null:
		_last_save_error = "temp_open_failed"
		_persist_state = PersistState.FAILED_WRITE
		push_error("Cannot open progression temp file %s (error %d); save aborted"
			% [_tmp_path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.flush()
	var write_err: int = f.get_error()
	f.close()
	if write_err != OK:
		_last_save_error = "temp_write_failed"
		_persist_state = PersistState.FAILED_WRITE
		push_error("Failed writing progression temp file (error %d); save aborted" % write_err)
		_remove_if_exists(_tmp_path)
		return false

	# The temp file must round-trip as this schema, not merely as some JSON value.
	var reread := _read_text(_tmp_path)
	var parsed = JSON.parse_string(reread)
	if reread != text or not _profile_schema_ok(parsed) or not _parsed_matches_profile(parsed):
		_last_save_error = "temp_verify_failed"
		_persist_state = PersistState.FAILED_WRITE
		push_error("Progression temp file failed schema verification; previous save left intact")
		_remove_if_exists(_tmp_path)
		return false

	var err: int = _commit_temp_file()
	if err != OK:
		_last_save_error = "commit_failed:%d" % err
		_persist_state = PersistState.FAILED_WRITE
		push_error("Failed to commit progression save (error %d); previous save left intact" % err)
		_remove_if_exists(_tmp_path)
		return false
	_last_save_error = ""
	if _pending_run.is_empty():
		_persist_state = PersistState.READY
	else:
		_persist_state = PersistState.UNSAVED_CHANGES
	return true

## Replace the live file only after the temp file has been verified.
## If the platform refuses to replace an existing file, move that file aside
## and put it back when the commit itself fails.
func _commit_temp_file() -> int:
	var src := ProjectSettings.globalize_path(_tmp_path)
	var dst := ProjectSettings.globalize_path(_save_path)
	var err: int = DirAccess.rename_absolute(src, dst)
	if err == OK:
		return OK
	if not FileAccess.file_exists(_save_path):
		return err
	var bak := _save_path + ".bak"
	var bak_global := ProjectSettings.globalize_path(bak)
	var parked: int = DirAccess.rename_absolute(dst, bak_global)
	if parked != OK:
		return err
	err = DirAccess.rename_absolute(src, dst)
	if err != OK:
		DirAccess.rename_absolute(bak_global, dst)
		return err
	_remove_if_exists(bak)
	return OK

func _is_number(value) -> bool:
	return value is int or value is float

func _profile_schema_ok(parsed) -> bool:
	if not parsed is Dictionary:
		return false
	if _as_int(parsed.get("version"), -1) != SAVE_VERSION:
		return false
	if str(parsed.get("engine", "")) == "":
		return false
	if not parsed.get("unlocked") is Array:
		return false
	if not parsed.get("unlocked_variants") is Array:
		return false
	if not parsed.get("tower_use_counts") is Dictionary:
		return false
	if not parsed.get("tower_kill_counts") is Dictionary:
		return false
	if not parsed.get("active_variants") is Dictionary:
		return false
	if not parsed.get("settings") is Dictionary:
		return false
	if not parsed.get("run_history") is Array:
		return false
	if not _is_number(parsed.get("total_rp")) or not _is_number(parsed.get("banked_rp")):
		return false
	var defaults := _default_settings()
	for key in defaults.keys():
		if not parsed["settings"].has(key):
			return false
	for key in ["active_starting_tower", "active_modifier", "active_modifier_2"]:
		if not parsed.get(key) is String:
			return false
	return true

func _parsed_matches_profile(parsed: Dictionary) -> bool:
	if not is_equal_approx(float(parsed.get("banked_rp", -1)), float(_profile.get("banked_rp", -2))):
		return false
	if not is_equal_approx(float(parsed.get("total_rp", -1)), float(_profile.get("total_rp", -2))):
		return false
	var unlocked = parsed.get("unlocked", [])
	if not unlocked is Array or unlocked.size() != _profile.get("unlocked", []).size():
		return false
	var history = parsed.get("run_history", [])
	if not history is Array or history.size() != _profile.get("run_history", []).size():
		return false
	return true

## Deliberate recovery. Copies the blocked file to a verified backup, then
## writes a fresh profile. Refuses if the original bytes cannot be preserved.
func recover_blocked_profile() -> Dictionary:
	if not writes_blocked() or _persist_state == PersistState.UNINITIALIZED:
		return {
			"success": false,
			"reason": "recovery_not_required",
			"state": persistence_status()["state"],
		}
	var backup_path := ""
	if FileAccess.file_exists(_save_path):
		var probe := FileAccess.open(_save_path, FileAccess.READ)
		if probe == null:
			return {"success": false, "reason": "cannot_preserve_original", "backup": ""}
		var original: PackedByteArray = probe.get_buffer(probe.get_length())
		probe.close()
		var stamp: int = int(Time.get_unix_time_from_system())
		backup_path = "%s.recovery-%d" % [_save_path, stamp]
		var out := FileAccess.open(backup_path, FileAccess.WRITE)
		if out == null:
			return {"success": false, "reason": "backup_failed", "backup": ""}
		out.store_buffer(original)
		out.flush()
		out.close()
		var check_f := FileAccess.open(backup_path, FileAccess.READ)
		if check_f == null:
			_remove_if_exists(backup_path)
			return {"success": false, "reason": "backup_unreadable", "backup": ""}
		var check: PackedByteArray = check_f.get_buffer(check_f.get_length())
		check_f.close()
		if check != original:
			_remove_if_exists(backup_path)
			return {"success": false, "reason": "backup_mismatch", "backup": ""}
	_profile = _default_profile()
	_loaded_player_data = false
	_load_origin = "recovered_defaults"
	_persist_state = PersistState.READY
	_initialized = true
	_last_save_error = ""
	if not save_profile():
		return {"success": false, "reason": "save_failed", "backup": backup_path}
	return {"success": true, "reason": "", "backup": backup_path, "state": "ready"}

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _restore_parked_backup_if_needed() -> void:
	if FileAccess.file_exists(_save_path):
		return
	var bak := _save_path + ".bak"
	if not FileAccess.file_exists(bak):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(bak),
		ProjectSettings.globalize_path(_save_path)
	)

func _deep_merge(base: Dictionary, override: Dictionary) -> void:
	for key in override:
		if key in base and base[key] is Dictionary and override[key] is Dictionary:
			_deep_merge(base[key], override[key])
		else:
			base[key] = override[key]

# ---------------------------------------------------------------------------
# RP calculation  (mirrors compute_rp in progression.py)
# ---------------------------------------------------------------------------

func compute_rp(waves_survived: int, perfect_waves: int, lives_remaining: int,
				gold_earned: int, gold_spent: int,
				gold_efficiency_enabled: bool = true) -> int:
	var rp: int = (waves_survived * 8) + (perfect_waves * 7) + (lives_remaining * 5)
	if gold_efficiency_enabled and gold_earned > 0:
		var bonus: int = int(float(gold_spent) / float(gold_earned) * 20.0)
		rp += clampi(bonus, 0, 20)
	return rp

# ---------------------------------------------------------------------------
# End-of-run record  (mirrors record_run in progression.py)
# ---------------------------------------------------------------------------

func _run_fingerprint(gs: Object, map_id: int, abandoned: bool) -> String:
	return "%d|%d|%d|%d|%d|%s" % [
		map_id,
		int(gs.stat_waves_survived),
		int(gs.stat_enemies_killed),
		int(gs.stat_gold_earned),
		int(gs.lives),
		"1" if abandoned else "0",
	]

func record_run(gs: Object, map_id: int, abandoned: bool = false) -> Dictionary:
	if _profile.is_empty() or not _initialized:
		initialize()
	var fingerprint := _run_fingerprint(gs, map_id, abandoned)
	if fingerprint == _committed_fingerprint and not _last_commit_result.is_empty():
		var dup: Dictionary = _last_commit_result.duplicate(true)
		dup["duplicate"] = true
		dup["persisted"] = true
		dup["save_failed"] = false
		return dup
	if not _pending_run.is_empty():
		if str(_pending_run.get("fingerprint", "")) == fingerprint:
			var again: Dictionary = (_pending_run["result"] as Dictionary).duplicate(true)
			again["duplicate"] = true
			return again
		return {
			"rp": 0,
			"newly_unlocked_variants": [],
			"milestone_deltas": [],
			"save_failed": true,
			"persisted": false,
			"duplicate": false,
			"reason": "unsaved_run_pending",
		}
	var settings: Dictionary = get_settings()
	var gold_eff_on: bool = settings.get("gold_efficiency_enabled", true)
	var gold_spent: int = maxi(0, gs.stat_gold_earned - gs.gold)

	var rp: int = compute_rp(
		gs.stat_waves_survived,
		gs.stat_perfect_waves,
		maxi(0, gs.lives),
		gs.stat_gold_earned,
		gold_spent,
		gold_eff_on
	)
	rp = int(round(float(rp) * gs._rp_mult)) if gs.game_state == "won" else rp

	_profile["total_rp"]  += rp
	_profile["banked_rp"] += rp

	# Snapshot pre-update counts for delta calculation
	var pre_use: Dictionary = {}
	var pre_kill: Dictionary = {}
	for ttype in _profile["tower_use_counts"]:
		pre_use[ttype]  = _profile["tower_use_counts"].get(ttype, 0)
		pre_kill[ttype] = _profile["tower_kill_counts"].get(ttype, 0)
	var prev_unlocked_v: Array = _profile["unlocked_variants"].duplicate()
	var prev_total_rp: int = _profile["total_rp"] - rp
	var prev_banked_rp: int = _profile["banked_rp"] - rp
	var prev_history: Array = _profile["run_history"].duplicate(true)

	for ttype in gs.stat_tower_use_by_type:
		_profile["tower_use_counts"][ttype] = \
			_profile["tower_use_counts"].get(ttype, 0) + gs.stat_tower_use_by_type[ttype]
	for ttype in gs.stat_tower_kills_by_type:
		_profile["tower_kill_counts"][ttype] = \
			_profile["tower_kill_counts"].get(ttype, 0) + gs.stat_tower_kills_by_type[ttype]

	var entry: Dictionary = {
		"map_id":      map_id,
		"waves":       gs.stat_waves_survived,
		"perfect":     gs.stat_perfect_waves,
		"lives":       gs.lives,
		"gold_earned": gs.stat_gold_earned,
		"gold_spent":  gold_spent,
		"rp_earned":   rp,
		"won":         gs.game_state == "won",
		"abandoned":   abandoned,
	}
	_profile["run_history"].append(entry)
	if _profile["run_history"].size() > 50:
		_profile["run_history"] = _profile["run_history"].slice(-50)

	_check_milestone_unlocks()
	var saved: bool = save_profile()
	if not saved:
		# Report the truth: this run's progress is not durable. Roll the
		# in-memory counters back so a later successful save cannot bank a run
		# whose record already failed. The snapshot stays available for retry.
		_profile["total_rp"]  = prev_total_rp
		_profile["banked_rp"] = prev_banked_rp
		_profile["run_history"] = prev_history
		_profile["unlocked_variants"] = prev_unlocked_v
		for ttype in pre_use:
			_profile["tower_use_counts"][ttype] = pre_use[ttype]
			_profile["tower_kill_counts"][ttype] = pre_kill[ttype]
		var failed := {
			"rp":                     rp,
			"newly_unlocked_variants": [],
			"milestone_deltas":       [],
			"save_failed":            true,
			"persisted":              false,
			"duplicate":              false,
			"reason":                 _last_save_error,
		}
		_pending_run = {
			"fingerprint": fingerprint,
			"rp": rp,
			"entry": entry.duplicate(true),
			"use_adds": gs.stat_tower_use_by_type.duplicate(),
			"kill_adds": gs.stat_tower_kills_by_type.duplicate(),
			"result": failed.duplicate(true),
		}
		if not writes_blocked():
			_persist_state = PersistState.UNSAVED_CHANGES
		return failed

	# Build milestone delta info for the end screen
	var newly_unlocked: Array = []
	var milestone_deltas: Array = []
	var used_types: Array = []
	for ttype in gs.stat_tower_use_by_type:
		if gs.stat_tower_use_by_type[ttype] > 0 or gs.stat_tower_kills_by_type.get(ttype, 0) > 0:
			used_types.append(ttype)

	for variant in TOWER_VARIANTS:
		var key: String    = variant["variant_key"]
		var ttype: String  = variant["tower_type"]
		if not ttype in used_types:
			continue
		if key in _profile["unlocked_variants"] and not key in prev_unlocked_v:
			newly_unlocked.append(variant["label"])
		elif not key in _profile["unlocked_variants"]:
			var run_uses: int  = gs.stat_tower_use_by_type.get(ttype, 0)
			var run_kills: int = gs.stat_tower_kills_by_type.get(ttype, 0)
			if run_uses > 0 or run_kills > 0:
				milestone_deltas.append({
					"label":      variant["label"],
					"uses_now":   _profile["tower_use_counts"].get(ttype, 0),
					"uses_max":   variant["use_threshold"],
					"kills_now":  _profile["tower_kill_counts"].get(ttype, 0),
					"kills_max":  variant["kill_threshold"],
					"run_uses":   run_uses,
					"run_kills":  run_kills,
				})

	var committed := {
		"rp":                     rp,
		"newly_unlocked_variants": newly_unlocked,
		"milestone_deltas":       milestone_deltas,
		"save_failed":            false,
		"persisted":              true,
		"duplicate":              false,
	}
	_committed_fingerprint = fingerprint
	_last_commit_result = committed.duplicate(true)
	_pending_run = {}
	return committed

## Re-apply the one unsaved run and commit it. A second call after success
## does not award the run again.
func retry_pending_run() -> Dictionary:
	if _pending_run.is_empty():
		if not _last_commit_result.is_empty():
			var already: Dictionary = _last_commit_result.duplicate(true)
			already["duplicate"] = true
			already["persisted"] = true
			already["save_failed"] = false
			return already
		return {
			"success": false,
			"reason": "nothing_pending",
			"save_failed": false,
			"persisted": false,
			"duplicate": false,
			"rp": 0,
		}
	if writes_blocked():
		var blocked: Dictionary = (_pending_run["result"] as Dictionary).duplicate(true)
		blocked["save_failed"] = true
		blocked["persisted"] = false
		return blocked
	var snap: Dictionary = _pending_run
	var prev_total: int = int(_profile.get("total_rp", 0))
	var prev_banked: int = int(_profile.get("banked_rp", 0))
	var prev_history: Array = _profile.get("run_history", []).duplicate(true)
	var prev_unlocked: Array = _profile.get("unlocked_variants", []).duplicate()
	var prev_use: Dictionary = _profile.get("tower_use_counts", {}).duplicate()
	var prev_kill: Dictionary = _profile.get("tower_kill_counts", {}).duplicate()
	_profile["total_rp"] = prev_total + int(snap.get("rp", 0))
	_profile["banked_rp"] = prev_banked + int(snap.get("rp", 0))
	for ttype in snap.get("use_adds", {}):
		_profile["tower_use_counts"][ttype] = int(_profile["tower_use_counts"].get(ttype, 0)) + int(snap["use_adds"][ttype])
	for ttype in snap.get("kill_adds", {}):
		_profile["tower_kill_counts"][ttype] = int(_profile["tower_kill_counts"].get(ttype, 0)) + int(snap["kill_adds"][ttype])
	_profile["run_history"].append((snap["entry"] as Dictionary).duplicate(true))
	if _profile["run_history"].size() > 50:
		_profile["run_history"] = _profile["run_history"].slice(-50)
	_check_milestone_unlocks()
	if not save_profile():
		_profile["total_rp"] = prev_total
		_profile["banked_rp"] = prev_banked
		_profile["run_history"] = prev_history
		_profile["unlocked_variants"] = prev_unlocked
		_profile["tower_use_counts"] = prev_use
		_profile["tower_kill_counts"] = prev_kill
		var failed: Dictionary = (snap["result"] as Dictionary).duplicate(true)
		failed["save_failed"] = true
		failed["persisted"] = false
		failed["reason"] = _last_save_error
		_pending_run["result"] = failed
		_persist_state = PersistState.UNSAVED_CHANGES
		return failed
	var ok: Dictionary = (snap["result"] as Dictionary).duplicate(true)
	ok["save_failed"] = false
	ok["persisted"] = true
	ok["duplicate"] = false
	ok["reason"] = ""
	_committed_fingerprint = str(snap.get("fingerprint", ""))
	_last_commit_result = ok.duplicate(true)
	_pending_run = {}
	_persist_state = PersistState.READY
	return ok

func _check_milestone_unlocks() -> void:
	for variant in TOWER_VARIANTS:
		var key: String = variant["variant_key"]
		if key in _profile["unlocked_variants"]:
			continue
		var ttype: String = variant["tower_type"]
		var uses: int  = _profile["tower_use_counts"].get(ttype, 0)
		var kills: int = _profile["tower_kill_counts"].get(ttype, 0)
		if uses >= variant["use_threshold"] and kills >= variant["kill_threshold"]:
			_profile["unlocked_variants"].append(key)

# ---------------------------------------------------------------------------
# Shop actions
# ---------------------------------------------------------------------------

func purchase_upgrade(unlock_id: String) -> Dictionary:
	if unlock_id in _profile["unlocked"]:
		return {"success": false, "reason": "already_owned", "banked_rp": _profile["banked_rp"]}

	var cost: int = _find_upgrade_cost(unlock_id)
	if cost < 0:
		return {"success": false, "reason": "unknown_upgrade", "banked_rp": _profile["banked_rp"]}

	# Enforce chain order for starting towers
	if unlock_id.begins_with("start_"):
		var chain_ids: Array = []
		for entry in STARTING_TOWER_CHAIN:
			chain_ids.append(entry[0])
		var idx: int = chain_ids.find(unlock_id)
		if idx > 0:
			var prev: String = chain_ids[idx - 1]
			if not prev in _profile["unlocked"]:
				return {"success": false, "reason": "prerequisite_missing", "banked_rp": _profile["banked_rp"]}

	if _profile["banked_rp"] < cost:
		return {"success": false, "reason": "not_enough_rp", "banked_rp": _profile["banked_rp"]}

	var prev_rp: int = _profile["banked_rp"]
	_profile["banked_rp"] -= cost
	_profile["unlocked"].append(unlock_id)
	if not save_profile():
		# Never leave a purchase applied in memory when it did not persist.
		_profile["banked_rp"] = prev_rp
		_profile["unlocked"].erase(unlock_id)
		return {"success": false, "reason": "save_failed", "banked_rp": _profile["banked_rp"]}
	return {"success": true, "banked_rp": _profile["banked_rp"]}

func _find_upgrade_cost(unlock_id: String) -> int:
	for entry in STARTING_TOWER_CHAIN:
		if entry[0] == unlock_id:
			return entry[1]
	for entry in MAP_MODIFIERS:
		if entry[0] == unlock_id:
			return entry[1]
	for entry in CONVENIENCE_UPGRADES:
		if entry[0] == unlock_id:
			return entry[1]
	return -1

func set_active_starting_tower(unlock_id: String) -> void:
	if unlock_id != "" and not unlock_id in _profile["unlocked"]:
		return
	var prev = _profile["active_starting_tower"]
	_profile["active_starting_tower"] = unlock_id
	if not save_profile():
		_profile["active_starting_tower"] = prev

func get_active_modifier() -> String:
	return _profile.get("active_modifier", "")

func set_active_modifier(mod_id: String) -> void:
	if mod_id != "" and not mod_id in _profile["unlocked"]:
		return
	var prev = _profile["active_modifier"]
	var prev_2 = _profile.get("active_modifier_2", "")
	_profile["active_modifier"] = mod_id
	# Clear modifier_2 if it's now incompatible with the new primary
	if not _modifiers_compatible(_profile["active_modifier"], _profile.get("active_modifier_2", "")):
		_profile["active_modifier_2"] = ""
	if not save_profile():
		_profile["active_modifier"] = prev
		_profile["active_modifier_2"] = prev_2

func set_active_modifier_2(mod_id: String) -> void:
	if mod_id != "" and not mod_id in _profile["unlocked"]:
		return
	var mod1: String = _profile.get("active_modifier", "")
	if mod_id != "" and not _modifiers_compatible(mod1, mod_id):
		return  # incompatible pair — silently reject
	var prev = _profile.get("active_modifier_2", "")
	_profile["active_modifier_2"] = mod_id
	if not save_profile():
		_profile["active_modifier_2"] = prev

func get_active_modifier_2() -> String:
	return _profile.get("active_modifier_2", "")

func get_active_modifier_ids() -> Array:
	var ids: Array = []
	var m1: String = _profile.get("active_modifier", "")
	var m2: String = _profile.get("active_modifier_2", "")
	if m1 != "":
		ids.append(m1)
	if m2 != "" and m2 != m1:
		ids.append(m2)
	return ids

func get_compatible_second_modifiers(mod1_id: String) -> Array:
	var result: Array = []
	var unlocked: Array = _profile.get("unlocked", [])
	for entry in MAP_MODIFIERS:
		var mid: String = entry[0]
		if mid == mod1_id:
			continue
		if mid not in unlocked:
			continue
		if _modifiers_compatible(mod1_id, mid):
			result.append(entry)
	return result

func _modifiers_compatible(mod_a: String, mod_b: String) -> bool:
	if mod_a == "" or mod_b == "":
		return true
	for pair in MODIFIER_INCOMPATIBLE:
		if (pair[0] == mod_a and pair[1] == mod_b) or (pair[0] == mod_b and pair[1] == mod_a):
			return false
	return true

func set_active_variant(tower_type: String, variant_key: String) -> void:
	if variant_key != "" and not variant_key in _profile["unlocked_variants"]:
		return
	var prev = _profile["active_variants"].get(tower_type, "")
	_profile["active_variants"][tower_type] = variant_key
	if not save_profile():
		_profile["active_variants"][tower_type] = prev

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func get_settings() -> Dictionary:
	var defaults := _default_settings()
	var merged := defaults.duplicate()
	var saved: Dictionary = _profile.get("settings", {})
	for k in saved:
		merged[k] = saved[k]
	return merged

func set_setting(key: String, value) -> bool:
	var defaults := _default_settings()
	if not key in defaults:
		return false
	if not "settings" in _profile:
		_profile["settings"] = {}
	var had_prev: bool = _profile["settings"].has(key)
	var prev = _profile["settings"].get(key)
	_profile["settings"][key] = value
	if not save_profile():
		# A setting that did not persist must not look applied in memory.
		if had_prev:
			_profile["settings"][key] = prev
		else:
			_profile["settings"].erase(key)
		return false
	return true

func reset_settings() -> void:
	var prev: Dictionary = _profile.get("settings", {}).duplicate(true)
	_profile["settings"] = _default_settings()
	if not save_profile():
		_profile["settings"] = prev

# ---------------------------------------------------------------------------
# Run-start config  (mirrors get_run_config in progression.py)
# ---------------------------------------------------------------------------

func get_run_config() -> Dictionary:
	var unlocked: Array = _profile.get("unlocked", [])
	var cfg: Dictionary = {
		"starting_tower_type":     "",
		"extra_gold":              0,
		"extra_lives":             0,
		"modifier_id":             "",
		"speed_mult_enemies":      1.0,
		"hp_mult_enemies":         1.0,
		"kill_reward_mult":        1.0,
		"wave_bonus_mult":         1.0,
		"sell_disabled":           false,
		"rp_mult":                 1.0,
		"starting_lives_override": -1,   # -1 = not overridden
		"disabled_towers":         [],
		"tower_damage_mults":      {},
		"tower_range_mults":       {},
		"tower_cooldown_mults":    {},
		"tower_splash_mults":      {},
		"default_speed":           float(get_settings().get("default_speed", 1.0)),
		"default_target_mode":     str(get_settings().get("default_target_mode", "first")),
	}

	# Starting tower
	var st: String = _profile.get("active_starting_tower", "")
	if st != "" and st in unlocked:
		for entry in STARTING_TOWER_CHAIN:
			if entry[0] == st:
				cfg["starting_tower_type"] = entry[2]
				break

	# Convenience bonuses (only highest tier applies)
	if "bonus_gold_25" in unlocked:
		cfg["extra_gold"] = 25
	elif "bonus_gold_10" in unlocked:
		cfg["extra_gold"] = 10

	if "bonus_life_2" in unlocked:
		cfg["extra_lives"] = 2
	elif "bonus_life_1" in unlocked:
		cfg["extra_lives"] = 1

	# Active modifiers (primary + optional stack)
	var active_mods: Array = []
	var mod1: String = _profile.get("active_modifier", "")
	var mod2: String = _profile.get("active_modifier_2", "")
	if mod1 != "" and mod1 in unlocked:
		active_mods.append(mod1)
	if mod2 != "" and mod2 in unlocked and mod2 != mod1:
		active_mods.append(mod2)

	cfg["modifier_id"] = active_mods[0] if not active_mods.is_empty() else ""
	# Full modifier list: GameState needs all of them (not just the primary) to
	# filter wave-shop offers and validate rules like Sudden Death.
	cfg["modifier_ids"] = active_mods.duplicate()

	for mod in active_mods:
		_apply_modifier_to_config(mod, cfg)

	# Stacking RP formula: max(A_mult, B_mult) + 0.5 per extra modifier
	if active_mods.size() >= 2:
		var m_a: float = MODIFIER_RP_MULT.get(active_mods[0], 1.0)
		var m_b: float = MODIFIER_RP_MULT.get(active_mods[1], 1.0)
		cfg["rp_mult"] = maxf(m_a, m_b) + 0.5
	elif active_mods.size() == 1:
		cfg["rp_mult"] = MODIFIER_RP_MULT.get(active_mods[0], 1.0)

	return cfg

func _apply_modifier_to_config(mod: String, cfg: Dictionary) -> void:
	if mod == "mod_iron_economy":
		cfg["extra_gold"]      -= 50
		cfg["kill_reward_mult"] = maxf(cfg["kill_reward_mult"], 1.15)
		cfg["sell_disabled"]    = true
	elif mod == "mod_glass_cannon":
		if cfg["starting_lives_override"] < 0 or cfg["starting_lives_override"] > 5:
			cfg["starting_lives_override"] = 5
		cfg["wave_bonus_mult"] = maxf(cfg["wave_bonus_mult"], 1.30)
		var dmg_mults: Dictionary = cfg.get("tower_damage_mults", {})
		dmg_mults["archer"]  = maxf(dmg_mults.get("archer", 1.0), 1.18)
		dmg_mults["sniper"]  = maxf(dmg_mults.get("sniper", 1.0), 1.18)
		cfg["tower_damage_mults"] = dmg_mults
	elif mod == "mod_blitz":
		cfg["speed_mult_enemies"] = maxf(cfg["speed_mult_enemies"], 1.25)
		cfg["kill_reward_mult"]   = maxf(cfg["kill_reward_mult"], 1.20)
		if "frost" not in cfg["disabled_towers"]:
			cfg["disabled_towers"].append("frost")
		var dmg_mults: Dictionary = cfg.get("tower_damage_mults", {})
		dmg_mults["lightning"] = maxf(dmg_mults.get("lightning", 1.0), 1.35)
		cfg["tower_damage_mults"] = dmg_mults
	elif mod == "mod_hardened":
		cfg["hp_mult_enemies"]  = maxf(cfg["hp_mult_enemies"], 1.40)
		cfg["wave_bonus_mult"]  = maxf(cfg["wave_bonus_mult"], 2.0)
		if "archer" not in cfg["disabled_towers"]:
			cfg["disabled_towers"].append("archer")
		var splash_mults: Dictionary = cfg.get("tower_splash_mults", {})
		splash_mults["cannon"] = maxf(splash_mults.get("cannon", 1.0), 1.25)
		splash_mults["mage"]   = maxf(splash_mults.get("mage", 1.0), 1.20)
		cfg["tower_splash_mults"] = splash_mults
	elif mod == "mod_sudden_death":
		cfg["starting_lives_override"] = 1
		cfg["sell_disabled"]           = true

# ---------------------------------------------------------------------------
# Variant lookup  (mirrors get_variant_for_type in progression.py)
# ---------------------------------------------------------------------------

func get_variant_for_type(tower_type: String) -> Dictionary:
	var vkey: String = _profile["active_variants"].get(tower_type, "")
	if vkey == "":
		return {}
	for v in TOWER_VARIANTS:
		if v["variant_key"] == vkey and vkey in _profile["unlocked_variants"]:
			return v
	return {}

# ---------------------------------------------------------------------------
# Profile accessors for UI
# ---------------------------------------------------------------------------

func get_profile() -> Dictionary:
	return _profile

func get_banked_rp() -> int:
	return _profile.get("banked_rp", 0)

func get_total_rp() -> int:
	return _profile.get("total_rp", 0)

func is_unlocked(unlock_id: String) -> bool:
	return unlock_id in _profile.get("unlocked", [])

func is_variant_unlocked(variant_key: String) -> bool:
	return variant_key in _profile.get("unlocked_variants", [])

func just_won() -> bool:
	var history: Array = _profile.get("run_history", [])
	if history.is_empty():
		return false
	return history[-1].get("won", false)
