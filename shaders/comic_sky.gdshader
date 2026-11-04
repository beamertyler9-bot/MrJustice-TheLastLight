shader_type sky;
uniform float world_time = 0.0;
uniform float daylight = 1.0;
uniform float cloud_cover = 0.35;
uniform vec3 sun_direction = vec3(-0.55, 0.65, -0.52);
uniform vec4 day_top : source_color = vec4(0.13, 0.32, 0.52, 1.0);
uniform vec4 day_horizon : source_color = vec4(0.54, 0.68, 0.76, 1.0);
// Cloud layering is adapted from the supplied SourceCode sky shader.
uniform sampler2D cloud_tex_01 : filter_linear, repeat_enable;
uniform sampler2D cloud_tex_02 : filter_linear, repeat_enable;
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0)), f.x), f.y);
}
float clouds(vec2 p) {
	vec2 uv=p*0.075;
	float a=texture(cloud_tex_01,uv).r;
	float b=texture(cloud_tex_02,uv*1.6+vec2(0.17,0.29)).r;
	vec2 depth=vec2(a-b,b-a)*0.045;
	return texture(cloud_tex_01,uv+depth).r*.68+texture(cloud_tex_02,uv*1.6-depth).r*.32;
}
void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = max(dir.y, 0.0);
	float dusk = (1.0 - smoothstep(0.0, 0.50, abs(sun_direction.y))) * daylight;
	vec3 top = mix(vec3(0.025, 0.045, 0.12), day_top.rgb, daylight);
	top = mix(top, vec3(0.30, 0.18, 0.38), dusk * 0.42);
	vec3 horizon = mix(vec3(0.10, 0.15, 0.26), day_horizon.rgb, daylight);
	horizon = mix(horizon, vec3(0.91, 0.46, 0.30), dusk * 0.80);
	vec3 color = mix(horizon, top, pow(height, 0.48));
	if (AT_CUBEMAP_PASS && dir.y < 0.0) {
		color = mix(vec3(0.045, 0.065, 0.04), horizon, exp(dir.y * 7.0));
	}
	if (!AT_CUBEMAP_PASS) {
		float sun_dot = max(dot(dir, normalize(sun_direction)), 0.0);
		color += vec3(0.40, 0.27, 0.10) * pow(sun_dot, 25.0) * daylight * 0.22;
		float sun_ink = smoothstep(0.9952, 0.9955, sun_dot) * daylight;
		float sun_disc = smoothstep(0.9962, 0.9965, sun_dot) * daylight;
		color = mix(color, vec3(1.0, 0.87, 0.53), sun_disc);
		vec3 moon_dir = normalize(vec3(-sun_direction.x, max(0.18, -sun_direction.y), -sun_direction.z));
		float moon = smoothstep(0.9983, 0.9986, dot(dir, moon_dir)) * (1.0 - daylight);
		color = mix(color, vec3(0.78, 0.90, 0.91), moon);
		vec2 stars_uv = SKY_COORDS * vec2(160.0, 80.0);
		float star_cell = hash2(floor(stars_uv));
		float star = (1.0 - smoothstep(0.015, 0.08, length(fract(stars_uv) - 0.5))) * step(0.985, star_cell);
		color += vec3(0.82, 0.86, 0.69) * star * (1.0 - daylight) * smoothstep(0.03, 0.25, height);
		vec2 plane = dir.xz / max(0.14, height + 0.13);
		float n = clouds(plane * vec2(2.6, 3.6) + vec2(world_time * 0.004, world_time * 0.001));
		float threshold = mix(0.69, 0.44, cloud_cover);
		float visibility = smoothstep(0.015, 0.09, height);
		float outline = smoothstep(threshold - 0.025, threshold - 0.012, n) * visibility;
		float fill = smoothstep(threshold - 0.025, threshold + 0.055, n) * visibility;
		float lit = smoothstep(threshold + 0.015, threshold + 0.16, n);
		vec3 cloud_shadow = mix(vec3(0.12, 0.19, 0.32), vec3(0.48, 0.65, 0.69), daylight);
		vec3 cloud_light = mix(vec3(0.25, 0.34, 0.46), vec3(0.96, 0.91, 0.74), daylight);
		cloud_light = mix(cloud_light, vec3(0.98, 0.64, 0.46), dusk * 0.70);
		vec3 cloud_ink = mix(vec3(0.055, 0.09, 0.17), vec3(0.25, 0.42, 0.51), daylight);
		color = mix(color, cloud_shadow, outline * 0.24);
		color = mix(color, mix(cloud_shadow, cloud_light, lit), fill);
	}
	COLOR = color;
}
