extends Control
class_name CyberDeckScreen

# Meta-progression shop: purchase starting-tower unlocks, convenience upgrades,
# and view/activate earned tower variants.

const _THEME  := preload("res://ui/theme/GameTheme.gd")
const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _BACKDROP := preload("res://rendering/backdrop/TechBackdrop.gd")

@onready var _back_btn:  Button         = $TopBar/BackBtn
@onready var _title_lbl: Label          = $TopBar/Title
@onready var _rp_lbl:    Label          = $TopBar/RPLabel
@onready var _top_bar:   HBoxContainer  = $TopBar
@onready var _tab_bar:   HBoxContainer  = $TabBar
@onready var _scroll:    ScrollContainer = $Scroll
@onready var _content:   VBoxContainer  = $Scroll/ContentMargin/Content

var _active_tab: String = "shop"
var _tab_btns: Dictionary = {}   # tab_id -> Button
var _card_btns: Array = []
var _navigating: bool = false

# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	var backdrop := _BACKDROP.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	_apply_visuals()
	_build_tab_bar()
	_scroll.scroll_deadzone = 12
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	if _content.get_parent() is Control:
		_content.get_parent().mouse_filter = Control.MOUSE_FILTER_PASS
	_show_tab("shop")
	_apply_layout()

	_back_btn.pressed.connect(_on_back)
	get_viewport().size_changed.connect(_on_resize)

	self.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

	FocusManager.back_pressed.connect(_on_back)
	FocusManager.register_initial_focus(_back_btn)

func _apply_visuals() -> void:
	_THEME.apply_button(_back_btn, "secondary")
	_title_lbl.add_theme_color_override("font_color", _THEME.GOLD)
	_rp_lbl.add_theme_color_override("font_color", _THEME.GOLD)
	_back_btn.custom_minimum_size = Vector2(128.0, _LAYOUT.min_touch_height(false))
	_rp_lbl.custom_minimum_size = Vector2(116.0, _LAYOUT.min_touch_height(false))
	_refresh_rp()

func _refresh_rp() -> void:
	_rp_lbl.text = "Shards: %d" % Progression.get_banked_rp()

func _on_resize() -> void:
	_apply_layout()
	_show_tab(_active_tab)

func _apply_layout() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	var margin: float = _LAYOUT.edge_margin(viewport)
	var top: float = _LAYOUT.top_margin(viewport)
	var bottom: float = _LAYOUT.bottom_margin(viewport)
	var top_h: float = maxf(_LAYOUT.min_touch_height(false), viewport.y * 0.07)
	var tab_h: float = 44.0
	var tab_gap: float = 8.0
	var scroll_gap: float = 6.0

	_LAYOUT.apply_rect(_top_bar, Rect2(Vector2(margin, top), Vector2(maxf(0.0, viewport.x - margin * 2.0), top_h)))
	_LAYOUT.apply_rect(_tab_bar, Rect2(Vector2(margin, top + top_h + tab_gap), Vector2(maxf(0.0, viewport.x - margin * 2.0), tab_h)))

	var scroll_top: float = top + top_h + tab_gap + tab_h + scroll_gap
	var scroll_h: float = maxf(0.0, viewport.y - scroll_top - bottom)
	_LAYOUT.apply_rect(_scroll, Rect2(Vector2(margin, scroll_top), Vector2(maxf(0.0, viewport.x - margin * 2.0), scroll_h)))

# ──────────────────────────────────────────────────────────────────────────────
# Tab bar
# ──────────────────────────────────────────────────────────────────────────────

func _build_tab_bar() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	_tab_btns.clear()

	var tabs := [["shop", "SHOP"], ["variants", "VARIANTS"]]
	for pair in tabs:
		var tid: String  = pair[0]
		var tlbl: String = pair[1]
		var btn := Button.new()
		btn.text = tlbl
		btn.custom_minimum_size = Vector2(120.0, 36.0)
		btn.toggle_mode = false
		_THEME.apply_button(btn, "secondary")
		btn.pressed.connect(_show_tab.bind(tid))
		_tab_bar.add_child(btn)
		_tab_btns[tid] = btn

func _update_tab_visuals() -> void:
	for tid in _tab_btns:
		var btn: Button = _tab_btns[tid]
		if tid == _active_tab:
			btn.add_theme_color_override("font_color", _THEME.GOLD)
			btn.add_theme_stylebox_override("normal",
				_THEME.style_box(Color(0.10, 0.15, 0.10, 0.95), _THEME.GOLD, 2, 6))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")

# ──────────────────────────────────────────────────────────────────────────────
# Content rendering
# ──────────────────────────────────────────────────────────────────────────────

