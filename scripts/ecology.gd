extends Node3D



const Enemy = preload("res://scripts/enemy.gd")
const Locations = preload("res://scripts/locations.gd")
const Creatures = preload("res://scripts/creature_catalog.gd")
const MAX_ACTIVE := 8
const CELL_SIZE := 32.0
const SPAWN_RADIUS := 56.0
const RETIRE_RADIUS := 72.0
var game
var live: Dictionary = {}
var update_clock := 0.0

func setup(context) -> void:
	game = context
	name = "OutdoorEcology"
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(dt: float) -> void:
	if game == null or game.mode != "play" or not is_instance_valid(game.player) or not is_instance_valid(game.world): return
	if not _player_outdoors() or game.world.chunks.is_empty():
		_retire_all()
		return


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
			if distance < 17.0 or distance > SPAWN_RADIUS or not _habitable(point): continue
			point.y = _height(point) + 0.07
			candidates.append({"id": victim_id, "point": point, "distance": distance})
	candidates.sort_custom(func (a, b): return float(a.distance) < float(b.distance))
	var spawned := 0
	for candidate in candidates:
		if get_child_count() >= MAX_ACTIVE or spawned >= 2: break
		var actor = Enemy.new()
		actor.configure_species(species_at(candidate.point, candidate.id))
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

func _retire_all() -> void:
	for actor in get_children(): _retire(actor)
	live.clear()
	update_clock = 0.0
