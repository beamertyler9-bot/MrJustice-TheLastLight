extends "res://tools/sculpt_dune_maw.gd"
## The Riftback of the Ashfall Caldera, sculpted by hand: a heavy armoured beast whose back is
## made of basalt, split by glowing rifts of lava. Three designs, each built on a real armoured
## animal:
##   columns  - a glyptodont (the giant armadillo of the Ice Age, its shell a dome of bony
##              rosettes) whose shell is a dome of basalt columns, the six-sided pillars that
##              lava cracks into as it cools, with a rift of lava down its spine; a bony cap on
##              its head and an armoured, ringed tail
##   pangolin - a giant pangolin: overlapping basalt scales from snout to tail, lava glowing in
##              the gaps, a small cone head with a long snout and huge digging claws
##   tortoise - a Galapagos giant tortoise (they live on volcanoes) with a saddleback shell of
##              basalt scutes split by lava, a small smoking vent on top and a long leathery neck

const BASALT := Color("#2a292c")
const BASALT_LIGHT := Color("#57545a")
const ASHEN := Color("#86817b")
const CLAW := Color("#1a1715")
const LAVA := Color("#ff5a14")


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(3.5, 3.5, 3.5)
	material.roughness = 0.9
	glow.albedo_color = Color("#b8360c"); glow.emission = Color("#ff4a0c"); glow.emission_energy_multiplier = 1.4


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Riftback"
	match variant:
		"columns": return _columns()
		"pangolin": return _pangolin()
		"tortoise": return _tortoise()
	return null


# ------------------------------------------------------------------ painters

