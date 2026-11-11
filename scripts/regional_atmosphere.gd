extends RefCounted

const TOP = ["#24688b", "#487c9e", "#5f87a1", "#3a7e98", "#7595b8", "#b17a50", "#547c74", "#9a7466", "#536a82", "#2e7298", "#856b9c", "#438cb1", "#b17c51", "#3e3e4d", "#353249", "#647cbd"]
const HORIZON = ["#bedfda", "#c7ddeb", "#d4dfc6", "#b6ded5", "#e4eef5", "#f0c28c", "#b7d5b8", "#e2c19b", "#b8c8cb", "#c2dfd3", "#f3cfb9", "#d8e7c6", "#f3c791", "#b47b63", "#80728d", "#c1e3e9"]
const NIGHT = ["#10213b", "#202744", "#252943", "#152a3a", "#1c2a48", "#34283b", "#182d2d", "#30253a", "#14213a", "#112c3c", "#302343", "#172a49", "#30233a", "#251c2c", "#171526", "#202750"]
const CLOUD = ["#fff2d9", "#e2e7fa", "#f5efd6", "#e7f6e7", "#f3f8ff", "#ffe0bd", "#d7e7d7", "#f5d6b0", "#d7e4ee", "#edf3dc", "#ffe5eb", "#f5f0d9", "#ead2b0", "#8f8690", "#9f94b3", "#d8e3ff"]
const SCALE = [1.0, 1.1, 0.8, 0.9, 1.1, 0.7, 0.85, 0.95, 1.15, 0.9, 0.78, 1.28, 0.68, 1.6, 0.65, 0.82]
const DRIFT = [1.0, 0.8, 0.7, 0.9, 1.2, 0.65, 0.7, 0.7, 1.1, 0.8, 0.6, 1.4, 0.65, 0.45, 0.35, 0.55]
var palettes: Array = []
var current: Array[Color] = []
var scale_value = 1.0
var drift = 1.0
var aurora = 0.0
func _init():
	for i in TOP.size(): palettes.append([Color(TOP[i]), Color(HORIZON[i]), Color(NIGHT[i]), Color(CLOUD[i])])
func apply(material: ShaderMaterial, biome: int, dt: float):
	var index = clampi(biome, 0, TOP.size() - 1); var first = current.is_empty()
	if first: current.assign(palettes[index])
	var weight = 1.0 if first else 1.0 - exp(-maxf(dt, 0) * 0.55)
	for i in current.size(): current[i] = current[i].lerp(palettes[index][i], weight)
	scale_value = lerpf(scale_value, SCALE[index], weight); drift = lerpf(drift, DRIFT[index], weight); aurora = lerpf(aurora, 0.42 if index == 15 else 0.0, weight)
	material.set_shader_parameter("day_top", current[0]); material.set_shader_parameter("day_horizon", current[1])
	material.set_shader_parameter("night_top", current[2]); material.set_shader_parameter("night_horizon", current[2].lerp(current[1], 0.18))
	material.set_shader_parameter("cloud_tint", current[3]); material.set_shader_parameter("cloud_scale", scale_value)
	material.set_shader_parameter("cloud_drift", drift); material.set_shader_parameter("aurora_amount", aurora)
