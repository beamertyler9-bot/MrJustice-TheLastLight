extends RefCounted

const STEP := 2.0
const M = preload("res://scripts/mosswake_layouts.gd")
static var data: Dictionary = {}
static var plans: Dictionary = {}
static var masks: Dictionary = {}
static var gates: Dictionary = {}
static var records: Dictionary = {}
static var navigation: Dictionary = {}
static var interior_grid: Dictionary = {}
static var origins: Dictionary = {}
static var gate_grid: Dictionary = {}

static func _load() -> void:
	if not data.is_empty(): return
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/expansion.json"))
	for record in data.sites:
		record.region = int(record.region)
		records[record.id] = record
		var raw_origin: Array = record.origin; var o = Vector3(raw_origin[0], raw_origin[1], raw_origin[2]); origins[record.id] = o
		if not record.has("alias"):
			for z in range(floori((o.z - 155) / 128), floori((o.z + 35) / 128) + 1):
				for x in range(floori((o.x - 108) / 128), floori((o.x + 108) / 128) + 1):
					var key = Vector2i(x, z)
					if not interior_grid.has(key): interior_grid[key] = []
					interior_grid[key].append(record)
		var rooms: Array = []
		for raw in record.get("rooms", []):
			var room: Dictionary = raw.duplicate(true)
			room.p = Vector2(raw.p[0], raw.p[1]); room.size = Vector2(raw.size[0], raw.size[1]); rooms.append(room)
		plans[record.id] = {"rooms": rooms, "links": record.get("links", []), "levels": int(record.get("levels", 1)), "castle": bool(record.get("castle", false))}

static func catalog() -> Array:
	_load(); return data.sites
static func site(id: String) -> Dictionary:
	_load(); return records.get(id, {})
static func layout(id: String) -> Dictionary:
	_load(); return plans.get(id, {})
static func origin(id: String) -> Vector3:
	_load(); return origins[id]

static func cells(id: String) -> Dictionary:
	if masks.has(id): return masks[id]
	var plan = layout(id); var result = {}
	if bool(plan.castle):
		# Blackthorn Keep: the solid main block and stair tower (its walls come from castle_layout.gd).
		masks[id] = load("res://scripts/castle_layout.gd").cells()
		return masks[id]
	for room in plan.rooms:
		if room.level != 0: continue
		var half: Vector2 = room.size * 0.5
		for z in range(floori((room.p.y - half.y) / STEP), ceili((room.p.y + half.y) / STEP)):
			for x in range(floori((room.p.x - half.x) / STEP), ceili((room.p.x + half.x) / STEP)):
				var p = (Vector2(x, z) + Vector2.ONE * 0.5) * STEP; var q = (p - room.p) / half
				if room.shape == "ellipse" and q.length_squared() > 1: continue
				if room.shape == "hex" and absf(q.x) + absf(q.y) * 0.5 > 1: continue
				result[Vector2i(x, z)] = true
	for edge in plan.links:
		var a: Dictionary = plan.rooms[int(edge[0])]; var b: Dictionary = plan.rooms[int(edge[1])]
		if a.level != 0 or b.level != 0: continue
		var radius := 3.2 if site(id).kind == "cave" else 2.8
		for z in range(floori((minf(a.p.y, b.p.y) - radius) / STEP), ceili((maxf(a.p.y, b.p.y) + radius) / STEP)):
			for x in range(floori((minf(a.p.x, b.p.x) - radius) / STEP), ceili((maxf(a.p.x, b.p.x) + radius) / STEP)):
				var p = (Vector2(x, z) + Vector2.ONE * 0.5) * STEP
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a.p, b.p)) <= radius: result[Vector2i(x, z)] = true
	if bool(plan.castle):


		for z in range(-14, 12):
			for x in range(16, 26): result[Vector2i(x, z)] = true
		for z in range(-5, -1):
			for x in range(13, 26): result[Vector2i(x, z)] = true
	masks[id] = result
	return result

static func floor_height(id: String, p: Vector2, level: int = 0) -> float:
	if bool(layout(id).castle): return (level - 2) * 7.5
	var grade: Array = site(id).get("grade", [0, 0])
	return clampf(p.x * float(grade[0]) + (p.y - 4) * float(grade[1]), -9, 6)
static func ceiling_height(id: String, p: Vector2) -> float:
	if bool(layout(id).castle): return 7.2
	return (5.8 + 0.8 * sin(p.x * 0.09 + p.y * 0.11)) if site(id).kind == "cave" else 7.0
static func point(id: String, p: Vector2, level: int = 0) -> Vector3:
	return origin(id) + Vector3(p.x, floor_height(id, p, level) + 0.24, p.y)
