extends RefCounted


const B = preload("res://scripts/build.gd")
const Catalog = preload("res://scripts/crafting.gd")
const Stories = preload("res://scripts/scrapper_stories.gd")
const QuestItems = preload("res://scripts/quest_items.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const Enemy = preload("res://scripts/enemy.gd")
const MAX_PATROLS := 6
const REQUESTS := [
	{"id": "pantry_beans", "giver": "brindlewick_merchant", "owner": "Auntie Rowan", "name": "A kettle for every traveler", "type": "supply", "needs": {"coffee_bean": 6}, "text": "My kettle has run dry, and the night travelers will be here soon. Bring me six handfuls of coffee beans; I will keep a cup warm for you.", "return_text": "The kettle is singing again. Every weary traveler has you to thank.", "reward": {"shard": 20, "herb": 3}},
	{"id": "north_trail", "giver": "brindlewick_resident", "owner": "Forester Pip", "name": "The forester's north trail", "type": "hunt", "area": "North trail", "point": Vector2(-9, -17), "radius": 42.0, "goal": 3, "species": "moss_guardian", "text": "Three restless guardians have driven the woodcutters off the north trail. Quiet them between the glade and Embervein, then come tell me the road is safe.", "return_text": "I can hear the axes again. Honest work is back on the trail.", "reward": {"shard": 24, "tonic": 1}},
	{"id": "seed_satchel", "giver": "brindlewick_gardener", "owner": "Juniper", "name": "Juniper's missing seeds", "type": "retrieve", "area": "Embervein approach", "point": Vector2(-22, -23), "key_name": "Juniper's seed satchel", "text": "I set my seed satchel down on the Embervein approach and forgot it in the dusk. Look beside the north road and bring it home before the spring planting.", "return_text": "Every little seed is still here! These will become a whole garden.", "reward": {"shard": 18, "herb": 5}},
	{"id": "forge_fuel", "giver": "brindlewick_smith", "owner": "Bramm Emberhand", "name": "Keep Bramm's forge bright", "type": "supply", "needs": {"wood": 12, "stone": 6}, "text": "The forge needs a sound hearth and a hot fire. Bring twelve timber and six stones. I will trade my labor for yours: good iron and fair Light Essence.", "return_text": "A steady fire, a sound hearth. Now these green hands can get back to work.", "reward": {"iron": 4, "shard": 18}},
	{"id": "garden_wall", "giver": "brindlewick_mason", "owner": "Tansy Stonefoot", "name": "A wall against the weather", "type": "supply", "needs": {"stone": 12}, "text": "The winter frost opened every joint in the garden wall. Twelve stones will make it sound before the next rain. Bring them here; I will do the fitting.", "return_text": "There. A wall that will stand another winter. You have built a little piece of home.", "reward": {"shard": 24, "coffee": 2}},
	{"id": "camp_supper", "giver": "brindlewick_baker", "owner": "Nim Honeybun", "name": "Something sweet for supper", "type": "supply", "needs": {"marshmallow": 4}, "text": "The little ones are sharing supper by the village fire. Four marshmallows would turn an ordinary evening into a celebration. Could you spare them?", "return_text": "Four sticky smiles, guaranteed. Thank you for making an ordinary evening special.", "reward": {"shard": 12, "herb": 6}},
	{"id": "lost_spindle", "giver": "brindlewick_weaver", "owner": "Lethiel Fernsong", "name": "The spindle in the grass", "type": "retrieve", "area": "East road meadows", "point": Vector2(28, 22), "key_name": "Lethiel's silver spindle", "text": "My silver spindle slipped from my basket in the east-road meadows. It was my mother's. Find its blue ribbon in the grass and bring it back to me.", "return_text": "That ribbon is older than half the village. You have brought a family memory home.", "reward": {"shard": 22, "crystal": 2}},
	{"id": "bridge_watch", "giver": "brindlewick_porter", "owner": "Tobin Reed", "name": "A clear road for the carts", "type": "hunt", "area": "East road crossing", "point": Vector2(34, 32), "radius": 29.0, "goal": 3, "species": "wild_boar", "text": "The east-road crossing is overrun, and our supply carts cannot pass. Deal with three dangers around the crossing, then report back so I can send the drivers.", "return_text": "I will send the flour cart first. The bakers will cheer when they hear.", "reward": {"shard": 26, "coffee_bean": 4}},
	{"id": "market_manifest", "giver": "ironbell_merchant", "owner": "Mara of the Market", "name": "The missing market ledger", "type": "retrieve", "area": "Old bell road", "point": Vector2(88, 39), "key_name": "Mara's market ledger", "text": "A cart lost my market ledger on the old bell road, west of the crypt. Without it I cannot pay the small traders. Recover the leather book and bring it straight to me.", "return_text": "Every trader will be paid on time. That matters more than all the gold in a royal vault.", "reward": {"shard": 30, "tonic": 2}},
	{"id": "three_seals", "giver": "ironbell_resident", "owner": "Bellkeeper Oren", "name": "Three voices in the crypt", "type": "dungeon", "area": "Bellkeeper's Crypt", "route": "dungeon", "flags": ["deep_seal_ember", "deep_seal_echo", "deep_seal_tide"], "text": "The old crypt's Ember, Echo and Tide seals have fallen silent. Awaken all three side chapels, then return. Their light will endure even if you fall along the way.", "return_text": "Three voices answer again. The Bellkeeper's court is open. Now there is hope.", "reward": {"shard": 36, "tonic": 3}},
	{"id": "willow_remedy", "giver": "ironbell_gardener", "owner": "Sable Willow", "name": "A remedy for the watch", "type": "supply", "needs": {"herb": 10}, "text": "The night watch has come down with marsh fever. Bring ten healing herbs. I will steep them properly, and put aside fresh tonic for your own journey.", "return_text": "The first pot is ready. The watch can rest tonight because you helped.", "reward": {"shard": 20, "tonic": 3}},
	{"id": "hesters_alloy", "giver": "ironbell_smith", "owner": "Hester Ironhand", "name": "Hester's bright alloy", "type": "supply", "needs": {"iron": 6, "crystal": 3}, "text": "I am testing an alloy that holds its edge through the cold. Six iron and three crystals will make the sample. Bring both together; a good experiment needs a fair measure.", "return_text": "Look at that edge catch the light. This will change the way we make tools.", "reward": {"shard": 50, "stone": 8}},
	{"id": "quarry_watch", "giver": "ironbell_mason", "owner": "Dori Copperbraid", "name": "The silent quarry", "type": "hunt", "area": "Amberwood quarry", "point": Vector2(72, -45), "radius": 30.0, "goal": 3, "species": "thorn_wolf", "text": "Three prowlers have stopped work around the Amberwood quarry. Clear the quarry approaches so my stonecutters can return, then bring me the good news.", "return_text": "The stonecutters can earn their living again. You did more than swing a fist out there.", "reward": {"shard": 30, "iron": 4}},
	{"id": "warm_cups", "giver": "ironbell_baker", "owner": "Pella Crumb", "name": "Three cups before dawn", "type": "supply", "needs": {"coffee": 3}, "text": "My apprentices start baking before dawn. Brew three camp coffees over a lit fire and bring them to me. Warm hands make better bread.", "return_text": "Three warm cups for three sleepy bakers. Tomorrow's loaves will taste all the better.", "reward": {"shard": 24, "tonic": 2}},
	{"id": "forgotten_pattern", "giver": "ironbell_weaver", "owner": "Ilyra Threadsong", "name": "A pattern worth remembering", "type": "retrieve", "area": "Glasswood foothills", "point": Vector2(100, -65), "key_name": "Ilyra's pattern case", "text": "I was sketching the Glasswood foothills when the wind took my pattern case. Find it below the eastern mountain and return it. No two winters leave the same pattern.", "return_text": "These lines are the shape of a whole season. I thought they were lost forever.", "reward": {"shard": 28, "crystal": 3}},
	{"id": "bellroad_watch", "giver": "ironbell_porter", "owner": "Gorrin Goodbarrel", "name": "Bells along the supply road", "type": "hunt", "area": "Crypt supply road", "point": Vector2(104, 51), "radius": 29.0, "goal": 3, "species": "glass_skitter", "text": "Three lurking beasts keep scattering the caravans on the road to the crypt. Drive them off around the eastern supply road and report back. Nobody should travel it alone.", "return_text": "The caravan bells sound friendly again. That is what a safe road should sound like.", "reward": {"shard": 32, "coffee_bean": 6}},
	{"id": "embermaw_oath", "giver": "brindlewick_resident", "owner": "Forester Pip", "requires": "north_trail", "name": "The heart under the mountain", "type": "dungeon", "area": "Embervein depths", "route": "mine", "flags": ["deep_boss_embermaw"], "text": "The trail is safe, but the trouble comes from deeper down. Explore Embervein's branching caves and defeat Embermaw in the deepest hollow. Then let me know the mountain can sleep.", "return_text": "For the first time in years, the mountain is quiet. You have my word: we will remember this.", "reward": {"shard": 55, "relic": 2}},
	{"id": "fen_watch", "giver": "brindlewick_gardener", "owner": "Juniper", "requires": "seed_satchel", "name": "Roots of the old garden", "type": "hunt", "area": "Mossbound ruins", "point": Vector2(-84, -65), "radius": 33.0, "goal": 3, "species": "moss_guardian", "text": "The old garden at the Mossbound ruins has become dangerous. Quiet three restless guardians there. I would like the children to see its flowers one day.", "return_text": "Perhaps the flowers will return before summer. I will take the children there myself.", "reward": {"shard": 34, "herb": 8}},
	{"id": "core_for_bramm", "giver": "brindlewick_smith", "owner": "Bramm Emberhand", "requires": "forge_fuel", "name": "A heartstone for honest hands", "type": "supply", "needs": {"ancient_core": 1}, "text": "The deep guardians carry ancient cores. Bring me one, and I will learn how to work it safely. I will give you iron for your own Warden Plate in return.", "return_text": "Warm, even here in my palm. This old craft is not lost after all.", "reward": {"shard": 30, "iron": 10}},
	{"id": "rowans_locket", "giver": "brindlewick_merchant", "owner": "Auntie Rowan", "requires": "pantry_beans", "name": "A little light from long ago", "type": "retrieve", "area": "Westreach ruins trail", "point": Vector2(-69, -73), "key_name": "Rowan's copper locket", "text": "I lost a copper locket on the trail beyond Westreach. There is a portrait inside, from before the old roads fell quiet. Find it if you can. There are things Light Essence cannot replace.", "return_text": "He still looks exactly as I remember him. Sit a moment. The kettle is always on for you.", "reward": {"shard": 38, "relic": 1}},
	{"id": "last_bell", "giver": "ironbell_resident", "owner": "Bellkeeper Oren", "requires": "three_seals", "name": "When the last bell falls", "type": "dungeon", "area": "Bellkeeper's court", "route": "dungeon", "flags": ["deep_boss_bellkeeper"], "text": "You woke the chapels. Now the Hollow Bellkeeper waits in his court beyond the sealed hall. Defeat him, and return so we may ring a bell for the living.", "return_text": "At last, a bell for the living. You have released more than stone from that place.", "reward": {"shard": 70, "ancient_core": 1}},
	{"id": "dawn_for_the_forge", "giver": "ironbell_smith", "owner": "Hester Ironhand", "requires": "hesters_alloy", "name": "The dawn vault's promise", "type": "dungeon", "area": "Dawn Vault", "route": "dungeon", "flags": ["deep_vault_dawn"], "text": "There is a vault beyond the Bellkeeper's court, still bound to his oath. Open the Dawn Vault and bring me word of the craft you find there. Its promise belongs to the whole frontier.", "return_text": "A dawn blade, after all these years. Perhaps the old masters would approve of our little forge.", "reward": {"shard": 60, "crystal": 6}},
	{"id": "tuning_fork", "giver": "ironbell_weaver", "owner": "Ilyra Threadsong", "requires": "forgotten_pattern", "name": "The song on the north wind", "type": "retrieve", "area": "Old bell road north", "point": Vector2(15, -83), "key_name": "Ilyra's tuning fork", "text": "My loom's tuning fork slipped from the pack along the northern bell road. Find the little brass fork beside the road and return it. I weave best when the loom can sing.", "return_text": "Listen. A single clear note. Now I can finish the song in these threads.", "reward": {"shard": 32, "relic": 1}},
	{"id": "provisions_for_the_pass", "giver": "ironbell_porter", "owner": "Gorrin Goodbarrel", "requires": "bellroad_watch", "name": "Provisions for the high pass", "type": "supply", "needs": {"roasted_marshmallow": 4, "tonic": 2}, "text": "A relief crew is heading for the high pass. Bring four roasted marshmallows and two tonics so nobody has to turn back hungry or hurt. We look after one another out here.", "return_text": "A full pack and a little kindness. That is how a crew makes it home.", "reward": {"shard": 52, "iron": 6}}
]
var game
var requests: Array = REQUESTS.duplicate(true)
var pickups: Dictionary = {}
var pickup_points: Dictionary = {}
var patrols: Dictionary = {}
var elapsed := 0.0

func setup(owner_game) -> void:
	game = owner_game
	requests = REQUESTS.duplicate(true)
	requests.append_array(Stories.REQUESTS.duplicate(true))
	for request in requests:
		var id = str(request.id)
		if Stories.FETCH.has(id) and (not accepted(id) or game.state.taken.get(_flag(id, "keepsake_v2"), false)):
			request.type = "retrieve"
			request.merge(Stories.FETCH[id], true)

			for original in REQUESTS:
				if original.id == Stories.FETCH_ANCHOR[id]: request.point = original.point + Vector2(2.0, 1.0)
			request.return_text = "You brought it home. A good tool carries a little of everyone who used it. Thank you."
		if request.type == "retrieve":
			request.item = QuestItems.item_for(id)
			request.key_name = Catalog.item_name(request.item)

			if accepted(id) and not completed(id) and game.state.taken.get(_flag(id, "recovered"), false) and int(game.state.items.get(request.item, 0)) == 0:
				game.state.award_reward(request.item, 1)
	if game.world.get("atlas") != null:
		var points = preload("res://scripts/fixed_world.gd").service_points("quest_points")
		for request in requests:
			if points.has(request.id): request.point = points[request.id]
			elif Stories.FETCH.has(request.id) and request.type == "retrieve":
				var anchor = str(Stories.FETCH_ANCHOR.get(request.id, "seed_satchel"))
				if points.has(anchor): request.point = points[anchor] + Vector2(5.0, 3.0)
	pickups.clear(); patrols.clear(); pickup_points.clear()
	for request in requests:
		if request.type == "retrieve":
			var point := _safe_surface(request.point)
			if point != Vector3.INF:
				pickup_points[request.id] = point
				if not game.world.reserved_cache_positions.has(point): game.world.reserved_cache_positions.append(point)
	restore_tracking()
	_refresh_pickups()

func restore_tracking() -> void:
	for request in requests:
		if game.state.taken.get(_flag(request.id, "tracked"), false) and not completed(request.id):
			game.tracked_location = "quest_" + str(request.id)
			return

func definition(id: String) -> Dictionary:
	for request in requests:
		if request.id == id: return request
	return {}

func _flag(id: String, part: String) -> String: return "quest_%s_%s" % [id, part]

func accepted(id: String) -> bool: return bool(game.state.taken.get(_flag(id, "accepted"), false))

func completed(id: String) -> bool: return bool(game.state.taken.get(_flag(id, "claimed"), false))

func available(id: String) -> bool:
	var request := definition(id)
	return not request.is_empty() and (not request.has("requires") or completed(str(request.requires)))

func progress(id: String) -> int:
	var request := definition(id)
	if request.is_empty() or not accepted(id): return 0
	match str(request.type):
		"hunt":
			var amount := 0
			var prefix := _flag(id, "victim_")
			for key in game.state.taken:
				if str(key).begins_with(prefix) and game.state.taken[key] == true: amount += 1
			return mini(amount, int(request.goal))
		"retrieve": return int(game.state.taken.get(_flag(id, "recovered"), false) and int(game.state.items.get(request.item, 0)) == 1)
		"story":
			var amount := 0
			for step in request.steps:
				if not _step_done(step): break
				amount += 1
			return amount
		"dungeon":
			var amount := 0
			for flag in request.flags: amount += int(game.state.taken.get(flag, false))
			return amount
		"supply":
			var amount := 0
			for item in request.needs: amount += mini(int(game.state.items.get(item, 0)), int(request.needs[item]))
			return amount
	return 0

func goal(id: String) -> int:
	var request := definition(id)
	match str(request.get("type", "")):
		"hunt": return int(request.goal)
		"dungeon": return request.flags.size()
		"story": return request.steps.size()
		"supply":
			var amount := 0
			for value in request.needs.values(): amount += int(value)
			return amount
	return 1

func ready(id: String) -> bool: return accepted(id) and not completed(id) and progress(id) >= goal(id)

func _at_giver(request: Dictionary) -> bool:
	return is_instance_valid(game.vendor) and is_instance_valid(game.player) and str(game.vendor.get_meta("id", "")) == str(request.giver) and game.mode == "dialogue" and game.player.global_position.distance_to(game.vendor.global_position) <= 3.6

func _snapshot() -> Dictionary:
	return {"items": game.state.items.duplicate(true), "taken": game.state.taken.duplicate(true), "slots": game.state._slots.duplicate(true), "unlocked": game.state.unlocked.duplicate(true), "upgrades": game.state.upgrades.duplicate(true), "equipment": game.state.equipment, "selected": game.state.selected_hotbar, "tracked": game.tracked_location}

func _rollback(before: Dictionary) -> void:
	game.state.items = before.items; game.state.taken = before.taken; game.state._slots = before.slots
	game.state.unlocked = before.unlocked; game.state.upgrades = before.upgrades
	game.state.equipment = before.equipment; game.state.selected_hotbar = before.selected; game.tracked_location = before.tracked

func _select_track(id: String) -> void:
	for request in requests: game.state.taken[_flag(request.id, "tracked")] = request.id == id
	game.tracked_location = "quest_" + id

func accept(id: String) -> bool:
	var request := definition(id)
	if not available(id) or accepted(id) or not _at_giver(request): return false
	var before := _snapshot()
	game.state.taken[_flag(id, "accepted")] = true
	if Stories.FETCH.has(id) and request.type == "retrieve": game.state.taken[_flag(id, "keepsake_v2")] = true
	_select_track(id)
	if not game.state.save_game():
		_rollback(before); return false
	_refresh_pickups()
	_notify("Request accepted: " + str(request.name) + ". " + objective(id), 5)
	return true

func claim(id: String) -> bool:
	var request := definition(id)
	if request.is_empty() or not ready(id) or not _at_giver(request): return false
	var before := _snapshot()
	var next: Dictionary = game.state.items.duplicate(true)
	if request.type == "supply":
		for item in request.needs: next[item] = int(next.get(item, 0)) - int(request.needs[item])
	elif request.type == "retrieve": next[request.item] = int(next.get(request.item, 0)) - 1
	elif request.type == "story":
		for step in request.steps:
			if step.has("item"): next[step.item] = int(next.get(step.item, 0)) - 1
	for item in request.reward:
		if int(next.get(item, 0)) + int(request.reward[item]) > game.state.MAX_ITEMS:
			_notify("Your " + Catalog.item_name(item).to_lower() + " count is at its limit. This reward is waiting with " + str(request.owner) + ".", 5)
			return false
		next[item] = int(next.get(item, 0)) + int(request.reward[item])



	var layout: Array = game.state.Stacks.reconcile(before.slots, game.state._inventory_totals(before.items, before.unlocked, before.upgrades))
	layout = game.state.Stacks.reconcile(layout, game.state._inventory_totals(next, before.unlocked, before.upgrades), false)
	if layout.is_empty():
		_notify("Make room in your pack. This reward is waiting with " + str(request.owner) + ".", 5)
		return false
	game.state.items = next
	game.state._slots = layout
	game.state.taken[_flag(id, "claimed")] = true
	game.state.taken[_flag(id, "tracked")] = false
	if game.tracked_location == "quest_" + id: game.tracked_location = "ironbell" if str(request.giver).begins_with("ironbell_") else "brindlewick"
	if not game.state.save_game():
		_rollback(before); return false
	_notify(str(request.return_text) + "  Reward: " + reward_text(id), 6)
	return true

func reward_text(id: String) -> String:
	var pieces: PackedStringArray = []
	for item in definition(id).get("reward", {}): pieces.append("%d %s" % [int(definition(id).reward[item]), Catalog.item_name(item).to_lower()])
	return " · ".join(pieces)

func objective(id: String) -> String:
	var request := definition(id)
	if request.is_empty(): return ""
	if completed(id): return "Returned to " + str(request.owner)
	if not accepted(id): return "Speak to " + str(request.owner)
	if ready(id): return "Return to " + str(request.owner) + " for your reward"
	match str(request.type):
		"hunt": return "%s · defeat %d / %d threats" % [request.area, progress(id), goal(id)]
		"retrieve": return "Find " + str(request.key_name) + " · " + str(request.area)
		"story":
			var index := progress(id)
			return "%d / %d · %s" % [index, goal(id), str(request.steps[index].text)]
		"dungeon": return "%s · %d / %d objectives" % [request.area, progress(id), goal(id)]
		"supply":
			var pieces: PackedStringArray = []
			for item in request.needs: pieces.append("%s %d / %d" % [Catalog.item_name(item), mini(int(game.state.items.get(item, 0)), int(request.needs[item])), int(request.needs[item])])
			return "Bring " + " · ".join(pieces)
	return ""

func entry(id: String) -> Dictionary:
	var request := definition(id)
	if request.is_empty(): return {}
	var result: Dictionary = request.duplicate(true)
	result.accepted = accepted(id); result.completed = completed(id); result.ready = ready(id)
	result.available = available(id); result.progress = progress(id); result.goal = goal(id)
	result.objective = objective(id); result.reward_text = reward_text(id)
	result.status = "Returned" if result.completed else ("Return to owner" if result.ready else ("In progress" if result.accepted else ("Available" if result.available else "Help this resident first")))
	return result

func entries() -> Array:
	var active: Array = []; var offers: Array = []; var finished: Array = []
	for request in requests:
		var value := entry(str(request.id))
		if value.completed: finished.append(value)
		elif value.accepted: active.append(value)
		else: offers.append(value)
	return active + offers + finished

func offer_for(npc_id: String) -> Dictionary:


	for priority in ["accepted", "story", "ordinary"]:
		for request in requests:
			if request.giver != npc_id or completed(request.id) or not available(request.id): continue
			if priority == "accepted" and not accepted(request.id): continue
			if priority == "story" and request.type != "story": continue
			return entry(request.id)
	return {}

func _giver_point(request: Dictionary) -> Vector2:
	for resident in game.world.residents:
		if is_instance_valid(resident) and resident.get_meta("id", "") == request.giver: return Vector2(resident.global_position.x, resident.global_position.z)
	if game.world.atlas != null: return game.world.atlas.nodes.ironbell if str(request.giver).begins_with("ironbell_") else game.world.atlas.nodes.brindlewick
	return Vector2(65, 12) if str(request.giver).begins_with("ironbell_") else Vector2(-32, 18)

func destinations() -> Array:
	var routes: Array = []
	for request in requests:
		var id := str(request.id)
		if completed(id) or not available(id): continue
		if not accepted(id) and not game.state.taken.get(_flag(id, "tracked"), false): continue
		var p := _giver_point(request)
		var name_value := "Return to " + str(request.owner)
		if not accepted(id): name_value = "Speak to " + str(request.owner)
		elif not ready(id) and request.type == "story":
			var step: Dictionary = request.steps[progress(id)]
			var site := _site(str(step.site))
			if site.is_empty(): continue
			p = site.pos
			name_value = str(step.text)
		elif not ready(id) and request.type in ["hunt", "retrieve"]:
			p = request.point
			if pickup_points.has(id): p = Vector2(pickup_points[id].x, pickup_points[id].z)
			name_value = str(request.area) + " · " + str(request.name)
		elif not ready(id) and request.type == "dungeon":
			p = Vector2(-16, -45) if request.route == "mine" else Vector2(118, 47)
			if game.world.atlas != null:
				var gate = game.world.regional._gate("legacy_mine" if request.route == "mine" else "valley-d01"); p = Vector2(gate.x, gate.z)
			name_value = str(request.area) + " · " + str(request.name)
		routes.append({"id": "quest_" + id, "name": name_value, "kind": "quest", "pos": p})
	return routes

func track(id: String) -> bool:
	if definition(id).is_empty() or completed(id) or not available(id): return false
	var before := _snapshot()
	_select_track(id)
	if not game.state.save_game():
		_rollback(before); return false
	return true

func handle(tag: String) -> bool:
	var parts := tag.split(":")
	if parts.size() != 2: return false
	match parts[0]:
		"quest_accept": accept(parts[1])
		"quest_claim": claim(parts[1])
		"quest_track": track(parts[1])
		_: return false
	return true

func enemy_defeated(enemy_id: String, point: Vector3, _kind: String = "") -> void:
	if enemy_id.is_empty() or not point.is_finite(): return
	var changed := false
	for request in requests:
		if request.type != "hunt" or not accepted(request.id) or completed(request.id) or ready(request.id): continue
		if absf(point.y - game.world.surface_height_at(point.x, point.z)) > 12.0: continue
		if Vector2(point.x, point.z).distance_to(request.point) > float(request.radius):



			var patrol = patrols.get(enemy_id)
			if not is_instance_valid(patrol) or str(patrol.get_meta("quest", "")) != str(request.id): continue
			var home: Vector3 = patrol.home
			if Vector2(home.x, home.z).distance_to(request.point) > float(request.radius) or home.distance_to(point) > 35.0: continue
		var key := _flag(request.id, "victim_" + enemy_id.sha256_text().substr(0, 24))
		if game.state.taken.get(key, false): continue
		game.state.taken[key] = true; changed = true
		_notify(str(request.name) + " · " + ("Area clear. Return to " + str(request.owner) if ready(request.id) else "%d / %d" % [progress(request.id), goal(request.id)]), 4)
	if changed: game.state.save_game()

func _site(id: String) -> Dictionary:
	var component = game.get("scrappers")
	return component.site(id) if component != null else {}

func _step_done(step: Dictionary) -> bool:
	if step.has("item"): return int(game.state.items.get(step.item, 0)) == 1
	return bool(game.state.taken.get(step.get("flag", ""), false))

func interact(node: Node3D) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_meta("kind", "") != "quest_pickup" or not game.world.is_ancestor_of(node): return false
	var id := str(node.get_meta("quest", "")); var request := definition(id)
	if request.is_empty() or not accepted(id) or completed(id) or ready(id): return false
	if not is_instance_valid(game.player) or game.player.global_position.distance_to(node.global_position) > 3.6: return false
	var item := str(node.get_meta("item", request.get("item", "")))
	if not QuestItems.is_quest(item): return false
	if request.type == "story":
		var step: Dictionary = request.steps[progress(id)]
		if step.get("item", "") != item: return false
	elif game.state.taken.get(_flag(id, "recovered"), false): return false
	var before := _snapshot()
	if not game.state.harvest(_flag(id, "key_" + item), item, 1):
		_rollback(before)
		_notify("Make room in your satchel for " + Catalog.item_name(item) + ". It is waiting here.", 4); return false
	game.state.taken[_flag(id, "recovered")] = true
	if not game.state.save_game():
		_rollback(before); return false
	_notify("Recovered " + Catalog.item_name(item) + ". " + objective(id), 5)
	node.queue_free(); pickups.erase(id)
	return true

func _notify(message: String, seconds: float = 4.0) -> void:
	if game.has_method("toast"): game.toast(message, seconds)

func _safe_surface(origin: Vector2) -> Vector3:
	for index in range(81):
		var ring := ceili(float(index) / 12.0)
		var angle := index * TAU / 12.0
		var p := origin + Vector2.from_angle(angle) * float(ring) * 1.75
		var height: float = game.world.surface_height_at(p.x, p.y)
		if height <= game.world.water_level + 0.8: continue
		var clear := true
		for offset in [Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0, -0.6), Vector2(0, 0.6)]:
			if absf(game.world.surface_height_at(p.x + offset.x, p.y + offset.y) - height) > 0.48: clear = false; break
		if not clear: continue
		var point := Vector3(p.x, height + 0.06, p.y)
		if game.world.is_inside_tree():
			var shape := BoxShape3D.new(); shape.size = Vector3(0.85, 1.2, 0.85)
			var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape
			query.transform.origin = point + Vector3.UP * 0.75
			query.collision_mask = 1 | 8
			if not game.world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
		return point
	return Vector3.INF

