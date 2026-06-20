extends Node3D

const PLANET_RADIUS := 2.0
const PLANET_GRID_RADIUS := 2.015
const TERMINATOR_RADIUS := PLANET_RADIUS * 1.012
const ATMOSPHERE_RADIUS := PLANET_RADIUS * 1.34
const WORLD_SURFACE_LONGITUDE_SEGMENTS := 512
const WORLD_SURFACE_LATITUDE_SEGMENTS := 256
const PLANET_TEXTURE_SIZE := Vector2i(2048, 1024)
const PLANET_TEXTURE_VERSION := 8
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
var debug_view_mode := "terrain"
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
var planet_material: StandardMaterial3D
var planet_texture: Texture2D
var planet_texture_cache_key := ""
var info_label: Label
var event_log_label: RichTextLabel
var debug_view_button: Button
var world_loading_layer: CanvasLayer
var world_loading_label: Label
var world_loading_bar: ProgressBar
var suppress_world_refresh := false
var world_refresh_running := false
var grid_faint_enabled := true


func _ready() -> void:
	_build_world()
	_build_overlay()
	Game.world_state_changed.connect(_on_world_state_changed)
	call_deferred("_load_world_on_startup")


func _process(delta: float) -> void:
	if sun_shader_material != null:
		sun_shader_time += delta
		sun_shader_material.set_shader_parameter("time", sun_shader_time)
	_face_sun_visuals_to_camera()

	if planet_root != null and not zooming:
		var rotation_step := Game.advance_world_time(delta)
		_sync_world_rotation_from_game()
		camera_yaw += rotation_step
		_update_camera_orbit_from_input(delta)
		_apply_camera_orbit()

	if zooming and camera != null:
		camera.look_at(Vector3.ZERO, Vector3.UP)


func _input(event: InputEvent) -> void:
	if world_loading_layer != null:
		return
	if zooming:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_toggle_grid_faint()
			get_viewport().set_input_as_handled()
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


func _sync_world_rotation_from_game() -> void:
	if planet_root != null:
		planet_root.rotation.y = Game.get_world_rotation_angle()


func _build_world() -> void:
	planet_root = Node3D.new()
	planet_root.name = "RotatingPlanet"
	_sync_world_rotation_from_game()
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
	camera_yaw = Game.get_world_rotation_angle()
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
	environment.ambient_light_color = Color(0.14, 0.16, 0.22)
	environment.ambient_light_energy = 0.52
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

	debug_view_button = Button.new()
	debug_view_button.text = "View: Terrain"
	debug_view_button.pressed.connect(_on_debug_view_pressed)
	top_bar.add_child(debug_view_button)

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
	hint.text = "Click a cell to enter it. %s/arrows or right-drag orbit. Mouse wheel zooms. G toggles grid." % Game.movement_layout_label()
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


func _build_world_loading_overlay() -> void:
	if world_loading_layer != null:
		return

	world_loading_layer = CanvasLayer.new()
	world_loading_layer.name = "WorldLoadingOverlay"
	world_loading_layer.layer = 100
	add_child(world_loading_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.020, 0.030, 0.92)
	world_loading_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -82
	panel.offset_right = 300
	panel.offset_bottom = 82
	world_loading_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	margin.add_child(stack)

	var title := Label.new()
	title.text = "Preparing World"
	title.add_theme_font_size_override("font_size", 20)
	stack.add_child(title)

	world_loading_label = Label.new()
	world_loading_label.text = "Starting..."
	world_loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(world_loading_label)

	world_loading_bar = ProgressBar.new()
	world_loading_bar.min_value = 0.0
	world_loading_bar.max_value = 100.0
	world_loading_bar.value = 0.0
	stack.add_child(world_loading_bar)


func _show_world_loading(stage: String, progress: float = 0.0) -> void:
	_build_world_loading_overlay()
	_set_world_loading(stage, progress)


func _set_world_loading(stage: String, progress: float) -> void:
	if world_loading_label != null:
		world_loading_label.text = stage
	if world_loading_bar != null:
		world_loading_bar.value = clamp(progress, 0.0, 1.0) * 100.0


func _hide_world_loading() -> void:
	if world_loading_layer != null:
		world_loading_layer.queue_free()
		world_loading_layer = null
		world_loading_label = null
		world_loading_bar = null


