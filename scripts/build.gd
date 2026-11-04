extends RefCounted

const Surfaces = preload("res://scripts/surfaces.gd")

static var cache: Dictionary = {}
static var geometry_cache: Dictionary = {}
static var palette_materials: Dictionary = {}

static func ink_material(width: float = 0.014, wind_strength: float = 0.0, rooted: bool = false) -> ShaderMaterial:
	var key = "ink:%s:%s:%s" % [width, wind_strength, rooted]
	if cache.has(key):
		return cache[key]
	var ink = ShaderMaterial.new()
	ink.shader = preload("res://shaders/ink.gdshader")
	ink.set_shader_parameter("ink_width", width)
	ink.set_shader_parameter("wind_strength", wind_strength)
	ink.set_shader_parameter("rooted", rooted)
	cache[key] = ink
	return ink

static func mat(hex: String, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key = hex + ":" + str(metal) + ":" + str(glow)
	if cache.has(key):
		return cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metal
	m.roughness = 0.25 if metal > 0.1 else 0.77
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.set_meta("static_palette", true)
	if glow > 0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = glow * 0.22
	cache[key] = m
	return m

static func surface(kind: String, hex: String, metal: float = 0.0) -> StandardMaterial3D:
	return Surfaces.get_surface(kind, Color(hex), metal)

static func world_surface(kind: String, hex: String, metal: float = 0.0) -> StandardMaterial3D:
	return Surfaces.get_surface(kind, Color(hex), metal, true)



static func flame(parent: Node3D, pos: Vector3, size: Vector3) -> MeshInstance3D:
	if not geometry_cache.has("flame"):
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var profile := [0.1, 0.35, 0.43, 0.35, 0.23, 0.11, 0.005]
		for row in range(profile.size()):
			var v := float(row) / float(profile.size() - 1)
			for sector in range(13):
				var angle := float(sector) / 12.0 * TAU
				vertices.append(Vector3(cos(angle) * profile[row] + sin(v * 4.7) * v * 0.22, v - 0.5, sin(angle) * profile[row] * 0.82))
				normals.append(Vector3(cos(angle), 0.2, sin(angle)).normalized())
				uvs.append(Vector2(float(sector) / 12.0, v))
		for row in range(profile.size() - 1):
			for sector in range(12):
				var i := row * 13 + sector
				indices.append_array(PackedInt32Array([i, i + 1, i + 13, i + 1, i + 14, i + 13]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var shape := ArrayMesh.new()
		shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geometry_cache.flame = shape
	if not cache.has("flame_material"):
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/flame.gdshader")
		cache.flame_material = material
	return mesh(parent, geometry_cache.flame, cache.flame_material, pos, size)

static func mesh(parent: Node3D, shape: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = shape
	n.material_override = material
	n.position = pos
	n.scale = size
	parent.add_child(n)
	return n

static func solid(parent: Node3D, pos: Vector3, shape: Shape3D) -> StaticBody3D:
	var b = StaticBody3D.new()
	var c = CollisionShape3D.new()
	c.shape = shape
	b.position = pos
	b.add_child(c)
	parent.add_child(b)
	return b

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	if not geometry_cache.has("cube"):
		geometry_cache.cube = BoxMesh.new()
	var n = mesh(parent, geometry_cache.cube, material, pos, size)
	if collision:
		var shape = BoxShape3D.new()
		shape.size = size
		solid(parent, pos, shape)
	return n

static func ball(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	if not geometry_cache.has("ball"):
		var s = SphereMesh.new()
		s.radial_segments = 20
		s.rings = 10
		s.radius = 0.5
		s.height = 1.0
		geometry_cache.ball = s
	return mesh(parent, geometry_cache.ball, material, pos, size)

static func cyl(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, collision: bool = false, top: float = -1.0) -> MeshInstance3D:
	var key = "cylinder:%s:%s:%s" % [radius, height, top]
	if not geometry_cache.has(key):
		var s = CylinderMesh.new()
		s.top_radius = radius if top < 0 else top
		s.bottom_radius = radius
		s.height = height
		s.radial_segments = 16
		geometry_cache[key] = s
	var n = mesh(parent, geometry_cache[key], material, pos)
	if collision:
		var sh = CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		solid(parent, pos, sh)
	return n

static func ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var key = "ring:%s:%s" % [radius, thickness]
	if not geometry_cache.has(key):
		var t = TorusMesh.new()
		t.inner_radius = radius - thickness
		t.outer_radius = radius + thickness
		t.rings = 24
		t.ring_segments = 8
		geometry_cache[key] = t
	return mesh(parent, geometry_cache[key], material, pos)

static func instances(parent: Node3D, transforms: Array[Transform3D], shape: Mesh, material: Material) -> void:
	if transforms.is_empty():
		return
	var n = MultiMeshInstance3D.new()
	n.multimesh = MultiMesh.new()
	n.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	n.multimesh.mesh = shape
	n.multimesh.instance_count = transforms.size()
	n.multimesh.buffer = _instance_buffer(transforms)
	n.set_meta("instance_transforms", transforms.duplicate())
	n.material_override = material
	parent.add_child(n)



static func beveled_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	if not geometry_cache.has("beveled_cube"):
		var faces: Array[PackedVector3Array] = []
		var inset = 0.43
		for axis in range(3):
			for sign_value in [-1.0, 1.0]:
				var u = (axis + 1) % 3
				var v = (axis + 2) % 3
				var face = PackedVector3Array()
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var p = Vector3.ZERO
					p[axis] = sign_value * 0.5
					p[u] = corner.x * inset
					p[v] = corner.y * inset
					face.append(p)
				faces.append(face)
		for axis in range(3):
			var u = (axis + 1) % 3
			var v = (axis + 2) % 3
			for a in [-1.0, 1.0]:
				for b in [-1.0, 1.0]:
					var face = PackedVector3Array()
					for tip in [-1.0, 1.0]:
						var p = Vector3.ZERO
						p[axis] = tip * inset
						p[u] = a * 0.5
						p[v] = b * inset
						face.append(p)
					for tip in [1.0, -1.0]:
						var p = Vector3.ZERO
						p[axis] = tip * inset
						p[u] = a * inset
						p[v] = b * 0.5
						face.append(p)
					faces.append(face)
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					faces.append(PackedVector3Array([Vector3(x * 0.5, y * inset, z * inset), Vector3(x * inset, y * 0.5, z * inset), Vector3(x * inset, y * inset, z * 0.5)]))
		var geometry := _flat_geometry(faces)
		var arrays := geometry.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals := PackedVector3Array()
		for point in points:
			var core := point.clamp(Vector3.ONE * -inset, Vector3.ONE * inset)
			normals.append((point - core).normalized())
		arrays[Mesh.ARRAY_NORMAL] = normals
		var rounded := ArrayMesh.new()
		rounded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geometry_cache.beveled_cube = rounded
	var n = mesh(parent, geometry_cache.beveled_cube, material, pos, size)
	if collision:
		var shape = BoxShape3D.new()
		shape.size = size
		solid(parent, pos, shape)
	return n


static func facet(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	if not geometry_cache.has("crystal"):
		var faces: Array[PackedVector3Array] = []
		for i in range(6):
			var a = float(i) / 6.0 * TAU
			var b = float(i + 1) / 6.0 * TAU
			var p = Vector3(cos(a) * 0.5, 0.24, sin(a) * 0.5)
			var q = Vector3(cos(b) * 0.5, 0.24, sin(b) * 0.5)
			var r = Vector3(cos(a) * 0.43, -0.28, sin(a) * 0.43)
			var s = Vector3(cos(b) * 0.43, -0.28, sin(b) * 0.43)
			faces.append(PackedVector3Array([p, q, Vector3(0.08, 0.5, -0.04)]))
			faces.append(PackedVector3Array([p, r, s, q]))
			faces.append(PackedVector3Array([r, Vector3(-0.04, -0.5, 0.03), s]))
		geometry_cache.crystal = _flat_geometry(faces)
	return mesh(parent, geometry_cache.crystal, material, pos, size)

static func branch(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material, taper: float = 0.45) -> MeshInstance3D:
	var key = "branch:%s" % taper
	if not geometry_cache.has(key):
		var shape = CylinderMesh.new()
		shape.radial_segments = 10
		shape.bottom_radius = 1.0
		shape.top_radius = taper
		shape.height = 1.0
		geometry_cache[key] = shape
	var delta = end - start
	var n = mesh(parent, geometry_cache[key], material, (start + end) * 0.5)
	n.basis = Basis(Quaternion(Vector3.UP, delta.normalized())) * Basis.from_scale(Vector3(radius, delta.length(), radius))
	return n

static func _flat_geometry(faces: Array[PackedVector3Array]) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	for face in faces:
		var normal = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		var center_point = Vector3.ZERO
		for point in face:
			center_point += point
		if normal.dot(center_point) < 0.0:
			normal = -normal

		for i in range(1, face.size() - 1):
			var tri = [face[0], face[i], face[i + 1]]
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0.0:
				tri = [face[0], face[i + 1], face[i]]
			for point in tri:
				vertices.append(point)
				normals.append(normal)
				var axis := normal.abs().max_axis_index()
				uvs.append((Vector2(point.z, point.y) if axis == 0 else Vector2(point.x, point.z) if axis == 1 else Vector2(point.x, point.y)) + Vector2.ONE * 0.5)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var shape = ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return shape




static func batch_static(root: Node3D) -> int:
	if _batch_dynamic(root):
		return 0
	var buckets: Dictionary = {}
	var saved = _collect_static(root, root, Transform3D.IDENTITY, buckets)
	for bucket in buckets.values():
		if bucket.nodes.size() < 2:
			continue
		var source: MeshInstance3D = bucket.nodes[0]
		var batch = MultiMeshInstance3D.new()
		batch.name = "StaticArt"
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = source.mesh
		batch.multimesh.instance_count = bucket.nodes.size()
		batch.material_override = source.material_override
		batch.cast_shadow = source.cast_shadow
		batch.layers = source.layers
		batch.visibility_range_begin = source.visibility_range_begin; batch.visibility_range_end = source.visibility_range_end
		batch.visibility_range_begin_margin = source.visibility_range_begin_margin; batch.visibility_range_end_margin = source.visibility_range_end_margin; batch.visibility_range_fade_mode = source.visibility_range_fade_mode
		if source.is_in_group("imported_detail"):
			batch.add_to_group("imported_detail")
			batch.visibility_range_end = source.visibility_range_end
		var transforms: Array[Transform3D] = []
		var bounds: AABB = bucket.transforms[0] * source.mesh.get_aabb()
		for i in range(bucket.nodes.size()):
			transforms.append(bucket.transforms[i])
			bounds = bounds.merge(bucket.transforms[i] * source.mesh.get_aabb())
		batch.multimesh.buffer = _instance_buffer(transforms)
		batch.set_meta("instance_transforms", transforms.duplicate())
		batch.custom_aabb = bounds
		root.add_child(batch)
		saved += bucket.nodes.size() - 1
		for node in bucket.nodes:
			node.free()
	return saved

static func _batch_dynamic(node: Node) -> bool:
	return node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D or node is Skeleton3D or node.is_in_group("float_pickup") or node.is_in_group("batch_dynamic") or bool(node.get_meta("batch_dynamic", false))






static func merge_colored(root: Node3D) -> int:
	if _batch_dynamic(root): return 0
	var buckets: Dictionary = {}
	var saved := _collect_colored(root, Transform3D.IDENTITY, buckets)
	var source_count := 0
	for bucket in buckets.values(): source_count += bucket.size()
	if source_count < 2: return saved + batch_static(root)
	var render_groups: Dictionary = {}
	var consumed: Array[MeshInstance3D] = []
	for key in buckets:
		var bucket: Array = buckets[key]
		var source: MeshInstance3D = bucket[0].node
		var render_key := "%s:%s" % [source.layers, source.cast_shadow]
		if not render_groups.has(render_key): render_groups[render_key] = {"source": source, "geometry": ArrayMesh.new()}
		var combined_geometry: ArrayMesh = render_groups[render_key].geometry
		var material: StandardMaterial3D = source.material_override
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var radial_hulls := PackedFloat32Array()
		var indices := PackedInt32Array()
		for entry in bucket:
			var node: MeshInstance3D = entry.node
			var transform_value: Transform3D = entry.transform
			var normal_basis := transform_value.basis.inverse().transposed()
			var paint: StandardMaterial3D = node.material_override
			consumed.append(node)
			for surface in range(node.mesh.get_surface_count()):
				var arrays := node.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var directions: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var offset := vertices.size()
				for i in range(points.size()):
					vertices.append(transform_value * points[i])
					normals.append((normal_basis * directions[i]).normalized())
					var radial: Vector3 = points[i]
					if paint.get_meta("merged_radial", false) and arrays[Mesh.ARRAY_TANGENT] != null:
						var at := i * 4
						radial = Vector3(arrays[Mesh.ARRAY_TANGENT][at], arrays[Mesh.ARRAY_TANGENT][at + 1], arrays[Mesh.ARRAY_TANGENT][at + 2])
					radial = (transform_value.basis * radial).normalized()
					radial_hulls.append_array(PackedFloat32Array([radial.x, radial.y, radial.z, 1.0]))
					var color := paint.albedo_color
					if paint.vertex_color_use_as_albedo and arrays[Mesh.ARRAY_COLOR] != null:
						color *= arrays[Mesh.ARRAY_COLOR][i]
					colors.append(color)
					uvs.append(arrays[Mesh.ARRAY_TEX_UV][i] if arrays[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO)
				if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty():
					for index in arrays[Mesh.ARRAY_INDEX]: indices.append(offset + index)
				else:
					for i in range(points.size()): indices.append(offset + i)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TANGENT] = radial_hulls
		arrays[Mesh.ARRAY_INDEX] = indices
		combined_geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if not palette_materials.has(key):
			var palette := material.duplicate() as StandardMaterial3D
			palette.albedo_color = Color.WHITE
			palette.vertex_color_use_as_albedo = true
			palette.vertex_color_is_srgb = true
			palette.set_meta("merged_radial", true)
			if material.next_pass is ShaderMaterial:
				var ink := ShaderMaterial.new()
				ink.shader = preload("res://shaders/ink_merged.gdshader")
				ink.set_shader_parameter("ink_width", material.next_pass.get_shader_parameter("ink_width"))
				palette.next_pass = ink
			palette_materials[key] = palette
		combined_geometry.surface_set_material(combined_geometry.get_surface_count() - 1, palette_materials[key])
	for group in render_groups.values():
		var geometry: ArrayMesh = group.geometry
		var source_node: MeshInstance3D = group.source
		var override_material: Material = geometry.surface_get_material(0) if geometry.get_surface_count() == 1 else null
		var merged := mesh(root, geometry, override_material)
		merged.name = "ColoredArt"
		merged.cast_shadow = source_node.cast_shadow
		merged.layers = source_node.layers
	saved += consumed.size() - render_groups.size()
	for node in consumed: node.free()
	return saved + batch_static(root)

static func _collect_colored(parent: Node3D, relative: Transform3D, buckets: Dictionary) -> int:
	var saved := 0
	for child in parent.get_children():
		if not child is Node3D or _batch_dynamic(child) or child.get_script() != null or not child.visible or child.top_level: continue
		if child.is_in_group("interactable") or child.is_in_group("static_art_root"):
			saved += merge_colored(child)
			continue
		var next: Transform3D = relative * child.transform
		if child is MeshInstance3D and child.mesh != null and child.get_child_count() == 0 and child.skin == null and child.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = child.material_override
			if material.uv1_triplanar and not material.uv1_world_triplanar: continue
			if not material.get_meta("static_palette", false) or material.emission_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
			var ink_id := material.next_pass.get_instance_id() if material.next_pass != null else 0


			var texture_id := material.albedo_texture.get_instance_id() if material.albedo_texture != null else 0
			var normal_id := material.normal_texture.get_instance_id() if material.normal_texture != null else 0
			var key := "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [material.metallic, material.roughness, material.shading_mode, material.diffuse_mode, material.specular_mode, ink_id, material.cull_mode, child.cast_shadow, child.layers, texture_id, normal_id, material.normal_scale, material.uv1_triplanar, material.uv1_scale, material.uv1_world_triplanar, material.metallic_specular]
			key += ":%s:%s:%s:%s" % [material.texture_filter, material.uv1_offset, material.uv1_triplanar_sharpness, material.normal_enabled]
			if not buckets.has(key): buckets[key] = []
			buckets[key].append({"node": child, "transform": next})
		elif not child is MultiMeshInstance3D:
			saved += _collect_colored(child, next, buckets)
	return saved

static func _collect_static(root: Node3D, parent: Node, relative: Transform3D, buckets: Dictionary) -> int:
	var saved = 0
	for child in parent.get_children():
		if _batch_dynamic(child) or child.get_script() != null:
			continue
		if child is Node3D and (not child.visible or child.top_level):
			continue
		if child is Node3D and (child.is_in_group("interactable") or child.is_in_group("static_art_root")):
			saved += batch_static(child)
			continue
		var next: Transform3D = relative * child.transform if child is Node3D else relative
		if child is MeshInstance3D and child.mesh != null and child.get_child_count() == 0 and child.skin == null:
			var material: Material = child.material_override
			var compatible = true
			if material is StandardMaterial3D and material.uv1_triplanar and not material.uv1_world_triplanar: compatible = false
			if material == null:
				for surface in range(child.mesh.get_surface_count()):


					var paint = child.mesh.surface_get_material(surface)
					if child.get_surface_override_material(surface) != null or (paint is StandardMaterial3D and paint.uv1_triplanar and not paint.uv1_world_triplanar): compatible = false; break
			if not compatible: continue
			var key = "%s:%s:%s:%s:%s:%s:%s:%s:%s" % [child.mesh.get_instance_id(), material.get_instance_id() if material else 0, child.cast_shadow, child.layers, child.visibility_range_begin, child.visibility_range_end, child.visibility_range_begin_margin, child.visibility_range_end_margin, child.visibility_range_fade_mode]
			if not buckets.has(key):
				buckets[key] = {"nodes": [], "transforms": []}
			buckets[key].nodes.append(child)
			buckets[key].transforms.append(next)
		elif not child is MultiMeshInstance3D:
			saved += _collect_static(root, child, next, buckets)
	return saved



static func _instance_buffer(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer = PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for i in range(transforms.size()):
		var t = transforms[i]
		var at = i * 12
		buffer[at] = t.basis.x.x
		buffer[at + 1] = t.basis.y.x
		buffer[at + 2] = t.basis.z.x
		buffer[at + 3] = t.origin.x
		buffer[at + 4] = t.basis.x.y
		buffer[at + 5] = t.basis.y.y
		buffer[at + 6] = t.basis.z.y
		buffer[at + 7] = t.origin.y
		buffer[at + 8] = t.basis.x.z
		buffer[at + 9] = t.basis.y.z
		buffer[at + 10] = t.basis.z.z
		buffer[at + 11] = t.origin.z
	return buffer
