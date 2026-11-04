extends RefCounted

const A = preload("res://scripts/imported_assets.gd")
const B = preload("res://scripts/build.gd")
const S = preload("res://scripts/region_sites.gd")

static func fit(parent: Node3D, id: String, at: Vector3, size: Vector3, yaw: float = 0) -> Node3D:
	var entry = A.entry(id)
	if entry.is_empty(): return null
	var bounds = entry.bounds_size
	var model = A.place(parent, id, at, 1.0, yaw)
	model.scale = Vector3(size.x / maxf(0.0001, float(bounds[0])), size.y, size.z / maxf(0.0001, float(bounds[2])))
	model.set_meta("overhaul_prop", true)
	return model

static func structural(node: Node3D) -> void:
	for geometry in node.find_children("*", "GeometryInstance3D", true, false):
		geometry.remove_from_group("imported_detail"); geometry.visibility_range_end = 0
	node.set_meta("structural_art", true)

static func tree(parent: Node3D, region: int, variant: int, height: float) -> bool:
	if region in [9, 10, 11, 12, 13, 14, 15]:
		load("res://scripts/regional_trees.gd").place(parent, region, height, variant * 2.39996); return true
	if region not in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 13, 14]: return false
	var id = "qnat_commontree_" + str(1 + posmod(variant, 5))
	if region in [4, 8] or (region == 9 and variant % 3 == 0): id = "qnat_pine_" + str(1 + posmod(variant, 5))
	if region in [5, 6, 7, 13, 14]: id = "qnat_deadtree_" + str(1 + posmod(variant, 5))
	var model = A.place(parent, id, Vector3.ZERO, height, variant * 2.39996)
	if model == null: return false


	var original: MeshInstance3D = model.get_child(0)
	var mesh = MultiMeshInstance3D.new(); mesh.name = "WholeAuthoredTree"
	mesh.multimesh = MultiMesh.new(); mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.multimesh.mesh = original.mesh; mesh.multimesh.instance_count = 1
	mesh.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	mesh.set_meta("instance_transforms", [Transform3D.IDENTITY]); mesh.visibility_range_end = 0
	model.add_child(mesh); original.free(); model.set_meta("whole_tree", true)
	return true

static func roof(parent: Node3D, width: float, depth: float, region: int, eaves: float = 4.15, rise: float = 2.05) -> bool:
	if region not in [9, 10, 11]: return false
	var model = fit(parent, "qv_roof_roundtiles_6x8", Vector3(0, eaves, 0), Vector3(width + 0.85, rise, depth + 0.95))
	if model == null: return false
	model.name = "AuthoredTileRoof"; structural(model)
	var soffit = B.box(parent, Vector3(0, eaves + 0.08, 0), Vector3(width, 0.1, depth), B.world_surface("timber", "#89715b"))
	soffit.name = "RoofSoffit"
	return true

static func facade(parent: Node3D, width: float, depth: float, purpose: String, region: int, index: int) -> void:
	var z = depth * 0.5 + 0.22


	var shutter_width = minf(2.05, 2 * (width * 0.3 - 1.18))
	var window_width = 1.35 * shutter_width / 2.05
	for side in [-1, 1]:
		var at = Vector3(side * width * 0.3, 1.42, z)
		var window = fit(parent, "qv_window_wide_flat1", at, Vector3(window_width, 1.5, 0.12))
		if window: structural(window)
		var shutters = fit(parent, "qv_windowshutters_wide_flat_open", at + Vector3(0, -0.03, 0.1), Vector3(shutter_width, 1.55, 0.22))
		if shutters: structural(shutters)
	if region in [9, 10, 11]:
		var chimney = fit(parent, "qv_prop_chimney2" if index % 2 else "qv_prop_chimney", Vector3(-width * 0.27, 4.7, -depth * 0.23), Vector3(0.9, 2.25, 0.85))
		if chimney: structural(chimney)
		if index % 3 == 0: fit(parent, "qv_prop_vine1", Vector3(width * 0.47, 0.25, z + 0.07), Vector3(0.85, 3.1, 0.14))
		if index % 4 == 0: A.place(parent, "avra_allassets_with_texture_streetlamp_01", Vector3(width * 0.43, 0.02, depth * 0.5 + 1.1), 3.2)


	if purpose in ["bakery", "stores", "inn"]:
		var stall_width = minf(2.5, 2 * (width * 0.32 - 1.2))
		var stall = fit(parent, "qprop_stall_empty", Vector3(-width * 0.32, 0.04, depth * 0.5 + 1), Vector3(stall_width, 2.9, 1.15))
		if stall:
			var id = "treat_bread" if purpose == "bakery" else "qprop_farmcrate_apple"
			var height = 0.24 if purpose == "bakery" else 0.47
			var bounds = A.entry(id).bounds_size
			fit(parent, id, Vector3(-width * 0.32, 1.02, depth * 0.5 + 1.03), Vector3(minf(float(bounds[0]) * height, stall_width * 0.82), height, float(bounds[2]) * height))
	parent.set_meta("polished_facade", true); parent.set_meta("overhaul_facade", true)

