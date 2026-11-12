extends "res://scripts/hero_base.gd"

const HeroPerformanceLayer = preload("res://scripts/hero_performance.gd")
const ArmReach = preload("res://scripts/arm_reach.gd")
const WORKING_REACH := 0.84
var performance = HeroPerformanceLayer.new()
var concept_mode := "idle"
var concept_age := 0.0
var run_cycle := 0.0
var _run_arm_blends := [1.0, 1.0]
var _tool_arm_starts: Array[Basis] = []
var _tool_arm_rolls: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _tool_applied_rolls: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _mining_release := 0.0
var _support_wrist_roll := 0.0
var _support_palm_start := Basis.IDENTITY
var _support_palm_previous := Basis.IDENTITY
const MAIN_TOOL_GRIP_DISTANCE := 0.105
var _tool_carry_weight := 0.0
var _tool_equip_age := 1.0
var _tool_equip_starts: Array[Quaternion] = []
const REFERENCE_RUN_STANCE := 0.2
const REFERENCE_RUN_DURATION := 0.54
var _steps_before := 0
var _published_feet: Array = []
var _published_origin := Vector3.INF
var roast_pivot: Node3D
var roast_food: Node3D
var toast_material: StandardMaterial3D
var sleep_blend := 0.0
var seat_height := 0.26
var grip_kind := ""
var roast_hover_target := Vector3(0, 1.03, 0)
var pick_power_grip: Node3D
var ordinary_digit_meshes: Array[MeshInstance3D] = []
var tool_support_grip: MeshInstance3D
var ordinary_support_digits: Array[MeshInstance3D] = []
var _support_grip_owned := false
# Which hand meshes should show this frame. The pose code changes its mind several times a
# frame; showing/hiding the finger meshes is expensive, so it is applied once, at the end.
var _pick_grip_want := false
var _support_grip_want := false
var _flight_pose_weight := 0.0
var _flight_pivot_offset := Vector3.ZERO
var _flight_pitch := 0.0
var _flight_fist := 0.0
const TOOL_SUPPORT_OFFSET = Vector3(-0.06, -0.105, 0.08)
const ROAST_SHAFT_METRES := 0.85
const ROAST_GRIP_FROM_BUTT := 0.08

func _ready() -> void:
	super._ready()
	roast_pivot = Node3D.new(); roast_pivot.name = "ConceptRoastingSkewer"; add_child(roast_pivot)
	B.cyl(roast_pivot, Vector3(0, (ROAST_SHAFT_METRES * 0.5 - ROAST_GRIP_FROM_BUTT) / MODEL_SCALE, 0), 0.012, ROAST_SHAFT_METRES / MODEL_SCALE, B.world_surface("timber", "#76533b"))
	roast_food = ItemModels.build(roast_pivot, "marshmallow")
	roast_food.position = Vector3(0, (ROAST_SHAFT_METRES - ROAST_GRIP_FROM_BUTT - 0.07) / MODEL_SCALE, 0); roast_food.scale = Vector3.ONE * 0.78
	toast_material = StandardMaterial3D.new(); toast_material.roughness = 0.75
	for mesh in roast_food.get_children(): mesh.material_override = toast_material
	roast_pivot.hide()
	_build_pick_power_grip()
	_build_tool_support_grip()
	var shadows = load("res://scripts/prepared_hero_shadows.gd")
	# One skinned draw per material; falls back to the prebaked per-joint shadow proxies.
	var loose: Array = shadows.excluded_sources(self)
	var hard: Array = []
	for key in ["flame", "inner_flame", "cape"]:
		if is_instance_valid(get(key)): hard.append(get(key)); loose.erase(get(key))
	if load("res://scripts/rigid_skin_batches.gd").apply(self, loose, hard) == null:
		shadows.apply(self)

func begin_camp_pose(action: String) -> void:
	_show_pick_power_grip(false)
	_show_tool_support_grip(false)
	concept_mode = "sleep_entry" if action == "sleep" else action
	concept_age = 0.0; sleep_blend = 0.0
	rest_pose = {"roast": "marshmallow", "coffee": "coffee", "sleep": "sleep"}.get(action, "sit")
	bag_target = 0.0; bag_progress = 0.0; backpack.show()
	supply_pour.cancel(); reset_cape_motion()

func start_sleep_roll() -> void:
	concept_mode = "sleep"; concept_age = 0.0

func end_camp_pose() -> void:
	concept_mode = "idle"; concept_age = 0.0; sleep_blend = 0.0; rest_pose = ""
	supply_pour.cancel(); roast_pivot.hide(); _cup.hide(); _roasting_stick.hide()
	backpack.show(); head.position.z = 0.0; rig.rotation = Vector3.ZERO; _rest_weight = 0.0
	_show_pick_power_grip(false); reset_cape_motion()

func set_weapon(id: String) -> void:
	var model: String = MODEL_ALIASES.get(id, id)
	if model != weapon_id and model in TOOLS and arms.size() == 2:
		_tool_equip_age = 0.0; _tool_equip_starts.clear()
		for joint in arms + forearms + wrists: _tool_equip_starts.append(joint.quaternion)
	super.set_weapon(id)
	if tool_support_grip != null: _show_tool_support_grip(false)
	if _weapon_mount == null: return
	if (weapon_id in TOOLS or weapon_id in ["iron_blade", "dawn_blade"]):
		var frame = _approved_tool_frame()
		var palm = _grasp_frame(frame.y, Vector3.UP if weapon_id == "stone_pickaxe" else Vector3.BACK)
		_weapon_mount.basis = palm.inverse() * frame
		_weapon_mount.position = Vector3(0.06 + (MAIN_TOOL_GRIP_DISTANCE if weapon_id in TOOLS else 0.0), -0.105, 0.08)
	else:
		_weapon_mount.position = Vector3(0, -0.12, 0.12)
		_weapon_mount.basis = Basis(Vector3.BACK, PI * 0.5)
	if pick_power_grip != null and weapon_id not in TOOLS and weapon_id not in ["iron_blade", "dawn_blade"]: _show_pick_power_grip(false)

