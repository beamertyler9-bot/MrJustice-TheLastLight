extends "res://scripts/enemy.gd"

const BossModels = preload("res://scripts/boss_models.gd")

var adventure
var interior := "mine"
var max_health := 32
var arena_radius := 11.0
var enraged := false
var attack_type := ""
var next_attack := "cleave"
var committed_target := Vector3.ZERO
var committed_direction := Vector3.FORWARD
var ground_mark: MeshInstance3D
var phase_crown: MeshInstance3D
var body_scale := 1.0
var tell_duration := 1.0
var attack_count := 0
var boss_jaw: Node3D
var boss_tail: Node3D
var boss_bells: Array[Node3D] = []
var boss_cloth: Array[Node3D] = []

func _build_visual() -> void:
	BossModels.build(self, interior)

func _ready() -> void:
	max_health = Difficulty.health(max_health)
	health = max_health
	super._ready()
	set_meta("id", id)
	set_meta("is_boss", true)
	set_meta("display_name", display_name)
	set_meta("max_health", max_health)
	set_meta("health", health)
	add_to_group("deep_boss")
	for child in get_children():
		if child is CollisionShape3D:
			var shape := CapsuleShape3D.new()
			shape.radius = 0.67
			shape.height = 2.7
			child.shape = shape
			child.position.y = 1.38
	telegraph.queue_free()
	telegraph = B.ring(self, Vector3(0, 0.06, 0), 3.55, 0.1, B.mat("#ffc175", 0, 0.7))
	telegraph.visible = false
	ground_mark = B.ring(self, Vector3(0, 0.08, 0), 2.7, 0.12, B.mat("#91e0df", 0, 0.75))
	ground_mark.top_level = true
	ground_mark.visible = false
	visible = false
	model.scale = Vector3.ONE * body_scale

func _physics_process(dt: float) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or game == null or game.mode != "play" or health <= 0 or not is_instance_valid(game.player): return
	if bool(get_meta("magic_stasis", false)):
		return
	var real_dt := dt
	var magic_scale := clampf(float(get_meta("magic_time_scale", 1.0)), 0.1, 1.0)
	dt *= magic_scale
	if bool(get_meta("magic_steam", false)) and windup > 0: _cancel_attack()
	clock += dt
	_tick_hurt_reaction(dt)
	cooldown = maxf(0, cooldown - dt)
	recovery = maxf(0, recovery - dt)
	recoil *= exp(-dt * 8)
	var player = game.player
	var offset: Vector3 = player.global_position - home
	var in_arena := absf(offset.y) < 4.0 and Vector2(offset.x, offset.z).length() <= arena_radius + 1.5
	visible = game.world.interior_at(player.global_position) == interior and player.global_position.distance_to(home) < 65
	if not visible:
		_reset_abandoned_encounter()
		global_position = home
		velocity = Vector3.ZERO
		_cancel_attack()
		return
	if interior == "dungeon" and not adventure.seals_complete():
		_cancel_attack()
		return
	var delta: Vector3 = player.global_position - global_position
	var flat := Vector3(delta.x, 0, delta.z)
	var distance := flat.length()
	var speed := 0.0
	if not in_arena:
		_reset_abandoned_encounter()
		_cancel_attack()
		flat = home - global_position
		flat.y = 0
		speed = 2.2 if flat.length() > 0.4 else 0.0
	elif windup > 0:
		windup = maxf(0, windup - dt)
		if windup <= 0:


			_contact_pose()
			_resolve_attack()

			if not is_inside_tree() or is_queued_for_deletion(): return
			recovery = (0.9 if not enraged else 0.7) * Difficulty.RECOVERY_SCALE
			cooldown = (1.4 if not enraged else 0.95) * Difficulty.COOLDOWN_SCALE
	elif recovery <= 0 and cooldown <= 0 and hurt_stagger_time <= 0:
		if distance < 12 and absf(delta.y) < 2.3 and not bool(get_meta("magic_steam", false)) and _sight(player.global_position):


			var choice := "quake" if distance > 4.0 else next_attack
			_begin_attack(choice)
		elif distance > 2.1:
			speed = (2.15 if enraged else 1.65) * Difficulty.PURSUIT_SCALE
	elif recovery <= 0 and windup <= 0 and distance > 2.1:
		speed = (2.15 if enraged else 1.65) * Difficulty.PURSUIT_SCALE
	if windup > 0 or recovery > 0 or hurt_stagger_time > 0: speed = 0
	var direction := flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
	if windup <= 0 and recovery <= 0 and flat.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-flat.x, -flat.z), 1 - exp(-dt * 3.2))
	velocity.x = direction.x * speed * magic_scale + recoil.x * 0.35
	velocity.z = direction.z * speed * magic_scale + recoil.z * 0.35
	velocity.y -= 19 * real_dt * float(get_meta("magic_gravity_scale", 1.0))
	move_and_slide()
	var home_delta := global_position - home
	var horizontal := Vector2(home_delta.x, home_delta.z)
	if horizontal.length() > arena_radius:
		horizontal = horizontal.normalized() * arena_radius
		global_position.x = home.x + horizontal.x
		global_position.z = home.z + horizontal.y
	telegraph.visible = windup > 0 and attack_type == "cleave"
	ground_mark.visible = windup > 0 and attack_type == "quake"
	if ground_mark.visible:
		ground_mark.global_position = committed_target + Vector3.UP * 0.07
		ground_mark.scale = Vector3.ONE * (3.1 / 2.7 if enraged else 1.0)
		ground_mark.rotation.y += dt * 2
	if telegraph.visible: telegraph.scale = Vector3.ONE
	_animate_boss(dt, speed)

