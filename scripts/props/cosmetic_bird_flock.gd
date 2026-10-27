extends Node3D

@export_enum("seagull", "crow") var species := "seagull"
@export_range(1, 64) var bird_count := 8
@export_range(0, 1) var lod_index := 0
@export var flight_radius := 5.0
@export var altitude := 4.0
@export var orbit_speed := 0.3
@export var flock_seed := 31
@export var gliding := false:
	set(value):
		gliding = value
		if material != null:
			material.set_shader_parameter("flap_amount", 0.0 if value else 1.0)

var birds: MultiMeshInstance3D
var material: ShaderMaterial
var _time := 0.0
var _phases := PackedFloat32Array()


func _ready() -> void:
	birds = MultiMeshInstance3D.new()
	birds.name = "CosmeticBirds"
	birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	birds.visibility_range_end = 180.0
	add_child(birds)
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/cosmetic_bird.gdshader")
	material.set_shader_parameter("wing_root", 0.045 if species == "seagull" else 0.03735)
	material.set_shader_parameter("flap_rate", 7.0 if species == "seagull" else 9.0)
	material.set_shader_parameter("flap_amount", 0.0 if gliding else 1.0)
	birds.material_override = material
	set_lod(lod_index)


func set_lod(index: int) -> void:
	lod_index = clampi(index, 0, 1)
	if birds == null:
		return
	var source := load("res://assets/models/wildlife/%s_lod%d.glb" % [species, lod_index]).instantiate() as Node3D
	var mesh := source.find_child("*", true, false) as MeshInstance3D
	if mesh == null:
		mesh = source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh.mesh
	multimesh.instance_count = clampi(bird_count, 1, 64)
	birds.multimesh = multimesh
	source.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = flock_seed
	_phases.resize(multimesh.instance_count)
	for i in range(multimesh.instance_count):
		_phases[i] = TAU * float(i) / multimesh.instance_count
		multimesh.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 1))
	# Include wing deformation and the full orbit in the culling bounds.
	var extent := maxf(flight_radius, 0.0) * 1.15 + 1.0
	multimesh.custom_aabb = AABB(Vector3(-extent, altitude - 1, -extent), Vector3(extent * 2, 2, extent * 2))
	_process(0.0)


func _process(delta: float) -> void:
	_time += delta
	if birds == null:
		return
	for i in range(_phases.size()):
		var angle := _phases[i] + _time * orbit_speed
		var radius := maxf(flight_radius, 0.0) * (0.85 + 0.05 * (i % 4))
		var point := Vector3(cos(angle) * radius, altitude + (sin(angle * 2) * 0.2 if radius > 0 else 0.0), sin(angle) * radius)
		var basis := Basis(Vector3.UP, -angle) if radius > 0 else Basis.IDENTITY
		birds.multimesh.set_instance_transform(i, Transform3D(basis, point))
