extends Node3D

const Ore = preload("res://scripts/props/ore_prototype.gd")
const Selector = preload("res://scripts/tools/preview_scene_selector.gd")
const OUTPUT := "res://tmp/ore_prototype_review/"
const KINDS := Ore.KINDS
var models: Array[Node3D] = []
var labels: Array[Label3D] = []
var camera: Camera3D
var environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var focus_menu: OptionButton
var lod_menu: OptionButton
var shine_toggle: CheckBox
var night_toggle: CheckBox
var toolbar: VBoxContainer
var target := Vector3(0, 0.3, 0)
var distance := 32.0
var yaw := 0.2
var pitch := 0.65
var dragging := false
var failures: Array[String] = []


func _ready() -> void:
	_build_stage()
	for i in range(KINDS.size()):
		for variant in range(1, 4):
			var ore := Ore.new()
			ore.ore_kind = KINDS[i]
			ore.variant = variant
			ore.position = Vector3((i-3)*4.2, 0, (variant-2)*3.0)
			add_child(ore)
			models.append(ore)
			var label := Label3D.new()
			label.text = "%s %d" % [str(KINDS[i]).capitalize(), variant]
			label.position = ore.position + Vector3(0, 0.025, 1.15)
			label.font_size = 32
			label.pixel_size = 0.004
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			add_child(label)
			labels.append(label)
	_build_toolbar()
	_set_night(false)
	_update_camera()
	if "--capture-ores" in OS.get_cmdline_user_args(): _capture_review.call_deferred()


func _build_stage() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 2.0
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky_sorta_cell.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150, 150)
	ground.mesh = plane
	ground.position.y = -0.01
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.25, 0.215)
	material.roughness = 0.95
	ground.material_override = material
	add_child(ground)
	camera = Camera3D.new()
	camera.fov = 50
	camera.far = 300
	camera.current = true
	add_child(camera)


func _build_toolbar() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	toolbar = VBoxContainer.new()
	toolbar.position = Vector2(16, 16)
	toolbar.add_theme_constant_override("separation", 8)
	canvas.add_child(toolbar)
	toolbar.add_child(Selector.new())
	var row := HBoxContainer.new()
	toolbar.add_child(row)
	focus_menu = OptionButton.new()
	focus_menu.add_item("All ores")
	for kind in KINDS: focus_menu.add_item(str(kind).capitalize())
	focus_menu.item_selected.connect(_focus)
	row.add_child(focus_menu)
	lod_menu = OptionButton.new()
	for title in ["Close", "Gameplay", "Far"]: lod_menu.add_item(title)
	lod_menu.item_selected.connect(_set_detail)
	row.add_child(lod_menu)
	var lighting := HBoxContainer.new()
	toolbar.add_child(lighting)
	shine_toggle = CheckBox.new()
	shine_toggle.text = "Mineral shine"
	shine_toggle.button_pressed = true
	shine_toggle.toggled.connect(_set_shine)
	lighting.add_child(shine_toggle)
	night_toggle = CheckBox.new()
	night_toggle.text = "Night"
	night_toggle.toggled.connect(_set_night)
	lighting.add_child(night_toggle)


func _focus(index: int) -> void:
	target = Vector3((index-4)*4.2, 0.4, 0) if index > 0 else Vector3(0, 0.3, 0)
	distance = 9.0 if index > 0 else 32.0
	for i in range(models.size()):
		models[i].visible = index == 0 or models[i].ore_kind == KINDS[index-1]
		labels[i].visible = models[i].visible
	_update_camera()


func _set_detail(lod: int) -> void:
	for model in models: model.set_detail(lod)


func _solo_specimen(kind: String, variant: int = 2) -> void:
	for i in range(models.size()):
		models[i].visible = models[i].ore_kind == kind and models[i].variant == variant
		labels[i].visible = false


func _set_shine(enabled: bool) -> void:
	for model in models: model.set_shine(enabled)


