extends RefCounted

static func prepare(host, nav, source: Array) -> Array:
	if host.cell == null or not host.cell.rts_state.has("founding_allowance"): return source
	var state: Dictionary = host.cell.rts_state
	var center := Vector3.ZERO
	if state.has("founding_clearing"):
		var saved: Array = state.founding_clearing
		center = Vector3(saved[0], saved[1], saved[2])
	else:
		var found := false
		for ring in range(25):
			for index in range(maxi(1, ring * 8)):
				var angle := TAU * index / maxi(1, ring * 8)
				var candidate := Vector3(cos(angle), 0, sin(angle)) * ring * 72.0
				if not _clearing_is_dry(nav, candidate): continue
				center = nav.ground(candidate)
				found = true
				break
			if found: break
		if not found:
			push_warning("No sufficiently large dry founding clearing in this cell.")
			return source
		state["founding_clearing"] = [center.x, center.y, center.z]
	var props: Array = []
	for prop in source:
		var position: Vector3 = prop.get("position", Vector3.ZERO)
		var footprint := float(prop.get("footprint", 15.0))
		if Vector2(position.x - center.x, position.z - center.z).length() < 100.0 + footprint: continue
		props.append(prop)
	# Reserve the removed starter trees' old ID slots only. The forest layout
	# suppresses these entries, so no tree, resource or obstacle is spawned.
	# Keeping their batch positions prevents shifting later saved resource IDs.
	for offset in [-50, -15, 20, 55]:
		props.append({"type": "tree", "opening_tree": true, "forest_suppressed": true, "position": nav.ground(center + Vector3(-58, 0, offset)), "asset": host.LEAF_TREE_ASSETS[0], "scale": 1.0, "rotation": 0.0})
	# Deterministic starter deposits, not spendable stock. Wood comes from the
	# naturally generated trees outside the clearing.
	props.append({"type": "resource_deposit", "resource_type": "stone", "position": nav.ground(center + Vector3(58, 0, -35)), "asset": "res://assets/models/resources/resource_stone_pile.glb", "scale": 1.4, "cluster_count": 4, "cluster_spread": 2.0, "deposit_size": "small", "amount": 240})
	props.append({"type": "resource_deposit", "resource_type": "food", "position": nav.ground(center + Vector3(58, 0, 35)), "asset": "res://assets/models/resources/resource_food_pot.glb", "scale": 1.4, "cluster_count": 4, "cluster_spread": 2.0, "deposit_size": "small", "amount": 180})
	return props

static func _clearing_is_dry(nav, center: Vector3) -> bool:
	var low := INF
	var high := -INF
	for x in range(-3, 4):
		for z in range(-3, 4):
			var point := center + Vector3(x * 24.0, 0, z * 24.0)
			if not nav.terrain_clear(point, 12.0): return false
			var y: float = nav.ground(point).y
			low = minf(low, y)
			high = maxf(high, y)
	return high - low < 1.4
