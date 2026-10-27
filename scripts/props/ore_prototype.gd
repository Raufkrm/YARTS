extends Node3D

const ROOT := "res://assets/models/resources/ore_prototypes/"
const MINERAL_SHADER = preload("res://assets/shaders/ore_mineral.gdshader")
const KINDS := ["coal", "iron", "copper", "tin", "silver", "gold", "uranium"]
static var _materials: Dictionary = {}
static var _geometry: Dictionary = {}

@export_enum("coal", "iron", "copper", "tin", "silver", "gold", "uranium") var ore_kind := "iron"
@export_range(1, 3) var variant := 1
@export_range(0, 2) var detail_level := 0
@export var battle_view := false
var model: MeshInstance3D
var shine := true


func _ready() -> void:
	if model == null: set_detail(detail_level)


static func shared_material(kind: String, lod: int, enabled: bool, in_battle: bool = false) -> ShaderMaterial:
	var key := "%s_%d_%s_%s" % [kind, lod, enabled, in_battle]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = MINERAL_SHADER
		material.resource_name = "OreMineral_%s" % key
		material.set_shader_parameter("close_detail", ([1.0, 1.0, 0.0] if in_battle else [1.0, 0.25, 0.0])[lod])
		material.set_shader_parameter("metallic_strength", 0.0 if kind in ["coal", "uranium"] else 1.0)
		material.set_shader_parameter("shine_enabled", enabled)
		material.set_shader_parameter("distance_scale", 0.2 if in_battle else 1.0)
		if kind == "tin":
			material.set_shader_parameter("stone_tint", Color(0.38, 0.48, 0.59))
			material.set_shader_parameter("stone_tint_amount", 0.38)
		elif kind == "iron":
			material.set_shader_parameter("rust_amount", 0.62)
		_materials[key] = material
	return _materials[key]


func set_detail(lod: int) -> void:
	detail_level = clampi(lod, 0, 2)
	# Keep the approved rounded outcrop and continuous veins at every distance.
	# Detail levels simplify shading only; retired pointed meshes must not return.
	var path := ROOT + "ore_%s_v%02d_lod0.glb" % [ore_kind, variant]
	if not _geometry.has(path):
		var source := (load(path) as PackedScene).instantiate()
		var mesh_node := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var local_transform := mesh_node.transform
		var ancestor := mesh_node.get_parent()
		while ancestor is Node3D:
			local_transform = ancestor.transform * local_transform
			ancestor = ancestor.get_parent()
		_geometry[path] = {"mesh": mesh_node.mesh, "transform": local_transform}
		source.free()
	if model == null:
		model = MeshInstance3D.new()
		model.name = "Model"
		add_child(model)
	model.mesh = _geometry[path].mesh
	model.transform = _geometry[path].transform
	model.position.y -= 0.04
	model.material_override = shared_material(ore_kind, detail_level, shine, battle_view)


func set_shine(enabled: bool) -> void:
	shine = enabled
	if model != null: model.material_override = shared_material(ore_kind, detail_level, shine, battle_view)


func update_camera_detail(camera_position: Vector3, immediate: bool = false) -> void:
	var distance := global_position.distance_to(camera_position) / maxf(global_basis.x.length(), 0.001)
	var desired := 0 if distance < 45.0 else (1 if distance < 160.0 else 2)
	# Hysteresis prevents rapid swaps at a threshold; reuse one node and cached meshes.
	if not immediate:
		if detail_level == 0 and distance < 49.5: desired = 0
		elif detail_level == 1 and distance > 40.5 and distance < 176.0: desired = 1
		elif detail_level == 2 and distance > 144.0: desired = 2
	if desired != detail_level: set_detail(desired)
