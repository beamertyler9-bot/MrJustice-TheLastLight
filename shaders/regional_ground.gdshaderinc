uniform sampler2DArray regional_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray regional_relief : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D regional_map : filter_nearest, repeat_disable;
uniform bool regional_surfaces = false;
uniform vec2 regional_map_origin = vec2(-1872.0, -2628.0);
uniform vec2 regional_map_extent = vec2(10260.0, 6264.0);
float ground_region(vec2 point) {
	vec2 at = (point - regional_map_origin) / regional_map_extent;
	return clamp(floor(texture(regional_map, at).r * 255.0 + 0.5) - 1.0, 0.0, 6.0);
}
vec3 ground_tile_uv(vec2 point, float region) {
	return vec3((vec2(16.0)+fract(point*0.17)*224.0)/256.0,region);
}
vec4 ground_color_detail(vec2 point,float region) {
	// Derivatives come from unwrapped world space. Derivatives of fract()
	// Layers keep the complete mip pyramid inside this region's exact tile.
	vec2 scale=vec2(224.0/256.0)*0.17;
	return textureGrad(regional_albedo,ground_tile_uv(point,region),dFdx(point)*scale,dFdy(point)*scale);
}
vec4 ground_relief_detail(vec2 point,float region) {
	vec2 scale=vec2(224.0/256.0)*0.17;
	return textureGrad(regional_relief,ground_tile_uv(point,region),dFdx(point)*scale,dFdy(point)*scale);
}
float ground_macro(vec2 point) {
	return sin(point.x * 0.043 + sin(point.y * 0.029) * 1.6) * sin(point.y * 0.037 - cos(point.x * 0.032));
}
