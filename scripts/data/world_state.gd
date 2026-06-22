class_name WorldState
extends Resource

const CellDataScript = preload("res://scripts/data/cell_data.gd")

const TERRAIN_TYPES := ["plains", "forest", "hills", "water", "mountains", "snow", "desert", "tundra"]
const SEA_LEVEL := 0.47
const HILL_LEVEL := 0.63
const MOUNTAIN_LEVEL := 0.74
const SNOW_LEVEL := 0.84
const POLAR_SNOW_LATITUDE := 0.82
const POLAR_MERGE_SPAN := 4
const RIVER_LOW_ELEVATION := SEA_LEVEL + 0.035
const RIVER_HIGH_ELEVATION := MOUNTAIN_LEVEL + 0.04
const RIVER_MAP_WIDTH := 512
const RIVER_MAP_HEIGHT := 256
const RIVER_SOURCE_COUNT := 56
const RIVER_SOURCE_CANDIDATES := 4200
const RIVER_SOURCE_MIN_ELEVATION := MOUNTAIN_LEVEL
const RIVER_MAX_STEPS := 340
const RIVER_MIN_DROP := 0.0015
const RIVER_LAKE_RADIUS := 2.4
const RIVER_MIN_LAKE_PATH := 48
const RIVER_SEA_CONNECT_RADIUS := 36

@export var seed := 0
@export var width := 5
@export var height := 5
@export var starting_cell_id := ""
@export var world_day := 1

var cells: Dictionary = {}
var _elevation_noise: FastNoiseLite
var _ridge_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _temperature_noise: FastNoiseLite
var _river_noise: FastNoiseLite
var _forest_noise: FastNoiseLite
var _river_map := PackedFloat32Array()
var factions := {
	"player": {
		"display_name": "Player Civilization",
		"color": "4f8cff",
	},
	"neutral": {
		"display_name": "Neutral",
		"color": "9aa0a6",
	},
	"bandits": {
		"display_name": "Bandits",
		"color": "d45b4f",
	},
}


func create_new(new_seed: int = 0, new_width: int = 24, new_height: int = 12) -> void:
	seed = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	width = new_width
	height = new_height
	world_day = 1
	cells.clear()
	_rebuild_noise_layers()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var start_x := int(width / 2)
	var start_y := int(height / 2)

	for y_index in range(height):
		var span := _row_cell_span(y_index)
		for x_index in range(0, width, span):
			var cell = CellDataScript.new()
			cell.x = x_index
			cell.y = y_index
			cell.x_span = span
			cell.id = "C%d_%d" % [x_index, y_index]
			_apply_generated_layers(cell)
			cell.owner_id = "player" if x_index == start_x and y_index == start_y else _starting_owner_for_cell(rng)
			cell.threat_level = 0 if cell.owner_id == "player" else rng.randi_range(1, 3)
			cell.settlement_name = "Cradle" if cell.owner_id == "player" else ""
			cell.resources = _resources_for_terrain(cell.terrain)
			cells[cell.id] = cell

	starting_cell_id = cell_id_from_grid(start_x, start_y)


func get_cell(cell_id: String):
	return cells.get(cell_id)


func get_cells() -> Array:
	return cells.values()


func conquer_cell(cell_id: String, owner_id: String) -> void:
	var cell = get_cell(cell_id)
	if cell == null:
		return

	cell.owner_id = owner_id
	cell.threat_level = 0
	if cell.settlement_name.is_empty() and owner_id == "player":
		cell.settlement_name = "Outpost %s" % cell_id


func get_neighbors(cell_id: String) -> Array:
	var cell = get_cell(cell_id)
	if cell == null:
		return []

	var neighbors: Array = []
	var seen := {}
	_add_neighbor(neighbors, seen, int(cell.x) + int(cell.x_span), int(cell.y))
	_add_neighbor(neighbors, seen, int(cell.x) - 1, int(cell.y))

	if int(cell.y) > 0:
		for x_index in range(int(cell.x), int(cell.x) + int(cell.x_span)):
			_add_neighbor(neighbors, seen, x_index, int(cell.y) - 1)
	if int(cell.y) < height - 1:
		for x_index in range(int(cell.x), int(cell.x) + int(cell.x_span)):
			_add_neighbor(neighbors, seen, x_index, int(cell.y) + 1)

	return neighbors


