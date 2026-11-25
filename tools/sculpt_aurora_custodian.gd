extends "res://tools/sculpt_shard_sentinel.gd"
## The Aurora Custodian, boss of Prismere: an ancient guardian of stone and crystal that floats
## above the ground, wheeling rings about it; a chime sounds and the rings line up before it
## throws light split by its prisms. Three designs, each built on real things:
##   armillary - an archaic stone colossus (the stiff, broad-shouldered kouros statues of early
##               Greece, with their almond eyes and "archaic smile") whose legs have broken away
##               into a hanging cluster of crystal, turning inside an armillary sphere - the old
##               astronomer's instrument of bronze rings for the meridian, the equator and the
##               ecliptic tilted 23.4 degrees to it; a glass prism floats over each open palm
##   moai      - a moai of Rapa Nui: a great head on a slender torso carved from volcanic tuff,
##               heavy brow, long nose, pursed lips, long ears, arms carved down its sides with
##               long fingers meeting over the belly, a red scoria topknot (pukao), and eyes of
##               white coral with dark pupils as were found at Anakena - here the pupils are
##               glowing crystal; stone rings circle it like a planet's
##   aurora    - a seraph of crystal and stone: its body one great quartz point hanging point-
##               down, a carved stone mask for a face with three halo rings behind it, arms of
##               floating stone blocks with no joints between them, and curtains of aurora light
##               hanging from its crown - green at their lower edges and fading up through violet
##               into red, as the real aurora glows (oxygen green low, red high, nitrogen violet)

var kinda := "armillary"
var bronze: StandardMaterial3D
var aurora_mat: StandardMaterial3D


func _init() -> void:
	super()
	bronze = StandardMaterial3D.new()
	bronze.vertex_color_use_as_albedo = true; bronze.vertex_color_is_srgb = true
	bronze.metallic = 0.7; bronze.roughness = 0.35
	aurora_mat = StandardMaterial3D.new()
	aurora_mat.vertex_color_use_as_albedo = true; aurora_mat.vertex_color_is_srgb = true
	aurora_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aurora_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aurora_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aurora_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "AuroraCustodian"
	kinda = variant; kindc = "quartz"; kind = "sentinel"
	crystal_mat.emission = Color("#6a7aa8"); crystal_mat.emission_energy_multiplier = 0.4
	match variant:
		"armillary":
			glow.albedo_color = Color("#3ad0ff"); glow.emission = Color("#2ac8ff")
		"moai":
			glow.albedo_color = Color("#9affd8").darkened(0.2); glow.emission = Color("#8affd0")
		"aurora":
			glow.albedo_color = Color("#c8ffe0").darkened(0.2); glow.emission = Color("#b0ffd8")
		_: return null
	glow.emission_energy_multiplier = 2.2
	match variant:
		"armillary": return _armillary()
		"moai": return _moai()
	return _aurora()


# ------------------------------------------------------------------ shared

static func bronze_paint(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#5a3a18").lerp(Color("#d8a860"), clampf(n.y * 0.3 + 0.45 + Sculpt.noise(p * 14.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#3a8a78"), smoothstep(0.45, 0.7, Sculpt.noise(p * 6.0 + Vector3(4, 0, 0))) * 0.55)


## Volcanic tuff, as the moai are carved from: grey-brown, pitted, lichen-spotted.
static func tuff(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#4a4440").lerp(Color("#8a8076"), clampf(n.y * 0.25 + 0.4 + Sculpt.fbm(p * 6.0) * 0.45, 0.0, 1.0))
	c = c.lerp(Color("#1a1614"), smoothstep(0.62, 0.75, Sculpt.noise(p * 30.0)) * 0.6)
	c = c.lerp(Color("#b8b088"), smoothstep(0.62, 0.72, Sculpt.noise(p * 9.0 + Vector3(7, 0, 0))) * 0.35)
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.3)


## A ring as a closed tube, `r` round, in the plane given by basis `b` (x and y axes), centred on `c`.
func ring(s: Sculpt, painter: int, c: Vector3, b: Basis, r: float, thick: float, flat := 1.0) -> void:
	var pts: Array = []; var rr: Array = []
	for k in range(49):
		var a := TAU * k / 48.0
		pts.append(c + b * Vector3(cos(a) * r, sin(a) * r, 0)); rr.append(thick)
	s.tube(pts, rr, painter, {"sides": 8, "per": 1, "flat": flat, "side": b.z, "cap0": false, "cap1": false})


## A triangular glass prism floating at `c` along `axis`.
func prism(s: Sculpt, painter: int, c: Vector3, axis: Vector3, length: float, r: float) -> void:
	s.lathe(c, [Vector2(0.0, length * 0.5), Vector2(r, length * 0.5), Vector2(r, -length * 0.5), Vector2(0.0, -length * 0.5)], painter, {"sides": 3, "basis": Basis(Quaternion(Vector3.UP, axis.normalized()))})


func launch(parent: Node3D, at: Vector3) -> void:
	var lp := Node3D.new(); lp.name = "LaunchPoint"; parent.add_child(lp)
	lp.position = at - _world(parent)


func _sway_rig(node: Node3D, head: Node3D, sway: Array) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [],
		"ears": [], "tails": [], "features": {&"smoke": sway.map(func (n): return node.get_path_to(n))}}
	node.set_meta("rig_bindings", rig)
	return node