func _show_tab(tab_id: String) -> void:
	_active_tab = tab_id
	_update_tab_visuals()
	_clear_content()
	_card_btns.clear()

	if tab_id == "shop":
		_build_shop()
	else:
		_build_variants()

	# Wire dpad through all card buttons vertically
	if _card_btns.size() > 0:
		FocusManager.setup_dpad_neighbors(_card_btns, true)
		FocusManager.set_neighbor(_card_btns[0], "top", _tab_btns.get(_active_tab, _back_btn))

func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# Shop tab
# ──────────────────────────────────────────────────────────────────────────────

func _build_shop() -> void:
	_add_section_header("Starting Tower Upgrades",
		"Unlock free towers at the start of each run. Purchased in order.")

	var unlocked: Array = Progression.get_profile().get("unlocked", [])
	var active_st: String = Progression.get_profile().get("active_starting_tower", "")
	var chain_ids: Array  = []
	for entry in Progression.STARTING_TOWER_CHAIN:
		chain_ids.append(entry[0])

	for i in Progression.STARTING_TOWER_CHAIN.size():
		var entry: Array = Progression.STARTING_TOWER_CHAIN[i]
		var uid: String   = entry[0]
		var cost: int     = entry[1]
		var lbl: String   = entry[3]

		var owned: bool   = uid in unlocked
		var prereq_ok: bool = (i == 0) or (chain_ids[i - 1] in unlocked)
		var active: bool  = (uid == active_st)

		var desc_text: String = ""
		match entry[2]:
			"archer":    desc_text = "Guaranteed Archer tower ready at wave start."
			"frost":     desc_text = "Guaranteed Frost tower ready at wave start."
			"mage":      desc_text = "Guaranteed Mage tower ready at wave start."
			"lightning": desc_text = "Guaranteed Lightning tower ready at wave start."
			"sniper":    desc_text = "Guaranteed Sniper tower ready at wave start."
			"cannon":    desc_text = "Guaranteed Cannon tower ready at wave start."
			"choice":    desc_text = "Pick any tower type freely at wave start."

		var buy_cb := func():
			var result := Progression.purchase_upgrade(uid)
			if result["success"]:
				_refresh_rp()
				_show_tab("shop")

		var activate_cb := func():
			var new_active := uid if not active else ""
			Progression.set_active_starting_tower(new_active)
			_show_tab("shop")

		var card := _make_shop_card(lbl, desc_text, cost, owned, prereq_ok, active, buy_cb, activate_cb)
		_content.add_child(card)

	_add_spacer(12.0)
	_add_section_header("Convenience Upgrades", "Passive bonuses applied at the start of every run.")

	for entry in Progression.CONVENIENCE_UPGRADES:
		var uid: String  = entry[0]
		var cost: int    = entry[1]
		var lbl: String  = entry[2]
		var desc: String = entry[3]
		var owned: bool  = uid in unlocked

		# bonus_gold_25 replaces bonus_gold_10; bonus_life_2 replaces bonus_life_1
		var superseded := false
		if uid == "bonus_gold_10" and "bonus_gold_25" in unlocked:
			superseded = true
		if uid == "bonus_life_1" and "bonus_life_2" in unlocked:
			superseded = true

		var prereq_ok := true
		if uid == "bonus_gold_25" and not "bonus_gold_10" in unlocked:
			prereq_ok = false
		if uid == "bonus_life_2" and not "bonus_life_1" in unlocked:
			prereq_ok = false

		var buy_cb := func():
			var result := Progression.purchase_upgrade(uid)
			if result["success"]:
				_refresh_rp()
				_show_tab("shop")

		var card := _make_simple_card(lbl, desc, cost, owned, prereq_ok, superseded, buy_cb)
		_content.add_child(card)

# ──────────────────────────────────────────────────────────────────────────────
# Variants tab
# ──────────────────────────────────────────────────────────────────────────────

func _build_variants() -> void:
	_add_section_header("Tower Variants",
		"Earned by playing — place towers and rack up kills to unlock each variant.")

	var profile := Progression.get_profile()
	var unlocked_v: Array = profile.get("unlocked_variants", [])
	var use_counts: Dictionary  = profile.get("tower_use_counts", {})
	var kill_counts: Dictionary = profile.get("tower_kill_counts", {})
	var active_variants: Dictionary = profile.get("active_variants", {})

	for variant in Progression.TOWER_VARIANTS:
		var vkey: String    = variant["variant_key"]
		var ttype: String   = variant["tower_type"]
		var lbl: String     = variant["label"]
		var desc: String    = variant["desc"]
		var ut: int         = variant["use_threshold"]
		var kt: int         = variant["kill_threshold"]
		var tint: Color     = variant.get("visual_tint", _THEME.CYAN)
		var unlocked: bool  = vkey in unlocked_v
		var active: bool    = active_variants.get(ttype, "") == vkey

		var uses: int  = use_counts.get(ttype, 0)
		var kills: int = kill_counts.get(ttype, 0)
		var u_pct: float  = clampf(float(uses) / float(maxi(1, ut)), 0.0, 1.0)
		var k_pct: float  = clampf(float(kills) / float(maxi(1, kt)), 0.0, 1.0)

		var activate_cb := func():
			var new_v := vkey if not active else ""
			Progression.set_active_variant(ttype, new_v)
			_show_tab("variants")

		var card := _make_variant_card(lbl, ttype, desc, tint, unlocked, active,
			uses, kills, ut, kt, u_pct, k_pct, activate_cb)
		_content.add_child(card)

