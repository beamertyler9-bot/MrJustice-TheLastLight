extends Node3D

const Treasure = preload("res://scripts/treasure_loot.gd")
const Architecture = preload("res://scripts/interior_architecture.gd")
const Shell = preload("res://scripts/interior_surfaces.gd")
const S = preload("res://scripts/region_sites.gd")
const B = preload("res://scripts/build.gd")
const P = preload("res://scripts/locations.gd")
const F = preload("res://scripts/regional_furnishings.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Deep = preload("res://scripts/deep_adventure.gd")
const Dungeon = preload("res://scripts/dungeon_dressing.gd")
const Creatures = preload("res://scripts/creature_catalog.gd")
const RegionalModels = preload("res://scripts/regional_creature_models.gd")
const Occupancy = preload("res://scripts/world_occupancy.gd")
var world
var game
var active_id := ""
var live: Node3D
var mouths: Dictionary = {}
var populated := false
var swimmers: Array = []
var clock := 0.0
var room_lights: Array = []
var light_position := Vector3.INF

func _process(dt: float) -> void:
	if game == null or game.mode != "play": return
	clock += dt
	if game.player.position.distance_squared_to(light_position) > 4.0: refresh_lighting(game.player.position)
	for swimmer in swimmers:
		if not is_instance_valid(swimmer.node): continue
		swimmer.node.position = swimmer.center + Vector3(cos(clock * 0.7 + swimmer.phase) * 0.6, -0.4, sin(clock * 0.7 + swimmer.phase) * 0.45)
		swimmer.node.rotation.y = -clock * 0.7 - swimmer.phase

func setup(owner_world) -> void: world = owner_world; name = "RegionalInteriors"
func bind_game(context) -> void:
	game = context
	if live != null:
		if active_id in ["mine", "dungeon"]: game.deep_adventure = Deep.new(); game.deep_adventure.setup(game)
		else: _encounters()
func _retire(node: Node) -> void:
	for child in node.find_children("*", "Node3D", true, false):
		for group in ["interactable", "enemy", "npc", "deep_space", "deep_connection", "deep_cache", "deep_gate", "deep_seal", "deep_trap_spawn", "deep_boss"]:
			if child.is_in_group(group): child.remove_from_group(group)
	if node.get_parent() != null: node.get_parent().remove_child(node)
	node.queue_free()

func stream_at(point: Vector3) -> void:
	var id = S.interior_at(point)
	if id.is_empty(): id = P.interior_at(point, world.state.seed_value)
	if id != active_id:
		if is_instance_valid(live): _retire(live)
		if active_id in ["mine", "dungeon"] and game != null and game.deep_adventure != null:
			if is_instance_valid(game.deep_adventure.encounter_root): _retire(game.deep_adventure.encounter_root)
			game.deep_adventure = null
		live = null; active_id = id; populated = false; swimmers.clear()
		room_lights.clear(); light_position = Vector3.INF
		if not id.is_empty():
			if id in ["mine", "dungeon"]: _legacy(id)
			else: _build(id)
	_stream_mouths(point if id.is_empty() and world.MosswakeLayouts.interior_at(point).is_empty() else Vector3.INF)

func _legacy(id: String) -> void:
	var key = "valley-d01" if id == "dungeon" else "legacy_mine"
	P.interior(world, id, _return_point(key))
	live = world.locations.get_node(id.capitalize() + "Interior")
	if game != null:
		game.deep_adventure = Deep.new(); game.deep_adventure.setup(game)

func _gate(id: String) -> Vector3:
	if id == "legacy_mine":
		var p: Vector2 = world.atlas.nodes.brindlewick + Vector2(-65, -75)
		return Vector3(p.x, world.surface_height_at(p.x, p.y) + 0.24, p.y)
	return S.gate_point(world.atlas, id)

func _return_point(id: String) -> Vector3:
	var base = _gate(id); var offset = Occupancy.entrance_offset(world, base, S.gate_yaw(id)); var p = Vector2(base.x, base.z) + offset
	return Vector3(p.x, world.surface_height_at(p.x, p.y) + 0.24, p.y)

func _stream_mouths(point: Vector3) -> void:
	var wanted = {}
	for record in S.catalog() + [{"id": "legacy_mine", "name": "Embervein Cave & Mine", "kind": "cave", "region": 9}]:
		if record.get("alias", "") in ["rootglow", "cedarwatch"]: continue
		var gate = _gate(record.id)
		if not point.is_finite() or Vector2(point.x - gate.x, point.z - gate.z).length() > 140: continue
		wanted[record.id] = true
		if mouths.has(record.id): continue
		var mouth = Node3D.new(); mouth.name = "Approach_" + record.id; mouth.position = gate - Vector3.UP * 0.24; add_child(mouth); mouths[record.id] = mouth
		var yaw = S.gate_yaw(record.id) if record.kind == "cave" else 0.0
		mouth.rotation.y = yaw


		var footprint = Rect2(-19, -35, 38, 40) if record.id in ["desert-d02", "desert-d03"] else Rect2(-5.5, -5, 11, 10)
		if record.kind == "cave": footprint = Rect2(-58, -110, 116, 122)
		var occupied = Occupancy.conflicts(world.state, Occupancy.oriented_rect(Vector2(gate.x, gate.z), footprint, yaw))
		mouth.set_meta("placement_clearance_applied", occupied)
		if not occupied:
			var art = load("res://scripts/landmark_art.gd")
			var stone = B.world_surface("stone", ["#76816a", "#96735a", "#989a7b", "#c7a37b", "#5a5150", "#64596b", "#a4a1b8"][int(record.region) - 9])
			if record.kind == "cave": load("res://scripts/cave_entrance.gd").build(mouth, Color(["#76816a", "#96735a", "#989a7b", "#c7a37b", "#5a5150", "#64596b", "#a4a1b8"][int(record.region) - 9]), int(record.region), world)
			elif record.id != "haunted-d01":
				for side in [-1, 1]:
					art.module(mouth, "dungeon_pillar_decorated", Vector3(side * 2.8, 0, -0.7), Vector3(1.3, 4, 2))
					load("res://scripts/world_overhaul.gd").support_box(mouth, Vector3(side * 2.8, 2, -0.7), Vector3(1.3, 4, 2))
				art.module(mouth, "u29_castle_wall_half", Vector3(0, 3.7, -0.7), Vector3(6.8, 0.8, 2))
			if record.id in ["desert-d02", "desert-d03"]:
				for tier in range(6): B.box(mouth, Vector3(0, 1 + tier * 2, -18), Vector3(38 - tier * 5, 2, 34 - tier * 4.4), stone)
		var target = S.entry_point(record.id) if not record.get("alias", "") == "dungeon" and record.id != "legacy_mine" else P.INTERIORS["dungeon" if record.id != "legacy_mine" else "mine"] + Vector3(0, 0.25, 1)
		var safe = Occupancy.entrance_offset(world, gate, yaw); var safe_at = Vector2(gate.x, gate.z) + safe; var local_safe = safe.rotated(yaw)
		P.entrance(mouth, "site_enter_" + record.id, Vector3(local_safe.x, world.surface_height_at(safe_at.x, safe_at.y) - mouth.position.y + 0.6, local_safe.y), target, record.name, "Enter " + record.name)
		if record.id == "haunted-d01": mouth.get_child(mouth.get_child_count() - 1).set_meta("ring_only", true)
		P.signboard(mouth, Vector3(4.5, 1.7, 2.8), record.name, -0.18, 3.4, "cave_entrance" if record.kind == "cave" else "")

		var at = Vector2(gate.x, gate.z); var nearest = at; var distance = INF
		for road in world.atlas.roads():
			var p: Vector2 = Geometry2D.get_closest_point_to_segment(at, road.a, road.b)
			if p.distance_to(at) < distance: nearest = p; distance = p.distance_to(at)
		for step in range(1, mini(12, ceili(distance / 9))):
			var p = at.lerp(nearest, float(step) / maxf(1, ceili(distance / 9)))
			var local_mark = (p - Vector2(gate.x, gate.z)).rotated(yaw)
			B.cyl(mouth, Vector3(local_mark.x, world.height_at(p.x, p.y) - mouth.position.y + 0.35, local_mark.y), 0.11, 0.7, B.mat("#b49a6b"))
		B.batch_static(mouth)
	for key in mouths.keys():
		if not wanted.has(key): _retire(mouths[key]); mouths.erase(key)

func _build(id: String) -> void:
	var record = S.site(id); var plan = S.layout(id)
	live = Node3D.new(); live.name = id; live.position = S.origin(id); add_child(live); live.set_meta("interior", id)
	for level in range(plan.levels): _shell(id, level)
	if plan.castle: _stairs(id)
	if record.kind != "cave": Architecture.portals(live, plan, func (p: Vector2, level: int) -> float: return S.floor_height(id, p, level), plan.castle, null if plan.castle else Architecture.stone(int(record.region), false, false, false))
	var furnished: Array[String] = []
	for room in plan.rooms:
		var local = S.point(id, room.p, int(room.level)) - S.origin(id) - Vector3.UP * 0.24
		var decor = Node3D.new(); decor.name = "Room_" + str(furnished.size()); decor.position = local; live.add_child(decor)
		if record.kind == "cave": _cave_art(decor, record, room)
		else:
			var purpose: String = room.name if plan.castle else _room_purpose(record, room, plan.rooms.find(room), plan.rooms.size())
			if plan.castle: F.furnish(decor, maxf(7, room.size.x - 2), maxf(7, room.size.y - 2), purpose, int(record.region), record.region == 14, not plan.castle)
			else:
				# Doorways lie on the line toward each linked room; keep them (and the way out) clear.
				var index: int = plan.rooms.find(room)
				var links: Array = []
				for edge in plan.links:
					var other := -1
					if int(edge[0]) == index: other = int(edge[1])
					elif int(edge[1]) == index: other = int(edge[0])
					if other >= 0 and int(plan.rooms[other].level) == int(room.level): links.append(((plan.rooms[other].p as Vector2) - (room.p as Vector2)).normalized())
				var keep: Array = [Vector2(0, 4) - (room.p as Vector2), Vector2(0, 6) - (room.p as Vector2), (plan.rooms.back().p as Vector2) + Vector2(0, 1.5) - (room.p as Vector2)]
				Dungeon.room(decor, room.size.x - 0.6, room.size.y - 0.6, str(room.get("shape", "rect")), purpose, int(record.region), links, keep, id + ":" + str(index))
			if plan.castle: Architecture.room(decor, room.size, 7.2, purpose)
			P.signboard(decor, Vector3(0, 2.6, -room.size.y * 0.35), room.name, 0, minf(5, room.size.x * 0.6))
			if not plan.castle:
				_site_tools(decor, record, room)
		_register_room_treasure(decor, id, furnished.size())
		_ground_decor(decor, id, room)
		furnished.append(room.name)
	live.set_meta("furnished_rooms", furnished)
	if record.kind == "cave": load("res://scripts/cave_dressing.gd").dress(live, id, record)
	elif not plan.castle: Dungeon.torches(live, id)
	var mouth = S.entry_point(id) - S.origin(id)
	P.entrance(live, "SiteExit", mouth + Vector3(0, 0.4, 1.5), _return_point(id), "The open road", "Return to the surface")
	P.signboard(live, mouth + Vector3(0, 2.5, 2), "SURFACE RETURN", PI, 4)
	for i in range(mini(6 if plan.castle else 3, plan.rooms.size())):
		var room: Dictionary = plan.rooms[i]
		var lamp = OmniLight3D.new(); lamp.position = S.point(id, room.p, int(room.level)) - S.origin(id) + Vector3.UP * 3
		# Caves are lit in their region's own colour; dungeons by warm torchlight.
		var cave_tones := ["#9fd8bb", "#f2b783", "#d4e3b0", "#f3cd8f", "#ff8a4a", "#93b2dc", "#bba0f2"]
		lamp.light_color = Color(cave_tones[clampi(int(record.region) - 9, 0, 6)] if record.kind == "cave" else "#efc193" if plan.castle else "#bcc5d7" if record.region == 14 else "#f2bd7d")
		lamp.light_energy = 0.85 if plan.castle else 1.15; lamp.omni_range = 13 if plan.castle else 20; lamp.shadow_enabled = false
		live.add_child(lamp); room_lights.append(lamp)
	if id in ["desert-d02", "desert-d03"]: _mechanism(id)
	_cache(id)
	if record.kind != "cave" and plan.rooms.size() > 4: _side_cache(id)
	B.batch_static(live)
	_encounters()
	if game != null: refresh_lighting(game.player.position)

func refresh_lighting(point: Vector3) -> void:
	if room_lights.is_empty() or S.site(active_id).is_empty(): return
	light_position = point
	var rooms = S.layout(active_id).rooms.duplicate()
	rooms.sort_custom(func (a, b): return S.point(active_id, a.p, int(a.level)).distance_squared_to(point) < S.point(active_id, b.p, int(b.level)).distance_squared_to(point))
	for i in range(room_lights.size()):
		var room: Dictionary = rooms[i]
		room_lights[i].position = S.point(active_id, room.p, int(room.level)) - S.origin(active_id) + Vector3.UP * (4.0 if S.layout(active_id).castle else 2.0)

func _room_purpose(record: Dictionary, room: Dictionary, index: int, total: int) -> String:
	if index == 0: return "entry hall"
	if index == total - 1: return "boss sanctum" if Creatures.BOSSES.has(record.id) else "vault treasure"
	return ["library archive", "armory workshop", "tomb ceremony", "stores pantry"][posmod(index + int(record.region), 4)]
func _ground_decor(decor: Node3D, id: String, room: Dictionary):
	if S.layout(id).castle: return
	var center = S.floor_height(id, room.p, int(room.level))
	for prop in decor.get_children():
		if prop is Node3D:

			if prop.has_meta("imported_asset") and (str(prop.get_meta("imported_asset")).begins_with("qnat_") or prop.get_meta("imported_asset") == "ruin_pillarsquarecut"): continue
			var p: Vector2 = room.p + Vector2(prop.position.x, prop.position.z)
			prop.position.y += S.floor_height(id, p, int(room.level)) - center
			if prop.name == "OverhaulRoom":
				for detail in prop.get_children():
					if detail is Node3D: detail.position.y += S.floor_height(id, room.p + Vector2(detail.position.x, detail.position.z), int(room.level)) - center
func _side_cache(id: String):
	if world.state.taken.has("site_side_cache_" + id): return
	var room: Dictionary = S.layout(id).rooms[2]; var q: Vector2 = room.p + Vector2(0, room.size.y * 0.22)
	var p = S.point(id, q, int(room.level)) - S.origin(id) - Vector3.UP * 0.24
	var cache = P.interaction(live, "site_side_cache_" + id, "regional_cache", "Open the side-chamber treasure", p + Vector3.UP * 0.35); cache.name = "SideTreasure"
	cache.set_meta("site", id); cache.set_meta("bonus_cache", true); load("res://scripts/world_overhaul.gd").cache(cache)
func _purpose(record: Dictionary) -> String:
	if any_word(record.name, ["pyramid", "mausoleum", "court", "abbey", "basilica", "cathedral", "monastery"]): return "tomb ceremony"
	if any_word(record.name, ["archive", "observatory", "surveyor", "orrery", "relay", "tower"]): return "library instruments"
	if any_word(record.name, ["bake", "pantry", "confection", "conservatory"]): return "bakery pantry"
	return "armory workshop"
func _site_tools(parent: Node3D, record: Dictionary, room: Dictionary) -> void:
	var p = Vector3(room.size.x * 0.22, 1.2, -room.size.y * 0.22)
	if any_word(record.hook, ["gear", "rotating", "clock", "orrery", "wind", "instrument"]):
		B.ring(parent, p + Vector3.UP, 0.9, 0.08, B.mat("#b5a175", 0.55)).rotation.x = PI * 0.5
		for i in range(8): B.box(parent, p + Vector3(cos(i * TAU / 8), 1 + sin(i * TAU / 8), 0), Vector3(0.2, 0.2, 0.12), B.mat("#b5a175", 0.55))
	if any_word(record.hook, ["sluice", "pump", "waterwheel", "channel", "mixing"]):
		B.cyl(parent, p - Vector3.UP * 0.5, 0.8, 1.2, B.world_surface("stone", "#7e827e"), false, 0.95)
		B.cyl(parent, p + Vector3.UP * 0.13, 0.72, 0.03, B.mat("#816144" if record.region == 10 else "#779d9f"))

func _surface(id: String, ceiling: bool, level: int) -> ArrayMesh:
	var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	var castle: bool = S.layout(id).castle
	for cell in S.cells(id):
		var p = Vector2(cell) * S.STEP

		if castle and p.x >= 36 and p.y >= -26 and p.y < 20: continue
		if castle and ceiling and p.x >= 32: continue
		for index in ([0, 2, 1, 1, 2, 3] if ceiling else [0, 1, 2, 1, 3, 2]):
			var q = p + Vector2(2 if index in [1, 3] else 0, 2 if index in [2, 3] else 0)
			var height = S.ceiling_height(id, q)
			if castle and ceiling:
				for room in S.layout(id).rooms:
					if int(room.level) == level and Rect2(room.p - room.size * 0.5, room.size).has_point(q):
						height = 5.2 + 1.8 * (1 - pow(clampf(absf(q.x - room.p.x) / (room.size.x * 0.5), 0, 1), 1.5)); break
			var y = S.floor_height(id, q, level) + (height if ceiling else 0)
			verts.append(Vector3(q.x, y, q.y)); normals.append(Vector3.DOWN if ceiling else Vector3.UP); uvs.append(q * 0.3)
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh

func _shell(id: String, level: int) -> void:
	var record = S.site(id); var cave: bool = record.kind == "cave"; var castle: bool = S.layout(id).castle
	var floor_material = Architecture.stone(int(record.region), true, castle, cave); var stone = Architecture.stone(int(record.region), false, castle, cave)
	if cave:
		Shell.build(live, S.cells(id), S.STEP, func (p: Vector2) -> float: return S.floor_height(id, p), func (p: Vector2) -> float: return S.ceiling_height(id, p), floor_material, stone, true)
		return
	for ceiling in [false, true]:
		var mesh = _surface(id, ceiling, level); B.mesh(live, mesh, stone if ceiling else floor_material).name = ("Ceiling_" if ceiling else "Floor_") + str(level)
		B.solid(live, Vector3.ZERO, mesh.create_trimesh_shape())
	var cells = S.cells(id)
	for cell in cells:
		var center = (Vector2(cell) + Vector2.ONE * 0.5) * S.STEP
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if cells.has(cell + d): continue
			var p = center + Vector2(d); var h = S.ceiling_height(id, p); var y = S.floor_height(id, p, level)
			B.box(live, Vector3(p.x, y + h * 0.5, p.y), Vector3(0.5, h + 0.2, 2.05) if d.x != 0 else Vector3(2.05, h + 0.2, 0.5), stone, true)

func _stairs(id: String) -> void:
	var stone = B.world_surface("stone", "#7d7483")
	for level in range(6):
		var x = 39 if level % 2 == 0 else 47
		var a = Vector3(x, S.floor_height(id, Vector2.ZERO, level), -26 if level % 2 == 0 else 20)
		var b = Vector3(x, a.y + 7.5, 20 if level % 2 == 0 else -26)
		var span = b - a; var center = (a + b) * 0.5 - Vector3.UP * 0.14
		var ramp = Node3D.new(); live.add_child(ramp); ramp.position = center
		ramp.rotation.x = -atan2(span.y, span.z) if span.z > 0 else atan2(span.y, -span.z)
		B.box(ramp, Vector3.ZERO, Vector3(5, 0.28, span.length()), stone, true)

		for tread in range(58):
			var at = a.lerp(b, (tread + 0.5) / 58.0)
			B.box(live, at + Vector3.UP * 0.014, Vector3(5, 0.045, 0.075), stone)
		for side in [-2.8, 2.8]:
			for post in range(12):
				var at = a.lerp(b, float(post) / 11) + Vector3(side, 0.52, 0)
				B.cyl(live, at, 0.045, 1.04, B.mat("#978794"), false, 0.055)
		for side in [-2.8, 2.8]: B.branch(live, a + Vector3(side, 1, 0), b + Vector3(side, 1, 0), 0.07, B.mat("#978794"), 1)
	live.set_meta("stairs", 6)

func _cave_art(parent: Node3D, record: Dictionary, room: Dictionary) -> void:
	# Stalactites, boulders, crystals, mushrooms and lava come from cave_dressing.gd; each
	# room keeps its own rocks, pools and wildlife here.
	load("res://scripts/world_overhaul.gd").cave(parent, record, room)
	var region = int(record.region)
	if any_word(record.hook, ["pool", "basin", "water", "cola"]):
		B.cyl(parent, Vector3(room.size.x * 0.22, 0.02, -room.size.y * 0.17), minf(room.size.x, room.size.y) * 0.13, 0.03, B.mat("#4a2c1c" if region == 10 else "#24484f", 0.35))
	if region == 13:
		var p = Vector3(room.size.x * 0.23, 0.025, room.size.y * 0.2)
		B.cyl(parent, p, 1.15, 0.03, B.mat("#2c4a4f", 0.35))
		if swimmers.size() < 4:
			var fish = Node3D.new(); parent.add_child(fish); RegionalModels.wildlife(fish, "cinderfin_fish"); swimmers.append({"node": fish, "center": p, "phase": float(swimmers.size()) * PI})
	parent.set_meta("natural_dressing", true)
func any_word(value: String, words: Array) -> bool: return F.any_word(value, words)

func _cache(id: String) -> void:
	if world.state.taken.has("site_cache_" + id): return
	var rooms = S.layout(id).rooms; var room: Dictionary = rooms.back()


	var p = S.point(id, room.p + Vector2(0, 1.5), int(room.level)) - S.origin(id) - Vector3.UP * 0.24
	var cache = P.interaction(live, "site_cache_" + id, "regional_cache", "Open the expedition cache", p + Vector3(0, 0.35, 0)); cache.name = "RegionalCache"
	cache.set_meta("site", id)
	load("res://scripts/world_overhaul.gd").cache(cache)

func claim_cache(node: Node3D) -> bool:
	if game == null or not is_instance_valid(node) or live == null or not live.is_ancestor_of(node) or node.is_queued_for_deletion(): return false
	var id = str(node.get_meta("site", "")); var bonus = bool(node.get_meta("bonus_cache", false)); var key = ("site_side_cache_" if bonus else "site_cache_") + id; var state = game.state
	if node.has_meta("room_cache"): key = str(node.get_meta("id"))
	if state.taken.has(key): return false
	if not bonus and not node.has_meta("room_cache") and id in ["desert-d02", "desert-d03"] and not state.taken.get("site_mechanism_" + id, false): game.toast("Align the sunlight mirrors." if id == "desert-d02" else "Raise both counterweights to release the strongbox."); return false
	var record = S.site(id)
	var flags = {} if bonus or node.has_meta("room_cache") else {"site_complete_" + id: true}
	if node.has_meta("room_cache"): key = str(node.get_meta("id"))
	return Treasure.claim(game, node, key, Treasure.bundle(key, str(record.kind), int(record.region)), "", flags)

func _register_room_treasure(decor: Node3D, id: String, room_index: int) -> void:
	var index = 0
	for node in decor.find_children("*", "Node3D", true, false):
		if node.get_meta("imported_asset", "") != "dungeon_chest_gold": continue
		var key = "site_room_cache_%s_%d_%d" % [id, room_index, index]; index += 1
		if world.state.taken.has(key):
			node.get_parent().remove_child(node); node.queue_free(); continue


		for child in node.get_children():
			node.remove_child(child); child.queue_free()
		node.position.y += 0.35 * node.scale.y
		load("res://scripts/treasure_art.gd").build(node, Vector3(1.2, 0.7, 0.8))
		load("res://scripts/world_overhaul.gd").support_box(node, Vector3.ZERO, Vector3(1.2, 0.7, 0.8))
		node.set_meta("id", key); node.set_meta("kind", "regional_cache"); node.set_meta("site", id); node.set_meta("room_cache", true)
		node.set_meta("label", "Search the ceremonial strongbox")
		node.add_to_group("interactable"); node.add_to_group("batch_dynamic")

func _mechanism(id: String) -> void:
	var room: Dictionary = S.layout(id).rooms[1]
	var p = S.point(id, room.p) - S.origin(id) + Vector3(-4, 0.4, 0)
	var node = P.interaction(live, "mechanism_" + id, "regional_mechanism", "Align sunlight mirrors" if id == "desert-d02" else "Raise counterweight", p); node.name = "SiteMechanism"
	node.set_meta("mechanism_kind", "sunlight" if id == "desert-d02" else "counterweight")
	var progress = 0
	for i in range(3 if id == "desert-d02" else 2):
		if world.state.taken.get("site_dial_%s_%d" % [id, i], false): progress += 1
	node.rotation.y = progress * TAU / (3 if id == "desert-d02" else 2)
	B.cyl(node, Vector3.ZERO, 0.75, 0.65, B.mat("#b0a16e", 0.45))
	if id == "desert-d02":
		for i in range(3): B.facet(node, Vector3((i - 1) * 0.7, 1 + i * 0.3, 0), Vector3(0.5, 1.1, 0.18), B.mat("#b8d9dc", 0.5, 0.2)).rotation.z = (i - 1) * 0.3
	else:
		for x in [-0.5, 0.5]: B.box(node, Vector3(x, 1.3, 0), Vector3(0.5, 1.6, 0.5), B.mat("#877f69")); B.branch(node, Vector3(x, 2.3, 0), Vector3(x, 0.5, 0), 0.025, B.mat("#bdad78"), 1)
func operate(node: Node3D) -> bool:
	if game == null or live == null or not is_instance_valid(node) or not live.is_ancestor_of(node): return false
	var id = active_id; var state = game.state; var old: Dictionary = state.taken.duplicate(true)
	var required = 3 if id == "desert-d02" else 2; var progress = 0
	for i in range(required):
		if state.taken.get("site_dial_%s_%d" % [id, i], false): progress += 1
	if progress >= required: game.toast("The mechanism is already aligned. The strongbox is open."); return true
	state.taken["site_dial_%s_%d" % [id, progress]] = true
	if progress + 1 == required: state.taken["site_mechanism_" + id] = true
	if not state.save_game(): state.taken = old; game.toast("Could not save the mechanism. Nothing changed."); return false
	node.rotation.y += TAU / required; game.audio.cue("collect"); game.toast("Sunlight aligned %d/3." % (progress + 1) if id == "desert-d02" else "Counterweights raised %d/2." % (progress + 1)); return true

func _encounters() -> void:
	if game == null or live == null or populated or active_id in ["mine", "dungeon"]: return
	populated = true
	var rooms = S.layout(active_id).rooms
	for i in range(2):
		var room: Dictionary = rooms[mini(rooms.size() - 1, 2 + i * 2)]; var key = "site_enemy_%s_%d" % [active_id, i]
		if world.state.taken.has(key): continue
		var options = Creatures.hostiles_for(int(S.site(active_id).region))
		var actor = Enemy.new(); actor.configure_species(options[posmod(hash(active_id) + i, options.size())])
		actor.id = key; actor.game = game; actor.position = S.point(active_id, room.p, int(room.level)) - S.origin(active_id) + Vector3(2, 0, 0); actor.home = S.origin(active_id) + actor.position; live.add_child(actor)
	if Creatures.BOSSES.has(active_id):
		var key = "site_boss_" + active_id
		if not world.state.taken.has(key):
			var room: Dictionary = rooms.back(); var boss = Enemy.new(); boss.configure_species(Creatures.BOSSES[active_id]); boss.id = key; boss.game = game; boss.position = S.point(active_id, room.p, int(room.level)) - S.origin(active_id) + Vector3(0, 0, -2); boss.home = S.origin(active_id) + boss.position; live.add_child(boss); boss.set_meta("is_boss", true)
