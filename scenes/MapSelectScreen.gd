extends Control
class_name MapSelectScreen

# Port of screens/map_select.py — card-based map selection.
# Draws procedural path thumbnails via Node2D child.

const _MAPS_DATA := preload("res://data/maps.gd")
const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BRAND := preload("res://ui/theme/BrandCopy.gd")
const _BACKDROP := preload("res://rendering/backdrop/CorporateDistrictBackdrop.gd")
const _MapScenicThumb := preload("res://rendering/ui/MapScenicThumb.gd")
const _CARD_ORDER: Array[int] = [2, 1, 0]
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
var _shards_pill: PanelContainer = null
var _shards_lbl: Label = null
var _mod_scroll: ScrollContainer = null
var _mod_strip: HBoxContainer = null
var _mod_rp_lbl: Label = null
var _mod_btns: Dictionary = {}   # mod_id -> Button

func _ready() -> void:
	_add_backdrop()
	_add_shards_pill()
	_back_btn.pressed.connect(_on_back)
	get_viewport().size_changed.connect(_apply_layout)
	_ensure_header_spacer()
	_build_modifier_strip()
	_build_cards()
	_apply_visuals()
	_apply_layout()
	_scroll.scroll_deadzone = 12
	_scroll.follow_focus = true
	_refresh_shards()

	FocusManager.register_initial_focus(_back_btn)

var _play_btns: Array[Button] = []

func _build_modifier_strip() -> void:
	# A row of five unlocked modifiers does not fit a phone landscape. Wrap it
	# in a horizontal scroller so every modifier remains reachable.
	_mod_scroll = ScrollContainer.new()
	_mod_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_mod_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mod_scroll.scroll_deadzone = 12
	_mod_scroll.follow_focus = true
	add_child(_mod_scroll)
	_mod_strip = HBoxContainer.new()
	_mod_strip.add_theme_constant_override("separation", 6)
	_mod_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mod_scroll.add_child(_mod_strip)

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
		btn.custom_minimum_size = Vector2(0, _LAYOUT.MIN_TOUCH_HEIGHT)
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
	# Do not render an orphan "MODIFIERS:" heading when nothing is owned yet.
	_mod_scroll.visible = not _mod_btns.is_empty()

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
			_mod_rp_lbl.text = _BRAND.shards_mult(mult, false)
		else:
			var m_a: float = Progression.MODIFIER_RP_MULT.get(active[0], 1.0)
			var m_b: float = Progression.MODIFIER_RP_MULT.get(active[1], 1.0)
			var stacked: float = maxf(m_a, m_b) + 0.5
			_mod_rp_lbl.text = _BRAND.shards_mult(stacked, true)

func _add_backdrop() -> void:
	var backdrop := _BACKDROP.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var bg := get_node_or_null("BG")
	if bg is CanvasItem:
		(bg as CanvasItem).visible = false
		move_child(backdrop, bg.get_index() + 1)
	else:
		move_child(backdrop, 0)

