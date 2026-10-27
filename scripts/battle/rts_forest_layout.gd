extends RefCounted

const SIZE_MULTIPLIER := 2.0
const MIN_TREE_DISTANCE := 64.0
const FOREST_TREE_DISTANCE := 40.0
const TRUNK_RADIUS := 3.0
const TREE_TYPES := ["tree", "tree_impostor", "forest_tree"]

static func prepare(host, source: Array) -> Array:
	# Keep the seeded candidates and their registration order. Suppressed trees
	# reserve their old resource IDs, so thinning cannot remap saved depletion.
	var result: Array = []
	var occupied: Dictionary = {}
	for original in source:
		if original.get("opening_tree", false):
			# Also remove these from older cached layouts without reusing their IDs.
			var removed: Dictionary = original.duplicate()
			removed["forest_suppressed"] = true
			result.append(removed)
			continue
		var is_tree: bool = str(original.get("type", "")) in TREE_TYPES
		var asset := str(original.get("asset", ""))
		var is_sapling: bool = asset in host.SMALL_TREE_ASSETS or asset in host.SMALL_SNOW_TREE_ASSETS
		if not is_tree and not is_sapling:
			result.append(original)
			continue
		var prop: Dictionary = original.duplicate()
		if not prop.get("tree_scale_doubled", false):
			prop.scale = float(prop.get("scale", 1.0)) * SIZE_MULTIPLIER
			prop["tree_scale_doubled"] = true
		prop["forest_suppressed"] = false
		if not prop.has("forest_spacing"):
			var point: Vector3 = prop.position
			var sample: Dictionary = host._sample_cell_uv(point.x / host.MAP_SIZE + 0.5, point.z / host.MAP_SIZE + 0.5)
			var in_forest := str(sample.get("terrain", "")) == "forest" or str(sample.get("biome", "")) == "forested_hills"
			prop["forest_spacing"] = FOREST_TREE_DISTANCE if in_forest else MIN_TREE_DISTANCE
		result.append(prop)
	# First retain the previous 64-unit layout exactly, including grassland.
	for prop in result:
		if not prop.has("forest_suppressed") or prop.get("opening_tree", false): continue
		if _has_room(occupied, prop.position, MIN_TREE_DISTANCE):
			_remember(occupied, prop.position, float(prop.forest_spacing))
		else:
			prop.forest_suppressed = true
	# Repack only the forest candidates around the unchanged meadow trees.
	# Keeping the old forest anchors would prevent filling many regular gaps.
	occupied.clear()
	for prop in result:
		if not prop.has("forest_suppressed") or prop.forest_suppressed: continue
		if prop.get("opening_tree", false) or float(prop.forest_spacing) == MIN_TREE_DISTANCE:
			_remember(occupied, prop.position, MIN_TREE_DISTANCE)
	for prop in result:
		if not prop.has("forest_suppressed") or prop.get("opening_tree", false) or float(prop.forest_spacing) != FOREST_TREE_DISTANCE: continue
		prop.forest_suppressed = true
		if _has_room(occupied, prop.position, FOREST_TREE_DISTANCE):
			_remember(occupied, prop.position, FOREST_TREE_DISTANCE)
			prop.forest_suppressed = false
	return result

static func _bucket(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / MIN_TREE_DISTANCE), floori(point.z / MIN_TREE_DISTANCE))

static func _remember(occupied: Dictionary, point: Vector3, spacing: float) -> void:
	var key := _bucket(point)
	if not occupied.has(key): occupied[key] = []
	occupied[key].append({"point": Vector2(point.x, point.z), "spacing": spacing})

static func _has_room(occupied: Dictionary, point: Vector3, spacing: float) -> bool:
	var key := _bucket(point)
	for z in range(-1, 2):
		for x in range(-1, 2):
			for other in occupied.get(key + Vector2i(x, z), []):
				var distance := maxf(spacing, float(other.spacing))
				if Vector2(point.x, point.z).distance_squared_to(other.point) < distance * distance:
					return false
	return true
