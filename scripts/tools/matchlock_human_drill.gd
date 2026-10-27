class_name MatchlockHumanDrill
extends "res://scripts/tools/handgonne_human_drill.gd"
const MatchReload = preload("res://scripts/data/matchlock_reload_state.gd")
static var _match_libraries: Dictionary = {}
const BAYONET_DURATION := 20.0
var held_bayonet: Node3D
var _socket_reload := false
var support_contact := Vector3.ZERO
var _carry_contact := Vector3.ZERO
var _carry_arm_rotations: Dictionary = {}

func _init() -> void: weapon_id = "matchlock_arquebus"

func _rod_bounds() -> Array:
	return Prop.asset_manifest().assets[weapon_id].lods[0].parts_bounds_blender.Ramrod

func _rod_length() -> float:
	var bounds := _rod_bounds()
	return float(bounds[0][1]) - float(bounds[0][0])

func _rod_stowed() -> Vector3:
	var bounds := _rod_bounds()
	return Vector3(float(bounds[0][0]), (float(bounds[2][0])+float(bounds[2][1]))*0.5, -(float(bounds[1][0])+float(bounds[1][1]))*0.5)

func _build_props(level: int) -> Dictionary:
	var result := Props.build(level)
	result.igniter.mesh = null
	if weapon_id == "caplock_musket" and level == 0:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.004
		cap.bottom_radius = 0.004
		cap.height = 0.004
		cap.radial_segments = 6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.48, 0.29, 0.13)
		cap.material = material
		result.igniter.mesh = cap
	if level < 2:
		var rod := Props._data()
		# Exactly the exported rod's length/radius, including the new weapon scale.
		Props._append_rings(rod, 6 if level == 0 else 4, [[0.0, 0.0055 * held_weapon.asset_scale()], [_rod_length() * held_weapon.asset_scale(), 0.0055 * held_weapon.asset_scale()]], Color(0.07, 0.09, 0.105))
		result.rod.mesh = Props._mesh(rod, "MatchlockRod%d" % level)
	if level > 0:
		for prop_name in ["flask", "shot", "pouch"]: result[prop_name].mesh = null
		if level == 2: result.rod.mesh = null
	return result

func _bake_library() -> void:
	held_bayonet = Node3D.new()
	held_bayonet.name = "HeldBayonet"
	add_child(held_bayonet)
	var attachment := "plug_bayonet" if weapon_id == "matchlock_arquebus" else "socket_bayonet"
	var asset: Node3D = load(Prop.asset_manifest().attachments[attachment].lods[0].mesh).instantiate()
	held_bayonet.add_child(asset)
	asset.scale = Vector3.ONE * held_weapon.asset_scale()
	held_bayonet.hide()
	var key := weapon_id + str(female) + str(held_weapon.asset_scale())
	if not _match_libraries.has(key):
		var library := AnimationLibrary.new()
		for phase: String in MatchReload.PHASES:
			library.add_animation(phase, _bake_clip(phase, MatchReload.PHASES[phase].duration))
		library.add_animation("Carry", _bake_clip("", 2.0))
		for clip in ["MusketAim", "MusketLower", "MusketFire"]:
			library.add_animation(clip, _bake_clip(clip, 2.0))
		if weapon_id == "matchlock_arquebus":
			for clip in ["BayonetFit", "BayonetRemove"]:
				library.add_animation(clip, _bake_clip(clip, BAYONET_DURATION))
		if weapon_id != "matchlock_arquebus":
			_socket_reload = true
			for phase: String in MatchReload.PHASES:
				library.add_animation("Socket_" + phase, _bake_clip(phase, MatchReload.PHASES[phase].duration))
			_socket_reload = false
		_match_libraries[key] = library
	animation_player.add_animation_library("", _match_libraries[key])

func _loading(phase: String, p: float) -> float:
	if phase == "ML_R03": return _smooth(p / 0.30)
	if phase in ["ML_R04", "ML_R05", "ML_R06", "ML_R07"]: return 1.0
	if phase == "ML_R08": return 1.0 - _smooth(p / 0.30)
	return 0.0

