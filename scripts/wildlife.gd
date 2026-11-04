extends Node3D



const Motion = preload("res://scripts/creature_motion.gd")
const Actor = preload("res://scripts/wildlife_actor.gd")
const Models = preload("res://scripts/wildlife_models.gd")
const Locations = preload("res://scripts/locations.gd")
const Catalog = preload("res://scripts/creature_catalog.gd")
const RegionalModels = preload("res://scripts/regional_creature_models.gd")
const POOL_SPECIES = ["moth", "hare", "deer", "fox", "bird", "boar", "hare", "bird"]
const SPAWN_MIN = 18.0
const SPAWN_MAX = 82.0
const RETIRE_DISTANCE = 105.0
const NEAR_DISTANCE = 30.0
const MID_DISTANCE = 52.0
const MID_STEP = 0.1
const FAR_STEP = 0.2
var game
var clock: float = 0.0
var scatter_clock: float = 0.0
var rng = RandomNumberGenerator.new()
var critters: Array[Dictionary] = []
var current_region := -1
var deferred_population = false
var groups: Dictionary = {}

func setup(data, prepare_later: bool = false) -> void:
	game = data
	deferred_population = prepare_later

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	name = "Wildlife"
	rng.seed = 5190427
	if deferred_population: return
	if game != null and game.world.get("atlas") != null:
		var point = game.player.position if is_instance_valid(game.player) else game.world.get_spawn()
		_set_region(game.world.biome_at(point.x, point.z)); return
	for i in range(POOL_SPECIES.size()):
		_build_critter(POOL_SPECIES[i], i)

func populate_loading(report: Callable, draw: Callable) -> void:
	var species: Array = POOL_SPECIES.duplicate()
	if game.world.get("atlas") != null:
		var point: Vector3 = game.player.position
		current_region = game.world.biome_at(point.x, point.z)
		var choices = Catalog.wildlife_for(current_region); species = []
		for i in range(16): species.append(choices[i % choices.size()])
	for i in range(species.size()):
		var label = Catalog.entry(species[i]).get("name", Models.NAMES.get(species[i], species[i]))
		report.call("Wildlife %d/%d: %s" % [i + 1, species.size(), label])
		_build_critter(species[i], i)
		await draw.call()
	deferred_population = false

func _build_critter(species: String, index: int) -> void:
	var regional: bool = not Catalog.entry(species).is_empty()
	var flying: bool = Catalog.flying(species) if regional else species in ["moth", "bird"]
	var node := Actor.new()
	node.name = species.capitalize() + str(index)
	node.set_meta("species", species)
	node.set_meta("display_name", Catalog.entry(species).get("name", species) if regional else Models.NAMES[species])
	node.visible = false
	add_child(node)
	var body := Node3D.new()
	node.add_child(body)
	var visual: Dictionary = RegionalModels.wildlife(body, species) if regional else Models.build(body, species, index)
	var family: String = Catalog.entry(species).get("form", species)
	node.prepare(family, body)
	for mesh in node.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var prior = 0
	for critter in critters:
		if critter.species == species: prior += 1
	var group_id = species + "/" + str(prior / 3)
	if not groups.has(group_id): groups[group_id] = {"placed": false, "center": Vector3.ZERO, "phase": rng.randf() * TAU, "ordinal": groups.size()}
	critters.append({"node": node, "body": body, "body_rest": body.basis, "species": species, "family": family, "group": group_id, "member": prior % 3, "flying": flying, "flee": 0.0, "visual_rig": visual, "knees": visual.get("knees", []), "ears": visual.get("ears", []), "tails": visual.get("tails", []), "wings": visual.wings, "wing_meshes": visual.wing_meshes, "legs": visual.legs, "head": visual.head, "features": visual.features, "anchor": Vector3.ZERO, "placed": false, "elapsed": 0.0, "pose_phase": float(index % 16) / 16.0, "phase": rng.randf() * TAU})

func _set_region(region: int) -> void:
	if region == current_region: return
	for critter in critters:
		remove_child(critter.node); critter.node.queue_free()
	critters.clear(); groups.clear(); current_region = region
	var choices = Catalog.wildlife_for(region)
	for i in range(16): _build_critter(choices[i % choices.size()], i)

