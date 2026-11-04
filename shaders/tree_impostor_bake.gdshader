shader_type spatial;
render_mode unshaded,cull_disabled;
#include "res://shaders/regional_plant_color.gdshaderinc"
uniform sampler2D albedo_texture:source_color,filter_linear_mipmap;
uniform vec4 tint:source_color=vec4(1.0);
uniform bool textured=false;
uniform bool vertex_colors=false;
uniform bool normal_pass=false;
uniform float alpha_cutoff=0.0;
uniform bool candy_surface=false;
uniform bool candy_bark=false;
void fragment(){
	vec4 base=textured?texture(albedo_texture,UV):vec4(1.0);
	if(base.a*tint.a<alpha_cutoff){discard;}
	ALBEDO=normal_pass?normalize(NORMAL)*0.5+0.5:base.rgb*tint.rgb*(vertex_colors?COLOR.rgb:vec3(1.0));
	if(candy_surface && !normal_pass){ALBEDO=regional_plant_color(base.rgb,tint.rgb,UV,candy_bark);}
}
