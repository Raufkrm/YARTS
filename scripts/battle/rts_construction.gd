extends RefCounted

const Catalog = preload("res://scripts/data/building_catalog.gd")
const Building = preload("res://scripts/data/rts_building_data.gd")
const VisualFactory = preload("res://scripts/battle/rts_entity_visual_factory.gd")
const UnitManager = preload("res://scripts/managers/unit_manager.gd")
const Outline = preload("res://scripts/battle/rts_building_outline.gd")
const RECRUIT_COST := {"food": 10}
const PERIMETER_OFFSET := 6.0
const WORKER_SPACING := 5.0
const BUILD_REACH := 8.0
var host
var navigation
var visuals: Dictionary = {}
var jobs: Dictionary = {}
var selected_id := ""
var preview_type := ""
var preview: Node3D
var preview_position := Vector3.ZERO
var preview_rotation := 0.0
var preview_reason := ""
var preview_check_elapsed := 0.0
var panel: PanelContainer
var title: Label
var details: Label
var options: VBoxContainer
var actions: HBoxContainer
var recruit_button: Button
var cancel_button: Button
var elapsed := 0.0
var message := "Select a person to build."

func configure(scene, nav) -> void:
	host = scene
	navigation = nav
	# Cell.resources is the spendable ledger. Historical per-building amounts
	# were mirrors already included in it, so never add them a second time.
	for building in host.battle_buildings:
		building.stored_resources.clear()
		navigation.add_building(building)
		refresh_visual(building)
	var restored_jobs := {}
	for id in host.cell.rts_state.get("construction_jobs", {}):
		var building = host._building_by_id(str(host.cell.rts_state.construction_jobs[id]))
		var actor = host.unit_actors_by_id.get(str(id))
		if actor != null and building != null and not building.completed:
			if not restored_jobs.has(building.id): restored_jobs[building.id] = []
			restored_jobs[building.id].append(id)
	for building_id in restored_jobs:
		assign(host._building_by_id(building_id), restored_jobs[building_id])
	_build_panel()

func founding_state() -> String:
	return str(host.cell.rts_state.get("founding_allowance", "legacy"))

func available(resource: String, allow_founding: bool = false) -> int:
	var reserved := 0
	if not allow_founding and founding_state() == "available":
		reserved = int(Catalog.DEFINITIONS.town_center.cost.get(resource, 0))
	return maxi(0, int(host.cell.resources.get(resource, 0)) - reserved)

func can_pay(cost: Dictionary, allow_founding: bool = false) -> bool:
	for resource in cost:
		if available(resource, allow_founding) < int(cost[resource]): return false
	return true

func pay(cost: Dictionary, allow_founding: bool = false) -> bool:
	if not can_pay(cost, allow_founding): return false
	for resource in cost: host.cell.resources[resource] = int(host.cell.resources.get(resource, 0)) - int(cost[resource])
	return true

func refund(cost: Dictionary, fraction: float = 1.0) -> void:
	for resource in cost:
		host.cell.resources[resource] = int(host.cell.resources.get(resource, 0)) + floori(int(cost[resource]) * fraction)

func remaining_storage() -> int:
	var capacity := 0
	for building in host.battle_buildings:
		if building.faction_id == "player" and building.can_store_resources(): capacity += building.storage_capacity
	var used := 0
	for amount in host.cell.resources.values(): used += int(amount)
	return maxi(0, capacity - used)

func builders() -> Array:
	var result := []
	for id in host._valid_selected_unit_ids():
		var actor = host.unit_actors_by_id.get(id)
		if actor != null and actor.unit_data.is_alive() and actor.faction_id == "player" and actor.unit_data.can_construct(): result.append(id)
	return result

