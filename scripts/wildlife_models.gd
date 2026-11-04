extends RefCounted
const Resources = preload("res://scripts/creature_resources.gd")
const Art = preload("res://scripts/cast_art.gd")
const NAMES = {"moth": "Starwing Moth", "hare": "Fernhare", "deer": "Glimmerstag", "fox": "Mistrunner Fox", "bird": "Dawnbell Songbird", "boar": "Mossbrow Boar"}
const MOTH_COLORS = ["#303b67", "#275a63", "#624365", "#414f56", "#344c74", "#635040", "#4c406e", "#684850", "#365951"]
static func build(body: Node3D, species: String, _index: int = 0) -> Dictionary:
 var data = Resources.attach(body, "wild_" + species)
 body.name = NAMES[species]
 return data.rig
static func moth_wing_material(region: int) -> StandardMaterial3D:
 return Art.material("cloth", Color(MOTH_COLORS[clampi(region, 0, MOTH_COLORS.size() - 1)]), 0.0, 0.025)
