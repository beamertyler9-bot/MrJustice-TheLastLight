extends Node3D

var records: Array = []
var owners: Dictionary = {}
var rigid_owners: Array = []
var integrity_clock: float = 0.0

static func rebuild(chunk: Node3D):
	var previous = chunk.get_node_or_null("ChunkInstances")
	if previous != null: previous.free()
	return build(chunk)

static func build(chunk: Node3D):
	var existing = chunk.get_node_or_null("ChunkInstances")
	if existing != null: return existing
	var renderer = load("res://scripts/chunk_instances.gd").new()
	renderer.name = "ChunkInstances"; renderer.add_to_group("batch_dynamic"); chunk.add_child(renderer)
	var buckets = {}
	for owner in chunk.get_children():
		if not owner is Node3D: continue
		if not owner.visible: continue
		if not (owner.is_in_group("harvestable") or owner.get_meta("regional_food", false) or owner.get_meta("loose_stone", false) or owner.get_meta("authored_outcrop", false) or (owner is RigidBody3D and owner.freeze and owner.is_in_group("carryable"))): continue
		for source in owner.find_children("*", "GeometryInstance3D", true, false):
			if not source.visible or source.material_overlay != null: continue
			var ancestor = source.get_parent(); var dynamic = false
			while ancestor != owner:
				if ancestor is PhysicsBody3D or ancestor is Skeleton3D or ancestor.is_in_group("interactable") or ancestor.is_in_group("float_pickup") or ancestor.get_script() != null: dynamic = true; break
				ancestor = ancestor.get_parent()
			if dynamic: continue
			var mesh: Mesh; var frames: Array = []
			if source is MeshInstance3D and source.skin == null:
				mesh = source.mesh; frames = [Transform3D.IDENTITY]
				var overrides = false
				if mesh:
					for surface in range(mesh.get_surface_count()): overrides = overrides or source.get_surface_override_material(surface) != null
				if overrides: continue
			elif source is MultiMeshInstance3D and source.multimesh:
				mesh = source.multimesh.mesh
				var stored = source.get_meta("instance_transforms", [])
				for i in range(source.multimesh.instance_count): frames.append(stored[i] if stored.size() > i else source.multimesh.get_instance_transform(i))
			if mesh == null: continue
			var material = source.material_override
			var geometry_frame = renderer.global_transform.affine_inverse() * source.global_transform
			var basis = geometry_frame.basis; var divisor = maxf(basis.x.length_squared(), 1.0e-08)


			var gram = Vector3(basis.y.length_squared(), basis.z.length_squared(), basis.x.dot(basis.y)) / divisor
			var shear = Vector2(basis.x.dot(basis.z), basis.y.dot(basis.z)) / divisor
			gram = gram.snapped(Vector3.ONE * 1.0e-05); shear = shear.snapped(Vector2.ONE * 1.0e-05)


			var cell = Vector2i.ZERO if owner.has_meta("building_generation") or owner.get_meta("loose_stone", false) or owner.get_meta("authored_outcrop", false) else Vector2i(floori(owner.position.x / 24), floori(owner.position.z / 24))
			var key = "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [mesh.get_instance_id(), material.get_instance_id() if material else 0, source.layers, source.cast_shadow, source.visibility_range_begin, source.visibility_range_end, source.visibility_range_begin_margin, source.visibility_range_end_margin, source.visibility_range_fade_mode, gram, shear, source is MultiMeshInstance3D, cell]
			if not buckets.has(key): buckets[key] = []
			for frame in frames: buckets[key].append({"owner": owner, "source": source, "frame": geometry_frame * frame, "geometry_basis": basis, "mesh": mesh})
	for bucket in buckets.values():
		if bucket.size() < 2: continue
		var source = bucket[0].source; var batch = MultiMeshInstance3D.new(); batch.name = "SharedStationaryArt"
		var owner = bucket[0].owner
		if (owner.is_in_group("harvestable") and owner.get_meta("kind", "") == "tree") or owner.get_meta("regional_food", false): batch.set_meta("forest_canopy", true)



		batch.transform = Transform3D(bucket[0].geometry_basis, Vector3.ZERO)
		batch.multimesh = MultiMesh.new(); batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D; batch.multimesh.mesh = bucket[0].mesh; batch.multimesh.instance_count = bucket.size()
		batch.material_override = source.material_override; batch.layers = source.layers; batch.cast_shadow = source.cast_shadow
		batch.visibility_range_begin = source.visibility_range_begin; batch.visibility_range_end = source.visibility_range_end
		batch.visibility_range_begin_margin = source.visibility_range_begin_margin; batch.visibility_range_end_margin = source.visibility_range_end_margin; batch.visibility_range_fade_mode = source.visibility_range_fade_mode
		if source.is_in_group("imported_detail"): batch.add_to_group("imported_detail")
		var transforms: Array[Transform3D] = []; var bounds = AABB(); var first = true
		for i in range(bucket.size()):
			var record: Dictionary = bucket[i]; record.batch = batch; record.slot = i; record.active = true
			var local_frame = batch.transform.affine_inverse() * record.frame
			transforms.append(local_frame)
			var box = local_frame * record.mesh.get_aabb(); bounds = box if first else bounds.merge(box); first = false
			var id = record.owner.get_instance_id()
			if not renderer.owners.has(id):
				var callback = renderer._release.bind(id)
				var visibility_callback = renderer.owner_visibility_changed.bind(id)
				var item = {"id": id, "owner": record.owner, "frame": record.owner.global_transform, "visible": record.owner.visible, "records": [], "callback": callback, "visibility_callback": visibility_callback, "watch": null}
				renderer.owners[id] = item
				record.owner.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
				record.owner.visibility_changed.connect(visibility_callback)
				var watch = load("res://scripts/stationary_render_watch.gd").new(); watch.name = "StationaryRenderWatch"; record.owner.add_child(watch); watch.setup(renderer, id); item.watch = watch
				if record.owner is RigidBody3D: renderer.rigid_owners.append(item)
				record.owner.set_meta("chunk_renderer", weakref(renderer))
			renderer.owners[id].records.append(record); renderer.records.append(record); record.source.hide()
		batch.multimesh.buffer = load("res://scripts/build.gd")._instance_buffer(transforms)
		batch.set_meta("instance_transforms", transforms); batch.custom_aabb = bounds; renderer.add_child(batch)
	return renderer

