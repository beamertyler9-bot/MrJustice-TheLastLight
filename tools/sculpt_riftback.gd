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

func _pangolin() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(hide); var sp := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return basalt(p, n, v, w).lightened(smoothstep(0.7, 1.0, v) * 0.25))
	# An arched body, the scales overlapping from neck to rump like roof tiles.
	var spine := [Vector3(0, 0.55, -0.55), Vector3(0, 0.68, -0.25), Vector3(0, 0.72, 0.1), Vector3(0, 0.66, 0.45), Vector3(0, 0.52, 0.7)]
	var rads := [0.24, 0.32, 0.34, 0.31, 0.22]
	body.tube(spine, rads, bp, {"sides": 16, "per": 3, "flat": 0.9})
	var glow_s := Sculpt.new(); var gw := glow_s.add_painter(func (p, n, v, w): return Color.WHITE)
	for i in range(12):
		var t := i / 11.0
		var seg := t * 4.0; var k := mini(int(seg), 3)
		var ctr: Vector3 = (spine[k] as Vector3).lerp(spine[k + 1], seg - k)
		var rad: float = lerpf(rads[k], rads[k + 1], seg - k) * 1.04
		var along: Vector3 = ((spine[k + 1] as Vector3) - spine[k]).normalized()
		var count := 7 + int(4.0 * sin(PI * t))
		# Lava glowing in the seam under this row of scales.
		var arc: Array = []; var ar: Array = []
		for j in range(9):
			var a := lerpf(-1.9, 1.9, j / 8.0)
			arc.append(ctr + Vector3(sin(a) * rad * 0.9, cos(a) * rad, 0) * 1.0); ar.append(0.016)
		glow_s.tube(arc, ar, gw, {"sides": 5, "per": 2})
		for j in range(count):
			var a := lerpf(-2.0, 2.0, (j + 0.5 * (i % 2)) / float(count))
			if absf(a) < 0.16: continue
			var out := Vector3(sin(a) * 0.9, cos(a), 0).normalized()
			var at := ctr + Vector3(sin(a) * rad * 0.9, cos(a) * rad, 0)
			var bz := Basis(out.cross(along).normalized(), out, along.normalized())
			# A broad shingle with a pointed tip, lying back over the row behind it.
			var k2 := 0.85 + 0.35 * sin(PI * t)
			var base := at + out * 0.01
			var tip := base + along * 0.17 * k2 + out * 0.035
			var side_dir := out.cross(along).normalized()
			body.tube([base, base.lerp(tip, 0.45) + out * 0.025, tip], [0.075 * k2, 0.07 * k2, 0.006], sp, {"sides": 8, "per": 2, "flat": 0.22, "side": out, "cap1": false})
	# The rift: lava glowing along the spine where the two sides of the armour part.
	var ridge: Array = []; var rdg: Array = []
	for k in range(spine.size()):
		ridge.append((spine[k] as Vector3) + Vector3(0, float(rads[k]) * 1.0, 0)); rdg.append(0.03 if k in [0, 4] else 0.045)
	glow_s.tube(ridge, rdg, gw, {"sides": 7, "per": 4, "lump": 0.3})
	part(root, "Body", body)
	part(root, "Lava", glow_s, glow).material_override = glow
	# A small cone head with a long tapering snout, scaled over the crown.
	var head := joint(root, "Head", Vector3(0, 0.55, -0.6))
	var hs := Sculpt.new(); var hp := hs.add_painter(hide); var hsp := hs.add_painter(basalt)
	hs.tube([Vector3(0, 0.55, -0.6), Vector3(0, 0.5, -0.78), Vector3(0, 0.44, -0.95), Vector3(0, 0.4, -1.06)], [0.17, 0.12, 0.07, 0.04], hp, {"sides": 12, "per": 3, "cap_len": 0.5})
	for j in range(5):
		var z := -0.62 - j * 0.07
		hs.blob(Vector3(0, 0.62 - j * 0.03, z), Vector3(0.09 - j * 0.012, 0.02, 0.06), hsp, {"lat": 4, "lon": 8, "basis": Basis(Vector3.RIGHT, -0.4)})
	var core := _eyes(head, [Vector3(-0.08, 0.56, -0.75), Vector3(0.08, 0.56, -0.75)], 0.016)
	part(head, "Head", hs)
	var jaw := joint(head, "Jaw", Vector3(0, 0.47, -0.8))
	var js := Sculpt.new(); var jt := js.add_painter(func (p, n, v, w): return Color("#7a2a2a"))
	js.tube([Vector3(0, 0.41, -1.05), Vector3(0, 0.38, -1.15), Vector3(0, 0.33, -1.2)], [0.012, 0.009, 0.004], jt, {"sides": 5, "per": 2})
	part(jaw, "Tongue", js)
	var legs := stout_legs(hide, 0.24, -0.38, 0.45, 0.5, 0.95, 3, 0.16)
	# A long, thick tail armoured in scales, curling down to the ground.
	var tails := ringed_tail(Vector3(0, 0.5, 0.75), 6, Vector3(0, -0.06, 0.17), 0.2, func (p, n, v, w): return basalt(p, n, v, w), true)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs.hips, "knees": legs.knees, "leaves": []}, 1.4)
	return _rig(node, head, legs.hips, legs.knees, jaw, tails)


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
	# A small vent on the crown of the shell, glowing inside.
	lava.lathe(c + Vector3(0, r.y + 0.08, 0), [Vector2(0, 0.0), Vector2(0.06, 0.0), Vector2(0.065, -0.02), Vector2(0, -0.02)], lw, {"sides": 10})
	part(root, "Lava", lava, glow).material_override = glow
	var vs := Sculpt.new(); var vp := vs.add_painter(basalt)
	vs.lathe(c + Vector3(0, r.y + 0.06, 0), [Vector2(0.07, 0.04), Vector2(0.1, 0.03), Vector2(0.18, -0.06), Vector2(0.12, -0.08), Vector2(0.06, 0.0)], vp, {"sides": 12, "wobble": 0.4})
	var smoke := vs.add_painter(func (p, n, v, w): return Color("#6d6863").lerp(Color("#b0aaa3"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0)))
	for k in range(3): vs.blob(c + Vector3(0.02 * k, r.y + 0.14 + k * 0.09, 0.04 * k), Vector3.ONE * (0.05 + 0.025 * k), smoke, {"lat": 5, "lon": 8, "lump": 0.4})
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
	var tails := ringed_tail(Vector3(0, 0.38, 0.72), 2, Vector3(0, -0.03, 0.1), 0.06, hide, false)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs.hips, "knees": legs.knees, "leaves": []}, 1.4)
	return _rig(node, head, legs.hips, legs.knees, jaw, tails)
