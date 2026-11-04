extends RefCounted

const STEP := 2.0
const ORIGINS = {"rootglow": Vector3(900, -220, -1800), "cedarwatch": Vector3(1100, -220, -1800)}
const GATES = {"rootglow": Vector2(-140, 46), "cedarwatch": Vector2(66, -42)}
const NAMES = {"rootglow": "Rootglow Hollow", "cedarwatch": "Cedarwatch Redoubt"}
static var masks: Dictionary = {}

static func cells(id: String) -> Dictionary:
	if masks.has(id): return masks[id]
	var result: Dictionary = {}
	if not ORIGINS.has(id): return result
	var lobes = [[Vector2(0, 2), Vector2(6, 6)], [Vector2(0, -9), Vector2(7, 6)],
		[Vector2(-13, -18), Vector2(7, 8)], [Vector2(-14, -29), Vector2(7, 8)],
		[Vector2(0, -27), Vector2(8, 9)], [Vector2(14, -27), Vector2(7, 8)], [Vector2(13, -10), Vector2(5, 7)]]
	var links = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 1]]
	for z in range(-29, 6):
		for x in range(-13, 25):
			var p = (Vector2(x, z) + Vector2.ONE * 0.5) * STEP
			var inside := false
			if id == "rootglow":
				for lobe in lobes:
					if ((p - lobe[0]) / lobe[1]).length_squared() < 1.0: inside = true; break
				if not inside:
					for link in links:
						if p.distance_to(Geometry2D.get_closest_point_to_segment(p, lobes[link[0]][0], lobes[link[1]][0])) < 2.8: inside = true; break
			else:
				inside = Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(0, 10), Vector2(-24, -28), Vector2(24, -28)]))
				inside = inside or Rect2(-11, -52, 22, 25).has_point(p) or Rect2(8, -46, 28, 6).has_point(p) or Rect2(28, -53, 18, 18).has_point(p)
			if inside: result[Vector2i(x, z)] = true
	masks[id] = result
	return result

static func floor_height(id: String, p: Vector2) -> float:
	if id == "rootglow": return -1.9 * exp(-p.distance_squared_to(Vector2(0, -27)) / 85.0)
	return -3.0 * smoothstep(14.0, 28.0, p.x)

static func ceiling_height(id: String, p: Vector2) -> float:
	if id == "rootglow": return 1.95 if p.x > 7 and p.y > -17 else 4.7 + 0.25 * sin(p.x * 0.2 + p.y * 0.15)
	return 8.0 if p.y > -28 else 4.5

static func point(id: String, p: Vector2) -> Vector3:
	return ORIGINS[id] + Vector3(p.x, floor_height(id, p) + 0.25, p.y)

static func interior_at(p: Vector3) -> String:
	for id in ORIGINS:
		var local: Vector3 = p - ORIGINS[id]; var at = Vector2(local.x, local.z)
		if not cells(id).has(Vector2i(floori(at.x / STEP), floori(at.y / STEP))): continue
		var floor_y = floor_height(id, at)
		if local.y >= floor_y - 1.2 and local.y <= floor_y + ceiling_height(id, at) + 1.2: return id
	return ""

static func rooms(id: String) -> Array:
	if id == "rootglow": return [{"name": "Root mouth", "p": Vector2(0, 3)}, {"name": "Root fork", "p": Vector2(0, -9)},
		{"name": "Fern passage", "p": Vector2(-14, -24)}, {"name": "Fungal pocket", "p": Vector2(0, -27)},
		{"name": "East root loop", "p": Vector2(14, -27)}, {"name": "Low return", "p": Vector2(13, -10)}]
	return [{"name": "Triangular court", "p": Vector2(0, -12)}, {"name": "Barracks", "p": Vector2(0, -39)},
		{"name": "Armory ramp", "p": Vector2(21, -43)}, {"name": "Lower armory", "p": Vector2(36, -43)},
		{"name": "Postern", "p": Vector2(14, -20)}]

static func gate_point(atlas, id: String) -> Vector3:
	var p: Vector2 = atlas.nodes.bellcrown + GATES[id] + Vector2(0, 4)
	return Vector3(p.x, atlas.height_at(p) + 0.25, p.y)

static func destinations(atlas) -> Array:
	var market: Vector2 = atlas.nodes.bellcrown + Vector2(0, 14)
	var result: Array = [{"id": "timbermarket", "name": "Bellcrown / Timbermarket", "kind": "district", "region": 9, "pos": market, "point": Vector3(market.x, atlas.height_at(market) + 0.25, market.y)}]
	for id in ORIGINS:
		var gate = gate_point(atlas, id)
		result.append({"id": id + "_entrance", "name": NAMES[id] + " / approach", "kind": "entrance", "region": 9, "pos": Vector2(gate.x, gate.z), "point": gate})
		var arrival = point(id, Vector2(0, 3))
		result.append({"id": id + "_interior", "name": NAMES[id] + " / inside", "kind": "interior", "region": 9, "pos": Vector2(gate.x, gate.z), "point": arrival})
	for entry in [{"id": "rootglow_pocket", "space": "rootglow", "p": Vector2(0, -27), "name": "Rootglow / fungal pocket"},
		{"id": "cedarwatch_armory", "space": "cedarwatch", "p": Vector2(36, -43), "name": "Cedarwatch / lower armory"}]:
		var p: Vector3 = point(entry.space, entry.p)
		var gate = gate_point(atlas, entry.space)
		result.append({"id": entry.id, "name": entry.name, "kind": "interior", "region": 9, "pos": Vector2(gate.x, gate.z), "point": p})
	return result
