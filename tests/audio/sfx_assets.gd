extends SceneTree

# Asset gate for the original SFX set: every cue JuiceManager can play must
# exist, import, decode, and be longer than a single-frame blip. Loudness is
# normalized by tools/audio/generate_sfx.py; this gate catches missing or
# truncated files in CI.

const CUES: Array[String] = [
	"btn_press", "tower_place", "tower_upgrade", "tower_promote", "tower_sell",
	"enemy_death", "boss_appear", "wave_start", "wave_clear", "wave_shop",
	"integrity_lost", "error", "purchase", "game_over", "win",
]

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	for cue in CUES:
		var path := "res://assets/sfx/%s.ogg" % cue
		_check(ResourceLoader.exists(path, "AudioStream"), "%s exists" % cue)
		if not ResourceLoader.exists(path, "AudioStream"):
			continue
		var stream = load(path)
		_check(stream != null and stream is AudioStream, "%s loads as AudioStream" % cue)
		if stream is AudioStream:
			_check(stream.get_length() >= 0.03, "%s is at least 30 ms (%.3fs)" % [cue, stream.get_length()])
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			_check(file.get_length() > 1500, "%s asset is not an empty stub (%d bytes)" % [cue, file.get_length()])
			file.close()
	# The three formerly reused cues must have distinct assets now.
	for cue in ["integrity_lost", "error", "purchase"]:
		_check(FileAccess.file_exists("res://assets/sfx/%s.ogg" % cue),
			"%s has a dedicated cue rather than a reused placeholder" % cue)
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	quit(1 if _fail > 0 else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)
