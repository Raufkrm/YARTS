extends "res://scripts/tools/handgonne_human_drill.gd"
## Standalone preview: IK is used while baking; playback only samples cached clips.

const Crossbow = preload("res://scripts/props/crossbow_prop.gd")
const Catalog = preload("res://scripts/tools/unit_animation_catalog.gd")
const PHASE_NAMES := ["Plant", "Attach windlass", "Span", "Stow windlass", "Load bolt", "Raise"]
const PHASE_STARTS := [0.0, 1.0, 2.5, 7.5, 9.0, 11.0, 12.0]
const FIRE_RELEASE := 1.1
const FIRE_DURATION := 1.7
static var _crossbow_clips: Dictionary = {}
var crossbow: Crossbow
var _rest_positions: Array[Vector3] = []
var _gaits: Dictionary = {}
var durations := {"Carry": 2.0, "Walk": 1.0, "Jog": 1.0, "Reload": 12.0, "Fire": FIRE_DURATION, "Aim": 0.7}
var left_target := Vector3.ZERO
var right_target := Vector3.ZERO
var left_width := Vector3.RIGHT
var right_width := Vector3.RIGHT
var _base_human_y := 0.0
var pelvis_bob := 0.0

func _ready() -> void:
	name = "CrossbowHumanDrill"
	human = (load("res://assets/reference_models/base_low_poly_female_reference_ual_rigged.glb") if female else HUMAN).instantiate() as Node3D
	human.name = "Human"; add_child(human)
	skeleton = human.find_child("Skeleton3D", true, false) as Skeleton3D
	var bounds := _bounds(human)
	_body_scale = 1.75 / bounds.size.y
	human.scale = Vector3.ONE * _body_scale
	human.position.y = -bounds.position.y * _body_scale
	_base_human_y = human.position.y
	var skin := StandardMaterial3D.new(); skin.albedo_color = Color("7d8980"); skin.roughness = 0.95
	for mesh in human.find_children("*", "MeshInstance3D", true, false): mesh.material_override = skin
	for bone in range(skeleton.get_bone_count()):
		_rest_rotations.append(skeleton.get_bone_pose_rotation(bone))
		_rest_positions.append(skeleton.get_bone_pose_position(bone))
		_rest_global.append(skeleton.get_bone_global_pose(bone))
	crossbow = Crossbow.new(); crossbow.name = "Crossbow"
	if female: crossbow.bolt_grip.x = -0.165
	add_child(crossbow)
	animation_player = AnimationPlayer.new(); animation_player.name = "CrossbowAnimations"
	animation_player.root_node = NodePath("..")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animation_player)
	_load_gaits()
	var cache_key := str(female)
	if not _crossbow_clips.has(cache_key):
		var library := AnimationLibrary.new()
		for mode: String in durations: library.add_animation(mode, _bake_crossbow_clip(mode))
		_crossbow_clips[cache_key] = library
	animation_player.add_animation_library("", _crossbow_clips[cache_key])
	show_pose("Carry", 0)

func _load_gaits() -> void:
	var source := load("res://assets/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb").instantiate() as Node3D
	var player := Catalog.find_first_animation_player(source)
	var source_skeleton := Catalog.find_first_skeleton(source)
	for pair in [["Walk", "Walk"], ["Jog", "Jog_Fwd"]]:
		var clip := Catalog.retarget_animation(player.get_animation(pair[1]), pair[1], source_skeleton, skeleton, get_path_to(skeleton))
		Catalog.Kneeling.preserve_vertical_motion(clip, player.get_animation(pair[1]), source_skeleton, skeleton, get_path_to(skeleton))
		_gaits[pair[0]] = clip
		durations[pair[0]] = clip.length
	source.free()