func cell_id_from_grid(x_index: int, y_index: int) -> String:
	var clamped_y: int = clamp(y_index, 0, height - 1)
	var span: int = _row_cell_span(clamped_y)
	var wrapped_x: int = posmod(x_index, width)
	var merged_x: int = wrapped_x - posmod(wrapped_x, span)
	return "C%d_%d" % [merged_x, clamped_y]


func get_cell_center_lat_lon(cell) -> Vector2:
	var span: int = int(cell.x_span)
	var lon: float = lerpf(-PI, PI, (float(cell.x) + float(span) * 0.5) / float(width))
	var lat: float = lerpf(PI / 2.0, -PI / 2.0, (float(cell.y) + 0.5) / float(height))
	return Vector2(lat, lon)


func direction_to_cell_id(direction: Vector3) -> String:
	var normalized := direction.normalized()
	var lat := asin(clamp(normalized.y, -1.0, 1.0))
	var lon := atan2(normalized.x, normalized.z)
	var x_index := int(floor(((lon + PI) / TAU) * float(width)))
	var y_index := int(floor(((PI / 2.0 - lat) / PI) * float(height)))
	return cell_id_from_grid(x_index, y_index)


func to_dict() -> Dictionary:
	var serialized_cells := []
	for cell in cells.values():
		serialized_cells.append(cell.to_dict())

	return {
		"seed": seed,
		"width": width,
		"height": height,
		"starting_cell_id": starting_cell_id,
		"world_day": world_day,
		"factions": factions.duplicate(true),
		"cells": serialized_cells,
	}


func load_from_dict(data: Dictionary) -> void:
	seed = int(data.get("seed", 0))
	width = int(data.get("width", 5))
	height = int(data.get("height", 5))
	starting_cell_id = data.get("starting_cell_id", "")
	world_day = int(data.get("world_day", 1))
	factions = data.get("factions", factions).duplicate(true)
	cells.clear()

	for cell_data in data.get("cells", []):
		var cell = CellDataScript.new()
		cell.load_from_dict(cell_data)
		cells[cell.id] = cell
	_rebuild_noise_layers()


