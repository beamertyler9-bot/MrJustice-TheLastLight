shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float world_time = 0.0;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	float ripple = sin(world.x * 2.7 + world.z * 1.9 - world_time * 0.8);
	float broken = smoothstep(-0.75, 0.65, sin(world.x * 4.1 - world.z * 2.3 + ripple));
	ALBEDO = vec3(0.57, 0.68, 0.58);
	ROUGHNESS = 0.86;
	ALPHA = pow(edge, 1.2) * (0.22 + broken * 0.24) * (0.8 + ripple * 0.13);
}
