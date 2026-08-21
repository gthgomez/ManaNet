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
