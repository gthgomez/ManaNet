class_name InputController

# Port of input_controller_kivy.py — translates Godot input events into
# action dicts compatible with GameState.apply_action().
#
# Action dict format (mirrors Python):
#   {"type": "place_tower",     "tower_type": str, "pos": Vector2}
#   {"type": "select_tower",    "tower_id": int}
#   {"type": "upgrade_base",    "tower_id": int}
#   {"type": "upgrade_path",    "tower_id": int, "path": str}
#   {"type": "confirm_promotion","tower_id": int}
#   {"type": "cancel_promotion","tower_id": int}
#   {"type": "sell_tower",      "tower_id": int}
#   {"type": "cycle_target_mode","tower_id": int}
#   {"type": "start_wave"}
#   {"type": "toggle_pause"}
#   {"type": "set_speed",       "multiplier": float}
#   {"type": "restart_game"}

const _MAPS := preload("res://data/maps.gd")

var game_state: GameState = null
var view_state: Object = null

# HUD hit regions — set by GameScreen after layout is known
var _wave_btn_rect: Rect2    = Rect2(0, 0, 0, 0)
var _pause_btn_rect: Rect2   = Rect2(0, 0, 0, 0)
var _speed1_rect: Rect2      = Rect2(0, 0, 0, 0)
var _speed2_rect: Rect2      = Rect2(0, 0, 0, 0)
var _speed3_rect: Rect2      = Rect2(0, 0, 0, 0)
var _sell_btn_rect: Rect2    = Rect2(0, 0, 0, 0)
var _target_btn_rect: Rect2  = Rect2(0, 0, 0, 0)
var _shop_rects: Dictionary  = {}   # tower_type -> Rect2
var _upgrade_rects: Array    = []   # [{path, rect, tower_id}]
var _base_upgrade_rect: Rect2 = Rect2(0,0,0,0)

# Drag / placement tracking
var _touch_start: Vector2 = Vector2.ZERO
var _touch_moved: bool = false
const DRAG_THRESHOLD: float = 8.0

# ---------------------------------------------------------------------------
# HUD registration (called by GameScreen._ready or after layout)
# ---------------------------------------------------------------------------

func register_hud(wave_btn: Rect2, pause_btn: Rect2,
				  speed1: Rect2, speed2: Rect2, speed3: Rect2,
				  sell_btn: Rect2, target_btn: Rect2,
				  shop: Dictionary, upgrade_rects: Array,
				  base_upgrade: Rect2) -> void:
	_wave_btn_rect   = wave_btn
	_pause_btn_rect  = pause_btn
	_speed1_rect     = speed1
	_speed2_rect     = speed2
	_speed3_rect     = speed3
	_sell_btn_rect   = sell_btn
	_target_btn_rect = target_btn
	_shop_rects      = shop
	_upgrade_rects   = upgrade_rects
	_base_upgrade_rect = base_upgrade

# ---------------------------------------------------------------------------
# Public entry points called by GameScreen._input()
# ---------------------------------------------------------------------------

func handle_press(pos: Vector2, now_ms: int) -> Dictionary:
	_touch_start = pos
	_touch_moved = false

	if view_state == null or game_state == null:
		return {}

	# Dismiss the upgrade-path tutorial only while it is visible.
	if view_state.show_onboarding:
		view_state.onboarding_dismissed = true
		view_state.show_onboarding = false
		return {}

	# --- Confirmation dialogs take priority ---
	if view_state.confirm_restart:
		view_state.confirm_restart = false
		return {"type": "restart_game"}

	if view_state.confirm_sell and view_state.selected_tower_id >= 0:
		view_state.confirm_sell = false
		return {"type": "sell_tower", "tower_id": view_state.selected_tower_id}

	if view_state.promotion_pending and view_state.selected_tower_id >= 0:
		return {}

	if view_state.has_pending_placement():
		return {}

	# --- Placement mode ---
	if view_state.placement_active:
		if pos.y < _MAPS.HEIGHT - 115.0:
			var tower_under: Tower = _tower_at(pos)
			if tower_under != null:
				view_state.exit_placement()
				view_state.selected_tower_id = tower_under.id
				return {"type": "select_tower", "tower_id": tower_under.id}

			if view_state.placement_mode == "drop":
				var tower_type: String = view_state.placement_tower_type
				var check: Array = game_state.can_place_tower(pos, tower_type) if game_state else [true, ""]
				if view_state.confirm_placement_enabled:
					view_state.set_pending_placement(pos, tower_type, check[0])
					view_state.exit_placement()
					return {}
				else:
					return {"type": "place_tower", "tower_type": tower_type, "pos": pos}
			else:
				# In drag mode, we just start the touch tracking and let release handle it.
				view_state.placement_ghost_pos = pos
				return {}
		else:
			# Clicked back in shop/UI while placing handled by toggle logic in ViewState/GameScreen
			return {}

	# HUD controls are handled by Godot button signals in GameScreen.
	# This controller receives world-space positions, so screen-space HUD
	# rectangles are intentionally not used here.

	# --- Game world: select tower ---
	var clicked_tower: Tower = _tower_at(pos)
	if clicked_tower != null:
		view_state.selected_tower_id = clicked_tower.id
		return {"type": "select_tower", "tower_id": clicked_tower.id}

	# Tap on empty space — deselect
	view_state.deselect_tower()
	return {}

const TOUCH_OFFSET_Y: float = -62.0

func handle_drag(pos: Vector2, _now_ms: int) -> void:
	if (pos - _touch_start).length() > DRAG_THRESHOLD:
		_touch_moved = true
	if view_state != null and view_state.placement_active:
		# Apply offset so finger doesn't obscure the placement location
		view_state.placement_ghost_pos = pos + Vector2(0, TOUCH_OFFSET_Y)
		if game_state != null:
			var check: Array = game_state.can_place_tower(view_state.placement_ghost_pos, view_state.placement_tower_type)
			view_state.placement_ghost_valid = check[0]

func handle_release(pos: Vector2, now_ms: int) -> Dictionary:
	# In drag placement mode: release finalises the placement
	if view_state != null and view_state.placement_active and view_state.placement_mode == "drag":
		if pos.y < _MAPS.HEIGHT - 115.0:
			var tower_type: String = view_state.placement_tower_type
			var final_pos = view_state.placement_ghost_pos
			var check: Array = [true, "OK"]
			if game_state != null:
				check = game_state.can_place_tower(final_pos, tower_type)
			var valid: bool = bool(check[0])
			
			if view_state.confirm_placement_enabled:
				view_state.set_pending_placement(final_pos, tower_type, valid)
				view_state.exit_placement()
				return {}
			
			if not valid:
				view_state.exit_placement()
				return {"type": "placement_failed", "reason": str(check[1])}

			return {"type": "place_tower", "tower_type": tower_type, "pos": final_pos}
		else:
			# Released back in shop area - cancel placement
			view_state.exit_placement()
			return {}
	return {}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tower_at(pos: Vector2) -> Tower:
	if game_state == null:
		return null
	# Iterate reversed so top-rendered tower wins on overlap
	var towers: Array = game_state.towers.duplicate()
	towers.reverse()
	for tower in towers:
		if pos.distance_to(tower.pos) <= float(tower.radius) + 4.0:
			return tower
	return null
