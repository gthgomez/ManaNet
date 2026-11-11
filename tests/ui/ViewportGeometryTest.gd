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
const MIN_TOUCH: float = 48.0

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
	for vp in VIEWPORTS:
		if bool(vp[3]):
			await _check_settings_and_deck(vp[0], int(vp[1]), int(vp[2]))

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
	_check(wave_rect.size.y >= MIN_TOUCH - 1.0,
		"%s: wave button is a usable touch target (%.0fpx)" % [label, wave_rect.size.y])

	# Shop buttons must be individually reachable.
	var too_small: int = 0
	for btn in gs._shop_btns.values():
		if btn is Button and btn.is_visible_in_tree() and btn.get_global_rect().size.y < MIN_TOUCH - 1.0:
			too_small += 1
	_check(too_small == 0, "%s: all %d shop buttons meet touch height (short: %d)"
		% [label, gs._shop_btns.size(), too_small])

	# Instruction banner must never cover the playfield.
	_check(gs._instruction_banner.size.y <= 60.0,
		"%s: instruction banner is height-bounded (%.0f)" % [label, gs._instruction_banner.size.y])

	# A real selected tower must open a usable panel with touch-sized upgrade
	# controls. On short landscapes the panel is a bottom sheet by design and
	# may cover the shop strip; it must still fit the screen and be dismissible.
	gs.game_state.gold = 9999
	gs._dispatch({"type": "place_tower", "tower_type": "archer",
		"pos": Vector2(180, 250)}, Time.get_ticks_msec())
	await get_tree().process_frame
	_check(gs.game_state.towers.size() > 0, "%s: test tower placed" % label)
	if supported and gs.game_state.towers.size() > 0:
		gs.view_state.selected_tower_id = gs.game_state.towers[0].id
		await get_tree().process_frame
		await get_tree().process_frame
		gs._update_hud(Time.get_ticks_msec())
		_check(gs._tower_panel.visible, "%s: tower panel opens for a selected tower" % label)
		var panel_rect: Rect2 = gs._tower_panel.get_global_rect()
		_check(panel_rect.position.x >= -1.0 and panel_rect.position.y >= -1.0
				and panel_rect.position.x + panel_rect.size.x <= vp.x + 1.0
				and panel_rect.position.y + panel_rect.size.y <= vp.y + 1.0,
			"%s: tower panel fits the viewport (%.0fx%.0f at %.0f,%.0f)"
				% [label, panel_rect.size.x, panel_rect.size.y,
					panel_rect.position.x, panel_rect.position.y])
		if h >= 430:
			_check(not panel_rect.intersects(Rect2(gs._wave_btn.position, gs._wave_btn.size)),
				"%s: tower panel never covers the wave button" % label)
			_check(not panel_rect.intersects(Rect2(gs._shop_scroll.position, gs._shop_scroll.size)),
				"%s: tower panel never covers the shop strip" % label)
		for btn in [gs._base_upg_btn, gs._sell_btn, gs._target_btn]:
			_check(btn.get_global_rect().size.y >= MIN_TOUCH - 1.0,
				"%s: tower panel control '%s' is touch-sized (%.0fpx)"
					% [label, btn.text, btn.get_global_rect().size.y])
			gs._tower_panel_scroll.ensure_control_visible(btn)
			await get_tree().process_frame
			var sr: Rect2 = gs._tower_panel_scroll.get_global_rect()
			var br: Rect2 = btn.get_global_rect()
			_check(btn.is_visible_in_tree() and br.position.y >= sr.position.y - 1.0
					and br.position.y + br.size.y <= sr.position.y + sr.size.y + 1.0,
				"%s: tower panel control '%s' is reachable after scrolling"
					% [label, btn.text])
		var close_rect: Rect2 = gs._close_panel_btn.get_global_rect()
		_check(gs._close_panel_btn.is_visible_in_tree() and close_rect.position.y >= 0.0
				and close_rect.position.y + close_rect.size.y <= vp.y + 1.0,
			"%s: tower panel has an on-screen close control" % label)
		if h >= 430:
			var panel_bottom: float = panel_rect.position.y + panel_rect.size.y
			_check(panel_bottom <= gs._shop_scroll.position.y + 1.0,
				"%s: tower panel clears the shop strip (%.0f <= %.0f)"
					% [label, panel_bottom, gs._shop_scroll.position.y])
		# Exercise the opposite vertical branch: select a tower in the lower
		# half and confirm the panel still avoids the wave/shop controls.
		gs.game_state.gold = 9999
		gs._dispatch({"type": "place_tower", "tower_type": "archer",
			"pos": Vector2(700, 500)}, Time.get_ticks_msec())
		await get_tree().process_frame
		var lower = gs.game_state.towers[-1]
		gs.view_state.selected_tower_id = lower.id
		await get_tree().process_frame
		await get_tree().process_frame
		gs._update_hud(Time.get_ticks_msec())
		var low_rect: Rect2 = gs._tower_panel.get_global_rect()
		_check(low_rect.position.x >= -1.0 and low_rect.position.y >= -1.0
				and low_rect.position.x + low_rect.size.x <= vp.x + 1.0
				and low_rect.position.y + low_rect.size.y <= vp.y + 1.0,
			"%s: lower-half tower panel stays on-screen" % label)
		if h >= 430:
			_check(not low_rect.intersects(Rect2(gs._wave_btn.position, gs._wave_btn.size))
					and not low_rect.intersects(Rect2(gs._shop_scroll.position, gs._shop_scroll.size)),
				"%s: lower-half tower panel avoids wave and shop controls" % label)

	# Portrait is not a supported gameplay mode: record it honestly.
	if not supported:
		print("       %s: portrait is an unsupported orientation (landscape-first); "
			% label + "layout builds without error but is not claimed as playable")

	# Pause / restart / quit must be reachable from a real paused run.
	gs.game_state.paused = true
	await get_tree().process_frame
	gs._update_hud(Time.get_ticks_msec())
	_check(gs._pause_modal.visible, "%s: pause modal opens" % label)
	if supported:
		var pause_rect: Rect2 = gs._pause_modal.get_global_rect()
		_check(pause_rect.position.x >= -1.0 and pause_rect.position.y >= -1.0
				and pause_rect.position.x + pause_rect.size.x <= vp.x + 1.0
				and pause_rect.position.y + pause_rect.size.y <= vp.y + 1.0,
			"%s: pause modal fits the viewport (%.0fx%.0f at %.0f,%.0f)"
				% [label, pause_rect.size.x, pause_rect.size.y, pause_rect.position.x, pause_rect.position.y])
	_check(gs._pause_body.size.x >= 220.0,
		"%s: pause body is wide enough for readable text (%.0fpx)" % [label, gs._pause_body.size.x])
	var pause_scroll: ScrollContainer = gs._pause_body.get_parent()
	for btn in [gs._resume_btn, gs._restart_btn, gs._quit_btn,
			gs._placement_mode_btn, gs._placement_confirm_toggle_btn]:
		_check(btn.get_global_rect().size.y >= MIN_TOUCH - 1.0,
			"%s: pause control '%s' is touch-sized (%.0fpx)"
				% [label, btn.text, btn.get_global_rect().size.y])
		pause_scroll.ensure_control_visible(btn)
		await get_tree().process_frame
		var pr: Rect2 = btn.get_global_rect()
		var ps: Rect2 = pause_scroll.get_global_rect()
		_check(btn.is_visible_in_tree() and pr.position.y >= ps.position.y - 1.0
				and pr.position.y + pr.size.y <= ps.position.y + ps.size.y + 1.0,
			"%s: pause control '%s' is reachable after scrolling"
				% [label, btn.text])
	gs.game_state.paused = false
	await get_tree().process_frame

	await _unmount(gs)

