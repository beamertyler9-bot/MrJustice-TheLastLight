extends RefCounted

const Catalog = preload("res://scripts/crafting.gd")
const Locations = preload("res://scripts/locations.gd")
const Expeditions = preload("res://scripts/expeditions.gd")
const Quests = preload("res://scripts/quests.gd")
const Book = preload("res://scripts/spellbook.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Wildlife = preload("res://scripts/wildlife.gd")
const Entrances = preload("res://scripts/travel_entrances.gd")
const MAX_TEST_SPAWNS := 12
const WINDOWS := ["bag", "craft", "journal", "grimoire", "settings", "controls"]
var game
var status := "Choose a tool. Travel and test spawns can be undone. Grants persist with your journey."
var return_point := Vector3.INF
var spawned: Array = []
var serial := 0
var atlas_entries: Array = []

class TestEnemy extends "res://scripts/enemy.gd":
	func take_damage(amount: int) -> void:
		if amount <= 0 or health <= 0: return
		if amount < health:
			super.take_damage(amount)
		else:

			health = 0
			_clear_projectiles()
			remove_from_group("enemy")
			collision_layer = 0
			queue_free()

class TestArena extends RefCounted:
	func seals_complete() -> bool: return true
	func boss_defeated(_actor) -> void: pass

func setup(owner_game) -> void:
	clear_spawns()
	game = owner_game
	return_point = Vector3.INF
	atlas_entries.clear()

func available() -> bool:
	return game != null and is_instance_valid(game.player) and is_instance_valid(game.world) and game.state != null and game.mode not in ["menu", "loading"]

func _surface(pos: Vector2) -> Vector3:
	return Vector3(pos.x, game.world.surface_height_at(pos.x, pos.y) + 0.22, pos.y)

func destinations() -> Array:
	if game == null or not is_instance_valid(game.world): return []
	if game.world.get("atlas") != null: return _atlas_destinations()
	var result: Array = []
	for site in Locations.SITES + Locations.MOUNTAINS:
		var point: Vector3 = _surface(site.pos)
		if site.kind in ["mine", "dungeon"]: point += Vector3(0, 0, 4.5)
		elif site.kind in ["village", "town", "city"]: point = Entrances.settlement_point(game.world, site)
		result.append({"id": site.id, "name": site.name, "kind": "Entrance" if site.kind in ["mine", "dungeon"] else str(site.kind).capitalize(), "point": point})
	var tower = game.get("wizard_tower")
	if is_instance_valid(tower):
		result.append({"id": "wizard_tower", "name": "The Wizard's Tower · entrance", "kind": "Entrance", "point": Entrances.tower_point(tower)})
	for site in Expeditions.CACHES:
		var point: Vector3 = _surface(site.pos)
		if game.expeditions != null: point = game.expeditions.cache_points.get(site.id, point) + Vector3(0, 0.22, 1.8)
		result.append({"id": site.id, "name": site.name, "kind": "Expedition", "point": point})
	for site in game.world.landmarks:
		result.append({"id": site.id, "name": site.name, "kind": "Landmark", "point": _surface(site.pos)})
	result.append({"id": "start_glade", "name": "Starting glade", "kind": "Landmark", "point": game.world.get_spawn() + Vector3.UP * 0.2})
	for request in Quests.REQUESTS:
		if request.has("point"):
			result.append({"id": "objective_" + str(request.id), "name": str(request.area) + " · " + str(request.name), "kind": "Quest site", "point": _surface(request.point)})
	return result

func _atlas_destinations() -> Array:
	if not atlas_entries.is_empty(): return atlas_entries
	for site in game.world.get_locations():
		if site.kind in ["interior", "island"]: continue
		if site.id == "wizard_tower" and is_instance_valid(game.wizard_tower):
			atlas_entries.append({"id": site.id, "name": site.name + " · entrance", "kind": "Entrance", "point": Entrances.tower_point(game.wizard_tower)})
			continue
		if site.kind in ["city", "town"]:
			atlas_entries.append({"id": site.id, "name": site.name, "kind": str(site.kind).capitalize(), "point": Entrances.settlement_point(game.world, site)})
			continue
		if site.has("point"):
			atlas_entries.append({"id": site.id, "name": site.name, "kind": str(site.kind).capitalize(), "point": site.point})
			continue
		var p: Vector2 = site.pos
		if site.id == "fizzpeak":


			var roads: Array = game.world.atlas.roads()
			for index in range(roads.size() - 1, -1, -1):
				var road: Dictionary = roads[index]
				if road.name == "Fizzpeak summit trail" and game.world.dry_surface_at(road.b, 0.4):
					p = road.b; break
		var point: Vector3 = _surface(p)
		atlas_entries.append({"id": site.id, "name": site.name, "kind": str(site.kind).capitalize(), "point": point})
	if is_instance_valid(game.wizard_tower) and not atlas_entries.any(func (e): return e.id == "wizard_tower"):
		atlas_entries.append({"id": "wizard_tower", "name": "Wizard tower · entrance", "kind": "Entrance", "point": Entrances.tower_point(game.wizard_tower)})
	return atlas_entries

func _message(value: String, success := true) -> bool:
	status = value
	if game != null and game.has_method("toast"): game.toast(value)
	return success

func _travel(point: Vector3, title: String, queued: bool = false) -> bool:
	if game.mode != "dev": return _message("Open DEV to use entrance travel.", false)
	if not point.is_finite() or not game.has_method("teleport_player"): return _message("Safe travel is unavailable.", false)
	point = Entrances.resolve(game, point)
	if not point.is_finite(): return _message("Choose an outside entrance for this location.", false)
	var previous: Vector3 = Entrances.resolve(game, game.player.global_position)
	if queued: return game.request_teleport(point, title, _travel_finished.bind(previous, title))
	if not game.teleport_player(point, title, true, false, true): return _message("No supported arrival at this destination.", false)
	return _travel_finished(true, previous, title)

func _travel_finished(success: bool, previous: Vector3, title: String) -> bool:
	if not success: return _message("The journey could not be completed. You stayed at your previous location.", false)
	return_point = previous
	game.set_mode("play")
	return _message("Arrived: " + title + ". DEV → Travel → Return restores your previous location.")

func execute(action: String, payload: Variant = null, queued_travel: bool = false) -> bool:
	if not available(): return false
	match action:
		"travel":
			if not payload is String: return false
			for site in destinations():
				if site.id == payload: return _travel(site.point, str(site.name), queued_travel)
			return _message("Unknown destination.", false)
		"return":
			if not return_point.is_finite(): return _message("Travel somewhere first to set a return point.", false)
			return _travel(return_point, "previous location", queued_travel)
		"restore":
			game.state.health = game.state.max_health
			game.state.mana = game.state.max_mana
			game.state.stamina = game.state.max_stamina
			return _message("Health, mana and stamina restored.")
		"grant": return _grant(payload)
		"equip":
			if not payload is String or not Catalog.WEAPONS.has(payload) or not game.state.equip_weapon(payload): return _message("Grant this weapon before equipping it.", false)
			game.player.visual.set_weapon(payload)
			return _message("Equipped " + Catalog.item_name(payload) + ".")
		"starters":
			var added := 0
			for spell in Book.starters():
				if game.state.spell_by_id(str(spell.id)).is_empty() and game.state.save_spell(spell): added += 1
			return _message("Predefined library ready · %d missing legacy starter spells restored." % added)
		"open":
			if not payload is String or payload not in WINDOWS: return false
			game.set_mode(payload)
			return true
		"altar":
			if not game.near_spell_altar(): return _message("Travel to the wizard tower to browse its spell archive.", false)
			game.set_mode("play")
			return game.open_spell_archive()
		"time": return _set_time(payload)
		"quality":
			if not payload is int or payload < 0 or payload > 2: return false
			game.state.settings.quality = payload
			game.apply_settings()
			return _message("Rendering quality: " + ["Low", "Balanced", "High"][payload])
		"quest_track":
			if not payload is String or game.quests == null: return false
			return game.quests.track(payload)
		"quest_giver": return _quest_giver(payload, queued_travel)
		"spawn_enemy": return _spawn_enemy(payload)
		"spawn_wildlife": return _spawn_wildlife(payload)
		"spawn_boss": return _spawn_boss(payload)
		"spawn_object": return _spawn_object()
		"undo_spawn":
			var live := live_spawns()
			if live.is_empty(): return _message("No test spawns to undo.", false)
			_remove_spawn(live.back())
			return _message("Last test spawn removed.")
		"clear_spawns":
			clear_spawns()
			return _message("All developer test spawns removed.")
	return false

func _grant(payload: Variant) -> bool:
	if not payload is Dictionary or not payload.get("id") is String or not payload.get("amount") is int: return false
	var id: String = payload.id
	var amount: int = payload.amount
	if amount < 1 or amount > 9999 or not Catalog.ITEMS.has(id): return false
	if Catalog.WEAPONS.has(id) or Catalog.UPGRADES.has(id):
		if not game.state.award_unique(id): return _message("Already owned: " + Catalog.item_name(id) + ".", false)
		return _message("Granted " + Catalog.item_name(id) + " · available in inventory.")
	var granted: int = game.state.award_reward(id, amount)
	return _message("Granted %d × %s." % [granted, Catalog.item_name(id)], granted > 0)

func _set_time(value: Variant) -> bool:
	var phases: Dictionary = {"dawn": 0.0, "noon": 0.25, "dusk": 0.5, "night": 0.75}
	if not value is String or not phases.has(value): return false
	game.state.journey_time = floorf(game.state.journey_time / 540.0) * 540 + fposmod(float(phases[value]) - 0.18, 1.0) * 540
	game._weather()
	return _message("World lighting: " + value + ".")

func _quest_giver(value: Variant, queued: bool = false) -> bool:
	if not value is String or game.quests == null: return false
	var request: Dictionary = game.quests.definition(value)
	if request.is_empty(): return false
	var site: Vector2 = game.quests._giver_point(request)

	if not _travel(_surface(site), str(request.owner), queued): return false
	if queued: return true
	return _message("Arrived at the settlement. Walk to " + str(request.owner) + " to accept or return the request.")

func live_spawns() -> Array:
	var result: Array = []
	for actor in spawned:
		if is_instance_valid(actor) and not actor.is_queued_for_deletion(): result.append(actor)
	spawned = result
	return result

func _remove_spawn(actor: Node) -> void:
	if actor.has_method("_clear_projectiles"): actor._clear_projectiles()
	if actor is RigidBody3D and game != null:
		if is_instance_valid(game.player) and game.player.held_body == actor: game.player.release_held(false)
		if is_instance_valid(game.magic) and game.magic.has_method("cancel_object_magic"): game.magic.cancel_object_magic()
	actor.queue_free()

func clear_spawns() -> void:
	for actor in live_spawns(): _remove_spawn(actor)
	spawned.clear()

func _spawn_point(distance := 5.0) -> Vector3:
	var origin: Vector3 = game.player.global_position
	var interior: String = game.world.interior_at(origin)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.72
	shape.height = 2.8
	for reach in [distance, distance * 0.7, 2.5]:
		for turn in [0.0, 0.65, -0.65, 1.3, -1.3, PI]:
			var yaw: float = game.player.yaw + turn
			var point: Vector3 = origin + Vector3(-sin(yaw), 0, -cos(yaw)) * float(reach)
			if not interior.is_empty():
				if game.world.interior_at(point) != interior: continue
				point.y = origin.y
			else:
				point.y = game.world.surface_height_at(point.x, point.z) + 0.12
				if point.y < game.world.water_level + 0.5: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.5)
			query.collision_mask = 1 | 4 | 8
			query.exclude = [game.player.get_rid()]
			if game.player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return point
	return Vector3.INF

