// Atmospheric shell inspired by "Sky++ but world-space" by smallcableboi.
// The source shader is a sky shader, so this is a lightweight spatial adaptation
// for the project planet instead of a direct skybox replacement.
// https://godotshaders.com/shader/sky-but-world-space/
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec3 sun_direction = vec3(0.74, 0.45, 0.50);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.84, 1.0);
uniform vec3 high_color : source_color = vec3(0.12, 0.34, 0.78);
uniform vec3 white_limb_color : source_color = vec3(1.0, 0.96, 0.82);
uniform vec3 baby_blue_color : source_color = vec3(0.62, 0.84, 1.0);
uniform vec3 bright_yellow_color : source_color = vec3(1.0, 0.88, 0.18);
uniform vec3 bright_red_color : source_color = vec3(1.0, 0.02, 0.0);
uniform vec3 dark_red_color : source_color = vec3(0.62, 0.0, 0.0);
uniform vec3 dark_yellow_color : source_color = vec3(0.35, 0.22, 0.035);
uniform float rim_power : hint_range(0.5, 12.0) = 7.4;
uniform float rim_strength : hint_range(0.0, 3.0) = 0.42;
uniform float day_strength : hint_range(0.0, 2.0) = 0.08;
uniform float alpha_multiplier : hint_range(0.0, 2.0) = 0.32;
uniform float face_fade_power : hint_range(0.5, 10.0) = 4.2;
uniform float planet_radius_ratio : hint_range(0.1, 1.0) = 0.82;
uniform float planet_radius_world = 2.0;
uniform float outer_fade_power : hint_range(0.5, 8.0) = 2.4;
uniform float warm_spill_strength : hint_range(0.0, 2.0) = 0.82;
uniform float dark_spill : hint_range(0.0, 1.0) = 0.45;
uniform float red_dark_spill : hint_range(0.0, 1.0) = 0.38;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ray_dir = normalize(world_position - CAMERA_POSITION_WORLD);
	float closest_t = max(0.0, -dot(CAMERA_POSITION_WORLD, ray_dir));
	vec3 closest_point = CAMERA_POSITION_WORLD + ray_dir * closest_t;
	if (length(closest_point) < planet_radius_world * 1.0) {
		discard;
	}

	vec3 normal = normalize(world_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 light_dir = normalize(sun_direction);

	float view_facing = clamp(dot(normal, view_dir), 0.0, 1.0);
	float rim_raw = 1.0 - view_facing;
	float planet_limb_rim = 1.0 - sqrt(max(0.0, 1.0 - planet_radius_ratio * planet_radius_ratio));
	float inner_at_surface = smoothstep(0.0, planet_limb_rim, rim_raw);
	float outward_distance = clamp((rim_raw - planet_limb_rim) / max(1.0 - planet_limb_rim, 0.001), 0.0, 1.0);
	float outward_fade = exp(-outward_distance * outer_fade_power);
	outward_fade *= 1.0 - smoothstep(0.90, 1.0, outward_distance);
	float atmosphere_band = inner_at_surface * outward_fade;
	float face_cut = pow(inner_at_surface, face_fade_power);
	float rim = pow(inner_at_surface, rim_power) * rim_strength * atmosphere_band;
	float sun_facing = clamp(dot(normal, light_dir), 0.0, 1.0);
	float signed_light = dot(normal, light_dir);
	float lit_side = smoothstep(-0.03, 0.18, signed_light);
	float twilight = exp(-abs(signed_light) * 7.0);
	float dark_spill_mask = smoothstep(-0.62, -0.04, signed_light);
	float red_spill_mask = smoothstep(-0.82, -0.08, signed_light) * (1.0 - smoothstep(0.16, 0.48, signed_light));
	float atmosphere_light = clamp(lit_side + dark_spill_mask * dark_spill, 0.0, 1.0);
	float day_haze = pow(sun_facing, 2.6) * day_strength * face_cut;
	float horizon_mix = clamp(rim * 2.2, 0.0, 1.0);
	float twilight_ramp = clamp((signed_light + 0.82) / 1.10, 0.0, 1.0);
	float twilight_strength = twilight * atmosphere_band * warm_spill_strength * 1.18 * smoothstep(-0.88, -0.03, signed_light) * (1.0 - smoothstep(0.34, 0.62, signed_light));

	vec3 color = mix(high_color, horizon_color, horizon_mix);
	color = mix(color, white_limb_color, clamp(pow(sun_facing, 5.0) * 0.9, 0.0, 1.0));
	vec3 twilight_color = dark_yellow_color;
	twilight_color = mix(twilight_color, dark_red_color, smoothstep(0.04, 0.18, twilight_ramp));
	twilight_color = mix(twilight_color, bright_red_color, smoothstep(0.18, 0.43, twilight_ramp));
	twilight_color = mix(twilight_color, bright_yellow_color, smoothstep(0.56, 0.64, twilight_ramp));
	twilight_color = mix(twilight_color, baby_blue_color, smoothstep(0.66, 0.86, twilight_ramp));
	float red_boost = (1.0 - smoothstep(0.44, 0.62, twilight_ramp)) * smoothstep(0.04, 0.22, twilight_ramp);
	twilight_color = mix(twilight_color, bright_red_color, red_boost * 0.46);
	color = mix(color, twilight_color, clamp(twilight_strength * (0.92 + red_dark_spill), 0.0, 0.94));
	color += horizon_color * day_haze;
	color *= atmosphere_light;
	float alpha = clamp((rim + day_haze * 0.12) * alpha_multiplier * atmosphere_band, 0.0, 0.45);
	alpha *= clamp(atmosphere_light + twilight * 0.16, 0.0, 1.0);
	alpha += clamp(twilight_strength * 0.14, 0.0, 0.14);

	ALBEDO = color;
	EMISSION = color * alpha;
	ALPHA = alpha;
	if (alpha < 0.003) {
		discard;
	}
}
