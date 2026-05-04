class_name UpgradePathTracker

# Port of UpgradePathTracker dataclass from core.py (lines 172-292).
# Manages the 3-path upgrade tree: one primary (T5), one secondary (T2), third locked.

const PATH_KEYS: Array = ["Top", "Middle", "Bottom"]

var path_levels: Dictionary = {"Top": 0, "Middle": 0, "Bottom": 0}
var primary_path: String = ""        # "" = not chosen yet
var secondary_path: String = ""      # "" = not chosen yet
var locked_paths: Array = []         # paths the player can no longer invest in
var pending_promotion_path: String = ""  # "" = no pending promotion

func _init() -> void:
	path_levels = {"Top": 0, "Middle": 0, "Bottom": 0}
	primary_path = ""
	secondary_path = ""
	locked_paths = []
	pending_promotion_path = ""

func active_paths() -> Array:
	var result: Array = []
	for path in PATH_KEYS:
		if path_levels[path] > 0:
			result.append(path)
	return result

func has_pending_promotion() -> bool:
	return pending_promotion_path != ""

func can_attempt_upgrade(path: String) -> bool:
	if not path in path_levels:
		return false
	if pending_promotion_path != "":
		return false
	if path in locked_paths:
		return false
	var current: int = path_levels[path]
	if current >= 5:
		return false

	if primary_path == "":
		# No promotion chosen yet — player may invest freely in one path
		# (1-0-0, 2-0-0 …). Investing in a second path triggers the dialog.
		var active: Array = active_paths()
		if not path in active and active.size() >= 2:
			# Blocking a third pre-promotion path
			return false
		return current < 5

	if path == primary_path:
		return current < 5
	if secondary_path == "":
		# Primary exists but no secondary yet; allow new path (dialog fires via
		# would_trigger_promotion_preview), or deepen an existing active path.
		var active: Array = active_paths()
		if path in active:
			return current < 2
		return true
	if path == secondary_path:
		return current < 2
	return false

func would_trigger_promotion_preview(path: String) -> bool:
	if primary_path != "":
		return false
	var active: Array = active_paths()
	var other_active: Array = []
	for p in active:
		if p != path:
			other_active.append(p)
	return other_active.size() >= 1 and path_levels[path] == 0

func start_promotion_preview(path: String) -> bool:
	if not can_attempt_upgrade(path):
		return false
	if not would_trigger_promotion_preview(path):
		return false
	pending_promotion_path = path
	return true

func cancel_promotion() -> void:
	pending_promotion_path = ""

func confirm_promotion() -> bool:
	var new_path: String = pending_promotion_path
	if new_path == "":
		return false
	if path_levels[new_path] != 0:
		return false

	# Pick the most-invested active path (excluding new_path) as primary
	var best_path: String = ""
	var best_level: int = -1
	for p in PATH_KEYS:
		if p == new_path:
			continue
		if path_levels[p] > best_level:
			best_level = path_levels[p]
			best_path = p
	if best_path == "" or best_level <= 0:
		return false

	primary_path = best_path
	secondary_path = new_path
	path_levels[new_path] = 1   # first upgrade applied on the new secondary

	locked_paths.clear()
	for p in PATH_KEYS:
		if p != primary_path and p != secondary_path:
			locked_paths.append(p)

	pending_promotion_path = ""
	return true

func apply_non_promotion_upgrade(path: String) -> bool:
	if not can_attempt_upgrade(path):
		return false
	path_levels[path] += 1

	if primary_path != "":
		if path == primary_path and path_levels[path] > 5:
			path_levels[path] = 5
			return false
		if path != primary_path:
			if secondary_path == "":
				secondary_path = path
				locked_paths.clear()
				for p in PATH_KEYS:
					if p != primary_path and p != secondary_path:
						locked_paths.append(p)
			elif path != secondary_path:
				return false
			if path_levels[path] > 2:
				path_levels[path] = 2
				return false
	return true

# Serialise to a plain dict for JSON save
func to_dict() -> Dictionary:
	return {
		"path_levels": path_levels.duplicate(),
		"primary_path": primary_path,
		"secondary_path": secondary_path,
		"locked_paths": locked_paths.duplicate(),
		"pending_promotion_path": pending_promotion_path,
	}

# Restore from a saved dict
func from_dict(d: Dictionary) -> void:
	path_levels = d.get("path_levels", {"Top": 0, "Middle": 0, "Bottom": 0}).duplicate()
	primary_path = d.get("primary_path", "")
	secondary_path = d.get("secondary_path", "")
	locked_paths = d.get("locked_paths", []).duplicate()
	pending_promotion_path = d.get("pending_promotion_path", "")

func get_dominant_path() -> String:
	var best := ""
	var best_lvl := 0
	for p in PATH_KEYS:
		if path_levels[p] > best_lvl:
			best_lvl = path_levels[p]
			best = p
	return best
