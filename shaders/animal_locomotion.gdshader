shader_type spatial;
render_mode cull_back;

uniform float phase = 0.0;
uniform float motion = 0.0;
uniform float body_height = 1.0;
uniform float belly_height = 0.42;
uniform float center_z = 0.0;
uniform bool penguin = false;

void vertex() {
	// Runtime gait for the unrigged animals. A smooth hip-to-foot falloff
	// keeps the trunk fixed while diagonal leg pairs take alternating steps.
	float leg = 1.0 - smoothstep(belly_height * 0.25, belly_height, VERTEX.y);
	float pair = (VERTEX.x >= 0.0 ? 1.0 : -1.0) * (VERTEX.z >= center_z ? 1.0 : -1.0);
	if (penguin) pair = VERTEX.x >= 0.0 ? 1.0 : -1.0;
	float swing = sin(phase) * pair * motion;
	VERTEX.z += swing * body_height * 0.15 * leg;
	VERTEX.y += max(0.0, cos(phase) * pair) * motion * body_height * 0.075 * leg;
	VERTEX.y += (1.0 - cos(phase * 2.0)) * body_height * 0.01 * motion;
	if (penguin) VERTEX.x += sin(phase) * motion * VERTEX.y * 0.055;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.94;
}
