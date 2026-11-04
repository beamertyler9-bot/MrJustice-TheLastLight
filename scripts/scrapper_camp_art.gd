extends RefCounted

const Stake = preload("res://assets/scrapper_camps/palisade_stake.res")
const O = preload("res://scripts/world_overhaul.gd")
const B = preload("res://scripts/build.gd")
const Crate = preload("res://scripts/scrapper_crate.gd")
const PARTS = ["ground", "walls", "gate", "platforms", "tents", "supplies", "props", "signals", "finish"]
static func build_part(root: Node3D, world, site: Dictionary, part: String) -> void:
	if part not in PARTS or root.has_meta("scrapper_part_" + part): return
	root.set_meta("scrapper_part_" + part, true)
	var style = str(site.get("layout", "stockade")); var variant = posmod(hash(str(site.get("id", "camp"))), 5)
	match part:
		"ground":

			for i in range(7):
				var at = Vector3(-4.6 + float(i % 3) * 2.1, 0, -11 + float(i / 3) * 1.1)
				var foot = _foot(root, world, "ScatteredSalvage", at)
				O.fit(foot, "resource_stone_chunks_small" if style == "quarry" else "resource_wood_planks_stack_small", Vector3.ZERO, Vector3(0.65, 0.12, 0.45), float(i) * 0.8)
		"walls": _walls(root, world, style)
		"gate":
			for side in [-1, 1]:
				var foot = _foot(root, world, "GatePost", Vector3(side * 3.5, 0, 14.4))
				O.fit(foot, "avra_allassets_with_texture_fence_wood_door_h_01", Vector3.ZERO, Vector3(1.0, 3.9, 0.65), PI * 0.5)

				var leaf = _prop(root, world, "OpenGateLeaf", "avra_allassets_with_texture_fence_wood_door_gate", Vector3(side * 4.1, 0, 15.3), Vector3(2.6, 2.5, 0.3), side * 1.14, true)
				leaf.set_meta("open_gate", true)
		"platforms":
			_platform(root, world, Vector3(-11, 0, -9.5) if style == "round" else Vector3(-11.8, 0, -10.8), style == "quarry")
			if style != "round": _platform(root, world, Vector3(11.8, 0, 10.3), false)
		"tents":
			var places = [Vector3(-7.8, 0, -10.3), Vector3(7.2, 0, -11), Vector3(-10.1, 0, 7.1), Vector3(8.8, 0, 5.5)]
			if style == "round": places = [Vector3(-8.3, 0, -10.3), Vector3(6.5, 0, -11.0), Vector3(-11, 0, 4.8), Vector3(9.3, 0, 5.4), Vector3(-6.5, 0, 10.6)]
			if style == "quarry": places = [Vector3(-7.8, 0, -11), Vector3(6.5, 0, -11.1), Vector3(-10.2, 0, 7.2)]
			for i in range(places.size()):
				var yaw = atan2(-places[i].x, -places[i].z)
				var foot = _prop(root, world, "CanvasShelter", "u29_survival_tent_canvas", places[i], Vector3(3.3, 2.5, 3.6), yaw, false)

				_support(foot, Vector3(0, 1.1, -1.3), Vector3(2.7, 2.2, 0.2))
				O.fit(foot, "u29_survival_bedroll", Vector3(0, 0.03, -0.5), Vector3(0.9, 0.2, 1.9))
		"supplies":
			for i in range(3):
				var id = "scrapper_crate_%s_%d" % [str(site.get("id", "camp")), i]
				if world != null and world.get("state") != null and world.state.taken.has("broken_" + id):
					Crate.retire_source(world, id); continue



				if not Crate.live_sources(world, id).is_empty(): continue
				var at = [Vector3(-10.2, 0, 1), Vector3(10.5, 0, 0.5), Vector3(-7.2, 0, 10.5)][i]
				var foot = _foot(root, world, "CrateSupply", at)
				var box = Crate.new(); box.position.y = 0.48; box.rotation.y = 0.18 + i * 0.4; box.configure(world, id); foot.add_child(box)
			_prop(root, world, "SalvageWagon", "qv_prop_wagon", Vector3(11.2, 0, -3.4), Vector3(2.0, 1.65, 3.2), 0.14, false)
			_prop(root, world, "TimberStack", "resource_wood_log_stack", Vector3(-12.2, 0, 0.2), Vector3(1.7, 1.1, 2.4), 0.25, true)
		"props":
			var fire = _prop(root, world, "FireCircle", "u29_survival_campfire_pit", Vector3(-2.8, 0, 1), Vector3(2.0, 0.35, 2.0), 0, false)
			B.flame(fire, Vector3(0, 0.48, 0), Vector3(0.48, 0.75, 0.48))
			for i in range(3):
				var at = Vector3(-2.8 + cos(float(i) * TAU / 3) * 2.1, 0, 1 + sin(float(i) * TAU / 3) * 2.1)
				_prop(root, world, "FireSeat", "u29_survival_tree_log_small", at, Vector3(1.4, 0.32, 0.38), -float(i) * TAU / 3, false)
			_prop(root, world, "RepairStation", "u29_survival_workbench_anvil", Vector3(10.6, 0, -8.2), Vector3(1.9, 1.1, 1.4), PI * 0.5, true)
			_prop(root, world, "ToolStack", "u29_survival_tool_axe", Vector3(-11.7, 0, 2.9), Vector3(0.5, 1.0, 0.22), 0.3, false)
			if style == "quarry":
				for i in range(2): _prop(root, world, "QuarrySpoil", "resource_stone_bricks_stack_small", Vector3(12.7, 0, -0.5 + float(i) * 1.4), Vector3(1.7, 0.5 + float(i % 2) * 0.25, 1.1), 0.12, true)
			elif int(site.get("region", 0)) in [5, 6]: _prop(root, world, "AshSalvage", "qnat_deadtree_1", Vector3(-13.2, 0, 10.5), Vector3(1.2, 3.2, 1.1), 0, false)
			else: _prop(root, world, "RopeCoil", "kaykit_rope_bundle_b", Vector3(9.8, 0, 8.5), Vector3(0.9, 0.18, 0.8), float(variant), false)
		"signals":
			for side in [-1, 1]:
				var pole = _foot(root, world, "ScrapperStandard", Vector3(side * 4.0, 0, 13.8))
				O.fit(pole, "qprop_banner_2", Vector3.ZERO, Vector3(0.95, 4.7, 0.25), PI if side < 0 else 0)
				var banner = O.fit(pole, "dungeon_banner_patterna_red", Vector3(0, 2.2, 0.13), Vector3(0.9, 1.6, 0.15))
				if banner: banner.set_meta("scrapper_colors", true)
		"finish":
			root.set_meta("scrapper_art", true); root.set_meta("camp_layout", style); root.set_meta("gate_clear_width", 5.6)
