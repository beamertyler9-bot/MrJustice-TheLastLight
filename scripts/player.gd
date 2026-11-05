extends CharacterBody3D

const Hero = preload("res://scripts/hero_visual.gd")
const Mantle = preload("res://scripts/mantle.gd")
const Crafting = preload("res://scripts/crafting.gd")
const HERO_HEIGHT: float = Hero.STANDING_HEIGHT_METRES
const HERO_RATIO: float = Hero.MODEL_SCALE / 0.75
const BODY_RADIUS: float = 0.28 * HERO_RATIO
const WALK_SPEED: float = 1.9
const RUN_SPEED: float = 3.8
const CARRY_SPEED: float = 1.65
const DODGE_DURATION: float = 0.62
const DODGE_COOLDOWN: float = 0.8
const DODGE_SPEED: float = 6.4
var state
var world
var game
var control_move: Vector2 = Vector2.ZERO
var sprinting: bool = false
var held_body: RigidBody3D
var throw_pending: bool = false
var visual: Node3D
var camera: Camera3D
var yaw: float = 0.0
var pitch: float = 0.18
var camera_distance: float = 3.5
const DEFAULT_CAMERA_DISTANCE := 3.5
const CAMERA_IDLE_DELAY := 3.0
var zoom_target: float = DEFAULT_CAMERA_DISTANCE
var camera_idle: float = 0.0
var ability_aiming: bool = false
var aim_blend: float = 0.0
var active: bool = true
var climbing: bool = false
var swimming: bool = false
var climb_normal: Vector3 = Vector3.BACK
var climb_surface_normal: Vector3 = Vector3.ZERO
var climb_surface: WeakRef
var terrain_climb_normal: Vector3 = Vector3.ZERO
var hit_cooldown: float = 0.0
var attack_cooldown: float = 0.0
var ability_cooldown: float = 0.0
var ability_id: String = "beam"
var cast_time: float = 0.0
var hook_target: Vector3 = Vector3.ZERO
var hooking: float = 0.0
var mantle_time: float = 0.0
var mantle_start: Vector3
var mantle_end: Vector3
var mantle_lift: Vector3
var closest: Node3D
var motion: String = "idle"
var foot_time: float = 0.0
var bag_yaw: float = 0.0
var last_vertical: float = 0.0
var coyote: float = 0.0
var swim_jump_time: float = 0.0
var jump_buffer: float = 0.0
var jump_lock: float = 0.0
var melee_contact: float = -1.0
var combo_step: int = -1
var combo_timer: float = 0.0
var queued_strike: bool = false
var strike_duration: float = 0.0
var strike_facing: Vector3 = Vector3.ZERO
var magic_contact: float = -1.0
var camera_trauma: float = 0.0
var landing_offset: float = 0.0
var camera_clock: float = 0.0
# Camera feel: a smoothed pivot (lags vertically in the air), travel look-ahead,
# collision distance that snaps in and eases out, organic shake and directional kicks.
var _interaction_clock := 0.0
const LOCK_RANGE := 30.0
var cam_mode := -1
var cam_blend := 0.0
var cam_blend_from := Transform3D.IDENTITY
var cam_pivot := Vector3.ZERO
var cam_pivot_ready := false
var cam_length := -1.0
var cam_lookahead := Vector3.ZERO
var cam_kick := Vector3.ZERO
var cam_noise: FastNoiseLite
const CAMERA_FOLLOW_DELAY := 1.4
var hook_rope: MeshInstance3D
var hook_anchor: WeakRef
var hook_local_point: Vector3
var hook_local_normal: Vector3
var hook_point: Vector3
var hook_normal: Vector3
var hook_gripped: bool = false
var beam_contact: float = -1.0
var beam_target: Vector3
var beam_paid: float = 0.0
var beam_power: float = 0.0
var beam_aim_toggled: bool = false
var beam_charging: bool = false
var beam_charge: float = 0.0
var climb_detach: float = 0.0
var charge_vfx: Node3D
var charge_glow: MeshInstance3D
var charge_glow_material: ShaderMaterial
var shadow: MeshInstance3D
var shadow_material: ShaderMaterial
var dodge_time: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var lock_target: Node3D
var lock_occlusion: float = 0.0
var last_grounded_position: Vector3 = Vector3.ZERO

func setup(data, terrain) -> void:
	state = data
	world = terrain

func _ready() -> void:
	last_grounded_position = state.checkpoint if state != null else global_position
	collision_layer = 2
	collision_mask = 1 | 8
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(49)
	var c = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = HERO_HEIGHT
	c.shape = capsule
	c.position.y = HERO_HEIGHT * 0.5 + 0.01
	add_child(c)
	visual = Hero.new()
	add_child(visual)
	charge_vfx = Node3D.new()
	visual.hands[1].add_child(charge_vfx)
	for i in range(3):
		var ring = preload("res://scripts/build.gd").ring(charge_vfx, Vector3(0, 0, 0.08 + i * 0.02), 0.07 + i * 0.015, 0.009, preload("res://scripts/build.gd").mat("#9cfff0", 0, 0.8))
		ring.rotation.x = PI * 0.5
		ring.layers = 1 << 3
	# A toon glow that swells in the palm while the beam charges.
	charge_glow_material = ShaderMaterial.new(); charge_glow_material.shader = preload("res://shaders/magic/halo.gdshader")
	charge_glow_material.set_shader_parameter("body_color", Color("4fe3d0")); charge_glow_material.set_shader_parameter("rim_color", Color("9cfff0"))
	charge_glow_material.set_shader_parameter("core_color", Color("f0fffb")); charge_glow_material.set_shader_parameter("family", 4.0)
	charge_glow = MeshInstance3D.new(); charge_glow.name = "ChargeGlow"
	var glow_quad := QuadMesh.new(); glow_quad.size = Vector2.ONE; charge_glow.mesh = glow_quad
	charge_glow.material_override = charge_glow_material; charge_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	charge_glow.layers = 1 << 3; charge_glow.top_level = true
	charge_vfx.add_child(charge_glow)
	charge_vfx.visible = false
	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 62
	camera.near = 0.08
	camera.far = 14000 if state != null and state.get("expanded_world") == true else 220
	camera.current = true
	add_child(camera)
	visual.aim_camera = camera
	add_to_group("player")
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = load("res://shaders/contact_shadow.gdshader")
	shadow = MeshInstance3D.new()
	shadow.mesh = PlaneMesh.new()
	shadow.material_override = shadow_material
	shadow.top_level = true
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.scale = Vector3(0.78 * HERO_RATIO, 1, 0.56 * HERO_RATIO)
	add_child(shadow)
	update_camera(1.0)

func clear_controls(cancel_supply: bool = true) -> void:
	cancel_magic()
	cancel_dodge()
	clear_lock_on()
	cancel_primary_action()
	cancel_beam()
	finish_hook(true)
	end_ability_aim(false)
	aim_blend = 0.0
	control_move = Vector2.ZERO
	sprinting = false
	velocity.x = 0
	velocity.z = 0
	jump_buffer = 0
	melee_contact = -1
	queued_strike = false
	camera_trauma = 0
	throw_pending = false
	if visual != null:
		if cancel_supply: visual.supply_pour.cancel()
		visual.cancel_throw()
		visual.aim_weight = 0.0

func supply_speed_multiplier() -> float:
	return 0.8 if visual != null and visual.supply_pour.active() else 1.0

