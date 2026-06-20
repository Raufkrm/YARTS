extends Node3D

const MAP_SIZE := 4000.0
const GRID_STEP := 100.0
const TERRAIN_STEPS := 192
const RTS_CACHE_VERSION := 16
const PROP_SAMPLE_COUNT := 220
const WATER_PLANE_STEPS := 96
const UNIT_HEIGHT := 1.65
const UNIT_BODY_HEIGHT := 1.35
const UNIT_HEAD_RADIUS := 0.15
const TERRAIN_HEIGHT_SCALE := 38.0
const TERRAIN_SMOOTH_PASSES := 2
const TERRAIN_SMOOTH_BLEND := 0.55
const TERRAIN_BASE_HEIGHT := -1.5
const WATER_SURFACE_HEIGHT := 0.08
const RIVER_SURFACE_OFFSET := 0.0
const RIVER_RENDER_EDGE := 0.22
const RIVER_RENDER_FULL := 0.68
const GRID_SURFACE_OFFSET := 0.16
const CAMERA_PAN_SPEED := 420.0
const CAMERA_FAST_MULTIPLIER := 2.2
const CAMERA_ZOOM_STEP := 70.0
const CAMERA_MIN_HEIGHT := 90.0
const CAMERA_MAX_HEIGHT := 1200.0
const CAMERA_MIN_Z := 120.0
const CAMERA_MAX_Z := 1450.0
const FREE_ROAM_SPEED := 95.0
const FREE_ROAM_FAST_MULTIPLIER := 3.0
const FREE_ROAM_MOUSE_SENSITIVITY := 0.0025
const FREE_ROAM_MIN_PITCH := -1.5
const FREE_ROAM_MAX_PITCH := 1.5
const RTS_MOUSE_YAW_SPEED := 0.006

var cell
var camera: Camera3D
var sun_light: DirectionalLight3D
var night_fill_light: DirectionalLight3D
var battle_environment: Environment
var sky_material: ShaderMaterial
var summary_label: Label
var event_log_label: RichTextLabel
var loading_layer: CanvasLayer
var loading_label: Label
var loading_bar: ProgressBar
var terrain_root: Node3D
var free_roam_enabled := false
var free_roam_yaw := 0.0
var free_roam_pitch := 0.0
var displayed_sun_label := ""
var rts_yaw_dragging := false
var grid_faint_enabled := true
var smoothed_river_map := PackedFloat32Array()
var smoothed_river_map_size := 0


func _ready() -> void:
	cell = Game.get_current_cell()
	_build_scene()
	_build_overlay()
	_refresh_overlay()
	_build_loading_overlay()
	call_deferred("_load_rts_cell")


func _process(delta: float) -> void:
	Game.advance_battle_sun(delta)
	_sync_sun_lighting()
	if free_roam_enabled:
		_update_free_roam_camera(delta)
	else:
		_update_rts_camera(delta)


func _input(event: InputEvent) -> void:
	if camera == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_toggle_grid_faint()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_P:
			_toggle_free_roam()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and free_roam_enabled:
			_set_free_roam_enabled(false)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and free_roam_enabled:
		free_roam_yaw -= event.relative.x * FREE_ROAM_MOUSE_SENSITIVITY
		free_roam_pitch = clamp(free_roam_pitch - event.relative.y * FREE_ROAM_MOUSE_SENSITIVITY, FREE_ROAM_MIN_PITCH, FREE_ROAM_MAX_PITCH)
		camera.rotation = Vector3(free_roam_pitch, free_roam_yaw, 0.0)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		rts_yaw_dragging = event.pressed and not free_roam_enabled
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and rts_yaw_dragging and not free_roam_enabled:
		camera.rotation.y -= event.relative.x * RTS_MOUSE_YAW_SPEED
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return

	if event is InputEventMouseButton and event.pressed:
		if free_roam_enabled:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(CAMERA_ZOOM_STEP)


func _exit_tree() -> void:
	if free_roam_enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	rts_yaw_dragging = false


func _build_scene() -> void:
	terrain_root = Node3D.new()
	terrain_root.name = "DetailedRTSCell"
	add_child(terrain_root)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "BattleSun"
	sun_light.shadow_enabled = true
	add_child(sun_light)

	night_fill_light = DirectionalLight3D.new()
	night_fill_light.name = "NightTerrainFill"
	night_fill_light.shadow_enabled = false
	night_fill_light.light_color = Color(0.34, 0.42, 0.62)
	add_child(night_fill_light)
	night_fill_light.look_at_from_position(Vector3(-38.0, 100.0, -52.0), Vector3.ZERO, Vector3.UP)

	var world_environment := WorldEnvironment.new()
	battle_environment = Environment.new()
	battle_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky_sorta_cell.gdshader")
	sky.sky_material = sky_material
	battle_environment.sky = sky
	battle_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment = battle_environment
	add_child(world_environment)

	_sync_sun_lighting()

	camera = Camera3D.new()
	camera.name = "RTSCamera"
	camera.position = Vector3(0.0, 420.0, 420.0)
	camera.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	camera.fov = 50.0
	camera.current = true
	add_child(camera)


