extends RefCounted




const SCALE := 8.0
const ORIGIN := Vector2(307, 536)
const FIRST_REGION := 9
const MAX_DISTANCE := 16000.0
const COLORS = ["#46734d", "#79934d", "#9b9e62", "#d0a368", "#594b49", "#514b5b", "#829fa6"]
var regions: Array = []
var data: Dictionary
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var _sites: Array = []
var _roads: Array = []
var _waters: Array = []
var _lakes: Array = []
var _features: Dictionary = {}
var nodes: Dictionary = {}
var _destinations: Array = []
var _sky_groups: Array = []
var _castle_height := 0.0
var seed_value: int

func _init(seed: int = 64127) -> void:
	seed_value = seed
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/atlas.json"))
	noise.seed = seed; noise.frequency = 0.0013; noise.fractal_octaves = 3
	detail.seed = seed + 937; detail.frequency = 0.017; detail.fractal_octaves = 2
	for i in range(data.regions.size()):
		var region: Dictionary = data.regions[i].duplicate(true)
		region.id = FIRST_REGION + i
		var polygon := PackedVector2Array()
		for p in region.polygon: polygon.append(point(Vector2(p[0], p[1])))
		region.polygon = polygon; regions.append(region)
	for raw in data.capitals + data.towns:
		var p = point(Vector2(raw.point[0], raw.point[1])); nodes[raw.id] = p
		var index = 0
		for i in range(regions.size()):
			if regions[i].key == raw.region: index = i; break
		var city = raw in data.capitals
		_sites.append({"id": str(raw.id), "name": str(raw.name), "pos": p, "kind": "city" if city else "town", "region": FIRST_REGION + index, "clearance": 76.0 if city else 58.0, "district": ["crescent", "crescent", "avenues", "courtyards", "avenues", "avenues", "crescent"][index], "height": _raw_height(p)})
		_sites.back().wall_color = ["#bfbb9b", "#cfb68b", "#c5c6a8", "#ddbd87", "#6b605c", "#635b6e", "#b7b7d0"][index]
		_sites.back().roof_color = ["#795442", "#78503b", "#6a7968", "#ab7950", "#7e6860", "#484050", "#6e8e9b"][index]
	for id in data.route_landmarks:
		var p: Array = data.route_landmarks[id]; nodes[id] = point(Vector2(p[0], p[1]))
	for route in data.routes:
		var points: Array = [nodes[route.a]]
		for p in route.via: points.append(point(Vector2(p[0], p[1])))
		points.append(nodes[route.b])
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]; var b: Vector2 = points[i + 1]
			_roads.append({"a": a, "b": b, "ah": _raw_height(a), "bh": _raw_height(b), "kind": route.kind, "name": route.name, "bounds": Rect2(a, Vector2.ZERO).expand(b).grow(13)})

	var peak = point(Vector2(280, 722)); var previous = peak + Vector2(610, 0)
	for i in range(1, 161):
		var t = float(i) / 160
		var next = peak + Vector2.from_angle(t * TAU * 3.5) * lerpf(610, 12, t)
		_roads.append({"a": previous, "b": next, "ah": _raw_height(previous), "bh": _raw_height(next), "kind": "trail", "name": "Fizzpeak summit trail", "bounds": Rect2(previous, Vector2.ZERO).expand(next).grow(13)})
		previous = next
	for raw in data.watercourses:
		var points: Array = []; var heights: Array = []; var last = INF
		for p in raw.points:
			var at = point(Vector2(p[0], p[1])); points.append(at)
			last = minf(_raw_height(at) - 0.25, last - 0.12); heights.append(last)
		_waters.append({"kind": raw.kind, "width": float(raw.width), "points": points, "heights": heights})
	for record in [["water", 365, 450, 62, 34], ["water", 960, 920, 49, 25], ["water", 1455, 945, 35, 20], ["water", 1000, 590, 70, 45], ["cola", 380, 1007, 50, 22], ["cola", 280, 722, 2.7, 2.7]]:
		var at = point(Vector2(record[1], record[2])); var h = _raw_height(at) - 0.3
		for water in _waters:
			if water.kind != record[0]: continue
			for i in range(water.points.size()):
				if at.distance_to(water.points[i]) < 2: h = water.heights[i]
		_lakes.append({"kind": record[0], "pos": at, "extent": Vector2(record[3], record[4]) * SCALE, "height": h})
	_castle_height = _raw_height(nodes.blackthornkeep)

func point(p: Vector2) -> Vector2: return (p - ORIGIN) * SCALE
func map_point(p: Vector2) -> Vector2: return p / SCALE + ORIGIN

func _bump(p: Vector2, center: Vector2, extent: Vector2) -> float:
	var q = (p - center) / extent
	return exp(-q.length_squared() * 2.8)

