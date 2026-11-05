extends CharacterBody3D

const Motion = preload("res://scripts/creature_motion.gd")
const B = preload("res://scripts/build.gd")
const EnemyModels = preload("res://scripts/enemy_models.gd")
const CreatureCatalog = preload("res://scripts/creature_catalog.gd")
const Difficulty = preload("res://scripts/enemy_difficulty.gd")
const Feel = preload("res://scripts/combat_feel.gd")
const HURT_DURATION := 0.3
const WINDUP_TIME: float = 0.65
const RECOVERY_TIME: float = 0.52
const BASE_SPECIES = {
	"rootling_sentinel": {"name": "Rootling Sentinel", "model": "RootlingSentinel", "hp": 4, "speed": 2.3, "reach": 1.6, "windup": 0.72, "recovery": 0.65, "cooldown": 2.3, "damage": 1, "radius": 0.32, "height": 1.6},
	"moss_guardian": {"name": "Moss guardian", "model": "MossGuardian", "hp": 6, "speed": 1.85, "reach": 1.8, "windup": 0.65, "recovery": 0.52, "cooldown": 2.1, "damage": 1, "radius": 0.43, "height": 1.8},
	"glass_skitter": {"name": "Glass skitter", "model": "GlassSkitter", "hp": 4, "speed": 3.25, "reach": 1.55, "windup": 0.48, "recovery": 0.65, "cooldown": 1.65, "damage": 1, "radius": 0.45, "height": 0.9},
	"thorn_wolf": {"name": "Thorn wolf", "model": "ThornWolf", "hp": 5, "speed": 3.0, "reach": 2.0, "windup": 0.62, "recovery": 0.72, "cooldown": 1.9, "damage": 1, "radius": 0.4, "height": 1.25},
	"cinder_wisp": {"name": "Cinder wisp", "model": "CinderWisp", "hp": 5, "speed": 1.8, "reach": 12.0, "windup": 0.95, "recovery": 0.75, "cooldown": 2.8, "damage": 1, "radius": 0.35, "height": 1.6},
	"frost_brute": {"name": "Frost brute", "model": "FrostBrute", "hp": 10, "speed": 1.35, "reach": 2.5, "windup": 1.05, "recovery": 1.0, "cooldown": 2.9, "damage": 2, "radius": 0.6, "height": 2.3},
	"wild_boar": {"name": "Ironhide boar", "model": "IronhideBoar", "hp": 7, "speed": 2.25, "reach": 7.0, "windup": 0.85, "recovery": 1.0, "cooldown": 3.2, "damage": 1, "radius": 0.48, "height": 1.15}
}
static var SPECIES: Dictionary = Difficulty.profiles(BASE_SPECIES.merged(CreatureCatalog.enemy_profiles()))
var game
var home: Vector3
var id: String = ""
var species_id: String = "moss_guardian"
var profile: Dictionary = SPECIES.moss_guardian
var display_name: String = "Moss guardian"
var health: int = int(profile.hp)
var clock: float = 0.0
var cooldown: float = 0.0
var windup: float = 0.0
var recovery: float = 0.0
var model: Node3D
var visual_rig: Dictionary = {}
var head: Node3D
var core: MeshInstance3D
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var feet: Array[Node3D] = []
var knees: Array[Node3D] = []
var gait_weight := 0.0

var animation_profile: Dictionary = {}
var animation_rig: Dictionary = {}
var leaves: Array[Node3D] = []
var telegraph: MeshInstance3D
var recoil: Vector3 = Vector3.ZERO
var hurt_timer: float = 0.0
var hurt_stagger_time := 0.0
var hurt_stagger_cooldown := 0.0
var hurt_side := 1.0
var normal_glow: Material
var attack_glow: Material
var hurt_glow: Material
var rest_scale := Vector3.ONE
var attack_direction := Vector3.FORWARD
var charge_time := 0.0
var charge_contact := false
var projectiles: Array[Dictionary] = []
var noticed := false
var calm_time := 0.0
var wander_target := Vector3.INF
var wander_wait := 0.0