func set_held_item(id: String) -> void:
	super.set_held_item(id)
	if tool_support_grip != null and not held_item_id.is_empty(): _show_tool_support_grip(false)
	if id == "camp_kit" and _held_props.has(id): _held_props[id].get_child(0).scale = Vector3.ONE
	if pick_power_grip != null and not held_item_id.is_empty(): _show_pick_power_grip(false)

func _approved_tool_frame() -> Basis:
	if weapon_id in ["iron_blade", "dawn_blade"]: return _sword_ready_orientation()



	return Basis(Vector3.RIGHT, deg_to_rad(55)) * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) if weapon_id == "stone_pickaxe" else Basis(Vector3.BACK, -0.34) * Basis(Vector3.RIGHT, -0.25)

func _tool_ready_orientation() -> Basis:
	return _approved_tool_frame() if (weapon_id in TOOLS or weapon_id in ["iron_blade", "dawn_blade"]) else super._tool_ready_orientation()

func _mining_recovery_blocked(motion: String) -> bool:


	return motion in ["climb", "mantle", "swim", "beam", "hook"] or _hand_occupied() or dodge_progress >= 0.0 or not held_item_id.is_empty()

func _advance_pose(dt: float, motion: String, speed: float) -> void:
	_advance_pose_body(dt, motion, speed)
	_apply_grips()

func _advance_pose_body(dt: float, motion: String, speed: float) -> void:

	rig.position -= _flight_pivot_offset
	_flight_pivot_offset = Vector3.ZERO
	_support_grip_owned = false
	var working = attack_time > 0.0 and (weapon_id in TOOLS or weapon_id in ["iron_blade", "dawn_blade"])
	if _mining_recovery_blocked(motion) or (attack_time > 0.0 and not working): _mining_release = 0.0
	elif working: _mining_release = 0.2
	var released_frames: Array[Quaternion] = []
	if _mining_release > 0.0:
		for joint in arms + forearms + wrists: released_frames.append(joint.quaternion)
	performance.restore(self, motion)
	rig.basis = rig.basis.orthonormalized()
	_steps_before = _footsteps
	var saved_rest = rest_pose
	if concept_mode == "sleep_entry": rest_pose = ""
	super._advance_pose(dt, "walk" if concept_mode == "sleep_entry" and concept_age < 1.2 else motion, 1.6 if concept_mode == "sleep_entry" and concept_age < 1.2 else speed)
	rest_pose = saved_rest
	if pick_power_grip == null: return
	_show_pick_power_grip(false)
	var airborne_light := motion in ["seraph_hover", "seraph_fly", "seraph_glide", "seraph_boost"]
	_flight_pose_weight = move_toward(_flight_pose_weight, 1.0 if airborne_light else 0.0, dt * (1.6 if airborne_light else 3.0))
	if not airborne_light and _flight_pose_weight <= 0.001: _flight_pitch = 0.0; _flight_fist = 0.0
	if airborne_light:
		_show_tool_support_grip(false); roast_pivot.hide()
		_pose_seraph_flight(dt, motion, speed)
		_publish_feet()
		return
	if dodge_progress >= 0.0:
		_show_tool_support_grip(false)
		roast_pivot.hide()
		_show_pick_power_grip(_weapon_mount.visible and (weapon_id in TOOLS or weapon_id in ["iron_blade", "dawn_blade"]))
		_ensure_dodge_floor(); _publish_feet(); return
	roast_pivot.visible = not rest_pose.is_empty() and concept_mode == "roast"
	if not rest_pose.is_empty() and concept_mode != "idle":
		_show_tool_support_grip(false)
		concept_age += dt; _cup.hide(); _roasting_stick.hide()
		if concept_mode in ["sit", "roast", "coffee"]: _seated_pose(dt)
		elif concept_mode == "sleep": _sleep_pose(dt)
		_publish_feet(); return


	var running = _run > 0.001 and _locomotion > 0.001 and _grounded and motion not in ["climb", "mantle", "swim"]
	if running: _reference_run(dt, speed)
	var run_weight = smoothstep(0.0, 0.95, _run) * _locomotion if running else 0.0
	var carry_available = _tool_carry_available(motion)
	if carry_available:

		_tool_carry_weight = move_toward(_tool_carry_weight, 0.0 if motion == "run" else 1.0, dt * (4.0 if motion == "run" else 7.0))
	else: _tool_carry_weight = move_toward(_tool_carry_weight, 0.0, dt * 7.0)
	if _weapon_mount.visible and (weapon_id in TOOLS or weapon_id in ["iron_blade", "dawn_blade"]):
		grip_kind = weapon_id
		if attack_time <= 0.0: _correct_grip(dt, run_weight * _run_arm_blends[1])
		else: _show_pick_power_grip(true)
	elif _held_mount.visible and held_item_id in ["coffee", "camp_kit"]:
		grip_kind = held_item_id
		_correct_grip(dt, run_weight * _run_arm_blends[1])
	elif running and _held_mount.visible and not _held_supporting():
		_orient_palm(1, _held_mount.basis.inverse(), 1.0)
	if running and _grimoire.visible and not is_grimoire_casting():
		_orient_palm(0, torso.global_basis.orthonormalized().inverse() * global_basis.orthonormalized() * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), 1.0)
	performance.pose(self, dt, motion, speed)
	if carry_available and attack_time <= 0.0: _apply_tool_carry_support(_tool_carry_weight, dt)
	if _mining_recovery_blocked(motion): _mining_release = 0.0
	if _mining_release > 0.0 and not (attack_time > 0.0 and (weapon_id in TOOLS or weapon_id in ["iron_blade", "dawn_blade"])):


		_mining_release = maxf(0.0, _mining_release - dt)
		var joints = arms + forearms + wrists
		for i in range(joints.size()): joints[i].quaternion = released_frames[i].slerp(joints[i].quaternion, 1.0 - exp(-dt * 28.0))
	if _tool_equip_age < 0.3:
		if carry_available and attack_time <= 0.0:
			_tool_equip_age = minf(0.3, _tool_equip_age + dt)
			var joints = arms + forearms + wrists
			for i in range(joints.size()): joints[i].quaternion = _tool_equip_starts[i].slerp(joints[i].quaternion, smoothstep(0, 0.3, _tool_equip_age))
			_support_grip_owned = _support_grip_owned and _tool_equip_age >= 0.3
		else: _tool_equip_age = 0.3
	_show_tool_support_grip(_support_grip_owned)
	if _flight_pose_weight > 0.001 and bag_progress < 0.01 and rest_pose.is_empty(): _pose_seraph_flight(dt, motion, speed)
	_publish_feet()

