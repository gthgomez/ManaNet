class_name RunSetup
extends RefCounted

# Static helpers for building a fresh run's simulation state.
# Extracted verbatim from GameScreen.gd — no scene dependencies.

const _MAPS := preload("res://data/maps.gd")
const _TT   := preload("res://data/tower_types.gd")

static func apply_variant_stats(gs: GameState) -> void:
	gs._variant_deltas = {}
	for ttype in _TT.TOWER_TYPES_LIST:
		var variant: Dictionary = Progression.get_variant_for_type(ttype)
		if not variant.is_empty():
			gs._variant_deltas[ttype] = variant

static func place_starting_tower(gs: GameState, run_config: Dictionary) -> void:
	var st_type: String = run_config.get("starting_tower_type", "")
	if st_type == "" or st_type == "choice":
		return
	if not st_type in _TT.TOWER_TYPES:
		return
	if gs.path.size() < 2:
		return

	var start: Vector2 = gs.path[0]
	var next: Vector2 = gs.path[1]
	var direction: Vector2 = next - start
	var length: float = direction.length()
	if length == 0.0:
		return

	var perp: Vector2 = Vector2(-direction.y / length, direction.x / length)
	var offset: float = float(_MAPS.PATH_RADIUS + _MAPS.TOWER_RADIUS + 6)
	var anchor: Vector2 = start + direction * 0.25

	for sign in [1.0, -1.0]:
		var candidate: Vector2 = anchor + perp * offset * sign
		if _try_place_free_starting_tower(gs, candidate, st_type):
			return

	for radius in range(10, 160, 10):
		for angle_deg in range(0, 360, 30):
			var angle: float = deg_to_rad(float(angle_deg))
			var candidate: Vector2 = start + Vector2(cos(angle), sin(angle)) * float(radius)
			if _try_place_free_starting_tower(gs, candidate, st_type):
				return

static func _try_place_free_starting_tower(gs: GameState, candidate: Vector2, st_type: String) -> bool:
	var check: Array = gs.can_place_tower(candidate, st_type)
	if not check[0]:
		return false
	var tower := gs._configure_tower(Tower.new(candidate, st_type, gs.tower_id_counter))
	gs.tower_id_counter += 1
	gs.towers.append(tower)
	gs.stat_tower_use_by_type[st_type] = gs.stat_tower_use_by_type.get(st_type, 0) + 1
	return true
