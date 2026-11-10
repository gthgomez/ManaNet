extends SceneTree

# Speed-parity proof (Workstream B2).
#
# The whole point of the authoritative simulation clock is that choosing
# fast-forward must change how *fast wall time passes*, never what happens per
# unit of simulated combat. These fixtures run the same scenario at 1x / 2x / 3x
# with identical fixed seeds and compare final outcomes.
#
# Two comparison modes are used, and the distinction matters:
#
#   * Sim-clock equivalence (exact): feed the same simulation-elapsed time and
#     assert identical damage, kills, leaks, positions. Tolerance is 0 or
#     floating-point epsilon; any difference is a real timing bug.
#
#   * Wall-clock parity (bounded): run 1x for N wall ms and 2x/3x for N/k wall
#     ms. Results must agree within a documented tolerance that accounts for
#     discrete-tick quantization (an enemy crossing a waypoint on one tick, a
#     projectile landing one tick later). These differences are genuine and are
#     asserted as bounds, not hidden.
#
# Run: godot --headless --path . --script tests/simulation/speed_parity.gd

const GameStateScript := preload("res://simulation/core/GameState.gd")
const EnemyScript := preload("res://simulation/entities/Enemy.gd")
const TowerScript := preload("res://simulation/entities/Tower.gd")
const _MAPS := preload("res://data/maps.gd")

const SEED: int = 90210
## One wall-clock tick is 16 ms at ~60 fps. A speed multiplier advances the sim
## clock by 16*mult per tick, so equal *sim* time means fewer ticks at 3x.
const TICK_MS: int = 16

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("--- SPEED PARITY ---")
	_test_movement_is_sim_time_identical()
	_test_damage_and_kills_identical_per_sim_time()
	_test_status_durations_are_sim_time()
	_test_wall_clock_parity_bounded()
	_test_speed_change_mid_combat()
	_test_pause_does_not_advance_sim()
	_test_hitch_is_clamped_not_teleported()
	_test_tick_size_independence()
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

func _check_close(actual: float, expected: float, tol: float, message: String) -> void:
	var ok: bool = absf(actual - expected) <= tol
	if ok:
		_pass += 1
		print("[PASS] %s (got %.3f, expect %.3f +/- %.3f)" % [message, actual, expected, tol])
	else:
		_fail += 1
		push_error("[FAIL] %s (got %.3f, expect %.3f +/- %.3f)" % [message, actual, expected, tol])

func _straight_state(speed: float = 1.0) -> GameState:
	# Long straight corridor: no waypoint snapping inside the test window, so
	# movement comparisons isolate the clock rather than path geometry.
	var gs := GameStateScript.new([Vector2(0, 300), Vector2(4000, 300)], {}, 0)
	gs.speed_multiplier = speed
	gs.wave_ready = false
	gs.next_spawn_ms = 999999999
	gs.wave_enemy_total = 0
	return gs

func _real_state(speed: float) -> GameState:
	# rng_seed makes the enemy composition identical across speeds; otherwise
	# randomize() would hand each run a different wave and the comparison would
	# be meaningless.
	var gs := GameStateScript.new(_MAPS.MAPS[0]["path"], {"rng_seed": SEED}, 0)
	gs.speed_multiplier = speed
	return gs

## Advance a state by `sim_ms` of *simulation* time using 16 ms wall ticks.
## At 3x this takes a third as many ticks, exactly like real fast-forward.
## Returns the simulation time actually advanced, because a 16 ms wall tick at
## 2x advances 32 sim ms and integer tick counts cannot hit every target
## exactly. Callers compare *rates* against this value rather than assuming the
## requested duration was reached.
func _advance_sim_time(gs: GameState, sim_ms: int) -> int:
	var start: int = gs.sim_now()
	var ticks: int = int(ceil(float(sim_ms) / (float(TICK_MS) * gs.speed_multiplier)))
	for i in range(ticks):
		gs.update_simulation(gs.wall_now() + TICK_MS)
	return gs.sim_now() - start

## Advance by a fixed amount of *wall* time (used for the wall-parity check).
func _advance_wall_time(gs: GameState, wall_ms: int) -> void:
	var ticks: int = int(ceil(float(wall_ms) / float(TICK_MS)))
	for i in range(ticks):
		gs.update_simulation(gs.wall_now() + TICK_MS)

# ---------------------------------------------------------------------------
# Exact sim-time equivalence
# ---------------------------------------------------------------------------

