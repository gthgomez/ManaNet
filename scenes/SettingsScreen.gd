extends Control
class_name SettingsScreen

# Port of screens/settings.py — global gameplay settings.

const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BACKDROP := preload("res://rendering/backdrop/TechBackdrop.gd")

const _SETTING_ROWS := [
	["gold_efficiency_enabled",  "Gold Efficiency RP Bonus",
	 "Adds RP for spending gold efficiently over the run.",            true],
	["show_upgrade_tutorial",    "Show Upgrade Tutorial",
	 "Shows the path-promotion explainer on first branch.",            true],
	["fast_promotion_enabled",   "Fast Promotion",
	 "Double-tap a new branch to commit promotion without a modal.",   false],
	["confirm_restart",          "Confirm Restart",
	 "Requires a second tap before restarting an active run.",         true],
	["confirm_sell",             "Confirm Sell",
	 "Requires a second tap before selling a placed tower.",           true],
	["continuous_placement",      "Continuous Placement",
	 "Automatically keep the build tool active after placement.",      true],
	["cursor_acceleration",       "Cursor Acceleration",
	 "Gradually increases cursor speed while moving for smoother navigation.", true],
	["pause_on_tower_info",       "Pause on Tower Info",
	 "Automatically pauses the game while the '!' upgrade info panel is open.", true],
]

const _OPTION_ROWS := [
	["default_speed",       "Default Speed",       "Initial run speed for each new game.", ["1x", "2x", "3x"], [1.0, 2.0, 3.0]],
	["default_target_mode", "Default Target Mode", "Initial targeting mode for newly built towers.", ["First", "Strong", "Close"], ["first", "strong", "close"]],
	["placement_mode",      "Placement Style",     "How towers are moved onto the map.", ["Drag & Release", "Tap to Drop"], ["drag", "drop"]],
	["cursor_sensitivity",  "Cursor Sensitivity",  "Base movement speed for the virtual tactical cursor.", ["Low", "Normal", "High", "Ultra"], [0.6, 1.0, 1.6, 2.5]],
]

@onready var _rows_box: VBoxContainer = $Scroll/Content/RowsBox
@onready var _back_btn: Button        = $TopBar/BackBtn
@onready var _top_bar: HBoxContainer  = $TopBar
@onready var _title: Label            = $TopBar/Title
@onready var _scroll: ScrollContainer = $Scroll
@onready var _content: VBoxContainer  = $Scroll/Content
var _right_spacer: Control = null
var _glass: Panel = null
var _layout_settled: bool = false

func _ready() -> void:
	# Start invisible for fade-in
	self.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

	_add_backdrop()
	_back_btn.pressed.connect(_on_back)
	FocusManager.back_pressed.connect(_on_back)
	
	get_viewport().size_changed.connect(_on_viewport_changed)
	_ensure_header_spacer()
	_apply_visuals()
	_apply_layout()
	_build()
	
	# Handle Fire TV / Remote focus
	FocusManager.register_initial_focus(_back_btn)

func _on_viewport_changed() -> void:
	_layout_settled = false
	_apply_layout()

func _process(_delta: float) -> void:
	if not _layout_settled:
		var viewport: Vector2 = _LAYOUT.viewport_size(self)
		if viewport.x > 10.0 and viewport.y > 10.0:
			_apply_layout()
			_layout_settled = true

func _ensure_glass() -> void:
	if _glass != null:
		return
	_glass = Panel.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glass)
	# Behind TopBar (3) and Scroll (4) but in front of BG (0) and Backdrop (-1)
	# Wait, if Backdrop is at 0, and we want Glass at 1, and BG at 2... 
	# Actually, standard TD stack: Backdrop(0) -> BG(1) -> Glass(2) -> Content(3+)
	# Let's use that.
	move_child(_glass, 2) 
	_THEME.apply_glass_panel(_glass)

func _add_backdrop() -> void:
	var backdrop := _BACKDROP.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0) # Absolute bottom
	
	# Ensure BG is at 1 (above backdrop)
	var bg = get_node_or_null("BG")
	if bg:
		move_child(bg, 1)

func _apply_visuals() -> void:
	_THEME.apply_button(_back_btn, "secondary")
	_THEME.apply_label(_title, "heading")

func _ensure_header_spacer() -> void:
	if _right_spacer != null:
		return
	_right_spacer = Control.new()
	_right_spacer.custom_minimum_size = Vector2(132.0, 1.0)
	_top_bar.add_child(_right_spacer)

func _apply_layout() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	var margin: float = _LAYOUT.edge_margin(viewport)
	var top: float = _LAYOUT.top_margin(viewport)
	_LAYOUT.apply_rect(_top_bar, Rect2(Vector2(margin, top), Vector2(maxf(0.0, viewport.x - margin * 2.0), 52.0)))
	_back_btn.custom_minimum_size = Vector2(132.0, _LAYOUT.TOUCH_HEIGHT)
	if _right_spacer:
		_right_spacer.custom_minimum_size = Vector2(132.0, 1.0)
	_title.add_theme_font_size_override("font_size", 32 if viewport.x >= 1050.0 else 28)

	var content_rect: Rect2 = _LAYOUT.centered_rect(viewport, top + 66.0, _LAYOUT.bottom_margin(viewport), 1320.0)
	_ensure_glass()
	_LAYOUT.apply_rect(_glass, content_rect)
	_LAYOUT.apply_rect(_scroll, content_rect)
	_content.custom_minimum_size = Vector2(maxf(0.0, content_rect.size.x - 42.0), 0.0)
	_rows_box.custom_minimum_size = Vector2(maxf(0.0, content_rect.size.x - 42.0), 0.0)

