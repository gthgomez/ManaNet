extends Node2D
class_name GameRenderer

# Phase 3 renderer — port of draw_kivy.py (2224 lines) to Godot 4.6.
#
# Performance strategy vs Kivy:
#   Kivy: ~930 individual canvas instructions per frame (no batching)
#   Godot: MultiMeshInstance2D per entity type → ~30-40 draw calls per frame
#
# Draw order (matches draw_kivy.py exactly):
#   1. Background (map texture or starfield)
#   2. Path terrain (baked to SubViewport texture at load — not per-frame)
#   3. Selected tower range circle
#   4. Effects (flash, ring, explosion, lightning, sniper, ice, damage numbers, etc.)
#   5. Enemies   (MultiMeshInstance2D, one per enemy type = 6 draw calls)
#   6. Towers    (MultiMeshInstance2D, one per tower type = 6 draw calls)
#   7. Projectiles (MultiMeshInstance2D = 1 draw call)
#   8. Particles (custom _draw loop, ~200 max)
#   9. HUD       (Control nodes in GameScreen scene — not drawn here)

const _MAPS := preload("res://data/maps.gd")
const _TT   := preload("res://data/tower_types.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _TOWER_FIDELITY_SHADER := preload("res://assets/shaders/TowerFidelity.gdshader")
const _TOWER_CUTOUT_SHADER := preload("res://assets/shaders/tower_cutout.gdshader")
const TOWER_SPRITE_PATHS: Dictionary = {
	"archer": "res://assets/sprites/towers/archer.png",
	"mage": "res://assets/sprites/towers/mage.png",
	"cannon": "res://assets/sprites/towers/cannon.png",
	"sniper": "res://assets/sprites/towers/sniper.png",
	"frost": "res://assets/sprites/towers/frost.png",
	"lightning": "res://assets/sprites/towers/lightning.png",
}
const ENEMY_SPRITE_PATHS: Dictionary = {
	"Enemy": "res://assets/sprites/enemies/grunt_soldier.jpg",
	"FastScout": "res://assets/sprites/enemies/fast_scout.jpg",
	"ArmoredTank": "res://assets/sprites/enemies/armored_tank.jpg",
	"FlyingDrone": "res://assets/sprites/enemies/flying_drone.jpg",
	"SwarmMinion": "res://assets/sprites/enemies/swarm_minion.jpg",
	"HeavyBrute": "res://assets/sprites/enemies/heavy_brute.png",
}
const MAP_BG_PATHS: Dictionary = {
	0: "res://assets/sprites/maps/map_bg_s_curve.jpg",
	1: "res://assets/sprites/maps/map_bg_gauntlet.jpg",
	2: "res://assets/sprites/maps/map_bg_spiral.jpg",
}

# References set by GameScreen after scene is ready
var game_state: GameState = null
var view_state: Object = null
var _overlay_node: Node2D = null

# --- Path bake ---
var _path_viewport: SubViewport = null
var _path_texture: ViewportTexture = null
var _path_baked: bool = false
var _path_bake_size: Vector2 = Vector2.ZERO

# --- MultiMesh pools ---
# Enemies: 6 types, pre-allocated to MAX_ENEMIES instances each
const MAX_ENEMIES: int = 120
const MAX_TOWERS: int = 60
const MAX_PROJECTILES: int = 100

# One MultiMeshInstance2D per enemy type (index matches ENEMY_TYPE_ORDER)
const ENEMY_TYPE_ORDER: Array = ["Enemy","FastScout","ArmoredTank","FlyingDrone","SwarmMinion","HeavyBrute"]
var _enemy_mmis: Array = []   # Array[MultiMeshInstance2D]

# One MultiMeshInstance2D per tower type
const TOWER_TYPE_ORDER: Array = ["archer","mage","cannon","sniper","frost","lightning"]
var _tower_mmis: Array = []   # Array[MultiMeshInstance2D]

# Projectile pool — single MultiMeshInstance2D (all projectiles same quad)
var _proj_mmi: MultiMeshInstance2D = null

# Enemy colours per type (used for tinting the quad mesh)
const ENEMY_COLORS: Dictionary = {
	"Enemy":       Color(0.82, 0.20, 0.20),
	"FastScout":   Color(0.96, 0.55, 0.10),
	"ArmoredTank": Color(0.45, 0.45, 0.55),
	"FlyingDrone": Color(0.20, 0.75, 0.90),
	"SwarmMinion": Color(0.70, 0.85, 0.20),
	"HeavyBrute":  Color(0.60, 0.25, 0.70),
}

# Cache for baked path draw — rebuild when viewport size changes
var _last_viewport_size: Vector2 = Vector2.ZERO

# Starfield (pre-generated positions, drawn as circles in _draw)
var _stars: Array = []   # Array[Vector3] — x,y,radius
var _tower_cutout_material: ShaderMaterial = null
var _map_bg_textures: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	z_index = 0
	if _THEME.shader_effects_enabled():
		_tower_cutout_material = ShaderMaterial.new()
		_tower_cutout_material.shader = _TOWER_CUTOUT_SHADER
	_load_map_backgrounds()
	_generate_starfield()
	_build_multimesh_pools()
	_build_path_viewport()

func _load_map_backgrounds() -> void:
	_map_bg_textures.clear()
	for map_id in MAP_BG_PATHS:
		var tex: Texture2D = load(MAP_BG_PATHS[map_id])
		if tex:
			_map_bg_textures[map_id] = tex

func _generate_starfield() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDEADBEEF   # deterministic — same field every run
	for _i in range(80):
		_stars.append(Vector3(
			rng.randf_range(0, _MAPS.WIDTH),
			rng.randf_range(0, _MAPS.HEIGHT),
			rng.randf_range(1.0, 2.5)
		))

# ---------------------------------------------------------------------------
# MultiMesh pool construction
# ---------------------------------------------------------------------------

func _build_multimesh_pools() -> void:
	# Enemy MMIs
	_enemy_mmis.clear()
	var use_shaders := _THEME.shader_effects_enabled()
	var entity_mat: ShaderMaterial = null
	if use_shaders:
		entity_mat = ShaderMaterial.new()
		entity_mat.shader = preload("res://assets/shaders/EntityFidelity.gdshader")

	for etype in ENEMY_TYPE_ORDER:
		var mmi := _make_mmi(MAX_ENEMIES, _enemy_color(etype), true)
		var tex: Texture2D = load(ENEMY_SPRITE_PATHS[etype])
		if tex:
			mmi.texture = tex
			if use_shaders and entity_mat:
				var mat := entity_mat.duplicate()
				mat.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 0.35))
				mat.set_shader_parameter("outline_width", 1.8)
				mmi.material = mat
		add_child(mmi)
		_enemy_mmis.append(mmi)

	# Tower MMIs
	_tower_mmis.clear()
	for ttype in TOWER_TYPE_ORDER:
		var col: Color = _TT.TOWER_TYPES[ttype]["color"]
		var mmi := _make_mmi(MAX_TOWERS, col)
		var tex: Texture2D = load(TOWER_SPRITE_PATHS[ttype])
		if tex:
			mmi.texture = tex
			if use_shaders:
				var mat := ShaderMaterial.new()
				mat.shader = _TOWER_FIDELITY_SHADER

				var glow_col := _THEME.CYAN
				match ttype:
					"mage", "lightning": glow_col = _THEME.VIOLET
					"cannon": glow_col = _THEME.ORANGE
					"sniper": glow_col = _THEME.GOLD

				mat.set_shader_parameter("glow_color", glow_col)
				mat.set_shader_parameter("glow_intensity", 3.5)
				mmi.material = mat
		add_child(mmi)
		_tower_mmis.append(mmi)

	# Projectile MMI
	_proj_mmi = _make_mmi(MAX_PROJECTILES, Color(1.0, 1.0, 0.8))
	add_child(_proj_mmi)

	# Overlay for Health Bars/Badges (must be last in tree to be on top)
	var overlay := _OverlayDrawNode.new()
	overlay.renderer_ref = self
	overlay.name = "Overlay"
	add_child(overlay)
	_overlay_node = overlay

