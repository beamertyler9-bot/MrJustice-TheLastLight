extends Skeleton3D
## Renders a procedurally animated, piece-built character as one skinned mesh per material.
##
## Characters such as Mr. Justice are made from hundreds of small meshes parented to Node3D
## joints that gameplay code animates directly. That costs one draw call per piece (plus shadow
## passes). This node mirrors every joint as a bone, merges all rigid pieces into a few skinned
## meshes, and copies the joint transforms into the bones after animation runs each frame.
##
## The original pieces stay in the tree with their visibility and bounds untouched (code that
## measures them keeps working); they are only hidden from cameras and shadows via layers.
## A joint that is hidden collapses its bone, so held items, tools and weapons still appear and
## disappear exactly as before. If a piece toggles its own visibility or leaves the tree, the
## batch shuts down and the original pieces render again.

const NODE_NAME := "RigidSkinBatches"
const HIDDEN_SCALE := Vector3(0.00001, 0.00001, 0.00001)

var root_node: Node3D
var joints: Array[Node3D] = []
var batches: Array[MeshInstance3D] = []
var sources: Array = []
var active := false


## loose: pieces that move or show/hide on their own (fingers, straps). Each gets its own bone.
## excluded: pieces that must keep rendering themselves (animated cloth, flames).
static func apply(root: Node3D, loose: Array = [], excluded: Array = []) -> Node:
	if root == null: return null
	var existing = root.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	var batcher = load("res://scripts/rigid_skin_batches.gd").new()
	batcher.name = NODE_NAME
	root.add_child(batcher)
	if not batcher.build(root, loose, excluded):
		batcher.queue_free()
		return null
	return batcher


static func eligible(source: MeshInstance3D, excluded: Array, loose: bool = false) -> bool:
	var JointBatches = load("res://scripts/joint_draw_batches.gd")
	if source.mesh == null or excluded.has(source) or source.get_script() != null or source.skin != null: return false
	if source.top_level or source.get_child_count() != 0 or source.material_overlay != null: return false
	if not loose and not source.visible: return false
	if source.has_meta("prepared_shadow_proxy") or source.has_meta("joint_batch_proxy"): return false
	if not (source.mesh is ArrayMesh or source.mesh is PrimitiveMesh): return false
	if source.visibility_range_begin != 0 or source.visibility_range_end != 0 or source.custom_aabb != AABB(): return false
	if source.transparency != 0 or source.visibility_parent != NodePath() or source.basis.determinant() == 0: return false
	if source.layers == 0 or source.mesh.get_surface_count() != 1: return false
	if source.mesh is ArrayMesh:
		if source.mesh.get_blend_shape_count() != 0: return false
		if source.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES: return false
	var paint = JointBatches._material_of(source, 0)
	return paint != null and JointBatches.merge_safe(paint)


func _joint_pose(joint: Node3D) -> Transform3D:
	# For loose pieces the "joint" is the piece itself.
	var xform := root_node.global_transform.affine_inverse() * joint.global_transform
	if not joint.is_visible_in_tree():
		xform = Transform3D(Basis.from_scale(HIDDEN_SCALE), xform.origin)
	return xform


func build(root: Node3D, loose: Array, excluded: Array) -> bool:
	root_node = root
	var JointBatches = load("res://scripts/joint_draw_batches.gd")
	var joint_index: Dictionary = {}
	var buckets: Dictionary = {}
	# Identical material copies can share a draw; materials the character script keeps a
	# reference to (it may animate them) keep their own identity.
	var dynamic: Dictionary = {}
	for info in root.get_property_list():
		var value = root.get(info.name)
		if value is Material: dynamic[value] = true
	var Contracts = load("res://scripts/district_batches.gd")
	var contract_ids: Dictionary = {}
	for source in root.find_children("*", "MeshInstance3D", true, false):
		var is_loose: bool = loose.has(source)
		if not eligible(source, excluded, is_loose): continue
		var joint = source if is_loose else source.get_parent()
		if not joint is Node3D: continue
		if not joint_index.has(joint):
			# Bones store position/rotation/scale, so a joint whose frame cannot round-trip
			# (for example a mirrored, skewed basis) keeps its original pieces.
			var pose: Transform3D = root.global_transform.affine_inverse() * (joint as Node3D).global_transform
			if not _round_trips(pose):
				joint_index[joint] = -1
			else:
				joint_index[joint] = joints.size()
				joints.append(joint)
		if joint_index[joint] < 0: continue
		var paint = JointBatches._material_of(source, 0)
		var arrays: Array = source.mesh.surface_get_arrays(0)
		var material_key = paint.get_instance_id()
		if not dynamic.has(paint):
			if not contract_ids.has(paint): contract_ids[paint] = var_to_str(Contracts.material_contract(paint)).hash()
			material_key = contract_ids[paint]
		var key = [material_key, source.layers, source.cast_shadow, source.gi_mode, JointBatches._signature(arrays)]
		if not buckets.has(key): buckets[key] = {"paint": paint, "first": source, "items": []}
		buckets[key].items.append({"source": source, "arrays": arrays, "bone": joint_index[joint], "local": Transform3D.IDENTITY if is_loose else source.transform, "loose": is_loose, "cull": _cull_of(paint)})
	var merged := 0
	for key in buckets: merged += buckets[key].items.size()
	if merged < 8 or buckets.size() >= merged: return false
	for j in range(joints.size()):
		add_bone("j%d" % j)
		set_bone_rest(j, Transform3D.IDENTITY)
	var skin := Skin.new()
	for j in range(joints.size()): skin.add_bind(j, Transform3D.IDENTITY)
	for key in buckets:
		var bucket = buckets[key]
		var mesh := _merge(bucket.items, JointBatches._signature(bucket.items[0].arrays))
		var draw := MeshInstance3D.new()
		draw.name = "SkinnedBatch"
		draw.mesh = mesh
		draw.skin = skin
		draw.material_override = bucket.paint
		draw.layers = bucket.first.layers
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode = bucket.first.gi_mode
		draw.set_meta("joint_batch_proxy", true)
		add_child(draw)
		draw.skeleton = NodePath("..")
		batches.append(draw)
		for item in bucket.items:
			var source: MeshInstance3D = item.source
			sources.append({"source": source, "layers": source.layers, "shadow": source.cast_shadow, "visible": source.visible, "loose": item.loose})
	# All shadow casters share one shadow-only draw per cull mode.
	var casters: Dictionary = {}
	for key in buckets:
		for item in buckets[key].items:
			if item.source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
			if not casters.has(item.cull): casters[item.cull] = []
			casters[item.cull].append(item)
	for cull in casters:
		var shadow := MeshInstance3D.new()
		shadow.name = "SkinnedShadow"
		shadow.mesh = _merge(casters[cull], 0)
		shadow.skin = skin
		var paint := StandardMaterial3D.new()
		paint.cull_mode = cull
		shadow.material_override = paint
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow.set_meta("joint_batch_proxy", true)
		add_child(shadow)
		shadow.skeleton = NodePath("..")
		batches.append(shadow)
	for item in sources:
		var source: MeshInstance3D = item.source
		source.layers = 0
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not item.loose: source.visibility_changed.connect(_source_visibility_changed)
		source.tree_exiting.connect(release, CONNECT_ONE_SHOT)
	active = true
	process_priority = 1000
	_sync()
	return true


