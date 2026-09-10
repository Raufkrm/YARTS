class_name UnitManager
extends Node

const UnitDataScript = preload("res://scripts/data/rts_unit_data.gd")
const EquipmentDefinitionScript = preload("res://scripts/data/rts_equipment_definition.gd")

const PROFESSION_WORKER := "worker"
const PROFESSION_BUILDER := "builder"
const PROFESSION_INFANTRY := "infantry"

var equipment_definitions: Dictionary = {}


func _init() -> void:
	_register_default_equipment()


func profession_for_equipment(equipment_id: String) -> String:
	return equipment_definition_for(equipment_id).profession


func build_unit_stats(equipment_id: String, experience: int = 0) -> Dictionary:
	return equipment_definition_for(equipment_id).build_stats(experience)


func equipment_definition_for(equipment_id: String):
	if equipment_definitions.is_empty():
		_register_default_equipment()
	return equipment_definitions.get(equipment_id, equipment_definitions.get("flint_axe"))


func create_unit(unit_id: String, faction_id: String = "player", equipment_id: String = "flint_axe", position: Vector3 = Vector3.ZERO, experience: int = 0):
	var unit = UnitDataScript.new()
	unit.id = unit_id
	unit.display_name = _display_name_for_equipment(equipment_id)
	unit.faction_id = faction_id
	unit.equipment_id = equipment_id
	unit.position = position
	unit.apply_stats(build_unit_stats(equipment_id, experience))
	return unit


func unit_from_dict(data: Dictionary):
	var unit = UnitDataScript.new()
	unit.load_from_dict(data)
	return unit


func change_equipment(unit, equipment_id: String) -> void:
	if unit == null:
		return
	unit.equipment_id = equipment_id
	unit.display_name = _display_name_for_equipment(equipment_id)
	unit.apply_stats(build_unit_stats(equipment_id, int(unit.experience)))


func _display_name_for_equipment(equipment_id: String) -> String:
	return equipment_definition_for(equipment_id).display_name


func _register_default_equipment() -> void:
	if not equipment_definitions.is_empty():
		return

	_register_equipment({
		"id": "flint_axe",
		"display_name": "Worker",
		"profession": PROFESSION_WORKER,
		"damage": 4,
		"movement_speed": 4.0,
		"equipment_quality": 1,
	})
	_register_equipment({
		"id": "building_tools",
		"display_name": "Builder",
		"profession": PROFESSION_BUILDER,
		"damage": 3,
		"movement_speed": 4.0,
		"equipment_quality": 2,
	})
	_register_equipment({
		"id": "spear",
		"display_name": "Spearman",
		"profession": PROFESSION_INFANTRY,
		"armor": 5,
		"damage": 9,
		"movement_speed": 3.6,
		"equipment_quality": 1,
	})


func _register_equipment(definition: Dictionary) -> void:
	var equipment = EquipmentDefinitionScript.new(definition)
	if equipment.id.is_empty():
		return
	equipment_definitions[equipment.id] = equipment
