extends "res://tools/sculpt_slag_crawler.gd"
## The Grave Creeper of Hollowmourn, sculpted by hand: a thing of long folded limbs that lies
## among the graves with a crust of stone on its back, so it looks like one more broken grave
## until the gravestones scrape and it unfolds. Three designs, each built on a real animal:
##   assassin  - a giant assassin bug. Some real assassin bugs pile the husks of their prey and
##               bits of debris on their backs as camouflage; this one carries broken gravestones,
##               bones, a skull and grave moss. A narrow head with bulging eyes and elbowed
##               antennae, a curved beak folded under it, and long thin folded legs
##   mantis    - a giant praying mantis whose folded wing-cases are two slabs of lichened grave
##               stone: a long neck (the prothorax), a triangle head with huge eyes, and spiked
##               raptorial forelegs folded as if in prayer, ready to snap out
##   crab      - a Japanese spider crab, the crab with the longest legs of any animal, and like
##               the decorator crabs it covers its shell with whatever it finds: a cracked
##               headstone stuck upright in its back, moss, ivy and bones

const GRANITE := Color("#6e6f6c")
const GRANITE_LIGHT := Color("#a3a49e")
const LICHEN := Color("#b8b878")

var kind := "assassin"


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	glow.albedo_color = Color("#a8ffb0").darkened(0.2); glow.emission = Color("#9affa8")
	glow.emission_energy_multiplier = 1.6


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GraveCreeper"
	kind = variant
	match variant:
		"assassin": return _assassin()
		"mantis": return _mantis()
		"crab": return _crab()
	return null


# ------------------------------------------------------------------ painters

