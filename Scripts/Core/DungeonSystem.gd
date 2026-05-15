class_name DungeonSystem
extends Node

signal dungeon_changed
signal run_failed(rank, floor)
signal run_completed(rank)

const MAX_FLOOR = 100
const CHECKPOINT_STEP = 10
const ENERGY_MAX = 100
const RANKS = ["F", "E", "D", "C", "B", "A", "S"]

const ENTRY_COSTS = {
	"F": 10,
	"E": 15,
	"D": 22,
	"C": 30,
	"B": 40,
	"A": 52,
	"S": 65,
}

const DUNGEON_NAMES = {
	"F": "Bois fendu",
	"E": "Caves de rouille",
	"D": "Cryptes affamees",
	"C": "Tour des echos",
	"B": "Fosse des rois",
	"A": "Citadelle noire",
	"S": "Abime final",
}

const DUNGEON_BACKGROUNDS = {
	"F": [
		"res://Assets/Dungeons/Backgrounds/rank_f_01.png",
		"res://Assets/Dungeons/Backgrounds/rank_f_02.png",
		"res://Assets/Dungeons/Backgrounds/rank_f_03.png",
		"res://Assets/Dungeons/Backgrounds/rank_f_04.png",
	],
}

const AMBIENCE_MESSAGES = [
	"L'air devient plus lourd. Le donjon se referme autour de toi.",
	"L'ambiance se degrade. Les ombres semblent suivre chacun de tes pas.",
	"Le donjon s'enfonce dans quelque chose de mauvais. Reste vigilant.",
	"Tout ici respire la fin. Le coeur du donjon est proche.",
]

const TYPE_DATA = {
	"Brute": {"hp": 1.35, "atk": 1.12, "def": 1.2, "spd": 0.72},
	"Assassin": {"hp": 0.85, "atk": 1.05, "def": 0.8, "spd": 1.45},
	"Mage": {"hp": 0.95, "atk": 1.28, "def": 0.72, "spd": 1.0},
}

var in_run = false
var active_rank = "F"
var current_floor = 1
var checkpoint_floor = 1
var phase = "idle"
var player_energy = 0
var shield_turns = 0
var temp_atk_bonus = 0
var temp_def_bonus = 0
var temp_agi_bonus = 0
var enemy: Dictionary = {}
var event_data: Dictionary = {}
var battle_log: Array = []
var checkpoints: Dictionary = {}
var best_floors: Dictionary = {}

func _ready() -> void:
	_ensure_rank_data()

func start_run(rank: String, player_rank: String, player_data) -> bool:
	_ensure_rank_data()
	if in_run:
		return false
	if not _rank_available(rank, player_rank):
		_set_log(["Rang indisponible."])
		_emit_changed()
		return false

	var cost = get_entry_cost(rank)
	if not player_data.can_spend_stamina(cost):
		_set_log(["END insuffisante pour entrer."])
		_emit_changed()
		return false
	if player_data.hp <= 0:
		_set_log(["HP insuffisants pour entrer."])
		_emit_changed()
		return false

	player_data.spend_stamina(cost)
	active_rank = rank
	checkpoint_floor = int(checkpoints.get(rank, 1))
	current_floor = checkpoint_floor
	in_run = true
	player_energy = 15
	shield_turns = 0
	temp_atk_bonus = 0
	temp_def_bonus = 0
	temp_agi_bonus = 0
	_set_log(["Entree dans %s. Checkpoint etage %d." % [get_dungeon_name(rank), checkpoint_floor]])
	_start_combat()
	return true

func resolve_auto_exchange(player_data) -> bool:
	if phase != "combat" or enemy.is_empty():
		return false

	_add_energy(18)
	var player_first = _player_speed(player_data) >= int(enemy.get("spd", 1))
	if player_first:
		_player_basic_attack(player_data)
		if _enemy_dead():
			_clear_floor()
			return true
		_enemy_attack(player_data)
	else:
		_enemy_attack(player_data)
		if _player_dead(player_data):
			_fail_run(player_data)
			return true
		_player_basic_attack(player_data)

	if _enemy_dead():
		_clear_floor()
	elif _player_dead(player_data):
		_fail_run(player_data)
	else:
		_tick_shield()
		_emit_changed()
	return true

