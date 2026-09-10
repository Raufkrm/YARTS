extends SceneTree

const UnitActorScript = preload("res://scripts/battle/rts_unit_actor.gd")
const UnitDataScript = preload("res://scripts/data/rts_unit_data.gd")
const MoveOrderScript = preload("res://scripts/battle/rts_unit_move_order.gd")


func _init() -> void:
	var unit_data = UnitDataScript.new()
	unit_data.id = "movement_test"
	unit_data.position = Vector3(0.8, 0.0, 0.0)
	var actor = UnitActorScript.new()
	actor.configure(unit_data)
	actor.issue_move_order(MoveOrderScript.new(Vector3(1.0, 0.0, 0.0)))
	var arrived: bool = actor.update_movement(0.016, Callable(self, "_ground_position"), 0.25)
	assert(arrived)
	assert(is_equal_approx(actor.position.x, 0.8))
	assert(not actor.has_move_order())

	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var carry := Animation.new()
	carry.length = 1.0
	carry.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("Carry", carry)
	player.add_animation_library("", library)
	actor.add_child(player)
	actor.set_animation_player(player)
	actor.play_animation("Carry")
	actor.set_animation_paused(true)
	assert(is_zero_approx(player.speed_scale))
	actor.set_animation_paused(false)
	assert(is_equal_approx(player.speed_scale, 1.0))

	actor.free()
	print("Unit movement verification passed")
	quit()


func _ground_position(x: float, z: float) -> Vector3:
	return Vector3(x, 0.0, z)
