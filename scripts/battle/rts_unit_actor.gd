class_name RTSUnitActor
extends Node3D

var unit_data
var unit_id := ""
var faction_id := ""
var equipment_id := ""
var navigation
const PERSONAL_SPACE := 5.0
var movement_neighbors: Callable
var crowd_path := PackedVector3Array()
var crowd_retry_remaining := 0.0
var people_wait_time := 0.0
var action_revision := 0
var path := PackedVector3Array()
var path_revision := -1
var path_index := 0
var route_retry_remaining := 0.0
var route_failures := 0
var shortcut_remaining := 0.0
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
var kneeling_phase := ""
var kneeling_context := ""
var kneeling_remaining := 0.0
var after_kneeling_animation := "Idle"
var after_kneeling_speed := 1.0
var collected_tool_visual


func setup_collected_tool_visual(skeleton: Skeleton3D, visual_scale: float) -> void:
	if skeleton == null or skeleton.find_bone("hand_r") < 0: return
	collected_tool_visual = preload("res://scripts/props/collected_tool_visual.gd").new()
	collected_tool_visual.name = "CollectedToolGrip"
	skeleton.add_child(collected_tool_visual)
	collected_tool_visual.configure(self, visual_scale)


func configure(data) -> void:
	unit_data = data
	unit_id = str(data.id)
	faction_id = str(data.faction_id)
	equipment_id = str(data.equipment_id)
	name = "Unit_%s" % unit_id
	position = data.position
	set_meta("rts_entity_type", "unit")
	set_meta("rts_entity_id", unit_id)
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
	if kneeling_phase != "" and not animation_name.begins_with("Kneel_"):
		after_kneeling_animation = animation_name
		after_kneeling_speed = playback_speed
		return
	if animation_player == null or not is_instance_valid(animation_player):
		return
	if not animation_player.has_animation(animation_name):
		return
	if current_animation != animation_name and animation_player.has_animation(current_animation):
		var previous := animation_player.get_animation(current_animation)
		var next := animation_player.get_animation(animation_name)
		var had_position := false
		var has_position := false
		for track in range(previous.get_track_count()):
			if previous.track_get_type(track) == Animation.TYPE_POSITION_3D: had_position = true
		for track in range(next.get_track_count()):
			if next.track_get_type(track) == Animation.TYPE_POSITION_3D: has_position = true
		if had_position and not has_position:
			for skeleton in find_children("*", "Skeleton3D", true, false):
				var pelvis: int = skeleton.find_bone("pelvis")
				if pelvis >= 0: skeleton.set_bone_pose_position(pelvis, skeleton.get_bone_rest(pelvis).origin)

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
	if cancel_gather_action: finish_kneeling_work()
	if unit_data != null and unit_data.musket_combat != null:
		unit_data.musket_combat.request_move()
	current_order = order
	crowd_path.clear()
	crowd_retry_remaining = 0.0
	people_wait_time = 0.0
	set_meta("people_waiting", false)
	path_revision = -1
	path_index = 0
	path.clear()
	route_failures = 0
	route_retry_remaining = 0.0
	shortcut_remaining = float(posmod(unit_id.hash(), 200)) / 1000.0
	set_meta("route_blocked", false)
	set_meta("route_retry_after", 0)
	if cancel_gather_action:
		action_revision += 1
		clear_gather_action()
		clear_delivery_action()


# The destination search already proved this route. Reuse it only while its
# origin, target and static obstacle revision still match the new move order.
func apply_prepared_route(prepared: Dictionary) -> bool:
	if navigation == null or current_order == null or not prepared.has("route"): return false
	if int(prepared.get("revision", -1)) != navigation.revision: return false
	var origin: Vector3 = prepared.get("origin", Vector3.INF)
	var route: PackedVector3Array = prepared.route
	if origin.distance_squared_to(position) > 0.0001 or route.is_empty(): return false
	if Vector2(route[-1].x - current_order.target.x, route[-1].z - current_order.target.z).length_squared() > 0.0001: return false
	path = route.duplicate()
	path_index = 0
	path_revision = navigation.revision
	return true

func clear_move_order() -> void:
	current_order = null
	crowd_path.clear()
	people_wait_time = 0.0
	set_meta("people_waiting", false)


func has_move_order() -> bool:
	return current_order != null


