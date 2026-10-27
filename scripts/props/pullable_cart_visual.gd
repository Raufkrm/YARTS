extends Node3D
## Visual hitch/wheel support. Movement commands/pathfinding remain the caller's responsibility.

@export var wheel_radius := 0.44
@export var pull_distance := 1.75

var pull_target: Node3D
var _wheels: Array[Node3D] = []
var _previous_position := Vector3.ZERO


func _ready() -> void:
	for child in find_children("Wheel*", "MeshInstance3D", true, false):
		_wheels.append(child as Node3D)
	_previous_position = global_position


func set_pull_target(target: Node3D) -> void:
	pull_target = target
	_previous_position = global_position


func _process(_delta: float) -> void:
	if is_instance_valid(pull_target):
		var direction := pull_target.global_position - global_position
		direction.y = 0.0
		if direction.length() > 0.01:
			direction = direction.normalized()
			rotation.y = atan2(direction.x, direction.z)
			var next_position := pull_target.global_position - direction * pull_distance
			next_position.y = global_position.y
			global_position = next_position
	var movement := global_position - _previous_position
	var distance := movement.dot(global_basis.z.normalized())
	if absf(distance) < 5.0:
		for wheel in _wheels:
			wheel.rotate_x(distance / maxf(wheel_radius, 0.01))
	_previous_position = global_position