func _begin_attack(choice: String) -> void:
	attack_type = choice
	next_attack = "quake" if choice == "cleave" else "cleave"
	committed_target = game.player.global_position
	committed_target.y = home.y
	committed_direction = committed_target - global_position
	committed_direction.y = 0
	committed_direction = committed_direction.normalized()
	model.rotation.y = atan2(-committed_direction.x, -committed_direction.z)
	tell_duration = maxf(0.72, (0.95 if choice == "cleave" else 1.35) * (0.85 if enraged else 1.0) * Difficulty.WINDUP_SCALE)
	windup = tell_duration
	attack_count += 1
	game.audio.cue("bag")

func _resolve_attack() -> void:
	var p: Vector3 = game.player.global_position
	var delta := p - global_position
	var flat := Vector3(delta.x, 0, delta.z)
	var hit := false
	if attack_type == "cleave":
		hit = flat.length() < 3.5 and (flat.length() < 0.15 or committed_direction.dot(flat.normalized()) > 0.1) and absf(delta.y) < 1.9
	else:
		var from_mark := p - committed_target
		hit = Vector2(from_mark.x, from_mark.z).length() < (3.1 if enraged else 2.7) and absf(from_mark.y) < 1.9
	if hit and _sight(p):
		game.player.take_damage(Difficulty.damage(2))
		if not is_inside_tree() or is_queued_for_deletion(): return
	game.audio.cue("impact")
	game.burst(global_position + Vector3.UP * 0.2 if attack_type == "cleave" else committed_target, Color("#ffd188" if attack_type == "cleave" else "#94d9dc"))
	ground_mark.visible = false
	telegraph.visible = false

func _sight(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, target + Vector3.UP * 0.9, 1 | 8)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _cancel_attack() -> void:
	windup = 0
	recovery = 0
	telegraph.visible = false
	ground_mark.visible = false

