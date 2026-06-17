// Adapted from "Star Nest" by ColorauGuiyino on Godot Shaders.
// Source page lists the shader code under MIT:
// https://godotshaders.com/shader/star-nest/
shader_type sky;

uniform float formuparam = 0.75;
uniform float stepsize = 0.1;
uniform float zoom = 0.85;
uniform float tile = 0.85;
uniform vec3 drift_speed = vec3(0.0, 0.00045, 0.00015);
uniform float brightness = 0.00008;
uniform float darkmatter = 0.55;
uniform float distfading = 0.55;
uniform float saturation = 0.0;
uniform vec3 space_tint : source_color = vec3(0.00055, 0.00145, 0.0042);

float scurve(float value) {
	if (value < 0.5) {
		return value * value * value * value * value * 16.0;
	}

	value -= 1.0;
	return value * value * value * value * value * 16.0 + 1.0;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	dir = normalize(vec3(dir.x * zoom, dir.y * zoom, dir.z));
	vec3 from = vec3(1.0, 0.5, 0.5) + drift_speed * TIME;

	float s = 0.1;
	float fade = 1.0;
	vec3 v = vec3(0.0);

	for (int r = 0; r < 20; r++) {
		vec3 p = from + s * dir * 0.5;
		p = abs(vec3(tile) - mod(p, vec3(tile * 2.0)));

		float pa = 1.0;
		float a = 1.0;
		for (int i = 0; i < 17; i++) {
			p = abs(p) / dot(p, p) - formuparam;
			a += abs(length(p) - pa);
			pa = length(p);
		}

		float dm = max(0.0, darkmatter - a * a * 0.001);
		a *= a * a;
		if (r > 6) {
			fade *= 1.0 - dm;
		}

		v += fade;
		v += vec3(s, s * s, s * s * s * s) * a * brightness * fade;
		fade *= distfading;
		s += stepsize;
	}

	v = mix(vec3(length(v)), v, saturation);
	vec3 color = v * 0.01;
	color.r = pow(color.r, 0.35);
	color.g = pow(color.g, 0.36);
	color.b = pow(color.b, 0.38);
	color.r = mix(color.r, scurve(color.r), 0.7);
	color.g = mix(color.g, scurve(color.g), 1.0);
	color.b = mix(color.b, scurve(color.b), 0.2);

	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 neutral_stars = vec3(luma) * 0.11;
	vec3 cold_space = vec3(luma * 0.02, luma * 0.028, luma * 0.045);
	COLOR = space_tint + cold_space + neutral_stars;
}
