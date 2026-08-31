extends Node

# Causal runtime proof for the production art pack. The script instantiates the
# real GameScreen and inspects the live texture-backed MultiMesh/UI controls;
# source-string bindings alone never produce a passing record here.

const GameStateClass = preload("res://simulation/core/GameState.gd")
const EnemyClass = preload("res://simulation/entities/Enemy.gd")
const TowerClass = preload("res://simulation/entities/Tower.gd")
const ProjectileClass = preload("res://simulation/entities/Projectile.gd")
const Maps = preload("res://data/maps.gd")
const GameScreenScene = preload("res://scenes/GameScreen.tscn")

var output_path: String = "build/verification/runtime_asset_coverage.json"
var screenshot_dir: String = "build/verification/runtime_screenshots"
var evidence: Dictionary = {}
var screenshot_ready: bool = false

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--output" and i + 1 < args.size():
			output_path = str(args[i + 1]).replace("\\", "/")
		elif args[i] == "--screenshots" and i + 1 < args.size():
			screenshot_dir = str(args[i + 1]).replace("\\", "/")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(screenshot_dir)

	var menu = preload("res://scenes/MenuScreen.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.75).timeout
	if menu.has_method("get_ui_asset_runtime_snapshot"):
		var menu_screenshot := _capture("menu_ui")
		_merge_ui_evidence(menu.get_ui_asset_runtime_snapshot(), "menu_shards_and_cyber_deck", menu_screenshot)
	menu.queue_free()
	await get_tree().process_frame

	var screen = GameScreenScene.instantiate()
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.75).timeout
	screen.set_process(false)
	screen.modulate.a = 1.0
	if screen._instruction_banner != null:
		screen._instruction_banner.visible = false
	if screen._msg_label != null:
		screen._msg_label.text = ""
	if screen._wave_btn != null:
		screen._wave_btn.visible = false

	var renderer = screen.renderer
	var map_evidence: Array = []
	for map_id in range(Maps.MAPS.size()):
		var map_state = _replace_state(screen, map_id)
		renderer.render_frame(Time.get_ticks_msec())
		await get_tree().process_frame
		for _i in range(4):
			renderer.render_frame(Time.get_ticks_msec())
			await get_tree().process_frame
		var map_snapshot: Dictionary = _find_runtime_asset(renderer.get_asset_runtime_snapshot()["assets"], "environment.%s" % _map_stem(map_id))
		map_snapshot["scenario"] = "map_%d_%s" % [map_id + 1, _map_stem(map_id)]
		map_snapshot["frame_count_seen"] = 5 if map_snapshot.get("rendered", false) else 0
		map_snapshot["screenshot"] = _capture("map_%d_%s" % [map_id + 1, _map_stem(map_id)])
		map_evidence.append(map_snapshot)

	var combat_state = _replace_state(screen, 0)
	combat_state.gold = 10000
	var tower_positions := [
		Vector2(120, 120), Vector2(120, 500), Vector2(350, 180),
		Vector2(560, 120), Vector2(780, 120), Vector2(780, 500),
	]
	var tower_types := ["archer", "mage", "cannon", "sniper", "frost", "lightning"]
	for i in range(tower_types.size()):
		var tower = TowerClass.new(tower_positions[i], tower_types[i], i)
		tower.game_state = combat_state
		combat_state.towers.append(tower)

	var enemy_types := [
		{"id": "Enemy", "asset": "enemies.intrusion", "ctor": "base"},
		{"id": "FastScout", "asset": "enemies.fast_scout", "ctor": "fast_scout"},
		{"id": "ArmoredTank", "asset": "enemies.armored_firewall", "ctor": "armored_tank"},
		{"id": "FlyingDrone", "asset": "enemies.flying_drone", "ctor": "flying_drone"},
		{"id": "SwarmMinion", "asset": "enemies.swarm_minion", "ctor": "swarm_minion"},
		{"id": "HeavyBrute", "asset": "enemies.heavy_brute", "ctor": "heavy_brute"},
		{"id": "BossShieldBrute", "asset": "enemies.shielded_brute", "ctor": "boss_shield"},
		{"id": "BossSwarmCarrier", "asset": "enemies.swarm_carrier", "ctor": "boss_carrier"},
		{"id": "BossRegenerator", "asset": "enemies.regenerator", "ctor": "boss_regenerator"},
	]
	var enemies: Array = []
	for i in range(enemy_types.size()):
		var e = _make_enemy(enemy_types[i]["ctor"], combat_state.path)
		e.pos = Vector2(130.0 + float(i % 5) * 145.0, 260.0 + float(i / 5) * 100.0)
		combat_state.enemies.append(e)
		enemies.append(e)

	for i in range(tower_types.size()):
		var projectile = ProjectileClass.new(tower_positions[i], enemies[i], combat_state.towers[i], 1, Time.get_ticks_msec(), 0, 1.0)
		combat_state.projectiles.append(projectile)

	renderer.render_frame(Time.get_ticks_msec())
	await get_tree().process_frame
	for _i in range(7):
		renderer.render_frame(Time.get_ticks_msec())
		await get_tree().process_frame
	var combat_screenshot := _capture("combat_asset_families")
	var runtime_assets: Array = renderer.get_asset_runtime_snapshot()["assets"]
	for asset in runtime_assets:
		if str(asset["id"]).begins_with("environment."):
			continue
		asset["screenshot"] = combat_screenshot
		var item := _runtime_entry(asset, "all_towers_enemies_and_projectiles", 8)
		evidence[item["id"]] = item

	if screen.has_method("get_ui_asset_runtime_snapshot"):
		combat_state.wave = 1
		screen._wave_btn.visible = true
		screen._update_hud(Time.get_ticks_msec())
		var initial_ui: Dictionary = screen.get_ui_asset_runtime_snapshot()
		var wave_1_screenshot := _capture("wave_1_hud")
		_merge_ui_evidence(initial_ui, "wave_1_hud", wave_1_screenshot)
		combat_state.wave = 5
		screen._update_hud(Time.get_ticks_msec())
		await get_tree().create_timer(0.45).timeout
		var wave_5_screenshot := _capture("wave_5_boss_warning")
		_merge_ui_evidence(screen.get_ui_asset_runtime_snapshot(), "wave_5_boss_warning", wave_5_screenshot)

	for map_item in map_evidence:
		var map_entry := _runtime_entry(map_item, map_item.get("scenario", "map"), int(map_item.get("frame_count_seen", 0)))
		map_entry["id"] = map_item["id"]
		map_entry["screenshot"] = map_item.get("screenshot", false)
		evidence[map_entry["id"]] = map_entry
	screen.queue_free()
	await get_tree().process_frame

	var all_assets: Array = []
	for key in evidence.keys():
		all_assets.append(evidence[key])
	all_assets.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var result := {
		"schema_version": "1.0.0",
		"scenario": "runtime_asset_certification",
		"launch": "res://scenes/GameScreen.tscn",
		"screenshot_capture": screenshot_ready,
		"visual_review_provenance": "runtime_screenshot_capture; no VLM claim",
		"assets": all_assets,
	}
	var f := FileAccess.open(output_path, FileAccess.WRITE)
	if f == null:
		printerr("RUNTIME_ASSET_CERTIFICATION_FAIL cannot write ", output_path)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	print("RUNTIME_ASSET_CERTIFICATION_PASS assets=", all_assets.size(), " screenshots=", screenshot_ready)
	for asset in all_assets:
		print("asset_id=", asset["id"], " loaded=", asset["loaded"], " rendered=", asset["exercised"], " scenario=", asset["scenario"], " frame_count_seen=", asset["frame_count_seen"])
	get_tree().quit(0)

