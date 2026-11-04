extends RefCounted

const PATH = "res://assets/world/fixed/"
static var _map: Dictionary = {}
static var _heights := PackedByteArray()
static var _sectors: Dictionary = {}
static var _order: Array = []
static var _cliffs: Dictionary = {}
static var _feature_grid: Dictionary = {}
static var _road_grid: Dictionary = {}
static var _gate_grid: Dictionary = {}
static func _load() -> void:
	if not _map.is_empty(): return
	_map = FileAccess.open(PATH + "map.bin", FileAccess.READ).get_var()
	_heights = FileAccess.get_file_as_bytes(PATH + "heightfield.bin")
	assert(_heights.size() == int(_map.width) * int(_map.height) * 2, "Incomplete fixed world height field")
	for c in _map.cliffs:
		_cliffs[c.id] = c
		for z in range(floori((c.pos.y - 140) / 128), ceili((c.pos.y + 140) / 128) + 1):
			for x in range(floori((c.pos.x - 140) / 128), ceili((c.pos.x + 140) / 128) + 1):
				var key = Vector2i(x, z)
				if not _feature_grid.has(key): _feature_grid[key] = []
				_feature_grid[key].append(c)
	for r in _map.roads:
		var bounds: Rect2 = r.bounds.grow(4)
		for z in range(floori(bounds.position.y / 128), floori(bounds.end.y / 128) + 1):
			for x in range(floori(bounds.position.x / 128), floori(bounds.end.x / 128) + 1):
				var key = Vector2i(x, z)
				if not _road_grid.has(key): _road_grid[key] = []
				_road_grid[key].append(r)
	for p in _map.gates.values():
		for z in range(floori((p.y - 45) / 128), floori((p.y + 45) / 128) + 1):
			for x in range(floori((p.x - 45) / 128), floori((p.x + 45) / 128) + 1):
				var key = Vector2i(x, z)
				if not _gate_grid.has(key): _gate_grid[key] = []
				_gate_grid[key].append(p)
static func metadata() -> Dictionary:
	_load(); return _map.duplicate(true)
static func town_plots(id: String) -> Array:
	_load(); return _map.town_plots.get(id, []).duplicate(true)
static func deep_plan(id: String) -> Dictionary:
	_load(); return _map.deep_plans.get(id, {}).duplicate(true)
static func gates() -> Dictionary:
	_load(); return _map.gates.duplicate(true)
static func spawn() -> Vector2:
	_load(); return _map.spawn
static func wizard_anchor() -> Vector2:
	_load(); return _map.wizard_tower
static func service_points(kind: String) -> Dictionary:
	_load(); return _map.get(kind, {}).duplicate(true)
static func height_at(p: Vector2) -> float:
	_load(); var q = (p - _map.origin) / 3.0
	q.x = clampf(q.x, 0, int(_map.width) - 1.001); q.y = clampf(q.y, 0, int(_map.height) - 1.001)
	var x = floori(q.x); var z = floori(q.y); var u = q.x - x; var v = q.y - z; var index = (z * int(_map.width) + x) * 2
	var a = _heights.decode_u16(index); var b = _heights.decode_u16(index + 2)
	var c = _heights.decode_u16(index + int(_map.width) * 2); var d = _heights.decode_u16(index + int(_map.width) * 2 + 2)
	var h = lerpf(lerpf(a, b, u), lerpf(c, d, u), v)
	return -128.0 + h / 64.0
static func bounds() -> Rect2:
	_load(); return Rect2(_map.origin, Vector2(int(_map.width) - 1, int(_map.height) - 1) * 3)
static func contains(p: Vector2) -> bool:
	_load(); return Rect2(_map.origin, Vector2(int(_map.width) - 1, int(_map.height) - 1) * 3).has_point(p)
static func chunk_extent() -> Rect2i:
	_load()
	return Rect2i(Vector2i((_map.origin / 48).floor()), Vector2i(ceili((int(_map.width) - 1) * 3.0 / 48), ceili((int(_map.height) - 1) * 3.0 / 48)) + Vector2i.ONE)
static func chunk(key: Vector2i) -> Dictionary:
	return _chunk_record(key).duplicate(true)
static func _chunk_record(key: Vector2i) -> Dictionary:
	_load(); var sector = Vector2i(floori(key.x / 32.0), floori(key.y / 32.0))
	if not _sectors.has(sector):
		var path = PATH + "sector_%d_%d.bin" % [sector.x, sector.y]
		if not FileAccess.file_exists(path): return {}
		if _order.size() >= 4: _sectors.erase(_order.pop_front())
		_sectors[sector] = FileAccess.open(path, FileAccess.READ).get_var(); _order.append(sector)
	return _sectors[sector].get(key, {})
