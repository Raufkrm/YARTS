class_name HandgonneHumanDrill
extends Node3D
## Authored handgonne handling poses baked into ordinary AnimationPlayer tracks.
## Reload milestones remain owned by HandgonneReloadState; animation has no events.

const HUMAN = preload("res://assets/reference_models/base_low_poly_male_reference_ual_rigged.glb")
const Prop = preload("res://scripts/props/firearm_prop.gd")
const Props = preload("res://scripts/tools/handgonne_drill_props.gd")
const Reload = preload("res://scripts/data/handgonne_reload_state.gd")
const Fire = preload("res://scripts/data/handgonne_fire_state.gd")
const PALM_OFFSET := 0.065
const GRIP_OFFSET := Vector3(0.020, 0.090, 0)
const SAMPLE_RATE := 24.0
static var _shared_libraries: Dictionary = {}
var female := false
var weapon_id := "early_handgonne"
var weapon_scale_override := 0.0
var human: Node3D
var skeleton: Skeleton3D
var held_weapon: Prop
var props: Dictionary = {}
var animation_player: AnimationPlayer
var current_phase := ""
var detail_level := 0
var _body_scale := 1.0
var _rest_rotations: Array[Quaternion] = []
var _rest_global: Array[Transform3D] = []
var _last_clip := ""


func _ready() -> void:
	name = "HandgonneHumanDrill"
	human = (load("res://assets/reference_models/base_low_poly_female_reference_ual_rigged.glb") if female else HUMAN).instantiate() as Node3D
	human.name = "Human"
	add_child(human)
	skeleton = human.find_child("Skeleton3D", true, false) as Skeleton3D
	var bounds := _bounds(human)
	_body_scale = 1.75 / bounds.size.y
	human.scale = Vector3.ONE * _body_scale
	human.position.y = -bounds.position.y * _body_scale
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("4f5e57")
	skin.roughness = 0.95
	for candidate in human.find_children("*", "MeshInstance3D", true, false):
		(candidate as MeshInstance3D).material_override = skin
	for bone in range(skeleton.get_bone_count()):
		_rest_rotations.append(skeleton.get_bone_pose_rotation(bone))
		_rest_global.append(skeleton.get_bone_global_pose(bone))
	held_weapon = Prop.new()
	held_weapon.name = "HeldHandgonne"
	held_weapon.weapon_id = weapon_id
	held_weapon.scale_override = weapon_scale_override
	add_child(held_weapon)
	props = _build_props(0)
	add_child(props.root)
	animation_player = AnimationPlayer.new()
	animation_player.name = "HumanDrillAnimations"
	animation_player.root_node = NodePath("..")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animation_player)
	_bake_library()
	update_pose(null)


func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for candidate in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		result = result.merge(box) if initialized else box
		initialized = true
	return result


func _build_props(level: int) -> Dictionary:
	return Props.build(level)


func _bake_library() -> void:
	var cache_key := str(female)
	if _shared_libraries.has(cache_key):
		animation_player.add_animation_library("", _shared_libraries[cache_key])
		return
	var library := AnimationLibrary.new()
	for phase: String in Reload.PHASES:
		library.add_animation(phase, _bake_clip(phase, float(Reload.PHASES[phase].duration)))
	library.add_animation("Fire", _bake_clip("Fire", Fire.DURATION))
	var carry := _bake_clip("", 2.0)
	carry.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("Carry", carry)
	_shared_libraries[cache_key] = library
	animation_player.add_animation_library("", library)


func _bake_clip(phase: String, duration: float) -> Animation:
	var clip := Animation.new()
	clip.resource_name = "hg_" + (phase.to_lower() if not phase.is_empty() else "carry_idle")
	clip.length = duration
	var bone_tracks: Array[int] = []
	var skeleton_path := str(get_path_to(skeleton))
	for bone in range(skeleton.get_bone_count()):
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(skeleton_path + ":" + skeleton.get_bone_name(bone)))
		bone_tracks.append(track)
	var nodes: Array[Node3D] = _animation_prop_nodes()
	var node_tracks: Array[Vector2i] = []
	for node in nodes:
		var position_track := clip.add_track(Animation.TYPE_POSITION_3D)
		var rotation_track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(position_track, get_path_to(node))
		clip.track_set_path(rotation_track, get_path_to(node))
		node_tracks.append(Vector2i(position_track, rotation_track))
	var frames := ceili(duration * SAMPLE_RATE)
	for frame in range(frames + 1):
		var progress := float(frame) / frames
		if phase == "Fire": _apply_firing_pose(duration * progress)
		else: _apply_authored_pose(phase, progress)
		var time := duration * progress
		for bone in range(bone_tracks.size()):
			clip.rotation_track_insert_key(bone_tracks[bone], time, skeleton.get_bone_pose_rotation(bone))
		for index in range(nodes.size()):
			clip.position_track_insert_key(node_tracks[index].x, time, nodes[index].position)
			clip.rotation_track_insert_key(node_tracks[index].y, time, nodes[index].quaternion)
	return clip


