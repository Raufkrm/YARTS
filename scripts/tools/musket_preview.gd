extends Node3D

const Drill = preload("res://scripts/tools/musket_viewer_drill.gd")
const HandgonneDrill = preload("res://scripts/tools/handgonne_viewer_drill.gd")
const ShotEffects = preload("res://scripts/effects/handgonne_shot_effects.gd")
const Prop = preload("res://scripts/props/firearm_prop.gd")
const Selector = preload("res://scripts/tools/preview_scene_selector.gd")
const MODES := ["Reload", "Carry", "Walk", "Jog", "Aim", "Fire", "Fit bayonet", "Remove bayonet", "Combat loop", "Move", "Prime only", "Load barrel", "Gallery", "Weapon", "Bayonets"]
const WEAPONS := ["matchlock_arquebus", "flintlock_musket", "caplock_musket", "early_handgonne"]
var loaded := false
var attachments := {}
var move_origin := {}
var effects: Node3D
var phase_row: HBoxContainer
var phase_signature := ""
var fire_button: Button
var gallery: Node3D
var gallery_lod := -1
var gallery_models: Array = []
var gallery_attachments: Array = []
var mechanism := ""
var weapon_index := 0
var weapon_picker: OptionButton
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
var distance := 5.4
var orbiting := false
var ui: CanvasLayer
var mode_picker: OptionButton
var female_button: CheckBox

func _ready() -> void:
	_build_stage()
	_build_ui()
	effects = ShotEffects.new(); add_child(effects)
	_replace_drill()
	if "--musket-capture" in OS.get_cmdline_user_args(): _capture.call_deferred()

func _replace_drill() -> void:
	if drill != null: drill.free()
	drill = HandgonneDrill.new() if weapon_index == 3 else Drill.new(); drill.female = female; drill.weapon_id = WEAPONS[weapon_index]; add_child(drill)
	drill.configure_attachment(bool(attachments.get(weapon_index,false)))
	drill.move_origin = move_origin
	drill.set_detail_level(lod)
	_update_pose()

func _change_weapon(index: int) -> void:
	weapon_index = index; loaded = false
	if (index == 3 and mode in ["Fit bayonet","Remove bayonet","Move"]) or (index != 3 and mode in ["Prime only","Load barrel"]): mode = "Carry"; elapsed = 0
	_replace_drill()
	elapsed = minf(elapsed,_duration()) if not _is_loop() else elapsed
	_update_pose()

func _is_loop() -> bool:
	return mode in ["Carry","Walk","Jog","Combat loop","Gallery","Weapon","Bayonets"]

func _duration() -> float:
	return 4.0 if mode in ["Gallery","Weapon","Bayonets"] else float(drill.durations[mode])

func _blocked() -> bool:
	return weapon_index == 0 and bool(attachments.get(weapon_index,false))

func _can_fire() -> bool:
	return loaded and mode == "Aim" and elapsed >= float(drill.durations.Aim) and not _blocked()

func _select_mode(next: String) -> void:
	if next in ["Fit bayonet","Remove bayonet"] and weapon_index == 3: return
	if next in ["Prime only","Load barrel"] and weapon_index != 3: return
	if next == "Fire":
		if not _can_fire(): _update_pose(); return
		mode = next; elapsed = drill.fire_start; playing = true
	elif next == "Aim" and (not loaded or _blocked()): _update_pose(); return
	elif next in ["Reload","Combat loop","Prime only","Load barrel"] and _blocked(): _update_pose(); return
	elif next == "Move":
		if mode == "Combat loop" and weapon_index != 3:
			var sequence = Drill.Combat.new(); sequence.load_from_dict(drill.sequence_snapshot); sequence.request_move()
			move_origin = sequence.to_dict(); drill.move_origin = move_origin
		elif mode in ["Aim","Fire"] and weapon_index != 3:
			var sequence = Drill.Combat.new(); sequence.mode = "aim"; sequence.request_move()
			move_origin = sequence.to_dict(); drill.move_origin = move_origin
		else: _select_mode("Carry"); return
		mode = next; elapsed = 0; playing = true
	else:
		mode = next; elapsed = 0; playing = true
		if next in ["Reload","Combat loop","Prime only","Load barrel"]: loaded = false
	_update_pose()

