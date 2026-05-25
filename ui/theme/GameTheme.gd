class_name TDGameTheme

const BG: Color = Color(0.059, 0.102, 0.180, 1.0)          # #0F1A2E  Deep Navy
const PANEL: Color = Color(0.080, 0.122, 0.212, 0.88)      # #14203A  Frosted Navy Glass
const PANEL_ALT: Color = Color(0.098, 0.145, 0.245, 0.93)  # #182540  Deep Navy Panel
const PANEL_SOFT: Color = Color(0.062, 0.100, 0.182, 0.72) # #10192E  Ghost Navy
const TEXT: Color = Color(0.930, 0.942, 0.968, 1.0)        # #EDF0F7  Soft Blue-White
const MUTED: Color = Color(0.490, 0.565, 0.682, 1.0)       # #7D90AE  Blue-Steel Gray
const DISABLED: Color = Color(0.165, 0.212, 0.318, 1.0)    # #2A3651  Navy Void
const GOLD: Color = Color(0.910, 0.627, 0.125, 1.0)        # #E8A020  Amber Gold
const GOLD_DARK: Color = Color(0.255, 0.165, 0.024, 1.0)   # #412A06  Deep Bronze
const CYAN: Color = Color(0.290, 0.565, 0.851, 1.0)        # #4A90D9  Steel Blue
const CYAN_DARK: Color = Color(0.085, 0.210, 0.392, 1.0)   # #163564  Deep Steel
const VIOLET: Color = Color(0.66, 0.33, 0.97, 1.0)         # Hyper Violet (milestone/special only)
const GREEN: Color = Color(0.13, 0.77, 0.37, 1.0)          # Neo Green
const RED: Color = Color(0.902, 0.224, 0.275, 1.0)         # #E63946  Soft Crimson
const ORANGE: Color = Color(1.0, 0.36, 0.0, 1.0)           # Alert Orange

static func shader_effects_enabled() -> bool:
	var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	return not (OS.has_feature("android") and renderer == "gl_compatibility")

