# Rendered-FPS probe for the shipped GameScreen under a real display.
# Software GL (llvmpipe/Xvfb) numbers are desktop harness evidence only; they
# are not Android/Fire GPU evidence.
extends SceneTree

const SCENARIO_ENV := "QA_FPS_SIZE"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var size := OS.get_environment(SCENARIO_ENV)
	var parts := size.split("x")
	var w: int = int(parts[0]) if parts.size() == 2 else 900
	var h: int = int(parts[1]) if parts.size() == 2 else 600
	root.content_scale_size = Vector2i(w, h)
	root.size = Vector2i(w, h)
	await process_frame
	await process_frame
	var progression := root.get_node("Progression")
	progression.pending_map_id = 0
	var game = load("res://scenes/GameScreen.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	game.view_state.show_onboarding = false
	game.view_state.onboarding_dismissed = true
	game.view_state.clear_instruction()
	# Populate combat the same way the shipped shop does.
	for i in range(6):
		var pos := Vector2(140 + i * 90, 240)
		game._dispatch({"type": "place_tower", "tower_type": "archer", "pos": pos}, Time.get_ticks_msec())
	game.game_state.gold = 3000
	game.game_state.start_wave()
	await create_timer(1.5).timeout
	var samples: Array[float] = []
	for _i in range(240):
		await process_frame
		samples.append(float(Engine.get_frames_per_second()))
	var total := 0.0
	var mn := 9999.0
	var mx := 0.0
	for s in samples:
		total += s
		mn = minf(mn, s)
		mx = maxf(mx, s)
	var avg: float = total / maxf(1.0, float(samples.size()))
	print("RENDER_FPS size=%dx%d frames=%d avg=%.1f min=%.1f max=%.1f cpu_static_mb=%.1f"
		% [w, h, samples.size(), avg, mn, mx,
			float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)])
	quit(0)
