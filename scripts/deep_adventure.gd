extends RefCounted

const Treasure = preload("res://scripts/treasure_loot.gd")
const B = preload("res://scripts/build.gd")
const Boss = preload("res://scripts/deep_boss.gd")
const Trap = preload("res://scripts/deep_trap.gd")
const SEALS = ["deep_seal_ember", "deep_seal_echo", "deep_seal_tide"]
const CAVE_REWARD = {"ancient_core": 2, "crystal": 8, "iron": 12, "tonic": 3, "shard": 60}
var game
var encounter_root: Node3D
var traps: Array = []
var bosses: Dictionary = {}
var gates: Array = []
var seals: Array = []
var caches: Array = []
var _last_room := ""

func setup(owner_game) -> void:
	game = owner_game
	traps.clear(); bosses.clear(); gates.clear(); seals.clear(); caches.clear()
	_last_room = ""
	if not is_instance_valid(game.world): return
	var old: Node = game.world.get_node_or_null("DeepEncounters")
	if old != null:
		game.world.remove_child(old)
		old.queue_free()
	encounter_root = Node3D.new()
	encounter_root.name = "DeepEncounters"
	game.world.add_child(encounter_root)
	for marker in game.get_tree().get_nodes_in_group("deep_trap_spawn"):
		if not game.world.is_ancestor_of(marker): continue
		var trap := Trap.new()
		trap.game = game
		trap.trap_type = str(marker.get_meta("trap_type", "spikes"))
		trap.position = encounter_root.to_local(marker.global_position)
		trap.set_meta("id", str(marker.get_meta("id")) + "_controller")
		encounter_root.add_child(trap)
		traps.append(trap)
	for gate in game.get_tree().get_nodes_in_group("deep_gate"):
		if not game.world.is_ancestor_of(gate): continue
		gates.append(gate)
		_build_gate(gate)
	for seal in game.get_tree().get_nodes_in_group("deep_seal"):
		if game.world.is_ancestor_of(seal): seals.append(seal)
	for cache in game.get_tree().get_nodes_in_group("deep_cache"):
		if game.world.is_ancestor_of(cache): caches.append(cache)
	_spawn_bosses()
	_refresh_progress(false)

func tick(dt: float) -> void:
	if game == null or game.mode != "play": return
	for trap in traps:
		if is_instance_valid(trap): trap.tick(dt)
	_update_room_visit()

func current_room() -> Dictionary:
	if game == null or not is_instance_valid(game.world) or not is_instance_valid(game.player): return {}
	var interior: String = game.world.interior_at(game.player.global_position)
	if interior == "": return {}
	var nearest: Node3D
	var distance := INF
	for space in game.get_tree().get_nodes_in_group("deep_space"):
		if not game.world.is_ancestor_of(space) or space.get_meta("interior", "") != interior: continue
		var offset: Vector3 = game.player.global_position - space.global_position
		var size: Vector2 = space.get_meta("size", Vector2.ZERO)
		if absf(offset.x) > size.x * 0.5 or absf(offset.z) > size.y * 0.5 or offset.y < -0.5 or offset.y > float(space.get_meta("ceiling", 5.0)): continue
		var flat := Vector2(offset.x, offset.z)
		if flat.length_squared() < distance:
			nearest = space; distance = flat.length_squared()
	if nearest == null: return {}
	return {"id": str(nearest.get_meta("room_id", "")), "title": str(nearest.get_meta("title", "")), "interior": interior, "p": Vector2(nearest.global_position.x, nearest.global_position.z)}

func _update_room_visit() -> void:
	var room := current_room()
	if room.is_empty():
		_last_room = ""
		return
	var key := "visited_%s_%s" % [room.interior, room.id]
	if not game.state.taken.has(key): game.state.taken[key] = true
	if _last_room != key:
		_last_room = key
		game.region_text = room.title
		game.region_time = 3.2

func seals_complete() -> bool:
	for id in SEALS:
		if not game.state.taken.has(id): return false
	return true

