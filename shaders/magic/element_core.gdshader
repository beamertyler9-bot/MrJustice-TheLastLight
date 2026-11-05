shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
// The heart of every spell: one sphere, shaded in the shared energy tones, but with a surface
// that is unmistakably its element. Fire churns and licks, frost cracks into facets, storm
// crackles, grove grows veins, light radiates, shadow is an ink drop with a lit rim, water
// wobbles with caustics, wind is a translucent swirl, earth glows through cracks, metal is
// banded and polished, void is a dark hole with a hot rim, time ticks around a clock face.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.98, 0.35, 0.05, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform vec4 rim_color : source_color = vec4(0.9, 0.2, 0.02, 1.0);
uniform vec4 trail_color : source_color = vec4(0.9, 0.2, 0.02, 1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
varying vec3 obj;

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm3(vec3 p) { return noise3(p) * 0.62 + noise3(p * 2.03 + 7.1) * 0.38; }
bool is_family(float f) { return abs(family - f) < 0.5; }

void vertex() {
	obj = VERTEX;
	float clock = age * mix(1.0, 0.45, low_flash);
	if (is_family(0.0)) {
		// Fire: the surface licks outward and upward.
		float lick = fbm3(VERTEX * 3.2 + vec3(0.0, -clock * 3.4, 0.0));
		VERTEX += NORMAL * (lick - 0.45) * 0.34 * (0.6 + edge_noise * 0.5) * (0.5 + max(VERTEX.y + 0.1, 0.0));
	} else if (is_family(6.0)) {
		// Water: a heavy, sloshing liquid drop (several slow waves, not a vibration).
		float slosh = sin(VERTEX.x * 5.0 + clock * 4.2) * sin(VERTEX.y * 4.0 - clock * 3.1) * 0.08
			+ sin(VERTEX.z * 7.0 - clock * 5.3 + VERTEX.y * 3.0) * 0.045
			+ sin(dot(VERTEX, vec3(3.0, 5.0, 2.0)) + clock * 6.4) * 0.025;
		VERTEX += NORMAL * slosh;
		VERTEX.y *= 0.92 + sin(clock * 3.6) * 0.06;
	} else if (is_family(8.0)) {
		// Earth: a lumpy boulder.
		VERTEX += NORMAL * (noise3(VERTEX * 4.0) - 0.5) * 0.28;
	} else if (is_family(5.0)) {
		// Shadow: a drop of ink that ripples.
		VERTEX += NORMAL * sin(VERTEX.y * 9.0 - clock * 4.0) * 0.035;
	}
}

void fragment() {
	float clock = age * mix(1.0, 0.45, low_flash);
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	vec3 body = body_color.rgb;
	vec3 core = core_color.rgb;
	float flash = contact_flash * is_contact;
	float v = facing;
	float alpha = 1.0;
	vec3 col;
	if (is_family(0.0)) {
		float n = fbm3(obj * 3.6 + vec3(0.0, -clock * 2.8, clock * 0.6));
		v = clamp(facing * 0.85 + (n - 0.5) * 1.1 + 0.08, 0.0, 1.0);
		col = energy_color(v, body, core);
		alpha = energy_alpha(v);
	} else if (is_family(1.0)) {
		// Frost: flat icy body with bright facet cracks.
		float facets = step(0.9, abs(sin(obj.x * 13.0 + obj.y * 7.0)) ) + step(0.92, abs(sin(obj.z * 11.0 - obj.y * 9.0)));
		v = 0.45 + facing * 0.25 + clamp(facets, 0.0, 1.0) * 0.32;
		col = energy_color(v, mix(body, core, 0.25), core);
		alpha = 0.9;
	} else if (is_family(2.0)) {
		// Storm: crackling filaments over a dark-blue plasma.
		float flick = floor(clock * 14.0);
		float arcs = 1.0 - toon_aa(0.08, abs(sin(obj.x * 8.0 + sin(obj.y * 9.0 + flick * 1.7) * 1.8 + flick)));
		arcs = max(arcs, 1.0 - toon_aa(0.06, abs(sin(obj.z * 10.0 - sin(obj.x * 7.0 - flick * 2.3) * 1.6))));
		v = clamp(facing * 0.55 + arcs * 0.5, 0.0, 1.0);
		col = energy_color(v, body * 0.85, core);
		alpha = energy_alpha(max(v, 0.32));
	} else if (is_family(3.0)) {
		// Grove: a green seed with growing light veins.
		float veins = 1.0 - toon_aa(0.05, abs(sin(atan(obj.z, obj.x) * 5.0 + obj.y * 6.0 + sin(obj.y * 4.0 + clock) * 0.8)));
		v = 0.38 + facing * 0.2 + veins * 0.4;
		col = energy_color(v, body, core);
	} else if (is_family(4.0)) {
		// Light: radiant sun, rays sweeping around a white heart.
		float rays = step(0.6, sin(atan(obj.y, obj.x) * 8.0 + clock * 2.0));
		v = clamp(pow(facing, 0.6) + rays * 0.12, 0.0, 1.0);
		col = energy_color(v, body, core);
		alpha = energy_alpha(max(v, 0.32));
	} else if (is_family(5.0)) {
		// Shadow: ink-dark heart, lit only at the rim.
		float rim = 1.0 - facing;
		v = clamp(rim * 1.15, 0.0, 1.0);
		col = mix(toon_ink(body) * 0.35, energy_color(0.4 + rim * 0.5, body, core), toon_aa(0.45, rim));
	} else if (is_family(6.0)) {
		// Water: see-through deep blue in the middle, a bright reflective rim, soft rippling
		// caustics, and two hard specular glints from a fixed sky light, like a toon water drop.
		vec3 n = normalize(NORMAL);
		vec3 sky = normalize(vec3(-0.45, 0.65, 0.6));
		float glint = pow(max(dot(reflect(-normalize(VIEW), n), sky), 0.0), 28.0);
		float glint2 = pow(max(dot(reflect(-normalize(VIEW), n), normalize(vec3(0.5, -0.3, 0.8))), 0.0), 40.0);
		float rim = 1.0 - facing;
		float ripple = sin(obj.x * 7.0 + sin(obj.y * 6.0 + clock * 2.4) * 1.6 + clock * 1.7) * sin(obj.z * 6.0 - clock * 1.3);
		float caustic = toon_aa(0.55, ripple);
		vec3 deep = mix(body * 0.55, body, 0.4);
		vec3 shallow = mix(body, core, 0.55);
		col = mix(deep, shallow, toon_aa(0.45, rim));
		col = mix(col, mix(shallow, core, 0.6), caustic * 0.55);
		col = mix(col, vec3(1.0), max(toon_aa(0.5, glint), toon_aa(0.6, glint2) * 0.8));
		alpha = mix(0.55, 0.92, toon_aa(0.4, rim)) + caustic * 0.12 + toon_aa(0.5, glint);
	} else if (is_family(7.0)) {
		// Wind: a translucent swirl of streaks.
		float swirl = step(0.55, fract(atan(obj.z, obj.x) * 0.477 + obj.y * 1.5 - clock * 2.2));
		v = 0.25 + swirl * 0.45;
		col = energy_color(v, body, core);
		alpha = (0.18 + swirl * 0.55) * (1.0 - facing * 0.5);
	} else if (is_family(8.0)) {
		// Earth: dark stone with magma-bright cracks.
		float cracks = 1.0 - toon_aa(0.07, abs(noise3(obj * 5.0) - 0.5));
		vec3 stone = mix(body * 0.45, body * 0.8, step(0.5, facing));
		col = mix(stone, energy_color(0.7, rim_color.rgb, core), cracks);
	} else if (is_family(9.0)) {
		// Metal: polished bands with a hard highlight.
		float bands = step(0.5, fract(obj.y * 6.0 + facing * 1.5));
		v = 0.3 + bands * 0.25 + step(0.93, facing) * 0.45;
		col = energy_color(v, mix(body, vec3(0.8), 0.35), core);
	} else if (is_family(10.0)) {
		// Void: a hole with a hot event-horizon rim.
		float rim = 1.0 - facing;
		col = mix(body * 0.08, energy_color(0.75, rim_color.rgb, core), toon_aa(0.55, rim));
	} else {
		// Time: a golden clock face with sweeping ticks.
		float ang = atan(obj.y, obj.x);
		float ticks = step(0.94, cos(ang * 12.0)) * step(0.55, facing);
		float hand = (1.0 - toon_aa(0.06, abs(sin(ang - clock * 1.5)))) * step(0.5, facing);
		v = 0.35 + facing * 0.2 + max(ticks, hand) * 0.4;
		col = energy_color(v, body, core);
	}
	col = mix(col, vec3(1.0), flash * 0.35);
	ALBEDO = col * clamp(brightness, 0.6, 1.6);
	ALPHA = clamp(alpha, 0.0, 1.0) * opacity;
}
