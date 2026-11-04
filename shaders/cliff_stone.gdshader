shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D rock_detail:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 weights=pow(abs(world_normal),vec3(4.0));weights/=max(dot(weights,vec3(1.0)),0.001);
 vec3 rock=texture(rock_detail,world_position.zy*.38).rgb*weights.x+texture(rock_detail,world_position.xz*.38).rgb*weights.y+texture(rock_detail,world_position.xy*.38).rgb*weights.z;
 float luma=dot(rock,vec3(.333333));
 float strata=.87+.13*sin(world_position.y*.9+sin(world_position.x*.18)*.7);
 ALBEDO=vec3(.14,.17,.16)*(.8+luma*.8)*strata;ROUGHNESS=.94;SPECULAR=.22;
}
