extends "res://tools/creature_kit.gd"
## Ambush mimics, sculpted by hand around the real props they pretend to be.
## "rock": the Chocorock Mimic, built on the very chocolate rock found all over S'morewood.
## "chest": the Chest Mimic, built on the game's own treasure chest.
## Both lie still in disguise; the game sinks them `sink` metres and folds their legs away
## (see CreatureCatalog.AMBUSH) until Mr. Justice comes close, then they rise on long, spindly
## limbs and open up a mouth of crooked teeth. Their only tell is a few tooth tips and a
## faint glint of eyes.

const Ground = preload("res://scripts/regional_ground.gd")
const Imported = preload("res://scripts/imported_assets.gd")

const MAW := Color("#250608")
const GUM := Color("#6e1520")
const FANG := Color("#efe3c4")
const FANG_ROOT := Color("#a88e62")
const TONGUE := Color("#9c2234")
const LIMB := Color("#3a231a")
const LIMB_PALE := Color("#8f7766")
const CLAW := Color("#1a0f0b")

var flesh: StandardMaterial3D
var dim_eyes: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	material.roughness = 0.75
	flesh = StandardMaterial3D.new()
	flesh.vertex_color_use_as_albedo = true
	flesh.vertex_color_is_srgb = true
	flesh.roughness = 0.35
	flesh.metallic_specular = 0.6
	dim_eyes = StandardMaterial3D.new()
	dim_eyes.albedo_color = Color("#d99a3a")
	dim_eyes.emission_enabled = true
	dim_eyes.emission = Color("#ffb03a")
	dim_eyes.emission_energy_multiplier = 0.55
	glow = dim_eyes


func build(variant: String) -> Node3D:
	root = Node3D.new()
	match variant:
		"rock": root.name = "ChocorockMimic"; return _rock()
		"chest": root.name = "ChestMimic"; return _chest()
	return null


func _with_visual(node: Node3D, head: Node3D, hips: Array, knees: Array, jaw: Node3D) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": [], "features": {&"jaw": node.get_path_to(jaw)}}
	node.set_meta("rig_bindings", rig)
	return node


