extends Control
class_name MenuScreen

const _MAPS_DATA := preload("res://data/maps.gd")
const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BRAND := preload("res://ui/theme/BrandCopy.gd")
const _BACKDROP := preload("res://rendering/backdrop/TechBackdrop.gd")
const _UI_ICONS: Dictionary = {
	"shards": preload("res://assets/sprites/production/ui/shards.svg"),
	"cyber_deck": preload("res://assets/sprites/production/ui/cyber_deck.svg"),
}

@onready var _vbox: VBoxContainer   = $VBox
@onready var _title: TextureRect      = $VBox/Title
@onready var _subtitle: Label       = $VBox/SubTitle
@onready var _play_btn: Button      = $VBox/ActionCol/PlayBtn
@onready var _base_btn: Button      = $VBox/ActionCol/Row2/CyberDeckBtn
@onready var _settings_btn: Button  = $VBox/ActionCol/Row2/SettingsBtn
@onready var _bg: ColorRect         = $BG

# Gap 1 — ambient particles
var _particles: CPUParticles2D = null
# Gap 2 — glass panel behind VBox
var _glass: Panel = null
# Gap 4 — mute toggle
var _mute_btn: Button = null
# Gap 5 — title decorative rule
var _title_rule: ColorRect = null
# Gap 8 — play micro-context
var _play_context_lbl: Label = null
# Previous pass elements
var _rp_pill: PanelContainer = null
var _rp_pill_label: Label = null
var _version_lbl: Label = null
var _last_run_lbl: Label = null

# Tower showcase (sine float in _process)
var _tower_showcase: Array = []
var _tower_base_y: Array = []
var _time: float = 0.0

func _ready() -> void:
	_title.texture = load("res://assets/sprites/ui/title_logo.png")
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backdrop := _BACKDROP.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	# Decor mage — rendered above BG so it's actually visible
	if ResourceLoader.exists("res://assets/sprites/towers/mage.svg", "Texture2D"):
		_add_decor_icon(load("res://assets/sprites/towers/mage.svg"))

	# Background elements (low z in tree) — must be added before overlays
	_add_particles()        # Gap 1
	_add_tower_showcase()   # Gap 7 (tinted showcase)

	# VBox content additions
	_add_title_rule()       # Gap 5
	_add_last_run_label()   # Previous pass + Gap 6
	_add_play_context_label() # Gap 8

	# Overlay elements (appended last = render on top)
	_add_rp_pill()
	_add_mute_toggle()      # Gap 4
	_add_version_label()    # Gap 3 (dynamic)

	self.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

	_play_btn.pressed.connect(_on_play)
	_base_btn.pressed.connect(_on_cyberdeck)
	_settings_btn.pressed.connect(_on_settings)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_visuals()
	_apply_layout()
	_refresh_rp()

	FocusManager.setup_dpad_neighbors([_base_btn, _settings_btn], false)
	FocusManager.set_neighbor(_play_btn,     "bottom", _base_btn)
	FocusManager.set_neighbor(_base_btn,     "top",    _play_btn)
	FocusManager.set_neighbor(_settings_btn, "top",    _play_btn)
	# Allow dpad-left from Play to reach mute toggle
	if _mute_btn:
		FocusManager.set_neighbor(_play_btn, "left",  _mute_btn)
		FocusManager.set_neighbor(_mute_btn, "right", _play_btn)
	FocusManager.register_initial_focus(_play_btn)
	FocusManager.back_pressed.connect(_on_back_pressed)

func _process(delta: float) -> void:
	_time += delta
	for i in _tower_showcase.size():
		if i < _tower_base_y.size() and _tower_base_y[i] > 0.0:
			_tower_showcase[i].position.y = _tower_base_y[i] + sin(_time * 1.1 + i * 0.85) * 9.0

# ── Visuals ────────────────────────────────────────────────────────────────────

