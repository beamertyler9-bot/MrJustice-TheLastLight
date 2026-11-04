extends Node3D

const B = preload("res://scripts/build.gd")
const Locations = preload("res://scripts/locations.gd")
const Harvestable = preload("res://scripts/harvestable.gd")
const Mineable = preload("res://scripts/mineable.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const WorldAtlas = preload("res://scripts/world_atlas.gd")
const AtlasScenery = preload("res://scripts/atlas_scenery.gd")
const ChunkLOD = preload("res://scripts/chunk_lod.gd")
const MosswakeLayouts = preload("res://scripts/mosswake_layouts.gd")
const MosswakeInteriors = preload("res://scripts/mosswake_interiors.gd")
const RegionSites = preload("res://scripts/region_sites.gd")
const RegionalInteriors = preload("res://scripts/regional_interiors.gd")
const RegionalSettlements = preload("res://scripts/regional_settlements.gd")
const RegionalGround = preload("res://scripts/regional_ground.gd")
var atlas
var atlas_scenery
var mosswake
var regional
var society
var scrappers
var site_catalog: Array = Locations.SITES
var _navigation_locations: Array = []
var _navigation_cells: Dictionary = {}
var _navigation_ids: Dictionary = {}
var _selection_position := Vector3.INF
var _selection_frame: int = -1000
var _selection_state: int = 0
var _detail_position := Vector3.ZERO
var locations: Node3D
var residents: Array[Node3D] = []
var reserved_cache_positions: Array = []
const CampGround = preload("res://scripts/camp_ground.gd")
var camp_ground = CampGround.new()
var _growth_clock := 0.0
var _stone_clock = 0.0
const CHUNK: int = 48
const STEPS: int = 16
var water_level: float = -1.7
var state
var noise = FastNoiseLite.new()
var detail = FastNoiseLite.new()
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []


var surface_grids: Dictionary = {}
var fine_surface_grids: Dictionary = {}
var terrain_contexts: Dictionary = {}
var stream_job: Dictionary = {}
var settlement_jobs: Array[Dictionary] = []
var center: Vector2i = Vector2i(99999, 99999)
var ground_mat: ShaderMaterial
var art_materials: Dictionary = {}
var art_meshes: Dictionary = {}
var site_heights: Dictionary = {}
var radius: int = 2
var water: MeshInstance3D
var elapsed: float = 0.0
const LEGACY_LANDMARKS = [
	{"id": "beam", "pos": Vector2(18, -28), "name": "Shrine of the Kindled Palm"},
	{"id": "hook", "pos": Vector2(103, -58), "name": "Shrine of the Wandering Hand"},
	{"id": "heart", "pos": Vector2(-95, -82), "name": "The Heart of the Hollow"}]
const MOUNTAINS = Locations.MOUNTAINS
const GROUND_COLORS = [Color("#356a4d"), Color("#416675"), Color("#4c6757"), Color("#3d7b72"), Color("#c5d5d6"), Color("#c49c65"), Color("#536e56"), Color("#8a7048"), Color("#355b4c"), Color("#46734d"), Color("#798e4b"), Color("#979863"), Color("#cba56f"), Color("#564744"), Color("#50495a"), Color("#8aa8ad")]
const CROWN_COLORS = ["#315b3c", "#36726a", "#3a625a", "#2f7466", "#42676c", "#7e9262", "#497669", "#a56b38", "#285947", "#355b45", "#638743", "#6e8151", "#7e8a5a", "#322f32", "#36313f", "#8cbabc"]
const TIP_COLORS = ["#709751", "#a2c7a4", "#b4aa75", "#7ebda0", "#d9e6e5", "#a8b278", "#8fa477", "#d5a34a", "#5c8c62", "#85a565", "#eddbb0", "#aeb073", "#aa9b6f", "#c47143", "#a39baf", "#c4d3e7"]
const GRASS_COLORS = ["#3f7954", "#4d8b87", "#4e7c61", "#419584", "#96b8ba", "#a89760", "#6b8c55", "#9b8348", "#4f7760", "#517d55", "#879348", "#a5a66b", "#ac9a62", "#716056", "#69616e", "#92bcb4"]
const MEADOW_COLORS = ["#7f9d5a", "#8bb6a7", "#b1a66b", "#86b58a", "#c7d9d7", "#c6b97e", "#a0ac73", "#ba9e56", "#779274", "#8eaa68", "#b1ac71", "#b5b57a", "#d4b57d", "#89765f", "#8c8292", "#a7c3cd"]


var landmarks: Array = []
var region_names: Array[String] = ["MOSSWAKE VALLEY", "THE GLASSWOOD", "THE SUSPENDED GARDEN", "STILLWATER BASIN", "FROSTREACH HIGHLANDS", "THE SUNSPIRE DUNES", "REEDWATER MARSH", "ALDERGOLD WOOD", "THE GREAT NORTHWOOD"]

func setup(data) -> void:
	state = data
	_navigation_locations.clear()
	_navigation_cells.clear()
	_navigation_ids.clear()
	_selection_position = Vector3.INF; _selection_frame = -1000
	_detail_position = Vector3.ZERO
	atlas = null; site_catalog = Locations.SITES
	if state.get("expanded_world") == true:
		atlas = WorldAtlas.new(state.seed_value)
		site_catalog = atlas.sites()
		for region in atlas.regions: region_names.append(str(region.name).to_upper())
	camp_ground.setup(state)
	noise.seed = state.seed_value
	noise.frequency = 0.009
	noise.fractal_octaves = 3
	detail.seed = state.seed_value + 937
	detail.frequency = 0.05
	site_heights.clear()
	terrain_contexts.clear()
	surface_grids.clear(); fine_surface_grids.clear()
	site_heights["wizard_tower"] = maxf(frontier_height_at(Locations.TOWER.pos.x, Locations.TOWER.pos.y), water_level + 4.0)
	for site in site_catalog:
		site_heights[site.id] = atlas.height_at(site.pos) if atlas != null else maxf(frontier_height_at(site.pos.x, site.pos.y) if site.kind == "city" else base_height(site.pos.x, site.pos.y), water_level + 4.0)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/terrain.gdshader")
	ground_mat.set_shader_parameter("ground_detail", B.Surfaces.texture("ground"))
	ground_mat.set_shader_parameter("rock_detail", B.Surfaces.texture("stone"))
	if atlas != null: RegionalGround.configure(ground_mat)
	ground_mat.set_shader_parameter("clearing_count", state.camp_clearings.size())
	ground_mat.set_shader_parameter("clearings", camp_ground.shader_records())

func base_height(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 10.0 + detail.get_noise_2d(x, z) * 1.25 + 3.0

func legacy_height_at(x: float, z: float) -> float:
	var p = Vector2(x, z)
	var h = base_height(x, z)
	h -= (1.0 - smoothstep(9.0, 33.0, p.distance_to(Vector2(20, 48)))) * 15.0
	h = lerpf(base_height(0, 0), h, smoothstep(8.0, 18.0, p.length()))
	for land in LEGACY_LANDMARKS:
		var lp: Vector2 = land.pos
		h = lerpf(h, base_height(lp.x, lp.y), 1.0 - smoothstep(5.0, 12.0, p.distance_to(lp)))
	return h

func frontier_height_at(x: float, z: float) -> float:
	var h = legacy_height_at(x, z)


	var north: float = 1.0 - smoothstep(-260.0, -170.0, z)
	h += north * (10.0 + 7.0 * sin(x * 0.012 + noise.get_noise_2d(x, z) * 1.5))
	var snow: float = smoothstep(160.0, 285.0, -x) * smoothstep(210.0, 320.0, -z)
	h += snow * (12.0 + absf(noise.get_noise_2d(x * 0.7, z * 0.7)) * 23.0)
	var dunes: float = smoothstep(185.0, 280.0, x) * smoothstep(65.0, 160.0, z)
	h = lerpf(h, 5.0 + sin(x * 0.026 + z * 0.011) * 3.6 + noise.get_noise_2d(x, z) * 2.0, dunes)
	var marsh: float = smoothstep(250.0, 335.0, z) * (1.0 - smoothstep(155.0, 250.0, absf(x - 50.0)))
	h = lerpf(h, water_level + 0.5 + detail.get_noise_2d(x, z) * 1.25, marsh)
	var autumn: float = smoothstep(150.0, 240.0, -x) * smoothstep(40.0, 125.0, z)
	h += autumn * (2.0 + sin(z * 0.018) * 2.0)
	return h

func _height_features_at(x: float, z: float) -> Dictionary:
	var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
	if terrain_contexts.has(key): return terrain_contexts[key]
	var bounds := Rect2(Vector2(key) * CHUNK, Vector2.ONE * CHUNK).grow(0.001)
	var features := {"mountains": [], "sites": [], "bluffs": [], "routes": [], "tower": bounds.intersects(Rect2(Locations.TOWER.pos - Vector2.ONE * 8.0, Vector2.ONE * 16.0))}
	for mountain in MOUNTAINS:
		if bounds.intersects(Rect2(mountain.pos - mountain.extent, mountain.extent * 2)):
			features.mountains.append(mountain)
	for site in Locations.SITES:
		var local: Rect2 = Locations.site_bounds(site)
		if bounds.intersects(Rect2(site.pos + local.position, local.size).grow(18.0 if site.kind == "city" else 4.0)):
			features.sites.append(site)
		if site.kind in ["mine", "dungeon"] and bounds.intersects(Rect2(site.pos + Vector2(-22, -44), Vector2(44, 52))):
			features.bluffs.append(site)
	for route in Locations.ROUTES + Locations.FRONTIER_ROUTES + [Locations.TOWER_ROUTE]:
		if bounds.intersects(Rect2(route[0], Vector2.ZERO).expand(route[1]).grow(4.5)):
			features.routes.append(route)

	if terrain_contexts.size() >= 256: terrain_contexts.clear()
	terrain_contexts[key] = features
	return features

func _base_height_at(x: float, z: float) -> float:
	if atlas != null: return atlas.height_at(Vector2(x, z))
	var p = Vector2(x, z)
	var features := _height_features_at(x, z)
	var h = frontier_height_at(x, z)


	for mountain in features.mountains:
		var local: Vector2 = (p - mountain.pos) / mountain.extent
		var weight = 1.0 - smoothstep(0.22, 1.0, local.length())
		var summit = base_height(mountain.pos.x, mountain.pos.y) + mountain.rise
		h = maxf(h, lerpf(h, summit, weight))

	for site in features.sites:
		var target: float = site_heights[site.id]
		h = lerpf(h, target, Locations.flatten_weight(site, p))
	if features.tower:
		var tower_weight := 1.0 - smoothstep(6.0, 8.0, p.distance_to(Locations.TOWER.pos))
		h = lerpf(h, site_heights["wizard_tower"], tower_weight)


	for site in features.bluffs:
		var local: Vector2 = p - site.pos
		var radial: float = ((local - Vector2(0, -18)) / Vector2(22, 26)).length()
		if radial >= 1.0: continue
		var weight: float = 1.0 - smoothstep(0.08, 1.0, radial)
		var throat: float = 1.0 - smoothstep(-7.5, -3.5, local.y)
		var sides: float = smoothstep(3.2, 6.0, absf(local.x))
		weight *= maxf(throat, sides)


		for route in Locations.ROUTES:
			var approach: Vector2 = Geometry2D.get_closest_point_to_segment(p, route[0], route[1])
			weight *= smoothstep(3.0, 6.0, p.distance_to(approach))
		for settlement_site in Locations.SITES:
			if settlement_site.kind in ["village", "town", "city"]:
				weight *= 1.0 - Locations.flatten_weight(settlement_site, p)
		if weight > 0.0:
			var target: float = site_heights[site.id]
			h = maxf(h, lerpf(h, target + 16.0 * weight, smoothstep(0.0, 0.28, weight)))


	for route in features.routes:
		var closest = Geometry2D.get_closest_point_to_segment(p, route[0], route[1])
		var distance = p.distance_to(closest)
		if distance < 4.5:
			var grade = 1.0 - smoothstep(1.6, 4.5, distance)
			h = maxf(h, lerpf(water_level - 1.5, water_level + 4.0, grade))


	var bell_road: Array = Locations.ROUTES.back()
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, bell_road[0], bell_road[1])
	var distance: float = p.distance_to(closest)
	if distance < 5.5:
		var t: float = bell_road[0].distance_to(closest) / bell_road[0].distance_to(bell_road[1])
		var road_height: float = lerpf(site_heights["ironbell"], site_heights["dungeon"], t)
		h = lerpf(h, road_height, 1.0 - smoothstep(2.0, 5.5, distance))
	return h

func height_at(x: float, z: float) -> float:
	return _cleared_height(x, z) if camp_ground.near_point(Vector2(x, z)) else _base_height_at(x, z)

func _base_surface_height(x: float, z: float) -> float:
	var step := float(CHUNK) / STEPS
	var left = floorf(x / step) * step; var near = floorf(z / step) * step
	var u = (x - left) / step; var v = (z - near) / step
	var a = _base_height_at(left, near); var b = _base_height_at(left + step, near); var c = _base_height_at(left, near + step)
	if u + v <= 1.0: return a + (b - a) * u + (c - a) * v
	var d = _base_height_at(left + step, near + step)
	return d + (c - d) * (1 - u) + (b - d) * (1 - v)

func _cleared_height(x: float, z: float) -> float:
	return camp_ground.height_for(Vector2(x, z), _base_surface_height(x, z))

func _fine_surface_grid(left: float, near: float) -> PackedFloat64Array:
	var key = Vector2i(roundi(left), roundi(near))
	if fine_surface_grids.has(key): return fine_surface_grids[key]
	if fine_surface_grids.size() > 512: fine_surface_grids.clear()
	var grid := PackedFloat64Array()
	for z in range(4):
		for x in range(4): grid.append(_cleared_height(left + x, near + z))
	fine_surface_grids[key] = grid; return grid

func prepare_camp(point: Vector3) -> Vector3:
	camp_ground.place(point)
	refresh_camp_ground()
	return point

func refresh_camp_ground() -> void:
	fine_surface_grids.clear()
	ground_mat.set_shader_parameter("clearing_count", state.camp_clearings.size())
	ground_mat.set_shader_parameter("clearings", camp_ground.shader_records())
	preload("res://scripts/building_paths.gd").sync_material(ground_mat)
	var affected = camp_ground.dirty_positions.duplicate()
	camp_ground.dirty_positions.clear()
	if affected.is_empty():
		for record in state.camp_clearings: affected.append(Vector2(record.position[0], record.position[2]))
	var rebuild = []
	for key in chunks.keys():
		var middle = Vector2(key.x * CHUNK + 24, key.y * CHUNK + 24)
		if affected.any(func (point): return middle.distance_to(point) <= CampGround.OUTER + 35): rebuild.append(key)
	if not stream_job.is_empty() and affected.any(func (point): return Vector2(stream_job.key.x * CHUNK + 24, stream_job.key.y * CHUNK + 24).distance_to(point) <= CampGround.OUTER + 35):
		var key = stream_job.key
		if is_instance_valid(stream_job.root): stream_job.root.free()
		chunks.erase(key); surface_grids.erase(key); stream_job.clear()
		if key not in rebuild: rebuild.append(key)
	for key in rebuild:
		if chunks.has(key): chunks[key].free(); chunks.erase(key)
		surface_grids.erase(key); make_chunk(key)

func surface_height_at(x: float, z: float, use_cache: bool = true) -> float:

	var coarse_step = float(CHUNK) / STEPS
	var fine = camp_ground.fine_cell(floorf(x / coarse_step) * coarse_step, floorf(z / coarse_step) * coarse_step)
	var step = 1.0 if fine else coarse_step
	var left = floorf(x / step) * step
	var near = floorf(z / step) * step
	var u = (x - left) / step
	var v = (z - near) / step
	var key := Vector2i(floori(left / CHUNK), floori(near / CHUNK))
	var a: float
	var b: float
	var c: float
	var d: float
	if fine:
		var base_left = floorf(x / coarse_step) * coarse_step; var base_near = floorf(z / coarse_step) * coarse_step
		var grid = _fine_surface_grid(base_left, base_near)
		var index = roundi(near - base_near) * 4 + roundi(left - base_left)
		a = grid[index]; b = grid[index + 1]; c = grid[index + 4]
		if u + v > 1.0: d = grid[index + 5]
	elif use_cache and surface_grids.has(key):
		var grid: PackedFloat64Array = surface_grids[key]
		var index := roundi((near - key.y * CHUNK) / step) * (STEPS + 1) + roundi((left - key.x * CHUNK) / step)
		a = grid[index]
		b = grid[index + 1]
		c = grid[index + STEPS + 1]
		if u + v > 1.0: d = grid[index + STEPS + 2]
	else:
		a = height_at(left, near)
		b = height_at(left + step, near)
		c = height_at(left, near + step)
		if u + v > 1.0: d = height_at(left + step, near + step)
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)

