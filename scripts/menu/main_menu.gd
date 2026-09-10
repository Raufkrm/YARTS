extends Node3D

const WORLD_SCENE := "res://scenes/world/world_map.tscn"
const ANIMATION_TESTER_SCENE := "res://scenes/tools/animation_tester.tscn"
const CONTROL_TESTER_SCENE := "res://scenes/tools/control_tester.tscn"


func _ready() -> void:
	_build_environment()
	_build_interface()


func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("07111c")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("7693ac")
	environment_resource.ambient_light_energy = 0.24
	environment.environment = environment_resource
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	light.light_color = Color("fff1d0")
	light.light_energy = 1.0
	light.shadow_enabled = false
	add_child(light)

	var globe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.5
	sphere.height = 5.0
	sphere.radial_segments = 32
	sphere.rings = 16
	globe.mesh = sphere
	globe.position = Vector3(4.4, -0.15, -6.0)
	var globe_material := StandardMaterial3D.new()
	globe_material.albedo_color = Color("183e59")
	globe_material.metallic = 0.08
	globe_material.roughness = 0.72
	globe.material_override = globe_material
	add_child(globe)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 8.5)
	camera.current = true
	add_child(camera)

	var rotation_tween := create_tween().set_loops()
	rotation_tween.tween_property(globe, "rotation:y", TAU, 42.0).from(0.0)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.027, 0.043, 0.38)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(78.0, -176.0)
	panel.custom_minimum_size = Vector2(340.0, 352.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	canvas.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "YARTS"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("e9f2f5"))
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Yet Another Real-Time Strategy"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("91a9b6"))
	stack.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24.0
	stack.add_child(spacer)

	stack.add_child(_menu_button("Play", _on_play_pressed))
	stack.add_child(_menu_button("Control Tester", _on_control_tester_pressed))
	stack.add_child(_menu_button("Animation Tester", _on_animation_tester_pressed))
	stack.add_child(_menu_button("Quit", _on_quit_pressed))


func _menu_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.048, 0.068, 0.94)
	style.border_color = Color(0.25, 0.43, 0.52, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	return style


func _on_play_pressed() -> void:
	Game.begin_campaign_start()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_animation_tester_pressed() -> void:
	get_tree().change_scene_to_file(ANIMATION_TESTER_SCENE)


func _on_control_tester_pressed() -> void:
	get_tree().change_scene_to_file(CONTROL_TESTER_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
