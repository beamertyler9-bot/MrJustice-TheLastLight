extends RefCounted

const B = preload("res://scripts/build.gd")
const MosswakeDistrict = preload("res://scripts/mosswake_district.gd")
const RegionalFurnishings = preload("res://scripts/regional_furnishings.gd")
const Occupancy = preload("res://scripts/world_occupancy.gd")
const Resident = preload("res://scripts/resident.gd")
const Mineable = preload("res://scripts/mineable.gd")
const ItemModels = preload("res://scripts/item_models.gd")

const TOWER = {"id": "wizard_tower", "name": "The Wizard's Tower", "pos": Vector2(-20, -14), "clearance": 6.0}
const TOWER_ROUTE = [Vector2(-10, -17), Vector2(-20, -10)]
const SITES = [
	{"id": "brindlewick", "name": "Brindlewick", "pos": Vector2(-32, 18), "kind": "village", "clearance": 27.0, "bounds": Rect2(-43, -28, 70, 56)},


	{"id": "ironbell", "name": "Ironbell Market", "pos": Vector2(65, 12), "kind": "town", "clearance": 29.0, "bounds": Rect2(-21, -29, 71, 58)},
	{"id": "mine", "name": "Embervein Cave & Mine", "pos": Vector2(-16, -45), "kind": "mine", "clearance": 8.0},
	{"id": "dungeon", "name": "The Bellkeeper's Crypt", "pos": Vector2(118, 47), "kind": "dungeon", "clearance": 5.0, "bounds": Rect2(-8, -5, 16, 18)},
	{"id": "alderhaven", "name": "Alderhaven", "pos": Vector2(-260, 160), "kind": "city", "clearance": 65.0, "district": "crescent"},
	{"id": "sunspire", "name": "Sunspire Bazaar", "pos": Vector2(330, 230), "kind": "city", "clearance": 67.0, "district": "courtyards"},
	{"id": "frostharbor", "name": "Frostharbor", "pos": Vector2(-260, -300), "kind": "city", "clearance": 69.0, "district": "avenues"}]
const MOUNTAINS = [
	{"id": "westreach_summit", "name": "Westreach Summit", "pos": Vector2(-63, -31), "kind": "mountain", "extent": Vector2(26, 22), "rise": 31.0},
	{"id": "glasswood_summit", "name": "Glasswood Summit", "pos": Vector2(112, -30), "kind": "mountain", "extent": Vector2(30, 25), "rise": 36.0}]
const ROUTES = [
	[Vector2.ZERO, Vector2(-14, 7)], [Vector2(-14, 7), Vector2(-32, 18)],
	[Vector2.ZERO, Vector2(18, 16)], [Vector2(18, 16), Vector2(43, 37)],
	[Vector2(43, 37), Vector2(65, 37)], [Vector2(65, 37), Vector2(65, 12)],
	[Vector2.ZERO, Vector2(-10, -17)], [Vector2(-10, -17), Vector2(-16, -33)],
	[Vector2(-16, -33), Vector2(-16, -40.5)],
	[Vector2(65, 37), Vector2(118, 47)]]
const FRONTIER_ROUTES = [
	[Vector2(-145, 107), Vector2(-204, 160)], [Vector2(-204, 160), Vector2(-260, 160)],
	[Vector2(175, 135), Vector2(260, 230)], [Vector2(260, 230), Vector2(330, 230)],
	[Vector2(-145, -175), Vector2(-260, -230)], [Vector2(-260, -230), Vector2(-260, -300)]]
const INTERIORS = {"mine": Vector3(-240, -24, 180), "dungeon": Vector3(240, -24, 180)}

static func get_locations() -> Array:
	var result: Array = []
	for site in SITES + MOUNTAINS:
		result.append({"id": site.id, "name": site.name, "pos": site.pos, "kind": site.kind})
	return result

static func reserved(p: Vector2, padding: float = 0.0) -> bool:
	if p.distance_to(TOWER.pos) < TOWER.clearance + padding + 1.5: return true
	for site in SITES:
		if site_bounds(site).grow(padding + 1.5).has_point(p - site.pos):
			return true
	return false

static func site_bounds(site: Dictionary) -> Rect2:
	return site.get("bounds", Rect2(-site.clearance, -site.clearance, site.clearance * 2, site.clearance * 2))

static func flatten_weight(site: Dictionary, p: Vector2) -> float:
	var bounds := site_bounds(site)
	var local: Vector2 = p - site.pos
	var outside := maxf(maxf(bounds.position.x - local.x, local.x - bounds.end.x), maxf(bounds.position.y - local.y, local.y - bounds.end.y))
	return 1.0 - smoothstep(0.0, 18.0 if site.kind == "city" else 4.0, outside)

static var _interior_masks: Dictionary = {}

static func interior_at(point: Vector3, seed_value: int = 0) -> String:
	for id in INTERIORS:
		var p: Vector3 = point - INTERIORS[id]
		if p.y < -1.5 or p.y > 13.0:
			continue
		var key := "%s:%s" % [id, seed_value]
		if not _interior_masks.has(key):

			if _interior_masks.size() > 12: _interior_masks.clear()
			_interior_masks[key] = _deep_cells(id, deep_layout(id, seed_value))
		if _interior_masks[key].has(Vector2i(floori(p.x), floori(p.z))):
			return id
	return ""

static func build(world) -> void:
	if world.locations != null:
		return
	world.locations = Node3D.new()
	world.locations.name = "FrontierLocations"
	world.add_child(world.locations)
	if world.get("atlas") != null: return
	for site in SITES:
		if site.kind == "city": continue
		var n = Node3D.new()
		n.name = site.id.capitalize()
		n.position = Vector3(site.pos.x, world.height_at(site.pos.x, site.pos.y), site.pos.y)
		n.set_meta("location_id", site.id)
		world.locations.add_child(n)
		if site.kind in ["village", "town"]:
			settlement(world, n, site.kind == "town", site.id)
		else:
			cave_mouth(n, site.kind == "dungeon", world)
			var dst: Vector3 = INTERIORS[site.id] + Vector3(0, 0.22, 4)
			entrance(n, "entrance_" + site.id, Vector3(0, 0.3, 0), dst, site.name, "Enter " + site.name)
			interior(world, site.id, n.position + Vector3(0, 0.25, 4.5))
		if site.kind in ["village", "town"]: load("res://scripts/building_paths.gd").complete(world, n, site)
		B.batch_static(n)
		cull_art(n, 190.0 if site.kind == "town" else 145.0)



static func stream_settlements(world, point: Vector3, immediate: bool = true) -> void:
	if world.locations == null: return
	var outdoors: bool = world.interior_at(point).is_empty()
	for site in world.site_catalog:
		if site.kind != "city" and world.get("atlas") == null: continue
		var existing = world.locations.get_node_or_null(str(site.id).capitalize())
		var distance: float = Vector2(point.x, point.z).distance_to(site.pos) if outdoors else INF
		if existing != null and distance > 290.0:
			for resident in world.residents.duplicate():
				if is_instance_valid(resident) and existing.is_ancestor_of(resident):
					world.residents.erase(resident)
			for job in world.settlement_jobs.duplicate():
				if job.root == existing: world.settlement_jobs.erase(job)
			world.locations.remove_child(existing)
			existing.queue_free()
		elif existing == null and distance < 185.0:
			var city := Node3D.new()
			city.name = str(site.id).capitalize()
			city.position = Vector3(site.pos.x, world.height_at(site.pos.x, site.pos.y), site.pos.y)
			city.set_meta("location_id", site.id)
			world.locations.add_child(city)
			if immediate:
				city_settlement(world, city, site)
				B.batch_static(city)
				cull_art(city, 360.0 if world.get("atlas") != null else 180.0)
				load("res://scripts/district_batches.gd").build(city, "civic-" + str(site.id))
			else:
				city.set_meta("streaming", true)
				world.settlement_jobs.append({"root": city, "site": site, "plots": city_plots(site, world.state.seed_value), "index": 0})
	if immediate:
		while not world.settlement_jobs.is_empty(): step_settlement(world)

static func cull_art(n: Node3D, distance: float) -> void:
	for geometry in n.find_children("*", "GeometryInstance3D", true, false):
		geometry.visibility_range_end = minf(distance, geometry.visibility_range_end) if geometry.visibility_range_end > 0 else distance
		geometry.visibility_range_end_margin = 8.0

