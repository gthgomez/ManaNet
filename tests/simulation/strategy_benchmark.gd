extends SceneTree

# Strategy-baseline measurement (Workstream D2/E).
#
# Plays full runs with a *competent* build policy: candidates are scored by how
# much of the path a tower actually covers, buys follow a plan, and the bot
# upgrades before buying more. It prints an outcome distribution and, for wins,
# the late-game credit balance — the specific "unused credits at the end" claim
# this project needed evidence for.
#
# This is a measurement tool. It asserts only that the harness itself produced
# sane, finite data (so a broken run cannot masquerade as a balance finding).
#
# Run: godot --headless --path . --script tests/simulation/strategy_benchmark.gd

const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")
const _TT := preload("res://data/tower_types.gd")

const TICK_MS: int = 16
const MAX_TICKS: int = 400_000

const BUILD_ORDERS: Dictionary = {
	"archer_focus":   ["archer", "archer", "archer", "archer", "frost", "archer", "archer"],
	"mage_focus":     ["mage", "mage", "frost", "mage", "mage", "archer", "mage"],
	"cannon_focus":   ["cannon", "cannon", "archer", "cannon", "frost", "cannon"],
	"mixed_balanced": ["archer", "archer", "frost", "mage", "archer", "cannon", "sniper",
					   "frost", "mage", "lightning"],
	"economy_first":  ["archer", "archer", "archer", "frost", "archer", "sniper", "mage"],
}

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("--- STRATEGY BASELINE ---")
	var results: Array = []
	for strategy in BUILD_ORDERS.keys():
		for map_id in [0, 1, 2]:
			for seed_value in [4242, 1002]:
				results.append(_play(strategy, map_id, seed_value))
	_report(results)
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	quit(1 if _fail > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % msg)
	else:
		_fail += 1
		push_error("[FAIL] %s" % msg)

# ---------------------------------------------------------------------------
# Placement scoring: maximise path coverage, not proximity to a single point.
# ---------------------------------------------------------------------------

func _path_samples(path: Array) -> Array:
	var out: Array = []
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var length: float = a.distance_to(b)
		if length <= 0.0:
			continue
		var steps: int = maxi(1, int(ceil(length / 16.0)))
		for s in range(steps):
			out.append(a.lerp(b, float(s) / float(steps)))
	return out

func _candidates(path: Array) -> Array:
	var out: Array = []
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg: Vector2 = b - a
		var length: float = seg.length()
		if length <= 0.0:
			continue
		var dir: Vector2 = seg / length
		var normal := Vector2(-dir.y, dir.x)
		var steps: int = maxi(2, int(ceil(length / 24.0)))
		for s in range(steps + 1):
			var anchor: Vector2 = a.lerp(b, float(s) / float(steps))
			for offset in [44.0, 60.0, 76.0, 96.0]:
				for side in [-1.0, 1.0]:
					var p: Vector2 = anchor + normal * offset * side
					if p.x < 25 or p.x > 875 or p.y < 25 or p.y > 465:
						continue
					out.append(p)
	return out

func _best_position(gs: GameState, samples: Array, ttype: String) -> Vector2:
	var tower_range: float = float(_TT.TOWER_TYPES[ttype]["range"])
	var best := Vector2(-1, -1)
	var best_score := -1.0
	for p in _candidates(gs.path):
		if not gs.can_place_tower(p, ttype)[0]:
			continue
		var covered: int = 0
		for sample in samples:
			if p.distance_to(sample) <= tower_range:
				covered += 1
		if float(covered) > best_score:
			best_score = float(covered)
			best = p
	return best

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

