extends RefCounted

static var scenes: Dictionary = {}
static func resolve(root: Node, value):
	if value is NodePath:
		var node = root.get_node_or_null(value)
		if node != null: node.add_to_group("batch_dynamic")
		return node
	if value is Array:
		var result = []
		for item in value: result.append(resolve(root, item))
		return result
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = resolve(root, value[key])
		return result
	return value
static func attach(parent: Node3D, id: String) -> Dictionary:
	var path = "res://assets/creatures/" + id + ".scn"
	if not scenes.has(id): scenes[id] = load(path)
	assert(scenes[id] != null, "Missing replacement creature " + id)
	return attach_packed(parent, scenes[id])
static func attach_packed(parent: Node3D, scene: PackedScene) -> Dictionary:
	var model = scene.instantiate(); parent.add_child(model)
	for key in model.get_meta_list(): parent.set_meta(key, model.get_meta(key))
	var rig = resolve(model, model.get_meta("rig_bindings"))
	var properties = model.get_meta("actor_properties")


	for child in model.get_children(): child.reparent(parent, false)
	model.free()
	return {"model": parent, "rig": rig, "properties": properties}
static func bind(actor, id: String) -> void:
	var data = attach(actor.model, id)
	for key in data.rig:
		var current = actor.get(key)
		if current is Array: current.assign(data.rig[key])
		else: actor.set(key, data.rig[key])
	for key in data.properties:
		if data.properties[key] != null: actor.set(key, data.properties[key])
