extends "res://tools/creature_kit.gd"
## The Obelisk Scorpion of the Sunspire Dunes, sculpted by hand on real scorpion anatomy: a
## cephalothorax (prosoma) with a pair of median eyes and clusters of lateral eyes, seven
## overlapping back plates (the mesosoma), a five-segment keeled tail (metasoma) arching over
## the back to a bulb and curved sting (the telson), pincers (pedipalps) built from femur,
## patella and a swollen hand with a fixed and a movable finger, small chelicerae at the front
## and four pairs of walking legs. Three designs:
##   emperor - glossy blue-black, with huge granular claws (like an emperor scorpion)
##   fattail - dark and dangerous, with slender claws and a massively thick tail (Androctonus)
##   obelisk - a desert guardian: sandstone plates carved with glowing glyphs, a tail of stacked
##             obelisk blocks tipped with a gilded sting, and flat chisel-bladed claws

const SAND_STONE := Color("#b9a27a")
const GOLD := Color("#d6a83c")

var shell := Color("#1b1e24")
var shell_light := Color("#4a5566")
var finger := Color("#5a2418")
var claw_k := 1.0
var tail_k := 1.0
var grain := 0.0
var carved := false


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(3.5, 3.5, 3.5)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ObeliskScorpion"
	match variant:
		"emperor":
			shell = Color("#15181d"); shell_light = Color("#3f4d5e"); finger = Color("#6a2a1a"); claw_k = 1.45; tail_k = 0.95; grain = 1.0
			material.roughness = 0.42; material.metallic_specular = 0.6
			_glow(Color("#7fe0ff"))
		"fattail":
			shell = Color("#2e2418"); shell_light = Color("#7a6040"); finger = Color("#1c140c"); claw_k = 0.72; tail_k = 1.65; grain = 0.6
			material.roughness = 0.5
			_glow(Color("#ffb347"))
		"obelisk":
			shell = Color("#2b2a2e"); shell_light = SAND_STONE; finger = Color("#3a3330"); claw_k = 1.15; tail_k = 1.1; carved = true
			material.albedo_texture = load("res://assets/cast/stone_detail_mid.png")
			material.roughness = 0.85
			_glow(Color("#3fe0d0"))
		_: return null
	return _scorpion()


func _glow(c: Color) -> void:
	glow.albedo_color = c.darkened(0.3); glow.emission = c; glow.emission_energy_multiplier = 1.3


## The carapace colour: dark on top with lighter edges and keels, granules picked out, and for
## the obelisk a sandstone body with dark basalt plates.
func carapace() -> Callable:
	var dark := shell; var light := shell_light; var g := grain; var stone := carved
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := dark.lerp(light, clampf(0.15 + (1.0 - absf(n.y)) * 0.35 + Sculpt.fbm(p * 6.0) * 0.3, 0.0, 1.0))
		if g > 0.0: c = c.lightened(smoothstep(0.4, 0.55, Sculpt.noise(p * 38.0)) * 0.25 * g)
		if stone:
			c = Color("#29272b").lerp(Color("#5c5860"), clampf(Sculpt.fbm(p * 5.0) * 0.7 + 0.25 + (1.0 - absf(n.y)) * 0.2, 0.0, 1.0))
			c = c.lerp(SAND_STONE, smoothstep(0.42, 0.6, Sculpt.noise(p * 7.0)) * 0.35)
		return c.lerp(Color("#8a7a60") if stone else light.lightened(0.2), smoothstep(-0.4, -0.85, n.y) * 0.5)


func plate_paint() -> Callable:
	var dark := shell; var light := shell_light; var stone := carved
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		if stone: return GOLD.lerp(Color("#7a5a1a"), clampf(-n.y * 0.5 + Sculpt.noise(p * 14.0) * 0.4 + 0.2, 0.0, 1.0))
		return dark.lerp(light, clampf(n.y * -0.2 + 0.1 + Sculpt.noise(p * 9.0) * 0.25, 0.0, 1.0))


