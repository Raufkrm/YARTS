shader_type spatial;
render_mode cull_back;

uniform float wing_root = 0.045;
uniform float flap_rate = 7.0;
uniform float flap_amount : hint_range(0.0, 1.0) = 1.0;
uniform float pose_time = -1.0;

void vertex() {
	// The body fits inside this threshold; embedded wing-root vertices stay fixed.
	float t = pose_time < 0.0 ? TIME : pose_time;
	float angle = sin(t * flap_rate + INSTANCE_CUSTOM.x * 6.283185) * 0.62 * flap_amount;
	float side = sign(VERTEX.x);
	float offset = max(abs(VERTEX.x) - wing_root, 0.0);
	float mask = step(wing_root + 0.05, abs(VERTEX.x));
	VERTEX.x += side * offset * (cos(angle) - 1.0) * mask;
	VERTEX.y += offset * sin(angle) * mask;
	float a = side * angle * mask;
	NORMAL.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * NORMAL.xy;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.93;
	SPECULAR = 0.15;
}
