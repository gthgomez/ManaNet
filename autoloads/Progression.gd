extends Node

# Port of progression.py — persistent meta-progression singleton.
# Loaded as autoload "Progression" in project.godot.
#
# Save file: user://td_progression.json
# Atomic write: user://td_progression.tmp → rename

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
	 "Start with -50 gold, cannot sell towers, but earn +15% per kill"],
	["mod_glass_cannon",  80, "Glass Cannon",
	 "Start with 5 lives; Archer and Sniper gain +18% damage; waves give +30% gold bonus"],
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
]

const CONVENIENCE_UPGRADES: Array = [
	# [id, cost, label, desc]
	["bonus_gold_10",  30, "+10 Starting Gold",  "Each run begins with 10 extra gold"],
	["bonus_gold_25",  80, "+25 Starting Gold",  "Each run begins with 25 extra gold (replaces +10)"],
	["bonus_life_1",   50, "+1 Starting Life",   "Each run begins with 11 lives"],
	["bonus_life_2",  110, "+2 Starting Lives",  "Each run begins with 12 lives (replaces +1)"],
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
		"desc":           "Deeper cold. Chill duration +20%, +8% damage. Costs 10 more gold.",
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
		"desc":           "Ancient runes amplify spells. +12% damage, chain jumps +1. Costs 15 more.",
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
		"desc":           "Upgraded barrel. +15% splash radius, +8% damage. Costs 20 more.",
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
		"desc":           "Extended barrel. +20% range, +5% damage. Costs 15 more.",
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
		"desc":           "Souped-up coils. -10% cooldown, +8% damage. Costs 15 more.",
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

var _profile: Dictionary = {}
const _SAVE_PATH: String = "user://td_progression.json"
const _TMP_PATH:  String = "user://td_progression.tmp"
const _LEGACY_DESKTOP_SAVE: String = "res://../td_v712/td_progression.json"

# Transient: map id chosen on MapSelectScreen, read by GameScreen on load
var pending_map_id: int = 0
var pending_end_stats: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	load_profile()

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
	var loaded := _read_profile_file(_SAVE_PATH)
	if not loaded.is_empty():
		_profile = loaded
		return _profile

	var migrated := _read_profile_file(_LEGACY_DESKTOP_SAVE)
	if not migrated.is_empty():
		_profile = migrated
		_profile["engine"] = "godot"
		save_profile()
		return _profile

	_profile = _default_profile()
	return _profile

func _read_profile_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var default := _default_profile()
	_deep_merge(default, parsed)
	_normalize_profile(default)
	default["engine"] = "godot"
	return default

func save_profile() -> void:
	if _profile.is_empty():
		return
	var text := JSON.stringify(_profile, "\t")
	var f := FileAccess.open(_TMP_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(_TMP_PATH),
			ProjectSettings.globalize_path(_SAVE_PATH)
		)

func _deep_merge(base: Dictionary, override: Dictionary) -> void:
	for key in override:
		if key in base and base[key] is Dictionary and override[key] is Dictionary:
			_deep_merge(base[key], override[key])
		else:
			base[key] = override[key]

func _normalize_profile(profile: Dictionary) -> void:
	if profile.get("active_starting_tower") == null:
		profile["active_starting_tower"] = ""
	if profile.get("active_modifier") == null:
		profile["active_modifier"] = ""
	if profile.get("active_modifier_2") == null:
		profile["active_modifier_2"] = ""

	if not profile.get("active_variants", {}) is Dictionary:
		profile["active_variants"] = _default_profile()["active_variants"]
	var default_variants: Dictionary = _default_profile()["active_variants"]
	for ttype in default_variants:
		if not ttype in profile["active_variants"] or profile["active_variants"][ttype] == null:
			profile["active_variants"][ttype] = ""

# ---------------------------------------------------------------------------
# RP calculation  (mirrors compute_rp in progression.py)
# ---------------------------------------------------------------------------

func compute_rp(waves_survived: int, perfect_waves: int, lives_remaining: int,
				gold_earned: int, gold_spent: int,
				gold_efficiency_enabled: bool = true) -> int:
	var rp: int = (waves_survived * 8) + (perfect_waves * 7) + (lives_remaining * 5)
	if gold_efficiency_enabled and gold_earned > 0:
		var bonus: int = int(float(gold_spent) / float(gold_earned) * 20.0)
		rp += clampi(bonus, 0, 40)
	return rp

# ---------------------------------------------------------------------------
# End-of-run record  (mirrors record_run in progression.py)
# ---------------------------------------------------------------------------

func record_run(gs: Object, map_id: int) -> Dictionary:
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
	rp = int(round(float(rp) * gs._rp_mult))

	_profile["total_rp"]  += rp
	_profile["banked_rp"] += rp

	# Snapshot pre-update counts for delta calculation
	var pre_use: Dictionary = {}
	var pre_kill: Dictionary = {}
	for ttype in _profile["tower_use_counts"]:
		pre_use[ttype]  = _profile["tower_use_counts"].get(ttype, 0)
		pre_kill[ttype] = _profile["tower_kill_counts"].get(ttype, 0)
	var prev_unlocked_v: Array = _profile["unlocked_variants"].duplicate()

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
	}
	_profile["run_history"].append(entry)
	if _profile["run_history"].size() > 50:
		_profile["run_history"] = _profile["run_history"].slice(-50)

	_check_milestone_unlocks()
	save_profile()

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

	return {
		"rp":                     rp,
		"newly_unlocked_variants": newly_unlocked,
		"milestone_deltas":       milestone_deltas,
	}

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

	_profile["banked_rp"] -= cost
	_profile["unlocked"].append(unlock_id)
	save_profile()
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
	_profile["active_starting_tower"] = unlock_id
	save_profile()

func get_active_modifier() -> String:
	return _profile.get("active_modifier", "")

func set_active_modifier(mod_id: String) -> void:
	if mod_id != "" and not mod_id in _profile["unlocked"]:
		return
	_profile["active_modifier"] = mod_id
	# Clear modifier_2 if it's now incompatible with the new primary
	if not _modifiers_compatible(_profile["active_modifier"], _profile.get("active_modifier_2", "")):
		_profile["active_modifier_2"] = ""
	save_profile()

func set_active_modifier_2(mod_id: String) -> void:
	if mod_id != "" and not mod_id in _profile["unlocked"]:
		return
	var mod1: String = _profile.get("active_modifier", "")
	if mod_id != "" and not _modifiers_compatible(mod1, mod_id):
		return  # incompatible pair — silently reject
	_profile["active_modifier_2"] = mod_id
	save_profile()

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
	_profile["active_variants"][tower_type] = variant_key
	save_profile()

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
	_profile["settings"][key] = value
	save_profile()
	return true

func reset_settings() -> void:
	_profile["settings"] = _default_settings()
	save_profile()

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
