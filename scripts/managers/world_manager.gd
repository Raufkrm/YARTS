class_name WorldManager
extends Node

signal cell_selected(cell)
signal ownership_changed(cell)

var world_state


func setup(state) -> void:
	world_state = state


func select_cell(cell_id: String):
	if world_state == null:
		return null

	var cell = world_state.get_cell(cell_id)
	if cell != null:
		cell_selected.emit(cell)
	return cell


func conquer_cell(cell_id: String, owner_id: String) -> void:
	if world_state == null:
		return

	world_state.conquer_cell(cell_id, owner_id)
	var cell = world_state.get_cell(cell_id)
	if cell != null:
		ownership_changed.emit(cell)


func advance_world_day(days: int = 1) -> void:
	if world_state == null:
		return

	world_state.world_day += max(1, days)
