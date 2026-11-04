extends RefCounted


const Places = preload("res://scripts/locations.gd")
static func _surface(world, p: Vector2) -> Vector3:
	return Vector3(p.x, world.surface_height_at(p.x, p.y) + 0.22, p.y)
static func settlement_point(world, site: Dictionary) -> Vector3:
	var offset = 18.0 if world.atlas != null else 0.0
	return _surface(world, site.pos + Vector2(0, offset))
static func tower_point(tower: Node3D) -> Vector3:
	var entry = tower.get_node_or_null("BuildingEntry") as Node3D
	return entry.global_position if entry != null else tower.global_position + Vector3(0, 0.22, 7)
static func resolve(game, point: Vector3) -> Vector3:
	if not point.is_finite(): return Vector3.INF
	var world = game.world
	var inside = world.interior_at(point)
	if not inside.is_empty():


		for site in world.get_locations():
			if site.kind == "interior" and site.has("point") and world.interior_at(site.point) == inside: return _surface(world, site.pos)
		for site in Places.SITES:
			if str(site.id) == inside: return _surface(world, site.pos + Vector2(0, 4.5))
		return Vector3.INF
	var tower = game.get("wizard_tower")
	if is_instance_valid(tower) and Vector2(point.x - tower.global_position.x, point.z - tower.global_position.z).length() < 12 and absf(point.y - tower.global_position.y) < 25: return tower_point(tower)
	if world.atlas != null:
		for group in world.atlas.island_groups():
			if point.y > world.surface_height_at(point.x, point.z) + 12 and Vector2(point.x, point.z).distance_to(group.pos) < group.names.size() * 24 + 32: return _surface(world, group.lower_pos)
	return _surface(world, Vector2(point.x, point.z))

static func building_point(game, point: Vector3) -> Vector3:

	for house in game.get_tree().get_nodes_in_group("settlement_building"):
		if not game.world.is_ancestor_of(house) or house.is_queued_for_deletion(): continue
		var room = house.get_node_or_null("HouseholdInterior")
		var entry = house.get_node_or_null("BuildingEntry")
		if room == null or entry == null: continue
		var local: Vector3 = house.to_local(point)
		if absf(local.x) < room.width * 0.5 and absf(local.z) < room.depth * 0.5 and local.y > -0.5 and local.y < 4: return entry.global_position
	return point
