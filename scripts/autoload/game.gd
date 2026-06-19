extends Node

signal world_state_changed
signal battle_started(cell_id: String)
signal battle_finished(cell_id: String, victory: bool)

const WorldStateScript = preload("res://scripts/data/world_state.gd")
const SaveManagerScript = preload("res://scripts/managers/save_manager.gd")
const CAMPAIGN_SAVE_PATH := "user://campaign.json"
const WORLD_ROTATION_SPEED := 0.025

var world_state
var current_cell_id := ""
var event_log: Array[String] = []
var world_visual_cache: Dictionary = {}
var rts_cell_cache: Dictionary = {}
var battle_sun_direction := Vector3(0.45, 0.82, 0.35).normalized()
var battle_sun_amount := 0.82
var battle_cell_normal := Vector3.UP
var battle_sun_planet_direction := Vector3(0.45, 0.82, 0.35).normalized()
var battle_sun_elapsed := 0.0
var keyboard_uses_azerty := false


func _ready() -> void:
	refresh_keyboard_layout()


func new_campaign(seed: int = 0, width: int = 24, height: int = 12) -> void:
	clear_world_visual_cache()
	clear_rts_cell_cache()
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


func set_battle_sun_context(local_sun_direction: Vector3, sunlight_amount: float) -> void:
	battle_sun_direction = local_sun_direction.normalized()
	battle_sun_amount = clamp(sunlight_amount, -1.0, 1.0)


func set_battle_sun_context_for_cell(cell_normal: Vector3, sun_planet_direction: Vector3) -> void:
	battle_cell_normal = cell_normal.normalized()
	battle_sun_planet_direction = sun_planet_direction.normalized()
	battle_sun_elapsed = 0.0
	_refresh_battle_sun_context()


func advance_battle_sun(delta: float) -> void:
	battle_sun_elapsed += WORLD_ROTATION_SPEED * delta
	_refresh_battle_sun_context()


func get_battle_sun_direction() -> Vector3:
	return battle_sun_direction


func get_battle_sun_amount() -> float:
	return battle_sun_amount


func _refresh_battle_sun_context() -> void:
	var sun_planet := battle_sun_planet_direction.rotated(Vector3.UP, -battle_sun_elapsed).normalized()
	battle_sun_direction = _sun_direction_for_cell_view(battle_cell_normal, sun_planet)
	battle_sun_amount = clamp(battle_cell_normal.dot(sun_planet), -1.0, 1.0)


func _sun_direction_for_cell_view(cell_normal: Vector3, sun_planet_direction: Vector3) -> Vector3:
	var up := cell_normal.normalized()
	var east := Vector3.UP.cross(up)
	if east.length_squared() < 0.0001:
		east = Vector3.RIGHT
	east = east.normalized()
	var north := up.cross(east).normalized()
	return Vector3(
		sun_planet_direction.dot(east),
		sun_planet_direction.dot(up),
		sun_planet_direction.dot(north)
	).normalized()


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
	clear_world_visual_cache()
	clear_rts_cell_cache()
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


func clear_world_visual_cache() -> void:
	world_visual_cache.clear()


func get_world_visual_cache(cache_key: String):
	return world_visual_cache.get(cache_key)


func set_world_visual_cache(cache_key: String, value) -> void:
	world_visual_cache[cache_key] = value


func clear_rts_cell_cache() -> void:
	rts_cell_cache.clear()


func get_rts_cell_cache(cache_key: String):
	return rts_cell_cache.get(cache_key)


func set_rts_cell_cache(cache_key: String, value) -> void:
	rts_cell_cache[cache_key] = value


func refresh_keyboard_layout() -> void:
	keyboard_uses_azerty = false
	var layout_index := DisplayServer.keyboard_get_current_layout()
	if layout_index < 0:
		return

	var layout_name := DisplayServer.keyboard_get_layout_name(layout_index).to_lower()
	var layout_language := DisplayServer.keyboard_get_layout_language(layout_index).to_lower()
	keyboard_uses_azerty = (
		layout_name.contains("azerty")
		or layout_name.contains("belg")
		or layout_name.contains("french")
		or layout_language.begins_with("fr")
		or layout_language.contains("_be")
		or layout_language.contains("-be")
	)


func movement_layout_label() -> String:
	return "ZQSD" if keyboard_uses_azerty else "WASD"


func is_move_forward_pressed() -> bool:
	return Input.is_key_pressed(KEY_UP) or _is_layout_key_pressed(KEY_W, KEY_Z)


func is_move_back_pressed() -> bool:
	return Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)


func is_move_left_pressed() -> bool:
	return Input.is_key_pressed(KEY_LEFT) or _is_layout_key_pressed(KEY_A, KEY_Q)


func is_move_right_pressed() -> bool:
	return Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)


func _is_layout_key_pressed(qwerty_key: int, azerty_key: int) -> bool:
	if keyboard_uses_azerty:
		return Input.is_key_pressed(azerty_key) or Input.is_key_pressed(qwerty_key)
	return Input.is_key_pressed(qwerty_key) or Input.is_key_pressed(azerty_key)
