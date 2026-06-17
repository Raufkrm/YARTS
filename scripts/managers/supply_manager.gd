class_name SupplyManager
extends Node

const TOWN_CENTER_SUPPLY_RADIUS_METERS := 100.0
const UNSUPPLIED_DAMAGE_MULTIPLIER := 1.25
const UNSUPPLIED_EFFECTIVENESS_MULTIPLIER := 0.75


func is_cell_connected_to_player_supply(world_state, cell_id: String) -> bool:
	if world_state == null:
		return false

	var cell = world_state.get_cell(cell_id)
	if cell == null:
		return false

	if cell.is_player_owned():
		return true

	for neighbor in world_state.get_neighbors(cell_id):
		if neighbor.is_player_owned():
			return true
	return false


func supply_status_for_unit(distance_to_supply_source: float) -> Dictionary:
	var supplied := distance_to_supply_source <= TOWN_CENTER_SUPPLY_RADIUS_METERS
	return {
		"supplied": supplied,
		"damage_taken_multiplier": 1.0 if supplied else UNSUPPLIED_DAMAGE_MULTIPLIER,
		"effectiveness_multiplier": 1.0 if supplied else UNSUPPLIED_EFFECTIVENESS_MULTIPLIER,
	}
