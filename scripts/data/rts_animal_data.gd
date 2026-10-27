extends Resource

var id := ""
var species := "sheep"
var coat := "brown"
var owner_id := "neutral"
var position := Vector3.ZERO
var rotation_y := 0.0
var home := Vector3.ZERO
var herd_id := ""
var health := 60
var max_health := 60
var command := "wild"
var follow_id := ""
var target := Vector3.ZERO
var legacy_capture: Dictionary = {}
var behavior := "grazing"

func to_dict() -> Dictionary:
	return {"id": id, "species": species, "coat": coat, "owner_id": owner_id,
		"position": [position.x, position.y, position.z], "rotation_y": rotation_y,
		"home": [home.x, home.y, home.z], "herd_id": herd_id, "health": health,
		"max_health": max_health, "command": command, "follow_id": follow_id,
		"target": [target.x, target.y, target.z], "behavior": behavior}

func load_from_dict(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	species = str(data.get("species", "sheep"))
	coat = str(data.get("coat", "brown"))
	owner_id = str(data.get("owner_id", "neutral"))
	position = _vector(data.get("position", [0, 0, 0]))
	home = _vector(data.get("home", data.get("position", [0, 0, 0])))
	target = _vector(data.get("target", data.get("position", [0, 0, 0])))
	rotation_y = float(data.get("rotation_y", 0))
	herd_id = str(data.get("herd_id", ""))
	health = int(data.get("health", 60))
	max_health = int(data.get("max_health", health))
	command = str(data.get("command", "wild"))
	follow_id = str(data.get("follow_id", ""))
	legacy_capture = data.get("capture", {}).duplicate(true)
	behavior = str(data.get("behavior", "grazing"))

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