static func interaction(parent: Node3D, id: String, kind: String, label: String, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.name = id
	n.position = pos
	parent.add_child(n)
	n.set_meta("id", id)
	n.set_meta("kind", kind)
	n.set_meta("label", label)
	n.add_to_group("interactable")
	return n

static func entrance(parent: Node3D, id: String, pos: Vector3, dst: Vector3, title: String, label: String) -> void:
	var n = interaction(parent, id, "entrance", label, pos)
	n.set_meta("destination", dst)
	n.set_meta("location_name", title)
	load("res://scripts/entrance_ring.gd").build_marker(n)

static func lantern(parent: Node3D, p: Vector3, pole: bool = true, cave: bool = false) -> void:
	var O = load("res://scripts/world_overhaul.gd")
	if pole: O.fit(parent, "avra_allassets_with_texture_streetlamp_01", p, Vector3(0.75, 3.0, 0.75))
	else: O.fit(parent, "kaykit_lantern", p - Vector3.UP * 0.3, Vector3(0.5, 0.65, 0.5))
	p += Vector3(0, 2.4, 0) if pole else Vector3.ZERO
	if cave:
		var light = OmniLight3D.new()
		light.position = p
		light.light_color = Color("#ffd89b")
		light.light_energy = 1.35
		light.omni_range = 12
		parent.add_child(light)

static func building(parent: Node3D, p: Vector3, width: float, depth: float, color: String, roof_color: String, heading: float = 0, title: String = "Home", identity: String = "", purpose: String = "home", region: int = 9) -> Node3D:
	var n = Node3D.new(); n.position = p; n.rotation.y = heading; parent.add_child(n)
	if identity.is_empty(): identity = title + str(p)
	n.name = identity.validate_node_name()
	n.set_meta("building_title", title)
	n.set_meta("purpose", purpose)
	n.set_meta("plot_id", identity); n.add_to_group("settlement_building")
	load("res://scripts/village_architecture.gd").build(n, width, depth, region, identity, color, roof_color)
	var first_interior = n.get_child_count()
	load("res://scripts/building_interiors.gd").furnish(n, width - 0.4, depth - 0.4, purpose, identity, region)
	var contents = n.get_children().slice(first_interior)
	var interior = load("res://scripts/interior_visibility.gd").new(); interior.name = "HouseholdInterior"; n.add_child(interior); interior.setup(n, width, depth)
	for child in contents: child.reparent(interior, false)
	B.merge_colored(interior); B.batch_static(interior); interior.capture_geometry()
	if load("res://scripts/shop_architecture.gd").service(purpose): load("res://scripts/shop_architecture.gd").frontage(n, width, depth, title)
	if purpose in ["workshop", "smith_shop"]: load("res://scripts/shop_architecture.gd").smith_bay(n, width, depth, region)
	B.merge_colored(n)
	return n

static func npc(world, parent: Node3D, id: String, title: String, coat: String, shop: String, lines: Array, race: String, role: String, route: PackedVector3Array, accessory: String = "", work_target: Vector3 = Vector3.ZERO, service_house: Node3D = null) -> void:
	var n = Resident.new()
	parent.add_child(n)
	var speech: Array[String] = []
	for line in lines:
		speech.append(str(line))
	n.configure({"id": id, "name": title, "coat": coat, "shop": shop, "dialogue": speech, "race": race, "role": role, "accessory": accessory, "work_target": work_target}, route)
	if not shop.is_empty():
		var shops = load("res://scripts/shop_architecture.gd")
		var house = service_house if service_house != null else shops.available_shop(parent, shop, id)
		if house == null: house = ensure_shop(world, parent, shop, title, id)
		shops.bind_vendor(n, house)
	world.residents.append(n)

static func ensure_shop(world, parent: Node3D, kind: String, title: String, identity: String) -> Node3D:
	var shops = load("res://scripts/shop_architecture.gd")
	var existing = shops.available_shop(parent, kind, identity)
	if existing != null: return existing
	var at = Vector3(-9, 0, -8) if kind == "smith" else Vector3(8, 0, 5)
	if kind == "general" and parent.get_meta("location_id", "") == "bellcrown": at = Vector3(11, 0, -11)
	var region = int(parent.get_meta("region", 9))
	if world != null and world.has_method("surface_height_at"):
		var frame = shops._root_frame(parent); var global = frame * at
		at = frame.affine_inverse() * Vector3(global.x, world.surface_height_at(global.x, global.z) + 0.04, global.z)
	return building(parent, at, 7.2, 6.2, "#b6ad98", "#59636c", PI if kind == "smith" else 0, title + " / Smithy" if kind == "smith" else title + " / Provisions", identity + "_shop", "workshop" if kind == "smith" else "stores", region)

static func stall(parent: Node3D, p: Vector3, color: String) -> void:
	var O = load("res://scripts/world_overhaul.gd")
	var model = O.fit(parent, "qprop_stall_empty", p, Vector3(3.2, 3.0, 2.2))
	model.set_meta("stall_cloth", color)
	O.support_box(model, Vector3(0, 0.85, 0) / model.scale, Vector3(3.0, 1.2, 1.2) / model.scale)
	for side in [-1, 1]: O.fit(parent, "qprop_farmcrate_apple" if side < 0 else "qprop_farmcrate_carrot", p + Vector3(side * 0.7, 1.02, 0.05), Vector3(0.85, 0.42, 0.65))

static func signboard(parent: Node3D, p: Vector3, title: String, heading: float = 0.0, width: float = 2.4, placement: String = "") -> Node3D:
	if placement not in ["settlement_entrance", "cave_entrance", "crossroads"]: return null
	var n = Node3D.new()
	n.position = p
	n.rotation.y = heading
	parent.add_child(n)
	n.add_to_group("wayfinding_sign"); n.set_meta("sign_placement", placement); n.set_meta("sign_title", title)
	load("res://scripts/world_overhaul.gd").fit(n, "u29_wayfinding_board", Vector3(0, -0.375, 0), Vector3(width, 0.75, 0.12))
	if placement == "crossroads": load("res://scripts/world_overhaul.gd").fit(n, "resource_wood_log_a", Vector3(0, -1.65, 0), Vector3(0.13, 1.65, 0.13))
	var label = Label3D.new()
	label.text = title
	label.position.z = 0.085
	label.font_size = 48
	label.pixel_size = minf(0.009, width / maxf(6.0, title.length()) / 27.0)
	label.outline_size = 9
	label.modulate = Color("#ffe2a1")
	label.no_depth_test = false
	label.double_sided = false
	n.add_child(label)

	return n

static func bench(parent: Node3D, p: Vector3, heading: float = 0.0) -> void:
	var paths = load("res://scripts/building_paths.gd")
	var model = load("res://scripts/world_overhaul.gd").fit(parent, "qprop_bench", p, Vector3(1.35, 0.91, 0.4), heading)
	if model != null:
		paths.reserve_mesh(parent, model); return
	paths.reserve_prop(parent, p, Vector2(1.35, 0.4), heading)
	var n = Node3D.new()
	n.position = p
	n.rotation.y = heading
	parent.add_child(n)
	var wood = B.world_surface("timber", "#896847")
	for x in [-0.5, 0.5]:
		B.box(n, Vector3(x, 0.22, 0), Vector3(0.12, 0.44, 0.36), wood)
	for z in [-0.13, 0.1]:
		B.box(n, Vector3(0, 0.48, z), Vector3(1.35, 0.1, 0.18), wood)
	B.box(n, Vector3(0, 0.83, -0.2), Vector3(1.35, 0.15, 0.08), wood)

static func barrel(parent: Node3D, p: Vector3) -> void:
	var body = preload("res://scripts/breakable_barrel.gd").new(); body.position = p + Vector3.UP * 0.42; body.mass = 3; body.freeze = true; body.collision_layer = 8; body.collision_mask = 1 | 4 | 8; parent.add_child(body)
	var collision = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size = Vector3(0.68, 0.84, 0.68); collision.shape = shape; body.add_child(collision)
	if load("res://scripts/world_overhaul.gd").fit(body, "qprop_barrel", Vector3(0, -0.42, 0), Vector3(0.68, 0.84, 0.68)) != null: return
	var wood = B.world_surface("timber", "#98724c")
	B.cyl(body, Vector3.ZERO, 0.34, 0.84, wood, false, 0.31)
	for y in [0.1, 0.7]:
		B.cyl(body, Vector3.UP * (y - 0.42), 0.35, 0.055, B.mat("#535b55", 0.45))
	B.cyl(body, Vector3.UP * 0.43, 0.3, 0.03, wood)

static func garden(parent: Node3D, p: Vector3, flowers: bool = false) -> void:
	var soil = B.world_surface("ground", "#655541")
	B.box(parent, p + Vector3(0, 0.015, 0), Vector3(3.0, 0.04, 4.0), soil)
	for x in [-1.55, 1.55]:
		B.box(parent, p + Vector3(x, 0.1, 0), Vector3(0.12, 0.2, 4.2), B.mat("#957655"))
	for row in range(4):
		for col in range(3):
			var sprout = p + Vector3(-0.95 + col * 0.95, 0.22, -1.4 + row * 0.9)
			load("res://scripts/imported_assets.gd").place(parent, "qnat_flower_3_group" if flowers else "qnat_plant_1", sprout - Vector3.UP * 0.18, 0.55, float(row + col) * 1.8)

static func plot_details(house: Node3D, width: float, depth: float, index: int) -> void:
	var timber = B.world_surface("timber", "#76553c")
	var side = 1.0 if index % 2 == 0 else -1.0

	barrel(house, Vector3(side * (width / 2 + 0.7), 0, depth / 2 - 0.4))
	load("res://scripts/world_overhaul.gd").fit(house, "qprop_crate_wooden", Vector3(side * (width / 2 + 0.7), 0, depth / 2 - 1.2), Vector3(0.55, 0.46, 0.55))
	load("res://scripts/world_overhaul.gd").fit(house, "resource_wood_log_stack", Vector3(-width / 2 - 0.65, 0, -0.4), Vector3(0.7, 0.65, 1.8))
	for post in [-1.0, 1.0]:
		B.box(house, Vector3(post * (width / 2 + 1.4), 0.65, -depth / 2 - 0.6), Vector3(0.12, 1.3, 0.12), timber)
	B.branch(house, Vector3(-width / 2 - 1.4, 1.2, -depth / 2 - 0.6), Vector3(width / 2 + 1.4, 1.2, -depth / 2 - 0.6), 0.018, B.mat("#cfbd8f"), 1)
	for cloth in range(3):
		var sheet = B.box(house, Vector3(-1.3 + cloth * 1.3, 0.84, -depth / 2 - 0.6), Vector3(0.85, 0.65, 0.035), B.world_surface("cloth", ["#c7b889", "#9f7370", "#668e88"][cloth]))
		sheet.rotation.z = 0.045 * (cloth - 1)


	for puff in range(3):
		var smoke = B.ball(house, Vector3(width * 0.27 + 0.17 * puff, 6.15 + puff * 0.35, -depth * 0.2), Vector3.ONE * (0.36 + puff * 0.12), B.mat("#acb9aa"))
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func local_loop(x0: float, z0: float, x1: float, z1: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(x0, 0.05, z0), Vector3(x1, 0.05, z0), Vector3(x1, 0.05, z1), Vector3(x0, 0.05, z1)])

