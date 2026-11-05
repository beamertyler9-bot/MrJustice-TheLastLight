shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://shaders/regional_plant_color.gdshaderinc"
#include "res://shaders/wind.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool textured = true;
uniform bool candy_surface = true;
uniform bool candy_bark = false;
uniform float alpha_cutoff = 0.0;
void vertex() {
	VERTEX = wind_sway(VERTEX, MODEL_MATRIX);
}
void fragment() {
	vec4 source = textured ? texture(albedo_texture, UV) : vec4(1.0);
	if (source.a < alpha_cutoff) { discard; }
	ALBEDO = regional_plant_color(source.rgb, tint.rgb, UV, candy_bark);
	ROUGHNESS = candy_bark ? 0.79 : 0.91;
	SPECULAR = candy_bark ? 0.20 : 0.08;
	BACKLIGHT = tint.rgb * (candy_bark ? 0.0 : 0.11);
}