func configure_species(kind: String) -> void:

	if is_node_ready(): return
	species_id = kind if SPECIES.has(kind) else "moss_guardian"
	profile = SPECIES[species_id]
	display_name = profile.name
	health = int(profile.hp)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 1 | 8
	floor_snap_length = 0.6
	var c = CollisionShape3D.new()
	var s = CapsuleShape3D.new()
	s.radius = float(profile.radius)
	s.height = float(profile.height)
	c.shape = s
	c.position.y = s.height * 0.5 + 0.04
	add_child(c)
	model = Node3D.new()
	model.name = profile.model
	add_child(model)
	normal_glow = B.mat("#9deccb", 0, 0.55)
	attack_glow = B.mat("#ffe292", 0, 0.75)
	hurt_glow = B.mat("#f3fff1", 0, 0.8)
	_build_visual()
	model.scale = rest_scale
	hurt_side = -1.0 if posmod(hash(id if id != "" else species_id), 2) == 0 else 1.0
	add_to_group("enemy")
	set_meta("health", health)
	set_meta("max_health", health)
	set_meta("name", display_name)
	set_meta("display_name", display_name)
	if profile.get("boss", false): set_meta("is_boss", true)
	set_meta("species", species_id)
	telegraph = B.ring(self, Vector3(0, 0.045, 0), 0.65, 0.035, B.mat("#ffce83", 0, 0.65))
	telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	telegraph.visible = false



func _build_visual() -> void:
	EnemyModels.build(self)

