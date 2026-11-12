extends RefCounted
## The main story, "The Last Light", and the lore scattered across the land.
##
## Long ago the Dawnbell of Bellcrown rang every morning, and its ring carried the light
## out over all seven lands. The Lantern Masons built lanternfolk to carry that light to
## the far places. Then the Blackthorn Regent of Hollowmourn cracked the bell. Its seven
## chimes scattered, each one claimed by something that should never have held it, and
## every dawn since has come a little dimmer. Mr. Justice carries the last spark struck from
## the Dawnbell before it fell silent: the Last Light.
##
## Chapters run in order; each ends at a place or a boss on the map, and the current one is
## always tracked (HUD card + compass + map star) unless you track something else. Bosses
## beaten early still count. Each region also hides three lore pieces (a journal, a carved
## stone and a note) that tell a local trouble; finding all three earns that region's
## keepsake, a lasting bonus you can't get anywhere else.

const B = preload("res://scripts/build.gd")

const CHAPTERS := [
	{"id": "last_light", "title": "The Last Light",
		"intro": "Your lantern holds the last spark of the Dawnbell. Go to Bellcrown, where the great bell hangs cracked and silent, and see what was lost.",
		"steps": [{"type": "discover", "site": "bellcrown", "text": "Reach Bellcrown, the city of the silent Dawnbell."}],
		"outro": "The Dawnbell hangs in its tower, split from lip to crown. Seven sockets around its rim stand empty: the seven chimes are gone, scattered to the seven lands.",
		"reward": {"shard": 20, "tonic": 2}},
	{"id": "moss_chime", "title": "The Moss Chime",
		"intro": "Miners in Mosswake hear a bell ringing under Thunderledge. Something deep in the cave swallowed the Moss Chime and grew fat on its light.",
		"steps": [{"type": "boss", "site": "valley-c08", "text": "Defeat the Stonejaw Wyrm in Thunderledge Cave."}],
		"outro": "The wyrm coughs up a chime of green bronze, warm as a hearthstone. Somewhere in Bellcrown, the Dawnbell hums.",
		"reward": {"shard": 40, "iron": 4, "tonic": 2}},
	{"id": "sugar_chime", "title": "The Sugar Chime",
		"intro": "In S'morewood the cola runs sweet and the ovens never cool. Climb Fizzpeak to see the land, then find the Sugar Chime in the Grand Confectionery.",
		"steps": [{"type": "discover", "site": "fizzpeak", "text": "Climb to the summit of Fizzpeak."},
			{"type": "boss", "site": "food-d06", "text": "Defeat the Grand Confectioner in the Grand Confectionery."}],
		"outro": "The Grand Confectioner had been baking the chime into a cake, and it is still a little sticky. It rings like a spoon on a glass.",
		"reward": {"shard": 45, "marshmallow": 4, "chocolate_bar": 4, "graham_cracker": 4}},
	{"id": "wind_chime", "title": "The Wind Chime",
		"intro": "Across Windbell Plains the windmills turn backwards in a storm that never ends. The storm has a heart: the Stormhorn Matriarch, and the Wind Chime on her horn.",
		"steps": [{"type": "boss", "site": "plains-d06", "text": "Defeat the Stormhorn Matriarch in Stormhorn Arena."}],
		"outro": "The storm breaks. The Wind Chime is light as a feather and will not stop humming.",
		"reward": {"shard": 50, "iron": 6, "tonic": 2}},
	{"id": "sun_chime", "title": "The Sun Chime",
		"intro": "The Sunspire Dunes hide the Pyramid of Seven Shadows. Its glass guardian keeps the Sun Chime locked in a chamber of light.",
		"steps": [{"type": "boss", "site": "desert-d02", "text": "Defeat the Glass Anubid in the Pyramid of Seven Shadows."}],
		"outro": "Out of the glass guardian's shards you lift a chime of gold that throws little suns across the walls.",
		"reward": {"shard": 55, "crystal": 4, "tonic": 2}},
	{"id": "ash_chime", "title": "The Ash Chime",
		"intro": "Ashfall Caldera's people say the Furnace Cathedral's fire burned blue the night the Dawnbell broke. Go and see what lies on its altar.",
		"steps": [{"type": "enter", "site": "volcanic-d05", "text": "Find the Ash Chime inside the Furnace Cathedral."}],
		"outro": "On the cathedral altar, in a bed of blue embers, the Ash Chime is waiting, as if someone left it there for you.",
		"reward": {"shard": 55, "iron": 6, "ancient_core": 1}},
	{"id": "glass_chime", "title": "The Glass Chime",
		"intro": "Prismere's Aurora Orrery tracks every star, and its custodian will not give up the Glass Chime it uses to keep time.",
		"steps": [{"type": "boss", "site": "crystal-d06", "text": "Defeat the Aurora Custodian in the Aurora Orrery."}],
		"outro": "The orrery winds down. The Glass Chime is clear as water, and the whole room rings faintly with your footsteps.",
		"reward": {"shard": 60, "crystal": 6, "tonic": 2}},
	{"id": "grave_chime", "title": "The Grave Chime",
		"intro": "In Hollowmourn the dead don't rest, because the Pale Watcher of the Mourning Abbey rings the Grave Chime every night to wake them.",
		"steps": [{"type": "boss", "site": "haunted-d02", "text": "Defeat the Pale Watcher in the Mourning Abbey."}],
		"outro": "The Grave Chime is cold and quiet. For the first time in years, Hollowmourn sleeps.",
		"reward": {"shard": 60, "tonic": 3, "ancient_core": 1}},
	{"id": "blackthorn", "title": "Blackthorn",
		"intro": "Seven chimes ring together in your lantern. Only the one who cracked the Dawnbell is left: the Blackthorn Regent, waiting at the top of Blackthorn Keep.",
		"steps": [{"type": "boss", "site": "haunted-d01", "text": "Climb Blackthorn Keep and defeat the Blackthorn Regent."}],
		"outro": "The Regent falls, and far away, for the first time in a generation, the Dawnbell rings. Morning spills over all seven lands. The Last Light was never meant to be the last.",
		"reward": {"shard": 120, "ancient_core": 2, "tonic": 4}},
]

