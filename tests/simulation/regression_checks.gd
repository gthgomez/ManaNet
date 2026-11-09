extends SceneTree

const GameStateScript := preload("res://simulation/core/GameState.gd")
const EnemyScript := preload("res://simulation/entities/Enemy.gd")
const TowerScript := preload("res://simulation/entities/Tower.gd")
const ProjectileScript := preload("res://simulation/entities/Projectile.gd")
const ProgressionScript := preload("res://autoloads/Progression.gd")
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
	_test_burn_dps_is_tick_independent()
	_test_boss_regen_works_at_sixty_fps()
	_test_mage_vulnerability_applies_to_hit()
	_test_projectile_swept_hit_at_high_speed()
	_test_wave_shop_actions_require_pending()
	_test_discount_sell_has_no_profit_loop()
	_test_dead_enemy_does_not_leak()
	_test_spawn_pacing_scales_with_speed()
	_test_projectile_lifetime_is_bounded()
	_test_opening_waves_have_no_stealth_or_flying()
	_test_stealth_vision_paths()
	_test_cannon_can_target_flying()
	_test_incompatible_modifiers_rejected()
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
	# 1 boss + full 20 trash = 21
	_check(state.get_wave_spawn_total() == 21, "boss wave spawn total is 1 + full base (21 for base 20)")
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
	_check(state.enemies_spawned == 21, "boss wave stops at the full wave cap (not a reduced one)")
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

# --- Damage-over-time / regen integration ------------------------------------

func _burn_damage_over_one_second(dt_ms: int) -> int:
	var state := _make_straight_state()
	state.wave_ready = false
	state.next_spawn_ms = 999999999
	var enemy := _inject_enemy(state)
	enemy.health = 1000000
	enemy.burn_dps = 30
	enemy.burn_until = 999999999
	state.update_simulation(100000)
	for i in range(1, int(1000.0 / float(dt_ms)) + 1):
		state.update_simulation(100000 + i * dt_ms)
	var lost: int = 1000000 - enemy.health
	state.dispose()
	return lost

func _test_burn_dps_is_tick_independent() -> void:
	# A 30 dps burn must deal ~30 damage per second at any tick size. The old
	# maxi(1, int(dps*dt/1000)) floor made this 22-126 dps depending on ticks.
	var a := _burn_damage_over_one_second(8)
	var b := _burn_damage_over_one_second(16)
	var c := _burn_damage_over_one_second(32)
	_check(absf(float(a) - 30.0) <= 2.0, "30 dps burn deals ~30 dmg/s at 8ms ticks (got %d)" % a)
	_check(absf(float(b) - 30.0) <= 2.0, "30 dps burn deals ~30 dmg/s at 16ms ticks (got %d)" % b)
	_check(absf(float(c) - 30.0) <= 2.0, "30 dps burn deals ~30 dmg/s at 32ms ticks (got %d)" % c)
	_check(absi(a - b) <= 1 and absi(b - c) <= 1,
		"burn damage is tick-size independent (%d/%d/%d)" % [a, b, c])

func _test_boss_regen_works_at_sixty_fps() -> void:
	var state := _make_straight_state()
	state.wave_ready = false
	state.next_spawn_ms = 999999999
	var boss := EnemyScript.BossRegenerator.new(state.path)
	boss.health = 100
	boss.max_health = 600
	state.enemies.append(boss)
	state.update_simulation(100000)
	for i in range(1, 63):  # 1 second at 16ms
		state.update_simulation(100000 + i * 16)
	var gained: int = boss.health - 100
	_check(gained >= 43 and gained <= 47,
		"BossRegenerator heals ~45 HP/s at 60fps (got %d)" % gained)
	state.dispose()