func _match_transform(phase: String, p: float) -> Transform3D:
	var load_amount := _loading(phase, p)
	var working_axis := Vector3(0.88, 0.22, 0.42).normalized()
	var load_axis := Vector3(-0.10, 0.985, 0.14).normalized()
	var direction := working_axis.slerp(load_axis, load_amount)
	# Keep the stock and the loading channel in front of the torso and legs.
	var origin := Vector3(-0.06, 1.03, 0.30).lerp(Vector3(0.08, 0.48, 0.30), load_amount)
	# Lift through the turn so the support arm never reaches down and outward
	# at once; settle the butt only after the barrel is upright.
	origin += Vector3(0, 0.10, -0.04) * sin(load_amount * PI)
	# Longer muskets lower the muzzle to the same reachable loading height.
	origin.y -= maxf(0, held_weapon.socket_position("muzzle_fx").x - 1.357 * held_weapon.asset_scale()) * load_amount
	var carry_amount := _carry_blend(phase, p)
	var side := direction.cross(Vector3.UP).normalized()
	var basis := Basis(direction, side.cross(direction), side)
	# Keep the backward lean and roll the trigger toward the upward side.
	var shoulder_axis := Vector3(0.0, 0.985, -0.174).normalized()
	var trigger_up := (Vector3.UP - shoulder_axis * shoulder_axis.dot(Vector3.UP)).normalized()
	var shoulder_basis := Basis(shoulder_axis, -trigger_up, shoulder_axis.cross(-trigger_up))
	basis = Basis(basis.get_rotation_quaternion().slerp(shoulder_basis.get_rotation_quaternion(), carry_amount))
	var carry_origin := _carry_hand_target() - basis * _carry_stock_local()
	origin = origin.lerp(carry_origin, carry_amount)
	origin.y += 0.12 * sin(carry_amount * PI)
	# Clear the close carry from the arm before turning it across the body.
	origin.z += 0.12 * sin(sqrt(1.0 - carry_amount) * PI)
	origin.x += 0.04 * sin(sqrt(1.0 - carry_amount) * PI)
	return Transform3D(basis, origin)

func _carry_stock_local() -> Vector3:
	return Vector3(-0.47, -0.11, 0) * held_weapon.asset_scale()

# Departure time is reversible: the right hand takes a fixed stock grip,
# guides the gun while the left changes grip, then releases for supplies.
func _handover_time(phase: String, p: float) -> float:
	if phase == "ML_R00": return p
	if phase == "ML_R10": return 1.0 - p
	return 0.0 if phase.is_empty() else 1.0

func _carry_blend(phase: String, p: float) -> float:
	return 1.0 - _smooth((_handover_time(phase, p) - 0.20) / 0.65)

func _handover_grip_local() -> Vector3:
	return Vector3(-0.15, -0.05, -0.035) * held_weapon.asset_scale()

func _relax_right_arm(amount: float) -> void:
	if amount <= 0.0: return
	var upper := skeleton.find_bone("upperarm_r")
	var lower := skeleton.find_bone("lowerarm_r")
	var hand := skeleton.find_bone("hand_r")
	var old_upper := skeleton.get_bone_pose_rotation(upper)
	var old_lower := skeleton.get_bone_pose_rotation(lower)
	var old_hand := skeleton.get_bone_pose_rotation(hand)
	# A hanging arm has a nearly vertical humerus and a small elbow bend.
	# Author its directions, rather than forcing a palm grip below the body.
	var upper_direction := Vector3(-0.09, -1.0, 0.025).normalized()
	_aim_bone(upper, skeleton.get_bone_global_pose(upper).origin + skeleton.global_basis.inverse() * global_basis * upper_direction)
	var direction := Vector3(-0.035, -1.0, 0.12).normalized()
	var width := (Vector3.BACK - direction * direction.dot(Vector3.BACK)).normalized()
	_set_global_basis(lower, (skeleton.global_basis.inverse() * global_basis * Basis(direction.cross(width), direction, width)).orthonormalized())
	skeleton.set_bone_pose_rotation(hand, _rest_rotations[hand])
	var relaxed_upper := skeleton.get_bone_pose_rotation(upper)
	var relaxed_lower := skeleton.get_bone_pose_rotation(lower)
	var relaxed_hand := skeleton.get_bone_pose_rotation(hand)
	skeleton.set_bone_pose_rotation(upper, old_upper.slerp(relaxed_upper, amount))
	skeleton.set_bone_pose_rotation(lower, old_lower.slerp(relaxed_lower, amount))
	skeleton.set_bone_pose_rotation(hand, old_hand.slerp(relaxed_hand, amount))
	skeleton.force_update_all_bone_transforms()

