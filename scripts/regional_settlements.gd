extends Node3D
const Merchants = preload("res://scripts/merchants.gd")

const B = preload("res://scripts/build.gd")
const P = preload("res://scripts/locations.gd")
const F = preload("res://scripts/regional_furnishings.gd")
const Occupancy = preload("res://scripts/world_occupancy.gd")
const Dressing = preload("res://scripts/asset_dressing.gd")
const DistrictBatches = preload("res://scripts/district_batches.gd")
const DISTRICTS = {
	9: ["Lakeside Harbor", "Bellward", "Timbermarket", "River Gardens", "Old Stone Quarter", "Cedarhomes"],
	10: ["Cola Quays", "Baker's Row", "Orchard Ward", "Graham Market", "Clockpantry", "Hearthhomes"],
	11: ["Grand Market", "Bellhall", "Windmill Quarter", "Caravan Commons", "Streamgardens", "Meadowhomes"],
	12: ["Shaded Bazaar", "Oasis Gardens", "Windtower Ward", "Caravan Gate", "Sun Courts", "Old Sunspire"],
	15: ["Prism Rotunda", "Gemcutters' Steps", "Chimegarden", "Mirror Quays", "Observatory Ward", "Opalhomes"]}
static var plans: Dictionary = {}
var world
var game
var live: Dictionary = {}
var jobs: Array = []
var active_residents: Dictionary = {}
var clock := 0.0
var viewer := Vector3.ZERO
var proxies: Node3D


const PROXY_LOAD_DISTANCE = 900.0
const PROXY_KEEP_DISTANCE = 1050.0
var proxy_jobs: Array = []
var proxy_live: Dictionary = {}

static func plan(atlas, site: Dictionary) -> Dictionary:
	var key = "%s:%s" % [atlas.seed_value, site.id]
	if plans.has(key): return plans[key]
	var plots = P.city_plots(site, atlas.seed_value).duplicate(true); var districts: Array = []
	for i in range(plots.size()):
		plots[i].index = i; plots[i].legacy = false; plots[i].district = i / 4 if site.kind == "city" else 0
		plots[i].purpose = ["stores", "workshop", "library", "bakery", "home", "home", "inn", "home"][i % 8]
	for i in range(6 if site.kind == "city" else 1):
		var center = Vector2.ZERO; var count = 0
		for plot in plots:
			if plot.district == i: center += plot.p; count += 1
		districts.append({"name": DISTRICTS[int(site.region)][i] if site.kind == "city" else site.name + " / homes", "p": center / maxi(1, count), "index": i})
	var population: Array = []
	var names = ["Ada", "Bram", "Cora", "Della", "Edric", "Fenna", "Galen", "Hesta", "Ivo", "Junia", "Kellan", "Lira", "Milo", "Nessa", "Orin", "Pella", "Quinn", "Rhea", "Soren", "Tamsin", "Una", "Venn", "Willa", "Yarrow"]
	var surnames = ["Bellward", "Cedarhand", "Riverreed", "Mosswell", "Fernlight", "Willowmere", "Honeycrumb", "Cocoavale", "Grahamwood", "Fizzbrook", "Windweaver", "Goldseed", "Reedcrest", "Millward", "Sunthread", "Saffron", "Oasisleaf", "Dunewalker", "Opalbrook", "Gemward", "Chimeleaf", "Prismwell", "Mirrorlake", "Starshard", "Copperstrap"]
	var count = 600 if site.kind == "city" else 64
	for i in range(count):
		var plot: Dictionary = plots[i % plots.size()]
		population.append({"id": "citizen_%s_%03d" % [site.id, i], "name": names[i % names.size()] + " " + surnames[(i / names.size() + int(site.region) * 3) % surnames.size()], "home": i % plots.size(), "district": int(plot.district), "role": plot.get("purpose", "home"), "phase": i % 4})
	var result = {"plots": plots, "districts": districts, "population": population}; plans[key] = result; return result

