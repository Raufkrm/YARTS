shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D ground_detail : filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
varying vec3 ground_color;
varying float slope;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_color = pow(COLOR.rgb, vec3(2.2));
	slope = 1.0 - (MODEL_NORMAL_MATRIX * NORMAL).y;
}

void fragment() {
	// Two reads of a shared tile replace expensive procedural fragment noise.
	float broad = texture(ground_detail, world_position.xz * 0.0019).r;
	float fine = texture(ground_detail, world_position.xz * 0.055).r;
	float detail = 0.82 + broad * 0.26 + fine * 0.07;
	vec3 ground = ground_color * detail;
	float snow = smoothstep(0.65, 0.88, COLOR.r);
	float rock = smoothstep(0.08, 0.48, slope) * (1.0 - snow * 0.55);
	ground = mix(ground, pow(vec3(0.29, 0.31, 0.30), vec3(2.2)) * (0.85 + broad * 0.28), rock * 0.78);
	ALBEDO = ground;
	ROUGHNESS = 0.88 + fine * 0.10;
	SPECULAR = 0.16;
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.20;
}
