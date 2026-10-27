class_name HandgonneDrillProps
extends RefCounted
## Small shared meshes for the handgonne human drill, in metres.
## Rod and igniter extend along +Y from their lower end. Other props are bottom-centred.

const PALETTE := preload("res://assets/models/weapons/firearms/firearm_vertex_palette.tres")
const PROP_NAMES := ["rod", "flask", "shot", "igniter", "pouch"]
const WOOD := Color("765135")
const CORD := Color("b09868")
const EMBER := Color("ffd16a")
const IRON := Color("879193")
const SHOT_RADIUS := 0.018
const LEATHER := Color("56402e")
static var _mesh_cache: Dictionary = {}


static func build(level: int) -> Dictionary:
	level = clampi(level, 0, 2)
	if not _mesh_cache.has(level):
		_mesh_cache[level] = _build_meshes(level)
	var meshes: Dictionary = _mesh_cache[level]
	var result: Dictionary = {}
	var parent := Node3D.new()
	parent.name = "HandgonneDrillProps"
	result["root"] = parent
	result["vertex_count"] = 0
	for prop_name: String in PROP_NAMES:
		var prop := MeshInstance3D.new()
		prop.name = prop_name
		prop.mesh = meshes.get(prop_name) as ArrayMesh
		prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Visibility is phase-driven by the drill controller; start with all props stowed.
		prop.visible = false
		parent.add_child(prop)
		result[prop_name] = prop
		if prop.mesh != null:
			result["vertex_count"] += prop.mesh.surface_get_array_len(0)
	return result


static func _build_meshes(level: int) -> Dictionary:
	var result: Dictionary = {}
	if level == 2:
		var card := _data()
		for vertex: Vector3 in [Vector3(-0.004, 0, 0), Vector3(0.004, 0, 0), Vector3(0.004, 0.42, 0), Vector3(-0.004, 0.42, 0)]:
			_add_vertex(card, vertex, WOOD)
		card["indices"].append_array(PackedInt32Array([0, 1, 2, 0, 2, 3]))
		result["rod"] = _mesh(card, "HandgonneRodFar")
		return result
	var rod := _data()
	_append_rings(rod, 6 if level == 0 else 4, [[0.0, 0.0045], [0.42, 0.0045]], WOOD)
	result["rod"] = _mesh(rod, "HandgonneRod%d" % level)
	var igniter := _data()
	_append_rings(igniter, 4, [[0.0, 0.004], [0.413, 0.004]], WOOD)
	if level == 0:
		_append_octahedron(igniter, Vector3(0, 0.417, 0), 0.005, EMBER)
	else:
		_append_pyramid(igniter, 0.413, 0.42, 0.005, EMBER)
	result["igniter"] = _mesh(igniter, "HandgonneIgniter%d" % level)
	var flask := _data()
	if level == 0:
		_append_rings(flask, 6, [[0.0, 0.016], [0.012, 0.0225], [0.065, 0.0225], [0.08, 0.008], [0.09, 0.008]], WOOD)
	else:
		_append_box(flask, Vector3(0.04, 0.09, 0.025), WOOD)
	result["flask"] = _mesh(flask, "HandgonneFlask%d" % level)
	if level == 0:
		var shot := _data()
		_append_ball(shot)
		result["shot"] = _mesh(shot, "HandgonneShot")
	var pouch := _data()
	_append_box(pouch, Vector3(0.09, 0.10, 0.04), LEATHER)
	result["pouch"] = _mesh(pouch, "HandgonnePouch%d" % level)
	return result


static func _data() -> Dictionary:
	return {"vertices": PackedVector3Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}


