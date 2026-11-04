extends RefCounted

const A = preload("res://scripts/imported_assets.gd")
const B = preload("res://scripts/build.gd")
const STOCK = {
	"home": ["qprop_bookgroup_small_1", "qprop_book_stack_2", "qprop_pot_1", "kaykit_journal_closed", "qprop_bag", "qprop_table_plate"],
	"inn": ["qprop_table_plate", "qprop_bottle_1", "treat_bread_roll", "qprop_pot_1", "qprop_bag", "zappy_bowl_04"],
	"bakery": ["treat_bread", "treat_bread_roll", "qprop_bag", "zappy_bowl_04", "qprop_pot_1", "qprop_bottle_1"],
	"workshop": ["resource_iron_bars_stack_small", "qprop_bag", "kaykit_rope_bundle_a", "kaykit_blueprint_stacked", "qprop_bottle_1", "qprop_bucket_metal"],
	"library": ["qprop_bookgroup_small_1", "qprop_bookgroup_small_2", "qprop_bookgroup_small_3", "qprop_book_stack_1", "qprop_book_stack_2", "kaykit_map_rolled"],
	"stores": ["qprop_bag", "qprop_bottle_1", "qprop_pot_1", "kaykit_rope_bundle_a", "qprop_bucket_metal", "kaykit_journal_closed"]}

static func stock(purpose: String, identity: String) -> Array:
	var pool: Array = STOCK.get(purpose, STOCK.home); var phase = posmod(hash(identity + ":belongings"), pool.size()); var result = []
	for i in range(6): result.append(pool[(phase + i) % pool.size()])
	return result

static func place(parent: Node3D, id: String, at: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> Node3D:
	var n = A.place(parent, id, Vector3.ZERO, 1)
	if n == null: return null
	var leaf: MeshInstance3D = n.get_child(0); var turn = Basis.from_euler(rotation)
	var box = Transform3D(turn, Vector3.ZERO) * leaf.transform * leaf.mesh.get_aabb()
	n.basis = Basis.from_scale(size / box.size) * turn
	box = n.transform * leaf.transform * leaf.mesh.get_aabb()
	n.position = at - Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return n

static func table(parent: Node3D, profile: Dictionary) -> void:
	var group = Node3D.new(); group.name = "HouseholdWorkSurface"; parent.add_child(group)
	group.position = profile.table + Vector3(-0.25, 0.782, -0.17)
	match str(profile.purpose):
		"home", "inn":
			place(group, "qprop_table_plate", Vector3.ZERO, Vector3(0.44, 0.026, 0.4))
			place(group, "treat_bread_roll", Vector3(0, 0.028, 0), Vector3(0.21, 0.14, 0.21))
		"bakery":
			place(group, "zappy_bowl_04", Vector3(-0.08, 0, 0), Vector3(0.32, 0.11, 0.32))
			place(group, "kaykit_knife", Vector3(0.15, 0, 0), Vector3(0.055, 0.025, 0.3), Vector3(PI * 0.5, 0, 0))
		"workshop":
			place(group, "kaykit_blueprint_stacked", Vector3.ZERO, Vector3(0.48, 0.018, 0.36))
			place(group, "kaykit_hammer", Vector3(0.03, 0.02, 0), Vector3(0.22, 0.1, 0.28), Vector3(PI * 0.5, 0, 0))
		"library":
			place(group, "kaykit_journal_open", Vector3.ZERO, Vector3(0.48, 0.055, 0.34), Vector3(-PI * 0.5, 0, 0))
			place(group, "kaykit_compass_base", Vector3(0.1, 0.057, 0), Vector3(0.115, 0.045, 0.125))
		_:
			place(group, "kaykit_map_rolled", Vector3(-0.08, 0, 0), Vector3(0.065, 0.065, 0.34))
			place(group, "kaykit_rope_bundle_a", Vector3(0.1, 0, 0.035), Vector3(0.24, 0.044, 0.1))

static func windows(parent: Node3D, width: float, depth: float, region: int, variant: int) -> void:
	if width < 5.2: return
	var group = Node3D.new(); group.name = "HouseholdWindowGardens"; parent.add_child(group)
	for side in [-1, 1]:
		var center = Vector3(side * width * 0.31, 1.005, depth * 0.5 + 0.47)
		B.box(group, center + Vector3(0, -0.03, 0), Vector3(0.68, 0.06, 0.5), B.world_surface("timber", "#76644e"))
		place(group, "qprop_pot_1", center, Vector3(0.44, 0.28, 0.3))
		B.ball(group, center + Vector3(0, 0.255, 0), Vector3(0.34, 0.036, 0.24), B.mat("#51432d"))
		var plant = "qnat_fern_1" if region == 9 else "qnat_flower_4_group" if region == 10 else "qnat_plant_7" if region == 12 else "zappy_crystal" if region == 15 else "qnat_flower_3_group"
		var size = Vector3(0.58, 0.35, 0.3) if region in [9, 10, 11] else Vector3(0.42, 0.32, 0.26)
		place(group, plant, center + Vector3(0, 0.255, 0), size, Vector3(0, float(variant + side) * 0.18, 0))
	for leaf in group.find_children("*", "GeometryInstance3D", true, false):
		leaf.visibility_range_end = A.detail_range(); leaf.add_to_group("imported_detail")
