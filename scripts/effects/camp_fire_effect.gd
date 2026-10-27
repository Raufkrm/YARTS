extends Node3D
## Runtime-only fire shared by campfires and torches. No flame mesh is baked
## into their GLBs; all tongues, embers and smoke are generated here.

const FLAME_SHADER := preload("res://assets/shaders/camp_flame.gdshader")
const SMOKE_SHADER := preload("res://assets/shaders/camp_smoke.gdshader")

@export var burning := true:
	set(value):
		burning = value
		_apply_state()
@export_range(0.1, 2.0) var effect_scale := 1.0
@export var maximum_distance := 55.0
@export var smoke_enabled := true

var flames: MultiMeshInstance3D
var embers: CPUParticles3D
var smoke: CPUParticles3D
var glow: OmniLight3D
var coal_glow: MeshInstance3D
var elapsed := 0.0
var _near_camera := true


func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "FireVisual"
	visual.scale = Vector3.ONE * effect_scale
	add_child(visual)
	flames = MultiMeshInstance3D.new()
	flames.name = "FlameTongues"
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _flame_mesh()
	multimesh.instance_count = 9
	for i in range(9):
		var angle := TAU * float(i) / 6.0
		var inner := i >= 6
		var radius := 0.065 if inner else 0.21
		var height := 0.65 + 0.12 * float(i % 3)
		var width := 0.53 if inner else 0.70
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(width, height, width))
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(sin(angle) * radius, 0.01, cos(angle) * radius)))
		multimesh.set_instance_custom_data(i, Color(float(i) * 2.13, 0.85 if inner else 0.0, 0.0, 1.0))
	flames.multimesh = multimesh
	flames.material_override = material
	visual.add_child(flames)
	coal_glow = MeshInstance3D.new()
	var coal_mesh := CylinderMesh.new()
	coal_mesh.top_radius = 0.28
	coal_mesh.bottom_radius = 0.32
	coal_mesh.height = 0.012
	coal_mesh.radial_segments = 12
	coal_glow.mesh = coal_mesh
	coal_glow.position.y = -0.035
	var coal_material := StandardMaterial3D.new()
	coal_material.albedo_color = Color(0.21, 0.022, 0.004)
	coal_material.emission_enabled = true
	coal_material.emission = Color(0.85, 0.07, 0.008)
	coal_material.emission_energy_multiplier = 1.2
	coal_glow.material_override = coal_material
	visual.add_child(coal_glow)
	embers = CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 14
	embers.lifetime = 1.5
	embers.preprocess = 1.2
	embers.direction = Vector3.UP
	embers.spread = 19.0
	embers.initial_velocity_min = 0.45
	embers.initial_velocity_max = 1.1
	embers.gravity = Vector3(0.08, 0.08, 0.02)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.16
	embers.position.y = 0.28
	embers.scale_amount_min = 0.6
	embers.scale_amount_max = 1.25
	var spark := SphereMesh.new()
	spark.radius = 0.009
	spark.height = 0.024
	spark.radial_segments = 4
	spark.rings = 2
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.37, 0.015)
	spark_material.emission_energy_multiplier = 2.0
	spark.material = spark_material
	embers.mesh = spark
	embers.color_ramp = _gradient([Color(1, 0.73, 0.15), Color(1, 0.22, 0.015), Color(0.1, 0.01, 0.0)])
	visual.add_child(embers)
	smoke = CPUParticles3D.new()
	smoke.name = "SmokeWisps"
	smoke.amount = 9
	smoke.lifetime = 2.8
	smoke.preprocess = 1.5
	smoke.direction = Vector3.UP
	smoke.spread = 13.0
	smoke.gravity = Vector3(0.045, 0.015, 0.0)
	smoke.initial_velocity_min = 0.26
	smoke.initial_velocity_max = 0.42
	smoke.position.y = 0.52
	smoke.scale_amount_min = 0.3
	smoke.scale_amount_max = 0.7
	smoke.color_ramp = _gradient([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(0.8, 0.8)
	var smoke_material := ShaderMaterial.new()
	smoke_material.shader = SMOKE_SHADER
	smoke_mesh.material = smoke_material
	smoke.mesh = smoke_mesh
	visual.add_child(smoke)
	glow = OmniLight3D.new()
	glow.name = "FireLight"
	glow.light_color = Color(1.0, 0.44, 0.12)
	glow.omni_range = 4.3 * effect_scale
	glow.omni_attenuation = 1.5
	glow.position.y = 0.45 * effect_scale
	glow.shadow_enabled = false
	add_child(glow)
	_apply_state()


func _process(delta: float) -> void:
	elapsed += delta
	var camera := get_viewport().get_camera_3d()
	var near := camera == null or camera.global_position.distance_to(global_position) < maximum_distance
	if near != _near_camera:
		_near_camera = near
		_apply_state()
	if burning and _near_camera:
		glow.light_energy = (1.35 + sin(elapsed * 8.7) * 0.13 + sin(elapsed * 13.1) * 0.08) * sqrt(effect_scale)


func _apply_state() -> void:
	if not is_instance_valid(flames):
		return
	var active := burning and _near_camera
	flames.visible = active
	coal_glow.visible = active
	glow.visible = active
	embers.emitting = active
	embers.visible = active
	smoke.emitting = active and smoke_enabled
	smoke.visible = active and smoke_enabled


func _gradient(colors: Array[Color]) -> Gradient:
	var result := Gradient.new()
	result.colors = PackedColorArray(colors)
	result.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	return result


func _flame_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var radii := [0.18, 0.255, 0.19, 0.09, 0.002]
	for ring in range(5):
		var height := float(ring) / 4.0
		for side in range(6):
			var a := TAU * float(side) / 6.0
			vertices.append(Vector3(sin(a) * radii[ring], height, cos(a) * radii[ring]))
			uvs.append(Vector2(float(side) / 6.0, height))
	for ring in range(4):
		for side in range(6):
			var a := ring * 6 + side
			var b := ring * 6 + (side + 1) % 6
			indices.append_array(PackedInt32Array([a, b, a + 6, b, b + 6, a + 6]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
