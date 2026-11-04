extends RefCounted

const B = preload("res://scripts/build.gd")
const O = preload("res://scripts/world_overhaul.gd")
const A = preload("res://scripts/imported_assets.gd")
const Details = preload("res://scripts/household_details.gd")

static func service(purpose: String) -> bool: return purpose in ["stores", "workshop", "bakery", "inn", "smith_shop", "merchant_shop"]
static func layout(width: float, depth: float, purpose: String, identity: String) -> Dictionary:
	var half = width * 0.5; var length = minf(2.7, depth * 0.48); var shift = float(posmod(hash(identity), 5) - 2) * 0.025
	var keeper = Vector3(-minf(half - 0.65, 2.55), 0.035, -0.18 + shift)
	return {"keeper": keeper, "customer": Vector3(-0.43, 0.035, keeper.z), "counter": Vector3(-1.35, 0.035, keeper.z), "counter_size": Vector3(0.64, 0.82, length), "staff": Rect2(-half + 0.22, -depth * 0.5 + 0.25, maxf(0.9, half - 1.98), depth - 0.5), "purpose": purpose, "identity": identity}

static func prop(parent: Node3D, id: String, at: Vector3, size: Vector3, yaw: float = 0, solid: bool = false) -> Node3D:
	if A.entry(id).is_empty(): return null
	var fitted_size = Vector3(size.z, size.y, size.x) if absf(sin(yaw)) > 0.99 else size
	var node = O.fit(parent, id, at, fitted_size, yaw)
	if node != null:
		node.set_meta("furniture_id", id); node.set_meta("furniture_size", size); node.set_meta("furniture_solid", solid)
		if solid: O.support_box(node, Vector3(0, size.y * 0.5, 0) / node.scale, fitted_size / node.scale)
	return node

