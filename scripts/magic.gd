extends Node3D


const Spellbook = preload("res://scripts/spellbook.gd")
const ObjectMagic = preload("res://scripts/object_magic.gd")
const MagicWeave = preload("res://scripts/magic_weave.gd")
const Presentation = preload("res://scripts/spell_presentation.gd")
const MAX_SCHEDULED := 48
const MAX_RESOLVES_PER_TICK := 12
const MAX_APPLICATIONS := 96
const MAX_TARGETS := 24
const MAX_PROJECTILES := 42
const MAX_VISUALS := 64
const MAX_STATUSES := 48
const MAX_MATERIALS := 96
const COLLISION_MASK := 1 | 4 | 8 | 16
var game
var object_magic = ObjectMagic.new()
var weave = MagicWeave.new()
var presentation = Presentation.new()
var stage_events: Array:
	get: return weave.stage_events
var constructs: Array:
	get: return weave.constructs
var guardians: Array:
	get: return weave.guardians
var _step_offset := Vector3(0, 0.6196, 0)
var scheduled: Array = []
var pending: Dictionary = {}
var last_release_error := ""
var cooldown_remaining := 0.0
var ward_remaining := 0.0
var ward_strength := 0
var projectiles: Array = []
var visuals: Array = []
var statuses: Array = []
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _spheres: Dictionary = {}
var _target_spheres: Dictionary = {}
var _step_shape: CapsuleShape3D
var _sequence := 0

func setup(owner_game) -> void:
	game = owner_game
	object_magic.setup(self)
	weave.setup(self)
	presentation.setup(self)
	visuals = presentation.visuals
	name = "SpellSimulation"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	set_physics_process(false)
	_step_shape = CapsuleShape3D.new()
	_step_shape.radius = 0.18
	_step_shape.height = 1.2192
	for child in game.player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			_step_shape = child.shape.duplicate()
			_step_offset = child.position
			break

func _usable() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or game.state == null: return false
	if game.player.is_queued_for_deletion() or not game.player.is_inside_tree() or int(game.state.health) <= 0: return false
	if game.player.get("active") == false: return false
	var mode: Variant = game.get("mode")
	return mode == null or mode == "play"

func _hands_busy() -> bool:
	var player = game.player
	if player.has_method("magic_hands_busy"): return bool(player.magic_hands_busy())
	var cast_time: Variant = player.get("cast_time")
	return _physical_hands_busy() or ((cast_time is float or cast_time is int) and float(cast_time) > 0.0)

func _physical_hands_busy() -> bool:
	var player = game.player
	for key in ["held_body", "throw_pending", "climbing", "swimming", "beam_charging", "ability_aiming"]:
		var value: Variant = player.get(key)
		if value is Object and is_instance_valid(value): return true
		if value is bool and value: return true
	for key in ["hooking", "mantle_time", "dodge_time", "attack_cooldown"]:
		var value: Variant = player.get(key)
		if (value is float or value is int) and float(value) > 0: return true
	for key in ["beam_contact", "melee_contact"]:
		var value: Variant = player.get(key)
		if (value is float or value is int) and float(value) >= 0: return true
	return false

func _equipped() -> bool:
	return is_instance_valid(game) and is_instance_valid(game.player) and (not game.player.has_method("grimoire_equipped") or bool(game.player.grimoire_equipped()))

func can_cast(raw: Dictionary) -> bool:
	var spell := Spellbook.sanitize(raw)
	return not spell.is_empty() and _equipped() and _usable() and pending.is_empty() and cooldown_remaining <= 1.0e-05 and game.state.mana >= Spellbook.cost(spell) and not _hands_busy() and weave.can_admit(spell, Vector3.ZERO, false)

static func _valid_point(point: Vector3) -> bool:
	return point.is_finite() and maxf(absf(point.x), maxf(absf(point.y), absf(point.z))) <= 100000.0

## How charged the spell being released is (0..1); read by delivery code during release.
var release_charge := 0.0

func prepare(raw: Dictionary, target: Vector3, acquired: Node3D = null, charge: float = 0.0) -> bool:
	last_release_error = ""
	if not _valid_point(target) or not can_cast(raw): return false
	var spell := Spellbook.sanitize(raw)
	last_release_error = weave.admission_reason(spell, target)
	if not last_release_error.is_empty(): return false
	pending = {"spell": spell, "target": target, "caster": game.player.get_instance_id(), "age": 0.0}
	if acquired != null: pending["acquired"] = weakref(acquired)
	pending["charge"] = clampf(charge, 0.0, 1.0) if is_finite(charge) else 0.0
	return true

func _acquire_levitation(spell: Dictionary) -> Node3D:
	var camera: Camera3D = game.player.camera
	var mark: Vector2 = game.player.get_viewport().get_visible_rect().size * Vector2(0.5, 332.0 / 720.0)
	var start := camera.project_ray_origin(mark)
	var end := start + camera.project_ray_normal(mark) * (_line_delivery_reach(spell) + start.distance_to(_origin()))
	var hit := _ray(start, end)
	# Rocks in the world are static until something picks them up: aiming levitation at one
	# turns it into a loose rock body first.
	if not hit.is_empty() and not _target_allowed(hit.get("collider"), spell):
		var rock = preload("res://scripts/loose_stone_carry.gd").rock_owner(hit.get("collider"))
		if rock != null and _origin().distance_to(rock.global_position) <= _line_delivery_reach(spell) + 1.5:
			var body = preload("res://scripts/loose_stone_carry.gd").lift(game, rock)
			if body != null and object_magic.eligible(body, spell) and object_magic.can_hold_body(body): return body
	if hit.is_empty() or not _target_allowed(hit.get("collider"), spell): hit = _sweep(start, end, 0.2)
	if hit.is_empty() or not _target_allowed(hit.get("collider"), spell): return null
	var candidate: Node3D = hit.collider
	if not object_magic.eligible(candidate, spell) and not object_magic.creature_eligible(candidate): return null
	if candidate is RigidBody3D and not object_magic.can_hold_body(candidate): return null
	if not _line_delivery_hits(candidate, spell, _origin()): return null
	return candidate


func _line_delivery_reach(spell: Dictionary) -> float:
	return 2.0 if spell.form == "touch" else float(spell.range)

func _line_delivery_hits(target: Node3D, spell: Dictionary, origin: Vector3) -> bool:
	if not is_instance_valid(target): return false
	var direction := (_target_center(target) - origin).normalized()
	var hit := _sweep(origin, origin + direction * _line_delivery_reach(spell), float(spell.size) * 0.7)
	return not hit.is_empty() and hit.get("collider") == target

func cancel() -> void:
	pending.clear()

func release() -> bool:
	last_release_error = ""
	if pending.is_empty(): return false
	var transaction: Dictionary = pending
	pending = {}
	if not _equipped() or not _usable() or _physical_hands_busy() or game.player.get_instance_id() != transaction.caster or cooldown_remaining > 1.0e-05: return false
	var spell: Dictionary = transaction.spell
	var origin := _spell_origin(spell)
	var target: Vector3 = transaction.target
	if transaction.get("acquired") is WeakRef:
		var selected = transaction.acquired.get_ref()
		if not _target_allowed(selected, spell) or not _line_delivery_hits(selected, spell, origin):
			last_release_error = "The levitation target moved out of reach or behind cover. Try again."
			return false
		if selected is RigidBody3D and not object_magic.can_hold_body(selected):
			last_release_error = "Too many sustained object effects. Let one finish before lifting another."
			return false
		target = _target_center(selected)
	last_release_error = weave.admission_reason(spell, target)
	if not last_release_error.is_empty(): return false
	if not game.state.spend_mana(Spellbook.cost(spell)):
		last_release_error = "Your mana changed before release."; return false
	cooldown_remaining = Spellbook.cooldown(spell)
	_sequence += 1
	release_charge = float(transaction.get("charge", 0.0))
	weave.begin(spell, origin, target, _sequence)
	release_charge = 0.0
	_cast_circles(spell, origin, target)
	if game.get("audio") != null:
		if game.audio.has_method("magic_cue"): game.audio.magic_cue(str(spell.element), "release", float(spell.power))
		elif game.audio.has_method("cue"): game.audio.cue("beam", 0.85 + float(spell.power) * 0.04)
	return true