func _grip_offset(side: String) -> Vector3:
	# Centre of the curled finger opening, measured beyond the palm/knuckles.
	return Vector3(-0.050 if side == "r" else 0.050, 0.140, 0)

func _support_local(phase: String, p: float) -> Vector3:
	var working := Vector3(lerpf(0.35 if female else 0.43, 0.82, _loading(phase, p)), 0.006, 0) * held_weapon.asset_scale()
	var transfer := _smooth((_handover_time(phase, p) - 0.20) / 0.65)
	# The right hand holds a fixed stock point while the left hand releases,
	# moves outside the wood and closes around the fore-end.
	return _carry_stock_local().lerp(working, transfer) + Vector3(0, 0, 0.09) * sin(transfer * PI)

# Rod coordinates use the original export's local frame. Conversion to world
# applies the same 0.8 factor as the mesh and every socket, exactly once.
func _rod_path(phase: String, p: float) -> Vector3:
	var stowed := _rod_stowed()
	var muzzle := held_weapon.socket_position("muzzle_fx") / held_weapon.asset_scale()
	var clear_storage := Vector3(muzzle.x + 0.075, stowed.y, stowed.z)
	var clear_bore := Vector3(clear_storage.x, muzzle.y, muzzle.z)
	var seated := Vector3(muzzle.x - _rod_length() + 0.12, muzzle.y, muzzle.z)
	if phase == "ML_R05":
		if p < 0.25: return stowed
		if p < 0.75: return stowed.lerp(clear_storage, _smooth((p-0.25)/0.50))
		return clear_storage.lerp(clear_bore, _smooth((p-0.75)/0.25))
	if phase == "ML_R06":
		if p < 0.40: return clear_bore.lerp(seated, _smooth(p/0.40))
		return seated + Vector3.RIGHT * 0.10 * pow(sin((p-0.40)/0.60 * TAU), 2)
	if phase == "ML_R07":
		if p < 0.40: return seated.lerp(clear_bore, _smooth(p/0.40))
		if p < 0.55: return clear_bore.lerp(clear_storage, _smooth((p-0.40)/0.15))
		if p < 0.75: return clear_storage.lerp(stowed, _smooth((p-0.55)/0.20))
	return stowed

