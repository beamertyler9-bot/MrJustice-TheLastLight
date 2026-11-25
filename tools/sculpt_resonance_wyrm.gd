extends "res://tools/sculpt_dune_maw.gd"
## The Resonance Wyrm of Prismere, sculpted by hand: a long serpent whose body is ribbed with
## mineral; the ribs ring like struck crystal, and a shiver runs down them before it sends a
## wave through the ground. Three designs, each built on a real long-bodied animal:
##   rattler  - the western diamondback rattlesnake: a broad triangular head with heat pits,
##              hooded brows, slit pupils and long hinged fangs; dark diamonds edged in pale
##              scales, a black-and-white banded "coon tail", and a rattle of stacked hollow
##              segments that buzz - here clear quartz - with keeled crystal scales down its back
##   oarfish  - the giant oarfish, the longest bony fish: a silver ribbon of a body, flattened
##              side to side, a red crest of long rays on the head, one red dorsal fin running
##              its whole length, and two long oar-tipped pelvic rays; here every fin ray is a
##              rod of rose crystal, like a row of tuning forks
##   lamprey  - the sea lamprey: an eel-like body with no jaws, just a round sucking disc set
##              with rings of teeth, seven gill pores in a row behind each eye, and two dorsal
##              fins; here the rings of its body are mineral ribs and the gill pores glow
## All three are made draconic the way a fantasy "wyrm" is drawn: a lindworm - a great serpent
## with one pair of clawed forelegs - with swept-back horns, a spined brow and jaw, a glow in
## the throat, and small torn, flightless wings it can no longer fly with; their hides are
## gravelly, stone-like scale.

var kindw := "rattler"
var wing_mat: StandardMaterial3D
var wrng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	material.albedo_texture = null
	material.vertex_color_is_srgb = true
	material.roughness = 0.5; material.metallic_specular = 0.7
	wing_mat = material.duplicate()
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_mat.roughness = 0.8


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ResonanceWyrm"
	kindw = variant
	wrng.seed = 9113
	match variant:
		"rattler": return _rattler()
		"oarfish": return _oarfish()
		"lamprey": return _lamprey()
	return null


# ------------------------------------------------------------------ shared

## The tail: `count` jointed segments trailing back from `start`, swaying gently, each from
## `r0` down towards `r1`. `skin` paints them; `extra` adds per-segment details
## (sculpt, segment start, segment end, radius, index).
func tail_chain(start: Vector3, count: int, step: float, r0: float, r1: float, skin: Callable, opts: Dictionary, extra: Callable) -> Array:
	var tails: Array = []
	var parent: Node3D = root
	var at := start
	for k in range(count):
		var dir := Vector3(0.3 * sin(k * 0.8 + 0.6), -0.005, 1.0).normalized()
		var next := at + dir * step
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var ra: float = lerpf(r0, r1, float(k) / count); var rb: float = lerpf(r0, r1, float(k + 1) / count)
		var ts := Sculpt.new(); var tp := ts.add_painter(skin)
		var o := opts.duplicate(); o["cap1"] = k == count - 1; o["cap_len"] = 0.6
		ts.tube([at - dir * step * 0.12, at.lerp(next, 0.5), next + dir * step * 0.08], [ra * 1.02, (ra + rb) * 0.5, rb], tp, o)
		extra.call(ts, at, next, (ra + rb) * 0.5, k)
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	return tails


func slit_pupils(parent: Node3D, eyes: Array, size: float, facing: Array) -> void:
	var ps := Sculpt.new(); var pp := ps.add_painter(func (_p, _n, _v, _w): return Color("#070506"))
	for k in range(eyes.size()):
		var e: Vector3 = eyes[k]; var f: Vector3 = facing[k]
		ps.blob(e + f * size * 0.92, Vector3(size * 0.16, size * 0.78, size * 0.16), pp, {"lat": 4, "lon": 6})
	part(parent, "Pupils", ps)


# ------------------------------------------------------------------ the dragon parts