# ---------------------------------------------------------------------------
# Settings and Cyber-Deck controls must stay on-screen and touch-sized.
# ---------------------------------------------------------------------------

func _find_buttons(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_find_buttons(child, out)
	return out

func _check_settings_and_deck(label: String, w: int, h: int) -> void:
	await _set_viewport(w, h)
	var settings: Node = await _mount("res://scenes/SettingsScreen.tscn")
	await get_tree().process_frame
	var svp: Vector2 = settings.get_viewport_rect().size
	var s_buttons: Array = _find_buttons(settings, [])
	var small_setts: Array = []
	for b in s_buttons:
		if b.is_visible_in_tree() and b.get_global_rect().size.y < MIN_TOUCH - 1.0:
			small_setts.append("%s:%.0f" % [b.text, b.get_global_rect().size.y])
	_check(small_setts.is_empty(), "%s: every settings control is touch-sized%s"
		% [label, "" if small_setts.is_empty() else " (short: %s)" % str(small_setts)])
	var settings_offscreen: Array = []
	for b in s_buttons:
		if not b.is_visible_in_tree():
			continue
		if settings._scroll.is_ancestor_of(b):
			settings._scroll.ensure_control_visible(b)
			await get_tree().process_frame
		var sr: Rect2 = b.get_global_rect()
		if sr.position.y < -1.0 or sr.position.y + sr.size.y > svp.y + 1.0 \
				or sr.position.x < -1.0 or sr.position.x + sr.size.x > svp.x + 1.0:
			settings_offscreen.append(b.text)
	_check(settings_offscreen.is_empty(), "%s: every settings control is reachable by scrolling%s"
		% [label, "" if settings_offscreen.is_empty() else " (off: %s)" % str(settings_offscreen)])
	var reset_btn: Button = null
	for b in s_buttons:
		if b.text == "Reset Settings":
			reset_btn = b
	if reset_btn != null:
		settings._scroll.ensure_control_visible(reset_btn)
		await get_tree().process_frame
		await get_tree().process_frame
		var rr: Rect2 = reset_btn.get_global_rect()
		_check(rr.position.y >= -1.0 and rr.position.y + rr.size.y <= svp.y + 1.0
				and rr.position.x >= -1.0 and rr.position.x + rr.size.x <= svp.x + 1.0,
			"%s: Reset Settings is reachable after scrolling" % label)
	await _unmount(settings)

	var deck: Node = await _mount("res://scenes/CyberDeckScreen.tscn")
	await get_tree().process_frame
	var dvp: Vector2 = deck.get_viewport_rect().size
	var d_buttons: Array = _find_buttons(deck, [])
	var small_deck: Array = []
	for b in d_buttons:
		if b.is_visible_in_tree() and b.get_global_rect().size.y < MIN_TOUCH - 1.0:
			small_deck.append("%s:%.0f" % [b.text, b.get_global_rect().size.y])
	_check(small_deck.is_empty(), "%s: every Cyber-Deck control is touch-sized%s"
		% [label, "" if small_deck.is_empty() else " (short: %s)" % str(small_deck)])
	var offscreen: Array = []
	for b in d_buttons:
		if not b.is_visible_in_tree():
			continue
		if deck._scroll.is_ancestor_of(b):
			deck._scroll.ensure_control_visible(b)
			await get_tree().process_frame
		var br: Rect2 = b.get_global_rect()
		if br.position.y < -1.0 or br.position.y + br.size.y > dvp.y + 1.0 \
				or br.position.x < -1.0 or br.position.x + br.size.x > dvp.x + 1.0:
			offscreen.append(b.text)
	_check(offscreen.is_empty(), "%s: every Cyber-Deck control is reachable by scrolling%s"
		% [label, "" if offscreen.is_empty() else " (off: %s)" % str(offscreen)])
	deck._show_tab("variants")
	await get_tree().process_frame
	var v_buttons: Array = _find_buttons(deck, [])
	var small_v: Array = []
	for b in v_buttons:
		if b.is_visible_in_tree() and b.get_global_rect().size.y < MIN_TOUCH - 1.0:
			small_v.append("%s:%.0f" % [b.text, b.get_global_rect().size.y])
	_check(small_v.is_empty(), "%s: every variant control is touch-sized%s"
		% [label, "" if small_v.is_empty() else " (short: %s)" % str(small_v)])
	await _unmount(deck)

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
			_check(sr.size.y >= MIN_TOUCH - 1.0,
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
	_check(play_rect.size.y >= MIN_TOUCH - 1.0,
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
	var cards: int = 0
	for child in map_sel._card_container.get_children():
		if child is PanelContainer:
			cards += 1
			var r: Rect2 = child.get_global_rect()
	_check(cards == 3, "%s: map select shows 3 maps (got %d)" % [label, cards])
	# Every Play button must be reachable at every supported landscape size.
	# Scrolling horizontally is acceptable; clipping the primary action is not.
	var plays_reachable: bool = true
	var play_offenders: Array = []
	for i in map_sel._play_btns.size():
		var play_btn: Button = map_sel._play_btns[i]
		var pr: Rect2 = play_btn.get_global_rect()
		if pr.position.x < -1.0 or pr.position.x + pr.size.x > mvp.x + 1.0:
			# Scroll the row to bring this button fully into view.
			var card: Control = map_sel._card_container.get_child(i)
			map_sel._scroll.scroll_horizontal = int(maxf(0.0, card.position.x))
			await get_tree().process_frame
			pr = play_btn.get_global_rect()
		if pr.position.y < -1.0 or pr.position.y + pr.size.y > mvp.y + 1.0 \
				or pr.position.x < -1.0 or pr.position.x + pr.size.x > mvp.x + 1.0:
			plays_reachable = false
			play_offenders.append("card %d play @ %.0f,%.0f %.0fx%.0f"
				% [i, pr.position.x, pr.position.y, pr.size.x, pr.size.y])
		if pr.size.y < MIN_TOUCH - 1.0:
			plays_reachable = false
			play_offenders.append("card %d play height %.0f" % [i, pr.size.y])
	_check(plays_reachable, "%s: every map Play button is visible and touch-sized%s"
		% [label, "" if play_offenders.is_empty() else " (offenders: %s)" % str(play_offenders)])
	await _unmount(map_sel)

	Progression.pending_end_stats = {
		"won": true, "waves": 15, "perfect_waves": 2, "lives": 7, "map_id": 0,
		"towers_placed": 9, "enemies_killed": 210, "gold_earned": 5000, "rp_earned": 300,
		"newly_unlocked_variants": [], "milestone_deltas": [],
	}
	var end_screen: Node = await _mount("res://scenes/EndScreen.tscn")
	_check(end_screen != null, "%s: end screen builds at this size" % label)
	if end_screen != null and w > h:
		var evp: Vector2 = end_screen.get_viewport_rect().size
		var actions: Array = [end_screen._retry_btn, end_screen._map_btn, end_screen._menu_btn]
		for b in end_screen.get_node("Panel/VBox/BtnRow").get_children():
			if b is Button:
				actions.append(b)
		var off: Array = []
		for btn in actions:
			var br: Rect2 = btn.get_global_rect()
			if br.position.y < -1.0 or br.position.y + br.size.y > evp.y + 1.0 \
					or br.position.x < -1.0 or br.position.x + br.size.x > evp.x + 1.0 \
					or br.size.y < MIN_TOUCH - 1.0:
				off.append("%s @ %.0f,%.0f %.0fx%.0f" % [btn.text, br.position.x,
					br.position.y, br.size.x, br.size.y])
		_check(off.is_empty(), "%s: every end-screen action is reachable%s"
			% [label, "" if off.is_empty() else " (offenders: %s)" % str(off)])
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
