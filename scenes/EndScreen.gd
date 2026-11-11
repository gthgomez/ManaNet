extends Control
class_name EndScreen

# Port of screens/end.py — win / game-over screen with run stats.
# Stats are passed via Node metadata (set_meta) by GameScreen before instantiation.

const _MAPS_DATA := preload("res://data/maps.gd")
const _LAYOUT := preload("res://ui/layout/ResponsiveLayout.gd")
const _THEME := preload("res://ui/theme/GameTheme.gd")
const _BRAND := preload("res://ui/theme/BrandCopy.gd")
const _BACKDROP := preload("res://rendering/backdrop/TechBackdrop.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _title_lbl: Label     = $Panel/VBox/TitleLabel
@onready var _sub_lbl: Label       = $Panel/VBox/SubLabel
@onready var _stats_box: VBoxContainer = $Panel/VBox/StatsScroll/StatsBox
@onready var _retry_btn: Button    = $Panel/VBox/BtnRow/RetryBtn
@onready var _map_btn: Button      = $Panel/VBox/BtnRow/MapBtn
@onready var _menu_btn: Button     = $Panel/VBox/MenuBtn
var _reward_lbl: Label = null

func _ready() -> void:
	_add_backdrop()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_visuals()
	_apply_layout()
	_retry_btn.pressed.connect(_on_retry)
	_map_btn.pressed.connect(_on_change_map)
	_menu_btn.pressed.connect(_on_menu)

	# One tap from the result to spending Shards: motivation peaks here.
	var deck_btn := Button.new()
	deck_btn.text = "Cyber-Deck"
	deck_btn.custom_minimum_size = Vector2(150.0, _LAYOUT.TOUCH_HEIGHT)
	_THEME.apply_button(deck_btn, "secondary")
	deck_btn.pressed.connect(func(): _fade_to("res://scenes/CyberDeckScreen.tscn"))
	$Panel/VBox/BtnRow.add_child(deck_btn)

	# Dpad navigation: retry ↔ map_btn (horizontal), both → menu_btn (down)
	FocusManager.setup_dpad_neighbors([_retry_btn, _map_btn], false)
	FocusManager.set_neighbor(_retry_btn, "bottom", _menu_btn)
	FocusManager.set_neighbor(_map_btn,   "bottom", _menu_btn)
	FocusManager.set_neighbor(_menu_btn,  "top",    _retry_btn)
	FocusManager.register_initial_focus(_retry_btn)

	var stats: Dictionary = Progression.pending_end_stats
	var won: bool          = stats.get("won", get_meta("won", false))
	var rp_earned: int     = stats.get("rp_earned", get_meta("rp_earned", 0))
	var waves: int         = stats.get("waves", get_meta("waves", 0))
	var perfect_waves: int = stats.get("perfect_waves", get_meta("perfect_waves", 0))
	var lives: int         = stats.get("lives", get_meta("lives", 0))
	var map_id: int        = stats.get("map_id", get_meta("map_id", 0))
	var towers: int        = stats.get("towers_placed", get_meta("towers_placed", 0))
	var kills: int         = stats.get("enemies_killed", get_meta("enemies_killed", 0))
	var gold: int          = stats.get("gold_earned", get_meta("gold_earned", 0))

	var profile: Dictionary = Progression.load_profile()
	var banked_rp: int = profile.get("banked_rp", 0)
	var save_failed: bool = bool(stats.get("save_failed", false)) or Progression.has_pending_run()

	if won:
		_title_lbl.text = "VICTORY!"
		_title_lbl.add_theme_color_override("font_color", _THEME.GREEN)
	else:
		_title_lbl.text = "GAME OVER"
		_title_lbl.add_theme_color_override("font_color", _THEME.RED)

	var map_name: String = _MAPS_DATA.MAPS[map_id]["name"] if map_id < _MAPS_DATA.MAPS.size() else "Unknown"
	if save_failed:
		_sub_lbl.text = _BRAND.SAVE_FAILED_BODY
		_sub_lbl.add_theme_color_override("font_color", _THEME.GOLD)
		_add_retry_save_button()
	elif won:
		_sub_lbl.text = "All 15 waves cleared!  Map: %s" % map_name
		_sub_lbl.add_theme_color_override("font_color", _THEME.GREEN)
	else:
		_sub_lbl.text = "Survived %d of 15 waves  |  Map: %s" % [waves, map_name]

	if not save_failed:
		# Fixed reward line: visible even when the stats region scrolls on a
		# 320px-tall result screen.
		_reward_lbl = Label.new()
		_reward_lbl.text = _BRAND.end_stat_shards(rp_earned, banked_rp)
		_reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_reward_lbl.add_theme_color_override("font_color", _THEME.GOLD)
		_reward_lbl.add_theme_font_size_override("font_size", 13)
		$Panel/VBox.add_child(_reward_lbl)
		$Panel/VBox.move_child(_reward_lbl, _sub_lbl.get_index() + 1)

	_add_stat("Defenders Built",   str(towers),                         Color.WHITE)
	_add_stat("Intrusions Cleared", str(kills),                         Color.WHITE)
	_add_stat("%s Earned" % _BRAND.CURRENCY_RUN, str(gold),             Color(1.0, 0.82, 0.2))
	_add_stat("%s Remaining" % _BRAND.CORE_RESOURCE, str(lives),        Color.WHITE)
	_add_stat("Perfect Waves",     "%d / %d" % [perfect_waves, waves],  Color(0.2, 0.8, 1.0))
	if save_failed:
		_add_stat(_BRAND.CURRENCY_META, "Not saved", _THEME.GOLD)

	var newly_unlocked: Array = stats.get("newly_unlocked_variants", [])
	var milestone_deltas: Array = stats.get("milestone_deltas", [])

	if not newly_unlocked.is_empty():
		var sep1 := HSeparator.new()
		_stats_box.add_child(sep1)
		for variant_label in newly_unlocked:
			_add_stat("UNLOCKED", variant_label, _THEME.GOLD)

	if not milestone_deltas.is_empty():
		var sep2 := HSeparator.new()
		_stats_box.add_child(sep2)
		var prog_hdr := Label.new()
		prog_hdr.text = "TOWER PROGRESS"
		prog_hdr.add_theme_font_size_override("font_size", 13)
		prog_hdr.add_theme_color_override("font_color", _THEME.CYAN)
		_stats_box.add_child(prog_hdr)
		for delta in milestone_deltas:
			_add_milestone_row(delta)

	# Stats rows are built above; re-run layout so compact font sizes apply and
	# the scroll region is measured with real content.
	call_deferred("_apply_layout")

func _add_milestone_row(delta: Dictionary) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = str(delta.get("label", "?"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_THEME.apply_label(name_lbl, "muted")
	row.add_child(name_lbl)
	# Key contract mirrors Progression.record_run()'s milestone_deltas entries.
	var uses_now: int = delta.get("uses_now", 0)
	var kills_now: int = delta.get("kills_now", 0)
	var uses_max: int = maxi(1, delta.get("uses_max", 0))
	var kills_max: int = maxi(1, delta.get("kills_max", 0))
	var u_pct: int = mini(100, int(float(uses_now) / float(uses_max) * 100.0))
	var k_pct: int = mini(100, int(float(kills_now) / float(kills_max) * 100.0))
	var prog_text: String = "Place %d%%  Kill %d%%" % [u_pct, k_pct]
	var prog_lbl := Label.new()
	prog_lbl.text = prog_text
	_THEME.apply_label(prog_lbl, "body")
	prog_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	prog_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(prog_lbl)
	_stats_box.add_child(row)

func _add_backdrop() -> void:
	var backdrop := _BACKDROP.new()
	add_child(backdrop)
	move_child(backdrop, 1)

func _apply_visuals() -> void:
	_THEME.apply_panel(_panel, "modal")
	_THEME.apply_label(_title_lbl, "title")
	_THEME.apply_label(_sub_lbl, "muted")
	_THEME.apply_button(_retry_btn, "primary")
	_THEME.apply_button(_map_btn, "secondary")
	_THEME.apply_button(_menu_btn, "secondary")

func _apply_layout() -> void:
	var viewport: Vector2 = _LAYOUT.viewport_size(self)
	var compact: bool = viewport.y < 480.0 or viewport.x < 700.0
	var v_margin: float = maxf(_LAYOUT.top_margin(viewport), 20.0)
	var desired := Vector2(
		minf(600.0, viewport.x - _LAYOUT.edge_margin(viewport) * 2.0),
		minf(520.0, viewport.y - v_margin * 2.0)
	)
	var rect: Rect2 = _LAYOUT.modal_rect(viewport, desired)
	_LAYOUT.apply_modal(_panel, rect)
	_title_lbl.add_theme_font_size_override("font_size", 30 if compact else (50 if viewport.x >= 1050.0 else 44))
	_sub_lbl.add_theme_font_size_override("font_size", 12 if compact else 14)
	if _reward_lbl:
		_reward_lbl.add_theme_font_size_override("font_size", 11 if compact else 13)
	_retry_btn.custom_minimum_size = Vector2(150.0, _LAYOUT.TOUCH_HEIGHT)
	_map_btn.custom_minimum_size = Vector2(150.0, _LAYOUT.TOUCH_HEIGHT)
	_menu_btn.custom_minimum_size = Vector2(0.0, _LAYOUT.TOUCH_HEIGHT)
	_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font_size: int = 12 if compact else 14
	for child in _stats_box.get_children():
		if child is HBoxContainer:
			for lbl in child.get_children():
				if lbl is Label:
					lbl.add_theme_font_size_override("font_size", font_size)

func _add_stat(label: String, value: String, val_color: Color) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_THEME.apply_label(lbl, "muted")
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	_THEME.apply_label(val, "body")
	val.add_theme_color_override("font_color", val_color)
	row.add_child(val)
	_stats_box.add_child(row)

func _add_retry_save_button() -> void:
	var retry_save := Button.new()
	retry_save.name = "RetrySaveBtn"
	retry_save.text = _BRAND.SAVE_RETRY
	retry_save.custom_minimum_size = Vector2(150.0, _LAYOUT.TOUCH_HEIGHT)
	_THEME.apply_button(retry_save, "primary")
	retry_save.pressed.connect(_on_retry_save)
	$Panel/VBox.add_child(retry_save)
	$Panel/VBox.move_child(retry_save, _stats_box.get_index() + 1)

func _on_retry_save() -> void:
	var result: Dictionary = Progression.retry_pending_run()
	var retry_save := $Panel/VBox.get_node_or_null("RetrySaveBtn")
	if result.get("save_failed", true):
		_sub_lbl.text = "Still not saved. Your earlier profile is unchanged."
		return
	_sub_lbl.text = _BRAND.SAVE_OK
	_sub_lbl.add_theme_color_override("font_color", _THEME.GREEN)
	Progression.pending_end_stats["save_failed"] = false
	Progression.pending_end_stats["persisted"] = true
	if retry_save is Button:
		retry_save.text = _BRAND.SAVE_OK
		retry_save.disabled = true

func _on_retry() -> void:
	var map_id: int = Progression.pending_end_stats.get("map_id", get_meta("map_id", 0))
	Progression.pending_map_id = map_id
	_fade_to("res://scenes/GameScreen.tscn")

func _on_change_map() -> void:
	_fade_to("res://scenes/MapSelectScreen.tscn")

func _on_menu() -> void:
	_fade_to("res://scenes/MenuScreen.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu()
		get_viewport().set_input_as_handled()

func _fade_to(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): get_tree().change_scene_to_file(path))
