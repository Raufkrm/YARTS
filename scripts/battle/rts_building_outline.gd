extends RefCounted

const BLUE := Color(0.02, 0.64, 1.0)
static var cache: Dictionary = {}

static func apply(root: Node3D, color: Color = BLUE) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.has_meta("blueprint_outline"): continue
		var mesh_key := mesh_instance.mesh.get_rid()
		if not cache.has(mesh_key): cache[mesh_key] = face_edges(mesh_instance.mesh)
		mesh_instance.mesh = cache[mesh_key]
		mesh_instance.set_meta("blueprint_outline", true)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.material_override = material(color)

static func tint(root: Node3D, color: Color) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("blueprint_outline"):
			(mesh.material_override as StandardMaterial3D).albedo_color = color

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	return result

static func point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 10000), roundi(point.y * 10000), roundi(point.z * 10000)]

static func face_edges(mesh: Mesh) -> ArrayMesh:
	# Weld split material/normal vertices. Keep face boundaries and creases,
	# omit the coplanar diagonals introduced by GLB triangulation.
	var edges := {}
	for surface in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		for triangle in range(0, indices.size(), 3):
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			var normal := (b - a).cross(c - a).normalized()
			for pair in [[a, b], [b, c], [c, a]]:
				var first := point_key(pair[0])
				var second := point_key(pair[1])
				var key := first + "/" + second if first < second else second + "/" + first
				if not edges.has(key): edges[key] = {"a": pair[0], "b": pair[1], "normals": []}
				edges[key].normals.append(normal)
	var lines := PackedVector3Array()
	for edge in edges.values():
		var keep: bool = edge.normals.size() == 1
		for normal in edge.normals:
			if absf(normal.dot(edge.normals[0])) < 0.9999: keep = true
		if keep:
			lines.append(edge.a)
			lines.append(edge.b)
	var result := ArrayMesh.new()
	if not lines.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lines
		result.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return result