func _apply_authored_pose(phase: String, p: float) -> void:
	if phase in ["BayonetFit", "BayonetRemove"]:
		_apply_bayonet_pose(phase == "BayonetRemove", p)
		return
	if phase in ["MusketAim", "MusketLower", "MusketFire"]:
		_apply_musket_shooting_pose(phase, p)
		return
	super._apply_authored_pose("", 0.0)
	_author_left_carry_arm()
	held_weapon.transform = _match_transform(phase, p)
	var axis := held_weapon.basis.x
	support_contact = held_weapon.transform * _support_local(phase, p)
	var muzzle := held_weapon.transform * held_weapon.socket_position("muzzle_fx")
	var pan := held_weapon.transform * held_weapon.socket_position("cap_seat" if weapon_id == "caplock_musket" else "pan_fx")
	var hip := Vector3(-0.22, 0.98, 0.22)
	var preparation := Vector3(-0.10, 1.20, 0.32)
	var handover := _handover_time(phase, p)
	var transfer_grip := held_weapon.transform * _handover_grip_local()
	var grip := hip
	var width := Vector3.BACK
	var rod_start := _rod_path(phase, p)
	var muzzle_local := held_weapon.socket_position("muzzle_fx") / held_weapon.asset_scale()
	# Regrip along the exposed rod: no impossible one-metre arm extension.
	var rod_end_margin := 0.015 if _socket_reload else 0.035
	var rod_grip_local := Vector3(clampf(muzzle_local.x + (0.22 if _socket_reload else 0.085), rod_start.x + 0.035, rod_start.x + _rod_length() - rod_end_margin), rod_start.y, rod_start.z)
	if phase == "ML_R06" and p >= 0.40:
		rod_grip_local.x = rod_start.x + _rod_length() - rod_end_margin
	var careful_offset := held_weapon.basis.z * 0.080 + held_weapon.basis.y * 0.025 if _socket_reload else Vector3.ZERO
	var rod_grip := held_weapon.transform * (rod_grip_local * held_weapon.asset_scale())
	if phase.is_empty():
		grip = transfer_grip
		width = Vector3.BACK
	match phase:
		"ML_R00":
			grip = transfer_grip.lerp(hip, _smooth((handover - 0.85) / 0.15))
		"ML_R02": grip = _arc(hip, preparation, p)
		"ML_R03":
			grip = _reach(p, preparation, muzzle + axis * 0.055 + careful_offset, hip, 0.50, 0.70)
			width = Vector3.BACK.slerp(axis, _contact_weight(p, 0.50, 0.70))
		"ML_R04":
			grip = _reach(p, hip, muzzle + axis * 0.045 + careful_offset, hip, 0.40, 0.60)
			width = Vector3.BACK.slerp(axis, _contact_weight(p, 0.40, 0.60))
		"ML_R05":
			grip = _arc(hip, rod_grip, p / 0.25) if p < 0.25 else rod_grip
			width = Vector3.BACK.slerp(axis, _smooth(p / 0.25))
		"ML_R06":
			grip = rod_grip
			width = axis
		"ML_R07":
			grip = _arc(rod_grip, hip, (p-0.75)/0.25) if p > 0.75 else rod_grip
			width = axis.slerp(Vector3.BACK, _smooth((p-0.75)/0.25))
		"ML_R08":
			grip = _reach(p, hip, pan + Vector3.UP * 0.07, hip, 0.5, 0.70)
			width = Vector3.BACK.slerp(axis, _contact_weight(p, 0.5, 0.70))
		"ML_R10":
			grip = transfer_grip.lerp(hip, _smooth((handover - 0.85) / 0.15))
	_grip_arm("l", support_contact, axis.slerp(_carry_palm_axis(), _carry_blend(phase, p)), Vector3(0.48, 1.02, 0.03).lerp(_carry_elbow_hint(), _carry_blend(phase, p)))
	_blend_left_carry_arm(1.0 - _smooth((handover - 0.20) / 0.65))
	var right_hint := Vector3(-0.42, 1.02 + maxf(0, grip.y - 1.2) * 0.4, 0.08)
	_grip_arm("r", grip, width, right_hint)
	var left_transfer := _smooth((handover - 0.20) / 0.65)
	_curl_fingers("l", lerpf(0.55, 1.05, left_transfer) * (1.0 - 0.85 * sin(left_transfer * PI)))
	_relax_right_arm(1.0 - _smooth(handover / 0.20))
	var right_curl := 1.1 if phase == "ML_R06" else 0.70
	if phase == "ML_R05": right_curl = lerpf(0.70, 1.1, _smooth(p / 0.25))
	if phase == "ML_R07": right_curl = lerpf(1.1, 0.70, _smooth((p - 0.75) / 0.25))
	if phase in ["ML_R00", "ML_R10"]:
		right_curl = lerpf(1.0, 0.70, _smooth((handover - 0.85) / 0.15))
	_curl_fingers("r", lerpf(0.18, right_curl, _smooth(handover / 0.20)))
	_set_prop_axis(props.rod, held_weapon.transform * (rod_start * held_weapon.asset_scale()), axis)
	var flask_axis := Vector3.UP
	if phase == "ML_R03": flask_axis = flask_axis.slerp(-axis, _contact_weight(p, 0.5, 0.7))
	if phase == "ML_R03" and _socket_reload:
		flask_axis = flask_axis.slerp((muzzle-grip).normalized(), _contact_weight(p,0.5,0.7))
	if phase == "ML_R08": flask_axis = Vector3.UP.rotated(Vector3.RIGHT, PI * _contact_weight(p, 0.5, 0.7))
	_set_prop_axis(props.flask, grip - flask_axis * 0.045, flask_axis)
	props.shot.position = grip - axis * 0.025
	if phase == "ML_R04" and p >= 0.4:
		props.shot.position = muzzle + axis * lerpf(0.02, -0.10, _smooth((p - 0.4) / 0.2))
	if phase == "ML_R04" and _socket_reload and p >= 0.4:
		props.shot.position = (grip-axis*0.025).lerp(muzzle-axis*0.10,_smooth((p-0.4)/0.2))
	props.igniter.position = grip
	props.pouch.position = Vector3(-0.115, 0.91, 0.18)
	skeleton.force_update_all_bone_transforms()

