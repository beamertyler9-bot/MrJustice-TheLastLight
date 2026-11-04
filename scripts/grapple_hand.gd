extends RefCounted

var hand: Node3D
var wrist: Node3D
var state: String = ""
var age: float = 0.0
var duration: float = 0.0
var point: Vector3
var normal: Vector3 = Vector3.BACK
var origin: Transform3D
var model_scale: Vector3 = Vector3.ONE

func setup(actual_hand: Node3D, socket: Node3D) -> void:
	hand = actual_hand
	wrist = socket

func active() -> bool:
	return state != ""

func launch(target: Vector3, surface_normal: Vector3) -> bool:
	if active() or not target.is_finite() or not surface_normal.is_finite() or surface_normal.length_squared() < 0.01:
		return false
	point = target
	normal = surface_normal.normalized()
	origin = hand.global_transform
	model_scale = origin.basis.get_scale()
	duration = clampf(origin.origin.distance_to(target) / 30.0, 0.12, 0.55)
	age = 0
	state = "out"
	hand.top_level = true
	hand.global_transform = origin
	return true

func set_anchor(target: Vector3, surface_normal: Vector3) -> void:
	if target.is_finite() and surface_normal.is_finite() and surface_normal.length_squared() > 0.01:
		point = target
		normal = surface_normal.normalized()

func finish(immediate: bool = false) -> void:
	if not active():
		return
	if immediate:
		hand.top_level = false
		hand.transform = Transform3D.IDENTITY
		state = ""
		age = 0
		return
	if state != "return":
		origin = hand.global_transform
		state = "return"
		age = 0
		duration = 0.24

static func facing(direction: Vector3) -> Basis:
	var forward = direction.normalized()
	var right = Vector3.DOWN.cross(forward)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	return Basis(right, forward.cross(right).normalized(), forward)

func tick(dt: float) -> void:
	if not active() or not is_instance_valid(hand) or not is_instance_valid(wrist):
		return
	age += dt
	if state == "return":
		var t = smoothstep(0.0, duration, age)
		var destination = wrist.global_transform
		hand.global_position = origin.origin.lerp(destination.origin, t) + Vector3.UP * sin(t * PI) * 0.1
		hand.global_basis = origin.basis.orthonormalized().slerp(destination.basis.orthonormalized(), t) * Basis.from_scale(model_scale)
		if age + 1.0e-06 >= duration:
			finish(true)
		return
	var target = point + normal * 0.09
	var target_basis = facing(-normal)
	if state == "out":
		var t = smoothstep(0.0, duration, age)
		hand.global_position = origin.origin.lerp(target, t)
		hand.global_basis = origin.basis.orthonormalized().slerp(target_basis, t) * Basis.from_scale(model_scale)
		if age + 1.0e-06 >= duration:
			state = "latched"
			age = 0
	else:
		hand.global_position = target
		hand.global_basis = target_basis * Basis.from_scale(model_scale)