func _make_mmi(max_count: int, base_color: Color, use_custom_data: bool = false) -> MultiMeshInstance2D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = use_custom_data
	mm.instance_count = max_count
	mm.visible_instance_count = 0

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)   # scaled per instance via Transform2D
	mm.mesh = quad

	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	return mmi

func _enemy_color(etype: String) -> Color:
	return ENEMY_COLORS.get(etype, Color.WHITE)

# ---------------------------------------------------------------------------
# Path baking into SubViewport
# ---------------------------------------------------------------------------

func _build_path_viewport() -> void:
	_path_viewport = SubViewport.new()
	_path_viewport.size = Vector2i(_MAPS.WIDTH, _MAPS.HEIGHT)
	_path_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_path_viewport.transparent_bg = true

	var path_draw := _PathDrawNode.new()
	path_draw.maps_ref = _MAPS
	_path_viewport.add_child(path_draw)
	add_child(_path_viewport)

	_path_texture = _path_viewport.get_texture()
	_path_baked = true
	_path_bake_size = Vector2(_MAPS.WIDTH, _MAPS.HEIGHT)

# ---------------------------------------------------------------------------
# Per-frame update — called by GameScreen
# ---------------------------------------------------------------------------

func render_frame(now_ms: int) -> void:
	_consume_simulation_events()
	queue_redraw()
	_update_multimeshes(now_ms)

func _consume_simulation_events() -> void:
	if game_state == null or view_state == null:
		return
	for event in game_state.drain_events():
		var event_type: String = str(event.get("type", ""))
		if event_type == "screen_shake":
			view_state.start_screen_shake(
				int(event.get("ms", Time.get_ticks_msec())),
				float(event.get("intensity", 6.0)),
				int(event.get("duration_ms", 380))
			)

# ---------------------------------------------------------------------------
# MultiMesh updates (enemies, towers, projectiles)
# ---------------------------------------------------------------------------

func _update_multimeshes(now_ms: int) -> void:
	if game_state == null:
		return

	_update_enemy_meshes(now_ms)
	_update_tower_meshes(now_ms)
	_update_projectile_meshes()

func _update_enemy_meshes(now_ms: int) -> void:
	# Bucket enemies by type index
	var buckets: Array = []
	for _i in ENEMY_TYPE_ORDER.size():
		buckets.append([])
	for enemy in game_state.enemies:
		var idx: int = ENEMY_TYPE_ORDER.find(enemy.type_name)
		if idx < 0:
			idx = 0
		buckets[idx].append(enemy)

	for i in ENEMY_TYPE_ORDER.size():
		var mmi: MultiMeshInstance2D = _enemy_mmis[i]
		var bucket: Array = buckets[i]
		var count: int = mini(bucket.size(), MAX_ENEMIES)
		mmi.multimesh.visible_instance_count = count
		for j in range(count):
			var enemy: Enemy = bucket[j]
			var shake: Vector2 = view_state.get_screen_shake_offset(now_ms) if view_state else Vector2.ZERO
			var draw_pos: Vector2 = enemy.pos + shake
			var sz: float = float(enemy.radius) * 2.35
			var scale_x: float = sz if enemy.facing_right else -sz
			var xform := Transform2D(0.0, Vector2(scale_x, sz), 0.0, draw_pos)
			mmi.multimesh.set_instance_transform_2d(j, xform)
			# Flash: set custom data x to 1.0 if flashing
			var flash: float = 1.0 if now_ms < enemy.flash_until else 0.0
			mmi.multimesh.set_instance_custom_data(j, Color(flash, 0, 0, 0))

			# Tint: chilled = blue tint, frozen = white
			var col: Color = _enemy_base_color(enemy, now_ms)
			mmi.multimesh.set_instance_color(j, col)

