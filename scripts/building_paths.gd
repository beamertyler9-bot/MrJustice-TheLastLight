extends RefCounted


const B = preload("res://scripts/build.gd")
const Access = preload("res://scripts/building_access.gd")
const HALF = 0.98
const CLEARANCE = 1.22
const MAX_LENGTH = 180.0
const MAX_VERTICES = 24576

static func surface_material(ground: ShaderMaterial) -> ShaderMaterial:


	if ground.has_meta("building_path_material"): return ground.get_meta("building_path_material")
	var material = ShaderMaterial.new(); material.shader = preload("res://shaders/building_path.gdshader")
	for uniform in ground.shader.get_shader_uniform_list():
		var value = ground.get_shader_parameter(uniform.name)
		if value != null: material.set_shader_parameter(uniform.name, value)
	ground.set_meta("building_path_material", material)
	return material

static func sync_material(ground: ShaderMaterial) -> void:
	if not ground.has_meta("building_path_material"): return
	var material: ShaderMaterial = ground.get_meta("building_path_material")
	material.set_shader_parameter("clearing_count", ground.get_shader_parameter("clearing_count"))
	material.set_shader_parameter("clearings", ground.get_shader_parameter("clearings"))

static func frame(node: Node3D) -> Transform3D:

	var result = Transform3D.IDENTITY
	while node is Node3D:
		result = node.transform * result; node = node.get_parent() as Node3D
	return result

static func streets(world, site: Dictionary) -> Array:
	var result: Array = []
	var at: Vector2 = site.pos; var reach: float = site.get("clearance", 70.0)


	if site.get("kind", "") in ["city", "town", "village"]:
		if world.get("atlas") != null or site.get("kind", "") == "city":
			result.append([at - Vector2(reach - 0.1, 0), at + Vector2(reach - 0.1, 0)])
			result.append([at - Vector2(0, reach - 0.1), at + Vector2(0, reach - 0.1)])
		else: result.append([at - Vector2(0, 25.9), at + Vector2(0, 25.9)])
		return result
	if world.get("atlas") != null:
		for road in world.atlas._near(at).roads: result.append([road.a, road.b])
	else:
		var P = load("res://scripts/locations.gd")
		for road in P.ROUTES + P.FRONTIER_ROUTES + [P.TOWER_ROUTE]: result.append(road)
	return result

static func footprint(transform_value: Transform3D, width: float, depth: float, purpose: String = "home") -> Dictionary:

	return {"frame": transform_value, "rect": Rect2(-width * 0.5, -depth * 0.5, width + (3.8 if purpose in ["workshop", "smith_shop"] else 0.0), depth)}

static func planned(parent: Node3D, plots: Array, regional: bool = false) -> Array:
	var result: Array = []; var base = frame(parent)
	for i in range(plots.size()):
		var p: Dictionary = plots[i]
		var purpose = str(p.get("purpose", ["stores", "workshop", "library", "bakery", "home", "home", "inn", "home"][i % 8] if regional else "stores" if i == 0 else "workshop" if i == 1 else "home"))
		result.append(footprint(base * Transform3D(Basis(Vector3.UP, p.heading), Vector3(p.p.x, 0, p.p.y)), p.w, p.d, purpose))
	return result

static func civic(site: Dictionary) -> Array:


	var base = Transform3D(Basis.IDENTITY, Vector3(site.pos.x, 0, site.pos.y)); var result: Array = []
	var general = Vector3(11, 0, -11) if site.id == "bellcrown" else Vector3(8, 0, 5)
	result.append(footprint(base * Transform3D(Basis.IDENTITY, general), 7.2, 6.2, "stores"))
	result.append(footprint(base * Transform3D(Basis(Vector3.UP, PI), Vector3(-9, 0, -8)), 7.2, 6.2, "workshop"))
	if site.id == "bellcrown":
		for at in [Vector3(-11, 0, 8), Vector3(11, 0, 8), Vector3(-11, 0, 17), Vector3(11, 0, 15.5)]:
			result.append(footprint(base * Transform3D(Basis(Vector3.UP, PI * 0.5 if at.x < 0 else -PI * 0.5), at), 6.8, 5.8, "workshop" if at == Vector3(11, 0, 15.5) else "stores"))
		result.append(footprint(base * Transform3D(Basis.IDENTITY, Vector3(-15, 0, -38)), 8, 6.2, "inn"))
	for at in [Vector3(-5, 0, -14) if site.id == "bellcrown" else Vector3(-7, 0, 8), Vector3(7, 0, -17)]:
		result.append({"frame": base * Transform3D(Basis.IDENTITY, at), "rect": _fitted_bench_rect(), "clearance": 1.55})
	return result

