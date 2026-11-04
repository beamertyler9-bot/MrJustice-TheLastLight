shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_atlas:source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D normal_atlas:source_color,filter_linear_mipmap,repeat_disable;
uniform vec2 viewer=vec2(0.0);
uniform int terrain_chunk_count=0;
uniform vec2 terrain_origin=vec2(0.0);
uniform vec2 terrain_extent=vec2(1.0);
uniform sampler2D terrain_ownership:filter_nearest,repeat_disable;
uniform float glow=0.0;
uniform bool unlit=false;
varying vec3 world_point;
varying vec2 tree_root;
varying vec2 view_uv;
varying vec3 card_right;
varying vec3 card_up;
varying vec3 card_forward;
void vertex(){
	tree_root=MODEL_MATRIX[3].xz;
	vec3 center=(MODEL_MATRIX*vec4(0.0,0.5,0.0,1.0)).xyz;
	vec3 facing=normalize(vec3(INV_VIEW_MATRIX[3].x-center.x,0.0,INV_VIEW_MATRIX[3].z-center.z));
	vec3 right=vec3(facing.z,0.0,-facing.x);
	float size=length(MODEL_MATRIX[1].xyz);
	world_point=center+right*VERTEX.x*size+vec3(0.0,(VERTEX.y-0.5)*size,0.0);
	POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world_point,1.0);
	float relative=atan(facing.x,facing.z)-atan(MODEL_MATRIX[2].x,MODEL_MATRIX[2].z);
	float frame=mod(floor(relative/1.570796327+0.5),4.0);
	view_uv=vec2((UV.x+frame)*0.25,UV.y);
	card_right=(VIEW_MATRIX*vec4(right,0.0)).xyz;
	card_up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	card_forward=(VIEW_MATRIX*vec4(facing,0.0)).xyz;
}
void fragment(){
	vec2 cell=floor(tree_root/48.0)-terrain_origin;
    if(terrain_chunk_count>0 && cell.x>=0.0 && cell.y>=0.0 && cell.x<terrain_extent.x && cell.y<terrain_extent.y && texture(terrain_ownership,(cell+vec2(0.5))/terrain_extent).r>0.5){discard;}
	vec4 base=texture(albedo_atlas,view_uv);
	if(base.a<0.5){discard;}
	vec3 n=texture(normal_atlas,view_uv).rgb*2.0-1.0;
	NORMAL=normalize(card_right*n.x+card_up*n.y+card_forward*n.z);
	ALBEDO=unlit?vec3(0.0):base.rgb;ROUGHNESS=0.9;SPECULAR=0.05;EMISSION=base.rgb*(glow+(unlit?1.0:0.0));
}
void light(){
	float facing=max(dot(NORMAL,LIGHT),0.0);
	float bands=0.18+smoothstep(0.13,0.32,facing)*0.36+smoothstep(0.57,0.78,facing)*0.46;
	DIFFUSE_LIGHT+=mix(vec3(0.44,0.50,0.57),vec3(1.0),bands)*bands*LIGHT_COLOR*ATTENUATION/PI;
}