func _build_terrain_grid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var minor_alpha := 0.025 if grid_faint_enabled else 0.14
	var major_alpha := 0.055 if grid_faint_enabled else 0.30
	var minor_color := Color(0.94, 0.95, 0.86, minor_alpha)
	var major_color := Color(1.0, 0.96, 0.70, major_alpha)
	var line_count := int(MAP_SIZE / GRID_STEP)
	var half_size := MAP_SIZE * 0.5
	var segments_per_line := TERRAIN_STEPS

	for index in range(line_count + 1):
		var offset: float = -half_size + float(index) * GRID_STEP
		var color := major_color if index % 4 == 0 else minor_color
		for segment_index in range(segments_per_line):
			var t0: float = float(segment_index) / float(segments_per_line)
			var t1: float = float(segment_index + 1) / float(segments_per_line)
			var z0: float = lerpf(-half_size, half_size, t0)
			var z1: float = lerpf(-half_size, half_size, t1)
			var x0: float = lerpf(-half_size, half_size, t0)
			var x1: float = lerpf(-half_size, half_size, t1)
			vertices.append(_grid_vertex_at(offset, z0))
			vertices.append(_grid_vertex_at(offset, z1))
			vertices.append(_grid_vertex_at(x0, offset))
			vertices.append(_grid_vertex_at(x1, offset))
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


func _toggle_grid_faint() -> void:
	grid_faint_enabled = not grid_faint_enabled
	_refresh_grid_mesh()


func _refresh_grid_mesh() -> void:
	if terrain_root == null:
		return

	var grid := terrain_root.get_node_or_null("ScaleGrid10m") as MeshInstance3D
	if grid == null:
		return
	grid.mesh = _build_terrain_grid_mesh()


func _grid_vertex_at(x: float, z: float) -> Vector3:
	var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
	var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
	var sample := _sample_cell_uv(u, v)
	var surface_height := _height_from_sample(sample)
	if str(sample["terrain"]) == "water":
		surface_height = max(surface_height, WATER_SURFACE_HEIGHT)
	elif float(sample.get("river", 0.0)) > 0.42:
		surface_height = max(surface_height, WATER_SURFACE_HEIGHT)
	return Vector3(x, surface_height + GRID_SURFACE_OFFSET, z)


func _spawn_scale_unit(parent: Node3D, base_height: float = 0.0) -> void:
	var unit := Node3D.new()
	unit.name = "ScaleUnit_1m65"
	unit.position = Vector3(0.0, base_height, 0.0)
	parent.add_child(unit)

	var body := MeshInstance3D.new()
	body.name = "Body_1m35"
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.22
	body_mesh.bottom_radius = 0.25
	body_mesh.height = UNIT_BODY_HEIGHT
	body_mesh.radial_segments = 12
	body.mesh = body_mesh
	body.material_override = _material(Color(0.16, 0.36, 0.82))
	body.position = Vector3(0.0, UNIT_BODY_HEIGHT * 0.5, 0.0)
	unit.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head_0m30"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = UNIT_HEAD_RADIUS
	head_mesh.height = UNIT_HEAD_RADIUS * 2.0
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	head.mesh = head_mesh
	head.material_override = _material(Color(0.86, 0.70, 0.54))
	head.position = Vector3(0.0, UNIT_BODY_HEIGHT + UNIT_HEAD_RADIUS, 0.0)
	unit.add_child(head)

	var height_marker := MeshInstance3D.new()
	height_marker.name = "HeightMarker_1m65"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.04, UNIT_HEIGHT, 0.04)
	height_marker.mesh = marker_mesh
	height_marker.material_override = _material(Color(1.0, 0.92, 0.28))
	height_marker.position = Vector3(0.55, UNIT_HEIGHT * 0.5, 0.0)
	unit.add_child(height_marker)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BattleOverlay"
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(380, 230)
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
	event_log_label.custom_minimum_size = Vector2(0, 70)
	event_log_label.fit_content = false
	stack.add_child(event_log_label)


func _build_loading_overlay() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.name = "RTSLoadingOverlay"
	add_child(loading_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.025, 0.035, 0.86)
	loading_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -70
	panel.offset_right = 260
	panel.offset_bottom = 70
	loading_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	margin.add_child(stack)

	loading_label = Label.new()
	loading_label.text = "Preparing RTS cell..."
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(loading_label)

	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0.0
	loading_bar.max_value = 100.0
	loading_bar.value = 0.0
	stack.add_child(loading_bar)


func _set_loading(stage: String, progress: float) -> void:
	if loading_label != null:
		loading_label.text = stage
	if loading_bar != null:
		loading_bar.value = clamp(progress, 0.0, 1.0) * 100.0


func _hide_loading_overlay() -> void:
	if loading_layer != null:
		loading_layer.queue_free()
		loading_layer = null
		loading_label = null
		loading_bar = null


func _load_rts_cell() -> void:
	_set_loading("Checking cached RTS terrain...", 0.03)
	await get_tree().process_frame

	var cache_key := _rts_cell_cache_key()
	var cached_cell = Game.get_rts_cell_cache(cache_key)
	if cached_cell is Dictionary:
		_set_loading("Loading cached terrain meshes...", 0.92)
		await get_tree().process_frame
		_apply_rts_cell_data(cached_cell)
		_hide_loading_overlay()
		_refresh_overlay()
		return

	var generated_cell: Dictionary = await _generate_rts_cell_data()
	Game.set_rts_cell_cache(cache_key, generated_cell)
	_apply_rts_cell_data(generated_cell)
	_hide_loading_overlay()
	_refresh_overlay()


func _rts_cell_cache_key() -> String:
	var cell_id := "none"
	if cell != null:
		cell_id = str(cell.id)
	var seed := 0
	if Game.world_state != null:
		seed = int(Game.world_state.seed)
	return "rts_cell:v%d:%d:%s:%d:%d" % [RTS_CACHE_VERSION, seed, cell_id, int(MAP_SIZE), TERRAIN_STEPS]


