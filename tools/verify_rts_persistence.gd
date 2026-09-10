extends SceneTree

const CellDataScript = preload("res://scripts/data/cell_data.gd")
const UnitManagerScript = preload("res://scripts/managers/unit_manager.gd")
const BuildingDataScript = preload("res://scripts/data/rts_building_data.gd")


func _init() -> void:
	var unit_manager = UnitManagerScript.new()
	var unit = unit_manager.create_unit("persistence_probe", "player", "flint_axe", Vector3(317.5, 8.25, -441.75), 3)
	var cell = CellDataScript.new()
	cell.id = "C_test"
	var storage = BuildingDataScript.new()
	storage.id = "storage_probe"
	storage.apply_definition(BuildingDataScript.TYPE_SUPPLY_DEPOT)
	storage.store_resource("wood", 5)
	cell.rts_state = {
		"version": 2,
		"units": [unit.to_dict()],
		"unit_runtime": {"persistence_probe": {"carried_resources": {"wood": 5}}},
		"buildings": [storage.to_dict()],
		"resources": {"res_00001": {"amount_remaining": 5, "depleted": false, "stage": "felled_log", "work_progress": 1.2, "work_required": 2.4, "show_ring": true}},
	}

	var restored_cell = CellDataScript.new()
	restored_cell.load_from_dict(cell.to_dict())
	var restored_unit = unit_manager.unit_from_dict(restored_cell.rts_state["units"][0])
	assert(restored_unit.position.is_equal_approx(unit.position))
	assert(int(restored_cell.rts_state["unit_runtime"]["persistence_probe"]["carried_resources"]["wood"]) == 5)
	assert(str(restored_cell.rts_state["resources"]["res_00001"]["stage"]) == "felled_log")
	assert(is_equal_approx(float(restored_cell.rts_state["resources"]["res_00001"]["work_progress"]), 1.2))
	assert(int(restored_cell.rts_state["buildings"][0]["stored_resources"]["wood"]) == 5)
	print("RTS persistence round-trip passed: ", restored_unit.position)
	quit()