func get_locations() -> Array:
	return _navigation_points().duplicate(true)

func _navigation_points() -> Array:
	if _navigation_locations.is_empty():
		_navigation_locations = atlas.destinations() + MosswakeLayouts.destinations(atlas) + RegionSites.destinations(atlas) + RegionalSettlements.destinations(atlas) if atlas != null else Locations.get_locations()
		if atlas != null and not _navigation_locations.any(func (s): return s.id == "wizard_tower"): _navigation_locations.append({"id": "wizard_tower", "name": "The Wizard's Tower", "pos": preload("res://scripts/fixed_world.gd").wizard_anchor(), "kind": "tower"})
		if is_instance_valid(scrappers): _navigation_locations.append_array(scrappers.destinations())
	return _navigation_locations

func locations_near(point: Vector2, reach: float = 17.0) -> Array:


	if _navigation_cells.is_empty():
		for site in _navigation_points():
			var key = Vector2i((site.pos / 32.0).floor())
			if not _navigation_cells.has(key): _navigation_cells[key] = []
			_navigation_cells[key].append(site)
	var result: Array = []
	var low = Vector2i(((point - Vector2.ONE * reach) / 32.0).floor())
	var high = Vector2i(((point + Vector2.ONE * reach) / 32.0).floor())
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for site in _navigation_cells.get(Vector2i(x, z), []):
				if point.distance_squared_to(site.pos) < reach * reach: result.append(site)
	return result.duplicate(true)

func navigation_location(id: String) -> Dictionary:
	if _navigation_ids.is_empty():
		for site in _navigation_points():
			if not _navigation_ids.has(str(site.id)): _navigation_ids[str(site.id)] = site
	return _navigation_ids.get(id, {}).duplicate(true)

func interior_at(point: Vector3) -> String:
	if atlas != null:
		var id = MosswakeLayouts.interior_at(point)
		if id.is_empty(): id = RegionSites.interior_at(point)
		if id.is_empty(): id = Locations.interior_at(point, state.seed_value)
		return id
	return Locations.interior_at(point, state.seed_value)

func biome_at(x: float, z: float) -> int:
	if atlas != null: return atlas.region_at(Vector2(x, z))


	var bend_large: float = noise.get_noise_2d(x * 0.18 + 1200, z * 0.18 - 700) * 34.0
	if z < -225.0 + bend_large and x < -125.0 + bend_large: return 4
	if x > 205.0 + bend_large and z > 90.0 + bend_large: return 5
	if z > 280.0 + bend_large and x > -130.0 + bend_large and x < 220.0 + bend_large: return 6
	if x < -175.0 + bend_large and z > 55.0 + bend_large: return 7
	if z < -185.0 + bend_large: return 8
	if z > 30 and absf(x - 20) < 45:
		return 3
	var bend = noise.get_noise_2d(x + 600, z - 100) * 22
	if x + bend > 55:
		return 1
	if x + bend < -50:
		return 2
	return 0

func get_spawn() -> Vector3:
	if atlas != null:
		var p = preload("res://scripts/fixed_world.gd").spawn()
		return Vector3(p.x, surface_height_at(p.x, p.y) + 0.2, p.y)
	return Vector3(0, height_at(0, 0) + 0.2, 0)

func shrine_path_distance(p: Vector2) -> float:
	var d = 1000.0
	for land in LEGACY_LANDMARKS:
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2.ZERO, land.pos)))
	return d

func path_distance(p: Vector2) -> float:
	if atlas != null: return atlas.path_distance(p)
	var d = shrine_path_distance(p)
	for route in Locations.ROUTES + Locations.FRONTIER_ROUTES + [Locations.TOWER_ROUTE]:
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, route[0], route[1])))
	for site in Locations.SITES:
		if site.kind not in ["village", "town", "city"]:
			continue
		var local: Vector2 = p - site.pos
		if site.kind == "city":
			if absf(local.x) < site.clearance and absf(local.y) < site.clearance:
				d = minf(d, minf(absf(local.x), absf(local.y)))
			continue
		if absf(local.y) < 26 and absf(local.x) < 10:
			d = minf(d, absf(local.x))
		if absf(local.x) < 10 and absf(local.y) < 4:
			d = minf(d, absf(local.y))
	return d

func legacy_blocked(p: Vector2) -> bool:
	if p.length() < 10 or shrine_path_distance(p) < 2.1:
		return true
	for land in LEGACY_LANDMARKS:
		if p.distance_to(land.pos) < 9:
			return true
	return false

func blocked(p: Vector2) -> bool:
	if camp_ground.grass_blocked(p, 1.5): return true
	if atlas != null: return atlas.reserved(p, 2) or RegionSites.reserved(atlas, p, 2) or RegionalSettlements.reserved(atlas, p, 2) or atlas.path_distance(p) < 3.5
	for cache_point in reserved_cache_positions:
		if p.distance_to(Vector2(cache_point.x, cache_point.z)) < 3.0:
			return true
	if Locations.reserved(p) or p.length() < 10 or path_distance(p) < 2.1:
		return true
	for land in LEGACY_LANDMARKS:
		if p.distance_to(land.pos) < 9:
			return true
	return false

func reserved_at(p: Vector2, padding: float = 0) -> bool:
	if is_instance_valid(scrappers) and scrappers.reserved(p, padding): return true
	return (atlas.reserved(p, padding) or RegionSites.reserved(atlas, p, padding) or RegionalSettlements.reserved(atlas, p, padding)) if atlas != null else Locations.reserved(p, padding)

func water_height_at(p: Vector2) -> float:
	if atlas == null: return water_level
	var liquid: Dictionary = atlas.liquid_at(p)
	return float(liquid.height) if not liquid.is_empty() and liquid.kind != "lava" else -100000.0

func dry_surface_at(p: Vector2, radius: float = 0) -> bool:
	if atlas == null: return height_at(p.x, p.y) > water_level + 0.35
	var points = [p]
	if radius > 0:
		for i in range(8): points.append(p + Vector2.from_angle(i * TAU / 8) * radius)
	for at in points:
		var liquid: Dictionary = atlas.liquid_at(at)
		if not liquid.is_empty() and surface_height_at(at.x, at.y) <= liquid.height + 0.35: return false
	return true

