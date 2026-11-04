extends RefCounted

const A = preload("res://scripts/cast_art.gd")
const B = preload("res://scripts/build.gd")
static var materials: Dictionary = {}
static var eye_mesh: ArrayMesh
static var tubes: Dictionary = {}
const MATERIAL_LIMIT := 256

static func material(kind: String, tint: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var base = A.material(kind, tint, metal, glow)
	var key = base.resource_name + ":" + str(base.metallic) + ":" + str(base.emission_energy_multiplier if base.emission_enabled else 0)
	if materials.has(key): return materials[key]
	var result = base.duplicate() as StandardMaterial3D
	result.resource_name = "Low-poly " + base.resource_name
	result.normal_enabled = result.normal_texture != null
	result.normal_scale = 0.025
	if kind == "bark": result.albedo_texture = A._texture("fur_color.png")
	result.metallic_specular = 0.24 if metal < 0.2 else 0.42
	result.roughness = maxf(0.48, result.roughness)


	if materials.size() >= MATERIAL_LIMIT: materials.erase(materials.keys()[0])
	materials[key] = result
	return result

static func tube(parent: Node3D, points: PackedVector3Array, radii: PackedFloat32Array, surface: Material, sides: int = 8) -> MeshInstance3D:
	var node = A.tube(parent, points, radii, surface, mini(sides, 8))
	node.mesh = faceted(node.mesh)
	return node

static func faceted(mesh: Mesh) -> ArrayMesh:
	var key = mesh.get_instance_id()
	if not tubes.has(key):
		var source: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var coords: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		var flat = PackedVector3Array(); var normals = PackedVector3Array(); var uv = PackedVector2Array(); var tangents = PackedFloat32Array(); var order = PackedInt32Array()
		for i in range(0, indices.size(), 3):
			var a = vertices[indices[i]]; var b = vertices[indices[i + 1]]; var c = vertices[indices[i + 2]]
			var normal = (c - a).cross(b - a).normalized()
			if normal.length_squared() < 0.5: continue
			var tangent = (b - a).normalized()
			for k in range(3):
				order.append(flat.size()); flat.append(vertices[indices[i + k]]); normals.append(normal); uv.append(coords[indices[i + k]]); tangents.append_array([tangent.x, tangent.y, tangent.z, 1.0])
		if tubes.size() >= 128: tubes.erase(tubes.keys()[0])
		tubes[key] = A._mesh(flat, normals, uv, tangents, order, "Faceted creature tube")
	return tubes[key]

static func beveled_box(parent: Node3D, at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var node = B.beveled_box(parent, at, size, surface)
	node.mesh = faceted(node.mesh)
	return node

static func surface_point(mesh: MeshInstance3D, frame: Node3D, origin: Vector3, direction: Vector3):
	var local = frame.global_transform.affine_inverse() * mesh.global_transform
	var faces = mesh.mesh.get_faces(); var closest = INF; var point = null
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(origin, direction, local * faces[i], local * faces[i + 1], local * faces[i + 2])
		if hit is Vector3 and origin.distance_to(hit) < closest: closest = origin.distance_to(hit); point = hit
	return point

static func ring(parent: Node3D, at: Vector3, radius: float, width: float, surface: Material) -> MeshInstance3D:
	var points = PackedVector3Array(); var radii = PackedFloat32Array()
	for i in range(13): points.append(Vector3(cos(i * TAU / 12) * radius, 0, sin(i * TAU / 12) * radius)); radii.append(width)
	var node = tube(parent, points, radii, surface, 5); node.position = at; return node

static func section_mesh(rows: int, sides: int, sample: Callable, axial_z: bool, label: String) -> ArrayMesh:
	var points = PackedVector3Array(); var indices = PackedInt32Array(); var coords = PackedVector2Array()
	for row in range(rows + 1):
		for sector in range(sides + 1):
			points.append(sample.call(float(row) / rows, float(sector) / sides))
			coords.append(Vector2(float(sector) / sides, 1.0 - float(row) / rows))
	var bounds = AABB(points[0], Vector3.ZERO)
	for p in points: bounds = bounds.expand(p)
	var multiplier = Vector3.ONE / bounds.size; var center = bounds.get_center()
	for i in range(points.size()): points[i] = (points[i] - center) * multiplier
	for row in range(rows):
		for sector in range(sides):
			var i = row * (sides + 1) + sector; var n = i + sides + 1
			if row > 0: indices.append_array([i, n, i + 1] if axial_z else [i, i + 1, n])
			if row < rows - 1: indices.append_array([i + 1, n, n + 1] if axial_z else [i + 1, n + 1, n])
	var vertices = PackedVector3Array(); var normals = PackedVector3Array(); var uv = PackedVector2Array(); var tangents = PackedFloat32Array()
	for i in range(0, indices.size(), 3):
		var a = points[indices[i]]; var b = points[indices[i + 1]]; var c = points[indices[i + 2]]
		var normal = (c - a).cross(b - a).normalized()
		if normal.length_squared() < 0.5: continue
		var tangent = (b - a).normalized()
		for k in range(3):
			vertices.append(points[indices[i + k]]); normals.append(normal); uv.append(coords[indices[i + k]])
			tangents.append_array([tangent.x, tangent.y, tangent.z, 1.0])
	var flat_indices = PackedInt32Array()
	for i in range(vertices.size()): flat_indices.append(i)
	return A._mesh(vertices, normals, uv, tangents, flat_indices, label)

static func eyes(head: Node3D, spread: float, y: float, z: float, size: float, iris: Material = null, family: String = "fur", metal: float = 0.0, side_normal: float = 0.64) -> void:
	var geometry = head.find_children("*", "MeshInstance3D", true, false)
	if geometry.is_empty(): return


	var dark = material(family, Color("#182126"), metal)
	var light = material(family, Color("#fff0cd"), metal)
	var rim = material(family, Color("#4e4b48"), metal)
	if iris is StandardMaterial3D: iris = material(family, iris.albedo_color, metal)
	var landmarks = []
	for side in [-1.0, 1.0]:


		var normal = Vector3(side * side_normal, 0.03, -sqrt(1.0 - side_normal * side_normal)).normalized()
		var origin = Vector3(side * spread, y, z) + normal
		var point = origin - normal; var closest = INF
		for skull in geometry:
			var local = head.global_transform.affine_inverse() * skull.global_transform
			var faces = skull.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(origin, -normal, local * faces[i], local * faces[i + 1], local * faces[i + 2])
				if hit is Vector3 and origin.distance_to(hit) < closest: closest = origin.distance_to(hit); point = hit
		var frame = Basis(Quaternion(Vector3.BACK, normal))
		if eye_mesh == null: eye_mesh = section_mesh(6, 8, func (v: float, u: float): return Vector3(cos(u * TAU) * sin(v * PI) * 0.5, v - 0.5, sin(u * TAU) * sin(v * PI) * 0.5), false, "Faceted eye")
		var socket = B.mesh(head, eye_mesh, rim, point + normal * size * 0.06, Vector3(size * 1.24, size * 1.13, size * 0.4))
		socket.basis = frame.scaled(socket.scale)
		var eye = B.mesh(head, eye_mesh, dark, point + normal * size * 0.19, Vector3(size * 0.98, size * 0.94, size * 0.39))
		eye.basis = frame.scaled(eye.scale)

		if iris != null:
			var color = B.mesh(head, eye_mesh, iris, point + normal * size * 0.34 + frame.x * side * size * 0.19, Vector3(size * 0.28, size * 0.47, size * 0.1))
			color.basis = frame.scaled(color.scale)
		var glint = B.mesh(head, eye_mesh, light, point + normal * size * 0.38 + frame.y * size * 0.23 - frame.x * side * size * 0.17, Vector3.ONE * size * 0.15)
		glint.basis = frame.scaled(glint.scale)
		landmarks.append({"point": point + normal * size * 0.3, "normal": normal})
	head.set_meta("eye_landmarks", landmarks)
