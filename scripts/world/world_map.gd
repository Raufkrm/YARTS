extends Node3D

const PLANET_RADIUS := 2.0
const PLANET_GRID_RADIUS := 2.015
const TERMINATOR_RADIUS := PLANET_RADIUS * 1.012
const ATMOSPHERE_RADIUS := PLANET_RADIUS * 1.34
const TERRAIN_CELL_SUBDIVISIONS := 4
const ROTATION_SPEED := 0.025
const ZOOM_DURATION := 0.85
const CAMERA_DEFAULT_DISTANCE := 6.2
const CAMERA_MIN_DISTANCE := PLANET_RADIUS + 0.85
const CAMERA_MAX_DISTANCE := 12.0
const CAMERA_ORBIT_SPEED := 1.35
const CAMERA_MOUSE_ORBIT_SPEED := 0.006
const CAMERA_ZOOM_STEP := 0.45
const CAMERA_MIN_PITCH := -1.15
const CAMERA_MAX_PITCH := 1.15
const SUN_RADIUS_EARTH_RATIO := 109.0
const SUN_DISTANCE_EARTH_RATIO := 23455.0
const SUN_VISUAL_RADIUS := PLANET_RADIUS * SUN_RADIUS_EARTH_RATIO
const SUN_WORLD_DISTANCE := PLANET_RADIUS * SUN_DISTANCE_EARTH_RATIO
const SUN_WORLD_DIRECTION := Vector3(0.74, 0.45, 0.50)
const SUN_VISUAL_DISTANCE := 185.0
const SUN_CORE_QUAD_SIZE := 15.0
const SUN_BURST_QUAD_SIZE := 50.0

var selected_cell_id := ""
var zooming := false
var orbit_dragging := false
var camera_yaw := 0.0
var camera_pitch := -0.22
var camera_distance := CAMERA_DEFAULT_DISTANCE

var planet_root: Node3D
var camera_pivot: Node3D
var terrain_mesh_instance: MeshInstance3D
var grid_mesh_instance: MeshInstance3D
var selection_mesh_instance: MeshInstance3D
var terminator_mesh_instance: MeshInstance3D
var atmosphere_mesh_instance: MeshInstance3D
var camera: Camera3D
var sun_light: DirectionalLight3D
var sun_core_visual: MeshInstance3D
var sun_burst_visual: MeshInstance3D
var sun_shader_material: ShaderMaterial
var sun_shader_time := 0.0
var info_label: Label
var event_log_label: RichTextLabel


func _ready() -> void:
	if Game.world_state == null:
		Game.new_campaign()

	_build_world()
	_build_overlay()
	Game.world_state_changed.connect(_refresh_world)
	_refresh_world()


func _process(delta: float) -> void:
	if sun_shader_material != null:
		sun_shader_time += delta
		sun_shader_material.set_shader_parameter("time", sun_shader_time)
	_face_sun_visuals_to_camera()

	if planet_root != null and not zooming:
		planet_root.rotate_y(ROTATION_SPEED * delta)
		camera_yaw += ROTATION_SPEED * delta
		_update_camera_orbit_from_input(delta)
		_apply_camera_orbit()

	if zooming and camera != null:
		camera.look_at(Vector3.ZERO, Vector3.UP)


