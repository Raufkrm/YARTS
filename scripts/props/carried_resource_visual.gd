extends Node3D

var actor
var skeleton: Skeleton3D
var left := -1
var right := -1
var resource_type := ""

func configure(person, kind: String) -> void:
	actor = person
	resource_type = kind
	for node in actor.find_children("*", "Skeleton3D", true, false):
		skeleton = node
		break
	if skeleton != null:
		left = skeleton.find_bone("hand_l")
		right = skeleton.find_bone("hand_r")
		if left < 0: left = skeleton.find_bone("Hand.L")
		if right < 0: right = skeleton.find_bone("Hand.R")
	var visual := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	if kind == "wood":
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.55
		log_mesh.bottom_radius = 0.65
		log_mesh.height = 4.2
		log_mesh.radial_segments = 9
		visual.mesh = log_mesh
		visual.rotation.z = PI * 0.5
		material.albedo_color = Color(0.38, 0.22, 0.10)
	else:
		# A tied resource sack works for every inventory type, including new ones.
		var sack := SphereMesh.new()
		sack.radius = 1.0
		sack.height = 1.6
		sack.radial_segments = 10
		sack.rings = 5
		visual.mesh = sack
		visual.scale = Vector3(1.5,1,0.9)
		material.albedo_color = Color(0.55,0.43,0.25)
		var tie := MeshInstance3D.new()
		var cord := TorusMesh.new()
		cord.inner_radius = 0.22
		cord.outer_radius = 0.29
		tie.mesh = cord
		tie.position.y = 0.65
		add_child(tie)
	visual.material_override = material
	add_child(visual)
	process_priority = 100
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(actor): return
	global_basis = actor.global_basis.orthonormalized()
	if skeleton != null and left >= 0 and right >= 0:
		var a := skeleton.global_transform * skeleton.get_bone_global_pose(left).origin
		var b := skeleton.global_transform * skeleton.get_bone_global_pose(right).origin
		global_position = (a+b)*0.5 + Vector3.UP * 0.5
	else:
		global_position = actor.global_transform * Vector3(0,4.5,1.4)
