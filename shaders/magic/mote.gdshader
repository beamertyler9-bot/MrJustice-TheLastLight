shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() { ALBEDO = COLOR.rgb; EMISSION = COLOR.rgb*0.42; ALPHA = COLOR.a; }