func _physics_process(dt: float) -> void:
	if not active or state == null or world == null:
		cancel_dodge()
		clear_lock_on()
		forward_climb_context()
		return
	dodge_cooldown = maxf(0.0, dodge_cooldown - dt)
	if dodge_time > 0.0:
		dodge_time = maxf(0.0, dodge_time - dt)
		if dodge_time <= 1.0e-06 or dodge_hands_busy():
			cancel_dodge()
	update_lock_on(dt)
	hit_cooldown = maxf(0, hit_cooldown - dt)
	attack_cooldown = maxf(0, attack_cooldown - dt)
	ability_cooldown = maxf(0, ability_cooldown - dt)
	cast_time = maxf(0, cast_time - dt)
	swim_jump_time = maxf(0, swim_jump_time - dt)
	jump_buffer = maxf(0, jump_buffer - dt)
	jump_lock = maxf(0, jump_lock - dt)
	climb_detach = maxf(0, climb_detach - dt)
	combo_timer = maxf(0, combo_timer - dt)
	if magic_contact >= 0.0:
		if not visual.is_grimoire_casting() or climbing or swimming or mantle_time > 0.0 or hooking > 0.0 or is_instance_valid(held_body) or visual.is_throwing():
			cancel_magic()
		else:
			magic_contact -= dt
			if magic_contact <= 0.0:
				magic_contact = -1.0
				var runtime = magic_runtime()
				if runtime != null:
					if runtime.release():
						camera_trauma = minf(0.24, camera_trauma + 0.1)
						feel_rumble(14, 0.3)
					elif runtime.get("last_release_error") is String and not str(runtime.last_release_error).is_empty():
						toast(str(runtime.last_release_error))
	if melee_contact >= 0:
		melee_contact -= dt
		if melee_contact <= 0:
			melee_contact = -1
			resolve_melee()
	if queued_strike and attack_cooldown <= 0:
		queued_strike = false
		attack()
	var stick = movement_input()
	var move = Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, yaw)
	if mantle_time > 0:
		var before = 1.0 - mantle_time / Mantle.DURATION
		mantle_time = maxf(0, mantle_time - dt)
		var progress = 1.0 - mantle_time / Mantle.DURATION


		var clear = true
		if before < Mantle.LIFT_PORTION and progress > Mantle.LIFT_PORTION:
			clear = Mantle.step_is_clear(self, global_position, mantle_lift)
			if clear:
				global_position = mantle_lift
		var next = Mantle.path_position(mantle_start, mantle_lift, mantle_end, progress)
		if clear and Mantle.step_is_clear(self, global_position, next):
			global_position = next
		else:
			mantle_time = 0
		velocity = Vector3.ZERO
		motion = "mantle" if mantle_time > 0 else "idle"
		visual.mantle_progress = progress if mantle_time > 0 else -1.0
		if mantle_time <= 0:
			visual.mantle_contacts.clear()
		state.player_position = global_position
		world.stream_at(global_position)
		return
	var dry_interior = world.has_method("interior_at") and world.interior_at(global_position) != ""
	swimming = not dry_interior and swim_jump_time <= 0 and global_position.y < _water_height() - 0.25 and world.height_at(global_position.x, global_position.z) < _water_height() - 1.2
	if swimming and dodge_time > 0.0:
		cancel_dodge()
	if dodge_time <= 0.0 and not climbing and hooking <= 0 and not swimming and move.length() > 0.15 and not ability_aiming and cast_time <= 0:
		if (is_on_floor() or velocity.y > -5.0) and try_mantle(move, 1.05 if is_on_floor() else 1.55):
			return
		try_auto_climb(move)
	if dodge_time > 0.0:
		var progress = 1.0 - dodge_time / DODGE_DURATION
		var speed = lerpf(DODGE_SPEED, 2.0, smoothstep(0.45, 1.0, progress))
		velocity.x = dodge_direction.x * speed
		velocity.z = dodge_direction.z * speed
		velocity.y = -0.6 if is_on_floor() else velocity.y - 19.6 * dt
		motion = "dodge"
	elif climbing:
		climb_step(dt, stick)
	elif hooking > 0:
		hooking = maxf(0, hooking - dt)
		if not refresh_hook_anchor():
			finish_hook()
		elif visual.grapple_latched():
			var hook_offset = hook_target - (global_position + Vector3.UP)
			velocity = hook_offset.normalized() * minf(16.0, 5.0 + hook_offset.length() * 2.0)
			motion = "hook"
			if hook_offset.length() < 0.15:
				var toward_wall = -hook_normal
				var wall_grip = surface_climbable(hook_anchor.get_ref() if hook_anchor != null else null, hook_normal)
				finish_hook(true)
				if wall_grip:
					try_auto_climb(toward_wall, true)
			elif hooking <= 0:
				finish_hook()
		else:
			velocity.x = move_toward(velocity.x, 0, dt * 20)
			velocity.z = move_toward(velocity.z, 0, dt * 20)
			velocity.y = -0.6 if is_on_floor() else velocity.y - 19.6 * dt
			motion = "idle" if is_on_floor() else "jump"
			if hooking <= 0:
				finish_hook()
	elif swimming:
		velocity.x = move_toward(velocity.x, move.x * 3.1, dt * 9)
		velocity.z = move_toward(velocity.z, move.z * 3.1, dt * 9)
		velocity.y = clampf((_water_height() - 0.8 - global_position.y) * 4, -2.5, 3)
		motion = "swim"
		if stick.length() > 0.2:
			foot_time += dt
			if foot_time > 0.68:
				foot_time = 0
				cue("splash", randf_range(0.92, 1.08))
				if game != null:
					game.foot_effect(global_position + Vector3.UP * 0.8, true, 0.3)
	else:
		coyote = 0.12 if is_on_floor() else maxf(0, coyote - dt)
		var wants_run = (control_move.length() > 0.72 or sprinting or Input.is_physical_key_pressed(KEY_SHIFT)) and stick.length() > 0.2
		var run = wants_run and is_on_floor() and not is_instance_valid(held_body) and not visual.is_throwing() and not ability_aiming
		var speed = lerpf(WALK_SPEED, RUN_SPEED, smoothstep(0.55, 1.0, stick.length())) if run else WALK_SPEED
		if is_instance_valid(held_body):
			speed = CARRY_SPEED


		floor_snap_length = 0.16 if run else 0.45
		speed *= supply_speed_multiplier()
		var acceleration = 23.0 if is_on_floor() else 8.0
		if stick.length() < 0.05 and is_on_floor():
			acceleration = 20.0
		velocity.x = move_toward(velocity.x, move.x * speed, dt * acceleration)
		velocity.z = move_toward(velocity.z, move.z * speed, dt * acceleration)
		if not is_on_floor():
			velocity.y -= 19.6 * dt
		elif velocity.y < 0:
			velocity.y = -0.6
		motion = "run" if run else "walk" if Vector2(velocity.x, velocity.z).length() > 0.12 else "idle"
		if not is_on_floor():
			motion = "jump"
	if is_instance_valid(lock_target) and not climbing and hooking <= 0 and not visual.grapple_active():
		var toward: Vector3 = lock_target.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-toward.x, -toward.z), 1.0 - exp(-dt * 18))
	elif dodge_time > 0.0:
		pass
	elif melee_contact >= 0.0 and strike_facing.length_squared() > 0.5:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-strike_facing.x, -strike_facing.z), 1.0 - exp(-dt * 22.0))
	elif visual.is_throwing() or ability_aiming or cast_time > 0 or visual.grapple_active():
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 1.0 - exp(-dt * 15))
	elif move.length() > 0.08 and not climbing and hooking <= 0:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-move.x, -move.z), 1.0 - exp(-dt * 13))
	var was_grounded = is_on_floor()
	last_vertical = velocity.y
	move_and_slide()
	if is_on_floor() and not swimming and not climbing:
		last_grounded_position = global_position
	if is_on_floor() and not was_grounded and last_vertical < -3.0:
		var impact = clampf(-last_vertical / 12.0, 0.15, 1.0)
		landing_offset = -impact * 0.15
		if impact > 0.4:
			camera_trauma = minf(1.0, camera_trauma + impact * 0.22)
			feel_rumble(int(lerpf(12.0, 40.0, impact)), impact * 0.6)
		visual_action("land", impact)
		cue("land", lerpf(1.12, 0.88, impact))
		if game != null and game.has_method("foot_effect"):
			game.foot_effect(global_position, false, impact)
	if jump_buffer > 0 and is_on_floor() and jump_lock <= 0:
		execute_jump()
	if is_on_floor() and last_vertical < -16:
		take_damage(1)
	if global_position.y < -35 and (not world.has_method("interior_at") or world.interior_at(global_position).is_empty()):
		respawn("A small stumble. A fresh start.")
	if cast_time > 0:
		motion = "grimoire" if visual.has_method("is_grimoire_casting") and visual.is_grimoire_casting() else "beam" if hooking <= 0 else "hook"
	visual.carry_pose = is_instance_valid(held_body)
	state.player_position = global_position
	world.stream_at(global_position)
	# The interaction prompt only needs ~10 updates a second; interact() always rescans.
	_interaction_clock -= dt
	if _interaction_clock <= 0.0 or (closest != null and not is_instance_valid(closest)):
		_interaction_clock = 0.1
		closest = nearest_interaction()

func _process(dt: float) -> void:
	if visual == null:
		return
	if not active:
		cancel_dodge()
		clear_lock_on()
	forward_dodge_progress()
	if visual.has_method("set_weapon"):
		visual.set_weapon(state.equipment)
	if beam_charging:
		if not active or not beam_aim_toggled or not ability_aiming:
			cancel_primary_action()
		else:
			beam_charge = minf(1.3, beam_charge + dt)
	if "charge_weight" in visual:
		visual.charge_weight = beam_charge / 1.3 if beam_charging else 0.0
	charge_vfx.visible = active and beam_charging and beam_charge > 0.12
	if charge_vfx.visible:
		charge_vfx.scale = Vector3.ONE * (0.65 + beam_charge / 1.3 * 0.25)
		charge_vfx.rotation.z += dt * (0.5 + beam_charge * 0.5)
		var full := beam_charge >= 1.29
		var swell := clampf(beam_charge / 1.3, 0.0, 1.0)
		var beat := 1.0 + (sin(camera_clock * 18.0) * 0.12 if full else 0.0)
		if camera != null:
			var palm: Vector3 = charge_vfx.global_position
			var toward := (camera.global_position - palm).normalized()
			charge_glow.global_transform = Transform3D(camera.global_basis.scaled(Vector3.ONE * (0.28 + swell * 0.42) * beat), palm + toward * 0.05)
		charge_glow_material.set_shader_parameter("age", camera_clock)
		charge_glow_material.set_shader_parameter("opacity", 0.55 + swell * 0.45)
		charge_glow_material.set_shader_parameter("brightness", 1.0 + (0.4 if full else swell * 0.2))
	if ability_aiming and (not active or climbing or mantle_time > 0 or hooking > 0 or is_instance_valid(held_body) or visual.is_throwing()):
		end_ability_aim(false)
	visual.aim_kind = "hook" if visual.grapple_active() else "beam" if beam_contact >= 0 else ability_id
	visual.aim_weight = 1.0 if visual.grapple_active() or beam_contact >= 0 else aim_blend
	visual.mantle_progress = 1.0 - mantle_time / Mantle.DURATION if mantle_time > 0 else -1.0
	if beam_contact >= 0:
		var tracked_point = beam_lock_point()
		if tracked_point.is_finite():
			beam_target = tracked_point
	if visual.grapple_active():
		visual.aim_target = hook_point
	elif beam_contact >= 0:
		visual.aim_target = beam_target
	elif aim_blend > 0.001:
		visual.aim_target = ability_target().point
	if visual.has_method("set_motion_context"):
		visual.set_motion_context(velocity if active else Vector3.ZERO, is_on_floor(), get_floor_normal() if is_on_floor() else Vector3.UP)
	forward_climb_context()
	visual.animate(dt, motion if active else "idle", Vector2(velocity.x, velocity.z).length() if active else 0.0)
	if beam_contact >= 0:
		beam_contact -= dt
		if beam_contact <= 1.0e-06:
			beam_contact = -1.0
			resolve_beam()
	if visual.grapple_latched() and not hook_gripped:
		hook_gripped = true
		cue("grip")
	if throw_pending:
		if not active or not is_instance_valid(held_body):
			throw_pending = false
			visual.cancel_throw()
		elif visual.consume_throw_release():
			release_held(true)
	if active and visual.has_method("consume_footstep") and visual.consume_footstep() and is_on_floor() and not climbing:
		if game != null and game.has_method("step_sound"): game.step_sound(global_position)
		else: cue("step", randf_range(0.93, 1.08))
		if game != null and game.has_method("foot_effect") and motion == "run":
			game.foot_effect(global_position, false, 0.2)
	if is_instance_valid(hook_rope):
		if visual.grapple_active():
			var start: Vector3 = visual.wrists[1].global_position
			var end: Vector3 = visual.hands[1].to_global(Vector3(0, 0.1, 0))
			var cable = end - start
			hook_rope.mesh.height = maxf(0.01, cable.length())
			hook_rope.global_position = (start + end) * 0.5
			if cable.length_squared() > 1.0e-05:
				hook_rope.quaternion = Quaternion(Vector3.UP, cable.normalized())
		else:
			hook_rope.queue_free()
	var floor_hit = ray(global_position + Vector3.UP * 0.15, global_position - Vector3.UP * 3.5, 1)
	shadow.visible = not floor_hit.is_empty() and not swimming and not climbing
	if shadow.visible:
		shadow.global_position = floor_hit.position + floor_hit.normal * 0.018
		shadow.quaternion = Quaternion(Vector3.UP, floor_hit.normal)
		shadow_material.set_shader_parameter("strength", clampf(1.0 - global_position.distance_to(floor_hit.position) / 3.2, 0, 1) * 0.25)
	update_camera(dt)