## Grave stone: weathered grey granite, speckled, stained darker in the hollows, crusted with
## pale lichen rosettes and green moss on the upper faces.
static func grave_stone(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := GRANITE.lerp(GRANITE_LIGHT, clampf(n.y * 0.25 + 0.35 + Sculpt.fbm(p * 6.0) * 0.45, 0.0, 1.0))
	c = c.darkened(smoothstep(0.55, 0.7, Sculpt.noise(p * 40.0)) * 0.25)
	c = c.darkened(clampf(-w, 0.0, 1.0) * 0.3)
	c = c.lerp(LICHEN, smoothstep(0.58, 0.72, Sculpt.noise(p * 13.0 + Vector3(4, 1, 7))) * 0.75)
	return c.lerp(grave_moss(p, n, 0.0, 0.0), smoothstep(0.55, 0.9, n.y + Sculpt.fbm(p * 4.0) * 0.6) * 0.45)


## Grave moss: dull dark green going grey, not the bright moss of the forest.
static func grave_moss(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return moss_color(p).darkened(0.3).lerp(Color("#4a5040"), 0.45).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)


## Chitin: dark earthy brown-grey, a little paler on top, with faint pale bands.
static func chitin(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#221e1c").lerp(Color("#554c44"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(p * 9.0) * 0.35, 0.0, 1.0))
	return c.lerp(Color("#8a7e6c"), smoothstep(0.82, 0.95, sin(v * 18.0)) * 0.3)


static func bone(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#d8cfb6").lerp(Color("#6e6250"), clampf(0.15 - n.y * 0.25 + Sculpt.fbm(p * 14.0) * 0.5, 0.0, 1.0))


static func soil(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#2a2018").lerp(Color("#4a3a2a"), clampf(n.y * 0.3 + Sculpt.fbm(p * 10.0) * 0.6, 0.0, 1.0))


# ------------------------------------------------------------------ shared pieces

## A jointed leg through `pts`, bending at pts[knee]. Returns [hip, knee].
func jleg(parent: Node3D, label: String, pts: Array, radii: Array, paint: Callable, knee := 1) -> Array:
	var hip := joint(parent, label, pts[0])
	var us := Sculpt.new(); var up := us.add_painter(paint)
	us.tube(pts.slice(0, knee + 1), radii.slice(0, knee + 1), up, {"sides": 7, "per": 2, "ridges": 3, "ridge": 0.08})
	us.blob(pts[knee], Vector3.ONE * float(radii[knee]) * 1.15, up, {"lat": 4, "lon": 6})
	part(hip, "Femur", us)
	var kn := joint(hip, "Knee", pts[knee])
	var ls := Sculpt.new(); var lp := ls.add_painter(paint)
	var lr: Array = radii.slice(knee); lr[-1] = 0.004
	ls.tube(pts.slice(knee), lr, lp, {"sides": 6, "per": 2, "cap1": false})
	for j in range(knee + 1, pts.size() - 1): ls.blob(pts[j], Vector3.ONE * float(radii[j]) * 1.1, lp, {"lat": 4, "lon": 6})
	part(kn, "Tibia", ls)
	return [hip, kn]


## A broken gravestone slab: rounded top, chipped, with a carved cross on its face.
func headstone(s: Sculpt, painter: int, cut: int, c: Vector3, size: Vector3, b: Basis, broken := false) -> void:
	slab(s, painter, c, size, b, 0.35, 0.05)
	if not broken:
		s.blob(c + b * Vector3(0, size.y * 0.5, 0), Vector3(size.x * 0.5, size.y * 0.16, size.z * 0.5), painter, {"lat": 4, "lon": 10, "basis": b})
	var face := c + b * Vector3(0, size.y * 0.1, -size.z * 0.52)
	s.tube([face + b * Vector3(0, size.y * 0.25, 0), face + b * Vector3(0, -size.y * 0.25, 0)], [size.x * 0.05, size.x * 0.05], cut, {"sides": 4, "per": 1})
	s.tube([face + b * Vector3(-size.x * 0.18, size.y * 0.1, 0), face + b * Vector3(size.x * 0.18, size.y * 0.1, 0)], [size.x * 0.05, size.x * 0.05], cut, {"sides": 4, "per": 1})


## A small skull lying at `c`, facing `fwd`.
func little_skull(s: Sculpt, bp: int, dark: int, c: Vector3, size: float) -> void:
	s.blob(c, Vector3(0.9, 0.85, 1.0) * size, bp, {"lat": 7, "lon": 10})
	s.blob(c + Vector3(0, -size * 0.45, -size * 0.55), Vector3(0.6, 0.4, 0.55) * size, bp, {"lat": 5, "lon": 8})
	for side: float in [-1.0, 1.0]: s.blob(c + Vector3(0.35 * side, -0.05, -0.8) * size, Vector3(0.25, 0.25, 0.15) * size, dark, {"lat": 4, "lon": 6})
	s.blob(c + Vector3(0, -0.4, -0.95) * size, Vector3(0.1, 0.14, 0.08) * size, dark, {"lat": 3, "lon": 5})


# ------------------------------------------------------------------ A: assassin bug

func _assassin() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(chitin)
	# The abdomen: broad and flat with flared edges (the connexivum), banded light and dark.
	var band := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return chitin(p, n, v, w).lerp(Color("#9a8a70"), smoothstep(0.6, 0.9, sin(p.z * 40.0)) * 0.6))
	body.blob(Vector3(0, 0.5, 0.25), Vector3(0.38, 0.17, 0.52), bp, {"lat": 9, "lon": 14})
	# The flared, banded edge of the abdomen, scalloped into a spiny rim.
	for k in range(9):
		for side: float in [-1.0, 1.0]:
			var z := lerpf(-0.12, 0.62, k / 8.0)
			var r := 0.4 * sqrt(maxf(0.0, 1.0 - pow((z - 0.25) / 0.55, 2.0)))
			body.blob(Vector3(r * side, 0.47, z), Vector3(0.06, 0.03, 0.045), band, {"lat": 4, "lon": 7})
			if k % 2 == 1: body.crystal(Vector3((r + 0.04) * side, 0.47, z), Vector3(side, 0.1, 0.3), 0.07, 0.015, bp, 4)
	# The thorax: a two-lobed pronotum, the back lobe with a spine on each corner.
	body.blob(Vector3(0, 0.56, -0.28), Vector3(0.24, 0.12, 0.17), bp, {"lat": 8, "lon": 12, "lump": 0.08})
	body.blob(Vector3(0, 0.55, -0.44), Vector3(0.14, 0.09, 0.1), bp, {"lat": 6, "lon": 10})
	for side: float in [-1.0, 1.0]:
		body.crystal(Vector3(0.2 * side, 0.62, -0.22), Vector3(side, 0.6, 0.2), 0.12, 0.025, bp, 5)
		body.crystal(Vector3(0.08 * side, 0.63, -0.46), Vector3(0.3 * side, 1.0, -0.2), 0.06, 0.016, bp, 4)
	part(root, "Body", body)
	# The heap on its back: broken headstones, a skull, bones, grave soil and moss.
	var pile := Sculpt.new(); var sp := pile.add_painter(grave_stone); var cut := pile.add_painter(func (p, n, v, w): return Color("#2a2a2a"))
	var bn := pile.add_painter(bone); var dk := pile.add_painter(func (p, n, v, w): return Color("#100c0a"))
	var sl := pile.add_painter(soil); var mo := pile.add_painter(grave_moss)
	pile.blob(Vector3(0, 0.64, 0.22), Vector3(0.4, 0.16, 0.54), sl, {"lat": 7, "lon": 12, "lump": 0.35})
	headstone(pile, sp, cut, Vector3(0.04, 0.98, 0.4), Vector3(0.44, 0.56, 0.1), Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, 0.12), false)
	headstone(pile, sp, cut, Vector3(-0.22, 0.84, 0.04), Vector3(0.32, 0.34, 0.08), Basis(Vector3.UP, 0.9) * Basis(Vector3.BACK, -0.55), true)
	headstone(pile, sp, cut, Vector3(0.24, 0.82, -0.02), Vector3(0.28, 0.3, 0.08), Basis(Vector3.UP, -0.6) * Basis(Vector3.BACK, 0.6), true)
	headstone(pile, sp, cut, Vector3(0.0, 0.8, -0.12), Vector3(0.3, 0.12, 0.2), Basis(Vector3.RIGHT, -0.15), true)
	for k in range(7): pile.rock(Vector3(0.3 * sin(k * 2.4), 0.74, 0.22 + 0.36 * cos(k * 1.7)), Vector3(0.07, 0.05, 0.07) * (0.8 + 0.4 * fposmod(k * 0.618, 1.0)), sp, {"seed": 3 + k})
	little_skull(pile, bn, dk, Vector3(-0.16, 0.82, 0.56), 0.1)
	# A rusted iron cross from a grave, leaning out of the heap.
	var rust := pile.add_painter(func (p, n, v, w): return Color("#3a2a22").lerp(Color("#7a4a2a"), clampf(Sculpt.noise(p * 20.0) + 0.4, 0.0, 1.0)))
	pile.tube([Vector3(0.22, 0.72, 0.5), Vector3(0.3, 1.18, 0.62)], [0.022, 0.02], rust, {"sides": 5, "per": 1})
	pile.tube([Vector3(0.17, 1.04, 0.6), Vector3(0.39, 1.06, 0.56)], [0.02, 0.02], rust, {"sides": 5, "per": 1})
	for k in range(4):
		var a := Vector3(0.28 * sin(k * 1.9), 0.72, 0.1 + 0.15 * k); var b := a + Vector3(0.18 * cos(k * 2.3), 0.02, 0.12 * sin(k * 1.1))
		pile.tube([a, b], [0.016, 0.016], bn, {"sides": 5, "per": 1})
		pile.blob(a, Vector3.ONE * 0.024, bn, {"lat": 3, "lon": 5}); pile.blob(b, Vector3.ONE * 0.024, bn, {"lat": 3, "lon": 5})
	moss_collar(pile, mo, Vector3(0, 0.7, 0.22), 0.36, 12, 0.08)
	part(root, "Heap", pile)
	# The head: narrow and long on a neck, bulging eyes, elbowed antennae, a curved beak.
	var head := joint(root, "Head", Vector3(0, 0.56, -0.5))
	var hs := Sculpt.new(); var hp := hs.add_painter(chitin)
	hs.tube([Vector3(0, 0.56, -0.5), Vector3(0, 0.58, -0.62), Vector3(0, 0.57, -0.78)], [0.05, 0.07, 0.05], hp, {"sides": 10, "per": 3})
	var eye_at: Array = []
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.065 * side, 0.6, -0.66), Vector3(0.04, 0.045, 0.045), hs.add_painter(func (p, n, v, w): return Color("#120e0c")), {"lat": 5, "lon": 8})
		eye_at.append(Vector3(0.09 * side, 0.61, -0.68))
		var ab := Vector3(0.03 * side, 0.6, -0.78)
		hs.tube([ab, ab + Vector3(0.03 * side, 0.12, -0.1), ab + Vector3(0.06 * side, 0.22, -0.2)], [0.012, 0.01, 0.009], hp, {"sides": 5, "per": 2})
		antenna(hs, hp, ab + Vector3(0.06 * side, 0.22, -0.2), Vector3(0.4 * side, -0.1, -1.0), 0.4, 0.008, 0.25)
	part(head, "Head", hs)
	var core := _eyes(head, eye_at, 0.018)
	var beak := joint(head, "Beak", Vector3(0, 0.55, -0.78))
	var ks := Sculpt.new(); var kp := ks.add_painter(chitin)
	ks.tube([Vector3(0, 0.55, -0.78), Vector3(0, 0.5, -0.84), Vector3(0, 0.44, -0.8), Vector3(0, 0.42, -0.72)], [0.022, 0.018, 0.014, 0.004], kp, {"sides": 6, "per": 3, "cap1": false})
	part(beak, "Beak", ks)
	# Six long thin legs, the front pair thicker for grabbing, all folded high at the knee.
	var hips: Array = []; var knees: Array = []; var pincers: Array = []
	var rows := [[-0.36, -0.9, 0.8, 0.05], [-0.2, -0.1, 0.78, 0.042], [0.05, 0.7, 0.88, 0.042]]
	for r: Array in rows:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(0.14 * side, 0.48, r[0])
			var o := Vector3(side, 0, float(r[1]) * 0.6).normalized()
			var reach: float = r[2]
			var kn := at + o * reach * 0.42 + Vector3(0, 0.22, 0)
			var ft := at + o * reach + Vector3(0, -0.47, 0)
			var mid := kn.lerp(ft, 0.6) + o * 0.05
			var th: float = r[3]
			var leg := jleg(root, "Leg%d" % hips.size(), [at, kn, mid, ft], [th, th * 0.9, th * 0.7, th * 0.4], chitin)
			hips.append(leg[0]); knees.append(leg[1])
			if r[0] < -0.3: pincers.append(leg[1])
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.6)
	return _rig(node, head, hips, knees, beak, [], pincers)


