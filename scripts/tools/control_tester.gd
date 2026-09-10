extends "res://scripts/battle/battle_scene.gd"

const CellDataScript = preload("res://scripts/data/cell_data.gd")

const TEST_TERRAIN_STEPS := TERRAIN_STEPS
const TEST_TREES_PER_VARIANT := 2
const TEST_WATER_START_V := 0.73
const TEST_SHORE_START_V := 0.65
const TEST_RIVER_CENTER_U := 0.82
const TEST_RIVER_HALF_WIDTH := 0.032
const TEST_RIVER_START_V := 0.12
const TEST_SMALL_RIVER_CENTER_U := 0.63
const TEST_SMALL_RIVER_HALF_WIDTH := 0.010
const TEST_SMALL_RIVER_START_V := 0.16
const TEST_RESOURCE_START_X := -1325.0
const TEST_DEPOSIT_SIZES := ["small", "medium", "large"]
const TEST_RESOURCE_ASSETS := [
	{"type": "wood", "label": "Wood", "path": "res://assets/models/resources/resource_wood_logs.glb", "scale": 3.0},
	{"type": "stone", "label": "Stone", "path": "res://assets/models/resources/resource_stone_pile.glb", "scale": 3.2},
	{"type": "food", "label": "Food", "path": "res://assets/models/resources/resource_food_pot.glb", "scale": 3.0},
	{"type": "gold", "label": "Gold bars", "path": "res://assets/models/resources/resource_gold_bars.glb", "scale": 3.0},
	{"type": "flint", "label": "Flint", "path": "res://assets/models/details/flint_stone_01.glb", "scale": 3.2},
	{"type": "coal", "label": "Coal", "path": "res://assets/models/resources/ore_coal.glb", "scale": 3.0},
	{"type": "copper", "label": "Copper", "path": "res://assets/models/resources/ore_copper.glb", "scale": 3.0},
	{"type": "tin", "label": "Tin", "path": "res://assets/models/resources/ore_tin.glb", "scale": 3.0},
	{"type": "iron", "label": "Iron", "path": "res://assets/models/resources/ore_iron.glb", "scale": 3.0},
	{"type": "silver", "label": "Silver", "path": "res://assets/models/resources/ore_silver.glb", "scale": 3.0},
	{"type": "gold_ore", "label": "Gold ore", "path": "res://assets/models/resources/ore_gold.glb", "scale": 3.0},
	{"type": "uranium", "label": "Uranium", "path": "res://assets/models/resources/ore_uranium.glb", "scale": 3.0},
	{"type": "fish", "label": "Deep mixed fish shoal", "path": "res://assets/models/fish/quaternius_animated_fish_pack/fish_1.fbx", "scale": 0.25, "water": true, "water_x": -420.0, "water_z": 1650.0},
	{"type": "fish_shallow", "label": "Shallow fish school", "path": "res://assets/models/fish/quaternius_animated_fish_pack/fish_1.fbx", "scale": 0.18, "water": true, "water_x": 0.0, "water_z": 1120.0},
	{"type": "whale_oil", "label": "Whale oil pod", "path": "res://assets/models/fish/quaternius_animated_fish_pack/whale.fbx", "scale": 0.60, "water": true, "water_x": 420.0, "water_z": 1650.0},
]


func _ready() -> void:
	cell = _create_test_cell()
	_build_scene()
	_build_overlay()
	_refresh_overlay()
	_build_loading_overlay()
	call_deferred("_load_control_test_cell")


func _create_test_cell():
	var test_cell = CellDataScript.new()
	test_cell.id = "CONTROL_TEST"
	test_cell.owner_id = "player"
	test_cell.terrain = "plains"
	test_cell.biome = "interaction_range"
	test_cell.climate = "temperate"
	test_cell.elevation = WorldState.SEA_LEVEL + 0.12
	test_cell.moisture = 0.55
	test_cell.temperature = 0.56
	test_cell.settlement_name = "Control Test Range"
	test_cell.threat_level = 0
	test_cell.resources = {
		"food": 0,
		"wood": 0,
		"stone": 0,
		"metal": 0,
		"tools": 0,
		"weapons": 0,
		"supply": 0,
	}
	return test_cell


