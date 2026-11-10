extends SceneTree

# Known-good 15-wave qualification.
#
# The bot is the economy-first policy from strategy_benchmark.gd: public
# GameState actions only (place, upgrade, confirm promotion, pick the offered
# card, start the wave). No free towers, no health edits, no disabled enemies.
# Seed 4242 is the reproducible run that cleared S-Curve, Gauntlet, and Spiral
# in the strategy benchmark (13/30 scenarios won overall; this policy won 6/6).
#
# Other policies in that benchmark lose, including every archer-focus run.
# Those losses are balance evidence, not a license to retune curves.

const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")
const _TT := preload("res://data/tower_types.gd")

const TICK_MS := 16
const MAX_TICKS := 400000
const QUAL_SEED := 4242
const ORDER := ["archer", "archer", "archer", "frost", "archer", "sniper", "mage"]

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("--- VICTORY QUALIFICATION ---")
	for map_id in [0, 1, 2]:
		var result := _play(map_id, QUAL_SEED)
		var name: String = _MAPS.MAPS[map_id]["name"]
		print("MAP %s seed=%s outcome=%s wave=%s cleared=%s lives=%s gold=%s towers=%s earned=%s spent=%s kills=%s"
			% [name, QUAL_SEED, result["outcome"], result["wave"], result["cleared"], result["lives"],
				result["gold"], result["towers"], result["earned"], result["spent"], result["kills"]])
		_check(result["outcome"] == "won",
			"%s economy-first legal bot clears the run (outcome %s, wave %s, lives %s)"
				% [name, result["outcome"], result["wave"], result["lives"]])
		_check(int(result["cleared"]) == 15, "%s records 15 survived waves (got %s)" % [name, result["cleared"]])
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

func _build(gs: GameState, samples: Array, now: int) -> void:
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
		if gs.towers.size() < ORDER.size():
			var ttype: String = ORDER[gs.towers.size()]
			if gs.gold >= int(_TT.TOWER_TYPES[ttype]["cost"]):
				var p := _best_position(gs, samples, ttype)
				if p.x >= 0 and gs.apply_action(
						{"type": "place_tower", "tower_type": ttype, "pos": p}, now).get("success", false):
					progressed = true

func _play(map_id: int, seed_value: int) -> Dictionary:
	var map_data: Dictionary = _MAPS.MAPS[map_id]
	var gs: GameState = GameStateScript.new(map_data["path"], {"rng_seed": seed_value}, map_id)
	var samples: Array = _path_samples(map_data["path"])
	var now: int = 0
	var ticks: int = 0
	while gs.game_state == "playing" and ticks < MAX_TICKS:
		if gs.wave_shop_pending:
			var offers: Array = gs.get_wave_shop_offers()
			if not offers.is_empty():
				gs.apply_action({"type": "wave_shop_pick", "card_id": str(offers[0]["id"])}, now)
			else:
				gs.apply_action({"type": "wave_shop_skip"}, now)
		if gs.wave_ready:
			_build(gs, samples, now)
			gs.apply_action({"type": "start_wave"}, now)
		now += TICK_MS
		gs.update_simulation(now)
		ticks += 1
	var spent: int = maxi(0, gs.stat_gold_earned - gs.gold)
	var result := {
		"outcome": "timeout" if gs.game_state == "playing" else ("won" if gs.game_state == "won" else "lost"),
		"wave": gs.wave,
		"cleared": gs.stat_waves_survived,
		"lives": gs.lives,
		"gold": gs.gold,
		"earned": gs.stat_gold_earned,
		"spent": spent,
		"towers": gs.towers.size(),
		"kills": gs.stat_enemies_killed,
	}
	gs.dispose()
	return result
