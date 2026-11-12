shader_type spatial;
// Soft puffs that always face the camera: spray at the foot of a waterfall, or (with
// rise > 0) bubbles of fizz climbing out of the cola lake.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 mist_color : source_color = vec4(0.97, 0.9, 0.78, 1.0);
uniform float strength = 0.45;
uniform float rise = 0.0;
varying float phase;
varying float life;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.21;
	life = fract(TIME * 0.35 + fract(phase * 0.13));
	float grow = 1.0 + 0.2 * sin(TIME * 1.1 + phase);
	if (rise > 0.0) grow = mix(0.4, 1.1, life);
	vec3 lift = vec3(0.0, rise * life, 0.0);
	float sx = length(MODEL_MATRIX[0].xyz) * grow;
	float sy = length(MODEL_MATRIX[1].xyz) * grow;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], vec4(MODEL_MATRIX[3].xyz + lift, 1.0));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float puff = noise(UV * 4.0 + vec2(TIME * 0.2, -TIME * 0.35) + phase);
	float body = (1.0 - smoothstep(0.2, 1.0, d)) * (0.65 + 0.35 * puff);
	float fade = rise > 0.0 ? sin(life * 3.14159) : (0.75 + 0.25 * sin(TIME * 0.8 + phase));
	if (rise > 0.0) body *= smoothstep(1.0, 0.75, d) * (0.55 + 0.45 * smoothstep(0.55, 0.8, d));
	ALBEDO = mist_color.rgb;
	ALPHA = clamp(body * strength * fade, 0.0, 1.0);
}
