shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Glow cards in three stepped toon bands with a slowly turning four-point sparkle.
// The vertex colour picks a variant so one material serves several card meshes:
//   white            -> glow (projectile and impact halos)
//   red   (1,0,*)    -> shockwave ring that rides the contact flash
//   green (0,1,*)    -> star-burst flash at the moment of contact
// Corona families draw just the ring.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.6,0.3,1.0,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.9,0.7,1.0);
uniform vec4 rim_color : source_color = vec4(0.8,0.4,1.0,1.0);
uniform vec4 trail_color : source_color = vec4(0.6,0.2,1.0,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;

float star_arms(vec2 q, float reach, float thickness) {
	float arm_x = max(0.0, 1.0 - abs(q.x) / reach);
	float arm_y = max(0.0, 1.0 - abs(q.y) / reach);
	float a = (1.0 - toon_aa(thickness * arm_x * arm_x + 0.002, abs(q.y))) * step(abs(q.x), reach);
	float b = (1.0 - toon_aa(thickness * arm_y * arm_y + 0.002, abs(q.x))) * step(abs(q.y), reach);
	return max(a, b);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float flicker = mix(1.0, 0.92 + 0.08 * sin(age * 9.0), 1.0 - low_flash);
	float bright = clamp(brightness, 0.6, 1.6);
	vec3 col;
	float value;
	if (COLOR.g < 0.5) {
		// Shockwave: a crisp ring with a faint fill, thinning as it races outward.
		float ring = toon_aa(0.8, r) * (1.0 - toon_aa(0.93, r));
		float fill = (1.0 - toon_aa(0.8, r)) * toon_aa(0.45, r) * 0.18;
		col = mix(mix(body_color.rgb, core_color.rgb, 0.3) * 1.12, core_color.rgb, 0.6);
		value = (ring + fill) * 0.9;
	} else if (COLOR.r < 0.5) {
		// Contact star: eight hard rays (long cross + short diagonal) around a hot core.
		float c = cos(0.3), s = sin(0.3);
		vec2 q = mat2(vec2(c, s), vec2(-s, c)) * p;
		vec2 d = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * q;
		float rays = max(star_arms(q, 0.98, 0.09), star_arms(d, 0.55, 0.06) * 0.8);
		float hot = 1.0 - toon_aa(0.22, r);
		col = mix(core_color.rgb, vec3(1.0), 0.45 + hot * 0.4);
		value = clamp(rays + hot, 0.0, 1.0);
	} else {
		float scallop = 1.0 + sin(ang * 8.0 + age * 1.3) * 0.035 * edge_noise;
		float rr = r * scallop;
		// Three flat glow steps instead of a soft blob.
		float outer = 1.0 - toon_aa(0.56, rr);
		float mid = 1.0 - toon_aa(0.42, rr);
		float inner = 1.0 - toon_aa(0.22, rr);
		float ring = toon_aa(0.62, rr) * (1.0 - toon_aa(0.68, rr));
		float corona = step(9.5, family);
		// A small four-point sparkle that slowly turns and breathes.
		float t = age * 0.8;
		vec2 q = mat2(vec2(cos(t), sin(t)), vec2(-sin(t), cos(t))) * p;
		float sparkle = star_arms(q, 0.5 + 0.06 * sin(age * 5.0), 0.05) * (1.0 - corona);
		value = mix(outer * 0.12 + mid * 0.2 + inner * 0.34 + sparkle * 0.45, ring * 0.8, corona);
		col = mix(mix(body_color.rgb, core_color.rgb, 0.3) * 1.12, mix(core_color.rgb, vec3(1.0), 0.5), clamp(inner * 0.7 + sparkle, 0.0, 1.0) * (1.0 - corona));
		value *= (family < 0.5 ? 1.0 : 0.85);
	}
	ALBEDO = col * bright * flicker;
	ALPHA = clamp(value, 0.0, 1.0) * opacity * mix(1.0, 0.6, low_flash);
}
