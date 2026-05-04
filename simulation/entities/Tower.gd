class_name Tower

# Port of Tower class from core.py (lines 433-679).
# Plain GDScript class — no Node. GameState owns an Array[Tower].

const _TT := preload("res://data/tower_types.gd")
const _UP := preload("res://data/upgrade_paths.gd")
const _MAPS := preload("res://data/maps.gd")

var id: int
var ttype: String
var tower_name: String
var pos: Vector2
var color: Color
var dominant_path_tint: Color = Color(0,0,0,0)
var base_cost: int
var base_range: float
var base_damage: float
var base_cooldown: int
var last_shot_ms: int
var level: int
var target_mode: String
var radius: int
var flash_until: int
var burst_until: int
var muzzle_flash_until: int
var tracker: UpgradePathTracker
var path_multipliers: Dictionary    # {"Top": 1.0, ...} — not used in damage calc directly
var spent_gold: int
var damage_mult_bonus: float = 1.0
var range_mult_bonus: float = 1.0
var cooldown_mult_bonus: float = 1.0
var splash_mult_bonus: float = 1.0
var chain_bonus_flat: int = 0
var chill_mult_bonus: float = 1.0
var perm_cd_mult: float = 1.0       # permanent fire-rate bonus (adrenaline)
var perm_range_mult: float = 1.0    # permanent range bonus (targeting matrix)
var variant_key: String = ""
var variant_label: String = ""
var variant_badge: String = ""
var variant_tint: Color = Color(0, 0, 0, 0)
var last_target_id: int = -1
var last_target_ref: Object = null
var target_hit_count: int = 0
var volley_counter: int = 0   # Veteran Archer — tracks shots for every-5th volley

# Back-reference set by GameState after construction so shoot() can call add_effect/apply_hit
var game_state: Object = null

func _init(p_pos: Vector2, p_ttype: String, p_id: int) -> void:
	var base: Dictionary = _TT.TOWER_TYPES[p_ttype]
	id = p_id
	ttype = p_ttype
	tower_name = base["name"]
	pos = p_pos
	color = base["color"]
	base_cost = base["cost"]
	base_range = float(base["range"])
	base_damage = float(base["damage"])
	base_cooldown = int(base["cooldown"])
	last_shot_ms = -999999
	level = 1
	target_mode = "first"
	radius = _MAPS.TOWER_RADIUS
	flash_until = 0
	burst_until = 0
	tracker = UpgradePathTracker.new()
	path_multipliers = {"Top": 1.0, "Middle": 1.0, "Bottom": 1.0}
	spent_gold = base_cost
	damage_mult_bonus = 1.0
	range_mult_bonus = 1.0
	cooldown_mult_bonus = 1.0
	splash_mult_bonus = 1.0
	chain_bonus_flat = 0
	chill_mult_bonus = 1.0
	perm_cd_mult = 1.0
	perm_range_mult = 1.0
	variant_key = ""
	variant_label = ""
	variant_badge = ""
	variant_tint = Color(0, 0, 0, 0)

# ---------------------------------------------------------------------------
# Cost helpers
# ---------------------------------------------------------------------------

func base_upgrade_cost() -> int:
	if level >= 5:
		return -1
	return _TT.BASE_LEVEL_COSTS[level - 1]

func path_upgrade_cost(path: String) -> int:
	return _TT.PATH_UPGRADE_COSTS[tracker.path_levels[path]]

# ---------------------------------------------------------------------------
# Stat computations
# ---------------------------------------------------------------------------

func effective_range() -> float:
	var bonus: float = 1.0 + 0.08 * float(level - 1)
	if ttype == "sniper" and tracker.path_levels["Middle"] > 0:
		bonus += 0.04 * float(tracker.path_levels["Middle"])
	if ttype == "lightning" and tracker.path_levels["Top"] > 0:
		bonus += 0.02 * float(tracker.path_levels["Top"])
	return base_range * bonus * range_mult_bonus * perm_range_mult