func _load_world_on_startup() -> void:
	if world_refresh_running:
		return

	world_refresh_running = true
	_show_world_loading("Opening world scene...", 0.02)
	await get_tree().process_frame
	if Game.world_state == null:
		await _create_world_with_loading(0, 24, 12, "Creating new world")
	else:
		await _refresh_world_with_loading("Loading world map")
	_hide_world_loading()
	world_refresh_running = false


func _create_world_with_loading(seed: int, width: int, height: int, title: String) -> void:
	suppress_world_refresh = true
	selected_cell_id = ""
	_set_world_loading("%s: generating seed, cells, biomes, and rivers..." % title, 0.08)
	await get_tree().process_frame
	Game.new_campaign(seed, width, height)
	if Game.world_state != null:
		selected_cell_id = Game.world_state.starting_cell_id
	_set_world_loading("%s: world data ready, building globe..." % title, 0.22)
	await get_tree().process_frame
	await _refresh_world_with_loading(title)
	suppress_world_refresh = false


func _run_world_refresh_with_loading(title: String) -> void:
	if world_refresh_running:
		return

	world_refresh_running = true
	_show_world_loading("%s..." % title, 0.02)
	await get_tree().process_frame
	await _refresh_world_with_loading(title)
	_hide_world_loading()
	world_refresh_running = false


func _refresh_world_with_loading(title: String) -> void:
	if Game.world_state == null:
		return

	if selected_cell_id.is_empty():
		selected_cell_id = Game.world_state.starting_cell_id
	_sync_world_rotation_from_game()

	_set_world_loading("%s: building planet geometry..." % title, 0.30)
	await get_tree().process_frame
	terrain_mesh_instance.mesh = _build_planet_mesh(false)

	_set_world_loading("%s: painting terrain texture..." % title, 0.42)
	await get_tree().process_frame
	await _apply_planet_texture_with_loading(0.42, 0.86)

	_set_world_loading("%s: wrapping strategic grid..." % title, 0.90)
	await get_tree().process_frame
	grid_mesh_instance.mesh = _build_grid_mesh()

	_set_world_loading("%s: selecting starting cell..." % title, 0.96)
	await get_tree().process_frame
	selection_mesh_instance.mesh = _build_cell_outline_mesh(selected_cell_id)
	_update_overlay()
	_set_world_loading("%s complete." % title, 1.0)
	await get_tree().process_frame


func _on_world_state_changed() -> void:
	if suppress_world_refresh:
		return
	call_deferred("_run_world_refresh_with_loading", "Refreshing world")


func _refresh_world() -> void:
	if Game.world_state == null:
		return

	if selected_cell_id.is_empty():
		selected_cell_id = Game.world_state.starting_cell_id

	terrain_mesh_instance.mesh = _build_planet_mesh()
	grid_mesh_instance.mesh = _build_grid_mesh()
	selection_mesh_instance.mesh = _build_cell_outline_mesh(selected_cell_id)
	_update_overlay()


func _build_planet_mesh(apply_texture: bool = true) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_length := WORLD_SURFACE_LONGITUDE_SEGMENTS + 1

	for lat_index in range(WORLD_SURFACE_LATITUDE_SEGMENTS + 1):
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, float(lat_index) / float(WORLD_SURFACE_LATITUDE_SEGMENTS))
		for lon_index in range(WORLD_SURFACE_LONGITUDE_SEGMENTS + 1):
			var lon: float = lerpf(-PI, PI, float(lon_index) / float(WORLD_SURFACE_LONGITUDE_SEGMENTS))
			var direction := _direction_from_lat_lon(lat, lon)
			vertices.append(direction * PLANET_RADIUS)
			normals.append(direction)
			uvs.append(Vector2(
				float(lon_index) / float(WORLD_SURFACE_LONGITUDE_SEGMENTS),
				float(lat_index) / float(WORLD_SURFACE_LATITUDE_SEGMENTS)
			))

	for lat_index in range(WORLD_SURFACE_LATITUDE_SEGMENTS):
		for lon_index in range(WORLD_SURFACE_LONGITUDE_SEGMENTS):
			var base_index := lat_index * row_length + lon_index
			indices.append(base_index)
			indices.append(base_index + 1)
			indices.append(base_index + row_length)

			indices.append(base_index + 1)
			indices.append(base_index + row_length + 1)
			indices.append(base_index + row_length)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	planet_material = StandardMaterial3D.new()
	planet_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	planet_material.roughness = 0.82
	planet_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.surface_set_material(0, planet_material)
	if apply_texture:
		_apply_planet_texture()
	return mesh


