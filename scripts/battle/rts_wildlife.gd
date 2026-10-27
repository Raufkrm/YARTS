extends RefCounted

const Catalog = preload("res://scripts/data/wildlife_catalog.gd")
const AnimalData = preload("res://scripts/data/rts_animal_data.gd")
const AnimalActor = preload("res://scripts/battle/rts_animal_actor.gd")
const CAPTURE_DISTANCE_METERS := 1.0
var host
var navigation
var animals: Dictionary = {}
var actors: Dictionary = {}
var rng := RandomNumberGenerator.new()
var root: Node3D
var selected_id := ""
var follow_mode := false
var panel: PanelContainer
var label: Label
var commands: HBoxContainer
var ui_elapsed := 0.0
var message := ""
var cosmetic_specs: Array = []
var last_update_usec := 0

func configure(scene, nav) -> void:
	host = scene
	navigation = nav
	root = Node3D.new()
	root.name = "Wildlife"
	host.terrain_root.add_child(root)
	var seed_value := 0
	# World seed and cell ID are the only generation inputs.
	var game = host.get_node("/root/Game")
	if game.world_state != null: seed_value = game.world_state.seed
	rng.seed = hash("wildlife:%d:%s" % [seed_value, host.cell.id])
	if bool(host.cell.rts_state.get("wildlife_generated", false)):
		for record in host.cell.rts_state.get("animals", []):
			var animal := AnimalData.new()
			animal.load_from_dict(record)
			if Catalog.SPECIES.has(animal.species): animals[animal.id] = animal
		cosmetic_specs = host.cell.rts_state.get("cosmetic_birds", []).duplicate(true)
	else:
		generate()
		host.cell.rts_state["wildlife_generated"] = true
	for animal in animals.values():
		if animal.health > 0: _spawn_actor(animal)
	spawn_cosmetic_birds()
	_release_legacy_capture_reservations()
	_build_panel()
	snapshot()

func latitude_at(point: Vector3) -> float:
	var game = host.get_node("/root/Game")
	if game.world_state == null: return 0.0
	var bounds: Dictionary = game.world_state.get_cell_lat_lon_bounds(host.cell)
	return lerpf(float(bounds.lat_top), float(bounds.lat_bottom), (point.z + navigation.half_size) / (navigation.half_size * 2.0))

func coastal(point: Vector3) -> bool:
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if str(navigation.sample(point + direction * 140.0).get("terrain", "")) == "water": return true
	return false

func local_habitat(point: Vector3) -> String:
	return Catalog.habitat(navigation.sample(point), latitude_at(point), coastal(point))

func generate() -> void:
	var candidates: Array = []
	var origin: Vector3 = host._find_initial_dry_spawn_center()
	if not host.battle_units.is_empty(): origin = host.battle_units[0].position
	var half: float = navigation.half_size - 40.0
	# Uniform area sampling naturally weights species by suitable habitat area.
	for index in range(360):
		var point := Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-half, half))
		if not navigation.clear(point, 6.0): continue
		var habitat := local_habitat(point)
		point = navigation.ground(point)
		if habitat == "forest" and cosmetic_specs.size() < 4:
			cosmetic_specs.append({"species": "crow", "position": [point.x, point.y + 30, point.z]})
		elif coastal(point) and cosmetic_specs.size() < 6:
			cosmetic_specs.append({"species": "seagull", "position": [point.x, point.y + 35, point.z]})
		if habitat.is_empty(): continue
		for species in Catalog.SPECIES:
			if not Catalog.eligible(species, habitat): continue
			var profile: Dictionary = Catalog.SPECIES[species]
			if profile.temperament == "dangerous" and point.distance_to(origin) < 350: continue
			candidates.append({"position": point, "species": species, "weight": profile.rarity})
	var herd_count := rng.randi_range(3, 6)
	var centers: Array[Vector3] = []
	for herd in range(herd_count):
		for attempt in range(16):
			if candidates.is_empty() or animals.size() >= Catalog.MAX_ANIMALS: break
			var index := _weighted_index(candidates)
			var candidate: Dictionary = candidates[index]
			candidates.remove_at(index)
			var center: Vector3 = candidate.position
			var separated := true
			for previous in centers:
				if previous.distance_to(center) < 110.0: separated = false
			if not separated or navigation.route(origin, center).is_empty(): continue
			var profile: Dictionary = Catalog.SPECIES[candidate.species]
			var count := rng.randi_range(profile.group.x, profile.group.y)
			for member in range(count):
				if animals.size() >= Catalog.MAX_ANIMALS: break
				for placement in range(12):
					var point := center + Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-22, 22))
					if not navigation.clear(point, 5) or not Catalog.eligible(candidate.species, local_habitat(point)): continue
					if profile.temperament == "dangerous" and point.distance_to(origin) < 350.0: continue
					if not navigation.segment_clear(center, point): continue
					var occupied := false
					for other in animals.values():
						if other.position.distance_to(point) < 8: occupied = true
					if occupied: continue
					var animal := AnimalData.new()
					animal.id = "%s_animal_%02d" % [host.cell.id, animals.size() + 1]
					animal.herd_id = "%s_herd_%d" % [host.cell.id, herd]
					animal.species = candidate.species
					animal.coat = "white" if animal.species == "horse" and rng.randf() < 0.22 else "brown"
					animal.position = navigation.ground(point)
					animal.home = center
					animal.health = profile.health
					animal.max_health = profile.health
					animals[animal.id] = animal
					break
			centers.append(center)
			break

