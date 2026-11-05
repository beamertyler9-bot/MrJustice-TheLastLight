extends RefCounted
## Furnishes each of Blackthorn Keep's 42 rooms for what it is, plus its seven landings.
## Walkways from each doorway to the middle of the room are kept clear.

const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/imported_assets.gd")
const O = preload("res://scripts/world_overhaul.gd")
const Architecture = preload("res://scripts/interior_architecture.gd")
const Dungeon = preload("res://scripts/dungeon_dressing.gd")
const Comfort = preload("res://scripts/household_comfort.gd")
const ROOM := Vector2(19.6, 20.6)

static func any(name: String, words: Array) -> bool:
	for word in words:
		if word in name: return true
	return false


static func furnish(decor: Node3D, room: Dictionary, region: int) -> void:
	var name := str(room.name).to_lower()
	var size: Vector2 = room.size
	if size.x > 40.0:
		_landing(decor, size)
		return
	# Doorway on the landing side: rooms north of the landing face +z, south rooms face -z.
	var door := Vector2(0, 1) if (room.p as Vector2).y < -6.0 else Vector2(0, -1)
	var back := -door
	var d = Dungeon.new()
	d.parent = decor; d.width = ROOM.x; d.depth = ROOM.y; d.shape = "rect"; d.rng.seed = hash("castle:" + name)
	d.avoid.append(["ray", door])
	d.pillar_stone = B.world_surface("stone", "#6d6a78")
	Architecture.room(decor, ROOM, 7.2, str(room.name))
	var stone := B.world_surface("stone", "#857f8c")
	var timber := B.world_surface("timber", "#5e4636")
	var back_z := back.y * (ROOM.y * 0.5 - 0.3)
	if any(name, ["royal chamber", "guest", "servants", "dressing"]):
		_bedroom(d, name, back, back_z, stone, timber)
	elif any(name, ["great hall", "reception", "ballroom"]):
		_hall(d, name, back, back_z, stone, timber)
	elif any(name, ["kitchen", "scullery"]):
		_kitchen(d, back, back_z, stone, timber)
	elif any(name, ["prison"]):
		_prison(d, back, back_z)
	elif any(name, ["crypt"]):
		d._furnish("tomb ceremony", region)
	elif any(name, ["armory", "guardroom", "gatehouse"]):
		d._furnish("armory workshop", region)
		var table := Vector2(-4.5, back_z * 0.35)
		if d._free(table, 1.2):
			O.fit(decor, "qprop_table_large", Vector3(table.x, 0, table.y), Vector3(2.2, 0.85, 1.3))
			for side in [-1, 1]: O.fit(decor, "qprop_chair_1", Vector3(table.x + side * 1.5, 0, table.y), Vector3(0.6, 0.95, 0.6), side * PI * 0.5)
	elif any(name, ["vault"]):
		d._furnish("vault treasure", region)
	elif any(name, ["pantry", "stores", "cellar", "cold room", "service"]):
		d._furnish("stores pantry", region)
	elif any(name, ["library", "study", "map", "council", "instrument", "observatory", "star"]):
		_study(d, name, back, back_z, timber)
	elif any(name, ["chapel", "vestry"]):
		_chapel(d, name, back, back_z)
	elif any(name, ["gallery", "music", "portrait"]):
		_gallery(d, back_z)
	elif any(name, ["throne"]):
		d._brazier(Vector2(-3.5, back_z - back.y * 3.0), true); d._brazier(Vector2(3.5, back_z - back.y * 3.0), true)
		d._along_walls(["dungeon_banner_patterna_red"], 6, 2.6, 0.42, 3.0, Vector3.ZERO, 0.6, 1.4)
	elif any(name, ["bell", "clock", "lookout"]):
		_belfry(d, name, back_z)
	else:
		d._furnish("entry hall", region)
	# Structure: a stone arcade down the room (two rows of pillars, the middle aisle clear),
	# then more furniture along the side walls for the room's purpose.
	if not any(name, ["bell", "clock", "prison"]):
		for x in [-5.6, 5.6]:
			for z in [-6.5, 0.0, 6.5]: d._pillar(Vector2(x, z))
	_side_walls(d, name)
	# Every room has its own warm light (only drawn when you are near it).
	var lamp := OmniLight3D.new(); lamp.name = "CastleRoomLight"; lamp.position = Vector3(0, 4.6, 0)
	lamp.light_color = Color("#ffcf96"); lamp.light_energy = 0.95; lamp.omni_range = 15.0; lamp.shadow_enabled = false
	lamp.distance_fade_enabled = true; lamp.distance_fade_begin = 24.0; lamp.distance_fade_length = 8.0
	decor.add_child(lamp)
	decor.set_meta("castle_room", name)