func _clear_planet_texture_cache() -> void:
	planet_texture = null
	planet_texture_cache_key = ""


func _apply_planet_texture() -> void:
	if planet_material == null or Game.world_state == null:
		return

	var cache_key := _planet_texture_cache_key()
	if cache_key != planet_texture_cache_key:
		planet_texture = null
		planet_texture_cache_key = cache_key

	if planet_texture == null:
		var cached_texture = Game.get_world_visual_cache(cache_key)
		if cached_texture is Texture2D:
			planet_texture = cached_texture
		if planet_texture == null:
			planet_texture = _build_planet_texture(PLANET_TEXTURE_SIZE.x, PLANET_TEXTURE_SIZE.y)
			Game.set_world_visual_cache(cache_key, planet_texture)
	planet_material.albedo_texture = planet_texture


func _apply_planet_texture_with_loading(progress_start: float, progress_end: float) -> void:
	if planet_material == null or Game.world_state == null:
		return

	var cache_key := _planet_texture_cache_key()
	if cache_key != planet_texture_cache_key:
		planet_texture = null
		planet_texture_cache_key = cache_key

	if planet_texture == null:
		var cached_texture = Game.get_world_visual_cache(cache_key)
		if cached_texture is Texture2D:
			_set_world_loading("Using cached planet texture...", progress_end)
			await get_tree().process_frame
			planet_texture = cached_texture
		if planet_texture == null:
			planet_texture = await _build_planet_texture_with_loading(PLANET_TEXTURE_SIZE.x, PLANET_TEXTURE_SIZE.y, progress_start, progress_end)
			Game.set_world_visual_cache(cache_key, planet_texture)
	planet_material.albedo_texture = planet_texture


func _planet_texture_cache_key() -> String:
	return "planet_texture:v%d:%d:%s:%dx%d" % [
		PLANET_TEXTURE_VERSION,
		int(Game.world_state.seed),
		debug_view_mode,
		PLANET_TEXTURE_SIZE.x,
		PLANET_TEXTURE_SIZE.y,
	]


func _build_planet_texture(width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, true, Image.FORMAT_RGBA8)
	for y in range(height):
		var v: float = float(y) / float(height - 1)
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, v)
		for x in range(width):
			var u: float = float(x) / float(width - 1)
			var lon: float = lerpf(-PI, PI, u)
			var sample: Dictionary = Game.world_state.sample_world(lat, lon)
			image.set_pixel(x, y, _sample_color(sample, "neutral"))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _build_planet_texture_with_loading(width: int, height: int, progress_start: float, progress_end: float) -> Texture2D:
	var image := Image.create(width, height, true, Image.FORMAT_RGBA8)
	var row_step := 16
	for y in range(height):
		var v: float = float(y) / float(height - 1)
		var lat: float = lerpf(PI / 2.0, -PI / 2.0, v)
		for x in range(width):
			var u: float = float(x) / float(width - 1)
			var lon: float = lerpf(-PI, PI, u)
			var sample: Dictionary = Game.world_state.sample_world(lat, lon)
			image.set_pixel(x, y, _sample_color(sample, "neutral"))

		if y % row_step == 0:
			var row_progress: float = float(y) / float(max(height - 1, 1))
			_set_world_loading(
				"Painting planet texture row %d/%d..." % [y + 1, height],
				lerpf(progress_start, progress_end - 0.04, row_progress)
			)
			await get_tree().process_frame

	_set_world_loading("Generating planet texture mipmaps...", progress_end - 0.02)
	await get_tree().process_frame
	image.generate_mipmaps()
	_set_world_loading("Uploading planet texture...", progress_end)
	await get_tree().process_frame
	return ImageTexture.create_from_image(image)


