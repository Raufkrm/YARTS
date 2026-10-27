extends "res://scripts/battle/battle_scene.gd"
## Reproducible pond / lagoon / river fixture and a close model gallery.
var gallery: Node3D
var preview_night := false
var preview_controls: CanvasLayer
var records: Dictionary

func _ready() -> void:
	_setup_preview()

func _setup_preview() -> void:
	cell = preload("res://scripts/data/cell_data.gd").new()
	cell.id = "WETLAND_PREVIEW"
	cell.owner_id = "player"
	cell.resources = {}
	cell.rts_state = {"founding_allowance": "spent"}
	_build_scene()
	_make_ground()
	records = WetlandLayout.generate(self, PackedFloat32Array(), 0)
	wetlands = preload("res://scripts/battle/rts_wetlands.gd").new()
	wetlands.configure(self, records)
	wetlands.spawn()
	_restore_resource_state()
	_make_gallery()
	show_pond()
	set_night(false)
	_build_preview_controls()

func _process(delta: float) -> void:
	if wetlands == null: return
	wetlands.update(delta)
	_update_fish_school_motion(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N: set_night(not preview_night)
		elif event.keycode == KEY_1: show_pond()
		elif event.keycode == KEY_2: show_gallery()
		elif event.keycode == KEY_3: show_lagoon()
		elif event.keycode == KEY_4: show_fireflies()

func _unhandled_input(_event: InputEvent) -> void:
	pass

func water_distance(p: Vector2) -> float:
	var pond := p.length() - 90.0
	var lagoon := p.distance_to(Vector2(380, 0)) - 100.0
	var neck := maxf(absf(p.y) - 14.0, maxf(465 - p.x, p.x - 640))
	var ocean := 620.0 - p.x
	var river := absf(p.x + 260) - 20.0
	return minf(minf(pond, lagoon), minf(neck, minf(ocean, river)))

func _sample_cell_uv(u: float, v: float) -> Dictionary:
	return _sample_cell_uv_raw(u, v)

func _sample_cell_uv_raw(u: float, v: float) -> Dictionary:
	var p := (Vector2(u, v) - Vector2.ONE * 0.5) * MAP_SIZE
	var water := water_distance(p) < 0.0
	var river := water and absf(p.x + 260) < 21
	return {"terrain": "water" if water and not river else "plains", "biome": "grassland", "river": 0.85 if river else 0.0,
		"elevation": WorldState.SEA_LEVEL - 0.11 if water else WorldState.SEA_LEVEL + 0.10,
		"moisture": 0.7, "temperature": 0.6, "ridge": 0.45, "raw_noise": 0.5}

func _height_from_smoothed_terrain_at_uv(u: float, v: float, _heights: PackedFloat32Array, _length: int) -> float:
	var p := (Vector2(u, v) - Vector2.ONE * 0.5) * MAP_SIZE
	return lerpf(-1.35, 1.25, smoothstep(-8, 8, water_distance(p)))

func _make_ground() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var steps := Vector2i(200, 130)
	for z in range(steps.y + 1):
		for x in range(steps.x + 1):
			var p := Vector2(lerpf(-600, 800, float(x) / steps.x), lerpf(-455, 455, float(z) / steps.y))
			var y := _height_from_smoothed_terrain_at_uv(p.x / MAP_SIZE + 0.5, p.y / MAP_SIZE + 0.5, PackedFloat32Array(), 0)
			vertices.append(Vector3(p.x, y, p.y))
			normals.append(Vector3.UP)
			uvs.append(p / MAP_SIZE)
			colors.append(Color(0.26, 0.34, 0.15) if y > 0.2 else Color(0.18, 0.21, 0.12))
	for z in range(steps.y):
		for x in range(steps.x):
			var index := z * (steps.x + 1) + x
			indices.append_array(PackedInt32Array([index, index + 1, index + steps.x + 1, index + 1, index + steps.x + 2, index + steps.x + 1]))
	var ground := MeshInstance3D.new()
	ground.mesh = _mesh_from_arrays(vertices, normals, colors, uvs, indices)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	ground.material_override = material
	terrain_root.add_child(ground)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 910)
	water.mesh = plane
	water.position = Vector3(100, WATER_SURFACE_HEIGHT, 0)
	water.material_override = _water_material(false)
	terrain_root.add_child(water)

func _make_gallery() -> void:
	gallery = Node3D.new()
	gallery.name = "WetlandModelGallery"
	add_child(gallery)
	gallery.position = Vector3(0, 40, -800)
	var plate := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(44, 22)
	plate.mesh = plane
	plate.material_override = _material(Color("182923"))
	gallery.add_child(plate)
	var names := ["lilypad_round", "lilypad_white_flower", "lilypad_pink_cluster", "cattails", "high_grass"]
	var titles := ["Round pad", "White blossom", "Pink cluster", "Cattails", "Tall grass"]
	for i in range(names.size()):
		var plant := MeshInstance3D.new()
		plant.mesh = wetlands.mesh_for(names[i], 0)
		plant.position = Vector3((i - 2) * 8, 0.04, 0)
		plant.scale = Vector3.ONE * 5
		var material := ShaderMaterial.new()
		material.shader = wetlands.PLANT_SHADER
		material.set_shader_parameter("floating_leaf", i < 3)
		plant.material_override = material
		gallery.add_child(plant)
		var label := Label3D.new()
		label.text = titles[i]
		label.position = Vector3((i - 2) * 8, 0.12, 5.8)
		label.rotation_degrees.x = -90
		label.font_size = 30
		label.pixel_size = 0.03
		gallery.add_child(label)
	gallery.hide()

func _build_preview_controls() -> void:
	preview_controls = CanvasLayer.new()
	add_child(preview_controls)
	var bar := HBoxContainer.new()
	bar.position = Vector2(18, 18)
	bar.add_theme_constant_override("separation", 8)
	preview_controls.add_child(bar)
	for item in [["Pond [1]", show_pond], ["Models [2]", show_gallery], ["Lagoon [3]", show_lagoon], ["Fireflies [4]", show_fireflies], ["Day / night [N]", func(): set_night(not preview_night)]]:
		var button := _make_compact_button(item[0])
		button.pressed.connect(item[1])
		bar.add_child(button)
	bar.add_child(preload("res://scripts/tools/preview_scene_selector.gd").new())

func show_pond() -> void:
	gallery.hide()
	terrain_root.show()
	camera.position = Vector3(80, 145, 195)
	camera.look_at(Vector3(0, 0, 0))

func show_lagoon() -> void:
	gallery.hide()
	terrain_root.show()
	camera.position = Vector3(400, 155, 210)
	camera.look_at(Vector3(425, 0, 0))

func show_gallery() -> void:
	set_night(false)
	gallery.show()
	terrain_root.hide()
	camera.position = gallery.position + Vector3(0, 29, 27)
	camera.look_at(gallery.position + Vector3(0, 1, 0))

func show_fireflies() -> void:
	gallery.hide()
	terrain_root.show()
	set_night(true)
	if wetlands.light_flies.is_empty(): return
	var center: Vector3 = wetlands.flight_position(wetlands.light_flies[0], wetlands.time)
	camera.position = center + Vector3(1, 3, 9)
	camera.look_at(center)
	wetlands.update(0.6)

func set_night(enabled: bool) -> void:
	preview_night = enabled
	Game.set_battle_sun_context(Vector3(0.4, -0.7 if enabled else 0.9, 0.3), -0.5 if enabled else 0.8)
	_update_sun_lighting(1.0)
	if wetlands != null: wetlands.update(0.6)
