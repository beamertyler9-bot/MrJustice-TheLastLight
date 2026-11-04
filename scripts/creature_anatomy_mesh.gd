extends RefCounted



const A = preload("res://scripts/cast_art.gd")
const B = preload("res://scripts/build.gd")
static var meshes: Dictionary = {}
const CACHE_LIMIT := 128

static func _triangle(points: Array, coords: Array, vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, tangents: PackedFloat32Array) -> void:
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	if normal.length_squared() < 0.5: return
	var edge1: Vector3 = points[1] - points[0]; var edge2: Vector3 = points[2] - points[0]
	var uv1: Vector2 = coords[1] - coords[0]; var uv2: Vector2 = coords[2] - coords[0]
	var determinant = uv1.x * uv2.y - uv1.y * uv2.x
	assert(absf(determinant) > 1.0e-06, "Anatomical UV triangles must have an area")
	var tangent = (edge1 * uv2.y - edge2 * uv1.y) / determinant
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent = (edge2 * uv1.x - edge1 * uv2.x) / determinant
	var handedness = -1.0 if normal.cross(tangent).dot(bitangent) < 0 else 1.0
	for i in range(3):
		vertices.append(points[i]); normals.append(normal); uv.append(coords[i]); tangents.append_array([tangent.x, tangent.y, tangent.z, handedness])

static func geometry(sections: Array[Vector4], axis_z: bool = true, sides: int = 8) -> ArrayMesh:
	assert(sections.size() >= 2)
	var key = str(axis_z) + ":" + str(sides) + ":" + str(sections)
	if meshes.has(key): return meshes[key]
	var rows = []; var centres = []
	for section in sections:
		var center = (section.z + section.w) * 0.5; var radius = absf(section.z - section.w) * 0.5
		assert(section.y > 0 and radius > 0, "Anatomical ends are capped rings, not pinched points")
		var ring = []
		for i in range(sides):
			var angle = float(i) * TAU / sides
			ring.append(Vector3(cos(angle) * section.y, center + sin(angle) * radius, section.x) if axis_z else Vector3(cos(angle) * section.y, section.x, center + sin(angle) * radius))
		rows.append(ring); centres.append(Vector3(0, center, section.x) if axis_z else Vector3(0, section.x, center))
	var vertices = PackedVector3Array(); var normals = PackedVector3Array(); var uv = PackedVector2Array(); var tangents = PackedFloat32Array()
	for row in range(rows.size() - 1):
		for i in range(sides):
			var j = (i + 1) % sides; var a: Vector3 = rows[row][i]; var b: Vector3 = rows[row][j]; var c: Vector3 = rows[row + 1][i]; var d: Vector3 = rows[row + 1][j]
			var u = float(i) / sides; var v = float(row) / (rows.size() - 1); var du = 1.0 / sides; var dv = 1.0 / (rows.size() - 1)
			if axis_z:
				_triangle([a, c, b], [Vector2(u, v), Vector2(u, v + dv), Vector2(u + du, v)], vertices, normals, uv, tangents)
				_triangle([b, c, d], [Vector2(u + du, v), Vector2(u, v + dv), Vector2(u + du, v + dv)], vertices, normals, uv, tangents)
			else:
				_triangle([a, b, c], [Vector2(u, v), Vector2(u + du, v), Vector2(u, v + dv)], vertices, normals, uv, tangents)
				_triangle([b, d, c], [Vector2(u + du, v), Vector2(u + du, v + dv), Vector2(u, v + dv)], vertices, normals, uv, tangents)
	for end in [0, rows.size() - 1]:
		for i in range(sides):
			var j = (i + 1) % sides
			var order = [centres[end], rows[end][i], rows[end][j]] if (end == 0) == axis_z else [centres[end], rows[end][j], rows[end][i]]
			_triangle(order, [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)], vertices, normals, uv, tangents)
	var indices = PackedInt32Array()
	for i in range(vertices.size()): indices.append(i)
	var mesh = A._mesh(vertices, normals, uv, tangents, indices, "Anatomical contour")
	if meshes.size() >= CACHE_LIMIT: meshes.erase(meshes.keys()[0])
	meshes[key] = mesh
	return mesh

static func z_loft(parent: Node3D, sections: Array[Vector4], material: Material, label: String = "Anatomy", sides: int = 8) -> MeshInstance3D:
	var node = B.mesh(parent, geometry(sections, true, sides), material); node.name = label; return node

static func y_loft(parent: Node3D, sections: Array[Vector4], material: Material, label: String = "Anatomy", sides: int = 8) -> MeshInstance3D:
	var node = B.mesh(parent, geometry(sections, false, sides), material); node.name = label; return node


static func segment(parent: Node3D, a: Vector3, b: Vector3, width_a: float, width_b: float, depth_a: float, depth_b: float, material: Material) -> MeshInstance3D:
	var length = a.distance_to(b)
	var sections: Array[Vector4] = [Vector4(-0.012, width_a * 0.5, -depth_a * 0.5, depth_a * 0.5), Vector4(length * 0.22, width_a * 0.51, -depth_a * 0.51, depth_a * 0.51), Vector4(length * 0.8, lerpf(width_a, width_b, 0.8) * 0.5, -lerpf(depth_a, depth_b, 0.8) * 0.5, lerpf(depth_a, depth_b, 0.8) * 0.5), Vector4(length + 0.012, width_b * 0.5, -depth_b * 0.5, depth_b * 0.5)]
	var node = y_loft(parent, sections, material, "TaperedLimb")
	node.position = a; node.quaternion = Quaternion(Vector3.UP, (b - a).normalized()); return node


static func paw(parent: Node3D, at: Vector3, width: float, length: float, height: float, material: Material) -> MeshInstance3D:
	var sections: Array[Vector4] = [Vector4(-length * 0.72, width * 0.38, height * 0.52, 0), Vector4(-length * 0.53, width * 0.5, height * 0.72, 0), Vector4(-length * 0.08, width * 0.46, height, 0), Vector4(length * 0.25, width * 0.29, height * 0.74, 0)]
	var node = z_loft(parent, sections, material, "Foot"); node.position = at; return node