func _weighted_index(items: Array) -> int:
	var total := 0.0
	for item in items: total += float(item.weight)
	var roll := rng.randf() * total
	for index in range(items.size()):
		roll -= float(items[index].weight)
		if roll <= 0: return index
	return items.size() - 1

func _spawn_actor(animal) -> void:
	var actor := AnimalActor.new()
	root.add_child(actor)
	actor.configure(animal, navigation)
	actors[animal.id] = actor
	if animal.command == "move": actor.move_to(animal.target)

func spawn_cosmetic_birds() -> void:
	for spec in cosmetic_specs:
		var flock := (load("res://scenes/props/%s.tscn" % spec.species) as PackedScene).instantiate()
		flock.bird_count = 5
		flock.flight_radius = 20.0
		flock.position = Vector3(spec.position[0], spec.position[1], spec.position[2])
		root.add_child(flock)

func _capture_near_selected_humans() -> void:
	var selected: Array = host._valid_selected_unit_ids()
	if selected.is_empty(): return
	var capture_distance: float = CAPTURE_DISTANCE_METERS * host.UNIT_VISUAL_SCALE
	for animal in animals.values():
		if animal.health <= 0 or animal.owner_id != "neutral": continue
		for id in selected:
			var person = host.unit_actors_by_id.get(id)
			if person == null or person.faction_id != "player" or not person.unit_data.is_alive(): continue
			if person.position.distance_to(animal.position) > capture_distance: continue
			if not navigation.segment_clear(person.position, animal.position): continue
			animal.owner_id = "player"
			animal.command = "stay"
			animal.behavior = "idle"
			animal.follow_id = ""
			if actors.has(animal.id): actors[animal.id].stop()
			message = "%s captured. Select it to Move, Stop, Follow or Stay." % Catalog.SPECIES[animal.species].name
			if host.hud != null: host.hud.notify(message, animal.position)
			host._refresh_overlay()
			break

func _release_legacy_capture_reservations() -> void:
	# Saves made with the earlier timed-capture system may contain reserved food.
	# Return it once; new proximity captures never reserve or spend resources.
	for animal in animals.values():
		if animal.legacy_capture.is_empty(): continue
		host.construction.refund({"food": int(animal.legacy_capture.get("reserved_food", 0))})
		animal.legacy_capture.clear()
		animal.behavior = "idle" if animal.owner_id == "player" else "grazing"

func _approach_position(from: Vector3, target: Vector3) -> Vector3:
	var direction := Vector3(from.x - target.x, 0, from.z - target.z).normalized()
	if direction == Vector3.ZERO: direction = Vector3.BACK
	return navigation.ground(target + direction * 7.0)