func _pose_seraph_flight(dt: float, motion: String, speed: float) -> void:
	var weight := smoothstep(0.0, 1.0, _flight_pose_weight)
	var gliding := motion == "seraph_glide"
	var hovering := motion == "seraph_hover"
	var boosting := motion == "seraph_boost"
	_flight_fist = move_toward(_flight_fist, 1.0 if boosting else 0.0, dt * 7.0)
	var fist := smoothstep(0.0, 1.0, _flight_fist)
	var travel := clampf(speed / 22.0, 0.0, 1.0)
	var target_pitch := PI * 0.5 if boosting else (0.0 if hovering else PI * 0.25)
	_flight_pitch = move_toward(_flight_pitch, target_pitch, dt * 3.8)
	if weight <= 0.001: _flight_pitch = 0.0
	rig.rotation.x = lerp_angle(rig.rotation.x, -_flight_pitch, weight)
	torso.rotation.x = lerp_angle(torso.rotation.x, 0.0, weight)
	torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, weight)

	var pivot := Vector3(0, TORSO_PIVOT, 0)
	_flight_pivot_offset = (pivot - rig.basis * pivot) * weight
	_flight_pivot_offset.y += sin(time * (1.9 if hovering else 3.2)) * (0.085 if hovering else 0.018) * weight
	if hovering: torso.rotation.z = lerp_angle(torso.rotation.z, sin(time * 1.4) * 0.025, weight)
	rig.position += _flight_pivot_offset
	head.rotation.x = lerp_angle(head.rotation.x, _flight_pitch - 0.025, weight)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var arm := Vector3(0.13 if boosting else -0.12, side * 0.06, side * (0.15 if boosting else (0.4 + sin(time * 1.9) * 0.025 if hovering else 0.42)))
		arms[i].quaternion = arms[i].quaternion.slerp(Quaternion.from_euler(arm), weight)
		forearms[i].quaternion = forearms[i].quaternion.slerp(Quaternion.from_euler(Vector3(0.12, 0, 0)), weight)

		var inward := Vector3(-side, 0, 0)
		var forearm_frame := (arms[i].basis * forearms[i].basis).orthonormalized()
		var palm_up := forearm_frame.y.slide(inward).normalized()
		_orient_palm(i, Basis(palm_up.cross(inward).normalized(), palm_up, inward), weight)
		legs[i].quaternion = legs[i].quaternion.slerp(Quaternion.from_euler(Vector3((-0.09 if hovering else -0.035) + sin(time * 1.9 + i) * 0.016, 0, side * 0.045)), weight)
		knees[i].quaternion = knees[i].quaternion.slerp(Quaternion.from_euler(Vector3(0.32 if hovering else (0.06 if boosting else 0.16), 0, 0)), weight)
		feet[i].rotation.x = lerp_angle(feet[i].rotation.x, -0.16, weight)
		hands[i].set_pose(dt, lerpf(0.18, 1.05, fist), lerpf(0.22, 1.5, fist), lerpf(0.22, 0.85, fist), lerpf(0.12, 0.0, fist), 140.0)
	if _flight_pose_weight > 0.3:
		_weapon_mount.hide(); _held_mount.hide(); _grimoire.hide()

func _tool_carry_available(motion: String) -> bool:
	return weapon_id in TOOLS and _weapon_mount.visible and _grounded and motion in ["idle", "walk", "run"] and not _mining_recovery_blocked(motion) and float(_event_left.hurt) <= 0.0

func _apply_tool_carry_support(weight: float, dt: float) -> void:
	if weight <= 0.001: return
	var frame = torso.global_basis.orthonormalized().inverse() * _weapon_mount.global_basis.orthonormalized()
	var palm = frame * _weapon_mount.basis.inverse()
	var grasp = torso.to_local(_weapon_mount.to_global(Vector3.ZERO))
	var target = grasp - palm * TOOL_SUPPORT_OFFSET


	var upper = arms[0].quaternion; var lower = forearms[0].quaternion; var wrist = wrists[0].quaternion
	_solve_arm(0, target, 1.0, Vector3(-0.55, -0.4, 0.1))
	_orient_palm(0, palm, 1.0)
	arms[0].quaternion = upper.slerp(arms[0].quaternion, weight)
	forearms[0].quaternion = lower.slerp(forearms[0].quaternion, weight)
	wrists[0].quaternion = wrist.slerp(wrists[0].quaternion, weight)
	_support_grip_owned = weight > 0.5

func _ensure_dodge_floor() -> void:
	var low := INF
	for mesh in _dodge_surfaces:
		if not mesh.is_visible_in_tree(): continue
		var relative = global_transform.affine_inverse() * mesh.global_transform
		var box = mesh.mesh.get_aabb()
		for corner in range(8): low = minf(low, (relative * box.get_endpoint(corner)).y)
	if is_finite(low): rig.position.y += maxf(0, 0.035 - low)

