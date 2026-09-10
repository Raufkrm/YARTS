extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")
const ResourceNodeScript = preload("res://scripts/battle/rts_resource_node.gd")


func _ready() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var resource = ResourceNodeScript.new()
	resource.configure({
		"asset_path": "res://assets/Ultimate Nature Pack by Quaternius/OBJ/CommonTree_1.obj",
		"scale": 2.0,
	})
	var model := Node3D.new()
	add_child(model)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 1.0, 0.5)
	mesh_instance.mesh = mesh
	model.add_child(mesh_instance)
	var half_thickness: float = battle.call("_fit_felled_log_to_source_tree", model, resource)
	assert(is_equal_approx(model.scale.x, 2.85))
	assert(is_equal_approx(half_thickness, 1.425))
	model.free()
	battle.free()
	get_tree().quit()