static func _starting_owner_for_cell(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.18:
		return "bandits"
	return "neutral"


func get_cell_lat_lon_bounds(cell) -> Dictionary:
	return {
		"lon_left": lerpf(-PI, PI, float(cell.x) / float(width)),
		"lon_right": lerpf(-PI, PI, float(cell.x + cell.x_span) / float(width)),
		"lat_top": lerpf(PI / 2.0, -PI / 2.0, float(cell.y) / float(height)),
		"lat_bottom": lerpf(PI / 2.0, -PI / 2.0, float(cell.y + 1) / float(height)),
	}


func sample_cell(cell, u: float, v: float) -> Dictionary:
	var bounds: Dictionary = get_cell_lat_lon_bounds(cell)
	var lat: float = lerpf(float(bounds["lat_top"]), float(bounds["lat_bottom"]), clamp(v, 0.0, 1.0))
	var lon: float = lerpf(float(bounds["lon_left"]), float(bounds["lon_right"]), clamp(u, 0.0, 1.0))
	return sample_world(lat, lon)


func sample_world(lat: float, lon: float) -> Dictionary:
	return sample_direction(_direction_from_lat_lon(lat, lon))


func sample_direction(direction: Vector3) -> Dictionary:
	_ensure_noise_layers()
	var normal: Vector3 = direction.normalized()
	var base: Dictionary = _sample_base_layers(normal)
	var latitude_abs: float = float(base["latitude_abs"])
	var elevation: float = float(base["elevation"])
	var moisture: float = float(base["moisture"])
	var temperature: float = float(base["temperature"])
	var ridge: float = float(base["ridge"])
	var raw_noise: float = float(base["raw_noise"])
	var river: float = _river_amount_for_direction(normal, elevation)
	var terrain: String = _terrain_for_layers(elevation, moisture, temperature, latitude_abs, river)
	var climate: String = _climate_for_layers(elevation, moisture, temperature, latitude_abs)
	var biome: String = _biome_for_layers(terrain, elevation, moisture, temperature, latitude_abs)
	return {
		"direction": normal,
		"elevation": elevation,
		"moisture": moisture,
		"temperature": temperature,
		"ridge": ridge,
		"raw_noise": raw_noise,
		"river": river,
		"has_river": river > 0.52,
		"terrain": terrain,
		"biome": biome,
		"climate": climate,
	}


func _sample_base_layers(normal: Vector3) -> Dictionary:
	var latitude_abs: float = abs(normal.y)
	var continent_base: float = _normalized_noise(_elevation_noise, normal, 1.05)
	var continent_detail: float = _normalized_noise(_detail_noise, normal, 2.35)
	var continent: float = clamp(continent_base * 0.82 + continent_detail * 0.18, 0.0, 1.0)
	var landmass: float = smoothstep(0.35, 0.73, continent)
	var ridge_sample: float = _normalized_noise(_ridge_noise, normal, 4.8)
	var ridge: float = 1.0 - abs(ridge_sample * 2.0 - 1.0)
	var detail: float = _normalized_noise(_detail_noise, normal, 7.5)
	var fine_detail: float = _normalized_noise(_detail_noise, normal, 18.0)
	var ridge_land_mask: float = smoothstep(0.52, 0.82, continent)
	var raw_noise: float = clamp(continent * 0.66 + landmass * 0.20 + ridge * 0.09 + detail * 0.035 + fine_detail * 0.015, 0.0, 1.0)
	var elevation: float = clamp(continent * 0.56 + landmass * 0.32 + pow(ridge, 2.45) * 0.20 * ridge_land_mask + detail * 0.04 + fine_detail * 0.02 - latitude_abs * 0.035, 0.0, 1.0)
	var subtropical_dry_belt: float = 1.0 - smoothstep(0.0, 0.28, abs(latitude_abs - 0.34))
	var moisture: float = clamp(_normalized_noise(_moisture_noise, normal, 2.75) * 0.72 + _normalized_noise(_forest_noise, normal, 9.0) * 0.16 + (1.0 - latitude_abs) * 0.12 - subtropical_dry_belt * 0.22, 0.0, 1.0)
	var temperature: float = clamp(1.0 - pow(latitude_abs, 1.35), 0.0, 1.0)
	temperature += (_normalized_noise(_temperature_noise, normal, 2.5) - 0.5) * 0.18
	temperature += subtropical_dry_belt * 0.08
	temperature -= max(0.0, elevation - SEA_LEVEL) * 0.58
	temperature = clamp(temperature, 0.0, 1.0)
	return {
		"latitude_abs": latitude_abs,
		"elevation": elevation,
		"moisture": moisture,
		"temperature": temperature,
		"ridge": ridge,
		"raw_noise": raw_noise,
	}


func _river_amount_for_direction(normal: Vector3, elevation: float) -> float:
	if elevation < SEA_LEVEL - 0.018:
		return 0.0

	_ensure_river_map()
	var uv: Vector2 = _uv_from_direction(normal)
	return _sample_river_map(uv.x, uv.y)


func _ensure_river_map() -> void:
	if _river_map.size() == RIVER_MAP_WIDTH * RIVER_MAP_HEIGHT:
		return
	_build_river_map()


func _build_river_map() -> void:
	_river_map = PackedFloat32Array()
	_river_map.resize(RIVER_MAP_WIDTH * RIVER_MAP_HEIGHT)
	_river_map.fill(0.0)

	var sources: Array = _select_river_sources()
	for source_variant in sources:
		var source: Dictionary = source_variant
		_trace_river_from_source(source)


func _select_river_sources() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) + 880301
	var candidates: Array = []
	for index in range(RIVER_SOURCE_CANDIDATES):
		var x: int = rng.randi_range(0, RIVER_MAP_WIDTH - 1)
		var y: int = rng.randi_range(6, RIVER_MAP_HEIGHT - 7)
		var direction: Vector3 = _river_grid_direction(x, y)
		var base: Dictionary = _sample_base_layers(direction)
		var elevation: float = float(base["elevation"])
		if elevation < RIVER_SOURCE_MIN_ELEVATION:
			continue
		var latitude_abs: float = float(base["latitude_abs"])
		if latitude_abs > POLAR_SNOW_LATITUDE + 0.08:
			continue
		var score: float = elevation * 1.65 + float(base["ridge"]) * 0.38 + float(base["moisture"]) * 0.12 + rng.randf() * 0.05
		candidates.append({
			"x": x,
			"y": y,
			"score": score,
		})

	candidates.sort_custom(_sort_river_source_score_desc)
	var sources: Array = []
	var min_spacing: float = 22.0
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var spaced := true
		for source_variant in sources:
			var source: Dictionary = source_variant
			if _river_grid_distance_squared(int(candidate["x"]), int(candidate["y"]), int(source["x"]), int(source["y"])) < min_spacing * min_spacing:
				spaced = false
				break
		if not spaced:
			continue
		sources.append(candidate)
		if sources.size() >= RIVER_SOURCE_COUNT:
			break
	return sources


