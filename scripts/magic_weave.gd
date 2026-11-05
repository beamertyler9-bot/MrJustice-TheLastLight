extends RefCounted

const Book = preload("res://scripts/spellbook.gd")
const Guardian = preload("res://scripts/temporary_guardian.gd")
const MAX_STAGES := 64
const MAX_TAG_TARGETS := 48
const MAX_GUARDIANS := 2
const MAX_CONSTRUCTS := 2
const MAX_TRAPS := 12
var runtime
var casts: Array = []
var stages: Array = []
var guardians: Array = []
var constructs: Array = []
var traps: Array = []
var target_states: Array = []
var stage_events: Array = []
var _serial := 0
var clearing := false

func setup(owner_runtime) -> void:
	runtime = owner_runtime

func estimate(raw: Dictionary) -> Dictionary:
	var result := {"projectiles": 0, "events": 0, "guardians": 0, "constructs": 0, "traps": 0, "stages": 0}
	var multiplier := 1
	for spell in Book.stage_list(raw):
		if result.stages > 0: multiplier *= int(spell.repeat_contacts) if spell.when == "hit" else 1
		result.stages += multiplier
		var bolts := int(spell.count) if spell.form in ["volley", "rain", "orbitals"] else 0
		result.projectiles += bolts * multiplier
		var contacts := bolts * (1 + int(spell[{"pierce": "pierces", "chain": "chains", "bounce": "bounces"}.get(spell.impact, "pierces")])) if spell.impact != "shatter" and bolts > 0 else maxi(1, bolts)
		if spell.form == "cone": contacts = runtime.MAX_TARGETS
		elif spell.form == "summon": contacts = int(spell.summon_count) * ceili(float(spell.duration) / 0.8)

		if spell.trigger in ["delay", "pulse"]: result.events += contacts * multiplier
		if bolts > 0 and float(spell.stagger) > 0: result.events += maxi(0, bolts - 1) * multiplier
		if spell.form == "field": result.events += multiplier
		if spell.when == "delay" and result.stages > 1: result.events += multiplier
		if spell.form == "summon": result.guardians += int(spell.summon_count) * multiplier
		if spell.form == "wall": result.constructs += multiplier
		if spell.form == "trap": result.traps += multiplier
	return result

func reserved(kind: String) -> int:
	var total := 0
	for cast in casts: total += int(cast.reserve.get(kind, 0))
	return total

func can_admit(raw: Dictionary, target: Vector3, check_placement := true) -> bool:
	return admission_reason(raw, target, check_placement).is_empty()

func timer_count() -> int:
	var total := 0
	for stage in stages:
		var next := int(stage.index) + 1
		if next < stage.context.pool.recipes.size() and stage.context.pool.recipes[next].when == "delay" and not stage.delay_fired: total += 1
	return total

func admission_reason(raw: Dictionary, target: Vector3, check_placement := true) -> String:
	var need := estimate(raw)
	if need.stages <= 0: return "Invalid spell recipe."
	if need.stages + stages.size() + reserved("stages") > MAX_STAGES: return "Too many spell stages are still active."
	if runtime.projectiles.size() + reserved("projectiles") + need.projectiles > runtime.MAX_PROJECTILES: return "This weave needs more than 42 available projectiles. Reduce count or contact repeats."
	if runtime.scheduled.size() + timer_count() + reserved("events") + need.events > runtime.MAX_SCHEDULED: return "This weave needs more than 48 available delayed events. Reduce stagger, pulses or contact repeats."
	if guardians.size() + reserved("guardians") + need.guardians > MAX_GUARDIANS: return "Only two magical guardians can be active."
	if constructs.size() + reserved("constructs") + need.constructs > MAX_CONSTRUCTS: return "Only two magical walls can be active."
	if traps.size() + reserved("traps") + need.traps > MAX_TRAPS: return "Too many magical traps are still active."
	if raw.form == "wall" and check_placement and wall_transform(raw, runtime._origin(), target).is_empty(): return "The wall needs clear space away from characters and solids."
	return ""

