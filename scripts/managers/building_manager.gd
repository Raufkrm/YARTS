class_name BuildingManager
extends Node

const BuildingDataScript = preload("res://scripts/data/rts_building_data.gd")

const BUILDING_COSTS := {
	"town_center": {
		"wood": 40,
		"stone": 10,
	},
	"supply_depot": {
		"wood": 35,
		"stone": 8,
	},
	"workshop": {
		"wood": 60,
		"stone": 25,
	},
	"barracks": {
		"wood": 70,
		"stone": 20,
	},
	"house": {
		"wood": 18,
	},
	"tent": {
		"wood": 8,
	},
	"road": {
		"stone": 2,
	},
}


func create_building(
	building_id: String,
	building_type: String,
	faction_id: String = "player",
	position: Vector3 = Vector3.ZERO,
	rotation_y: float = 0.0
):
	var building = BuildingDataScript.new()
	building.id = building_id
	building.apply_definition(building_type)
	building.faction_id = faction_id
	building.position = position
	building.rotation_y = rotation_y
	return building


func cost_for(building_type: String) -> Dictionary:
	return BUILDING_COSTS.get(building_type, {}).duplicate(true)


func can_construct(resources: Dictionary, building_type: String) -> bool:
	var cost := cost_for(building_type)
	for resource_name in cost.keys():
		if int(resources.get(resource_name, 0)) < int(cost[resource_name]):
			return false
	return true


func pay_construction_cost(resources: Dictionary, building_type: String) -> bool:
	var cost := cost_for(building_type)
	if not can_construct(resources, building_type):
		return false
	for resource_name in cost.keys():
		resources[resource_name] = int(resources.get(resource_name, 0)) - int(cost[resource_name])
	return true
