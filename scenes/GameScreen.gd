extends Node2D
class_name GameScreen

# Main game screen — port of screens/game.py.
# Owns GameState, ViewState, GameRenderer, InputController.
# Wires the simulation → render → input pipeline each frame.

const _MAPS := preload("res://data/maps.gd")
const _TT   := preload("res://data/tower_types.gd")
const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BRAND := preload("res://ui/theme/BrandCopy.gd")
const _UP   := preload("res://data/upgrade_paths.gd")
const _PLACEMENT_HINTS := preload("res://ui/controllers/PlacementHints.gd")
const _RUN_SETUP := preload("res://ui/controllers/RunSetup.gd")
const _WAVE_SHOP_CTRL := preload("res://ui/controllers/WaveShopModalController.gd")
const _DETAILS_CTRL := preload("res://ui/controllers/TowerDetailsOverlayController.gd")
const _MAP_BG_PATHS: Dictionary = {
	0: "res://assets/sprites/maps/map_bg_s_curve.jpg",
	1: "res://assets/sprites/maps/map_bg_gauntlet.jpg",
	2: "res://assets/sprites/maps/map_bg_spiral.jpg",
}

# Child node references (assigned in _ready)
@onready var renderer: Node2D           = $GameRenderer
@onready var hud_layer: CanvasLayer      = $HudLayer

# Created in code
var game_state: GameState      = null
var view_state: Object         = null
var input_ctrl: Object         = null

# HUD Control nodes (created dynamically in _build_hud)
var _wave_btn: Button   = null
var _pause_btn: Button  = null
var _speed_btns: Array  = []   # [Button x3]
var _sell_btn: Button   = null
var _target_btn: Button = null
var _msg_label: Label   = null
var _gold_label: Label  = null
var _lives_label: Label = null
var _wave_label: Label  = null
var _tower_panel: PanelContainer = null
var _tower_name_label: Label = null
var _base_upg_btn: Button = null
var _path_upg_btns: Array = []   # [Button x3]
var _shop_btns: Dictionary = {}  # tower_type -> Button
var _shop_name_labels: Dictionary = {}  # tower_type -> Label
var _shop_cost_labels: Dictionary = {}  # tower_type -> Label
var _promotion_modal: PanelContainer = null
var _promotion_title: Label = null
var _promotion_confirm_btn: Button = null
var _promotion_cancel_btn: Button = null
var _pause_modal: PanelContainer = null
var _pause_title: Label = null
var _resume_btn: Button = null
var _restart_btn: Button = null
var _quit_btn: Button = null
var _placement_mode_btn: Button = null
var _placement_confirm_toggle_btn: Button = null
var _placement_confirm_modal: PanelContainer = null
var _placement_confirm_title: Label = null
var _placement_confirm_btn: Button = null
var _placement_cancel_btn: Button = null
var _top_bar: HBoxContainer = null
var _speed_bar: HBoxContainer = null
var _shop_bar: HBoxContainer = null
var _shop_scroll: ScrollContainer = null
var _modifier_badge: Label = null
var _active_modifier_id: String = ""
var _placement_confirm_bar: HBoxContainer = null
var _confirm_placement_btn: Button = null
var _cancel_placement_btn: Button = null
var _info_btn: Button = null
var _instruction_banner: PanelContainer = null
var _instruction_label: Label = null
var _details = null   # TowerDetailsOverlayController
var _tower_stats_label: Label = null
var _wave_progress_bar: ProgressBar = null
var _wave_shop_modal: PanelContainer = null
var _wave_shop = null   # WaveShopModalController
var _restart_confirm_start_ms: int = 0
var _restart_confirm_bar: ProgressBar = null
var _world_rect: Rect2 = Rect2(Vector2.ZERO, _LAYOUT.BASE_SIZE)

# Dpad: track modal visibility so we can grab focus on open and restore on close
var _dpad_pause_open: bool = false
var _dpad_promo_open: bool = false
var _dpad_shop_open: bool  = false
var _dpad_place_open: bool = false
var _world_scale: float = 1.0
var _backdrop_texture: Texture2D = null
var _selection_ring: SelectionRing = null
var _virtual_cursor: VirtualCursor = null
var _cursor_accel_time: float = 0.0
const _PANEL_TEXT: Color = Color(0.92, 0.94, 0.98, 1.0)
const _PANEL_MUTED: Color = Color(0.66, 0.70, 0.78, 1.0)
const _PANEL_DISABLED: Color = Color(0.50, 0.53, 0.60, 1.0)
const _SHOP_COST_AFFORD: Color = Color(1.0, 0.82, 0.2)
const _SHOP_COST_DENY: Color = Color(1.0, 0.35, 0.35)
const _Z_TOWER_PANEL: int = 30
const _Z_WAVE_BUTTON: int = 45
const _Z_SHOP_BAR: int = 50
const _Z_INSTRUCTION: int = 55
const _Z_PLACEMENT_BAR: int = 60
const _Z_MODAL: int = 100
const _Z_OVERLAY_BACKDROP: int = 110
const _Z_OVERLAY: int = 120

# Previous lives count to detect leaks for screen shake
var _prev_lives: int = 10
var _prev_wave: int = 0
var _prev_kills: int = 0
var _prev_wave_shop_pending: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	view_state = ViewState.new()
	view_state.configure_from_settings(Progression.get_settings())
	input_ctrl = InputController.new()

	# Init game state from Progression run config
	var run_config: Dictionary = Progression.get_run_config()
	var map_id: int = Progression.pending_map_id
	var map_data: Dictionary = _MAPS.MAPS[map_id]
	game_state = GameState.new(map_data["path"], run_config, map_id)
	_RUN_SETUP.apply_variant_stats(game_state)
	_RUN_SETUP.place_starting_tower(game_state, run_config)
	_active_modifier_id = run_config.get("modifier_id", "")
	_backdrop_texture = load(_MAP_BG_PATHS.get(map_id, ""))

	# Wire renderer
	renderer.game_state = game_state
	renderer.view_state = view_state
	
	# Fade in transition
	self.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD)
	renderer.rebuild_path_for_map(map_data["path"])

	# Wire input
	input_ctrl.game_state = game_state
	input_ctrl.view_state = view_state

	_prev_lives = game_state.lives
	_prev_wave = game_state.wave
	_prev_kills = game_state.stat_enemies_killed
	_prev_wave_shop_pending = game_state.wave_shop_pending

	# Show active modifier(s) as a persistent instruction for the first few seconds
	var mod_ids: Array = Progression.get_active_modifier_ids()
	if not mod_ids.is_empty():
		var labels: Array = mod_ids.map(func(m): return _mod_short_name(m))
		view_state.set_instruction(" + ".join(labels))
		var clear_tween := create_tween()
		clear_tween.tween_interval(4.0)
		clear_tween.tween_callback(func(): view_state.clear_instruction())

	_selection_ring = preload("res://rendering/overlays/SelectionRing.gd").new()
	_selection_ring.visible = false
	renderer.add_child(_selection_ring)
	
	_virtual_cursor = preload("res://input/VirtualCursor.gd").new()
	_virtual_cursor.visible = false
	renderer.add_child(_virtual_cursor)

	JuiceManager.configure_from_progression()
	_build_hud()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_register_hud_rects()
	FocusManager.register_initial_focus(_wave_btn if _wave_btn.visible else _shop_btns.values()[0])

func _exit_tree() -> void:
	if game_state:
		game_state.dispose()

func _current_game_state() -> GameState:
	return game_state

