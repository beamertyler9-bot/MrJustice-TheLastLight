shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float ink_width = 0.014;
uniform vec4 ink_color : source_color = vec4(0.035, 0.065, 0.095, 1.0);
uniform float world_time = 0.0;
uniform float wind_strength = 0.0;
uniform bool rooted = false;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = rooted ? clamp(VERTEX.y, 0.0, 1.5) : 0.7;
	float breeze = sin(p.x * 0.17 + p.z * 0.12 + world_time * 1.05) + sin(p.z * 0.31 - world_time * 0.72) * 0.35;
	VERTEX.x += breeze * weight * wind_strength;
	VERTEX.z += breeze * weight * wind_strength * 0.36;
	// World-unit widths keep a thin twig from inheriting a boulder's line size.
	// A radial hull closes the seams between flat box faces. Using each
	// face's split normal left cube corners with hairline gaps in the ink.
	vec3 radial = mat3(MODEL_MATRIX) * VERTEX;
	vec3 world_normal = length(radial) > 0.0001 ? normalize(radial) : normalize(MODEL_NORMAL_MATRIX * NORMAL);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_normal * ink_width;
}
void fragment() {
	ALBEDO = ink_color.rgb;
}
