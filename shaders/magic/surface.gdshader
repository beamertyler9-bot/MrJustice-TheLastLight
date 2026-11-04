shader_type spatial;
render_mode cull_disabled;
uniform vec4 body_color : source_color = vec4(0.12,0.48,0.76,1.0);
uniform vec4 core_color : source_color = vec4(0.85,0.98,1.0,1.0);
uniform vec4 rim_color : source_color = vec4(0.55,0.95,1.0,1.0);
uniform vec4 trail_color : source_color = vec4(0.3,0.7,1.0,1.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
uniform float contact_flash = 0.0;
uniform float is_contact = 0.0;
varying vec3 shape_position;
void vertex() {
 shape_position = VERTEX;
 // Small surface motion belongs to the object, never to its supplied flight path.
 if (family > 2.5 && family < 3.5) { VERTEX.y += sin(VERTEX.z * 11.0 + age * 2.0) * 0.018; }
 if (family > 4.5 && family < 5.5) { VERTEX.y += sin(VERTEX.x * 9.0 + VERTEX.z * 13.0 + age * 2.5) * 0.025; }
 if (family > 5.5 && family < 6.5) { VERTEX += NORMAL * sin(VERTEX.y * 13.0 + age * 3.0) * 0.012; }
}
void fragment() {
 float fresnel = pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),3.0);
 float facets = step(0.5,fract(UV.x*4.0+UV.y*2.0))*0.06;
 float vein = pow(max(0.0,sin(UV.x*31.0+sin(UV.y*15.0+age*0.3)*edge_noise)),17.0);
 float grain = sin(shape_position.x*91.0+sin(shape_position.z*43.0)*2.0)*sin(shape_position.y*79.0+shape_position.z*53.0);
 vec3 tint = body_color.rgb;
 vec3 detail = rim_color.rgb*fresnel*0.28 + core_color.rgb*vein*0.08;
 float metal = 0.20; float rough = 0.24; float alpha = 1.0;
 if (family > 0.5 && family < 1.5) {
  // Real screen refraction plus a low frequency internal caustic, kept narrow
  // enough to leave the faceted crystal ribs and individual splinters readable.
  vec2 bend = NORMAL.xy * (0.005 + fresnel*0.007) + vec2(grain,-grain)*0.0015;
  vec3 refracted = textureLod(screen_texture,clamp(SCREEN_UV+bend,vec2(0.002),vec2(0.998)),0.0).rgb;
  float cleavage = pow(abs(sin(shape_position.z*27.0+shape_position.x*17.0)),29.0);
  tint = mix(refracted,body_color.rgb,0.35+fresnel*0.35);
  detail = rim_color.rgb*(fresnel*0.42+cleavage*0.085)+core_color.rgb*vein*0.13;
  rough = 0.075; metal = 0.12; alpha = 0.76+fresnel*0.21;
 }
 if (family > 1.5 && family < 2.5) { tint *= 0.32; detail += core_color.rgb*(0.12+fresnel*0.40); rough = 0.10; }
 if (family > 2.5 && family < 3.5) {
  float midrib = exp(-abs(shape_position.x)*95.0);
  float branches = pow(max(0.0,cos(abs(shape_position.x)*41.0+shape_position.z*34.0)),24.0);
  tint *= 0.68+grain*0.075; detail = rim_color.rgb*(midrib*0.16+branches*0.10+fresnel*0.14); rough = 0.66; metal = 0.0;
 }
 if (family > 3.5 && family < 4.5) {
  vec3 prism = mix(rim_color.rgb,trail_color.rgb,0.5+0.5*sin(shape_position.z*17.0+shape_position.x*9.0));
  tint = mix(body_color.rgb,core_color.rgb,0.24); detail = prism*fresnel*0.45+core_color.rgb*vein*0.08; rough = 0.11; alpha = 0.87;
 }
 if (family > 4.5 && family < 5.5) {
  float torn = smoothstep(0.08,0.28,abs(sin(shape_position.x*18.0+shape_position.z*23.0+age*0.4)));
  tint *= 0.055; detail = rim_color.rgb*fresnel*0.18; rough = 0.90; alpha = mix(0.28,0.89,torn);
 }
 if (family > 5.5 && family < 6.5) {
  vec3 refracted = textureLod(screen_texture,clamp(SCREEN_UV+NORMAL.xy*0.009,vec2(0.002),vec2(0.998)),0.0).rgb;
  float caustic = pow(max(0.0,sin(shape_position.y*29.0+sin(shape_position.x*15.0+age*1.4)*2.0)),16.0);
  tint = mix(refracted,body_color.rgb,0.44); detail = rim_color.rgb*(fresnel*0.38+caustic*0.10); rough = 0.09; alpha = 0.59+fresnel*0.30;
 }
 if (family > 6.5 && family < 7.5) { tint *= 0.45; detail = rim_color.rgb*fresnel*0.30; alpha = 0.30+fresnel*0.30; rough = 0.12; }
 if (family > 7.5 && family < 8.5) {
  float fracture = pow(max(0.0,cos(shape_position.z*23.0+sin(shape_position.x*19.0)*3.0)),28.0);
  tint *= 0.52+grain*0.16; tint = mix(tint,tint*0.14,fracture*0.82);
  detail = rim_color.rgb*(fracture*0.065+fresnel*0.055); rough = 0.94; metal = 0.0;
 }
 if (family > 8.5 && family < 9.5) {
  float etch = step(0.94,cos(shape_position.z*58.0))*step(0.2,cos(shape_position.x*31.0));
  tint *= 0.77+sin(shape_position.z*330.0)*0.025; detail = rim_color.rgb*fresnel*0.30+core_color.rgb*etch*0.16;
  metal = 0.93; rough = 0.19;
 }
 if (family > 9.5 && family < 10.5) { tint *= 0.008; detail = rim_color.rgb*fresnel*0.075; rough = 0.18; metal = 0.10; }
 if (family > 10.5) { tint = mix(body_color.rgb*0.33,core_color.rgb*0.62,vein*0.55); detail = rim_color.rgb*fresnel*0.20+core_color.rgb*vein*0.12; metal = 0.66; rough = 0.22; alpha = 0.85; }
 if (style > 0.5 && style < 1.5) { tint = mix(tint,trail_color.rgb,facets*2.0); }
 if (style > 1.5 && style < 2.5) { tint = mix(tint,core_color.rgb,0.16); alpha *= 0.72; }
 if (style > 2.5 && style < 3.5) { tint = mix(tint,rim_color.rgb,step(0.5,fract(UV.x*6.0+UV.y*3.0))*0.13); rough = 0.08; }
 if (style > 3.5 && style < 4.5) { tint *= 0.07; rough = 1.0; }
 if (style > 4.5 && style < 5.5) { tint = mix(tint,core_color.rgb,vein*0.5); }
 if (style > 5.5 && style < 6.5) { detail += core_color.rgb*step(0.8,sin(UV.x*41.0))*step(0.0,sin(UV.y*29.0))*0.14; }
 if (style > 6.5) { tint = mix(tint,rim_color.rgb,pow(abs(sin(UV.y*31.0+sin(UV.x*9.0))),12.0)*0.28); rough = 0.65; }
 ALBEDO = mix(tint+facets*(1.0-fresnel)*0.35,rim_color.rgb,fresnel*0.14);
 EMISSION = (tint*0.075+detail+core_color.rgb*contact_flash*is_contact*0.065) * brightness;
 METALLIC = metal; ROUGHNESS = rough;
 ALPHA = opacity*alpha;
}