func _publish_feet() -> void:
	_published_feet = [feet[0].global_position, feet[1].global_position]; _published_origin = global_position

func _seated_pose(dt: float) -> void:
	var sit = smoothstep(0.05, 1.1, concept_age)

	var seated_y = seat_height / MODEL_SCALE - 0.95
	rig.position = Vector3(0, lerpf(-0.045, seated_y, sit), 0)
	rig.rotation = Vector3.ZERO
	torso.rotation = Vector3(-0.035, 0, 0)
	head.rotation = Vector3(0.025, sin(concept_age * 0.75) * 0.025, 0)
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var foot = Vector3(side * 0.21, 0.085, lerpf(0.0, -0.57, sit))
		_foot_pitch[i] = 0.0; _solve_leg(i, foot, Vector3.UP, 1.0)

		var wrist_world = to_global(Vector3(side * 0.52, seat_height / MODEL_SCALE + 0.07, 0))
		var hand = torso.to_local(wrist_world)
		if concept_mode == "roast" and i == 1:
			var check_food = smoothstep(2.7, 3.2, concept_age) * (1.0 - smoothstep(3.65, 4.3, concept_age))
			hand = hand.lerp(Vector3(0.39, 0.05, -0.61), sit)
			hand = hand.lerp(Vector3(0.42, 0.16, -0.43), check_food)
		_solve_arm(i, hand, 1.0, Vector3(side * 0.38, -0.45, 0.12))
		var palm_down = torso.global_basis.orthonormalized().inverse() * global_basis.orthonormalized() * Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
		_orient_palm(i, palm_down, 1.0)
		if i == 0 or concept_mode == "sit" or (concept_mode == "coffee" and not supply_pour.active()):

			hands[i].set_pose(dt, 0.02, 0.025, 0.08, 0.15, 160.0)
	if concept_mode == "roast":
		_roast_pose(dt)
	if concept_mode == "coffee":

		supply_pour.pose(dt)

func _roast_pose(dt: float) -> void:
	var check_food = smoothstep(2.7, 3.2, concept_age) * (1.0 - smoothstep(3.65, 4.3, concept_age))

	var toward = (roast_hover_target - hands[1].global_position).normalized()
	var inspect_direction = (global_basis.orthonormalized() * Vector3(0.1, 0.66, -0.75)).normalized()
	var axis = toward.lerp(inspect_direction, check_food).normalized()
	var palm = _grasp_frame(axis, Vector3.UP)
	_orient_palm(1, torso.global_basis.orthonormalized().inverse() * palm, 1.0)
	var start = hands[1].to_global(Vector3(0, -0.115, 0.1))
	roast_pivot.global_position = start

	roast_pivot.global_basis = (Basis(Quaternion(Vector3.UP, axis)) * Basis(Vector3.UP, sin(concept_age * 1.7) * 0.65)).scaled_local(Vector3.ONE * MODEL_SCALE)
	hands[1].set_pose(dt, 0.95, 1.5, 0.8, 0, 140)
	toast_material.albedo_color = Color("#f1e7d2").lerp(Color("#bf8752"), smoothstep(0.8, 4.3, concept_age) * 0.7)
	head.rotation.x = lerpf(0.025, 0.12, check_food)

func _sleep_pose(dt: float) -> void:

	var kneel = smoothstep(0.0, 0.85, concept_age)
	var lie = smoothstep(1.2, 2.9, concept_age)
	sleep_blend = lie
	var bend = lerpf(0.0, 0.42, kneel) * (1.0 - lie)
	rig.rotation = Vector3(lerpf(0.0, PI * 0.5, lie), 0, 0)
	rig.position = Vector3(0, lerpf(lerpf(-0.045, -0.52, kneel), 0.79, lie), lerpf(0.0, -0.27, lie))
	torso.rotation = Vector3(-bend, 0, 0)
	head.rotation = Vector3(bend * 0.4, 0, 0)
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var kneel_target = Vector3(side * 0.22, 0.085, -0.37 if i == 0 else 0.1)
		var standing = Vector3(side * 0.19, 0.085, 0)
		var folded = Vector3(side * 0.21, 0.14, -0.3 if i == 0 else -0.16)
		var target = standing.lerp(kneel_target, kneel).lerp(rig.transform * folded, lie)
		_foot_pitch[i] = 0; _solve_leg(i, target, Vector3.UP, 1.0 - lie)
		var brace = Vector3(side * 0.53, -0.37, -0.32)
		var folded_hand = Vector3(side * 0.22, 0.17, -0.43)
		_solve_arm(i, brace.lerp(folded_hand, lie), 1.0, Vector3(side * 0.35, -0.48, 0.08))
		_orient_palm(i, Basis.IDENTITY, 1.0)
		hands[i].set_pose(dt, 0.2, 0.32, 0.18, 0, 25)
	backpack.visible = concept_age < 0.9


