class_name GameState

# Port of GameState from core.py (lines 722-1320).
# Pure simulation — no Nodes, no rendering. Owned by GameScreen.

const _TT   := preload("res://data/tower_types.gd")
const _MAPS := preload("res://data/maps.gd")
const _UP   := preload("res://data/upgrade_paths.gd")
const _WAVE_CARDS := preload("res://data/wave_shop_cards.gd")

# Simulation collections
var towers: Array      # Array[Tower]
var enemies: Array     # Array[Enemy]
var projectiles: Array # Array[Projectile]
var effects: Array     # Array[Effect]
var particles: Array   # Array[Particle]
var pending_events: Array

# Run state
var path: Array        # Array[Vector2]
var map_id: int
var gold: int
var lives: int
var wave: int
var enemies_spawned: int
var wave_enemy_total: int
var spawn_interval_ms: int
var next_spawn_ms: int
var tower_id_counter: int
var game_state: String  # "playing" / "game_over" / "won"
var wave_started: bool
var wave_perfect: bool
var last_message: String
var wave_ready: bool
var paused: bool
var speed_multiplier: float
var _last_sim_ms: int

# Run-config modifiers
var _run_config: Dictionary
var _enemy_hp_mult: float
var _enemy_speed_mult: float
var _kill_reward_mult: float
var _wave_bonus_mult: float
var sell_disabled: bool
var _rp_mult: float
var _disabled_towers: Array
var _tower_damage_mults: Dictionary
var _tower_range_mults: Dictionary
var _tower_cooldown_mults: Dictionary
var _tower_splash_mults: Dictionary
var _variant_deltas: Dictionary
var _default_target_mode: String

const _SPATIAL_CELL_SIZE: float = 120.0

# Run stats
var stat_towers_placed: int
var stat_enemies_killed: int
var stat_gold_earned: int
var stat_waves_survived: int
var stat_perfect_waves: int
var stat_tower_use_by_type: Dictionary
var stat_tower_kills_by_type: Dictionary
var _spatial_grid_cache: Dictionary = {}
var _sim_tick_count: int = 0

# Wave shop bonuses — applied for the current wave, cleared on wave end
var _ws_damage_boost: float = 1.0       # multiplicative damage bonus
var _ws_cost_discount: float = 1.0      # multiplicative cost reduction
var _ws_next_spawn_speed_mult: float = 1.0  # enemy speed multiplier on spawn
var _ws_kill_reward_bonus: int = 0      # flat extra gold per kill
var _ws_armor_ignore: float = 0.0       # fraction of armor ignored this wave
var _ws_spawn_interval_mult: float = 1.0  # spawn interval multiplier
var _ws_frost_vanguard_remaining: int = 0   # pre-chill N enemies on spawn
var _ws_expose_active: bool = false         # strip armor + 10% dmg this wave

# Permanent run bonuses — never cleared between waves
var _perm_cd_mult: float = 1.0       # adrenaline stacks (< 1.0 = faster)
var _perm_range_mult: float = 1.0    # targeting matrix stacks
var _perm_kill_bonus: int = 0        # bounty contract stacks (flat g/kill)

# Wave shop gate — set true when wave ends (non-final); cleared by player card pick
var wave_shop_pending: bool = false

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _init(p_path: Array = [], run_config: Dictionary = {}, p_map_id: int = 0) -> void:
	path = p_path if not p_path.is_empty() else _MAPS.MAPS[0]["path"]
	map_id = p_map_id
	_run_config = run_config

	towers = []
	enemies = []
	projectiles = []
	effects = []
	particles = []
	pending_events = []

	var cfg := run_config
	var extra_gold: int   = cfg.get("extra_gold", 0)
	var extra_lives: int  = cfg.get("extra_lives", 0)
	var lives_override: int = cfg.get("starting_lives_override", -1)

	gold  = maxi(0, 300 + extra_gold)
	lives = lives_override if lives_override >= 0 else (10 + extra_lives)

	_enemy_hp_mult       = cfg.get("hp_mult_enemies",    1.0)
	_enemy_speed_mult    = cfg.get("speed_mult_enemies",  1.0)
	_kill_reward_mult    = cfg.get("kill_reward_mult",    1.0)
	_wave_bonus_mult     = cfg.get("wave_bonus_mult",     1.0)
	sell_disabled        = cfg.get("sell_disabled",       false)
	_rp_mult             = cfg.get("rp_mult",             1.0)
	_disabled_towers     = cfg.get("disabled_towers",     []).duplicate()
	_tower_damage_mults  = cfg.get("tower_damage_mults",  {}).duplicate()
	_tower_range_mults   = cfg.get("tower_range_mults",   {}).duplicate()
	_tower_cooldown_mults= cfg.get("tower_cooldown_mults",{}).duplicate()
	_tower_splash_mults  = cfg.get("tower_splash_mults",  {}).duplicate()
	_default_target_mode  = cfg.get("default_target_mode", "first")
	_variant_deltas = {}

	wave = 1
	enemies_spawned = 0
	wave_enemy_total = 8
	spawn_interval_ms = _current_spawn_interval_ms()
	next_spawn_ms = 0
	tower_id_counter = 0
	game_state = "playing"
	wave_started = false
	wave_perfect = true
	last_message = "Select a tower from the shop, then place it on the map."
	wave_ready = true
	paused = false
	_last_sim_ms = 0
	speed_multiplier = float(cfg.get("default_speed", 1.0))

	stat_towers_placed = 0
	stat_enemies_killed = 0
	stat_gold_earned = gold
	stat_waves_survived = 0
	stat_perfect_waves = 0
	var ttypes := _TT.TOWER_TYPES_LIST
	stat_tower_use_by_type = {}
	stat_tower_kills_by_type = {}
	for t in ttypes:
		stat_tower_use_by_type[t] = 0
		stat_tower_kills_by_type[t] = 0

	_ws_damage_boost = 1.0
	_ws_cost_discount = 1.0
	_ws_next_spawn_speed_mult = 1.0
	_ws_kill_reward_bonus = 0
	_ws_armor_ignore = 0.0
	_ws_spawn_interval_mult = 1.0
	_ws_frost_vanguard_remaining = 0
	_ws_expose_active = false
	_perm_cd_mult = 1.0
	_perm_range_mult = 1.0
	_perm_kill_bonus = 0
	wave_shop_pending = false

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func dispose() -> void:
	# Break circular references to avoid memory leaks
	for t in towers:
		if t is Object and "game_state" in t:
			t.game_state = null
	for p in projectiles:
		if p is Object and "tower" in p:
			p.tower = null
	
	towers.clear()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	particles.clear()
	pending_events.clear()
	_spatial_grid_cache.clear()

