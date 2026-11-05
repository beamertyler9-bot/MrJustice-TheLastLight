shader_type spatial;
// Butterflies (wings beating about the body) by day, blinking fireflies by night.
render_mode cull_disabled, shadows_disabled;
uniform bool night = false;
uniform float fade = 1.0;
varying float blink;
varying vec2 wing_uv;
varying vec2 local;
void vertex() {
	float phase = INSTANCE_CUSTOM.r; float speed = INSTANCE_CUSTOM.g;
	wing_uv = UV;
	local = VERTEX.xz;
	if (night) {
		// A glowing speck that always faces the camera.
		vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		POSITION = PROJECTION_MATRIX * vec4(centre + vec3(VERTEX.x, VERTEX.z, 0.0) * 1.1, 1.0);
		blink = smoothstep(0.35, 1.0, sin(TIME * 1.7 * speed + phase * 3.0)) * fade;
	} else {
		float flap = sin(TIME * 15.0 * speed + phase) * 0.95 + 0.35;
		float side = sign(VERTEX.x);
		float spread = abs(VERTEX.x);
		VERTEX.x = side * spread * cos(flap);
		VERTEX.y = spread * sin(flap);
		VERTEX *= fade;
		blink = 0.0;
		// (POSITION is written for fireflies, so it must be written here too.)
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
}
void fragment() {
	if (night) {
		// A small round glowing dot.
		if (length(local - vec2(0.0, 0.01)) > 0.042) discard;
		ALBEDO = vec3(0.05);
		EMISSION = COLOR.rgb * (0.5 + blink * 3.5);
	} else {
		// Darker edges and a spot on each wing.
		float edge = smoothstep(0.75, 1.0, wing_uv.x);
		float spot = 1.0 - smoothstep(0.08, 0.16, length(wing_uv - vec2(0.62, 0.55)));
		vec3 c = COLOR.rgb * mix(1.0, 0.35, edge);
		c = mix(c, vec3(0.12, 0.08, 0.06), spot * 0.8);
		ALBEDO = c;
		ROUGHNESS = 0.7;
		BACKLIGHT = COLOR.rgb * 0.4;
	}
}
