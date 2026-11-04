extends RefCounted
const Resources = preload("res://scripts/creature_resources.gd")
const Motion = preload("res://scripts/creature_motion.gd")
const SkinPose = preload("res://scripts/scrapper_skin_pose.gd")
static func bind(actor) -> void:
	Resources.bind(actor, "dissonance")
	actor.staff_muzzle = actor.model.find_child("StaffEmitter", true, false)
	actor.visual_rig.weapon_hand = actor.visual_rig.links[actor.visual_rig.skeleton.find_bone("Hand_L")].node
	actor.normal_glow = actor.core.material_override; actor.hurt_glow = actor.B.mat("#f0d9ff", 0, 0.65); actor.attack_glow = actor.B.mat("#b687e2", 0, 0.55)
static func pose(a, dt: float, speed: float, contact := false) -> void:
	a.gait_weight = lerpf(a.gait_weight, clampf(speed / 2.4, 0, 1), 1 - exp(-maxf(dt, 0) * 8))
	var phase = clampf(1 - a.windup / float(a.profile.windup), 0, 1) if a.windup > 0 else 0.0
	var settle = smoothstep(0, 1, clampf(a.recovery / float(a.profile.recovery), 0, 1))
	if contact: phase = 1; settle = 0
	var load = smoothstep(0, 0.62, phase) * (1 - smoothstep(0.72, 1, phase)); var release = smoothstep(0.72, 1, phase) + settle
	var stride = a.gait_weight if a.windup <= 0 and a.recovery <= 0 and not contact else 0.0
	Motion._place(a.model, Vector3(0, absf(sin(a.clock * 5.5)) * 0.02 * stride - 0.025 * load, 0))
	a.model.rotation.x = -0.08 * load + 0.14 * release; a.model.rotation.z = 0
	if a.attack_kind == "slam": a.model.rotation.x = 0.08 * load - 0.14 * release
	Motion._rotate(a.head, Vector3(-0.08 * load + 0.07 * release, sin(a.clock * 0.55) * 0.045, 0))
	for i in range(2):
		var walk = sin(a.clock * 5.5 + i * PI) * stride
		Motion._rotate(a.feet[i], Vector3(walk * 0.42, 0, 0)); Motion._rotate(a.knees[i], Vector3(-maxf(0, -walk) * 0.55 - 0.07 * load, 0, 0))
		var arm = Vector3(-walk * 0.25, 0, -0.1 if i == 0 else 0.1); var elbow = Vector3(0.12, 0, 0)
		if a.attack_kind == "slam":
			arm += Vector3(2.1, 0, -0.05) * load + Vector3(0.25, 0, 0) * release if i == 0 else Vector3(0.6, 0.2, 0.3) * load
			elbow.x += 0.55 * load + 0.18 * release
		else:
			arm += Vector3(1.25, 0.05, -0.1) * load + Vector3(1.53, 0.18, -0.1) * release if i == 0 else Vector3(0.4, -0.2, 0.1) * load
			elbow.x += 0.18 * load + 0.05 * release
		Motion._rotate(a.arms[i], arm); Motion._rotate(a.forearms[i], elbow)


	var turn = -2.5 * (load + release) if a.attack_kind == "slam" else 0.0
	Motion._rotate(a.visual_rig.weapon_hand, Vector3(turn, 0, 0))
	if a.hurt_timer > 0 and not contact:
		var hurt = smoothstep(0, 1, clampf(a.hurt_timer / 0.3, 0, 1)); a.model.rotation.x += 0.15 * hurt; a.head.rotation.x += 0.2 * hurt
	SkinPose.sync(a.model, a.visual_rig)
