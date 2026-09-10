class_name RTSUnitMoveOrder
extends RefCounted

const GAIT_WALK := "walk"
const GAIT_JOG := "jog"

var target := Vector3.ZERO
var gait := GAIT_WALK
var speed_multiplier := 1.0
var animation_speed := 1.0


func _init(order_target: Vector3 = Vector3.ZERO, order_gait: String = GAIT_WALK, movement_speed_multiplier: float = 1.0, animation_speed_multiplier: float = 1.0) -> void:
	target = order_target
	gait = order_gait
	speed_multiplier = max(0.1, movement_speed_multiplier)
	animation_speed = max(0.05, animation_speed_multiplier)


func is_jog() -> bool:
	return gait == GAIT_JOG