func _refresh_pickups() -> void:
	for request in requests:
		var id := str(request.id)
		if request.type not in ["retrieve", "story"] or not accepted(id) or completed(id) or ready(id): continue
		if is_instance_valid(pickups.get(id)): continue
		var item := str(request.get("item", ""))
		var point := Vector3.INF
		if request.type == "story":
			var step: Dictionary = request.steps[progress(id)]
			if not step.has("item"): continue
			item = str(step.item)
			var site := _site(str(step.site))
			if site.is_empty(): continue
			var anchor: Vector3 = site.point
			point = _safe_surface(Vector2(anchor.x, anchor.z) + Vector2(1.8, 1.8))
		else:
			if not pickup_points.has(id):
				var found := _safe_surface(request.point)
				if found == Vector3.INF: continue
				pickup_points[id] = found
			point = pickup_points[id]
		if point == Vector3.INF: continue
		var node := Node3D.new(); node.name = "QuestPickup_" + id
		node.set_meta("id", _flag(id, "key")); node.set_meta("quest", id); node.set_meta("item", item)
		node.set_meta("kind", "quest_pickup"); node.set_meta("label", "Recover " + Catalog.item_name(item))
		node.add_to_group("interactable"); node.add_to_group("quest_pickup")
		game.world.add_child(node); node.global_position = point
		ItemModels.build(node, item)
		B.ring(node, Vector3(0, 0.025, 0), 0.4, 0.018, B.mat("#90ddd9", 0, 0.35))
		pickups[id] = node

