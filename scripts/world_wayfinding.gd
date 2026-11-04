extends RefCounted
const P = preload("res://scripts/locations.gd")
const B = preload("res://scripts/build.gd")
static func junctions(roads: Array) -> Array:
	var points = {}
	for road in roads:
		for pair in [[road.a, road.b], [road.b, road.a]]:
			var p: Vector2 = pair[0]; var key = Vector2i(roundi(p.x), roundi(p.y))
			if not points.has(key): points[key] = {"p": p, "arms": []}
			var direction = (pair[1] - p).normalized(); var duplicate = false
			for arm in points[key].arms:
				if arm.dot(direction) > 0.98: duplicate = true; break
			if not duplicate: points[key].arms.append(direction)
	return points.values().filter(func (j): return j.arms.size() >= 3)
static func build(parent: Node3D, world) -> void:
	for j in junctions(world.atlas.roads()):
		var p: Vector2 = j.p; var allowed = true
		for site in world.atlas.sites():
			if p.distance_to(site.pos) < 90: allowed = false; break
		if not allowed: continue
		var at = p + j.arms[0].orthogonal() * 4.5; var h: float = world.surface_height_at(at.x, at.y)
		if not world.atlas.liquid_at(at).is_empty(): continue
		var sign = P.signboard(parent, Vector3(at.x, h + 1.65, at.y), "CROSSROADS", 0, 2.5, "crossroads")
		P.cull_art(sign, 95)