func _sort_river_source_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a["score"]) > float(b["score"])


func _trace_river_from_source(source: Dictionary) -> void:
	var x: int = int(source["x"])
	var y: int = int(source["y"])
	var path: Array[Vector2i] = []
	var visited: Dictionary = {}
	var ended_in_lake := false
	var reached_water := false
	var connected_to_water := false

	for step in range(RIVER_MAX_STEPS):
		var key: String = "%d:%d" % [x, y]
		if visited.has(key):
			connected_to_water = _try_connect_river_to_nearby_water(path, x, y)
			ended_in_lake = not connected_to_water
			break
		visited[key] = true
		path.append(Vector2i(x, y))

		var base: Dictionary = _sample_base_layers(_river_grid_direction(x, y))
		var elevation: float = float(base["elevation"])
		if elevation <= SEA_LEVEL + 0.006:
			reached_water = true
			break

		var previous_step := Vector2i.ZERO
		if path.size() >= 2:
			previous_step = _wrapped_step_delta(path[path.size() - 2], path[path.size() - 1])
		var next: Vector2i = _next_river_step(x, y, elevation, previous_step, step)
		if next.x == x and next.y == y:
			connected_to_water = _try_connect_river_to_nearby_water(path, x, y)
			ended_in_lake = not connected_to_water
			break
		x = next.x
		y = next.y

	if not reached_water and not connected_to_water and not ended_in_lake and path.size() >= 5:
		var endpoint: Vector2i = path[path.size() - 1]
		connected_to_water = _try_connect_river_to_nearby_water(path, endpoint.x, endpoint.y)
		ended_in_lake = not connected_to_water

	if path.size() < 5:
		return

	for index in range(path.size()):
		var t: float = float(index) / max(float(path.size() - 1), 1.0)
		var radius: float = lerpf(0.78, 0.92, t)
		var value: float = lerpf(0.72, 1.0, t)
		var point: Vector2i = path[index]
		if index == 0:
			_stamp_river_circle(point.x, point.y, radius, value)
		else:
			var previous: Vector2i = path[index - 1]
			_stamp_river_segment(previous, point, radius, value)

	if ended_in_lake and path.size() >= RIVER_MIN_LAKE_PATH:
		var endpoint: Vector2i = path[path.size() - 1]
		_stamp_river_circle(endpoint.x, endpoint.y, RIVER_LAKE_RADIUS, 0.92)


