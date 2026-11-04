shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Restrained four-point accent adapted from Binbun3D's supplied CC0 HitFXFree.
// The existing Sprite3D atlas/pool still owns placement, frame and retirement.
uniform sampler2D impact_texture : source_color, filter_linear_mipmap;
uniform float progress = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 stamp = texture(impact_texture, UV);
	vec2 p = abs(fract(UV * vec2(6.0, 5.0)) * 2.0 - 1.0);
	float star = 1.0 - smoothstep(0.62, 0.92, pow(p.x, 0.55) + pow(p.y, 0.55));
	float accent = star * 0.28 * pow(1.0 - progress, 2.0);
	ALBEDO = COLOR.rgb * mix(vec3(1.0, 0.86, 0.60), vec3(1.0), stamp.r);
	ALPHA = min(0.64, max(stamp.a * 0.8, accent)) * COLOR.a;
}
