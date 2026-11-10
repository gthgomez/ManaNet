extends SceneTree

# Proves gameplay timestamps use the simulation clock even when the caller
# passes a wall-clock value (what GameScreen does today). A promotion stamped
# with wall time used to stay active for the rest of the run.

const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")

const BURST_MS := 6000
const WALL_STAMP := 50_000_000

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("--- CLOCK AUTHORITY ---")
	_test_promotion_ignores_wall_stamp()
	for speed in [1.0, 2.0, 3.0]:
		_test_burst_expires_on_sim_time(speed)
	_test_speed_change_mid_burst()
	_test_pause_does_not_advance()
	_test_hitch_is_clamped()
	_test_invalid_speeds_rejected()
	_test_restart_clears_clock()
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

func _fresh() -> GameState:
	return GameStateScript.new(_MAPS.MAPS[0]["path"], {"rng_seed": 11}, 0)

func _promote(gs: GameState, wall_ms: int) -> Tower:
	gs.gold = 100000
	var placed: Dictionary = gs.apply_action(
		{"type": "place_tower", "tower_type": "archer", "pos": Vector2(300, 240)}, wall_ms)
	var tower_id: int = int(placed.get("tower_id", -1))
	gs.apply_action({"type": "upgrade_path", "tower_id": tower_id, "path": "Top"}, wall_ms)
	var preview: Dictionary = gs.apply_action(
		{"type": "upgrade_path", "tower_id": tower_id, "path": "Middle"}, wall_ms)
	_check(preview.get("preview_promotion", false), "second path opens a promotion preview")
	var confirmed: Dictionary = gs.apply_action(
		{"type": "confirm_promotion", "tower_id": tower_id}, wall_ms)
	_check(confirmed.get("success", false), "promotion confirms through apply_action")
	return gs.get_tower_by_id(tower_id)

func _advance(gs: GameState, wall_ms: int, count: int, step: int) -> int:
	var cursor := wall_ms
	for _i in range(count):
		cursor += step
		gs.update_simulation(cursor)
	return cursor

func _test_promotion_ignores_wall_stamp() -> void:
	var gs := _fresh()
	var tower := _promote(gs, WALL_STAMP)
	_check(tower.burst_until == gs.sim_now() + BURST_MS,
		"burst_until is sim+6000 (got %d, sim %d)" % [tower.burst_until, gs.sim_now()])
	_check(tower.burst_until != WALL_STAMP + BURST_MS,
		"burst_until is not the wall stamp plus 6000")
	var buffed: int = tower.get_effective_damage(tower.burst_until - 1)
	var expired: int = tower.get_effective_damage(tower.burst_until)
	_check(buffed > expired, "damage bonus is active before the sim boundary and gone at it (%d -> %d)"
		% [buffed, expired])
	gs.dispose()

func _test_burst_expires_on_sim_time(speed: float) -> void:
	var gs := _fresh()
	_check(gs.set_speed(speed), "speed %s is accepted" % speed)
	var tower := _promote(gs, WALL_STAMP)
	# Leave build mode so the clock can move, without needing a kill.
	gs.start_wave()
	var wall := 1_000
	gs.update_simulation(wall)
	var sim_at_start: int = gs.sim_now()
	var buffed: int = tower.get_effective_damage(gs.sim_now())
	var steps := 0
	while gs.sim_now() < tower.burst_until and steps < 20000:
		wall += 16
		gs.update_simulation(wall)
		steps += 1
	var expired: int = tower.get_effective_damage(gs.sim_now())
	var sim_elapsed: int = gs.sim_now() - sim_at_start
	var wall_elapsed: int = steps * 16
	_check(expired < buffed, "x%s bonus expired after the sim boundary (%d -> %d)"
		% [speed, buffed, expired])
	# 6000 sim ms. At Nx, wall time is about 6000/N, within a couple of frames.
	var expected_wall: float = float(BURST_MS) / speed
	_check(absi(wall_elapsed - int(expected_wall)) < int(80.0 / speed) + 64,
		"x%s wall time to expiry is ~6000/speed (wall %d, sim %d)"
			% [speed, wall_elapsed, sim_elapsed])
	gs.dispose()

