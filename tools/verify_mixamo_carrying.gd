extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")
const TARGET_MODEL := preload("res://assets/reference_models/base_low_poly_male_reference_ual_rigged.glb")
const FEMALE_TARGET_MODEL := preload("res://assets/reference_models/base_low_poly_female_reference_ual_rigged.glb")
const AnimationCatalog = preload("res://scripts/tools/unit_animation_catalog.gd")
const EXPECTED_ANIMATIONS := {
	"Mixamo_Carry_Idle": true,
	"Mixamo_Carry_Walk": true,
	"Mixamo_Carry_Run": true,
	"Mixamo_Carry_Stop": false,
}


func _ready() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var library = battle.call("_get_unit_animation_library")
	assert(library is AnimationLibrary)
	var target_root := TARGET_MODEL.instantiate()
	add_child(target_root)
	var target_skeleton = battle.call("_find_first_skeleton", target_root)
	assert(target_skeleton is Skeleton3D)
	var target_prefix := "%s:" % str(target_root.get_path_to(target_skeleton))
	var female_root := FEMALE_TARGET_MODEL.instantiate()
	add_child(female_root)
	var female_skeleton = battle.call("_find_first_skeleton", female_root)
	assert(female_skeleton is Skeleton3D)
	assert(female_root.get_path_to(female_skeleton) == target_root.get_path_to(target_skeleton))
	for animation_name in EXPECTED_ANIMATIONS:
		assert(library.has_animation(animation_name), "Missing remapped animation: %s" % animation_name)
		var animation: Animation = library.get_animation(animation_name)
		assert(animation.get_track_count() >= 20, "Animation does not animate the full body: %s" % animation_name)
		var animated_bones := {}
		for track_index in range(animation.get_track_count()):
			var track_path := str(animation.track_get_path(track_index))
			assert(animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D, "Gameplay clip contains root motion: %s" % animation_name)
			assert(
				track_path.begins_with(target_prefix),
				"Animation track does not target the gameplay skeleton: %s" % track_path
			)
			animated_bones[track_path.get_slice(":", 1)] = true
		for required_bone in ["pelvis", "spine_01", "spine_03", "upperarm_l", "lowerarm_r", "thigh_l", "calf_r", "foot_l"]:
			assert(animated_bones.has(required_bone), "Animation is missing body bone %s: %s" % [required_bone, animation_name])
		var expected_loop: bool = EXPECTED_ANIMATIONS[animation_name]
		assert((animation.loop_mode == Animation.LOOP_LINEAR) == expected_loop)
	var player := AnimationPlayer.new()
	player.root_node = NodePath("..")
	player.add_animation_library("", library)
	target_root.add_child(player)
	for animation_name in EXPECTED_ANIMATIONS:
		player.play(animation_name)
		player.advance(0.1)
	var female_player := AnimationPlayer.new()
	female_player.root_node = NodePath("..")
	female_player.add_animation_library("", library)
	female_root.add_child(female_player)
	for animation_name in EXPECTED_ANIMATIONS:
		female_player.play(animation_name)
		female_player.advance(0.1)
	assert(library.get_animation("Mixamo_Carry_Stop").length <= 1.251)
	var catalog_result: Dictionary = AnimationCatalog.build_library(target_root)
	assert(catalog_result.library is AnimationLibrary)
	for animation_name in EXPECTED_ANIMATIONS:
		assert(catalog_result.names.has(animation_name), "Animation viewer is missing: %s" % animation_name)
		var viewer_animation: Animation = catalog_result.library.get_animation(animation_name)
		assert(viewer_animation.get_track_count() >= 20, "Animation viewer clip is not full-body: %s" % animation_name)
		for track_index in range(viewer_animation.get_track_count()):
			assert(viewer_animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D, "Viewer clip contains root motion: %s" % animation_name)
	target_root.free()
	female_root.free()
	battle.free()
	get_tree().quit()
