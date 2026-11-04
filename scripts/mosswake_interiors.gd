extends Node3D

const Treasure = preload("res://scripts/treasure_loot.gd")
const L = preload("res://scripts/mosswake_layouts.gd")
const B = preload("res://scripts/build.gd")
const Places = preload("res://scripts/locations.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Items = preload("res://scripts/item_models.gd")
var world
var game
var active_id := ""
var live: Node3D
var encounters_ready := false

func setup(owner_world) -> void:
	world = owner_world; name = "MosswakeInteriors"
func bind_game(context) -> void:
	game = context
	if live != null: _encounters()

func stream_at(point: Vector3) -> void:
	var id = L.interior_at(point)
	if id == active_id: return
	if is_instance_valid(live):
		for node in live.find_children("*", "Node3D", true, false):
			if node.is_in_group("enemy"): node.remove_from_group("enemy")
			if node.is_in_group("interactable"): node.remove_from_group("interactable")
		remove_child(live); live.queue_free()
	live = null; active_id = id; encounters_ready = false
	if id.is_empty(): return
	live = Node3D.new(); live.name = id.capitalize() + "Interior"; live.position = L.ORIGINS[id]; add_child(live)
	live.set_meta("interior", id)
	_shell(id)
	if id == "rootglow": _rootglow_art()
	else: _redoubt_art()
	Places.entrance(live, "mosswake_exit_" + id, Vector3(0, 0.25, 5), L.gate_point(world.atlas, id), "Bellcrown / the open road", "Leave " + str(L.NAMES[id]))
	Places.signboard(live, Vector3(0, 2.7, 5.6), "SURFACE RETURN", PI, 3.3)
	if id == "cedarwatch":
		var p = L.point(id, Vector2(14, -20)) - L.ORIGINS[id]
		Places.entrance(live, "mosswake_postern", p, L.gate_point(world.atlas, id), "Bellcrown / postern return", "Leave through the postern")
	_cache(id)
	B.batch_static(live)
	_encounters()

func _surface(id: String, ceiling: bool) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for cell in L.cells(id):
		var p = Vector2(cell) * L.STEP
		var points = [p, p + Vector2(L.STEP, 0), p + Vector2(0, L.STEP), p + Vector2(L.STEP, L.STEP)]
		var order = [0, 2, 1, 1, 2, 3] if ceiling else [0, 1, 2, 1, 3, 2]
		for index in order:
			var q: Vector2 = points[index]; var y = L.floor_height(id, q)
			if ceiling: y += L.ceiling_height(id, q)
			vertices.append(Vector3(q.x, y, q.y)); normals.append(Vector3.DOWN if ceiling else Vector3.UP); uvs.append(q * 0.3)
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _shell(id: String) -> void:
	if id == "rootglow":
		var architecture = load("res://scripts/interior_architecture.gd")
		load("res://scripts/interior_surfaces.gd").build(live, L.cells(id), L.STEP, func (p: Vector2) -> float: return L.floor_height(id, p), func (p: Vector2) -> float: return L.ceiling_height(id, p), architecture.stone(9, true, false, true), architecture.stone(9, false, false, true), true)
		return
	var stone = B.world_surface("stone", "#667361" if id == "rootglow" else "#85816d")
	var floor_mat = B.world_surface("ground", "#52664c") if id == "rootglow" else B.world_surface("stone", "#938e78")
	var floor_mesh = _surface(id, false)
	B.mesh(live, floor_mesh, floor_mat).name = "AuthoredFloor"
	B.solid(live, Vector3.ZERO, floor_mesh.create_trimesh_shape()).name = "AuthoredFloorCollision"
	var roof_mesh = _surface(id, true)
	B.mesh(live, roof_mesh, stone).name = "AuthoredCeiling"
	B.solid(live, Vector3.ZERO, roof_mesh.create_trimesh_shape())
	var cells: Dictionary = L.cells(id)
	for cell in cells:
		var at = (Vector2(cell) + Vector2.ONE * 0.5) * L.STEP
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if cells.has(cell + direction): continue
			var p = at + Vector2(direction) * L.STEP * 0.5
			var h = L.ceiling_height(id, p); var y = L.floor_height(id, p)
			var size = Vector3(0.5, h + 0.3, L.STEP + 0.08) if direction.x != 0 else Vector3(L.STEP + 0.08, h + 0.3, 0.5)
			if id == "rootglow":
				var shape = BoxShape3D.new(); shape.size = size; B.solid(live, Vector3(p.x, y + h * 0.5, p.y), shape)
				var width = 2.8 + 0.3 * sin(p.x * 0.7 + p.y * 0.8)
				var bulge = B.ball(live, Vector3(p.x, y + h * 0.48, p.y), Vector3(width, h * 1.3, width), stone)
				bulge.rotation.y = p.x * 0.31 + p.y * 0.17
			else: B.box(live, Vector3(p.x, y + h * 0.5, p.y), size, stone, true)

func _at(id: String, p: Vector2, up: float = 0) -> Vector3:
	return Vector3(p.x, L.floor_height(id, p) + up, p.y)

func _lamp(p: Vector3, color: String, energy: float = 0.9) -> void:
	var light = OmniLight3D.new(); light.position = p; light.light_color = Color(color); light.light_energy = energy; light.omni_range = 15
	live.add_child(light)

func _rootglow_art() -> void:
	var root_mat = B.world_surface("timber", "#685641"); var moss = B.mat("#78935b"); var cap = B.mat("#75b6ac", 0, 0.3)
	var rng = RandomNumberGenerator.new(); rng.seed = world.state.seed_value + 2187
	for room in L.rooms("rootglow"):
		var p: Vector3 = _at("rootglow", room.p)
		if room.name != "Low return":
			for side in [-1.0, 1.0]:
				var path = [Vector3(side * 3, 0, 1.5), Vector3(side * 2.8, 1.7, 0.8), Vector3(side * 2.1, 3.1, 0.2), Vector3(side * 1, 3.8, -0.1), Vector3(0, 4, -0.3)]
				for segment in range(path.size() - 1): B.branch(live, p + path[segment], p + path[segment + 1], 0.28 - float(segment) * 0.045, root_mat, 0.85)
			B.cyl(live, p + Vector3(1, 3.8, -1), 0, 1.4, B.world_surface("stone", "#71816a"), false, 0.45)
		for i in range(5):
			var q: Vector2 = room.p + Vector2.from_angle(float(i) * TAU / 5) * rng.randf_range(2.8, 3.9)
			var spot = _at("rootglow", q)
			var height = rng.randf_range(0.35, 1.2)
			B.cyl(live, spot + Vector3.UP * height * 0.5, 0.07, height, B.mat("#c7bf93"))
			B.ball(live, spot + Vector3.UP * height, Vector3(0.9, 0.32, 0.9) * height, cap)
			for leaf in range(3): B.facet(live, spot + Vector3(leaf * 0.13, 0.2, 0), Vector3(0.12, 0.55, 0.09), moss).rotation.z = (leaf - 1) * 0.5
	var basin = _at("rootglow", Vector2(0, -27), 0.015)
	B.cyl(live, basin, 2.3, 0.025, B.mat("#61a6a3", 0.1, 0.4))
	_lamp(basin + Vector3(0, 2.7, 0), "#86ddd0", 1.4)
	_lamp(_at("rootglow", Vector2(-14, -24), 3), "#d7b578")
	_lamp(_at("rootglow", Vector2(1, -4), 2.8), "#d9c38a")
	Places.signboard(live, Vector3(0, 2, -0.5), "ROOTGLOW HOLLOW", 0, 4)
	var note = Places.interaction(live, "rootglow_fieldnote", "lore", "Read the forester's field note", _at("rootglow", Vector2(-14, -20), 0.7))
	note.set_meta("text", "The roots braid around the glowing pocket. Follow the fern-lit western passage down, or take the low eastern squeeze back to daylight. These are living roots, not a mason's corridors.")
	B.box(note, Vector3.ZERO, Vector3(0.5, 0.08, 0.35), B.mat("#d7c794"))

func _redoubt_art() -> void:
	var wood = B.world_surface("timber", "#71513d"); var cloth = B.world_surface("cloth", "#667c6b"); var iron = B.mat("#565f63", 0.55)

	for x in [-7.0, 7.0]:
		for z in [-34.0, -41.0, -48.0]:
			var at = Vector3(x, 0, z)
			B.box(live, at + Vector3(0, 0.28, 0), Vector3(2.1, 0.5, 3.4), wood, true)
			B.box(live, at + Vector3(0, 0.64, 0), Vector3(1.9, 0.28, 3.2), cloth)
			B.box(live, at + Vector3(0, 0.85, -1), Vector3(1.4, 0.2, 0.6), B.mat("#c4b99c"))
	for x in [-10.0, 10.0]:
		B.box(live, Vector3(x, 2, -28), Vector3(14, 4, 0.65), B.world_surface("stone", "#797c6c"), true)
	for x in [-12.0, 12.0]:
		B.cyl(live, Vector3(x, 2.8, -18), 0.7, 5.6, B.world_surface("stone", "#a4a08a"), true)
	var table = B.box(live, Vector3(0, 1.0, -20), Vector3(6, 0.25, 3.2), wood, true); table.name = "GarrisonMapTable"
	for x in [-2.5, 2.5]:
		for z in [-21.2, -18.8]: B.box(live, Vector3(x, 0.45, z), Vector3(0.18, 0.9, 0.18), wood)
	B.box(live, Vector3(0, 1.16, -20), Vector3(3.5, 0.03, 1.9), B.mat("#c3bb91"))
	for x in [-12.0, 12.0]:
		Places.bench(live, Vector3(x, 0, -16), PI * 0.5)
		B.box(live, Vector3(x, 3, -25), Vector3(1.5, 3.4, 0.07), B.world_surface("cloth", "#7f7057"))
	for p in [Vector3(-18, 0, -24), Vector3(18, 0, -24), Vector3(30, -3, -49), Vector3(43, -3, -39)]: Places.barrel(live, p)
	for x in [30.0, 43.0]:
		B.box(live, Vector3(x, -1.8, -50), Vector3(2.8, 2.4, 0.45), wood, true)
		for i in range(3):
			B.branch(live, Vector3(x - 1 + i, -2.8, -49.7), Vector3(x - 1 + i, -0.6, -49.7), 0.045, iron, 1)
	B.box(live, Vector3(35, -2.15, -47), Vector3(5, 0.2, 1.8), wood, true)
	for x in [33.0, 37.0]:
		for z in [-47.6, -46.4]: B.box(live, Vector3(x, -2.6, z), Vector3(0.16, 0.8, 0.16), wood)
	for i in range(3):
		var id = ["iron_blade", "mana_potion", "stone_pickaxe"][i]
		var item = Items.build(live, id) if Items.supports(id) else load("res://scripts/imported_assets.gd").place(live, "weapons_arming_sword" if id == "iron_blade" else "kaykit_pickaxe", Vector3.ZERO, 1)
		item.position = Vector3(33.3 + i * 1.6, -2.0, -47); item.scale = Vector3.ONE * 0.7
	Places.signboard(live, Vector3(0, 3, -27.5), "CEDARWATCH BARRACKS", 0, 5)
	Places.signboard(live, Vector3(12, 2, -42), "LOWER ARMORY  >", PI * 0.5, 3)
	Places.signboard(live, Vector3(14, 2, -20), "POSTERN / SURFACE", 0, 3)
	_lamp(Vector3(0, 5, -12), "#f1cf95", 1.5); _lamp(Vector3(0, 3, -40), "#e3bb7d", 1.2); _lamp(Vector3(36, 0, -43), "#d9bc8e", 1.3)

func _cache(id: String) -> void:
	var key = "mosswake_cache_" + id
	if world.state.taken.has(key): return
	var p = Vector2(-17, -29) if id == "rootglow" else Vector2(41, -46)
	var node = Places.interaction(live, key, "regional_cache", "Open the forester's cache" if id == "rootglow" else "Open the armory strongbox", _at(id, p, 0.35))
	node.set_meta("space", id)
	load("res://scripts/world_overhaul.gd").cache(node)

func claim_cache(node: Node3D) -> bool:
	if game == null or not is_instance_valid(node) or node.is_queued_for_deletion() or live == null or not live.is_ancestor_of(node): return false
	var s = game.state; var id = str(node.get_meta("id", ""))
	if not id.begins_with("mosswake_cache_") or s.taken.has(id): return false
	return Treasure.claim(game, node, id, Treasure.bundle(id))

func _encounters() -> void:
	if game == null or live == null or encounters_ready: return
	encounters_ready = true
	var positions = [Vector2(-14, -29), Vector2(14, -25)] if active_id == "rootglow" else [Vector2(4, -35), Vector2(40, -39)]
	for i in range(positions.size()):
		var id = "mosswake_enemy_" + active_id + "_" + str(i)
		if game.state.taken.has(id): continue
		var enemy = Enemy.new(); enemy.configure_species("rootling_sentinel" if active_id == "rootglow" else "thorn_wolf")
		enemy.game = game; enemy.id = id; enemy.position = _at(active_id, positions[i], 0.08); enemy.home = L.ORIGINS[active_id] + enemy.position
		live.add_child(enemy)