static func settlement(world, parent: Node3D, town: bool, site_id: String = "") -> void:
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = hash("settlement:%s:%s" % [world.state.seed_value, site_id])
	var stone = B.world_surface("stone", "#8d927e")
	var timber = B.world_surface("timber", "#5f4c38")
	var house_z = [-20.0, -7.0, 7.0, 20.0] if town else [-17.0, 0.0, 17.0]
	var names = ["Bellkeeper's Hall", "The Copper Kettle", "Mara's Provisions", "The Cloth & Quill", "The Tall Oak", "Ironhand Smithy", "Wayfarer House", "The Little Loaf"] if town else ["Pip's Timber Lodge", "Rowan's Pantry", "Juniper's Cottage", "The Willow House", "Emberhand Smithy", "The Hearth & Honey"]
	var index = 0
	for side in [-1.0, 1.0]:
		var x = (-16.0 if side < 0 else 21.0) if town else side * 18.0
		for z in house_z:
			var width = (7.0 if town else 6.3) + layout_rng.randf_range(0.0, 0.55)
			var purpose = "workshop" if "Smithy" in names[index] else "stores" if "Pantry" in names[index] or "Provisions" in names[index] else "home"
			var house = building(parent, Vector3(x, 0, z + layout_rng.randf_range(-0.4, 0.4)), width, 6.0, ["#d1bd95", "#bac3a1", "#d4c6a5", "#b5c4b3"][index % 4], "#8f4e3e" if index % 2 == 0 else "#526b63", PI / 2 if side < 0 else -PI / 2, names[index], "", purpose)
			plot_details(house, width, 6.0, index)
			if absf(float(z)) > 10 and (not town or side > 0):
				garden(parent, Vector3(x + side * 5.5, 0, z), index % 2 == 1)
			index += 1


	for z in [-25.0, 25.0]:
		for x in [-5.7, 5.7]:
			B.box(parent, Vector3(x, 1.6, z), Vector3(0.28, 3.2, 0.35), timber)
		B.box(parent, Vector3(0, 3.25, z), Vector3(11.8, 0.28, 0.45), timber)
	if town:
		for x in [-19.5, 27.0]:
			for z in [-26.0, 26.0]:
				B.cyl(parent, Vector3(x, 1.5, z), 1.25, 3, stone, true)
				B.cyl(parent, Vector3(x, 3.2, z), 1.5, 0.45, timber)
		B.cyl(parent, Vector3(0, 2.65, 25), 0.54, 0.72, B.mat("#bd9d57", 0.6), false, 0.2)
		B.ball(parent, Vector3(0, 2.3, 25), Vector3.ONE * 0.17, B.mat("#584d34"))
		if load("res://scripts/shop_architecture.gd").find_shop(parent, "general") == null: stall(parent, Vector3(-11.5, 0, 17), "#8e5360")
	if load("res://scripts/shop_architecture.gd").find_shop(parent, "general") == null: stall(parent, Vector3(13, 0, 20), "#bb8753" if not town else "#607f79")
	forge(parent, Vector3(12.5, 0, -5), "IRONHAND SMITHY" if town else "EMBERHAND FORGE")

	var well = Vector3(-6.2, 0, -8.5)
	B.cyl(parent, well + Vector3.UP * 0.4, 0.9, 0.8, stone, true)
	B.cyl(parent, well + Vector3.UP * 0.82, 0.65, 0.04, B.mat("#304b4c"))
	for x in [-1.0, 1.0]:
		B.box(parent, well + Vector3(x, 1.35, 0), Vector3(0.13, 2.7, 0.13), timber)
	B.box(parent, well + Vector3(0, 2.65, 0), Vector3(2.45, 0.15, 1.8), B.mat("#8f4e3e"))
	B.branch(parent, well + Vector3(0, 2.6, 0), well + Vector3(0, 1, 0), 0.025, B.mat("#ad9872"))
	B.cyl(parent, well + Vector3(1.25, 0.2, 0.3), 0.23, 0.4, timber, false, 0.28)
	for p in [Vector3(-11, 0, -12), Vector3(11, 0, -12), Vector3(-11, 0, 12), Vector3(11, 0, 12)]:
		lantern(parent, p)
	bench(parent, Vector3(-12, 0, 7), PI / 2)
	bench(parent, Vector3(12, 0, 8), -PI / 2)
	garden(parent, Vector3(-12, 0, 13.5 if town else 10), true)
	var prefix = (site_id if not site_id.is_empty() else "ironbell" if town else "brindlewick") + "_"
	npc(world, parent, prefix + "merchant", "Mara of the Market" if town else "Auntie Rowan", "#a56c4c", "general", ["Welcome to Ironbell. Every road brings a story." if town else "Brindlewick keeps a warm lantern for every wanderer.", "Gather timber and loose stones, then make a camp kit in your fieldbook.", "I trade supplies for Light Essence. Come browse."], "human", "merchant", local_loop(8, 14, 9, 17), "bun", Vector3(13, 0, 17))
	npc(world, parent, prefix + "resident", "Bellkeeper Oren" if town else "Forester Pip", "#52756d", "", ["From the starting glade, take the ochre trail north to Embervein. Its branching mine reaches deep under the mountain.", "The crypt's floor marks warn before spikes and bell pulses. Step away after the tell, or keep solid stone between you and the blast." if town else "Glassroot Grotto loops around the great air shaft. Look above the old mining ramps for a forgotten strongbox.", "Awaken the Ember, Echo and Tide seals in the crypt's side chapels. Their light survives rest and defeat; all three open the Bellkeeper's court.", "The Bellkeeper binds the Dawn Vault. Defeat the warden, then cross the east passage for a blade worth the journey." if town else "Embermaw sleeps in the deepest hollow. Its ancient cores can become Warden Plate at a workbench."], "human", "reader" if town else "forester", local_loop(-9, -19, -7, -15), "spectacles" if town else "hat", Vector3(-15, 0, -20))
	npc(world, parent, prefix + "gardener", "Sable Willow" if town else "Juniper", "#718452", "", ["The flowerbeds need a little care every day. So do people.", "Coffee and a roasted marshmallow make a fine camp supper."], "elf", "gardener", local_loop(-9, 14, -7, 18), "bun", Vector3(-12, 0, 18))
	npc(world, parent, prefix + "smith", "Hester Ironhand" if town else "Bramm Emberhand", "#62576d" if town else "#5c6752", "smith", ["A steady hand shapes iron; a kind hand decides its use." if town else "Bramm Emberhand, at your service. Good green hands and honest iron.", "Embervein lies north of the starting glade. Follow its loops to the deep hollow; Embermaw guards ancient cores.", "Three crypt seals open the Bellkeeper's court: Ember Chapel west, Echo Scriptorium east, Tide Cistern beyond. Seals stay lit through defeat.", "Bring three ancient cores, eight iron and four crystal to a workbench. Warden Plate will turn that deep treasure into lasting protection.", "My smith's stock is ready. Come closer to the anvil."], "dwarf" if town else "orc", "smith", local_loop(9, -3.4, 8, -1), "", Vector3(10.4, 0, -4.6))
	npc(world, parent, prefix + "mason", "Dori Copperbraid" if town else "Tansy Stonefoot", "#9c7859", "", ["Stone remembers every season. I keep the old walls mended.", "Leave the wide road clear for travelers. There is always room by the fire."], "dwarf", "mason", local_loop(-9, -3.5, -7, -1), "scarf", Vector3(-14, 0, 0))
	npc(world, parent, prefix + "baker", "Pella Crumb" if town else "Nim Honeybun", "#b08e66", "", ["The first loaf is for the early traveler.", "A warm camp and a full bag make the road kinder."], "smallfolk", "baker", local_loop(8, -19, 9.5, -15), "hat", Vector3(14, 0, -17))
	npc(world, parent, prefix + "weaver", "Ilyra Threadsong" if town else "Lethiel Fernsong", "#668d95", "", ["Every road has its own pattern. I weave the ones I remember.", "Sit a moment. Even a lantern needs time to rest."], "elf", "weaver", local_loop(-8, 6, -6, 9), "scarf", Vector3(-12, 0, 7))
	npc(world, parent, prefix + "porter", "Gorrin Goodbarrel" if town else "Tobin Reed", "#9f6f58", "", ["A full market means a busy morning!", "Emberhand's forge is the pride of Brindlewick."], "orc" if town else "human", "porter", local_loop(6, 6, 8, 9), "scarf", Vector3(12, 0, 8))


	for extra in range(4):
		var x: float = (43.0 + layout_rng.randf_range(-1.5, 1.5)) if town else (-34.0 + layout_rng.randf_range(-1.5, 1.5))
		var z: float = -20.0 + extra * 13.0 + layout_rng.randf_range(-0.8, 0.8)
		var heading: float = -PI / 2 if town else PI / 2
		var title: String = ["Potter's Yard", "The Lantern House", "Reed Cottage", "Applewood Home"][extra]
		var home = building(parent, Vector3(x, 0, z), 5.8 + layout_rng.randf_range(0.0, 0.7), 5.4, "#c4bc9b", "#526b63" if town else "#8f4e3e", heading, title)
		barrel(home, Vector3(-3.7, 0, -1))
		var front: Vector3 = home.position + Vector3(-6.4 if town else 6.4, 0.05, 0)
		var route := PackedVector3Array([front + Vector3(0, 0, -1.2), front + Vector3(0, 0, 1.2), front + Vector3(-0.7 if town else 0.7, 0, 1.2), front + Vector3(-0.7 if town else 0.7, 0, -1.2)])
		npc(world, parent, prefix + "neighbor_" + str(extra), ["Arlen Reed", "Moss Applewick", "Fenna Clay", "Borin Ash"][extra], "#92785d", "", ["Our new quarter keeps the old road open for every traveler.", "The wider frontier holds Alderhaven's autumn market, Sunspire's desert courts, and snowy Frostharbor."], ["human", "smallfolk", "elf", "dwarf"][extra], ["porter", "gardener", "weaver", "mason"][extra], route, "scarf", home.position + Vector3(-4.4 if town else 4.4, 0, 0))

