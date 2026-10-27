shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D sight_mask : repeat_disable, filter_linear;
uniform float map_size = 4000.0;
uniform float dim_amount = 0.20;
uniform float desaturation : hint_range(0.0, 1.0) = 0.30;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	float sight = texture(sight_mask, world.xz / map_size + 0.5).r;
	vec3 scene_color = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(scene_color, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted_color = mix(scene_color, vec3(luminance), desaturation);
	ALBEDO = mix(muted_color, vec3(0.12, 0.16, 0.23), dim_amount);
	ALPHA = depth < 0.000001 ? 0.0 : (1.0 - sight);
}