func update_camera(dt: float) -> void:
	if camera == null or not is_inside_tree():
		return
	if game != null and game.is_title_context():
		camera.set_cull_mask_value(2, true)
		camera.fov = 48
		camera.global_position = global_position + Vector3(1.5 * HERO_RATIO, 1.65 * HERO_RATIO, 3.2 * HERO_RATIO)
		camera.look_at(global_position + Vector3(-0.72 * HERO_RATIO, 0.95 * HERO_RATIO, -0.2 * HERO_RATIO), Vector3.UP)
		return
	if game != null and str(game.get("mode")) in ["rest", "sleep"]:
		update_camp_camera(dt); return
	update_zoom(dt)
	var smoothing = 1.0 - exp(-maxf(dt, 0.0) * 9.0)
	camera_clock += dt
	camera_trauma = maxf(0, camera_trauma - dt * 2.2)
	landing_offset *= exp(-dt * 9)
	var aiming_view = ability_aiming or ((cast_time > 0 or visual.grapple_active()) and aim_blend > 0.5)
	aim_blend = lerpf(aim_blend, 1.0 if aiming_view and active else 0.0, 1.0 - exp(-maxf(dt, 0) * 11.0))
	var desired_fov = lerpf(64.0 if motion == "run" and active else 60.0, 54.0, aim_blend)
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-dt * 5))
	var bag = visual.bag_progress if visual != null else 0.0
	var use_lock_view: bool = is_instance_valid(lock_target) and active and not aiming_view and bag < 0.02
	var view_mode := 1 if use_lock_view else 0
	if view_mode != cam_mode and cam_mode >= 0:
		# Ease between the lock-on framing and the free/aim camera instead of cutting.
		cam_blend_from = camera.global_transform
		cam_blend = 1.0
	cam_mode = view_mode
	if use_lock_view:
		update_lock_camera(smoothing)
		_apply_camera_blend(dt)
		return
	var step := maxf(dt, 0.0)
	var flat_velocity := Vector3(velocity.x, 0, velocity.z)
	# Gentle auto-follow: after the player stops steering the camera, swing it in behind a
	# running hero. Never while aiming, carrying the bag view, or running toward the camera.
	if active and camera_idle > CAMERA_FOLLOW_DELAY and aim_blend < 0.1 and bag < 0.02 and flat_velocity.length() > 2.2 and not climbing:
		var heading: float = atan2(-flat_velocity.x, -flat_velocity.z)
		var turn: float = angle_difference(yaw, heading)
		if absf(turn) < 2.1:
			yaw += turn * (1.0 - exp(-step * 0.85)) * clampf((flat_velocity.length() - 2.2) / 4.0, 0.0, 1.0)
	var camera_yaw = lerp_angle(yaw, bag_yaw, smoothstep(0, 1, bag))
	var raw_target = global_position + Vector3(0, lerpf(1.38, 1.25, aim_blend) * HERO_RATIO + landing_offset, 0)
	if not cam_pivot_ready or cam_pivot.distance_to(raw_target) > 6.0:
		cam_pivot = raw_target; cam_pivot_ready = true; cam_length = -1.0
	var grounded: bool = is_on_floor() or climbing or swimming
	var vertical_rate: float = 10.0 if grounded else (3.5 if velocity.y > -7.0 else 11.0)
	var follow_h := 1.0 - exp(-step * 9.0)
	var follow_v := 1.0 - exp(-step * vertical_rate)
	cam_pivot = Vector3(lerpf(cam_pivot.x, raw_target.x, follow_h), lerpf(cam_pivot.y, raw_target.y, follow_v), lerpf(cam_pivot.z, raw_target.z, follow_h))
	cam_pivot.y = clampf(cam_pivot.y, raw_target.y - 0.9, raw_target.y + 0.55)
	var ahead: Vector3 = flat_velocity.limit_length(7.0) * 0.075 * (1.0 - aim_blend) * (1.0 - bag)
	cam_lookahead = cam_lookahead.lerp(ahead, 1.0 - exp(-step * 2.6))
	var target = cam_pivot + cam_lookahead
	var aimed_distance = 3.1 + (camera_distance - DEFAULT_CAMERA_DISTANCE) * 0.7
	var distance = lerpf(lerpf(camera_distance, aimed_distance, aim_blend), 3.8 * HERO_RATIO, bag)
	var view_pitch = lerpf(pitch, 0.1, smoothstep(0, 1, bag))
	var forward = Vector3(-sin(camera_yaw) * cos(view_pitch), -sin(view_pitch), -cos(camera_yaw) * cos(view_pitch))
	var right = Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var shoulder = lerpf(lerpf(0.72, 1.4, aim_blend) * HERO_RATIO, 0.0, bag)
	# Orbit responds instantly to input; only the collision distance is smoothed:
	# snap in when something blocks the view, ease back out when it clears (no popping).
	var offset: Vector3 = -forward * distance + right * shoulder
	var full_length: float = offset.length()
	var allowed: float = full_length
	var hit = ray(target, target + offset, 1 | 8)
	if not hit.is_empty():
		allowed = maxf(0.3, target.distance_to(hit.position) - 0.22)
	if cam_length < 0.0 or allowed < cam_length: cam_length = allowed
	else: cam_length = lerpf(cam_length, allowed, 1.0 - exp(-step * 3.2))
	var shake_enabled: bool = state == null or bool(state.settings.get("camera_shake", true))
	cam_kick *= exp(-step * 11.0)
	camera.global_position = target + offset.normalized() * minf(cam_length, full_length) + (cam_kick if shake_enabled else Vector3.ZERO)
	var blocked = ray(target, camera.global_position, 1 | 8)
	if not blocked.is_empty():
		camera.global_position = blocked.position + blocked.normal * 0.22
	if cam_noise == null:
		cam_noise = FastNoiseLite.new(); cam_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX; cam_noise.frequency = 1.0
	var trauma_sq = camera_trauma * camera_trauma
	var amplitude = lerpf(0.09, 0.025, aim_blend) * trauma_sq
	var shake = (right * cam_noise.get_noise_2d(camera_clock * 22.0, 3.0) + Vector3.UP * cam_noise.get_noise_2d(camera_clock * 22.0, 47.0) * 0.7) * amplitude
	var roll: float = cam_noise.get_noise_2d(camera_clock * 16.0, 91.0) * trauma_sq * 0.04
	if not shake_enabled: shake = Vector3.ZERO; roll = 0.0
	var look_point = camera.global_position + forward * 10
	# Aiming while locked on: keep the target under the reticle.
	if is_instance_valid(lock_target) and aim_blend > 0.01 and not lock_suspended():
		var enemy_focus: Vector3 = lock_target.global_position + Vector3.UP
		var to_enemy: Vector3 = enemy_focus - camera.global_position
		if to_enemy.length_squared() > 1.0:
			look_point = look_point.lerp(camera.global_position + to_enemy.normalized() * 10.0, aim_blend)
	look_point = look_point.lerp(target + right * (2.8 * HERO_RATIO), bag)
	camera.look_at(look_point + shake, Vector3.UP.rotated(forward.normalized(), roll))
	_apply_camera_blend(dt)
	camera.set_cull_mask_value(2, true)

func _apply_camera_blend(dt: float) -> void:
	if cam_blend <= 0.0: return
	cam_blend = maxf(0.0, cam_blend - maxf(dt, 0.0) * 3.6)
	var weight := smoothstep(0.0, 1.0, 1.0 - cam_blend)
	camera.global_transform = cam_blend_from.interpolate_with(camera.global_transform, weight)

## Push the camera briefly away along a direction (impacts, hits taken).
func camera_kick(direction: Vector3, strength: float) -> void:
	if direction.length_squared() < 1e-6: return
	cam_kick = (cam_kick + direction.normalized() * strength).limit_length(0.35)

func feel_hit_stop(duration: float) -> void:
	if game != null and game.get("feel") != null: game.feel.hit_stop(duration)

func feel_rumble(ms: int, strength: float) -> void:
	if game != null and game.get("feel") != null: game.feel.rumble(ms, strength)

func camera_input_allowed() -> bool:
	return active or (game != null and str(game.get("mode")) in ["rest", "sleep"])

func update_camp_camera(dt: float) -> void:
	update_zoom(dt)
	camera.fov = 44; camera.set_cull_mask_value(2, true)
	var focus = global_position + Vector3(0, 0.62, 0)
	if str(game.get("mode")) == "sleep" and is_instance_valid(game.camp): focus = game.camp.global_position + Vector3(-2, 0.5, -2.35)
	var offset = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * camera_distance
	var desired = focus + offset; var hit = ray(focus, desired, 1 | 8)
	if not hit.is_empty(): desired = hit.position + hit.normal * 0.18
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-maxf(0, dt) * 9))
	if camera.global_position.distance_to(focus) > 0.01: camera.look_at(focus)

