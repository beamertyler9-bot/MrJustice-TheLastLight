extends RefCounted


const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/cast_art.gd")
const F = preload("res://scripts/creature_facets.gd")
const ROWS := 8
const SIDES := 8
static var shapes: Dictionary = {}
static var wings: Dictionary = {}
const SECTIONS = {
	"body": [0, 0.34, 0.46, 0.5, 0.5, 0.48, 0.43, 0.3, 0],
	"chest": [0, 0.34, 0.45, 0.43, 0.41, 0.49, 0.5, 0.35, 0],
	"skull": [0, 0.19, 0.31, 0.42, 0.49, 0.5, 0.43, 0.26, 0],
	"muzzle": [0, 0.38, 0.47, 0.5, 0.49, 0.45, 0.38, 0.27, 0],
	"limb": [0, 0.34, 0.43, 0.48, 0.5, 0.47, 0.4, 0.29, 0],
	"paw": [0, 0.3, 0.44, 0.49, 0.5, 0.47, 0.38, 0.23, 0],
	"ear": [0, 0.26, 0.42, 0.5, 0.46, 0.35, 0.23, 0.1, 0],
	"feather": [0, 0.13, 0.31, 0.44, 0.5, 0.47, 0.36, 0.18, 0],
	"plate": [0, 0.26, 0.43, 0.49, 0.5, 0.47, 0.37, 0.21, 0]}
static func point(profile: String, v: float, u: float) -> Vector3:
	var source: Array = SECTIONS.get(profile, SECTIONS.body)
	var step = clampf(v, 0, 1) * 8.0; var row = mini(7, int(step))
	var r = lerpf(source[row], source[row + 1], smoothstep(0, 1, step - row))
	var angle = u * TAU; var x = cos(angle) * r; var z = sin(angle) * r
	if profile in ["ear", "feather"]: z *= 0.23
	if profile == "plate": z *= 0.36
	if profile == "paw":
		x = signf(x) * pow(absf(x) * 2.0, 0.72) * 0.5
		z = signf(z) * pow(absf(z) * 2.0, 0.8) * 0.5
	if profile in ["body", "muzzle", "paw"]:
		return Vector3(x, z * (0.8 if profile == "body" else 1.0) + 0.035 * sin(v * PI), v - 0.5)
	return Vector3(x, v - 0.5, z + (0.045 * sin(v * PI) if profile == "skull" else 0.0))
static func geometry(profile: String) -> ArrayMesh:
	if shapes.has(profile): return shapes[profile]
	shapes[profile] = F.section_mesh(ROWS, SIDES, func (v: float, u: float): return point(profile, v, u), profile in ["body", "muzzle", "paw"], "Low-poly creature " + profile)
	return shapes[profile]
static func shape(parent: Node3D, p: Vector3, size: Vector3, material: Material, profile: String = "body", rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node = B.mesh(parent, geometry(profile), material, p, size); node.rotation = rotation; return node
static func span(parent: Node3D, start: Vector3, end: Vector3, width: float, depth: float, material: Material, profile: String = "limb") -> MeshInstance3D:
	var delta = end - start
	var node = shape(parent, (start + end) * 0.5, Vector3(width, delta.length() + width * 0.25, depth), material, profile)
	if delta.length_squared() > 1.0e-06: node.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return node
static func wing(parent: Node3D, side: float, kind: String, material: Material) -> MeshInstance3D:
	var key = kind + str(side)
	if not wings.has(key):
		var points: Array
		match kind:
			"moth": points = [Vector2(0.02, -0.12), Vector2(0.27, -0.39), Vector2(0.65, -0.33), Vector2(0.74, -0.12), Vector2(0.55, 0.02), Vector2(0.61, 0.25), Vector2(0.4, 0.38), Vector2(0.18, 0.26), Vector2(0.02, 0.12)]
			"bee": points = [Vector2(0.01, -0.07), Vector2(0.24, -0.4), Vector2(0.51, -0.34), Vector2(0.55, -0.16), Vector2(0.35, 0.05), Vector2(0.4, 0.2), Vector2(0.21, 0.27), Vector2(0.02, 0.08)]
			"manta": points = [Vector2(0.0, -0.32), Vector2(0.55, -0.17), Vector2(1.0, 0.11), Vector2(0.67, 0.23), Vector2(0.23, 0.25), Vector2(0, 0.37)]
			_: points = [Vector2(0.0, -0.12), Vector2(0.27, -0.24), Vector2(0.7, -0.12), Vector2(0.96, 0.22), Vector2(0.77, 0.3), Vector2(0.57, 0.25), Vector2(0.36, 0.2), Vector2(0.06, 0.2)]
		var outline = PackedVector2Array()
		for p in points: outline.append(Vector2(p.x * side, p.y))
		var triangles = Geometry2D.triangulate_polygon(outline)
		var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for layer in [-1.0, 1.0]:
			for j in range(0, triangles.size(), 3):
				for k in ([0, 1, 2] if layer * side > 0 else [2, 1, 0]):
					var p = outline[triangles[j + k]]; surface.set_uv(Vector2(absf(p.x), p.y + 0.4)); surface.add_vertex(Vector3(p.x, layer * 0.012, p.y))
		for i in range(outline.size()):
			var p = outline[i]; var q = outline[(i + 1) % outline.size()]
			for v in [Vector3(p.x, -0.012, p.y), Vector3(q.x, -0.012, q.y), Vector3(p.x, 0.012, p.y), Vector3(q.x, -0.012, q.y), Vector3(q.x, 0.012, q.y), Vector3(p.x, 0.012, p.y)]: surface.set_uv(Vector2(absf(v.x), v.z + 0.4)); surface.add_vertex(v)
		surface.generate_normals(); surface.generate_tangents(); wings[key] = F.faceted(surface.commit())
	return B.mesh(parent, wings[key], material)
