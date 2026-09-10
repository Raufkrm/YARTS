extends Node3D

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const MODEL_HEIGHT := 2.8
const DEFAULT_CAMERA_DISTANCE := 7.0
const AnimationCatalog = preload("res://scripts/tools/unit_animation_catalog.gd")

var models: Array[Dictionary] = []
var animation_names: Array[String] = []
var filtered_animation_names: Array[String] = []
var model_root: Node3D
var model_container: Node3D
var animation_player: AnimationPlayer
var animation_players: Array[AnimationPlayer] = []
var camera_pivot: Node3D
var camera: Camera3D
var model_picker: OptionButton
var animation_list: ItemList
var animation_search: LineEdit
var status_label: Label
var current_label: Label
var speed_slider: HSlider
var speed_value_label: Label
var loop_check: CheckBox
var pause_button: Button
var orbit_yaw := 0.35
var orbit_pitch := -0.08
var camera_distance := DEFAULT_CAMERA_DISTANCE
var dragging := false
var library_status := ""


func _ready() -> void:
	_build_stage()
	_build_interface()
	models = AnimationCatalog.discover_human_models()
	_populate_models()
	if not models.is_empty():
		_load_model(0)
	else:
		status_label.text = "No human GLB models were found."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE or mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mouse_button.pressed
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(2.6, camera_distance - 0.55)
			_update_camera()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(18.0, camera_distance + 0.55)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		orbit_yaw -= motion.relative.x * 0.008
		orbit_pitch = clamp(orbit_pitch - motion.relative.y * 0.008, -1.1, 0.8)
		_update_camera()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)


