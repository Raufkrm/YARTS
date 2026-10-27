extends Control
## Compact hybrid HUD. Gameplay stays in the settlement / wildlife controllers.

const Buildings = preload("res://scripts/data/building_catalog.gd")
const Animals = preload("res://scripts/data/wildlife_catalog.gd")
const INK := Color("e5e8e5")
const MUTED := Color("a2ada8")
const ACCENT := Color("839d8f")

var host
var panels: Array[Control] = []
var resource_labels := {}
var resource_panel: PanelContainer
var people_panel: PanelContainer
var people_label: Label
var idle_button: Button
var region_label: Label
var more_panel: PanelContainer
var more_label: Label
var dock: PanelContainer
var selection_title: Label
var health_label: Label
var health_bar: ProgressBar
var task_label: Label
var carry_label: Label
var command_hint: Label
var commands: HBoxContainer
var command_buttons := {}
var drawer: PanelContainer
var build_buttons := {}
var founding_label: Label
var map_panel: PanelContainer
var local_map: Control
var world_map: Control
var local_tab: Button
var world_tab: Button
var map_mode := "local"
var menu: PanelContainer
var debug_box: VBoxContainer
var debug_label: Label
var group_bar: HBoxContainer
var groups := {}
var group_buttons: Array[Button] = []
var alerts: Array[Dictionary] = []
var alert_button: Button
var alert_history: PanelContainer
var alert_list: VBoxContainer
var elapsed := 0.0
var target_mode := ""
var selection_key := ""
var active_kind := ""
var selected_building
var selected_animal
var ui_scale := 1.0

func configure(scene, parent: Control) -> void:
	host = scene
	name = "CompactHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	add_theme_color_override("font_color", INK)
	add_theme_font_size_override("font_size", 14)
	_build_top()
	_build_dock()
	_build_drawer()
	_build_map()
	_build_menu()
	_build_alerts()
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _panel(label: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = label
	panel.add_theme_stylebox_override("panel", host._hud_panel_style(0.96))
	add_child(panel)
	panels.append(panel)
	host._add_hud_glass(panel, 0.96)
	return panel

func _content(panel: PanelContainer, horizontal: bool = false) -> BoxContainer:
	var margin: MarginContainer = host._add_hud_margin(panel, 12, 10, 12, 10)
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box

func _label(parent: Node, value: String = "", font_size: int = 14, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MUTED if muted else INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable, minimum := Vector2(0, 30)) -> Button:
	var button: Button = host._make_compact_button(value)
	button.custom_minimum_size = minimum
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_top() -> void:
	resource_panel = _panel("Resources")
	var row := _content(resource_panel, true)
	for resource in ["food", "wood", "stone"]:
		var stack := VBoxContainer.new()
		stack.custom_minimum_size.x = 98
		stack.add_theme_constant_override("separation", 1)
		row.add_child(stack)
		_label(stack, resource.to_upper(), 10, true)
		resource_labels[resource] = _label(stack, "0", 18)
	_button(row, "More", toggle_more)
	more_panel = _panel("MoreResources")
	var more := _content(more_panel)
	_label(more, "STOCKPILE", 11, true)
	more_label = _label(more, "", 14)
	more_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more_panel.hide()
	people_panel = _panel("PeopleAndMenu")
	var people := _content(people_panel, true)
	people_label = _label(people, "People  0 / 0", 14)
	people_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_label.tooltip_text = "Living people / completed housing capacity"
	people_label.mouse_filter = Control.MOUSE_FILTER_PASS
	idle_button = _button(people, "Idle  0", select_idle)
	idle_button.tooltip_text = "Select idle workers and centre the camera [I]"
	_button(people, "Menu", toggle_menu)
	region_label = _label(self, "", 12, true)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	region_label.add_theme_constant_override("shadow_offset_x", 1)
	region_label.add_theme_constant_override("shadow_offset_y", 1)

func _build_dock() -> void:
	dock = _panel("SelectionDock")
	var row := _content(dock, true)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 270
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)
	selection_title = _label(info, "", 17)
	selection_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	health_label = _label(info, "", 12, true)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 4
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("29302d")
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	health_bar.add_theme_stylebox_override("background", track)
	health_bar.add_theme_stylebox_override("fill", fill)
	info.add_child(health_bar)
	task_label = _label(info, "", 12)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carry_label = _label(info, "", 12, true)
	carry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var separator := VSeparator.new()
	row.add_child(separator)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 9)
	row.add_child(actions)
	command_hint = _label(actions, "", 12, true)
	command_hint.custom_minimum_size.y = 38
	command_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commands = HBoxContainer.new()
	commands.add_theme_constant_override("separation", 6)
	actions.add_child(commands)
	group_bar = HBoxContainer.new()
	group_bar.add_theme_constant_override("separation", 5)
	add_child(group_bar)
	for index in range(1, 6):
		var button := _button(group_bar, str(index), func(): use_group(index, Input.is_key_pressed(KEY_CTRL)), Vector2(38, 28))
		button.tooltip_text = "Group %d: Ctrl+%d to assign, %d to select" % [index, index, index]
		group_buttons.append(button)

