extends SceneTree

# Performance Simulator / Headless Benchmark
# Run with: godot --headless -s scripts/benchmark.gd

func _init():
	print("--- TACTICAL SIMULATOR: PERFORMANCE BENCHMARK ---")
	
	# Mock data
	var path = [Vector2(0,0), Vector2(500, 500), Vector2(1000, 1000)]
	var config = {"extra_gold": 50000} # Infinite money for stress test
	
	var GameState = load("res://simulation/core/GameState.gd")
	var state = GameState.new(path, config)
	
	# 1. Stress Test Setup: Place 50 Towers
	var tower_types = ["archer", "mage", "cannon", "sniper", "frost", "lightning"]
	for i in range(50):
		state.apply_action({
			"type": "place_tower",
			"tower_type": tower_types[i % 6],
			"pos": Vector2(randf_range(0, 1000), randf_range(0, 1000))
		}, 0)
	
	print("Simulation Setup: 50 Towers placed.")
	
	# 2. Simulation Run
	var start_time = Time.get_ticks_usec()
	var frames = 5000
	var now_ms = 0
	
	for f in range(frames):
		# Force spawn enemies to keep load high (100 concurrent)
		if state.enemies.size() < 100:
			state.spawn_enemy(now_ms)
			
		state.update_simulation(now_ms)
		now_ms += 16 # 60 FPS step
		
	var end_time = Time.get_ticks_usec()
	var total_ms = (end_time - start_time) / 1000.0
	
	print("--- RESULTS ---")
	print("Total Frames Simulated: ", frames)
	print("Total Execution Time:   ", total_ms, "ms")
	print("Max FPS (Theoretical):  ", 1000.0 / (total_ms / frames))
	print("-----------------------------------------------")
	
	state.dispose()
	
	quit()
