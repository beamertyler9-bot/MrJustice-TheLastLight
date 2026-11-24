extends "res://tools/creature_kit.gd"
## The Dune Maw of the Sunspire Dunes, sculpted by hand: a huge burrower that travels under the
## sand and bursts out to bite. Three designs, each built on a real sand-dwelling animal:
##   antlion   - a giant antlion larva: a fat bristly abdomen, a flat head and enormous sickle
##               jaws lined with teeth, which it uses to seize prey from the bottom of its pit
##   sandfish  - a giant sandfish skink, the lizard that "swims" through dunes: a shovel snout,
##               a countersunk lower jaw, glossy banded scales and fringed toes
##   caecilian - a giant caecilian, the legless burrowing amphibian: a ringed body, a bullet
##               head with tiny eyes and sensory tentacles, and a powerful toothy jaw

const SAND := Color("#c9a96b")
const SAND_DARK := Color("#6b4d2c")
const SAND_PALE := Color("#eadcb8")
const TOOTH := Color("#efe6cf")
const MOUTH := Color("#4a1f1b")
const CHITIN := Color("#5a2e1c")


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	glow.albedo_color = Color("#ffb347").darkened(0.2); glow.emission = Color("#ffb347")
	glow.emission_energy_multiplier = 1.2


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "DuneMaw"
	match variant:
		"antlion": return _antlion()
		"sandfish": return _sandfish()
		"caecilian": return _caecilian()
		"sandworm": return _sandworm()
	return null


func _eyes(parent: Node3D, at: Array, size: float) -> MeshInstance3D:
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for p in at: es.blob(p, Vector3.ONE * size, white, {"lat": 4, "lon": 7})
	var core := part(parent, "GlowingEyes", es, glow)
	core.material_override = glow
	return core


func _rig(node: Node3D, head: Node3D, hips: Array, knees: Array, jaw: Node3D, tails: Array, pincers: Array = [], fronds: Array = []) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {}
	if jaw != null: features[&"jaw"] = node.get_path_to(jaw)
	if not pincers.is_empty(): features[&"pincers"] = paths.call(pincers)
	if not fronds.is_empty(): features[&"fronds"] = paths.call(fronds)
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tails), "features": features}
	node.set_meta("rig_bindings", rig)
	return node


# ------------------------------------------------------------------ A: antlion

