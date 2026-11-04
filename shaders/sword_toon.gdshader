shader_type spatial;
uniform vec4 tint:source_color=vec4(1.0);
uniform sampler2D albedo_texture:source_color,filter_linear_mipmap;
uniform bool textured=false;
varying float blade_height;
void vertex(){blade_height=VERTEX.y;}
void fragment(){
    vec3 base=(textured?texture(albedo_texture,UV).rgb:vec3(1.0))*tint.rgb;
    ALBEDO=base;ROUGHNESS=0.7;SPECULAR=0.12;
    EMISSION=vec3(0.23,0.65,0.49)*smoothstep(0.25,0.55,blade_height)*0.16;
}
void light(){
    float f=max(dot(NORMAL,LIGHT),0.0);
    float bands=0.18+smoothstep(0.13,0.32,f)*0.36+smoothstep(0.57,0.78,f)*0.46;
    DIFFUSE_LIGHT+=mix(vec3(0.44,0.50,0.57),vec3(1.0),bands)*bands*LIGHT_COLOR*ATTENUATION/PI;
}
