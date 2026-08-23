# AGES v2 Generic Scenario IR Runner
# Executes a serialized execution plan (execution_plan.json). Scenario IDs never
# hardcode behavior — only plan steps do.
extends SceneTree

const GameStateClass = preload("res://simulation/core/GameState.gd")

var plan: Dictionary = {}
var steps: Array = []
var step_idx: int = 0
var run_dir: String = ""
var scenario_id: String = ""
var scenario_hash: String = ""
var screenshot_mode: String = "auto"
var gs = null
var live_screen: Node = null
var tel_file: FileAccess
var evt_file: FileAccess
var assertions_passed: int = 0
var assertions_failed: int = 0
var checkpoints_recorded: Array = []
var tick_count: int = 0
var sim_ms: int = 1000
var wait_frames_left: int = 0
var wait_ticks_left: int = 0
var running: bool = false
var finished: bool = false
var last_error: String = ""
var screenshot_meta: Dictionary = {}  # checkpoint -> {path, provenance, unique_colors, variance}
var input_path_used: String = "none"  # engine_parse_input_event | none
var launch_kind: String = "none"  # gamestate | scene

func _initialize() -> void:
	var all_args: Array = []
	all_args.append_array(OS.get_cmdline_args())
	all_args.append_array(OS.get_cmdline_user_args())

	var plan_path := ""
	for i in range(all_args.size()):
		if all_args[i] == "--run-dir" and i + 1 < all_args.size():
			run_dir = str(all_args[i + 1]).replace("\\", "/")
		elif all_args[i] == "--plan" and i + 1 < all_args.size():
			plan_path = str(all_args[i + 1]).replace("\\", "/")
		elif all_args[i] == "--scenario-id" and i + 1 < all_args.size():
			scenario_id = str(all_args[i + 1])

	if run_dir == "":
		run_dir = "C:/Workspace/Project_Games/ManaNet/.agent-game/runs/latest"
	DirAccess.make_dir_recursive_absolute(run_dir)

	if plan_path == "":
		plan_path = run_dir + "/execution_plan.json"

	if not FileAccess.file_exists(plan_path):
		_fail_hard("execution_plan.json missing: " + plan_path)
		return

	var f := FileAccess.open(plan_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail_hard("Invalid execution plan JSON")
		return

	plan = parsed
	scenario_hash = str(plan.get("scenario_hash", ""))
	if scenario_id == "":
		scenario_id = str(plan.get("scenario", {}).get("id", "unknown"))
	screenshot_mode = str(plan.get("screenshot_mode", "auto"))
	steps = plan.get("steps", [])

	tel_file = FileAccess.open(run_dir + "/telemetry.jsonl", FileAccess.WRITE)
	evt_file = FileAccess.open(run_dir + "/events.jsonl", FileAccess.WRITE)

	print("\n============================================================")
	print("  AGES v2 SCENARIO RUNNER (IR): ", scenario_id)
	print("  Plan steps: ", steps.size())
	print("  Target Directory: ", run_dir)
	print("============================================================\n")

	set_auto_accept_quit(false)
	if root != null:
		root.close_requested.connect(func():
			print("[AGES] root.close_requested ignored")
		)

	running = true
	# Defer first advance so SceneTree process loop is active (required for scene _ready).
	call_deferred("_advance")

func _process(_delta: float) -> bool:
	# MainLoop contract (Godot 4): return TRUE to quit, FALSE to keep running.
	if finished:
		return true
	if not running:
		return false

	if wait_frames_left > 0:
		wait_frames_left -= 1
		if wait_frames_left > 0:
			return false
		# frames done — fall through to ticks or advance

	if wait_ticks_left > 0:
		if gs == null and live_screen != null and live_screen.get("game_state") != null:
			gs = live_screen.game_state
		if gs != null:
			tick_count += 1
			sim_ms += 16
			gs.update_simulation(sim_ms)
		wait_ticks_left -= 1
		if wait_ticks_left > 0:
			return false

	_advance()
	return finished

func _advance() -> void:
	while step_idx < steps.size():
		var step: Dictionary = steps[step_idx]
		step_idx += 1
		var op := str(step.get("op", ""))
		var ok := true
		match op:
			"launch":
				ok = _op_launch(step)
			"wait":
				ok = _op_wait(step)
				if ok and (wait_frames_left > 0 or wait_ticks_left > 0):
					return  # resume via _process
			"checkpoint":
				ok = _op_checkpoint(step)
			"domain_action":
				ok = _op_domain_action(step)
			"input_action":
				ok = _op_input_action(step)
			"pointer_touch":
				ok = _op_pointer_touch(step)
			"assert":
				ok = _op_assert(step)
			_:
				ok = false
				last_error = "Unknown operation in runner: " + op
		if not ok:
			_finish(false)
			return
		# Yield to _process when frames/ticks were requested by the last op
		if wait_frames_left > 0 or wait_ticks_left > 0:
			return
	_finish(true)

func _op_launch(step: Dictionary) -> bool:
	var entry := str(step.get("entrypoint", ""))
	if entry.ends_with(".tscn"):
		var packed: PackedScene = load(entry)
		if packed == null:
			last_error = "Failed to load scene: " + entry
			return false
		var inst: Node = packed.instantiate()
		root.add_child(inst)
		# Keep GameScreen._process off during harness waits; re-enable before screenshots.
		if inst.has_method("set_process"):
			inst.set_process(false)
		live_screen = inst
		launch_kind = "scene"
		wait_frames_left = max(wait_frames_left, 8)
		if inst.get("game_state") != null:
			gs = inst.game_state
		return true
	elif entry.ends_with("GameState.gd") or entry.find("GameState") >= 0:
		gs = GameStateClass.new()
		launch_kind = "gamestate"
		return true
	else:
		# Generic script class fallback
		var scr = load(entry)
		if scr == null:
			last_error = "Failed to load entrypoint: " + entry
			return false
		if scr.can_instantiate():
			var obj = scr.new()
			if obj is Node:
				root.add_child(obj)
				live_screen = obj
				launch_kind = "scene"
				wait_frames_left = 4
			else:
				gs = obj
				launch_kind = "gamestate"
			return true
		last_error = "Unsupported entrypoint: " + entry
		return false

func _op_wait(step: Dictionary) -> bool:
	var ticks = int(step.get("ticks", 0) or 0)
	var frames = int(step.get("frames", 0) or 0)
	if ticks <= 0 and frames <= 0 and step.get("duration_ms") != null:
		frames = max(1, int(ceil(float(step.get("duration_ms")) / 16.0)))
	wait_ticks_left = ticks
	wait_frames_left = frames
	return true

func _op_checkpoint(step: Dictionary) -> bool:
	var name := str(step.get("name", "checkpoint"))
	_record_checkpoint(name, tick_count)
	return true

func _op_domain_action(step: Dictionary) -> bool:
	if gs == null and live_screen != null and live_screen.get("game_state") != null:
		gs = live_screen.game_state
	if gs == null:
		last_error = "domain_action requires launched GameState"
		return false
	var action_type := str(step.get("action", ""))
	var params: Dictionary = step.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	var action: Dictionary = {"type": action_type}
	for k in params.keys():
		var v = params[k]
		if k == "pos" and typeof(v) == TYPE_ARRAY and v.size() >= 2:
			action[k] = Vector2(float(v[0]), float(v[1]))
		else:
			action[k] = v
	var res: Dictionary = gs.apply_action(action, sim_ms)
	if evt_file:
		evt_file.store_line(JSON.stringify({
			"tick": tick_count,
			"event_name": action_type,
			"source": "domain",
			"data": action,
			"result_success": res.get("success", false),
			"timestamp_utc": "2026-08-12T00:00:00Z"
		}))
	return true  # domain may fail intentionally; asserts decide

func _op_input_action(step: Dictionary) -> bool:
	var action := str(step.get("action", ""))
	var params: Dictionary = step.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}

	if action == "block_ui_input":
		return _install_blocking_overlay()
	if action == "enter_placement" or action == "place_tower_archer":
		var ttype := str(params.get("tower_type", "archer"))
		if action == "place_tower_archer":
			ttype = "archer"
		return _enter_placement(ttype)
	if action == "clear_ui_block":
		return _clear_blocking_overlay()
	if action == "force_onboarding":
		return _set_onboarding(true)
	if action == "clear_onboarding":
		return _set_onboarding(false)
	if action == "set_placement_mode":
		return _set_placement_mode(str(params.get("mode", "drop")))

	last_error = "Unknown input_action: " + action
	return false