func _correct_grip(dt: float, run_weight: float = 0.0) -> void:
	var tool = grip_kind in TOOLS or grip_kind in ["iron_blade", "dawn_blade"]
	var supporting = _held_supporting() and not tool
	var two = _held_two_hands()
	var palm = Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP) if supporting else Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT)
	var tool_frame = Basis.IDENTITY
	if tool:

		tool_frame = _approved_tool_frame()
		palm = _grasp_frame(tool_frame.y, Vector3.UP if grip_kind == "stone_pickaxe" else Vector3.BACK)
	var hand = Vector3(0.3, -0.17, -0.68) if two else Vector3(0.56, -0.05, -0.44) if tool or grip_kind == "coffee" else Vector3(0.54, -0.12, -0.53)
	if grip_kind == "stone_pickaxe": hand = Vector3(0.58, 0, -0.58)
	if grip_kind in TOOLS:
		hand = hand.lerp(Vector3(0.28, 0.38, -0.45), _tool_carry_weight)

		hand += torso.global_basis.orthonormalized().inverse() * global_basis.orthonormalized() * tool_frame.y * MAIN_TOOL_GRIP_DISTANCE


	_solve_arm(1, hand, 1.0 - run_weight * (1.0 - _tool_carry_weight), Vector3(0.55, -0.45, 0.1))
	var frame_to_torso = torso.global_basis.orthonormalized().inverse() * global_basis.orthonormalized()
	_orient_palm(1, frame_to_torso * palm, 1.0)

	var object_basis = Basis.IDENTITY
	if tool:
		_weapon_mount.basis = palm.inverse() * tool_frame

		_weapon_mount.position = Vector3(0.06 + (MAIN_TOOL_GRIP_DISTANCE if weapon_id in TOOLS else 0.0), -0.105, 0.08)
		hands[1].set_pose(dt, 1.05 if grip_kind == "stone_pickaxe" else 0.95, 1.5, 0.8, 0, 160)
		_show_pick_power_grip(true)
		return
	_held_mount.basis = palm.inverse() * object_basis
	var floor = _prop_floor(_held_props[held_item_id]) if supporting and _held_props.has(held_item_id) else 0.0
	_held_mount.position = Vector3(0, 0, 0.075 - floor) if supporting else Vector3(0, -0.115, 0.11) if grip_kind == "coffee" else Vector3(0, -0.13, 0.12)
	if two:
		_solve_arm(0, Vector3(-0.3, -0.17, -0.68), 1.0, Vector3(-0.55, -0.45, 0.1))
		_orient_palm(0, frame_to_torso * palm, 1.0)
		hands[0].set_pose(dt, 0.42, 0.55, 0.3, 0, 40)
		var center = (hands[0].global_position + hands[1].global_position) * 0.5 + global_basis.y * (0.075 - floor) + global_basis.z * 0.063
		_held_mount.position = hands[1].to_local(center)
	hands[1].set_pose(dt, 0.42 if supporting else 0.95, 0.55 if supporting else 1.5, 0.3 if supporting else 0.8, 0, 140 if grip_kind == "coffee" else 40)

func _build_pick_power_grip() -> void:
	var hand = hands[1]
	for joint in hand.knuckles + [hand.thumb_base]:
		for mesh in joint.find_children("*", "MeshInstance3D", true, false): ordinary_digit_meshes.append(mesh)
	pick_power_grip = Node3D.new(); pick_power_grip.name = "PickaxePowerGrip"; hand.add_child(pick_power_grip)
	var silver = B.surface("silver", "#ccd3d6", 0.78)
	var light = B.surface("silver", "#eff1f2", 0.78)
	var dark = B.mat("#29393d", 0.55)
	for i in range(3):
		var finger = Node3D.new(); finger.name = "Finger" + str(i); pick_power_grip.add_child(finger)
		var x = -0.075 + i * 0.075
		var points = [Vector3(x, -0.09, -0.005), Vector3(x, -0.154, 0.057), Vector3(x, -0.146, 0.122), Vector3(x, -0.071, 0.112)]
		for j in range(3):
			_pick_grip_link(finger, points[j], points[j + 1], [0.051, 0.047, 0.044][j], [0.044, 0.04, 0.02][j], light if j == 0 else silver, "Segment" + str(j))
		for j in range(3): B.ball(finger, points[j], Vector3.ONE * [0.052, 0.04, 0.032][j], dark).name = "Joint" + str(j)
	var thumb = Node3D.new(); thumb.name = "Thumb"; pick_power_grip.add_child(thumb)
	var t = [Vector3(-0.13, -0.015, 0.058), Vector3(-0.13, -0.0565, 0.086), Vector3(-0.02, -0.0565, 0.086)]
	_pick_grip_link(thumb, t[0], t[1], 0.044, 0.04, light, "Proximal")
	_pick_grip_link(thumb, t[1], t[2], 0.046, 0.042, silver, "OpposingPad")
	B.ball(thumb, t[0], Vector3.ONE * 0.05, dark)
	B.ball(thumb, t[1], Vector3.ONE * 0.044, dark)
	for mesh in pick_power_grip.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 4; _dodge_surfaces.append(mesh)
	pick_power_grip.hide()

func _pick_grip_link(parent: Node3D, a: Vector3, b: Vector3, width: float, depth: float, material: Material, label: String) -> void:
	var mesh = B.beveled_box(parent, (a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material)
	mesh.name = label; mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _show_pick_power_grip(active: bool) -> void:
	_pick_grip_want = active

func _build_tool_support_grip() -> void:
	for joint in hands[0].knuckles + [hands[0].thumb_base]:
		for mesh in joint.find_children("*", "MeshInstance3D", true, false): ordinary_support_digits.append(mesh)
	tool_support_grip = MeshInstance3D.new(); tool_support_grip.name = "ToolSupportGrip"
	tool_support_grip.mesh = load("res://assets/equipment/tool_support_grip.res")
	tool_support_grip.layers = 4; tool_support_grip.hide(); hands[0].add_child(tool_support_grip)
	_dodge_surfaces.append(tool_support_grip)

func _show_tool_support_grip(active: bool) -> void:
	_support_grip_want = active

## Show the gripping hand or the ordinary fingers, touching the meshes only on a change.
func _apply_grips() -> void:
	if pick_power_grip != null and pick_power_grip.visible != _pick_grip_want:
		pick_power_grip.visible = _pick_grip_want
		for mesh in ordinary_digit_meshes: mesh.visible = not _pick_grip_want
	if tool_support_grip != null and tool_support_grip.visible != _support_grip_want:
		tool_support_grip.visible = _support_grip_want
		for mesh in ordinary_support_digits: mesh.visible = not _support_grip_want

func _grasp_frame(shaft: Vector3, across: Vector3) -> Basis:
	var x = -shaft.normalized()
	var y = across.slide(x).normalized()
	if y.length_squared() < 0.1: y = Vector3.UP.slide(x).normalized()
	var z = x.cross(y).normalized()
	return Basis(x, z.cross(x).normalized(), z)

func begin_supply_pour(id: String) -> bool:
	var begun = super.begin_supply_pour(id)
	if begun and id == "coffee":
		var palm = Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT)
		supply_pour._grip_basis = palm.inverse()
		supply_pour.vessel_mount.basis = supply_pour._grip_basis
		supply_pour.vessel_mount.position = Vector3(0, -0.115, 0.11)
	return begun

