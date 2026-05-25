extends Node

# Global audio + haptics manager.
# Add res://assets/sfx/*.ogg files to activate sounds — missing files are silently skipped.

enum SFX {
	BTN_PRESS,
	TOWER_PLACE,
	TOWER_UPGRADE,
	TOWER_PROMOTE,
	TOWER_SELL,
	ENEMY_DEATH,
	BOSS_APPEAR,
	WAVE_START,
	WAVE_CLEAR,
	WAVE_SHOP_OPEN,
	GAME_OVER,
	WIN,
}

const _SFX_PATHS: Dictionary = {
	SFX.BTN_PRESS:       "res://assets/sfx/btn_press.ogg",
	SFX.TOWER_PLACE:     "res://assets/sfx/tower_place.ogg",
	SFX.TOWER_UPGRADE:   "res://assets/sfx/tower_upgrade.ogg",
	SFX.TOWER_PROMOTE:   "res://assets/sfx/tower_promote.ogg",
	SFX.TOWER_SELL:      "res://assets/sfx/tower_sell.ogg",
	SFX.ENEMY_DEATH:     "res://assets/sfx/enemy_death.ogg",
	SFX.BOSS_APPEAR:     "res://assets/sfx/boss_appear.ogg",
	SFX.WAVE_START:      "res://assets/sfx/wave_start.ogg",
	SFX.WAVE_CLEAR:      "res://assets/sfx/wave_clear.ogg",
	SFX.WAVE_SHOP_OPEN:  "res://assets/sfx/wave_shop.ogg",
	SFX.GAME_OVER:       "res://assets/sfx/game_over.ogg",
	SFX.WIN:             "res://assets/sfx/win.ogg",
}

const _POOL_SIZE: int = 8

var _pool: Array[AudioStreamPlayer] = []
var _sfx_enabled: bool = true
var _loaded_streams: Dictionary = {}   # SFX -> AudioStream cache

func _ready() -> void:
	_ensure_sfx_bus()
	for _i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_preload_streams()
	configure_from_progression()

func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")

func configure_from_progression() -> void:
	var settings: Dictionary = Progression.get_settings()
	var sfx_on: bool = settings.get("sfx_enabled", true)
	var master_muted: bool = settings.get("audio_muted", false)
	configure(sfx_on and not master_muted)

func _preload_streams() -> void:
	for sfx_id in _SFX_PATHS:
		var path: String = _SFX_PATHS[sfx_id]
		if ResourceLoader.exists(path):
			_loaded_streams[sfx_id] = load(path)

func configure(sfx_on: bool) -> void:
	_sfx_enabled = sfx_on

func play(sfx: SFX, volume_db: float = 0.0) -> void:
	if not _sfx_enabled:
		return
	if not sfx in _loaded_streams:
		return
	var player := _get_free_player()
	player.stream = _loaded_streams[sfx]
	player.volume_db = volume_db
	player.play()

func vibrate(duration_ms: int = 50) -> void:
	if OS.get_name() == "Android":
		Input.vibrate_handheld(duration_ms)

func play_and_vibrate(sfx: SFX, vibrate_ms: int = 40) -> void:
	play(sfx)
	vibrate(vibrate_ms)

func _get_free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	# All busy — steal the oldest (index 0 is the longest-playing)
	return _pool[0]

# ---------------------------------------------------------------------------
# Visual particle burst helpers (retained from original stub)
# ---------------------------------------------------------------------------

func spawn_burst(pos: Vector2, color: Color, count: int = 8) -> void:
	for _i in range(count):
		var p := _create_dot_particle(pos, color)
		get_tree().root.add_child(p)

func spawn_collect_vfx(start_pos: Vector2, end_pos: Vector2, color: Color) -> void:
	var p := _create_dot_particle(start_pos, color)
	get_tree().root.add_child(p)
	var tween := p.create_tween()
	tween.set_parallel(true)
	tween.tween_property(p, "position", end_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(p, "scale", Vector2.ZERO, 0.6).set_delay(0.2)
	tween.chain().tween_callback(p.queue_free)

func _create_dot_particle(pos: Vector2, color: Color) -> Control:
	var p := Control.new()
	p.position = pos
	p.custom_minimum_size = Vector2(8, 8)
	p.pivot_offset = Vector2(4, 4)
	var dot := ColorRect.new()
	dot.color = color
	dot.size = Vector2(6, 6)
	dot.position = Vector2(1, 1)
	p.add_child(dot)
	var angle := randf() * TAU
	var speed := randf_range(50.0, 150.0)
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	var tween := p.create_tween()
	tween.set_parallel(true)
	tween.tween_property(p, "position", pos + velocity, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(p, "modulate:a", 0.0, 0.5)
	tween.tween_property(p, "scale", Vector2(0.2, 0.2), 0.5)
	tween.chain().tween_callback(p.queue_free)
	return p
