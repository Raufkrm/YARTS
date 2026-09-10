extends SceneTree

const WorldStateScript = preload("res://scripts/data/world_state.gd")


func _init() -> void:
	var world = WorldStateScript.new()
	world.create_new(482931, 24, 12)
	world._ensure_river_map()
	var stats: Dictionary = world._river_generation_stats
	assert(int(stats["major"]) == WorldStateScript.RIVER_MAJOR_COUNT)
	assert(int(stats["sea_outlets"]) == WorldStateScript.RIVER_MAJOR_COUNT)
	_verify_river_limits(world)
	_verify_sources_and_polar_caps(world)
	var map_pixel_meters := 4000.0 * 24.0 / float(WorldStateScript.RIVER_MAP_WIDTH)
	var minor_width_meters := map_pixel_meters
	assert(minor_width_meters >= 80.0 and minor_width_meters <= 110.0)
	var connected_components := _count_river_components(world._river_map, WorldStateScript.RIVER_MAP_WIDTH, WorldStateScript.RIVER_MAP_HEIGHT, 0.20)
	assert(connected_components <= WorldStateScript.RIVER_MAJOR_COUNT)
	for validation_seed in [1001, 2002, 3003, 4004, 5005]:
		var validation_world = WorldStateScript.new()
		validation_world.create_new(validation_seed, 24, 12)
		validation_world._ensure_river_map()
		assert(int(validation_world._river_generation_stats["major"]) == WorldStateScript.RIVER_MAJOR_COUNT)
		assert(int(validation_world._river_generation_stats["sea_outlets"]) == WorldStateScript.RIVER_MAJOR_COUNT)
		_verify_river_limits(validation_world)
		_verify_sources_and_polar_caps(validation_world)
	print("Sparse river hierarchy verified: %d major, %d medium, %d small; %d valid mountain/snow sources; %d sea outlets; polar caps clear; small width %.1f m; components %d" % [
		int(stats["major"]),
		int(stats["medium"]),
		int(stats["minor"]),
		world._river_source_points.size(),
		int(stats["sea_outlets"]),
		minor_width_meters,
		connected_components,
	])
	quit()


func _verify_river_limits(world) -> void:
	var stats: Dictionary = world._river_generation_stats
	var medium_count := int(stats["medium"])
	var minor_count := int(stats["minor"])
	var total_count := int(stats["major"]) + medium_count + minor_count
	assert(medium_count <= WorldStateScript.RIVER_MEDIUM_COUNT)
	assert(minor_count <= WorldStateScript.RIVER_MINOR_COUNT)
	assert(total_count <= 9)


func _verify_sources_and_polar_caps(world) -> void:
	var expected_source_count: int = int(world._river_generation_stats["major"]) + int(world._river_generation_stats["medium"]) + int(world._river_generation_stats["minor"])
	assert(world._river_source_points.size() == expected_source_count)
	assert(int(world._river_generation_stats["invalid_sources"]) == 0)
	for source in world._river_source_points:
		assert(not world._river_grid_is_polar(source.y))
		assert(world._is_valid_river_source_point(source))
		var base: Dictionary = world._sample_base_layers(world._river_grid_direction(source.x, source.y))
		var terrain: String = world._terrain_for_layers(
			float(base["elevation"]),
			float(base["moisture"]),
			float(base["temperature"]),
			float(base["latitude_abs"])
		)
		assert(terrain == "mountains" or terrain == "snow")
	var polar_river_max := 0.0
	for y in range(WorldStateScript.RIVER_MAP_HEIGHT):
		if not world._river_grid_is_polar(y):
			continue
		for x in range(WorldStateScript.RIVER_MAP_WIDTH):
			polar_river_max = maxf(polar_river_max, world._river_map[y * WorldStateScript.RIVER_MAP_WIDTH + x])
	assert(polar_river_max <= 0.0001)


func _count_river_components(river_map: PackedFloat32Array, width: int, height: int, threshold: float) -> int:
	var visited := PackedByteArray()
	visited.resize(width * height)
	var component_count := 0
	for start_index in range(river_map.size()):
		if visited[start_index] != 0 or river_map[start_index] < threshold:
			continue
		var component_size := 0
		var pending: Array[int] = [start_index]
		visited[start_index] = 1
		while not pending.is_empty():
			var index: int = pending.pop_back()
			component_size += 1
			var x: int = index % width
			var y: int = index / width
			for y_offset in range(-1, 2):
				var next_y := y + y_offset
				if next_y < 0 or next_y >= height:
					continue
				for x_offset in range(-1, 2):
					if x_offset == 0 and y_offset == 0:
						continue
					var next_x := posmod(x + x_offset, width)
					var next_index := next_y * width + next_x
					if visited[next_index] != 0 or river_map[next_index] < threshold:
						continue
					visited[next_index] = 1
					pending.append(next_index)
		if component_size >= 8:
			component_count += 1
	return component_count
