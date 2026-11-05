shader_type spatial;
// Rivers, streams, lakes and the cola: a lit, see-through liquid surface.
//  - moving ripples (carried downstream on rivers, drifting slowly on lakes) bend the light,
//    so the sun glints off the surface and the sky reflects at grazing angles;
//  - clear and pale in the shallows by the bank, deep and dark in the middle;
//  - a soft foam line where it meets the bank, white water down steep cascades;
//  - the cola is dark and glossy, amber where it is shallow, with rising fizz.
// Lava stays opaque and glowing.
// Lighting is worked out here from the sun (unshaded), so the water costs one pass however
// many lamps are near: transparent lit surfaces are redrawn once per light on phones.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;
uniform vec3 sun_dir = vec3(-0.45, 0.75, -0.45);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
uniform float light_level = 1.0;
uniform vec4 liquid_color : source_color = vec4(0.2, 0.5, 0.6, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.94, 0.85, 1.0);
uniform vec4 sky_color : source_color = vec4(0.62, 0.78, 0.9, 1.0);
uniform float world_time = 0.0;
uniform bool lava = false;
uniform bool cola = false;
uniform bool still_lake = false;
uniform float foam_start = 0.78;
uniform float wave_strength = 0.08;
varying vec2 flow_uv;
varying vec3 world;
varying float bank_factor;
varying float body_shade;
varying float fall_factor;

void vertex() {
	flow_uv = UV; bank_factor = COLOR.a; body_shade = COLOR.r;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	fall_factor = 1.0 - smoothstep(0.35, 0.75, abs(world_normal.y));
}

// A little wave field: returns its slope (d/dx, d/dz).
vec2 waves(vec2 p, float t) {
	vec2 slope = vec2(0.0);
	vec2 d1 = vec2(0.83, 0.56); float a1 = dot(p, d1) * 1.7 + t * 1.3;
	vec2 d2 = vec2(-0.45, 0.89); float a2 = dot(p, d2) * 2.9 - t * 1.9;
	vec2 d3 = vec2(0.97, -0.24); float a3 = dot(p, d3) * 5.3 + t * 2.6;
	vec2 d4 = vec2(-0.71, -0.70); float a4 = dot(p, d4) * 8.1 - t * 3.1;
	slope += d1 * cos(a1) * 1.7 * 0.05;
	slope += d2 * cos(a2) * 2.9 * 0.03;
	slope += d3 * cos(a3) * 5.3 * 0.012;
	slope += d4 * cos(a4) * 8.1 * 0.006;
	return slope;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	if (lava) {
		float churn = sin(flow_uv.y * 0.55 - world_time * 0.9 + sin(flow_uv.x * 19.0) * 0.4);
		float crust = smoothstep(0.2, 0.9, sin(world.x * 0.9 + world_time * 0.2) * sin(world.z * 0.8 - world_time * 0.15));
		vec3 glow = mix(liquid_color.rgb * 1.1, foam_color.rgb * 1.3, smoothstep(0.7, 1.0, churn)) * (1.0 - crust * 0.7);
		ALBEDO = mix(liquid_color.rgb, vec3(0.16, 0.07, 0.05), crust * 0.6) * body_shade * 0.4 + glow;
		ALPHA = 1.0;
	} else {
		// Ripples: rivers carry them downstream (UV.y is distance along the river).
		vec2 p = world.xz;
		vec2 flow = still_lake ? vec2(world_time * 0.12, world_time * 0.07) : vec2(0.0);
		float t = world_time * (still_lake ? 0.55 : 1.0);
		vec2 slope = waves(p * 0.6 + flow, t) + waves(p * 1.9 - flow * 1.7, t * 1.3) * 0.45;
		if (!still_lake) {
			// Running water: streaks that slide along the river and a choppier surface.
			float along = flow_uv.y * 0.9 - world_time * 2.4;
			slope += vec2(0.0, cos(along + sin(flow_uv.x * 13.0 + flow_uv.y * 0.2) * 1.5) * 0.06);
		}
		slope *= mix(1.0, 0.45, fall_factor);
		vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
		vec3 face_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		n_world = normalize(mix(n_world, face_world, fall_factor));
		vec3 view_world = normalize(CAMERA_POSITION_WORLD - world);
		vec3 sun = normalize(sun_dir);
		// Depth: the shallows by the bank are clear and pale, the middle deep and dark.
		// (Lakes shade from the middle out to the shore, so only the last stretch is shallow.)
		float shallow = still_lake ? smoothstep(0.8, 1.0, bank_factor) : smoothstep(0.35, 1.0, bank_factor);
		vec3 deep = liquid_color.rgb * (cola ? 0.38 : 0.45);
		vec3 shoal = cola ? liquid_color.rgb * 1.35 + vec3(0.06, 0.02, 0.0) : mix(liquid_color.rgb, vec3(0.55, 0.78, 0.66), 0.45);
		vec3 body = mix(deep, shoal, shallow);
		// The sky reflected at grazing angles.
		float facing = clamp(abs(dot(n_world, view_world)), 0.0, 1.0);
		float fresnel = pow(1.0 - facing, 4.0);
		body = mix(body, sky_color.rgb * (cola ? 0.5 : 0.9), fresnel * (cola ? 0.3 : 0.6));
		// Foam: a soft, broken line along the bank, flecks on the ripples, white water on cascades.
		float edge = smoothstep(foam_start, 1.0, bank_factor);
		float broken = smoothstep(-0.3, 0.8, sin(p.x * 3.1 + p.y * 2.3 + world_time * 0.9) * sin(p.x * 1.7 - p.y * 3.3 - world_time * 0.6));
		float crest = smoothstep(0.075, 0.11, length(slope)) * wave_strength * 2.0;
		float cascade = still_lake ? 0.0 : fall_factor * body_shade;
		float streak = sin(flow_uv.y * 2.8 - world_time * 5.2 + flow_uv.x * 21.0);
		float foam = edge * (0.25 + broken * 0.4) + crest + cascade * (0.45 + smoothstep(-0.4, 0.8, streak) * 0.45);
		if (cola) {
			// Fizz: tiny bubbles winking in and out.
			vec2 cell = floor(p * 3.0);
			float bubble = step(0.93, hash(cell + floor(world_time * 2.0 + hash(cell) * 7.0)));
			vec2 local = fract(p * 3.0) - 0.5;
			foam += bubble * smoothstep(0.22, 0.08, length(local)) * 0.8;
		}
		foam = clamp(foam, 0.0, 1.0);
		// Sunlight: soft shading, then a sharp glint where the ripples catch the sun.
		float sun_up = smoothstep(-0.05, 0.2, sun.y);
		float diffuse = 0.62 + 0.38 * max(dot(n_world, sun), 0.0) * sun_up;
		vec3 lit = mix(body, foam_color.rgb, foam) * mix(1.0, body_shade, 0.5) * diffuse * light_level * mix(vec3(1.0), sun_color.rgb, 0.35);
		float glint = pow(max(dot(reflect(-sun, n_world), view_world), 0.0), cola ? 60.0 : 90.0) * (1.0 - foam) * sun_up;
		ALBEDO = lit + sun_color.rgb * glint * (cola ? 0.9 : 1.4) * light_level;
		// See-through in the shallows, more solid in the deep and wherever it foams.
		float clear = cola ? mix(0.9, 0.62, shallow) : mix(0.84, 0.42, shallow);
		ALPHA = clamp(max(clear + fresnel * 0.25, foam), 0.0, 1.0);
		ALPHA = mix(ALPHA, 0.95, fall_factor);
	}
}
