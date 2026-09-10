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
const RIVER_MAP_WIDTH := 1024
const RIVER_MAP_HEIGHT := 512
const RIVER_MAJOR_COUNT := 3
const RIVER_MEDIUM_BRANCHES_PER_MAJOR := 1
const RIVER_MINOR_BRANCHES_PER_MEDIUM := 1
const RIVER_MEDIUM_COUNT := RIVER_MAJOR_COUNT * RIVER_MEDIUM_BRANCHES_PER_MAJOR
const RIVER_MINOR_COUNT := RIVER_MEDIUM_COUNT * RIVER_MINOR_BRANCHES_PER_MEDIUM
const RIVER_SOURCE_COUNT := RIVER_MAJOR_COUNT
const RIVER_SOURCE_CANDIDATES := 4200
const RIVER_SOURCE_MIN_SPACING := 180.0
const RIVER_SOURCE_MIN_ELEVATION := MOUNTAIN_LEVEL
const RIVER_MAX_ABS_LATITUDE := POLAR_SNOW_LATITUDE
const RIVER_SOURCE_CONNECT_RADIUS := 28
const RIVER_MAX_STEPS := 680
const RIVER_MIN_DROP := 0.0015
const RIVER_LAKE_RADIUS := 4.8
const RIVER_MIN_LAKE_PATH := 96
const RIVER_SEA_CONNECT_RADIUS := 72
const RIVER_FORCED_SEA_CONNECT_RADIUS := 220
const RIVER_MINOR_RADIUS := Vector2(0.26, 0.38)
const RIVER_MEDIUM_RADIUS := Vector2(0.68, 1.02)
const RIVER_MAJOR_RADIUS := Vector2(1.35, 2.20)
const RIVER_MINOR_VALUE := Vector2(0.74, 0.84)
const RIVER_MEDIUM_VALUE := Vector2(0.82, 0.94)
const RIVER_MAJOR_VALUE := Vector2(0.88, 1.0)
const RIVER_BEND_WIDENING := 0.18
const RIVER_STAMP_FEATHER := 0.22
const RIVER_RASTER_PIXEL_FOOTPRINT := 0.50
const RIVER_PATH_CONTROL_STRIDE := 6
const RIVER_CENTERLINE_MEANDER := 1.65
const RIVER_HEADWATER_FADE_RATIO := 0.10
const RIVER_MEDIUM_BRANCH_LENGTH := Vector2i(54, 96)
const RIVER_MINOR_BRANCH_LENGTH := Vector2i(24, 48)
const FACTION_COLOR_PALETTE := [
	"3568b8", # royal blue
	"2e7778", # muted teal
	"6650a4", # violet
	"984672", # blue magenta
	"712b4b", # blue red
	"682923", # dark red
	"a76d28", # ochre
	"81713a", # muted olive
	"3f7187", # steel cyan
	"4f4b86", # indigo
	"94503d", # terracotta
	"49663f", # forest green
]

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
var _river_generation_stats := {"major": 0, "medium": 0, "minor": 0, "sea_outlets": 0, "invalid_sources": 0}
var _river_source_points: Array[Vector2i] = []
var _cell_water_coverage_cache: Dictionary = {}
var factions := {
	"player": {
		"display_name": "Player Civilization",
		"color": "3568b8",
		"intel": 1,
		"discovered_cells": [],
	},
	"neutral": {
		"display_name": "Neutral",
		"color": "9aa0a6",
		"intel": 1,
		"discovered_cells": [],
	},
	"bandits": {
		"display_name": "Bandits",
		"color": "712b4b",
		"intel": 1,
		"discovered_cells": [],
	},
}


func create_new(new_seed: int = 0, new_width: int = 24, new_height: int = 12) -> void:
	seed = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	width = new_width
	height = new_height
	world_day = 1
	cells.clear()
	_cell_water_coverage_cache.clear()
	_rebuild_noise_layers()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y_index in range(height):
		var span := _row_cell_span(y_index)
		for x_index in range(0, width, span):
			var cell = CellDataScript.new()
			cell.x = x_index
			cell.y = y_index
			cell.x_span = span
			cell.id = "C%d_%d" % [x_index, y_index]
			_apply_generated_layers(cell)
			cell.owner_id = "neutral"
			cell.threat_level = rng.randi_range(1, 3)
			cell.settlement_name = ""
			cell.status = "unsettled"
			cell.resources = _resources_for_terrain(cell.terrain)
			cells[cell.id] = cell

	starting_cell_id = ""
	_reset_faction_progress()


func settle_starting_cell(cell_id: String, faction_id: String = "player") -> bool:
	var cell = get_cell(cell_id)
	if cell == null or get_cell_water_coverage(cell_id) > 0.90 or not starting_cell_id.is_empty():
		return false

	_ensure_faction(faction_id)
	assign_random_faction_color(faction_id, "%d:%s" % [seed, cell_id])
	cell.owner_id = faction_id
	cell.status = "settled"
	cell.threat_level = 0
	cell.settlement_name = "Cradle" if faction_id == "player" else "%s Settlement" % faction_display_name(faction_id)
	starting_cell_id = cell_id
	reveal_from_cell(faction_id, cell_id)
	return true


