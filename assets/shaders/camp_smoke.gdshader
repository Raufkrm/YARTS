shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= scale;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wisps = 0.80 + 0.20 * sin(p.x * 9.0 + TIME * 1.1 + sin(p.y * 7.0));
	float alpha = (1.0 - smoothstep(0.05, 1.0, length(p))) * wisps;
	ALBEDO = vec3(0.20, 0.22, 0.23);
	ALPHA = alpha * COLOR.a * 0.19;
}