static func _fitted_bench_rect() -> Rect2:

	var assets = load("res://scripts/imported_assets.gd"); var data = assets.entry("qprop_bench")
	var source = assets.mesh("qprop_bench")
	if source == null: return Rect2(-0.675, -0.2, 1.35, 0.4)
	var box: AABB = source.get_aabb(); var scale = Vector3(1.35 / float(data.bounds_size[0]), 0.91, 0.4 / float(data.bounds_size[2]))
	box = AABB(box.position * scale, box.size * scale)
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

static func reserve_mesh(parent: Node3D, prop: Node3D) -> void:
	var transform_value = frame(prop)
	var orientation = Transform3D(transform_value.basis.orthonormalized(), transform_value.origin)
	var box = AABB(); var found = false
	for art in prop.find_children("*", "MeshInstance3D", true, false):
		if art.mesh == null: continue
		var part = (orientation.affine_inverse() * frame(art)) * art.mesh.get_aabb()
		box = box.merge(part) if found else part; found = true
	if not found: return
	var props: Array = parent.get_meta("building_path_props", [])
	props.append({"frame": frame(parent).affine_inverse() * orientation, "rect": Rect2(box.position.x, box.position.z, box.size.x, box.size.z), "clearance": 1.02})
	parent.set_meta("building_path_props", props)

static func reserve_prop(parent: Node3D, at: Vector3, size: Vector2, heading: float = 0) -> void:
	var props: Array = parent.get_meta("building_path_props", [])
	props.append({"frame": Transform3D(Basis(Vector3.UP, heading), at), "rect": Rect2(-size * 0.5, size), "clearance": 1.02})
	parent.set_meta("building_path_props", props)

static func props(parent: Node3D) -> Array:
	var result: Array = []
	for node in [parent] + parent.find_children("*", "Node3D", true, false):
		if not node.has_meta("building_path_props"): continue

		var ancestor = node; var indoors = false
		while ancestor != null:
			if ancestor.is_in_group("settlement_building"): indoors = true; break
			ancestor = ancestor.get_parent()
		if indoors: continue
		for prop in node.get_meta("building_path_props"):
			result.append({"frame": frame(node) * prop.frame, "rect": prop.rect, "clearance": prop.clearance})
	return result

static func complete(world, parent: Node3D, site: Dictionary, plots: Array = []) -> void:
	var obstacles = planned(parent, plots, world.get("atlas") != null) + props(parent)
	if world.get("atlas") != null: obstacles.append_array(civic(site))
	var buildings = parent.find_children("*", "Node3D", true, false).filter(func (n): return n.is_in_group("settlement_building"))
	for house in buildings: obstacles.append(footprint(frame(house), house.get_meta("building_width"), house.get_meta("building_depth"), house.get_meta("purpose", "home")))
	var roads = streets(world, site)
	for house in buildings: attach(house, world, roads, obstacles)
	batch(parent)

static func _flat(p: Vector3) -> Vector2: return Vector2(p.x, p.z)

static func _crosses(a: Vector2, b: Vector2, obstacle: Dictionary) -> bool:
	var inverse: Transform3D = obstacle.frame.affine_inverse()
	var aa = _flat(inverse * Vector3(a.x, 0, a.y)); var bb = _flat(inverse * Vector3(b.x, 0, b.y))
	var rect: Rect2 = obstacle.rect.grow(float(obstacle.get("clearance", CLEARANCE)))

	var enter = 0.0; var leave = 1.0; var delta = bb - aa
	for axis in range(2):
		if absf(delta[axis]) < 1.0e-05:
			if aa[axis] <= rect.position[axis] or aa[axis] >= rect.end[axis]: return false
		else:
			var t0 = (rect.position[axis] - aa[axis]) / delta[axis]; var t1 = (rect.end[axis] - aa[axis]) / delta[axis]
			enter = maxf(enter, minf(t0, t1)); leave = minf(leave, maxf(t0, t1))
	return leave > enter + 1.0e-05 and leave > 1.0e-05 and enter < 0.99999

static func _clear(a: Vector2, b: Vector2, obstacles: Array) -> bool:
	for obstacle in obstacles:
		if _crosses(a, b, obstacle): return false
	return true

