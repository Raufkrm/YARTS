shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

uniform sampler2D palette : source_color, filter_nearest_mipmap, repeat_disable;
uniform float wind_strength = 0.06;

void vertex() {
	// Custom data supplies each instance's ground level and height, so imported
	// FBX pivots and object transforms cannot move the roots during a gust.
	float height = max(INSTANCE_CUSTOM.g, 0.01);
	float tip = clamp((VERTEX.y - INSTANCE_CUSTOM.r) / height, 0.0, 1.0);
	float phase = INSTANCE_CUSTOM.b;
	float gust = sin(TIME * 1.5 + phase) * 0.65 + sin(TIME * 2.7 + phase * 1.71) * 0.35;
	VERTEX.xz += vec2(1.0, 0.45) * gust * tip * tip * height * wind_strength;
}

void fragment() {
	ALBEDO = texture(palette, UV).rgb;
	ROUGHNESS = 1.0;
}