func _deliver(spell: Dictionary, origin: Vector3, target: Vector3, direction: Vector3, context: Dictionary) -> void:
	match spell.form:
		"volley", "orbitals": _volley(spell, origin, direction, context)
		"beam", "touch": _beam_cast(spell, origin, direction, context)
		"burst", "field": _burst_cast(spell, origin, target, context)
		"cone": weave.cone(spell, origin, direction, context)
		"rain": weave.rain(spell, origin, target, context)
		"trap": weave.trap(spell, origin, target, context)
		"wall": weave.wall(spell, origin, target, context)
		"summon": weave.summon(spell, origin, target, context)
		"ward":
			ward_strength = int(spell.power) + 1
			ward_remaining = 3.0 + float(spell.power) * 0.8
			_glyph(game.player.global_position + Vector3.UP * 0.62, spell, "ward", ward_remaining, 0.6)
		"mend":
			game.state.health = mini(game.state.max_health, game.state.health + maxi(1, int(ceilf(float(spell.power) * 0.6))))
			_glyph(game.player.global_position + Vector3.UP * 0.2, spell, "mend", 1.25, 1.0)
		"step": _step(spell, target)
		"strike": _strike_cast(spell, origin, target, context)

func _crown_center() -> Vector3:
	var visual: Variant = game.player.get("visual")
	if is_instance_valid(visual) and is_instance_valid(visual.get("lantern")):
		return (visual.lantern as Node3D).global_position + Vector3.UP * 0.38
	return game.player.global_position + Vector3.UP * 2.2

## Set by the player while a charged spell's own circle is already on screen.
var suppress_hand_circle := false
## While a hand beam is still pouring out, the hero keeps his arm raised toward its end.
var beam_hold := 0.0
var beam_hold_point := Vector3.ZERO

## The element's magic circle where the spell is cast: standing in front of the hand (or
## lantern), facing the aim; and flat on the ground under spells that land on an area or
## surround Mr. Justice.
func _cast_circles(spell: Dictionary, origin: Vector3, target: Vector3) -> void:
	var Circle = preload("res://scripts/magic_circle.gd")
	var direction := (target - origin).normalized()
	if direction.length_squared() < 0.5: direction = -game.player.camera.global_basis.z if is_instance_valid(game.player.camera) else Vector3.FORWARD
	if not suppress_hand_circle and str(spell.get("motif", "none")) != "railgun":
		Circle.at_hand(self, spell, origin + direction * 0.35, direction, 0.42 + float(spell.power) * 0.06, 0.75)
	var form := str(spell.form)
	if form in ["ward", "mend", "step", "summon"]:
		Circle.on_ground(self, spell, game.player.global_position, 1.1, 1.1)
	elif form in ["burst", "field", "rain", "strike", "trap", "wall"]:
		var aim := origin + (target - origin).limit_length(float(spell.range))
		var ground := _ray(aim + Vector3.UP * 1.5, aim + Vector3.DOWN * 30.0, 1)
		var point: Vector3 = ground.position if not ground.is_empty() else aim
		if form == "rain":
			# Rain pours out of a circle hanging in the sky over the target.
			var sky_height := rain_drop_height(spell)
			if str(spell.get("motif", "none")) in ["storm_cloud", "frost_cloud"]:
				# Cloud spells: the circle hangs just under the cloud it pours from.
				sky_height = clampf(float(spell.get("rain_height", 7.0)) * 0.5, 3.2, 4.2) - 0.8
			var lid := _ray(point + Vector3.UP * 0.2, point + Vector3.UP * sky_height, 1)
			var sky: Vector3 = lid.position + Vector3.DOWN * 0.15 if not lid.is_empty() else point + Vector3.UP * sky_height
			var pour := float(spell.count) * float(spell.stagger) + 1.0
			Circle.in_sky(self, spell, sky, clampf(float(spell.radius) * 1.1, 1.2, 5.0), clampf(pour, 1.6, 6.0), game.player.global_position)
			return
		var size := float(spell.wall_width) * 0.55 if form == "wall" else float(spell.radius)
		var duration := float(spell.duration) if form in ["field", "trap"] else 1.2
		Circle.on_ground(self, spell, point, clampf(size, 0.8, 5.0), clampf(duration, 1.0, 8.0))

## How high rain spells pour from: the sky circle, low enough to stay in view.
func rain_drop_height(spell: Dictionary) -> float:
	return minf(float(spell.get("rain_height", 6.0)), 4.8)

## Lantern spells leave from the lantern in Mr. Justice's head; everything else from the hand.
func _spell_origin(spell: Dictionary) -> Vector3:
	if str(spell.get("origin", "hand")) == "lantern":
		var visual: Variant = game.player.get("visual")
		if is_instance_valid(visual) and is_instance_valid(visual.get("lantern")):
			var lamp: Vector3 = visual.lantern.global_position
			var ahead: Vector3 = -game.player.camera.global_basis.z if is_instance_valid(game.player.camera) else -visual.global_basis.z
			return lamp + ahead.normalized() * 0.32
	return _origin()

## Where an arcing (lob) throw lands and how it is launched. Charge throws further.
func lob_launch(spell: Dictionary, origin: Vector3, aim_target: Vector3, charge: float) -> Dictionary:
	var flat := Vector3(aim_target.x - origin.x, 0.0, aim_target.z - origin.z)
	var heading: Vector3 = flat.normalized() if flat.length_squared() > 1.0e-4 else -game.player.global_basis.z
	var reach := lerpf(7.0, 30.0, clampf(charge, 0.0, 1.0))
	var landing := aim_target
	if flat.length() > reach or flat.length() < 1.5:
		landing = origin + heading * reach
		var ground := _ray(landing + Vector3.UP * 12.0, landing + Vector3.DOWN * 40.0)
		landing.y = ground.position.y if not ground.is_empty() else origin.y - 1.2
	var distance := Vector2(landing.x - origin.x, landing.z - origin.z).length()
	var flight := clampf(distance / maxf(float(spell.speed), 1.0) * 1.5, 0.45, 1.9)
	var velocity := (landing - origin) / flight + Vector3.UP * 5.5 * flight
	return {"velocity": velocity, "landing": landing, "time": flight}

## A bolt (or pillar) of the element out of the sky onto the aimed ground.
func _strike_cast(spell: Dictionary, origin: Vector3, target: Vector3, context: Dictionary) -> void:
	var aim := origin + (target - origin).limit_length(float(spell.range))
	var ground := _ray(aim + Vector3.UP * 2.0, aim + Vector3.DOWN * 40.0)
	var center: Vector3 = ground.position + Vector3.UP * 0.05 if not ground.is_empty() else aim
	var stage := weave._stage(context)
	if not stage.is_empty(): stage.point = center
	presentation.sky_strike(center + Vector3.UP * 22.0, center, spell, 0.55 + release_charge * 0.3, clampf(float(spell.radius) / 1.8, 1.0, 2.4))
	_glyph(center, spell, "burst", 0.8, float(spell.radius))
	_contact(null, center, spell, context, true)
	if is_instance_valid(game.player):
		game.player.camera_trauma = minf(1.0, game.player.camera_trauma + 0.35)
		if game.get("feel") != null: game.feel.rumble(45, 0.7)

