extends RefCounted

static var scenes: Dictionary = {}
static var mana_liquid: StandardMaterial3D
static func build(parent: Node3D, kind: String) -> Node3D:


	var source_kind = "tonic" if kind == "mana_potion" else kind
	if not scenes.has(source_kind): scenes[source_kind] = load("res://assets/replacements/items/" + source_kind + ".scn")
	assert(scenes[source_kind] != null, "Missing canonical replacement item: " + kind)
	var model = scenes[source_kind].instantiate(); parent.add_child(model); model.set_meta("item_model", kind)
	if kind == "mana_potion":
		var liquid = model.get_node("HerbalLiquid")
		if mana_liquid == null:
			mana_liquid = liquid.material_override.duplicate(); mana_liquid.albedo_color = Color("#287cdb")
		liquid.material_override = mana_liquid
	return model
