shader_type spatial;
render_mode cull_disabled;
uniform bool floating_leaf = false;
void vertex() {
	float seed = MODEL_MATRIX[3].x * 0.13 + MODEL_MATRIX[3].z * 0.19;
	if (floating_leaf) {
		VERTEX.y += sin(TIME * 0.65 + seed) * 0.003;
	} else {
		float tip = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.15 + seed) * tip * tip * 0.04;
		VERTEX.z += cos(TIME * 0.8 + seed) * tip * 0.025;
	}
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = floating_leaf ? 0.58 : 0.92;
}
