class_name WaveShopModalController
extends RefCounted

# Owns the between-wave shop modal: chrome build, card grid, layout metrics,
# and dpad focus wiring. Extracted from GameScreen.gd (behavior-preserving).
# The owning screen keeps a reference to `modal` so z-order raising, ui_cancel
# handling, and responsive re-layout continue to operate on the same node.

signal card_picked(card_id: String, now_ms: int)
signal skipped(now_ms: int)

const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BRAND := preload("res://ui/theme/BrandCopy.gd")
const _CARDS := preload("res://data/wave_shop_cards.gd")

# Mirrors GameScreen panel palette (kept literal to avoid a circular preload)
const _PANEL_TEXT: Color = Color(0.92, 0.94, 0.98, 1.0)
const _PANEL_MUTED: Color = Color(0.66, 0.70, 0.78, 1.0)

## Injected by the owner: Callable(Button) applying the shared readability style.
var button_readability: Callable = Callable()

var modal: PanelContainer = null
var scroll: ScrollContainer = null
var desired_size: Vector2 = Vector2(520.0, 320.0)

var _card_btns: Array = []
var _skip_btn: Button = null

func _init(hud_layer: CanvasLayer) -> void:
	modal = PanelContainer.new()
	modal.visible = false
	modal.custom_minimum_size = Vector2.ZERO
	modal.clip_contents = true
	modal.z_index = 100  # GameScreen._Z_MODAL
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_THEME.apply_panel(modal, "modal")
	hud_layer.add_child(modal)

func is_open() -> bool:
	return modal != null and modal.visible

