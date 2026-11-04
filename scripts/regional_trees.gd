extends RefCounted

const A = preload("res://scripts/imported_assets.gd")
const B = preload("res://scripts/build.gd")
const Ground = preload("res://scripts/regional_ground.gd")
const SOURCES = {9: "qnat_commontree_1", 10: "qnat_commontree_5", 11: "qnat_pine_3", 12: "sunspire_cactus", 13: "qnat_deadtree_2", 14: "qnat_twistedtree_4", 15: "prism_spires"}
const CRYSTAL_COLORS = ["#83b7b0", "#b6a2c9", "#a2cbd2"]
static var meshes = {}
static func asset_id(region: int) -> String: return SOURCES.get(region, "")
static func nominal_height(region: int) -> float: return 4.0 if region == 12 else 9.5 if region == 15 else 10.5
static func mesh(region: int) -> ArrayMesh:
	if not meshes.has(region):
		var path = "res://assets/regional_trees/%s.res" % asset_id(region)
		if ResourceLoader.exists(path): meshes[region] = load(path)
		elif region in [12, 15]: meshes[region] = _composite(region)
		else: meshes[region] = A.mesh(asset_id(region))
		if region == 10 and meshes[region].get_meta("biome_art_revision", 0) < 32:
			meshes[region] = Ground.paint_mesh(meshes[region], "smorewood_tree", ["#e5d9ef", "#eb95c3"], 0)


		if region == 15:
			for i in range(3): meshes[region].surface_set_material(i, B.mat(CRYSTAL_COLORS[i], 0.12, 0.08))
	return meshes[region]
static var canopy_anchors = {}
static func food_anchors(region: int) -> Array:
	if not canopy_anchors.has(region):
		var prepared = mesh(region).get_meta("forest_food_anchors", [])
		if not prepared.is_empty():
			canopy_anchors[region] = prepared
			return canopy_anchors[region]


		var leaves = mesh(region).surface_get_arrays(1)[Mesh.ARRAY_VERTEX]; var points = []
		for target in [Vector3(-0.19, 0.57, 0.13), Vector3(0.18, 0.63, -0.1), Vector3(0.04, 0.71, 0.21)]:
			var closest = Vector3.ZERO; var distance = INF
			for vertex in leaves:
				if vertex.y < 0.49 or vertex.y > 0.83: continue
				var gap = vertex.distance_squared_to(target)
				if gap < distance: distance = gap; closest = vertex
			points.append(closest)
		canopy_anchors[region] = points
	return canopy_anchors[region]
static func place(parent: Node3D, region: int, height: float, yaw: float = 0) -> Node3D:
	var model = Node3D.new(); parent.add_child(model); model.name = "RegionalTree"; model.rotation.y = yaw; model.scale = Vector3.ONE * height
	model.set_meta("regional_tree_asset", asset_id(region)); model.set_meta("imported_asset", asset_id(region)); model.set_meta("whole_tree", true)
	var art = MultiMeshInstance3D.new(); art.name = "WholeRegionalTree"; art.multimesh = MultiMesh.new(); art.multimesh.transform_format = MultiMesh.TRANSFORM_3D; art.multimesh.mesh = mesh(region); art.multimesh.instance_count = 1; art.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	art.set_meta("instance_transforms", [Transform3D.IDENTITY]); model.add_child(art)
	return model
static func _composite(region: int) -> ArrayMesh:
	var root = Node3D.new()
	if region == 12:
		for row in [["u29_nature_cactus_tall", Vector3.ZERO, 4.0], ["u29_nature_cactus_short", Vector3(0.6, 0, 0.15), 2.1]]:
			var part = MeshInstance3D.new(); part.mesh = ResourceLoader.load(A.entry(row[0]).path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE); part.position = row[1]; part.scale = Vector3.ONE * row[2]
			var paint = StandardMaterial3D.new(); paint.albedo_color = Color("#748b61"); paint.roughness = 0.86; part.material_override = paint; root.add_child(part)
	else:
		for j in range(6):
			var angle = j * 2.2; var part = MeshInstance3D.new(); part.mesh = ResourceLoader.load(A.entry("zappy_crystal").path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE)
			part.position = Vector3(cos(angle), j * 0.55, sin(angle)); part.scale = Vector3(0.64, 8 - j * 0.6, 0.69); part.rotation.z = sin(angle) * 0.35
			part.material_override = B.mat(CRYSTAL_COLORS[j % 3], 0.12, 0.08); root.add_child(part)
	var geometry = []; var groups = {}; var bounds = AABB()
	for part in root.get_children():
		for surface in range(part.mesh.get_surface_count()):
			var arrays = part.mesh.surface_get_arrays(surface); var indices = arrays[Mesh.ARRAY_INDEX]; var material = part.material_override if part.material_override else part.mesh.surface_get_material(surface)
			var order = indices if indices != null and not indices.is_empty() else range(arrays[Mesh.ARRAY_VERTEX].size())
			var id = material.get_instance_id()
			if not groups.has(id): groups[id] = {"material": material, "vertices": []}
			for index in order:
				var vertex = [part.transform * arrays[Mesh.ARRAY_VERTEX][index], (part.transform.basis.inverse().transposed() * arrays[Mesh.ARRAY_NORMAL][index]).normalized()]
				geometry.append(vertex); groups[id].vertices.append(vertex)
	bounds = AABB(geometry[0][0], Vector3.ZERO)
	for vertex in geometry: bounds = bounds.expand(vertex[0])
	var result = ArrayMesh.new()
	for group in groups.values():
		var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in group.vertices:
			surface.set_normal(vertex[1]); surface.add_vertex((vertex[0] - Vector3(0, bounds.position.y, 0)) / bounds.size.y)
		surface.index(); surface.commit(result); result.surface_set_material(result.get_surface_count() - 1, group.material)
	result.set_meta("replacement_version", 29); result.set_meta("source_assets", ["u29_nature_cactus_tall", "u29_nature_cactus_short"] if region == 12 else ["zappy_crystal"])
	root.free()
	return result
static func distant_mesh(region: int) -> Mesh:
	var result = QuadMesh.new(); result.size = Vector2.ONE * 1.4; result.center_offset = Vector3(0, 0.5, 0)
	var material = ShaderMaterial.new(); material.shader = preload("res://shaders/regional_forest.gdshader")
	material.set_shader_parameter("albedo_atlas", load("res://assets/regional_trees/%d-albedo.png" % region))
	material.set_shader_parameter("normal_atlas", load("res://assets/regional_trees/%d-normal.png" % region))
	material.set_shader_parameter("unlit", region == 15)
	material.set_shader_parameter("glow", 0.0176 if region == 15 else 0.0)
	result.material = material; result.set_meta("regional_tree_asset", asset_id(region)); return result