func _build_hud() -> void:
	# All HUD lives in a CanvasLayer so it renders on top of the game world
	# and is not affected by screen shake.

	# ---- Top bar ----
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 12)
	hud_layer.add_child(_top_bar)

	_wave_label = Label.new()
	_wave_label.text = "Wave 1 / 15"
	_THEME.apply_label(_wave_label, "body")
	_top_bar.add_child(_wave_label)

	_lives_label = Label.new()
	_lives_label.text = _BRAND.integrity(10)
	_THEME.apply_label(_lives_label, "body")
	_top_bar.add_child(_lives_label)

	_gold_label = Label.new()
	_gold_label.text = _BRAND.credits(300)
	_THEME.apply_label(_gold_label, "currency")
	_top_bar.add_child(_gold_label)

	_msg_label = Label.new()
	_msg_label.text = ""
	_msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_THEME.apply_label(_msg_label, "muted")
	_top_bar.add_child(_msg_label)

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.custom_minimum_size = Vector2(48.0, _LAYOUT.min_touch_height(false))
	_THEME.apply_button(_pause_btn, "secondary")
	_pause_btn.pressed.connect(_on_pause_pressed)
	_top_bar.add_child(_pause_btn)

	# ---- Speed buttons ----
	_speed_bar = HBoxContainer.new()
	_speed_bar.add_theme_constant_override("separation", 4)
	hud_layer.add_child(_speed_bar)

	for mult in [1.0, 2.0, 3.0]:
		var btn := Button.new()
		btn.text = "x%d" % int(mult)
		btn.custom_minimum_size = Vector2(48.0, _LAYOUT.min_touch_height(false))
		_THEME.apply_button(btn, "tab")
		btn.pressed.connect(_on_speed_pressed.bind(mult))
		_speed_bar.add_child(btn)
		_speed_btns.append(btn)

	# ---- Wave button ----
	_wave_btn = Button.new()
	_wave_btn.text = _BRAND.START_WAVE
	_wave_btn.custom_minimum_size = Vector2(210.0, _LAYOUT.min_touch_height(true))
	_wave_btn.z_index = _Z_WAVE_BUTTON
	_THEME.apply_button(_wave_btn, "primary")
	_wave_btn.pressed.connect(_on_wave_btn_pressed)
	hud_layer.add_child(_wave_btn)

	# ---- Tower selection panel ----
	_tower_panel = PanelContainer.new()
	_tower_panel.custom_minimum_size = Vector2(430.0, 178.0)
	_tower_panel.visible = false
	_tower_panel.z_index = _Z_TOWER_PANEL
	_THEME.apply_panel(_tower_panel, "default")
	hud_layer.add_child(_tower_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 12)
	panel_margin.add_theme_constant_override("margin_top", 10)
	panel_margin.add_theme_constant_override("margin_right", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 10)
	_tower_panel.add_child(panel_margin)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	panel_margin.add_child(panel_vbox)

	_tower_name_label = Label.new()
	_tower_name_label.text = "Tower"
	_tower_name_label.add_theme_color_override("font_color", _PANEL_TEXT)
	_tower_name_label.add_theme_font_size_override("font_size", 16)
	_tower_name_label.clip_text = false

	var name_hbox := HBoxContainer.new()
	name_hbox.add_child(_tower_name_label)

	_info_btn = Button.new()
	_info_btn.text = "i"
	_info_btn.custom_minimum_size = Vector2(32.0, 32.0)
	_THEME.apply_button(_info_btn, "tab")
	_info_btn.pressed.connect(_on_info_pressed)
	name_hbox.add_child(_info_btn)

	panel_vbox.add_child(name_hbox)

	_tower_stats_label = Label.new()
	_tower_stats_label.text = ""
	_tower_stats_label.add_theme_color_override("font_color", _PANEL_MUTED)
	_tower_stats_label.add_theme_font_size_override("font_size", 13)
	panel_vbox.add_child(_tower_stats_label)

	_base_upg_btn = Button.new()
	_base_upg_btn.text = "Upgrade (45g)"
	_base_upg_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
	_base_upg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_readability(_base_upg_btn)
	_base_upg_btn.pressed.connect(_on_base_upgrade_pressed)
	panel_vbox.add_child(_base_upg_btn)

	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 6)
	panel_vbox.add_child(path_row)
	for path_name in ["Top", "Middle", "Bottom"]:
		var pbtn := Button.new()
		pbtn.text = path_name
		pbtn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_button_readability(pbtn)
		pbtn.pressed.connect(_on_path_upgrade_pressed.bind(path_name))
		path_row.add_child(pbtn)
		_path_upg_btns.append(pbtn)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)
	panel_vbox.add_child(act_row)

	_sell_btn = Button.new()
	_sell_btn.text = "Sell"
	_sell_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_readability(_sell_btn)
	_sell_btn.pressed.connect(_on_sell_pressed)
	act_row.add_child(_sell_btn)

	_target_btn = Button.new()
	_target_btn.text = "Target: First"
	_target_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
	_target_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_readability(_target_btn)
	_target_btn.pressed.connect(_on_target_pressed)
	act_row.add_child(_target_btn)

	# ---- Shop strip (ScrollContainer when cards exceed phone width) ----
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.z_index = _Z_SHOP_BAR
	hud_layer.add_child(_shop_scroll)

	_shop_bar = HBoxContainer.new()
	_shop_bar.add_theme_constant_override("separation", 6)
	_shop_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_scroll.add_child(_shop_bar)

	for ttype in _TT.TOWER_TYPES_LIST:
		var info: Dictionary = _TT.TOWER_TYPES[ttype]
		var sbtn := Button.new()
		sbtn.text = ""
		sbtn.custom_minimum_size = Vector2(126.0, 88.0)
		_THEME.apply_button(sbtn, "shop")
		var shop_vbox := VBoxContainer.new()
		shop_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		shop_vbox.add_theme_constant_override("separation", 2)
		shop_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl := Label.new()
		name_lbl.text = info["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_THEME.apply_label(name_lbl, "body")
		name_lbl.add_theme_font_size_override("font_size", 13)
		shop_vbox.add_child(name_lbl)
		_shop_name_labels[ttype] = name_lbl
		var cost_lbl := Label.new()
		cost_lbl.text = _BRAND.credits_amount_suffix(int(info["cost"]))
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_THEME.apply_label(cost_lbl, "currency")
		cost_lbl.add_theme_font_size_override("font_size", 14)
		shop_vbox.add_child(cost_lbl)
		sbtn.add_child(shop_vbox)
		sbtn.button_down.connect(_on_shop_btn_down.bind(ttype))
		sbtn.pressed.connect(_on_shop_pressed.bind(ttype))
		_shop_bar.add_child(sbtn)
		_shop_btns[ttype] = sbtn
		_shop_cost_labels[ttype] = cost_lbl

	# ---- Placement Confirmation Bar ----
	_placement_confirm_bar = HBoxContainer.new()
	_placement_confirm_bar.add_theme_constant_override("separation", 10)
	_placement_confirm_bar.visible = false
	_placement_confirm_bar.z_index = _Z_PLACEMENT_BAR
	hud_layer.add_child(_placement_confirm_bar)

	_confirm_placement_btn = Button.new()
	_confirm_placement_btn.text = "✓"
	_confirm_placement_btn.custom_minimum_size = Vector2(68.0, _LAYOUT.min_touch_height(true))
	_THEME.apply_button(_confirm_placement_btn, "primary")
	_confirm_placement_btn.pressed.connect(_on_confirm_placement)
	_placement_confirm_bar.add_child(_confirm_placement_btn)

	_cancel_placement_btn = Button.new()
	_cancel_placement_btn.text = "X"
	_cancel_placement_btn.custom_minimum_size = Vector2(68.0, _LAYOUT.min_touch_height(true))
	_THEME.apply_button(_cancel_placement_btn, "danger")
	_cancel_placement_btn.pressed.connect(_on_cancel_placement)
	_placement_confirm_bar.add_child(_cancel_placement_btn)

	# ---- Active modifier badge ----
	var badge_mod_ids: Array = Progression.get_active_modifier_ids()
	if not badge_mod_ids.is_empty():
		_modifier_badge = Label.new()
		_modifier_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_modifier_badge.add_theme_font_size_override("font_size", 11)
		_modifier_badge.add_theme_color_override("font_color", _THEME.ORANGE)
		_modifier_badge.add_theme_stylebox_override("normal",
			_THEME.style_box(_THEME.BG, _THEME.ORANGE, 1, 4, 0))
		var badge_labels: Array = badge_mod_ids.map(func(m): return _mod_short_name(m))
		_modifier_badge.text = " + ".join(badge_labels)
		hud_layer.add_child(_modifier_badge)

	# ---- Instruction Banner ----
	_instruction_banner = PanelContainer.new()
	_instruction_banner.custom_minimum_size = Vector2(400, 50)
	_instruction_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_banner.z_index = _Z_INSTRUCTION
	_THEME.apply_panel(_instruction_banner, "default")
	hud_layer.add_child(_instruction_banner)
	
	_instruction_label = Label.new()
	_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_label.text = _BRAND.INSTRUCTION_PICK_TOWER
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_THEME.apply_label(_instruction_label, "heading")
	_instruction_label.add_theme_font_size_override("font_size", 20)
	_instruction_banner.add_child(_instruction_label)

	# ---- Wave progress bar ----
	_wave_progress_bar = ProgressBar.new()
	_wave_progress_bar.min_value = 0.0
	_wave_progress_bar.max_value = 1.0
	_wave_progress_bar.value = 0.0
	_wave_progress_bar.show_percentage = false
	_wave_progress_bar.custom_minimum_size = Vector2(210.0, 5.0)
	_wave_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_wave_progress_style(1.0)
	hud_layer.add_child(_wave_progress_bar)

	_build_promotion_modal()
	_build_pause_modal()
	_build_placement_confirm_modal()
	_wave_shop = _WAVE_SHOP_CTRL.new(hud_layer)
	_wave_shop.button_readability = _apply_button_readability
	_wave_shop.card_picked.connect(_on_wave_shop_pick)
	_wave_shop.skipped.connect(_on_wave_shop_skip)
	_wave_shop_modal = _wave_shop.modal
	_details = _DETAILS_CTRL.new(hud_layer)
	_details.resolve_game_state = _current_game_state
	_details.raise_to_top = _raise_visible_modal_controls
	_wire_hud_dpad()

func _build_promotion_modal() -> void:
	_promotion_modal = PanelContainer.new()
	_promotion_modal.visible = false
	_promotion_modal.custom_minimum_size = Vector2.ZERO
	_promotion_modal.clip_contents = true
	_promotion_modal.z_index = _Z_MODAL
	_promotion_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_THEME.apply_panel(_promotion_modal, "modal")
	hud_layer.add_child(_promotion_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_promotion_modal.add_child(vbox)

	_promotion_title = Label.new()
	_promotion_title.text = "Confirm path promotion?"
	_promotion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_promotion_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promotion_title.add_theme_color_override("font_color", _PANEL_TEXT)
	vbox.add_child(_promotion_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	_promotion_confirm_btn = Button.new()
	_promotion_confirm_btn.text = "Confirm"
	_promotion_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_promotion_confirm_btn.custom_minimum_size = Vector2(0.0, 44.0)
	_apply_button_readability(_promotion_confirm_btn)
	_promotion_confirm_btn.pressed.connect(_on_promotion_confirm_pressed)
	row.add_child(_promotion_confirm_btn)

	_promotion_cancel_btn = Button.new()
	_promotion_cancel_btn.text = "Cancel"
	_promotion_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_promotion_cancel_btn.custom_minimum_size = Vector2(0.0, 44.0)
	_apply_button_readability(_promotion_cancel_btn)
	_promotion_cancel_btn.pressed.connect(_on_promotion_cancel_pressed)
	row.add_child(_promotion_cancel_btn)

func _build_pause_modal() -> void:
	_pause_modal = PanelContainer.new()
	_pause_modal.visible = false
	_pause_modal.custom_minimum_size = Vector2.ZERO
	_pause_modal.clip_contents = true
	_pause_modal.z_index = _Z_MODAL
	_pause_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_THEME.apply_panel(_pause_modal, "modal")
	hud_layer.add_child(_pause_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_pause_modal.add_child(vbox)

	_pause_title = Label.new()
	_pause_title.text = "Paused"
	_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_title.add_theme_color_override("font_color", _PANEL_TEXT)
	_pause_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_pause_title)

	_resume_btn = Button.new()
	_resume_btn.text = "Resume"
	_resume_btn.custom_minimum_size = Vector2(0, 44)
	_apply_button_readability(_resume_btn)
	_resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(_resume_btn)

	_restart_btn = Button.new()
	_restart_btn.text = "Restart Run"
	_restart_btn.custom_minimum_size = Vector2(0, 44)
	_apply_button_readability(_restart_btn)
	_restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_btn)

	_restart_confirm_bar = ProgressBar.new()
	_restart_confirm_bar.visible = false
	_restart_confirm_bar.min_value = 0.0
	_restart_confirm_bar.max_value = 1.0
	_restart_confirm_bar.value = 1.0
	_restart_confirm_bar.show_percentage = false
	_restart_confirm_bar.custom_minimum_size = Vector2(0.0, 5.0)
	_restart_confirm_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var restart_bg := StyleBoxFlat.new()
	restart_bg.bg_color = Color(0.12, 0.14, 0.20, 0.85)
	restart_bg.set_corner_radius_all(2)
	_restart_confirm_bar.add_theme_stylebox_override("background", restart_bg)
	var restart_fill := StyleBoxFlat.new()
	restart_fill.bg_color = Color(_THEME.ORANGE.r, _THEME.ORANGE.g, _THEME.ORANGE.b, 0.95)
	restart_fill.set_corner_radius_all(2)
	_restart_confirm_bar.add_theme_stylebox_override("fill", restart_fill)
	vbox.add_child(_restart_confirm_bar)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit to Menu"
	_quit_btn.custom_minimum_size = Vector2(0, 44)
	_apply_button_readability(_quit_btn)
	_quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(_quit_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_placement_mode_btn = Button.new()
	_placement_mode_btn.custom_minimum_size = Vector2(0, 44)
	_apply_button_readability(_placement_mode_btn)
	_placement_mode_btn.pressed.connect(_on_placement_mode_toggle)
	vbox.add_child(_placement_mode_btn)

	_placement_confirm_toggle_btn = Button.new()
	_placement_confirm_toggle_btn.custom_minimum_size = Vector2(0, 44)
	_apply_button_readability(_placement_confirm_toggle_btn)
	_placement_confirm_toggle_btn.pressed.connect(_on_placement_confirm_toggle)
	vbox.add_child(_placement_confirm_toggle_btn)

func _build_placement_confirm_modal() -> void:
	# Built for potential future / accessibility, but P0 uses only the floating bar
	# so confirm UI never double-stacks over the map on short phone viewports.
	_placement_confirm_modal = PanelContainer.new()
	_placement_confirm_modal.visible = false
	_placement_confirm_modal.custom_minimum_size = Vector2.ZERO
	_placement_confirm_modal.clip_contents = true
	_placement_confirm_modal.z_index = _Z_MODAL
	_placement_confirm_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_THEME.apply_panel(_placement_confirm_modal, "modal")
	hud_layer.add_child(_placement_confirm_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_placement_confirm_modal.add_child(vbox)

	_placement_confirm_title = Label.new()
	_placement_confirm_title.text = "Place tower here?"
	_placement_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_confirm_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement_confirm_title.add_theme_color_override("font_color", _PANEL_TEXT)
	vbox.add_child(_placement_confirm_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	_placement_confirm_btn = Button.new()
	_placement_confirm_btn.text = "Confirm"
	_placement_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placement_confirm_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
	_apply_button_readability(_placement_confirm_btn)
	_placement_confirm_btn.pressed.connect(_on_confirm_placement_pressed)
	row.add_child(_placement_confirm_btn)

	_placement_cancel_btn = Button.new()
	_placement_cancel_btn.text = "Cancel"
	_placement_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placement_cancel_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
	_apply_button_readability(_placement_cancel_btn)
	_placement_cancel_btn.pressed.connect(_on_cancel_placement_pressed)
	row.add_child(_placement_cancel_btn)

func _wire_hud_dpad() -> void:
	# Ordered shop button list (matches _shop_bar child order)
	var shop_list: Array = []
	for child in _shop_bar.get_children():
		if child is Button:
			shop_list.append(child)

	# Speed buttons: horizontal strip
	FocusManager.setup_dpad_neighbors(_speed_btns, false)

	# Shop strip: horizontal
	FocusManager.setup_dpad_neighbors(shop_list, false)

	# Speed strip → wave button (down); wave button → speed strip (up)
	for btn in _speed_btns:
		FocusManager.set_neighbor(btn, "bottom", _wave_btn)
	if _speed_btns.size() > 0:
		FocusManager.set_neighbor(_wave_btn, "top", _speed_btns[0])

	# Wave button ↔ shop strip
	if not shop_list.is_empty():
		FocusManager.set_neighbor(_wave_btn, "bottom", shop_list[0])
		for sbtn in shop_list:
			FocusManager.set_neighbor(sbtn, "top", _wave_btn)

	# Pause button: reachable from rightmost speed button, goes down to wave button
	if _speed_btns.size() > 0:
		FocusManager.set_neighbor(_speed_btns.back(), "right", _pause_btn)
		FocusManager.set_neighbor(_pause_btn, "left", _speed_btns.back())
	FocusManager.set_neighbor(_pause_btn, "bottom", _wave_btn)

	# Tower panel: vertical chain base → paths → actions
	# Path buttons also wired horizontally among themselves
	FocusManager.setup_dpad_neighbors([_base_upg_btn] + _path_upg_btns + [_sell_btn, _target_btn], true)
	FocusManager.setup_dpad_neighbors(_path_upg_btns, false)
	# sell / target → down → first shop button
	if not shop_list.is_empty():
		FocusManager.set_neighbor(_sell_btn,   "bottom", shop_list[0])
		FocusManager.set_neighbor(_target_btn, "bottom", shop_list[0])

	# Pause modal: vertical chain
	FocusManager.setup_dpad_neighbors([
		_resume_btn, _restart_btn, _quit_btn,
		_placement_mode_btn, _placement_confirm_toggle_btn
	], true)

	# Promotion modal: horizontal pair
	FocusManager.setup_dpad_neighbors([_promotion_confirm_btn, _promotion_cancel_btn], false)

	# Placement confirm modal: horizontal pair
	FocusManager.setup_dpad_neighbors([_placement_confirm_btn, _placement_cancel_btn], false)

	# Placement confirm bar (floating): horizontal pair
	FocusManager.setup_dpad_neighbors([_confirm_placement_btn, _cancel_placement_btn], false)

func _dpad_return_focus() -> void:
	# Called after a modal closes — return focus to the most logical HUD button.
	if _wave_btn.is_visible_in_tree():
		_wave_btn.grab_focus()
	elif not _shop_btns.is_empty():
		_shop_btns.values()[0].grab_focus()

func _show_wave_shop(now_ms: int) -> void:
	if _wave_shop == null or _wave_shop.modal == null:
		return
	_wave_shop.show_shop(game_state.wave, _active_modifier_id, now_ms, self)
	_layout_modal(_wave_shop.modal, _wave_shop.desired_size)
	_wave_shop.modal.visible = true
	_raise_visible_modal_controls()
	JuiceManager.play(JuiceManager.SFX.WAVE_SHOP_OPEN)
	_wave_shop.finish_open()

func _on_wave_shop_pick(card_id: String, now_ms: int) -> void:
	_wave_shop_modal.visible = false
	_dispatch({"type": "wave_shop_pick", "card_id": card_id}, now_ms)
	_dpad_return_focus()

func _on_wave_shop_skip(now_ms: int) -> void:
	_wave_shop_modal.visible = false
	_dispatch({"type": "wave_shop_skip"}, now_ms)
	_dpad_return_focus()

func _apply_button_readability(btn: Button) -> void:
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not btn.has_theme_stylebox_override("normal"):
		_THEME.apply_button(btn, "secondary")
	btn.add_theme_color_override("font_color", _PANEL_TEXT)
	btn.add_theme_color_override("font_disabled_color", _PANEL_DISABLED)
	btn.add_theme_font_size_override("font_size", 12)

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	_hud_rects_ready = false
	queue_redraw()

func _draw() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	if _backdrop_texture != null:
		draw_texture_rect(_backdrop_texture, Rect2(Vector2.ZERO, viewport), false)
		draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.02, 0.03, 0.06, 0.34))
	else:
		draw_rect(Rect2(Vector2.ZERO, viewport), _LAYOUT.BG_COLOR)

func _apply_responsive_layout() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	_world_rect = _LAYOUT.game_world_rect(viewport)
	_world_scale = _world_rect.size.x / _LAYOUT.BASE_SIZE.x
	renderer.position = _world_rect.position
	renderer.scale = Vector2(_world_scale, _world_scale)

	var margins: Dictionary = _LAYOUT.content_margins(viewport, self)
	var margin_l: float = float(margins["left"])
	var margin_r: float = float(margins["right"])
	var top: float = float(margins["top"])
	var bottom: float = float(margins["bottom"])
	var margin: float = maxf(margin_l, margin_r)
	var top_bar_h: float = maxf(_LAYOUT.min_touch_height(false), viewport.y * 0.074)
	if _LAYOUT.is_short_height(viewport):
		top_bar_h = maxf(_LAYOUT.min_touch_height(false), minf(top_bar_h, 44.0))
	_LAYOUT.apply_rect(_top_bar, Rect2(Vector2(margin_l, top), Vector2(maxf(0.0, viewport.x - margin_l - margin_r), top_bar_h)))
	_LAYOUT.apply_rect(_speed_bar, Rect2(Vector2(margin_l, top + top_bar_h + 6.0), Vector2(166.0, _LAYOUT.min_touch_height(false))))

	# Scale font sizes with viewport height so they stay readable at all sizes
	var top_font: int = int(clampf(viewport.y * 0.026, 13.0, 18.0))
	for lbl in [_wave_label, _lives_label, _gold_label, _msg_label]:
		if lbl:
			lbl.add_theme_font_size_override("font_size", top_font)

	# Shop strip: fit within viewport; horizontal scroll when 6 towers exceed width
	var tower_count: int = max(1, _shop_btns.size())
	var gap_count: int = max(0, tower_count - 1)
	var shop_sep: float = 6.0
	var compact_shop: bool = viewport.y < 620.0 or _LAYOUT.shop_strip_needs_compaction(viewport, tower_count)
	var preferred_card_w: float = 100.0 if compact_shop else 120.0
	var min_card_w: float = 72.0 if compact_shop else 88.0
	var shop_h: float = 76.0 if compact_shop else 88.0
	var shop_max_w: float = minf(viewport.x - margin_l - margin_r, _world_rect.size.x - margin * 2.0)
	var preferred_content_w: float = float(tower_count) * preferred_card_w + float(gap_count) * shop_sep
	var min_content_w: float = float(tower_count) * min_card_w + float(gap_count) * shop_sep
	var needs_scroll: bool = min_content_w > shop_max_w + 1.0
	var shop_w: float = shop_max_w if needs_scroll else minf(preferred_content_w, shop_max_w)
	var card_w: float
	if needs_scroll:
		card_w = min_card_w
	else:
		card_w = floor((shop_w - float(gap_count) * shop_sep) / float(tower_count))
		card_w = maxf(card_w, min_card_w)
	var card_h: float = shop_h
	var shop_x: float = margin_l + (viewport.x - margin_l - margin_r - shop_w) * 0.5
	var shop_y: float = viewport.y - bottom - shop_h
	_shop_bar.add_theme_constant_override("separation", int(shop_sep))
	for ttype in _shop_btns.keys():
		var shop_btn: Button = _shop_btns[ttype]
		shop_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if needs_scroll else Control.SIZE_FILL
		shop_btn.custom_minimum_size = Vector2(card_w, card_h)
		if ttype in _shop_name_labels:
			var name_lbl: Label = _shop_name_labels[ttype]
			name_lbl.add_theme_font_size_override("font_size", 10 if compact_shop or needs_scroll else 13)
		if ttype in _shop_cost_labels:
			var cost_lbl: Label = _shop_cost_labels[ttype]
			cost_lbl.add_theme_font_size_override("font_size", 11 if compact_shop or needs_scroll else 14)
	var content_w: float = float(tower_count) * card_w + float(gap_count) * shop_sep
	_shop_bar.custom_minimum_size = Vector2(content_w if needs_scroll else shop_w, shop_h)
	if _shop_scroll != null:
		_shop_scroll.horizontal_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_ALWAYS if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED
		)
		_LAYOUT.apply_rect(_shop_scroll, Rect2(Vector2(shop_x, shop_y), Vector2(shop_w, shop_h)))
	else:
		_LAYOUT.apply_rect(_shop_bar, Rect2(Vector2(shop_x, shop_y), Vector2(shop_w, shop_h)))

	# Wave button: docked flush to top of shop strip, visually grouped
	var wave_size: Vector2 = Vector2(clampf(viewport.x * 0.23, 180.0, 240.0), _LAYOUT.min_touch_height(true))
	var wave_y: float = shop_y - wave_size.y - (12.0 if compact_shop else 10.0)
	_LAYOUT.apply_rect(_wave_btn, Rect2(Vector2((viewport.x - wave_size.x) * 0.5, wave_y), wave_size))

	# Wave progress bar: directly below the wave button
	if _wave_progress_bar != null:
		_LAYOUT.apply_rect(_wave_progress_bar, Rect2(Vector2((viewport.x - wave_size.x) * 0.5, wave_y + wave_size.y + 2.0), Vector2(wave_size.x, 5.0)))

	# Position modifier badge right of speed bar if present
	if _modifier_badge != null:
		var badge_x: float = margin_l + 166.0 + 8.0
		var badge_y: float = top + top_bar_h + 9.0
		_modifier_badge.position = Vector2(badge_x, badge_y)

	# Instruction banner: centered below top bar
	if _instruction_banner != null:
		var banner_w: float = minf(560.0, maxf(280.0, viewport.x - margin_l - margin_r))
		var banner_h: float = _LAYOUT.min_touch_height(true) if _LAYOUT.is_small(viewport) or _LAYOUT.is_short_height(viewport) else 52.0
		var banner_font: int = int(clampf(viewport.y * 0.032, 14.0, 20.0))
		_instruction_label.add_theme_font_size_override("font_size", banner_font)
		_LAYOUT.apply_rect(_instruction_banner, Rect2(Vector2(margin_l + (viewport.x - margin_l - margin_r - banner_w) * 0.5, top + top_bar_h + 12.0), Vector2(banner_w, banner_h)))

	_layout_tower_panel(null)

	_layout_modal(_promotion_modal, Vector2(360.0, 160.0))
	_layout_modal(_pause_modal, Vector2(400.0, 360.0))
	# Placement confirm modal is intentionally not shown (floating bar only).
	if _placement_confirm_modal != null:
		_placement_confirm_modal.visible = false
	if _wave_shop != null and _wave_shop.is_open():
		_wave_shop.desired_size = _LAYOUT.wave_shop_desired_size(viewport, self)
		_layout_modal(_wave_shop.modal, _wave_shop.desired_size)
	_raise_core_hud_controls()
	_raise_visible_modal_controls()

func _raise_core_hud_controls() -> void:
	for node in [_wave_btn, _shop_scroll if _shop_scroll != null else _shop_bar, _instruction_banner, _placement_confirm_bar]:
		if node != null and node.get_parent() == hud_layer:
			hud_layer.move_child(node, hud_layer.get_child_count() - 1)

func _raise_visible_modal_controls() -> void:
	for node in [_promotion_modal, _pause_modal, _placement_confirm_modal, _wave_shop_modal]:
		if node != null and node.get_parent() == hud_layer and node.is_visible_in_tree():
			hud_layer.move_child(node, hud_layer.get_child_count() - 1)
	if _details != null and _details.overlay != null and _details.overlay.get_parent() == hud_layer:
		if _details.overlay.has_meta("backdrop"):
			var backdrop: Node = _details.overlay.get_meta("backdrop")
			if is_instance_valid(backdrop) and backdrop.get_parent() == hud_layer:
				hud_layer.move_child(backdrop, hud_layer.get_child_count() - 1)
		hud_layer.move_child(_details.overlay, hud_layer.get_child_count() - 1)

static func _mod_short_name(mod_id: String) -> String:
	match mod_id:
		"mod_iron_economy":  return "[ Iron Eco ]"
		"mod_glass_cannon":  return "[ Glass ]"
		"mod_blitz":         return "[ Blitz ]"
		"mod_hardened":      return "[ Hardened ]"
		"mod_sudden_death":  return "[ SUDDEN DEATH ]"
	return "[ %s ]" % mod_id

func _layout_modal(panel: PanelContainer, desired_size: Vector2) -> void:
	if panel == null:
		return
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	# Center over the playfield when present so letterbox gutters don't pull modals off-map.
	var center_on: Rect2 = _world_rect if _world_rect.size.x > 1.0 and _world_rect.size.y > 1.0 else Rect2()
	var rect: Rect2 = _LAYOUT.modal_rect(viewport, desired_size, self, center_on)
	_LAYOUT.apply_modal(panel, rect)

func _screen_to_world(pos: Vector2) -> Vector2:
	if _world_scale <= 0.0:
		return pos
	return (pos - _world_rect.position) / _world_scale

func _world_to_screen(pos: Vector2) -> Vector2:
	return _world_rect.position + pos * _world_scale

func _layout_tower_panel(selected: Tower) -> void:
	if _tower_panel == null:
		return
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	var margins: Dictionary = _LAYOUT.content_margins(viewport, self)
	var margin_l: float = float(margins["left"])
	var margin_r: float = float(margins["right"])
	var top: float = float(margins["top"])
	var bottom: float = float(margins["bottom"])
	var panel_h: float = 220.0
	if _LAYOUT.is_short_height(viewport) or _LAYOUT.is_phone_ultrawide(viewport):
		panel_h = 168.0
	var size: Vector2 = Vector2(minf(460.0, maxf(300.0, viewport.x - margin_l - margin_r)), panel_h)
	var shop_y: float = viewport.y - bottom - 92.0
	var low_y: float = maxf(top + 102.0, shop_y - size.y - 12.0)
	var high_y: float = top + 102.0
	var x: float = margin_l
	var y: float = low_y

	if selected != null:
		var selected_screen: Vector2 = _world_to_screen(selected.pos)
		x = margin_l if selected_screen.x > viewport.x * 0.5 else viewport.x - margin_r - size.x
		y = high_y if selected_screen.y > viewport.y * 0.52 else low_y
		y = clampf(y, top + 92.0, maxf(top + 92.0, shop_y - size.y - 8.0))
	else:
		x = viewport.x - margin_r - size.x
		y = low_y

	_LAYOUT.apply_rect(_tower_panel, Rect2(Vector2(x, y), size))
	_THEME.apply_glass_panel(_tower_panel)
	if _tower_panel.material is ShaderMaterial:
		_tower_panel.material.set_shader_parameter("panel_size", size)

func _register_hud_rects() -> void:
	# Build Rect2 hit regions from the Control node global positions.
	# Called after _build_hud so positions are stable.
	# NOTE: These need to be re-registered after first _process frame
	# when layout has settled; we call _refresh_hud_rects() in _process.
	pass

func _refresh_hud_rects() -> void:
	var wave_rect := Rect2(_wave_btn.global_position, _wave_btn.size) if _wave_btn else Rect2()
	var pause_rect := Rect2(_pause_btn.global_position, _pause_btn.size) if _pause_btn else Rect2()
	var s1 := Rect2(_speed_btns[0].global_position, _speed_btns[0].size) if _speed_btns.size() > 0 else Rect2()
	var s2 := Rect2(_speed_btns[1].global_position, _speed_btns[1].size) if _speed_btns.size() > 1 else Rect2()
	var s3 := Rect2(_speed_btns[2].global_position, _speed_btns[2].size) if _speed_btns.size() > 2 else Rect2()
	var sell_rect := Rect2(_sell_btn.global_position, _sell_btn.size) if _sell_btn else Rect2()
	var tgt_rect := Rect2(_target_btn.global_position, _target_btn.size) if _target_btn else Rect2()

	var shop_d: Dictionary = {}
	for ttype in _shop_btns:
		shop_d[ttype] = Rect2(_shop_btns[ttype].global_position, _shop_btns[ttype].size)

	var upg_list: Array = []
	var sel_id: int = view_state.selected_tower_id
	for i in _path_upg_btns.size():
		var btn: Button = _path_upg_btns[i]
		upg_list.append({
			"path": ["Top","Middle","Bottom"][i],
			"rect": Rect2(btn.global_position, btn.size),
			"tower_id": sel_id,
		})

	var base_rect := Rect2(_base_upg_btn.global_position, _base_upg_btn.size) if _base_upg_btn else Rect2()

	input_ctrl.register_hud(wave_rect, pause_rect, s1, s2, s3,
							sell_rect, tgt_rect, shop_d, upg_list, base_rect)

# ---------------------------------------------------------------------------
# Game loop
# ---------------------------------------------------------------------------

var _hud_rects_ready: bool = false

func _process(_delta: float) -> void:
	if not _hud_rects_ready:
		_refresh_hud_rects()
		_hud_rects_ready = true

	var now_ms: int = Time.get_ticks_msec()

	# Detect life loss for screen-space feedback.
	if game_state.lives < _prev_lives:
		var lost: int = _prev_lives - game_state.lives
		view_state.start_screen_shake(now_ms, 7.0, 400)
		view_state.show_toast(
			"%s — %d left" % [_BRAND.life_lost_toast(lost), game_state.lives],
			now_ms,
			1200
		)
	_prev_lives = game_state.lives

	view_state.tick(now_ms)
	game_state.update_simulation(now_ms)
	# Juice: kills and wave-clear (rising edges after sim step)
	if game_state.stat_enemies_killed > _prev_kills:
		JuiceManager.play(JuiceManager.SFX.ENEMY_DEATH)
	_prev_kills = game_state.stat_enemies_killed
	if game_state.wave_shop_pending and not _prev_wave_shop_pending:
		JuiceManager.play(JuiceManager.SFX.WAVE_CLEAR)
	_prev_wave_shop_pending = game_state.wave_shop_pending
	renderer.render_frame(now_ms)
	_update_selection_ring()
	_update_virtual_cursor(now_ms)
	_update_hud(now_ms)

	# Check for end states
	if game_state.game_state == "game_over" or game_state.game_state == "won":
		_on_run_ended()

func _update_hud(now_ms: int) -> void:
	if game_state.wave > _prev_wave:
		_show_wave_banner(game_state.wave)
		_prev_wave = game_state.wave
		
	_wave_label.text  = "Wave %d / %d" % [game_state.wave, _MAPS.MAX_WAVE]

	if _wave_progress_bar != null:
		var spawn_total: int = game_state.get_wave_spawn_total()
		var in_wave: bool = not game_state.wave_ready and not game_state.wave_shop_pending and spawn_total > 0
		_wave_progress_bar.visible = in_wave
		if in_wave:
			var killed := game_state.enemies_spawned - game_state.enemies.size()
			var ratio: float = float(maxi(0, killed)) / float(spawn_total)
			_wave_progress_bar.value = ratio
			_apply_wave_progress_style(ratio)

	var lives_txt: String = _BRAND.integrity(game_state.lives)
	if _lives_label.text != lives_txt:
		_lives_label.text = lives_txt
		_juice_label(_lives_label)

	var gold_txt: String = _BRAND.credits(game_state.gold)
	if _gold_label.text != gold_txt:
		_gold_label.text = gold_txt
		_juice_label(_gold_label)

	var sel: Tower = game_state.get_tower_by_id(view_state.selected_tower_id) if view_state.selected_tower_id >= 0 else null
	var fast_promotion: bool = Progression.get_settings().get("fast_promotion_enabled", false)
	var promo_visible: bool = view_state.promotion_pending and sel != null and not fast_promotion
	var pause_visible: bool = game_state.paused and game_state.game_state == "playing"
	var has_pending: bool = view_state.has_pending_placement()
	var wave_shop_visible: bool = game_state.wave_shop_pending
	var details_visible: bool = _details.is_open()
	var blocking_menu_visible: bool = wave_shop_visible or promo_visible or pause_visible or has_pending or details_visible
	
	# Instruction banner: persistent instructions have priority over contextual hints
	if _instruction_banner != null:
		if blocking_menu_visible:
			_instruction_banner.visible = false
		elif view_state.instruction_banner != "":
			_instruction_banner.visible = true
			_instruction_label.text = view_state.instruction_banner
		elif game_state.towers.size() == 0 and not view_state.placement_active:
			_instruction_banner.visible = true
			_instruction_label.text = _BRAND.INSTRUCTION_CHOOSE_TOWER
		elif view_state.placement_active:
			_instruction_banner.visible = true
			_instruction_label.text = _placement_hint_text()
		elif game_state.wave_ready and game_state.wave == 1 and game_state.enemies.size() == 0:
			_instruction_banner.visible = true
			_instruction_label.text = _BRAND.INSTRUCTION_START_WAVE
		else:
			_instruction_banner.visible = false

	_update_placement_confirm_bar()

	# Toast / message
	var toast: String = view_state.get_toast(now_ms)
	_msg_label.text = toast if toast != "" else game_state.last_message

	if _shop_scroll != null:
		_shop_scroll.visible = not blocking_menu_visible
	elif _shop_bar != null:
		_shop_bar.visible = not blocking_menu_visible

	# Wave button visibility
	_wave_btn.visible = game_state.wave_ready and game_state.game_state == "playing" and not blocking_menu_visible

	# Pause button
	_pause_btn.text = ">" if game_state.paused else "II"

	# Speed button highlights
	for i in _speed_btns.size():
		var mult: float = [1.0, 2.0, 3.0][i]
		_speed_btns[i].button_pressed = (game_state.speed_multiplier == mult)
		_THEME.apply_button(_speed_btns[i], "primary" if game_state.speed_multiplier == mult else "tab")

	# Tower panel
	var was_panel_hidden: bool = not _tower_panel.visible
	_tower_panel.visible = sel != null
	if sel != null:
		if was_panel_hidden:
			_base_upg_btn.grab_focus()
		_layout_tower_panel(sel)
		var pnames := ["Top","Middle","Bottom"]
		_tower_name_label.text = "%s  Lv.%d" % [sel.tower_name, sel.level]
		_tower_stats_label.text = "⚔ %d  ◎ %d  ⏱ %dms" % [sel.get_effective_damage(now_ms), int(sel.effective_range()), sel.effective_cooldown()]

		# Base Upgrade Delta
		if sel.level < 5:
			var base_cost: int = sel.base_upgrade_cost()
			var cur_dmg := sel.get_effective_damage(now_ms)
			var next_dmg := int(float(sel.base_damage) * pow(1.15, float(sel.level)))
			var d_dmg := next_dmg - int(float(sel.base_damage) * pow(1.15, float(sel.level-1)))
			_base_upg_btn.text = "UPGRADE (%dg) [ ⚔️ +%d ]" % [base_cost, d_dmg]
			_base_upg_btn.disabled = game_state.gold < base_cost
		else:
			_base_upg_btn.text = "MAX LEVEL"
			_base_upg_btn.disabled = true
			
		for i in _path_upg_btns.size():
			var path: String = pnames[i]
			var can: bool = sel.tracker.can_attempt_upgrade(path)
			var pcost: int = sel.path_upgrade_cost(path)
			var lvl: int = sel.tracker.path_levels[path]
			var p_data := _UP.get_path_data(sel.ttype, path)
			
			if can:
				var next_mult: float = p_data["tiers"][lvl]
				var cur_mult: float = p_data["tiers"][lvl-1] if lvl > 0 else 1.0
				var d_pct := int((next_mult - cur_mult) * 100.0)
				var icon := "⚔️" if "dmg" in p_data["name"].to_lower() else ("⚡" if "speed" in p_data["name"].to_lower() else "🎯")
				_path_upg_btns[i].text = "%s [ %s +%d%% ] %dg" % [p_data["name"].left(6), icon, d_pct, pcost]
				_path_upg_btns[i].disabled = game_state.gold < pcost
			else:
				_path_upg_btns[i].text = p_data["name"] + " (LOCKED)" if lvl == 0 else "MAX"
				_path_upg_btns[i].disabled = true
				
		_target_btn.text = "Target: %s" % sel.target_mode.capitalize()
		var sell_val: int = sel.sell_value(game_state.wave)
		_sell_btn.text = "Sell +%dg" % sell_val if not view_state.confirm_sell else "Confirm?"
		_sell_btn.disabled = game_state.sell_disabled

	if _promotion_modal:
		_promotion_modal.visible = promo_visible
		if promo_visible and sel != null:
			var pending_path: String = sel.tracker.pending_promotion_path
			_promotion_title.text = "Promote %s as secondary and lock the third path?" % pending_path
		if promo_visible and not _dpad_promo_open:
			_promotion_confirm_btn.grab_focus()
		elif not promo_visible and _dpad_promo_open:
			_dpad_return_focus()
		_dpad_promo_open = promo_visible

	if _pause_modal:
		_pause_modal.visible = pause_visible
		if pause_visible:
			_pause_title.text = _BRAND.pause_status(game_state.wave, game_state.lives, game_state.gold)
			if view_state.confirm_restart:
				var elapsed_ms: int = now_ms - _restart_confirm_start_ms
				var remaining_s: int = maxi(0, 4 - elapsed_ms / 1000)
				if remaining_s == 0 and _restart_confirm_start_ms > 0:
					view_state.confirm_restart = false
					_restart_confirm_start_ms = 0
					_restart_btn.text = "Restart Run"
					if _restart_confirm_bar != null:
						_restart_confirm_bar.visible = false
				else:
					_restart_btn.text = "Confirm Restart (%ds)" % remaining_s
					if _restart_confirm_bar != null:
						_restart_confirm_bar.visible = true
						_restart_confirm_bar.value = clampf(1.0 - float(elapsed_ms) / 4000.0, 0.0, 1.0)
			else:
				_restart_btn.text = "Restart Run"
				if _restart_confirm_bar != null:
					_restart_confirm_bar.visible = false
			_placement_mode_btn.text = "Placement: %s" % view_state.placement_mode.capitalize()
			_placement_confirm_toggle_btn.text = "Placement Confirm: %s" % ("On" if view_state.confirm_placement_enabled else "Off")
		else:
			view_state.confirm_restart = false
		if pause_visible and not _dpad_pause_open:
			_resume_btn.grab_focus()
		elif not pause_visible and _dpad_pause_open:
			_dpad_return_focus()
		_dpad_pause_open = pause_visible

	# P0: floating confirm bar only — keep center modal hidden so it never stacks over the map.
	if _placement_confirm_modal:
		_placement_confirm_modal.visible = false
	if has_pending and not _dpad_place_open:
		if _confirm_placement_btn != null:
			_confirm_placement_btn.grab_focus()
	elif not has_pending and _dpad_place_open:
		_dpad_return_focus()
	_dpad_place_open = has_pending

	# Shop button affordability — block active menus, dim-only for unaffordable towers.
	for ttype in _shop_btns:
		var cost: int = game_state._tower_purchase_cost(ttype)
		var can_afford: bool = game_state.gold >= cost
		var hard_disabled: bool = blocking_menu_visible or game_state.paused or ttype in game_state._disabled_towers
		_shop_btns[ttype].disabled = hard_disabled
		if hard_disabled:
			_shop_btns[ttype].modulate.a = 0.4
			_THEME.set_button_glow(_shop_btns[ttype], false)
		elif not can_afford:
			_shop_btns[ttype].modulate.a = 0.55
			_THEME.set_button_glow(_shop_btns[ttype], false)
		else:
			_shop_btns[ttype].modulate.a = 1.0
			_THEME.set_button_glow(_shop_btns[ttype], true)
		if ttype in _shop_cost_labels:
			var cost_lbl: Label = _shop_cost_labels[ttype]
			cost_lbl.text = "%dg" % cost
			cost_lbl.add_theme_color_override(
				"font_color",
				_SHOP_COST_AFFORD if can_afford and not hard_disabled else _SHOP_COST_DENY
			)

	# Wave shop: open modal when simulation signals shop is pending
	if game_state.wave_shop_pending and _wave_shop_modal != null and not _wave_shop_modal.visible:
		_show_wave_shop(now_ms)
	if blocking_menu_visible:
		_raise_visible_modal_controls()

func _update_selection_ring() -> void:
	if _selection_ring == null: return
	var sel: Tower = game_state.get_tower_by_id(view_state.selected_tower_id) if view_state.selected_tower_id >= 0 else null
	if sel == null:
		_selection_ring.visible = false
	else:
		_selection_ring.visible = true
		_selection_ring.position = sel.pos
		
		# Set color based on tower element/type
		var ring_color := _THEME.CYAN
		match sel.ttype:
			"mage", "lightning": ring_color = _THEME.VIOLET
			"cannon": ring_color = _THEME.ORANGE
			"sniper": ring_color = _THEME.GOLD
			"frost": ring_color = _THEME.CYAN
		
		_selection_ring.set_color(ring_color)

func _apply_wave_progress_style(ratio: float) -> void:
	if _wave_progress_bar == null:
		return
	var fill_color: Color
	if ratio >= 0.66:
		fill_color = _THEME.CYAN
	elif ratio >= 0.33:
		fill_color = _THEME.GOLD
	else:
		fill_color = _THEME.ORANGE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.12, 0.18, 0.75)
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.92)
	fill.set_corner_radius_all(2)
	_wave_progress_bar.add_theme_stylebox_override("background", bg)
	_wave_progress_bar.add_theme_stylebox_override("fill", fill)