static func ground(parent: Node3D, region: int, at: Vector3, variant: int, stable_id: String = "") -> void:
	var rock = "qnat_rock_medium_" + str(1 + posmod(variant, 3))
	var world = parent
	while world != null and not world.has_method("surface_height_at"): world = world.get_parent()
	var holder: Node3D = parent; var rock_at = at
	if world != null:
		var point = parent.to_global(at); var id = stable_id if not stable_id.is_empty() else "ground_rock_%d_%d" % [roundi(point.x * 32), roundi(point.z * 32)]
		if not world.state.taken.has(id):
			holder = load("res://scripts/mineable.gd").new(); holder.world = world; holder.position = at
			holder.set_meta("id", id); holder.set_meta("item", "stone"); holder.set_meta("amount", 3); holder.set_meta("authored_outcrop", true)
			parent.add_child(holder); rock_at = Vector3.ZERO
		else: holder = null
	if holder != null:
		var model = A.place(holder, rock, rock_at, 0.48 + posmod(variant, 3) * 0.15, variant * 1.7)
		if world != null and model != null:

			var bounds = holder.global_transform.affine_inverse() * A.bounds(model)
			var shape = BoxShape3D.new(); shape.size = bounds.size.max(Vector3.ONE * 0.05)
			holder.collider = B.solid(holder, bounds.get_center(), shape)
	if region in [9, 10, 11]:
		var grass = A.place(parent, "qnat_fern_1" if region == 9 else "qnat_grass_wispy_tall", at + Vector3(0.6, 0.01, 0.25), 0.6, variant * 0.8)
		if region == 10 and grass: preload("res://scripts/regional_ground.gd").paint_model(grass, "smorewood_wispy", ["#d493b7"])
		if variant % 2 == 0:
			var flowers = A.place(parent, "qnat_flower_3_group", at + Vector3(-0.5, 0.01, 0.3), 0.42, variant * 0.4)
			if region == 10 and flowers: preload("res://scripts/regional_ground.gd").paint_model(flowers, "smorewood_flowers", ["#cf91b9", "#f2d8e4"])
	elif region == 14: A.place(parent, "qnat_mushroom_common", at + Vector3(0.65, 0.01, 0), 0.3, variant * 0.7)
	elif region == 15: A.place(parent, "zappy_crystal", at + Vector3(0.65, 0.01, 0), 0.65, variant * 0.7)

static func yard(parent: Node3D, region: int, variant: int) -> void:
	var group = Node3D.new(); group.name = "OverhaulWorkSupplies"; parent.add_child(group)
	A.place(group, "qprop_crate_wooden", Vector3(1.7, 0, 1.2), 0.7, 0.1)
	A.place(group, "resource_wood_log_stack", Vector3(-1.5, 0, 1.3), 0.8, 0.6)
	A.place(group, "qprop_bag", Vector3(2.4, 0.02, 0.7), 0.6, 0.2)

static func support_box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var shape = BoxShape3D.new(); shape.size = size; B.solid(parent, at, shape)

static func table(parent: Node3D, p: Vector3, size: Vector2) -> bool:
	var model = fit(parent, "qprop_table_large", p, Vector3(size.x, 0.93, size.y))
	if model == null: return false
	support_box(parent, p + Vector3.UP * 0.85, Vector3(size.x, 0.16, size.y))
	return true

static func shelf(parent: Node3D, p: Vector3, width: float, books: bool) -> bool:
	var model = fit(parent, "qprop_bookcase_2" if books else "qprop_shelf_simple", p, Vector3(width, 2.3, 0.46))
	if model == null: return false
	for side in [-1, 1]: support_box(parent, p + Vector3(side * width * 0.5, 1.15, 0), Vector3(0.15, 2.3, 0.45))
	if books:
		for row in range(3):
			for side in [-1, 1]: A.place(parent, "qprop_bookgroup_small_1" if side < 0 else "qprop_bookgroup_small_2", p + Vector3(side * width * 0.24, 0.18 + row * 0.58, 0.02), 0.35)
	return true

static func bed(parent: Node3D, p: Vector3) -> bool:
	if fit(parent, "qprop_bed_twin1", p, Vector3(1.8, 1.12, 3.2)) == null: return false
	support_box(parent, p + Vector3.UP * 0.28, Vector3(1.8, 0.5, 3.2)); return true

