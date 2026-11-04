extends RefCounted



static var mesh_cache: Dictionary = {}
static var palettes: Dictionary = {}
static var tangent_arrays: Dictionary = {}
const CACHE_LIMIT := 384

static func finish(part: Node3D) -> void:
	var buckets := {}
	_collect(part, Transform3D.IDENTITY, buckets)
	for key in buckets:
		var group: Dictionary = buckets[key]
		if group.nodes.size() < 2: continue
		var tinted: bool = group.materials.size() > 1
		var surface: Material = group.material
		if tinted:
			if not palettes.has(key):
				var palette := surface.duplicate() as StandardMaterial3D
				palette.albedo_color = Color.WHITE
				palette.vertex_color_use_as_albedo = true
				palette.vertex_color_is_srgb = true
				if palettes.size() >= 128: palettes.erase(palettes.keys()[0])
				palettes[key] = palette
			surface = palettes[key]
		var signature: String = str(key)
		for entry in group.entries:
			signature += ":%s:%s:%s:%s" % [entry.mesh.get_instance_id(), entry.surface, entry.transform, entry.color if tinted else Color.WHITE]
		signature += ":" + str(surface.get_instance_id())
		var geometry: ArrayMesh
		if mesh_cache.has(signature):
			geometry = mesh_cache[signature]
		else:
			geometry = _merge(group.entries, tinted)
			geometry.surface_set_material(0, surface)
			if mesh_cache.size() >= CACHE_LIMIT: mesh_cache.erase(mesh_cache.keys()[0])
			mesh_cache[signature] = geometry
		var combined := MeshInstance3D.new()
		combined.name = "CastSurface"
		combined.mesh = geometry
		combined.cast_shadow = group.shadow
		combined.layers = group.layers
		combined.visibility_range_end = group.distance
		combined.set_meta("cast_merged", true)
		part.add_child(combined)
		for original in group.nodes:
			if is_instance_valid(original): original.free()

static func _material_key(material: Material) -> String:


	if not material is StandardMaterial3D or not material.has_meta("cast_family") or material.emission_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.vertex_color_use_as_albedo or material.next_pass != null:
		return str(material.get_instance_id())
	var key := str(material.get_meta("cast_family"))
	for property in ["metallic", "roughness", "metallic_specular", "normal_enabled", "normal_scale", "roughness_texture_channel", "uv1_scale", "uv1_offset", "uv1_triplanar", "uv1_world_triplanar", "texture_filter", "cull_mode", "shading_mode", "diffuse_mode", "specular_mode", "vertex_color_is_srgb"]:
		key += ":" + str(material.get(property))
	for property in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture"]:
		var texture = material.get(property)
		key += ":" + str(texture.get_instance_id() if texture != null else 0)
	return key

static func _collect(parent: Node3D, relative: Transform3D, buckets: Dictionary) -> void:
	for child in parent.get_children():
		if not child is Node3D or child.is_in_group("batch_dynamic") or child.get_script() != null or child.top_level or not child.visible: continue
		var at: Transform3D = relative * child.transform
		if child is MeshInstance3D and child.mesh != null and child.skin == null and child.get_child_count() == 0:


			if child.mesh.get_surface_count() != 1: continue
			var material: Material = child.material_override if child.material_override != null else child.mesh.surface_get_material(0)
			if material == null: continue
			if material is StandardMaterial3D and material.uv1_world_triplanar: continue
			var key := "%s:%s:%s:%s" % [_material_key(material), child.cast_shadow, child.layers, child.visibility_range_end]
			if not buckets.has(key):
				buckets[key] = {"material": material, "materials": {}, "shadow": child.cast_shadow, "layers": child.layers, "distance": child.visibility_range_end, "nodes": [], "entries": []}
			buckets[key].materials[material.get_instance_id()] = true
			buckets[key].nodes.append(child)
			buckets[key].entries.append({"mesh": child.mesh, "surface": 0, "transform": at, "color": material.albedo_color if material is StandardMaterial3D else Color.WHITE})
		elif not child is GeometryInstance3D:
			_collect(child, at, buckets)

static func _merge(entries: Array, tint_vertices := false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for entry in entries:
		var data: Array = entry.mesh.surface_get_arrays(entry.surface)


		if data[Mesh.ARRAY_NORMAL] != null and data[Mesh.ARRAY_TEX_UV] != null and not data[Mesh.ARRAY_TEX_UV].is_empty():
			var frame_key := "%s:%s" % [entry.mesh.get_instance_id(), entry.surface]
			if not tangent_arrays.has(frame_key):
				var tool := SurfaceTool.new()
				tool.create_from(entry.mesh, entry.surface)
				tool.generate_tangents()
				if tangent_arrays.size() >= 128: tangent_arrays.erase(tangent_arrays.keys()[0])
				tangent_arrays[frame_key] = tool.commit_to_arrays()
			data = tangent_arrays[frame_key]
		var source: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL] if data[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var source_tangents: PackedFloat32Array = data[Mesh.ARRAY_TANGENT] if data[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var source_uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV] if data[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var source_colors: PackedColorArray = data[Mesh.ARRAY_COLOR] if data[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var source_indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var at: Transform3D = entry.transform
		var normal_basis := at.basis.inverse().transposed()
		var handedness := -1.0 if at.basis.determinant() < 0 else 1.0
		var start := vertices.size()
		for i in range(source.size()):
			vertices.append(at * source[i])
			var normal := (normal_basis * source_normals[i]).normalized() if source_normals.size() > i else Vector3.UP
			normals.append(normal)
			var tangent: Vector3
			var sign_value := handedness
			if source_tangents.size() >= (i + 1) * 4:
				tangent = at.basis * Vector3(source_tangents[i * 4], source_tangents[i * 4 + 1], source_tangents[i * 4 + 2])
				sign_value *= source_tangents[i * 4 + 3]
			else:
				tangent = Vector3.RIGHT if absf(normal.x) < 0.8 else Vector3.FORWARD
			tangent = (tangent - normal * tangent.dot(normal)).normalized()
			if tangent.length_squared() < 0.5: tangent = normal.cross(Vector3.FORWARD if absf(normal.z) < 0.8 else Vector3.UP).normalized()
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, sign_value]))
			uvs.append(source_uvs[i] if source_uvs.size() > i else Vector2.ZERO)
			var color: Color = source_colors[i] if source_colors.size() > i else Color.WHITE
			colors.append(color * entry.color if tint_vertices else color)
		var length := source_indices.size() if not source_indices.is_empty() else source.size()
		for triangle in range(0, length, 3):
			for corner in ([0, 2, 1] if handedness < 0 else [0, 1, 2]):
				var i: int = source_indices[triangle + corner] if not source_indices.is_empty() else triangle + corner
				indices.append(start + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
