extends RefCounted

## Stateless loot factory. When an ItemDatabase is provided, picks a random
## template to determine the item name and stat pool. Rarity is always rolled
## at generation time regardless of whether a template is used.
##
## Output format (JSON-friendly Dictionary for SaveSystem):
##   { id, name, rarity, type, base_power, stat_bonuses, [template_id] }

# ── Rarity tables ─────────────────────────────────────────────────────────────

const RARITY_NAMES:   Array[String] = ["common", "rare", "epic", "legendary", "mythic"]
const RARITY_WEIGHTS: Array[int]    = [60, 25, 10, 4, 1]
const RARITY_MULTS:   Array[float]  = [1.0, 1.8, 3.0, 5.0, 8.0]

const RARITY_SUFFIX: Dictionary = {
	"common":    "",
	"rare":      "fin",
	"epic":      "magique",
	"legendary": "légendaire",
	"mythic":    "mythique"
}

# ── Fallback tables (used when no template is available) ─────────────────────

const TYPES: Array[String] = ["weapon", "armor", "legs", "feet", "accessory"]

const FALLBACK_NAMES: Dictionary = {
	"weapon":    ["Lame", "Épée", "Dague", "Hache", "Lance", "Marteau"],
	"armor":     ["Tunique", "Armure", "Cuirasse", "Robe", "Cotte"],
	"legs":      ["Short", "Pantalon", "Jambieres"],
	"feet":      ["Claquettes", "Baskets", "Bottes"],
	"accessory": ["Anneau", "Amulette", "Bracelet", "Talisman"]
}

const FALLBACK_STATS: Dictionary = {
	"weapon":    ["STR", "AGI"],
	"armor":     ["HP", "WIL"],
	"legs":      ["AGI", "STAMINA"],
	"feet":      ["AGI", "STAMINA"],
	"accessory": ["INT", "WIL"]
}

# ── Public API ────────────────────────────────────────────────────────────────

## item_db: an ItemDatabase node, or null to use fallback tables.
static func generate(player_level: int, item_db = null) -> Dictionary:
	var rarity_str: String = _roll_rarity()
	var rarity_idx: int    = RARITY_NAMES.find(rarity_str)
	var mult: float        = RARITY_MULTS[rarity_idx]

	var item_type:   String = _pick_item_type(item_db)
	var template_id: String = ""
	var base_name:   String = ""
	var stat_pool:   Array  = []
	var base_pwr:    int    = 0

	if item_db != null:
		var tmpl = item_db.get_random_by_type(item_type)
		if tmpl != null:
			template_id = tmpl.id
			base_name   = tmpl.item_name
			base_pwr    = tmpl.base_power
			stat_pool   = Array(tmpl.stat_pool)

	if base_name.is_empty():
		base_name = (FALLBACK_NAMES[item_type] as Array).pick_random()
	if stat_pool.is_empty():
		stat_pool = Array(FALLBACK_STATS[item_type])
	if base_pwr == 0:
		base_pwr = player_level * 2

	var result: Dictionary = {
		"id":          "loot_%d" % randi(),
		"name":        _display_name(base_name, rarity_str),
		"rarity":      rarity_str,
		"type":        item_type,
		"base_power":  int(float(base_pwr) * mult) + int(float(player_level) * mult * 0.5),
		"stat_bonuses": _roll_bonuses(stat_pool, rarity_idx, player_level, mult)
	}
	if not template_id.is_empty():
		result["template_id"] = template_id
	return result

static func _pick_item_type(item_db = null) -> String:
	if item_db != null:
		var available_types: Array[String] = []
		for type_key in TYPES:
			if item_db.has_templates_for_type(type_key):
				available_types.append(type_key)
		if not available_types.is_empty():
			return available_types.pick_random()

	return TYPES.pick_random()

# ── Private ───────────────────────────────────────────────────────────────────

static func _roll_rarity() -> String:
	var total: int = 0
	for w in RARITY_WEIGHTS: total += w
	var roll: int  = randi() % total
	var cumul: int = 0
	for i in range(RARITY_WEIGHTS.size()):
		cumul += RARITY_WEIGHTS[i]
		if roll < cumul: return RARITY_NAMES[i]
	return "common"

static func _display_name(base: String, rarity: String) -> String:
	var suffix: String = RARITY_SUFFIX.get(rarity, "")
	return base if suffix.is_empty() else "%s %s" % [base, suffix]

static func _roll_bonuses(pool: Array, rarity_idx: int, player_level: int, mult: float) -> Dictionary:
	var num_stats: int = 1 + rarity_idx
	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()
	var bonuses: Dictionary = {}
	for i in range(mini(num_stats, shuffled.size())):
		var stat_key := StatTypes.normalize_key(shuffled[i])
		if stat_key.is_empty():
			continue
		var amount: int = int(float(player_level) * 0.3 * mult) + randi_range(1, 3)
		bonuses[stat_key] = int(bonuses.get(stat_key, 0)) + amount
	return bonuses