static func route(start: Vector2, roads: Array, obstacles: Array) -> PackedVector2Array:


	var nodes: Array[Vector2] = [start]; var goals: Array[int] = []
	for obstacle in obstacles:
		var rect: Rect2 = obstacle.rect.grow(float(obstacle.get("clearance", CLEARANCE)) + 0.04)
		for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var q = _flat(obstacle.frame * Vector3(p.x, 0, p.y))
			if q.distance_to(start) < MAX_LENGTH: nodes.append(q)
	var corner_count = nodes.size()
	for i in range(corner_count):


		var candidates: Array = []
		for road in roads:
			var q = Geometry2D.get_closest_point_to_segment(nodes[i], road[0], road[1])
			if q.distance_to(start) < MAX_LENGTH: candidates.append(q)
		candidates.sort_custom(func (a, b): return a.distance_squared_to(nodes[i]) < b.distance_squared_to(nodes[i]))
		for q in candidates.slice(0, 3):
			if _clear(nodes[i], q, obstacles): goals.append(nodes.size()); nodes.append(q)
	var costs: Array[float] = []; var previous: Array[int] = []; var visited = {}
	for i in nodes.size(): costs.append(INF); previous.append(-1)
	costs[0] = 0
	for iteration in nodes.size():
		var current = -1; var best = INF
		for i in nodes.size():
			if not visited.has(i) and costs[i] < best: best = costs[i]; current = i
		if current < 0 or best > MAX_LENGTH: break
		if goals.has(current):
			var result = PackedVector2Array()
			while current >= 0: result.insert(0, nodes[current]); current = previous[current]
			return result
		visited[current] = true
		for next in nodes.size():
			if visited.has(next): continue
			var distance = costs[current] + nodes[current].distance_to(nodes[next])
			if distance < costs[next] and _clear(nodes[current], nodes[next], obstacles): costs[next] = distance; previous[next] = current
	return PackedVector2Array()

static func _natural_route(points: PackedVector2Array, obstacles: Array) -> PackedVector2Array:
	if points.size() < 2: return points
	var result = PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var a = points[i - 1]; var b = points[i]; var direction = (b - a).normalized()
		var pieces = maxi(1, ceili(a.distance_to(b) / 4.0))
		for j in range(1, pieces):
			var t = float(j) / pieces
			var p = a.lerp(b, t)

			var shift = sin(t * PI) * sin(p.x * 0.31 + p.y * 0.27) * 0.085
			var candidate = p + direction.orthogonal() * shift
			if _clear(result[-1], candidate, obstacles) and _clear(candidate, b, obstacles): p = candidate
			result.append(p)
		result.append(b)
	return result

static func attach(house: Node3D, world, roads: Array, all_obstacles: Array) -> void:
	if house.get_node_or_null("BuildingApproach") != null: return
	var transform_value = frame(house); var depth: float = house.get_meta("building_depth")
	var start3 = transform_value * Vector3(0, 0.034, depth * 0.5 + 2.35); var start = _flat(start3)
	var obstacles: Array = [footprint(transform_value, house.get_meta("building_width"), depth, house.get_meta("purpose", "home"))]
	for obstacle in all_obstacles:
		if _flat(obstacle.frame.origin).distance_to(_flat(transform_value.origin)) < 0.1: continue

		if _flat(obstacle.frame.origin).distance_to(start) < MAX_LENGTH: obstacles.append(obstacle)
	Access.ground_exterior(house, world)
	var points = _natural_route(route(start, roads, obstacles), obstacles)
	if points.size() < 2:
		push_warning("No clear building approach for " + str(house.get_meta("plot_id", house.name))); return
	var path = Node3D.new(); path.name = "BuildingApproach"; path.add_to_group("batch_dynamic"); house.add_child(path)
	var centerline = PackedVector3Array()
	for p in points: centerline.append(Vector3(p.x, world.surface_height_at(p.x, p.y) + 0.018, p.y))
	path.set_meta("centerline", centerline); path.set_meta("obstacles", obstacles)
	var mesh = _paint(_ribbon(world, points, start3, transform_value.affine_inverse()), world, transform_value)
	var material = surface_material(world.ground_mat)
	var art = B.mesh(path, mesh, material); art.name = "Surface"; art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	B.solid(path, Vector3.ZERO, mesh.create_trimesh_shape())

