extends RefCounted


const O = preload("res://scripts/world_overhaul.gd")
const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/imported_assets.gd")
const Crate = preload("res://scripts/scrapper_crate.gd")
const Stake = preload("res://assets/scrapper_camps/palisade_stake.res")


const FOOTPRINT := Rect2(-48, -64, 96, 128)
const PARTS = ["wall_front_l", "wall_front_r", "wall_left_front", "wall_left_rear", "wall_right_front", "wall_right_rear", "wall_rear_l", "wall_rear_r", "tower_l_front", "tower_l_mid", "tower_l_rear", "tower_r_front", "tower_r_mid", "tower_r_rear", "boss_deck", "boss_access", "gate", "barracks_l", "barracks_r", "workshop", "drone_yard", "supplies_l", "supplies_r", "finish"]
static func parts() -> Array: return PARTS.duplicate()
static func build_part(root: Node3D, world, site: Dictionary, part: String) -> void:
	if part not in PARTS or root.has_meta("stronghold_part_" + part): return
	var group = Node3D.new(); group.name = "StrongholdPart_" + part; root.add_child(group)
	match part:
		"wall_front_l": _wall(group, world, Vector3(-46, 0, 62), Vector3(-7, 0, 62))
		"wall_front_r": _wall(group, world, Vector3(7, 0, 62), Vector3(46, 0, 62))
		"wall_left_front": _wall(group, world, Vector3(-46, 0, 62), Vector3(-46, 0, 0))
		"wall_left_rear": _wall(group, world, Vector3(-46, 0, 0), Vector3(-46, 0, -62))
		"wall_right_front": _wall(group, world, Vector3(46, 0, 62), Vector3(46, 0, 0))
		"wall_right_rear": _wall(group, world, Vector3(46, 0, 0), Vector3(46, 0, -62))
		"wall_rear_l": _wall(group, world, Vector3(-46, 0, -62), Vector3(0, 0, -62))
		"wall_rear_r": _wall(group, world, Vector3(0, 0, -62), Vector3(46, 0, -62))
		"tower_l_front": _tower_and_walk(group, world, -1, 50)
		"tower_l_mid": _tower_and_walk(group, world, -1, 0)
		"tower_l_rear": _tower_and_walk(group, world, -1, -50)
		"tower_r_front": _tower_and_walk(group, world, 1, 50)
		"tower_r_mid": _tower_and_walk(group, world, 1, 0)
		"tower_r_rear": _tower_and_walk(group, world, 1, -50)
		"boss_deck": _boss_deck(group, world)
		"boss_access": _ramp(group, world, "AccessRampBoss", Vector3(0, 0, -29), Vector3(0, 0, -43), 8.8, _ground_y(group, world, Vector3(0, 0, -52)) + 2.0)
		"gate": _gate(group, world)
		"barracks_l": _barracks(group, world, -1)
		"barracks_r": _barracks(group, world, 1)
		"workshop": _workshop(group, world)
		"drone_yard": _drone_yard(group, world)
		"supplies_l": _supplies(group, world, site, -1)
		"supplies_r": _supplies(group, world, site, 1)
		"finish":
			root.set_meta("scrapper_art", true); root.set_meta("camp_layout", "stronghold"); root.set_meta("gate_clear_width", 12.4)
	root.set_meta("stronghold_part_" + part, true)
static func boss_spawn(world, site: Dictionary) -> Vector3:
	var origin: Vector3 = site.get("point", Vector3(float(site.get("pos", Vector2.ZERO).x), 0, float(site.get("pos", Vector2.ZERO).y)))
	var point = origin + Basis(Vector3.UP, float(site.get("heading", 0))) * Vector3(0, 0, -52)
	point.y = world.surface_height_at(point.x, point.z) + 2.04 if world != null and world.has_method("surface_height_at") else origin.y + 2.04
	return point
static func _ground_y(root: Node3D, world, at: Vector3) -> float:
	var p = root.to_global(at)
	return float(world.surface_height_at(p.x, p.z)) if world != null and world.has_method("surface_height_at") else p.y
static func _foot(root: Node3D, world, label: String, at: Vector3) -> Node3D:
	var foot = Node3D.new(); foot.name = label; root.add_child(foot, true)
	var point = root.to_global(at); point.y = _ground_y(root, world, at)
	foot.position = root.to_local(point); foot.set_meta("ground_sample", true)
	return foot