func begin(raw: Dictionary, origin: Vector3, target: Vector3, sequence: int) -> void:
	var pool := {"sequence": sequence, "budget": runtime.MAX_APPLICATIONS, "healed": false, "reactions": 12,
		"recipes": Book.stage_list(raw), "reserve": estimate(raw), "charge": float(runtime.get("release_charge"))}
	casts.append(pool)
	_start(pool, 0, origin, target, null)

func _start(pool: Dictionary, index: int, origin: Vector3, target: Vector3, previous: Variant, contact_tags: Dictionary = {}) -> void:
	if clearing or not runtime.is_inside_tree() or not runtime._usable() or index >= pool.recipes.size() or int(pool.budget) <= 0: return
	var spell: Dictionary = pool.recipes[index]
	if index > 0 and not _condition(previous, spell.condition, contact_tags): return
	_serial += 1
	var direction: Vector3 = (target - origin).normalized()
	if direction.length_squared() < 0.5: direction = Vector3.FORWARD
	var context := {"pool": pool, "sequence": pool.sequence, "origin": origin, "direction": direction, "stage_id": _serial, "aim_target": target}
	var stage := {"id": _serial, "index": index, "context": context, "work": 0, "released": false, "ended": false,
		"hits": 0, "last": weakref(previous) if is_instance_valid(previous) else null, "point": origin if spell.form in ["volley", "rain", "orbitals"] else target, "age": 0.0, "delay_fired": false}
	stages.append(stage)
	consume(context, "stages")
	if index + 1 < pool.recipes.size() and pool.recipes[index + 1].when == "delay": consume(context, "events")
	stage_events.append({"sequence": pool.sequence, "stage": index, "id": _serial, "origin": origin})
	if stage_events.size() > 128: stage_events.pop_front()
	runtime._deliver(spell, origin, target, direction, context)
	if spell.form == "field":
		consume(context, "events"); work(context, 1)
		runtime.scheduled.append({"kind": "end", "wait": float(spell.duration), "spell": spell, "context": context})
	stage.released = true
	_end_if_ready(stage)

func _condition(target: Variant, condition: String, contact_tags: Dictionary = {}) -> bool:
	if condition == "always": return true
	if not is_instance_valid(target) or not target is Node3D or not target.is_inside_tree() or target.get_world_3d() != runtime.get_world_3d(): return false
	if condition == "movable": return target is RigidBody3D and target.is_in_group("carryable")
	return bool(contact_tags.get(condition, false)) or has_status(target, condition)

func _stage(context: Dictionary) -> Dictionary:
	for stage in stages:
		if stage.id == context.get("stage_id", -1): return stage
	return {}

func work(context: Dictionary, change: int) -> void:
	var stage := _stage(context)
	if stage.is_empty(): return
	stage.work = maxi(0, int(stage.work) + change)
	_end_if_ready(stage)

func _end_if_ready(stage: Dictionary) -> void:
	if not stage.released or int(stage.work) > 0 or stage.ended: return
	stage.ended = true
	var index := int(stage.index) + 1
	var pool: Dictionary = stage.context.pool
	if index < pool.recipes.size() and pool.recipes[index].when == "end":
		var target = stage.last.get_ref() if stage.last is WeakRef else null
		var point: Vector3 = runtime._target_center(target) if is_instance_valid(target) and target is Node3D else stage.point
		_start(pool, index, stage.point, point, target)

func hit(target: Node3D, point: Vector3, context: Dictionary, surface := false, contact_tags: Dictionary = {}) -> void:
	var stage := _stage(context)
	if stage.is_empty(): return
	stage.last = weakref(target); stage.point = point
	var next := int(stage.index) + 1
	var pool: Dictionary = context.pool
	if next >= pool.recipes.size() or pool.recipes[next].when != "hit": return
	var successor: Dictionary = pool.recipes[next]
	if stage.hits >= int(successor.repeat_contacts): return
	stage.hits += 1
	_start(pool, next, point, point if surface else runtime._target_center(target), target, contact_tags)