func cast(spell: Dictionary, target: Vector3) -> bool:
	return prepare(spell, target) and release()

func absorb_damage(amount: int) -> int:
	if amount <= 0: return 0
	if ward_remaining <= 0 or ward_strength <= 0: return amount
	var absorbed := mini(amount, ward_strength)
	ward_strength -= absorbed
	if ward_strength == 0: ward_remaining = 0.0
	return amount - absorbed

func tick(dt: float) -> void:
	if not is_finite(dt) or dt <= 0: return
	if not _usable(): _tick_slice(dt); return


	var remaining := minf(dt, 180.0)
	while remaining > 1.0e-06:
		var step_time := minf(0.1, remaining)
		_tick_slice(step_time); remaining -= step_time
		if not _usable(): break
	if dt > 180.0 and _usable():
		cooldown_remaining = maxf(0.0, cooldown_remaining - (dt - 180.0)); game.state.recover_mana(dt - 180.0)

func _tick_slice(dt: float) -> void:
	if not _usable():
		if not is_instance_valid(game) or game.state == null or not is_instance_valid(game.player) or game.player.is_queued_for_deletion() or int(game.state.health) <= 0:
			clear_effects()
		else:
			cancel()
			cancel_object_magic()
		return
	if not _equipped():


		cancel()
		end_concentration()
	object_magic.tick(dt)
	_tick_scheduled(dt)
	cooldown_remaining = maxf(0.0, cooldown_remaining - dt)
	beam_hold = maxf(0.0, beam_hold - dt)
	game.state.recover_mana(dt)
	ward_remaining = maxf(0.0, ward_remaining - dt)
	if ward_remaining <= 0: ward_strength = 0
	weave.tick(dt)
	if not pending.is_empty():
		pending.age += dt
		if pending.age > 2.0: cancel()
	_tick_projectiles(dt)
	_tick_statuses(dt)
	_tick_visuals(dt)

func _origin() -> Vector3:
	var chest: Vector3 = game.player.global_position + Vector3.UP * 0.82
	var visual: Variant = game.player.get("visual")
	if is_instance_valid(visual) and visual.get("hands") is Array and visual.hands.size() > 1 and is_instance_valid(visual.hands[1]):
		var palm: Vector3 = visual.hands[1].global_position

		var hit := _ray(chest, palm)
		return hit.position + hit.normal * 0.06 if not hit.is_empty() else palm
	return chest

func _exclude() -> Array[RID]:
	var result: Array[RID] = []
	if is_instance_valid(game) and is_instance_valid(game.player) and game.player is CollisionObject3D:
		result.append(game.player.get_rid())
	return result

func _ray(start: Vector3, end: Vector3, mask: int = COLLISION_MASK) -> Dictionary:
	if start.distance_squared_to(end) < 1.0e-06 or not is_inside_tree(): return {}
	var query := PhysicsRayQueryParameters3D.create(start, end, mask, _exclude())
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _sphere(radius: float) -> SphereShape3D:
	var key := clampi(roundi(radius * 100.0), 8, 50)
	if not _spheres.has(key):
		var shape := SphereShape3D.new()
		shape.radius = float(key) * 0.01
		_spheres[key] = shape
	return _spheres[key]

func _sweep(start: Vector3, end: Vector3, radius: float, extra_exclude: Array[RID] = []) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sphere(radius)
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.collision_mask = COLLISION_MASK
	query.exclude = _exclude() + extra_exclude
	query.margin = 0.008
	var overlaps := space.intersect_shape(query, 8)
	if not overlaps.is_empty(): return {"collider": overlaps[0].collider, "position": start}
	query.motion = end - start
	var fractions := space.cast_motion(query)
	if fractions.size() == 2 and fractions[0] < 1.0:
		var contact := start.lerp(end, minf(1.0, fractions[1] + 0.001))
		query.transform.origin = contact
		query.motion = Vector3.ZERO
		query.margin = 0.018
		var rest := space.get_rest_info(query)
		if not rest.is_empty(): return {"collider": instance_from_id(rest.collider_id), "position": contact, "normal": rest.normal}
		overlaps = space.intersect_shape(query, 8)
		if not overlaps.is_empty(): return {"collider": overlaps[0].collider, "position": contact}
		return {"collider": null, "position": contact}
	var ray_query := PhysicsRayQueryParameters3D.create(start, end, COLLISION_MASK, _exclude() + extra_exclude)
	return space.intersect_ray(ray_query)

func _target_center(enemy: Node3D) -> Vector3:
	for child in enemy.get_children():
		if child is CollisionShape3D and not child.disabled: return child.global_position
	return enemy.global_position if enemy is RigidBody3D else enemy.global_position + Vector3.UP

func _live(enemy: Variant) -> bool:
	return is_instance_valid(enemy) and enemy is Node3D and enemy.is_inside_tree() and not enemy.is_queued_for_deletion() and enemy.get_world_3d() == get_world_3d() and (enemy.is_in_group("enemy") or enemy.is_in_group("damageable")) and enemy.has_method("take_damage") and (enemy.get("health") == null or int(enemy.get("health")) > 0)

func _clear_line(start: Vector3, end: Vector3, target: Node3D) -> bool:
	var hit := _ray(start, end)
	return hit.is_empty() or hit.collider == target

func _volley(spell: Dictionary, origin: Vector3, direction: Vector3, context: Dictionary) -> void:
	for index in range(int(spell.count)):
		_spawn_or_schedule(spell, origin, direction, context, index, float(index) * float(spell.stagger) if spell.form != "orbitals" else 0.0)
	_glyph(origin, spell, "cast", 0.22, 0.32)

func _spawn_or_schedule(spell: Dictionary, origin: Vector3, direction: Vector3, context: Dictionary, index: int, delay: float) -> void:
	if delay > 1.0e-05:
		weave.consume(context, "events")
		scheduled.append({"kind": "launch", "spell": spell, "context": context, "origin": origin, "direction": direction, "index": index, "wait": delay})
		weave.work(context, 1)
	else: _spawn_bolt(spell, origin, direction, context, index)

func _spawn_bolt(spell: Dictionary, origin: Vector3, direction: Vector3, context: Dictionary, index: int) -> void:

	if projectiles.size() >= MAX_PROJECTILES: return
	weave.consume(context, "projectiles")
	var ratio := 0.0 if int(spell.count) == 1 else float(index) / float(spell.count - 1) - 0.5
	var angle := deg_to_rad(float(spell.spread)) * ratio
	var aim := direction.rotated(Vector3.UP, angle) if spell.trajectory in ["fan", "seeking"] or spell.form == "orbitals" else direction
	var release_target: Vector3 = context.get("aim_target", origin + direction * float(spell.range))
	if spell.form == "orbitals":
		var aimed_hit := _ray(origin, release_target)
		if not aimed_hit.is_empty() and _target_allowed(aimed_hit.collider, spell): release_target = _target_center(aimed_hit.collider)
	var node := _projectile_node(spell); node.global_position = origin
	if aim.length_squared() > 0.5: node.quaternion = Quaternion(Vector3.FORWARD, aim)
	var right := aim.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.1: right = Vector3.RIGHT
	var up := right.cross(aim).normalized()
	projectiles.append({"node": node, "spell": spell, "direction": aim, "origin": origin, "position": origin,
		"right": right, "up": up, "phase": float(index) * TAU / float(spell.count), "offset": Vector3.ZERO,
		"age": 0.0, "flight_age": 0.0, "context": context, "target": null, "seek_wait": 0.0, "seek_interval": 0.14 + float(index) * 0.006,
		"ignored": [], "contacts": 0, "distance": 0.0, "visited": [], "held": spell.form == "orbitals", "hold_wait": float(spell.hold_time) + float(index) * float(spell.stagger), "stasis": 0.0,
		"release_target": release_target,
		"velocity": _launch_velocity(spell, origin, aim, release_target, context)})
	weave.work(context, 1)