# ---------------------------------------------------------------------------
# Difficulty curves  (exact mirrors of Python methods)
# ---------------------------------------------------------------------------

func _wave_index() -> int:
	return maxi(0, wave - 1)

func _current_enemy_hp_multiplier() -> float:
	var idx: float = float(_wave_index())
	return 1.0 + 0.05 * idx + 0.0035 * (idx * idx)

func _current_enemy_speed_multiplier() -> float:
	return 1.0 + 0.006 * float(_wave_index())

func _current_spawn_interval_ms() -> int:
	var idx: int = _wave_index()
	var interval: int = 700 - 9 * idx - int(0.3 * float(idx * idx))
	return maxi(500, interval)

# ---------------------------------------------------------------------------
# Wave control
# ---------------------------------------------------------------------------

func start_wave() -> void:
	if wave_ready and game_state == "playing":
		wave_ready = false
		next_spawn_ms = 0

func toggle_pause() -> void:
	if game_state == "playing":
		paused = !paused

func set_speed(multiplier: float) -> void:
	speed_multiplier = multiplier

func enemies_alive() -> int:
	return enemies.size()

func get_tower_by_id(tower_id: int) -> Tower:
	for t in towers:
		if t.id == tower_id:
			return t
	return null

func _spatial_key_for_pos(p: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor(p.x / _SPATIAL_CELL_SIZE)), 0, int(ceil(float(_MAPS.WIDTH) / _SPATIAL_CELL_SIZE))),
		clampi(int(floor(p.y / _SPATIAL_CELL_SIZE)), 0, int(ceil(float(_MAPS.HEIGHT) / _SPATIAL_CELL_SIZE)))
	)

func _build_enemy_spatial_grid() -> Dictionary:
	var grid: Dictionary = {}
	for enemy in enemies:
		if enemy.health <= 0:
			continue
		var key: Vector2i = _spatial_key_for_pos(enemy.pos)
		if not key in grid:
			grid[key] = []
		grid[key].append(enemy)
	return grid

func _query_enemy_spatial_grid(grid: Dictionary, center: Vector2, radius: float) -> Array:
	if grid.is_empty():
		return []
	var min_cell: Vector2i = _spatial_key_for_pos(center - Vector2(radius, radius))
	var max_cell: Vector2i = _spatial_key_for_pos(center + Vector2(radius, radius))
	var result: Array = []
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var key := Vector2i(cx, cy)
			if key in grid:
				result.append_array(grid[key])
	return result

# ---------------------------------------------------------------------------
# Path distance helpers
# ---------------------------------------------------------------------------

func _path_distance(point: Vector2) -> float:
	var best: float = INF
	for i in range(path.size() - 1):
		best = minf(best, _point_to_segment_distance(point, path[i], path[i + 1]))
	return best

func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq == 0.0:
		return point.distance_to(a)
	var t: float = ((point - a).dot(ab)) / ab_len_sq
	t = clampf(t, 0.0, 1.0)
	return point.distance_to(a + ab * t)

# ---------------------------------------------------------------------------
# Tower placement & configuration
# ---------------------------------------------------------------------------

func _tower_purchase_cost(tower_type: String) -> int:
	var cost: int = _TT.TOWER_TYPES[tower_type]["cost"]
	var variant: Dictionary = _variant_deltas.get(tower_type, {})
	if not variant.is_empty():
		cost += int(variant.get("stat_delta", {}).get("cost", 0))
	return maxi(0, int(float(cost) * _ws_cost_discount))

func _configure_tower(tower: Tower) -> Tower:
	if _default_target_mode in _MAPS.TARGET_MODES:
		tower.target_mode = _default_target_mode

	tower.damage_mult_bonus   *= _tower_damage_mults.get(tower.ttype, 1.0)
	tower.range_mult_bonus    *= _tower_range_mults.get(tower.ttype, 1.0)
	tower.cooldown_mult_bonus *= _tower_cooldown_mults.get(tower.ttype, 1.0)
	tower.splash_mult_bonus   *= _tower_splash_mults.get(tower.ttype, 1.0)

	var variant: Dictionary = _variant_deltas.get(tower.ttype, {})
	if not variant.is_empty():
		var sd: Dictionary = variant.get("stat_delta", {})
		tower.variant_key   = variant.get("variant_key", "")
		tower.variant_label = variant.get("label", "")
		tower.variant_badge = variant.get("badge", "")
		var tint = variant.get("visual_tint", null)
		tower.variant_tint  = tint if tint is Color else Color(0, 0, 0, 0)
		tower.tower_name    = variant.get("label", tower.tower_name)
		tower.damage_mult_bonus   *= 1.0 + float(sd.get("damage", 0.0))
		tower.range_mult_bonus    *= 1.0 + float(sd.get("range", 0.0))
		tower.cooldown_mult_bonus *= maxf(0.5, 1.0 + float(sd.get("cooldown", 0.0)))
		tower.base_cost           += int(sd.get("cost", 0))
		tower.spent_gold          += int(sd.get("cost", 0))
		tower.chill_mult_bonus    *= 1.0 + float(variant.get("chill_bonus", 0.0))
		tower.splash_mult_bonus   *= 1.0 + float(variant.get("splash_bonus", 0.0))
		tower.chain_bonus_flat    += int(variant.get("chain_bonus", 0))
	tower.perm_cd_mult = _perm_cd_mult
	tower.perm_range_mult = _perm_range_mult
	tower.game_state = self
	return tower

