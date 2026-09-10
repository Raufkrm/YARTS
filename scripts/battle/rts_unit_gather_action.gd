class_name RTSUnitGatherAction
extends RefCounted

const STATE_APPROACH := "approach"
const STATE_WORK := "work"
const STATE_DONE := "done"

var target_id := ""
var resource_type := "wood"
var target_position := Vector3.ZERO
var approach_position := Vector3.ZERO
var work_required := 1.0
var work_done := 0.0
var harvest_amount := 1
var range := 8.0
var state := STATE_APPROACH


func _init(action_target_id: String = "", action_resource_type: String = "wood", action_target_position: Vector3 = Vector3.ZERO, action_approach_position: Vector3 = Vector3.ZERO, action_work_required: float = 1.0, action_harvest_amount: int = 1, action_range: float = 8.0) -> void:
	target_id = action_target_id
	resource_type = action_resource_type
	target_position = action_target_position
	approach_position = action_approach_position
	work_required = max(0.1, action_work_required)
	harvest_amount = max(1, action_harvest_amount)
	range = max(0.5, action_range)


func add_work(amount: float) -> void:
	work_done = clamp(work_done + max(0.0, amount), 0.0, work_required)
	if work_done >= work_required:
		state = STATE_DONE
	else:
		state = STATE_WORK


func progress_ratio() -> float:
	return clamp(work_done / work_required, 0.0, 1.0)


func is_done() -> bool:
	return state == STATE_DONE or work_done >= work_required
