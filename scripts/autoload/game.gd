extends Node

signal world_state_changed
signal battle_started(cell_id: String)
signal battle_finished(cell_id: String, victory: bool)

const WorldStateScript = preload("res://scripts/data/world_state.gd")
const SaveManagerScript = preload("res://scripts/managers/save_manager.gd")
const CAMPAIGN_SAVE_PATH := "user://campaign.json"
const WORLD_ROTATION_SPEED := 0.025
const YARTS_DEFAULT_CURSOR_PATH := "res://assets/sprites/ui/yarts_default_cursor.svg"
const YARTS_THING_SELECTED_CURSOR_PATH := "res://assets/sprites/ui/yarts_thing_selected_cursor.svg"
const YARTS_BUILD_CURSOR_PATH := "res://assets/sprites/ui/yarts_build_cursor.svg"
const YARTS_ATTACK_CURSOR_PATH := "res://assets/sprites/ui/yarts_attack_cursor.svg"
const YARTS_INTERACT_CURSOR_PATH := "res://assets/sprites/ui/yarts_interact_cursor.svg"
const YARTS_AUTO_MOVE_CURSOR_PATH := "res://assets/sprites/ui/yarts_auto_move_cursor.svg"
const YARTS_REPAIR_CURSOR_PATH := "res://assets/sprites/ui/yarts_repair_cursor.svg"
const YARTS_SCAVENGE_CURSOR_PATH := "res://assets/sprites/ui/yarts_scavenge_cursor.svg"
const YARTS_CURSOR_SOURCE_SIZE := Vector2i(56, 56)
const YARTS_CURSOR_DISPLAY_SCALE := 0.5
const YARTS_CURSOR_HOTSPOT := Vector2(2.5, 2.5)

var world_state
var current_cell_id := ""
var event_log: Array[String] = []
var world_visual_cache: Dictionary = {}
var rts_cell_cache: Dictionary = {}
var world_rotation_angle := 0.0
var battle_sun_direction := Vector3(0.45, 0.82, 0.35).normalized()
var battle_sun_amount := 0.82
var battle_cell_normal := Vector3.UP
var battle_sun_planet_direction := Vector3(0.45, 0.82, 0.35).normalized()
var battle_sun_elapsed := 0.0
var keyboard_uses_azerty := false
var yarts_default_cursor_texture: ImageTexture
var yarts_thing_selected_cursor_texture: ImageTexture
var yarts_build_cursor_texture: ImageTexture
var yarts_attack_cursor_texture: ImageTexture
var yarts_interact_cursor_texture: ImageTexture
var yarts_auto_move_cursor_texture: ImageTexture
var yarts_repair_cursor_texture: ImageTexture
var yarts_scavenge_cursor_texture: ImageTexture
var build_order_cursor_active := false
var attack_order_cursor_active := false
var interact_order_cursor_active := false
var auto_move_order_cursor_active := false
var repair_order_cursor_active := false
var scavenge_order_cursor_active := false
var thing_selected_cursor_active := false
var active_cursor_name := "default"
var campaign_start_pending := false


func _ready() -> void:
	_apply_yarts_cursor()
	refresh_keyboard_layout()


func _apply_yarts_cursor() -> void:
	yarts_default_cursor_texture = _load_svg_cursor(YARTS_DEFAULT_CURSOR_PATH)
	yarts_thing_selected_cursor_texture = _load_svg_cursor(YARTS_THING_SELECTED_CURSOR_PATH)
	yarts_build_cursor_texture = _load_svg_cursor(YARTS_BUILD_CURSOR_PATH)
	yarts_attack_cursor_texture = _load_svg_cursor(YARTS_ATTACK_CURSOR_PATH)
	yarts_interact_cursor_texture = _load_svg_cursor(YARTS_INTERACT_CURSOR_PATH)
	yarts_auto_move_cursor_texture = _load_svg_cursor(YARTS_AUTO_MOVE_CURSOR_PATH)
	yarts_repair_cursor_texture = _load_svg_cursor(YARTS_REPAIR_CURSOR_PATH)
	yarts_scavenge_cursor_texture = _load_svg_cursor(YARTS_SCAVENGE_CURSOR_PATH)
	_refresh_yarts_cursor()