static func _support(root: Node3D, at: Vector3, size: Vector3, walk: bool = false, terrain: bool = false) -> StaticBody3D:
	var shape = BoxShape3D.new(); shape.size = size; var body = B.solid(root, at, shape)
	var collision: CollisionShape3D = body.get_child(0)
	if walk: collision.set_meta("walk_surface", true)
	if terrain: collision.set_meta("terrain_support", true)
	return body
static func _prop(root: Node3D, world, label: String, id: String, at: Vector3, size: Vector3, yaw: float = 0, solid: bool = false) -> Node3D:
	var foot = _foot(root, world, label, at); foot.rotation.y = yaw
	var model = O.fit(foot, id, Vector3.ZERO, size)
	if model:
		O.structural(model)
		if id.begins_with("avra_allassets_with_texture_fence_wood"): _weathered(model)
	if solid: _support(foot, Vector3(0, size.y * 0.5 - 0.08, 0), Vector3(size.x, size.y + 0.16, size.z))
	return foot
static func _timber() -> Material: return B.world_surface("timber", "#6d5640")
static func _weathered(model: Node3D) -> void:
	if model == null: return
	O.structural(model)
	for visual in model.find_children("*", "MeshInstance3D", true, false): visual.material_override = _timber()
static func _post(root: Node3D, world, at: Vector3, top_y: float, width: float = 0.32, label: String = "TimberSupport") -> void:
	var ground = _ground_y(root, world, at)
	if top_y <= ground: return
	var foot = _foot(root, world, label, at); var height = top_y - ground + 0.08
	B.box(foot, Vector3(0, height * 0.5 - 0.08, 0), Vector3(width, height, width), _timber())
	_support(foot, Vector3(0, height * 0.5 - 0.08, 0), Vector3(width, height, width), false, true)
static func _wall(root: Node3D, world, start: Vector3, end: Vector3) -> void:
	var span = end - start; var count = ceili(span.length() / 3.0); var frames = []; var stakes = []
	var yaw = atan2(-span.z, span.x); var panel_mesh = A.mesh("avra_allassets_with_texture_fence_wood_h_01")
	for i in range(count):
		var at = start + span * (float(i) + 0.5) / float(count); var size = Vector3(span.length() / float(count) + 0.1, 4.8, 0.55)
		var foot = _prop(root, world, "TimberStockade", "avra_allassets_with_texture_fence_wood_h_01", at, size, yaw, false)
		_support(foot, Vector3(0, 2.2, 0), Vector3(size.x, 5.2, 0.55))
		var model: Node3D = foot.get_child(0); var visual: MeshInstance3D = model.get_child(0)
		frames.append(root.global_transform.affine_inverse() * visual.global_transform); visual.free()
	var number = ceili(span.length() / 0.42)
	for i in range(number):
		var at = start + span * (float(i) + 0.5) / float(number); var p = root.to_global(at); p.y = _ground_y(root, world, at)
		stakes.append(Transform3D(Basis(Vector3.UP, float(i) * 0.73).scaled(Vector3(1, 1.58 + float(i % 5) * 0.035, 1)), root.to_local(p)))
	var panels = _batch(root, "StockadePanels", panel_mesh, frames); panels.material_override = _timber()
	var tips = _batch(root, "PalisadeStakes", Stake, stakes); tips.material_override = _timber()
static func _yard_fence(root: Node3D, world, start: Vector3, end: Vector3) -> void:
	var span = end - start; var count = ceili(span.length() / 3.0); var frames = []; var yaw = atan2(-span.z, span.x)
	for i in range(count):
		var at = start + span * (float(i) + 0.5) / float(count)
		var foot = _prop(root, world, "YardDivider", "avra_allassets_with_texture_fence_wood_h_01", at, Vector3(span.length() / float(count) + 0.08, 2.2, 0.35), yaw, true)
		foot.set_meta("yard_divider", true)
		var visual: MeshInstance3D = foot.get_child(0).get_child(0)
		frames.append(root.global_transform.affine_inverse() * visual.global_transform); visual.free()
	var panels = _batch(root, "YardDividerPanels", A.mesh("avra_allassets_with_texture_fence_wood_h_01"), frames); panels.material_override = _timber()
static func _batch(root: Node3D, label: String, mesh: Mesh, frames: Array) -> MultiMeshInstance3D:
	var batch = MultiMeshInstance3D.new(); batch.name = label; batch.multimesh = MultiMesh.new(); batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh; batch.multimesh.instance_count = frames.size()
	for i in range(frames.size()): batch.multimesh.set_instance_transform(i, frames[i])
	batch.set_meta("instance_transforms", frames); batch.set_meta("structural_art", true); root.add_child(batch)
	return batch
