extends RefCounted


const Map = preload("res://scripts/fixed_world.gd")
const B = preload("res://scripts/build.gd")
const P = preload("res://scripts/locations.gd")
const Trees = preload("res://scripts/regional_trees.gd")
static func tree(world, root: Node3D, key: Vector2i, record: Dictionary):
	var p: Vector3 = record.point; var at = Vector2(root.position.x + p.x, root.position.z + p.z)
	var id = str(record.get("id", "atlas_tree_%s_%s_%s" % [key.x, key.y, record.slot]))
	if world.state.taken.has(id) or not world.decoration_allowed(root, Vector2(p.x, p.z), 2.0): return
	var tree = preload("res://scripts/harvestable.gd").new(); tree.world = world; tree.position = p; root.add_child(tree)
	tree.set_meta("id", id); tree.set_meta("kind", "tree"); tree.set_meta("label", "Chop timber")
	tree.add_to_group("interactable"); tree.add_to_group("harvestable"); tree.add_to_group("batch_dynamic"); tree.set_process(false)
	Trees.place(tree, int(record.region), Trees.nominal_height(int(record.region)) * float(record.size), float(record.yaw))
	var shape = CylinderShape3D.new(); shape.height = 7 * float(record.size); shape.radius = 0.4 * float(record.size)
	tree.collider = B.solid(tree, Vector3.UP * shape.height * 0.5, shape)
	if int(record.region) == 10 or (int(record.region) == 9 and int(record.slot) % 4 == 0):
		var food_id = "food_" + id; var item = ["marshmallow", "chocolate_bar", "graham_cracker"][int(record.slot) % 3 if int(record.region) == 10 else 0]
		if not world.state.taken.has(food_id):
			var food = P.interaction(root, food_id, "material", "Gather " + item.replace("_", " "), p + Vector3(1.4, 0.18, 1.0))
			food.set_meta("item", item); food.set_meta("amount", 1); food.set_meta("regional_food", true)
			var crown = Node3D.new(); crown.name = "CanopyFood"; food.add_child(crown)
			crown.position = p - food.position; crown.rotation.y = float(record.yaw)
			var height = Trees.nominal_height(int(record.region)) * float(record.size)
			for anchor in Trees.food_anchors(int(record.region)):
				var anchor_point: Vector3 = anchor * height; var drop = 0.16
				var model = preload("res://scripts/item_models.gd").build(crown, item)
				var footprint = preload("res://scripts/imported_assets.gd").bounds(model).size
				model.scale = Vector3.ONE * (2.7 if item == "marshmallow" else 0.5 / maxf(maxf(footprint.x, footprint.z), 0.001))
				var top = preload("res://scripts/imported_assets.gd").bounds(model).end.y - crown.global_position.y
				model.position = anchor_point - Vector3.UP * (drop + top)
				B.cyl(crown, anchor_point - Vector3.UP * drop * 0.5, 0.028, drop, B.mat("#d4bdc7"))


			tree.tree_exiting.connect(_drop_food.bind(food), CONNECT_ONE_SHOT)
	if int(record.slot) % 3 == 0:
		var q = Vector2(p.x + 3.4, p.z - 2.5)
		if world.decoration_allowed(root, q, 1.4): preload("res://scripts/world_overhaul.gd").ground(root, int(record.region), Vector3(q.x, world.height_at(root.position.x + q.x, root.position.z + q.y), q.y), int(record.slot), str(record.get("ground_id", "")))
static func _drop_food(food):
	if not is_instance_valid(food) or not food.is_inside_tree() or food.is_queued_for_deletion(): return
	var renderer = food.get_meta("chunk_renderer") if food.has_meta("chunk_renderer") else null
	if renderer is WeakRef and is_instance_valid(renderer.get_ref()): renderer.get_ref().release(food)
	for child in food.get_children(): child.free()
	var model = preload("res://scripts/item_models.gd").build(food, str(food.get_meta("item")))
	model.scale = Vector3.ONE * 1.6
	var bottom = preload("res://scripts/imported_assets.gd").bounds(model).position.y - food.global_position.y
	model.position.y = -0.16 - bottom
static func cover(world, root: Node3D, index: int, tile: int, quality: int, layout: Dictionary):
	var record: Dictionary = Map.cover_record(Vector2i(roundi(root.position.x / 48), roundi(root.position.z / 48)), index, tile)
	var biome = world.biome_at(root.position.x + 24, root.position.z + 24)
	for row in record.blades.slice(0, [4, 7, 8][quality]):
		if biome == 13: continue
		var p = Vector2(row[0], row[1])
		if not world.decoration_allowed(root, p, 0.85): continue
		var y = world.surface_height_at(root.position.x + p.x, root.position.z + p.y)
		var frame = Transform3D(Basis(Vector3.UP, row[2]).scaled(Vector3(row[3], row[4], row[5])), Vector3(p.x, y + 0.015, p.y))
		layout["meadow" if index % 3 == 0 else "grass"].append(frame)
	for decor_index in range(mini(3, record.decor.size())):
		var row = record.decor[decor_index]
		var p = Vector2(row[0], row[1]); var family = 3 if biome == 13 else int(record.family)
		if not world.decoration_allowed(root, p, 1.25 if family == 1 else 0.65): continue
		var y = world.surface_height_at(root.position.x + p.x, root.position.z + p.y)
		var frame = Transform3D(Basis(Vector3.UP, row[2]).scaled(Vector3.ONE * float(row[3])), Vector3(p.x, y + 0.02, p.y))
		layout[["flowers", "ferns", "mushrooms", "pebbles", "flowers"][family]].append(frame)
		if family == 3:
			var stable_ids: Array = record.get("pebble_ids", [])
			layout.get_or_add("pebble_ids", []).append(str(stable_ids[decor_index]) if decor_index < stable_ids.size() else "")
static func item(world, root: Node3D, key: Vector2i, record: Dictionary):
	var slot = int(record.slot); var p: Vector3 = record.point
	if not world.decoration_allowed(root, Vector2(p.x, p.z), 0.6): return
	var id = str(record.get("id", "%s_%s_%s" % [key.x, key.y, slot] if slot < 3 else "carry_%s_%s_%s" % [key.x, key.y, slot - 3]))
	if world.state.taken.has(id): return
	if slot < 3: world.pickup(root, p, id, "shard")
	else: world.carryable(root, p + Vector3.UP * 0.4, slot - 3, id)
static func loose(world, root: Node3D, key: Vector2i, record: Dictionary):
	var slot = int(record.slot); var p: Vector3 = record.point; var material = "stone" if slot % 2 == 0 else "stick"
	var id = str(record.get("id", "loose_%s_%s_%s_%s" % [material, key.x, key.y, slot]))
	if world.state.taken.has(id) or not world.decoration_allowed(root, Vector2(p.x, p.z), 0.7) or not world.loose_point_clear(root, p): return
	world.carryable(root, p + Vector3.UP * 0.4, 0 if slot % 2 == 0 else 2, id)
