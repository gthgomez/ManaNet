extends SceneTree

# Same seed and actions must produce the same mechanical history whether
# combat particles are off, normal, or flooded — and whether the global RNG
# is burned by unrelated presentation code.

const GameStateScript := preload("res://simulation/core/GameState.gd")
const _MAPS := preload("res://data/maps.gd")

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("--- RNG ISOLATION ---")
	for seed_value in [3, 17, 101, 4099]:
		_test_seed(seed_value)
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

func _play(seed_value: int, particle_scale: int, burn_global: bool) -> Dictionary:
	var gs: GameState = GameStateScript.new(
		_MAPS.MAPS[0]["path"], {"rng_seed": seed_value, "extra_gold": 2000}, 0)
	gs.presentation_particle_scale = particle_scale
	var spots: Array = [Vector2(300, 240), Vector2(360, 180), Vector2(420, 300), Vector2(250, 180)]
	for spot in spots:
		gs.apply_action(
			{"type": "place_tower", "tower_type": "archer", "pos": spot}, gs.sim_now())
	gs.start_wave()
	var spawns: Array = []
	var offers: Array = []
	var wall := 10_000
	var ticks := 0
	while gs.game_state == "playing" and gs.wave == 1 and ticks < 20000:
		if burn_global:
			for _i in range(25):
				randf()
				randf_range(0.0, 1.0)
				randi()
			gs._add_particle_burst(Vector2(100, 100), "spark", Color.WHITE, 40, gs.sim_now())
		var before: int = gs.enemies_spawned
		wall += 16
		gs.update_simulation(wall)
		if gs.enemies_spawned > before and not gs.enemies.is_empty():
			spawns.append(str(gs.enemies.back().type_name))
		if gs.wave_shop_pending and offers.is_empty():
			for card in gs.get_wave_shop_offers():
				offers.append(str(card.get("id", "")))
			gs.apply_action({"type": "wave_shop_pick", "card_id": offers[0]}, gs.sim_now())
		ticks += 1
	var digest := {
		"spawns": ",".join(spawns),
		"offers": ",".join(offers),
		"kills": gs.stat_enemies_killed,
		"gold": gs.gold,
		"lives": gs.lives,
		"kills_by_type": str(gs.stat_tower_kills_by_type),
		"wave": gs.wave,
		"state": gs.game_state,
	}
	gs.dispose()
	return digest

func _test_seed(seed_value: int) -> void:
	var normal := _play(seed_value, 1, false)
	var disabled := _play(seed_value, 0, false)
	var heavy := _play(seed_value, 8, true)
	_check(not str(normal["spawns"]).is_empty(), "seed %d spawned enemies" % seed_value)
	_check(not str(normal["offers"]).is_empty(), "seed %d drew wave-shop offers (%s)"
		% [seed_value, normal["offers"]])
	_check(normal == disabled,
		"seed %d disabled particles match normal play" % seed_value)
	_check(normal == heavy,
		"seed %d heavy particles and global RNG burns match normal play" % seed_value)
	print("       seed %d offers=%s kills=%s" % [seed_value, normal["offers"], normal["kills"]])
