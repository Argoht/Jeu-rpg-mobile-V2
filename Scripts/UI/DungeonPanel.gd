extends PanelContainer

const MAX_DUNGEON_FLOOR = 100

var _background_rect: TextureRect
var _scene_frame: PanelContainer
var _scene_content: Control
var _ambience_popup: PanelContainer
var _ambience_label: Label
var _ambience_timer: Timer
var _current_background_path = ""
var _current_background_stage = -1
var _background_aspect = 4.0 / 3.0
var _rank_select: OptionButton
var _title_label: Label
var _status_label: Label
var _checkpoint_label: Label
var _enemy_label: Label
var _enemy_hp_bar: ProgressBar
var _energy_label: Label
var _energy_bar: ProgressBar
var _log_label: Label
var _event_title_label: Label
var _event_text_label: Label
var _choice_box: VBoxContainer
var _start_button: Button
var _forfeit_button: Button
var _auto_button: Button
var _special_button: Button
var _heal_button: Button
var _shield_button: Button
var _next_button: Button

func _ready() -> void:
	name = "DonjonPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build()

	if GlobalEngine.has_signal("dungeon_changed"):
		GlobalEngine.dungeon_changed.connect(_refresh)
	GlobalEngine.stats_updated.connect(_refresh)
	call_deferred("_refresh")