func _generate_rts_cell_data() -> Dictionary:
	_set_loading("Sampling elevation, moisture, rivers, and biomes...", 0.08)
	await get_tree().process_frame
	_build_smoothed_river_map()

	var terrain_vertices := PackedVector3Array()
	var terrain_normals := PackedVector3Array()
	var terrain_colors := PackedColorArray()
	var terrain_uvs := PackedVector2Array()
	var terrain_indices := PackedInt32Array()
	var terrain_heights := PackedFloat32Array()
	var row_length := TERRAIN_STEPS + 1
	var half_size := MAP_SIZE * 0.5

	for z_index in range(TERRAIN_STEPS + 1):
		var v: float = float(z_index) / float(TERRAIN_STEPS)
		for x_index in range(TERRAIN_STEPS + 1):
			var u: float = float(x_index) / float(TERRAIN_STEPS)
			var x: float = lerpf(-half_size, half_size, u)
			var z: float = lerpf(-half_size, half_size, v)
			var sample := _sample_cell_uv(u, v)
			var height := _height_from_sample(sample)
			terrain_vertices.append(Vector3(x, height, z))
			terrain_heights.append(height)
			terrain_colors.append(_terrain_color_from_sample(sample))
			terrain_uvs.append(Vector2(u, v))

		if z_index % 8 == 0:
			_set_loading("Sampling terrain rows %d/%d..." % [z_index, TERRAIN_STEPS], lerpf(0.08, 0.48, float(z_index) / float(TERRAIN_STEPS)))
			await get_tree().process_frame

	_set_loading("Building terrain mesh...", 0.54)
	await get_tree().process_frame
	terrain_heights = _smooth_terrain_heights(terrain_heights, row_length, TERRAIN_SMOOTH_PASSES)
	for vertex_index in range(terrain_vertices.size()):
		var vertex := terrain_vertices[vertex_index]
		vertex.y = terrain_heights[vertex_index]
		terrain_vertices[vertex_index] = vertex

	var vertex_spacing := MAP_SIZE / float(TERRAIN_STEPS)
	for z_index in range(TERRAIN_STEPS + 1):
		for x_index in range(TERRAIN_STEPS + 1):
			var left_x: int = max(x_index - 1, 0)
			var right_x: int = min(x_index + 1, TERRAIN_STEPS)
			var down_z: int = max(z_index - 1, 0)
			var up_z: int = min(z_index + 1, TERRAIN_STEPS)
			var left_height: float = terrain_heights[z_index * row_length + left_x]
			var right_height: float = terrain_heights[z_index * row_length + right_x]
			var down_height: float = terrain_heights[down_z * row_length + x_index]
			var up_height: float = terrain_heights[up_z * row_length + x_index]
			var normal := Vector3(left_height - right_height, vertex_spacing * 2.0, down_height - up_height).normalized()
			terrain_normals.append(normal)

	for z_index in range(TERRAIN_STEPS):
		for x_index in range(TERRAIN_STEPS):
			var base_index := z_index * row_length + x_index
			terrain_indices.append(base_index)
			terrain_indices.append(base_index + row_length)
			terrain_indices.append(base_index + 1)
			terrain_indices.append(base_index + 1)
			terrain_indices.append(base_index + row_length)
			terrain_indices.append(base_index + row_length + 1)

	_set_loading("Building shared water plane...", 0.68)
	await get_tree().process_frame

	_set_loading("Preparing cached RTS meshes...", 0.86)
	await get_tree().process_frame
	var terrain_mesh := _mesh_from_arrays(terrain_vertices, terrain_normals, terrain_colors, terrain_uvs, terrain_indices)
	var water_mesh := _build_water_plane_mesh()
	var grid_mesh := _build_terrain_grid_mesh()
	var prop_data := _generate_prop_data()
	var center_height := _height_from_sample(_sample_cell_uv(0.5, 0.5))

	return {
		"terrain_mesh": terrain_mesh,
		"water_mesh": water_mesh,
		"grid_mesh": grid_mesh,
		"props": prop_data,
		"center_height": center_height,
	}


func _apply_rts_cell_data(data: Dictionary) -> void:
	_clear_generated_nodes()

	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "DetailedTerrain"
	terrain_mesh.mesh = data["terrain_mesh"]
	terrain_mesh.material_override = _terrain_material()
	terrain_root.add_child(terrain_mesh)

	var water_mesh := data["water_mesh"] as ArrayMesh
	if water_mesh != null and water_mesh.get_surface_count() > 0:
		var water := MeshInstance3D.new()
		water.name = "StillOceanWater"
		water.mesh = water_mesh
		water.material_override = _water_material(false)
		terrain_root.add_child(water)

	var grid_mesh := data.get("grid_mesh") as ArrayMesh
	if grid_mesh != null and grid_mesh.get_surface_count() > 0:
		var grid := MeshInstance3D.new()
		grid.name = "ScaleGrid10m"
		grid.mesh = grid_mesh
		terrain_root.add_child(grid)

	_spawn_cached_props(data.get("props", []))
	_spawn_scale_unit(terrain_root, float(data.get("center_height", 0.0)))


func _clear_generated_nodes() -> void:
	if terrain_root == null:
		return

	for child in terrain_root.get_children():
		child.queue_free()


