extends Node3D


const Catalog = preload("res://scripts/scrapper_sites.gd")
const Art = preload("res://scripts/scrapper_camp_art.gd")
const Bandit = preload("res://scripts/scrapper_bandit.gd")
const Drone = preload("res://scripts/scrapper_drone.gd")
const Boss = preload("res://scripts/dissonance.gd")
const Roster = preload("res://scripts/scrapper_roster.gd")
const StrongholdArt = preload("res://scripts/scrapper_stronghold_art.gd")
const B = preload("res://scripts/build.gd")
const Occupancy = preload("res://scripts/world_occupancy.gd")
const RegionSites = preload("res://scripts/region_sites.gd")
const Settlements = preload("res://scripts/regional_settlements.gd")
const PARTS = ["ground", "walls", "gate", "platforms", "tents", "supplies", "props", "signals", "finish"]
const MAX_ACTORS := 12
const MAX_CAMPS := 2
const MAX_AMBIENT := 4
const CAMP_DISTANCE := 145.0
const CELL := 40.0
var game
var sites: Array = []
var jobs: Array = []
var live: Dictionary = {}
var actors: Dictionary = {}
var relay_progress: Dictionary = {}
var viewer := Vector3.INF
var epoch := -1
var clock := 0.0
var pending_deaths: Dictionary = {}
var queued_actors: Dictionary = {}

func setup(context) -> void:
	game = context; name = "ScrapperWorld"; process_mode = Node.PROCESS_MODE_PAUSABLE
	epoch = int(game.state.loot_epoch); sites.clear()
	if game.world.atlas == null: return
	for record in Catalog.records():
		var radius = float(record.get("radius", 23.0))
		var chosen := -1
		var prefix = "scrapper_site_" + str(record.id) + "_slot_"
		for flag in game.state.taken:
			if not str(flag).begins_with(prefix): continue
			var suffix = str(flag).trim_prefix(prefix)
			if suffix.is_valid_int() and int(suffix) >= 0 and int(suffix) < Catalog.ANCHOR_LIMIT: chosen = int(suffix); break
		if chosen < 0:
			for i in range(Catalog.ANCHOR_LIMIT):
				var candidate = Catalog.anchor(record, i)
				if game.world.atlas.region_at(candidate) == int(record.region) and _site_supported(record, candidate, radius): chosen = i; break
			if chosen < 0:



				push_error("No supported Scrapper anchor for " + str(record.id))
				continue
			game.state.taken[_slot_key(record.id, chosen)] = true
		var p: Vector2 = Catalog.anchor(record, chosen)
		record.pos = p; record.point = _ground(p); record.radius = radius; record.kind = "scrapper_camp"; record.slot = chosen
		sites.append(record)


		if _all_hostiles_defeated(record):
			game.state.taken["scrapper_camp_" + str(record.id) + "_cleared"] = true

func _site_supported(record: Dictionary, p: Vector2, radius: float) -> bool:
	if not safe_site(p, radius): return false
	if record.layout != "stronghold": return true
	for other in sites:
		if p.distance_to(other.pos) < radius + float(other.radius) + 12: return false
	var heading = float(record.heading); var height = game.world.surface_height_at(p.x, p.y)


	for x in range(-48, 49, 8):
		for z in range(-64, 79, 8):
			var at = p + Vector2(x, z).rotated(-heading)
			if not game.world.dry_surface_at(at, 2) or game.world.atlas.path_distance(at) < 6: return false
	for x in [-13, 0, 13]:
		for z in [-61, -52, -43]:
			var at = p + Vector2(x, z).rotated(-heading)
			if absf(game.world.surface_height_at(at.x, at.y) - height) > 1.2: return false
	return true

func _slot_key(id: String, index: int) -> String: return "scrapper_site_%s_slot_%d" % [id, index]
func site(id: String) -> Dictionary:
	for entry in sites:
		if entry.id == id: return entry
	return {}
func destinations() -> Array:
	var result: Array = []
	for entry in sites:
		var offset = Vector2(0, 74 if entry.layout == "stronghold" else 20).rotated(-float(entry.heading))
		result.append({"id": entry.id, "name": entry.name, "region": entry.region, "kind": "scrapper_camp", "pos": entry.pos + offset, "point": _ground(entry.pos + offset), "camp_id": entry.id})
	return result
