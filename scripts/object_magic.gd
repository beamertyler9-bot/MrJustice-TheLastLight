extends RefCounted

const MAX_BODIES := 12
const MAX_MOTION_WATCHES := 48
var runtime
var bodies: Array = []
var motion_watches: Array = []
var enchantments: Array = []
var held: WeakRef
var held_creature: WeakRef
var creature_hold: Dictionary = {}
var hold_distance := 4.0
var hold_direction := Vector3.FORWARD

func setup(owner_runtime) -> void:
	runtime = owner_runtime

func eligible(body: Variant, spell: Dictionary) -> bool:
	return is_instance_valid(body) and body is RigidBody3D and body.is_inside_tree() and not body.is_queued_for_deletion() and body.get_world_3d() == runtime.get_world_3d() and body.is_in_group("carryable") and body.mass <= float(spell.mass_limit)

func has_held() -> bool:
	return held != null and is_instance_valid(held.get_ref()) and held.get_ref().is_inside_tree() and not held.get_ref().is_queued_for_deletion()

func has_creature() -> bool:
	return held_creature != null and is_instance_valid(held_creature.get_ref()) and held_creature.get_ref().is_inside_tree() and not held_creature.get_ref().is_queued_for_deletion() and int(held_creature.get_ref().get("health")) > 0

func creature_eligible(body: Variant) -> bool:
	return is_instance_valid(body) and body is CharacterBody3D and body.is_inside_tree() and not body.is_queued_for_deletion() and body.get_world_3d() == runtime.get_world_3d() and body.is_in_group("enemy") and not body.is_in_group("deep_boss") and body.get("health") != null and int(body.get("health")) > 0

func levitated_target() -> Node3D:
	return held_creature.get_ref() if has_creature() else held.get_ref() if has_held() else null

func distance_limits() -> Vector2:
	var maximum := float(creature_hold.get("range", 18.0))
	if has_held():
		for data in bodies:
			if data.body.get_ref() == held.get_ref():
				for layer in data.layers:
					if layer.effect == "levitate": maximum = float(layer.range)
	return Vector2(2.0, maxf(2.0, maximum))

func hold_creature(body: CharacterBody3D, spell: Dictionary, direction: Vector3) -> bool:
	if not creature_eligible(body): return false
	if has_creature() and held_creature.get_ref() == body:
		creature_hold.remaining = float(spell.duration)
		creature_hold.force = float(spell.force); creature_hold.range = float(spell.range)
		hold_distance = clampf(hold_distance, 2.0, float(spell.range)); hold_direction = direction
		return true
	release(false)
	held_creature = weakref(body)
	creature_hold = {"remaining": float(spell.duration), "force": float(spell.force), "range": float(spell.range),
		"had_owner": body.has_meta("magic_held"), "owner": body.get_meta("magic_held", false)}
	body.set_meta("magic_held", true)
	body.velocity = Vector3.ZERO
	hold_distance = clampf(runtime._origin().distance_to(runtime._target_center(body)), 2.0, float(spell.range))
	hold_direction = direction
	return true

func _tick_creature(dt: float) -> void:
	if held_creature == null: return
	if not has_creature():
		_release_creature(false)
		return
	creature_hold.remaining -= dt
	if float(creature_hold.remaining) <= 0:
		_release_creature(false)
		return
	var body: CharacterBody3D = held_creature.get_ref()
	var origin: Vector3 = runtime._origin()
	if not runtime._clear_line(origin, runtime._target_center(body), body):
		_release_creature(false)
		return
	hold_direction = _aim()
	var goal := origin + hold_direction * hold_distance
	var obstruction: Dictionary = runtime._ray(origin, goal, 1 | 8 | 16)
	if not obstruction.is_empty(): goal = obstruction.position + obstruction.normal * 0.65
	var displacement: Vector3 = goal - runtime._target_center(body)
	body.velocity = (displacement * 6.0).limit_length(10.0)
	body.move_and_collide(body.velocity * dt)