func _build_grid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var grid_alpha := 0.035 if grid_faint_enabled else 0.14
	var color := Color(0.9, 0.95, 1.0, grid_alpha)
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
		var is_polar_boundary := column % WorldState.POLAR_MERGE_SPAN == 0
		var start_segment := 0 if is_polar_boundary else int(ceil(float(segments) / float(height)))
		var end_segment := segments if is_polar_boundary else int(floor(float(segments) * float(height - 1) / float(height)))
		for segment in range(start_segment, end_segment):
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


func _toggle_grid_faint() -> void:
	grid_faint_enabled = not grid_faint_enabled
	_refresh_grid_mesh()


func _refresh_grid_mesh() -> void:
	if grid_mesh_instance == null or Game.world_state == null:
		return
	grid_mesh_instance.mesh = _build_grid_mesh()


func _build_cell_outline_mesh(cell_id: String) -> ArrayMesh:
	var cell = Game.world_state.get_cell(cell_id)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	if cell == null:
		return ArrayMesh.new()

	var color := Color(1.0, 0.92, 0.25, 1.0)
	var corners := _cell_corner_directions(cell.x, cell.y, cell.x_span)
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
	_sync_battle_sun_context()
	Game.start_battle(selected_cell_id)


func _sync_battle_sun_context() -> void:
	var cell = Game.world_state.get_cell(selected_cell_id)
	if cell == null or planet_root == null:
		return

	var lat_lon: Vector2 = Game.world_state.get_cell_center_lat_lon(cell)
	var cell_normal := _direction_from_lat_lon(lat_lon.x, lat_lon.y)
	var sun_planet := (planet_root.global_transform.basis.inverse() * SUN_WORLD_DIRECTION.normalized()).normalized()
	Game.set_battle_sun_context_for_cell(cell_normal, sun_planet)


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


func _cell_corner_directions(x_index: int, y_index: int, x_span: int = 1) -> Array:
	var width: int = int(Game.world_state.width)
	var height: int = int(Game.world_state.height)
	var lon_left: float = lerpf(-PI, PI, float(x_index) / float(width))
	var lon_right: float = lerpf(-PI, PI, float(x_index + x_span) / float(width))
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


func _cell_color(cell) -> Color:
	var sample: Dictionary = {
		"terrain": cell.terrain,
		"climate": cell.climate,
		"elevation": cell.elevation,
		"moisture": cell.moisture,
		"temperature": cell.temperature,
		"raw_noise": cell.elevation,
		"ridge": 0.0,
		"river": 0.0,
		"direction": _direction_from_lat_lon(Game.world_state.get_cell_center_lat_lon(cell).x, Game.world_state.get_cell_center_lat_lon(cell).y),
	}
	return _sample_color(sample, str(cell.owner_id))


func _sample_color(sample: Dictionary, owner_id: String = "neutral") -> Color:
	if debug_view_mode == "climate":
		return _climate_color(str(sample["climate"]))
	if debug_view_mode == "noise":
		var raw_noise: float = float(sample["raw_noise"])
		var noise_color := Color(raw_noise, raw_noise, raw_noise)
		return noise_color.lerp(Color(0.20, 0.72, 1.0), clamp(float(sample["river"]) * 1.8, 0.0, 1.0))
	return _terrain_color(sample, owner_id)