static func city_plots(site: Dictionary, seed_value: int) -> Array:
	if site.has("region") and FileAccess.file_exists("res://assets/world/fixed/map.bin"):
		return preload("res://scripts/fixed_world.gd").town_plots(site.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("city-plots:%s:%s" % [seed_value, site.id])
	var plots: Array = []
	if site.has("region") and site.kind == "town":
		for side in [-1.0, 1.0]:
			for z in [-42.0, -26.0, -10.0, 10.0, 26.0, 42.0]:
				plots.append({"p": Vector2(side * 25, z), "heading": PI / 2 if side < 0 else -PI / 2, "w": 6.8, "d": 5.6})
		return plots
	if site.district == "crescent":
		for ring in range(2):
			for i in range(12):
				var angle: float = (float(i) + 0.5) * TAU / 12.0 + rng.randf_range(-0.025, 0.025)
				var radius: float = (29.0 if ring == 0 else 49.0) + rng.randf_range(-1.2, 1.2)
				var at := Vector2(cos(angle), sin(angle)) * radius
				plots.append({"p": at, "heading": atan2(-at.x, -at.y), "w": rng.randf_range(6.0, 7.6), "d": rng.randf_range(5.0, 6.1)})
	elif site.district == "courtyards":
		for x in [-30.0, 30.0]:
			for z in [-30.0, 30.0]:
				for local in [Vector2(-14, -8), Vector2(-14, 8), Vector2(-8, 18), Vector2(8, 18), Vector2(14, 8), Vector2(14, -8)]:
					var at: Vector2 = Vector2(x, z) + local + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
					plots.append({"p": at, "heading": atan2(-local.x, -local.y), "w": rng.randf_range(6.0, 7.2), "d": rng.randf_range(5.0, 5.8)})
	else:
		for x in [-47.0, -29.0, 29.0, 47.0]:
			for z in [-46.0, -28.0, -10.0, 10.0, 28.0, 46.0]:
				var at := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.9, 0.9))
				plots.append({"p": at, "heading": PI / 2 if x < 0 else -PI / 2, "w": rng.randf_range(6.8, 8.2), "d": rng.randf_range(5.4, 6.2)})
	return plots

static func city_settlement(world, parent: Node3D, site: Dictionary) -> void:
	var plots := city_plots(site, world.state.seed_value)
	for i in range(plots.size()): _city_plot(world, parent, site, plots[i], i)
	_city_civic(parent, site, world)
	load("res://scripts/building_paths.gd").complete(world, parent, site, plots)

static func _city_plot(world, parent: Node3D, site: Dictionary, plot: Dictionary, i: int) -> void:
	parent.set_meta("region", int(site.get("region", 9)))
	var coats = ["#9e7355", "#668c7e", "#947187", "#a28658", "#63847d", "#9e7c69"]
	var races = ["human", "elf", "dwarf", "orc", "smallfolk"]
	var roles = ["porter", "gardener", "mason", "baker", "weaver", "forester"]
	var forenames = ["Ari", "Fenna", "Linden", "Bram", "Mira", "Orrin", "Tamsin", "Nella", "Corin", "Edda", "Rook", "Sylva"]
	var house_names = ["Lantern", "Willow", "Copper", "Hearth", "Juniper", "Kettle", "Apple", "Cedar"]
	var walls: String = site.get("wall_color", "#dac69c" if site.id == "sunspire" else "#bbc9b4" if site.id == "frostharbor" else "#cbb58f")
	var roofs: String = site.get("roof_color", "#aa6e4c" if site.id == "sunspire" else "#4d646d" if site.id == "frostharbor" else "#815443")
	if world.get("atlas") == null:
		var purpose = "stores" if i == 0 else "workshop" if i == 1 else "home"
		var house = building(parent, Vector3(plot.p.x, 0, plot.p.y), plot.w, plot.d, walls, roofs, plot.heading, house_names[i % 8] + " House " + str(i / 8 + 1), site.id + "_home_" + str(i), purpose)
		barrel(house, Vector3(-plot.w * 0.5 - 0.55, 0, -plot.d * 0.3))
	elif i >= 2 and i % 5 == 0 and site.id not in ["brindlewick", "ironbell"]: return
	var direction := Vector3(sin(plot.heading), 0, cos(plot.heading))
	var tangent := Vector3(direction.z, 0, -direction.x)
	var front: Vector3 = Vector3(plot.p.x, 0, plot.p.y) + direction * (plot.d * 0.5 + 4.0) + Vector3.UP * 0.05
	var route := PackedVector3Array([front - tangent * 1.1, front + tangent * 1.1, front + tangent * 1.1 + direction * 0.7, front - tangent * 1.1 + direction * 0.7])
	var role: String = roles[i % roles.size()]
	var shop: String = ""
	var id: String = site.id + "_resident_" + str(i)
	if i == 0:
		role = "merchant"; shop = "general"; id = site.id + "_merchant"
		route = local_loop(7, 8, 9, 9)
	elif i == 1:
		role = "smith"; shop = "smith"; id = site.id + "_smith"
		route = local_loop(-10, -3.7, -8, -2.7)
	var lines: Array = ["Welcome to " + site.name + ". Every district has its own people and its own stories.", "Our lanterns mark the broad streets. Stop at the central market for supplies."]
	if site.has("region"): lines.append("The signposted roads lead to neighboring towns. The lava region has wilderness trails and no settlements.")
	elif site.id == "alderhaven": lines.append("The autumn woods spread far beyond the orchard rings. Northward, dark firs climb toward the snow.")
	elif site.id == "sunspire": lines.append("Our four courtyard markets shelter travelers from the dunes. Take water before crossing the sandstone ridges.")
	else: lines.append("The long avenues lead through the snow. Conifer woods shelter the road back toward Mosswake.")
	if shop != "": lines.append("My stock is ready. Come browse when you need provisions or equipment.")
	var title = forenames[i % 12] + " " + ["Reed", "Copperleaf"][i / 12]; var race = races[i % 5]
	if site.id in ["brindlewick", "ironbell"] and i < 8:
		var identities = ["merchant", "smith", "resident", "gardener", "mason", "baker", "weaver", "porter"]
		id = site.id + "_" + identities[i]
		var names = ["Auntie Rowan", "Bramm Emberhand", "Forester Pip", "Juniper", "Tansy Stonefoot", "Nim Honeybun", "Lethiel Fernsong", "Tobin Reed"] if site.id == "brindlewick" else ["Mara of the Market", "Hester Ironhand", "Bellkeeper Oren", "Sable Willow", "Dori Copperbraid", "Pella Crumb", "Ilyra Threadsong", "Gorrin Goodbarrel"]
		title = names[i]; role = ["merchant", "smith", "forester", "gardener", "mason", "baker", "weaver", "porter"][i]
		race = ["human", "orc", "human", "elf", "dwarf", "smallfolk", "elf", "human"][i] if site.id == "brindlewick" else ["human", "dwarf", "human", "elf", "dwarf", "smallfolk", "elf", "orc"][i]
	npc(world, parent, id, title, coats[i % 6], shop, lines, race, role, route, "hat" if i % 3 == 0 else "scarf", Vector3(plot.p.x, 0, plot.p.y) + direction * (plot.d * 0.5 + 2.8))