static func furnish(house: Node3D, width: float, depth: float, purpose: String, identity: String, region: int) -> void:
	var data = layout(width, depth, purpose, identity); var half = width * 0.5; var back = -depth * 0.5
	house.set_meta("shop_layout", data); house.set_meta("shop_kind", "smith" if purpose in ["workshop", "smith_shop"] else "general"); house.add_to_group("service_shop")
	var room = Node3D.new(); room.name = "ShopInterior"; house.add_child(room)
	var wood = B.world_surface("timber", "#70513a" if region != 10 else "#89667b"); var edge = B.world_surface("timber", "#a17e54")
	var counter = Node3D.new(); counter.name = "ServiceCounter"; counter.position = data.counter; counter.add_to_group("service_counter"); room.add_child(counter)
	var size: Vector3 = data.counter_size
	B.beveled_box(counter, Vector3(0, 0.39, 0), Vector3(size.x, 0.78, size.z), wood)
	B.box(counter, Vector3(0, 0.82, 0), Vector3(size.x + 0.12, 0.1, size.z + 0.12), edge)
	B.box(counter, Vector3(0, 0.435, 0), Vector3(size.x, 0.87, size.z), wood, true).visible = false
	counter.set_meta("furniture_id", "service_counter"); counter.set_meta("furniture_size", Vector3(size.x, 0.87, size.z)); counter.set_meta("furniture_solid", true)
	for z in [-size.z * 0.4, 0, size.z * 0.4]: B.box(counter, Vector3(size.x * 0.5 + 0.014, 0.38, z), Vector3(0.028, 0.65, 0.045), edge)
	for y in [0.13, 0.68]: B.box(counter, Vector3(size.x * 0.5 + 0.022, y, 0), Vector3(0.032, 0.055, size.z - 0.06), edge)
	prop(room, "kaykit_journal_closed", data.counter + Vector3(0, 0.875, -size.z * 0.3), Vector3(0.32, 0.09, 0.26), 0.08)
	var cup = "qprop_cup" if not A.entry("qprop_cup").is_empty() else "qprop_pot_1"
	prop(room, cup, data.counter + Vector3(0.02, 0.875, size.z * 0.3), Vector3(0.15, 0.2, 0.15))
	prop(room, "resource_iron_bars_stack_small" if house.get_meta("shop_kind") == "smith" else "qprop_farmcrate_apple", data.counter + Vector3(0, 0.875, 0.1), Vector3(0.42, 0.14, 0.4))
	B.box(room, Vector3(0.22, 0.043, 0.45), Vector3(1.75, 0.014, 1.65), B.world_surface("cloth", "#8a7662"))
	var wall_stock = Vector3(-half + 0.72, 0.95, back + 0.2)
	if house.get_meta("shop_kind") == "smith":
		prop(room, "qprop_peg_rack", wall_stock, Vector3(1.08, 0.6, 0.15))
		for i in range(3): prop(room, ["kaykit_axe", "kaykit_pickaxe", "kaykit_hammer"][i], wall_stock + Vector3(-0.32 + i * 0.32, -0.18, 0.08), Vector3(0.22, 0.75, 0.1))
	else:
		prop(room, "qprop_shelf_small_bottles", Vector3(-half + 0.65, 0.9, back + 0.25), Vector3(0.95, 0.8, 0.34))


	var shelf = Vector3(half - 0.49, 0.035, back + 1.1)
	prop(room, "qprop_shelf_simple", shelf, Vector3(0.62, 1.85, 1.55), PI * 0.5, true)
	var stock = Details.stock("workshop" if house.get_meta("shop_kind") == "smith" else purpose, identity)
	for row in range(3):
		var y = 0.24 + row * 0.53
		B.box(room, shelf + Vector3(0, y, 0), Vector3(0.59, 0.065, 1.48), edge)
		for col in [-1, 1]:
			var id = stock[row * 2 + (0 if col < 0 else 1)]
			if not A.entry(id).is_empty(): prop(room, id, shelf + Vector3(0, y + 0.035, col * 0.38), Vector3(0.34, 0.3, 0.31))
	prop(room, "qprop_cabinet", Vector3(half - 0.55, 0.035, 0.55), Vector3(0.78, 1.05, 0.85), 0, true)
	prop(room, "qprop_barrel", Vector3(-half + 0.48, 0.035, depth * 0.5 - 0.55), Vector3(0.7, 0.78, 0.7), 0, true)
	prop(room, "kaykit_lantern", Vector3(half - 0.55, 1.09, 0.55), Vector3(0.25, 0.4, 0.23))
	if house.get_meta("shop_kind") == "smith":
		prop(room, "kaykit_anvil", Vector3(half - 0.63, 0.035, depth * 0.5 - 0.55), Vector3(0.9, 0.78, 0.63), 0, true)
		prop(room, "weapons_anvil_hammer", Vector3(half - 0.63, 0.816, depth * 0.5 - 0.55), Vector3(0.38, 0.15, 0.18), 0.18)
	else:
		prop(room, "qprop_farmcrate_apple", Vector3(half - 0.55, 0.035, depth * 0.5 - 0.55), Vector3(0.78, 0.65, 0.68), 0, true)
	var light = OmniLight3D.new(); light.name = "ShopWarmLight"; light.position = Vector3(0, 2.4, -0.3); light.omni_range = 5.5; light.light_energy = 0.55; light.light_color = Color("#ffe1b0"); light.shadow_enabled = false; light.distance_fade_enabled = true; light.distance_fade_begin = 26; room.add_child(light)
	house.set_meta("fixtures", ["counter", "shelf", "stock", "cup", "light", "storage", "ledger", "anvil" if house.get_meta("shop_kind") == "smith" else "provisions"]); house.set_meta("asset_dressing", true)

