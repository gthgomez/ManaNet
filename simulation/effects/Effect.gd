class_name Effect

# Port of Effect dataclass from core.py (lines 145-155).
# Plain data container — no Node.

var kind: String
var pos: Vector2
var until_ms: int
var radius: int
var color: Color
var text: String
var start_ms: int
var dy: float           # upward drift (px/ms) for dmg_num effects
var target_pos: Vector2 # for directional effects (lightning bolt, sniper shot)
var has_target_pos: bool

func _init(p_kind: String, p_pos: Vector2, p_until_ms: int,
		   p_radius: int = 18, p_color: Color = Color.WHITE,
		   p_text: String = "", p_start_ms: int = 0,
		   p_dy: float = 0.0,
		   p_target_pos: Vector2 = Vector2.ZERO,
		   p_has_target_pos: bool = false) -> void:
	kind = p_kind
	pos = p_pos
	until_ms = p_until_ms
	radius = p_radius
	color = p_color
	text = p_text
	start_ms = p_start_ms
	dy = p_dy
	target_pos = p_target_pos
	has_target_pos = p_has_target_pos