static func _city_civic(parent: Node3D, site: Dictionary, world = null) -> void:
	if site.get("region", -1) == 15:
		B.facet(parent, Vector3(0, 39, 0), Vector3(9, 27, 9), B.mat("#a1caca", 0.1, 0.15))
		B.facet(parent, Vector3(0, 39, 0), Vector3(6, 32, 6), B.mat("#bba2d3", 0.12, 0.12)).rotation.y = 0.6
		B.ring(parent, Vector3(0, 33, 0), 12, 0.28, B.mat("#b69f71", 0.45))
	elif site.get("region", -1) == 9 and site.kind == "city":
		for x in [-4.0, 4.0]:
			for z in [-4.0, 4.0]: B.box(parent, Vector3(x, 10, z), Vector3(0.7, 20, 0.7), B.mat("#7d6d55"), true)
		B.box(parent, Vector3(0, 20, 0), Vector3(10, 1, 10), B.mat("#694a40"))
		B.cyl(parent, Vector3(0, 16, 0), 2.2, 3.7, B.mat("#b39c60", 0.55), false, 0.8)
	if site.id != "bellcrown" and load("res://scripts/shop_architecture.gd").find_shop(parent, "general") == null:
		stall(parent, Vector3(8, 0, 5), "#b68c54" if site.id == "sunspire" else "#7c6266")
		stall(parent, Vector3(8, 0, -6), "#5e8c80")
	forge(parent, Vector3(-9, 0, -8), str(site.name).to_upper() + " FORGE")
	for point in [Vector3(-5, 0, 17), Vector3(5, 0, -19), Vector3(-17, 0, 4), Vector3(17, 0, -2)]: lantern(parent, point)
	for point in [Vector3(-5, 0, -14) if site.id == "bellcrown" else Vector3(-7, 0, 8), Vector3(7, 0, -17)]: bench(parent, point)

	if site.district == "crescent":
		garden(parent, Vector3(-9, 0, 13), true)
		B.cyl(parent, Vector3(0, 0.4, 0), 1.1, 0.8, B.mat("#858a73"), true)
	elif site.district == "courtyards":
		for x in [-30.0, 30.0]:
			for z in [-30.0, 30.0]:
				B.cyl(parent, Vector3(x, 0.4, z), 1.0, 0.8, B.mat("#b39770"), true)
	else:
		for x in [-13.0, 13.0]:
			for z in [-35.0, 35.0]:
				B.cyl(parent, Vector3(x, 1.8, z), 1.0, 3.6, B.mat("#77878a"), true)
	for x in [-5.0, 5.0]: B.box(parent, Vector3(x, 2.2, 60), Vector3(0.35, 4.4, 0.4), B.mat("#68513b"))
	B.box(parent, Vector3(0, 4.5, 60), Vector3(10.8, 0.35, 0.5), B.mat("#68513b"))
	signboard(parent, Vector3(0, 4.5, 60.3), str(site.name).to_upper(), 0, 8.0, "settlement_entrance")
	if site.has("region") and site.kind == "city": signboard(parent, Vector3(7, 1.7, 67), "TRAVEL PLAZA / JOURNAL", 0, 4)
	if world != null and site.id == "bellcrown" and world.get("atlas") != null: MosswakeDistrict.build(world, parent)


static func forge(parent: Node3D, p: Vector3, title: String = "FORGE") -> Node3D:
	var existing = load("res://scripts/shop_architecture.gd").find_shop(parent, "smith")
	if existing != null: return existing
	return building(parent, p, 7.2, 6.2, "#b6ad98", "#59636c", PI if p.x < 0 else 0, title, "smithy_" + title.to_snake_case(), "workshop", int(parent.get_meta("region", 9)))

static func outcrop(parent: Node3D, p: Vector3, size: Vector3, variant: int, material: Material, angles: Vector3 = Vector3.ZERO, collision: bool = true) -> void:
	var key: String = "frontier_outcrop_" + str(variant % 3)
	if not B.geometry_cache.has(key):
		var lower := PackedVector3Array()
		var upper := PackedVector3Array()
		for i in range(7):
			var angle: float = float(i) * TAU / 7.0
			var radius: float = 0.46 + sin(i * 4.1 + variant) * 0.055
			lower.append(Vector3(cos(angle) * radius, -0.42 + sin(i * 2.4 + variant) * 0.06, sin(angle) * radius))
			upper.append(Vector3(cos(angle + 0.16) * radius * 0.81, 0.25 + sin(i * 1.8 + variant) * 0.1, sin(angle + 0.16) * radius * 0.81))
		var faces: Array[PackedVector3Array] = [lower]
		var peak := Vector3(0.09, 0.5, -0.07)
		for i in range(7):
			var next: int = (i + 1) % 7
			faces.append(PackedVector3Array([lower[i], lower[next], upper[next], upper[i]]))
			faces.append(PackedVector3Array([upper[i], upper[next], peak]))
		B.geometry_cache[key] = B._flat_geometry(faces)
	var geometry: ArrayMesh = B.geometry_cache[key]
	B.mesh(parent, geometry, material, p, size).rotation = angles
	if collision:
		var points := PackedVector3Array()
		for vertex in geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: points.append(vertex * size)
		var shape := ConvexPolygonShape3D.new(); shape.points = points
		B.solid(parent, p, shape).rotation = angles

static func cave_mouth(parent: Node3D, crypt: bool, world = null) -> void:
	var stone = B.world_surface("stone", "#7d8377" if crypt else "#6a756c")
	if not crypt:
		load("res://scripts/cave_entrance.gd").build(parent, Color("#6a756c"), 0, world)
		for side in [-1, 1]: lantern(parent, Vector3(side * 2.4, 1.8, 1.2), false, true)
		signboard(parent, Vector3(4.8, 1.8, 3.4), "EMBERVEIN CAVE & MINE", -0.2, 3.4, "cave_entrance")
		return
	for side in [-1.0, 1.0]:
		B.beveled_box(parent, Vector3(side * 2.3, 1.9, -0.5), Vector3(1.8, 3.8, 3), stone, true)
		if not crypt:
			B.box(parent, Vector3(side * 1.3, 1.3, 0.7), Vector3(0.23, 2.6, 0.25), B.mat("#78543a"), true)
	B.beveled_box(parent, Vector3(0, 3.5, -0.5), Vector3(5.2, 1, 3), stone, true)
	B.box(parent, Vector3(0, 3, 0.6), Vector3(3, 0.3, 0.3), B.mat("#ad9871"))

	B.box(parent, Vector3(0, 1.5, -1.9), Vector3(2.8, 3, 0.1), B.mat("#253637"))
	lantern(parent, Vector3(2.1, 2, 1), false)