## Three pieces per region; the kind decides how it looks (journal, stone or note).
const LORE := {
	9: {"region": "Mosswake Valley", "trouble": "The Mason's Last Lantern",
		"keepsake": {"id": "charm_mosswake", "name": "Mason's Thimble", "text": "+1 heart", "health": 1},
		"pieces": [
			{"kind": "journal", "title": "A Mason's Daybook", "text": "Forty lanterns finished this season. The Dawnbell's spark takes to brass like a cat to a sunbeam. We are told a lantern carrying the light should never be left in the dark."},
			{"kind": "stone", "title": "Carved Stone of the Masons", "text": "HERE THE LANTERN MASONS SWORE: EVERY LIGHT WE MAKE SHALL BE CARRIED, NOT KEPT. A LIGHT KEPT IS A LIGHT LOST."},
			{"kind": "note", "title": "Note Pinned to a Post", "text": "To whoever finds this: the last lantern the masons made walked out of the hall the night the bell broke. Its head still burned. If you see it, tell it we're sorry. - Odile, apprentice"}]},
	10: {"region": "S'morewood", "trouble": "The Ovens That Never Cool",
		"keepsake": {"id": "charm_smorewood", "name": "Fizzpeak Sugarglass", "text": "+8% run speed", "speed": 0.08},
		"pieces": [
			{"kind": "journal", "title": "Baker's Ledger", "text": "Since the chime came to the Confectionery, the ovens won't cool. Flour by the cartload goes in; nobody remembers who the cakes are for. The cola springs bubble faster every week."},
			{"kind": "stone", "title": "Graham-stone Marker", "text": "GRAHAM GLEN, FOUNDED ON THE FIRST SWEET HARVEST. SHARE THE FIRE, SHARE THE MALLOW. NO ONE EATS ALONE."},
			{"kind": "note", "title": "Child's Note", "text": "Dear lantern man, if you go up Fizzpeak can you bring back some cloud? Mum says they taste like marshmallow but I think she's making it up. - Pip"}]},
	11: {"region": "Windbell Plains", "trouble": "The Backwards Windmills",
		"keepsake": {"id": "charm_windbell", "name": "Kitewatch Feather", "text": "+1 heart", "health": 1},
		"pieces": [
			{"kind": "journal", "title": "Miller's Journal", "text": "Third week of the storm. Every mill on the plain turns backwards now. The grain grinds itself to dust. Old Harl swears he heard a horn in the thunder, and a bell under it."},
			{"kind": "stone", "title": "Windstone", "text": "THE WIND IS THE PLAINS' BREATH. WHEN IT TURNS AGAINST US, ASK WHO HAS STOLEN ITS VOICE."},
			{"kind": "note", "title": "Torn Caravan Notice", "text": "CARAVANS TO IRONBELL SUSPENDED. Stormhorns sighted near the arena. A herd that size isn't natural. Something is driving them."}]},
	12: {"region": "Sunspire Dunes", "trouble": "The Seven Shadows",
		"keepsake": {"id": "charm_sunspire", "name": "Oasis Scarab", "text": "+20 mana", "mana": 20.0},
		"pieces": [
			{"kind": "journal", "title": "Surveyor's Notes", "text": "The Pyramid of Seven Shadows casts seven shadows at noon, which ought to be impossible. One of them falls the wrong way, towards the Dawnbell, as if it is pointing."},
			{"kind": "stone", "title": "Sun-worn Obelisk", "text": "WATER IS LIFE. SHADE IS MERCY. LIGHT IS THE PATH. GIVE ALL THREE TO THE TRAVELLER."},
			{"kind": "note", "title": "Caravan Master's Warning", "text": "Don't follow the glass dog into the pyramid. Three of my drivers did. The sand gave back their boots, and it was laughing."}]},
	13: {"region": "Ashfall Caldera", "trouble": "The Blue Fire",
		"keepsake": {"id": "charm_ashfall", "name": "Ember-heart Bead", "text": "+1 heart", "health": 1},
		"pieces": [
			{"kind": "journal", "title": "Foundry Logbook", "text": "The night the bell broke, the Furnace Cathedral's fire turned blue, and nobody here has been able to light a red flame since. The smiths are working with cold iron."},
			{"kind": "stone", "title": "Basalt Prayer-stone", "text": "FIRE THAT WARMS, FIRE THAT FORGES, FIRE THAT GUIDES. WE KEEP ALL THREE. WE FEAR ONLY THE FIRE THAT IS COLD."},
			{"kind": "note", "title": "Smith's Scrawl", "text": "If the lantern-walker comes through, send it to the Cathedral. A blue fire is waiting for something to come and take it home."}]},
	14: {"region": "Hollowmourn", "trouble": "The Ones Who Don't Sleep",
		"keepsake": {"id": "charm_hollowmourn", "name": "Widow's Locket", "text": "+1 heart", "health": 1},
		"pieces": [
			{"kind": "journal", "title": "Abbey Register", "text": "Burials this month: eleven. Returns this month: eleven. The Pale Watcher rings his bell at midnight, and the graveyard empties. We have stopped digging."},
			{"kind": "stone", "title": "Grave of the Regent's Herald", "text": "HE SERVED THE BLACKTHORN REGENT FAITHFULLY, AND WAS THE FIRST TO LEARN THAT THE REGENT WANTED NO DAWN AT ALL."},
			{"kind": "note", "title": "Letter Never Sent", "text": "My lord Regent, the bell is cracked as you ordered. But the masons got one spark out before it fell silent. A lantern carries it. Forgive me; I could not catch it."}]},
	15: {"region": "Prismere", "trouble": "The Stopped Stars",
		"keepsake": {"id": "charm_prismere", "name": "Aurora Lens", "text": "+20 mana", "mana": 20.0},
		"pieces": [
			{"kind": "journal", "title": "Astronomer's Record", "text": "The orrery has stopped. Its custodian keeps it wound with the Glass Chime, but the stars it shows haven't moved in nine years. We can't tell when to plant."},
			{"kind": "stone", "title": "Chime-carved Pillar", "text": "EVERY CHIME IN PRISMERE WAS TUNED TO THE DAWNBELL. WHEN IT RINGS AGAIN, SO SHALL WE."},
			{"kind": "note", "title": "Gemcutter's Receipt", "text": "One lens, aurora-cut, for the Orrery. Paid in full. Note: the custodian asked if the lens could see a lantern coming from very far away. Odd question."}]},
}