func _build() -> void:
	var margin = MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	_title_label = Label.new()
	_title_label.text = "DONJON"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("#00f2ff"))
	title_box.add_child(_title_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_box.add_child(_status_label)

	_rank_select = OptionButton.new()
	_rank_select.custom_minimum_size = Vector2(86, 0)
	_rank_select.item_selected.connect(_on_rank_selected)
	header.add_child(_rank_select)

	_checkpoint_label = Label.new()
	_checkpoint_label.add_theme_font_size_override("font_size", 12)
	_checkpoint_label.add_theme_color_override("font_color", Color("#ffd166"))
	_checkpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_checkpoint_label)

	_scene_frame = PanelContainer.new()
	_scene_frame.custom_minimum_size = Vector2(0, 370)
	_scene_frame.clip_contents = true
	_scene_frame.add_theme_stylebox_override("panel", _scene_frame_style())
	root.add_child(_scene_frame)

	_scene_content = Control.new()
	_scene_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene_frame.add_child(_scene_content)

	_background_rect = TextureRect.new()
	_background_rect.custom_minimum_size = Vector2(0, 370)
	_background_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_background_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_background_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scene_content.add_child(_background_rect)
	_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_rect.offset_left = 0
	_background_rect.offset_top = 0
	_background_rect.offset_right = 0
	_background_rect.offset_bottom = 0
	_scene_frame.resized.connect(_update_background_frame_size)

	_build_ambience_popup()

	root.add_child(_make_separator())

	var enemy_box = VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 4)
	root.add_child(enemy_box)

	_enemy_label = Label.new()
	_enemy_label.add_theme_font_size_override("font_size", 14)
	_enemy_label.add_theme_color_override("font_color", Color("#f5f7fb"))
	_enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	enemy_box.add_child(_enemy_label)

	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(0, 18)
	_enemy_hp_bar.show_percentage = false
	enemy_box.add_child(_enemy_hp_bar)

	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(0, 18)
	_energy_bar.max_value = 100
	_energy_bar.show_percentage = false

	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", 12)
	_energy_label.add_theme_color_override("font_color", Color("#8be9fd"))
	root.add_child(_energy_label)
	root.add_child(_energy_bar)

	_log_label = Label.new()
	_log_label.custom_minimum_size = Vector2(0, 104)
	_log_label.add_theme_stylebox_override("normal", _log_style())
	_log_label.add_theme_font_size_override("font_size", 12)
	_log_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	root.add_child(_log_label)

	var event_panel = VBoxContainer.new()
	event_panel.add_theme_constant_override("separation", 6)
	root.add_child(event_panel)

	_event_title_label = Label.new()
	_event_title_label.add_theme_font_size_override("font_size", 15)
	_event_title_label.add_theme_color_override("font_color", Color("#ffd166"))
	event_panel.add_child(_event_title_label)

	_event_text_label = Label.new()
	_event_text_label.add_theme_font_size_override("font_size", 12)
	_event_text_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9))
	_event_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_panel.add_child(_event_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	event_panel.add_child(_choice_box)

	var combat_grid = GridContainer.new()
	combat_grid.columns = 2
	combat_grid.add_theme_constant_override("h_separation", 8)
	combat_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(combat_grid)

	_auto_button = _make_button("Echange auto")
	_auto_button.pressed.connect(_on_auto_pressed)
	combat_grid.add_child(_auto_button)

	_special_button = _make_button("Attaque speciale")
	_special_button.pressed.connect(_on_special_pressed)
	combat_grid.add_child(_special_button)

	_heal_button = _make_button("Soin")
	_heal_button.pressed.connect(_on_heal_pressed)
	combat_grid.add_child(_heal_button)

	_shield_button = _make_button("Bouclier")
	_shield_button.pressed.connect(_on_shield_pressed)
	combat_grid.add_child(_shield_button)

	_next_button = _make_button("Monter a l'etage suivant")
	_next_button.pressed.connect(_on_next_pressed)
	root.add_child(_next_button)

	_start_button = _make_button("Entrer")
	_start_button.pressed.connect(_on_start_pressed)
	root.add_child(_start_button)

	_forfeit_button = _make_button("Sortir du donjon")
	_forfeit_button.pressed.connect(_on_forfeit_pressed)
	root.add_child(_forfeit_button)

func _refresh() -> void:
	if not is_instance_valid(GlobalEngine) or GlobalEngine.dungeon_system == null:
		return

	var player_rank: String = GlobalEngine.get_rank_by_level(GlobalEngine.lvl)
	var state = GlobalEngine.dungeon_system.get_view_state(player_rank)
	_sync_rank_select(state.get("available_ranks", []), String(state.get("active_rank", player_rank)))

	var selected_rank = _selected_rank(player_rank)
	var rank_for_display = selected_rank
	if bool(state.get("in_run", false)):
		rank_for_display = String(state.get("active_rank", selected_rank))
	var dungeon_name = GlobalEngine.dungeon_system.get_dungeon_name(rank_for_display)
	var display_floor = int(state.get("current_floor", 1))
	var background_stage = GlobalEngine.dungeon_system.get_dungeon_background_stage(display_floor)
	var background_path = GlobalEngine.dungeon_system.get_dungeon_background_path(rank_for_display, display_floor)
	var phase = String(state.get("phase", "idle"))

	_refresh_background(background_path, background_stage, bool(state.get("in_run", false)))
	_title_label.text = "%s - Rang %s" % [dungeon_name.to_upper(), rank_for_display]
	_status_label.text = _status_text(state, rank_for_display)
	_checkpoint_label.text = _checkpoint_text(state, rank_for_display)
	_refresh_enemy(state)
	_refresh_energy(state)
	_refresh_log(state)
	_refresh_event(state)
	_refresh_buttons(state, selected_rank, phase)

func _sync_rank_select(ranks: Array, preferred_rank: String) -> void:
	var old_rank = _selected_rank(preferred_rank)
	_rank_select.clear()
	for rank in ranks:
		_rank_select.add_item(String(rank))
	if _rank_select.item_count == 0:
		_rank_select.add_item(preferred_rank)

	var target = preferred_rank
	if ranks.has(old_rank):
		target = old_rank
	for i in range(_rank_select.item_count):
		if _rank_select.get_item_text(i) == target:
			_rank_select.select(i)
			return
	_rank_select.select(0)

func _selected_rank(fallback: String) -> String:
	if _rank_select == null or _rank_select.item_count == 0:
		return fallback
	return _rank_select.get_item_text(_rank_select.selected)

func _status_text(state: Dictionary, rank: String) -> String:
	if bool(state.get("in_run", false)):
		return "Etage %d / %d - %s" % [int(state.get("current_floor", 1)), MAX_DUNGEON_FLOOR, _phase_label(String(state.get("phase", "idle")))]
	if String(state.get("phase", "idle")) == "dead":
		return "Expulse du donjon. Recuperation requise avant une nouvelle tentative."
	if String(state.get("phase", "idle")) == "completed":
		return "Donjon termine. Tu peux recommencer depuis le dernier checkpoint."
	return "Cout d'entree: %d END. Le donjon utilise ton rang actuel et tes stats." % GlobalEngine.dungeon_system.get_entry_cost(rank)

func _checkpoint_text(state: Dictionary, rank: String) -> String:
	var checkpoints = state.get("checkpoints", {})
	var bests = state.get("best_floors", {})
	var checkpoint = int(checkpoints.get(rank, 1))
	var best = int(bests.get(rank, 1))
	return "Checkpoint: etage %d | Meilleur etage: %d | HP %d/%d | END %d/%d" % [
		checkpoint,
		best,
		GlobalEngine.hp,
		GlobalEngine.max_hp,
		GlobalEngine.end,
		GlobalEngine.max_end,
	]

func _refresh_enemy(state: Dictionary) -> void:
	var enemy = state.get("enemy", {})
	if enemy.is_empty():
		_enemy_label.text = "Aucun ennemi."
		_enemy_hp_bar.value = 0
		_enemy_hp_bar.max_value = 1
		return

	_enemy_label.text = "%s [%s]  HP %d/%d  ATK %d  DEF %d  SPD %d" % [
		enemy.get("name", "Ennemi"),
		enemy.get("type", "?"),
		int(enemy.get("hp", 0)),
		int(enemy.get("max_hp", 1)),
		int(enemy.get("atk", 0)),
		int(enemy.get("def", 0)),
		int(enemy.get("spd", 0)),
	]
	_enemy_hp_bar.max_value = int(enemy.get("max_hp", 1))
	_enemy_hp_bar.value = int(enemy.get("hp", 0))

func _refresh_energy(state: Dictionary) -> void:
	var shield_turns = int(state.get("shield_turns", 0))
	var energy = int(state.get("player_energy", 0))
	_energy_label.text = "Energie: %d / 100" % energy
	_energy_bar.value = energy
	_energy_bar.tooltip_text = "Energie de combat"
	if shield_turns > 0:
		_energy_bar.tooltip_text = "Energie de combat - Bouclier %d" % shield_turns

func _refresh_background(path: String, stage: int, in_run: bool) -> void:
	if _background_rect == null:
		return
	var previous_stage = _current_background_stage
	if path == _current_background_path and stage == _current_background_stage:
		return

	_current_background_path = path
	_current_background_stage = stage
	_background_rect.texture = _load_texture_from_path(path)
	_background_rect.visible = _background_rect.texture != null
	if _background_rect.texture != null:
		var texture_size = _background_rect.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			_background_aspect = texture_size.x / texture_size.y
	_update_background_frame_size()
	if in_run and previous_stage >= 0 and stage > previous_stage:
		_show_ambience_popup(GlobalEngine.dungeon_system.get_ambience_message(stage))

func _update_background_frame_size() -> void:
	if _scene_frame == null or _background_rect == null:
		return

	var frame_width = _scene_frame.size.x
	if frame_width <= 1.0:
		frame_width = maxf(1.0, size.x - 24.0)
	var frame_height = clampf(frame_width / _background_aspect, 260.0, 520.0)
	_scene_frame.custom_minimum_size.y = frame_height
	_background_rect.custom_minimum_size.y = frame_height

func _build_ambience_popup() -> void:
	_ambience_popup = PanelContainer.new()
	_ambience_popup.visible = false
	_ambience_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambience_popup.add_theme_stylebox_override("panel", _ambience_popup_style())
	_scene_content.add_child(_ambience_popup)
	_ambience_popup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ambience_popup.offset_left = 18
	_ambience_popup.offset_top = 14
	_ambience_popup.offset_right = -18
	_ambience_popup.offset_bottom = 58

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	_ambience_popup.add_child(margin)

	_ambience_label = Label.new()
	_ambience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambience_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ambience_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ambience_label.add_theme_font_size_override("font_size", 12)
	_ambience_label.add_theme_color_override("font_color", Color("#e7fbff"))
	margin.add_child(_ambience_label)

	_ambience_timer = Timer.new()
	_ambience_timer.one_shot = true
	_ambience_timer.wait_time = 3.2
	_ambience_timer.timeout.connect(_hide_ambience_popup)
	add_child(_ambience_timer)

func _show_ambience_popup(text: String) -> void:
	if _ambience_popup == null or _ambience_label == null:
		return
	_ambience_label.text = text
	_ambience_popup.show()
	if _ambience_timer != null:
		_ambience_timer.start()

func _hide_ambience_popup() -> void:
	if _ambience_popup != null:
		_ambience_popup.hide()

func _refresh_log(state: Dictionary) -> void:
	var lines = state.get("log", [])
	var text = ""
	for line in lines:
		text += String(line) + "\n"
	_log_label.text = text.strip_edges()

func _refresh_event(state: Dictionary) -> void:
	for child in _choice_box.get_children():
		child.queue_free()

	var event = state.get("event", {})
	if String(state.get("phase", "")) != "event" or event.is_empty():
		_event_title_label.hide()
		_event_text_label.hide()
		return

	_event_title_label.text = String(event.get("title", "Evenement"))
	_event_text_label.text = String(event.get("text", ""))
	_event_title_label.show()
	_event_text_label.show()

	var choices = event.get("choices", [])
	for i in range(choices.size()):
		var button = _make_button(String(choices[i]))
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choice_box.add_child(button)

func _refresh_buttons(state: Dictionary, selected_rank: String, phase: String) -> void:
	var in_run = bool(state.get("in_run", false))
	var energy = int(state.get("player_energy", 0))
	var is_combat = phase == "combat"
	var is_event = phase == "event"
	var is_clear = phase == "floor_cleared"

	_rank_select.disabled = in_run
	_start_button.visible = not in_run
	_start_button.text = "Entrer (%d END)" % GlobalEngine.dungeon_system.get_entry_cost(selected_rank)
	_start_button.disabled = (not GlobalEngine.is_debug_invincible() and GlobalEngine.end < GlobalEngine.dungeon_system.get_entry_cost(selected_rank)) or GlobalEngine.hp <= 0

	_forfeit_button.visible = in_run
	_auto_button.visible = is_combat
	_special_button.visible = is_combat
	_heal_button.visible = is_combat
	_shield_button.visible = is_combat
	_next_button.visible = is_clear

	_auto_button.disabled = not is_combat
	_special_button.disabled = energy < 50
	_heal_button.disabled = energy < 45
	_shield_button.disabled = energy < 35
	_next_button.disabled = not is_clear or is_event

	_special_button.text = "Attaque speciale (50)"
	_heal_button.text = "Soin (45)"
	_shield_button.text = "Bouclier (35)"

func _phase_label(phase: String) -> String:
	match phase:
		"combat":
			return "Combat"
		"event":
			return "Evenement"
		"floor_cleared":
			return "Etage nettoye"
		"dead":
			return "Defaite"
		"completed":
			return "Termine"
	return "Repos"

func _on_start_pressed() -> void:
	GlobalEngine.start_dungeon(_selected_rank(GlobalEngine.get_rank_by_level(GlobalEngine.lvl)))
	_refresh()

func _on_rank_selected(_index: int) -> void:
	_refresh()

func _on_forfeit_pressed() -> void:
	GlobalEngine.forfeit_dungeon()
	_refresh()

func _on_auto_pressed() -> void:
	GlobalEngine.dungeon_auto_exchange()
	_refresh()

func _on_special_pressed() -> void:
	GlobalEngine.dungeon_use_skill("special")
	_refresh()

func _on_heal_pressed() -> void:
	GlobalEngine.dungeon_use_skill("heal")
	_refresh()

func _on_shield_pressed() -> void:
	GlobalEngine.dungeon_use_skill("shield")
	_refresh()

func _on_next_pressed() -> void:
	GlobalEngine.dungeon_advance_floor()
	_refresh()

func _on_choice_pressed(choice_index: int) -> void:
	GlobalEngine.dungeon_choose_event(choice_index)
	_refresh()

func _make_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _button_style())
	return button

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.12, 0.18, 0.24))
	return sep

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.047, 0.059, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.149, 0.173, 0.212, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _log_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	style.bg_color = Color(0.025, 0.033, 0.045, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.35)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	style.bg_color = Color(0.05, 0.10, 0.16, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0, 0.63, 1, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _scene_frame_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.035, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.63, 1.0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _ambience_popup_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.78)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _load_texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null

	var imported_texture = load(path)
	if imported_texture is Texture2D:
		return imported_texture

	var image = Image.new()
	var error = image.load(path)
	if error != OK:
		push_warning("Image de donjon introuvable: %s" % path)
		return null

	return ImageTexture.create_from_image(image)
