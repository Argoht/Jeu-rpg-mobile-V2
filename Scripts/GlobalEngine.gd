extends Node

## Thin orchestrator — creates subsystems, wires their signals and exposes a
## backward-compatible surface so existing UI scripts need no changes.
##
## Subsystems are loaded via preload() to guarantee compilation order
## (autoloads are parsed before the global class_name registry is fully built).

# ── Signals (re-emitted from subsystems for backward compat) ──────────────────

signal stats_updated
signal leveled_up(new_level: int)
signal xp_gained(amount: int)
signal mission_completed(xp_amount: int, stat_name: String, stat_amount: int)
signal mission_failed(hp_lost: int)
signal missions_changed
signal inventory_changed
signal dungeon_changed

# ── Subsystems ────────────────────────────────────────────────────────────────
# Untyped: autoloads are parsed before the global class_name registry is built,
# so the Core class_names aren't resolvable as types here.
# Runtime types: PlayerData, MissionManager, SaveSystem, InventorySystem.

var player_data      = null
var mission_manager  = null
var save_system      = null
var inventory_system = null
var dungeon_system   = null

# ── Inventory display constant ────────────────────────────────────────────────

var items_per_page: int = 45

# ── Auto-save ─────────────────────────────────────────────────────────────────

var _auto_save_timer: float = 0.0

# ── Backward-compatible computed properties ───────────────────────────────────

var player_name: String:
	get: return player_data.player_name
	set(v): player_data.player_name = v

var hp: int:
	get: return player_data.hp
	set(v): player_data.hp = v

var max_hp: int:
	get: return player_data.max_hp
	set(v): player_data.max_hp = v

var end: int:
	get: return player_data.stamina
	set(v): player_data.stamina = v

var max_end: int:
	get: return player_data.max_stamina
	set(v): player_data.max_stamina = v

var xp: int:
	get: return player_data.xp
	set(v): player_data.xp = v

var lvl: int:
	get: return player_data.lvl
	set(v): player_data.lvl = v

var stat_points: int:
	get: return player_data.stat_points
	set(v): player_data.stat_points = v

var atk: int:
	get: return player_data.atk

var def: int:
	get: return player_data.def

var stats: Dictionary:
	get: return player_data.get_stats_view()
	set(v): player_data.set_base_stats(v)

var all_missions: Dictionary:
	get: return mission_manager.all_missions

var available_missions: Array:
	get: return mission_manager.available_missions

var available_weekly_missions: Array:
	get: return mission_manager.available_weekly_missions

## Backward compat: MainScene reads GlobalEngine.inventory as an Array.
var inventory: Array:
	get: return inventory_system.items
	set(v): inventory_system.items = v

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	player_data      = preload("res://Scripts/Core/PlayerData.gd").new()
	mission_manager  = preload("res://Scripts/Core/MissionManager.gd").new()
	save_system      = preload("res://Scripts/Core/SaveSystem.gd").new()
	inventory_system = preload("res://Scripts/Core/InventorySystem.gd").new()
	dungeon_system   = preload("res://Scripts/Core/DungeonSystem.gd").new()

	add_child(player_data)
	add_child(mission_manager)
	add_child(save_system)
	add_child(inventory_system)
	add_child(dungeon_system)
	inventory_system.load_database()

	mission_manager.initialize(player_data)

	randomize()
	mission_manager.load_all_missions()
	save_system.load_game(player_data, mission_manager, inventory_system, dungeon_system)
	inventory_system.ensure_default_equipment()
	# Applique les bonus d'équipement chargés depuis la save
	player_data.set_equipment_bonuses(inventory_system.get_equipment_bonuses())
	player_data.update_derived_stats()

	if mission_manager.available_missions.is_empty():
		mission_manager.generate_missions()

	_connect_signals()

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= 30.0:
		_auto_save_timer = 0.0
		save_game()

# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	player_data.stats_updated.connect(func(): stats_updated.emit())
	player_data.xp_gained.connect(func(a: int): xp_gained.emit(a))
	player_data.leveled_up.connect(func(l: int): leveled_up.emit(l))

	mission_manager.mission_completed.connect(_on_mission_completed)
	mission_manager.mission_failed.connect(_on_mission_failed)
	mission_manager.missions_changed.connect(func(): missions_changed.emit())

	inventory_system.inventory_changed.connect(_on_inventory_changed)
	dungeon_system.dungeon_changed.connect(_on_dungeon_changed)

func _on_inventory_changed() -> void:
	# Recalcule les bonus d'équipement → PlayerData.stats_updated → UI refresh
	player_data.set_equipment_bonuses(inventory_system.get_equipment_bonuses())
	inventory_changed.emit()