static func style_box(bg: Color, border: Color, border_width: int = 1, radius: int = 6, expand: int = 0, shadow_sz: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12.0 + expand
	sb.content_margin_top = 8.0 + expand
	sb.content_margin_right = 12.0 + expand
	sb.content_margin_bottom = 8.0 + expand
	if shadow_sz > 0:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = shadow_sz
		sb.shadow_offset = Vector2(0, 3)
	return sb

static func apply_panel(panel: Control, kind: String = "default") -> void:
	if panel == null:
		return
	var border: Color = CYAN.lerp(Color.WHITE, 0.12)
	var bg: Color = PANEL
	var shadow: int = 8
	if kind == "card" and shader_effects_enabled():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/chamfer_glass.gdshader")
		mat.set_shader_parameter("bg_color", PANEL_ALT)
		mat.set_shader_parameter("border_color", CYAN.lerp(VIOLET, 0.32))
		mat.set_shader_parameter("border_glow_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.12))
		mat.set_shader_parameter("border_width", 1.5)
		mat.set_shader_parameter("chamfer_size", 10.0)
		mat.set_shader_parameter("glow_size", 5.0)
		mat.set_shader_parameter("panel_size", panel.size)
		panel.material = mat
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

		if not panel.is_connected("resized", Callable(_on_card_resized.bind(panel))):
			panel.resized.connect(_on_card_resized.bind(panel))
		return
	elif kind == "modal":
		bg = Color(0.03, 0.05, 0.11, 0.98)
		border = GOLD
		shadow = 24
	elif kind == "premium":
		bg = PANEL_ALT
		border = VIOLET
		shadow = 16
	elif kind == "danger":
		border = RED
	panel.add_theme_stylebox_override("panel", style_box(bg, border, 1, 12, 2, shadow))

static func apply_glass_panel(panel: Control) -> void:
	if panel == null:
		return
	if not shader_effects_enabled():
		panel.material = null
		panel.add_theme_stylebox_override("panel",
				style_box(Color(0.051, 0.082, 0.149, 0.88), Color(0.290, 0.565, 0.851, 0.76), 2, 12, 2, 10))
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/chamfer_glass.gdshader")
	mat.set_shader_parameter("bg_color", Color(0.051, 0.082, 0.149, 0.72))
	mat.set_shader_parameter("border_color", Color(0.290, 0.565, 0.851, 0.76))
	mat.set_shader_parameter("border_glow_color", Color(0.290, 0.565, 0.851, 0.35))
	mat.set_shader_parameter("border_width", 2.0)
	mat.set_shader_parameter("chamfer_size", 20.0)
	mat.set_shader_parameter("glow_size", 14.0)
	mat.set_shader_parameter("panel_size", panel.size)
	panel.material = mat
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

static func apply_button(btn: Button, kind: String = "secondary") -> void:
	if btn == null:
		return
	if not btn.has_meta("td_theme_fx"):
		btn.set_meta("td_theme_fx", true)
		btn.button_down.connect(_on_button_down.bind(btn))
		btn.button_up.connect(_on_button_up.bind(btn))
		btn.mouse_exited.connect(_on_button_up.bind(btn))
		btn.focus_entered.connect(_on_focus_entered.bind(btn))
		btn.focus_exited.connect(_on_focus_exited.bind(btn))
		btn.pressed.connect(_on_button_pressed.bind(btn))

	if shader_effects_enabled():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/LightSweep.gdshader")
		mat.set_shader_parameter("sweep_pos", -1.0)
		mat.set_shader_parameter("sweep_width", 0.14)
		if kind == "primary":
			mat.set_shader_parameter("sweep_color", Color(1.0, 0.94, 0.74, 0.44)) # warm gold glint
		else:
			mat.set_shader_parameter("sweep_color", Color(0.5, 0.8, 1.0, 0.38)) # cyan ice glint
		btn.material = mat
	else:
		btn.material = null

	# Default: secondary — visible navy fill, steel-blue border, clear hover lift
	var base:   Color = Color(0.110, 0.178, 0.318, 1.0)
	var border: Color = CYAN
	var hover:  Color = Color(0.158, 0.238, 0.400, 1.0)
	var press:  Color = Color(0.082, 0.148, 0.278, 1.0)
	var font:   Color = Color(0.880, 0.925, 1.000, 1.0)   # slight blue-white tint
	var bw:     int   = 2
	var radius: int   = 12
	var shadow: int   = 8
	var outline: int  = 1

	if kind == "primary":
		# Amber-dark fill — reads as a solid premium CTA, not just an outline
		base   = Color(0.420, 0.280, 0.050, 1.0)
		border = GOLD
		hover  = Color(0.540, 0.360, 0.070, 1.0)
		press  = Color(0.275, 0.178, 0.032, 1.0)
		font   = Color(1.000, 0.940, 0.740, 1.0)   # warm cream
		radius = 14
		shadow = 14
		outline = 2
	elif kind == "danger":
		base   = Color(0.360, 0.080, 0.100, 1.0)
		border = RED
		hover  = Color(0.460, 0.105, 0.118, 1.0)
		press  = Color(0.220, 0.048, 0.065, 1.0)
		font   = Color(1.000, 0.878, 0.878, 1.0)
		shadow = 6
	elif kind == "tab":
		base   = Color(0.082, 0.138, 0.238, 0.97)
		border = Color(0.248, 0.380, 0.575, 1.0)
		hover  = Color(0.118, 0.188, 0.318, 1.0)
		press  = CYAN_DARK
		font   = TEXT
		bw     = 1
		radius = 10
		shadow = 2
		outline = 0
	elif kind == "shop":
		base   = Color(0.092, 0.142, 0.258, 0.98)
		border = CYAN.darkened(0.15)
		hover  = Color(0.138, 0.198, 0.338, 1.0)
		press  = Color(0.078, 0.182, 0.380, 1.0)
		shadow = 6

	btn.add_theme_stylebox_override("normal",   style_box(base,               border,                 bw,     radius, 0, shadow))
	btn.add_theme_stylebox_override("hover",    style_box(hover,              border.lightened(0.22), bw,     radius, 0, shadow + 6))
	btn.add_theme_stylebox_override("pressed",  style_box(press,              border.lightened(0.38), bw + 1, radius, 0, 2))
	btn.add_theme_stylebox_override("focus",    style_box(Color(0, 0, 0, 0), border.lightened(0.58), 2,      radius, 0, 0))
	btn.add_theme_stylebox_override("disabled", style_box(Color(0.050, 0.072, 0.120, 0.85), Color(0.140, 0.198, 0.298, 1.0), 1, radius))
	btn.add_theme_color_override("font_color",          font)
	btn.add_theme_color_override("font_hover_color",    Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color",  Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", DISABLED)
	btn.add_theme_color_override("font_outline_color",  Color(0.0, 0.0, 0.0, 0.52))
	btn.add_theme_constant_override("outline_size", outline)

static func _on_button_down(btn: Button) -> void:
	if btn == null or btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(0.985, 0.985), 0.045)

static func _on_button_up(btn: Button) -> void:
	if btn == null:
		return
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.075)