func interact(node: Node3D) -> bool:
	if game == null or not is_instance_valid(node) or not game.world.is_ancestor_of(node): return false
	var kind := str(node.get_meta("kind", ""))
	var id := str(node.get_meta("id", ""))
	if kind == "deep_seal":
		if id not in SEALS: return false
		if game.state.taken.has(id):
			game.toast("This seal is awake. Its light endures through defeat and rest.")
			return true
		game.state.taken[id] = true
		game.audio.cue("shrine")
		game.burst(node.global_position + Vector3.UP, Color("#b6edcb"))
		var active := 0
		for key in SEALS:
			if game.state.taken.has(key): active += 1
		game.toast("Seal awakened  %d / 3. %s" % [active, "The Bellkeeper's gate is open." if active == 3 else "Find the other chapels beyond the bell hall."])
		_refresh_progress(true)
		game.state.save_game()
		return true
	if kind == "deep_gate":
		if node.get_meta("open", false):
			game.toast("The way stands open.")
		elif node.get_meta("requires", "") == "seals":
			var remaining := 0
			for key in SEALS:
				if not game.state.taken.has(key): remaining += 1
			game.toast("%d seals remain: seek the Ember Chapel, Echo Scriptorium and Tide Cistern. No keys are spent." % remaining, 5)
		else:
			game.toast("Defeat the Bellkeeper to open the Dawn Vault.")
		return true
	if kind == "deep_cache":
		if game.state.taken.has(id):
			game.toast("This cache has already been claimed.")
			return true
		if id == "deep_vault_dawn" and not game.state.taken.has("deep_boss_bellkeeper"):
			game.toast("The Bellkeeper's oath still binds this treasure.")
			return true
		if id == "deep_reward_embermaw" and not game.state.taken.has("deep_boss_embermaw"):
			game.toast("Embermaw guards the ancient heartstone. Defeat it first.")
			return true
		var rewards: Dictionary = node.get_meta("rewards", {})
		if Treasure.claim(game, node, id, rewards, "dawn_blade" if id == "deep_vault_dawn" else ""):
			game.burst(node.global_position + Vector3.UP, Color("#ffe3a0"))
			_refresh_progress(true)
		return true
	return false

func _claim_bundle(id: String, rewards: Dictionary, unique: String = "") -> bool:
	return Treasure.claim(game, null, id, rewards, unique)

func boss_defeated(boss) -> void:
	if game.state.taken.has(boss.id): return
	game.state.taken[boss.id] = true
	if boss.id == "deep_boss_embermaw":
		if _claim_bundle("deep_reward_embermaw", CAVE_REWARD):
			game.toast("Embermaw quieted! +2 ancient cores, +8 crystal, +12 iron, +3 tonic, +60 Light Essence. Return to the smith for Warden Plate.", 7)
		else:
			game.toast("Embermaw is defeated. Its heartstone cache holds your unclaimed treasure.", 6)
	else:
		game.toast("The Bellkeeper falls. The Dawn Vault is open; claim its unique blade and ancient cores.", 7)
	game.audio.cue("shrine")
	_refresh_progress(true)
	game.state.save_game()

func reset_encounters() -> void:
	if game == null or not is_instance_valid(game.world): return
	for trap in traps:
		if is_instance_valid(trap): trap.reset()


	for boss in bosses.values():
		if is_instance_valid(boss):
			if boss.get_parent() != null: boss.get_parent().remove_child(boss)
			boss.queue_free()
	bosses.clear()
	_spawn_bosses()
	_refresh_progress(false)

func _spawn_bosses() -> void:
	for marker in game.get_tree().get_nodes_in_group("deep_boss_spawn"):
		if not game.world.is_ancestor_of(marker): continue
		var id := str(marker.get_meta("boss_id", marker.get_meta("id", "")))
		if game.state.taken.has(id): continue
		var boss := Boss.new()
		boss.game = game
		boss.adventure = self
		boss.id = id
		boss.interior = str(marker.get_meta("interior", "mine"))
		boss.display_name = str(marker.get_meta("display_name", "Deep Guardian"))
		boss.max_health = 32 if boss.interior == "mine" else 48
		boss.home = marker.global_position
		boss.position = encounter_root.to_local(marker.global_position)
		boss.arena_radius = float(marker.get_meta("arena_radius", 11.0))
		encounter_root.add_child(boss)
		bosses[id] = boss

