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
}


func _initialize() -> void:
	for id in OS.get_cmdline_user_args():
		var design: Array = DESIGNS[id]
		var path := "res://assets/creatures/enemy_%s.scn" % id
		if not ResourceLoader.exists(path): path = "res://assets/creatures/regional_enemy_%s.scn" % id
		var model: Node3D = load(design[0]).new().build(design[1])
		if ResourceLoader.exists(path):
			var old: Node = load(path).instantiate()
			for key in ["cast_revision", "folklore_identity", "replacement_asset"]:
				if old.has_meta(key) and not model.has_meta(key): model.set_meta(key, old.get_meta(key))
			old.free()
		var packed := PackedScene.new(); packed.pack(model)
		print("BAKE %s %s triangles=%d" % [id, error_string(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)), model.get_meta("sculpt_triangles")])
	quit()
