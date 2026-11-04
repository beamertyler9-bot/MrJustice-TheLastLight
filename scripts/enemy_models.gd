extends RefCounted
const Resources = preload("res://scripts/creature_resources.gd")
const Regional = preload("res://scripts/regional_creature_models.gd")
static func build(actor) -> void:
 if actor.profile.has("form"):
  Regional.enemy(actor); actor.model.set_meta("cast_revision", "0.22-reviewed"); return
 Resources.bind(actor, "enemy_" + actor.species_id)
