class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://campaign.json"
const WorldStateScript = preload("res://scripts/data/world_state.gd")


func save_world_state(world_state) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed. File error: %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(world_state.to_dict(), "\t"))
	return true


func load_world_state():
	if not FileAccess.file_exists(SAVE_PATH):
		return null

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Load failed. File error: %s" % FileAccess.get_open_error())
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Load failed. Save data is not a dictionary.")
		return null

	var world_state = WorldStateScript.new()
	world_state.load_from_dict(parsed)
	return world_state
