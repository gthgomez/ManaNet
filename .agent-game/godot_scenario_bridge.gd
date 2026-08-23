# ManaNet Project Scenario Bridge
# Implements ProjectScenarioBridge interface for ManaNet domain logic.
extends RefCounted

const GameStateClass = preload("res://simulation/core/GameState.gd")

var harness = null
var live_scene: Node = null
var gs = null

func setup(context: Dictionary) -> void:
	harness = context.get("harness")
	live_scene = context.get("live_scene")
	var domain_obj = context.get("domain_object")
	if domain_obj != null:
		gs = domain_obj
	elif live_scene != null and live_scene.get("game_state") != null:
		gs = live_scene.game_state
	elif gs == null:
		gs = GameStateClass.new()

func _ensure_game_state():
	if gs == null and live_scene != null and live_scene.get("game_state") != null:
		gs = live_scene.game_state
	if gs == null:
		gs = GameStateClass.new()
	return gs

func snapshot_state() -> Dictionary:
	var state = _ensure_game_state()
	if state == null:
		return {"player": {"lives": null, "gold": null}, "towers_count": null, "wave": null}
	return {
		"player": {"lives": state.lives, "gold": state.gold},
		"towers_count": state.towers.size(),
		"wave": state.wave
	}

func perform_domain_action(action: Dictionary, sim_ms: int) -> Dictionary:
	var state = _ensure_game_state()
	if state == null:
		return {"success": false, "error": "ManaNet GameState not available"}
	return state.apply_action(action, sim_ms)

func tick_simulation(sim_ms: int) -> void:
	var state = _ensure_game_state()
	if state != null and state.has_method("update_simulation"):
		state.update_simulation(sim_ms)

func resolve_semantic_target(target_id: String, root_node: Node) -> Dictionary:
	# Semantic alias resolution for ManaNet HUD and board
	if target_id == "hud.shop.archer" or target_id == "shop.archer":
		return {"ok": true, "position": Vector2(160, 560), "size": Vector2(60, 60)}
	if target_id == "hud.shop.frost" or target_id == "shop.frost":
		return {"ok": true, "position": Vector2(240, 560), "size": Vector2(60, 60)}
	if target_id == "hud.wave_button" or target_id == "wave_btn":
		return {"ok": true, "position": Vector2(820, 560), "size": Vector2(80, 50)}

	return {"ok": false, "error": "ManaNet bridge could not resolve target: " + target_id}

func handle_input_action(action: String, params: Dictionary) -> Dictionary:
	if action == "enter_placement" or action == "place_tower_archer":
		var ttype := str(params.get("tower_type", "archer"))
		if action == "place_tower_archer":
			ttype = "archer"
			var pos_val = params.get("position", params.get("pos"))
			if pos_val != null and typeof(pos_val) == TYPE_ARRAY and pos_val.size() >= 2:
				var state = _ensure_game_state()
				if state != null:
					state.apply_action({"type": "place_tower", "tower_type": "archer", "pos": Vector2(float(pos_val[0]), float(pos_val[1]))}, 0)
					return {"ok": true}
		if live_scene == null:
			return {"ok": false, "error": "enter_placement requires active scene"}
		var vs = live_scene.get("view_state")
		if vs == null or not vs.has_method("enter_placement"):
			return {"ok": false, "error": "view_state not ready"}
		vs.enter_placement(ttype)
		return {"ok": true}

	if action == "set_placement_mode":
		if live_scene == null:
			return {"ok": false, "error": "set_placement_mode requires active scene"}
		var vs = live_scene.get("view_state")
		if vs == null:
			return {"ok": false, "error": "view_state not ready"}
		var mode = str(params.get("mode", "drop"))
		vs.placement_mode = mode
		vs.confirm_placement_enabled = false
		return {"ok": true}

	if action == "force_onboarding" or action == "clear_onboarding":
		if live_scene == null:
			return {"ok": false, "error": "onboarding action requires active scene"}
		var vs = live_scene.get("view_state")
		if vs == null:
			return {"ok": false, "error": "view_state not ready"}
		var enabled = (action == "force_onboarding")
		vs.show_onboarding = enabled
		if enabled:
			vs.onboarding_dismissed = false
			if vs.has_method("set_instruction"):
				vs.set_instruction("AGES_ONBOARDING_MODAL")
		else:
			vs.onboarding_dismissed = true
			if vs.has_method("clear_instruction"):
				vs.clear_instruction()
		return {"ok": true}

	return {"ok": false, "error": "Unhandled input_action in ManaNet bridge: " + action}

func teardown() -> void:
	harness = null
	live_scene = null
	gs = null
