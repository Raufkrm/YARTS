extends Node3D

const NAMES := ["wild_boar", "deer", "camel", "polar_bear", "penguin", "seagull", "crow", "sheep", "cow", "goat"]
const TITLES := ["Wild Boar", "Deer", "Camel", "Polar Bear", "Penguin", "Seagull", "Crow", "Sheep", "Cow", "Goat"]
const BIRDS := [5, 6]
const ANIMATED := [1, 8]
const PreviewSceneSelector = preload("res://scripts/tools/preview_scene_selector.gd")
@export_enum("All animals", "Ground animals", "Birds", "Polar animals", "Deer", "Livestock", "Cow") var initial_focus := 0
var models: Array[Node3D] = []
var labels: Array[Label3D] = []
var camera: Camera3D
var target := Vector3(0, 1.1, 0.3)
var yaw := 0.12
var pitch := 0.50
var zoom := 7.2
var dragging := false
var lod_menu: OptionButton
var focus_menu: OptionButton
var animation_menu: OptionButton


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.16, .21, .25)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.80, .87, .94)
	environment.ambient_light_energy = .65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.position.y = -.015
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.20, .27, .26)
	material.roughness = .95
	ground.material_override = material
	add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	var locations := [Vector3(-3,0,-3), Vector3(0,0,-3), Vector3(3,0,-3), Vector3(-3,0,2), Vector3(-.5,0,2), Vector3(1.5,1.3,3), Vector3(3.5,1.3,3), Vector3(-3,0,7), Vector3(0,0,7), Vector3(3,0,7)]
	for i in range(NAMES.size()):
		var model := load("res://scenes/props/%s.tscn" % NAMES[i]).instantiate() as Node3D
		model.position = locations[i]
		model.rotation.y = -.6
		add_child(model)
		model.set_lod(0)
		models.append(model)
		var label := Label3D.new()
		label.text = TITLES[i]
		label.font_size = 36
		label.pixel_size = .005
		label.position = locations[i] + Vector3(0, -.25 if i in BIRDS else .05, 1.3 if i >= 7 else .85)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		labels.append(label)
	var layer := CanvasLayer.new()
	add_child(layer)
	var toolbar := VBoxContainer.new()
	toolbar.position = Vector2(16,16)
	toolbar.add_theme_constant_override("separation", 8)
	layer.add_child(toolbar)
	toolbar.add_child(PreviewSceneSelector.new())
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	toolbar.add_child(controls)
	lod_menu = OptionButton.new()
	for text in ["Close detail", "Gameplay detail", "Far detail"]: lod_menu.add_item(text)
	lod_menu.item_selected.connect(_set_lod)
	controls.add_child(lod_menu)
	focus_menu = OptionButton.new()
	for text in ["All animals", "Ground animals", "Birds", "Polar animals", "Deer", "Livestock", "Cow"]: focus_menu.add_item(text)
	focus_menu.item_selected.connect(_focus)
	controls.add_child(focus_menu)
	var animation := OptionButton.new()
	animation_menu = animation
	for text in ["Idle", "Walk", "Gallop", "Eating"]: animation.add_item(text)
	animation.item_selected.connect(func(index: int):
		for i in ANIMATED: models[i].play_animation(animation.get_item_text(index)))
	controls.add_child(animation)
	var glide := CheckButton.new()
	glide.text = "Glide"
	glide.toggled.connect(func(value: bool):
		models[5].gliding = value
		models[6].gliding = value)
	controls.add_child(glide)
	_focus(initial_focus)
	if "--capture-wildlife" in OS.get_cmdline_user_args(): _capture.call_deferred()


func _set_lod(index: int) -> void:
	if lod_menu != null: lod_menu.select(index)
	for i in range(models.size()): models[i].set_lod(mini(index,1) if i in BIRDS else index)


func _focus(index: int) -> void:
	focus_menu.select(index)
	var visible_indices: Array = range(models.size())
	target = Vector3(0,1.1,1.7)
	zoom = 10.0
	match index:
		1: visible_indices = [0,1,2,3,4,7,8,9]
		2:
			visible_indices = BIRDS
			target = Vector3(2.5,1.3,3)
			zoom = 2.5
		3:
			visible_indices = [3,4]
			target = Vector3(-1.75,.8,2)
			zoom = 3.6
		4, 6:
			var animal_index := 1 if index == 4 else 8
			visible_indices = [animal_index]
			target = models[animal_index].position + Vector3(0,.9,0)
			zoom = 2.5
		5:
			visible_indices = [7,8,9]
			target = Vector3(0,.85,7)
			zoom = 5.0
	for i in range(models.size()):
		models[i].visible = i in visible_indices
		labels[i].visible = models[i].visible and index not in [4,6]
		labels[i].pixel_size = .005 * zoom / 7.2
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.0, 14.0)
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * .006
		pitch = clampf(pitch + event.relative.y * .004, -.1, 1.2)
		_update_camera()


func _update_camera() -> void:
	camera.size = zoom
	camera.position = target + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*16
	camera.look_at(target)


func _shot(filename: String) -> void:
	for frame in range(12): await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tmp/wildlife_review/" + filename + ".png")


func _capture() -> void:
	_focus(0)
	await _shot("godot_overview")
	for lod in range(3):
		_set_lod(lod)
		lod_menu.select(lod)
		_focus(1)
		focus_menu.select(1)
		await _shot("godot_ground_lod%d" % lod)
	_set_lod(0)
	_focus(2)
	focus_menu.select(2)
	for phase in [0.0, 0.3]:
		for i in [5,6]: models[i].material.set_shader_parameter("pose_time", phase)
		await _shot("godot_birds_" + str(phase))
	_set_lod(1)
	await _shot("godot_birds_far")
	_set_lod(0)
	_focus(3)
	focus_menu.select(3)
	await _shot("godot_polar")
	for lod in range(3):
		_set_lod(lod)
		_focus(5)
		await _shot("godot_livestock_lod%d" % lod)
	_set_lod(0)
	animation_menu.select(1)
	yaw = .4
	pitch = .2
	for i in ANIMATED:
		_focus(4 if i == 1 else 6)
		models[i].play_animation("Walk")
		for phase in [0.1,0.6]:
			models[i].animation_player.play("Walk", 0.0)
			models[i].animation_player.seek(models[i].animation_player.current_animation_length * phase, true)
			models[i].animation_player.advance(0.0)
			models[i].animation_player.pause()
			await _shot("godot_%s_walk_%s" % [NAMES[i], str(phase)])
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	print("WILDLIFE_CAPTURE_COMPLETE")
	get_tree().quit()
