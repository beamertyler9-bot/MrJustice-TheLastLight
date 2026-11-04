extends RefCounted

const A = preload("res://scripts/imported_assets.gd")
const B = preload("res://scripts/build.gd")
static var _leaf_materials: Dictionary = {}
static var _leaf_mesh: SphereMesh

static func tree(parent: Node3D, region: int, variant: int, height: float) -> bool:
	if region not in [9, 11]: return false
	return load("res://scripts/world_overhaul.gd").tree(parent, region, variant, height)

static func workyard(parent: Node3D, region: int, variant: int) -> void:
	parent.set_meta("regional_workyard", region)
	load("res://scripts/world_overhaul.gd").yard(parent, region, variant)
	if region == 11:
		A.place(parent, "farm_tower_windmill" if variant % 2 == 0 else "farm_windmill", Vector3.ZERO, 8.5)
		A.place(parent, "farm_fence_2", Vector3(-2.5, 0, 0), 1.1, PI * 0.5)
	elif region in [9, 10]:
		A.place(parent, "farm_well", Vector3.ZERO, 2.7, 0.2)
		A.place(parent, "farm_fence", Vector3(-2.4, 0, -1.5), 0.95, PI * 0.5)
		fit(parent, "kaykit_rope_bundle_a", Vector3(1.8, 0.25, 0), 0.65)
	elif region == 12:
		A.place(parent, "kaykit_bucket_metal", Vector3(0, 0.2, 0), 0.6)
		fit(parent, "kaykit_rope_bundle_b", Vector3(-1, 0.2, 0), 0.9)
		A.place(parent, "kaykit_map_rolled", Vector3(1, 0.3, 0), 0.6)
	else:
		A.place(parent, "kaykit_grindstone", Vector3.ZERO, 0.95)
		A.place(parent, "kaykit_bucket_metal", Vector3(1.2, 0.2, 0), 0.5)
		A.place(parent, "kaykit_lantern", Vector3(-1.2, 0.2, 0), 0.65)

static func facade(parent: Node3D, width: float, depth: float, purpose: String, region: int, index: int) -> void:
	load("res://scripts/world_overhaul.gd").facade(parent, width, depth, purpose, region, index)

static func furnish(parent: Node3D, width: float, depth: float, purpose: String, region: int) -> void:
	var left = -width * 0.5 + 1.4; var back = -depth * 0.5 + 1.1
	var words = purpose.to_lower()
	if has_word(words, ["library", "archive", "study", "map", "observatory", "instrument"]):
		fit(parent, "kaykit_journal_open", Vector3(-width * 0.22 - 0.5, 0.96, -0.4), 0.65)
		fit(parent, "kaykit_map", Vector3(-width * 0.22 + 0.45, 0.96, -0.4), 0.72)
		fit(parent, "kaykit_compass_base", Vector3(-width * 0.22, 0.97, 0.05), 0.24)
		fit(parent, "kaykit_map_rolled", Vector3(width * 0.28, 0.95, back + 1.4), 0.3)
	elif has_word(words, ["armory", "guard", "prison", "vault", "clock", "work", "kiln", "forge"]):
		A.place(parent, "kaykit_anvil", Vector3(width * 0.25 - 0.35, 0.95, back + 1), 0.5)
		A.place(parent, "kaykit_hammer", Vector3(width * 0.25 + 0.65, 0.95, back + 1), 0.4, -0.45)
		fit(parent, "kaykit_blueprint_stacked", Vector3(width * 0.25 + 0.45, 0.96, back + 0.55), 0.65)
		for i in range(3):
			var id = ["weapons_arming_sword", "weapons_bearded_axe", "kaykit_pickaxe"][i]
			A.place(parent, id, Vector3(left - 0.65 + i * 0.6, 0.35, back + 0.5), 1.35, 0.1 * (i - 1))
	elif has_word(words, ["kitchen", "bak", "pantry", "food", "stores", "scullery", "inn", "tavern"]):
		A.place(parent, "kaykit_bucket_metal", Vector3(left, 0.28, back + 1.5), 0.45)
		fit(parent, "kaykit_rope_bundle_a", Vector3(left, 0.22, back + 0.2), 0.6)
		A.place(parent, "kaykit_knife", Vector3(width * 0.24 - 0.8, 0.95, back + 1), 0.26, 0.6)
		fit(parent, "kaykit_journal_closed", Vector3(width * 0.24 + 0.65, 0.96, back + 1), 0.42)
	elif has_word(words, ["great hall", "ballroom", "gallery", "council", "throne", "landing", "entrance hall", "crown hall", "tomb", "pyramid", "crypt", "ceremony", "chapel", "temple"]):

		A.place(parent, "kaykit_lantern", Vector3(width * 0.32, 0.28, back + 1), 0.55)
		fit(parent, "kaykit_journal_closed", Vector3(left, 0.99, back + 0.7), 0.5)
	else:
		fit(parent, "kaykit_journal_closed", Vector3(width * 0.27 - 0.3, 0.95, back + 1), 0.5)
		A.place(parent, "kaykit_lantern", Vector3(width * 0.27 + 0.36, 0.95, back + 0.8), 0.45)
		fit(parent, "kaykit_rope_bundle_b", Vector3(width * 0.28, 0.28, depth * 0.5 - 1), 0.65)
	parent.set_meta("asset_dressing", true)

static func fit(parent: Node3D, id: String, at: Vector3, width: float) -> Node3D:
	var entry = A.entry(id)
	if entry.is_empty(): return null
	var size = entry.bounds_size
	return A.place(parent, id, at, width / maxf(float(size[0]), float(size[2])))

static func has_word(value: String, words: Array) -> bool:
	for word in words:
		if word in value: return true
	return false