static func reserved(atlas, p: Vector2, padding: float = 0) -> bool:
	for site in atlas.sites():
		var local = p - site.pos
		if local.length() > 230 + padding: continue
		if site.kind == "town":
			if absf(local.x) > 36 and absf(local.x) < 51 + padding and absf(local.y) < 26 + padding: return true
			continue

		for i in range(6):
			var angle = float(i) * TAU / 6 + PI / 6; var center = Vector2(cos(angle), sin(angle)) * 158
			var q = (local - center).abs()
			if maxf(q.x, q.y) < 45 + padding: return true
			var edge = Vector2(signf(center.x) * 82, 0) if absf(center.x) > absf(center.y) else Vector2(0, signf(center.y) * 82)
			if local.distance_to(Geometry2D.get_closest_point_to_segment(local, Vector2.ZERO, edge)) < 4 + padding or local.distance_to(Geometry2D.get_closest_point_to_segment(local, edge, center)) < 4 + padding: return true
	return false

static func destinations(atlas) -> Array:
	var result: Array = []
	for site in atlas.sites():
		if site.kind != "city": continue
		for district in plan(atlas, site).districts:
			var p: Vector2 = site.pos + district.p
			result.append({"id": "district_%s_%d" % [site.id, district.index], "name": site.name + " / " + district.name, "kind": "district", "region": site.region, "pos": p, "point": Vector3(p.x, atlas.height_at(p) + 0.3, p.y)})
	return result

func setup(owner_world) -> void:
	world = owner_world; name = "RegionalSettlements"
	proxies = Node3D.new(); proxies.name = "MatchedHousingVistas"; add_child(proxies)

func _stream_proxies(point: Vector3, immediate: bool) -> void:
	var wanted = {}; var queued = {}; var at = Vector2(point.x, point.z)
	for job in proxy_jobs: queued[job.id] = true
	for site in world.atlas.sites():
		if site.kind != "city": continue
		for plot in plan(world.atlas, site).plots:
			var id = site.id + "_home_" + str(plot.index)
			var distance = at.distance_to(site.pos + plot.p)
			if distance > (PROXY_KEEP_DISTANCE if proxy_live.has(id) else PROXY_LOAD_DISTANCE): continue
			wanted[id] = true
			if not proxy_live.has(id) and not queued.has(id): proxy_jobs.append({"id": id, "site": site, "plot": plot})
	proxy_jobs = proxy_jobs.filter(func (job): return wanted.has(job.id))
	for id in proxy_live.keys():
		if wanted.has(id): continue
		var n: Node3D = proxy_live[id]; proxies.remove_child(n); n.queue_free(); proxy_live.erase(id)
	if proxy_live.is_empty():
		var renderer = proxies.get_node_or_null("DistrictBatches")
		if renderer: renderer.free()
	if immediate:
		while not proxy_jobs.is_empty(): step_proxy()
	_update_proxies()

func step_proxy() -> void:
	if proxy_jobs.is_empty(): return
	var job = proxy_jobs.pop_front(); var site: Dictionary = job.site; var plot: Dictionary = job.plot
	var p: Vector2 = site.pos + plot.p; var high: float = world.height_at(p.x, p.y)
	for d in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]: high = maxf(high, world.height_at(p.x + d.x, p.y + d.y))
	var n = Node3D.new(); proxies.add_child(n); n.position = Vector3(p.x, high + 0.08, p.y); n.rotation.y = plot.heading
	n.set_meta("site", site.id); n.set_meta("plot_index", plot.index); n.set_meta("plot_id", job.id); n.set_meta("world_plot", p)
	n.set_meta("purpose", plot.purpose)
	load("res://scripts/village_architecture.gd").build(n, plot.w, plot.d, int(site.region), str(job.id), site.wall_color, site.roof_color, false)
	B.batch_static(n)
	for mesh in n.find_children("*", "GeometryInstance3D", true, false): mesh.visibility_range_end = 750; mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy_live[job.id] = n
	# Only the new house needs its visibility decided now; re-checking every distant house
	# after each build made streaming cost grow with the size of the town (40-65 ms hitches).
	if n.is_in_group("housing_representation"):
		n.visible = not has_plot(n.get_meta("site"), n.get_meta("plot_index")) and not _occupied(n.get_meta("world_plot"), 7)
	if proxy_jobs.is_empty():
		_update_proxies()
		DistrictBatches.rebuild(proxies, "housing-vistas", null, true)
