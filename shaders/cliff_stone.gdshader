shader_type spatial;
render_mode diffuse_burley;
// Cliffs and big boulders (cave mouths, outcrops): warm grey stone with broad mottling,
// ledge strata, dark vertical weathering streaks, and moss settling on up-facing ledges.
uniform sampler2D rock_detail:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 moss_color:source_color=vec4(.33,.42,.22,1);
varying vec3 world_position;
varying vec3 world_normal;
float h21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float vn(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(h21(i),h21(i+vec2(1,0)),f.x),mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 weights=pow(abs(world_normal),vec3(4.0));weights/=max(dot(weights,vec3(1.0)),0.001);
 vec3 rock=texture(rock_detail,world_position.zy*.38).rgb*weights.x+texture(rock_detail,world_position.xz*.38).rgb*weights.y+texture(rock_detail,world_position.xy*.38).rgb*weights.z;
 float luma=dot(rock,vec3(.333333));
 vec2 side=abs(world_normal.x)>abs(world_normal.z)?world_position.zy:world_position.xy;
 float strata=.84+.16*sin(world_position.y*.9+sin(world_position.x*.18+world_position.z*.13)*.9);
 float mottle=vn(side*.25)*.6+vn(side*.9+3.)*.4;
 vec3 stone=mix(vec3(.2,.19,.17),vec3(.34,.32,.28),mottle)*(.75+luma*.7)*strata;
 // Rain streaks running down the faces.
 float streak=vn(vec2(side.x*2.3,world_position.y*.12));
 stone*=mix(1.,.72,smoothstep(.62,.85,streak)*(1.-abs(world_normal.y)));
 // Moss on the ledges and tops.
 float ledge=smoothstep(.45,.85,world_normal.y);
 float patchy=smoothstep(.35,.65,vn(world_position.xz*.4+1.7));
 stone=mix(stone,moss_color.rgb*(.7+luma*.6),ledge*patchy*.85);
 ALBEDO=stone;ROUGHNESS=.94;SPECULAR=.22;
}