func _test_movement_is_sim_time_identical() -> void:
	# Compare distance travelled per unit of *actual* simulated time. Tick counts
	# differ by speed (a 16 ms wall tick is 48 sim ms at 3x), so rates — not raw
	# distances — are the meaningful invariant.
	var rates: Dictionary = {}
	var distances: Dictionary = {}
	for mult in [1.0, 2.0, 3.0]:
		var gs := _straight_state(mult)
		var enemy := EnemyScript.new(gs.path)
		gs.enemies.append(enemy)
		var elapsed: int = _advance_sim_time(gs, 1000)
		distances[mult] = enemy.pos.x
		rates[mult] = enemy.pos.x / float(elapsed)
		gs.dispose()
	_check(distances[1.0] > 100.0, "enemy actually moves over one sim-second")
	_check_close(rates[2.0], rates[1.0], 0.0005,
		"2x travels the same distance per sim-ms as 1x")
	_check_close(rates[3.0], rates[1.0], 0.0005,
		"3x travels the same distance per sim-ms as 1x")

func _make_combat_state(speed: float) -> GameState:
	var gs := _real_state(speed)
	# Deterministic, fully-specified combat: one archer, one fixed-health enemy
	# walking a straight corridor, pinned so nothing depends on spawn RNG.
	gs.path = [Vector2(0, 300), Vector2(4000, 300)]
	gs.wave_ready = false
	gs.wave_shop_pending = false
	gs.enemies_spawned = 0
	gs.wave_enemy_total = 0
	gs.next_spawn_ms = 999999999
	var tower := TowerScript.new(Vector2(200, 300), "archer", 1)
	tower.game_state = gs
	gs.towers.append(tower)
	var enemy := EnemyScript.new(gs.path)
	enemy.pos = Vector2(260, 300)
	enemy.speed = 0.0            # stationary target: isolate damage, not movement
	enemy.health = 5000
	enemy.max_health = 5000
	enemy.reward = 10
	gs.enemies.append(enemy)
	return gs

func _test_damage_and_kills_identical_per_sim_time() -> void:
	var results: Dictionary = {}
	for mult in [1.0, 2.0, 3.0]:
		var gs := _make_combat_state(mult)
		var start_hp: int = gs.enemies[0].health
		_advance_sim_time(gs, 3000)
		results[mult] = {
			"damage": start_hp - gs.enemies[0].health,
			"kills": gs.stat_enemies_killed,
			"gold": gs.gold,
			"shots": gs.towers[0].last_shot_ms,
		}
		gs.dispose()
	_check(int(results[1.0]["damage"]) > 0, "combat deals damage over sim time")
	_check(int(results[2.0]["damage"]) == int(results[1.0]["damage"]),
		"total damage per sim-second is identical at 2x (%d vs %d)"
			% [results[2.0]["damage"], results[1.0]["damage"]])
	_check(int(results[3.0]["damage"]) == int(results[1.0]["damage"]),
		"total damage per sim-second is identical at 3x (%d vs %d)"
			% [results[3.0]["damage"], results[1.0]["damage"]])
	_check(int(results[2.0]["gold"]) == int(results[1.0]["gold"]),
		"credits earned per sim-second are identical at 2x")

func _test_status_durations_are_sim_time() -> void:
	# Two separate claims, tested exactly:
	#  (a) a chill expires at exactly start+1000 on the sim clock (a pure
	#      function of the timestamp, so no tick quantization enters);
	#  (b) while chilled, the slowed movement *rate* per sim-ms is identical at
	#      every speed.
	var probe := _straight_state(1.0)
	var enemy := EnemyScript.new(probe.path)
	enemy.speed = 2.0
	var t0 := 5000
	enemy.chilled_until = t0 + 1000
	_check_close(enemy.current_speed(t0 + 999), 1.2, 0.0001,
		"chill still applies 1 sim-ms before expiry (60% speed)")
	_check_close(enemy.current_speed(t0 + 1000), 2.0, 0.0001,
		"chill expires exactly at its sim-clock deadline")
	probe.dispose()

	var rates: Dictionary = {}
	for mult in [1.0, 2.0, 3.0]:
		var gs := _straight_state(mult)
		var e := EnemyScript.new(gs.path)
		e.pos = Vector2(0, 300)
		gs.enemies.append(e)
		gs.update_simulation(TICK_MS)              # prime the clock
		e.chilled_until = gs.sim_now() + 1000000  # chilled for the whole window
		var start_x: float = e.pos.x
		var elapsed: int = _advance_sim_time(gs, 1000)
		rates[mult] = (e.pos.x - start_x) / float(elapsed)
		gs.dispose()
	_check_close(rates[2.0], rates[1.0], 0.0005,
		"chilled movement rate per sim-ms is identical at 2x")
	_check_close(rates[3.0], rates[1.0], 0.0005,
		"chilled movement rate per sim-ms is identical at 3x")