func _update_prop_visibility(phase: String, p: float) -> void:
	props.pouch.visible = detail_level == 0
	props.flask.visible = detail_level == 0 and (phase in ["ML_R02", "ML_R03"] or (phase == "ML_R08" and weapon_id != "caplock_musket"))
	props.shot.visible = detail_level == 0 and phase == "ML_R04" and p > 0.1 and p < 0.64
	props.shot.scale = Vector3.ONE * 0.5
	var rod_in_hand := phase in ["ML_R05", "ML_R06", "ML_R07"]
	props.rod.visible = detail_level < 2 and rod_in_hand
	props.rod.scale = Vector3.ONE
	# The wick remains fitted for the entire cycle. There is no held-wick prop.
	props.igniter.visible = detail_level == 0 and weapon_id == "caplock_musket" and phase == "ML_R08" and p > 0.2 and p < 0.75
	var cover := _contact_weight(p, 0.35, 0.75) if phase == "ML_R08" else 0.0
	held_weapon.set_mechanism_pose("Lock_Open", cover)
	var weapon_skeleton := held_weapon.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if weapon_skeleton != null:
		var rod_bone := weapon_skeleton.find_bone("Ramrod")
		if rod_bone >= 0: weapon_skeleton.set_bone_pose_scale(rod_bone, Vector3.ZERO if rod_in_hand else Vector3.ONE)
		weapon_skeleton.force_update_all_bone_transforms()

func _carry_hand_target() -> Vector3:
	return _carry_contact

func _carry_palm_axis() -> Vector3:
	return Vector3(1, 0, -1).normalized() if female else Vector3.RIGHT

func _carry_elbow_hint() -> Vector3:
	return Vector3(0.20, 1.08, -0.08)

func _author_left_carry_arm() -> void:
	var upper := skeleton.find_bone("upperarm_l")
	var lower := skeleton.find_bone("lowerarm_l")
	var hand := skeleton.find_bone("hand_l")
	var upper_direction := Vector3(0.06, -1.0, 0.50 if female else 0.40).normalized()
	_aim_bone(upper, skeleton.get_bone_global_pose(upper).origin + skeleton.global_basis.inverse() * global_basis * upper_direction)
	var direction := Vector3(0.035, -1.0, 0.50 if female else 0.40).normalized()
	var width := (Vector3.BACK - direction * direction.dot(Vector3.BACK)).normalized()
	_set_global_basis(lower, (skeleton.global_basis.inverse() * global_basis * Basis(direction.cross(width), direction, width)).orthonormalized())
	skeleton.set_bone_pose_rotation(hand, _rest_rotations[hand])
	skeleton.force_update_all_bone_transforms()
	# The arm hangs naturally; only the hand bends to cup the stock.
	_rotate_world("hand_l", Vector3.RIGHT, deg_to_rad(-55.0))
	_carry_contact = to_local(grip_world_position("l"))
	for bone in [upper, lower, hand]: _carry_arm_rotations[bone] = skeleton.get_bone_pose_rotation(bone)

