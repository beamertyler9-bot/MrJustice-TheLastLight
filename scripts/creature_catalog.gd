extends RefCounted

const S = preload("res://scripts/region_sites.gd")
const ALIASES = {"ironhide_boar": "wild_boar", "the_bellkeeper": "bellkeeper"}
const LEGACY_WILD = {"starwing_moth": "moth", "fernhare": "hare", "glimmerstag": "deer", "mistrunner_fox": "fox", "dawnbell_songbird": "bird", "mossbrow_boar": "boar"}
const BOSSES = {"valley-c08": "stonejaw_wyrm", "food-d06": "grand_confectioner", "plains-d06": "stormhorn_matriarch", "desert-d02": "glass_anubid", "haunted-d02": "pale_watcher", "haunted-d01": "blackthorn_regent", "crystal-d06": "aurora_custodian"}
const FORMS = {
	"starwing_moth": "moth", "fernhare": "hare", "glimmerstag": "deer", "mossbrow_boar": "boar", "craghorn_goat": "goat", "riverglass_kingfisher": "bird",
	"mallow_sheep": "sheep", "cocoa_chipmunk": "rodent", "fizz_frog": "frog", "fizz_toad": "frog", "slosh_axolotl": "lizard", "graham_tortoise": "tortoise", "caramel_dormouse": "rodent", "sugarwing_bee": "bee",
	"dawnbell_songbird": "bird", "meadowhopper": "hopper", "windtail_hare": "hare", "reedcrest_crane": "crane", "goldmane_antelope": "antelope", "streamback_turtle": "tortoise",
	"mistrunner_fox": "fox", "sandshell_lizard": "lizard", "dune_jerboa": "rodent", "oasis_ibis": "crane", "amber_scarab": "beetle", "shadeback_camel": "camel",
	"ember_salamander": "lizard", "ash_moth": "moth", "basalt_beetle": "beetle", "copperback_gecko": "lizard", "cinderfin_fish": "fish", "ventwing_swift": "bird",
	"ashen_raven": "bird", "pallid_moth": "moth", "gravemoss_snail": "snail", "prismhart": "deer", "opaline_otter": "otter", "chimewing_manta": "manta", "geode_tortoise": "tortoise", "faceted_finch": "bird", "quartz_hare": "hare",
	"cliffwarden": "golem", "stonejaw_wyrm": "wyrm", "fudge_golem": "golem", "cocoa_knight": "knight", "chocobar_croc": "crawler", "wrapper_mimic": "mimic", "pretzel_crawler": "crawler", "cola_sloshback": "frog", "sugarspike_wasp": "winged", "grand_confectioner": "knight",
	"windwhistle_stalker": "cat", "thistle_jackal": "hound", "grassland_colossus": "golem", "kiteclaw_raptor": "winged", "stormhorn_matriarch": "boar", "storm_bison": "boar", "thunder_rhino": "boar", "stormcloud_muskox": "boar", "stormfrill": "boar", "thunderclub": "boar", "dune_maw": "wyrm", "pit_antlion": "crawler", "dune_monitor": "wyrm", "thorn_devil": "lizard", "sunken_sentinel": "knight", "pharaoh_guardian": "knight", "lion_warden": "knight", "sandwraith": "wraith", "obelisk_scorpion": "scorpion", "glass_anubid": "hound",
	"riftback": "armored", "furnace_hound": "hound", "slag_crawler": "crawler", "ash_harpy": "winged", "root_reaper": "reaper", "wraithhart": "deer", "hollow_hound": "hound", "grave_creeper": "crawler", "veil_moth": "winged", "thorn_widow": "spider", "mourning_knight": "knight", "pale_watcher": "wraith", "blackthorn_regent": "knight",
	"shard_sentinel": "knight", "prismstalker": "cat", "geode_mimic": "mimic", "resonance_wyrm": "wyrm", "glasswing_reaver": "winged", "aurora_custodian": "wraith"}
