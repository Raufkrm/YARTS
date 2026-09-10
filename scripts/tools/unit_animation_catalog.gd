class_name UnitAnimationCatalog
extends RefCounted

const PACKS := [
	{
		"label": "UAL1",
		"path": "res://assets/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb",
	},
	{
		"label": "UAL2",
		"path": "res://assets/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb",
	},
	{
		"label": "Mixamo Carry Idle",
		"path": "res://assets/animations/mixamo/carrying/Carrying.fbx",
		"animation_name": "Mixamo_Carry_Idle",
		"loop": true,
	},
	{
		"label": "Mixamo Carry Walk",
		"path": "res://assets/animations/mixamo/carrying/Walking.fbx",
		"animation_name": "Mixamo_Carry_Walk",
		"loop": true,
	},
	{
		"label": "Mixamo Carry Run",
		"path": "res://assets/animations/mixamo/carrying/Running.fbx",
		"animation_name": "Mixamo_Carry_Run",
		"loop": true,
	},
	{
		"label": "Mixamo Carry Stop",
		"path": "res://assets/animations/mixamo/carrying/Walk To Stop.fbx",
		"animation_name": "Mixamo_Carry_Stop",
		"loop": false,
	},
	{
		"label": "Mixamo Swimming",
		"path": "res://assets/animations/mixamo/swimming/Swimming.fbx",
		"animation_name": "Mixamo_Swimming",
		"loop": true,
	},
	{
		"label": "Mixamo Treading Water",
		"path": "res://assets/animations/mixamo/swimming/Treading Water.fbx",
		"animation_name": "Mixamo_Treading_Water",
		"loop": true,
	},
]
const BONE_MAP := {
	"pelvis": "Hips",
	"spine_01": "Spine",
	"spine_02": "Spine",
	"spine_03": "Chest",
	"neck_01": "Neck",
	"Head": "Head",
	"clavicle_l": "Shoulder.L",
	"upperarm_l": "UpperArm.L",
	"lowerarm_l": "LowerArm.L",
	"hand_l": "Hand.L",
	"thumb_01_l": "Thumb.L",
	"clavicle_r": "Shoulder.R",
	"upperarm_r": "UpperArm.R",
	"lowerarm_r": "LowerArm.R",
	"hand_r": "Hand.R",
	"thumb_01_r": "Thumb.R",
	"thigh_l": "UpperLeg.L",
	"calf_l": "LowerLeg.L",
	"foot_l": "Foot.L",
	"thigh_r": "UpperLeg.R",
	"calf_r": "LowerLeg.R",
	"foot_r": "Foot.R",
	"mixamorig_Hips": "pelvis",
	"mixamorig_Spine": "spine_01",
	"mixamorig_Spine1": "spine_02",
	"mixamorig_Spine2": "spine_03",
	"mixamorig_Neck": "neck_01",
	"mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "clavicle_l",
	"mixamorig_LeftArm": "upperarm_l",
	"mixamorig_LeftForeArm": "lowerarm_l",
	"mixamorig_LeftHand": "hand_l",
	"mixamorig_LeftHandThumb1": "thumb_01_l",
	"mixamorig_LeftHandThumb2": "thumb_02_l",
	"mixamorig_LeftHandThumb3": "thumb_03_l",
	"mixamorig_LeftHandThumb4": "thumb_04_leaf_l",
	"mixamorig_LeftHandIndex1": "index_01_l",
	"mixamorig_LeftHandIndex2": "index_02_l",
	"mixamorig_LeftHandIndex3": "index_03_l",
	"mixamorig_LeftHandIndex4": "index_04_leaf_l",
	"mixamorig_LeftHandMiddle1": "middle_01_l",
	"mixamorig_LeftHandMiddle2": "middle_02_l",
	"mixamorig_LeftHandMiddle3": "middle_03_l",
	"mixamorig_LeftHandMiddle4": "middle_04_leaf_l",
	"mixamorig_LeftHandRing1": "ring_01_l",
	"mixamorig_LeftHandRing2": "ring_02_l",
	"mixamorig_LeftHandRing3": "ring_03_l",
	"mixamorig_LeftHandRing4": "ring_04_leaf_l",
	"mixamorig_LeftHandPinky1": "pinky_01_l",
	"mixamorig_LeftHandPinky2": "pinky_02_l",
	"mixamorig_LeftHandPinky3": "pinky_03_l",
	"mixamorig_LeftHandPinky4": "pinky_04_leaf_l",
	"mixamorig_RightShoulder": "clavicle_r",
	"mixamorig_RightArm": "upperarm_r",
	"mixamorig_RightForeArm": "lowerarm_r",
	"mixamorig_RightHand": "hand_r",
	"mixamorig_RightHandThumb1": "thumb_01_r",
	"mixamorig_RightHandThumb2": "thumb_02_r",
	"mixamorig_RightHandThumb3": "thumb_03_r",
	"mixamorig_RightHandThumb4": "thumb_04_leaf_r",
	"mixamorig_RightHandIndex1": "index_01_r",
	"mixamorig_RightHandIndex2": "index_02_r",
	"mixamorig_RightHandIndex3": "index_03_r",
	"mixamorig_RightHandIndex4": "index_04_leaf_r",
	"mixamorig_RightHandMiddle1": "middle_01_r",
	"mixamorig_RightHandMiddle2": "middle_02_r",
	"mixamorig_RightHandMiddle3": "middle_03_r",
	"mixamorig_RightHandMiddle4": "middle_04_leaf_r",
	"mixamorig_RightHandRing1": "ring_01_r",
	"mixamorig_RightHandRing2": "ring_02_r",
	"mixamorig_RightHandRing3": "ring_03_r",
	"mixamorig_RightHandRing4": "ring_04_leaf_r",
	"mixamorig_RightHandPinky1": "pinky_01_r",
	"mixamorig_RightHandPinky2": "pinky_02_r",
	"mixamorig_RightHandPinky3": "pinky_03_r",
	"mixamorig_RightHandPinky4": "pinky_04_leaf_r",
	"mixamorig_LeftUpLeg": "thigh_l",
	"mixamorig_LeftLeg": "calf_l",
	"mixamorig_LeftFoot": "foot_l",
	"mixamorig_LeftToeBase": "ball_l",
	"mixamorig_LeftToe_End": "ball_leaf_l",
	"mixamorig_RightUpLeg": "thigh_r",
	"mixamorig_RightLeg": "calf_r",
	"mixamorig_RightFoot": "foot_r",
	"mixamorig_RightToeBase": "ball_r",
	"mixamorig_RightToe_End": "ball_leaf_r",
}
const BASE_SOURCE_PATH := "res://assets/reference_models/base_low_poly_source.glb"
const BASE_MALE_RIGGED_PATH := "res://assets/reference_models/base_low_poly_male_reference_ual_rigged.glb"
const BASE_FEMALE_RIGGED_PATH := "res://assets/reference_models/base_low_poly_female_reference_ual_rigged.glb"


