class_name RTSUnitActor
extends Node3D

var unit_data
var unit_id := ""
var faction_id := ""
var profession := ""
var equipment_id := ""
var current_order
var current_gather_action
var current_delivery_action
var carried_resources: Dictionary = {}
var carry_capacity := 20
var animation_player: AnimationPlayer
var current_animation := ""
var current_animation_speed := 1.0
var queued_animation := ""
var queued_animation_blend := 0.18
var queued_animation_speed := 1.0
var queued_animation_delay := 0.0


func configure(data) -> void:
	unit_data = data
	unit_id = str(data.id)
	faction_id = str(data.faction_id)
	profession = str(data.profession)
	equipment_id = str(data.equipment_id)
	name = "Unit_%s" % unit_id
	position = data.position
	set_meta("rts_entity_type", "unit")
	set_meta("rts_entity_id", unit_id)
	set_meta("rts_profession", profession)
	set_meta("rts_equipment", equipment_id)


func set_animation_player(player: AnimationPlayer) -> void:
	animation_player = player


func reset_skeleton_pose() -> void:
	if animation_player != null and is_instance_valid(animation_player):
		animation_player.stop()
		animation_player.clear_caches()
	for candidate in find_children("*", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton != null:
			skeleton.reset_bone_poses()
	current_animation = ""
	current_animation_speed = 1.0
	set_meta("current_animation", "")


func play_animation(animation_name: String, blend_time: float = 0.18, playback_speed: float = 1.0) -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		return
	if not animation_player.has_animation(animation_name):
		return

	var clamped_speed: float = max(0.05, playback_speed)
	animation_player.speed_scale = 1.0
	if current_animation == animation_name and is_equal_approx(current_animation_speed, clamped_speed) and animation_player.is_playing():
		return

	animation_player.play(animation_name, blend_time, clamped_speed)
	current_animation = animation_name
	current_animation_speed = clamped_speed
	set_meta("current_animation", current_animation)
	set_meta("current_animation_speed", current_animation_speed)


func set_animation_paused(paused: bool) -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		return
	var target_speed_scale := 0.0 if paused else 1.0
	if is_equal_approx(animation_player.speed_scale, target_speed_scale):
		return
	animation_player.speed_scale = target_speed_scale
	set_meta("animation_paused", paused)


func issue_move_order(order, cancel_gather_action: bool = true) -> void:
	current_order = order
	if cancel_gather_action:
		clear_gather_action()
		clear_delivery_action()


func clear_move_order() -> void:
	current_order = null


func has_move_order() -> bool:
	return current_order != null


func issue_gather_action(action) -> void:
	current_gather_action = action
	current_delivery_action = null
	clear_move_order()


func clear_gather_action() -> void:
	current_gather_action = null


func has_gather_action() -> bool:
	return current_gather_action != null


func gather_action():
	return current_gather_action


func issue_delivery_action(action) -> void:
	current_delivery_action = action
	clear_gather_action()
	clear_move_order()


func clear_delivery_action() -> void:
	current_delivery_action = null


func has_delivery_action() -> bool:
	return current_delivery_action != null


func delivery_action():
	return current_delivery_action


func move_order_target() -> Vector3:
	if current_order == null:
		return position
	return current_order.target


func update_movement(delta: float, ground_position_provider: Callable, arrival_radius: float, idle_animation: String = "") -> bool:
	if current_order == null or unit_data == null:
		return false

	var target: Vector3 = current_order.target
	var current := position
	var to_target := Vector3(target.x - current.x, 0.0, target.z - current.z)
	var distance := to_target.length()
	if distance <= arrival_radius:
		position = _ground_position(ground_position_provider, current.x, current.z)
		unit_data.position = position
		clear_move_order()
		if not idle_animation.is_empty():
			play_animation(idle_animation)
		return true

	var direction: Vector3 = to_target / max(distance, 0.001)
	var speed: float = max(0.5, float(unit_data.movement_speed) * current_order.speed_multiplier)
	var step: float = min(distance, speed * delta)
	var next_position: Vector3 = current + direction * step
	position = _ground_position(ground_position_provider, next_position.x, next_position.z)
	unit_data.position = position
	face_direction(direction)
	return false


func face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	rotation.y = atan2(flat_direction.x, flat_direction.z)


func face_position(target: Vector3) -> void:
	face_direction(Vector3(target.x - position.x, 0.0, target.z - position.z))


func add_carried_resource(resource_type: String, amount: int) -> int:
	var clamped_amount: int = max(0, amount)
	if clamped_amount <= 0:
		return 0
	var accepted: int = min(clamped_amount, remaining_carry_capacity())
	if accepted <= 0:
		return 0
	carried_resources[resource_type] = int(carried_resources.get(resource_type, 0)) + accepted
	return accepted


func carried_total() -> int:
	var total := 0
	for amount_value in carried_resources.values():
		total += int(amount_value)
	return total


func remaining_carry_capacity() -> int:
	return max(0, carry_capacity - carried_total())


func clear_carried_resources() -> void:
	carried_resources.clear()


func queue_animation(animation_name: String, delay: float, blend_time: float = 0.18, playback_speed: float = 1.0) -> void:
	queued_animation = animation_name
	queued_animation_delay = max(0.0, delay)
	queued_animation_blend = blend_time
	queued_animation_speed = playback_speed


func update_animation_queue(delta: float) -> void:
	if queued_animation.is_empty():
		return
	queued_animation_delay -= delta
	if queued_animation_delay > 0.0:
		return
	var animation_name := queued_animation
	var blend_time := queued_animation_blend
	var playback_speed := queued_animation_speed
	queued_animation = ""
	play_animation(animation_name, blend_time, playback_speed)


func _ground_position(ground_position_provider: Callable, x: float, z: float) -> Vector3:
	if ground_position_provider.is_valid():
		var ground_position = ground_position_provider.call(x, z)
		if ground_position is Vector3:
			return ground_position
	return Vector3(x, position.y, z)
