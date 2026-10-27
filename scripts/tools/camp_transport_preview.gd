extends Node3D

const PreviewSceneSelector = preload("res://scripts/tools/preview_scene_selector.gd")

var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var brown: Node3D
var white: Node3D
var horse_cart: Node3D
var hand_cart: Node3D
var fire: Node3D
var unlit: Node3D
var torch: Node3D
var unlit_torch: Node3D
var elapsed := 0.0
var moving := false
var orbit_yaw := 0.25
var orbit_pitch := 0.47
var view_size := 15.5
var view_target := Vector3(0.0, 0.9, 1.0)
var _dragging := false


func _ready() -> void:
	_build_stage()
	_add_prop("swept_thatch_roundhouse", Vector3(-5, 0, -1.5))
	_add_prop("hemp_ridge_tent", Vector3(1.0, 0, -1.5))
	horse_cart = _add_prop("horse_cart", Vector3(5.4, 0, -0.6))
	hand_cart = _add_prop("hand_cart", Vector3(1.2, 0, 4.2))
	brown = _add_prop("horse_brown", Vector3(5.4, 0, 2.2))
	brown.set_lod(0)
	white = _add_prop("horse_white", Vector3(8.1, 0, 1.8))
	white.set_lod(0)
	white.rotation.y = -0.2
	white.play_animation("Eating")
	horse_cart.set_pull_target(brown)
	fire = _add_prop("campfire", Vector3(-3.6, 0, 4.3))
	unlit = _add_prop("campfire_unlit", Vector3(-1.8, 0, 4.3))
	torch = _add_prop("hemp_torch", Vector3(-2.9, 0, 5.3))
	unlit_torch = _add_prop("hemp_torch_unlit", Vector3(-2.4, 0, 5.3))
	_build_toolbar()
	_update_camera()
	if "--capture-camp" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _add_prop(asset: String, at: Vector3) -> Node3D:
	var packed := load("res://scenes/props/%s.tscn" % asset) as PackedScene
	var model := packed.instantiate() as Node3D
	model.position = at
	add_child(model)
	return model


func _build_stage() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.085, 0.115, 0.135)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.85)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	ground.mesh = plane
	ground.position.y = -0.026
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.275, 0.28)
	mat.roughness = 0.96
	ground.material_override = mat
	add_child(ground)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 150.0
	add_child(camera)


func _build_toolbar() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.07, 0.078, 0.96)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	panel.add_child(toolbar)
	toolbar.add_child(PreviewSceneSelector.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	toolbar.add_child(row)
	var title := Label.new()
	title.text = "Camp & Transport"
	row.add_child(title)
	var views := OptionButton.new()
	for name in ["All models", "Fire & torch", "Horses", "Carts", "Roundhouse", "Hemp tent"]:
		views.add_item(name)
	views.item_selected.connect(_focus)
	row.add_child(views)
	var animations := OptionButton.new()
	for animation in ["Idle", "Walk", "Gallop", "Eating", "Idle_2", "Idle_Headlow", "Gallop_Jump", "Jump_toIdle", "Attack_Headbutt", "Attack_Kick", "Death", "Idle_HitReact_Left", "Idle_HitReact_Right"]:
		animations.add_item(animation)
	animations.item_selected.connect(func(index: int):
		brown.play_animation(animations.get_item_text(index))
		white.play_animation(animations.get_item_text(index)))
	row.add_child(animations)
	var lods := OptionButton.new()
	for label in ["Close", "Gameplay", "Far"]:
		lods.add_item(label)
	lods.item_selected.connect(func(index: int):
		brown.set_lod(index)
		white.set_lod(index))
	row.add_child(lods)
	var motion := CheckBox.new()
	motion.text = "Pull cart"
	motion.toggled.connect(func(enabled: bool):
		moving = enabled
		brown.play_animation("Walk" if enabled else "Idle"))
	row.add_child(motion)
	var flames := CheckBox.new()
	flames.text = "Fire"
	flames.button_pressed = true
	flames.toggled.connect(func(enabled: bool):
		fire.get_node("Fire").burning = enabled
		torch.get_node("Fire").burning = enabled)
	row.add_child(flames)
	var night := CheckBox.new()
	night.text = "Dusk"
	night.toggled.connect(_set_dusk)
	row.add_child(night)


func _process(delta: float) -> void:
	if moving:
		elapsed += delta
		brown.position.z = 2.2 + fmod(elapsed * 0.7, 3.5)
		hand_cart.position.z = 4.2 + fmod(elapsed * 0.4, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			view_size = clampf(view_size * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.5, 30.0)
			_update_camera()
	if event is InputEventMouseMotion and _dragging:
		orbit_yaw -= event.relative.x * 0.006
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.004, 0.10, 1.3)
		_update_camera()


func _focus(index: int) -> void:
	var targets := [Vector3(0, 0.9, 1), Vector3(-2.7, 0.6, 4.6), Vector3(6.8, 1.0, 2.2), Vector3(3.9, 0.8, 1.9), Vector3(-5, 1.6, -1.5), Vector3(1, 0.9, -1.5)]
	var sizes := [15.5, 3.3, 5.3, 8.0, 6.4, 5.0]
	view_target = targets[index]
	view_size = sizes[index]
	_update_camera()


func _update_camera() -> void:
	camera.size = view_size
	var direction := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch))
	camera.position = view_target + direction * 28.0
	camera.look_at(view_target)


func _set_dusk(enabled: bool) -> void:
	sun.light_energy = 0.12 if enabled else 1.25
	environment.ambient_light_energy = 0.23 if enabled else 0.65


func _capture() -> void:
	for i in range(40):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tmp/camp_transport_review/godot_overview.png")
	_focus(1)
	_set_dusk(true)
	for i in range(30):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tmp/camp_transport_review/godot_fire_a.png")
	for i in range(35):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tmp/camp_transport_review/godot_fire_b.png")
	_set_dusk(false)
	_focus(2)
	brown.play_animation("Walk")
	white.play_animation("Gallop")
	for i in range(30):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tmp/camp_transport_review/godot_horses_a.png")
	for i in range(30):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tmp/camp_transport_review/godot_horses_b.png")
	print("CAMP_PREVIEW_CAPTURE_COMPLETE")
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	get_tree().quit()
