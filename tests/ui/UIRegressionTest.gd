extends Node

# Headless UI regression: executes the P0-fixed screen code paths with real
# data shapes. Run with:
#   godot --headless --path . res://tests/ui/UIRegressionTest.tscn
#
# Isolation contract (P0 player-save safety):
# - This harness never overwrites or deletes the real player profile at
#   user://td_progression.json.
# - tools/verify_game.py sets MANANET_PROFILE_PATH for this process, and as a
#   second line of defence _ready() redirects the live autoload to a scratch
#   profile before any screen is mounted.
# - At the end it asserts the real profile bytes are unchanged (read-only peek)
#   so a regression that reintroduces real-save writes fails loudly.
#
# Nothing here relies on restore-after-mutation: a hard kill mid-run can only
# ever leave the scratch file behind, never a damaged player profile.

const REAL_SAVE_PATH := "user://td_progression.json"
const SANDBOX_PATH := "user://td_progression.ui_harness.json"

var _pass: int = 0
var _fail: int = 0
var _real_save_before: PackedByteArray = PackedByteArray()
var _real_save_existed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	# Capture real-profile bytes read-only (never opened for writing anywhere).
	_real_save_existed = FileAccess.file_exists(REAL_SAVE_PATH)
	if _real_save_existed:
		_real_save_before = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	# Redirect the live autoload to the scratch profile before mounting screens.
	Progression.set_save_path(SANDBOX_PATH)
	Progression.load_profile()
	_run()

func _check(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % message)
	else:
		_fail += 1
		push_error("[FAIL] %s" % message)