func movement_input() -> Vector2:
	var stick = control_move
	if game != null:
		stick += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return stick.limit_length()

func dodge_hands_busy() -> bool:
	return climbing or swimming or mantle_time > 0.0 or hooking > 0.0 or cast_time > 0.0 or is_instance_valid(held_body) or throw_pending or beam_charging or ability_aiming or beam_contact >= 0.0 or visual == null or visual.bag_target > 0.01 or visual.bag_progress > 0.01 or visual.is_throwing() or visual.grapple_active()

func dodge() -> bool:
	if not active or state == null or dodge_time > 0.0 or dodge_cooldown > 1.0e-06 or not is_on_floor():
		return false


	if visual == null or climbing or swimming or mantle_time > 0.0 or hooking > 0.0 or is_instance_valid(held_body) or throw_pending or visual.bag_target > 0.01 or visual.bag_progress > 0.01 or visual.is_throwing() or visual.grapple_active():
		return false
	if magic_contact >= 0.0 or (visual.has_method("is_grimoire_casting") and visual.is_grimoire_casting()):
		cancel_magic()
	if ability_aiming or beam_aim_toggled or beam_charging or beam_contact >= 0.0:
		end_ability_aim(false)
		cancel_beam()
		aim_blend = 0.0
		visual.cancel_hand_ability_pose()
		charge_vfx.hide()
	if dodge_hands_busy(): return false
	var stick = movement_input()
	dodge_direction = Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, yaw).normalized() if stick.length() > 0.12 else (visual.global_basis.z.normalized() * 0.75)
	dodge_direction.y = 0.0
	dodge_direction = dodge_direction.normalized()
	if stick.length() > 0.12 and not is_instance_valid(lock_target):
		visual.rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
	dodge_time = DODGE_DURATION
	dodge_cooldown = DODGE_COOLDOWN
	jump_buffer = 0.0
	melee_contact = -1.0
	queued_strike = false
	combo_timer = 0.0
	visual.attack_time = 0.0
	forward_dodge_progress()
	return true

func dodge_invulnerable() -> bool:
	if not active or dodge_time <= 0.0 or dodge_hands_busy():
		return false
	var elapsed = DODGE_DURATION - dodge_time
	return elapsed >= 0.14 - 1.0e-06 and elapsed <= 0.38 + 1.0e-06

func cancel_dodge() -> void:
	if dodge_time > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	dodge_time = 0.0
	dodge_direction = Vector3.ZERO
	forward_dodge_progress()

func forward_dodge_progress() -> void:
	if visual != null and "dodge_progress" in visual:
		visual.dodge_progress = 1.0 - dodge_time / DODGE_DURATION if dodge_time > 0.0 else -1.0
		visual.dodge_direction = visual.global_basis.orthonormalized().inverse() * dodge_direction if dodge_time > 0.0 else Vector3.FORWARD

func lock_target_alive(target: Node3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree() or not target.is_in_group("enemy") or not target.is_visible_in_tree():
		return false
	if "health" in target and int(target.get("health")) <= 0:
		return false
	return int(target.get_meta("health", 1)) > 0

func lock_sight_clear(target: Node3D) -> bool:
	return ray(global_position + Vector3.UP * (1.15 * HERO_RATIO), target.global_position + Vector3.UP, 1 | 8).is_empty()

## Lock-on stays through hand aiming, casting, beams and dodges; it only pauses its
## steering while the grappling hook is carrying the hero.
func lock_controls_available() -> bool:
	return active and visual != null

func lock_suspended() -> bool:
	return visual == null or visual.grapple_active() or hooking > 0.0

func beam_lock_point() -> Vector3:
	# Every hand ability except the grappling hook (which needs a surface) aims at the lock.
	if ability_id == "hook" or not is_instance_valid(lock_target):
		return Vector3.INF
	if not lock_target_alive(lock_target) or global_position.distance_to(lock_target.global_position) > LOCK_RANGE:
		clear_lock_on()
		return Vector3.INF
	if not lock_sight_clear(lock_target):
		return Vector3.INF
	return lock_target.global_position + Vector3.UP

func lock_candidates() -> Array:
	var candidates: Array = []
	var forward = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right = Vector3(cos(yaw), 0.0, -sin(yaw))
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or not node is Node3D or not lock_target_alive(node):
			continue
		var offset: Vector3 = node.global_position - global_position
		var distance = offset.length()
		if distance > 18.0 or not camera.is_position_in_frustum(node.global_position + Vector3.UP) or not lock_sight_clear(node):
			continue
		candidates.append({"node": node, "angle": atan2(offset.dot(right), offset.dot(forward)), "distance": distance, "id": node.get_instance_id()})
	candidates.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a.angle, b.angle): return a.angle < b.angle
		if not is_equal_approx(a.distance, b.distance): return a.distance < b.distance
		return a.id < b.id)
	return candidates

func toggle_lock_on() -> bool:
	if not lock_controls_available():
		return false
	if is_instance_valid(lock_target):
		clear_lock_on()
		return true
	clear_lock_on()
	var candidates = lock_candidates()
	if candidates.is_empty():
		return false
	var best: Dictionary = candidates[0]
	for entry in candidates:
		if absf(entry.angle) < absf(best.angle) - 1.0e-05 or (is_equal_approx(absf(entry.angle), absf(best.angle)) and (entry.distance < best.distance or (is_equal_approx(entry.distance, best.distance) and entry.id < best.id))):
			best = entry
	lock_target = best.node
	return true

func cycle_lock_target() -> bool:
	if not lock_controls_available():
		return false
	var candidates = lock_candidates()
	if candidates.is_empty():
		clear_lock_on()
		return false
	var selected = 0
	for i in range(candidates.size()):
		if candidates[i].node == lock_target:
			selected = (i + 1) % candidates.size()
			break
	lock_target = candidates[selected].node
	lock_occlusion = 0.0
	return true

func clear_lock_on() -> void:
	lock_target = null
	lock_occlusion = 0.0

func update_lock_on(dt: float) -> void:

	if not is_instance_valid(lock_target):
		clear_lock_on()
		return
	if not lock_target_alive(lock_target) or not lock_controls_available() or global_position.distance_to(lock_target.global_position) > LOCK_RANGE:
		clear_lock_on()
		return
	if lock_suspended(): return
	lock_occlusion = 0.0 if lock_sight_clear(lock_target) else lock_occlusion + dt
	if lock_occlusion >= 1.5:
		clear_lock_on()
		return
	var toward = lock_target.global_position - global_position
	if Vector2(toward.x, toward.z).length_squared() > 0.001:
		var target_yaw = atan2(-toward.x, -toward.z)
		if ability_id == "beam" and (ability_aiming or beam_contact >= 0.0 or beam_charging):
			var turn = maxf(0.0, dt) * 4.2
			yaw += clampf(angle_difference(yaw, target_yaw), -turn, turn)
		elif dt > 0.0 and (ability_aiming or cast_time > 0.0 or dodge_time > 0.0):
			# Smooth tracking while aiming, casting or rolling so the view never snaps.
			yaw += angle_difference(yaw, target_yaw) * (1.0 - exp(-dt * 14.0))
		else:
			yaw = target_yaw
		if ability_aiming and dt > 0.0:
			var rise: float = (lock_target.global_position.y + 1.0) - (global_position.y + 1.25 * HERO_RATIO)
			var wanted_pitch: float = clampf(-atan2(rise, Vector2(toward.x, toward.z).length()) + 0.12, -0.6, 0.7)
			pitch = lerpf(pitch, wanted_pitch, 1.0 - exp(-dt * 6.0))

func face_lock_target() -> void:
	if is_instance_valid(lock_target) and lock_target_alive(lock_target):
		var toward = lock_target.global_position - global_position
		if Vector2(toward.x, toward.z).length_squared() > 0.001:
			visual.rotation.y = atan2(-toward.x, -toward.z)

func update_lock_camera(smoothing: float) -> void:
	var hero_focus = global_position + Vector3.UP * (1.25 * HERO_RATIO)
	var enemy_focus = lock_target.global_position + Vector3.UP
	var flat = lock_target.global_position - global_position
	flat.y = 0.0
	var forward = flat.normalized() if flat.length_squared() > 0.001 else Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right = forward.cross(Vector3.UP)
	var distance = clampf((4.1 + flat.length() * 0.12) * camera_distance / DEFAULT_CAMERA_DISTANCE, 2.8, 9.0)
	var desired = hero_focus - forward * distance + right * 0.8 + Vector3.UP * 0.8
	var hit = ray(hero_focus, desired, 1 | 8)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.22
	camera.global_position = camera.global_position.lerp(desired, smoothing)
	var blocked = ray(hero_focus, camera.global_position, 1 | 8)
	if not blocked.is_empty():
		camera.global_position = blocked.position + blocked.normal * 0.22
	camera.look_at(hero_focus.lerp(enemy_focus, 0.45), Vector3.UP)
	camera.set_cull_mask_value(2, true)

func adjust_zoom(amount: float) -> void:
	if not camera_input_allowed() or not is_finite(amount):
		return
	zoom_target = clampf(zoom_target + amount, 2.4, 8.0)
	camera_idle = 0.0

func update_zoom(dt: float) -> void:
	if dt <= 0.0:
		return
	if ability_aiming or beam_charging or cast_time > 0.0 or is_instance_valid(lock_target) or (visual != null and visual.bag_progress > 0.01):
		camera_idle = 0.0
	else:
		camera_idle += dt
		if camera_idle > CAMERA_IDLE_DELAY:
			zoom_target = lerpf(zoom_target, DEFAULT_CAMERA_DISTANCE, 1.0 - exp(-dt * 0.4))
	camera_distance = lerpf(camera_distance, zoom_target, 1.0 - exp(-dt * 7.0))

func look(delta: Vector2) -> void:
	if not camera_input_allowed() or not delta.is_finite():
		return
	if delta.length_squared() > 0.01:
		camera_idle = 0.0
	yaw -= delta.x * 0.004 * float(state.settings.sensitivity)
	pitch = clampf(pitch + delta.y * 0.003 * float(state.settings.sensitivity), -0.85, 1.05)