func _juice_label(label: Label) -> void:
	var tween := create_tween()
	label.pivot_offset = label.size * 0.5
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _show_wave_banner(wave_num: int) -> void:
	var banner := preload("res://ui/widgets/WaveBanner.gd").new()
	hud_layer.add_child(banner)
	banner.display("WAVE %d INBOUND" % wave_num)
	var sfx := JuiceManager.SFX.BOSS_APPEAR if wave_num in [5, 10, 15] else JuiceManager.SFX.WAVE_START
	JuiceManager.play(sfx)

func _placement_check(pos: Vector2, tower_type: String) -> Array:
	if game_state == null or tower_type == "":
		return [false, "Cannot place here"]
	return game_state.can_place_tower(pos, tower_type)

func _placement_hint_text() -> String:
	if view_state == null or not view_state.placement_active:
		return ""
	var tower_type: String = view_state.placement_tower_type
	var check: Array = _placement_check(view_state.placement_ghost_pos, tower_type)
	if bool(check[0]):
		if view_state.placement_mode == "drag":
			return "VALID PLACEMENT - RELEASE TO BUILD"
		return "VALID PLACEMENT - TAP TO BUILD"
	return "INVALID - %s" % _PLACEMENT_HINTS.reason_hint(str(check[1]))

func _update_placement_confirm_bar() -> void:
	if _placement_confirm_bar == null:
		return
	if view_state.has_pending_placement():
		_placement_confirm_bar.visible = true
		var pos: Vector2 = _world_to_screen(view_state.pending_placement_pos)
		var bar_size: Vector2 = _placement_confirm_bar.size
		if bar_size.x <= 1.0 or bar_size.y <= 1.0:
			bar_size = _placement_confirm_bar.get_combined_minimum_size()
		var viewport: Vector2 = _LAYOUT.viewport_size(self)
		var margins: Dictionary = _LAYOUT.content_margins(viewport, self)
		var margin_l: float = float(margins["left"])
		var margin_r: float = float(margins["right"])
		var margin_t: float = float(margins["top"])
		var margin_b: float = float(margins["bottom"])
		var next_pos: Vector2 = pos + Vector2(-bar_size.x * 0.5, 40.0)
		next_pos.x = clampf(next_pos.x, margin_l, maxf(margin_l, viewport.x - bar_size.x - margin_r))
		next_pos.y = clampf(next_pos.y, margin_t, maxf(margin_t, viewport.y - bar_size.y - margin_b))
		_placement_confirm_bar.position = next_pos
		_confirm_placement_btn.disabled = not view_state.pending_placement_valid
	else:
		_placement_confirm_bar.visible = false

