shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Solid spell objects (blades, crystals, leaves, stone, metal) shaded with the same
// three-band toon lighting as the world (see pack_toon.gdshader), a crisp coloured rim,
// and flat per-element markings. No screen-texture refraction: glassy families use
// flat translucency instead, which avoids a full-screen copy on phones.
#include "res://shaders/magic/toon_magic.gdshaderinc"
uniform vec4 body_color : source_color = vec4(0.12,0.48,0.76,1.0);
uniform vec4 core_color : source_color = vec4(0.85,0.98,1.0,1.0);
uniform vec4 rim_color : source_color = vec4(0.55,0.95,1.0,1.0);
uniform vec4 trail_color : source_color = vec4(0.3,0.7,1.0,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
varying vec3 shape_position;
void vertex() {
	shape_position = VERTEX;
	// Small surface motion belongs to the object, never to its supplied flight path.
	if (family > 2.5 && family < 3.5) { VERTEX.y += sin(VERTEX.z * 11.0 + age * 2.0) * 0.018; }
	if (family > 4.5 && family < 5.5) { VERTEX.y += sin(VERTEX.x * 9.0 + VERTEX.z * 13.0 + age * 2.5) * 0.025; }
	if (family > 5.5 && family < 6.5) { VERTEX += NORMAL * sin(VERTEX.y * 13.0 + age * 3.0) * 0.012; }
}
void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = toon_aa(0.62, 1.0 - facing);
	float vein = step(0.9, sin(UV.x * 31.0 + sin(UV.y * 15.0 + age * 0.3) * edge_noise));
	vec3 tint = body_color.rgb;
	vec3 marks = core_color.rgb;
	float mark = vein * 0.6;
	float alpha = 1.0;
	float glow = 0.0;
	if (family > 0.5 && family < 1.5) {
		// Frost crystal: pale translucent body, bright facet stripes.
		float cleave = step(0.82, abs(sin(shape_position.z * 27.0 + shape_position.x * 17.0)));
		tint = mix(body_color.rgb, core_color.rgb, 0.35); mark = cleave; alpha = 0.82 + rim * 0.18; glow = 0.25;
	}
	if (family > 1.5 && family < 2.5) { tint = mix(body_color.rgb, core_color.rgb, 0.25); glow = 0.55; mark = vein; }
	if (family > 2.5 && family < 3.5) {
		// Leaf: midrib and side veins drawn as flat lines.
		float midrib = 1.0 - toon_aa(0.012, abs(shape_position.x));
		float branches = step(0.92, cos(abs(shape_position.x) * 41.0 + shape_position.z * 34.0));
		marks = mix(body_color.rgb, core_color.rgb, 0.6); mark = max(midrib, branches * 0.8);
	}
	if (family > 3.5 && family < 4.5) { tint = mix(body_color.rgb, core_color.rgb, 0.3); glow = 0.45; marks = mix(rim_color.rgb, trail_color.rgb, 0.5); alpha = 0.92; }
	if (family > 4.5 && family < 5.5) {
		// Shadow: inky body with torn see-through gaps.
		float torn = step(0.2, abs(sin(shape_position.x * 18.0 + shape_position.z * 23.0 + age * 0.4)));
		tint = toon_ink(body_color.rgb) * 0.5; alpha = mix(0.35, 0.95, torn); glow = 0.1;
	}
	if (family > 5.5 && family < 6.5) {
		float wave = step(0.75, sin(shape_position.y * 29.0 + sin(shape_position.x * 15.0 + age * 1.4) * 2.0));
		tint = mix(body_color.rgb, core_color.rgb, 0.2); mark = wave; alpha = 0.72 + rim * 0.25; glow = 0.2;
	}
	if (family > 6.5 && family < 7.5) { tint = mix(body_color.rgb, vec3(1.0), 0.3); alpha = 0.45 + rim * 0.45; glow = 0.3; }
	if (family > 7.5 && family < 8.5) {
		// Earth: chunky stone with dark crack lines.
		float crack = step(0.9, cos(shape_position.z * 23.0 + sin(shape_position.x * 19.0) * 3.0));
		tint = body_color.rgb * 0.95; marks = toon_ink(body_color.rgb); mark = crack;
	}
	if (family > 8.5 && family < 9.5) {
		float etch = step(0.94, cos(shape_position.z * 58.0)) * step(0.2, cos(shape_position.x * 31.0));
		tint = mix(body_color.rgb, vec3(0.85), 0.25); mark = etch; glow = 0.15;
	}
	if (family > 9.5 && family < 10.5) { tint = body_color.rgb * 0.12; glow = 0.05; }
	if (family > 10.5) { tint = mix(body_color.rgb * 0.5, core_color.rgb * 0.7, vein * 0.5); mark = vein; glow = 0.3; alpha = 0.9; }
	if (style > 3.5 && style < 4.5) { tint = toon_ink(tint) * 0.4; }
	if (style > 2.5 && style < 3.5) { mark = max(mark, step(0.5, fract(UV.x * 6.0 + UV.y * 3.0)) * 0.3); }
	vec3 base = mix(tint, marks, clamp(mark, 0.0, 1.0));
	float flash = contact_flash * is_contact;
	ALBEDO = base;
	// Coloured rim band (lit regardless of sun) and a flat element glow.
	// Same glow tone as every energy effect on the rim, so solid spell objects belong to the set.
	vec3 rim_glow = mix(body_color.rgb, core_color.rgb, 0.3) * 1.12;
	EMISSION = (rim_glow * rim * 0.6 + base * glow * 0.5 + core_color.rgb * flash * 0.35) * clamp(brightness, 0.6, 1.6);
	ALPHA = opacity * alpha;
}
void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float bands = 0.25 + smoothstep(0.13, 0.3, facing) * 0.35 + smoothstep(0.58, 0.76, facing) * 0.4;
	vec3 shade = mix(vec3(0.5, 0.55, 0.66), vec3(1.0), bands) * bands;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = step(0.97, max(dot(NORMAL, h), 0.0)) * 0.35;
	DIFFUSE_LIGHT += shade * LIGHT_COLOR * ATTENUATION / PI;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION;
}