func _antlion() -> Node3D:
	# Sandy, blotched with dark brown, so it vanishes against the sand at the bottom of its pit.
	var skin := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := SAND.lerp(SAND_DARK, clampf(n.y * 0.3 + Sculpt.fbm(p * 4.0) * 0.6 + 0.1, 0.0, 1.0))
		c = c.lerp(Color("#3e2a19"), smoothstep(0.32, 0.45, Sculpt.noise(p * 11.0)) * 0.75)
		# Paired dark spots down the back of each abdominal segment, and a dark V on the head.
		if p.z > 0.05: c = c.lerp(Color("#2e1f13"), smoothstep(0.5, 0.85, sin(p.z * 23.0)) * smoothstep(0.07, 0.03, absf(absf(p.x) - 0.14)) * smoothstep(0.2, 0.6, n.y) * 0.85)
		if p.z < -0.38: c = c.lerp(Color("#2e1f13"), smoothstep(0.03, 0.012, absf(absf(p.x) - (p.z + 0.68) * 0.55)) * smoothstep(0.3, 0.7, n.y) * 0.8)
		return c.lerp(SAND_PALE, smoothstep(-0.3, -0.8, n.y) * 0.5)
	var bristle := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#3a2817").lerp(Color("#c9a66d"), v)
	var body := Sculpt.new(); var bp := body.add_painter(skin); var br := body.add_painter(bristle)
	# A narrow neck and thorax.
	body.tube([Vector3(0, 0.3, -0.42), Vector3(0, 0.32, -0.25), Vector3(0, 0.34, -0.02)], [0.13, 0.2, 0.26], bp, {"sides": 14, "per": 3, "flat": 1.25, "bands": 2, "band": 0.08})
	var tail := joint(root, "Tail", Vector3(0, 0.36, 0.05))
	var ab := Sculpt.new(); var ap := ab.add_painter(skin); var abr := ab.add_painter(bristle)
	# The huge round abdomen, ringed with segments and bristling with stiff hairs.
	ab.tube([Vector3(0, 0.34, 0.0), Vector3(0, 0.42, 0.25), Vector3(0, 0.41, 0.55), Vector3(0, 0.34, 0.85), Vector3(0, 0.27, 1.02)], [0.25, 0.4, 0.42, 0.32, 0.1], ap, {"sides": 18, "per": 3, "flat": 1.2, "bands": 7, "band": 0.06})
	for k in range(120):
		var t := float(k) / 120.0
		var z := lerpf(0.05, 0.95, t)
		var ang := lerpf(-1.9, 1.9, fposmod(k * 0.618034 + Sculpt.noise(Vector3(k, 1, 3)) * 0.2, 1.0))
		var r := 0.44 * sin(clampf(z / 1.0, 0.05, 0.95) * PI) * 0.98 + 0.03
		var at := Vector3(sin(ang) * r * 1.2, 0.38 + cos(ang) * r, z)
		thorn(ab, abr, at, Vector3(sin(ang) * 1.2, cos(ang), 0.7), 0.13 + 0.07 * absf(Sculpt.noise(at * 9.0)), 0.013)
	# Rows of warty tubercles along the flanks, each sprouting a tuft of bristles.
	for k in range(6):
		var z := 0.14 + k * 0.14
		var r := 0.42 * sin(clampf(z, 0.05, 0.95) * PI) + 0.02
		for side in [-1.0, 1.0]:
			var at := Vector3(side * r * 1.18, 0.33, z)
			ab.blob(at, Vector3(0.05, 0.045, 0.05), ap, {"lat": 4, "lon": 7})
			for b in range(4):
				var a := b * 1.57 + k
				thorn(ab, abr, at + Vector3(side * 0.03, 0, 0), Vector3(side, cos(a) * 0.6, sin(a) * 0.6 + 0.3), 0.12, 0.01)
	var head := joint(root, "Head", Vector3(0, 0.29, -0.42))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin); var hb := hs.add_painter(bristle)
	# A flat, square head.
	hs.tube([Vector3(0, 0.3, -0.4), Vector3(0, 0.29, -0.55), Vector3(0, 0.27, -0.66)], [0.14, 0.15, 0.13], hp, {"sides": 12, "per": 2, "flat": 1.7, "square": 0.6, "cap_len": 0.4})
	for k in range(10):
		var x := (k - 4.5) * 0.04
		thorn(hs, hb, Vector3(x, 0.38, -0.5 + absf(x) * 0.2), Vector3(x * 2.0, 1.0, 0.6), 0.07, 0.008)
	var eye_at: Array = []
	for side in [-1.0, 1.0]:
		# Little clusters of eyes on bumps at the front corners.
		hs.blob(Vector3(0.19 * side, 0.33, -0.6), Vector3(0.045, 0.04, 0.045), hp, {"lat": 4, "lon": 7})
		for e in [Vector3(0.2, 0.37, -0.62), Vector3(0.225, 0.345, -0.59), Vector3(0.18, 0.36, -0.575), Vector3(0.215, 0.375, -0.585), Vector3(0.19, 0.34, -0.635), Vector3(0.23, 0.36, -0.615)]:
			eye_at.append(Vector3(e.x * side, e.y, e.z))
	part(head, "Head", hs)
	var core := _eyes(head, eye_at, 0.017)
	# The sickle jaws: long, curved, hollow mandibles with three sharp teeth on the inside.
	var jaws: Array = []
	for side in [-1.0, 1.0]:
		var hinge := joint(head, "LeftJaw" if side < 0 else "RightJaw", Vector3(0.13 * side, 0.28, -0.64))
		var js := Sculpt.new()
		var cp := js.add_painter(func (p, n, v, w): return CHITIN.lerp(Color("#1c120c"), v).lightened(clampf(n.y, 0.0, 1.0) * 0.18))
		var tp := js.add_painter(func (p, n, v, w): return TOOTH.darkened(0.1 + v * 0.2))
		var path := [Vector3(0.13 * side, 0.28, -0.64), Vector3(0.25 * side, 0.29, -0.84), Vector3(0.26 * side, 0.3, -1.05), Vector3(0.18 * side, 0.3, -1.24), Vector3(0.05 * side, 0.29, -1.32)]
		js.tube(path, [0.075, 0.062, 0.048, 0.03, 0.005], cp, {"sides": 8, "per": 3, "flat": 0.7, "side": Vector3.UP, "cap1": false})
		for k in range(3):
			var at: Vector3 = (path[k + 1] as Vector3).lerp(path[k + 2], 0.3)
			js.crystal(at + Vector3(-0.02 * side, 0, 0), Vector3(-side, 0, -0.3), 0.08 - k * 0.012, 0.016, tp, 5)
		# Stiff bristles along the outer edge of each jaw.
		var bp2 := js.add_painter(bristle)
		for k in range(5):
			var at: Vector3 = (path[1] as Vector3).lerp(path[3], k / 4.0)
			thorn(js, bp2, at + Vector3(0.03 * side, 0.01, 0), Vector3(side, 0.4, 0.3), 0.07, 0.007)
		part(hinge, "Mandible", js)
		jaws.append(hinge)
	# Six short legs, the front ones reaching forward.
	var hips: Array = []; var knees: Array = []
	for row in [[-0.32, -0.6], [-0.18, -0.1], [-0.04, 0.35]]:
		for side in [-1.0, 1.0]:
			var z: float = row[0]; var lean: float = row[1]
			var hip_at := Vector3(0.17 * side, 0.24, z)
			var knee_at := Vector3(0.33 * side, 0.27, z + lean * 0.2)
			var foot := Vector3(0.38 * side, 0.03, z + lean * 0.35)
			var hip := joint(root, "Leg%d%s" % [hips.size() / 2, "Left" if side < 0 else "Right"], hip_at)
			var us := Sculpt.new(); var up := us.add_painter(skin)
			us.tube([hip_at, hip_at.lerp(knee_at, 0.5) + Vector3(0, 0.03, 0), knee_at], [0.06, 0.05, 0.045], up, {"sides": 7, "per": 2})
			part(hip, "Upper", us)
			var knee := joint(hip, "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cl := ls.add_painter(func (p, n, v, w): return Color("#2a1a10"))
			ls.tube([knee_at, knee_at.lerp(foot, 0.5), foot + Vector3(0, 0.02, 0)], [0.045, 0.036, 0.028], lp, {"sides": 7, "per": 2})
			ls.crystal(foot + Vector3(0, 0.01, 0), Vector3(side * 0.3, -0.6, lean - 0.3), 0.06, 0.012, cl, 4)
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)
	part(root, "Body", body)
	part(tail, "Abdomen", ab)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": [tail]}, 1.9)
	return _rig(node, head, hips, knees, null, [tail], jaws)