func _apply_visuals() -> void:
	if _bg:
		if _THEME.shader_effects_enabled():
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/shaders/LiquidGlass.gdshader")
			_bg.material = mat
		else:
			_bg.material = null

	_THEME.apply_label(_subtitle, "muted")
	_subtitle.text = _BRAND.FANTASY_SUBTITLE

	_THEME.apply_button(_play_btn, "primary")
	_THEME.apply_button(_base_btn, "secondary")
	_THEME.apply_button(_settings_btn, "secondary")
	_base_btn.icon = _UI_ICONS["cyber_deck"]

	# Gap 9 — Accessibility: tooltip_text and FOCUS_ALL on all interactive controls
	_play_btn.tooltip_text     = "Start a new network defense run"
	_base_btn.tooltip_text     = "Open %s — spend %s on permanent software upgrades" % [
		_BRAND.META_SCREEN, _BRAND.CURRENCY_META
	]
	_settings_btn.tooltip_text = "Gameplay settings"
	_play_btn.focus_mode     = Control.FOCUS_ALL
	_base_btn.focus_mode     = Control.FOCUS_ALL
	_settings_btn.focus_mode = Control.FOCUS_ALL

	# Title tilt loop
	_title.pivot_offset = _title.size * 0.5
	var tt := create_tween().set_loops()
	tt.tween_property(_title, "rotation", deg_to_rad(1.0),  4.0).set_trans(Tween.TRANS_SINE)
	tt.tween_property(_title, "rotation", deg_to_rad(-1.0), 4.0).set_trans(Tween.TRANS_SINE)

	# Play glint loop
	var pt := create_tween().set_loops()
	pt.tween_callback(func(): _THEME.trigger_glint(_play_btn)).set_delay(3.5)

	# Cyber-Deck glows when unspent Shards are available (not just on just_won)
	var profile: Dictionary = Progression.load_profile()
	if Progression.just_won() or profile.get("banked_rp", 0) > 0:
		_THEME.set_button_glow(_base_btn, true)
		var t := create_tween().set_loops()
		t.tween_callback(func(): _THEME.trigger_glint(_base_btn)).set_delay(2.0)

	_refresh_mute_btn()

# ── Layout ─────────────────────────────────────────────────────────────────────

func _apply_layout() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	var width: float  = minf(1100.0, maxf(600.0, viewport.x * 0.8))
	var height: float = clampf(viewport.y * 0.72, 400.0, 600.0)
	var x: float      = (viewport.x - width) * 0.5
	var top_min: float    = _LAYOUT.top_margin(viewport) + 32.0
	var bottom_min: float = _LAYOUT.bottom_margin(viewport) + 24.0
	var y: float = clampf(
			(viewport.y - height) * 0.44,
			top_min,
			maxf(top_min, viewport.y - height - bottom_min))
	_LAYOUT.apply_rect(_vbox, Rect2(Vector2(x, y), Vector2(width, height)))

	_vbox.add_theme_constant_override("separation", 32)
	_title.custom_minimum_size = Vector2(0.0, 110.0 if viewport.x >= 1200.0 else 84.0)
	_subtitle.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	_play_btn.custom_minimum_size     = Vector2(0.0, 64.0)
	_base_btn.custom_minimum_size     = Vector2(0.0, _LAYOUT.TOUCH_HEIGHT)
	_settings_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.TOUCH_HEIGHT)

	# Gap 2 — glass panel housing the content area
	_ensure_glass()
	var glass_rect := Rect2(
			Vector2(x - 20.0, y - 12.0),
			Vector2(width + 40.0, height + 24.0))
	_LAYOUT.apply_rect(_glass, glass_rect)
	if _glass.material is ShaderMaterial:
		_glass.material.set_shader_parameter("panel_size", glass_rect.size)
	for tr in _tower_showcase:
		move_child(tr, _vbox.get_index())

	var margin := _LAYOUT.edge_margin(viewport)
	var top    := _LAYOUT.top_margin(viewport)
	var bottom := _LAYOUT.bottom_margin(viewport)

	# Shards pill — top-right corner
	if _rp_pill:
		_rp_pill.position = Vector2(viewport.x - 118.0 - margin, top + 6.0)

	# Gap 4 — mute toggle — top-left corner, symmetric with Shards pill
	if _mute_btn:
		_mute_btn.position = Vector2(margin + 4.0, top + 6.0)

	# Gap 3 — version label — bottom-left corner
	if _version_lbl:
		_version_lbl.position = Vector2(margin + 4.0, viewport.y - bottom - 18.0)

	# Tower showcase — centered row just below VBox
	if not _tower_showcase.is_empty():
		var compact_showcase := OS.has_feature("android") and viewport.x > viewport.y
		var ts_sz  := 64.0 if compact_showcase else 80.0
		var ts_gap := 28.0 if compact_showcase else 36.0
		var count  := _tower_showcase.size()
		var total_w := count * ts_sz + (count - 1) * ts_gap
		var ts_x    := (viewport.x - total_w) * 0.5
		var desired_y := y + height + 14.0
		var max_y := viewport.y - bottom - ts_sz - (34.0 if compact_showcase else 24.0)
		var ts_y: float = minf(desired_y, max_y)
		_tower_base_y.resize(count)
		for i in count:
			_tower_showcase[i].size     = Vector2(ts_sz, ts_sz)
			_tower_showcase[i].position = Vector2(ts_x + i * (ts_sz + ts_gap), ts_y)
			_tower_base_y[i]            = ts_y

	# Gap 1 — center particles origin and expand emission rect to full screen
	if _particles:
		_particles.position              = Vector2(viewport.x * 0.5, viewport.y * 0.5)
		_particles.emission_rect_extents = Vector2(viewport.x * 0.5, viewport.y * 0.5)