func get_cell_water_coverage(cell_id: String) -> float:
	if _cell_water_coverage_cache.has(cell_id):
		return float(_cell_water_coverage_cache[cell_id])
	var cell = get_cell(cell_id)
	if cell == null:
		return 1.0

	const SAMPLE_COLUMNS := 12
	const SAMPLE_ROWS := 8
	var water_samples := 0
	var bounds: Dictionary = get_cell_lat_lon_bounds(cell)
	for sample_y in range(SAMPLE_ROWS):
		var v := (float(sample_y) + 0.5) / float(SAMPLE_ROWS)
		var lat := lerpf(float(bounds["lat_top"]), float(bounds["lat_bottom"]), v)
		for sample_x in range(SAMPLE_COLUMNS):
			var u := (float(sample_x) + 0.5) / float(SAMPLE_COLUMNS)
			var lon := lerpf(float(bounds["lon_left"]), float(bounds["lon_right"]), u)
			var layers: Dictionary = _sample_base_layers(_direction_from_lat_lon(lat, lon))
			if float(layers.get("elevation", 0.0)) < SEA_LEVEL:
				water_samples += 1
	var coverage := float(water_samples) / float(SAMPLE_COLUMNS * SAMPLE_ROWS)
	_cell_water_coverage_cache[cell_id] = coverage
	return coverage


func reveal_from_cell(faction_id: String, cell_id: String) -> void:
	_ensure_faction(faction_id)
	var faction: Dictionary = factions[faction_id]
	var discovered: Array = faction.get("discovered_cells", []).duplicate()
	var seen := {}
	for known_id in discovered:
		seen[str(known_id)] = true

	var frontier: Array[String] = [cell_id]
	var intel: int = maxi(0, int(faction.get("intel", 1)))
	for depth in range(intel + 1):
		var next_frontier: Array[String] = []
		for current_id in frontier:
			if not seen.has(current_id):
				seen[current_id] = true
				discovered.append(current_id)
			if depth >= intel:
				continue
			for neighbor in get_neighbors(current_id):
				var neighbor_id := str(neighbor.id)
				if not seen.has(neighbor_id) and not next_frontier.has(neighbor_id):
					next_frontier.append(neighbor_id)
		frontier = next_frontier

	faction["discovered_cells"] = discovered
	factions[faction_id] = faction


func is_cell_discovered(cell_id: String, faction_id: String = "player") -> bool:
	if not factions.has(faction_id):
		return false
	var discovered: Array = factions[faction_id].get("discovered_cells", [])
	return discovered.has(cell_id)


func get_faction_color(faction_id: String) -> Color:
	if not factions.has(faction_id):
		return Color("9aa0a6")
	return Color.from_string(str(factions[faction_id].get("color", "9aa0a6")), Color("9aa0a6"))


func faction_display_name(faction_id: String) -> String:
	if not factions.has(faction_id):
		return faction_id.capitalize()
	return str(factions[faction_id].get("display_name", faction_id.capitalize()))


func assign_random_faction_color(faction_id: String, salt: String = "") -> Color:
	_ensure_faction(faction_id)
	var used_colors: Array[Color] = []
	for other_id in factions.keys():
		if str(other_id) == faction_id or str(other_id) == "neutral":
			continue
		used_colors.append(get_faction_color(str(other_id)))

	var color_rng := RandomNumberGenerator.new()
	color_rng.seed = int(seed) * 1103515245 + faction_id.hash() * 97 + salt.hash()
	var start_index := color_rng.randi_range(0, FACTION_COLOR_PALETTE.size() - 1)
	var best_color := Color.from_string(FACTION_COLOR_PALETTE[start_index], Color("3568b8"))
	var best_distance := -1.0
	for offset in range(FACTION_COLOR_PALETTE.size()):
		var candidate := Color.from_string(FACTION_COLOR_PALETTE[(start_index + offset) % FACTION_COLOR_PALETTE.size()], best_color)
		var minimum_distance := 10.0
		for used in used_colors:
			minimum_distance = minf(minimum_distance, _color_distance(candidate, used))
		if used_colors.is_empty() or minimum_distance >= 0.34:
			best_color = candidate
			break
		if minimum_distance > best_distance:
			best_distance = minimum_distance
			best_color = candidate

	var faction: Dictionary = factions[faction_id]
	faction["color"] = best_color.to_html(false)
	factions[faction_id] = faction
	return best_color


func _reset_faction_progress() -> void:
	for faction_id in factions.keys():
		var faction: Dictionary = factions[faction_id]
		faction["intel"] = 1
		faction["discovered_cells"] = []
		factions[faction_id] = faction


func _ensure_faction(faction_id: String) -> void:
	if not factions.has(faction_id):
		factions[faction_id] = {
			"display_name": faction_id.capitalize(),
			"color": "3568b8",
			"intel": 1,
			"discovered_cells": [],
		}
	var faction: Dictionary = factions[faction_id]
	if not faction.has("intel"):
		faction["intel"] = 1
	if not faction.has("discovered_cells"):
		faction["discovered_cells"] = []
	factions[faction_id] = faction