func _set_placement_mode(mode: String) -> bool:
	if live_screen == null:
		last_error = "set_placement_mode requires launched scene"
		return false
	var vs = live_screen.get("view_state")
	if vs == null:
		last_error = "view_state not ready"
		return false
	if mode != "drop" and mode != "drag":
		last_error = "invalid placement mode: " + mode
		return false
	vs.placement_mode = mode
	vs.confirm_placement_enabled = false
	return true

func _set_onboarding(enabled: bool) -> bool:
	if live_screen == null:
		last_error = "onboarding requires launched scene"
		return false
	var vs = live_screen.get("view_state")
	if vs == null:
		last_error = "view_state not ready"
		return false
	vs.show_onboarding = enabled
	if enabled:
		vs.onboarding_dismissed = false
		if vs.has_method("set_instruction"):
			vs.set_instruction("AGES_ONBOARDING_MODAL")
	else:
		vs.onboarding_dismissed = true
		if vs.has_method("clear_instruction"):
			vs.clear_instruction()
	if evt_file:
		evt_file.store_line(JSON.stringify({
			"tick": tick_count,
			"event_name": "onboarding_set",
			"source": "runtime",
			"data": {"enabled": enabled},
			"timestamp_utc": "2026-08-12T00:00:00Z"
		}))
	return true

