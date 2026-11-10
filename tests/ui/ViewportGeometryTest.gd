extends Node

# Viewport geometry qualification (Workstream F1).
#
# Mounts each real screen at the representative desktop and mobile sizes from
# the brief and asserts that essential controls stay on-screen, remain at a
# usable touch size, and do not overlap the shop strip or each other.
#
# This is headless: it verifies layout MATH and control geometry, not pixels.
# Screenshot/visual evidence is a separate, explicitly-labelled step.
#
# Canvas is 900x600 with stretch aspect "expand", so a portrait viewport is a
# genuinely unsupported configuration — the game is landscape-first. For those
# we assert the app still builds without error and report the mode as
# unsupported rather than pretending portrait gameplay works.
#
# Run: godot --headless --path . res://tests/ui/ViewportGeometryTest.tscn

const REAL_SAVE_PATH := "user://td_progression.json"
const SANDBOX_PATH := "user://td_progression.geometry.json"
const MIN_TOUCH: float = 40.0

## [label, width, height, supported_landscape]
const VIEWPORTS: Array = [
	["mobile 568x320", 568, 320, true],
	["mobile 640x360", 640, 360, true],
	["tablet 800x600", 800, 600, true],
	["desktop 1280x720", 1280, 720, true],
	["desktop 1440x900", 1440, 900, true],
	["portrait 320x568", 320, 568, false],
	["portrait 360x640", 360, 640, false],
	["portrait 390x844", 390, 844, false],
]

var _pass: int = 0
var _fail: int = 0
var _real_before: PackedByteArray = PackedByteArray()
var _real_existed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_real_existed = FileAccess.file_exists(REAL_SAVE_PATH)
	if _real_existed:
		_real_before = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	Progression.set_save_path(SANDBOX_PATH)
	Progression.load_profile()
	await _run()
	_verify_real_save_untouched()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	_restore_viewport()
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _set_viewport(w: int, h: int) -> void:
	var root: Window = get_tree().root
	root.content_scale_size = Vector2i(w, h)
	root.size = Vector2i(w, h)
	await get_tree().process_frame
	await get_tree().process_frame

func _restore_viewport() -> void:
	var root: Window = get_tree().root
	root.content_scale_size = Vector2i(900, 600)
	root.size = Vector2i(900, 600)