func _input(event: InputEvent) -> void:
	if zooming:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbit_dragging = event.pressed and not _is_pointer_over_ui()
			if event.pressed:
				get_viewport().set_input_as_handled()
			return

		if event.pressed and not _is_pointer_over_ui():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_camera_distance(camera_distance - CAMERA_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_camera_distance(camera_distance + CAMERA_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				_select_cell_from_screen(event.position)

	if event is InputEventMouseMotion and orbit_dragging:
		camera_yaw -= event.relative.x * CAMERA_MOUSE_ORBIT_SPEED
		camera_pitch = clamp(camera_pitch - event.relative.y * CAMERA_MOUSE_ORBIT_SPEED, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
		_apply_camera_orbit()
		get_viewport().set_input_as_handled()


func _build_world() -> void:
	planet_root = Node3D.new()
	planet_root.name = "RotatingPlanet"
	add_child(planet_root)

	terrain_mesh_instance = MeshInstance3D.new()
	terrain_mesh_instance.name = "GeneratedTerrainCells"
	planet_root.add_child(terrain_mesh_instance)

	grid_mesh_instance = MeshInstance3D.new()
	grid_mesh_instance.name = "WrappedGrid"
	grid_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(grid_mesh_instance)

	selection_mesh_instance = MeshInstance3D.new()
	selection_mesh_instance.name = "SelectedCellOutline"
	selection_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(selection_mesh_instance)

	atmosphere_mesh_instance = MeshInstance3D.new()
	atmosphere_mesh_instance.name = "PlanetAtmosphere"
	var atmosphere_sphere := SphereMesh.new()
	atmosphere_sphere.radius = ATMOSPHERE_RADIUS
	atmosphere_sphere.height = ATMOSPHERE_RADIUS * 2.0
	atmosphere_sphere.radial_segments = 96
	atmosphere_sphere.rings = 48
	atmosphere_mesh_instance.mesh = atmosphere_sphere
	var atmosphere_material := ShaderMaterial.new()
	atmosphere_material.shader = load("res://shaders/planet_atmosphere.gdshader")
	atmosphere_material.set_shader_parameter("sun_direction", SUN_WORLD_DIRECTION.normalized())
	atmosphere_material.set_shader_parameter("horizon_color", Color(0.62, 0.84, 1.0))
	atmosphere_material.set_shader_parameter("high_color", Color(0.12, 0.34, 0.78))
	atmosphere_material.set_shader_parameter("white_limb_color", Color(1.0, 0.96, 0.82))
	atmosphere_material.set_shader_parameter("baby_blue_color", Color(0.62, 0.84, 1.0))
	atmosphere_material.set_shader_parameter("bright_yellow_color", Color(1.0, 0.88, 0.18))
	atmosphere_material.set_shader_parameter("bright_red_color", Color(1.0, 0.02, 0.0))
	atmosphere_material.set_shader_parameter("dark_red_color", Color(0.62, 0.0, 0.0))
	atmosphere_material.set_shader_parameter("dark_yellow_color", Color(0.35, 0.22, 0.035))
	atmosphere_material.set_shader_parameter("rim_power", 7.4)
	atmosphere_material.set_shader_parameter("rim_strength", 0.72)
	atmosphere_material.set_shader_parameter("day_strength", 0.08)
	atmosphere_material.set_shader_parameter("alpha_multiplier", 0.72)
	atmosphere_material.set_shader_parameter("face_fade_power", 4.2)
	atmosphere_material.set_shader_parameter("planet_radius_ratio", PLANET_RADIUS / ATMOSPHERE_RADIUS)
	atmosphere_material.set_shader_parameter("planet_radius_world", PLANET_RADIUS)
	atmosphere_material.set_shader_parameter("outer_fade_power", 3.8)
	atmosphere_material.set_shader_parameter("warm_spill_strength", 1.05)
	atmosphere_material.set_shader_parameter("dark_spill", 0.45)
	atmosphere_material.set_shader_parameter("red_dark_spill", 0.38)
	atmosphere_mesh_instance.material_override = atmosphere_material
	atmosphere_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(atmosphere_mesh_instance)

	terminator_mesh_instance = MeshInstance3D.new()
	terminator_mesh_instance.name = "PlanetSurfaceTerminatorGlow"
	var terminator_sphere := SphereMesh.new()
	terminator_sphere.radius = TERMINATOR_RADIUS
	terminator_sphere.height = TERMINATOR_RADIUS * 2.0
	terminator_sphere.radial_segments = 96
	terminator_sphere.rings = 48
	terminator_mesh_instance.mesh = terminator_sphere
	var terminator_material := ShaderMaterial.new()
	terminator_material.shader = load("res://shaders/planet_terminator_glow.gdshader")
	terminator_material.set_shader_parameter("sun_direction", SUN_WORLD_DIRECTION.normalized())
	terminator_material.set_shader_parameter("amber_color", Color(1.0, 0.62, 0.16))
	terminator_material.set_shader_parameter("orange_color", Color(1.0, 0.28, 0.04))
	terminator_material.set_shader_parameter("red_color", Color(0.85, 0.05, 0.015))
	terminator_material.set_shader_parameter("band_width", 0.48)
	terminator_material.set_shader_parameter("lit_offset", 0.08)
	terminator_material.set_shader_parameter("rim_power", 1.25)
	terminator_material.set_shader_parameter("alpha_strength", 0.95)
	terminator_mesh_instance.material_override = terminator_material
	terminator_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terminator_mesh_instance.visible = false
	planet_root.add_child(terminator_mesh_instance)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraOrbitPivot"
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.name = "WorldCamera"
	camera.position = Vector3(0.0, 0.0, camera_distance)
	camera.fov = 45.0
	camera.near = 0.05
	camera.far = SUN_VISUAL_DISTANCE + SUN_BURST_QUAD_SIZE * 2.0
	camera.current = true
	camera_pivot.add_child(camera)
	_apply_camera_orbit()

	sun_core_visual = MeshInstance3D.new()
	sun_core_visual.name = "VisibleSunCore"
	var core_quad := QuadMesh.new()
	core_quad.size = Vector2(SUN_CORE_QUAD_SIZE, SUN_CORE_QUAD_SIZE)
	sun_core_visual.mesh = core_quad
	var sun_shader: Shader = load("res://shaders/flaring_star_sun.gdshader")
	sun_shader_material = ShaderMaterial.new()
	sun_shader_material.shader = sun_shader
	sun_shader_material.set_shader_parameter("brightness", 1.7)
	sun_shader_material.set_shader_parameter("ray_brightness", 12.0)
	sun_shader_material.set_shader_parameter("gamma", 5.8)
	sun_shader_material.set_shader_parameter("spot_brightness", 15.0)
	sun_shader_material.set_shader_parameter("ray_density", 4.2)
	sun_shader_material.set_shader_parameter("curvature", 18.0)
	sun_shader_material.set_shader_parameter("rgb", Vector3(5.6, 1.55, 0.28))
	sun_shader_material.set_shader_parameter("emission_strength", 4.2)
	sun_core_visual.material_override = sun_shader_material
	sun_core_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun_core_visual.position = _sun_visual_position()
	add_child(sun_core_visual)

	sun_burst_visual = MeshInstance3D.new()
	sun_burst_visual.name = "VisibleSunStarburst"
	var burst_quad := QuadMesh.new()
	burst_quad.size = Vector2(SUN_BURST_QUAD_SIZE, SUN_BURST_QUAD_SIZE)
	sun_burst_visual.mesh = burst_quad
	var burst_material := ShaderMaterial.new()
	burst_material.shader = load("res://shaders/starburst_3d_sun.gdshader")
	burst_material.set_shader_parameter("star_color", Color(1.0, 0.86, 0.44, 1.0))
	burst_material.set_shader_parameter("spike_count", 16)
	burst_material.set_shader_parameter("flare_intensity", 0.34)
	burst_material.set_shader_parameter("spike_length", 7.2)
	burst_material.set_shader_parameter("long_ray_intensity", 0.52)
	burst_material.set_shader_parameter("long_ray_length", 2.35)
	burst_material.set_shader_parameter("glow_size", 0.016)
	burst_material.set_shader_parameter("glow_intensity", 5.5)
	burst_material.set_shader_parameter("master_brightness", 0.62)
	burst_material.set_shader_parameter("alpha_threshold", 0.12)
	burst_material.set_shader_parameter("edge_smoothing", 0.16)
	burst_material.set_shader_parameter("inner_thickness", 0.0052)
	burst_material.set_shader_parameter("outer_thickness", 0.0012)
	sun_burst_visual.material_override = burst_material
	sun_burst_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun_burst_visual.position = _sun_visual_position()
	add_child(sun_burst_visual)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.light_energy = 2.4
	sun_light.shadow_enabled = true
	add_child(sun_light)
	sun_light.look_at_from_position(_sun_world_position(), Vector3.ZERO, Vector3.UP)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/star_nest_sky.gdshader")
	sky_material.set_shader_parameter("formuparam", 0.75)
	sky_material.set_shader_parameter("stepsize", 0.1)
	sky_material.set_shader_parameter("zoom", 0.85)
	sky_material.set_shader_parameter("tile", 0.85)
	sky_material.set_shader_parameter("drift_speed", Vector3(0.0, 0.00045, 0.00015))
	sky_material.set_shader_parameter("brightness", 0.00008)
	sky_material.set_shader_parameter("darkmatter", 0.55)
	sky_material.set_shader_parameter("distfading", 0.55)
	sky_material.set_shader_parameter("saturation", 0.0)
	sky_material.set_shader_parameter("space_tint", Vector3(0.00055, 0.00145, 0.0042))
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.04, 0.05, 0.08)
	environment.ambient_light_energy = 0.18
	world_environment.environment = environment
	add_child(world_environment)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "WorldOverlay"
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(16, 16)
	top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(top_bar)

	var new_button := Button.new()
	new_button.text = "New World"
	new_button.pressed.connect(_on_new_campaign_pressed)
	top_bar.add_child(new_button)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	top_bar.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_on_load_pressed)
	top_bar.add_child(load_button)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 58)
	panel.custom_minimum_size = Vector2(340, 260)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_margin.add_theme_constant_override("margin_left", 12)
	panel_margin.add_theme_constant_override("margin_top", 10)
	panel_margin.add_theme_constant_override("margin_right", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(panel_margin)

	var panel_stack := VBoxContainer.new()
	panel_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_margin.add_child(panel_stack)

	var title := Label.new()
	title.text = "Rotating World"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 20)
	panel_stack.add_child(title)

	info_label = Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_stack.add_child(info_label)

	var hint := Label.new()
	hint.text = "Click a cell to enter it. WASD/arrows or right-drag orbit. Mouse wheel zooms."
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_stack.add_child(hint)

	var log_title := Label.new()
	log_title.text = "Debug Events"
	log_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_title.add_theme_font_size_override("font_size", 16)
	panel_stack.add_child(log_title)

	event_log_label = RichTextLabel.new()
	event_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_log_label.custom_minimum_size = Vector2(0, 92)
	event_log_label.fit_content = false
	panel_stack.add_child(event_log_label)


