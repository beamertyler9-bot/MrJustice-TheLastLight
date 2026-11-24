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
	return null


func _eyes(parent: Node3D, at: Array, size: float) -> MeshInstance3D:
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for p in at: es.blob(p, Vector3.ONE * size, white, {"lat": 4, "lon": 7})
	var core := part(parent, "GlowingEyes", es, glow)
	core.material_override = glow
	return core


func _rig(node: Node3D, head: Node3D, hips: Array, knees: Array, jaw: Node3D, tails: Array, pincers: Array = []) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {}
	if jaw != null: features[&"jaw"] = node.get_path_to(jaw)
	if not pincers.is_empty(): features[&"pincers"] = paths.call(pincers)
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

func _sandfish() -> Node3D:
	# Glossy golden-sand scales with dark brown cross-bands on the back and a pale belly; each
	# scale is picked out as a small diamond.
	var scales := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#dcb66a").lerp(Color("#b48a45"), clampf(n.y * 0.4 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
		var band := sin(p.z * 8.0 + Sculpt.fbm(p * 2.0) * 1.2)
		c = c.lerp(Color("#4f331b"), smoothstep(0.45, 0.65, band) * smoothstep(-0.2, 0.3, n.y) * 0.9)
		var d := absf(fposmod(p.z * 12.0 + p.x * 8.0, 1.0) - 0.5) + absf(fposmod(p.z * 12.0 - p.x * 8.0 + p.y * 6.0, 1.0) - 0.5)
		c = c.darkened(smoothstep(0.7, 0.92, d) * 0.3)
		# A dark lip line along the mouth.
		if p.z < -0.6 and p.y < 0.43 and p.y > 0.35: c = c.lerp(Color("#3a2614"), smoothstep(0.42, 0.39, p.y) * smoothstep(0.35, 0.38, p.y) * absf(n.x))
		return c.lerp(Color("#f3ead2"), smoothstep(-0.2, -0.6, n.y) * 0.8)
	material.roughness = 0.55
	var body := Sculpt.new(); var bp := body.add_painter(scales)
	body.tube([Vector3(0, 0.46, -0.56), Vector3(0, 0.49, -0.22), Vector3(0, 0.47, 0.22), Vector3(0, 0.42, 0.58)], [0.27, 0.32, 0.32, 0.27], bp, {"sides": 18, "per": 3, "flat": 1.25})
	var tails: Array = []
	var parent: Node3D = root
	var at := Vector3(0, 0.41, 0.56)
	var step := Vector3(0, -0.02, 0.32)
	for k in range(6):
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var r0: float = lerpf(0.27, 0.03, pow(float(k) / 6.0, 0.8)); var r1: float = lerpf(0.27, 0.03, pow(float(k + 1) / 6.0, 0.8))
		var ts := Sculpt.new(); var tp := ts.add_painter(scales)
		var next := at + step
		ts.tube([at - step * 0.15, at.lerp(next, 0.5), next + step * 0.12], [r0 * 1.02, (r0 + r1) * 0.5, r1], tp, {"sides": 14, "per": 2, "flat": 1.15, "cap1": k == 5})
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	# The head: a wedge with a sharp shovel snout for diving into sand, the lower jaw tucked
	# under the upper (countersunk) so sand can't get in.
	var head := joint(root, "Head", Vector3(0, 0.48, -0.6))
	var hs := Sculpt.new(); var hp := hs.add_painter(scales); var dark := hs.add_painter(func (p, n, v, w): return Color("#1d1510"))
	var tooth := hs.add_painter(func (p, n, v, w): return TOOTH)
	hs.tube([Vector3(0, 0.5, -0.56), Vector3(0, 0.5, -0.8), Vector3(0, 0.45, -1.02), Vector3(0, 0.38, -1.18), Vector3(0, 0.35, -1.24)], [0.29, 0.26, 0.18, 0.085, 0.02], hp, {"sides": 16, "per": 3, "flat": 1.2, "square": 0.25, "cap1": false})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.05 * side, 0.41, -1.15), Vector3(0.015, 0.008, 0.018), dark, {"lat": 3, "lon": 6})
		hs.blob(Vector3(0.21 * side, 0.47, -0.7), Vector3(0.025, 0.03, 0.02), dark, {"lat": 3, "lon": 6})
		for k in range(6):
			hs.crystal(Vector3((0.2 - k * 0.025) * side, 0.37, -0.72 - k * 0.07), Vector3(0, -1, -0.15), 0.085, 0.016, tooth, 5)
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.22 * side, 0.625, -0.85), Vector3(0.06, 0.028, 0.06), hp, {"lat": 4, "lon": 7})
	part(head, "Head", hs)
	var core := _eyes(head, [Vector3(-0.255, 0.58, -0.87), Vector3(0.255, 0.58, -0.87)], 0.045)
	var jaw := joint(head, "Jaw", Vector3(0, 0.36, -0.6))
	var js := Sculpt.new(); var jp := js.add_painter(scales); var mouth := js.add_painter(func (p, n, v, w): return MOUTH)
	var jt := js.add_painter(func (p, n, v, w): return TOOTH)
	js.tube([Vector3(0, 0.36, -0.58), Vector3(0, 0.33, -0.86), Vector3(0, 0.33, -1.08)], [0.2, 0.15, 0.06], jp, {"sides": 14, "per": 3, "flat": 1.4, "cap_len": 0.5})
	js.blob(Vector3(0, 0.37, -0.82), Vector3(0.16, 0.025, 0.2), mouth, {"lat": 4, "lon": 10})
	for side in [-1.0, 1.0]:
		for k in range(5):
			js.crystal(Vector3((0.17 - k * 0.025) * side, 0.37, -0.75 - k * 0.07), Vector3(0, 1, -0.15), 0.05, 0.012, jt, 5)
	# Built hanging a little open, so its teeth show even at rest.
	part(jaw, "Jaw", js).rotation.x = -0.32
	# Short, sprawling legs; the toes are fringed with comb-like scales for running on sand.
	var hips: Array = []; var knees: Array = []
	for row in [["Front", -0.36, 0.42], ["Hind", 0.42, 0.38]]:
		for side in [-1.0, 1.0]:
			var z: float = row[1]; var y: float = row[2]
			var hip_at := Vector3(0.3 * side, y, z)
			var elbow_at := Vector3(0.52 * side, y - 0.06, z + 0.04)
			var foot_at := Vector3(0.6 * side, 0.04, z - 0.04)
			var hip := joint(root, str(row[0]) + ("Left" if side < 0 else "Right") + "Leg", hip_at)
			var us := Sculpt.new(); var up := us.add_painter(scales)
			us.tube([hip_at - Vector3(0.08 * side, 0, 0), hip_at.lerp(elbow_at, 0.5) + Vector3(0, 0.03, 0), elbow_at], [0.11, 0.09, 0.075], up, {"sides": 10, "per": 3})
			part(hip, "UpperLeg", us)
			var knee := joint(hip, "Elbow" if row[0] == "Front" else "Knee", elbow_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(scales); var fr := ls.add_painter(func (p, n, v, w): return SAND_PALE)
			ls.tube([elbow_at, elbow_at.lerp(foot_at, 0.5), foot_at + Vector3(0, 0.04, 0)], [0.075, 0.06, 0.055], lp, {"sides": 10, "per": 3})
			for t in range(5):
				var ang := -0.9 + t * 0.45
				var dir := Vector3(sin(ang) * side, 0, -cos(ang))
				var toe := foot_at + dir * 0.04
				ls.tube([toe, toe + dir * 0.13 + Vector3(0, -0.02, 0)], [0.022, 0.012], lp, {"sides": 5, "per": 2, "cap_rings": 1})
				for f in range(3): ls.crystal(toe + dir * (0.04 + f * 0.035), dir.cross(Vector3.UP) * side + Vector3(0, -0.2, 0), 0.03, 0.005, fr, 3)
			part(knee, "LowerLeg", ls)
			hips.append(hip); knees.append(knee)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": tails}, 1.7)
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
