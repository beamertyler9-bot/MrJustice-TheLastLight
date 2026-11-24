extends SceneTree
## Bakes a hand-sculpted creature into assets/creatures. Run with:
## godot --headless --path . --script res://tools/bake_creature.gd -- <species id>
const DESIGNS := {
	"rootling_sentinel": ["res://tools/sculpt_rootling.gd", "mossback"],
	"moss_guardian": ["res://tools/sculpt_moss_guardian.gd", "rockmound"],
	"glass_skitter": ["res://tools/sculpt_glass_skitter.gd", "spider"],
	"thorn_wolf": ["res://tools/sculpt_thorn_wolf.gd", "briar"],
	"cinder_wisp": ["res://tools/sculpt_cinder_wisp.gd", "lantern_wraith"],
	"frost_brute": ["res://tools/sculpt_frost_brute.gd", "glacier2"],
	"wild_boar": ["res://tools/sculpt_wild_boar.gd", "mossback"],
	"cliffwarden": ["res://tools/sculpt_cliffwarden.gd", "classic"],
	"stonejaw_wyrm": ["res://tools/sculpt_stonejaw_wyrm.gd", "classic"],
	"fudge_golem": ["res://tools/sculpt_fudge_golem2.gd", "ogre"],
	"cocoa_knight": ["res://tools/sculpt_fudge_golem2.gd", "knight"],
	"chocobar_croc": ["res://tools/sculpt_choco_croc.gd", "croc"],
	"pretzel_crawler": ["res://tools/sculpt_pretzel_crawler.gd", "scorpion"],
	"cola_sloshback": ["res://tools/sculpt_cola_sloshback.gd", "bottle"],
	"sugarspike_wasp": ["res://tools/sculpt_sugarspike_wasp.gd", "candycorn"],
	"fizz_toad": ["res://tools/sculpt_cola_sloshback.gd", "toad_wild", "wild"],
	"slosh_axolotl": ["res://tools/sculpt_cola_sloshback.gd", "axolotl_wild", "wild"],
	"wrapper_mimic": ["res://tools/sculpt_mimics.gd", "rock"],
	"chest_mimic": ["res://tools/sculpt_mimics.gd", "chest"],
	"treeline_lurker": ["res://tools/sculpt_treeline_lurker.gd", "lurker", "lurker"],
	"barrowback": ["res://tools/sculpt_grassland_colossus.gd", "barrowback", "plain"],
	"grand_confectioner": ["res://tools/sculpt_grand_confectioner.gd", "mixer"],
	"windwhistle_stalker": ["res://tools/sculpt_windwhistle_stalker.gd", "lion"],
	"thistle_jackal": ["res://tools/sculpt_thistle_jackal.gd", "burrcoat"],
	"grassland_colossus": ["res://tools/sculpt_grassland_colossus.gd", "sod"],
	"kiteclaw_raptor": ["res://tools/sculpt_kiteclaw_raptor.gd", "raptor"],
	"storm_bison": ["res://tools/sculpt_stormhorn_matriarch.gd", "bison"],
	"thunder_rhino": ["res://tools/sculpt_stormhorn_matriarch.gd", "rhino"],
	"stormcloud_muskox": ["res://tools/sculpt_stormhorn_matriarch.gd", "muskox"],
	"stormfrill": ["res://tools/sculpt_stormhorn_boss.gd", "frill"],
	"thunderclub": ["res://tools/sculpt_stormhorn_boss.gd", "club"],
	"stormhorn_matriarch": ["res://tools/sculpt_stormhorn_boss.gd", "elk"],
	"dune_maw": ["res://tools/sculpt_dune_maw.gd", "sandworm"],
	"pit_antlion": ["res://tools/sculpt_dune_maw.gd", "antlion"],
	"dune_monitor": ["res://tools/sculpt_sand_lizard.gd", "monitor"],
	"thorn_devil": ["res://tools/sculpt_sand_lizard.gd", "devil_wild", "wild"],
	"obelisk_scorpion": ["res://tools/sculpt_obelisk_scorpion.gd", "fattail"],
	"sunken_sentinel": ["res://tools/sculpt_sunken_sentinel.gd", "sunken"],
	"pharaoh_guardian": ["res://tools/sculpt_sunken_sentinel.gd", "pharaoh"],
	"lion_warden": ["res://tools/sculpt_sunken_sentinel.gd", "lion"],
	"sandwraith": ["res://tools/sculpt_sandwraith.gd", "shroud"],
	"glass_anubid": ["res://tools/sculpt_anubis_god.gd", "beast"],
	"riftback": ["res://tools/sculpt_riftback.gd", "pangolin"],
	"volcano_tortoise": ["res://tools/sculpt_riftback.gd", "tortoise"],
	"furnace_hound": ["res://tools/sculpt_hellhound.gd", "infernal"],
	"cerberus": ["res://tools/sculpt_hellhound.gd", "cerberus"],
	"bone_hound": ["res://tools/sculpt_hellhound.gd", "bone"],
	"slag_crawler": ["res://tools/sculpt_slag_crawler.gd", "hermit"],
	"ash_harpy": ["res://tools/sculpt_ash_harpy.gd", "harpy"],
	"cinder_vulture": ["res://tools/sculpt_ash_harpy.gd", "vulture"],
	"root_reaper": ["res://tools/sculpt_root_reaper.gd", "strangler"],
	"grave_mandrake": ["res://tools/sculpt_root_reaper.gd", "mandrake"],
	"bog_wight": ["res://tools/sculpt_root_reaper.gd", "bogoak"],
	"wraithhart": ["res://tools/sculpt_wraithhart.gd", "skull"],
	"hollow_hound": ["res://tools/sculpt_hollow_hound.gd", "shuck"],
	"shadow_wolf": ["res://tools/sculpt_hollow_hound.gd", "shadow"],
	"grave_creeper": ["res://tools/sculpt_grave_creeper.gd", "assassin"],
	"grave_mantis": ["res://tools/sculpt_grave_creeper.gd", "mantis"],
	"deathshead_moth": ["res://tools/sculpt_veil_moth.gd", "deathshead"],
	"ghost_moon_moth": ["res://tools/sculpt_veil_moth.gd", "moon"],
	"thorn_widow": ["res://tools/sculpt_thorn_widow.gd", "bark"],
	"spiny_orbweaver": ["res://tools/sculpt_thorn_widow.gd", "spiny"],
	"mourning_knight": ["res://tools/sculpt_mourning_knight.gd", "blackknight"],
	"pale_watcher": ["res://tools/sculpt_pale_watcher.gd", "veiled"],
	"blackthorn_regent": ["res://tools/sculpt_mourning_knight.gd", "thorn"],
	"dust_devil": ["res://tools/sculpt_sandwraith.gd", "dustdevil"],
	"linen_revenant": ["res://tools/sculpt_sandwraith.gd", "mummy"],
}


func _initialize() -> void:
	for id in OS.get_cmdline_user_args():
		var design: Array = DESIGNS[id]
		var path := "res://assets/creatures/enemy_%s.scn" % id
		if not ResourceLoader.exists(path): path = "res://assets/creatures/regional_enemy_%s.scn" % id
		if design.size() > 2 and design[2] == "wild": path = "res://assets/creatures/regional_wild_%s.scn" % id
		if design.size() > 2 and design[2] in ["lurker", "plain"]: path = "res://assets/creatures/%s.scn" % id
		var model: Node3D = load(design[0]).new().build(design[1])
		if ResourceLoader.exists(path):
			var old: Node = load(path).instantiate()
			for key in ["cast_revision", "folklore_identity", "replacement_asset"]:
				if old.has_meta(key) and not model.has_meta(key): model.set_meta(key, old.get_meta(key))
			old.free()
		var packed := PackedScene.new(); packed.pack(model)
		print("BAKE %s %s triangles=%d" % [id, error_string(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)), model.get_meta("sculpt_triangles")])
	quit()