func effective_cooldown() -> int:
	var cd: float = float(base_cooldown) * pow(0.92, float(level - 1))
	if ttype == "cannon" and tracker.path_levels["Middle"] > 0:
		cd *= maxf(0.55, 1.0 - 0.09 * float(tracker.path_levels["Middle"]))
	if ttype == "archer" and tracker.path_levels["Middle"] > 0:
		cd *= maxf(0.62, 1.0 - 0.08 * float(tracker.path_levels["Middle"]))
	if ttype == "lightning" and tracker.path_levels["Middle"] > 0:
		cd *= maxf(0.58, 1.0 - 0.07 * float(tracker.path_levels["Middle"]))
	cd *= cooldown_mult_bonus * perm_cd_mult
	return maxi(180, int(cd))

func get_effective_damage(now_ms: int) -> int:
	var path_mult: float = 1.0
	for path in _MAPS.PATH_KEYS:
		var lvl: int = tracker.path_levels[path]
		if lvl > 0:
			var tier_mult: float = _UP.get_path_data(ttype, path)["tiers"][lvl - 1]
			path_mult *= tier_mult
	var dmg: float = base_damage * pow(1.15, float(level - 1)) * path_mult * damage_mult_bonus
	
	# Unique Path Kinks (Identity bonuses)
	var dominant := tracker.get_dominant_path()
	if ttype == "archer" and dominant == "Bottom":
		dmg *= 1.25 # Hunter focuses for +25% Power
	elif ttype == "mage" and dominant == "Top":
		dmg *= 1.15 # Arcane Master bonus
	elif ttype == "sniper" and dominant == "Top":
		dmg *= 1.20 # Assassin Precision
		
	if now_ms < burst_until:
		dmg *= 1.25
	
	if ttype == "lightning" and tracker.path_levels["Top"] > 0:
		dmg *= voltage_multiplier()
		
	return maxi(1, int(round(dmg)))

func get_dominant_path_tint() -> Color:
	var path := tracker.get_dominant_path()
	match path:
		"Top":    return Color(0.18, 0.69, 1.0, 0.4) # Cyan (Arcane/Marksman)
		"Middle": return Color(0.2, 0.9, 0.4, 0.4)  # Emerald (Ranger/Frost)
		"Bottom": return Color(1.0, 0.6, 0.1, 0.4)  # Amber (Hunter/Elite)
	return Color(0, 0, 0, 0)

func crit_multiplier() -> float:
	if ttype == "sniper" and tracker.path_levels["Top"] > 0:
		return 1.0 + 0.35 * float(tracker.path_levels["Top"])
	return 1.0

func root_chance() -> float:
	if ttype == "archer" and tracker.path_levels["Top"] > 0:
		return 0.05 + 0.03 * float(tracker.path_levels["Top"])
	return 0.0

func splash_radius() -> int:
	var r: int = 0
	if ttype == "mage" and tracker.path_levels["Top"] > 0:
		r = 42 + 12 * tracker.path_levels["Top"]
	elif ttype == "cannon" and tracker.path_levels["Top"] > 0:
		r = 52 + 18 * tracker.path_levels["Top"]
	elif ttype == "lightning" and tracker.path_levels["Bottom"] > 0:
		r = 34 + 10 * tracker.path_levels["Bottom"]
	elif ttype == "frost" and tracker.path_levels["Top"] > 0:
		r = 38 + 12 * tracker.path_levels["Top"]
	if r > 0:
		return int(round(float(r) * splash_mult_bonus))
	return 0

func transmute_bonus() -> int:
	if ttype == "mage" and tracker.path_levels["Middle"] > 0:
		return 1 + tracker.path_levels["Middle"]
	return 0

func mana_leak_bonus() -> float:
	if ttype == "mage" and tracker.path_levels["Bottom"] > 0:
		return 1.0 + 0.06 * float(tracker.path_levels["Bottom"])
	return 1.0

func multi_shot() -> int:
	if ttype == "archer" and tracker.path_levels["Middle"] > 0:
		return 1 + mini(2, tracker.path_levels["Middle"] / 2 + 1)
	return 1

func focus_bonus() -> float:
	if ttype == "archer" and tracker.path_levels["Bottom"] > 0:
		return 1.0 + 0.12 * float(tracker.path_levels["Bottom"])
	return 1.0

func armor_ignore() -> float:
	var ignore: float = 0.0
	if ttype == "sniper" and tracker.path_levels["Bottom"] > 0:
		ignore += minf(0.4, 0.12 * float(tracker.path_levels["Bottom"]))
	if variant_key == "mage_geomancer":
		ignore += 0.20
	return ignore