## A mesh made in `node`'s own space (for parts inside rotated or scaled props).
func local_part(node: Node3D, name: String, s: Sculpt, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.name = name
	m.mesh = s.commit(mat, Vector3.ZERO)
	node.add_child(m)
	return m


## Crooked needle fangs from `a` to `b`, pointing `dir`; a few are much longer than the rest.
func fangs(s: Sculpt, painter: int, a: Vector3, b: Vector3, count: int, dir: Vector3, length: float, width: float, inward := 0.0) -> void:
	for k in range(count):
		var t := (k + 0.5) / count
		var at := a.lerp(b, t)
		var l := length * (0.55 + 0.75 * absf(sin(k * 2.71 + 0.4)))
		var lean := Vector3(sin(k * 1.9) * 0.25, 0, absf(cos(k * 2.3)) * 0.15 * inward if inward != 0.0 else cos(k * 2.3) * 0.15)
		var d := (dir.normalized() + lean).normalized()
		s.tube([at, at + d * l * 0.55 + lean * 0.02, at + d * l], [width, width * 0.6, 0.002], painter, {"sides": 6, "per": 2, "cap0": false})


## Long spider limbs: up and out to a high knee, then a long thin shin down to the ground
## ending in three hooked claws. Pale knuckles at every joint.
func creepy_legs(hip_spots: Array, reach: float, knee_rise: float, thick: float) -> Array:
	var hips: Array = []; var knees: Array = []
	var skin := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return LIMB.lerp(LIMB_PALE, clampf(0.25 + Sculpt.noise(p * 9.0) * 0.4 + n.y * 0.2, 0.0, 1.0) * 0.5)
	var knuckle := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return LIMB_PALE.lightened(clampf(n.y, 0.0, 1.0) * 0.2)
	var claw := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return CLAW.lerp(FANG_ROOT, v * 0.4)
	for k in range(hip_spots.size()):
		var at: Vector3 = hip_spots[k]
		var out := Vector3(at.x, 0, at.z).normalized()
		var label := ("Foreleg%d" if at.z < 0.0 else "Hindleg%d") % k
		var hip := joint(root, label, at)
		var knee_at := at + out * reach * 0.42 + Vector3(0, knee_rise, 0)
		var ts := Sculpt.new(); var tp := ts.add_painter(skin)
		ts.tube([at, at.lerp(knee_at, 0.5) + Vector3(0, 0.05, 0), knee_at], [thick * 1.2, thick, thick * 0.8], tp, {"sides": 7, "per": 3, "lump": 0.25})
		part(hip, "Thigh", ts, flesh)
		var knee := joint(hip, "Knee", knee_at)
		var foot := Vector3(at.x + out.x * reach, 0.03, at.z + out.z * reach)
		var ss := Sculpt.new(); var sp := ss.add_painter(skin); var kp := ss.add_painter(knuckle); var cp := ss.add_painter(claw)
		var bend := knee_at.lerp(foot, 0.55) + out * 0.08 + Vector3(0, 0.05, 0)
		ss.tube([knee_at, bend, foot + Vector3(0, 0.06, 0)], [thick * 0.8, thick * 0.65, thick * 0.45], sp, {"sides": 7, "per": 3, "lump": 0.25})
		ss.blob(knee_at, Vector3.ONE * thick * 1.25, kp, {"lat": 5, "lon": 7, "lump": 0.2})
		ss.blob(bend, Vector3.ONE * thick * 0.85, kp, {"lat": 4, "lon": 6})
		for c in range(3):
			var spread := (c - 1) * 0.55
			var cd := (out.rotated(Vector3.UP, spread) * 0.9 + Vector3(0, -0.35, 0)).normalized()
			var base := foot + Vector3(0, 0.06, 0)
			ss.tube([base, base + cd * 0.08 + Vector3(0, 0.02, 0), base + cd * 0.15 + Vector3(0, -0.05, 0)], [thick * 0.35, thick * 0.25, 0.002], cp, {"sides": 5, "per": 2, "cap0": false})
		part(knee, "Shin", ss, flesh)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


# ------------------------------------------------------------------- rock

## The Chocorock Mimic. Above ground it is exactly one of S'morewood's chocolate rocks; its
## tells are three fang tips under the front edge and two faint amber slits. Out of the ground
## it hangs on six spider legs, the rock splits from a chocolate lower jaw full of fangs.
func _rock() -> Node3D:
	var lift := 0.95
	var rock_height := 0.78
	var head := joint(root, "Head", Vector3(0, lift + 0.3, 0))
	# The rock itself: the region's own rock model with its chocolate material.
	var rock_mesh: Mesh = Imported.mesh("qnat_rock_medium_1")
	var rock := MeshInstance3D.new(); rock.name = "ChocolateRock"; rock.mesh = rock_mesh
	rock.material_override = Ground.chocolate_rock_material(rock_mesh.surface_get_material(0))
	rock.scale = Vector3.ONE * rock_height
	rock.position = Vector3(0, lift, 0) - Vector3(0, lift + 0.3, 0)
	head.add_child(rock)
	# The roof of the mouth and the upper fangs, hung under the rock.
	var ms := Sculpt.new(); var maw := ms.add_painter(func (p, n, v, w): return MAW.lerp(GUM, clampf(-n.y, 0.0, 1.0) * 0.6))
	var fp := ms.add_painter(func (p, n, v, w): return FANG_ROOT.lerp(FANG, v))
	ms.blob(Vector3(0, lift + 0.05, -0.02), Vector3(0.48, 0.06, 0.42), maw, {"lat": 5, "lon": 12})
	fangs(ms, fp, Vector3(-0.4, lift + 0.03, -0.38), Vector3(0.4, lift + 0.03, -0.38), 9, Vector3(0, -1, -0.15), 0.2, 0.025)
	fangs(ms, fp, Vector3(-0.44, lift + 0.03, -0.25), Vector3(-0.44, lift + 0.03, 0.25), 4, Vector3(0, -1, 0), 0.16, 0.022)
	fangs(ms, fp, Vector3(0.44, lift + 0.03, -0.25), Vector3(0.44, lift + 0.03, 0.25), 4, Vector3(0, -1, 0), 0.16, 0.022)
	# The tell: three fang tips just peeking out under the front edge of the rock.
	fangs(ms, fp, Vector3(-0.12, lift + 0.06, -0.5), Vector3(0.14, lift + 0.06, -0.5), 3, Vector3(0, -1, -0.1), 0.07, 0.014)
	part(head, "Maw", ms, flesh)
	# Eyes: two thin amber slits low on the front face, barely lit.
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.17 * side, lift + 0.2, -0.52), Vector3(0.05, 0.012, 0.012), ew, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.25 * side)})
	var core := part(head, "SlitEyes", es, dim_eyes); core.material_override = dim_eyes
	# The lower jaw: a chocolate slab of a jaw with fangs and a long tongue.
	var jaw := joint(head, "Jaw", Vector3(0, lift - 0.02, 0.32))
	var js := Sculpt.new()
	var choc := js.add_painter(func (p, n, v, w): return Color("#4a2a1a").lerp(Color("#734630"), clampf(0.35 + Sculpt.fbm(p * 5.0) * 0.6 + n.y * 0.2, 0.0, 1.0)))
	var jm := js.add_painter(func (p, n, v, w): return MAW.lerp(GUM, clampf(n.y, 0.0, 1.0) * 0.7))
	var jf := js.add_painter(func (p, n, v, w): return FANG_ROOT.lerp(FANG, v))
	var tongue := js.add_painter(func (p, n, v, w): return TONGUE.lightened(clampf(n.y, 0.0, 1.0) * 0.2 + absf(Sculpt.noise(p * 20.0)) * 0.1))
	js.rock(Vector3(0, lift - 0.13, -0.02), Vector3(0.44, 0.13, 0.42), choc, {"lat": 5, "lon": 9, "lump": 0.3})
	js.blob(Vector3(0, lift - 0.03, -0.04), Vector3(0.36, 0.035, 0.33), jm, {"lat": 4, "lon": 10})
	fangs(js, jf, Vector3(-0.36, lift - 0.03, -0.36), Vector3(0.36, lift - 0.03, -0.36), 8, Vector3(0, 1, -0.1), 0.15, 0.022)
	js.tube([Vector3(0, lift - 0.01, 0.15), Vector3(0.02, lift + 0.01, -0.15), Vector3(0.05, lift - 0.02, -0.42), Vector3(0.08, lift - 0.18, -0.52)], [0.07, 0.08, 0.065, 0.04], tongue, {"sides": 9, "per": 3, "flat": 2.0, "side": Vector3.RIGHT, "cap_len": 0.6})
	part(jaw, "LowerJaw", js, flesh)
	# Drool strands from the upper fangs.
	var ds := Sculpt.new(); var dp := ds.add_painter(func (p, n, v, w): return Color("#e8d8c8"))
	for x in [-0.22, 0.05, 0.27]:
		ds.tube([Vector3(x, lift - 0.12, -0.4), Vector3(x + 0.01, lift - 0.24, -0.41), Vector3(x, lift - 0.32, -0.4)], [0.006, 0.004, 0.01], dp, {"sides": 5, "per": 2})
	part(head, "Drool", ds, flesh)
	var spots: Array = []
	for k in range(6):
		var ang := TAU * (k + 0.5) / 6.0
		spots.append(Vector3(cos(ang) * 0.3, lift - 0.08, sin(ang) * 0.28))
	var legs := creepy_legs(spots, 1.25, 0.45, 0.04)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.0)
	return _with_visual(node, head, legs[0], legs[1], jaw)


