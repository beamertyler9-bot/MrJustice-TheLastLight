extends RefCounted

const SCALE := 6.0
const ORIGIN := Vector2(307, 536)
const FIRST_REGION := 9
const MAX_DISTANCE := 16000.0
const COLORS = ["#46734d", "#79934d", "#9b9e62", "#d0a368", "#594b49", "#514b5b", "#829fa6"]
var regions: Array = []
var data: Dictionary
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

func _init(_legacy_seed: int = 64127) -> void:

	var fixed = preload("res://scripts/fixed_world.gd")
	var map = fixed.metadata()
	seed_value = 64127
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/atlas.json"))
	regions = map.regions; _sites = map.sites; _roads = map.roads
	_waters = preload("res://scripts/water_profile.gd").watercourses()
	_lakes = preload("res://scripts/water_profile.gd").lakes(); nodes = map.nodes; _sky_groups = map.sky
	_castle_height = fixed.height_at(nodes.blackthornkeep)

func point(p: Vector2) -> Vector2: return preload("res://scripts/compact_geography.gd").point((p - ORIGIN) * (SCALE / 0.75))
func map_point(p: Vector2) -> Vector2: return preload("res://scripts/compact_geography.gd").source(p) / (SCALE / 0.75) + ORIGIN
func sites() -> Array: return _sites
func watercourses() -> Array: return _waters
func lakes() -> Array: return _lakes
func spawn() -> Vector2: return nodes.brindlewick
func roads() -> Array: return _roads

func region_at(p: Vector2) -> int:
	for region in regions:
		if Geometry2D.is_point_in_polygon(p, region.polygon): return region.id
	var nearest = INF; var selected = FIRST_REGION
	for region in regions:
		var center := Vector2.ZERO
		for v in region.polygon: center += v
		center /= region.polygon.size()
		var d = p.distance_squared_to(center)
		if d < nearest: nearest = d; selected = region.id
	return selected

func _bump(p: Vector2, center: Vector2, extent: Vector2) -> float:
	var q = (p - center) / extent
	return exp(-q.length_squared() * 2.8)

func _raw_height(p: Vector2) -> float:
	return preload("res://scripts/fixed_world.gd").height_at(p)

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
	return preload("res://scripts/fixed_world.gd").height_at(p)

func liquid_at(p: Vector2) -> Dictionary:
	return preload("res://scripts/water_profile.gd").liquid_at(p)

func path_distance(p: Vector2) -> float:
	var best = INF
	for road in _near(p).roads: best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, road.a, road.b)))
	for site in _near(p).sites:
		var local: Vector2 = p - site.pos
		if maxf(absf(local.x), absf(local.y)) < site.clearance: best = minf(best, minf(absf(local.x), absf(local.y)))
	return best

func reserved(p: Vector2, padding: float = 0) -> bool:
	if preload("res://scripts/fixed_world.gd").reserved(p, padding): return true
	var castle: Vector2 = (p - nodes.blackthornkeep).abs()
	if castle.x < 55 + padding and castle.y < 48 + padding: return true
	for group in island_groups():
		if p.distance_to(group.lower_pos) < 9 + padding: return true
	for site in _near(p).sites:
		var d: Vector2 = (p - site.pos).abs()
		if maxf(d.x, d.y) < site.clearance + padding: return true
	return false

func destinations() -> Array:
	if not _destinations.is_empty(): return _destinations
	var result = _sites.duplicate(true)
	for entry in [{"id": "fizzpeak", "name": "Fizzpeak summit", "pos": point(Vector2(280, 722)), "kind": "mountain"}, {"id": "blackthornkeep", "name": "Blackthorn Keep", "pos": nodes.blackthornkeep, "kind": "castle"}, {"id": "ashwest", "name": "Ashfall wilderness crossing", "pos": nodes.ashwest, "kind": "trail"}]: result.append(entry)
	for group in island_groups():
		result.append({"id": "sky_access_" + str(group.region), "name": "Free sky lift / " + str(regions[group.region - 9].name), "pos": group.lower_pos, "kind": "lift", "region": group.region})
		for i in range(group.names.size()):
			result.append({"id": "sky_%s_%s" % [group.region, i], "name": str(group.names[i]), "pos": group.pos + Vector2(i * 24, 0), "height": island_floor(group) + 0.25, "region": group.region, "kind": "island"})
	_destinations = result
	return result

func island_floor(group: Dictionary) -> float:
	var h = height_at(group.pos) + 40
	for i in range(group.names.size()): h = maxf(h, height_at(group.pos + Vector2(i * 24, 0)) + 24)
	return h

func connected() -> bool:
	var graph = {}
	for id in nodes: graph[id] = []
	for route in data.routes: graph[route.a].append(route.b); graph[route.b].append(route.a)
	var seen = {"brindlewick": true}; var pending = ["brindlewick"]
	while not pending.is_empty():
		for next in graph[pending.pop_back()]:
			if not seen.has(next): seen[next] = true; pending.append(next)
	return seen.size() == nodes.size()

func island_groups() -> Array:
	if not _sky_groups.is_empty(): return _sky_groups
	var centers = [Vector2(545, 235), Vector2(480, 725), Vector2(745, 465), Vector2(1495, 655), Vector2(1130, 337), Vector2(725, 260), Vector2(1115, 460)]
	var groups = []
	for i in range(regions.size()):
		var p = point(centers[i]); var lower = p + Vector2(0, 20)
		groups.append({"region": FIRST_REGION + i, "pos": p, "lower_pos": lower, "base_height": _raw_height(lower), "names": regions[i].islands})
	_sky_groups = groups
	return _sky_groups