func update_pose(state) -> void:
	if animation_player == null: return
	current_phase = str(state.phase_id) if state != null else ""
	var clip := _pose_clip_name(current_phase)
	var progress := 0.0
	if state != null and not current_phase.is_empty():
		progress = clampf(float(state.phase_elapsed) / maxf(0.001, state.phase_duration()), 0.0, 1.0)
	if clip != _last_clip:
		animation_player.play(clip)
		_last_clip = clip
	animation_player.seek(animation_player.get_animation(clip).length * progress, true)
	animation_player.pause()
	skeleton.force_update_all_bone_transforms()
	_update_prop_visibility(current_phase, progress)


func set_detail_level(level: int) -> void:
	detail_level = clampi(level, 0, 2)
	held_weapon.set_detail_level(detail_level)
	var replacement := _build_props(detail_level)
	for prop_name: String in Props.PROP_NAMES:
		(props[prop_name] as MeshInstance3D).mesh = (replacement[prop_name] as MeshInstance3D).mesh
	(replacement.root as Node3D).free()
	var progress := 0.0
	if not _last_clip.is_empty():
		progress = animation_player.current_animation_position / animation_player.get_animation(_last_clip).length
	_update_prop_visibility(current_phase, progress)


func update_firing_pose(elapsed: float) -> void:
	current_phase = "Fire"
	if _last_clip != "Fire":
		animation_player.play("Fire")
		_last_clip = "Fire"
	animation_player.seek(clampf(elapsed, 0, Fire.DURATION), true)
	animation_player.pause()
	skeleton.force_update_all_bone_transforms()
	_update_prop_visibility("Fire", elapsed / Fire.DURATION)


func hand_world_position(side: String) -> Vector3:
	var suffix := "l" if side in ["left", "l"] else "r"
	var pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + suffix))
	return skeleton.global_transform * (pose.origin + pose.basis.y.normalized() * PALM_OFFSET)


func grip_world_position(side: String) -> Vector3:
	var suffix := "l" if side in ["left", "l"] else "r"
	var pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + suffix))
	var offset := _grip_offset(suffix)
	return skeleton.global_transform * (pose * offset)


func _update_prop_visibility(phase: String, progress: float) -> void:
	props.pouch.visible = detail_level == 0
	props.flask.visible = detail_level == 0 and phase in ["HG_R01", "HG_R02", "HG_R08"]
	props.shot.visible = detail_level == 0 and phase == "HG_R03" and progress > 0.10 and progress < 0.64
	# Priming is a supply gesture. A burning igniter belongs to firing, not reload.
	props.igniter.visible = detail_level < 2 and phase == "Fire" and progress * Fire.DURATION > 1.2 and progress * Fire.DURATION < 6.0
	props.rod.visible = phase in ["HG_R05", "HG_R06", "HG_R07"] and (phase != "HG_R07" or progress < 0.92)


func _smooth(value: float) -> float:
	value = clampf(value, 0.0, 1.0)
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)


func _reach(progress: float, start: Vector3, contact: Vector3, end: Vector3, hold_start: float = 0.3, hold_end: float = 0.65) -> Vector3:
	if progress < hold_start: return _arc(start, contact, progress / hold_start)
	if progress <= hold_end: return contact
	return _arc(contact, end, (progress - hold_end) / (1.0 - hold_end))


func _arc(start: Vector3, end: Vector3, progress: float) -> Vector3:
	var blend := _smooth(progress)
	return start.lerp(end, blend) + Vector3(0, 0.025, 0.018) * sin(PI * blend)


