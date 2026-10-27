extends RefCounted

# Ground items have stable IDs and persist collection separately from equipment.
# Their inventory records do not assign jobs or reset unit health.
const PICKUP_WORK := 0.6
var host
var items: Dictionary = {}
var jobs: Dictionary = {}
# Empty slots retire a spawn without renumbering persisted item IDs.
const MODELS := {
	"flint_axe": ["res://assets/models/tools/primitive_stone_axe_lod0.glb"],
	"building_tools": ["", "res://assets/models/tools/primitive_antler_pick_lod0.glb"],
	"spear": ["res://assets/models/tools/primitive_stone_spear_lod0.glb"],
}

static func spawn(host, actor) -> void:
	var data = actor.unit_data
	if data.ground_tools_equipment_id.is_empty(): data.ground_tools_equipment_id = actor.equipment_id
	if not MODELS.has(data.ground_tools_equipment_id): return
	if host.tool_pickups == null:
		host.tool_pickups = (load("res://scripts/battle/rts_spawn_tools.gd") as GDScript).new()
		host.tool_pickups.host = host
	if not data.ground_tools_initialized:
		data.ground_tools_position = host._ground_position_for_local(actor.position.x, actor.position.z + 4.0)
		data.ground_tools_initialized = true
	var root := Node3D.new()
	root.name = "SpawnTools_%s" % actor.unit_id
	root.set_meta("unit_id", actor.unit_id)
	root.position = data.ground_tools_position
	host.battle_entity_root.add_child(root)
	var paths: Array = MODELS[data.ground_tools_equipment_id]
	var active_paths := paths.filter(func(path): return not str(path).is_empty())
	for index in range(paths.size()):
		if str(paths[index]).is_empty(): continue
		var id := "%s:tool:%d" % [actor.unit_id, index]
		if index in data.ground_tools_collected: continue
		if host.tool_pickups.items.has(id): continue
		var tool := (load(paths[index]) as PackedScene).instantiate() as Node3D
		root.add_child(tool)
		tool.scale = Vector3.ONE * host.UNIT_VISUAL_SCALE
		tool.rotation = Vector3(PI * 0.5, 0, PI * 0.12)
		tool.position.x = (active_paths.find(paths[index]) - (active_paths.size() - 1) * 0.5) * 1.8
		# Set the rotated asset's lowest point on the sampled ground.
		var bounds: Dictionary = host._combined_local_bounds(tool)
		if bounds.valid:
			var minimum := INF
			var box := AABB(bounds.min, bounds.max - bounds.min)
			for endpoint in range(8): minimum = minf(minimum, (tool.transform.basis * box.get_endpoint(endpoint)).y)
			var ground: Vector3 = host._ground_position_for_local(root.position.x + tool.position.x, root.position.z)
			tool.position.y = ground.y - root.position.y - minimum + 0.03
			var low := Vector3.ONE * INF
			var high := Vector3.ONE * -INF
			for endpoint in range(8):
				var point := tool.global_transform * box.get_endpoint(endpoint)
				low = low.min(point)
				high = high.max(point)
			var center := (low + high) * 0.5
			var radius := maxf(1.2, Vector2(high.x - low.x, high.z - low.z).length() * 0.55)
			var ring := MeshInstance3D.new()
			ring.name = "ToolOutline_%d" % index
			ring.mesh = host._resource_ring_mesh()
			ring.material_override = host._resource_ring_material("flint")
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ring)
			ring.global_position = host._ground_position_for_local(center.x, center.z) + Vector3(0, host.RESOURCE_RING_SURFACE_OFFSET + 0.04, 0)
			ring.scale = Vector3(radius, 1, radius)
			host.tool_pickups.items[id] = {"id": id, "owner": data, "index": index, "model": tool, "path": paths[index], "ring": ring, "center": center, "bounds": AABB(low, high - low), "radius": radius}

