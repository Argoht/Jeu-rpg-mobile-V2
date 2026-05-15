extends Control

const MISSIONS_SCENE = preload("res://Scenes/UI/missions_ui.tscn")
const EmptyTabPanel = preload("res://Scripts/UI/EmptyTabPanel.gd")
const CORE_STAT_KEYS: Array[String] = ["STR", "INT", "WIL", "AGI", "HP", "STAMINA"]
const DEBUG_BAR_DEFAULT_VISIBLE := false
const EMPTY_TAB_NAMES: Array[String] = ["Campement", "Grimoire", "Social", "Donjon", "Boutique", "Options"]
const DEFAULT_ARMOR_TEMPLATE_ID := "chemise_delavee"
const EQUIPMENT_SLOT_BY_TYPE := {
	"armor": "Torse",
	"legs": "Jambes",
	"feet": "Pieds",
	"weapon": "Mains",
	"accessory": "Anneau1",
}

# ── Nœuds de la scène ──

@onready var barre_hp      = $VBox/VitalsSection/VBox/Vitals/HP/BarreHP
@onready var label_hp_num  = $VBox/VitalsSection/VBox/Vitals/HP/Margin/HBox/Val
@onready var barre_end     = $VBox/VitalsSection/VBox/Vitals/END/BarreEnd
@onready var label_end_num = $VBox/VitalsSection/VBox/Vitals/END/Margin/HBox/Val
@onready var barre_xp      = $VBox/VitalsSection/VBox/XPLine/BarreXP
@onready var label_xp_num  = $VBox/VitalsSection/VBox/XPLine/BarreXP/XPText
@onready var label_lvl     = $VBox/VitalsSection/VBox/XPLine/LabelLvl

@onready var nav_section    = $VBox/Nav
@onready var vitals_section = $VBox/VitalsSection
@onready var hero_frame     = $VBox/GameZone/VBox/HeroFrame
@onready var avatar_view    = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/AvatarView
@onready var stats_frame    = $VBox/GameZone/VBox/StatsFrame
@onready var inv_panel      = $VBox/GameZone/VBox/InvPanel

@onready var btn_personnage = $VBox/Nav/NavVBox/Row1/Button1
@onready var btn_campement  = $VBox/Nav/NavVBox/Row1/Button2
@onready var btn_missions   = $VBox/Nav/NavVBox/Row1/Button3
@onready var btn_grimoire   = $VBox/Nav/NavVBox/Row1/Button4
@onready var btn_social     = $VBox/Nav/NavVBox/Row2/Button5
@onready var btn_donjon     = $VBox/Nav/NavVBox/Row2/Button6
@onready var btn_boutique   = $VBox/Nav/NavVBox/Row2/Button7
@onready var btn_options    = $VBox/Nav/NavVBox/Row2/Button8

@onready var label_pseudo = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderCard/HeaderInfo/Pseudo
@onready var inv_grid     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/GridZone/Grille
@onready var page_label   = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/PageLabel
@onready var btn_prev     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnPrev
@onready var btn_next     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnNext

@onready var stats_labels = {
	"STR": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Str/Val"),
	"AGI": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Dex/Val"),
	"INT": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Int/Val"),
	"HP": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Vit/Val"),
	"WIL": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Wil/Val"),
	"STAMINA": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Per/Val"),
	"atk": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Atk/Val"),
	"def": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Def/Val")
}

# ── État local ────────────────────────────────────────────────────────────────

var current_page: int = 0
var total_pages:  int = 5

var _missions_panel: Control = null
var _empty_tab_panels: Dictionary = {}
var _options_panel = null
var _debug_bar: Control = null
var _debug_invincible_button: Button = null
var _debug_mode_enabled: bool = DEBUG_BAR_DEFAULT_VISIBLE
var _popup_manager  = null   # PopupManager (preloaded)