func _mesh_from_arrays(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _smooth_terrain_heights(heights: PackedFloat32Array, row_length: int, passes: int) -> PackedFloat32Array:
	var smoothed := heights
	if passes <= 0:
		return smoothed

	for pass_index in range(passes):
		var next_heights := smoothed.duplicate()
		for z_index in range(1, row_length - 1):
			for x_index in range(1, row_length - 1):
				var index := z_index * row_length + x_index
				var average := (
					smoothed[index]
					+ smoothed[index - 1]
					+ smoothed[index + 1]
					+ smoothed[index - row_length]
					+ smoothed[index + row_length]
					+ smoothed[index - row_length - 1] * 0.5
					+ smoothed[index - row_length + 1] * 0.5
					+ smoothed[index + row_length - 1] * 0.5
					+ smoothed[index + row_length + 1] * 0.5
				) / 7.0
				next_heights[index] = lerpf(smoothed[index], average, TERRAIN_SMOOTH_BLEND)
		smoothed = next_heights
	return smoothed


func _build_water_plane_mesh() -> ArrayMesh:
	var half_size := MAP_SIZE * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_length := WATER_PLANE_STEPS + 1

	for z_index in range(WATER_PLANE_STEPS + 1):
		var v: float = float(z_index) / float(WATER_PLANE_STEPS)
		for x_index in range(WATER_PLANE_STEPS + 1):
			var u: float = float(x_index) / float(WATER_PLANE_STEPS)
			vertices.append(Vector3(lerpf(-half_size, half_size, u), WATER_SURFACE_HEIGHT, lerpf(-half_size, half_size, v)))
			normals.append(Vector3.UP)
			uvs.append(Vector2(u, v))

	for z_index in range(WATER_PLANE_STEPS):
		for x_index in range(WATER_PLANE_STEPS):
			var base_index: int = z_index * row_length + x_index
			indices.append(base_index)
			indices.append(base_index + row_length)
			indices.append(base_index + 1)
			indices.append(base_index + 1)
			indices.append(base_index + row_length)
			indices.append(base_index + row_length + 1)
	return _water_mesh_from_arrays(vertices, uvs, indices, normals)


func _water_mesh_from_arrays(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, normals: PackedVector3Array = PackedVector3Array(), colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh

	if normals.is_empty():
		for index in range(vertices.size()):
			normals.append(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_river_surface_cell(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	terrain_vertices: PackedVector3Array,
	terrain_heights: PackedFloat32Array,
	river_values: PackedFloat32Array,
	water_values: PackedFloat32Array,
	row_length: int,
	x_index: int,
	z_index: int
) -> void:
	var i00: int = z_index * row_length + x_index
	var i10: int = i00 + 1
	var i01: int = i00 + row_length
	var i11: int = i01 + 1
	var alpha00: float = _river_render_alpha(river_values[i00], water_values[i00])
	var alpha10: float = _river_render_alpha(river_values[i10], water_values[i10])
	var alpha01: float = _river_render_alpha(river_values[i01], water_values[i01])
	var alpha11: float = _river_render_alpha(river_values[i11], water_values[i11])
	if max(max(alpha00, alpha10), max(alpha01, alpha11)) <= 0.025:
		return

	var base_index: int = vertices.size()
	_add_river_surface_vertex(vertices, uvs, colors, terrain_vertices[i00], terrain_heights[i00], alpha00, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index, z_index))
	_add_river_surface_vertex(vertices, uvs, colors, terrain_vertices[i10], terrain_heights[i10], alpha10, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index + 1, z_index))
	_add_river_surface_vertex(vertices, uvs, colors, terrain_vertices[i01], terrain_heights[i01], alpha01, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index, z_index + 1))
	_add_river_surface_vertex(vertices, uvs, colors, terrain_vertices[i11], terrain_heights[i11], alpha11, _river_flow_vector_at_vertex(terrain_heights, river_values, water_values, row_length, x_index + 1, z_index + 1))
	indices.append(base_index)
	indices.append(base_index + 2)
	indices.append(base_index + 1)
	indices.append(base_index + 1)
	indices.append(base_index + 2)
	indices.append(base_index + 3)


func _add_river_surface_vertex(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, terrain_vertex: Vector3, terrain_height: float, alpha: float, flow_vector: Vector2) -> void:
	var edge_lift: float = lerpf(0.10, 0.0, clamp(alpha, 0.0, 1.0))
	var y: float = max(terrain_height + RIVER_SURFACE_OFFSET + edge_lift, WATER_SURFACE_HEIGHT + 0.08)
	vertices.append(Vector3(terrain_vertex.x, y, terrain_vertex.z))
	uvs.append(Vector2(terrain_vertex.x, terrain_vertex.z) / MAP_SIZE)
	var flow := flow_vector.normalized()
	if flow.length_squared() <= 0.001:
		flow = Vector2(0.0, 1.0)
	colors.append(Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, 1.0, alpha))


func _river_flow_vector_at_vertex(terrain_heights: PackedFloat32Array, river_values: PackedFloat32Array, water_values: PackedFloat32Array, row_length: int, x_index: int, z_index: int) -> Vector2:
	var clamped_x: int = clamp(x_index, 0, TERRAIN_STEPS)
	var clamped_z: int = clamp(z_index, 0, TERRAIN_STEPS)
	var center_index: int = clamped_z * row_length + clamped_x
	var center_height: float = terrain_heights[center_index]
	var best := Vector2.ZERO
	var best_score := INF
	var search_radius := 5

	for z_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			if x_offset == 0 and z_offset == 0:
				continue
			var sample_x: int = clamp(clamped_x + x_offset, 0, TERRAIN_STEPS)
			var sample_z: int = clamp(clamped_z + z_offset, 0, TERRAIN_STEPS)
			var sample_index: int = sample_z * row_length + sample_x
			var candidate_river: float = river_values[sample_index]
			var candidate_water: float = water_values[sample_index]
			if candidate_river < RIVER_RENDER_EDGE and candidate_water < 0.5:
				continue
			var offset := Vector2(float(sample_x - clamped_x), float(sample_z - clamped_z))
			var distance: float = max(offset.length(), 1.0)
			var height_drop: float = center_height - terrain_heights[sample_index]
			var score: float = -height_drop - candidate_water * 7.0 - candidate_river * 0.85 + distance * 0.12
			if score < best_score:
				best_score = score
				best = offset / distance

	if best.length_squared() > 0.001:
		return best

	var left_x: int = max(clamped_x - 1, 0)
	var right_x: int = min(clamped_x + 1, TERRAIN_STEPS)
	var down_z: int = max(clamped_z - 1, 0)
	var up_z: int = min(clamped_z + 1, TERRAIN_STEPS)
	var left_height: float = terrain_heights[clamped_z * row_length + left_x]
	var right_height: float = terrain_heights[clamped_z * row_length + right_x]
	var down_height: float = terrain_heights[down_z * row_length + clamped_x]
	var up_height: float = terrain_heights[up_z * row_length + clamped_x]
	return Vector2(left_height - right_height, down_height - up_height).normalized()


