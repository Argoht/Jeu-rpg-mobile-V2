class_name PlayerData
extends Node

## Holds all player state: stats, XP, level, HP, stamina and passive regen.
## Never modify stats directly from outside — use add_stat() and get_final_stat().

# ── Enums ──────────────────────────────────────────────────────────────────────

enum StatType { STR, INT, WIL, AGI, HP, STAMINA }

# String keys matching the enum order — used for Dictionary access and JSON save.
const STAT_KEYS: Array[String] = ["STR", "INT", "WIL", "AGI", "HP", "STAMINA"]

# ── Signals ───────────────────────────────────────────────────────────────────

signal stats_updated
signal xp_gained(amount: int)
signal leveled_up(new_level: int)

# ── Player identity ───────────────────────────────────────────────────────────

var player_name: String = "Joueur"

# ── Vitals ────────────────────────────────────────────────────────────────────

var hp: int = 100
var max_hp: int = 100
var stamina: int = 100  # displayed as END in the UI
var max_stamina: int = 100
var debug_invincible: bool = false

# ── Progression ───────────────────────────────────────────────────────────────

var xp: int = 0
var lvl: int = 1
var stat_points: int = 0

# ── Derived combat stats (recalculated via update_derived_stats) ───────────────

var atk: int = 12
var def: int = 6

# ── Base stats (editable via stat points) ─────────────────────────────────────

var base_stats: Dictionary = {
	"STR": 1,
	"INT": 1,
	"WIL": 1,
	"AGI": 1,
	"HP": 100,
	"STAMINA": 100,
}

# ── Bonus layers (added on top of base_stats in get_final_stat) ───────────────

var _equipment_bonuses: Dictionary = {}     # { "STR": 5, ... }
var _temp_buffs: Dictionary = {}            # { "STR": [{ "amount": 3, "duration": 60.0 }] }
var _passive_bonuses: Dictionary = {}       # { "STR": 1, ... }

# ── Regen constants ───────────────────────────────────────────────────────────

const HP_REGEN_RATE: float = 5.0 / 3600.0       # +5 HP/hour
const STAMINA_REGEN_RATE: float = 10.0 / 3600.0  # +10 stamina/hour

var _hp_regen_acc: float = 0.0
var _stamina_regen_acc: float = 0.0

# ── XP curve (index = level - 1, covers levels 1–99) ─────────────────────────

const XP_TABLE: Array = [
	100, 120, 140, 160, 180, 200, 230, 260, 300, 350,
	400, 450, 500, 560, 620, 680, 750, 820, 900, 980,
	1060, 1150, 1240, 1340, 1450, 1560, 1680, 1810, 1950, 2100,
	2260, 2430, 2610, 2800, 3000, 3210, 3430, 3660, 3900, 4150,
	4410, 4680, 4960, 5250, 5550, 5860, 6180, 6510, 6850, 7200,
	7560, 7930, 8310, 8700, 9100, 9510, 9930, 10360, 10800, 11250,
	11710, 12180, 12660, 13150, 13650, 14160, 14680, 15210, 15750, 16300,
	16860, 17430, 18010, 18600, 19200, 19810, 20430, 21060, 21700, 22350,
	23010, 23680, 24360, 25050, 25750, 26460, 27180, 27910, 28650, 29400,
	30160, 30930, 31710, 32500, 33300, 34110, 34930, 35760, 36600
]

# ── Godot lifecycle ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_process_regen(delta)

# ── Stat access ───────────────────────────────────────────────────────────────

## Final value of a stat = base + equipment bonus + active buffs + passives.
## Always use this instead of reading base_stats directly.
func get_final_stat(stat_key) -> int:
	var key: String = StatTypes.normalize_key(stat_key)
	if key.is_empty():
		return 0

	var base: int = base_stats.get(key, 0)
	var equip: int = _equipment_bonuses.get(key, 0)
	var passive: int = _passive_bonuses.get(key, 0)
	var buff: int = 0
	if _temp_buffs.has(key):
		for b in _temp_buffs[key]:
			buff += b.get("amount", 0)
	return base + equip + passive + buff

## Type-safe enum accessor.
func get_stat(stat_type: StatType) -> int:
	return get_final_stat(STAT_KEYS[stat_type])

func set_base_stats(stats_data: Dictionary) -> void:
	base_stats = StatTypes.normalize_base_stats(stats_data, max_hp, max_stamina)
	update_derived_stats()
	stats_updated.emit()

func get_stats_view() -> Dictionary:
	var view: Dictionary = {}
	for key in StatTypes.STAT_KEYS:
		view[key] = get_final_stat(key)
	for legacy_key in StatTypes.LEGACY_STAT_KEYS:
		view[legacy_key] = get_final_stat(legacy_key)
	return view