func _on_confirm_placement() -> void:
	if view_state.has_pending_placement() and view_state.pending_placement_valid:
		var action := {
			"type": "place_tower",
			"tower_type": view_state.pending_placement_type,
			"pos": view_state.pending_placement_pos
		}
		_dispatch(action, Time.get_ticks_msec())
		view_state.clear_pending_placement()

func _on_cancel_placement() -> void:
	view_state.clear_pending_placement()

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var pos: Vector2 = Vector2.ZERO
	var handled: bool = false

	# Dpad / keyboard accept — Godot fires Button.pressed automatically on focused buttons,
	# but we need ui_accept to also confirm placement when the bar is visible.
	if event.is_action_pressed("ui_accept"):
		if _placement_confirm_bar != null and _placement_confirm_bar.visible:
			_on_confirm_placement()
			get_viewport().set_input_as_handled()
			return

	# Dpad / keyboard cancel — layered dismiss (innermost modal first)
	if event.is_action_pressed("ui_cancel"):
		if _details.is_open():
			_details.close(game_state)
			get_viewport().set_input_as_handled()
			return
		if _wave_shop_modal != null and _wave_shop_modal.visible:
			_on_wave_shop_skip(now_ms)
		elif _promotion_modal != null and _promotion_modal.visible:
			_on_promotion_cancel_pressed()
		elif _pause_modal != null and _pause_modal.visible:
			_on_resume_pressed()
		elif _placement_confirm_modal != null and _placement_confirm_modal.visible:
			_on_cancel_placement_pressed()
		elif _placement_confirm_bar != null and _placement_confirm_bar.visible:
			_on_cancel_placement()
		elif view_state.placement_active:
			view_state.exit_placement()
			_dpad_return_focus()
		elif view_state.selected_tower_id >= 0:
			view_state.deselect_tower()
			_dpad_return_focus()
		elif game_state.game_state == "playing" and not game_state.paused:
			_on_pause_pressed()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		pos = event.position
		if _hud_captures_point(pos):
			return
		var world_pos: Vector2 = _screen_to_world(pos)
		if event.pressed:
			var action: Dictionary = input_ctrl.handle_press(world_pos, now_ms)
			_dispatch(action, now_ms)
			handled = true
		else:
			var action: Dictionary = input_ctrl.handle_release(world_pos, now_ms)
			_dispatch(action, now_ms)
			handled = true

	elif event is InputEventScreenDrag:
		input_ctrl.handle_drag(_screen_to_world(event.position), now_ms)
		handled = true

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
			if _hud_captures_point(pos):
				return
			var world_pos: Vector2 = _screen_to_world(pos)
			if event.pressed:
				var action: Dictionary = input_ctrl.handle_press(world_pos, now_ms)
				_dispatch(action, now_ms)
			else:
				var action: Dictionary = input_ctrl.handle_release(world_pos, now_ms)
				_dispatch(action, now_ms)
			handled = true

	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		input_ctrl.handle_drag(_screen_to_world(event.position), now_ms)
		handled = true

	if handled:
		get_viewport().set_input_as_handled()

