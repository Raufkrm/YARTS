class_name RTSEntityVisualFactory
extends RefCounted


static func create_building_visual(building) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % str(building.id)
	root.position = building.position
	root.rotation.y = float(building.rotation_y)
	root.set_meta("rts_entity_type", "building")
	root.set_meta("rts_entity_id", str(building.id))
	root.set_meta("rts_building_type", str(building.type_id))

	match str(building.shape):
		"tent":
			_add_tent_mesh(root, building)
		"flat":
			_add_box_mesh(root, building, Color(0.34, 0.30, 0.23), true)
		_:
			_add_box_mesh(root, building, _building_color(str(building.type_id)), false)

	if float(building.supply_radius) > 0.0:
		_add_supply_marker(root, float(building.supply_radius))
	return root


static func _add_box_mesh(root: Node3D, building, color: Color, is_flat: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Shape"
	var mesh := BoxMesh.new()
	mesh.size = building.size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.position.y = (float(building.size.y) * 0.5) if not is_flat else 0.035
	root.add_child(mesh_instance)


static func _add_tent_mesh(root: Node3D, building) -> void:
	var pyramid := MeshInstance3D.new()
	pyramid.name = "FourSidedCone"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = min(float(building.size.x), float(building.size.z)) * 0.62
	mesh.height = float(building.size.y)
	mesh.radial_segments = 4
	mesh.rings = 1
	pyramid.mesh = mesh
	pyramid.material_override = _material(_building_color(str(building.type_id)))
	pyramid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pyramid.position.y = float(building.size.y) * 0.5
	pyramid.rotation.y = PI * 0.25
	root.add_child(pyramid)

	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(float(building.size.x) * 0.92, 0.28, float(building.size.z) * 0.92)
	base.mesh = base_mesh
	base.material_override = _material(Color(0.35, 0.25, 0.16))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	base.position.y = 0.14
	root.add_child(base)


static func _add_supply_marker(root: Node3D, radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "SupplyRadiusDebug"
	ring.visible = false
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var segments := 96
	for index in range(segments):
		var a0: float = TAU * float(index) / float(segments)
		var a1: float = TAU * float(index + 1) / float(segments)
		vertices.append(Vector3(cos(a0) * radius, 0.16, sin(a0) * radius))
		vertices.append(Vector3(cos(a1) * radius, 0.16, sin(a1) * radius))
		colors.append(Color(0.42, 0.78, 1.0, 0.22))
		colors.append(Color(0.42, 0.78, 1.0, 0.22))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	ring.mesh = mesh
	root.add_child(ring)


static func _building_color(building_type: String) -> Color:
	match building_type:
		"town_center":
			return Color(0.50, 0.36, 0.22)
		"supply_depot":
			return Color(0.42, 0.33, 0.23)
		"workshop":
			return Color(0.38, 0.32, 0.29)
		"barracks":
			return Color(0.36, 0.25, 0.22)
		"house":
			return Color(0.62, 0.52, 0.34)
		"tent":
			return Color(0.72, 0.66, 0.48)
	return Color(0.50, 0.42, 0.32)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material