static func smith_bay(house: Node3D, width: float, depth: float, region: int = 9) -> void:
	if house.get_node_or_null("CoveredForgeBay") != null: return
	var bay = Node3D.new(); bay.name = "CoveredForgeBay"; bay.add_to_group("covered_forge"); bay.add_to_group("working_forge"); house.add_child(bay)
	bay.set_meta("replacement_art", 29); bay.set_meta("shop_revision", 35)
	var start = width * 0.5 + 0.14; var finish = start + 3.55; var middle = (start + finish) * 0.5; var length = minf(5.8, depth)
	var stone = B.world_surface("stone", "#908779"); var dark = B.world_surface("stone", "#655f58"); var wood = B.world_surface("timber", "#5c4635"); var iron = B.mat("#454b4d", 0.58)
	B.box(bay, Vector3(middle, -0.12, 0), Vector3(finish - start, 0.3, length), stone, true)
	for x in [start + 0.08, finish - 0.08]:
		for z in [-length * 0.5 + 0.2, length * 0.5 - 0.2]:
			B.box(bay, Vector3(x, 1.42, z), Vector3(0.18, 2.84, 0.2), wood, true)
		B.box(bay, Vector3(x, 2.75, 0), Vector3(0.22, 0.21, length + 0.25), wood)
	B.box(bay, Vector3(middle, 2.78, -length * 0.5 + 0.18), Vector3(finish - start, 0.22, 0.22), wood)
	var roof = B.box(bay, Vector3(middle, 2.95, 0), Vector3(finish - start + 0.42, 0.16, length + 0.5), B.world_surface("stone", "#5a6065")); roof.rotation.z = -0.12

	for i in range(7):
		var x = lerpf(start - 0.1, finish + 0.1, float(i) / 6)
		var tile = B.box(bay, Vector3(x, 2.98 - (x - middle) * 0.12 + 0.014, 0), Vector3(0.61, 0.075, length + 0.52), B.world_surface("stone", "#61676c" if i % 2 else "#596066")); tile.rotation.z = -0.12
	var hearth = Node3D.new(); hearth.name = "StoneForgeHearth"; hearth.position = Vector3(start + 0.95, 0.035, -length * 0.24); hearth.add_to_group("shop_hearth"); bay.add_child(hearth)
	B.box(hearth, Vector3(0, 0.21, 0), Vector3(1.55, 0.42, 1.25), dark, true)
	B.box(hearth, Vector3(0, 0.98, -0.48), Vector3(1.55, 1.55, 0.3), stone, true)
	for side in [-1, 1]: B.box(hearth, Vector3(side * 0.64, 0.97, 0), Vector3(0.27, 1.25, 1.18), stone, true)
	B.box(hearth, Vector3(0, 1.67, -0.03), Vector3(1.65, 0.26, 1.34), dark, true)
	B.box(hearth, Vector3(0, 2.7, -0.29), Vector3(0.77, 1.85, 0.76), stone, true)
	for y in [1.96, 2.4, 2.84, 3.28]: B.box(hearth, Vector3(0, y, -0.29), Vector3(0.84, 0.1, 0.83), dark)
	B.box(hearth, Vector3(0, 3.7, -0.29), Vector3(0.96, 0.18, 0.94), dark)
	B.flame(hearth, Vector3(0, 0.46, 0.1), Vector3(0.72, 0.82, 0.64))
	for i in range(5): B.box(hearth, Vector3(-0.44 + i * 0.22, 0.46, 0.12), Vector3(0.055, 0.055, 0.9), iron)
	prop(bay, "interior_mdvl_interiors_anvil_01", Vector3(finish - 0.78, 0.035, -0.3), Vector3(1.15, 1.02, 0.72), 0, true)
	prop(bay, "kaykit_grindstone", Vector3(finish - 0.78, 0.035, 1.25), Vector3(0.9, 1.08, 0.7), 0, true)
	prop(bay, "qprop_weaponstand", Vector3(finish - 0.7, 0.035, -length * 0.5 + 0.48), Vector3(1.05, 1.65, 0.42), 0, true)
	for i in range(3): prop(bay, ["kaykit_axe", "kaykit_pickaxe", "weapons_arming_sword"][i], Vector3(finish - 1.04 + i * 0.33, 0.72, -length * 0.5 + 0.52), Vector3(0.26, 1.12, 0.1))
	prop(bay, "resource_iron_bars_stack_small", Vector3(start + 0.55, 0.035, length * 0.34), Vector3(0.64, 0.25, 0.4))
	prop(bay, "kaykit_bucket_metal", Vector3(start + 1.45, 0.035, length * 0.37), Vector3(0.43, 0.48, 0.43))
	prop(bay, "weapons_anvil_hammer", Vector3(finish - 0.78, 1.07, -0.3), Vector3(0.44, 0.15, 0.2), 0.15)
	var glow = OmniLight3D.new(); glow.position = hearth.position + Vector3(0, 1, 0.4); glow.light_color = Color("#ff9b50"); glow.light_energy = 0.85; glow.omni_range = 4; glow.shadow_enabled = false; glow.distance_fade_enabled = true; glow.distance_fade_begin = 24; bay.add_child(glow)
	B.merge_colored(bay); B.batch_static(bay)

