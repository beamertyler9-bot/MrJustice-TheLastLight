extends RefCounted


const PATH = "res://assets/world/fixed/water.bin"
static var _data: Dictionary = {}
static var _grid: Dictionary = {}
static func _load() -> void:
	if not _data.is_empty(): return
	_data = FileAccess.open(PATH, FileAccess.READ).get_var()
	for river in _data.rivers: _seat_river(river)
	for lake in _data.lakes:
		_fit_summit_spring(lake)
		_seat_lake(lake)
	for river in _data.rivers:
		for i in range(river.sections.size() - 1):
			var a = river.sections[i]; var b = river.sections[i + 1]
			var bounds = Rect2(a.left, Vector2.ZERO).expand(a.right).expand(b.left).expand(b.right)
			_register(bounds, {"kind": river.kind, "a": a, "b": b})
	for lake in _data.lakes:
		_register(Rect2(lake.pos - lake.extent, lake.extent * 2), {"kind": lake.kind, "lake": lake})




static func _fit_summit_spring(lake: Dictionary) -> void:
	if lake.get("id", "") == "fizzpeak_summit_pool": return
	if lake.kind != "cola" or float(lake.height) < 700.0: return
	for river in _data.rivers:
		if river.get("id", "") != "fizzpeak_cascade" or river.sections.size() < 2: continue
		var first: Dictionary = river.sections[0]
		var head: Vector2 = first.get("channel_center", (first.left + first.right) * 0.5)
		if lake.pos.distance_to(head) > 24.0: continue
		var along: Vector2 = (river.sections[1].channel_center - head).normalized()
		var across: Vector2 = (first.right - first.left).normalized()
		var radius: float = first.left.distance_to(first.right) * 0.5
		var outline := PackedVector2Array()
		for i in range(25):
			var angle := PI * float(i) / 24.0
			outline.append(head + across * cos(angle) * radius - along * sin(angle) * radius)
		lake.id = "fizzpeak_spring"
		lake.pos = head - along * radius * 0.35
		lake.outline = outline
		lake.extent = Vector2.ZERO
		for point in outline: lake.extent = lake.extent.max((point - lake.pos).abs())
		lake.height = first.height
		lake.depth = 0.0
		lake.terrain_fitted = true
		lake.natural_shore = true
		return




static func _seat_river(river: Dictionary) -> void:
	if river.get("terrain_fitted", false): return
	var sections: Array = river.sections
	var count := sections.size()
	if count == 0: return
	var wanted := PackedFloat32Array(); wanted.resize(count)
	var bed := PackedFloat32Array(); bed.resize(count)
	for i in range(count):
		var s: Dictionary = sections[i]
		bed[i] = terrain_height((s.left + s.right) * 0.5)
		var bank := minf(terrain_height(s.left), terrain_height(s.right))
		wanted[i] = minf(float(s.height), bank - 0.12)
	for i in range(count):
		var h := float(sections[i].height)
		for j in range(maxi(0, i - 3), mini(count, i + 4)): h = minf(h, wanted[j])
		sections[i].height = minf(float(sections[i].height), maxf(h, bed[i] + 1.4))
	for s in sections:
		var height := float(s.height)
		var centre: Vector2 = (s.left + s.right) * 0.5
		for key in ["left", "right"]:
			var edge: Vector2 = s[key]
			if terrain_height(edge) >= height - 0.02: continue
			var out := (edge - centre).normalized()
			for step in range(1, 21):
				var q := edge + out * (step * 0.5)
				if terrain_height(q) >= height + 0.05:
					s[key] = q; break
		var low := minf(terrain_height(s.left), terrain_height(s.right))
		if low < height - 0.02: s.height = maxf(low - 0.12, terrain_height((s.left + s.right) * 0.5) + 0.4)