func can_place_tower(p: Vector2, tower_type: String) -> Array:  # [bool, String]
	if tower_type in _disabled_towers:
		return [false, "Tower disabled by active modifier"]
	var cost: int = _tower_purchase_cost(tower_type)
	if gold < cost:
		return [false, "Not enough gold"]
	if p.y > _MAPS.HEIGHT - 115:
		return [false, "Cannot place on shop area"]
	if _path_distance(p) <= _MAPS.PATH_RADIUS + _MAPS.TOWER_RADIUS - 4:
		return [false, "Too close to the path"]
	for t in towers:
		if p.distance_to(t.pos) <= _MAPS.TOWER_RADIUS * 2 + 4:
			return [false, "Too close to another tower"]
	if p.x < 25 or p.x > _MAPS.WIDTH - 25 or p.y < 25 or p.y > _MAPS.HEIGHT - 135:
		return [false, "Out of bounds"]
	return [true, "OK"]

# ---------------------------------------------------------------------------
# Effects helper
# ---------------------------------------------------------------------------

func add_effect(kind: String, pos: Vector2, now_ms: int,
				duration: int = 350, until_ms_override: int = -1,
				radius: int = 18, color: Color = Color.WHITE,
				text: String = "", dy: float = 0.0,
				target_pos: Vector2 = Vector2.ZERO) -> void:
	var final_until: int = until_ms_override if until_ms_override >= 0 else (now_ms + duration)
	var has_tp: bool = target_pos != Vector2.ZERO
	effects.append(Effect.new(kind, pos, final_until, radius, color, text, now_ms, dy, target_pos, has_tp))

func emit_event(event: Dictionary) -> void:
	pending_events.append(event.duplicate())

func drain_events() -> Array:
	var drained: Array = pending_events.duplicate()
	pending_events.clear()
	return drained

# ---------------------------------------------------------------------------
# Action dispatch  (mirrors apply_action in core.py)
# ---------------------------------------------------------------------------

func apply_action(action: Dictionary, now_ms: int) -> Dictionary:
	if action.is_empty():
		return {"success": false, "reason": "no_action"}
	var action_type: String = action.get("type", "")
	var result: Dictionary = {"success": true, "action": action_type}

	if action_type == "place_tower":
		var tower_type: String = action["tower_type"]
		var p: Vector2 = action["pos"]
		var check: Array = can_place_tower(p, tower_type)
		if not check[0]:
			return {"success": false, "reason": check[1]}
		var cost: int = _tower_purchase_cost(tower_type)
		var tower := _configure_tower(Tower.new(p, tower_type, tower_id_counter))
		tower_id_counter += 1
		towers.append(tower)
		gold -= cost
		stat_towers_placed += 1
		if tower_type in stat_tower_use_by_type:
			stat_tower_use_by_type[tower_type] += 1
		last_message = "Placed %s." % tower.tower_name
		add_effect("flash", p, now_ms, 400, -1, 28, tower.color)
		result.merge({"tower_id": tower.id, "message": last_message})
		return result

	if action_type == "select_tower":
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		return {"success": true, "tower_id": tower.id, "message": "Selected %s" % tower.tower_name}

	if action_type == "upgrade_base":
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		var res: Dictionary = tower.upgrade_base(gold, now_ms)
		if not res["success"]:
			return res
		gold -= res["cost"]
		last_message = res["message"]
		if tower.level >= 5:
			add_effect("banner", tower.pos, now_ms, 900, -1, 34, Color(1.0, 0.843, 0.314), "MAXED")
		return res

	if action_type == "upgrade_path":
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		var res: Dictionary = tower.try_path_upgrade(gold, action["path"], now_ms)
		if not res["success"]:
			return res
		if res.get("preview_promotion", false):
			last_message = "Confirm %s as secondary path?" % action["path"]
			return res
		gold -= res["cost"]
		last_message = res["message"]
		add_effect("flash", tower.pos, now_ms, 500, -1, 30, tower.color)
		return res

	if action_type == "confirm_promotion":
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		var res: Dictionary = tower.confirm_promotion(gold, now_ms)
		if not res["success"]:
			return res
		gold -= res["cost"]
		last_message = res["message"]
		add_effect("banner", tower.pos, now_ms, 1150, -1, 44, Color(1.0, 0.843, 0.0), "%s PATH" % res["path"])
		return res

	if action_type == "cancel_promotion":
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		var res: Dictionary = tower.cancel_promotion()
		if not res["success"]:
			return res
		last_message = res["message"]
		return res

	if action_type == "sell_tower":
		if sell_disabled:
			return {"success": false, "reason": "sell_disabled"}
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		var value: int = tower.sell_value(wave)
		gold += value
		towers = towers.filter(func(t): return t.id != tower.id)
		last_message = "Sold %s for %d gold." % [tower.tower_name, value]
		add_effect("flash", tower.pos, now_ms, 450, -1, 30, Color(1.0, 0.706, 0.275))
		return {"success": true, "sold": true, "value": value, "message": last_message}

	if action_type == "cycle_target_mode":
		var tower: Tower = get_tower_by_id(action["tower_id"])
		if tower == null:
			return {"success": false, "reason": "tower_not_found"}
		var idx: int = _MAPS.TARGET_MODES.find(tower.target_mode)
		tower.target_mode = _MAPS.TARGET_MODES[(idx + 1) % _MAPS.TARGET_MODES.size()]
		last_message = "Target mode: %s" % tower.target_mode.capitalize()
		return {"success": true, "tower_id": tower.id, "mode": tower.target_mode, "message": last_message}

	if action_type == "restart_game":
		_init(path, _run_config, map_id)
		return {"success": true, "message": "Game restarted"}

	if action_type == "start_wave":
		start_wave()
		return {"success": true, "message": "Wave %d started!" % wave}

	if action_type == "toggle_pause":
		toggle_pause()
		return {"success": true, "message": "Paused" if paused else "Resumed"}

	if action_type == "set_speed":
		set_speed(action.get("multiplier", 1.0))
		return {"success": true, "message": "Speed x%d" % int(speed_multiplier)}

	if action_type == "wave_shop_pick":
		var card_id: String = action.get("card_id", "")
		if not _is_valid_wave_shop_card(card_id):
			return {"success": false, "reason": "invalid_wave_shop_card", "card_id": card_id}
		_apply_wave_shop_card(card_id, now_ms)
		wave_shop_pending = false
		wave_ready = true
		return {"success": true, "card_id": card_id, "message": "Bonus applied!"}

	if action_type == "wave_shop_skip":
		wave_shop_pending = false
		wave_ready = true
		return {"success": true, "message": ""}

	return {"success": false, "reason": "unknown_action:%s" % action_type}