func _play(strategy_name: String, map_id: int, seed_value: int) -> Dictionary:
	var map_data: Dictionary = _MAPS.MAPS[map_id]
	var gs := GameStateScript.new(map_data["path"], {"rng_seed": seed_value}, map_id)
	var samples: Array = _path_samples(map_data["path"])
	var order: Array = BUILD_ORDERS[strategy_name]
	var buy_index: int = 0
	var now: int = 0
	var ticks: int = 0
	var waves: Array = []
	var last_wave: int = gs.wave
	var wave_gold: int = gs.gold

	while gs.game_state == "playing" and ticks < MAX_TICKS:
		if gs.wave != last_wave:
			waves.append({"w": last_wave, "gold": wave_gold, "lives": gs.lives,
				"towers": gs.towers.size()})
			last_wave = gs.wave
			wave_gold = gs.gold
		if gs.wave_shop_pending:
			var offers: Array = gs.get_wave_shop_offers()
			if not offers.is_empty():
				gs.apply_action({"type": "wave_shop_pick", "card_id": str(offers[0]["id"])}, now)
			else:
				gs.apply_action({"type": "wave_shop_skip"}, now)
		if gs.wave_ready:
			_build(gs, samples, order, buy_index, now)
			# _build mutates the index implicitly by placing towers; re-derive it.
			buy_index = mini(gs.towers.size(), order.size())
			gs.start_wave()
		now += TICK_MS
		gs.update_simulation(now)
		ticks += 1

	var result := {
		"strategy": strategy_name,
		"map": map_data["name"],
		"map_id": map_id,
		"seed": seed_value,
		"state": gs.game_state,
		"cleared": gs.stat_waves_survived,
		"lives": gs.lives,
		"gold": gs.gold,
		"earned": gs.stat_gold_earned,
		"towers": gs.towers.size(),
		"kills": gs.stat_enemies_killed,
		"waves": waves,
	}
	gs.dispose()
	return result

func _build(gs: GameState, samples: Array, order: Array, _buy_index: int, now: int) -> void:
	# Spend the wave's income: upgrade what exists, then extend the plan.
	var progressed := true
	var guard: int = 0
	while progressed and guard < 80:
		guard += 1
		progressed = false
		if gs.towers.size() >= 6:
			for t in gs.towers:
				if t.base_upgrade_cost() >= 0 and gs.gold >= t.base_upgrade_cost() and t.level < 5:
					if gs.apply_action({"type": "upgrade_base", "tower_id": t.id}, now).get("success", false):
						progressed = true
						break
			if progressed:
				continue
			for t in gs.towers:
				for pk in ["Top", "Middle", "Bottom"]:
					if t.tracker.can_attempt_upgrade(pk) and gs.gold >= t.path_upgrade_cost(pk):
						var r: Dictionary = gs.apply_action(
							{"type": "upgrade_path", "tower_id": t.id, "path": pk}, now)
						if r.get("success", false):
							if r.get("preview_promotion", false):
								gs.apply_action({"type": "confirm_promotion", "tower_id": t.id}, now)
							progressed = true
							break
				if progressed:
					break
			if progressed:
				continue
		if gs.towers.size() < order.size():
			var ttype: String = order[gs.towers.size()]
			var cost: int = _TT.TOWER_TYPES[ttype]["cost"]
			if gs.gold >= cost:
				var p := _best_position(gs, samples, ttype)
				if p.x >= 0:
					if gs.apply_action({"type": "place_tower", "tower_type": ttype, "pos": p}, now).get("success", false):
						progressed = true

func _report(results: Array) -> void:
	print("\n%-15s %-9s %6s %5s %7s %7s %7s %6s" % [
		"strategy", "map", "seed", "clear", "lives", "towers", "gold_end", "outcome"])
	var wins: int = 0
	var late_gold: Array = []
	for r in results:
		print("%-15s %-9s %6d %5d %7d %7d %7d %6s" % [
			r["strategy"], r["map"], r["seed"], r["cleared"], r["lives"],
			r["towers"], r["gold"], r["state"]])
		if r["state"] == "won":
			wins += 1
			late_gold.append(int(r["gold"]))
			for w in r["waves"]:
				print("    wave %2d: gold_in=%5d lives=%2d towers=%2d"
					% [w["w"], w["gold"], w["lives"], w["towers"]])
	var rate: float = float(wins) / float(maxi(1, results.size())) * 100.0
	print("\nWins: %d/%d (%.0f%%)" % [wins, results.size(), rate])
	if not late_gold.is_empty():
		var total: int = 0
		for g in late_gold:
			total += g
		print("Winning-run ending credits: min=%d max=%d avg=%d"
			% [late_gold.min(), late_gold.max(), int(total / late_gold.size())])
	_check(results.size() > 0, "benchmark produced results")
	_check(wins > 0, "at least one strategy/map/seed reaches victory (%d/%d)" % [wins, results.size()])
	var all_terminal: bool = true
	for r in results:
		if not r["state"] in ["won", "game_over"]:
			all_terminal = false
	_check(all_terminal, "every measured run reached a terminal state (no timeouts)")
