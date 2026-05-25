extends Control
class_name MapSelectScreen

# Port of screens/map_select.py — card-based map selection.
# Draws procedural path thumbnails via Node2D child.

const _MAPS_DATA := preload("res://data/maps.gd")
const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BACKDROP := preload("res://rendering/backdrop/TechBackdrop.gd")
const _DIFFICULTY_LABELS: Array[String] = ["", "Easy", "Medium", "Hard"]
const _DIFFICULTY_COLORS: Array[Color] = [
	Color.WHITE,
	Color(0.42, 0.82, 0.45), # Muted Sage (Easy)
	Color(1.0, 0.72, 0.28),  # Solar Orange (Medium)
	Color(1.0, 0.32, 0.45),  # Electric Crimson (Hard)
]

@onready var _card_container: HBoxContainer = $Scroll/Cards
@onready var _back_btn: Button              = $TopBar/BackBtn
@onready var _top_bar: HBoxContainer        = $TopBar
@onready var _title: Label                  = $TopBar/Title
@onready var _scroll: ScrollContainer       = $Scroll
var _right_spacer: Control = null
var _mod_strip: HBoxContainer = null
var _mod_rp_lbl: Label = null
var _mod_btns: Dictionary = {}   # mod_id -> Button

func _ready() -> void:
	_add_backdrop()
	_back_btn.pressed.connect(_on_back)
	get_viewport().size_changed.connect(_apply_layout)
	_ensure_header_spacer()
	_build_modifier_strip()
	_build_cards()
	_apply_visuals()
	_apply_layout()
	_scroll.scroll_deadzone = 12

	FocusManager.register_initial_focus(_back_btn)

var _play_btns: Array[Button] = []

func _build_modifier_strip() -> void:
	_mod_strip = HBoxContainer.new()
	_mod_strip.add_theme_constant_override("separation", 6)
	add_child(_mod_strip)

	var strip_lbl := Label.new()
	strip_lbl.text = "MODIFIERS:"
	strip_lbl.add_theme_font_size_override("font_size", 12)
	strip_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	strip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mod_strip.add_child(strip_lbl)

	var unlocked: Array = Progression.load_profile().get("unlocked", [])
	for entry in Progression.MAP_MODIFIERS:
		var mid: String = entry[0]
		if mid not in unlocked:
			continue
		var btn := Button.new()
		btn.text = entry[2]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 36)
		_THEME.apply_button(btn, "tab")
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_mod_toggled.bind(mid))
		_mod_strip.add_child(btn)
		_mod_btns[mid] = btn

	_mod_rp_lbl = Label.new()
	_mod_rp_lbl.add_theme_font_size_override("font_size", 12)
	_mod_rp_lbl.add_theme_color_override("font_color", Color(0.47, 0.90, 1.0))
	_mod_rp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mod_strip.add_child(_mod_rp_lbl)

	_refresh_mod_strip()

func _on_mod_toggled(mod_id: String) -> void:
	var active: Array = Progression.get_active_modifier_ids()
	if mod_id == Progression.get_active_modifier():
		Progression.set_active_modifier("")
	elif mod_id == Progression.get_active_modifier_2():
		Progression.set_active_modifier_2("")
	elif active.is_empty():
		Progression.set_active_modifier(mod_id)
	else:
		Progression.set_active_modifier_2(mod_id)
	_refresh_mod_strip()

func _refresh_mod_strip() -> void:
	if _mod_strip == null:
		return
	var active: Array = Progression.get_active_modifier_ids()
	var mod1: String = Progression.get_active_modifier()
	for mid in _mod_btns:
		var btn: Button = _mod_btns[mid]
		var is_active: bool = mid in active
		btn.button_pressed = is_active
		_THEME.apply_button(btn, "primary" if is_active else "tab")
		# Grey out incompatible mods when one is already selected
		if active.size() == 1 and not is_active:
			var compatible: bool = Progression._modifiers_compatible(mod1, mid)
			btn.modulate.a = 1.0 if compatible else 0.35
			btn.disabled = not compatible
		else:
			btn.modulate.a = 1.0
			btn.disabled = false

	if _mod_rp_lbl:
		if active.is_empty():
			_mod_rp_lbl.text = ""
		elif active.size() == 1:
			var mult: float = Progression.MODIFIER_RP_MULT.get(active[0], 1.0)
			_mod_rp_lbl.text = "  RP ×%.1f" % mult
		else:
			var m_a: float = Progression.MODIFIER_RP_MULT.get(active[0], 1.0)
			var m_b: float = Progression.MODIFIER_RP_MULT.get(active[1], 1.0)
			var stacked: float = maxf(m_a, m_b) + 0.5
			_mod_rp_lbl.text = "  RP ×%.1f  (stacked)" % stacked