# ------------------------------------------------------------------ B: grave mantis

func _mantis() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(chitin)
	# The abdomen, long and segmented, held low behind; the wing-cases cover it.
	var ab: Array = []; var ar: Array = []
	for k in range(7):
		var t := k / 6.0
		ab.append(Vector3(0, 0.5 + 0.06 * sin(t * PI) - t * 0.08, -0.1 + t * 0.85)); ar.append(0.15 * sin(PI * (0.2 + 0.7 * t)) + 0.03)
	for k in range(ar.size()): ar[k] = float(ar[k]) * 1.3
	body.tube(ab, ar, bp, {"sides": 14, "per": 3, "flat": 0.75, "bands": 7, "band": 0.12})
	body.blob(Vector3(0, 0.52, -0.16), Vector3(0.13, 0.12, 0.16), bp, {"lat": 7, "lon": 10})
	# The prothorax: a long neck rising forward to the head.
	body.tube([Vector3(0, 0.55, -0.22), Vector3(0, 0.75, -0.42), Vector3(0, 0.98, -0.56)], [0.085, 0.065, 0.06], bp, {"sides": 10, "per": 3, "flat": 0.8})
	# A ridge of stone knobs along the neck, as if it too were carved.
	for k in range(5): body.rock(Vector3(0, 0.62 + k * 0.08, -0.3 - k * 0.055), Vector3(0.035, 0.025, 0.03), body.add_painter(grave_stone), {"seed": k})
	body.blob(Vector3(0, 0.66, -0.33), Vector3(0.1, 0.05, 0.08), bp, {"lat": 5, "lon": 8})
	part(root, "Body", body)
	# The wing-cases: two long slabs of grave stone folded over the back, overlapping.
	var wings := Sculpt.new(); var wp := wings.add_painter(grave_stone); var cut := wings.add_painter(func (p, n, v, w): return Color("#33332f"))
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3.FORWARD, 0.35 * side) * Basis(Vector3.RIGHT, 0.12)
		slab(wings, wp, Vector3(0.09 * side, 0.7 + (0.01 if side > 0 else 0.0), 0.33), Vector3(0.26, 0.06, 0.86), b, 0.4, 0.06)
		wings.blob(Vector3(0.07 * side, 0.64, 0.74), Vector3(0.1, 0.035, 0.08), wp, {"lat": 4, "lon": 8, "basis": b})
		# Veins carved into the stone, like an engraving.
		for k in range(3):
			var z := 0.05 + k * 0.22
			wings.tube([Vector3(0.03 * side, 0.705, z), Vector3(0.13 * side, 0.66, z + 0.14)], [0.008, 0.006], cut, {"sides": 4, "per": 1})
	moss_clump(wings, wings.add_painter(grave_moss), Vector3(0.0, 0.72, 0.5), 0.08, 5)
	part(root, "WingCases", wings)
	# The triangle head with huge eyes, mandibles and two thin antennae.
	var head := joint(root, "Head", Vector3(0, 1.0, -0.58))
	var hs := Sculpt.new(); var hp := hs.add_painter(chitin); var hd := hs.add_painter(func (p, n, v, w): return Color("#1a1e16").lerp(Color("#3e4a34"), clampf(n.y, 0.0, 1.0)))
	hs.blob(Vector3(0, 1.02, -0.62), Vector3(0.09, 0.07, 0.06), hp, {"lat": 7, "lon": 10})
	hs.tube([Vector3(0, 1.0, -0.64), Vector3(0, 0.92, -0.67)], [0.05, 0.025], hp, {"sides": 8, "per": 2, "flat": 0.6})
	var eye_at: Array = []
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.1 * side, 1.06, -0.62), Vector3(0.06, 0.065, 0.06), hd, {"lat": 7, "lon": 10})
		eye_at.append(Vector3(0.108 * side, 1.065, -0.628))
		antenna(hs, hp, Vector3(0.025 * side, 1.08, -0.66), Vector3(0.3 * side, 1.0, -0.6), 0.45, 0.006, 0.4)
		hs.crystal(Vector3(0.02 * side, 0.92, -0.67), Vector3(-0.3 * side, -1, -0.2), 0.04, 0.012, hp, 4)
	part(head, "Head", hs)
	var core := _eyes(head, eye_at, 0.056)
	# The raptorial forelegs folded under the head, spiked, on their own joints so they unfold.
	var hips: Array = []; var knees: Array = []; var pincers: Array = []
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.06 * side, 0.82, -0.48)
		var arm := joint(root, "ForelegLeft" if side < 0 else "ForelegRight", at)
		var cs := Sculpt.new(); var cp := cs.add_painter(chitin); var spk := cs.add_painter(func (p, n, v, w): return Color("#cfc6b0").lerp(Color("#3a3028"), 1.0 - v))
		var elbow := at + Vector3(0.07 * side, -0.2, -0.16)
		var wrist := elbow + Vector3(0.0, 0.42, -0.12)
		cs.tube([at, elbow], [0.05, 0.045], cp, {"sides": 7, "per": 2})
		cs.tube([elbow, elbow.lerp(wrist, 0.5) + Vector3(0, 0, -0.03), wrist], [0.045, 0.065, 0.04], cp, {"sides": 8, "per": 2, "ridges": 3, "ridge": 0.1})
		for k in range(7):
			var sp_at := elbow.lerp(wrist, 0.12 + k * 0.12) + Vector3(0, 0, 0.03)
			cs.crystal(sp_at, Vector3(0.2 * side, -0.2, 1.0), 0.08 if k % 2 == 0 else 0.045, 0.013, spk, 4)
		part(arm, "Femur", cs)
		var hinge := joint(arm, "Tibia", wrist)
		var ts := Sculpt.new(); var tp := ts.add_painter(chitin); var tk := ts.add_painter(func (p, n, v, w): return Color("#cfc6b0").lerp(Color("#3a3028"), 1.0 - v))
		var claw := wrist + Vector3(0, -0.36, 0.07)
		ts.tube([wrist, wrist.lerp(claw, 0.6) + Vector3(0, 0, 0.04), claw], [0.038, 0.03, 0.008], tp, {"sides": 6, "per": 2, "cap1": false})
		ts.crystal(claw, Vector3(0, -0.4, -1.0), 0.09, 0.013, tk, 4)
		for k in range(6): ts.crystal(wrist.lerp(claw, 0.12 + k * 0.14) + Vector3(0, 0, -0.015), Vector3(0.2 * side, 0.1, -1.0), 0.045, 0.009, tk, 4)
		part(hinge, "Tibia", ts)
		pincers.append(hinge)
	# Four long thin walking legs.
	for r: Array in [[-0.12, -0.2, 0.8], [0.02, 0.8, 0.95]]:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(0.08 * side, 0.5, r[0])
			var o := Vector3(side, 0, float(r[1])).normalized()
			var reach: float = r[2]
			var kn := at + o * reach * 0.42 + Vector3(0, 0.25, 0)
			var ft := at + o * reach + Vector3(0, -0.49, 0)
			var leg := jleg(root, "Leg%d" % hips.size(), [at, kn, kn.lerp(ft, 0.7), ft], [0.034, 0.03, 0.02, 0.01], chitin)
			hips.append(leg[0]); knees.append(leg[1])
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.8)
	return _rig(node, head, hips, knees, null, [], pincers)