func can_see_stealth() -> bool:
	if ttype == "sniper" or ttype == "lightning":
		return true # Implicit tech detection
	if ttype == "archer" and tracker.path_levels["Bottom"] >= 2:
		return true # Focus detection
	return false

func freeze_duration_ms() -> int:
	if ttype == "frost" and tracker.path_levels["Middle"] >= 2:
		return 350 + 90 * tracker.path_levels["Middle"]
	return 0

func chill_duration_ms() -> int:
	if ttype == "frost":
		return int(round((900.0 + 120.0 * float(tracker.path_levels["Top"])) * chill_mult_bonus))
	return 0

func flare_duration_ms() -> int:
	if ttype == "lightning" and tracker.path_levels["Middle"] > 0:
		return 2200 + 600 * tracker.path_levels["Middle"]
	return 0

func disrupt_duration_ms() -> int:
	if ttype == "lightning" and tracker.path_levels["Bottom"] > 0:
		return 800 + 400 * tracker.path_levels["Bottom"]
	return 0

func voltage_multiplier() -> float:
	if ttype == "lightning" and tracker.path_levels["Top"] > 0:
		return 1.0 + 0.05 * float(target_hit_count)
	return 1.0

func stun_duration_ms() -> int:
	if ttype == "cannon" and tracker.path_levels["Bottom"] >= 1:
		return 400 + 150 * tracker.path_levels["Bottom"]
	return 0

func teleport_chance() -> float:
	if ttype == "frost" and tracker.path_levels["Bottom"] >= 1:
		return 0.05 + 0.04 * float(tracker.path_levels["Bottom"])
	return 0.0

func fragile_multiplier() -> float:
	if ttype == "frost" and tracker.path_levels["Top"] >= 1:
		return 1.15
	return 1.0

func can_shatter() -> bool:
	if ttype == "frost" and tracker.path_levels["Middle"] >= 2:
		return true
	return false

func burn_dps(base_dmg: int) -> int:
	if ttype == "mage" and tracker.path_levels["Top"] > 0:
		return int(float(base_dmg) * (0.4 + 0.15 * float(tracker.path_levels["Top"])))
	return 0

func burn_duration_ms() -> int:
	if ttype == "mage" and tracker.path_levels["Top"] > 0:
		return 2000 + 400 * tracker.path_levels["Top"]
	return 0

# ---------------------------------------------------------------------------
# Shooting
# ---------------------------------------------------------------------------

func can_shoot(now_ms: int, speed_multiplier: float = 1.0) -> bool:
	var scaled_cd: float = float(effective_cooldown()) / maxf(0.25, speed_multiplier)
	return float(now_ms - last_shot_ms) >= scaled_cd

func select_target(enemies: Array, now_ms: int) -> Enemy:
	var in_range: Array = []
	var er: float = effective_range()
	var sees_stealth: bool = can_see_stealth()
	
	for enemy in enemies:
		if ttype == "cannon" and enemy.flying:
			continue
		if enemy.stealthed and not sees_stealth and enemy.revealed_until < now_ms:
			continue
		if pos.distance_to(enemy.pos) <= er:
			in_range.append(enemy)
			
	if in_range.is_empty():
		return null
		
	match target_mode:
		"first":
			var best: Enemy = in_range[0]
			var best_dist: float = best.get_remaining_path_distance()
			for e in in_range:
				var d: float = e.get_remaining_path_distance()
				if d < best_dist:
					best_dist = d
					best = e
			return best
		"last":
			var best: Enemy = in_range[0]
			var best_dist: float = best.get_remaining_path_distance()
			for e in in_range:
				var d: float = e.get_remaining_path_distance()
				if d > best_dist:
					best_dist = d
					best = e
			return best
		"strong":
			var best: Enemy = in_range[0]
			for e in in_range:
				if e.health > best.health:
					best = e
			return best
		"weak":
			var best: Enemy = in_range[0]
			for e in in_range:
				if e.health < best.health:
					best = e
			return best
		"close":
			var best: Enemy = in_range[0]
			var best_d: float = pos.distance_to(best.pos)
			for e in in_range:
				var d: float = pos.distance_to(e.pos)
				if d < best_d:
					best_d = d
					best = e
			return best
	return null