static func deep_layout(id: String, seed_value: int = 0) -> Dictionary:
	if seed_value != 0 and FileAccess.file_exists("res://assets/world/fixed/map.bin"):
		return preload("res://scripts/fixed_world.gd").deep_plan(id)
	var rooms: Array = []
	var links: Array = []
	if id == "mine":
		rooms = [
			{"id": "mouth", "title": "MINER'S THRESHOLD", "p": Vector2(0, 0), "size": Vector2(14, 14), "ceiling": 5.6},
			{"id": "fork", "title": "THE LANTERN FORK", "p": Vector2(0, -16), "size": Vector2(15, 18), "ceiling": 6.0},
			{"id": "echo", "title": "ECHO BASIN", "p": Vector2(0, -34), "size": Vector2(20, 19), "ceiling": 7.5},
			{"id": "crystal", "title": "GLASSROOT GROTTO", "p": Vector2(21, -14), "size": Vector2(23, 17), "ceiling": 6.8},
			{"id": "shaft", "title": "THE GREAT AIR SHAFT", "p": Vector2(30, -38), "size": Vector2(22, 27), "ceiling": 12.0},
			{"id": "sump", "title": "THE JADE SUMP", "p": Vector2(24, -62), "size": Vector2(20, 18), "ceiling": 6.2},
			{"id": "rift", "title": "CINDER RIFT", "p": Vector2(0, -61), "size": Vector2(22, 23), "ceiling": 7.0},
			{"id": "fungus", "title": "PALECAP HOLLOW", "p": Vector2(-24, -34), "size": Vector2(21, 20), "ceiling": 7.3},
			{"id": "secret", "title": "THE FORGOTTEN WORKINGS", "p": Vector2(-35, -59), "size": Vector2(17, 19), "ceiling": 6.0},
			{"id": "heart", "title": "HEART OF EMBERVEIN", "p": Vector2(0, -90), "size": Vector2(31, 29), "ceiling": 9.0}]
		links = [["mouth", "fork"], ["fork", "echo"], ["fork", "crystal"], ["crystal", "shaft"], ["shaft", "echo"], ["shaft", "sump"], ["sump", "rift"], ["echo", "rift"], ["echo", "fungus"], ["fungus", "secret"], ["secret", "rift"], ["rift", "heart"]]
	else:
		rooms = [
			{"id": "vestibule", "title": "THE SILENT VESTIBULE", "p": Vector2(0, 0), "size": Vector2(14, 14), "ceiling": 5.6},
			{"id": "processional", "title": "PROCESSIONAL GALLERY", "p": Vector2(0, -16), "size": Vector2(14, 16), "ceiling": 6.0},
			{"id": "ossuary", "title": "THE OSSUARY", "p": Vector2(21, -14), "size": Vector2(20, 14), "ceiling": 5.2},
			{"id": "bells", "title": "HALL OF FALLEN BELLS", "p": Vector2(0, -36), "size": Vector2(20, 20), "ceiling": 8.0},
			{"id": "ember", "title": "CHAPEL OF EMBERS", "p": Vector2(-24, -35), "size": Vector2(16, 18), "ceiling": 7.0},
			{"id": "cloister", "title": "THE BROKEN CLOISTER", "p": Vector2(-24, -61), "size": Vector2(18, 20), "ceiling": 6.0},
			{"id": "scriptorium", "title": "THE ECHO SCRIPTORIUM", "p": Vector2(23, -39), "size": Vector2(19, 18), "ceiling": 6.5},
			{"id": "cistern", "title": "CISTERN OF TIDES", "p": Vector2(25, -64), "size": Vector2(20, 20), "ceiling": 6.5},
			{"id": "reliquary", "title": "THE INNER RELIQUARY", "p": Vector2(0, -66), "size": Vector2(18, 20), "ceiling": 7.0},
			{"id": "gate", "title": "THE THREEFOLD GATE", "p": Vector2(0, -85), "size": Vector2(12, 14), "ceiling": 6.0},
			{"id": "throne", "title": "THE BELLKEEPER'S COURT", "p": Vector2(0, -111), "size": Vector2(29, 29), "ceiling": 10.0},
			{"id": "vault", "title": "THE DAWN VAULT", "p": Vector2(31, -111), "size": Vector2(18, 18), "ceiling": 7.0}]
		links = [["vestibule", "processional"], ["processional", "bells"], ["processional", "ossuary"], ["ossuary", "scriptorium"], ["scriptorium", "cistern"], ["cistern", "reliquary"], ["bells", "ember"], ["ember", "cloister"], ["cloister", "reliquary"], ["bells", "reliquary"], ["reliquary", "gate"], ["gate", "throne"], ["throne", "vault"]]
	if seed_value != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("living-depths:%s:%s" % [seed_value, id])


		for room in rooms:
			if room.id in ["mouth", "vestibule", "gate", "throne", "vault", "heart"]: continue
			room.size += Vector2(rng.randf_range(0.0, 5.0), rng.randf_range(0.0, 4.0))
		var count: int = rng.randi_range(3, 5) if id == "mine" else rng.randi_range(3, 4)
		for index in range(count):
			var branch_id: String = "frontier_" + str(index)
			var at: Vector2
			var anchor: String
			if id == "mine":
				at = Vector2(-52.0 - rng.randf_range(0, 7), -15.0 - index * 18.0 + rng.randf_range(-3, 3))
				anchor = "fungus" if index < 2 else "secret" if index == 2 else "rift" if index == 3 else "heart"
			else:
				var side: float = -1.0 if index < 2 else 1.0
				at = Vector2(side * (49.0 + rng.randf_range(0, 5)), -34.0 - float(index % 2) * 28.0 + rng.randf_range(-3, 3))
				anchor = ("ember" if index == 0 else "cloister") if index < 2 else ("scriptorium" if index == 2 else "cistern")
			rooms.append({"id": branch_id, "title": (["THE COPPER DRIFTS", "ROOTBOUND GALLERY", "THE WANDERER'S HOLLOW", "THE OLD QUARRY", "THE DEEPER WORKINGS"] if id == "mine" else ["THE FORGOTTEN ARCHIVE", "CLOISTER OF ASH", "THE LAMPWARDEN'S CHAMBER", "THE WATER COURT"])[index], "p": at, "size": Vector2(rng.randf_range(14.0, 23.0), rng.randf_range(13.0, 20.0)), "ceiling": rng.randf_range(5.8, 8.2), "optional": true})
			links.append([anchor, branch_id])
			if index > 0 and (id == "mine" or index % 2 == 1): links.append(["frontier_" + str(index - 1), branch_id])
	return {"rooms": rooms, "links": links}