func _build_stage() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("121820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9eb4c3")
	environment.ambient_light_energy = 0.5
	environment_node.environment = environment
	add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	key_light.light_color = Color("fff0d1")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(25.0, 145.0, 0.0)
	fill_light.light_color = Color("8ebee8")
	fill_light.light_energy = 0.42
	fill_light.shadow_enabled = false
	add_child(fill_light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18.0, 18.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("28333b")
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	add_child(floor)

	model_container = Node3D.new()
	model_container.name = "PreviewModel"
	add_child(model_container)

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0.0, MODEL_HEIGHT * 0.48, 0.0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 38.0
	camera_pivot.add_child(camera)
	_update_camera()


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 16.0
	top_bar.offset_top = 16.0
	top_bar.offset_right = -16.0
	top_bar.offset_bottom = 78.0
	top_bar.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(top_bar)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_row)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(84.0, 38.0)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	top_row.add_child(back_button)

	var model_label := Label.new()
	model_label.text = "Model"
	top_row.add_child(model_label)
	model_picker = OptionButton.new()
	model_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_picker.custom_minimum_size = Vector2(320.0, 38.0)
	model_picker.item_selected.connect(_load_model)
	top_row.add_child(model_picker)

	var reset_view_button := Button.new()
	reset_view_button.text = "Reset View"
	reset_view_button.custom_minimum_size = Vector2(110.0, 38.0)
	reset_view_button.pressed.connect(_reset_view)
	top_row.add_child(reset_view_button)

	var animation_panel := PanelContainer.new()
	animation_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	animation_panel.offset_left = 16.0
	animation_panel.offset_top = 92.0
	animation_panel.offset_right = 382.0
	animation_panel.offset_bottom = -16.0
	animation_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(animation_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	animation_panel.add_child(stack)

	var heading := Label.new()
	heading.text = "Animation Library"
	heading.add_theme_font_size_override("font_size", 22)
	stack.add_child(heading)

	animation_search = LineEdit.new()
	animation_search.placeholder_text = "Search animations"
	animation_search.clear_button_enabled = true
	animation_search.text_changed.connect(_filter_animations)
	stack.add_child(animation_search)

	animation_list = ItemList.new()
	animation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animation_list.custom_minimum_size = Vector2(334.0, 360.0)
	animation_list.select_mode = ItemList.SELECT_SINGLE
	animation_list.item_selected.connect(_on_animation_selected)
	animation_list.item_activated.connect(_on_animation_selected)
	stack.add_child(animation_list)

	current_label = Label.new()
	current_label.text = "No animation selected"
	current_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(current_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	stack.add_child(controls)
	var restart_button := Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(_restart_animation)
	controls.add_child(restart_button)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)
	loop_check = CheckBox.new()
	loop_check.text = "Loop"
	loop_check.button_pressed = true
	loop_check.toggled.connect(_on_loop_toggled)
	controls.add_child(loop_check)

	var speed_row := HBoxContainer.new()
	stack.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "Speed"
	speed_row.add_child(speed_label)
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.1
	speed_slider.max_value = 2.5
	speed_slider.step = 0.05
	speed_slider.value = 1.0
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(speed_slider)
	speed_value_label = Label.new()
	speed_value_label.text = "1.00x"
	speed_value_label.custom_minimum_size.x = 52.0
	speed_row.add_child(speed_value_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("9fb5c0"))
	stack.add_child(status_label)

	var input_hint := Label.new()
	input_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	input_hint.position = Vector2(-292.0, -46.0)
	input_hint.size = Vector2(276.0, 30.0)
	input_hint.text = "Middle/right drag: orbit   Wheel: zoom"
	input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_hint.add_theme_color_override("font_color", Color("9fb5c0"))
	root.add_child(input_hint)


func _populate_models() -> void:
	model_picker.clear()
	for model in models:
		model_picker.add_item(str(model.label))


func _load_model(index: int) -> void:
	if index < 0 or index >= models.size():
		return
	if model_root != null and is_instance_valid(model_root):
		model_root.free()
	animation_player = null
	animation_players.clear()
	animation_names.clear()
	filtered_animation_names.clear()
	animation_list.clear()
	current_label.text = "No animation selected"
	var model_data := models[index]
	if str(model_data.get("type", "single")) == "pair":
		_load_model_pair(model_data)
		return
	var packed_scene = load(str(model_data.path))
	if not packed_scene is PackedScene:
		status_label.text = "Could not load %s." % str(model_data.path)
		return
	model_root = (packed_scene as PackedScene).instantiate() as Node3D
	if model_root == null:
		status_label.text = "The selected resource is not a 3D model."
		return
	model_container.add_child(model_root)
	_fit_model_to_height(model_root, MODEL_HEIGHT)

	var result: Dictionary = AnimationCatalog.build_library(model_root)
	library_status = str(result.status)
	status_label.text = library_status
	animation_names.assign(result.names)
	if result.library != null:
		animation_player = _attach_animation_player(model_root, result.library, "PreviewAnimationPlayer")
		animation_players.append(animation_player)
	_filter_animations(animation_search.text)
	_play_first_idle()


func _load_model_pair(model_data: Dictionary) -> void:
	model_root = Node3D.new()
	model_root.name = "BaseLowPolySourcePair"
	model_container.add_child(model_root)
	var paths: Array = model_data.get("paths", [])
	var figure_labels: Array = model_data.get("figure_labels", [])
	var pair_offsets := [-1.15, 1.15]
	var common_names: Array[String] = []
	var statuses: Array[String] = []
	for figure_index in range(min(paths.size(), pair_offsets.size())):
		var packed_scene = load(str(paths[figure_index]))
		if not packed_scene is PackedScene:
			statuses.append("%s missing" % str(paths[figure_index]).get_file())
			continue
		var figure_root := (packed_scene as PackedScene).instantiate() as Node3D
		if figure_root == null:
			continue
		model_root.add_child(figure_root)
		_fit_model_to_height(figure_root, MODEL_HEIGHT)
		figure_root.position.x = pair_offsets[figure_index]
		_add_figure_label(
			str(figure_labels[figure_index]) if figure_index < figure_labels.size() else "Figure %d" % (figure_index + 1),
			pair_offsets[figure_index]
		)
		var result: Dictionary = AnimationCatalog.build_library(figure_root)
		statuses.append(str(result.status))
		if result.library == null:
			continue
		var player := _attach_animation_player(figure_root, result.library, "PreviewAnimationPlayer%d" % figure_index)
		animation_players.append(player)
		var figure_names: Array[String] = []
		figure_names.assign(result.names)
		if common_names.is_empty():
			common_names = figure_names.duplicate()
		else:
			for name_index in range(common_names.size() - 1, -1, -1):
				if not figure_names.has(common_names[name_index]):
					common_names.remove_at(name_index)
	animation_player = animation_players[0] if not animation_players.is_empty() else null
	animation_names = common_names
	library_status = "Paired source preview: %d synchronized animations. %s" % [
		animation_names.size(),
		" ".join(statuses),
	]
	_filter_animations(animation_search.text)
	_play_first_idle()


func _attach_animation_player(target_root: Node3D, library: AnimationLibrary, player_name: String) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = player_name
	player.root_node = NodePath("..")
	target_root.add_child(player)
	player.add_animation_library("", library)
	return player


func _add_figure_label(label_text: String, x_position: float) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(x_position, 3.15, 0.0)
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color("d7e8ee")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	model_root.add_child(label)


func _filter_animations(query: String) -> void:
	filtered_animation_names.clear()
	animation_list.clear()
	var normalized_query := query.strip_edges().to_lower()
	for animation_name in animation_names:
		if normalized_query.is_empty() or animation_name.to_lower().find(normalized_query) >= 0:
			filtered_animation_names.append(animation_name)
			animation_list.add_item(animation_name)
	status_label.text = "%s\n%d of %d animations shown." % [library_status, filtered_animation_names.size(), animation_names.size()]


func _on_animation_selected(index: int) -> void:
	if index < 0 or index >= filtered_animation_names.size() or animation_player == null:
		return
	_play_animation(filtered_animation_names[index])


func _play_animation(animation_name: String) -> void:
	if animation_players.is_empty():
		return
	for player in animation_players:
		if not player.has_animation(animation_name):
			continue
		var animation := player.get_animation(animation_name)
		animation.loop_mode = Animation.LOOP_LINEAR if loop_check.button_pressed else Animation.LOOP_NONE
		player.speed_scale = speed_slider.value
		player.play(animation_name, 0.15)
	pause_button.text = "Pause"
	current_label.text = animation_name


func _play_first_idle() -> void:
	for animation_name in animation_names:
		if animation_name.to_lower() == "idle" or animation_name.to_lower().ends_with(" idle"):
			_play_animation(animation_name)
			var visible_index := filtered_animation_names.find(animation_name)
			if visible_index >= 0:
				animation_list.select(visible_index)
				animation_list.ensure_current_is_visible()
			return
	if not animation_names.is_empty():
		_play_animation(animation_names[0])


func _restart_animation() -> void:
	if animation_players.is_empty():
		return
	for player in animation_players:
		var current := str(player.current_animation)
		if not current.is_empty():
			player.play(current, 0.0)


func _toggle_pause() -> void:
	if animation_players.is_empty():
		return
	var should_pause := false
	for player in animation_players:
		if player.is_playing():
			should_pause = true
			break
	if should_pause:
		for player in animation_players:
			player.pause()
		pause_button.text = "Resume"
	else:
		for player in animation_players:
			player.play()
		pause_button.text = "Pause"


func _on_loop_toggled(enabled: bool) -> void:
	for player in animation_players:
		var current := str(player.current_animation)
		if not current.is_empty() and player.has_animation(current):
			player.get_animation(current).loop_mode = Animation.LOOP_LINEAR if enabled else Animation.LOOP_NONE


func _on_speed_changed(value: float) -> void:
	speed_value_label.text = "%.2fx" % value
	for player in animation_players:
		player.speed_scale = value


func _reset_view() -> void:
	orbit_yaw = 0.35
	orbit_pitch = -0.08
	camera_distance = DEFAULT_CAMERA_DISTANCE
	_update_camera()


func _update_camera() -> void:
	if camera_pivot == null or camera == null:
		return
	camera_pivot.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, camera_distance)
	camera.look_at(camera_pivot.global_position, Vector3.UP)


