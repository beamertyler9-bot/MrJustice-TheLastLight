extends Node3D
const B = preload("res://scripts/build.gd")
const Places = preload("res://scripts/locations.gd")
const Harvestable = preload("res://scripts/harvestable.gd")
const FoodModels = preload("res://scripts/item_models.gd")
const Discoveries = preload("res://scripts/regional_discoveries.gd")
const Dressing = preload("res://scripts/asset_dressing.gd")
const Imported = preload("res://scripts/imported_assets.gd")
var world
var atlas
var distant: MeshInstance3D
var castle_proxy: Node3D
var water_materials: Array = []
var forest_materials: Array = []
var bank_material: ShaderMaterial
var live: Dictionary = {}
var clock := 0.0
var terrain_mask: ImageTexture
var terrain_mask_data: Image
var forest_mask: ImageTexture
var _forest_mask_data: Image
var _coverage_signature: int = -1

func setup(context) -> void:
	name = "AtlasScenery"; world = context; atlas = world.atlas
	load("res://scripts/world_wayfinding.gd").build(self, world)
	_distant_terrain()
	_distant_banks()
	_distant_forests()
	for water in atlas.watercourses(): _water(water)
	for lake in atlas.lakes(): _lake(lake)
	_volcanic_fire()
	preload("res://scripts/fizzpeak_falls.gd").build(self)
	for bridge in atlas.data.get("bridges", []): _bridge(bridge)
	_castle_silhouette()

func setup_loading(context, progress: Callable) -> void:
	name = "AtlasScenery"; world = context; atlas = world.atlas
	progress.call("Finding the old roads")
	await get_tree().process_frame
	load("res://scripts/world_wayfinding.gd").build(self, world)
	progress.call("Painting the far horizon")
	await get_tree().process_frame
	_distant_terrain()
	await get_tree().process_frame
	_distant_banks()
	progress.call("Growing distant forests")
	await get_tree().process_frame
	var groups: Array = FileAccess.open("res://assets/world/fixed/forest.bin", FileAccess.READ).get_var()
	var variants = {}; var deadline = Time.get_ticks_usec() + 4000
	for group in groups:
		_forest_group(group, variants)
		if Time.get_ticks_usec() >= deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + 4000
	progress.call("Following rivers and bridges")
	await get_tree().process_frame
	for water in atlas.watercourses():
		_water(water); await get_tree().process_frame
	for lake in atlas.lakes():
		_lake(lake); await get_tree().process_frame
	for bridge in atlas.data.get("bridges", []):
		_bridge(bridge); await get_tree().process_frame
	_volcanic_fire()
	preload("res://scripts/fizzpeak_falls.gd").build(self)
	progress.call("Raising distant landmarks")
	await get_tree().process_frame
	_castle_silhouette()

## Distant impostor forests are grouped into large cells: each cell is one draw call, and
## the near trees are still masked out per pixel by the forest shader, so bigger cells cost
## far fewer draws for the same picture. (Was 192 m, ~1,400 draws across the map.)
const FOREST_CELL := 768.0
const FOREST_RANGE := 1400.0

## Merge every mesh under a purely decorative far proxy into one draw per material.
static func flatten_static(root: Node3D) -> int:
	var JointBatches = load("res://scripts/joint_draw_batches.gd")
	var tools: Dictionary = {}
	var materials: Dictionary = {}
	var sources: Array = []
	var inverse := root.global_transform.affine_inverse()
	for geometry in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var frames: Array = []
		var base: Transform3D = inverse * geometry.global_transform
		if geometry is MeshInstance3D and geometry.mesh != null:
			mesh = geometry.mesh; frames = [base]
		elif geometry is MultiMeshInstance3D and geometry.multimesh != null and geometry.multimesh.mesh != null:
			mesh = geometry.multimesh.mesh
			for i in geometry.multimesh.instance_count: frames.append(base * geometry.multimesh.get_instance_transform(i))
		else: continue
		var ok := true
		for surface in mesh.get_surface_count():
			var paint = geometry.material_override if geometry.material_override != null else (geometry.get_surface_override_material(surface) if geometry is MeshInstance3D else null)
			if paint == null: paint = mesh.surface_get_material(surface)
			if paint == null or not JointBatches.merge_safe(paint) or (mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES): ok = false; break
		if not ok: continue
		for surface in mesh.get_surface_count():
			var paint = geometry.material_override if geometry.material_override != null else (geometry.get_surface_override_material(surface) if geometry is MeshInstance3D else null)
			if paint == null: paint = mesh.surface_get_material(surface)
			if not tools.has(paint):
				var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); tools[paint] = tool
			for frame in frames: tools[paint].append_from(mesh, surface, frame)
		sources.append(geometry)
	if sources.size() < 2: return 0
	for paint in tools:
		var merged := MeshInstance3D.new(); merged.name = "FlattenedSilhouette"
		merged.mesh = tools[paint].commit(); merged.material_override = paint
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)
	for geometry in sources: geometry.queue_free()
	return sources.size() - tools.size()

