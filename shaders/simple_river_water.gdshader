// YARTS adaptation of "Simple animated 3d water" from Godot Shaders.
// Uses two animated normal-map noise textures for both oceans and rivers.
// https://godotshaders.com/shader/simple-animated-3d-water/
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform bool use_river_flow = true;
uniform vec3 uAlbedo : source_color = vec3(0.04, 0.32, 0.54);
uniform sampler2D uTexureNormal;
uniform sampler2D uTexureNormal2;
uniform float uNormalMix: hint_range(0.0, 1.0, 0.01) = 0.38;
uniform vec2 uWaveDirection = vec2(1.0, 0.0);
uniform vec2 uWaveDirection2 = vec2(0.0, 1.0);
uniform float uTimeScale: hint_range(0.0, 0.2, 0.001) = 0.025;
uniform float uWaveScale = 16.0;

uniform vec4 deep_water_color : source_color = vec4(0.005, 0.035, 0.085, 1.0);
uniform vec4 shallow_water_color : source_color = vec4(0.10, 0.45, 0.68, 1.0);
uniform vec4 foam_color : source_color = vec4(0.70, 0.92, 1.0, 0.35);
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform float normal_depth : hint_range(0.0, 2.0, 0.01) = 0.65;
uniform float ripple_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float day_factor : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec3 sun_direction = vec3(0.2, 0.8, 0.4);

void fragment() {
	vec2 encoded_flow = COLOR.rg * 2.0 - vec2(1.0);
	vec2 vertex_flow = length(encoded_flow) > 0.01 ? normalize(encoded_flow) : normalize(flow_direction);
	vec2 flow = use_river_flow ? vertex_flow : normalize(flow_direction);
	vec2 river_cross = vec2(-flow.y, flow.x);
	vec2 direction_1 = use_river_flow ? flow : normalize(uWaveDirection);
	vec2 direction_2 = use_river_flow ? normalize(flow * 0.55 + river_cross * 0.45) : normalize(uWaveDirection2);
	float speed_scale = use_river_flow ? 1.0 : 0.85;
	float scale = use_river_flow ? uWaveScale : uWaveScale * 0.46;

	vec2 time_1 = TIME * direction_1 * uTimeScale * speed_scale;
	vec2 time_2 = TIME * direction_2 * uTimeScale * speed_scale * 1.46;
	vec2 uv_1 = UV * scale + time_1;
	vec2 uv_2 = UV * (scale * (use_river_flow ? 1.84 : 0.72)) + time_2;
	vec3 normal_1 = texture(uTexureNormal, uv_1).rgb;
	vec3 normal_2 = texture(uTexureNormal2, uv_2).rgb;
	vec3 normal = mix(normal_1, normal_2, uNormalMix);
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_depth;

	float normal_energy = dot(normal, vec3(0.22, 0.55, 0.23));
	float foam = smoothstep(0.78, 0.98, normal_energy) * ripple_strength;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), use_river_flow ? 2.2 : 3.4);
	float shallow_mix = clamp(normal_energy * (use_river_flow ? 0.28 : 0.18) + fresnel * (use_river_flow ? 0.12 : 0.36), 0.0, 1.0);
	vec3 daylight_water = mix(deep_water_color.rgb, shallow_water_color.rgb, shallow_mix);
	daylight_water = mix(daylight_water, uAlbedo, use_river_flow ? 0.50 : 0.34);
	daylight_water = mix(daylight_water, foam_color.rgb, foam);
	daylight_water = mix(daylight_water, vec3(0.52, 0.78, 0.92), fresnel * (use_river_flow ? 0.08 : 0.20));

	float sun_glint = pow(max(dot(normalize(vec3(0.25, 0.92, 0.28)), normalize(sun_direction)), 0.0), use_river_flow ? 7.0 : 18.0);
	sun_glint *= smoothstep(0.54, 0.96, normal_energy) * day_factor * (use_river_flow ? 0.10 : 0.26);
	vec3 night_water = deep_water_color.rgb * (use_river_flow ? 0.42 : 0.52) + vec3(0.0, 0.025, 0.07) * (0.35 + normal_energy * 0.26);
	vec3 color = mix(night_water, daylight_water + sun_glint, day_factor);

	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = use_river_flow ? mix(0.48, 0.28, day_factor) : mix(0.34, 0.14, day_factor);
	SPECULAR = use_river_flow ? mix(0.24, 0.46, day_factor) : mix(0.40, 0.72, day_factor);
	ALPHA = mix(alpha * 0.92, alpha, day_factor) * COLOR.a;
}
