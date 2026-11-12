extends RefCounted

const B = preload("res://scripts/build.gd")
const Items = preload("res://scripts/item_models.gd")
const L = preload("res://scripts/mosswake_layouts.gd")
const Workbench = preload("res://scripts/workbench.gd")

static func build(world, parent: Node3D) -> void:

	var P = load("res://scripts/locations.gd")
	var district = Node3D.new(); district.name = "Timbermarket"; parent.add_child(district)
	var wood = B.world_surface("timber", "#72513b"); var brass = B.mat("#b5a06b", 0.4)
	var stalls = [{"at": Vector3(-11, 0, 8), "label": "MOSS & HERBS", "items": ["herb", "tonic"], "color": "#537d62"},
		{"at": Vector3(11, 0, 8), "label": "THE BLUE BOTTLE", "items": ["mana_potion", "crystal"], "color": "#577c92"},
		{"at": Vector3(-11, 0, 17), "label": "CAMP SWEETHEARTS", "items": ["marshmallow", "coffee_bean"], "color": "#b28464"},
		{"at": Vector3(11, 0, 15.5), "label": "CEDAR & COPPER", "items": ["wood", "stick"], "color": "#92714f"}]
	var shops = {}
	var vendor_ids = ["herbalist", "brewer", "baker", "woodwright"]
	for index in range(stalls.size()):
		var data: Dictionary = stalls[index]
		var house = P.building(district, data.at, 6.8, 5.8, "#c3b59c", "#57646b", PI * 0.5 if data.at.x < 0 else -PI * 0.5, data.label, "timbermarket_" + vendor_ids[index] + "_shop", "workshop" if index == 3 else "bakery" if index == 2 else "stores", 9)
		house.add_to_group("timbermarket_stall")
		shops[vendor_ids[index]] = house
	var tea = P.building(district, Vector3(-15, 0, -38), 8.0, 6.2, "#bfb398", "#62705d", 0, "The Cedar Kettle", "timbermarket_tea_host_shop", "inn", 9)
	shops["tea_host"] = tea
	var table = Workbench.new(); table.name = "TimbermarketWorkbench"; table.position = Vector3(16, 0, -33); district.add_child(table)
	table.set_meta("id", "timbermarket_workbench")
	for p in [Vector3(-10, 0, 15), Vector3(10, 0, 51), Vector3(-11, 0, -26)]: P.lantern(district, p)
	P.signboard(district, Vector3(-7, 2.4, 34), "TIMBERMARKET", PI * 0.5, 4)

	B.branch(district, Vector3(-16, 4.3, 34), Vector3(16, 4.3, 34), 0.025, brass, 1)
	for i in range(11):
		var flag = B.box(district, Vector3(-14 + i * 2.8, 3.9, 34), Vector3(0.75, 0.65, 0.045), B.world_surface("cloth", ["#a65b49", "#708d70", "#c6b47a"][i % 3]))
		flag.rotation.z = 0.06 * sin(i)
	var people = [
		["herbalist", "Fenna Mossbasket", "elf", "gardener", "alchemist", Vector2(-7.7, 8), "Two herbs make a Lantern Tonic. Add a crystal to one herb instead, and the campfire brews a Mana Potion."],
		["brewer", "Orrin Blueglass", "human", "merchant", "alchemist", Vector2(7.3, 17), "Blue bottles restore mana. The crystal holds the infusion; the herb steadies it."],
		["baker", "Nella Honeycrumb", "smallfolk", "baker", "grocer", Vector2(-7.4, 17), "Marshmallows for the camp, coffee for the road. A warm fire makes both better."],
		["woodwright", "Bram Cedarhand", "dwarf", "mason", "smith", Vector2(11, -13), "The worktable is ready. Timbermarket keeps a clear avenue all the way to the travel plaza."],
		["tea_host", "Mira Kettleleaf", "human", "baker", "grocer", Vector2(-10, -36), "Rest a moment beneath the awning. Rootglow's old tree arch is on our western edge."],
		["porter", "Rook Copperstrap", "orc", "porter", "", Vector2(7, 30), "Cedarwatch's watchgate stands on the eastern edge. Its armory lies below the old barracks."],
		["gardener", "Sylva Fernwell", "elf", "gardener", "", Vector2(-8, 12), "Glimmerstags browse the valley. Fernhares disappear into the undergrowth before you notice their ears."],
		["watcher", "Edda Bellward", "human", "forester", "", Vector2(8, -24), "Rootlings guard the hollow. Watch their glowing seed before their arms rise to strike."]]
	for person in people:
		var at: Vector2 = person[5]
		P.npc(world, district, "timbermarket_" + person[0], person[1], ["#678d70", "#6d8295", "#ac8565"][people.find(person) % 3], person[4], [person[6], "Welcome to Bellcrown's Timbermarket."], person[2], person[3], P.local_loop(at.x, at.y, at.x + 0.8, at.y + 1.2), "scarf", Vector3(at.x, 0, at.y + 2), shops.get(person[0]))
	for id in L.GATES:
		var gate = Node3D.new(); gate.name = id.capitalize() + "Approach"; var at: Vector2 = L.GATES[id]
		gate.position = Vector3(at.x, 0, at.y); parent.add_child(gate)
		var art = load("res://scripts/landmark_art.gd")
		if id == "rootglow":
			var base = world.surface_height_at(parent.position.x + at.x, parent.position.z + at.y)
			gate.position.y = base - parent.position.y
			var point = Vector2(parent.position.x + at.x, parent.position.z + at.y)
			if not load("res://scripts/world_occupancy.gd").conflicts(world.state, Rect2(point + Vector2(-58, -110), Vector2(116, 122))):
				load("res://scripts/cave_entrance.gd").build(gate, Color("#76816a"), 9, world)
		else:
			for side in [-1.0, 1.0]:
				art.module(gate, "dungeon_pillar_decorated", Vector3(side * 2.1, 0, 0), Vector3(1.4, 4, 2))
				load("res://scripts/world_overhaul.gd").support_box(gate, Vector3(side * 2.1, 2, 0), Vector3(1.4, 4, 2))
			art.module(gate, "u29_castle_wall_half", Vector3(0, 3.6, 0), Vector3(5.6, 0.8, 2))
		P.signboard(gate, Vector3(0, 4.9, 0.2), L.NAMES[id].to_upper(), 0, 5, "cave_entrance" if id == "rootglow" else "")
		P.entrance(gate, "mosswake_gate_" + id, Vector3(0, 0.7, 1.4), L.point(id, Vector2(0, 3)), L.NAMES[id], "Explore " + L.NAMES[id])
		P.lantern(gate, Vector3(3.5, 0, 2.5))