func _process(dt: float) -> void:
	if game == null or game.mode != "play" or not is_instance_valid(game.player) or not is_instance_valid(game.world):
		return
	if game.world.chunks.is_empty() or not _player_outdoors():
		_retire_all()
		return
	if game.world.get("atlas") != null: _set_region(game.world.biome_at(game.player.position.x, game.player.position.z))
	clock += dt
	scatter_clock -= dt
	var inspect_habitat = scatter_clock <= 0
	for critter in critters:
		var node = critter.node
		var anchor: Vector3 = critter.anchor
		var distance = _distance(anchor, game.player.global_position)
		var newly_visible = false
		if node.visible and (distance > RETIRE_DISTANCE or inspect_habitat and not _loaded_dry(anchor)):
			node.set_active(false)
		if not node.visible and inspect_habitat and not node.defeated:
			_scatter(critter)
			newly_visible = node.visible
			distance = _distance(critter.anchor, game.player.global_position)
		if node.visible:
			critter.elapsed = float(critter.elapsed) + dt
			var step = 0.0 if newly_visible or distance < NEAR_DISTANCE or node.hurt_timer > 0 or node.flee_timer > 0 or float(critter.flee) > 0 else MID_STEP if distance < MID_DISTANCE else FAR_STEP



			var due = step <= 0.0
			if step > 0.0: due = floori(clock / step + critter.pose_phase) != floori((clock - dt) / step + critter.pose_phase)
			if due:
				_animate_critter(critter, float(critter.elapsed)); critter.elapsed = 0.0
	if scatter_clock <= 0:
		scatter_clock = 0.65

func _loaded_dry(point: Vector3) -> bool:
	var world = game.world
	var key = Vector2i(floori(point.x / world.CHUNK), floori(point.z / world.CHUNK))
	if not world.chunks.has(key): return false
	if world.has_method("interior_at") and world.interior_at(_ground(point)) != "": return false
	if world.get("atlas") != null:
		return world.biome_at(point.x, point.z) == current_region and world.dry_surface_at(Vector2(point.x, point.z), 0.7) and not world.reserved_at(Vector2(point.x, point.z), 1.4)
	return _height(point) >= world.water_level + 0.35 and not Locations.reserved(Vector2(point.x, point.z), 1.4)

func _ground(point: Vector3) -> Vector3:
	return Vector3(point.x, _height(point) + 0.025, point.z)

func _near_player(radius: float, min_radius: float) -> Vector3:
	var angle = rng.randf() * TAU
	var distance = rng.randf_range(min_radius, radius)
	return _ground(game.player.global_position + Vector3(cos(angle), 0, sin(angle)) * distance)

func _scatter(critter: Dictionary) -> void:
	if critter.node.defeated or critter.family == "fish": return


	if bool(critter.placed) and _distance(critter.anchor, game.player.global_position) >= SPAWN_MIN and _distance(critter.anchor, game.player.global_position) <= RETIRE_DISTANCE and _loaded_dry(critter.anchor) and _placement_clear(critter.anchor, critter):
		critter.node.position = critter.anchor; critter.node.set_active(true); return
	var group: Dictionary = groups[critter.group]
	var live_group = false
	for other in critters:
		if other.group == critter.group and other.node.visible: live_group = true; break
	if not live_group and (not bool(group.placed) or _distance(group.center, game.player.global_position) > RETIRE_DISTANCE or _distance(group.center, game.player.global_position) < SPAWN_MIN or not _loaded_dry(group.center)):
		group.placed = false
	if not bool(group.placed):
		for attempt in range(32):


			var inner = int(group.ordinal) % 3 == 0 and attempt < 12
			var center = _near_player(35.0 if inner else SPAWN_MAX - 5.0, SPAWN_MIN + 5.0 if inner else 46.0)
			if not _loaded_dry(center): continue
			var clear = true
			for key in groups:
				if key != critter.group and bool(groups[key].placed) and _distance(center, groups[key].center) < 23.0: clear = false; break
			if clear: group.center = center; group.placed = true; break
	if not bool(group.placed): return
	for attempt in range(12):
		var angle = float(group.phase) + float(critter.member) * TAU / 3.0 + float(attempt) * 0.31
		var point: Vector3 = _ground(group.center + Vector3(cos(angle), 0, sin(angle)) * (3.8 + float(attempt / 4) * 0.7))
		if _distance(point, game.player.global_position) < SPAWN_MIN or _distance(point, game.player.global_position) > RETIRE_DISTANCE or not _loaded_dry(point) or not _placement_clear(point, critter): continue
		critter.anchor = point
		critter.placed = true
		critter.node.position = point
		critter.node.set_active(true)
		if critter.species == "moth":
			var region: int = clampi(game.world.biome_at(point.x, point.z), 0, 8)
			for mesh in critter.wing_meshes:
				mesh.material_override = Models.moth_wing_material(region)
		return