func _is_valid_wave_shop_card(card_id: String) -> bool:
	for card in _WAVE_CARDS.CARDS:
		if str(card.get("id", "")) == card_id:
			return true
	for card in _WAVE_CARDS.MILESTONE_CARDS:
		if str(card.get("id", "")) == card_id:
			return true
	return false

func _apply_wave_shop_card(card_id: String, now_ms: int) -> void:
	var mid := Vector2(_MAPS.WIDTH / 2.0, 90.0)
	match card_id:
		# ── Standard wave cards ──────────────────────────────────────────────
		"windfall":
			var amount: int = 30 if wave <= 5 else (50 if wave <= 10 else 70)
			gold += amount
			stat_gold_earned += amount
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(1.0, 0.843, 0.0), "+%d GOLD" % amount)
		"life_recover":
			lives += 1
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(0.4, 1.0, 0.4), "+1 LIFE")
		"dmg_wave":
			_ws_damage_boost = 1.15
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(1.0, 0.4, 0.4), "POWER SURGE")
		"slow_wave":
			_ws_next_spawn_speed_mult = 0.80
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(0.4, 0.8, 1.0), "ENTROPY FIELD")
		"discount":
			_ws_cost_discount = 0.75
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(0.6, 1.0, 0.6), "SUPPLY DROP -25%")
		"frost_vanguard":
			_ws_frost_vanguard_remaining = 10
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(0.4, 0.8, 1.0), "FROST VANGUARD")
		"gold_wave":
			_ws_kill_reward_bonus = 8
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(1.0, 0.843, 0.0), "PROSPECTOR +8G/KILL")
		"expose":
			_ws_expose_active = true
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(1.0, 0.6, 0.2), "EXPOSE!")
		"rapid_spawn":
			_ws_spawn_interval_mult = 1.40
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(0.9, 0.9, 0.4), "PREP TIME")
		# ── Milestone cards (boss waves 5 / 10 / 15) ─────────────────────────
		"adrenaline":
			_perm_cd_mult *= 0.92
			for t in towers:
				t.perm_cd_mult = _perm_cd_mult
			add_effect("banner", mid, now_ms, 1100, -1, 28, Color(1.0, 0.6, 0.2), "ADRENALINE!")
		"war_chest":
			gold += 80
			stat_gold_earned += 80
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(1.0, 0.843, 0.0), "+80 GOLD")
		"emergency_protocol":
			lives += 2
			add_effect("banner", mid, now_ms, 900, -1, 26, Color(0.4, 1.0, 0.4), "+2 LIVES")
		"targeting_matrix":
			_perm_range_mult *= 1.05
			for t in towers:
				t.perm_range_mult = _perm_range_mult
			add_effect("banner", mid, now_ms, 1100, -1, 28, Color(0.3, 0.9, 1.0), "TARGETING MATRIX!")
		"bounty_contract":
			_perm_kill_bonus += 2
			add_effect("banner", mid, now_ms, 1100, -1, 28, Color(1.0, 0.843, 0.0), "BOUNTY +2G/KILL!")

# ---------------------------------------------------------------------------
# Enemy spawning
# ---------------------------------------------------------------------------

func _is_boss_wave() -> bool:
	return wave in [5, 10, 15]

## Boss waves: 1 boss + ~60% of the usual non-boss wave count as trash (plan #8).
## Keeps `wave_enemy_total` progression intact; only the spawn cap is reduced.
const BOSS_TRASH_DENSITY: float = 0.6
## Extra pause after the boss enters before trash spawns (readability).
const BOSS_POST_SPAWN_EXTRA_MS: int = 600

func get_wave_spawn_total() -> int:
	if not _is_boss_wave():
		return wave_enemy_total
	var trash: int = maxi(0, int(round(float(wave_enemy_total) * BOSS_TRASH_DENSITY)))
	return 1 + trash