func _blend_left_carry_arm(amount: float) -> void:
	for bone: int in _carry_arm_rotations:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(_carry_arm_rotations[bone], amount))
	skeleton.force_update_all_bone_transforms()


func update_combat_pose(sequence) -> void:
	if sequence.mode == "reload":
		update_pose(sequence.reload)
		return
	if sequence.mode == "carry":
		update_pose(null)
		return
	if sequence.mode == "return":
		var state := MatchReload.new()
		state.phase_id = "ML_R10"
		state.phase_elapsed = sequence.elapsed
		update_pose(state)
		return
	var clip := "MusketFire" if sequence.mode == "fire" else "MusketLower" if sequence.mode == "lower" else "MusketAim"
	var time: float = 2.0 if sequence.mode == "aim" else sequence.elapsed
	animation_player.play(clip)
	animation_player.seek(clampf(time, 0, 2.0), true)
	animation_player.pause()
	_last_clip = clip
	current_phase = clip
	skeleton.force_update_all_bone_transforms()
	_update_prop_visibility(clip, time / 2.0)
	var lock_pose := "Lock_Fire" if sequence.mode == "fire" and sequence.elapsed >= 0.6 else "Lock_Ready"
	held_weapon.set_mechanism_pose(lock_pose, clampf((sequence.elapsed-0.6)/0.12, 0, 1) if lock_pose == "Lock_Fire" else 1.0)

func _apply_musket_shooting_pose(phase: String, p: float) -> void:
	_apply_authored_pose("ML_R08", 1.0)
	var motion := 1.0 if phase == "MusketFire" else 1.0-p if phase == "MusketLower" else p
	var amount := _smooth((motion - 0.25) / 0.75)
	# Keep the shoulders square. Small butt/shoulder contact is intentional.
	var working := held_weapon.transform
	var forward := Vector3.BACK
	var aim_basis := Basis(forward, Vector3.UP, Vector3.LEFT)
	# Stock rests just ahead of the shoulder; bore follows the actor's +Z.
	var aimed := Transform3D(aim_basis, _aim_position())
	held_weapon.transform = working.interpolate_with(aimed, amount)
	held_weapon.position.z += (0.11 if female else 0.08) * sin(amount * PI)
	var recoil := 0.0
	if phase == "MusketFire":
		recoil = sin(clampf((p-0.30)/0.22, 0, 1) * PI) * 0.010
		held_weapon.position.z -= recoil
	var left_contact := Vector3(lerpf(0.35 if female else 0.43, 0.12 if female else 0.15, _smooth(amount / 0.5)), lerpf(0.006, -0.025, amount), 0) * held_weapon.asset_scale()
	if weapon_id == "matchlock_arquebus":
		left_contact.x -= 0.030 * amount * held_weapon.asset_scale()
	if female: left_contact.z -= 0.050 * amount * held_weapon.asset_scale()
	support_contact = held_weapon.transform * left_contact
	_shooting_arm("l", support_contact, held_weapon.basis.x.slerp(Vector3.RIGHT, amount), Vector3(0.48, 1.02, 0.03).lerp(Vector3(0.06, 1.04, 0.30), _smooth(amount / 0.20)), amount)
	var hip := Vector3(-0.22, 0.98, 0.22)
	var lock_clearance := 0.04 * sin(amount * PI) if female and weapon_id == "flintlock_musket" else 0.0
	# Seat the neck inside the curled hand, not against the fingertips.
	var trigger := held_weapon.transform * (Vector3(-0.18 if weapon_id == "matchlock_arquebus" else -0.16, -0.015, -0.025 + lock_clearance) * held_weapon.asset_scale())
	var reach := _smooth(motion / 0.25)
	var firing_grip := hip.lerp(trigger, reach) + Vector3(-0.05, 0, 0.05) * sin(reach * PI)
	# Keep the elbow below the stock on both bodies. The narrower female
	# shoulder needs a lower pole target to reproduce the male arm posture.
	var firing_elbow := Vector3(-0.42, 1.02, 0.08).lerp(Vector3(-0.40, 1.18 if female else 1.24, 0.04), reach)
	firing_elbow += Vector3(-0.28, -0.10, 0.0) * sin(amount * PI)
	_shooting_arm("r", firing_grip, _firing_hand_width(reach), firing_elbow, reach)
	_curl_fingers("l", 1.05)
	_curl_fingers("r", lerpf(0.70, 1.10, reach))
	skeleton.force_update_all_bone_transforms()