func _process(delta: float) -> void:
	if drill == null: return
	if playing:
		if mode == "Reload": loaded = false
		elapsed += delta * speed
		if mode == "Fire" and elapsed >= drill.release_time: loaded = false
		if not _is_loop() and elapsed >= _duration():
			elapsed = _duration(); playing = false
			if mode == "Reload": loaded = true
			elif mode == "Fire": mode = "Carry"; elapsed = 0
			elif mode in ["Fit bayonet","Remove bayonet"]:
				attachments[weapon_index] = mode == "Fit bayonet"
				drill.configure_attachment(attachments[weapon_index])
				mode = "Carry"; elapsed = 0
	_update_pose()
	if mode in ["Move","Prime only","Load barrel"] and drill.finished: playing = false

func _seek(value: float) -> void:
	elapsed = value; playing = false
	if mode == "Reload": loaded = elapsed >= _duration() and not _blocked()
	if mode == "Fire" and elapsed >= drill.release_time: loaded = false
	_update_pose()

func _restart() -> void:
	_select_mode("Reload" if mode == "Fire" else mode)

func _play_pause() -> void:
	if not _is_loop() and elapsed >= _duration(): _restart()
	else: playing = not playing

func _update_pose() -> void:
	var asset_mode := mode in ["Gallery","Weapon","Bayonets"]
	drill.visible = not asset_mode
	if asset_mode: _show_gallery()
	else:
		if gallery != null: gallery.hide()
		drill.show_pose(mode, elapsed)
	if effects != null:
		effects.clear(); effects.emitted_count = 0
		var age: float = drill.shot_age if not asset_mode else -1.0
		if age >= 0 and age < ShotEffects.LIFETIME:
			# Reconstruct the muzzle at the shot, so smoke stays in world space while lowering.
			if weapon_index == 3: drill.update_firing_pose(drill.release_time)
			else:
				var shot = Drill.Combat.new(); shot.mode = "fire"; shot.elapsed = 0.6; drill.update_combat_pose(shot)
			effects.emit_shot(drill.held_weapon.socket_world_position("muzzle_fx"),drill.held_weapon.socket_world_position("ignition_fx" if weapon_index == 3 else "cap_seat" if weapon_index == 2 else "pan_fx"),drill.held_weapon.global_basis.x,lod,age)
			effects.set_process(false)
			drill.show_pose(mode,elapsed)
	timeline.set_block_signals(true)
	timeline.max_value = _duration()
	timeline.set_value_no_signal(fposmod(elapsed,_duration()) if _is_loop() else elapsed)
	timeline.set_block_signals(false)
	play_button.text = "Pause" if playing else "Play"
	mode_picker.select(MODES.find(mode)); female_button.set_pressed_no_signal(female); weapon_picker.select(weapon_index)
	fire_button.disabled = not _can_fire()
	for index in range(MODES.size()):
		var label: String = MODES[index]
		var disabled := (label == "Fire" and not _can_fire()) or (label == "Aim" and (not loaded or _blocked()))
		disabled = disabled or (label in ["Fit bayonet","Remove bayonet"] and weapon_index == 3) or (label in ["Prime only","Load barrel"] and weapon_index != 3)
		disabled = disabled or (label in ["Reload","Combat loop"] and _blocked())
		mode_picker.set_item_disabled(index,disabled)
	_refresh_phases()
	var state: String = "Asset inspection" if asset_mode else drill.state_text
	if _blocked(): state = "Plug fitted · remove before loading/firing"
	elif mode in ["Carry","Walk","Jog"]: state = "Loaded" if loaded else "Empty · select Reload"
	elif _can_fire(): state = "Ready · press Fire"
	status.text = "%s  ·  %.2f s  ·  %s\nHandling preview only · right-drag to orbit · wheel to zoom · Space pauses · R restarts" % [mode if asset_mode else drill.current_phase,timeline.value,state]