const VISIBLE := 140.0

var game
var markers: Dictionary = {}   # lore id -> Node3D
var points: Dictionary = {}    # lore id -> Vector3
var reading: Dictionary = {}   # the open lore card: {title, text, region, from}
var reading_time := 0.0
var elapsed := 0.0
var announced := ""


func setup(owner_game) -> void:
	game = owner_game
	var atlas = game.world.get("atlas")
	if atlas == null: return
	_place_lore(atlas)
	game.state.refresh_stats()


static func lore_id(region: int, index: int) -> String: return "lore_%d_%d" % [region, index]


# --- Placing lore: beside the roads of each region, away from towns and sites -----------

func _place_lore(atlas) -> void:
	var by_region := {}
	for road in atlas.roads():
		var mid: Vector2 = (road.a + road.b) * 0.5
		var region: int = atlas.region_at(mid)
		if not LORE.has(region): continue
		if not by_region.has(region): by_region[region] = []
		by_region[region].append(road)
	for region in LORE:
		var roads: Array = by_region.get(region, [])
		roads.sort_custom(func(a, b): return (a.a + a.b).length_squared() < (b.a + b.b).length_squared())
		var chosen: Array = []
		for spacing in [120.0, 50.0]:
			for road in roads:
				if chosen.size() >= 3: break
				for t in [0.5, 0.3, 0.7]:
					var along: Vector2 = road.a.lerp(road.b, t)
					var far := true
					for other in chosen: far = far and along.distance_to(Vector2(other.x, other.z)) > spacing
					if not far: continue
					var spot := _spot(atlas, along)
					if spot != Vector3.INF: chosen.append(spot); break
		for index in range(chosen.size()):
			var point: Vector3 = chosen[index]
			var id := lore_id(region, index)
			points[id] = point
			if not game.world.reserved_cache_positions.has(point): game.world.reserved_cache_positions.append(point)
			if not game.state.taken.get(id, false): _build(id, region, index, point)