func _test_mage_vulnerability_applies_to_hit() -> void:
	var state := _make_state()
	var mage := TowerScript.new(Vector2(100, 100), "mage", 1)
	mage.tracker.path_levels["Bottom"] = 5
	var target := EnemyScript.new(state.path)
	target.health = 100000
	target.max_health = 100000
	state.enemies.append(target)
	state.apply_hit(mage, target, 100, 1000)
	var lost: int = 100000 - target.health
	_check(lost == 130, "mage Bottom L5 Vulnerability Exploit applies +30%% to the hit (got %d)" % lost)
	# Any other tower also benefits while the debuff is active.
	var archer := TowerScript.new(Vector2(100, 100), "archer", 2)
	state.apply_hit(archer, target, 100, 1100)
	var second_lost: int = 100000 - lost - target.health
	_check(second_lost == 130, "vulnerability applies to other towers too (got %d)" % second_lost)
	state.dispose()

func _test_projectile_swept_hit_at_high_speed() -> void:
	var state := _make_straight_state()
	state.wave_ready = false
	state.next_spawn_ms = 999999999
	state.speed_multiplier = 3.0
	var target := EnemyScript.new(state.path)
	target.pos = Vector2(300, 300)
	target.health = 100000
	target.max_health = 100000
	target.frozen_until = 1 << 40   # stationary target
	state.enemies.append(target)
	var tower := TowerScript.new(Vector2(100, 300), "archer", 1)
	tower.game_state = state
	var projectile := ProjectileScript.new(Vector2(100, 300), target, tower, 10, 100000, 0, 3.0)
	state.projectiles.append(projectile)
	# A 3x-speed step moves ~81px; the swept segment must register the hit even
	# though the end point can leap past the target's hit radius.
	for i in range(1, 6):
		state.update_simulation(100000 + i * 50)
	_check(target.health < 100000, "swept collision registers a high-speed projectile hit")
	_check(state.projectiles.is_empty(), "high-speed projectile is consumed instead of orbiting")
	state.dispose()

func _test_wave_shop_actions_require_pending() -> void:
	var state := _make_state()
	state.wave_ready = false
	var gold_before: int = state.gold
	var pick: Dictionary = state.apply_action({"type": "wave_shop_pick", "card_id": "war_chest"}, 1000)
	var skip: Dictionary = state.apply_action({"type": "wave_shop_skip"}, 1000)
	_check(not pick.get("success", true), "wave_shop_pick is rejected when no shop is pending")
	_check(not skip.get("success", true), "wave_shop_skip is rejected when no shop is pending")
	_check(state.gold == gold_before and not state.wave_ready,
		"rejected wave-shop actions do not grant cards or start the wave")
	state.dispose()

func _test_discount_sell_has_no_profit_loop() -> void:
	var state := _make_state()
	state.wave = 2
	state.gold = 1000
	state._ws_cost_discount = 0.75
	var placed: Dictionary = state.apply_action(
		{"type": "place_tower", "tower_type": "archer", "pos": Vector2(300, 200)}, 1000)
	_check(placed.get("success", false), "discounted tower placement succeeds")
	var sold: Dictionary = state.apply_action(
		{"type": "sell_tower", "tower_id": placed.get("tower_id", -1)}, 1000)
	_check(sold.get("success", false), "discounted tower can be sold")
	_check(state.gold < 1000, "discount buy + sell does not create gold (got %d)" % state.gold)
	state.dispose()

func _test_dead_enemy_does_not_leak() -> void:
	var state := GameStateScript.new([Vector2(0, 300), Vector2(200, 300)], {}, 0)
	state.wave_ready = false
	state.next_spawn_ms = 999999999
	var enemy := EnemyScript.new(state.path)
	enemy.pos = Vector2(199, 300)
	enemy.health = 1
	enemy.burn_dps = 200
	enemy.burn_until = 999999999
	state.enemies.append(enemy)
	var lives_before: int = state.lives
	state.update_simulation(100000)
	state.update_simulation(100016)
	_check(state.lives == lives_before,
		"an enemy killed by burn does not also leak a life (lives %d -> %d)" % [lives_before, state.lives])
	state.dispose()

