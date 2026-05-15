class_name ItemInstance
extends RefCounted

var template_id: String
var rarity: String = "common"
var level: int = 1
var bonuses: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"template_id": template_id,
		"rarity": rarity,
		"level": level,
		"bonuses": bonuses
	}

static func from_dict(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.template_id = data.get("template_id", "")
	item.rarity = data.get("rarity", "common")
	item.level = data.get("level", 1)
	item.bonuses = data.get("bonuses", {})
	return item
