class_name Particle

# Port of Particle dataclass from core.py (lines 158-168).
# Physics updated in GameState.update_simulation() — no Node.

var kind: String        # "spark", "smoke", "debris"
var pos: Vector2
var vel: Vector2
var color: Color
var size: float
var lifespan_ms: int
var start_ms: int
var friction: float
var gravity: float

func _init(p_kind: String, p_pos: Vector2, p_vel: Vector2,
		   p_color: Color, p_size: float,
		   p_lifespan_ms: int, p_start_ms: int,
		   p_friction: float = 0.98, p_gravity: float = 0.0) -> void:
	kind = p_kind
	pos = p_pos
	vel = p_vel
	color = p_color
	size = p_size
	lifespan_ms = p_lifespan_ms
	start_ms = p_start_ms
	friction = p_friction
	gravity = p_gravity
