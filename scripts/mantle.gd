extends RefCounted

const DURATION: float = 0.56
const COLLISION_MASK: int = 1 | 8
const MIN_RISE: float = 0.18
const LANDING_GAP: float = 0.04
const LIFT_PORTION: float = 0.6
const FLOOR_CONTACT_SLOP: float = 0.002

static func find_ledge(player: CharacterBody3D, direction: Vector3, max_rise: float = 1.55) -> Dictionary:
	if not is_instance_valid(player) or not player.is_inside_tree() or not direction.is_finite() or max_rise < MIN_RISE:
		return {}
	var collider: CollisionShape3D = _collision_shape(player)
	if collider == null or not collider.shape is CapsuleShape3D:
		return {}
	var forward := Vector3(direction.x, 0, direction.z).normalized()
	if forward.length_squared() < 0.5:
		return {}
	var radius: float = (collider.shape as CapsuleShape3D).radius * maxf(collider.global_basis.x.length(), collider.global_basis.z.length())
	var start := player.global_position


	var low_probe := start + Vector3.UP * 0.12
	var face: Dictionary = _ray(player, low_probe, low_probe + forward * (radius + 0.8))
	if face.is_empty():
		return {}
	var face_normal: Vector3 = face.normal
	if absf(face_normal.y) > 0.3 or face_normal.dot(-forward) < 0.5:
		return {}
	var inward := -Vector3(face_normal.x, 0, face_normal.z).normalized()
	var inside: Vector3 = face.position + inward * (radius + 0.06)
	var top: Dictionary = _ray(player, Vector3(inside.x, start.y + max_rise + 0.08, inside.z), Vector3(inside.x, start.y - 0.02, inside.z))
	if top.is_empty() or top.normal.y <= 0.65:
		return {}
	var rise: float = top.position.y - start.y
	if rise < MIN_RISE - 0.001 or rise > max_rise + 0.001:
		return {}
	var end: Vector3 = top.position + Vector3.UP * LANDING_GAP


	for i in range(8):
		var angle: float = TAU * i / 8.0
		var footprint := Vector3(cos(angle), 0, sin(angle)) * radius
		var support_at: Vector3 = top.position + footprint
		var support: Dictionary = _ray(player, support_at + Vector3.UP * 0.12, support_at - Vector3.UP * 0.12)
		if support.is_empty() or support.normal.y <= 0.65 or absf(support.position.y - top.position.y) > 0.08:
			return {}
	var lift := Vector3(start.x, end.y, start.z)


	if not step_is_clear(player, start, lift) or not step_is_clear(player, lift, end):
		return {}
	var along := inward.cross(Vector3.UP).normalized()
	var contacts: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var edge_at: Vector3 = face.position + inward * 0.04 + along * side * 0.21
		edge_at.y = top.position.y
		var contact: Dictionary = _ray(player, edge_at + Vector3.UP * 0.12, edge_at - Vector3.UP * 0.12)
		if contact.is_empty() or contact.normal.y <= 0.65 or absf(contact.position.y - top.position.y) > 0.08:
			return {}
		contacts.append(contact.position + Vector3.UP * 0.015)
	return {"start": start, "lift": lift, "end": end, "contacts": contacts}

static func path_position(start: Vector3, lift: Vector3, end: Vector3, t: float) -> Vector3:
	var progress := clampf(t, 0.0, 1.0)
	if progress <= LIFT_PORTION:
		return start.lerp(lift, smoothstep(0.0, LIFT_PORTION, progress))
	return lift.lerp(end, smoothstep(LIFT_PORTION, 1.0, progress))

static func step_is_clear(player: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or not from.is_finite() or not to.is_finite():
		return false
	var collider: CollisionShape3D = _collision_shape(player)
	if collider == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	var relative: Transform3D = player.global_transform.affine_inverse() * collider.global_transform
	var body_transform := player.global_transform
	body_transform.origin = from
	query.transform = body_transform * relative
	query.collision_mask = COLLISION_MASK
	query.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state


	var motion := to - from
	var floor_clearance: float = _floor_clearance(space, query, motion)
	if floor_clearance < 0:
		return false
	if floor_clearance > 0:



		query.transform.origin.y += floor_clearance
		if not space.intersect_shape(query, 1).is_empty():
			return false
		if motion.y <= floor_clearance:
			body_transform.origin = to
			query.transform = body_transform * relative
			return _floor_clearance(space, query, motion) >= 0
	query.motion = motion - Vector3.UP * floor_clearance
	var fractions := space.cast_motion(query)
	if fractions.size() < 2 or fractions[0] < 0.99999:
		return false
	body_transform.origin = to
	query.transform = body_transform * relative
	query.motion = Vector3.ZERO
	return _floor_clearance(space, query, motion) >= 0

static func _floor_clearance(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, motion: Vector3) -> float:
	var lifting: bool = motion.y > 0 and Vector2(motion.x, motion.z).length_squared() <= 1.0e-10
	if space.intersect_shape(query, 1).is_empty():


		if lifting:
			var rest: Dictionary = space.get_rest_info(query)
			if not rest.is_empty() and rest.normal.y > 0.65:
				return 0.0001
		return 0.0


	if not lifting:
		return -1.0
	var contacts: Array[Vector3] = space.collide_shape(query, 32)
	if contacts.is_empty():



		var rest: Dictionary = space.get_rest_info(query)
		return 0.0001 if not rest.is_empty() and rest.normal.y > 0.65 else -1.0
	if contacts.size() % 2 != 0 or contacts.size() >= 64:
		return -1.0
	var clearance: float = 0.0
	for i in range(0, contacts.size(), 2):
		var separation: Vector3 = contacts[i + 1] - contacts[i]
		var depth := separation.length()
		if depth <= 1.0e-07:
			var rest: Dictionary = space.get_rest_info(query)
			if rest.is_empty() or rest.normal.y <= 0.65:
				return -1.0
			clearance = maxf(clearance, 0.0001)
			continue
		if depth > FLOOR_CONTACT_SLOP or separation.normalized().y <= 0.65:
			return -1.0
		clearance = maxf(clearance, depth / separation.normalized().y + 0.0001)
	return clearance

static func _collision_shape(player: CharacterBody3D) -> CollisionShape3D:
	for child in player.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			return child
	return null

static func _ray(player: CharacterBody3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, COLLISION_MASK, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query)
