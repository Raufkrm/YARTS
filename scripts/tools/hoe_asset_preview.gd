extends Node3D

const ASSETS := ["wooden_hoe", "copper_hoe", "iron_hoe"]
const LABELS := ["Wooden\nPrehistoric", "Copper\nClassical", "Iron\nMedieval - Early Modern"]
const PreviewSceneSelector = preload("res://scripts/tools/preview_scene_selector.gd")
var models: Array[Node3D] = []
var camera: Camera3D
var yaw := 0.20
var pitch := 0.35
var zoom := 2.0
var dragging := false
var lod_menu: OptionButton


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.07, .10, .115)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.74, .81, .86)
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
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.position.y = -.01
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.20, .255, .275)
	material.roughness = .95
	ground.material_override = material
	add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	for i in range(ASSETS.size()):
		var prop := load("res://scenes/props/%s.tscn" % ASSETS[i]).instantiate() as Node3D
		prop.position.x = (i-1)*.78
		add_child(prop)
		models.append(prop)
		var label := Label3D.new()
		label.text = LABELS[i]
		label.font_size = 32
		label.pixel_size = .0018
		label.position = Vector3(prop.position.x, -.075, .08)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)
	var layer := CanvasLayer.new()
	add_child(layer)
	var toolbar := VBoxContainer.new()
	toolbar.position = Vector2(16, 16)
	toolbar.add_theme_constant_override("separation", 8)
	layer.add_child(toolbar)
	toolbar.add_child(PreviewSceneSelector.new())
	lod_menu = OptionButton.new()
	lod_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lod_menu.add_item("Close detail")
	lod_menu.add_item("Gameplay detail")
	lod_menu.item_selected.connect(_set_lod)
	toolbar.add_child(lod_menu)
	_update_camera()
	if "--capture-hoes" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _set_lod(lod: int) -> void:
	for i in range(models.size()):
		var previous := models[i].get_node("Model")
		models[i].remove_child(previous)
		previous.queue_free()
		var replacement := load("res://assets/models/tools/hoes/%s_lod%d.glb" % [ASSETS[i], lod]).instantiate() as Node3D
		replacement.name = "Model"
		models[i].add_child(replacement)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), .65, 4.0)
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x*.006
		pitch = clampf(pitch + event.relative.y*.004, -.2, 1.2)
		_update_camera()


func _update_camera() -> void:
	var target := Vector3(0, .68, .10)
	camera.size = zoom
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*8.0
	camera.look_at(target)


func _capture() -> void:
	for lod in range(2):
		_set_lod(lod)
		lod_menu.select(lod)
		for frame in range(25):
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tmp/hoe_asset_review/godot_lod%d.png" % lod)
	print("HOE_PREVIEW_CAPTURE_COMPLETE")
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	get_tree().quit()