func _build() -> void:
	# Clear old rows
	for child in _rows_box.get_children():
		child.queue_free()

	var settings: Dictionary = Progression.get_settings()

	for row_def in _SETTING_ROWS:
		var key: String   = row_def[0]
		var title: String = row_def[1]
		var desc: String  = row_def[2]
		var default: bool = row_def[3]
		var enabled: bool = settings.get(key, default)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		row.custom_minimum_size = Vector2(0, 76)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = title
		_THEME.apply_label(name_lbl, "body")
		col.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		_THEME.apply_label(desc_lbl, "muted")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc_lbl)
		row.add_child(col)

		var tog_btn := Button.new()
		tog_btn.text = "ON" if enabled else "OFF"
		_THEME.apply_button(tog_btn, "primary" if enabled else "danger")
		# Standardized width for all settings buttons
		tog_btn.custom_minimum_size = Vector2(140, _LAYOUT.TOUCH_HEIGHT)
		tog_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tog_btn.pressed.connect(_on_toggle.bind(key, enabled))
		row.add_child(tog_btn)

		_rows_box.add_child(row)
		_rows_box.add_child(HSeparator.new())

	# ---- Data Section (Maintenance) ----
	var data_header := Label.new()
	data_header.text = "Data Management"
	_THEME.apply_label(data_header, "heading")
	data_header.add_theme_font_size_override("font_size", 20)
	_rows_box.add_child(data_header)
	
	var data_row := HBoxContainer.new()
	data_row.add_theme_constant_override("separation", 24)
	data_row.custom_minimum_size = Vector2(0, 76)
	
	var data_col := VBoxContainer.new()
	data_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var data_lbl := Label.new()
	data_lbl.text = "Maintenance Actions"
	_THEME.apply_label(data_lbl, "body")
	data_col.add_child(data_lbl)
	var data_desc := Label.new()
	data_desc.text = "Reset tutorials or all local gameplay settings."
	_THEME.apply_label(data_desc, "muted")
	data_desc.add_theme_font_size_override("font_size", 12)
	data_col.add_child(data_desc)
	data_row.add_child(data_col)
	
	var btn_vbox := VBoxContainer.new()
	btn_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_vbox.add_theme_constant_override("separation", 8)
	
	var res_tut_btn := Button.new()
	res_tut_btn.text = "Reset Tutorials"
	_THEME.apply_button(res_tut_btn, "shop")
	res_tut_btn.custom_minimum_size = Vector2(160, 42)
	res_tut_btn.pressed.connect(_on_reset_tutorials)
	btn_vbox.add_child(res_tut_btn)
	
	var res_set_btn := Button.new()
	res_set_btn.text = "Reset Settings"
	_THEME.apply_button(res_set_btn, "danger")
	res_set_btn.custom_minimum_size = Vector2(160, 42)
	res_set_btn.pressed.connect(_on_reset_settings)
	btn_vbox.add_child(res_set_btn)
	
	data_row.add_child(btn_vbox)
	_rows_box.add_child(data_row)
	_rows_box.add_child(HSeparator.new())

	for row_def in _OPTION_ROWS:
		var key: String = row_def[0]
		var title: String = row_def[1]
		var desc: String = row_def[2]
		var labels: Array = row_def[3]
		var values: Array = row_def[4]
		var current = settings.get(key, values[0])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		row.custom_minimum_size = Vector2(0, 76)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = title
		_THEME.apply_label(name_lbl, "body")
		col.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		_THEME.apply_label(desc_lbl, "muted")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc_lbl)
		row.add_child(col)

		var current_idx: int = values.find(current)
		if current_idx < 0:
			current_idx = 0
		var opt_btn := Button.new()
		opt_btn.text = labels[current_idx]
		_THEME.apply_button(opt_btn, "secondary")
		# Standardized width for all settings buttons
		opt_btn.custom_minimum_size = Vector2(140, _LAYOUT.TOUCH_HEIGHT)
		opt_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		opt_btn.pressed.connect(_on_cycle_option.bind(key, values, current_idx))
		row.add_child(opt_btn)

		_rows_box.add_child(row)
		_rows_box.add_child(HSeparator.new())

	# Link all buttons for vertical navigation
	var all_btns: Array[Control] = []
	all_btns.append(_back_btn)
	for child in _rows_box.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is Button:
					all_btns.append(sub)
	FocusManager.setup_dpad_neighbors(all_btns, true)

func _on_toggle(key: String, current: bool) -> void:
	Progression.set_setting(key, not current)
	_build()

func _on_cycle_option(key: String, values: Array, current_idx: int) -> void:
	var next_idx: int = (current_idx + 1) % values.size()
	Progression.set_setting(key, values[next_idx])
	_build()

func _on_reset_tutorials() -> void:
	Progression.set_setting("show_upgrade_tutorial", true)
	_build()

func _on_reset_settings() -> void:
	Progression.reset_settings()
	_build()

func _on_back() -> void:
	_fade_to("res://scenes/MenuScreen.tscn")

func _fade_to(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): 
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			printerr("Failed to change scene to %s: %d" % [path, err])
			self.modulate.a = 1.0 # Recovery
	)
