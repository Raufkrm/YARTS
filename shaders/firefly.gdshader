shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float flight_time = 0.0;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
varying float phase;
void vertex() {
	phase = INSTANCE_CUSTOM.r;
	float speed = INSTANCE_CUSTOM.a;
	float t = flight_time * speed + phase;
	vec3 offset = vec3(sin(t) * 3.0, sin(t * 1.7) * 0.65, cos(t * 0.83) * 3.0);
	vec3 center = MODEL_MATRIX[3].xyz + offset;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
	UV.x = (UV.x + mod(floor(flight_time * 10.0 + phase), 2.0)) * 0.5;
}
void fragment() {
	vec4 sprite = texture(atlas, UV);
	float pulse = 0.7 + 0.3 * sin(flight_time * 2.2 + phase);
	float yellow = smoothstep(0.12, 0.45, sprite.r - sprite.b);
	ALBEDO = sprite.rgb;
	EMISSION = vec3(1.0, 0.74, 0.06) * yellow * 3.0 * pulse * night_factor;
	ALPHA = sprite.a * night_factor;
}
