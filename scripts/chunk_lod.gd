extends Node


const SIZE = 48.0
const NEAR = 48.0
const FAR = 96.0
const MARGIN = 8.0
var level: int = -1
var _records: Array = []
var _ground: WeakRef
var _terrain: Array = []

static func attach(chunk: Node3D):
	var existing = chunk.get_node_or_null("ChunkLOD")
	if existing != null: return existing
	var controller = load("res://scripts/chunk_lod.gd").new()
	controller.name = "ChunkLOD"; chunk.add_child(controller); controller._capture(chunk)
	return controller

func _capture(chunk: Node3D) -> void:
	for node in chunk.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D and node.name == "TerrainSurface":
			_ground = weakref(node); _terrain = [node.mesh, null, null]; continue
		if not node.visible: continue
		var ancestor = node.get_parent(); var moving = false
		while ancestor != chunk:


			if ancestor is RigidBody3D: moving = true; break
			ancestor = ancestor.get_parent()
		if moving: continue
		var record = {"node": weakref(node), "layers": node.layers, "bias": node.lod_bias, "shadow": node.cast_shadow, "small": node.is_in_group("world_detail"), "active": true}
		node.tree_exiting.connect(_restore.bind(record), CONNECT_ONE_SHOT)
		_records.append(record)

func update_viewer(position: Vector3) -> bool:
	var chunk: Node3D = get_parent()
	var point = chunk.to_local(position)
	var distance = Vector2(maxf(0.0, maxf(-point.x, point.x - SIZE)), maxf(0.0, maxf(-point.z, point.z - SIZE))).length()
	var next = 0 if distance <= NEAR else 1 if distance <= FAR else 2
	if level == 0: next = 2 if distance > FAR + MARGIN else 1 if distance > NEAR + MARGIN else 0
	elif level == 1: next = 0 if distance < NEAR - MARGIN else 2 if distance > FAR + MARGIN else 1
	elif level == 2: next = 0 if distance < NEAR - MARGIN else 1 if distance < FAR - MARGIN else 2
	if next == level: return false
	level = next; chunk.set_meta("chunk_detail_level", level)
	if _ground != null and is_instance_valid(_ground.get_ref()):
		if _terrain[level] == null: _terrain[level] = terrain_mesh(_terrain[0], 2 if level == 1 else 4)
		_ground.get_ref().mesh = _terrain[level]
	for record in _records:
		if not record.active: continue
		var node = record.node.get_ref()
		if not is_instance_valid(node): continue
		if not chunk.is_ancestor_of(node): _restore(record); continue
		node.layers = 0 if level == 2 or (level == 1 and record.small) else record.layers
		node.lod_bias = record.bias * ([1.0, 0.45, 0.15][level])
		node.cast_shadow = record.shadow if level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true

func _restore(record: Dictionary) -> void:
	if not record.active: return
	record.active = false
	var node = record.node.get_ref()
	if not is_instance_valid(node): return
	node.layers = record.layers; node.lod_bias = record.bias; node.cast_shadow = record.shadow

func _exit_tree() -> void:
	for record in _records:
		_restore(record)
		var node = record.node.get_ref()
		var callback = _restore.bind(record)
		if is_instance_valid(node) and node.tree_exiting.is_connected(callback): node.tree_exiting.disconnect(callback)
	if _ground != null and is_instance_valid(_ground.get_ref()): _ground.get_ref().mesh = _terrain[0]

static func terrain_mesh(source: ArrayMesh, stride: int) -> ArrayMesh:
	if stride not in [2, 4] or source.get_surface_count() != 1: return source
	var arrays = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() != 289: return source


	for z in range(17):
		for x in range(17):
			var v = vertices[z * 17 + x]
			if not is_equal_approx(v.x, x * 3.0) or not is_equal_approx(v.z, z * 3.0): return source
	var indices = PackedInt32Array()
	for z in range(0, 16, stride):
		for x in range(0, 16, stride):
			var ring = PackedInt32Array()


			var step = 1 if z == 0 else stride
			for px in range(x, x + stride + 1, step): ring.append(z * 17 + px)
			step = 1 if x + stride == 16 else stride
			for pz in range(z + step, z + stride + 1, step): ring.append(pz * 17 + x + stride)
			step = 1 if z + stride == 16 else stride
			for px in range(x + stride - step, x - 1, -step): ring.append((z + stride) * 17 + px)
			step = 1 if x == 0 else stride
			for pz in range(z + stride - step, z, -step): ring.append(pz * 17 + x)
			var center = (z + stride / 2) * 17 + x + stride / 2
			for i in range(ring.size()): indices.append_array(PackedInt32Array([center, ring[i], ring[(i + 1) % ring.size()]]))
	arrays[Mesh.ARRAY_INDEX] = indices
	var result = ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, source.surface_get_material(0))
	return result