func _terrain_color(sample: Dictionary, owner_id: String) -> Color:
	var elevation: float = float(sample["elevation"])
	var moisture: float = float(sample["moisture"])
	var temperature: float = float(sample["temperature"])
	var ridge: float = float(sample.get("ridge", 0.0))
	var river: float = float(sample.get("river", 0.0))
	var sample_direction := Vector3.UP
	if sample.has("direction") and sample["direction"] is Vector3:
		sample_direction = sample["direction"]
	var land_height: float = clamp((elevation - WorldState.SEA_LEVEL) / max(1.0 - WorldState.SEA_LEVEL, 0.001), 0.0, 1.0)
	var surface_detail: float = clamp((float(sample.get("raw_noise", elevation)) - 0.5) * 0.20, -0.08, 0.08)
	var color := Color(0.34, 0.58, 0.28)
	if elevation < WorldState.SEA_LEVEL:
		var depth: float = clamp((WorldState.SEA_LEVEL - elevation) * 7.5, 0.0, 1.0)
		var shelf: float = smoothstep(WorldState.SEA_LEVEL - 0.13, WorldState.SEA_LEVEL - 0.012, elevation)
		color = Color(0.035, 0.19, 0.43).lerp(Color(0.04, 0.31, 0.62), 1.0 - depth)
		color = color.lerp(Color(0.15, 0.58, 0.82), shelf * 0.78)
		var sea_edge: float = smoothstep(WorldState.SEA_LEVEL - 0.085, WorldState.SEA_LEVEL - 0.004, elevation)
		var sea_floor: Color = Color(0.68, 0.59, 0.38).lerp(Color(0.42, 0.40, 0.34), clamp(ridge * 0.62, 0.0, 1.0))
		color = color.lerp(sea_floor, clamp(sea_edge * 0.34, 0.0, 0.34))
		color = color.lightened(clamp(surface_detail * 0.45, 0.0, 0.05))
	else:
		var dryness: float = clamp((1.0 - moisture) * 0.82 + temperature * 0.20, 0.0, 1.0)
		var lush: float = clamp(moisture * 1.08 - temperature * 0.10, 0.0, 1.0)
		var lowland := Color(0.38, 0.67, 0.30).lerp(Color(0.12, 0.42, 0.16), lush)
		var dryland := Color(0.63, 0.47, 0.25).lerp(Color(0.82, 0.66, 0.36), clamp(dryness, 0.0, 1.0))
		color = lowland.lerp(dryland, clamp(dryness * 0.76, 0.0, 0.76))
		var foothill: float = smoothstep(0.20, 0.48, land_height)
		color = color.lerp(Color(0.43, 0.38, 0.27), foothill * 0.30)
		var mountain: float = smoothstep(0.44, 0.72, land_height) * smoothstep(0.25, 0.70, ridge)
		color = color.lerp(Color(0.34, 0.27, 0.22), clamp(mountain * 0.78, 0.0, 0.78))
		var high_peak: float = smoothstep(0.64, 0.88, land_height) * smoothstep(0.42, 0.86, ridge)
		color = color.lerp(Color(0.68, 0.65, 0.59), clamp(high_peak, 0.0, 0.92))
		var snow: float = smoothstep(WorldState.SNOW_LEVEL - 0.08, WorldState.SNOW_LEVEL + 0.02, elevation)
		snow = max(snow, smoothstep(0.78, 0.95, abs(sample_direction.y)) * smoothstep(0.0, 0.32, 1.0 - temperature))
		color = color.lerp(Color(0.94, 0.97, 0.94), clamp(snow, 0.0, 0.90))
		var coast_edge: float = 1.0 - smoothstep(WorldState.SEA_LEVEL + 0.006, WorldState.SEA_LEVEL + 0.060, elevation)
		if coast_edge > 0.0:
			var coast_sand := Color(0.86, 0.74, 0.43)
			var coast_rock := Color(0.45, 0.40, 0.32)
			var coast_rock_mix: float = clamp(ridge * 0.60 + land_height * 0.24, 0.0, 1.0)
			var coast_color: Color = coast_sand.lerp(coast_rock, coast_rock_mix)
			color = color.lerp(coast_color, clamp(coast_edge * 0.88, 0.0, 0.88))
		var river_bank: float = smoothstep(0.012, 0.105, river) * (1.0 - smoothstep(0.28, 0.58, river))
		if river_bank > 0.0:
			var sandy_bank := Color(0.82, 0.71, 0.45)
			var rocky_bank := Color(0.42, 0.38, 0.31)
			var rock_mix: float = clamp(ridge * 0.74 + land_height * 0.34, 0.0, 1.0)
			var bank_color: Color = sandy_bank.lerp(rocky_bank, rock_mix)
			color = color.lerp(bank_color, clamp(river_bank * 0.68, 0.0, 0.68))
		var river_bed: float = smoothstep(0.20, 0.48, river)
		if river_bed > 0.0:
			var bed_color: Color = Color(0.30, 0.31, 0.30).lerp(Color(0.48, 0.46, 0.40), clamp(1.0 - ridge, 0.0, 0.55))
			color = color.lerp(bed_color, clamp(river_bed * 0.52, 0.0, 0.52))
		if river > 0.018:
			var river_strength: float = clamp((river - 0.018) * 2.55, 0.0, 0.82)
			color = color.lerp(Color(0.025, 0.30, 0.58), river_strength)
		if surface_detail > 0.0:
			color = color.lightened(surface_detail * 0.38)
		else:
			color = color.darkened(abs(surface_detail) * 0.26)
	return color