func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _placement_clear(point: Vector3, critter: Dictionary) -> bool:
	for other in critters:
		if other == critter or not other.node.visible: continue
		if _distance(point, other.anchor) < (2.8 if other.group == critter.group else 13.0): return false
	return true

func _animate_critter(critter: Dictionary, dt: float) -> void:
	var node = critter.node
	critter.body.basis = critter.body_rest
	if node.defeated:
		node.advance_reaction(dt)
		Motion.wildlife_pose(critter, clock, dt, 0.0, false)
		if not critter.flying: _align_ground(critter)
		critter.body.rotation.z += smoothstep(0.0, 0.55, node.defeat_time) * 1.2
		return
	var phase: float = critter.phase
	var anchor: Vector3 = critter.anchor
	var offset: Vector3 = node.position - game.player.global_position
	offset.y = 0
	var alert := 8.0 if critter.family in ["deer", "antelope", "goat"] else 5.0
	if critter.family in ["moth", "snail", "tortoise"]: alert = 2.0
	if offset.length() < alert: critter.flee = 2.4
	critter.flee = maxf(float(critter.flee), node.flee_timer)
	critter.flee = maxf(0.0, float(critter.flee) - dt)
	var fleeing: bool = float(critter.flee) > 0
	var movement := 0.0
	if fleeing:
		var direction := offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
		var speed := 4.0 if critter.family in ["deer", "antelope"] else 0.3 if critter.family in ["snail", "tortoise"] else 2.5
		if critter.flying: speed = 3.6
		var next: Vector3 = node.position + (direction * speed + node.recoil) * minf(dt, 0.25)
		if _loaded_dry(next):
			critter.anchor = _ground(next)
			anchor = critter.anchor
			node.position = anchor
			movement = 1.0
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-dt * 8.0))
	if critter.flying:
		var bird: bool = critter.family in ["bird", "crane", "manta"]
		var orbit = anchor + Vector3(cos(clock * 0.65 + phase), 0, sin(clock * 0.8 + phase)) * (1.5 if bird else 0.85)
		if fleeing or not _loaded_dry(orbit): orbit = anchor
		var altitude := 2.4 if bird else 1.1
		if fleeing: altitude += 0.7
		node.position = _ground(orbit) + Vector3.UP * (altitude + sin(clock * 2.4 + phase) * 0.2)
		if not fleeing: node.rotation.y = -clock * 0.65 - phase
	else:

		var stroll := not fleeing and sin(clock * 0.38 + phase) > 0.5
		if stroll:
			var next = anchor + Vector3(sin(clock * 0.5 + phase), 0, cos(clock * 0.5 + phase)) * 0.35
			if _loaded_dry(next):
				node.position = _ground(next)
				movement = 0.3
				node.rotation.y = lerp_angle(node.rotation.y, -clock * 0.5 - phase, 1.0 - exp(-dt * 3.0))
		else: node.position = _ground(anchor)
	Motion.wildlife_pose(critter, clock, dt, movement, fleeing)
	if not critter.flying: _align_ground(critter)
	node.advance_reaction(dt)
	var hurt = sin(PI * clampf(1.0 - node.hurt_timer / Actor.HURT_DURATION, 0.0, 1.0)) if node.hurt_timer > 0 else 0.0
	critter.body.rotation.z += node.flinch_side * hurt * 0.32
	critter.body.rotation.x -= hurt * (0.1 if critter.family in ["snail", "tortoise"] else 0.23)
	critter.body.position.y -= hurt * 0.045
	if critter.head != null: critter.head.rotation.x -= hurt * 0.3

func _align_ground(critter: Dictionary) -> void:
	var node: Node3D = critter.node
	var p := node.position


	var normal := Vector3(_height(p - Vector3.RIGHT * 0.35) - _height(p + Vector3.RIGHT * 0.35), 0.7, _height(p - Vector3.BACK * 0.35) - _height(p + Vector3.BACK * 0.35)).normalized()
	normal = (node.basis.inverse() * normal).normalized()
	var right := Vector3.FORWARD.cross(normal).normalized()
	var forward := normal.cross(right).normalized()
	var stretch: Vector3 = critter.body.scale
	critter.body.basis = Basis(right, normal, -forward)
	critter.body.scale = stretch

func _height(point: Vector3) -> float:
	if game.world.has_method("surface_height_at"): return game.world.surface_height_at(point.x, point.z)
	return game.world.height_at(point.x, point.z)

func _player_outdoors() -> bool:
	var point: Vector3 = game.player.global_position
	if game.world.has_method("interior_at") and game.world.interior_at(point) != "": return false
	return point.y >= _height(point) - 3.0

func _retire_all() -> void:
	for critter in critters:
		critter.node.set_active(false)