# ── Gap 1: Ambient particles ───────────────────────────────────────────────────

func _add_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.emitting              = true
	_particles.amount                = 28
	_particles.lifetime              = 5.0
	_particles.one_shot              = false
	_particles.explosiveness         = 0.0
	_particles.randomness            = 1.0
	_particles.direction             = Vector2(0.0, -1.0)
	_particles.spread                = 55.0
	_particles.gravity               = Vector2.ZERO
	_particles.initial_velocity_min  = 12.0
	_particles.initial_velocity_max  = 32.0
	_particles.scale_amount_min      = 1.5
	_particles.scale_amount_max      = 3.5
	_particles.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(400.0, 300.0)  # Updated in _apply_layout
	# Fade CYAN → transparent over lifetime for a soft ambient look
	var grad := Gradient.new()
	grad.set_color(0, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.16))
	grad.set_color(1, Color(_THEME.CYAN.r, _THEME.CYAN.g, _THEME.CYAN.b, 0.0))
	_particles.color_ramp = grad
	add_child(_particles)
	# Place just after BG so particles drift behind all UI content
	move_child(_particles, _bg.get_index() + 1)

# ── Gap 2: Glass panel (instantiated on first layout call) ─────────────────────

func _ensure_glass() -> void:
	if _glass != null:
		return
	_glass = Panel.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glass)
	# Just before VBox so glass renders behind it but above backdrop/BG
	move_child(_glass, _vbox.get_index())
	_THEME.apply_glass_panel(_glass)

# ── Gap 3: Dynamic version (+ fallback to "v7.1.2") ───────────────────────────

func _add_version_label() -> void:
	_version_lbl = Label.new()
	_version_lbl.text = "v" + ProjectSettings.get_setting(
			"application/config/version", "7.1.2")
	_version_lbl.add_theme_color_override("font_color",
			Color(_THEME.MUTED.r, _THEME.MUTED.g, _THEME.MUTED.b, 0.45))
	_version_lbl.add_theme_font_size_override("font_size", 10)
	_version_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version_lbl)

# ── Gap 4: Mute toggle ────────────────────────────────────────────────────────