func spawn_enemy(now_ms: int) -> void:
	var enemy: Enemy
	var spawned_boss := false

	# Boss waves: first spawn is always the boss
	if _is_boss_wave() and enemies_spawned == 0:
		match wave:
			5:  enemy = Enemy.BossShieldBrute.new(path)
			10: enemy = Enemy.BossSwarmCarrier.new(path)
			15: enemy = Enemy.BossRegenerator.new(path)
		spawned_boss = true
	else:
		var weights: Array
		if wave >= 8:
			weights = [0.24, 0.18, 0.18, 0.14, 0.14, 0.12]
		else:
			weights = [0.38, 0.16, 0.14, 0.12, 0.12, 0.08]

		var roll: float = randf()
		var cumulative: float = 0.0
		var chosen_idx: int = 0
		for i in range(weights.size()):
			cumulative += weights[i]
			if roll < cumulative:
				chosen_idx = i
				break

		match chosen_idx:
			0: enemy = Enemy.new(path)
			1: enemy = Enemy.FastScout.new(path)
			2: enemy = Enemy.ArmoredTank.new(path)
			3: enemy = Enemy.FlyingDrone.new(path)
			4: enemy = Enemy.SwarmMinion.new(path)
			5: enemy = Enemy.HeavyBrute.new(path)
			_: enemy = Enemy.new(path)

	var wave_hp_mult: float    = _current_enemy_hp_multiplier()
	var wave_speed_mult: float = _current_enemy_speed_multiplier()
	enemy.health     = maxi(1, int(round(float(enemy.health) * wave_hp_mult * _enemy_hp_mult)))
	enemy.max_health = enemy.health
	enemy.speed      = enemy.speed * wave_speed_mult * _enemy_speed_mult * _ws_next_spawn_speed_mult

	if _ws_frost_vanguard_remaining > 0:
		enemy.chilled_until = maxi(enemy.chilled_until, now_ms + 3000)
		_ws_frost_vanguard_remaining -= 1

	var jitter: int = randi_range(-5, 5)
	enemy.pos.x += float(jitter)
	enemy.pos.y += float(jitter)

	enemies.append(enemy)
	enemies_spawned += 1
	# Clear per-spawn speed mult once all enemies for this wave are queued
	if enemies_spawned >= get_wave_spawn_total():
		_ws_next_spawn_speed_mult = 1.0
	var interval: int = int(float(spawn_interval_ms) * _ws_spawn_interval_mult)
	if spawned_boss:
		interval += BOSS_POST_SPAWN_EXTRA_MS
	next_spawn_ms = now_ms + interval
	wave_started = true

# ---------------------------------------------------------------------------
# Hit logic  (mirrors apply_hit in core.py)
# ---------------------------------------------------------------------------

func apply_projectile_hit(projectile: Projectile, now_ms: int) -> void:
	apply_hit(projectile.tower, projectile.target, projectile.damage, now_ms)