static func _foot(root: Node3D, world, label: String, at: Vector3) -> Node3D:
	var foot = Node3D.new(); foot.name = label; root.add_child(foot, true)
	var point = root.to_global(at)
	if world != null and world.has_method("surface_height_at"): point.y = world.surface_height_at(point.x, point.z)
	foot.position = root.to_local(point); foot.set_meta("ground_sample", true)
	return foot
static func _prop(root: Node3D, world, label: String, id: String, at: Vector3, size: Vector3, yaw: float, solid: bool) -> Node3D:
	var foot = _foot(root, world, label, at); foot.rotation.y = yaw
	var model = O.fit(foot, id, Vector3.ZERO, size)
	if model: O.structural(model)
	if solid: _support(foot, Vector3.UP * size.y * 0.5, size)
	return foot
static func _support(root: Node3D, at: Vector3, size: Vector3) -> void:
	var shape = BoxShape3D.new(); shape.size = size; B.solid(root, at, shape)
static func _walls(root: Node3D, world, style: String) -> void:
	var points = []; var stake_frames = []
	if style == "round":
		for i in range(25):
			var angle = 0.27 + float(i) * (TAU - 0.54) / 24
			points.append(Vector3(sin(angle) * 15, 0, cos(angle) * 15))
	elif style == "quarry": points = [Vector3(3.5, 0, 14), Vector3(11, 0, 14), Vector3(15, 0, 7), Vector3(14, 0, -3), Vector3(15, 0, -13), Vector3(0, 0, -15), Vector3(-14, 0, -13), Vector3(-15, 0, 0), Vector3(-13, 0, 14), Vector3(-3.5, 0, 14)]
	else: points = [Vector3(3.5, 0, 14), Vector3(14, 0, 14), Vector3(14, 0, -14), Vector3(-14, 0, -14), Vector3(-14, 0, 14), Vector3(-3.5, 0, 14)]
	for i in range(points.size() - 1):
		var start: Vector3 = points[i]; var end: Vector3 = points[i + 1]; var span = end - start; var count = ceili(span.length() / 3.2)
		for j in range(count):
			var at = start + span * (float(j) + 0.5) / float(count)
			var height = 2.8 + float((i + j) % 3) * 0.18
			_prop(root, world, "TimberStockade", "avra_allassets_with_texture_fence_wood_h_01", at, Vector3(span.length() / float(count) + 0.12, height, 0.48), atan2(-span.z, span.x), true)
		var stakes = ceili(span.length() / 0.36)
		for j in range(stakes):
			var at: Vector3 = start + span * (float(j) + 0.5) / float(stakes)
			var p = root.to_global(at)
			if world != null and world.has_method("surface_height_at"): p.y = world.surface_height_at(p.x, p.z)
			var frame = Transform3D(Basis(Vector3.UP, float(j) * 0.73).scaled(Vector3(1, 0.93 + float((i + j) % 5) * 0.035, 1)), root.to_local(p))
			stake_frames.append(frame)
	var stakes = _instances(root, "PalisadeStakes", Stake, stake_frames)
	stakes.material_override = B.world_surface("timber", "#65503b")
	_batch_panels(root)
