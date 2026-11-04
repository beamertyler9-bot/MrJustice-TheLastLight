#include "res://shaders/regional_ground.gdshaderinc"
uniform sampler2D ground_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int clearing_count=0;
uniform vec4 clearings[8];
varying vec3 world_position;
varying vec3 terrain_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 p = world_position.xz;
	float patch = sin(p.x * 0.15 + sin(p.y * 0.11) * 1.2) * sin(p.y * 0.12 - cos(p.x * 0.09) * 0.8);
	float slope = 1.0 - smoothstep(0.5, 0.85, terrain_normal.y);
	vec3 weights = pow(abs(terrain_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 rock=vec3(0.5);
	if(max(slope,1.0-COLOR.a)>0.0001){
		rock=texture(rock_detail, world_position.zy * 0.38).rgb * weights.x;
		rock+=texture(rock_detail, world_position.xz * 0.38).rgb * weights.y;
		rock+=texture(rock_detail, world_position.xy * 0.38).rgb * weights.z;
	}
	float grit=0.5;
	if(!regional_surfaces){grit=dot(texture(ground_detail,p*0.42).rgb,vec3(0.3,0.55,0.15));}
	vec3 terrain_tint = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	vec3 meadow = terrain_tint * (0.84 + smoothstep(-0.6, 0.7, patch) * 0.2);
	meadow *= 0.77 + grit * 1.7;
	vec4 planted_relief=vec4(0.5,0.5,1.0,0.94);
	if(regional_surfaces){
		float region=ground_region(p);
		vec3 plants=ground_color_detail(p,region).rgb;
		grit=dot(plants,vec3(0.3,0.55,0.15))*0.65;
		planted_relief=ground_relief_detail(p,region);
		float humus=smoothstep(0.35,0.90,ground_macro(p))*0.20;
		meadow=terrain_tint*mix(vec3(1.0),plants*1.75,0.76)*(0.92+patch*0.065);
		meadow=mix(meadow,terrain_tint*vec3(0.66,0.62,0.58),humus);
	}
	vec3 cliff = mix(terrain_tint * vec3(1.03, 0.92, 0.79), vec3(0.34, 0.35, 0.31), 0.35) * rock * 1.75;
	float authored_rock=1.0-COLOR.a;
	ALBEDO = mix(meadow, cliff, max(slope * 0.86,authored_rock));
	float stone_luma=dot(rock,vec3(0.333333));
	float strata=0.87+0.13*sin(world_position.y*0.9+sin(p.x*0.18)*0.7);
	vec3 painted_rock=vec3(0.14,0.17,0.16)*(0.8+stone_luma*0.8)*strata;
	ALBEDO=mix(ALBEDO,painted_rock,authored_rock);
	float soil=0.0;
	float edge_noise=sin(p.x*3.7+sin(p.y*2.1))*sin(p.y*4.2)*0.14;
	for(int i=0;i<8;i++){
		if(i>=clearing_count){break;}
		soil=max(soil,(1.0-smoothstep(4.4+edge_noise,6.2+edge_noise,distance(p,clearings[i].xy)))*clearings[i].z);
	}
	vec3 pale_dirt=pow(vec3(0.76,0.65,0.47),vec3(2.2))*(0.75+grit*1.4);
	ALBEDO=mix(ALBEDO,pale_dirt,soil);
	float small_detail=(1.0-max(slope,authored_rock))*(1.0-soil*0.7);
	if(regional_surfaces){
		vec2 relief=(planted_relief.xy*2.0-1.0)*small_detail*0.38;
		vec3 planted_normal=normalize(terrain_normal+vec3(relief.x,0.0,relief.y));
		NORMAL=normalize((VIEW_MATRIX*vec4(planted_normal,0.0)).xyz);
	}
	ROUGHNESS = mix(0.94,planted_relief.a,small_detail*0.7);
	SPECULAR = 0.22;
#ifdef BUILDING_PATH
	// The shoulder reveals the ground well before the mesh boundary. Two
	// scales of world-space wear dissolve its edge without a straight border.
	float wear=sin(p.x*3.1+sin(p.y*2.3))*sin(p.y*3.7+p.x*0.6)*0.10;
	wear+=sin(p.x*10.7-p.y*7.3)*sin(p.y*9.1)*0.035;
	wear+=(grit-0.5)*0.08;
	ALPHA=(1.0-smoothstep(0.36+wear,0.96+wear*0.25,abs(UV2.x)))*smoothstep(0.0,0.30,UV2.y+wear*0.18);
#endif
}