func _refresh_world() -> void:
	if Game.world_state == null:
		return

	if selected_cell_id.is_empty():
		selected_cell_id = Game.world_state.starting_cell_id

	terrain_mesh_instance.mesh = _build_planet_mesh()
	grid_mesh_instance.mesh = _build_grid_mesh()
	selection_mesh_instance.mesh = _build_cell_outline_mesh(selected_cell_id)
	_update_overlay()


func _build_planet_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for cell in Game.world_state.get_cells():
		var width: int = int(Game.world_state.width)
		var height: int = int(Game.world_state.height)
		var lon_left: float = lerpf(-PI, PI, float(cell.x) / float(width))
		var lon_right: float = lerpf(-PI, PI, float(cell.x + 1) / float(width))
		var lat_top: float = lerpf(PI / 2.0, -PI / 2.0, float(cell.y) / float(height))
		var lat_bottom: float = lerpf(PI / 2.0, -PI / 2.0, float(cell.y + 1) / float(height))
		var cell_color := _terrain_color(cell.terrain, cell.owner_id)

		for sub_y in range(TERRAIN_CELL_SUBDIVISIONS):
			var lat_a: float = lerpf(lat_top, lat_bottom, float(sub_y) / float(TERRAIN_CELL_SUBDIVISIONS))
			var lat_b: float = lerpf(lat_top, lat_bottom, float(sub_y + 1) / float(TERRAIN_CELL_SUBDIVISIONS))
			for sub_x in range(TERRAIN_CELL_SUBDIVISIONS):
				var lon_a: float = lerpf(lon_left, lon_right, float(sub_x) / float(TERRAIN_CELL_SUBDIVISIONS))
				var lon_b: float = lerpf(lon_left, lon_right, float(sub_x + 1) / float(TERRAIN_CELL_SUBDIVISIONS))
				var base_index := vertices.size()
				var corners := [
					_direction_from_lat_lon(lat_a, lon_a),
					_direction_from_lat_lon(lat_a, lon_b),
					_direction_from_lat_lon(lat_b, lon_b),
					_direction_from_lat_lon(lat_b, lon_a),
				]

				for direction in corners:
					vertices.append(direction * PLANET_RADIUS)
					normals.append(direction)
					colors.append(cell_color)

				indices.append(base_index)
				indices.append(base_index + 1)
				indices.append(base_index + 2)
				indices.append(base_index)
				indices.append(base_index + 2)
				indices.append(base_index + 3)

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
	material.roughness = 0.82
	mesh.surface_set_material(0, material)
	return mesh