func tick(dt: float) -> void:
	_tick_states(dt)

	for stage in stages.duplicate():
		stage.age += dt
		var pool: Dictionary = stage.context.pool
		var next := int(stage.index) + 1
		if next < pool.recipes.size() and pool.recipes[next].when == "delay" and not stage.delay_fired and stage.age >= float(pool.recipes[next].stage_delay):
			stage.delay_fired = true
			var selected = stage.last.get_ref() if stage.last is WeakRef else null
			var point: Vector3 = runtime._target_center(selected) if is_instance_valid(selected) and selected is Node3D else stage.point
			_start(pool, next, stage.point, point, selected)
	_tick_traps(dt)
	_tick_guardians(dt)
	_tick_constructs(dt)
	_collect()

func _collect() -> void:
	for i in range(stages.size() - 1, -1, -1):
		var stage: Dictionary = stages[i]
		var next := int(stage.index) + 1
		var recipes: Array = stage.context.pool.recipes
		var waiting_delay: bool = next < recipes.size() and recipes[next].when == "delay" and not stage.delay_fired
		if stage.ended and not waiting_delay: stages.remove_at(i)
	for i in range(casts.size() - 1, -1, -1):
		var active := false
		for stage in stages:
			if stage.context.pool == casts[i]: active = true; break
		if not active: casts.remove_at(i)

func consume(context: Dictionary, kind: String, count := 1) -> void:
	context.pool.reserve[kind] = maxi(0, int(context.pool.reserve.get(kind, 0)) - count)

func _state(target: Node3D, create := false) -> Dictionary:
	for state in target_states:
		if state.target.get_ref() == target: return state
	if not create or target_states.size() >= MAX_TAG_TARGETS or not target.is_inside_tree() or target.get_world_3d() != runtime.get_world_3d(): return {}
	var originals := {}
	for key in ["magic_stasis", "magic_time_scale", "magic_steam", "magic_gravity_scale"]:
		originals[key] = {"present": target.has_meta(key), "value": target.get_meta(key) if target.has_meta(key) else null}
	var result := {"target": weakref(target), "tags": {}, "originals": originals, "motions": []}
	target_states.append(result)
	return result

func set_status(target: Node3D, tag: String, duration: float) -> bool:
	if tag not in ["wet", "burning", "frozen", "steam", "slow", "stasis"] or not is_finite(duration) or duration <= 0: return false
	var state := _state(target, true)
	if state.is_empty(): return false
	state.tags[tag] = maxf(float(state.tags.get(tag, 0.0)), minf(duration, 10.0))
	_publish(state)
	return true

func has_status(target: Node3D, tag: String) -> bool:
	return status_remaining(target, tag) > 1.0e-05

func status_remaining(target: Node3D, tag: String) -> float:
	var state := _state(target)
	return float(state.tags.get(tag, 0.0)) if not state.is_empty() else 0.0

func remove_status(target: Node3D, tag: String) -> void:
	var state := _state(target)
	if state.is_empty(): return
	state.tags.erase(tag); _publish(state)

func _publish(state: Dictionary) -> void:
	var target = state.target.get_ref()
	if not is_instance_valid(target): return
	target.set_meta("magic_stasis", state.tags.has("stasis") or state.tags.has("frozen"))
	target.set_meta("magic_time_scale", float(state.get("slow_factor", 0.45)) if state.tags.has("slow") else 1.0)
	target.set_meta("magic_steam", state.tags.has("steam"))
	target.set_meta("magic_gravity_scale", 0.0 if not state.motions.is_empty() else 1.0)

