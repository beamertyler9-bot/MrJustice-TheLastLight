extends RefCounted

const B = preload("res://scripts/build.gd")
const CACHES := [
	{"id": "field_cache_foxglove", "name": "Foxglove waystation", "pos": Vector2(-26, 16)},
	{"id": "field_cache_stargazer", "name": "Stargazer's lookout", "pos": Vector2(35, -9)},
	{"id": "field_cache_amber", "name": "Amberwood hollow", "pos": Vector2(65, -49)},
	{"id": "field_cache_bellroad", "name": "The old bell road", "pos": Vector2(16, -97)},
	{"id": "field_cache_moss", "name": "Mossbound ruins", "pos": Vector2(-94, -73)},
	{"id": "field_cache_farshore", "name": "Farshore camp", "pos": Vector2(125, -104)}
]
const GOALS := [
	{"id": "tools", "name": "THE FIRST EXPEDITION", "text": "Craft an axe and a pickaxe. Gather loose stone and sticks first; use a table for your pick.", "route": "brindlewick", "goal": 2, "reward": {"shard": 12, "tonic": 2}, "reward_text": "12 Light Essence · 2 tonics"},
	{"id": "smith", "name": "HONEST IRON", "text": "Talk to Bramm Emberhand, the orc blacksmith in Brindlewick.", "route": "brindlewick", "goal": 1, "reward": {"iron": 4, "shard": 15}, "reward_text": "4 iron · 15 Light Essence"},
	{"id": "camp", "name": "A LIGHT OF YOUR OWN", "text": "Craft a camp kit at a table and place your camp on clear, level ground.", "route": "", "goal": 1, "reward": {"coffee_bean": 6, "marshmallow": 4, "shard": 15}, "reward_text": "Camp provisions · 15 Light Essence"},
	{"id": "cave", "name": "THE HEART BELOW", "text": "Explore the branching Embervein caves and defeat Embermaw in the deepest cavern.", "route": "mine", "goal": 1, "reward": {"shard": 25, "relic": 2}, "reward_text": "25 Light Essence · 2 relics"},
	{"id": "seals", "name": "THREE VOICES IN STONE", "text": "Find and awaken the Ember, Echo and Tide seals in the Bellkeeper's Crypt. Each remains lit after defeat.", "route": "dungeon", "goal": 3, "reward": {"tonic": 3, "shard": 30}, "reward_text": "3 tonics · 30 Light Essence"},
	{"id": "vault", "name": "WHEN THE LAST BELL FALLS", "text": "Defeat the Hollow Bellkeeper and open the Dawn vault beyond his chamber.", "route": "dungeon", "goal": 1, "reward": {"shard": 40, "ancient_core": 1}, "reward_text": "40 Light Essence · ancient core"},
	{"id": "summits", "name": "ABOVE THE CLOUDLINE", "text": "Stand on the summits of both Westreach and Glasswood. Climb steep faces or grapple to gain height.", "route": "westreach_summit", "goal": 2, "reward": {"crystal": 6, "shard": 35}, "reward_text": "6 crystals · 35 Light Essence"},
	{"id": "caches", "name": "STORIES BY THE ROADSIDE", "text": "Find all six hidden expedition caches. Their routes are listed under Destinations.", "route": "field_cache_foxglove", "goal": 6, "reward": {"ancient_core": 2, "shard": 60}, "reward_text": "2 ancient cores · 60 Light Essence"},
	{"id": "warden", "name": "THE FRONTIER'S WARDEN", "text": "Forge Warden plate at a crafting table using ancient cores, iron and crystal.", "route": "brindlewick", "goal": 1, "reward": {"shard": 50, "tonic": 4}, "reward_text": "50 Light Essence · 4 tonics"}
]
var game
var elapsed := 0.0
var cache_points: Dictionary = {}

func setup(owner_game) -> void:
	game = owner_game
	for site in CACHES:
		var p: Vector2 = preload("res://scripts/fixed_world.gd").service_points("cache_points").get(site.id, site.pos) if game.world.atlas != null else site.pos

		var point := Vector3(p.x, game.world.surface_height_at(p.x, p.y), p.y)
		for ring in range(9):
			if point.y > game.world.water_level + 0.8: break
			p += Vector2(ring * 2.0, ring * -2.0)
			point = Vector3(p.x, game.world.surface_height_at(p.x, p.y), p.y)
		cache_points[site.id] = point
		if game.state.taken.get(site.id, false): continue
		_build_cache(site, point)
	game.world.reserved_cache_positions = cache_points.values()

