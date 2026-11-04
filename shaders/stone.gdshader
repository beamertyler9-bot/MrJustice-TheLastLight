shader_type spatial;
render_mode diffuse_burley;
uniform vec4 stone_color : source_color = vec4(0.52, 0.57, 0.48, 1.0);
uniform sampler2D stone_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 detail = texture(stone_detail, world_position.zy * 0.7).rgb * weights.x;
	detail += texture(stone_detail, world_position.xz * 0.7).rgb * weights.y;
	detail += texture(stone_detail, world_position.xy * 0.7).rgb * weights.z;
	float weather = sin(world_position.x * 2.2 + sin(world_position.z * 1.8)) * sin(world_position.y * 3.6 + world_position.z * 0.9);
	float moss = smoothstep(0.35, 0.9, world_normal.y) * smoothstep(-0.15, 0.7, weather) * 0.48;
	ALBEDO = mix(stone_color.rgb * detail * 1.55, vec3(0.075, 0.16, 0.10) * (0.7 + detail), moss);
	ROUGHNESS = 0.9;
	SPECULAR = 0.27;
}