func placement_reason(type_id: String, position: Vector3, rotation: float, check_access: bool = true) -> String:
	if not Catalog.DEFINITIONS.has(type_id): return "Unknown building."
	var size: Vector3 = Catalog.DEFINITIONS[type_id].size
	var low := INF
	var high := -INF
	# Sample the whole rotated footprint, not only its centre/corners.
	var nx := ceili(size.x / 3.0)
	var nz := ceili(size.z / 3.0)
	for x in range(nx + 1):
		for z in range(nz + 1):
			var p := position + Vector3(lerpf(-size.x * 0.5, size.x * 0.5, float(x) / nx), 0, lerpf(-size.z * 0.5, size.z * 0.5, float(z) / nz)).rotated(Vector3.UP, rotation)
			if not navigation.clear(p, 3.0): return "Footprint blocked by water, steep ground, resources or structures."
			var y: float = navigation.ground(p).y
			low = minf(low, y)
			high = maxf(high, y)
	if high - low > 1.5: return "Choose flatter ground; construction does not reshape terrain."
	# Keep at least one usable edge on existing buildings, regardless of facing.
	for building in host.battle_buildings:
		var accessible := false
		for point in building.perimeter_positions(position):
			var local: Vector3 = (point - position).rotated(Vector3.UP, -rotation)
			if absf(local.x) < size.x * 0.5 + 2 and absf(local.z) < size.z * 0.5 + 2: continue
			if navigation.clear(point):
				accessible = true
				break
		if not accessible: return "This blocks all access to another building."
	for actor in host.unit_actors_by_id.values():
		var local: Vector3 = (actor.position - position).rotated(Vector3.UP, -rotation)
		if absf(local.x) < size.x * 0.5 + 2 and absf(local.z) < size.z * 0.5 + 2: return "Move people out of the footprint."
	if host.wildlife != null:
		for animal in host.wildlife.animals.values():
			if animal.health <= 0: continue
			var local: Vector3 = (animal.position - position).rotated(Vector3.UP, -rotation)
			if absf(local.x) < size.x * 0.5 + 4 and absf(local.z) < size.z * 0.5 + 4: return "An animal is inside the footprint."
	if check_access:
		var site := Building.new()
		site.size = size
		site.position = position
		site.rotation_y = rotation
		var reachable := false
		for id in builders():
			if not _builder_target(site, host.unit_actors_by_id[id]).is_empty():
				reachable = true
				break
		if not reachable: return "Select a builder who can reach the building perimeter."
	return ""

func place(type_id: String, position: Vector3, rotation: float = 0.0):
	message = placement_reason(type_id, position, rotation)
	if not message.is_empty(): return null
	var entry: Dictionary = Catalog.DEFINITIONS[type_id]
	var founding := type_id == "town_center" and founding_state() == "available"
	if not pay(entry.cost, founding):
		message = "Insufficient supplies. The founding 40 wood / 10 stone is reserved for the Hall."
		return null
	var building := Building.new()
	var sequence := int(host.cell.rts_state.get("building_sequence", 0)) + 1
	host.cell.rts_state["building_sequence"] = sequence
	building.id = "%s_building_%d" % [host.cell.id, sequence]
	building.apply_definition(type_id)
	building.position = navigation.ground(position)
	building.rotation_y = rotation
	building.build_progress = 0.0
	building.completed = false
	building.founding_site = founding
	building.reserved_cost = entry.cost.duplicate(true)
	if founding: host.cell.rts_state["founding_allowance"] = "reserved"
	host.battle_buildings.append(building)
	navigation.add_building(building)
	refresh_visual(building)
	assign(building, builders())
	selected_id = building.id
	message = "Construction started. People can work from any reachable side."
	host._refresh_overlay()
	return building

func assign(building, ids: Array, jog_order: bool = false) -> void:
	if building.completed or building.faction_id != "player": return
	for index in range(ids.size()):
		var id = ids[index]
		var actor = host.unit_actors_by_id.get(id)
		if actor == null or not actor.unit_data.is_alive() or not actor.unit_data.can_construct() or actor.faction_id != "player": continue
		if jobs.has(id) and jobs[id].building == building.id and jobs[id].revision == actor.action_revision:
			if jog_order: host._sprint_task_approach(actor)
			continue
		var chosen := _builder_target(building, actor)
		if chosen.is_empty(): continue
		var target: Vector3 = chosen.position
		actor.stop()
		if actor.position.distance_to(target) > 0.1:
			actor.issue_move_order(host._make_unit_move_order(target, false), false)
		jobs[id] = {"building": building.id, "revision": actor.action_revision, "target": target}
		if actor.has_move_order(): actor.play_animation(host._first_available_unit_animation(host.UNIT_WALK_ANIMATION_CANDIDATES))
		if jog_order: host._sprint_task_approach(actor)