# ──────────────────────────────────────────────────────────────────────────────
# Card builders
# ──────────────────────────────────────────────────────────────────────────────

func _make_shop_card(
		lbl: String, desc: String, cost: int,
		owned: bool, prereq_ok: bool, active: bool,
		buy_cb: Callable, activate_cb: Callable) -> Control:

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_THEME.apply_panel(panel, "card")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Left: text
	var vtext := VBoxContainer.new()
	vtext.mouse_filter = Control.MOUSE_FILTER_PASS
	vtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtext.add_theme_constant_override("separation", 3)
	hbox.add_child(vtext)

	var name_lbl := Label.new()
	name_lbl.text = lbl
	_THEME.apply_label(name_lbl, "body")
	if owned:
		name_lbl.add_theme_color_override("font_color", _THEME.GREEN if not active else _THEME.GOLD)
	vtext.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_THEME.apply_label(desc_lbl, "muted")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vtext.add_child(desc_lbl)

	# Right: controls
	var vctrl := VBoxContainer.new()
	vctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	vctrl.add_theme_constant_override("separation", 4)
	vctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vctrl)

	if owned:
		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(100.0, 34.0)
		if active:
			act_btn.text = "Active ✓"
			_THEME.apply_button(act_btn, "primary")
		else:
			act_btn.text = "Activate"
			_THEME.apply_button(act_btn, "secondary")
		act_btn.pressed.connect(activate_cb)
		vctrl.add_child(act_btn)
		_card_btns.append(act_btn)
	elif not prereq_ok:
		var lock_lbl := Label.new()
		lock_lbl.text = "Locked"
		_THEME.apply_label(lock_lbl, "muted")
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vctrl.add_child(lock_lbl)
	else:
		var cost_lbl := Label.new()
		cost_lbl.text = "%d Shards" % cost
		_THEME.apply_label(cost_lbl, "currency")
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vctrl.add_child(cost_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(80.0, 34.0)
		_THEME.apply_button(buy_btn, "primary")
		var can_afford: bool = Progression.get_banked_rp() >= cost
		if not can_afford:
			buy_btn.modulate.a = 0.5
		buy_btn.pressed.connect(buy_cb)
		vctrl.add_child(buy_btn)
		_card_btns.append(buy_btn)

	return panel

func _make_simple_card(
		lbl: String, desc: String, cost: int,
		owned: bool, prereq_ok: bool, superseded: bool,
		buy_cb: Callable) -> Control:

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_THEME.apply_panel(panel, "card")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var vtext := VBoxContainer.new()
	vtext.mouse_filter = Control.MOUSE_FILTER_PASS
	vtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtext.add_theme_constant_override("separation", 3)
	hbox.add_child(vtext)

	var name_lbl := Label.new()
	name_lbl.text = lbl
	_THEME.apply_label(name_lbl, "body")
	if owned:
		name_lbl.add_theme_color_override("font_color", _THEME.GREEN)
	elif superseded:
		name_lbl.add_theme_color_override("font_color", _THEME.MUTED)
	vtext.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_THEME.apply_label(desc_lbl, "muted")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vtext.add_child(desc_lbl)

	var vctrl := VBoxContainer.new()
	vctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	vctrl.add_theme_constant_override("separation", 4)
	vctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vctrl)

	if owned or superseded:
		var status_lbl := Label.new()
		status_lbl.text = "Owned ✓" if owned else "Replaced"
		_THEME.apply_label(status_lbl, "muted")
		if owned:
			status_lbl.add_theme_color_override("font_color", _THEME.GREEN)
		status_lbl.add_theme_font_size_override("font_size", 13)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vctrl.add_child(status_lbl)
	elif not prereq_ok:
		var lock_lbl := Label.new()
		lock_lbl.text = "Locked"
		_THEME.apply_label(lock_lbl, "muted")
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vctrl.add_child(lock_lbl)
	else:
		var cost_lbl := Label.new()
		cost_lbl.text = "%d Shards" % cost
		_THEME.apply_label(cost_lbl, "currency")
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vctrl.add_child(cost_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(80.0, 34.0)
		_THEME.apply_button(buy_btn, "primary")
		var can_afford: bool = Progression.get_banked_rp() >= cost
		if not can_afford:
			buy_btn.modulate.a = 0.5
		buy_btn.pressed.connect(buy_cb)
		vctrl.add_child(buy_btn)
		_card_btns.append(buy_btn)

	return panel

func _make_variant_card(
		lbl: String, ttype: String, desc: String, tint: Color,
		unlocked: bool, active: bool,
		uses: int, kills: int, ut: int, kt: int,
		u_pct: float, k_pct: float,
		activate_cb: Callable) -> Control:

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_THEME.apply_panel(panel, "card")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Tint badge
	var badge := ColorRect.new()
	badge.custom_minimum_size = Vector2(6.0, 0.0)
	badge.color = tint if unlocked else _THEME.MUTED
	hbox.add_child(badge)

	var vtext := VBoxContainer.new()
	vtext.mouse_filter = Control.MOUSE_FILTER_PASS
	vtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtext.add_theme_constant_override("separation", 4)
	hbox.add_child(vtext)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vtext.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = lbl
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_THEME.apply_label(name_lbl, "body")
	if unlocked:
		name_lbl.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.4))
	else:
		name_lbl.add_theme_color_override("font_color", _THEME.MUTED)
	top_row.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = ttype.capitalize()
	_THEME.apply_label(type_lbl, "muted")
	type_lbl.add_theme_font_size_override("font_size", 11)
	top_row.add_child(type_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_THEME.apply_label(desc_lbl, "muted")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vtext.add_child(desc_lbl)

	if not unlocked:
		# Progress bars
		var prog_box := VBoxContainer.new()
		prog_box.mouse_filter = Control.MOUSE_FILTER_PASS
		prog_box.add_theme_constant_override("separation", 3)
		vtext.add_child(prog_box)

		prog_box.add_child(_make_progress_row("Place", uses, ut, u_pct, _THEME.CYAN))
		prog_box.add_child(_make_progress_row("Kills", kills, kt, k_pct, _THEME.ORANGE))

	# Right: activate button (only if unlocked)
	var vctrl := VBoxContainer.new()
	vctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	vctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vctrl)

	if unlocked:
		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(100.0, 36.0)
		if active:
			act_btn.text = "Active ✓"
			_THEME.apply_button(act_btn, "primary")
			act_btn.add_theme_color_override("font_color", tint)
		else:
			act_btn.text = "Activate"
			_THEME.apply_button(act_btn, "secondary")
		act_btn.pressed.connect(activate_cb)
		vctrl.add_child(act_btn)
		_card_btns.append(act_btn)
	else:
		var pct_lbl := Label.new()
		var avg_pct := int((u_pct + k_pct) * 50.0)
		pct_lbl.text = "%d%%" % avg_pct
		_THEME.apply_label(pct_lbl, "muted")
		pct_lbl.add_theme_font_size_override("font_size", 13)
		pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pct_lbl.custom_minimum_size = Vector2(48.0, 0.0)
		vctrl.add_child(pct_lbl)

	return panel