func _load_control_test_cell() -> void:
	_set_loading("Building deterministic interaction terrain...", 0.10)
	await get_tree().process_frame
	var data := _build_control_test_data()
	_set_loading("Spawning every tree family...", 0.58)
	await get_tree().process_frame
	_apply_rts_cell_data(data)
	_place_control_test_coastal_unit()
	_set_loading("Arranging harvestable resources...", 0.82)
	await get_tree().process_frame
	_spawn_control_test_resources()
	_spawn_control_test_labels()
	_rebuild_resource_ring_batches()
	_apply_minimap_data(data)
	_set_loading("Control test range ready", 1.0)
	await get_tree().process_frame
	_hide_loading_overlay()
	_refresh_overlay()


func _build_control_test_data() -> Dictionary:
	var props := _control_test_tree_props()
	return {
		"terrain_mesh": _build_control_test_terrain_mesh(),
		"water_mesh": _build_water_plane_mesh(),
		"river_mesh": _build_river_surface_mesh(),
		"grid_mesh": _build_terrain_grid_mesh(),
		"props": props,
		"minimap_texture": _build_minimap_texture(props),
		"center_height": _test_ground_height(0.5),
	}


func _build_control_test_terrain_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_length := TEST_TERRAIN_STEPS + 1
	var half_size := MAP_SIZE * 0.5

	for z_index in range(row_length):
		var v := float(z_index) / float(TEST_TERRAIN_STEPS)
		for x_index in range(row_length):
			var u := float(x_index) / float(TEST_TERRAIN_STEPS)
			var sample := _sample_cell_uv(u, v)
			vertices.append(Vector3(lerpf(-half_size, half_size, u), _height_from_sample(sample), lerpf(-half_size, half_size, v)))
			colors.append(_terrain_color_from_sample(sample))
			uvs.append(Vector2(u, v))

	for z_index in range(row_length):
		for x_index in range(row_length):
			var left_x := maxi(x_index - 1, 0)
			var right_x := mini(x_index + 1, TEST_TERRAIN_STEPS)
			var down_z := maxi(z_index - 1, 0)
			var up_z := mini(z_index + 1, TEST_TERRAIN_STEPS)
			var left_height := vertices[z_index * row_length + left_x].y
			var right_height := vertices[z_index * row_length + right_x].y
			var down_height := vertices[down_z * row_length + x_index].y
			var up_height := vertices[up_z * row_length + x_index].y
			normals.append(Vector3(left_height - right_height, MAP_SIZE / float(TEST_TERRAIN_STEPS) * 2.0, down_height - up_height).normalized())

	for z_index in range(TEST_TERRAIN_STEPS):
		for x_index in range(TEST_TERRAIN_STEPS):
			var base_index := z_index * row_length + x_index
			indices.append_array(PackedInt32Array([
				base_index,
				base_index + row_length,
				base_index + 1,
				base_index + 1,
				base_index + row_length,
				base_index + row_length + 1,
			]))

	return _mesh_from_arrays(vertices, normals, colors, uvs, indices)


func _sample_cell_uv_raw(u: float, v: float) -> Dictionary:
	var sample := {
		"terrain": "plains",
		"biome": "grassland",
		"elevation": WorldState.SEA_LEVEL + 0.12,
		"moisture": 0.56,
		"temperature": 0.56,
		"ridge": 0.45,
		"raw_noise": 0.50,
		"river": _control_test_river_amount(u, v),
	}
	if v >= TEST_WATER_START_V:
		var depth_ratio := inverse_lerp(TEST_WATER_START_V, 1.0, v)
		sample["terrain"] = "water"
		sample["biome"] = "shallow_sea"
		sample["elevation"] = WorldState.SEA_LEVEL - lerpf(0.015, 0.16, depth_ratio)
	elif v >= TEST_SHORE_START_V:
		var shore_ratio := inverse_lerp(TEST_SHORE_START_V, TEST_WATER_START_V, v)
		sample["terrain"] = "desert"
		sample["biome"] = "beach"
		sample["elevation"] = WorldState.SEA_LEVEL + lerpf(0.055, 0.006, shore_ratio)
		sample["moisture"] = 0.34
	return sample