func _add_mute_toggle() -> void:
	_mute_btn = Button.new()
	_mute_btn.custom_minimum_size = Vector2(42.0, 34.0)
	_mute_btn.focus_mode          = Control.FOCUS_ALL
	_mute_btn.tooltip_text        = "Toggle audio mute"
	_mute_btn.add_theme_font_size_override("font_size", 18)
	_mute_btn.add_theme_color_override("font_color",
			Color(_THEME.MUTED.r, _THEME.MUTED.g, _THEME.MUTED.b, 0.72))
	_mute_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.92))
	# Icon-only style — transparent fill, subtle hover tint
	var sb_empty := StyleBoxEmpty.new()
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	sb_hover.set_corner_radius_all(8)
	_mute_btn.add_theme_stylebox_override("normal",   sb_empty)
	_mute_btn.add_theme_stylebox_override("pressed",  sb_empty)
	_mute_btn.add_theme_stylebox_override("focus",    sb_empty)
	_mute_btn.add_theme_stylebox_override("hover",    sb_hover)
	_mute_btn.add_theme_stylebox_override("disabled", sb_empty)
	_mute_btn.pressed.connect(_on_mute_toggle)
	add_child(_mute_btn)
	_refresh_mute_btn()

func _refresh_mute_btn() -> void:
	if _mute_btn == null:
		return
	var is_muted: bool = Progression.get_settings().get("audio_muted", false)
	_mute_btn.text = "🔇" if is_muted else "🔊"
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted)

func _on_mute_toggle() -> void:
	var is_muted: bool = Progression.get_settings().get("audio_muted", false)
	Progression.set_setting("audio_muted", not is_muted)
	_refresh_mute_btn()
	JuiceManager.configure_from_progression()

# ── Gap 5: Title decorative gold rule ─────────────────────────────────────────

func _add_title_rule() -> void:
	_title_rule = ColorRect.new()
	_title_rule.color                = Color(_THEME.GOLD.r, _THEME.GOLD.g, _THEME.GOLD.b, 0.42)
	_title_rule.custom_minimum_size  = Vector2(0.0, 1.0)
	_title_rule.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_title_rule)
	_vbox.move_child(_title_rule, _title.get_index() + 1)
	# Animated reveal so the rule "draws itself" on load
	_title_rule.modulate.a = 0.0
	var rt := _title_rule.create_tween()
	rt.tween_property(_title_rule, "modulate:a", 1.0, 0.9).set_delay(0.4).set_trans(Tween.TRANS_SINE)

# ── Gap 6 + previous-pass: Last-run label with wins/losses ────────────────────

func _add_last_run_label() -> void:
	_last_run_lbl = Label.new()
	_last_run_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_THEME.apply_label(_last_run_lbl, "muted")
	_last_run_lbl.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_last_run_lbl)
	# After Title(0), TitleRule(1), SubTitle(2) → insert at 3
	_vbox.move_child(_last_run_lbl, _subtitle.get_index() + 1)
	_update_last_run_label()

func _update_last_run_label() -> void:
	if _last_run_lbl == null:
		return
	var profile: Dictionary  = Progression.load_profile()
	var history: Array       = profile.get("run_history", [])

	var best_wave: int  = 0
	var last_wave: int  = 0
	var wins: int       = 0
	var losses: int     = 0
	for entry in history:
		var w: int = entry.get("waves", 0)
		best_wave = maxi(best_wave, w)
		if entry.get("won", false):
			wins += 1
		else:
			losses += 1
	if not history.is_empty():
		last_wave = history[-1].get("waves", 0)

	var parts: Array[String] = []
	if best_wave > 0:
		parts.append("Best: Wave %d" % best_wave)
	elif last_wave > 0:
		parts.append("Last: Wave %d" % last_wave)
	if wins > 0 or losses > 0:
		parts.append("%dW / %dL" % [wins, losses])

	_last_run_lbl.text    = "  ·  ".join(parts)
	_last_run_lbl.visible = not _last_run_lbl.text.is_empty()

# ── Gap 7 + previous-pass: Tower showcase with per-tower tints ────────────────