# ------------------------------------------------------------------ C: spider crab

func _crab() -> Node3D:
	var shell_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return chitin(p, n, v, w).lerp(Color("#5a3424"), 0.35).lerp(LICHEN, smoothstep(0.62, 0.75, Sculpt.noise(p * 12.0)) * 0.5)
	var body := Sculpt.new(); var bp := body.add_painter(shell_paint)
	# A pear-shaped carapace, narrow in front, studded with spiny knobs, two horns at the front.
	body.blob(Vector3(0, 0.62, 0.02), Vector3(0.34, 0.17, 0.36), bp, {"lat": 9, "lon": 14, "lump": 0.08})
	body.blob(Vector3(0, 0.62, -0.26), Vector3(0.2, 0.13, 0.16), bp, {"lat": 7, "lon": 10})
	for k in range(26):
		var a := lerpf(-2.6, 2.6, fposmod(k * 0.618, 1.0)); var z := lerpf(-0.3, 0.3, fposmod(k * 0.37, 1.0))
		var r := 0.32 * sqrt(maxf(0.0, 1.0 - pow(z / 0.38, 2.0)))
		var at := Vector3(sin(a) * r, 0.62 + cos(a) * 0.15 * (1.0 - absf(z) * 0.8), z)
		body.crystal(at, Vector3(sin(a) * 0.5, 1.0, 0.0), 0.06, 0.02, bp, 4)
	for side: float in [-1.0, 1.0]:
		body.tube([Vector3(0.04 * side, 0.66, -0.38), Vector3(0.07 * side, 0.7, -0.5), Vector3(0.12 * side, 0.74, -0.58)], [0.03, 0.02, 0.004], bp, {"sides": 6, "per": 2, "cap1": false})
	part(root, "Shell", body)
	# Its decorations: a cracked headstone wedged upright in its back, moss, ivy and bones.
	var deco := Sculpt.new(); var sp := deco.add_painter(grave_stone); var cut := deco.add_painter(func (p, n, v, w): return Color("#2a2a28"))
	var bn := deco.add_painter(bone); var dk := deco.add_painter(func (p, n, v, w): return Color("#100c0a")); var mo := deco.add_painter(grave_moss)
	headstone(deco, sp, cut, Vector3(0.0, 1.0, 0.1), Vector3(0.42, 0.62, 0.1), Basis(Vector3.RIGHT, 0.18) * Basis(Vector3.BACK, 0.08))
	deco.tube([Vector3(-0.15, 1.25, 0.06), Vector3(-0.03, 1.12, 0.05), Vector3(0.02, 1.0, 0.04), Vector3(0.12, 0.86, 0.04)], [0.008, 0.007, 0.006, 0.005], cut, {"sides": 4, "per": 1})
	moss_collar(deco, mo, Vector3(0, 0.74, 0.05), 0.28, 12, 0.08)
	moss_clump(deco, mo, Vector3(0.12, 1.3, 0.13), 0.07, 4)
	little_skull(deco, bn, dk, Vector3(0.2, 0.8, 0.22), 0.07)
	for k in range(3):
		var a := Vector3(-0.22 + 0.1 * k, 0.76, 0.2 - 0.08 * k); var b := a + Vector3(0.1, 0.02, 0.14)
		deco.tube([a, b], [0.014, 0.014], bn, {"sides": 5, "per": 1})
	var ivy: Array = []
	for k in range(10): ivy.append(Vector3(0.24 - k * 0.05, 1.28 - k * 0.06, 0.03 + 0.02 * sin(k)))
	vine(deco, ivy, 0.02, 1.0, 0.007, 7)
	part(root, "Decorations", deco)
	# Stalked eyes and the mouthparts.
	var head := joint(root, "Head", Vector3(0, 0.6, -0.36))
	var hs := Sculpt.new(); var hp := hs.add_painter(shell_paint)
	var eye_at: Array = []
	for side: float in [-1.0, 1.0]:
		hs.tube([Vector3(0.08 * side, 0.64, -0.36), Vector3(0.1 * side, 0.69, -0.42)], [0.018, 0.015], hp, {"sides": 6, "per": 1})
		eye_at.append(Vector3(0.105 * side, 0.705, -0.43))
	hs.blob(Vector3(0, 0.52, -0.38), Vector3(0.1, 0.06, 0.05), hp, {"lat": 5, "lon": 8, "lump": 0.3})
	part(head, "Head", hs)
	var core := _eyes(head, eye_at, 0.022)
	# Long thin claws in front, on their own joints.
	var hips: Array = []; var knees: Array = []; var pincers: Array = []
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.14 * side, 0.55, -0.3)
		var arm := joint(root, "ClawArmLeft" if side < 0 else "ClawArmRight", at)
		var cs := Sculpt.new(); var cp := cs.add_painter(shell_paint)
		var elbow := at + Vector3(0.22 * side, 0.15, -0.2)
		var wrist := elbow + Vector3(-0.08 * side, -0.18, -0.3)
		cs.tube([at, elbow, wrist], [0.045, 0.04, 0.038], cp, {"sides": 7, "per": 2, "ridges": 3, "ridge": 0.1})
		cs.blob(elbow, Vector3.ONE * 0.045, cp, {"lat": 4, "lon": 6})
		var palm := wrist + Vector3(0, -0.02, -0.1)
		cs.blob(palm, Vector3(0.06, 0.05, 0.12), cp, {"lat": 6, "lon": 9})
		cs.tube([palm + Vector3(0.015 * side, 0, -0.09), palm + Vector3(0.02 * side, -0.01, -0.24)], [0.022, 0.004], cp, {"sides": 5, "per": 1, "cap1": false})
		part(arm, "Claw", cs)
		var hinge := joint(arm, "Pincer", palm + Vector3(-0.02 * side, 0, -0.09))
		var ps := Sculpt.new(); var pp := ps.add_painter(shell_paint)
		ps.tube([palm + Vector3(-0.02 * side, 0, -0.09), palm + Vector3(-0.026 * side, 0.015, -0.23)], [0.02, 0.004], pp, {"sides": 5, "per": 1, "cap1": false})
		part(hinge, "Finger", ps)
		pincers.append(hinge)
	# Eight very long walking legs, knees raised high, spreading far out around it.
	for j in range(4):
		for side: float in [-1.0, 1.0]:
			var at := Vector3(0.28 * side, 0.58, -0.18 + j * 0.14)
			var o := Vector3(side, 0, -0.7 + j * 0.5).normalized()
			var reach := 1.45 - absf(j - 1.2) * 0.18
			var kn := at + o * reach * 0.36 + Vector3(0, 0.32, 0)
			var ft := at + o * reach + Vector3(0, -0.57, 0)
			var mid := kn.lerp(ft, 0.5) + o * 0.12 + Vector3(0, 0.08, 0)
			var leg := jleg(root, "Leg%d" % hips.size(), [at, kn, mid, ft], [0.05, 0.045, 0.034, 0.016], shell_paint)
			# Spines along the upper leg, like the real crab's.
			var lsp := Sculpt.new(); var lpp := lsp.add_painter(shell_paint)
			for q in range(4): lsp.crystal(at.lerp(kn, 0.2 + q * 0.2) + Vector3(0, 0.04, 0), Vector3(0, 1, 0.2), 0.05, 0.012, lpp, 4)
			part(leg[0], "Spines", lsp)
			hips.append(leg[0]); knees.append(leg[1])
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.5)
	return _rig(node, head, hips, knees, null, [], pincers)