func _test_spawn_pacing_scales_with_speed() -> void:
	var slow := _make_state()
	slow.spawn_interval_ms = 600
	slow.wave_enemy_total = 100
	slow.speed_multiplier = 1.0
	slow.spawn_enemy(1000)
	var slow_gap: int = slow.next_spawn_ms - 1000
	var fast := _make_state()
	fast.spawn_interval_ms = 600
	fast.wave_enemy_total = 100
	fast.speed_multiplier = 3.0
	fast.spawn_enemy(1000)
	var fast_gap: int = fast.next_spawn_ms - 1000
	_check(absi(fast_gap - int(slow_gap / 3)) <= 1,
		"3x speed scales spawn pacing to ~1/3 wall time (%d vs %d)" % [fast_gap, slow_gap])
	slow.dispose()
	fast.dispose()

func _test_projectile_lifetime_is_bounded() -> void:
	var state := _make_straight_state()
	state.wave_ready = false
	state.next_spawn_ms = 999999999
	var target := EnemyScript.new(state.path)
	target.pos = Vector2(300, 300)
	target.health = 100000
	target.max_health = 100000
	target.frozen_until = 1 << 40
	state.enemies.append(target)
	var tower := TowerScript.new(Vector2(100, 300), "archer", 1)
	tower.game_state = state
	var projectile := ProjectileScript.new(Vector2(100, 300), target, tower, 10, -5000, 0, 1.0)
	state.projectiles.append(projectile)
	state.update_simulation(0)
	state.update_simulation(16)
	_check(state.projectiles.is_empty(),
		"projectiles older than PROJECTILE_MAX_FLIGHT_MS are despawned")
	_check(target.health == 100000, "expired projectile deals no damage")
	state.dispose()

func _test_opening_waves_have_no_stealth_or_flying() -> void:
	for wave_num in [1, 2]:
		var state := _make_state()
		state.wave = wave_num
		state.enemies_spawned = 0
		state.wave_enemy_total = 1000
		state.enemies.clear()
		for i in range(200):
			state.spawn_enemy(1000 + i)
		var bad: int = 0
		for enemy in state.enemies:
			if enemy.stealthed or enemy.flying:
				bad += 1
		_check(bad == 0, "wave %d opening spawns no stealth/flying enemies (got %d)" % [wave_num, bad])
		state.dispose()

func _test_stealth_vision_paths() -> void:
	var archer := TowerScript.new(Vector2(100, 100), "archer", 1)
	_check(not archer.can_see_stealth(), "archer at Bottom 0 cannot see stealth")
	archer.tracker.path_levels["Bottom"] = 1
	_check(archer.can_see_stealth(), "archer Bottom L1 can see stealth")
	var frost := TowerScript.new(Vector2(100, 100), "frost", 2)
	_check(frost.can_see_stealth(), "frost can see stealth")
	var mage := TowerScript.new(Vector2(100, 100), "mage", 3)
	_check(not mage.can_see_stealth(), "mage remains stealth-blind")
	var cannon := TowerScript.new(Vector2(100, 100), "cannon", 4)
	_check(not cannon.can_see_stealth(), "cannon remains stealth-blind")

func _test_cannon_can_target_flying() -> void:
	var state := _make_state()
	var cannon := TowerScript.new(Vector2(100, 100), "cannon", 1)
	var drone := EnemyScript.FlyingDrone.new(state.path)
	drone.pos = Vector2(120, 100)
	drone.stealthed = false   # isolate the flying rule
	state.enemies.append(drone)
	var target = cannon.select_target(state.enemies, 1000)
	_check(target == drone, "cannon can target non-stealth flying enemies")
	state.dispose()

func _test_incompatible_modifiers_rejected() -> void:
	var prog = ProgressionScript.new()
	_check(not prog._modifiers_compatible("mod_sudden_death", "mod_glass_cannon"),
		"Sudden Death + Glass Cannon stack is rejected")
	_check(not prog._modifiers_compatible("mod_blitz", "mod_hardened"),
		"Blitz + Hardened stack is rejected")
	_check(prog._modifiers_compatible("mod_blitz", "mod_iron_economy"),
		"compatible modifier pair is allowed")
	prog.free()