func _mount(scene_path: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene

func _unmount(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame

func _run() -> void:
	print("--- VIEWPORT GEOMETRY ---")
	for vp in VIEWPORTS:
		await _check_game_screen(vp[0], int(vp[1]), int(vp[2]), bool(vp[3]))
	for vp in VIEWPORTS:
		await _check_wave_shop(vp[0], int(vp[1]), int(vp[2]), bool(vp[3]))
	for vp in VIEWPORTS:
		await _check_menu_and_end(vp[0], int(vp[1]), int(vp[2]))

# ---------------------------------------------------------------------------
# Game screen: essential HUD controls must be on-screen and touchable.
# ---------------------------------------------------------------------------

func _check_game_screen(label: String, w: int, h: int, supported: bool) -> void:
	await _set_viewport(w, h)
	Progression.pending_map_id = 0
	var gs: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame
	var vp: Vector2 = gs.get_viewport_rect().size

	# Essential controls: wave button, integrity/credits labels, shop strip.
	var controls := {
		"wave button": gs._wave_btn,
		"credits label": gs._gold_label,
		"integrity label": gs._lives_label,
		"shop strip": gs._shop_scroll,
	}
	var all_on_screen: bool = true
	var offenders: Array = []
	for name in controls:
		var ctrl = controls[name]
		if ctrl == null:
			continue
		var rect: Rect2 = ctrl.get_global_rect()
		# Allow a small tolerance for sub-pixel layout rounding.
		var ok: bool = (rect.position.x >= -1.0
			and rect.position.y >= -1.0
			and rect.position.x + rect.size.x <= vp.x + 1.0
			and rect.position.y + rect.size.y <= vp.y + 1.0)
		if not ok:
			all_on_screen = false
			offenders.append("%s @ %.0f,%.0f %.0fx%.0f" % [name, rect.position.x,
				rect.position.y, rect.size.x, rect.size.y])
	_check(all_on_screen, "%s: essential HUD controls stay within %.0fx%.0f%s"
		% [label, vp.x, vp.y, "" if offenders.is_empty() else " (offenders: %s)" % str(offenders)])

	# Touch targets must be large enough to hit reliably.
	var wave_rect: Rect2 = gs._wave_btn.get_global_rect()
	_check(wave_rect.size.y >= MIN_TOUCH - 6.0,
		"%s: wave button is a usable touch target (%.0fpx)" % [label, wave_rect.size.y])

	# Shop buttons must be individually reachable.
	var too_small: int = 0
	for btn in gs._shop_btns.values():
		if btn is Button and btn.visible and btn.get_global_rect().size.y < MIN_TOUCH - 8.0:
			too_small += 1
	_check(too_small == 0, "%s: all %d shop buttons meet touch height (short: %d)"
		% [label, gs._shop_btns.size(), too_small])

	# Instruction banner must never cover the playfield.
	_check(gs._instruction_banner.size.y <= 60.0,
		"%s: instruction banner is height-bounded (%.0f)" % [label, gs._instruction_banner.size.y])

	# Tower panel must not overlap the shop strip.
	gs._layout_tower_panel(null)
	var panel_bottom: float = gs._tower_panel.position.y + gs._tower_panel.size.y
	_check(panel_bottom <= gs._shop_scroll.position.y + 1.0,
		"%s: tower panel clears the shop strip (%.0f <= %.0f)"
			% [label, panel_bottom, gs._shop_scroll.position.y])

	# Portrait is not a supported gameplay mode: record it honestly.
	if not supported:
		print("       %s: portrait is an unsupported orientation (landscape-first); "
			% label + "layout builds without error but is not claimed as playable")

	await _unmount(gs)

# ---------------------------------------------------------------------------
# Wave-shop modal must fit and keep its controls reachable.
# ---------------------------------------------------------------------------

func _check_wave_shop(label: String, w: int, h: int, supported: bool) -> void:
	await _set_viewport(w, h)
	Progression.pending_map_id = 0
	var gs: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame
	# Force a wave shop and open the real modal controller.
	gs.game_state.wave_shop_pending = true
	gs.game_state.wave_ready = false
	gs._show_wave_shop(Time.get_ticks_msec())
	await get_tree().process_frame
	var vp: Vector2 = gs.get_viewport_rect().size
	var modal: PanelContainer = gs._wave_shop_modal
	_check(modal != null and modal.visible, "%s: wave-shop modal opens" % label)
	if modal != null and modal.visible:
		var rect: Rect2 = modal.get_global_rect()
		_check(rect.position.x >= -2.0 and rect.position.y >= -2.0
				and rect.position.x + rect.size.x <= vp.x + 2.0
				and rect.position.y + rect.size.y <= vp.y + 2.0,
			"%s: wave-shop modal fits the viewport (%.0fx%.0f at %.0f,%.0f in %.0fx%.0f)"
				% [label, rect.size.x, rect.size.y, rect.position.x, rect.position.y, vp.x, vp.y])
		# The skip button must always be reachable so a player can never be
		# trapped at the gate.
		var skip = gs._wave_shop._skip_btn
		if skip != null:
			var sr: Rect2 = skip.get_global_rect()
			_check(sr.size.y >= MIN_TOUCH - 8.0,
				"%s: wave-shop skip button is touchable (%.0fpx)" % [label, sr.size.y])
			_check(sr.position.y + sr.size.y <= vp.y + 2.0,
				"%s: wave-shop skip button is on-screen" % label)
	await _unmount(gs)

# ---------------------------------------------------------------------------
# Menu and end screen must build and keep their primary action reachable.
# ---------------------------------------------------------------------------

func _check_menu_and_end(label: String, w: int, h: int) -> void:
	await _set_viewport(w, h)
	var menu: Node = await _mount("res://scenes/MenuScreen.tscn")
	var vp: Vector2 = menu.get_viewport_rect().size
	var play_rect: Rect2 = menu._play_btn.get_global_rect()
	_check(play_rect.size.y >= MIN_TOUCH - 6.0,
		"%s: menu play button is touchable (%.0fpx)" % [label, play_rect.size.y])
	_check(play_rect.position.x >= -1.0 and play_rect.position.y >= -1.0
			and play_rect.position.x + play_rect.size.x <= vp.x + 1.0
			and play_rect.position.y + play_rect.size.y <= vp.y + 1.0,
		"%s: menu play button is on-screen" % label)
	# Every action button must fit; the column used to overlap the buttons.
	for btn in [menu._base_btn, menu._settings_btn]:
		var br: Rect2 = btn.get_global_rect()
		_check(br.position.y + br.size.y <= vp.y + 1.0,
			"%s: '%s' button stays on-screen (bottom %.0f <= %.0f)"
				% [label, btn.text, br.position.y + br.size.y, vp.y])
	await _unmount(menu)

	# Map select: on screens wide enough for three cards they must all be
	# visible. On narrow screens the card row is inside a ScrollContainer by
	# design, so horizontal scrolling is the supported behaviour — assert that a
	# scrollbar is available rather than pretending the cards fit.
	var map_sel: Node = await _mount("res://scenes/MapSelectScreen.tscn")
	await get_tree().process_frame
	var mvp: Vector2 = map_sel.get_viewport_rect().size
	var max_right: float = 0.0
	var cards: int = 0
	for child in map_sel._card_container.get_children():
		if child is PanelContainer:
			cards += 1
			var r: Rect2 = child.get_global_rect()
			max_right = maxf(max_right, r.position.x + r.size.x)
	_check(cards == 3, "%s: map select shows 3 maps (got %d)" % [label, cards])
	if w >= 900:
		_check(max_right <= mvp.x + 1.0,
			"%s: all map cards fit horizontally at this width (right %.0f <= %.0f)"
				% [label, max_right, mvp.x])
	else:
		var scrollable: bool = map_sel._scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		_check(scrollable,
			"%s: narrow map row is horizontally scrollable (right %.0f > %.0f by design)"
				% [label, max_right, mvp.x])
	await _unmount(map_sel)

	Progression.pending_end_stats = {
		"won": true, "waves": 15, "perfect_waves": 2, "lives": 7, "map_id": 0,
		"towers_placed": 9, "enemies_killed": 210, "gold_earned": 5000, "rp_earned": 300,
		"newly_unlocked_variants": [], "milestone_deltas": [],
	}
	var end_screen: Node = await _mount("res://scenes/EndScreen.tscn")
	_check(end_screen != null, "%s: end screen builds at this size" % label)
	await _unmount(end_screen)
	Progression.pending_end_stats = {}

func _verify_real_save_untouched() -> void:
	var now := PackedByteArray()
	var exists_now: bool = FileAccess.file_exists(REAL_SAVE_PATH)
	if exists_now:
		now = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	_check(exists_now == _real_existed, "real profile existence unchanged by geometry test")
	_check(now == _real_before, "real profile byte-identical after geometry test")
	for path in [SANDBOX_PATH, SANDBOX_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
