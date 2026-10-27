shader_type spatial;
render_mode cull_disabled;
uniform bool match_removed = false;
void fragment() {
	bool cord = COLOR.r > 0.30 && COLOR.g > 0.16 && COLOR.b > 0.08;
	bool ember = COLOR.r > 0.55 && COLOR.g < 0.16;
	if (match_removed && (cord || ember)) discard;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.75;
}