func _loaded(point: Vector3) -> bool:
	return game.world.chunks.has(Vector2i(floori(point.x / game.world.CHUNK), floori(point.z / game.world.CHUNK)))

func _tick_patrols() -> void:
	for id in patrols.keys():
		var foe = patrols[id]
		if not is_instance_valid(foe) or foe.is_queued_for_deletion(): patrols.erase(id); continue
		var request := definition(str(foe.get_meta("quest", "")))
		if request.is_empty() or completed(request.id) or ready(request.id) or foe.global_position.distance_to(game.player.global_position) > 95.0 or not _loaded(foe.global_position):
			foe.queue_free(); patrols.erase(id)
	for request in requests:
		if request.type != "hunt" or not accepted(request.id) or completed(request.id) or ready(request.id): continue
		if Vector2(game.player.global_position.x, game.player.global_position.z).distance_to(request.point) > 76.0: continue
		for index in range(3):
			if patrols.size() >= MAX_PATROLS: return
			var id := "quest_patrol_%s_%d" % [request.id, index]
			if is_instance_valid(patrols.get(id)) or game.state.taken.get(id, false) or game.state.taken.get(_flag(request.id, "victim_" + id.sha256_text().substr(0, 24)), false): continue
			var intended: Vector2 = request.point + Vector2.from_angle(float(index) * TAU / 3.0) * 7.0
			var point := _safe_surface(intended)
			if point == Vector3.INF or not _loaded(point): continue
			var foe = Enemy.new(); foe.game = game; foe.id = id
			if foe.has_method("configure_species"): foe.configure_species(str(request.get("species", "moss_guardian")))
			foe.set_meta("quest", request.id)
			game.world.add_child(foe); foe.global_position = point + Vector3.UP * 0.15; foe.home = foe.global_position
			patrols[id] = foe

func tick(dt: float) -> void:
	if game == null or not is_instance_valid(game.world) or not is_instance_valid(game.player): return
	elapsed += maxf(0, dt)
	if elapsed < 1.0: return
	elapsed = 0.0
	_refresh_pickups()
	if game.mode == "play": _tick_patrols()
