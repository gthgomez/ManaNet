class_name Enemy

# Port of Enemy base class + subclasses from core.py (lines 295-426).
# Plain GDScript class — no Node, no scene. GameState owns arrays of these.

var path: Array          # Array[Vector2]
var path_index: int
var pos: Vector2
var speed: float
var health: int
var max_health: int
var radius: int
var reward: int
var flying: bool
var shields: int
var max_shields: int
var armor: float         # fraction damage reduction (0.0–1.0)
var chilled_until: int   # ms timestamp
var frozen_until: int
var revealed_until: int
var stealthed: bool
var burn_until: int
var burn_dps: int
var last_teleport_time: int
var last_damage_time: int
var flash_until: int
var rooted_until: int = 0
var transmute_until: int = 0
var disrupt_until: int = 0
var rewind_count: int = 0
var facing_right: bool = true
var marked_until: int = 0   # Longshot Sniper variant — all towers deal +15% to marked targets

# String tag used for death-rattle particle dispatch
var type_name: String = "Enemy"

func _init(p_path: Array) -> void:
	path = p_path
	path_index = 0
	pos = Vector2(p_path[0])
	speed = 2.0
	health = 100
	max_health = 100
	radius = 15
	reward = 20
	flying = false
	shields = 0
	max_shields = 0
	armor = 0.0
	chilled_until = 0
	frozen_until = 0
	revealed_until = 0
	stealthed = false
	last_teleport_time = -999999

func get_remaining_path_distance() -> float:
	if path_index >= path.size() - 1:
		return 0.0
	var total: float = pos.distance_to(path[path_index + 1])
	for i in range(path_index + 1, path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total

func rewind_by_distance(fraction: float, now_ms: int) -> bool:
	if flying:
		return false
	if now_ms - last_teleport_time < 3000:
		return false
	last_teleport_time = now_ms
	rewind_count += 1

	var travelled: float = 0.0
	for i in range(path_index):
		travelled += path[i].distance_to(path[i + 1])
	travelled += path[path_index].distance_to(pos)
	
	# Rewind Resistance: each subsequent rewind is 33% less effective
	var effectiveness: float = pow(0.66, float(rewind_count - 1))
	var target_travelled: float = maxf(0.0, travelled * (1.0 - fraction * effectiveness))

	var remaining: float = target_travelled
	path_index = 0
	pos = Vector2(path[0])
	for i in range(path.size() - 1):
		var seg_len: float = path[i].distance_to(path[i + 1])
		if remaining <= seg_len:
			var t: float = 0.0 if seg_len == 0.0 else remaining / seg_len
			pos = path[i].lerp(path[i + 1], t)
			path_index = i
			return true
		remaining -= seg_len
		path_index = i + 1
		pos = Vector2(path[i + 1])
	return true

func current_speed(now_ms: int) -> float:
	if now_ms < frozen_until or now_ms < rooted_until:
		return 0.0
	if now_ms < chilled_until:
		return speed * 0.6
	return speed

func move(now_ms: int, speed_multiplier: float = 1.0) -> bool:
	if path_index >= path.size() - 1:
		return true
	var target: Vector2 = path[path_index + 1]
	var diff: Vector2 = target - pos
	var dist: float = diff.length()
	var spd: float = current_speed(now_ms) * speed_multiplier
	if dist <= spd:
		pos = target
		path_index += 1
	elif dist > 0.0:
		var move_vec: Vector2 = diff.normalized() * spd
		pos += move_vec
		if abs(move_vec.x) > 0.1:
			facing_right = move_vec.x > 0
	return path_index >= path.size() - 1

func take_damage(dmg: int) -> bool:
	var rem: int = dmg
	if shields > 0:
		var s_dmg: int = mini(shields, rem)
		shields -= s_dmg
		rem -= s_dmg
		
	if rem > 0:
		var effective: int = maxi(1, int(round(float(rem) * (1.0 - armor))))
		health -= effective
	return health <= 0


# ---------------------------------------------------------------------------
# Subclasses
# ---------------------------------------------------------------------------

class FastScout extends Enemy:
	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed = 3.5
		health = 60
		max_health = 60
		reward = 15
		radius = 12
		type_name = "FastScout"
		stealthed = true

class ArmoredTank extends Enemy:
	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed = 1.25
		health = 250
		max_health = 250
		reward = 35
		armor = 0.18
		radius = 18
		type_name = "ArmoredTank"
		shields = 50
		max_shields = 50

class FlyingDrone extends Enemy:
	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed = 2.9
		health = 82
		max_health = 82
		reward = 24
		flying = true
		radius = 13
		type_name = "FlyingDrone"
		stealthed = true

class SwarmMinion extends Enemy:
	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed = 2.4
		health = 44
		max_health = 44
		reward = 9
		radius = 10
		type_name = "SwarmMinion"

class HeavyBrute extends Enemy:
	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed = 1.7
		health = 190
		max_health = 190
		reward = 40
		radius = 17
		type_name = "HeavyBrute"
		shields = 120
		max_shields = 120


# ---------------------------------------------------------------------------
# Boss subclasses (waves 5, 10, 15)
# ---------------------------------------------------------------------------

class BossShieldBrute extends Enemy:
	# Absorbs the first 3 hits entirely via shield_hp (checked in GameState.apply_hit).
	# Split into 2 ArmoredTanks on shield break is not implemented (not in Kivy original; Godot-only addition planned but deferred).
	var shield_hp: int = 3

	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed   = 1.0
		health  = 750
		max_health = 750
		reward  = 120
		armor   = 0.22
		radius  = 23
		type_name = "BossShieldBrute"

class BossSwarmCarrier extends Enemy:
	# Spawns 4 SwarmMinions at its position on death (handled in GameState dead-enemy loop).
	var spawned_swarm: bool = false

	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed   = 2.4
		health  = 400
		max_health = 400
		reward  = 100
		flying  = true
		radius  = 20
		type_name = "BossSwarmCarrier"
		stealthed = true   # enters stealthed; Sniper/Lightning can reveal

class BossRegenerator extends Enemy:
	# Regenerates regen_dps HP per second (applied in GameState movement step).
	var regen_dps: float = 8.0

	func _init(p_path: Array) -> void:
		super._init(p_path)
		speed   = 1.5
		health  = 600
		max_health = 600
		reward  = 110
		armor   = 0.15
		radius  = 21
		type_name = "BossRegenerator"
		shields = 80
		max_shields = 80
