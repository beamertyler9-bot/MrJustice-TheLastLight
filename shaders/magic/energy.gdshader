shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Ribbons, trails and beams: a cel-shaded stroke with an ink edge, flat body and hot core.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.7,0.2,0.9,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.9,0.7,1.0);
uniform vec4 rim_color : source_color = vec4(0.8,0.4,1.0,1.0);
uniform vec4 trail_color : source_color = vec4(0.5,0.2,0.9,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float sigil = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
void vertex() {
	if (family > 9.5 && family < 10.5) {
		float a = atan(VERTEX.y, VERTEX.x);
		VERTEX.xy *= 1.0 + sin(a * 3.0 + age * 0.8) * 0.045 + sin(a * 7.0 - age * 0.6) * 0.018;
		VERTEX.z += sin(a * 2.0 + age * 0.5) * 0.045;
	}
}
void fragment() {
	float clock = age * mix(1.0, 0.42, low_flash);
	float edge = max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0));
	// Chunky, slow wobble instead of fine fibres: reads as a drawn brush stroke.
	float wobble = sin(UV.x * 21.0 - clock * 6.0) * 0.6 + sin(UV.x * 9.0 + clock * 2.3) * 0.4;
	float shape = clamp(edge + wobble * edge_noise * 0.16, 0.0, 1.0);
	// Speed-line notches travelling along the stroke.
	float dash = fract(UV.x * 6.0 - clock * 2.2);
	float cut = 1.0 - step(0.86, dash) * step(shape, 0.55) * 0.9;
	if (family > 10.5) { cut *= mix(0.15, 1.0, step(0.22, fract(UV.x * 9.0 + floor(clock * 4.0) * 0.07))); }
	if (family > 2.5 && family < 3.5) { cut *= step(0.15, fract(UV.x * 7.0)); }
	if (family > 4.5 && family < 5.5) { cut *= step(0.25, abs(sin(UV.x * 19.0 + clock * 0.6))); }
	if (family > 7.5 && family < 8.5) { cut *= step(0.25, fract(UV.x * 23.0)); }
	if (style > 5.5 && style < 6.5) { cut *= step(0.4, fract(UV.x * 19.0)); }
	vec3 body = mix(trail_color.rgb, body_color.rgb, 0.35);
	vec3 core = mix(core_color.rgb, vec3(1.0), 0.25);
	vec3 ink = toon_ink(rim_color.rgb);
	float core_at = (family > 1.5 && family < 2.5) ? 0.62 : 0.72;
	if (style > 3.5 && style < 4.5) {
		// Ink style: dark body with a bright lining.
		body = toon_ink(body_color.rgb) * 0.55;
		ink = rim_color.rgb;
		core = mix(rim_color.rgb, core_color.rgb, 0.5);
	}
	float flash = contact_flash * is_contact;
	vec3 col = toon_ramp(shape + flash * 0.18, ink, body, core, 0.28, core_at);
	// Small hard highlight glints sliding along the core.
	float glint = step(0.93, fract(UV.x * 3.0 - clock * 1.4)) * toon_aa(0.8, shape);
	col = mix(col, vec3(1.0), glint * 0.6 * (1.0 - low_flash * 0.6));
	col *= clamp(brightness, 0.6, 1.6);
	ALBEDO = col;
	EMISSION = col * 0.35;
	ALPHA = toon_aa(0.08, shape) * opacity * COLOR.a * cut;
}
