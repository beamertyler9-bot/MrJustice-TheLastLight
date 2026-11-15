extends "res://tools/creature_kit.gd"
## The Choco-Bar Croc of S'morewood, take two: less cartoon, more crocodile. A long, low
## chocolate crocodile still half inside its torn blue wrapper: a flat tapering snout with
## interlocking white-chocolate teeth, hooded amber eyes with slit pupils, rows of square
## chocolate-bar scutes down the back and a long segmented tail, on short sprawling legs.

const CHOC := Color("#2c160d")
const CHOC_MID := Color("#4a2818")
const CHOC_HI := Color("#6e4027")
const WRAP := Color("#18306e")
const WRAP_HI := Color("#2c4f9e")
const GOLD := Color("#d9a830")
const FOIL := Color("#c3c6cf")
const TOOTH := Color("#f1e6cc")
const MAW := Color("#2a0d0a")
const BELLY := Color("#d9c39c")
const GUM := Color("#c98c7c")
const PALATE := Color("#d98a86")
const TONGUE := Color("#b0563a")
const TAIL_SEGMENTS := 5
const TAIL_START := Vector3(0, 0.3, 0.72)
const TAIL_STEP := Vector3(0, -0.03, 0.27)

var shiny: StandardMaterial3D
var foil_mat: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	material.roughness = 0.6
	material.uv1_scale = Vector3(4, 4, 4)
	shiny = StandardMaterial3D.new()
	shiny.vertex_color_use_as_albedo = true
	shiny.vertex_color_is_srgb = true
	shiny.roughness = 0.45
	shiny.metallic_specular = 0.5
	foil_mat = StandardMaterial3D.new()
	foil_mat.vertex_color_use_as_albedo = true
	foil_mat.vertex_color_is_srgb = true
	foil_mat.roughness = 0.2
	foil_mat.metallic = 0.85
	foil_mat.metallic_specular = 0.9
	glow.albedo_color = Color("#6b3c12"); glow.emission = Color("#a8641a")
	glow.emission_energy_multiplier = 0.35