func _next_river_step(x: int, y: int, current_elevation: float, previous_step: Vector2i, step_index: int) -> Vector2i:
	var best := Vector2i(x, y)
	var best_score: float = INF
	var best_lower := false
	var carved_rise_limit: float = 0.010 if current_elevation < MOUNTAIN_LEVEL else 0.016
	var previous_direction := Vector2(float(previous_step.x), float(previous_step.y))
	var has_previous_direction := previous_direction.length_squared() > 0.0
	if has_previous_direction:
		previous_direction = previous_direction.normalized()
	var lateral_direction := Vector2(1.0, 0.0)
	if has_previous_direction:
		lateral_direction = Vector2(-previous_direction.y, previous_direction.x).normalized()
	var current_direction := _river_grid_direction(x, y)
	var meander_noise: float = _normalized_noise(_river_noise, current_direction, 3.25) * 2.0 - 1.0
	var meander_wave: float = sin(float(step_index) * 0.43 + meander_noise * TAU)
	var target_side: float = 1.0 if meander_wave >= 0.0 else -1.0
	var meander_strength: float = lerpf(0.006, 0.026, abs(meander_wave))

	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			var next_y: int = clamp(y + y_offset, 1, RIVER_MAP_HEIGHT - 2)
			var next_x: int = posmod(x + x_offset, RIVER_MAP_WIDTH)
			var direction: Vector3 = _river_grid_direction(next_x, next_y)
			var base: Dictionary = _sample_base_layers(direction)
			var elevation: float = float(base["elevation"])
			var is_lower := elevation <= current_elevation - RIVER_MIN_DROP
			var is_carvable := elevation <= current_elevation + carved_rise_limit
			if not is_lower and not is_carvable:
				continue
			var candidate_step := Vector2(float(x_offset), float(y_offset)).normalized()
			var lateral_alignment: float = candidate_step.dot(lateral_direction) * target_side
			var straight_alignment := 0.0
			if has_previous_direction:
				straight_alignment = candidate_step.dot(previous_direction)
			var meander: float = (_normalized_noise(_river_noise, direction, 12.0) - 0.5) * 0.014
			meander -= lateral_alignment * meander_strength
			meander += max(straight_alignment, 0.0) * 0.004
			meander += max(-straight_alignment, 0.0) * 0.034
			var diagonal_penalty: float = 0.0012 if x_offset != 0 and y_offset != 0 else 0.0
			var score: float = elevation + meander + diagonal_penalty
			if is_lower and not best_lower:
				best_lower = true
				best_score = score
				best = Vector2i(next_x, next_y)
			elif is_lower == best_lower and score < best_score:
				best_score = score
				best = Vector2i(next_x, next_y)
	return best


func _wrapped_step_delta(from_point: Vector2i, to_point: Vector2i) -> Vector2i:
	var dx: int = to_point.x - from_point.x
	if dx > RIVER_MAP_WIDTH / 2:
		dx -= RIVER_MAP_WIDTH
	elif dx < -RIVER_MAP_WIDTH / 2:
		dx += RIVER_MAP_WIDTH
	return Vector2i(signi(dx), signi(to_point.y - from_point.y))


func _try_connect_river_to_nearby_water(path: Array[Vector2i], x: int, y: int) -> bool:
	var target: Vector2i = _find_nearby_water_point(x, y, RIVER_SEA_CONNECT_RADIUS)
	if target.x < 0:
		return false
	_append_river_connection(path, Vector2i(x, y), target)
	return true


