class_name RTSUnitData
extends Resource

const PROFESSION_WORKER := "worker"
const PROFESSION_BUILDER := "builder"
const PROFESSION_INFANTRY := "infantry"

@export var id := ""
@export var display_name := "Person"
@export var faction_id := "player"
@export var profession := PROFESSION_WORKER
@export var equipment_id := "flint_axe"
@export var position := Vector3.ZERO
@export var health := 100
@export var max_health := 100
@export var stamina := 100
@export var morale := 50
@export var fatigue := 0
@export var armor := 0
@export var damage := 4
@export var movement_speed := 4.0
@export var experience := 0
@export var equipment_quality := 1
@export var supply := 100


func apply_stats(stats: Dictionary) -> void:
	profession = str(stats.get("profession", profession))
	health = int(stats.get("health", health))
	max_health = max(max_health, health)
	morale = int(stats.get("morale", morale))
	fatigue = int(stats.get("fatigue", fatigue))
	armor = int(stats.get("armor", armor))
	damage = int(stats.get("damage", damage))
	movement_speed = float(stats.get("movement_speed", movement_speed))
	equipment_quality = int(stats.get("equipment_quality", equipment_quality))
	experience = int(stats.get("experience", experience))


func can_gather() -> bool:
	return profession == PROFESSION_WORKER


func can_construct() -> bool:
	return profession == PROFESSION_WORKER or profession == PROFESSION_BUILDER


func can_fight() -> bool:
	return damage > 0


func is_alive() -> bool:
	return health > 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"faction_id": faction_id,
		"profession": profession,
		"equipment_id": equipment_id,
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z,
		},
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"morale": morale,
		"fatigue": fatigue,
		"armor": armor,
		"damage": damage,
		"movement_speed": movement_speed,
		"experience": experience,
		"equipment_quality": equipment_quality,
		"supply": supply,
	}


func load_from_dict(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	display_name = str(data.get("display_name", "Person"))
	faction_id = str(data.get("faction_id", "player"))
	profession = str(data.get("profession", PROFESSION_WORKER))
	equipment_id = str(data.get("equipment_id", "flint_axe"))
	var position_data: Dictionary = data.get("position", {})
	position = Vector3(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0)),
		float(position_data.get("z", 0.0))
	)
	health = int(data.get("health", 100))
	max_health = int(data.get("max_health", 100))
	stamina = int(data.get("stamina", 100))
	morale = int(data.get("morale", 50))
	fatigue = int(data.get("fatigue", 0))
	armor = int(data.get("armor", 0))
	damage = int(data.get("damage", 4))
	movement_speed = float(data.get("movement_speed", 4.0))
	experience = int(data.get("experience", 0))
	equipment_quality = int(data.get("equipment_quality", 1))
	supply = int(data.get("supply", 100))