func _build_cache(site: Dictionary, point: Vector3) -> void:
	var n := Node3D.new()
	n.position = point
	n.name = str(site.id)
	n.set_meta("id", site.id)
	n.set_meta("kind", "expedition_cache")
	n.set_meta("label", "Open expedition cache")
	n.add_to_group("interactable")
	n.add_to_group("expedition_cache")
	game.world.add_child(n)
	var stone := B.mat("#617c79")
	var dark := B.mat("#334e52")
	var brass := B.mat("#c6a46c", 0.55)
	B.beveled_box(n, Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 1.05), stone)
	B.beveled_box(n, Vector3(0, 0.65, 0), Vector3(0.96, 0.7, 0.65), B.mat("#79553b"))
	B.beveled_box(n, Vector3(0, 1.02, 0), Vector3(1.03, 0.18, 0.71), dark)
	for x in [-0.34, 0.34]:
		B.box(n, Vector3(x, 0.72, 0.34), Vector3(0.08, 0.68, 0.045), brass)
	B.facet(n, Vector3(0, 0.86, 0.38), Vector3(0.18, 0.23, 0.07), B.mat("#8ce2dc", 0, 0.45))
	B.branch(n, Vector3(-0.95, 0, 0.1), Vector3(-0.95, 2.9, 0.1), 0.05, dark, 0.8)
	var pennant := B.box(n, Vector3(-0.67, 2.55, 0.1), Vector3(0.55, 0.6, 0.035), B.mat("#b34d49"))
	pennant.rotation.z = -0.07
	B.facet(n, Vector3(-0.67, 2.54, 0.07), Vector3(0.12, 0.22, 0.035), brass)
	B.batch_static(n)

func routes() -> Array:
	var result: Array = []
	for site in CACHES:
		if game.state.taken.get(site.id, false): continue
		var point: Vector3 = cache_points.get(site.id, Vector3(site.pos.x, 0, site.pos.y))
		result.append({"id": site.id, "name": site.name, "kind": "expedition cache", "pos": Vector2(point.x, point.z)})
	return result

func interact(node: Node3D) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_meta("kind", "") != "expedition_cache": return false
	var id := str(node.get_meta("id", ""))
	if game.state.taken.get(id, false): return false
	game.state.taken[id] = true
	game.state.award_reward("shard", 18)
	game.state.award_reward("tonic", 1)
	game.state.award_reward("relic", 1)
	game.audio.cue("collect")
	game.burst(node.global_position + Vector3.UP, Color("#ffe5a4"), 14)
	node.queue_free()
	game.toast("Expedition cache found · 18 Light Essence, tonic & old relic", 4)
	game.state.save_game()
	return true

func progress(id: String) -> int:
	var s = game.state
	match id:
		"tools": return (1 if s.unlocked.get("makeshift_axe", false) or s.unlocked.get("stone_axe", false) else 0) + (1 if s.unlocked.get("stone_pickaxe", false) else 0)
		"smith": return 1 if s.taken.get("talked_brindlewick_smith", false) else 0
		"camp": return 1 if s.camp_placed else 0
		"cave": return 1 if s.taken.get("deep_boss_embermaw", false) else 0
		"seals": return int(s.taken.get("deep_seal_ember", false)) + int(s.taken.get("deep_seal_echo", false)) + int(s.taken.get("deep_seal_tide", false))
		"vault": return 1 if s.taken.get("deep_vault_dawn", false) else 0
		"summits": return int(s.taken.get("discovered_westreach_summit", false) or s.taken.get("discovered_fizzpeak", false)) + int(s.taken.get("discovered_glasswood_summit", false) or s.taken.get("discovered_sky_9_2", false))
		"caches":
			var found := 0
			for site in CACHES: found += int(s.taken.get(site.id, false))
			return found
		"warden": return 1 if s.upgrades.get("warden_plate", false) else 0
	return 0

func entries() -> Array:
	var result: Array = []
	for goal in GOALS:
		var entry: Dictionary = goal.duplicate(true)
		if game.world.atlas != null:
			if entry.route == "mine": entry.route = "legacy_mine"
			elif entry.route == "dungeon": entry.route = "valley-d01"
			elif entry.id == "summits": entry.route = "fizzpeak"; entry.text = "Reach Fizzpeak and Cloudbell Crown above Mosswake Valley."
		entry.progress = progress(str(goal.id))
		entry.completed = game.state.taken.get("expedition_" + str(goal.id), false)
		result.append(entry)
	return result

func tick(dt: float) -> void:
	elapsed += maxf(0, dt)
	if elapsed < 1.0: return
	elapsed = 0.0
	check_progress()

func check_progress() -> void:
	for goal in GOALS:
		var flag := "expedition_" + str(goal.id)
		if game.state.taken.get(flag, false) or progress(str(goal.id)) < int(goal.goal): continue
		game.state.taken[flag] = true
		for item in goal.reward: game.state.award_reward(item, int(goal.reward[item]))
		game.audio.cue("shrine")
		game.toast("Expedition complete: " + str(goal.name).capitalize() + " · " + str(goal.reward_text), 5)
		game.state.save_game()
		return