func _find_nearby_water_point(x: int, y: int, max_radius: int) -> Vector2i:
	for radius in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y_offset in range(-radius, radius + 1):
			var py: int = y + y_offset
			if py < 0 or py >= RIVER_MAP_HEIGHT:
				continue
			for x_offset in range(-radius, radius + 1):
				if abs(x_offset) != radius and abs(y_offset) != radius:
					continue
				var px: int = posmod(x + x_offset, RIVER_MAP_WIDTH)
				var base: Dictionary = _sample_base_layers(_river_grid_direction(px, py))
				if float(base["elevation"]) > SEA_LEVEL + 0.008:
					continue
				var distance: float = Vector2(float(x_offset), float(y_offset)).length_squared()
				if distance < best_distance:
					best_distance = distance
					best = Vector2i(px, py)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _append_river_connection(path: Array[Vector2i], from_point: Vector2i, to_point: Vector2i) -> void:
	var dx: int = to_point.x - from_point.x
	if dx > RIVER_MAP_WIDTH / 2:
		dx -= RIVER_MAP_WIDTH
	elif dx < -RIVER_MAP_WIDTH / 2:
		dx += RIVER_MAP_WIDTH

	var dy: int = to_point.y - from_point.y
	var steps: int = max(max(abs(dx), abs(dy)), 1)
	var distance: float = Vector2(float(dx), float(dy)).length()
	var lateral := Vector2(float(-dy), float(dx))
	if lateral.length_squared() > 0.0:
		lateral = lateral.normalized()
	var bend_noise: float = _normalized_noise(_river_noise, _river_grid_direction(from_point.x, from_point.y), 4.6) * 2.0 - 1.0
	var bend_strength: float = clamp(distance * 0.24, 2.0, 9.0)
	for step in range(1, steps + 1):
		var t: float = float(step) / float(steps)
		var snake: float = sin(t * PI) * bend_noise + sin(t * TAU * 1.5) * 0.36
		var offset := lateral * snake * bend_strength
		var x: int = posmod(int(round(float(from_point.x) + float(dx) * t + offset.x)), RIVER_MAP_WIDTH)
		var y: int = clamp(int(round(float(from_point.y) + float(dy) * t + offset.y)), 0, RIVER_MAP_HEIGHT - 1)
		var point := Vector2i(x, y)
		if path.is_empty() or path[path.size() - 1] != point:
			path.append(point)


func _stamp_river_segment(from_point: Vector2i, to_point: Vector2i, radius: float, value: float) -> void:
	var dx: int = to_point.x - from_point.x
	if dx > RIVER_MAP_WIDTH / 2:
		dx -= RIVER_MAP_WIDTH
	elif dx < -RIVER_MAP_WIDTH / 2:
		dx += RIVER_MAP_WIDTH

	var dy: int = to_point.y - from_point.y
	var steps: int = max(max(abs(dx), abs(dy)) * 2, 1)
	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		var x: int = posmod(int(round(float(from_point.x) + float(dx) * t)), RIVER_MAP_WIDTH)
		var y: int = clamp(int(round(float(from_point.y) + float(dy) * t)), 0, RIVER_MAP_HEIGHT - 1)
		_stamp_river_circle(x, y, radius, value)


func _stamp_river_circle(x: int, y: int, radius: float, value: float) -> void:
	var reach: int = int(ceil(radius))
	for y_offset in range(-reach, reach + 1):
		var py: int = y + y_offset
		if py < 0 or py >= RIVER_MAP_HEIGHT:
			continue
		for x_offset in range(-reach, reach + 1):
			var px: int = posmod(x + x_offset, RIVER_MAP_WIDTH)
			var distance: float = Vector2(float(x_offset), float(y_offset)).length()
			if distance > radius:
				continue
			var falloff: float = 1.0 - smoothstep(radius * 0.20, radius, distance)
			var index: int = py * RIVER_MAP_WIDTH + px
			_river_map[index] = max(_river_map[index], clamp(value * falloff, 0.0, 1.0))


