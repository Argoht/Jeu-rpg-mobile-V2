extends Node

## Manages the player's items, equipment slots and computed equipment bonuses.
## Items are stored as JSON-friendly Dictionaries — see LootGenerator.gd.
## Emits inventory_changed whenever the items list or equipment is mutated.

const LootGen  = preload("res://Scripts/Core/LootGenerator.gd")
const ItemDB   = preload("res://Scripts/Core/ItemDatabase.gd")

# ── Signals ───────────────────────────────────────────────────────────────────

signal inventory_changed
signal item_added(item: Dictionary)
signal item_equipped(slot: String, item: Dictionary)

# ── Constants ─────────────────────────────────────────────────────────────────

## 5 pages × 45 slots in the current UI grid.
const MAX_SLOTS: int = 225
const DEFAULT_ARMOR_TEMPLATE_ID := "chemise_delavee"
const DEFAULT_LEGS_TEMPLATE_ID := "short_de_timp"
const DEFAULT_FEET_TEMPLATE_ID := "claquettes_de_boloss"
const REMOVED_TEMPLATE_IDS := [
	"amulette_sagesse",
	"anneau_force",
	"armure_acier",
	"bracelet_agilite",
	"cotte_mailles",
	"dague_rapide",
	"epee_fer",
	"hache_guerre",
	"lance_ombre",
	"robe_mage",
	"talisman_chance",
	"tunique_cuir",
]

const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "legs", "feet", "accessory"]

# ── State ─────────────────────────────────────────────────────────────────────

var items: Array = []
var equipment: Dictionary = {
	"weapon": null, "armor": null, "legs": null, "feet": null, "accessory": null
}

var _item_db = null  # ItemDatabase node

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func load_database() -> void:
	_item_db = ItemDB.new()
	add_child(_item_db)
	_item_db.load_all()

func ensure_default_equipment() -> void:
	_remove_deleted_templates()
	_normalize_default_shirt_stats()
	_ensure_default_slot("armor", DEFAULT_ARMOR_TEMPLATE_ID, {"HP": 1})
	_ensure_default_slot("legs", DEFAULT_LEGS_TEMPLATE_ID, {"AGI": 1})
	_ensure_default_slot("feet", DEFAULT_FEET_TEMPLATE_ID, {"STAMINA": 1})

func _ensure_default_slot(slot: String, template_id: String, stat_bonuses: Dictionary) -> void:
	if equipment.get(slot, null) != null:
		return
	if _has_template_anywhere(template_id):
		return

	var template = null
	if _item_db != null:
		template = _item_db.get_template(template_id)
	if template == null:
		return

	equipment[slot] = {
		"id": "default_%s" % template_id,
		"name": template.item_name,
		"rarity": "common",
		"type": slot,
		"base_power": template.base_power,
		"stat_bonuses": stat_bonuses,
		"template_id": template.id
	}

# ── Public API: items ─────────────────────────────────────────────────────────

func add_item(item: Dictionary) -> bool:
	if items.size() >= MAX_SLOTS:
		return false
	items.append(item)
	item_added.emit(item)
	inventory_changed.emit()
	return true

func remove_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var removed: Dictionary = items[index]
	items.remove_at(index)
	inventory_changed.emit()
	return removed

func generate_loot(player_level: int) -> Dictionary:
	var item: Dictionary = LootGen.generate(player_level, _item_db)
	add_item(item)
	return item

# ── Public API: equipment ─────────────────────────────────────────────────────

## Equip the item at `index` to its matching slot, swapping any current piece
## back into the inventory. Returns true on success.
func equip_at(index: int) -> bool:
	if index < 0 or index >= items.size(): return false
	var item: Dictionary = items[index]
	var slot: String = item.get("type", "")
	if not equipment.has(slot): return false

	if equipment[slot] != null:
		items.append(equipment[slot])
	items.remove_at(index)
	equipment[slot] = item

	item_equipped.emit(slot, item)
	inventory_changed.emit()
	return true

## Unequip the item in `slot` and move it back to inventory.
func unequip(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot] == null: return false
	if items.size() >= MAX_SLOTS: return false
	items.append(equipment[slot])
	equipment[slot] = null
	inventory_changed.emit()
	return true

func _has_template_anywhere(template_id: String) -> bool:
	for slot in EQUIP_SLOTS:
		var equipped = equipment.get(slot)
		if typeof(equipped) == TYPE_DICTIONARY and equipped.get("template_id", "") == template_id:
			return true

	for item in items:
		if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == template_id:
			return true

	return false

func _normalize_default_shirt_stats() -> void:
	var armor = equipment.get("armor", null)
	if typeof(armor) == TYPE_DICTIONARY and armor.get("template_id", "") == DEFAULT_ARMOR_TEMPLATE_ID:
		var bonuses = armor.get("stat_bonuses", {})
		if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
			armor["stat_bonuses"] = {"HP": 1}

func _remove_deleted_templates() -> void:
	for slot in EQUIP_SLOTS:
		var equipped = equipment.get(slot)
		if typeof(equipped) == TYPE_DICTIONARY and REMOVED_TEMPLATE_IDS.has(equipped.get("template_id", "")):
			equipment[slot] = null

	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		if typeof(item) == TYPE_DICTIONARY and REMOVED_TEMPLATE_IDS.has(item.get("template_id", "")):
			items.remove_at(i)

## Sum stat bonuses from all equipped items — used by PlayerData.get_final_stat().
func get_equipment_bonuses() -> Dictionary:
	var total: Dictionary = {}
	for slot in EQUIP_SLOTS:
		var piece = equipment.get(slot)
		if piece == null: continue
		var bonuses := StatTypes.normalize_bonus_stats(piece.get("stat_bonuses", {}))
		for stat_key in bonuses:
			total[stat_key] = total.get(stat_key, 0) + int(bonuses[stat_key])
	return total

# ── Serialization ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"items": items,
		"equipment": equipment
	}

func from_dict(data: Dictionary) -> void:
	items = data.get("items", [])
	equipment = data.get("equipment", {})
	# Forward-compat: garantit que tous les slots existent
	for slot in EQUIP_SLOTS:
		if not equipment.has(slot):
			equipment[slot] = null
	inventory_changed.emit()
