extends SceneTree

const GameStateScript := preload("res://simulation/core/GameState.gd")
const EnemyScript := preload("res://simulation/entities/Enemy.gd")
const TowerScript := preload("res://simulation/entities/Tower.gd")
const _MAPS := preload("res://data/maps.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("--- SIMULATION REGRESSION CHECKS ---")
	_test_event_queue()
	_test_wave_shop_gate()
	_test_frost_vanguard_timing()
	_test_boss_shield_brute_absorbs_damage()
	_test_boss_wave_trash_density()
	_test_invalid_wave_shop_card()
	_test_cannon_shock_stuns_target_and_chills_aoe()
	_test_cannon_siege_splash_and_rapid_cooldown()
	_test_movement_scales_with_sim_delta()
	_test_large_time_gaps_are_clamped()
	_test_flame_burst_density_is_tick_phase_independent()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass_count)
	print("FAIL: %d" % _fail_count)
	quit(1 if _fail_count > 0 else 0)

func _make_state() -> GameState:
	return GameStateScript.new(_MAPS.MAPS[0]["path"], {}, 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % message)
	else:
		_fail_count += 1
		push_error("[FAIL] %s" % message)

func _test_event_queue() -> void:
	var state: GameState = _make_state()
	var event := {"type": "screen_shake", "intensity": 4.0, "duration_ms": 300, "ms": 1234}
	state.emit_event(event)
	event["intensity"] = 99.0
	var drained: Array = state.drain_events()
	_check(drained.size() == 1, "drain_events returns one queued event")
	_check(float(drained[0]["intensity"]) == 4.0, "emit_event stores a duplicate event")
	_check(state.pending_events.is_empty(), "drain_events clears the queue")
	_check(state.drain_events().is_empty(), "second drain returns empty")
	state.dispose()

func _test_wave_shop_gate() -> void:
	var state: GameState = _make_state()
	state.wave = 2
	state.wave_ready = false
	state.wave_shop_pending = true
	state.next_spawn_ms = 999
	state.start_wave()
	_check(state.wave == 2 and state.wave_ready == false and state.next_spawn_ms == 999,
		"start_wave does not advance while wave_shop_pending gates the run")
	var result: Dictionary = state.apply_action({"type": "wave_shop_skip"}, 2000)
	state.start_wave()
	state.update_simulation(2000)
	_check(result.get("success", false) and not state.wave_shop_pending and state.enemies_spawned > 0,
		"wave_shop_skip clears the gate and allows next wave spawning")
	state.dispose()

func _test_frost_vanguard_timing() -> void:
	var state: GameState = _make_state()
	var now_ms: int = 123456
	state._ws_frost_vanguard_remaining = 1
	state.spawn_enemy(now_ms)
	_check(state.enemies.size() == 1, "frost vanguard test spawned one enemy")
	_check(state.enemies[0].chilled_until == now_ms + 3000,
		"frost vanguard chill duration is based on provided now_ms")
	state.dispose()

func _test_boss_shield_brute_absorbs_damage() -> void:
	var state: GameState = _make_state()
	var boss := EnemyScript.BossShieldBrute.new(state.path)
	var tower := TowerScript.new(Vector2(100.0, 100.0), "archer", 1)
	var initial_health: int = boss.health
	var initial_shield: int = boss.shield_hp
	state.apply_hit(tower, boss, 999, 5000)
	_check(boss.shield_hp == initial_shield - 1, "BossShieldBrute shield absorbs one hit")
	_check(boss.health == initial_health, "BossShieldBrute shield prevents health damage")
	state.dispose()

func _test_boss_wave_trash_density() -> void:
	var state: GameState = _make_state()
	state.wave = 5
	state.wave_enemy_total = 20
	# 1 boss + round(20 * 0.6) trash = 13
	_check(state.get_wave_spawn_total() == 13, "boss wave spawn total is 1 + 60%% of base (13 for base 20)")
	state.wave = 4
	_check(state.get_wave_spawn_total() == 20, "non-boss wave uses full wave_enemy_total")
	state.wave = 5
	state.enemies_spawned = 0
	state.enemies.clear()
	state.spawn_interval_ms = 500
	state.spawn_enemy(1000)
	_check(state.enemies.size() == 1 and state.enemies[0] is EnemyScript.BossShieldBrute,
		"boss wave first spawn is BossShieldBrute")
	_check(state.next_spawn_ms == 1000 + 500 + GameStateScript.BOSS_POST_SPAWN_EXTRA_MS,
		"boss spawn adds post-boss trash delay")
	while state.enemies_spawned < state.get_wave_spawn_total():
		state.spawn_enemy(state.next_spawn_ms)
	_check(state.enemies_spawned == 13, "boss wave stops at density cap (not full base 20)")
	_check(state.wave_enemy_total == 20, "base wave_enemy_total progression value unchanged")
	state.dispose()

