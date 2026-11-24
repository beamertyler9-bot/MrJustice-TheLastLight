extends "res://tools/sculpt_riftback.gd"
## The Slag Crawler of the Ashfall Caldera, sculpted by hand: a low armoured crawler on many
## jointed legs, its armour made of slag (the glassy black, rust-streaked crust that forms on
## molten rock and metal), lava glowing in its joints, steam venting from it before it splashes
## molten slag. Three designs, each built on a real animal:
##   hermit   - a giant hermit crab living in a coiled shell of slag that steams from its vents:
##              one huge crushing claw and one smaller one, stalked eyes, long antennae and two
##              pairs of big walking legs, the way a coconut crab or a land hermit crab is built
##   isopod   - a giant isopod (Bathynomus): a broad flat body of seven overlapping arched
##              plates, a head shield with big compound eyes, two pairs of antennae, seven pairs
##              of short legs and a fan-shaped tail
##   centipede - a giant centipede (Scolopendra): a long flat body of plated segments with a
##              pair of legs on each, long antennae, venom claws (forcipules) curled round the
##              mouth, and a long pair of trailing legs at the end

const SLAG := Color("#1f1a19")
const RUST := Color("#7a3b1c")


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "SlagCrawler"
	match variant:
		"hermit": return _hermit()
		"isopod": return _isopod()
		"centipede": return _centipede()
		"horseshoe": return _horseshoe()
	return null


# ------------------------------------------------------------------ painters

