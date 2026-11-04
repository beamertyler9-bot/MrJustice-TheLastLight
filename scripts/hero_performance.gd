extends RefCounted

var changes = []
var rig_shift = Vector3.ZERO
var idle_age = 0.0
var palm_weight = 0.0
var look = Vector3.ZERO
var last_equipment = ""
func priority(h, motion: String = "") -> bool:
	return motion in ["climb", "mantle", "swim", "beam", "hook"] or h.attack_time > 0 or h.dodge_progress >= 0 or h.carry_pose or not h.held_item_id.is_empty() or h.is_throwing() or h.grapple.active() or h.aim_weight > 0.01 or h.charge_weight > 0.01 or h.bag_progress > 0.01 or h.bag_target > 0.01 or not h.rest_pose.is_empty() or h.supply_pour.active() or h.is_grimoire_casting() or h._grimoire.visible or maxf(h._weights.beam, h._weights.hook) > 0.01 or maxf(h._weights.climb, maxf(h._weights.mantle, h._weights.swim)) > 0.01
func restore(h, motion: String) -> void:
	var handoff = h.weapon_id != last_equipment and palm_weight > 0.001; last_equipment = h.weapon_id
	if not priority(h, motion) and not handoff:
		for change in changes:
			if is_instance_valid(change.node): change.node.quaternion = (change.node.quaternion * change.delta.inverse()).normalized()
		h.rig.position -= rig_shift
	changes.clear(); rig_shift = Vector3.ZERO
func pose(h, dt: float, motion: String, speed: float) -> void:
	if priority(h, motion): idle_age = 0; palm_weight = 0; look = Vector3.ZERO; return
	var free = not h._weapon_mount.visible and not h._held_mount.visible
	if h._held_mount.visible: return
	var nodes = [h.torso, h.head, h.arms[0], h.arms[1], h.forearms[0], h.forearms[1], h.wrists[0], h.wrists[1]]; var before = []
	for node in nodes: before.append(node.quaternion)
	var feet = [h.feet[0].global_position, h.feet[1].global_position]
	var gait = h._locomotion if motion in ["walk", "run"] else 0.0
	var sway = lerpf(sin(h.phase), sin(h.run_cycle * TAU), h._run)
	var chest = Vector3(-0.025 * gait, -sway * 0.06 * gait, sway * 0.047 * gait)
	h.torso.quaternion = h.torso.quaternion * Quaternion.from_euler(chest)
	if motion == "idle" and free and h._grounded: idle_age += dt
	else: idle_age = 0
	var age = fposmod(idle_age, 18.0)
	var inspect = smoothstep(2.3, 2.85, age) * (1 - smoothstep(3.8, 4.65, age)) if free else 0.0
	palm_weight = lerpf(palm_weight, inspect, 1 - exp(-dt * 8))
	var glance = smoothstep(1.0, 1.5, age) * (1 - smoothstep(1.9, 2.3, age)) if free else 0.0
	var desired = Vector3(-inspect * 0.14, inspect * 0.28 + glance * 0.16, -inspect * 0.025)
	if motion == "jump" and not h._grounded: desired.x = -0.12 if h._velocity.y < -0.5 else 0.025
	look = look.lerp(desired, 1 - exp(-dt * 8))
	if free:
		h.head.quaternion = h.head.quaternion * Quaternion.from_euler(look + Vector3(0, -chest.y * 0.5, -chest.z * 0.4))
		for i in range(2):
			var side = -1.0 if i == 0 else 1.0
			h.arms[i].quaternion = h.arms[i].quaternion * Quaternion.from_euler(Vector3(-sway * (1 if i == 0 else -1) * 0.085 * gait, side * 0.025 * gait, side * 0.025 * gait))
			h.forearms[i].rotation.x += gait * (0.1 + h._run * 0.08)
		if palm_weight > 0.001:
			var wrist = h.torso.to_local(h.hands[0].global_position)
			var pole = h.torso.to_local(h.forearms[0].global_position) - h.arms[0].position



			h._solve_arm(0, wrist.lerp(Vector3(-0.65, 0.62, -0.48), palm_weight), 1.0, pole.lerp(Vector3(-0.58, -0.25, 0.1), palm_weight), 0.0)
			h._orient_palm(0, Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP), palm_weight)
			h.hands[0].set_pose(dt, 0.06, 0.08, 0.03, 0.1, 18 * palm_weight)
	var airborne = motion == "jump" and not h._grounded
	if airborne:
		var fall = 1 - smoothstep(-3.5, -0.4, h._velocity.y)
		h.torso.rotation.x += lerpf(-0.08, -0.16, fall) * h._weights.jump



		var lift = smoothstep(0.06, 1.12, h._fall_age)
		for i in range(2):
			var side = -1.0 if i == 0 else 1.0
			var palm = h.hands[i].global_basis.orthonormalized()


			var span = 0.74 if i == 1 and h._weapon_mount.visible else 0.54
			var wrist = Vector3(side * lerpf(0.58, span, lift), lerpf(0.45, 1.38, lift), lerpf(-0.38, -0.12, lift))
			h._solve_arm(i, wrist, h._weights.jump, Vector3(side * 0.65, -0.3, 0.08), 0.0)
			if i == 1 and h._weapon_mount.visible:
				h._orient_palm(i, h.torso.global_basis.orthonormalized().inverse() * palm, 1.0)
	var land = h._landing_weight(); rig_shift = Vector3(0, -land * 0.035, 0); h.rig.position += rig_shift
	if land > 0.001: h.torso.rotation.x -= land * 0.075
	if airborne or not rig_shift.is_zero_approx():
		var normal = h.global_basis.orthonormalized().inverse() * h._floor_normal
		for i in range(2):
			var target = h.to_local(feet[i])
			if airborne: target += Vector3(0, 0.11 if i == 0 else 0, -0.09 if i == 0 else 0.05) * h._weights.jump
			h._solve_leg(i, target, normal, 0.0 if airborne else 1.0)
	for i in range(nodes.size()): changes.append({"node": nodes[i], "delta": (before[i].inverse() * nodes[i].quaternion).normalized()})
