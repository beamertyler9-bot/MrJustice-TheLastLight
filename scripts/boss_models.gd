extends RefCounted
const Resources = preload("res://scripts/creature_resources.gd")
static func build(actor, interior: String) -> void:
 Resources.bind(actor, "boss_" + interior)
 if interior == "dungeon" and str(actor.model.get_meta("geometry_revision", "")) != "sculpted-1": preload("res://scripts/haunted_creature_art.gd").bellkeeper(actor)