func _add_tower_showcase() -> void:
	if OS.has_feature("android") and not _THEME.shader_effects_enabled():
		return
	var paths := [
		"res://assets/sprites/towers/archer.svg",
		"res://assets/sprites/towers/cannon.svg",
		"res://assets/sprites/towers/frost.svg",
		"res://assets/sprites/towers/lightning.svg",
	]
	# Each tower fades in at its gameplay accent color — teaches the color vocabulary
	var tints := [
		Color(0.92, 0.84, 0.62, 0.82),  # archer    — warm parchment
		Color(0.88, 0.58, 0.32, 0.82),  # cannon    — burnt orange
		Color(0.52, 0.82, 1.00, 0.82),  # frost     — ice blue
		Color(0.90, 0.96, 0.38, 0.82),  # lightning — electric yellow
	]
	_tower_showcase.clear()
	_tower_base_y.clear()
	for i in paths.size():
		if not ResourceLoader.exists(paths[i], "Texture2D"):
			continue
		var tr := TextureRect.new()
		tr.texture      = load(paths[i])
		tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate     = Color(1.0, 1.0, 1.0, 0.0)

		if _THEME.shader_effects_enabled():
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/shaders/hologram.gdshader")
			mat.set_shader_parameter("holo_color", tints[i])
			mat.set_shader_parameter("scanline_speed", 1.4)
			mat.set_shader_parameter("scanline_scale", 110.0)
			mat.set_shader_parameter("flicker_amount", 0.05)
			tr.material = mat
		else:
			tr.material = null
			tr.modulate = Color(tints[i].r, tints[i].g, tints[i].b, 0.0)

		add_child(tr)
		# Keep towers behind VBox in draw order
		move_child(tr, _vbox.get_index())
		_tower_showcase.append(tr)
		_tower_base_y.append(0.0)
		# Staggered fade-in, arriving at full opacity
		var fade := tr.create_tween()
		fade.tween_property(tr, "modulate:a", tints[i].a, 0.5).set_delay(0.35 + i * 0.11)

# ── Gap 8: Play button micro-context ──────────────────────────────────────────

func _add_play_context_label() -> void:
	_play_context_lbl = Label.new()
	_play_context_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_context_lbl.add_theme_color_override("font_color",
			Color(_THEME.MUTED.r, _THEME.MUTED.g, _THEME.MUTED.b, 0.65))
	_play_context_lbl.add_theme_font_size_override("font_size", 11)
	_play_context_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Insert inside ActionCol between PlayBtn and Row2
	var action_col := _play_btn.get_parent()
	action_col.add_child(_play_context_lbl)
	action_col.move_child(_play_context_lbl, _play_btn.get_index() + 1)
	_update_play_context_label()

func _update_play_context_label() -> void:
	if _play_context_lbl == null:
		return
	var profile: Dictionary = Progression.load_profile()
	var history: Array      = profile.get("run_history", [])
	if history.is_empty():
		_play_context_lbl.text = "15 waves  ·  Normal difficulty"
		return
	var last: Dictionary = history[-1]
	# run_history stores map_id as a number (int in-memory, float after JSON
	# round-trip) — coerce before use instead of assigning into a String.
	var last_map_id: int = int(last.get("map_id", -1))
	var last_wave: int   = last.get("waves",  0)
	var map_name: String = ""
	if last_map_id >= 0 and last_map_id < _MAPS_DATA.MAPS.size():
		map_name = str(_MAPS_DATA.MAPS[last_map_id].get("name", ""))
	if map_name != "" and last_wave > 0:
		_play_context_lbl.text = "%s  ·  Last reached Wave %d" % [map_name, last_wave]
	elif map_name != "":
		_play_context_lbl.text = "Last map: %s" % map_name
	elif last_wave > 0:
		_play_context_lbl.text = "Last reached Wave %d" % last_wave
	else:
		_play_context_lbl.text = "15 waves  ·  Normal difficulty"

# ── Decor icon (mage ghost — positioned above BG so it's visible) ──────────────