func _castle_silhouette() -> void:

	var proxy = Node3D.new(); proxy.name = "CastleSilhouette"; add_child(proxy)
	castle_proxy = proxy
	var p: Vector2 = atlas.nodes.blackthornkeep
	proxy.position = Vector3(p.x, atlas.height_at(p), p.y)
	load("res://scripts/landmark_art.gd").castle(proxy, false); B.batch_static(proxy)
	for mesh in proxy.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_begin = 0; mesh.visibility_range_end = 0; mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flatten_static(proxy)

func _process(dt: float) -> void:
	clock += dt
	for material in water_materials: material.set_shader_parameter("world_time", clock)

func _distant_terrain() -> void:

	var mesh = load("res://assets/world/backdrop/terrain.res") as ArrayMesh
	var material = ShaderMaterial.new(); material.shader = preload("res://shaders/atlas_distant.gdshader")
	preload("res://scripts/regional_ground.gd").configure(material)
	var channels := PackedVector4Array()
	for water in atlas.watercourses():
		for i in range(water.points.size() - 1):
			var a: Vector2 = water.points[i]; var b: Vector2 = water.points[i + 1]
			channels.append(Vector4(a.x, a.y, b.x, b.y))

		var previous: Array = water.get("previous_points", [])
		for i in range(previous.size() - 1): channels.append(Vector4(previous[i].x, previous[i].y, previous[i + 1].x, previous[i + 1].y))
	assert(channels.size() <= 48, "Distant river mask capacity exceeded")
	material.set_shader_parameter("water_count", channels.size())
	while channels.size() < 48: channels.append(Vector4.ZERO)
	material.set_shader_parameter("waterways", channels)
	var lake_bounds := PackedVector4Array()
	for lake in atlas.lakes(): lake_bounds.append(Vector4(lake.pos.x, lake.pos.y, lake.extent.x, lake.extent.y))
	assert(lake_bounds.size() <= 16, "Distant lake mask capacity exceeded")
	material.set_shader_parameter("lake_count", lake_bounds.size())
	while lake_bounds.size() < 16: lake_bounds.append(Vector4.ZERO)
	material.set_shader_parameter("lake_bounds", lake_bounds)
	distant = B.mesh(self, mesh, material); distant.name = "DistantAtlasTerrain"; distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _distant_banks() -> void:
	bank_material = ShaderMaterial.new(); bank_material.shader = preload("res://shaders/atlas_distant.gdshader")
	preload("res://scripts/regional_ground.gd").configure(bank_material)
	var tiles: Array = load("res://assets/world/backdrop/banks-cells.res").get_meta("tiles")
	for i in tiles.size():
		var banks = B.mesh(self, tiles[i], bank_material)
		banks.name = "DistantRiverBankCell_%d" % i
		banks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_completed_chunks(chunks: Dictionary) -> void:


	var ownership: Array = []
	for key in chunks: ownership.append([key, chunks[key].get_meta("fixed_dressing_ready", false), int(chunks[key].get_meta("chunk_detail_level", 0))])
	var signature := hash(ownership)
	if signature == _coverage_signature: return
	_coverage_signature = signature
	var domain = preload("res://scripts/fixed_world.gd").chunk_extent()
	if terrain_mask_data == null:
		terrain_mask_data = Image.create(domain.size.x, domain.size.y, false, Image.FORMAT_R8)
		_forest_mask_data = Image.create(domain.size.x, domain.size.y, false, Image.FORMAT_R8)
	var ground = terrain_mask_data; ground.fill(Color.BLACK)
	var forest = _forest_mask_data; forest.fill(Color.BLACK)
	var origin = domain.position; var count = 0; var tree_count = 0
	for key in chunks:
		if not domain.has_point(key): continue
		var cell: Vector2i = key - origin
		ground.set_pixel(cell.x, cell.y, Color.WHITE); count += 1
		if chunks[key].get_meta("fixed_dressing_ready", false) and int(chunks[key].get_meta("chunk_detail_level", 0)) == 0: forest.set_pixel(cell.x, cell.y, Color.WHITE); tree_count += 1
	terrain_mask_data = ground
	if terrain_mask == null: terrain_mask = ImageTexture.create_from_image(ground); forest_mask = ImageTexture.create_from_image(forest)
	else: terrain_mask.update(ground); forest_mask.update(forest)
	for material in [distant.material_override if is_instance_valid(distant) else null, bank_material]:
		if material:
			material.set_shader_parameter("terrain_chunk_count", count); material.set_shader_parameter("terrain_origin", Vector2(origin)); material.set_shader_parameter("terrain_extent", Vector2(domain.size)); material.set_shader_parameter("terrain_ownership", terrain_mask)
	for material in forest_materials:
		material.set_shader_parameter("terrain_chunk_count", tree_count); material.set_shader_parameter("terrain_origin", Vector2(origin)); material.set_shader_parameter("terrain_extent", Vector2(domain.size)); material.set_shader_parameter("terrain_ownership", forest_mask)