func _enter_placement(tower_type: String) -> bool:
	if live_screen == null:
		last_error = "enter_placement requires launched scene"
		return false
	var vs = live_screen.get("view_state")
	if vs == null:
		last_error = "view_state not ready (scene _ready incomplete?)"
		return false
	if vs.has_method("enter_placement"):
		vs.enter_placement(tower_type)
		return true
	last_error = "view_state.enter_placement missing"
	return false

func _install_blocking_overlay() -> bool:
	if live_screen == null:
		last_error = "block_ui_input requires launched scene"
		return false
	var hud = live_screen.get("hud_layer")
	if hud == null:
		last_error = "hud_layer not ready"
		return false
	var vp_size: Vector2 = root.get_visible_rect().size
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		vp_size = Vector2(900, 600)
	var modal := ColorRect.new()
	modal.name = "AgesBlockingModal"
	modal.color = Color(0, 0, 0, 0.35)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.position = Vector2.ZERO
	modal.size = vp_size
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(modal)
	if evt_file:
		evt_file.store_line(JSON.stringify({
			"tick": tick_count,
			"event_name": "ui_block_installed",
			"source": "runtime",
			"data": {"size": [vp_size.x, vp_size.y]},
			"timestamp_utc": "2026-08-12T00:00:00Z"
		}))
	wait_frames_left = max(wait_frames_left, 2)
	return true

func _clear_blocking_overlay() -> bool:
	if live_screen == null:
		return true
	var hud = live_screen.get("hud_layer")
	if hud == null:
		return true
	var existing = hud.get_node_or_null("AgesBlockingModal")
	if existing:
		existing.queue_free()
	return true

