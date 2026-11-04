extends RefCounted

const B = preload("res://scripts/build.gd")

static func table(parent: Node3D, p: Vector3, size: Vector2, wood: Material) -> void:
	if load("res://scripts/world_overhaul.gd").table(parent, p, size): return
	B.box(parent, p + Vector3.UP * 0.85, Vector3(size.x, 0.16, size.y), wood, true)
	for x in [-0.4, 0.4]:
		for z in [-0.35, 0.35]: B.box(parent, p + Vector3(x * size.x, 0.4, z * size.y), Vector3(0.12, 0.8, 0.12), wood)
static func shelf(parent: Node3D, p: Vector3, width: float, wood: Material, books: bool = true) -> void:
	if load("res://scripts/world_overhaul.gd").shelf(parent, p, width, books): return
	for side in [-1, 1]: B.box(parent, p + Vector3(side * width * 0.5, 1.15, 0), Vector3(0.15, 2.3, 0.45), wood, true)
	B.box(parent, p + Vector3(0, 1.15, -0.2), Vector3(width, 2.3, 0.08), wood)
	for row in range(4):
		B.box(parent, p + Vector3(0, 0.18 + row * 0.58, 0), Vector3(width, 0.1, 0.45), wood)
		for book in range(6):
			var at = p + Vector3(-width * 0.4 + book * width * 0.16, 0.43 + row * 0.58, 0)
			if books: B.box(parent, at, Vector3(width * 0.13, 0.37 + 0.04 * (book % 2), 0.28), B.mat(["#876663", "#729082", "#bfab78", "#667d91"][posmod(row + book, 4)]))
			else: B.cyl(parent, at, 0.14, 0.3, B.mat("#b2a584"))

