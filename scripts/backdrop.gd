extends MeshInstance3D

func setup(seed_value: int) -> void:
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	var normals = PackedVector3Array()
	for row in range(3):
		for i in range(81):
			var angle = float(i) / 80 * TAU
			var radius = [154.0, 187.0, 232.0][row]
			var ridge = pow(absf(sin(angle * 4.0 + seed_value * 0.001)), 1.5) * 32 + sin(angle * 11.0) * 7
			var height = -7.0 if row == 0 else 20 + ridge if row == 1 else -10.0
			vertices.append(Vector3(sin(angle) * radius, height, cos(angle) * radius))
			colors.append(Color("#334e59").lerp(Color("#6a8589"), 0.45 if row == 1 else 0.9))
			normals.append(Vector3.UP)
	for row in range(2):
		for i in range(80):
			var j = row * 81 + i
			indices.append_array(PackedInt32Array([j, j + 81, j + 1, j + 1, j + 81, j + 82]))
	var data = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_COLOR] = colors
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_INDEX] = indices
	var shape = ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	mesh = shape
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
