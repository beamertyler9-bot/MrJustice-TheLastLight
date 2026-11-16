extends Node3D



const Enemy = preload("res://scripts/enemy.gd")
const Locations = preload("res://scripts/locations.gd")
const Creatures = preload("res://scripts/creature_catalog.gd")
const Lurker = preload("res://scripts/treeline_lurker.gd")
const MAX_ACTIVE := 8
const CELL_SIZE := 32.0
const SPAWN_RADIUS := 56.0
const RETIRE_RADIUS := 72.0
var game
var live: Dictionary = {}
var update_clock := 0.0
## The one Treeline Lurker that may be stalking Mr. Justice through Hollowmourn's woods.
var lurker: Node3D = null
var lurker_clock := 4.0

func setup(context) -> void:
	game = context
	name = "OutdoorEcology"
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(dt: float) -> void:
	if game == null or game.mode != "play" or not is_instance_valid(game.player) or not is_instance_valid(game.world): return
	if not _player_outdoors() or game.world.chunks.is_empty():
		_retire_all()
		_retire_lurker()
		return
	_tick_lurker(dt)


	for victim_id in live.keys():
		var actor = live[victim_id]
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.health <= 0:
			live.erase(victim_id)
		elif actor.home.distance_to(game.player.global_position) > RETIRE_RADIUS or not _loaded(actor.home) or not _loaded(actor.global_position):
			_retire(actor)
			live.erase(victim_id)
	update_clock -= dt
	if update_clock > 0 or get_child_count() >= MAX_ACTIVE: return
	update_clock = 0.85
	var candidates: Array[Dictionary] = []
	var p: Vector3 = game.player.global_position
	var cell := Vector2i(floori(p.x / CELL_SIZE), floori(p.z / CELL_SIZE))
	var world_seed: int = int(game.state.seed_value)
	for x in range(cell.x - 2, cell.x + 3):
		for z in range(cell.y - 2, cell.y + 3):
			var victim_id = "roam_%d_%d_%d" % [world_seed, x, z]
			if live.has(victim_id) or game.state.taken.has(victim_id): continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(victim_id)
			var point := Vector3((x + 0.5) * CELL_SIZE + rng.randf_range(-9, 9), 0, (z + 0.5) * CELL_SIZE + rng.randf_range(-9, 9))
			var distance := Vector2(point.x - p.x, point.z - p.z).length()
			if distance < 17.0 or distance > SPAWN_RADIUS: continue
			# Choco-Bar Crocs keep to S'morewood's cola: lying in the shallows or on the banks.
			var croc := _croc_spot(point, rng)
			if croc != Vector3.INF: point = croc
			elif not _habitable(point): continue
			point.y = _height(point) + 0.07
			var entry := {"id": victim_id, "point": point, "distance": distance}
			if croc != Vector3.INF: entry.species = "chocobar_croc"
			candidates.append(entry)
	candidates.sort_custom(func (a, b): return float(a.distance) < float(b.distance))
	var spawned := 0
	for candidate in candidates:
		if get_child_count() >= MAX_ACTIVE or spawned >= 2: break
		var actor = Enemy.new()
		actor.configure_species(str(candidate.get("species", species_at(candidate.point, candidate.id))))
		actor.game = game
		actor.id = candidate.id
		actor.name = candidate.id
		actor.position = candidate.point
		actor.home = candidate.point
		add_child(actor)
		live[candidate.id] = actor
		spawned += 1

func _player_outdoors() -> bool:
	var point: Vector3 = game.player.global_position
	if game.world.has_method("interior_at") and game.world.interior_at(point) != "": return false
	var surface := Vector2(point.x, point.z)
	if surface.length() < 30.0 or (game.world.reserved_at(surface, 2.0) if game.world.has_method("reserved_at") else Locations.reserved(surface, 2.0)): return false
	return point.y >= _height(point) - 3.0

func _height(point: Vector3) -> float:
	if game.world.has_method("surface_height_at"): return game.world.surface_height_at(point.x, point.z)
	return game.world.height_at(point.x, point.z)

func _loaded(point: Vector3) -> bool:
	var chunk_size: float = game.world.CHUNK
	return game.world.chunks.has(Vector2i(floori(point.x / chunk_size), floori(point.z / chunk_size)))

