extends Node
## Merges rigid sibling meshes that share a joint, material and layer mask into one draw call.
##
## Procedural characters are assembled from many small boxes and cylinders parented to animated
## joints. Every piece is its own draw call, which is expensive on phones. This keeps the
## original pieces in the tree (so gameplay code that reads their bounds or visibility keeps
## working) but hides them from cameras with layer mask 0, and renders one merged proxy per
## joint instead. If any source piece changes visibility or leaves the tree, its whole group is
## released and the original pieces render again.

const NODE_NAME := "JointDrawBatches"
const MIN_GROUP := 2
## Merged groups are split into cells of this size (in the parent's space) so large
## settlements still frustum-cull in pieces.
const CELL_SIZE := 16.0

var groups: Array = []


const RANGE_KEYS := ["visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode"]
const SHARED_GROUPS := ["world_detail", "imported_detail"]


static func clear(root: Node) -> void:
	if root == null: return
	var previous = root.get_node_or_null(NODE_NAME)
	if previous != null:
		previous.release_all()
		previous.free()


static func rebuild(root: Node, excluded: Array = []) -> Node:
	if root == null: return null
	clear(root)
	return apply(root, excluded)


## Sources already owned by a prebaked DistrictBatches renderer under root.
static func district_sources(root: Node) -> Array:
	var result := []
	for renderer in root.find_children("DistrictBatches", "", true, false):
		for group in renderer.get("groups"):
			result.append_array(group.sources)
	return result


static func apply(root: Node, excluded: Array = []) -> Node:
	if root == null: return null
	var existing = root.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	var batcher = load("res://scripts/joint_draw_batches.gd").new()
	batcher.name = NODE_NAME
	root.add_child(batcher)
	batcher.build(root, excluded)
	return batcher


static func _material_of(source: MeshInstance3D, surface: int) -> Material:
	var paint = source.get_surface_override_material(surface)
	if paint == null: paint = source.material_override
	if paint == null: paint = source.mesh.surface_get_material(surface)
	return paint


static func eligible(source: MeshInstance3D, excluded: Array) -> bool:
	if source.mesh == null or excluded.has(source) or source.get_script() != null or source.skin != null: return false
	if source.top_level or source.get_child_count() != 0 or source.material_overlay != null: return false
	if source.has_meta("prepared_shadow_proxy") or source.has_meta("joint_batch_proxy"): return false
	if not (source.mesh is ArrayMesh or source.mesh is PrimitiveMesh): return false
	if source.custom_aabb != AABB() or source.extra_cull_margin != 0: return false
	if not source.get_meta_list().is_empty(): return false
	for group in source.get_groups():
		if not str(group) in SHARED_GROUPS: return false
	if source.transparency != 0 or source.visibility_parent != NodePath() or source.basis.determinant() == 0: return false
	if source.layers == 0 or source.mesh.get_surface_count() != 1: return false
	if source.mesh is ArrayMesh:
		if source.mesh.get_blend_shape_count() != 0: return false
		if source.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES: return false
	var paint = _material_of(source, 0)
	if paint == null: return false
	return merge_safe(paint)


## A material is safe to merge when it does not depend on the object's own origin or axes.
static func merge_safe(paint: Material) -> bool:
	if paint is BaseMaterial3D:
		if paint.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or paint.fixed_size or paint.grow: return false
		if paint.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or paint.next_pass != null: return false
		if paint.uv1_triplanar and not paint.uv1_world_triplanar: return false
		if paint.uv2_triplanar and not paint.uv2_world_triplanar: return false
		return true
	if paint is ShaderMaterial and paint.shader != null and paint.next_pass == null:
		var code: String = paint.shader.code
		return not ("void vertex" in code or "MODEL_MATRIX" in code or "NODE_POSITION" in code or "INV_VIEW_MATRIX * vec4(VERTEX" in code)
	return false


static func _signature(arrays: Array) -> int:
	var bits := 0
	for slot in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var data = arrays[slot]
		if data != null and data.size() > 0: bits |= 1 << slot
	return bits


