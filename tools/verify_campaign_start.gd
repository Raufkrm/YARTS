extends SceneTree

const WorldStateScript = preload("res://scripts/data/world_state.gd")


func _init() -> void:
	_verify_river_width_classes()
	_verify_thin_river_stamp_continuity()

	var sampled_colors := {}
	for color_seed in [1001, 2002, 3003, 4004, 5005, 6006]:
		var color_world = WorldStateScript.new()
		color_world.create_new(color_seed, 12, 6)
		for candidate in color_world.get_cells():
			if color_world.get_cell_water_coverage(str(candidate.id)) <= 0.90:
				assert(color_world.settle_starting_cell(str(candidate.id)))
				sampled_colors[color_world.get_faction_color("player").to_html(false)] = true
				break
	assert(sampled_colors.size() >= 3)

	var world = WorldStateScript.new()
	world.create_new(482931, 24, 12)
	var river_sources: Array = world._select_river_sources()
	assert(river_sources.size() == WorldStateScript.RIVER_MAJOR_COUNT)
	assert(int(world._river_generation_stats["major"]) == WorldStateScript.RIVER_MAJOR_COUNT)
	assert(int(world._river_generation_stats["medium"]) <= WorldStateScript.RIVER_MEDIUM_COUNT)
	assert(int(world._river_generation_stats["minor"]) <= WorldStateScript.RIVER_MINOR_COUNT)
	assert(int(world._river_generation_stats["sea_outlets"]) == WorldStateScript.RIVER_MAJOR_COUNT)
	assert(int(world._river_generation_stats["invalid_sources"]) == 0)
	var generated_river_count := int(world._river_generation_stats["major"]) + int(world._river_generation_stats["medium"]) + int(world._river_generation_stats["minor"])
	assert(generated_river_count <= 9)
	assert(world._river_source_points.size() == generated_river_count)
	assert(world.starting_cell_id.is_empty())
	assert(int(world.factions["player"]["intel"]) == 1)
	assert(int(world.factions["bandits"]["intel"]) == 1)

	var land_cell = null
	var water_cell = null
	for cell in world.get_cells():
		if world.get_cell_water_coverage(str(cell.id)) > 0.90 and water_cell == null:
			water_cell = cell
		elif world.get_cell_water_coverage(str(cell.id)) <= 0.90 and land_cell == null and world.get_neighbors(str(cell.id)).size() == 8:
			land_cell = cell
	assert(land_cell != null)
	assert(water_cell != null)
	assert(not world.settle_starting_cell(str(water_cell.id)))

	assert(world.settle_starting_cell(str(land_cell.id)))
	assert(str(land_cell.owner_id) == "player")
	assert(str(land_cell.status) == "settled")
	assert(world.is_cell_discovered(str(land_cell.id), "player"))
	var neighbors := world.get_neighbors(str(land_cell.id))
	assert(neighbors.size() <= 8)
	for neighbor in neighbors:
		assert(world.is_cell_discovered(str(neighbor.id), "player"))
	var discovered: Array = world.factions["player"]["discovered_cells"]
	assert(discovered.size() == neighbors.size() + 1)

	var player_color := world.get_faction_color("player")
	var player_rgb := Vector3(player_color.r, player_color.g, player_color.b)
	assert(player_rgb.distance_to(Vector3(1.0, 0.0, 0.0)) > 0.35)
	assert(player_rgb.distance_to(Vector3(0.0, 1.0, 0.0)) > 0.35)

	var restored = WorldStateScript.new()
	restored.load_from_dict(world.to_dict())
	assert(restored.starting_cell_id == world.starting_cell_id)
	assert(restored.is_cell_discovered(str(land_cell.id), "player"))
	assert(restored.get_cell(str(land_cell.id)).status == "settled")
	assert(restored.get_faction_color("player").is_equal_approx(player_color))

	print("Campaign start verified: cell=%s neighbors=%d color=#%s river_network=%d/%d/%d" % [
		land_cell.id,
		neighbors.size(),
		player_color.to_html(false),
		int(world._river_generation_stats["major"]),
		int(world._river_generation_stats["medium"]),
		int(world._river_generation_stats["minor"]),
	])
	quit()


func _verify_river_width_classes() -> void:
	var world = WorldStateScript.new()
	var major: Dictionary = world._river_width_profile_for_source(0)
	var medium: Dictionary = world._river_width_profile_for_source(WorldStateScript.RIVER_MAJOR_COUNT)
	var minor: Dictionary = world._river_width_profile_for_source(WorldStateScript.RIVER_MAJOR_COUNT + WorldStateScript.RIVER_MEDIUM_COUNT)
	assert(str(major["class"]) == "major")
	assert(str(medium["class"]) == "medium")
	assert(str(minor["class"]) == "minor")
	assert((major["radius"] as Vector2).y > (medium["radius"] as Vector2).y)
	assert((medium["radius"] as Vector2).y > (minor["radius"] as Vector2).y)
	assert(WorldStateScript.RIVER_SOURCE_COUNT == WorldStateScript.RIVER_MAJOR_COUNT)
	assert(WorldStateScript.RIVER_MEDIUM_COUNT == WorldStateScript.RIVER_MAJOR_COUNT * WorldStateScript.RIVER_MEDIUM_BRANCHES_PER_MAJOR)
	assert(WorldStateScript.RIVER_MINOR_COUNT == WorldStateScript.RIVER_MEDIUM_COUNT * WorldStateScript.RIVER_MINOR_BRANCHES_PER_MEDIUM)
	assert(WorldStateScript.RIVER_MAJOR_COUNT + WorldStateScript.RIVER_MEDIUM_COUNT + WorldStateScript.RIVER_MINOR_COUNT <= 9)
	var equatorial_map_pixel_meters := 4000.0 * 24.0 / float(WorldStateScript.RIVER_MAP_WIDTH)
	var minor_visible_width_meters := equatorial_map_pixel_meters
	assert(minor_visible_width_meters >= 80.0 and minor_visible_width_meters <= 110.0)


func _verify_thin_river_stamp_continuity() -> void:
	var world = WorldStateScript.new()
	world._river_map.resize(WorldStateScript.RIVER_MAP_WIDTH * WorldStateScript.RIVER_MAP_HEIGHT)
	world._river_map.fill(0.0)
	var radius := WorldStateScript.RIVER_MINOR_RADIUS.x
	world._stamp_river_segment(Vector2i(30, 250), Vector2i(36, 256), radius, radius, 0.72, 0.72)
	for step in range(25):
		var t := float(step) / 24.0
		var x := lerpf(30.0, 36.0, t)
		var y := lerpf(250.0, 256.0, t)
		var river := world._sample_river_map(
			(x + 0.5) / float(WorldStateScript.RIVER_MAP_WIDTH),
			(y + 0.5) / float(WorldStateScript.RIVER_MAP_HEIGHT)
		)
		assert(river > 0.35)

	world._river_map.fill(0.0)
	world._stamp_river_circle_float(48.5, 250.5, radius, 0.74)
	var corner_sample := world._sample_river_map(
		49.0 / float(WorldStateScript.RIVER_MAP_WIDTH),
		251.0 / float(WorldStateScript.RIVER_MAP_HEIGHT)
	)
	assert(corner_sample > 0.22)

	var bend_path: Array[Vector2i] = [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]
	var straight_radius := lerpf(radius, radius, 0.5)
	assert(world._river_radius_for_path_index(bend_path, 1, Vector2(radius, radius)) > straight_radius)
