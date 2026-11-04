shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 body_color : source_color = vec4(0.7,0.2,0.9,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.9,0.7,1.0);
uniform vec4 rim_color : source_color = vec4(0.8,0.4,1.0,1.0);
uniform vec4 trail_color : source_color = vec4(0.5,0.2,0.9,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float sigil = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
void vertex() {
 if (family > 9.5 && family < 10.5) {
  float a = atan(VERTEX.y,VERTEX.x);
  VERTEX.xy *= 1.0+sin(a*3.0+age*0.8)*0.045+sin(a*7.0-age*0.6)*0.018;
  VERTEX.z += sin(a*2.0+age*0.5)*0.045;
 }
}
void fragment() {
 float edge = max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0));
 float clock = age * mix(1.0, 0.42, low_flash);
 float fibers = 0.72 + 0.28 * sin(UV.x * 71.0 - clock * 9.0 + UV.y * 4.0);
 float waves = sin(UV.x * 39.0 - clock * 7.0 + sin(UV.x * 17.0 + clock) * 1.7);
 float boundary = clamp(edge + waves * edge_noise * 0.21, 0.0, 1.0);
 float hot = pow(edge, 7.0) * (0.72 + fibers * 0.28);
 float cut = 1.0;
 if (family > 10.5) { cut = mix(0.13, 1.0, step(0.2, fract(UV.x * 9.0 + floor(clock * 4.0) * 0.07))); }
 if (style > 5.5 && style < 6.5) { cut *= 0.5 + 0.5 * step(0.45, fract(UV.x * 19.0)); }
 vec3 tint = mix(trail_color.rgb, rim_color.rgb, pow(edge, 0.4) * 0.25);
 if (style > 3.5 && style < 4.5) { tint = mix(body_color.rgb * 0.1, rim_color.rgb, pow(edge, 11.0)); }
 // Family microstructure changes the existing ribbon and edge geometry;
 // flame keeps its reviewed equation below.
 float detail = 0.0; float family_gain = 1.0;
 if (family > 0.5 && family < 1.5) { detail = pow(max(0.0,cos(UV.x*113.0+UV.y*17.0)),25.0)*0.24; family_gain = 0.87; }
 if (family > 1.5 && family < 2.5) { hot = pow(edge,10.0); detail = hot*0.42; family_gain = 1.05; }
 if (family > 2.5 && family < 3.5) { cut *= 0.72+0.28*step(0.2,sin(UV.x*43.0)); detail = pow(max(0.0,cos(UV.x*51.0-UV.y*9.0)),14.0)*0.12; family_gain = 0.84; }
 if (family > 3.5 && family < 4.5) { detail = pow(max(0.0,cos(UV.x*61.0)),25.0)*0.20; family_gain = 0.90; }
 if (family > 4.5 && family < 5.5) { cut *= smoothstep(0.0,0.35,abs(sin(UV.x*39.0+clock*0.6))); family_gain = 0.46; }
 if (family > 5.5 && family < 6.5) { detail = pow(max(0.0,sin(UV.x*67.0-clock*3.0+sin(UV.y*9.0)*2.0)),17.0)*0.17; family_gain = 0.83; }
 if (family > 6.5 && family < 7.5) { cut *= 0.33+0.67*smoothstep(-0.5,0.6,sin(UV.x*13.0-clock*1.5)); detail = pow(edge,17.0)*0.11; family_gain = 0.68; }
 if (family > 7.5 && family < 8.5) { cut *= 0.45+0.55*step(0.25,fract(UV.x*23.0)); family_gain = 0.68; }
 if (family > 8.5 && family < 9.5) { detail = pow(max(0.0,sin(UV.x*137.0)),30.0)*0.22; family_gain = 0.86; }
 if (family > 9.5 && family < 10.5) { cut *= 0.42+0.58*smoothstep(-0.35,0.2,sin(UV.x*12.0+clock*0.35)); hot *= 0.38; family_gain = 0.68; }
 if (family > 10.5) { detail = step(0.92,cos(UV.x*97.0))*0.15; family_gain = 0.84; }
 ALBEDO = tint * 0.4;
 EMISSION = (tint * (0.58 + fibers * 0.20) + core_color.rgb * (hot * 0.30+detail+contact_flash*is_contact*hot*0.16)) * brightness * family_gain;
 ALPHA = pow(boundary, 1.6) * opacity * COLOR.a * cut;
}
