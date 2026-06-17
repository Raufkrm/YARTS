shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;

uniform vec3 sun_direction = vec3(0.74, 0.45, 0.50);
uniform vec3 amber_color : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 orange_color : source_color = vec3(1.0, 0.28, 0.04);
uniform vec3 red_color : source_color = vec3(0.85, 0.05, 0.015);
uniform float band_width : hint_range(0.01, 1.0) = 0.48;
uniform float lit_offset : hint_range(-1.0, 1.0) = 0.08;
uniform float rim_power : hint_range(0.5, 8.0) = 1.25;
uniform float alpha_strength : hint_range(0.0, 2.0) = 0.95;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 light_dir = normalize(sun_direction);

	float signed_light = dot(normal, light_dir);
	float lit_side = smoothstep(-0.04, 0.28, signed_light);
	float shifted_light = signed_light - lit_offset;
	float terminator = 1.0 - smoothstep(0.0, band_width, abs(shifted_light));
	float red_edge = smoothstep(0.08, -0.18, shifted_light);
	float orange_edge = smoothstep(0.42, 0.00, shifted_light);
	float view_rim = pow(1.0 - clamp(dot(normal, view_dir), 0.0, 1.0), rim_power);
	float surface_mask = smoothstep(0.02, 0.42, view_rim);
	float dark_cutoff = smoothstep(-0.32, -0.02, signed_light);
	float alpha = terminator * surface_mask * alpha_strength * lit_side * dark_cutoff;

	vec3 color = mix(amber_color, orange_color, orange_edge);
	color = mix(color, red_color, red_edge);
	ALBEDO = color;
	EMISSION = color * alpha;
	ALPHA = alpha;

	if (alpha < 0.003) {
		discard;
	}
}