func _river_render_alpha(river: float, water: float) -> float:
	var alpha: float = smoothstep(RIVER_RENDER_EDGE, RIVER_RENDER_FULL, river)
	alpha *= 1.0 - smoothstep(0.0, 0.85, water)
	return clamp(alpha, 0.0, 1.0)


func _add_water_quad(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var base_index := vertices.size()
	vertices.append(Vector3(x0, y, z0))
	vertices.append(Vector3(x1, y, z0))
	vertices.append(Vector3(x0, y, z1))
	vertices.append(Vector3(x1, y, z1))
	uvs.append(Vector2(x0, z0) / MAP_SIZE)
	uvs.append(Vector2(x1, z0) / MAP_SIZE)
	uvs.append(Vector2(x0, z1) / MAP_SIZE)
	uvs.append(Vector2(x1, z1) / MAP_SIZE)
	indices.append(base_index)
	indices.append(base_index + 2)
	indices.append(base_index + 1)
	indices.append(base_index + 1)
	indices.append(base_index + 2)
	indices.append(base_index + 3)


func _sample_cell_uv(u: float, v: float) -> Dictionary:
	var sample: Dictionary = _sample_cell_uv_raw(u, v)
	sample["river"] = _smooth_river_at_uv(u, v)
	return sample


func _sample_cell_uv_raw(u: float, v: float) -> Dictionary:
	if Game.world_state == null or cell == null:
		return {
			"terrain": "plains",
			"elevation": WorldState.SEA_LEVEL + 0.10,
			"moisture": 0.45,
			"temperature": 0.55,
			"ridge": 0.0,
			"raw_noise": 0.5,
			"river": 0.0,
		}
	return Game.world_state.sample_cell(cell, clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0))