func stream_at(pos: Vector3, immediate: bool = false) -> void:
	var indoors := not interior_at(pos).is_empty()
	var frame = Engine.get_physics_frames()
	var ownership = hash([state.camp_placed, state.camp_position, state.workbench_placed, state.workbench_position, state.camp_clearings.hash(), state.taken.size(), state.loot_epoch, radius, indoors])



	var select = immediate or ownership != _selection_state or pos.distance_squared_to(_selection_position) > 0.0625 or frame - _selection_frame >= maxi(1, ceili(Engine.physics_ticks_per_second * 0.1))
	if select:
		_selection_position = pos; _selection_frame = frame; _selection_state = ownership
		if is_instance_valid(scrappers): scrappers.stream_at(pos, false)
		if mosswake != null: mosswake.stream_at(pos)
		if regional != null: regional.stream_at(pos)
		if society != null: society.stream_at(pos, immediate)
		if atlas_scenery != null: atlas_scenery.visible = not indoors
		for chunk in chunks.values(): chunk.visible = not indoors
		Locations.stream_settlements(self, pos, immediate)
	if indoors:

		center = Vector2i(99999, 99999)
		pending.clear()
		if not stream_job.is_empty():
			if is_instance_valid(stream_job.root): stream_job.root.queue_free()
			chunks.erase(stream_job.key); surface_grids.erase(stream_job.key)
			stream_job.clear()
			if atlas_scenery != null: atlas_scenery.set_completed_chunks(chunks)
		return
	_detail_position = pos
	if select: _update_chunk_detail(pos)
	if select and atlas_scenery != null: atlas_scenery.stream_at(pos)
	var next = Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	if next == center and not chunks.is_empty():
		if immediate:
			while not stream_job.is_empty() or not pending.is_empty(): stream_step()
			_finish_scrapper_arrival(pos)
		return
	center = next
	pending.clear()
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.y - radius, center.y + radius + 1):
			var key = Vector2i(x, z)
			if not chunks.has(key) and (stream_job.is_empty() or stream_job.key != key):
				pending.append(key)
	pending.sort_custom(func (a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	for key in chunks.keys():
		if absi(key.x - center.x) > radius + 1 or absi(key.y - center.y) > radius + 1:
			chunks[key].queue_free()
			chunks.erase(key)
			surface_grids.erase(key)
	if not stream_job.is_empty() and (absi(stream_job.key.x - center.x) > radius + 1 or absi(stream_job.key.y - center.y) > radius + 1):
		if is_instance_valid(stream_job.root): stream_job.root.queue_free()
		chunks.erase(stream_job.key); surface_grids.erase(stream_job.key)
		stream_job.clear()
	if immediate:


		while not stream_job.is_empty() or not pending.is_empty(): stream_step()
		_finish_scrapper_arrival(pos)
	if atlas_scenery != null: atlas_scenery.set_completed_chunks(chunks)
	if water != null:
		water.position.x = pos.x
		water.position.z = pos.z

func _finish_scrapper_arrival(point: Vector3) -> void:
	if not is_instance_valid(scrappers): return


	scrappers.stream_at(point, false)
	while not scrappers.jobs.is_empty(): scrappers.step()
	scrappers.stream_at(point, false)

func _update_chunk_detail(position: Vector3) -> void:
	var changed = false
	for chunk in chunks.values():
		var controller = chunk.get_node_or_null("ChunkLOD")
		if controller != null: changed = controller.update_viewer(position) or changed
	if changed and atlas_scenery != null: atlas_scenery.set_completed_chunks(chunks)

func _finish_chunk_detail(chunk: Node3D) -> void:
	ChunkLOD.attach(chunk).update_viewer(_detail_position)

func _process(dt: float) -> void:
	elapsed += dt
	_stone_clock += dt
	if _stone_clock >= 0.12:
		_stone_clock = 0
		var targets = get_tree().get_nodes_in_group("player")
		if not targets.is_empty():
			for stones in get_tree().get_nodes_in_group("ground_stone_batches"): stones.sync_near(targets[0].global_position)
	_growth_clock += dt
	if _growth_clock >= 1.0:
		_growth_clock = 0.0
		ground_mat.set_shader_parameter("clearings", camp_ground.shader_records())
		preload("res://scripts/building_paths.gd").sync_material(ground_mat)
		if camp_ground.newly_regrown(): refresh_camp_ground()


	for key in art_materials:
		if str(key).begins_with("leaf:") or str(key) == "foam":
			art_materials[key].set_shader_parameter("world_time", elapsed)
			if art_materials[key].next_pass != null:
				art_materials[key].next_pass.set_shader_parameter("world_time", elapsed)
	var players = get_tree().get_nodes_in_group("player")
	var nearby_player: Node3D = players[0] if not players.is_empty() else null

	for resident in residents:
		if is_instance_valid(resident):
			resident.tick(dt, nearby_player)
	var stream_started := Time.get_ticks_usec()
	while (not pending.is_empty() or not stream_job.is_empty()) and Time.get_ticks_usec() - stream_started < 2000:
		stream_step()
	Locations.step_settlement(self)
	for n in get_tree().get_nodes_in_group("float_pickup"):
		n.rotation.y += dt * 0.6
		n.position.y = float(n.get_meta("base_y")) + sin(elapsed * 1.8 + n.position.x) * 0.12
	if not players.is_empty():
		for body in get_tree().get_nodes_in_group("loose_prop"):
			if body.global_position.distance_to(players[0].global_position) > 160 or (body.global_position.y < -30 and interior_at(body.global_position).is_empty()):
				body.queue_free()

func make_chunk(key: Vector2i) -> void:
	if not stream_job.is_empty() and stream_job.key == key:
		while not stream_job.is_empty(): stream_step()
		return
	if chunks.has(key): return
	var job := _new_chunk_job(key)
	while not _chunk_step(job): pass

func _new_chunk_job(key: Vector2i) -> Dictionary:
	var root := Node3D.new()
	root.name = "Chunk_%s_%s" % [key.x, key.y]
	root.position = Vector3(key.x * CHUNK, 0, key.y * CHUNK)
	add_child(root)
	return {"key": key, "root": root, "phase": "terrain", "index": 0, "quality": int(state.settings.quality), "verts": PackedVector3Array(), "norms": PackedVector3Array(), "cols": PackedColorArray(), "grid": PackedFloat64Array()}




func stream_step() -> void:
	if stream_job.is_empty():
		while not pending.is_empty() and chunks.has(pending.front()): pending.pop_front()
		if pending.is_empty(): return
		stream_job = _new_chunk_job(pending.pop_front())
	if _chunk_step(stream_job): stream_job.clear()

func _chunk_step(job: Dictionary) -> bool:
	if atlas != null: return _fixed_chunk_step(job)
	var root: Node3D = job.root
	var key: Vector2i = job.key
	match job.phase:
		"terrain":
			_sample_terrain_rows(job, mini(STEPS + 1, int(job.index) + 3))
			if job.index > STEPS: job.phase = "ground"
		"ground":
			_finish_terrain(job)
			job.scatter = _scatter_data(key)
			job.phase = "trees"; job.index = 0
		"trees":
			_scatter_tree(root, key, job.index, job.scatter)
			job.index += 1
			if job.index >= 12: job.phase = "grass"; job.index = 0
		"grass":
			var slots := 160 if job.quality > 0 else 50
			for i in range(job.index, mini(slots, int(job.index) + 16)):
				_scatter_grass(root, job.scatter.rng, job.scatter.grass)
			job.index += 16
			if job.index >= slots: job.phase = "scatter_finish"
		"scatter_finish":
			_scatter_finish(root, job.scatter)
			var empty: Array[Transform3D] = []
			job.cover = {"grass": empty.duplicate(), "meadow": empty.duplicate(), "flowers": empty.duplicate(), "ferns": empty.duplicate(), "mushrooms": empty.duplicate(), "pebbles": empty.duplicate()}
			job.phase = "cover"; job.index = 0
		"cover":
			var biome := biome_at(root.position.x + 24, root.position.z + 24)
			var quality := clampi(job.quality, 0, 2)
			var patches: int = [22, 74, 96][quality]
			if biome in [4, 5]: patches = maxi(5, patches / 4)
			for i in range(job.index, mini(patches, int(job.index) + 4)):
				_ground_cover_patch(root, biome, job.scatter.visual_rng, job.cover, i, [4, 7, 8][quality])
			job.index += 4
			if job.index >= patches: job.phase = "plant"
		"plant":
			_plant_ground_cover(root, biome_at(root.position.x + 24, root.position.z + 24), job.cover, job.scatter.grass)
			job.phase = "items"
		"items":
			_scatter_items(root, key, job.scatter.rng)
			job.loose_rng = RandomNumberGenerator.new()
			job.loose_rng.seed = hash("loose-ground:%s:%s:%s" % [state.seed_value, key.x, key.y])
			job.phase = "loose"; job.index = 0
		"loose":
			for i in range(job.index, mini(20, int(job.index) + 4)):
				_scatter_loose_slot(root, key, i, job.loose_rng)
			job.index += 4
			if job.index >= 20: job.phase = "shore"
		"shore":
			shoreline(root, key)
			job.phase = "batch"
		"batch":
			B.batch_static(root)
			load("res://scripts/chunk_instances.gd").build(root)
			_finish_chunk_detail(root)
			return true
	return false

func _fixed_chunk_step(job: Dictionary) -> bool:
	var root: Node3D = job.root; var key: Vector2i = job.key
	var fixed = preload("res://scripts/fixed_world.gd")
	var dressing = preload("res://scripts/fixed_dressing.gd")
	match job.phase:
		"terrain":
			_sample_terrain_rows(job, mini(STEPS + 1, int(job.index) + 3))
			if job.index > STEPS: job.phase = "ground"
		"ground":
			_finish_terrain(job); job.fixed = fixed.chunk(key); job.phase = "fixed_trees"; job.index = 0
		"fixed_trees":
			var rows: Array = job.fixed.get("trees", [])
			if job.index < rows.size(): dressing.tree(self, root, key, rows[job.index])
			job.index += 1
			if job.index >= rows.size():
				var empty: Array[Transform3D] = []
				job.cover = {"grass": empty.duplicate(), "meadow": empty.duplicate(), "flowers": empty.duplicate(), "ferns": empty.duplicate(), "mushrooms": empty.duplicate(), "pebbles": empty.duplicate()}
				job.phase = "fixed_cover"; job.index = 0
		"fixed_cover":
			var quality = clampi(job.quality, 0, 2); var count = fixed.cover_count(key, quality)
			for i in range(job.index, mini(count, int(job.index) + 4)): dressing.cover(self, root, i, int(job.fixed.get("cover", 0)), quality, job.cover)
			job.index += 4
			if job.index >= count:
				var grass: Array[Transform3D] = []
				_plant_ground_cover(root, biome_at(root.position.x + 24, root.position.z + 24), job.cover, grass)
				job.phase = "fixed_items"; job.index = 0
		"fixed_items":
			var rows: Array = job.fixed.get("items", [])
			for i in range(job.index, mini(rows.size(), int(job.index) + 4)): dressing.item(self, root, key, rows[i])
			job.index += 4
			if job.index >= rows.size():
				var point: Vector3 = job.fixed.get("ruin", Vector3.INF)
				if point.is_finite() and decoration_allowed(root, Vector2(point.x, point.z), 6.5): ruin(root, point, 0.8)
				job.phase = "fixed_loose"; job.index = 0
		"fixed_loose":
			var rows: Array = job.fixed.get("loose", [])
			for i in range(job.index, mini(rows.size(), int(job.index) + 4)): dressing.loose(self, root, key, rows[i])
			job.index += 4
			if job.index >= rows.size(): job.phase = "shore"
		"shore": shoreline(root, key); job.phase = "batch"
		"batch":
			B.batch_static(root); load("res://scripts/chunk_instances.gd").build(root)
			root.set_meta("fixed_dressing_ready", true)
			_finish_chunk_detail(root)
			if atlas_scenery != null: atlas_scenery.set_completed_chunks(chunks)
			return true
	return false

func _sample_terrain_rows(job: Dictionary, finish: int) -> void:
	var key: Vector2i = job.key
	var verts: PackedVector3Array = job.verts
	var norms: PackedVector3Array = job.norms
	var cols: PackedColorArray = job.cols
	var grid: PackedFloat64Array = job.grid
	var step_size := float(CHUNK) / STEPS
	for z in range(job.index, finish):
		for x in range(STEPS + 1):
			var gx = key.x * CHUNK + x * step_size
			var gz = key.y * CHUNK + z * step_size
			var h = height_at(gx, gz)
			grid.append(h)
			verts.append(Vector3(x * step_size, h, z * step_size))
			var norm = Vector3(height_at(gx - 0.2, gz) - height_at(gx + 0.2, gz), 0.4, height_at(gx, gz - 0.2) - height_at(gx, gz + 0.2)).normalized()
			norms.append(norm)
			cols.append(ground_color_at(gx, gz, h, norm))
	job.verts = verts; job.norms = norms; job.cols = cols; job.grid = grid
	job.index = finish

func _finish_terrain(job: Dictionary) -> void:
	var root: Node3D = job.root
	var key: Vector2i = job.key
	var verts: PackedVector3Array = job.verts
	var norms: PackedVector3Array = job.norms
	var cols: PackedColorArray = job.cols
	var idx := PackedInt32Array()
	for z in range(STEPS):
		for x in range(STEPS):
			var i = z * (STEPS + 1) + x
			idx.append_array(PackedInt32Array([i, i + 1, i + STEPS + 1, i + 1, i + STEPS + 2, i + STEPS + 1]))
	if camp_ground.near_point(Vector2(key.x * CHUNK + 24, key.y * CHUNK + 24), 35):
		var adaptive = _camp_mesh_arrays(key)
		verts = adaptive.vertices; norms = adaptive.normals; cols = adaptive.colors; idx = adaptive.indices
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)



	var ground = B.mesh(root, mesh, ground_mat)
	ground.name = "TerrainSurface"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var faces = PackedVector3Array()
	for index in idx:
		faces.append(verts[index])
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var terrain = B.solid(root, Vector3.ZERO, shape)
	terrain.name = "TerrainCollider"
	terrain.set_meta("terrain", true)
	terrain.set_meta("climbable", true)
	surface_grids[key] = job.grid
	chunks[key] = root
	if atlas_scenery != null: atlas_scenery.set_completed_chunks(chunks)

func _camp_mesh_arrays(key: Vector2i) -> Dictionary:
	var vertices: Array[Vector3] = []; var normals: Array[Vector3] = []; var colors: Array[Color] = []
	var indices := PackedInt32Array(); var cache = {}
	for z in range(STEPS):
		for x in range(STEPS):
			var left: float = key.x * CHUNK + x * 3; var near: float = key.y * CHUNK + z * 3
			var parts = 3 if camp_ground.fine_cell(left, near) else 1
			var stride = 3 / parts
			for j in range(parts):
				for i in range(parts):
					var quad = []
					for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]:
						var slot = Vector2i(x * 3 + (i + offset.x) * stride, z * 3 + (j + offset.y) * stride)
						if not cache.has(slot):
							var gx: float = key.x * CHUNK + slot.x; var gz: float = key.y * CHUNK + slot.y
							var h = _cleared_height(gx, gz) if parts == 3 else height_at(gx, gz)
							var normal = Vector3(_cleared_height(gx - 0.2, gz) - _cleared_height(gx + 0.2, gz), 0.4, _cleared_height(gx, gz - 0.2) - _cleared_height(gx, gz + 0.2)).normalized() if parts == 3 else Vector3(height_at(gx - 0.2, gz) - height_at(gx + 0.2, gz), 0.4, height_at(gx, gz - 0.2) - height_at(gx, gz + 0.2)).normalized()
							cache[slot] = vertices.size(); vertices.append(Vector3(slot.x, h, slot.y)); normals.append(normal); colors.append(ground_color_at(gx, gz, h, normal))
						quad.append(cache[slot])
					indices.append_array(PackedInt32Array([quad[0], quad[1], quad[2], quad[1], quad[3], quad[2]]))
	return {"vertices": PackedVector3Array(vertices), "normals": PackedVector3Array(normals), "colors": PackedColorArray(colors), "indices": indices}