func _contact_weight(progress: float, enter: float = 0.3, leave: float = 0.65) -> float:
	return _smooth(progress / enter) * (1.0 - _smooth((progress - leave) / (1.0 - leave)))


func _weapon_transform(loading: float) -> Transform3D:
	var carry_axis := Vector3(0.75, 0.22, 0.62).normalized()
	var load_axis := Vector3(-0.20, 0.97, 0.14).normalized()
	var direction := carry_axis.slerp(load_axis, loading).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var up := side.cross(direction).normalized()
	var origin := Vector3(0.14, 1.17, 0.32).lerp(Vector3(0.11, 1.10, 0.34), loading)
	origin += Vector3(0, 0.05, 0.12) * sin(loading * PI)
	return Transform3D(Basis(direction, up, side), origin)


func _apply_authored_pose(phase: String, progress: float) -> void:
	for bone in range(_rest_rotations.size()):
		skeleton.set_bone_pose_rotation(bone, _rest_rotations[bone])
	skeleton.force_update_all_bone_transforms()
	var loading := 0.0 if phase.is_empty() else 1.0
	if phase == "HG_R00": loading = _smooth(progress)
	elif phase == "HG_R09": loading = 1.0 - _smooth(progress)
	var clock := _phase_time(phase, progress)
	var sway := sin(clock * TAU / Reload.FULL_DURATION) * loading
	held_weapon.transform = _weapon_transform(loading)
	var rod_lower := 1.0 if phase == "HG_R06" else 0.0
	if phase == "HG_R05": rod_lower = _smooth(progress / 0.65)
	if phase == "HG_R07": rod_lower = 1.0 - _smooth((progress - 0.60) / 0.40)
	held_weapon.position += Vector3(0, -0.04, -0.04) * rod_lower
	held_weapon.position += Vector3(0.005 * sway, 0.003 * sway, 0.003 * sway)
	var axis := held_weapon.basis.x
	var support := held_weapon.transform * held_weapon.socket_position("support_grip")
	var carry := held_weapon.transform * held_weapon.socket_position("carry_grip")
	var muzzle := held_weapon.transform * held_weapon.socket_position("muzzle_fx")
	var ignition := held_weapon.transform * held_weapon.socket_position("ignition_fx")
	var hip := Vector3(-0.20, 1.00, 0.18)
	var powder_time := progress * 0.8 if phase == "HG_R01" else 0.8 + progress * 3.2
	var powder_progress := powder_time / 4.0
	var right_grip := carry if phase.is_empty() else hip
	var right_width := axis if phase.is_empty() else Vector3.BACK
	var right_curl := 0.85 if phase.is_empty() else 0.15
	var contact := _contact_weight(progress)
	var rod_clear := muzzle + axis * 0.27
	var rod_side := rod_clear + Vector3(-0.16, 0, 0)
	var rod_seated := muzzle + axis * 0.11
	var rod_axis := axis
	match phase:
		"HG_R00":
			right_grip = _arc(carry, hip, progress)
			right_width = axis.slerp(Vector3.BACK, _smooth(progress))
			right_curl = lerpf(0.85, 0.15, _smooth(progress))
		"HG_R01", "HG_R02":
			# One continuous reach/pour arc across the reservation boundary.
			right_grip = _reach(powder_progress, hip, muzzle + axis * 0.051, hip, 0.375, 0.60)
			var pour := _contact_weight(powder_progress, 0.375, 0.60)
			right_width = Vector3.BACK.slerp(axis, pour)
			right_curl = lerpf(0.15, 0.80, pour)
		"HG_R03":
			right_grip = _reach(progress, hip, muzzle + axis * 0.015, hip, 0.35, 0.62)
			right_width = Vector3.BACK.slerp(axis, _contact_weight(progress, 0.35, 0.62))
			right_curl = lerpf(0.15, 0.40, contact)
		"HG_R05":
			right_grip = _arc(hip, rod_side, progress / 0.65) if progress < 0.65 else rod_side.lerp(rod_clear, _smooth((progress-0.65)/0.35))
			right_width = Vector3.BACK.slerp(axis, _smooth(progress / 0.65))
			right_curl = lerpf(0.15, 0.95, _smooth(progress / 0.65))
		"HG_R06":
			if progress < 0.25: right_grip = rod_clear.lerp(rod_seated, _smooth(progress / 0.25))
			else: right_grip = rod_seated + axis * 0.08 * pow(sin((progress-0.25)/0.75 * TAU), 2)
			right_width = axis
			right_curl = 0.95
		"HG_R07":
			if progress < 0.40: right_grip = rod_seated.lerp(rod_clear, _smooth(progress/0.40))
			elif progress < 0.60: right_grip = rod_clear.lerp(rod_side, _smooth((progress-0.40)/0.20))
			else: right_grip = _arc(rod_side, hip, (progress-0.60)/0.40)
			var stow := _smooth((progress-0.60)/0.40)
			right_width = axis.slerp(Vector3.BACK, stow)
			right_curl = lerpf(0.95, 0.15, stow)
		"HG_R08":
			right_grip = _reach(progress, hip, ignition + Vector3.UP * 0.051, hip)
			right_width = Vector3.BACK.slerp(axis, contact)
			right_curl = lerpf(0.15, 0.80, contact)
		"HG_R09":
			right_grip = _arc(hip, carry, progress)
			right_width = Vector3.BACK.slerp(axis, _smooth(progress))
			right_curl = lerpf(0.15, 0.85, _smooth(progress))
	# Small connected torso/head changes accompany the reaches; the feet remain planted.
	_rotate_world("pelvis", Vector3.FORWARD, sway * 0.012)
	_rotate_world("spine_01", Vector3.RIGHT, loading * 0.035 + sway * 0.012)
	_rotate_world("spine_03", Vector3.UP, loading * -0.035 + sway * 0.010)
	_rotate_world("Head", Vector3.RIGHT, 0.06 + loading * 0.13)
	_rotate_world("Head", Vector3.UP, loading * clampf(right_grip.x * 0.3, -0.07, 0.07))
	for side: String in ["l", "r"]:
		var foot := skeleton.find_bone("foot_" + side)
		var rest_foot := to_local(skeleton.global_transform * _rest_global[foot].origin)
		rest_foot.x += 0.025 if side == "l" else -0.025
		_solve_chain("thigh_" + side, "calf_" + side, "foot_" + side, rest_foot, Vector3(rest_foot.x, 0.48, 0.20))
		_set_global_basis(foot, _rest_global[foot].basis)
	_grip_arm("l", support, axis, Vector3(0.43, 1.06, 0.06))
	var right_hint := Vector3(-0.40, 1.03 + maxf(0.0, right_grip.y - 1.2) * 0.45, 0.07)
	_grip_arm("r", right_grip, right_width, right_hint)
	_curl_fingers("l", 0.90)
	_curl_fingers("r", right_curl)
	_set_prop_axis(props.rod, right_grip - rod_axis * 0.23, rod_axis)
	var flask_axis := Vector3.UP
	if phase in ["HG_R01", "HG_R02"]: flask_axis = Vector3.UP.slerp(-axis, _contact_weight(powder_progress, 0.375, 0.60))
	elif phase == "HG_R08": flask_axis = Vector3.UP.slerp(Vector3(0.01, -1, 0).normalized(), contact)
	_set_prop_axis(props.flask, right_grip - flask_axis * 0.045, flask_axis)
	props.shot.position = right_grip + axis * 0.05
	if phase == "HG_R03" and progress >= 0.40:
		props.shot.position = muzzle + axis * lerpf(0.065, -0.11, _smooth((progress - 0.40) / 0.20))
	props.pouch.position = Vector3(-0.115, 0.91, 0.07)
	skeleton.force_update_all_bone_transforms()


