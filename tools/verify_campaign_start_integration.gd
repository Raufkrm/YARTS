extends Node

const WorldMapScript = preload("res://scripts/world/world_map.gd")
const BattleSceneScript = preload("res://scripts/battle/battle_scene.gd")


func _ready() -> void:
	Game.new_campaign(735291, 24, 12)
	assert(Game.campaign_start_pending)
	var land_cell = null
	for candidate in Game.world_state.get_cells():
		if Game.world_state.get_cell_water_coverage(str(candidate.id)) <= 0.90:
			land_cell = candidate
			break
	assert(land_cell != null)
	assert(Game.settle_player_start(str(land_cell.id)))
	assert(not Game.campaign_start_pending)

	var map := WorldMapScript.new()
	assert(map.PLANET_TEXTURE_SIZE == Vector2i(3072, 1536))
	var intel_mesh: ArrayMesh = map._build_intel_overlay_mesh()
	assert(intel_mesh.get_surface_count() == 1)
	assert(intel_mesh.surface_get_array_len(0) > 0)
	var intel_arrays := intel_mesh.surface_get_arrays(0)
	var intel_vertices := intel_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var intel_colors := intel_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var minimum_triangle_center_radius := INF
	for triangle_start in range(0, intel_vertices.size(), 3):
		var triangle_center := (intel_vertices[triangle_start] + intel_vertices[triangle_start + 1] + intel_vertices[triangle_start + 2]) / 3.0
		minimum_triangle_center_radius = minf(minimum_triangle_center_radius, triangle_center.length())
	assert(minimum_triangle_center_radius > float(map.PLANET_RADIUS) + 0.001)
	var found_subtle_discovered_tint := false
	for color in intel_colors:
		if absf(color.a - float(map.INTEL_DISCOVERED_ALPHA)) <= 0.005:
			found_subtle_discovered_tint = true
			break
	assert(found_subtle_discovered_tint)
	map._build_overlay()
	assert(map.hover_popup.get_child_count() == 1)
	assert(map.hover_popup.size == Vector2(188.0, 70.0))
	map.free()
	var battle := BattleSceneScript.new()
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color.WHITE
	var tinted_material = battle._unit_faction_material(base_material, Game.get_faction_color("player"))
	assert(tinted_material is StandardMaterial3D)
	assert(not (tinted_material as StandardMaterial3D).albedo_color.is_equal_approx(Color.WHITE))
	battle.free()
	print("Campaign integration verified: overlay_vertices=%d" % intel_mesh.surface_get_array_len(0))
	get_tree().quit()