func ground_color_at(x: float, z: float, height: float, normal: Vector3, path_surface: bool = false) -> Color:


	var biome: int = biome_at(x, z)
	var color: Color = RegionalGround.color_for(biome) if atlas != null else GROUND_COLORS[biome]
	var litter = Color(RegionalGround.LITTER[biome - 9]) if atlas != null else Color(MEADOW_COLORS[biome])
	color = color.lerp(litter, clampf(detail.get_noise_2d(x, z) * 0.28 + 0.12, 0.02, 0.27) if atlas != null else clampf(detail.get_noise_2d(x, z) + 0.12, 0.0, 0.34))
	color = color.lerp(Color("#8c7c65"), clampf((0.88 - normal.y) * 2.7, 0.0, 0.72))
	var trail = Color(RegionalGround.PATH[biome - 9]) if atlas != null else Color("#aebbb5" if biome == 4 else "#be975f")
	color = color.lerp(trail, 1.0 if path_surface else 1.0 - smoothstep(0.9, 2.8, path_distance(Vector2(x, z))))
	if height < water_level + 1.3:
		color = color.lerp(Color("#ad9b70"), 0.57)
	if atlas != null: color.a = 1.0 - preload("res://scripts/fixed_world.gd").cliff_paint(Vector2(x, z))
	return color

func _scatter_data(key: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [state.seed_value, key.x, key.y])
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.seed = hash("art:%s:%s:%s" % [state.seed_value, key.x, key.y])
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var tips: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var roots: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var moss: Array[Transform3D] = []
	return {"rng": rng, "visual_rng": visual_rng, "trunks": trunks, "crowns": crowns, "tips": tips, "grass": grass, "roots": roots, "stones": stones, "moss": moss}

func _scatter_tree(root: Node3D, key: Vector2i, i: int, data: Dictionary) -> void:
	if atlas != null:
		atlas_scenery.scatter_tree(root, key, i, data.rng)
		return
	var rng: RandomNumberGenerator = data.rng
	var visual_rng: RandomNumberGenerator = data.visual_rng
	var roots: Array[Transform3D] = data.roots
	var stones: Array[Transform3D] = data.stones
	var moss: Array[Transform3D] = data.moss
	var biome := biome_at(root.position.x + 24, root.position.z + 24)
	var x = rng.randf_range(2, 46)
	var z = rng.randf_range(2, 46)
	var gx = root.position.x + x
	var gz = root.position.z + z
	var y = height_at(gx, gz)

	if legacy_height_at(gx, gz) < water_level + 0.6 or legacy_blocked(Vector2(gx, gz)):
		return
	var s = rng.randf_range(0.8, 1.5)
	if y < water_level + 0.6 or blocked(Vector2(gx, gz)):
		return
	if biome == 1:


		B.facet(root, Vector3(x - 0.12 * s, y + 2.5 * s, z), Vector3(0.95 * s, 5 * s, 1.1 * s), crystal_material(0)).rotation.y = 0.4
		B.facet(root, Vector3(x + 0.34 * s, y + 2.05 * s, z + 0.24 * s), Vector3(0.9 * s, 4.2 * s, 0.8 * s), crystal_material(1)).rotation.z = -0.12
		var crystal_shape = CylinderShape3D.new()
		crystal_shape.height = 5 * s
		crystal_shape.radius = 0.75 * s
		B.solid(root, Vector3(x, y + 2.5 * s, z), crystal_shape)
		B.facet(root, Vector3(x + 1, y + 1.4 * s, z), Vector3(0.65 * s, 2.8 * s, 0.7 * s), crystal_material(1)).rotation.z = -0.3
		for satellite in range(5):
			var angle = visual_rng.randf() * TAU
			var length = visual_rng.randf_range(0.65, 2.1) * s
			var offset = Vector3(cos(angle), 0, sin(angle)) * visual_rng.randf_range(0.5, 1.2) * s
			if not decoration_allowed(root, Vector2(x + offset.x, z + offset.z), 0.3):
				return
			var crystal = B.facet(root, Vector3(x, y + length * 0.46, z) + offset, Vector3(length * 0.32, length, length * 0.32), crystal_material(satellite % 2))
			crystal.rotation = Vector3(sin(angle) * 0.25, angle, cos(angle) * 0.25)
		B.mesh(root, leaf_mesh(), stone_material(false), Vector3(x, y + 0.08, z), Vector3(s * 1.8, 0.45 * s, s * 1.5))
	elif i < 9:
		var id = "tree_%s_%s_%s" % [key.x, key.y, i]

		var tree_trunks: Array[Transform3D] = []
		var tree_crowns: Array[Transform3D] = []
		var tree_tips: Array[Transform3D] = []
		tree_art(tree_trunks, tree_crowns, tree_tips, Vector3.ZERO, s, i, biome, visual_rng)
		tree_floor_art(root, roots, stones, moss, Vector3(x, y, z), s, visual_rng)
		if not state.taken.has(id):
			var tree = Harvestable.new()
			tree.world = self
			tree.position = Vector3(x, y, z)
			tree.fall_direction = float(hash(id) % 628) / 100.0
			root.add_child(tree)
			tree.set_meta("id", id)
			tree.set_meta("kind", "tree")
			tree.set_meta("label", "Chop timber")
			tree.add_to_group("interactable")
			tree.add_to_group("harvestable")
			tree.add_to_group("batch_dynamic")
			tree.set_process(false)
			load("res://scripts/world_overhaul.gd").tree(tree, biome, i, 6.8 * s)
			var shape = CylinderShape3D.new()
			shape.height = 5 * s
			shape.radius = 0.36 * s
			tree.collider = B.solid(tree, Vector3(0, shape.height / 2, 0), shape)
	else:
		var rock_id = "rock_%d_%d_%d" % [key.x, key.y, i]
		var rock_root = Mineable.new()
		rock_root.world = self
		rock_root.position = Vector3(x, y, z)
		rock_root.set_meta("id", rock_id)
		rock_root.set_meta("item", "stone")
		rock_root.set_meta("amount", 4)
		root.add_child(rock_root)
		var rock = ItemModels.build(rock_root, "stone")


		rock.scale = Vector3(s * 5.9, s * 5.7, s * 6.8)
		rock.position.y = -s * 0.09
		rock.rotation.y = visual_rng.randf() * TAU
		var shape = SphereShape3D.new()
		shape.radius = s * 0.85
		rock_root.collider = B.solid(rock_root, Vector3(0, s * 0.35, 0), shape)
		if state.taken.has(rock_id): rock_root.queue_free()

func _scatter_grass(root: Node3D, rng: RandomNumberGenerator, grass: Array[Transform3D]) -> void:
	var x = rng.randf_range(0, 48)
	var z = rng.randf_range(0, 48)
	var gx = root.position.x + x
	var gz = root.position.z + z
	var y = height_at(gx, gz)
	if legacy_height_at(gx, gz) > water_level + 0.2 and shrine_path_distance(Vector2(gx, gz)) > 1.6:

		var yaw = rng.randf() * TAU
		var blade_height = rng.randf_range(0.3, 0.7)
		if decoration_allowed(root, Vector2(x, z), 0.55):
			grass.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.72, blade_height * 1.5, 0.72)), Vector3(x, y + 0.015, z)))