func _animate_boss(dt: float, speed: float) -> void:
	if animation_profile.is_empty():
		animation_profile = Motion.Profiles.for_species("embermaw" if interior == "mine" else "bellkeeper")
	var charge := clampf(1.0 - windup / tell_duration, 0.0, 1.0) if windup > 0 else 0.0
	gait_weight = lerpf(gait_weight, clampf(speed, 0.0, 1.0), 1.0 - exp(-maxf(0.0, dt) * 7.0))
	var settling := clampf(recovery / ((0.7 if enraged else 0.9) * Difficulty.RECOVERY_SCALE), 0.0, 1.0)
	var walk := gait_weight if windup <= 0 and recovery <= 0 else 0.0
	var breath := sin(clock * (1.25 if interior == "mine" else 0.93)) * 0.0025 * (1.0 - walk)
	model.scale = Vector3.ONE * body_scale * Vector3(1.0 - breath * 0.2, 1.0 + breath, 1.0)
	core.material_override = hurt_glow if hurt_timer > 0 else (attack_glow if windup > 0 or enraged else normal_glow)
	phase_crown.visible = enraged
	if interior == "mine":
		_animate_furnace(charge, settling, walk)
	else:
		_animate_bellkeeper(charge, settling, walk)
		phase_crown.rotation.y = clock * 0.35


	var load := sin(charge * PI)
	for index in range(boss_bells.size()):
		var pendulum := clock * 2.35 - float(index) * 0.47
		Motion._rotate(boss_bells[index], Vector3(sin(pendulum - 0.6) * (0.008 + walk * 0.053) - load * 0.07 + settling * 0.035, 0, sin(pendulum) * (0.018 + walk * 0.075) + load * 0.065))
	for index in range(boss_cloth.size()):
		var lag := float(index) * 0.63
		Motion._rotate(boss_cloth[index], Vector3(sin(clock * 1.43 - lag) * (0.01 + walk * 0.032) + load * 0.045 - settling * 0.022, sin(clock * 0.87 - lag) * 0.012, sin(clock * 1.72 - lag) * (0.008 + walk * 0.02)))
	Motion.enemy_hurt_pose(self)

func _animate_furnace(charge: float, settling: float, walk: float) -> void:
	var cycle := clock * float(animation_profile.rate)
	var load := smoothstep(0.0, 0.66, charge) * (1.0 - smoothstep(0.82, 1.0, charge))
	var release := smoothstep(0.76, 1.0, charge)


	Motion._place(model, Vector3(0, absf(sin(cycle)) * 0.017 * walk - load * 0.035 - sin(settling * PI) * 0.022, 0))
	model.rotation.x = -load * 0.06 + release * 0.052 + settling * 0.046
	model.rotation.z = sin(cycle) * 0.012 * walk + sin(clock * 0.83) * 0.003 * (1.0 - walk)
	Motion._rotate(head, Vector3(-load * 0.21 + release * 0.075 + settling * 0.065 + sin(clock * 1.25) * 0.026 * (1.0 - walk), sin(clock * 0.63) * 0.023 * (1.0 - walk), -model.rotation.z * 0.52))
	Motion._rotate(boss_jaw, Vector3(-0.035 - load * 0.28 + release * 0.09 - settling * 0.055 - sin(clock * 1.25) * 0.014, 0, 0))
	Motion._rotate(boss_tail, Vector3(sin(clock * 1.13 - 0.8) * 0.018, sin(cycle - 0.95) * (0.032 + walk * 0.11) + load * 0.055, -model.rotation.z * 0.72))
	for i in range(2):
		var raw := sin(cycle + i * PI)
		var stride := signf(raw) * pow(absf(raw), 1.65) * walk
		var side := -1.0 if i == 0 else 1.0
		Motion._rotate(feet[i], Vector3(-stride * 0.2 - load * 0.035, 0, side * load * 0.025))
		Motion._rotate(knees[i], Vector3(-pow(maxf(0.0, raw), 1.25) * walk * 0.34 - load * 0.055, 0, 0))
		var attack := _attack_arm_pose(charge) * (1.0 + side * 0.025 * sin(charge * PI))
		Motion._rotate(arms[i], Vector3(attack if windup > 0 else 0.56 * settling + stride * 0.18, side * load * 0.035, side * (0.035 + load * 0.09)))
		Motion._rotate(forearms[i], Vector3(-0.045 - maxf(0.0, -raw) * walk * 0.25 - load * 0.37 - settling * 0.055, 0, 0))

