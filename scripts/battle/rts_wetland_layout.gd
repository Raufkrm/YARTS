extends RefCounted
## Seeded cosmetic ecology, independent of the resource / forest RNG and IDs.
const STEP := 16.0
const MAX_POND_AREA := 180000.0
const MAX_POND_SPAN := 560.0
const MAX_PLANTS := 2400
const MAX_SWARMS := 32
const MAX_BODIES := 32
var host
var side := 0
var step := STEP
var half := 0.0
var wet := PackedByteArray()
var depth := PackedFloat32Array()
var clearance := PackedInt32Array()
var body_at := PackedInt32Array()
var bodies: Array[Dictionary] = []
var heights := PackedFloat32Array()
var row_length := 0
var rng := RandomNumberGenerator.new()

static func generate(scene, terrain_heights: PackedFloat32Array, terrain_row_length: int) -> Dictionary:
	var layout = new()
	layout.host = scene
	layout.heights = terrain_heights
	layout.row_length = terrain_row_length
	return layout.build()

func point(index: int) -> Vector2:
	return Vector2((index % side + 0.5) * step - half, (index / side + 0.5) * step - half)

func index_at(p: Vector2) -> int:
	var x := floori((p.x + half) / step)
	var z := floori((p.y + half) / step)
	return z * side + x if x >= 0 and z >= 0 and x < side and z < side else -1

func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var x := index % side
	var z := index / side
	if x > 0: result.append(index - 1)
	if x < side - 1: result.append(index + 1)
	if z > 0: result.append(index - side)
	if z < side - 1: result.append(index + side)
	return result

func sample(p: Vector2) -> Dictionary:
	return host._sample_cell_uv(p.x / (half * 2.0) + 0.5, p.y / (half * 2.0) + 0.5)

func ground(p: Vector2) -> float:
	return host._height_from_smoothed_terrain_at_uv(p.x / (half * 2.0) + 0.5, p.y / (half * 2.0) + 0.5, heights, row_length)

func is_wet(p: Vector2) -> bool:
	var data := sample(p)
	return (str(data.get("terrain", "")) == "water" or float(data.get("river", 0)) >= 0.42) and ground(p) < host.WATER_SURFACE_HEIGHT - 0.10

func build() -> Dictionary:
	half = host.MAP_SIZE * 0.5
	side = ceili(host.MAP_SIZE / STEP)
	step = host.MAP_SIZE / side
	var seed_value := 0
	if Game.world_state != null: seed_value = Game.world_state.seed
	rng.seed = seed_value + int(str(host.cell.id).hash()) + 741103
	wet.resize(side * side)
	depth.resize(wet.size())
	clearance.resize(wet.size())
	body_at.resize(wet.size())
	body_at.fill(-1)
	var queue: Array[int] = []
	for index in range(wet.size()):
		var p := point(index)
		var data := sample(p)
		depth[index] = host.WATER_SURFACE_HEIGHT - ground(p)
		if depth[index] > 0.10:
			if str(data.get("terrain", "")) == "water": wet[index] = 2
			elif float(data.get("river", 0)) >= 0.42: wet[index] = 1
		if wet[index] == 0:
			queue.append(index)
			clearance[index] = 0
		else: clearance[index] = side * 2
	# Distance to dry ground, also used to find safe fish-school centres.
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		for neighbor in neighbors(index):
			if clearance[neighbor] > clearance[index] + 1:
				clearance[neighbor] = clearance[index] + 1
				queue.append(neighbor)
	# Size distinguishes ponds from lakes; it must never exclude inland water.
	# Long thin river components stay rivers.
	for component in components(wet):
		if qualifies(component): add_body(component, freshwater_kind(component))
	# Erode narrow connections, then recover shore bands. This finds sheltered
	# lagoons and wider river pools without classifying an open coast as a pond.
	var core := PackedByteArray()
	core.resize(wet.size())
	for index in range(wet.size()):
		if wet[index] > 0 and clearance[index] >= 3 and body_at[index] < 0: core[index] = 1
	for component in components(core):
		if not qualifies(component): continue
		var recovered: Array = component.duplicate()
		var included := {}
		for index in recovered: included[index] = true
		var frontier: Array = component
		for band in range(2):
			var next: Array[int] = []
			for index in frontier:
				for neighbor in neighbors(index):
					if wet[neighbor] > 0 and body_at[neighbor] < 0 and not included.has(neighbor):
						included[neighbor] = true
						recovered.append(neighbor)
						next.append(neighbor)
			frontier = next
		if qualifies(recovered):
			var river_pool := false
			for index in component:
				if wet[index] == 1: river_pool = true; break
			add_body(recovered, freshwater_kind(recovered) if river_pool else "lagoon")
	var plants: Array[Dictionary] = []
	var fish: Array[Dictionary] = []
	var swarms: Array[Dictionary] = []
	for body in bodies:
		populate_body(body, plants, fish, swarms)
	# River-bank swarms share the same bounded, nighttime-only effect.
	var river_banks: Array[int] = []
	for index in range(wet.size()):
		if wet[index] == 1 and clearance[index] == 1 and body_at[index] < 0: river_banks.append(index)
	for attempt in range(mini(800, river_banks.size())):
		if swarms.size() >= MAX_SWARMS: break
		var index := river_banks[rng.randi_range(0, river_banks.size() - 1)]
		try_swarm(point(index), "river", swarms)
	# Runtime only needs compact placement records, not the flood-fill grids.
	var summaries: Array[Dictionary] = []
	for body in bodies:
		summaries.append({"id": body.id, "kind": body.kind, "center": body.center, "area": body.area, "fish_radius": body.fish_radius})
	return {"bodies": summaries, "plants": plants, "fish": fish, "swarms": swarms}