func _apply_canonical_stat_labels() -> void:
	var label_paths := {
		"Str": "STR",
		"Dex": "AGI",
		"Int": "INT",
		"Vit": "HP",
		"Wil": "WIL",
		"Per": "STAMINA",
		"Atk": "ATK",
		"Def": "DEF",
	}
	for node_name in label_paths.keys():
		var lab = get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/%s/Lab" % node_name)
		if is_instance_valid(lab):
			lab.text = label_paths[node_name]

	for old_node_name in ["Cha", "Lck"]:
		var old_node = get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/%s" % old_node_name)
		if is_instance_valid(old_node):
			old_node.hide()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_apply_canonical_stat_labels()

	# Navigation
	_connect_navigation()
	btn_prev.pressed.connect(_change_page.bind(-1))
	btn_next.pressed.connect(_change_page.bind(1))
	$VBox/GameZone.mouse_filter = 2
	$VBox/GameZone/VBox.mouse_filter = 2

	# PopupManager — gère level-up, mission result et rename
	_popup_manager = preload("res://Scripts/UI/PopupManager.gd").new()
	add_child(_popup_manager)

	# Bouton renommage pseudo
	_add_rename_button()

	# Ecran missions : enfant direct de la racine UI, pour ne pas heriter
	# des marges/contraintes de GameZone.
	_missions_panel = MISSIONS_SCENE.instantiate()
	add_child(_missions_panel)
	move_child(_missions_panel, _popup_manager.get_index())
	_missions_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_missions_panel.offset_left = 0
	_missions_panel.offset_top = 0
	_missions_panel.offset_right = 0
	_missions_panel.offset_bottom = 0
	_missions_panel.hide()
	_build_empty_tab_panels()

	# Signaux GlobalEngine
	GlobalEngine.stats_updated.connect(update_ui)
	GlobalEngine.inventory_changed.connect(_on_inventory_changed)
	update_ui()

	_set_debug_mode(DEBUG_BAR_DEFAULT_VISIBLE)

# ── Navigation ────────────────────────────────────────────────────────────────

func _connect_navigation() -> void:
	var bindings := [
		[btn_personnage, "Personnage"],
		[btn_campement, "Campement"],
		[btn_missions, "Missions"],
		[btn_grimoire, "Grimoire"],
		[btn_social, "Social"],
		[btn_donjon, "Donjon"],
		[btn_boutique, "Boutique"],
		[btn_options, "Options"],
	]

	for binding in bindings:
		var button: Button = binding[0]
		var tab_name: String = binding[1]
		button.pressed.connect(_on_nav_pressed.bind(tab_name))

func _on_nav_pressed(tab_name: String) -> void:
	vitals_section.show()
	_hide_root_tab_panels()

	if tab_name == "Personnage":
		_show_personnage_content(true)
		update_ui()
		return

	_show_personnage_content(false)
	if tab_name == "Missions":
		_missions_panel.show()
	else:
		var panel = _empty_tab_panels.get(tab_name, null)
		if is_instance_valid(panel):
			panel.show()

	call_deferred("_sync_content_panels_layout")

func _show_personnage_content(is_visible: bool) -> void:
	hero_frame.visible = is_visible
	stats_frame.visible = is_visible
	inv_panel.visible = is_visible

func _hide_root_tab_panels() -> void:
	if is_instance_valid(_missions_panel):
		_missions_panel.hide()

	for panel in _empty_tab_panels.values():
		if is_instance_valid(panel):
			panel.hide()

func _toggle_debug_mode() -> void:
	_set_debug_mode(not _debug_mode_enabled)

func _set_debug_mode(enabled: bool) -> void:
	_debug_mode_enabled = enabled

	if enabled and not is_instance_valid(_debug_bar):
		_build_debug_bar()

	if is_instance_valid(_debug_bar):
		_debug_bar.visible = enabled

	_update_debug_toggle_button()
	_update_debug_invincible_button()

	call_deferred("_sync_content_panels_layout")

func _toggle_debug_invincible() -> void:
	GlobalEngine.debug_toggle_invincible()
	_update_debug_invincible_button()
	update_ui()

func _update_debug_invincible_button() -> void:
	if not is_instance_valid(_debug_invincible_button):
		return
	var enabled = GlobalEngine.is_debug_invincible()
	_debug_invincible_button.text = "Invincible: ON" if enabled else "Invincible: OFF"

func _sync_missions_layout() -> void:
	_sync_content_panels_layout()

func _sync_content_panels_layout() -> void:
	if not is_instance_valid(_missions_panel):
		return
	var content_top: float = vitals_section.global_position.y + vitals_section.size.y - global_position.y + 8.0

	var panels := [_missions_panel]
	panels.append_array(_empty_tab_panels.values())
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.offset_top = content_top
		panel.offset_left = 0
		panel.offset_right = 0
		panel.offset_bottom = 0

func _build_empty_tab_panels() -> void:
	for tab_name in EMPTY_TAB_NAMES:
		var panel: Control = _create_empty_tab_panel(tab_name)
		_empty_tab_panels[tab_name] = panel
		add_child(panel)
		move_child(panel, _popup_manager.get_index())
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		panel.hide()