static func _paint(source: Mesh, world, transform_value: Transform3D) -> ArrayMesh:


	var mesh = ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays = source.surface_get_arrays(surface); var colors = PackedColorArray()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var cache = {}; var samples = {}
		for i in vertices.size():
			var p = transform_value * vertices[i]
			var key = Vector2(p.x, p.z)
			if not samples.has(key):
				var data = _terrain_attributes(world, key, cache)
				data.soil = world.ground_color_at(p.x, p.z, p.y, data.normal, true)
				samples[key] = data
			var data: Dictionary = samples[key]


			var edge: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var wear = 1.0 - smoothstep(0.48, 1.0, absf(edge[i].x))
			var tint: Color = data.color
			var soil: Color = data.soil
			colors.append(tint.lerp(soil, wear))
			normals[i] = (transform_value.basis.transposed() * data.normal).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _terrain_attributes(world, p: Vector2, cache: Dictionary) -> Dictionary:


	var coarse = (p / 3.0).floor() * 3.0
	var fine = world.has_method("_cleared_height") and world.camp_ground.fine_cell(coarse.x, coarse.y)
	var step = 1.0 if fine else 3.0
	var origin = (p / step).floor() * step; var uv = (p - origin) / step
	var corners = [origin, origin + Vector2(step, 0), origin + Vector2(0, step)] if uv.x + uv.y <= 1 else [origin + Vector2(step, step), origin + Vector2(0, step), origin + Vector2(step, 0)]
	var weights = Vector3(1.0 - uv.x - uv.y, uv.x, uv.y) if uv.x + uv.y <= 1 else Vector3(uv.x + uv.y - 1.0, 1.0 - uv.x, 1.0 - uv.y)
	var normal = Vector3.ZERO; var color = Color(0, 0, 0, 0)
	for i in range(3):
		var q: Vector2 = corners[i]
		var key = Vector3(q.x, q.y, step)
		if not cache.has(key):
			var h: float = world._cleared_height(q.x, q.y) if fine else world.height_at(q.x, q.y)
			var n = Vector3(world._cleared_height(q.x - 0.2, q.y) - world._cleared_height(q.x + 0.2, q.y), 0.4, world._cleared_height(q.x, q.y - 0.2) - world._cleared_height(q.x, q.y + 0.2)).normalized() if fine else Vector3(world.height_at(q.x - 0.2, q.y) - world.height_at(q.x + 0.2, q.y), 0.4, world.height_at(q.x, q.y - 0.2) - world.height_at(q.x, q.y + 0.2)).normalized()
			cache[key] = {"normal": n, "color": world.ground_color_at(q.x, q.y, h, n)}
		normal += cache[key].normal * weights[i]; color += cache[key].color * weights[i]
	return {"normal": normal.normalized(), "color": color}

static func _ribbon_width(p: Vector2, quad: PackedVector2Array) -> float:


	var diagonal = quad[2] - quad[0]
	if diagonal.cross(p - quad[0]) * diagonal.cross(quad[1] - quad[0]) >= 0:
		return clampf(2 * (quad[1] - quad[0]).cross(p - quad[0]) / (quad[1] - quad[0]).cross(diagonal) - 1, -1, 1)
	return clampf(1 - 2 * (quad[2] - p).cross(quad[3] - p) / diagonal.cross(quad[3] - quad[0]), -1, 1)

static func _clipped_strips(strips: Array, triangle: PackedVector2Array) -> Array:
	var pieces: Array = []
	for strip in strips: pieces.append_array(Geometry2D.intersect_polygons(strip, triangle))
	return pieces

static func _terrain_triangles(world, x: int, z: int) -> Array:
	var parts = 3 if world.has_method("_cleared_height") and world.camp_ground.fine_cell(x * 3, z * 3) else 1
	var step = 3.0 / parts; var triangles: Array = []
	for j in range(parts):
		for i in range(parts):
			var o = Vector2(x * 3 + i * step, z * 3 + j * step)
			triangles.append(PackedVector2Array([o, o + Vector2(step, 0), o + Vector2(0, step)]))
			triangles.append(PackedVector2Array([o + Vector2(step, 0), o + Vector2(step, step), o + Vector2(0, step)]))
	return triangles