func _water(water: Dictionary) -> void:
	var material = _water_material(str(water.kind))
	for piece in preload("res://scripts/water_profile.gd").river_pieces(water):
		var mesh = preload("res://scripts/water_profile.gd").river_mesh(piece)
		var surface = B.mesh(self, mesh, material); surface.name = "Flowing_" + water.kind
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _water_material(kind: String) -> ShaderMaterial:
	var material = ShaderMaterial.new(); material.shader = preload("res://shaders/atlas_water.gdshader")
	material.set_shader_parameter("liquid_color", Color("#71432a" if kind == "cola" else "#d75b26" if kind == "lava" else "#3d929e"))
	material.set_shader_parameter("foam_color", Color("#f0d5a4" if kind == "cola" else "#f9ba52" if kind == "lava" else "#d9ede2"))
	material.set_shader_parameter("lava", kind == "lava"); material.set_shader_parameter("cola", kind == "cola")
	material.set_shader_parameter("sky_color", Color("#c9a77f") if kind == "cola" else Color("#a9cbe0"))
	water_materials.append(material)
	return material

func _distant_forests() -> void:
	var groups: Array = FileAccess.open("res://assets/world/fixed/forest.bin", FileAccess.READ).get_var()
	var variants = {}
	for group in groups: _forest_group(group, variants)

func _forest_group(group: Dictionary, variants: Dictionary) -> void:
	var trees = load("res://scripts/regional_trees.gd")
	var region = group.region
	if not variants.has(region):
		variants[region] = trees.distant_mesh(region)
		for surface in range(variants[region].get_surface_count()): forest_materials.append(variants[region].surface_get_material(surface))


	var cells = {}; var source_origin = Vector3(group.cell.x * 1024, 0, group.cell.y * 1024)
	for saved in group.transforms:
		var frame: Transform3D = saved; frame.origin += source_origin
		var cell = Vector2i(floori(frame.origin.x / FOREST_CELL), floori(frame.origin.z / FOREST_CELL))
		if not cells.has(cell): cells[cell] = []
		frame.origin -= Vector3(cell.x * FOREST_CELL, 0, cell.y * FOREST_CELL); cells[cell].append(frame)
	for cell in cells:
		var holder = Node3D.new(); holder.name = "RegionalForest_%d_%d_%d" % [region, cell.x, cell.y]; holder.position = Vector3(cell.x * FOREST_CELL, 0, cell.y * FOREST_CELL); add_child(holder)
		var transforms: Array[Transform3D] = []
		transforms.assign(cells[cell])
		B.instances(holder, transforms, variants[region], null)
		var batch = holder.get_child(0); batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; batch.set_meta("regional_tree_asset", trees.asset_id(region))
		var source_bounds = AABB(Vector3(-0.7, -0.2, -0.7), Vector3(1.4, 1.4, 1.4))
		var bounds = transforms[0] * source_bounds
		for frame in transforms: bounds = bounds.merge(frame * source_bounds)
		batch.custom_aabb = bounds
		# Beyond this the fog has fully swallowed the impostors.
		batch.visibility_range_end = FOREST_RANGE