func release(owner: Node3D) -> void: _release(owner.get_instance_id())
func _release(id: int) -> void:
	if not owners.has(id): return
	var item = owners[id]; owners.erase(id)
	if item.owner is RigidBody3D: rigid_owners.erase(item)
	if is_instance_valid(item.watch): item.watch.detach()
	if is_instance_valid(item.owner):
		if item.owner.visibility_changed.is_connected(item.visibility_callback): item.owner.visibility_changed.disconnect(item.visibility_callback)
		if item.owner.tree_exiting.is_connected(item.callback): item.owner.tree_exiting.disconnect(item.callback)
	for record in item.records:
		if record.active:
			if is_instance_valid(record.batch):
				var hidden = Transform3D(Basis.from_scale(Vector3.ONE * 1.0e-06), Vector3.ZERO)
				record.batch.multimesh.set_instance_transform(record.slot, hidden)
				record.batch.get_meta("instance_transforms")[record.slot] = hidden
			if is_instance_valid(record.source): record.source.show()
			record.active = false
func owner_transform_changed(id: int) -> void:
	if owners.has(id) and not owners[id].owner.global_transform.is_equal_approx(owners[id].frame): _release(id)
func owner_visibility_changed(id: int) -> void:

	if owners.has(id) and owners[id].owner.visible != owners[id].visible: _release(id)
func refresh() -> void:
	for id in owners.keys():
		var item = owners[id]; var owner = item.owner
		if not is_instance_valid(owner) or not owner.global_transform.is_equal_approx(item.frame) or owner.visible != item.visible or (owner is RigidBody3D and not owner.freeze): _release(id)
func _process(dt: float) -> void:



	var released = []
	for item in rigid_owners:
		if not is_instance_valid(item.owner) or not item.owner.freeze: released.append(item.id)
	for id in released: _release(id)
	integrity_clock += dt
	if integrity_clock >= 0.5: integrity_clock = 0.0; refresh()
func _exit_tree() -> void:
	for id in owners.keys(): _release(id)
