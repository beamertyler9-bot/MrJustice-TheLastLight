extends RefCounted


var player: AnimationPlayer
var pose_root: Node3D
var nodes: Array = []
var samples: Array = []
var previous: Array = []
var phase = 0.0
var clip = "hang"
func setup(h):
	nodes = [h.rig, h.torso, h.head] + h.arms + h.forearms + h.wrists + h.legs + h.knees + h.feet
	pose_root = Node3D.new(); pose_root.name = "AuthoredClimb"; h.add_child(pose_root)
	var pose = Node3D.new(); pose.name = "Pose"; pose_root.add_child(pose)
	for i in range(nodes.size()):
		var sample = Node3D.new(); sample.name = "P%d" % i; pose.add_child(sample); samples.append(sample)
	player = AnimationPlayer.new(); player.name = "ClipPlayer"; pose_root.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("", load("res://assets/animation/justice_climb.tres"))
func pose(h, dt: float, weight: float):
	if weight < 0.001:
		previous.clear(); phase = 0; return
	if player == null: setup(h)
	var velocity = h.global_basis.orthonormalized().inverse() * h._climb_velocity
	var local_face = h.global_basis.orthonormalized().inverse() * h._climb_normal
	var moving = velocity.slide(local_face.normalized() if local_face.length_squared() > 0.1 else Vector3.BACK).length() > 0.03
	var face = local_face.normalized() if local_face.length_squared() > 0.1 else Vector3.BACK
	var up = Vector3.UP.slide(face).normalized()
	var rise = velocity.dot(up)
	var next = "lateral" if absf(velocity.x) > absf(rise) * 1.2 else "vertical"
	if not moving: next = "hang"
	if next != clip or not player.is_playing(): player.play(next); clip = next
	var stride = 0.6 * h.MODEL_SCALE if clip == "lateral" else 1.05 * h.MODEL_SCALE
	if moving: phase = fposmod(phase + dt * (velocity.x if clip == "lateral" else rise) / stride, 1.0)
	player.seek(phase if moving else 0.0, true); player.advance(0)
	var local_normal = h.global_basis.orthonormalized().inverse() * h._climb_normal
	var tilt = clampf(-atan2(local_normal.y, maxf(0.1, local_normal.z)), -0.9, 0.65) if local_normal.length_squared() > 0.1 else 0.0
	var alignment = Quaternion(Vector3.RIGHT, tilt)
	var response = 1.0 - exp(-dt * 16)
	for i in range(nodes.size()):
		var target = samples[i].quaternion
		if i == 0: target = alignment * target
		if previous.size() == nodes.size(): target = previous[i].slerp(target, response)
		nodes[i].quaternion = nodes[i].quaternion.slerp(target, weight).normalized()
	if previous.is_empty(): previous.resize(nodes.size())
	for i in range(nodes.size()): previous[i] = nodes[i].quaternion



	var radius = 0.28 / 0.75
	var height = h.STANDING_HEIGHT_METRES / h.MODEL_SCALE
	var shift = radius * local_normal.y if local_normal.y >= 0 else (height - radius) * local_normal.y
	var origin = alignment * samples[0].position + local_normal * shift
	h.rig.position = h.rig.position.lerp(origin, weight)
	for i in range(2):
		h.hands[i].set_pose(dt, 0.2, 0.4, 0.12, 0.35)
		h._foot_world_positions[i] = h.feet[i].global_position
