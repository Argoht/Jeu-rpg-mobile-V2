class_name ItemDatabase
extends Node

## Loads all ItemData templates from Data/Items/ and indexes them by id and type.
## Must call load_all() before using any lookup methods.

const ITEMS_PATH: String = "res://Data/Items/"

var _by_id: Dictionary   = {}
var _by_type: Dictionary = { "weapon": [], "armor": [], "legs": [], "feet": [], "accessory": [] }

# ── Public API ────────────────────────────────────────────────────────────────

func load_all() -> void:
	var dir := DirAccess.open(ITEMS_PATH)
	if not dir:
		push_warning("ItemDatabase: dossier introuvable — " + ITEMS_PATH)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			_try_load(ITEMS_PATH + fname)
		fname = dir.get_next()

func get_template(id: String) -> ItemData:
	return _by_id.get(id, null)

## Returns a random template for the given type string, or null if pool is empty.
func get_random_by_type(type_str: String) -> ItemData:
	var pool: Array = _by_type.get(type_str, [])
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func has_templates_for_type(type_str: String) -> bool:
	var pool: Array = _by_type.get(type_str, [])
	return not pool.is_empty()

func template_count() -> int:
	return _by_id.size()

# ── Private ───────────────────────────────────────────────────────────────────

func _try_load(path: String) -> void:
	var res = load(path)
	if not (res and res is ItemData):
		return
	var tmpl: ItemData = res as ItemData
	_by_id[tmpl.id] = tmpl
	var tkey: String = ItemData.type_string(tmpl.item_type)
	if _by_type.has(tkey):
		_by_type[tkey].append(tmpl)
