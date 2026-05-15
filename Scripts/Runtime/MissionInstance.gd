class_name MissionInstance
extends RefCounted

var id: String
var status: String = "available"
var end_cost: int = 0
var started_at: float = 0.0

func _init(mission_id: String = "", stamina_cost: int = 0) -> void:
	id = mission_id
	end_cost = stamina_cost

func to_dict() -> Dictionary:
	return {
		"id": id,
		"status": status,
		"end_cost": end_cost,
		"started_at": started_at
	}

static func from_dict(data: Dictionary) -> MissionInstance:
	var instance := MissionInstance.new(
		data.get("id", ""),
		data.get("end_cost", 0)
	)
	instance.status = data.get("status", "available")
	instance.started_at = data.get("started_at", 0.0)
	return instance
