shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float close_detail : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool shine_enabled = true;
uniform float distance_scale = 1.0;
uniform vec4 stone_tint : source_color = vec4(1.0);
uniform float stone_tint_amount = 0.0;
uniform float rust_amount = 0.0;
uniform vec4 rust_color : source_color = vec4(0.40, 0.17, 0.075, 1.0);
varying float local_camera_distance;
varying vec3 rock_position;

void vertex() {
	rock_position = VERTEX;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float model_scale = max(length(MODEL_MATRIX[0].xyz), 0.001);
	local_camera_distance = distance(CAMERA_POSITION_WORLD, world_position) / model_scale * distance_scale;
}

void fragment() {
	// UV0.x is a texture-free mineral mask, never transparency. The engine's
	// existing filtered sky cubemap supplies reflections without another capture.
	float mineral = smoothstep(0.01, 0.70, UV.x);
	float detail = close_detail * (1.0 - smoothstep(12.0, 32.0, local_camera_distance));
	if (!shine_enabled) { detail = 0.0; }
	vec3 base = mix(COLOR.rgb, stone_tint.rgb, stone_tint_amount * (1.0 - mineral * 0.65));
	float rust = 0.0;
	if (rust_amount > 0.0) {
		// Object-space patches stay fixed as the camera and sun move. No texture fetch.
		float warp = sin(dot(rock_position, vec3(-2.3, 3.7, 5.1)));
		float fleck = 0.5 + 0.5 * sin(dot(rock_position, vec3(4.1, 6.7, 3.3)) + warp * 2.0);
		rust = rust_amount * mix(0.55, 1.0, smoothstep(0.3, 0.7, fleck));
		// Some seams remain exposed metal rather than uniformly rusty paint.
		rust *= mix(1.0, smoothstep(0.30, 0.65, fleck), mineral);
	}
	ALBEDO = mix(base, rust_color.rgb, rust);
	float exposed_metal = mineral * detail * (1.0 - rust);
	METALLIC = UV.x * metallic_strength * detail * (1.0 - rust);
	ROUGHNESS = mix(0.94, 0.36, exposed_metal);
	SPECULAR = mix(0.35, 0.5, exposed_metal);
}
