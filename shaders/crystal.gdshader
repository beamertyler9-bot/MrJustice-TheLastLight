shader_type spatial;
uniform vec4 crystal_color : source_color = vec4(0.42, 0.81, 0.77, 1.0);
void fragment() {
	float edge = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 2.5);
	ALBEDO = mix(crystal_color.rgb * 0.7, crystal_color.rgb + vec3(0.10, 0.14, 0.12), edge * 0.65);
	ROUGHNESS = 0.28;
	METALLIC = 0.24;
	SPECULAR = 0.65;
	EMISSION = crystal_color.rgb * (0.07 + edge * 0.12);
}
void light() {
	float nl = dot(NORMAL, LIGHT);
	float bands = 0.28 + 0.34 * smoothstep(0.22, 0.25, nl) + 0.38 * smoothstep(0.65, 0.68, nl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * bands / PI;
}