func _add_decor_icon(texture: Texture2D) -> void:
	if texture == null:
		return
	var decor := TextureRect.new()
	decor.texture      = texture
	decor.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	decor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor.modulate.a   = 0.0
	decor.size         = Vector2(300, 300)
	decor.position     = Vector2(-20, -20)
	add_child(decor)
	# +1 over BG so the ghost actually renders (original move_child(1) hid it behind BG)
	move_child(decor, _bg.get_index() + 1)

	var decor_tween := create_tween().set_parallel(true).set_loops()
	decor_tween.tween_property(decor, "modulate:a",  0.35, 1.5).set_trans(Tween.TRANS_SINE)
	decor_tween.tween_property(decor, "position:x", 10.0, 4.0).from(-20.0).set_trans(Tween.TRANS_SINE)

	var float_tween := create_tween().set_loops()
	float_tween.tween_property(decor, "position:y",  10.0, 3.0).from(-20.0).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(decor, "position:y", -20.0, 3.0).set_trans(Tween.TRANS_SINE)

# ── Shards pill ────────────────────────────────────────────────────────────────

func _add_rp_pill() -> void:
	_rp_pill = PanelContainer.new()
	_rp_pill.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_rp_pill.custom_minimum_size = Vector2(100.0, 30.0)
	add_child(_rp_pill)

	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.040, 0.065, 0.130, 0.88)
	sb.border_color = Color(_THEME.GOLD.r, _THEME.GOLD.g, _THEME.GOLD.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.content_margin_left   = 10.0
	sb.content_margin_right  = 10.0
	sb.content_margin_top    = 4.0
	sb.content_margin_bottom = 4.0
	_rp_pill.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.name = "ShardRow"
	hbox.add_theme_constant_override("separation", 5)
	_rp_pill.add_child(hbox)

	var shard_icon := TextureRect.new()
	shard_icon.name = "ShardsIcon"
	shard_icon.texture = _UI_ICONS["shards"]
	shard_icon.custom_minimum_size = Vector2(22.0, 22.0)
	shard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shard_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(shard_icon)

	var icon_lbl := Label.new()
	icon_lbl.text = _BRAND.CURRENCY_META
	icon_lbl.add_theme_color_override("font_color", _THEME.GOLD)
	icon_lbl.add_theme_font_size_override("font_size", 10)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	_rp_pill_label = Label.new()
	_rp_pill_label.text = "0"
	_rp_pill_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70, 1.0))
	_rp_pill_label.add_theme_font_size_override("font_size", 14)
	_rp_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_rp_pill_label)

func get_ui_asset_runtime_snapshot() -> Dictionary:
	# Runtime certification reads the visible menu controls and assigned texture.
	return {
		"ui.shards": {"path": "res://assets/sprites/production/ui/shards.svg", "loaded": _UI_ICONS["shards"] != null, "rendered": _rp_pill != null and _rp_pill.get_node_or_null("ShardRow/ShardsIcon") != null and _rp_pill.get_node("ShardRow/ShardsIcon").is_visible_in_tree()},
		"ui.cyber_deck": {"path": "res://assets/sprites/production/ui/cyber_deck.svg", "loaded": _UI_ICONS["cyber_deck"] != null, "rendered": _base_btn != null and _base_btn.visible and _base_btn.icon == _UI_ICONS["cyber_deck"]},
	}

# ── Navigation ─────────────────────────────────────────────────────────────────

func _on_play() -> void:
	_fade_to("res://scenes/MapSelectScreen.tscn")

func _on_cyberdeck() -> void:
	_fade_to("res://scenes/CyberDeckScreen.tscn")

func _on_settings() -> void:
	_fade_to("res://scenes/SettingsScreen.tscn")

func _on_back_pressed() -> void:
	print("Back pressed on main menu")

func _refresh_rp() -> void:
	var profile: Dictionary = Progression.load_profile()
	if _rp_pill_label:
		_rp_pill_label.text = str(profile.get("banked_rp", 0))

func _fade_to(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			printerr("Failed to change scene to %s: %d" % [path, err])
			self.modulate.a = 1.0
	)
