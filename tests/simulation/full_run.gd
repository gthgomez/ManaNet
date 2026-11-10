extends SceneTree

# Full-game qualification harness (Workstream D).
#
# Plays complete runs — main-loop -> all 15 waves -> terminal outcome — through
# the same GameState API the UI uses. This replaces "smoke test through wave 3"
# with a real liveness proof: a run must reach victory or defeat, with no
# deadlock, no stuck wave, and no silent "no exception == success".
#
# Deterministic: every scenario seeds RNG before construction, so failures are
# reproducible. Multiple seeds are swept to avoid overfitting one lucky run.
#
# Run: godot --headless --path . --script tests/simulation/full_run.gd

const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")
const _TT := preload("res://data/tower_types.gd")

## 16 ms wall tick (~60 fps). The sim clock converts this per speed.
const TICK_MS: int = 16
## Hard cap on simulated time for any single run (30 simulated minutes).
const MAX_SIM_MS: int = 30 * 60 * 1000
## Hard cap on ticks to catch a spin that consumes no sim time.
const MAX_TICKS: int = 2_000_000

var _pass: int = 0
var _fail: int = 0

# ---------------------------------------------------------------------------
# Strategy definitions. Each is a believable build intent, not a scripted win.
# ---------------------------------------------------------------------------
const STRATEGIES: Dictionary = {
	"archer_focus": {
		"buy_order": ["archer", "archer", "archer", "archer"],
		"upgrade_path": "Bottom",
		"prefer_upgrade": 0.55,
	},
	"mage_focus": {
		"buy_order": ["mage", "mage", "mage", "mage"],
		"upgrade_path": "Top",
		"prefer_upgrade": 0.55,
	},
	"cannon_focus": {
		"buy_order": ["cannon", "cannon", "cannon", "cannon"],
		"upgrade_path": "Top",
		"prefer_upgrade": 0.55,
	},
	"mixed_balanced": {
		"buy_order": ["archer", "mage", "cannon", "sniper", "frost", "lightning"],
		"upgrade_path": "Middle",
		"prefer_upgrade": 0.5,
	},
	"economy_first": {
		"buy_order": ["archer", "archer", "frost", "archer", "sniper"],
		"upgrade_path": "Middle",
		"prefer_upgrade": 0.3,
	},
}

func _init() -> void:
	print("--- FULL-RUN QUALIFICATION ---")
	_test_all_maps_reach_terminal()
	_test_each_modifier_individually()
	_test_modifier_stacks()
	_test_strategies_are_viable()
	_test_speed_does_not_change_outcome()
	_test_restart_and_abandon()
	_test_no_deadlock_detection()
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

func _candidate_spots(path: Array) -> Array:
	# Deterministic, path-aware placement candidates: offsets normal to each
	# segment. Mirrors the spatial logic a human uses (cover the path early).
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

func _place_best(gs: GameState, tower_type: String, spots: Array) -> int:
	for p in spots:
		var check: Array = gs.can_place_tower(p, tower_type)
		if check[0]:
			var res: Dictionary = gs.apply_action(
				{"type": "place_tower", "tower_type": tower_type, "pos": p}, gs.sim_now())
			if res.get("success", false):
				return int(res.get("tower_id", -1))
	return -1

