// Lightweight RTS-cell adaptation of "Sky Sorta" by Toybreaker.
// The source shader is a large WIP sky shader with sun, atmosphere, stars,
// moons, volumetric clouds, and cheap cloud layers; this keeps the atmospheric
// gradient and sun disc only for the cell-view lighting context.
// https://godotshaders.com/shader/sky-sorta/
shader_type sky;

uniform vec3 sun_direction = vec3(0.45, 0.82, 0.35);
uniform float sun_amount = 0.82;
uniform float day_factor = 1.0;
uniform vec3 day_top_color : source_color = vec3(0.16, 0.38, 0.76);
uniform vec3 day_horizon_color : source_color = vec3(0.68, 0.82, 0.94);
uniform vec3 twilight_horizon_color : source_color = vec3(1.0, 0.43, 0.16);
uniform vec3 night_top_color : source_color = vec3(0.012, 0.018, 0.045);
uniform vec3 night_horizon_color : source_color = vec3(0.045, 0.055, 0.095);
uniform vec3 sun_color : source_color = vec3(1.0, 0.89, 0.58);
uniform float sun_size : hint_range(0.001, 0.08) = 0.010;
uniform float sun_glow : hint_range(0.0, 6.0) = 0.75;

void sky() {
	vec3 ray = normalize(EYEDIR);
	vec3 sun_dir = normalize(sun_direction);

	float altitude = clamp(ray.y * 0.5 + 0.5, 0.0, 1.0);
	float horizon = pow(1.0 - altitude, 2.25);
	float twilight = exp(-abs(sun_amount) * 5.0) * (1.0 - day_factor * 0.35);

	vec3 day_sky = mix(day_horizon_color, day_top_color, pow(altitude, 0.75));
	day_sky += twilight_horizon_color * horizon * twilight * 0.75;

	vec3 night_sky = mix(night_horizon_color, night_top_color, pow(altitude, 0.65));
	float star_hash = fract(sin(dot(floor(ray * 520.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float stars = step(0.9965, star_hash) * smoothstep(0.02, 0.34, altitude) * (1.0 - day_factor);
	night_sky += vec3(stars) * 0.85;

	vec3 color = mix(night_sky, day_sky, day_factor);

	float sun_dot = dot(ray, sun_dir);
	float sun_disc = smoothstep(cos(sun_size * 1.35), cos(sun_size), sun_dot);
	float glow = pow(max(sun_dot, 0.0), 42.0) * sun_glow;
	float visible_sun = smoothstep(-0.06, 0.08, sun_amount);
	color += sun_color * (sun_disc * 2.65 + glow * 0.24) * visible_sun;
	color += twilight_horizon_color * horizon * twilight * 0.30;

	COLOR = color;
}