func _run() -> void:
	print("--- UI REGRESSION CHECKS ---")
	await _test_end_screen_milestones()
	_prepare_sandbox_profile()
	await _test_menu_with_seeded_history()
	await _test_restart_with_clean_meta()
	_test_accessibility_settings()
	_verify_real_save_untouched()
	print("--- RESULTS ---")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _collect_labels(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		out += _collect_labels(child)
	if node is Label or node is RichTextLabel or node is Button:
		out += str(node.text) + "\n"
	return out

func _mount(scene_path: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene

func _unmount(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# 1) EndScreen — milestone contract (producer keys from Progression.record_run)
# ---------------------------------------------------------------------------

func _test_end_screen_milestones() -> void:
	Progression.pending_end_stats = {
		"won": false, "waves": 10, "perfect_waves": 3, "lives": 4,
		"map_id": 0, "towers_placed": 9, "enemies_killed": 88,
		"gold_earned": 4200, "rp_earned": 150,
		"newly_unlocked_variants": ["Veteran Archer"],
		"milestone_deltas": [{
			"label": "Permafrost Tower",
			"uses_now": 10, "uses_max": 12, "kills_now": 75, "kills_max": 150,
			"run_uses": 2, "run_kills": 20,
		}],
	}
	var screen: Node = await _mount("res://scenes/EndScreen.tscn")
	var text := _collect_labels(screen)
	_check(text.contains("GAME OVER"), "EndScreen renders loss title")
	_check(text.contains("UNLOCKED") and text.contains("Veteran Archer"),
		"newly-unlocked variant callout renders")
	_check(text.contains("TOWER PROGRESS"), "milestone section header renders")
	_check(text.contains("Permafrost Tower"), "milestone row renders producer 'label' key")
	_check(text.contains("Place 83%") and text.contains("Kill 50%"),
		"progress percentages computed from uses_now/uses_max + kills_now/kills_max")
	await _unmount(screen)
	Progression.pending_end_stats = {}

# ---------------------------------------------------------------------------
# Sandbox profile — write a seeded profile to the scratch path only
# ---------------------------------------------------------------------------

func _prepare_sandbox_profile() -> void:
	var zeros := {"archer": 0, "mage": 0, "cannon": 0, "sniper": 0, "frost": 0, "lightning": 0}
	var av := {"archer": "", "mage": "", "cannon": "", "sniper": "", "frost": "", "lightning": ""}
	var profile := {
		"version": 1, "engine": "godot", "total_rp": 120, "banked_rp": 120,
		"unlocked": [], "unlocked_variants": [],
		"tower_use_counts": zeros.duplicate(),
		"tower_kill_counts": zeros.duplicate(),
		"settings": {"confirm_restart": true},
		"active_starting_tower": "", "active_modifier": "", "active_modifier_2": "",
		"active_variants": av,
		# Last entry has map_id as float — the exact post-JSON round-trip shape
		# that used to be assigned into a String-typed local and error out.
		"run_history": [
			{"map_id": 1, "waves": 7, "perfect": 2, "lives": 3,
				"gold_earned": 3000, "gold_spent": 2400, "rp_earned": 90, "won": false},
			{"map_id": 2.0, "waves": 12, "perfect": 5, "lives": 6,
				"gold_earned": 6000, "gold_spent": 5200, "rp_earned": 160, "won": false},
		],
	}
	var f := FileAccess.open(SANDBOX_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile))
		f.close()
	Progression.load_profile()

func _verify_real_save_untouched() -> void:
	var now := PackedByteArray()
	var exists_now: bool = FileAccess.file_exists(REAL_SAVE_PATH)
	if exists_now:
		now = FileAccess.get_file_as_bytes(REAL_SAVE_PATH)
	_check(exists_now == _real_save_existed,
		"real player profile existence unchanged by harness")
	_check(now == _real_save_before, "real player profile byte-identical after harness run")
	# Clean up the scratch artifacts.
	for path in [SANDBOX_PATH, SANDBOX_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# ---------------------------------------------------------------------------
# 2) MenuScreen — run-history driven labels (int AND float map_id entries)
# ---------------------------------------------------------------------------

func _test_menu_with_seeded_history() -> void:
	var menu: Node = await _mount("res://scenes/MenuScreen.tscn")
	var text := _collect_labels(menu)
	_check(not text.is_empty(), "MenuScreen mounts and builds labels")
	_check(text.contains("Spiral"), "play-context resolves float map_id 2.0 to map name 'Spiral'")
	_check(text.contains("Last reached Wave 12"), "play-context shows last-run wave")
	_check(text.contains("Best: Wave 12"), "last-run label shows best wave")
	_check(text.contains("0W / 2L"), "win/loss tally renders from history")
	await _unmount(menu)

# ---------------------------------------------------------------------------
# 3) GameScreen — world-tap restart must rebuild through _restart_current_run
# ---------------------------------------------------------------------------

func _test_restart_with_clean_meta() -> void:
	Progression.pending_map_id = 0
	var gs: Node = await _mount("res://scenes/GameScreen.tscn")
	await get_tree().process_frame   # let the deferred layout pass run
	var vp: Vector2 = gs.get_viewport_rect().size
	# P0 geometry regressions: the instruction banner must never cover the field,
	# and the tower panel must fit above the shop strip.
	_check(gs._instruction_banner.size.y <= 60.0,
		"instruction banner height is bounded (got %.1f)" % gs._instruction_banner.size.y)
	_check(gs._instruction_banner.size.x <= vp.x,
		"instruction banner width fits viewport (got %.1f / %.1f)" % [gs._instruction_banner.size.x, vp.x])
	gs._layout_tower_panel(null)
	_check(gs._tower_panel.size.y <= 230.0,
		"tower panel stays within its reserved slot (got %.1f)" % gs._tower_panel.size.y)
	var panel_bottom: float = gs._tower_panel.position.y + gs._tower_panel.size.y
	_check(panel_bottom <= gs._shop_scroll.position.y + 1.0,
		"tower panel does not overlap the shop strip (%.1f <= %.1f)" % [panel_bottom, gs._shop_scroll.position.y])
	var old_state: GameState = gs.game_state
	old_state.gold = 9999
	old_state.lives = 3
	gs.view_state.confirm_restart = true
	var action: Dictionary = gs.input_ctrl.handle_press(Vector2(400, 300), Time.get_ticks_msec())
	_check(str(action.get("type")) == "restart_game",
		"confirmed world-tap emits restart_game action")
	gs._dispatch(action, Time.get_ticks_msec())
	await get_tree().process_frame
	_check(gs.game_state != old_state,
		"restart rebuilds GameState instance (not apply_action's in-place _init)")
	_check(gs.game_state.gold == 300, "credits reset to base after restart (got %d)" % gs.game_state.gold)
	_check(gs.game_state.lives == 10, "integrity reset to base after restart")
	_check(gs.view_state != null and gs.view_state.confirm_restart == false,
		"fresh ViewState created and confirm flag cleared")
	_check(gs._prev_lives == gs.game_state.lives and gs._prev_wave == gs.game_state.wave,
		"_prev_* edge trackers resynced after rebuild")
	# Draw-order regression: combat call-outs (damage numbers, KO, banners) must
	# render on the overlay layer, which must come AFTER every entity sprite pool
	# and the baked terrain, so text is never buried by enemies/towers/path.
	# (The selection ring and virtual cursor are added after it on purpose.)
	var overlay_idx: int = -1
	var last_sprite_idx: int = -1
	var children: Array = gs.renderer.get_children()
	for i in range(children.size()):
		var child = children[i]
		if child is MultiMeshInstance2D or child is SubViewport:
			last_sprite_idx = i
		if child is CanvasItem and str(child.name) == "Overlay":
			overlay_idx = i
	_check(overlay_idx >= 0, "renderer has an Overlay draw layer")
	_check(overlay_idx > last_sprite_idx,
		"Overlay paints after all sprite pools/terrain (overlay idx %d > last sprite idx %d)"
			% [overlay_idx, last_sprite_idx])
	_check(gs.renderer.TEXT_EFFECT_KINDS.has("dmg_num")
			and gs.renderer.TEXT_EFFECT_KINDS.has("banner"),
		"damage numbers and banners are classified as overlay text effects")
	await _unmount(gs)

# ---------------------------------------------------------------------------
# 4) Accessibility settings persist AND change runtime behavior (F4)
# ---------------------------------------------------------------------------

func _test_accessibility_settings() -> void:
	# Persistence: write through the isolated profile and read back from disk.
	var path := SANDBOX_PATH
	_check(Progression.set_setting("reduce_motion", true), "reduce_motion write persists")
	_check(Progression.set_setting("audio_muted", true), "audio_muted write persists")
	_check(Progression.set_setting("haptics_enabled", false), "haptics write persists")
	var reloaded = load("res://autoloads/Progression.gd").new()
	reloaded.initialize(path)
	var s: Dictionary = reloaded.get_settings()
	_check(s.get("reduce_motion") == true, "reduce_motion survives a profile reload")
	_check(s.get("audio_muted") == true, "audio_muted survives a profile reload")
	_check(s.get("haptics_enabled") == false, "haptics survives a profile reload")
	reloaded.free()

	# Runtime effect: reduce_motion must actually suppress screen shake.
	var vs = load("res://rendering/ViewState.gd").new()
	vs.configure_from_settings({"reduce_motion": true})
	vs.start_screen_shake(1000, 10.0, 500)
	_check(vs.get_screen_shake_offset(1050) == Vector2.ZERO,
		"reduce_motion suppresses screen shake entirely")
	vs.configure_from_settings({"reduce_motion": false})
	vs.start_screen_shake(2000, 10.0, 500)
	_check(vs.get_screen_shake_offset(2050) != Vector2.ZERO,
		"screen shake is active when reduce_motion is off")
	vs.free()

	# Audio/haptics: JuiceManager must reflect the muted/haptic settings.
	JuiceManager.configure_from_progression()
	_check(JuiceManager._sfx_enabled == false, "mute setting disables SFX playback")
	_check(JuiceManager._haptics_enabled == false, "haptics setting disables vibration")
	# Restore defaults so later checks are unaffected.
	Progression.reset_settings()