func _scatter_finish(root: Node3D, data: Dictionary) -> void:
	var trunks: Array[Transform3D] = data.trunks
	var crowns: Array[Transform3D] = data.crowns
	var tips: Array[Transform3D] = data.tips
	var roots: Array[Transform3D] = data.roots
	var stones: Array[Transform3D] = data.stones
	var moss: Array[Transform3D] = data.moss
	var biome := biome_at(root.position.x + 24, root.position.z + 24)
	trunks.append_array(roots)
	B.instances(root, trunks, trunk_mesh(), B.world_surface("timber", "#715847"))
	plant_instances(root, stones, leaf_mesh(), stone_material(false))
	plant_instances(root, moss, leaf_mesh(), foliage_material("#3c8268", true, 0.018))
	B.instances(root, crowns, canopy_mesh(), foliage_material(CROWN_COLORS[biome], false, 0.042))
	B.instances(root, tips, canopy_mesh(), foliage_material(TIP_COLORS[biome], false, 0.042))

func _scatter_items(root: Node3D, key: Vector2i, rng: RandomNumberGenerator) -> void:
	for i in range(4):
		var p = Vector3(rng.randf_range(4, 44), 0, rng.randf_range(4, 44))
		p.y = height_at(p.x + root.position.x, p.z + root.position.z)
		var id = "%s_%s_%s" % [key.x, key.y, i]


		if i < 3 and p.y > water_level + 0.5 and not state.taken.has(id):
			pickup(root, p, id, "shard")
	for i in range(4):
		var p = Vector3(rng.randf_range(4, 44), 0, rng.randf_range(4, 44))
		p.y = height_at(p.x + root.position.x, p.z + root.position.z)
		if p.y > water_level and not blocked(Vector2(p.x + root.position.x, p.z + root.position.z)):
			var id = "carry_%s_%s_%s" % [key.x, key.y, i]
			if not state.taken.has(id):
				carryable(root, p + Vector3(0, 0.4, 0), i, id)
	if rng.randf() < 0.16:
		var p = Vector3(24, height_at(root.position.x + 24, root.position.z + 24), 24)
		if p.y > water_level and not blocked(Vector2(p.x + root.position.x, p.z + root.position.z)):
			ruin(root, p, 0.8)


func scatter(root: Node3D, key: Vector2i) -> void:
	if atlas != null:
		var record = preload("res://scripts/fixed_world.gd").chunk(key); var dressing = preload("res://scripts/fixed_dressing.gd")
		for row in record.get("trees", []): dressing.tree(self, root, key, row)
		var empty: Array[Transform3D] = []; var cover = {"grass": empty.duplicate(), "meadow": empty.duplicate(), "flowers": empty.duplicate(), "ferns": empty.duplicate(), "mushrooms": empty.duplicate(), "pebbles": empty.duplicate()}
		var quality = clampi(int(state.settings.quality), 0, 2)
		for i in range(preload("res://scripts/fixed_world.gd").cover_count(key, quality)): dressing.cover(self, root, i, int(record.get("cover", 0)), quality, cover)
		_plant_ground_cover(root, biome_at(root.position.x + 24, root.position.z + 24), cover, empty)
		for row in record.get("items", []): dressing.item(self, root, key, row)
		var point: Vector3 = record.get("ruin", Vector3.INF)
		if point.is_finite() and decoration_allowed(root, Vector2(point.x, point.z), 6.5): ruin(root, point, 0.8)
		return
	var data := _scatter_data(key)
	for i in range(12): _scatter_tree(root, key, i, data)
	for i in range(160 if int(state.settings.quality) > 0 else 50): _scatter_grass(root, data.rng, data.grass)
	_scatter_finish(root, data)
	undergrowth(root, biome_at(root.position.x + 24, root.position.z + 24), data.visual_rng, data.grass)
	_scatter_items(root, key, data.rng)

func scatter_loose_materials(root: Node3D, key: Vector2i) -> void:
	if atlas != null:
		for row in preload("res://scripts/fixed_world.gd").chunk(key).get("loose", []): preload("res://scripts/fixed_dressing.gd").loose(self, root, key, row)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("loose-ground:%s:%s:%s" % [state.seed_value, key.x, key.y])
	for i in range(20): _scatter_loose_slot(root, key, i, rng)

func _scatter_loose_slot(root: Node3D, key: Vector2i, i: int, rng: RandomNumberGenerator) -> void:
	var point = Vector3.ZERO
	var found = false
	for attempt in range(3):
		point = Vector3((i % 5) * 9.6 + rng.randf_range(2.0, 7.6), 0, (i / 5) * 12.0 + rng.randf_range(2.0, 10.0))
		var outdoor = Vector2(root.position.x + point.x, root.position.z + point.z)
		point.y = surface_height_at(outdoor.x, outdoor.y)
		if point.y <= water_level + 0.8 or blocked(outdoor) or path_distance(outdoor) < 2.6:
			continue
		var normal = Vector3(height_at(outdoor.x - 0.2, outdoor.y) - height_at(outdoor.x + 0.2, outdoor.y), 0.4, height_at(outdoor.x, outdoor.y - 0.2) - height_at(outdoor.x, outdoor.y + 0.2)).normalized()
		if normal.y < 0.76 or not loose_point_clear(root, point): continue
		found = true
		break
	if not found: return
	var material = "stone" if i % 2 == 0 else "stick"
	var id = "loose_%s_%s_%s_%s" % [material, key.x, key.y, i]
	if not state.taken.has(id):
		carryable(root, point + Vector3.UP * 0.4, 0 if material == "stone" else 2, id)


func loose_point_clear(root: Node3D, point: Vector3) -> bool:
	for obstacle in root.get_children():
		if not obstacle is Node3D: continue
		var clearance = 0.0
		if obstacle is Mineable or obstacle.is_in_group("harvestable"):
			clearance = 2.0
		elif obstacle is RigidBody3D:
			clearance = 1.2
		elif obstacle is StaticBody3D and obstacle.get_child_count() > 0 and not obstacle.get_child(0).shape is ConcavePolygonShape3D:
			clearance = 1.8
		elif obstacle.is_in_group("static_art_root"):
			clearance = 6.5
		if clearance > 0 and Vector2(obstacle.position.x - point.x, obstacle.position.z - point.z).length() < clearance:
			return false
	return true

func pickup(parent: Node3D, pos: Vector3, id: String, kind: String) -> void:
	if kind == "tonic": return
	var n = Node3D.new()
	n.position = pos + Vector3(0, 0.8, 0)
	parent.add_child(n)
	n.set_meta("id", id)
	n.set_meta("kind", kind)
	n.set_meta("label", "Collect a Light Essence" if kind == "shard" else "Take a lantern tonic")
	n.set_meta("base_y", n.position.y)
	n.add_to_group("interactable")
	n.add_to_group("float_pickup")
	if kind == "tonic":
		ItemModels.build(n, "tonic").position.y = -0.24
	elif kind == "shard":
		var model = ItemModels.build(n, "shard")
		model.scale = Vector3.ONE * 1.55
		model.position.y = -0.155
	else:
		B.facet(n, Vector3(0, -0.04, 0), Vector3(0.3, 0.75, 0.3), B.mat("#f3d486", 0.2, 0.5))

func carryable(parent: Node3D, pos: Vector3, variant: int, id: String = "") -> void:
	var body = preload("res://scripts/breakable_barrel.gd").new() if variant == 1 else RigidBody3D.new()
	if variant == 1: body.configure(self, id)
	body.position = pos
	body.mass = 1.5 if variant == 0 else 3 if variant == 1 else 0.6
	body.freeze = true
	body.collision_layer = 8
	body.collision_mask = 1 | 4 | 8
	body.continuous_cd = true
	body.set_meta("kind", "carry")
	body.set_meta("material", ["stone", "wood", "stick", "wood"][mini(variant, 3)])
	body.set_meta("amount", 2 if variant == 1 or variant == 3 else 1)
	body.set_meta("id", id)
	body.set_meta("label", ["Pick up stone", "Pick up barrel", "Pick up stick", "Pick up branch"][mini(variant, 3)])
	var shape: Shape3D
	var stone_center = Vector3.ZERO
	if variant == 0:
		var model = ItemModels.build(body, "stone")
		body.position.y -= 0.27
		model.position.y = -0.11


		var bounds = AABB(); var first = true
		for geometry in model.find_children("*", "MeshInstance3D", true, false):
			var frame = geometry.transform; var ancestor = geometry.get_parent()
			while ancestor != body: frame = ancestor.transform * frame; ancestor = ancestor.get_parent()
			var part = frame * geometry.mesh.get_aabb(); bounds = part if first else bounds.merge(part); first = false
		shape = BoxShape3D.new()
		shape.size = bounds.size.max(Vector3.ONE * 0.04); stone_center = bounds.get_center()
	elif variant == 1:
		body.position.y -= 0.05
		load("res://scripts/carry_container_art.gd").build(body)
		shape = BoxShape3D.new()
		shape.size = Vector3(0.7, 0.7, 0.7)
	else:
		body.position.y -= 0.27
		var model = ItemModels.build(body, "wood" if variant == 3 else "stick")


		model.rotation.z = PI / 2
		model.scale = Vector3(0.6, 1.74, 0.6) if variant == 3 else Vector3(1.3, 1.8, 1.3)
		model.position.x = 0.626 if variant == 3 else 0.622
		shape = CapsuleShape3D.new()
		shape.radius = 0.09
		shape.height = 1.3
	var col = CollisionShape3D.new()
	col.shape = shape
	if variant == 0: col.position = stone_center
	if variant >= 2:
		col.rotation.z = PI / 2
	body.add_child(col)
	parent.add_child(body)
	body.add_to_group("interactable")
	body.add_to_group("carryable")

func ruin(parent: Node3D, pos: Vector3, size: float) -> void:
	load("res://scripts/landmark_art.gd").ruin_arch(parent, pos, size)

func checkpoint_at(pos: Vector3, id: String) -> void:
	var n = Node3D.new()
	n.position = pos
	add_child(n)
	B.cyl(n, Vector3(0, 0.5, 0), 0.22, 1, B.mat("#626756"), true)
	B.box(n, Vector3(0, 1.3, 0), Vector3(0.65, 0.13, 0.65), B.mat("#bea77c", 0.5))
	B.box(n, Vector3(0, 2, 0), Vector3(0.6, 0.13, 0.6), B.mat("#bea77c", 0.5))
	B.ball(n, Vector3(0, 1.65, 0), Vector3(0.28, 0.55, 0.28), B.mat("#ffd68c", 0, 0.7))
	for x in [-0.25, 0.25]:
		for z in [-0.25, 0.25]:
			B.box(n, Vector3(x, 1.65, z), Vector3(0.055, 0.65, 0.055), B.mat("#bea77c", 0.5))
	B.cyl(n, Vector3(0, 0.09, 0), 0.46, 0.18, stone_material(true))
	B.beveled_box(n, Vector3(0, 2.1, 0), Vector3(0.77, 0.12, 0.77), B.mat("#9a8157", 0.55))
	B.ring(n, Vector3(0, 2.34, 0), 0.18, 0.035, B.mat("#bea77c", 0.5)).rotation.x = PI / 2
	B.facet(n, Vector3(0, 1.67, 0), Vector3(0.12, 0.42, 0.12), B.mat("#fff0b1", 0.1, 0.6))
	n.set_meta("kind", "checkpoint")
	n.set_meta("id", id)
	n.set_meta("label", "Rest and save at the lantern")
	n.add_to_group("interactable")

func build_landmarks_loading(progress: Callable) -> void:
	if atlas == null:
		build_landmarks(); return
	if locations == null: Locations.build(self)
	atlas_scenery = AtlasScenery.new(); add_child(atlas_scenery)
	await atlas_scenery.setup_loading(self, progress)
	progress.call("Preparing homes and gathering places")
	await get_tree().process_frame
	mosswake = MosswakeInteriors.new(); add_child(mosswake); mosswake.setup(self)
	regional = RegionalInteriors.new(); add_child(regional); regional.setup(self)
	society = RegionalSettlements.new(); add_child(society); society.setup(self)

