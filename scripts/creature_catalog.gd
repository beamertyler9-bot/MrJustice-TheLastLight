extends RefCounted

const S = preload("res://scripts/region_sites.gd")
const ALIASES = {"ironhide_boar": "wild_boar", "the_bellkeeper": "bellkeeper"}
const LEGACY_WILD = {"starwing_moth": "moth", "fernhare": "hare", "glimmerstag": "deer", "mistrunner_fox": "fox", "dawnbell_songbird": "bird", "mossbrow_boar": "boar"}
const BOSSES = {"valley-c08": "stonejaw_wyrm", "food-d06": "grand_confectioner", "plains-d06": "stormhorn_matriarch", "desert-d02": "glass_anubid", "haunted-d02": "pale_watcher", "haunted-d01": "blackthorn_regent", "crystal-d06": "aurora_custodian"}
const FORMS = {
	"starwing_moth": "moth", "fernhare": "hare", "glimmerstag": "deer", "mossbrow_boar": "boar", "craghorn_goat": "goat", "riverglass_kingfisher": "bird",
	"mallow_sheep": "sheep", "cocoa_chipmunk": "rodent", "fizz_frog": "frog", "graham_tortoise": "tortoise", "caramel_dormouse": "rodent", "sugarwing_bee": "bee",
	"dawnbell_songbird": "bird", "meadowhopper": "hopper", "windtail_hare": "hare", "reedcrest_crane": "crane", "goldmane_antelope": "antelope", "streamback_turtle": "tortoise",
	"mistrunner_fox": "fox", "sandshell_lizard": "lizard", "dune_jerboa": "rodent", "oasis_ibis": "crane", "amber_scarab": "beetle", "shadeback_camel": "camel",
	"ember_salamander": "lizard", "ash_moth": "moth", "basalt_beetle": "beetle", "copperback_gecko": "lizard", "cinderfin_fish": "fish", "ventwing_swift": "bird",
	"ashen_raven": "bird", "pallid_moth": "moth", "gravemoss_snail": "snail", "prismhart": "deer", "opaline_otter": "otter", "chimewing_manta": "manta", "geode_tortoise": "tortoise", "faceted_finch": "bird", "quartz_hare": "hare",
	"cliffwarden": "golem", "stonejaw_wyrm": "wyrm", "fudge_golem": "golem", "wrapper_mimic": "mimic", "pretzel_crawler": "crawler", "cola_sloshback": "frog", "sugarspike_wasp": "winged", "grand_confectioner": "knight",
	"windwhistle_stalker": "cat", "thistle_jackal": "hound", "grassland_colossus": "golem", "kiteclaw_raptor": "winged", "stormhorn_matriarch": "boar", "dune_maw": "wyrm", "sunken_sentinel": "knight", "sandwraith": "wraith", "obelisk_scorpion": "scorpion", "glass_anubid": "hound",
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
static func flying(id: String) -> bool: return entry(id).get("form", "") in ["moth", "bee", "bird", "manta"]
static func enemy_profiles() -> Dictionary:
	var result = {}
	for e in entries():
		if e.kind != "hostile" or enemy_id(e.id) in ["bellkeeper", "embermaw", "moss_guardian", "thorn_wolf", "frost_brute", "wild_boar", "glass_skitter", "cinder_wisp"]: continue
		var form: String = e.form; var boss: bool = e.boss
		var attack = "ranged" if form == "wraith" or e.id in ["cola_sloshback", "sugarspike_wasp"] else "charge" if form in ["hound", "cat", "boar", "wyrm"] else "melee"
		var tall: bool = form in ["knight", "golem", "reaper", "wraith"]
		var height = 2.3 if boss else 2.0 if tall else 1.15
		var reach = 9.0 if attack == "ranged" else 6.0 if attack == "charge" else 2.3 if tall else 1.8
		result[enemy_id(e.id)] = {"name": e.name, "model": e.name.replace(" ", ""), "hp": 24 if boss else 8 if form in ["golem", "knight", "armored"] else 5, "speed": 1.6 if tall else 2.8, "reach": reach, "windup": 1.1 if boss else 0.85 if tall else 0.65, "recovery": 1.0 if boss else 0.8, "cooldown": 3.4 if boss else 2.5, "damage": 2 if boss else 1, "radius": 0.65 if boss else 0.5, "height": height, "attack": attack, "form": form, "region": e.region, "boss": boss}
	return result