func _hud_captures_point(pos: Vector2) -> bool:
	return _control_tree_captures_point(hud_layer, pos)

func _control_tree_captures_point(node: Node, pos: Vector2) -> bool:
	for child in node.get_children():
		if child is Control:
			var ctrl: Control = child
			if not ctrl.is_visible_in_tree():
				continue
			if _control_tree_captures_point(child, pos):
				return true
			if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			if Rect2(ctrl.global_position, ctrl.size).has_point(pos):
				return true
		elif _control_tree_captures_point(child, pos):
			return true
	return false

func _dispatch(action: Dictionary, now_ms: int) -> void:
	if action.is_empty():
		return
	if action.get("type", "") == "placement_failed":
		view_state.show_toast(_PLACEMENT_HINTS.format_ui_reason(str(action.get("reason", "Cannot place here"))), now_ms, 1200)
		return
	var result := game_state.apply_action(action, now_ms)
	_handle_action_result(result, action, now_ms)

func _handle_action_result(result: Dictionary, action: Dictionary, now_ms: int) -> void:
	if not result.get("success", false):
		if result.get("reason", "") != "":
			view_state.show_toast(_PLACEMENT_HINTS.format_ui_reason(str(result["reason"])), now_ms, 1000)
		return

	var atype: String = action.get("type", "")
	match atype:
		"place_tower":
			JuiceManager.play(JuiceManager.SFX.TOWER_PLACE)
			view_state.show_toast("Placed!", now_ms, 600)
			# Exit placement mode unless continuous placement is enabled and affordable.
			var cont_on: bool = Progression.get_settings().get("continuous_placement", true)
			var can_afford: bool = game_state.gold >= game_state._tower_purchase_cost(action.get("tower_type", ""))
			if not cont_on or not can_afford:
				view_state.exit_placement()
		"upgrade_base":
			JuiceManager.play(JuiceManager.SFX.TOWER_UPGRADE)
			view_state.show_toast(result.get("message",""), now_ms, 800)
		"upgrade_path":
			if result.get("preview_promotion", false):
				JuiceManager.play(JuiceManager.SFX.TOWER_PROMOTE)
				view_state.promotion_pending = true
				view_state.selected_tower_id = int(result.get("tower_id", view_state.selected_tower_id))
				if Progression.get_settings().get("fast_promotion_enabled", false):
					view_state.show_toast("Tap %s again to confirm." % action.get("path", ""), now_ms, 1600)
				else:
					view_state.show_toast("Confirm promotion?", now_ms, 2000)
			else:
				JuiceManager.play(JuiceManager.SFX.TOWER_UPGRADE)
				view_state.show_toast(result.get("message",""), now_ms, 800)
		"confirm_promotion":
			JuiceManager.play(JuiceManager.SFX.TOWER_PROMOTE)
			view_state.promotion_pending = false
			view_state.show_toast(result.get("message",""), now_ms, 1200)
		"cancel_promotion":
			view_state.promotion_pending = false
			view_state.show_toast(result.get("message",""), now_ms, 800)
		"sell_tower":
			JuiceManager.play(JuiceManager.SFX.TOWER_SELL)
			view_state.deselect_tower()
			view_state.show_toast(result.get("message",""), now_ms, 900)
			_dpad_return_focus()
		"select_tower":
			_hud_rects_ready = false   # refresh upgrade rect tower_ids
		"toggle_pause":
			view_state.confirm_restart = false
			view_state.show_toast(result.get("message",""), now_ms, 600)
			if not game_state.paused:
				_dpad_return_focus()