func _build_grid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var color := Color(0.9, 0.95, 1.0, 0.14)
	var width: int = int(Game.world_state.width)
	var height: int = int(Game.world_state.height)
	var segments := 96

	for row in range(1, height):
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, float(row) / float(height))
		for segment in range(segments):
			var lon_a: float = lerpf(-PI, PI, float(segment) / float(segments))
			var lon_b: float = lerpf(-PI, PI, float(segment + 1) / float(segments))
			vertices.append(_direction_from_lat_lon(lat, lon_a) * PLANET_GRID_RADIUS)
			vertices.append(_direction_from_lat_lon(lat, lon_b) * PLANET_GRID_RADIUS)
			colors.append(color)
			colors.append(color)

	for column in range(width):
		var lon: float = lerpf(-PI, PI, float(column) / float(width))
		for segment in range(segments):
			var lat_a: float = lerpf(PI / 2.0, -PI / 2.0, float(segment) / float(segments))
			var lat_b: float = lerpf(PI / 2.0, -PI / 2.0, float(segment + 1) / float(segments))
			vertices.append(_direction_from_lat_lon(lat_a, lon) * PLANET_GRID_RADIUS)
			vertices.append(_direction_from_lat_lon(lat_b, lon) * PLANET_GRID_RADIUS)
			colors.append(color)
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