func _test_invalid_wave_shop_card() -> void:
	var state: GameState = _make_state()
	state.wave_shop_pending = true
	state.wave_ready = false
	var result: Dictionary = state.apply_action({"type": "wave_shop_pick", "card_id": "not_a_real_card"}, 6000)
	_check(result.get("success", true) == false, "invalid wave shop card returns success false")
	_check(state.wave_shop_pending and not state.wave_ready, "invalid wave shop card leaves the gate unchanged")
	state.dispose()

func _test_cannon_shock_stuns_target_and_chills_aoe() -> void:
	var state: GameState = _make_state()
	var cannon := TowerScript.new(Vector2(480.0, 420.0), "cannon", 1)
	cannon.tracker.path_levels["Bottom"] = 2
	# Stun 400 + 150*2 = 700 ms; nearby chill 300 + 100*2 = 500 ms (matches upgrade_paths.gd desc)
	_check(cannon.stun_duration_ms() == 700, "cannon Bottom L2 stun duration is 700ms")
	# Splash path (Top) is 0: shock radius falls back to int(effective_range * 0.35) = int(95 * 0.35) = 33
	var target := EnemyScript.new(state.path)
	var near := EnemyScript.new(state.path)
	var far := EnemyScript.new(state.path)
	target.pos = Vector2(500, 500)
	near.pos = Vector2(520, 500)
	far.pos = Vector2(700, 700)
	state.enemies.append(target)
	state.enemies.append(near)
	state.enemies.append(far)
	var now_ms: int = 7000
	state.apply_hit(cannon, target, 50, now_ms)
	_check(target.frozen_until == now_ms + 700, "shock stuns primary target for 700ms")
	_check(near.chilled_until == now_ms + 500, "shock chills enemies within blast radius for 500ms")
	_check(far.chilled_until < now_ms, "shock does not chill enemies outside radius")
	_check(near.current_speed(now_ms) == near.speed * 0.6, "chilled enemy moves at 60% speed")
	# Control: identical hit from a cannon without Shock applies neither stun nor chill
	var plain := TowerScript.new(Vector2(480.0, 420.0), "cannon", 2)
	var plain_target := EnemyScript.new(state.path)
	var plain_near := EnemyScript.new(state.path)
	plain_target.pos = Vector2(500, 500)
	plain_near.pos = Vector2(520, 500)
	state.enemies.append(plain_target)
	state.enemies.append(plain_near)
	state.apply_hit(plain, plain_target, 50, now_ms)
	_check(plain_target.frozen_until < now_ms and plain_near.chilled_until < now_ms,
		"cannon without Shock applies neither stun nor chill")
	state.dispose()

func _test_cannon_siege_splash_and_rapid_cooldown() -> void:
	var state: GameState = _make_state()
	var base := TowerScript.new(Vector2(480.0, 420.0), "cannon", 1)
	_check(base.splash_radius() == 0, "cannon without Siege has no AoE splash radius")
	_check(base.effective_cooldown() == base.base_cooldown, "cannon without Rapid keeps base cooldown")
	var siege := TowerScript.new(Vector2(480.0, 420.0), "cannon", 1)
	siege.tracker.path_levels["Top"] = 3
	_check(siege.splash_radius() == 106, "Siege L3 grants 106px AoE splash radius")
	var target := EnemyScript.new(state.path)
	var neighbor := EnemyScript.new(state.path)
	var outsider := EnemyScript.new(state.path)
	target.pos = Vector2(500, 500)
	neighbor.pos = Vector2(560, 500)
	outsider.pos = Vector2(900, 900)
	state.enemies.append(target)
	state.enemies.append(neighbor)
	state.enemies.append(outsider)
	var neighbor_health_before: int = neighbor.health
	var outsider_health_before: int = outsider.health
	state.apply_hit(siege, target, 68, 4000)
	_check(neighbor.health == neighbor_health_before - maxi(1, int(68.0 * 0.65)),
		"Siege splash deals 65% hit damage to enemies in radius")
	_check(outsider.health == outsider_health_before, "Siege splash does not reach enemies outside radius")
	var saw_shake := false
	for ev in state.drain_events():
		if ev.get("type") == "screen_shake":
			saw_shake = true
	_check(saw_shake, "Siege splash impact emits screen shake event")
	var rapid := TowerScript.new(Vector2(480.0, 420.0), "cannon", 2)
	rapid.tracker.path_levels["Middle"] = 5
	_check(rapid.effective_cooldown() == int(float(rapid.base_cooldown) * 0.55),
		"Rapid L5 reduces cannon cooldown by 45% (capped)")
	state.dispose()

