// Based on "Starry/Space-themed sky" by spvcer3ii on Godot Shaders.
// Source code is published as CC0 by Godot Shaders:
// https://godotshaders.com/shader/starry-space-themed-sky/
shader_type sky;

uniform vec3 sun_color : source_color = vec3(5.0, 4.4, 2.8);
uniform float sun_size : hint_range(0.01, 1.0) = 0.035;
uniform float sun_blur : hint_range(0.01, 20.0) = 0.08;
uniform float star_density : hint_range(0.01, 1.0) = 0.65;
uniform float star_brightness : hint_range(0.1, 5.0) = 1.8;
uniform vec3 space_tint : source_color = vec3(0.005, 0.008, 0.018);

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = EYEDIR;
	float cos_theta = dot(dir, LIGHT0_DIRECTION);
	float sun_disc = smoothstep(1.0 - sun_size, 1.0 - sun_size + (sun_blur * 0.001), cos_theta);
	vec3 final_sun = sun_disc * sun_color;

	vec3 star_grid = floor(dir * 200.0 * star_density);
	float star_noise = hash(star_grid);
	vec3 stars = vec3(0.0);
	if (star_noise > 0.995) {
		float star_intensity = pow(hash(star_grid + 0.5), 10.0) * star_brightness;
		stars = vec3(star_intensity);
	}

	stars *= (1.0 - sun_disc);
	COLOR = space_tint + final_sun + stars;
}