func _build_cell_outline_mesh(cell_id: String) -> ArrayMesh:
	var cell = Game.world_state.get_cell(cell_id)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	if cell == null:
		return ArrayMesh.new()

	var color := Color(1.0, 0.92, 0.25, 1.0)
	var corners := _cell_corner_directions(cell.x, cell.y)
	var edges := [
		[corners[0], corners[1]],
		[corners[1], corners[2]],
		[corners[2], corners[3]],
		[corners[3], corners[0]],
	]

	for edge in edges:
		for segment in range(10):
			var t_a := float(segment) / 10.0
			var t_b := float(segment + 1) / 10.0
			vertices.append(edge[0].slerp(edge[1], t_a).normalized() * 2.045)
			vertices.append(edge[0].slerp(edge[1], t_b).normalized() * 2.045)
			colors.append(color)
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
	mesh.surface_set_material(0, material)
	return mesh


func _select_cell_from_screen(screen_position: Vector2) -> void:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var hit = _ray_sphere_intersection(ray_origin, ray_direction, Vector3.ZERO, PLANET_RADIUS)
	if hit == null:
		return

	var local_hit := planet_root.to_local(hit).normalized()
	selected_cell_id = Game.world_state.direction_to_cell_id(local_hit)
	Game.current_cell_id = selected_cell_id
	Game.debug_event("cell_selected cell=%s" % selected_cell_id)
	selection_mesh_instance.mesh = _build_cell_outline_mesh(selected_cell_id)
	_update_overlay()
	_zoom_to_selected_cell()


func _zoom_to_selected_cell() -> void:
	var cell = Game.world_state.get_cell(selected_cell_id)
	if cell == null:
		return

	zooming = true
	var lat_lon: Vector2 = Game.world_state.get_cell_center_lat_lon(cell)
	var local_direction := _direction_from_lat_lon(lat_lon.x, lat_lon.y)
	var world_direction := planet_root.global_transform.basis * local_direction
	var target_distance: float = max(CAMERA_MIN_DISTANCE, 3.05)
	var target_position: Vector3 = world_direction.normalized() * target_distance
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_position, ZOOM_DURATION)
	tween.tween_callback(_enter_selected_cell)


func _enter_selected_cell() -> void:
	Game.start_battle(selected_cell_id)


func _ray_sphere_intersection(origin: Vector3, direction: Vector3, center: Vector3, radius: float):
	var oc := origin - center
	var a := direction.dot(direction)
	var b := 2.0 * oc.dot(direction)
	var c := oc.dot(oc) - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null

	var distance := (-b - sqrt(discriminant)) / (2.0 * a)
	if distance < 0.0:
		distance = (-b + sqrt(discriminant)) / (2.0 * a)
	if distance < 0.0:
		return null
	return origin + direction * distance


func _cell_corner_directions(x_index: int, y_index: int) -> Array:
	var width: int = int(Game.world_state.width)
	var height: int = int(Game.world_state.height)
	var lon_left: float = lerpf(-PI, PI, float(x_index) / float(width))
	var lon_right: float = lerpf(-PI, PI, float(x_index + 1) / float(width))
	var lat_top: float = lerpf(PI / 2.0, -PI / 2.0, float(y_index) / float(height))
	var lat_bottom: float = lerpf(PI / 2.0, -PI / 2.0, float(y_index + 1) / float(height))
	return [
		_direction_from_lat_lon(lat_top, lon_left),
		_direction_from_lat_lon(lat_top, lon_right),
		_direction_from_lat_lon(lat_bottom, lon_right),
		_direction_from_lat_lon(lat_bottom, lon_left),
	]


