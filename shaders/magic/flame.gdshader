shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Production adaptation of the approved layered native fire study.
uniform vec4 body_color : source_color = vec4(0.98,0.26,0.015,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.84,0.36,1.0);
uniform vec4 rim_color : source_color = vec4(0.65,0.065,0.003,1.0);
uniform vec4 trail_color : source_color = vec4(0.9,0.12,0.01,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float edge_noise = 0.5;
uniform float style = 0.0;
uniform float family = 0.0;
uniform float low_flash = 0.0;
float hash21(vec2 p) {
 p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y);
}
float noise21(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash21(i), hash21(i + vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
float fbm(vec2 p) {
 return noise21(p)*0.55 + noise21(p*2.07+8.3)*0.29 + noise21(p*4.13+17.4)*0.16;
}
void fragment() {
 vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
 float phase = COLOR.r * 6.283185;
 float clock = age * mix(2.7, 1.0, low_flash) + phase * 3.17;
 vec2 flow = vec2(p.x * 3.1 + phase * 13.7, p.y * 4.8 - clock);
 float curl = fbm(flow * 0.6 + vec2(clock * 0.19, 2.1));
 float n = fbm(flow + vec2(curl * 2.2, 0.0));
 float width = mix(0.82, 0.18, pow(p.y, 0.8));
 float sway = sin(p.y * 5.3 - clock * 1.3) * p.y * 0.16;
 float density = (1.0 - abs(p.x + sway) / width) * (1.0 - p.y * 0.65);
 density += (n - 0.49) * mix(0.25, 1.35, edge_noise);
 float alpha = smoothstep(-0.08,0.42,density)*smoothstep(0.0,0.12,p.y)*(1.0-smoothstep(0.74,1.0,p.y));
 float heat = clamp(density*1.45-p.y*0.20+(n-0.5)*0.32,0.0,1.0);
 vec3 color = mix(rim_color.rgb*0.72,body_color.rgb,smoothstep(0.0,0.35,heat));
 color = mix(color,core_color.rgb,smoothstep(0.32,0.86,heat));
 if (style > 0.5 && style < 1.5) { color = mix(color,trail_color.rgb,0.2+0.25*step(0.85,n)); }
 if (style > 1.5 && style < 2.5) { color = mix(color,core_color.rgb,0.3); alpha *= 0.58+0.22*n; }
 if (style > 2.5 && style < 3.5) { color = mix(body_color.rgb,core_color.rgb,floor(heat*4.0)/3.0); alpha *= step(0.08,density); }
 if (style > 3.5 && style < 4.5) { color = mix(body_color.rgb*0.05,rim_color.rgb,pow(heat,4.0)); }
 if (style > 4.5 && style < 5.5) { color = mix(body_color.rgb*0.30,core_color.rgb,smoothstep(0.45,0.65,n)); }
 if (style > 5.5 && style < 6.5) { alpha *= 0.35+0.65*step(0.4,sin(p.y*43.0+p.x*19.0)); }
 if (style > 6.5) { color = mix(body_color.rgb,rim_color.rgb,pow(abs(sin(p.y*23.0+p.x*7.0)),12.0)); alpha *= 0.65+0.35*sin(p.y*8.0); }
 ALBEDO = color * 0.45;
 EMISSION = color * brightness * mix(1.12,0.72,low_flash);
 ALPHA = alpha * (0.65+0.35*smoothstep(0.18,0.78,n)) * opacity * COLOR.a * 0.73;
}
