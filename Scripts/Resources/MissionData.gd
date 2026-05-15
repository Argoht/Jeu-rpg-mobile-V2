class_name MissionData
extends Resource

## Énumérations pour structurer les données proprement
enum Rank { F, E, D, C, B, A, S }
enum MissionType { QUOTIDIENNE, HEBDOMADAIRE }
enum Stat { AUCUNE, STR, DEX, VIT, INT, WIS, CHA, PER, WIL }

@export_category("Informations Générales")
@export var id: String = "mission_001"
@export var title: String = "Nouvelle Mission"
@export_multiline var description: String = "Description de la tâche IRL..."
@export var rank: Rank = Rank.F
@export var type: MissionType = MissionType.QUOTIDIENNE

@export_category("Pré-requis des Statistiques")
@export var req_str: int = 0
@export var req_dex: int = 0
@export var req_end: int = 0
@export var req_int: int = 0
@export var req_wis: int = 0
@export var req_cha: int = 0
@export var req_per: int = 0
@export var req_wil: int = 0

@export_category("Récompenses de Base")
@export var base_xp: int = 50
@export var reward_stat: Stat = Stat.AUCUNE
@export var reward_stat_amount: int = 0

func get_requirement_map() -> Dictionary:
	return StatTypes.normalize_requirements({
		"STR": req_str,
		"AGI": req_dex,
		"STAMINA": req_end,
		"INT": req_int,
		"wis": req_wis,
		"cha": req_cha,
		"per": req_per,
		"WIL": req_wil,
	})

func get_reward_stat_key() -> String:
	match reward_stat:
		Stat.STR:
			return StatTypes.KEY_STR
		Stat.DEX:
			return StatTypes.KEY_AGI
		Stat.VIT:
			return StatTypes.KEY_HP
		Stat.INT:
			return StatTypes.KEY_INT
		Stat.WIS, Stat.CHA, Stat.PER, Stat.WIL:
			return StatTypes.KEY_WIL
	return ""
