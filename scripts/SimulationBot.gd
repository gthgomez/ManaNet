extends SceneTree

# Simulation Bot for Godot TD
# Runs a headless game to audit mechanics and balance.
# Simulates a "Learning Player" with sub-optimal choices.

const _MAPS := preload("res://data/maps.gd")
const _TT := preload("res://data/tower_types.gd")
const GameState := preload("res://simulation/core/GameState.gd")
const BOT_SEED: int = 71240
const PLACEMENT_SAMPLE_SPACING: float = 34.0
const PLACEMENT_OFFSETS: Array = [56.0, 72.0, 92.0, 118.0, 148.0, 180.0]

func _init():
	print("--- Starting Headless Simulation Bot ---")
	run_simulation()
	quit()

func run_simulation():
	seed(BOT_SEED)
	# 1. Setup GameState
	var map_id = 0 # S-Curve
	var map_data = _MAPS.MAPS[map_id]
	var run_config = {
		"extra_gold": 0,
		"extra_lives": 0,
		"speed_mult_enemies": 1.0,
		"hp_mult_enemies": 1.0
	}
	
	var gs = GameState.new(map_data["path"], run_config, map_id)
	var path_len: float = _path_length(map_data["path"])
	var path_samples: Array = _path_samples(map_data["path"], PLACEMENT_SAMPLE_SPACING)
	print("Map: %s | Difficulty: %d" % [map_data["name"], map_data["difficulty"]])
	print("Bot RNG Seed: %d" % BOT_SEED)
	
	var now_ms = 0
	var tick_rate_ms = 16 # ~60 FPS
	var total_ticks = 0
	var max_waves = 10
	
	var simulation_active = true
	
	# Stats for the report
	var towers_placed = 0
	var upgrades_bought = 0
	var wave_reports: Array = []
	var wave_report: Dictionary = _new_wave_report(gs, now_ms)
	
	# "Learning Player" Logic
	var next_action_time = 1000 # Action every 1s
	var skill_level = 0.4 # Testing the floor
	
	print("Skill Level: %.2f (Learning Player)" % skill_level)
	
	while simulation_active:
		var wave_before: int = gs.wave
		var lives_before: int = gs.lives
		var kills_before: int = gs.stat_enemies_killed
		var spawned_before: int = gs.enemies_spawned
		var tower_shots_before: Dictionary = _tower_shot_times(gs)
		var target_snapshot: Dictionary = _target_snapshot(gs, now_ms)
		var leak_candidates: Array = _front_enemy_snapshot(gs.enemies, path_len, 3)

		# Tick simulation
		gs.update_simulation(now_ms)

		var spawned_delta: int = gs.enemies_spawned - spawned_before
		if gs.wave == wave_before and spawned_delta > 0:
			wave_report["enemies_spawned"] += spawned_delta
		var kills_delta: int = gs.stat_enemies_killed - kills_before
		if kills_delta > 0:
			wave_report["enemies_killed"] += kills_delta
		var lives_delta: int = lives_before - gs.lives
		if lives_delta > 0:
			wave_report["enemies_leaked"] += lives_delta
			wave_report["lives_lost"] += lives_delta
			_append_limited(wave_report["leak_candidates"], leak_candidates, 9)
		_accumulate_target_snapshot(wave_report, target_snapshot)
		_accumulate_fired_towers(wave_report, gs, tower_shots_before)

		if gs.wave != wave_before:
			wave_report["ending_gold"] = gs.gold
			wave_report["result"] = "passed"
			wave_report["reason"] = _wave_reason(wave_report, gs)
			wave_reports.append(wave_report)
			wave_report = _new_wave_report(gs, now_ms)

		if total_ticks % 60 == 0:
			print("Tick %d | Wave %d | Enemies: %d | Towers: %d | Gold: %d | Kills: %d | Lives: %d" % [
				total_ticks, gs.wave, gs.enemies.size(), gs.towers.size(), gs.gold, gs.stat_enemies_killed, gs.lives
			])

		# Check for defeat or success
		if gs.lives <= 0:
			print("!!! DEFEAT at Wave %d !!!" % gs.wave)
			wave_report["ending_gold"] = gs.gold
			wave_report["result"] = "failed"
			wave_report["reason"] = _wave_reason(wave_report, gs)
			wave_reports.append(wave_report)
			simulation_active = false
			break
			
		if gs.wave >= max_waves and gs.enemies.is_empty() and gs.wave_started == false:
			print("+++ SUCCESS! Cleared 10 Waves +++")
			wave_report["ending_gold"] = gs.gold
			wave_report["result"] = "passed"
			wave_report["reason"] = _wave_reason(wave_report, gs)
			wave_reports.append(wave_report)
			simulation_active = false
			break
			
		# Dismiss wave shop gate immediately — start_wave silently no-ops while pending
		if gs.wave_shop_pending:
			wave_report["shop_cards_offered"] = "not drawn by SimulationBot"
			wave_report["shop_choice"] = "skipped"
			gs.apply_action({"type": "wave_shop_skip"}, now_ms)

		# Player Thinking Logic
		if now_ms >= next_action_time:
			var delay = randi_range(800, 1500) if gs.wave < 3 else randi_range(1500, 3000)
			next_action_time = now_ms + delay
			
			# Decision 1: Start wave if idle
			if not gs.wave_started:
				if randf() < 0.95: # Very likely to start
					var start_res: Dictionary = gs.apply_action({"type": "start_wave"}, now_ms)
					if start_res.get("success", false):
						wave_report["started_at_ms"] = now_ms
			
			# Decision 2: Place a tower
			var max_towers = 5 if gs.wave < 2 else 12 
			if gs.gold >= 100 and towers_placed < max_towers:
				if randf() < (skill_level + 0.2): # More likely to place early
					var choice: Dictionary = _choose_placement(gs, map_data["path"], path_samples)
					_print_placement_decision(choice)
					if choice.is_empty():
						wave_report["failed_placements"].append("no affordable legal path-aware placement")
					else:
						var ttype: String = choice["tower_type"]
						var pos: Vector2 = choice["pos"]
						var res = gs.apply_action({"type": "place_tower", "tower_type": ttype, "pos": pos}, now_ms)
						if res.get("success", false):
							towers_placed += 1
							wave_report["towers_placed"] += 1
							wave_report["tower_details"].append("%s#%d @ %s score=%.1f samples=%d" % [
								ttype, int(res.get("tower_id", -1)), _fmt_vec(pos),
								float(choice.get("score", 0.0)), int(choice.get("samples_covered", 0))
							])
						else:
							var reason: String = str(res.get("reason", "unknown"))
							wave_report["failed_placements"].append("%s @ %s: %s" % [ttype, _fmt_vec(pos), reason])
							choice["failure_reasons"][reason] = int(choice["failure_reasons"].get(reason, 0)) + 1
			
			# Decision 3: Upgrade
			if gs.gold >= 150 and not gs.towers.is_empty():
				if randf() < (skill_level * 0.5): # Learners upgrade less often
					var target_tower = gs.towers.pick_random()
					var upg_res = gs.apply_action({"type": "upgrade_base", "tower_id": target_tower.id}, now_ms)
					if upg_res.get("success", false):
						upgrades_bought += 1
						wave_report["upgrades_bought"] += 1
						wave_report["upgrade_details"].append("%s#%d -> L%d" % [target_tower.ttype, target_tower.id, target_tower.level])

		now_ms += tick_rate_ms
		total_ticks += 1
		
		# Safety break for infinite loops
		if total_ticks > 500000: # ~2.3 hours of game time
			print("Simulation timed out.")
			wave_report["ending_gold"] = gs.gold
			wave_report["result"] = "timed_out"
			wave_report["reason"] = _wave_reason(wave_report, gs)
			wave_reports.append(wave_report)
			break

	# Final Report
	_generate_report(gs, towers_placed, upgrades_bought, wave_reports, path_len)
	
	# Cleanup to prevent leaks
	gs.dispose()