func _build_drawer() -> void:
	drawer = _panel("BuildDrawer")
	var box := _content(drawer)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label(header, "BUILD SETTLEMENT", 11, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Close [B]", toggle_build)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for type_id in Buildings.DEFINITIONS:
		var item: Dictionary = Buildings.DEFINITIONS[type_id]
		var button := _button(grid, "%s\n%s" % [item.name, Buildings.cost_label(item.cost)], begin_build.bind(type_id), Vector2(210, 54))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s\n%s\nHousing: %d  •  Storage: %d\nBuild time: %d seconds with one builder at the site." % [item.name, Buildings.cost_label(item.cost), item.housing, item.storage, int(item.work)]
		build_buttons[type_id] = button
	founding_label = _label(box, "", 11, true)
	founding_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer.hide()

func _build_map() -> void:
	map_panel = _panel("MapPanel")
	var box := _content(map_panel)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	local_tab = _button(tabs, "LOCAL", set_map_mode.bind("local"))
	world_tab = _button(tabs, "WORLD", set_map_mode.bind("world"))
	for tab in [local_tab, world_tab]:
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_map = host.HudMapPreview.new()
	local_map.preview_mode = "minimap"
	local_map.custom_minimum_size = Vector2(216, 216)
	local_map.mouse_filter = Control.MOUSE_FILTER_STOP
	local_map.gui_input.connect(host._on_minimap_gui_input)
	box.add_child(local_map)
	local_map.mouse_filter = Control.MOUSE_FILTER_STOP
	host.minimap_preview = local_map
	world_map = VBoxContainer.new()
	box.add_child(world_map)
	var globe := SubViewportContainer.new()
	globe.custom_minimum_size = Vector2(216, 178)
	globe.stretch = true
	globe.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map.add_child(globe)
	host._build_world_globe_view(globe)
	_button(world_map, "Open world map", host._on_return_pressed)
	set_map_mode("local")

func _build_menu() -> void:
	menu = _panel("Menu")
	var box := _content(menu)
	_label(box, "YARTS", 18)
	_button(box, "Save campaign", func():
		notify("Campaign saved." if Game.save_campaign() else "Could not save campaign.")
		menu.hide())
	_button(box, "World map", host._on_return_pressed)
	_button(box, "Debug tools", func():
		debug_box.visible = not debug_box.visible
		host._refresh_animation_picker())
	debug_box = VBoxContainer.new()
	box.add_child(debug_box)
	debug_label = _label(debug_box, "", 12, true)
	_label(debug_box, "Selected person's animation", 12, true)
	host.context_animation_picker = OptionButton.new()
	host._apply_hud_control_theme(host.context_animation_picker)
	host.context_animation_picker.item_selected.connect(host._on_unit_animation_selected)
	debug_box.add_child(host.context_animation_picker)
	debug_box.hide()
	_button(box, "Close [Esc]", toggle_menu)
	menu.hide()

func _build_alerts() -> void:
	alert_button = _button(self, "", toggle_alerts, Vector2(0, 28))
	alert_button.hide()
	alert_history = _panel("RecentAlerts")
	alert_list = _content(alert_history)
	alert_history.hide()

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	ui_scale = minf(clampf(viewport_size.y / 900.0, 0.85, 1.25), viewport_size.x / 1240.0)
	scale = Vector2.ONE * ui_scale
	size = viewport_size / ui_scale
	resource_panel.position = Vector2(16, 16)
	resource_panel.size = Vector2(400, 64)
	people_panel.position = Vector2(size.x - 338, 16)
	people_panel.size = Vector2(322, 64)
	region_label.position = Vector2(size.x / 2 - 190, 24)
	region_label.size = Vector2(380, 48)
	# On narrower windows the region sits on its own line beneath the bars.
	if size.x < 1550: region_label.position.y = 86
	more_panel.position = Vector2(16, 88)
	more_panel.size = Vector2(400, 160)
	dock.position = Vector2(16, size.y - 170)
	dock.size = Vector2(760, 154)
	group_bar.position = Vector2(16, size.y - 208)
	drawer.position = Vector2(316, size.y - 470)
	drawer.size = Vector2(460, 286)
	map_panel.position = Vector2(size.x - 256, size.y - 294)
	map_panel.size = Vector2(240, 278)
	menu.position = Vector2(size.x - 306, 88)
	menu.size = Vector2(290, 0)
	alert_button.position = Vector2(16, 88)
	alert_history.position = Vector2(16, 126)
	alert_history.size = Vector2(400, 0)

func contains(point: Vector2) -> bool:
	for panel in panels:
		if host._visible_control_contains(panel, point): return true
	for control in [group_bar, alert_button]:
		if host._visible_control_contains(control, point): return true
	return false

func update(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.2: return
	elapsed = 0.0
	refresh()

func refresh() -> void:
	if host.cell == null: return
	var resources: Dictionary = host.cell.resources
	for resource in resource_labels:
		resource_labels[resource].text = str(int(resources.get(resource, 0)))
	var lines: PackedStringArray = []
	var keys: Array = resources.keys()
	keys.sort()
	for resource in keys:
		if resource not in ["food", "wood", "stone"]: lines.append("%s   %d" % [str(resource).capitalize(), int(resources[resource])])
	more_label.text = "No other materials stored." if lines.is_empty() else "\n".join(lines)
	if host.construction != null and host.construction.founding_state() == "available":
		more_label.text += "\n\n40 wood + 10 stone are reserved for your first Hall."
	people_label.text = "People  %d / %d" % [host._settlement_population_estimate(resources), housing()]
	idle_button.text = "Idle  %d" % idle_units().size()
	idle_button.disabled = idle_units().is_empty()
	region_label.text = "%s  ·  %s" % [host._settlement_display_name(str(host.cell.id), str(host.cell.terrain).capitalize()), host._sun_label(Game.get_battle_sun_amount())]
	host.displayed_sun_label = host._sun_label(Game.get_battle_sun_amount())
	refresh_selection()
	if drawer.visible and host.construction != null:
		for type_id in build_buttons:
			build_buttons[type_id].disabled = not host.construction.can_pay(Buildings.DEFINITIONS[type_id].cost, type_id == "town_center" and host.construction.founding_state() == "available")
		founding_label.text = "40 wood + 10 stone reserved for your first Hall." if host.construction.founding_state() == "available" else "Choose a building, then click clear ground to place it."
	if debug_box.visible:
		debug_label.text = "People %d  •  Buildings %d\nEntities %d  •  Models %d" % [host.battle_units.size(), host.battle_buildings.size(), host.loaded_entity_count, host.full_model_entity_count]
	refresh_alert()
	for index in range(1, 6):
		var ids := valid_group(index)
		group_buttons[index - 1].text = str(index) if ids.is_empty() else "%d · %d" % [index, ids.size()]

func refresh_selection() -> void:
	selected_building = host._building_by_id(host.construction.selected_id) if host.construction != null else null
	selected_animal = host.wildlife.animals.get(host.wildlife.selected_id) if host.wildlife != null else null
	var ids: Array = host._valid_selected_unit_ids()
	var kind := ""
	if selected_animal != null: kind = "animal" if selected_animal.owner_id == "player" and selected_animal.health > 0 else "wild"
	elif host.construction != null and host.construction.preview != null: kind = "preview"
	elif selected_building != null: kind = "building" if selected_building.completed else "site"
	elif not ids.is_empty(): kind = "people"
	var key := "%s:%s:%s:%s" % [kind, str(ids), selected_animal.id if selected_animal != null else "", selected_building.id if selected_building != null else ""]
	if key != selection_key:
		selection_key = key
		target_mode = ""
		if kind != "people": drawer.hide()
		_rebuild_commands(kind)
	active_kind = kind
	dock.visible = not kind.is_empty()
	group_bar.visible = not kind.is_empty() or not groups.is_empty()
	if kind.is_empty():
		drawer.hide()
		return
	carry_label.text = ""
	health_bar.visible = true
	if kind in ["animal", "wild"]:
		selection_title.text = Animals.SPECIES[selected_animal.species].name
		_set_health(selected_animal.health, selected_animal.max_health)
		task_label.text = "%s  ·  %s" % ["Captured" if selected_animal.owner_id == "player" else "Wild", selected_animal.behavior.capitalize()]
		command_hint.text = "Right-click to move. Follow lets you choose a person." if kind == "animal" else "Walk a selected person within 1 metre to capture this animal."
		if selected_animal.health <= 0: command_hint.text = "This animal has died."
	elif kind in ["building", "site"]:
		selection_title.text = selected_building.display_name
		_set_health(selected_building.health, selected_building.max_health)
		task_label.text = "Housing %d  ·  Storage %d" % [selected_building.housing, selected_building.storage_capacity]
		if kind == "site":
			var builders := assigned_builders(selected_building.id)
			health_label.text = "Construction  %d%%  ·  %d builders" % [roundi(selected_building.build_progress * 100), builders.size()]
			health_bar.value = selected_building.build_progress * 100
			carry_label.text = "Reserved: " + Buildings.cost_label(selected_building.reserved_cost)
			command_hint.text = "Select people, then right-click this site to assign builders."
			if command_buttons.has("select_builders"): command_buttons.select_builders.disabled = builders.is_empty()
		else:
			command_hint.text = "Completed. People deliver gathered supplies at any reachable edge."
			if command_buttons.has("recruit"):
				command_buttons.recruit.disabled = host._settlement_population_estimate({}) >= housing() or not host.construction.can_pay({"food": 10}) or host.construction.recruit_position(selected_building).is_empty()
				command_buttons.recruit.tooltip_text = "Recruit a worker: 10 food, available housing and a clear spot around the building."
	elif kind == "preview":
		selection_title.text = Buildings.DEFINITIONS[host.construction.preview_type].name
		health_label.text = Buildings.cost_label(Buildings.DEFINITIONS[host.construction.preview_type].cost)
		health_bar.hide()
		task_label.text = "Choose a location"
		command_hint.text = "Click to place  ·  R rotate  ·  Esc / right-click cancel\n" + ("Clear ground" if host.construction.preview_reason.is_empty() else host.construction.preview_reason)
	else:
		selection_title.text = host.selected_unit_data.display_name if ids.size() == 1 else "%d people selected" % ids.size()
		var health := 0
		var maximum := 0
		var tasks := {}
		for id in ids:
			var actor = host.unit_actors_by_id[id]
			health += actor.unit_data.health
			maximum += actor.unit_data.max_health
			tasks[task_for(actor)] = true
		_set_health(health, maximum)
		task_label.text = str(tasks.keys()[0]) if tasks.size() == 1 else "Working on different tasks"
		var carried: Dictionary = host._carried_resource_totals_for_units(ids)
		carried.erase("none")
		carry_label.text = "Carrying: " + (Buildings.cost_label(carried) if not carried.is_empty() else "nothing")
		var collected := 0
		for id in ids: collected += host.unit_actors_by_id[id].unit_data.collected_tools.size()
		if collected > 0: carry_label.text += "  ·  Tools %d" % collected
		command_hint.text = "Right-click to move, gather or collect tools. Double right-click to sprint to the task."
		if command_buttons.has("build"): command_buttons.build.disabled = host.construction == null or host.construction.builders().is_empty()
		if command_buttons.has("gather"):
			command_buttons.gather.disabled = not ids.any(func(id): return host.unit_actors_by_id[id].unit_data.can_gather())
	if target_mode == "move": command_hint.text = "Click a destination  ·  Esc / right-click cancel"
	elif target_mode == "gather": command_hint.text = "Click a resource to gather  ·  Esc / right-click cancel"
	elif host.wildlife != null and host.wildlife.follow_mode: command_hint.text = "Click a person to follow  ·  Esc cancel"

func _set_health(value: int, maximum: int) -> void:
	health_label.text = "Health  %d / %d" % [value, maximum]
	health_bar.value = 100.0 * value / maxi(1, maximum)

func _command(id: String, text: String, callback: Callable) -> void:
	var button := _button(commands, text, callback, Vector2(92, 60))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_buttons[id] = button

func _rebuild_commands(kind: String) -> void:
	for child in commands.get_children():
		commands.remove_child(child)
		child.queue_free()
	command_buttons.clear()
	if kind in ["people", "animal"]:
		_command("move", "Move\n[M]", func(): set_target_mode("move"))
		_command("stop", "Stop\n[X]", stop_selected)
	if kind == "people":
		_command("gather", "Gather\n[C]", func(): set_target_mode("gather"))
		_command("build", "Build\n[B]", toggle_build)
	elif kind == "animal":
		_command("follow", "Follow\n[F]", follow_selected)
		_command("stay", "Stay\n[T]", func(): host.wildlife.order(host.wildlife.selected_id, "stay"))
	elif kind == "site" and selected_building.faction_id == "player":
		_command("select_builders", "Select\nbuilders", func(): select_people(assigned_builders(selected_building.id)))
		_command("cancel", "Cancel site", func():
			host.construction.cancel(selected_building)
			refresh())
	elif kind == "building" and selected_building.can_train_population and selected_building.faction_id == "player":
		_command("recruit", "Recruit worker\n10 food", func():
			host.construction.recruit(selected_building)
			notify(host.construction.message, selected_building.position)
			refresh())
	elif kind == "preview":
		_command("rotate", "Rotate\n[R]", func(): host.construction.preview_rotation += PI / 4.0)
		_command("cancel", "Cancel\n[Esc]", func(): host.construction.end_preview(); refresh())

func housing() -> int:
	var count := 0
	for building in host.battle_buildings:
		if building.completed and building.faction_id == "player": count += building.housing
	return count

func task_for(actor) -> String:
	if host.tool_pickups != null and host.tool_pickups.jobs.has(actor.unit_id):
		if host.tool_pickups.jobs[actor.unit_id].revision == actor.action_revision: return "Collecting a tool"
	if host._actor_has_gameplay_task(actor):
		var building = host._building_by_id(host.construction.jobs[actor.unit_id].building)
		if building != null and not building.completed: return "Building %s · %d%%" % [building.display_name, roundi(building.build_progress * 100)]
	if actor.current_delivery_action != null: return "Delivering supplies"
	if actor.current_gather_action != null: return "Gathering resources"
	if actor.has_move_order(): return "Moving"
	return "Idle"

func idle_units() -> Array:
	var ids := []
	for actor in host.unit_actors_by_id.values():
		if actor.faction_id == "player" and actor.unit_data.is_alive() and actor.unit_data.can_construct() and task_for(actor) == "Idle": ids.append(actor.unit_id)
	return ids

func assigned_builders(building_id: String) -> Array:
	var ids := []
	for id in host.construction.jobs:
		var actor = host.unit_actors_by_id.get(id)
		var job: Dictionary = host.construction.jobs[id]
		if job.building == building_id and actor != null and actor.unit_data.is_alive() and job.revision == actor.action_revision: ids.append(id)
	return ids

func select_people(ids: Array) -> void:
	if ids.is_empty(): return
	if host.construction != null:
		host.construction.selected_id = ""
		host.construction.end_preview()
	if host.wildlife != null:
		host.wildlife.selected_id = ""
		host.wildlife.follow_mode = false
	host._set_selected_units(ids)
	refresh_selection()

func select_idle() -> void:
	var ids := idle_units()
	select_people(ids)
	if not ids.is_empty(): locate(host.unit_actors_by_id[ids[0]].position)

func valid_group(index: int) -> Array:
	var result := []
	for id in groups.get(index, []):
		var actor = host.unit_actors_by_id.get(id)
		if actor != null and actor.faction_id == "player" and actor.unit_data.is_alive(): result.append(id)
	return result

func use_group(index: int, assign: bool = false) -> void:
	if assign:
		groups[index] = host._valid_selected_unit_ids().duplicate()
		if groups[index].is_empty(): groups.erase(index)
	else: select_people(valid_group(index))
	refresh()

func set_map_mode(mode: String) -> void:
	map_mode = mode
	local_map.visible = mode == "local"
	world_map.visible = mode == "world"
	local_tab.set_pressed_no_signal(mode == "local")
	world_tab.set_pressed_no_signal(mode == "world")
	host.minimap_collapsed = mode != "local"
	host.world_view_collapsed = mode != "world"
	if mode == "world": host.world_globe_update_elapsed = host.WORLD_GLOBE_UPDATE_INTERVAL
	map_panel.reset_size()

func toggle_build() -> void:
	if host.construction == null or host.construction.builders().is_empty(): return
	host.construction.end_preview()
	host.construction.selected_id = ""
	if host.wildlife != null: host.wildlife.selected_id = ""
	refresh_selection()
	target_mode = ""
	drawer.visible = not drawer.visible
	refresh()

func begin_build(type_id: String) -> void:
	drawer.hide()
	target_mode = ""
	host.construction.begin_preview(type_id)
	refresh_selection()

func set_target_mode(mode: String) -> void:
	target_mode = mode
	drawer.hide()
	if host.wildlife != null: host.wildlife.follow_mode = false
	refresh_selection()

func stop_selected() -> void:
	target_mode = ""
	if active_kind == "animal":
		host.wildlife.follow_mode = false
		host.wildlife.order(host.wildlife.selected_id, "stop")
	else:
		for id in host._valid_selected_unit_ids(): host.unit_actors_by_id[id].stop()
	refresh_selection()

func follow_selected() -> void:
	target_mode = ""
	host.wildlife._command_pressed("follow")
	refresh_selection()

func toggle_menu() -> void:
	menu.visible = not menu.visible
	if menu.visible:
		drawer.hide()
		more_panel.hide()
		alert_history.hide()
		target_mode = ""
		host._cancel_unit_selection_drag()

func input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if menu.visible: menu.hide()
			elif host.construction != null and host.construction.preview != null: host.construction.end_preview()
			elif not target_mode.is_empty(): target_mode = ""
			elif host.wildlife != null and host.wildlife.follow_mode: host.wildlife.follow_mode = false
			elif drawer.visible: drawer.hide()
			elif more_panel.visible: more_panel.hide()
			elif alert_history.visible: alert_history.hide()
			else: toggle_menu()
			refresh_selection()
			return true
		if menu.visible: return true
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			use_group(event.keycode - KEY_1 + 1, event.ctrl_pressed)
			return true
		if event.keycode == KEY_I: select_idle(); return true
		if event.keycode == KEY_B and host.construction != null and not host.construction.builders().is_empty(): toggle_build(); return true
		if event.keycode == KEY_M and active_kind in ["people", "animal"]: set_target_mode("move"); return true
		if event.keycode == KEY_C and active_kind == "people" and not command_buttons.gather.disabled: set_target_mode("gather"); return true
		if event.keycode == KEY_X and active_kind in ["people", "animal"]: stop_selected(); return true
		if event.keycode == KEY_F and active_kind == "animal": follow_selected(); return true
		if event.keycode == KEY_T and active_kind == "animal": host.wildlife.order(host.wildlife.selected_id, "stay"); return true
	if event is InputEventMouseButton and event.pressed and not contains(event.position):
		if menu.visible: menu.hide(); return true
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			more_panel.hide()
			alert_history.hide()
		if not target_mode.is_empty():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				target_mode = ""
				refresh_selection()
				return true
			if event.button_index == MOUSE_BUTTON_LEFT:
				if target_mode == "gather":
					var resource = host._resource_at_screen(event.position)
					if resource == null or not host._issue_gather_order_to_selected_units(resource):
						notify("Choose a resource this person can gather.")
						return true
				elif active_kind == "animal":
					var hit: Dictionary = host._screen_to_ground_position(event.position)
					if not hit.is_empty(): host.wildlife.order(host.wildlife.selected_id, "move", hit.position)
				else: host._issue_move_order_to_selected_units(event.position, false)
				target_mode = ""
				refresh_selection()
				return true
	return false

func notify(message: String, position: Variant = null) -> void:
	alerts.push_front({"text": message, "position": position, "time": Time.get_ticks_msec()})
	if alerts.size() > 8: alerts.pop_back()
	refresh_alert()

func refresh_alert() -> void:
	alert_button.visible = not alerts.is_empty() and not more_panel.visible
	if alerts.is_empty(): return
	var recent: Dictionary = alerts[0]
	var fresh := Time.get_ticks_msec() - int(recent.time) < 6500
	var line := str(recent.text).get_slice("\n", 0)
	alert_button.text = (line.left(53) + ("…" if line.length() > 53 else "")) if fresh else "%d recent alerts" % alerts.size()
	alert_button.tooltip_text = str(recent.text) + "\nClick to view recent alerts and locate events."

func toggle_alerts() -> void:
	more_panel.hide()
	alert_history.visible = not alert_history.visible
	if not alert_history.visible: return
	for child in alert_list.get_children():
		alert_list.remove_child(child)
		child.queue_free()
	for alert in alerts:
		var button := _button(alert_list, str(alert.text), func():
			if alert.position is Vector3: locate(alert.position)
			alert_history.hide())
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.x = 370
		button.tooltip_text = "Locate event" if alert.position is Vector3 else str(alert.text)

func toggle_more() -> void:
	more_panel.visible = not more_panel.visible
	alert_history.hide()
	refresh_alert()

func locate(position: Vector3) -> void:
	var half: float = host.MAP_SIZE * 0.5
	host._move_camera_to_minimap_position(Vector2(inverse_lerp(-half, half, position.x), inverse_lerp(-half, half, position.z)))
