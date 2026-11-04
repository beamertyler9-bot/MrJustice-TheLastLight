extends Node3D

var sources: Array = []
static var templates: Dictionary = {}
static func relative(node: Node3D, owner: Node3D) -> Transform3D:
	var frame = Transform3D.IDENTITY
	while node != owner: frame = node.transform * frame; node = node.get_parent()
	return frame
static func compatible(material: Material) -> bool:
	if material == null or material.next_pass != null: return false
	if material is StandardMaterial3D: return material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and (not material.uv1_triplanar or material.uv1_world_triplanar)
	return material is ShaderMaterial and material.shader != null and material.shader.resource_path == "res://shaders/pack_toon.gdshader"
static func bake(owner: Node3D, template_key: String = ""):
	var existing = owner.get_node_or_null("StaticSurfaces")
	if existing != null: return existing
	var result = load("res://scripts/static_surfaces.gd").new(); result.name = "StaticSurfaces"; owner.add_child(result)
	var cached = not template_key.is_empty() and templates.has(template_key)
	var groups = {}
	for source in owner.find_children("*", "GeometryInstance3D", true, false):
		if not source.visible or source.material_overlay != null: continue
		var ancestor = source.get_parent(); var dynamic = false
		while ancestor != owner:
			if ancestor is PhysicsBody3D or ancestor is Skeleton3D or ancestor.get_script() != null or ancestor.is_in_group("interactable") or ancestor.is_in_group("float_pickup"): dynamic = true; break
			ancestor = ancestor.get_parent()
		if dynamic: continue
		var mesh: Mesh; var frames = []
		if source is MeshInstance3D and source.skin == null:
			mesh = source.mesh; frames = [Transform3D.IDENTITY]
		elif source is MultiMeshInstance3D and source.multimesh:
			mesh = source.multimesh.mesh; var stored = source.get_meta("instance_transforms", [])
			for i in range(source.multimesh.instance_count): frames.append(stored[i] if stored.size() > i else source.multimesh.get_instance_transform(i))
		if mesh == null: continue
		var supported = true; var materials = []
		for surface in range(mesh.get_surface_count()):
			var material = source.material_override if source.material_override else mesh.surface_get_material(surface)
			if source is MeshInstance3D and source.get_surface_override_material(surface) != null: material = source.get_surface_override_material(surface)
			materials.append(material); supported = supported and compatible(material)
		if not supported: continue
		for surface in range(mesh.get_surface_count()):
			var material = materials[surface]
			var key = "%s:%s:%s:%s:%s:%s:%s:%s:%s" % [material.get_instance_id(), source.layers, source.cast_shadow, source.visibility_range_begin, source.visibility_range_end, source.visibility_range_begin_margin, source.visibility_range_end_margin, source.visibility_range_fade_mode, source.is_in_group("imported_detail")]
			if not groups.has(key): groups[key] = {"source": source, "material": material, "pieces": []}
			if not cached:
				var arrays = mesh.surface_get_arrays(surface)
				for frame in frames: groups[key].pieces.append([arrays, relative(source, owner) * frame])
		result.sources.append(source); source.hide()
	if cached:
		for saved in templates[template_key]:
			var geometry = MeshInstance3D.new(); geometry.name = "SharedArchitecturalSurface"; geometry.mesh = saved.mesh; geometry.layers = saved.layers; geometry.cast_shadow = saved.shadow; result.add_child(geometry)
			for property in saved.visibility: geometry.set(property, saved.visibility[property])
			if saved.detail: geometry.add_to_group("imported_detail")
		return result
	var saved = []
	for group in groups.values():
		var mesh = _merge_pieces(group.pieces); mesh.surface_set_material(0, group.material)
		var geometry = MeshInstance3D.new(); geometry.name = "SharedArchitecturalSurface"; geometry.mesh = mesh; var source = group.source
		geometry.layers = source.layers; geometry.cast_shadow = source.cast_shadow; geometry.visibility_range_begin = source.visibility_range_begin; geometry.visibility_range_end = source.visibility_range_end; geometry.visibility_range_begin_margin = source.visibility_range_begin_margin; geometry.visibility_range_end_margin = source.visibility_range_end_margin; geometry.visibility_range_fade_mode = source.visibility_range_fade_mode
		if source.is_in_group("imported_detail"): geometry.add_to_group("imported_detail")
		result.add_child(geometry)
		var visibility = {}
		for property in ["visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode"]: visibility[property] = geometry.get(property)
		saved.append({"mesh": mesh, "layers": geometry.layers, "shadow": geometry.cast_shadow, "visibility": visibility, "detail": geometry.is_in_group("imported_detail")})
	if not template_key.is_empty(): templates[template_key] = saved
	return result
