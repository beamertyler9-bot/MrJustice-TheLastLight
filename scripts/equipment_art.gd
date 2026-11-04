extends RefCounted

const A = preload("res://scripts/imported_assets.gd")
static var _parts: Dictionary = {}
const ICON_EQUIPMENT = preload("res://assets/equipment/icon-equipment.res")
const SWORDS = {"iron_blade": {"source": "rpg_sword_01", "height": 1.22, "grip": 0.14}, "dawn_blade": {"source": "weapons_leaf_blade", "height": 1.28, "grip": 0.13}}
static func build_sword(parent: Node3D, id: String) -> void:
	_build_icon_equipment(parent, id)

static func _build_icon_equipment(parent: Node3D, id: String) -> void:



	var parts: Array = ICON_EQUIPMENT.get_meta("equipment")[id]
	for part in parts:
		var model = MeshInstance3D.new(); model.name = part.name; model.mesh = part.mesh; model.transform = part.frame; parent.add_child(model)
	parent.set_meta("replacement_art", 29)
	parent.set_meta("art_revision", 31 if id in SWORDS else 30)
	parent.set_meta("icon_revision", 3612)
	parent.set_meta("source_model", "inventory_icon:" + id)

const TOOLS = {
	"makeshift_axe": {"source": "weapons_hatchet", "height": 0.82, "grip": 0.18, "head": 0.64},
	"stone_axe": {"source": "weapons_bearded_axe", "height": 0.94, "grip": 0.18, "head": 0.64},
	"stone_pickaxe": {"source": "kaykit_pickaxe", "height": 0.84, "grip": 0.12, "head": 0.75},
	"stone_hammer": {"source": "weapons_war_hammer", "height": 0.94, "grip": 0.18, "head": 0.8}}



static func build_tool(parent: Node3D, id: String) -> void:
	_build_icon_equipment(parent, id)


	if id == "stone_pickaxe": parent.rotation.y = deg_to_rad(12)

static func _section_center(source: Mesh, height: float) -> Vector3:
	var section = []
	for surface in range(source.get_surface_count()):
		var arrays = source.surface_get_arrays(surface); var points = arrays[Mesh.ARRAY_VERTEX]; var order = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, order.size(), 3):
			for e in range(3):
				var a: Vector3 = points[order[i + e]]; var b: Vector3 = points[order[i + (e + 1) % 3]]
				if (a.y - height) * (b.y - height) < 0: section.append(a.lerp(b, (height - a.y) / (b.y - a.y)))
	if section.is_empty(): return Vector3(0, height, 0)
	var bounds = AABB(section[0], Vector3.ZERO)
	for point in section: bounds = bounds.expand(point)
	return bounds.get_center()

static func _clip(vertices: Array, height: float, above: bool) -> Array:
	var out = []
	for i in range(vertices.size()):
		var a = vertices[i]; var b = vertices[(i + 1) % vertices.size()]
		var inside_a = a.p.y >= height if above else a.p.y <= height
		var inside_b = b.p.y >= height if above else b.p.y <= height
		if inside_a: out.append(a)
		if inside_a != inside_b:
			var t = (height - a.p.y) / (b.p.y - a.p.y)
			out.append({"p": a.p.lerp(b.p, t), "n": a.n.lerp(b.n, t).normalized(), "uv": a.uv.lerp(b.uv, t)})
	return out

static func _outside_grip(source: Mesh, frame: Transform3D, height: float, above: bool, ceiling: float = INF) -> ArrayMesh:
	var result = ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays = source.surface_get_arrays(surface); var points = arrays[Mesh.ARRAY_VERTEX]; var order = arrays[Mesh.ARRAY_INDEX]
		var tool = SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); var count = 0
		for i in range(0, order.size(), 3):
			var triangle = []
			for j in range(3):
				var k = order[i + j]; triangle.append({"p": frame * points[k], "n": frame.basis.orthonormalized() * arrays[Mesh.ARRAY_NORMAL][k], "uv": arrays[Mesh.ARRAY_TEX_UV][k] if arrays[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO})
			var polygon = _clip(triangle, height, above)
			if is_finite(ceiling) and not polygon.is_empty(): polygon = _clip(polygon, ceiling, false)
			for j in range(1, polygon.size() - 1):
				for vertex in [polygon[0], polygon[j], polygon[j + 1]]:
					tool.set_normal(vertex.n); tool.set_uv(vertex.uv); tool.add_vertex(vertex.p); count += 1
		if count > 0:
			tool.commit(result); result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface))
	return result