# ---------------------------------------------------------------------------
# HUD button signal handlers (delegate to input_ctrl action pattern)
# ---------------------------------------------------------------------------

func _on_wave_btn_pressed() -> void:
	_dispatch({"type": "start_wave"}, Time.get_ticks_msec())

func _on_pause_pressed() -> void:
	_dispatch({"type": "toggle_pause"}, Time.get_ticks_msec())

func _on_resume_pressed() -> void:
	if game_state.paused:
		_dispatch({"type": "toggle_pause"}, Time.get_ticks_msec())

func _on_restart_pressed() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if Progression.get_settings().get("confirm_restart", true) and not view_state.confirm_restart:
		view_state.confirm_restart = true
		_restart_confirm_start_ms = now_ms
		view_state.show_toast("Tap Restart again to confirm.", now_ms, 1200)
		return
	_restart_current_run()

func _on_quit_pressed() -> void:
	game_state.paused = false
	_fade_to_scene("res://scenes/MenuScreen.tscn")

func _on_placement_mode_toggle() -> void:
	var next_mode: String = "drop" if view_state.placement_mode == "drag" else "drag"
	Progression.set_setting("placement_mode", next_mode)
	view_state.configure_from_settings(Progression.get_settings())
	view_state.show_toast("Placement: %s" % next_mode.capitalize(), Time.get_ticks_msec(), 900)