func set_build_order_cursor_active(active: bool) -> void:
	build_order_cursor_active = active
	if active:
		attack_order_cursor_active = false
		interact_order_cursor_active = false
		auto_move_order_cursor_active = false
		repair_order_cursor_active = false
		scavenge_order_cursor_active = false
	_refresh_yarts_cursor()


func is_build_order_cursor_active() -> bool:
	return build_order_cursor_active


func set_attack_order_cursor_active(active: bool) -> void:
	attack_order_cursor_active = active
	if active:
		build_order_cursor_active = false
		interact_order_cursor_active = false
		auto_move_order_cursor_active = false
		repair_order_cursor_active = false
		scavenge_order_cursor_active = false
	_refresh_yarts_cursor()


func is_attack_order_cursor_active() -> bool:
	return attack_order_cursor_active


func set_interact_order_cursor_active(active: bool) -> void:
	interact_order_cursor_active = active
	if active:
		build_order_cursor_active = false
		attack_order_cursor_active = false
		auto_move_order_cursor_active = false
		repair_order_cursor_active = false
		scavenge_order_cursor_active = false
	_refresh_yarts_cursor()


func is_interact_order_cursor_active() -> bool:
	return interact_order_cursor_active


func set_auto_move_order_cursor_active(active: bool) -> void:
	auto_move_order_cursor_active = active
	if active:
		build_order_cursor_active = false
		attack_order_cursor_active = false
		interact_order_cursor_active = false
		repair_order_cursor_active = false
		scavenge_order_cursor_active = false
	_refresh_yarts_cursor()


func is_auto_move_order_cursor_active() -> bool:
	return auto_move_order_cursor_active


func set_repair_order_cursor_active(active: bool) -> void:
	repair_order_cursor_active = active
	if active:
		build_order_cursor_active = false
		attack_order_cursor_active = false
		interact_order_cursor_active = false
		auto_move_order_cursor_active = false
		scavenge_order_cursor_active = false
	_refresh_yarts_cursor()


func is_repair_order_cursor_active() -> bool:
	return repair_order_cursor_active


func set_scavenge_order_cursor_active(active: bool) -> void:
	scavenge_order_cursor_active = active
	if active:
		build_order_cursor_active = false
		attack_order_cursor_active = false
		interact_order_cursor_active = false
		auto_move_order_cursor_active = false
		repair_order_cursor_active = false
	_refresh_yarts_cursor()


func is_scavenge_order_cursor_active() -> bool:
	return scavenge_order_cursor_active


func set_thing_selected_cursor_active(active: bool) -> void:
	if thing_selected_cursor_active == active:
		return
	thing_selected_cursor_active = active
	_refresh_yarts_cursor()


func is_thing_selected_cursor_active() -> bool:
	return thing_selected_cursor_active


func get_active_cursor_name() -> String:
	return active_cursor_name


func reset_order_cursor() -> void:
	build_order_cursor_active = false
	attack_order_cursor_active = false
	interact_order_cursor_active = false
	auto_move_order_cursor_active = false
	repair_order_cursor_active = false
	scavenge_order_cursor_active = false
	_refresh_yarts_cursor()


