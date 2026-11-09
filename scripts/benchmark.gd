extends SceneTree

# Headless benchmark. The previous version never called start_wave(), so the
# wave_ready gate returned before spawning and the reported 0.0006 ms/frame
# measured an empty loop. This version runs a live wave, asserts liveness, and
# reports percentiles instead of a mean that hides spikes.

const _MAPS := preload("res://data/maps.gd")
const _TT := preload("res://data/tower_types.gd")
const WARMUP_FRAMES := 300
const MEASURED_FRAMES := 3000
const TARGET_ENEMIES := 100
const TARGET_TOWERS := 50

func _init() -> void:
	print("--- MANANET SIMULATION BENCHMARK (LIVE) ---")
	var GameState = load("res://simulation/core/GameState.gd")
	var path: Array = _MAPS.MAPS[0]["path"]
	var state = GameState.new(path, {"extra_gold": 1_000_000})
	state.wave_ready = false
	state.lives = 1_000_000_000
	state.wave_enemy_total = 1_000_000_000
	state.spawn_interval_ms = 50
	state.next_spawn_ms = 0

	var placed: int = 0
	for pos in _candidate_positions(path):
		if placed >= TARGET_TOWERS:
			break
		var ttype: String = _TT.TOWER_TYPES_LIST[placed % _TT.TOWER_TYPES_LIST.size()]
		var res: Dictionary = state.apply_action(
			{"type": "place_tower", "tower_type": ttype, "pos": pos}, 0)
		if res.get("success", false):
			placed += 1
	state.gold = 1_000_000_000

	state.start_wave()
	print("Setup: %d towers, %dms spawn interval, target %d concurrent enemies"
		% [placed, state.spawn_interval_ms, TARGET_ENEMIES])

	var samples: Array[float] = []
	var now_ms: int = 0
	var last_enemy_pos: Vector2 = Vector2.ZERO
	var max_enemies: int = 0
	for f in range(WARMUP_FRAMES + MEASURED_FRAMES):
		if f == WARMUP_FRAMES:
			samples.clear()
		var t0: int = Time.get_ticks_usec()
		state.update_simulation(now_ms)
		var dt: float = float(Time.get_ticks_usec() - t0)
		if f >= WARMUP_FRAMES:
			samples.append(dt)
		now_ms += 16
		max_enemies = maxi(max_enemies, state.enemies.size())
		if not state.enemies.is_empty():
			last_enemy_pos = state.enemies[0].pos

	samples.sort()
	var total_us: float = 0.0
	for s in samples:
		total_us += s
	var mean_ms: float = total_us / float(samples.size()) / 1000.0
	var p50: float = _pct(samples, 0.50) / 1000.0
	var p95: float = _pct(samples, 0.95) / 1000.0
	var p99: float = _pct(samples, 0.99) / 1000.0
	var max_ms: float = samples[-1] / 1000.0

	print("--- RESULTS ---")
	print("Measured frames:   %d (after %d warm-up)" % [samples.size(), WARMUP_FRAMES])
	print("Towers placed:     %d" % placed)
	print("Peak enemies:      %d" % max_enemies)
	print("Kills:             %d" % state.stat_enemies_killed)
	print("Mean frame:        %.4f ms" % mean_ms)
	print("p50 / p95 / p99:   %.4f / %.4f / %.4f ms" % [p50, p95, p99])
	print("Max frame:         %.4f ms" % max_ms)
	print("Theoretical FPS:   %.0f (mean)" % (1000.0 / maxf(0.000001, mean_ms)))

	var alive: bool = (
		placed > 0
		and max_enemies > 0
		and state.stat_enemies_killed > 0
		and state.enemies.size() > 0
		and last_enemy_pos != Vector2.ZERO
	)
	if not alive:
		push_error("BENCHMARK FAIL: workload did not advance (no enemies/kills/motion)")
		state.dispose()
		quit(1)
		return
	print("BENCHMARK PASS: live workload verified")
	state.dispose()
	quit(0)

func _pct(sorted_values: Array[float], frac: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var idx: int = clampi(int(floor(frac * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1)
	return sorted_values[idx]

func _candidate_positions(path: Array) -> Array:
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
		var steps: int = maxi(2, int(ceil(length / 28.0)))
		for step in range(steps + 1):
			var anchor: Vector2 = a.lerp(b, float(step) / float(steps))
			for offset in [52.0, 76.0, 100.0, 130.0, 160.0]:
				for side in [-1.0, 1.0]:
					out.append(anchor + normal * offset * side)
	return out
