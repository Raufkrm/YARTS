// YARTS Godot 4.7 adaptation inspired by "LowPoly Water" from Godot Shaders.
// The original page includes a mesh script; this shader keeps the effect on YARTS' generated meshes.
// Source reference: https://godotshaders.com/shader/lowpoly-water/
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool use_river_flow = false;
uniform vec3 deep_water_color : source_color = vec3(0.01, 0.07, 0.16);
uniform vec3 shallow_water_color : source_color = vec3(0.10, 0.42, 0.62);
uniform vec3 foam_color : source_color = vec3(0.82, 0.94, 0.98);
uniform vec2 wave_direction = vec2(0.72, 0.22);
uniform vec2 wave_direction_2 = vec2(-0.31, 0.86);
uniform float wave_height : hint_range(0.0, 2.0, 0.01) = 0.25;
uniform float wave_scale : hint_range(0.01, 2.0, 0.01) = 0.12;
uniform float wave_speed : hint_range(0.0, 5.0, 0.01) = 1.2;
uniform float edge_foam_distance : hint_range(0.01, 8.0, 0.01) = 1.2;
uniform float depth_color_distance : hint_range(0.1, 30.0, 0.1) = 6.0;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 0.86;
uniform float facet_contrast : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float low_poly_strength : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float day_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec3 sun_direction = vec3(0.2, 0.8, 0.4);

varying vec3 view_position;
varying float water_alpha;
varying float wave_energy;
varying float crest_amount;

float shaped_wave(float value) {
	return value + 0.18 * (2.0 * value * value - 1.0);
}

float shaped_wave_derivative(float value) {
	return 1.0 + 0.72 * value;
}

void vertex() {
	vec2 encoded_flow = COLOR.rg * 2.0 - vec2(1.0);
	vec2 river_flow = length(encoded_flow) > 0.01 ? normalize(encoded_flow) : vec2(0.0, 1.0);
	vec2 primary_flow = use_river_flow ? river_flow : normalize(wave_direction);
	vec2 cross_flow = vec2(-primary_flow.y, primary_flow.x);
	vec2 secondary_flow = normalize(use_river_flow ? primary_flow * 0.84 + cross_flow * 0.16 : wave_direction_2);
	vec2 diagonal_flow = normalize(primary_flow * 0.58 - cross_flow * 0.42);
	vec2 short_flow = normalize(secondary_flow * 0.46 + cross_flow * 0.54);
	vec2 position = VERTEX.xz;
	float shoreline_alpha = COLOR.a;
	float edge_alpha = use_river_flow ? shoreline_alpha : 1.0;
	float river_edge_damp = mix(0.25, 1.0, edge_alpha);
	float height = wave_height * river_edge_damp;
	float frequency_a = wave_scale * (use_river_flow ? 2.6 : 0.55);
	float frequency_b = wave_scale * (use_river_flow ? 4.2 : 1.00);
	float frequency_c = wave_scale * (use_river_flow ? 6.8 : 1.62);
	float frequency_d = wave_scale * (use_river_flow ? 9.4 : 2.30);
	float phase_a = dot(position, primary_flow) * frequency_a + TIME * wave_speed * 0.46;
	float phase_b = dot(position, secondary_flow) * frequency_b + TIME * wave_speed * 0.71 + 1.7;
	float phase_c = dot(position, diagonal_flow) * frequency_c + TIME * wave_speed * 1.03 + 4.1;
	float phase_d = dot(position, short_flow) * frequency_d + TIME * wave_speed * 1.37 + 2.6;
	float raw_a = sin(phase_a);
	float raw_b = sin(phase_b);
	float raw_c = sin(phase_c);
	float raw_d = sin(phase_d);
	float wave_a = use_river_flow ? raw_a : shaped_wave(raw_a);
	float wave_b = use_river_flow ? raw_b : shaped_wave(raw_b);
	float wave_c = use_river_flow ? raw_c : shaped_wave(raw_c);
	float wave_d = use_river_flow ? raw_d : shaped_wave(raw_d);
	float displacement = (wave_a * 0.50 + wave_b * 0.27 + wave_c * 0.15 + wave_d * 0.08) * height;
	float derivative_a = use_river_flow ? 1.0 : shaped_wave_derivative(raw_a);
	float derivative_b = use_river_flow ? 1.0 : shaped_wave_derivative(raw_b);
	float derivative_c = use_river_flow ? 1.0 : shaped_wave_derivative(raw_c);
	float derivative_d = use_river_flow ? 1.0 : shaped_wave_derivative(raw_d);
	vec2 wave_gradient = height * (
		primary_flow * cos(phase_a) * frequency_a * 0.50 * derivative_a
		+ secondary_flow * cos(phase_b) * frequency_b * 0.27 * derivative_b
		+ diagonal_flow * cos(phase_c) * frequency_c * 0.15 * derivative_c
		+ short_flow * cos(phase_d) * frequency_d * 0.08 * derivative_d
	);
	VERTEX.y += displacement;
	NORMAL = normalize(vec3(-wave_gradient.x, 1.0, -wave_gradient.y));

	view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	water_alpha = shoreline_alpha;
	wave_energy = clamp(abs(displacement) / max(wave_height, 0.001), 0.0, 1.4);
	crest_amount = clamp(raw_a * 0.34 + raw_b * 0.24 + raw_c * 0.12 + 0.50, 0.0, 1.0);
}

void fragment() {
	vec3 smooth_normal = normalize(NORMAL);
	vec3 triangle_normal = normalize(cross(dFdx(view_position), dFdy(view_position)));
	if (triangle_normal.y < 0.0) {
		triangle_normal *= -1.0;
	}
	vec3 face_normal = normalize(mix(smooth_normal, triangle_normal, low_poly_strength));
	if (face_normal.y < 0.0) {
		face_normal *= -1.0;
	}
	NORMAL = face_normal;

	float sampled_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, sampled_depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float water_depth = -view_position.z;
	float depth_delta = max(scene_depth - water_depth, 0.0);

	float shallow = 1.0 - smoothstep(0.0, depth_color_distance, depth_delta);
	float edge_foam = 1.0 - smoothstep(0.0, edge_foam_distance, depth_delta);
	vec3 daylight_color = mix(deep_water_color, shallow_water_color, shallow);
	daylight_color = mix(daylight_color, foam_color, clamp(edge_foam * 0.24, 0.0, 0.34));

	float surface_light = clamp(face_normal.y * 0.76 + crest_amount * 0.16 + 0.14, 0.42, 1.10);
	daylight_color *= mix(1.0 - facet_contrast, 1.0 + facet_contrast * 0.30, surface_light);
	float fresnel = pow(1.0 - clamp(dot(face_normal, VIEW), 0.0, 1.0), 3.0);
	daylight_color = mix(daylight_color, shallow_water_color + foam_color * 0.08, fresnel * 0.18);

	vec3 night_color = deep_water_color * (use_river_flow ? 0.58 : 0.64) + vec3(0.0, 0.030, 0.065);
	night_color *= mix(0.90, 1.08, crest_amount);
	vec3 final_color = mix(night_color, daylight_color, day_factor);

	ALBEDO = final_color;
	ROUGHNESS = use_river_flow ? 0.54 : 0.42;
	SPECULAR = use_river_flow ? 0.36 : 0.58;
	METALLIC = 0.0;
	ALPHA = alpha * water_alpha;
}
