class_name Projectile

# Port of Projectile class from core.py (lines 681-719).

const _MAPS := preload("res://data/maps.gd")

var pos: Vector2
var prev_pos: Vector2
var target: Enemy
var tower: Tower
var damage: int
var speed: float
var radius: int
var created_ms: int
var shot_index: int
var dx: float
var dy: float

func _init(p_start: Vector2, p_target: Enemy, p_tower: Tower,
		   p_damage: int, p_created_ms: int,
		   p_shot_index: int = 0, speed_multiplier: float = 1.0) -> void:
	pos = p_start
	prev_pos = p_start
	target = p_target
	tower = p_tower
	damage = p_damage
	speed = 9.0 * maxf(0.25, speed_multiplier)
	radius = 6
	created_ms = p_created_ms
	shot_index = p_shot_index
	dx = 0.0
	dy = 0.0
	_update_direction()

func _update_direction() -> void:
	if target == null or target.health <= 0:
		return
	var diff: Vector2 = target.pos - pos
	var dist: float = diff.length()
	if dist > 0.0:
		var spread_angle: float = 0.0
		if tower.multi_shot() > 1:
			spread_angle = -0.1 + float(shot_index) * 0.1
		var base_angle: float = atan2(diff.y, diff.x) + spread_angle
		dx = cos(base_angle) * speed
		dy = sin(base_angle) * speed

func move() -> void:
	prev_pos = pos
	pos.x += dx
	pos.y += dy
	if target != null and target.health > 0:
		_update_direction()

func out_of_bounds() -> bool:
	return pos.x < 0 or pos.x > _MAPS.WIDTH or pos.y < 0 or pos.y > _MAPS.HEIGHT
