extends RefCounted

const A = preload("res://scripts/imported_assets.gd")
const B = preload("res://scripts/build.gd")
const O = preload("res://scripts/world_overhaul.gd")
const Details = preload("res://scripts/household_details.gd")
static var packed = {}
static var paints = {}
static var tinted_meshes = {}
static var rail_mesh: Mesh
static func module(parent: Node3D, id: String, at: Vector3, size: Vector3, yaw: float = 0) -> Node3D:
	var node = O.fit(parent, id, at, size, yaw); O.structural(node); return node
static func local_bounds(parent: Node3D, frame: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result = AABB(); var found = false
	for child in parent.get_children():
		if not child is Node3D: continue
		var box = frame * child.transform * child.mesh.get_aabb() if child is MeshInstance3D else local_bounds(child, frame * child.transform)
		if box.size.length_squared() == 0: continue
		result = result.merge(box) if found else box; found = true
	return result
static func prop(parent: Node3D, id: String, at: Vector3, size: Vector3) -> Node3D:
	if not packed.has(id): packed[id] = load("res://assets/replacements/" + id + ".scn")
	var model = packed[id].instantiate(); var box = local_bounds(model); model.scale = size / box.size
	model.position = at - Vector3(box.get_center().x, box.position.y, box.get_center().z) * model.scale
	parent.add_child(model); O.structural(model); return model
static func beam(parent: Node3D, start: Vector3, end: Vector3, width: float, id: String = "resource_wood_log_a") -> Node3D:
	var delta = end - start; var node = A.place(parent, id, start, delta.length())
	var bounds = A.entry(id).bounds_size
	node.quaternion = Quaternion(Vector3.UP, delta.normalized()); node.scale = Vector3(width / float(bounds[0]), delta.length(), width / float(bounds[2])); O.structural(node); return node
static func rails(parent: Node3D, at: Vector3):
	if rail_mesh == null:
		var profile = PackedVector2Array([Vector2(-0.06, 0), Vector2(0.06, 0), Vector2(0.06, 0.015), Vector2(0.018, 0.015), Vector2(0.018, 0.055), Vector2(0.05, 0.055), Vector2(0.05, 0.07), Vector2(-0.05, 0.07), Vector2(-0.05, 0.055), Vector2(-0.018, 0.055), Vector2(-0.018, 0.015), Vector2(-0.06, 0.015)])
		var faces: Array[PackedVector3Array] = []
		for offset in [-0.6, 0.6]:
			for i in range(profile.size()):
				var j = (i + 1) % profile.size(); var a = profile[i]; var b = profile[j]
				faces.append(PackedVector3Array([Vector3(offset + a.x, a.y, -4), Vector3(offset + b.x, b.y, -4), Vector3(offset + b.x, b.y, 4), Vector3(offset + a.x, a.y, 4)]))
			rail_mesh = B._flat_geometry(faces)
	var mesh = B.mesh(parent, rail_mesh, B.mat("#58615c", 0.5), at); mesh.set_meta("replacement_art", 29)
static func tint(node: Node3D, color: Color):


	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var originals = []; var variant_key = str(mesh.mesh.get_instance_id()) + ":" + color.to_html()
		for surface in range(mesh.mesh.get_surface_count()):
			var original = mesh.get_active_material(surface); originals.append(original); variant_key += ":" + str(original.get_instance_id())
		if not tinted_meshes.has(variant_key):
			var variant = mesh.mesh.duplicate()
			for surface in range(originals.size()):
				var original = originals[surface]; var key = str(original.get_instance_id()) + ":" + color.to_html()
				if not paints.has(key):
					var paint = original.duplicate()
					if paint is ShaderMaterial: paint.set_shader_parameter("tint", original.get_shader_parameter("tint") * color)
					elif paint is StandardMaterial3D: paint.albedo_color = original.albedo_color * color
					paints[key] = paint
				variant.surface_set_material(surface, paints[key])
			tinted_meshes[variant_key] = variant
		mesh.mesh = tinted_meshes[variant_key]
		for surface in range(mesh.mesh.get_surface_count()): mesh.set_surface_override_material(surface, null)
		mesh.material_override = null
static func tower_shell(parent: Node3D):
	var stone = B.world_surface("stone", "#84969a"); var amber = B.mat("#d9ae63", 0.45)
	B.cyl(parent, Vector3(0, -0.035, 0), 3.48, 0.07, B.world_surface("stone", "#536873"))
	B.ring(parent, Vector3(0, 0.012, 0), 3.2, 0.045, amber)
	for index in range(12):
		if index in [2, 3, 4]: continue
		var angle = float(index) * TAU / 12; var wall = Node3D.new(); wall.position = Vector3(cos(angle) * 3.28, 0, sin(angle) * 3.28); wall.rotation.y = PI * 0.5 - angle; parent.add_child(wall)
		module(wall, "u29_castle_wall_half", Vector3.ZERO, Vector3(1.83, 5.3, 0.38))
		O.support_box(wall, Vector3(0, 2.65, 0), Vector3(1.83, 5.3, 0.38))
		if index % 2 == 0: module(wall, "qv_window_thin_round1", Vector3(0, 3.0, 0.24), Vector3(0.52, 1.25, 0.12))
	for side in [-1, 1]:
		module(parent, "dungeon_pillar_decorated", Vector3(side * 1.75, 0, 2.93), Vector3(0.61, 3.1, 0.74))
		O.support_box(parent, Vector3(side * 1.75, 1.55, 2.93), Vector3(0.45, 3.1, 0.6))
	module(parent, "u29_castle_wall_half", Vector3(0, 3.075, 2.93), Vector3(3.9, 1.05, 0.6))
	O.support_box(parent, Vector3(0, 3.6, 2.93), Vector3(3.9, 1.05, 0.6))
	module(parent, "u29_castle_tower_hexagon_mid", Vector3(0, 5.3, 0), Vector3(6.5, 5, 5.63))
	var shape = CylinderShape3D.new(); shape.radius = 3.25; shape.height = 5; B.solid(parent, Vector3(0, 7.8, 0), shape)
	module(parent, "u29_castle_tower_hexagon_top", Vector3(0, 10.3, 0), Vector3(6.9, 0.65, 5.98))
	var roof = module(parent, "qv_roof_tower_roundtiles", Vector3(0, 10.65, 0), Vector3(8.64, 5.2, 8.64))
	tint(roof, Color("#7778ba"))
	for piece in parent.get_children():
		if str(piece.get_meta("imported_asset", "")).begins_with("u29_castle_") and "roof" not in str(piece.get_meta("imported_asset", "")): tint(piece, Color("#84969a"))
	parent.set_meta("replacement_art", 29)
static func castle(parent: Node3D, detailed: bool = true, world = null):
	load("res://scripts/gothic_castle.gd").build(parent, detailed, world)
static func castle_door(parent: Node3D, solid: bool = true):
	var stone = B.world_surface("stone", "#55505e"); var iron = B.mat("#363940", 0.6)
	for side in [-1, 1]:
		B.box(parent, Vector3(side * 7, 9, 30), Vector3(6, 18, 3), stone, solid)
		var leaf = O.fit(parent, "village_mdvl_village_door_plank_01", Vector3(side * 2.0, 0, 30.55), Vector3(4.0, 10, 0.55))
		O.structural(leaf)
		for y in [1.5, 5.0, 8.5]:
			B.box(parent, Vector3(side * 2, y, 30.91), Vector3(3.7, 0.2, 0.12), iron)
			for x in [side * 0.45, side * 3.5]: B.ball(parent, Vector3(x, y, 31.0), Vector3(0.13, 0.13, 0.09), iron)
		B.ring(parent, Vector3(side * 0.62, 4.5, 31.03), 0.24, 0.055, iron).rotation.x = PI * 0.5
	B.box(parent, Vector3(0, 14, 30), Vector3(8, 8, 3), stone, solid)
	if solid: O.support_box(parent, Vector3(0, 5, 30.5), Vector3(8, 10, 0.7))
	if solid:
		for side in [-1, 1]:
			var lamp = O.fit(parent, "kaykit_lantern", Vector3(side * 4.7, 3.4, 31.8), Vector3(0.65, 0.9, 0.65)); O.structural(lamp)
			B.box(parent, Vector3(side * 4.7, 4.4, 31.4), Vector3(0.12, 0.12, 1.1), iron)
		var fill = OmniLight3D.new(); fill.name = "CastleGateLanterns"; fill.position = Vector3(0, 4.4, 34); fill.light_color = Color("#f4c082"); fill.light_energy = 2.0; fill.omni_range = 17; fill.shadow_enabled = false; parent.add_child(fill)
	parent.set_meta("entry_via_ring_only", true)
static func deck_at(model: Node3D, point: Vector2) -> float:
	var top = -INF
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var frame = model.transform * mesh.transform; var faces = mesh.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(point.x, 100, point.y), Vector3.DOWN, frame * faces[i], frame * faces[i + 1], frame * faces[i + 2])
			if hit != null: top = maxf(top, hit.y)
	return top