func apply_enemy(effect: String, enemy: Node3D, spell: Dictionary, center: Vector3, direction: Vector3) -> void:
	if effect in ["slow", "stasis", "suspend"]:
		var duration := float(spell.duration) * (0.5 if enemy.is_in_group("deep_boss") else 1.0)
		if effect == "slow":
			var state := _state(enemy, true)
			if not state.is_empty(): state.slow_factor = float(spell.slow_factor)
		set_status(enemy, "slow" if effect == "slow" else "stasis", duration)
		return
	var radial: Vector3 = runtime._target_center(enemy) - center
	var away: Vector3 = radial.normalized() if radial.length_squared() > 0.04 else direction
	if effect in ["push", "pull", "repel", "launch"]:
		var impulse: Vector3 = away * float(spell.force)
		if effect == "push": impulse = direction * float(spell.force)
		elif effect == "pull": impulse = -away * float(spell.force)
		elif effect == "launch": impulse = (direction + Vector3.UP * 0.6).normalized() * float(spell.force)
		if enemy.has_method("receive_impulse"): enemy.receive_impulse(impulse.limit_length(30.0))
		return
	if effect not in ["levitate", "orbit", "gravity_well"]: return
	var state := _state(enemy, true)
	if state.is_empty(): return
	for motion in state.motions:
		if motion.effect == effect: motion.remaining = float(spell.duration); return
	state.motions.append({"effect": effect, "remaining": float(spell.duration), "age": 0.0, "force": float(spell.force), "anchor": center,
		"radius": float(spell.orbit_radius), "lift": enemy.global_position + Vector3.UP * 1.2})
	_publish(state)

func _tick_states(dt: float) -> void:
	for i in range(target_states.size() - 1, -1, -1):
		var state: Dictionary = target_states[i]
		var target = state.target.get_ref()
		if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion() or (target.get("health") != null and int(target.get("health")) <= 0):
			_restore_state(i); continue
		for tag in state.tags.keys():
			state.tags[tag] -= dt
			if float(state.tags[tag]) <= 0: state.tags.erase(tag)
		for j in range(state.motions.size() - 1, -1, -1):
			var motion: Dictionary = state.motions[j]; motion.remaining -= dt; motion.age += dt
			if motion.remaining <= 0: state.motions.remove_at(j); continue
			var goal: Vector3 = motion.lift if motion.effect == "levitate" else motion.anchor
			if motion.effect == "orbit": goal += Vector3(cos(motion.age * 1.8), 0.6, sin(motion.age * 1.8)) * float(motion.radius)
			if target.has_method("receive_impulse") and not state.tags.has("stasis"):
				var displacement: Vector3 = goal - target.global_position
				var impulse: Vector3 = displacement * float(motion.force) * minf(dt, 0.1)
				target.receive_impulse(impulse.limit_length(2.0))
		_publish(state)
		if state.tags.is_empty() and state.motions.is_empty(): _restore_state(i)

func _restore_state(index: int) -> void:
	var state: Dictionary = target_states[index]; target_states.remove_at(index)
	var target = state.target.get_ref()
	if not is_instance_valid(target): return
	for key in state.originals:
		if state.originals[key].present: target.set_meta(key, state.originals[key].value)
		elif target.has_meta(key): target.remove_meta(key)

func cone(spell: Dictionary, origin: Vector3, direction: Vector3, context: Dictionary) -> void:
	var scan := spell.duplicate(); scan.radius = float(spell.range)
	var cosine := cos(deg_to_rad(float(spell.cone_angle)) * 0.5)
	for target in runtime._near_targets(origin, scan):
		var center: Vector3 = runtime._target_center(target)
		var delta := center - origin
		if delta.length_squared() < 0.01 or (delta.normalized().dot(direction) >= cosine and runtime._clear_line(origin, center, target)):
			runtime._contact(target, center, spell, context)
	runtime._glyph(origin + direction * minf(2.0, float(spell.range) * 0.4), spell, "cone", 0.45, minf(3.0, float(spell.radius)))

func rain(spell: Dictionary, origin: Vector3, target: Vector3, context: Dictionary) -> void:
	var center: Vector3 = origin + (target - origin).limit_length(float(spell.range))
	var obstruction: Dictionary = runtime._ray(origin, center)
	if not obstruction.is_empty(): center = obstruction.position + obstruction.normal * 0.1
	for i in range(int(spell.count)):
		var angle := float(i) * 2.39996
		var radius := 0.0 if i == 0 else sqrt(float(i) / float(spell.count)) * float(spell.radius) * 0.75
		var floor_point := center + Vector3(cos(angle), 0, sin(angle)) * radius
		var sky := floor_point + Vector3.UP * float(spell.rain_height)
		var cover: Dictionary = runtime._ray(floor_point + Vector3.UP * 0.1, sky, 1 | 8 | 16)
		if not cover.is_empty(): sky = cover.position + cover.normal * 0.1
		runtime._spawn_or_schedule(spell, sky, Vector3.DOWN, context, i, float(i) * float(spell.stagger))
	runtime._glyph(center, spell, "rain", 0.8, float(spell.radius))