static func _put_fit(d, id: String, p: Vector2, size: Vector3, yaw: float, solid: bool = true, radius: float = 0.9) -> Node3D:
	if not d._free(p, radius): return null
	var node := O.fit(d.parent, id, Vector3(p.x, 0, p.y), size, yaw)
	if node != null and solid: O.support_box(d.parent, Vector3(p.x, size.y * 0.5, p.y), size * 0.9)
	return node


static func _hearth_on(d, at: Vector2, facing: Vector2, stone: Material, timber: Material) -> void:
	var holder := Node3D.new(); holder.position = Vector3(at.x, 0, at.y); holder.rotation.y = atan2(facing.x, facing.y)
	d.parent.add_child(holder)
	Comfort._hearth(holder, Vector3.ZERO, stone, timber, d.rng)


static func _bedroom(d, name: String, back: Vector2, back_z: float, stone: Material, timber: Material) -> void:
	var facing := -back
	var yaw := atan2(facing.x, facing.y)
	if "servants" in name:
		for i in range(4):
			var x := -7.5 + i * 5.0
			_put_fit(d, ["qprop_bed_twin1", "qprop_bed_twin2"][i % 2], Vector2(x, back_z - back.y * 1.4), Vector3(1.3, 0.9, 2.6), yaw)
			_put_fit(d, "qprop_chest_wood", Vector2(x, back_z - back.y * 3.4), Vector3(0.9, 0.6, 0.6), yaw, true, 0.6)
	else:
		var big := "royal" in name
		_put_fit(d, "dungeon_bed_decorated" if big else "qprop_bed_twin1", Vector2(0, back_z - back.y * 1.7), Vector3(2.6, 1.3, 3.2) if big else Vector3(1.6, 1.0, 2.7), yaw)
		for side in [-1, 1]: _put_fit(d, "qprop_nightstand_shelf", Vector2(side * 2.1, back_z - back.y * 0.5), Vector3(0.7, 0.65, 0.5), yaw, true, 0.4)
		_put_fit(d, "qprop_cabinet", Vector2(-7.0, back_z - back.y * 0.4), Vector3(1.6, 2.1, 0.7), yaw, true, 0.6)
		_put_fit(d, "qprop_chest_wood", Vector2(0, back_z - back.y * 4.4), Vector3(1.3, 0.7, 0.8), yaw, true, 0.6)
		O.fit(d.parent, "interior_mdvl_interiors_rug_01", Vector3(0, 0.07, back_z - back.y * 5.6), Vector3(3.2, 0.03, 2.2))
		if big: d._along_walls(["dungeon_banner_patterna_red", "dungeon_banner_shield_blue"], 2, 2.6, 0.42, 4.0, Vector3.ZERO, 0.6, 1.4)
	_hearth_on(d, Vector2(ROOM.x * 0.5 - 0.3, -back.y * 1.0), Vector2(-1, 0), stone, timber)
	for i in range(2): Comfort._painting(d.parent, Vector3(-ROOM.x * 0.5 + 0.08, 1.9, back_z - back.y * (3.0 + i * 5.0)), atan2(1.0, 0.0), d.rng)


