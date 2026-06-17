class_name UnitManager
extends Node

const PROFESSION_WORKER := "worker"
const PROFESSION_BUILDER := "builder"
const PROFESSION_INFANTRY := "infantry"

const EQUIPMENT_TO_PROFESSION := {
	"flint_axe": PROFESSION_WORKER,
	"building_tools": PROFESSION_BUILDER,
	"spear": PROFESSION_INFANTRY,
}


func profession_for_equipment(equipment_id: String) -> String:
	return EQUIPMENT_TO_PROFESSION.get(equipment_id, PROFESSION_WORKER)


func build_unit_stats(equipment_id: String, experience: int = 0) -> Dictionary:
	var profession := profession_for_equipment(equipment_id)
	var stats := {
		"profession": profession,
		"health": 100,
		"morale": 50 + experience,
		"fatigue": 0,
		"armor": 0,
		"damage": 4,
		"movement_speed": 4.0,
		"equipment_quality": 1,
		"experience": experience,
	}

	match profession:
		PROFESSION_BUILDER:
			stats["damage"] = 3
			stats["equipment_quality"] = 2
		PROFESSION_INFANTRY:
			stats["armor"] = 5
			stats["damage"] = 9
			stats["movement_speed"] = 3.6

	return stats