func _op_pointer_touch(step: Dictionary) -> bool:
	var pos_arr = step.get("position", [0, 0])
	if typeof(pos_arr) != TYPE_ARRAY or pos_arr.size() < 2:
		last_error = "pointer_touch missing position"
		return false
	var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))

	# Engine-level injection — NEVER call _input() directly.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	Input.parse_input_event(release)

	input_path_used = "engine_parse_input_event"
	if evt_file:
		evt_file.store_line(JSON.stringify({
			"tick": tick_count,
			"event_name": "pointer_touch",
			"source": "runtime",
			"data": {"position": [pos.x, pos.y], "path": input_path_used},
			"timestamp_utc": "2026-08-12T00:00:00Z"
		}))
	# Allow input queue + GameScreen handlers to process
	wait_frames_left = max(wait_frames_left, 3)
	return true

func _op_assert(step: Dictionary) -> bool:
	var target := str(step.get("target", ""))
	var op := str(step.get("operator", "equals"))
	var expected = step.get("value")
	var actual = _resolve_target(target)
	var passed := _compare(actual, op, expected)
	if passed:
		assertions_passed += 1
	else:
		assertions_failed += 1
		print("ASSERT FAIL: ", target, " ", op, " ", expected, " actual=", actual)
	return true  # keep running; overall status from counts

func _resolve_target(target: String):
	var snap = _get_snapshot()
	if target.begins_with("telemetry.state_snapshot."):
		var path = target.substr("telemetry.state_snapshot.".length()).split(".")
		var cur = snap
		for p in path:
			if typeof(cur) == TYPE_DICTIONARY and cur.has(p):
				cur = cur[p]
			else:
				return null
		return cur
	if target == "telemetry.state_snapshot.towers_count":
		return snap.get("towers_count", null)
	return null

func _compare(actual, op: String, expected) -> bool:
	match op:
		"equals":
			return actual == expected
		"not_equals":
			return actual != expected
		"less_than":
			return actual != null and float(actual) < float(expected)
		"less_than_or_equal":
			return actual != null and float(actual) <= float(expected)
		"greater_than":
			return actual != null and float(actual) > float(expected)
		"greater_than_or_equal":
			return actual != null and float(actual) >= float(expected)
		"contains":
			return str(expected) in str(actual)
		"in":
			return actual in expected
	return false

func _get_snapshot() -> Dictionary:
	# Prefer live GameScreen state
	var state = gs
	if live_screen != null and live_screen.get("game_state") != null:
		state = live_screen.game_state
	if state == null:
		return {"player": {"lives": null, "gold": null}, "towers_count": null, "wave": null}
	return {
		"player": {"lives": state.lives, "gold": state.gold},
		"towers_count": state.towers.size(),
		"wave": state.wave
	}

func _record_checkpoint(name: String, tick: int) -> void:
	checkpoints_recorded.append(name)
	var snap = _get_snapshot()
	var snapshot_data = {
		"tick": tick,
		"checkpoint_name": name,
		"timestamp_utc": "2026-08-12T00:00:00Z",
		"state_snapshot": snap,
		"metrics": {
			"fps": {"value": Engine.get_frames_per_second(), "provenance": "ENGINE"},
			"draw_calls": {"value": -1, "provenance": "UNAVAILABLE"}
		},
		"input_path": input_path_used,
		"launch_kind": launch_kind
	}
	if tel_file:
		tel_file.store_line(JSON.stringify(snapshot_data))

	_maybe_capture_screenshot(name, tick)