func _on_placement_confirm_toggle() -> void:
	Progression.set_setting("confirm_placement_enabled", not view_state.confirm_placement_enabled)
	view_state.configure_from_settings(Progression.get_settings())
	var state: String = "on" if view_state.confirm_placement_enabled else "off"
	view_state.show_toast("Placement confirmation %s" % state, Time.get_ticks_msec(), 900)

func _on_speed_pressed(mult: float) -> void:
	_dispatch({"type": "set_speed", "multiplier": mult}, Time.get_ticks_msec())

func _on_base_upgrade_pressed() -> void:
	if view_state.selected_tower_id >= 0:
		_dispatch({"type": "upgrade_base", "tower_id": view_state.selected_tower_id},
				  Time.get_ticks_msec())

func _on_path_upgrade_pressed(path_name: String) -> void:
	if view_state.selected_tower_id >= 0:
		var selected: Tower = game_state.get_tower_by_id(view_state.selected_tower_id)
		if (
			selected != null
			and view_state.promotion_pending
			and Progression.get_settings().get("fast_promotion_enabled", false)
			and selected.tracker.pending_promotion_path == path_name
		):
			_dispatch({"type": "confirm_promotion", "tower_id": view_state.selected_tower_id},
					  Time.get_ticks_msec())
			return
		_dispatch({"type": "upgrade_path", "tower_id": view_state.selected_tower_id, "path": path_name},
				  Time.get_ticks_msec())

