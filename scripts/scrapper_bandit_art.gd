extends RefCounted


const Resources = preload("res://scripts/creature_resources.gd")
const Motion = preload("res://scripts/creature_motion.gd")
const SkinPose = preload("res://scripts/scrapper_skin_pose.gd")
static func bind(actor, kind: String) -> void:
	Resources.bind(actor, "scrapper_" + kind)
	var rig: Dictionary = actor.visual_rig
	rig.pelvis = rig.links[1].node; rig.chest = rig.links[4].node
	rig.wrists = [rig.links[10].node, rig.links[23].node]
	rig.soles = [rig.links[35].node, rig.links[39].node]
	rig.sole_width = 0.125 * (1.35 if kind == "bruiser" else 1.0)
	rig.floor_y = _sole_height(actor)
	if kind == "slinger":
		rig.pouch = actor.model.find_child("SlingPouch", true, false)
		rig.bands = actor.model.find_children("ElasticBand*", "MeshInstance3D", true, false)
	actor.normal_glow = actor.core.material_override

	actor.hurt_glow = actor.B.mat("#f5d8ed", 0, 0.7)
	actor.attack_glow = actor.B.mat("#ce8cff", 0, 0.7)
static func pose(actor, dt: float, speed: float, contact := false) -> void:
	actor.gait_weight = lerpf(actor.gait_weight, clampf(speed / 2.5, 0, 1), 1 - exp(-maxf(dt, 0) * 8))
	var gait: float = actor.gait_weight
	var cycle: float = actor.clock * (8.4 if actor.scrapper_kind == "scout" else 5.4)
	var progress := clampf(1.0 - actor.windup / float(actor.profile.windup), 0, 1) if actor.windup > 0 else 0.0
	var settle := smoothstep(0.0, 1.0, clampf(actor.recovery / float(actor.profile.recovery), 0, 1))
	if contact: progress = 1.0; settle = 0.0
	var loading := smoothstep(0.0, 0.52, progress) * (1 - smoothstep(0.65, 1.0, progress))
	var release := smoothstep(0.65, 1.0, progress) + settle
	var follow := sin((1 - clampf(actor.recovery / float(actor.profile.recovery), 0, 1)) * PI) if actor.recovery > 0 and not contact else 0.0
	var stride := gait if actor.windup <= 0 and actor.recovery <= 0 and not contact else 0.0
	var lean: float = 0.05 * loading - 0.13 * release
	if actor.scrapper_kind == "bruiser": lean = 0.09 * loading - 0.23 * release
	elif actor.scrapper_kind == "slinger": lean = 0.025 * loading - 0.035 * release
	Motion._place(actor.model, Vector3(0, absf(sin(cycle)) * 0.025 * stride - 0.035 * loading, -0.045 * release))
	actor.model.rotation.x = lean; actor.model.rotation.z = sin(cycle * 0.5) * 0.018 * stride
	var twist: float = 0.3 * loading - 0.27 * release - 0.12 * follow
	if actor.scrapper_kind == "bruiser": twist = 0.24 * loading - 0.32 * release
	elif actor.scrapper_kind == "slinger": twist = -0.1 * loading + 0.06 * release
	Motion._rotate(actor.visual_rig.pelvis, Vector3(0, twist * 0.35, 0))
	Motion._rotate(actor.visual_rig.chest, Vector3(0, twist * 0.65, 0))
	Motion._rotate(actor.head, Vector3(-0.09 * loading + 0.07 * release, -twist * 0.65 + sin(actor.clock * 0.6) * 0.025 * (1 - stride), 0))
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var walk: float = sin(cycle + i * PI) * stride
		Motion._rotate(actor.feet[i], Vector3(walk * 0.48 + (0.1 if i == 0 else -0.06) * release, 0, side * 0.025 * loading))
		Motion._rotate(actor.knees[i], Vector3(-maxf(0, -walk) * 0.58 - 0.12 * loading - 0.05 * release, 0, 0))
		var arm := Vector3(-walk * 0.36, 0, side * 0.07)
		var elbow := Vector3(0.1, 0, 0)
		var wrist := Vector3.ZERO
		match actor.scrapper_kind:
			"scout":
				if i == 0:
					arm += Vector3(0.65, -0.9, -0.4) * loading + Vector3(1.1, -0.22, -0.07) * release + Vector3(0.12, 0.26, -0.13) * follow
					elbow.x += 0.65 * loading - 0.16 * release
					wrist = Vector3(-0.25 * loading - 0.5 * release, 0, -0.12 * release)
				else:
					arm += Vector3(0.42, 0.12, 0.22) * loading + Vector3(0.36, -0.15, 0.16) * release
					elbow.x += 0.42 * (loading + release)
			"bruiser":
				if i == 0:
					arm += Vector3(0.5, -0.75, -0.3) * loading + Vector3(1.15, -0.2, -0.02) * release
					elbow.x += 1.0 * loading - 0.12 * release
					wrist.x = -0.18 * loading - 0.12 * release
				else:
					arm += Vector3(0.48, 0.12, 0.14) * (loading + release)
					elbow.x += 1.05 * (loading + release)
			"slinger":
				if i == 0:
					arm += Vector3(0.95, -0.8, 0) * (loading + release)
					elbow.x -= 0.12 * (loading + release)
					wrist.x = -0.8 * (loading + release)
					wrist.y = 0.8 * (loading + release)
				else:
					arm += Vector3(0.72, -0.5, 0.1) * loading + Vector3(0.65, 0.08, 0.12) * release
					elbow.x += 0.85 * loading + 0.55 * release
		Motion._rotate(actor.arms[i], arm)
		Motion._rotate(actor.forearms[i], elbow)
		Motion._rotate(actor.visual_rig.wrists[i], wrist)
	if actor.scrapper_kind == "slinger": _sling(actor, loading)


	if actor.hurt_timer > 0 and not contact:
		var hurt := smoothstep(0.0, 1.0, clampf(actor.hurt_timer / 0.3, 0, 1))
		actor.model.rotation.x += 0.16 * hurt; actor.model.rotation.z += actor.hurt_side * 0.1 * hurt
		actor.model.position.z += 0.08 * hurt; actor.head.rotation.x += 0.28 * hurt


	actor.model.position.y += (float(actor.visual_rig.floor_y) - _sole_height(actor)) * clampf(loading + release, 0, 1)
	SkinPose.sync(actor.model, actor.visual_rig)