func _curve(keys: Array, p: float) -> Vector3:
	for i in range(keys.size() - 1):
		if p <= float(keys[i + 1][0]):
			var t = smoothstep(float(keys[i][0]), float(keys[i + 1][0]), p)
			return (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
	return keys[-1][1]

func _reference_run(dt: float, speed: float) -> void:
	var weight = smoothstep(0.0, 0.95, _run) * _locomotion
	var arm_weights = []
	for i in range(2):
		var available = _run_arm_available(i)


		_run_arm_blends[i] = minf(_run_arm_blends[i], available)
		_run_arm_blends[i] = move_toward(_run_arm_blends[i], available, dt * 7.0)
		arm_weights.append(weight * _run_arm_blends[i])
	var body_weight = 0.0 if _run_body_owned() else weight
	var base_rig = rig.transform; var base_torso = torso.quaternion; var base_head = head.quaternion
	var base_feet = [feet[0].global_position, feet[1].global_position]
	var book_start = torso.to_local(hands[0].global_position)
	var base_pitch = _foot_pitch.duplicate(); var upper = []; var lower = []; var wrist = []
	for i in range(2): upper.append(arms[i].quaternion); lower.append(forearms[i].quaternion); wrist.append(wrists[i].quaternion)
	var previous_cycle = run_cycle
	_approved_reference_run(dt, speed, arm_weights)
	var book_target = torso.to_local(hands[0].global_position)
	var target_feet = [feet[0].global_position, feet[1].global_position]; var target_pitch = _foot_pitch.duplicate()
	var target_origin = rig.position; var target_rotation = rig.basis.orthonormalized().get_rotation_quaternion()
	rig.position = base_rig.origin.lerp(target_origin, body_weight)
	rig.quaternion = base_rig.basis.orthonormalized().get_rotation_quaternion().slerp(target_rotation, body_weight).normalized()
	torso.quaternion = base_torso.slerp(torso.quaternion, body_weight); head.quaternion = base_head.slerp(head.quaternion, body_weight)
	var normal = global_basis.orthonormalized().inverse() * _floor_normal
	for i in range(2):
		arms[i].quaternion = upper[i].slerp(arms[i].quaternion, arm_weights[i])
		forearms[i].quaternion = lower[i].slerp(forearms[i].quaternion, arm_weights[i])
		wrists[i].quaternion = wrist[i].slerp(wrists[i].quaternion, arm_weights[i])
		_foot_pitch[i] = lerpf(base_pitch[i], target_pitch[i], weight)
		var world_target: Vector3 = base_feet[i].lerp(target_feet[i], weight)
		if _published_feet.size() == 2 and global_position.distance_to(_published_origin) < 1.0: world_target = _published_feet[i].move_toward(world_target, dt * 9.0)
		var target = to_local(world_target)
		target.y = maxf(target.y, _run_floor_height(target, normal, _foot_pitch[i]))
		_solve_leg(i, target, normal, 1.0)
		_foot_positions[i] = to_local(feet[i].global_position); _foot_world_positions[i] = feet[i].global_position
		if weight > 0.95: _foot_planted[i] = fposmod(run_cycle + i * 0.5, 1.0) < REFERENCE_RUN_STANCE
	if _grimoire.visible and not is_grimoire_casting():


		var book_hand = book_start.lerp(book_target, arm_weights[0])
		var outside = lerpf(book_target.x, minf(book_target.x, -0.68), smoothstep(-0.62, -0.43, book_target.z))
		book_hand.x = lerpf(book_start.x, outside, smoothstep(0, 0.4, arm_weights[0]))
		book_hand.z = lerpf(minf(book_start.z, -0.5), book_target.z, smoothstep(0.4, 0.8, arm_weights[0]))
		var pole = torso.to_local(forearms[0].global_position) - arms[0].position
		_solve_arm(0, book_hand, 1.0, pole, 0.0)
	if weight > 0.95:
		phase = run_cycle * TAU; _footsteps = _steps_before
		if floori(run_cycle * 2) != floori(previous_cycle * 2): _footsteps += 1

func _run_arm_available(i: int) -> float:
	if attack_time > 0.0 or carry_pose or is_throwing() or bag_progress > 0.01 or bag_target > 0.01 or is_grimoire_casting(): return 0.0
	if _held_mount.visible and (_held_two_hands() or (i == 1 and _held_supporting())): return 0.0
	if i == 1:
		if supply_pour.active() or grapple.active(): return 0.0


		if maxf(maxf(aim_weight, charge_weight), maxf(_weights.beam, _weights.hook)) > 0.001: return 0.0
	return 1.0

func _run_body_owned() -> bool:
	return attack_time > 0.0 or carry_pose or is_throwing() or bag_progress > 0.01 or bag_target > 0.01 or is_grimoire_casting() or supply_pour.active() or grapple.active() or maxf(maxf(aim_weight, charge_weight), maxf(_weights.beam, _weights.hook)) > 0.001

func _run_floor_height(foot: Vector3, normal: Vector3, pitch: float) -> float:
	var floor_basis = Basis.looking_at(Vector3.FORWARD.slide(normal).normalized(), normal) * Basis(Vector3.RIGHT, pitch)
	var sole = minf(normal.dot(floor_basis * Vector3(0, -0.085, -0.35)), normal.dot(floor_basis * Vector3(0, -0.085, 0.09)))
	return -(normal.x * foot.x + normal.z * foot.z + sole) / maxf(0.1, normal.y)

const RUN_RECOVERY := [
	[0.2, Vector3(0, 0.221, 0.45), Vector3(0, 0, 4.45)],
	[0.34, Vector3(0, 0.43, 0.51), Vector3(0, 1.0, -2.0)],
	[0.53, Vector3(0, 0.49, 0.08), Vector3(0, -0.2, -3.2)],
	[0.76, Vector3(0, 0.29, -0.51), Vector3(0, -1.4, -1.6)],
	[0.9, Vector3(0, 0.19, -0.55), Vector3(0, -1.0, 0.2)],
	[1.0, Vector3(0, 0.126, -0.44), Vector3(0, 0, 4.45)]]
const RUN_BODY := [[0.0, Vector3(0, -0.165, 0)], [0.2, Vector3(0, -0.19, 0)], [0.4, Vector3(0, -0.18, 0)], [0.75, Vector3(0, -0.1, 0)], [1.0, Vector3(0, -0.165, 0)]]

func _run_recovery(p: float) -> Vector3:


	for i in range(RUN_RECOVERY.size() - 1):
		var a = RUN_RECOVERY[i]; var b = RUN_RECOVERY[i + 1]
		if p > float(b[0]): continue
		var span = float(b[0]) - float(a[0]); var t = clampf((p - float(a[0])) / span, 0, 1)
		return a[1] * (2 * t * t * t - 3 * t * t + 1) + a[2] * span * (t * t * t - 2 * t * t + t) + b[1] * (-2 * t * t * t + 3 * t * t) + b[2] * span * (t * t * t - t * t)
	return RUN_RECOVERY[-1][1]

func _approved_reference_run(dt: float, speed: float, arm_weights: Array) -> void:


	run_cycle = fposmod(run_cycle + dt / REFERENCE_RUN_DURATION * maxf(0, speed) / 3.8, 1.0)
	var beat = fposmod(run_cycle * 2.0, 1.0)
	var body_y = _curve(RUN_BODY, beat).y
	rig.position = Vector3(sin(run_cycle * TAU) * 0.012, body_y, 0)
	rig.rotation = Vector3(0, sin(run_cycle * TAU) * 0.025, 0)
	torso.rotation = Vector3(-0.085, -sin(run_cycle * TAU) * 0.045, 0)
	head.rotation = Vector3(0.04, sin(run_cycle * TAU) * 0.014, 0)
	var normal = global_basis.orthonormalized().inverse() * _floor_normal
	var targets = []
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var p = fposmod(run_cycle + i * 0.5, 1.0)
		var foot = _run_recovery(p); foot.x = side * 0.19
		if p < REFERENCE_RUN_STANCE:

			foot.z = lerpf(-0.44, 0.45, p / REFERENCE_RUN_STANCE)
			_foot_pitch[i] = lerpf(0.12, -0.42, smoothstep(0.02, REFERENCE_RUN_STANCE, p))
			foot.y = _run_floor_height(foot, normal, _foot_pitch[i])
		else:
			_foot_pitch[i] = lerpf(-0.42, 0.12, smoothstep(0.23, 0.94, p))
			foot.y = maxf(foot.y - (normal.x * foot.x + normal.z * foot.z) / maxf(0.1, normal.y), _run_floor_height(foot, normal, _foot_pitch[i]))
		targets.append(foot)
	for i in range(2):
		var p = fposmod(run_cycle + i * 0.5, 1.0)
		if p >= REFERENCE_RUN_STANCE: continue
		var hip = to_local(legs[i].global_position)
		var horizontal = Vector2(hip.x - targets[i].x, hip.z - targets[i].z).length_squared()
		var maximum_y = targets[i].y + sqrt(maxf(0.001, pow((THIGH_LENGTH + SHIN_LENGTH) * 0.96, 2) - horizontal))
		if hip.y > maximum_y: rig.position.y -= hip.y - maximum_y
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var p = fposmod(run_cycle + i * 0.5, 1.0)
		var foot: Vector3 = targets[i]
		_solve_leg(i, foot, normal, 1.0)

		var abduction = 0.075
		if i == 0 and _grimoire.visible: abduction = 0.4
		elif i == 1 and _weapon_mount.visible and weapon_id in ["iron_blade", "dawn_blade"]: abduction = 0.22
		arms[i].rotation = Vector3(0.1 - cos(p * TAU) * 0.66, 0, side * abduction)
		forearms[i].rotation = Vector3(1.08 + cos(p * TAU) * 0.12, 0, 0)
		wrists[i].rotation = Vector3(0, -side * PI * 0.5, 0)
		var holding = (_grimoire.visible and i == 0) or (i == 1 and (_weapon_mount.visible or _held_mount.visible))
		if arm_weights[i] > 0.01 and not holding: hands[i].set_pose(dt, 0.25, 0.4, 0.25, 0, 32 * arm_weights[i])

func _capture_strike_start() -> void:
	super._capture_strike_start()



	if weapon_id in TOOLS: _strike_origins[1] -= _strike_start_tool.y * MAIN_TOOL_GRIP_DISTANCE
	_tool_arm_starts.clear()
	_tool_arm_rolls.assign([0.0, 0.0, 0.0, 0.0])
	_tool_applied_rolls.assign([0.0, 0.0, 0.0, 0.0])
	for i in range(arms.size()):
		_tool_arm_starts.append(arms[i].basis.orthonormalized())
		_tool_arm_starts.append((arms[i].basis * forearms[i].basis).orthonormalized())
	_support_wrist_roll = 0.0
	_support_palm_start = rig.global_basis.orthonormalized().inverse() * hands[0].global_basis.orthonormalized()
	_support_palm_previous = hands[0].global_basis.orthonormalized()

func _tool_hand_target(age: float) -> Vector3:
	var target = super._tool_hand_target(age)
	var phase_key = _work_phase(age)


	if weapon_id == "stone_pickaxe":
		if phase_key.x < 0.5: target.z -= 0.18 * (1.0 - phase_key.y)
		else: target.z -= 0.18 * smoothstep(strike_contact(weapon_id, _strike_variant) + 0.28, _strike_duration, age)
	return target

func _solve_tool_arm(i: int, target: Vector3, weight: float) -> void:
	if i == 1 and weapon_id in TOOLS:
		var age = _strike_duration - attack_time
		var frame = _strike_start_tool.slerp(_tool_orientation(age), _tool_envelope(age))
		var axis = torso.basis.orthonormalized().inverse() * frame.y
		target += axis * MAIN_TOOL_GRIP_DISTANCE



		var main = arms[1].position
		var support = arms[0].position + axis * (0.12 + MAIN_TOOL_GRIP_DISTANCE)
		var one = ArmReach.project(target, main, main, WORKING_REACH)
		var both = ArmReach.project(target, main, support, WORKING_REACH)
		var support_weight = weight * smoothstep(0, 0.16, age) if weapon_id == "stone_pickaxe" else weight
		target = one.lerp(both, support_weight)
	_solve_working_arm(i, target, weight)

func _solve_sword_arm(i: int, target: Vector3, weight: float) -> void:
	target = ArmReach.project(target, arms[i].position, arms[i].position, WORKING_REACH)
	target = _extended_impact_target(i, target, _work_phase(_strike_duration - attack_time))
	_solve_working_arm(i, target, weight, 0.87)

func _solve_working_arm(i: int, target: Vector3, weight: float, maximum_reach: float = 0.865) -> void:
	if _tool_arm_starts.size() != 4:
		_solve_arm(i, target, 1.0, Vector3.INF, 1.0, maximum_reach)
		return



	var side = -1.0 if i == 0 else 1.0
	var start_upper = _tool_arm_starts[i * 2]
	var start_lower = _tool_arm_starts[i * 2 + 1]
	var pole = (-start_upper.y).lerp(Vector3(side * 0.35, -0.55, 0.25), weight)
	_solve_arm(i, target, 1.0, pole, 1.0, maximum_reach)
	var upper = arms[i].basis.orthonormalized()
	var lower = (upper * forearms[i].basis).orthonormalized()



	var transported_upper = Basis(Quaternion(start_upper.y, upper.y)) * start_upper
	var transported_lower = Basis(Quaternion(start_lower.y, lower.y)) * start_lower
	upper = _tool_hinge_frame(i * 2, transported_upper, upper, weight)
	lower = _tool_hinge_frame(i * 2 + 1, transported_lower, lower, weight)
	arms[i].basis = upper
	forearms[i].basis = upper.inverse() * lower

func _tool_hinge_frame(index: int, transported: Basis, hinge: Basis, weight: float) -> Basis:


	var across = transported.x.slide(hinge.y).normalized()
	transported = Basis(across, hinge.y, across.cross(hinge.y).normalized())


	var roll = atan2(hinge.y.dot(transported.x.cross(hinge.x)), transported.x.dot(hinge.x))
	roll = _tool_arm_rolls[index] + angle_difference(_tool_arm_rolls[index], roll)
	_tool_arm_rolls[index] = roll


	_tool_applied_rolls[index] = move_toward(_tool_applied_rolls[index], roll * weight, STEP * 24.0)
	return Basis(hinge.y, _tool_applied_rolls[index]) * transported

func _apply_tool_support(age: float, weight: float) -> void:
	var mining = weapon_id in ["stone_pickaxe", "stone_hammer"]


	if mining: weight *= smoothstep(0.0, 0.16, age)
	_support_grip_owned = weight > 0.5


	_support_wrist_roll = 0.0
	var tool_basis = torso.global_basis.orthonormalized().inverse() * _weapon_mount.global_basis.orthonormalized()
	var palm_basis = tool_basis * _weapon_mount.basis.inverse()
	var grasp = torso.to_local(_weapon_mount.global_position)
	var wrist = grasp - palm_basis * TOOL_SUPPORT_OFFSET


	var start = torso.transform.affine_inverse() * (_strike_origins[0] + Vector3.UP * TORSO_PIVOT)
	_solve_tool_arm(0, start.lerp(wrist, weight), weight)
	var start_basis = torso.basis.orthonormalized().inverse() * _support_palm_start
	var desired = torso.global_basis.orthonormalized() * start_basis.slerp(palm_basis, weight)
	if weight < 0.999:


		var previous = _support_palm_previous.get_rotation_quaternion()
		var target_rotation = desired.get_rotation_quaternion()
		var turn = previous.angle_to(target_rotation)
		desired = Basis(previous.slerp(target_rotation, minf(1.0, STEP * 60.0 / maxf(0.001, turn))))
	_support_palm_previous = desired
	_orient_palm(0, torso.global_basis.orthonormalized().inverse() * desired, 1.0)

func _apply_grimoire_pose(dt: float) -> void:
	super._apply_grimoire_pose(dt)
	if _run * _locomotion < 0.001: return


	var p = 1.0 - _grimoire_left / _grimoire_duration
	var palm = hands[0].global_basis.orthonormalized()
	var target = torso.to_local(hands[0].global_position)
	target.z -= 0.08 * _run * _locomotion * smoothstep(0.02, 0.12, p)
	_solve_arm(0, target, 1.0)
	_orient_palm(0, torso.global_basis.orthonormalized().inverse() * palm, 1.0)