func _refresh_phases() -> void:
	var signature := mode + str(weapon_index) + str(attachments)
	if signature == phase_signature: return
	phase_signature = signature
	for child in phase_row.get_children(): child.free()
	var labels: Array = []
	var starts: Array = []
	if mode in ["Gallery","Weapon","Bayonets"]:
		labels = ["Rest","Open lock","Ready lock","Fire lock","Draw rod","Bayonet on","Bayonet off"]
		starts = [0,1,2,3,4,5,6]
	elif mode == "Reload": labels = Array(drill.PHASE_NAMES); starts = drill.phase_starts()
	elif mode == "Prime only": labels = ["Recover","Prime","Carry"]; starts = [0,2,5]
	elif mode == "Load barrel": labels = ["Recover","Supplies","Powder","Shot","Draw rod","Ram","Return rod","Carry"]; starts = [0,2,2.8,6,9,12,17,20]
	elif mode == "Aim": labels = ["Raise","Aim"] if weapon_index == 3 else ["Recover","Raise","Aim"]; starts = [0,2] if weapon_index == 3 else [0,4,6]
	elif mode == "Fire": labels = ["Aim","Ignite","Recover"] if weapon_index == 3 else ["Aim","Fire","Lower","Shoulder"]; starts = [2,4.5,6] if weapon_index == 3 else [2,2.6,4,6]
	elif mode in ["Fit bayonet","Remove bayonet"]: labels = ["Start","Grip","Transfer","Finish"]; starts = [0,_duration()*0.3,_duration()*0.6,_duration()]
	else: labels = ["Start","Middle","End"]; starts = [0,_duration()*0.5,_duration()]
	for index in range(labels.size()):
		var button := Button.new(); button.text = labels[index]; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var at: float = starts[index]
		button.pressed.connect(func():
			if mode in ["Gallery","Weapon","Bayonets"]:
				if at >= 5: attachments[weapon_index] = at == 5; drill.configure_attachment(at == 5)
				else: mechanism = ["","Lock_Open","Lock_Ready","Lock_Fire","Ramrod_Draw"][int(at)]
				playing = false; _update_pose()
			else: _seek(at))
		phase_row.add_child(button)

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
	var target := Vector3(0,1.15,0.10)
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left",18); margin.add_theme_constant_override("margin_right",18); margin.add_theme_constant_override("margin_top",16); ui.add_child(margin)
	var panel := PanelContainer.new(); margin.add_child(panel)
	var column := VBoxContainer.new(); panel.add_child(column)
	var title := Label.new(); title.text = "FIREARMS  /  HANDLING DRILL"; title.add_theme_font_size_override("font_size",20); column.add_child(title)
	weapon_picker = OptionButton.new()
	for label in ["Matchlock", "Flintlock", "Caplock", "Handgonne"]: weapon_picker.add_item(label)
	weapon_picker.item_selected.connect(_change_weapon)
	title.add_theme_constant_override("outline_size",0)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); column.add_child(row)
	row.add_child(Selector.new())
	row.add_child(weapon_picker)
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
	play_button = Button.new(); play_button.text = "Pause"; play_button.pressed.connect(_play_pause)
	row.add_child(play_button)
	var restart := Button.new(); restart.text = "Restart"; restart.pressed.connect(_restart); row.add_child(restart)
	var speed_label := Label.new(); speed_label.text = "1.00×"; row.add_child(speed_label)
	var speed_slider := HSlider.new(); speed_slider.min_value = 0.25; speed_slider.max_value = 2; speed_slider.step = 0.05; speed_slider.value = 1; speed_slider.custom_minimum_size.x = 100
	speed_slider.value_changed.connect(func(value): speed = value; speed_label.text = "%.2f×" % value); row.add_child(speed_slider)
	var bottom := VBoxContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_left = 24; bottom.offset_right = -24; bottom.offset_top = -104; bottom.offset_bottom = -16; ui.add_child(bottom)
	phase_row = HBoxContainer.new(); bottom.add_child(phase_row)
	timeline = HSlider.new(); timeline.min_value = 0; timeline.max_value = 12; timeline.step = 0.01
	timeline.value_changed.connect(_seek); bottom.add_child(timeline)
	status = Label.new(); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bottom.add_child(status)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1.5, distance - 0.25); _camera_pose()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(8, distance + 0.25); _camera_pose()
	elif event is InputEventMouseMotion and orbiting:
		yaw -= event.relative.x * 0.007; pitch = clampf(pitch + event.relative.y * 0.007, -0.2, 1.3); _camera_pose()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _play_pause()
		elif event.keycode == KEY_R: _restart()