func _control_test_river_amount(u: float, v: float) -> float:
	var main_center := _control_test_main_river_center(v)
	var main_source_fade := smoothstep(TEST_RIVER_START_V, TEST_RIVER_START_V + 0.09, v)
	var river := _control_test_river_band(u, main_center, TEST_RIVER_HALF_WIDTH) * main_source_fade

	var small_center := _control_test_small_river_center(v)
	var small_source_fade := smoothstep(TEST_SMALL_RIVER_START_V, TEST_SMALL_RIVER_START_V + 0.07, v)
	var small_river := _control_test_river_band(u, small_center, TEST_SMALL_RIVER_HALF_WIDTH) * small_source_fade
	return clampf(maxf(river, small_river), 0.0, 1.0)


func _control_test_main_river_center(v: float) -> float:
	return TEST_RIVER_CENTER_U + sin(v * TAU * 1.65) * 0.026


func _control_test_small_river_center(v: float) -> float:
	return TEST_SMALL_RIVER_CENTER_U + sin(v * TAU * 1.28 + 0.75) * 0.017


func _control_test_river_band(u: float, center_u: float, half_width: float) -> float:
	var distance := absf(u - center_u)
	return 1.0 - smoothstep(half_width * 0.42, half_width, distance)


func _place_control_test_coastal_unit() -> void:
	if battle_units.size() < 2:
		return
	var coastal_z := lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, TEST_SHORE_START_V - 0.018)
	var coastal_position := _ground_position_for_local(1040.0, coastal_z)
	var coastal_unit = battle_units[1]
	coastal_unit.position = coastal_position
	var coastal_actor = unit_actors_by_id.get(str(coastal_unit.id))
	if coastal_actor != null:
		coastal_actor.position = coastal_position


func _control_test_tree_props() -> Array:
	var props: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var tree_groups := [
		{"label": "Leaf", "assets": LEAF_TREE_ASSETS},
		{"label": "Conifer", "assets": CONIFER_TREE_ASSETS},
		{"label": "Snow conifer", "assets": SNOW_CONIFER_TREE_ASSETS},
		{"label": "Palm", "assets": PALM_TREE_ASSETS},
		{"label": "Dead", "assets": DEAD_TREE_ASSETS},
		{"label": "Snow dead", "assets": SNOW_DEAD_TREE_ASSETS},
	]
	var row_start_z := -1200.0
	var row_spacing := 240.0
	for group_index in range(tree_groups.size()):
		var group := tree_groups[group_index] as Dictionary
		var assets := group["assets"] as Array
		var column := 0
		for asset_value in assets:
			var asset_path := str(asset_value)
			for repeat_index in range(TEST_TREES_PER_VARIANT):
				var x := -940.0 + float(column) * 330.0 + float(repeat_index) * 105.0
				var z := row_start_z + float(group_index) * row_spacing
				props.append({
					"type": "tree",
					"asset": asset_path,
					"position": Vector3(x, _test_ground_height(inverse_lerp(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, z)), z),
					"scale": _tree_runtime_scale_for_asset(asset_path, rng),
					"rotation": rng.randf_range(-0.24, 0.24),
				})
			column += 1
	return props


func _spawn_control_test_resources() -> void:
	var columns := 6
	var spacing_x := 300.0
	var spacing_z := 245.0
	for index in range(TEST_RESOURCE_ASSETS.size()):
		var resource_data := TEST_RESOURCE_ASSETS[index] as Dictionary
		var column := index % columns
		var row: int = index / columns
		var base_position := Vector3(
			TEST_RESOURCE_START_X + float(column) * spacing_x,
			_test_ground_height(0.59 + float(row) * 0.04),
			360.0 + float(row) * spacing_z
		)
		var sizes: Array = ["medium"] if str(resource_data.get("type", "")) == "wood" else TEST_DEPOSIT_SIZES
		for size_index in range(sizes.size()):
			var size_offset := 0.0 if sizes.size() == 1 else float(size_index - 1)
			var position := base_position + Vector3(size_offset * 78.0, 0.0, 0.0)
			if bool(resource_data.get("water", false)):
				position = Vector3(
					float(resource_data.get("water_x", 0.0)) + size_offset * 135.0,
					WATER_SURFACE_HEIGHT + 0.10,
					float(resource_data.get("water_z", 1600.0))
				)
			_spawn_control_test_resource(resource_data, position, str(sizes[size_index]))


