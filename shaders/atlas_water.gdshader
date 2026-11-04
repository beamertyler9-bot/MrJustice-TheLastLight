shader_type spatial;
render_mode unshaded;
uniform vec4 liquid_color : source_color = vec4(0.2,0.5,0.6,1.0);
uniform vec4 foam_color : source_color = vec4(0.9,0.94,0.85,1.0);
uniform float world_time=0.0;
uniform bool lava=false;
uniform bool still_lake=false;
uniform float foam_start=0.78;
uniform float wave_strength=0.08;
varying vec2 flow_uv;
varying float bank_factor;
varying float body_shade;
varying float fall_factor;
void vertex(){
	flow_uv=UV;bank_factor=COLOR.a;body_shade=COLOR.r;
	vec3 world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
	fall_factor=1.0-smoothstep(0.35,0.75,abs(world_normal.y));
}
void fragment(){
	float ripple=sin(flow_uv.y*0.55-world_time*1.6+sin(flow_uv.x*19.0)*0.4);
	float edge=smoothstep(foam_start,1.0,bank_factor);
	float cascade=still_lake?0.0:fall_factor*body_shade;
	float streak=sin(flow_uv.y*2.8-world_time*4.2+flow_uv.x*21.0);
	float foam=edge*0.34+smoothstep(0.86,1.0,ripple)*wave_strength+cascade*smoothstep(-0.2,0.8,streak)*0.28;
	ALBEDO=mix(liquid_color.rgb,foam_color.rgb,foam)*body_shade;
	ROUGHNESS=lava?0.8:0.26;
	SPECULAR=0.35;
	if(lava){EMISSION=liquid_color.rgb*0.8;}
}