# ------------------------------------------------------------------ B: sandfish skink

## Legs for a sprawling lizard: the upper limb reaches out sideways to the elbow or knee, the
## lower limb plants down to a flat foot with five long clawed toes spread wide.
func lizard_legs(skin: Callable, rows: Array, thick := 1.0) -> Dictionary:
	var hips: Array = []; var knees: Array = []
	for row in rows:
		for side in [-1.0, 1.0]:
			var front: bool = row[0] == "Front"
			var hip_at := Vector3(0.22 * side, row[2], row[1])
			var elbow := Vector3(0.48 * side, float(row[2]) - 0.03, float(row[1]) + (0.02 if front else 0.1))
			var wrist := Vector3(0.53 * side, 0.09, float(row[1]) + (-0.04 if front else 0.14))
			var hip := joint(root, str(row[0]) + ("Left" if side < 0 else "Right") + "Leg", hip_at)
			var us := Sculpt.new(); var up := us.add_painter(skin)
			us.tube([hip_at - Vector3(0.06 * side, 0, 0), hip_at.lerp(elbow, 0.5) + Vector3(0, 0.035, 0), elbow], [(0.1 if front else 0.13) * thick, 0.085 * thick, 0.07 * thick], up, {"sides": 10, "per": 3})
			part(hip, "UpperLeg", us)
			var knee := joint(hip, "Elbow" if front else "Knee", elbow)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cl := ls.add_painter(func (p, n, v, w): return Color("#2a2018").lerp(Color("#c8b48a"), v))
			ls.tube([elbow, elbow.lerp(wrist, 0.5) + Vector3(0.02 * side, 0, 0), wrist + Vector3(0, 0.03, 0)], [0.07 * thick, 0.058 * thick, 0.05 * thick], lp, {"sides": 9, "per": 3})
			ls.blob(wrist + Vector3(0, -0.02, -0.02), Vector3(0.07, 0.035, 0.07) * thick, lp, {"lat": 5, "lon": 8})
			for t in range(5):
				var ang := lerpf(-1.1, 0.9, t / 4.0) if front else lerpf(-0.6, 1.6, t / 4.0)
				var dir := Vector3(sin(ang) * side, 0, -cos(ang))
				var length := 0.12 + 0.05 * sin(float(t) / 4.0 * PI) + (0.04 if not front and t == 3 else 0.0)
				var toe := wrist + Vector3(0, -0.02, 0) + dir * 0.04
				ls.tube([toe, toe + dir * length * 0.6 + Vector3(0, 0.012, 0), toe + dir * length + Vector3(0, -0.015, 0)], [0.022 * thick, 0.017 * thick, 0.012 * thick], lp, {"sides": 5, "per": 2, "cap_rings": 1})
				ls.crystal(toe + dir * length, dir + Vector3(0, -0.5, 0), 0.05 * thick, 0.01 * thick, cl, 4)
			part(knee, "LowerLeg", ls)
			hips.append(hip); knees.append(knee)
	return {"hips": hips, "knees": knees}