static func _platform(root: Node3D, world, at: Vector3, quarry: bool) -> void:
	var foot = _foot(root, world, "WatchPlatform", at)
	var inward = PI if at.z > 0 else 0.0; foot.rotation.y = inward
	var rise = 1.65 if quarry else 2.0
	for x in [-1.3, 1.3]:
		for z in [-1.3, 1.3]: O.fit(foot, "avra_allassets_with_texture_fence_wood_door_h_01", Vector3(x, 0, z), Vector3(0.27, rise + 0.85, 0.28), PI * 0.5)
	O.fit(foot, "village_mdvl_village_floor_wood_01", Vector3(0, rise, 0), Vector3(3.2, 0.18, 3.2)); _support(foot, Vector3(0, rise, 0), Vector3(3.2, 0.22, 3.2))
	for x in [-1.5, 1.5]: O.fit(foot, "qv_prop_woodenfence_single", Vector3(x, rise, 0), Vector3(2.8, 0.85, 0.15), PI * 0.5)
	O.fit(foot, "qv_prop_woodenfence_single", Vector3(0, rise, -1.5), Vector3(2.8, 0.85, 0.15))
	var ramp = _foot(root, world, "AccessRamp", at + Vector3(0, 0, -4.0 if at.z > 0 else 4.0)); ramp.rotation.y = inward

	var top = foot.to_global(Vector3(0, rise, 1.5)); var delta = top.y - ramp.global_position.y
	var length = sqrt(5.0 * 5.0 + delta * delta); var slope = atan2(delta, 5.0)
	var deck = O.fit(ramp, "village_mdvl_village_floor_wood_01", Vector3(0, delta * 0.5, 0), Vector3(1.4, 0.15, length)); deck.rotation.x = slope
	var shape = BoxShape3D.new(); shape.size = Vector3(1.4, 0.15, length)
	var body = B.solid(ramp, Vector3(0, delta * 0.5, 0), shape); body.rotation.x = slope
	O.fit(foot, "avra_allassets_with_texture_ladder", Vector3(1.5, 0, 0.4), Vector3(0.6, rise + 0.3, 0.15), PI * 0.5)

static func _instances(root: Node3D, label: String, mesh: Mesh, frames: Array) -> MultiMeshInstance3D:
	var batch = MultiMeshInstance3D.new(); batch.name = label
	batch.multimesh = MultiMesh.new(); batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh; batch.multimesh.instance_count = frames.size()
	for i in range(frames.size()): batch.multimesh.set_instance_transform(i, frames[i])
	batch.set_meta("instance_transforms", frames); batch.set_meta("structural_art", true); root.add_child(batch)
	return batch
static func _batch_panels(root: Node3D) -> void:
	var frames = []; var mesh: Mesh; var material: Material
	var originals = []
	for panel in root.get_children():
		if not str(panel.name).begins_with("TimberStockade"): continue
		for visual in panel.find_children("*", "MeshInstance3D", true, false):
			mesh = visual.mesh; material = visual.material_override
			frames.append(root.global_transform.affine_inverse() * visual.global_transform); originals.append(visual)
	if frames.is_empty(): return
	var batch = _instances(root, "StockadePanels", mesh, frames); batch.material_override = material
	for visual in originals: visual.free()
