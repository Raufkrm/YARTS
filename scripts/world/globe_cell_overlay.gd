extends RefCounted

const OVERLAY_SHADER = preload("res://shaders/planet_cell_overlay.gdshader")
const EMPTY_RECT := Vector4(-2.0, -2.0, -2.0, -2.0)


static func create_material(world, grid_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OVERLAY_SHADER
	material.render_priority = 1
	material.set_shader_parameter("grid_size", Vector2(world.width, world.height))
	var span: int = WorldState.POLAR_MERGE_SPAN if world.width % WorldState.POLAR_MERGE_SPAN == 0 else 1
	material.set_shader_parameter("polar_span", float(span))
	material.set_shader_parameter("grid_color", grid_color)
	material.set_shader_parameter("tint_enabled", false)
	return material


static func cell_rect(cell) -> Vector4:
	if cell == null: return EMPTY_RECT
	return Vector4(cell.x, cell.y, cell.x + cell.x_span, cell.y + 1)