func use_skill(skill: String, player_data) -> bool:
	if phase != "combat" or enemy.is_empty():
		return false

	match skill:
		"special":
			if player_energy < 50:
				return false
			player_energy -= 50
			var damage = maxi(4, int(float(player_data.atk + temp_atk_bonus) * 1.75) + player_data.get_final_stat("INT") - int(enemy.get("def", 0) * 0.35))
			enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
			_log("Attaque speciale: -%d HP ennemi." % damage)
		"heal":
			if player_energy < 45:
				return false
			player_energy -= 45
			var heal = maxi(8, int(float(player_data.max_hp) * 0.18) + player_data.get_final_stat("WIL"))
			player_data.hp = mini(player_data.max_hp, player_data.hp + heal)
			player_data.stats_updated.emit()
			_log("Soin: +%d HP." % heal)
		"shield":
			if player_energy < 35:
				return false
			player_energy -= 35
			shield_turns = maxi(shield_turns, 2)
			_log("Bouclier actif pour 2 echanges.")
		_:
			return false

	if _enemy_dead():
		_clear_floor()
		return true

	_enemy_attack(player_data)
	if _player_dead(player_data):
		_fail_run(player_data)
	else:
		_tick_shield()
		_emit_changed()
	return true

func advance_floor() -> bool:
	if phase != "floor_cleared":
		return false
	if current_floor >= MAX_FLOOR:
		_complete_run()
		return true
	current_floor += 1
	_start_combat()
	return true

func resolve_event(choice_index: int, player_data) -> bool:
	if phase != "event" or event_data.is_empty():
		return false

	var kind = String(event_data.get("kind", ""))
	match kind:
		"altar":
			if choice_index == 0:
				var sacrifice = maxi(5, int(float(player_data.max_hp) * 0.12))
				player_data.take_damage(sacrifice)
				temp_atk_bonus += 3 + _rank_index(active_rank)
				_log("Autel: -%d HP, ATK temporaire augmentee." % sacrifice)
			elif choice_index == 1:
				var cost = mini(player_data.stamina, 8 + _rank_index(active_rank) * 2)
				player_data.spend_stamina(cost)
				temp_def_bonus += 3 + _rank_index(active_rank)
				_log("Autel: -%d END, DEF temporaire augmentee." % cost)
			else:
				_log("Tu ignores l'autel.")
		"merchant":
			if choice_index == 0 and player_data.can_spend_stamina(8):
				player_data.spend_stamina(8)
				var heal = maxi(10, int(float(player_data.max_hp) * 0.22))
				player_data.hp = mini(player_data.max_hp, player_data.hp + heal)
				player_data.stats_updated.emit()
				_log("Marchand: potion recue, +%d HP." % heal)
			else:
				_log("Tu passes ton chemin.")
		"trap":
			var stat = "INT"
			if choice_index == 0:
				stat = "AGI"
			var score = player_data.get_final_stat(stat) + randi_range(1, 20)
			var difficulty = 10 + _rank_index(active_rank) * 4 + int(float(current_floor) * 0.18)
			if score >= difficulty:
				player_energy = mini(ENERGY_MAX, player_energy + 25)
				_log("Test %s reussi. Energie +25." % stat)
			else:
				var damage = 6 + _rank_index(active_rank) * 5 + int(float(current_floor) * 0.45)
				player_data.take_damage(damage)
				_log("Test %s rate. Piege: -%d HP." % [stat, damage])
		"dilemma":
			if choice_index == 0:
				var damage = 4 + _rank_index(active_rank) * 4 + int(float(current_floor) * 0.35)
				player_data.take_damage(damage)
				current_floor = mini(MAX_FLOOR - 1, current_floor + 1)
				_log("Chemin court: -%d HP, un etage gagne." % damage)
			else:
				temp_def_bonus += 2
				_log("Chemin long: DEF temporaire +2.")

	event_data = {}
	if _player_dead(player_data):
		_fail_run(player_data)
	else:
		phase = "floor_cleared"
		_emit_changed()
	return true

func forfeit_run() -> bool:
	if not in_run:
		return false
	in_run = false
	phase = "idle"
	current_floor = int(checkpoints.get(active_rank, 1))
	event_data = {}
	enemy = {}
	_log("Sortie du donjon. Retour au checkpoint.")
	_emit_changed()
	return true

func get_entry_cost(rank: String) -> int:
	return int(ENTRY_COSTS.get(rank, 10))

func get_dungeon_name(rank: String) -> String:
	return String(DUNGEON_NAMES.get(rank, "Donjon"))

func get_dungeon_background_stage(floor: int) -> int:
	return clampi(int(float(maxi(1, floor) - 1) / 25.0), 0, 3)

func get_dungeon_background_path(rank: String, floor: int = 1) -> String:
	var backgrounds = DUNGEON_BACKGROUNDS.get(rank, [])
	if backgrounds is Array and not backgrounds.is_empty():
		return String(backgrounds[get_dungeon_background_stage(floor)])
	return ""