func _update_proxies() -> void:
	if proxies == null: return
	for n in proxies.get_children():
		if n.is_in_group("housing_representation"): n.visible = not has_plot(n.get_meta("site"), n.get_meta("plot_index")) and not _occupied(n.get_meta("world_plot"), 7)
func bind_game(context) -> void: game = context
func _process(dt: float) -> void:
	if game == null or game.mode != "play": return
	if not jobs.is_empty(): step()
	if not proxy_jobs.is_empty(): step_proxy()
	clock -= dt
	if clock <= 0: clock = 0.8; _citizens()

func _key(site: Dictionary, district: Dictionary) -> String: return "%s:%d" % [site.id, district.index]
func stream_at(point: Vector3, immediate: bool = false) -> void:
	viewer = point
	var wanted = {}; var outdoors = world.interior_at(point).is_empty(); proxies.visible = outdoors
	if outdoors: _stream_proxies(point, immediate)
	else: proxy_jobs.clear()
	var choices = []
	for site in world.atlas.sites():
		if Vector2(point.x, point.z).distance_to(site.pos) > 220 or not outdoors: continue
		for district in plan(world.atlas, site).districts:
			var ground_point: Vector2 = site.pos + district.p
			var distance = Vector3(ground_point.x, world.height_at(ground_point.x, ground_point.y), ground_point.y).distance_to(point)
			if distance < (128 if live.has(_key(site, district)) else 106): choices.append({"site": site, "district": district, "distance": distance})
	choices.sort_custom(func (a, b): return a.distance < b.distance)
	for choice in choices.slice(0, 3):
		var site: Dictionary = choice.site; var district: Dictionary = choice.district; var key = _key(site, district); wanted[key] = true
		if live.has(key):
			_queue_missing(live[key], site, district)
			continue
		var n = Node3D.new(); n.name = key.replace(":", "_"); n.position = Vector3(site.pos.x, 0, site.pos.y); add_child(n)
		n.set_meta("site", site.id); n.set_meta("district", district.index); n.set_meta("built_plots", []); live[key] = n
		_queue_missing(n, site, district)
	for key in live.keys():
		if not wanted.has(key): _remove(key)
	if immediate:
		while not jobs.is_empty(): step()
		_citizens()
	_update_proxies()

func _queue_missing(root: Node3D, site: Dictionary, district: Dictionary) -> void:
	var built: Array = root.get_meta("built_plots", [])
	for plot in plan(world.atlas, site).plots:
		if plot.district != district.index or built.has(int(plot.index)): continue
		if _occupied(site.pos + plot.p, 7): continue
		var pending = false
		for job in jobs:
			if job.root == root and int(job.plot.index) == int(plot.index): pending = true; break
		if not pending: jobs.append({"root": root, "site": site, "plot": plot})

func _remove(key: String) -> void:
	var root: Node3D = live[key]
	for id in active_residents.keys():
		var actor = active_residents[id]
		if is_instance_valid(actor) and root.is_ancestor_of(actor): world.residents.erase(actor); actor.remove_from_group("npc"); actor.remove_from_group("interactable"); active_residents.erase(id)
	jobs = jobs.filter(func (job): return job.root != root)
	remove_child(root); root.queue_free(); live.erase(key)
func clear() -> void:
	for key in live.keys(): _remove(key)
	_update_proxies()
func has_plot(site_id: String, index: int) -> bool:
	for root in live.values():
		if root.get_meta("site") == site_id and root.get_meta("built_plots", []).has(index): return true
	return false

