// Dark weathered basalt, with restrained local heat that fades before it shimmers.
uniform sampler2D magma_pattern : filter_linear_mipmap, repeat_enable;
vec4 volcanic_surface(vec2 p, float view_distance) {
 vec2 warp=vec2(sin(p.y*0.0047),sin(p.x*0.0039))*0.06;
 vec3 plate=texture(magma_pattern,p/36.0+warp).rgb;
 float mottling=sin(p.x*0.011+sin(p.y*0.006))*sin(p.y*0.009);
 float hot_patch=smoothstep(0.48,0.86,mottling);
 hot_patch*=1.0-smoothstep(240.0,1100.0,distance(p,vec2(6348.0,-1356.0)));
 float detail_fade=1.0-smoothstep(32.0,115.0,view_distance);
 float molten=pow(smoothstep(0.62,0.98,plate.r),2.0)*hot_patch*detail_fade;
 vec3 basalt=mix(vec3(0.075,0.078,0.083),vec3(0.19,0.17,0.145),plate.g)*(0.88+plate.b*0.22);
 basalt*=0.94+sin(p.x*0.021+sin(p.y*0.018))*0.055;
 return vec4(mix(basalt,vec3(0.65,0.13,0.012),molten*0.72),molten*0.48);
}