func _spot(atlas, origin: Vector2) -> Vector3:
	for index in range(60):
		var ring := 2.5 + float(index / 8) * 2.0
		var p := origin + Vector2.from_angle(index * TAU / 8.0 + 0.4) * ring
		if atlas.reserved(p, 3.0): continue
		var height: float = game.world.surface_height_at(p.x, p.y)
		if height <= game.world.water_level + 0.8: continue
		if not preload("res://scripts/water_profile.gd").sample(p).is_empty(): continue
		var level := true
		for offset in [Vector2(-0.7, 0), Vector2(0.7, 0), Vector2(0, -0.7), Vector2(0, 0.7)]:
			if absf(game.world.surface_height_at(p.x + offset.x, p.y + offset.y) - height) > 0.45: level = false; break
		if level: return Vector3(p.x, height, p.y)
	return Vector3.INF


func _build(id: String, region: int, index: int, point: Vector3) -> void:
	var piece: Dictionary = LORE[region].pieces[index]
	var node := Node3D.new(); node.name = id; node.position = point
	node.set_meta("id", id); node.set_meta("kind", "lore")
	node.set_meta("label", {"journal": "Read the journal", "stone": "Read the carved stone", "note": "Read the note"}[piece.kind])
	node.add_to_group("interactable")
	game.world.add_child(node)
	node.rotation.y = float(hash(id) % 628) / 100.0
	var wood := B.mat("#6b4a33"); var stone := B.mat("#8e8a80"); var paper := B.mat("#efe2c0")
	var glow := StandardMaterial3D.new(); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glow.albedo_color = Color("#ffe6a0")
	match str(piece.kind):
		"journal":
			B.beveled_box(node, Vector3(0, 0.45, 0), Vector3(0.42, 0.9, 0.34), stone)
			var top := B.box(node, Vector3(0, 0.95, 0.02), Vector3(0.6, 0.06, 0.44), wood); top.rotation.x = -0.35
			var book := B.box(node, Vector3(0, 1.02, 0.03), Vector3(0.5, 0.05, 0.34), B.mat("#7b2f2a")); book.rotation.x = -0.35
			var pages := B.box(node, Vector3(0, 1.055, 0.03), Vector3(0.44, 0.02, 0.3), paper); pages.rotation.x = -0.35
		"stone":
			var slab := B.beveled_box(node, Vector3(0, 0.85, 0), Vector3(0.75, 1.7, 0.28), stone); slab.rotation.z = 0.04
			for i in range(4): B.box(node, Vector3(-0.18 + (i % 2) * 0.36, 1.25 - (i / 2) * 0.4, 0.15), Vector3(0.16, 0.16, 0.02), glow)
		_:
			B.branch(node, Vector3(0, 0, 0), Vector3(0, 1.5, 0), 0.06, wood, 1)
			var sheet := B.box(node, Vector3(0, 1.15, 0.07), Vector3(0.36, 0.46, 0.015), paper); sheet.rotation.z = 0.06
			B.box(node, Vector3(0, 1.36, 0.085), Vector3(0.05, 0.05, 0.02), B.mat("#b8423a"))
	# A small floating light so it can be spotted from down the road.
	var wisp := B.ball(node, Vector3(0, 2.1, 0), Vector3(0.16, 0.16, 0.16), glow)
	wisp.name = "LoreWisp"
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		child.visibility_range_end = VISIBLE
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markers[id] = node