## Merge pieces into one surface with whole-array operations. Same result as the old
## per-corner SurfaceTool path (all attributes present, defaults filled in), but built in
## bulk so a new house template no longer costs 50-70 ms of GDScript on first use.
static func _merge_pieces(pieces: Array) -> ArrayMesh:
	var verts := PackedVector3Array(); var normals := PackedVector3Array(); var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array(); var uv2s := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array()
	for piece in pieces:
		var arrays: Array = piece[0]; var frame: Transform3D = piece[1]
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var count := src_v.size()
		if count == 0: continue
		var base := verts.size()
		verts.append_array(frame * src_v)
		var normal_frame := Transform3D(frame.basis.inverse().transposed(), Vector3.ZERO)
		var src_n = arrays[Mesh.ARRAY_NORMAL]
		if src_n != null and src_n.size() == count: normals.append_array(normal_frame * PackedVector3Array(src_n))
		else:
			var up := PackedVector3Array(); up.resize(count); up.fill(Vector3.UP); normals.append_array(up)
		var src_t = arrays[Mesh.ARRAY_TANGENT]
		var flip_sign := signf(frame.basis.determinant())
		if src_t != null and src_t.size() == count * 4:
			for i in count:
				var t: Vector3 = (frame.basis * Vector3(src_t[i * 4], src_t[i * 4 + 1], src_t[i * 4 + 2])).normalized()
				tangents.append_array([t.x, t.y, t.z, src_t[i * 4 + 3] * flip_sign])
		else:
			for i in count: tangents.append_array([1.0, 0.0, 0.0, 1.0])
		for slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			var src_uv = arrays[slot]
			var target: PackedVector2Array = uvs if slot == Mesh.ARRAY_TEX_UV else uv2s
			if src_uv != null and src_uv.size() == count: target.append_array(src_uv)
			else:
				var zero := PackedVector2Array(); zero.resize(count); target.append_array(zero)
			if slot == Mesh.ARRAY_TEX_UV: uvs = target
			else: uv2s = target
		var src_c = arrays[Mesh.ARRAY_COLOR]
		if src_c != null and src_c.size() == count: colors.append_array(src_c)
		else:
			var white := PackedColorArray(); white.resize(count); white.fill(Color.WHITE); colors.append_array(white)
		var src_i = arrays[Mesh.ARRAY_INDEX]
		var flip := frame.basis.determinant() < 0
		if src_i != null and not src_i.is_empty():
			for f in range(0, src_i.size(), 3):
				if flip: indices.append_array([base + src_i[f], base + src_i[f + 2], base + src_i[f + 1]])
				else: indices.append_array([base + src_i[f], base + src_i[f + 1], base + src_i[f + 2]])
		else:
			for f in range(0, count, 3):
				if flip: indices.append_array([base + f, base + f + 2, base + f + 1])
				else: indices.append_array([base + f, base + f + 1, base + f + 2])
	var out := []; out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts; out[Mesh.ARRAY_NORMAL] = normals; out[Mesh.ARRAY_TANGENT] = tangents
	out[Mesh.ARRAY_TEX_UV] = uvs; out[Mesh.ARRAY_TEX_UV2] = uv2s; out[Mesh.ARRAY_COLOR] = colors; out[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not verts.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh

func _exit_tree():
	for source in sources:
		if is_instance_valid(source): source.show()