static func _seat_lake(lake: Dictionary) -> void:
	if lake.get("terrain_fitted", false): return
	var height := float(lake.height)
	var centre: Vector2 = lake.pos
	var outline: PackedVector2Array = PackedVector2Array(lake.outline)
	for i in range(outline.size()):
		var edge: Vector2 = outline[i]
		if terrain_height(edge) >= height - 0.02: continue
		var out := (edge - centre).normalized()
		var moved := false
		for step in range(1, 41):
			var q := edge + out * (step * 0.5)
			if terrain_height(q) >= height + 0.05:
				outline[i] = q; moved = true; break
		if moved: continue
		for step in range(1, 40):
			var q := edge.lerp(centre, float(step) / 50.0)
			if terrain_height(q) >= height + 0.05:
				outline[i] = q; break
	lake.outline = outline
	var grown := Vector2.ZERO
	for q in outline: grown = Vector2(maxf(grown.x, absf(q.x - centre.x)), maxf(grown.y, absf(q.y - centre.y)))
	lake.extent = Vector2(maxf(lake.extent.x, grown.x), maxf(lake.extent.y, grown.y))


static func _register(bounds: Rect2, entry: Dictionary) -> void:
	for z in range(floori(bounds.position.y / 128), floori(bounds.end.y / 128) + 1):
		for x in range(floori(bounds.position.x / 128), floori(bounds.end.x / 128) + 1):
			var key = Vector2i(x, z)
			if not _grid.has(key): _grid[key] = []
			_grid[key].append(entry)
static func watercourses() -> Array:
	_load(); return _data.rivers
static func lakes() -> Array:
	_load(); return _data.lakes