static func _ribbon(world, points: PackedVector2Array, _start: Vector3, inverse: Transform3D) -> ArrayMesh:
	var vertices = PackedVector3Array(); var normals = PackedVector3Array(); var uvs = PackedVector2Array(); var edges = PackedVector2Array(); var traveled = 0.0
	var total_length = 0.0
	for i in range(1, points.size()): total_length += points[i - 1].distance_to(points[i])



	var left = PackedVector2Array(); var right = PackedVector2Array()
	for i in points.size():
		var before = (points[i] - points[maxi(0, i - 1)]).normalized(); var after = (points[mini(points.size() - 1, i + 1)] - points[i]).normalized()
		if before.is_zero_approx(): before = after
		if after.is_zero_approx(): after = before
		var normal = (before.orthogonal() + after.orthogonal()).normalized()
		var offset = normal * minf(HALF / maxf(0.4, normal.dot(after.orthogonal())), CLEARANCE - 0.05)
		left.append(points[i] + offset); right.append(points[i] - offset)
	for segment in range(points.size() - 1):
		var a: Vector2 = points[segment]; var b: Vector2 = points[segment + 1]; var length = a.distance_to(b)
		var start_edge = (right[segment] - left[segment]).normalized()
		var end_edge = (right[segment + 1] - left[segment + 1]).normalized()
		var polygon = PackedVector2Array([left[segment], left[segment + 1], right[segment + 1], right[segment]])
		var strips: Array = []
		for band in range(4):
			var lo = float(band) / 4; var hi = float(band + 1) / 4
			strips.append(PackedVector2Array([left[segment].lerp(right[segment], lo), left[segment + 1].lerp(right[segment + 1], lo), left[segment + 1].lerp(right[segment + 1], hi), left[segment].lerp(right[segment], hi)]))
		var bounds = Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: bounds = bounds.expand(p)
		for z in range(floori(bounds.position.y / 3), floori(bounds.end.y / 3) + 1):
			for x in range(floori(bounds.position.x / 3), floori(bounds.end.x / 3) + 1):
				for triangle in _terrain_triangles(world, x, z):
					for piece in _clipped_strips(strips, triangle):
						for i in range(1, piece.size() - 1):
							var face: Array[Vector3] = []; var edge: Array[Vector2] = []
							for p in [piece[0], piece[i], piece[i + 1]]:
								var ground: float = world.surface_height_at(p.x, p.y) + 0.018
								var y = ground
								face.append(inverse * Vector3(p.x, y, p.y))
								var from_start = absf(start_edge.cross(p - left[segment]))
								var to_end = absf(end_edge.cross(p - left[segment + 1]))
								var distance = traveled + length * from_start / maxf(1.0e-06, from_start + to_end)
								edge.append(Vector2(_ribbon_width(p, polygon), clampf(minf(distance, total_length - distance), 0.0, 1.0)))
							var normal = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
							if normal.y < 0: normal = -normal
							if (face[1] - face[0]).cross(face[2] - face[0]).y > 0: face.reverse(); edge.reverse()
							for j in face.size():
								var v = face[j]; vertices.append(v); normals.append(normal); uvs.append(Vector2(v.x, v.z)); edges.append(edge[j])
		traveled += length
	assert(vertices.size() <= MAX_VERTICES, "Building path exceeds bounded geometry")
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_TEX_UV2] = edges
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh

static func batch(parent: Node3D) -> void:


	var old = parent.get_node_or_null("BuildingApproachBatch")
	if old != null: old.free()
	var vertices = PackedVector3Array(); var normals = PackedVector3Array(); var uvs = PackedVector2Array(); var edges = PackedVector2Array(); var colors = PackedColorArray(); var material: Material; var inverse = frame(parent).affine_inverse()
	for path in parent.find_children("BuildingApproach", "Node3D", true, false):

		for art in [path.get_node("Surface")]:
			var t = inverse * frame(art); var arrays = art.mesh.surface_get_arrays(0); material = art.material_override
			var order = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else range(arrays[Mesh.ARRAY_VERTEX].size())
			var normal_basis = t.basis.inverse().transposed()
			for i in order:
				var p = t * arrays[Mesh.ARRAY_VERTEX][i]; vertices.append(p); uvs.append(Vector2(p.x, p.z))
				edges.append(arrays[Mesh.ARRAY_TEX_UV2][i])
				normals.append((normal_basis * arrays[Mesh.ARRAY_NORMAL][i]).normalized()); colors.append(arrays[Mesh.ARRAY_COLOR][i])
			art.hide()
	if vertices.is_empty(): return
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_TEX_UV2] = edges; arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var art = B.mesh(parent, mesh, material); art.name = "BuildingApproachBatch"; art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
