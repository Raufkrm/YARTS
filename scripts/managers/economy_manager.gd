class_name EconomyManager
extends Node

const STARTING_TOWN_CENTER_COST := {
	"wood": 40,
	"stone": 10,
}

const BASIC_WORKSHOP_COST := {
	"wood": 60,
	"stone": 25,
}


func can_afford(resources: Dictionary, cost: Dictionary) -> bool:
	for resource_name in cost.keys():
		if int(resources.get(resource_name, 0)) < int(cost[resource_name]):
			return false
	return true


func pay_cost(resources: Dictionary, cost: Dictionary) -> bool:
	if not can_afford(resources, cost):
		return false

	for resource_name in cost.keys():
		resources[resource_name] = int(resources.get(resource_name, 0)) - int(cost[resource_name])
	return true


func add_resources(resources: Dictionary, income: Dictionary) -> void:
	for resource_name in income.keys():
		resources[resource_name] = int(resources.get(resource_name, 0)) + int(income[resource_name])


func produce_basic_tool(resources: Dictionary) -> bool:
	var cost := {
		"wood": 5,
	}
	if not pay_cost(resources, cost):
		return false

	resources["tools"] = int(resources.get("tools", 0)) + 1
	return true


func produce_basic_weapon(resources: Dictionary) -> bool:
	var cost := {
		"wood": 4,
		"metal": 2,
	}
	if not pay_cost(resources, cost):
		return false

	resources["weapons"] = int(resources.get("weapons", 0)) + 1
	return true