func update_pose(state) -> void:
	_socket_reload = state != null and state.socket_attached and weapon_id != "matchlock_arquebus"
	if held_bayonet != null: held_bayonet.hide()
	super.update_pose(state)
	if held_weapon == null: return
	var open: bool = state != null and state.phase_id == "ML_R08" and state.phase_elapsed < state.phase_duration()*0.72
	held_weapon.set_mechanism_pose("Lock_Open" if open else "Lock_Ready",1.0)


func _shooting_arm(side: String, contact: Vector3, width: Vector3, hint: Vector3, amount: float) -> void:
	_grip_arm(side, contact, width, hint)
	# Share forearm roll with the humerus without over-rotating the support
	# upper arm. Its lower blend keeps the elbow mesh from folding inward.
	# Preserve elbow and wrist positions while distributing roll.
	var upper := skeleton.find_bone("upperarm_" + side)
	var lower := skeleton.find_bone("lowerarm_" + side)
	var upper_pose := skeleton.get_bone_global_pose(upper)
	var lower_pose := skeleton.get_bone_global_pose(lower)
	var direction := upper_pose.basis.y.normalized()
	var shared_width := (lower_pose.basis.z - direction * direction.dot(lower_pose.basis.z)).normalized()
	var aligned := Basis(direction.cross(shared_width), direction, shared_width).orthonormalized()
	_set_global_basis(upper, Basis(upper_pose.basis.get_rotation_quaternion().slerp(aligned.get_rotation_quaternion(), amount * (0.40 if side == "l" else 0.7))))
	_set_global_basis(lower, lower_pose.basis)
	skeleton.force_update_all_bone_transforms()

func _aim_position() -> Vector3:
	return Vector3(-0.18 if female else -0.16, 1.40 if female else 1.44, (0.365 if female else 0.390) - (0.8-held_weapon.asset_scale())*0.46)

func _firing_hand_width(reach: float) -> Vector3:
	# The firing palm closes inward onto the stock; its wrist stays outside.
	# Reach is already eased. A sideways waypoint passes close to the forearm
	# axis, making the projected roll spin rapidly at the start of the raise.
	# Turn directly from the hip grip to the firing grip instead.
	return Vector3.BACK.slerp(Vector3.UP, reach)

func _animation_prop_nodes() -> Array[Node3D]:
	var nodes := super._animation_prop_nodes()
	nodes.append(held_bayonet)
	return nodes

func _pose_clip_name(phase: String) -> String:
	return "Socket_" + phase if _socket_reload and not phase.is_empty() else super._pose_clip_name(phase)

func set_bayonet(attached: bool) -> void:
	held_weapon.set_bayonet_attached(attached)

func _bayonet_grip(removing: bool) -> Vector3:
	# Plug removal uses the side of the brass guard, behind the blade root.
	return Vector3(-0.020, -0.045, 0.0) if removing and weapon_id == "matchlock_arquebus" else Vector3(-0.085, 0, 0) if weapon_id == "matchlock_arquebus" else Vector3(-0.030, 0.040, 0.0)