func _apply_firing_pose(time: float) -> void:
	_apply_authored_pose("", 0.0)
	var raise := _smooth(time / 2.0)
	var lower := _smooth((time - 6.0) / 2.0)
	var aim := raise * (1.0 - lower)
	# This model faces local +Z. Aim along the actor, not diagonally across it.
	var axis := Vector3.BACK
	var side := axis.cross(Vector3.UP).normalized()
	# The tiller crosses just below the left armpit; the muzzle points forward.
	var aimed := Transform3D(Basis(axis, side.cross(axis), side), Vector3(0.20 if female else 0.24, 1.20, 0) + axis * 0.29)
	# First bring the muzzle upright in front of the body, then lower it
	# forward alongside the ribs. A direct diagonal-to-forward turn sweeps
	# the long rear tiller through the torso even when both endpoints clear.
	if aim < 0.45:
		held_weapon.transform = _weapon_transform(_smooth(aim / 0.45))
	else:
		var settle := _smooth((aim - 0.45) / 0.55)
		var upright := _weapon_transform(1.0)
		var direction := upright.basis.x.slerp(axis, settle)
		# Straighten the sideways lean before dropping the rear past the elbow.
		direction.x *= 1.0 - _smooth(settle / 0.40)
		direction = direction.normalized()
		var lateral := direction.cross(Vector3.UP).normalized()
		var settling_origin := upright.origin.lerp(aimed.origin, settle)
		var clearance_x := 0.28 if female else 0.24
		# Clear the hip before pitching down; tuck inward only after the rear
		# has risen past it, leaving room for the supporting forearm.
		settling_origin.x = (
			lerpf(upright.origin.x, clearance_x, _smooth(settle / 0.40))
			+ (aimed.origin.x - clearance_x) * _smooth((settle - 0.50) / 0.50)
			- 0.035 * sin(settle * PI) * _smooth((settle - 0.5) / 0.15)
		)
		held_weapon.transform = Transform3D(Basis(direction, lateral.cross(direction), lateral), settling_origin)
	var recoil := 0.0
	if time >= Fire.SHOT_TIME:
		var pulse := time - Fire.SHOT_TIME
		recoil = _smooth(pulse / 0.10) * (1.0 - _smooth((pulse - 0.10) / 0.55))
	held_weapon.position -= axis * recoil * 0.035
	_rotate_world("spine_01", Vector3.RIGHT, aim * 0.035 - recoil * 0.045)
	var support := held_weapon.transform * held_weapon.socket_position("support_grip")
	var carry := held_weapon.transform * held_weapon.socket_position("carry_grip")
	var primer := held_weapon.transform * held_weapon.socket_position("ignition_fx")
	var hip := Vector3(-0.20, 1.00, 0.18)
	var wand_axis := Vector3(0.88, -0.18, 0.44).normalized()
	var approach := _smooth((time - 2.0) / 2.5)
	var withdraw := _smooth((time - 4.65) / 1.35)
	var reach := approach * (1.0 - withdraw)
	var right_grip := _arc(carry, hip, time / 0.5)
	if time >= 2.0: right_grip = _arc(hip, primer - wand_axis * 0.18, reach)
	if time >= 6.0: right_grip = _arc(hip, carry, _smooth((time - 7.5) / 0.5))
	var width := held_weapon.basis.x.slerp(Vector3.BACK, _smooth(time / 0.5))
	# The shorter forearm needs a flatter roll target to avoid aligning the palm
	# width with the forearm during the approach (an unstable roll singularity).
	if time >= 2.0: width = Vector3.BACK.slerp(Vector3(1, 0.35, 0).normalized() if female else wand_axis, reach)
	if time >= 6.0: width = Vector3.BACK.slerp(held_weapon.basis.x, _smooth((time - 7.5) / 0.5))
	_grip_arm("l", support, held_weapon.basis.x, Vector3(0.43, 1.06, 0.06).lerp(Vector3(0.48, 1.05, 0.05), aim))
	_grip_arm("r", right_grip, width, Vector3(-0.40, 1.03, 0.07).lerp(Vector3(-0.40, 1.04, 0.06), aim))
	_curl_fingers("l", 0.90)
	_curl_fingers("r", lerpf(0.85, 0.90, aim))
	var rod_axis := Vector3.UP.slerp(wand_axis, reach)
	_set_prop_axis(props.igniter, right_grip - rod_axis * 0.237, rod_axis)
	skeleton.force_update_all_bone_transforms()