static func head(id: String) -> Mesh:
	if id == "makeshift_axe": return _fitted_head("u29_survival_tool_axe", Vector3(0.13, 0.34, 0.43), Vector3(0, 0.015, -0.12), Basis(Vector3.UP, PI * 0.5), 0.63)
	if id not in ["stone_axe", "stone_pickaxe"]: return null
	if _parts.has(id): return _parts[id]
	var pick = id == "stone_pickaxe"
	var source = A.mesh("kaykit_pickaxe" if pick else "kaykit_axe")
	var data = source.surface_get_arrays(0)
	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var threshold = 0.76 if pick else 0.68
	var center_y = 0.85 if pick else 0.918
	var center_x = 0.0 if pick else 0.1088
	var scale_value = 0.88 if pick else 1.14
	var output = SurfaceTool.new(); output.begin(Mesh.PRIMITIVE_TRIANGLES)
	output.set_material(source.surface_get_material(0))
	for i in range(0, indices.size(), 3):
		var keep = true
		for j in range(3): keep = keep and points[indices[i + j]].y >= threshold
		if not keep: continue
		for j in range(3):
			var index = indices[i + j]; var point = points[index] - Vector3(center_x, center_y, 0)


			var basis = Basis(Vector3.UP, -PI * 0.5)
			point = basis * point * scale_value
			if pick:


				point.y -= 0.015
			else: point.y *= 1.7


			var edge = smoothstep(0.12, 0.48 if pick else 0.46, absf(point.z))
			point.x *= lerpf(1.0, 0.13, edge)
			output.set_normal(basis * data[Mesh.ARRAY_NORMAL][index]); output.set_uv(data[Mesh.ARRAY_TEX_UV][index])
			output.add_vertex(point)
	output.generate_normals()
	_parts[id] = output.commit()
	return _parts[id]

static func hammer() -> Mesh:
	return _fitted_head("rpg_hammer_01", Vector3(0.51, 0.27, 0.27), Vector3.ZERO, Basis.IDENTITY, 0.58)

static func _fitted_head(id: String, size: Vector3, at: Vector3, rotation: Basis, cut: float) -> Mesh:
	var key = "fitted:" + id
	if _parts.has(key): return _parts[key]
	var source = A.mesh(id); var triangles = []; var box = AABB(); var found = false
	for surface in range(source.get_surface_count()):
		var data = source.surface_get_arrays(surface); var indices = data[Mesh.ARRAY_INDEX]
		var order = indices if indices != null and not indices.is_empty() else range(data[Mesh.ARRAY_VERTEX].size())
		for i in range(0, order.size(), 3):
			var keep = true
			for j in range(3): keep = keep and data[Mesh.ARRAY_VERTEX][order[i + j]].y >= cut
			if not keep: continue
			for j in range(3):
				var index = order[i + j]; var p = rotation * data[Mesh.ARRAY_VERTEX][index]
				triangles.append([p, rotation * data[Mesh.ARRAY_NORMAL][index]])
				if not found: box = AABB(p, Vector3.ZERO); found = true
				else: box = box.expand(p)
	assert(found, "No working head in supplied tool " + id)
	var scale = size / box.size; var tool = SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in triangles:
		var point = (vertex[0] - box.get_center()) * scale + at
		if id == "u29_survival_tool_axe": point.x = clampf(point.x * lerpf(1.9, 0.45, smoothstep(0.06, 0.29, -point.z)), -0.065, 0.065)
		tool.set_normal((vertex[1] / scale).normalized()); tool.add_vertex(point)
	if id == "u29_survival_tool_axe": tool.generate_normals()
	_parts[key] = tool.commit(); return _parts[key]

static func blade() -> Mesh:
	if _parts.has("blade"): return _parts.blade
	var source = A.mesh("weapons_arming_sword")
	var output = SurfaceTool.new(); output.begin(Mesh.PRIMITIVE_TRIANGLES)
	output.set_material(source.surface_get_material(0))
	for surface in range(source.get_surface_count()):
		var data = source.surface_get_arrays(surface)
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		for i in range(0, indices.size(), 3):
			var keep = true
			for j in range(3): keep = keep and points[indices[i + j]].y > 0.3
			if not keep: continue
			for j in range(3):
				var index = indices[i + j]; var point = points[index]
				point.y = 0.17 + (point.y - 0.3) * 1.28
				output.set_normal(data[Mesh.ARRAY_NORMAL][index]); output.set_uv(data[Mesh.ARRAY_TEX_UV][index]); output.add_vertex(point)
	_parts.blade = output.commit()
	return _parts.blade