func _on_sell_pressed() -> void:
	if view_state.selected_tower_id < 0:
		return
	if not Progression.get_settings().get("confirm_sell", true):
		_dispatch({"type": "sell_tower", "tower_id": view_state.selected_tower_id},
				  Time.get_ticks_msec())
		return
	if view_state.confirm_sell:
		_dispatch({"type": "sell_tower", "tower_id": view_state.selected_tower_id},
				  Time.get_ticks_msec())
		view_state.confirm_sell = false
	else:
		view_state.confirm_sell = true

func _on_target_pressed() -> void:
	if view_state.selected_tower_id >= 0:
		_dispatch({"type": "cycle_target_mode", "tower_id": view_state.selected_tower_id},
				  Time.get_ticks_msec())

func _on_shop_btn_down(ttype: String) -> void:
	# Activate placement immediately on button-down so the ghost tracks drag gestures.
	# button_down fires on press; if the user simply clicks without dragging, pressed
	# fires on release and _on_shop_pressed re-enters placement (harmless) and shows the hint.
	view_state.enter_placement(ttype)
	view_state.placement_ghost_pos = Vector2(_MAPS.WIDTH * 0.5, _MAPS.HEIGHT * 0.5)
	view_state.placement_ghost_valid = false

func _on_shop_pressed(ttype: String) -> void:
	# Fires only on a clean click (no drag). Placement already active from button_down;
	# just re-confirm the type and show the placement hint.
	view_state.enter_placement(ttype)
	view_state.placement_ghost_pos = Vector2(_MAPS.WIDTH * 0.5, _MAPS.HEIGHT * 0.5)
	view_state.placement_ghost_valid = false
	var mode_text: String = "Tap the map to place." if view_state.placement_mode == "drop" else "Drag or tap the map to place."
	view_state.show_toast(mode_text, Time.get_ticks_msec(), 1000)

func _on_confirm_placement_pressed() -> void:
	if not view_state.has_pending_placement() or not view_state.pending_placement_valid:
		return
	var action := {
		"type": "place_tower",
		"tower_type": view_state.pending_placement_type,
		"pos": view_state.pending_placement_pos,
	}
	view_state.clear_pending_placement()
	_dispatch(action, Time.get_ticks_msec())

func _on_cancel_placement_pressed() -> void:
	view_state.clear_pending_placement()
	view_state.show_toast("Placement cancelled.", Time.get_ticks_msec(), 700)

func _on_info_pressed() -> void:
	if _details.is_open():
		_details.close(game_state)
		return
	var sel_id: int = view_state.selected_tower_id
	if sel_id < 0: return
	var tower := game_state.get_tower_by_id(sel_id)
	if tower == null: return
	_details.open(tower, game_state)

func _on_promotion_confirm_pressed() -> void:
	if view_state.selected_tower_id >= 0:
		_dispatch({"type": "confirm_promotion", "tower_id": view_state.selected_tower_id},
				  Time.get_ticks_msec())

func _on_promotion_cancel_pressed() -> void:
	if view_state.selected_tower_id >= 0:
		_dispatch({"type": "cancel_promotion", "tower_id": view_state.selected_tower_id},
				  Time.get_ticks_msec())

func _restart_current_run() -> void:
	var map_id: int = game_state.map_id
	var map_data: Dictionary = _MAPS.MAPS[map_id]
	var run_config: Dictionary = Progression.get_run_config()

	view_state = ViewState.new()
	view_state.configure_from_settings(Progression.get_settings())
	input_ctrl.view_state = view_state

	game_state = GameState.new(map_data["path"], run_config, map_id)
	_RUN_SETUP.apply_variant_stats(game_state)
	_RUN_SETUP.place_starting_tower(game_state, run_config)
	_backdrop_texture = load(_MAP_BG_PATHS.get(map_id, ""))
	input_ctrl.game_state = game_state
	renderer.game_state = game_state
	renderer.view_state = view_state
	renderer.rebuild_path_for_map(map_data["path"])

	_prev_lives = game_state.lives
	_prev_wave = game_state.wave
	_prev_kills = game_state.stat_enemies_killed
	_prev_wave_shop_pending = game_state.wave_shop_pending
	_hud_rects_ready = false
	set_process(true)
	view_state.show_toast("Game restarted.", Time.get_ticks_msec(), 900)

func _fade_to_scene(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.20)
	tween.tween_callback(func(): get_tree().change_scene_to_file(path))

# ---------------------------------------------------------------------------
# Run end — record to Progression and go to EndScreen
# ---------------------------------------------------------------------------

func _update_virtual_cursor(now_ms: int) -> void:
	if _virtual_cursor == null: return
	
	var is_remote := not Input.get_connected_joypads().is_empty() or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")
	
	if view_state.placement_active and is_remote:
		_virtual_cursor.visible = true
		var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var settings := Progression.get_settings()
		var sensitivity: float = settings.get("cursor_sensitivity", 1.0)
		var use_accel: bool = settings.get("cursor_acceleration", true)
		
		if move.length() > 0.1:
			_cursor_accel_time += get_process_delta_time()
			var accel_mult := 1.0
			if use_accel:
				# Logarithmic acceleration curve: starts at 1x, ramps to 2.5x over 1.2 seconds
				accel_mult = 1.0 + (log(_cursor_accel_time + 1.0) * 1.8)
			
			var base_speed := 450.0 * sensitivity
			var speed := base_speed * accel_mult * (2.0 if Input.is_action_pressed("ui_select") else 1.0)
			
			view_state.placement_ghost_pos += move * speed * get_process_delta_time()
			# Clamp to map
			view_state.placement_ghost_pos.x = clampf(view_state.placement_ghost_pos.x, 0, _MAPS.WIDTH)
			view_state.placement_ghost_pos.y = clampf(view_state.placement_ghost_pos.y, 0, _MAPS.HEIGHT)
		else:
			_cursor_accel_time = 0.0
		
		_virtual_cursor.position = view_state.placement_ghost_pos
		
		if Input.is_action_just_pressed("ui_accept"):
			_on_confirm_placement()
	else:
		_virtual_cursor.visible = false

func _on_run_ended() -> void:
	set_process(false)
	if game_state.game_state == "won":
		JuiceManager.play(JuiceManager.SFX.WIN)
	else:
		JuiceManager.play(JuiceManager.SFX.GAME_OVER)
	var run_result = Progression.record_run(game_state, game_state.map_id)
	var rp: int = run_result.get("rp", 0) if run_result is Dictionary else int(run_result)
	Progression.pending_end_stats = {
		"rp_earned":               rp,
		"waves":                   game_state.stat_waves_survived,
		"perfect_waves":           game_state.stat_perfect_waves,
		"lives":                   game_state.lives,
		"won":                     game_state.game_state == "won",
		"map_id":                  game_state.map_id,
		"towers_placed":           game_state.stat_towers_placed,
		"enemies_killed":          game_state.stat_enemies_killed,
		"gold_earned":             game_state.stat_gold_earned,
		"newly_unlocked_variants": run_result.get("newly_unlocked_variants", []) if run_result is Dictionary else [],
		"milestone_deltas":        run_result.get("milestone_deltas", []) if run_result is Dictionary else [],
	}
	get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