func _occupied(p: Vector2, radius: float) -> bool:
	return Occupancy.conflicts(world.state, Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2))

func step() -> void:
	if jobs.is_empty(): return
	var job = jobs.pop_front()
	if not is_instance_valid(job.root) or job.root.is_queued_for_deletion(): return
	var at: Vector2 = job.site.pos + job.plot.p
	if _occupied(at, 7) or job.root.get_meta("built_plots", []).has(int(job.plot.index)):
		_batch_completed(job.root); return
	_house(job.root, job.site, job.plot)
	var built: Array = job.root.get_meta("built_plots"); built.append(int(job.plot.index)); job.root.set_meta("built_plots", built)
	_update_proxies()
	_batch_completed(job.root)

func _batch_completed(root: Node3D):
	if not jobs.any(func (job): return job.root == root): DistrictBatches.rebuild(root, "district-%s-%s" % [root.get_meta("site"), root.get_meta("district")], null, true)

func _house(parent: Node3D, site: Dictionary, plot: Dictionary) -> void:
	var p: Vector2 = site.pos + plot.p; var high: float = world.height_at(p.x, p.y)
	for d in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]: high = maxf(high, world.height_at(p.x + d.x, p.y + d.y))
	var house = P.building(parent, Vector3(plot.p.x, high + 0.08, plot.p.y), plot.w, plot.d, site.wall_color, site.roof_color, plot.heading, "Home", site.id + "_home_" + str(plot.index), plot.purpose, int(site.region))
	house.name = "Building_" + str(plot.index)
	var paths = load("res://scripts/building_paths.gd")
	var obstacles = paths.planned(parent, plan(world.atlas, site).plots, true) + paths.civic(site) + paths.props(world.locations) + paths.props(parent)

	for neighbor in world.find_children("*", "Node3D", true, false):
		if neighbor.is_in_group("settlement_building") and neighbor != house and neighbor.has_meta("building_width"):
			obstacles.append(paths.footprint(paths.frame(neighbor), neighbor.get_meta("building_width"), neighbor.get_meta("building_depth"), neighbor.get_meta("purpose", "home")))
	paths.attach(house, world, paths.streets(world, site), obstacles)
	paths.batch(parent)
	B.batch_static(house); P.cull_art(house, 155)

static func _walk_surface(faces: Array[PackedVector3Array]) -> ArrayMesh:


	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array()
	for face in faces:
		var normal = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		if normal.y < 0: normal = -normal
		for i in range(1, face.size() - 1):
			var tri = [face[0], face[i], face[i + 1]]
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0: tri = [face[0], face[i + 1], face[i]]
			for p in tri: vertices.append(p); normals.append(normal); uv.append(Vector2(p.x, p.z))
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh

