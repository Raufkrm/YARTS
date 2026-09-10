class_name RTSEquipmentDefinition
extends RefCounted

var id := ""
var display_name := "Person"
var profession := "worker"
var base_health := 100
var base_morale := 50
var base_fatigue := 0
var armor := 0
var damage := 4
var movement_speed := 4.0
var equipment_quality := 1


func _init(definition: Dictionary = {}) -> void:
	id = str(definition.get("id", id))
	display_name = str(definition.get("display_name", display_name))
	profession = str(definition.get("profession", profession))
	base_health = int(definition.get("base_health", base_health))
	base_morale = int(definition.get("base_morale", base_morale))
	base_fatigue = int(definition.get("base_fatigue", base_fatigue))
	armor = int(definition.get("armor", armor))
	damage = int(definition.get("damage", damage))
	movement_speed = float(definition.get("movement_speed", movement_speed))
	equipment_quality = int(definition.get("equipment_quality", equipment_quality))


func build_stats(experience: int = 0) -> Dictionary:
	return {
		"profession": profession,
		"health": base_health,
		"morale": base_morale + experience,
		"fatigue": base_fatigue,
		"armor": armor,
		"damage": damage,
		"movement_speed": movement_speed,
		"equipment_quality": equipment_quality,
		"experience": experience,
	}