func _animate_bellkeeper(charge: float, settling: float, walk: float) -> void:
	var cycle := clock * float(animation_profile.rate)
	var load := smoothstep(0.0, 0.68, charge) * (1.0 - smoothstep(0.82, 1.0, charge))
	var release := smoothstep(0.76, 1.0, charge)


	Motion._place(model, Vector3(sin(cycle) * 0.013 * walk, absf(sin(cycle)) * 0.014 * walk - load * 0.045 - sin(settling * PI) * 0.028, 0))
	model.rotation.x = -load * 0.085 + release * 0.058 + settling * 0.055
	model.rotation.z = sin(cycle) * 0.017 * walk - load * 0.012
	Motion._rotate(head, Vector3(-load * 0.1 + release * 0.025 + sin(clock * 0.93) * 0.018 * (1.0 - walk), sin(clock * 0.51) * 0.034 * (1.0 - walk), -model.rotation.z * 0.58))
	for i in range(2):
		var raw := sin(cycle + i * PI)
		var stride := signf(raw) * pow(absf(raw), 1.72) * walk
		var side := -1.0 if i == 0 else 1.0
		Motion._rotate(feet[i], Vector3(stride * 0.23 - load * 0.035, 0, 0))
		Motion._rotate(knees[i], Vector3(-pow(maxf(0.0, -raw), 1.35) * walk * 0.39 - load * 0.045, 0, 0))
		var attack := _attack_arm_pose(charge) + side * 0.055 * sin(charge * PI)
		var carry := (0.035 if i == 0 else 0.095) * (1.0 - settling)
		Motion._rotate(arms[i], Vector3(attack if windup > 0 else 0.6 * settling - stride * (0.2 if i == 0 else 0.11) + carry, side * load * 0.045, side * (0.055 + load * (0.13 if i == 0 else 0.09))))
		Motion._rotate(forearms[i], Vector3(-0.1 - load * (0.29 if i == 0 else 0.38) - settling * 0.035, 0, 0))

func _attack_arm_pose(progress: float) -> float:
	var peak := (2.16 if interior == "mine" else 2.3) if attack_type == "cleave" else (1.72 if interior == "mine" else 1.85)
	var contact := 0.56 if attack_type == "cleave" else 0.35


	if progress < 0.58: return lerpf(0, peak, smoothstep(0.0, 0.58, progress))
	if progress < 0.72: return peak
	return lerpf(peak, contact, smoothstep(0.72, 1.0, progress))

func _contact_pose() -> void:
	for arm in arms: Motion._rotate(arm, Vector3(_attack_arm_pose(1.0), 0, 0))
	for elbow in forearms: Motion._rotate(elbow, Vector3(-0.1, 0, 0))
	model.rotation.x = 0.055 if interior == "mine" else 0.06

func take_damage(amount: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or health <= 0 or amount <= 0 or not _player_in_encounter(): return
	if amount >= health and not _can_drop_death_reward(): return
	health = maxi(0, health - amount)
	set_meta("health", health)
	_begin_hurt_reaction(false)
	game.audio.cue("impact")
	game.burst(global_position + Vector3.UP * 1.5, Color("#ffe4ad"))
	Feel.flash(self, 0.8)
	Feel.number(self, amount, 3.0 * body_scale)
	_animate_boss(0.0, 0.0)
	if not enraged and health > 0 and health <= max_health / 2:
		enraged = true
		set_meta("phase", 2)
		_cancel_attack()
		recovery = 1.35
		phase_crown.visible = true
		game.toast(display_name + " awakens! Watch the ground and dodge after the tell.")
	if health <= 0:
		_cancel_attack()
		remove_from_group("enemy")
		collision_layer = 0
		adventure.boss_defeated(self)
		_drop_light_essence(8, false)
		Feel.defeat(game, self, 3.0 * body_scale)
		if game.get("feel") != null: game.feel.hit_stop(0.14)
		var tween := create_tween().set_parallel()
		tween.tween_property(model, "scale", Vector3.ONE * 0.15, 0.65)
		tween.tween_property(model, "position:y", 0.3, 0.65)
		tween.chain().tween_callback(queue_free)

func receive_impulse(impulse: Vector3) -> void:
	super.receive_impulse(impulse * 0.35)

func _player_in_encounter() -> bool:
	if game == null or not is_instance_valid(game.player): return false
	var offset: Vector3 = game.player.global_position - home
	return game.world.interior_at(game.player.global_position) == interior and absf(offset.y) < 4.0 and Vector2(offset.x, offset.z).length() <= arena_radius + 1.5 and (interior != "dungeon" or adventure.seals_complete())

func _reset_abandoned_encounter() -> void:
	if health >= max_health and not enraged: return
	health = max_health
	set_meta("health", health)
	enraged = false
	set_meta("phase", 1)
	hurt_timer = 0
	hurt_stagger_time = 0
	hurt_stagger_cooldown = 0
	cooldown = 0
	recoil = Vector3.ZERO
	phase_crown.visible = false
