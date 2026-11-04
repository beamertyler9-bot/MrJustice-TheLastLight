shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.25;
void fragment() {
	float radial = length((UV - vec2(0.5)) * vec2(1.0, 1.15));
	ALBEDO = vec3(0.025, 0.05, 0.065);
	ALPHA = (1.0 - smoothstep(0.12, 0.50, radial)) * strength;
}