static func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _find_starting_land_cell(start_x: int, start_y: int) -> String:
	for y_index in range(start_y, height):
		var direct_cell = get_cell(cell_id_from_grid(start_x, y_index))
		if direct_cell != null and str(direct_cell.terrain) != "water":
			return str(direct_cell.id)
		for x_distance in range(1, width / 2 + 1):
			for x_direction in [-1, 1]:
				var candidate = get_cell(cell_id_from_grid(start_x + x_distance * x_direction, y_index))
				if candidate != null and str(candidate.terrain) != "water":
					return str(candidate.id)
	for cell_value in cells.values():
		if str(cell_value.terrain) != "water":
			return str(cell_value.id)
	return cell_id_from_grid(start_x, start_y)


func get_cell(cell_id: String):
	return cells.get(cell_id)


func get_cells() -> Array:
	return cells.values()


func conquer_cell(cell_id: String, owner_id: String) -> void:
	var cell = get_cell(cell_id)
	if cell == null:
		return

	cell.owner_id = owner_id
	cell.status = "settled"
	cell.threat_level = 0
	if cell.settlement_name.is_empty() and owner_id == "player":
		cell.settlement_name = "Outpost %s" % cell_id
	reveal_from_cell(owner_id, cell_id)


func get_neighbors(cell_id: String) -> Array:
	var cell = get_cell(cell_id)
	if cell == null:
		return []

	var neighbors: Array = []
	var seen := {}
	_add_neighbor(neighbors, seen, int(cell.x) + int(cell.x_span), int(cell.y))
	_add_neighbor(neighbors, seen, int(cell.x) - 1, int(cell.y))

	if int(cell.y) > 0:
		for x_index in range(int(cell.x) - 1, int(cell.x) + int(cell.x_span) + 1):
			_add_neighbor(neighbors, seen, x_index, int(cell.y) - 1)
	if int(cell.y) < height - 1:
		for x_index in range(int(cell.x) - 1, int(cell.x) + int(cell.x_span) + 1):
			_add_neighbor(neighbors, seen, x_index, int(cell.y) + 1)

	if neighbors.size() > 8:
		var center_direction := _direction_from_lat_lon(get_cell_center_lat_lon(cell).x, get_cell_center_lat_lon(cell).y)
		neighbors.sort_custom(func(a, b):
			var a_lat_lon := get_cell_center_lat_lon(a)
			var b_lat_lon := get_cell_center_lat_lon(b)
			var a_direction := _direction_from_lat_lon(a_lat_lon.x, a_lat_lon.y)
			var b_direction := _direction_from_lat_lon(b_lat_lon.x, b_lat_lon.y)
			return center_direction.dot(a_direction) > center_direction.dot(b_direction)
		)
		neighbors.resize(8)

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
	_cell_water_coverage_cache.clear()
	for faction_id in factions.keys():
		_ensure_faction(str(faction_id))
	cells.clear()

	for cell_data in data.get("cells", []):
		var cell = CellDataScript.new()
		cell.load_from_dict(cell_data)
		cells[cell.id] = cell
	if not starting_cell_id.is_empty() and not is_cell_discovered(starting_cell_id, "player"):
		reveal_from_cell("player", starting_cell_id)
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
	if absf(1.0 - uv.y * 2.0) >= RIVER_MAX_ABS_LATITUDE:
		return 0.0
	return _sample_river_map(uv.x, uv.y)


func _ensure_river_map() -> void:
	if _river_map.size() == RIVER_MAP_WIDTH * RIVER_MAP_HEIGHT:
		return
	_build_river_map()


func _build_river_map() -> void:
	_river_map = PackedFloat32Array()
	_river_map.resize(RIVER_MAP_WIDTH * RIVER_MAP_HEIGHT)
	_river_map.fill(0.0)
	_river_generation_stats = {"major": 0, "medium": 0, "minor": 0, "sea_outlets": 0, "invalid_sources": 0}
	_river_source_points.clear()

	var sources: Array = _select_river_sources()
	for source_index in range(mini(sources.size(), RIVER_MAJOR_COUNT)):
		var source: Dictionary = sources[source_index]
		var major_path: Array[Vector2i] = _trace_river_from_source(source, _river_width_profile_for_source(0))
		if major_path.size() < 7:
			continue
		_record_river_source(major_path)
		_river_generation_stats["major"] = int(_river_generation_stats["major"]) + 1
		if _river_path_reaches_sea(major_path):
			_river_generation_stats["sea_outlets"] = int(_river_generation_stats["sea_outlets"]) + 1
		_build_river_tributary_network(major_path, source_index)


