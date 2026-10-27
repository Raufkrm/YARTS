extends Node3D

const Drill = preload("res://scripts/tools/crossbow_human_drill.gd")
const Selector = preload("res://scripts/tools/preview_scene_selector.gd")
const MODES := ["Reload", "Carry", "Walk", "Jog", "Fire", "Aim"]
var loaded := false
var fire_button: Button
var drill: Node3D
var camera: Camera3D
var mode := "Reload"
var elapsed := 0.0
var speed := 1.0
var playing := true
var female := false
var lod := 0
var status: Label
var play_button: Button
var timeline: HSlider
var yaw := 0.50
var pitch := 0.10
var distance := 4.1
var orbiting := false
var ui: CanvasLayer
var mode_picker: OptionButton
var female_button: CheckBox

func _ready() -> void:
	_build_stage()
	_build_ui()
	_replace_drill()
	if "--crossbow-capture" in OS.get_cmdline_user_args(): _capture.call_deferred()

func _replace_drill() -> void:
	if drill != null: drill.free()
	drill = Drill.new(); drill.female = female; add_child(drill)
	drill.set_detail_level(lod)
	_update_pose()

func _process(delta: float) -> void:
	if drill == null: return
	if playing:
		elapsed += delta * speed
		if mode == "Reload": loaded = false
		if mode == "Fire" and elapsed >= Drill.FIRE_RELEASE: loaded = false
		if mode in ["Reload", "Fire", "Aim"] and elapsed >= float(drill.durations[mode]):
			elapsed = float(drill.durations[mode]); playing = false
			if mode == "Reload": loaded = true
			elif mode == "Fire": mode = "Carry"; elapsed = 0.0
	_update_pose()

func _can_fire() -> bool:
	return loaded and mode == "Aim" and elapsed >= 0.7

func _select_mode(next: String) -> void:
	if next == "Fire":
		if not _can_fire():
			_update_pose()
			return
		mode = "Fire"; elapsed = 0.7; playing = true
	elif next == "Aim" and not loaded:
		_update_pose()
		return
	else:
		mode = next; elapsed = 0.0; playing = true
		if next == "Reload": loaded = false
	_update_pose()

func _restart() -> void:
	_select_mode("Reload" if mode == "Fire" else mode)

func _update_pose() -> void:
	drill.show_pose(mode, elapsed)
	if mode in ["Carry", "Walk", "Jog"]:
		drill.crossbow.set_draw(1.0 if loaded else 0.0)
		drill.crossbow.bolt.visible = loaded
	timeline.set_block_signals(true)
	timeline.max_value = float(drill.durations[mode])
	timeline.set_value_no_signal(elapsed if mode in ["Reload", "Fire", "Aim"] else fposmod(elapsed, timeline.max_value))
	timeline.set_block_signals(false)
	play_button.text = "Pause" if playing else "Play"
	mode_picker.select(MODES.find(mode))
	female_button.set_pressed_no_signal(female)
	fire_button.disabled = not _can_fire()
	mode_picker.set_item_disabled(MODES.find("Fire"), not _can_fire())
	mode_picker.set_item_disabled(MODES.find("Aim"), not loaded)
	var bolts := "Bolt seated" if mode != "Reload" or elapsed >= 10.65 else "Bolt in hand" if elapsed >= 9.25 else "Track empty"
	if mode == "Fire": bolts = "Bolt seated" if elapsed < Drill.FIRE_RELEASE else "Track empty"
	if mode in ["Carry", "Walk", "Jog"]: bolts = "Bolt seated" if loaded else "Empty · select Reload"
	if mode == "Aim" and _can_fire(): bolts = "Ready · press Fire"
	status.text = "%s  ·  %.2f s  ·  %s\nHandling preview only · right-drag to orbit · wheel to zoom · Space pauses · R restarts" % [drill.current_phase, timeline.value, bolts]

func _scrub(value: float) -> void:
	elapsed = value; playing = false
	if mode == "Reload": loaded = elapsed >= 12.0
	elif mode == "Fire" and elapsed >= Drill.FIRE_RELEASE: loaded = false
	_update_pose()

