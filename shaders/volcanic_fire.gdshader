shader_type spatial;
render_mode unshaded, cull_disabled;
varying float phase;
void vertex() {
 phase = MODEL_MATRIX[3].x * 0.17 + MODEL_MATRIX[3].z * 0.23;
 float tip = UV.y * UV.y;
 VERTEX.x += sin(TIME * 6.5 + phase - UV.y * 8.0) * tip * 0.15;
 VERTEX.z += cos(TIME * 4.7 + phase - UV.y * 6.0) * tip * 0.07;
 VERTEX.y += (sin(TIME * 8.0 + phase) * 0.06 + 0.01) * UV.y;
}
void fragment() {
 float heat = pow(1.0 - UV.y, 0.75);
 vec3 fire = mix(vec3(0.95, 0.13, 0.012), vec3(1.0, 0.72, 0.19), heat);
 ALBEDO = fire; EMISSION = fire * 0.55;
}