func trap(spell: Dictionary, origin: Vector3, target: Vector3, context: Dictionary) -> void:
	var point: Vector3 = origin + (target - origin).limit_length(float(spell.range))
	var blocked: Dictionary = runtime._ray(origin, point)
	if not blocked.is_empty(): point = blocked.position + blocked.normal * 0.1
	traps.append({"point": point, "spell": spell, "context": context, "remaining": float(spell.duration)})
	consume(context, "traps"); work(context, 1)
	runtime._glyph(point, spell, "trap", float(spell.duration), float(spell.radius))

func _tick_traps(dt: float) -> void:
	for i in range(traps.size() - 1, -1, -1):
		var trap_data: Dictionary = traps[i]; trap_data.remaining -= dt
		var triggered := false
		for target in runtime._near_targets(trap_data.point, trap_data.spell):
			if runtime._clear_line(trap_data.point, runtime._target_center(target), target):
				runtime._contact(null, trap_data.point, trap_data.spell, trap_data.context, true); triggered = true; break
		if triggered or trap_data.remaining <= 0:
			traps.remove_at(i); work(trap_data.context, -1)

func wall_solution(spell: Dictionary, origin: Vector3, target: Vector3) -> Dictionary:
	var base: Vector3 = origin + (target - origin).limit_length(float(spell.range))
	var blocked: Dictionary = runtime._ray(origin, base)
	if not blocked.is_empty(): base = blocked.position + blocked.normal * (float(spell.wall_thickness) * 0.5 + 0.08)
	var ground: Dictionary = runtime._ray(base + Vector3.UP * 1.0, base + Vector3.DOWN * 5.0, 1 | 8 | 16)
	if not ground.is_empty() and ground.normal.y > 0.6: base.y = ground.position.y
	var flat := target - origin; flat.y = 0
	var angle := atan2(-flat.x, -flat.z) if flat.length_squared() > 0.01 else 0.0
	var shape := BoxShape3D.new(); shape.size = Vector3(float(spell.wall_width), float(spell.wall_height), float(spell.wall_thickness))
	var transform := Transform3D(Basis(Vector3.UP, angle), base + Vector3.UP * (float(spell.wall_height) * 0.5 + 0.025))
	var result: Dictionary = {"valid": false, "shape": shape, "transform": transform, "reason": "Make room for the whole wall."}


	var local_player: Vector3 = transform.affine_inverse() * (runtime.game.player.global_position + Vector3.UP * 0.62)
	if absf(local_player.x) < shape.size.x * 0.5 + 0.2 and absf(local_player.y) < shape.size.y * 0.5 + 0.61 and absf(local_player.z) < shape.size.z * 0.5 + 0.2:
		result.reason = "Move the wall away from yourself."; return result
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.transform = transform; query.collision_mask = 1 | 2 | 4 | 8 | 16; query.margin = 0.015
	if not runtime.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return result
	result.valid = true; result.reason = "CAST · Raise wall"; return result

func wall_transform(spell: Dictionary, origin: Vector3, target: Vector3) -> Dictionary:
	var result := wall_solution(spell, origin, target)
	return result if result.valid else {}

func wall(spell: Dictionary, origin: Vector3, target: Vector3, context: Dictionary) -> void:
	var placement := wall_transform(spell, origin, target)
	consume(context, "constructs")
	if placement.is_empty(): return
	var node := StaticBody3D.new(); node.name = "TemporarySpellWall"; node.collision_layer = 1 | 16; node.collision_mask = 1 | 2 | 4 | 8 | 16
	var col := CollisionShape3D.new(); col.shape = placement.shape; node.add_child(col)
	runtime.add_child(node); node.global_transform = placement.transform; node.set_meta("temporary_magic", true)
	var art := _wall_art(node, placement.shape.size, spell)
	constructs.append({"node": node, "remaining": float(spell.duration), "context": context, "art": art, "age": 0.0, "height": float(placement.shape.size.y)})
	work(context, 1); runtime._glyph(node.global_position, spell, "wall", 0.5, float(spell.radius))