static func discover_human_models() -> Array[Dictionary]:
	var paths: Array[String] = []
	_collect_glb_files("res://assets/reference_models", paths)
	var female_mannequin := "res://assets/Universal Animation Library 2[Standard]/Female Mannequin/Unreal-Godot/Mannequin_F.glb"
	if ResourceLoader.exists(female_mannequin):
		paths.append(female_mannequin)
	paths.sort()

	var models: Array[Dictionary] = []
	if ResourceLoader.exists(BASE_SOURCE_PATH) and ResourceLoader.exists(BASE_MALE_RIGGED_PATH) and ResourceLoader.exists(BASE_FEMALE_RIGGED_PATH):
		models.append({
			"label": "New Low Poly Model for Main Game",
			"type": "pair",
			"paths": [BASE_MALE_RIGGED_PATH, BASE_FEMALE_RIGGED_PATH],
			"figure_labels": ["Male", "Female"],
			"source_path": BASE_SOURCE_PATH,
		})
	for path in paths:
		if path == BASE_SOURCE_PATH:
			continue
		models.append({
			"label": _friendly_model_name(path),
			"type": "single",
			"path": path,
		})
	return models


static func build_library(target_root: Node3D) -> Dictionary:
	var target_skeleton := find_first_skeleton(target_root)
	if target_skeleton == null:
		return {"library": null, "names": [], "status": "This model has no Skeleton3D, so it can only be inspected."}

	var library := AnimationLibrary.new()
	var names: Array[String] = []
	var loaded_packs := 0
	var target_path := target_root.get_path_to(target_skeleton)
	for pack in PACKS:
		var preferred_animation_name := str(pack.get("animation_name", ""))
		var packed_scene = load(str(pack.path))
		if not packed_scene is PackedScene:
			continue
		var source_root := (packed_scene as PackedScene).instantiate()
		var source_player := find_first_animation_player(source_root)
		var source_skeleton := find_first_skeleton(source_root)
		if source_player == null or source_skeleton == null:
			source_root.queue_free()
			continue
		loaded_packs += 1
		for source_library_name in source_player.get_animation_library_list():
			var source_library := source_player.get_animation_library(source_library_name)
			if source_library == null:
				continue
			for source_name_value in source_library.get_animation_list():
				var source_name := str(source_name_value)
				var animation_name := preferred_animation_name if not preferred_animation_name.is_empty() else source_name
				var remapped := _retarget_animation(
					source_library.get_animation(source_name_value),
					animation_name,
					source_skeleton,
					target_skeleton,
					target_path
				)
				if remapped == null or remapped.get_track_count() == 0:
					continue
				if pack.has("loop"):
					remapped.loop_mode = Animation.LOOP_LINEAR if bool(pack.loop) else Animation.LOOP_NONE
				var unique_name := _unique_name(library, animation_name, str(pack.label))
				library.add_animation(unique_name, remapped)
				names.append(unique_name)
		source_root.queue_free()
	names.sort()
	var status := "%d animations available from %d packs." % [names.size(), loaded_packs]
	if names.is_empty():
		status = "No compatible animation tracks were found for this skeleton."
	return {"library": library if not names.is_empty() else null, "names": names, "status": status}


