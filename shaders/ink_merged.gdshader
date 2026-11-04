shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float ink_width = 0.014;
uniform vec4 ink_color : source_color = vec4(0.035, 0.065, 0.095, 1.0);

void vertex() {
	// Rigid color batches retain each source primitive's radial hull in the
	// tangent channel. Expanding around the merged part's origin would change
	// the outlines of fingers, facial details and offset architecture.
	vec3 radial = mat3(MODEL_MATRIX) * TANGENT;
	vec3 world_normal = length(radial) > 0.0001 ? normalize(radial) : normalize(MODEL_NORMAL_MATRIX * NORMAL);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_normal * ink_width;
}
void fragment() {
	ALBEDO = ink_color.rgb;
}
