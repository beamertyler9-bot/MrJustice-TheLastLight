extends RefCounted


const A = preload("res://scripts/imported_assets.gd")


static func configure_round(source: Node3D, model: Node3D) -> bool:
	if source.get_meta("item", "") != "stone": return false
	var extent = 0.0
	for geometry in model.find_children("*", "MeshInstance3D", true, false):
		if geometry.mesh == null: continue

		var dimensions = geometry.mesh.get_aabb().size * geometry.global_transform.basis.get_scale().abs()
		extent = maxf(extent, maxf(dimensions.x, maxf(dimensions.y, dimensions.z)))
	if extent <= 0 or extent > 1.15: return false
	if is_instance_valid(source.collider): source.collider.free(); source.collider = null
	source.remove_from_group("mineable"); source.remove_from_group("batch_dynamic")
	source.set_meta("kind", "material"); source.set_meta("loose_stone", true); source.set_meta("label", "Pick up stone")
	return true
static func liftable(source: Node3D) -> bool:
	return is_instance_valid(source) and not source.is_queued_for_deletion() and source.get_meta("kind", "") == "material" and source.get_meta("item", "") == "stone" and source.get_meta("loose_stone", false) and str(source.get_meta("id", "")).length() > 0
static func lift(game, source: Node3D) -> RigidBody3D:
	if not liftable(source): return null
	var original_id = str(source.get_meta("id")); var existing = bool(source.get_meta("world_drop", false))
	if not existing and game.state.taken.has(original_id): return null
	var id = original_id if existing else "lifted_" + original_id
	var record: Dictionary = {}
	if existing:
		for row in game.state.world_loot:
			if row.id == id: record = row; break
		if record.is_empty(): return null
	var guide = source.get_meta("ground_stone_art", false)
	var ground = guide.get_ref() if guide is WeakRef else null
	var slot = int(source.get_meta("ground_stone_index", -1))
	var mesh_frame = Transform3D.IDENTITY; var bounds: AABB
	if ground != null and slot >= 0 and slot < ground.frames.size() and is_instance_valid(ground.batch):
		mesh_frame = ground.global_transform * ground.frames[slot]
		bounds = mesh_frame * ground.batch.multimesh.mesh.get_aabb()
	else: bounds = A.bounds(source)
	if bounds.size.length_squared() <= 1.0e-06: return null
	if not existing:
		var point = bounds.get_center()
		record = {"id": id, "item": "stone", "amount": int(source.get_meta("amount", 1)), "position": [point.x, point.y, point.z]}
		if not game.state.add_world_drop(record):
			game.toast("Collect some dropped supplies before lifting more stones."); return null


	var renderer = source.get_meta("chunk_renderer", false)
	if renderer is WeakRef and is_instance_valid(renderer.get_ref()): renderer.get_ref().release(source)
	var body = RigidBody3D.new(); body.name = "LiftedStone"; body.mass = 0.35; body.freeze = true; body.continuous_cd = true
	body.collision_layer = 8; body.collision_mask = 1 | 4 | 8; game.world.add_child(body); body.global_position = bounds.get_center()
	if ground != null:
		var visual = MeshInstance3D.new(); visual.name = "OriginalStoneArt"; visual.mesh = ground.batch.multimesh.mesh; visual.material_override = ground.batch.material_override
		visual.layers = ground.batch.layers; visual.cast_shadow = ground.batch.cast_shadow; body.add_child(visual); visual.global_transform = mesh_frame
	else:
		var visual = source.duplicate(0) as Node3D; visual.name = "OriginalStoneArt"; visual.set_script(null)
		for node in [visual] + visual.find_children("*", "Node", true, false):
			for group in node.get_groups(): node.remove_from_group(group)
		body.add_child(visual); visual.global_transform = source.global_transform
	var shape = BoxShape3D.new(); shape.size = bounds.size.max(Vector3.ONE * 0.04)
	var collider = CollisionShape3D.new(); collider.shape = shape; body.add_child(collider)
	body.set_meta("kind", "carry"); body.set_meta("material", "stone"); body.set_meta("item", "stone"); body.set_meta("amount", int(record.amount)); body.set_meta("id", id)
	body.set_meta("label", "Pick up stone"); body.set_meta("loose_stone", true); body.set_meta("lifted_stone", true); body.set_meta("world_drop", true)
	body.add_to_group("interactable"); body.add_to_group("carryable"); game._loot_nodes[id] = body
	if not existing: game.state.taken[original_id] = true
	if ground != null: ground._hide(slot)
	source.hide(); source.queue_free(); game._queue_loot_save()
	return body