## Stacked, slightly irregular blocks merged into one mesh (one draw call). Earth walls get
## offset masonry courses; other elements get taller crystal-like slabs.
func _wall_art(parent: Node3D, size: Vector3, spell: Dictionary) -> Node3D:
	var art := Node3D.new(); art.name = "WallArt"; parent.add_child(art)
	var rng := RandomNumberGenerator.new(); rng.seed = hash(str(spell.get("id", "wall"))) ^ int(parent.global_position.x * 7.0)
	var earth := str(spell.get("element", "")) == "earth"
	var rows := maxi(2, int(round(size.y / (0.5 if earth else 0.9))))
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var block := BoxMesh.new(); block.size = Vector3.ONE
	for row in range(rows):
		var h := size.y / rows
		var y := -size.y * 0.5 + h * (row + 0.5)
		var width := (0.62 if earth else 0.45) * (1.0 + rng.randf_range(-0.15, 0.15))
		var cols := maxi(2, int(round(size.x / width)))
		var offset := (0.5 if row % 2 == 1 and earth else 0.0)
		for col in range(cols + (1 if offset > 0 else 0)):
			var w := size.x / cols
			var x := -size.x * 0.5 + w * (col + 0.5 - offset)
			var left := maxf(x - w * 0.5, -size.x * 0.5); var right := minf(x + w * 0.5, size.x * 0.5)
			if right - left < 0.08: continue
			var dims := Vector3((right - left) * 0.94, h * (0.9 if earth else rng.randf_range(0.85, 1.15)), size.z * rng.randf_range(0.85, 1.12))
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))).scaled(dims)
			tool.append_from(block, 0, Transform3D(basis, Vector3((left + right) * 0.5, y, rng.randf_range(-0.04, 0.04) * size.z)))
	# A cap row of chunky crenels / shards along the top.
	var caps := maxi(2, int(size.x / 0.55))
	for c in range(caps):
		if c % 2 == 1 and earth: continue
		var cw := size.x / caps
		var cap_h := rng.randf_range(0.18, 0.32) if earth else rng.randf_range(0.25, 0.6)
		var cap_basis := Basis.from_euler(Vector3(0, 0, rng.randf_range(-0.12, 0.12))).scaled(Vector3(cw * 0.86, cap_h, size.z * 0.9))
		tool.append_from(block, 0, Transform3D(cap_basis, Vector3(-size.x * 0.5 + cw * (c + 0.5), size.y * 0.5 + cap_h * 0.5, 0)))
	tool.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.mesh = tool.commit()
	mesh.material_override = runtime._spell_material(spell)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	art.add_child(mesh)
	art.scale = Vector3(1, 0.02, 1); art.position.y = -size.y * 0.5
	return art

func _wall_pose(data: Dictionary) -> void:
	var art = data.get("art")
	if not is_instance_valid(art): return
	var h: float = data.height
	var rise := clampf(data.age / 0.28, 0.0, 1.0)
	# Pop up with a small overshoot, then sink back into the ground in the last half second.
	var grow := 1.0 + sin(rise * PI) * 0.12 * (1.0 - rise * 0.5) if rise < 1.0 else 1.0
	var s := ease(rise, 0.45) * grow * clampf(data.remaining / 0.45, 0.0, 1.0)
	s = maxf(s, 0.02)
	art.scale = Vector3(1.0, s, 1.0)
	art.position.y = -h * 0.5 * (1.0 - s)

func _tick_constructs(dt: float) -> void:
	for i in range(constructs.size() - 1, -1, -1):
		var data: Dictionary = constructs[i]; data.remaining -= dt
		data.age = float(data.get("age", 0.0)) + dt
		_wall_pose(data)
		if data.remaining <= 0 or not is_instance_valid(data.node):
			if is_instance_valid(data.node): data.node.free()
			constructs.remove_at(i); work(data.context, -1)