func _physics_process(dt: float) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or game == null or game.mode != "play" or health <= 0:
		return
	if bool(get_meta("magic_held", false)):
		_tick_projectiles(dt, game.player)
		if not is_inside_tree() or is_queued_for_deletion(): return
		windup = 0.0
		charge_time = 0.0
		telegraph.visible = false
		_animate(dt, 0.0)
		return
	var real_dt := dt
	if bool(get_meta("magic_stasis", false)):
		_tick_projectiles(real_dt, game.player)
		return
	var magic_scale := clampf(float(get_meta("magic_time_scale", 1.0)), 0.1, 1.0)
	dt *= magic_scale
	if bool(get_meta("magic_steam", false)) and windup > 0:
		windup = 0; recovery = maxf(recovery, 0.3)
	clock += dt
	cooldown = maxf(0, cooldown - dt)
	_tick_hurt_reaction(dt)
	recovery = maxf(0, recovery - dt)
	recoil *= exp(-dt * 9)
	var player = game.player
	var world = game.world
	var home_chunk = Vector2i(floori(home.x / world.CHUNK), floori(home.z / world.CHUNK))
	var here_chunk = Vector2i(floori(global_position.x / world.CHUNK), floori(global_position.z / world.CHUNK))
	var indoor_floor: bool = world.has_method("interior_at") and not world.interior_at(home).is_empty() and world.interior_at(home) == world.interior_at(global_position)
	visible = (indoor_floor or (world.chunks.has(home_chunk) and world.chunks.has(here_chunk))) and player.global_position.distance_to(home) <= 80 and _same_region(player)
	if not visible:
		velocity = Vector3.ZERO
		global_position = home
		windup = 0
		charge_time = 0
		recovery = 0
		telegraph.visible = false
		_clear_projectiles()
		noticed = false
		return
	_tick_projectiles(real_dt, player)
	if not is_inside_tree() or is_queued_for_deletion(): return
	var offset: Vector3 = player.global_position - global_position
	var flat: Vector3 = Vector3(offset.x, 0, offset.z)
	var distance = flat.length()
	var aggro := 17.0 if species_id == "cinder_wisp" else 14.0
	var pursuing: bool = distance < aggro and global_position.distance_to(home) < 28
	var speed: float = float(profile.speed) if pursuing else 0.0
	var travel: Vector3 = flat
	# Spotting Mr. Justice: a "!" and a hop, once per encounter.
	if pursuing:
		calm_time = 0.0
		wander_target = Vector3.INF
		if not noticed:
			noticed = true
			Feel.notice(self, float(profile.height))
			if is_on_floor(): velocity.y = 3.2
			cooldown = maxf(cooldown, 0.35)
	else:
		calm_time += dt
		if calm_time > 4.0: noticed = false
	if speed == 0 and global_position.distance_to(home) > 4.5:
		travel = home - global_position
		travel.y = 0
		speed = 1.0
	elif speed == 0:
		# At ease: amble about near home, pausing to look around.
		wander_wait -= dt
		if wander_target == Vector3.INF and wander_wait <= 0.0:
			var angle := randf() * TAU
			wander_target = home + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, 3.5)
		if wander_target != Vector3.INF:
			travel = wander_target - global_position; travel.y = 0
			speed = float(profile.speed) * 0.32
			if travel.length() < 0.4 or is_on_wall():
				wander_target = Vector3.INF; wander_wait = randf_range(2.0, 5.0); speed = 0.0
	if pursuing and (species_id in ["thorn_wolf", "glass_skitter"] or profile.get("form", "") in ["hound", "cat"]) and distance > 3.0:

		var side := -1.0 if posmod(hash(id), 2) == 0 else 1.0
		travel += Vector3(-flat.z, 0, flat.x).normalized() * minf(distance * 0.48, 3.0) * side
	if pursuing and (species_id == "cinder_wisp" or profile.get("attack", "") == "ranged"):
		if distance < 5.0: travel = -flat
		elif distance < 9.0: travel = Vector3(-flat.z, 0, flat.x) * 0.45
	if pursuing and distance < float(profile.reach) and cooldown <= 0 and windup <= 0 and charge_time <= 0 and recovery <= 0 and hurt_stagger_time <= 0 and not bool(get_meta("magic_steam", false)) and _strike_clear(player, float(profile.reach)):
		windup = float(profile.windup)
		cooldown = float(profile.cooldown)
		attack_direction = flat.normalized() if distance > 0.1 else -model.global_basis.z
	if windup > 0:
		var before_windup := windup
		windup = maxf(0, windup - dt)
		if before_windup > 0.2 and windup <= 0.2: Feel.warn(self)
		if windup <= 0:


			_contact_pose()
			match str(profile.get("attack", species_id)):
				"cinder_wisp", "ranged": _launch_projectile()
				"wild_boar", "charge":
					charge_time = 0.58
					charge_contact = false
				_:

					if _strike_clear(player, float(profile.reach) + 0.45):
						player.take_damage(int(profile.damage))
						if not is_inside_tree() or is_queued_for_deletion(): return
			if charge_time <= 0: recovery = float(profile.recovery)
	if windup > 0 or recovery > 0 or hurt_stagger_time > 0:
		speed = 0
	telegraph.visible = windup > 0
	if telegraph.visible:
		telegraph.scale = Vector3.ONE * (0.8 + (1 - windup / float(profile.windup)) * 0.7)
	core.material_override = hurt_glow if hurt_timer > 0 else (attack_glow if windup > 0 or charge_time > 0 else normal_glow)

	if flat.length() > 0.1 and recovery <= 0 and charge_time <= 0:
		var turn_rate = 1.8 if windup > 0 else 5.0
		var facing_target: Vector3 = attack_direction if windup > 0 else flat
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-facing_target.x, -facing_target.z), 1.0 - exp(-dt * turn_rate))
	var direction = travel.normalized() if travel.length() > 0.2 else Vector3.ZERO
	if charge_time > 0:
		direction = attack_direction
		speed = 8.0
		charge_time = maxf(0.0, charge_time - dt)
	velocity.x = direction.x * speed * magic_scale + recoil.x
	velocity.z = direction.z * speed * magic_scale + recoil.z
	velocity.y -= 19 * real_dt * float(get_meta("magic_gravity_scale", 1.0))
	move_and_slide()
	if (species_id == "wild_boar" or profile.get("attack", "") == "charge") and speed > 6.0:
		if not charge_contact and _strike_clear(player, 1.65):
			charge_contact = true
			_contact_pose()
			player.take_damage(int(profile.damage))
			if not is_inside_tree() or is_queued_for_deletion(): return
		if charge_time <= 0 or is_on_wall():
			charge_time = 0
			recovery = float(profile.recovery)
	_animate(dt, speed)