func reserved(point, padding: float = 0) -> bool:
	var p = Vector2(point.x, point.z) if point is Vector3 else Vector2(point)
	for entry in sites:
		if p.distance_to(entry.pos) <= float(entry.radius) + padding: return true
	return false
func _ground(p: Vector2) -> Vector3: return Vector3(p.x, game.world.surface_height_at(p.x, p.y) + 0.07, p.y)
func _occupied(p: Vector2, radius: float) -> bool:
	return Occupancy.conflicts(game.state, Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2))
func _site_footprint(entry: Dictionary) -> Rect2:
	if entry.layout == "stronghold":
		return Occupancy.oriented_rect(entry.pos, StrongholdArt.FOOTPRINT, float(entry.heading))
	var half := Vector2.ONE * (float(entry.radius) + 2.0)
	return Rect2(entry.pos - half, half * 2)

func blocks_placement(footprint: Rect2) -> bool:
	return sites.any(func (entry): return _site_footprint(entry).intersects(footprint))

func safe_site(p: Vector2, radius: float = 23.0) -> bool:
	var w = game.world; var a = w.atlas
	if a == null or _occupied(p, radius + 2): return false
	if a.reserved(p, radius + 4) or RegionSites.reserved(a, p, radius + 4) or Settlements.reserved(a, p, radius + 4): return false
	if a.path_distance(p) < radius + 6 or not w.dry_surface_at(p, radius + 2): return false
	var h: float = w.surface_height_at(p.x, p.y)
	for i in range(16):
		var at = p + Vector2.from_angle(i * TAU / 16) * radius
		if not w.dry_surface_at(at, 2) or a.path_distance(at) < 5: return false
		if a.reserved(at, 3) or RegionSites.reserved(a, at, 3) or Settlements.reserved(a, at, 3): return false
		if absf(w.surface_height_at(at.x, at.y) - h) > (10.0 if radius > 40 else 1.5): return false
	return true
func _outdoors(point: Vector3) -> bool:
	return game.world.interior_at(point) == "" and absf(point.y - game.world.surface_height_at(point.x, point.z)) < 6

func stream_at(point: Vector3, immediate: bool = false) -> void:
	viewer = point
	_reconcile()
	if int(game.state.loot_epoch) != epoch: reset_for_rest()
	if not _outdoors(point): _retire_all(); return
	var selected: Array = []
	for entry in sites:
		if Vector2(point.x, point.z).distance_to(entry.pos) <= CAMP_DISTANCE and not Occupancy.conflicts(game.state, _site_footprint(entry)):
			selected.append(entry)
	selected.sort_custom(func (a, b): return Vector2(point.x, point.z).distance_squared_to(a.pos) < Vector2(point.x, point.z).distance_squared_to(b.pos))
	selected = selected.slice(0, MAX_CAMPS)

	var strongholds = selected.filter(func (entry): return entry.layout == "stronghold")
	if not strongholds.is_empty(): selected = strongholds.slice(0, 1)
	var ids: Array = []
	for entry in selected: ids.append(entry.id)
	for id in live.keys():
		if id not in ids: _retire_camp(id)
	for entry in selected:
		if not live.has(entry.id):
			var root = Node3D.new(); root.name = entry.id; root.position = entry.point; root.rotation.y = entry.heading
			add_child(root); live[entry.id] = root
			for part in StrongholdArt.parts() if entry.layout == "stronghold" else PARTS: jobs.append({"id": entry.id, "part": part})
		elif bool(live[entry.id].get_meta("scrapper_complete", false)): _populate_camp(entry)
	_stream_patrols(point)

	if immediate and not jobs.is_empty(): step()
func step() -> void:
	_reconcile()
	if not pending_deaths.is_empty(): _commit_deaths()
	if jobs.is_empty():
		if viewer != Vector3.INF and _outdoors(viewer):
			for id in live:
				if bool(live[id].get_meta("scrapper_complete", false)): _populate_camp(site(id))
			_stream_patrols(viewer)
		return
	var job: Dictionary = jobs.pop_front()
	if not live.has(job.id): return
	var root: Node3D = live[job.id]
	var entry = site(job.id)
	if Occupancy.conflicts(game.state, _site_footprint(entry)):
		_retire_camp(job.id)
		return
	if job.part == "actor":
		queued_actors.erase(job.entry.id); _spawn_entry(entry, job.entry); return
	if entry.layout == "stronghold": StrongholdArt.build_part(root, game.world, entry, job.part)
	else: Art.build_part(root, game.world, entry, job.part)
	if job.part == "finish":
		_build_activities(root, entry); root.set_meta("scrapper_complete", true); _populate_camp(entry)
