extends Node3D
## A strike out of the sky. Storm magic comes down as a jagged, flickering lightning bolt
## with forks and a white-hot core; every other element comes down as a pillar of its own
## light (a Kamehameha column pointing at the ground). Self-managing; frees itself.

var presentation
var spell: Dictionary
var top := Vector3.ZERO
var ground := Vector3.ZERO
var life := 0.5
var age := 0.0
var _bolt: MeshInstance3D
var _material: ShaderMaterial
var _flicker := -1.0
var _storm := false
var _icicle: MeshInstance3D
var _spikes: Array = []
## Bigger strikes (Thunderclap) and lightning along beams use thicker, wider bolts.
var scale_factor := 1.0


func setup(owner_presentation, from: Vector3, to: Vector3, recipe: Dictionary, duration: float) -> void:
	presentation = owner_presentation; top = from; ground = to; spell = recipe; life = duration
	_storm = str(recipe.get("element", "")) == "storm"


func _ready() -> void:
	name = "SkyStrike"
	top_level = true
	global_transform = Transform3D.IDENTITY
	var body: Color = presentation._color(spell, "color", Color("8c9aff"))
	var core: Color = presentation._color(spell, "core_color", presentation._color(spell, "accent", Color("e9f5ff")))
	var gentle := bool(presentation._settings().get("low_flash", false))
	if _storm:
		_material = presentation._material(presentation.ENERGY, spell)
		_bolt = MeshInstance3D.new(); _bolt.mesh = ArrayMesh.new(); _bolt.material_override = _material
		_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _bolt.extra_cull_margin = 4.0
		add_child(_bolt)
		preload("res://scripts/kame_beam.gd").spawn(self, top, ground, body, core, 0.08 * scale_factor, life * 0.8, gentle, 1.2)
	elif str(spell.get("element", "")) == "frost":
		# A massive jagged spike of ice bursts up out of the ground, ringed by smaller ones.
		life = maxf(life, 1.7)
		var ice: ShaderMaterial = presentation._material(presentation.SURFACE, spell)
		var size := clampf(float(spell.get("radius", 1.5)), 1.0, 3.0)
		var rng := RandomNumberGenerator.new(); rng.seed = hash(ground)
		for i in range(9):
			var spike := MeshInstance3D.new(); spike.mesh = presentation._mesh("shard")
			spike.material_override = ice; spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(spike)
			var angle := float(i) * TAU / 8.0 + rng.randf_range(-0.3, 0.3)
			var main := i == 0
			_spikes.append({"node": spike, "at": Vector3.ZERO if main else Vector3(cos(angle), 0.0, sin(angle)) * size * rng.randf_range(0.45, 0.85),
				"lean": Vector3(0.0, 0.0, 0.0) if main else Vector3(sin(angle), 0.0, -cos(angle)) * rng.randf_range(0.35, 0.6),
				"height": size * (2.6 if main else rng.randf_range(0.8, 1.5)), "width": size * (0.55 if main else rng.randf_range(0.22, 0.35)), "delay": 0.0 if main else rng.randf_range(0.03, 0.12), "twist": rng.randf() * TAU})
	else:
		preload("res://scripts/kame_beam.gd").spawn(self, top, ground, body, core, clampf(float(spell.get("radius", 1.5)) * 0.32, 0.3, 1.1), life, gentle)
	_update()


func _process(dt: float) -> void:
	age += dt
	if age >= life + 0.1:
		queue_free(); return
	_update()


func _update() -> void:
	for spike in _spikes:
		var rise := smoothstep(0.0, 0.14, age - float(spike.delay))
		var melt := 1.0 - smoothstep(life - 0.4, life, age)
		var height: float = float(spike.height) * rise * melt
		var width: float = float(spike.width) * (0.6 + 0.4 * rise) * melt
		var basis := Basis.from_euler(Vector3(-PI * 0.5, float(spike.twist), 0.0))
		basis = Basis.from_euler(Vector3(spike.lean.z, 0.0, -spike.lean.x)) * basis
		(spike.node as MeshInstance3D).global_transform = Transform3D(basis.scaled(Vector3(width, width, maxf(height, 0.001))), ground + spike.at + basis.z * 0.0 + Vector3.UP * (height * 0.45 - 0.2))
	if _icicle != null:
		var fall := clampf(age / 0.2, 0.0, 1.0)
		_icicle.visible = age < 0.32
		var size := clampf(float(spell.get("radius", 1.5)) * 0.9, 1.0, 3.0)
		var tip := ground.lerp(ground + Vector3.UP * 9.0, 1.0 - fall * fall)
		var basis := Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(0.55, 0.55, 2.6) * size)
		_icicle.global_transform = Transform3D(basis, tip + Vector3.UP * size * 1.1)
	if not _storm: return
	var opacity := 1.0 - smoothstep(0.55, 1.0, age / life)
	presentation._set_material_clock(_material, spell, age, opacity)
	# Re-roll the jagged path a few times a second: real lightning flickers.
	var step := floorf(age * 18.0)
	if step == _flicker: return
	_flicker = step
	var rng := RandomNumberGenerator.new(); rng.seed = hash(Vector2i(int(step), int(top.x * 10.0)))
	var main := _jagged(rng, top, ground, 18, 1.4 * minf(scale_factor, 1.6) * clampf(top.distance_to(ground) / 22.0, 0.25, 1.0))
	var paths := [main]; var widths := [0.34 * scale_factor]
	for f in range(3 + int(scale_factor)):
		var from: Vector3 = main[rng.randi_range(4, 12)]
		var reach := 3.0 * clampf(top.distance_to(ground) / 22.0, 0.25, 1.0) * scale_factor
		var tip := from.lerp(ground, 0.5) + Vector3(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach) * 0.4, rng.randf_range(-reach, reach))
		paths.append(_jagged(rng, from, tip, 7, 0.7 * scale_factor)); widths.append(0.14 * scale_factor)
	presentation._strip_paths(_bolt, paths, widths)


func _jagged(rng: RandomNumberGenerator, from: Vector3, to: Vector3, points: int, wobble: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side).normalized()
	for i in range(points):
		var t := float(i) / float(points - 1)
		var offset := Vector3.ZERO
		if i > 0 and i < points - 1:
			offset = (side * rng.randf_range(-1.0, 1.0) + other * rng.randf_range(-1.0, 1.0)) * wobble * sin(t * PI)
		result.append(from.lerp(to, t) + offset)
	return result
