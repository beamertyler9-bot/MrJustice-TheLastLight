shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/regional_ground.gdshaderinc"
#include "res://shaders/volcanic_surface.gdshaderinc"
uniform vec2 viewer=vec2(0.0);
uniform int terrain_chunk_count=0;
uniform vec2 terrain_origin=vec2(0.0);
uniform vec2 terrain_extent=vec2(1.0);
uniform sampler2D terrain_ownership:filter_nearest,repeat_disable;
uniform int water_count=0;
uniform vec4 waterways[48];
uniform int lake_count=0;
uniform vec4 lake_bounds[16];
varying vec3 world_point;
varying float land_slope;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;land_slope=1.0-smoothstep(0.45,0.88,normalize(MODEL_NORMAL_MATRIX*NORMAL).y);}
void fragment(){
	vec2 cell=floor(world_point.xz/48.0)-terrain_origin;
    if(terrain_chunk_count>0 && cell.x>=0.0 && cell.y>=0.0 && cell.x<terrain_extent.x && cell.y<terrain_extent.y && texture(terrain_ownership,(cell+vec2(0.5))/terrain_extent).r>0.5){discard;}
	for(int i=0;i<48;i++){
		if(i>=water_count){break;}
		vec2 a=waterways[i].xy;
		vec2 b=waterways[i].zw;
		vec2 edge=b-a;
		float t=clamp(dot(world_point.xz-a,edge)/max(dot(edge,edge),0.01),0.0,1.0);
		if(distance(world_point.xz,a+edge*t)<52.0){discard;}
	}
	for(int i=0;i<16;i++){
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
		float strata=0.94+0.055*sin(world_point.y*0.16+sin(world_point.x*0.013)*1.8);
		ALBEDO=mix(ALBEDO,pow(vec3(0.49,0.45,0.41),vec3(2.2))*strata,land_slope*0.72);
	}
	ROUGHNESS=1.0;
	if(regional_surfaces && abs(ground_region(world_point.xz)-4.0)<0.25){
		vec4 ash=volcanic_surface(world_point.xz,distance(CAMERA_POSITION_WORLD,world_point));ALBEDO=ash.rgb;EMISSION=vec3(0.45,0.10,0.01)*ash.a;
	}
}