func order(id: String, command: String, target: Vector3 = Vector3.ZERO, follow_id: String = "") -> bool:
	var animal = animals.get(id)
	if animal == null or animal.owner_id != "player" or animal.health <= 0 or not command in Catalog.COMMANDS: return false
	var actor = actors.get(id)
	if actor == null: return false
	if command == "follow":
		var person = host.unit_actors_by_id.get(follow_id)
		if person == null or person.faction_id != "player" or not person.unit_data.is_alive(): return false
	if command == "move" and not actor.move_to(target):
		message = "No safe land route to that position."
		if host.hud != null: host.hud.notify(message, animal.position)
		return false
	if command in ["stop", "stay"]: actor.stop()
	animal.command = command
	animal.follow_id = follow_id
	animal.behavior = "idle"
	return true

func update(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_capture_near_selected_humans()
	for animal in animals.values():
		var actor = actors.get(animal.id)
		if actor == null: continue
		if animal.health <= 0:
			actor.visible = false
			continue
		var distance: float = host.camera.global_position.distance_to(animal.position) if host.camera != null else 0.0
		var on_screen: bool = distance < 900.0 and (host.camera == null or not host.camera.is_position_behind(animal.position))
		actor.motion_elapsed += delta
		if on_screen or actor.motion_elapsed >= 0.25:
			actor.update_motion(actor.motion_elapsed, on_screen)
			actor.motion_elapsed = 0.0
		actor.decision_elapsed += delta
		if actor.decision_elapsed >= (0.8 if on_screen else 2.4):
			actor.decision_elapsed = 0.0
			_think(animal, actor)
			var lod := 0 if distance < 140 else (1 if distance < 600 else 2)
			if lod != actor.lod: actor.set_lod(lod)
		actor.selection.visible = animal.id == selected_id
	ui_elapsed += delta
	if ui_elapsed >= 0.2:
		ui_elapsed = 0.0
		_refresh_panel()
	last_update_usec = Time.get_ticks_usec() - started

func _think(animal, actor) -> void:
	if animal.owner_id == "player":
		if animal.command == "follow":
			var person = host.unit_actors_by_id.get(animal.follow_id)
			if person == null or not person.unit_data.is_alive():
				order(animal.id, "stay")
			elif animal.position.distance_to(person.position) > 18.0:
				actor.move_to(_approach_position(animal.position, person.position))
		return
	var nearest = null
	var distance := INF
	for person in host.unit_actors_by_id.values():
		if not person.unit_data.is_alive(): continue
		var d: float = person.position.distance_to(animal.position)
		if d < distance:
			distance = d
			nearest = person
	var temperament: String = Catalog.SPECIES[animal.species].temperament
	# Selected people can walk up to wildlife; it pauses instead of endlessly
	# outrunning the person. Unselected people still trigger wild behavior.
	var calm_handler := false
	for id in host._valid_selected_unit_ids():
		if host.unit_actors_by_id[id].position.distance_to(animal.position) < 38.0:
			calm_handler = true
			break
	if calm_handler:
		actor.stop()
		animal.behavior = "watching"
		return
	if nearest != null and distance < (38.0 if temperament == "wary" else 16.0) and not calm_handler:
		if temperament == "dangerous" and distance < 11.0 and navigation.segment_clear(animal.position, nearest.position):
			animal.behavior = "defending"
			nearest.unit_data.health = maxi(0, nearest.unit_data.health - 4)
			if nearest.unit_data.health <= 0: nearest.stop()
			actor.stop()
			return
		animal.behavior = "fleeing"
		var direction: Vector3 = (animal.position - nearest.position).normalized()
		for turn in [0.0, 0.7, -0.7, 1.4, -1.4]:
			if actor.move_to(animal.position + direction.rotated(Vector3.UP, turn) * 45): return
		return
	if actor.moving: return
	animal.behavior = "grazing"
	if rng.randf() > 0.24: return
	# Herd home bounds keep grazers grouped; wander targets retain habitat.
	var target: Vector3 = animal.home + Vector3(rng.randf_range(-38, 38), 0, rng.randf_range(-38, 38))
	if Catalog.eligible(animal.species, local_habitat(target)) and actor.move_to(target): animal.behavior = "wandering"

func damage(id: String, amount: int) -> void:
	var animal = animals.get(id)
	if animal == null: return
	animal.health = maxi(0, animal.health - maxi(0, amount))
	if animal.health == 0:
		if actors.has(id):
			actors[id].stop()
			actors[id].visible = false

func at_screen(point: Vector2) -> String:
	var nearest := ""
	var best := 32.0
	for animal in animals.values():
		if animal.health <= 0 or host.camera.is_position_behind(animal.position): continue
		var p: Vector2 = host.camera.unproject_position(animal.position + Vector3(0, 3, 0))
		var distance := p.distance_to(point)
		if distance < best:
			best = distance
			nearest = animal.id
	return nearest

func select_at(point: Vector2) -> bool:
	selected_id = at_screen(point)
	if not selected_id.is_empty():
		# Close human/animal pick radii overlap at capture distance. Honor the
		# nearer screen target so the human can still be selected beside it.
		var human_hit: Dictionary = host._unit_at_screen(point)
		var animal_point: Vector2 = host.camera.unproject_position(animals[selected_id].position + Vector3(0, 3, 0))
		if not human_hit.is_empty() and float(human_hit.screen_distance_sq) <= animal_point.distance_squared_to(point):
			selected_id = ""
	if selected_id.is_empty():
		_refresh_panel()
		return false
	var animal = animals[selected_id]
	if animal.owner_id == "player": host._clear_unit_selection()
	_refresh_panel()
	return true

func input(event: InputEvent, jog_order: bool = false) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			follow_mode = false
			selected_id = ""
			_refresh_panel()
		if event.keycode == KEY_X and not selected_id.is_empty(): return order(selected_id, "stop")
	if event is InputEventMouseButton and event.pressed and not host._is_screen_point_in_hud(event.position):
		if follow_mode and event.button_index == MOUSE_BUTTON_LEFT:
			var hit: Dictionary = host._unit_at_screen(event.position)
			if not hit.is_empty(): order(selected_id, "follow", Vector3.ZERO, str(hit.id))
			follow_mode = false
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT and not host._valid_selected_unit_ids().is_empty():
			var animal_id := at_screen(event.position)
			if not animal_id.is_empty() and animals[animal_id].owner_id == "neutral":
				for id in host._valid_selected_unit_ids():
					var person = host.unit_actors_by_id[id]
					person.issue_move_order(host._make_unit_move_order(animals[animal_id].position, false))
					person.play_animation(host._first_available_unit_animation(host.UNIT_WALK_ANIMATION_CANDIDATES))
					if jog_order: host._sprint_task_approach(person)
				return true
		if event.button_index == MOUSE_BUTTON_RIGHT and not selected_id.is_empty() and animals[selected_id].owner_id == "player":
			var hit: Dictionary = host._screen_to_ground_position(event.position)
			if not hit.is_empty(): order(selected_id, "move", hit.position)
			return true
	return false

func _build_panel() -> void:
	if host.hud != null: return
	panel = PanelContainer.new()
	panel.name = "AnimalPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -380
	panel.offset_right = -80
	panel.offset_top = 175
	panel.add_theme_stylebox_override("panel", host._hud_panel_style(0.94))
	host.order_sidebar_panel.get_parent().add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 290
	box.add_child(label)
	commands = HBoxContainer.new()
	box.add_child(commands)
	for command in ["stop", "stay", "follow"]:
		var button: Button = host._make_compact_button(command.capitalize())
		button.pressed.connect(_command_pressed.bind(command))
		commands.add_child(button)
	_refresh_panel()

func _command_pressed(command: String) -> void:
	if command == "follow":
		follow_mode = true
		message = "Click a person for this animal to follow."
	else: order(selected_id, command)

func _refresh_panel() -> void:
	if panel == null: return
	var animal = animals.get(selected_id)
	panel.visible = animal != null
	if animal == null:
		label.text = message
		commands.visible = false
		return
	var profile: Dictionary = Catalog.SPECIES[animal.species]
	var text := "%s • %d/%d health\n%s • %s\n" % [profile.name, animal.health, animal.max_health, animal.owner_id.capitalize(), animal.behavior.capitalize()]
	if animal.owner_id == "neutral":
		text += "Walk a selected person within 1 metre to capture.\n"
	else: text += "RMB move | X stop | Follow: click a person\n"
	label.text = text + message
	commands.visible = animal.owner_id == "player" and animal.health > 0

func snapshot() -> void:
	var records := []
	for animal in animals.values(): records.append(animal.to_dict())
	host.cell.rts_state["animals"] = records
	host.cell.rts_state["wildlife_generated"] = true
	host.cell.rts_state["cosmetic_birds"] = cosmetic_specs.duplicate(true)
