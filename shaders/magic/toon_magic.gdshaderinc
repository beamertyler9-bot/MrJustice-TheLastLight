// Shared helpers for the cel-shaded magic look.
// Every spell surface resolves to three flat tones (ink outline, body, hot core) with
// anti-aliased band edges, matching the banded pack_toon shading used by the world.

float toon_aa(float edge, float x) {
	float w = max(fwidth(x) * 0.85, 0.0015);
	return smoothstep(edge - w, edge + w, x);
}

// Dark, saturated outline tone derived from a spell colour (never pure black, so
// shadow spells still read as coloured ink rather than holes in the screen).
vec3 toon_ink(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sat = mix(vec3(luma), c, 1.35);
	return clamp(sat * 0.42, 0.0, 1.0);
}

// Three-tone ramp: outline -> body -> core.
vec3 toon_ramp(float value, vec3 ink, vec3 body, vec3 core, float body_at, float core_at) {
	vec3 col = mix(ink, body, toon_aa(body_at, value));
	return mix(col, core, toon_aa(core_at, value));
}

// ---------------------------------------------------------------------------------------
// The one energy look every spell shares. Any shape is first reduced to a single value
// v (0 at its silhouette, 1 at its heart); v then picks four flat tones:
//   glow  (outer translucent fringe, element colour lifted toward the accent)
//   body  (the element colour)
//   hot   (the accent / core colour)
//   white (a small white-hot centre)
// Nothing is outlined in black: magic is light, so it reads by its glow on any ground.
const float ENERGY_BODY_AT = 0.3;
const float ENERGY_HOT_AT = 0.62;
const float ENERGY_WHITE_AT = 0.86;

vec3 energy_color(float v, vec3 body, vec3 core) {
	vec3 glow = mix(body, core, 0.3) * 1.12;
	vec3 col = mix(glow, body, toon_aa(ENERGY_BODY_AT, v));
	col = mix(col, core, toon_aa(ENERGY_HOT_AT, v));
	return mix(col, mix(core, vec3(1.0), 0.78), toon_aa(ENERGY_WHITE_AT, v));
}

float energy_alpha(float v) {
	return toon_aa(0.03, v) * mix(0.4, 1.0, toon_aa(ENERGY_BODY_AT, v));
}