func _apply_bayonet_pose(removing: bool, progress: float) -> void:
	var p := 1.0-progress if removing else progress
	if p < 0.20:
		_apply_authored_pose("ML_R00", p/0.20)
		return
	if p > 0.80:
		_apply_authored_pose("ML_R10", (p-0.80)/0.20)
		return
	_apply_authored_pose("ML_R08", 1.0)
	var loading := _smooth((p-0.20)/0.10) * (1.0-_smooth((p-0.70)/0.10))
	var load_phase := loading * 0.30
	held_weapon.transform = _match_transform("ML_R03", load_phase)
	support_contact = held_weapon.transform * _support_local("ML_R03", load_phase)
	_grip_arm("l", support_contact, held_weapon.basis.x, Vector3(0.48,1.02,0.03))
	_curl_fingers("l",1.05)
	var hip := Vector3(-0.22, 0.98, 0.22)
	var axis := held_weapon.basis.x
	var mount := held_weapon.transform * held_weapon.socket_position("bayonet_socket")
	var grip_local := _bayonet_grip(removing) * held_weapon.asset_scale()
	var seated := Transform3D(held_weapon.basis, mount)
	var clear := seated
	clear.origin += axis * (0.23 * held_weapon.asset_scale())
	# Travel outside the barrel, then align the handle before inserting it.
	var pocket := Transform3D(Basis(Quaternion(Vector3.RIGHT, Vector3.DOWN)), Vector3.ZERO)
	pocket.origin = hip - pocket.basis * grip_local
	var approach := clear
	approach.origin += held_weapon.basis.z * 0.12
	if p < 0.30: held_bayonet.transform = pocket
	elif p < 0.40: held_bayonet.transform = pocket.interpolate_with(approach, _smooth((p-0.30)/0.10))
	elif p < 0.50: held_bayonet.transform = approach.interpolate_with(clear, _smooth((p-0.40)/0.10))
	elif p < 0.60: held_bayonet.transform = clear.interpolate_with(seated, _smooth((p-0.50)/0.10))
	else: held_bayonet.transform = seated
	var contact := held_bayonet.transform * grip_local
	if p < 0.30: contact = hip
	elif p > 0.60: contact = contact.lerp(hip, _smooth((p-0.60)/0.10))
	var turn := _smooth((p-0.20)/0.10) * (1.0-_smooth((p-0.60)/0.10))
	var handling_width := Vector3.LEFT.slerp(-held_bayonet.basis.x if removing else held_bayonet.basis.x, _smooth((p-0.40)/0.10))
	var width := Vector3.BACK.slerp(handling_width, turn)
	var hint := Vector3(-0.42,1.02,0.08).lerp(Vector3(-0.42,1.10,0.22),turn)
	_grip_arm("r", contact, width, hint)
	_curl_fingers("r",lerpf(0.70,1.05,turn))
	skeleton.force_update_all_bone_transforms()
	# The hand owns the loose prop in transit; bore alignment takes over at .5.
	if p >= 0.30 and p < 0.50:
		held_bayonet.position += to_local(grip_world_position("r")) - contact

func update_bayonet_pose(removing: bool, elapsed: float) -> void:
	_socket_reload = false
	var clip := "BayonetRemove" if removing else "BayonetFit"
	var p := clampf(elapsed/BAYONET_DURATION,0,1)
	animation_player.play(clip)
	animation_player.seek(p*BAYONET_DURATION,true)
	animation_player.pause()
	_last_clip = clip
	current_phase = clip
	var fit_progress := 1.0-p if removing else p
	held_weapon.set_bayonet_attached(fit_progress >= 0.60)
	for key in ["rod","flask","shot","igniter"]: props[key].hide()
	props.pouch.visible = detail_level == 0
	held_bayonet.visible = fit_progress >= 0.30 and fit_progress < 0.60 and detail_level < 2
	skeleton.force_update_all_bone_transforms()
