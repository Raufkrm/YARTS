extends RefCounted
## Batched shoreline plants and two-frame fireflies; up to eight nearby lights.
const Layout = preload("res://scripts/battle/rts_wetland_layout.gd")
const PLANT_SHADER = preload("res://shaders/wetland_foliage.gdshader")
const FIREFLY_SHADER = preload("res://shaders/firefly.gdshader")
const ROOT := "res://assets/models/environment/wetlands/"
const CHUNK := 160.0
const MAX_LIGHTS := 8
var host
var data: Dictionary
var root: Node3D
var plant_batches: Array[MultiMeshInstance3D] = []
var firefly_batches: Array[MultiMeshInstance3D] = []
var lights: Array[OmniLight3D] = []
var light_flies: Array[Dictionary] = []
var firefly_material: ShaderMaterial
var time := 0.0
var light_elapsed := 1.0
var selected_lights: Array[Dictionary] = []
static var meshes: Dictionary = {}

func configure(scene, records: Dictionary) -> void:
	host = scene
	data = records

func spawn() -> void:
	root = Node3D.new()
	root.name = "WetlandEcology"
	host.terrain_root.add_child(root)
	_spawn_plants()
	_spawn_fireflies()
	_spawn_fish()
	update(0.0)

func _spawn_plants() -> void:
	var buckets := {}
	for plant in data.get("plants", []):
		var p: Vector3 = plant.position
		var chunk := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
		var key := "%s_%d_%d" % [plant.asset, chunk.x, chunk.y]
		if not buckets.has(key): buckets[key] = {"asset": plant.asset, "chunk": chunk, "plants": []}
		buckets[key].plants.append(plant)
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = PLANT_SHADER
	leaf_material.set_shader_parameter("floating_leaf", true)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = PLANT_SHADER
	for key in buckets:
		var bucket: Dictionary = buckets[key]
		var leaf := str(bucket.asset).begins_with("lilypad")
		var origin := Vector3((bucket.chunk.x + 0.5) * CHUNK, 0, (bucket.chunk.y + 0.5) * CHUNK)
		var ranges := [0.0, 170.0, 430.0, 850.0] if leaf else [0.0, 160.0, 350.0, 650.0]
		var levels := 2 if bucket.asset == "high_grass" else 3
		for lod in range(levels):
			var mesh := mesh_for(str(bucket.asset), lod)
			if mesh == null: continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = bucket.plants.size()
			for index in range(bucket.plants.size()):
				var plant: Dictionary = bucket.plants[index]
				multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, plant.rotation).scaled(Vector3.ONE * plant.scale), plant.position - origin))
			var batch := MultiMeshInstance3D.new()
			batch.name = "%s_LOD%d" % [key, lod]
			batch.multimesh = multi
			batch.material_override = leaf_material if leaf else grass_material
			batch.position = origin
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_begin = ranges[lod]
			batch.visibility_range_end = ranges[lod + 1]
			root.add_child(batch)
			plant_batches.append(batch)

static func mesh_for(asset: String, lod: int) -> ArrayMesh:
	var path := ROOT + "%s_lod%d.glb" % [asset, lod]
	if meshes.has(path): return meshes[path]
	var scene := load(path) as PackedScene
	if scene == null: return null
	var instance := scene.instantiate()
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collect_mesh(instance, Transform3D.IDENTITY, combined)
	var mesh := combined.commit()
	instance.free()
	meshes[path] = mesh
	return mesh

static func _collect_mesh(node: Node, transform: Transform3D, target: SurfaceTool) -> void:
	if node is Node3D: transform = transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()): target.append_from(node.mesh, surface, transform)
	for child in node.get_children(): _collect_mesh(child, transform, target)