func _can_spawn() -> bool:
	return live_spawns().size() < MAX_TEST_SPAWNS

func _spawn_enemy(value: Variant) -> bool:
	if not value is String or not Enemy.SPECIES.has(value) or not _can_spawn(): return false
	var point := _spawn_point()
	if not point.is_finite(): return _message("No clear spawn space nearby. Move to open ground.", false)
	var actor = TestEnemy.new()
	actor.configure_species(value)
	actor.game = game
	serial += 1
	actor.id = "dev_test_%d" % serial
	actor.position = point
	actor.home = actor.position
	game.add_child(actor)
	spawned.append(actor)
	return _message("Test " + str(actor.display_name) + " spawned · no loot or quest progress. Close DEV to fight.")

func _spawn_boss(value: Variant) -> bool:
	if not value is String or value not in ["embermaw", "bellkeeper"] or not _can_spawn(): return false
	var interior: String = "mine" if value == "embermaw" else "dungeon"
	if game.world.interior_at(game.player.global_position) != interior: return _message("Travel inside " + ("Embervein" if interior == "mine" else "the crypt") + " before spawning this boss.", false)
	var point := _spawn_point(7)
	if not point.is_finite(): return _message("Find an open chamber before spawning the boss.", false)
	var actor = load("res://scripts/deep_boss.gd").new()
	actor.game = game
	actor.adventure = TestArena.new()
	actor.interior = interior
	actor.display_name = "Test Embermaw" if interior == "mine" else "Test Bellkeeper"
	actor.max_health = 32 if interior == "mine" else 44
	actor.position = point
	actor.home = actor.position
	serial += 1
	actor.id = "dev_test_boss_%d" % serial
	game.add_child(actor)
	spawned.append(actor)
	return _message(actor.display_name + " spawned · test encounter grants no progression.")

