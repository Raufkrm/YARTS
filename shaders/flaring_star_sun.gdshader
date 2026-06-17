// Adapted from "Flaring Star" by halcyonxero on Godot Shaders.
// Source page lists the shader code under CC0:
// https://godotshaders.com/shader/flaring-star/
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float brightness = 1.15;
uniform float ray_brightness = 9.0;
uniform float gamma = 8.0;
uniform float spot_brightness = 11.0;
uniform float ray_density = 3.5;
uniform float curvature = 15.0;
uniform vec3 rgb = vec3(4.0, 1.0, 0.1);
uniform float emission_strength = 2.2;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(vec2 x) {
	x *= 1.75;
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n = p.x + p.y * 57.0;
	float res = mix(
		mix(hash(n + 0.0), hash(n + 1.0), f.x),
		mix(hash(n + 57.0), hash(n + 58.0), f.x),
		f.y
	);
	return res;
}

float fbm(vec2 p) {
	mat2 m2 = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float z = 2.0;
	float rz = 0.0;
	p *= 0.25;
	for (int i = 1; i < 6; i++) {
		rz += abs((noise(p) - 0.5) * 2.0) / z;
		z *= 2.0;
		p = p * 2.0 * m2;
	}
	return rz;
}

void fragment() {
	float t = -TIME * 0.03;
	vec2 centered_uv = UV - vec2(0.5);
	float quad_radius = length(centered_uv);
	float circular_mask = smoothstep(0.50, 0.24, quad_radius);
	vec2 uv = centered_uv;
	uv.x *= 1.7;
	uv *= curvature * 0.05 + 0.0001;

	float r = sqrt(dot(uv, uv));
	vec2 safe_uv = uv;
	if (length(safe_uv) < 0.0001) {
		safe_uv = vec2(0.0001, 0.0);
	}

	float x = dot(normalize(safe_uv), vec2(0.5, 0.0)) + t;
	float y = dot(normalize(safe_uv), vec2(0.0, 0.5)) + t;

	float val = fbm(vec2(r + y * ray_density, r + x * ray_density - y));
	val = smoothstep(gamma * 0.02 - 0.1, ray_brightness + (gamma * 0.02 - 0.1) + 0.001, val);
	val = sqrt(val);

	vec3 col = val / rgb;
	col = clamp(1.0 - col, 0.0, 1.0);
	col = mix(col, vec3(1.0), spot_brightness - r / 0.1 / curvature * 200.0 / brightness);
	col = clamp(col, 0.0, 1.0);
	col = pow(col, vec3(1.7));

	vec3 hot_core = mix(col, vec3(1.0, 0.92, 0.68), 0.45);
	hot_core *= circular_mask;
	float alpha = clamp(max(max(hot_core.r, hot_core.g), hot_core.b) * 1.35, 0.0, 1.0) * circular_mask;
	ALBEDO = hot_core;
	EMISSION = hot_core * emission_strength;
	ALPHA = alpha;
	if (alpha < 0.002) {
		discard;
	}
}
