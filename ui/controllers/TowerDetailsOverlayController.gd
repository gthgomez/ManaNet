class_name TowerDetailsOverlayController
extends RefCounted

# Owns the "i" tower-details overlay: dim backdrop, styled panel, per-path cards,
# and the auto-pause bookkeeping. Extracted from GameScreen.gd (behavior-preserving).
# The owning screen reads `overlay` so modal z-order raising keeps working on the
# same node, and routes explicit closes through close(game_state) so the live
# simulation instance is used even if the run was restarted mid-session.

const _UP   := preload("res://data/upgrade_paths.gd")
const _MAPS := preload("res://data/maps.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")

## Injected by owner: Callable() -> GameState returning the live run state.
var resolve_game_state: Callable = Callable()
## Injected by owner: Callable() raising visible modal controls above the HUD.
var raise_to_top: Callable = Callable()

var overlay: PanelContainer = null
var _auto_paused: bool = false
var _hud_layer: CanvasLayer = null

func _init(hud_layer: CanvasLayer) -> void:
	_hud_layer = hud_layer

func is_open() -> bool:
	return overlay != null

func open(tower: Tower, game_state: GameState) -> void:
	close(game_state)

	# Auto-pause if the setting is enabled and the game is not already paused
	if Progression.get_settings().get("pause_on_tower_info", true) and not game_state.paused:
		game_state.paused = true
		_auto_paused = true

	var vp: Vector2 = _hud_layer.get_viewport().get_visible_rect().size
	var panel_w: float = clampf(vp.x - 32.0, 280.0, 540.0)
	var panel_h: float = clampf(vp.y - 64.0, 200.0, 560.0)

	# Z values mirror GameScreen._Z_OVERLAY_BACKDROP / _Z_OVERLAY
	var z_backdrop: int = 110
	var z_overlay: int = 120

	# Dim backdrop — click anywhere on it to dismiss
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.z_index = z_backdrop
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_via_resolver()
	)
	_hud_layer.add_child(backdrop)

	overlay = PanelContainer.new()
	overlay.z_index = z_overlay
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.11, 0.97)
	style.set_border_width_all(2)
	style.border_color = Color(0.18, 0.69, 1.0, 0.7)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.5, 1.0, 0.25)
	style.shadow_size = 12
	overlay.add_theme_stylebox_override("panel", style)
	overlay.set_meta("backdrop", backdrop)

	# Position centred, but anchored to top-left so size doesn't fight the anchor
	overlay.position = Vector2(
		(vp.x - panel_w) * 0.5,
		(vp.y - panel_h) * 0.5
	)
	overlay.size = Vector2(panel_w, panel_h)
	_hud_layer.add_child(overlay)
	if raise_to_top.is_valid():
		raise_to_top.call()

	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 12
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# ── Header ──────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(header)

	var title := Label.new()
	title.text = "%s — Upgrade Paths" % tower.tower_name
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.18, 0.69, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	_THEME.apply_button(close_btn, "secondary")
	close_btn.pressed.connect(_close_via_resolver)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ── Current stats row ───────────────────────────────────────────────────
	var now_ms: int = Time.get_ticks_msec()
	var stats_lbl := Label.new()
	stats_lbl.text = "DMG %d   Range %d   CD %dms" % [
		tower.get_effective_damage(now_ms),
		int(tower.effective_range()),
		tower.effective_cooldown()
	]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(stats_lbl)

	# ── One card per upgrade path ────────────────────────────────────────────
	for path in _MAPS.PATH_KEYS:
		var p_data := _UP.get_path_data(tower.ttype, path)
		var cur: int = tower.tracker.path_levels[path]

		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.10, 0.13, 0.18, 0.85)
		card_sb.set_border_width_all(1)
		card_sb.border_color = Color(0.18, 0.69, 1.0, 0.25)
		card_sb.set_corner_radius_all(6)
		card_sb.content_margin_left = 10
		card_sb.content_margin_right = 10
		card_sb.content_margin_top = 8
		card_sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.mouse_filter = Control.MOUSE_FILTER_PASS
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)

		# Path name + level dots on one line
		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_PASS
		cvbox.add_child(top_row)

		var p_name := Label.new()
		p_name.text = p_data["name"]
		p_name.add_theme_font_size_override("font_size", 14)
		p_name.add_theme_color_override("font_color", Color(0.18, 0.69, 1.0))
		p_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(p_name)

		var dots := ""
		for k in range(5):
			dots += "●" if k < cur else "○"
		var p_prog := Label.new()
		p_prog.text = dots
		p_prog.add_theme_font_size_override("font_size", 14)
		p_prog.add_theme_color_override("font_color",
			Color(0.3, 0.9, 0.55) if cur > 0 else Color(0.4, 0.45, 0.5))
		top_row.add_child(p_prog)

		var p_desc := Label.new()
		p_desc.text = p_data["desc"]
		p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p_desc.add_theme_font_size_override("font_size", 12)
		p_desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
		p_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cvbox.add_child(p_desc)

		var next_lvl := mini(4, cur)
		var power := int((p_data["tiers"][next_lvl] - 1.0) * 100.0)
		var p_stats := Label.new()
		p_stats.text = "Next upgrade: +%d%% power" % power if cur < 5 else "MAX LEVEL"
		p_stats.add_theme_font_size_override("font_size", 11)
		p_stats.add_theme_color_override("font_color",
			Color(1.0, 0.84, 0.0) if cur < 5 else Color(0.3, 0.9, 0.55))
		cvbox.add_child(p_stats)

func close(game_state: GameState) -> void:
	if overlay == null:
		return
	if overlay.has_meta("backdrop"):
		var bd: Node = overlay.get_meta("backdrop")
		if is_instance_valid(bd):
			bd.queue_free()
	overlay.queue_free()
	overlay = null
	if _auto_paused:
		_auto_paused = false
		game_state.paused = false

func _close_via_resolver() -> void:
	if resolve_game_state.is_valid():
		close(resolve_game_state.call())