func _process(dt: float) -> void:
	if game == null or game.mode != "play" or not is_instance_valid(game.player): return
	clock -= dt
	if clock <= 0: clock = 0.8; stream_at(game.player.global_position)
	if not jobs.is_empty() or not pending_deaths.is_empty(): step()
func _retire_actor(id: String) -> void:
	if not actors.has(id): return
	var actor = actors[id]; actors.erase(id)
	if is_instance_valid(actor):
		if actor.get_parent() != null: actor.get_parent().remove_child(actor)
		actor.queue_free()
func _retire_camp(id: String) -> void:
	for key in actors.keys():
		if is_instance_valid(actors[key]) and actors[key].camp_id == id: _retire_actor(key)
	jobs = jobs.filter(func (job): return job.id != id)
	for key in queued_actors.keys():
		if queued_actors[key] == id: queued_actors.erase(key)
	if live.has(id):
		var root = live[id]; live.erase(id)
		if is_instance_valid(root): remove_child(root); root.queue_free()
	relay_progress.erase(id)
func _retire_all() -> void:
	for id in live.keys(): _retire_camp(id)
	for id in actors.keys(): _retire_actor(id)
	jobs.clear(); queued_actors.clear()
func _reconcile() -> void:
	for id in actors.keys():
		var actor = actors[id]
		if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.health <= 0: actors.erase(id)
		elif not _ground_ready(actor.home) or not _ground_ready(actor.global_position): _retire_actor(id)
func reset_for_rest() -> void:
	for id in actors.keys(): _retire_actor(id)
	epoch = int(game.state.loot_epoch)

	if viewer != Vector3.INF and _outdoors(viewer):
		for id in live:
			if bool(live[id].get_meta("scrapper_complete", false)): _populate_camp(site(id))
		_stream_patrols(viewer)
func _ground_ready(point: Vector3) -> bool:
	var w = game.world
	var key = Vector2i(floori(point.x / w.CHUNK), floori(point.z / w.CHUNK))
	var chunk = w.chunks.get(key)
	if not is_instance_valid(chunk) or not chunk.is_inside_tree() or chunk.is_queued_for_deletion(): return false
	var collider = chunk.get_node_or_null("TerrainCollider")
	if not is_instance_valid(collider) or collider.is_queued_for_deletion(): return false
	for shape in collider.get_children():
		if shape is CollisionShape3D and shape.shape != null and not shape.disabled: return true
	return false
func actor_budget() -> int:

	return 9 + MAX_AMBIENT if live.has(Roster.STRONGHOLD) else MAX_ACTORS
func _spawn(id: String, kind: String, p: Vector3, camp_id: String, route: Array[Vector3], actor_type: String = "bandit", walking: bool = false) -> void:
	if actors.size() >= actor_budget() or actors.has(id) or game.state.taken.has(id) or pending_deaths.has(id) or not _ground_ready(p): return
	var actor
	match actor_type:
		"drone": actor = Drone.new(); actor.configure_drone(kind, walking)
		"boss": actor = Boss.new(); actor.configure_dissonance()
		_: actor = Bandit.new(); actor.configure_scrapper(kind)
	actor.game = game; actor.id = id; actor.name = id; actor.home = p; actor.position = p; actor.camp_id = camp_id
	if actor_type == "bandit":
		for waypoint in route:
			if _ground_ready(waypoint): actor.patrol_route.append(waypoint)


	add_child(actor); actors[id] = actor
func _camp_enemy_id(id: String, index: int) -> String: return "scrapper_guard_%s_%d" % [id, index]
func _populate_camp(entry: Dictionary) -> void:
	if entry.is_empty() or game.state.taken.has("scrapper_camp_" + entry.id + "_cleared"): return
	for spec in Roster.entries(entry):
		if actors.has(spec.id) or queued_actors.has(spec.id) or game.state.taken.has(spec.id) or pending_deaths.has(spec.id): continue
		var p = StrongholdArt.boss_spawn(game.world, entry) if spec.actor == "boss" else _ground(entry.pos + spec.offset.rotated(-float(entry.heading)))
		if not _ground_ready(p): continue
		queued_actors[spec.id] = entry.id; jobs.append({"id": entry.id, "part": "actor", "entry": spec})