func shoot(now_ms: int, enemies: Array, projectiles: Array, speed_multiplier: float = 1.0) -> void:
	if not can_shoot(now_ms, speed_multiplier):
		return
	var target: Enemy = select_target(enemies, now_ms)
	if target == null:
		last_target_ref = null
		target_hit_count = 0
		return
	
	if target == last_target_ref:
		target_hit_count = mini(10, target_hit_count + 1)
	else:
		last_target_ref = target
		target_hit_count = 0

	var shots: int = multi_shot()
	for shot_index in range(shots):
		if ttype == "lightning" or ttype == "sniper":
			var effect_kind: String = "lightning_bolt" if ttype == "lightning" else "sniper_shot"
			game_state.add_effect(effect_kind, pos, now_ms, 100, -1, 18, color, "", 0.0, target.pos)
			game_state.apply_hit(self, target, get_effective_damage(now_ms), now_ms)
		else:
			var proj := Projectile.new(pos, target, self, get_effective_damage(now_ms), now_ms, shot_index, speed_multiplier)
			projectiles.append(proj)
	last_shot_ms = now_ms
	muzzle_flash_until = now_ms + 100

	# Veteran Archer — Volley: every 5th shot fires 3 extra spread projectiles
	if variant_key == "archer_veteran":
		volley_counter += 1
		if volley_counter % 5 == 0:
			var volley_dmg: int = get_effective_damage(now_ms)
			for vi in range(3):
				var vproj := Projectile.new(pos, target, self, volley_dmg, now_ms, shots + vi, speed_multiplier)
				projectiles.append(vproj)
			if game_state:
				game_state.add_effect("burst", pos, now_ms, 450, -1, 32, color)

# ---------------------------------------------------------------------------
# Upgrade actions
# ---------------------------------------------------------------------------

func upgrade_base(gold: int, now_ms: int) -> Dictionary:
	var cost: int = base_upgrade_cost()
	if cost < 0:
		return {"success": false, "reason": "base_maxed"}
	if gold < cost:
		return {"success": false, "reason": "not_enough_gold"}
	level += 1
	flash_until = now_ms + 500
	spent_gold += cost
	return {"success": true, "cost": cost, "message": "Base upgraded"}

func try_path_upgrade(gold: int, path: String, now_ms: int) -> Dictionary:
	if not path in _MAPS.PATH_KEYS:
		return {"success": false, "reason": "invalid_path"}
	if not tracker.can_attempt_upgrade(path):
		return {"success": false, "reason": "illegal_path_state"}
	var cost: int = path_upgrade_cost(path)
	if gold < cost:
		return {"success": false, "reason": "not_enough_gold"}
	if tracker.would_trigger_promotion_preview(path):
		tracker.start_promotion_preview(path)
		return {
			"success": true, "preview_promotion": true,
			"tower_id": id, "path": path, "cost": cost,
			"message": "Preview branch lock for %s" % path,
		}
	if not tracker.apply_non_promotion_upgrade(path):
		return {"success": false, "reason": "illegal_path_state"}
	flash_until = now_ms + 650
	spent_gold += cost
	return {"success": true, "cost": cost, "message": "%s upgraded" % path}

func confirm_promotion(gold: int, now_ms: int) -> Dictionary:
	var path: String = tracker.pending_promotion_path
	if path == "":
		return {"success": false, "reason": "no_pending_promotion"}
	var cost: int = path_upgrade_cost(path)
	if gold < cost:
		return {"success": false, "reason": "not_enough_gold"}
	if not tracker.confirm_promotion():
		return {"success": false, "reason": "promotion_failed"}
	burst_until = now_ms + 6000
	flash_until = now_ms + 1100
	spent_gold += cost
	return {
		"success": true, "cost": cost, "promoted": true,
		"tower_id": id, "path": path,
		"message": "%s added as secondary" % path,
	}

func cancel_promotion() -> Dictionary:
	if tracker.pending_promotion_path == "":
		return {"success": false, "reason": "no_pending_promotion"}
	var path: String = tracker.pending_promotion_path
	tracker.cancel_promotion()
	return {"success": true, "cancelled": true, "path": path, "message": "Promotion cancelled"}

func sell_value(current_wave: int) -> int:
	var rate: float = 0.9 if current_wave <= 3 else 0.7
	return maxi(base_cost / 2, int(round(float(spent_gold) * rate)))
