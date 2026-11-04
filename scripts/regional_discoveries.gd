extends RefCounted

const B = preload("res://scripts/build.gd")
const P = preload("res://scripts/locations.gd")

static func island(world, parent: Node3D, group: Dictionary, index: int, at: Vector3) -> void:
	var garden = Node3D.new(); garden.position = at; garden.name = "SkyGarden_" + str(index); parent.add_child(garden)
	var region: int = group.region
	for side in [-1, 1]:
		var p = Vector3(side * 4.5, 0, -2.8 + index * 0.12)
		var tree = load("res://scripts/regional_trees.gd").place(garden, region, 2.4 if region == 12 else 3.8, side * 0.7 + index * 0.3); tree.position = p
	var key = "sky_cache_%s_%s" % [region, index]
	if not world.state.taken.has(key):
		var cache = P.interaction(parent, key, "regional_discovery", "Read the sky journal and secure its supplies", at + Vector3(3, 0.45, 2.7)); cache.name = key
		cache.set_meta("rewards", {"shard": 6, "crystal": 1}); cache.set_meta("note", str(group.names[index]) + ": an old skyfarer's journal marks this garden and the free route home.")
		load("res://scripts/treasure_art.gd").build(cache, Vector3(0.8, 0.9, 0.6))
		load("res://scripts/world_overhaul.gd").support_box(cache, Vector3.ZERO, Vector3(0.8, 0.6, 0.6))
	parent.set_meta("regional_islands", int(parent.get_meta("regional_islands", 0)) + 1)

static func claim(game, node: Node3D) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not game.world.is_ancestor_of(node): return false
	var state = game.state; var id = str(node.get_meta("id", ""))
	if not id.begins_with("sky_cache_") or state.taken.has(id): return false
	var items: Dictionary = state.items.duplicate(true); var slots: Array = state.inventory_slots().duplicate(true); var flags: Dictionary = state.taken.duplicate(true)
	var ok := true
	for item in node.get_meta("rewards", {}):
		var count: int = node.get_meta("rewards")[item]
		if state.award_reward(item, count) != count: ok = false; break
	state.taken[id] = true
	if not ok or not state.save_game():
		state.items = items; state._slots = slots; state.taken = flags; game.toast("The discovery could not be saved or your supplies are full. Nothing was taken."); return false
	load("res://scripts/treasure_art.gd").open(node, true, true); game.audio.cue("collect"); game.toast(str(node.get_meta("note")), 6); return true
