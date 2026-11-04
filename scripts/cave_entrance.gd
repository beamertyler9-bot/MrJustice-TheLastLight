extends RefCounted


const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/imported_assets.gd")
const O = preload("res://scripts/world_overhaul.gd")
static var cliff_material: ShaderMaterial
static func build(parent: Node3D, tint: Color, variant: int = 0, world = null) -> Node3D:
	var root = Node3D.new(); root.name = "NaturalCaveMouth"; parent.add_child(root)
	root.set_meta("natural_cave_revision", 30); root.set_meta("clear_throat_width", 3.2)
	var cliff = {}
	if world != null and world.atlas != null:
		var at = _frame(parent).origin
		cliff = preload("res://scripts/fixed_world.gd").cliff_at(Vector2(at.x, at.z))
		if cliff.is_empty(): root.free(); return null
		root.set_meta("cliff_revision", 31); root.set_meta("cliff_id", cliff.id)
		if cliff_material == null:
			cliff_material = ShaderMaterial.new(); cliff_material.shader = preload("res://shaders/cliff_stone.gdshader"); cliff_material.set_shader_parameter("rock_detail", preload("res://assets/surfaces/stone.png"))
		tint = Color("#606b67").lerp(tint, 0.12)
	var fronts = []; var outer = []; var backs = []; var throat = []; var segments = 13
	for i in range(segments + 1):
		var angle = float(i) / segments * PI; var wave = sin(i * 2.13 + variant * 0.7)
		var x = cos(angle) * (2.15 + 0.16 * sin(i * 1.7 + variant)); var y = sin(angle) * (3.8 + 0.18 * wave) - 0.28
		fronts.append(Vector3(x, y, 0.1 + 0.18 * wave))
		throat.append(Vector3(x * 0.88, y * 0.91, -4.1 + 0.15 * wave))
		var p = Vector3(cos(angle) * (6.1 + 0.4 * wave), sin(angle) * (6.3 + 0.28 * sin(i + variant)) - 0.7, -1.8 + 0.35 * wave)
		if i in [0, segments] and world != null: p.y = _ground(parent, p, world) - 0.45
		outer.append(p)
		var back = Vector3(cos(angle) * (4.6 + 0.3 * wave), sin(angle) * (4.6 + 0.25 * wave) - 0.65, -7.4)
		if i in [0, segments] and world != null: back.y = _ground(parent, back, world) - 0.45
		backs.append(back)
	var outside: Array[PackedVector3Array] = []; var inside: Array[PackedVector3Array] = []
	for i in range(segments):
		outside.append(PackedVector3Array([fronts[i], outer[i], outer[i + 1], fronts[i + 1]]))
		outside.append(PackedVector3Array([outer[i], backs[i], backs[i + 1], outer[i + 1]]))
		if cliff.is_empty(): outside.append(PackedVector3Array([backs[i], Vector3(0, -0.7, -9), backs[i + 1]]))
		inside.append(PackedVector3Array([fronts[i], fronts[i + 1], throat[i + 1], throat[i]]))
	var shell = B.mesh(root, B._flat_geometry(outside), B.world_surface("stone", "#" + tint.to_html(false))); shell.name = "ContinuousBluff"
	var tunnel = B.mesh(root, _inward(inside), B.world_surface("stone", "#" + tint.darkened(0.23).to_html(false))); tunnel.name = "RecessedThroat"
	var skins = [shell, tunnel]
	if not cliff.is_empty(): shell.material_override = cliff_material; tunnel.material_override = cliff_material
	if not cliff.is_empty():


		for i in range(6):
			var x = (-1 if i % 2 == 0 else 1) * (12 + (i / 2) * 12); var p = Vector3(x, 0, -3.5 - (i % 3) * 0.5)
			var at = _frame(parent) * p
			if world.path_distance(Vector2(at.x, at.z)) < 14.5: continue
			var lowest = INF
			for dx in [-5.1, 0, 5.1]:
				for dz in [-6.0, 0, 6.0]: lowest = minf(lowest, _ground(parent, p + Vector3(dx, 0, dz), world))
			p.y = lowest - 4.0
			var rock = O.fit(root, "u29_nature_rock_largea" if i % 2 else "u29_nature_rock_largeb", p, Vector3(12, 5.5 + (i % 3) * 1.4, 11), i * 0.7); O.structural(rock)
			rock.get_child(0).material_override = B.world_surface("stone", "#" + tint.to_html(false))


	for model in skins:
		var body = StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
		var collision = CollisionShape3D.new(); collision.shape = model.mesh.create_trimesh_shape(); body.add_child(collision); root.add_child(body)
	B.box(root, Vector3(0, 1.4, -4.25), Vector3(3.8, 3.5, 0.25), B.mat("#152321"), true)
	for i in range(9):
		var side = -1 if i % 2 == 0 else 1
		var p = Vector3(side * (3.3 + (i % 3) * 1.0), -0.22, -0.8 - (i % 4) * 1.15)
		if world != null: p.y = _ground(parent, p, world) - 0.24
		var rock = O.fit(root, "u29_nature_rock_largea" if i % 2 == 0 else "u29_nature_rock_largeb", p, Vector3(2.1 + (i % 3) * 0.18, 1.35 + (i % 3) * 0.35, 2.7), i * 0.18)
		O.structural(rock)


		rock.get_child(0).material_override = B.world_surface("stone", "#" + tint.lightened(0.045 if i % 2 else 0.0).to_html(false))
	for i in range(7):
		var p = Vector3((-1 if i % 2 else 1) * (2.7 + (i % 3) * 0.9), 0, 1.4 + (i % 2) * 0.7)
		if world != null: p.y = _ground(parent, p, world) - 0.02
		var stone = A.place(root, "weapons_rock", p, 0.16 + (i % 3) * 0.11, i * 1.4); O.structural(stone)
	if world != null:
		for model in root.get_children():
			if not model is Node3D or not model.has_meta("imported_asset"): continue
			var shift = INF
			for mesh in model.find_children("*", "MeshInstance3D", true, false):
				var box = mesh.mesh.get_aabb()
				for vertex in mesh.mesh.get_faces():
					if vertex.y > box.position.y + box.size.y * 0.12: continue
					var p = model.transform * mesh.transform * vertex
					shift = minf(shift, _ground(parent, p, world) - p.y)
			if is_finite(shift): model.position.y += shift - 0.06
			if not cliff.is_empty() and str(model.get_meta("imported_asset")).begins_with("u29_nature_rock_"):
				for mesh in model.find_children("*", "MeshInstance3D", true, false): mesh.material_override = cliff_material
				for mesh in model.find_children("*", "MeshInstance3D", true, false):
					var points = mesh.mesh.get_faces()
					for j in range(points.size()): points[j] = model.transform * mesh.transform * points[j]
					var shape = ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points); B.solid(root, Vector3.ZERO, shape)
	return root
static func _ground(parent: Node3D, p: Vector3, world) -> float:


	var frame = _frame(parent)
	var at = frame * p
	return world.surface_height_at(at.x, at.z) - frame.origin.y
static func _frame(parent: Node3D) -> Transform3D:
	var frame = parent.transform
	var ancestor = parent.get_parent()
	while ancestor is Node3D:
		frame = ancestor.transform * frame; ancestor = ancestor.get_parent()
	return frame
static func _inward(faces: Array[PackedVector3Array]) -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var center = Vector3.ZERO
		for p in face: center += p
		center /= face.size()
		var n = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		var into = Vector3(-center.x, 1.2 - center.y, 0)
		if n.dot(into) < 0: n = -n
		for i in range(1, face.size() - 1):
			var tri = [face[0], face[i], face[i + 1]]
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(n) > 0: tri = [face[0], face[i + 1], face[i]]
			for p in tri: st.set_normal(n); st.set_uv(Vector2(p.z, p.y) * 0.4); st.add_vertex(p)
	return st.commit()