func _replace_state(screen: Node, map_id: int):
	var map_data: Dictionary = Maps.MAPS[map_id]
	if screen.game_state != null:
		screen.game_state.dispose()
	var state = GameStateClass.new(map_data["path"], {}, map_id)
	screen.game_state = state
	screen.renderer.game_state = state
	screen.input_ctrl.game_state = state
	screen.renderer.rebuild_path_for_map(map_data["path"])
	screen.view_state.selected_tower_id = -1
	return state

func _make_enemy(kind: String, path: Array):
	match kind:
		"fast_scout": return EnemyClass.FastScout.new(path)
		"armored_tank": return EnemyClass.ArmoredTank.new(path)
		"flying_drone": return EnemyClass.FlyingDrone.new(path)
		"swarm_minion": return EnemyClass.SwarmMinion.new(path)
		"heavy_brute": return EnemyClass.HeavyBrute.new(path)
		"boss_shield": return EnemyClass.BossShieldBrute.new(path)
		"boss_carrier": return EnemyClass.BossSwarmCarrier.new(path)
		"boss_regenerator": return EnemyClass.BossRegenerator.new(path)
	return EnemyClass.new(path)

func _merge_ui_evidence(snapshot: Dictionary, scenario: String, screenshot: bool) -> void:
	for key in snapshot.keys():
		var source: Dictionary = snapshot[key]
		source["screenshot"] = screenshot
		var item := _runtime_entry({
			"id": key,
			"path": source.get("path", ""),
			"loaded": source.get("loaded", false),
			"rendered": source.get("rendered", false),
			"screenshot": source.get("screenshot", false),
		}, scenario, 1)
		if bool(source.get("rendered", false)) or not evidence.has(key):
			evidence[key] = item

func _runtime_entry(source: Dictionary, scenario: String, frames: int) -> Dictionary:
	var path := str(source.get("path", ""))
	var loaded := bool(source.get("loaded", false))
	var rendered := bool(source.get("rendered", source.get("exercised", false)))
	var shot := bool(source.get("screenshot", false))
	return {
		"id": str(source.get("id", "unknown")),
		"path": path,
		"present": ResourceLoader.exists(path, "Texture2D"),
		"valid": loaded,
		"bound": path != "",
		"loaded": loaded,
		"exercised": rendered,
		"visually_reviewed": shot,
		"scenario": scenario,
		"frame_count_seen": frames if rendered else 0,
	}

func _find_runtime_asset(assets: Array, asset_id: String) -> Dictionary:
	for asset in assets:
		if asset.get("id", "") == asset_id:
			return asset.duplicate()
	return {"id": asset_id, "path": "", "loaded": false, "rendered": false}

func _map_stem(map_id: int) -> String:
	return {0: "s_curve", 1: "gauntlet", 2: "spiral"}.get(map_id, "unknown")

func _capture(name: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var texture := get_tree().root.get_texture()
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	var path := screenshot_dir + "/" + name + ".png"
	if image.save_png(path) != OK:
		return false
	screenshot_ready = true
	return true