# ---------------------------------------------------------------------------
# Wall-clock parity (bounded) — the player-visible question
# ---------------------------------------------------------------------------

func _run_to_sim_time(speed: float, target_sim_ms: int) -> Dictionary:
	# Advance until the *simulation* clock reaches an exact target. This is the
	# precise parity contract: at equal simulated time, every mechanical outcome
	# must match. Wall-clock only determines how long that takes to arrive.
	var gs := _real_state(speed)
	gs.wave = 3
	gs.wave_enemy_total = 400
	gs.lives = 1_000_000
	gs.start_wave()
	var guard: int = 0
	while gs.sim_now() < target_sim_ms and guard < 1_000_000:
		var before: int = gs.sim_now()
		gs.update_simulation(gs.wall_now() + TICK_MS)
		guard += 1
		if gs.sim_now() == before:
			break  # stalled (paused/gated) — stop rather than spin
	var snapshot := {
		"kills":       gs.stat_enemies_killed,
		"leaks":       1_000_000 - gs.lives,
		"gold":        gs.gold,
		"sim_elapsed": gs.sim_now(),
		"spawned":     gs.enemies_spawned,
		"alive":       gs.enemies.size(),
	}
	gs.dispose()
	return snapshot

func _run_wall_budget(speed: float, wall_budget_ms: int) -> int:
	# Wall budget only measures the *rate* at which sim time accrues.
	var gs := _real_state(speed)
	gs.wave = 3
	gs.wave_enemy_total = 400
	gs.lives = 1_000_000
	gs.start_wave()
	_advance_wall_time(gs, wall_budget_ms)
	var elapsed: int = gs.sim_now()
	gs.dispose()
	return elapsed

func _test_wall_clock_parity_bounded() -> void:
	# Two distinct, honest claims:
	#
	#  1. At equal SIMULATED time the mechanics are identical. This is the real
	#     parity contract and is asserted exactly.
	#  2. Wall time to reach that sim time compresses by the speed multiplier.
	#     This can only be asserted as a rate (integer ticks never land on the
	#     same sim instant), so it gets a small tolerance.
	var target_sim: int = 12000
	var slow := _run_to_sim_time(1.0, target_sim)
	var mid := _run_to_sim_time(2.0, target_sim)
	var fast := _run_to_sim_time(3.0, target_sim)

	_check(int(slow["sim_elapsed"]) == int(mid["sim_elapsed"]),
		"1x and 2x stop at the same sim time (%d vs %d)"
			% [slow["sim_elapsed"], mid["sim_elapsed"]])
	_check(int(slow["sim_elapsed"]) == int(fast["sim_elapsed"]),
		"1x and 3x stop at the same sim time (%d vs %d)"
			% [slow["sim_elapsed"], fast["sim_elapsed"]])
	_check(int(mid["spawned"]) == int(slow["spawned"]),
		"2x spawns the same number of enemies at equal sim time (%d vs %d)"
			% [mid["spawned"], slow["spawned"]])
	_check(int(fast["spawned"]) == int(slow["spawned"]),
		"3x spawns the same number of enemies at equal sim time (%d vs %d)"
			% [fast["spawned"], slow["spawned"]])
	_check(int(mid["kills"]) == int(slow["kills"]),
		"2x kills the same enemies at equal sim time (%d vs %d)"
			% [mid["kills"], slow["kills"]])
	_check(int(fast["kills"]) == int(slow["kills"]),
		"3x kills the same enemies at equal sim time (%d vs %d)"
			% [fast["kills"], slow["kills"]])
	_check(int(mid["leaks"]) == int(slow["leaks"]),
		"2x leaks the same enemies at equal sim time (%d vs %d)"
			% [mid["leaks"], slow["leaks"]])
	_check(int(fast["leaks"]) == int(slow["leaks"]),
		"3x leaks the same enemies at equal sim time (%d vs %d)"
			% [fast["leaks"], slow["leaks"]])

	# Rate check: sim-ms accrued per wall-ms over a fixed wall budget.
	var base_wall: int = 24000
	var slow_rate: float = float(_run_wall_budget(1.0, base_wall)) / float(base_wall)
	var mid_rate: float = float(_run_wall_budget(2.0, base_wall)) / float(base_wall)
	var fast_rate: float = float(_run_wall_budget(3.0, base_wall)) / float(base_wall)
	_check(mid_rate > slow_rate * 1.8 and mid_rate < slow_rate * 2.2,
		"2x accrues sim time at roughly twice the wall rate (%.2f vs %.2f)"
			% [mid_rate, slow_rate])
	_check(fast_rate > slow_rate * 2.7 and fast_rate < slow_rate * 3.3,
		"3x accrues sim time at roughly three times the wall rate (%.2f vs %.2f)"
			% [fast_rate, slow_rate])

