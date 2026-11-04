extends RefCounted

const Catalog = preload("res://scripts/crafting.gd")
const Stacks = preload("res://scripts/stack_inventory.gd")
const Art = preload("res://scripts/treasure_art.gd")

static func bundle(source: String, kind: String = "", region: int = 9) -> Dictionary:
	if source == "mosswake_cache_rootglow": return {"herb": 5, "crystal": 3, "tonic": 2, "relic": 1}
	if source == "mosswake_cache_cedarwatch": return {"iron": 6, "mana_potion": 2, "shard": 12, "relic": 2}
	if source.begins_with("site_room_cache_"): return {"relic": 1, "crystal": 2, "shard": 6}
	if source.begins_with("site_side_cache_"): return {"shard": 8, "herb": 3, "tonic": 1}
	if kind == "cave":
		return {"shard": 12, "herb": 3, "crystal": 4, "tonic": 2} if region in [9, 10, 14, 15] else {"shard": 12, "iron": 6, "crystal": 2, "tonic": 2}
	if source.begins_with("site_cache_"): return {"shard": 18, "mana_potion": 2, "relic": 2, "iron": 4}

	return {"relic": 1, "shard": 8, "tonic": 2, "iron": 3}

static func receipt(rewards: Dictionary, unique: String = "") -> String:
	var parts: PackedStringArray = []
	if not unique.is_empty(): parts.append("1 " + Catalog.item_name(unique))
	for item in rewards: parts.append("%d %s" % [int(rewards[item]), Catalog.item_name(str(item))])
	return "Treasure secured: " + ", ".join(parts) + "."

static func claim(game, node: Node3D, id: String, rewards: Dictionary, unique: String = "", extra_flags: Dictionary = {}) -> bool:
	var s = game.state
	if not s._valid_id(id) or s.taken.has(id): return false
	if rewards.is_empty() and unique.is_empty(): return false
	var next_items: Dictionary = s.items.duplicate(true)
	var next_unlocked: Dictionary = s.unlocked.duplicate(true)
	var next_upgrades: Dictionary = s.upgrades.duplicate(true)
	for item in rewards:
		var amount = rewards[item]
		if item not in s.INVENTORY_IDS or not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or int(amount) <= 0 or int(amount) > s.MAX_ITEMS: return false
		if int(next_items.get(item, 0)) + int(amount) > s.MAX_ITEMS:
			game.toast("Make room for this treasure, then claim it again."); return false
		next_items[item] = int(next_items.get(item, 0)) + int(amount)
	var earned_unique = unique
	if not unique.is_empty():
		if unique == "fists": return false
		if Catalog.WEAPONS.has(unique):
			if next_unlocked.get(unique, false): earned_unique = ""
			next_unlocked[unique] = true
		elif Catalog.UPGRADES.has(unique):
			if next_upgrades.get(unique, false): earned_unique = ""
			next_upgrades[unique] = true
		else: return false
	if rewards.is_empty() and earned_unique.is_empty(): return false
	for flag in extra_flags:
		if not s._valid_id(str(flag)) or not extra_flags[flag] is bool: return false


	var baseline = Stacks.reconcile(s._slots, s._inventory_totals(s.items, s.unlocked, s.upgrades))
	var layout = Stacks.reconcile(baseline, s._inventory_totals(next_items, next_unlocked, next_upgrades), false)
	if layout.is_empty():
		game.toast("Make room in your bag for the whole treasure, then try again."); return false
	var old_items: Dictionary = s.items.duplicate(true); var old_slots: Array = s._slots.duplicate(true)
	var old_taken: Dictionary = s.taken.duplicate(true); var old_unlocked: Dictionary = s.unlocked.duplicate(true); var old_upgrades: Dictionary = s.upgrades.duplicate(true)
	var stats = {}
	for field in ["health", "max_health", "stamina", "max_stamina", "mana", "max_mana"]: stats[field] = s.get(field)
	s.items = next_items; s._slots = layout; s.unlocked = next_unlocked; s.upgrades = next_upgrades
	s.taken[id] = true; s.taken.merge(extra_flags, true)
	if not earned_unique.is_empty(): s.refresh_stats()
	if not s.save_game():
		s.items = old_items; s._slots = old_slots; s.taken = old_taken; s.unlocked = old_unlocked; s.upgrades = old_upgrades
		for field in stats: s.set(field, stats[field])
		game.toast("The treasure could not be saved. Nothing was taken; try again."); return false
	if is_instance_valid(node):
		node.set_meta("claimed", true); node.set_meta("label", "Treasure claimed")

		Art.open(node, true, str(node.get_meta("kind", "")) != "deep_cache")
	game.audio.cue("collect"); game.toast(receipt(rewards, earned_unique), 6)
	return true
