shader_type spatial;
render_mode cull_disabled;
// Underground stone for caves and dungeons, projected in world space so walls, floors,
// stalactites and boulders all share one continuous rock.
//  - Caves: layered strata, dark crevices and cracks, a darker ceiling, and a band of
//    moss / dust / ash (accent colour) gathering where the walls meet the floor.
//  - Dungeons: offset ashlar masonry, each block a slightly different shade, with grime
//    creeping up from the floor and the odd mossy block.
uniform vec4 stone_color:source_color=vec4(.30,.33,.36,1);
uniform vec4 grout_color:source_color=vec4(.12,.14,.16,1);
uniform vec4 accent_color:source_color=vec4(.33,.42,.24,1);
uniform float accent_amount=0.6;
uniform bool polished=false;
uniform bool masonry=false;
uniform sampler2D detail_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 point;
varying vec3 face;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;face=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hash21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float vnoise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return vnoise(p)*.55+vnoise(p*2.07+3.1)*.3+vnoise(p*4.3+7.7)*.15;}
void fragment(){
 vec2 uv=abs(face.y)>.65?point.xz:abs(face.x)>.65?point.zy:point.xy;
 float grain=dot(texture(detail_tex,uv*.34).rgb,vec3(.3333));
 vec3 stone=stone_color.rgb*(.82+grain*.7);
 float aa=max(fwidth(uv.x),fwidth(uv.y));
 if(masonry){
  vec2 tile=vec2(uv.x+floor(uv.y/.7)*.56,uv.y)*vec2(.9,1.42857);
  vec2 edge=min(fract(tile),1.-fract(tile));
  float taa=max(fwidth(tile.x),fwidth(tile.y))*.65;
  float seam=1.-smoothstep(.012-taa,.027+taa,min(edge.x,edge.y));
  // Every block its own shade, and a few mossy or sooty ones.
  float block=hash21(floor(tile)+vec2(3.7,1.3));
  stone*=.86+block*.26;
  float stain=step(.86,hash21(floor(tile)*1.7+11.3))*accent_amount;
  stone=mix(stone,accent_color.rgb*(.8+grain*.4),stain*.45*smoothstep(.2,.9,vnoise(uv*2.3)));
  stone=mix(stone,grout_color.rgb,seam*.8);
  // Damp, sooty patches drifting across the walls.
  if(abs(face.y)<.5) stone*=.82+.18*smoothstep(.25,.7,fbm(uv*.6+vec2(2.,5.)));
 }else{
  // Rock strata: wavy horizontal layers of lighter and darker stone.
  float wave=fbm(vec2(uv.x*.35,point.y*.12)+point.z*.05);
  float strata=sin(point.y*2.6+wave*5.5);
  stone*=.88+.16*smoothstep(-.4,.9,strata);
  // Broad mottling and dark crevices / cracks.
  float mottle=fbm(uv*.45);
  stone*=.8+mottle*.4;
  // Thin, broken cracks on walls and ceilings only (never outlining blobs on the floor).
  float crack=abs(fbm(uv*1.3+vec2(9.1,2.3))-.5);
  float crack_mask=smoothstep(.55,.75,vnoise(uv*.5+vec2(1.3,7.7)))*(1.-smoothstep(.5,.8,face.y));
  stone*=mix(1.,mix(.7,1.,smoothstep(.0,.022+aa*.6,crack)),crack_mask);
  // Ceilings are darker; overhangs fall into shadow.
  stone*=mix(1.,.62,smoothstep(.2,.9,-face.y));
  // Moss / dust / ash collects on upward faces and the foot of walls.
  float up=smoothstep(.35,.95,face.y);
  float patch=smoothstep(.42,.7,fbm(point.xz*.35+vec2(4.2,1.7)));
  stone=mix(stone,accent_color.rgb*(.75+grain*.5),clamp(up*patch*accent_amount,0.,1.)*.75);
 }
 ALBEDO=stone;ROUGHNESS=polished?.43:.92;SPECULAR=polished?.42:.14;
}
