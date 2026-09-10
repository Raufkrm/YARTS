shader_type canvas_item;

// Adapted for YARTS from "Yet Another Liquid Glass Shader" by Pcniado (CC0).
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.025, 0.16, 0.10, 0.76);
uniform vec4 edge_tint : source_color = vec4(0.40, 0.86, 0.62, 0.42);
uniform float corner_radius : hint_range(0.0, 0.5) = 0.055;
uniform float distortion_strength : hint_range(0.0, 8.0) = 1.35;
uniform float blur_radius : hint_range(0.0, 8.0) = 2.2;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.72;

float rounded_box_sdf(vec2 point, vec2 half_size, float radius) {
	vec2 distance = abs(point) - half_size + vec2(radius);
	return min(max(distance.x, distance.y), 0.0) + length(max(distance, 0.0)) - radius;
}

vec3 sample_blur(vec2 uv, vec2 pixel_size, float radius) {
	vec3 color = texture(screen_texture, uv).rgb * 0.28;
	color += texture(screen_texture, uv + vec2(pixel_size.x * radius, 0.0)).rgb * 0.12;
	color += texture(screen_texture, uv - vec2(pixel_size.x * radius, 0.0)).rgb * 0.12;
	color += texture(screen_texture, uv + vec2(0.0, pixel_size.y * radius)).rgb * 0.12;
	color += texture(screen_texture, uv - vec2(0.0, pixel_size.y * radius)).rgb * 0.12;
	color += texture(screen_texture, uv + pixel_size * radius).rgb * 0.06;
	color += texture(screen_texture, uv - pixel_size * radius).rgb * 0.06;
	color += texture(screen_texture, uv + vec2(pixel_size.x, -pixel_size.y) * radius).rgb * 0.06;
	color += texture(screen_texture, uv + vec2(-pixel_size.x, pixel_size.y) * radius).rgb * 0.06;
	return color;
}

void fragment() {
	vec2 pixel_scale = max(fwidth(UV), vec2(0.00001));
	vec2 rect_size = 1.0 / pixel_scale;
	vec2 local_position = (UV - 0.5) * rect_size;
	vec2 half_size = rect_size * 0.5;
	float radius = min(rect_size.x, rect_size.y) * corner_radius;
	float signed_distance = rounded_box_sdf(local_position, half_size, radius);
	if (signed_distance > 0.0) {
		discard;
	}

	float inner_distance = -signed_distance / max(min(rect_size.x, rect_size.y), 1.0);
	float edge = 1.0 - smoothstep(0.0, 0.09, inner_distance);
	vec2 direction = local_position / max(length(local_position), 0.001);
	vec2 refraction = direction * edge * distortion_strength * SCREEN_PIXEL_SIZE;
	vec3 background = sample_blur(SCREEN_UV - refraction, SCREEN_PIXEL_SIZE, blur_radius);
	vec3 tinted_background = mix(background, glass_tint.rgb, tint_strength);
	float top_glint = pow(clamp(1.0 - UV.y, 0.0, 1.0), 7.0) * 0.13;
	vec3 final_color = tinted_background + edge_tint.rgb * edge * 0.18 + vec3(top_glint);
	float alpha = clamp(glass_tint.a + edge * 0.08, 0.0, 0.94);
	COLOR = vec4(final_color, alpha);
}