func _test_speed_change_mid_burst() -> void:
	var gs := _fresh()
	gs.set_speed(1.0)
	var tower := _promote(gs, WALL_STAMP)
	gs.start_wave()
	var wall := 2_000
	gs.update_simulation(wall)
	for _i in range(50):
		wall += 16
		gs.update_simulation(wall)
	var mid: int = gs.sim_now()
	_check(mid < tower.burst_until, "burst still active before the speed change")
	_check(gs.apply_action({"type": "set_speed", "multiplier": 3}, WALL_STAMP).get("success", false),
		"speed can change during the burst")
	var before: int = gs.sim_now()
	for _i in range(20):
		wall += 16
		gs.update_simulation(wall)
	var gained: int = gs.sim_now() - before
	_check(gained >= 20 * 16 * 3 - 50 and gained <= 20 * 16 * 3 + 50,
		"after switching to 3x, sim time tracks the new speed (gained %d)" % gained)
	gs.dispose()

func _test_pause_does_not_advance() -> void:
	var gs := _fresh()
	gs.start_wave()
	var wall := 3_000
	gs.update_simulation(wall)
	wall += 16
	gs.update_simulation(wall)
	var sim_before: int = gs.sim_now()
	gs.apply_action({"type": "toggle_pause"}, WALL_STAMP)
	wall += 100_000
	gs.update_simulation(wall)
	_check(gs.sim_now() == sim_before, "a long pause does not advance simulation time")
	gs.apply_action({"type": "toggle_pause"}, WALL_STAMP)
	wall += 16
	gs.update_simulation(wall)
	var gained: int = gs.sim_now() - sim_before
	_check(gained > 0 and gained <= 50, "resume continues from the next frame, not the paused gap (gained %d)" % gained)
	gs.dispose()

func _test_hitch_is_clamped() -> void:
	var gs := _fresh()
	gs.start_wave()
	var wall := 4_000
	gs.update_simulation(wall)
	var before: int = gs.sim_now()
	gs.update_simulation(wall + 5_000)
	var gained: int = gs.sim_now() - before
	_check(gained > 0 and gained <= 50, "a 5s hitch advances at most one clamped step (gained %d)" % gained)
	gs.dispose()

func _test_invalid_speeds_rejected() -> void:
	var gs := _fresh()
	_check(gs.set_speed(1.0), "1x is a supported speed")
	for bad in [-1.0, 0.0, 0.5, 4.0, 100.0, INF, NAN]:
		var before: float = gs.speed_multiplier
		var ok: bool = gs.set_speed(bad)
		_check(not ok and is_equal_approx(gs.speed_multiplier, before),
			"rejected speed %s leaves the clock at %s" % [bad, before])
	var action: Dictionary = gs.apply_action({"type": "set_speed", "multiplier": -3}, WALL_STAMP)
	_check(not action.get("success", true), "apply_action rejects a negative speed")
	_check(is_equal_approx(gs.speed_multiplier, 1.0), "rejected action does not change speed")
	var missing: Dictionary = gs.apply_action({"type": "set_speed"}, WALL_STAMP)
	_check(not missing.get("success", true), "apply_action rejects a missing multiplier")
	gs.dispose()

func _test_restart_clears_clock() -> void:
	var gs := _fresh()
	gs.set_speed(3.0)
	var tower := _promote(gs, WALL_STAMP)
	gs.start_wave()
	var wall := 8_000
	for _i in range(30):
		wall += 16
		gs.update_simulation(wall)
	_check(gs.sim_now() > 0 and tower.burst_until > 0, "pre-restart clock and burst are live")
	var restarted: Dictionary = gs.apply_action({"type": "restart_game"}, WALL_STAMP)
	_check(restarted.get("success", false), "restart action succeeds")
	_check(gs.sim_now() == 0, "restart clears simulation time")
	_check(gs.towers.is_empty(), "restart clears towers and their buffs")
	_check(is_equal_approx(gs.speed_multiplier, 1.0), "restart restores the configured speed")
	gs.dispose()