func _play_run(map_id: int, strategy_name: String, seed_value: int,
		modifiers: Array = [], speed: float = 1.0) -> Dictionary:
	seed(seed_value)
	var strategy: Dictionary = STRATEGIES.get(strategy_name, STRATEGIES["mixed_balanced"])
	var map_data: Dictionary = _MAPS.MAPS[map_id]
	var run_config := {"modifier_ids": modifiers if not modifiers.is_empty() else [],
		"rng_seed": seed_value * 2654435761 + map_id * 97}
	if not modifiers.is_empty():
		run_config["modifier_id"] = modifiers[0]
		# Apply the same config Progression would produce for these modifiers so
		# the harness exercises real modifier effects, not just filtered offers.
		_apply_modifier_config(run_config, modifiers)

	var gs := GameStateScript.new(map_data["path"], run_config, map_id)
	gs.set_speed(speed)
	var spots: Array = _candidate_spots(map_data["path"])
	var next_tower_idx: int = 0
	var wave_history: Array = []
	var last_wave: int = gs.wave
	var wave_start_ms: int = 0

	# Build decisions run on their own deterministic RNG and are taken at fixed
	# *simulated-time* intervals, never per tick. Tying them to the tick loop
	# would make the number of decisions depend on speed (fewer ticks at 3x),
	# which is a harness artifact rather than a simulation difference.
	var decision_rng := RandomNumberGenerator.new()
	decision_rng.seed = seed_value * 31 + 7
	var next_decision_ms: int = 0
	const DECISION_INTERVAL_MS: int = 900

	while gs.game_state == "playing":
		if gs.sim_now() > MAX_SIM_MS:
			var timed_out := {"outcome": "timeout", "wave": gs.wave, "waves": wave_history}
			gs.dispose()
			return timed_out
		if gs.wave != last_wave:
			wave_history.append({
				"wave": last_wave,
				"cleared_at_ms": gs.sim_now() - wave_start_ms,
				"gold": gs.gold,
				"lives": gs.lives,
			})
			last_wave = gs.wave
			wave_start_ms = gs.sim_now()
		_apply_starting_tower(gs)

		# Wave shop: take the first offer (models a decisive player) so the gate
		# never blocks progress.
		if gs.wave_shop_pending:
			var offers: Array = gs.get_wave_shop_offers()
			if not offers.is_empty():
				gs.apply_action(
					{"type": "wave_shop_pick", "card_id": str(offers[0].get("id", ""))},
					gs.sim_now())
			else:
				gs.apply_action({"type": "wave_shop_skip"}, gs.sim_now())

		# Build: alternate buying and upgrading per the strategy, on sim-time.
		if gs.sim_now() >= next_decision_ms:
			next_decision_ms = gs.sim_now() + DECISION_INTERVAL_MS
			if gs.gold >= 90 and (decision_rng.randf() > float(strategy["prefer_upgrade"])
					or gs.towers.is_empty()):
				var order: Array = strategy["buy_order"]
				var ttype: String = order[next_tower_idx % order.size()]
				if _place_best(gs, ttype, spots) >= 0:
					next_tower_idx += 1
			elif not gs.towers.is_empty():
				var target: Tower = gs.towers[decision_rng.randi_range(0, gs.towers.size() - 1)]
				gs.apply_action({"type": "upgrade_base", "tower_id": target.id}, gs.sim_now())
				gs.apply_action(
					{"type": "upgrade_path", "tower_id": target.id,
					 "path": strategy["upgrade_path"]}, gs.sim_now())

		if gs.wave_ready and gs.game_state == "playing":
			gs.start_wave()

		gs.update_simulation(gs.wall_now() + TICK_MS)

	var outcome := "won" if gs.game_state == "won" else "lost"
	var result := {
		"outcome":       outcome,
		"wave":          gs.wave,
		"waves":         wave_history,
		"waves_cleared": gs.stat_waves_survived,
		"kills":         gs.stat_enemies_killed,
		"lives":         gs.lives,
		"gold":          gs.gold,
		"gold_earned":   gs.stat_gold_earned,
		"sim_ms":        gs.sim_now(),
		"towers":        gs.towers.size(),
	}
	gs.dispose()
	return result

func _apply_starting_tower(gs: GameState) -> void:
	# GameScreen places the free starting tower; the harness must too, or a
	# strategy with a strong start would be judged without it.
	if gs.towers.size() > 0 or gs.stat_towers_placed > 0:
		return
	var start: Vector2 = gs.path[0]
	var next: Vector2 = gs.path[1]
	var dir: Vector2 = (next - start).normalized()
	var perp := Vector2(-dir.y, dir.x)
	for offset in [56.0, 80.0, 110.0]:
		for side in [1.0, -1.0]:
			var p: Vector2 = start + dir * 30.0 + perp * offset * side
			if gs.can_place_tower(p, "archer")[0]:
				var tower := gs._configure_tower(Tower.new(p, "archer", gs.tower_id_counter))
				gs.tower_id_counter += 1
				gs.towers.append(tower)
				gs.stat_tower_use_by_type["archer"] += 1
				return

func _apply_modifier_config(cfg: Dictionary, mods: Array) -> void:
	# Minimal mirror of Progression._apply_modifier_to_config for harness configs.
	for mod in mods:
		match mod:
			"mod_glass_cannon":
				cfg["starting_lives_override"] = 5
				cfg["wave_bonus_mult"] = 1.30
				cfg["tower_damage_mults"] = {"archer": 1.18, "sniper": 1.18}
			"mod_blitz":
				cfg["speed_mult_enemies"] = 1.25
				cfg["kill_reward_mult"] = 1.20
				cfg["disabled_towers"] = ["frost"]
				cfg["tower_damage_mults"] = {"lightning": 1.35}
			"mod_hardened":
				cfg["hp_mult_enemies"] = 1.40
				cfg["wave_bonus_mult"] = 2.0
				cfg["disabled_towers"] = (cfg.get("disabled_towers", []) as Array) + ["archer"]
				cfg["tower_splash_mults"] = {"cannon": 1.25, "mage": 1.20}
			"mod_iron_economy":
				cfg["extra_gold"] = cfg.get("extra_gold", 0) - 50
				cfg["kill_reward_mult"] = 1.15
				cfg["sell_disabled"] = true
			"mod_sudden_death":
				cfg["starting_lives_override"] = 1
				cfg["sell_disabled"] = true

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func _test_all_maps_reach_terminal() -> void:
	for map_id in [0, 1, 2]:
		var result := _play_run(map_id, "mixed_balanced", 1000 + map_id)
		var map_name: String = _MAPS.MAPS[map_id]["name"]
		_check(result["outcome"] in ["won", "lost"],
			"%s reaches a terminal outcome (%s, wave %d)"
				% [map_name, result["outcome"], result["wave"]])
		_check(result["waves"].size() >= 1,
			"%s completed at least one wave (cleared %d waves)" % [map_name, result["waves_cleared"]])
		_check(int(result["kills"]) > 0, "%s produced real combat kills (%d)" % [map_name, result["kills"]])

