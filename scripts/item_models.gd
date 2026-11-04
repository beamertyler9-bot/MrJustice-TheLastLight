extends RefCounted


const Surfaces = preload("res://scripts/surfaces.gd")
const KINDS = ["herb", "stone", "iron", "tonic", "mana_potion", "coffee", "wood", "stick", "planks", "crystal", "shard", "coffee_bean", "marshmallow", "roasted_marshmallow", "camp_kit", "relic", "ancient_core", "chocolate_bar", "graham_cracker", "smore"]
static func supports(kind: String) -> bool:
	return kind in KINDS or preload("res://scripts/quest_items.gd").is_quest(kind)




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