func components(mask: PackedByteArray) -> Array:
	var result: Array = []
	var visited := PackedByteArray()
	visited.resize(mask.size())
	for start in range(mask.size()):
		if mask[start] == 0 or visited[start] != 0: continue
		var queue: Array[int] = [start]
		visited[start] = 1
		var cursor := 0
		while cursor < queue.size():
			var index := queue[cursor]
			cursor += 1
			var adjacent := neighbors(index)
			# Corner connections still connect to the sea; do not invent ponds
			# from diagonally sampled pieces of an open shoreline.
			for dx in [-1, 1]:
				for dz in [-1, 1]:
					var x: int = index % side + dx
					var z: int = index / side + dz
					if x >= 0 and z >= 0 and x < side and z < side: adjacent.append(z * side + x)
			for neighbor in adjacent:
				if mask[neighbor] > 0 and visited[neighbor] == 0:
					visited[neighbor] = 1
					queue.append(neighbor)
		result.append(queue)
	return result

func qualifies(component: Array) -> bool:
	if component.size() < 4 or bodies.size() >= MAX_BODIES: return false
	var river_only := true
	for index in component:
		var p := Vector2(index % side, index / side)
		# An open sea component is not a lake, regardless of its size.
		if p.x == 0 or p.y == 0 or p.x == side - 1 or p.y == side - 1: return false
		if wet[index] == 2: river_only = false
	var span := component_span(component)
	return not river_only or maxf(span.x, span.y) / maxf(1.0, minf(span.x, span.y)) < 4.0

func component_span(component: Array) -> Vector2:
	var low := Vector2(side, side)
	var high := Vector2.ZERO
	for index in component:
		var p := Vector2(index % side, index / side)
		low = low.min(p)
		high = high.max(p)
	return (high - low + Vector2.ONE) * step

func freshwater_kind(component: Array) -> String:
	var span := component_span(component)
	return "pond" if component.size() * step * step <= MAX_POND_AREA and maxf(span.x, span.y) <= MAX_POND_SPAN else "lake"

func add_body(component: Array, kind: String) -> void:
	var best: int = component[0]
	var shore: Array[int] = []
	for index in component:
		if clearance[index] > clearance[best] or (clearance[index] == clearance[best] and depth[index] > depth[best]): best = index
		if clearance[index] == 1: shore.append(index)
	if shore.is_empty(): return
	var center := point(best)
	var radius := minf(28.0, clearance[best] * step * 0.45)
	# Exact radial probes shrink the school envelope at concave / narrow banks.
	while radius > 2.0 and not water_disc(center, radius): radius *= 0.7
	for index in component: body_at[index] = bodies.size()
	bodies.append({"id": "pond_%d_%d" % [best % side, best / side], "kind": kind, "center": center,
		"area": component.size() * step * step, "indices": component, "shore": shore, "fish_radius": radius})

func water_disc(center: Vector2, radius: float) -> bool:
	if not is_wet(center): return false
	for ring in [0.5, 1.0]:
		for direction in range(16):
			if not is_wet(center + Vector2.from_angle(direction * TAU / 16.0) * radius * ring): return false
	return true