func _climate_color(climate: String) -> Color:
	match climate:
		"polar":
			return Color(0.86, 0.94, 1.0)
		"alpine":
			return Color(0.72, 0.73, 0.78)
		"cold":
			return Color(0.42, 0.65, 0.78)
		"temperate":
			return Color(0.34, 0.68, 0.34)
		"tropical":
			return Color(0.10, 0.58, 0.22)
		"arid":
			return Color(0.78, 0.55, 0.22)
		_:
			return Color(0.50, 0.50, 0.50)


func _update_overlay() -> void:
	var cell = Game.world_state.get_cell(selected_cell_id)
	if cell == null:
		info_label.text = "No cell selected."
	else:
		info_label.text = _join_lines([
			"Selected: %s" % cell.id,
			"Owner: %s" % _owner_label(cell.owner_id),
			"Terrain: %s" % cell.terrain.capitalize(),
			"Biome: %s" % str(cell.biome).capitalize(),
			"Climate: %s" % str(cell.climate).capitalize(),
			"Elevation: %.2f  Moisture: %.2f  Temp: %.2f" % [float(cell.elevation), float(cell.moisture), float(cell.temperature)],
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
	if world_refresh_running:
		return
	selected_cell_id = ""
	zooming = false
	camera_yaw = 0.0
	camera_pitch = -0.22
	_set_camera_distance(CAMERA_DEFAULT_DISTANCE)
	call_deferred("_new_campaign_with_loading")


func _new_campaign_with_loading() -> void:
	if world_refresh_running:
		return

	world_refresh_running = true
	_show_world_loading("Creating new world...", 0.02)
	await get_tree().process_frame
	await _create_world_with_loading(0, 24, 12, "Creating new world")
	_hide_world_loading()
	world_refresh_running = false


func _on_save_pressed() -> void:
	Game.save_campaign()
	_update_overlay()


func _on_load_pressed() -> void:
	if world_refresh_running:
		return
	call_deferred("_load_campaign_with_loading")


func _load_campaign_with_loading() -> void:
	if world_refresh_running:
		return

	world_refresh_running = true
	_show_world_loading("Loading campaign save...", 0.05)
	await get_tree().process_frame
	suppress_world_refresh = true
	var loaded := Game.load_campaign()
	suppress_world_refresh = false
	if loaded:
		selected_cell_id = Game.current_cell_id
		_set_world_loading("Save loaded, rebuilding world map...", 0.20)
		await get_tree().process_frame
		await _refresh_world_with_loading("Loading saved world")
	else:
		_set_world_loading("No valid campaign save found.", 1.0)
		await get_tree().create_timer(0.35).timeout
	_hide_world_loading()
	world_refresh_running = false


func _on_debug_view_pressed() -> void:
	if world_refresh_running:
		return
	match debug_view_mode:
		"terrain":
			debug_view_mode = "climate"
		"climate":
			debug_view_mode = "noise"
		_:
			debug_view_mode = "terrain"
	debug_view_button.text = "View: %s" % debug_view_mode.capitalize()
	_clear_planet_texture_cache()
	call_deferred("_refresh_debug_view_with_loading")


func _refresh_debug_view_with_loading() -> void:
	if world_refresh_running:
		return

	world_refresh_running = true
	_show_world_loading("Switching to %s view..." % debug_view_mode.capitalize(), 0.04)
	await get_tree().process_frame
	await _refresh_world_with_loading("Switching to %s view" % debug_view_mode.capitalize())
	_hide_world_loading()
	world_refresh_running = false


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

	if Game.is_move_left_pressed():
		yaw_input -= 1.0
	if Game.is_move_right_pressed():
		yaw_input += 1.0
	if Game.is_move_forward_pressed():
		pitch_input -= 1.0
	if Game.is_move_back_pressed():
		pitch_input += 1.0

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