func _add_shards_pill() -> void:
	_shards_pill = PanelContainer.new()
	_shards_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _THEME.style_box(Color(0.04, 0.07, 0.13, 0.9), Color(0.29, 0.56, 0.85, 0.55), 1, 14, 0, 6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_shards_pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_shards_pill.add_child(row)
	var shard_icon := TextureRect.new()
	shard_icon.texture = load("res://assets/sprites/production/ui/shards.svg")
	shard_icon.custom_minimum_size = Vector2(16.0, 16.0)
	shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(shard_icon)
	var cap := Label.new()
	cap.text = _BRAND.CURRENCY_META
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", _THEME.CYAN)
	row.add_child(cap)
	_shards_lbl = Label.new()
	_shards_lbl.text = "0"
	_shards_lbl.add_theme_font_size_override("font_size", 14)
	_shards_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	row.add_child(_shards_lbl)
	add_child(_shards_pill)

func _refresh_shards() -> void:
	if _shards_lbl == null:
		return
	var profile: Dictionary = Progression.load_profile()
	_shards_lbl.text = str(profile.get("banked_rp", 0))

func _apply_visuals() -> void:
	_THEME.apply_button(_back_btn, "secondary")
	_THEME.apply_label(_title, "heading")

func _build_cards() -> void:
	for map_id in _CARD_ORDER:
		var map_def: Dictionary = _MAPS_DATA.MAPS[map_id]
		var card := _make_card(map_def)
		_card_container.add_child(card)

func _make_card(map_def: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 420)
	var is_recommended: bool = int(map_def.get("id", -1)) == 2
	if is_recommended:
		var rec_sb := _THEME.style_box(Color(0.08, 0.12, 0.20, 0.95), _THEME.GOLD, 3, 10, 0, 14)
		rec_sb.content_margin_left = 0.0
		rec_sb.content_margin_top = 0.0
		rec_sb.content_margin_right = 0.0
		rec_sb.content_margin_bottom = 0.0
		card.add_theme_stylebox_override("panel", rec_sb)
	else:
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
	var thumb := _MapScenicThumb.new(map_def)
	thumb.custom_minimum_size = Vector2(272, 198)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(thumb)
	card.set_meta("thumb", thumb)

	# Map name
	var name_lbl := Label.new()
	name_lbl.text = str(map_def.get("name", "")).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	_THEME.apply_label(name_lbl, "body")
	vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = str(map_def.get("subtitle", ""))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.45, 0.82, 0.95, 0.9))
	_THEME.apply_label(sub_lbl, "muted")
	vbox.add_child(sub_lbl)
	var rec_lbl: Label = null
	if is_recommended:
		rec_lbl = Label.new()
		rec_lbl.text = "★ RECOMMENDED"
		rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec_lbl.add_theme_font_size_override("font_size", 10)
		rec_lbl.add_theme_color_override("font_color", _THEME.GOLD)
		vbox.add_child(rec_lbl)

	# Difficulty badge
	var diff_lbl := Label.new()
	var difficulty: int = int(map_def["difficulty"])
	var diff_text: String = _DIFFICULTY_LABELS[difficulty].to_upper()
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
	desc_lbl.max_lines_visible = 3
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	card.set_meta("layout_name", name_lbl)
	card.set_meta("layout_sub", sub_lbl)
	card.set_meta("layout_diff", diff_lbl)
	card.set_meta("layout_desc", desc_lbl)
	card.set_meta("layout_play", play_btn)
	if rec_lbl != null:
		card.set_meta("layout_rec", rec_lbl)
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
	if _shards_pill:
		_shards_pill.position = Vector2(viewport.x - margin - 118.0, top + 8.0)

	var mod_strip_h: float = 0.0
	if _mod_strip != null and not _mod_btns.is_empty():
		_LAYOUT.apply_rect(_mod_scroll, Rect2(Vector2(margin, top + 58.0), Vector2(maxf(0.0, viewport.x - margin * 2.0), _LAYOUT.MIN_TOUCH_HEIGHT + 4.0)))
		mod_strip_h = _LAYOUT.MIN_TOUCH_HEIGHT + 10.0

	var scroll_top: float = top + 66.0 + mod_strip_h
	var content: Rect2 = _LAYOUT.centered_rect(viewport, scroll_top, _LAYOUT.bottom_margin(viewport), 1360.0)
	_LAYOUT.apply_rect(_scroll, content)
	# Only surface a scrollbar when the card row genuinely overflows. AUTO still
	# reserves a track when three cards already fit, which read as a stray bar.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.custom_minimum_size = Vector2(content.size.x, content.size.y)

	# Fit the cards to the height that actually exists. The old 390px minimum
	# clipped every PLAY button below a 320px landscape viewport, and vertical
	# scrolling was disabled, so the primary action was unreachable.
	var compact_cards: bool = content.size.y < 340.0
	var card_sep: float = 10.0 if compact_cards else 32.0
	_card_container.add_theme_constant_override("separation", int(card_sep))
	var min_card_w: float = 140.0 if viewport.x < 1000.0 else 250.0
	var card_w: float = clampf((content.size.x - card_sep * 2.0) / 3.0, min_card_w, 350.0)
	_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
		if card_w * 3.0 + card_sep * 2.0 <= content.size.x + 1.0
		else ScrollContainer.SCROLL_MODE_AUTO)
	var card_h: float = clampf(content.size.y, 140.0, 460.0)
	var ultra_compact: bool = card_h < 300.0
	var card_margin: int = 8 if ultra_compact else 14
	var card_vsep: int = 4 if ultra_compact else 8
	var play_h: float = _LAYOUT.MIN_TOUCH_HEIGHT if ultra_compact else _LAYOUT.TOUCH_HEIGHT
	for child in _card_container.get_children():
		if child is PanelContainer:
			child.custom_minimum_size = Vector2(card_w, card_h)
			# Keep the hover/focus scale anchored to the card centre at every
			# size; the fixed (150,210) pivot drifted outside compact cards.
			child.pivot_offset = Vector2(card_w, card_h) * 0.5
			var card_margin_node: Node = child.get_child(0)
			if card_margin_node is MarginContainer:
				card_margin_node.add_theme_constant_override("margin_left", card_margin)
				card_margin_node.add_theme_constant_override("margin_top", card_margin)
				card_margin_node.add_theme_constant_override("margin_right", card_margin)
				card_margin_node.add_theme_constant_override("margin_bottom", card_margin)
				var card_vbox: Node = card_margin_node.get_child(0)
				if card_vbox is VBoxContainer:
					card_vbox.add_theme_constant_override("separation", card_vsep)
					# Keep every essential row inside the card; only the thumbnail
					# and description absorb the available height.
					var show_desc: bool = card_h >= 260.0 and not ultra_compact
					var show_sub: bool = show_desc
					var sep_count: int = 2
					if show_sub:
						sep_count += 1
					if show_desc:
						sep_count += 2
					else:
						sep_count += 1
					var chrome_h: float = float(card_margin * 2) + float(card_vsep * sep_count) \
						+ (16.0 if ultra_compact else 24.0) \
						+ (22.0 if ultra_compact else 31.0) + play_h
					var thumb_h: float = clampf(card_h - chrome_h - (34.0 if show_desc else 0.0), 36.0, 188.0)
					var thumb = child.get_meta("thumb", null)
					if thumb is Control:
						thumb.custom_minimum_size = Vector2(maxf(110.0, card_w - float(card_margin * 2)), thumb_h)
					var name_lbl = child.get_meta("layout_name", null)
					var diff_lbl = child.get_meta("layout_diff", null)
					var desc_lbl = child.get_meta("layout_desc", null)
					var play_btn = child.get_meta("layout_play", null)
					if name_lbl is Label and diff_lbl is Label and desc_lbl is Label and play_btn is Button:
						var sub_lbl = child.get_meta("layout_sub") if child.has_meta("layout_sub") else null
						var rec_lbl = child.get_meta("layout_rec") if child.has_meta("layout_rec") else null
						name_lbl.add_theme_font_size_override("font_size", 15 if ultra_compact else (17 if compact_cards else 20))
						if sub_lbl is Label:
							sub_lbl.visible = show_desc and not ultra_compact
							sub_lbl.add_theme_font_size_override("font_size", 9 if ultra_compact else 10)
						if rec_lbl is Label:
							rec_lbl.visible = not ultra_compact
						diff_lbl.add_theme_font_size_override("font_size", 11 if ultra_compact else 13)
						desc_lbl.add_theme_font_size_override("font_size", 10 if ultra_compact else 12)
						desc_lbl.visible = show_desc and not ultra_compact
						play_btn.custom_minimum_size = Vector2(0.0, play_h)
						play_btn.add_theme_font_size_override("font_size", 14 if ultra_compact else 16)

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