func _lake(lake: Dictionary) -> void:
	var mesh = preload("res://scripts/water_profile.gd").lake_mesh(lake)
	var material = _water_material(str(lake.kind))
	material.set_shader_parameter("still_lake", true)
	material.set_shader_parameter("foam_start", 1.0 - minf(0.18, 2.8 / minf(lake.extent.x, lake.extent.y)))
	material.set_shader_parameter("wave_strength", 0.035)
	var surface = B.mesh(self, mesh, material)
	surface.name = "Lake_" + lake.kind; surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if str(lake.kind) != "lava": _embankments(lake)

## Where a lake's shore runs over ground lower than the water (and no river carries it on),
## a stone embankment holds the water in, so it never hangs in the air.
func _embankments(lake: Dictionary) -> void:
	if lake.get("natural_shore", false): return
	var W = preload("res://scripts/water_profile.gd")
	var outline: PackedVector2Array = PackedVector2Array(lake.outline)
	var height := float(lake.height)
	var stone := ShaderMaterial.new(); stone.shader = preload("res://shaders/interior_stone.gdshader")
	stone.set_shader_parameter("stone_color", Color("#8a8379")); stone.set_shader_parameter("masonry", true)
	stone.set_shader_parameter("detail_tex", preload("res://assets/surfaces/stone.png"))
	stone.set_shader_parameter("accent_color", Color("#5e7c3c")); stone.set_shader_parameter("accent_amount", 0.45)
	var cap := B.world_surface("stone", "#a39b8e")
	var built := 0
	for i in range(outline.size()):
		var a: Vector2 = outline[i]; var b: Vector2 = outline[(i + 1) % outline.size()]
		var low := minf(W.terrain_height(a), W.terrain_height(b))
		if low > height - 0.3: continue
		var mid := (a + b) * 0.5
		var river_near := false
		for q in [a, mid, b]:
			var found: Dictionary = W.sample(q + (q - lake.pos).normalized() * 3.0)
			if not found.is_empty() and float(found.height) < height - 0.05: river_near = true
		if river_near: continue
		var length := a.distance_to(b) + 1.2
		var out: Vector2 = (mid - lake.pos).normalized()
		var at: Vector2 = mid + out * 0.6
		var bottom := low - 0.6; var top := height + 0.35
		var wall := Node3D.new(); wall.name = "LakeEmbankment"; add_child(wall)
		wall.position = Vector3(at.x, (bottom + top) * 0.5, at.y)
		wall.rotation.y = atan2(b.x - a.x, b.y - a.y)
		var dry := signf(out.dot(Vector2(cos(wall.rotation.y), -sin(wall.rotation.y))))
		B.box(wall, Vector3.ZERO, Vector3(1.4, top - bottom, length), stone, true)
		B.box(wall, Vector3(0, (top - bottom) * 0.5 + 0.1, 0), Vector3(1.7, 0.22, length + 0.1), cap)
		# A buttress on the dry side of each stretch, stepping out at the foot.
		B.box(wall, Vector3(dry * 1.0, -(top - bottom) * 0.25, 0), Vector3(0.9, (top - bottom) * 0.5, 1.4), stone)
		B.box(wall, Vector3(dry * 0.85, 0.1, 0), Vector3(0.6, (top - bottom) * 0.5, 1.1), stone)


		flatten_static(wall)
		for geometry in wall.find_children("*", "GeometryInstance3D", true, false):
			geometry.visibility_range_end = 280.0
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		built += 1
	set_meta("lake_embankments", int(get_meta("lake_embankments", 0)) + built)

func _bridge(record: Dictionary) -> void:
	var p = atlas.point(Vector2(record.point[0], record.point[1]))
	var root = Node3D.new(); root.name = "RoadBridge"; add_child(root)
	root.position = Vector3(p.x, world.surface_height_at(p.x, p.y), p.y)
	root.rotation.y = -deg_to_rad(float(record.angle))
	load("res://scripts/landmark_art.gd").bridge(root, Vector3.ZERO, 19, 4.5)
	B.batch_static(root)
	for mesh in root.find_children("*", "GeometryInstance3D", true, false): mesh.visibility_range_end = 280