func _build_river_tributary_network(major_path: Array[Vector2i], major_index: int) -> void:
	for medium_index in range(RIVER_MEDIUM_BRANCHES_PER_MAJOR):
		var medium_fraction := 0.56 if RIVER_MEDIUM_BRANCHES_PER_MAJOR == 1 else lerpf(0.42, 0.70, float(medium_index) / float(RIVER_MEDIUM_BRANCHES_PER_MAJOR - 1))
		var medium_side := -1 if (major_index + medium_index) % 2 == 0 else 1
		var medium_length := _river_branch_length(RIVER_MEDIUM_BRANCH_LENGTH, major_index * 37 + medium_index * 11)
		var medium_path := _build_upstream_tributary_path(
			major_path,
			medium_fraction,
			medium_side,
			medium_length,
			major_index * 101 + medium_index * 17 + 7001
		)
		if medium_path.size() < 7:
			continue
		_record_river_source(medium_path)
		_stamp_river_path(medium_path, _river_width_profile_for_source(RIVER_MAJOR_COUNT))
		_river_generation_stats["medium"] = int(_river_generation_stats["medium"]) + 1

		for minor_index in range(RIVER_MINOR_BRANCHES_PER_MEDIUM):
			var minor_fraction := 0.48 if RIVER_MINOR_BRANCHES_PER_MEDIUM == 1 else lerpf(0.24, 0.72, float(minor_index) / float(RIVER_MINOR_BRANCHES_PER_MEDIUM - 1))
			var minor_side := -1 if (major_index + medium_index + minor_index) % 2 == 0 else 1
			var minor_length := _river_branch_length(RIVER_MINOR_BRANCH_LENGTH, major_index * 71 + medium_index * 23 + minor_index * 7)
			var minor_path := _build_upstream_tributary_path(
				medium_path,
				minor_fraction,
				minor_side,
				minor_length,
				major_index * 307 + medium_index * 53 + minor_index * 19 + 17011
			)
			if minor_path.size() >= 6:
				_record_river_source(minor_path)
				_stamp_river_path(minor_path, _river_width_profile_for_source(RIVER_MAJOR_COUNT + RIVER_MEDIUM_COUNT))
				_river_generation_stats["minor"] = int(_river_generation_stats["minor"]) + 1


func _river_branch_length(length_range: Vector2i, salt: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) * 7919 + salt * 104729
	return rng.randi_range(length_range.x, length_range.y)


func _river_width_profile_for_source(source_index: int) -> Dictionary:
	if source_index < RIVER_MAJOR_COUNT:
		return {
			"class": "major",
			"radius": RIVER_MAJOR_RADIUS,
			"value": RIVER_MAJOR_VALUE,
		}
	if source_index < RIVER_MAJOR_COUNT + RIVER_MEDIUM_COUNT:
		return {
			"class": "medium",
			"radius": RIVER_MEDIUM_RADIUS,
			"value": RIVER_MEDIUM_VALUE,
		}
	return {
		"class": "minor",
		"radius": RIVER_MINOR_RADIUS,
		"value": RIVER_MINOR_VALUE,
	}


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
		var latitude_abs: float = float(base["latitude_abs"])
		if not _is_river_source_layers(elevation, float(base["temperature"]), latitude_abs):
			continue
		var score: float = elevation * 1.65 + float(base["ridge"]) * 0.38 + float(base["moisture"]) * 0.12 + rng.randf() * 0.05
		candidates.append({
			"x": x,
			"y": y,
			"score": score,
		})

	candidates.sort_custom(_sort_river_source_score_desc)
	var sources: Array = []
	var min_spacing: float = RIVER_SOURCE_MIN_SPACING
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