## Basalt: near-black, pitted with gas bubbles, dusted pale with ash on top.
static func basalt(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := BASALT.lerp(BASALT_LIGHT, clampf(n.y * 0.3 + 0.2 + Sculpt.fbm(p * 6.0) * 0.4, 0.0, 1.0))
	c = c.darkened(smoothstep(0.5, 0.65, Sculpt.noise(p * 45.0)) * 0.5)
	return c.lerp(ASHEN, smoothstep(0.55, 1.0, n.y) * smoothstep(0.0, 0.5, Sculpt.fbm(p * 3.0 + Vector3(5, 1, 2))) * 0.5)


## Leathery grey-black skin, creased, paler underneath.
static func hide(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#3b3735").lerp(Color("#5e5752"), clampf(Sculpt.fbm(p * 9.0) * 0.5 + 0.3 - n.y * 0.2, 0.0, 1.0))
	return c.darkened(smoothstep(0.75, 0.95, absf(sin(Sculpt.fbm(p * 4.0) * 20.0))) * 0.3)


static func claw(_p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return CLAW.lerp(Color("#5b524a"), v * 0.6 + clampf(n.y, 0.0, 1.0) * 0.15)


# ------------------------------------------------------------------ shared pieces

## Short, thick pillar legs with broad padded feet and heavy claws, like an armadillo's or a
## tortoise's. Returns {hips, knees}.
func stout_legs(skin: Callable, width: float, front_z: float, hind_z: float, hip_y: float, thick: float, claws: int, claw_len: float) -> Dictionary:
	var hips: Array = []; var knees: Array = []
	for row in [["Front", front_z, true], ["Hind", hind_z, false]]:
		for side: float in [-1.0, 1.0]:
			var z: float = row[1]; var front: bool = row[2]
			var x := width * side
			var hip := joint(root, str(row[0]) + ("Left" if side < 0 else "Right") + "Leg", Vector3(x, hip_y, z))
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at := Vector3(x * 1.08, hip_y * 0.45, z + (-0.02 if front else 0.04))
			us.tube([Vector3(x * 0.95, hip_y + 0.06, z), Vector3(x * 1.04, lerpf(hip_y, knee_at.y, 0.5), z), knee_at], [0.15 * thick, 0.13 * thick, 0.105 * thick], up, {"sides": 12, "per": 3, "lump": 0.08})
			part(hip, "Upper", us)
			var knee := joint(hip, "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cp := ls.add_painter(claw)
			var foot := Vector3(x * 1.1, 0.06, knee_at.z - 0.03)
			ls.tube([knee_at, foot + Vector3(0, 0.06, 0)], [0.1 * thick, 0.1 * thick], lp, {"sides": 12, "per": 2, "lump": 0.08})
			ls.blob(foot, Vector3(0.12, 0.07, 0.13) * thick, lp, {"lat": 6, "lon": 10, "lump": 0.1})
			for c in range(claws):
				var off := c - (claws - 1) * 0.5
				var at := foot + Vector3(off * 0.05 * thick, -0.02, -0.1 * thick + absf(off) * 0.02)
				ls.tube([at, at + Vector3(off * 0.012, -0.015, -claw_len * 0.6), at + Vector3(off * 0.018, -0.055, -claw_len)], [0.024 * thick, 0.016 * thick, 0.003], cp, {"sides": 6, "per": 2, "cap1": false})
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)
	return {"hips": hips, "knees": knees}


## A basalt column standing out of a surface: a six-sided pillar along `normal`, flat-topped.
func column(s: Sculpt, painter: int, base: Vector3, normal: Vector3, radius: float, height: float, twist: float) -> void:
	s.tube([base - normal * 0.06, base + normal * height], [radius, radius * 0.97], painter, {"sides": 6, "per": 1, "cap_len": 0.12, "cap_rings": 1, "side": normal.cross(Vector3.FORWARD).rotated(normal, twist) if absf(normal.z) < 0.9 else Vector3.RIGHT, "facet": true})


## A point on an ellipsoid (centre c, radii r) at latitude phi (0 on top) and longitude th,
## with its outward normal.
static func on_dome(c: Vector3, r: Vector3, phi: float, th: float) -> Array:
	var u := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
	return [c + u * r, (u / r).normalized()]


## A lava-filled cap under a shell: the ellipsoid (c, r) from the top down to latitude `to`.
func lava_cap(s: Sculpt, painter: int, c: Vector3, r: Vector3, to: float, shrink: float) -> void:
	var prof: Array = []
	for k in range(13):
		var phi := to * k / 12.0
		prof.append(Vector2(sin(phi) * r.x * shrink, cos(phi) * r.y * shrink))
	prof.append(Vector2(0, cos(to) * r.y * shrink))
	s.lathe(c, prof, painter, {"sides": 24, "basis": Basis.from_scale(Vector3(1, 1, r.z / r.x))})


## An armoured tail of segments that the game swings.
func ringed_tail(start: Vector3, count: int, step: Vector3, r0: float, paint: Callable, spikes: bool) -> Array:
	var tails: Array = []; var parent: Node3D = root; var at := start
	for k in range(count):
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var ts := Sculpt.new(); var tp := ts.add_painter(paint)
		var ra := lerpf(r0, r0 * 0.35, float(k) / count); var rb := lerpf(r0, r0 * 0.35, float(k + 1) / count)
		var dir := step + Vector3(0, -0.02 * k, 0)
		var next := at + dir
		ts.tube([at - dir * 0.1, at.lerp(next, 0.5), next + dir * 0.05], [ra * 1.05, (ra + rb) * 0.55, rb], tp, {"sides": 12, "per": 2, "cap1": k == count - 1, "lump": 0.06})
		if spikes:
			for j in range(5):
				var a := PI * (0.15 + 0.7 * j / 4.0)
				var out := Vector3(cos(a), sin(a), 0)
				column(ts, tp, at.lerp(next, 0.5) + out * (ra + rb) * 0.45, (out + dir.normalized() * 0.3).normalized(), 0.028, 0.05 + 0.03 * (j % 2), j)
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	return tails


# ------------------------------------------------------------------ A: basalt-column glyptodont

func _columns() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(hide); var cp := body.add_painter(basalt)
	var c := Vector3(0, 0.56, 0.05); var r := Vector3(0.56, 0.52, 0.78)
	# The body under the shell, and the bony skirt round its rim.
	body.blob(Vector3(0, 0.45, 0.05), Vector3(0.46, 0.3, 0.66), bp, {"lat": 10, "lon": 14})
	var rim: Array = []; var rr: Array = []
	for k in range(25):
		var th := TAU * k / 24.0
		var pt: Array = on_dome(c, r, 1.42, th)
		rim.append(pt[0]); rr.append(0.06)
	body.tube(rim, rr, cp, {"sides": 7, "per": 2, "lump": 0.25})
	# The shell: a dome of basalt columns, split down the spine by a rift of lava.
	for i in range(1, 11):
		var phi := 1.42 * i / 10.0
		var ring := maxi(6, int(round(TAU * sin(phi) * 0.66 / 0.125)))
		for j in range(ring):
			var th := TAU * (j + 0.5 * (i % 2)) / ring
			var pt: Array = on_dome(c, r, phi, th)
			var at: Vector3 = pt[0]; var n: Vector3 = pt[1]
			if absf(at.x) < 0.07 and at.y > 0.75: continue
			var h := 0.03 + 0.09 * absf(Sculpt.noise(at * 7.0)) + (0.07 if absf(at.x) < 0.16 and at.y > 0.8 else 0.0)
			column(body, cp, at, n, 0.066, h, j * 0.7)
	part(root, "Shell", body)
	var lava := Sculpt.new(); var lw := lava.add_painter(func (p, n, v, w): return Color.WHITE)
	lava_cap(lava, lw, c, r, 1.42, 0.975)
	part(root, "Lava", lava, glow).material_override = glow

	# The head: short and deep, capped with a helmet of small columns.
	var head := joint(root, "Head", Vector3(0, 0.42, -0.72))
	var hs := Sculpt.new(); var hp := hs.add_painter(hide); var hc := hs.add_painter(basalt)
	hs.blob(Vector3(0, 0.42, -0.86), Vector3(0.17, 0.16, 0.17), hp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 0.4, -0.9), Vector3(0, 0.36, -1.02)], [0.12, 0.085], hp, {"sides": 12, "per": 2, "cap_len": 0.5})
	hs.blob(Vector3(0, 0.37, -1.06), Vector3(0.05, 0.035, 0.03), hs.add_painter(func (p, n, v, w): return Color("#120e0c")), {"lat": 4, "lon": 7})
	for k in range(9):
		var pt: Array = on_dome(Vector3(0, 0.44, -0.86), Vector3(0.17, 0.16, 0.17), 0.25 + 0.4 * (k % 3), TAU * k / 9.0 + PI)
		column(hs, hc, pt[0], pt[1], 0.045, 0.03, k)
	var core := _eyes(head, [Vector3(-0.11, 0.45, -0.95), Vector3(0.11, 0.45, -0.95)], 0.018)
	part(head, "Head", hs)
	var jaw := joint(head, "Jaw", Vector3(0, 0.33, -0.86))
	var js := Sculpt.new(); var jp := js.add_painter(hide)
	js.tube([Vector3(0, 0.33, -0.86), Vector3(0, 0.3, -1.0)], [0.1, 0.07], jp, {"sides": 10, "per": 2, "cap_len": 0.5})
	part(jaw, "Jaw", js)
	var legs := stout_legs(hide, 0.33, -0.42, 0.48, 0.42, 1.25, 5, 0.09)
	var tails := ringed_tail(Vector3(0, 0.42, 0.8), 4, Vector3(0, -0.04, 0.16), 0.13, basalt, true)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs.hips, "knees": legs.knees, "leaves": []}, 1.4)
	return _rig(node, head, legs.hips, legs.knees, jaw, tails)