func _release_creature(launch: bool) -> bool:
	if held_creature == null: return false
	var body = held_creature.get_ref()
	var direction := _aim() if launch else hold_direction
	var force := float(creature_hold.get("force", 12.0))
	if is_instance_valid(body):
		if creature_hold.get("had_owner", false): body.set_meta("magic_held", creature_hold.owner)
		elif body.has_meta("magic_held"): body.remove_meta("magic_held")
		body.velocity = Vector3.ZERO
		if launch and body.has_method("receive_impulse"): body.receive_impulse((direction + Vector3.UP * 0.16).normalized() * force)
	held_creature = null; creature_hold.clear()
	return is_instance_valid(body)


func can_hold_body(body: RigidBody3D) -> bool:
	if bodies.size() < MAX_BODIES or has_held(): return true
	for data in bodies:
		if data.body.get_ref() == body: return true
	return false

func _record(body: RigidBody3D) -> Dictionary:
	for data in bodies:
		if data.body.get_ref() == body: return data
	if bodies.size() >= MAX_BODIES: return {}
	var data := {"body": weakref(body), "gravity": body.gravity_scale, "linear_damp": body.linear_damp,
		"angular_damp": body.angular_damp, "freeze": body.freeze, "continuous_cd": body.continuous_cd,
		"can_sleep": body.can_sleep, "position": body.global_position, "layers": []}
	bodies.append(data)
	body.freeze = false
	body.sleeping = false
	body.continuous_cd = true
	body.can_sleep = false
	return data

func apply(effect: String, body: RigidBody3D, spell: Dictionary, center: Vector3, direction: Vector3) -> void:
	if not eligible(body, spell): return
	_watch_motion(body)
	var radial := body.global_position - center
	var away := radial.normalized() if radial.length_squared() > 0.04 else direction
	if away.length_squared() < 0.5: away = Vector3.FORWARD
	if effect in ["push", "pull", "repel", "launch"]:
		body.freeze = false; body.sleeping = false
		if effect == "launch": _activate_throw(body)
		var impulse: Vector3 = away * float(spell.force)
		if effect == "push": impulse = direction * float(spell.force)
		elif effect == "pull": impulse = -away * float(spell.force)
		elif effect == "launch": impulse = (direction + Vector3.UP * 0.45).normalized() * float(spell.force)



		body.linear_velocity = (body.linear_velocity + impulse / maxf(0.1, body.mass)).limit_length(30.0)
		return
	if effect not in ["levitate", "suspend", "orbit", "gravity_well", "slow", "stasis"]: return
	if effect == "levitate":
		if not can_hold_body(body): return
		if not has_held() or held.get_ref() != body: release(false)
	var data := _record(body)
	if data.is_empty(): return
	if effect == "levitate":
		held = weakref(body)
		hold_distance = clampf(runtime._origin().distance_to(body.global_position), 2.0, float(spell.range))
		hold_direction = direction
	var anchor := body.global_position if effect in ["levitate", "suspend"] else center

	for layer in data.layers:
		if layer.effect == effect:
			layer.remaining = float(spell.duration); layer.force = float(spell.force)
			return
	data.layers.append({"effect": effect, "remaining": float(spell.duration), "force": float(spell.force), "slow_factor": float(spell.slow_factor),
		"saved_linear": body.linear_velocity, "saved_angular": body.angular_velocity,
		"anchor": anchor, "age": 0.0, "radius": float(spell.orbit_radius) if effect == "orbit" else clampf(body.global_position.distance_to(center), 1.0, float(spell.radius)), "range": float(spell.range)})
	if effect == "stasis": body.freeze = true
	elif effect == "slow":
		body.linear_velocity *= float(spell.slow_factor); body.angular_velocity *= float(spell.slow_factor)
		body.linear_damp = float(data.linear_damp) + 4.0 * (1.0 - float(spell.slow_factor))
	else:
		body.gravity_scale = 0.0
		body.linear_damp = 3.5
		body.angular_damp = 4.0