func build(root: Node, excluded: Array) -> void:
	var parents: Dictionary = {}
	for source in root.find_children("*", "MeshInstance3D", true, false):
		if not eligible(source, excluded): continue
		var parent = source.get_parent()
		if not parent is Node3D: continue
		if not parents.has(parent): parents[parent] = []
		parents[parent].append(source)
	for parent in parents:
		var buckets: Dictionary = {}
		for source in parents[parent]:
			var arrays: Array = source.mesh.surface_get_arrays(0)
			var key = [_material_of(source, 0).get_instance_id(), source.layers, source.cast_shadow, source.visible, source.gi_mode, _signature(arrays), source.get_groups()]
			for range_key in RANGE_KEYS: key.append(source.get(range_key))
			key.append(Vector3i((source.position / CELL_SIZE).floor()))
			if not buckets.has(key): buckets[key] = []
			buckets[key].append({"source": source, "arrays": arrays})
		for key in buckets:
			if buckets[key].size() >= MIN_GROUP: _make_group(parent, buckets[key])


func _make_group(parent: Node3D, items: Array) -> void:
	var first: MeshInstance3D = items[0].source
	var sig := _signature(items[0].arrays)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	for item in items:
		var arrays: Array = item.arrays
		var xform: Transform3D = item.source.transform
		var basis_n: Basis = xform.basis.inverse().transposed()
		var base := verts.size()
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in src_v: verts.append(xform * v)
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
		var src_i = arrays[Mesh.ARRAY_INDEX]
		var flip := xform.basis.determinant() < 0
		if src_i != null and src_i.size() > 0:
			for i in range(0, src_i.size(), 3):
				if flip: indices.append_array([base + src_i[i], base + src_i[i + 2], base + src_i[i + 1]])
				else: indices.append_array([base + src_i[i], base + src_i[i + 1], base + src_i[i + 2]])
		else:
			for i in range(0, src_v.size(), 3):
				if flip: indices.append_array([base + i, base + i + 2, base + i + 1])
				else: indices.append_array([base + i, base + i + 1, base + i + 2])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_INDEX] = indices
	if sig & (1 << Mesh.ARRAY_NORMAL): out[Mesh.ARRAY_NORMAL] = normals
	if sig & (1 << Mesh.ARRAY_TANGENT): out[Mesh.ARRAY_TANGENT] = tangents
	if sig & (1 << Mesh.ARRAY_COLOR): out[Mesh.ARRAY_COLOR] = colors
	if sig & (1 << Mesh.ARRAY_TEX_UV): out[Mesh.ARRAY_TEX_UV] = uvs
	if sig & (1 << Mesh.ARRAY_TEX_UV2): out[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var proxy := MeshInstance3D.new()
	proxy.name = "JointBatch"
	proxy.mesh = mesh
	proxy.material_override = _material_of(first, 0)
	proxy.layers = first.layers
	proxy.cast_shadow = first.cast_shadow
	proxy.gi_mode = first.gi_mode
	proxy.visible = first.visible
	for range_key in RANGE_KEYS: proxy.set(range_key, first.get(range_key))
	for group_name in first.get_groups(): proxy.add_to_group(group_name)
	proxy.set_meta("joint_batch_proxy", true)
	parent.add_child(proxy)
	var index := groups.size()
	var group := {"proxy": proxy, "sources": [], "active": true}
	groups.append(group)
	var release := release_index.bind(index)
	var watch := _source_visibility_changed.bind(index)
	group.release = release
	group.watch = watch
	for item in items:
		var source: MeshInstance3D = item.source
		group.sources.append({"source": source, "layers": source.layers, "shadow": source.cast_shadow, "visible": source.visible})
		source.layers = 0
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Ancestor visibility changes also emit this signal; only the piece's own flag matters,
		# because the proxy shares the same parent and inherits ancestor visibility.
		source.visibility_changed.connect(watch)
		source.tree_exiting.connect(release, CONNECT_ONE_SHOT)


func _source_visibility_changed(index: int) -> void:
	if index < 0 or index >= groups.size() or not groups[index].active: return
	for item in groups[index].sources:
		if is_instance_valid(item.source) and item.source.visible != item.visible:
			release_index(index)
			return


func release_index(index: int) -> void:
	if index < 0 or index >= groups.size(): return
	var group: Dictionary = groups[index]
	if not group.active: return
	group.active = false
	if is_instance_valid(group.proxy): group.proxy.queue_free()
	for item in group.sources:
		var source = item.source
		if not is_instance_valid(source): continue
		source.layers = item.layers
		source.cast_shadow = item.shadow
		if source.visibility_changed.is_connected(group.watch): source.visibility_changed.disconnect(group.watch)
		if source.tree_exiting.is_connected(group.release): source.tree_exiting.disconnect(group.release)


func draw_reduction() -> int:
	var saved := 0
	for group in groups:
		if group.active: saved += group.sources.size() - 1
	return saved


func release_all() -> void:
	for i in range(groups.size()): release_index(i)


func _exit_tree() -> void:
	release_all()
