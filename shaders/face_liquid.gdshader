shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform vec4 liquid_tint : source_color = vec4(0.35, 0.78, 0.30, 0.8);
void fragment() {
	float taper = mix(0.56, 0.90, smoothstep(0.05, 0.8, UV.y));
	float center = 0.5 + sin(UV.y * 5.5) * 0.06;
	vec2 p = vec2((UV.x - center) * 2.0 / taper, (UV.y - 0.5) * 2.0);
	float mask = 1.0 - smoothstep(0.78, 1.0, length(p));
	float shine = pow(max(0.0, 1.0 - abs(UV.x - center + 0.12) * 7.0), 8.0);
	ALBEDO = mix(liquid_tint.rgb, vec3(0.88, 0.97, 0.92), shine * 0.50);
	ROUGHNESS = 0.08;
	SPECULAR = 0.85;
	ALPHA = liquid_tint.a * mask;
}