func apply_hit(tower: Tower, target: Enemy, damage: int, now_ms: int) -> void:
	if target == null or target.health <= 0:
		return

	# Boss shield absorption — BossShieldBrute absorbs entire hits until shield_hp reaches 0
	if target is Enemy.BossShieldBrute and target.shield_hp > 0:
		target.shield_hp -= 1
		add_effect("banner", target.pos, now_ms, 500, -1, 26, Color(0.5, 0.75, 1.0),
				   "SHIELD %d" % target.shield_hp)
		add_effect("ring", target.pos, now_ms, 320, -1, target.radius + 10, Color(0.5, 0.75, 1.0))
		_add_particle_burst(target.pos, "spark", Color(0.6, 0.85, 1.0), 14, now_ms)
		return

	_add_particle_burst(target.pos, "spark", Color(1.0, 0.902, 0.588), 6, now_ms)
	_add_particle_burst(target.pos, "smoke", Color(0.392, 0.392, 0.471), 3, now_ms)

	# Wave-shop armor ignore
	if _ws_armor_ignore > 0.0:
		target.armor = maxf(0.0, target.armor - _ws_armor_ignore)

	# Expose — strip all armor and deal +10% damage this wave
	if _ws_expose_active:
		target.armor = 0.0
		damage = int(float(damage) * 1.10)

	# Marked bonus — any tower hitting a marked enemy deals +15% damage
	if target.marked_until > now_ms:
		damage = int(float(damage) * 1.15)
		add_effect("dmg_num", target.pos + Vector2(0, -10), now_ms, 400, -1, 0,
				   Color(0.9, 0.5, 1.0), "MARKED!")

	# Wave-shop damage boost
	if _ws_damage_boost != 1.0:
		damage = int(float(damage) * _ws_damage_boost)

	# 1. Fragile Check (Nearby Frost Towers)
	var frag_mult: float = 1.0
	for t in towers:
		if t.ttype == "frost" and t.fragile_multiplier() > 1.0:
			if t.pos.distance_to(target.pos) <= t.effective_range() + 10.0:
				frag_mult = 1.15
				break
	damage = int(float(damage) * frag_mult)

	# 2. Shatter Check (Physical/Earth vs Frozen)
	if target.frozen_until > now_ms:
		var is_physical: bool = tower.ttype in ["archer", "cannon", "sniper"]
		var is_earth: bool = tower.variant_key == "mage_geomancer"
		if is_physical or is_earth:
			damage *= 2
			add_effect("banner", target.pos, now_ms, 380, -1, 24, Color(0.0, 0.9, 1.0), "SHATTER!")
			_add_particle_burst(target.pos, "spark", Color(0.6, 1.0, 1.0), 10, now_ms)

	if tower.ttype == "archer":
		damage = int(round(float(damage) * tower.focus_bonus()))

	if tower.ttype == "sniper":
		if tower.tracker.path_levels["Top"] >= 1:
			var crit_chance: float = 0.12 + 0.04 * float(tower.tracker.path_levels["Top"])
			if randf() < crit_chance:
				damage = int(float(damage) * 2.5)
				add_effect("banner", target.pos, now_ms, 420, -1, 24, Color(1.0, 0.157, 0.157), "CRIT!")
				_add_particle_burst(target.pos, "spark", Color(1.0, 0.235, 0.157), 12, now_ms)
		if tower.tracker.path_levels["Middle"] >= 2:
			var flare_ms: int = 2500 + 500 * tower.tracker.path_levels["Middle"]
			target.revealed_until = maxi(target.revealed_until, now_ms + flare_ms)
			add_effect("radar_pulse", target.pos, now_ms, 650, -1, 110, Color(0.784, 0.902, 0.196))
		target.armor = maxf(0.0, target.armor - tower.armor_ignore())
		# Longshot Sniper variant — Mark the target for 3s
		if tower.variant_key == "sniper_longshot":
			target.marked_until = maxi(target.marked_until, now_ms + 3000)
			add_effect("ring", target.pos, now_ms, 450, -1, target.radius + 6, Color(0.9, 0.5, 1.0))

	if tower.ttype == "lightning" and target.revealed_until > now_ms:
		damage = int(round(float(damage) * 1.18))

	var killed: bool = target.take_damage(damage)
	target.last_damage_time = now_ms
	target.flash_until = now_ms + 100
	add_effect("hit_flash", target.pos, now_ms, 90, -1, target.radius + 3, Color.WHITE)
	var num_color: Color = tower.variant_tint if tower.variant_tint.a > 0.0 else tower.color
	add_effect("dmg_num", target.pos, now_ms, 700, -1, 0, num_color, str(damage), 0.038)
	add_effect("hit", target.pos, now_ms, 220, -1, 15, tower.color)

	# Mage Alchemy & Arcanist Leak
	if tower.ttype == "mage":
		damage = int(round(float(damage) * tower.mana_leak_bonus()))
		var t_bonus: int = tower.transmute_bonus()
		if t_bonus > 0:
			target.transmute_until = maxi(target.transmute_until, now_ms + 2500)
			add_effect("ring", target.pos, now_ms, 250, -1, 15, Color(1.0, 0.843, 0.0))
			
		var b_dps: int = tower.burn_dps(damage)
		if b_dps > 0:
			# Runic Mage — Resonance: reset burn timer on already-burning enemies
			var is_resonance: bool = tower.variant_key == "mage_runic"
			if is_resonance and target.burn_until > now_ms:
				target.burn_until = now_ms + tower.burn_duration_ms()
				add_effect("banner", target.pos, now_ms, 420, -1, 20, Color(1.0, 0.45, 0.0), "RESONANCE!")
			else:
				target.burn_until = maxi(target.burn_until, now_ms + tower.burn_duration_ms())
			target.burn_dps = maxi(target.burn_dps, b_dps)
			add_effect("flash", target.pos, now_ms, 250, -1, 15, Color(1.0, 0.4, 0.0))

	# Mage splash
	if tower.ttype == "mage" and tower.tracker.path_levels["Top"] > 0:
		var r: int = tower.splash_radius()
		for e in enemies:
			if e == target or e.health <= 0:
				continue
			if target.pos.distance_to(e.pos) <= float(r):
				e.take_damage(maxi(1, int(float(damage) * 0.55)))
		add_effect("explosion", target.pos, now_ms, 320, -1, r, Color(0.392, 0.627, 1.0))

	if tower.ttype == "cannon":
		var aoe_r: int = tower.splash_radius() if tower.tracker.path_levels["Top"] > 0 else 0
		if aoe_r > 0:
			emit_event({"type": "screen_shake", "intensity": 4.0, "duration_ms": 300, "ms": now_ms})
			for e in enemies:
				if e == target or e.health <= 0:
					continue
				if target.pos.distance_to(e.pos) <= float(aoe_r):
					e.take_damage(maxi(1, int(float(damage) * 0.65)))
			var eff_kind: String = "siege_shockwave" if tower.variant_key == "cannon_siege_mk2" else "explosion"
			add_effect(eff_kind, target.pos, now_ms, 420, -1, aoe_r, Color(1.0, 0.471, 0.157))
		
		var stun_ms: int = tower.stun_duration_ms()
		if stun_ms > 0:
			target.frozen_until = maxi(target.frozen_until, now_ms + stun_ms)
			add_effect("ring", target.pos, now_ms, 200, -1, 12, Color(1.0, 1.0, 0.0))
			# Shock path (Bottom): chill all enemies inside the AoE radius too
			var shock_r: int = aoe_r if aoe_r > 0 else int(tower.effective_range() * 0.35)
			var chill_ms: int = 300 + 100 * tower.tracker.path_levels["Bottom"]
			for e in enemies:
				if e == target or e.health <= 0:
					continue
				if target.pos.distance_to(e.pos) <= float(shock_r):
					e.chilled_until = maxi(e.chilled_until, now_ms + chill_ms)

	# Frost chill / freeze / rewind / spike AoE
	if tower.ttype == "frost":
		target.chilled_until = maxi(target.chilled_until, now_ms + tower.chill_duration_ms())
		var f_ms: int = tower.freeze_duration_ms()
		if f_ms > 0:
			target.frozen_until = maxi(target.frozen_until, now_ms + f_ms)
		
		var t_chance: float = tower.teleport_chance()
		if t_chance > 0.0 and randf() < t_chance:
			target.rewind_by_distance(0.18, now_ms)
			add_effect("vortex", target.pos, now_ms, 450, -1, 32, Color(0.0, 0.8, 1.0))
			_add_particle_burst(target.pos, "spark", Color(0.2, 0.8, 1.0), 15, now_ms)

		if tower.tracker.path_levels["Bottom"] >= 2:
			var frac: float = 0.35 + 0.05 * float(tower.tracker.path_levels["Bottom"] - 2)
			if target.rewind_by_distance(frac, now_ms):
				add_effect("ice_rewind", target.pos, now_ms, 400, -1, 24, Color(0.627, 0.902, 1.0))
		var spike_r: int = tower.splash_radius()
		if spike_r > 0:
			for e in enemies:
				if e == target or e.health <= 0:
					continue
				if target.pos.distance_to(e.pos) <= float(spike_r):
					e.take_damage(maxi(1, int(float(damage) * 0.45)))
			add_effect("ice_spikes", target.pos, now_ms, 420, -1, spike_r, Color(0.588, 0.902, 1.0))

	# Lightning flare + EMP
	if tower.ttype == "lightning":
		var flare_ms: int = tower.flare_duration_ms()
		if flare_ms > 0:
			target.revealed_until = maxi(target.revealed_until, now_ms + flare_ms)
			add_effect("banner", target.pos, now_ms, 340, -1, 18, Color(1.0, 0.922, 0.275), "FLARE")
			
		var disrupt_ms: int = tower.disrupt_duration_ms()
		if disrupt_ms > 0:
			target.disrupt_until = maxi(target.disrupt_until, now_ms + disrupt_ms)
			target.shields = maxi(0, target.shields - 10 * tower.tracker.path_levels["Bottom"])
			add_effect("ring", target.pos, now_ms, 300, -1, 24, Color(0.47, 1.0, 1.0))

		var storm_r: int = tower.splash_radius() if tower.tracker.path_levels["Bottom"] > 0 else 0
		if storm_r > 0:
			for e in enemies:
				if e == target or e.health <= 0:
					continue
				if target.pos.distance_to(e.pos) <= float(storm_r):
					e.take_damage(maxi(1, int(float(damage) * 0.35)))
			add_effect("ring", target.pos, now_ms, 180, -1, storm_r, Color(0.8, 1.0, 0.0))

	# Archer Rooting
	if tower.ttype == "archer" and tower.root_chance() > 0.0:
		if randf() < tower.root_chance():
			target.rooted_until = maxi(target.rooted_until, now_ms + 1200)
			add_effect("banner", target.pos, now_ms, 400, -1, 16, Color(0.4, 0.9, 0.4), "ROOTED")

	if killed:
		add_effect("death_pop", target.pos, now_ms, 380, -1, target.radius, Color.WHITE)
		var shard_color: Color = tower.variant_tint if tower.variant_tint.a > 0.0 else tower.color
		add_effect("shards", target.pos, now_ms, 360, -1, target.radius + 12, shard_color)
		add_effect("banner", target.pos, now_ms, 260, -1, 16, Color.WHITE, "KO")

		match target.type_name:
			"FlyingDrone":
				_add_particle_burst(target.pos, "spark", Color(0.588, 0.902, 1.0), 18, now_ms)
				_add_particle_burst(target.pos, "smoke", Color(0.706, 0.784, 0.863), 6, now_ms)
			"ArmoredTank", "HeavyBrute":
				_add_particle_burst(target.pos, "debris", Color(0.392, 0.314, 0.275), 20, now_ms)
				_add_particle_burst(target.pos, "smoke", Color(0.157, 0.157, 0.176), 12, now_ms)
			_:
				var dcolor: Color = tower.variant_tint if tower.variant_tint.a > 0.0 else tower.color
				_add_particle_burst(target.pos, "debris", dcolor, 10, now_ms)
				_add_particle_burst(target.pos, "smoke", Color(0.235, 0.235, 0.275), 8, now_ms)

		if tower.ttype in stat_tower_kills_by_type:
			stat_tower_kills_by_type[tower.ttype] += 1