func get_ambience_message(stage: int) -> String:
	return String(AMBIENCE_MESSAGES[clampi(stage, 0, AMBIENCE_MESSAGES.size() - 1)])

func get_view_state(player_rank: String = "F") -> Dictionary:
	_ensure_rank_data()
	var available: Array = []
	for rank in RANKS:
		if _rank_available(rank, player_rank):
			available.append(rank)
	return {
		"in_run": in_run,
		"active_rank": active_rank,
		"current_floor": current_floor,
		"checkpoint_floor": checkpoint_floor,
		"phase": phase,
		"player_energy": player_energy,
		"shield_turns": shield_turns,
		"enemy": enemy,
		"event": event_data,
		"log": battle_log,
		"checkpoints": checkpoints,
		"best_floors": best_floors,
		"available_ranks": available,
		"background_stage": get_dungeon_background_stage(current_floor),
		"background_path": get_dungeon_background_path(active_rank, current_floor),
	}

func to_dict() -> Dictionary:
	return {
		"in_run": in_run,
		"active_rank": active_rank,
		"current_floor": current_floor,
		"checkpoint_floor": checkpoint_floor,
		"phase": phase,
		"player_energy": player_energy,
		"shield_turns": shield_turns,
		"temp_atk_bonus": temp_atk_bonus,
		"temp_def_bonus": temp_def_bonus,
		"temp_agi_bonus": temp_agi_bonus,
		"enemy": enemy,
		"event_data": event_data,
		"battle_log": battle_log,
		"checkpoints": checkpoints,
		"best_floors": best_floors,
	}

func from_dict(data: Dictionary) -> void:
	_ensure_rank_data()
	in_run = bool(data.get("in_run", false))
	active_rank = String(data.get("active_rank", "F"))
	current_floor = int(data.get("current_floor", 1))
	checkpoint_floor = int(data.get("checkpoint_floor", checkpoints.get(active_rank, 1)))
	phase = String(data.get("phase", "idle"))
	player_energy = int(data.get("player_energy", 0))
	shield_turns = int(data.get("shield_turns", 0))
	temp_atk_bonus = int(data.get("temp_atk_bonus", 0))
	temp_def_bonus = int(data.get("temp_def_bonus", 0))
	temp_agi_bonus = int(data.get("temp_agi_bonus", 0))
	enemy = data.get("enemy", {})
	event_data = data.get("event_data", {})
	battle_log = []
	for line in data.get("battle_log", []):
		battle_log.append(String(line))
	checkpoints = data.get("checkpoints", checkpoints)
	best_floors = data.get("best_floors", best_floors)
	_ensure_rank_data()

func _start_combat() -> void:
	phase = "combat"
	event_data = {}
	enemy = _generate_enemy()
	_log("Etage %d: %s apparait." % [current_floor, enemy.get("name", "Ennemi")])
	_emit_changed()

func _generate_enemy() -> Dictionary:
	var rank_i = _rank_index(active_rank)
	var enemy_types = TYPE_DATA.keys()
	var type_name = String(enemy_types.pick_random())
	var type_mod = TYPE_DATA[type_name]
	var base_hp = 28 + current_floor * 5 + rank_i * 38
	var base_atk = 7 + current_floor * 2 + rank_i * 8
	var base_def = 3 + current_floor + rank_i * 3
	var base_spd = 4 + int(float(current_floor) * 0.16) + rank_i * 2
	return {
		"name": _enemy_name(type_name),
		"type": type_name,
		"hp": maxi(1, int(float(base_hp) * float(type_mod["hp"]))),
		"max_hp": maxi(1, int(float(base_hp) * float(type_mod["hp"]))),
		"atk": maxi(1, int(float(base_atk) * float(type_mod["atk"]))),
		"def": maxi(0, int(float(base_def) * float(type_mod["def"]))),
		"spd": maxi(1, int(float(base_spd) * float(type_mod["spd"]))),
	}

func _enemy_name(type_name: String) -> String:
	var rank_i = _rank_index(active_rank)
	var pools = [
		["Rat de cave", "Chien errant", "Bandit maigre"],
		["Goule rouillee", "Voleur d'os", "Mage de suie"],
		["Sentinelle creuse", "Ombre vive", "Cultiste"],
		["Chevalier fendu", "Lame muette", "Oracle sec"],
		["Geant de fosse", "Traqueur royal", "Mage sanglant"],
		["Champion noir", "Assassin d'elite", "Archimage brise"],
		["Avatar du gouffre", "Main du vide", "Prophete final"],
	]
	var names = pools[clampi(rank_i, 0, pools.size() - 1)]
	return "%s %s" % [names.pick_random(), type_name]