func _on_dungeon_changed() -> void:
	dungeon_changed.emit()

func _on_mission_completed(xp_reward: int, stat_key: String, stat_amount: int) -> void:
	if not stat_key.is_empty() and stat_amount != 0:
		player_data.add_base_stat(stat_key, stat_amount)
	player_data.add_xp(xp_reward)
	mission_completed.emit(xp_reward, stat_key, stat_amount)

func _on_mission_failed(hp_lost: int) -> void:
	player_data.take_damage(hp_lost)
	mission_failed.emit(hp_lost)

# ── Delegated public API (backward compat) ────────────────────────────────────

func save_game() -> void:
	save_system.save_game(player_data, mission_manager, inventory_system, dungeon_system)

func add_stat(stat_name: String) -> void:
	player_data.add_stat(stat_name)
	save_game()

func accept_mission(mission_dict: Dictionary) -> bool:
	var result: bool = mission_manager.accept_mission(mission_dict)
	if result: save_game()
	return result

func process_mission_result(mission_dict: Dictionary, success: bool) -> void:
	mission_manager.process_result(mission_dict, success)
	save_game()

func equip_inventory_item(index: int) -> bool:
	var result: bool = inventory_system.equip_at(index)
	if result:
		save_game()
	return result

func unequip_item(slot: String) -> bool:
	var result: bool = inventory_system.unequip(slot)
	if result:
		save_game()
	return result

func get_time_string() -> String:
	return mission_manager.get_time_string()

func get_weekly_time_string() -> String:
	return mission_manager.get_weekly_time_string()

func get_xp_for_level(l: int) -> int:
	return player_data.get_xp_for_level(l)

func get_rank_index(l: int) -> int:
	return player_data.get_rank_index(l)

func get_rank_by_level(l: int) -> String:
	return player_data.get_rank_by_level(l)

func update_derived_stats() -> void:
	player_data.update_derived_stats()

func get_final_stat(stat_key) -> int:
	return player_data.get_final_stat(stat_key)

func get_dungeon_state() -> Dictionary:
	return dungeon_system.get_view_state(get_rank_by_level(lvl))

func start_dungeon(rank: String) -> bool:
	var result: bool = dungeon_system.start_run(rank, get_rank_by_level(lvl), player_data)
	if result:
		save_game()
	return result

func dungeon_auto_exchange() -> bool:
	var result: bool = dungeon_system.resolve_auto_exchange(player_data)
	if result:
		save_game()
	return result

func dungeon_use_skill(skill: String) -> bool:
	var result: bool = dungeon_system.use_skill(skill, player_data)
	if result:
		save_game()
	return result

func dungeon_advance_floor() -> bool:
	var result: bool = dungeon_system.advance_floor()
	if result:
		save_game()
	return result

func dungeon_choose_event(choice_index: int) -> bool:
	var result: bool = dungeon_system.resolve_event(choice_index, player_data)
	if result:
		save_game()
	return result

func forfeit_dungeon() -> bool:
	var result: bool = dungeon_system.forfeit_run()
	if result:
		save_game()
	return result

# ── Debug helpers ─────────────────────────────────────────────────────────────

func is_debug_invincible() -> bool:
	return player_data != null and player_data.debug_invincible

func debug_toggle_invincible() -> bool:
	player_data.debug_invincible = not player_data.debug_invincible
	if player_data.debug_invincible:
		player_data.hp = player_data.max_hp
		player_data.stamina = player_data.max_stamina
	player_data.stats_updated.emit()
	return player_data.debug_invincible

func debug_reset_daily() -> void:
	mission_manager.debug_reset_daily()

func debug_reset_weekly() -> void:
	mission_manager.debug_reset_weekly()

func debug_add_level() -> void:
	player_data.lvl += 1
	player_data.stat_points += 3
	player_data.update_derived_stats()
	player_data.leveled_up.emit(player_data.lvl)
	player_data.stats_updated.emit()
	save_game()

## Returns the Texture2D icon for an item dict, or null if no template/icon.
func get_item_icon(item: Dictionary): # -> Texture2D or null
	var tid: String = item.get("template_id", "")
	if tid.is_empty(): return null
	var db = inventory_system._item_db
	if db == null: return null
	var tmpl = db.get_template(tid)
	if tmpl == null: return null
	return tmpl.icon

func debug_add_loot() -> Dictionary:
	var item: Dictionary = inventory_system.generate_loot(player_data.lvl)
	save_game()
	return item