static func find_first_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := find_first_animation_player(child)
		if result != null:
			return result
	return null


static func find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := find_first_skeleton(child)
		if result != null:
			return result
	return null


static func retarget_animation(source: Animation, animation_name: String, source_skeleton: Skeleton3D, target_skeleton: Skeleton3D, target_path: NodePath) -> Animation:
	if source == null:
		return null
	if source_skeleton.find_bone("mixamorig_Hips") >= 0:
		return _retarget_global_delta_animation(source, animation_name, source_skeleton, target_skeleton, target_path)
	var result := Animation.new()
	result.length = source.length
	result.loop_mode = Animation.LOOP_LINEAR if _looks_looping(animation_name) else source.loop_mode
	var used_paths := {}
	for source_track in range(source.get_track_count()):
		var track_type := source.track_get_type(source_track)
		# Preview locomotion in place. Source rigs use different local axes, so
		# copying root translation can turn forward travel into vertical travel.
		if track_type != Animation.TYPE_ROTATION_3D:
			continue
		var source_bone_name := _bone_from_track(source.track_get_path(source_track))
		if source_bone_name.is_empty():
			continue
		var target_bone_name := _resolve_target_bone(source_bone_name, target_skeleton)
		if target_bone_name.is_empty():
			continue
		var track_key := "%s:%s:%d" % [str(target_path), target_bone_name, track_type]
		if used_paths.has(track_key):
			continue
		used_paths[track_key] = true
		var source_bone_index := source_skeleton.find_bone(source_bone_name)
		var target_bone_index := target_skeleton.find_bone(target_bone_name)
		if source_bone_index < 0 or target_bone_index < 0:
			continue
		var target_track := result.add_track(track_type)
		result.track_set_path(target_track, NodePath("%s:%s" % [str(target_path), target_bone_name]))
		result.track_set_interpolation_type(target_track, source.track_get_interpolation_type(source_track))
		for key_index in range(source.track_get_key_count(source_track)):
			var value = source.track_get_key_value(source_track, key_index)
			if value is Quaternion:
				var source_rest := source_skeleton.get_bone_rest(source_bone_index).basis.get_rotation_quaternion()
				var target_rest := target_skeleton.get_bone_rest(target_bone_index).basis.get_rotation_quaternion()
				value = (target_rest * source_rest.inverse() * (value as Quaternion)).normalized()
			else:
				continue
			result.track_insert_key(
				target_track,
				source.track_get_key_time(source_track, key_index),
				value,
				source.track_get_key_transition(source_track, key_index)
			)
	return result