func _fit_model_to_height(model: Node3D, target_height: float) -> void:
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	var bounds := _combined_local_bounds(model)
	if not bool(bounds.valid):
		return
	var minimum := bounds.min as Vector3
	var maximum := bounds.max as Vector3
	var scale_value: float = target_height / max(maximum.y - minimum.y, 0.001)
	model.scale = Vector3.ONE * scale_value
	model.position.y = -minimum.y * scale_value


func _combined_local_bounds(root: Node3D) -> Dictionary:
	var bounds := {"valid": false, "min": Vector3.ONE * 1.0e20, "max": Vector3.ONE * -1.0e20}
	_accumulate_bounds(root, root, bounds)
	return bounds


func _accumulate_bounds(root: Node3D, node: Node, bounds: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var to_root := root.global_transform.affine_inverse() * mesh_instance.global_transform
			var aabb := mesh_instance.get_aabb()
			for endpoint_index in range(8):
				var point := to_root * aabb.get_endpoint(endpoint_index)
				bounds.min = (bounds.min as Vector3).min(point)
				bounds.max = (bounds.max as Vector3).max(point)
				bounds.valid = true
	for child in node.get_children():
		_accumulate_bounds(root, child, bounds)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.05, 0.94)
	style.border_color = Color(0.20, 0.34, 0.40, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