# --- Frame-rate independence guards (P0 timing fix) --------------------------

# Long straight path so enemies never hit a waypoint inside the test window
# (waypoint snapping is step-size sensitive by design).
func _make_straight_state() -> GameState:
	var straight_path: Array = [Vector2(0, 300), Vector2(4000, 300)]
	return GameStateScript.new(straight_path, {}, 0)

func _inject_enemy(state: GameState) -> Enemy:
	var enemy := EnemyScript.new(state.path)
	state.enemies.append(enemy)
	return enemy

func _run_unpaused(state: GameState, t_start: int, steps: int, dt_ms: int) -> void:
	state.wave_ready = false
	state.next_spawn_ms = 999999999   # isolate from the spawner
	state.update_simulation(t_start)  # prime: consume the cold-start sentinel tick
	for i in range(1, steps + 1):
		state.update_simulation(t_start + i * dt_ms)

func _test_movement_scales_with_sim_delta() -> void:
	var a := _make_straight_state()
	var b := _make_straight_state()
	var c := _make_straight_state()
	var ea := _inject_enemy(a)
	_inject_enemy(b)
	_inject_enemy(c)
	_run_unpaused(a, 100000, 60, 16)    # 960 ms at ~60 fps
	_run_unpaused(b, 100000, 120, 8)    # 960 ms at ~120 fps
	_run_unpaused(c, 100000, 30, 32)    # 960 ms at ~30 fps
	_check(ea.pos.x > 100.0, "enemy actually travels during stepped sim")
	_check(absf(ea.pos.x - 115.2) < 5.0,
		"travel matches analytic px/frame@60 scaling (got %.2f, expect ~115.2)" % ea.pos.x)
	_check(ea.pos.distance_to(b.enemies[0].pos) < 0.05,
		"960 ms of travel matches between 16 ms and 8 ms ticks")
	_check(ea.pos.distance_to(c.enemies[0].pos) < 0.05,
		"960 ms of travel matches between 16 ms and 32 ms ticks")
	a.dispose()
	b.dispose()
	c.dispose()

func _test_large_time_gaps_are_clamped() -> void:
	var state := _make_straight_state()
	var enemy := _inject_enemy(state)
	state.wave_ready = false
	state.update_simulation(100000)
	var before := enemy.pos
	state.update_simulation(110000)   # 10 s hitch in one tick
	var moved: float = before.distance_to(enemy.pos)
	var max_step: float = 2.0 * state.MAX_SIM_STEP_MS / state.SIM_REFERENCE_FRAME_MS + 0.5
	_check(moved > 0.0 and moved <= max_step,
		"10 s hitch advances the enemy by at most one clamped step")
	_check(state._last_sim_ms == 110000, "hitch tick consumes the gap (no repeated catch-up)")
	state.dispose()

func _test_flame_burst_density_is_tick_phase_independent() -> void:
	# Same simulated burn duration from two different wall-clock phases must
	# produce identical flame-burst cadence (old now_ms % 250 gate failed this).
	# Counts emission events via last_flame_burst_ms transitions — particle
	# survival is lifespan-random and therefore not a usable signal.
	var results := []
	for offset in [123456, 123456 + 137]:
		var state := _make_straight_state()
		state.wave_ready = false
		state.next_spawn_ms = 999999999
		var enemy := _inject_enemy(state)
		enemy.health = 1000000
		enemy.burn_dps = 10
		enemy.burn_until = 999999999
		var emissions: Array = []
		var last_seen: int = -999999
		for i in range(63):   # covers [offset, offset + 992] ms of burn
			state.update_simulation(offset + i * 16)
			if enemy.last_flame_burst_ms != last_seen:
				emissions.append(enemy.last_flame_burst_ms - offset)
				last_seen = enemy.last_flame_burst_ms
		results.append(emissions)
		state.dispose()
	_check(results[0].size() == 4 and results[1].size() == 4,
		"flame bursts fire every ~250 ms regardless of clock phase (4 in 1000 ms; got %d vs %d)"
			% [results[0].size(), results[1].size()])
	_check(results[0] == results[1],
		"flame burst cadence identical across phases %s vs %s" % [str(results[0]), str(results[1])])