func _phase_time(phase: String, progress: float) -> float:
	if phase.is_empty(): return 0.0
	var elapsed := 0.0
	for candidate: String in ["HG_R00", "HG_R01", "HG_R02", "HG_R03", "HG_R05", "HG_R06", "HG_R07", "HG_R08", "HG_R09"]:
		var duration := float(Reload.PHASES[candidate].duration)
		if candidate == phase: return elapsed + duration * progress
		elapsed += duration
	return 0.0


func _set_prop_axis(node: Node3D, origin: Vector3, direction: Vector3) -> void:
	node.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())), origin)


func _grip_offset(side: String) -> Vector3:
	return Vector3(-GRIP_OFFSET.x if side == "r" else GRIP_OFFSET.x, GRIP_OFFSET.y, GRIP_OFFSET.z)


func _grip_arm(side: String, contact: Vector3, width_axis: Vector3, hint: Vector3) -> void:
	var lower := skeleton.find_bone("lowerarm_" + side)
	var hand := skeleton.find_bone("hand_" + side)
	var offset := _grip_offset(side)
	var wrist := contact - Vector3(0, 0, offset.y * _body_scale)
	# Solve the contact by moving the entire arm. Wrist orientation remains the
	# rig's neutral relationship to its forearm, on BOTH sides. Forearm roll turns
	# the palm toward its grip without folding the wrist back onto the arm.
	for iteration in range(20):
		_solve_chain("upperarm_" + side, "lowerarm_" + side, "hand_" + side, wrist, hint)
		var lower_pose := skeleton.get_bone_global_pose(lower)
		var direction := (global_basis.inverse() * skeleton.global_basis * lower_pose.basis.y).normalized()
		var width := width_axis - direction * width_axis.dot(direction)
		if width.length_squared() < 0.01:
			width = Vector3.RIGHT - direction * direction.x
		width = width.normalized()
		var normal := direction.cross(width).normalized()
		var forearm_basis := Basis(normal, direction, width)
		var local_basis := (skeleton.global_basis.inverse() * global_basis * forearm_basis).orthonormalized()
		_set_global_basis(lower, local_basis)
		skeleton.set_bone_pose_rotation(hand, _rest_rotations[hand])
		skeleton.force_update_all_bone_transforms()
		var actual := to_local(grip_world_position(side))
		wrist += (contact - actual) * 0.5