func _make_progress_row(label: String, current: int, maximum: int, pct: float, bar_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "%s %d/%d" % [label, mini(current, maximum), maximum]
	_THEME.apply_label(lbl, "muted")
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.value = pct
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.show_percentage = false
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = bar_color
	fill_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_sb)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.15, 0.17, 0.20)
	bg_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_sb)
	row.add_child(bar)

	return row

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

func _add_section_header(title: String, subtitle: String = "") -> void:
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator",
		_THEME.style_box(Color.TRANSPARENT, _THEME.CYAN.darkened(0.5), 1, 0))
	_content.add_child(sep)

	var lbl := Label.new()
	lbl.text = title
	_THEME.apply_label(lbl, "body")
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", _THEME.CYAN)
	_content.add_child(lbl)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_THEME.apply_label(sub, "muted")
		sub.add_theme_font_size_override("font_size", 11)
		_content.add_child(sub)

func _add_spacer(height: float) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0.0, height)
	_content.add_child(sp)

# ──────────────────────────────────────────────────────────────────────────────
# Navigation
# ──────────────────────────────────────────────────────────────────────────────

func _on_back() -> void:
	if _navigating:
		return
	_navigating = true
	_fade_to("res://scenes/MenuScreen.tscn")

func _fade_to(path: String) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			printerr("CyberDeckScreen: scene change failed: %s (%d)" % [path, err])
			self.modulate.a = 1.0
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