# Project onto each side as well as sampling the full perimeter. This keeps a
# nearby builder on their own side and provides alternatives around obstructions.
func _perimeter_points(building, near: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = building.perimeter_positions(near, PERIMETER_OFFSET, WORKER_SPACING)
	for index in range(points.size()): points[index] = navigation.ground(points[index])
	return points

func _within_build_reach(building, point: Vector3) -> bool:
	return building.edge_distance(point) <= BUILD_REACH

func _space_available(point: Vector3, worker_id: String = "") -> bool:
	if not host._unit_position_available(point, worker_id): return false
	for id in jobs:
		if id == worker_id: continue
		var actor = host.unit_actors_by_id.get(id)
		if actor == null or not actor.unit_data.is_alive() or actor.action_revision != jobs[id].revision: continue
		var target: Vector3 = jobs[id].target
		if Vector2(target.x - point.x, target.z - point.z).length() < WORKER_SPACING: return false
	return true

func _builder_target(building, actor) -> Dictionary:
	var candidates := _perimeter_points(building, actor.position)
	# Someone already close enough can kneel where they stand.
	if _within_build_reach(building, actor.position): candidates.push_front(actor.position)
	for point in candidates:
		if not navigation.clear(point) or not _space_available(point, actor.unit_id): continue
		if not navigation.route(actor.position, point).is_empty(): return {"position": point}
	return {}

func cancel(building) -> void:
	if building == null or building.completed or building.faction_id != "player": return
	refund(building.reserved_cost, 1.0 if building.founding_site else 1.0 - building.build_progress)
	if building.founding_site: host.cell.rts_state["founding_allowance"] = "available"
	for id in jobs.keys():
		if jobs[id].building == building.id:
			var actor = host.unit_actors_by_id.get(id)
			if actor != null: actor.stop()
			jobs.erase(id)
	navigation.remove_obstacle(building.id)
	if visuals.has(building.id):
		visuals[building.id].queue_free()
		visuals.erase(building.id)
	host.battle_buildings.erase(building)
	selected_id = ""
	message = "Site cancelled; unused materials returned."
	host._refresh_overlay()

func recruit_position(building) -> Dictionary:
	for candidate in _perimeter_points(building, building.entrance_position()):
		if navigation.clear(candidate) and _space_available(candidate): return {"position": candidate}
	return {}

func recruit(building) -> bool:
	if building == null or not building.completed or not building.can_train_population or building.faction_id != "player": return false
	var capacity := 0
	for home in host.battle_buildings:
		if home.completed and home.faction_id == "player": capacity += home.housing
	var population := 0
	for person in host.battle_units:
		if person.is_alive(): population += 1
	if population >= capacity:
		message = "Build more housing before recruiting."
		return false
	var chosen := recruit_position(building)
	if chosen.is_empty() or not pay(RECRUIT_COST):
		message = "Recruiting needs 10 food and a clear spot around the building."
		return false
	var position: Vector3 = chosen.position
	var sequence := int(host.cell.rts_state.get("recruit_sequence", 0)) + 1
	host.cell.rts_state["recruit_sequence"] = sequence
	var manager := UnitManager.new()
	var person = manager.create_unit("%s_recruit_%d" % [host.cell.id, sequence], "player", "flint_axe", position)
	manager.free()
	host.battle_units.append(person)
	host._spawn_unit_from_data(person)
	host.unit_actors_by_id[person.id].navigation = navigation
	message = "A new worker has joined the settlement."
	host._refresh_overlay()
	return true

func update(delta: float) -> void:
	for id in jobs.keys():
		if not jobs.has(id): continue
		var job: Dictionary = jobs[id]
		var actor = host.unit_actors_by_id.get(id)
		var building = host._building_by_id(str(job.building))
		if actor == null or building == null or not actor.unit_data.is_alive() or actor.action_revision != job.revision or building.completed:
			if actor != null and actor.kneeling_context == "build:" + str(job.building): actor.finish_kneeling_work()
			jobs.erase(id)
			continue
		var target: Vector3 = job.target
		if actor.has_move_order(): continue
		if Vector2(actor.position.x - target.x, actor.position.z - target.z).length() > 5.0: continue
		if not _within_build_reach(building, actor.position): continue
		if not navigation.clear(actor.position) or not navigation.segment_clear(actor.position, target): continue
		actor.clear_move_order()
		actor.face_position(building.position)
		var work_delta: float = actor.work_while_kneeling(delta, "build:" + building.id)
		building.build_progress = minf(1.0, building.build_progress + work_delta / building.work_required)
		if building.build_progress >= 1.0:
			building.completed = true
			building.reserved_cost.clear()
			if building.founding_site: host.cell.rts_state["founding_allowance"] = "spent"
			refresh_visual(building)
			message = "%s completed." % building.display_name
			if host.hud != null: host.hud.notify(message, building.position)
			host._refresh_overlay()
			for worker_id in jobs.keys():
				if jobs[worker_id].building == building.id:
					var worker = host.unit_actors_by_id.get(worker_id)
					if worker != null:
						worker.clear_move_order()
						worker.finish_kneeling_work()
					jobs.erase(worker_id)
	elapsed += delta
	if elapsed >= 0.25:
		elapsed = 0.0
		_refresh_panel()
		for building in host.battle_buildings:
			if not visuals.has(building.id): continue
			var root: Node3D = visuals[building.id]
			var distance: float = host.camera.global_position.distance_to(building.position) if host.camera != null else 300.0
			var lod := 0 if distance < 180 else (1 if distance < 650 else 2)
			if root.get_meta("lod", -1) != lod and Catalog.DEFINITIONS.has(building.type_id): refresh_visual(building, lod)
	if preview != null:
		preview_check_elapsed += delta
		var hit: Dictionary = host._screen_to_ground_position(host.get_viewport().get_mouse_position())
		if not hit.is_empty():
			preview_position = hit.position
			preview.position = preview_position
			preview.rotation.y = preview_rotation
			if preview_check_elapsed >= 0.12:
				preview_check_elapsed = 0.0
				preview_reason = placement_reason(preview_type, preview_position, preview_rotation)
				if preview_reason.is_empty() and not can_pay(Catalog.DEFINITIONS[preview_type].cost, preview_type == "town_center" and founding_state() == "available"):
					preview_reason = "Insufficient available supplies; founding materials are reserved for the Hall."
			Outline.tint(preview, Outline.BLUE if preview_reason.is_empty() else Color(1, 0.2, 0.15))

func refresh_visual(building, lod: int = 1) -> void:
	if visuals.has(building.id):
		var old: Node = visuals[building.id]
		old.get_parent().remove_child(old)
		old.queue_free()
	var root := make_model(building.type_id, lod)
	if root == null: root = VisualFactory.create_building_visual(building)
	root.name = "Building_%s" % building.id
	root.position = building.position
	root.rotation.y = building.rotation_y
	root.set_meta("lod", lod)
	root.set_meta("building_id", building.id)
	host.battle_entity_root.add_child(root)
	visuals[building.id] = root
	if not building.completed: Outline.apply(root)
	var label := Label3D.new()
	label.text = building.display_name if building.completed else "%s — Construction" % building.display_name
	label.position.y = building.size.y + 4.0
	label.pixel_size = 0.04
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	root.add_child(label)

func make_model(type_id: String, lod: int = 1) -> Node3D:
	if not Catalog.DEFINITIONS.has(type_id): return null
	var root := Node3D.new()
	var model := (load(Catalog.model_path(type_id, lod)) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * Catalog.SCALE * float(Catalog.DEFINITIONS[type_id].get("model_scale", 1.0))
	root.add_child(model)
	return root

func begin_preview(type_id: String) -> void:
	if builders().is_empty():
		message = "Select a worker or builder first."
		return
	end_preview()
	preview_type = type_id
	preview_check_elapsed = 1.0
	preview = make_model(type_id)
	host.terrain_root.add_child(preview)
	var footprint := MeshInstance3D.new()
	var box := BoxMesh.new()
	var size: Vector3 = Catalog.DEFINITIONS[type_id].size
	box.size = Vector3(size.x, 0.12, size.z)
	footprint.mesh = box
	preview.add_child(footprint)
	Outline.apply(preview)
	message = "LMB place • R rotate • Esc/RMB cancel"

func end_preview() -> void:
	if is_instance_valid(preview): preview.queue_free()
	preview = null
	preview_type = ""

func at_screen(point: Vector2):
	var hit: Dictionary = host._screen_to_ground_position(point)
	if hit.is_empty(): return null
	for building in host.battle_buildings:
		var local: Vector3 = (Vector3(hit.position) - building.position).rotated(Vector3.UP, -building.rotation_y)
		if absf(local.x) <= building.size.x * 0.5 and absf(local.z) <= building.size.z * 0.5: return building
	return null

func input(event: InputEvent, jog_order: bool = false) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if preview != null and event.keycode == KEY_R:
			preview_rotation += PI * 0.25
			return true
		if preview != null and event.keycode == KEY_ESCAPE:
			end_preview()
			return true
		if event.keycode == KEY_B and not builders().is_empty():
			begin_preview("town_center")
			return true
		if event.keycode == KEY_X:
			for id in host._valid_selected_unit_ids(): host.unit_actors_by_id[id].stop()
			return not host._valid_selected_unit_ids().is_empty()
	if event is InputEventMouseButton and event.pressed and not host._is_screen_point_in_hud(event.position):
		if preview != null:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				end_preview()
				return true
			if event.button_index == MOUSE_BUTTON_LEFT:
				var hit: Dictionary = host._screen_to_ground_position(event.position)
				if not hit.is_empty() and place(preview_type, hit.position, preview_rotation) != null: end_preview()
				return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var building = at_screen(event.position)
			if building != null and not building.completed and not builders().is_empty():
				assign(building, builders(), jog_order)
				selected_id = building.id
				return true
	return false

func select_at(point: Vector2) -> bool:
	var building = at_screen(point)
	if building != null:
		var human_hit: Dictionary = host._unit_at_screen(point)
		var base: Vector2 = host.camera.unproject_position(building.position)
		var center: Vector2 = host.camera.unproject_position(building.position + Vector3(0, building.size.y * 0.5, 0))
		var distance_sq := minf(point.distance_squared_to(base), point.distance_squared_to(center))
		if not human_hit.is_empty() and float(human_hit.screen_distance_sq) < distance_sq:
			building = null
	selected_id = building.id if building != null else ""
	if building != null:
		host._clear_unit_selection()
		_refresh_panel()
	return building != null

func _build_panel() -> void:
	if host.hud != null: return
	panel = PanelContainer.new()
	panel.name = "ConstructionPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -380
	panel.offset_right = -80
	panel.offset_top = 175
	panel.add_theme_stylebox_override("panel", host._hud_panel_style(0.94))
	host.order_sidebar_panel.get_parent().add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	title = Label.new()
	box.add_child(title)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 260
	box.add_child(details)
	options = VBoxContainer.new()
	box.add_child(options)
	for type_id in Catalog.DEFINITIONS:
		var item: Dictionary = Catalog.DEFINITIONS[type_id]
		var button: Button = host._make_compact_button("%s\n%s" % [item.name, Catalog.cost_label(item.cost)])
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(begin_preview.bind(type_id))
		options.add_child(button)
	actions = HBoxContainer.new()
	box.add_child(actions)
	cancel_button = host._make_compact_button("Cancel site")
	cancel_button.pressed.connect(func(): cancel(host._building_by_id(selected_id)))
	actions.add_child(cancel_button)
	recruit_button = host._make_compact_button("Recruit (10 food)")
	recruit_button.pressed.connect(func(): recruit(host._building_by_id(selected_id)))
	actions.add_child(recruit_button)
	_refresh_panel()

func _refresh_panel() -> void:
	if panel == null: return
	var building = host._building_by_id(selected_id)
	panel.visible = preview != null or building != null or not builders().is_empty()
	if host.wildlife != null and not host.wildlife.selected_id.is_empty() and preview == null: panel.visible = false
	options.visible = not builders().is_empty() and preview == null
	title.text = building.display_name if building != null else "Construction"
	var text := message
	if building != null:
		text = "Complete • Storage %d • Housing %d" % [building.storage_capacity, building.housing] if building.completed else "Construction %d%% • RMB with selected people to resume" % roundi(building.build_progress * 100)
	elif preview != null:
		text = "%s\n%s\n%s\nLMB place • R rotate • Esc cancel" % [Catalog.DEFINITIONS[preview_type].name, Catalog.cost_label(Catalog.DEFINITIONS[preview_type].cost), "Valid ground" if preview_reason.is_empty() else preview_reason]
	elif founding_state() == "available": text = "40 wood + 10 stone reserved for your first Hall.\nB: Hall preview • X: stop selected people"
	details.text = text
	cancel_button.visible = building != null and not building.completed
	recruit_button.visible = building != null and building.completed and building.can_train_population

func snapshot() -> void:
	var saved := {}
	for id in jobs:
		var actor = host.unit_actors_by_id.get(id)
		if actor != null and actor.action_revision == jobs[id].revision: saved[id] = jobs[id].building
	host.cell.rts_state["construction_jobs"] = saved