func _enemy_base_color(enemy: Enemy, now_ms: int) -> Color:
	var base: Color = Color.WHITE
	# Boss stealth: dim until revealed (Swarm Carrier / stealthed types)
	if enemy.stealthed and now_ms >= enemy.revealed_until:
		return Color(0.45, 0.55, 0.70, 0.55)
	if now_ms < enemy.frozen_until:
		return base.lerp(Color.WHITE, 0.65)
	if now_ms < enemy.chilled_until:
		return base.lerp(Color(0.5, 0.8, 1.0), 0.45)
	if now_ms < enemy.revealed_until:
		return base.lerp(Color(1.0, 1.0, 0.4), 0.35)
	# Boss regenerator: soft green pulse while healing below max HP
	if enemy is Enemy.BossRegenerator and enemy.health > 0 and enemy.health < enemy.max_health:
		var pulse: float = 0.35 + 0.25 * (0.5 + 0.5 * sin(float(now_ms) * 0.008))
		return base.lerp(Color(0.35, 1.0, 0.55), pulse)
	return base

func _update_tower_meshes(now_ms: int) -> void:
	# Bucket towers by type
	var buckets: Array = []
	for _i in TOWER_TYPE_ORDER.size():
		buckets.append([])
	for tower in game_state.towers:
		var idx: int = TOWER_TYPE_ORDER.find(tower.ttype)
		if idx >= 0:
			buckets[idx].append(tower)

	for i in TOWER_TYPE_ORDER.size():
		var mmi: MultiMeshInstance2D = _tower_mmis[i]
		var bucket: Array = buckets[i]
		var count: int = mini(bucket.size(), MAX_TOWERS)
		mmi.multimesh.visible_instance_count = count
		for j in range(count):
			var tower: Tower = bucket[j]
			var shake: Vector2 = view_state.get_screen_shake_offset(now_ms) if view_state else Vector2.ZERO
			var draw_pos: Vector2 = tower.pos + shake
			var sz: float = float(tower.radius) * 2.2
			var xform := Transform2D(0.0, Vector2(sz, sz), 0.0, draw_pos)
			mmi.multimesh.set_instance_transform_2d(j, xform)
			# Flash: brighten during flash_until, gold during burst_until, white during muzzle flash
			var col: Color
			if view_state and view_state.selected_tower_id == tower.id:
				col = Color.WHITE.lerp(tower.color, 0.25)
			elif now_ms < tower.muzzle_flash_until:
				col = Color(2.5, 2.5, 2.5) # Over-bright white fire
			elif now_ms < tower.burst_until:
				col = Color.WHITE.lerp(Color(1.0, 0.9, 0.2), 0.45)
			elif now_ms < tower.flash_until:
				col = Color(1.25, 1.25, 1.25)
			elif tower.variant_tint.a > 0.0:
				col = Color.WHITE.lerp(tower.variant_tint, 0.4)
			else:
				var path_tint := tower.get_dominant_path_tint()
				if path_tint.a > 0.0:
					col = Color.WHITE.lerp(path_tint, 0.45)
				else:
					col = Color.WHITE
			mmi.multimesh.set_instance_color(j, col)

func _update_projectile_meshes() -> void:
	var count: int = mini(game_state.projectiles.size(), MAX_PROJECTILES)
	_proj_mmi.multimesh.visible_instance_count = count
	for i in range(count):
		var proj: Projectile = game_state.projectiles[i]
		var sz: float = float(proj.radius) * 2.0
		var xform := Transform2D(0.0, Vector2(sz, sz), 0.0, proj.pos)
		_proj_mmi.multimesh.set_instance_transform_2d(i, xform)
		var col: Color = proj.tower.color if proj.tower else Color.YELLOW
		_proj_mmi.multimesh.set_instance_color(i, col)

func _draw_projectile_trails(shake: Vector2) -> void:
	if game_state == null:
		return
	for proj in game_state.projectiles:
		var col: Color = proj.tower.color if proj.tower else Color.YELLOW
		col.a = 0.52
		draw_line(proj.prev_pos + shake, proj.pos + shake, col, 3.25)

# ---------------------------------------------------------------------------
# _draw  — background, path, effects, particles (not batched via MultiMesh)
# ---------------------------------------------------------------------------

func _draw() -> void:
	if game_state == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	var shake: Vector2 = view_state.get_screen_shake_offset(now_ms) if view_state else Vector2.ZERO

	_draw_background(shake)
	_draw_path(shake)
	_draw_range_circle(now_ms, shake)
	_draw_projectile_trails(shake)
	_draw_portals(now_ms, shake)
	_draw_effects(now_ms, shake)
	# Enemies and towers are drawn by MultiMeshInstance2D nodes (no _draw needed)
	_draw_particles(now_ms, shake)
	if view_state and view_state.placement_active and view_state.placement_tower_type != "":
		draw_placement_ghost(
			view_state.placement_ghost_pos,
			view_state.placement_tower_type,
			view_state.placement_ghost_valid,
			now_ms
		)
	if view_state and view_state.has_pending_placement():
		draw_placement_ghost(
			view_state.pending_placement_pos,
			view_state.pending_placement_type,
			view_state.pending_placement_valid,
			now_ms
		)

	# Health bars and badges moved to _on_overlay_draw to stay on top of sprites
	_overlay_node.queue_redraw()