func build_landmarks() -> void:
	if locations == null:
		Locations.build(self)
	if atlas != null:
		atlas_scenery = AtlasScenery.new()
		add_child(atlas_scenery)
		atlas_scenery.setup(self)
		mosswake = MosswakeInteriors.new(); add_child(mosswake); mosswake.setup(self)
		regional = RegionalInteriors.new(); add_child(regional); regional.setup(self)
		society = RegionalSettlements.new(); add_child(society); society.setup(self)
		return
	if not state.taken.has("starter_rock"):
		var starter_rock = Mineable.new()
		starter_rock.world = self
		starter_rock.position = Vector3(7, height_at(7, 2), 2)
		starter_rock.set_meta("id", "starter_rock")
		starter_rock.set_meta("item", "stone")
		starter_rock.set_meta("amount", 4)
		add_child(starter_rock)
		var model = ItemModels.build(starter_rock, "stone")
		model.scale = Vector3(4.3, 5.0, 5.0)
		model.position.y = -0.08
		var shape = SphereShape3D.new()
		shape.radius = 0.62
		starter_rock.collider = B.solid(starter_rock, Vector3(0, 0.45, 0), shape)
	for i in range(3):
		var id = "starter_carry_%s" % i
		if not state.taken.has(id):
			var p = [Vector2(3, -3), Vector2(5, -4), Vector2(-2, -5)][i]
			carryable(self, Vector3(p.x, height_at(p.x, p.y) + 0.4, p.y), i if i < 2 else 3, id)
	var wmat = ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	water = B.mesh(self, PlaneMesh.new(), wmat, Vector3(0, water_level, 0), Vector3(1600, 1, 1600))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for land in LEGACY_LANDMARKS:
		var p: Vector2 = land.pos
		var rest = Vector3(p.x, height_at(p.x, p.y), p.y)
		checkpoint_at(rest + Vector3(4.7, 0, 2), "lantern_" + land.id)
		var chest_id = "chest_" + land.id
		if not state.taken.has(chest_id):
			var chest = Node3D.new()
			chest.position = rest + Vector3(-4.6, 0.45, 1.8)
			add_child(chest)
			load("res://scripts/treasure_art.gd").build(chest, Vector3(1.2, 0.9, 0.85))
			var support = BoxShape3D.new(); support.size = Vector3(1.2, 0.8, 0.85); B.solid(chest, Vector3.ZERO, support)
			chest.set_meta("kind", "chest")
			chest.set_meta("id", chest_id)
			chest.set_meta("label", "Open the forgotten chest")
			chest.add_to_group("interactable")
	checkpoint_at(Vector3(-4, height_at(-4, 1), 1), "start-lantern")
	ruin(self, Vector3(-1, height_at(-1, -12), -12), 1)
	for i in range(3):
		var p = Vector3(-22 - i * 15, 0, -48 - i * 19)
		p.y = height_at(p.x, p.z)
		B.cyl(self, p + Vector3(0, 4 + i * 2, 0), 1.6, 8 + i * 4, stone_material(false), true)
		B.cyl(self, p + Vector3(0, 8.3 + i * 4, 0), 2, 0.6, stone_material(true), true)
		for tier in range(3):
			B.cyl(self, p + Vector3(0, (2 + tier * 2) * (1 + i * 0.4), 0), 1.64, 0.12, B.mat("#53664e"))
		B.cyl(self, p + Vector3(0, 8.65 + i * 4, 0), 1.55, 0.1, B.mat("#68805a"))
		for flower in range(6):
			var angle = float(flower) / 6 * TAU
			B.mesh(self, flower_mesh(), flower_material(), p + Vector3(cos(angle) * 1.3, 8.7 + i * 4, sin(angle) * 1.3))
	for i in range(5):
		suspended_ring(i)
	for i in range(15):
		B.beveled_box(self, Vector3(16, water_level + 1.4 + 0.14 * sin(float(i) / 14 * PI), 38 + i), Vector3(3.6, 0.25, 0.85), B.world_surface("timber", "#826f51"), true)
	for side in [-1, 1]:
		for i in range(4):
			B.beveled_box(self, Vector3(16 + side * 1.58, water_level + 1.85, 38 + i * 4), Vector3(0.11, 1.1, 0.13), B.world_surface("timber", "#605741"))
			if i < 3:
				B.branch(self, Vector3(16 + side * 1.58, water_level + 2.2, 38 + i * 4), Vector3(16 + side * 1.58, water_level + 2.2, 42 + i * 4), 0.027, B.mat("#b3a57d"), 1.0)
	for i in range(10):
		var p = Vector3(21 + sin(i * 2.4) * 5.0, water_level + 0.025, 46 + cos(i * 2.4) * 5)
		var pad = B.cyl(self, p, 0.25 + (i % 3) * 0.12, 0.025, B.mat("#63885e"), false)
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i % 3 == 0:
			B.mesh(self, flower_mesh(), flower_material(), p, Vector3(0.65, 0.4, 0.65))
	var signpost = Node3D.new()
	signpost.position = Vector3(-5, height_at(-5, -4), -4)
	add_child(signpost)
	signpost.set_meta("kind", "lore")
	signpost.set_meta("id", "old_signpost")
	signpost.set_meta("label", "Read the old sign")
	signpost.set_meta("text", "EMBERVEIN CAVE & MINE — follow the ochre trail north, around the west side of the broken arch. Look for the great rock mouth and the miner's sign.\n\nBoth hand powers are yours from the start. Climb the mountains, explore the caves and visit the settlements. Small lantern rests save your journey.")
	signpost.add_to_group("interactable")
	Locations.signboard(signpost, Vector3(0, 1.45, 0.1), "CAVE  ↑  48m", 0, 2.4)
	B.batch_static(self)

func foliage_material(hex: String, rooted: bool, wind: float) -> ShaderMaterial:
	var key = "leaf:%s:%s:%s" % [hex, rooted, wind]
	if not art_materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/foliage.gdshader")
		material.set_shader_parameter("leaf_color", Color(hex))
		material.set_shader_parameter("rooted", rooted)
		material.set_shader_parameter("wind_strength", wind)
		material.set_shader_parameter("world_time", elapsed)
		art_materials[key] = material
	return art_materials[key]

func stone_material(light: bool, tint: String = "") -> ShaderMaterial:
	var key = ("stone_light" if light else "stone") + tint
	if not art_materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/stone.gdshader")
		material.set_shader_parameter("stone_color", Color(tint if not tint.is_empty() else "#c3b48b" if light else "#897e69"))
		material.set_shader_parameter("stone_detail", B.Surfaces.texture("stone"))
		art_materials[key] = material
	return art_materials[key]

func crystal_material(variant: int) -> ShaderMaterial:
	var key = "crystal_%s" % variant
	if not art_materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/crystal.gdshader")
		material.set_shader_parameter("crystal_color", Color("#70c9cb" if variant == 0 else "#bc92d8"))
		art_materials[key] = material
	return art_materials[key]

func leaf_mesh() -> ArrayMesh:
	if not art_meshes.has("leaf"):
		var faces: Array[PackedVector3Array] = []
		for i in range(7):
			var a = float(i) / 7.0 * TAU
			var b = float(i + 1) / 7.0 * TAU
			var p = Vector3(cos(a) * 0.8, 0.12, sin(a) * 0.8)
			var q = Vector3(cos(b) * 0.8, 0.12, sin(b) * 0.8)
			var r = Vector3(cos(a) * 0.61, -0.32, sin(a) * 0.61)
			var s = Vector3(cos(b) * 0.61, -0.32, sin(b) * 0.61)
			faces.append(PackedVector3Array([p, q, Vector3(0.08, 0.68, -0.05)]))
			faces.append(PackedVector3Array([p, r, s, q]))
			faces.append(PackedVector3Array([r, Vector3(-0.1, -0.54, 0.08), s]))
		art_meshes.leaf = B._flat_geometry(faces)
	return art_meshes.leaf

func limb_transform(start: Vector3, end: Vector3, width: float) -> Transform3D:
	var delta = end - start
	return Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())) * Basis.from_scale(Vector3(width, delta.length(), width)), (start + end) * 0.5)

func trunk_mesh() -> CylinderMesh:
	if not art_meshes.has("trunk"):
		var shape = CylinderMesh.new()
		shape.radial_segments = 12
		shape.height = 1
		shape.top_radius = 0.52
		shape.bottom_radius = 1
		art_meshes.trunk = shape
	return art_meshes.trunk

func canopy_mesh() -> ArrayMesh:
	if not art_meshes.has("canopy"):


		var faces: Array[PackedVector3Array] = []
		var rings: Array[PackedVector3Array] = []
		var heights = [-0.43, -0.1, 0.29, 0.56]
		var radii = [0.35, 0.9, 0.78, 0.35]
		for tier in range(4):
			var ring = PackedVector3Array()
			for i in range(8):
				var angle = float(i) / 8 * TAU
				var radius_value = radii[tier] * (1.0 + sin(i * 2.4 + tier * 0.7) * 0.045)
				ring.append(Vector3(cos(angle) * radius_value, heights[tier] + sin(i * 2.1) * 0.025, sin(angle) * radius_value))
			rings.append(ring)
		for i in range(8):
			var j = (i + 1) % 8
			faces.append(PackedVector3Array([Vector3(0, -0.52, 0), rings[0][j], rings[0][i]]))
			for tier in range(3):
				faces.append(PackedVector3Array([rings[tier][i], rings[tier][j], rings[tier + 1][j], rings[tier + 1][i]]))
			faces.append(PackedVector3Array([rings[3][i], rings[3][j], Vector3(0.04, 0.64, -0.03)]))
		var shape := B._flat_geometry(faces)
		var arrays := shape.surface_get_arrays(0)
		var smooth_normals := PackedVector3Array()
		for point in arrays[Mesh.ARRAY_VERTEX]:
			smooth_normals.append(Vector3(point.x, (point.y - 0.06) * 1.5, point.z).normalized())
		arrays[Mesh.ARRAY_NORMAL] = smooth_normals
		var smooth := ArrayMesh.new()
		smooth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		art_meshes.canopy = smooth
	return art_meshes.canopy

