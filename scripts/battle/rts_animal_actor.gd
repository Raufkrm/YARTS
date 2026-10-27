extends Node3D

const Catalog = preload("res://scripts/data/wildlife_catalog.gd")
const GaitShader = preload("res://shaders/animal_locomotion.gdshader")
var data
var navigation
var visual: Node3D
var lod := 1
var path := PackedVector3Array()
var path_index := 0
var path_revision := -1
var shortcut_remaining := 0.0
var gait: ShaderMaterial
var phase := 0.0
var moving := false
var decision_elapsed := 0.0
var motion_elapsed := 0.0
var think_interval := 0.8
var current_clip := ""
var selection: MeshInstance3D

func configure(animal, nav) -> void:
	data = animal
	navigation = nav
	data.position = navigation.ground(data.position)
	position = data.position
	rotation.y = data.rotation_y
	name = data.id
	decision_elapsed = float(posmod(data.id.hash(), 100)) * 0.01
	set_lod(1)
	selection = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 3.8
	ring.outer_radius = 4.2
	ring.rings = 24
	ring.ring_segments = 4
	selection.mesh = ring
	selection.position.y = 0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.95, 0.8)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection.material_override = material
	selection.visible = false
	add_child(selection)

func set_lod(index: int) -> void:
	lod = clampi(index, 0, 2)
	if visual == null:
		var scene: String = Catalog.SPECIES[data.species].scene
		if data.species == "horse": scene = "horse_%s" % data.coat
		visual = (load("res://scenes/props/%s.tscn" % scene) as PackedScene).instantiate()
		visual.lod_index = lod
		visual.scale = Vector3.ONE * 5.0
		add_child(visual)
	else:
		visual.set_lod(lod)
	if not Catalog.SPECIES[data.species].rigged:
		gait = ShaderMaterial.new()
		gait.shader = GaitShader
		var first := true
		var bounds := AABB()
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			mesh.material_override = gait
		var height := maxf(0.1, bounds.size.y)
		gait.set_shader_parameter("body_height", height)
		gait.set_shader_parameter("belly_height", bounds.position.y + height * (0.18 if data.species == "penguin" else 0.43))
		gait.set_shader_parameter("center_z", bounds.get_center().z)
		gait.set_shader_parameter("penguin", data.species == "penguin")
		gait.set_shader_parameter("phase", phase)
		gait.set_shader_parameter("motion", 1.0 if moving else 0.0)
	current_clip = ""

func move_to(target: Vector3) -> bool:
	var route: PackedVector3Array = navigation.route(position, target, 3.0, clampf(float(Catalog.SPECIES[data.species].speed) * 0.35, 4.0, 12.0))
	if route.is_empty():
		stop()
		return false
	data.target = navigation.ground(target)
	path = route
	path_index = 0
	path_revision = navigation.revision
	shortcut_remaining = float(posmod(str(data.id).hash(), 200)) / 1000.0
	moving = true
	return true

func stop() -> void:
	path.clear()
	moving = false

func update_motion(delta: float, on_screen: bool) -> void:
	if data.health <= 0:
		stop()
		visible = false
		return
	if moving and path_revision != navigation.revision:
		move_to(data.target)
	if moving:
		shortcut_remaining -= delta
		if shortcut_remaining <= 0.0:
			shortcut_remaining = 0.2
			if path_index + 1 < path.size() and navigation.segment_clear(position, data.target, 3.0):
				path = PackedVector3Array([navigation.ground(data.target)])
				path_index = 0
		var travel: float = float(Catalog.SPECIES[data.species].speed) * delta * (1.6 if data.behavior == "fleeing" else 1.0)
		while travel > 0.0 and path_index < path.size():
			var target: Vector3 = path[path_index]
			var direction := Vector3(target.x - position.x, 0, target.z - position.z)
			var distance := direction.length()
			if distance <= 0.00001:
				path_index += 1
				shortcut_remaining = 0.0
				continue
			var step := minf(distance, travel)
			var next_position := position + direction.normalized() * step
			if not navigation.segment_clear(position, next_position, 3.0):
				move_to(data.target)
				break
			position = next_position
			position = navigation.ground(position)
			rotation.y = atan2(direction.x, direction.z)
			travel -= step
		if path_index >= path.size(): stop()
	data.position = position
	data.rotation_y = rotation.y
	if on_screen:
		phase += delta * (8.0 if data.behavior == "fleeing" else 5.0)
		if gait != null:
			gait.set_shader_parameter("phase", phase)
			gait.set_shader_parameter("motion", 1.0 if moving else 0.0)
		var clip := "Walk" if moving else ("Eating" if data.behavior == "grazing" else "Idle")
		if clip != current_clip:
			visual.play_animation(clip)
			current_clip = clip
	if visual.animation_player != null: visual.animation_player.speed_scale = 1.0 if on_screen else 0.0