static func bridge(parent: Node3D, center: Vector3, length: float, width: float, deck: float = 0.12, rail_collision: bool = true):


	var model = Details.place(parent, "terrain_mdvl_nature_bridge_plank_01", center, Vector3(length, 0.4, width)); O.structural(model)
	var surface = deck_at(model, Vector2(center.x + 0.01, center.z)); assert(is_finite(surface), "Source bridge has no walkable middle")
	model.position.y += center.y + deck - surface
	O.support_box(parent, center + Vector3(0, deck - 0.12, 0), Vector3(length, 0.24, width))
	for side in [-1, 1]:
		var z = side * (width * 0.5 + 0.05 if rail_collision else width * 0.5 + 0.1)
		var posts = [-8.0, -4.0, 0.0, 4.0, 8.0] if rail_collision else [-length * 0.5 + 0.12, 0.0, length * 0.5 - 0.12]
		for x in posts:
			beam(parent, center + Vector3(x, 0, z), center + Vector3(x, 1.4, z), 0.22)
			if rail_collision: O.support_box(parent, center + Vector3(x, 0.7, z), Vector3(0.22, 1.4, 0.22))
		beam(parent, center + Vector3(-length * 0.5, 1.2 if rail_collision else 0.8, z), center + Vector3(length * 0.5, 1.2 if rail_collision else 0.8, z), 0.16)
		if rail_collision: O.support_box(parent, center + Vector3(0, 1.2, z), Vector3(length, 0.16, 0.16))
	parent.set_meta("replacement_bridge", 29)