static func _plank(root: Node3D, label: String, at: Vector3, width: float, depth: float, thickness: float = 0.22) -> Node3D:
	var floor_node = Node3D.new(); floor_node.name = label; floor_node.position = at; root.add_child(floor_node, true)
	var model = O.fit(floor_node, "village_mdvl_village_floor_wood_01", Vector3(0, -thickness, 0), Vector3(width, thickness, depth))
	_weathered(model)
	_support(floor_node, Vector3(0, -thickness * 0.5, 0), Vector3(width, thickness, depth), true)
	return floor_node
static func _rail(root: Node3D, at: Vector3, width: float, yaw: float = 0) -> void:
	var model = O.fit(root, "qv_prop_woodenfence_single", at, Vector3(width, 1.05, 0.2), yaw)
	_weathered(model)
	var barrier = _support(root, at + Vector3.UP * 0.525, Vector3(width, 1.05, 0.2)); barrier.rotation.y = yaw; barrier.set_meta("safety_rail", true)
static func _tower_top(root: Node3D, world, side: int, z: float) -> float: return _ground_y(root, world, Vector3(side * 42, 0, z)) + 5.2
static func _walk_top(root: Node3D, world, side: int, z: float) -> float:
	if z >= 0: return lerpf(_tower_top(root, world, side, 0), _tower_top(root, world, side, 50), z / 50.0)
	return lerpf(_tower_top(root, world, side, 0), _tower_top(root, world, side, -50), -z / 50.0)
static func _tower_and_walk(root: Node3D, world, side: int, z: float) -> void:
	var center = Vector3(side * 42, 0, z); var foot = _foot(root, world, "WatchPlatform", center); var top = 5.2
	_plank(foot, "TowerFloor", Vector3(0, top, 0), 6, 6)
	for x in [-2.6, 2.6]:
		for dz in [-2.6, 2.6]: _post(root, world, center + Vector3(x, 0, dz), foot.global_position.y + top + 2.45, 0.38, "TowerPost")
	_rail(foot, Vector3(side * 2.85, top, 0), 5.6, PI * 0.5)
	for dz in [-2.15, 2.15]: _rail(foot, Vector3(-side * 2.85, top, dz), 1.3, PI * 0.5)

	for dx in [-2.15, 2.15]: _rail(foot, Vector3(dx, top, 2.85), 1.25)
	var roof = O.fit(foot, "u29_survival_structure_roof", Vector3(0, top + 2.4, 0), Vector3(6.7, 1.75, 6.7))
	_weathered(roof)
	_prop(foot, world, "TowerLadder", "avra_allassets_with_texture_ladder", Vector3(-side * 2.8, 0, -1.9), Vector3(0.8, top + 0.6, 0.22), side * PI * 0.5)
	var flag = O.fit(foot, "dungeon_banner_patterna_red", Vector3(0, top + 0.8, 3.08), Vector3(1.1, 1.6, 0.15))
	if flag: O.structural(flag)
	var spans = [Vector2(25, 47.15)] if z == 50 else ([Vector2(-47.15, -25)] if z == -50 else [Vector2(-25, -2.85), Vector2(2.85, 25)])


	for span in spans:
		var count = ceili((span.y - span.x) / 4.0)
		for i in range(count):
			var a = lerpf(span.x, span.y, float(i) / float(count)); var b = lerpf(span.x, span.y, float(i + 1) / float(count))
			var mid = (a + b) * 0.5; var world_y = _walk_top(root, world, side, mid)
			var at = Vector3(side * 42, 0, mid); var p = root.to_global(at); p.y = world_y
			var delta = _walk_top(root, world, side, a) - _walk_top(root, world, side, b)
			var length = sqrt((b - a) * (b - a) + delta * delta)
			var walk = _plank(root, "Catwalk", root.to_local(p), 2.7, length + 0.08)

			walk.rotation.x = atan2(delta, b - a)
			for dx in [-1.22, 1.22]:
				_rail(walk, Vector3(dx, 0, 0), length + 0.05, PI * 0.5)
				_post(root, world, at + Vector3(dx, 0, 0), world_y - 0.22, 0.24, "CatwalkPost")
	if z == 0: _ramp(root, world, "AccessRampTower", Vector3(side * 26, 0, 0), Vector3(side * 39, 0, 0), 2.6, foot.global_position.y + top)