func _bake_crossbow_clip(mode: String) -> Animation:
	var clip := Animation.new(); clip.length = durations[mode]
	clip.loop_mode = Animation.LOOP_NONE if mode in ["Reload", "Fire", "Aim"] else Animation.LOOP_LINEAR
	for bone in range(skeleton.get_bone_count()):
		for kind in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
			var track := clip.add_track(kind)
			clip.track_set_path(track, NodePath(str(get_path_to(skeleton)) + ":" + skeleton.get_bone_name(bone)))
	var height_track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(height_track, NodePath("Human:position:y"))
	var frames := ceili(clip.length * 30.0)
	for frame in range(frames + 1):
		var time := clip.length * float(frame) / frames
		_author_pose(mode, 0.0 if frame == frames and mode not in ["Reload", "Fire", "Aim"] else time)
		for bone in range(skeleton.get_bone_count()):
			clip.rotation_track_insert_key(bone * 2, time, skeleton.get_bone_pose_rotation(bone))
			clip.position_track_insert_key(bone * 2 + 1, time, skeleton.get_bone_pose_position(bone))
		clip.track_insert_key(height_track, time, human.position.y)
	if mode in ["Walk", "Jog"]:
		# Preserve the original leg keys and interpolation exactly; only the arms
		# and upper body need baking. Resampling fast foot arcs changes the gait.
		var source: Animation = _gaits[mode]
		for track in range(clip.get_track_count() - 1, -1, -1):
			var bone_name := str(clip.track_get_path(track)).get_slice(":", 1)
			if _is_leg(bone_name): clip.remove_track(track)
		for track in range(source.get_track_count()):
			if _is_leg(str(source.track_get_path(track)).get_slice(":", 1)):
				source.copy_track(track, clip)
	return clip

func _is_leg(bone_name: String) -> bool:
	return bone_name.begins_with("thigh_") or bone_name.begins_with("calf_") or bone_name.begins_with("foot_") or bone_name.begins_with("ball_")

func _sample_gait(mode: String, time: float) -> void:
	var clip: Animation = _gaits[mode]
	for track in range(clip.get_track_count()):
		var bone := skeleton.find_bone(str(clip.track_get_path(track)).get_slice(":", 1))
		if bone < 0: continue
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var rotation := clip.rotation_track_interpolate(track, time)
			# Keep the original legs and pelvis; soften the upper-body swing.
			if skeleton.get_bone_name(bone) in ["spine_01", "spine_02", "spine_03", "neck_01", "Head"]:
				rotation = _rest_rotations[bone].slerp(rotation, 0.35 if mode == "Jog" else 0.55)
			skeleton.set_bone_pose_rotation(bone, rotation)
		elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			skeleton.set_bone_pose_position(bone, clip.position_track_interpolate(track, time))
	skeleton.force_update_all_bone_transforms()
	var pelvis := skeleton.find_bone("pelvis")
	pelvis_bob = (skeleton.get_bone_global_pose(pelvis).origin.y - _rest_global[pelvis].origin.y) * _body_scale

func _author_pose(mode: String, time: float) -> void:
	if mode == "Aim": mode = "Fire"
	human.position.y = _base_human_y
	for bone in range(skeleton.get_bone_count()):
		skeleton.set_bone_pose_rotation(bone, _rest_rotations[bone])
		skeleton.set_bone_pose_position(bone, _rest_positions[bone])
	pelvis_bob = 0.0
	if mode in ["Walk", "Jog"]: _sample_gait(mode, time)
	var load := loading_amount(time) if mode == "Reload" else 0.0
	if load > 0:
		var lean := _smooth((time - 9.0) / 0.6) * load
		var pelvis := skeleton.find_bone("pelvis")
		var parent := skeleton.get_bone_parent(pelvis)
		var parent_basis := _rest_global[parent].basis if parent >= 0 else Basis.IDENTITY
		var shift := skeleton.global_basis.inverse() * global_basis * Vector3(0, -0.07 * load, 0)
		skeleton.set_bone_pose_position(pelvis, _rest_positions[pelvis] + parent_basis.inverse() * shift)
		_rotate_world("spine_01", Vector3.RIGHT, (0.16 + 0.25 * lean) * load)
		_rotate_world("spine_03", Vector3.RIGHT, (0.10 + 0.10 * lean) * load)
		# Step the left foot into the stirrup; right foot remains grounded.
		var foot := skeleton.find_bone("foot_l")
		var rest_foot := to_local(skeleton.to_global(_rest_global[foot].origin))
		var target := rest_foot.lerp(Vector3(0.11, rest_foot.y, 0.29), load)
		target.y += 0.085 * sin(load * PI)
		_solve_chain("thigh_l", "calf_l", "foot_l", target, Vector3(0.17, 0.55, 0.70))
		_set_global_basis(foot, _rest_global[foot].basis)
		var right_foot := skeleton.find_bone("foot_r")
		var right_rest := to_local(skeleton.to_global(_rest_global[right_foot].origin))
		_solve_chain("thigh_r", "calf_r", "foot_r", right_rest, Vector3(-0.17, 0.55, 0.4))
		_set_global_basis(right_foot, _rest_global[right_foot].basis)
	configure_props(mode, time)
	_grip_arm("l", left_target, left_width, Vector3(0.42, 0.94, 0.24))
	var supply_reach := _smooth((time - 8.7) / 0.3) * loading_amount(time) if mode == "Reload" else 0.0
	var right_hint := Vector3(-0.42, 1.00, -0.10).lerp(Vector3(-0.42, 0.94, 0.24), supply_reach)
	if mode == "Fire": right_hint = right_hint.lerp(Vector3(-0.42, 1.13, 0.08), fire_raise_amount(time))
	_grip_arm("r", right_target, right_width, right_hint)
	_curl_fingers("l", 0.9); _curl_fingers("r", 0.9)
	skeleton.force_update_all_bone_transforms()