func ray(start: Vector3, end: Vector3, mask: int = 1 | 4 | 8) -> Dictionary:
	var q = PhysicsRayQueryParameters3D.create(start, end, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)

func climb_probe(start: Vector3, end: Vector3) -> Dictionary:
	var hit = ray(start, end, 1 | 8)


	return hit if hit.is_empty() or surface_supports_climbing(hit.collider) else {}

func forward_climb_context() -> void:
	if visual == null or not visual.has_method("set_climb_context"):
		return
	if active and climbing:
		visual.set_climb_context(climb_surface_normal if climb_surface_normal.length_squared() > 0.5 else climb_normal, velocity, climb_probe)
	else:
		if not climbing:
			climb_surface_normal = Vector3.ZERO
			climb_surface = null
		visual.set_climb_context(Vector3.ZERO, Vector3.ZERO, Callable())

func jump() -> void:
	if not active or dodge_time > 0.0 or jump_lock > 0 or mantle_time > 0:
		return
	cancel_magic()
	if try_mantle(-climb_normal if climbing else -(visual.global_basis.z.normalized() * 0.75)):
		return
	if climbing:
		climbing = false
		climb_detach = 0.45
		velocity = climb_normal * 3.3 + Vector3.UP * 5.5
		jump_lock = 0.13
		visual_action("jump")
		cue("jump")
	elif is_on_floor() or coyote > 0 or swimming:
		execute_jump()
	else:
		jump_buffer = 0.16

func execute_jump() -> void:
	if dodge_time > 0.0:
		return
	jump_buffer = 0
	if swimming:
		swim_jump_time = 0.5
	velocity.y = (7.1 if not swimming else 6.0) * (1.2 if state.upgrades.get("spring_boots", false) else 1.0)
	coyote = 0
	jump_lock = 0.13
	visual_action("jump")
	cue("jump")

func toggle_climb() -> void:
	cancel_magic()
	if not active or dodge_time > 0.0 or mantle_time > 0 or visual.grapple_active():
		return
	if climbing:
		climbing = false
		climb_detach = 0.4
		velocity = climb_normal * 1.5
		return
	if is_instance_valid(held_body):
		toast("Throw the object before climbing.")
		return
	var facing = -(visual.global_basis.z.normalized() * 0.75)
	if try_mantle(facing):
		return
	var hit = ray(global_position + Vector3.UP * (0.95 * HERO_RATIO), global_position + Vector3.UP * (0.95 * HERO_RATIO) + facing * 1.0, 1 | 8)
	if not hit.is_empty() and surface_climbable(hit.collider, hit.normal):
		cancel_primary_action()
		end_ability_aim(false)
		cancel_beam()
		climbing = true
		climb_surface_normal = hit.normal
		climb_surface = weakref(hit.collider)
		climb_normal = Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
		terrain_climb_normal = hit.normal if surface_is_terrain(hit.collider) else Vector3.ZERO
		velocity = Vector3.ZERO
		cue("grip")
	else:
		toast("Walk or jump toward a wall to grip it.")

func surface_is_terrain(node: Object) -> bool:
	var current = node
	for i in range(3):
		if current == null or not is_instance_valid(current):
			break
		if bool(current.get_meta("terrain", false)):
			return true
		current = current.get_parent() if current is Node else null
	return false

func surface_climbable(node: Object, normal: Vector3) -> bool:
	if node == null or not is_instance_valid(node) or not normal.is_finite():
		return false
	var normal_limit = 0.55
	if normal.y >= 0.0:
		normal_limit = 0.76 if surface_is_terrain(node) else maxf(0.55, cos(floor_max_angle) + 0.02)
	if absf(normal.y) > normal_limit:
		return false
	return surface_supports_climbing(node)

func surface_supports_climbing(node: Object) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is RigidBody3D and not node.freeze:
		return false
	var current = node
	for i in range(3):
		if current == null:
			break
		if current.has_meta("climbable") and not bool(current.get_meta("climbable")):
			return false
		current = current.get_parent() if current is Node else null
	return true

func try_auto_climb(direction: Vector3, grapple_arrival: bool = false) -> bool:
	if not active or dodge_time > 0.0 or climbing or climb_detach > 0 or mantle_time > 0 or swimming or is_instance_valid(held_body) or visual.is_throwing():
		return false
	if not grapple_arrival and (ability_aiming or cast_time > 0 or visual.grapple_active()):
		return false
	var facing = Vector3(direction.x, 0, direction.z).normalized()
	if facing.length_squared() < 0.1:
		return false
	var chest = global_position + Vector3.UP * (1.05 * HERO_RATIO)
	var hit = ray(chest, chest + facing * (1.25 if grapple_arrival else 0.8), 1 | 8)
	if hit.is_empty() and not grapple_arrival:



		var slope = ray(chest, chest + facing * 1.3, 1 | 8)
		if not slope.is_empty() and (surface_is_terrain(slope.collider) or (slope.normal.y > 0.08 and surface_climbable(slope.collider, slope.normal))):
			hit = slope
	if hit.is_empty() or not surface_climbable(hit.collider, hit.normal) or facing.dot(-hit.normal) < 0.45:
		return false
	cancel_primary_action()
	end_ability_aim(false)
	cancel_beam()
	climbing = true
	climb_surface_normal = hit.normal
	climb_surface = weakref(hit.collider)
	climb_normal = Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	terrain_climb_normal = hit.normal if surface_is_terrain(hit.collider) else Vector3.ZERO
	visual.rotation.y = atan2(climb_normal.x, climb_normal.z)
	velocity = Vector3.ZERO
	motion = "climb"
	cue("grip")
	return true

func try_mantle(direction: Vector3, max_rise: float = 1.55) -> bool:
	if not active or dodge_time > 0.0 or state == null or swimming or hooking > 0 or mantle_time > 0 or cast_time > 0 or is_instance_valid(held_body) or visual.is_throwing() or visual.grapple_active() or visual.attack_time > 0:
		return false
	var ledge = Mantle.find_ledge(self, direction, max_rise)
	if ledge.is_empty():
		return false
	end_ability_aim(false)
	climbing = false
	velocity = Vector3.ZERO
	mantle_start = ledge.start
	mantle_lift = ledge.lift
	mantle_end = ledge.end
	mantle_time = Mantle.DURATION
	visual.mantle_contacts.assign(ledge.contacts)
	visual.mantle_height = mantle_end.y - mantle_start.y
	visual.mantle_progress = 0.0
	visual.rotation.y = atan2(-direction.x, -direction.z)
	motion = "mantle"
	jump_buffer = 0
	jump_lock = Mantle.DURATION
	cue("grip")
	return true

func climb_step(dt: float, stick: Vector2) -> void:
	if stick.y < -0.15 and try_mantle(-climb_normal):
		return
	if terrain_climb_normal.length_squared() > 0.5 and terrain_walk_handoff(stick):
		return
	if terrain_climb_normal.length_squared() < 0.5 and rock_walk_handoff(stick):
		return
	var chest = global_position + Vector3.UP * (1.0 * HERO_RATIO)


	var reach = 1.55 if terrain_climb_normal.length_squared() > 0.5 else 1.3 if climb_surface_normal.y > 0.08 else 0.8
	var wall = ray(chest + climb_normal * 0.1, chest - climb_normal * reach, 1 | 8)
	var contour = climb_contour(stick.y < -0.15)
	if not wall.is_empty() and not surface_climbable(wall.collider, wall.normal):
		wall = {}
	if wall.is_empty() and contour.is_empty():
		if terrain_crest_step(stick) or rock_crest_step(stick):
			return
		climbing = false
		velocity = Vector3.ZERO
		return
	var normal: Vector3 = wall.normal if not wall.is_empty() else contour.normal
	var terrain_face = surface_is_terrain(wall.collider) if not wall.is_empty() else bool(contour.get("terrain", false))
	if wall.is_empty():
		normal = contour.get("slope_normal", normal)



	if surface_climbable(wall.collider if not wall.is_empty() else contour.collider, normal):
		climb_surface_normal = normal
	climb_surface = weakref(wall.collider if not wall.is_empty() else contour.collider)
	climb_normal = climb_normal.lerp(Vector3(normal.x, 0, normal.z).normalized(), minf(1, dt * 8)).normalized()
	visual.rotation.y = atan2(climb_normal.x, climb_normal.z)
	var sideways = Vector3.UP.cross(climb_normal).normalized()
	if terrain_face:
		terrain_climb_normal = normal



		var up_slope = Vector3.UP.slide(normal).normalized()
		velocity = up_slope * -stick.y * 1.65 + sideways * stick.x * 1.5 - normal * 0.6
		if is_on_floor() and stick.y > 0.2:
			climbing = false
			climb_detach = 0.4
		motion = "climb"
		return
	terrain_climb_normal = Vector3.ZERO
	var correction: float = contour.correction if not contour.is_empty() else -0.06




	var rise = -stick.y * 1.65
	if rise > 0 and correction > 0.035:
		rise = 0.0


	var up_face = Vector3.UP.slide(normal).normalized() if normal.y > 0.08 else Vector3.UP
	velocity = up_face * rise + sideways * stick.x * 1.5 + climb_normal * clampf(correction * 12.0, -0.75, 2.4)
	if is_on_floor() and stick.y > 0.2:
		climbing = false
		climb_detach = 0.4
	motion = "climb"

func rock_walk_handoff(stick: Vector2) -> bool:
	if climb_surface_normal.y <= 0.08 or climb_surface == null or not is_instance_valid(climb_surface.get_ref()):
		return false
	var chest = global_position + Vector3.UP * (1.05 * HERO_RATIO)
	var face = ray(chest, chest - climb_normal * 1.3, 1 | 8)
	if not face.is_empty() and surface_climbable(face.collider, face.normal):
		return false
	var ground = ray(global_position + Vector3.UP * 0.35, global_position - Vector3.UP * 0.45, 1 | 8)
	if ground.is_empty() or ground.collider != climb_surface.get_ref() or ground.normal.y < cos(floor_max_angle) + 0.02 or ground.position.y > global_position.y + 0.02:
		return false
	climbing = false
	climb_detach = 0.18
	var move = Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, yaw)
	velocity = move * WALK_SPEED
	velocity.y = -0.6
	motion = "walk" if stick.length() > 0.1 else "idle"
	return true

