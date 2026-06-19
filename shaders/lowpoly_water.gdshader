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
uniform float day_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec3 sun_direction = vec3(0.2, 0.8, 0.4);

varying vec3 view_position;
varying float water_alpha;
varying float wave_energy;
varying float surface_band;

float wave_value(vec2 position, vec2 direction, float scale, float speed, float phase) {
	return sin(dot(position, normalize(direction)) * scale + TIME * speed + phase);
}

void vertex() {
	vec2 encoded_flow = COLOR.rg * 2.0 - vec2(1.0);
	vec2 river_flow = length(encoded_flow) > 0.01 ? normalize(encoded_flow) : vec2(0.0, 1.0);
	vec2 primary_flow = use_river_flow ? river_flow : normalize(wave_direction);
	vec2 cross_flow = vec2(-primary_flow.y, primary_flow.x);
	vec2 position = VERTEX.xz;
	float edge_alpha = use_river_flow ? COLOR.a : 1.0;
	float river_edge_damp = mix(0.25, 1.0, edge_alpha);
	float height = wave_height * river_edge_damp;
	float scale = wave_scale * (use_river_flow ? 2.9 : 1.0);
	float speed = wave_speed * (use_river_flow ? 1.45 : 1.0);

	float wave_a = wave_value(position, primary_flow, scale, speed, 0.0);
	float wave_b = wave_value(position, normalize(primary_flow * 0.55 + cross_flow * 0.45), scale * 1.85, speed * 1.34, 1.7);
	float wave_c = wave_value(position, normalize(wave_direction_2), scale * 0.62, speed * 0.58, 4.1);
	float displacement = (wave_a * 0.54 + wave_b * 0.31 + wave_c * 0.15) * height;
	VERTEX.y += displacement;

	view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	water_alpha = edge_alpha;
	wave_energy = abs(displacement) / max(wave_height, 0.001);
	surface_band = floor((wave_a * 0.5 + 0.5) * 5.0) / 5.0;
}

void fragment() {
	vec3 face_normal = normalize(cross(dFdx(view_position), dFdy(view_position)));
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

	float facet_light = clamp(face_normal.y * 0.68 + surface_band * 0.22 + 0.18, 0.36, 1.16);
	daylight_color *= mix(1.0 - facet_contrast, 1.0 + facet_contrast * 0.42, facet_light);

	vec3 night_color = deep_water_color * (use_river_flow ? 0.58 : 0.64) + vec3(0.0, 0.030, 0.065);
	night_color *= mix(0.86, 1.10, surface_band);
	vec3 final_color = mix(night_color, daylight_color, day_factor);

	ALBEDO = final_color;
	ROUGHNESS = use_river_flow ? 0.54 : 0.42;
	SPECULAR = use_river_flow ? 0.36 : 0.58;
	METALLIC = 0.0;
	ALPHA = alpha * water_alpha;
}