static func _sole_height(actor) -> float:
	var low := INF
	for sole in actor.visual_rig.soles:
		var frame: Transform3D = actor.global_transform.affine_inverse() * sole.global_transform
		for x in [-float(actor.visual_rig.sole_width), float(actor.visual_rig.sole_width)]:
			for z in [-0.235, 0.125]: low = minf(low, (frame * Vector3(x, -0.0825, z)).y)
	return low
static func _sling(actor, draw: float) -> void:
	var rig: Dictionary = actor.visual_rig
	var pouch: Node3D = rig.pouch
	pouch.position = Vector3(0, 0.14, 0.05 + 0.25 * draw)
	for band in rig.bands:
		var anchor: Vector3 = band.get_meta("fork_anchor")
		var delta: Vector3 = pouch.position - anchor
		band.position = (pouch.position + anchor) * 0.5
		band.quaternion = Quaternion(Vector3.UP, delta.normalized())
		band.scale = Vector3(1, delta.length() / float(band.get_meta("rest_length")), 1)
	if draw <= 0.001: return


	var wrist: Node3D = rig.wrists[1]
	var target: Vector3 = pouch.global_position
	for iteration in range(8):
		for joint in [actor.forearms[1], actor.arms[1]]:
			var from: Vector3 = (wrist.to_global(Vector3(0, -0.05, 0)) - joint.global_position).normalized()
			var to: Vector3 = (target - joint.global_position).normalized()
			var turn := Quaternion.IDENTITY.slerp(Quaternion(from, to), draw)
			joint.basis = (joint.get_parent().global_basis.inverse() * Basis(turn) * joint.global_basis).orthonormalized()