static func _ramp(root: Node3D, world, label: String, start: Vector3, end: Vector3, width: float, top_y: float) -> void:
	var ramp = _foot(root, world, label, start); var direction = end - start; direction.y = 0
	var distance = direction.length(); var yaw = atan2(-direction.x, -direction.z); ramp.rotation.y = yaw
	var high = top_y - ramp.global_position.y; var low = 0.015



	var rise = high - low; var slope = atan2(rise, distance); var thickness = 0.22; var normal = Basis(Vector3.RIGHT, slope) * Vector3.UP
	var frame = Node3D.new(); frame.name = "RampFloor"; ramp.add_child(frame); frame.position = Vector3(0, (high + low) * 0.5, -distance * 0.5) - normal * thickness * 0.5; frame.rotation.x = slope
	var model = O.fit(frame, "village_mdvl_village_floor_wood_01", Vector3(0, -thickness * 0.5, 0), Vector3(width, thickness, sqrt(distance * distance + rise * rise)))
	_weathered(model)
	_support(frame, Vector3.ZERO, Vector3(width, thickness, sqrt(distance * distance + rise * rise)), true)
	for t in [0.2, 0.45, 0.7, 0.95]:
		for side in [-1, 1]:
			var support = frame.to_global(Vector3(side * (width * 0.5 - 0.24), -thickness * 0.5, (0.5 - t) * sqrt(distance * distance + rise * rise)))
			_post(root, world, root.to_local(support), support.y, 0.25, "RampPost")
static func _boss_deck(root: Node3D, world) -> void:
	var foot = _foot(root, world, "BossDeck", Vector3(0, 0, -52)); var top = 2.0; var thickness = 0.24
	for ix in range(4):
		for iz in range(3):
			var model = O.fit(foot, "village_mdvl_village_floor_wood_01", Vector3(-9.75 + ix * 6.5, top - thickness, -6 + iz * 6), Vector3(6.5, thickness, 6))
			_weathered(model)
	_support(foot, Vector3(0, top - thickness * 0.5, 0), Vector3(26, thickness, 18), true)
	for x in [-11.5, -5.75, 0, 5.75, 11.5]:
		for z in [-7.5, 0, 7.5]: _post(root, world, Vector3(x, 0, -52 + z), foot.global_position.y + top - thickness, 0.46, "BossDeckPost")
	for z in [-7.5, 0, 7.5]: B.box(foot, Vector3(0, top - 0.48, z), Vector3(25, 0.48, 0.42), _timber())
	for side in [-1, 1]:
		_rail(foot, Vector3(side * 12.9, top, -0.2), 17.4, PI * 0.5)
		var pole = Vector3(side * 12.4, top, -7.6)
		B.box(foot, pole + Vector3.UP * 2.2, Vector3(0.3, 4.4, 0.3), _timber())
		O.fit(foot, "dungeon_banner_patterna_red", pole + Vector3(0, 2.25, 0.16), Vector3(1.25, 2.0, 0.15))
		_speaker_stack(foot, Vector3(side * 10, top, -4.6), side)
	_rail(foot, Vector3(0, top, -8.8), 24.9)
	var console = O.fit(foot, "qprop_table_large", Vector3(-5, top, -6.6), Vector3(3.2, 1.05, 1.7)); _weathered(console)
	_support(foot, Vector3(-5, top + 0.55, -6.6), Vector3(3.2, 1.1, 1.7))
	O.fit(foot, "qprop_bucket_metal", Vector3(-4.5, top + 1.05, -6.6), Vector3(0.75, 0.8, 0.75))


	for side in [-1, 1]:
		B.branch(foot, Vector3(side * 11.5, 0.15, -7.5), Vector3(side * 11.5, top - 0.3, 0), 0.12, _timber(), 1)
		B.branch(foot, Vector3(side * 11.5, 0.15, 0), Vector3(side * 11.5, top - 0.3, 7.5), 0.12, _timber(), 1)