static func furnish(parent: Node3D, width: float, depth: float, purpose: String, region: int, weathered: bool = false, add_rug: bool = true) -> void:
	var P = load("res://scripts/locations.gd")
	parent.add_to_group("furnished_space"); parent.set_meta("purpose", purpose)
	var wood = B.world_surface("timber", "#675247" if weathered else "#967453")
	var cloth = B.world_surface("cloth", ["#728b74", "#b18a6c", "#9aa67c", "#ad8063", "#766458", "#6b6178", "#8da3ae"][clampi(region - 9, 0, 6)])
	var left = -width * 0.5 + 1.4; var back = -depth * 0.5 + 1.1
	var fixtures: Array[String] = []
	if add_rug:
		B.box(parent, Vector3(0, 0.04, -0.7), Vector3(minf(width - 2, 4), 0.025, minf(depth - 2, 3.4)), cloth)
		fixtures.append("rug")
	if any_word(purpose, ["great hall", "ballroom", "gallery", "council", "throne", "landing", "entrance hall", "crown hall"]):
		var length = minf(6, depth - 2)
		table(parent, Vector3(-width * 0.2, 0, -0.3), Vector2(3, length), wood)
		for side in [-1, 1]:
			for z in [-length * 0.25, length * 0.25]: P.bench(parent, Vector3(-width * 0.2 + side * 2, 0, z), -side * PI * 0.5)
		B.box(parent, Vector3(-width * 0.2, 0.96, -0.3), Vector3(1.8, 0.025, length * 0.6), cloth)
		fixtures.append_array(["banquet table", "hall seating", "table runner"])
	elif any_word(purpose, ["tomb", "pyramid", "crypt", "ceremony", "chapel", "temple"]):
		var stone = B.world_surface("stone", "#b6a280" if region == 12 else "#87818e")
		B.box(parent, Vector3(left, 0.45, back + 1), Vector3(1.8, 0.9, 3.0), stone, true)
		B.box(parent, Vector3(left, 0.98, back + 1), Vector3(2, 0.18, 3.2), stone)
		for side in [-1, 1]: B.cyl(parent, Vector3(side * (width * 0.5 - 1), 1.8, back), 0.35, 3.6, stone)
		for i in range(3): B.cyl(parent, Vector3(width * 0.28 + i * 0.16, 0.4, back + 1.2), 0.22, 0.8, B.mat("#ad9473"), false, 0.14)
		fixtures.append_array(["carved stone monument", "columns", "ceremonial jars"])
	elif any_word(purpose, ["library", "archive", "study", "map", "observatory", "instrument"]):
		for side in [-1, 1]: shelf(parent, Vector3(side * (width * 0.5 - 1.6), 0, back + 0.35), 2.4, wood, true)
		table(parent, Vector3(-width * 0.22, 0, -0.4), Vector2(2.5, 1.5), wood)
		B.box(parent, Vector3(-width * 0.22, 0.96, -0.4), Vector3(1.3, 0.025, 0.8), B.mat("#d5c7a5"))
		if width > 12 and depth > 10:
			for side in [-1, 1]:
				for z in [-depth * 0.15, depth * 0.18]:
					var stack = Node3D.new(); stack.position = Vector3(side * (width * 0.5 - 0.7), 0, z); stack.rotation.y = -side * PI * 0.5; parent.add_child(stack)
					shelf(stack, Vector3.ZERO, 2.7, wood, true)
				shelf(parent, Vector3(side * width * 0.22, 0, back), 2.7, wood, true)
			table(parent, Vector3(width * 0.22, 0, 0.2), Vector2(2.5, 1.5), wood)
			B.box(parent, Vector3(width * 0.22, 0.96, 0.2), Vector3(1.2, 0.03, 0.8), B.mat("#d4c8a6"))
			fixtures.append_array(["archive stacks", "second reading table"])
		fixtures.append_array(["bookshelves", "reading table", "open book"])
	elif any_word(purpose, ["armory", "guard", "prison", "vault", "clock", "work", "kiln", "forge"]):
		shelf(parent, Vector3(left, 0, back), 2.3, wood, false)
		table(parent, Vector3(width * 0.25, 0, back + 1), Vector2(2.2, 1.4), wood)
		for i in range(4): B.branch(parent, Vector3(left - 0.8 + i * 0.5, 0.3, back + 0.3), Vector3(left - 0.8 + i * 0.5, 2.1, back + 0.3), 0.035, B.mat("#849193", 0.65))
		fixtures.append_array(["tool rack", "work table", "storage shelf"])
	elif any_word(purpose, ["kitchen", "bak", "pantry", "food", "stores", "scullery", "inn", "tavern"]):
		shelf(parent, Vector3(left, 0, back), 2.3, wood, false)
		table(parent, Vector3(width * 0.24, 0, back + 1), Vector2(2.5, 1.5), wood)
		B.box(parent, Vector3(left, 0.7, 0), Vector3(1.7, 1.4, 1.6), B.world_surface("stone", "#897967"), true)
		B.box(parent, Vector3(left, 0.65, 0.81), Vector3(0.95, 0.7, 0.03), B.mat("#383b3a"))
		for i in range(3): B.cyl(parent, Vector3(width * 0.24 - 0.7 + i * 0.65, 0.99, back + 1), 0.22, 0.13, B.mat("#d2bea0"))
		fixtures.append_array(["oven", "ingredient shelf", "dining table", "plates"])
	else:
		if not load("res://scripts/world_overhaul.gd").bed(parent, Vector3(left, 0, back + 1)):
			B.box(parent, Vector3(left, 0.28, back + 1), Vector3(1.8, 0.5, 3.2), wood, true)
			B.box(parent, Vector3(left, 0.63, back + 1), Vector3(1.7, 0.2, 3.0), cloth)
			B.box(parent, Vector3(left, 0.81, back), Vector3(1.3, 0.17, 0.65), B.mat("#d1c8af"))
		table(parent, Vector3(width * 0.27, 0, back + 1), Vector2(1.5, 1.25), wood)
		shelf(parent, Vector3(width * 0.26, 0, back - 0.1), 1.7, wood)
		fixtures.append_array(["bed", "pillow", "table", "books and belongings"])

	for z in [back + 2.1, back + 3.2]: P.bench(parent, Vector3(width * 0.28, 0, z), PI * 0.5)
	P.barrel(parent, Vector3(-width * 0.5 + 0.7, 0, depth * 0.5 - 1.1))
	B.cyl(parent, Vector3(width * 0.28, 0.99, back + 1), 0.13, 0.24, B.mat("#d2bd94"))
	P.lantern(parent, Vector3(width * 0.5 - 0.3, 2.2, 0), false)
	fixtures.append_array(["seats", "cup", "storage barrel", "lantern"])
	if region == 12:
		for i in range(3): B.ball(parent, Vector3(width * 0.5 - 0.6, 0.2 + i * 0.16, depth * 0.5 - 1.3), Vector3(1.1, 0.3, 0.8), cloth)
		fixtures.append("oasis cushions")
	if region == 15:
		B.facet(parent, Vector3(width * 0.28, 1.25, back + 1.4), Vector3(0.3, 0.6, 0.3), B.mat("#9ccac8", 0.1, 0.16)); fixtures.append("crystal craft")
	if weathered:
		for i in range(5):
			B.ball(parent, Vector3(left + i * 0.24, 0.77, back + 0.1), Vector3(0.3, 0.014, 0.22), B.mat("#9b9485"))
		var pale = B.mat("#aaa7ac")
		for i in range(1, 7): B.branch(parent, Vector3(-width * 0.5 + 0.2, 3.5, back), Vector3(-width * 0.5 + 0.2 + i * 0.25, 3.5 - i * 0.23, back), 0.009, pale, 1)
		fixtures.append_array(["dust", "cobwebs"])
	load("res://scripts/asset_dressing.gd").furnish(parent, width, depth, purpose, region)
	load("res://scripts/world_overhaul.gd").room(parent, width, depth, purpose, region, weathered)
	parent.set_meta("fixtures", fixtures)

static func any_word(value: String, words: Array) -> bool:
	for word in words:
		if word in value.to_lower(): return true
	return false