## A glowing carved glyph: a short line or a small eye-ring lying on a surface.
func glyph(s: Sculpt, painter: int, at: Vector3, up: Vector3, kind: int, size: float) -> void:
	var a := up.cross(Vector3.BACK).normalized()
	if a.length() < 0.1: a = Vector3.RIGHT
	var b := up.cross(a).normalized()
	match kind % 3:
		0:
			var pts: Array = []
			for k in range(7):
				var t := TAU * k / 6.0
				pts.append(at + (a * cos(t) * 1.4 + b * sin(t)) * size)
			s.tube(pts, pts.map(func (_q): return size * 0.18), painter, {"sides": 4, "per": 2, "cap_rings": 1})
			s.blob(at, Vector3.ONE * size * 0.35, painter, {"lat": 3, "lon": 5})
		1:
			s.tube([at - b * size * 1.3, at + b * size * 1.3], [size * 0.18, size * 0.18], painter, {"sides": 4, "per": 1, "cap_rings": 1})
			s.tube([at - a * size, at + a * size], [size * 0.18, size * 0.18], painter, {"sides": 4, "per": 1, "cap_rings": 1})
		2:
			s.tube([at - a * size * 1.2 - b * size, at - b * size * 0.2, at + a * size * 1.2 + b * size], [size * 0.18, size * 0.18, size * 0.18], painter, {"sides": 4, "per": 1, "cap_rings": 1})