func _smooth_river_at_uv(u: float, v: float) -> float:
	if smoothed_river_map.is_empty() or smoothed_river_map_size <= 1:
		_build_smoothed_river_map()
	if smoothed_river_map.is_empty() or smoothed_river_map_size <= 1:
		return float(_sample_cell_uv_raw(u, v).get("river", 0.0))

	var map_max := smoothed_river_map_size - 1
	var map_x: float = clamp(u, 0.0, 1.0) * float(map_max)
	var map_y: float = clamp(v, 0.0, 1.0) * float(map_max)
	var x0: int = int(floor(map_x))
	var y0: int = int(floor(map_y))
	var x1: int = min(x0 + 1, map_max)
	var y1: int = min(y0 + 1, map_max)
	var tx: float = map_x - float(x0)
	var ty: float = map_y - float(y0)
	var a: float = smoothed_river_map[y0 * smoothed_river_map_size + x0]
	var b: float = smoothed_river_map[y0 * smoothed_river_map_size + x1]
	var c: float = smoothed_river_map[y1 * smoothed_river_map_size + x0]
	var d: float = smoothed_river_map[y1 * smoothed_river_map_size + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _build_smoothed_river_map() -> void:
	smoothed_river_map_size = TERRAIN_STEPS + 1
	var total_size := smoothed_river_map_size * smoothed_river_map_size
	var raw := PackedFloat32Array()
	raw.resize(total_size)
	smoothed_river_map = PackedFloat32Array()
	smoothed_river_map.resize(total_size)

	for y_index in range(smoothed_river_map_size):
		var v: float = float(y_index) / float(smoothed_river_map_size - 1)
		for x_index in range(smoothed_river_map_size):
			var u: float = float(x_index) / float(smoothed_river_map_size - 1)
			var sample: Dictionary = _sample_cell_uv_raw(u, v)
			raw[y_index * smoothed_river_map_size + x_index] = float(sample.get("river", 0.0))

	var radius := 4
	for y_index in range(smoothed_river_map_size):
		for x_index in range(smoothed_river_map_size):
			var weighted_sum := 0.0
			var total_weight := 0.0
			var dilated := 0.0
			for y_offset in range(-radius, radius + 1):
				for x_offset in range(-radius, radius + 1):
					var offset := Vector2(float(x_offset), float(y_offset))
					var distance: float = offset.length()
					if distance > float(radius):
						continue
					var sx: int = clamp(x_index + x_offset, 0, smoothed_river_map_size - 1)
					var sy: int = clamp(y_index + y_offset, 0, smoothed_river_map_size - 1)
					var raw_river: float = raw[sy * smoothed_river_map_size + sx]
					var weight: float = 1.0 - smoothstep(0.0, float(radius), distance)
					weight = max(weight * weight, 0.018)
					weighted_sum += raw_river * weight
					total_weight += weight
					var rounded_falloff: float = 1.0 - smoothstep(0.35, float(radius), distance)
					dilated = max(dilated, raw_river * rounded_falloff)

			var softened: float = weighted_sum / max(total_weight, 0.001)
			var connected: float = max(dilated, softened * 1.22)
			smoothed_river_map[y_index * smoothed_river_map_size + x_index] = clamp(smoothstep(0.04, 0.82, connected), 0.0, 1.0)


func _height_from_sample(sample: Dictionary) -> float:
	var terrain: String = str(sample["terrain"])
	var elevation: float = float(sample["elevation"])
	var ridge: float = float(sample.get("ridge", 0.0))
	var raw_noise: float = float(sample.get("raw_noise", elevation))
	var river: float = float(sample.get("river", 0.0))
	if terrain == "water":
		var depth: float = clamp((WorldState.SEA_LEVEL - elevation) * 12.0, 0.0, 5.5)
		return TERRAIN_BASE_HEIGHT - depth

	var land_height: float = max(0.0, elevation - WorldState.SEA_LEVEL) * TERRAIN_HEIGHT_SCALE
	land_height += (ridge - 0.45) * 4.0
	land_height += (raw_noise - 0.5) * 2.0
	if river > 0.06:
		var bank_cut: float = smoothstep(0.06, 0.22, river)
		var floor_cut: float = smoothstep(0.16, 0.52, river)
		var shoulder_height: float = WATER_SURFACE_HEIGHT + 0.14
		var bed_height: float = WATER_SURFACE_HEIGHT - 0.72 - smoothstep(0.56, 0.92, river) * 0.28
		var river_target_height: float = lerpf(shoulder_height, bed_height, floor_cut)
		land_height = lerpf(land_height, min(land_height, river_target_height), bank_cut)
	return land_height


func _terrain_color_from_sample(sample: Dictionary) -> Color:
	var terrain: String = str(sample["terrain"])
	var elevation: float = float(sample["elevation"])
	var moisture: float = float(sample["moisture"])
	var temperature: float = float(sample["temperature"])
	var river: float = float(sample.get("river", 0.0))
	var ridge: float = float(sample.get("ridge", 0.0))
	var land_height: float = clamp((elevation - WorldState.SEA_LEVEL) / max(1.0 - WorldState.SEA_LEVEL, 0.001), 0.0, 1.0)
	var color := Color(0.32, 0.56, 0.24)
	match terrain:
		"water":
			var depth: float = clamp((WorldState.SEA_LEVEL - elevation) * 7.0, 0.0, 1.0)
			var water_color: Color = Color(0.02, 0.12, 0.25).lerp(Color(0.08, 0.32, 0.48), 1.0 - depth)
			var sea_edge: float = smoothstep(WorldState.SEA_LEVEL - 0.080, WorldState.SEA_LEVEL - 0.006, elevation)
			var sea_floor: Color = Color(0.52, 0.47, 0.36).lerp(Color(0.36, 0.36, 0.34), clamp(ridge * 0.70, 0.0, 1.0))
			water_color = water_color.lerp(sea_floor, clamp(sea_edge * 0.44, 0.0, 0.44))
			return water_color
		"mountains":
			color = Color(0.32, 0.28, 0.22).lerp(Color(0.64, 0.62, 0.56), clamp(ridge * 0.75, 0.0, 0.75))
		"snow":
			color = Color(0.75, 0.84, 0.86).lerp(Color(0.96, 0.98, 0.94), clamp(1.0 - temperature, 0.0, 0.8))
		"desert":
			color = Color(0.62, 0.49, 0.25).lerp(Color(0.84, 0.70, 0.38), clamp(elevation, 0.0, 1.0) * 0.35)
		"tundra":
			color = Color(0.34, 0.43, 0.36).lerp(Color(0.55, 0.62, 0.56), moisture * 0.32)
		"hills":
			color = Color(0.29, 0.43, 0.22).lerp(Color(0.55, 0.51, 0.38), clamp(elevation, 0.0, 1.0) * 0.45)
		"forest":
			color = Color(0.06, 0.30, 0.12).lerp(Color(0.12, 0.45, 0.18), moisture * 0.28)
		_:
			var dry: float = clamp((1.0 - moisture) * 0.7 + temperature * 0.18, 0.0, 1.0)
			color = Color(0.32, 0.56, 0.24).lerp(Color(0.69, 0.60, 0.34), dry * 0.45)

	var coast_edge: float = 1.0 - smoothstep(WorldState.SEA_LEVEL + 0.004, WorldState.SEA_LEVEL + 0.060, elevation)
	if coast_edge > 0.0:
		var coast_sand := Color(0.73, 0.63, 0.40)
		var coast_rock := Color(0.42, 0.39, 0.33)
		var coast_rock_mix: float = clamp(ridge * 0.64 + land_height * 0.28, 0.0, 1.0)
		var coast_color: Color = coast_sand.lerp(coast_rock, coast_rock_mix)
		color = color.lerp(coast_color, clamp(coast_edge * 0.76, 0.0, 0.76))

	var river_bank: float = smoothstep(0.06, 0.34, river) * (1.0 - smoothstep(0.48, 0.74, river))
	if river_bank > 0.0:
		var river_sand := Color(0.73, 0.63, 0.40)
		var river_rock := Color(0.42, 0.39, 0.33)
		var river_rock_mix: float = clamp(ridge * 0.64 + land_height * 0.28, 0.0, 1.0)
		var river_shore_color: Color = river_sand.lerp(river_rock, river_rock_mix)
		color = color.lerp(river_shore_color, clamp(river_bank * 0.76, 0.0, 0.76))

	var river_bed: float = smoothstep(0.42, 0.72, river)
	if river_bed > 0.0:
		var bed_color: Color = Color(0.30, 0.31, 0.29).lerp(Color(0.47, 0.45, 0.39), clamp(1.0 - ridge, 0.0, 0.55))
		color = color.lerp(bed_color, clamp(river_bed * 0.84, 0.0, 0.84))

	return color


func _generate_prop_data() -> Array:
	var props: Array = []
	if Game.world_state == null or cell == null:
		return props

	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.world_state.seed) + int(cell.x) * 99173 + int(cell.y) * 57121
	for index in range(PROP_SAMPLE_COUNT):
		var x := rng.randf_range(-MAP_SIZE * 0.46, MAP_SIZE * 0.46)
		var z := rng.randf_range(-MAP_SIZE * 0.46, MAP_SIZE * 0.46)
		var u := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, x)
		var v := inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)
		var sample := _sample_cell_uv(u, v)
		var terrain: String = str(sample["terrain"])
		var river: float = float(sample.get("river", 0.0))
		if terrain == "water" or river > 0.18:
			continue
		var prop_type := "grass"
		if terrain == "forest" and rng.randf() < 0.86:
			prop_type = "tree"
		elif terrain in ["hills", "mountains", "snow", "desert"] and rng.randf() < 0.68:
			prop_type = "rock"
		props.append({
			"type": prop_type,
			"position": Vector3(x, _height_from_sample(sample), z),
			"scale": rng.randf_range(0.75, 1.45),
			"rotation": rng.randf_range(0.0, TAU),
		})
	return props