func add_base_stat(stat_key, amount: int = 1) -> void:
	var key: String = StatTypes.normalize_key(stat_key)
	if key.is_empty():
		return
	base_stats[key] = int(base_stats.get(key, 0)) + amount
	update_derived_stats()
	stats_updated.emit()

## Spend one stat point to raise a stat by 1.
func add_stat(stat_key) -> void:
	if stat_points <= 0:
		return
	if not StatTypes.is_valid_key(stat_key):
		return
	stat_points -= 1
	add_base_stat(stat_key, 1)

## Replace the equipment bonus layer (called by GlobalEngine when inventory changes).
## Triggers a recompute of derived combat stats and notifies the UI.
func set_equipment_bonuses(bonuses: Dictionary) -> void:
	_equipment_bonuses = StatTypes.normalize_bonus_stats(bonuses)
	update_derived_stats()
	stats_updated.emit()

func set_passive_bonuses(bonuses: Dictionary) -> void:
	_passive_bonuses = StatTypes.normalize_bonus_stats(bonuses)
	update_derived_stats()
	stats_updated.emit()

# ── Progression ───────────────────────────────────────────────────────────────

func add_xp(amount: int) -> void:
	xp += amount
	xp_gained.emit(amount)
	_check_level_up()
	stats_updated.emit()

func take_damage(amount: int) -> void:
	if debug_invincible:
		hp = max_hp
		stats_updated.emit()
		return
	hp = max(0, hp - amount)
	stats_updated.emit()

func can_spend_stamina(amount: int) -> bool:
	return debug_invincible or stamina >= amount

func spend_stamina(amount: int) -> bool:
	if debug_invincible:
		stamina = max_stamina
		stats_updated.emit()
		return true
	if not can_spend_stamina(amount):
		return false
	stamina -= amount
	stats_updated.emit()
	return true

## Recalculate ATK and DEF from base stats.
func update_derived_stats() -> void:
	max_hp = maxi(1, get_final_stat(StatTypes.KEY_HP))
	max_stamina = maxi(1, get_final_stat(StatTypes.KEY_STAMINA))
	hp = clampi(hp, 0, max_hp)
	stamina = clampi(stamina, 0, max_stamina)

	atk = 10 + (get_final_stat(StatTypes.KEY_STR) * 2) + get_final_stat(StatTypes.KEY_AGI)
	def = 5 + int(float(get_final_stat(StatTypes.KEY_HP)) * 0.1) + get_final_stat(StatTypes.KEY_WIL)

## Apply passive HP/stamina regen for time spent offline.
func apply_offline_regen(elapsed_seconds: float) -> void:
	hp = min(max_hp, hp + int(elapsed_seconds * HP_REGEN_RATE))
	stamina = min(max_stamina, stamina + int(elapsed_seconds * STAMINA_REGEN_RATE))

# ── Level / rank helpers ──────────────────────────────────────────────────────

func get_xp_for_level(l: int) -> int:
	if l >= 100: return 999999
	return XP_TABLE[clampi(l - 1, 0, 98)]

func get_rank_index(l: int) -> int:
	if l <= 10: return 0
	elif l <= 25: return 1
	elif l <= 40: return 2
	elif l <= 55: return 3
	elif l <= 70: return 4
	elif l <= 85: return 5
	else: return 6

func get_rank_by_level(l: int) -> String:
	return ["F", "E", "D", "C", "B", "A", "S"][get_rank_index(l)]

# ── Private ───────────────────────────────────────────────────────────────────

func _check_level_up() -> void:
	while lvl < 100 and xp >= get_xp_for_level(lvl):
		xp -= get_xp_for_level(lvl)
		lvl += 1
		stat_points += 3
		leveled_up.emit(lvl)

func _process_regen(delta: float) -> void:
	if hp < max_hp:
		_hp_regen_acc += delta * HP_REGEN_RATE
		if _hp_regen_acc >= 1.0:
			var gain := int(_hp_regen_acc)
			hp = min(max_hp, hp + gain)
			_hp_regen_acc -= gain
			stats_updated.emit()
	else:
		_hp_regen_acc = 0.0

	if stamina < max_stamina:
		_stamina_regen_acc += delta * STAMINA_REGEN_RATE
		if _stamina_regen_acc >= 1.0:
			var gain := int(_stamina_regen_acc)
			stamina = min(max_stamina, stamina + gain)
			_stamina_regen_acc -= gain
			stats_updated.emit()
	else:
		_stamina_regen_acc = 0.0