func _build_gate(gate: Node3D) -> void:
	if gate.get_node_or_null("Barrier") != null: return
	var barrier := Node3D.new()
	barrier.name = "Barrier"
	gate.add_child(barrier)
	var dark := B.mat("#4b545b", 0.5)
	var gold := B.mat("#bd9a62", 0.5)
	for x in [-2.1, -1.4, -0.7, 0.0, 0.7, 1.4, 2.1]:
		B.beveled_box(barrier, Vector3(x, 1.5, 0), Vector3(0.18, 4.3, 0.22), dark)
		B.facet(barrier, Vector3(x, -0.7, 0), Vector3(0.25, 0.6, 0.25), gold).rotation.z = PI
	for y in [0.2, 2.6]: B.box(barrier, Vector3(0, y, 0), Vector3(4.7, 0.18, 0.35), gold)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.95, 4.7, 0.5)
	var blocker := B.solid(barrier, Vector3(0, 1.4, 0), shape)
	blocker.name = "Blocker"
	for side in [-1.0, 1.0]:
		B.beveled_box(gate, Vector3(side * 2.8, 1.8, 0), Vector3(0.7, 5, 0.95), B.mat("#8e8f87"))
	B.beveled_box(gate, Vector3(0, 4.4, 0), Vector3(6.3, 0.65, 1.0), gold)
	B.batch_static(barrier)

func _refresh_progress(animate: bool) -> void:
	for gate in gates:
		if not is_instance_valid(gate): continue
		var open: bool = seals_complete() if gate.get_meta("requires", "") == "seals" else game.state.taken.has("deep_boss_bellkeeper")
		var changed: bool = bool(gate.get_meta("open", false)) != open
		gate.set_meta("open", open)
		gate.set_meta("label", "The way is open" if open else ("Awaken all three crypt seals" if gate.get_meta("requires", "") == "seals" else "Defeat the Bellkeeper to unbar the vault"))
		var barrier: Node3D = gate.get_node("Barrier")
		barrier.get_node("Blocker").collision_layer = 0 if open else 1
		if animate and changed:
			gate.create_tween().tween_property(barrier, "position:y", 5.2 if open else 0.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		else:
			barrier.position.y = 5.2 if open else 0.0
	for seal in seals:
		if not is_instance_valid(seal): continue
		var awake: bool = game.state.taken.has(str(seal.get_meta("id")))
		seal.set_meta("awake", awake)
		seal.set_meta("label", "Seal awakened — its light endures" if awake else "Awaken this crypt seal")
		var rune: MeshInstance3D = seal.get_node("Rune")
		rune.material_override = B.mat("#ffe1a1", 0, 0.8) if awake else B.mat("#8dcabb", 0, 0.25)
	for cache in caches:
		if not is_instance_valid(cache): continue
		var claimed: bool = game.state.taken.has(str(cache.get_meta("id")))
		cache.get_node("TreasureChest").set_open(claimed, animate)
		if claimed: cache.set_meta("label", "Treasure claimed")

func navigation_target(interior: String) -> Dictionary:
	if game == null or not is_instance_valid(game.world): return {}
	if interior == "dungeon":
		var nearest: Node3D
		var distance := INF
		for seal in seals:
			if not is_instance_valid(seal) or game.state.taken.has(str(seal.get_meta("id"))): continue
			var d: float = game.player.global_position.distance_to(seal.global_position)
			if d < distance:
				nearest = seal; distance = d
		if nearest != null: return _navigation_node(nearest, "CRYPT SEAL")
		if not game.state.taken.has("deep_boss_bellkeeper"):
			return _navigation_boss("deep_boss_bellkeeper", "BELLKEEPER'S COURT")
		if not game.state.taken.has("deep_vault_dawn"):
			for cache in caches:
				if cache.get_meta("id", "") == "deep_vault_dawn": return _navigation_node(cache, "DAWN VAULT")
	elif interior == "mine" and not game.state.taken.has("deep_boss_embermaw"):
		return _navigation_boss("deep_boss_embermaw", "HEART OF EMBERVEIN")
	return {}

func _navigation_node(node: Node3D, title: String) -> Dictionary:
	return {"id": str(node.get_meta("id", "")), "name": title, "pos": Vector2(node.global_position.x, node.global_position.z), "interior": game.world.interior_at(node.global_position)}

func _navigation_boss(id: String, title: String) -> Dictionary:
	if bosses.has(id) and is_instance_valid(bosses[id]): return _navigation_node(bosses[id], title)
	return {}