## A giant sandfish skink, built as a proper lizard: a thick scaly body held up on bent,
## sprawling legs, a distinct neck, a long head with brow ridges, ear openings and a forked
## tongue flicking from its open jaws, and a long tapering tail.
func _sandfish() -> Node3D:
	material.roughness = 0.6
	# Golden-sand scales picked out one by one, dark brown cross-bands over the back and tail,
	# a row of dark flecks along each flank and a cream belly.
	var scales := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#d7b060").lerp(Color("#a67d3e"), clampf(n.y * 0.4 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
		var band := sin(p.z * 7.5 + Sculpt.fbm(p * 2.0) * 1.0)
		c = c.lerp(Color("#4a2e17"), smoothstep(0.45, 0.62, band) * smoothstep(-0.25, 0.25, n.y) * 0.9)
		c = c.lerp(Color("#3b2512"), smoothstep(0.35, 0.5, Sculpt.noise(p * 16.0)) * smoothstep(0.6, 0.2, absf(n.y)) * 0.5)
		var u := p.z * 18.0; var q := p.x * 14.0 + p.y * 9.0 + (0.5 if fposmod(u, 2.0) > 1.0 else 0.0)
		var cell := Vector2(fposmod(u, 1.0) - 0.5, fposmod(q, 1.0) - 0.5).length()
		c = c.darkened(smoothstep(0.36, 0.5, cell) * 0.35).lightened(smoothstep(0.25, 0.0, cell) * 0.08)
		return c.lerp(Color("#f1e5c7"), smoothstep(-0.25, -0.65, n.y) * 0.85)
	var body := Sculpt.new(); var bp := body.add_painter(scales); var ridge := body.add_painter(func (p, n, v, w): return Color("#5b3c1f").lerp(Color("#b48a4a"), n.y * 0.5))
	body.tube([Vector3(0, 0.5, -0.4), Vector3(0, 0.54, -0.1), Vector3(0, 0.51, 0.3), Vector3(0, 0.46, 0.6)], [0.25, 0.3, 0.3, 0.25], bp, {"sides": 18, "per": 3, "flat": 1.15})
	body.tube([Vector3(0, 0.53, -0.36), Vector3(0, 0.56, -0.52), Vector3(0, 0.58, -0.64)], [0.24, 0.2, 0.17], bp, {"sides": 16, "per": 3, "flat": 1.1})
	# A row of raised keeled scales down the spine.
	for k in range(16):
		var z := -0.55 + k * 0.075
		var y := 0.83 - absf(z + 0.05) * 0.1 if z < 0.3 else 0.8 - (z - 0.3) * 0.25
		body.rock(Vector3(0, y - 0.03, z), Vector3(0.03, 0.03, 0.04), ridge, {"lat": 3, "lon": 5, "lump": 0.2})
	var tails: Array = []
	var parent: Node3D = root
	var at := Vector3(0, 0.45, 0.58)
	for k in range(7):
		var step := Vector3(0.05 * sin(k * 0.8), -0.035, 0.34)
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var r0: float = lerpf(0.25, 0.02, pow(float(k) / 7.0, 0.75)); var r1: float = lerpf(0.25, 0.02, pow(float(k + 1) / 7.0, 0.75))
		var ts := Sculpt.new(); var tp := ts.add_painter(scales)
		var next := at + step
		ts.tube([at - step * 0.15, at.lerp(next, 0.5), next + step * 0.12], [r0 * 1.02, (r0 + r1) * 0.5, r1], tp, {"sides": 14, "per": 2, "flat": 1.1, "cap1": k == 6})
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	var head := joint(root, "Head", Vector3(0, 0.58, -0.64))
	var hs := Sculpt.new(); var hp := hs.add_painter(scales); var dark := hs.add_painter(func (p, n, v, w): return Color("#1d1510"))
	var tooth := hs.add_painter(func (p, n, v, w): return TOOTH); var mouth := hs.add_painter(func (p, n, v, w): return MOUTH)
	# A long, wedge-snouted lizard head with heavy brow ridges.
	hs.tube([Vector3(0, 0.6, -0.6), Vector3(0, 0.63, -0.78), Vector3(0, 0.59, -0.98), Vector3(0, 0.53, -1.12), Vector3(0, 0.5, -1.17)], [0.17, 0.17, 0.125, 0.07, 0.02], hp, {"sides": 16, "per": 3, "flat": 1.15, "square": 0.3, "cap1": false})
	hs.blob(Vector3(0, 0.55, -0.74), Vector3(0.16, 0.06, 0.16), hp, {"lat": 5, "lon": 10})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.115 * side, 0.7, -0.83), Vector3(0.065, 0.028, 0.075), hp, {"lat": 4, "lon": 8, "basis": Basis(Vector3.FORWARD, side * 0.3)})
		hs.blob(Vector3(0.142 * side, 0.645, -0.85), Vector3(0.042, 0.038, 0.042), dark, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.035 * side, 0.565, -1.12), Vector3(0.014, 0.01, 0.014), dark, {"lat": 3, "lon": 6})
		hs.blob(Vector3(0.16 * side, 0.58, -0.66), Vector3(0.012, 0.025, 0.02), dark, {"lat": 3, "lon": 6})
		for k in range(7):
			hs.crystal(Vector3((0.15 - k * 0.018) * side, 0.52, -0.74 - k * 0.055), Vector3(0, -1, -0.1), 0.06, 0.012, tooth, 4)
	hs.blob(Vector3(0, 0.51, -0.86), Vector3(0.12, 0.02, 0.2), mouth, {"lat": 4, "lon": 9})
	part(head, "Head", hs)
	var core := _eyes(head, [Vector3(-0.158, 0.648, -0.862), Vector3(0.158, 0.648, -0.862)], 0.03)
	var jaw := joint(head, "Jaw", Vector3(0, 0.5, -0.64))
	var js := Sculpt.new(); var jp := js.add_painter(scales); var jt := js.add_painter(func (p, n, v, w): return TOOTH)
	var jm := js.add_painter(func (p, n, v, w): return MOUTH); var tongue := js.add_painter(func (p, n, v, w): return Color("#9c2a3a").lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	js.tube([Vector3(0, 0.51, -0.62), Vector3(0, 0.48, -0.9), Vector3(0, 0.49, -1.1)], [0.15, 0.11, 0.045], jp, {"sides": 14, "per": 3, "flat": 1.25, "cap_len": 0.5})
	js.blob(Vector3(0, 0.52, -0.86), Vector3(0.1, 0.02, 0.2), jm, {"lat": 4, "lon": 9})
	for side in [-1.0, 1.0]:
		for k in range(6):
			js.crystal(Vector3((0.13 - k * 0.017) * side, 0.525, -0.76 - k * 0.055), Vector3(0, 1, -0.1), 0.05, 0.011, jt, 4)
	# The forked tongue, flicking out to taste the air.
	js.tube([Vector3(0, 0.53, -0.85), Vector3(0, 0.53, -1.05), Vector3(0, 0.52, -1.22)], [0.018, 0.016, 0.012], tongue, {"sides": 6, "per": 2, "flat": 0.5, "side": Vector3.UP})
	for side in [-1.0, 1.0]:
		js.tube([Vector3(0, 0.52, -1.21), Vector3(0.03 * side, 0.515, -1.29), Vector3(0.05 * side, 0.505, -1.33)], [0.011, 0.007, 0.002], tongue, {"sides": 5, "per": 2, "cap1": false})
	part(jaw, "Jaw", js).rotation.x = -0.3
	var leg_rig := lizard_legs(scales, [["Front", -0.32, 0.5], ["Hind", 0.42, 0.47]])
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": leg_rig.hips, "knees": leg_rig.knees, "leaves": tails}, 1.7)
	return _rig(node, head, [], [], jaw, tails)


# ------------------------------------------------------------------ C: caecilian

func _caecilian() -> Node3D:
	# Smooth sand-coloured skin ringed by darker grooves (annuli), paler underneath.
	var ringed := func (bands: float) -> Callable:
		return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var c := Color("#b8946c").lerp(Color("#5e4735"), clampf(n.y * 0.5 + Sculpt.fbm(p * 4.0) * 0.5 + 0.15, 0.0, 1.0))
			c = c.lerp(Color("#3a2a1f"), smoothstep(0.3, 0.45, Sculpt.noise(p * 7.0)) * smoothstep(0.0, 0.5, n.y) * 0.6)
			c = c.lerp(Color("#ead9bd"), smoothstep(-0.2, -0.7, n.y) * 0.7)
			if bands <= 0.0: return c
			var ring := fposmod(v * bands, 1.0)
			c = c.darkened(smoothstep(0.1, 0.0, ring) * 0.45 + smoothstep(0.9, 1.0, ring) * 0.45)
			return c.darkened(smoothstep(0.04, 0.0, absf(ring - 0.5)) * 0.25)
	var skin: Callable = ringed.call(9.0)
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	# The front of the body rears up a little behind the head.
	body.tube([Vector3(0, 0.62, -0.5), Vector3(0, 0.55, -0.2), Vector3(0, 0.42, 0.15), Vector3(0, 0.36, 0.5)], [0.3, 0.33, 0.34, 0.33], bp, {"sides": 18, "per": 3, "flat": 1.05, "bands": 9, "band": 0.07})
	var tails: Array = []
	var parent: Node3D = root
	var at := Vector3(0, 0.36, 0.48)
	for k in range(8):
		var step := Vector3(0.13 * sin(k * 0.9 + 0.4), -0.01, 0.4)
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var r0: float = lerpf(0.33, 0.14, float(k) / 8.0); var r1: float = lerpf(0.33, 0.14, float(k + 1) / 8.0)
		var ts := Sculpt.new(); var tp := ts.add_painter(ringed.call(3.0))
		var next := at + step
		ts.tube([at - step * 0.1, at.lerp(next, 0.5), next + step * 0.1], [r0 * 1.02, (r0 + r1) * 0.5, r1], tp, {"sides": 16, "per": 2, "flat": 1.05, "bands": 3, "band": 0.07, "cap1": k == 7, "cap_len": 0.6})
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	# A blunt bullet head of thick bone for ramming through sand, with tiny eyes under the skin
	# and a sensory tentacle between eye and nostril.
	var head := joint(root, "Head", Vector3(0, 0.64, -0.55))
	var hs := Sculpt.new(); var hp := hs.add_painter(ringed.call(0.0)); var dark := hs.add_painter(func (p, n, v, w): return Color("#2b1c12"))
	var tooth := hs.add_painter(func (p, n, v, w): return TOOTH.darkened(v * 0.1))
	hs.tube([Vector3(0, 0.66, -0.5), Vector3(0, 0.68, -0.78), Vector3(0, 0.64, -1.0), Vector3(0, 0.58, -1.12)], [0.29, 0.27, 0.2, 0.09], hp, {"sides": 16, "per": 3, "flat": 1.15, "cap_len": 0.7})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.07 * side, 0.6, -1.15), Vector3(0.016, 0.01, 0.012), dark, {"lat": 3, "lon": 6})
		hs.tube([Vector3(0.15 * side, 0.63, -1.0), Vector3(0.18 * side, 0.62, -1.05), Vector3(0.19 * side, 0.6, -1.08)], [0.016, 0.012, 0.006], hp, {"sides": 5, "per": 2, "cap_rings": 1})
		# Two rows of long, backward-curving teeth along the upper jaw.
		for k in range(7):
			var z := -0.66 - k * 0.065
			var x: float = (0.25 - k * 0.022) * side
			hs.crystal(Vector3(x, 0.52, z), Vector3(0, -1, 0.35), 0.1 - k * 0.006, 0.016, tooth, 5)
			hs.crystal(Vector3(x * 0.8, 0.53, z - 0.02), Vector3(0, -1, 0.3), 0.07, 0.012, tooth, 5)
	hs.blob(Vector3(0, 0.53, -0.82), Vector3(0.22, 0.02, 0.24), hs.add_painter(func (p, n, v, w): return MOUTH), {"lat": 4, "lon": 10})
	part(head, "Head", hs)
	var core := _eyes(head, [Vector3(-0.225, 0.74, -0.94), Vector3(0.225, 0.74, -0.94)], 0.024)
	var jaw := joint(head, "Jaw", Vector3(0, 0.5, -0.55))
	var js := Sculpt.new(); var jp := js.add_painter(skin); var jt := js.add_painter(func (p, n, v, w): return TOOTH)
	var jm := js.add_painter(func (p, n, v, w): return MOUTH)
	js.tube([Vector3(0, 0.5, -0.55), Vector3(0, 0.46, -0.85), Vector3(0, 0.48, -1.08)], [0.22, 0.17, 0.07], jp, {"sides": 14, "per": 3, "flat": 1.35, "cap_len": 0.5})
	js.blob(Vector3(0, 0.52, -0.82), Vector3(0.18, 0.02, 0.22), jm, {"lat": 4, "lon": 10})
	for side in [-1.0, 1.0]:
		for k in range(6):
			js.crystal(Vector3((0.21 - k * 0.022) * side, 0.52, -0.7 - k * 0.065), Vector3(0, 1, 0.3), 0.08, 0.014, jt, 5)
	part(jaw, "Jaw", js).rotation.x = -0.28
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": tails}, 1.6)
	return _rig(node, head, [], [], jaw, tails)


