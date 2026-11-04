shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 leaf_color : source_color = vec4(0.28, 0.43, 0.31, 1.0);
uniform float wind_strength = 0.08;
uniform bool rooted = true;
uniform float world_time = 0.0;
varying vec3 world_position;
varying float leaf_height;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = rooted ? clamp(VERTEX.y, 0.0, 1.5) : 0.7;
	float breeze = sin(p.x * 0.17 + p.z * 0.12 + world_time * 1.05) + sin(p.z * 0.31 - world_time * 0.72) * 0.35;
	VERTEX.x += breeze * weight * wind_strength;
	VERTEX.z += breeze * weight * wind_strength * 0.36;
	world_position = p;
	leaf_height = VERTEX.y;
}
void fragment() {
	float variation = sin(world_position.x * 0.19 + world_position.z * 0.17) * 0.025;
	float leaflets = sin(world_position.x * 19.0 + sin(world_position.z * 17.0)) * sin(world_position.y * 23.0 + world_position.z * 11.0);
	variation += leaflets * 0.055;
	float tip = smoothstep(rooted ? 0.18 : -0.10, rooted ? 0.8 : 0.58, leaf_height);
	vec3 base = leaf_color.rgb * (0.96 + variation);
	ALBEDO = base * mix(vec3(0.86, 0.94, 0.97), vec3(1.09, 1.065, 0.94), tip);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	BACKLIGHT = leaf_color.rgb * 0.12;
}
