extends RefCounted

static var _catalog: Dictionary = {}
static var _meshes: Dictionary = {}
static var _quality: int = 1

static func detail_range() -> float:
	return [45.0, 65.0, 110.0][_quality]

static func set_quality(value: int) -> void:
	_quality = clampi(value, 0, 2)
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		for node in tree.get_nodes_in_group("imported_detail"):
			if node is GeometryInstance3D: node.visibility_range_end = detail_range()

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/imported/catalog.json"))
		if data is Dictionary: _catalog = data
	return _catalog

static func entry(id: String) -> Dictionary:
	return catalog().get(id, {})

static func mesh(id: String) -> Mesh:
	if not _meshes.has(id):
		var data = entry(id)
		if data.is_empty(): return null
		var path = str(data.path)
		if id.begins_with("qnat_commontree_"):
			var prepared = "res://assets/forest_canopies/%s.res" % id
			if ResourceLoader.exists(prepared): path = prepared
		var resource = load(path)
		if not resource is Mesh: return null
		if str(data.category) != "vegetation" and not resource.has_meta("forest_canopy_revision"): load("res://scripts/pack_materials.gd").apply(resource)
		_meshes[id] = resource
	return _meshes[id]

static func place(parent: Node3D, id: String, at: Vector3, height: float, yaw: float = 0.0) -> Node3D:
	if parent == null or not at.is_finite() or not is_finite(height) or height <= 0 or not is_finite(yaw): return null
	var geometry = mesh(id)
	if geometry == null: return null
	var node = Node3D.new(); node.name = id.to_pascal_case(); node.position = at; node.rotation.y = yaw; node.scale = Vector3.ONE * height
	node.set_meta("imported_asset", id); node.set_meta("source_archive", entry(id).source_archive)
	var art = MeshInstance3D.new(); art.name = "AuthoredMesh"; art.mesh = geometry
	if geometry.get_surface_count() == 1: art.material_override = geometry.surface_get_material(0)
	art.visibility_range_end = 145 if id.begins_with("nature_tree") else detail_range()
	if not id.begins_with("nature_tree"): art.add_to_group("imported_detail")
	node.add_child(art); parent.add_child(node)
	return node

static func bounds(node: Node3D) -> AABB:
	var box = AABB(); var found = false
	if node is MeshInstance3D and node.mesh:
		box = node.global_transform * node.get_aabb(); found = true
	if node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
		var frames = node.get_meta("instance_transforms", [])
		for i in range(node.multimesh.instance_count):
			var frame: Transform3D = frames[i] if frames.size() > i else node.multimesh.get_instance_transform(i)
			var part = node.global_transform * frame * node.multimesh.mesh.get_aabb()
			box = box.merge(part) if found else part; found = true
	for child in node.get_children():
		if not child is Node3D: continue
		var part = bounds(child)
		if part.size.length_squared() <= 0: continue
		box = box.merge(part) if found else part; found = true
	return box
