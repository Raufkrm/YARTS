extends Node3D

const MAP_SIZE := 240.0
const TERRAIN_STEPS := 96
const PROP_EXTENT := 108.0
const CAMERA_PAN_SPEED := 46.0
const CAMERA_FAST_MULTIPLIER := 2.2
const CAMERA_ZOOM_STEP := 8.0
const CAMERA_MIN_HEIGHT := 22.0
const CAMERA_MAX_HEIGHT := 115.0
const CAMERA_MIN_Z := 24.0
const CAMERA_MAX_Z := 130.0

var cell
var terrain_root: Node3D
var camera: Camera3D
var summary_label: Label
var event_log_label: RichTextLabel


func _ready() -> void:
	cell = Game.get_current_cell()
	_build_scene()
	_build_overlay()
	_refresh_overlay()


func _process(delta: float) -> void:
	_update_rts_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(CAMERA_ZOOM_STEP)


func _build_scene() -> void:
	terrain_root = Node3D.new()
	terrain_root.name = "LargeRTSCell"
	add_child(terrain_root)

	var sun := DirectionalLight3D.new()
	sun.name = "BattleSun"
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(5.5, 8.0, 4.0), Vector3.ZERO, Vector3.UP)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.42, 0.62, 0.85)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.42)
	environment.ambient_light_energy = 0.55
	world_environment.environment = environment
	add_child(world_environment)

	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "LargeRTSPlane"
	terrain_mesh.mesh = _build_terrain_mesh()
	terrain_root.add_child(terrain_mesh)

	var grid_mesh := MeshInstance3D.new()
	grid_mesh.name = "RTSScaleGrid"
	grid_mesh.mesh = _build_ground_grid_mesh()
	terrain_root.add_child(grid_mesh)

	_spawn_cell_props()
	_spawn_town_center()
	_spawn_units()
	_spawn_enemy_marker()

	camera = Camera3D.new()
	camera.name = "RTSCamera"
	camera.position = Vector3(0.0, 72.0, 72.0)
	camera.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	camera.fov = 50.0
	camera.current = true
	add_child(camera)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BattleOverlay"
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(380, 260)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	margin.add_child(stack)

	var title := Label.new()
	title.text = "RTS Work Plane"
	title.add_theme_font_size_override("font_size", 20)
	stack.add_child(title)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(summary_label)

	var actions := HBoxContainer.new()
	stack.add_child(actions)

	var victory_button := Button.new()
	victory_button.text = "Resolve Victory"
	victory_button.pressed.connect(_on_victory_pressed)
	actions.add_child(victory_button)

	var defeat_button := Button.new()
	defeat_button.text = "Resolve Defeat"
	defeat_button.pressed.connect(_on_defeat_pressed)
	actions.add_child(defeat_button)

	var return_button := Button.new()
	return_button.text = "World Map"
	return_button.pressed.connect(_on_return_pressed)
	actions.add_child(return_button)

	event_log_label = RichTextLabel.new()
	event_log_label.custom_minimum_size = Vector2(0, 80)
	event_log_label.fit_content = false
	stack.add_child(event_log_label)


func _build_terrain_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var terrain: String = str(cell.terrain) if cell != null else "plains"

	for z_index in range(TERRAIN_STEPS + 1):
		for x_index in range(TERRAIN_STEPS + 1):
			var x: float = lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, float(x_index) / float(TERRAIN_STEPS))
			var z: float = lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, float(z_index) / float(TERRAIN_STEPS))
			var y: float = _terrain_height_at(x, z, terrain)
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3.UP)
			colors.append(_terrain_color_at(x, z, terrain))

	for z_index in range(TERRAIN_STEPS):
		for x_index in range(TERRAIN_STEPS):
			var row := TERRAIN_STEPS + 1
			var a := z_index * row + x_index
			var b := a + 1
			var c := a + row
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	return mesh


