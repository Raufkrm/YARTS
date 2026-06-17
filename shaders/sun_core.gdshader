// Based on "SUN Script" by ArmouredJupiter on Godot Shaders.
// Source code is published as CC0 by Godot Shaders:
// https://godotshaders.com/shader/sun-script/
shader_type spatial;
render_mode unshaded, cull_back;

uniform float time = 0.0;
uniform vec3 base_color : source_color = vec3(1.0, 0.92, 0.38);
uniform float emission_strength = 1.65;

varying vec3 vert_pos;
varying vec3 world_normal;
varying vec3 world_pos;

vec3 mod289(vec3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
	return mod289(((x * 34.0) + 1.0) * x);
}

vec4 taylorInvSqrt(vec4 r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
	const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
	const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = mod289(i);
	vec4 p = permute(permute(permute(
		i.z + vec4(0.0, i1.z, i2.z, 1.0))
		+ i.y + vec4(0.0, i1.y, i2.y, 1.0))
		+ i.x + vec4(0.0, i1.x, i2.x, 1.0));
	float n_ = 0.142857142857;
	vec3 ns = n_ * D.wyz - D.xzx;
	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
	vec4 x_ = floor(j * ns.z);
	vec4 y_ = floor(j - 7.0 * x_);
	vec4 x = x_ * ns.x + ns.yyyy;
	vec4 y = y_ * ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);
	vec4 b0 = vec4(x.xy, y.xy);
	vec4 b1 = vec4(x.zw, y.zw);
	vec4 s0 = floor(b0) * 2.0 + 1.0;
	vec4 s1 = floor(b1) * 2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0));
	vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	vec3 p0 = vec3(a0.xy, h.x);
	vec3 p1 = vec3(a0.zw, h.y);
	vec3 p2 = vec3(a1.xy, h.z);
	vec3 p3 = vec3(a1.zw, h.w);
	vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
	m = m * m;
	return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.9;
	vec3 shift = vec3(100.0);
	for (int i = 0; i < 8; ++i) {
		v += a * snoise(p);
		p = p * 2.0 + shift;
		a *= 0.9;
	}
	return v;
}

float fbm_detail(vec3 p) {
	float v = 0.0;
	float a = 0.9;
	vec3 shift = vec3(50.0);
	for (int i = 0; i < 8; ++i) {
		v += a * snoise(p);
		p = p * 3.0 + shift;
		a *= 0.9;
	}
	return v;
}

void vertex() {
	vert_pos = normalize(VERTEX);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 pos = vert_pos * 0.9 + vec3(time * -0.05);
	float n1 = fbm(pos);
	n1 = n1 * 2.0 + 0.9;
	float n2 = fbm(pos + vec3(40.0));
	n2 = n2 * 0.9 + 0.9;
	float base_noise = n1 * 0.6 + n2 * 0.9;
	base_noise = clamp(base_noise, 0.0, 1.0);
	float detail = fbm_detail(pos * 5.0 + vec3(30.0));
	detail = detail * 0.5 + 0.5;
	base_noise += detail * 0.15;
	base_noise = clamp(base_noise, 0.0, 1.0);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float rim = 1.0 - max(dot(world_normal, view_dir), 0.0);
	rim = pow(rim, 2.0);
	vec3 radiant_glow = vec3(1.0, 0.9, 0.6) * rim * 0.9;

	vec3 yellow = mix(vec3(1.0, 0.55, 0.0), base_color, 0.35);
	vec3 orange = vec3(1.0, 0.27, 0.0);
	vec3 red = vec3(0.8, 0.2, 0.0);
	vec3 color = mix(yellow, orange, base_noise);
	color = mix(color, red, detail * 0.9);
	color += radiant_glow;

	ALBEDO = color;
	EMISSION = color * emission_strength;
}