static func _hall(d, name: String, back: Vector2, back_z: float, stone: Material, timber: Material) -> void:
	var facing := -back
	if "great hall" in name:
		for x in [-4.2, 4.2]:
			for k in range(3):
				var p := Vector2(x, back_z - back.y * (5.0 + k * 3.2))
				var table := _put_fit(d, "dungeon_table_long_decorated_a", p, Vector3(1.2, 1.0, 2.6), 0.0, true, 1.0)
				if table != null:
					for side in [-1, 1]: O.fit(d.parent, "qprop_bench", Vector3(p.x + side * 1.1, 0, p.y), Vector3(0.5, 0.5, 2.4), 0.0)
		# The high seat on a dais at the far end.
		var dais := Vector2(0, back_z - back.y * 1.6)
		B.box(d.parent, Vector3(dais.x, 0.2, dais.y), Vector3(5.0, 0.4, 2.6), stone, true)
		O.fit(d.parent, "qprop_chair_1", Vector3(dais.x, 0.4, dais.y), Vector3(1.0, 1.7, 1.0), atan2(facing.x, facing.y))
		for side in [-1, 1]: O.fit(d.parent, "qprop_candlestick_stand", Vector3(dais.x + side * 1.8, 0.4, dais.y), Vector3(0.4, 1.6, 0.4))
		_hearth_on(d, Vector2(-ROOM.x * 0.5 + 0.3, -back.y * 2.0), Vector2(1, 0), stone, timber)
		d._along_walls(["dungeon_banner_patterna_red", "dungeon_banner_patternb_brown"], 4, 2.6, 0.42, 3.4, Vector3.ZERO, 0.6, 1.4)
	else:
		# Reception rooms and the ballroom: an open floor ringed with seats, plants and pictures.
		for side in [-1, 1]:
			for k in range(3):
				var p := Vector2(side * (ROOM.x * 0.5 - 1.0), -6.0 + k * 6.0)
				_put_fit(d, "qprop_bench", p, Vector3(2.2, 0.5, 0.55), side * -PI * 0.5, true, 0.6)
		for i in range(4): Comfort._painting(d.parent, Vector3((i - 1.5) * 4.0, 2.2, back_z + back.y * 0.0 - back.y * 0.1), atan2(-back.x, -back.y), d.rng)
		d._corners(["interior_mdvl_interiors_pottedplant_01"], 1.0, 0.9)
		O.fit(d.parent, "interior_mdvl_interiors_rug_01", Vector3(0, 0.07, 0), Vector3(6.0, 0.03, 4.4))


static func _kitchen(d, back: Vector2, back_z: float, stone: Material, timber: Material) -> void:
	_hearth_on(d, Vector2(0, back_z + back.y * 0.2), -back, stone, timber)
	_put_fit(d, "qprop_cauldron", Vector2(0, back_z - back.y * 2.8), Vector3(1.2, 1.1, 1.2), 0.0)
	for x in [-5.0, 5.0]:
		_put_fit(d, "qprop_workbench", Vector2(x, -1.0), Vector3(2.2, 0.95, 1.0), 0.0, true, 1.0)
	d._along_walls(["qprop_shelf_small_bottles"], 3, 1.0, 0.3, 3.0, Vector3.ZERO, 0.5, 1.4)
	d._corners(["dungeon_barrel_large_decorated", "dungeon_box_stacked", "dungeon_barrel_small_stack", "qprop_barrel"], 1.1, 0.9, Vector3(1.0, 1.1, 1.0))
	_put_fit(d, "interior_mdvl_interiors_potcrane_01", Vector2(3.2, back_z - back.y * 0.8), Vector3(0.9, 1.3, 0.6), 0.0, false)