func _test_speed_change_mid_combat() -> void:
	# Switching speed mid-wave must behave like advancing at the new rate from
	# that moment — no jump, no lost or doubled time.
	var gs := _make_combat_state(1.0)
	var start_hp: int = gs.enemies[0].health
	_advance_sim_time(gs, 1000)
	var hp_at_switch: int = gs.enemies[0].health
	gs.set_speed(3.0)
	var sim_at_switch: int = gs.sim_now()
	_advance_sim_time(gs, 2000)
	var sim_moved: int = gs.sim_now() - sim_at_switch
	_check(hp_at_switch < start_hp, "damage accrues before the speed change")
	_check(absf(float(sim_moved) - 2000.0) <= float(TICK_MS) * 3.0,
		"post-switch sim time advances 2000 ms (got %d)" % sim_moved)
	_check(gs.enemies[0].health < hp_at_switch, "damage continues after the speed change")
	gs.dispose()

	# Switching back to 1x must also be clean.
	var gs2 := _make_combat_state(3.0)
	_advance_sim_time(gs2, 1000)
	gs2.set_speed(1.0)
	var before_sim: int = gs2.sim_now()
	_advance_sim_time(gs2, 1000)
	_check(absf(float(gs2.sim_now() - before_sim) - 1000.0) <= float(TICK_MS) * 2.0,
		"3x -> 1x switch still advances exactly 1000 sim ms")
	gs2.dispose()

func _test_pause_does_not_advance_sim() -> void:
	var gs := _make_combat_state(3.0)
	_advance_sim_time(gs, 500)
	var sim_before: int = gs.sim_now()
	var hp_before: int = gs.enemies[0].health
	gs.toggle_pause()
	_check(gs.paused, "toggle_pause pauses the run")
	_advance_wall_time(gs, 5000)
	_check(gs.sim_now() == sim_before,
		"paused run does not advance the simulation clock (got %d vs %d)"
			% [gs.sim_now(), sim_before])
	_check(gs.enemies[0].health == hp_before, "paused run deals no damage")
	gs.toggle_pause()
	_advance_sim_time(gs, 500)
	_check(gs.sim_now() > sim_before, "simulation resumes after unpause")
	gs.dispose()

func _test_hitch_is_clamped_not_teleported() -> void:
	var gs := _straight_state(1.0)
	var enemy := EnemyScript.new(gs.path)
	gs.enemies.append(enemy)
	gs.update_simulation(1000)
	var before := enemy.pos
	gs.update_simulation(60000)   # 59 s stall in one tick
	var moved: float = before.distance_to(enemy.pos)
	var max_step: float = 2.0 * gs.MAX_SIM_STEP_MS / gs.SIM_REFERENCE_FRAME_MS + 0.5
	_check(moved > 0.0 and moved <= max_step,
		"a 59 s stall advances at most one clamped step (%.2f <= %.2f)" % [moved, max_step])
	gs.dispose()

func _test_tick_size_independence() -> void:
	# Same simulated duration driven at 8 ms and 32 ms ticks must agree.
	var results: Dictionary = {}
	for dt in [8, 32]:
		var gs := _straight_state(1.0)
		var enemy := EnemyScript.new(gs.path)
		gs.enemies.append(enemy)
		gs.update_simulation(dt)
		var start := enemy.pos.x
		var ticks: int = int(1000.0 / float(dt))
		for i in range(1, ticks + 1):
			gs.update_simulation(dt + i * dt)
		results[dt] = enemy.pos.x - start
		gs.dispose()
	_check_close(results[8], results[32], 1.0,
		"1 sim-second of travel matches between 8 ms and 32 ms ticks")