func _new_wave_report(gs, now_ms: int) -> Dictionary:
	return {
		"wave": gs.wave,
		"started_at_ms": now_ms,
		"starting_gold": gs.gold,
		"ending_gold": gs.gold,
		"towers_placed": 0,
		"tower_details": [],
		"failed_placements": [],
		"upgrades_bought": 0,
		"upgrade_details": [],
		"enemies_spawned": 0,
		"enemies_killed": 0,
		"enemies_leaked": 0,
		"lives_lost": 0,
		"shop_cards_offered": "none",
		"shop_choice": "none",
		"target_checks": 0,
		"towers_with_targets": 0,
		"tower_fire_events": 0,
		"fired_by_type": {},
		"leak_candidates": [],
		"result": "incomplete",
		"reason": ""
	}

func _choose_placement(gs, path: Array, path_samples: Array) -> Dictionary:
	var best: Dictionary = {}
	for tower_type in _TT.TOWER_TYPES_LIST:
		var cost: int = int(_TT.TOWER_TYPES[tower_type]["cost"])
		if gs.gold < cost:
			continue
		var scored: Dictionary = _best_position_for_tower(gs, path, path_samples, tower_type)
		if scored.is_empty():
			continue
		if best.is_empty() or float(scored["score"]) > float(best["score"]):
			best = scored
	return best