static func island_rocks(parent: Node3D, at: Vector3):
	var body = module(parent, "u29_nature_rock_largea", at - Vector3.UP * 0.7, Vector3(9.8, 16, 9.8)); body.rotation.z = PI
	for i in range(3):
		var angle = i * TAU / 3; var point = at + Vector3(cos(angle) * 4.1, -0.9, sin(angle) * 4.1)
		var rock = module(parent, "u29_nature_rock_talla", point, Vector3(3.4, 7.5, 3.4), angle); rock.rotation.z = PI
static func ruin_arch(parent: Node3D, position: Vector3, scale_value: float):
	var n = Node3D.new(); n.position = position; n.scale = Vector3.ONE * scale_value; parent.add_child(n); n.add_to_group("static_art_root")
	for side in [-1, 1]:
		module(n, "ruin_pillarsquarecut", Vector3(side * 3.2, 0, 0), Vector3(1.5, 5.3, 1.7))
		O.support_box(n, Vector3(side * 3.2, 2.5, 0), Vector3(1.5, 5, 1.7))
		module(n, "ruin_pillarsquarecut", Vector3(side * 3.2, 0, 0), Vector3(2, 0.6, 2.1))
		O.support_box(n, Vector3(side * 3.2, 0.3, 0), Vector3(2, 0.6, 2.1))
		module(n, "ruin_pillarsquarecut", Vector3(side * 3.2, 4.875, 0), Vector3(1.9, 0.45, 2))
		O.support_box(n, Vector3(side * 3.2, 5.1, 0), Vector3(1.9, 0.45, 2))
	module(n, "u29_castle_wall_half", Vector3(0, 4.85, 0), Vector3(5.4, 0.8, 1.6)); O.support_box(n, Vector3(0, 5.25, 0), Vector3(5.4, 0.8, 1.6))
	module(n, "u29_castle_wall_half", Vector3(0, 5.6, 0), Vector3(1.2, 0.5, 1.7)); O.support_box(n, Vector3(0, 5.85, 0), Vector3(1.2, 0.5, 1.7))
	for i in range(5):
		module(n, "terrain_mdvl_nature_rocks_01", Vector3(-2 + i * 1.1, 0, 0), Vector3(0.9, 0.24, 2.4))
		O.support_box(n, Vector3(-2 + i * 1.1, 0.12, 0), Vector3(0.9, 0.24, 2.4))
	B.batch_static(n)
