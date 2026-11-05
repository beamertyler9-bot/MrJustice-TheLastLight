// Wind for trees and plants: the whole plant leans and rocks with slow gusts (each one out
// of step with its neighbours) and the upper leaves flutter. Assets are normalised to unit
// height, so object-space VERTEX.y runs 0 (root) .. 1 (top) and the root stays planted.
// Kept cheap (a handful of sines per vertex, no matrix work): it runs on every plant.
uniform float wind_amount = 1.0;
vec3 wind_sway(vec3 v, mat4 m) {
	float h = clamp(v.y, 0.0, 1.2);
	float bend = h * h;
	float phase = m[3].x * 0.071 + m[3].z * 0.053;
	float gust = 0.55 + 0.45 * sin(TIME * 0.33 + phase * 0.31);
	float sway = (sin(TIME * 1.2 + phase) * 0.62 + sin(TIME * 2.05 + phase * 1.9) * 0.24 + 0.32) * gust;
	float flutter = sin(TIME * 7.3 + v.x * 13.1 + v.y * 7.7 + v.z * 11.3) * h;
	// Small plants move relatively more than tall trees.
	float amp = mix(0.085, 0.022, clamp(length(m[1].xyz) * 0.125, 0.0, 1.0)) * wind_amount;
	v.x += (sway * bend + flutter * 0.05 * h) * amp;
	v.z += flutter * 0.12 * bend * amp;
	return v;
}
