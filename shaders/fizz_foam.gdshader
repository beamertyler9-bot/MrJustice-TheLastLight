shader_type spatial;
// A flat ring of foam on the water: rings spread out where a waterfall lands or fizz rises.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 foam_color : source_color = vec4(0.94, 0.835, 0.643, 1.0);
uniform float strength = 0.75;
uniform float rings = 9.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q) * 2.0;
	float angle = atan(q.y, q.x);
	float wobble = noise(vec2(angle * 3.0, TIME * 0.4)) * 0.12;
	float ring = smoothstep(0.35, 1.0, sin((r + wobble) * rings - TIME * 2.6) * 0.5 + 0.5);
	float churn = noise(q * 18.0 + vec2(TIME * 0.6, -TIME * 0.5));
	float core = 1.0 - smoothstep(0.0, 0.45, r);
	float foam = clamp(core * 0.9 + ring * 0.6 * (0.5 + churn * 0.5), 0.0, 1.0);
	ALBEDO = foam_color.rgb;
	ALPHA = clamp(foam * (1.0 - smoothstep(0.7, 1.0, r)) * strength, 0.0, 1.0);
}
