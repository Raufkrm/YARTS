extends Node

const BattleSceneScript = preload("res://scripts/battle/battle_scene.gd")

func _ready() -> void:
	var battle_scene = BattleSceneScript.new()
	var paths := [
		"res://assets/Ultimate Nature Pack by Quaternius/OBJ/CommonTree_1.obj",
		"res://assets/Ultimate Nature Pack by Quaternius/OBJ/PineTree_1.obj",
		"res://assets/Ultimate Nature Pack by Quaternius/OBJ/PalmTree_1.obj",
	]
	for path in paths:
		var mesh := load(path) as Mesh
		assert(mesh != null, "Failed to load %s" % path)
		assert(mesh.get_surface_count() >= 2, "%s lost its foliage/wood surfaces" % path)
		var lit_mesh := battle_scene._battle_lit_mesh(mesh)
		assert(lit_mesh != null)
		assert(lit_mesh.get_surface_count() == mesh.get_surface_count())
		var material_names: Array[String] = []
		for surface_index in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface_index)
			assert(material != null, "%s surface %d has no material" % [path, surface_index])
			var lit_material := lit_mesh.surface_get_material(surface_index) as BaseMaterial3D
			assert(lit_material != null)
			assert(lit_material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)
			assert(not lit_material.disable_receive_shadows)
			if material is BaseMaterial3D:
				var source_color := (material as BaseMaterial3D).albedo_color
				assert(lit_material.albedo_color.get_luminance() > source_color.get_luminance())
			var material_description := str(material.resource_name)
			if material is BaseMaterial3D:
				material_description += "=%s" % str((material as BaseMaterial3D).albedo_color)
			material_names.append(material_description)
		print("%s: %d surfaces (%s)" % [path.get_file(), mesh.get_surface_count(), ", ".join(material_names)])
	battle_scene.free()
	get_tree().quit()
