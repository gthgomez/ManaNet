extends Node

# Headless simulation test — validates the 15-wave game loop with no renderer.
# Run this scene from the Godot editor to verify simulation correctness.
# Expected output (no modifiers, default config):
#   Wave 15 completed, lives ≥ 1, gold > 0, RP > 0.

const _MAPS := preload("res://data/maps.gd")
const _TT   := preload("res://data/tower_types.gd")

var _gs: GameState
var _now_ms: int = 0
var _dt_ms: int = 17   # ~60 FPS tick
var _tick: int = 0
var _MAX_TICKS: int = 60 * 60 * 10   # 10 minutes of simulated time as safety cap

func _ready() -> void:
	print("=== SimTest: starting headless 15-wave run ===")
	var map_data: Dictionary = _MAPS.MAPS[0]
	_gs = GameState.new(map_data["path"], {}, 0)

	# Place a balanced starter grid: 2 archers, 1 mage, 1 sniper, 1 cannon, 1 frost
	_place_initial_towers()
	_spend_gold_before_wave()
	print("Towers placed: %d  |  Starting gold: %d  |  Lives: %d" % [
		_gs.towers.size(), _gs.gold, _gs.lives])

	# Kick off wave 1
	_gs.apply_action({"type": "start_wave"}, _now_ms)

func _place_initial_towers() -> void:
	var placements: Array = [
		[Vector2(350, 240), "archer"],
		[Vector2(550, 360), "archer"],
		[Vector2(150, 200), "mage"],
		[Vector2(750, 120), "sniper"],
		[Vector2(350, 380), "cannon"],
		[Vector2(550, 150), "frost"],
	]
	for entry in placements:
		var p: Vector2 = entry[0]
		var ttype: String = entry[1]
		var check: Array = _gs.can_place_tower(p, ttype)
		if check[0]:
			_gs.apply_action({"type": "place_tower", "tower_type": ttype, "pos": p}, _now_ms)
		else:
			print("  Placement skipped (%s at %s): %s" % [ttype, p, check[1]])

func _process(_delta: float) -> void:
	if _tick > _MAX_TICKS:
		_fail("Timed out — simulation did not finish within tick budget")
		return

	_gs.update_simulation(_now_ms)
	_now_ms += _dt_ms
	_tick += 1

	# Auto-start each new wave
	if _gs.wave_ready and _gs.game_state == "playing":
		_spend_gold_before_wave()
		_gs.apply_action({"type": "start_wave"}, _now_ms)
		print("  Wave %d started (tick %d, gold %d, lives %d)" % [
			_gs.wave, _tick, _gs.gold, _gs.lives])

	if _gs.game_state == "game_over":
		_fail("Game over at wave %d (lives = %d)" % [_gs.wave, _gs.lives])
		return

	if _gs.game_state == "won":
		_pass_test()
		return

func _spend_gold_before_wave() -> void:
	var attempts: int = 0
	var spent: bool = true
	while spent and attempts < 80:
		attempts += 1
		spent = _try_upgrade_tower()
		if not spent:
			spent = _try_buy_tower()

func _try_upgrade_tower() -> bool:
	for tower in _gs.towers:
		var top_level: int = tower.tracker.path_levels["Top"]
		if top_level < _TT.PATH_UPGRADE_COSTS.size() and tower.tracker.can_attempt_upgrade("Top"):
			var path_cost: int = tower.path_upgrade_cost("Top")
			if _gs.gold >= path_cost:
				var res: Dictionary = _gs.apply_action(
					{"type": "upgrade_path", "tower_id": tower.id, "path": "Top"},
					_now_ms
				)
				if res.get("success", false) and not res.get("preview_promotion", false):
					return true

		var base_cost: int = tower.base_upgrade_cost()
		if base_cost >= 0 and _gs.gold >= base_cost:
			var res: Dictionary = _gs.apply_action(
				{"type": "upgrade_base", "tower_id": tower.id},
				_now_ms
			)
			if res.get("success", false):
				return true
	return false

func _try_buy_tower() -> bool:
	var order: Array = ["cannon", "mage", "lightning", "sniper", "frost", "archer"]
	for ttype in order:
		var cost: int = _TT.TOWER_TYPES[ttype]["cost"]
		if _gs.gold < cost:
			continue
		for p in _candidate_positions():
			var check: Array = _gs.can_place_tower(p, ttype)
			if check[0]:
				var res: Dictionary = _gs.apply_action({"type": "place_tower", "tower_type": ttype, "pos": p}, _now_ms)
				return res.get("success", false)
	return false

func _candidate_positions() -> Array:
	var positions: Array = []
	for y in range(60, _MAPS.HEIGHT - 135, 45):
		for x in range(45, _MAPS.WIDTH - 25, 45):
			positions.append(Vector2(x, y))
	return positions

func _pass_test() -> void:
	var rp: int = Progression.compute_rp(
		_gs.stat_waves_survived,
		_gs.stat_perfect_waves,
		maxi(0, _gs.lives),
		_gs.stat_gold_earned,
		maxi(0, _gs.stat_gold_earned - _gs.gold),
		true
	)
	print("")
	print("=== SimTest PASSED ===")
	print("  Waves survived : %d / %d" % [_gs.stat_waves_survived, _MAPS.MAX_WAVE])
	print("  Perfect waves  : %d" % _gs.stat_perfect_waves)
	print("  Lives remaining: %d" % _gs.lives)
	print("  Gold remaining : %d" % _gs.gold)
	print("  Gold earned    : %d" % _gs.stat_gold_earned)
	print("  Enemies killed : %d" % _gs.stat_enemies_killed)
	print("  Towers placed  : %d" % _gs.stat_towers_placed)
	print("  RP this run    : %d" % rp)
	print("  Sim ticks used : %d (~%.1f s)" % [_tick, float(_tick * _dt_ms) / 1000.0])
	set_process(false)
	get_tree().quit(0)

func _fail(reason: String) -> void:
	print("")
	print("=== SimTest FAILED: %s ===" % reason)
	print("  Wave: %d  Lives: %d  Gold: %d  Enemies: %d" % [
		_gs.wave, _gs.lives, _gs.gold, _gs.enemies.size()])
	set_process(false)
	get_tree().quit(1)
