shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform float world_time = 0.0;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world.xz;
	float broad = sin(dot(p, vec2(0.42, 0.31)) + world_time * 0.57);
	float ripple = sin(dot(p, vec2(-1.17, 0.81)) - world_time * 0.91 + broad * 0.52);
	float fine = sin(p.x * 2.6 + p.y * 1.75 + world_time * 1.1) * sin(p.y * 2.9 - world_time * 0.75);
	vec2 slope = vec2(cos(dot(p, vec2(0.42, 0.31)) + world_time * 0.57) * 0.042, cos(dot(p, vec2(-1.17, 0.81)) - world_time * 0.91 + broad * 0.52) * 0.055);
	NORMAL = normalize(NORMAL + vec3(slope.x, slope.y, 0.0));
	float glint = pow(max(0.0, ripple * 0.6 + fine * 0.4), 10.0);
	float wave_line = smoothstep(0.93, 0.99, ripple) * (0.35 + broad * 0.1);
	vec3 deep = vec3(0.025, 0.15, 0.21);
	vec3 light = vec3(0.10, 0.38, 0.42);
	ALBEDO = mix(deep, light, smoothstep(-0.1, 0.1, broad) * 0.40 + 0.22);
	ALBEDO += vec3(0.53, 0.64, 0.52) * (glint * 0.25 + wave_line * 0.11);
	ALBEDO = mix(ALBEDO, vec3(0.025, 0.10, 0.15), smoothstep(0.978, 0.992, ripple) * 0.65);
	ROUGHNESS = 0.22 + (1.0 - glint) * 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.65;
	ALPHA = 0.91;
}
