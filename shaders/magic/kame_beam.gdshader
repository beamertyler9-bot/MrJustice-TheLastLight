shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
// Kamehameha-style energy beam body (also its muzzle and head orbs). The tube is shaded by
// how squarely each point faces the camera, so from any angle it reads as a solid column of
// light: white-hot down the middle, element colour around it, a translucent glow at the
// silhouette. Bulges travel down its length and bright streaks race along the surface.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform bool tube = true;
uniform float brightness = 1.0;
uniform float low_flash = 0.0;
uniform float wave = 1.0;
uniform float length_m = 1.0;
varying float along;
void vertex() {
	along = VERTEX.y;
	float travel = age * mix(26.0, 12.0, low_flash);
	float pulse = sin(VERTEX.y * 5.0 - travel) * 0.07 + sin(VERTEX.y * 11.0 - travel * 1.4) * 0.035;
	VERTEX.xz *= 1.0 + pulse * wave;
}
void fragment() {
	// Shade by the beam's cross-section, not the raw view angle: looking down a beam from
	// behind the hero must still show a solid column, not a ghost.
	vec3 view_dir = normalize(VIEW);
	if (tube) {
		vec3 axis = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		vec3 across = view_dir - axis * dot(view_dir, axis);
		if (dot(across, across) > 1.0e-5) view_dir = normalize(across);
	}
	float facing = clamp(abs(dot(normalize(NORMAL), view_dir)), 0.0, 1.0);
	float v = pow(facing, 1.6);
	// Streaks of light racing from the hands toward the target.
	float streak = step(0.82, fract(UV.x * 5.0 + along * 0.35 - age * 6.0)) * step(0.5, fract(along * 0.9 - age * 9.0)) * wave;
	v = clamp(v + streak * 0.22 * (1.0 - low_flash * 0.5), 0.0, 1.0);
	vec3 col = energy_color(v, body_color.rgb, core_color.rgb) * clamp(brightness, 0.6, 1.8);
	ALBEDO = col;
	ALPHA = energy_alpha(max(v, 0.05)) * opacity;
}