static func triangle_height(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab = Vector2(b.x - a.x, b.z - a.z); var ac = Vector2(c.x - a.x, c.z - a.z)
	var det = ab.cross(ac)
	if absf(det) < 1.0e-06: return -INF
	var q = p - Vector2(a.x, a.z); var u = q.cross(ac) / det; var v = ab.cross(q) / det
	if u < -1.0e-05 or v < -1.0e-05 or u + v > 1.00001: return -INF
	return a.y + (b.y - a.y) * u + (c.y - a.y) * v
static func _at(p: Vector2, h: float) -> Vector3: return Vector3(p.x, h, p.y)
static func section_height(p: Vector2, a: Dictionary, b: Dictionary) -> float:
	var al = _at(a.left, a.height); var ar = _at(a.right, a.height)
	var bl = _at(b.left, b.height); var br = _at(b.right, b.height)
	var ac = _at(a.channel_center, a.height) if a.has("channel_center") else (al + ar) * 0.5
	var bc = _at(b.channel_center, b.height) if b.has("channel_center") else (bl + br) * 0.5
	for triangle in [[al, bl, ac], [ac, bl, bc], [ac, bc, ar], [ar, bc, br]]:
		var h = triangle_height(p, triangle[0], triangle[1], triangle[2])
		if is_finite(h): return h
	return -INF
static func sample(p: Vector2) -> Dictionary:
	_load(); var selected = {}; var highest = -INF
	for entry in _grid.get(Vector2i(floori(p.x / 128), floori(p.y / 128)), []):
		var h = -INF
		if entry.has("lake"):
			if Geometry2D.is_point_in_polygon(p, entry.lake.outline): h = entry.lake.height
		else: h = section_height(p, entry.a, entry.b)
		if h > highest: highest = h; selected = {"kind": entry.kind, "height": h}
	return selected
static func liquid_at(p: Vector2) -> Dictionary:
	var result = sample(p)


	if not result.is_empty() and terrain_height(p) >= float(result.height) - 0.04: return {}
	return result
static func terrain_height(p: Vector2) -> float:


	var at = (p / 3).floor() * 3; var q = (p - at) / 3
	var fixed = load("res://scripts/fixed_world.gd")
	var a = fixed.height_at(at); var b = fixed.height_at(at + Vector2(3, 0)); var c = fixed.height_at(at + Vector2(0, 3))
	if q.x + q.y <= 1: return a + (b - a) * q.x + (c - a) * q.y
	var d = fixed.height_at(at + Vector2.ONE * 3)
	return d + (c - d) * (1 - q.x) + (b - d) * (1 - q.y)
static func river_mesh(river: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array(); var uv := PackedVector2Array(); var colors := PackedColorArray(); var ids := PackedInt32Array()
	var sections: Array = river.sections
	for row in sections:
		for p in [row.left, row.get("channel_center", (row.left + row.right) * 0.5), row.right]:
			verts.append(_at(p, row.height)); uv.append(Vector2(float((verts.size() - 1) % 3) * 0.5, row.distance)); colors.append(Color(1, 1, 1, 1 if verts.size() % 3 != 2 else 0))
	for i in range(sections.size() - 1):
		var n = i * 3
		for col in range(2): ids.append_array(PackedInt32Array([n + col, n + col + 3, n + col + 1, n + col + 1, n + col + 3, n + col + 4]))
	var outline := PackedInt32Array()
	for i in range(sections.size()): outline.append(i * 3)
	outline.append((sections.size() - 1) * 3 + 1)
	for i in range(sections.size() - 1, -1, -1): outline.append(i * 3 + 2)
	outline.append(1)
	return _volume(verts, uv, colors, ids, outline, 0.0 if river.get("terrain_fitted", false) else float(river.get("depth", 3.4)))
static func lake_mesh(lake: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array([_at(lake.pos, lake.height)]); var uv := PackedVector2Array([Vector2(0.5, 0)]); var colors := PackedColorArray([Color(1, 1, 1, 0)]); var ids := PackedInt32Array(); var outline := PackedInt32Array()
	for i in range(lake.outline.size()):
		var p: Vector2 = lake.outline[i]
		verts.append(_at(p, lake.height)); uv.append(Vector2(0.5 + (p.x - lake.pos.x) / (lake.extent.x * 2), (p.y - lake.pos.y))); colors.append(Color.WHITE); outline.append(i + 1)
		if i > 0: ids.append_array(PackedInt32Array([0, i + 1, i]))
	ids.append_array(PackedInt32Array([0, 1, lake.outline.size()]))
	return _volume(verts, uv, colors, ids, outline, float(lake.get("depth", 3.4)))
static func _volume(verts: PackedVector3Array, uv: PackedVector2Array, colors: PackedColorArray, ids: PackedInt32Array, outline: PackedInt32Array, depth: float) -> ArrayMesh:
	var count = verts.size(); var top_ids = ids.duplicate()
	if depth > 0.0:
		for i in range(count): verts.append(verts[i] - Vector3.UP * depth); uv.append(uv[i]); colors.append(Color(0.42, 0.42, 0.42, 0))
		for i in range(0, top_ids.size(), 3): ids.append_array(PackedInt32Array([top_ids[i] + count, top_ids[i + 2] + count, top_ids[i + 1] + count]))
	var area = 0.0
	for i in range(outline.size()):
		var a = verts[outline[i]]; var b = verts[outline[(i + 1) % outline.size()]]; area += a.x * b.z - b.x * a.z
	if area < 0: outline.reverse()
	for i in range(outline.size()):
		if depth <= 0.0: break
		var a = outline[i]; var b = outline[(i + 1) % outline.size()]
		ids.append_array(PackedInt32Array([a, b, a + count, b, b + count, a + count]))
	var normals := PackedVector3Array(); normals.resize(verts.size())
	for i in range(0, ids.size(), 3):
		var a = ids[i]; var b = ids[i + 1]; var c = ids[i + 2]; var n = (verts[b] - verts[a]).cross(verts[c] - verts[a]).normalized()
		normals[a] += n; normals[b] += n; normals[c] += n
	for i in range(normals.size()): normals[i] = normals[i].normalized()


	for i in range(0, ids.size(), 3):
		var swap = ids[i + 1]; ids[i + 1] = ids[i + 2]; ids[i + 2] = swap
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = ids
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh
