extends Node3D

@export_enum("brown", "white") var coat := "brown"
@export_range(0, 2) var lod_index := 1
@export var initial_animation := "Idle"

var animation_player: AnimationPlayer
var visual: Node3D
var current_animation := "Idle"


func _ready() -> void:
	set_lod(lod_index)
	play_animation(initial_animation)


func set_lod(index: int) -> void:
	index = clampi(index, 0, 2)
	var previous_time := animation_player.current_animation_position if is_instance_valid(animation_player) else 0.0
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	lod_index = index
	var packed := load("res://assets/models/camp_transport/horses/horse_%s_lod%d.glb" % [coat, index]) as PackedScene
	visual = packed.instantiate() as Node3D
	visual.name = "HorseVisual"
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	play_animation(current_animation)
	if animation_player != null:
		animation_player.seek(previous_time, true)


func play_animation(animation_name: String) -> bool:
	if animation_player == null:
		return false
	for available in animation_player.get_animation_list():
		if str(available).get_file() == animation_name:
			current_animation = animation_name
			animation_player.play(available, 0.18)
			return true
	return false


func set_speed(speed_mps: float) -> void:
	play_animation("Idle" if speed_mps < 0.05 else "Walk" if speed_mps < 2.7 else "Gallop")
	if animation_player != null:
		animation_player.speed_scale = 1.0 if speed_mps < 0.05 else clampf(speed_mps / (1.3 if speed_mps < 2.7 else 5.5), 0.5, 1.8)