func _build_stage() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("17202b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("bbc7ce"); env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env; add_child(env_node)
	for settings in [[Vector3(-45,-30,0), 1.3], [Vector3(-20,140,0), 0.55]]:
		var light := DirectionalLight3D.new(); light.rotation_degrees = settings[0]; light.light_energy = settings[1]
		light.shadow_enabled = settings[1] > 1; add_child(light)
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(20,20); ground.mesh = plane
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("283b47"); mat.roughness = 0.95; ground.material_override = mat; add_child(ground)
	camera = Camera3D.new(); camera.current = true; camera.fov = 38; add_child(camera); _camera_pose()

func _camera_pose() -> void:
	var target := Vector3(0,0.9,0.10)
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left",18); margin.add_theme_constant_override("margin_right",18); margin.add_theme_constant_override("margin_top",16); ui.add_child(margin)
	var panel := PanelContainer.new(); margin.add_child(panel)
	var column := VBoxContainer.new(); panel.add_child(column)
	var title := Label.new(); title.text = "CROSSBOW  /  WINDLASS DRILL"; title.add_theme_font_size_override("font_size",20); column.add_child(title)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); column.add_child(row)
	row.add_child(Selector.new())
	var modes := OptionButton.new()
	mode_picker = modes
	for label in MODES: modes.add_item(label)
	modes.item_selected.connect(func(index): _select_mode(MODES[index]))
	row.add_child(modes)
	fire_button = Button.new(); fire_button.text = "Fire"; fire_button.pressed.connect(func(): _select_mode("Fire")); row.add_child(fire_button)
	var gender := CheckBox.new(); gender.text = "Female"; gender.toggled.connect(func(value): female = value; _replace_drill()); row.add_child(gender)
	female_button = gender
	var details := OptionButton.new()
	for label in ["LOD0 · close", "LOD1 · gameplay", "LOD2 · far"]: details.add_item(label)
	details.item_selected.connect(func(index): lod = index; drill.set_detail_level(lod); _update_pose()); row.add_child(details)
	play_button = Button.new(); play_button.text = "Pause"; play_button.pressed.connect(func(): playing = not playing; if mode in ["Reload", "Fire"] and elapsed >= float(drill.durations[mode]): elapsed = 0)
	row.add_child(play_button)
	var restart := Button.new(); restart.text = "Restart"; restart.pressed.connect(_restart); row.add_child(restart)
	var speed_label := Label.new(); speed_label.text = "1.00×"; row.add_child(speed_label)
	var speed_slider := HSlider.new(); speed_slider.min_value = 0.25; speed_slider.max_value = 2; speed_slider.step = 0.05; speed_slider.value = 1; speed_slider.custom_minimum_size.x = 100
	speed_slider.value_changed.connect(func(value): speed = value; speed_label.text = "%.2f×" % value); row.add_child(speed_slider)
	var bottom := VBoxContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_left = 24; bottom.offset_right = -24; bottom.offset_top = -104; bottom.offset_bottom = -16; ui.add_child(bottom)
	var phases := HBoxContainer.new(); bottom.add_child(phases)
	for index in range(6):
		var button := Button.new(); button.text = Drill.PHASE_NAMES[index]; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): mode = "Reload"; loaded = false; modes.select(0); elapsed = Drill.PHASE_STARTS[index]; playing = false; _update_pose())
		phases.add_child(button)
	timeline = HSlider.new(); timeline.min_value = 0; timeline.max_value = 12; timeline.step = 0.01
	timeline.value_changed.connect(_scrub); bottom.add_child(timeline)
	status = Label.new(); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bottom.add_child(status)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1.5, distance - 0.25); _camera_pose()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(8, distance + 0.25); _camera_pose()
	elif event is InputEventMouseMotion and orbiting:
		yaw -= event.relative.x * 0.007; pitch = clampf(pitch + event.relative.y * 0.007, -0.2, 1.3); _camera_pose()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: playing = not playing
		elif event.keycode == KEY_R: _restart()

func _capture() -> void:
	playing = false
	DirAccess.make_dir_recursive_absolute("res://tmp/crossbow_preview")
	for gender in [false, true]:
		female = gender; _replace_drill()
		for sample in [["Reload",0.0],["Reload",1.0],["Reload",2.5],["Reload",4.4],["Reload",8.3],["Reload",10.0],["Reload",12.0],["Walk",0.2],["Jog",0.16],["Jog",0.40],["Fire",0.0],["Fire",0.7],["Fire",1.1],["Fire",1.15],["Fire",1.45],["Fire",1.7]]:
			mode = sample[0]; elapsed = sample[1]; _update_pose()
			for view in ["front", "side"]:
				yaw = 0.3 if view == "front" else -PI/2; _camera_pose()
				for frame in range(3): await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://tmp/crossbow_preview/%s_%s_%.2f_%s.png" % ["female" if female else "male", mode, elapsed, view])
	print("CROSSBOW_CAPTURE_COMPLETE")
	get_tree().quit()