static func room(parent: Node3D, width: float, depth: float, purpose: String, region: int, weathered: bool) -> void:
	var group = Node3D.new(); group.name = "OverhaulRoom"; parent.add_child(group)
	group.set_meta("room_style", purpose)
	var words = purpose.to_lower(); var left = -width * 0.5 + 1.4; var back = -depth * 0.5 + 1.1
	if any_word(words, ["library", "archive", "study", "map", "observatory", "instrument"]):
		A.place(group, "qprop_book_stack_1", Vector3(-width * 0.22 - 0.78, 0.95, -0.88), 0.23, 0.2)
		A.place(group, "qprop_candlestick_triple", Vector3(-width * 0.22 + 0.8, 0.95, -0.8), 0.43)
		A.place(group, "qprop_scroll_1", Vector3(-width * 0.22 - 0.6, 0.95, 0.1), 0.18, 0.5)
		A.place(group, "qprop_bookstand", Vector3(left, 0.02, -depth * 0.05), 1.35, 0.2)
		A.place(group, "curio_magestaff_low", Vector3(left - 0.5, 0.02, back + 1.5), 1.7, 0.1)
	elif any_word(words, ["armory", "guard", "prison", "vault", "clock", "work", "kiln", "forge"]):
		A.place(group, "qprop_weaponstand", Vector3(left, 0.02, back + 2.4), 1.65, PI * 0.15)
		fit(group, "qprop_crate_wooden", Vector3(left + 1.4, 0.02, back + 0.6), Vector3(0.85, 0.72, 0.75))
		A.place(group, "resource_iron_bars_stack_small", Vector3(left + 1.4, 0.74, back + 0.6), 0.27, 0.2)
		A.place(group, "resource_copper_nuggets", Vector3(width * 0.25 + 0.65, 0.96, back + 1.35), 0.16)
		A.place(group, "rpg_shield_01", Vector3(left - 0.2, 0.12, back + 2.4), 1.05, 0.3)
	elif any_word(words, ["kitchen", "bak", "pantry", "food", "stores", "scullery", "inn", "tavern"]):
		A.place(group, "treat_bread", Vector3(width * 0.24 - 0.7, 1.055, back + 1), 0.22, 0.15)
		A.place(group, "treat_cake_chocolate_slice", Vector3(width * 0.24, 1.055, back + 1), 0.24, 0.4)
		A.place(group, "treat_croissant", Vector3(width * 0.24 + 0.6, 1.055, back + 1), 0.18, 0.1)
		A.place(group, "qprop_cauldron", Vector3(left, 0.02, 1.4), 0.85)
		A.place(group, "potion_round_bottle", Vector3(width * 0.24 + 0.8, 0.95, back + 0.65), 0.34)
	elif any_word(words, ["tomb", "pyramid", "crypt", "ceremony", "chapel", "temple", "great hall", "ballroom", "throne", "council", "gallery", "landing"]):
		A.place(group, "ruin_vase", Vector3(left, 0.02, depth * 0.16), 0.9)
		A.place(group, "dungeon_chest_gold", Vector3(width * 0.32, 0.02, back + 1), 0.7)
		A.place(group, "dungeon_banner_patternb_brown" if weathered else "dungeon_banner_patterna_blue", Vector3(width * 0.35, 1.7, back - 0.1), 1.65)
		A.place(group, "qprop_coin_pile", Vector3(width * 0.32, 0.73, back + 1), 0.1)
	else:
		fit(group, "qprop_nightstand_shelf", Vector3(left + 1.5, 0.02, back + 2.2), Vector3(0.72, 0.7, 0.65))
		A.place(group, "potion_heart_bottle", Vector3(left + 1.5, 0.72, back + 2.2), 0.27)
		A.place(group, "qprop_mug", Vector3(width * 0.27 + 0.4, 0.95, back + 1.15), 0.2)
		A.place(group, "interior_mdvl_interiors_pottedplant_01", Vector3(-width * 0.36, 0.02, depth * 0.24), 0.8)
	fit(group, "small_broom_a", Vector3(left - 1, 0.02, depth * 0.18), Vector3(0.28, 1.15, 0.18), 0.25)
	parent.set_meta("overhaul_room", purpose)

static func cave(parent: Node3D, record: Dictionary, room_data: Dictionary) -> void:
	var size: Vector2 = room_data.size; var natural = str(record.get("kind", "cave")) == "cave"
	var level = int(room_data.level); var base_floor = S.floor_height(record.id, room_data.p, level)
	var corner = 0.36 if room_data.shape == "rect" else 0.3
	for i in range(4 if natural else 2):


		var at = Vector3((1 if i % 2 else -1) * size.x * corner, 0, (1 if i < 2 else -1) * size.y * corner)
		if not natural: at = Vector3((1 if i % 2 else -1) * size.x * 0.25, 0, size.y * 0.32)
		at.y = S.floor_height(record.id, room_data.p + Vector2(at.x, at.z), level) - base_floor
		var id = "qnat_rock_medium_" + str(1 + i % 3) if natural else "ruin_pillarsquarecut"
		A.place(parent, id, at, 1.0 + i * 0.14 if natural else 2.6, i * 0.7)
		if natural and i % 2 == 0:
			var mushroom = at + Vector3(0.5, 0, 0.2)
			mushroom.y = S.floor_height(record.id, room_data.p + Vector2(mushroom.x, mushroom.z), level) - base_floor + 0.02
			A.place(parent, "qnat_mushroom_common", mushroom, 0.48)
	parent.set_meta("overhaul_depth_art", true)

static func cache(parent: Node3D) -> bool:
	load("res://scripts/treasure_art.gd").build(parent, Vector3(1.2, 0.7, 0.8))
	support_box(parent, Vector3.ZERO, Vector3(1.2, 0.7, 0.8)); return true

static func any_word(value: String, words: Array) -> bool:
	for word in words:
		if word in value: return true
	return false
