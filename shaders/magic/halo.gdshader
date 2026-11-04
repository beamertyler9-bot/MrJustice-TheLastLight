shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Glow cards: a flat toon disc with a crisp edge instead of a soft gaussian haze,
// plus a thin bright ring. Corona families draw just the ring.
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
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float scallop = 1.0 + sin(a * 8.0 + age * 1.3) * 0.035 * edge_noise;
	float rr = r * scallop;
	// Two flat tones: a faint outer glow disc and a brighter inner disc.
	float disc = 1.0 - toon_aa(0.55, rr);
	float inner = 1.0 - toon_aa(0.28, rr);
	float ring = toon_aa(0.62, rr) * (1.0 - toon_aa(0.68, rr));
	float corona = step(9.5, family);
	float value = mix(disc * 0.35 + inner * 0.45, ring * 0.8, corona);
	vec3 col = mix(body_color.rgb, core_color.rgb, inner * 0.6 * (1.0 - corona));
	ALBEDO = col * clamp(brightness, 0.6, 1.6);
	ALPHA = value * opacity * 0.4 * mix(1.0, 0.6, low_flash) * (family < 0.5 ? 1.0 : 0.8);
}
