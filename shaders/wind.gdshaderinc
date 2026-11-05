// Wind for trees and plants: the whole plant leans and rocks with slow gusts (each one a
// little out of step with its neighbours), and the upper leaves flutter. Assets are
// normalised to unit height, so object-space VERTEX.y runs 0 (root) .. 1 (top); the root
// stays planted. Small plants move relatively more than tall trees.
uniform float wind_amount = 1.0;
vec3 wind_sway(vec3 v, mat4 m) {
	float h = clamp(v.y, 0.0, 1.2);
	float bend = h * h;
	vec3 origin = m[3].xyz;
	float phase = dot(origin.xz, vec2(0.071, 0.053));
	float gust = 0.55 + 0.45 * sin(TIME * 0.33 + phase * 0.31);
	float sway = (sin(TIME * 1.2 + phase) * 0.62 + sin(TIME * 2.05 + phase * 1.9) * 0.24 + 0.32) * gust;
	float flutter = sin(TIME * 7.3 + dot(v, vec3(13.1, 7.7, 11.3))) * h;
	float s0 = length(m[0].xyz); float s1 = length(m[1].xyz); float s2 = length(m[2].xyz);
	float amp = mix(0.085, 0.022, clamp(s1 / 8.0, 0.0, 1.0)) * wind_amount;
	mat3 r = mat3(m[0].xyz / s0, m[1].xyz / s1, m[2].xyz / s2);
	vec3 along = transpose(r) * normalize(vec3(0.86, 0.0, 0.5));
	vec3 across = transpose(r) * normalize(vec3(-0.5, 0.0, 0.86));
	return v + (along * sway + across * flutter * 0.12) * bend * amp + along * flutter * 0.05 * amp * h;
}
