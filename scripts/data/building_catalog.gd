extends RefCounted

# Metre-authored art uses the same five-times scale as people in the cell view.
const SCALE := 5.0
const DEFINITIONS := {
	"town_center": {"name": "Settlement Hall", "model": "camp_transport/swept_thatch_roundhouse", "model_scale": 1.4, "size": Vector3(39.2, 25.97, 39.2), "cost": {"wood": 40, "stone": 10}, "work": 120.0, "health": 1500, "storage": 500, "housing": 6, "supply": 100.0},
	"house": {"name": "Reed Hut", "model": "buildings/conical_reed_hut", "size": Vector3(21.5, 18, 21), "cost": {"wood": 18}, "work": 40.0, "health": 350, "storage": 40, "housing": 3, "supply": 0.0},
	"longhouse": {"name": "Communal Longhouse", "model": "buildings/oval_thatch_longhouse", "size": Vector3(34.5, 16, 22), "cost": {"wood": 35, "stone": 5}, "work": 80.0, "health": 650, "storage": 100, "housing": 8, "supply": 0.0},
	"hide_shelter": {"name": "Hide Shelter", "model": "buildings/bone_hide_shelter", "size": Vector3(16.5, 10, 14), "cost": {"wood": 12, "stone": 2}, "work": 30.0, "health": 240, "storage": 20, "housing": 2, "supply": 0.0},
	"tent": {"name": "Hemp Tent", "model": "camp_transport/hemp_ridge_tent", "size": Vector3(15, 10.05, 28), "cost": {"wood": 8}, "work": 20.0, "health": 180, "storage": 20, "housing": 2, "supply": 0.0},
}

static func model_path(type_id: String, lod: int = 1) -> String:
	return "res://assets/models/%s_lod%d.glb" % [DEFINITIONS[type_id].model, clampi(lod, 0, 2)]

static func cost_label(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in cost: parts.append("%d %s" % [cost[key], key])
	return ", ".join(parts)
