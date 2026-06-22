shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 shadow_color : source_color = vec3(0.015, 0.018, 0.012);
uniform float shadow_alpha : hint_range(0.0, 1.0, 0.01) = 0.20;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radius_squared = dot(centered_uv, centered_uv);
	float soft_edge = smoothstep(1.0, 0.16, radius_squared);
	ALBEDO = shadow_color;
	ALPHA = shadow_alpha * soft_edge;
}
