shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;

uniform sampler2D cell_tints : source_color, filter_nearest, repeat_disable;
uniform bool tint_enabled = true;
uniform vec2 grid_size = vec2(24.0, 12.0);
uniform float polar_span = 4.0;
uniform vec4 grid_color : source_color = vec4(0.9, 0.95, 1.0, 0.035);
uniform vec4 selected_rect = vec4(-2.0);
uniform vec4 selected_color : source_color = vec4(1.0, 0.92, 0.25, 1.0);
uniform vec4 hovered_rect = vec4(-2.0);
uniform vec4 hovered_color : source_color = vec4(0.5, 0.8, 0.65, 1.0);

vec4 over(vec4 base, vec4 layer) {
	float alpha = layer.a + base.a * (1.0 - layer.a);
	return vec4((layer.rgb * layer.a + base.rgb * base.a * (1.0 - layer.a)) / max(alpha, 0.00001), alpha);
}

float outline(vec2 point, vec2 pixel, vec4 rect) {
	if (rect.z <= rect.x || rect.w <= rect.y) { return 0.0; }
	vec4 distance_to_edge = vec4(point - rect.xy, rect.zw - point) / pixel.xyxy;
	float nearest = min(min(distance_to_edge.x, distance_to_edge.y), min(distance_to_edge.z, distance_to_edge.w));
	return 1.0 - smoothstep(0.5, 1.5, abs(nearest));
}

void fragment() {
	// This next pass uses the terrain's exact vertices and depth, with no shell
	// radius or vertex displacement. UV borders follow the actual cell bounds.
	vec2 point = UV * grid_size;
	vec2 pixel = max(fwidth(point), vec2(0.00001));
	float span = (point.y < 1.0 || point.y >= grid_size.y - 1.0) ? polar_span : 1.0;
	vec2 coordinate = point / vec2(span, 1.0);
	vec2 grid_distance = abs(fract(coordinate + 0.5) - 0.5) / max(fwidth(coordinate), vec2(0.00001));
	float grid_line = 1.0 - smoothstep(0.35, 1.1, min(grid_distance.x, grid_distance.y));
	vec4 tint = tint_enabled ? texture(cell_tints, UV) : vec4(0.0);
	tint = over(tint, vec4(grid_color.rgb, grid_color.a * grid_line));
	tint = over(tint, vec4(hovered_color.rgb, hovered_color.a * outline(point, pixel, hovered_rect)));
	tint = over(tint, vec4(selected_color.rgb, selected_color.a * outline(point, pixel, selected_rect)));
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
