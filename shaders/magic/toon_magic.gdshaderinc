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
