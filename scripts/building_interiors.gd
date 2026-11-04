extends RefCounted

const B = preload("res://scripts/build.gd")
const O = preload("res://scripts/world_overhaul.gd")
const Details = preload("res://scripts/household_details.gd")
static func profile(identity: String, width: float, depth: float, purpose: String) -> Dictionary:
	var rng = RandomNumberGenerator.new(); rng.seed = hash("interior:" + identity)
	var layout = posmod(hash(identity), 4); var side = -1 if layout % 2 == 0 else 1
	var back = -1 if layout < 2 else 1
	var bed = Vector3(side * (width * 0.5 - 0.84), 0.035, back * (depth * 0.5 - 1.55) + rng.randf_range(-0.04, 0.04))
	var table = Vector3(-side * (width * 0.5 - 0.9), 0.035, -back * (depth * 0.5 - 1.3) + rng.randf_range(-0.05, 0.05))
	var shelf = Vector3(-side * (width * 0.5 - 1), 0.035, back * (depth * 0.5 - 0.5))
	return {"identity": identity, "layout": layout, "bed": bed, "table": table, "shelf": shelf, "bed_model": ["qprop_bed_twin1", "qprop_bed_twin2"][layout % 2], "tint": ["#8a9b80", "#ab867a", "#899eac", "#b39e78"][posmod(hash(identity + "cloth"), 4)], "keepsake": rng.randi_range(0, 2), "yaw": rng.randf_range(-0.3, 0.3), "purpose": purpose}
static func prop(parent: Node3D, id: String, at: Vector3, size: Vector3, yaw: float = 0, solid: bool = false) -> Node3D:
	var n = O.fit(parent, id, at, size, yaw)
	if n:
		n.set_meta("furniture_id", id); n.set_meta("furniture_size", size); n.set_meta("furniture_solid", solid)
		if solid: O.support_box(n, Vector3(0, size.y * 0.5, 0) / n.scale, size / n.scale)
	return n
static func furnish(parent: Node3D, width: float, depth: float, purpose: String, identity: String, region: int) -> void:
	var p = profile(identity, width, depth, purpose); var side = -1 if p.layout % 2 == 0 else 1
	parent.add_to_group("furnished_space"); parent.set_meta("purpose", purpose); parent.set_meta("interior_layout", p.layout); parent.set_meta("interior_profile", p)
	var shops = load("res://scripts/shop_architecture.gd")
	if shops.service(purpose):
		shops.furnish(parent, width, depth, purpose, identity, region)
		return
	var room = Node3D.new(); room.name = "IndividualInterior"; parent.add_child(room)
	var floor = 0.035; var table: Vector3 = p.table; var top = table.y + 0.78
	B.box(room, Vector3(0, 0.048, -0.3), Vector3(minf(width - 2, 3.2), 0.025, minf(depth - 2, 2.6)), B.world_surface("cloth", p.tint))
	var fixtures = ["rug", "table", "cup", "chair", "shelf", "light", "keepsake", "storage"]
	prop(room, "qprop_table_large", table, Vector3(1.3, 0.78, 1.05), 0, true)
	prop(room, "qprop_chair_1", table + Vector3(0, 0, 1.0 if table.z < 0 else -1.0), Vector3(0.58, 0.85, 0.58), PI if table.z < 0 else 0, true)
	var shelf_yaw = PI if p.shelf.z > 0 else 0.0
	prop(room, "qprop_bookcase_2" if purpose == "library" else "qprop_shelf_simple", p.shelf, Vector3(1.5, 1.85, 0.42), shelf_yaw, true)

	var stock = Details.stock(purpose, identity)
	for row in range(3):
		var y = 0.2 + row * 0.52
		B.box(room, p.shelf + Vector3(0, y, 0), Vector3(1.4, 0.07, 0.4), B.world_surface("timber", "#8f7459"))
		for col in [-1, 1]:
			var item = stock[row * 2 + (0 if col < 0 else 1)]
			var info = load("res://scripts/imported_assets.gd").entry(item).bounds_size
			var native = Vector3(info[0], info[1], info[2]); var fit = minf(0.44 / native.x, minf(0.36 / native.y, 0.28 / native.z))
			Details.place(room, item, p.shelf + Vector3(col * 0.35, y + 0.036, 0), native * fit, Vector3(0, shelf_yaw, 0))
	var cup = "qprop_cup" if not load("res://scripts/imported_assets.gd").entry("qprop_cup").is_empty() else "qprop_pot_1"
	prop(room, cup, table + Vector3(0.35, 0.782, 0), Vector3(0.17, 0.2, 0.17))
	if purpose in ["home", "inn"]:
		prop(room, p.bed_model, p.bed, Vector3(1.28, 0.9, 2.6), 0, true)
		prop(room, "qprop_nightstand_shelf", p.bed + Vector3(0, 0, 1.62 if p.bed.z < 0 else -1.62), Vector3(0.65, 0.62, 0.5), 0, true)
		prop(room, "kaykit_lantern", p.bed + Vector3(0, 0.622, 1.62 if p.bed.z < 0 else -1.62), Vector3(0.22, 0.34, 0.22))
		fixtures.append_array(["bed", "nightstand"])
	elif purpose == "bakery":
		prop(room, "qprop_cauldron", p.bed, Vector3(1.2, 1.15, 1.25), 0, true)
		fixtures.append("oven")
	elif purpose == "workshop":
		prop(room, "kaykit_anvil", p.bed, Vector3(1.15, 0.95, 0.8), 0, true)
		fixtures.append("anvil")
	elif purpose == "library":
		prop(room, "qprop_bookstand", p.bed, Vector3(0.9, 1.3, 0.65), side * 0.3, true)
		fixtures.append("reading desk")
	else:
		prop(room, "qprop_crate_wooden", p.bed, Vector3(0.95, 0.95, 0.9), p.yaw, true)
		prop(room, "qprop_bag", p.bed + Vector3(0, 0.95, 0), Vector3(0.45, 0.42, 0.45))
		fixtures.append("stock")
	var book = ["kaykit_journal_closed", "qprop_book_stack_1", "kaykit_map_rolled"][p.keepsake]
	prop(room, book, table + Vector3(-0.3, 0.782, 0.32), Vector3(0.35, 0.15, 0.28), p.yaw)
	Details.table(room, p)
	prop(room, "qprop_barrel", Vector3(side * (width * 0.5 - 0.65), floor, (-1 if p.bed.z > 0 else 1) * (depth * 0.5 - 0.65)), Vector3(0.7, 0.8, 0.7), p.yaw, true)
	var light = OmniLight3D.new(); light.position = Vector3(0, 2.35, 0); light.omni_range = 5; light.light_energy = 0.55; light.light_color = Color("#ffe1b0"); light.shadow_enabled = false; light.distance_fade_enabled = true; light.distance_fade_begin = 24; room.add_child(light)
	prop(room, "kaykit_lantern", Vector3(-side * (width * 0.5 - 0.65), floor, 0), Vector3(0.38, 0.62, 0.35), p.yaw)
	parent.set_meta("fixtures", fixtures); parent.set_meta("asset_dressing", true)
