shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Cartoon fire: a noise-driven flame shape resolved into the shared energy tones
// (glow fringe, element body, hot core, white tongue).
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.98,0.26,0.015,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.84,0.36,1.0);
uniform vec4 rim_color : source_color = vec4(0.65,0.065,0.003,1.0);
uniform vec4 trail_color : source_color = vec4(0.9,0.12,0.01,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y);
}
float noise21(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise21(p) * 0.6 + noise21(p * 2.07 + 8.3) * 0.4;
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float phase = COLOR.r * 6.283185;
	float clock = age * mix(2.7, 1.0, low_flash) + phase * 3.17;
	// Lower-frequency flow than before so the licks are bold and few.
	vec2 flow = vec2(p.x * 2.2 + phase * 13.7, p.y * 3.2 - clock);
	float n = fbm(flow + vec2(fbm(flow * 0.5 + 2.1) * 1.6, 0.0));
	float width = mix(0.86, 0.14, pow(p.y, 0.85));
	float sway = sin(p.y * 4.3 - clock * 1.3) * p.y * 0.18;
	float density = (1.0 - abs(p.x + sway) / width) * (1.0 - p.y * 0.6);
	density += (n - 0.5) * mix(0.3, 1.2, edge_noise);
	density *= smoothstep(0.0, 0.1, p.y) * (1.0 - smoothstep(0.8, 1.0, p.y));
	vec3 body = body_color.rgb;
	vec3 core = core_color.rgb;
	if (style > 0.5 && style < 1.5) { body = mix(body, trail_color.rgb, 0.35); }
	float v = clamp(density * 1.05, 0.0, 1.0);
	vec3 col = energy_color(v, body, core);
	if (style > 3.5 && style < 4.5) { col = mix(rim_color.rgb, toon_ink(body_color.rgb) * 0.6, toon_aa(ENERGY_BODY_AT, v) * (1.0 - toon_aa(ENERGY_HOT_AT, v))); }
	col *= clamp(brightness, 0.6, 1.6);
	ALBEDO = col;
	EMISSION = col * 0.35;
	ALPHA = energy_alpha(v) * opacity * COLOR.a;
}
