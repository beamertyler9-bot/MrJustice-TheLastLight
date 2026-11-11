shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float world_time = 0.0;
uniform float radiance = 1.0;
uniform float manifestation = 1.0;
varying float feather_birth;
void vertex() {
	// The shoulder forms first, then the wrist, then the attached feathers.
	float start = CUSTOM0.a < -1.5 ? 0.10 : max(0.0, CUSTOM0.a);
	float end = CUSTOM0.a < -1.5 ? 0.20 : (CUSTOM0.a < 0.0 ? 0.10 : min(1.0, CUSTOM0.a + 0.52));
	feather_birth = smoothstep(start, end, manifestation);
	VERTEX = mix(CUSTOM0.xyz, VERTEX, feather_birth);
}
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float sweep = smoothstep(0.76, 0.98, sin(UV.y * 7.0 - world_time * 2.4));
	float shaft = (1.0 - smoothstep(0.015, 0.07, abs(UV.x - 0.5))) * (1.0 - UV.y);
	float barbs = sin(UV.y * 155.0 + abs(UV.x - 0.5) * 30.0) * 0.022;
	ALBEDO = COLOR.rgb * (0.82 + shaft * 0.06 + barbs);
	EMISSION = COLOR.rgb * radiance * (0.065 + rim * 0.20 + sweep * 0.035 + (1.0 - feather_birth) * 0.28);
	ROUGHNESS = 0.7;
}