func _record_river_source(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	var source := path[0]
	_river_source_points.append(source)
	if not _is_valid_river_source_point(source):
		_river_generation_stats["invalid_sources"] = int(_river_generation_stats["invalid_sources"]) + 1


func _is_valid_river_source_point(point: Vector2i) -> bool:
	if point.x < 0 or point.y < 0 or point.y >= RIVER_MAP_HEIGHT or _river_grid_is_polar(point.y):
		return false
	var base := _sample_base_layers(_river_grid_direction(posmod(point.x, RIVER_MAP_WIDTH), point.y))
	return _is_river_source_layers(float(base["elevation"]), float(base["temperature"]), float(base["latitude_abs"]))


func _is_river_source_layers(elevation: float, temperature: float, latitude_abs: float) -> bool:
	if latitude_abs >= RIVER_MAX_ABS_LATITUDE or elevation < SEA_LEVEL:
		return false
	return elevation >= RIVER_SOURCE_MIN_ELEVATION or temperature < 0.20


func _river_grid_latitude_abs(y: int) -> float:
	var v := (float(y) + 0.5) / float(RIVER_MAP_HEIGHT)
	return absf(1.0 - v * 2.0)


func _river_grid_is_polar(y: int) -> bool:
	return y < 0 or y >= RIVER_MAP_HEIGHT or _river_grid_latitude_abs(y) >= RIVER_MAX_ABS_LATITUDE


func _trace_river_from_source(source: Dictionary, width_profile: Dictionary) -> Array[Vector2i]:
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
	if not reached_water and not connected_to_water and path.size() >= 5:
		var endpoint: Vector2i = path[path.size() - 1]
		var forced_target := _find_nearby_water_point(endpoint.x, endpoint.y, RIVER_FORCED_SEA_CONNECT_RADIUS)
		if forced_target.x < 0:
			forced_target = _find_nearest_water_point_global(endpoint.x, endpoint.y)
		if forced_target.x >= 0:
			_append_river_connection(path, endpoint, forced_target)
			connected_to_water = true
			ended_in_lake = false

	if path.size() < 5:
		return []

	_stamp_river_path(path, width_profile)

	if ended_in_lake and path.size() >= RIVER_MIN_LAKE_PATH:
		var endpoint: Vector2i = path[path.size() - 1]
		_stamp_river_circle(endpoint.x, endpoint.y, RIVER_LAKE_RADIUS, 0.92)
	return path


func _stamp_river_path(path: Array[Vector2i], width_profile: Dictionary) -> void:
	if path.is_empty():
		return
	var radius_range: Vector2 = width_profile.get("radius", RIVER_MINOR_RADIUS)
	var value_range: Vector2 = width_profile.get("value", RIVER_MINOR_VALUE)
	var smooth_path := _smoothed_river_path(path)
	for index in range(smooth_path.size()):
		var t: float = float(index) / maxf(float(smooth_path.size() - 1), 1.0)
		var source_fade := lerpf(0.45, 1.0, smoothstep(0.0, RIVER_HEADWATER_FADE_RATIO, t))
		var radius := lerpf(radius_range.x * 0.35, radius_range.y, t) * source_fade
		if index > 0 and index < smooth_path.size() - 1:
			var incoming := (smooth_path[index] - smooth_path[index - 1]).normalized()
			var outgoing := (smooth_path[index + 1] - smooth_path[index]).normalized()
			var turn_amount := 1.0 - clampf(incoming.dot(outgoing), -1.0, 1.0)
			radius *= 1.0 + turn_amount * RIVER_BEND_WIDENING
		var value := lerpf(value_range.x, value_range.y, t) * source_fade
		_stamp_river_circle_float(smooth_path[index].x, smooth_path[index].y, radius, value)


func _smoothed_river_path(path: Array[Vector2i]) -> Array[Vector2]:
	var controls: Array[Vector2] = []
	for path_index in range(0, path.size(), RIVER_PATH_CONTROL_STRIDE):
		_append_unwrapped_river_control(controls, path[path_index])
	if controls.is_empty() or Vector2(float(path[path.size() - 1].x), float(path[path.size() - 1].y)).distance_to(Vector2(fposmod(controls[controls.size() - 1].x, float(RIVER_MAP_WIDTH)), controls[controls.size() - 1].y)) > 0.01:
		_append_unwrapped_river_control(controls, path[path.size() - 1])
	if controls.size() <= 2:
		return controls

	var smooth: Array[Vector2] = []
	for control_index in range(controls.size() - 1):
		var p0: Vector2 = controls[maxi(control_index - 1, 0)]
		var p1: Vector2 = controls[control_index]
		var p2: Vector2 = controls[control_index + 1]
		var p3: Vector2 = controls[mini(control_index + 2, controls.size() - 1)]
		var substeps := maxi(int(ceil(p1.distance_to(p2) * 3.0)), 4)
		for substep in range(substeps):
			var t := float(substep) / float(substeps)
			smooth.append(_catmull_rom_river_point(p0, p1, p2, p3, t))
	smooth.append(controls[controls.size() - 1])
	return _apply_river_centerline_meander(smooth)


func _apply_river_centerline_meander(path: Array[Vector2]) -> Array[Vector2]:
	if path.size() < 5:
		return path
	var result := path.duplicate()
	var phase := float(posmod(int(seed) * 31 + int(path[0].x) * 17 + int(path[0].y) * 13, 997)) / 997.0 * TAU
	var distance_along := 0.0
	for index in range(1, path.size() - 1):
		distance_along += path[index - 1].distance_to(path[index])
		var tangent := (path[index + 1] - path[index - 1]).normalized()
		if tangent.length_squared() <= 0.001:
			continue
		var normal := Vector2(-tangent.y, tangent.x)
		var progress := float(index) / float(path.size() - 1)
		var endpoint_fade := smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.90, 1.0, progress))
		var wave := sin(distance_along * 0.18 + phase) * 0.68 + sin(distance_along * 0.073 + phase * 1.7) * 0.32
		result[index] += normal * wave * RIVER_CENTERLINE_MEANDER * endpoint_fade
	return result


func _append_unwrapped_river_control(controls: Array[Vector2], point: Vector2i) -> void:
	var control := Vector2(float(point.x), float(point.y))
	if not controls.is_empty():
		var previous: Vector2 = controls[controls.size() - 1]
		var dx := control.x - fposmod(previous.x, float(RIVER_MAP_WIDTH))
		if dx > float(RIVER_MAP_WIDTH) * 0.5:
			dx -= float(RIVER_MAP_WIDTH)
		elif dx < -float(RIVER_MAP_WIDTH) * 0.5:
			dx += float(RIVER_MAP_WIDTH)
		control.x = previous.x + dx
	controls.append(control)