static var roster: Array = []
static var lookup: Dictionary = {}
static func entries() -> Array:
	if not roster.is_empty(): return roster
	S.catalog()
	for raw in S.data.creatures:
		var entry: Dictionary = raw.duplicate(true); entry.region = int(entry.region)

		if entry.id == "cola_slime": entry.id = "cola_sloshback"; entry.name = "Cola Sloshback"; entry.hook = "A stout amber amphibian with a bubble throat; swells and rattles before a fizzy spray."
		entry.form = FORMS.get(entry.id, "golem"); roster.append(entry); lookup[entry.id] = entry
	return roster
static func entry(id: String) -> Dictionary:
	entries(); return lookup.get(id, {})
static func enemy_id(id: String) -> String: return str(ALIASES.get(id, id))
static func wildlife_for(region: int) -> Array:
	return entries().filter(func (e): return e.region == region and e.kind == "wildlife").map(func (e): return e.id)
static func hostiles_for(region: int) -> Array:
	return entries().filter(func (e): return e.region == region and e.kind == "hostile" and not e.boss).map(func (e): return enemy_id(e.id))
## Big storm beasts roam the plains but are a rare sight: each is picked this often compared
## with an ordinary hostile (1.0).
const RARITY = {"storm_bison": 0.2, "thunder_rhino": 0.2, "stormcloud_muskox": 0.2, "stormfrill": 0.2, "thunderclub": 0.2, "pit_antlion": 0.35, "dune_monitor": 0.35, "pharaoh_guardian": 0.35, "lion_warden": 0.35}
## Picks one of `options` from `seed`, the same every time for the same seed, with rare
## species weighted down.
static func pick_hostile(options: Array, seed: int) -> String:
	var total := 0.0
	for id in options: total += float(RARITY.get(id, 1.0))
	var roll := float(posmod(seed, 10007)) / 10007.0 * total
	for id in options:
		roll -= float(RARITY.get(id, 1.0))
		if roll < 0.0: return id
	return options[-1]