static func _speaker_stack(root: Node3D, at: Vector3, side: int) -> void:
	var steel = B.world_surface("metal", "#55545e", 0.35); var dark = B.mat("#26252c"); var purple = B.mat("#776092", 0.3)
	var stack = Node3D.new(); stack.name = "SalvagedSpeakerStack"; stack.position = at; root.add_child(stack, true)
	O.fit(stack, "qprop_crate_metal", Vector3.ZERO, Vector3(2.2, 0.62, 1.65))
	for row in range(2):
		var y = 0.62 + row * 1.38
		B.box(stack, Vector3(0, y + 0.69, 0), Vector3(1.9, 1.38, 1.35), steel)
		_support(stack, Vector3(0, y + 0.69, 0), Vector3(1.9, 1.38, 1.35))
		var cone = B.cyl(stack, Vector3(0, y + 0.7, 0.71), 0.51, 0.12, dark); cone.rotation.x = PI * 0.5
		var rim = B.ring(stack, Vector3(0, y + 0.7, 0.79), 0.51, 0.045, steel); rim.rotation.x = PI * 0.5
		B.box(stack, Vector3(side * 0.83, y + 0.7, 0.74), Vector3(0.08, 0.85, 0.06), purple)
	B.branch(stack, Vector3(side * 0.72, 0.18, 0.82), Vector3(side * 0.87, 2.85, 0.66), 0.035, purple, 1)
	for dx in [-1, 1]:
		B.branch(stack, Vector3(dx * 0.98, 0.72, -0.56), Vector3(dx * 0.98, 3.25, 0.56), 0.075, _timber(), 1)
		B.box(stack, Vector3(dx * 0.98, 0.72, 0), Vector3(0.13, 0.16, 1.4), _timber())
	O.fit(stack, "kaykit_bucket_metal", Vector3(side * 0.52, 3.38, 0), Vector3(0.75, 0.63, 0.75))
static func _gate(root: Node3D, world) -> void:
	var posts = []
	for side in [-1, 1]:
		var foot = _prop(root, world, "GatePost", "avra_allassets_with_texture_fence_wood_door_h_01", Vector3(side * 6.9, 0, 62), Vector3(0.75, 7.0, 0.85), PI * 0.5, true); posts.append(foot)
		var leaf = _prop(root, world, "OpenGateLeaf", "avra_allassets_with_texture_fence_wood_door_gate", Vector3(side * 9.2, 0, 60.1), Vector3(4.5, 4.7, 0.4), side * 1.24, true); leaf.set_meta("open_gate", true)
		var flag = _prop(root, world, "GateStandard", "qprop_banner_2", Vector3(side * 8.6, 0, 62.3), Vector3(1.8, 7.3, 0.35))
		O.fit(flag, "dungeon_banner_patterna_red", Vector3(0, 3.5, 0.2), Vector3(1.6, 2.7, 0.18))

	var top = maxf(posts[0].global_position.y, posts[1].global_position.y) + 6.3
	var p = root.to_global(Vector3(0, 0, 62)); p.y = top
	B.box(root, root.to_local(p), Vector3(14.7, 0.52, 0.85), _timber(), true)
static func _barracks(root: Node3D, world, side: int) -> void:
	for z in [40, 6]: _yard_fence(root, world, Vector3(side * 14, 0, z), Vector3(side * 40, 0, z))
	var places = [Vector3(side * 23, 0, 35), Vector3(side * 35, 0, 30), Vector3(side * 23, 0, 17), Vector3(side * 35, 0, 13)]
	for at in places:
		var shelter = _prop(root, world, "CanvasShelter", "u29_survival_tent_canvas", at, Vector3(6.3, 4.1, 6.7), -side * PI * 0.5)
		_support(shelter, Vector3(0, 1.35, -2.5), Vector3(5.1, 2.7, 0.24))
		for dx in [-1.25, 1.25]: _prop(shelter, world, "Bedroll", "u29_survival_bedroll", Vector3(dx, 0, -0.6), Vector3(1.25, 0.23, 2.5))
	var fire = _prop(root, world, "BarracksFire", "u29_survival_campfire_pit", Vector3(side * 28, 0, 24), Vector3(2.6, 0.42, 2.6))
	B.flame(fire, Vector3(0, 0.75, 0), Vector3(0.6, 1.1, 0.6))
	for z in [20, 27.7]: _prop(root, world, "FireSeat", "u29_survival_tree_log_small", Vector3(side * 28, 0, z), Vector3(3.1, 0.45, 0.6))
	_prop(root, world, "TimberStores", "resource_wood_log_stack", Vector3(side * 37, 0, 40), Vector3(4.8, 2.4, 5.5), 0.15, true)
static func _awning(root: Node3D, world, center: Vector3, width: float, depth: float) -> Node3D:
	var foot = _foot(root, world, "SalvageWorkshopAwning", center); var top = foot.global_position.y + 3.8
	for dx in [-width * 0.45, width * 0.45]:
		for dz in [-depth * 0.43, depth * 0.43]: _post(root, world, center + Vector3(dx, 0, dz), top, 0.32, "WorkshopPost")
	var roof = O.fit(foot, "u29_survival_structure_roof", Vector3(0, 3.72, 0), Vector3(width, 1.5, depth))
	_weathered(roof)
	return foot