func _spawn_cached_props(props: Array) -> void:
	for prop in props:
		var prop_type := str(prop.get("type", "grass"))
		var position := Vector3.ZERO
		if prop.has("position") and prop["position"] is Vector3:
			position = prop["position"]
		var scale_value: float = float(prop.get("scale", 1.0))
		var rotation_y: float = float(prop.get("rotation", 0.0))
		match prop_type:
			"tree":
				_spawn_tree(position, scale_value, rotation_y)
			"rock":
				_spawn_rock(position, scale_value, rotation_y)
			_:
				_spawn_grass(position, scale_value, rotation_y)


func _spawn_tree(position: Vector3, scale_value: float, rotation_y: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.08 * scale_value
	trunk_mesh.bottom_radius = 0.12 * scale_value
	trunk_mesh.height = 2.1 * scale_value
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color(0.32, 0.20, 0.10))
	trunk.position = position + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
	trunk.rotation.y = rotation_y
	terrain_root.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.95 * scale_value
	crown_mesh.height = 1.45 * scale_value
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	crown.mesh = crown_mesh
	crown.material_override = _material(Color(0.05, 0.28, 0.11))
	crown.position = position + Vector3(0.0, trunk_mesh.height + crown_mesh.radius * 0.72, 0.0)
	terrain_root.add_child(crown)


func _spawn_rock(position: Vector3, scale_value: float, rotation_y: float) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.62 * scale_value
	rock_mesh.height = 0.74 * scale_value
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 5
	rock.mesh = rock_mesh
	rock.scale = Vector3(1.35, 0.55, 1.0)
	rock.rotation.y = rotation_y
	rock.material_override = _material(Color(0.34, 0.33, 0.30))
	rock.position = position + Vector3(0.0, rock_mesh.height * 0.25, 0.0)
	terrain_root.add_child(rock)


func _spawn_grass(position: Vector3, scale_value: float, rotation_y: float) -> void:
	var grass := MeshInstance3D.new()
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0.025 * scale_value
	grass_mesh.bottom_radius = 0.055 * scale_value
	grass_mesh.height = 0.55 * scale_value
	grass_mesh.radial_segments = 5
	grass.mesh = grass_mesh
	grass.rotation.y = rotation_y
	grass.material_override = _material(Color(0.22, 0.42, 0.14))
	grass.position = position + Vector3(0.0, grass_mesh.height * 0.5, 0.0)
	terrain_root.add_child(grass)


func _refresh_overlay() -> void:
	var cell_id := "none"
	if cell != null:
		cell_id = str(cell.id)

	displayed_sun_label = _sun_label(Game.get_battle_sun_amount())
	summary_label.text = _join_lines([
		"Cell: %s" % cell_id,
		"Flat plane: %dm x %dm" % [int(MAP_SIZE), int(MAP_SIZE)],
		"Center unit: %.2fm tall" % UNIT_HEIGHT,
		"Grid: %dm spacing" % int(GRID_STEP),
		"Sun: %s" % displayed_sun_label,
		"",
		"%s/arrows pan. Middle-drag yaws. P free roam. G toggles grid. Space/C rise/fall." % Game.movement_layout_label(),
	])
	event_log_label.text = _join_lines(Game.get_recent_events(8))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _sun_label(sun_amount: float) -> String:
	if sun_amount < -0.08:
		return "Night"
	if sun_amount < 0.12:
		return "Sunrise / Sunset"
	return "Day"


func _terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.0
	material.metallic_specular = 0.0
	material.roughness = 0.94
	return material