func _create_empty_tab_panel(tab_name: String) -> Control:
	if tab_name == "Donjon":
		var dungeon_script = load("res://Scripts/UI/DungeonPanel.gd")
		if dungeon_script != null:
			var dungeon_panel = dungeon_script.new()
			if dungeon_panel is Control:
				return dungeon_panel

	var panel = EmptyTabPanel.new()
	panel.configure(tab_name, Callable(self, "_toggle_debug_mode"))
	if tab_name == "Options":
		_options_panel = panel
		_update_debug_toggle_button()
	return panel

func _update_debug_toggle_button() -> void:
	if is_instance_valid(_options_panel):
		_options_panel.set_debug_enabled(_debug_mode_enabled)

func _change_page(step: int) -> void:
	current_page = clampi(current_page + step, 0, total_pages - 1)
	update_inventory_display()
	update_equipment_display()

func _on_inventory_changed() -> void:
	update_inventory_display()
	update_equipment_display()
	update_ui()

# ── UI update ─────────────────────────────────────────────────────────────────

func update_ui() -> void:
	if not is_instance_valid(GlobalEngine): return

	barre_hp.value    = GlobalEngine.hp
	label_hp_num.text = "%d / %d" % [GlobalEngine.hp, GlobalEngine.max_hp]
	barre_end.value    = GlobalEngine.end
	label_end_num.text = "%d / %d" % [GlobalEngine.end, GlobalEngine.max_end]
	barre_xp.max_value = GlobalEngine.get_xp_for_level(GlobalEngine.lvl)
	barre_xp.value     = GlobalEngine.xp
	label_xp_num.text  = "%d / %d XP" % [GlobalEngine.xp, GlobalEngine.get_xp_for_level(GlobalEngine.lvl)]
	label_lvl.text     = "NIVEAU " + str(GlobalEngine.lvl)

	if is_instance_valid(label_pseudo):
		label_pseudo.text = GlobalEngine.player_name.to_upper()
	if is_instance_valid(avatar_view):
		avatar_view.set_avatar_state(GlobalEngine.lvl, GlobalEngine.get_rank_by_level(GlobalEngine.lvl), GlobalEngine.inventory_system.equipment)

	for s_key in stats_labels.keys():
		var label = stats_labels[s_key]
		if not is_instance_valid(label): continue

		if s_key == "atk":
			label.text = str(GlobalEngine.atk)
		elif s_key == "def":
			label.text = str(GlobalEngine.def)
		elif s_key in CORE_STAT_KEYS:
			label.text = str(GlobalEngine.get_final_stat(s_key))
		elif GlobalEngine.stats.has(s_key):
			label.text = str(GlobalEngine.stats[s_key])

		var parent   = label.get_parent()
		var btn_name = "AddBtn_" + s_key
		var btn      = parent.get_node_or_null(btn_name)

		if GlobalEngine.stat_points > 0 and s_key not in ["atk", "def"]:
			if not btn:
				btn = Button.new()
				btn.name = btn_name
				btn.text = "+"
				btn.pressed.connect(Callable(GlobalEngine, "add_stat").bind(s_key))
				parent.add_child(btn)
			btn.show()
		elif btn:
			btn.hide()

	update_inventory_display()
	update_equipment_display()

func update_inventory_display() -> void:
	page_label.text = "%d / %d" % [current_page + 1, total_pages]
	var slots     := inv_grid.get_children()
	var start_idx := current_page * GlobalEngine.items_per_page

	for i in range(slots.size()):
		var slot = slots[i]
		_clear_slot(slot)

		var item_idx := start_idx + i
		if item_idx < GlobalEngine.inventory.size():
			var item: Dictionary = GlobalEngine.inventory[item_idx]
			var btn := Button.new()
			_configure_item_button(btn, item)
			btn.pressed.connect(_on_inventory_item_pressed.bind(item_idx, item))
			slot.add_child(btn)
			# Fait remplir le slot après add_child (sinon les ancres n'ont pas de parent)
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.offset_left = 0; btn.offset_top = 0
			btn.offset_right = 0; btn.offset_bottom = 0

## Couleur d'affichage par rareté (aligné sur ItemData.get_rarity_color).
func update_equipment_display() -> void:
	for slot_type in EQUIPMENT_SLOT_BY_TYPE.keys():
		var panel := _get_equipment_slot_panel(slot_type)
		if not is_instance_valid(panel):
			continue

		_clear_slot(panel)
		var item = GlobalEngine.inventory_system.equipment.get(slot_type, null)
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var btn := Button.new()
		_configure_item_button(btn, item)
		btn.pressed.connect(_on_equipment_slot_pressed.bind(slot_type))
		panel.add_child(btn)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.offset_left = 0; btn.offset_top = 0
		btn.offset_right = 0; btn.offset_bottom = 0