func _build_ground_grid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var minor_color := Color(0.94, 0.95, 0.86, 0.16)
	var major_color := Color(0.95, 0.94, 0.78, 0.34)
	var step := 10.0
	var line_count := int(MAP_SIZE / step)
	var half_size := MAP_SIZE * 0.5

	for index in range(line_count + 1):
		var offset: float = -half_size + float(index) * step
		var color := major_color if index % 4 == 0 else minor_color
		vertices.append(Vector3(offset, 0.08, -half_size))
		vertices.append(Vector3(offset, 0.08, half_size))
		vertices.append(Vector3(-half_size, 0.08, offset))
		vertices.append(Vector3(half_size, 0.08, offset))
		for color_index in range(4):
			colors.append(color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	return mesh


func _spawn_cell_props() -> void:
	if cell == null:
		return

	var terrain: String = str(cell.terrain)
	var rng := RandomNumberGenerator.new()
	var cell_seed: int = int(Game.world_state.seed) + int(cell.x) * 928371 + int(cell.y) * 364479
	rng.seed = cell_seed

	for index in range(_prop_count_for_terrain(terrain)):
		var position := _random_point(rng, PROP_EXTENT)
		position.y = _terrain_height_at(position.x, position.z, terrain)
		match terrain:
			"forest":
				_spawn_tree(position, rng)
			"hills":
				_spawn_rock(position, rng)
			"water":
				_spawn_reed_or_rock(position, rng)
			_:
				if index % 3 == 0:
					_spawn_rock(position, rng)
				else:
					_spawn_grass_marker(position, rng)


func _spawn_tree(position: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.08
	trunk_mesh.bottom_radius = 0.11
	trunk_mesh.height = rng.randf_range(1.8, 3.1)
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color(0.35, 0.21, 0.11))
	trunk.position = position + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
	terrain_root.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = rng.randf_range(1.2, 2.0)
	crown_mesh.height = crown_mesh.radius * 1.7
	crown.mesh = crown_mesh
	crown.material_override = _material(Color(0.05, 0.31, 0.12))
	crown.position = position + Vector3(0.0, trunk_mesh.height + crown_mesh.radius * 0.7, 0.0)
	terrain_root.add_child(crown)


func _spawn_rock(position: Vector3, rng: RandomNumberGenerator) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = rng.randf_range(0.9, 2.8)
	rock_mesh.height = rock_mesh.radius * rng.randf_range(0.8, 1.25)
	rock.mesh = rock_mesh
	rock.scale = Vector3(rng.randf_range(1.0, 1.6), rng.randf_range(0.45, 0.85), rng.randf_range(0.8, 1.4))
	rock.material_override = _material(Color(0.35, 0.34, 0.31))
	rock.position = position + Vector3(0.0, rock_mesh.height * 0.2, 0.0)
	terrain_root.add_child(rock)


func _spawn_reed_or_rock(position: Vector3, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.45:
		_spawn_rock(position, rng)
		return

	var reed := MeshInstance3D.new()
	var reed_mesh := CylinderMesh.new()
	reed_mesh.top_radius = 0.025
	reed_mesh.bottom_radius = 0.035
	reed_mesh.height = rng.randf_range(1.0, 2.2)
	reed_mesh.radial_segments = 5
	reed.mesh = reed_mesh
	reed.material_override = _material(Color(0.52, 0.58, 0.22))
	reed.position = position + Vector3(0.0, reed_mesh.height * 0.5, 0.0)
	terrain_root.add_child(reed)


func _spawn_grass_marker(position: Vector3, rng: RandomNumberGenerator) -> void:
	var grass := MeshInstance3D.new()
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0.04
	grass_mesh.bottom_radius = 0.06
	grass_mesh.height = rng.randf_range(0.45, 0.9)
	grass_mesh.radial_segments = 5
	grass.mesh = grass_mesh
	grass.material_override = _material(Color(0.28, 0.52, 0.18))
	grass.position = position + Vector3(0.0, grass_mesh.height * 0.5, 0.0)
	terrain_root.add_child(grass)


func _spawn_town_center() -> void:
	var center := MeshInstance3D.new()
	center.name = "TownCenterPlaceholder"
	var box := BoxMesh.new()
	box.size = Vector3(7.5, 4.2, 7.5)
	center.mesh = box
	center.material_override = _material(Color(0.55, 0.36, 0.18))
	center.position = Vector3(-32.0, _terrain_height_at(-32.0, -24.0, _cell_terrain()) + 2.1, -24.0)
	terrain_root.add_child(center)


func _spawn_units() -> void:
	var unit_material := _material(Color(0.12, 0.45, 0.9))
	for index in range(8):
		var unit := MeshInstance3D.new()
		unit.name = "PlayerUnit%d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.75
		mesh.bottom_radius = 0.82
		mesh.height = 1.8
		mesh.radial_segments = 8
		unit.mesh = mesh
		unit.material_override = unit_material
		var x := -16.0 + float(index % 4) * 3.2
		var z := -13.0 + float(index / 4) * 3.2
		unit.position = Vector3(x, _terrain_height_at(x, z, _cell_terrain()) + mesh.height * 0.5, z)
		terrain_root.add_child(unit)


func _spawn_enemy_marker() -> void:
	if cell == null or cell.owner_id == "player":
		return

	var enemy := MeshInstance3D.new()
	enemy.name = "EnemyCampPlaceholder"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(8.5, 3.2, 8.5)
	enemy.mesh = mesh
	enemy.material_override = _material(Color(0.72, 0.16, 0.12))
	enemy.position = Vector3(54.0, _terrain_height_at(54.0, 46.0, _cell_terrain()) + 1.6, 46.0)
	terrain_root.add_child(enemy)


func _terrain_height_at(x: float, z: float, terrain: String) -> float:
	match terrain:
		"hills":
			return sin(x * 0.06) * 3.6 + cos(z * 0.055) * 2.8
		"water":
			return -0.45 + sin(x * 0.12 + z * 0.08) * 0.12
		"forest":
			return sin(x * 0.035) * 0.9 + cos(z * 0.045) * 0.75
		_:
			return sin(x * 0.028 + z * 0.022) * 0.45


func _terrain_color_at(x: float, z: float, terrain: String) -> Color:
	match terrain:
		"hills":
			var slope: float = clamp((_terrain_height_at(x, z, terrain) + 0.5), 0.0, 1.0)
			return Color(0.30, 0.42, 0.22).lerp(Color(0.55, 0.52, 0.42), slope)
		"water":
			var shore: float = clamp(abs(x) / (MAP_SIZE * 0.5), 0.0, 1.0)
			return Color(0.06, 0.24, 0.56).lerp(Color(0.30, 0.50, 0.42), shore * 0.25)
		"forest":
			return Color(0.07, 0.34, 0.14).lerp(Color(0.12, 0.45, 0.18), sin(x + z) * 0.08 + 0.12)
		_:
			return Color(0.33, 0.55, 0.22).lerp(Color(0.44, 0.62, 0.29), sin(x * 0.7) * 0.08 + 0.14)


func _prop_count_for_terrain(terrain: String) -> int:
	match terrain:
		"forest":
			return 140
		"hills":
			return 80
		"water":
			return 44
		_:
			return 54


func _random_point(rng: RandomNumberGenerator, extent: float) -> Vector3:
	return Vector3(rng.randf_range(-extent, extent), 0.0, rng.randf_range(-extent, extent))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _cell_terrain() -> String:
	if cell == null:
		return "plains"
	return str(cell.terrain)


func _refresh_overlay() -> void:
	if cell == null:
		summary_label.text = "No selected cell data."
	else:
		summary_label.text = _join_lines([
			"Cell: %s" % cell.id,
			"Terrain: %s" % str(cell.terrain).capitalize(),
			"Owner: %s" % cell.owner_id,
			"Threat: %d" % int(cell.threat_level),
			"Plane: %dm x %dm" % [int(MAP_SIZE), int(MAP_SIZE)],
			"",
			"WASD/arrow keys pan. Mouse wheel zooms.",
		])
	event_log_label.text = _join_lines(Game.get_recent_events(8))


func _on_victory_pressed() -> void:
	Game.finish_battle(true)


func _on_defeat_pressed() -> void:
	Game.finish_battle(false)


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/world_map.tscn")


func _join_lines(lines: Array) -> String:
	var output := ""
	for line in lines:
		if not output.is_empty():
			output += "\n"
		output += str(line)
	return output


func _update_rts_camera(delta: float) -> void:
	if camera == null:
		return

	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if direction == Vector3.ZERO:
		return

	direction = direction.normalized()
	var speed := CAMERA_PAN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= CAMERA_FAST_MULTIPLIER

	var next_position := camera.position + direction * speed * delta
	var limit := MAP_SIZE * 0.5
	next_position.x = clamp(next_position.x, -limit, limit)
	next_position.z = clamp(next_position.z, -limit + CAMERA_MIN_Z, limit + CAMERA_MAX_Z * 0.25)
	camera.position = next_position


func _zoom_camera(amount: float) -> void:
	var next_y: float = clamp(camera.position.y + amount, CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT)
	var zoom_ratio: float = inverse_lerp(CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT, next_y)
	var next_z: float = lerpf(CAMERA_MIN_Z, CAMERA_MAX_Z, zoom_ratio)
	camera.position.y = next_y
	camera.position.z = clamp(camera.position.z, -MAP_SIZE * 0.5 + next_z, MAP_SIZE * 0.5 + next_z * 0.25)
	camera.rotation_degrees.x = lerpf(-58.0, -46.0, zoom_ratio)