static func flying(id: String) -> bool: return entry(id).get("form", "") in ["moth", "bee", "bird", "manta"]
## Size, hitbox and reach for regional enemies that have been re-sculpted, so they stand at
## their intended size beside Mr. Justice (who is 1.22 m tall).
const SIZES = {"cocoa_knight": {"radius": 0.6, "height": 2.6, "reach": 2.6}, "fudge_golem": {"radius": 0.75, "height": 1.9, "reach": 2.3}, 
	"cliffwarden": {"radius": 0.7, "height": 2.6, "reach": 2.7},
	"stonejaw_wyrm": {"radius": 1.0, "height": 2.0},
	"pretzel_crawler": {"radius": 0.6, "height": 1.1, "reach": 2.2},
	"cola_sloshback": {"radius": 0.55, "height": 1.0},
	"sugarspike_wasp": {"radius": 0.5, "height": 1.4},
	"chocobar_croc": {"radius": 0.55, "height": 1.0, "reach": 2.3, "hp": 6},
	"wrapper_mimic": {"radius": 0.6, "height": 1.5, "reach": 2.4, "hp": 6, "speed": 3.0},
	"chest_mimic": {"radius": 0.6, "height": 1.6, "reach": 2.4, "hp": 7, "speed": 3.0},
	"grand_confectioner": {"radius": 0.95, "height": 3.0, "reach": 3.0},
	"windwhistle_stalker": {"radius": 0.65, "height": 1.45, "reach": 2.5},
	"thistle_jackal": {"radius": 0.45, "height": 1.3, "reach": 2.2},
	"grassland_colossus": {"radius": 1.45, "height": 3.6, "reach": 3.4},
	"kiteclaw_raptor": {"radius": 0.7, "height": 1.5, "reach": 2.6},
	"storm_bison": {"radius": 0.85, "height": 2.1, "reach": 2.8, "hp": 7},
	"thunder_rhino": {"radius": 0.85, "height": 1.95, "reach": 2.8, "hp": 8},
	"stormcloud_muskox": {"radius": 0.8, "height": 1.95, "reach": 2.7, "hp": 7},
	"stormfrill": {"radius": 0.8, "height": 2.2, "reach": 2.9, "hp": 8},
	"thunderclub": {"radius": 0.95, "height": 1.8, "reach": 2.9, "hp": 9},
	"stormhorn_matriarch": {"radius": 1.0, "height": 4.2, "reach": 3.8, "hp": 30, "front_max": 2.4},
	"dune_maw": {"radius": 0.7, "height": 1.5, "reach": 3.2, "hp": 7, "front_max": 2.0},
	"pit_antlion": {"radius": 0.8, "height": 1.4, "reach": 3.3, "hp": 6, "front_max": 2.4},
	"dune_monitor": {"radius": 0.7, "height": 1.5, "reach": 3.4, "hp": 6, "front_max": 2.3},
	"obelisk_scorpion": {"radius": 0.75, "height": 1.8, "reach": 3.0, "hp": 6, "front_max": 2.1},
	"sunken_sentinel": {"radius": 0.45, "height": 2.6, "reach": 9.0, "hp": 7, "attack": "ranged", "beam": true, "windup": 1.0},
	"pharaoh_guardian": {"radius": 0.45, "height": 2.6, "reach": 9.0, "hp": 7, "attack": "ranged", "beam": true, "windup": 1.0},
	"lion_warden": {"radius": 0.45, "height": 2.6, "reach": 9.0, "hp": 7, "attack": "ranged", "beam": true, "windup": 1.0},
}
## Ambushers lie still, disguised (a rock, a chest), until Mr. Justice comes within `trigger`
## metres; then they rise `sink` metres out of the ground on their legs and fight.
const AMBUSH = {"wrapper_mimic": {"sink": 0.95, "trigger": 3.6}, "chest_mimic": {"sink": 0.8, "trigger": 3.0}, "pit_antlion": {"sink": 0.5, "trigger": 4.2}}
## Hostiles that are not tied to one region (placed by ecology and site interiors instead).
const WANDERING_HOSTILES = [{"id": "chest_mimic", "name": "Chest Mimic", "region": 0, "kind": "hostile", "boss": false, "form": "mimic"}]


static func enemy_profiles() -> Dictionary:
	var result = {}
	for e in entries() + WANDERING_HOSTILES:
		if e.kind != "hostile" or enemy_id(e.id) in ["bellkeeper", "embermaw", "moss_guardian", "thorn_wolf", "frost_brute", "wild_boar", "glass_skitter", "cinder_wisp"]: continue
		var form: String = e.form; var boss: bool = e.boss
		var attack = "ranged" if form == "wraith" or e.id in ["cola_sloshback", "sugarspike_wasp"] else "charge" if form in ["hound", "cat", "boar", "wyrm"] else "melee"
		var tall: bool = form in ["knight", "golem", "reaper", "wraith"]
		var height = 2.3 if boss else 2.0 if tall else 1.15
		var reach = 9.0 if attack == "ranged" else 6.0 if attack == "charge" else 2.3 if tall else 1.8
		result[enemy_id(e.id)] = {"name": e.name, "model": e.name.replace(" ", ""), "hp": 24 if boss else 8 if form in ["golem", "knight", "armored"] else 5, "speed": 1.6 if tall else 2.8, "reach": reach, "windup": 1.1 if boss else 0.85 if tall else 0.65, "recovery": 1.0 if boss else 0.8, "cooldown": 3.4 if boss else 2.5, "damage": 2 if boss else 1, "radius": 0.65 if boss else 0.5, "height": height, "attack": attack, "form": form, "region": e.region, "boss": boss}
		result[enemy_id(e.id)].merge(SIZES.get(enemy_id(e.id), {}), true)
		if AMBUSH.has(e.id): result[enemy_id(e.id)]["ambush"] = AMBUSH[e.id]
	return result
