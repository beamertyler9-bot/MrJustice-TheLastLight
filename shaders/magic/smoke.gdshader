shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// Shared material: explicit per-contact simulation age arrives through instance custom data.
uniform float age = 0.0;
varying float smoke_age;
varying float smoke_phase;
void vertex() { smoke_age = age+INSTANCE_CUSTOM.x; smoke_phase = INSTANCE_CUSTOM.y; }
float hash21(vec2 p) {
 p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y);
}
float noise21(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 vec2 flow=p*3.0+vec2(smoke_phase*4.13,smoke_age*0.5);
 float density=noise21(flow)*0.65+noise21(flow*2.1+5.3)*0.35;
 float cloud=exp(-dot(p,p)*3.4)*smoothstep(1.0,0.35,length(p));
 ALBEDO=COLOR.rgb;
 ALPHA=cloud*smoothstep(0.15,0.7,density)*COLOR.a;
}