func _best_position_for_tower(gs, path: Array, path_samples: Array, tower_type: String) -> Dictionary:
	var best: Dictionary = {}
	var rejected: int = 0
	var failure_reasons: Dictionary = {}
	var candidate_positions: Array = _candidate_positions_near_path(path)
	for pos in candidate_positions:
		var check: Array = gs.can_place_tower(pos, tower_type)
		if not bool(check[0]):
			rejected += 1
			var reason: String = str(check[1])
			failure_reasons[reason] = int(failure_reasons.get(reason, 0)) + 1
			continue
		var scored: Dictionary = _score_candidate(pos, path_samples, tower_type, gs.towers)
		if best.is_empty() or float(scored["score"]) > float(best["score"]):
			best = scored
	if best.is_empty():
		return {}
	best["tower_type"] = tower_type
	best["rejected_count"] = rejected
	best["failure_reasons"] = failure_reasons
	return best

func _candidate_positions_near_path(path: Array) -> Array:
	var candidates: Array = []
	var seen: Dictionary = {}
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var segment: Vector2 = b - a
		var length: float = segment.length()
		if length <= 0.0:
			continue
		var dir: Vector2 = segment / length
		var normal := Vector2(-dir.y, dir.x)
		var steps: int = maxi(2, int(ceil(length / PLACEMENT_SAMPLE_SPACING)))
		for step in range(steps + 1):
			var t: float = float(step) / float(steps)
			var anchor: Vector2 = a.lerp(b, t)
			for offset in PLACEMENT_OFFSETS:
				for side in [-1.0, 1.0]:
					var candidate: Vector2 = anchor + normal * offset * side
					var key := "%d:%d" % [roundi(candidate.x / 4.0), roundi(candidate.y / 4.0)]
					if seen.has(key):
						continue
					seen[key] = true
					candidates.append(candidate)
	return candidates

func _path_samples(path: Array, spacing: float) -> Array:
	var samples: Array = []
	var total_len: float = _path_length(path)
	var travelled: float = 0.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var segment_len: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(segment_len / spacing)))
		for step in range(steps):
			var t: float = float(step) / float(steps)
			var pos: Vector2 = a.lerp(b, t)
			var progress: float = 0.0 if total_len <= 0.0 else (travelled + segment_len * t) / total_len
			samples.append({"pos": pos, "progress": progress})
		travelled += segment_len
	samples.append({"pos": path[-1], "progress": 1.0})
	return samples