func _player_basic_attack(player_data) -> void:
	var damage = _roll_damage(player_data.atk + temp_atk_bonus, int(enemy.get("def", 0)))
	enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
	_log("Tu frappes: -%d HP ennemi." % damage)

func _enemy_attack(player_data) -> void:
	var defense = player_data.def + temp_def_bonus
	var damage = _roll_damage(int(enemy.get("atk", 1)), defense)
	if shield_turns > 0:
		damage = maxi(1, int(float(damage) * 0.45))
	player_data.take_damage(damage)
	_log("%s attaque: -%d HP." % [enemy.get("name", "Ennemi"), damage])

func _roll_damage(atk: int, defense: int) -> int:
	return maxi(1, atk - int(float(defense) * 0.55) + randi_range(-2, 2))

func _clear_floor() -> void:
	phase = "floor_cleared"
	enemy = {}
	best_floors[active_rank] = maxi(int(best_floors.get(active_rank, 1)), current_floor)
	if current_floor % CHECKPOINT_STEP == 0:
		checkpoint_floor = current_floor
		checkpoints[active_rank] = checkpoint_floor
		_log("Checkpoint atteint: etage %d." % checkpoint_floor)

	if current_floor >= MAX_FLOOR:
		_complete_run()
		return

	if randi_range(1, 100) <= 28:
		_start_event()
	else:
		_log("Etage %d nettoye. Tu peux monter." % current_floor)
		_emit_changed()

func _start_event() -> void:
	phase = "event"
	var kind = ["altar", "merchant", "trap", "dilemma"].pick_random()
	match kind:
		"altar":
			event_data = {
				"kind": kind,
				"title": "Autel fissure",
				"text": "Une pierre froide reclame un prix avant le prochain etage.",
				"choices": ["Sacrifier HP pour ATK", "Sacrifier END pour DEF", "Ignorer"],
			}
		"merchant":
			event_data = {
				"kind": kind,
				"title": "Marchand cache",
				"text": "Une silhouette propose une potion contre 8 END.",
				"choices": ["Acheter la potion", "Passer"],
			}
		"trap":
			event_data = {
				"kind": kind,
				"title": "Couloir piege",
				"text": "Le sol craque. Il faut agir vite ou lire le mecanisme.",
				"choices": ["Esquiver avec AGI", "Analyser avec INT"],
			}
		"dilemma":
			event_data = {
				"kind": kind,
				"title": "Deux chemins",
				"text": "Un raccourci dangereux descend dans la roche. L'autre contourne lentement.",
				"choices": ["Chemin court", "Chemin long"],
			}
	_log("Evenement: %s." % event_data.get("title", "Choix"))
	_emit_changed()

func _complete_run() -> void:
	in_run = false
	phase = "completed"
	checkpoints[active_rank] = MAX_FLOOR
	best_floors[active_rank] = MAX_FLOOR
	_log("%s termine. Les 100 etages sont vaincus." % get_dungeon_name(active_rank))
	run_completed.emit(active_rank)
	_emit_changed()

func _fail_run(player_data) -> void:
	in_run = false
	phase = "dead"
	current_floor = int(checkpoints.get(active_rank, 1))
	checkpoint_floor = current_floor
	enemy = {}
	event_data = {}
	_log("Defaite. Retour au checkpoint etage %d." % checkpoint_floor)
	run_failed.emit(active_rank, current_floor)
	_emit_changed()

func _player_speed(player_data) -> int:
	return maxi(1, player_data.get_final_stat("AGI") + temp_agi_bonus)

func _enemy_dead() -> bool:
	return int(enemy.get("hp", 0)) <= 0

func _player_dead(player_data) -> bool:
	return player_data.hp <= 0

func _tick_shield() -> void:
	if shield_turns > 0:
		shield_turns -= 1

func _add_energy(amount: int) -> void:
	player_energy = mini(ENERGY_MAX, player_energy + amount)

func _rank_available(rank: String, player_rank: String) -> bool:
	var wanted = RANKS.find(rank)
	var current = RANKS.find(player_rank)
	return wanted >= 0 and current >= 0 and wanted <= current

func _rank_index(rank: String) -> int:
	return maxi(0, RANKS.find(rank))

func _ensure_rank_data() -> void:
	for rank in RANKS:
		if not checkpoints.has(rank):
			checkpoints[rank] = 1
		if not best_floors.has(rank):
			best_floors[rank] = 1

func _set_log(lines: Array) -> void:
	battle_log = lines.duplicate()

func _log(line: String) -> void:
	battle_log.append(line)
	while battle_log.size() > 8:
		battle_log.remove_at(0)

func _emit_changed() -> void:
	dungeon_changed.emit()