func glow_part(parent: Node3D, name: String, s: Sculpt) -> MeshInstance3D:
	var m := part(parent, name, s, glow); m.material_override = glow
	return m


# ------------------------------------------------------------------ A: armillary colossus

## A fist closed round a shaft, as `fist()` but sized by `k` for a giant's hand.
func big_fist(s: Sculpt, painter: int, c: Vector3, d: Vector3, a: Vector3, bh: Vector3, grip_r: float, k: float) -> void:
	var front := d.cross(bh).normalized()
	if front.dot(a) < 0.0: front = -front
	s.blob(c + bh * (grip_r + 0.022 * k) - a * 0.01 * k, Vector3(0.02, 0.05, 0.045) * k, painter, {"lat": 5, "lon": 8, "basis": Basis(bh, d, bh.cross(d)).orthonormalized()})
	for f in range(4):
		var off := d * (0.03 - f * 0.022) * k
		var pts: Array = []; var rr: Array = []
		for j in range(6):
			var t := lerpf(0.0, PI * 1.25, j / 5.0)
			pts.append(c + off + (bh * cos(t) + front * sin(t)) * (grip_r + 0.014 * k)); rr.append(0.0115 * k)
		s.tube(pts, rr, painter, {"sides": 6, "per": 1})
	var tb := c + d * 0.045 * k
	s.tube([tb + bh * (grip_r + 0.01 * k) - a * 0.02 * k, tb + front * (grip_r + 0.012 * k) + bh * 0.008 * k, tb + front * (grip_r + 0.01 * k) - bh * (grip_r * 0.6)], [0.013 * k, 0.012 * k, 0.01 * k], painter, {"sides": 6, "per": 2})
	s.blob(c - a * 0.035 * k + bh * 0.01 * k, Vector3(0.038, 0.045, 0.04) * k, painter, {"lat": 5, "lon": 8})


static func dark_stone(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#16181e").lerp(Color("#44464e"), clampf(n.y * 0.25 + 0.35 + Sculpt.fbm(p * 5.0) * 0.45, 0.0, 1.0))
	c = c.lerp(Color("#0a0a0c"), smoothstep(0.66, 0.78, Sculpt.noise(p * 30.0)) * 0.6)
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.3)