func summon(spell: Dictionary, origin: Vector3, target: Vector3, context: Dictionary) -> void:
	var base: Vector3 = origin + (target - origin).limit_length(minf(8.0, float(spell.range)))
	var blocked: Dictionary = runtime._ray(origin, base)
	if not blocked.is_empty(): base = blocked.position + blocked.normal * 0.7
	for i in range(int(spell.summon_count)):
		consume(context, "guardians")
		var node = Guardian.new(); node.name = "Temporary_" + str(spell.summon_kind); node.health = 4 + int(spell.power) * 2
		var shape := CapsuleShape3D.new(); shape.radius = 0.25; shape.height = 0.9
		var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.45; node.add_child(col)
		runtime.add_child(node); node.global_position = base + Vector3(float(i) * 0.8 - 0.4, 0, 0)
		runtime._piece(node, runtime._mesh("shard" if spell.summon_kind == "familiar" else "orb"), runtime._spell_material(spell), Vector3(0.3, 0.6, 0.3)).position.y = 0.55
		guardians.append({"node": node, "spell": spell, "context": context, "remaining": float(spell.duration), "attack_wait": 0.0, "seek_wait": 0.0, "target": null, "phase": float(i) * PI})
		work(context, 1)

func _tick_guardians(dt: float) -> void:
	for i in range(guardians.size() - 1, -1, -1):
		var data: Dictionary = guardians[i]; data.remaining -= dt
		if data.remaining <= 0 or not is_instance_valid(data.node) or data.node.is_queued_for_deletion():
			if is_instance_valid(data.node): data.node.free()
			guardians.remove_at(i); work(data.context, -1); continue
		var node: CharacterBody3D = data.node
		data.attack_wait = maxf(0.0, float(data.attack_wait) - dt); data.seek_wait -= dt
		if data.seek_wait <= 0:
			data.target = runtime._seek_target(node.global_position + Vector3.UP * 0.5, data.spell); data.seek_wait = 0.2
		var target = data.target.get_ref() if data.target is WeakRef else null
		var origin := node.global_position + Vector3.UP * 0.5
		var goal: Vector3 = runtime.game.player.global_position
		var visible_target: bool = runtime._live(target) and runtime._clear_line(origin, runtime._target_center(target), target)
		if visible_target: goal = target.global_position
		elif data.spell.summon_kind == "protector":
			data.phase += dt * 1.5; goal += Vector3(cos(data.phase), 0, sin(data.phase)) * 1.8
		var travel := goal - node.global_position
		travel.y = 0
		if travel.length() > 0.8:
			var motion: Vector3 = travel.normalized() * minf(3.0 * minf(dt, 0.25), travel.length())
			node.move_and_collide(motion)
		if data.spell.summon_kind == "familiar":
			var rise: float = (runtime.game.player.global_position.y + 0.8 - node.global_position.y) * minf(1.0, dt * 3)
			node.move_and_collide(Vector3.UP * rise)
		else: node.move_and_collide(Vector3.DOWN * minf(dt, 0.1) * 2.0)
		if visible_target and origin.distance_to(runtime._target_center(target)) < 1.8 and data.attack_wait <= 0:
			data.attack_wait = 0.8; runtime._contact(target, runtime._target_center(target), data.spell, data.context)
			runtime._beam_visual(origin, runtime._target_center(target), data.spell, 0.16, 0.04)

func clear() -> void:
	clearing = true
	for data in guardians + constructs:
		if is_instance_valid(data.node): data.node.free()
	guardians.clear(); constructs.clear(); traps.clear()
	for i in range(target_states.size() - 1, -1, -1): _restore_state(i)
	casts.clear(); stages.clear(); stage_events.clear()
	clearing = false

func stats() -> Dictionary:
	var reservations := 0
	for cast in casts:
		for key in ["projectiles", "events", "guardians", "constructs", "traps", "stages"]: reservations += int(cast.reserve[key])
	return {"stages": stages.size(), "guardians": guardians.size(), "constructs": constructs.size(), "traps": traps.size(), "target_states": target_states.size(), "reservations": reservations}