static func _deep_cells(id: String, layout: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	var centers: Dictionary = {}
	for room in layout.rooms:
		centers[room.id] = room.p
		var half: Vector2 = room.size * 0.5
		for z in range(floori(room.p.y - half.y), ceili(room.p.y + half.y)):
			for x in range(floori(room.p.x - half.x), ceili(room.p.x + half.x)):
				var q: Vector2 = (Vector2(x + 0.5, z + 0.5) - room.p) / half


				var edge: float = 1.0 + 0.07 * sin(q.y * 7.0 + room.p.x) + 0.04 * sin(q.x * 9.0)
				if id == "mine" and q.length_squared() > edge:
					continue
				var key := Vector2i(x, z)
				cells[key] = maxf(float(cells.get(key, 0.0)), float(room.ceiling))
	for link in layout.links:
		var a: Vector2 = centers[link[0]]
		var b: Vector2 = centers[link[1]]
		var radius: float = 2.6 if id == "mine" else 2.4
		for z in range(floori(minf(a.y, b.y) - radius), ceili(maxf(a.y, b.y) + radius)):
			for x in range(floori(minf(a.x, b.x) - radius), ceili(maxf(a.x, b.x) + radius)):
				var p := Vector2(x + 0.5, z + 0.5)
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= radius:
					var key := Vector2i(x, z)
					cells[key] = maxf(float(cells.get(key, 0.0)), 4.8)


	for z in range(-35, 7):
		for x in range(-7, 7):
			var key := Vector2i(x, z)
			cells[key] = maxf(float(cells.get(key, 0.0)), 5.6)
	for z in range(-21, -7):
		for x in range(7, 25):
			var key := Vector2i(x, z)
			cells[key] = maxf(float(cells.get(key, 0.0)), 5.6)
	return cells

static func _cell_rectangles(cells: Dictionary, roof: bool) -> Array:
	var rows: Dictionary = {}
	for key in cells:
		if not rows.has(key.y): rows[key.y] = []
		rows[key.y].append(key.x)
	var ordered: Array = rows.keys()
	ordered.sort()
	var active: Dictionary = {}
	var rectangles: Array = []
	var previous := -10000
	for z in ordered:
		if z != previous + 1:
			rectangles.append_array(active.values())
			active.clear()
		previous = z
		var xs: Array = rows[z]
		xs.sort()
		var spans: Array = []
		var start: int = xs[0]
		var last: int = start
		var height: float = float(cells[Vector2i(start, z)]) if roof else 0.0
		for x in xs.slice(1):
			var h: float = float(cells[Vector2i(x, z)]) if roof else 0.0
			if x != last + 1 or not is_equal_approx(h, height):
				spans.append({"start": start, "end": last + 1, "height": height})
				start = x; height = h
			last = x
		spans.append({"start": start, "end": last + 1, "height": height})
		var next: Dictionary = {}
		for span in spans:
			var tag := "%s:%s:%s" % [span.start, span.end, span.height]
			if active.has(tag):
				var entry: Dictionary = active[tag]
				entry.rect.size.y += 1
				next[tag] = entry
				active.erase(tag)
			else:
				next[tag] = {"rect": Rect2i(span.start, z, span.end - span.start, 1), "height": span.height}
		rectangles.append_array(active.values())
		active = next
	rectangles.append_array(active.values())
	return rectangles

static func _deep_shell(n: Node3D, id: String, cells: Dictionary) -> void:
	var architecture = load("res://scripts/interior_architecture.gd")
	load("res://scripts/interior_surfaces.gd").build(n, cells, 1.0, func (_p: Vector2) -> float: return 0.0, func (p: Vector2) -> float: return float(cells.get(Vector2i(floori(p.x), floori(p.y)), 5.6)), architecture.stone(9, true, false, id == "mine"), architecture.stone(9, false, false, id == "mine"), id == "mine")
	if id == "dungeon":
		var original = deep_layout(id, 64127); var rooms = []; var indices = {}; var links = []
		for room in original.rooms:
			indices[room.id] = rooms.size(); var copy = room.duplicate(true); copy.level = 0; rooms.append(copy)
		for link in original.links: links.append([indices[link[0]], indices[link[1]]])
		architecture.portals(n, {"rooms": rooms, "links": links}, func (_p: Vector2, _level: int) -> float: return 0.0)

static func interior(world, id: String, return_to: Vector3) -> void:
	var n := Node3D.new()
	n.name = id.capitalize() + "Interior"
	n.position = INTERIORS[id]
	world.locations.add_child(n)
	n.set_meta("interior", id)
	var layout := deep_layout(id, world.state.seed_value)
	var cells := _deep_cells(id, layout)

	var branch_rng := RandomNumberGenerator.new()
	branch_rng.seed = hash("side-room:%s:%s" % [world.state.seed_value, id])
	var width := branch_rng.randf_range(14.0, 18.0)
	var old_floor := BoxShape3D.new()
	old_floor.size = Vector3(width, 0.6, 14)
	B.solid(n, Vector3(7.0 + width * 0.5, -0.3, -14), old_floor)
	_deep_shell(n, id, cells)
	var centers: Dictionary = {}
	for room in layout.rooms:
		centers[room.id] = room.p
		var space := Node3D.new()
		space.name = room.id.capitalize() + "Space"
		space.position = Vector3(room.p.x, 0, room.p.y)
		n.add_child(space)
		space.add_to_group("deep_space")
		space.set_meta("room_id", room.id)
		space.set_meta("interior", id)
		space.set_meta("title", room.title)
		space.set_meta("size", room.size)
		space.set_meta("ceiling", room.ceiling)
		var neighbors: Array = []
		for link in layout.links:
			if link[0] == room.id: neighbors.append(link[1])
			if link[1] == room.id: neighbors.append(link[0])
		space.set_meta("neighbors", neighbors)
		_deep_room_art(n, id, room, world.state.seed_value)
	for link in layout.links:
		var edge := Node3D.new()
		edge.name = link[0] + "To" + link[1].capitalize()
		n.add_child(edge)
		edge.add_to_group("deep_connection")
		edge.set_meta("interior", id)
		edge.set_meta("from", link[0])
		edge.set_meta("to", link[1])
		edge.set_meta("path", PackedVector3Array([Vector3(centers[link[0]].x, 0, centers[link[0]].y), Vector3(centers[link[1]].x, 0, centers[link[1]].y)]))
	_deep_contents(world, n, id)
	entrance(n, "exit_" + id, Vector3(0, 0.2, 5.5), return_to, "The Open Frontier", "Leave " + ("Embervein Cave & Mine" if id == "mine" else "the Bellkeeper's Crypt"))
	B.box(n, Vector3(0, 2, 6.65), Vector3(2.7, 3.5, 0.1), B.mat("#c1d8b9", 0, 0.4))
	signboard(n, Vector3(0, 3.4, 5.9), "SURFACE RETURN", PI, 3.4)
	B.batch_static(n)
	cull_art(n, 145.0)

static func _deep_room_art(n: Node3D, id: String, room: Dictionary, seed_value: int) -> void:
	var L = load("res://scripts/landmark_art.gd")
	var p := Vector3(room.p.x, 0, room.p.y)
	var half: Vector2 = room.size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("deep-art:%s:%s:%s" % [seed_value, id, room.id])
	var stone := B.world_surface("stone", "#617b6c" if id == "mine" else "#515965")
	var edge := B.world_surface("stone", "#9eac8b" if id == "mine" else "#aca68f")
	var brass := B.mat("#c4a46a", 0.35)
	var timber := B.world_surface("timber", "#73543b")

	lantern(n, p + Vector3(-half.x * 0.55, 2.8, half.y * 0.53), false, true)
	if id == "mine":
		for i in range(9):
			var angle := float(i) * TAU / 9.0 + 0.15
			var rim := p + Vector3(cos(angle) * half.x * 0.81, 0, sin(angle) * half.y * 0.81)
			L.module(n, "terrain_mdvl_nature_rocks_01", rim, Vector3(rng.randf_range(0.7, 1.3), 0.6, rng.randf_range(0.8, 1.5)), angle)
			var tooth = L.module(n, "u29_nature_rock_tallb", rim + Vector3.UP * (float(room.ceiling) - 0.1), Vector3(1.1, 1.8, 1.3))
			tooth.rotation.z = PI
			if room.id in ["crystal", "heart", "sump"]:
				var crystal = L.module(n, "zappy_crystal", rim, Vector3(0.5, 1.8, 0.55)); crystal.rotation.z = 0.2 * sin(angle * 3); crystal.get_child(0).material_override = B.mat("#80dac4", 0.25, 0.25)
		if room.id in ["mouth", "fork", "secret"]:
			for side in [-1.0, 1.0]:
				L.beam(n, p + Vector3(side * 4.9, 0, 3.4), p + Vector3(side * 4.9, 4.2, 3.4), 0.32)
				L.beam(n, p + Vector3(side * 4.9, 3.0, 3.4), p + Vector3(side * 3.8, 4.2, 3.4), 0.26)
			L.beam(n, p + Vector3(-5.1, 4.25, 3.4), p + Vector3(5.1, 4.25, 3.4), 0.35)
			for z in [-3.0, 0.0, 3.0]:
				L.module(n, "resource_wood_planks_stack_small", p + Vector3(-4, 0, z), Vector3(1.5, 0.05, 0.2))
			L.rails(n, p + Vector3(-4, 0.035, 0))
		if room.id == "fungus":
			for i in range(12):
				var angle := float(i) * TAU / 12
				var rim := p + Vector3(cos(angle) * half.x * 0.7, 0, sin(angle) * half.y * 0.7)
				L.module(n, "qnat_mushroom_common", rim, Vector3(1.1, 1.1, 1.0))
		if room.id == "sump":


			B.cyl(n, p + Vector3(3, 0.012, 3), 2.8, 0.018, B.mat("#4f9a90", 0.4, 0.12))
		if room.id == "shaft":


			var ramp_length := sqrt(13.0 * 13.0 + 3.3 * 3.3)
			var ramp := B.box(n, p + Vector3(6, 1.48, 1), Vector3(3.0, 0.35, ramp_length), timber)
			ramp.rotation.x = atan2(3.3, 13.0)
			var sh := BoxShape3D.new(); sh.size = Vector3(3, 0.35, ramp_length)
			var body := B.solid(n, p + Vector3(6, 1.48, 1), sh)
			body.rotation.x = ramp.rotation.x
			B.box(n, p + Vector3(5.6, 3.1, -7), Vector3(5.5, 0.35, 3.4), timber, true)
			for x in [3.0, 8.1]:
				B.box(n, p + Vector3(x, 1.5, -7), Vector3(0.3, 3, 0.3), timber)
				B.branch(n, p + Vector3(x, 3.3, -7), p + Vector3(x, 9, -7), 0.05, B.mat("#b39c76"), 1)
			B.ring(n, p + Vector3(0, 10.8, 0), 3.2, 0.25, B.mat("#a4c3ab", 0, 0.15))
			signboard(n, p + Vector3(2.5, 2.4, 6.5), "UPPER WORKINGS  →", 0, 3.2)
	else:
		var architecture := Node3D.new()
		architecture.name = room.id.capitalize() + "Architecture"
		n.add_child(architecture)
		architecture.add_to_group("crypt_architecture")
		for side in [-1.0, 1.0]:
			for z in [-half.y * 0.7, half.y * 0.7]:
				var foot := p + Vector3(side * half.x * 0.82, 0, z)
				L.module(architecture, "dungeon_pillar_decorated", foot, Vector3(1.1, 4.45, 1.1))
				var arc := [foot + Vector3.UP * 4.45, p + Vector3(side * half.x * 0.55, room.ceiling - 1.1, z), p + Vector3(0, room.ceiling - 0.35, z)]
				for j in range(arc.size() - 1): stone_link(architecture, arc[j], arc[j + 1], edge)
			B.box(architecture, p + Vector3(side * (half.x - 0.4), 2.5, 0), Vector3(0.06, 2.0, 1.3), B.mat("#7d4c61"))
			for tier in [0.8, 1.8, 3.7]:
				B.box(architecture, p + Vector3(side * (half.x - 0.25), tier, 0), Vector3(0.05, 0.04, room.size.y - 1), edge)
		for z in [-half.y + 1, half.y - 1]:
			B.box(architecture, p + Vector3(0, 0.025, z), Vector3(room.size.x - 1, 0.05, 0.15), brass)
		if room.id in ["ossuary", "cloister", "reliquary"]:
			for side in [-1.0, 1.0]:
				var tomb := p + Vector3(side * (half.x - 2), 0, -6.0 if room.id == "reliquary" else 2.5)
				L.prop(architecture, "coffin", tomb, Vector3(1.65, 1.16, 3.0))
				load("res://scripts/world_overhaul.gd").support_box(architecture, tomb + Vector3.UP * 0.45, Vector3(1.5, 0.9, 2.8))
		if room.id in ["bells", "throne"]:
			for side in [-1.0, 1.0]:
				var bell := p + Vector3(side * (half.x - 3), 4.7, -3.3)
				B.branch(architecture, bell + Vector3.UP * 0.7, bell + Vector3.UP * 2.2, 0.05, brass, 1)
				L.prop(architecture, "bell", bell - Vector3.UP * 0.65, Vector3(1.7, 1.3, 1.7))
		if room.id == "scriptorium":
			for side in [-1.0, 1.0]:
				L.module(architecture, "qprop_bookcase_2", p + Vector3(side * (half.x - 1), 0, 0), Vector3(5, 2.6, 0.7), side * PI * 0.5)
		if room.id == "cistern":
			for side in [-1.0, 1.0]: B.cyl(architecture, p + Vector3(side * 6, 0.015, 0), 2.0, 0.025, B.mat("#487d82", 0.3, 0.1))
		if room.id == "throne":
			for side in [-1.0, 1.0]:
				B.beveled_box(architecture, p + Vector3(side * 7.5, 2.0, 5), Vector3(1.5, 4, 1.5), stone, true)
				B.box(architecture, p + Vector3(side * 7.5, 4.15, 5), Vector3(2.0, 0.3, 2.0), brass)
			B.beveled_box(architecture, p + Vector3(0, 0.25, -10), Vector3(7, 0.5, 3), edge, true)
			L.prop(architecture, "throne", p + Vector3(0, 0.5, -10.8), Vector3(2.8, 4.1, 1.9))

	signboard(n, p + Vector3(0, 3.65, half.y * 0.7), room.title, 0, 4.6)

static func _deep_marker(n: Node3D, id: String, group: String, p: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.name = id
	marker.position = p
	marker.set_meta("id", id + "_spawn" if group == "deep_boss_spawn" else id)
	if group == "deep_boss_spawn": marker.set_meta("boss_id", id)
	n.add_child(marker)
	marker.add_to_group(group)
	return marker

static func _deep_cache(n: Node3D, id: String, p: Vector3, rewards: Dictionary, label: String) -> void:
	var cache := interaction(n, id, "deep_cache", label, p)
	cache.set_meta("rewards", rewards)
	cache.add_to_group("deep_cache")
	cache.add_to_group("batch_dynamic")
	load("res://scripts/treasure_art.gd").build(cache).position.y = -0.5
	var support = BoxShape3D.new(); support.size = Vector3(1.45, 0.85, 1.05)
	B.solid(cache, Vector3.ZERO, support)

static func _deep_contents(world, n: Node3D, id: String) -> void:
	var layout := deep_layout(id, world.state.seed_value)
	for i in range(layout.rooms.size()):
		var room: Dictionary = layout.rooms[i]
		var p := Vector3(room.p.x, 0, room.p.y)
		var item := "iron" if id == "mine" and i % 3 != 0 else "crystal"
		material_node(world, n, "deep_" + id + "_vein_" + room.id, item, 4 if item == "iron" else 3, p + Vector3(-room.size.x * 0.34 if room.get("optional", false) else -room.size.x * 0.28, 0.35, room.size.y * 0.22 if room.get("optional", false) else -room.size.y * 0.27))
		if i % 3 == 1: material_node(world, n, "deep_" + id + "_herb_" + room.id, "herb", 3, p + Vector3(room.size.x * 0.27, 0.15, room.size.y * 0.23))
		if room.get("optional", false):
			_deep_cache(n, "deep_cache_" + id + "_" + room.id, p + Vector3(-room.size.x * 0.34, 0.5, -room.size.y * 0.22), {"shard": 10, "iron": 3, "herb": 2}, "Search the forgotten expedition chest")
	var guards: Array = [Vector3(1, 0.2, -21), Vector3(20, 0.2, -17), Vector3(-23, 0.2, -36), Vector3(27, 0.2, -61), Vector3(-1, 0.2, -65)] if id == "mine" else [Vector3(0, 0.2, -22), Vector3(23, 0.2, -18), Vector3(-24, 0.2, -37), Vector3(24, 0.2, -42), Vector3(-24, 0.2, -63), Vector3(25, 0.2, -68), Vector3(1, 0.2, -69)]
	for i in range(guards.size()):

		var guard_id := id + "_guardian_" + str(i + 1)
		_deep_marker(n, guard_id, "frontier_enemy_spawn", guards[i])
	if id == "mine":
		_deep_cache(n, "mine_treasure", Vector3(-37, 0.5, -62), {"relic": 2, "shard": 16, "tonic": 2, "iron": 5}, "Search the forgotten miner's cache")
		_deep_cache(n, "deep_cache_shaft", Vector3(35.6, 3.75, -45), {"crystal": 5, "shard": 20, "ancient_core": 1}, "Open the upper-workings strongbox")
		_deep_cache(n, "deep_cache_sump", Vector3(28, 0.5, -66), {"herb": 5, "tonic": 2, "shard": 12}, "Search the sump expedition pack")
		_deep_cache(n, "deep_reward_embermaw", Vector3(5, 0.5, -97), {"ancient_core": 2, "crystal": 8, "iron": 12, "tonic": 3, "shard": 60}, "Claim Embermaw's ancient heartstone")
		var boss := _deep_marker(n, "deep_boss_embermaw", "deep_boss_spawn", Vector3(0, 0.15, -90))
		boss.set_meta("interior", "mine")
		boss.set_meta("arena_radius", 11.0)
		boss.set_meta("display_name", "Embermaw, Heart of the Mine")
		for trap in [{"id": "deep_embers_shaft", "p": Vector3(30, 0.03, -38)}, {"id": "deep_embers_rift", "p": Vector3(-3, 0.03, -58)}]:
			var mark := _deep_marker(n, trap.id, "deep_trap_spawn", trap.p)
			mark.set_meta("trap_type", "embers")
	else:
		for seal in [{"id": "deep_seal_ember", "p": Vector3(-27, 0.55, -39), "title": "Ember seal"}, {"id": "deep_seal_echo", "p": Vector3(26, 0.55, -43), "title": "Echo seal"}, {"id": "deep_seal_tide", "p": Vector3(29, 0.55, -68), "title": "Tide seal"}]:
			var node := interaction(n, seal.id, "deep_seal", "Awaken the " + seal.title, seal.p)
			node.add_to_group("deep_seal")
			node.add_to_group("batch_dynamic")
			B.beveled_box(node, Vector3(0, -0.16, 0), Vector3(1.2, 0.8, 1.1), B.mat("#676c76"), true)
			B.ring(node, Vector3(0, 0.72, 0), 0.55, 0.12, B.mat("#bf9a63", 0.4)).rotation.x = PI / 2
			var rune := B.facet(node, Vector3(0, 0.74, 0), Vector3(0.36, 0.7, 0.16), B.mat("#8dcabb", 0, 0.3))
			rune.name = "Rune"
			signboard(node, Vector3(0, 1.65, 0), seal.title.to_upper(), 0, 2.8)
		var gate := interaction(n, "deep_gate_bells", "deep_gate", "The three seals hold this gate", Vector3(0, 0.65, -94))
		gate.add_to_group("deep_gate")
		gate.add_to_group("batch_dynamic")
		gate.set_meta("requires", "seals")
		var vault_gate := interaction(n, "deep_gate_vault", "deep_gate", "The Bellkeeper guards the Dawn Vault", Vector3(18, 0.65, -111))
		vault_gate.rotation.y = PI / 2
		vault_gate.add_to_group("deep_gate")
		vault_gate.add_to_group("batch_dynamic")
		vault_gate.set_meta("requires", "boss")
		_deep_cache(n, "dungeon_treasure", Vector3(-28, 0.5, -65), {"relic": 2, "tonic": 2, "shard": 20}, "Search the cloister reliquary")
		_deep_cache(n, "deep_cache_scriptorium", Vector3(28, 0.5, -35), {"crystal": 4, "herb": 4, "shard": 18}, "Open the scribe's reliquary")
		_deep_cache(n, "deep_vault_dawn", Vector3(32, 0.6, -114), {"ancient_core": 3, "relic": 6, "shard": 120}, "Claim the Dawn Blade and the Bellkeeper's hoard")
		var boss := _deep_marker(n, "deep_boss_bellkeeper", "deep_boss_spawn", Vector3(0, 0.15, -111))
		boss.set_meta("interior", "dungeon")
		boss.set_meta("arena_radius", 11.0)
		boss.set_meta("display_name", "The Bellkeeper, Warden of Dawn")
		for trap in [{"id": "deep_spikes_gallery", "p": Vector3(0, 0.03, -29), "type": "spikes"}, {"id": "deep_spikes_cloister", "p": Vector3(-24, 0.03, -50), "type": "spikes"}, {"id": "deep_bell_cistern", "p": Vector3(24, 0.03, -62), "type": "bell"}, {"id": "deep_bell_reliquary", "p": Vector3(0, 0.03, -65), "type": "bell"}]:
			var mark := _deep_marker(n, trap.id, "deep_trap_spawn", trap.p)
			mark.set_meta("trap_type", trap.type)

static func stone_link(n: Node3D, start: Vector3, end: Vector3, material: Material) -> void:
	var delta = end - start
	var block = B.beveled_box(n, (start + end) / 2, Vector3(0.3, delta.length() + 0.09, 0.46), material)
	block.quaternion = Quaternion(Vector3.UP, delta.normalized())

static func material_node(world, parent: Node3D, id: String, item: String, amount: int, p: Vector3) -> void:
	if world.state.taken.has(id):
		return
	var n: Node3D
	if item in ["stone", "iron", "crystal"]:
		n = Mineable.new()
		n.world = world
		n.position = p
		n.set_meta("id", id)
		parent.add_child(n)
		var shape = SphereShape3D.new()
		shape.radius = 0.55
		n.collider = B.solid(n, Vector3(0, 0.15, 0), shape)
	else:
		n = interaction(parent, id, "material", "Gather " + item.capitalize(), p)
	n.set_meta("item", item)
	n.set_meta("amount", amount)
	if item in ["stone", "iron", "crystal"]:
		n.set_meta("label", "Mine " + item.capitalize())
	if item in ["herb", "iron", "stone", "crystal"]:
		var model = ItemModels.build(n, item)
		if item == "crystal":
			model.scale = Vector3(3.0, 2.2, 3.4)
			model.position.y = -0.28
		elif item != "herb":
			model.scale = Vector3(3.0, 2.4, 3.0) if item == "iron" else Vector3(3.7, 3.9, 4.3)
			model.position.y = -0.15
		if item == "stone": preload("res://scripts/loose_stone_carry.gd").configure_round(n, model)
	else:
		B.ball(n, Vector3(0, -0.1, 0), Vector3(1.2, 0.7, 0.95), B.mat("#505d5d"))
		for i in range(3):
			B.facet(n, Vector3((i - 1) * 0.26, 0.15 + i * 0.09, 0), Vector3(0.28, 0.9, 0.35), B.mat("#9ee0d2", 0.4, 0.15))

static func step_settlement(world) -> void:
	if world.settlement_jobs.is_empty(): return
	var job: Dictionary = world.settlement_jobs.front()
	if not is_instance_valid(job.root) or job.root.is_queued_for_deletion():
		world.settlement_jobs.pop_front()
		return
	if job.index < job.plots.size():
		_city_plot(world, job.root, job.site, job.plots[job.index], job.index)
		job.index += 1
	else:
		_city_civic(job.root, job.site, world)
		load("res://scripts/building_paths.gd").complete(world, job.root, job.site, job.plots)
		B.batch_static(job.root)
		cull_art(job.root, 360.0 if world.get("atlas") != null else 180.0)
		load("res://scripts/district_batches.gd").build(job.root, "civic-" + str(job.site.id))
		job.root.set_meta("streaming", false)
		world.settlement_jobs.pop_front()
