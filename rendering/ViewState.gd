class_name ViewState

# Port of view_state.py — UI animation state, screen shake, panel visibility.
# Plain GDScript class owned by GameScreen. No Node.

const _MAPS := preload("res://data/maps.gd")

# Screen shake
var shake_started: int = 0
var shake_amplitude: float = 0.0
var shake_duration_ms: int = 0

# Tower panel / shop state
var selected_tower_id: int = -1      # -1 = none
var placement_active: bool = false
var placement_mode: String = "drag"
var placement_tower_type: String = ""
var placement_ghost_pos: Vector2 = Vector2.ZERO
var placement_ghost_valid: bool = false
var confirm_placement_enabled: bool = false
var pending_placement_pos: Vector2 = Vector2.ZERO
var pending_placement_type: String = ""
var pending_placement_valid: bool = false

# Confirmation dialogs
var confirm_sell: bool = false
var confirm_restart: bool = false
var promotion_pending: bool = false

# Action toasts — auto-expire, used for upgrade feedback / errors
var toast_text: String = ""
var toast_until_ms: int = 0

# Instruction banner — persistent until explicitly cleared, used for placement hints / modifier reminders
var instruction_banner: String = ""

# Onboarding
var onboarding_dismissed: bool = false
var show_onboarding: bool = false

# Speed / pause button state (mirrors what GameState exposes, cached here for HUD)
var displayed_speed: float = 1.0

func configure_from_settings(settings: Dictionary) -> void:
	placement_mode = str(settings.get("placement_mode", "drag"))
	if placement_mode != "drop":
		placement_mode = "drag"
	confirm_placement_enabled = bool(settings.get("confirm_placement_enabled", false))

func start_screen_shake(now_ms: int, amplitude: float = 6.0, duration_ms: int = 380) -> void:
	shake_started = now_ms
	shake_amplitude = amplitude
	shake_duration_ms = duration_ms

func get_screen_shake_offset(now_ms: int) -> Vector2:
	var elapsed: int = now_ms - shake_started
	if elapsed > shake_duration_ms or shake_amplitude <= 0.0:
		return Vector2.ZERO
	var decay: float = 1.0 - float(elapsed) / float(shake_duration_ms)
	var amp: float = shake_amplitude * decay
	var t: float = float(elapsed) / 28.0
	var sx: float = sin(t * 3.8) * amp
	var sy: float = cos(t * 4.9) * amp * 0.45
	return Vector2(sx, sy)

func show_toast(text: String, now_ms: int, duration_ms: int = 1400) -> void:
	toast_text = text
	toast_until_ms = now_ms + duration_ms

func get_toast(now_ms: int) -> String:
	if now_ms < toast_until_ms:
		return toast_text
	return ""

func set_instruction(text: String) -> void:
	instruction_banner = text

func clear_instruction() -> void:
	instruction_banner = ""

func tick(now_ms: int) -> void:
	if now_ms >= toast_until_ms:
		toast_text = ""

func deselect_tower() -> void:
	selected_tower_id = -1
	confirm_sell = false
	promotion_pending = false

func enter_placement(tower_type: String) -> void:
	if placement_active and placement_tower_type == tower_type:
		exit_placement()
		return
	placement_active = true
	placement_tower_type = tower_type
	selected_tower_id = -1
	clear_pending_placement()

func exit_placement() -> void:
	placement_active = false
	placement_tower_type = ""
	placement_ghost_pos = Vector2.ZERO
	placement_ghost_valid = false

func set_pending_placement(pos: Vector2, tower_type: String, valid: bool) -> void:
	pending_placement_pos = pos
	pending_placement_type = tower_type
	pending_placement_valid = valid

func clear_pending_placement() -> void:
	pending_placement_pos = Vector2.ZERO
	pending_placement_type = ""
	pending_placement_valid = false

func has_pending_placement() -> bool:
	return pending_placement_type != ""
