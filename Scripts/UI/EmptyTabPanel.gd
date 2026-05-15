extends PanelContainer

var _debug_toggle_button: Button = null

func configure(tab_name: String, debug_callback: Callable) -> void:
	name = tab_name + "Panel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())

	if tab_name == "Options":
		_build_options(debug_callback)

func set_debug_enabled(enabled: bool) -> void:
	if is_instance_valid(_debug_toggle_button):
		_debug_toggle_button.text = "Mode debug : ON" if enabled else "Mode debug : OFF"

func _build_options(debug_callback: Callable) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(tabs)

	var options_box := VBoxContainer.new()
	options_box.name = "Options"
	options_box.add_theme_constant_override("separation", 10)
	tabs.add_child(options_box)

	_debug_toggle_button = Button.new()
	_debug_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_toggle_button.pressed.connect(debug_callback)
	options_box.add_child(_debug_toggle_button)

	var bestiary_script = load("res://Scripts/UI/BestiaryPanel.gd")
	if bestiary_script != null:
		tabs.add_child(bestiary_script.new())

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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
