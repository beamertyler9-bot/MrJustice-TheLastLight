// Used by the live candy plants and their offline horizon captures.
vec3 regional_plant_color(vec3 source, vec3 tint, vec2 uv, bool bark) {
	float relief = sqrt(max(dot(source, vec3(0.2126, 0.7152, 0.0722)), 0.0));
	vec3 color = tint * (0.72 + relief * 0.43);
	if (bark) {
		float ribbon = smoothstep(0.45, 0.86, sin(uv.y * 72.0 + uv.x * 22.0));
		color *= mix(vec3(1.0), vec3(0.78, 0.67, 0.87), ribbon * 0.58);
	}
	return color;
}