## Old bronze: dark and burnished, streaked green with verdigris in the hollows.
static func old_bronze(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#1a120a").lerp(Color("#7a5628"), clampf(n.y * 0.3 + 0.3 + Sculpt.noise(p * 12.0) * 0.35, 0.0, 1.0))
	c = c.lerp(Color("#c89a50"), smoothstep(0.55, 0.75, Sculpt.noise(p * 20.0)) * 0.35)
	return c.lerp(Color("#2a6a5c"), smoothstep(0.3, 0.6, Sculpt.noise(p * 5.0 + Vector3(4, 0, 0))) * clampf(0.75 - n.y * 0.4, 0.0, 1.0) * 0.75)


## A: the bronze-armoured colossus of an ancient hoplite, its stone cracked through with light,
## hanging in an armillary sphere. Built on the Greek hoplite: a Corinthian helmet (one
## piece of bronze, the cheek-guards closing round the face to leave only a T of eyes and
## mouth, a long nose-guard and a tall crest), a bronze "muscle cuirass" shaped to the body,
## leather strips (pteruges) hanging from the waist, a long spear (the dory) with a leaf-shaped
## head and a bronze butt-spike, and the round, dished aspis shield, carried on the forearm
## through a central band (the porpax) with the hand gripping a cord near the rim (the
## antilabe).
func _armillary() -> Node3D:
	var lights := Sculpt.new(); var lw := lights.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	var bs := Sculpt.new(); var sp := bs.add_painter(dark_stone); var bz := bs.add_painter(old_bronze); var cp := bs.add_painter(quartz)
	var leather := bs.add_painter(func (p: Vector3, n: Vector3, v: float, _w) -> Color: return Color("#2a1c14").lerp(Color("#5a3a24"), clampf(n.y * 0.3 + 0.4 + Sculpt.noise(p * 16.0) * 0.3, 0.0, 1.0)).lerp(Color("#16181e"), v * 0.5))
	# The muscle cuirass over a broad chest; the stone of the shoulders and neck bare.
	bs.blob(Vector3(0, 1.58, 0), Vector3(0.38, 0.34, 0.24), bz, {"lat": 12, "lon": 16})
	for side in [-1.0, 1.0]:
		bs.blob(Vector3(0.15 * side, 1.66, -0.15), Vector3(0.15, 0.1, 0.08), bz, {"lat": 7, "lon": 10})
		for k in range(3): bs.blob(Vector3(0.07 * side, 1.47 - k * 0.075, -0.18), Vector3(0.065, 0.032, 0.04), bz, {"lat": 5, "lon": 8})
		bs.blob(Vector3(0.42 * side, 1.8, 0), Vector3(0.17, 0.15, 0.16), sp, {"lat": 8, "lon": 10, "lump": 0.05})
		# Crystal breaking out through the stone of the shoulders.
		cluster(bs, cp, Vector3(0.46 * side, 1.9, 0.04), Vector3(0.6 * side, 1, 0.3), 5, 0.26, 0.05, side * 2.0)
	bs.blob(Vector3(0, 1.28, 0), Vector3(0.27, 0.16, 0.2), bz, {"lat": 8, "lon": 12})
	bs.tube([Vector3(0, 1.85, 0), Vector3(0, 1.97, -0.01)], [0.12, 0.11], sp, {"sides": 10, "per": 2})
	# A gorgon's face on the breast, as hoplites wore to terrify: here a glowing crystal eye.
	bs.blob(Vector3(0, 1.6, -0.235), Vector3(0.07, 0.07, 0.03), bz, {"lat": 6, "lon": 10})
	lights.blob(Vector3(0, 1.6, -0.258), Vector3(0.035, 0.045, 0.015), lw, {"lat": 5, "lon": 8})
	# Pteruges: two rows of hanging strips round the hips, breaking up into crystal below.
	for row in range(2):
		for k in range(16):
			var a := TAU * (k + row * 0.5) / 16.0
			var t := Vector3(sin(a) * 0.27, 1.2 - row * 0.08, cos(a) * 0.2)
			var o := Vector3(sin(a), 0, cos(a))
			bs.tube([t, t + o * 0.04 + Vector3(0, -0.15, 0), t + o * 0.06 + Vector3(0, -0.28, 0)], [0.055, 0.055, 0.05], leather, {"sides": 5, "per": 2, "flat": 0.2, "side": o, "cap1": false})
	var deepc := bs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#2a3a6a").lerp(Color("#d8f4ff"), clampf(v * 1.1 + Sculpt.noise(p * 8.0) * 0.2, 0.0, 1.0)))
	cluster(bs, deepc, Vector3(0, 0.98, 0), Vector3(0, -1, 0), 13, 1.05, 0.13, 1.1, 0.6)
	# Cracks of light running through the stone and splitting the bronze.
	var glowc := lights.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for k in range(4):
		var side := -1.0 if k % 2 == 0 else 1.0
		var a0 := Vector3(0.42 * side, 1.92, -0.06 + k * 0.03)
		crack(lights, glowc, a0, a0 + Vector3(0.12 * side, -0.2, -0.1), Vector3(side, 0.5, -0.3).normalized(), 0.03, k)
	for k in range(5):
		var a0 := Vector3(0, 1.6, -0.24)
		var dir := Vector3(cos(k * 1.26 + 0.3), sin(k * 1.26 + 0.3), 0)
		crack(lights, glowc, a0 + dir * 0.06, a0 + dir * (0.2 + 0.08 * (k % 2)) + Vector3(0, 0, 0.06), Vector3(0, 0, -1), 0.03, k + 4)
	part(root, "Torso", bs)
	part(root, "Cracks", lights, glow).material_override = glow
	# The head inside a Corinthian helmet.
	var head := joint(root, "Head", Vector3(0, 2.1, -0.02))
	var hs := Sculpt.new(); var hb := hs.add_painter(old_bronze); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#050506"))
	var crest := hs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#5a7aa8").lerp(Color("#f0fbff"), v).lerp(Color("#b8f0ff"), Sculpt.noise(p * 9.0) * 0.3))
	hs.blob(Vector3(0, 2.12, -0.02), Vector3(0.17, 0.2, 0.19), hb, {"lat": 12, "lon": 16})
	hs.blob(Vector3(0, 2.11, -0.04), Vector3(0.16, 0.12, 0.17), hd, {"lat": 6, "lon": 10})
	for side in [-1.0, 1.0]:
		# Cheek-guards sweeping down to points beside the chin, leaving a slit between them.
		hs.tube([Vector3(0.12 * side, 2.12, -0.15), Vector3(0.1 * side, 2.0, -0.18), Vector3(0.05 * side, 1.9, -0.19)], [0.06, 0.055, 0.03], hb, {"sides": 8, "per": 3, "flat": 0.45, "side": Vector3(0, 0, 1)})
		# The almond eye-openings, cut in under a heavy brow ridge.
		hs.blob(Vector3(0.06 * side, 2.15, -0.19), Vector3(0.05, 0.018, 0.02), hd, {"lat": 4, "lon": 8, "basis": Basis(Vector3.FORWARD, 0.28 * side)})
		hs.tube([Vector3(0.0, 2.17, -0.21), Vector3(0.08 * side, 2.18, -0.2), Vector3(0.15 * side, 2.19, -0.14)], [0.024, 0.022, 0.016], hb, {"sides": 6, "per": 2})
	# The long nose-guard.
	hs.tube([Vector3(0, 2.2, -0.2), Vector3(0, 2.1, -0.215), Vector3(0, 2.03, -0.21)], [0.018, 0.02, 0.016], hb, {"sides": 6, "per": 2, "flat": 1.6})
	# The crest: a tall fan of crystal blades on a bronze stand, running front to back.
	hs.tube([Vector3(0, 2.3, -0.16), Vector3(0, 2.34, 0.0), Vector3(0, 2.3, 0.16)], [0.02, 0.025, 0.02], hb, {"sides": 6, "per": 3})
	for k in range(13):
		var t := k / 12.0
		var base := Vector3(0, 2.31 + 0.03 * sin(PI * t), lerpf(-0.17, 0.2, t))
		var dir := Vector3(0, 1.0, lerpf(-0.5, 1.2, t)).normalized()
		hs.crystal(base, dir, 0.22 + 0.22 * sin(PI * clampf(t * 1.1, 0.0, 1.0)), 0.03, crest, 4, k * 0.3)
	part(head, "Helmet", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.058 * side, 2.152, -0.207), Vector3(0.034, 0.007, 0.006), ew, {"lat": 4, "lon": 7, "basis": Basis(Vector3.FORWARD, 0.28 * side)})
	var core := glow_part(head, "Eyes", es)
	launch(head, Vector3(0, 2.15, -0.6))
	var sway: Array = []
	# The spear arm: the dory held upright at its side, butt-spike down, its fist closed round
	# the shaft with the index finger toward the head.
	var rsh := Vector3(0.46, 1.8, 0)
	var rarm := joint(root, "RightArm", rsh)
	var ra := Sculpt.new(); var rap := ra.add_painter(dark_stone); var rbz := ra.add_painter(old_bronze)
	var shaft := ra.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#2a1c12").lerp(Color("#5a4028"), clampf(0.5 + Sculpt.noise(p * Vector3(4, 40, 4)) * 0.5, 0.0, 1.0)))
	var blade_p := ra.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#5a8ad8").lerp(Color("#f0fbff"), v).lerp(Color("#c8f0ff"), Sculpt.noise(p * 12.0) * 0.3))
	var rel := rsh + Vector3(0.14, -0.3, -0.04)
	var rh := rel + Vector3(0.04, -0.06, -0.28)
	ra.tube([rsh, rsh.lerp(rel, 0.5), rel], [0.14, 0.12, 0.1], rap, {"sides": 10, "per": 2, "lump": 0.04})
	ra.blob(rel, Vector3.ONE * 0.1, rap, {"lat": 6, "lon": 8})
	ra.tube([rel, rh], [0.095, 0.08], rap, {"sides": 10, "per": 2, "lump": 0.04})
	ra.tube([rel.lerp(rh, 0.35), rel.lerp(rh, 0.75)], [0.1, 0.095], rbz, {"sides": 10, "per": 1})
	var d := Vector3(0.02, 1.0, -0.12).normalized()
	big_fist(ra, rap, rh, d, (rh - rel).normalized(), Vector3(1, 0, 0), 0.035, 2.1)
	var butt := rh - d * 1.0; var top := rh + d * 1.05
	ra.tube([butt, top], [0.032, 0.03], shaft, {"sides": 8, "per": 1})
	ra.tube([butt, butt - d * 0.18], [0.034, 0.004], rbz, {"sides": 4, "per": 1, "cap1": false})
	# The leaf-shaped head, here a blade of crystal, socketed on bronze.
	ra.tube([top - d * 0.04, top + d * 0.06], [0.04, 0.035], rbz, {"sides": 8, "per": 1})
	ra.tube([top + d * 0.05, top + d * 0.22, top + d * 0.42, top + d * 0.55], [0.035, 0.09, 0.06, 0.003], blade_p, {"sides": 4, "per": 3, "flat": 0.2, "side": Vector3(0, 0, 1), "cap1": false})
	part(rarm, "Arm", ra)
	sway.append(rarm)
	# The shield arm: the aspis on the forearm, the arm through the central band and the hand
	# gripping the cord near the rim.
	var lsh := Vector3(-0.46, 1.8, 0)
	var larm := joint(root, "LeftArm", lsh)
	var la := Sculpt.new(); var lap := la.add_painter(dark_stone); var lbz := la.add_painter(old_bronze)
	var lel := lsh + Vector3(-0.1, -0.3, -0.16)
	var lh := lel + Vector3(0.16, 0.06, -0.3)
	la.tube([lsh, lsh.lerp(lel, 0.5), lel], [0.14, 0.12, 0.1], lap, {"sides": 10, "per": 2, "lump": 0.04})
	la.blob(lel, Vector3.ONE * 0.1, lap, {"lat": 6, "lon": 8})
	la.tube([lel, lh], [0.095, 0.08], lap, {"sides": 10, "per": 2, "lump": 0.04})
	var fdir := (lh - lel).normalized()
	var out := Vector3(-1, 0, -0.35)
	var nrm := (out - fdir * out.dot(fdir)).normalized()
	big_fist(la, lap, lh, nrm.cross(fdir).normalized(), fdir, -nrm, 0.02, 2.1)
	var sc := lel.lerp(lh, 0.3) + nrm * 0.12
	var dish := [Vector2(0.0, 0.1), Vector2(0.18, 0.09), Vector2(0.32, 0.06), Vector2(0.44, 0.02), Vector2(0.49, 0.0), Vector2(0.5, -0.03), Vector2(0.44, -0.02), Vector2(0.26, 0.03), Vector2(0.0, 0.05)]
	var face := la.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := old_bronze(p, n, v, w)
		var r := (p - sc).length()
		c = c.lerp(Color("#0a0806"), smoothstep(0.012, 0.0, absf(r - 0.38) - 0.02) * 0.9)
		return c.lerp(Color("#140e0a"), smoothstep(0.012, 0.0, absf(r - 0.25) - 0.012) * 0.7))
	la.lathe(sc, dish, face, {"sides": 28, "basis": Basis(Quaternion(Vector3.UP, nrm))})
	# The porpax band round the forearm, and its emblem: a crystal eye radiating light.
	la.tube([lel.lerp(lh, 0.15), lel.lerp(lh, 0.45)], [0.105, 0.1], lbz, {"sides": 10, "per": 1})
	var emb := sc + nrm * 0.1
	la.crystal(emb - nrm * 0.02, nrm, 0.1, 0.07, la.add_painter(quartz), 6)
	var sl := Sculpt.new(); var slp := sl.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for k in range(8):
		var a := TAU * k / 8.0
		var u := nrm.cross(Vector3.UP).normalized(); var v := nrm.cross(u)
		var dir := (u * cos(a) + v * sin(a))
		crack(sl, slp, emb + dir * 0.08 - nrm * 0.01, emb + dir * 0.34 - nrm * 0.06, nrm, 0.03, k)
	part(larm, "Arm", la)
	part(larm, "ShieldLight", sl, glow).material_override = glow
	sway.append(larm)
	# The armillary sphere: great bronze rings, the zodiac band set with glowing signs and crystal
	# spikes, small prisms riding the rings.
	var c := Vector3(0, 1.6, 0)
	var defs := [[Basis(Vector3.UP, 0.3), 1.24, 0.05], [Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.12), 1.18, 0.045], [Basis(Vector3.RIGHT, PI * 0.5 - 0.41) * Basis(Vector3.FORWARD, 0.4), 1.12, 0.09], [Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, 0.5), 1.06, 0.035]]
	for k in range(defs.size()):
		var j := joint(root, "Ring%d" % k, c)
		var rs := Sculpt.new(); var rp := rs.add_painter(old_bronze); var rc := rs.add_painter(quartz)
		var gl := Sculpt.new(); var glp := gl.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
		var b: Basis = defs[k][0]; var r: float = defs[k][1]
		ring(rs, rp, c, b, r, defs[k][2], 0.35 if k == 2 else 1.0)
		var count := 12 if k == 2 else 6
		for z in range(count):
			var a := TAU * (z + 0.5) / count
			var radial := b * Vector3(cos(a), sin(a), 0)
			if k == 2:
				rs.crystal(c + radial * r, radial, 0.18, 0.035, rc, 6, z)
				gl.blob(c + radial * r - b.z * 0.03, Vector3.ONE * 0.025, glp, {"lat": 4, "lon": 6})
			else:
				rs.crystal(c + radial * r, radial, 0.1, 0.025, rc, 6, z)
		if k == 1 or k == 3:
			for z in range(2):
				var a := PI * (0.25 + z)
				prism(rs, rs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#e8f4ff").lerp(Color.from_hsv(fposmod(p.y * 2.0 + v, 1.0), 0.5, 1.0), 0.4)), c + b * Vector3(cos(a), sin(a), 0) * r, b * Vector3(-sin(a), cos(a), 0), 0.3, 0.08)
		part(j, "Ring", rs, bronze)
		if k == 2: part(j, "Signs", gl, glow).material_override = glow
		sway.append(j)
	# Broken stones orbiting with it.
	var dj := joint(root, "Debris", c)
	var ds := Sculpt.new(); var dp := ds.add_painter(dark_stone)
	for k in range(6):
		var a := TAU * k / 6.0 + 0.3
		ds.rock(c + Vector3(cos(a) * 1.0, -0.7 + 0.15 * sin(k * 2.0), sin(a) * 1.0), Vector3(0.1, 0.08, 0.09) * (0.8 + 0.4 * fposmod(k * 0.618, 1.0)), dp, {"seed": k})
	part(dj, "Stones", ds)
	sway.append(dj)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": sway}, 1.85)
	return _sway_rig(node, head, sway)


# ------------------------------------------------------------------ B: moai

func _moai() -> Node3D:
	var bs := Sculpt.new(); var tp := bs.add_painter(tuff); var cp := bs.add_painter(quartz)
	var vein := bs.add_painter(func (_p, _n, _v, _w): return Color("#7affd0"))
	# The slender torso, arms carved down its sides with long fingers meeting over the belly.
	bs.blob(Vector3(0, 1.35, 0), Vector3(0.28, 0.42, 0.2), tp, {"lat": 10, "lon": 14, "lump": 0.03})
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.27 * side, 1.62, 0.0), Vector3(0.3 * side, 1.38, -0.02), Vector3(0.26 * side, 1.16, -0.1), Vector3(0.12 * side, 1.08, -0.18)], [0.06, 0.055, 0.05, 0.045], tp, {"sides": 8, "per": 3})
		for f in range(4):
			var f0 := Vector3(0.12 * side, 1.1 - f * 0.025, -0.19)
			bs.tube([f0, f0 + Vector3(-0.07 * side, -0.01, -0.005), f0 + Vector3(-0.11 * side, -0.02, 0.0)], [0.014, 0.013, 0.01], tp, {"sides": 5, "per": 2})
		bs.blob(Vector3(0.1 * side, 1.52, -0.18), Vector3(0.018, 0.018, 0.01), tp, {"lat": 4, "lon": 6})
	# The base, broken off jagged, grown through with crystal.
	cluster(bs, cp, Vector3(0, 0.98, 0), Vector3(0, -1, 0), 9, 0.55, 0.1, 0.7, 0.55)
	for k in range(6):
		var a := Vector3(sin(k * 2.1) * 0.2, 1.15 + k * 0.08, -0.19 + absf(sin(k * 2.1)) * 0.03)
		crack(bs, vein, a, a + Vector3(sin(k * 1.7) * 0.15, 0.12, 0), Vector3(0, 0, -1), 0.02, k)
	part(root, "Torso", bs)
	var head := joint(root, "Head", Vector3(0, 1.98, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(tuff); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#0e0c0a"))
	var coral := hs.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#eae4d8").darkened(Sculpt.noise(p * 40.0) * 0.1))
	var scoria := hs.add_painter(func (p: Vector3, n: Vector3, _v, _w) -> Color: return Color("#6a2418").lerp(Color("#b04a30"), clampf(n.y * 0.3 + 0.4 + Sculpt.fbm(p * 8.0) * 0.4, 0.0, 1.0)))
	# The long head: a deep heavy brow, a long straight nose with flared nostrils, pursed lips,
	# a jutting chin and long ears.
	hs.blob(Vector3(0, 2.0, 0.02), Vector3(0.24, 0.38, 0.22), hp, {"lat": 12, "lon": 14})
	hs.tube([Vector3(-0.2, 2.2, -0.15), Vector3(0, 2.22, -0.2), Vector3(0.2, 2.2, -0.15)], [0.05, 0.06, 0.05], hp, {"sides": 8, "per": 3})
	hs.tube([Vector3(0, 2.18, -0.2), Vector3(0, 2.0, -0.26), Vector3(0, 1.88, -0.29)], [0.04, 0.05, 0.06], hp, {"sides": 8, "per": 3, "flat": 1.2})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.05 * side, 1.86, -0.27), Vector3(0.04, 0.03, 0.03), hp, {"lat": 5, "lon": 7})
		hs.blob(Vector3(0.03 * side, 1.85, -0.3), Vector3(0.012, 0.01, 0.01), hd, {"lat": 3, "lon": 5})
		hs.tube([Vector3(0.23 * side, 2.18, 0.02), Vector3(0.25 * side, 2.0, 0.03), Vector3(0.23 * side, 1.78, 0.04)], [0.04, 0.035, 0.025], hp, {"sides": 7, "per": 3, "flat": 0.5, "side": Vector3.RIGHT})
		# White coral eyes in deep sockets.
		hs.blob(Vector3(0.1 * side, 2.12, -0.16), Vector3(0.07, 0.04, 0.03), hd, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.1 * side, 2.12, -0.175), Vector3(0.055, 0.03, 0.02), coral, {"lat": 5, "lon": 8})
	hs.tube([Vector3(-0.06, 1.77, -0.22), Vector3(0, 1.76, -0.25), Vector3(0.06, 1.77, -0.22)], [0.022, 0.028, 0.022], hp, {"sides": 6, "per": 2})
	hs.tube([Vector3(-0.055, 1.73, -0.215), Vector3(0, 1.725, -0.24), Vector3(0.055, 1.73, -0.215)], [0.02, 0.024, 0.02], hp, {"sides": 6, "per": 2})
	hs.blob(Vector3(0, 1.66, -0.18), Vector3(0.12, 0.06, 0.07), hp, {"lat": 6, "lon": 9})
	# The pukao: a broad cylinder of red scoria balanced on the head.
	hs.lathe(Vector3(0, 2.4, 0.03), [Vector2(0.0, 0.14), Vector2(0.16, 0.14), Vector2(0.24, 0.1), Vector2(0.26, -0.05), Vector2(0.22, -0.1), Vector2(0.0, -0.1)], scoria, {"sides": 16})
	part(head, "Head", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.1 * side, 2.12, -0.193), Vector3(0.022, 0.022, 0.008), ew, {"lat": 4, "lon": 7})
	var core := glow_part(head, "Eyes", es)
	launch(head, Vector3(0, 2.12, -0.5))
	# Stone rings circling it like a planet's, set with crystal, and a halo ring behind the head.
	var sway: Array = []
	var defs := [[Vector3(0, 1.3, 0), Basis(Vector3.RIGHT, PI * 0.5 + 0.25), 0.85, 0.05], [Vector3(0, 1.3, 0), Basis(Vector3.RIGHT, PI * 0.5 - 0.3) * Basis(Vector3.FORWARD, 0.25), 1.0, 0.035], [Vector3(0, 2.05, 0.3), Basis.IDENTITY, 0.55, 0.035]]
	for k in range(defs.size()):
		var c: Vector3 = defs[k][0]
		var j := joint(root, "Ring%d" % k, c)
		var rs := Sculpt.new(); var rp := rs.add_painter(tuff); var rc := rs.add_painter(quartz)
		var b: Basis = defs[k][1]
		ring(rs, rp, c, b, defs[k][2], defs[k][3], 0.6)
		for z in range(10 if k < 2 else 8):
			var a := TAU * z / (10.0 if k < 2 else 8.0) + k
			var at := c + b * Vector3(cos(a), sin(a), 0) * float(defs[k][2])
			rs.crystal(at, b * Vector3(cos(a), sin(a), 0) + Vector3(0, 0.3, 0), 0.12, 0.03, rc, 6, z)
		part(j, "Ring", rs)
		sway.append(j)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": sway}, 1.55)
	return _sway_rig(node, head, sway)