func adjust_distance(amount: float) -> void:
	if not is_finite(amount) or (not has_held() and not has_creature()): return
	var maximum := 18.0
	for data in bodies:
		if has_held() and data.body.get_ref() == held.get_ref():
			for layer in data.layers:
				if layer.effect == "levitate": maximum = layer.range
	if has_creature(): maximum = float(creature_hold.range)
	hold_distance = clampf(hold_distance + amount, 2.0, maximum)

func _aim() -> Vector3:
	if not is_instance_valid(runtime) or not is_instance_valid(runtime.game): return hold_direction
	var player = runtime.game.player
	if not is_instance_valid(player) or not player.is_inside_tree(): return hold_direction
	var camera: Variant = player.get("camera")
	if camera is Camera3D and camera.is_inside_tree():
		var mark: Vector2 = player.get_viewport().get_visible_rect().size * Vector2(0.5, 332.0 / 720.0)
		var ray_start: Vector3 = camera.project_ray_origin(mark)
		var ray_direction: Vector3 = camera.project_ray_normal(mark).normalized()
		var origin: Vector3 = runtime._origin()



		var offset := ray_start - origin
		var along := offset.dot(ray_direction)
		var perpendicular_squared := maxf(0.0, offset.length_squared() - along * along)
		var depth := -along + sqrt(maxf(0.0, hold_distance * hold_distance - perpendicular_squared))
		var direction := ray_start + ray_direction * maxf(0.05, depth) - origin
		if direction.is_finite() and direction.length_squared() > 0.01: return direction.normalized()
	if player.has_method("ability_target"):
		var solution: Variant = player.ability_target()
		if solution is Dictionary and solution.get("point") is Vector3:
			var direction: Vector3 = solution.point - runtime._origin()
			if direction.is_finite() and direction.length_squared() > 0.01: return direction.normalized()
	return hold_direction

func tick(dt: float) -> void:
	_tick_creature(dt)
	_tick_ownership(dt)
	_tick_enchantments(dt)
	for i in range(bodies.size() - 1, -1, -1):
		var data: Dictionary = bodies[i]
		var body = data.body.get_ref()
		if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
			_restore(i); continue
		_adopt_if_moved(body, data.position)
		for j in range(data.layers.size() - 1, -1, -1):
			var layer: Dictionary = data.layers[j]
			layer.remaining -= dt; layer.age += dt
			if layer.remaining <= 0:
				if layer.effect == "stasis":
					body.freeze = false; body.linear_velocity = layer.saved_linear; body.angular_velocity = layer.saved_angular
				if layer.effect == "levitate" and held != null and held.get_ref() == body: held = null
				data.layers.remove_at(j); continue
			if layer.effect == "stasis": body.freeze = true; continue
			if layer.effect == "slow": continue
			var time_frozen := false
			for other_layer in data.layers:
				if other_layer.effect == "stasis": time_frozen = true; break
			if time_frozen: continue
			var goal: Vector3 = layer.anchor
			if layer.effect == "levitate":
				var origin: Vector3 = runtime._origin()

				if not _visible(origin, body.global_position, body):
					data.layers.clear(); break
				hold_direction = _aim()
				goal = origin + hold_direction * hold_distance
				var hit := _obstacle_ray(origin, goal, body)
				if not hit.is_empty(): goal = hit.position + hit.normal * 0.5
			elif layer.effect == "orbit":
				goal += Vector3(cos(layer.age * 1.5), 0.5, sin(layer.age * 1.5)) * float(layer.radius)
			var acceleration: Vector3 = (goal - body.global_position) * 12.0 - body.linear_velocity * 3.0
			if layer.effect == "gravity_well": acceleration = (goal - body.global_position).normalized() * float(layer.force) - body.linear_velocity * 0.5
			body.apply_central_force(acceleration.limit_length(float(layer.force) * 2.0) * body.mass)



			if body.linear_velocity.length_squared() > 144.0:
				body.linear_velocity = body.linear_velocity.limit_length(12.0)
		if data.layers.is_empty(): _restore(i)
	if held != null and not has_held(): held = null