func _spawn_fireflies() -> void:
	firefly_material = ShaderMaterial.new()
	firefly_material.shader = FIREFLY_SHADER
	firefly_material.set_shader_parameter("atlas", load("res://assets/sprites/firefly_two_frame.svg"))
	var quad := QuadMesh.new()
	quad.size = Vector2(1.8, 1.8)
	for swarm in data.get("swarms", []):
		var rng := RandomNumberGenerator.new()
		rng.seed = swarm.seed
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = quad
		multi.instance_count = swarm.count
		multi.custom_aabb = AABB(Vector3(-20, -8, -20), Vector3(40, 20, 40))
		for index in range(swarm.count):
			var offset := Vector3(rng.randf_range(-10, 10), rng.randf_range(-1.0, 1.5), rng.randf_range(-10, 10))
			var phase := rng.randf() * TAU
			var speed := rng.randf_range(0.5, 1.2)
			multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, offset))
			multi.set_instance_custom_data(index, Color(phase, 0, 0, speed))
			if index == 0: light_flies.append({"position": Vector3(swarm.position) + offset, "phase": phase, "speed": speed})
		var batch := MultiMeshInstance3D.new()
		batch.name = "FireflySwarm_%d" % firefly_batches.size()
		batch.position = swarm.position
		batch.multimesh = multi
		batch.material_override = firefly_material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 420.0
		root.add_child(batch)
		firefly_batches.append(batch)
	for index in range(mini(MAX_LIGHTS, light_flies.size())):
		var light := OmniLight3D.new()
		light.name = "FireflyLight_%d" % index
		light.light_color = Color(1.0, 0.78, 0.15)
		light.omni_range = 13.0
		light.omni_attenuation = 1.7
		light.shadow_enabled = false
		root.add_child(light)
		lights.append(light)

func _spawn_fish() -> void:
	for school in data.get("fish", []):
		var p: Vector3 = school.position
		# Preserve every old resource ID; ponds use their own stable spatial IDs.
		# Existing schools inside the same safe envelope count toward the pond.
		var existing := false
		for resource in host.resource_nodes_by_id.values():
			if resource.resource_type == "fish" and resource.world_position.distance_to(p) < school.radius:
				# Keep an old school's yield/ID, but contain its visual orbits in the pond.
				for motion in host.fish_school_members:
					var member: Node3D = motion.node
					if member.get_parent() != resource.visual_node: continue
					motion.pond_school = true
					motion.center = member.get_parent().to_local(p) + Vector3(0, -0.55, 0)
					motion.radius_x = minf(motion.radius_x, school.radius * 0.45)
					motion.radius_z = minf(motion.radius_z, school.radius * 0.45)
					member.position = motion.center
				existing = true
				break
		if existing: continue
		host._spawn_resource_deposit({"resource_type": "fish", "resource_id": "wetland_fish_" + school.body_id,
			"asset": host.FISH_DEPOSIT_ASSETS[0], "assets": host.FISH_DEPOSIT_ASSETS, "position": p,
			"scale": 0.13, "deposit_size": "medium", "cluster_count": 8,
			"cluster_spread": float(school.radius) / 0.13, "visual_y_offset": -0.55,
			"amount": 70, "pond_school": true, "show_ring": true})

static func night_amount(sun_amount: float) -> float:
	return 1.0 - smoothstep(-0.12, 0.10, sun_amount)

static func flight_position(fly: Dictionary, elapsed: float) -> Vector3:
	var t: float = elapsed * fly.speed + fly.phase
	return Vector3(fly.position) + Vector3(sin(t) * 3.0, sin(t * 1.7) * 0.65, cos(t * 0.83) * 3.0)

func update(delta: float) -> void:
	if root == null: return
	time += delta
	var night := night_amount(Game.get_battle_sun_amount())
	firefly_material.set_shader_parameter("flight_time", time)
	firefly_material.set_shader_parameter("night_factor", night)
	for batch in firefly_batches: batch.visible = night > 0.01
	light_elapsed += delta
	if light_elapsed >= 0.5:
		light_elapsed = 0.0
		selected_lights.clear()
		if night > 0.01 and host.camera != null:
			var candidates := light_flies.duplicate()
			var camera_position: Vector3 = host.camera.global_position
			candidates.sort_custom(func(a, b): return Vector3(a.position).distance_squared_to(camera_position) < Vector3(b.position).distance_squared_to(camera_position))
			for fly in candidates:
				if selected_lights.size() >= MAX_LIGHTS: break
				if Vector3(fly.position).distance_to(camera_position) <= 240.0: selected_lights.append(fly)
	for index in range(lights.size()):
		var light := lights[index]
		light.visible = night > 0.01 and index < selected_lights.size()
		if not light.visible: continue
		var fly := selected_lights[index]
		light.position = flight_position(fly, time)
		light.light_energy = night * (0.65 + 0.25 * sin(time * 2.2 + fly.phase))
