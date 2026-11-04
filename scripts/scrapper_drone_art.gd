extends RefCounted

const Resources = preload("res://scripts/creature_resources.gd")
static func bind(actor) -> void:
	Resources.bind(actor, actor.species_id)
	actor.core.set_meta("neutral_transform", actor.core.transform)
	if actor.walking: actor.visual_rig.floor_y = _foot_height(actor)
	actor.normal_glow = actor.core.material_override
	actor.attack_glow = actor.B.mat("#c89cf0", 0, 0.8)
	actor.hurt_glow = actor.B.mat("#e6dced", 0, 0.65)
static func reset(joint: Node3D) -> void:
	joint.transform = joint.get_meta("neutral_transform", Transform3D.IDENTITY)
static func pose(actor, dt: float, speed: float, contact := false) -> void:
	actor.gait_weight = lerpf(actor.gait_weight, clampf(speed / 2.5, 0, 1), 1 - exp(-maxf(dt, 0) * 8))
	var gait: float = actor.gait_weight if actor.windup <= 0 and actor.recovery <= 0 and not contact else 0.0
	var phase := clampf(1.0 - actor.windup / float(actor.profile.windup), 0, 1) if actor.windup > 0 else 0.0
	var settle := smoothstep(0.0, 1.0, clampf(actor.recovery / float(actor.profile.recovery), 0, 1))
	if contact: phase = 1.0; settle = 0.0
	var load := smoothstep(0.0, 0.55, phase) * (1 - smoothstep(0.72, 1.0, phase))
	var blast := smoothstep(0.72, 1.0, phase) + settle
	var heavy: bool = actor.drone_variant == "blast"
	var cycle: float = actor.clock * (6.2 if heavy else 8.0)
	actor.model.position = Vector3.ZERO
	actor.model.rotation.x = 0; actor.model.rotation.z = 0
	reset(actor.head)
	actor.head.position.y += sin(actor.clock * 2.4) * (0.012 if actor.walking else 0.075) * (1 - load * 0.8)
	actor.head.rotation.x = -load * (0.13 if heavy else 0.1) + blast * (0.18 if heavy else 0.14)
	actor.head.position.z += load * (0.1 if heavy else 0.06) + blast * (0.34 if heavy else 0.27)
	actor.head.position.y -= load * (0.025 if actor.walking else 0.055)
	actor.head.rotation.z = sin(cycle) * 0.018 * gait if actor.walking else sin(actor.clock * 1.7) * 0.035 * (1 - load) + sin(cycle) * 0.045 * gait
	reset(actor.core)


	var charge_pulse := 0.065 if actor.drone_variant == "echo" else 0.025
	var pulse: float = 1 + sin(actor.clock * 11) * (0.015 + charge_pulse * load) + 0.045 * blast
	actor.core.scale *= Vector3(pulse, 1, pulse)
	for i in range(2):
		var side: float = -1 if i == 0 else 1
		reset(actor.arms[i]); reset(actor.forearms[i])
		actor.arms[i].rotation.z += side * (load * 0.23 - blast * 0.18) + sin(actor.clock * 1.7 + i) * 0.025
		actor.forearms[i].rotation.x -= load * 0.4; actor.forearms[i].rotation.x += blast * 0.27
		actor.forearms[i].rotation.y += side * sin(actor.clock * 0.8) * 0.05 * (1 - load)
	for i in range(actor.feet.size()):
		reset(actor.feet[i]); reset(actor.knees[i])
		var side: float = -1 if i % 2 == 0 else 1
		var end: float = -1 if i < 2 else 1
		var wave: float = sin(cycle + (PI if i in [1, 2] else 0.0)) * gait
		actor.feet[i].rotation.x -= end * wave * 0.38
		actor.feet[i].rotation.z += side * (load * 0.13 - blast * 0.05) + wave * 0.08
		actor.knees[i].rotation.x -= end * maxf(0, wave) * 0.65; actor.knees[i].rotation.x += load * 0.12
	if actor.hurt_timer > 0 and not contact:
		var hurt := smoothstep(0, 1, clampf(actor.hurt_timer / 0.3, 0, 1))
		actor.head.rotation.x += hurt * 0.18; actor.head.rotation.z += actor.hurt_side * hurt * 0.1
	if actor.walking: actor.model.position.y += float(actor.visual_rig.floor_y) - _foot_height(actor)
static func _foot_height(actor) -> float:
	var low := INF
	for toe in actor.visual_rig.toes:
		var frame: Transform3D = actor.global_transform.affine_inverse() * toe.global_transform
		for x in [-0.08, 0.08]:
			for z in [-0.135, 0.085]: low = minf(low, (frame * Vector3(x, -0.043, z)).y)
	return low