func _capture() -> void:
	playing = false
	DirAccess.make_dir_recursive_absolute("res://tmp/musket_viewer")
	for weapon in range(4):
		weapon_index = weapon
		for gender in [false,true]:
			female = gender; _replace_drill()
			var samples := []
			for t in drill.phase_starts(): samples.append(["Reload",t+0.5])
			samples.append_array([["Reload",drill.durations.Reload],["Walk",0.2],["Jog",0.4],["Aim",drill.durations.Aim],["Fire",drill.release_time+0.05],["Gallery",0],["Weapon",0],["Bayonets",0]])
			if weapon != 3: samples.append_array([["Fit bayonet",drill.durations["Fit bayonet"]*0.45],["Remove bayonet",drill.durations["Remove bayonet"]*0.45]])
			else: samples.append_array([["Prime only",3],["Load barrel",15]])
			for sample in samples:
				mode = sample[0]; elapsed = sample[1]; _update_pose()
				for view in ["front","side"]:
					yaw = 0.3 if view == "front" else -PI/2; _camera_pose()
					for frame in range(3): await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://tmp/musket_viewer/%d_%s_%s_%.2f_%s.png" % [weapon,"female" if female else "male",mode,elapsed,view])
	print("MUSKET_VIEWER_CAPTURE_COMPLETE")
	get_tree().quit()

func _show_gallery() -> void:
	if gallery == null or gallery_lod != lod:
		if gallery != null: gallery.free()
		gallery = Node3D.new(); add_child(gallery); gallery_lod = lod
		gallery_models.clear(); gallery_attachments.clear()
		for index in range(4):
			var prop := Prop.new(); prop.weapon_id = WEAPONS[index]; gallery.add_child(prop); prop.set_detail_level(lod)
			gallery_models.append(prop)
		for id in ["plug_bayonet","socket_bayonet"]:
			var asset = load("res://assets/models/weapons/firearms/%s_lod%d.glb" % [id,lod]).instantiate()
			gallery.add_child(asset); gallery_attachments.append(asset)
	gallery.show()
	for index in range(4):
		var prop = gallery_models[index]
		prop.visible = mode == "Gallery" or (mode == "Weapon" and index == weapon_index)
		prop.position = Vector3(-0.3,0.65+index*0.45,0) if mode == "Gallery" else Vector3(-0.3,1.15,0)
		prop.set_bayonet_attached(bool(attachments.get(index,false)))
		if not mechanism.is_empty(): prop.set_mechanism_pose(mechanism,1.0)
		elif not prop.pose_name.is_empty(): prop.pose_name = ""; prop.rebuild_visual()
	for index in range(2):
		gallery_attachments[index].visible = mode in ["Gallery","Bayonets"]
		gallery_attachments[index].position = Vector3(-0.7+index*1.2,0.28 if mode == "Gallery" else 1.15,0)