func _same_region(player: Node3D) -> bool:
	var world = game.world
	if not world.has_method("interior_at"): return true
	var home_interior: String = world.interior_at(home)
	if world.interior_at(player.global_position) != home_interior: return false
	if home_interior == "" and player.global_position.y < world.height_at(player.global_position.x, player.global_position.z) - 4.0:
		return false
	return true

func _launch_projectile() -> void:
	if projectiles.size() >= 3: return
	var ember = Node3D.new()
	ember.name = "CinderBolt"
	add_child(ember)
	ember.top_level = true
	ember.global_position = global_position + Vector3.UP * 1.02
	B.facet(ember, Vector3.ZERO, Vector3(0.23, 0.23, 0.4), B.mat("#ffb760", 0, 0.8))
	B.facet(ember, Vector3(0, 0, 0.18), Vector3(0.13, 0.13, 0.4), B.mat("#e97343", 0, 0.5))
	ember.rotation.y = atan2(-attack_direction.x, -attack_direction.z)
	projectiles.append({"node": ember, "direction": attack_direction, "life": 2.4})

func _tick_projectiles(dt: float, player: Node3D) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var bolt: Dictionary = projectiles[i]
		var node: Node3D = bolt.node
		var local_dt := dt
		if float(bolt.get("stasis", 0.0)) > 0:
			local_dt = maxf(0.0, dt - float(bolt.stasis)); bolt.stasis = maxf(0.0, float(bolt.stasis) - dt)
			if local_dt <= 0: continue
		var start := node.global_position
		var end: Vector3 = start + bolt.direction * 8.0 * local_dt
		var ray = PhysicsRayQueryParameters3D.create(start, end, 1 | 8 | 16)
		var blocked := not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var center := player.global_position + Vector3.UP * 0.95
		var nearest := Geometry3D.get_closest_point_to_segment(center, start, end)
		bolt.life = float(bolt.life) - local_dt
		var hit := not blocked and center.distance_to(nearest) < 0.47
		if blocked or hit or float(bolt.life) <= 0:
			node.queue_free()
			projectiles.remove_at(i)
			if hit:

				player.take_damage(int(profile.damage))
				if not is_inside_tree() or is_queued_for_deletion(): return
		else:
			node.global_position = end

func _clear_projectiles() -> void:
	for bolt in projectiles:
		if is_instance_valid(bolt.node): bolt.node.queue_free()
	projectiles.clear()

func _strike_clear(player: Node3D, reach: float) -> bool:
	var delta = player.global_position - global_position
	if Vector2(delta.x, delta.z).length() >= reach or absf(delta.y) >= 1.35:
		return false
	var flat = Vector3(delta.x, 0, delta.z)
	var facing = -model.global_basis.z
	facing.y = 0
	if flat.length() > 0.15 and facing.normalized().dot(flat.normalized()) < 0.35:
		return false
	var start = global_position + Vector3.UP * 1.08
	var end = player.global_position + Vector3.UP * 0.95
	var query = PhysicsRayQueryParameters3D.create(start, end, 1 | 8)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _contact_pose() -> void:
	Motion.enemy_contact_pose(self)

func _animate(dt: float, speed: float) -> void:
	Motion.enemy_pose(self, dt, speed)


func _animate_creature(dt: float, speed: float) -> void:
	Motion.enemy_pose(self, dt, speed)

