shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Hand-painted animated magic circle (one per element): a 5 x 4 flipbook played at
// 10 frames a second, with a little extra glow so it reads as light.
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float clock = 0.0;
uniform float opacity = 1.0;
uniform float glow = 1.15;
void fragment() {
	float frame = mod(floor(clock * 10.0), 20.0);
	vec2 cell = vec2(mod(frame, 5.0), floor(frame / 5.0));
	vec4 texel = texture(sheet, (cell + UV) / vec2(5.0, 4.0));
	ALBEDO = texel.rgb * glow;
	ALPHA = texel.a * opacity;
}