func rock_crest_step(stick: Vector2) -> bool:
	if terrain_climb_normal.length_squared() > 0.5 or climb_surface_normal.y <= 0.08 or climb_surface == null or not is_instance_valid(climb_surface.get_ref()):
		return false
	var probe = global_position - climb_normal * 0.8
	var support = ray(probe + Vector3.UP * 1.3, probe - Vector3.UP * 0.6, 1 | 8)


	if support.is_empty() or support.collider != climb_surface.get_ref() or support.normal.y < cos(floor_max_angle) + 0.02:
		return false
	var up_face = Vector3.UP.slide(climb_surface_normal).normalized()
	var sideways = Vector3.UP.cross(climb_normal).normalized()
	velocity = up_face * -stick.y * 1.65 + sideways * stick.x * 1.5 - climb_surface_normal * 0.6
	motion = "climb"
	return true

func terrain_walk_handoff(stick: Vector2) -> bool:


	var forward = -Vector3(climb_normal.x, 0, climb_normal.z).normalized()
	var chest = global_position + Vector3.UP * (1.05 * HERO_RATIO)
	var face = ray(chest, chest + forward * 1.3, 1 | 8)
	if not face.is_empty() and surface_is_terrain(face.collider) and surface_climbable(face.collider, face.normal):
		return false
	var ground = ray(global_position + Vector3.UP * 0.35, global_position - Vector3.UP * 0.45, 1 | 8)
	if ground.is_empty() or not surface_is_terrain(ground.collider) or ground.normal.y < cos(floor_max_angle) + 0.02 or ground.position.y > global_position.y + 0.02:
		return false


	climbing = false
	climb_detach = 0.18
	terrain_climb_normal = Vector3.ZERO
	var move = Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, yaw)
	velocity = move * WALK_SPEED
	velocity.y = -0.6
	motion = "walk" if stick.length() > 0.1 else "idle"
	return true

func terrain_crest_step(stick: Vector2) -> bool:
	if terrain_climb_normal.length_squared() < 0.5:
		return false
	var forward = -Vector3(climb_normal.x, 0, climb_normal.z).normalized()
	var probe = global_position + forward * 0.8
	var support = ray(probe + Vector3.UP * 1.3, probe - Vector3.UP * 0.6, 1 | 8)
	if support.is_empty() or not surface_is_terrain(support.collider) or support.normal.y < cos(floor_max_angle) + 0.02:
		return false



	var up_slope = Vector3.UP.slide(terrain_climb_normal).normalized()
	var sideways = Vector3.UP.cross(climb_normal).normalized()
	velocity = up_slope * -stick.y * 1.65 + sideways * stick.x * 1.5 - terrain_climb_normal * 0.6
	motion = "climb"
	return true

func climb_contour(ascending: bool) -> Dictionary:
	var outward = Vector3(climb_normal.x, 0, climb_normal.z).normalized()
	var probe = global_transform
	probe.origin += outward * 0.85 + Vector3.UP * (0.1 if ascending else 0.0)


	if not Mantle.step_is_clear(self, probe.origin, probe.origin):
		return {}
	var contact = KinematicCollision3D.new()
	if not test_move(probe, -outward * 1.85, contact, 0.001):
		return {}
	var normal = contact.get_normal()
	var horizontal = Vector3(normal.x, 0, normal.z)
	if horizontal.length_squared() < 0.12:
		return {}
	horizontal = horizontal.normalized()
	var terrain_face = surface_is_terrain(contact.get_collider())
	if horizontal.dot(outward) < 0.45 or not surface_climbable(contact.get_collider(), normal if terrain_face else horizontal):
		return {}
	var stand = probe.origin + contact.get_travel()
	return {"normal": horizontal, "correction": (stand - global_position).dot(outward) + 0.025, "terrain": terrain_face, "slope_normal": normal, "collider": contact.get_collider()}

func nearest_interaction() -> Node3D:
	var result: Node3D
	var nearest = 2.75 * 2.75
	for node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node) or node == held_body:
			continue


		var distance = global_position.distance_squared_to(node.global_position)
		if distance >= nearest: continue
		if node.get_meta("ring_only", false):
			var offset = global_position - node.global_position
			if Vector2(offset.x, offset.z).length_squared() > 0.95 * 0.95 or absf(offset.y) > 1.4: continue
		if distance < nearest:
			var kind = str(node.get_meta("kind", ""))
			var target_height = float(node.get_meta("interaction_height", 0.9 if kind == "npc" else 0.65 if kind in ["carry", "shrine", "checkpoint", "chest"] else 0.35 if kind == "material" or node.get_meta("loose_stone", false) else 0.0))
			var eye_height = 1.0 if kind == "npc" else 1.0 * HERO_RATIO
			var sight = ray(global_position + Vector3.UP * eye_height, node.global_position + Vector3.UP * target_height, 1 | 8)
			if not sight.is_empty() and sight.collider != node and not node.is_ancestor_of(sight.collider):
				continue
			result = node
			nearest = distance
	return result

func interact() -> void:
	if not active or dodge_time > 0.0 or mantle_time > 0 or visual.is_throwing() or visual.grapple_active():
		return
	cancel_beam()
	if is_instance_valid(held_body):
		throw_held()
		return
	var node = nearest_interaction()
	if node == null:
		return
	interact_node(node)

func interact_node(node: Node3D) -> void:
	if not active or dodge_time > 0.0 or not is_instance_valid(node) or global_position.distance_to(node.global_position) > 2.9:
		return
	var kind = str(node.get_meta("kind", ""))
	if kind == "material" and game != null and preload("res://scripts/loose_stone_carry.gd").liftable(node):
		var lifted = preload("res://scripts/loose_stone_carry.gd").lift(game, node)
		if lifted == null: return
		node = lifted; kind = "carry"
	if kind == "carry":
		cancel_magic()



		cancel_beam()
		end_ability_aim(false)
		cancel_melee()
		var moved_id = str(node.get_meta("id", ""))
		if moved_id != "" and not node.get_meta("world_drop", false):
			state.taken[moved_id] = true
		held_body = node
		held_body.freeze = true
		held_body.collision_layer = 0
		held_body.collision_mask = 0
		held_body.reparent(visual.grip, true)
		held_body.position = Vector3.ZERO
		held_body.rotation = Vector3.ZERO
		visual.carry_half_width = 0.3 if held_body.mass < 1.0 else 0.52

		for child in held_body.get_children():
			if child is CollisionShape3D:
				var half = Vector3.ONE * 0.35
				if child.shape is SphereShape3D:
					half = Vector3.ONE * child.shape.radius
				elif child.shape is BoxShape3D:
					half = child.shape.size * 0.5
				elif child.shape is CapsuleShape3D:
					half = Vector3(child.shape.radius, child.shape.height * 0.5, child.shape.radius)
				elif child.shape is ConvexPolygonShape3D:
					var points = child.shape.points
					if not points.is_empty():
						var bounds = AABB(points[0], Vector3.ZERO)
						for point in points: bounds = bounds.expand(point)
						half = bounds.size * 0.5
				var local = visual.global_basis.inverse() * child.global_basis
				var extent = local.x.abs() * half.x + local.y.abs() * half.y + local.z.abs() * half.z
				visual.carry_half_width = extent.x + 0.035
				visual.carry_half_height = extent.y
				visual.carry_half_depth = extent.z
				break
		visual.carry_pose = true
		cue("grip")
		toast("Tap E to throw · Hold E to put down. Aim with the camera." if game != null and game.has_method("desktop_enabled") and game.desktop_enabled() else "Tap B to throw · Hold B to put down. Aim with the camera.")
	elif game != null:
		game.interact_with(node)

func throw_held() -> void:
	if not active or dodge_time > 0.0 or throw_pending or visual.is_throwing() or not is_instance_valid(held_body):
		return
	throw_pending = true
	melee_contact = -1.0
	queued_strike = false
	visual_action("throw")

func release_held(launch: bool) -> void:
	var body = held_body
	if not is_instance_valid(body):
		held_body = null
		throw_pending = false
		visual.carry_pose = false
		return
	var direction = -camera.global_basis.z
	var release_position = body.global_position


	for child in body.get_children():
		if child is CollisionShape3D:
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			var start = global_position + Vector3.UP * (1.1 * HERO_RATIO)
			query.transform = Transform3D(body.global_basis, start) * child.transform
			query.collision_mask = 1 | 4 | 8
			query.exclude = [get_rid(), body.get_rid()]
			query.margin = 0.015
			var space = get_world_3d().direct_space_state



			for attempt in range(16):
				var rest = space.get_rest_info(query)
				if rest.is_empty():
					break
				var depth = 0.0
				var contacts = space.collide_shape(query, 12)
				for contact in range(0, contacts.size(), 2):
					depth = maxf(depth, (contacts[contact + 1] - contacts[contact]).dot(rest.normal))
				query.transform.origin += rest.normal * (depth + 0.02)
			if not space.intersect_shape(query, 1).is_empty():
				if launch:
					throw_pending = false
					visual.cancel_throw()
					toast("Find a little more room to throw.")
					return
				release_position = state.checkpoint + Vector3.UP * (1.1 * HERO_RATIO) if state != null else global_position + Vector3.UP * (1.5 * HERO_RATIO)
				break
			start = query.transform.origin - body.global_basis * child.position
			query.motion = release_position - start
			var safe = space.cast_motion(query)
			release_position = start + query.motion * safe[0]
			break
	if launch:
		var mark = get_viewport().get_visible_rect().size * Vector2(0.5, 332.0 / 720.0)
		var sight_start = camera.project_ray_origin(mark)
		var sight_end = sight_start + camera.project_ray_normal(mark) * 42
		var sight = ray(sight_start, sight_end)
		direction = ((sight.position if not sight.is_empty() else sight_end) - release_position).normalized()
	held_body = null
	throw_pending = false
	visual.carry_pose = false
	body.reparent(world, true)
	body.global_position = release_position
	body.collision_layer = 8
	body.collision_mask = 1 | 4 | 8
	body.freeze = false
	body.linear_velocity = (direction + Vector3.UP * 0.32).normalized() * 14.5 + velocity * 0.2 if launch else Vector3.ZERO
	body.angular_velocity = Vector3(2.5, 3.0, 1.5) if launch else Vector3.ZERO
	if not body.is_in_group("loose_prop"):
		body.add_to_group("loose_prop")
	body.contact_monitor = true
	body.max_contacts_reported = 3
	if not body.has_meta("throw_connected"):
		body.set_meta("throw_connected", true)
		body.body_entered.connect(func (other):
			if is_instance_valid(body) and body.linear_velocity.length() > 2.5:
				if is_instance_valid(other) and other.has_method("take_damage"):
					other.take_damage(2)
				if body.has_method("take_damage"):
					body.take_damage(2)
		)
	if launch:
		cue("throw")
	if game != null and body.get_meta("lifted_stone", false): game.stone_released(body)

