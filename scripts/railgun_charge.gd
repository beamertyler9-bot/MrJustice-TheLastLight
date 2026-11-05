extends Node3D
## Railgun charge-up: one magic circle opens in front of the hand, then three more lock into
## a triangle around it and the whole array spins faster and faster. On release the circles
## are launched down the barrel and burst (release mode, self-freeing).

var _circles: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _clock := 0.0
var _release := false
var _life := 0.7
var _origin := Vector3.ZERO
var _direction := Vector3.FORWARD
var _presentation


func _ready() -> void:
	name = "RailgunCircles"
	top_level = true


func _ensure(presentation, spell: Dictionary) -> void:
	if not _circles.is_empty(): return
	_presentation = presentation
	# Proper magic circles: the inked sigil shader on a card (rings, teeth and runes).
	var star: Dictionary = spell.duplicate(); star.sigil = str(spell.get("sigil", "star")) if str(spell.get("sigil", "circle")) != "circle" else "star"
	_material = presentation._material(presentation.SEAL, star)
	_material.set_shader_parameter("brightness", 1.6)
	var quad := QuadMesh.new(); quad.size = Vector2.ONE * 2.0
	for i in range(4):
		var circle := MeshInstance3D.new()
		circle.mesh = quad
		circle.material_override = _material
		circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		circle.extra_cull_margin = 2.0
		add_child(circle)
		_circles.append(circle)


static func _basis_facing(direction: Vector3) -> Basis:
	var z := -direction.normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1.0e-4: x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x).normalized(), z)


## Charging: anchor is the hand, direction the aim, amount 0..1.
func update_charge(presentation, spell: Dictionary, anchor: Vector3, direction: Vector3, amount: float, dt: float) -> void:
	_ensure(presentation, spell)
	_clock += dt * (1.0 + amount * 6.0)
	_layout(anchor, direction, amount, 0.0)
	presentation._set_material_clock(_material, spell, _clock, 1.0)


## Fire: the array flies down the barrel and blows apart.
func release(presentation, spell: Dictionary, origin: Vector3, direction: Vector3) -> void:
	_ensure(presentation, spell)
	_release = true; _origin = origin; _direction = direction.normalized(); _clock = 0.0
	_layout(origin, direction, 1.0, 0.0)


func _process(dt: float) -> void:
	if not _release: return
	_clock += dt
	if _clock >= _life:
		queue_free(); return
	var t := _clock / _life
	_layout(_origin, _direction, 1.0, t)
	_material.set_shader_parameter("opacity", 1.0 - t)


func _layout(anchor: Vector3, direction: Vector3, amount: float, launch: float) -> void:
	var facing := _basis_facing(direction)
	var forward := direction.normalized()
	var spin := _clock * 2.2
	# The big circle: opens during the first quarter of the charge.
	var open := smoothstep(0.0, 0.25, amount)
	var main := _circles[0]
	main.visible = open > 0.01
	main.global_transform = Transform3D(facing * Basis(Vector3.BACK, spin) * Basis.from_scale(Vector3.ONE * (0.95 * open + launch * 1.6)), anchor + forward * (0.55 + launch * 6.0))
	# Three more lock into a triangle around it from 35 % charge.
	var lock := smoothstep(0.35, 0.65, amount)
	var side := facing.x; var up := facing.y
	for i in range(1, 4):
		var circle := _circles[i]
		circle.visible = lock > 0.01
		var angle := float(i - 1) * TAU / 3.0 + spin * 0.6 + PI * 0.5
		var offset := (side * cos(angle) + up * sin(angle)) * (0.95 * lock + launch * 2.5)
		circle.global_transform = Transform3D(facing * Basis(Vector3.BACK, -spin * 1.6) * Basis.from_scale(Vector3.ONE * (0.5 * lock + launch * 0.8)), anchor + forward * (0.85 + launch * 9.0) + offset)
