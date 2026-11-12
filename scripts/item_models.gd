extends RefCounted


const Surfaces = preload("res://scripts/surfaces.gd")
const KINDS = ["lake_fish", "herb", "stone", "iron", "tonic", "mana_potion", "coffee", "wood", "stick", "planks", "crystal", "shard", "coffee_bean", "marshmallow", "roasted_marshmallow", "camp_kit", "relic", "ancient_core", "chocolate_bar", "graham_cracker", "smore"]
static func supports(kind: String) -> bool:
	return kind in ["string", "fishing_rod"] or kind in preload("res://scripts/fishing_catalog.gd").IDS or kind in KINDS or preload("res://scripts/quest_items.gd").is_quest(kind)




static func grip_anchor(kind: String) -> Vector3:
	match kind:
		"herb": return Vector3(0, 0.065, 0)
		"tonic", "mana_potion": return Vector3(0, 0.422, 0)
		"coffee": return Vector3(0.285, 0.18, 0)
		"wood": return Vector3(0, 0.21, 0)
		"stick": return Vector3(0, 0.19, 0)
		"crystal": return Vector3(0, 0.1, 0)
		"shard": return Vector3.ZERO
		"marshmallow", "roasted_marshmallow": return Vector3(0, 0.07, 0)
		"chocolate_bar", "graham_cracker": return Vector3(0.1, 0.04, 0)
		"smore": return Vector3(0.14, 0.12, 0)
	return Vector3.ZERO

static func build(parent: Node3D, kind: String) -> Node3D:
	if kind == "fishing_rod" or kind == "string":
		var prop = Node3D.new(); parent.add_child(prop)
		var b = load("res://scripts/build.gd")
		if kind == "fishing_rod":
			b.cyl(prop, Vector3(0, 0.7, 0), 0.025, 1.4, b.mat("#9f733f"))
			b.cyl(prop, Vector3(0, 0.13, 0.06), 0.085, 0.1, b.mat("#506c77")).rotation.x = PI / 2
			b.cyl(prop, Vector3.ZERO, 0.045, 0.28, b.mat("#44352c"))
		else:
			for i in 6: b.cyl(prop, Vector3(0, i * 0.025, 0), 0.11, 0.02, b.mat("#d9c69f"))
		return prop

	if kind in preload("res://scripts/fishing_catalog.gd").IDS:
		var fish = Node3D.new(); parent.add_child(fish)
		preload("res://scripts/fish_models.gd").build(fish, kind)
		return fish
	if preload("res://scripts/quest_items.gd").is_quest(kind): return preload("res://scripts/quest_item_models.gd").build(parent, kind)
	assert(supports(kind), "Unknown canonical item " + kind)
	if kind == "shard": return preload("res://scripts/light_essence.gd").build(parent)
	var model = load("res://scripts/replacement_items.gd").build(parent, kind)

	if kind in ["stone", "stick"]:
		for i in range(model.get_child_count()):
			var node = model.get_child(i)
			var path = "res://assets/mobile_lods/%s_%d.res" % [kind, i]
			if ResourceLoader.exists(path):
				var candidate = load(path)
				if candidate.get_meta("replacement_version", 0) == model.get_meta("art_revision", 29): node.mesh = candidate
	return model
