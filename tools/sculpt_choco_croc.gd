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
	foil_mat.roughness = 0.38
	foil_mat.metallic = 0.45
	foil_mat.metallic_specular = 0.8
	glow.albedo_color = Color("#e09a2a"); glow.emission = Color("#ffae2e")
	glow.emission_energy_multiplier = 0.8


static func choc(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := CHOC.lerp(CHOC_MID, clampf(0.35 + n.y * 0.45 + Sculpt.fbm(p * 7.0) * 0.4, 0.0, 1.0))
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.35)


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


## Conical teeth along a jaw from `a` to `b`, pointing `dir`; every fourth one is a fang.
func teeth(s: Sculpt, painter: int, a: Vector3, b: Vector3, count: int, dir: Vector3, length: float, width: float) -> void:
	for k in range(count):
		var at := a.lerp(b, (k + 0.5) / count)
		var l := length * (1.6 if k % 4 == 2 else 0.85 + 0.2 * absf(sin(k * 1.7)))
		s.tube([at, at + dir.normalized() * l * 0.55, at + dir.normalized() * l], [width, width * 0.65, 0.002], painter, {"sides": 6, "per": 2, "cap0": false})


func build(_variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ChocoBarCroc"
	# ---- the body: chocolate shoulders and hips, the middle still in its torn wrapper.
	var bs := Sculpt.new(); var cp := bs.add_painter(choc); var sp := bs.add_painter(scute); var wp := bs.add_painter(wrapper_paint)
	var fp := bs.add_painter(func (p, n, v, w): return FOIL.lightened(absf(Sculpt.noise(p * 25.0)) * 0.3).darkened(clampf(-n.y, 0.0, 1.0) * 0.3))
	var belly := bs.add_painter(func (p, n, v, w): return Color("#8a5a3a").lerp(CHOC_MID, clampf(n.y + 0.3, 0.0, 1.0)))
	bs.tube([Vector3(0, 0.33, -0.28), Vector3(0, 0.34, 0.0), Vector3(0, 0.33, 0.35), Vector3(0, 0.31, 0.66)], [0.17, 0.2, 0.2, 0.15], cp, {"sides": 16, "per": 3, "flat": 1.55, "side": Vector3.RIGHT, "square": 0.7, "cap_len": 0.4, "lump": 0.06})
	bs.blob(Vector3(0, 0.2, 0.15), Vector3(0.24, 0.07, 0.42), belly, {"lat": 5, "lon": 12})
	# The wrapper, torn at both ends: a crumpled sleeve round the middle with silver foil
	# peeking out of the tears.
	bs.tube([Vector3(0, 0.335, 0.06), Vector3(0, 0.34, 0.3), Vector3(0, 0.325, 0.56), Vector3(0, 0.31, 0.7), Vector3(0, 0.305, 0.8)], [0.215, 0.222, 0.21, 0.13, 0.12], wp, {"sides": 18, "per": 3, "flat": 1.55, "side": Vector3.RIGHT, "square": 0.7, "cap0": false, "cap1": false, "lump": 0.18})
	for k in range(11):
		var ang := TAU * k / 11.0 + 0.15
		var front := true
		var z := 0.06
		var dir := Vector3(cos(ang) * 1.55, sin(ang), 0).normalized()
		var at := Vector3(dir.x * 0.33, 0.335 + dir.y * 0.21, z)
		var out := Vector3(0, 0, -1.0 if front else 1.0)
		var flap_len := 0.05 + 0.06 * absf(sin(k * 2.1))
		bs.tube([at, at + out * flap_len * 0.6 + dir * 0.012, at + out * flap_len + dir * 0.02], [0.05, 0.035, 0.004], wp if k % 3 else fp, {"sides": 5, "per": 2, "flat": 0.25, "side": dir, "cap0": false})
	scutes(bs, sp, Vector3(0, 0.515, -0.27), Vector3(0, 0.525, 0.02), 2, 0.085, 0.13)
	# The crimped end of the wrapper, pinched round the root of the tail.
	bs.tube([Vector3(0, 0.305, 0.78), Vector3(0, 0.3, 0.86), Vector3(0, 0.3, 0.95)], [0.1, 0.13, 0.17], wp, {"sides": 16, "per": 2, "flat": 1.3, "side": Vector3.RIGHT, "ridges": 8, "ridge": 0.3, "cap0": false, "cap1": false, "lump": 0.2})
	part(root, "Body", bs, shiny)
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
			if k > 0: scutes(ts, tsp, at + Vector3(0, r0 * 0.85, 0.02), next + Vector3(0, r1 * 0.85, -0.02), 2, r0 * 0.4, maxf(0.025, r0 * 0.38))
		part(node, "Segment", ts, shiny)
		tail_nodes.append(node)
		parent = node; at = next
	# ---- the head: a long, flat, tapering snout and the skull behind it.
	var head := joint(root, "Head", Vector3(0, 0.36, -0.3))
	var hs := Sculpt.new(); var hc := hs.add_painter(choc); var hsc := hs.add_painter(scute); var ht := hs.add_painter(func (p, n, v, w): return TOOTH.lerp(Color("#cdb88f"), 1.0 - v))
	var maw := hs.add_painter(func (p, n, v, w): return MAW)
	hs.tube([Vector3(0, 0.4, -0.26), Vector3(0, 0.39, -0.45), Vector3(0, 0.355, -0.7), Vector3(0, 0.335, -0.95)], [0.15, 0.13, 0.09, 0.07], hc, {"sides": 16, "per": 3, "flat": 1.65, "side": Vector3.RIGHT, "square": 0.45, "cap_len": 0.45, "lump": 0.05})
	# The upper lip line, dark where the jaws meet.
	hs.tube([Vector3(0, 0.305, -0.3), Vector3(0, 0.3, -0.6), Vector3(0, 0.3, -0.93)], [0.033, 0.028, 0.019], maw, {"sides": 8, "per": 3, "flat": 7.2, "side": Vector3.RIGHT, "cap_len": 0.3})
	# Nostril bumps on the tip of the snout.
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.045 * side, 0.39, -0.93), Vector3(0.035, 0.025, 0.04), hc, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.045 * side, 0.41, -0.935), Vector3(0.012, 0.006, 0.012), maw, {"lat": 3, "lon": 6})
	# Raised eye sockets with heavy brows.
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.1 * side, 0.53, -0.36), Vector3(0.07, 0.06, 0.075), hc, {"lat": 6, "lon": 9})
		hs.tube([Vector3(0.06 * side, 0.585, -0.445), Vector3(0.12 * side, 0.59, -0.41), Vector3(0.155 * side, 0.565, -0.35)], [0.018, 0.022, 0.012], hsc, {"sides": 7, "per": 3, "flat": 0.6, "side": Vector3.UP})
	# Scutes down the neck and over the skull.
	scutes(hs, hsc, Vector3(0, 0.55, -0.27), Vector3(0, 0.54, -0.18), 1, 0.06, 0.08)
	# Upper teeth hanging outside the lower jaw, the croc's grin.
	for side in [-1.0, 1.0]:
		teeth(hs, ht, Vector3(0.215 * side, 0.3, -0.36), Vector3(0.11 * side, 0.3, -0.92), 9, Vector3(0.25 * side, -1, 0), 0.09, 0.022)
	part(head, "Snout", hs, shiny)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.11 * side, 0.55, -0.418), Vector3(0.045, 0.038, 0.035), ew, {"lat": 5, "lon": 8})
	var core := part(head, "Eyes", es, glow); core.material_override = glow
	var ps := Sculpt.new(); var pp := ps.add_painter(func (p, n, v, w): return Color("#120604"))
	for side in [-1.0, 1.0]: ps.blob(Vector3(0.11 * side, 0.55, -0.452), Vector3(0.009, 0.034, 0.006), pp, {"lat": 4, "lon": 6})
	part(head, "Pupils", ps, shiny)
	# ---- the lower jaw.
	var jaw := joint(head, "Jaw", Vector3(0, 0.29, -0.24))
	var js := Sculpt.new(); var jc := js.add_painter(choc); var jt := js.add_painter(func (p, n, v, w): return TOOTH.lerp(Color("#cdb88f"), 1.0 - v))
	var jm := js.add_painter(func (p, n, v, w): return MAW.lerp(Color("#5a1e14"), clampf(n.y, 0.0, 1.0) * 0.5))
	var jtongue := js.add_painter(func (p, n, v, w): return TONGUE.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	js.tube([Vector3(0, 0.25, -0.26), Vector3(0, 0.245, -0.55), Vector3(0, 0.255, -0.9)], [0.1, 0.075, 0.055], jc, {"sides": 14, "per": 3, "flat": 1.9, "side": Vector3.RIGHT, "square": 0.4, "cap_len": 0.4})
	js.blob(Vector3(0, 0.29, -0.55), Vector3(0.12, 0.018, 0.3), jm, {"lat": 4, "lon": 10})
	js.blob(Vector3(0, 0.3, -0.45), Vector3(0.07, 0.02, 0.17), jtongue, {"lat": 4, "lon": 9})
	for side in [-1.0, 1.0]:
		teeth(js, jt, Vector3(0.2 * side, 0.27, -0.42), Vector3(0.115 * side, 0.27, -0.9), 6, Vector3(0.35 * side, 1, 0), 0.1, 0.022)
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
		ss.blob(foot + Vector3(0, 0.0, -0.04), Vector3(0.08, 0.035, 0.1), sp2, {"lat": 5, "lon": 8})
		for c in range(4):
			var spread := (c - 1.5) * 0.35
			var d := Vector3(sin(spread) + side * 0.15, -0.25, -cos(spread)).normalized()
			var base := foot + Vector3(sin(spread) * 0.05, 0.0, -0.08)
			ss.tube([base, base + d * 0.045, base + d * 0.08 + Vector3(0, -0.02, 0)], [0.013, 0.009, 0.002], sc, {"sides": 5, "per": 2, "cap0": false})
		part(knee, "Foot", ss, shiny)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.15)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tail_nodes), "features": {&"jaw": node.get_path_to(jaw)}}
	node.set_meta("rig_bindings", rig)
	return node
