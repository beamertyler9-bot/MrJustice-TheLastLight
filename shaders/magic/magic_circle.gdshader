shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Animated elemental magic circle (one per element): a 4 x 4 flipbook of 16 frames played at
// 11 frames a second, with a little extra glow so the thin lines read as light.
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float clock = 0.0;
uniform float opacity = 1.0;
uniform float glow = 1.15;
void fragment() {
	float frame = mod(floor(clock * 11.0), 16.0);
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	vec4 texel = texture(sheet, (cell + UV) / vec2(4.0, 4.0));
	ALBEDO = texel.rgb * glow;
	ALPHA = clamp(texel.a * 1.25, 0.0, 1.0) * opacity;
}