func _district_art(parent: Node3D, site: Dictionary, district: Dictionary) -> void:
	var p: Vector2 = site.pos + district.p; var h: float = world.height_at(p.x, p.y)
	P.signboard(parent, Vector3(district.p.x, h + 3, district.p.y), district.name, 0, 6)
	if site.kind == "city":
		var paving = B.world_surface("stone", str(site.wall_color))
		for lane in [-32.0, -16.0, 0.0, 16.0, 32.0]:
			for z in range(-40, 40, 5):
				var corners := PackedVector3Array()
				for delta in [Vector2(-1.6, 0), Vector2(-1.6, 5), Vector2(1.6, 5), Vector2(1.6, 0)]:
					var q = p + Vector2(lane, z) + delta; corners.append(Vector3(q.x - site.pos.x, world.surface_height_at(q.x, q.y) + 0.025, q.y - site.pos.y))
				if not _occupied(p + Vector2(lane, z + 2.5), 2): B.mesh(parent, _walk_surface([corners]), paving)
		for side in [-1, 1]:
			for z in [-37.0, 37.0]:
				var q = p + Vector2(side * 5, z)
				if _occupied(q, 3): continue
				var spot = Vector3(q.x - site.pos.x, world.surface_height_at(q.x, q.y), q.y - site.pos.y)
				P.stall(parent, spot, "#a18567" if site.region != 15 else "#8d9eb1"); P.barrel(parent, spot + Vector3(side * 2, 0, 0.4))
		for z in [-24.0, 0.0, 24.0]:
			for side in [-1, 1]:
				var q = p + Vector2(side * 3.5, z)
				if not _occupied(q, 2): P.lantern(parent, Vector3(q.x - site.pos.x, world.surface_height_at(q.x, q.y), q.y - site.pos.y))
	if site.kind == "city":
		var edge = Vector2(signf(district.p.x) * 82, 0) if absf(district.p.x) > absf(district.p.y) else Vector2(0, signf(district.p.y) * 82)
		var path = [Vector2.ZERO, edge, district.p]
		for segment in range(2):
			var steps = ceili(path[segment].distance_to(path[segment + 1]) / 8)
			for i in range(1, steps + 1):
				var a: Vector2 = site.pos + path[segment].lerp(path[segment + 1], float(i - 1) / steps); var b: Vector2 = site.pos + path[segment].lerp(path[segment + 1], float(i) / steps)
				if _occupied((a + b) * 0.5, 3): continue
				var y0: float = world.height_at(a.x, a.y) + 0.04; var y1: float = world.height_at(b.x, b.y) + 0.04
				var delta = Vector3(b.x - a.x, y1 - y0, b.y - a.y); var root = Node3D.new(); parent.add_child(root); root.position = Vector3((a.x + b.x) * 0.5 - site.pos.x, (y0 + y1) * 0.5 - 0.06, (a.y + b.y) * 0.5 - site.pos.y)
				root.rotation.y = atan2(delta.x, delta.z); root.rotation.x = -atan2(delta.y, Vector2(delta.x, delta.z).length())
				B.box(root, Vector3.ZERO, Vector3(4.2, 0.12, delta.length() + 0.12), B.world_surface("stone", str(site.wall_color)), true)

	var local = Vector3(district.p.x + 5, h, district.p.y)


	var yard_offset = Vector2(24, 37) if site.kind == "city" else Vector2(10, 0)
	var yard_point = p + yard_offset
	if not _occupied(yard_point, 7):
		var yard = Node3D.new(); yard.name = "RegionalWorkyard"; parent.add_child(yard)
		yard.position = Vector3(district.p.x + yard_offset.x, world.surface_height_at(yard_point.x, yard_point.y), district.p.y + yard_offset.y)
		Dressing.workyard(yard, int(site.region), int(district.index))
	if _occupied(p + Vector2(5, 0), 4): B.batch_static(parent); return
	if site.region == 11:
		B.box(parent, local + Vector3.UP * 4, Vector3(2, 8, 2), B.mat("#b4ac80")); var hub = local + Vector3(0, 7, 1.2)
		for i in range(4): B.branch(parent, hub, hub + Vector3(sin(i * PI * 0.5) * 5, cos(i * PI * 0.5) * 5, 0), 0.15, B.mat("#c9c3a7"), 1)
	elif site.region == 15:
		B.facet(parent, local + Vector3.UP * 3, Vector3(1.8, 6, 1.8), B.mat("#b2cbd7", 0.15, 0.16)); B.ring(parent, local + Vector3.UP * 2, 2, 0.07, B.mat("#bba775", 0.55))
	elif site.region == 12:
		for x in [-2, 2]: B.cyl(parent, local + Vector3(x, 2, 0), 0.2, 4, B.mat("#c1a379"))
		B.box(parent, local + Vector3.UP * 4, Vector3(5, 0.15, 5), B.world_surface("cloth", "#a77a56"))
	elif site.region == 10:
		P.stall(parent, local, "#b29367"); P.barrel(parent, local + Vector3(2, 0, 0))
	else:
		P.bench(parent, local, PI * 0.5); P.barrel(parent, local + Vector3(2, 0, 0))
	B.batch_static(parent)