func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	if amount >= health and not _can_drop_death_reward(): return
	health = maxi(0, health - amount)
	set_meta("health", health)
	_begin_hurt_reaction()
	game.audio.cue("impact", randf_range(0.92, 1.08))
	game.burst(global_position + Vector3.UP, Color("#adcfc4"))
	Feel.flash(self)
	Feel.number(self, amount, float(profile.height))
	if game.get("feel") != null: game.feel.squash(self, 0.5)
	# Getting hit always gets an enemy's attention.
	if not noticed: noticed = true; calm_time = 0.0
	core.material_override = hurt_glow
	_animate(0.0, 0.0)
	if health <= 0:
		_clear_projectiles()
		remove_from_group("enemy")
		set_deferred("collision_layer", 0)
		game.state.taken[id] = true
		_drop_light_essence(2)
		game.toast(display_name + " quieted")
		if game.get("quests") != null:
			game.quests.enemy_defeated(id, global_position, species_id)
		core.material_override = hurt_glow
		Feel.defeat(game, self, float(profile.height))
		var tween = create_tween().set_parallel()
		tween.tween_property(model, "scale", Vector3.ONE * 0.15, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(model, "position:y", 0.28, 0.3)
		tween.tween_property(model, "rotation:z", 0.18, 0.3)
		tween.chain().tween_callback(queue_free)

func _tick_hurt_reaction(dt: float) -> void:
	hurt_timer = maxf(0.0, hurt_timer - dt)
	hurt_stagger_time = maxf(0.0, hurt_stagger_time - dt)
	hurt_stagger_cooldown = maxf(0.0, hurt_stagger_cooldown - dt)

func _begin_hurt_reaction(interrupt := true) -> void:
	hurt_timer = HURT_DURATION


	if hurt_stagger_cooldown > 0.0: return
	hurt_stagger_time = 0.23 if interrupt else 0.18


	hurt_stagger_cooldown = 1.6
	if interrupt:
		windup = 0.0
		charge_time = 0.0
		cooldown = maxf(cooldown, 0.45)
		telegraph.visible = false

func _light_essence_source_id() -> String:
	var identity := id if id != "" else "%s:%.2f:%.2f:%.2f" % [species_id, home.x, home.y, home.z]
	return "enemy_drop:" + identity

func _can_drop_death_reward() -> bool:
	if game.has_method("can_drop_light_essence"):
		return game.can_drop_light_essence(_light_essence_source_id())
	var context_script: Script = game.get_script()
	if context_script != null and context_script.resource_path == "res://scripts/game.gd":
		push_error("Enemy death requires Game.can_drop_light_essence")
		return false
	return true

func _drop_light_essence(amount: int, legacy_credit := true) -> void:
	if game.has_method("spawn_light_essence"):
		game.spawn_light_essence(global_position + Vector3.UP * 0.65, amount, _light_essence_source_id())
		return


	var context_script: Script = game.get_script()
	if context_script != null and context_script.resource_path == "res://scripts/game.gd":
		push_error("Enemy death requires Game.spawn_light_essence")
		return
	var legacy_state = game.get("state")
	if legacy_credit and legacy_state != null: legacy_state.award_reward("shard", amount)

func receive_impulse(impulse: Vector3) -> void:
	if not impulse.is_finite(): return
	recoil = (recoil + Vector3(impulse.x, 0, impulse.z)).limit_length(30.0)
	velocity.y = clampf(velocity.y + impulse.y, -20.0, 20.0)

func freeze_magic_projectiles(center: Vector3, radius: float, duration: float, limit := 3) -> int:
	var affected := 0
	for bolt in projectiles:
		if affected >= limit: break
		if not is_instance_valid(bolt.node): continue
		var point: Vector3 = bolt.node.global_position
		if point.distance_squared_to(center) > radius * radius: continue
		var query := PhysicsRayQueryParameters3D.create(center, point, 1 | 8 | 16)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			bolt.stasis = maxf(float(bolt.get("stasis", 0.0)), duration); affected += 1
	return affected
