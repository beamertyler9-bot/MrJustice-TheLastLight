shader_type spatial;
// A curtain of falling cola: streaks that pour down, foaming at the lip and the foot,
// with ragged see-through edges. Unshaded and single-pass, like the river water.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 liquid_color : source_color = vec4(0.443, 0.263, 0.165, 1.0);
uniform vec4 foam_color : source_color = vec4(0.94, 0.835, 0.643, 1.0);
uniform float speed = 1.6;
uniform float length_m = 100.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	float y = UV.y * length_m * 0.12;
	float t = TIME * speed;
	float columns = noise(vec2(UV.x * 22.0, y * 0.6 - t));
	float fine = noise(vec2(UV.x * 61.0, y * 2.0 - t * 2.3));
	float streak = smoothstep(0.62, 0.92, columns * 0.65 + fine * 0.45);
	float foot = smoothstep(0.78, 1.0, UV.y);
	float lip = 1.0 - smoothstep(0.0, 0.07, UV.y);
	float foam = clamp(streak * 0.5 + foot * 0.8 + lip * 0.4, 0.0, 1.0);
	vec3 body = mix(liquid_color.rgb * 0.55, liquid_color.rgb * 1.25 + vec3(0.05, 0.02, 0.0), smoothstep(0.3, 0.9, columns) * 0.7);
	ALBEDO = mix(body, foam_color.rgb, foam) * COLOR.r;
	float edge = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float ragged = smoothstep(0.1, 0.45, noise(vec2(UV.x * 9.0, y * 0.3 - t * 0.7)) * 0.7 + edge * 0.55);
	ALPHA = clamp((0.8 + foam * 0.2) * edge * ragged, 0.0, 1.0);
}
