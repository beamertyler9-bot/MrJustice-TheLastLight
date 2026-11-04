extends RefCounted

const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/landmark_art.gd")
const O = preload("res://scripts/world_overhaul.gd")
const TOWERS = [[-38, -28, 0, 50, 7, 24], [38, -28, 0, 55, 7, 25], [-38, 28, 0, 46, 7, 22], [38, 28, 0, 49, 7, 23], [-16, -19, 24, 57, 6, 28], [16, -19, 24, 64, 6, 31], [-20, 8, 24, 38, 5, 25], [20, 8, 24, 43, 5, 27], [0, -6, 24, 72, 8, 36]]
static var arch_meshes = {}
static func build(parent: Node3D, detailed: bool = true, world = null):
	var stone = B.world_surface("stone", "#48424d"); var trim = B.world_surface("stone", "#6b6067")


	if detailed: B.box(parent, Vector3(0, -0.24, 0), Vector3(88, 0.72, 78), stone, true)
	for side in [-1, 1]:
		for z in [-24.8, -12.4, 0.0, 12.4, 24.8]:
			var wall = A.module(parent, "u29_castle_wall", Vector3(side * 33, 0, z), Vector3(12.4, 24, 3), PI * 0.5); A.tint(wall, Color("#635a65"))
		if detailed: O.support_box(parent, Vector3(side * 33, 12, 0), Vector3(3, 24, 62))
		for x in [16.0, 28.0]:
			var wall = A.module(parent, "u29_castle_wall", Vector3(side * x, 0, 30), Vector3(12, 24, 3)); A.tint(wall, Color("#635a65"))
		if detailed: O.support_box(parent, Vector3(side * 22, 12, 30), Vector3(24, 24, 3))
	for x in [-24.75, -8.25, 8.25, 24.75]:
		var wall = A.module(parent, "u29_castle_wall", Vector3(x, 0, -30), Vector3(16.5, 24, 3)); A.tint(wall, Color("#635a65"))
	if detailed: O.support_box(parent, Vector3(0, 12, -30), Vector3(66, 24, 3))

	B.box(parent, Vector3(0, 23, 30), Vector3(20, 10, 3), stone, detailed)
	A.castle_door(parent, detailed)
	var gate_arch = Node3D.new(); gate_arch.position = Vector3(0, 0, 31.62); parent.add_child(gate_arch)
	_arch(gate_arch, 10.1, 15.3, 0.5, trim)
	var tympanum: Array[PackedVector3Array] = [PackedVector3Array([Vector3(-4, 10, 0.01), Vector3(4, 10, 0.01), Vector3(0, 14.1, 0.01)])]
	B.mesh(gate_arch, B._flat_geometry(tympanum), B.world_surface("stone", "#27232c"))
	var roof = A.module(parent, "qv_roof_roundtiles_8x8", Vector3(0, 24, 0), Vector3(69, 8, 64)); A.tint(roof, Color("#3e3b50"))
	if detailed: O.support_box(parent, Vector3(0, 24.1, 0), Vector3(69, 0.2, 64))
	for row in TOWERS: _tower(parent, row, detailed)
	for side in [-1, 1]:
		for z in [-20, -4, 12]:
			var buttress = A.module(parent, "dungeon_pillar_decorated", Vector3(side * 30, 0, z), Vector3(3.4, 27, 4.4)); A.tint(buttress, Color("#74666c"))
			if detailed: O.support_box(parent, Vector3(side * 30, 12, z), Vector3(2.5, 24, 3.8))
		for z in [-15, 5]:
			B.branch(parent, Vector3(side * 10, 55, z), Vector3(side * 24, 32, z), 0.8, trim, 0.8)
			B.branch(parent, Vector3(side * 10, 55, z), Vector3(side * 24, 55, z), 0.38, trim)
	for side in [-1, 1]:
		for i in range(3):
			var rock = A.module(parent, "u29_nature_rock_largea" if i % 2 == 0 else "u29_nature_rock_talla", Vector3(side * (51 + i % 2 * 3), -40, -32 + i * 27), Vector3(21, 43, 29), side * 0.3 + i * 0.7)
			A.tint(rock, Color("#615a62"))
			if detailed: _support(parent, rock, false)
	if detailed: _approach(parent, world)
	parent.set_meta("replacement_art", 29); parent.set_meta("castle_revision", 31); parent.set_meta("entry_via_ring_only", true)