## For S'morewood only: when there is cola within sixteen metres of a spawn point, four times
## in five a Choco-Bar Croc takes it instead, moved to the bank just short of the cola (or, one
## time in three, into the shallows if they are under half a metre deep, where its back and
## eyes show above the surface). Returns the croc's spot, or Vector3.INF for none.
func _croc_spot(point: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var world = game.world
	if world.get("atlas") == null or not world.has_method("biome_at") or world.biome_at(point.x, point.z) != 10: return Vector3.INF
	var p := Vector2(point.x, point.z)
	if p.length() < 35.0 or not _loaded(point) or rng.randf() > 0.8: return Vector3.INF
	var start := rng.randf() * TAU
	for ring: float in [4.0, 8.0, 12.0, 16.0]:
		for i in range(8):
			var dir := Vector2.from_angle(start + i * TAU / 8.0)
			var q := p + dir * ring
			var near: Dictionary = world.atlas.liquid_at(q)
			if near.is_empty() or str(near.get("kind", "")) != "cola": continue
			if rng.randf() < 0.34:
				var wet := Vector3(q.x, 0, q.y)
				var depth := float(near.height) - _height(wet)
				if depth > 0.05 and depth < 0.5 and _loaded(wet) and not world.reserved_at(q, 4.0): return wet
			for back: float in [3.0, 5.0, 7.0]:
				var bank := Vector3(q.x - dir.x * back, 0, q.y - dir.y * back)
				if _habitable(bank): return bank
			return Vector3.INF
	return Vector3.INF

func _habitable(point: Vector3) -> bool:
	var p := Vector2(point.x, point.z)
	if p.length() < 35.0 or (game.world.reserved_at(p, 7.0) if game.world.has_method("reserved_at") else Locations.reserved(p, 7.0)) or not _loaded(point): return false
	if game.world.has_method("path_distance") and game.world.path_distance(p) < 3.2: return false
	var height := _height(point)
	if height < game.world.water_level + 0.7: return false
	if game.world.has_method("dry_surface_at") and not game.world.dry_surface_at(p, 0.6): return false
	for offset in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if not _loaded(point + offset) or absf(_height(point + offset) - height) > 1.0: return false
	var space = get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, height + 0.95, point.z))
	query.collision_mask = 1 | 4 | 8
	return space.intersect_shape(query, 1).is_empty()

func species_at(point: Vector3, victim_id: String) -> String:
	var region: int = game.world.biome_at(point.x, point.z)
	if game.world.get("atlas") != null:
		var regional: Array = Creatures.hostiles_for(region)
		if region == 9: regional.append("rootling_sentinel")
		regional.erase("chocobar_croc")
		# Now and then a "chest" lying out in the open is a Chest Mimic.
		if posmod(hash(victim_id + ":mimic"), 9) == 0: return "chest_mimic"
		return regional[posmod(hash(victim_id), regional.size())]
	var choices: Array
	match region:
		9: choices = ["moss_guardian", "rootling_sentinel", "thorn_wolf"]
		13: choices = ["cinder_wisp", "cinder_wisp", "glass_skitter"]
		14: choices = ["thorn_wolf", "frost_brute", "thorn_wolf"]
		15: choices = ["glass_skitter", "glass_skitter", "cinder_wisp"]
		1: choices = ["glass_skitter", "cinder_wisp", "thorn_wolf"]
		2: choices = ["thorn_wolf", "moss_guardian", "wild_boar"]
		3, 6: choices = ["wild_boar", "cinder_wisp", "moss_guardian"]
		4: choices = ["frost_brute", "thorn_wolf", "frost_brute"]
		5: choices = ["glass_skitter", "cinder_wisp", "wild_boar"]
		7: choices = ["wild_boar", "thorn_wolf", "moss_guardian"]
		8: choices = ["thorn_wolf", "frost_brute", "moss_guardian"]
		_: choices = ["moss_guardian", "wild_boar", "thorn_wolf"]
	return choices[posmod(hash(victim_id), choices.size())]

func _retire(actor: Node3D) -> void:
	actor.remove_from_group("enemy")
	remove_child(actor)
	actor.queue_free()

## Now and then while Mr. Justice is out in Hollowmourn, a Treeline Lurker starts stalking
## him; it leaves when he leaves the region or goes far from where it is.
func _tick_lurker(dt: float) -> void:
	if is_instance_valid(lurker):
		if not Lurker.hunting_ground(game) or lurker.global_position.distance_to(game.player.global_position) > Lurker.LEAVE_DISTANCE:
			_retire_lurker()
		return
	lurker_clock -= dt
	if lurker_clock > 0.0: return
	lurker_clock = 8.0
	if not Lurker.hunting_ground(game) or randf() > 0.35: return
	lurker = Lurker.new()
	game.add_child(lurker)
	lurker.setup(game)
	lurker.global_position = game.player.global_position

func _retire_lurker() -> void:
	if is_instance_valid(lurker): lurker.queue_free()
	lurker = null
	lurker_clock = 20.0

func _retire_all() -> void:
	for actor in get_children(): _retire(actor)
	live.clear()
	update_clock = 0.0