func attack() -> void:
	if grimoire_equipped():
		cast_spell()
		return
	if not active or dodge_time > 0.0 or climbing or mantle_time > 0 or cast_time > 0.0 or hooking > 0.0 or visual.is_throwing() or visual.grapple_active():
		return
	if attack_cooldown > 0:


		if strike_duration - attack_cooldown >= 0.065 or attack_cooldown < 0.18:
			queued_strike = true
		return
	if is_instance_valid(held_body):
		throw_held()
		return
	end_ability_aim(false)
	cancel_beam()
	face_lock_target()
	strike_facing = assisted_strike_direction()
	if not is_instance_valid(lock_target) and strike_facing.length_squared() > 0.5:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-strike_facing.x, -strike_facing.z), 0.45)
	combo_step = (combo_step + 1) % 3 if combo_timer > 0 else 0
	var duration: float = Hero.strike_duration(state.equipment, combo_step)
	strike_duration = duration + 0.035
	combo_timer = duration + 0.55
	attack_cooldown = strike_duration
	melee_contact = Hero.strike_contact(state.equipment, combo_step)
	visual_action("attack", 1.0, combo_step)
	cue("punch")

func cancel_melee() -> void:
	melee_contact = -1.0
	queued_strike = false
	strike_facing = Vector3.ZERO
	visual.attack_time = 0.0

func assisted_strike_direction() -> Vector3:
	var forward := -visual.global_basis.z.normalized()
	if is_instance_valid(lock_target):
		return (lock_target.global_position - global_position).slide(Vector3.UP).normalized()

	if str(Crafting.weapon_metadata(state.equipment).get("tool", "")) != "":
		return forward
	var best := forward
	var score := 0.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node3D or not lock_target_alive(enemy): continue
		var offset: Vector3 = enemy.global_position - global_position
		if absf(offset.y) > 1.6 or offset.length() > 2.8 or offset.length() < 0.05: continue
		var direction := offset.slide(Vector3.UP).normalized()
		var alignment := forward.dot(direction)
		if alignment < cos(deg_to_rad(42.0)): continue
		if not ray(global_position + Vector3.UP * HERO_RATIO, enemy.global_position + Vector3.UP, 1 | 8).is_empty(): continue
		var candidate := alignment * 2.0 - offset.length() * 0.1
		if candidate > score:
			score = candidate
			best = direction
	return best

func combat_damage_targets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	var seen := {}
	for target in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("damageable"):
		if not target is Node3D or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_visible_in_tree() or not target.has_method("take_damage"):
			continue
		if target.get("health") != null and float(target.get("health")) <= 0.0:
			continue
		var id: int = target.get_instance_id()
		if seen.has(id): continue
		seen[id] = true
		targets.append(target)
	return targets

func damage_target_point(target: Node3D) -> Vector3:
	return target.global_position + Vector3.UP * float(target.get_meta("damage_height", 1.0 if target.is_in_group("enemy") else 0.65))

func damage_path_clear(origin: Vector3, point: Vector3, target: Node3D) -> bool:
	var hit := ray(origin, point, 1 | 8)
	return hit.is_empty() or hit.collider == target or target.is_ancestor_of(hit.collider)

func resolve_melee() -> void:

	if not active or dodge_time > 0.0 or climbing or mantle_time > 0 or ability_aiming or cast_time > 0.0 or beam_charging or beam_contact >= 0.0 or is_instance_valid(held_body) or throw_pending or visual.is_throwing() or visual.grapple_active() or visual.bag_target > 0.01 or visual.bag_progress > 0.01:
		return
	face_lock_target()
	var facing = -(visual.global_basis.z.normalized() * 0.75)
	if game != null and game.has_method("swing_effect"):
		game.swing_effect(global_position, facing, combo_step)
	if game != null and game.has_method("harvest_strike"):
		game.harvest_strike(global_position, facing)
	var weapon = Crafting.weapon_metadata(state.equipment)
	for enemy in combat_damage_targets():
		var offset: Vector3 = enemy.global_position - global_position
		if offset.length() < maxf(2.3, float(weapon.reach)) and absf(offset.y) < 1.6 and facing.dot(offset.normalized()) > 0.25:
			if not damage_path_clear(global_position + Vector3.UP * (1.05 * HERO_RATIO), damage_target_point(enemy), enemy):
				continue
			enemy.take_damage(int(weapon.damage) + (1 if combo_step == 2 else 0))
			if game != null and game.has_method("comic_impact"):
				game.comic_impact("KRAK!" if combo_step == 2 else "THOK!", enemy.global_position + Vector3.UP * 1.8)
			if enemy.has_method("receive_impulse"):
				enemy.receive_impulse(facing * (3.6 if combo_step == 2 else 2.1))
			camera_trauma = minf(1.0, camera_trauma + (0.48 if combo_step == 2 else 0.32))
			camera_kick(facing, 0.07 if combo_step == 2 else 0.04)
			var defeated: bool = enemy.get("health") != null and int(enemy.get("health")) <= 0
			feel_hit_stop(0.13 if defeated else (0.095 if combo_step == 2 else 0.055))
			feel_rumble(38 if combo_step == 2 else 22, 0.85 if combo_step == 2 else 0.55)
			if game != null and game.get("feel") != null: game.feel.squash(enemy, 1.0 if combo_step == 2 else 0.65)
			if game != null:
				game.burst(enemy.global_position + Vector3.UP, Color("#ffd99a"))

func use_ability(power: float = 0.0) -> void:
	if not active or dodge_time > 0.0 or ability_cooldown > 0 or is_instance_valid(held_body) or visual.is_throwing() or visual.grapple_active() or mantle_time > 0 or magic_contact >= 0.0 or (visual.has_method("is_grimoire_casting") and visual.is_grimoire_casting()):
		return
	if not state.has_ability(ability_id):
		toast("This hand ability is not available.")
		return
	update_lock_on(0.0)
	visual.rotation.y = yaw


	update_camera(0.0)
	var solution = ability_target()
	var hit: Dictionary = solution.hit
	var end: Vector3 = solution.point
	if ability_id == "hook":
		if hit.is_empty() or not hit.normal.is_finite() or global_position.distance_to(end) < 3:
			toast("Aim the center mark at a distant solid surface.")
			return
		if not visual.launch_grapple(end, hit.normal):
			return
		hook_anchor = weakref(hit.collider)
		hook_local_point = hit.collider.to_local(end)
		hook_local_normal = hit.collider.global_basis.orthonormalized().inverse() * hit.normal
		hook_point = end
		hook_normal = hit.normal
		hook_target = end + hit.normal * 0.6
		hook_gripped = false


		var pull_distance = global_position.distance_to(end)
		hooking = minf(5.2, visual.grapple.duration + maxf(0.0, pull_distance - 5.5) / 16.0 + 0.5 * log(16.0 / 5.3) + 0.45)
		climbing = false
		cast_time = hooking
		ability_cooldown = 1.6
		if game != null:
			if is_instance_valid(hook_rope):
				hook_rope.queue_free()
			hook_rope = game.make_rope(visual.wrists[1].global_position, visual.hands[1].to_global(Vector3(0, 0.1, 0)))
		cancel_melee()
		cue("hook")
	else:
		beam_power = clampf(power, 0, 1)
		beam_paid = 0.0
		beam_target = end
		beam_contact = 0.055 if beam_power < 0.42 else 0.1
		cast_time = 0.16 if beam_power < 0.42 else 0.42
		ability_cooldown = 0.24 if beam_power < 0.42 else 0.7
		cancel_melee()
		visual_action("beam")

func resolve_beam() -> void:
	if not active:
		return
	var solution = ability_target(beam_target)
	if game != null:
		game.beam(solution.origin, solution.point, Color("#95f3ee"), lerpf(0.12, 0.8, beam_power), 0.18 if beam_power < 0.42 else 0.5)
	for enemy in combat_damage_targets():
		var center: Vector3 = damage_target_point(enemy)
		var near = Geometry3D.get_closest_point_to_segment(center, solution.origin, solution.point)
		if near.distance_to(center) < lerpf(0.65, 1.25, beam_power) and damage_path_clear(solution.origin, center, enemy):
			enemy.take_damage(2 if beam_power < 0.42 else roundi(lerpf(3, 9, beam_power)))
	beam_paid = 0
	camera_trauma = minf(1, camera_trauma + lerpf(0.08, 0.4, beam_power))
	cue("beam")

func cancel_beam() -> void:
	if beam_contact >= 0:
		beam_contact = -1.0
		beam_paid = 0
		ability_cooldown = 0
		cast_time = 0