static func _retarget_global_delta_animation(source: Animation, animation_name: String, source_skeleton: Skeleton3D, target_skeleton: Skeleton3D, target_path: NodePath) -> Animation:
	var result := Animation.new()
	result.length = source.length
	result.loop_mode = Animation.LOOP_LINEAR if _looks_looping(animation_name) else source.loop_mode

	var source_tracks := {}
	for track_index in range(source.get_track_count()):
		if source.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var source_bone_name := _bone_from_track(source.track_get_path(track_index))
		var source_bone_index := source_skeleton.find_bone(source_bone_name)
		if source_bone_index >= 0:
			source_tracks[source_bone_index] = track_index

	var target_to_source := {}
	for source_bone_index in source_tracks:
		var source_name := str(source_skeleton.get_bone_name(source_bone_index))
		var target_name := _resolve_target_bone(source_name, target_skeleton)
		var target_bone_index := target_skeleton.find_bone(target_name)
		if target_bone_index >= 0:
			target_to_source[target_bone_index] = source_bone_index

	var result_tracks := {}
	for target_bone_index in target_to_source:
		var target_track := result.add_track(Animation.TYPE_ROTATION_3D)
		var target_name := str(target_skeleton.get_bone_name(target_bone_index))
		result.track_set_path(target_track, NodePath("%s:%s" % [str(target_path), target_name]))
		result.track_set_interpolation_type(target_track, Animation.INTERPOLATION_LINEAR)
		result_tracks[target_bone_index] = target_track

	# Godot rotation tracks contain absolute local bone poses. Sampling in global
	# space avoids converting reflected Mixamo rest bases into invalid quaternions.
	var sample_rate := 30.0
	var sample_count := maxi(2, int(ceil(source.length * sample_rate)) + 1)
	for sample_index in range(sample_count):
		var sample_time := minf(float(sample_index) / sample_rate, source.length)
		var source_globals: Array[Basis] = []
		source_globals.resize(source_skeleton.get_bone_count())
		for source_bone_index in range(source_skeleton.get_bone_count()):
			var pose_rotation := Quaternion.IDENTITY
			if source_tracks.has(source_bone_index):
				var interpolated = source.rotation_track_interpolate(int(source_tracks[source_bone_index]), sample_time)
				if interpolated is Quaternion:
					pose_rotation = interpolated as Quaternion
			var animated_local := (
				Basis(pose_rotation)
				if source_tracks.has(source_bone_index)
				else source_skeleton.get_bone_rest(source_bone_index).basis
			)
			var source_parent := source_skeleton.get_bone_parent(source_bone_index)
			source_globals[source_bone_index] = source_globals[source_parent] * animated_local if source_parent >= 0 else animated_local

		var target_globals: Array[Basis] = []
		target_globals.resize(target_skeleton.get_bone_count())
		for target_bone_index in range(target_skeleton.get_bone_count()):
			var target_rest := target_skeleton.get_bone_rest(target_bone_index).basis
			var target_parent := target_skeleton.get_bone_parent(target_bone_index)
			var parent_global := target_globals[target_parent] if target_parent >= 0 else Basis.IDENTITY
			var desired_global := parent_global * target_rest
			if target_to_source.has(target_bone_index):
				var source_bone_index: int = target_to_source[target_bone_index]
				var source_rest_global := source_skeleton.get_bone_global_rest(source_bone_index).basis
				var source_global_delta := source_globals[source_bone_index] * source_rest_global.inverse()
				var target_rest_global := target_skeleton.get_bone_global_rest(target_bone_index).basis
				desired_global = source_global_delta * target_rest_global
			target_globals[target_bone_index] = desired_global

			if not result_tracks.has(target_bone_index):
				continue
			var animated_local := (parent_global.inverse() * desired_global).orthonormalized()
			result.track_insert_key(int(result_tracks[target_bone_index]), sample_time, animated_local.get_rotation_quaternion())

	return result


static func _retarget_animation(source: Animation, animation_name: String, source_skeleton: Skeleton3D, target_skeleton: Skeleton3D, target_path: NodePath) -> Animation:
	return retarget_animation(source, animation_name, source_skeleton, target_skeleton, target_path)


static func _resolve_target_bone(source_name: String, target: Skeleton3D) -> String:
	if target.find_bone(source_name) >= 0:
		return source_name
	if BONE_MAP.has(source_name) and target.find_bone(str(BONE_MAP[source_name])) >= 0:
		return str(BONE_MAP[source_name])
	var normalized_source := _normalized_bone_name(source_name)
	for bone_index in range(target.get_bone_count()):
		var candidate := str(target.get_bone_name(bone_index))
		if _normalized_bone_name(candidate) == normalized_source:
			return candidate
	return ""


static func _normalized_bone_name(value: String) -> String:
	return value.to_lower().replace("mixamorig", "").replace("_", "").replace(".", "").replace("-", "")


static func _bone_from_track(path: NodePath) -> String:
	var path_text := str(path)
	var separator := path_text.rfind(":")
	return path_text.substr(separator + 1) if separator >= 0 else ""


static func _skeleton_height(skeleton: Skeleton3D) -> float:
	var minimum_y := 1.0e20
	var maximum_y := -1.0e20
	for bone_index in range(skeleton.get_bone_count()):
		var origin := skeleton.get_bone_global_rest(bone_index).origin
		minimum_y = min(minimum_y, origin.y)
		maximum_y = max(maximum_y, origin.y)
	return max(maximum_y - minimum_y, 0.001)


static func _looks_looping(animation_name: String) -> bool:
	var lower := animation_name.to_lower()
	for keyword in ["idle", "walk", "jog", "run", "sprint", "crouch", "dance", "swim", "crawl", "driving", "push"]:
		if lower.find(keyword) >= 0:
			return true
	return false


static func _unique_name(library: AnimationLibrary, animation_name: String, pack_label: String) -> String:
	if not library.has_animation(animation_name):
		return animation_name
	var candidate := "%s - %s" % [pack_label, animation_name]
	var suffix := 2
	while library.has_animation(candidate):
		candidate = "%s %d - %s" % [pack_label, suffix, animation_name]
		suffix += 1
	return candidate


static func _collect_glb_files(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_glb_files(path, output)
			elif entry.get_extension().to_lower() == "glb":
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _friendly_model_name(path: String) -> String:
	var name := path.get_file().get_basename().replace("_", " ")
	return name.capitalize()