# ------------------------------------------------------------------ B: basalt pangolin

## A pangolin scale: a broad, rounded shingle growing from `base` back along `along`, thin
## across `out`, its tip lifted a little off the scale beneath, its face grooved lengthwise
## like a real pangolin's.
func shingle(s: Sculpt, painter: int, base: Vector3, along: Vector3, out: Vector3, length: float, width: float, lift := 0.03) -> void:
	var a := along.normalized(); var o := out.normalized()
	var tip := base + a * length + o * lift
	s.tube([base - a * length * 0.05, base.lerp(tip, 0.45) + o * lift * 0.5, tip], [width * 0.65, width, width * 0.2], painter, {"sides": 6, "per": 1, "flat": 0.16, "side": o, "ridges": 3, "ridge": 0.08, "cap_len": 0.5, "cap_rings": 1})


## Pangolin scales in basalt: near-black, finely grooved, worn pale at the free edge.
static func scale_paint(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := basalt(p, n, v, w).lerp(Color("#2b292c"), 0.35)
	c = c.darkened(clampf(-w, 0.0, 1.0) * 0.3).lightened(clampf(w, 0.0, 1.0) * 0.06)
	return c.lerp(Color("#7f7b78"), smoothstep(0.75, 1.0, v) * 0.55)


## The bare skin of the belly, inner legs and face: ashy grey with a pinkish tinge.
static func belly(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#3e3836").lerp(Color("#5e504c"), clampf(Sculpt.fbm(p * 8.0) * 0.4 + 0.3 - n.y * 0.3, 0.0, 1.0)).darkened(smoothstep(0.6, 0.75, Sculpt.noise(p * 60.0)) * 0.2)


## A point along a spine path (t from 0 to 1): {centre, radius, direction}.
static func along_spine(spine: Array, rads: Array, t: float) -> Array:
	if t < 0.0:
		var d: Vector3 = (spine[1] as Vector3) - spine[0]
		return [(spine[0] as Vector3) + d * t * (spine.size() - 1), float(rads[0]) * (1.0 + t * 2.0), d.normalized()]
	var seg := clampf(t, 0.0, 0.999) * (spine.size() - 1); var k := int(seg)
	var ctr: Vector3 = (spine[k] as Vector3).lerp(spine[k + 1], seg - k)
	return [ctr, lerpf(rads[k], rads[k + 1], seg - k), ((spine[k + 1] as Vector3) - spine[k]).normalized()]


## A glowing crack across the face of a scale.
func scale_crack(s: Sculpt, painter: int, base: Vector3, along: Vector3, out: Vector3, length: float, side: Vector3) -> void:
	var o := out.normalized() * 0.022
	s.tube([base + o + along * length * 0.15, base + o * 1.5 + along * length * 0.45 + side * 0.02, base + o * 1.4 + along * length * 0.7 - side * 0.015, base + o * 1.1 + along * length * 0.9], [0.006, 0.01, 0.009, 0.003], painter, {"sides": 4, "per": 1, "cap_rings": 1})


# ------------------------------------------------------------------ B: basalt pangolin

func _pangolin() -> Node3D:
	# Built from the real animal: a small smooth tapered head running straight into a round,
	# arched body (highest over the hips); about eighteen rows of big overlapping scales that
	# point backwards and cover the back, flanks, the outsides of the legs and the whole top of
	# the tail, but not the face, belly or the inside of the legs; no external ears; tiny
	# heavy-lidded eyes; a very long sticky tongue; huge curved digging claws on the front feet
	# (the middle one biggest), folded so it walks on their outer edges; broad flat-soled hind
	# feet with short blunt claws; and a long, broad, flattened tail scaled to the tip.
	var body := Sculpt.new(); var bp := body.add_painter(belly); var sp := body.add_painter(scale_paint)
	var lava := Sculpt.new(); var lw := lava.add_painter(func (p, n, v, w): return Color.WHITE)
	var spine := [Vector3(0, 0.5, -0.58), Vector3(0, 0.64, -0.32), Vector3(0, 0.78, 0.0), Vector3(0, 0.84, 0.3), Vector3(0, 0.74, 0.6)]
	var rads := [0.19, 0.29, 0.35, 0.35, 0.26]
	body.tube(spine, rads.map(func (x): return float(x) * 0.95), bp, {"sides": 18, "per": 3})
	var rows := 18
	for i in range(-2, rows):
		var t := (i + 0.3) / float(rows)
		var sp_at: Array = along_spine(spine, rads, t)
		var ctr: Vector3 = sp_at[0]; var rad: float = sp_at[1]; var along: Vector3 = sp_at[2]
		var k2 := 0.78 + 0.4 * sin(PI * t)
		var count := 11 + int(round(5.0 * sin(PI * t)))
		var reach := 2.55 if t < 0.85 else 2.2
		# Lava under the lifted edges of the row in front.
		var arc: Array = []; var ar: Array = []
		for j in range(9):
			var a := lerpf(-reach - 0.05, reach + 0.05, j / 8.0)
			arc.append(ctr + Vector3(sin(a), cos(a), 0) * rad * 1.035); ar.append(0.026)
		if i >= 1: lava.tube(arc, ar, lw, {"sides": 4, "per": 1, "cap_rings": 1})
		for j in range(count):
			var a := lerpf(-reach, reach, (j + 0.5 * (i % 2)) / float(count))
			var out := Vector3(sin(a), cos(a), 0)
			var base := ctr + out * rad
			# Lie along the surface (which rises steeply over the shoulders), not the spine.
			var ahead: Array = along_spine(spine, rads, t + 0.03)
			var slope := ((ahead[0] as Vector3) + out * float(ahead[1]) - base).normalized() + out * 0.08
			shingle(body, sp, base, slope, out, 0.17 * k2, 0.075 * k2, 0.06)
			if (i * 7 + j * 3) % 5 == 0: scale_crack(lava, lw, base, slope.normalized(), out, 0.17 * k2, out.cross(along).normalized())
	part(root, "Body", body)

	# The head: small, smooth and tapering into a long snout, scaled over the crown.
	var head := joint(root, "Head", Vector3(0, 0.5, -0.6))
	var hs := Sculpt.new(); var hp := hs.add_painter(belly); var hsp := hs.add_painter(scale_paint)
	var nose := hs.add_painter(func (p, n, v, w): return Color("#1e1716").lightened(clampf(n.y, 0.0, 1.0) * 0.15))
	hs.tube([Vector3(0, 0.5, -0.55), Vector3(0, 0.46, -0.74), Vector3(0, 0.41, -0.9), Vector3(0, 0.37, -1.03)], [0.18, 0.125, 0.075, 0.045], hp, {"sides": 14, "per": 3, "cap_len": 0.5})
	hs.blob(Vector3(0, 0.368, -1.07), Vector3(0.035, 0.028, 0.022), nose, {"lat": 5, "lon": 8})
	for row in range(5):
		var z := -0.46 - row * 0.06
		var yc := 0.5 + (z + 0.55) * (0.21 if z < -0.55 else 0.5); var rc := 0.18 + (z + 0.55) * (0.29 if z < -0.55 else 0.5)
		var n := 8 - row
		for j in range(n):
			var a := lerpf(-1.5, 1.5, (j + 0.5 * (row % 2)) / float(n)) * (1.0 - row * 0.06)
			var out := Vector3(sin(a), cos(a), 0)
			shingle(hs, hsp, Vector3(sin(a) * rc * 1.04, yc + cos(a) * rc * 1.04, z), Vector3(0, 0.55, 1), out, 0.13 - row * 0.01, 0.065 - row * 0.006, 0.03)
	for side: float in [-1.0, 1.0]:
		# Small eyes on the sides of the head, in dark sockets under heavy lids.
		hs.blob(Vector3(0.088 * side, 0.488, -0.8), Vector3(0.03, 0.026, 0.034), hs.add_painter(func (p, n, v, w): return Color("#15100e")), {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.09 * side, 0.51, -0.8), Vector3(0.034, 0.014, 0.036), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.FORWARD, -0.35 * side)})
	var core := _eyes(head, [Vector3(-0.1, 0.49, -0.802), Vector3(0.1, 0.49, -0.802)], 0.02)
	part(head, "Head", hs)
	var jaw := joint(head, "Jaw", Vector3(0, 0.38, -0.9))
	var js := Sculpt.new(); var jt := js.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#8a2c2a").lerp(Color("#c4524a"), v))
	js.tube([Vector3(0, 0.36, -1.04), Vector3(0, 0.33, -1.16), Vector3(0.02, 0.26, -1.24), Vector3(0.0, 0.2, -1.27)], [0.012, 0.01, 0.007, 0.003], jt, {"sides": 6, "per": 3})
	part(jaw, "Tongue", js)

	# Legs: the front ones short with three great folded digging claws; the hind ones thick,
	# flat-soled, with five short blunt claws. Scales over the outside of each leg.
	var hips: Array = []; var knees: Array = []
	for row in [["Front", -0.32, true], ["Hind", 0.36, false]]:
		for side: float in [-1.0, 1.0]:
			var z: float = row[1]; var front: bool = row[2]
			var x := (0.21 if front else 0.23) * side
			var top := Vector3(x, 0.55 if front else 0.66, z)
			var hip := joint(root, str(row[0]) + ("Left" if side < 0 else "Right") + "Leg", top)
			var us := Sculpt.new(); var up := us.add_painter(belly); var usp := us.add_painter(scale_paint)
			var knee_at := Vector3(x * 1.15, 0.3 if front else 0.34, z + (-0.04 if front else -0.04))
			us.tube([top + Vector3(0, 0.08, 0), top.lerp(knee_at, 0.5), knee_at], [0.13 if front else 0.17, 0.11 if front else 0.14, 0.085], up, {"sides": 12, "per": 3})
			for k in range(6):
				var ang := (0.35 if k % 2 == 0 else -0.45)
				var out := Vector3(side * cos(ang), 0, sin(ang))
				var at := top.lerp(knee_at, 0.05 + int(k / 2) * 0.3) + out * (0.11 if k < 2 else 0.09)
				shingle(us, usp, at, Vector3(0, -1, 0.15), out, 0.14, 0.07, 0.025)
			part(hip, "Upper", us)
			var knee := joint(hip, "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(belly); var lsp := ls.add_painter(scale_paint); var cp := ls.add_painter(claw)
			if front:
				var wrist := Vector3(x * 1.2, 0.1, z - 0.06)
				ls.tube([knee_at, wrist], [0.08, 0.075], lp, {"sides": 12, "per": 2})
				for k in range(2):
					shingle(ls, lsp, knee_at + Vector3(0.065 * side, -0.02, -0.03 + k * 0.05), Vector3(0, -1, 0.2), Vector3(side, 0, -0.3 + k * 0.5), 0.13, 0.06, 0.02)
				ls.blob(wrist + Vector3(0, -0.035, -0.02), Vector3(0.08, 0.06, 0.08), lp, {"lat": 6, "lon": 9})
				for c in range(3):
					var off := c - 1.0
					var L := 0.22 if c == 1 else 0.15
					var at := wrist + Vector3(off * 0.04 * side, -0.01, -0.07)
					ls.tube([at, at + Vector3(off * 0.01, -0.02, -L * 0.5), at + Vector3(off * 0.015, -0.075, -L * 0.75), at + Vector3(off * 0.015, -0.09, -L * 0.55)], [0.026, 0.02, 0.01, 0.002], cp, {"sides": 7, "per": 3, "cap1": false})
			else:
				var heel := Vector3(x * 1.15, 0.07, z + 0.02)
				ls.tube([knee_at, heel + Vector3(0, 0.06, 0)], [0.09, 0.08], lp, {"sides": 12, "per": 2})
				ls.blob(Vector3(x * 1.15, 0.05, z - 0.08), Vector3(0.085, 0.05, 0.16), lp, {"lat": 6, "lon": 10})
				for c in range(5):
					var off := c - 2.0
					var at := Vector3(x * 1.15 + off * 0.03, 0.035, z - 0.22 + absf(off) * 0.025)
					ls.tube([at, at + Vector3(off * 0.008, -0.015, -0.04), at + Vector3(off * 0.01, -0.035, -0.06)], [0.016, 0.011, 0.003], cp, {"sides": 6, "per": 2, "cap1": false})
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)

	# The tail: long, broad and flat, scaled on top to the very tip with a saw-edge of scales
	# down each side, bare underneath, curving down to the ground.
	var tails: Array = []; var parent: Node3D = root; var at := Vector3(0, 0.72, 0.62)
	var steps := [Vector3(0, -0.03, 0.17), Vector3(0, -0.06, 0.17), Vector3(0, -0.08, 0.16), Vector3(0, -0.09, 0.15), Vector3(0, -0.08, 0.15), Vector3(0, -0.06, 0.14), Vector3(0, -0.04, 0.13)]
	for k in range(steps.size()):
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var ts := Sculpt.new(); var tp := ts.add_painter(belly); var tsp := ts.add_painter(scale_paint)
		var tl := Sculpt.new(); var tlw := tl.add_painter(func (p, n, v, w): return Color.WHITE)
		var dir: Vector3 = steps[k]; var next := at + dir
		var ra := lerpf(0.21, 0.05, float(k) / steps.size()); var rb := lerpf(0.21, 0.05, float(k + 1) / steps.size())
		ts.tube([at - dir * 0.15, at.lerp(next, 0.5), next + dir * 0.1], [ra, (ra + rb) * 0.5, rb], tp, {"sides": 12, "per": 2, "flat": 1.6, "cap1": k == steps.size() - 1})
		var r := (ra + rb) * 0.5
		for half in range(2):
			var mid := at.lerp(next, 0.05 + half * 0.5)
			var across := 6 if k < 4 else 4
			for j in range(across):
				var a := lerpf(-1.3, 1.3, (j + 0.5 * ((k * 2 + half) % 2)) / float(across))
				var out := Vector3(sin(a), cos(a), 0)
				shingle(ts, tsp, mid + Vector3(sin(a) * r * 1.5, cos(a) * r * 0.8, 0), dir + out * 0.1, out, 0.15 * (1.0 - k * 0.08), 0.06 * (1.0 - k * 0.07), 0.03)
		for side: float in [-1.0, 1.0]:
			shingle(ts, tsp, at.lerp(next, 0.4) + Vector3(side * r * 1.55, -0.01, 0), dir + Vector3(side * 0.6, -0.05, 0), Vector3(side * 0.2, 1, 0), 0.13 * (1.0 - k * 0.08), 0.055, 0.02)
		var arc: Array = []; var ar: Array = []
		for j in range(7):
			var a := lerpf(-1.3, 1.3, j / 6.0)
			arc.append(at + Vector3(sin(a) * ra * 1.5, cos(a) * ra * 0.78, 0)); ar.append(0.012)
		tl.tube(arc, ar, tlw, {"sides": 5, "per": 2})
		part(node, "Segment", ts)
		part(node, "Lava", tl, glow).material_override = glow
		tails.append(node); parent = node; at = next
	part(root, "Lava", lava, glow).material_override = glow
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.45)
	return _rig(node, head, hips, knees, jaw, tails)