# --- 1. Background ---

func _draw_background(shake: Vector2) -> void:
	var map_id: int = game_state.map_id if game_state else 0
	var bg: Texture2D = _map_bg_textures.get(map_id, null)
	if bg:
		draw_texture_rect(bg, Rect2(shake, Vector2(_MAPS.WIDTH, _MAPS.HEIGHT)), false)
		draw_rect(Rect2(shake, Vector2(_MAPS.WIDTH, _MAPS.HEIGHT)), Color(0.02, 0.03, 0.06, 0.28))
		return

	draw_rect(Rect2(shake, Vector2(_MAPS.WIDTH, _MAPS.HEIGHT)), Color(0.04, 0.04, 0.08))
	var drift := Vector2(sin(float(Time.get_ticks_msec()) * 0.0001) * 15.0, cos(float(Time.get_ticks_msec()) * 0.00012) * 10.0)
	for star in _stars:
		# Parallax effect: larger (closer) stars move more
		var star_parallax: float = star.z * 0.5
		var spos: Vector2 = Vector2(star.x, star.y) + shake * 0.15 + drift * star_parallax
		draw_circle(spos, star.z, Color(0.9, 0.9, 1.0, 0.55))

# --- 2. Path terrain ---

func _draw_path(shake: Vector2) -> void:
	if _path_texture != null:
		# Draw the pre-baked path texture
		draw_texture(_path_texture, shake)
		return
	# Fallback: draw path directly if viewport not ready
	_draw_path_direct(shake)

func _draw_path_direct(shake: Vector2) -> void:
	var map_path: Array = game_state.path
	if map_path.size() < 2:
		return

	# Layer 1: thick shadow
	for i in range(map_path.size() - 1):
		draw_line(map_path[i] + shake + Vector2(3, 3),
				  map_path[i+1] + shake + Vector2(3, 3),
				  Color(0, 0, 0, 0.35), 58.0)

	# Layer 2: outer border
	for i in range(map_path.size() - 1):
		draw_line(map_path[i] + shake, map_path[i+1] + shake,
				  Color(0.22, 0.18, 0.12), 56.0)

	# Layer 3: main surface
	for i in range(map_path.size() - 1):
		draw_line(map_path[i] + shake, map_path[i+1] + shake,
				  Color(0.30, 0.25, 0.18), 48.0)

	# Layer 4: inner highlight
	for i in range(map_path.size() - 1):
		draw_line(map_path[i] + shake, map_path[i+1] + shake,
				  Color(0.38, 0.32, 0.22, 0.7), 36.0)

	# Layer 5: centre groove
	for i in range(map_path.size() - 1):
		draw_line(map_path[i] + shake, map_path[i+1] + shake,
				  Color(0.26, 0.22, 0.15), 8.0)


func _draw_portals(now_ms: int, shake: Vector2) -> void:
	var map_path: Array = game_state.path
	if map_path.size() < 2: return
	# Start portal (Cyan Energy Vortex)
	_draw_vortex(map_path[0] + shake, _THEME.CYAN, now_ms)
	# End portal (Red Energy Vortex)
	_draw_vortex(map_path[-1] + shake, _THEME.RED, now_ms)

func _draw_vortex(p: Vector2, color: Color, now_ms: int) -> void:
	var t := float(now_ms) * 0.003
	for i in range(3):
		var r := 15.0 + i * 6.0
		var rot := t * (1.0 if i % 2 == 0 else -1.0) * (i + 1)
		draw_arc(p, r, rot, rot + PI * 1.2, 16, Color(color.r, color.g, color.b, 0.4 - i * 0.1), 2.0)
		draw_arc(p, r, rot + PI, rot + PI * 1.5, 12, Color(color.r, color.g, color.b, 0.6), 1.0)

# --- 3. Selected tower range circle ---

func _draw_range_circle(now_ms: int, shake: Vector2) -> void:
	if view_state == null or view_state.selected_tower_id < 0:
		return
	var tower: Tower = game_state.get_tower_by_id(view_state.selected_tower_id)
	if tower == null:
		return
	var p: Vector2 = tower.pos + shake
	var r: float = tower.effective_range()
	var col := tower.color

	# Premium Pulsing Glow
	var pulse := (sin(float(now_ms) * 0.004) + 1.0) * 0.5
	draw_circle(p, r, Color(col.r, col.g, col.b, 0.05 + pulse * 0.02))

	# Outer segmented ring (Rotating)
	var segments := 4
	var segment_len := TAU / float(segments) * 0.45
	var rotation_offset := float(now_ms) * 0.001
	for i in range(segments):
		var start_angle := i * (TAU / segments) + rotation_offset
		draw_arc(p, r, start_angle, start_angle + segment_len, 32, col, 2.5)
		draw_arc(p, r, start_angle, start_angle + segment_len, 32, Color.WHITE, 0.5)

	# Inner thin pulsing ring
	draw_arc(p, r - 4.0, 0, TAU, 64, Color(col.r, col.g, col.b, 0.2 + pulse * 0.2), 1.0)

	# Scoped crosshair dots
	for i in range(4):
		var angle := i * PI * 0.5
		var dot_p := p + Vector2(cos(angle), sin(angle)) * r
		draw_circle(dot_p, 3.0, Color.WHITE)
		draw_circle(dot_p, 2.0, col)