func _on_inventory_item_pressed(item_idx: int, item: Dictionary) -> void:
	if _can_equip_item(item):
		_popup_manager.show_item_details(item, "EQUIPER", Callable(self, "_equip_inventory_item_from_popup").bind(item_idx))
	else:
		_popup_manager.show_item_details(item)

func _on_equipment_slot_pressed(slot_type: String) -> void:
	var item = GlobalEngine.inventory_system.equipment.get(slot_type, null)
	if typeof(item) != TYPE_DICTIONARY:
		return

	_popup_manager.show_item_details(item, "DESEQUIPER", Callable(self, "_unequip_item_from_popup").bind(slot_type))

func _equip_inventory_item_from_popup(item_idx: int) -> void:
	GlobalEngine.equip_inventory_item(item_idx)

func _unequip_item_from_popup(slot_type: String) -> void:
	GlobalEngine.unequip_item(slot_type)

func _can_equip_item(item: Dictionary) -> bool:
	return GlobalEngine.inventory_system.equipment.has(item.get("type", ""))

func _is_default_shirt(item: Dictionary) -> bool:
	return item.get("type", "") == "armor" and item.get("template_id", "") == DEFAULT_ARMOR_TEMPLATE_ID

func _get_equipment_slot_panel(slot_type: String) -> Node:
	var node_name: String = EQUIPMENT_SLOT_BY_TYPE.get(slot_type, "")
	if node_name.is_empty():
		return null

	var left_panel = get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/LeftCol/%s" % node_name)
	if is_instance_valid(left_panel):
		return left_panel

	return get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/RightCol/%s" % node_name)

func _configure_item_button(btn: Button, item: Dictionary) -> void:
	var icon_tex = GlobalEngine.get_item_icon(item)
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = true
	else:
		btn.text = _type_icon(item.get("type", ""))
		btn.add_theme_font_size_override("font_size", 22)
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_color_override("font_color", _rarity_color(item.get("rarity", "common")))

func _clear_slot(slot: Node) -> void:
	for c in slot.get_children():
		c.queue_free()

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color("#aaaaaa")
		"rare":      return Color("#00f2ff")
		"epic":      return Color("#cc44ff")
		"legendary": return Color("#ffd700")
		"mythic":    return Color("#ff4444")
	return Color("#aaaaaa")

## Glyphe Unicode représentant le type d'objet (placeholder en attendant les sprites).
func _type_icon(item_type: String) -> String:
	match item_type:
		"weapon":    return "⚔"
		"armor":     return "🛡"
		"legs":      return "◩"
		"feet":      return "◨"
		"accessory": return "💍"
	return "◆"

# ── Rename button ─────────────────────────────────────────────────────────────

func _add_rename_button() -> void:
	var header_info = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderCard/HeaderInfo

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	header_info.add_child(hbox)
	header_info.move_child(hbox, 0)

	label_pseudo.reparent(hbox)

	var btn := Button.new()
	btn.text = "✎"
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color("#00f2ff"))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_width_left   = 1; s.border_width_top    = 1
	s.border_width_right  = 1; s.border_width_bottom = 1
	s.border_color = Color("#00f2ff")
	s.corner_radius_top_left    = 3; s.corner_radius_top_right   = 3
	s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
	s.content_margin_left  = 4; s.content_margin_right = 4
	s.content_margin_top   = 1; s.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(_popup_manager.show_rename)
	hbox.add_child(btn)

# ── Debug bar ─────────────────────────────────────────────────────────────────

func _build_debug_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.0, 0.0, 0.85)
	style.border_width_bottom = 1
	style.border_color = Color("#ff3333")

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style)
	_debug_bar = panel

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	panel.add_child(margin)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	margin.add_child(bar)

	var lbl := Label.new()
	lbl.text = "⚙ DEBUG"
	lbl.add_theme_color_override("font_color", Color("#ff3333"))
	lbl.add_theme_font_size_override("font_size", 11)
	bar.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	for btn_data in [
		["Reset Quotidien", func(): GlobalEngine.debug_reset_daily()],
		["Reset Hebdo",     func(): GlobalEngine.debug_reset_weekly()],
		["+ Niveau",        func(): GlobalEngine.debug_add_level()],
		["+ Loot",          func(): GlobalEngine.debug_add_loot()],
		["Invincible: OFF",  func(): _toggle_debug_invincible()],
	]:
		var b := Button.new()
		b.text = btn_data[0]
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(btn_data[1])
		bar.add_child(b)
		if btn_data[0] == "Invincible: OFF":
			_debug_invincible_button = b

	_update_debug_invincible_button()

	$VBox.add_child(panel)
	$VBox.move_child(panel, 0)
