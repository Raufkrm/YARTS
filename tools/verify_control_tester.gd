extends SceneTree

const TEST_SCENE := "res://scenes/tools/control_tester.tscn"
const EXPECTED_UNITS := 2
const EXPECTED_TREES := 36
const EXPECTED_LOOSE_RESOURCES := 43
const MINIMUM_DEPOSIT_AMOUNT := 45
const ROCK_RESOURCE_TYPES := ["stone", "flint", "coal", "copper", "tin", "iron", "silver", "gold", "gold_ore", "uranium"]


func _init() -> void:
	call_deferred("_verify")


func _verify() -> void:
	root.size = Vector2i(960, 540)
	var packed_scene := load(TEST_SCENE) as PackedScene
	if packed_scene == null:
		_fail("Control tester scene could not be loaded")
		return

	var tester := packed_scene.instantiate()
	root.add_child(tester)
	var game = tester.get_node_or_null("/root/Game")
	if game == null:
		_fail("Game autoload is unavailable for cursor-state verification")
		return
	for frame in range(120):
		await process_frame

	var unit_count: int = tester.battle_units.size()
	var tree_count := 0
	var loose_resource_count := 0
	var animated_fish_found := false
	var shallow_fish_found := false
	var animated_whale_found := false
	var moving_fish: Node3D = null
	var moving_whale: Node3D = null
	var moving_fish_start := Vector3.ZERO
	var moving_whale_start := Vector3.ZERO
	var shallowest_fish_y := -INF
	var deepest_fish_y := INF
	var fish_source_paths: Dictionary = {}
	var whale_source_paths: Dictionary = {}
	var deep_fish_radius := 0.0
	var shallow_fish_radius := INF
	var stone_deposit = null
	var deposit_sizes_by_type: Dictionary = {}
	var grounded_rock_members := 0
	for resource in tester.resource_nodes_by_id.values():
		if resource == null:
			continue
		if str(resource.stage) == "standing_tree":
			tree_count += 1
		else:
			loose_resource_count += 1
			var resource_type := str(resource.resource_type)
			if resource_type != "fish" and resource_type != "whale_oil":
				var resource_u := inverse_lerp(-float(tester.MAP_SIZE) * 0.5, float(tester.MAP_SIZE) * 0.5, float(resource.world_position.x))
				var resource_v := inverse_lerp(-float(tester.MAP_SIZE) * 0.5, float(tester.MAP_SIZE) * 0.5, float(resource.world_position.z))
				if float(tester._control_test_river_amount(resource_u, resource_v)) > 0.05:
					_fail("Land resource %s overlaps control-test river water" % resource_type)
					return
			if resource_type != "wood":
				if not deposit_sizes_by_type.has(resource_type):
					deposit_sizes_by_type[resource_type] = {}
				var sizes_for_type := deposit_sizes_by_type[resource_type] as Dictionary
				sizes_for_type[str(resource.deposit_size)] = true
			if int(resource.amount_remaining) < MINIMUM_DEPOSIT_AMOUNT:
				_fail("Resource %s only has %d units" % [str(resource.resource_type), int(resource.amount_remaining)])
				return
			if resource_type in ROCK_RESOURCE_TYPES:
				var rock_root := resource.visual_node as Node3D
				if rock_root != null:
					for member_value in rock_root.get_children():
						var rock_member := member_value as Node3D
						if rock_member == null:
							continue
						var surface_y := float(tester._terrain_surface_height_for_local(rock_member.global_position.x, rock_member.global_position.z))
						var member_bounds := tester._combined_local_bounds(rock_member) as Dictionary
						var member_bottom_y := rock_member.global_position.y
						if bool(member_bounds.get("valid", false)):
							member_bottom_y += float((member_bounds["min"] as Vector3).y) * rock_member.scale.y
						if member_bottom_y > surface_y + 0.01:
							_fail("Resource %s has a floating %s member" % [resource_type, str(resource.deposit_size)])
							return
						grounded_rock_members += 1
			if resource_type == "fish":
				var fish_root := resource.visual_node as Node3D
				if fish_root != null and fish_root.get_child_count() >= 20:
					deep_fish_radius = float(resource.visual_radius)
					moving_fish = fish_root.get_child(0) as Node3D
					if moving_fish != null:
						moving_fish_start = moving_fish.position
					for fish_value in fish_root.get_children():
						var fish_member := fish_value as Node3D
						if fish_member == null:
							continue
						fish_source_paths[fish_member.scene_file_path] = true
						shallowest_fish_y = maxf(shallowest_fish_y, fish_member.position.y)
						deepest_fish_y = minf(deepest_fish_y, fish_member.position.y)
					for candidate in fish_root.find_children("*", "AnimationPlayer", true, false):
						var player := candidate as AnimationPlayer
						if player != null and not player.current_animation.is_empty():
							animated_fish_found = true
							break
				elif fish_root != null and fish_root.get_child_count() >= 6 and fish_root.get_child_count() <= 11:
					shallow_fish_found = true
					shallow_fish_radius = float(resource.visual_radius)
			elif resource_type == "whale_oil":
				var whale_root := resource.visual_node as Node3D
				if whale_root != null and whale_root.get_child_count() >= 10:
					moving_whale = whale_root.get_child(0) as Node3D
					if moving_whale != null:
						moving_whale_start = moving_whale.position
					for whale_value in whale_root.get_children():
						var whale_member := whale_value as Node3D
						if whale_member != null:
							whale_source_paths[whale_member.scene_file_path] = true
					for candidate in whale_root.find_children("*", "AnimationPlayer", true, false):
						var player := candidate as AnimationPlayer
						if player != null and not player.current_animation.is_empty():
							animated_whale_found = true
							break
			elif resource_type == "stone":
				stone_deposit = resource

	var water: Node = tester.terrain_root.get_node_or_null("StillOceanWater")
	var river_water: Node = tester.terrain_root.get_node_or_null("RiverWater")
	print("CONTROL_TEST units=%d trees=%d resources=%d water=%s" % [unit_count, tree_count, loose_resource_count, str(water != null)])
	if unit_count != EXPECTED_UNITS:
		_fail("Expected %d units, found %d" % [EXPECTED_UNITS, unit_count])
		return
	if tester.context_panel == null or tester.context_panel.grow_vertical != Control.GROW_DIRECTION_BEGIN:
		_fail("Expected the bottom-left HUD panel to grow upward from its anchored bottom edge")
		return
	var hud_test_unit = tester.battle_units[0]
	var hud_test_unit_id := str(hud_test_unit.id)
	game.set_thing_selected_cursor_active(false)
	game.set_interact_order_cursor_active(true)
	if game.get_active_cursor_name() != "default":
		_fail("Expected resource interaction mode to retain the dark default cursor without a selected human")
		return
	game.reset_order_cursor()
	tester._set_selected_unit(hud_test_unit_id, hud_test_unit, tester.unit_nodes_by_id.get(hud_test_unit_id) as Node3D)
	if game.get_active_cursor_name() != "thing_selected":
		_fail("Expected the former default cursor after selecting a human")
		return
	game.set_interact_order_cursor_active(true)
	if game.get_active_cursor_name() != "interact":
		_fail("Expected the interact cursor when a selected human can use a resource")
		return
	game.reset_order_cursor()
	tester._refresh_context_panel()
	await process_frame
	await process_frame
	var context_rect: Rect2 = tester.context_panel.get_global_rect()
	var viewport_rect: Rect2 = tester.get_viewport().get_visible_rect()
	if context_rect.position.x < 0.0 or context_rect.position.y < 0.0 or context_rect.end.x > viewport_rect.end.x or context_rect.end.y > viewport_rect.end.y:
		_fail("Expected the expanded bottom-left HUD panel to remain completely inside the viewport (panel=%s viewport=%s)" % [str(context_rect), str(viewport_rect)])
		return
	if tree_count != EXPECTED_TREES:
		_fail("Expected %d trees, found %d" % [EXPECTED_TREES, tree_count])
		return
	if loose_resource_count != EXPECTED_LOOSE_RESOURCES:
		_fail("Expected %d loose resources, found %d" % [EXPECTED_LOOSE_RESOURCES, loose_resource_count])
		return
	if water == null:
		_fail("Expected the southern water mesh")
		return
	if river_water == null:
		_fail("Expected a separate flowing river mesh in the control test")
		return
	var water_instance := water as MeshInstance3D
	var water_material := water_instance.material_override as ShaderMaterial
	if water_material == null or float(water_material.get_shader_parameter("wave_height")) < 1.0:
		_fail("Expected visible ocean wave displacement in the control test")
		return
	var river_instance := river_water as MeshInstance3D
	var river_material := river_instance.material_override as ShaderMaterial
	if river_instance.mesh.get_surface_count() <= 0 or river_material == null or not bool(river_material.get_shader_parameter("use_river_flow")):
		_fail("Expected the control river to use its own flowing-water material")
		return
	var main_v := 0.46
	var main_u: float = tester._control_test_main_river_center(main_v)
	if float(tester._control_test_river_amount(main_u, main_v)) < 0.90:
		_fail("Expected the control test's major river center to remain filled")
		return
	var small_width: float = tester.TEST_SMALL_RIVER_HALF_WIDTH
	for river_v in [0.26, 0.34, 0.46, 0.58]:
		var small_u: float = tester._control_test_small_river_center(river_v)
		if float(tester._control_test_river_amount(small_u, river_v)) < 0.90:
			_fail("Expected the separate small river to remain continuous through its bends")
			return
		if float(tester._control_test_river_amount(small_u - small_width * 1.35, river_v)) > 0.10 or float(tester._control_test_river_amount(small_u + small_width * 1.35, river_v)) > 0.10:
			_fail("Expected the separate small river to retain narrow banks")
			return
		var main_channel_u: float = tester._control_test_main_river_center(river_v)
		var dry_gap_u := (small_u + main_channel_u) * 0.5
		if float(tester._control_test_river_amount(dry_gap_u, river_v)) > 0.05:
			_fail("Expected dry land between the separate small and major rivers")
			return
	if float(river_material.get_shader_parameter("wave_height")) >= float(water_material.get_shader_parameter("wave_height")) * 0.30:
		_fail("Expected river ripples to remain much smaller than sea waves")
		return
	if float(water_material.get_shader_parameter("low_poly_strength")) < 0.80:
		_fail("Expected ocean lighting to retain a strong low-poly faceted normal")
		return
	if float(river_material.get_shader_parameter("low_poly_strength")) >= float(water_material.get_shader_parameter("low_poly_strength")):
		_fail("Expected river facets to remain subtler than ocean facets")
		return
	var river_shallow_color := river_material.get_shader_parameter("shallow_water_color") as Color
	var ocean_shallow_color := water_material.get_shader_parameter("shallow_water_color") as Color
	if river_shallow_color.get_luminance() <= ocean_shallow_color.get_luminance() * 1.35:
		_fail("Expected rivers to remain visibly lighter than the sea")
		return
	if int(tester.RIVER_SURFACE_STEPS) <= int(tester.WATER_PLANE_STEPS):
		_fail("Expected the river surface to use denser subdivision than the sea")
		return
	if int(tester.TEST_TERRAIN_STEPS) < int(tester.TERRAIN_STEPS):
		_fail("Expected the control tester terrain to retain production terrain resolution")
		return
	if float(tester.RIVER_MESH_EDGE_ALPHA) <= 0.0:
		_fail("Expected a positive river contour clipping threshold")
		return
	var river_arrays := river_instance.mesh.surface_get_arrays(0)
	var river_vertices := river_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var river_grid_step := float(tester.MAP_SIZE) / float(tester.RIVER_SURFACE_STEPS)
	var river_half_size := float(tester.MAP_SIZE) * 0.5
	var found_subcell_shore_vertex := false
	for vertex in river_vertices:
		var grid_x := (vertex.x + river_half_size) / river_grid_step
		var grid_z := (vertex.z + river_half_size) / river_grid_step
		if absf(grid_x - roundf(grid_x)) > 0.001 or absf(grid_z - roundf(grid_z)) > 0.001:
			found_subcell_shore_vertex = true
			break
	if not found_subcell_shore_vertex:
		_fail("Expected river shoreline clipping to create vertices between whole grid points")
		return
	var expected_river_height := float(tester.WATER_SURFACE_HEIGHT) + 0.04
	for vertex in river_vertices:
		if absf(vertex.y - expected_river_height) > 0.001:
			_fail("Expected clipped river shoreline vertices to remain at the water surface instead of drooping beneath coarse terrain")
			return
	var water_arrays := water_instance.mesh.surface_get_arrays(0)
	var water_vertices := water_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var water_colors := water_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var water_indices := water_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if water_indices.size() >= int(tester.WATER_PLANE_STEPS) * int(tester.WATER_PLANE_STEPS) * 6:
		_fail("Expected dry inland water cells to be removed from the ocean mesh")
		return
	var found_drooped_shore := false
	var found_transparent_shore := false
	for vertex_index in range(water_vertices.size()):
		if water_vertices[vertex_index].y <= float(tester.WATER_SURFACE_HEIGHT) - 0.45:
			found_drooped_shore = true
		if water_colors[vertex_index].a <= 0.01:
			found_transparent_shore = true
		if found_drooped_shore and found_transparent_shore:
			break
	if not found_drooped_shore or not found_transparent_shore:
		_fail("Expected shoreline water vertices to lower and fade beneath dry terrain")
		return
	if not tester._is_water_surface_sample({"terrain": "plains", "river": 0.72}):
		_fail("Expected river channels to remain included in the clipped water mesh")
		return
	if tester._is_water_surface_sample({"terrain": "plains", "river": 0.0}):
		_fail("Expected ordinary dry land to stay outside the water mesh")
		return
	var river_probe_v := 0.46
	var river_probe_u: float = float(tester.TEST_RIVER_CENTER_U) + sin(river_probe_v * TAU * 1.65) * 0.026
	var river_probe := tester._sample_cell_uv_raw(river_probe_u, river_probe_v) as Dictionary
	if str(river_probe.get("terrain", "water")) == "water" or float(river_probe.get("river", 0.0)) < 0.90:
		_fail("Expected a strong inland river channel in the control test")
		return
	var coastal_unit_found := false
	for actor_value in tester.unit_actors_by_id.values():
		var actor_v := inverse_lerp(-float(tester.MAP_SIZE) * 0.5, float(tester.MAP_SIZE) * 0.5, float(actor_value.position.z))
		if absf(actor_v - (float(tester.TEST_SHORE_START_V) - 0.018)) < 0.01:
			coastal_unit_found = true
			break
	if not coastal_unit_found:
		_fail("Expected one of the two control-test humans beside the coast")
		return
	for resource_type_value in deposit_sizes_by_type.keys():
		var resource_type := str(resource_type_value)
		var sizes_for_type := deposit_sizes_by_type[resource_type] as Dictionary
		for expected_size in ["small", "medium", "large"]:
			if not sizes_for_type.has(expected_size):
				_fail("Expected %s to have a %s deposit variant" % [resource_type, expected_size])
				return
	if grounded_rock_members < 30:
		_fail("Expected grounded members across all solid resource deposits")
		return
	if not animated_fish_found:
		_fail("Expected an animated fish shoal with at least twenty visible fish")
		return
	if not shallow_fish_found:
		_fail("Expected a smaller shallow-water fish school")
		return
	if fish_source_paths.size() < 3:
		_fail("Expected the fish node to mix all three supplied fish models")
		return
	if not animated_whale_found or whale_source_paths.size() < 3:
		_fail("Expected an animated whale-oil pod with mixed marine models")
		return
	if shallowest_fish_y - deepest_fish_y < 0.55:
		_fail("Expected fish to occupy visibly different depth layers")
		return
	if shallowest_fish_y > -0.65:
		_fail("Expected the deep shoal to remain clearly below the water surface")
		return
	if shallow_fish_radius >= deep_fish_radius:
		_fail("Expected shallow-water schools to be smaller than offshore shoals")
		return
	for frame in range(30):
		await process_frame
	if moving_fish == null or moving_fish.position.distance_to(moving_fish_start) < 0.20:
		_fail("Expected fish to swim through the shoal area")
		return
	if moving_whale == null or moving_whale.position.distance_to(moving_whale_start) < 0.08:
		_fail("Expected the whale-oil pod to swim through its resource area")
		return
	var heading_sample_start := moving_fish.position
	await process_frame
	var heading_movement := moving_fish.position - heading_sample_start
	var fish_forward := moving_fish.transform.basis.z
	if heading_movement.length_squared() <= 0.0001 or fish_forward.normalized().dot(heading_movement.normalized()) < 0.90:
		_fail("Expected fish models to face their swimming direction")
		return
	if stone_deposit == null:
		_fail("Expected a stone deposit")
		return
	var stone_before := int(stone_deposit.amount_remaining)
	if int(stone_deposit.harvest(1)) != 1 or int(stone_deposit.amount_remaining) != stone_before - 1 or not stone_deposit.is_available():
		_fail("Stone deposit should lose one unit and remain available after harvesting")
		return

	var animation_library := tester.unit_animation_library as AnimationLibrary
	if animation_library == null or not animation_library.has_animation("Mixamo_Swimming") or not animation_library.has_animation("Mixamo_Treading_Water"):
		_fail("Expected both supplied human swimming animations in the gameplay library")
		return
	if animation_library.get_animation("Mixamo_Swimming").track_get_key_count(0) < 2 or animation_library.get_animation("Mixamo_Treading_Water").track_get_key_count(0) < 2:
		_fail("Expected retargeted swimming animations with moving bone tracks")
		return
	var swimmer = tester.unit_actors_by_id.values()[0]
	var swim_start: Vector3 = tester._unit_surface_position_for_local(0.0, 1600.0)
	swimmer.position = swim_start
	swimmer.clear_move_order()
	swimmer.clear_gather_action()
	swimmer.clear_delivery_action()
	tester._update_unit_movement(0.05)
	if str(swimmer.current_animation) != "Mixamo_Treading_Water":
		_fail("Expected a stationary human in water to tread water")
		return
	var waterline := float(tester.WATER_SURFACE_HEIGHT)
	if swimmer.position.y >= waterline or swimmer.position.y + float(tester.UNIT_VISUAL_HEIGHT) <= waterline:
		_fail("Expected the swimmer's legs below water and upper body above water")
		return
	var moving_swim_height: float = tester._unit_surface_position_for_local(swimmer.position.x, swimmer.position.z).y
	if swimmer.position.y > moving_swim_height - float(tester.UNIT_VISUAL_HEIGHT) * 0.10:
		_fail("Expected treading humans to sit deeper with the waterline below their elbows")
		return
	swimmer.issue_move_order(tester._make_unit_move_order(Vector3(80.0, waterline, 1600.0), false))
	tester._update_unit_movement(0.10)
	if str(swimmer.current_animation) != "Mixamo_Swimming":
		_fail("Expected a moving human in water to use the swimming animation")
		return
	var swimmer_skeleton = tester._find_first_skeleton(swimmer)
	var root_bone_index := -1
	if swimmer_skeleton != null:
		for bone_index in range(swimmer_skeleton.get_bone_count()):
			if swimmer_skeleton.get_bone_parent(bone_index) < 0:
				root_bone_index = bone_index
				break
	if swimmer_skeleton == null or root_bone_index < 0:
		_fail("Expected a swimmer skeleton for land-transition verification")
		return
	var reference_pose := Quaternion.IDENTITY
	var reference_pose_found := false
	for actor_value in tester.unit_actors_by_id.values():
		if actor_value == swimmer:
			continue
		var reference_skeleton = tester._find_first_skeleton(actor_value)
		if reference_skeleton == null:
			continue
		for bone_index in range(reference_skeleton.get_bone_count()):
			if reference_skeleton.get_bone_parent(bone_index) < 0:
				reference_pose = reference_skeleton.get_bone_pose_rotation(bone_index)
				reference_pose_found = true
				break
	if not reference_pose_found:
		_fail("Expected a standing reference skeleton for land-transition verification")
		return
	swimmer_skeleton.set_bone_pose_rotation(root_bone_index, Quaternion(Vector3.FORWARD, 0.45))
	swimmer.clear_move_order()
	swimmer.position = tester._ground_position_for_local(0.0, 0.0)
	swimmer.set_meta("is_swimming", true)
	tester._update_unit_movement(0.05)
	var remained_in_water := bool(swimmer.get_meta("is_swimming", true))
	var reset_pose_angle: float = swimmer_skeleton.get_bone_pose_rotation(root_bone_index).angle_to(reference_pose)
	if remained_in_water or reset_pose_angle > 0.05:
		_fail("Expected the skeleton pose to reset cleanly after leaving water (swimming=%s angle=%.3f animation=%s)" % [str(remained_in_water), reset_pose_angle, str(swimmer.current_animation)])
		return

	if tester.terrain_root.get_node_or_null("StrategicIcons") != null:
		_fail("Strategic zoom icons should remain removed")
		return

	var standing_tree = null
	for resource in tester.resource_nodes_by_id.values():
		if resource != null and str(resource.stage) == "standing_tree":
			standing_tree = resource
			break
	if standing_tree == null:
		_fail("Expected a standing tree for fall animation verification")
		return
	tester._fell_tree_resource(standing_tree)
	if not bool(standing_tree.interaction_locked) or tester.falling_tree_animations.size() != 1:
		_fail("Expected a felled tree to lock interaction and start falling")
		return
	var fall_pivot := (tester.falling_tree_animations[0] as Dictionary).get("node") as Node3D
	tester._update_falling_trees(float(tester.TREE_FALL_DURATION) * 0.5)
	if fall_pivot == null or absf(fall_pivot.rotation.z) < 0.35:
		_fail("Expected the standing tree model to rotate gradually while falling")
		return
	tester._update_falling_trees(float(tester.TREE_FALL_DURATION) * 0.5 + float(tester.TREE_IMPACT_BOUNCE_DURATION) * 0.5)
	if absf(fall_pivot.rotation.z) >= PI * 0.5 - 0.015:
		_fail("Expected the fallen tree to rebound slightly after impact")
		return
	tester._update_falling_trees(float(tester.TREE_IMPACT_BOUNCE_DURATION))
	if bool(standing_tree.interaction_locked) or str(standing_tree.stage) != "felled_log":
		_fail("Expected the tree to become harvestable wood after the fall")
		return
	var split_root := standing_tree.visual_node as Node3D
	if split_root == null or split_root.get_child_count() != int(tester.SPLIT_WOOD_PIECE_COUNT):
		_fail("Expected a fallen tree to become five separate visible wood pieces")
		return
	tester.free()
	packed_scene = null
	await process_frame
	print("CONTROL_TEST verification passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
