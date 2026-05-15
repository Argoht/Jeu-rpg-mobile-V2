extends MarginContainer

var _main_vbox: VBoxContainer
var _daily_list_vbox: VBoxContainer
var _weekly_vbox: VBoxContainer
var _daily_scroll: ScrollContainer
var _timer_acc: float = 0.0
var _touch_dragging: bool = false
var _touch_start_position := Vector2.ZERO
var _touch_scroll_start: int = 0
var _touch_active_index: int = -1

const TOUCH_DRAG_DEADZONE := 8.0

func _ready() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.043, 0.047, 0.059, 1)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.149, 0.173, 0.212, 1)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left = 4

	var bg := PanelContainer.new()
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", panel_style)
	add_child(bg)

	var inner := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inner.add_theme_constant_override(side, 10)
	bg.add_child(inner)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 14)
	inner.add_child(_main_vbox)

	GlobalEngine.missions_changed.connect(_build_static_ui)
	_build_static_ui()

func _build_static_ui() -> void:
	_clear_children(_main_vbox)

	var t_daily := Label.new()
	t_daily.name = "TimerDaily"
	t_daily.text = "↻ Quotidien : " + GlobalEngine.get_time_string()
	t_daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_daily.add_theme_color_override("font_color", Color("#00f2ff"))
	t_daily.add_theme_font_size_override("font_size", 13)
	_main_vbox.add_child(t_daily)

	var t_weekly := Label.new()
	t_weekly.name = "TimerWeekly"
	t_weekly.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
	t_weekly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_weekly.add_theme_color_override("font_color", Color("#d15cff"))
	t_weekly.add_theme_font_size_override("font_size", 13)
	_main_vbox.add_child(t_weekly)

	_add_section_header("MISSIONS QUOTIDIENNES", Color("#00f2ff"), _main_vbox)

	_daily_scroll = ScrollContainer.new()
	_daily_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_daily_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_daily_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_daily_scroll.gui_input.connect(_on_daily_scroll_gui_input)
	_main_vbox.add_child(_daily_scroll)

	_daily_list_vbox = VBoxContainer.new()
	_daily_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_list_vbox.add_theme_constant_override("separation", 14)
	_daily_scroll.add_child(_daily_list_vbox)

	_add_section_header("MISSION HEBDOMADAIRE", Color("#d15cff"), _main_vbox)

	_weekly_vbox = VBoxContainer.new()
	_weekly_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weekly_vbox.add_theme_constant_override("separation", 10)
	_main_vbox.add_child(_weekly_vbox)

	_refresh_mission_cards()

func _refresh_mission_cards() -> void:
	if not is_instance_valid(_daily_list_vbox) or not is_instance_valid(_weekly_vbox):
		return

	_clear_children(_daily_list_vbox)
	_clear_children(_weekly_vbox)

	if GlobalEngine.available_missions.is_empty():
		var empty := Label.new()
		empty.text = "Missions épuisées."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#707070"))
		_daily_list_vbox.add_child(empty)
	else:
		for mission in GlobalEngine.available_missions:
			_daily_list_vbox.add_child(_create_card(mission, false))

	if GlobalEngine.available_weekly_missions.is_empty():
		var empty_weekly := Label.new()
		empty_weekly.text = "Aucun défi cette semaine."
		empty_weekly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_weekly.add_theme_color_override("font_color", Color("#707070"))
		_weekly_vbox.add_child(empty_weekly)
	else:
		for mission in GlobalEngine.available_weekly_missions:
			_weekly_vbox.add_child(_create_card(mission, true))

func _on_daily_scroll_gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_daily_scroll):
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_dragging = true
			_touch_active_index = touch_event.index
			_touch_start_position = touch_event.position
			_touch_scroll_start = _daily_scroll.scroll_vertical
		elif touch_event.index == _touch_active_index:
			_touch_dragging = false
			_touch_active_index = -1
		return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if not _touch_dragging:
			return
		if drag_event.index != _touch_active_index:
			return

		var delta_y: float = drag_event.position.y - _touch_start_position.y
		if abs(delta_y) < TOUCH_DRAG_DEADZONE:
			return

		_daily_scroll.scroll_vertical = max(0, _touch_scroll_start - int(delta_y))
		accept_event()