# --- 4. Effects ---

func _draw_effects(now_ms: int, shake: Vector2) -> void:
	if game_state == null:
		return
	for effect in game_state.effects:
		_draw_single_effect(effect, now_ms, shake)

func _draw_single_effect(effect: Effect, now_ms: int, shake: Vector2) -> void:
	var age: float = float(now_ms - effect.start_ms)
	var duration: float = float(effect.until_ms - effect.start_ms)
	var t: float = clampf(age / maxf(1.0, duration), 0.0, 1.0)  # 0=start, 1=end
	var alpha: float = clampf(1.0 - t, 0.0, 1.0)
	var p: Vector2 = effect.pos + shake

	match effect.kind:
		"flash":
			draw_circle(p, effect.radius * (1.0 + t * 0.5),
						Color(effect.color.r, effect.color.g, effect.color.b, alpha * 0.6))

		"ring":
			draw_arc(p, effect.radius * (1.0 + t * 0.8), 0.0, TAU, 32,
					 Color(effect.color.r, effect.color.g, effect.color.b, alpha), 2.5)

		"hit":
			draw_arc(p, effect.radius * (1.0 + t), 0.0, TAU, 20,
					 Color(effect.color.r, effect.color.g, effect.color.b, alpha * 0.8), 2.0)

		"hit_flash":
			draw_circle(p, effect.radius,
						Color(1.0, 1.0, 1.0, alpha * 0.75))

		"explosion":
			var er: float = float(effect.radius) * (0.5 + t * 0.8)
			draw_circle(p, er,
						Color(effect.color.r, effect.color.g, effect.color.b, alpha * 0.45))
			draw_arc(p, er, 0.0, TAU, 48,
					 Color(effect.color.r, effect.color.g, effect.color.b, alpha), 3.0)

		"siege_shockwave":
			var er: float = float(effect.radius) * (0.3 + t * 1.1)
			draw_arc(p, er, 0.0, TAU, 48,
					 Color(1.0, 0.6, 0.2, alpha * 0.9), 4.0)
			draw_arc(p, er * 0.7, 0.0, TAU, 32,
					 Color(1.0, 0.85, 0.4, alpha * 0.5), 2.0)

		"vortex":
			var vr: float = float(effect.radius) * (1.2 - t * 0.8)
			for k in range(3):
				var rot: float = t * TAU * 1.5 + float(k) * (TAU / 3.0)
				draw_arc(p, vr, rot, rot + 1.2, 16,
						 Color(effect.color.r, effect.color.g, effect.color.b, alpha), 3.0)
			draw_circle(p, vr * 0.5, Color(effect.color.r, effect.color.g, effect.color.b, alpha * 0.4))

		"death_pop":
			draw_circle(p, effect.radius * (1.0 + t * 1.5),
						Color(1.0, 1.0, 1.0, alpha * 0.5))

		"shards":
			for k in range(8):
				var angle: float = TAU / 8.0 * float(k) + t * 0.8
				var dist: float = float(effect.radius) * t * 1.4
				var sp: Vector2 = p + Vector2(cos(angle), sin(angle)) * dist
				draw_circle(sp, 3.5 * (1.0 - t),
							Color(effect.color.r, effect.color.g, effect.color.b, alpha))

		"lightning_bolt":
			if effect.has_target_pos:
				var tp: Vector2 = effect.target_pos + shake
				_draw_lightning_bolt(p, tp, effect.color, alpha, now_ms)

		"sniper_shot":
			if effect.has_target_pos:
				var tp: Vector2 = effect.target_pos + shake
				draw_line(p, tp, Color(effect.color.r, effect.color.g, effect.color.b, alpha), 2.0)
				draw_circle(tp, 5.0 * alpha, Color(1.0, 1.0, 1.0, alpha * 0.8))

		"radar_pulse":
			var rr: float = float(effect.radius) * t
			draw_arc(p, rr, 0.0, TAU, 48,
					 Color(effect.color.r, effect.color.g, effect.color.b, alpha * 0.7), 2.5)

		"ice_spikes":
			var num_spikes: int = 6
			for k in range(num_spikes):
				var angle: float = TAU / float(num_spikes) * float(k)
				var spike_len: float = float(effect.radius) * (0.4 + t * 0.6)
				var spike_end: Vector2 = p + Vector2(cos(angle), sin(angle)) * spike_len
				draw_line(p, spike_end,
						  Color(effect.color.r, effect.color.g, effect.color.b, alpha), 3.0)

		"ice_rewind":
			draw_arc(p, float(effect.radius) * (1.0 + t * 0.5), 0.0, TAU, 24,
					 Color(0.6, 0.9, 1.0, alpha), 3.0)

		"banner":
			if effect.text != "":
				var text_alpha: float = alpha
				var drift: float = age * effect.dy
				var text_pos: Vector2 = p + Vector2(0.0, -drift - 14.0)
				_draw_text_centered(effect.text, text_pos,
									Color(effect.color.r, effect.color.g, effect.color.b, text_alpha),
									14)

		"dmg_num":
			if effect.text != "":
				var drift: float = age * effect.dy * 60.0
				var text_pos: Vector2 = p + Vector2(0.0, -drift)
				_draw_text_centered(effect.text, text_pos + Vector2(1.0, 1.0),
									Color(0.0, 0.0, 0.0, alpha * 0.65),
									13)
				_draw_text_centered(effect.text, text_pos,
									Color(effect.color.r, effect.color.g, effect.color.b, alpha),
									13)