func at_screen(point: Vector2) -> Dictionary:
	if host.camera == null: return {}
	var best := {}
	var distance := INF
	for item in items.values():
		if host.camera.is_position_behind(item.center): continue
		var low := Vector2.ONE * INF
		var high := Vector2.ONE * -INF
		for endpoint in range(8):
			var projected: Vector2 = host.camera.unproject_position(item.bounds.get_endpoint(endpoint))
			low = low.min(projected)
			high = high.max(projected)
		var rect := Rect2(low, high - low).grow(8.0)
		var candidate := point.distance_squared_to((low + high) * 0.5)
		if rect.has_point(point) and candidate < distance:
			best = item
			distance = candidate
	return best

func issue_pickup(item: Dictionary, ids: Array, jog_order: bool = false) -> bool:
	if item.is_empty() or not items.has(item.id): return false
	# An item is reserved by at most one active pickup order.
	for id in jobs:
		var job: Dictionary = jobs[id]
		if job.item != item.id: continue
		var reserved_actor = host.unit_actors_by_id.get(id)
		if id in ids and reserved_actor != null and reserved_actor.action_revision == job.revision:
			if jog_order: host._sprint_task_approach(reserved_actor)
			return true
		return false
	var chosen = null
	var chosen_target := Vector3.ZERO
	var closest := INF
	for id in ids:
		var actor = host.unit_actors_by_id.get(id)
		if actor == null or actor.faction_id != "player" or not actor.unit_data.is_alive(): continue
		var direction: Vector3 = item.center - actor.position
		direction.y = 0
		if direction.is_zero_approx(): direction = Vector3.FORWARD
		var target: Vector3 = host.navigation.ground(item.center - direction.normalized() * 2.5)
		if host.navigation.route(actor.position, target).is_empty(): continue
		var distance: float = actor.position.distance_squared_to(target)
		if distance < closest:
			chosen = actor
			chosen_target = target
			closest = distance
	if chosen == null: return false
	chosen.stop()
	chosen.issue_move_order(host._make_unit_move_order(chosen_target, false), false)
	chosen.play_animation(host._first_available_unit_animation(host.UNIT_WALK_ANIMATION_CANDIDATES))
	if jog_order: host._sprint_task_approach(chosen)
	jobs[chosen.unit_id] = {"item": item.id, "revision": chosen.action_revision, "target": chosen_target, "work": 0.0}
	return true

func update(delta: float) -> void:
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		var actor = host.unit_actors_by_id.get(id)
		if actor == null or not actor.unit_data.is_alive() or actor.action_revision != job.revision or not items.has(job.item):
			if actor != null and actor.kneeling_context == "tool:" + str(job.item): actor.finish_kneeling_work()
			jobs.erase(id)
			continue
		if actor.has_move_order(): continue
		var item: Dictionary = items[job.item]
		if actor.position.distance_to(job.target) > 2.0 or not host.navigation.segment_clear(actor.position, job.target):
			actor.stop()
			jobs.erase(id)
			continue
		actor.face_position(item.center)
		job.work += actor.work_while_kneeling(delta, "tool:" + str(item.id))
		if job.work < PICKUP_WORK: continue
		# Commit once, only after the reach. Removing the item also clears reservations.
		item.owner.ground_tools_collected.append(int(item.index))
		actor.unit_data.collected_tools.append({"id": item.id, "model": item.path})
		if actor.collected_tool_visual != null: actor.collected_tool_visual.refresh_inventory()
		item.model.visible = false
		item.ring.visible = false
		item.model.queue_free()
		item.ring.queue_free()
		items.erase(item.id)
		jobs.erase(id)
		actor.finish_kneeling_work()
		host._clear_resource_hover()
		if host.hud != null: host.hud.notify("Tool collected", item.center)
		host._refresh_overlay()

func snapshot() -> void:
	var saved := {}
	for id in jobs:
		var actor = host.unit_actors_by_id.get(id)
		if actor != null and actor.action_revision == jobs[id].revision: saved[id] = jobs[id].item
	host.cell.rts_state["tool_pickup_jobs"] = saved

func restore_jobs() -> void:
	for id in host.cell.rts_state.get("tool_pickup_jobs", {}):
		var item_id := str(host.cell.rts_state.tool_pickup_jobs[id])
		if items.has(item_id): issue_pickup(items[item_id], [id])