static func _tower(parent: Node3D, row: Array, detailed: bool):
	var x = float(row[0]); var z = float(row[1]); var base = float(row[2]); var height = float(row[3]); var radius = float(row[4]); var roof_height = float(row[5])
	var root = Node3D.new(); root.name = "GothicSpire_%d_%d" % [x, z]; root.position = Vector3(x, base, z); parent.add_child(root)
	var parts = ceili(height / 12) if detailed else 1; var step = height / parts
	for i in range(parts):
		var body = A.module(root, "u29_castle_tower_hexagon_mid", Vector3(0, i * step, 0), Vector3(radius * 2, step, radius * 1.73205)); A.tint(body, Color("#5d5360"))
		if detailed: _support(root, body, true)
	var crown = A.module(root, "u29_castle_tower_hexagon_top", Vector3(0, height - 1.1, 0), Vector3(radius * 2.15, 1.6, radius * 1.86)); A.tint(crown, Color("#7a6770"))
	var roof = A.module(root, "u29_castle_tower_hexagon_roof", Vector3(0, height, 0), Vector3(radius * 2.4, roof_height, radius * 2.0784)); A.tint(roof, Color("#343447"))
	if detailed: _support(root, roof, false)
	B.cyl(root, Vector3(0, height + roof_height + 1.0, 0), 0.12, 2.0, B.mat("#292b36", 0.55))
	var floors = maxi(2, floori(height / 13)) if detailed else 2
	for level in range(floors):
		for side in range(6):
			var angle = side * TAU / 6; var window = Node3D.new(); window.name = "GothicWindow_%d_%d" % [level, side]
			window.position = Vector3(sin(angle) * (radius * 0.866 + 0.18), 9 + level * (height - 18) / maxi(1, floors - 1), cos(angle) * (radius * 0.866 + 0.18)); window.rotation.y = angle; root.add_child(window)
			_window(window, 1.4 if radius > 6 else 1.1, 4.2 if radius > 6 else 3.6)
static func _window(parent: Node3D, width: float, height: float):
	_arch(parent, width, height, 0.2, B.world_surface("stone", "#817079"))
	var w = width * 0.5 - 0.19; var top = height - 0.24
	var pane: Array[PackedVector3Array] = [PackedVector3Array([Vector3(-w, 0.18, 0.145), Vector3(w, 0.18, 0.145), Vector3(w, height * 0.69, 0.145), Vector3(0, top, 0.145), Vector3(-w, height * 0.69, 0.145)])]
	B.mesh(parent, B._flat_geometry(pane), B.mat("#d7774c", 0, 0.28)).name = "RecessedWarmPane"
	B.box(parent, Vector3(0, height * 0.4, 0.25), Vector3(0.085, height * 0.79, 0.12), B.mat("#3c313b"))
static func _arch(parent: Node3D, width: float, height: float, depth: float, material: Material):
	var key = Vector3(width, height, depth)
	if not arch_meshes.has(key):
		var outer = [Vector2(-width * 0.5, 0), Vector2(-width * 0.5, height * 0.7), Vector2(0, height), Vector2(width * 0.5, height * 0.7), Vector2(width * 0.5, 0)]
		var inner = [Vector2(-width * 0.5 + 0.22, 0.05), Vector2(-width * 0.5 + 0.22, height * 0.69), Vector2(0, height - 0.3), Vector2(width * 0.5 - 0.22, height * 0.69), Vector2(width * 0.5 - 0.22, 0.05)]
		var faces: Array[PackedVector3Array] = []
		for i in range(outer.size() - 1):
			var a = Vector3(outer[i].x, outer[i].y, depth); var b = Vector3(outer[i + 1].x, outer[i + 1].y, depth); var c = Vector3(inner[i + 1].x, inner[i + 1].y, depth); var d = Vector3(inner[i].x, inner[i].y, depth)
			faces.append(PackedVector3Array([a, b, c, d])); faces.append(PackedVector3Array([c, b, b + Vector3.FORWARD * depth, c + Vector3.FORWARD * depth])); faces.append(PackedVector3Array([d, c, c + Vector3.FORWARD * depth, d + Vector3.FORWARD * depth]))
		arch_meshes[key] = B._flat_geometry(faces)
	B.mesh(parent, arch_meshes[key], material)
static func _support(parent: Node3D, node: Node3D, convex: bool):
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var points = mesh.mesh.get_faces(); var frame = node.transform * mesh.transform
		for i in range(points.size()): points[i] = frame * points[i]
		var shape: Shape3D
		if convex:
			shape = ConvexPolygonShape3D.new(); shape.points = points
		else:
			shape = ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points)
		B.solid(parent, Vector3.ZERO, shape)
static func _approach(parent: Node3D, world):
	if world == null: return
	var base = parent.position
	var stone = B.world_surface("stone", "#6f6268"); var dark = B.world_surface("stone", "#4f454f")
	for i in range(84):
		var z = 35.0 + i * 1.6; var high = -INF
		for dz in [-0.8, 0, 0.8]:
			for dx in [-4.1, 0, 4.1]: high = maxf(high, world.surface_height_at(base.x + dx, base.z + z + dz) - base.y)
		B.box(parent, Vector3(0, high - 0.46, z), Vector3(8.2, 1.1, 1.6), stone, true)
		if i % 5 == 0:
			for side in [-1, 1]: B.box(parent, Vector3(side * 4.7, high + 0.5, z), Vector3(0.8, 2.1, 0.85), dark, true)
	for side in [-1, 1]:
		for i in range(16):
			var z = 35.0 + i * 8; var a = Vector3(side * 4.7, world.surface_height_at(base.x + side * 4.7, base.z + z) - base.y + 1, z)
			var b = Vector3(side * 4.7, world.surface_height_at(base.x + side * 4.7, base.z + z + 8) - base.y + 1, z + 8)
			B.branch(parent, a, b, 0.19, dark)
static func occupied(point: Vector3) -> bool:
	if absf(point.x) < 31.5 and point.z > -28.5 and point.z < 31 and point.y >= -0.1 and point.y < 24: return true
	for row in TOWERS:
		if Vector2(point.x - row[0], point.z - row[1]).length() < float(row[4]) + 0.2 and point.y >= float(row[2]) - 0.1 and point.y < float(row[2] + row[3] + row[5]) + 2: return true
	return false