func _catmull_rom_river_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)



func _build_upstream_tributary_path(
	parent_path: Array[Vector2i],
	attach_fraction: float,
	side: int,
	target_steps: int,
	salt: int
) -> Array[Vector2i]:
	if parent_path.size() < 7:
		return []
	var attach_index := clampi(int(round(attach_fraction * float(parent_path.size() - 1))), 2, parent_path.size() - 3)
	var confluence := parent_path[attach_index]
	var tangent_step := _wrapped_grid_delta(parent_path[attach_index - 2], parent_path[attach_index + 2])
	var tangent := Vector2(float(tangent_step.x), float(tangent_step.y)).normalized()
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.DOWN
	var lateral := Vector2(-tangent.y, tangent.x) * float(side)
	var outward := (-tangent * 0.72 + lateral * 0.69).normalized()
	var preferred_direction := outward.normalized()
	var reverse_path: Array[Vector2i] = [confluence]
	var visited := {"%d:%d" % [confluence.x, confluence.y]: true}
	var current := confluence
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) * 15485863 + salt * 32452843

	for step_index in range(target_steps):
		var current_base := _sample_base_layers(_river_grid_direction(current.x, current.y))
		var current_elevation := float(current_base["elevation"])
		var best := current
		var best_score := -INF
		var current_distance := Vector2(float(_wrapped_grid_delta(confluence, current).x), float(current.y - confluence.y)).length()
		for y_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				if x_offset == 0 and y_offset == 0:
					continue
				var next_y := current.y + y_offset
				if next_y <= 1 or next_y >= RIVER_MAP_HEIGHT - 2:
					continue
				if _river_grid_is_polar(next_y):
					continue
				var next_x := posmod(current.x + x_offset, RIVER_MAP_WIDTH)
				var key := "%d:%d" % [next_x, next_y]
				if visited.has(key):
					continue
				var next_base := _sample_base_layers(_river_grid_direction(next_x, next_y))
				var next_elevation := float(next_base["elevation"])
				if next_elevation <= SEA_LEVEL + 0.018:
					continue
				var candidate_direction := Vector2(float(x_offset), float(y_offset)).normalized()
				var alignment := candidate_direction.dot(preferred_direction)
				var outward_alignment := candidate_direction.dot(outward)
				var confluence_delta := _wrapped_grid_delta(confluence, Vector2i(next_x, next_y))
				var confluence_distance := Vector2(float(confluence_delta.x), float(confluence_delta.y)).length()
				if step_index >= 3 and confluence_distance + 0.20 < current_distance:
					continue
				var uphill_gain := next_elevation - current_elevation
				var existing_river := _river_map[next_y * RIVER_MAP_WIDTH + next_x]
				if step_index >= 4 and existing_river > 0.18:
					continue
				var terrain_noise := _normalized_noise(_river_noise, _river_grid_direction(next_x, next_y), 9.0) - 0.5
				var outward_pull := lerpf(0.22, 0.045, clampf(float(step_index) / maxf(float(target_steps), 1.0), 0.0, 1.0))
				var score := uphill_gain * 10.0 + alignment * 0.92 + outward_alignment * outward_pull
				score += terrain_noise * 0.07 + rng.randf_range(-0.012, 0.012)
				if step_index >= 4:
					score -= existing_river * 1.15
				if score > best_score:
					best_score = score
					best = Vector2i(next_x, next_y)
		if best == current:
			break
		visited["%d:%d" % [best.x, best.y]] = true
		var chosen_step := _wrapped_grid_delta(current, best)
		var chosen_direction := Vector2(float(chosen_step.x), float(chosen_step.y)).normalized()
		var turn_field := (_normalized_noise(_river_noise, _river_grid_direction(best.x, best.y), 4.2) - 0.5) * 0.11
		var turn_noise := rng.randf_range(-0.035, 0.035)
		preferred_direction = preferred_direction.rotated(turn_field + turn_noise).lerp(chosen_direction, 0.22).lerp(outward, 0.035).normalized()
		current = best
		reverse_path.append(current)

	if reverse_path.size() < 6:
		return []
	if not _ensure_river_source_in_highlands(reverse_path):
		return []
	reverse_path.reverse()
	return reverse_path


func _ensure_river_source_in_highlands(reverse_path: Array[Vector2i]) -> bool:
	if reverse_path.is_empty():
		return false
	var endpoint := reverse_path[reverse_path.size() - 1]
	if _is_valid_river_source_point(endpoint):
		return true
	var target := _find_nearby_river_source_point(endpoint.x, endpoint.y, RIVER_SOURCE_CONNECT_RADIUS)
	if target.x < 0:
		return false
	var connection := _river_connection_points(endpoint, target)
	if not _river_source_connection_is_clear(connection, reverse_path):
		return false
	reverse_path.append_array(connection)
	return _is_valid_river_source_point(reverse_path[reverse_path.size() - 1])