static func _append_ball(data: Dictionary) -> void:
	# Icosahedron: twelve shared vertices, twenty triangles, opaque depth-tested.
	var points: Array[Vector3] = []
	var golden := (1.0 + sqrt(5.0)) * 0.5
	for a in [-1.0, 1.0]:
		for b in [-golden, golden]:
			points.append(Vector3(0, a, b).normalized() * SHOT_RADIUS)
			points.append(Vector3(a, b, 0).normalized() * SHOT_RADIUS)
			points.append(Vector3(b, 0, a).normalized() * SHOT_RADIUS)
	for point in points:
		_add_vertex(data, point, Color("303238") * (0.9 + point.y / SHOT_RADIUS * 0.16))
	for a in range(points.size()):
		for b in range(a + 1, points.size()):
			for c in range(b + 1, points.size()):
				var normal := (points[b] - points[a]).cross(points[c] - points[a]).normalized()
				var positive := false
				var negative := false
				for p in points:
					var distance := normal.dot(p - points[a])
					positive = positive or distance > 0.000001
					negative = negative or distance < -0.000001
				if positive and negative: continue
				data.indices.append_array(PackedInt32Array([a, c, b] if positive else [a, b, c]))


static func _add_vertex(data: Dictionary, position: Vector3, color: Color) -> void:
	data["vertices"].append(position)
	data["colors"].append(color)


static func _append_rings(data: Dictionary, sides: int, rings: Array, color: Color) -> void:
	var start: int = data["vertices"].size()
	for ring: Array in rings:
		for side in range(sides):
			var angle := TAU * float(side) / float(sides)
			_add_vertex(data, Vector3(cos(angle) * float(ring[1]), float(ring[0]), sin(angle) * float(ring[1])), color)
	for ring in range(rings.size() - 1):
		for side in range(sides):
			var next := (side + 1) % sides
			var a := start + ring * sides + side
			var b := start + ring * sides + next
			var c := start + (ring + 1) * sides + next
			var d := start + (ring + 1) * sides + side
			data["indices"].append_array(PackedInt32Array([a, c, b, a, d, c]))
	for side in range(1, sides - 1):
		data["indices"].append_array(PackedInt32Array([start, start + side, start + side + 1]))
		var top := start + (rings.size() - 1) * sides
		data["indices"].append_array(PackedInt32Array([top, top + side + 1, top + side]))


static func _append_octahedron(data: Dictionary, center: Vector3, radius: float, color: Color) -> void:
	var start: int = data["vertices"].size()
	for direction: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		_add_vertex(data, center + direction * radius, color)
	for side in range(4):
		var a := start + 2 + side
		var b := start + 2 + (side + 1) % 4
		data["indices"].append_array(PackedInt32Array([start, b, a, start + 1, a, b]))


static func _append_pyramid(data: Dictionary, bottom: float, top: float, radius: float, color: Color) -> void:
	var start: int = data["vertices"].size()
	for side in range(4):
		var angle := TAU * float(side) / 4.0
		_add_vertex(data, Vector3(cos(angle) * radius, bottom, sin(angle) * radius), color)
	_add_vertex(data, Vector3(0, top, 0), color)
	for side in range(4):
		data["indices"].append_array(PackedInt32Array([start + side, start + 4, start + (side + 1) % 4]))
	data["indices"].append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


static func _append_box(data: Dictionary, size: Vector3, color: Color) -> void:
	var start: int = data["vertices"].size()
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	for position: Vector3 in [Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z), Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z), Vector3(-half_x, size.y, -half_z), Vector3(half_x, size.y, -half_z), Vector3(half_x, size.y, half_z), Vector3(-half_x, size.y, half_z)]:
		_add_vertex(data, position, color)
	for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		data["indices"].append_array(PackedInt32Array([start + int(face[0]), start + int(face[1]), start + int(face[2]), start + int(face[0]), start + int(face[2]), start + int(face[3])]))


static func _mesh(data: Dictionary, label: String) -> ArrayMesh:
	var vertices: PackedVector3Array = data["vertices"]
	var indices: PackedInt32Array = data["indices"]
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		var normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.resource_name = label
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, PALETTE)
	return mesh