func loading_amount(time: float) -> float:
	if time < 1.0: return _smooth(time)
	if time > 11.0: return 1.0 - _smooth(time - 11.0)
	return 1.0

func _crossbow_transform(amount: float, bob: float) -> Transform3D:
	var forward := Vector3(0.75, 0.12, 0.65).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var carry := Transform3D(Basis(forward, side.cross(forward).normalized(), side), Vector3(0, 1.09 + bob * 0.55, 0.35))
	var down := Vector3(0, -0.993, 0.12).normalized()
	var load := Transform3D(Basis(down, Vector3(0, 0.12, 0.993).normalized(), Vector3.LEFT), Vector3(0.11, 0.597, 0.29))
	return carry.interpolate_with(load, amount)

func configure_props(mode: String, time: float) -> void:
	if mode == "Aim": mode = "Fire"
	var reload := mode == "Reload"
	var loading := loading_amount(time) if reload else 0.0
	crossbow.transform = _crossbow_transform(loading, 0.0 if reload else pelvis_bob)
	var draw := clampf((time - 2.5) / 5.0, 0, 1) if reload else 1.0
	if mode == "Fire":
		var aimed := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-0.18, 1.34, 0.52))
		var weight := fire_raise_amount(time)
		crossbow.transform = crossbow.transform.interpolate_with(aimed, weight)
		# A small mechanical follow-through, not firearm recoil.
		var kick := sin(clampf((time - FIRE_RELEASE) / 0.12, 0, 1) * PI) * 0.006
		crossbow.position.z -= kick
		draw = 1.0 - _smooth((time - FIRE_RELEASE) / 0.055)
	crossbow.set_draw(draw)
	crossbow.set_release(_smooth((time - FIRE_RELEASE) / 0.055) if mode == "Fire" else 0.0)
	var stowed := Transform3D(Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT), Vector3(-0.24, 1.04, 0.09))
	if mode in ["Walk", "Jog"]: stowed.origin.y += pelvis_bob
	var mounted := crossbow.transform * Transform3D(Basis.IDENTITY, crossbow.socket_position("windlass_mount"))
	var attached := 0.0
	if reload and time >= 1 and time <= 9:
		attached = _smooth((time - 1.5) / 0.75) if time < 2.5 else 1.0 - _smooth((time - 7.7) / 0.9) if time > 7.5 else 1.0
	var winch := stowed.interpolate_with(mounted, attached)
	winch.origin += Vector3(0, 0.12, 0.0) * sin(attached * PI)
	crossbow.windlass.global_transform = global_transform * winch
	var angle := TAU * 4.0 * clampf((time - 2.5) / 5.0, 0, 1) if reload else 0.0
	crossbow.cranks.rotation.z = angle
	crossbow.quiver.global_transform = global_transform * Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT), Vector3(-0.29, 0.80, -0.06))
	if mode in ["Walk", "Jog"]: crossbow.quiver.global_position.y += pelvis_bob
	crossbow.update_ropes(reload and time >= 2.25 and time <= 7.7)
	var carried_left := crossbow.transform * crossbow.socket_position("support_grip")
	# Support the wooden tiller from its top/outer face while the other hand
	# stows the windlass or loads a bolt; leave the underside trigger clear.
	var high_left := crossbow.transform * Vector3(-0.40, 0.040, 0)
	left_target = carried_left.lerp(high_left, loading)
	right_target = crossbow.transform * crossbow.socket_position("trigger_grip")
	left_width = crossbow.basis.x
	right_width = crossbow.basis.x
	if mode == "Fire":
		left_target = crossbow.transform * Vector3(lerpf(0.08, -0.10, fire_raise_amount(time)), -0.04, 0)
		right_width = _crossbow_transform(0, 0).basis.x.slerp(Vector3.UP, fire_raise_amount(time))
	var right_crank := to_local(crossbow.crank_contact("r"))
	var left_crank := to_local(crossbow.crank_contact("l"))
	if reload:
		if time >= 1.0 and time < 2.5:
			right_target = right_target.lerp(right_crank, _smooth((time - 1.0) / 0.5))
			left_target = left_target.lerp(left_crank, _smooth((time - 2.05) / 0.45))
			right_width = right_width.slerp(Vector3.RIGHT, _smooth((time - 1.0) / 0.5))
			left_width = left_width.slerp(Vector3.RIGHT, _smooth((time - 2.05) / 0.45))
		elif time >= 2.5 and time <= 7.5:
			left_target = left_crank; right_target = right_crank
			left_width = Vector3.RIGHT; right_width = Vector3.RIGHT
		elif time > 7.5 and time < 9.0:
			left_target = left_crank.lerp(left_target, _smooth((time - 7.5) / 0.25))
			right_target = right_crank.lerp(right_target, _smooth((time - 8.5) / 0.5))
			left_width = Vector3.RIGHT.slerp(left_width, _smooth((time - 7.5) / 0.25))
			right_width = Vector3.RIGHT.slerp(right_width, _smooth((time - 8.5) / 0.5))
	var bolt_seated := crossbow.transform * Transform3D(Basis.IDENTITY, crossbow.bolt_grip)
	var bolt_supply := Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT), Vector3(-0.29, 1.05, -0.015))
	var bolt_pose := bolt_seated
	crossbow.bolt.visible = not reload or time >= 9.25
	if mode == "Fire": crossbow.bolt.visible = time < FIRE_RELEASE
	if reload and time >= 9.0 and time < 11.0:
		var progress := (time - 9.0) / 2.0
		var lift := _smooth((progress - 0.15) / 0.60)
		bolt_pose = bolt_supply.interpolate_with(bolt_seated, lift)
		bolt_pose.origin += Vector3(-0.03, 0.12, 0.08) * sin(lift * PI)
		right_target = right_target.lerp(bolt_pose.origin, _smooth(progress / 0.15))
		right_target = right_target.lerp(crossbow.transform * crossbow.socket_position("trigger_grip"), _smooth((progress - 0.82) / 0.18))
	crossbow.bolt.global_transform = global_transform * bolt_pose

