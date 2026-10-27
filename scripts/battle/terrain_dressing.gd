extends RefCounted

const ROOT := "res://assets/models/environment/craftpix/"
const FOLIAGE_SHADER = preload("res://shaders/terrain_foliage.gdshader")
const PATCH_ATTEMPTS := 1600
const MAX_PROPS := 7200
const MAX_OUTCROPS := 4
const OUTCROP_MAX_RADIUS := 240.0
const OUTCROP_WATER_CLEARANCE := 100.0
const CHUNK_SIZE := 320.0
const PACKS := {
	"temperate": "temperate/Bush_temp_climate/Textures/T_Bush_temp_climate.png",
	"grass": "temperate/Grass_temp_climate/Textures/T_Grass.png",
	"woodland": "woodland/texture/Ekfs_bush_map.png",
	"desert": "desert/Textures/T_Desert_plants.png",
	"winter": "winter/Textures/T_Bush_winter.png",
	"desert_rocks": "desert_rocks/Textures/T_Mountains_desert.png",
	"winter_rocks": "winter_rocks/Textures/T_Mountains_winter_32.png",
	"rocky": "rocky/Textures/T_Stone.png",
}
# Heights use the cell view's enlarged unit scale (an adult is 8.25 units tall).
const GROUPS := {
	"bush": {"folder": "temperate/Bush_temp_climate/Fbx/", "pack": "temperate", "names": ["Bush_temp_climate_001", "Bush_temp_climate_004", "Bush_temp_climate_008", "Bush_temp_climate_012"], "height": Vector2(3.5, 7.0), "distance": 1100.0},
	"grass": {"folder": "temperate/Grass_temp_climate/Fbx/", "pack": "grass", "names": ["Grass_001", "Grass_003", "Grass_005", "Grass_007"], "height": Vector2(1.4, 3.2), "distance": 650.0},
	"flower": {"folder": "woodland/fbx/", "pack": "woodland", "names": ["_flower_1", "_flower_3", "_flower_5"], "height": Vector2(0.65, 1.2), "distance": 500.0},
	"mushroom": {"folder": "woodland/fbx/", "pack": "woodland", "names": ["_mashroom_1", "_mashroom_2", "_mashroom_4"], "height": Vector2(0.9, 1.8), "distance": 500.0},
	"stone": {"folder": "woodland/fbx/", "pack": "woodland", "names": ["_stones_1", "_stone_2"], "height": Vector2(1.6, 4.0), "distance": 1000.0},
	"rock_small": {"folder": "rocky/Fbx/", "pack": "rocky", "names": ["Stone_lit_002", "Stone_lit_007", "Stone_lit_013", "Stone_lit_019"], "height": Vector2(1.4, 3.5), "distance": 900.0},
	"rock_medium": {"folder": "rocky/Fbx/", "pack": "rocky", "names": ["Stone_mid_001", "Stone_mid_004", "Stone_mid_007", "Stone_mid_010"], "height": Vector2(4.0, 8.0), "distance": 1500.0},
	"boulder": {"folder": "rocky/Fbx/", "pack": "rocky", "names": ["Stone_big_001", "Stone_big_004", "Stone_big_007", "Stone_big_010"], "height": Vector2(10.0, 18.0), "distance": 2400.0},
	"desert": {"folder": "desert/Fbx/", "pack": "desert", "names": ["Desert_plant_001", "Desert_plant_004", "Desert_plant_008", "Desert_plant_012", "Desert_plant_016", "Desert_plant_020"], "height": Vector2(2.8, 7.5), "distance": 1200.0},
	"winter": {"folder": "winter/Fbx/", "pack": "winter", "names": ["Bush_winter_001", "Bush_winter_005", "Bush_winter_010", "Bush_winter_015", "Bush_winter_020"], "height": Vector2(2.5, 5.5), "distance": 1000.0},
	"desert_rocks": {"folder": "desert_rocks/Fbx/", "pack": "desert_rocks", "names": ["Hill_desert_001", "Mountain_desert_003", "Plateau_desert_002"], "height": Vector2(72.0, 132.0), "distance": 0.0},
	"winter_rocks": {"folder": "winter_rocks/Fbx/", "pack": "winter_rocks", "names": ["Hill_winter_001", "Mountain_winter_003", "Plateau_winter_002"], "height": Vector2(72.0, 132.0), "distance": 0.0},
}
static var _parts_cache: Dictionary = {}
static var _profiles: Dictionary = {}
static var _materials: Dictionary = {}