static func _cull_of(paint: Material) -> int:
	if paint is BaseMaterial3D: return paint.cull_mode
	return BaseMaterial3D.CULL_BACK


func _round_trips(pose: Transform3D) -> bool:
	var q := pose.basis.get_rotation_quaternion()
	var s := pose.basis.get_scale()
	# Skeleton bones compose rotation * scale (scale applied in the bone's local axes).
	return Transform3D(Basis(q) * Basis.from_scale(s), pose.origin).is_equal_approx(pose)


func _merge(items: Array, sig: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for item in items:
		var arrays: Array = item.arrays
		var xform: Transform3D = item.local
		var basis_n: Basis = xform.basis.inverse().transposed()
		var base := verts.size()
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in src_v:
			verts.append(xform * v)
			bones.append_array([item.bone, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
		if sig & (1 << Mesh.ARRAY_NORMAL):
			for n in arrays[Mesh.ARRAY_NORMAL]: normals.append((basis_n * n).normalized())
		if sig & (1 << Mesh.ARRAY_TANGENT):
			var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i in range(0, t.size(), 4):
				var d = (xform.basis * Vector3(t[i], t[i + 1], t[i + 2])).normalized()
				tangents.append_array([d.x, d.y, d.z, t[i + 3]])
		if sig & (1 << Mesh.ARRAY_COLOR): colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if sig & (1 << Mesh.ARRAY_TEX_UV): uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if sig & (1 << Mesh.ARRAY_TEX_UV2): uv2s.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		var flip := xform.basis.determinant() < 0
		var src_i = arrays[Mesh.ARRAY_INDEX]
		var count: int = src_i.size() if src_i != null and src_i.size() > 0 else src_v.size()
		for i in range(0, count, 3):
			var a: int = src_i[i] if src_i != null and src_i.size() > 0 else i
			var b: int = src_i[i + 1] if src_i != null and src_i.size() > 0 else i + 1
			var c: int = src_i[i + 2] if src_i != null and src_i.size() > 0 else i + 2
			if flip: indices.append_array([base + a, base + c, base + b])
			else: indices.append_array([base + a, base + b, base + c])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_INDEX] = indices
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	if sig & (1 << Mesh.ARRAY_NORMAL): out[Mesh.ARRAY_NORMAL] = normals
	if sig & (1 << Mesh.ARRAY_TANGENT): out[Mesh.ARRAY_TANGENT] = tangents
	if sig & (1 << Mesh.ARRAY_COLOR): out[Mesh.ARRAY_COLOR] = colors
	if sig & (1 << Mesh.ARRAY_TEX_UV): out[Mesh.ARRAY_TEX_UV] = uvs
	if sig & (1 << Mesh.ARRAY_TEX_UV2): out[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


func _sync() -> void:
	for j in range(joints.size()):
		var joint := joints[j]
		if is_instance_valid(joint): set_bone_pose(j, _joint_pose(joint))


func _process(_dt: float) -> void:
	if active: _sync()


func _source_visibility_changed() -> void:
	if not active: return
	for item in sources:
		if item.loose: continue
		if is_instance_valid(item.source) and item.source.visible != item.visible:
			release()
			return


func release() -> void:
	if not active: return
	active = false
	set_process(false)
	for draw in batches:
		if is_instance_valid(draw): draw.queue_free()
	batches.clear()
	for item in sources:
		var source = item.source
		if not is_instance_valid(source): continue
		source.layers = item.layers
		source.cast_shadow = item.shadow
		if source.visibility_changed.is_connected(_source_visibility_changed): source.visibility_changed.disconnect(_source_visibility_changed)
		if source.tree_exiting.is_connected(release): source.tree_exiting.disconnect(release)


func draw_reduction() -> int:
	return sources.size() - batches.size() if active else 0


func _exit_tree() -> void:
	release()
