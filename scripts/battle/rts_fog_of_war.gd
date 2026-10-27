extends RefCounted

# Terrain/resources remain readable. Only opposing humans are concealed.
const HUMAN_SIGHT := 140.0
const BUILDING_SIGHT := 180.0
const SOFT_EDGE := 30.0
const MASK_SIZE := 256
var host
var sources: Array[Vector3] = [] # x/z position in xy, radius in z
var texture: ImageTexture
var overlay: MeshInstance3D
var elapsed := 0.0

func configure(scene) -> void:
	host = scene
	var mask := Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(mask)
	overlay = MeshInstance3D.new()
	overlay.name = "SoftFogOfWar"
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	overlay.mesh = quad
	overlay.extra_cull_margin = 16384
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/rts_fog_of_war.gdshader")
	material.set_shader_parameter("sight_mask",texture)
	material.set_shader_parameter("map_size",float(host.MAP_SIZE))
	material.render_priority = 100
	overlay.material_override = material
	host.camera.add_child(overlay)
	refresh()

func sees(point: Vector3) -> bool:
	for source in sources:
		if Vector2(point.x-source.x,point.z-source.y).length_squared() <= source.z*source.z: return true
	return false

func update(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.15: return
	elapsed = 0.0
	refresh()

func refresh() -> void:
	sources.clear()
	for actor in host.unit_actors_by_id.values():
		if actor.unit_data.is_alive() and actor.faction_id == "player":
			sources.append(Vector3(actor.position.x,actor.position.z,HUMAN_SIGHT))
	for building in host.battle_buildings:
		if building.completed and building.health > 0 and building.faction_id == "player":
			sources.append(Vector3(building.position.x,building.position.z,BUILDING_SIGHT))
	var mask := Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	var step: float = host.MAP_SIZE / float(MASK_SIZE)
	for source in sources:
		var center := Vector2(source.x,source.y)/step + Vector2.ONE*MASK_SIZE*0.5
		var extent := ceili((source.z+SOFT_EDGE)/step)+1
		for y in range(maxi(0,int(center.y)-extent),mini(MASK_SIZE,int(center.y)+extent+1)):
			for x in range(maxi(0,int(center.x)-extent),mini(MASK_SIZE,int(center.x)+extent+1)):
				var distance := (Vector2(x+0.5,y+0.5)-center).length()*step
				var value := 1.0-smoothstep(source.z-SOFT_EDGE,source.z+SOFT_EDGE,distance)
				if value>mask.get_pixel(x,y).r: mask.set_pixel(x,y,Color(value,value,value))
	texture.update(mask)
	var selection: Array = host.selected_unit_ids.duplicate()
	for actor in host.unit_actors_by_id.values():
		var shown: bool = actor.unit_data.is_alive() and (actor.faction_id == "player" or sees(actor.position))
		actor.visible = shown
		actor.set_meta("hidden_by_fog",not shown)
		if not shown: selection.erase(actor.unit_id)
	if selection != host.selected_unit_ids:
		host._set_selected_units(selection)
		host._refresh_overlay()
