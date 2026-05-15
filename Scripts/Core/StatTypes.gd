class_name StatTypes
extends RefCounted

enum Type { STR, INT, WIL, AGI, HP, STAMINA }

const KEY_STR: String = "STR"
const KEY_INT: String = "INT"
const KEY_WIL: String = "WIL"
const KEY_AGI: String = "AGI"
const KEY_HP: String = "HP"
const KEY_STAMINA: String = "STAMINA"

const STAT_KEYS: Array[String] = [
	KEY_STR,
	KEY_INT,
	KEY_WIL,
	KEY_AGI,
	KEY_HP,
	KEY_STAMINA,
]

const LEGACY_STAT_KEYS: Array[String] = [
	"str",
	"dex",
	"vit",
	"int",
	"wis",
	"cha",
	"per",
	"wil",
	"spd",
	"lck",
	"end",
	"stamina",
	"hp",
	"agi",
]

const _ALIASES: Dictionary = {
	"str": KEY_STR,
	"strength": KEY_STR,
	"int": KEY_INT,
	"intelligence": KEY_INT,
	"wil": KEY_WIL,
	"wis": KEY_WIL,
	"will": KEY_WIL,
	"willpower": KEY_WIL,
	"cha": KEY_WIL,
	"per": KEY_WIL,
	"lck": KEY_WIL,
	"dex": KEY_AGI,
	"agi": KEY_AGI,
	"spd": KEY_AGI,
	"speed": KEY_AGI,
	"vit": KEY_HP,
	"hp": KEY_HP,
	"health": KEY_HP,
	"end": KEY_STAMINA,
	"stamina": KEY_STAMINA,
}

static func default_base_stats() -> Dictionary:
	return {
		KEY_STR: 1,
		KEY_INT: 1,
		KEY_WIL: 1,
		KEY_AGI: 1,
		KEY_HP: 100,
		KEY_STAMINA: 100,
	}

static func is_valid_key(raw_key) -> bool:
	return not normalize_key(raw_key).is_empty()

static func normalize_key(raw_key) -> String:
	if raw_key is int:
		var idx: int = int(raw_key)
		if idx >= 0 and idx < STAT_KEYS.size():
			return STAT_KEYS[idx]
		return ""

	var upper_key := String(raw_key).strip_edges().to_upper()
	if STAT_KEYS.has(upper_key):
		return upper_key

	var legacy_key := String(raw_key).strip_edges().to_lower()
	return _ALIASES.get(legacy_key, "")

static func normalize_base_stats(raw_stats: Dictionary, fallback_hp: int = 100, fallback_stamina: int = 100) -> Dictionary:
	var result := default_base_stats()
	result[KEY_HP] = fallback_hp
	result[KEY_STAMINA] = fallback_stamina

	result[KEY_STR] = _first_int(raw_stats, [KEY_STR, "str"], result[KEY_STR])
	result[KEY_INT] = _first_int(raw_stats, [KEY_INT, "int"], result[KEY_INT])
	result[KEY_AGI] = _first_int(raw_stats, [KEY_AGI, "agi", "dex"], result[KEY_AGI])
	result[KEY_WIL] = _max_int(raw_stats, [KEY_WIL, "wil", "wis", "cha", "per", "lck"], result[KEY_WIL])
	result[KEY_HP] = _first_int(raw_stats, [KEY_HP, "hp"], result[KEY_HP])
	result[KEY_STAMINA] = _first_int(raw_stats, [KEY_STAMINA, "stamina", "end"], result[KEY_STAMINA])

	return result

static func normalize_bonus_stats(raw_stats: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key in raw_stats.keys():
		var key := normalize_key(raw_key)
		if key.is_empty():
			continue
		result[key] = int(result.get(key, 0)) + int(raw_stats[raw_key])
	return result

static func normalize_requirements(raw_requirements: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key in raw_requirements.keys():
		var key := normalize_key(raw_key)
		var amount := int(raw_requirements[raw_key])
		if key.is_empty() or amount <= 0:
			continue
		result[key] = maxi(int(result.get(key, 0)), amount)
	return result

static func _first_int(source: Dictionary, keys: Array, fallback: int) -> int:
	for key in keys:
		if source.has(key):
			return int(source[key])
	return fallback

static func _max_int(source: Dictionary, keys: Array, fallback: int) -> int:
	var value := fallback
	var found := false
	for key in keys:
		if source.has(key):
			var candidate := int(source[key])
			if found:
				value = maxi(value, candidate)
			else:
				value = candidate
				found = true
	return value
