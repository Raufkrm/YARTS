extends RefCounted

# Shared land routing. Static geometry uses swept tests; terrain is sampled every
# 3 world units (with the actor footprint), not a continuous terrain collision.
const STEP := 16.0
const CLEARANCE := 2.0
const GRID_CLEARANCE := 4.0
const LOCAL_OBSTACLES := 8
const RING_POINTS := 16
const LOCAL_EDGE_BUDGET := 2400
const CORNER_PAD := 0.15
var segment_queries := 0
var last_route_kind := ""
var visibility_cache: Dictionary = {}
var visibility_margin := -1.0
var host
var grid: AStarGrid2D
var obstacles: Dictionary = {}
var buckets: Dictionary = {}
var revision := 0
var terrain_cache: Dictionary = {}
var half_size := 2000.0

func configure(scene) -> void:
	host = scene
	half_size = host.MAP_SIZE * 0.5

func prepare_routes() -> void:
	# Also prepare on saved-cell re-entry, where wildlife generation is skipped.
	# Otherwise the first wandering animal can build the entire grid mid-frame.
	if grid == null: _build_grid()

func ground(point: Vector3) -> Vector3:
	return host._ground_position_for_local(point.x, point.z)

func sample(point: Vector3) -> Dictionary:
	return host._sample_cell_uv((point.x + half_size) / (half_size * 2.0), (point.z + half_size) / (half_size * 2.0))

func terrain_clear(point: Vector3, margin: float = CLEARANCE) -> bool:
	if absf(point.x) > half_size - margin - 4.0 or absf(point.z) > half_size - margin - 4.0: return false
	var low := INF
	var high := -INF
	for offset in [Vector3.ZERO, Vector3(margin, 0, margin), Vector3(-margin, 0, margin), Vector3(margin, 0, -margin), Vector3(-margin, 0, -margin)]:
		var p: Vector3 = point + offset
		var key := Vector2i(roundi(p.x), roundi(p.z))
		if not terrain_cache.has(key):
			var data := sample(p)
			terrain_cache[key] = str(data.get("terrain", "water")) != "water" and float(data.get("river", 0.0)) < 0.10
		if not terrain_cache[key]: return false
		var height: float = ground(p).y
		low = minf(low, height)
		high = maxf(high, height)
	return high - low <= maxf(1.2, margin * 0.65)

func add_circle(id: String, point: Vector3, radius: float) -> void:
	var previous: Dictionary = obstacles.get(id, {})
	obstacles[id] = {"position": point, "radius": radius}
	_index(id)
	if not previous.is_empty(): _update_grid_area(previous)
	_update_grid_area(obstacles[id])
	revision += 1
	visibility_cache.clear()

func add_building(building) -> void:
	var previous: Dictionary = obstacles.get(building.id, {})
	obstacles[building.id] = {"position": building.position, "size": Vector2(building.size.x, building.size.z), "angle": building.rotation_y}
	_index(building.id)
	if not previous.is_empty(): _update_grid_area(previous)
	_update_grid_area(obstacles[building.id])
	revision += 1
	visibility_cache.clear()

func remove_obstacle(id: String) -> void:
	if not obstacles.has(id): return
	var previous: Dictionary = obstacles[id]
	obstacles.erase(id)
	# Bucket IDs may remain; queries skip them. No whole-world rebuild needed.
	_update_grid_area(previous)
	revision += 1
	visibility_cache.clear()

func _update_grid_area(item: Dictionary) -> void:
	if grid == null: return
	var point: Vector3 = item.position
	var radius: float = item.get("radius", Vector2(item.get("size", Vector2.ZERO)).length() * 0.5) + STEP * 2
	var start := Vector2i(floori((point.x - radius + half_size) / STEP), floori((point.z - radius + half_size) / STEP))
	var end := Vector2i(ceili((point.x + radius + half_size) / STEP), ceili((point.z + radius + half_size) / STEP))
	for z in range(maxi(0, start.y), mini(grid.region.end.y, end.y + 1)):
		for x in range(maxi(0, start.x), mini(grid.region.end.x, end.x + 1)):
			var id := Vector2i(x, z)
			var p := grid.get_point_position(id)
			grid.set_point_solid(id, not clear(Vector3(p.x, 0, p.y), STEP * 0.72 + GRID_CLEARANCE))