# ------------------------------------------------------------------ chest

## The Chest Mimic: the game's own treasure chest. Its tells are a few tiny tooth tips under
## the lid's front edge. Out of hiding it stands on four long clawed limbs, the lid gapes open
## on rows of needle fangs, a long tongue and two burning eyes inside the lid.
func _chest() -> Node3D:
	var lift := 0.8
	var head := joint(root, "Head", Vector3(0, lift + 0.4, 0))
	var chest_scene: PackedScene = load("res://assets/replacements/treasure_chest.scn")
	var source: Node3D = chest_scene.instantiate()
	# The chest faces +z in its own space; turn it round so its latch faces the front.
	var body := Node3D.new(); body.name = "ChestBody"
	body.position = Vector3(0, lift, 0) - Vector3(0, lift + 0.4, 0)
	body.rotation.y = PI; body.scale = Vector3.ONE * 0.95
	head.add_child(body)
	var base_src: MeshInstance3D = source.get_node("Base")
	var base := MeshInstance3D.new(); base.name = "Base"; base.mesh = base_src.mesh.duplicate(true); body.add_child(base)
	var lid_src: Node3D = source.get_node("Lid")
	var lid := Node3D.new(); lid.name = "Lid"; lid.position = lid_src.position; body.add_child(lid)
	var lid_mesh := MeshInstance3D.new(); lid_mesh.name = "LidMesh"; lid_mesh.mesh = (lid_src.get_node("LidMesh") as MeshInstance3D).mesh.duplicate(true); lid.add_child(lid_mesh)
	source.free()
	var maw := func (p, n, v, w): return MAW.lerp(GUM, clampf(absf(n.y), 0.0, 1.0) * 0.6)
	var fang_paint := func (p, n, v, w): return FANG_ROOT.lerp(FANG, v)
	# Inside the base: a dark gullet, a ring of fangs round the rim and a coiled tongue.
	var bs := Sculpt.new(); var bm := bs.add_painter(maw); var bf := bs.add_painter(fang_paint)
	var bt := bs.add_painter(func (p, n, v, w): return TONGUE.lightened(clampf(n.y, 0.0, 1.0) * 0.2 + absf(Sculpt.noise(p * 20.0)) * 0.1))
	bs.blob(Vector3(0, 0.555, 0.0), Vector3(0.56, 0.025, 0.37), bm, {"lat": 4, "lon": 12})
	fangs(bs, bf, Vector3(-0.5, 0.56, 0.32), Vector3(0.5, 0.56, 0.32), 11, Vector3(0, 1, -0.05), 0.15, 0.022, -1.0)
	fangs(bs, bf, Vector3(-0.53, 0.56, -0.28), Vector3(-0.53, 0.56, 0.26), 5, Vector3(0.1, 1, 0), 0.12, 0.02, -1.0)
	fangs(bs, bf, Vector3(0.53, 0.56, -0.28), Vector3(0.53, 0.56, 0.26), 5, Vector3(-0.1, 1, 0), 0.12, 0.02, -1.0)
	bs.tube([Vector3(0, 0.57, -0.25), Vector3(-0.05, 0.6, 0.0), Vector3(0.03, 0.6, 0.18), Vector3(0.05, 0.585, 0.3)], [0.07, 0.085, 0.08, 0.06], bt, {"sides": 9, "per": 3, "flat": 2.0, "side": Vector3.RIGHT, "cap_len": 0.6})
	local_part(body, "Gullet", bs, flesh)
	# Inside the lid: the roof of the mouth, the upper fangs and the eyes.
	var ls := Sculpt.new(); var lm := ls.add_painter(maw); var lf := ls.add_painter(fang_paint)
	ls.blob(Vector3(0, -0.01, 0.41), Vector3(0.58, 0.02, 0.4), lm, {"lat": 4, "lon": 12})
	fangs(ls, lf, Vector3(-0.52, -0.02, 0.74), Vector3(0.52, -0.02, 0.74), 12, Vector3(0, -1, -0.05), 0.2, 0.024, -1.0)
	fangs(ls, lf, Vector3(-0.54, -0.02, 0.12), Vector3(-0.54, -0.02, 0.68), 5, Vector3(0.1, -1, 0), 0.14, 0.02, -1.0)
	fangs(ls, lf, Vector3(0.54, -0.02, 0.12), Vector3(0.54, -0.02, 0.68), 5, Vector3(-0.1, -1, 0), 0.14, 0.02, -1.0)
	# The tell: a few tooth tips poking out under the lid's front edge.
	fangs(ls, lf, Vector3(-0.32, 0.0, 0.85), Vector3(0.36, 0.0, 0.85), 4, Vector3(0, -1, 0.02), 0.05, 0.011)
	local_part(lid, "MouthRoof", ls, flesh)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.2 * side, -0.035, 0.3), Vector3(0.075, 0.03, 0.06), ew, {"lat": 5, "lon": 9})
	var core := local_part(lid, "LidEyes", es, dim_eyes); core.material_override = dim_eyes
	var ps := Sculpt.new(); var pp := ps.add_painter(func (p, n, v, w): return Color("#120406"))
	for side in [-1.0, 1.0]: ps.blob(Vector3(0.2 * side, -0.06, 0.31), Vector3(0.015, 0.012, 0.045), pp, {"lat": 4, "lon": 7})
	local_part(lid, "Pupils", ps, flesh)
	var spots := [Vector3(-0.42, lift + 0.06, -0.26), Vector3(0.42, lift + 0.06, -0.26), Vector3(-0.42, lift + 0.06, 0.26), Vector3(0.42, lift + 0.06, 0.26)]
	var legs := creepy_legs(spots, 1.1, 0.5, 0.045)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.0)
	return _with_visual(node, head, legs[0], legs[1], lid)