# ---------------------------------------------------------------------------
# Main simulation step  (mirrors update_simulation in core.py)
# ---------------------------------------------------------------------------

func update_simulation(now_ms: int) -> void:
	if game_state != "playing":
		effects = effects.filter(func(e): return e.until_ms > now_ms)
		return

	if paused or wave_ready or wave_shop_pending:
		effects = effects.filter(func(e): return e.until_ms > now_ms)
		return

	# Step 1: spawn
	if enemies_spawned < get_wave_spawn_total() and now_ms >= next_spawn_ms:
		spawn_enemy(now_ms)

	# Step 2: move enemies, detect leaks
	var leaked_enemies: Array = []
	for enemy in enemies:
		# Apply DOT effects
		if now_ms < enemy.burn_until:
			var dot: int = maxi(1, int(float(enemy.burn_dps) * 0.016))
			enemy.health -= dot
			if now_ms % 250 == 0:
				_add_particle_burst(enemy.pos, "flame", Color(1.0, 0.4, 0.2), 3, now_ms)

		# BossRegenerator — regen 8 HP/s
		if enemy is Enemy.BossRegenerator and enemy.health > 0 and enemy.health < enemy.max_health:
			var regen_amount: int = int(enemy.regen_dps * float(now_ms - _last_sim_ms) / 1000.0)
			if regen_amount > 0:
				enemy.health = mini(enemy.max_health, enemy.health + regen_amount)

		var leaked: bool = enemy.move(now_ms, speed_multiplier)
		if leaked:
			leaked_enemies.append(enemy)
	for enemy in leaked_enemies:
		enemies.erase(enemy)
		lives -= 1
		wave_perfect = false
		emit_event({"type": "screen_shake", "intensity": 12.0, "duration_ms": 500, "ms": now_ms})
		add_effect("banner", path[-1], now_ms, 350, -1, 18, Color(1.0, 0.314, 0.314), "LEAK")
		add_effect("ring",   path[-1], now_ms, 420, -1, 28, Color(1.0, 0.353, 0.353))
		if lives <= 0:
			game_state = "game_over"
			last_message = "Base destroyed."

	# Step 3: tower shooting (Throttled Spatial Grid rebuild)
	_sim_tick_count += 1
	_spatial_grid_cache = _build_enemy_spatial_grid()
	var enemy_grid := _spatial_grid_cache
	
	for tower in towers:
		var nearby_enemies: Array = _query_enemy_spatial_grid(enemy_grid, tower.pos, tower.effective_range() + 4.0)
		tower.shoot(now_ms, nearby_enemies, projectiles, speed_multiplier)

	# Step 4: projectile movement + hit detection
	var dead_projectiles: Array = []
	for projectile in projectiles:
		if projectile.target == null or projectile.target.health <= 0:
			dead_projectiles.append(projectile)
			continue
		projectile.move()
		var hit_dist: float = float(projectile.target.radius + projectile.radius)
		if projectile.pos.distance_to(projectile.target.pos) <= hit_dist:
			apply_projectile_hit(projectile, now_ms)
			dead_projectiles.append(projectile)
		elif projectile.out_of_bounds():
			dead_projectiles.append(projectile)
	for p in dead_projectiles:
		projectiles.erase(p)

	# Step 5: remove dead enemies, award gold
	var dead_enemies: Array = []
	for enemy in enemies:
		if enemy.health <= 0:
			dead_enemies.append(enemy)
	for enemy in dead_enemies:
		var reward: int = maxi(1, int(round(float(enemy.reward) * _kill_reward_mult)))

		# Alchemy Bonus
		if enemy.transmute_until > now_ms:
			var bonus: int = randi_range(1, 3)
			reward += bonus
			add_effect("banner", enemy.pos, now_ms, 350, -1, 24, Color(1.0, 1.0, 0.4), "GOLD++")

		# Wave-shop Prospector bonus + permanent Bounty Contract
		reward += _ws_kill_reward_bonus + _perm_kill_bonus

		gold += reward
		stat_gold_earned += reward
		stat_enemies_killed += 1
		enemies.erase(enemy)
		add_effect("banner", enemy.pos, now_ms, 260, -1, 18, Color(1.0, 0.843, 0.0), "+%d" % reward)

		# BossSwarmCarrier — spawn 4 SwarmMinions on death
		if enemy is Enemy.BossSwarmCarrier and not enemy.spawned_swarm:
			enemy.spawned_swarm = true
			add_effect("explosion", enemy.pos, now_ms, 700, -1, 90, Color(1.0, 0.5, 0.1, 0.55))
			for _i in range(4):
				var minion := Enemy.SwarmMinion.new(path)
				minion.health = maxi(1, int(float(minion.health) * _current_enemy_hp_multiplier() * _enemy_hp_mult))
				minion.max_health = minion.health
				minion.pos = Vector2(
					enemy.pos.x + float(randi_range(-20, 20)),
					enemy.pos.y + float(randi_range(-20, 20))
				)
				minion.path_index = enemy.path_index
				enemies.append(minion)

	# Step 6: expire effects (Optimized frequency)
	if _sim_tick_count % 4 == 0:
		effects = effects.filter(func(e): return e.until_ms > now_ms)

	# Step 7: particle physics (frame-rate-independent exponential friction)
	if _last_sim_ms == 0:
		_last_sim_ms = now_ms
	var dt: float = float(now_ms - _last_sim_ms) * speed_multiplier
	_last_sim_ms = now_ms

	var alive_particles: Array = []
	for p in particles:
		if now_ms >= p.start_ms + p.lifespan_ms:
			continue
		p.pos.x += p.vel.x * dt
		p.pos.y += p.vel.y * dt
		var friction_factor: float = pow(p.friction, dt / 16.0)
		p.vel.x *= friction_factor
		p.vel.y *= friction_factor
		p.vel.y += p.gravity * dt
		alive_particles.append(p)
	particles = alive_particles

	# Step 8: wave completion check (skip if wave shop is already pending)
	if not wave_shop_pending and enemies_spawned >= get_wave_spawn_total() and enemies.is_empty() and game_state == "playing":
		var wave_bonus: int = int(round(float(50 + wave * 15) * _wave_bonus_mult))
		gold += wave_bonus
		stat_gold_earned += wave_bonus
		stat_waves_survived += 1
		if wave_perfect:
			var perf_bonus: int = int(round(20.0 * _wave_bonus_mult))
			gold += perf_bonus
			stat_gold_earned += perf_bonus
			stat_perfect_waves += 1
			add_effect("banner", Vector2(_MAPS.WIDTH / 2.0, 48), now_ms, 1000, -1, 30,
					   Color(0.471, 1.0, 0.471), "PERFECT WAVE")
		if wave >= _MAPS.MAX_WAVE:
			game_state = "won"
			last_message = "All 15 waves cleared."
			return
		wave += 1
		enemies_spawned = 0
		# Smooth early scaling: +2 for waves 2-3, +4 thereafter
		var jump = 2 if wave <= 3 else 4
		wave_enemy_total += jump
		spawn_interval_ms = _current_spawn_interval_ms()
		next_spawn_ms = now_ms + 1200
		wave_started = false
		wave_perfect = true
		# Clear per-wave shop bonuses before offering next wave shop
		_ws_damage_boost = 1.0
		_ws_cost_discount = 1.0
		_ws_kill_reward_bonus = 0
		_ws_armor_ignore = 0.0
		_ws_spawn_interval_mult = 1.0
		_ws_frost_vanguard_remaining = 0
		_ws_expose_active = false
		# Show wave shop instead of immediately readying
		wave_shop_pending = true
		last_message = "Wave %d ready — choose a bonus!" % wave

