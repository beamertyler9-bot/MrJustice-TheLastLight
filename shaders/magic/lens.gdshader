shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Void rifts: a flat dark hole ringed by bright inked bands. Replaces the old screen
// refraction, which forced a full-screen copy every frame on phones.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.15,0.06,0.28,1.0);
uniform vec4 core_color : source_color = vec4(0.83,0.65,1.0,1.0);
uniform vec4 rim_color : source_color = vec4(0.55,0.32,0.85,1.0);
uniform vec4 trail_color : source_color = vec4(0.25,0.08,0.45,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 10.0;
uniform float low_flash = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float warp = sin(a * 3.0 + age * 0.9) * 0.03 + sin(a * 7.0 - age * 0.6) * 0.015;
	float rr = r + warp;
	float hole = 1.0 - toon_aa(0.36, rr);
	float ring = toon_aa(0.36, rr) * (1.0 - toon_aa(0.47, rr));
	float outer = toon_aa(0.55, rr) * (1.0 - toon_aa(0.6, rr)) * step(0.0, sin(a * 2.0 + age * 0.38));
	float swirl = step(0.75, fract(a * 0.954 + r * 3.0 - age * 0.25)) * hole * (1.0 - toon_aa(0.3, rr));
	vec3 dark = body_color.rgb * 0.18;
	vec3 col = mix(dark, toon_ink(trail_color.rgb) * 1.4, swirl);
	// The event horizon uses the shared energy tones: hot ring, glow fringe outside it.
	float ring_v = ring * (0.72 + contact_flash * 0.2) + outer * 0.25;
	col = mix(col, energy_color(ring_v, rim_color.rgb, core_color.rgb), max(ring, outer));
	ALBEDO = col * mix(1.0, clamp(brightness, 0.6, 1.6), max(ring, outer));
	ALPHA = clamp(hole * 0.85 + ring + outer * 0.8, 0.0, 1.0) * opacity * mix(1.0, 0.8, low_flash);
}