## Rebuilds the modal content. The owner then positions the modal, makes it
## visible, raises it above other HUD controls, plays the open SFX, and calls
## finish_open() — preserving the original operation order exactly.
func show_shop(wave: int, modifier_id: String, now_ms: int, host: Node) -> void:
	# Rebuild content each time
	for child in modal.get_children():
		child.queue_free()
	scroll = null

	var viewport: Vector2 = _LAYOUT.viewport_size(host)
	var card_columns: int = _LAYOUT.wave_shop_card_columns(viewport)
	var card_min: Vector2 = _LAYOUT.wave_shop_card_min_size()
	desired_size = _LAYOUT.wave_shop_desired_size(viewport, host)

	# Chrome heights are fixed so the scroll region can be hard-capped (prevents
	# PanelContainer min-size growth that overflowed short phone landscapes).
	var m_side: int = 12 if card_columns < 3 else 14
	var m_top: int = 8 if card_columns < 3 else 10
	var vbox_sep: int = 6 if card_columns < 3 else 8
	var title_font: int = 15 if _LAYOUT.is_short_height(viewport) else 17
	var help_font: int = 11 if _LAYOUT.is_short_height(viewport) else 12
	var title_h: float = float(title_font + 6)
	var help_h: float = float(help_font + 6)
	var skip_h: float = _LAYOUT.min_touch_height(true)
	var chrome_h: float = float(m_top * 2) + title_h + help_h + skip_h + float(vbox_sep * 3)
	var scroll_h: float = maxf(96.0, desired_size.y - chrome_h)
	var card_h: float
	if card_columns > 1:
		card_h = minf(168.0, maxf(card_min.y + 12.0, scroll_h - 8.0))
	else:
		card_h = minf(180.0, maxf(120.0, scroll_h * 0.42))

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", m_side)
	margin.add_theme_constant_override("margin_top", m_top)
	margin.add_theme_constant_override("margin_right", m_side)
	margin.add_theme_constant_override("margin_bottom", m_top)
	modal.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", vbox_sep)
	margin.add_child(vbox)

	var is_milestone: bool = wave in [5, 10, 15]
	var title := Label.new()
	title.text = _BRAND.wave_shop_header(wave, is_milestone)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if is_milestone else _THEME.GOLD)
	title.add_theme_font_size_override("font_size", title_font)
	title.custom_minimum_size = Vector2(0.0, title_h)
	vbox.add_child(title)

	var help := Label.new()
	help.text = _BRAND.WAVE_SHOP_HELP
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", _PANEL_MUTED)
	help.add_theme_font_size_override("font_size", help_font)
	help.custom_minimum_size = Vector2(0.0, help_h)
	vbox.add_child(help)

	var pool := _CARDS.filtered_pool(modifier_id)
	var drawn: Array = _CARDS.draw_cards(pool, 3, wave)

	var scroll_container := ScrollContainer.new()
	scroll = scroll_container
	scroll_container.scroll_deadzone = 12
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.custom_minimum_size = Vector2(0.0, scroll_h)
	scroll_container.clip_contents = true
	vbox.add_child(scroll_container)

	var card_grid := GridContainer.new()
	card_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	card_grid.columns = card_columns
	card_grid.add_theme_constant_override("h_separation", 10)
	card_grid.add_theme_constant_override("v_separation", 10)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(card_grid)

	_card_btns = []
	for card in drawn:
		var card_panel := PanelContainer.new()
		card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		card_panel.custom_minimum_size = Vector2(minf(card_min.x, 150.0), card_h)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_panel.clip_contents = true
		_THEME.apply_panel(card_panel, "card")
		card_grid.add_child(card_panel)

		var card_margin := MarginContainer.new()
		card_margin.mouse_filter = Control.MOUSE_FILTER_PASS
		card_margin.add_theme_constant_override("margin_left", 8)
		card_margin.add_theme_constant_override("margin_top", 6)
		card_margin.add_theme_constant_override("margin_right", 8)
		card_margin.add_theme_constant_override("margin_bottom", 6)
		card_panel.add_child(card_margin)

		var card_vbox := VBoxContainer.new()
		card_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		card_vbox.add_theme_constant_override("separation", 4)
		card_margin.add_child(card_vbox)

		var card_title := Label.new()
		card_title.text = "%s %s" % [card.get("icon", ""), card["label"]]
		card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_title.max_lines_visible = 2
		card_title.add_theme_color_override("font_color", _PANEL_TEXT)
		card_title.add_theme_font_size_override("font_size", 13 if _LAYOUT.is_short_height(viewport) else 14)
		card_vbox.add_child(card_title)

		var card_desc := Label.new()
		card_desc.text = card["desc"]
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_desc.max_lines_visible = 4 if card_columns == 1 else 3
		card_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_desc.add_theme_color_override("font_color", _PANEL_MUTED)
		card_desc.add_theme_font_size_override("font_size", 11 if _LAYOUT.is_short_height(viewport) else 12)
		card_vbox.add_child(card_desc)

		var card_btn := Button.new()
		card_btn.text = "Choose"
		card_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.min_touch_height(false))
		card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_btn.size_flags_vertical = Control.SIZE_SHRINK_END
		_THEME.apply_button(card_btn, "primary")
		card_btn.add_theme_font_size_override("font_size", 12)
		card_btn.pressed.connect(_emit_card_picked.bind(card["id"], now_ms))
		card_vbox.add_child(card_btn)
		_card_btns.append(card_btn)

	var skip_button := Button.new()
	skip_button.text = _BRAND.skip_bonus_start_wave(wave)
	skip_button.custom_minimum_size = Vector2(0.0, skip_h)
	skip_button.size_flags_vertical = Control.SIZE_SHRINK_END
	if button_readability.is_valid():
		button_readability.call(skip_button)
	skip_button.pressed.connect(_emit_skipped.bind(now_ms))
	vbox.add_child(skip_button)
	_skip_btn = skip_button

func finish_open() -> void:
	FocusManager.setup_dpad_neighbors(_card_btns, false)
	if not _card_btns.is_empty():
		for cb in _card_btns:
			FocusManager.set_neighbor(cb, "bottom", _skip_btn)
		FocusManager.set_neighbor(_skip_btn, "top", _card_btns[0])
		_card_btns[0].grab_focus()

func _emit_card_picked(card_id: String, now_ms: int) -> void:
	card_picked.emit(card_id, now_ms)

func _emit_skipped(now_ms: int) -> void:
	skipped.emit(now_ms)