func _direction_from_lat_lon(lat: float, lon: float) -> Vector3:
	var cos_lat := cos(lat)
	return Vector3(
		cos_lat * sin(lon),
		sin(lat),
		cos_lat * cos(lon)
	).normalized()


func _terrain_color(terrain: String, owner_id: String) -> Color:
	var color := Color(0.35, 0.58, 0.26)
	match terrain:
		"forest":
			color = Color(0.08, 0.38, 0.16)
		"hills":
			color = Color(0.46, 0.43, 0.34)
		"water":
			color = Color(0.05, 0.26, 0.56)
		_:
			color = Color(0.38, 0.60, 0.29)

	if owner_id == "player":
		color = color.lerp(Color(0.18, 0.72, 0.76), 0.22)
	elif owner_id == "bandits":
		color = color.lerp(Color(0.78, 0.22, 0.16), 0.16)
	return color


func _update_overlay() -> void:
	var cell = Game.world_state.get_cell(selected_cell_id)
	if cell == null:
		info_label.text = "No cell selected."
	else:
		info_label.text = _join_lines([
			"Selected: %s" % cell.id,
			"Owner: %s" % _owner_label(cell.owner_id),
			"Terrain: %s" % cell.terrain.capitalize(),
			"Threat: %d" % cell.threat_level,
			"Food: %d  Wood: %d  Stone: %d" % [
				int(cell.resources.get("food", 0)),
				int(cell.resources.get("wood", 0)),
				int(cell.resources.get("stone", 0)),
			],
			"Supply: %d" % int(cell.resources.get("supply", 0)),
		])

	event_log_label.text = _join_lines(Game.get_recent_events(8))


func _on_new_campaign_pressed() -> void:
	selected_cell_id = ""
	zooming = false
	camera_yaw = 0.0
	camera_pitch = -0.22
	_set_camera_distance(CAMERA_DEFAULT_DISTANCE)
	Game.new_campaign()


func _on_save_pressed() -> void:
	Game.save_campaign()
	_update_overlay()


func _on_load_pressed() -> void:
	if Game.load_campaign():
		selected_cell_id = Game.current_cell_id
		_refresh_world()


func _owner_label(owner_id: String) -> String:
	match owner_id:
		"player":
			return "Player"
		"bandits":
			return "Bandits"
		_:
			return "Neutral"


func _join_lines(lines: Array) -> String:
	var output := ""
	for line in lines:
		if not output.is_empty():
			output += "\n"
		output += str(line)
	return output


func _is_pointer_over_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	return hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _sun_world_position() -> Vector3:
	return SUN_WORLD_DIRECTION.normalized() * SUN_WORLD_DISTANCE


func _sun_visual_position() -> Vector3:
	return SUN_WORLD_DIRECTION.normalized() * SUN_VISUAL_DISTANCE


func _face_sun_visuals_to_camera() -> void:
	if camera == null:
		return

	if sun_core_visual != null:
		sun_core_visual.look_at(camera.global_position, Vector3.UP)
	if sun_burst_visual != null:
		sun_burst_visual.look_at(camera.global_position, Vector3.UP)


func _update_camera_orbit_from_input(delta: float) -> void:
	var yaw_input := 0.0
	var pitch_input := 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		yaw_input -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		yaw_input += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pitch_input += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pitch_input -= 1.0

	if yaw_input != 0.0:
		camera_yaw += yaw_input * CAMERA_ORBIT_SPEED * delta
	if pitch_input != 0.0:
		camera_pitch = clamp(camera_pitch + pitch_input * CAMERA_ORBIT_SPEED * delta, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)


func _set_camera_distance(distance: float) -> void:
	camera_distance = clamp(distance, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	if camera != null:
		camera.position = Vector3(0.0, 0.0, camera_distance)


func _apply_camera_orbit() -> void:
	if camera_pivot == null or camera == null:
		return

	camera_pivot.position = Vector3.ZERO
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, camera_distance)
	camera.rotation = Vector3.ZERO