func _score_candidate(pos: Vector2, path_samples: Array, tower_type: String, existing_towers: Array) -> Dictionary:
	var tower_range: float = float(_TT.TOWER_TYPES[tower_type]["range"])
	var samples_covered: int = 0
	var score: float = 0.0
	for sample in path_samples:
		var sample_pos: Vector2 = sample["pos"]
		if pos.distance_to(sample_pos) <= tower_range:
			samples_covered += 1
			var progress: float = float(sample["progress"])
			score += 1.0
			if progress <= 0.35:
				score += 0.65
			elif progress <= 0.70:
				score += 0.35
	for tower in existing_towers:
		var d: float = pos.distance_to(tower.pos)
		if d < tower_range * 0.65:
			score -= 2.0
	return {
		"pos": pos,
		"score": score,
		"samples_covered": samples_covered
	}

func _print_placement_decision(choice: Dictionary) -> void:
	if choice.is_empty():
		print("Placement decision: no affordable legal path-aware candidate")
		return
	print("Placement decision: considered=%s chosen=%s score=%.1f samples=%d rejected=%d failures=%s" % [
		choice["tower_type"],
		_fmt_vec(choice["pos"]),
		float(choice.get("score", 0.0)),
		int(choice.get("samples_covered", 0)),
		int(choice.get("rejected_count", 0)),
		str(choice.get("failure_reasons", {}))
	])

func _tower_shot_times(gs) -> Dictionary:
	var times: Dictionary = {}
	for tower in gs.towers:
		times[tower.id] = tower.last_shot_ms
	return times

func _target_snapshot(gs, now_ms: int) -> Dictionary:
	var checks: int = 0
	var with_targets: int = 0
	for tower in gs.towers:
		checks += 1
		var target = tower.select_target(gs.enemies, now_ms)
		if target != null:
			with_targets += 1
	return {"checks": checks, "with_targets": with_targets}

func _accumulate_target_snapshot(report: Dictionary, snapshot: Dictionary) -> void:
	report["target_checks"] += int(snapshot.get("checks", 0))
	report["towers_with_targets"] += int(snapshot.get("with_targets", 0))

func _accumulate_fired_towers(report: Dictionary, gs, before: Dictionary) -> void:
	for tower in gs.towers:
		var prev: int = int(before.get(tower.id, tower.last_shot_ms))
		if tower.last_shot_ms != prev:
			report["tower_fire_events"] += 1
			var by_type: Dictionary = report["fired_by_type"]
			by_type[tower.ttype] = int(by_type.get(tower.ttype, 0)) + 1

func _append_limited(target: Array, additions: Array, limit: int) -> void:
	for item in additions:
		if target.size() >= limit:
			return
		target.append(item)

func _front_enemy_snapshot(enemies: Array, path_len: float, limit: int) -> Array:
	var rows: Array = []
	var sorted: Array = enemies.duplicate()
	sorted.sort_custom(func(a, b): return a.get_remaining_path_distance() < b.get_remaining_path_distance())
	for enemy in sorted.slice(0, mini(limit, sorted.size())):
		var remaining: float = enemy.get_remaining_path_distance()
		var progress: float = 0.0 if path_len <= 0.0 else 100.0 * (1.0 - remaining / path_len)
		rows.append("%s hp=%d progress=%.1f%% remaining=%.1f" % [enemy.type_name, enemy.health, progress, remaining])
	return rows

func _path_length(path: Array) -> float:
	var total: float = 0.0
	for i in range(path.size() - 1):
		total += Vector2(path[i]).distance_to(Vector2(path[i + 1]))
	return total

func _fmt_vec(pos: Vector2) -> String:
	return "(%.0f, %.0f)" % [pos.x, pos.y]

func _wave_reason(report: Dictionary, gs) -> String:
	if report["result"] == "passed":
		if int(report["lives_lost"]) > 0:
			return "eventually cleared, but leaks reduced the life buffer"
		return "cleared all spawned enemies without leaks"
	if int(report["lives_lost"]) > 0 and int(report["enemies_killed"]) == 0:
		return "enemies leaked before any kills; tower coverage or early damage was insufficient"
	if int(report["target_checks"]) > 0 and int(report["towers_with_targets"]) == 0:
		return "towers rarely had valid targets in range"
	if int(report["tower_fire_events"]) == 0 and gs.towers.size() > 0:
		return "towers were placed but did not fire during observed checks"
	if int(report["enemies_leaked"]) > 0:
		return "leaks exceeded the remaining life buffer"
	return "no single dominant cause observed"