func stream_at(position: Vector3) -> void:
	if distant != null: distant.material_override.set_shader_parameter("viewer", Vector2(position.x, position.z))
	if bank_material != null: bank_material.set_shader_parameter("viewer", Vector2(position.x, position.z))
	for material in forest_materials: material.set_shader_parameter("viewer", Vector2(position.x, position.z))
	var wanted = {}
	for group in atlas.island_groups():
		if Vector2(position.x, position.z).distance_to(group.pos) < 280:
			var id = "sky_" + str(group.region); wanted[id] = true
			if not live.has(id): live[id] = _islands(group)
	var castle: Vector2 = atlas.nodes.blackthornkeep
	if Vector2(position.x, position.z).distance_to(castle) < 310:
		wanted.castle = true
		if not live.has("castle"): live.castle = _castle(castle)
	for id in live.keys():
		if not wanted.has(id): live[id].hide(); live[id].queue_free(); live.erase(id)


	if is_instance_valid(castle_proxy): castle_proxy.visible = not live.has("castle")

func _islands(group: Dictionary) -> Node3D:
	var root = Node3D.new(); root.name = "IslandRoute_" + str(group.region); add_child(root)
	var ground = world.surface_height_at(group.lower_pos.x, group.lower_pos.y); var floor_height = atlas.island_floor(group)
	root.position = Vector3(group.pos.x, floor_height, group.pos.y)
	var stone = B.mat("#776f83" if group.region in [14, 15] else "#797964")
	var top = B.mat(atlas.COLORS[group.region - 9])
	for i in range(group.names.size()):
		var at = Vector3(i * 24, 0, 0)


		load("res://scripts/landmark_art.gd").island_rocks(root, at)
		B.cyl(root, at - Vector3.UP * 0.7, 7, 1.4, top, true)
		Places.signboard(root, at + Vector3(0, 2, -4), str(group.names[i]), 0, 3)
		Discoveries.island(world, root, group, i, at)
		if i > 0:
			load("res://scripts/landmark_art.gd").bridge(root, at - Vector3(12, 0, 0), 25, 3.2, 0.0, false)
	var lower = Vector3(group.lower_pos.x, ground + 0.25, group.lower_pos.y)
	var upper = root.position + Vector3(0, 0.25, 0)
	Places.entrance(self, "atlas_lift_" + str(group.region), lower + Vector3.UP * 0.7, upper, str(group.names[0]), "Ride the free sky lift")

	var entry = get_child(get_child_count() - 1); remove_child(entry); root.add_child(entry); entry.position -= root.position
	B.cyl(root, lower - root.position - Vector3.UP * 0.25, 3, 0.1, stone, true)
	Places.entrance(root, "atlas_return_" + str(group.region), Vector3(-4, 0.7, 0), lower, "The open road", "Return to the ground")
	B.batch_static(root)
	return root

func _castle(p: Vector2) -> Node3D:
	var root = Node3D.new(); root.name = "BlackthornKeep"; add_child(root)
	root.position = Vector3(p.x, atlas.height_at(p), p.y)
	load("res://scripts/landmark_art.gd").castle(root, true, world)
	B.batch_static(root); return root

func scatter_tree(parent: Node3D, key: Vector2i, i: int, _legacy_rng: RandomNumberGenerator = null) -> void:
	for record in preload("res://scripts/fixed_world.gd").chunk(key).get("trees", []):
		if int(record.slot) == i: preload("res://scripts/fixed_dressing.gd").tree(world, parent, key, record)


func _volcanic_fire() -> void:
	var records: Array = preload("res://scripts/fixed_world.gd").metadata().get("volcanic_fire", [])
	if records.is_empty(): return
	var holder = Node3D.new(); holder.name = "VolcanicFire"; add_child(holder)
	var template = B.flame(holder, Vector3.ZERO, Vector3.ONE)
	var shape: Mesh = template.mesh; template.free()
	var material = ShaderMaterial.new(); material.shader = preload("res://shaders/volcanic_fire.gdshader")
	var cells = {}
	for record in records:
		var p: Vector3 = record.point; var size: float = record.size
		var cell = Vector2i(floori(p.x / 192), floori(p.z / 192))
		if not cells.has(cell): cells[cell] = []
		var origin = Vector3(cell.x * 192, 0, cell.y * 192)
		var dimensions = Vector3(size * 0.65, size, size * 0.6)
		cells[cell].append(Transform3D(Basis(Vector3.UP, record.yaw).scaled(dimensions), p - origin + Vector3.UP * (size * 0.5 - 0.07)))
	for cell in cells:
		var group = Node3D.new(); group.position = Vector3(cell.x * 192, 0, cell.y * 192); holder.add_child(group)
		var frames: Array[Transform3D] = []; frames.assign(cells[cell])
		B.instances(group, frames, shape, material)
		var batch: MultiMeshInstance3D = group.get_child(0)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 150.0