static func _on_focus_entered(btn: Button) -> void:
	if btn == null: return
	btn.pivot_offset = btn.size * 0.5
	var tween := btn.create_tween().set_loops()
	tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	btn.set_meta("focus_tween", tween)

	# Light sweep animation
	var mat := btn.material as ShaderMaterial
	if mat and mat.shader:
		var stween := btn.create_tween().set_loops()
		var tweener := stween.tween_property(mat, "shader_parameter/sweep_pos", 1.5, 1.5)
		if tweener:
			tweener.from(-0.5)
		stween.tween_interval(2.0)
		btn.set_meta("sweep_tween", stween)

static func _on_focus_exited(btn: Button) -> void:
	if btn == null: return
	if btn.has_meta("focus_tween"):
		var tween: Tween = btn.get_meta("focus_tween")
		if tween: tween.kill()
	if btn.has_meta("sweep_tween"):
		var stween: Tween = btn.get_meta("sweep_tween")
		if stween: stween.kill()
	var mat := btn.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("sweep_pos", -1.0)
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)

static func _on_button_pressed(btn: Button) -> void:
	if btn == null: return
	# Trigger a fast sweep on click
	var mat := btn.material as ShaderMaterial
	if mat and mat.shader:
		var ctween := btn.create_tween()
		var tweener := ctween.tween_property(mat, "shader_parameter/sweep_pos", 2.0, 0.3)
		if tweener:
			tweener.from(-1.0)

	# Spawn juice burst at button center
	var juice = btn.get_node_or_null("/root/JuiceManager")
	if juice:
		juice.spawn_burst(btn.global_position + btn.size * 0.5, CYAN)

static func apply_label(label: Label, kind: String = "body") -> void:
	if label == null:
		return
	if kind == "title":
		label.add_theme_color_override("font_color", GOLD)
		label.add_theme_font_size_override("font_size", 56)
		label.add_theme_color_override("font_shadow_color",   Color(0.0, 0.0, 0.0, 0.55))
		label.add_theme_constant_override("shadow_offset_x",  0)
		label.add_theme_constant_override("shadow_offset_y",  3)
		label.add_theme_constant_override("shadow_outline_size", 4)
	elif kind == "heading":
		label.add_theme_color_override("font_color", GOLD)
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_shadow_color",   Color(0.0, 0.0, 0.0, 0.45))
		label.add_theme_constant_override("shadow_offset_x",  0)
		label.add_theme_constant_override("shadow_offset_y",  2)
		label.add_theme_constant_override("shadow_outline_size", 2)
	elif kind == "muted":
		label.add_theme_color_override("font_color", MUTED)
	elif kind == "currency":
		label.add_theme_color_override("font_color", GOLD)
	else:
		label.add_theme_color_override("font_color", TEXT)

static func apply_badge(label: Label, kind: String) -> void:
	if label == null:
		return
	var bg: Color = Color(0.075, 0.110, 0.200, 1.0)
	var border: Color = MUTED
	var font: Color = TEXT
	var shadow: int = 2
	if kind == "locked":
		border = DISABLED
		font = DISABLED.lightened(0.25)
		shadow = 0
	elif kind == "owned":
		border = GREEN
		font = GREEN
		shadow = 4
	elif kind == "active":
		border = VIOLET
		font = VIOLET.lightened(0.2)
		shadow = 6
	elif kind == "cost":
		border = GOLD
		font = GOLD
		bg = GOLD_DARK
		shadow = 4
	elif kind == "danger":
		border = RED
		font = RED.lightened(0.15)
		shadow = 4
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", font)
	label.add_theme_stylebox_override("normal", style_box(bg, border, 1, 6, 0, shadow))

static func set_button_glow(btn: Button, is_glowing: bool) -> void:
	if btn == null:
		return
	var border_color := CYAN if is_glowing else CYAN.darkened(0.6)
	var sb := btn.get_theme_stylebox("normal").duplicate()
	if sb is StyleBoxFlat:
		sb.border_color = border_color
		if is_glowing:
			sb.set_border_width_all(2)
			sb.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.15)
			sb.shadow_size = 8
		else:
			sb.set_border_width_all(1)
			sb.shadow_size = 0
		btn.add_theme_stylebox_override("normal", sb)

static func trigger_glint(btn: Button) -> void:
	if btn == null or not btn.material is ShaderMaterial:
		return
	var tween := btn.create_tween()
	tween.tween_property(btn.material, "shader_parameter/sweep_pos", 1.8, 0.5).from(-0.8)

static func style_tree(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			apply_button(child)
		elif child is PanelContainer:
			apply_panel(child)
		elif child is Label:
			apply_label(child)
		style_tree(child)

static func _on_card_resized(panel: Control) -> void:
	if panel and panel.material is ShaderMaterial:
		panel.material.set_shader_parameter("panel_size", panel.size)