func _spawn_wildlife(value: Variant) -> bool:
	if not value is String or value not in Wildlife.POOL_SPECIES or not _can_spawn(): return false
	if game.world.interior_at(game.player.global_position) != "": return _message("Wildlife lives outdoors; travel outside first.", false)
	var point := _spawn_point(4)
	if not point.is_finite() or Locations.reserved(Vector2(point.x, point.z), 1): return _message("Wildlife needs open countryside outside settlement plots. Travel to a field site first.", false)
	var pool = Wildlife.new()
	pool.setup(game)
	game.add_child(pool)
	var chosen: Array[Dictionary] = []
	for critter in pool.critters:
		if chosen.is_empty() and critter.species == value:
			critter.anchor = point
			critter.node.position = critter.anchor
			critter.node.visible = true
			chosen.append(critter)
		else: critter.node.queue_free()
	pool.critters = chosen
	spawned.append(pool)
	return _message("Test " + value + " spawned outdoors. Wildlife uses normal roaming behavior.")

func _spawn_object() -> bool:
	if not _can_spawn(): return false
	var point := _spawn_point(3)
	if not point.is_finite(): return _message("No clear space nearby for a test stone.", false)
	var before: int = game.world.get_child_count()
	game.world.carryable(game.world, point + Vector3.UP * 0.35, 0, "dev_magic_object_%d" % serial)
	if game.world.get_child_count() <= before: return false
	var actor = game.world.get_child(game.world.get_child_count() - 1)
	spawned.append(actor)
	serial += 1
	return _message("Throwable stone spawned for physics magic testing.")
