shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

varying float heat;
varying float phase;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	heat = INSTANCE_CUSTOM.y;
	float t = TIME * 5.2 + phase;
	float bend = pow(UV.y, 1.5);
	VERTEX.x += bend * (sin(t + UV.y * 5.0) * 0.13 + sin(t * 0.57) * 0.065);
	VERTEX.z += bend * cos(t * 0.73 + UV.y * 4.5) * 0.10;
	VERTEX.y *= 0.91 + 0.13 * sin(t * 0.88) + 0.07 * sin(t * 1.67);
}

void fragment() {
	float height = clamp(UV.y, 0.0, 1.0);
	vec3 hot = vec3(1.0, 0.86, 0.29);
	vec3 orange = vec3(1.0, 0.30, 0.018);
	vec3 red = vec3(0.78, 0.055, 0.003);
	vec3 color = mix(hot, orange, smoothstep(0.10, 0.64, height) * (1.0 - heat * 0.55));
	color = mix(color, red, smoothstep(0.62, 1.0, height) * (1.0 - heat * 0.7));
	float flutter = 0.92 + 0.08 * sin(TIME * 9.0 + phase + height * 12.0);
	ALBEDO = color;
	EMISSION = color * (1.2 + heat * 0.8) * flutter;
	ALPHA = (0.88 - height * 0.23) * (1.0 - smoothstep(0.82, 1.0, height));
}
