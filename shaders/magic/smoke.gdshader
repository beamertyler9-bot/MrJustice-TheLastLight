shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Shared material: explicit per-contact simulation age arrives through instance custom data.
// Cartoon puffs: lobed, two-tone, with a hard silhouette.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform float age = 0.0;
varying float smoke_age;
varying float smoke_phase;
void vertex() { smoke_age = age + INSTANCE_CUSTOM.x; smoke_phase = INSTANCE_CUSTOM.y; }
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y);
}
float noise21(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float lobes = 1.0 + sin(a * 5.0 + smoke_phase * 6.2832) * 0.12 + (noise21(p * 2.0 + vec2(smoke_phase * 4.13, smoke_age * 0.4)) - 0.5) * 0.3;
	float r = length(p) * lobes;
	float puff = 1.0 - toon_aa(0.78, r);
	// Light from the upper left: a flat highlight band on top of each puff.
	float lit = 1.0 - toon_aa(0.55, length(p - vec2(-0.18, -0.22)) * lobes);
	vec3 shade = COLOR.rgb * 0.72;
	ALBEDO = mix(shade, mix(COLOR.rgb, vec3(1.0), 0.18), lit);
	ALPHA = puff * COLOR.a;
}