static func _workshop(root: Node3D, world) -> void:
	_yard_fence(root, world, Vector3(-40, 0, -27), Vector3(-20, 0, -27))
	_awning(root, world, Vector3(-28, 0, -12), 15.5, 12.5)
	for at in [Vector3(-32, 0, -14), Vector3(-24, 0, -14)]: _prop(root, world, "RepairStation", "u29_survival_workbench_anvil", at, Vector3(3.2, 1.8, 2.5), PI, true)
	_prop(root, world, "Grindstone", "u29_survival_workbench_grind", Vector3(-35, 0, -7), Vector3(2.4, 1.8, 2.2), PI * 0.5, true)
	_prop(root, world, "QuarryBlocks", "resource_stone_bricks_stack_small", Vector3(-35, 0, -22), Vector3(5, 1.4, 3), 0.12, true)
	_prop(root, world, "PlankStores", "resource_wood_planks_stack_small", Vector3(-24, 0, -22), Vector3(5.2, 1.2, 3.6), -0.12, true)
	for i in range(3): _prop(root, world, "SalvageBarrel", "qprop_barrel", Vector3(-35 + i * 2.1, 0, -2.5), Vector3(1.5, 1.8, 1.5), float(i) * 0.7, true)
static func _drone_yard(root: Node3D, world) -> void:
	_yard_fence(root, world, Vector3(20, 0, -27), Vector3(40, 0, -27))
	_awning(root, world, Vector3(29, 0, -12), 16, 12)
	var metal = B.world_surface("metal", "#55535d", 0.4); var purple = B.mat("#80639a", 0.3)
	for x in [23, 34]:
		var bay = _foot(root, world, "DroneRepairBay", Vector3(x, 0, -12))


		for side in [-1, 1]:
			for dz in [-1.7, 1.7]: _post(root, world, Vector3(x + side * 1.35, 0, -12 + dz), bay.global_position.y + 0.8, 0.35, "DroneBayPost")
			B.box(bay, Vector3(side * 1.35, 0.7, 0), Vector3(0.35, 0.2, 3.8), metal, true)
		B.box(bay, Vector3(0, 0.85, 0), Vector3(3.2, 0.2, 3.8), metal, true)
		for dx in [-1.0, 0, 1.0]: B.cyl(bay, Vector3(dx, 1.19, 1.15), 0.27, 0.5, purple)
		O.fit(bay, "qprop_bucket_metal", Vector3(0.65, 0.95, -0.8), Vector3(1.3, 1.1, 1.3))
		O.fit(bay, "u29_survival_tool_hammer", Vector3(-0.9, 0.98, -0.9), Vector3(0.7, 0.6, 0.3))
	_prop(root, world, "MachineSalvage", "qprop_crate_metal", Vector3(36, 0, -22), Vector3(4, 1.8, 3), 0.08, true)
	_prop(root, world, "SalvageWagon", "qv_prop_wagon", Vector3(24, 0, -23), Vector3(4.2, 2.7, 5.8), -0.18, true)
static func _supplies(root: Node3D, world, site: Dictionary, side: int) -> void:
	for i in range(7):
		var index = i + (7 if side > 0 else 0); var id = "scrapper_crate_%s_%d" % [str(site.get("id", "dissonance_stronghold")), index]
		if world != null and world.get("state") != null and world.state.taken.has("broken_" + id): Crate.retire_source(world, id); continue
		if not Crate.live_sources(world, id).is_empty(): continue
		var at = Vector3(side * 26 + float(i % 3) * 2.6 - 2.6, 0, 44 + float(i / 3) * 3.0)
		var foot = _foot(root, world, "CrateSupply", at); var box = Crate.new(); box.position.y = 0.48; box.rotation.y = 0.18 + float(i) * 0.4; box.configure(world, id); foot.add_child(box)
	_prop(root, world, "SupplyWagon", "qv_prop_wagon", Vector3(side * 17, 0, 49), Vector3(3.2, 2.3, 5.2), side * 0.14, true)
	_prop(root, world, "SupplyTimbers", "resource_wood_log_stack", Vector3(side * 35, 0, 51), Vector3(4, 2.2, 5.4), side * 0.1, true)
	_prop(root, world, "QuarrySpoil", "resource_stone_chunks_small", Vector3(side * 36, 0, 58), Vector3(4, 0.7, 3), side * 0.23, true)