func _add_backdrop() -> void:
	var backdrop := _BACKDROP.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)

func _apply_visuals() -> void:
	_THEME.apply_button(_back_btn, "secondary")
	_THEME.apply_label(_title, "heading")

func _build_cards() -> void:
	for map_def in _MAPS_DATA.MAPS:
		var card := _make_card(map_def)
		_card_container.add_child(card)

func _make_card(map_def: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 420)
	_THEME.apply_panel(card, "card")
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.focus_mode = Control.FOCUS_ALL
	card.pivot_offset = Vector2(150, 210)
	
	card.mouse_entered.connect(func():
		var t := card.create_tween().set_parallel(true)
		t.tween_property(card, "scale", Vector2(1.025, 1.025), 0.15).set_trans(Tween.TRANS_QUAD)
		t.tween_property(card, "modulate", Color(1.1, 1.1, 1.2), 0.15)
		card.z_index = 10
	)
	card.mouse_exited.connect(func():
		var t := card.create_tween().set_parallel(true)
		t.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)
		t.tween_property(card, "modulate", Color.WHITE, 0.2)
		card.z_index = 0
	)
	
	card.focus_entered.connect(func():
		var t := card.create_tween().set_parallel(true)
		t.tween_property(card, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_QUAD)
		t.tween_property(card, "modulate", Color(1.2, 1.2, 1.4), 0.2)
		card.z_index = 10
	)
	card.focus_exited.connect(func():
		var t := card.create_tween().set_parallel(true)
		t.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)
		t.tween_property(card, "modulate", Color.WHITE, 0.2)
		card.z_index = 0
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Path thumbnail
	var thumb := _PathThumb.new(map_def["path"])
	thumb.custom_minimum_size = Vector2(272, 170)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(thumb)
	card.set_meta("thumb", thumb)

	# Map name
	var name_lbl := Label.new()
	name_lbl.text = map_def["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	_THEME.apply_label(name_lbl, "body")
	vbox.add_child(name_lbl)

	# Difficulty badge
	var diff_lbl := Label.new()
	var difficulty: int = int(map_def["difficulty"])
	var diff_text: String = _DIFFICULTY_LABELS[difficulty]
	diff_lbl.text = diff_text
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var diff_color: Color = _DIFFICULTY_COLORS[difficulty]
	diff_lbl.add_theme_color_override("font_color", diff_color)
	_THEME.apply_badge(diff_lbl, "danger" if difficulty >= 3 else "cost" if difficulty == 2 else "owned")
	vbox.add_child(diff_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = map_def["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	_THEME.apply_label(desc_lbl, "muted")
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.clip_text = true
	vbox.add_child(desc_lbl)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(0, _LAYOUT.TOUCH_HEIGHT)
	_THEME.apply_button(play_btn, "primary")
	play_btn.pressed.connect(_on_play_map.bind(map_def["id"]))
	vbox.add_child(play_btn)
	_play_btns.append(play_btn)
	_link_neighbors.call_deferred(play_btn)
	return card

func _link_neighbors(play_btn: Button) -> void:
	if not is_inside_tree() or not play_btn.is_inside_tree():
		return
	# Horizontal neighbors between play buttons
	if _play_btns.size() > 1:
		var prev = _play_btns[_play_btns.size() - 2]
		if prev.is_inside_tree():
			prev.focus_neighbor_right = play_btn.get_path()
			play_btn.focus_neighbor_left = prev.get_path()

	# Back button above play buttons; play buttons below back button
	if _back_btn.is_inside_tree():
		play_btn.focus_neighbor_top = _back_btn.get_path()
		_back_btn.focus_neighbor_bottom = play_btn.get_path()

	# If modifier strip has buttons, insert them between back and play
	if _mod_strip != null:
		var mod_btns: Array = _mod_strip.get_children().filter(func(c): return c is Button)
		if not mod_btns.is_empty():
			play_btn.focus_neighbor_top = mod_btns[0].get_path()
			for mb in mod_btns:
				mb.focus_neighbor_bottom = play_btn.get_path()
				mb.focus_neighbor_top    = _back_btn.get_path()
			_back_btn.focus_neighbor_bottom = mod_btns[0].get_path()

func _ensure_header_spacer() -> void:
	if _right_spacer != null:
		return
	_right_spacer = Control.new()
	_right_spacer.custom_minimum_size = Vector2(104.0, 1.0)
	_top_bar.add_child(_right_spacer)

func _apply_layout() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	var margin: float = _LAYOUT.edge_margin(viewport)
	var top: float = _LAYOUT.top_margin(viewport)
	_LAYOUT.apply_rect(_top_bar, Rect2(Vector2(margin, top), Vector2(maxf(0.0, viewport.x - margin * 2.0), 52.0)))
	_back_btn.custom_minimum_size = Vector2(104.0, _LAYOUT.TOUCH_HEIGHT)
	if _right_spacer:
		_right_spacer.custom_minimum_size = Vector2(104.0, 1.0)
	_title.add_theme_font_size_override("font_size", 34 if viewport.x >= 1050.0 else 30)

	var mod_strip_h: float = 0.0
	if _mod_strip != null and _mod_strip.get_child_count() > 1:
		_LAYOUT.apply_rect(_mod_strip, Rect2(Vector2(margin, top + 58.0), Vector2(maxf(0.0, viewport.x - margin * 2.0), 40.0)))
		mod_strip_h = 46.0

	var scroll_top: float = top + 66.0 + mod_strip_h
	var content: Rect2 = _LAYOUT.centered_rect(viewport, scroll_top, _LAYOUT.bottom_margin(viewport), 1360.0)
	_LAYOUT.apply_rect(_scroll, content)
	_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.add_theme_constant_override("separation", 32)
	_card_container.custom_minimum_size = Vector2(content.size.x, content.size.y)

	var card_w: float = clampf((content.size.x - 32.0) / 3.0, 250.0, 350.0)
	var card_h: float = minf(maxf(390.0, content.size.y - 8.0), 460.0)
	for child in _card_container.get_children():
		if child is PanelContainer:
			child.custom_minimum_size = Vector2(card_w, card_h)
			var thumb = child.get_meta("thumb", null)
			if thumb is Control:
				thumb.custom_minimum_size = Vector2(maxf(180.0, card_w - 28.0), clampf(card_h * 0.40, 154.0, 188.0))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _on_play_map(map_id: int) -> void:
	Progression.pending_map_id = map_id
	_fade_to("res://scenes/GameScreen.tscn")

func _on_back() -> void:
	_fade_to("res://scenes/MenuScreen.tscn")

func _fade_to(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): get_tree().change_scene_to_file(path))

# ---------------------------------------------------------------------------
# Inner class: procedural path thumbnail drawn via _draw()
# ---------------------------------------------------------------------------

class _PathThumb extends Control:
	var _path: Array = []  # Array[Vector2]

	func _init(path: Array) -> void:
		_path = path

	func _draw() -> void:
		if _path.size() < 2:
			return
		var draw_size: Vector2 = size
		if draw_size.x <= 0.0 or draw_size.y <= 0.0:
			draw_size = custom_minimum_size

		var min_x: float = INF
		var max_x: float = -INF
		var min_y: float = INF
		var max_y: float = -INF
		for p_variant in _path:
			var p: Vector2 = p_variant
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)

		var span_x: float = maxf(max_x - min_x, 1.0)
		var span_y: float = maxf(max_y - min_y, 1.0)
		var pad: float = 14.0
		var s: float = minf((draw_size.x - pad * 2.0) / span_x, (draw_size.y - pad * 2.0) / span_y)
		var off_x: float = pad + ((draw_size.x - pad * 2.0) - span_x * s) / 2.0
		var off_y: float = pad + ((draw_size.y - pad * 2.0) - span_y * s) / 2.0

		var pts: PackedVector2Array = []
		for p_variant in _path:
			var p: Vector2 = p_variant
			pts.append(Vector2(off_x + (p.x - min_x) * s, off_y + (p.y - min_y) * s))

		# Road layers (matches Python draw order)
		draw_polyline(pts, Color(0, 0, 0, 0.7), 8.0)
		draw_polyline(pts, Color(0.071, 0.086, 0.149, 1.0), 6.5)
		draw_polyline(pts, Color(0.141, 0.165, 0.267, 1.0), 5.0)
		draw_polyline(pts, Color(0.173, 0.204, 0.314, 1.0), 3.5)
		draw_polyline(pts, Color(0.204, 0.573, 1.0, 0.22), 5.5)
		draw_polyline(pts, Color(0.204, 0.573, 1.0, 0.70), 2.5)

		# Start dot (green)
		draw_circle(pts[0], 5.0, Color(0, 0.863, 0.51))
		# End dot (red)
		draw_circle(pts[-1], 5.0, Color(0.863, 0.235, 0.314))
