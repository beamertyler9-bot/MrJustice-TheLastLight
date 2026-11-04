shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/regional_ground.gdshaderinc"
uniform vec2 viewer=vec2(0.0);
uniform int terrain_chunk_count=0;
uniform vec2 terrain_origin=vec2(0.0);
uniform vec2 terrain_extent=vec2(1.0);
uniform sampler2D terrain_ownership:filter_nearest,repeat_disable;
uniform int water_count=0;
uniform vec4 waterways[32];
uniform int lake_count=0;
uniform vec4 lake_bounds[8];
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 cell=floor(world_point.xz/48.0)-terrain_origin;
    if(terrain_chunk_count>0 && cell.x>=0.0 && cell.y>=0.0 && cell.x<terrain_extent.x && cell.y<terrain_extent.y && texture(terrain_ownership,(cell+vec2(0.5))/terrain_extent).r>0.5){discard;}
	for(int i=0;i<32;i++){
		if(i>=water_count){break;}
		vec2 a=waterways[i].xy;
		vec2 b=waterways[i].zw;
		vec2 edge=b-a;
		float t=clamp(dot(world_point.xz-a,edge)/max(dot(edge,edge),0.01),0.0,1.0);
		if(distance(world_point.xz,a+edge*t)<52.0){discard;}
	}
	for(int i=0;i<8;i++){
		if(i>=lake_count){break;}
		vec2 delta=world_point.xz-lake_bounds[i].xy;
		float radius=length(delta/lake_bounds[i].zw);
		float shore=length(delta)*(1.0-1.0/max(radius,0.00001));
		if(shore> -96.0 && shore<64.0){discard;}
	}
	ALBEDO=pow(COLOR.rgb,vec3(2.2));
	if(regional_surfaces){
		float detail_fade=1.0-smoothstep(100.0,240.0,distance(CAMERA_POSITION_WORLD,world_point));
		vec3 fine=vec3(1.0);
		if(detail_fade>0.01){fine=mix(vec3(1.0),ground_color_detail(world_point.xz,ground_region(world_point.xz)).rgb*1.75,0.76*detail_fade);}
		ALBEDO*=fine*(0.96+ground_macro(world_point.xz)*0.055);
	}
	ROUGHNESS=1.0;
}