func _solve_chain(upper_name: String, lower_name: String, end_name: String, target: Vector3, hint: Vector3) -> void:
	var upper := skeleton.find_bone(upper_name)
	var lower := skeleton.find_bone(lower_name)
	var end := skeleton.find_bone(end_name)
	var origin := skeleton.get_bone_global_pose(upper).origin
	var target_local := skeleton.to_local(to_global(target))
	var hint_local := skeleton.to_local(to_global(hint))
	var length_upper := _rest_global[upper].origin.distance_to(_rest_global[lower].origin)
	var length_lower := _rest_global[lower].origin.distance_to(_rest_global[end].origin)
	var direction := (target_local - origin).normalized()
	var distance := clampf(origin.distance_to(target_local), absf(length_upper - length_lower) + 0.001, length_upper + length_lower - 0.001)
	var bend := hint_local - origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	var along := (length_upper * length_upper - length_lower * length_lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, length_upper * length_upper - along * along))
	var elbow := origin + direction * along + bend * height
	_aim_bone(upper, elbow)
	_aim_bone(lower, origin + direction * distance)


func _aim_bone(bone: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var desired := Basis(Quaternion(pose.basis.y.normalized(), (target - pose.origin).normalized())) * pose.basis
	_set_global_basis(bone, desired)


func _set_global_basis(bone: int, basis: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * basis).orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()


func _rotate_world(bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	_set_global_basis(bone, Basis(axis, angle) * skeleton.get_bone_global_pose(bone).basis)


func _curl_fingers(side: String, amount: float) -> void:
	# The four fingers share one mesh and one middle-finger chain. Independent
	# index/ring/pinky rotations are deliberately unused by this simplified hand.
	for joint in range(1, 4):
		var bone := skeleton.find_bone("middle_%02d_%s" % [joint, side])
		var angle: float = [0.72, 0.66, 0.18][joint - 1] * amount
		skeleton.set_bone_pose_rotation(bone, _rest_rotations[bone] * Quaternion(Vector3.RIGHT, angle))
	for joint in range(1, 3):
		var bone := skeleton.find_bone("thumb_%02d_%s" % [joint, side])
		var angle: float = [0.44, 0.26][joint - 1] * amount
		skeleton.set_bone_pose_rotation(bone, _rest_rotations[bone] * Quaternion(Vector3.RIGHT, angle))

func _animation_prop_nodes() -> Array[Node3D]:
	return [held_weapon, props.rod, props.flask, props.shot, props.igniter, props.pouch]

func _pose_clip_name(phase: String) -> String:
	return phase if not phase.is_empty() else "Carry"
