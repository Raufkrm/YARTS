extends Node3D

@export_enum("deer", "boar", "camel", "polar_bear", "penguin", "sheep", "cow", "goat") var species := "deer"
@export_range(0, 2) var lod_index := 1
@export var initial_animation := "Idle"

var animation_player: AnimationPlayer
var visual: Node3D
var current_animation := "Idle"


func _ready() -> void:
	set_lod(lod_index)
	play_animation(initial_animation)


func set_lod(index: int) -> void:
	var previous_time := animation_player.current_animation_position if is_instance_valid(animation_player) else 0.0
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	lod_index = clampi(index, 0, 2)
	var packed := load("res://assets/models/wildlife/%s_lod%d.glb" % [species, lod_index]) as PackedScene
	visual = packed.instantiate() as Node3D
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if play_animation(current_animation):
		animation_player.seek(fmod(previous_time, animation_player.current_animation_length), true)


func play_animation(animation_name: String) -> bool:
	if animation_player == null:
		return false
	for available in animation_player.get_animation_list():
		if str(available).get_file() == animation_name:
			current_animation = animation_name
			animation_player.play(available, 0.18)
			return true
	return false
