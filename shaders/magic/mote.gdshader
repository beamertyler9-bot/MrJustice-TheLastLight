shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Particles: flat colour with a slight lift so embers and sparkles pop like confetti.
void fragment() { ALBEDO = mix(COLOR.rgb, vec3(1.0), 0.12); ALPHA = COLOR.a; }
