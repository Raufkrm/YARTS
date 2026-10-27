shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec4 effect;
void vertex() {
	effect = INSTANCE_CUSTOM;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= scale;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p);
	float cloud = 1.0 - smoothstep(0.24, 1.0, edge + 0.09 * sin(p.x * 9.0 + effect.z) * sin(p.y * 8.0 - effect.z));
	if (effect.y > 0.5) {
		ALBEDO = mix(vec3(1.0, 0.26, 0.015), vec3(1.0, 0.94, 0.65), max(0.0, 1.0 - edge * 1.7));
		EMISSION = ALBEDO * 2.0;
		ALPHA = cloud * effect.w;
	} else {
		ALBEDO = mix(vec3(0.44, 0.46, 0.46), vec3(0.79, 0.80, 0.77), cloud);
		ALPHA = cloud * effect.w;
	}
}