static func _prison(d, back: Vector2, back_z: float) -> void:
	# Three barred cells along the far wall.
	var front_z := back_z - back.y * 4.2
	var facing_yaw := atan2(-back.x, -back.y)
	for i in range(6):
		var x := -7.5 + i * 3.0
		O.fit(d.parent, "p32_dungeon_gate_metal_bars", Vector3(x, 0, front_z), Vector3(3.0, 3.4, 0.2), facing_yaw)
	var bars := BoxShape3D.new(); bars.size = Vector3(18.0, 3.4, 0.3)
	B.solid(d.parent, Vector3(0, 1.7, front_z), bars)
	for x in [-3.0, 3.0]:
		var divider := B.box(d.parent, Vector3(x, 1.7, (front_z + back_z) * 0.5), Vector3(0.3, 3.4, absf(front_z - back_z)), B.world_surface("stone", "#6d6a78"), true)
	for x in [-6.0, 0.0, 6.0]:
		B.box(d.parent, Vector3(x - 1.0, 0.06, back_z - back.y * 1.6), Vector3(1.6, 0.12, 2.2), B.mat("#b8a15c"))
		A.place(d.parent, "qprop_bucket_wooden_1", Vector3(x + 1.6, 0, back_z - back.y * 0.8), 0.4, d.rng.randf() * TAU)
		A.place(d.parent, "ruin_skull", Vector3(x + 0.8, 0, back_z - back.y * 2.6), 0.3, d.rng.randf() * TAU)
	O.fit(d.parent, "dungeon_table_medium_tablecloth", Vector3(-5.0, 0, 3.0 * -back.y), Vector3(1.6, 0.9, 1.6))
	d._along_walls(["dungeon_keyring_hanging", "qprop_chain_coil"], 2, 0.8, 0.3, 4.0, Vector3.ZERO, 0.6, 1.5)


static func _study(d, name: String, back: Vector2, back_z: float, timber: Material) -> void:
	d._along_walls(["qprop_bookcase_2", "dungeon_wall_shelves", "qprop_bookcase_2"], 7, 2.4, 0.35, 2.4, Vector3(1.4, 2.4, 0.5))
	var table := Vector2(0, back_z - back.y * 5.5)
	if "council" in name:
		var long := _put_fit(d, "dungeon_table_long_decorated_a", Vector2(0, 0), Vector3(1.6, 1.0, 5.0), 0.0, true, 1.5)
		if long != null:
			for z in [-1.6, 0.0, 1.6]:
				for side in [-1, 1]: O.fit(d.parent, "qprop_chair_1", Vector3(side * 1.4, 0, z), Vector3(0.6, 1.0, 0.6), -side * PI * 0.5)
	else:
		_put_fit(d, "qprop_table_large", table, Vector3(2.6, 0.85, 1.5), 0.0, true, 1.2)
		var top := Vector3(table.x, 0.86, table.y)
		O.fit(d.parent, "kaykit_map" if "map" in name else "qprop_book_stack_1", top + Vector3(-0.4, 0, 0), Vector3(0.9, 0.06, 0.6) if "map" in name else Vector3(0.4, 0.25, 0.3))
		O.fit(d.parent, "qprop_candlestick", top + Vector3(0.8, 0, 0.2), Vector3(0.2, 0.4, 0.2))
	if any(name, ["observatory", "star", "instrument"]):
		_telescope(d.parent, Vector3(-4.0, 0, back_z - back.y * 3.0), d.rng.randf() * TAU)


static func _telescope(parent: Node3D, at: Vector3, yaw: float) -> void:
	var node := Node3D.new(); node.name = "Telescope"; node.position = at; node.rotation.y = yaw; parent.add_child(node)
	var brass := B.mat("#b59253", 0.6); var wood := B.world_surface("timber", "#5e4636")
	for i in range(3):
		var a := float(i) / 3.0 * TAU
		B.branch(node, Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55), Vector3(0, 1.3, 0), 0.04, wood, 0.8)
	var tube := B.cyl(node, Vector3(0, 1.55, 0), 0.13, 1.9, brass)
	tube.rotation.x = -0.75
	B.cyl(node, Vector3(0, 1.55, 0), 0.09, 0.3, B.mat("#2c2c34", 0.4)).rotation.z = PI * 0.5