# ------------------------------------------------------------------ C: aurora seraph

func _aurora() -> Node3D:
	var bs := Sculpt.new(); var sp := bs.add_painter(granite); var cp := bs.add_painter(quartz)
	var deep := bs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#5a6aa8").lerp(Color("#e8fff4"), clampf(v + Sculpt.noise(p * 8.0) * 0.2, 0.0, 1.0)))
	# The body: one great quartz point hanging point-down beneath a stone mantle.
	bs.crystal(Vector3(0, 1.55, 0), Vector3(0, -1, 0), 1.05, 0.3, deep, 6, 0.3)
	cluster(bs, cp, Vector3(0, 1.2, 0), Vector3(0, -1, 0.15), 6, 0.35, 0.12, 0.5, 0.9)
	bs.blob(Vector3(0, 1.66, 0), Vector3(0.36, 0.2, 0.24), sp, {"lat": 10, "lon": 14, "lump": 0.06})
	for side in [-1.0, 1.0]:
		var c := Vector3(0.36 * side, 1.78, 0)
		box(bs, sp, c, Basis(Vector3.FORWARD, -0.35 * side), Vector3(0.13, 0.08, 0.15))
		cluster(bs, cp, c + Vector3(0.05 * side, 0.06, 0), Vector3(0.4 * side, 1, 0), 4, 0.16, 0.04, side)
	bs.tube([Vector3(0, 1.8, 0), Vector3(0, 1.92, 0)], [0.1, 0.08], sp, {"sides": 10, "per": 2})
	part(root, "Body", bs)
	var gs := Sculpt.new(); var gw := gs.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	gs.blob(Vector3(0, 1.38, 0), Vector3(0.09, 0.14, 0.09), gw, {"lat": 6, "lon": 8})
	var heart := part(root, "Heart", gs, glow); heart.material_override = glow
	# The head: a serene carved stone mask.
	var head := joint(root, "Head", Vector3(0, 2.05, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return granite(p, n, v, w).lightened(0.25))
	var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#06080c"))
	hs.blob(Vector3(0, 2.05, 0.02), Vector3(0.14, 0.18, 0.13), hp, {"lat": 10, "lon": 14})
	hs.blob(Vector3(0, 2.06, -0.06), Vector3(0.12, 0.16, 0.07), hp, {"lat": 10, "lon": 12})
	hs.tube([Vector3(0, 2.1, -0.125), Vector3(0, 2.02, -0.145)], [0.016, 0.022], hp, {"sides": 6, "per": 2})
	hs.tube([Vector3(-0.03, 1.955, -0.12), Vector3(0, 1.95, -0.125), Vector3(0.03, 1.955, -0.12)], [0.006, 0.007, 0.006], hd, {"sides": 4, "per": 2})
	part(head, "Mask", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.045 * side, 2.08, -0.115), Vector3(0.03, 0.008, 0.01), ew, {"lat": 4, "lon": 7})
	var core := glow_part(head, "Eyes", es)
	launch(head, Vector3(0, 2.08, -0.5))
	var sway: Array = []
	# Three halo rings behind the head, one inside another, studded with crystal.
	for k in range(3):
		var c := Vector3(0, 2.08, 0.2 + k * 0.04)
		var j := joint(root, "Halo%d" % k, c)
		var rs := Sculpt.new(); var rp := rs.add_painter(granite); var rc := rs.add_painter(quartz)
		var r := 0.34 + k * 0.16
		var b := Basis(Vector3.FORWARD, k * 0.3) * Basis(Vector3.RIGHT, (k - 1) * 0.12)
		ring(rs, rp, c, b, r, 0.03 - k * 0.004, 0.5)
		for z in range(6 + k * 3):
			var a := TAU * z / (6.0 + k * 3.0)
			rs.crystal(c + b * Vector3(cos(a), sin(a), 0) * r, b * Vector3(cos(a), sin(a), 0), 0.08 + 0.03 * (z % 2), 0.02, rc, 6, z)
		part(j, "Halo", rs)
		sway.append(j)
	# Arms of floating stone: an upper block, a forearm block and a hand, with gaps between them
	# where crystal light shows.
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.46 * side, 1.74, 0)
		var arm := joint(root, "%sArm" % ("Left" if side < 0 else "Right"), sh)
		var as_ := Sculpt.new(); var ap := as_.add_painter(granite); var ac := as_.add_painter(quartz)
		var el := sh + Vector3(0.12 * side, -0.38, -0.02)
		var wr := el + Vector3(0.04 * side, -0.3, -0.18)
		box(as_, ap, sh.lerp(el, 0.5), Basis(Vector3.FORWARD, -0.3 * side), Vector3(0.08, 0.15, 0.08))
		box(as_, ap, el.lerp(wr, 0.55), Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.FORWARD, -0.12 * side), Vector3(0.065, 0.12, 0.065))
		as_.crystal(el + Vector3(0, 0.03, 0), Vector3(0.2 * side, -1, -0.2), 0.08, 0.035, ac, 6)
		as_.blob(wr + Vector3(0, -0.04, -0.04), Vector3(0.06, 0.08, 0.03), ap, {"lat": 5, "lon": 7})
		for f in range(4):
			var f0 := wr + Vector3((0.035 - f * 0.023) * side, -0.11, -0.04)
			as_.tube([f0, f0 + Vector3(0, -0.05, -0.01), f0 + Vector3(0, -0.08, -0.03)], [0.015, 0.013, 0.01], ap, {"sides": 6, "per": 2})
		part(arm, "Arm", as_)
		sway.append(arm)
	# Curtains of aurora hanging from a ring at its crown: green at the lower edge, fading up
	# through violet into red, folded in waves like the real curtains.
	var au := Sculpt.new()
	var ap2 := au.add_painter(func (p: Vector3, _n, v: float, w: float) -> Color:
		var c := Color("#4aff9a").lerp(Color("#9a5aff"), smoothstep(0.2, 0.65, v)).lerp(Color("#ff4a6a"), smoothstep(0.7, 1.0, v))
		var streak := 0.6 + 0.4 * sin(w * 70.0 + Sculpt.noise(p * 4.0) * 3.0)
		var a := smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.85, 1.0, v)) * 0.7 * streak
		return Color(c.r, c.g, c.b, a))
	var tops: Array = []; var outs: Array = []; var lens: Array = []
	var n := 26
	for k in range(n + 1):
		var a := lerpf(-2.3, 2.3, k / float(n))
		var r := 0.42 + 0.06 * sin(k * 1.3)
		tops.append(Vector3(sin(a) * r, 1.0, cos(a) * r * 0.8 + 0.18)); outs.append(Vector3(sin(a), 0, cos(a)).normalized())
		lens.append(1.25 + 0.2 * sin(k * 0.9))
	var base := au._v.size()
	for i in range(tops.size()):
		var t0: Vector3 = tops[i]; var o: Vector3 = outs[i]; var l: float = lens[i]
		for j in range(13):
			var t := j / 12.0
			# Rising from the hem upward: v is 0 at the bottom (green) and 1 at the top (red).
			var q := t0 + Vector3(0, l * t, 0) + o * (0.08 * sin(i * 0.9 + t * 4.0) + 0.25 * t * t)
			au._v.append(q); au._along.append(t); au._ridge.append(i / float(n)); au._painter.append(ap2)
	for i in range(tops.size() - 1):
		for j in range(12):
			var a := base + i * 13 + j; var b := a + 13
			au._i.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var aj := joint(root, "Aurora", Vector3(0, 1.6, 0.18))
	part(aj, "Aurora", au, aurora_mat)
	sway.append(aj)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": sway}, 1.6)
	return _sway_rig(node, head, sway)