static func is_asset(path: String) -> bool:
	return path.begins_with(ROOT)


static func paths(group: String) -> Array[String]:
	var result: Array[String] = []
	for asset_name in GROUPS[group].names:
		result.append(ROOT + GROUPS[group].folder + asset_name + ".fbx")
	return result


static func profile(path: String) -> Dictionary:
	if _profiles.is_empty():
		for group in GROUPS:
			for asset_path in paths(group):
				var item: Dictionary = GROUPS[group].duplicate()
				item["group"] = group
				_profiles[asset_path] = item
	return _profiles.get(path, {})


static func mesh_parts(path: String) -> Array:
	if _parts_cache.has(path): return _parts_cache[path]
	var scene := load(path) as PackedScene
	if scene == null: return []
	var root := scene.instantiate()
	var parts: Array = []
	_collect_parts(root, Transform3D.IDENTITY, parts)
	root.free()
	if parts.is_empty(): return parts
	var bounds: AABB = parts[0].transform * parts[0].mesh.get_aabb()
	for part in parts:
		bounds = bounds.merge(part.transform * part.mesh.get_aabb())
	var height := maxf(bounds.size.y, 0.001)
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var normalize := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / height), -center / height)
	var item := profile(path)
	item["radius"] = Vector2(bounds.size.x, bounds.size.z).length() * 0.5 / height
	var pack: String = item.pack
	var group: String = item.group
	if not _materials.has(group):
		var texture: Texture2D = load(ROOT + PACKS[pack])
		if group in ["grass", "flower", "bush"]:
			var material := ShaderMaterial.new()
			material.shader = FOLIAGE_SHADER
			material.set_shader_parameter("palette", texture)
			material.set_shader_parameter("wind_strength", 0.10 if group == "grass" else (0.06 if group == "flower" else 0.035))
			_materials[group] = material
		else:
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 1.0
			if group == "desert_rocks": material.albedo_color = Color(0.68, 0.82, 0.92)
			_materials[group] = material
	for part in parts:
		part.transform = normalize * part.transform
		var mesh: Mesh = part.mesh.duplicate()
		for surface in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface, _materials[group])
		part.mesh = mesh
	_parts_cache[path] = parts
	return parts


static func _collect_parts(node: Node, parent_transform: Transform3D, parts: Array) -> void:
	var transform := parent_transform
	if node is Node3D: transform *= node.transform
	if node is MeshInstance3D and node.mesh != null:
		parts.append({"mesh": node.mesh, "transform": transform})
	for child in node.get_children(): _collect_parts(child, transform, parts)


static func habitat(sample: Dictionary) -> String:
	var terrain := str(sample.get("terrain", "water"))
	var biome := str(sample.get("biome", ""))
	if terrain == "water" or biome == "polar_ice": return ""
	if terrain == "desert": return "desert"
	if terrain == "snow": return "winter"
	if terrain == "tundra": return "tundra"
	if terrain == "mountains": return "rock"
	if terrain == "forest" or biome == "forested_hills": return "woodland"
	return "meadow"