func _river_source_connection_is_clear(connection: Array[Vector2i], reverse_path: Array[Vector2i]) -> bool:
	var protected_path := {}
	for index in range(maxi(reverse_path.size() - 4, 0)):
		var point := reverse_path[index]
		protected_path["%d:%d" % [point.x, point.y]] = true
	for point in connection:
		if _river_grid_is_polar(point.y):
			return false
		if protected_path.has("%d:%d" % [point.x, point.y]):
			return false
		if _river_map[point.y * RIVER_MAP_WIDTH + point.x] > 0.18:
			return false
	return true


func _find_nearby_river_source_point(x: int, y: int, max_radius: int) -> Vector2i:
	for radius in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_elevation := -INF
		for x_offset in range(-radius, radius + 1):
			for y_offset in [-radius, radius]:
				var candidate := Vector2i(posmod(x + x_offset, RIVER_MAP_WIDTH), y + y_offset)
				var elevation := _river_source_candidate_elevation(candidate)
				if elevation > best_elevation:
					best_elevation = elevation
					best = candidate
		for y_offset in range(-radius + 1, radius):
			for x_offset in [-radius, radius]:
				var candidate := Vector2i(posmod(x + x_offset, RIVER_MAP_WIDTH), y + y_offset)
				var elevation := _river_source_candidate_elevation(candidate)
				if elevation > best_elevation:
					best_elevation = elevation
					best = candidate
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _river_source_candidate_elevation(point: Vector2i) -> float:
	if point.y < 0 or point.y >= RIVER_MAP_HEIGHT or _river_grid_is_polar(point.y):
		return -INF
	var base := _sample_base_layers(_river_grid_direction(point.x, point.y))
	var elevation := float(base["elevation"])
	return elevation if _is_river_source_layers(elevation, float(base["temperature"]), float(base["latitude_abs"])) else -INF


func _wrapped_grid_delta(from_point: Vector2i, to_point: Vector2i) -> Vector2i:
	var dx := to_point.x - from_point.x
	if dx > RIVER_MAP_WIDTH / 2:
		dx -= RIVER_MAP_WIDTH
	elif dx < -RIVER_MAP_WIDTH / 2:
		dx += RIVER_MAP_WIDTH
	return Vector2i(dx, to_point.y - from_point.y)


func _river_radius_for_path_index(path: Array[Vector2i], index: int, radius_range: Vector2) -> float:
	var t: float = float(index) / max(float(path.size() - 1), 1.0)
	var radius := lerpf(radius_range.x, radius_range.y, t)
	if index <= 0 or index >= path.size() - 1:
		return radius
	var incoming_step := _wrapped_step_delta(path[index - 1], path[index])
	var outgoing_step := _wrapped_step_delta(path[index], path[index + 1])
	var incoming := Vector2(float(incoming_step.x), float(incoming_step.y)).normalized()
	var outgoing := Vector2(float(outgoing_step.x), float(outgoing_step.y)).normalized()
	var turn_amount := 1.0 - clampf(incoming.dot(outgoing), -1.0, 1.0)
	return radius * (1.0 + turn_amount * RIVER_BEND_WIDENING)


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
	var meander_strength: float = lerpf(0.003, 0.011, abs(meander_wave))

	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			var next_y: int = clamp(y + y_offset, 1, RIVER_MAP_HEIGHT - 2)
			if _river_grid_is_polar(next_y):
				continue
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
			var meander: float = (_normalized_noise(_river_noise, direction, 12.0) - 0.5) * 0.006
			meander -= lateral_alignment * meander_strength
			meander -= max(straight_alignment, 0.0) * 0.012
			meander += max(-straight_alignment, 0.0) * 0.080
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


func _river_path_reaches_sea(path: Array[Vector2i]) -> bool:
	if path.is_empty():
		return false
	var endpoint := path[path.size() - 1]
	if _river_grid_is_polar(endpoint.y):
		return false
	var base := _sample_base_layers(_river_grid_direction(endpoint.x, endpoint.y))
	return float(base["elevation"]) <= SEA_LEVEL + 0.008


func _find_nearby_water_point(x: int, y: int, max_radius: int) -> Vector2i:
	for radius in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for x_offset in range(-radius, radius + 1):
			for y_offset in [-radius, radius]:
				var distance := _river_water_candidate_distance(x, y, x_offset, y_offset)
				if distance < best_distance:
					best_distance = distance
					best = Vector2i(posmod(x + x_offset, RIVER_MAP_WIDTH), y + y_offset)
		for y_offset in range(-radius + 1, radius):
			for x_offset in [-radius, radius]:
				var distance := _river_water_candidate_distance(x, y, x_offset, y_offset)
				if distance < best_distance:
					best_distance = distance
					best = Vector2i(posmod(x + x_offset, RIVER_MAP_WIDTH), y + y_offset)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _river_water_candidate_distance(x: int, y: int, x_offset: int, y_offset: int) -> float:
	var py := y + y_offset
	if py < 0 or py >= RIVER_MAP_HEIGHT or _river_grid_is_polar(py):
		return INF
	var px := posmod(x + x_offset, RIVER_MAP_WIDTH)
	var base := _sample_base_layers(_river_grid_direction(px, py))
	if float(base["elevation"]) > SEA_LEVEL + 0.008:
		return INF
	return Vector2(float(x_offset), float(y_offset)).length_squared()