func _citizens() -> void:
	var candidates: Array = []
	for root in live.values():
		var site: Dictionary = world.atlas.sites().filter(func (s): return s.id == root.get_meta("site"))[0]
		var data = plan(world.atlas, site)
		for person in data.population:
			if int(person.home) % 5 != 0 and person.role not in ["stores", "workshop", "bakery", "inn", "library"]: continue
			if int(person.district) != int(root.get_meta("district")) or not root.get_meta("built_plots", []).has(int(person.home)): continue
			var household = posmod(floori(world.state.journey_time / 90) + int(person.home), 5 if site.kind == "city" else 4)
			if int(person.id.get_slice("_", 2)) / data.plots.size() != household: continue
			var plot: Dictionary = data.plots[int(person.home)]; var at: Vector2 = site.pos + plot.p
			var distance = at.distance_to(Vector2(viewer.x, viewer.z))
			if distance < 62: candidates.append({"person": person, "plot": plot, "site": site, "root": root, "distance": distance})
	candidates.sort_custom(func (a, b): return a.distance < b.distance)
	var wanted = {}; var homes = {}
	for candidate in candidates:
		var house_id = "%s:%s" % [candidate.site.id, candidate.person.home]
		if wanted.size() >= 16: break
		if homes.has(house_id): continue
		homes[house_id] = true; var id: String = candidate.person.id; wanted[id] = true
		if active_residents.has(id): continue
		var plot: Dictionary = candidate.plot; var site: Dictionary = candidate.site
		var direction = Vector2(sin(plot.heading), cos(plot.heading)); var pos: Vector2 = plot.p + direction * (plot.d * 0.5 + 3.8); var at: Vector2 = site.pos + pos
		var y: float = world.height_at(at.x, at.y) + 0.05; var tangent = direction.orthogonal()
		var route := PackedVector3Array()
		for d in [-1, 1]:
			var q = pos + tangent * float(d) * 1.1
			route.append(Vector3(q.x, world.height_at(site.pos.x + q.x, site.pos.y + q.y) + 0.05, q.y))
		var role: String = candidate.person.role
		# Specialists: the workshop's blacksmith, the bakery's grocer, the inn's alchemist,
		# the library's curio dealer; stores are general stores or (every other one) anglers.
		var shop: String = {"workshop": "blacksmith", "bakery": "grocer", "inn": "alchemist", "library": "curio"}.get(role, "")
		if role == "stores": shop = "angler" if (int(candidate.person.home) / 8) % 2 == 1 else "general"
		var trade_line: String = "I'm %s's %s: %s Have a look." % [str(site.name), Merchants.title(shop).to_lower(), Merchants.blurb(shop).to_lower()] if shop != "" else "The main roads connect our homes to neighboring towns."
		P.npc(world, candidate.root, id, candidate.person.name, ["#7f9a87", "#a48665", "#8d789a", "#8c9aaf"][int(candidate.person.phase)], shop, ["Welcome to " + str(site.name) + ". This is our " + str(role) + " quarter.", trade_line, "Come in and look around. Every house has a place to rest, eat, work and store its belongings."], "human", "merchant" if shop != "" else "neighbor", route, "scarf", Vector3.ZERO, candidate.root.get_node_or_null("Building_" + str(candidate.person.home)) if shop != "" else null)
		var actor = world.residents.back()
		actor.set_meta("household_role", role)
		if actor.imported_actor != null: actor.imported_actor.context = role
		actor.set_meta("schedule", "work" if fmod(world.state.journey_time, 480) < 300 else "homeward"); active_residents[id] = actor
	for id in active_residents.keys():
		if wanted.has(id): continue
		var actor = active_residents[id]
		if is_instance_valid(actor): world.residents.erase(actor); actor.remove_from_group("npc"); actor.remove_from_group("interactable"); actor.queue_free()
		active_residents.erase(id)