static func cover_tile(index: int) -> Array:
	_load(); return _map.ground_tiles[index]
static func cliff(id: String) -> Dictionary:
	_load(); return _cliffs.get(id, {}).duplicate(true)
static func cliff_at(p: Vector2) -> Dictionary:
	_load()
	for c in _feature_grid.get(Vector2i(floori(p.x / 128), floori(p.y / 128)), []):
		if c.pos.distance_to(p) < 1: return c.duplicate(true)
	return {}
static func cliff_paint(p: Vector2) -> float:
	_load(); var strength = 0.0
	for c in _feature_grid.get(Vector2i(floori(p.x / 128), floori(p.y / 128)), []):
		var q = (p - c.pos).rotated(c.yaw); var back = -q.y
		var mask = (1 - smoothstep(35, 57, absf(q.x))) * smoothstep(2, 9, back) * (1 - smoothstep(55, 88, back))
		mask = maxf(mask, (1 - smoothstep(3.5, 7, absf(q.x))) * smoothstep(-2, 1, back) * (1 - smoothstep(7, 11, back)))
		strength = maxf(strength, mask)
	return strength
static func region_at(p: Vector2) -> int:
	_load(); var nearest = INF; var chosen = 9
	for r in _map.regions:
		if Geometry2D.is_point_in_polygon(p, r.polygon): return r.id
		var center = Vector2.ZERO
		for v in r.polygon: center += v
		center /= r.polygon.size(); var d = center.distance_squared_to(p)
		if d < nearest: nearest = d; chosen = r.id
	return chosen
static func path_distance(p: Vector2) -> float:
	_load(); var best = INF
	for r in _road_grid.get(Vector2i(floori(p.x / 128), floori(p.y / 128)), []): best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, r.a, r.b)))
	return best
static func liquid_at(p: Vector2) -> bool:
	return not load("res://scripts/water_profile.gd").liquid_at(p).is_empty()
static func reserved(p: Vector2, padding: float = 0) -> bool:
	_load()
	for s in _map.sites:
		var q = (p - s.pos).abs()
		if maxf(q.x, q.y) < s.clearance + padding: return true
	for c in _feature_grid.get(Vector2i(floori(p.x / 128), floori(p.y / 128)), []):
		var q = (p - c.pos).rotated(c.yaw)
		if absf(q.x) < c.width + padding and q.y > -c.depth - padding and q.y < 12 + padding: return true
	for at in _gate_grid.get(Vector2i(floori(p.x / 128), floori(p.y / 128)), []):
		if p.distance_to(at) < 14 + padding: return true
	for group in _map.sky:
		if p.distance_to(group.lower_pos) < 12 + padding: return true
	var castle = (p - _map.nodes.blackthornkeep)
	return (absf(castle.x) < 85 + padding and absf(castle.y) < 83 + padding) or (absf(castle.x) < 16 + padding and castle.y > 30 and castle.y < 170 + padding)



static func cover_count(key: Vector2i, quality: int) -> int:
	var record = _chunk_record(key)
	if not record.has("cover_patches"): return [22, 74, 96][quality]
	var count = 0
	for encoded in record.cover_patches:
		if posmod(int(encoded), 128) < [22, 74, 96][quality]: count += 1
	return count
static func cover_record(key: Vector2i, index: int, tile: int = 0) -> Dictionary:
	var saved = _chunk_record(key)
	if not saved.has("cover_patches"): return cover_tile(tile)[index]
	var encoded = int(saved.cover_patches[index]); var patch = posmod(encoded, 128); var source_key = Vector2i(encoded / 32768 - 64, posmod(encoded / 128, 256) - 96)
	var original: Dictionary = cover_tile(posmod(source_key.x * 7 + source_key.y * 11, 16))[patch]
	var result = original.duplicate(true); var origin = Vector2(source_key) * 48; var offset = Vector2(key) * 48
	var conversion = load("res://scripts/compact_geography.gd")
	result.center = conversion.point(origin + original.center) - offset
	var stable_ids = []
	for kind in ["blades", "decor"]:
		for row in result[kind]:
			var old = Vector2(row[0], row[1]); var p = conversion.point(origin + old) - offset
			if kind == "decor": stable_ids.append("ground_stone_%d_%d_%d_%d" % [source_key.x, source_key.y, roundi(old.x * 256), roundi(old.y * 256)])
			row[0] = p.x; row[1] = p.y
	result.pebble_ids = stable_ids
	return result