func _draw_lightning_bolt(a: Vector2, b: Vector2, color: Color, alpha: float, now_ms: int) -> void:
	# Jittered multi-segment bolt
	var segments: int = 6
	var points: Array = [a]
	var perp: Vector2 = (b - a).orthogonal().normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = now_ms % 997
	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var mid: Vector2 = a.lerp(b, t)
		var jitter: float = rng.randf_range(-12.0, 12.0)
		points.append(mid + perp * jitter)
	points.append(b)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i+1],
				  Color(color.r, color.g, color.b, alpha), 2.0)
	# Bright core
	for i in range(points.size() - 1):
		draw_line(points[i], points[i+1],
				  Color(1.0, 1.0, 1.0, alpha * 0.5), 1.0)

# --- 5. Particles ---

func _draw_particles(now_ms: int, shake: Vector2) -> void:
	if game_state == null:
		return
	for p in game_state.particles:
		var age: float = float(now_ms - p.start_ms)
		var life_frac: float = clampf(age / float(p.lifespan_ms), 0.0, 1.0)
		var alpha: float = 1.0 - life_frac
		var draw_pos: Vector2 = p.pos + shake
		var sz: float = p.size * (1.0 - life_frac * 0.5)
		match p.kind:
			"spark":
				draw_rect(Rect2(draw_pos - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)),
						  Color(p.color.r, p.color.g, p.color.b, alpha))
			"smoke":
				draw_circle(draw_pos, sz,
							Color(p.color.r, p.color.g, p.color.b, alpha * 0.35))
			"flame":
				var flame_w: float = sz * 0.8
				var flame_h: float = sz * 1.4
				var flame_rect := Rect2(draw_pos - Vector2(flame_w * 0.5, flame_h), Vector2(flame_w, flame_h))
				draw_rect(flame_rect, Color(p.color.r, p.color.g, p.color.b, alpha * 0.8))
				draw_rect(Rect2(draw_pos - Vector2(flame_w * 0.3, flame_h * 0.7), Vector2(flame_w * 0.6, flame_h * 0.6)), Color(1.0, 1.0, 0.4, alpha))
			"debris":
				draw_rect(Rect2(draw_pos - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)),
						  Color(p.color.r, p.color.g, p.color.b, alpha * 0.85))

# --- 6. Health bars (drawn in _draw, over enemies) ---

func _draw_health_bars(canvas: CanvasItem, shake: Vector2) -> void:
	if game_state == null:
		return
	const BAR_W: float = 34.0
	const BAR_H: float = 6.0
	var now_ms: int = Time.get_ticks_msec()
	for enemy in game_state.enemies:
		var has_status: bool = _enemy_has_visible_status(enemy, now_ms)
		var has_shield: bool = enemy.shields > 0
		var hit_shield: int = _boss_hit_shield_hp(enemy)
		var is_boss: bool = hit_shield >= 0 or enemy is Enemy.BossRegenerator or enemy is Enemy.BossSwarmCarrier
		if enemy.health >= enemy.max_health and not has_status and not has_shield and not is_boss:
			continue
		if now_ms - enemy.last_damage_time > 5500 and not has_status and not has_shield and not is_boss:
			continue

		var hp_frac: float = clampf(float(enemy.health) / float(enemy.max_health), 0.0, 1.0)
		var bar_x: float = enemy.pos.x - BAR_W * 0.5 + shake.x
		var bar_y: float = enemy.pos.y - float(enemy.radius) - 12.0 + shake.y

		# High-contrast background container
		canvas.draw_rect(Rect2(bar_x - 2, bar_y - 2, BAR_W + 4, BAR_H + 4), Color(0.01, 0.02, 0.04, 0.82))
		canvas.draw_rect(Rect2(bar_x, bar_y, BAR_W, BAR_H), Color(0.05, 0.08, 0.12, 0.9))

		# Dynamic health color based on thresholds
		var fill_color: Color = _THEME.GREEN
		if hp_frac <= 0.35:
			fill_color = _THEME.RED
		elif hp_frac <= 0.65:
			fill_color = _THEME.ORANGE
		if enemy is Enemy.BossRegenerator and enemy.health < enemy.max_health:
			fill_color = fill_color.lerp(Color(0.4, 1.0, 0.55), 0.35)

		canvas.draw_rect(Rect2(bar_x, bar_y, BAR_W * hp_frac, BAR_H), fill_color)

		for tick in [0.25, 0.5, 0.75]:
			var tick_x: float = bar_x + BAR_W * tick
			canvas.draw_line(Vector2(tick_x, bar_y + 1.0), Vector2(tick_x, bar_y + BAR_H - 1.0), Color(0.0, 0.0, 0.0, 0.45), 1.0)

		canvas.draw_line(Vector2(bar_x, bar_y + 1), Vector2(bar_x + BAR_W * hp_frac, bar_y + 1), fill_color.lightened(0.4), 1.0)

		if has_shield:
			var s_frac: float = clampf(float(enemy.shields) / maxf(1.0, float(enemy.max_shields)), 0.0, 1.0)
			var s_y: float = bar_y - 4.5
			canvas.draw_rect(Rect2(bar_x - 1.0, s_y - 1.0, BAR_W + 2.0, 3.0), Color(0.01, 0.02, 0.04, 0.70))
			canvas.draw_rect(Rect2(bar_x, s_y, BAR_W * s_frac, 2.5), _THEME.CYAN)
			canvas.draw_line(Vector2(bar_x, s_y), Vector2(bar_x + BAR_W * s_frac, s_y), Color.WHITE, 0.5)

		# Boss hit-shield charges (BossShieldBrute): pips above HP bar
		if hit_shield > 0:
			var pip_y: float = bar_y - 10.0
			for i in range(3):
				var px: float = bar_x + 4.0 + float(i) * 10.0
				var on: bool = i < hit_shield
				canvas.draw_circle(Vector2(px, pip_y), 3.6, Color(0.0, 0.0, 0.0, 0.75))
				canvas.draw_circle(
					Vector2(px, pip_y),
					2.6,
					Color(0.55, 0.85, 1.0, 1.0) if on else Color(0.25, 0.30, 0.38, 0.85)
				)

		_draw_enemy_status_pips(canvas, enemy, now_ms, Vector2(bar_x + BAR_W + 5.0, bar_y + BAR_H * 0.5))

func _boss_hit_shield_hp(enemy: Enemy) -> int:
	if enemy is Enemy.BossShieldBrute:
		return int(enemy.shield_hp)
	return -1

func _enemy_has_visible_status(enemy: Enemy, now_ms: int) -> bool:
	if enemy.stealthed and now_ms >= enemy.revealed_until:
		return true
	if enemy is Enemy.BossRegenerator and enemy.health < enemy.max_health:
		return true
	if _boss_hit_shield_hp(enemy) > 0:
		return true
	return now_ms < enemy.chilled_until or now_ms < enemy.frozen_until or now_ms < enemy.revealed_until

func _draw_enemy_status_pips(canvas: CanvasItem, enemy: Enemy, now_ms: int, start_pos: Vector2) -> void:
	var colors: Array = []
	if now_ms < enemy.frozen_until:
		colors.append(Color(0.90, 0.98, 1.0, 1.0))
	elif now_ms < enemy.chilled_until:
		colors.append(_THEME.CYAN)
	if now_ms < enemy.revealed_until:
		colors.append(_THEME.GOLD)
	if enemy.stealthed and now_ms >= enemy.revealed_until:
		colors.append(Color(0.55, 0.65, 0.85, 0.95))  # stealth
	if enemy is Enemy.BossRegenerator and enemy.health < enemy.max_health:
		colors.append(Color(0.35, 1.0, 0.55, 1.0))  # regen
	for i in range(colors.size()):
		var p: Vector2 = start_pos + Vector2(float(i) * 7.0, 0.0)
		canvas.draw_circle(p, 3.5, Color(0.0, 0.0, 0.0, 0.72))
		canvas.draw_circle(p, 2.4, colors[i])

func _draw_boss_telegraphs(canvas: CanvasItem, shake: Vector2, now_ms: int) -> void:
	## Identity / UX: boss states must be readable without a wiki (W1 contracts).
	if game_state == null:
		return
	for enemy in game_state.enemies:
		var pos: Vector2 = enemy.pos + shake
		var r: float = float(enemy.radius) + 6.0
		var hit_shield: int = _boss_hit_shield_hp(enemy)
		if hit_shield > 0:
			var pulse: float = 0.55 + 0.25 * (0.5 + 0.5 * sin(float(now_ms) * 0.006))
			var col := Color(0.45, 0.82, 1.0, pulse)
			canvas.draw_arc(pos, r + 2.0, 0.0, TAU, 40, col, 2.5, true)
			# Remaining hit charges as arc segments
			var segs: int = mini(3, hit_shield)
			for i in range(segs):
				var a0: float = -PI * 0.5 + float(i) * TAU / 3.0
				var a1: float = a0 + TAU / 3.0 - 0.25
				canvas.draw_arc(pos, r + 7.0, a0, a1, 12, Color(0.7, 0.95, 1.0, 0.9), 3.0, true)
		elif enemy is Enemy.BossSwarmCarrier and enemy.stealthed and now_ms >= enemy.revealed_until:
			canvas.draw_arc(pos, r, 0.0, TAU, 32, Color(0.5, 0.6, 0.85, 0.35), 1.5, true)
		elif enemy is Enemy.BossRegenerator and enemy.health > 0 and enemy.health < enemy.max_health:
			var gpulse: float = 0.4 + 0.35 * (0.5 + 0.5 * sin(float(now_ms) * 0.01))
			canvas.draw_arc(pos, r + 3.0, 0.0, TAU, 36, Color(0.3, 1.0, 0.5, gpulse), 2.0, true)

func _draw_overlay_on(canvas: CanvasItem) -> void:
	if game_state == null: return
	var now_ms: int = Time.get_ticks_msec()
	var shake: Vector2 = view_state.get_screen_shake_offset(now_ms) if view_state else Vector2.ZERO

	_draw_boss_telegraphs(canvas, shake, now_ms)
	_draw_health_bars(canvas, shake)
	_draw_tower_badges(canvas, now_ms, shake)

# --- 7. Tower badges (level dot + variant badge letter) ---

func _draw_tower_badges(canvas: CanvasItem, now_ms: int, shake: Vector2) -> void:
	if game_state == null:
		return
	for tower in game_state.towers:
		var p: Vector2 = tower.pos + shake
		# Level pip dots below the tower
		var pip_color: Color = Color(1.0, 0.9, 0.3) if tower.level >= 5 else Color(0.8, 0.8, 0.8)
		for lvl in range(tower.level):
			var pip_x: float = p.x - float(tower.level - 1) * 3.5 + float(lvl) * 7.0
			canvas.draw_circle(Vector2(pip_x, p.y + float(tower.radius) + 6.0), 2.5, pip_color)
		# Variant badge
		if tower.variant_badge != "":
			_draw_text_centered(tower.variant_badge,
								Vector2(p.x + float(tower.radius) - 2.0, p.y - float(tower.radius) + 2.0),
								Color(1.0, 1.0, 1.0, 0.9), 9, canvas)