# ------------------------------------------------------------------ D: sandworm

## The Dune Maw as a true sand worm: a vast, crusted, ring-armoured body that rears out of the
## dunes, with no face at all - just a round mouth that splits into four toothed petals, a
## throat lined with ring after ring of hooked teeth, and a sickly glow deep inside.
func _sandworm() -> Node3D:
	var crusted := func (bands: float) -> Callable:
		return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var c := Color("#c2a06c").lerp(Color("#7a5c38"), clampf(n.y * 0.25 + Sculpt.fbm(p * 3.5) * 0.7 + 0.2, 0.0, 1.0))
			c = c.lerp(Color("#3d2b1a"), smoothstep(0.38, 0.55, Sculpt.noise(p * 9.0)) * 0.55)
			c = c.lightened(smoothstep(0.42, 0.6, Sculpt.noise(p * 23.0 + Vector3(4, 1, 2))) * 0.15)
			c = c.lerp(Color("#e3d2ad"), smoothstep(-0.3, -0.8, n.y) * 0.5)
			if bands <= 0.0: return c
			var ring := fposmod(v * bands, 1.0)
			return c.darkened(smoothstep(0.14, 0.0, ring) * 0.55 + smoothstep(0.86, 1.0, ring) * 0.55)
	var spine := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#2a1d12").lerp(Color("#9c7c50"), v)
	var body := Sculpt.new(); var bp := body.add_painter(crusted.call(8.0)); var sp := body.add_painter(spine)
	# The front of the body rears up out of the sand towards the mouth.
	var path := [Vector3(0, 0.44, 0.55), Vector3(0, 0.5, 0.2), Vector3(0, 0.7, -0.22), Vector3(0, 0.94, -0.52)]
	body.tube(path, [0.44, 0.45, 0.46, 0.47], bp, {"sides": 22, "per": 3, "bands": 8, "band": 0.09, "lump": 0.07, "cap0": false, "cap1": false})
	# Rows of short dark spines along the back and flanks.
	for k in range(9):
		var t := float(k) / 8.0
		var c: Vector3 = (path[0] as Vector3).lerp(path[3], t)
		for a in [-1.1, -0.55, 0.0, 0.55, 1.1]:
			var dir := Vector3(sin(a), cos(a), 0.15 - t * 0.3).normalized()
			thorn(body, sp, c + dir * 0.44, dir + Vector3(0, 0, 0.6), 0.08 + 0.03 * absf(Sculpt.noise(c * 7.0 + Vector3(a, 0, 0))), 0.016)
	var tails: Array = []
	var parent: Node3D = root
	var at := Vector3(0, 0.44, 0.52)
	for k in range(8):
		var step := Vector3(0.12 * sin(k * 0.85 + 0.5), -0.01, 0.42)
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var r0: float = lerpf(0.44, 0.12, float(k) / 8.0); var r1: float = lerpf(0.44, 0.12, float(k + 1) / 8.0)
		var ts := Sculpt.new(); var tp := ts.add_painter(crusted.call(3.0)); var tsp := ts.add_painter(spine)
		var next := at + step
		ts.tube([at - step * 0.12, at.lerp(next, 0.5), next + step * 0.1], [r0 * 1.02, (r0 + r1) * 0.5, r1], tp, {"sides": 18, "per": 2, "bands": 3, "band": 0.09, "lump": 0.07, "cap1": k == 7, "cap_len": 0.5})
		for a in [-0.6, 0.0, 0.6]:
			var dir := Vector3(sin(a), cos(a), 0.0)
			thorn(ts, tsp, at.lerp(next, 0.5) + dir * (r0 + r1) * 0.48, dir + Vector3(0, 0, 0.6), 0.06, 0.012)
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	# The mouth: the body flares into a thick rim that splits into four petals.
	var mc := Vector3(0, 1.04, -0.74)
	var head := joint(root, "Head", Vector3(0, 0.98, -0.6))
	var hs := Sculpt.new(); var hp := hs.add_painter(crusted.call(2.0))
	hs.tube([Vector3(0, 0.92, -0.5), Vector3(0, 0.99, -0.62), mc], [0.47, 0.5, 0.52], hp, {"sides": 22, "per": 3, "bands": 2, "band": 0.08, "lump": 0.06, "cap0": false, "cap1": false})
	part(head, "Head", hs)
	# The throat, lined with rings of hooked teeth all raking inward; drawn double-sided so it
	# reads from inside the mouth.
	var throat_mat: StandardMaterial3D = material.duplicate()
	throat_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var th := Sculpt.new()
	var flesh := th.add_painter(func (p, n, v, w): return Color("#5a1d22").lerp(Color("#1a0709"), v).lightened(smoothstep(0.5, 0.9, sin(v * 40.0)) * 0.12))
	var fang := th.add_painter(func (p, n, v, w): return Color("#efe3c3").darkened((1.0 - v) * 0.45))
	var axis := Vector3(0, 0.18, 1).normalized()
	th.tube([mc - axis * 0.02, mc + axis * 0.22, mc + axis * 0.5], [0.49, 0.38, 0.2], flesh, {"sides": 22, "per": 2, "cap0": false, "cap_len": 0.6})
	for ring in range(4):
		var depth := 0.03 + ring * 0.1
		var r := 0.47 - ring * 0.07
		var count := 18 - ring * 2
		for k in range(count):
			var a := TAU * (k + ring * 0.5) / count
			var radial := Vector3(cos(a), sin(a), 0)
			var base := mc + axis * depth + radial * r
			th.crystal(base, -radial + axis * 0.75, 0.13 - ring * 0.02, 0.02, fang, 4)
	part(head, "Throat", th, throat_mat)
	# A sickly ember glow deep in the throat.
	glow.albedo_color = Color("#8a2a12"); glow.emission = Color("#ff5a1f"); glow.emission_energy_multiplier = 0.8
	var core := _eyes(head, [mc + axis * 0.5], 0.08)
	# Four petals that peel back from the mouth, each lined with teeth on its inner face.
	var petals: Array = []
	var jaw: Node3D = null
	for k in range(4):
		var a := PI * 0.5 + k * PI * 0.5
		var radial := Vector3(cos(a), sin(a), 0)
		var base := mc + radial * 0.48
		var name := "Petal%d" % k
		var hinge := joint(head, name, base)
		var ps := Sculpt.new(); var pp := ps.add_painter(crusted.call(0.0)); var inner := ps.add_painter(func (p, n, v, w): return Color("#6b2a2a").lerp(Color("#2a0d0e"), v))
		var pf := ps.add_painter(func (p, n, v, w): return Color("#efe3c3").darkened((1.0 - v) * 0.4))
		var fwd := Vector3(0, -0.05, -1)
		# Each petal arches out and forward, then hooks back in at the tip like a claw.
		var pts := [base, base + radial * 0.13 + fwd * 0.24, base + radial * 0.2 + fwd * 0.48, base + radial * 0.08 + fwd * 0.66]
		var tangent := radial.cross(Vector3(0, 0, 1)).normalized()
		ps.tube(pts, [0.3, 0.26, 0.16, 0.03], pp, {"sides": 12, "per": 3, "flat": 0.3, "side": radial, "lump": 0.08, "cap_len": 0.5})
		ps.tube(pts.map(func (q): return q - radial * 0.05), [0.24, 0.2, 0.12, 0.02], inner, {"sides": 12, "per": 3, "flat": 0.18, "side": radial})
		ps.crystal(pts[3] - radial * 0.02, -radial + fwd * 0.2, 0.2, 0.035, pf, 5)
		for i in range(7):
			var t := 0.2 + (i % 4) * 0.2
			var along: Vector3 = (pts[1] as Vector3).lerp(pts[2], t) if i < 4 else (pts[2] as Vector3).lerp(pts[3], t - 0.2)
			var off := tangent * (0.1 * (float(i % 3) - 1.0))
			ps.crystal(along + off - radial * 0.07, -radial + fwd * 0.3, 0.12, 0.02, pf, 4)
		part(hinge, "Petal", ps)
		petals.append(hinge)
		if k == 2: jaw = hinge
	var others: Array = petals.filter(func (n): return n != jaw)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": tails}, 1.7)
	return _rig(node, head, [], [], jaw, tails, [], others)