func _spawn_control_test_resource(resource_data: Dictionary, position: Vector3, deposit_size: String) -> void:
	var asset_path := str(resource_data.get("path", ""))
	var scale_value := float(resource_data.get("scale", 3.0))
	var test_resource_type := str(resource_data.get("type", "resource"))
	var resource_type := "fish" if test_resource_type == "fish_shallow" else test_resource_type
	var deposit_data := {
		"resource_type": resource_type,
		"deposit_size": deposit_size,
		"position": position,
		"scale": scale_value,
		"asset": asset_path,
		"amount": _resource_deposit_amount(resource_type),
		"harvest_amount": 1,
		"work_required": 1.4,
		"cluster_count": 7,
		"cluster_spread": 4.8,
		"show_ring": true,
	}
	if test_resource_type == "fish":
		deposit_data["assets"] = FISH_DEPOSIT_ASSETS
		deposit_data["amount"] = FISH_DEPOSIT_AMOUNT
		deposit_data["cluster_count"] = 24
		deposit_data["cluster_spread"] = 54.0
		deposit_data["visual_y_offset"] = -1.30
	elif test_resource_type == "fish_shallow":
		deposit_data["assets"] = FISH_DEPOSIT_ASSETS
		deposit_data["amount"] = SHALLOW_FISH_DEPOSIT_AMOUNT
		deposit_data["cluster_count"] = 8
		deposit_data["cluster_spread"] = 27.0
		deposit_data["visual_y_offset"] = -0.46
	elif resource_type == "whale_oil":
		deposit_data["assets"] = WHALE_OIL_DEPOSIT_ASSETS
		deposit_data["member_scale_multipliers"] = WHALE_OIL_MEMBER_SCALE_MULTIPLIERS
		deposit_data["amount"] = WHALE_OIL_DEPOSIT_AMOUNT
		deposit_data["cluster_count"] = 12
		deposit_data["cluster_spread"] = 28.0
		deposit_data["visual_y_offset"] = -1.15
		deposit_data["swim_speed_range"] = Vector2(0.18, 0.38)
		deposit_data["animation_speed"] = 0.88
	_spawn_resource_deposit(deposit_data)
	loaded_entity_count += 1
	full_model_entity_count += 1


func _spawn_control_test_labels() -> void:
	var tree_labels := ["Leaf trees", "Conifers", "Snow conifers", "Palms", "Dead trees", "Snow dead trees"]
	for index in range(tree_labels.size()):
		_add_test_label(str(tree_labels[index]), Vector3(-1320.0, 14.0, -1200.0 + float(index) * 240.0))
	for index in range(TEST_RESOURCE_ASSETS.size()):
		var resource_data := TEST_RESOURCE_ASSETS[index] as Dictionary
		if bool(resource_data.get("water", false)):
			_add_test_label(str(resource_data.get("label", "Resource")), Vector3(float(resource_data.get("water_x", 0.0)), 12.0, float(resource_data.get("water_z", 1600.0))))
			continue
		var column := index % 6
		var row: int = index / 6
		_add_test_label(str(resource_data.get("label", "Resource")), Vector3(TEST_RESOURCE_START_X + float(column) * 300.0, 12.0, 360.0 + float(row) * 245.0))
	_add_test_label("SOUTH WATER TEST", Vector3(0.0, 18.0, 1260.0), 22)
	var river_label_v := 0.46
	var river_label_u := _control_test_main_river_center(river_label_v)
	_add_test_label("RIVER SWIM TEST", Vector3(lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, river_label_u), 18.0, lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, river_label_v)), 20)
	var small_river_label_u := _control_test_small_river_center(river_label_v)
	_add_test_label("SMALL RIVER", Vector3(lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, small_river_label_u), 18.0, lerpf(-MAP_SIZE * 0.5, MAP_SIZE * 0.5, river_label_v)), 18)


func _add_test_label(text: String, position: Vector3, font_size: int = 16) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.outline_size = 5
	label.modulate = Color(0.90, 0.97, 0.91)
	label.outline_modulate = Color(0.02, 0.06, 0.04, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	terrain_root.add_child(label)


func _test_ground_height(v: float) -> float:
	return _height_from_sample(_sample_cell_uv_raw(0.5, clampf(v, 0.0, TEST_WATER_START_V - 0.01)))


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
