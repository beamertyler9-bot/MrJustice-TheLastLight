shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Particles: faces turned to the camera burn white-hot, edges keep the spell colour,
// and each mote twinkles on its own beat so clouds of sparks shimmer like confetti.
varying float twinkle;
void vertex() {
	twinkle = 0.5 + 0.5 * sin(TIME * 10.0 + float(INSTANCE_ID) * 2.39996);
}
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float hot = smoothstep(0.55, 0.7, facing);
	vec3 base = mix(COLOR.rgb, vec3(1.0), 0.12);
	ALBEDO = mix(base, mix(base, vec3(1.0), 0.7), hot * (0.45 + twinkle * 0.55));
	ALPHA = COLOR.a * (0.8 + twinkle * 0.2);
}
