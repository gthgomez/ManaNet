extends SceneTree

# Economy measurement for balance work (Workstream E).
#
# Plays real full runs and reports wave-by-wave resources so tuning decisions can
# cite measurements instead of intuition. This is a diagnostic, not a pass/fail
# gate: it prints tables and asserts only that the observed curve is finite and
# internally consistent.
#
# Run: godot --headless --path . --script tests/simulation/economy_probe.gd

const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")
const TICK_MS: int = 16
const MAX_SIM_MS: int = 30 * 60 * 1000

var _pass: int = 0
var _fail: int = 0

const STRATEGIES: Dictionary = {
	"optimized": {
		"buy_order": ["archer", "mage", "cannon", "sniper", "frost"],
		"upgrade_path": "Top",
		"prefer_upgrade": 0.6,
	},
	"balanced": {
		"buy_order": ["archer", "mage", "archer", "frost", "cannon"],
		"upgrade_path": "Middle",
		"prefer_upgrade": 0.5,
	},
	"lazy": {
		"buy_order": ["archer", "archer"],
		"upgrade_path": "Middle",
		"prefer_upgrade": 0.25,
	},
}

func _init() -> void:
	print("--- ECONOMY PROBE ---")
	for strategy_name in STRATEGIES.keys():
		for seed_value in [11, 22]:
			_probe(0, strategy_name, seed_value)
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _candidate_spots(path: Array) -> Array:
	var spots: Array = []
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg: Vector2 = b - a
		var length: float = seg.length()
		if length <= 0.0:
			continue
		var dir: Vector2 = seg / length
		var normal := Vector2(-dir.y, dir.x)
		var steps: int = maxi(2, int(ceil(length / 40.0)))
		for s in range(steps + 1):
			var anchor: Vector2 = a.lerp(b, float(s) / float(steps))
			for offset in [60.0, 85.0, 110.0]:
				for side in [-1.0, 1.0]:
					var p: Vector2 = anchor + normal * offset * side
					if p.x < 25 or p.x > 875 or p.y < 25 or p.y > 465:
						continue
					spots.append(p)
	return spots

func _play(map_id: int, strategy_name: String, seed_value: int) -> Dictionary:
	var strategy: Dictionary = STRATEGIES[strategy_name]
	var map_data: Dictionary = _MAPS.MAPS[map_id]
	var gs := GameStateScript.new(map_data["path"], {"rng_seed": seed_value * 7919}, map_id)
	var spots: Array = _candidate_spots(map_data["path"])
	var drng := RandomNumberGenerator.new()
	drng.seed = seed_value * 31 + 7
	var next_decision: int = 0
	var next_idx: int = 0
	var waves: Array = []
	var last_wave: int = gs.wave
	var wave_start_gold: int = gs.gold
	var wave_start_ms: int = 0
	var starting_tower_placed: bool = false

	while gs.game_state == "playing" and gs.sim_now() < MAX_SIM_MS:
		# Starting tower (mirrors GameScreen's free start).
		if not starting_tower_placed:
			starting_tower_placed = true
			var start: Vector2 = gs.path[0]
			var nxt: Vector2 = gs.path[1]
			var dir: Vector2 = (nxt - start).normalized()
			var perp := Vector2(-dir.y, dir.x)
			for off in [56.0, 80.0, 110.0]:
				var placed := false
				for side in [1.0, -1.0]:
					var p: Vector2 = start + dir * 30.0 + perp * off * side
					if gs.can_place_tower(p, "archer")[0]:
						var t := gs._configure_tower(Tower.new(p, "archer", gs.tower_id_counter))
						gs.tower_id_counter += 1
						gs.towers.append(t)
						gs.stat_tower_use_by_type["archer"] += 1
						placed = true
						break
				if placed:
					break

		if gs.wave_shop_pending:
			var offers: Array = gs.get_wave_shop_offers()
			if not offers.is_empty():
				gs.apply_action({"type": "wave_shop_pick",
					"card_id": str(offers[0].get("id", ""))}, gs.sim_now())
			else:
				gs.apply_action({"type": "wave_shop_skip"}, gs.sim_now())

		if gs.sim_now() >= next_decision:
			next_decision = gs.sim_now() + 900
			if gs.gold >= 90 and (drng.randf() > float(strategy["prefer_upgrade"])
					or gs.towers.is_empty()):
				var order: Array = strategy["buy_order"]
				var ttype: String = order[next_idx % order.size()]
				for p in spots:
					if gs.can_place_tower(p, ttype)[0]:
						if gs.apply_action({"type": "place_tower", "tower_type": ttype,
								"pos": p}, gs.sim_now()).get("success", false):
							next_idx += 1
						break
			elif not gs.towers.is_empty():
				var target: Tower = gs.towers[drng.randi_range(0, gs.towers.size() - 1)]
				gs.apply_action({"type": "upgrade_base", "tower_id": target.id}, gs.sim_now())
				gs.apply_action({"type": "upgrade_path", "tower_id": target.id,
					"path": strategy["upgrade_path"]}, gs.sim_now())

		if gs.wave_ready and gs.game_state == "playing":
			gs.start_wave()

		if gs.wave != last_wave:
			waves.append({
				"wave": last_wave,
				"gold_in": wave_start_gold,
				"gold_out": gs.gold,
				"lives": gs.lives,
				"towers": gs.towers.size(),
				"sim_ms": gs.sim_now() - wave_start_ms,
			})
			last_wave = gs.wave
			wave_start_gold = gs.gold
			wave_start_ms = gs.sim_now()

		gs.update_simulation(gs.wall_now() + TICK_MS)

	var result := {
		"outcome": gs.game_state,
		"wave": gs.wave,
		"waves": waves,
		"gold_end": gs.gold,
		"gold_earned": gs.stat_gold_earned,
		"lives": gs.lives,
		"kills": gs.stat_enemies_killed,
		"towers": gs.towers.size(),
	}
	gs.dispose()
	return result

func _probe(map_id: int, strategy_name: String, seed_value: int) -> void:
	var r := _play(map_id, strategy_name, seed_value)
	var label := "%s seed=%d" % [strategy_name, seed_value]
	print("\n== %s | %s | wave %d | cleared %d | gold_end %d | earned %d | lives %d =="
		% [label, r["outcome"], r["wave"], r["waves"].size(), r["gold_end"],
		   r["gold_earned"], r["lives"]])
	print("   wave | gold_in -> gold_out | lives | towers | sim_s")
	for w in r["waves"]:
		print("   %4d | %6d -> %6d | %5d | %6d | %.1f"
			% [w["wave"], w["gold_in"], w["gold_out"], w["lives"],
			   w["towers"], float(w["sim_ms"]) / 1000.0])
	# Sanity: the numbers must be finite and internally consistent. This is a
	# measurement probe, so the assertions check the measurement, not the balance.
	_check(int(r["gold_end"]) >= 0, "%s: ending credits are non-negative" % label)
	_check(int(r["gold_earned"]) > 0, "%s: run actually earned credits" % label)
	_check(r["waves"].size() >= 1, "%s: at least one wave recorded" % label)