## Slag: glassy black-brown, streaked and blotched with rust, pitted with bubbles.
static func slag(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := SLAG.lerp(Color("#4a403d"), clampf(n.y * 0.3 + 0.15 + Sculpt.fbm(p * 7.0) * 0.4, 0.0, 1.0))
	c = c.lerp(RUST, smoothstep(0.15, 0.55, Sculpt.fbm(p * 3.0 + Vector3(3, 7, 1))) * 0.6)
	c = c.lerp(Color("#b0562a"), smoothstep(0.62, 0.8, Sculpt.noise(p * 11.0)) * 0.35)
	return c.darkened(smoothstep(0.5, 0.65, Sculpt.noise(p * 50.0)) * 0.5)


## The softer jointed parts: dark red-brown, glowing a little hotter in the creases.
static func joint_skin(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	return Color("#3a1d14").lerp(Color("#6a2d18"), clampf(n.y * 0.4 + 0.3 + Sculpt.fbm(p * 12.0) * 0.3, 0.0, 1.0)).lerp(Color("#c2441a"), clampf(-w, 0.0, 1.0) * 0.4)


static func steam(_p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#6f6a66").lerp(Color("#b8b3ad"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0))


# ------------------------------------------------------------------ shared pieces

## A lathe profile with more rings, so the curve is smooth.
static func dense(profile: Array, per: int) -> Array:
	var out: Array = []
	for k in range(profile.size() - 1):
		var a: Vector2 = profile[k]; var b: Vector2 = profile[k + 1]
		for i in range(per): out.append(a.lerp(b, float(i) / per))
	out.append(profile[-1])
	return out

## A jointed arthropod leg: up and out to the knee, then down to a sharp tip. Returns
## [hip, knee].
func crawler_leg(parent: Node3D, label: String, at: Vector3, out: Vector3, reach: float, rise: float, thick: float) -> Array:
	var o := Vector3(out.x, 0, out.z).normalized()
	var hip := joint(parent, label, at)
	var knee_at := at + o * reach * 0.45 + Vector3(0, rise, 0)
	var ts := Sculpt.new(); var tp := ts.add_painter(slag); var jp := ts.add_painter(joint_skin)
	ts.tube([at, at.lerp(knee_at, 0.5) + Vector3(0, 0.02, 0), knee_at], [thick, thick * 1.05, thick * 0.85], tp, {"sides": 7, "per": 2, "ridges": 3, "ridge": 0.1})
	ts.blob(knee_at, Vector3.ONE * thick * 1.0, jp, {"lat": 4, "lon": 6})
	part(hip, "Femur", ts)
	var knee := joint(hip, "Knee", knee_at)
	var tip := at + o * reach + Vector3(0, -at.y + 0.01, 0)
	var mid := knee_at.lerp(tip, 0.55) + o * reach * 0.06
	var ss := Sculpt.new(); var sp := ss.add_painter(slag); var sj := ss.add_painter(joint_skin)
	ss.tube([knee_at, mid], [thick * 0.85, thick * 0.7], sp, {"sides": 7, "per": 2, "ridges": 3, "ridge": 0.1})
	ss.blob(mid, Vector3.ONE * thick * 0.75, sj, {"lat": 4, "lon": 6})
	ss.tube([mid, tip + Vector3(0, 0.01, 0)], [thick * 0.6, thick * 0.12], sp, {"sides": 6, "per": 2, "cap1": false})
	part(knee, "Tibia", ss)
	return [hip, knee]


## Puffs of steam rising from `at`.
func steam_puffs(s: Sculpt, painter: int, at: Vector3, size: float, count := 3) -> void:
	for k in range(count):
		s.blob(at + Vector3(0.02 * sin(k * 2.1), size * (0.5 + k * 1.1), 0.04 * k), Vector3(1.0, 0.75, 1.0) * size * (0.6 + 0.3 * k), painter, {"lat": 5, "lon": 7, "lump": 0.6})


## A long feeler from `at` sweeping along `dir`.
func antenna(s: Sculpt, painter: int, at: Vector3, dir: Vector3, length: float, thick: float, droop := 0.15) -> void:
	var d := dir.normalized()
	s.tube([at, at + d * length * 0.35 + Vector3(0, length * 0.08, 0), at + d * length * 0.7 + Vector3(0, length * 0.05, 0), at + d * length + Vector3(0, -length * droop, 0)], [thick, thick * 0.8, thick * 0.5, thick * 0.15], painter, {"sides": 5, "per": 3, "bands": 8, "band": 0.15})


# ------------------------------------------------------------------ A: hermit crab

func _hermit() -> Node3D:
	# The shell: a turban shell of slag. A big body whorl sits over the crab's back, opening
	# forward where the crab comes out; the spire winds back and up from it to a point, a
	# raised suture spiralling round it and knobbed spines on the shoulder of each whorl.
	var sh := Sculpt.new(); var sp := sh.add_painter(slag)
	var lava := Sculpt.new(); var lw := lava.add_painter(func (p, n, v, w): return Color.WHITE)
	var st := Sculpt.new(); var stp := st.add_painter(steam)
	var axis := Vector3(0, 0.75, 0.66).normalized()
	var base := Vector3(0, 0.55, 0.12)
	var ax_x := Vector3.RIGHT
	var ab := Basis(ax_x, axis, ax_x.cross(axis).normalized())
	var prof := [Vector2(0.0, -0.05), Vector2(0.3, -0.02), Vector2(0.42, 0.12), Vector2(0.38, 0.3), Vector2(0.28, 0.45), Vector2(0.18, 0.62), Vector2(0.09, 0.78), Vector2(0.0, 0.9)]
	var lprof := dense(prof, 3); lprof.reverse()
	sh.lathe(base, lprof, sp, {"sides": 28, "basis": ab})
	var pts: Array = []; var rs: Array = []
	for k in range(48):
		var t := k / 47.0
		var a2 := t * TAU * 3.2
		var h := lerpf(0.12, 0.84, t)
		# Ride on the shell's surface: look up its radius at this height.
		var rad := 0.0
		for j in range(prof.size() - 1):
			var p0: Vector2 = prof[j]; var p1: Vector2 = prof[j + 1]
			if h >= p0.y and h <= p1.y: rad = lerpf(p0.x, p1.x, (h - p0.y) / (p1.y - p0.y))
		pts.append(base + ab * Vector3(cos(a2) * rad, h, sin(a2) * rad)); rs.append(lerpf(0.035, 0.008, t))
	sh.tube(pts, rs, sp, {"sides": 6, "per": 2, "lump": 0.2})
	for k in range(2, 42, 2):
		var c: Vector3 = pts[k]
		var out := (c - (base + axis * axis.dot(c - base))).normalized()
		sh.crystal(c, (out + axis * 0.35).normalized(), 0.1 * (1.0 - k / 48.0) + 0.03, 0.026, sp, 5)
	# The lip of the shell's mouth, glowing inside, framing the crab.
	var lip: Array = []; var lr: Array = []
	for k in range(17):
		var a3 := TAU * k / 16.0
		lip.append(Vector3(cos(a3) * 0.3, 0.5 + sin(a3) * 0.24, -0.08)); lr.append(0.05)
	sh.tube(lip, lr, sp, {"sides": 8, "per": 2, "lump": 0.2})
	lava.blob(Vector3(0, 0.5, -0.05), Vector3(0.27, 0.21, 0.04), lw, {"lat": 6, "lon": 10})
	# Vents on the shell, glowing and steaming.
	for k in range(4):
		var i := 6 + k * 8
		var c: Vector3 = pts[i]
		var out := (c - (base + axis * axis.dot(c - base))).normalized()
		var at := c + out * 0.02 + axis * 0.02
		lava.blob(at, Vector3(0.035, 0.035, 0.035), lw, {"lat": 4, "lon": 6})
		if k % 2 == 0: steam_puffs(st, stp, at + Vector3(0, 0.04, 0), 0.045)
	part(root, "Shell", sh)
	part(root, "Steam", st)
	part(root, "Lava", lava, glow).material_override = glow

	# The crab coming out of the shell: an armoured front, stalked eyes, antennae, mouthparts.
	var head := joint(root, "Head", Vector3(0, 0.48, -0.2))
	var hs := Sculpt.new(); var hp := hs.add_painter(slag); var hj := hs.add_painter(joint_skin)
	hs.blob(Vector3(0, 0.45, -0.22), Vector3(0.24, 0.16, 0.2), hp, {"lat": 8, "lon": 12, "lump": 0.12})
	hs.blob(Vector3(0, 0.38, -0.36), Vector3(0.12, 0.08, 0.08), hj, {"lat": 6, "lon": 8})
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		var eb := Vector3(0.06 * side, 0.55, -0.36)
		hs.tube([eb, eb + Vector3(0.02 * side, 0.1, -0.03), eb + Vector3(0.03 * side, 0.17, -0.04)], [0.022, 0.018, 0.016], hj, {"sides": 6, "per": 2})
		hs.blob(eb + Vector3(0.03 * side, 0.19, -0.05), Vector3(0.03, 0.035, 0.03), hs.add_painter(func (p, n, v, w): return Color("#0d0908")), {"lat": 5, "lon": 7})
		eyes.append(eb + Vector3(0.032 * side, 0.19, -0.075))
		antenna(hs, hj, eb + Vector3(0, 0.04, -0.02), Vector3(0.5 * side, 0.6, -1.0), 0.6, 0.012, 0.3)
		antenna(hs, hj, eb + Vector3(-0.02 * side, 0.02, -0.03), Vector3(0.2 * side, 0.4, -1.0), 0.3, 0.008, 0.1)
	var core := _eyes(head, eyes, 0.017)
	part(head, "Head", hs)

	# Claws: the left one huge, for crushing; the right one smaller.
	var pincers: Array = []; var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var big := side < 0.0
		var k := 1.6 if big else 1.0
		var arm_at := Vector3(0.18 * side, 0.4, -0.3)
		var arm := joint(root, "ClawArmLeft" if big else "ClawArmRight", arm_at)
		var cs := Sculpt.new(); var cp := cs.add_painter(slag); var cj := cs.add_painter(joint_skin)
		var elbow := arm_at + Vector3(0.12 * side, 0.02, -0.12) * k
		var wrist := elbow + Vector3(-0.02 * side, 0.0, -0.12) * k
		cs.tube([arm_at, elbow], [0.045 * k, 0.05 * k], cp, {"sides": 8, "per": 2, "ridges": 4, "ridge": 0.1})
		cs.blob(elbow, Vector3.ONE * 0.05 * k, cj, {"lat": 5, "lon": 7})
		cs.tube([elbow, wrist], [0.05 * k, 0.06 * k], cp, {"sides": 8, "per": 2, "ridges": 4, "ridge": 0.1})
		# The palm and the fixed finger, studded with knobs.
		var palm := wrist + Vector3(0, 0, -0.08 * k)
		cs.blob(palm, Vector3(0.075, 0.06, 0.1) * k, cp, {"lat": 7, "lon": 10, "lump": 0.15})
		for j in range(5): cs.crystal(palm + Vector3((0.02 * j - 0.04) * k, 0.05 * k, (0.02 * j - 0.03) * k), Vector3(0, 1, -0.2), 0.02 * k, 0.008 * k, cp, 4)
		var f0 := palm + Vector3(0.03 * side * k, -0.01 * k, -0.08 * k)
		cs.tube([f0, f0 + Vector3(0.0, -0.005, -0.08) * k, f0 + Vector3(-0.015 * side, 0.0, -0.13) * k], [0.03 * k, 0.022 * k, 0.004], cp, {"sides": 7, "per": 2, "cap1": false})
		part(arm, "Claw", cs)
		# The moving finger, on its own hinge so the claw opens and snaps shut.
		var hinge_at := palm + Vector3(-0.035 * side * k, 0.0, -0.07 * k)
		var hinge := joint(arm, "Pincer", hinge_at)
		var ps := Sculpt.new(); var pp := ps.add_painter(slag)
		ps.tube([hinge_at, hinge_at + Vector3(-0.01 * side, 0.01, -0.08) * k, hinge_at + Vector3(0.02 * side, 0.0, -0.14) * k], [0.03 * k, 0.022 * k, 0.004], pp, {"sides": 7, "per": 2, "cap1": false})
		part(hinge, "Finger", ps)
		pincers.append(hinge)
		# Two pairs of big walking legs behind the claws.
		for j in range(2):
			var leg := crawler_leg(root, "Leg%d" % (hips.size()), Vector3(0.2 * side, 0.4, -0.18 + j * 0.13), Vector3(side, 0, -0.45 + j * 0.5), 0.72, 0.2, 0.06)
			hips.append(leg[0]); knees.append(leg[1])
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.35)
	return _rig(node, head, hips, knees, null, [], pincers)


# ------------------------------------------------------------------ B: giant isopod

func _isopod() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(slag); var bj := body.add_painter(joint_skin)
	var lava := Sculpt.new(); var lw := lava.add_painter(func (p, n, v, w): return Color.WHITE)
	var st := Sculpt.new(); var stp := st.add_painter(steam)
	# The soft underbody, and seven arched plates overlapping from front to back.
	body.blob(Vector3(0, 0.28, 0.05), Vector3(0.4, 0.14, 0.7), bj, {"lat": 8, "lon": 12})
	# The back: a broad low dome of seven overlapping plates, each with a raised rim at its back
	# edge lying over the next, lava glowing in the seam under the rim.
	body.blob(Vector3(0, 0.24, 0.0), Vector3(0.48, 0.3, 0.6), bp, {"lat": 14, "lon": 22, "lump": 0.05})
	var plates := 7
	for i in range(plates):
		var z := lerpf(-0.5, 0.5, (i + 0.5) / float(plates))
		var f := sqrt(maxf(1.0 - pow(z / 0.6, 2.0), 0.05))
		var w := 0.48 * f; var h := 0.3 * f
		var arc: Array = []; var ar: Array = []; var seam: Array = []; var sr: Array = []
		for j in range(13):
			var a := lerpf(-1.7, 1.7, j / 12.0)
			arc.append(Vector3(sin(a) * w * 1.04, 0.24 + cos(a) * h * 1.06, z)); ar.append(0.035)
			seam.append(Vector3(sin(a) * w * 1.0, 0.24 + cos(a) * h * 1.02, z + 0.035)); sr.append(0.012)
		body.tube(arc, ar, bp, {"sides": 6, "per": 2, "flat": 0.45, "side": Vector3.BACK, "lump": 0.15})
		lava.tube(seam, sr, lw, {"sides": 4, "per": 1, "cap_rings": 1})
		if i % 2 == 1: steam_puffs(st, stp, Vector3(0.16 * (1 if i % 4 == 1 else -1), 0.24 + h + 0.04, z + 0.04), 0.045)
		for side: float in [-1.0, 1.0]: body.crystal(Vector3(sin(1.7) * w * 1.04 * side, 0.24 + cos(1.7) * h, z), Vector3(side, -0.2, 0.4), 0.09, 0.028, bp, 4)
	# The tail fan: a broad plate with two pairs of paddles.
	body.blob(Vector3(0, 0.27, 0.64), Vector3(0.26, 0.06, 0.18), bp, {"lat": 6, "lon": 10, "lump": 0.1})
	for side: float in [-1.0, 1.0]:
		for j in range(2):
			slab(body, bp, Vector3((0.15 + j * 0.08) * side, 0.24, 0.72 + j * 0.03), Vector3(0.07, 0.025, 0.16), Basis(Vector3.UP, 0.35 * side), 0.4, 0.1)
	part(root, "Body", body)
	part(root, "Steam", st)
	part(root, "Lava", lava, glow).material_override = glow
	# The head shield with big glowing compound eyes and two pairs of antennae.
	var head := joint(root, "Head", Vector3(0, 0.3, -0.52))
	var hs := Sculpt.new(); var hp := hs.add_painter(slag); var hj := hs.add_painter(joint_skin)
	hs.blob(Vector3(0, 0.32, -0.58), Vector3(0.34, 0.15, 0.14), hp, {"lat": 7, "lon": 12, "lump": 0.1})
	for side: float in [-1.0, 1.0]:
		antenna(hs, hj, Vector3(0.06 * side, 0.3, -0.7), Vector3(0.6 * side, 0.1, -1.0), 0.7, 0.014, 0.25)
		antenna(hs, hj, Vector3(0.03 * side, 0.28, -0.71), Vector3(0.2 * side, 0.2, -1.0), 0.18, 0.01, 0.05)
	var core := _eyes(head, [Vector3(-0.22, 0.36, -0.62), Vector3(0.22, 0.36, -0.62)], 0.05)
	part(head, "Head", hs)
	# Seven pairs of short legs.
	var hips: Array = []; var knees: Array = []
	for i in range(7):
		var z := lerpf(-0.4, 0.4, i / 6.0)
		for side: float in [-1.0, 1.0]:
			var leg := crawler_leg(root, "Leg%d" % hips.size(), Vector3(0.3 * side, 0.2, z), Vector3(side, 0, -0.4 + i * 0.13), 0.4, 0.06, 0.028)
			hips.append(leg[0]); knees.append(leg[1])
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.4)
	return _rig(node, head, hips, knees, null, [])


# ------------------------------------------------------------------ C: giant centipede

func _centipede() -> Node3D:
	# The body is a chain of segments the game can sway; each carries its plate and legs.
	var hips: Array = []; var knees: Array = []; var tails: Array = []
	var segs := 13
	var path: Array = []
	for i in range(segs + 1):
		var t := i / float(segs)
		path.append(Vector3(0.22 * sin(t * PI * 1.6), 0.2, -0.55 + t * 1.9))
	var parent: Node3D = root
	for i in range(segs):
		var at: Vector3 = path[i]; var next: Vector3 = path[i + 1]
		var node := joint(parent, "Segment%d" % i, at)
		var s := Sculpt.new(); var sp := s.add_painter(slag); var sj := s.add_painter(joint_skin)
		var dir := (next - at).normalized(); var side := dir.cross(Vector3.UP).normalized()
		var w := 0.12 * (1.0 - i * 0.025)
		# A flat plate over the top, the soft joint underneath, lava between segments.
		s.tube([at, next], [w * 0.75, w * 0.75], sj, {"sides": 10, "per": 2, "flat": 1.6, "side": side})
		s.tube([at + Vector3(0, 0.05, 0) - dir * 0.01, at.lerp(next, 0.5) + Vector3(0, 0.07, 0), next + Vector3(0, 0.05, 0) - dir * 0.03], [w * 0.9, w * 1.05, w * 0.95], sp, {"sides": 10, "per": 2, "flat": 2.6, "side": side, "lump": 0.08})
		s.tube([at - Vector3(0, 0.035, 0), next - Vector3(0, 0.035, 0)], [w * 0.7, w * 0.7], sp, {"sides": 8, "per": 1, "flat": 2.0, "side": side})
		part(node, "Segment", s)
		var gs := Sculpt.new(); var gw := gs.add_painter(func (p, n, v, w2): return Color.WHITE)
		gs.tube([at + side * w * 2.0 + Vector3(0, 0.04, 0), at + Vector3(0, 0.085, 0), at - side * w * 2.0 + Vector3(0, 0.04, 0)], [0.012, 0.016, 0.012], gw, {"sides": 4, "per": 2, "cap_rings": 1})
		part(node, "Lava", gs, glow).material_override = glow
		for sd: float in [-1.0, 1.0]:
			var out := side * sd
			var reach := 0.42 if i < segs - 1 else 0.7
			var leg := crawler_leg(node, "Leg%d" % hips.size(), at.lerp(next, 0.5) + out * w * 1.4, out + (dir * 0.25 if i < segs - 1 else dir * 1.6), reach, 0.1, 0.03)
			hips.append(leg[0]); knees.append(leg[1])
		tails.append(node); parent = node
	# The head: a flat plate with long antennae, and the venom claws curled round the mouth.
	var head := joint(root, "Head", Vector3(0, 0.2, -0.58))
	var hs := Sculpt.new(); var hp := hs.add_painter(slag); var hj := hs.add_painter(joint_skin)
	hs.blob(Vector3(0, 0.22, -0.66), Vector3(0.24, 0.08, 0.15), hp, {"lat": 6, "lon": 10, "lump": 0.1})
	for side: float in [-1.0, 1.0]:
		antenna(hs, hj, Vector3(0.05 * side, 0.24, -0.79), Vector3(0.5 * side, 0.4, -1.0), 0.55, 0.012, 0.2)
	var core := _eyes(head, [Vector3(-0.08, 0.27, -0.76), Vector3(0.08, 0.27, -0.76)], 0.018)
	part(head, "Head", hs)
	var pincers: Array = []
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.09 * side, 0.18, -0.72)
		var hinge := joint(head, "VenomClaw", at)
		var cs := Sculpt.new(); var cp := cs.add_painter(slag); var tip := cs.add_painter(func (p, n, v, w): return Color("#1a0d08").lerp(Color("#ff7a2a"), smoothstep(0.6, 1.0, v)))
		cs.tube([at, at + Vector3(0.06 * side, 0.0, -0.08), at + Vector3(0.02 * side, -0.01, -0.17), at + Vector3(-0.06 * side, -0.02, -0.2)], [0.032, 0.028, 0.018, 0.003], tip, {"sides": 7, "per": 3, "cap1": false})
		part(hinge, "Claw", cs)
		pincers.append(hinge)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.6)
	return _rig(node, head, hips, knees, null, tails, pincers)