static func choc(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := CHOC.lerp(CHOC_MID, clampf(0.35 + n.y * 0.45 + Sculpt.fbm(p * 7.0) * 0.4, 0.0, 1.0))
	# Little scales: a fine dark grid of grooves over the chocolate.
	var cell := absf(fposmod(p.x * 28.0 + p.y * 9.0, 1.0) - 0.5) + absf(fposmod(p.z * 22.0 + p.y * 7.0, 1.0) - 0.5)
	c = c.darkened(smoothstep(0.62, 0.86, cell) * 0.25)
	# A pale white-chocolate belly underneath.
	return c.lerp(BELLY.darkened(clampf(-n.y, 0.0, 1.0) * 0.2), smoothstep(-0.25, -0.65, n.y))


static func scute(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return CHOC_MID.lerp(CHOC_HI, clampf(n.y * 0.7 + 0.15, 0.0, 1.0)).darkened(clampf(-n.y, 0.0, 1.0) * 0.4)


static func wrapper_paint(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := WRAP.lerp(WRAP_HI, clampf(n.y * 0.5 + absf(Sculpt.noise(p * 13.0)) * 0.6, 0.0, 1.0))
	c = c.lerp(GOLD, smoothstep(0.07, 0.045, absf(p.z - 0.34)) * 0.9)
	c = c.lerp(Color("#f2ead8"), smoothstep(0.03, 0.015, absf(p.z - 0.34)) * 0.9)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.45)


## Two rows of square chocolate-bar scutes along the back between `a` and `b`, standing
## `height` above that line, `spread` apart.
func scutes(s: Sculpt, painter: int, a: Vector3, b: Vector3, count: int, spread: float, size: float) -> void:
	for k in range(count):
		var at := a.lerp(b, (k + 0.5) / count)
		var shrink := 1.0 - 0.35 * float(k) / maxf(count, 1)
		for side in [-1.0, 1.0]:
			slab(s, painter, at + Vector3(spread * side * shrink, 0, 0), Vector3(size, size * 0.5, size * 1.05) * shrink, Basis(Vector3.BACK, -0.12 * side), 0.35, 0.04)


## The tail's crest: upright triangular plates along the top, in two rows near the body
## that merge into one down the tail, like a gator's.
func crests(s: Sculpt, painter: int, a: Vector3, b: Vector3, r0: float, r1: float, double: bool) -> void:
	for k in range(3):
		var t := (k + 0.5) / 3.0
		var r := lerpf(r0, r1, t)
		var at := a.lerp(b, t) + Vector3(0, r * 0.82, 0)
		var h := maxf(0.035, r * 0.55)
		for x: float in ([-r * 0.38, r * 0.38] if double else [0.0]):
			var base := at + Vector3(x, 0, 0)
			s.tube([base, base + Vector3(x * 0.15, h * 0.6, 0.008), base + Vector3(x * 0.2, h, 0.02)], [h * 0.45, h * 0.3, 0.003], painter, {"sides": 6, "per": 2, "flat": 0.35, "side": Vector3.RIGHT, "cap0": false, "cap_rings": 1})


## A gator tooth: a cream cone, thick at the root and curving slightly back.
func tooth(s: Sculpt, painter: int, root_at: Vector3, dir: Vector3, length: float, width: float) -> void:
	var d := dir.normalized()
	s.tube([root_at - d * width * 0.5, root_at + d * length * 0.5 + Vector3(0, 0, width * 0.15), root_at + d * length + Vector3(0, 0, width * 0.35)], [width, width * 0.72, 0.003], painter, {"sides": 5, "per": 2, "cap0": false, "cap_rings": 1})


## Conical teeth along a jaw from `a` to `b`, pointing `dir`; every fourth one is a fang.
func teeth(s: Sculpt, painter: int, a: Vector3, b: Vector3, count: int, dir: Vector3, length: float, width: float) -> void:
	for k in range(count):
		var at := a.lerp(b, (k + 0.5) / count)
		var l := length * (1.6 if k % 4 == 2 else 0.85 + 0.2 * absf(sin(k * 1.7)))
		s.tube([at, at + dir.normalized() * l * 0.55, at + dir.normalized() * l], [width, width * 0.65, 0.002], painter, {"sides": 6, "per": 2, "cap0": false, "cap_rings": 1})


func build(_variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ChocoBarCroc"
	# ---- the body: chocolate shoulders and hips, the middle still in its torn wrapper.
	var bs := Sculpt.new(); var cp := bs.add_painter(choc); var sp := bs.add_painter(scute)
	var belly := bs.add_painter(func (p, n, v, w): return Color("#8a5a3a").lerp(CHOC_MID, clampf(n.y + 0.3, 0.0, 1.0)))
	bs.tube([Vector3(0, 0.33, -0.28), Vector3(0, 0.34, 0.0), Vector3(0, 0.33, 0.35), Vector3(0, 0.31, 0.66)], [0.17, 0.2, 0.2, 0.15], cp, {"sides": 16, "per": 3, "flat": 1.55, "side": Vector3.RIGHT, "square": 0.7, "cap_len": 0.4, "lump": 0.06})
	bs.blob(Vector3(0, 0.2, 0.15), Vector3(0.24, 0.07, 0.42), belly, {"lat": 5, "lon": 12})
	scutes(bs, sp, Vector3(0, 0.5, -0.3), Vector3(0, 0.51, -0.2), 1, 0.08, 0.1)
	part(root, "Body", bs, shiny)
	# ---- the wrapper: crinkled blue tinfoil, burst open at both ends and torn through at
	# the legs, with the silver inside showing at every rip.
	var ws := Sculpt.new(); var wp := ws.add_painter(wrapper_paint)
	var fp := ws.add_painter(func (p, n, v, w): return FOIL.lightened(absf(Sculpt.noise(p * 25.0)) * 0.3).darkened(clampf(-n.y, 0.0, 1.0) * 0.3))
	ws.tube([Vector3(0, 0.33, -0.16), Vector3(0, 0.34, 0.06), Vector3(0, 0.34, 0.3), Vector3(0, 0.33, 0.52), Vector3(0, 0.315, 0.66)], [0.21, 0.228, 0.232, 0.222, 0.2], wp, {"sides": 28, "per": 4, "flat": 1.5, "side": Vector3.RIGHT, "square": 0.6, "cap0": false, "cap1": false, "lump": 0.32, "facet": true})
	# Ragged flaps peeling outward at both ends where the croc has burst through.
	for end: Array in [[-0.16, -1.0, 0.33, 0.21], [0.66, 1.0, 0.315, 0.2]]:
		var end_z: float = end[0]; var way: float = end[1]; var mid_y: float = end[2]; var rad: float = end[3]
		for k in range(12):
			var ang := TAU * k / 12.0 + 0.1 * way
			var dir := Vector3(cos(ang) * 1.5, sin(ang), 0).normalized()
			var base := Vector3(dir.x * rad * 1.5, mid_y + dir.y * rad, end_z)
			var peel := (Vector3(0, 0, way) * 0.55 + dir).normalized()
			var l := (0.09 + 0.12 * absf(sin(k * 2.3 + way))) * (0.55 if dir.y > 0.4 else 1.0)
			ws.tube([base, base + peel * l * 0.55, base + peel * l + dir * 0.03 * (1 if k % 2 else -1) - Vector3(0, 0, way) * 0.04], [0.085, 0.07, 0.025], wp if k % 3 else fp, {"sides": 6, "per": 2, "cap_rings": 1, "flat": 0.12, "side": dir.cross(Vector3(0, 0, 1)), "cap0": false, "facet": true, "lump": 0.4})
	# Torn holes where the legs punch out through the sides.
	for leg: Vector3 in [Vector3(-0.3, 0.3, -0.12), Vector3(0.3, 0.3, -0.12), Vector3(-0.3, 0.29, 0.52), Vector3(0.3, 0.29, 0.52)]:
		var side := signf(leg.x)
		for k in range(5):
			var ang := TAU * k / 5.0 + 0.3
			var ring := Vector3(0, cos(ang), sin(ang))
			var base: Vector3 = leg + ring * 0.08
			var peel := (Vector3(side, 0, 0) * 0.8 + ring * 0.6).normalized()
			var l := 0.05 + 0.05 * absf(sin(k * 1.9 + side))
			ws.tube([base, base + peel * l * 0.6, base + peel * l], [0.055, 0.045, 0.015], wp if k % 2 else fp, {"sides": 6, "per": 2, "cap_rings": 1, "flat": 0.12, "side": ring.cross(Vector3(side, 0, 0)).normalized(), "cap0": false, "facet": true, "lump": 0.4})
	part(root, "Wrapper", ws, foil_mat)
	# ---- the tail: nested segments that swing, scuted and tapering.
	var tail_nodes: Array = []
	var parent: Node3D = root; var at := TAIL_START
	for k in range(TAIL_SEGMENTS):
		var node := joint(parent, "Tail%d" % k, at)
		var r0: float = lerpf(0.15, 0.025, float(k) / TAIL_SEGMENTS)
		var r1: float = lerpf(0.15, 0.025, float(k + 1) / TAIL_SEGMENTS)
		var ts := Sculpt.new(); var tp := ts.add_painter(choc); var tsp := ts.add_painter(scute)
		var next := at + TAIL_STEP
		ts.tube([at - TAIL_STEP * 0.18, at.lerp(next, 0.5), next + TAIL_STEP * 0.12], [r0 * 1.02, (r0 + r1) * 0.5, r1], tp, {"sides": 12, "per": 2, "flat": 1.0 + 0.4 * (1.0 - float(k) / TAIL_SEGMENTS), "side": Vector3.RIGHT, "lump": 0.05})
		if k < TAIL_SEGMENTS - 1:
			crests(ts, tsp, at, next, r0, r1, k < 2)
		part(node, "Segment", ts, shiny)
		tail_nodes.append(node)
		parent = node; at = next
	# ---- the head, after an alligator: a heavy skull with raised eye bosses, a broad, flat,
	# rounded U-shaped snout with a nose bump, and a ragged grin of cream teeth.
	var head := joint(root, "Head", Vector3(0, 0.36, -0.3))
	var hs := Sculpt.new(); var hc := hs.add_painter(choc); var hsc := hs.add_painter(scute)
	var ht := hs.add_painter(func (p, n, v, w): return TOOTH.lerp(Color("#c9ad7c"), (1.0 - v) * 0.8))
	var maw := hs.add_painter(func (p, n, v, w): return MAW)
	var gum := hs.add_painter(func (p, n, v, w): return GUM.darkened(clampf(-n.y, 0.0, 1.0) * 0.2))
	var palate := hs.add_painter(func (p, n, v, w): return PALATE.darkened(clampf(n.y, 0.0, 1.0) * 0.15))
	hs.blob(Vector3(0, 0.43, -0.29), Vector3(0.2, 0.12, 0.17), hc, {"lat": 8, "lon": 14, "lump": 0.05})
	# Upper jaw: broad and flat, wide at the back and rounded at the tip; its lip waves a little.
	var snout := [Vector3(0, 0.39, -0.3), Vector3(0, 0.375, -0.5), Vector3(0, 0.36, -0.72), Vector3(0, 0.352, -0.88), Vector3(0, 0.348, -0.98)]
	var widths := [0.21, 0.185, 0.15, 0.145, 0.13]
	hs.tube(snout, [0.085, 0.074, 0.064, 0.064, 0.06], hc, {"sides": 18, "per": 3, "flat": 2.5, "side": Vector3.RIGHT, "square": 0.25, "cap_len": 0.75, "lump": 0.04})
	hs.blob(Vector3(0, 0.325, -0.62), Vector3(0.13, 0.014, 0.3), palate, {"lat": 4, "lon": 12})
	# Nose bump with two nostrils.
	hs.blob(Vector3(0, 0.395, -0.97), Vector3(0.065, 0.032, 0.055), hc, {"lat": 5, "lon": 9})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.028 * side, 0.425, -0.975), Vector3(0.013, 0.006, 0.016), maw, {"lat": 3, "lon": 6})
	# The gum line along the edge of the upper jaw.
	var lip: Array = []; var lip_r: Array = []
	for k in range(snout.size()):
		var c: Vector3 = snout[k]
		lip.append(Vector3(0, c.y - 0.055 - 0.008 * sin(k * 1.6), c.z)); lip_r.append(0.018)
	hs.tube(lip, lip_r, gum, {"sides": 8, "per": 3, "flat": 10.5, "side": Vector3.RIGHT, "cap_len": 0.5})
	# Eye bosses on top of the skull, with a bony brow over each and an ear slit behind.
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.1 * side, 0.52, -0.37), Vector3(0.065, 0.055, 0.07), hc, {"lat": 6, "lon": 9})
		hs.tube([Vector3(0.06 * side, 0.575, -0.44), Vector3(0.12 * side, 0.58, -0.4), Vector3(0.155 * side, 0.555, -0.34)], [0.017, 0.02, 0.011], hsc, {"sides": 7, "per": 3, "flat": 0.6, "side": Vector3.UP})
		hs.blob(Vector3(0.165 * side, 0.49, -0.25), Vector3(0.012, 0.02, 0.05), maw, {"lat": 3, "lon": 6})
	# Nuchal scutes on the back of the head and neck.
	scutes(hs, hsc, Vector3(0, 0.55, -0.26), Vector3(0, 0.53, -0.12), 2, 0.055, 0.075)
	# Upper teeth: uneven cream cones all along the jaw edge, some big, showing even when shut.
	var sizes := [0.55, 0.7, 1.15, 0.65, 0.55, 0.8, 1.3, 0.7, 0.6, 0.75, 1.0, 0.6, 0.85]
	for side in [-1.0, 1.0]:
		for k in range(sizes.size()):
			var t := (k + 0.5) / sizes.size()
			var z := lerpf(-0.36, -0.93, t)
			var idx := clampi(int(t * (widths.size() - 1)), 0, widths.size() - 2)
			var hw: float = lerpf(widths[idx], widths[idx + 1], t * (widths.size() - 1) - idx) - 0.012
			var sz: float = sizes[k]
			tooth(hs, ht, Vector3(hw * side, 0.3 - 0.008 * sin(t * 6.4), z), Vector3(0.12 * side, -1, 0.0), 0.065 * sz, 0.017 * sqrt(sz))
	# Front teeth round the tip of the snout, the two outer ones big.
	for k in range(6):
		var ang := lerpf(-1.15, 1.15, (k + 0.5) / 6.0)
		var tip := Vector3(sin(ang) * 0.115, 0.3, -0.955 - cos(ang) * 0.055)
		var tsz := 1.4 if absf(ang) > 0.6 else 0.8
		tooth(hs, ht, tip, Vector3(sin(ang) * 0.15, -1, -0.1), 0.065 * tsz, 0.018 * sqrt(tsz))
	# Eyes: dark amber almonds with slit pupils, set in the side of each boss under the brow.
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	var ps := Sculpt.new(); var pp := ps.add_painter(func (p, n, v, w): return Color("#0d0402"))
	for side in [-1.0, 1.0]:
		var look := Vector3(0.75 * side, 0.15, -0.65).normalized()
		var eye := Vector3(0.128 * side, 0.535, -0.405)
		es.blob(eye, Vector3(0.03, 0.017, 0.026), ew, {"lat": 5, "lon": 9, "basis": Basis.looking_at(look, Vector3.UP)})
		ps.blob(eye + look * 0.021, Vector3(0.005, 0.015, 0.004), pp, {"lat": 4, "lon": 6, "basis": Basis.looking_at(look, Vector3.UP)})
		hs.blob(eye + Vector3(-0.004 * side, 0.017, 0.004), Vector3(0.04, 0.015, 0.038), hc, {"lat": 5, "lon": 8, "basis": Basis.looking_at(look, Vector3.UP)})
	part(head, "Pupils", ps, shiny)
	part(head, "Snout", hs, shiny)
	var core := part(head, "Eyes", es, glow); core.material_override = glow
	# ---- the lower jaw: narrower than the upper, deep and muscled at the back, pale beneath,
	# pink inside, with its own row of teeth.
	var jaw := joint(head, "Jaw", Vector3(0, 0.3, -0.22))
	var js := Sculpt.new(); var jc := js.add_painter(choc)
	var jt := js.add_painter(func (p, n, v, w): return TOOTH.lerp(Color("#c9ad7c"), (1.0 - v) * 0.8))
	var jm := js.add_painter(func (p, n, v, w): return PALATE.lightened(0.05).darkened(clampf(-n.y, 0.0, 1.0) * 0.3))
	var jtongue := js.add_painter(func (p, n, v, w): return Color("#e3a59a").lightened(clampf(n.y, 0.0, 1.0) * 0.1))
	js.tube([Vector3(0, 0.255, -0.22), Vector3(0, 0.245, -0.5), Vector3(0, 0.25, -0.78), Vector3(0, 0.255, -0.93)], [0.08, 0.062, 0.052, 0.048], jc, {"sides": 16, "per": 3, "flat": 2.45, "side": Vector3.RIGHT, "square": 0.25, "cap_len": 0.6})
	for side in [-1.0, 1.0]:
		js.blob(Vector3(0.15 * side, 0.285, -0.21), Vector3(0.07, 0.075, 0.1), jc, {"lat": 6, "lon": 9})
	js.blob(Vector3(0, 0.295, -0.58), Vector3(0.13, 0.016, 0.32), jm, {"lat": 4, "lon": 12})
	js.blob(Vector3(0, 0.305, -0.48), Vector3(0.08, 0.02, 0.19), jtongue, {"lat": 4, "lon": 9})
	var jsizes := [0.6, 0.8, 0.6, 1.1, 0.7, 0.6, 0.9, 0.6, 1.2, 0.7]
	for side in [-1.0, 1.0]:
		for k in range(jsizes.size()):
			var t := (k + 0.5) / jsizes.size()
			var jhw := lerpf(0.17, 0.1, t)
			var jsz: float = jsizes[k]
			tooth(js, jt, Vector3(jhw * side, 0.285, lerpf(-0.38, -0.92, t)), Vector3(0.1 * side, 1, 0), 0.06 * jsz, 0.016 * sqrt(jsz))
	part(jaw, "LowerJaw", js, shiny)
	# ---- short sprawling legs, elbows out, with clawed feet.
	var hips: Array = []; var knees: Array = []
	var claw := func (p, n, v, w): return Color("#1a0e08").lerp(TOOTH, v * 0.5)
	for spot: Vector3 in [Vector3(-0.2, 0.3, -0.12), Vector3(0.2, 0.3, -0.12), Vector3(-0.19, 0.29, 0.52), Vector3(0.19, 0.29, 0.52)]:
		var side := signf(spot.x)
		var front := spot.z < 0.2
		var label := ("Foreleg%d" if front else "Hindleg%d") % hips.size()
		var hip := joint(root, label, spot)
		var elbow := spot + Vector3(0.3 * side, -0.01, -0.04 if front else 0.06)
		var ls := Sculpt.new(); var lp := ls.add_painter(choc); var lsc := ls.add_painter(scute)
		ls.tube([spot, spot.lerp(elbow, 0.5) + Vector3(0, 0.03, 0), elbow], [0.095, 0.085, 0.065], lp, {"sides": 10, "per": 3, "lump": 0.06})
		ls.blob(spot.lerp(elbow, 0.5) + Vector3(0, 0.06, 0), Vector3(0.05, 0.02, 0.06), lsc, {"lat": 4, "lon": 7})
		part(hip, "UpperLeg", ls, shiny)
		var knee := joint(hip, "Knee", elbow)
		var foot := Vector3(elbow.x + 0.06 * side, 0.035, elbow.z + (-0.08 if front else 0.0))
		var ss := Sculpt.new(); var sp2 := ss.add_painter(choc); var sc := ss.add_painter(claw)
		ss.tube([elbow, elbow.lerp(foot, 0.5), foot + Vector3(0, 0.03, 0)], [0.068, 0.06, 0.05], sp2, {"sides": 10, "per": 3, "lump": 0.06})
		ss.blob(foot + Vector3(0, 0.0, -0.02), Vector3(0.065, 0.03, 0.07), sp2, {"lat": 5, "lon": 8})
		for c in range(5 if front else 4):
			var spread := (c - (2.0 if front else 1.5)) * 0.42
			var d := Vector3(sin(spread) + side * 0.2, 0, -cos(spread)).normalized()
			var toe_root := foot + Vector3(0, 0.0, -0.02) + d * 0.04
			var toe_tip := toe_root + d * (0.07 if c != 0 else 0.05) + Vector3(0, -0.012, 0)
			ss.tube([toe_root, toe_root.lerp(toe_tip, 0.5) + Vector3(0, 0.006, 0), toe_tip], [0.02, 0.016, 0.012], sp2, {"sides": 6, "per": 2, "cap_rings": 1})
			ss.tube([toe_tip, toe_tip + d * 0.025 + Vector3(0, -0.008, 0), toe_tip + d * 0.04 + Vector3(0, -0.025, 0)], [0.01, 0.007, 0.002], sc, {"sides": 5, "per": 2, "cap0": false, "cap_rings": 1})
		part(knee, "Foot", ss, shiny)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.15)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tail_nodes), "features": {&"jaw": node.get_path_to(jaw)}}
	node.set_meta("rig_bindings", rig)
	return node