func _sample_river_map(u: float, v: float) -> float:
	var x: float = fposmod(u * float(RIVER_MAP_WIDTH) - 0.5, float(RIVER_MAP_WIDTH))
	var y: float = clamp(v * float(RIVER_MAP_HEIGHT) - 0.5, 0.0, float(RIVER_MAP_HEIGHT - 1))
	var x0: int = int(floor(x))
	var y0: int = int(floor(y))
	var x1: int = posmod(x0 + 1, RIVER_MAP_WIDTH)
	var y1: int = min(y0 + 1, RIVER_MAP_HEIGHT - 1)
	var tx := x - float(x0)
	var ty := y - float(y0)
	var a: float = _river_map[y0 * RIVER_MAP_WIDTH + x0]
	var b: float = _river_map[y0 * RIVER_MAP_WIDTH + x1]
	var c: float = _river_map[y1 * RIVER_MAP_WIDTH + x0]
	var d: float = _river_map[y1 * RIVER_MAP_WIDTH + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _river_grid_direction(x: int, y: int) -> Vector3:
	var u: float = (float(x) + 0.5) / float(RIVER_MAP_WIDTH)
	var v: float = (float(y) + 0.5) / float(RIVER_MAP_HEIGHT)
	var lon: float = lerpf(-PI, PI, u)
	var lat: float = lerpf(PI / 2.0, -PI / 2.0, v)
	return _direction_from_lat_lon(lat, lon)


func _uv_from_direction(direction: Vector3) -> Vector2:
	var normal: Vector3 = direction.normalized()
	var lat: float = asin(clamp(normal.y, -1.0, 1.0))
	var lon: float = atan2(normal.x, normal.z)
	return Vector2(
		fposmod((lon + PI) / TAU, 1.0),
		clamp((PI / 2.0 - lat) / PI, 0.0, 1.0)
	)


func _river_grid_distance_squared(ax: int, ay: int, bx: int, by: int) -> float:
	var dx: int = abs(ax - bx)
	dx = min(dx, RIVER_MAP_WIDTH - dx)
	var dy: int = ay - by
	return float(dx * dx + dy * dy)


func _apply_generated_layers(cell) -> void:
	var sample: Dictionary = sample_cell(cell, 0.5, 0.5)
	cell.elevation = float(sample["elevation"])
	cell.moisture = float(sample["moisture"])
	cell.temperature = float(sample["temperature"])
	cell.climate = str(sample["climate"])
	cell.terrain = str(sample["terrain"])
	cell.biome = str(sample["biome"])


func _terrain_for_layers(elevation: float, moisture: float, temperature: float, latitude_abs: float, river: float = 0.0) -> String:
	if elevation < SEA_LEVEL:
		return "water"
	if elevation >= SNOW_LEVEL:
		return "snow"
	if latitude_abs >= POLAR_SNOW_LATITUDE and temperature < 0.30:
		return "snow"
	if elevation >= MOUNTAIN_LEVEL:
		return "mountains"
	if temperature < 0.20:
		return "snow"
	if temperature < 0.31:
		return "tundra"
	if moisture < 0.28 and temperature > 0.56:
		return "desert"
	if elevation >= HILL_LEVEL:
		return "hills"
	if moisture > 0.58:
		return "forest"
	return "plains"


func _biome_for_layers(terrain: String, elevation: float, moisture: float, temperature: float, latitude_abs: float) -> String:
	match terrain:
		"water":
			return "shallow_sea" if elevation > SEA_LEVEL - 0.06 else "ocean"
		"snow":
			if elevation >= MOUNTAIN_LEVEL:
				return "snowy_mountain"
			return "polar_ice" if latitude_abs >= POLAR_SNOW_LATITUDE else "snowfield"
		"mountains":
			return "cold_mountains" if temperature < 0.35 else "mountains"
		"tundra":
			return "tundra"
		"desert":
			return "hot_desert" if temperature > 0.68 else "dry_steppe"
		"hills":
			return "forested_hills" if moisture > 0.55 else "highlands"
		"forest":
			return "rainforest" if temperature > 0.68 and moisture > 0.72 else "temperate_forest"
		_:
			return "grassland"


func _climate_for_layers(elevation: float, moisture: float, temperature: float, latitude_abs: float) -> String:
	if latitude_abs >= POLAR_SNOW_LATITUDE:
		return "polar"
	if elevation >= MOUNTAIN_LEVEL:
		return "alpine"
	if moisture < 0.28 and temperature > 0.56:
		return "arid"
	if temperature < 0.32:
		return "cold"
	if temperature > 0.70:
		return "tropical"
	return "temperate"


func _add_neighbor(neighbors: Array, seen: Dictionary, x_index: int, y_index: int) -> void:
	if y_index < 0 or y_index >= height:
		return

	var neighbor_id := cell_id_from_grid(x_index, y_index)
	if seen.has(neighbor_id):
		return

	var neighbor = get_cell(neighbor_id)
	if neighbor == null:
		return

	seen[neighbor_id] = true
	neighbors.append(neighbor)


func _row_cell_span(y_index: int) -> int:
	if width % POLAR_MERGE_SPAN == 0 and (y_index == 0 or y_index == height - 1):
		return POLAR_MERGE_SPAN
	return 1


func _cell_center_direction(x_index: int, y_index: int, x_span: int = 1) -> Vector3:
	var lon: float = lerpf(-PI, PI, (float(x_index) + float(x_span) * 0.5) / float(width))
	var lat: float = lerpf(PI / 2.0, -PI / 2.0, (float(y_index) + 0.5) / float(height))
	var cos_lat := cos(lat)
	return Vector3(
		cos_lat * sin(lon),
		sin(lat),
		cos_lat * cos(lon)
	).normalized()


func _direction_from_lat_lon(lat: float, lon: float) -> Vector3:
	var cos_lat := cos(lat)
	return Vector3(
		cos_lat * sin(lon),
		sin(lat),
		cos_lat * cos(lon)
	).normalized()


func _rebuild_noise_layers() -> void:
	_elevation_noise = _make_noise(seed + 101, 0.82, 5)
	_ridge_noise = _make_noise(seed + 211, 1.18, 4)
	_detail_noise = _make_noise(seed + 307, 2.60, 4)
	_moisture_noise = _make_noise(seed + 409, 1.45, 4)
	_temperature_noise = _make_noise(seed + 503, 1.05, 3)
	_river_noise = _make_noise(seed + 607, 1.65, 5)
	_forest_noise = _make_noise(seed + 709, 2.2, 3)
	_river_map = PackedFloat32Array()


func _ensure_noise_layers() -> void:
	if _elevation_noise == null:
		_rebuild_noise_layers()


func _make_noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.48
	return noise


func _normalized_noise(noise: FastNoiseLite, direction: Vector3, scale: float) -> float:
	return clamp(noise.get_noise_3d(direction.x * scale, direction.y * scale, direction.z * scale) * 0.5 + 0.5, 0.0, 1.0)


static func _resources_for_terrain(terrain: String) -> Dictionary:
	var resource_map := {
		"food": 50,
		"wood": 50,
		"stone": 20,
		"metal": 0,
		"tools": 2,
		"weapons": 0,
		"supply": 25,
	}

	match terrain:
		"forest":
			resource_map["food"] = 80
			resource_map["wood"] = 160
		"hills":
			resource_map["stone"] = 110
			resource_map["metal"] = 25
		"mountains":
			resource_map["food"] = 35
			resource_map["wood"] = 35
			resource_map["stone"] = 180
			resource_map["metal"] = 55
			resource_map["supply"] = 18
		"snow":
			resource_map["food"] = 25
			resource_map["wood"] = 25
			resource_map["stone"] = 80
			resource_map["supply"] = 14
		"desert":
			resource_map["food"] = 35
			resource_map["wood"] = 20
			resource_map["stone"] = 70
			resource_map["supply"] = 16
		"tundra":
			resource_map["food"] = 45
			resource_map["wood"] = 55
			resource_map["stone"] = 45
			resource_map["supply"] = 18
		"water":
			resource_map["food"] = 120
			resource_map["wood"] = 20
			resource_map["supply"] = 15
		_:
			resource_map["food"] = 90
			resource_map["wood"] = 70

	return resource_map