func _index(id: String) -> void:
	var item: Dictionary = obstacles[id]
	var p: Vector3 = item.position
	var r: float = item.get("radius", Vector2(item.get("size", Vector2.ZERO)).length() * 0.5) + 32.0
	for z in range(floori((p.z - r) / 64.0), floori((p.z + r) / 64.0) + 1):
		for x in range(floori((p.x - r) / 64.0), floori((p.x + r) / 64.0) + 1):
			var key := Vector2i(x, z)
			if not buckets.has(key): buckets[key] = []
			if not buckets[key].has(id): buckets[key].append(id)

func clear(point: Vector3, margin: float = CLEARANCE, ignore: String = "") -> bool:
	if not terrain_clear(point, margin): return false
	for id in _segment_obstacles(point, point, margin):
		if id == ignore or not obstacles.has(id): continue
		var item: Dictionary = obstacles[id]
		var local: Vector3 = point - Vector3(item.position)
		if item.has("radius"):
			if Vector2(local.x, local.z).length() < float(item.radius) + margin: return false
		else:
			local = local.rotated(Vector3.UP, -float(item.angle))
			if absf(local.x) < item.size.x * 0.5 + margin and absf(local.z) < item.size.y * 0.5 + margin: return false
	return true

func segment_clear(a: Vector3, b: Vector3, margin: float = CLEARANCE, ignore: String = "") -> bool:
	return _segment_clear_with(a, b, margin, _segment_obstacles(a, b, margin), ignore)

func _segment_clear_with(a: Vector3, b: Vector3, margin: float, candidates: Dictionary, ignore: String = "") -> bool:
	segment_queries += 1
	for id in candidates:
		if id != ignore and _obstacle_hit(a, b, obstacles[id], margin) < INF: return false
	var steps := maxi(1, ceili(Vector2(a.x - b.x, a.z - b.z).length() / 3.0))
	for i in range(steps + 1):
		if not terrain_clear(a.lerp(b, float(i) / steps), margin): return false
	return true

func _segment_obstacles(a: Vector3, b: Vector3, margin: float) -> Dictionary:
	# Walk the segment's bucket corridor, not the potentially huge diagonal AABB.
	var found := {}
	var count := maxi(1, ceili(Vector2(a.x - b.x, a.z - b.z).length() / 32.0))
	# Obstacles are indexed with 32 units of padding. The nearest sample is at
	# most 16 units away, leaving 16 units for the usual actor margins.
	var reach := maxi(0, ceili((margin - 16.0) / 64.0))
	var visited := {}
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		var center := Vector2i(floori(p.x / 64.0), floori(p.z / 64.0))
		for z in range(-reach, reach + 1):
			for x in range(-reach, reach + 1):
				var key := center + Vector2i(x, z)
				if visited.has(key): continue
				visited[key] = true
				for id in buckets.get(key, []):
					if obstacles.has(id): found[id] = true
	return found

func _obstacle_hit(a: Vector3, b: Vector3, item: Dictionary, margin: float) -> float:
	var origin: Vector3 = a - Vector3(item.position)
	var direction := b - a
	if item.has("radius"):
		var p := Vector2(origin.x, origin.z)
		var d := Vector2(direction.x, direction.z)
		var radius := float(item.radius) + margin
		var c := p.length_squared() - radius * radius
		if c < 0.0: return 0.0
		var length_sq := d.length_squared()
		if length_sq < 0.0000001: return INF
		# Perpendicular distance avoids subtracting two large quadratic terms.
		# That cancellation made a true tangent intermittently appear blocked
		# depending on segment length (and therefore on walk versus jog look-ahead).
		var length := sqrt(length_sq)
		var unit := d / length
		var projection := p.dot(unit)
		var perpendicular := p - unit * projection
		var discriminant := radius * radius - perpendicular.length_squared()
		if discriminant <= 0.0: return INF
		var t := (-projection - sqrt(discriminant)) / length
		if t >= 0.0 and t <= 1.0: return t
		return INF
	# Expanded box is conservative at corners; it never cuts through a footprint.
	origin = origin.rotated(Vector3.UP, -float(item.angle))
	direction = direction.rotated(Vector3.UP, -float(item.angle))
	var extent: Vector2 = item.size * 0.5 + Vector2.ONE * margin
	var enter := 0.0
	var leave := 1.0
	for axis in [0, 2]:
		var half: float = extent.x if axis == 0 else extent.y
		if absf(direction[axis]) < 0.000001:
			if absf(origin[axis]) >= half: return INF
		else:
			var t0: float = (-half - origin[axis]) / direction[axis]
			var t1: float = (half - origin[axis]) / direction[axis]
			enter = maxf(enter, minf(t0, t1))
			leave = minf(leave, maxf(t0, t1))
			if enter >= leave: return INF
	return enter