func issue_gather_action(action) -> void:
	finish_kneeling_work()
	action_revision += 1
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
	finish_kneeling_work()
	action_revision += 1
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
	if kneeling_phase != "" or current_order == null or unit_data == null: return false
	crowd_retry_remaining = maxf(0.0, crowd_retry_remaining - delta)
	var goal: Vector3 = current_order.target
	var speed: float = maxf(0.5, float(unit_data.movement_speed) * current_order.speed_multiplier)
	if navigation != null:
		route_retry_remaining = maxf(0.0, route_retry_remaining - delta)
		var changed: bool = path_revision != navigation.revision
		if changed: crowd_path.clear()
		if changed or (path.is_empty() and route_failures < 3 and route_retry_remaining <= 0.0):
			if changed: route_failures = 0
			path = navigation.route(position, goal, 2.0, clampf(speed * 0.35, 4.0, 12.0))
			path_revision = navigation.revision
			path_index = 0
			if path.is_empty():
				_block_route()
				return false
			route_failures = 0
			set_meta("route_blocked", false)
			set_meta("route_retry_after", 0)
		if path.is_empty(): return false
		shortcut_remaining -= delta
		if shortcut_remaining <= 0.0:
			shortcut_remaining = 0.2
			if path_index + 1 < path.size() and navigation.segment_clear(position, goal):
				path = PackedVector3Array([navigation.ground(goal)])
				path_index = 0
	var travel := speed * maxf(0.0, delta)
	while true:
		if Vector2(position.x - goal.x, position.z - goal.z).length() <= arrival_radius and (navigation == null or navigation.segment_clear(position, goal)):
			clear_move_order()
			if not idle_animation.is_empty(): play_animation(idle_animation)
			return true
		var route_target: Vector3 = path[path_index] if navigation != null else goal
		if crowd_path.is_empty():
			var ahead := position.move_toward(route_target, 12.0)
			if not _people_segment_clear(position, ahead):
				if crowd_retry_remaining <= 0.0: _plan_people_detour(route_target)
				if crowd_path.is_empty():
					people_wait_time += delta
					set_meta("people_waiting", true)
					return false
		var following_crowd := not crowd_path.is_empty()
		var target: Vector3 = crowd_path[0] if following_crowd else route_target
		var direction := Vector3(target.x - position.x, 0.0, target.z - position.z)
		var distance := direction.length()
		var final_point: bool = not following_crowd and (navigation == null or path_index == path.size() - 1)
		# Intermediate points are reached exactly; arrival tolerance never cuts corners.
		if final_point and distance <= arrival_radius:
			if navigation != null and not navigation.segment_clear(position, goal):
				_block_route()
				return false
			clear_move_order()
			if not idle_animation.is_empty(): play_animation(idle_animation)
			return true
		if distance < 0.00001:
			if following_crowd:
				crowd_path.remove_at(0)
				continue
			path_index += 1
			shortcut_remaining = 0.0
			continue
		if travel <= 0.0: break
		var step := minf(distance, minf(travel, 1.0))
		var next_position := position + direction / distance * step
		if navigation != null and not navigation.segment_clear(position, next_position):
			_block_route()
			return false
		if not _people_segment_clear(position, next_position):
			crowd_path.clear()
			crowd_retry_remaining = maxf(crowd_retry_remaining, 0.5)
			people_wait_time += delta
			set_meta("people_waiting", true)
			return false
		people_wait_time = 0.0
		set_meta("people_waiting", false)
		var facing := next_position - position
		position = _ground_position(ground_position_provider, next_position.x, next_position.z)
		unit_data.position = position
		face_direction(facing)
		travel -= step
		if step >= distance and following_crowd:
			crowd_path.remove_at(0)
		elif step >= distance and not final_point:
			path_index += 1
			shortcut_remaining = 0.0
	return false


# Each short movement segment is swept against living people. Committed
# detour corners prevent frame-by-frame changes of avoidance direction.
func _people_segment_clear(start: Vector3, end: Vector3) -> bool:
	if not movement_neighbors.is_valid(): return true
	for other in movement_neighbors.call(start, start.distance_to(end) + PERSONAL_SPACE):
		if other == self: continue
		var center := Vector2(other.position.x, other.position.z)
		var a := Vector2(start.x, start.z)
		var b := Vector2(end.x, end.z)
		var initial := a.distance_to(center)
		var closest := Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center)
		if closest < minf(PERSONAL_SPACE, initial) - 0.00000001: return false
		if b.distance_to(center) < minf(PERSONAL_SPACE, initial) - 0.00000001: return false
	return true

func _plan_people_detour(target: Vector3) -> void:
	if current_order != null and position.distance_to(current_order.target) < 60.0:
		target = current_order.target
	else:
		target = position.move_toward(target, 32.0)
	crowd_retry_remaining = 0.75
	if navigation == null or not movement_neighbors.is_valid(): return
	# A private local visibility graph includes people as temporary circles.
	# Commit to its corners rather than choosing a new sidestep every frame.
	var local_nav = preload("res://scripts/battle/rts_navigation.gd").new()
	local_nav.configure(navigation.host)
	local_nav.half_size = navigation.half_size
	for id in navigation._segment_obstacles(position, target, 32.0):
		local_nav.obstacles[id] = navigation.obstacles[id]
		local_nav._index(id)
	local_nav.terrain_cache = navigation.terrain_cache
	for other in movement_neighbors.call(position, 28.0):
		if other == self: continue
		local_nav.add_circle("person:" + other.unit_id, other.position, PERSONAL_SPACE - 2.0 + 0.05)
	if not local_nav.clear(position): return
	var destination := target
	if not local_nav.clear(destination):
		if position.distance_to(target) < PERSONAL_SPACE + 1.0: return
		var forward := (target - position).normalized()
		var right := forward.cross(Vector3.UP)
		var found := false
		for side in [1.0, -1.0]:
			var point: Vector3 = position.move_toward(target, 20.0) + right * 8.0 * side
			if local_nav.clear(point):
				destination = point
				found = true
				break
		if not found: return
	var hit: Dictionary = local_nav.first_obstruction(position, destination, 2.0)
	if hit.fraction == INF:
		crowd_path = PackedVector3Array([local_nav.ground(destination)])
		return
	crowd_path = local_nav._local_route(position, destination, 2.0, str(hit.id))