func _spawn_entry(entry: Dictionary, spec: Dictionary) -> void:
	var at: Vector2 = entry.pos + spec.offset.rotated(-float(entry.heading)); var p = StrongholdArt.boss_spawn(game.world, entry) if spec.actor == "boss" else _ground(at)
	var route: Array[Vector3] = [p, _ground(at + Vector2(2, 0).rotated(-float(entry.heading)))]
	_spawn(spec.id, spec.kind, p, entry.id, route, spec.actor, bool(spec.get("walking", false)))
func bandits_remaining(camp_id: String) -> int:
	if site(camp_id).is_empty(): return -1
	var remaining = 0
	for id in Roster.bandit_ids(camp_id):
		if not game.state.taken.has(id) and not pending_deaths.has(id): remaining += 1
	return remaining
func ambient_count() -> int:
	var count := 0
	for actor in actors.values():
		if is_instance_valid(actor) and actor.camp_id == "": count += 1
	return count
func _patrol_safe(p: Vector2) -> bool:
	var w = game.world; var a = w.atlas
	if a == null or p.distance_to(a.spawn()) < 90 or reserved(p, 14) or _occupied(p, 10): return false
	if a.reserved(p, 12) or RegionSites.reserved(a, p, 12) or Settlements.reserved(a, p, 12): return false
	var distance: float = a.path_distance(p)
	if distance < 5 or distance > 32 or not w.dry_surface_at(p, 4): return false
	var h: float = w.surface_height_at(p.x, p.y)
	for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		if absf(w.surface_height_at(p.x + offset.x, p.y + offset.y) - h) > 0.7: return false
	return true
func _patrol_candidates(point: Vector3) -> Array:
	var result: Array = []; var cell = Vector2i(floori(point.x / CELL), floori(point.z / CELL))
	for x in range(cell.x - 2, cell.x + 3):
		for z in range(cell.y - 2, cell.y + 3):
			var id = "scrapper_patrol_%d_%d_%d" % [x, z, epoch]
			var p = Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			var distance = p.distance_to(Vector2(point.x, point.z))
			if distance < 23 or distance > 78 or not _patrol_safe(p): continue
			result.append({"id": id, "pos": p, "distance": distance})
	result.sort_custom(func (a, b): return a.distance < b.distance)
	return result
func _stream_patrols(point: Vector3) -> void:
	var a = game.world.atlas
	var p = Vector2(point.x, point.z)
	var viewer_safe = a != null and p.distance_to(a.spawn()) >= 90 and not a.reserved(p, 18) and not RegionSites.reserved(a, p, 18) and not Settlements.reserved(a, p, 18) and not _occupied(p, 14)
	for id in actors.keys():
		var actor = actors[id]
		if actor.camp_id == "" and (not viewer_safe or actor.home.distance_to(point) > 96): _retire_actor(id)
	if not viewer_safe: return
	for candidate in _patrol_candidates(point):
		if ambient_count() >= MAX_AMBIENT or actors.size() >= actor_budget(): break
		var at: Vector2 = candidate.pos; var ground = _ground(at)
		var route: Array[Vector3] = [ground]

		for offset in [Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)]:
			if _patrol_safe(at + offset): route.append(_ground(at + offset))
		_spawn(candidate.id, "scout" if posmod(hash(candidate.id), 2) == 0 else "slinger", ground, "", route)
func find_patrol_fixture() -> Vector3:

	for road in game.world.atlas.roads():
		for t in [0.25, 0.5, 0.75]:
			var at: Vector2 = road.a.lerp(road.b, t) + (road.b - road.a).normalized().orthogonal() * 12
			if _patrol_safe(at) and not _patrol_candidates(_ground(at)).is_empty(): return _ground(at)
	return Vector3.INF

func enemy_defeated(id: String, _point: Vector3, _kind: String) -> void:
	if not id.begins_with("scrapper_guard_") and not id.begins_with("scrapper_patrol_") and not id.begins_with("scrapper_drone_") and not id.begins_with("scrapper_boss_"): return
	pending_deaths[id] = true


	_commit_deaths()
