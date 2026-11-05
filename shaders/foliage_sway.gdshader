shader_type spatial;
// The plain lit leaf/plant material, with wind.
render_mode cull_disabled;
#include "res://shaders/wind.gdshaderinc"
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform bool use_vertex_color = false;
uniform float alpha_cutoff = 0.0;
uniform float roughness = 0.9;
void vertex() {
	VERTEX = wind_sway(VERTEX, MODEL_MATRIX);
}
void fragment() {
	vec4 c = albedo_color;
	if (textured) c *= texture(albedo_texture, UV);
	if (use_vertex_color) c *= COLOR;
	if (alpha_cutoff > 0.0 && c.a < alpha_cutoff) discard;
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
	BACKLIGHT = c.rgb * 0.12;
}
