shader_type spatial;
// pack_toon.gdshader with wind (trees and plants).
#include "res://shaders/wind.gdshaderinc"
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool textured = false;
uniform vec4 shadow_tint : source_color = vec4(0.44, 0.50, 0.57, 1.0);
uniform float rim_blend = 0.055;
void vertex() {
	VERTEX = wind_sway(VERTEX, MODEL_MATRIX);
}
void fragment() {
	vec3 base = textured ? texture(albedo_texture, UV).rgb : vec3(1.0);
	ALBEDO = base * tint.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}
void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float bands = 0.18 + smoothstep(0.13, 0.32, facing) * 0.36 + smoothstep(0.57, 0.78, facing) * 0.46;
	vec3 diffuse = mix(shadow_tint.rgb, vec3(1.0), bands) * bands;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += (diffuse + rim * rim_blend) * LIGHT_COLOR * ATTENUATION / PI;
}