func _set_night(night: bool) -> void:
	var direction := Vector3(-0.48, 0.68, -0.55).normalized()
	sun.look_at(-direction if not night else Vector3(0.4, -0.8, 0.3))
	sun.light_color = Color(1, 0.94, 0.84) if not night else Color(0.52, 0.65, 0.9)
	sun.light_energy = 1.65 if not night else 0.09
	environment.ambient_light_color = Color(0.59, 0.68, 0.8) if not night else Color(0.13, 0.18, 0.28)
	environment.ambient_light_energy = 0.44 if not night else 0.10
	sky_material.set_shader_parameter("sun_direction", direction if not night else -direction)
	sky_material.set_shader_parameter("sun_amount", 0.68 if not night else -0.68)
	sky_material.set_shader_parameter("day_factor", 1.0 if not night else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3.0, 45.0)
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, 0.15, 1.35)
		_update_camera()


func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(target)


func _settle() -> void:
	for frame in range(32): await RenderingServer.frame_post_draw


func _shot(name: String) -> Image:
	await _settle()
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUTPUT + name + ".png")
	return image


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _capture_review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await _shot("overview")
	for index in range(1, KINDS.size() + 1):
		focus_menu.select(index)
		_focus(index)
		await _shot(KINDS[index-1] + "_variants")
		# Inspect the middle specimen from both sides and above.
		for angle in [0.25, 2.4, 4.3]:
			_solo_specimen(KINDS[index-1])
			yaw = angle
			distance = 4.3
			pitch = 0.5
			_update_camera()
			await _shot("%s_angle_%d" % [KINDS[index-1], int(angle*10)])
	focus_menu.select(3)
	_focus(3)
	_solo_specimen("copper")
	distance = 4.3
	yaw = 0.65
	pitch = 0.55
	_update_camera()
	var shining := await _shot("copper_shine_on")
	var shine_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_set_shine(false)
	var matte := await _shot("copper_shine_off")
	_check(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) == shine_calls, "Mineral shine adds draw calls")
	var changed := 0
	var occupied := 0
	for y in range(shining.get_height()/4, shining.get_height()*3/4, 2):
		for x in range(shining.get_width()/4, shining.get_width()*3/4, 2):
			var a := shining.get_pixel(x, y)
			var b := matte.get_pixel(x, y)
			if Vector3(a.r-b.r, a.g-b.g, a.b-b.b).length() > 0.015: changed += 1
			if maxf(a.r, maxf(a.g, a.b)) - minf(a.r, minf(a.g, a.b)) > 0.08: occupied += 1
	_check(changed > 100, "Close-up mineral reflections are missing")
	_check(occupied > 100, "Ore preview render is blank")
	_set_shine(true)
	_set_night(true)
	var night := await _shot("copper_night")
	var day_sum := 0.0
	var night_sum := 0.0
	for y in range(300, mini(650, night.get_height()), 4):
		for x in range(400, mini(1000, night.get_width()), 4):
			day_sum += shining.get_pixel(x, y).get_luminance()
			night_sum += night.get_pixel(x, y).get_luminance()
	_check(night_sum < day_sum*0.45, "Ore reflection glows at night")
	_set_night(false)
	distance = 38
	_update_camera()
	var far_on := await _shot("shine_far_on")
	_set_shine(false)
	var far_off := await _shot("shine_far_off")
	var far_changes := 0
	for y in range(0, far_on.get_height(), 4):
		for x in range(0, far_on.get_width(), 4):
			if far_on.get_pixel(x, y) != far_off.get_pixel(x, y): far_changes += 1
	_check(far_changes < 10, "Close-up shine persists at far zoom")
	_set_shine(true)
	_focus(0)
	focus_menu.select(0)
	yaw = 0.2
	pitch = 0.65
	_update_camera()
	for lod in range(3):
		_set_detail(lod)
		lod_menu.select(lod)
		await _shot("lod%d" % lod)
	_set_detail(1)
	lod_menu.select(1)
	distance = 32
	pitch = 0.85
	_update_camera()
	await _shot("gameplay_distance")
	_check(find_children("*", "ReflectionProbe", true, false).is_empty(), "Unexpected live reflection probes")
	_check(not environment.ssr_enabled and not environment.glow_enabled and not environment.ssao_enabled, "Expensive reflection/postprocess enabled")
	print("ORE_RENDER_METRICS shine_pixels=", changed, " night_day_ratio=", night_sum / maxf(day_sum, 0.001),
		" far_shine_pixels=", far_changes, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("ORE_REVIEW_PASS" if failures.is_empty() else "ORE_REVIEW_FAIL " + str(failures))
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	get_tree().quit(0 if failures.is_empty() else 1)