func refresh_hook_anchor() -> bool:
	var target = hook_anchor.get_ref() if hook_anchor != null else null
	if not is_instance_valid(target) or not target is Node3D:
		return false
	hook_point = target.to_global(hook_local_point)
	hook_normal = (target.global_basis.orthonormalized() * hook_local_normal).normalized()
	hook_target = hook_point + hook_normal * 0.6
	var cover = ray(global_position + Vector3.UP * (1.22 * HERO_RATIO), hook_point, 1 | 8)
	if not cover.is_empty() and cover.position.distance_to(hook_point) > 0.22:
		return false
	visual.update_grapple_anchor(hook_point, hook_normal)
	return true

func finish_hook(immediate: bool = false) -> void:
	var was_hooking = hooking > 0 or (visual != null and visual.grapple_active())
	hooking = 0
	hook_anchor = null
	hook_gripped = false
	if visual != null:
		visual.finish_grapple(immediate)
	if was_hooking:
		cast_time = 0
		velocity *= 0.2
	if immediate and is_instance_valid(hook_rope):
		hook_rope.queue_free()

func begin_ability_aim(preserve_spell_concentration: bool = false) -> bool:
	if not active or dodge_time > 0.0 or climbing or mantle_time > 0 or hooking > 0 or is_instance_valid(held_body) or visual.is_throwing() or visual.grapple_active():
		return false
	if not state.has_ability(ability_id):
		toast("This hand ability is not available.")
		return false
	if not preserve_spell_concentration: cancel_magic()
	cancel_melee()
	ability_aiming = true
	return true

func end_ability_aim(fire: bool) -> void:
	var was_aiming = ability_aiming
	cancel_primary_action()
	beam_aim_toggled = false
	ability_aiming = false
	if fire and was_aiming and active:
		use_ability()

func toggle_beam_aim() -> void:
	if beam_aim_toggled:
		end_ability_aim(false)
		cancel_beam()
	elif ability_id == "beam" and begin_ability_aim():
		beam_aim_toggled = true

func begin_primary_action() -> void:
	if not active:
		return
	if beam_aim_toggled and ability_aiming and ability_id == "beam":
		if not beam_charging and ability_cooldown <= 0 and beam_contact < 0:
			beam_charging = true
			beam_charge = 0
	else:
		jump()

func end_primary_action(canceled: bool = false) -> void:
	if not beam_charging:
		return
	var charge = beam_charge / 1.3
	cancel_primary_action()
	if not canceled and active and beam_aim_toggled and ability_aiming:
		use_ability(charge)

func cancel_primary_action() -> void:
	beam_charging = false
	beam_charge = 0

func ability_target(override_point: Vector3 = Vector3.INF) -> Dictionary:
	var mark = get_viewport().get_visible_rect().size * Vector2(0.5, 332.0 / 720.0)
	var start = camera.project_ray_origin(mark)
	var direction = camera.project_ray_normal(mark)
	var reach = 42.0 + (8.0 if ability_id == "hook" and state.upgrades.get("grapple_spool", false) else 0.0)
	var hit = ray(start, start + direction * reach)
	var tracked_point = beam_lock_point()
	var end: Vector3 = tracked_point if tracked_point.is_finite() else override_point if override_point.is_finite() else hit.position if not hit.is_empty() else start + direction * (reach - 2.0)
	if tracked_point.is_finite():
		hit = ray(start, tracked_point)
	var origin: Vector3 = visual.palm_origin()


	var cover = ray(global_position + Vector3.UP * (1.22 * HERO_RATIO), origin, 1 | 8)
	if not cover.is_empty():
		origin = cover.position + cover.normal * 0.03
		end = cover.position
		hit = cover
	else:
		cover = ray(origin, end, 1 | 8)
		if not cover.is_empty():
			end = cover.position
			hit = cover
	return {"origin": origin, "point": end, "hit": hit}

func begin_bag(opening: bool) -> void:
	visual.bag_target = 1.0 if opening else 0.0
	if opening:
		bag_yaw = visual.global_rotation.y + PI - 0.25
	clear_controls()
	cue("bag")

func reset_motion() -> void:
	climbing = false
	climb_surface_normal = Vector3.ZERO
	climb_surface = null
	terrain_climb_normal = Vector3.ZERO
	swimming = false
	hooking = 0
	mantle_time = 0
	swim_jump_time = 0
	cast_time = 0
	visual.mantle_contacts.clear()
	visual.mantle_progress = -1.0
	coyote = 0
	jump_lock = 0
	climb_detach = 0
	combo_timer = 0
	if is_instance_valid(hook_rope):
		hook_rope.queue_free()
	velocity = Vector3.ZERO
	clear_controls()

func take_damage(amount: int) -> void:
	if hit_cooldown > 0 or not active or dodge_invulnerable():
		return
	var runtime = magic_runtime()
	if runtime != null:
		amount = runtime.absorb_damage(amount)
	if amount <= 0:
		hit_cooldown = 0.28
		cue("grip", 1.2)
		return
	cancel_magic()
	hit_cooldown = 1.35
	var health_before: int = state.health
	state.health -= amount
	if game != null and "hud" in game and game.hud != null and game.hud.has_method("notify_damage"):
		game.hud.notify_damage(health_before, state.health, state.max_health)
	visual_action("hurt", float(amount))
	camera_trauma = minf(1, camera_trauma + 0.55)
	camera_kick(visual.global_basis.z if visual != null else Vector3.BACK, 0.09)
	feel_hit_stop(0.075)
	feel_rumble(65, 1.0)
	cue("hurt")
	if game != null:
		game.damage_flash = 0.5
	if state.health <= 0:
		respawn("Even a hero needs another try.")

func magic_runtime():
	return game.get("magic") if game != null else null

func grimoire_equipped() -> bool:
	return state != null and state.equipment == "grimoire" and state.unlocked.get("grimoire", false) == true

func magic_hands_busy() -> bool:
	return not active or state == null or state.health <= 0 or visual.supply_pour.active() or climbing or swimming or mantle_time > 0.0 or hooking > 0.0 or dodge_time > 0.0 or is_instance_valid(held_body) or throw_pending or visual.is_throwing() or visual.grapple_active() or visual.bag_target > 0.01 or visual.bag_progress > 0.01 or cast_time > 0.0 or beam_charging or beam_contact >= 0.0 or melee_contact >= 0.0

func cast_spell() -> bool:
	var runtime = magic_runtime()
	if runtime == null or not active: return false
	if not grimoire_equipped():
		toast("Equip your grimoire from the hotbar or spell library to cast magic.")
		return false


	visual.set_weapon(state.equipment)
	visual.set_held_item("")
	if game != null and game.has_method("update_placement_preview"):
		game.update_placement_preview()


	if ability_aiming and not beam_charging and beam_contact < 0.0:
		end_ability_aim(false)
	if magic_hands_busy(): return false
	var spell: Dictionary = state.equipped_spell()
	if spell.is_empty(): return false
	update_camera(0.0)
	var solution := ability_target()
	var destination: Vector3 = lock_target.global_position + Vector3.UP if is_instance_valid(lock_target) else solution.point
	var acquired: Node3D
	if str(spell.form) in ["beam", "touch"] and "levitate" in [spell.effect, spell.secondary_effect, spell.tertiary_effect]:
		acquired = runtime._acquire_levitation(spell)
		if acquired == null:
			toast("Aim at a movable object or regular creature within spell range.")
			return false
		destination = runtime._target_center(acquired)
	if not runtime.prepare(spell, destination, acquired):
		var reason := str(runtime.last_release_error)
		if reason.is_empty() and runtime.has_method("admission_reason") and runtime.cooldown_remaining <= 0.0 and state.mana >= preload("res://scripts/spellbook.gd").cost(spell):
			reason = runtime.admission_reason(spell, destination)
		toast(reason if not reason.is_empty() else "Your grimoire is recharging." if runtime.cooldown_remaining > 0.0 else "Use a Mana Potion to restore mana.")
		return false
	cancel_melee()
	attack_cooldown = 0.0
	visual.begin_grimoire_cast(Color(str(spell.color)), 0.62)
	if not visual.is_grimoire_casting():
		runtime.cancel()
		return false
	magic_contact = visual.grimoire_release_time()
	cast_time = 0.62
	if is_instance_valid(lock_target): face_lock_target()
	else: visual.rotation.y = yaw
	if game != null and game.get("audio") != null and game.audio.has_method("magic_cue"):
		game.audio.magic_cue(str(spell.element), "flight", 0.5)
	else: cue("bag", 1.16)
	return true

func cancel_magic() -> void:
	var was_casting := magic_contact >= 0.0
	magic_contact = -1.0
	var runtime = magic_runtime()
	if runtime != null:
		runtime.cancel()
		if runtime.has_method("end_concentration"): runtime.end_concentration()
		elif runtime.has_method("cancel_object_magic"): runtime.cancel_object_magic()
	if visual != null and visual.has_method("cancel_grimoire_cast"):
		was_casting = was_casting or visual.is_grimoire_casting()
		visual.cancel_grimoire_cast()
	if was_casting: cast_time = 0.0

func respawn(message: String = "") -> void:
	if game != null and game.has_method("on_player_death"):
		game.on_player_death()
	reset_motion()
	if is_instance_valid(held_body):
		release_held(false)
	state.health = state.max_health
	state.stamina = state.max_stamina
	global_position = state.checkpoint + Vector3.UP * 0.3
	velocity = Vector3.ZERO
	world.stream_at(global_position, true)
	toast(message)
	state.player_position = global_position
	state.save_game()

func cue(id: String, pitch_value: float = 1.0) -> void:
	if game != null and game.audio != null:
		game.audio.cue(id, pitch_value)

func toast(message: String) -> void:
	if game != null:
		game.toast(message)

func visual_action(kind: String, strength: float = 1.0, variant: int = 0) -> void:
	if visual != null and visual.has_method("trigger_action"):
		visual.trigger_action(kind, strength, variant)

func _exit_tree() -> void:
	if is_instance_valid(hook_rope) and not hook_rope.is_queued_for_deletion():
		hook_rope.queue_free()

func _water_height() -> float:
	if world.has_method("water_height_at"): return world.water_height_at(Vector2(global_position.x, global_position.z))
	return world.water_level