## A point `t` of the way along a polyline.
static func along_line(pts: Array, t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


## A horn: a ridged, tapering tube that curls as it grows, from `base` along `dir`, bending
## round `axis` by `curl` radians in all.
func horn(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, r: float, axis: Vector3, curl: float) -> void:
	var pts: Array = [base]; var rr: Array = [r]
	var d := dir.normalized(); var at := base
	for k in range(1, 7):
		d = d.rotated(axis.normalized(), curl / 6.0)
		at += d * length / 6.0
		pts.append(at); rr.append(lerpf(r, 0.004, pow(k / 6.0, 1.3)))
	s.tube(pts, rr, painter, {"sides": 8, "per": 2, "bands": 5, "band": 0.12, "cap1": false})


## A web of skin stretched between two bones (polylines `a` and `b`), its free edge scalloped
## and torn.
func membrane(s: Sculpt, painter: int, a: Array, b: Array, sag: Vector3, torn: float) -> void:
	var rows := 7; var cols := 6
	var base := s._v.size()
	for i in range(rows + 1):
		for j in range(cols + 1):
			var u := j / float(cols)
			var tmax := 1.0 - 0.28 * sin(PI * u) - (wrng.randf() * torn if i == rows and j > 0 and j < cols else 0.0)
			var t := i / float(rows) * tmax
			var q := along_line(a, t).lerp(along_line(b, t), u) + sag * sin(PI * u) * (0.3 + t)
			s._v.append(q); s._along.append(t); s._ridge.append(u); s._painter.append(painter)
	for i in range(rows):
		for j in range(cols):
			if i >= rows - 2 and wrng.randf() < torn * 0.5: continue
			var k := base + i * (cols + 1) + j
			s._i.append_array(PackedInt32Array([k, k + cols + 1, k + 1, k + 1, k + cols + 1, k + cols + 2]))


## A small torn, flightless wing folded up off the back: arm bones to the wrist, three long
## finger bones fanning from it, and torn skin between them and back to the body.
func wing(s: Sculpt, bone_p: int, skin_p: int, root_at: Vector3, side: float, size: float, back: Vector3) -> void:
	var e := root_at + Vector3(side * 0.3, 0.3, 0.12) * size
	var w := e + Vector3(side * 0.12, 0.3, 0.28) * size
	var f1 := w + Vector3(side * 0.22, 0.38, 0.4) * size
	var f2 := w + Vector3(side * 0.3, 0.0, 0.7) * size
	var f3 := w + Vector3(side * 0.1, -0.38, 0.72) * size
	var f1m := w.lerp(f1, 0.5) + Vector3(side * 0.04, 0.0, -0.04) * size
	var f2m := w.lerp(f2, 0.5) + Vector3(side * 0.05, 0.06, 0.0) * size
	var f3m := w.lerp(f3, 0.5) + Vector3(side * 0.04, 0.04, 0.0) * size
	s.tube([root_at, root_at.lerp(e, 0.5) + Vector3(0, 0.03, 0) * size, e], [0.05 * size, 0.04 * size, 0.035 * size], bone_p, {"sides": 8, "per": 2})
	s.blob(e, Vector3.ONE * 0.042 * size, bone_p, {"lat": 4, "lon": 6})
	s.tube([e, w], [0.034 * size, 0.026 * size], bone_p, {"sides": 7, "per": 2})
	s.blob(w, Vector3.ONE * 0.034 * size, bone_p, {"lat": 4, "lon": 6})
	# The thumb claw at the wrist.
	s.tube([w, w + Vector3(side * 0.02, 0.07, -0.05) * size, w + Vector3(0, 0.1, -0.1) * size], [0.018 * size, 0.012 * size, 0.002], bone_p, {"sides": 5, "per": 2, "cap1": false})
	for f: Array in [[f1m, f1], [f2m, f2], [f3m, f3]]:
		s.tube([w, f[0], f[1]], [0.02 * size, 0.015 * size, 0.004], bone_p, {"sides": 6, "per": 3, "cap1": false})
	var sag := Vector3(-side * 0.06, -0.02, 0.0) * size
	membrane(s, skin_p, [w, f1m, f1], [w, f2m, f2], sag, 0.25)
	membrane(s, skin_p, [w, f2m, f2], [w, f3m, f3], sag, 0.3)
	membrane(s, skin_p, [root_at, e, w, f3m, f3], [root_at, root_at.lerp(back, 0.4), back, back, back], sag, 0.35)


## One pair of clawed forelegs: upper arm out to the elbow, forearm down to a broad foot with
## three hooked claws forward and one behind. Returns [hips, knees].
func forelegs(look: Callable, centre: Vector3, r: float, thick: float) -> Array:
	var hips: Array = []; var knees: Array = []
	var claw_p := func (_p, _n, v: float, _w) -> Color: return Color("#2a2420").lerp(Color("#d8d0c4"), v)
	for side in [-1.0, 1.0]:
		var h := centre + Vector3(side * r * 0.75, -r * 0.25, 0.0)
		var hip := joint(root, "Foreleg%s" % ("Left" if side < 0 else "Right"), h)
		var e := h + Vector3(side * 0.24, 0.02, 0.06)
		var foot := Vector3(h.x + side * 0.36, 0.04, h.z - 0.16)
		var us := Sculpt.new(); var up := us.add_painter(look)
		us.blob(h, Vector3.ONE * thick * 1.3, up, {"lat": 6, "lon": 8})
		us.tube([h, h.lerp(e, 0.5) + Vector3(0, 0.03, 0), e], [thick * 1.25, thick * 1.1, thick * 0.9], up, {"sides": 10, "per": 3, "lump": 0.04})
		part(hip, "UpperArm", us)
		var knee := joint(hip, "Elbow", e)
		var ls := Sculpt.new(); var lp := ls.add_painter(look); var cp := ls.add_painter(claw_p)
		ls.blob(e, Vector3.ONE * thick * 0.95, lp, {"lat": 5, "lon": 7})
		ls.tube([e, e.lerp(foot, 0.5) + Vector3(side * 0.02, 0, 0.02), foot + Vector3(0, 0.07, 0)], [thick * 0.9, thick * 0.75, thick * 0.7], lp, {"sides": 9, "per": 3, "lump": 0.04})
		# A spur of horn behind the elbow.
		ls.crystal(e + Vector3(0, 0, thick * 0.6), Vector3(side * 0.3, 0.3, 1.0), thick * 1.6, thick * 0.3, cp, 4)
		ls.blob(foot + Vector3(0, 0.03, -0.02), Vector3(thick * 1.1, thick * 0.55, thick * 1.3), lp, {"lat": 5, "lon": 8})
		for c in range(3):
			var cd := Vector3((c - 1) * 0.45 + side * 0.15, 0.0, -1.0).normalized()
			var cb := foot + Vector3(0, 0.03, -0.02) + cd * thick * 1.1
			ls.tube([cb, cb + cd * 0.06 + Vector3(0, 0.01, 0), cb + cd * 0.1 + Vector3(0, -0.035, 0)], [thick * 0.32, thick * 0.22, 0.002], cp, {"sides": 6, "per": 2, "cap1": false})
		var cbk := foot + Vector3(0, 0.04, thick * 0.9)
		ls.tube([cbk, cbk + Vector3(0, 0.0, 0.06), cbk + Vector3(0, -0.035, 0.08)], [thick * 0.25, thick * 0.18, 0.002], cp, {"sides": 5, "per": 2, "cap1": false})
		part(knee, "Forearm", ls)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


## A glowing throat deep in the open mouth, like a furnace of light behind the teeth.
func throat_glow(head: Node3D, at: Vector3, size: Vector3) -> void:
	var gs := Sculpt.new(); var gw := gs.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	gs.blob(at, size, gw, {"lat": 5, "lon": 9})
	part(head, "ThroatGlow", gs, glow).material_override = glow


# ------------------------------------------------------------------ A: rattlesnake

static func diamondback(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#6e6452").lerp(Color("#a89c80"), clampf(0.45 + Sculpt.fbm(p * 6.0) * 0.6, 0.0, 1.0))
	var top := smoothstep(-0.55, 0.05, n.y)
	# The diamonds: dark smoky-quartz centres ringed with a row of pale scales.
	var u := absf(fposmod(p.z * 2.1, 1.0) - 0.5) * 2.0
	var d := u * 0.8 + absf(n.x) * 0.55 + Sculpt.noise(p * 9.0) * 0.06
	c = c.lerp(Color("#f4eedc"), smoothstep(0.6, 0.64, d) * smoothstep(0.78, 0.72, d) * top)
	c = c.lerp(Color("#221c24"), smoothstep(0.6, 0.54, d) * top)
	c = c.lerp(Color("#5a5068"), smoothstep(0.3, 0.16, d) * top * 0.7)
	return c.lerp(Color("#c8bea4"), smoothstep(-0.25, -0.7, n.y))


static func coontail(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var band := fposmod(p.z * 4.2, 1.0)
	var c := Color("#16131a") if band < 0.5 else Color("#e8e4dc")
	return c.lerp(Color("#d8d0c0"), smoothstep(-0.3, -0.8, n.y) * 0.5)


func _rattler() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(diamondback)
	var keel := func (p: Vector3, _n: Vector3, v: float, _w: float) -> Color: return Color("#3a3248").lerp(Color("#e8e0ff"), v)
	var kp := body.add_painter(keel)
	# The forebody rises in an S, the head held high and drawn back to strike.
	var path := [Vector3(0.0, 0.27, 0.55), Vector3(0.16, 0.28, 0.2), Vector3(0.12, 0.42, -0.12), Vector3(-0.04, 0.72, -0.28), Vector3(-0.02, 0.96, -0.42)]
	body.tube(path, [0.31, 0.32, 0.28, 0.23, 0.2], bp, {"sides": 22, "per": 6, "bands": 14, "band": 0.035, "lump": 0.03, "cap0": false, "cap1": false})
	# Keeled crystal scales down the spine.
	for k in range(12):
		var t := float(k) / 11.0
		var i := mini(int(t * 3.999), 3)
		var c: Vector3 = (path[i] as Vector3).lerp(path[i + 1], t * 4.0 - i)
		var r := lerpf(0.31, 0.2, t)
		var tg: Vector3 = ((path[i + 1] as Vector3) - (path[i] as Vector3)).normalized()
		var up := (Vector3.UP - tg * tg.y).normalized()
		body.crystal(c + up * r * 0.9, up + tg * -0.7, 0.15, 0.032, kp, 4)
	var tails := tail_chain(Vector3(0.0, 0.31, 0.5), 9, 0.4, 0.31, 0.08, diamondback, {"sides": 20, "per": 3, "bands": 3, "band": 0.035},
		func (ts: Sculpt, a: Vector3, b: Vector3, r: float, k: int) -> void:
			if k >= 7:
				ts.tube([a, a.lerp(b, 0.5), b], [r * 1.04, r * 1.03, r * 0.98], ts.add_painter(coontail), {"sides": 14, "per": 3, "cap0": false, "cap1": k == 8})
			if k < 7:
				var kk := ts.add_painter(keel)
				for j in range(2): ts.crystal(a.lerp(b, 0.25 + j * 0.5) + Vector3(0, r * 0.9, 0), Vector3(0, 1, 0.7), 0.14 * (1.0 - k * 0.08), 0.03, kk, 4)
			if k == 8:
				# The rattle: stacked hollow segments of clear quartz, each smaller than the last.
				var q := ts.add_painter(func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color: return Color("#9a8a6a").lerp(Color("#f4ecd8"), clampf(n.y * 0.5 + 0.5, 0.0, 1.0)))
				var dir := (b - a).normalized()
				var at := b
				for s in range(8):
					var rr := 0.105 - s * 0.008
					ts.lathe(at + dir * rr * 0.6, [Vector2(0.0, rr * 0.75), Vector2(rr * 0.75, rr * 0.55), Vector2(rr, 0.0), Vector2(rr * 0.75, -rr * 0.55), Vector2(0.0, -rr * 0.7)], q, {"sides": 10, "basis": Basis(Quaternion(Vector3.UP, dir))})
					at += dir * rr * 1.05)
	var head := joint(root, "Head", Vector3(0, 0.98, -0.46))
	var hs := Sculpt.new()
	# The diamondback's mask: a dark stripe slanting back from each eye to the corner of the
	# jaw, edged in pale.
	var hp := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#6e6452").lerp(Color("#a89c80"), clampf(0.45 + Sculpt.fbm(p * 7.0) * 0.6, 0.0, 1.0))
		var line := (p.y - 1.06) + (p.z + 0.78) * 0.5
		var side_f := smoothstep(0.35, 0.75, absf(n.x))
		c = c.lerp(Color("#2a2228"), smoothstep(0.035, 0.015, absf(line + 0.01)) * side_f)
		c = c.lerp(Color("#f2ead8"), smoothstep(0.022, 0.008, absf(line - 0.04)) * side_f)
		c = c.lerp(Color("#5a5060"), smoothstep(0.3, 0.8, n.y) * smoothstep(-0.55, -0.7, p.z) * 0.5)
		return c.lerp(Color("#e6dcc2"), smoothstep(-0.25, -0.7, n.y)))
	var dark := hs.add_painter(func (_p, _n, _v, _w): return Color("#1a1418"))
	var brow := hs.add_painter(func (p: Vector3, n: Vector3, _v, _w): return Color("#3a3238").lerp(Color("#8f8470"), clampf(n.y * 0.5 + Sculpt.noise(p * 20.0) * 0.3, 0.0, 1.0)))
	var fang := hs.add_painter(func (_p, _n, v: float, _w): return Color("#f4eedc").lerp(Color("#d8e8ff"), v))
	var gum := hs.add_painter(func (_p, n: Vector3, _v, _w): return Color("#c86a78").darkened(clampf(n.y, 0.0, 1.0) * 0.3))
	# A broad, flat, triangular head: wide jowls over the venom glands, narrowing to the snout.
	hs.tube([Vector3(0, 1.0, -0.42), Vector3(0, 1.02, -0.58), Vector3(0, 1.02, -0.78), Vector3(0, 0.99, -0.96)], [0.12, 0.13, 0.1, 0.05], hp, {"sides": 20, "per": 3, "flat": 2.3, "cap_len": 0.55})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.17 * side, 0.99, -0.6), Vector3(0.13, 0.085, 0.16), hp, {"lat": 6, "lon": 9})
		# Hooded brow scales (supraoculars) jutting over the eyes: the snake's scowl.
		hs.blob(Vector3(0.175 * side, 1.1, -0.77), Vector3(0.07, 0.026, 0.09), brow, {"lat": 4, "lon": 8, "basis": Basis(Vector3.FORWARD, -0.35 * side) * Basis(Vector3.RIGHT, 0.15)})
		hs.blob(Vector3(0.15 * side, 1.0, -0.88), Vector3(0.022, 0.018, 0.02), dark, {"lat": 4, "lon": 6})  # heat pit
		hs.blob(Vector3(0.06 * side, 1.02, -0.99), Vector3(0.014, 0.01, 0.01), dark, {"lat": 3, "lon": 5})  # nostril
		# Long hinged fangs, swung forward to strike, crystal at the tips.
		var f0 := Vector3(0.075 * side, 0.96, -0.9)
		hs.tube([f0, f0 + Vector3(0, -0.09, -0.02), f0 + Vector3(0, -0.17, 0.04)], [0.018, 0.013, 0.002], fang, {"sides": 7, "per": 3, "cap1": false})
		for k in range(4): hs.crystal(Vector3((0.1 - k * 0.012) * side, 0.965, -0.82 + k * 0.06), Vector3(0, -1, 0.3), 0.045, 0.009, fang, 4)
	hs.blob(Vector3(0, 0.955, -0.74), Vector3(0.15, 0.02, 0.2), gum, {"lat": 4, "lon": 10})
	part(head, "Head", hs)
	glow.albedo_color = Color("#c88a1a"); glow.emission = Color("#ffb020"); glow.emission_energy_multiplier = 0.9
	var eyes := [Vector3(-0.2, 1.06, -0.78), Vector3(0.2, 1.06, -0.78)]
	var core := _eyes(head, eyes, 0.034)
	slit_pupils(head, eyes, 0.034, [Vector3(-0.7, 0, -0.7).normalized(), Vector3(0.7, 0, -0.7).normalized()])
	var jaw := joint(head, "Jaw", Vector3(0, 0.95, -0.44))
	var js := Sculpt.new(); var jp := js.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return diamondback(p, n, v, w).lerp(Color("#e6dcc2"), 0.6))
	var jg := js.add_painter(func (_p, n: Vector3, _v, _w): return Color("#c86a78").darkened(clampf(-n.y, 0.0, 1.0) * 0.3))
	var tongue := js.add_painter(func (_p, _n, v: float, _w): return Color("#2a0e18").lerp(Color("#101014"), v))
	var jt := js.add_painter(func (_p, _n, v: float, _w): return Color("#f4eedc").lerp(Color("#d8e8ff"), v))
	js.tube([Vector3(0, 0.95, -0.44), Vector3(0, 0.93, -0.66), Vector3(0, 0.94, -0.92)], [0.09, 0.075, 0.035], jp, {"sides": 14, "per": 3, "flat": 2.3, "cap_len": 0.5})
	js.blob(Vector3(0, 0.95, -0.7), Vector3(0.12, 0.018, 0.18), jg, {"lat": 4, "lon": 10})
	for side in [-1.0, 1.0]:
		for k in range(4): js.crystal(Vector3((0.09 - k * 0.012) * side, 0.95, -0.78 + k * 0.06), Vector3(0, 1, 0.3), 0.035, 0.008, jt, 4)
		js.tube([Vector3(0, 0.955, -0.85), Vector3(0.01 * side, 0.95, -1.05), Vector3(0.05 * side, 0.935, -1.14)], [0.014, 0.01, 0.003], tongue, {"sides": 6, "per": 2, "flat": 1.6, "cap1": false})
	part(jaw, "Jaw", js).rotation.x = -0.32
	# Draconic: great horns, horned brows, jowl spines, a spined skull and chin, a furnace glow
	# in the throat, torn wings and one pair of clawed forelegs.
	var hn := Sculpt.new()
	var hornp := hn.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#2a2228").lerp(Color("#d8ccb0"), v))
	for side in [-1.0, 1.0]:
		horn(hn, hornp, Vector3(0.13 * side, 1.07, -0.52), Vector3(0.35 * side, 0.6, 1.0), 0.52, 0.048, Vector3(1, 0, 0), 1.0)
		horn(hn, hornp, Vector3(0.19 * side, 1.11, -0.77), Vector3(0.3 * side, 1.0, 0.35), 0.13, 0.022, Vector3(1, 0, 0), 0.5)
		for k in range(3):
			horn(hn, hornp, Vector3(0.24 * side, 1.0 - k * 0.035, -0.56 + k * 0.05), Vector3(side, -0.1 - k * 0.15, 0.9), 0.15 - k * 0.025, 0.02, Vector3.UP, 0.2 * side)
	for k in range(4): horn(hn, hornp, Vector3(0, 1.13 - k * 0.01, -0.68 + k * 0.07), Vector3(0, 1, 0.8), 0.08, 0.017, Vector3(1, 0, 0), 0.3)
	part(head, "Horns", hn)
	var jh := Sculpt.new(); var jhp := jh.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#2a2228").lerp(Color("#d8ccb0"), v))
	for side in [-1.0, 1.0]:
		for k in range(3): horn(jh, jhp, Vector3((0.13 - k * 0.025) * side, 0.885, -0.52 - k * 0.1), Vector3(0.3 * side, -1.0, 0.5), 0.09 - k * 0.012, 0.015, Vector3(1, 0, 0), 0.3)
	part(jaw, "ChinSpikes", jh).rotation.x = -0.32
	throat_glow(head, Vector3(0, 0.955, -0.64), Vector3(0.07, 0.025, 0.1))
	var ws := Sculpt.new()
	var wb := ws.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#4a4038").lerp(Color("#a89c80"), v * 0.6))
	var wm := ws.add_painter(func (p: Vector3, _n, v: float, w: float) -> Color: return Color("#2a2026").lerp(Color("#6a5848"), clampf(v * 0.7 + Sculpt.noise(p * 14.0) * 0.3, 0.0, 1.0)).darkened(smoothstep(0.85, 1.0, absf(sin(w * PI * 3.0))) * 0.3))
	for side in [-1.0, 1.0]:
		wing(ws, wb, wm, Vector3(0.16 + 0.2 * side, 0.56, 0.12), side, 0.95, Vector3(0.16 + 0.1 * side, 0.6, 0.62))
	part(root, "Wings", ws, wing_mat)
	var legs := forelegs(diamondback, Vector3(0.12, 0.42, -0.1), 0.3, 0.075)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": tails}, 1.6)
	return _rig(node, head, legs[0], legs[1], jaw, tails)