func _find_nearest_water_point_global(x: int, y: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance: float = INF
	var search_stride := 4
	for py in range(0, RIVER_MAP_HEIGHT, search_stride):
		if _river_grid_is_polar(py):
			continue
		for px in range(0, RIVER_MAP_WIDTH, search_stride):
			var base := _sample_base_layers(_river_grid_direction(px, py))
			if float(base["elevation"]) > SEA_LEVEL + 0.008:
				continue
			var dx: int = abs(px - x)
			dx = mini(dx, RIVER_MAP_WIDTH - dx)
			var dy: int = py - y
			var distance: float = float(dx * dx + dy * dy)
			if distance < best_distance:
				best_distance = distance
				best = Vector2i(px, py)
	if best.x < 0:
		return best
	for y_offset in range(-search_stride, search_stride + 1):
		var py := best.y + y_offset
		if py < 0 or py >= RIVER_MAP_HEIGHT or _river_grid_is_polar(py):
			continue
		for x_offset in range(-search_stride, search_stride + 1):
			var px := posmod(best.x + x_offset, RIVER_MAP_WIDTH)
			var base := _sample_base_layers(_river_grid_direction(px, py))
			if float(base["elevation"]) > SEA_LEVEL + 0.008:
				continue
			var dx: int = abs(px - x)
			dx = mini(dx, RIVER_MAP_WIDTH - dx)
			var dy: int = py - y
			var distance: float = float(dx * dx + dy * dy)
			if distance < best_distance:
				best_distance = distance
				best = Vector2i(px, py)
	return best


func _append_river_connection(path: Array[Vector2i], from_point: Vector2i, to_point: Vector2i) -> void:
	for point in _river_connection_points(from_point, to_point):
		if path.is_empty() or path[path.size() - 1] != point:
			path.append(point)


func _river_connection_points(from_point: Vector2i, to_point: Vector2i) -> Array[Vector2i]:
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
	var connection: Array[Vector2i] = []
	for step in range(1, steps + 1):
		var t: float = float(step) / float(steps)
		var snake: float = sin(t * PI) * bend_noise + sin(t * TAU * 1.5) * 0.36
		var offset := lateral * snake * bend_strength
		var x: int = posmod(int(round(float(from_point.x) + float(dx) * t + offset.x)), RIVER_MAP_WIDTH)
		var y: int = clamp(int(round(float(from_point.y) + float(dy) * t + offset.y)), 0, RIVER_MAP_HEIGHT - 1)
		var point := Vector2i(x, y)
		if connection.is_empty() or connection[connection.size() - 1] != point:
			connection.append(point)
	return connection


func _stamp_river_segment(from_point: Vector2i, to_point: Vector2i, from_radius: float, to_radius: float, from_value: float, to_value: float) -> void:
	var dx: int = to_point.x - from_point.x
	if dx > RIVER_MAP_WIDTH / 2:
		dx -= RIVER_MAP_WIDTH
	elif dx < -RIVER_MAP_WIDTH / 2:
		dx += RIVER_MAP_WIDTH

	var dy: int = to_point.y - from_point.y
	var steps: int = max(max(abs(dx), abs(dy)) * 4, 4)
	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		var x: float = float(from_point.x) + float(dx) * t
		var y: float = clampf(float(from_point.y) + float(dy) * t, 0.0, float(RIVER_MAP_HEIGHT - 1))
		_stamp_river_circle_float(x, y, lerpf(from_radius, to_radius, t), lerpf(from_value, to_value, t))


func _stamp_river_circle(x: int, y: int, radius: float, value: float) -> void:
	_stamp_river_circle_float(float(x), float(y), radius, value)


func _stamp_river_circle_float(x: float, y: float, radius: float, value: float) -> void:
	var outer_radius := radius + RIVER_STAMP_FEATHER + RIVER_RASTER_PIXEL_FOOTPRINT
	var reach: int = int(ceil(outer_radius))
	var center_x := int(floor(x))
	var center_y := int(floor(y))
	for y_offset in range(-reach, reach + 1):
		var unwrapped_y := center_y + y_offset
		var py: int = unwrapped_y
		if py < 0 or py >= RIVER_MAP_HEIGHT or _river_grid_is_polar(py):
			continue
		for x_offset in range(-reach, reach + 1):
			var unwrapped_x := center_x + x_offset
			var px: int = posmod(unwrapped_x, RIVER_MAP_WIDTH)
			var distance: float = Vector2(float(unwrapped_x) - x, float(unwrapped_y) - y).length()
			if distance > outer_radius:
				continue
			var falloff: float = 1.0 - smoothstep(radius, outer_radius, distance)
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


static func _resources_for_terrain(_terrain: String) -> Dictionary:
	return {
		"food": 0,
		"wood": 0,
		"stone": 0,
		"metal": 0,
		"tools": 0,
		"weapons": 0,
		"supply": 0,
	}