# ------------------------------------------------------------------ C: volcano tortoise

func _tortoise() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(hide)
	var scute := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var cc := basalt(p, n, v, w)
		return cc.darkened(smoothstep(0.7, 0.95, absf(sin(v * 18.0))) * 0.35))
	var c := Vector3(0, 0.62, 0.05); var r := Vector3(0.58, 0.5, 0.72)
	body.blob(Vector3(0, 0.45, 0.05), Vector3(0.48, 0.28, 0.62), bp, {"lat": 10, "lon": 14})
	# Scutes: broad raised plates in rings, with lava between them; the front rim of the shell
	# lifts high over the neck, like a saddleback's.
	var plates := [[0.0, 0.0, 1]]
	for k in range(5): plates.append([0.55, TAU * k / 5.0, 0])
	for k in range(9): plates.append([1.05, TAU * (k + 0.5) / 9.0, 0])
	for k in range(13): plates.append([1.38, TAU * k / 13.0, 0])
	for pl in plates:
		var phi: float = pl[0]; var th: float = pl[1]
		var pt: Array = on_dome(c, r, phi, th)
		var at: Vector3 = pt[0]; var n: Vector3 = pt[1]
		if phi > 1.3 and sin(th) < -0.5: at.y += 0.06
		var size := 0.2 if phi < 1.2 else 0.16
		var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD).normalized()
		body.tube([at - n * 0.04, at + n * 0.035], [size, size * 0.86], scute, {"sides": 6, "per": 1, "cap_len": 0.08, "cap_rings": 2, "side": side, "facet": true})
	part(root, "Shell", body)
	var lava := Sculpt.new(); var lw := lava.add_painter(func (p, n, v, w): return Color.WHITE)
	lava_cap(lava, lw, c, r, 1.45, 0.975)
	# A volcano on the crown of the shell: a cone of basalt with a pool of lava in its crater,
	# lava spilling over the rim and running down between the scutes, and a column of smoke.
	var top := c + Vector3(0, r.y, 0)
	lava.lathe(top + Vector3(0, 0.225, 0), [Vector2(0, 0.012), Vector2(0.08, 0.008), Vector2(0.13, -0.005), Vector2(0.135, -0.03), Vector2(0, -0.03)], lw, {"sides": 14})
	for k in range(4):
		var th := TAU * (k + 0.5) / 5.0 + 0.2
		var pts: Array = []; var pr: Array = []
		# Over the lip of the crater and down the side of the cone...
		var dir := Vector3(cos(th), 0, sin(th))
		for j in range(4):
			var t := j / 3.0
			var rr := lerpf(0.12, 0.35, t)
			pts.append(top + dir * rr + Vector3(0, lerpf(0.225, -0.055, t) + 0.025, 0)); pr.append(lerpf(0.04, 0.036, t))
		# ...then down the shell between the scutes, thinning as it cools.
		for j in range(1, 7):
			var phi := lerpf(0.72, 1.32 - 0.12 * (k % 2), j / 6.0)
			var pt: Array = on_dome(c, r, phi, th + 0.12 * sin(j * 1.7 + k))
			pts.append((pt[0] as Vector3) + (pt[1] as Vector3) * 0.045); pr.append(lerpf(0.034, 0.018, j / 6.0))
		lava.tube(pts, pr, lw, {"sides": 6, "per": 2, "lump": 0.25})
		lava.blob((pts[-1] as Vector3) + Vector3(0, -0.03, 0), Vector3(0.025, 0.04, 0.025), lw, {"lat": 4, "lon": 6})
	part(root, "Lava", lava, glow).material_override = glow
	var vs := Sculpt.new(); var vp := vs.add_painter(basalt)
	vs.lathe(top + Vector3(0, 0.21, 0), [Vector2(0.11, 0.0), Vector2(0.15, 0.015), Vector2(0.3, -0.2), Vector2(0.36, -0.27), Vector2(0.0, -0.28)], vp, {"sides": 14, "wobble": 0.5})
	var smoke := vs.add_painter(func (p, n, v, w): return Color("#36322f").lerp(Color("#77716b"), clampf(n.y * 0.4 + 0.2, 0.0, 1.0)))
	for k in range(3):
		var drift := Vector3(0.05 * k, 0.0, 0.12 * k)
		vs.blob(top + Vector3(0, 0.32 + k * 0.13, 0) + drift, Vector3(1.0, 0.8, 1.1) * (0.08 + 0.04 * k), smoke, {"lat": 6, "lon": 9, "lump": 0.6})
	part(root, "Vent", vs)
	# A long leathery neck and a beaked head.
	var head := joint(root, "Head", Vector3(0, 0.5, -0.72))
	var hs := Sculpt.new(); var hp := hs.add_painter(hide); var beak := hs.add_painter(func (p, n, v, w): return Color("#1c1916").lightened(clampf(n.y, 0.0, 1.0) * 0.15))
	hs.tube([Vector3(0, 0.48, -0.6), Vector3(0, 0.55, -0.8), Vector3(0, 0.6, -0.95)], [0.12, 0.1, 0.095], hp, {"sides": 12, "per": 3, "lump": 0.12})
	hs.blob(Vector3(0, 0.62, -1.02), Vector3(0.1, 0.09, 0.12), hp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 0.6, -1.1), Vector3(0, 0.57, -1.15)], [0.06, 0.03], beak, {"sides": 8, "per": 2, "cap_len": 0.6})
	var core := _eyes(head, [Vector3(-0.07, 0.65, -1.07), Vector3(0.07, 0.65, -1.07)], 0.015)
	part(head, "Head", hs)
	var jaw := joint(head, "Jaw", Vector3(0, 0.58, -1.02))
	var js := Sculpt.new(); var jp := js.add_painter(func (p, n, v, w): return Color("#1c1916"))
	js.tube([Vector3(0, 0.57, -1.04), Vector3(0, 0.555, -1.13)], [0.05, 0.02], jp, {"sides": 8, "per": 2, "cap_len": 0.6})
	part(jaw, "Jaw", js)
	var legs := stout_legs(func (p, n, v, w): return hide(p, n, v, w).darkened(smoothstep(0.6, 0.8, Sculpt.noise(p * 25.0)) * 0.3), 0.36, -0.4, 0.42, 0.4, 1.3, 5, 0.06)
	# Big horny scales over the fronts of the forelegs, like a giant tortoise's, here in basalt.
	for k in range(2):
		var knee: Node3D = legs.knees[k]
		var side := -1.0 if k == 0 else 1.0
		var ks := Sculpt.new(); var kp := ks.add_painter(basalt)
		var kat := _world(knee)
		for j in range(6):
			var at := kat + Vector3(0.02 * side * (j % 2), -0.05 - j * 0.045, -0.12)
			ks.crystal(at, Vector3(0.3 * side, 0.4, -1.0), 0.06 + 0.02 * (j % 2), 0.035, kp, 5)
		part(knee, "Spurs", ks)
	var tails := ringed_tail(Vector3(0, 0.38, 0.72), 2, Vector3(0, -0.03, 0.1), 0.06, hide, false)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs.hips, "knees": legs.knees, "leaves": []}, 1.4)
	return _rig(node, head, legs.hips, legs.knees, jaw, tails)