static func _group_for_patch(zone: String, moisture: float, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	match zone:
		"desert": return "desert" if roll < 0.80 else "stone"
		"winter": return "winter"
		"tundra": return "winter" if roll < 0.35 else "stone"
		"rock":
			if roll < 0.16: return "boulder"
			return "rock_medium" if roll < 0.60 else "rock_small"
		"woodland":
			if moisture > 0.58 and roll < 0.24: return "mushroom"
			return "bush" if roll < 0.62 else "grass"
		_:
			if moisture > 0.40 and roll < 0.045: return "flower"
			return "grass" if roll < 0.78 else "bush"


static func generate(map_size: float, water_level: float, seed_value: int, sample_at: Callable, height_at: Callable, exclusions: Array, landmark_exclusions: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4352414654
	var result: Array = []
	var spacing: Dictionary = {}
	var reserved: Dictionary = {}
	for exclusion in landmark_exclusions:
		reserved["max_radius"] = maxf(float(reserved.get("max_radius", 0.0)), float(exclusion.radius))
		var key := Vector2i(floori(exclusion.position.x / 96.0), floori(exclusion.position.y / 96.0))
		if not reserved.has(key): reserved[key] = []
		reserved[key].append(exclusion)
	var half := map_size * 0.5
	var attempts := maxi(32, int(PATCH_ATTEMPTS * pow(map_size / 4000.0, 2.0)))
	# Reserve landmark footprints before filling the cell with small plants.
	var landmark_rng := RandomNumberGenerator.new()
	landmark_rng.seed = seed_value ^ 0x4D4F554E54
	var outcrops := 0
	for attempt in range(maxi(11, attempts / 9)):
		if outcrops >= MAX_OUTCROPS: break
		var point := Vector2(landmark_rng.randf_range(-half + 100.0, half - 100.0), landmark_rng.randf_range(-half + 100.0, half - 100.0))
		var sample: Dictionary = sample_at.call(point.x / map_size + 0.5, point.y / map_size + 0.5)
		var zone := habitat(sample)
		var group := ""
		if zone == "desert" and float(sample.get("ridge", 0.0)) > 0.40: group = "desert_rocks"
		if zone == "winter" and float(sample.get("elevation", 0.0)) > 0.68: group = "winter_rocks"
		var neutral_rock := zone in ["rock", "meadow", "woodland"] and float(sample.get("elevation", 0.0)) > 0.61
		if neutral_rock: group = "desert_rocks"
		if group.is_empty(): continue
		var assets := paths(group)
		var prop := _place(assets[landmark_rng.randi_range(0, assets.size() - 1)], point, zone, map_size, water_level, landmark_rng, sample_at, height_at, exclusions, spacing, reserved)
		if not prop.is_empty():
			prop["neutral_rock"] = neutral_rock
			result.append(prop)
			outcrops += 1
	for attempt in range(attempts):
		var center := Vector2(rng.randf_range(-half + 40.0, half - 40.0), rng.randf_range(-half + 40.0, half - 40.0))
		var sample: Dictionary = sample_at.call(center.x / map_size + 0.5, center.y / map_size + 0.5)
		var zone := habitat(sample)
		if zone.is_empty(): continue
		var moisture := float(sample.get("moisture", 0.45))
		var chance := 0.82 if zone in ["woodland", "meadow"] else 0.30
		if zone == "rock": chance = 0.64
		if rng.randf() > chance: continue
		var group := _group_for_patch(zone, moisture, rng)
		var assets := paths(group)
		var patch_radius := rng.randf_range(9.0, 25.0)
		var members := rng.randi_range(5, 11) if zone in ["woodland", "meadow"] else rng.randi_range(2, 4)
		if zone == "rock": patch_radius = rng.randf_range(30.0, 65.0)
		if group == "flower":
			members = rng.randi_range(2, 4)
			patch_radius = rng.randf_range(3.0, 7.0)
		for member in range(members):
			var angle := rng.randf() * TAU
			var point := center + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * patch_radius
			var path := assets[rng.randi_range(0, assets.size() - 1)]
			var prop := _place(path, point, zone, map_size, water_level, rng, sample_at, height_at, exclusions, spacing)
			if not prop.is_empty(): result.append(prop)
			if result.size() >= MAX_PROPS: break
		if result.size() >= MAX_PROPS: break
	return result


static func _place(path: String, point: Vector2, zone: String, map_size: float, water_level: float, rng: RandomNumberGenerator, sample_at: Callable, height_at: Callable, exclusions: Array, spacing: Dictionary, reserved: Dictionary = {}) -> Dictionary:
	if mesh_parts(path).is_empty(): return {}
	var item := profile(path)
	var outcrop: bool = str(item.group).ends_with("_rocks")
	var height := rng.randf_range(item.height.x, item.height.y)
	if outcrop: height = minf(height, OUTCROP_MAX_RADIUS / float(item.radius))
	var radius: float = maxf(0.8, item.radius * height)
	if absf(point.x) + radius > map_size * 0.5 - 12.0 or absf(point.y) + radius > map_size * 0.5 - 12.0: return {}
	var bucket := Vector2i(floor(point.x / 96.0), floor(point.y / 96.0))
	for exclusion in exclusions:
		if point.distance_to(exclusion.position) < radius + float(exclusion.radius): return {}
	if outcrop:
		var search := ceili((radius + float(reserved.get("max_radius", 0.0))) / 96.0)
		for z in range(-search, search + 1):
			for x in range(-search, search + 1):
				for exclusion in reserved.get(bucket + Vector2i(x, z), []):
					if point.distance_to(exclusion.position) < radius + float(exclusion.radius): return {}
		if not _outcrop_clear_of_water(point, radius, map_size, water_level, sample_at, height_at): return {}
	# Check the whole footprint, not just its center, against water and slopes.
	var low := INF
	var high := -INF
	for offset in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(0.707, 0.707), Vector2(-0.707, 0.707), Vector2(0.707, -0.707), Vector2(-0.707, -0.707)]:
		var uv: Vector2 = (point + offset * radius) / map_size + Vector2.ONE * 0.5
		var sample: Dictionary = sample_at.call(uv.x, uv.y)
		if habitat(sample) != zone or float(sample.get("river", 0.0)) > 0.06: return {}
		if float(sample.get("beach", 0.0)) > 0.0: return {}
		var y: float = height_at.call(uv.x, uv.y)
		if y <= water_level + 0.7: return {}
		low = minf(low, y)
		high = maxf(high, y)
	if high - low > minf(height * 0.24, 6.0 if outcrop else 0.9): return {}
	var neighbor_range := ceili((radius + OUTCROP_MAX_RADIUS) / 96.0)
	for z in range(-neighbor_range, neighbor_range + 1):
		for x in range(-neighbor_range, neighbor_range + 1):
			for placed in spacing.get(bucket + Vector2i(x, z), []):
				if point.distance_to(placed.position) < (radius + float(placed.radius)) * 0.85: return {}
	if not spacing.has(bucket): spacing[bucket] = []
	spacing[bucket].append({"position": point, "radius": radius})
	return {"type": "scenery", "asset": path, "dressing": true, "habitat": zone,
		"position": Vector3(point.x, low - (height * 0.12 if outcrop else minf(height * 0.025, 0.22)), point.y),
		"scale": height, "rotation": rng.randf() * TAU, "footprint": radius}


static func _outcrop_clear_of_water(point: Vector2, radius: float, map_size: float, water_level: float, sample_at: Callable, height_at: Callable) -> bool:
	var clearance := radius + OUTCROP_WATER_CLEARANCE
	if absf(point.x) + clearance > map_size * 0.5 or absf(point.y) + clearance > map_size * 0.5: return false
	# A dense disk catches thin rivers between the ordinary nine footprint probes.
	var steps := ceili(clearance / 25.0)
	for z in range(-steps, steps + 1):
		for x in range(-steps, steps + 1):
			var offset := Vector2(x, z) * 25.0
			if offset.length() > clearance + 12.5: continue
			var uv := (point + offset) / map_size + Vector2.ONE * 0.5
			var sample: Dictionary = sample_at.call(uv.x, uv.y)
			if str(sample.get("terrain", "")) == "water" or float(sample.get("river", 0.0)) > 0.025 or float(sample.get("beach", 0.0)) > 0.0: return false
			if float(height_at.call(uv.x, uv.y)) <= water_level + 0.7: return false
	return true