static func _chapel(d, name: String, back: Vector2, back_z: float) -> void:
	var altar := Vector2(0, back_z - back.y * 1.6)
	if d._free(altar, 0.8):
		B.box(d.parent, Vector3(altar.x, 0.15, altar.y), Vector3(4.6, 0.3, 2.8), B.world_surface("stone", "#857f8c"), true)
		var a := A.place(d.parent, "ruin_altar", Vector3(altar.x, 0.3, altar.y), 1.3, 0.0)
		for side in [-1, 1]: O.fit(d.parent, "qprop_candlestick_stand", Vector3(altar.x + side * 1.6, 0.3, altar.y), Vector3(0.4, 1.6, 0.4))
	d._along_walls(["dungeon_banner_patternc_white"], 4, 2.6, 0.42, 3.4, Vector3.ZERO, 0.6, 1.4)
	if "vestry" in name:
		d._along_walls(["qprop_cabinet", "qprop_chest_wood"], 4, 1.8, 0.5, 3.0, Vector3(1.4, 1.8, 0.6))


static func _gallery(d, back_z: float) -> void:
	for side in [-1, 1]:
		for k in range(4):
			Comfort._painting(d.parent, Vector3(side * (ROOM.x * 0.5 - 0.08), 2.0, -7.0 + k * 4.6), atan2(-float(side), 0.0), d.rng)
	for k in range(3):
		var p := Vector2(0, -6.0 + k * 6.0)
		if absf(p.y) > 1.5: _put_fit(d, "qprop_bench", p, Vector3(2.2, 0.5, 0.55), 0.0, true, 0.7)
	d._corners(["interior_mdvl_interiors_pottedplant_01", "qprop_candlestick_stand"], 1.0, 0.9)


static func _belfry(d, name: String, back_z: float) -> void:
	if "clock" in name:
		var brass := B.mat("#b59253", 0.6)
		for i in range(3):
			var gear := Node3D.new(); gear.position = Vector3(-5.0 + i * 5.0, 3.0 + (i % 2) * 1.2, back_z); d.parent.add_child(gear)
			var r := 1.2 + (i % 2) * 0.7
			B.ring(gear, Vector3.ZERO, r, 0.12, brass).rotation.x = PI * 0.5
			for k in range(12):
				var a := float(k) / 12.0 * TAU
				B.box(gear, Vector3(cos(a) * (r + 0.15), sin(a) * (r + 0.15), 0), Vector3(0.22, 0.22, 0.16), brass)
			B.cyl(gear, Vector3.ZERO, 0.18, 0.4, brass).rotation.x = PI * 0.5
	else:
		# A great bronze bell hung from a timber beam.
		var bronze := B.mat("#9c7a3c", 0.65)
		var beam_y := 6.2
		B.box(d.parent, Vector3(0, beam_y, 0), Vector3(ROOM.x - 0.4, 0.5, 0.6), B.world_surface("timber", "#4e3a2c"))
		var bell := Node3D.new(); bell.name = "GreatBell"; bell.position = Vector3(0, beam_y - 0.3, 0); d.parent.add_child(bell)
		var cone := CylinderMesh.new(); cone.top_radius = 0.55; cone.bottom_radius = 1.25; cone.height = 1.9; cone.radial_segments = 18
		B.mesh(bell, cone, bronze, Vector3(0, -1.1, 0))
		B.ball(bell, Vector3(0, -0.15, 0), Vector3(1.15, 0.6, 1.15), bronze)
		B.ring(bell, Vector3(0, -2.05, 0), 1.25, 0.1, bronze)
		B.ball(bell, Vector3(0, -1.9, 0), Vector3(0.35, 0.35, 0.35), B.mat("#3a3530", 0.5))
		if "lookout" in name: _telescope(d.parent, Vector3(5.0, 0, back_z * 0.5), 0.6)


