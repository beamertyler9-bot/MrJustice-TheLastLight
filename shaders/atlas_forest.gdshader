shader_type spatial;
uniform vec4 tint : source_color = vec4(0.2,0.4,0.3,1.0);
uniform vec2 viewer=vec2(0.0);
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	if(distance(world_point.xz,viewer)<85.0){discard;}
	ALBEDO=tint.rgb;
	ROUGHNESS=1.0;
}