func _scorpion() -> Node3D:
	var cp := carapace(); var pp := plate_paint()
	var body := Sculpt.new(); var bp := body.add_painter(cp); var bplate := body.add_painter(pp)
	var gl := Sculpt.new(); var gp := gl.add_painter(func (p, n, v, w): return Color.WHITE)
	# The prosoma: a broad, flat head-shield, notched at the front, with a raised eye mound.
	body.tube([Vector3(0, 0.3, -0.12), Vector3(0, 0.32, -0.28), Vector3(0, 0.3, -0.44)], [0.15, 0.13, 0.1], bp, {"sides": 16, "per": 2, "flat": 1.9, "square": 0.5, "cap_len": 0.35})
	body.blob(Vector3(0, 0.39, -0.3), Vector3(0.05, 0.03, 0.05), bp, {"lat": 4, "lon": 7})
	# The mesosoma: seven overlapping back plates, each with a median keel.
	for k in range(7):
		var z := -0.1 + k * 0.095
		var w := 0.27 - absf(k - 3.0) * 0.012 - (0.03 if k == 6 else 0.0)
		var y := 0.33 - k * 0.004
		body.tube([Vector3(0, y, z - 0.055), Vector3(0, y + 0.01, z + 0.055)], [0.1, 0.1], bplate if not carved else bp, {"sides": 14, "per": 1, "flat": w / 0.1, "square": 0.4, "cap_len": 0.4})
		body.tube([Vector3(0, y + 0.085, z - 0.05), Vector3(0, y + 0.09, z + 0.05)], [0.012, 0.012], bplate, {"sides": 5, "per": 1, "cap_rings": 1})
		if carved:
			# Dark basalt inlays on each sandstone plate, each carved with a glowing glyph.
			body.tube([Vector3(0, y + 0.06, z - 0.04), Vector3(0, y + 0.065, z + 0.04)], [0.04, 0.04], bplate, {"sides": 10, "per": 1, "flat": 3.0, "square": 0.8, "cap_len": 0.3})
			for side in [-1.0, 1.0]:
				glyph(gl, gp, Vector3(0.12 * side, y + 0.088, z), Vector3(side * 0.3, 1, 0).normalized(), k + int(side > 0.0), 0.03)
	body.blob(Vector3(0, 0.25, 0.22), Vector3(0.22, 0.08, 0.38), bp, {"lat": 6, "lon": 10})
	# Chelicerae: two small pincers at the very front.
	for side in [-1.0, 1.0]:
		body.tube([Vector3(0.035 * side, 0.3, -0.44), Vector3(0.04 * side, 0.29, -0.51), Vector3(0.025 * side, 0.27, -0.54)], [0.025, 0.02, 0.006], bplate, {"sides": 6, "per": 2, "cap0": false})
	part(root, "Body", body)
	# The tail: five keeled segments arching up and over the back, then the telson.
	var spine := [Vector3(0, 0.3, 0.52), Vector3(0, 0.42, 0.74), Vector3(0, 0.63, 0.88), Vector3(0, 0.88, 0.88), Vector3(0, 1.07, 0.74), Vector3(0, 1.15, 0.53)]
	var tails: Array = []
	var parent: Node3D = root
	for seg in range(5):
		var a: Vector3 = spine[seg]; var b: Vector3 = spine[seg + 1]
		var node := joint(parent, "Tail%d" % seg, a)
		var ts := Sculpt.new(); var tp := ts.add_painter(cp); var tpl := ts.add_painter(pp)
		var tg := Sculpt.new(); var tgp := tg.add_painter(func (p, n, v, w): return Color.WHITE)
		var r0: float = lerpf(0.085, 0.07, seg / 4.0) * tail_k
		var axis := (b - a).normalized()
		var opts := {"sides": 12, "per": 2, "cap_len": 0.3, "cap_rings": 2, "ridges": 4, "ridge": 0.12}
		if carved: opts = {"sides": 12, "per": 1, "square": 1.0, "cap_len": 0.15, "cap_rings": 1}
		ts.tube([a + axis * 0.012, a.lerp(b, 0.5), b - axis * 0.012], [r0 * 0.92, r0 * 1.05, r0 * 0.96], tp, opts)
		# A dark joint ring where each segment meets the next.
		ts.tube([b - axis * 0.02, b + axis * 0.01], [r0 * 0.8, r0 * 0.8], tpl, {"sides": 10, "per": 1, "cap_rings": 1})
		if grain > 0.0:
			for i in range(6):
				var ang := TAU * i / 6.0
				var side_v := axis.cross(Vector3.RIGHT).normalized()
				var off := (Vector3.RIGHT * cos(ang) + side_v * sin(ang)) * r0 * 0.98
				ts.blob(a.lerp(b, 0.25 + 0.5 * (i % 2)) + off, Vector3.ONE * r0 * 0.13, tpl, {"lat": 3, "lon": 5})
		if carved:
			var up := axis.cross(Vector3.RIGHT).normalized() * -1.0
			glyph(tg, tgp, a.lerp(b, 0.5) + up * r0 * 1.02, up, seg, 0.03)
		if seg == 4:
			# The telson: a swollen venom bulb and a long curved sting, dark at the tip, with a
			# bead of glowing venom.
			var bulb := b + Vector3(0, -0.03, -0.06)
			var bulb_paint := ts.add_painter(func (p, n, v, w): return GOLD.lerp(Color("#7a5a1a"), clampf(-n.y, 0.0, 1.0)) if carved else shell.lerp(finger, 0.6).lightened(0.1))
			var sting := ts.add_painter(func (p, n, v, w): return Color("#120c08").lerp(Color("#3a2a1a"), 1.0 - v))
			ts.blob(bulb, Vector3(0.075, 0.07, 0.1) * tail_k, bulb_paint, {"lat": 7, "lon": 10})
			ts.tube([bulb + Vector3(0, -0.04, -0.08) * tail_k, bulb + Vector3(0, -0.12, -0.16) * tail_k, bulb + Vector3(0, -0.22, -0.13) * tail_k], [0.028 * tail_k, 0.016 * tail_k, 0.002], sting, {"sides": 8, "per": 3, "cap0": false})
			tg.blob(bulb + Vector3(0, -0.22, -0.13) * tail_k, Vector3.ONE * 0.014, tgp, {"lat": 4, "lon": 6})
			tails.append(node)
			part(node, "Segment", ts)
			part(node, "Glow", tg, glow).material_override = glow
			parent = node
			break
		part(node, "Segment", ts)
		if tg.triangles() > 0: part(node, "Glow", tg, glow).material_override = glow
		tails.append(node); parent = node
	# The head joint carries the eyes, the pedipalp arms and the claws.
	var head := joint(root, "Head", Vector3(0, 0.32, -0.32))
	var hs := Sculpt.new(); var hp := hs.add_painter(cp); var hpl := hs.add_painter(pp)
	var fp := hs.add_painter(func (p, n, v, w): return finger.lerp(Color("#0c0806"), v * 0.6))
	var claws: Array = []
	var hg := Sculpt.new(); var hgp := hg.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(0.12 * side, 0.3, -0.4)
		var elbow := Vector3(0.36 * side, 0.36, -0.48)
		var wrist := Vector3(0.43 * side, 0.34, -0.72)
		hs.tube([shoulder, elbow], [0.045 * claw_k, 0.04 * claw_k], hp, {"sides": 9, "per": 1, "cap_rings": 2, "ridges": 4, "ridge": 0.1})
		hs.tube([elbow, wrist], [0.042 * claw_k, 0.048 * claw_k], hp, {"sides": 9, "per": 1, "cap_rings": 2, "ridges": 4, "ridge": 0.1})
		hs.blob(elbow, Vector3.ONE * 0.05 * claw_k, hpl, {"lat": 5, "lon": 8})
		# The hand (manus): a swollen, keeled bulb.
		var hand := wrist + Vector3(-0.02 * side, -0.01, -0.13 * claw_k)
		var hand_r := Vector3(0.085, 0.065, 0.13) * claw_k
		if carved: hs.tube([wrist + Vector3(0, 0, -0.03), hand + Vector3(0, 0, -hand_r.z * 0.8)], [hand_r.x, hand_r.x], hp, {"sides": 10, "per": 1, "square": 1.0, "flat": 0.75, "side": Vector3.UP, "cap_len": 0.2})
		else: hs.blob(hand, hand_r, hp, {"lat": 7, "lon": 11})
		if grain > 0.0:
			for i in range(int(28 * grain)):
				var u := Vector3(Sculpt.noise(Vector3(i, side, 1) * 3.1), Sculpt.noise(Vector3(i, side, 2) * 2.7) * 0.8 + 0.3, Sculpt.noise(Vector3(i, side, 3) * 2.3)).normalized()
				hs.blob(hand + u * hand_r * 0.97, Vector3.ONE * 0.012 * claw_k, hpl, {"lat": 3, "lon": 5})
		if carved:
			glyph(hs, hs.add_painter(func (p, n, v, w): return Color("#2a292d")), hand + Vector3(0, hand_r.y * 0.98, 0), Vector3.UP, 2 + int(side > 0.0), 0.03)
			glyph(hg, hgp, hand + Vector3(0, hand_r.y * 1.02, 0), Vector3.UP, int(side > 0.0), 0.024)
		# Two fingers, hinged at the front of the hand so they open sideways like jaws: the
		# fixed finger on the outside, the movable finger on the inside. Each has a row of
		# little teeth along its cutting edge.
		var base := hand + Vector3(0, 0, -hand_r.z * 0.85)
		# Ordered so the game's opening swing moves both fingers apart on either side.
		for half in ([1.0, -1.0] if side < 0 else [-1.0, 1.0]):
			var label := "%sClaw%s" % ["Left" if side < 0 else "Right", "Outer" if half > 0 else "Inner"]
			var hinge := joint(head, label, base + Vector3(0.025 * half * side, 0, 0))
			var cs := Sculpt.new(); var cfp := cs.add_painter(func (p, n, v, w): return finger.lerp(Color("#0c0806"), v * 0.7))
			var ct := cs.add_painter(func (p, n, v, w): return Color("#d8c9a8").darkened(0.2))
			var o := base + Vector3(0.03 * half * side, 0, 0)
			var length := 0.26 * claw_k
			var pts := [o, o + Vector3(0.025 * half * side, 0, -length * 0.45), o + Vector3(0.012 * half * side, 0, -length * 0.8), o + Vector3(-0.03 * half * side, -0.004, -length)]
			var radii := [0.04 * claw_k, 0.03 * claw_k, 0.018 * claw_k, 0.004]
			if carved: cs.tube(pts, radii, cfp, {"sides": 6, "per": 2, "flat": 0.35, "side": Vector3.RIGHT, "cap1": false})
			else: cs.tube(pts, radii, cfp, {"sides": 8, "per": 3, "flat": 0.7, "side": Vector3.UP, "cap1": false})
			for i in range(4):
				var at: Vector3 = (pts[0] as Vector3).lerp(pts[3], 0.25 + i * 0.15)
				cs.crystal(at + Vector3(-0.02 * half * side, 0, 0), Vector3(-half * side, 0, -0.3), 0.025, 0.006, ct, 4)
			part(hinge, "Finger", cs)
			claws.append(hinge)
	part(head, "Head", hs)
	if hg.triangles() > 0: part(head, "Glyphs", hg, glow).material_override = glow
	# Eyes: the two median eyes on the mound, and three small lateral eyes at each front corner.
	var eye_at: Array = [Vector3(-0.025, 0.42, -0.31), Vector3(0.025, 0.42, -0.31)]
	for side in [-1.0, 1.0]:
		for e in [Vector3(0.2, 0.355, -0.41), Vector3(0.215, 0.35, -0.385), Vector3(0.19, 0.35, -0.43)]: eye_at.append(Vector3(e.x * side, e.y, e.z))
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for i in range(eye_at.size()): es.blob(eye_at[i], Vector3.ONE * (0.022 if i < 2 else 0.012), ew, {"lat": 4, "lon": 7})
	var core := part(head, "GlowingEyes", es, glow)
	core.material_override = glow
	# Four pairs of walking legs, each bent up to a knee and down to a spurred tip.
	var hips: Array = []; var knees: Array = []
	for k in range(4):
		for side in [-1.0, 1.0]:
			var at := Vector3(0.17 * side, 0.27, -0.36 + k * 0.1)
			var out := Vector3(side, 0, (k - 1.5) * 0.35).normalized()
			var knee_at := at + out * 0.22 + Vector3(0, 0.15, 0)
			var foot := Vector3(at.x + out.x * 0.48, 0.02, at.z + out.z * 0.48)
			var hip := joint(root, "Leg%d%s" % [k, "Left" if side < 0 else "Right"], at)
			var us := Sculpt.new(); var up := us.add_painter(cp)
			us.tube([at, at.lerp(knee_at, 0.5) + Vector3(0, 0.02, 0), knee_at], [0.042, 0.038, 0.032], up, {"sides": 7, "per": 2, "cap_rings": 1, "square": 0.5 if carved else 0.0})
			part(hip, "Femur", us)
			var knee := joint(hip, "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(cp); var lt := ls.add_painter(func (p, n, v, w): return finger.lerp(Color("#0c0806"), 0.5))
			var mid := knee_at.lerp(foot, 0.55) + out * 0.04
			ls.tube([knee_at, mid, foot + Vector3(0, 0.03, 0)], [0.032, 0.025, 0.014], lp, {"sides": 7, "per": 2, "cap_rings": 1, "square": 0.5 if carved else 0.0})
			ls.blob(knee_at, Vector3.ONE * 0.04, lp, {"lat": 4, "lon": 6})
			ls.crystal(foot + Vector3(0, 0.03, 0), Vector3(out.x * 0.4, -1, out.z * 0.4), 0.04, 0.008, lt, 4)
			part(knee, "Tibia", ls)
			hips.append(hip); knees.append(knee)
	if gl.triangles() > 0: part(root, "Glyphs", gl, glow).material_override = glow
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.6)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tails), "features": {&"pincers": paths.call(claws)}}
	node.set_meta("rig_bindings", rig)
	return node