func _launch_velocity(spell: Dictionary, origin: Vector3, aim: Vector3, release_target: Vector3, context: Dictionary) -> Vector3:
	if spell.trajectory not in ["lob", "ballistic"]: return aim * float(spell.speed)
	var pool: Variant = context.get("pool")
	var charge := float(pool.get("charge", 0.0)) if pool is Dictionary else 0.0
	if spell.trajectory == "ballistic": return ballistic_launch(spell, origin, release_target, charge).velocity
	return lob_launch(spell, origin, release_target, charge).velocity

const BALLISTIC_GRAVITY := 9.0

## Shot straight at the aim point; gravity then pulls it down. Charge shoots it faster.
func ballistic_launch(spell: Dictionary, origin: Vector3, aim_target: Vector3, charge: float) -> Dictionary:
	var direction := (aim_target - origin).normalized()
	if direction.length_squared() < 0.5: direction = -game.player.camera.global_basis.z if is_instance_valid(game.player.camera) else Vector3.FORWARD
	var velocity := direction * float(spell.speed) * (1.0 + clampf(charge, 0.0, 1.0) * 0.8)
	return {"velocity": velocity, "time": 2.2, "gravity": BALLISTIC_GRAVITY}

func _tick_projectiles(dt: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		if index >= projectiles.size(): continue
		var bolt: Dictionary = projectiles[index]
		var source_stage := weave._stage(bolt.context)
		if not source_stage.is_empty(): source_stage.point = _origin() if bolt.get("held", false) else bolt.position
		if not is_instance_valid(bolt.node):
			_retire_projectile(index); continue
		var local_dt := dt
		if float(bolt.get("stasis", 0.0)) > 0:
			local_dt = maxf(0.0, dt - float(bolt.stasis)); bolt.stasis = maxf(0.0, float(bolt.stasis) - dt)
			if local_dt <= 0: continue
		if bolt.get("held", false):
			bolt.hold_wait -= local_dt
			if float(bolt.hold_wait) > 0:
				var phase: float = float(bolt.phase) + (float(bolt.spell.hold_time) - float(bolt.hold_wait)) * 2.2
				# Held orbitals sit as a crown: a level ring circling above Mr. Justice's head
				# that travels with him, then each piece fires from its place in the ring.
				var desired: Vector3 = _crown_center() + Vector3(cos(phase), 0.0, sin(phase)) * minf(float(bolt.spell.orbit_radius), 0.75)
				var barrier := _sweep(bolt.position, desired, float(bolt.spell.size))
				bolt.position = barrier.position if not barrier.is_empty() else desired
				bolt.node.global_position = bolt.position
				bolt.node.quaternion = Quaternion(Vector3.FORWARD, Vector3(cos(phase), 0.0, sin(phase)))
				bolt.node.scale = Vector3.ONE * 0.72
				_animate_projectile(bolt); continue
			local_dt = minf(local_dt, -float(bolt.hold_wait)); bolt.held = false; bolt.origin = bolt.position
			bolt.node.scale = Vector3.ONE
			bolt.direction = (bolt.release_target - bolt.position).normalized(); bolt.velocity = bolt.direction * float(bolt.spell.speed)
		var remaining := maxf(0.0, float(bolt.spell.lifetime) - float(bolt.age))
		var travel_time := minf(local_dt, remaining)
		var steps := 1 if bolt.spell.trajectory in ["straight", "fan"] else clampi(ceili(travel_time * 60.0), 1, 96)
		var step_time := travel_time / float(steps)
		var impacted := false
		for substep in range(steps):
			var before: Vector3 = bolt.position
			var after: Vector3 = _advance_bolt(bolt, step_time)
			after = before + (after - before).limit_length(maxf(0.0, float(bolt.spell.range) - float(bolt.distance)))
			var ignored: Array[RID] = []; ignored.assign(bolt.ignored)
			var hit := _sweep(before, after, float(bolt.spell.size), ignored)
			if not hit.is_empty():
				if _target_allowed(hit.collider, bolt.spell):
					_contact(hit.collider, hit.position, bolt.spell, bolt.context)
					bolt.visited.append(hit.collider.get_instance_id())
				elif is_instance_valid(hit.collider) and hit.collider is Node3D:
					weave.hit(hit.collider, hit.position + hit.get("normal", Vector3.UP) * 0.06, bolt.context, true)
				var impact_spell: Dictionary = bolt.spell.duplicate(); impact_spell["_surface_normal"] = hit.get("normal", Vector3.UP)
				_glyph(hit.position, impact_spell, "impact", 0.45, 0.35 + float(bolt.spell.size) * 1.4)
				bolt.contacts += 1
				if bolt.spell.impact == "pierce" and _target_allowed(hit.collider, bolt.spell) and bolt.contacts <= int(bolt.spell.pierces):
					bolt.ignored.append(hit.collider.get_rid())
					after = hit.position + bolt.direction * 0.035
				elif bolt.spell.impact == "bounce" and hit.get("normal") is Vector3 and (hit.normal as Vector3).length_squared() > 0.5 and bolt.contacts <= int(bolt.spell.bounces):
					bolt.direction = (bolt.direction as Vector3).bounce(hit.normal).normalized()
					bolt.velocity = (bolt.velocity as Vector3).bounce(hit.normal)
					after = hit.position + hit.normal * (float(bolt.spell.size) + 0.04)
				elif bolt.spell.impact == "chain" and bolt.contacts <= int(bolt.spell.chains):
					var next = _chain_target(hit.position, bolt.spell, bolt.visited, hit.collider)
					if next != null:
						if hit.collider is CollisionObject3D: bolt.ignored.append(hit.collider.get_rid())
						bolt.direction = (_target_center(next) - hit.position).normalized()
						after = hit.position + bolt.direction * 0.04
					else: impacted = true
				else: impacted = true
				if impacted:
					bolt.position = hit.position; bolt.node.global_position = hit.position
					break
			bolt.distance += before.distance_to(after)
			bolt.position = after
			bolt.node.global_position = after
			var heading := after - before
			if heading.length_squared() > 1.0e-06: bolt.node.quaternion = Quaternion(Vector3.FORWARD, heading.normalized())
		if impacted or float(bolt.distance) >= float(bolt.spell.range) - 1.0e-05 or float(bolt.age) >= float(bolt.spell.lifetime) - 1.0e-05:
			_retire_projectile(index)
		else:
			_animate_projectile(bolt)

func _advance_bolt(bolt: Dictionary, dt: float) -> Vector3:
	bolt.age += dt
	bolt.flight_age = float(bolt.get("flight_age", 0.0)) + dt
	var trajectory: String = bolt.spell.trajectory
	if trajectory == "seeking":

		bolt.seek_wait -= dt
		if float(bolt.seek_wait) <= 0.0:
			bolt.target = _seek_target(bolt.position, bolt.spell)
			bolt.seek_wait = float(bolt.seek_interval)
		var selected: Variant = bolt.target.get_ref() if bolt.target is WeakRef else null
		if _target_allowed(selected, bolt.spell):
			var desired: Vector3 = (_target_center(selected) - bolt.position).normalized()
			bolt.direction = (bolt.direction as Vector3).slerp(desired, minf(1.0, dt * 4.0 * float(bolt.spell.homing))).normalized()
		return bolt.position + bolt.direction * float(bolt.spell.speed) * dt
	if trajectory == "returning" and float(bolt.age) >= float(bolt.spell.return_time):
		var home: Vector3 = _origin()
		var to_home: Vector3 = home - bolt.position
		if to_home.length_squared() < 0.16: bolt.age = float(bolt.spell.lifetime); return home
		bolt.direction = to_home.normalized()
		return bolt.position + bolt.direction * minf(float(bolt.spell.speed) * dt, to_home.length())
	if trajectory == "spiral":
		var amplitude := float(bolt.spell.orbit_radius) * minf(1.0, float(bolt.age) * 3.0)
		var offset: Vector3 = (bolt.right * cos(float(bolt.age) * 7 + bolt.phase) + bolt.up * sin(float(bolt.age) * 7 + bolt.phase)) * amplitude
		var next: Vector3 = bolt.position + bolt.direction * float(bolt.spell.speed) * dt + offset - bolt.offset
		bolt.offset = offset
		return next
	if trajectory == "wave":
		var offset: Vector3 = bolt.right * sin(float(bolt.age) * 9.0 + float(bolt.phase)) * (0.2 + float(bolt.spell.spread) * 0.015)
		var result: Vector3 = bolt.position + bolt.direction * float(bolt.spell.speed) * dt + offset - bolt.offset
		bolt.offset = offset
		return result
	if trajectory == "rising":
		bolt.velocity += Vector3.UP * 7.0 * dt
		return bolt.position + bolt.velocity * dt
	if trajectory == "lob":
		var displacement: Vector3 = bolt.velocity * dt + Vector3.DOWN * 5.5 * dt * dt
		bolt.velocity += Vector3.DOWN * 11.0 * dt
		return bolt.position + displacement
	if trajectory == "ballistic":
		var drop: Vector3 = bolt.velocity * dt + Vector3.DOWN * 0.5 * BALLISTIC_GRAVITY * dt * dt
		bolt.velocity += Vector3.DOWN * BALLISTIC_GRAVITY * dt
		return bolt.position + drop
	if trajectory == "helix":
		var age: float = bolt.age
		var amplitude := minf(0.58, 0.2 + float(bolt.spell.spread) * 0.008) * minf(1.0, age * 7.0)
		var offset: Vector3 = (bolt.right * cos(age * 11.0 + bolt.phase) + bolt.up * sin(age * 11.0 + bolt.phase)) * amplitude
		var next: Vector3 = bolt.position + bolt.direction * float(bolt.spell.speed) * dt + offset - bolt.offset
		bolt.offset = offset
		return next
	return bolt.position + bolt.direction * float(bolt.spell.speed) * dt

func _seek_target(position: Vector3, spell: Dictionary) -> Variant:
	var candidates: Array = []
	for target in _spatial_targets(position, 12.0, spell):
		candidates.append({"node": target, "distance": position.distance_squared_to(_target_center(target))})
	candidates.sort_custom(func (a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for index in range(mini(4, candidates.size())):
		var target: Node3D = candidates[index].node
		if _clear_line(position, _target_center(target), target): return weakref(target)
	return null

func _chain_clear(start: Vector3, target: Node3D, source: Node3D) -> bool:
	var excluded := _exclude()
	if source is CollisionObject3D: excluded.append(source.get_rid())
	var query := PhysicsRayQueryParameters3D.create(start, _target_center(target), COLLISION_MASK, excluded)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

func _beam_cast(spell: Dictionary, origin: Vector3, direction: Vector3, context: Dictionary) -> void:
	var end := origin + direction * _line_delivery_reach(spell)
	var hit := _sweep(origin, end, float(spell.size) * 0.7)
	if not hit.is_empty():
		end = hit.position
		if _target_allowed(hit.collider, spell): _contact(hit.collider, end, spell, context)
		elif is_instance_valid(hit.collider) and hit.collider is Node3D: weave.hit(hit.collider, end + hit.get("normal", Vector3.UP) * 0.06, context, true)
	var stage := weave._stage(context)
	if not stage.is_empty(): stage.point = end
	if spell.targeting in ["caster", "projectiles"]: _contact(null, origin if spell.targeting == "caster" else end, spell, context, true)
	if "levitate" in [spell.effect, spell.secondary_effect, spell.tertiary_effect]:
		# Levitation is a fine thread of magic, not a blast.
		_beam_visual(origin, end, spell, 0.3, 0.025)
	else:
		var node: Variant = presentation.beam(origin, end, spell, 0.26 + release_charge * 0.55, float(spell.size) * (1.0 + release_charge * 0.9))
		# Hand beams: the arm stays raised for as long as the beam pours out.
		if is_instance_valid(node) and str(spell.get("origin", "hand")) != "lantern":
			beam_hold = maxf(beam_hold, float(node.get("life")))
			beam_hold_point = end
	var impact_spell := spell.duplicate(); impact_spell["_surface_normal"] = hit.get("normal", Vector3.UP)
	_glyph(end, impact_spell, "beam_end" if hit.is_empty() else "impact", 0.5, 0.65)

func _burst_cast(spell: Dictionary, origin: Vector3, target: Vector3, context: Dictionary) -> void:
	var delta := target - origin
	var center := origin + delta.limit_length(float(spell.range))
	var hit := _ray(origin, center)
	if not hit.is_empty(): center = hit.position + hit.normal * 0.08
	var stage := weave._stage(context)
	if not stage.is_empty(): stage.point = center
	_glyph(center, spell, "field" if spell.form == "field" else "burst", float(spell.duration) if spell.form == "field" else 0.8, float(spell.radius))
	_beam_visual(origin, center, spell, 0.16, 0.035)
	_contact(null, center, spell, context, true)
	if not hit.is_empty() and is_instance_valid(hit.collider) and hit.collider is Node3D and not _target_allowed(hit.collider, spell): weave.hit(hit.collider, center, context, true)

func _elemental_hit(enemy: Node3D, spell: Dictionary, context: Dictionary, chain: bool = true) -> void:
	if not _live(enemy): return
	var position := _target_center(enemy)
	var wet := has_status(enemy, "wet")
	var frozen := has_status(enemy, "frozen")
	var damage := Spellbook.damage(spell)
	if frozen and int(spell.power) >= 4 and spell.element != "frost" and int(context.pool.reactions) > 0:
		context.pool.reactions -= 1; damage += mini(3, maxi(1, int(spell.power) / 2)); weave.remove_status(enemy, "frozen")
		_glyph(position, spell, "shatter", 0.55, 0.7)
	enemy.take_damage(damage)
	# Spell impacts get a lighter version of melee feedback, scaled by damage.
	if game != null and game.get("feel") != null:
		var heavy := clampf(float(damage) / 4.0, 0.25, 1.0)
		game.feel.hit_stop(0.025 + 0.045 * heavy if _live(enemy) else 0.1)
		game.feel.rumble(int(12 + 18 * heavy), 0.35 + 0.4 * heavy)
		game.feel.squash(enemy, 0.5 + 0.4 * heavy)
		if is_instance_valid(game.player): game.player.camera_trauma = minf(1.0, game.player.camera_trauma + 0.1 + 0.15 * heavy)
	if not _live(enemy): return
	match spell.element:
		"water":
			set_status(enemy, "wet", minf(10.0, float(spell.duration) + 1.0))
			_glyph(position, spell, "wet", 0.6, 0.4)
		"flame":
			if wet and int(context.pool.reactions) > 0:
				context.pool.reactions -= 1; weave.remove_status(enemy, "wet"); set_status(enemy, "steam", 1.5)
				if enemy.get("cooldown") != null: enemy.set("cooldown", maxf(1.5, float(enemy.cooldown)))
				_glyph(position, spell, "steam", 1.0, 0.9)
				return
			set_status(enemy, "burning", 1.4)
			for status in statuses:
				if status.target.get_ref() == enemy:
					status.elapsed = 0.0; status.pulses = 2; return
			if statuses.size() < MAX_STATUSES: statuses.append({"target": weakref(enemy), "elapsed": 0.0, "pulses": 2, "spell": spell})
		"frost":
			var duration: float = (0.9 + float(spell.power) * 0.2) * (2.0 if wet else 1.0) * (0.5 if enemy.is_in_group("deep_boss") else 1.0)
			if wet and int(context.pool.reactions) > 0: context.pool.reactions -= 1; weave.remove_status(enemy, "wet")
			set_status(enemy, "frozen", duration)
			if enemy.get("recovery") != null and not enemy.has_method("freeze_magic_projectiles"): enemy.set("recovery", maxf(float(enemy.recovery), duration))
			_glyph(position, spell, "frost", 0.9, 0.5)
		"storm":
			if not chain: return
			var scan := spell.duplicate(); scan.radius = 3.0 + float(spell.radius) * 0.35
			var contacts := 0
			for chosen in _near_targets(position, scan, [enemy.get_instance_id()]):
				if not _live(chosen) or not _chain_clear(position, chosen, enemy): continue
				if wet and not has_status(chosen, "wet"): continue
				if int(context.pool.budget) <= 0 or int(context.pool.reactions) <= 0: break
				context.pool.budget -= 1; context.pool.reactions -= 1; contacts += 1
				_beam_visual(position, _target_center(chosen), spell, 0.24, 0.055)
				chosen.take_damage(maxi(1, int(ceilf(Spellbook.damage(spell) * (0.75 if wet else 0.5)))))
				if wet: weave.remove_status(chosen, "wet")
				if contacts >= (3 if wet else 1): break
			if wet: weave.remove_status(enemy, "wet")
		"grove":
			if not context.pool.healed:
				context.pool.healed = true; game.state.health = mini(game.state.max_health, game.state.health + 1)
				_glyph(game.player.global_position + Vector3.UP * 0.62, spell, "mend", 0.6, 0.4)
		"light", "wind":
			var direction: Vector3 = position - (game.player.global_position + Vector3.UP * 0.62); direction.y = 0
			if enemy.has_method("receive_impulse"): enemy.receive_impulse(direction.normalized() * (2.0 + float(spell.power)))
		"shadow":
			if enemy.get("cooldown") != null: enemy.set("cooldown", maxf(float(enemy.cooldown), 1.5 + float(spell.power) * 0.3))
			_glyph(position, spell, "shadow", 0.65, 0.55)
		"void": weave.apply_enemy("gravity_well", enemy, spell, context.origin, context.direction)
		"time": weave.apply_enemy("slow", enemy, spell, position, context.direction)
		"earth", "metal":
			if enemy.has_method("receive_impulse"): enemy.receive_impulse(context.direction * float(spell.power) * 0.6)

func _tick_statuses(dt: float) -> void:
	for index in range(statuses.size() - 1, -1, -1):
		var status: Dictionary = statuses[index]
		var enemy = status.target.get_ref()
		if not _live(enemy): statuses.remove_at(index); continue
		status.elapsed += dt
		while status.elapsed >= 0.7 and status.pulses > 0 and _live(enemy):
			status.elapsed -= 0.7
			status.pulses -= 1
			enemy.take_damage(1)
			if is_instance_valid(enemy): _glyph(_target_center(enemy), status.spell, "impact", 0.28, 0.28)
		if status.pulses <= 0 or not _live(enemy): statuses.remove_at(index)

func _step(spell: Dictionary, target: Vector3) -> void:
	var start: Vector3 = game.player.global_position
	# Teleports go where Mr. Justice is facing (his movement direction while running).
	var visual: Variant = game.player.get("visual")
	var direction: Vector3 = -(visual as Node3D).global_basis.z if is_instance_valid(visual) else target - (start + Vector3.UP * 0.82)
	direction.y = 0.0
	if direction.length_squared() < 0.001: direction = Vector3.FORWARD
	direction = direction.normalized()
	var motion := direction * float(spell.radius)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _step_shape
	query.transform = Transform3D(Basis.IDENTITY, start + _step_offset)
	query.motion = motion
	query.margin = 0.025
	query.collision_mask = COLLISION_MASK
	query.exclude = _exclude()
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	var fraction := 1.0
	if fractions.size() == 2: fraction = clampf(fractions[0] - 0.015, 0.0, 1.0)
	var end := start + motion * fraction
	var ground := _ray(end + Vector3.UP * 0.45, end + Vector3.DOWN * 0.55, 1 | 8)
	if not ground.is_empty() and ground.normal.y > 0.6:
		var grounded: Vector3 = end
		grounded.y = ground.position.y + 0.025
		query.motion = Vector3.ZERO
		query.transform.origin = grounded + _step_offset
		if space.intersect_shape(query, 1).is_empty(): end = grounded
	_glyph(start + Vector3.UP * 0.15, spell, "step", 0.65, 0.8)
	game.player.global_position = end
	presentation.dash_trail(spell, game.player, start + Vector3.UP * 1.0 - direction * 0.28)
	if game.player is CharacterBody3D:
		game.player.velocity.x = 0.0; game.player.velocity.z = 0.0
	if is_instance_valid(game.world) and game.world.has_method("stream_at"): game.world.stream_at(end)
	_glyph(end + Vector3.UP * 0.15, spell, "step", 0.65, 0.8)

func _material(hex: String, soft: bool = false, glow: float = 1.0, opacity: float = 1.0) -> StandardMaterial3D:
	var key := hex + (":soft" if soft else ":solid") + ":%.2f:%.2f" % [glow, opacity]
	if _materials.has(key): return _materials[key]
	if _materials.size() >= MAX_MATERIALS: _materials.erase(_materials.keys()[0])
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	# Cel-shaded like the world: banded toon diffuse, a coloured rim and only a light glow,
	# so walls, summons and solid spell pieces read as objects instead of flat cut-outs.
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = 0.55
	material.rim_enabled = true
	material.rim = 0.55
	material.rim_tint = 0.35
	material.emission_enabled = true
	material.emission = Color(hex)
	material.emission_energy_multiplier = 0.22 * glow
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if soft or opacity < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = (0.42 if soft else 1.0) * opacity
	_materials[key] = material
	return material

func _spell_material(spell: Dictionary, accent: bool = false, soft: bool = false) -> StandardMaterial3D:
	return _material(spell.accent if accent else spell.color, soft, float(spell.glow), float(spell.opacity))

func _mesh(style: String) -> Mesh:
	if _meshes.has(style): return _meshes[style]
	var result: Mesh
	match style:
		"cube":
			var cube := BoxMesh.new(); cube.size = Vector3.ONE * 1.5; result = cube
		"embers":
			var ember := CylinderMesh.new()
			ember.top_radius = 0.0
			ember.bottom_radius = 0.45
			ember.height = 1.8
			ember.radial_segments = 5
			result = ember
		"ring":
			var ring := TorusMesh.new(); ring.inner_radius = 0.94; ring.outer_radius = 1.0; ring.rings = 32; ring.ring_segments = 5; result = ring
		"lance", "cone":
			var lance := CylinderMesh.new(); lance.top_radius = 0.0; lance.bottom_radius = 0.5; lance.height = 2.0; lance.radial_segments = 6; result = lance
		"line":
			var line := CylinderMesh.new(); line.top_radius = 1.0; line.bottom_radius = 1.0; line.height = 1.0; line.radial_segments = 6; result = line
		"shard", "runes", "petals":
			var shard := SphereMesh.new(); shard.radius = 1.0; shard.height = 2.0; shard.radial_segments = 4; shard.rings = 1; result = shard
		"star", "stars": result = _star_mesh()
		_:
			var orb := SphereMesh.new(); orb.radius = 1.0; orb.height = 2.0; orb.radial_segments = 10; orb.rings = 4; result = orb
	_meshes[style] = result
	return result

func _orbit_mesh(spell: Dictionary) -> TorusMesh:

	var width_step := roundi(float(spell.trail_width) * 20.0)
	var key := "orbit_tube_%d" % width_step
	if not _meshes.has(key):
		var ring := TorusMesh.new()
		ring.outer_radius = 1.0
		ring.inner_radius = 1.0 - 0.06 * float(width_step) / 20.0
		ring.rings = 32; ring.ring_segments = 5
		_meshes[key] = ring
	return _meshes[key]

func _star_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	for side in [-1.0, 1.0]:
		for index in range(10):
			var a := float(index) * TAU / 10.0
			var b := float(index + 1) * TAU / 10.0
			var r1 := 1.0 if index % 2 == 0 else 0.38
			var r2 := 0.38 if index % 2 == 0 else 1.0
			vertices.append_array(PackedVector3Array([Vector3(0, 0, side * 0.23), Vector3(sin(a) * r1, cos(a) * r1, 0), Vector3(sin(b) * r2, cos(b) * r2, 0)]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _piece(parent: Node3D, shape: Mesh, material: Material, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = shape; piece.material_override = material; piece.scale = size
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)
	return piece

func _projectile_node(spell: Dictionary) -> Node3D:
	return presentation.projectile_node(spell)

func _particles(parent: Node3D, spell: Dictionary, count: int) -> MultiMeshInstance3D:
	count = clampi(roundi(count * float(spell.particle_density)), 1, 72)
	var dust := MultiMeshInstance3D.new()
	dust.multimesh = MultiMesh.new()
	dust.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	dust.multimesh.mesh = _mesh(spell.particles)
	dust.multimesh.instance_count = count
	dust.material_override = _spell_material(spell, true)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dust)
	for index in range(count):
		dust.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * 0.03 * float(spell.particle_size)), Vector3.ZERO))
	return dust

func _animate_projectile(bolt: Dictionary) -> void:
	presentation.animate_projectile(bolt, 0.0)

func _track_visual(node: Node3D, data: Dictionary) -> void:
	while visuals.size() >= MAX_VISUALS: _retire_visual(0)
	data.node = node; data.age = 0.0
	visuals.append(data)

func _glyph(position: Vector3, spell: Dictionary, kind: String, lifetime: float, radius: float) -> void:
	presentation.glyph(position, spell, kind, lifetime, radius)
	if kind in ["impact", "burst"] and is_instance_valid(game) and game.get("audio") != null and game.audio.has_method("magic_cue"):
		game.audio.magic_cue(str(spell.element), "impact", float(spell.power))

func _beam_visual(start: Vector3, end: Vector3, spell: Dictionary, lifetime: float, width: float) -> void:
	presentation.beam(start, end, spell, lifetime, width)

func _tick_visuals(dt: float) -> void:
	presentation.tick(dt)

func _retire_projectile(index: int) -> void:
	if index < 0 or index >= projectiles.size(): return
	var bolt: Dictionary = projectiles[index]
	var node: Variant = bolt.node
	projectiles.remove_at(index)
	var stage := weave._stage(bolt.context)
	if not stage.is_empty(): stage.point = bolt.position
	weave.work(bolt.context, -1)
	if is_instance_valid(node): node.free()

func _retire_visual(index: int) -> void:
	var node: Variant = visuals[index].node
	visuals.remove_at(index)
	if is_instance_valid(node): node.free()

func clear_effects() -> void:
	cancel()
	presentation.clear()
	weave.clearing = true
	cancel_object_magic()
	weave.clear()
	scheduled.clear()
	projectiles.clear(); visuals.clear(); statuses.clear()
	ward_remaining = 0.0; ward_strength = 0
	cooldown_remaining = 0.0
	beam_hold = 0.0
	for node in get_children(): node.free()
	_materials.clear(); _meshes.clear(); _spheres.clear(); _target_spheres.clear()

func has_levitated_object() -> bool:
	return object_magic.has_held() or object_magic.has_creature()

func levitated_target() -> Node3D:
	return object_magic.levitated_target()

func levitation_distance_limits() -> Vector2:
	return object_magic.distance_limits()

func set_levitation_distance(value: float) -> void:
	if is_finite(value): object_magic.adjust_distance(value - object_magic.hold_distance)

func release_levitated_object(launch: bool) -> bool:
	var released: bool = object_magic.release(launch)
	if released:

		for pool in weave.casts: pool.concentration_ended = true
		_cancel_scheduled_physics(true)
	return released

func adjust_levitation_distance(amount: float) -> void:
	object_magic.adjust_distance(amount)

func end_concentration() -> void:
	object_magic.cancel_concentration()
	for pool in weave.casts: pool.concentration_ended = true
	_cancel_scheduled_physics(true)

func cancel_object_magic() -> void:
	object_magic.clear()
	_cancel_scheduled_physics()

func _cancel_scheduled_physics(levitation_only: bool = false) -> void:
	for index in range(scheduled.size() - 1, -1, -1):
		var spell: Dictionary = scheduled[index].spell
		var layers := [spell.effect, spell.secondary_effect, spell.get("tertiary_effect", "none")]
		var cancel_event: bool = "levitate" in layers if levitation_only else spell.effect != "elemental" or spell.secondary_effect not in ["elemental", "none"]
		if cancel_event:
			var event: Dictionary = scheduled[index]
			if levitation_only and (event.get("kind", "contact") != "contact" or layers.any(func (layer): return layer not in ["levitate", "none"])): continue
			scheduled.remove_at(index); weave.work(event.context, -1)

func _exit_tree() -> void:
	presentation.clear()
	weave.clearing = true
	object_magic.clear()
	weave.clear()

func _target_allowed(target: Variant, spell: Dictionary) -> bool:
	if not is_instance_valid(target) or not target is Node3D or not target.is_inside_tree() or target.get_world_3d() != get_world_3d(): return false
	if spell.targeting == "caster": return target == game.player
	if spell.targeting in ["enemies", "both"] and _live(target): return true
	if spell.targeting in ["objects", "both"] and "levitate" in [spell.effect, spell.secondary_effect, spell.tertiary_effect] and object_magic.creature_eligible(target): return true
	return spell.targeting in ["objects", "both"] and object_magic.eligible(target, spell)

func _spatial_targets(center: Vector3, radius: float, spell: Dictionary) -> Array:
	if spell.targeting == "caster": return [game.player] if _target_allowed(game.player, spell) else []
	var key := clampi(ceili(radius * 10.0), 1, 1000)
	if not _target_spheres.has(key):
		if _target_spheres.size() >= 64: _target_spheres.erase(_target_spheres.keys()[0])
		var shape := SphereShape3D.new(); shape.radius = float(key) * 0.1; _target_spheres[key] = shape
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = _target_spheres[key]
	query.transform = Transform3D(Basis.IDENTITY, center); query.collision_mask = 4 | 8; query.exclude = _exclude()
	var result: Array = []; var seen: Dictionary = {}


	for hit in get_world_3d().direct_space_state.intersect_shape(query, MAX_TARGETS * 4):
		var target: Variant = hit.collider
		if not _target_allowed(target, spell) or seen.has(target.get_instance_id()): continue
		seen[target.get_instance_id()] = true
		result.append(target)
	return result

func _near_targets(center: Vector3, spell: Dictionary, excluded_ids: Array = []) -> Array:
	var candidates: Array = []
	for target in _spatial_targets(center, float(spell.radius), spell):
		if target.get_instance_id() not in excluded_ids: candidates.append({"node": target, "distance": center.distance_squared_to(_target_center(target))})
	candidates.sort_custom(func (a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var result: Array = []
	for index in range(mini(MAX_TARGETS, candidates.size())): result.append(candidates[index].node)
	return result

func _chain_target(center: Vector3, spell: Dictionary, visited: Array, source: Variant) -> Variant:
	for target in _near_targets(center, spell, visited):
		if source is Node3D and _chain_clear(center, target, source): return target
	return null

func _contact(target: Variant, center: Vector3, spell: Dictionary, context: Dictionary, area: bool = false) -> void:
	if spell.targeting == "projectiles" or "projectile_stasis" in [spell.effect, spell.secondary_effect, spell.get("tertiary_effect", "none")]:
		_stasis_projectiles(center, spell, context)
		if spell.targeting == "projectiles": return
	if spell.targeting == "caster": target = game.player; area = false
	var event := {"kind": "contact", "target": weakref(target) if is_instance_valid(target) else null, "center": center,
		"spell": spell, "context": context, "area": area, "wait": float(spell.delay) if spell.trigger == "delay" else 0.0,
		"remaining": Spellbook.effective_pulses(spell)}
	if float(event.wait) <= 0:
		_resolve_event(event); event.remaining -= 1; event.wait = float(spell.interval)
	if int(event.remaining) > 0:
		weave.consume(context, "events"); scheduled.append(event); weave.work(context, 1)

func _tick_scheduled(dt: float) -> void:
	var resolved := 0
	for event in scheduled.duplicate():
		if event not in scheduled: continue
		event.wait -= dt
		if event.get("kind", "contact") == "end":
			if float(event.wait) <= 1.0e-05:
				scheduled.erase(event); weave.work(event.context, -1)
			continue
		if event.get("kind", "contact") == "launch":
			if float(event.wait) <= 1.0e-05:
				scheduled.erase(event)
				_spawn_bolt(event.spell, event.origin, event.direction, event.context, int(event.index))
				weave.work(event.context, -1)
			continue
		while float(event.wait) <= 1.0e-05 and int(event.remaining) > 0 and resolved < MAX_RESOLVES_PER_TICK:
			resolved += 1; _resolve_event(event); event.remaining -= 1; event.wait += float(event.spell.interval)
		if int(event.remaining) <= 0 or int(event.context.pool.budget) <= 0:
			scheduled.erase(event); weave.work(event.context, -1)

func _resolve_event(event: Dictionary) -> void:
	if int(event.context.pool.budget) <= 0: return
	if event.area:
		for target in _near_targets(event.center, event.spell):
			if _area_clear_line(event.center, _target_center(target), target): _apply_layers(target, event.center, event.spell, event.context)
	else:
		var target = event.target.get_ref() if event.target is WeakRef else null
		if not _target_allowed(target, event.spell): return
		if _clear_line(event.center, _target_center(target), target): _apply_layers(target, event.center, event.spell, event.context)


func _area_clear_line(start: Vector3, end: Vector3, target: Node3D) -> bool:
	var excluded: Array[RID] = _exclude()
	if target is CollisionObject3D: excluded.append(target.get_rid())
	var query := PhysicsRayQueryParameters3D.create(start, end, 1 | 8 | 16, excluded)
	query.hit_from_inside = true
	for attempt in range(MAX_TARGETS):
		query.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return true
		var collider = hit.collider
		if collider is CollisionObject3D and (collider.is_in_group("npc") or collider.is_in_group("resident") or collider.is_in_group("magic_guardian") or str(collider.get_meta("kind", "")) == "npc"):
			excluded.append(collider.get_rid())
		else: return false
	return false

func _apply_layers(target: Node3D, center: Vector3, spell: Dictionary, context: Dictionary) -> void:
	if int(context.pool.budget) <= 0 or not _target_allowed(target, spell): return
	context.pool.budget -= 1
	var movable_creature_only: bool = str(spell.targeting) == "objects" and object_magic.creature_eligible(target)


	var contact_tags: Dictionary = {}
	for tag in ["wet", "burning", "frozen"]:
		if has_status(target, tag): contact_tags[tag] = true
	for effect in [spell.effect, spell.secondary_effect, spell.get("tertiary_effect", "none")]:
		if effect == "none" or not is_instance_valid(target): continue
		if movable_creature_only and effect != "levitate": continue
		if effect == "levitate" and context.pool.get("concentration_ended", false): continue
		if effect == "elemental":
			if _live(target): _elemental_hit(target, spell, context)
		elif effect == "heal":
			if target == game.player: game.state.health = mini(game.state.max_health, game.state.health + maxi(1, int(spell.power)))
			elif target.get("health") != null: target.health = mini(int(target.get_meta("max_health", target.health + int(spell.power))), int(target.health) + int(spell.power))
		elif effect == "shield" and target == game.player:
			ward_strength = maxi(ward_strength, int(spell.power) + 1); ward_remaining = maxf(ward_remaining, float(spell.duration))
		elif effect == "levitate" and target is CharacterBody3D:
			if object_magic.creature_eligible(target): object_magic.hold_creature(target, spell, context.direction)
		elif object_magic.eligible(target, spell):
			var anchor: Vector3 = center if spell.form in ["burst", "field", "cone", "trap"] else context.origin
			if effect == "enchant": object_magic.enchant(target, spell, context)
			else: object_magic.apply(effect, target, spell, anchor, context.direction)
		elif _live(target): weave.apply_enemy(effect, target, spell, center, context.direction)

	if is_instance_valid(target) and "enchant" not in [spell.effect, spell.secondary_effect, spell.get("tertiary_effect", "none")]: weave.hit(target, center, context, false, contact_tags)

func _stasis_projectiles(center: Vector3, spell: Dictionary, context: Dictionary) -> void:
	var radius := float(spell.radius)
	for bolt in projectiles:
		if int(context.pool.budget) <= 0: break
		if bolt.context.stage_id == context.stage_id: continue
		if bolt.position.distance_squared_to(center) <= radius * radius and _ray(center, bolt.position, 1 | 8 | 16).is_empty():
			bolt.stasis = maxf(float(bolt.get("stasis", 0.0)), float(spell.duration)); context.pool.budget -= 1
			weave.hit(bolt.node, bolt.position, context)


	var candidates := get_tree().get_nodes_in_group("enemy").filter(func (node): return _live(node))
	var inspected := 0
	for enemy in candidates:
		if inspected >= MAX_TARGETS or int(context.pool.budget) <= 0: break
		inspected += 1
		if not enemy.has_method("freeze_magic_projectiles"): continue
		var affected: int = enemy.freeze_magic_projectiles(center, radius, float(spell.duration), mini(3, int(context.pool.budget)))
		context.pool.budget -= affected

func has_status(target: Node3D, tag: String) -> bool: return weave.has_status(target, tag)
func status_remaining(target: Node3D, tag: String) -> float: return weave.status_remaining(target, tag)
func set_status(target: Node3D, tag: String, duration: float) -> bool: return weave.set_status(target, tag, duration)
func stats() -> Dictionary:
	var result: Dictionary = weave.stats()
	result.merge({"projectiles": projectiles.size(), "events": scheduled.size() + weave.timer_count(), "applications": MAX_APPLICATIONS, "statuses": statuses.size(), "objects": object_magic.bodies.size(), "enchantments": object_magic.enchantments.size()})
	return result

func admission_reason(raw: Dictionary, target: Vector3) -> String:
	var spell := Spellbook.sanitize(raw)
	if spell.is_empty(): return "Invalid spell recipe."
	if not _valid_point(target): return "Aim at a finite point in the world."
	if not _usable(): return "Magic needs an active caster."
	return weave.admission_reason(spell, target)

func work_estimate(raw: Dictionary) -> Dictionary:
	var spell := Spellbook.sanitize(raw)
	return {} if spell.is_empty() else weave.estimate(spell)