# ------------------------------------------------------------------ D: horseshoe crab

## D: a giant horseshoe crab (Limulus), armoured in slag. Built from the real animal: a broad
## domed horseshoe-shaped head shield (the prosoma) with a ridge down the middle and a ridge on
## each side carrying a big compound eye, small median eyes at the front of the middle ridge,
## spines at its back corners; a hinged, roughly six-sided abdomen (the opisthosoma) edged with
## six movable spines a side; a long spike of a tail (the telson) for steering; and under the
## shell, five pairs of walking legs, the last pair the leaf-tipped "pusher" legs.
func _horseshoe() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(slag); var bj := body.add_painter(joint_skin)
	var lava := Sculpt.new(); var lw := lava.add_painter(func (p, n, v, w): return Color.WHITE)
	var st := Sculpt.new(); var stp := st.add_painter(steam)
	var y0 := 0.2
	# The height of the shield's top surface at (x, z).
	var surf := func (x: float, z: float) -> float:
		var d1 := 0.09 * sqrt(maxf(1.0 - pow(x / 0.6, 2.0) - pow((z + 0.1) / 0.55, 2.0), 0.0))
		var d2 := 0.22 * sqrt(maxf(1.0 - pow(x / 0.44, 2.0) - pow((z + 0.08) / 0.47, 2.0), 0.0))
		return y0 + 0.02 + maxf(d1, d2)
	# The horseshoe outline of the head shield: round at the front, its back corners drawn out
	# into spines.
	var outline: Array = []; var orr: Array = []
	for k in range(19):
		var a := lerpf(-1.95, 1.95, k / 18.0)
		outline.append(Vector3(sin(a) * 0.62, y0 + 0.02, -0.08 - cos(a) * 0.56)); orr.append(0.035)
	body.tube(outline, orr, bp, {"sides": 6, "per": 2, "flat": 0.5, "side": Vector3.UP})
	# The dome, flattening out to the rim, and the underside.
	# A wide, thin flared brim and a lower dome rising in the middle of it.
	body.blob(Vector3(0, y0 + 0.02, -0.1), Vector3(0.6, 0.09, 0.55), bp, {"lat": 12, "lon": 24, "lump": 0.03})
	body.blob(Vector3(0, y0 + 0.02, -0.08), Vector3(0.44, 0.22, 0.47), bp, {"lat": 16, "lon": 24, "lump": 0.04})
	body.blob(Vector3(0, y0 - 0.02, -0.1), Vector3(0.5, 0.08, 0.48), bj, {"lat": 8, "lon": 12})
	for side: float in [-1.0, 1.0]:
		var corner: Vector3 = outline[0 if side < 0 else 18]
		body.crystal(corner, Vector3(0.25 * side, -0.05, 1.0), 0.22, 0.04, bp, 5)
		# The side ridge, curving back over the dome, with the big compound eye on it.
		var ridge: Array = []; var rr: Array = []
		for j in range(7):
			var t := j / 6.0
			var x := lerpf(0.26, 0.33, sin(t * PI * 0.8)) * side
			var z := lerpf(-0.4, 0.14, t)
			var yy: float = surf.call(x, z)
			ridge.append(Vector3(x, yy + 0.012, z)); rr.append(0.028)
		body.tube(ridge, rr, bp, {"sides": 6, "per": 2, "lump": 0.2})
		for j in range(1, 6): body.crystal(ridge[j], Vector3(0.2 * side, 1, 0.4), 0.04, 0.014, bp, 4)
	# The middle ridge with a row of short spines.
	var mid: Array = []; var mr: Array = []
	for j in range(7):
		var z := lerpf(-0.55, 0.14, j / 6.0)
		mid.append(Vector3(0, float(surf.call(0.0, z)) + 0.012, z)); mr.append(0.032)
	body.tube(mid, mr, bp, {"sides": 6, "per": 2, "lump": 0.2})
	for j in range(1, 6): body.crystal(mid[j], Vector3(0, 1, 0.5), 0.07, 0.02, bp, 4)
	# Lava cracking across the dome between the ridges, and vents steaming.
	for side: float in [-1.0, 1.0]:
		# Irregular branching cracks, wandering out from the middle ridge.
		for j in range(3):
			var pts: Array = []; var pr: Array = []
			var x := 0.04 * side; var zz := -0.36 + j * 0.17 + 0.03 * side
			var heading := (0.4 + 0.5 * absf(Sculpt.noise(Vector3(j, side, 1) * 2.3))) * side
			for i in range(6):
				pts.append(Vector3(x, float(surf.call(x, zz)) + 0.004, zz)); pr.append(0.009 * (1.0 - i / 7.0))
				heading += Sculpt.noise(Vector3(i * 1.3, j * 2.1, side)) * 1.1
				x += sin(heading) * 0.04 * absf(side); zz += cos(heading) * 0.03 * (1.0 if j % 2 == 0 else -1.0)
				x = clampf(x, -0.24, 0.24)
			lava.tube(pts, pr, lw, {"sides": 4, "per": 1, "cap_rings": 1})
			var b0: Vector3 = pts[2]
			lava.tube([b0, b0 + Vector3(0.03 * side, 0.01, 0.05), b0 + Vector3(0.05 * side, 0.004, 0.08)], [0.007, 0.005, 0.002], lw, {"sides": 4, "per": 1, "cap_rings": 1})
		steam_puffs(st, stp, Vector3(0.42 * side, float(surf.call(0.42, -0.02)), -0.02), 0.04)
	part(root, "Shell", body)

	# The abdomen, on its hinge so it flexes; lava glowing in the hinge.
	var abd := joint(root, "Abdomen", Vector3(0, y0 + 0.05, 0.36))
	var as_ := Sculpt.new(); var ap := as_.add_painter(slag); var aj := as_.add_painter(joint_skin)
	as_.blob(Vector3(0, y0 + 0.04, 0.6), Vector3(0.36, 0.14, 0.28), ap, {"lat": 10, "lon": 14, "lump": 0.05})
	as_.blob(Vector3(0, y0 - 0.02, 0.58), Vector3(0.3, 0.06, 0.22), aj, {"lat": 6, "lon": 10})
	var hexo: Array = [Vector3(-0.4, y0 + 0.03, 0.4), Vector3(-0.36, y0 + 0.03, 0.72), Vector3(-0.1, y0 + 0.03, 0.86), Vector3(0.1, y0 + 0.03, 0.86), Vector3(0.36, y0 + 0.03, 0.72), Vector3(0.4, y0 + 0.03, 0.4)]
	var hr: Array = []
	for k in range(hexo.size()): hr.append(0.032)
	as_.tube(hexo, hr, ap, {"sides": 6, "per": 3, "flat": 0.5, "side": Vector3.UP})
	as_.tube([Vector3(0, y0 + 0.17, 0.4), Vector3(0, y0 + 0.18, 0.6), Vector3(0, y0 + 0.11, 0.8)], [0.03, 0.028, 0.02], ap, {"sides": 6, "per": 2, "lump": 0.2})
	for j in range(3): as_.crystal(Vector3(0, y0 + 0.18 - j * 0.03, 0.45 + j * 0.13), Vector3(0, 1, 0.4), 0.06, 0.018, ap, 4)
	for side: float in [-1.0, 1.0]:
		# Six movable spines along each edge.
		for j in range(6):
			var t := j / 5.0
			var at := Vector3(side * lerpf(0.4, 0.3, t), y0 + 0.03, lerpf(0.42, 0.78, t))
			as_.crystal(at, Vector3(side, -0.05, 0.25 + t * 0.4), 0.1 - t * 0.02, 0.016, ap, 4)
	part(abd, "Abdomen", as_)
	var hinge := Sculpt.new(); var hw := hinge.add_painter(func (p, n, v, w): return Color.WHITE)
	var hp: Array = []; var hrr: Array = []
	for k in range(9):
		var a := lerpf(-1.4, 1.4, k / 8.0)
		hp.append(Vector3(sin(a) * 0.37, y0 + 0.03 + cos(a) * 0.125, 0.355)); hrr.append(0.016)
	hinge.tube(hp, hrr, hw, {"sides": 4, "per": 2, "cap_rings": 1})
	part(abd, "Hinge", hinge, glow).material_override = glow
	part(root, "Steam", st)
	part(root, "Lava", lava, glow).material_override = glow

	# The tail: a long three-sided spike in two segments, hot at the tip.
	var tails: Array = []; var tparent: Node3D = abd; var tat := Vector3(0, y0 + 0.04, 0.86)
	for k in range(2):
		var node := joint(tparent, "Tail" if k == 0 else "TailSegment", tat)
		var ts := Sculpt.new(); var tp := ts.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return slag(p, n, v, w).lerp(Color("#ff7a2a"), smoothstep(0.7, 1.0, v) * float(k)))
		var nxt := tat + Vector3(0, -0.01, 0.42)
		ts.tube([tat, nxt], [0.04 - k * 0.018, 0.022 - k * 0.02], tp, {"sides": 3, "per": 2, "cap1": k == 1, "lump": 0.05})
		part(node, "Telson", ts)
		tails.append(node); tparent = node; tat = nxt

	# The head: the front of the shield carries the compound eyes and the small median eyes.
	var head := joint(root, "Head", Vector3(0, y0 + 0.1, -0.45))
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		eyes.append(Vector3(0.3 * side, float(surf.call(0.3, -0.33)) + 0.03, -0.33))
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for at in eyes: es.blob(at, Vector3(0.035, 0.028, 0.06), ew, {"lat": 5, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var ms := Sculpt.new(); var mw := ms.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]: ms.blob(Vector3(0.025 * side, float(surf.call(0.0, -0.42)) + 0.03, -0.42), Vector3.ONE * 0.016, mw, {"lat": 4, "lon": 6})
	part(head, "MedianEyes", ms, glow).material_override = glow

	# Legs under the shield: four pairs of walking legs with pincer tips, then the pushers.
	var hips: Array = []; var knees: Array = []
	for i in range(5):
		var z := lerpf(-0.35, 0.18, i / 4.0)
		for side: float in [-1.0, 1.0]:
			var leg := crawler_leg(root, "Leg%d" % hips.size(), Vector3(0.12 * side, y0 - 0.02, z), Vector3(side, 0, -0.1 + i * 0.25), 0.62 if i == 4 else 0.56, 0.1, 0.032)
			hips.append(leg[0]); knees.append(leg[1])
			if i == 4:
				var ls := Sculpt.new(); var lp := ls.add_painter(slag)
				var tip := Vector3(0.12 * side, y0 - 0.02, z) + Vector3(side, 0, 0.9).normalized() * 0.62 * 0.95 + Vector3(0, -y0 + 0.03, 0)
				for f in range(4):
					var a := TAU * f / 4.0
					ls.crystal(tip + Vector3(0, 0.02, 0), Vector3(cos(a), 0.4, sin(a)), 0.06, 0.016, lp, 3)
				part(leg[1], "Pusher", ls)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.8)
	return _rig(node, head, hips, knees, null, tails)
