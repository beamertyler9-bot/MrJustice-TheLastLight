shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Ground and air sigils: glowing line art in the shared energy tones, with a soft
// shadow underneath so they read on sunlit grass, sand and snow alike.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.8,0.5,0.2,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.9,0.7,1.0);
uniform vec4 rim_color : source_color = vec4(1.0,0.7,0.3,1.0);
uniform vec4 trail_color : source_color = vec4(0.7,0.3,1.0,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float sigil = 0.0;
float band(float r, float center, float half_width) {
	return toon_aa(center - half_width, r) * (1.0 - toon_aa(center + half_width, r));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	if (sigil > 0.5 && sigil < 1.5) { r *= 1.0 + cos(a * 5.0) * 0.20; }
	if (sigil > 2.5 && sigil < 3.5) { r *= 1.0 + cos(a * 6.0) * 0.12; }
	float spin = age * 0.35;
	float outer = band(r, 0.84, 0.035);
	float inner = band(r, 0.66, 0.022);
	float teeth = step(0.80, cos(a * 24.0 + spin * 2.0)) * band(r, 0.72, 0.05);
	float runes = step(0.6, sin(a * 17.0 - spin + floor(a * 2.0) * 3.0)) * band(r, 0.755, 0.03);
	float clock_face = max(step(10.5, family), step(1.5, sigil) * (1.0 - step(2.5, sigil)));
	float ticks = clock_face * step(0.96, cos(a * 12.0)) * band(r, 0.47, 0.16);
	float fracture = mix(1.0, step(0.13, fract(a * 0.7 + age * 0.025)), max(step(10.5, family), step(3.5, sigil)));
	float lines = clamp(outer + inner + teeth + runes * 0.9 + ticks, 0.0, 1.0);
	// Glow: the same strokes, fattened, in the translucent glow tone.
	float halo_r = max(max(band(r, 0.84, 0.065), band(r, 0.66, 0.05)), band(r, 0.74, 0.07) * step(0.6, cos(a * 24.0 + spin * 2.0)));
	float glow = clamp(halo_r + lines, 0.0, 1.0);
	// A faint soft shadow under the glyph keeps it readable on sunlit grass, sand and snow.
	float shade = max(band(r, 0.84, 0.1), band(r, 0.66, 0.085)) * (1.0 - glow);
	float v = lines * 0.74 + (glow - lines) * 0.2;
	vec3 col = energy_color(v, body_color.rgb, core_color.rgb);
	col = mix(col, toon_ink(body_color.rgb) * 0.5, shade);
	col *= clamp(brightness, 0.6, 1.6);
	ALBEDO = col;
	EMISSION = col * 0.3 * (1.0 - shade);
	ALPHA = (max(energy_alpha(v) * glow, shade * 0.22)) * opacity * fracture * mix(0.95, 0.7, low_flash);
}
