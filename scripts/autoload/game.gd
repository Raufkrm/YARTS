extends Node

signal world_state_changed
signal battle_started(cell_id: String)
signal battle_finished(cell_id: String, victory: bool)

const WorldStateScript = preload("res://scripts/data/world_state.gd")
const SaveManagerScript = preload("res://scripts/managers/save_manager.gd")
const CAMPAIGN_SAVE_PATH := "user://campaign.json"

var world_state
var current_cell_id := ""
var event_log: Array[String] = []


func _ready() -> void:
	if world_state == null:
		new_campaign()


func new_campaign(seed: int = 0, width: int = 24, height: int = 12) -> void:
	world_state = WorldStateScript.new()
	world_state.create_new(seed, width, height)
	current_cell_id = world_state.starting_cell_id
	debug_event("game_start")
	debug_event("new_campaign width=%d height=%d seed=%d" % [width, height, world_state.seed])
	world_state_changed.emit()


func start_battle(cell_id: String) -> void:
	if world_state == null or world_state.get_cell(cell_id) == null:
		push_warning("Cannot start battle. Unknown cell: %s" % cell_id)
		return

	current_cell_id = cell_id
	debug_event("battle_loaded cell=%s" % cell_id)
	battle_started.emit(cell_id)
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")


func finish_battle(victory: bool) -> void:
	if world_state == null or current_cell_id.is_empty():
		return

	if victory:
		world_state.conquer_cell(current_cell_id, "player")
		debug_event("ownership_changed cell=%s owner=player" % current_cell_id)

	debug_event("battle_finished cell=%s victory=%s" % [current_cell_id, str(victory)])
	battle_finished.emit(current_cell_id, victory)
	world_state_changed.emit()
	get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")


func save_campaign() -> bool:
	if world_state == null:
		return false

	var save_manager = SaveManagerScript.new()
	var saved: bool = save_manager.save_world_state(world_state)
	if saved:
		debug_event("save_completed path=%s" % CAMPAIGN_SAVE_PATH)
	return saved


func load_campaign() -> bool:
	var save_manager = SaveManagerScript.new()
	var loaded_state = save_manager.load_world_state()
	if loaded_state == null:
		push_warning("No valid campaign save found.")
		return false

	world_state = loaded_state
	current_cell_id = world_state.starting_cell_id
	debug_event("save_loaded path=%s" % CAMPAIGN_SAVE_PATH)
	world_state_changed.emit()
	return true


func get_current_cell():
	if world_state == null or current_cell_id.is_empty():
		return null
	return world_state.get_cell(current_cell_id)


func debug_event(message: String) -> void:
	var stamped := "%s | %s" % [Time.get_datetime_string_from_system(false, true), message]
	event_log.append(stamped)
	if event_log.size() > 100:
		event_log.pop_front()
	print(stamped)


func get_recent_events(max_events: int = 8) -> Array[String]:
	var start_index := event_log.size() - max_events
	if start_index < 0:
		start_index = 0
	return event_log.slice(start_index, event_log.size())
