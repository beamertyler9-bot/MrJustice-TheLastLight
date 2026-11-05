extends Node3D
## The wake of a teleport / dash: a ribbon of the spell's energy streaming out of
## Mr. Justice's back, from where he left to where he is now. It stays attached to his back
## and shrinks into it as it fades.

var presentation
var spell: Dictionary
var player: Node3D
var tail := Vector3.ZERO
var life := 0.65
var age := 0.0
var _ribbon: MeshInstance3D
var _glow: MeshInstance3D
var _material: ShaderMaterial
var _glow_material: ShaderMaterial


func setup(owner_presentation, recipe: Dictionary, hero: Node3D, from: Vector3) -> void:
	presentation = owner_presentation; spell = recipe; player = hero; tail = from


func _ready() -> void:
	name = "DashTrail"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_material = presentation._material(presentation.ENERGY, spell)
	_ribbon = MeshInstance3D.new(); _ribbon.mesh = ArrayMesh.new(); _ribbon.material_override = _material
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _ribbon.extra_cull_margin = 4.0
	add_child(_ribbon)
	_glow_material = presentation._material(presentation.ENERGY, spell)
	_glow = MeshInstance3D.new(); _glow.mesh = ArrayMesh.new(); _glow.material_override = _glow_material
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _glow.extra_cull_margin = 4.0
	add_child(_glow)
	_update(0.0)


func _process(dt: float) -> void:
	age += dt
	if age >= life or not is_instance_valid(player):
		queue_free(); return
	_update(dt)


func _back_point() -> Vector3:
	var visual: Variant = player.get("visual")
	var facing: Vector3 = -(visual as Node3D).global_basis.z if is_instance_valid(visual) else Vector3.FORWARD
	facing.y = 0.0
	if facing.length_squared() < 1.0e-4: facing = Vector3.FORWARD
	return player.global_position + Vector3.UP * 1.0 - facing.normalized() * 0.28


func _update(dt: float) -> void:
	var progress := age / life
	var back := _back_point()
	# The far end catches up with him, so the wake retracts into his back.
	tail = tail.lerp(back, 1.0 - exp(-dt * 1.8))
	var points := PackedVector3Array(); var alpha := PackedFloat32Array()
	for i in range(14):
		var t := float(i) / 13.0
		var point := tail.lerp(back, t)
		point += Vector3.UP * sin(t * PI * 2.0 + age * 14.0) * 0.08 * (1.0 - t)
		points.append(point); alpha.append((0.35 + 0.65 * t) * (1.0 - progress * 0.6))
	var fade := 1.0 - smoothstep(0.4, 1.0, progress)
	presentation._set_material_clock(_material, spell, age, fade)
	presentation._set_material_clock(_glow_material, spell, age, fade * 0.45)
	presentation._strip(_ribbon, points, 0.6 * (1.0 - progress * 0.5), alpha)
	presentation._strip(_glow, points, 1.25 * (1.0 - progress * 0.5), alpha)