static func entry_point(id: String) -> Vector3:
	return point(id, Vector2(0, 16), 2) if bool(layout(id).castle) else point(id, Vector2(0, 4))

static func interior_at(p: Vector3) -> String:
	if p.y < -418 or p.y > -355: return ""
	_load()
	for record in interior_grid.get(Vector2i(floori(p.x / 128), floori(p.z / 128)), []):
		var local = p - origin(record.id)
		if absf(local.x) > 108 or local.z > 35 or local.z < -155 or local.y < -18 or local.y > 45: continue
		var at = Vector2(local.x, local.z)
		if not cells(record.id).has(Vector2i(floori(at.x / STEP), floori(at.y / STEP))): continue
		if record.get("castle", false):
			if local.y >= -16.2 and local.y <= 37.3: return record.id
		else:
			var floor_y = floor_height(record.id, at)
			if local.y >= floor_y - 1.2 and local.y <= floor_y + ceiling_height(record.id, at) + 1.2: return record.id
	return ""

static func signature(id: String) -> String:


	var variants: Array[String] = []; var keys = cells(id).keys()
	for flip in [-1, 1]:
		for rotation in range(4):
			var transformed: Array[Vector2i] = []; var low = Vector2i(10000, 10000)
			for key in keys:
				var p = Vector2i(key.x * flip, key.y)
				for step in range(rotation): p = Vector2i(-p.y, p.x)
				low = Vector2i(mini(low.x, p.x), mini(low.y, p.y)); transformed.append(p)
			var rows: Array[String] = []
			for p in transformed: rows.append("%d,%d" % [p.x - low.x, p.y - low.y])
			rows.sort(); variants.append(";".join(rows))
	variants.sort(); return variants[0].sha256_text()

static func _make_gates(_atlas) -> Dictionary:
	return preload("res://scripts/fixed_world.gd").gates()
static func gate_yaw(id: String) -> float:
	return float(preload("res://scripts/fixed_world.gd").cliff(id).get("yaw", 0.0))
static func gate_point(atlas, id: String) -> Vector3:
	var key = "mr-justice-world-01"
	_ensure_gates(atlas)
	var p: Vector2 = gates[key][id]
	return Vector3(p.x, atlas.height_at(p) + 0.24, p.y)
static func destinations(atlas) -> Array:
	var key = "mr-justice-world-01"
	if navigation.has(key): return navigation[key]
	var result: Array = []
	for record in catalog():
		if record.get("alias", "") in ["rootglow", "cedarwatch"]: continue
		var gate = gate_point(atlas, record.id)
		result.append({"id": record.id, "name": record.name, "kind": record.kind, "region": record.region, "pos": Vector2(gate.x, gate.z), "point": gate})
		var target = Vector3(240, -23.75, 181) if record.get("alias", "") == "dungeon" else entry_point(record.id)
		result.append({"id": record.id + "_inside", "name": record.name + " / inside", "kind": "interior", "region": record.region, "pos": Vector2(gate.x, gate.z), "point": target})
	var mine: Vector2 = atlas.nodes.brindlewick + Vector2(-65, -75)
	result.append({"id": "legacy_mine", "name": "Embervein Cave & Mine", "kind": "cave", "region": 9, "pos": mine, "point": Vector3(mine.x, atlas.height_at(mine) + 0.24, mine.y)})
	result.append({"id": "legacy_mine_inside", "name": "Embervein / inside", "kind": "interior", "region": 9, "pos": mine, "point": Vector3(-240, -23.75, 181)})
	navigation[key] = result
	return result

static func reserved(atlas, p: Vector2, padding: float = 0) -> bool:
	var key = "mr-justice-world-01"
	_ensure_gates(atlas)
	var cell = Vector2i(floori(p.x / 128), floori(p.y / 128)); var span = maxi(1, ceili((40 + padding) / 128))
	for z in range(cell.y - span, cell.y + span + 1):
		for x in range(cell.x - span, cell.x + span + 1):
			for record in gate_grid[key].get(Vector2i(x, z), []):
				if p.distance_squared_to(record.pos) < pow(float(record.radius) + padding, 2): return true
	return p.distance_to(atlas.nodes.brindlewick + Vector2(-65, -75)) < 8 + padding

static func _ensure_gates(atlas) -> void:
	var key = "mr-justice-world-01"
	if not gates.has(key): gates[key] = _make_gates(atlas)
	if gate_grid.has(key): return
	gate_grid[key] = {}
	for id in gates[key]:
		var at: Vector2 = gates[key][id]
		var cell = Vector2i(floori(at.x / 128), floori(at.y / 128))
		if not gate_grid[key].has(cell): gate_grid[key][cell] = []
		gate_grid[key][cell].append({"pos": at, "radius": 40 if id in ["desert-d02", "desert-d03"] else 12})
