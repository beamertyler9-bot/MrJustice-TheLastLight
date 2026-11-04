shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 body_color : source_color = vec4(0.8,0.5,0.2,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.9,0.7,1.0);
uniform vec4 rim_color : source_color = vec4(1.0,0.7,0.3,1.0);
uniform vec4 trail_color : source_color = vec4(0.7,0.3,1.0,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float sigil = 0.0;
void fragment() {
 vec2 p = UV*2.0-1.0; float r = length(p); float a = atan(p.y,p.x);
 if (sigil > 0.5 && sigil < 1.5) { r *= 1.0+cos(a*5.0)*0.20; }
 if (sigil > 2.5 && sigil < 3.5) { r *= 1.0+cos(a*6.0)*0.12; }
 float outer = exp(-pow((r-0.84)*120.0,2.0));
 float inner = exp(-pow((r-0.66)*100.0,2.0));
 float teeth = step(0.88,cos(a*24.0))*smoothstep(0.64,0.68,r)*(1.0-smoothstep(0.76,0.79,r));
 float runes = step(0.7,sin(a*17.0+floor(a*2.0)*3.0))*smoothstep(0.70,0.72,r)*(1.0-smoothstep(0.80,0.81,r));
 float clock_face = max(step(10.5,family),step(1.5,sigil)*(1.0-step(2.5,sigil)));
 float clock = clock_face*step(0.975,cos(a*12.0))*smoothstep(0.30,0.34,r)*(1.0-smoothstep(0.62,0.64,r));
 float fracture = mix(1.0,step(0.13,fract(a*0.7+age*0.025)),max(step(10.5,family),step(3.5,sigil)));
 ALBEDO = body_color.rgb;
 EMISSION = mix(body_color.rgb,core_color.rgb,0.35)*brightness;
 ALPHA = clamp(outer+inner*0.7+teeth+runes*0.6+clock,0.0,1.0)*opacity*fracture*mix(1.0,0.7,low_flash);
}