func _refresh_yarts_cursor() -> void:
	var cursor_texture: Texture2D = yarts_thing_selected_cursor_texture if thing_selected_cursor_active else yarts_default_cursor_texture
	active_cursor_name = "thing_selected" if thing_selected_cursor_active else "default"
	if thing_selected_cursor_active and attack_order_cursor_active:
		cursor_texture = yarts_attack_cursor_texture
		active_cursor_name = "attack"
	elif thing_selected_cursor_active and build_order_cursor_active:
		cursor_texture = yarts_build_cursor_texture
		active_cursor_name = "build"
	elif thing_selected_cursor_active and interact_order_cursor_active:
		cursor_texture = yarts_interact_cursor_texture
		active_cursor_name = "interact"
	elif thing_selected_cursor_active and auto_move_order_cursor_active:
		cursor_texture = yarts_auto_move_cursor_texture
		active_cursor_name = "auto_move"
	elif thing_selected_cursor_active and repair_order_cursor_active:
		cursor_texture = yarts_repair_cursor_texture
		active_cursor_name = "repair"
	elif thing_selected_cursor_active and scavenge_order_cursor_active:
		cursor_texture = yarts_scavenge_cursor_texture
		active_cursor_name = "scavenge"
	if cursor_texture == null:
		return
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, YARTS_CURSOR_HOTSPOT)
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_POINTING_HAND, YARTS_CURSOR_HOTSPOT)


func _load_svg_cursor(path: String) -> ImageTexture:
	var svg_source := FileAccess.get_file_as_string(path)
	if svg_source.is_empty():
		push_warning("Could not load cursor source: %s" % path)
		return null
	var cursor_image := Image.new()
	var load_error := cursor_image.load_svg_from_string(svg_source)
	if load_error != OK:
		push_warning("Could not decode cursor %s: %s" % [path, error_string(load_error)])
		return null
	if cursor_image.get_size() != YARTS_CURSOR_SOURCE_SIZE:
		cursor_image.resize(YARTS_CURSOR_SOURCE_SIZE.x, YARTS_CURSOR_SOURCE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	# Keep the authored SVGs at full resolution and scale only the OS cursor image.
	var display_size := Vector2i(
		int(round(float(YARTS_CURSOR_SOURCE_SIZE.x) * YARTS_CURSOR_DISPLAY_SCALE)),
		int(round(float(YARTS_CURSOR_SOURCE_SIZE.y) * YARTS_CURSOR_DISPLAY_SCALE))
	)
	cursor_image.resize(display_size.x, display_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cursor_image)


func begin_campaign_start() -> void:
	clear_world_visual_cache()
	clear_rts_cell_cache()
	reset_world_time()
	world_state = null
	current_cell_id = ""
	campaign_start_pending = true
	debug_event("campaign_start_requested")


func new_campaign(seed: int = 0, width: int = 24, height: int = 12) -> void:
	clear_world_visual_cache()
	clear_rts_cell_cache()
	reset_world_time()
	world_state = WorldStateScript.new()
	world_state.create_new(seed, width, height)
	current_cell_id = ""
	campaign_start_pending = true
	debug_event("game_start")
	debug_event("new_campaign width=%d height=%d seed=%d" % [width, height, world_state.seed])
	world_state_changed.emit()


func settle_player_start(cell_id: String) -> bool:
	if world_state == null or not world_state.settle_starting_cell(cell_id, "player"):
		return false
	current_cell_id = cell_id
	campaign_start_pending = false
	debug_event("starting_cell_settled cell=%s color=%s intel=1" % [cell_id, get_faction_color("player").to_html(false)])
	world_state_changed.emit()
	return true


func get_faction_color(faction_id: String = "player") -> Color:
	if world_state == null:
		return Color("3568b8")
	return world_state.get_faction_color(faction_id)


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


func reset_world_time() -> void:
	world_rotation_angle = 0.0
	battle_sun_elapsed = 0.0
	_refresh_battle_sun_context()


func advance_world_time(delta: float) -> float:
	var angle_step := WORLD_ROTATION_SPEED * delta
	world_rotation_angle = wrapf(world_rotation_angle + angle_step, -PI, PI)
	return angle_step


func get_world_rotation_angle() -> float:
	return world_rotation_angle


func advance_battle_sun(delta: float) -> void:
	battle_sun_elapsed += advance_world_time(delta)
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
	campaign_start_pending = world_state.starting_cell_id.is_empty()
	reset_world_time()
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