# ---------------------------------------------------------------------------
# Text helper — draws a string centered at pos using draw_string
# ---------------------------------------------------------------------------

func _draw_text_centered(text: String, pos: Vector2, color: Color, size: int, canvas: CanvasItem = null) -> void:
	# SystemFont fallback — no asset dependency required
	var target: CanvasItem = canvas if canvas != null else self
	var font := ThemeDB.fallback_font
	var font_size: int = size
	var str_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var draw_pos := Vector2(pos.x - str_size.x * 0.5, pos.y + str_size.y * 0.5)
	target.draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# ---------------------------------------------------------------------------
# Ghost placement overlay (called by GameScreen during placement mode)
# ---------------------------------------------------------------------------

func draw_placement_ghost(pos: Vector2, tower_type: String, valid: bool, now_ms: int) -> void:
	var col: Color = _TT.TOWER_TYPES[tower_type]["color"] if tower_type in _TT.TOWER_TYPES else Color.WHITE
	var ghost_color: Color = col if valid else _THEME.RED
	var pulse := (sin(float(now_ms) * 0.008) + 1.0) * 0.5
	ghost_color.a = 0.45 + pulse * 0.15

	# Draw background circle
	draw_circle(pos, float(_MAPS.TOWER_RADIUS), Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.2))
	# Draw animated border
	draw_arc(pos, float(_MAPS.TOWER_RADIUS), 0.0, TAU, 32, ghost_color, 2.0)

	# Range preview
	if game_state:
		var dummy_range: float = 110.0
		if tower_type in _TT.TOWER_TYPES:
			dummy_range = _TT.TOWER_TYPES[tower_type].get("range", 110.0)

		var r_col := col if valid else _THEME.RED
		r_col.a = 0.25 + pulse * 0.1
		var fill_alpha: float = 0.05 if valid else 0.035
		var line_width: float = 1.5 if valid else 1.2
		draw_circle(pos, dummy_range, Color(r_col.r, r_col.g, r_col.b, fill_alpha))
		draw_arc(pos, dummy_range, 0.0, TAU, 64, r_col, line_width)

	if valid:
		# Draw crosshair line to cursor
		draw_line(pos + Vector2(-10, 0), pos + Vector2(10, 0), Color.WHITE, 1.0)
		draw_line(pos + Vector2(0, -10), pos + Vector2(0, 10), Color.WHITE, 1.0)
	else:
		# Draw "X" for invalid
		var x_sz := 8.0
		draw_line(pos + Vector2(-x_sz, -x_sz), pos + Vector2(x_sz, x_sz), _THEME.RED, 2.5)
		draw_line(pos + Vector2(x_sz, -x_sz), pos + Vector2(-x_sz, x_sz), _THEME.RED, 2.5)

# ---------------------------------------------------------------------------
# Inner class: draws the path terrain into the SubViewport once at startup
# ---------------------------------------------------------------------------

class _PathDrawNode extends Node2D:
	var maps_ref = null

	func _draw() -> void:
		if maps_ref == null:
			return
		# We use MAPS[0] path as placeholder; GameScreen rebakes when map changes.
		# The viewport is rebuilt via _rebuild_path_viewport(map_path).
		pass   # actual draw happens via _draw_path_direct in parent for now

class _OverlayDrawNode extends Node2D:
	var renderer_ref: GameRenderer = null

	func _draw() -> void:
		if renderer_ref != null:
			renderer_ref._draw_overlay_on(self)

# ---------------------------------------------------------------------------
# API for GameScreen to trigger a path rebake when map changes
# ---------------------------------------------------------------------------

func rebuild_path_for_map(map_path: Array) -> void:
	# Remove old viewport
	if _path_viewport != null:
		_path_viewport.queue_free()
		_path_viewport = null
		_path_texture = null
		_path_baked = false

	_path_viewport = SubViewport.new()
	_path_viewport.size = Vector2i(_MAPS.WIDTH, _MAPS.HEIGHT)
	_path_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_path_viewport.transparent_bg = true

	var path_node := _BakedPathDraw.new()
	path_node.map_path = map_path
	path_node.maps_ref = _MAPS
	_path_viewport.add_child(path_node)
	add_child(_path_viewport)
	_path_texture = _path_viewport.get_texture()
	_path_baked = true

class _BakedPathDraw extends Node2D:
	var map_path: Array = []
	var maps_ref = null

	func _draw() -> void:
		if map_path.size() < 2:
			return
		# Holo-Rail Style (Navy / Steel / Cyan)
		var c_shadow := Color(0, 0, 0, 0.4)
		var c_border := Color(0.12, 0.15, 0.22)
		var c_rail   := Color(0.08, 0.10, 0.16)
		var c_energy := Color(0.18, 0.69, 1.0, 0.12)

		# Shadow
		for i in range(map_path.size() - 1):
			draw_line(map_path[i] + Vector2(3,3), map_path[i+1] + Vector2(3,3), c_shadow, 54.0)
		# Outer Rail Frame
		for i in range(map_path.size() - 1):
			draw_line(map_path[i], map_path[i+1], c_border, 52.0)
		# Main Track
		for i in range(map_path.size() - 1):
			draw_line(map_path[i], map_path[i+1], c_rail, 44.0)
		# Energy Conduit
		for i in range(map_path.size() - 1):
			draw_line(map_path[i], map_path[i+1], c_energy, 12.0)
		# Center Laser Line
		for i in range(map_path.size() - 1):
			draw_line(map_path[i], map_path[i+1], Color(0.18, 0.69, 1.0, 0.25), 2.0)
