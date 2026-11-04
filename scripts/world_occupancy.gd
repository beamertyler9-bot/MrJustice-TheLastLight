extends RefCounted

const CampGround = preload("res://scripts/camp_ground.gd")
static func placeable_rect(center: Vector2, item: String) -> Rect2:
	var half := CampGround.OUTER if item == "camp_kit" else 1.4
	return Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2)

static func conflicts(state, footprint: Rect2, clearings: bool = true) -> bool:
	if state.camp_placed and footprint.intersects(placeable_rect(Vector2(state.camp_position.x, state.camp_position.z), "camp_kit")):
		return true
	if state.workbench_placed and footprint.intersects(placeable_rect(Vector2(state.workbench_position.x, state.workbench_position.z), "crafting_table")):
		return true
	if clearings:
		for record in state.camp_clearings:
			var p = Vector2(record.position[0], record.position[2])
			if footprint.intersects(placeable_rect(p, "camp_kit")):
				return true
	return false
static func entrance_offset(world, base: Vector3, yaw: float = 0) -> Vector2:
	var offsets: Array[Vector2] = [Vector2(0, 2).rotated(-yaw), Vector2(0, 6).rotated(-yaw)]
	for i in range(8): offsets.append(Vector2.from_angle(i * TAU / 8) * 10)
	for offset in offsets:
		var p = Vector2(base.x, base.z) + offset
		if not conflicts(world.state, Rect2(p - Vector2.ONE * 0.6, Vector2.ONE * 1.2), false) and world.dry_surface_at(p, 0.4): return offset
	return Vector2(0, 10).rotated(-yaw)
static func oriented_rect(center: Vector2, rect: Rect2, yaw: float) -> Rect2:
	var points = [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
	var result = Rect2(center + points[0].rotated(-yaw), Vector2.ZERO)
	for point in points: result = result.expand(center + point.rotated(-yaw))
	return result