# ------------------------------------------------------------------ B: oarfish

static func silver(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#5e6a7c").lerp(Color("#aeb8c8"), clampf(0.45 - n.y * 0.5 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
	c = c.lerp(Color.from_hsv(fposmod(n.x * 0.4 + p.z * 0.3, 1.0), 0.3, 1.0), 0.18)
	# Wavy dark streaks and spots along the flanks.
	var streak := absf(sin(p.z * 9.0 + p.y * 14.0 + Sculpt.noise(p * 4.0) * 3.0))
	c = c.lerp(Color("#2a3346"), smoothstep(0.08, 0.0, streak) * smoothstep(0.85, 0.3, absf(n.y)) * 0.75)
	c = c.lerp(Color("#2a3346"), smoothstep(0.45, 0.55, Sculpt.noise(p * 16.0)) * 0.6)
	return c.lerp(Color("#3a4660"), smoothstep(0.4, 0.95, n.y) * 0.75)


static func rose_ray(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color("#a8102e").lerp(Color("#ffb0c4"), v)


static func fin_web(p: Vector3, _n: Vector3, _v: float, _w: float) -> Color:
	return Color("#d8405a").lerp(Color("#ff8aa0"), clampf(0.5 + Sculpt.noise(p * 12.0) * 0.5, 0.0, 1.0))


## A run of dorsal fin from `a` to `b` on a body of half-height `h`: rays of rose crystal
## joined by a thin red web.
func dorsal(s: Sculpt, a: Vector3, b: Vector3, h: float, tall: float, rays: int) -> void:
	var rp := s.add_painter(rose_ray); var wp := s.add_painter(fin_web)
	var base0 := a + Vector3(0, h * 0.92, 0); var base1 := b + Vector3(0, h * 0.92, 0)
	for j in range(rays):
		var t := (j + 0.5) / rays
		var at := base0.lerp(base1, t)
		s.crystal(at, Vector3(0, 1, 0.35), tall * (0.85 + 0.3 * absf(sin(j * 2.3 + a.z))), 0.012, rp, 4)
	var mid := tall * 0.42
	s.tube([base0 + Vector3(0, mid, 0), base1 + Vector3(0, mid, 0)], [mid, mid], wp, {"sides": 6, "per": 2, "flat": 0.06, "cap0": false, "cap1": false})


func _oarfish() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(silver)
	var path := [Vector3(0.0, 0.34, 0.55), Vector3(0.1, 0.36, 0.2), Vector3(0.06, 0.52, -0.12), Vector3(-0.02, 0.78, -0.32), Vector3(0.0, 0.98, -0.44)]
	var rads := [0.34, 0.35, 0.33, 0.3, 0.27]
	body.tube(path, rads, bp, {"sides": 22, "per": 6, "flat": 0.42, "bands": 16, "band": 0.02, "cap0": false, "cap1": false})
	for i in range(4): dorsal(body, path[i], path[i + 1], lerpf(rads[i], rads[i + 1], 0.5), 0.26, 5)
	var tails := tail_chain(Vector3(0.0, 0.34, 0.5), 10, 0.42, 0.34, 0.05, silver, {"sides": 16, "per": 2, "flat": 0.42, "bands": 4, "band": 0.02},
		func (ts: Sculpt, a: Vector3, b: Vector3, r: float, k: int) -> void:
			dorsal(ts, a, b, r, 0.24 - k * 0.012, 5))
	var head := joint(root, "Head", Vector3(0, 1.0, -0.44))
	var hs := Sculpt.new(); var hp := hs.add_painter(silver)
	var ring := hs.add_painter(func (_p, _n, _v, _w): return Color("#1e2430"))
	# A blunt, deep, flat-sided head with a small upturned mouth.
	hs.tube([Vector3(0, 0.99, -0.4), Vector3(0, 1.0, -0.56), Vector3(0, 0.98, -0.72), Vector3(0, 0.95, -0.82)], [0.28, 0.27, 0.21, 0.1], hp, {"sides": 16, "per": 3, "flat": 0.45, "cap_len": 0.7})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.095 * side, 1.04, -0.7), Vector3(0.025, 0.07, 0.07), ring, {"lat": 5, "lon": 9})
		# The gill cover, a ridged arc.
		hs.tube([Vector3(0.1 * side, 1.15, -0.54), Vector3(0.115 * side, 1.0, -0.5), Vector3(0.1 * side, 0.85, -0.55)], [0.015, 0.018, 0.014], hp, {"sides": 6, "per": 3})
	part(head, "Head", hs)
	# The crest: long red rays sweeping up and back off the crown, crystal-tipped.
	var cs := Sculpt.new(); var crp := cs.add_painter(rose_ray); var cwp := cs.add_painter(fin_web)
	for j in range(9):
		var base := Vector3(0, 1.22 - j * 0.01, -0.68 + j * 0.035)
		var l := 0.38 + 0.3 * sin(j * 0.42)
		var dir := Vector3(0.04 * sin(j * 1.7), 1.0, 0.55 + j * 0.06).normalized()
		cs.tube([base, base + dir * l * 0.5 + Vector3(0, 0, 0.04), base + dir * l], [0.014, 0.01, 0.004], crp, {"sides": 5, "per": 3})
		cs.crystal(base + dir * l, dir, 0.08, 0.016, crp, 4)
	cs.tube([Vector3(0, 1.32, -0.64), Vector3(0, 1.4, -0.48)], [0.1, 0.1], cwp, {"sides": 6, "per": 2, "flat": 0.06})
	# The oars: two long pelvic rays trailing from the throat, each ending in a red paddle.
	for side in [-1.0, 1.0]:
		var p0 := Vector3(0.03 * side, 0.82, -0.5)
		var pts := [p0, p0 + Vector3(0.1 * side, -0.25, 0.1), p0 + Vector3(0.18 * side, -0.55, 0.35), p0 + Vector3(0.22 * side, -0.74, 0.75)]
		cs.tube(pts, [0.016, 0.014, 0.012, 0.01], crp, {"sides": 5, "per": 3})
		cs.blob((pts[3] as Vector3) + Vector3(0, 0.0, 0.08), Vector3(0.03, 0.012, 0.1), cwp, {"lat": 4, "lon": 8})
	part(head, "Crest", cs)
	glow.albedo_color = Color("#b0203a"); glow.emission = Color("#ff3a5a"); glow.emission_energy_multiplier = 1.0
	var eyes := [Vector3(-0.11, 1.04, -0.71), Vector3(0.11, 1.04, -0.71)]
	var core := _eyes(head, eyes, 0.04)
	# A heavy, spined brow ridge scowling over each eye.
	var bs := Sculpt.new(); var bp2 := bs.add_painter(func (_p, n: Vector3, _v, _w) -> Color: return Color("#2a3246").lerp(Color("#6a7890"), clampf(n.y, 0.0, 1.0)))
	var bsp := bs.add_painter(rose_ray)
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.08 * side, 1.1, -0.8), Vector3(0.12 * side, 1.105, -0.71), Vector3(0.11 * side, 1.09, -0.62)], [0.02, 0.032, 0.018], bp2, {"sides": 8, "per": 3})
		for k in range(3): horn(bs, bsp, Vector3(0.12 * side, 1.11, -0.74 + k * 0.05), Vector3(0.4 * side, 0.6, 1.0), 0.09, 0.012, Vector3(1, 0, 0), 0.3)
	part(head, "Brows", bs)
	var pp := Sculpt.new(); var pk := pp.add_painter(func (_p, _n, _v, _w): return Color("#06080c"))
	for e: Vector3 in eyes: pp.blob(e + Vector3(signf(e.x) * 0.036, 0, -0.005), Vector3(0.008, 0.03, 0.009), pk, {"lat": 4, "lon": 6})
	part(head, "Pupils", pp)
	var jaw := joint(head, "Jaw", Vector3(0, 0.92, -0.6))
	var js := Sculpt.new(); var jp := js.add_painter(silver); var jm := js.add_painter(func (_p, _n, _v, _w): return Color("#3a1a26"))
	js.tube([Vector3(0, 0.92, -0.6), Vector3(0, 0.9, -0.76), Vector3(0, 0.93, -0.86)], [0.1, 0.07, 0.035], jp, {"sides": 12, "per": 3, "flat": 0.6, "cap_len": 0.5})
	js.blob(Vector3(0, 0.935, -0.8), Vector3(0.04, 0.012, 0.05), jm, {"lat": 4, "lon": 8})
	part(jaw, "Jaw", js).rotation.x = -0.2
	# Draconic: a sea dragon's branching crystal antlers, long whiskers trailing from the lip,
	# a cold glow in the throat, fin-wings of rose crystal and one pair of clawed forelegs.
	var hn := Sculpt.new(); var hornp := hn.add_painter(rose_ray)
	var barb := hn.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#c8d0e0").lerp(Color("#ff8aa0"), v))
	for side in [-1.0, 1.0]:
		var b0 := Vector3(0.07 * side, 1.18, -0.6)
		horn(hn, hornp, b0, Vector3(0.3 * side, 1.0, 0.6), 0.5, 0.035, Vector3(1, 0, 0), 0.6)
		for k in range(2):
			var tb := b0 + Vector3(0.3 * side, 1.0, 0.6).normalized() * (0.16 + k * 0.15)
			horn(hn, hornp, tb, Vector3(0.6 * side, 0.6, -0.3 + k * 0.3), 0.16 - k * 0.03, 0.018, Vector3(0, 0, 1), -0.4 * side)
		horn(hn, barb, Vector3(0.06 * side, 0.95, -0.83), Vector3(0.5 * side, -0.4, 0.5), 0.55, 0.012, Vector3(0, 1, 0), 1.2 * side)
	part(head, "Antlers", hn)
	throat_glow(head, Vector3(0, 0.94, -0.74), Vector3(0.035, 0.015, 0.05))
	var ws := Sculpt.new(); var wb := ws.add_painter(rose_ray); var wm := ws.add_painter(fin_web)
	for side in [-1.0, 1.0]:
		wing(ws, wb, wm, Vector3(0.1 + 0.12 * side, 0.58, 0.12), side, 0.9, Vector3(0.1 + 0.06 * side, 0.62, 0.62))
	part(root, "FinWings", ws, wing_mat)
	var legs := forelegs(silver, Vector3(0.06, 0.52, -0.1), 0.22, 0.062)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": tails}, 1.55)
	return _rig(node, head, legs[0], legs[1], jaw, tails)