# ---------------------------------------------------------------------------
# Particle burst helper
# ---------------------------------------------------------------------------

func _add_particle_burst(pos: Vector2, kind: String, color: Color, count: int, now_ms: int) -> void:
	for _i in range(count):
		var angle: float = randf() * TAU
		var spd: float
		var lifespan: int
		var size: float
		var gravity: float
		var friction: float

		match kind:
			"spark":
				spd      = randf_range(0.12, 0.45)
				lifespan = randi_range(150, 450)
				size     = randf_range(1.2, 2.8)
				gravity  = 0.004
				friction = 0.94
			"smoke":
				spd      = randf_range(0.01, 0.06)
				lifespan = randi_range(800, 1600)
				size     = randf_range(4.0, 14.0)
				gravity  = -0.003
				friction = 0.96
			"flame":
				spd      = randf_range(0.04, 0.12)
				lifespan = randi_range(300, 700)
				size     = randf_range(3.5, 7.0)
				gravity  = -0.008 # Rises
				friction = 0.95
			_:  # debris
				spd      = randf_range(0.08, 0.28)
				lifespan = randi_range(500, 1000)
				size     = randf_range(2.5, 5.0)
				gravity  = 0.014
				friction = 0.95

		particles.append(Particle.new(
			kind,
			pos,
			Vector2(cos(angle) * spd, sin(angle) * spd),
			color, size, lifespan, now_ms, friction, gravity
		))
