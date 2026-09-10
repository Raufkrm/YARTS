class_name RTSUnitDeliveryAction
extends RefCounted

const STATE_APPROACH := "approach"
const STATE_DONE := "done"

var target_id := ""
var target_position := Vector3.ZERO
var range := 8.0
var state := STATE_APPROACH


func _init(action_target_id: String = "", action_target_position: Vector3 = Vector3.ZERO, action_range: float = 8.0) -> void:
	target_id = action_target_id
	target_position = action_target_position
	range = max(0.5, action_range)


func complete() -> void:
	state = STATE_DONE


func is_done() -> bool:
	return state == STATE_DONE
