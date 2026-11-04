shader_type spatial;
render_mode cull_disabled;
uniform vec4 stone_color:source_color=vec4(.30,.33,.36,1);
uniform vec4 grout_color:source_color=vec4(.12,.14,.16,1);
uniform bool polished=false;
uniform bool masonry=false;
uniform sampler2D detail_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 point;
varying vec3 face;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;face=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 uv=abs(face.y)>.65?point.xz:abs(face.x)>.65?point.zy:point.xy;
 float grain=dot(texture(detail_tex,uv*.34).rgb,vec3(.3333));
 vec3 stone=stone_color.rgb*(.82+grain*.7);
 if(masonry){
  vec2 tile=vec2(uv.x+floor(uv.y/.7)*.56,uv.y)*vec2(.9,1.42857);
  vec2 edge=min(fract(tile),1.-fract(tile));
  float aa=max(fwidth(tile.x),fwidth(tile.y))*.65;
  float seam=1.-smoothstep(.012-aa,.027+aa,min(edge.x,edge.y));
  stone=mix(stone,grout_color.rgb,seam*.8);
 }
 ALBEDO=stone;ROUGHNESS=polished?.43:.92;SPECULAR=polished?.42:.14;
}