func _obstacle_ray(start: Vector3, end: Vector3, body: RigidBody3D) -> Dictionary:
	var excluded: Array[RID] = runtime._exclude()
	excluded.append(body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(start, end, 1 | 4 | 8 | 16, excluded)
	return runtime.get_world_3d().direct_space_state.intersect_ray(query)

func _visible(start: Vector3, end: Vector3, body: RigidBody3D) -> bool:
	return _obstacle_ray(start, end, body).is_empty()

func _restore(index: int) -> void:
	var data: Dictionary = bodies[index]
	bodies.remove_at(index)
	var body = data.body.get_ref()
	if held != null and held.get_ref() == body: held = null
	if not is_instance_valid(body): return
	_adopt_if_moved(body, data.position)
	body.gravity_scale = data.gravity; body.linear_damp = data.linear_damp; body.angular_damp = data.angular_damp
	body.continuous_cd = data.continuous_cd; body.can_sleep = data.can_sleep


	body.freeze = data.freeze and body.global_position.distance_squared_to(data.position) <= 0.0025
	if data.freeze and not body.freeze and not body.is_in_group("loose_prop"): body.add_to_group("loose_prop")
	if body.freeze:
		body.linear_velocity = Vector3.ZERO; body.angular_velocity = Vector3.ZERO

func release(launch: bool) -> bool:
	if held_creature != null: return _release_creature(launch)
	if not has_held(): held = null; return false
	var body: RigidBody3D = held.get_ref()
	var direction := _aim()
	var force := 12.0
	for i in range(bodies.size() - 1, -1, -1):
		if bodies[i].body.get_ref() == body:
			for layer in bodies[i].layers:
				if layer.effect == "levitate": force = layer.force
			_restore(i)
	held = null
	body.freeze = false; body.sleeping = false
	body.linear_velocity = Vector3.ZERO
	if not body.is_in_group("loose_prop"): body.add_to_group("loose_prop")
	if launch:

		body.freeze = false; body.sleeping = false
		body.linear_velocity = direction * force
		_activate_throw(body)
	return true

func clear() -> void:
	_release_creature(false)
	for i in range(enchantments.size() - 1, -1, -1): _disarm_enchantment(i)
	_tick_ownership(0.0)
	for i in range(bodies.size() - 1, -1, -1): _restore(i)
	held = null

func _activate_throw(body: RigidBody3D) -> void:
	if not body.is_in_group("loose_prop"): body.add_to_group("loose_prop")
	body.contact_monitor = true
	body.max_contacts_reported = maxi(3, body.max_contacts_reported)

	if body.has_meta("throw_connected"): return
	body.set_meta("throw_connected", true)
	var reference: WeakRef = weakref(body)
	body.body_entered.connect(func (other: Node) -> void:
		var source = reference.get_ref()
		if is_instance_valid(source) and is_instance_valid(other) and source.linear_velocity.length() > 2.5 and other.has_method("take_damage"):
			other.take_damage(2)
	)

func _watch_motion(body: RigidBody3D) -> void:
	if body.has_meta("magic_world_owned"): return
	for watch in motion_watches:
		if watch.body.get_ref() == body: return
	while motion_watches.size() >= MAX_MOTION_WATCHES: motion_watches.pop_front()
	motion_watches.append({"body": weakref(body), "origin": body.global_position, "remaining": 4.0})

func _tick_ownership(dt: float) -> void:
	for index in range(motion_watches.size() - 1, -1, -1):
		var watch: Dictionary = motion_watches[index]
		var body = watch.body.get_ref()
		watch.remaining -= dt
		if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
			motion_watches.remove_at(index); continue
		if _adopt_if_moved(body, watch.origin) or watch.remaining <= 0:
			motion_watches.remove_at(index)

func _adopt_if_moved(body: RigidBody3D, origin: Vector3) -> bool:
	if body.has_meta("magic_world_owned"): return true
	if not is_instance_valid(runtime) or not is_instance_valid(runtime.game): return false
	var player = runtime.game.player


	if is_instance_valid(player) and player.get("held_body") == body: return true
	if body.global_position.distance_squared_to(origin) <= 0.0025: return false
	var world = runtime.game.get("world")
	if not is_instance_valid(world) or not world is Node3D or not world.is_inside_tree() or world.is_queued_for_deletion(): return false


	if body.get_parent() != world: body.reparent(world, true)
	if not body.is_in_group("loose_prop"): body.add_to_group("loose_prop")
	var source_id := str(body.get_meta("id", ""))
	if not source_id.is_empty() and runtime.game.state != null:
		runtime.game.state.taken[source_id] = true
	body.set_meta("magic_world_owned", true)
	return true

func cancel_concentration() -> void:
	_release_creature(false)
	for i in range(bodies.size() - 1, -1, -1):
		var data: Dictionary = bodies[i]
		for j in range(data.layers.size() - 1, -1, -1):
			if data.layers[j].effect == "levitate": data.layers.remove_at(j)
		if data.layers.is_empty(): _restore(i)
	held = null

func enchant(body: RigidBody3D, spell: Dictionary, context: Dictionary) -> void:
	if not eligible(body, spell): return
	for data in enchantments:
		if data.body.get_ref() == body: data.remaining = float(spell.duration); return
	if enchantments.size() >= MAX_BODIES: return
	var reference: WeakRef = weakref(body)
	var callback := func (other: Node) -> void: _enchantment_contact(reference, other)
	var data := {"body": reference, "context": context, "remaining": float(spell.duration), "age": 0.0, "speed": body.linear_velocity.length(),
		"monitor": body.contact_monitor, "contacts": body.max_contacts_reported, "callback": callback}
	enchantments.append(data)
	body.contact_monitor = true; body.max_contacts_reported = maxi(4, body.max_contacts_reported)
	body.body_entered.connect(callback)
	runtime.weave.work(context, 1)

func _tick_enchantments(dt: float) -> void:
	for i in range(enchantments.size() - 1, -1, -1):
		var data: Dictionary = enchantments[i]; var body = data.body.get_ref()
		data.remaining -= dt; data.age += dt
		if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or data.remaining <= 0: _disarm_enchantment(i); continue
		data.speed = body.linear_velocity.length()

func _enchantment_contact(reference: WeakRef, other: Node) -> void:
	var body = reference.get_ref()
	if not is_instance_valid(body) or not is_instance_valid(other) or not other is Node3D or other == runtime.game.player: return
	if other.get_world_3d() != runtime.get_world_3d(): return
	for i in range(enchantments.size()):
		var data: Dictionary = enchantments[i]
		if data.body.get_ref() != body: continue
		if float(data.age) < 0.05 or maxf(float(data.speed), body.linear_velocity.length()) < 1.0: return


		var context: Dictionary = data.context
		var point: Vector3 = body.global_position
		_disarm_enchantment(i, false)
		runtime.weave.hit(other, point, context)
		runtime.weave.work(context, -1)
		return

func _disarm_enchantment(index: int, finish_work := true) -> void:
	var data: Dictionary = enchantments[index]; enchantments.remove_at(index)
	var body = data.body.get_ref()
	if is_instance_valid(body):
		if body.body_entered.is_connected(data.callback): body.body_entered.disconnect(data.callback)
		body.contact_monitor = bool(data.monitor) or body.has_meta("throw_connected")
		body.max_contacts_reported = maxi(int(data.contacts), 3 if body.has_meta("throw_connected") else 0)
	if finish_work: runtime.weave.work(data.context, -1)
