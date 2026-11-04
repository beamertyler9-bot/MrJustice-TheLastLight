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
		var builder = SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in group.pieces:
			var arrays = piece[0]; var frame: Transform3D = piece[1]; var normals = frame.basis.inverse().transposed(); var indices = arrays[Mesh.ARRAY_INDEX]
			var order = indices if indices != null and not indices.is_empty() else range(arrays[Mesh.ARRAY_VERTEX].size())
			for face in range(0, order.size(), 3):
				var corners = [0, 2, 1] if frame.basis.determinant() < 0 else [0, 1, 2]
				for corner in corners:
					var index = order[face + corner]
					builder.set_normal((normals * arrays[Mesh.ARRAY_NORMAL][index]).normalized())
					builder.set_uv(arrays[Mesh.ARRAY_TEX_UV][index] if arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty() else Vector2.ZERO)
					builder.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][index] if arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty() else Vector2.ZERO)
					builder.set_color(arrays[Mesh.ARRAY_COLOR][index] if arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty() else Color.WHITE)
					if arrays[Mesh.ARRAY_TANGENT] != null and not arrays[Mesh.ARRAY_TANGENT].is_empty():
						var data = arrays[Mesh.ARRAY_TANGENT]; var tangent = (frame.basis * Vector3(data[index * 4], data[index * 4 + 1], data[index * 4 + 2])).normalized(); builder.set_tangent(Plane(tangent, data[index * 4 + 3] * signf(frame.basis.determinant())))
					else: builder.set_tangent(Plane(1, 0, 0, 1))
					builder.add_vertex(frame * arrays[Mesh.ARRAY_VERTEX][index])
		builder.index(); var mesh = builder.commit(); mesh.surface_set_material(0, group.material)
		var geometry = MeshInstance3D.new(); geometry.name = "SharedArchitecturalSurface"; geometry.mesh = mesh; var source = group.source
		geometry.layers = source.layers; geometry.cast_shadow = source.cast_shadow; geometry.visibility_range_begin = source.visibility_range_begin; geometry.visibility_range_end = source.visibility_range_end; geometry.visibility_range_begin_margin = source.visibility_range_begin_margin; geometry.visibility_range_end_margin = source.visibility_range_end_margin; geometry.visibility_range_fade_mode = source.visibility_range_fade_mode
		if source.is_in_group("imported_detail"): geometry.add_to_group("imported_detail")
		result.add_child(geometry)
		var visibility = {}
		for property in ["visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode"]: visibility[property] = geometry.get(property)
		saved.append({"mesh": mesh, "layers": geometry.layers, "shadow": geometry.cast_shadow, "visibility": visibility, "detail": geometry.is_in_group("imported_detail")})
	if not template_key.is_empty(): templates[template_key] = saved
	return result
func _exit_tree():
	for source in sources:
		if is_instance_valid(source): source.show()