func _water_material(use_river_flow: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/lowpoly_water.gdshader")
	material.set_shader_parameter("use_river_flow", use_river_flow)
	material.set_shader_parameter("deep_water_color", Color(0.014, 0.080, 0.17) if use_river_flow else Color(0.018, 0.085, 0.18))
	material.set_shader_parameter("shallow_water_color", Color(0.07, 0.38, 0.58) if use_river_flow else Color(0.10, 0.44, 0.64))
	material.set_shader_parameter("foam_color", Color(0.72, 0.90, 0.94) if use_river_flow else Color(0.78, 0.94, 0.98))
	material.set_shader_parameter("wave_direction", Vector2(0.86, 0.18) if use_river_flow else Vector2(0.72, 0.22))
	material.set_shader_parameter("wave_direction_2", Vector2(-0.25, 0.94) if use_river_flow else Vector2(-0.30, 0.88))
	material.set_shader_parameter("wave_height", 0.12 if use_river_flow else 0.52)
	material.set_shader_parameter("wave_scale", 0.26 if use_river_flow else 0.13)
	material.set_shader_parameter("wave_speed", 2.35 if use_river_flow else 1.95)
	material.set_shader_parameter("edge_foam_distance", 0.65 if use_river_flow else 1.90)
	material.set_shader_parameter("depth_color_distance", 2.6 if use_river_flow else 8.0)
	material.set_shader_parameter("alpha", 0.78 if use_river_flow else 0.84)
	material.set_shader_parameter("facet_contrast", 0.44 if use_river_flow else 0.52)
	material.set_shader_parameter("day_factor", _rts_visibility_factor(Game.get_battle_sun_amount()))
	material.set_shader_parameter("sun_direction", Game.get_battle_sun_direction())
	return material


func _water_noise_texture(noise_seed: int, frequency: float, bump_strength: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.52

	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = bump_strength
	texture.noise = noise
	return texture


func _sync_sun_lighting() -> void:
	if sun_light == null or sky_material == null or battle_environment == null:
		return

	var sun_amount := Game.get_battle_sun_amount()
	var visibility_factor := _rts_visibility_factor(sun_amount)
	var direct_sun_factor := smoothstep(-0.04, 0.45, sun_amount)
	var night_fill_factor := 1.0 - smoothstep(-0.16, 0.24, sun_amount)
	var sun_direction := Game.get_battle_sun_direction()
	sun_light.light_energy = lerpf(0.0, 1.85, direct_sun_factor)
	sun_light.shadow_enabled = direct_sun_factor > 0.08
	sun_light.light_color = Color(1.0, 0.78, 0.54).lerp(Color(1.0, 0.96, 0.86), direct_sun_factor)
	sun_light.look_at_from_position(sun_direction * 100.0, Vector3.ZERO, Vector3.UP)
	if night_fill_light != null:
		night_fill_light.light_energy = lerpf(0.02, 0.24, night_fill_factor)
	sky_material.set_shader_parameter("sun_direction", sun_direction)
	sky_material.set_shader_parameter("sun_amount", sun_amount)
	sky_material.set_shader_parameter("day_factor", visibility_factor)
	battle_environment.ambient_light_color = Color(0.13, 0.16, 0.24).lerp(Color(0.62, 0.60, 0.52), visibility_factor)
	battle_environment.ambient_light_energy = lerpf(0.40, 0.72, visibility_factor)
	_sync_water_lighting(visibility_factor, sun_direction)
	var next_sun_label := _sun_label(sun_amount)
	if summary_label != null and next_sun_label != displayed_sun_label:
		_refresh_overlay()


func _rts_visibility_factor(sun_amount: float) -> float:
	return smoothstep(-0.18, 0.32, sun_amount)


func _sync_water_lighting(day_factor: float, sun_direction: Vector3) -> void:
	if terrain_root == null:
		return

	for child in terrain_root.get_children():
		if child is MeshInstance3D and child.name == "StillOceanWater":
			var shader_material := child.material_override as ShaderMaterial
			if shader_material != null:
				shader_material.set_shader_parameter("day_factor", day_factor)
				shader_material.set_shader_parameter("sun_direction", sun_direction)


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
	if Game.is_move_forward_pressed():
		direction.z -= 1.0
	if Game.is_move_back_pressed():
		direction.z += 1.0
	if Game.is_move_left_pressed():
		direction.x -= 1.0
	if Game.is_move_right_pressed():
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
	if free_roam_enabled:
		return

	var next_y: float = clamp(camera.position.y + amount, CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT)
	var zoom_ratio: float = inverse_lerp(CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT, next_y)
	var next_z: float = lerpf(CAMERA_MIN_Z, CAMERA_MAX_Z, zoom_ratio)
	camera.position.y = next_y
	camera.position.z = clamp(camera.position.z, -MAP_SIZE * 0.5 + next_z, MAP_SIZE * 0.5 + next_z * 0.25)
	camera.rotation_degrees.x = lerpf(-58.0, -46.0, zoom_ratio)


func _toggle_free_roam() -> void:
	_set_free_roam_enabled(not free_roam_enabled)


func _set_free_roam_enabled(enabled: bool) -> void:
	free_roam_enabled = enabled
	if camera == null:
		return

	if free_roam_enabled:
		free_roam_yaw = camera.rotation.y
		free_roam_pitch = camera.rotation.x
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_free_roam_camera(delta: float) -> void:
	if camera == null:
		return

	var direction := Vector3.ZERO
	if Game.is_move_forward_pressed():
		direction -= camera.global_transform.basis.z
	if Game.is_move_back_pressed():
		direction += camera.global_transform.basis.z
	if Game.is_move_left_pressed():
		direction -= camera.global_transform.basis.x
	if Game.is_move_right_pressed():
		direction += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_C):
		direction -= Vector3.UP

	if direction == Vector3.ZERO:
		return

	direction = direction.normalized()
	var speed := FREE_ROAM_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FREE_ROAM_FAST_MULTIPLIER
	camera.global_position += direction * speed * delta
