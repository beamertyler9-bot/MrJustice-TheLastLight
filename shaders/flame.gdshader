shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.7;
void vertex() {
	VERTEX.x += sin(TIME * 7.0 - UV.y * 8.0) * UV.y * UV.y * 0.08;
	VERTEX.z += cos(TIME * 5.3 - UV.y * 6.0) * UV.y * 0.035;
}
void fragment() {
	float heat = pow(1.0 - UV.y, 0.7);
	vec3 fire = mix(vec3(1.0, 0.22, 0.025), vec3(1.0, 0.88, 0.38), heat);
	ALBEDO = fire;
	EMISSION = fire * emission_strength;
}