# --- Reading lore ------------------------------------------------------------------------

func interact(node: Node3D) -> bool:
	if not is_instance_valid(node) or str(node.get_meta("kind", "")) != "lore": return false
	var id := str(node.get_meta("id", ""))
	var region := int(id.get_slice("_", 1)); var index := int(id.get_slice("_", 2))
	if not LORE.has(region): return false
	var piece: Dictionary = LORE[region].pieces[index]
	reading = {"title": piece.title, "text": piece.text, "region": LORE[region].region, "from": node.global_position}
	reading_time = 16.0
	if not game.state.taken.get(id, false):
		game.state.taken[id] = true
		game.state.award_reward("shard", 6)
		game.audio.cue("collect")
		game.burst(node.global_position + Vector3.UP * 1.2, Color("#ffe6a0"), 12)
		var wisp := node.get_node_or_null("LoreWisp")
		if wisp != null: wisp.queue_free()
		_check_region(region)
		game.state.save_game()
	return true


## A story card (chapter start or end); it stays until closed or it times out.
func _show(header: String, title: String, text: String) -> void:
	reading = {"title": title, "text": text, "region": header}
	reading_time = 14.0

func close_reading() -> void:
	reading = {}; reading_time = 0.0


func region_found(region: int) -> int:
	var count := 0
	for i in range(3): count += int(game.state.taken.get(lore_id(region, i), false))
	return count


func _check_region(region: int) -> void:
	var keepsake: Dictionary = LORE[region].keepsake
	if region_found(region) < 3 or game.state.taken.get(keepsake.id, false): return
	game.state.taken[keepsake.id] = true
	game.state.refresh_stats()
	game.state.health = game.state.max_health
	game.audio.cue("shrine")
	game.toast("%s solved: \"%s\". Keepsake earned: %s (%s)" % [LORE[region].region, LORE[region].trouble, keepsake.name, keepsake.text], 7)


## Stat bonuses from keepsakes (applied by state.refresh_stats).
static func keepsake_bonus(taken: Dictionary) -> Dictionary:
	var bonus := {"health": 0, "stamina": 0.0, "mana": 0.0, "speed": 0.0}
	for region in LORE:
		var keepsake: Dictionary = LORE[region].keepsake
		if not taken.get(keepsake.id, false): continue
		bonus.health += int(keepsake.get("health", 0))
		bonus.stamina += float(keepsake.get("stamina", 0.0))
		bonus.mana += float(keepsake.get("mana", 0.0))
		bonus.speed += float(keepsake.get("speed", 0.0))
	return bonus


# --- Chapters ----------------------------------------------------------------------------

func _step_done(step: Dictionary) -> bool:
	var taken: Dictionary = game.state.taken
	match str(step.type):
		"discover": return taken.get("discovered_" + str(step.site), false)
		"boss": return taken.get("site_boss_" + str(step.site), false)
		"enter": return taken.get("story_entered_" + str(step.site), false)
	return false


func chapter_index() -> int:
	for i in range(CHAPTERS.size()):
		if not game.state.taken.get("story_done_" + str(CHAPTERS[i].id), false): return i
	return CHAPTERS.size()


func current_step(index: int) -> Dictionary:
	if index >= CHAPTERS.size(): return {}
	for step in CHAPTERS[index].steps:
		if not _step_done(step): return step
	return {}


func chimes() -> int:
	var count := 0
	for i in range(1, CHAPTERS.size() - 1): count += int(game.state.taken.get("story_done_" + str(CHAPTERS[i].id), false))
	return count