func first_obstruction(a: Vector3, b: Vector3, margin: float) -> Dictionary:
	var hit := {"fraction": INF, "id": ""}
	for id in _segment_obstacles(a, b, margin):
		var t := _obstacle_hit(a, b, obstacles[id], margin)
		if t < hit.fraction: hit = {"fraction": t, "id": id}
	return hit

func _build_grid() -> void:
	grid = AStarGrid2D.new()
	var count := ceili(half_size * 2.0 / STEP)
	grid.region = Rect2i(0, 0, count, count)
	grid.cell_size = Vector2.ONE * STEP
	grid.offset = Vector2.ONE * (-half_size + STEP * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(count):
		for x in range(count):
			var p := grid.get_point_position(Vector2i(x, z))
			grid.set_point_solid(Vector2i(x, z), not clear(Vector3(p.x, 0, p.y), STEP * 0.72 + GRID_CLEARANCE))

func _connected_grid_points(point: Vector3, margin: float) -> Array[Vector2i]:
	var center := Vector2i(floori((point.x + half_size) / STEP), floori((point.z + half_size) / STEP))
	var found: Array[Vector2i] = []
	for radius in range(5):
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var id := center + Vector2i(x, z)
				if not grid.region.has_point(id) or grid.is_point_solid(id): continue
				var p := grid.get_point_position(id)
				if segment_clear(point, Vector3(p.x, 0, p.y), margin): found.append(id)
		if found.size() >= 3: break
	return found

func route(start: Vector3, goal: Vector3, margin: float = CLEARANCE, approach_distance: float = 6.0) -> PackedVector3Array:
	last_route_kind = "blocked"
	if not clear(start, margin) or not clear(goal, margin): return PackedVector3Array()
	if segment_clear(start, goal, margin):
		last_route_kind = "direct"
		return PackedVector3Array([ground(goal)])
	var hit := first_obstruction(start, goal, margin)
	if hit.fraction < INF:
		var distance := _distance(start, goal)
		var approach := start.lerp(goal, maxf(0.0, float(hit.fraction) - maxf(2.0, approach_distance) / distance))
		if segment_clear(start, approach, margin):
			var local := _local_route(approach, goal, margin, str(hit.id))
			if not local.is_empty():
				if _distance(start, approach) > 0.05: local.insert(0, ground(approach))
				last_route_kind = "local"
				return local
	if grid == null: _build_grid()
	var result := _grid_route(start, goal, margin)
	if not result.is_empty():
		last_route_kind = "grid"
		return result
	result = _fine_route(start, goal, margin)
	if not result.is_empty(): last_route_kind = "fine"
	return result

func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func route_length(start: Vector3, path: PackedVector3Array) -> float:
	var length := 0.0
	for point in path:
		length += _distance(start, point)
		start = point
	return length

func _local_route(start: Vector3, goal: Vector3, margin: float, blocker: String) -> PackedVector3Array:
	if visibility_margin != margin or visibility_cache.size() > 8192:
		visibility_cache.clear()
		visibility_margin = margin
	var center: Vector3 = obstacles[blocker].position
	var radius: float = obstacles[blocker].get("radius", Vector2(obstacles[blocker].get("size", Vector2.ZERO)).length() * 0.5)
	var nearby: Array = _segment_obstacles(center - Vector3.ONE * (radius + 64), center + Vector3.ONE * (radius + 64), margin).keys()
	nearby.sort_custom(func(a, b):
		var da := _distance(center, obstacles[a].position)
		var db := _distance(center, obstacles[b].position)
		return str(a) < str(b) if is_equal_approx(da, db) else da < db)
	var points := PackedVector3Array([start, goal])
	for i in range(mini(LOCAL_OBSTACLES, nearby.size())):
		var item: Dictionary = obstacles[nearby[i]]
		var p: Vector3 = item.position
		if item.has("radius"):
			# Circumscribed polygon: even neighbouring ring chords clear the circle.
			var r := (float(item.radius) + margin + CORNER_PAD) / cos(PI / RING_POINTS)
			for j in range(RING_POINTS):
				var angle := TAU * j / RING_POINTS
				_add_candidate(points, p + Vector3(cos(angle), 0, sin(angle)) * r, margin)
			for endpoint in [start, goal]:
				var offset: Vector3 = endpoint - p
				var d := Vector2(offset.x, offset.z).length()
				if d <= r: continue
				var base := atan2(offset.z, offset.x)
				for side in [-1.0, 1.0]:
					var angle: float = base + side * acos(r / d)
					_add_candidate(points, p + Vector3(cos(angle), 0, sin(angle)) * r, margin)
		else:
			var size: Vector2 = item.size * 0.5 + Vector2.ONE * (margin + CORNER_PAD)
			for x in [-1, 1]:
				for z in [-1, 1]:
					_add_candidate(points, p + Vector3(x * size.x, 0, z * size.y).rotated(Vector3.UP, float(item.angle)), margin)
	# One conservative broad phase for the whole candidate graph. Repeating
	# bucket traversal for each visibility edge dominates clustered rock orders.
	var candidates := {}
	# Include the graph's full bounds: edges between candidates may leave both
	# endpoint corridors (e.g. the back of a concave building group).
	var low := Vector2(start.x, start.z)
	var high := low
	for point in points:
		low = low.min(Vector2(point.x, point.z))
		high = high.max(Vector2(point.x, point.z))
	for z in range(floori((low.y-margin)/64), floori((high.y+margin)/64)+1):
		for x in range(floori((low.x-margin)/64), floori((high.x+margin)/64)+1):
			for id in buckets.get(Vector2i(x,z), []):
				if obstacles.has(id): candidates[id] = true
	# Bounded A* over visibility edges. Goal is accepted when popped, so both
	# sides compete on full route cost, not first visible/first enumerated side.
	var costs := {0: 0.0}
	var parents := {}
	var open: Array[int] = [0]
	var closed := {}
	var edge_count := 0
	while not open.is_empty() and edge_count < LOCAL_EDGE_BUDGET:
		var best := open[0]
		for index in open:
			if float(costs[index]) + _distance(points[index], goal) < float(costs[best]) + _distance(points[best], goal): best = index
		open.erase(best)
		if best == 1:
			var path := PackedVector3Array()
			while best != 0:
				path.insert(0, ground(points[best]))
				best = parents[best]
			return path
		closed[best] = true
		for next in range(1, points.size()):
			if closed.has(next): continue
			var cost: float = costs[best] + _distance(points[best], points[next])
			if cost >= float(costs.get(next, INF)): continue
			edge_count += 1
			if edge_count > LOCAL_EDGE_BUDGET: break
			var a := points[best]
			var b := points[next]
			var key := Vector4(a.x, a.z, b.x, b.z) if a.x < b.x or (a.x == b.x and a.z < b.z) else Vector4(b.x, b.z, a.x, a.z)
			if not visibility_cache.has(key): visibility_cache[key] = _segment_clear_with(a, b, margin, candidates)
			if not visibility_cache[key]: continue
			costs[next] = cost
			parents[next] = best
			if not open.has(next): open.append(next)
	return PackedVector3Array()

func _add_candidate(points: PackedVector3Array, point: Vector3, margin: float) -> void:
	if clear(point, margin): points.append(point)

func _grid_route(start: Vector3, goal: Vector3, margin: float) -> PackedVector3Array:
	var starts := _connected_grid_points(start, margin)
	var goals := _connected_grid_points(goal, margin)
	starts.sort_custom(func(a, b): return grid.get_point_position(a).distance_squared_to(Vector2(start.x, start.z)) < grid.get_point_position(b).distance_squared_to(Vector2(start.x, start.z)))
	goals.sort_custom(func(a, b): return grid.get_point_position(a).distance_squared_to(Vector2(goal.x, goal.z)) < grid.get_point_position(b).distance_squared_to(Vector2(goal.x, goal.z)))
	var best := PackedVector3Array()
	var best_cost := INF
	# Nine connector pairs cap expensive global searches per request.
	for first in starts.slice(0, 3):
		for last in goals.slice(0, 3):
			var raw := grid.get_point_path(first, last)
			if raw.is_empty(): continue
			var candidate := PackedVector3Array()
			for p in raw: candidate.append(Vector3(p.x, 0, p.y))
			candidate.append(goal)
			var shortened := _shorten(start, candidate, margin)
			if shortened.is_empty(): continue
			var cost := route_length(start, shortened)
			if cost >= best_cost: continue
			best = shortened
			best_cost = cost
	return best

func _shorten(start: Vector3, path: PackedVector3Array, margin: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var index := 0
	while index < path.size():
		var next := path.size() - 1
		while next >= index and not segment_clear(start, path[next], margin): next -= 1
		if next < index: return PackedVector3Array()
		start = ground(path[next])
		result.append(start)
		index = next + 1
	return result

func _fine_route(start: Vector3, goal: Vector3, margin: float) -> PackedVector3Array:
	# Recovery for a coarse-grid gap. Never allocate a fine whole-world grid.
	const FINE_STEP := 4.0
	var low := Vector2(minf(start.x, goal.x), minf(start.z, goal.z)) - Vector2.ONE * 48
	low = (low / FINE_STEP).floor() * FINE_STEP
	var high := Vector2(maxf(start.x, goal.x), maxf(start.z, goal.z)) + Vector2.ONE * 48
	var size := Vector2i(ceili((high.x - low.x) / FINE_STEP) + 1, ceili((high.y - low.y) / FINE_STEP) + 1)
	if size.x > 129 or size.y > 129: return PackedVector3Array()
	var fine := AStarGrid2D.new()
	fine.region = Rect2i(Vector2i.ZERO, size)
	fine.offset = low
	fine.cell_size = Vector2.ONE * FINE_STEP
	fine.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	fine.update()
	for z in range(size.y):
		for x in range(size.x):
			var p := fine.get_point_position(Vector2i(x, z))
			fine.set_point_solid(Vector2i(x, z), not clear(Vector3(p.x, 0, p.y), margin))
	var connectors: Array = []
	for endpoint in [start, goal]:
		var nearest := Vector2i(roundi((endpoint.x - low.x) / FINE_STEP), roundi((endpoint.z - low.y) / FINE_STEP))
		var choices: Array[Vector2i] = []
		for z in range(-2, 3):
			for x in range(-2, 3):
				var id := nearest + Vector2i(x, z)
				if not fine.region.has_point(id) or fine.is_point_solid(id): continue
				var p := fine.get_point_position(id)
				if segment_clear(endpoint, Vector3(p.x, 0, p.y), margin): choices.append(id)
		choices.sort_custom(func(a, b): return fine.get_point_position(a).distance_squared_to(Vector2(endpoint.x, endpoint.z)) < fine.get_point_position(b).distance_squared_to(Vector2(endpoint.x, endpoint.z)))
		connectors.append(choices.slice(0, 3))
	var best := PackedVector3Array()
	var cost := INF
	for first in connectors[0]:
		for last in connectors[1]:
			var raw := fine.get_point_path(first, last)
			if raw.is_empty(): continue
			var path := PackedVector3Array()
			for p in raw: path.append(Vector3(p.x, 0, p.y))
			path.append(goal)
			path = _shorten(start, path, margin)
			if not path.is_empty() and route_length(start, path) < cost:
				best = path
				cost = route_length(start, path)
	return best