func show_pose(mode: String, time: float) -> void:
	var sample := clampf(time, 0, float(durations[mode])) if mode in ["Reload", "Fire", "Aim"] else fposmod(time, float(durations[mode]))
	animation_player.play(mode)
	animation_player.seek(sample, true)
	animation_player.pause()
	skeleton.force_update_all_bone_transforms()
	var pelvis := skeleton.find_bone("pelvis")
	pelvis_bob = (skeleton.get_bone_global_pose(pelvis).origin.y - _rest_global[pelvis].origin.y) * _body_scale
	configure_props(mode, sample)
	current_phase = phase_name(sample) if mode == "Reload" else mode
	if mode == "Fire":
		current_phase = "Raise and aim" if sample < 0.7 else "Aim" if sample < FIRE_RELEASE else "Release" if sample < 1.22 else "Recover" if sample < FIRE_DURATION else "Empty carry"

func fire_raise_amount(time: float) -> float:
	return _smooth(time / 0.7) * (1.0 - _smooth((time - 1.22) / 0.48))

func phase_name(time: float) -> String:
	for index in range(6):
		if time < PHASE_STARTS[index + 1]: return PHASE_NAMES[index]
	return "Loaded carry"

func set_detail_level(level: int) -> void:
	detail_level = clampi(level, 0, 2)
	crossbow.set_detail_level(detail_level)