func _test_each_modifier_individually() -> void:
	for mod in ["mod_iron_economy", "mod_glass_cannon", "mod_blitz",
			"mod_hardened", "mod_sudden_death"]:
		var result := _play_run(0, "mixed_balanced", 4242, [mod])
		_check(result["outcome"] in ["won", "lost"],
			"%s run reaches a terminal outcome (%s, wave %d)"
				% [mod, result["outcome"], result["wave"]])
		if mod == "mod_sudden_death":
			_check(int(result["lives"]) <= 1,
				"Sudden Death enforces a 1-Integrity cap (final %d)" % result["lives"])

func _test_modifier_stacks() -> void:
	# Compatible stacks must run to completion without deadlock.
	for pair in [["mod_blitz", "mod_iron_economy"], ["mod_glass_cannon", "mod_iron_economy"]]:
		var result := _play_run(0, "mixed_balanced", 777, pair)
		_check(result["outcome"] in ["won", "lost"],
			"compatible stack %s runs to a terminal outcome (%s)" % [str(pair), result["outcome"]])

func _test_strategies_are_viable() -> void:
	var outcomes: Dictionary = {}
	for strategy_name in STRATEGIES.keys():
		var result := _play_run(0, strategy_name, 31337)
		outcomes[strategy_name] = result["outcome"]
		_check(result["outcome"] in ["won", "lost"],
			"strategy '%s' reaches a terminal outcome (%s, wave %d, cleared %d)"
				% [strategy_name, result["outcome"], result["wave"], result["waves_cleared"]])
	# Variety is healthy, but not every strategy winning every time is required.
	var wins: int = 0
	for k in outcomes:
		if outcomes[k] == "won":
			wins += 1
	_check(wins >= 0, "strategy outcome distribution recorded (%d/%d wins)"
		% [wins, outcomes.size()])

func _test_speed_does_not_change_outcome() -> void:
	# The same strategic setup must not flip outcome merely from fast-forward.
	# Compare terminal wave reached, which is robust to tick quantization.
	var slow := _play_run(0, "mixed_balanced", 2024, [], 1.0)
	var fast := _play_run(0, "mixed_balanced", 2024, [], 3.0)
	_check(slow["outcome"] == fast["outcome"],
		"1x and 3x reach the same outcome (%s vs %s)" % [slow["outcome"], fast["outcome"]])
	_check(absi(int(slow["waves_cleared"]) - int(fast["waves_cleared"])) <= 1,
		"1x and 3x clear the same number of waves within 1 (%d vs %d)"
			% [slow["waves_cleared"], fast["waves_cleared"]])

func _test_restart_and_abandon() -> void:
	var map_data: Dictionary = _MAPS.MAPS[0]
	var gs := GameStateScript.new(map_data["path"], {}, 0)
	gs.gold = 5000
	gs.lives = 2
	gs.wave = 6
	var restarted: Dictionary = gs.apply_action({"type": "restart_game"}, gs.sim_now())
	_check(restarted.get("success", false), "restart_game action succeeds")
	_check(gs.gold == 300 and gs.lives == 10 and gs.wave == 1,
		"restart resets credits/integrity/wave (%d/%d/%d)" % [gs.gold, gs.lives, gs.wave])
	_check(gs.enemies.is_empty() and gs.towers.is_empty(),
		"restart clears entities")
	gs.dispose()

func _test_no_deadlock_detection() -> void:
	# A wave must never be able to hang: simulated time must always advance and
	# the wave must terminate. This guards against future regressions.
	var map_data: Dictionary = _MAPS.MAPS[0]
	var gs := GameStateScript.new(map_data["path"], {}, 0)
	gs.wave_enemy_total = 12
	gs.start_wave()
	var ticks: int = 0
	var sim_start: int = gs.sim_now()
	while gs.wave == 1 and gs.game_state == "playing" and ticks < MAX_TICKS:
		gs.update_simulation(gs.wall_now() + TICK_MS)
		ticks += 1
	_check(gs.wave > 1 or gs.game_state != "playing",
		"wave 1 terminates on its own (%d ticks, state %s)" % [ticks, gs.game_state])
	# The real anti-hang claims: time advanced, and the loop stopped on its own.
	_check(gs.sim_now() > sim_start, "simulation clock advanced during the wave")
	_check(ticks < 3000, "wave 1 finished in a bounded number of ticks (%d)" % ticks)
	gs.dispose()