## The long landing on every floor: runner carpet, benches between the doorways, banners,
## and plinths with urns.
static func _landing(decor: Node3D, size: Vector2) -> void:
	B.box(decor, Vector3(0, 0.03, 0), Vector3(size.x - 6.0, 0.02, 2.6), B.mat("#c9a35a", 0.3))
	B.box(decor, Vector3(0, 0.035, 0), Vector3(size.x - 6.2, 0.02, 2.3), B.mat("#5b2230"))
	for x in [-11.0, 11.0, -27.0, 27.0]:
		for side in [-1, 1]:
			O.fit(decor, "qprop_bench", Vector3(x, 0, side * 2.6), Vector3(2.2, 0.5, 0.55), 0.0 if side > 0 else PI)
	for x in [-16.0, -6.0, 6.0, 16.0]:
		for side in [-1, 1]:
			var banner := A.place(decor, ["dungeon_banner_patterna_red", "dungeon_banner_shield_blue"][int(absf(x)) % 2], Vector3(x, 1.3, side * 3.3), 2.4, 0.0 if side < 0 else PI)
	# A plinth and urn at the west end (the east end opens into the stair tower).
	B.cyl(decor, Vector3(-30.0, 0.5, 0), 0.35, 1.0, B.world_surface("stone", "#857f8c"), true)
	A.place(decor, "ruin_vase", Vector3(-30.0, 1.0, 0), 0.8, 0.0)


## Fills the side walls (between the arcade and the walls) to suit the room.
static func _side_walls(d, name: String) -> void:
	var ids: Array = ["qprop_candlestick_stand", "interior_mdvl_interiors_pottedplant_01"]
	var height := 1.6
	var solid := Vector3(0.6, 1.6, 0.6)
	if any(name, ["royal", "guest", "dressing", "servants"]):
		ids = ["qprop_cabinet", "qprop_chest_wood", "qprop_candlestick_stand", "interior_mdvl_interiors_pottedplant_01"]; height = 1.8; solid = Vector3(1.2, 1.8, 0.6)
	elif any(name, ["library", "study", "map", "council", "instrument", "observatory", "star", "belfry", "roof"]):
		ids = ["qprop_bookcase_2", "dungeon_wall_shelves", "qprop_candlestick_stand"]; height = 2.3; solid = Vector3(1.3, 2.3, 0.5)
	elif any(name, ["kitchen", "scullery", "pantry", "stores", "cellar", "cold", "service"]):
		ids = ["qprop_barrel", "dungeon_box_stacked", "qprop_shelf_simple", "qprop_crate_wooden"]; height = 1.1; solid = Vector3(1.0, 1.1, 0.9)
	elif any(name, ["armory", "guard", "gatehouse"]):
		ids = ["dungeon_barrel_large_decorated", "qprop_crate_wooden", "dungeon_box_stacked"]; height = 1.1; solid = Vector3(1.0, 1.1, 0.9)
	elif any(name, ["chapel", "vestry", "crypt"]):
		ids = ["qprop_candlestick_stand", "ruin_vase", "qprop_candlestick_stand"]; height = 1.5; solid = Vector3(0.6, 1.5, 0.6)
	elif any(name, ["gallery", "music", "portrait", "ballroom", "reception", "great hall", "throne"]):
		ids = ["qprop_candlestick_stand", "interior_mdvl_interiors_pottedplant_01", "ruin_vase"]; height = 1.5; solid = Vector3(0.6, 1.5, 0.6)
	var placed := 0
	for side in [-1, 1]:
		for k in range(5):
			var p := Vector2(side * (ROOM.x * 0.5 - 0.75), -8.0 + k * 4.0 + (1.0 if side > 0 else -1.0) * 0.6)
			if not d._free(p, 0.5): continue
			var id: String = ids[(k + (side + 1)) % ids.size()]
			_put_fit(d, id, p, Vector3(solid.x, height, solid.z), atan2(-float(side), 0.0), true, 0.5)
			placed += 1
	d.parent.set_meta("side_furniture", placed)
