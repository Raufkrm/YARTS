// Adapted from "Starburst effect 3D (astronomy)" by T360 on Godot Shaders.
// Source page lists the shader code under CC0:
// https://godotshaders.com/shader/starburst-effect-3d-astronomy/
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform int seed = 7;
uniform vec4 star_color : source_color = vec4(1.0, 0.86, 0.44, 1.0);
uniform int spike_count : hint_range(1, 16) = 16;
uniform float rotation_offset : hint_range(0.0, 6.28) = 0.0;
uniform float flare_intensity : hint_range(0.0, 8.0) = 0.34;
uniform float spike_length : hint_range(0.1, 12.0) = 7.2;
uniform float long_ray_intensity : hint_range(0.0, 4.0) = 0.52;
uniform float long_ray_length : hint_range(0.1, 12.0) = 2.35;
uniform float central_glow_effect : hint_range(0.0, 1.0) = 0.8;
uniform float glow_size : hint_range(0.002, 0.08) = 0.018;
uniform float glow_intensity : hint_range(0.0, 16.0) = 5.5;
uniform float master_brightness : hint_range(0.0, 8.0) = 0.62;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.12;
uniform float edge_smoothing : hint_range(0.01, 0.5) = 0.16;
uniform float inner_thickness : hint_range(0.0, 0.12) = 0.0052;
uniform float outer_thickness : hint_range(0.0, 0.12) = 0.0012;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 center = vec2(0.5);
	vec2 rel = UV - center;
	float dist = length(rel);

	float glow = exp(-dist / glow_size) * glow_intensity;
	float angle = atan(rel.y, rel.x) / TAU + 0.5;
	float radial_noise = hash(floor(angle * 96.0) + float(seed) * 19.17);
	radial_noise = radial_noise * central_glow_effect;
	float burst = (radial_noise / (dist + 0.1)) * 0.5;

	float spikes = 0.0;
	float long_spikes = 0.0;
	float current_thickness = mix(inner_thickness, outer_thickness, clamp(dist * 2.0, 0.0, 1.0));
	for (int i = 0; i < 16; i++) {
		if (i >= spike_count) {
			break;
		}
		float spike_angle = (float(i) * TAU / float(spike_count)) + rotation_offset + TIME * 0.025;
		vec2 dir = vec2(cos(spike_angle), sin(spike_angle));
		float projection = abs(rel.x * dir.y - rel.y * dir.x);
		float side_mask = step(0.0, dot(rel, dir));
		float line = smoothstep(current_thickness, 0.0, projection) * side_mask;
		spikes = max(spikes, line);

		if (i == 1 || i == 9) {
			float long_projection = abs(rel.x * dir.y - rel.y * dir.x);
			float long_line = smoothstep(current_thickness * 0.75, 0.0, long_projection) * side_mask;
			long_spikes = max(long_spikes, long_line);
		}
	}
	spikes *= exp(-dist * spike_length);
	long_spikes *= exp(-dist * long_ray_length);

	float combined = (glow + burst * 0.18 + spikes * flare_intensity + long_spikes * long_ray_intensity) * master_brightness;
	float radial_fade = smoothstep(0.82, 0.0, dist);
	radial_fade *= radial_fade;
	float alpha = smoothstep(alpha_threshold, alpha_threshold + edge_smoothing, combined) * radial_fade;

	vec3 warm = mix(vec3(1.0, 0.76, 0.36), vec3(1.0), clamp(glow * 0.08, 0.0, 1.0));
	vec3 final_color = warm * combined;
	ALBEDO = final_color;
	EMISSION = final_color;
	ALPHA = alpha;
	if (alpha < 0.002) {
		discard;
	}
}
