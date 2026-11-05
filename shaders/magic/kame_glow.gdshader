shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// The aura sheath around a Kamehameha beam: two stepped glow bands plus a helix of energy
// spiralling down the beam. Additive, so it brightens whatever is behind it.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform bool tube = true;
uniform float low_flash = 0.0;
uniform float turns = 2.0;
uniform float spiral = 1.0;
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
	float aura = toon_aa(0.18, facing) * 0.16 + toon_aa(0.5, facing) * 0.16;
	float coil = fract(UV.x * 2.0 + UV.y * turns - age * mix(3.2, 1.4, low_flash));
	float helix = (1.0 - toon_aa(0.14, abs(coil - 0.5))) * toon_aa(0.12, facing) * spiral;
	vec3 tone = mix(body_color.rgb, core_color.rgb, 0.3);
	ALBEDO = mix(tone, mix(core_color.rgb, vec3(1.0), 0.5), helix);
	ALPHA = clamp(aura + helix * 0.55, 0.0, 1.0) * opacity * mix(1.0, 0.6, low_flash);
}