func tree_art(trunks: Array[Transform3D], crowns: Array[Transform3D], tips: Array[Transform3D], p: Vector3, size: float, variant: int, biome: int, rng: RandomNumberGenerator) -> void:
	if biome in [4, 8]:


		trunks.append(Transform3D(Basis.from_scale(Vector3(0.35, 6.8, 0.35) * size), p + Vector3.UP * 3.4 * size))
		for tier in range(5):
			var spread: float = (2.5 - tier * 0.4) * size
			var at: Vector3 = p + Vector3.UP * (3.5 + tier * 0.95) * size
			crowns.append(Transform3D(Basis(Vector3.UP, tier * 0.6).scaled(Vector3(spread, 1.35 * size, spread)), at))
			if biome == 4:
				tips.append(Transform3D(Basis(Vector3.UP, tier * 0.6).scaled(Vector3(spread * 0.86, 0.48 * size, spread * 0.86)), at + Vector3.UP * 0.65 * size))
		return
	if biome == 5:

		trunks.append(Transform3D(Basis.from_scale(Vector3(0.32, 3.8, 0.32) * size), p + Vector3.UP * 1.9 * size))
		var heading: float = rng.randf() * TAU
		for side in [-1.0, 1.0]:
			var tip: Vector3 = p + Vector3(cos(heading) * side * 1.8, 3.7 + side * 0.3, sin(heading) * side * 1.8) * size
			trunks.append(limb_transform(p + Vector3.UP * 2.2 * size, tip, 0.14 * size))
			crowns.append(Transform3D(Basis.from_scale(Vector3(1.6, 0.75, 1.3) * size), tip))
		return
	trunks.append(Transform3D(Basis.from_scale(Vector3(0.4 * size, 5 * size, 0.4 * size)), p + Vector3.UP * 2.5 * size))
	var heading = rng.randf() * TAU
	var lean = Vector3(cos(heading), 0, sin(heading))
	var silhouette = 0 if biome == 7 else variant % 3
	if silhouette == 1:

		for tier in range(3):
			var spread = (1.2 - tier * 0.25) * size
			for i in range(3):
				var angle = heading + float(i) / 3 * TAU + tier * 0.65
				var position_value = p + Vector3(cos(angle) * spread, (4.65 + tier * 1.24) * size, sin(angle) * spread)
				var scale_value = Vector3(1.8 - tier * 0.22, 1.5 - tier * 0.13, 1.65 - tier * 0.2) * size
				var transform_value = Transform3D(Basis(Vector3.UP, angle).scaled(scale_value), position_value)
				if tier == 2:
					tips.append(transform_value)
				else:
					crowns.append(transform_value)
		for side in [-1.0, 1.0]:
			trunks.append(limb_transform(p + Vector3.UP * 3.5 * size, p + lean * side * 1.25 * size + Vector3.UP * 4.9 * size, 0.16 * size))
	else:
		var boughs = 4 if silhouette == 0 else 3
		for i in range(boughs):
			var angle = heading + float(i) / boughs * TAU
			var reach = (1.4 if silhouette == 0 else 1.85) * size
			var rise = 4.7 + sin(i * 2.2) * 0.35 + (0.25 if biome == 2 else 0.0)
			var tip = p + Vector3(cos(angle) * reach, rise * size, sin(angle) * reach)
			trunks.append(limb_transform(p + Vector3.UP * (2.8 + i * 0.2) * size, tip, (0.19 - i * 0.018) * size))
			crowns.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(1.95, 2.2 if silhouette == 0 else 1.6, 1.85) * size), tip + Vector3.UP * 0.5 * size))
			if i % 2 == 0:
				var highlight = tip + lean * 0.14 * size + Vector3.UP * 1.3 * size
				tips.append(Transform3D(Basis(Vector3.UP, angle + 0.3).scaled(Vector3(1.5, 1.1, 1.4) * size), highlight))
		crowns.append(Transform3D(Basis(Vector3.UP, heading).scaled(Vector3(2.0, 1.8, 1.8) * size), p + Vector3.UP * 5.6 * size))

	if biome == 2:
		trunks.append(limb_transform(p + Vector3.UP * 4.0 * size, p + lean * 2.2 * size + Vector3.UP * 5.5 * size, 0.11 * size))

func decoration_allowed(root: Node3D, point: Vector2, clearance: float = 0.45) -> bool:
	if camp_ground.grass_blocked(point + Vector2(root.position.x, root.position.z), clearance): return false


	if point.x < clearance or point.y < clearance or point.x > CHUNK - clearance or point.y > CHUNK - clearance:
		return false
	var world_point = point + Vector2(root.position.x, root.position.z)
	for cache_point in reserved_cache_positions:
		if world_point.distance_to(Vector2(cache_point.x, cache_point.z)) < 1.5 + clearance:
			return false
	if reserved_at(world_point, clearance):
		return false
	if path_distance(world_point) < 2.1 + clearance or world_point.length() < 4.8 + clearance:
		return false
	if atlas != null and not dry_surface_at(world_point, clearance): return false
	if height_at(world_point.x, world_point.y) < water_level + 0.45:
		return false
	for land in landmarks:
		if world_point.distance_to(land.pos) < 4.3 + clearance:
			return false
	return true

func tree_floor_art(root: Node3D, roots: Array[Transform3D], stones: Array[Transform3D], moss: Array[Transform3D], p: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	if not decoration_allowed(root, Vector2(p.x, p.z), 0.45):
		return
	var heading = rng.randf() * TAU
	for i in range(4):
		var angle = heading + float(i) / 4 * TAU + rng.randf_range(-0.25, 0.25)
		var offset = Vector2(cos(angle), sin(angle)) * size * rng.randf_range(0.95, 1.45)
		var endpoint = Vector2(p.x, p.z) + offset
		if not decoration_allowed(root, endpoint, 0.45) or not decoration_allowed(root, Vector2(p.x, p.z).lerp(endpoint, 0.5), 0.45):
			continue
		var y = height_at(endpoint.x + root.position.x, endpoint.y + root.position.z)
		roots.append(limb_transform(p + Vector3.UP * 0.38 * size, Vector3(endpoint.x, y + 0.035, endpoint.y), 0.16 * size))
		if i % 2 == 0:
			stones.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(0.6, 0.35, 0.45) * size), Vector3(endpoint.x, y + 0.06, endpoint.y)))
			moss.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(0.5, 0.16, 0.4) * size), Vector3(endpoint.x, y + 0.2, endpoint.y)))

func grass_mesh() -> ArrayMesh:
	if not art_meshes.has("grass"):
		var faces: Array[PackedVector3Array] = []
		for i in range(6):
			var angle = float(i) / 6.0 * TAU + sin(i * 2.6) * 0.2
			var axis = Vector3(cos(angle), 0, sin(angle))
			var across = Vector3(-sin(angle), 0, cos(angle))
			var base = axis * (0.05 + (i % 2) * 0.12)
			var bend = axis * (0.22 + (i % 3) * 0.12) + Vector3.UP * (0.45 + (i % 3) * 0.13)
			faces.append(PackedVector3Array([base - across * 0.1, base + across * 0.1, bend + across * 0.07, bend + axis * 0.17 + Vector3.UP * 0.25]))
		art_meshes.grass = B._flat_geometry(faces)
	return art_meshes.grass

func flower_mesh(variant: int = 0) -> ArrayMesh:
	var key = "flower_%s" % variant
	if not art_meshes.has(key):
		var faces: Array[PackedVector3Array] = []
		faces.append(PackedVector3Array([Vector3(-0.025, 0, 0), Vector3(0.025, 0, 0), Vector3(0.035, 0.55, 0)]))
		faces.append(PackedVector3Array([Vector3(0, 0.18, 0), Vector3(-0.21, 0.29, 0.03), Vector3(0, 0.27, 0)]))
		faces.append(PackedVector3Array([Vector3(0, 0.3, 0), Vector3(0.22, 0.43, 0.03), Vector3(0, 0.39, 0)]))
		for i in range(6):
			var a = float(i) / 6 * TAU
			var b = a + 0.66
			var middle = a + 0.33
			faces.append(PackedVector3Array([Vector3(0, 0.51, 0), Vector3(cos(a) * 0.13, 0.55, sin(a) * 0.13), Vector3(cos(middle) * 0.26, 0.57, sin(middle) * 0.26), Vector3(cos(b) * 0.13, 0.55, sin(b) * 0.13)]))
			faces.append(PackedVector3Array([Vector3(0, 0.565, 0), Vector3(cos(a) * 0.075, 0.566, sin(a) * 0.075), Vector3(cos(a + TAU / 6) * 0.075, 0.566, sin(a + TAU / 6) * 0.075)]))
		var shape = B._flat_geometry(faces)
		var arrays = shape.surface_get_arrays(0)
		var colors = PackedColorArray()
		var petals = [Color("#f5df9a"), Color("#ab9de8"), Color("#f3ae86"), Color("#94b7dc"), Color("#f3d7e3"), Color("#e7bd75"), Color("#c58b63"), Color("#d9cfe4"), Color("#c6e4e8")]
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			if vertex.y > 0.56 and Vector2(vertex.x, vertex.z).length() < 0.08:
				colors.append(Color("#bd7e3e"))
			else:
				var stem = Color("#be83a6" if variant == 4 else "#87945e" if variant in [3, 5] else "#76697e" if variant == 7 else "#6f8e86" if variant == 8 else "#4c8259")
				colors.append(petals[variant % petals.size()] if vertex.y >= 0.5 else stem)
		arrays[Mesh.ARRAY_COLOR] = colors
		var colored = ArrayMesh.new()
		colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		art_meshes[key] = colored
	return art_meshes[key]

func fern_mesh() -> ArrayMesh:
	if not art_meshes.has("fern"):
		var faces: Array[PackedVector3Array] = []
		for i in range(6):
			var a = float(i) / 6 * TAU
			var axis = Vector3(cos(a), 0, sin(a))
			var across = Vector3(-sin(a), 0, cos(a))
			for j in range(1, 5):
				var t = float(j) / 5
				var p = axis * t * 0.9 + Vector3.UP * sin(t * PI * 0.8) * 0.58
				var width = sin(t * PI) * 0.22
				for side in [-1.0, 1.0]:
					faces.append(PackedVector3Array([p - axis * 0.14, p + across * side * width + axis * 0.14, p + axis * 0.12]))
		art_meshes.fern = B._flat_geometry(faces)
	return art_meshes.fern

func mushroom_mesh(variant: int = 0) -> ArrayMesh:
	var key = "mushroom_%s" % variant
	if not art_meshes.has(key):
		var faces: Array[PackedVector3Array] = []
		for i in range(7):
			var a = float(i) / 7 * TAU
			var b = float(i + 1) / 7 * TAU
			var stem_a = Vector3(cos(a) * 0.05, 0, sin(a) * 0.05)
			var stem_b = Vector3(cos(b) * 0.05, 0, sin(b) * 0.05)
			faces.append(PackedVector3Array([stem_a, stem_b, stem_b + Vector3.UP * 0.26, stem_a + Vector3.UP * 0.26]))
			var rim_a = Vector3(cos(a) * 0.29, 0.27, sin(a) * 0.29)
			var rim_b = Vector3(cos(b) * 0.29, 0.27, sin(b) * 0.29)
			faces.append(PackedVector3Array([rim_a, rim_b, Vector3(0.015, 0.43, -0.01)]))
			faces.append(PackedVector3Array([Vector3(0, 0.235, 0), rim_b, rim_a]))
		var shape = B._flat_geometry(faces)
		var arrays = shape.surface_get_arrays(0)
		var colors = PackedColorArray()
		var caps = ["#d68461", "#f0dce4", "#c5b578", "#b99c72", "#bd7954", "#d3c7df", "#afced0"]
		var stems = ["#c7b994", "#dbbfd7", "#b6b196", "#a7a581", "#79706a", "#a699b8", "#b9c2d0"]
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			colors.append(Color(caps[variant % caps.size()]) if vertex.y >= 0.27 else Color(stems[variant % stems.size()]))
		arrays[Mesh.ARRAY_COLOR] = colors
		var colored = ArrayMesh.new()
		colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		art_meshes[key] = colored
	return art_meshes[key]

func ground_cover_layout(root: Node3D, biome: int, rng: RandomNumberGenerator) -> Dictionary:
	var grass: Array[Transform3D] = []
	var meadow: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var mushrooms: Array[Transform3D] = []
	var pebbles: Array[Transform3D] = []
	var layout := {"grass": grass, "meadow": meadow, "flowers": flowers, "ferns": ferns, "mushrooms": mushrooms, "pebbles": pebbles}
	var quality = clampi(int(state.settings.quality), 0, 2)
	var patch_count = [22, 74, 96][quality]
	if biome in [4, 5]: patch_count = maxi(5, patch_count / 4)
	var blades = [4, 7, 8][quality]
	for i in range(patch_count): _ground_cover_patch(root, biome, rng, layout, i, blades)
	return layout

