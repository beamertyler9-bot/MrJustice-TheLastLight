shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 body_color : source_color = vec4(0.6,0.3,1.0,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.9,0.7,1.0);
uniform vec4 rim_color : source_color = vec4(0.8,0.4,1.0,1.0);
uniform vec4 trail_color : source_color = vec4(0.6,0.2,1.0,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
void fragment() {
 vec2 p = UV*2.0-1.0; float r = length(p); float a = atan(p.y,p.x);
 float cloud = 0.78+0.12*sin(a*7.0+age*1.3+r*17.0)*edge_noise;
 float halo = exp(-r*r*7.0)*smoothstep(1.0,0.6,r);
 float corona = exp(-pow((r-0.62)*18.0,2.0))*cloud;
 float value = mix(halo,corona,step(9.5,family));
 ALBEDO = body_color.rgb; EMISSION = mix(body_color.rgb,rim_color.rgb,0.35)*brightness*0.65;
 ALPHA = value*opacity*0.30*mix(1.0,0.55,low_flash)*(family < 0.5 ? 1.0 : 0.70);
}