func _maybe_capture_screenshot(name: String, tick: int) -> void:
	# Domain-only GameState launches cannot claim real screenshots.
	if screenshot_mode == "none":
		return
	if launch_kind == "gamestate" and screenshot_mode != "real":
		return

	# Re-enable scene processing briefly so renderer can produce pixels.
	if live_screen != null and live_screen.has_method("set_process"):
		live_screen.set_process(true)
		if live_screen.get("renderer") != null and live_screen.renderer.has_method("render_frame"):
			live_screen.renderer.render_frame(Time.get_ticks_msec())

	var screenshots_dir = run_dir + "/screenshots"
	DirAccess.make_dir_recursive_absolute(screenshots_dir)
	var screenshot_path = screenshots_dir + "/%03d_%s.png" % [tick, name]

	var img: Image = null
	var provenance := "UNAVAILABLE"
	var vp = root
	if vp != null and vp.get_texture() != null:
		img = vp.get_texture().get_image()
		if img != null:
			provenance = "VIEWPORT"

	# REAL_SCREENSHOT_CAPTURE path: never write synthetic fills as capability proof.
	if img == null:
		screenshot_meta[name] = {
			"path": screenshot_path,
			"provenance": "UNAVAILABLE",
			"error": "viewport image null"
		}
		return

	img.save_png(screenshot_path)
	var stats = _image_stats(img)
	stats["path"] = screenshot_path
	stats["provenance"] = provenance
	screenshot_meta[name] = stats

func _image_stats(img: Image) -> Dictionary:
	var w = img.get_width()
	var h = img.get_height()
	var unique := {}
	var sum_r := 0.0
	var sum_g := 0.0
	var sum_b := 0.0
	var n = w * h
	var step = max(1, int(n / 50000))  # subsample for speed
	var count = 0
	for y in range(h):
		for x in range(w):
			if ((y * w + x) % step) != 0:
				continue
			var c: Color = img.get_pixel(x, y)
			var key = "%d_%d_%d" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
			unique[key] = true
			sum_r += c.r
			sum_g += c.g
			sum_b += c.b
			count += 1
	var mean_r = sum_r / max(1, count)
	var mean_g = sum_g / max(1, count)
	var mean_b = sum_b / max(1, count)
	var var_acc := 0.0
	count = 0
	for y in range(h):
		for x in range(w):
			if ((y * w + x) % step) != 0:
				continue
			var c2: Color = img.get_pixel(x, y)
			var_acc += (c2.r - mean_r) * (c2.r - mean_r)
			var_acc += (c2.g - mean_g) * (c2.g - mean_g)
			var_acc += (c2.b - mean_b) * (c2.b - mean_b)
			count += 1
	return {
		"width": w,
		"height": h,
		"unique_colors_sampled": unique.size(),
		"variance_approx": var_acc / max(1, count),
		"mean_rgb": [mean_r, mean_g, mean_b]
	}

func _finish(ok: bool) -> void:
	if finished:
		return
	finished = true
	running = false

	# Refresh gs from live screen before final asserts already done
	if live_screen != null and live_screen.get("game_state") != null:
		gs = live_screen.game_state

	if tel_file:
		tel_file.close()
	if evt_file:
		evt_file.close()

	var overall = "PASS" if (ok and assertions_failed == 0 and last_error == "") else "FAIL"
	if last_error != "" and overall == "PASS":
		overall = "FAIL"

	var result_data = {
		"status": overall,
		"scenario_id": scenario_id,
		"scenario_hash": scenario_hash,
		"ticks_simulated": tick_count,
		"checkpoints": checkpoints_recorded,
		"assertions_passed": assertions_passed,
		"assertions_failed": assertions_failed,
		"input_path": input_path_used,
		"launch_kind": launch_kind,
		"screenshot_meta": screenshot_meta,
		"error": last_error
	}
	var res_file = FileAccess.open(run_dir + "/result.json", FileAccess.WRITE)
	if res_file:
		res_file.store_string(JSON.stringify(result_data, "\t"))
		res_file.close()

	print("\n============================================================")
	print("  SCENARIO RESULT: ", overall)
	print("  Assertions Passed: ", assertions_passed)
	print("  Assertions Failed: ", assertions_failed)
	if last_error != "":
		print("  Error: ", last_error)
	print("============================================================\n")
	quit(0 if overall == "PASS" else 1)

func _fail_hard(msg: String) -> void:
	last_error = msg
	print("[AGES ERROR] ", msg)
	_finish(false)