func _ground_cover_patch(root: Node3D, biome: int, rng: RandomNumberGenerator, layout: Dictionary, i: int, blades: int) -> void:
	var grass: Array[Transform3D] = layout.grass
	var meadow: Array[Transform3D] = layout.meadow
	var flowers: Array[Transform3D] = layout.flowers
	var ferns: Array[Transform3D] = layout.ferns
	var mushrooms: Array[Transform3D] = layout.mushrooms
	var pebbles: Array[Transform3D] = layout.pebbles
	var centre = Vector2(rng.randf_range(1.5, 46.5), rng.randf_range(1.5, 46.5))
	if not decoration_allowed(root, centre, 0.8):
		return
	var radius_value = rng.randf_range(1.1, 2.4)
	var yaw = rng.randf() * TAU
	for j in range(blades):
		var angle = yaw + float(j) / blades * TAU + rng.randf_range(-0.3, 0.3)
		var point = centre + Vector2(cos(angle), sin(angle)) * rng.randf_range(0.0, radius_value)
		if not decoration_allowed(root, point, 0.85):
			return
		var y = height_at(point.x + root.position.x, point.y + root.position.z)
		var scale_value = Vector3(rng.randf_range(0.75, 1.2), rng.randf_range(0.5, 1.05) * (2.4 if biome == 6 else 0.55 if biome == 4 else 1.0), rng.randf_range(0.75, 1.2))
		var transform_value = Transform3D(Basis(Vector3.UP, angle).scaled(scale_value), Vector3(point.x, y + 0.015, point.y))
		if i % 3 == 0:
			meadow.append(transform_value)
		else:
			grass.append(transform_value)
	var path = path_distance(centre + Vector2(root.position.x, root.position.z))
	var family = i % 5
	var members = 4 if family == 0 and path < 13.0 else 3
	for j in range(members):
		var point = centre + Vector2(cos(yaw + j * 2.4), sin(yaw + j * 2.4)) * rng.randf_range(0.2, 0.9)
		var clearance = 1.25 if family == 1 or (biome == 2 and family == 4) else 0.65
		if not decoration_allowed(root, point, clearance):
			return
		var y = height_at(point.x + root.position.x, point.y + root.position.z)
		var scale_value = rng.randf_range(0.75, 1.3)
		var transform_value = Transform3D(Basis(Vector3.UP, yaw + j).scaled(Vector3.ONE * scale_value), Vector3(point.x, y + 0.02, point.y))
		if biome in [4, 5]:
			pebbles.append(Transform3D(transform_value.basis.scaled(Vector3(1.1, 0.45, 0.8)), transform_value.origin))
		elif family == 0 or (biome == 1 and family == 4):
			flowers.append(transform_value)
		elif family == 1 or (biome == 2 and family == 4):
			ferns.append(transform_value)
		elif family == 2:
			mushrooms.append(transform_value)
		elif family == 3:
			pebbles.append(Transform3D(transform_value.basis.scaled(Vector3(0.5, 0.24, 0.38)), transform_value.origin))

func undergrowth(root: Node3D, biome: int, rng: RandomNumberGenerator, grass: Array[Transform3D]) -> void:
	var layout = ground_cover_layout(root, biome, rng)
	_plant_ground_cover(root, biome, layout, grass)

func _plant_ground_cover(root: Node3D, biome: int, layout: Dictionary, grass: Array[Transform3D]) -> void:
	grass.append_array(layout.grass)
	if biome in [4, 5] and grass.size() > 18: grass.resize(18)
	var regional = biome >= 9
	plant_instances(root, grass, grass_mesh(), foliage_material(RegionalGround.GRASS[biome - 9] if regional else GRASS_COLORS[biome], true, 0.11))
	plant_instances(root, layout.meadow, grass_mesh(), foliage_material(RegionalGround.MEADOW[biome - 9] if regional else MEADOW_COLORS[biome], true, 0.11))
	plant_instances(root, layout.flowers, flower_mesh([0, 4, 3, 5, 6, 7, 8][biome - 9] if regional else 1 if biome == 1 else 2 if biome == 2 else 0), flower_material())
	plant_instances(root, layout.ferns, fern_mesh(), foliage_material(RegionalGround.FERN[biome - 9] if regional else "#418372" if biome != 2 else "#789263", true, 0.055))
	plant_instances(root, layout.mushrooms, mushroom_mesh(biome - 9 if regional else 0), flower_material())
	if not layout.pebbles.is_empty(): preload("res://scripts/ground_stones.gd").build(self, root, layout.pebbles, leaf_mesh(), stone_material(false, RegionalGround.ROCK[biome - 9] if regional else ""), layout.get("pebble_ids", []))



func shoreline(root: Node3D, key: Vector2i) -> void:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	var step_size = float(CHUNK) / STEPS
	var grid: PackedFloat64Array = surface_grids.get(key, PackedFloat64Array())
	for z in range(STEPS):
		for x in range(STEPS):
			var corners: Array[Vector3] = []
			for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var lx = (x + offset.x) * step_size
				var lz = (z + offset.y) * step_size
				var h: float = grid[(z + int(offset.y)) * (STEPS + 1) + x + int(offset.x)] if not grid.is_empty() else height_at(key.x * CHUNK + lx, key.y * CHUNK + lz)
				corners.append(Vector3(lx, h, lz))
			var crossings: Array[Vector3] = []
			for i in range(4):
				var a = corners[i]
				var b = corners[(i + 1) % 4]
				if (a.y < water_level) == (b.y < water_level):
					continue
				var point = a.lerp(b, (water_level - a.y) / (b.y - a.y))
				point.y = water_level + 0.045
				crossings.append(point)
			for i in range(0, crossings.size() - 1, 2):
				var a = crossings[i]
				var b = crossings[i + 1]
				var sideways = Vector3(-(b - a).z, 0, (b - a).x).normalized() * 0.38
				var at = vertices.size()
				vertices.append_array(PackedVector3Array([a - sideways, a + sideways, b - sideways, b + sideways]))
				normals.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
				uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]))
				indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
	if vertices.is_empty():
		return
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var shape = ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not art_materials.has("foam"):
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/shoreline.gdshader")
		art_materials.foam = material
	var foam = B.mesh(root, shape, art_materials.foam)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func flower_material() -> StandardMaterial3D:
	if not art_materials.has("flower"):
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.94
		art_materials.flower = material
	return art_materials.flower

func plant_instances(parent: Node3D, transforms: Array[Transform3D], shape: Mesh, material: Material) -> void:
	if transforms.is_empty():
		return
	B.instances(parent, transforms, shape, material)
	var batch = parent.get_child(parent.get_child_count() - 1) as MultiMeshInstance3D
	batch.add_to_group("world_detail")
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin = 0.22



	batch.visibility_range_end = [50.0, 65.0, 85.0][clampi(int(state.settings.quality), 0, 2)]
	batch.visibility_range_end_margin = 6.0

func shrine_ornaments(n: Node3D, id: String) -> void:
	var brass = B.mat("#b7a77c", 0.5)
	var light = B.mat("#b8e4d5" if id != "heart" else "#edd6a5", 0.2, 0.22)
	B.cyl(n, Vector3(0, 0.37, 0), 1.34, 0.12, stone_material(true))
	B.cyl(n, Vector3(0, 1.03, 0), 1.27, 0.14, brass)
	B.ring(n, Vector3(0, 2.5, -0.015), 1.12, 0.035, brass).rotation.x = PI / 2
	for i in range(8):
		var angle = float(i) / 8 * TAU
		var mark = B.beveled_box(n, Vector3(sin(angle) * 1.43, 2.5 + cos(angle) * 1.43, 0), Vector3(0.11, 0.28, 0.19), brass)
		mark.rotation.z = -angle
	for i in range(12):
		var angle = float(i) / 12 * TAU
		var rune = B.beveled_box(n, Vector3(sin(angle) * 2.5, 0.312, cos(angle) * 2.5), Vector3(0.12, 0.024, 0.34), light if i % 3 == 0 else brass)
		rune.rotation.y = angle
	for side in [-1, 1]:
		B.beveled_box(n, Vector3(side * 2.6, 0.18, 0.4), Vector3(0.9, 0.36, 0.9), stone_material(true))
		B.beveled_box(n, Vector3(side * 2.6, 3.14, 0.4), Vector3(0.85, 0.18, 0.85), stone_material(true))
		B.cyl(n, Vector3(side * 2.6, 1.0, 0.4), 0.38, 0.1, brass)
		B.cyl(n, Vector3(side * 2.6, 2.2, 0.4), 0.38, 0.1, brass)
		B.beveled_box(n, Vector3(side * 2.6, 1.7, 0.025), Vector3(0.13, 0.56, 0.05), brass)

func suspended_ring(index: int) -> void:
	var garden = Node3D.new()
	garden.name = "SuspendedGarden_%s" % index
	garden.position = Vector3(-92 + sin(index * 2.1) * 28, 17 + index * 3, -95 + cos(index * 2.1) * 20)
	add_child(garden)
	garden.add_to_group("static_art_root")
	var radius_value = 5.5 + index * 1.4
	var rotation_value = Vector3(0.8 + index * 0.31, index * 0.4, index * 0.3)
	var basis_value = Basis.from_euler(rotation_value)
	B.ring(garden, Vector3.ZERO, radius_value, 0.7, stone_material(true)).rotation = rotation_value
	B.ring(garden, Vector3.ZERO, radius_value - 0.76, 0.055, B.mat("#9c936c", 0.4)).rotation = rotation_value
	for i in range(10):
		var angle = float(i) / 10 * TAU
		var p = basis_value * Vector3(cos(angle) * radius_value, 0, sin(angle) * radius_value)
		var cap = B.beveled_box(garden, p, Vector3(0.48, 1.65, 0.42), stone_material(false))
		cap.basis = basis_value * Basis(Vector3.UP, -angle)
		cap.scale = Vector3(0.48, 1.65, 0.42)
		if i % 2 == 0:
			var inset = B.facet(garden, p + basis_value * Vector3(0, 0.87, 0), Vector3(0.18, 0.28, 0.18), B.mat("#b3d6bf", 0.15, 0.18))
			inset.basis = basis_value.scaled(Vector3(0.18, 0.28, 0.18))
	B.mesh(garden, leaf_mesh(), stone_material(false), Vector3(0, -5, 0), Vector3(2.65, 1.8, 2.25)).rotation.y = index * 0.7
	B.cyl(garden, Vector3(0, -4.15, 0), 1.52, 0.12, B.mat("#5d7950"))
	for side in [-1, 1]:
		var anchor = basis_value * Vector3(radius_value * side * 0.66, 0, -radius_value * 0.74)
		B.branch(garden, anchor, Vector3(side * 1.05, -4.55, 0), 0.045, B.mat("#8f8b69", 0.3), 0.8)
	for i in range(5):
		var angle = float(i) / 5 * TAU
		var start = Vector3(cos(angle) * 1.05, -4.75, sin(angle) * 0.95)
		var end = start + Vector3(sin(angle) * 0.6, -1.5 - (i % 3) * 0.65, cos(angle) * 0.3)
		B.branch(garden, start, end, 0.045, B.mat("#4e644b"), 0.25)
		for leaf in range(3):
			var p = start.lerp(end, float(leaf) / 3)
			B.mesh(garden, leaf_mesh(), B.mat("#647e52"), p, Vector3(0.35, 0.12, 0.24)).rotation.z = angle
		B.mesh(garden, fern_mesh(), foliage_material("#6e895c", true, 0.055), Vector3(cos(angle) * 0.9, -4.06, sin(angle) * 0.9))
		B.mesh(garden, flower_mesh(), flower_material(), Vector3(cos(angle) * 0.6, -4.05, sin(angle) * 0.6), Vector3.ONE * 0.9)
	B.facet(garden, Vector3(0, -7.1, 0), Vector3(0.42, 1.1, 0.42), crystal_material(0))
	B.batch_static(garden)