func _raw_height(p: Vector2) -> float:
	var q = map_point(p)
	var h = 38 + noise.get_noise_2d(p.x, p.y) * 17 + detail.get_noise_2d(p.x, p.y) * 1.2
	var plain = _bump(q, Vector2(760, 760), Vector2(230, 340))
	h = lerpf(h, 30 + noise.get_noise_2d(p.x * 0.4, p.y * 0.4) * 3, plain)
	for peak in [Vector2(180, 280), Vector2(320, 260), Vector2(500, 270), Vector2(585, 335)]:
		h += _bump(q, peak, Vector2(100, 95)) * 240
	h += _bump(q, Vector2(280, 722), Vector2(95, 95)) * 790
	var volcano = _bump(q, Vector2(1340, 310), Vector2(135, 155))
	h += volcano * 610 - _bump(q, Vector2(1340, 298), Vector2(24, 30)) * 140
	h += _bump(q, Vector2(825, 287), Vector2(85, 90)) * 125
	var desert = _bump(q, Vector2(1390, 820), Vector2(290, 270))
	h += desert * (sin(p.x * 0.006 + p.y * 0.002) * 19 + sin(p.x * 0.013 - p.y * 0.005) * 5)
	var rim = ((q - Vector2(1030, 590)) / Vector2(150, 170)).length()
	h += exp(-pow((rim - 0.85) * 3, 2)) * 37 - _bump(q, Vector2(1030, 590), Vector2(115, 130)) * 14
	return h

func _near(p: Vector2) -> Dictionary:
	var key = Vector2i(floori(p.x / 128), floori(p.y / 128))
	if _features.has(key): return _features[key]
	var bounds = Rect2(Vector2(key) * 128, Vector2.ONE * 128)
	var result = {"roads": [], "sites": [], "water": []}
	for road in _roads:
		if bounds.intersects(road.bounds): result.roads.append(road)
	for site in _sites:
		if bounds.intersects(Rect2(site.pos - Vector2.ONE * (site.clearance + 22), Vector2.ONE * (site.clearance + 22) * 2)): result.sites.append(site)
	for water in _waters:
		for i in range(water.points.size() - 1):
			var a: Vector2 = water.points[i]; var b: Vector2 = water.points[i + 1]
			if bounds.intersects(Rect2(a, Vector2.ZERO).expand(b).grow(water.width + 12)):
				result.water.append({"a": a, "b": b, "ah": water.heights[i], "bh": water.heights[i + 1], "width": water.width, "kind": water.kind})
	if _features.size() > 1024: _features.clear()
	_features[key] = result; return result

func height_at(p: Vector2) -> float:
	var h = _raw_height(p); var features = _near(p)
	for lake in _lakes:
		var radius = ((p - lake.pos) / lake.extent).length()
		if radius < 1.15: h = lerpf(h, lake.height - 2.4, 1 - smoothstep(0.82, 1.15, radius))
	for water in features.water:
		var at = Geometry2D.get_closest_point_to_segment(p, water.a, water.b)
		var t = water.a.distance_to(at) / maxf(0.01, water.a.distance_to(water.b))
		var d = p.distance_to(at)
		h = lerpf(h, lerpf(water.ah, water.bh, t) - 2.4, 1 - smoothstep(water.width * 0.4, water.width + 9, d))
	for road in features.roads:
		var at = Geometry2D.get_closest_point_to_segment(p, road.a, road.b)
		var t = road.a.distance_to(at) / maxf(0.01, road.a.distance_to(road.b))
		var d = p.distance_to(at)
		if d < 11:
			var target = lerpf(road.ah, road.bh, t) + 0.12
			h = lerpf(h, target, 1 - smoothstep(2.8, 11, d))

	for site in features.sites:
		var delta = (p - site.pos).abs(); var outside = maxf(delta.x, delta.y)
		h = lerpf(h, site.height, 1 - smoothstep(site.clearance, site.clearance + 20, outside))
	var castle: Vector2 = nodes.blackthornkeep
	h = lerpf(h, _castle_height, 1 - smoothstep(48, 80, p.distance_to(castle)))
	for group in island_groups(): h = lerpf(h, group.base_height, 1 - smoothstep(7, 12, p.distance_to(group.lower_pos)))
	return h

func island_groups() -> Array:
	if not _sky_groups.is_empty(): return _sky_groups
	var centers = [Vector2(545, 235), Vector2(480, 725), Vector2(745, 465), Vector2(1495, 655), Vector2(1130, 337), Vector2(725, 260), Vector2(1115, 460)]
	var groups = []
	for i in range(regions.size()):
		var p = point(centers[i]); var lower = p + Vector2(0, 20)
		groups.append({"region": FIRST_REGION + i, "pos": p, "lower_pos": lower, "base_height": _raw_height(lower), "names": regions[i].islands})
	_sky_groups = groups
	return _sky_groups
