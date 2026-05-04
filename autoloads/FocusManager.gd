extends Node

# Global dpad / remote-navigation manager for Fire TV and keyboard.
# Provides:
#   register_initial_focus   — grab focus after scene settles
#   setup_dpad_neighbors     — wire a 1-D list (vertical or horizontal)
#   setup_grid_dpad          — wire a flat list as an N-column 2-D grid
#   link_rows                — connect bottom of one row to top of another
#   focus_first_in           — focus first enabled, visible node in a list

signal back_pressed

func _input(event: InputEvent) -> void:
	var is_back := InputMap.has_action("ui_back") and event.is_action_pressed("ui_back")
	if event.is_action_pressed("ui_cancel") or is_back:
		back_pressed.emit()

# ---------------------------------------------------------------------------
# Focus helpers
# ---------------------------------------------------------------------------

func register_initial_focus(node: Control) -> void:
	if node == null:
		return
	# Wait one frame so the scene tree and layout have fully settled.
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(node) and node.is_inside_tree():
		node.grab_focus()

func focus_first_in(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node) and node.is_visible_in_tree():
			var btn := node as Button
			if btn and btn.disabled:
				continue
			node.grab_focus()
			return

# ---------------------------------------------------------------------------
# Neighbor wiring
# ---------------------------------------------------------------------------

func setup_dpad_neighbors(nodes: Array, vertical: bool = true) -> void:
	# Wire a 1-D list; vertical = up/down, horizontal = left/right.
	for i in nodes.size():
		var cur: Control = nodes[i]
		if not is_instance_valid(cur):
			continue
		if i > 0 and is_instance_valid(nodes[i - 1]):
			if vertical: cur.focus_neighbor_top    = nodes[i - 1].get_path()
			else:        cur.focus_neighbor_left   = nodes[i - 1].get_path()
		if i < nodes.size() - 1 and is_instance_valid(nodes[i + 1]):
			if vertical: cur.focus_neighbor_bottom = nodes[i + 1].get_path()
			else:        cur.focus_neighbor_right  = nodes[i + 1].get_path()

func setup_grid_dpad(nodes: Array, cols: int) -> void:
	# Wire a flat array as a cols-wide 2-D grid.
	if cols <= 0 or nodes.is_empty():
		return
	var count: int = nodes.size()
	for idx in count:
		var node: Control = nodes[idx]
		if not is_instance_valid(node):
			continue
		var row: int = idx / cols
		var col: int = idx % cols
		if col > 0 and is_instance_valid(nodes[idx - 1]):
			node.focus_neighbor_left  = nodes[idx - 1].get_path()
		if col < cols - 1 and idx + 1 < count and is_instance_valid(nodes[idx + 1]):
			node.focus_neighbor_right = nodes[idx + 1].get_path()
		if idx - cols >= 0 and is_instance_valid(nodes[idx - cols]):
			node.focus_neighbor_top    = nodes[idx - cols].get_path()
		if idx + cols < count and is_instance_valid(nodes[idx + cols]):
			node.focus_neighbor_bottom = nodes[idx + cols].get_path()

func link_rows(top_row: Array, bottom_row: Array) -> void:
	# Connect bottom of every node in top_row to the nearest node in bottom_row.
	if top_row.is_empty() or bottom_row.is_empty():
		return
	for i in top_row.size():
		var t: Control = top_row[i]
		var b: Control = bottom_row[mini(i, bottom_row.size() - 1)]
		if is_instance_valid(t) and is_instance_valid(b):
			t.focus_neighbor_bottom = b.get_path()
	for i in bottom_row.size():
		var b: Control = bottom_row[i]
		var t: Control = top_row[mini(i, top_row.size() - 1)]
		if is_instance_valid(b) and is_instance_valid(t):
			b.focus_neighbor_top = t.get_path()

func set_neighbor(node: Control, direction: String, target: Control) -> void:
	# Convenience: set a single directional neighbor.
	if not is_instance_valid(node) or not is_instance_valid(target):
		return
	match direction:
		"top":    node.focus_neighbor_top    = target.get_path()
		"bottom": node.focus_neighbor_bottom = target.get_path()
		"left":   node.focus_neighbor_left   = target.get_path()
		"right":  node.focus_neighbor_right  = target.get_path()
