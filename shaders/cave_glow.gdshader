shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Self-lit cave features: glowing mushroom caps, crystals, lava, ghost wisps.
// A slow breathing pulse (offset per instance by world position) keeps them alive.
// mode 0 = steady glow with a soft pulse, 1 = flowing lava, 2 = bobbing wisp.
uniform vec4 glow_color:source_color=vec4(.4,.9,.85,1);
uniform vec4 core_color:source_color=vec4(.9,1.,.95,1);
uniform float energy=1.2;
uniform int mode=0;
varying vec3 world;
varying float phase;
void vertex(){
 vec3 origin=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
 phase=fract(sin(dot(origin.xz,vec2(12.9898,78.233)))*43758.5453)*6.2831;
 if(mode==2){VERTEX.y+=sin(TIME*1.3+phase)*.18;VERTEX.x+=sin(TIME*.7+phase*1.7)*.08;}
 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
float hash21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float vnoise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float pulse=.82+.18*sin(TIME*1.6+phase);
 vec3 col;
 if(mode==1){
  // Lava: molten veins sliding slowly under a cooling crust.
  vec2 p=world.xz*1.3+vec2(TIME*.12,TIME*.07);
  float n=vnoise(p)*.6+vnoise(p*2.3-TIME*.2)*.4;
  float hot=smoothstep(.35,.75,n);
  col=mix(glow_color.rgb*.35,mix(glow_color.rgb,core_color.rgb,smoothstep(.65,.95,n)),hot);
  col*=.85+.15*sin(TIME*2.+phase);
 }else{
  float fres=pow(1.-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.,1.),2.);
  col=mix(glow_color.rgb,core_color.rgb,fres*.7)*pulse;
 }
 ALBEDO=col*energy;
}