static func find_shop(parent: Node3D, kind: String) -> Node3D:
	if parent.get_meta("shop_kind", "") == kind: return parent
	for node in parent.find_children("*", "Node3D", true, false):
		if node.get_meta("shop_kind", "") == kind: return node
	return null

static func available_shop(parent: Node3D, kind: String, vendor_id: String) -> Node3D:
	var available: Node3D
	for node in parent.find_children("*", "Node3D", true, false):
		if node.get_meta("shop_kind", "") != kind: continue
		if node.get_meta("shop_vendor_id", "") == vendor_id: return node
		if str(node.get_meta("shop_vendor_id", "")).is_empty() and (available == null or node.get_meta("purpose", "") == "stores"): available = node
	return available

static func frontage(house: Node3D, width: float, depth: float, title: String) -> void:
	var sign = Node3D.new(); sign.name = "ShopNameplate"; sign.position = Vector3(0, 2.78, depth * 0.5 + 0.34); house.add_child(sign)
	B.beveled_box(sign, Vector3.ZERO, Vector3(minf(width - 0.8, 3.1), 0.43, 0.1), B.world_surface("timber", "#594431"))
	var label = Label3D.new(); label.text = title.to_upper(); label.font = preload("res://assets/fonts/body.ttf"); label.font_size = 29; label.pixel_size = 0.0035; label.position = Vector3(0, 0, 0.061); label.modulate = Color("#f1dfb1"); label.outline_size = 3; sign.add_child(label)

static func _root_frame(node: Node3D) -> Transform3D:


	var frame = Transform3D.IDENTITY; var cursor: Node = node
	while cursor != null:
		var part = cursor as Node3D
		if part != null:
			frame = part.transform * frame
			if part.top_level: break
		cursor = cursor.get_parent()
	return frame

static func bind_vendor(actor: Node3D, house: Node3D) -> void:
	var data: Dictionary = house.get_meta("shop_layout", {})
	if data.is_empty(): return
	var parent = actor.get_parent() as Node3D; var center: Vector3 = data.keeper
	var frame = _root_frame(parent).affine_inverse() * _root_frame(house)
	var route = PackedVector3Array()
	for z in [-0.23, 0.23]: route.append(frame * (center + Vector3(0, 0, z)))
	actor.route = route; actor.position = frame * center; actor.route_index = 1; actor.wait_left = 2.2
	actor.work_target = frame * data.customer
	var facing = actor.work_target - actor.position; actor.rotation.y = atan2(facing.x, facing.z)
	actor.set_meta("shop_owner", actor.get_path_to(house)); actor.set_meta("shop_owner_id", house.get_meta("plot_id", house.name)); actor.add_to_group("shopkeeper")
	house.set_meta("shop_vendor_id", str(actor.get_meta("id", actor.name)))