func _generate_report(gs, placed, upgrades, wave_reports: Array, path_len: float):
	print("\n==========================================")
	print("       SIMULATION AUDIT REPORT            ")
	print("==========================================")
	print("Final State:      %s" % ("Victory" if gs.lives > 0 else "Defeat"))
	print("Waves Survived:   %d" % gs.wave)
	print("Lives Remaining:  %d / 10" % gs.lives)
	print("Gold Balance:     %d" % gs.gold)
	print("Towers Placed:    %d" % placed)
	print("Upgrades Bought:  %d" % upgrades)
	print("Total Kills:      %d" % gs.stat_enemies_killed)
	print("Gold Earned:      %d" % gs.stat_gold_earned)
	print("Enemies Remaining:%d" % gs.enemies.size())
	if not gs.enemies.is_empty():
		print("Front Enemies:    %s" % " | ".join(_front_enemy_snapshot(gs.enemies, path_len, 5)))
	print("Final Towers:     %s" % _final_tower_summary(gs))
	print("------------------------------------------")
	print("Wave Diagnostics:")
	for report in wave_reports:
		_print_wave_report(report)
	print("------------------------------------------")
	print("Auditor Notes:")
	if gs.lives == 10:
		print("- Balance seems EASY for this skill level.")
	elif gs.lives > 0:
		print("- Balance seems STABLE. Player survived with pressure.")
	else:
		print("- Bot defeat cause: %s" % _final_defeat_cause(wave_reports))
	
	if gs.gold > 500:
		print("- Economic Warning: Player accumulated excess gold. Costs may be too low or choices too few.")
	print("==========================================\n")

func _print_wave_report(report: Dictionary) -> void:
	print("- Wave %d: %s" % [report["wave"], report["result"]])
	print("  Gold: %d -> %d | Placed: %d | Upgrades: %d | Spawned: %d | Killed: %d | Leaked: %d | Lives Lost: %d" % [
		report["starting_gold"], report["ending_gold"], report["towers_placed"], report["upgrades_bought"],
		report["enemies_spawned"], report["enemies_killed"], report["enemies_leaked"], report["lives_lost"]
	])
	print("  Towers: %s" % _join_or_none(report["tower_details"]))
	print("  Upgrades: %s" % _join_or_none(report["upgrade_details"]))
	if not report["failed_placements"].is_empty():
		print("  Failed placements: %s" % " | ".join(report["failed_placements"]))
	print("  Shop: offered=%s, choice=%s" % [report["shop_cards_offered"], report["shop_choice"]])
	print("  Targeting: checks=%d, with_targets=%d, fire_events=%d, by_type=%s" % [
		report["target_checks"], report["towers_with_targets"], report["tower_fire_events"], str(report["fired_by_type"])
	])
	if not report["leak_candidates"].is_empty():
		print("  Leak candidates before life loss: %s" % " | ".join(report["leak_candidates"]))
	print("  Reason: %s" % report["reason"])

func _join_or_none(items: Array) -> String:
	return "none" if items.is_empty() else " | ".join(items)

func _final_defeat_cause(wave_reports: Array) -> String:
	for i in range(wave_reports.size() - 1, -1, -1):
		var report: Dictionary = wave_reports[i]
		if report.get("result", "") == "failed":
			return report.get("reason", "Unknown")
	return "Unknown"

func _final_tower_summary(gs) -> String:
	var rows: Array = []
	for tower in gs.towers:
		rows.append("%s#%d L%d @ %s last_shot=%dms" % [
			tower.ttype, tower.id, tower.level, _fmt_vec(tower.pos), tower.last_shot_ms
		])
	return _join_or_none(rows)