# ------------------------------------------------------------------ C: lamprey

static func lamprey_skin(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#262e38").lerp(Color("#4e5868"), clampf(0.4 + Sculpt.fbm(p * 5.0) * 0.8, 0.0, 1.0))
	c = c.lerp(Color("#1c2430"), smoothstep(0.35, 0.5, Sculpt.noise(p * 9.0)) * 0.6)
	# Mineral ribs: each ring of the body crusted with pale blue-grey stone.
	var ring := absf(fposmod(p.z * 5.0, 1.0) - 0.5)
	c = c.lerp(Color("#a8b8cc"), smoothstep(0.08, 0.0, ring) * 0.7)
	return c.lerp(Color("#b8bcc4"), smoothstep(-0.3, -0.8, n.y) * 0.7)


func _lamprey() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(lamprey_skin)
	var rib := body.add_painter(func (p: Vector3, n: Vector3, v: float, _w: float) -> Color: return Color("#6a7c94").lerp(Color("#d6e4f6"), v))
	var path := [Vector3(0.0, 0.3, 0.55), Vector3(0.14, 0.31, 0.2), Vector3(0.1, 0.46, -0.12), Vector3(-0.02, 0.74, -0.3), Vector3(0.0, 0.94, -0.44)]
	var rads := [0.3, 0.31, 0.29, 0.27, 0.25]
	body.tube(path, rads, bp, {"sides": 22, "per": 6, "bands": 12, "band": 0.06, "lump": 0.04, "cap0": false, "cap1": false})
	# Mineral rib-plates standing along the back like the teeth of a comb.
	for k in range(10):
		var t := float(k) / 9.0
		var i := mini(int(t * 3.999), 3)
		var c: Vector3 = (path[i] as Vector3).lerp(path[i + 1], t * 4.0 - i)
		var r: float = lerpf(rads[i], rads[i + 1], t * 4.0 - i)
		for side in [-1.0, 1.0]:
			var d := Vector3(0.75 * side, 0.65, 0.2).normalized()
			body.crystal(c + d * r * 0.9, d + Vector3(0, 0, 0.4), 0.07, 0.02, rib, 4)
	var fins := func (ts: Sculpt, a: Vector3, b: Vector3, r: float, k: int) -> void:
		var rp := ts.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#4a5a74").lerp(Color("#cfe6ff"), v))
		if k == 1 or k == 2 or (k >= 4 and k <= 6):
			for j in range(5):
				ts.crystal(a.lerp(b, (j + 0.5) / 5.0) + Vector3(0, r * 0.9, 0), Vector3(0, 1, 0.5), 0.1 + 0.08 * sin(PI * (j + 0.5) / 5.0), 0.014, rp, 4)
			ts.tube([a + Vector3(0, r + 0.06, 0), b + Vector3(0, r + 0.06, 0)], [0.06, 0.06], ts.add_painter(func (_p, _n, _v, _w): return Color("#5a6a84")), {"sides": 6, "per": 2, "flat": 0.06, "cap0": false, "cap1": false})
	var tails := tail_chain(Vector3(0.0, 0.3, 0.5), 9, 0.42, 0.3, 0.06, lamprey_skin, {"sides": 16, "per": 2, "bands": 3, "band": 0.06}, fins)
	var head := joint(root, "Head", Vector3(0, 0.96, -0.44))
	var hs := Sculpt.new(); var hp := hs.add_painter(lamprey_skin)
	var dark := hs.add_painter(func (_p, _n, _v, _w): return Color("#0c0a10"))
	var fringe := hs.add_painter(func (p: Vector3, _n: Vector3, v: float, _w: float) -> Color: return Color("#6a5060").lerp(Color("#c8a0b0"), v))
	var tooth := hs.add_painter(func (_p, _n, v: float, _w: float) -> Color: return Color("#7aa0d8").lerp(Color("#f0f8ff"), v))
	var gullet := hs.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#3a0e18").lerp(Color("#8a2a3a"), clampf(Sculpt.noise(p * 12.0) + 0.4, 0.0, 1.0)))
	# The head: a tube flaring into the round oral disc that faces forward and down.
	var disc := Vector3(0, 0.98, -0.88)
	var axis := Vector3(0, -0.3, -1).normalized()
	hs.tube([Vector3(0, 0.96, -0.4), Vector3(0, 0.99, -0.6), Vector3(0, 1.0, -0.76), disc - axis * 0.04], [0.25, 0.24, 0.25, 0.3], hp, {"sides": 18, "per": 3, "cap0": false, "cap1": false})
	var right := axis.cross(Vector3.UP).normalized(); var upd := right.cross(axis).normalized()
	# The disc face: a funnel of teeth in rings, sloping in to the throat.
	var face := disc - axis * 0.02
	hs.tube([face, face + axis * 0.1, face + axis * 0.22], [0.3, 0.17, 0.06], gullet, {"sides": 20, "per": 2, "cap0": false, "cap_len": 0.4})
	for ringk in range(4):
		var r := 0.27 - ringk * 0.055
		var count := 22 - ringk * 4
		for k in range(count):
			var a := TAU * (k + ringk * 0.5) / count
			var radial := right * cos(a) + upd * sin(a)
			var base := face + radial * r + axis * (0.02 + ringk * 0.03)
			hs.crystal(base, -axis * 0.8 - radial * 0.45, 0.07 - ringk * 0.008, 0.013, tooth, 4)
	# The rim: a fringe of soft papillae all round the disc.
	for k in range(30):
		var a := TAU * k / 30.0
		var radial := right * cos(a) + upd * sin(a)
		var base := face + radial * 0.3
		hs.tube([base, base + radial * 0.05 - axis * 0.02], [0.014, 0.004], fringe, {"sides": 5, "per": 1, "cap1": false})
	# One nostril on top of the head; seven gill pores behind each eye (glowing, below).
	hs.blob(Vector3(0, 1.21, -0.62), Vector3(0.02, 0.012, 0.03), dark, {"lat": 4, "lon": 6})
	part(head, "Head", hs)
	glow.albedo_color = Color("#3ac8d8"); glow.emission = Color("#5af0ff"); glow.emission_energy_multiplier = 1.1
	var gills: Array = []
	for side in [-1.0, 1.0]:
		for k in range(7): gills.append(Vector3(0.235 * side, 0.94 - k * 0.012, -0.47 + k * 0.075 - 0.2))
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for g: Vector3 in gills: es.blob(g, Vector3(0.016, 0.026, 0.02), ew, {"lat": 4, "lon": 6})
	for side in [-1.0, 1.0]: es.blob(Vector3(0.2 * side, 1.08, -0.72), Vector3.ONE * 0.034, ew, {"lat": 5, "lon": 8})
	var core := part(head, "GillsAndEyes", es, glow); core.material_override = glow
	slit_pupils(head, [Vector3(-0.2, 1.08, -0.72), Vector3(0.2, 1.08, -0.72)], 0.034, [Vector3(-1, 0, -0.4).normalized(), Vector3(1, 0, -0.4).normalized()])
	# The jaw: the lower lip of the disc, which gapes when it feeds.
	var jaw := joint(head, "Jaw", face - upd * 0.12)
	var js := Sculpt.new(); var jl := js.add_painter(lamprey_skin); var jt := js.add_painter(func (_p, _n, v: float, _w: float) -> Color: return Color("#7aa0d8").lerp(Color("#f0f8ff"), v))
	js.tube([face - upd * 0.24 + axis * 0.06, face - upd * 0.3 - axis * 0.02], [0.08, 0.06], jl, {"sides": 10, "per": 2, "flat": 2.2, "side": right})
	for k in range(5): js.crystal(face - upd * 0.26 + right * (k - 2) * 0.05, -axis + upd * 0.6, 0.06, 0.012, jt, 4)
	part(jaw, "Jaw", js)
	# Draconic: two great horns and a crown of smaller ones round the back of the disc, a glow
	# deep in the throat, torn stone-grey wings and one pair of clawed forelegs.
	var hn := Sculpt.new(); var hornp := hn.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#1c2028").lerp(Color("#c8d8ec"), v))
	for side in [-1.0, 1.0]:
		horn(hn, hornp, Vector3(0.12 * side, 1.17, -0.58), Vector3(0.4 * side, 0.7, 1.0), 0.6, 0.05, Vector3(1, 0, 0), 1.1)
	for k in range(7):
		var a := lerpf(-0.35, PI + 0.35, k / 6.0)
		var radial := Vector3(cos(a), sin(a), 0.0)
		var hb := Vector3(0, 0.99, -0.74) + radial * 0.25
		horn(hn, hornp, hb, radial * 0.7 + Vector3(0, 0, 1.0), 0.16 + 0.05 * sin(a), 0.022, radial.cross(Vector3(0, 0, 1)), -0.5)
	part(head, "Horns", hn)
	throat_glow(head, disc + axis * 0.16, Vector3(0.07, 0.07, 0.04))
	var ws := Sculpt.new()
	var wb := ws.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#3a4452").lerp(Color("#b8c8dc"), v * 0.6))
	var wm := ws.add_painter(func (p: Vector3, _n, v: float, w: float) -> Color: return Color("#1a1e26").lerp(Color("#4a5668"), clampf(v * 0.6 + Sculpt.noise(p * 12.0) * 0.35, 0.0, 1.0)).lerp(Color("#3ac8d8"), smoothstep(0.93, 1.0, absf(sin(w * PI * 3.0))) * 0.45))
	for side in [-1.0, 1.0]:
		wing(ws, wb, wm, Vector3(0.14 + 0.2 * side, 0.55, 0.12), side, 1.0, Vector3(0.14 + 0.1 * side, 0.58, 0.62))
	part(root, "Wings", ws, wing_mat)
	var legs := forelegs(lamprey_skin, Vector3(0.1, 0.46, -0.1), 0.29, 0.072)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": tails}, 1.6)
	return _rig(node, head, legs[0], legs[1], jaw, tails)
