extends Node3D

const B = preload("res://scripts/build.gd")
var side: float = 1.0
var knuckles: Array[Node3D] = []
var middle_joints: Array[Node3D] = []
var tips: Array[Node3D] = []
var thumb_base: Node3D
var thumb_middle: Node3D
var thumb_tip: Node3D

func _ready() -> void:
	var silver = B.surface("silver", "#ccd3d6", 0.78)
	var light = B.surface("silver", "#eff1f2", 0.78)
	var dark = B.mat("#29393d", 0.55)
	B.beveled_box(self, Vector3.ZERO, Vector3(0.22, 0.18, 0.14), silver)
	var ring = B.cyl(self, Vector3(0, 0, 0.076), 0.052, 0.012, dark)
	ring.rotation.x = PI / 2
	B.ball(self, Vector3(0, 0, 0.084), Vector3(0.065, 0.065, 0.012), B.mat("#86e3ec", 0.2, 0.6))
	for i in range(3):
		var base = Node3D.new()
		base.name = "Finger" + str(i)
		base.position = Vector3(-0.075 + i * 0.075, -0.08, -0.015)
		add_child(base)
		B.ball(base, Vector3.ZERO, Vector3(0.057, 0.055, 0.058), dark)
		B.beveled_box(base, Vector3(0, -0.04, 0), Vector3(0.051, 0.08, 0.055), light)
		var middle = Node3D.new()
		middle.name = "Middle"
		middle.position.y = -0.08
		base.add_child(middle)
		B.beveled_box(middle, Vector3(0, -0.0375, 0), Vector3(0.047, 0.075, 0.052), silver)
		var tip = Node3D.new()
		tip.name = "Tip"
		tip.position.y = -0.075
		middle.add_child(tip)
		knuckles.append(base)
		middle_joints.append(middle)
		tips.append(tip)
	thumb_base = Node3D.new()
	thumb_base.name = "Thumb"
	thumb_base.position = Vector3(-side * 0.14, -0.02, -0.025)
	add_child(thumb_base)
	B.beveled_box(thumb_base, Vector3(0, -0.035, 0), Vector3(0.06, 0.07, 0.065), light)
	thumb_middle = Node3D.new()
	thumb_middle.position.y = -0.07
	thumb_base.add_child(thumb_middle)
	B.beveled_box(thumb_middle, Vector3(0, -0.0325, 0), Vector3(0.055, 0.065, 0.06), silver)
	thumb_tip = Node3D.new()
	thumb_tip.position.y = -0.065
	thumb_middle.add_child(thumb_tip)
	set_pose(1.0, 0.13, 0.2, 0.08, 0.0)

func set_pose(dt: float, proximal: float, distal: float, thumb_fold: float, spread: float = 0.0, response: float = 28.0) -> void:
	var weight = 1.0 - exp(-dt * response)
	for i in range(3):
		knuckles[i].rotation.x = lerp_angle(knuckles[i].rotation.x, -proximal, weight)
		knuckles[i].rotation.z = lerp_angle(knuckles[i].rotation.z, (i - 1) * spread * 0.12, weight)
		middle_joints[i].rotation.x = lerp_angle(middle_joints[i].rotation.x, -distal, weight)
	var relaxed = Vector3(-side * lerpf(0.45, 0.9, spread), -lerpf(0.85, 0.45, spread), 0.02).normalized()
	var folded = Vector3(side * 0.95, -0.25, 0.08).normalized()
	var direction = relaxed.lerp(folded, thumb_fold).normalized()
	thumb_base.quaternion = thumb_base.quaternion.slerp(Quaternion(Vector3.DOWN, direction), weight)
	thumb_base.position.z = lerpf(thumb_base.position.z, lerpf(-0.025, 0.115, thumb_fold), weight)
	thumb_middle.rotation.x = lerp_angle(thumb_middle.rotation.x, -lerpf(0.08, 0.55, thumb_fold), weight)

func palm_origin() -> Vector3:
	return to_global(Vector3(0, 0, 0.09))