func populate_body(body: Dictionary, plants: Array[Dictionary], fish: Array[Dictionary], swarms: Array[Dictionary]) -> void:
	var center: Vector2 = body.center
	# Give ponds, lakes and lagoons a small school using the existing ocean fish art.
	# The envelope is checked before spawning, and each orbit is checked at runtime.
	if body.fish_radius > 2.0:
		fish.append({"body_id": body.id, "position": Vector3(center.x, host.WATER_SURFACE_HEIGHT + 0.10, center.y), "radius": body.fish_radius})
	var shore: Array = body.shore
	var stride := maxi(1, ceili(shore.size() / 90.0))
	for cursor in range(0, shore.size(), stride):
		if plants.size() >= MAX_PLANTS: break
		var index: int = shore[cursor]
		var p := point(index)
		var dry := Vector2.ZERO
		for neighbor in neighbors(index):
			if wet[neighbor] == 0: dry += point(neighbor) - p
		if dry.length_squared() < 0.01: continue
		dry = dry.normalized()
		# Binary search the actual bank, rather than the coarse classification grid.
		var inside := p
		var outside := p + dry * step * 2.0
		if is_wet(outside): continue
		for iteration in range(7):
			var middle := inside.lerp(outside, 0.5)
			if is_wet(middle): inside = middle
			else: outside = middle
		var bank := inside.lerp(outside, 0.5)
		# Patchy bands outside, on and inside the shoreline. These have no collision.
		for band in [6.0, 0.0, -4.0]:
			for tuft in range(2):
				var q: Vector2 = bank + dry * band + Vector2(-dry.y, dry.x) * rng.randf_range(-6, 6)
				add_plant(plants, "high_grass", q, "outer" if band > 0 else ("inner" if band < 0 else "edge"))
		if rng.randf() < 0.72:
			add_plant(plants, "cattails", bank - dry * rng.randf_range(1.0, 4.0), "edge")
		if cursor % (stride * 9) == 0: try_swarm(bank + dry * 2.0, body.kind, swarms)
	var leaf_count := clampi(roundi(body.area / 850.0), 5, 70)
	for attempt in range(leaf_count * 4):
		if attempt >= leaf_count and plants.size() >= MAX_PLANTS: break
		var index: int = body.indices[rng.randi_range(0, body.indices.size() - 1)]
		var q := point(index) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		if not water_disc(q, 4.0): continue
		if clearance[index] > 4 and rng.randf() < 0.6: continue
		var asset: String = ["lilypad_round", "lilypad_white_flower", "lilypad_pink_cluster"][attempt % 3]
		if add_plant(plants, asset, q, "surface"): leaf_count -= 1
		if leaf_count <= 0: break

func add_plant(plants: Array[Dictionary], asset: String, p: Vector2, band: String) -> bool:
	if plants.size() >= MAX_PLANTS or absf(p.x) >= half - 8 or absf(p.y) >= half - 8: return false
	var data := sample(p)
	if str(data.get("terrain", "")) in ["snow", "tundra"] or str(data.get("biome", "")) == "polar_ice": return false
	var y := ground(p)
	if asset.begins_with("lilypad"):
		y = host.WATER_SURFACE_HEIGHT + 0.065
	else:
		# Never bury short grass beneath deep water or put cattails on a high cliff.
		if host.WATER_SURFACE_HEIGHT - y > 1.5 or y - host.WATER_SURFACE_HEIGHT > 3.0: return false
		y -= 0.035
	var size := rng.randf_range(0.82, 1.22) * 5.0
	plants.append({"asset": asset, "position": Vector3(p.x, y, p.y), "scale": size, "rotation": rng.randf() * TAU, "band": band})
	return true

func try_swarm(p: Vector2, habitat: String, swarms: Array[Dictionary]) -> void:
	if swarms.size() >= MAX_SWARMS: return
	var data := sample(p)
	if str(data.get("terrain", "")) in ["snow", "tundra"] or str(data.get("biome", "")) == "polar_ice": return
	for existing in swarms:
		if Vector2(existing.position.x, existing.position.z).distance_to(p) < 72.0: return
	var y := maxf(host.WATER_SURFACE_HEIGHT, ground(p)) + 3.5
	swarms.append({"position": Vector3(p.x, y, p.y), "habitat": habitat, "count": rng.randi_range(9, 14), "seed": rng.randi()})
