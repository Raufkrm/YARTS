class_name RTSResourceNode
extends RefCounted

const STAGE_RAW := "raw"
const STAGE_STANDING_TREE := "standing_tree"
const STAGE_FELLED_LOG := "felled_log"

var id := ""
var resource_type := "wood"
var deposit_size := "medium"
var stage := STAGE_RAW
var world_position := Vector3.ZERO
var amount_remaining := 0
var initial_amount := 0
var harvest_amount := 1
var health := 0
var max_health := 0
var work_required := 1.0
var work_progress := 0.0
var chopped_down_threshold := 1.0
var gather_range := 8.0
var visual_radius := 5.0
var selection_height := 3.0
var asset_path := ""
var scale_value := 1.0
var rotation_y := 0.0
var depleted := false
var interaction_locked := false
var show_ring := true
var visual_node: Node3D
var visual_batches: Array = []
var batch_instance_index := -1
var ring_batch: MultiMeshInstance3D
var ring_instance_index := -1


func configure(data: Dictionary) -> void:
	id = str(data.get("id", id))
	resource_type = str(data.get("resource_type", resource_type))
	deposit_size = str(data.get("deposit_size", deposit_size))
	stage = str(data.get("stage", stage))
	world_position = data.get("world_position", world_position)
	amount_remaining = int(data.get("amount_remaining", amount_remaining))
	initial_amount = amount_remaining
	harvest_amount = int(data.get("harvest_amount", harvest_amount))
	max_health = int(data.get("max_health", 100 if stage == STAGE_FELLED_LOG else 0))
	health = clampi(int(data.get("health", max_health)), 0, max_health)
	work_required = float(data.get("work_required", work_required))
	work_progress = float(data.get("work_progress", work_progress))
	chopped_down_threshold = float(data.get("chopped_down_threshold", chopped_down_threshold))
	gather_range = float(data.get("gather_range", gather_range))
	visual_radius = float(data.get("visual_radius", visual_radius))
	selection_height = float(data.get("selection_height", selection_height))
	asset_path = str(data.get("asset_path", asset_path))
	scale_value = float(data.get("scale", scale_value))
	rotation_y = float(data.get("rotation", rotation_y))
	show_ring = bool(data.get("show_ring", show_ring))


func is_available() -> bool:
	return not interaction_locked and not depleted and amount_remaining > 0


func harvest(requested_limit: int = -1) -> int:
	if not is_available():
		return 0
	if stage == STAGE_FELLED_LOG and work_progress < max(0.1, work_required):
		return 0
	var amount: int = min(harvest_amount, amount_remaining)
	if stage == STAGE_FELLED_LOG:
		amount = min(amount, 1)
	if requested_limit >= 0:
		amount = min(amount, requested_limit)
	if amount <= 0:
		return 0
	amount_remaining -= amount
	if stage == STAGE_FELLED_LOG:
		health = roundi(float(max_health) * float(amount_remaining) / float(max(1, initial_amount)))
		work_progress = 0.0
	if amount_remaining <= 0:
		depleted = true
		health = 0
	return amount


func add_work(amount: float) -> bool:
	if not is_available():
		return false
	var threshold := chopped_down_threshold if stage == STAGE_STANDING_TREE else work_required
	work_progress = min(max(0.1, threshold), work_progress + max(0.0, amount))
	return work_progress >= max(0.1, threshold)


func progress_ratio() -> float:
	var threshold := chopped_down_threshold if stage == STAGE_STANDING_TREE else work_required
	return clamp(work_progress / max(0.1, threshold), 0.0, 1.0)


func transition_to_felled_log(log_work_required: float) -> void:
	stage = STAGE_FELLED_LOG
	harvest_amount = 1
	max_health = 100
	health = max_health
	work_required = max(0.1, log_work_required)
	work_progress = 0.0
	show_ring = true


func has_runtime_changes() -> bool:
	return depleted or amount_remaining != initial_amount or work_progress > 0.0 or stage == STAGE_FELLED_LOG


func set_visual_batches(batches: Array, instance_index: int) -> void:
	visual_batches = batches
	batch_instance_index = instance_index


func hide_visual(mark_depleted: bool = true) -> void:
	if mark_depleted:
		depleted = true
	if visual_node != null and is_instance_valid(visual_node):
		visual_node.visible = false
	for batch_value in visual_batches:
		var batch := batch_value as MultiMeshInstance3D
		if batch == null or not is_instance_valid(batch) or batch.multimesh == null:
			continue
		if batch_instance_index < 0 or batch_instance_index >= batch.multimesh.instance_count:
			continue
		var hidden_basis := Basis().scaled(Vector3.ONE * 0.001)
		batch.multimesh.set_instance_transform(batch_instance_index, Transform3D(hidden_basis, world_position + Vector3(0.0, -5000.0, 0.0)))
	hide_ring()


func set_ring_batch(batch: MultiMeshInstance3D, instance_index: int) -> void:
	ring_batch = batch
	ring_instance_index = instance_index


func hide_ring() -> void:
	if ring_batch == null or not is_instance_valid(ring_batch) or ring_batch.multimesh == null:
		return
	if ring_instance_index < 0 or ring_instance_index >= ring_batch.multimesh.instance_count:
		return
	var hidden_basis := Basis().scaled(Vector3.ONE * 0.001)
	ring_batch.multimesh.set_instance_transform(ring_instance_index, Transform3D(hidden_basis, world_position + Vector3(0.0, -5000.0, 0.0)))