func _all_hostiles_defeated(entry: Dictionary) -> bool:
	return Roster.entries(entry).all(func (spec): return game.state.taken.has(spec.id))

func _commit_deaths() -> void:
	var before: Dictionary = game.state.taken.duplicate(true)
	for id in pending_deaths: game.state.taken[id] = true
	var newly: Array = []
	for entry in sites:
		var key = "scrapper_camp_" + entry.id + "_cleared"
		if not game.state.taken.has(key) and _all_hostiles_defeated(entry):
			game.state.taken[key] = true
			newly.append(entry.name)
	if game.state.save_game():
		pending_deaths.clear()
		for title in newly: _notify(title + " cleared. The detained traveler and stolen-sound relay are safe to approach.")
	else: game.state.taken = before
func _activity(root: Node3D, entry: Dictionary, kind: String, at: Vector3, label: String) -> Node3D:
	var node = Node3D.new(); node.name = "Activity_" + kind
	root.add_child(node)
	var point = root.to_global(at); point.y = game.world.surface_height_at(point.x, point.z)
	node.global_position = point


	node.set_meta("interaction_height", 1.06 if kind.begins_with("note_") else 0.73 if kind == "clue" else 0.9)
	node.set_meta("kind", "scrapper_" + kind); node.set_meta("id", "scrapper_%s_%s" % [kind, entry.id]); node.set_meta("camp_id", entry.id); node.set_meta("label", label); node.add_to_group("interactable")
	return node
func _build_activities(root: Node3D, entry: Dictionary) -> void:
	var note = _activity(root, entry, "clue", Vector3(-3, 0, -8), "Read Dissonance's field orders")
	B.box(note, Vector3(0, 0.65, 0), Vector3(0.8, 0.12, 0.65), B.mat("#c4b18a"))
	B.box(note, Vector3(0, 0.3, 0), Vector3(0.14, 0.6, 0.14), B.mat("#584438"))
	B.box(note, Vector3(0, 0.73, 0), Vector3(0.5, 0.025, 0.4), B.mat("#eee1be"))
	var rescue = _activity(root, entry, "rescue", Vector3(8, 0, -6), "Free detained traveler" if not game.state.taken.has("scrapper_rescued_" + entry.id) else "Talk to freed traveler")
	var resident = preload("res://scripts/resident.gd").new(); rescue.add_child(resident)
	resident.configure({"id": "scrapper_traveler_" + entry.id, "name": "Detained traveler", "coat": "#688e9a", "role": "neighbor", "race": "human", "shop": "", "dialogue": []}, PackedVector3Array([Vector3.ZERO]))
	resident.remove_from_group("interactable"); resident.remove_from_group("npc")
	resident.set_meta("kind", "scrapper_traveler_visual")
	var relay = _activity(root, entry, "relay", Vector3(-7, 0, -3), "Read relay repair card: LOW • MIDDLE • HIGH")
	B.box(relay, Vector3(0, 0.4, 0), Vector3(0.95, 0.8, 0.55), B.mat("#544653", 0.4))
	B.box(relay, Vector3(0, 0.9, 0), Vector3(0.7, 0.2, 0.3), B.mat("#ad76c9", 0.5))
	for i in range(3):
		var pitch = ["low", "middle", "high"][i]
		var bell = _activity(root, entry, "note_" + pitch, Vector3(-8.8 + i * 1.8, 0, -0.8), "Ring " + pitch + " relay bell")
		bell.set_meta("note", pitch); bell.set_meta("kind", "scrapper_note")
		B.box(bell, Vector3(0, 0.7, 0), Vector3(0.12, 1.4, 0.12), B.mat("#584438"))
		B.box(bell, Vector3(0, 1.4, 0), Vector3(0.6, 0.12, 0.2), B.mat("#584438"))
		B.ball(bell, Vector3(0, 1.06, 0), Vector3(0.46 - 0.07 * i, 0.46 - 0.05 * i, 0.4), B.mat(["#af7845", "#b4a064", "#b6cbd2"][i], 0.65))
		var tag = Label3D.new(); tag.text = pitch.to_upper(); tag.font_size = 28; tag.pixel_size = 0.008; tag.position = Vector3(0, 1.8, 0); tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; bell.add_child(tag)