func _add_section_header(text: String, color: Color, parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

	var label := Label.new()
	label.text = "— " + text + " —"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _create_card(m_dict: Dictionary, is_weekly: bool) -> PanelContainer:
	var m_data = GlobalEngine.all_missions.get(m_dict.id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not m_data:
		return card

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a1018")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	if m_dict.status == "in_progress":
		style.border_color = Color("#ffaa00")
		style.shadow_color = Color(1.0, 0.67, 0.0, 0.25)
		style.shadow_size = 6
	elif m_dict.status in ["completed", "failed"]:
		style.border_color = Color("#2a2a2a")
	else:
		var border_color := Color("#00f2ff") if not is_weekly else Color("#d15cff")
		style.border_color = border_color
		style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.18)
		style.shadow_size = 5

	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)

	var title := Label.new()
	title.text = m_data.title.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#00f2ff") if not is_weekly else Color("#d15cff"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(title)

	var desc := Label.new()
	desc.text = m_data.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.74, 0.74, 0.74))
	content.add_child(desc)

	var reward_text := "+" + str(m_data.base_xp) + " XP"
	var reward_stat_key: String = m_data.get_reward_stat_key()
	if not reward_stat_key.is_empty():
		reward_text += "  +" + str(m_data.reward_stat_amount) + " " + reward_stat_key

	var reward := Label.new()
	reward.text = reward_text
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 12)
	reward.add_theme_color_override("font_color", Color("#00ff88"))
	content.add_child(reward)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)

	match m_dict.status:
		"available":
			var blockers := _get_launch_blockers(m_dict, m_data)
			if not blockers.is_empty():
				var reason := Label.new()
				reason.text = "Manque : " + " | ".join(blockers)
				reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				reason.autowrap_mode = TextServer.AUTOWRAP_WORD
				reason.add_theme_font_size_override("font_size", 11)
				reason.add_theme_color_override("font_color", Color("#ffb347"))
				buttons.add_child(reason)

				var disabled_button := Button.new()
				disabled_button.text = "BLOQUÉ"
				disabled_button.disabled = true
				disabled_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				buttons.add_child(disabled_button)
			else:
				var accept_button := Button.new()
				accept_button.text = "LANCER — %d END" % m_dict.end_cost
				accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				accept_button.pressed.connect(func(): if GlobalEngine.accept_mission(m_dict): _refresh_mission_cards())
				buttons.add_child(accept_button)
		"in_progress":
			var fail_button := Button.new()
			fail_button.text = "ÉCHEC"
			fail_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fail_button.add_theme_color_override("font_color", Color("#ff4444"))
			fail_button.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, false); _refresh_mission_cards())
			buttons.add_child(fail_button)

			var success_button := Button.new()
			success_button.text = "RÉUSSITE"
			success_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			success_button.add_theme_color_override("font_color", Color("#00ff88"))
			success_button.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, true); _refresh_mission_cards())
			buttons.add_child(success_button)
		_:
			var status_label := Label.new()
			status_label.text = "◉ " + m_dict.status.to_upper()
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.add_theme_font_size_override("font_size", 12)
			status_label.add_theme_color_override("font_color", Color("#707070"))
			buttons.add_child(status_label)

	content.add_child(buttons)
	margin.add_child(content)
	card.add_child(margin)
	return card

func _get_launch_blockers(m_dict: Dictionary, m_data) -> Array[String]:
	var blockers: Array[String] = []

	if GlobalEngine.hp <= 0:
		blockers.append("HP")

	var end_cost := int(m_dict.get("end_cost", 0))
	if not GlobalEngine.is_debug_invincible() and GlobalEngine.end < end_cost:
		blockers.append("END %d/%d" % [GlobalEngine.end, end_cost])

	for stat_key in m_data.get_requirement_map().keys():
		var required := int(m_data.get_requirement_map()[stat_key])
		var current := int(GlobalEngine.get_final_stat(stat_key))
		if current < required:
			blockers.append("%s %d/%d" % [_format_stat_label(stat_key), current, required])

	return blockers

func _format_stat_label(stat_key: String) -> String:
	if stat_key == "STAMINA":
		return "END"
	return stat_key

func _process(delta: float) -> void:
	_timer_acc += delta
	if _timer_acc < 1.0:
		return

	_timer_acc = 0.0

	var daily := _main_vbox.get_node_or_null("TimerDaily")
	if daily:
		daily.text = "↻ Quotidien : " + GlobalEngine.get_time_string()

	var weekly := _main_vbox.get_node_or_null("TimerWeekly")
	if weekly:
		weekly.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
