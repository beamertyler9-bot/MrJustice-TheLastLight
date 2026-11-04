extends RefCounted


const STRONGHOLD = "dissonance_stronghold"

const STRONGHOLD_GUARDS = [
	{"slot": 1, "kind": "bruiser", "offset": Vector2(-16, 54)},
	{"slot": 5, "kind": "scout", "offset": Vector2(-32, 36)},
	{"slot": 12, "kind": "slinger", "offset": Vector2(0, 15)},
	{"slot": 20, "kind": "scout", "offset": Vector2(-31, -19)},
	{"slot": 26, "kind": "bruiser", "offset": Vector2(-16, -35)},
]
const STRONGHOLD_DRONES = [
	{"slot": 1, "kind": "scout", "walking": false, "offset": Vector2(23, 54)},
	{"slot": 6, "kind": "blast", "walking": true, "offset": Vector2(-23, 0)},
	{"slot": 11, "kind": "echo", "walking": false, "offset": Vector2(23, -34)},
]
static func bandit_ids(camp_id: String) -> Array:
	var slots := STRONGHOLD_GUARDS.map(func (guard): return guard.slot) if camp_id == STRONGHOLD else range(3)
	return slots.map(func (slot): return "scrapper_guard_%s_%d" % [camp_id, slot])
static func entries(site: Dictionary) -> Array:
	var result = []; var id = str(site.id)
	if id != STRONGHOLD:
		var offsets = [Vector2(0, 9), Vector2(4, -1), Vector2(-4, -4)]
		for i in range(3): result.append({"id": bandit_ids(id)[i], "actor": "bandit", "kind": ["scout", "bruiser", "slinger"][i], "offset": offsets[i]})
		var count = 1 + posmod(hash(id), 2)
		for i in range(count): result.append({"id": "scrapper_drone_%s_%d" % [id, i], "actor": "drone", "kind": "scout" if i == 0 else "blast", "walking": posmod(hash(id) + i, 2) == 0, "offset": Vector2(-7, 7) if i == 0 else Vector2(7, 5)})
		return result
	for guard in STRONGHOLD_GUARDS:
		result.append({"id": "scrapper_guard_%s_%d" % [id, guard.slot],
			"actor": "bandit", "kind": guard.kind, "offset": guard.offset})
	for drone in STRONGHOLD_DRONES:
		result.append({"id": "scrapper_drone_%s_%d" % [id, drone.slot],
			"actor": "drone", "kind": drone.kind, "walking": drone.walking, "offset": drone.offset})
	result.append({"id": "scrapper_boss_" + id, "actor": "boss", "kind": "dissonance", "offset": Vector2(0, -52)})
	return result
