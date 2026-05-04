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
	_test_invalid_wave_shop_card()
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

func _test_invalid_wave_shop_card() -> void:
	var state: GameState = _make_state()
	state.wave_shop_pending = true
	state.wave_ready = false
	var result: Dictionary = state.apply_action({"type": "wave_shop_pick", "card_id": "not_a_real_card"}, 6000)
	_check(result.get("success", true) == false, "invalid wave shop card returns success false")
	_check(state.wave_shop_pending and not state.wave_ready, "invalid wave shop card leaves the gate unchanged")
	state.dispose()