func recover_personal_space(ground_provider: Callable) -> void:
	if not movement_neighbors.is_valid(): return
	for other in movement_neighbors.call(position, PERSONAL_SPACE):
		if other == self: continue
		var away := Vector3(position.x - other.position.x, 0, position.z - other.position.z)
		if away.length() >= PERSONAL_SPACE - 0.0001: continue
		if away.length_squared() < 0.000001: away = Vector3.RIGHT if unit_id < other.unit_id else Vector3.LEFT
		var candidate: Vector3 = other.position + away.normalized() * (PERSONAL_SPACE + 0.01)
		if navigation != null and not navigation.segment_clear(position, candidate): continue
		if not _people_segment_clear(position, candidate): continue
		position = _ground_position(ground_provider, candidate.x, candidate.z)
		unit_data.position = position

func _block_route() -> void:
	crowd_path.clear()
	# Retain the order and job intent. Failure is never reported as arrival.
	path.clear()
	route_failures += 1
	route_retry_remaining = 3.0
	set_meta("route_blocked", true)
	set_meta("route_retry_after", Time.get_ticks_msec() + 3000)


func stop() -> void:
	set_meta("delivery_slot_retry_after", 0)
	action_revision += 1
	queued_animation = ""
	finish_kneeling_work()
	play_animation("Idle")
	clear_move_order()
	clear_gather_action()
	clear_delivery_action()


func face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	rotation.y = atan2(flat_direction.x, flat_direction.z)


func face_position(target: Vector3) -> void:
	face_direction(Vector3(target.x - position.x, 0.0, target.z - position.z))


# The work timer belongs to simulation; only the middle clip repeats.
# Return the worker-seconds spent in the working phase this frame.
func work_while_kneeling(delta: float, context: String) -> float:
	if animation_player == null or not animation_player.has_animation("Kneel_Work"):
		return delta
	if kneeling_phase == "exit": return 0.0
	if kneeling_phase == "":
		queued_animation = ""
		after_kneeling_animation = "Idle"
		after_kneeling_speed = 1.0
		kneeling_context = context
		kneeling_phase = "enter"
		kneeling_remaining = animation_player.get_animation("Kneel_Enter").length
		play_animation("Kneel_Enter")
	if kneeling_context != context:
		finish_kneeling_work()
		return 0.0
	var work_delta := delta
	if kneeling_phase == "enter":
		work_delta = maxf(0.0, delta - kneeling_remaining)
		kneeling_remaining -= delta
		if kneeling_remaining > 0.0: return 0.0
		kneeling_phase = "work"
		play_animation("Kneel_Work", 0.08)
	return work_delta


func finish_kneeling_work() -> void:
	if kneeling_phase in ["", "exit"]: return
	# Exiting early during the lowering phase reverses that exact part of entry.
	# This avoids jumping straight to a fully kneeled exit pose on interruption.
	if kneeling_phase == "enter":
		var elapsed := animation_player.get_animation("Kneel_Enter").length - kneeling_remaining
		kneeling_phase = "exit"
		kneeling_remaining = maxf(0.0, elapsed)
		animation_player.play("Kneel_Enter", 0.08, -1.0)
		animation_player.seek(elapsed, true)
	else:
		kneeling_phase = "exit"
		kneeling_remaining = animation_player.get_animation("Kneel_Exit").length
		play_animation("Kneel_Exit")
	queued_animation = ""


func update_kneeling_exit(delta: float) -> void:
	if kneeling_phase != "exit": return
	# Called once per frame, including after a construction job has been removed.
	kneeling_remaining -= delta
	if kneeling_remaining > 0.0: return
	kneeling_phase = ""
	kneeling_context = ""
	for candidate in find_children("*", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		var pelvis := skeleton.find_bone("pelvis")
		if pelvis >= 0: skeleton.set_bone_pose_position(pelvis, skeleton.get_bone_rest(pelvis).origin)
	play_animation(after_kneeling_animation, 0.18, after_kneeling_speed)


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


# Firearm attack controllers call this when engaging a target. Shot events stay
# separate from visual playback and are consumed once by the combat caller.
func start_musket_combat(repeat_fire: bool = true) -> bool:
	if equipment_id not in ["matchlock_arquebus", "flintlock_musket", "caplock_musket"] or unit_data == null: return false
	clear_move_order()
	unit_data.get_musket_combat_state().start_combat(repeat_fire)
	return true

func advance_musket_combat(delta: float) -> Array[int]:
	if unit_data == null or unit_data.musket_combat == null: return []
	unit_data.musket_combat.advance(delta)
	return unit_data.musket_combat.take_shots()