func activity_node(id: String, kind: String) -> Node3D:
	if not live.has(id): return null
	return live[id].get_node_or_null("Activity_" + kind)
func interact(node) -> bool:
	if not is_instance_valid(node): return false
	var kind = str(node.get_meta("kind", ""))
	if kind not in ["scrapper_clue", "scrapper_rescue", "scrapper_relay", "scrapper_note"]: return false
	var id = str(node.get_meta("camp_id", "")); var entry = site(id)
	if entry.is_empty(): return false
	match kind:
		"scrapper_clue":
			var flag = "scrapper_read_" + id
			if game.state.taken.has(flag) or _transaction(flag, {}):
				game.lore_title = str(entry.name) + " — field orders"
				game.lore_text = Catalog.NOTES[id]
				game.set_mode("lore")
		"scrapper_rescue":
			if not game.state.taken.has("scrapper_camp_" + id + "_cleared"): _notify("The traveler whispers: 'The Scrappers and their drones guard the key. Clear this camp before you cut the binding.'")
			elif game.state.taken.has("scrapper_rescued_" + id): _notify("Freed traveler: 'Dissonance steals sounds for his blast weapon and his junk drones. His crew are as disposable to him as broken gears. The relay tune is low, middle, high.'", 12)
			elif _transaction("scrapper_rescued_" + id, {"tonic": 1, "shard": 12}):
				node.set_meta("label", "Talk to freed traveler")
				_notify("Traveler freed! +1 tonic, +12 Light Essence. 'He stole my voice for a machine. Thank you for giving it back. The relays answer LOW, MIDDLE, HIGH.'", 12)
		"scrapper_relay": _notify("Repair card: Ground the bass LOW, align the heart MIDDLE, release the sky HIGH. Ring the three labeled bells in that order. The camp must be safe first.", 12)
		"scrapper_note": play_note(id, str(node.get_meta("note", "")))
	return true
func play_note(id: String, note: String) -> bool:
	if site(id).is_empty() or note not in ["low", "middle", "high"]: return false
	if game.state.taken.has("scrapper_relay_" + id): _notify("The restored relay carries the frontier's voices freely."); return true
	if not game.state.taken.has("scrapper_camp_" + id + "_cleared"): _notify("A Scrapper jammer swallows the note. Clear this camp first."); return false
	var sequence = ["low", "middle", "high"]; var progress: int = int(relay_progress.get(id, 0))
	if note != sequence[progress]: relay_progress[id] = 1 if note == "low" else 0; _notify("The chord breaks. Begin LOW, then MIDDLE, then HIGH."); return false
	progress += 1; relay_progress[id] = progress
	if game.get("audio") != null: game.audio.cue("shrine")
	if progress < 3: _notify("Relay: " + " • ".join(sequence.slice(0, progress)) + " …"); return false
	relay_progress[id] = 0
	if not _transaction("scrapper_relay_" + id, {"crystal": 2, "shard": 8}): return false
	_notify("Relay restored! +2 crystals, +8 Light Essence. The stolen chord rings across the frontier; Dissonance's listening line has lost this camp.", 12)
	return true
func _transaction(flag: String, bundle: Dictionary) -> bool:
	var s = game.state
	if s.taken.has(flag): return false
	var snapshot = {"taken": s.taken.duplicate(true), "items": s.items.duplicate(true), "slots": s._slots.duplicate(true), "unlocked": s.unlocked.duplicate(true), "upgrades": s.upgrades.duplicate(true), "equipment": s.equipment}
	var accepted := true
	for item in bundle:
		if not s.harvest(flag + "_reward_" + str(item), str(item), int(bundle[item])): accepted = false; break
	if accepted:
		s.taken[flag] = true; accepted = s.save_game()
	if not accepted:
		s.taken = snapshot.taken; s.items = snapshot.items; s._slots = snapshot.slots; s.unlocked = snapshot.unlocked; s.upgrades = snapshot.upgrades; s.equipment = snapshot.equipment
		_notify("Keep this discovery here: make room in your pack and ensure the journey can be saved, then try again.")
	return accepted
func _notify(message: String, seconds: float = 5) -> void:
	if game.has_method("toast"): game.toast(message, seconds)