func tick(dt: float) -> void:
	if game.world.get("atlas") == null: return
	if reading_time > 0.0:
		reading_time -= dt
		if reading_time <= 0.0 or (reading.has("from") and game.player.global_position.distance_to(reading.from) > 7.0): close_reading()
	elapsed += dt
	if elapsed < 0.5: return
	elapsed = 0.0
	# Entering a site counts for "find it inside" steps.
	var inside: String = game.world.interior_at(game.player.global_position) if game.world.has_method("interior_at") else ""
	if inside != "" and not game.state.taken.get("story_entered_" + inside, false):
		for chapter in CHAPTERS:
			for step in chapter.steps:
				if str(step.type) == "enter" and str(step.site) == inside: game.state.taken["story_entered_" + inside] = true
	var index := chapter_index()
	if index >= CHAPTERS.size(): return
	var chapter: Dictionary = CHAPTERS[index]
	if announced != str(chapter.id) and reading.is_empty():
		announced = str(chapter.id)
		if not game.state.taken.get("story_begun_" + str(chapter.id), false):
			game.state.taken["story_begun_" + str(chapter.id)] = true
			_show("CHAPTER %d OF %d" % [index + 1, CHAPTERS.size()], str(chapter.title), str(chapter.intro) + "\n\nNext: " + str(current_step(index).get("text", "")))
		_follow()
	if current_step(index).is_empty():
		game.state.taken["story_done_" + str(chapter.id)] = true
		for item in chapter.reward: game.state.award_reward(item, int(chapter.reward[item]))
		game.audio.cue("shrine")
		var reward_bits: Array = []
		for item in chapter.reward: reward_bits.append("%d %s" % [int(chapter.reward[item]), "Light Essence" if item == "shard" else preload("res://scripts/crafting.gd").item_name(item).to_lower()])
		_show("CHAPTER %d COMPLETE" % (index + 1), str(chapter.title), str(chapter.outro) + "\n\nReward: " + ", ".join(reward_bits))
		announced = ""
		game.state.save_game()


## Keep the main story tracked unless the player chose something else.
func _follow() -> void:
	var tracked := str(game.tracked_location)
	if tracked == "" or tracked == "bellcrown" or tracked.begins_with("story_"): game.tracked_location = "story_current"


# --- Navigation and the HUD card --------------------------------------------------------

func destination() -> Dictionary:
	var index := chapter_index()
	if index >= CHAPTERS.size(): return {}
	var step := current_step(index)
	if step.is_empty(): return {}
	var target: Dictionary = game.navigation_destination(str(step.site)) if str(step.site) != "" else {}
	if target.is_empty(): return {}
	return {"id": "story_current", "name": str(CHAPTERS[index].title), "kind": "main story", "pos": target.pos, "region": target.get("region", "")}


func routes() -> Array:
	var result: Array = []
	var current := destination()
	if not current.is_empty(): result.append(current)
	for id in points:
		if game.state.taken.get(id, false): continue
		var region := int(id.get_slice("_", 1)); var index := int(id.get_slice("_", 2))
		var p: Vector3 = points[id]
		result.append({"id": id, "name": "%s · %s" % [LORE[region].region, {"journal": "an old journal", "stone": "a carved stone", "note": "a pinned note"}[LORE[region].pieces[index].kind]], "kind": "lore", "pos": Vector2(p.x, p.z), "region": region})
	return result


func card() -> Dictionary:
	var index := chapter_index()
	if index >= CHAPTERS.size():
		return {"header": "MAIN STORY", "name": "The Dawnbell rings", "objective": "The story is told. Explore, find the remaining lore and earn every keepsake."}
	var step := current_step(index)
	return {"header": "CHAPTER %d OF %d" % [index + 1, CHAPTERS.size()], "name": str(CHAPTERS[index].title), "objective": str(step.get("text", ""))}


func entries() -> Array:
	var result: Array = []
	var index := chapter_index()
	for i in range(CHAPTERS.size()):
		var chapter: Dictionary = CHAPTERS[i]
		if i > index: break
		result.append({"title": chapter.title, "number": i + 1, "done": i < index, "text": chapter.outro if i < index else chapter.intro, "objective": str(current_step(i).get("text", "")) if i == index else ""})
	return result
