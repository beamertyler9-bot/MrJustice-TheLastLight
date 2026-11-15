extends "res://tools/creature_kit.gd"
## The Wrapper Mimic of S'morewood, sculpted by hand: a sweet that is really a mouth on legs.
## Three takes: a twist-wrapped bonbon, a wrapped gift box and a half-unwrapped chocolate bar.
## Every take keeps the same rig: the body is the head, a lower jaw drops open to bite
## ("jaw"), and four legs scurry underneath.

const PINK := Color("#e4497f")
const PINK_LIGHT := Color("#ff8db5")
const CREAM := Color("#fbeee6")
const GOLD := Color("#e8b33a")
const MOUTH := Color("#2a0b14")
const TONGUE := Color("#d8434f")
const LICORICE := Color("#2a1418")
const TEAL := Color("#2fa3a0")
const RIBBON := Color("#d42435")
const WRAP_BLUE := Color("#2d5fc4")
const FOIL := Color("#c9ccd4")
const CHOC := Color("#4a2a18")
const CHOC_HI := Color("#6b3f25")

var shiny: StandardMaterial3D
var foil_mat: StandardMaterial3D
var eye_glow: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	material.roughness = 0.7
	material.uv1_scale = Vector3(5, 5, 5)
	shiny = StandardMaterial3D.new()
	shiny.vertex_color_use_as_albedo = true
	shiny.vertex_color_is_srgb = true
	shiny.roughness = 0.28
	shiny.metallic_specular = 0.7
	foil_mat = StandardMaterial3D.new()
	foil_mat.vertex_color_use_as_albedo = true
	foil_mat.vertex_color_is_srgb = true
	foil_mat.roughness = 0.3
	foil_mat.metallic = 0.55
	foil_mat.metallic_specular = 0.8
	glow.albedo_color = Color("#ffd27a"); glow.emission = Color("#ffcf5c")
	glow.emission_energy_multiplier = 0.9
	eye_glow = glow


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "WrapperMimic"
	match variant:
		"bonbon": return _bonbon()
		"giftbox": return _giftbox()
		"chocobar": return _chocobar()
	return null


## Adds the regional visual rig (legs, ears, tails and the snapping jaw) to a finished model.
func _with_visual(node: Node3D, head: Node3D, hips: Array, knees: Array, jaw: Node3D, ears: Array = [], tails: Array = []) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": paths.call(ears), "tails": paths.call(tails), "features": {&"jaw": node.get_path_to(jaw)}}
	node.set_meta("rig_bindings", rig)
	return node


## Four legs from the underside. Each: a thigh out and up to the knee, then a shin down to a
## small foot. `look` paints them, `foot` is drawn at the bottom of each shin.
func _legs(hip_spots: Array, spread: float, knee_lift: float, thick: float, look: Callable, foot: Callable, mat: Material) -> Array:
	var hips: Array = []; var knees: Array = []
	for k in range(hip_spots.size()):
		var at: Vector3 = hip_spots[k]
		var side := signf(at.x)
		var out := Vector3(side, 0, signf(at.z) * 0.45).normalized()
		var label := ("Foreleg%d" if at.z < 0.0 else "Hindleg%d") % k
		var hip := joint(root, label, at)
		var knee_at := at + out * spread * 0.55 + Vector3(0, knee_lift, 0)
		var ts := Sculpt.new(); var tp := ts.add_painter(look)
		ts.tube([at, at.lerp(knee_at, 0.5) + Vector3(0, 0.03, 0), knee_at], [thick, thick * 0.95, thick * 0.85], tp, {"sides": 8, "per": 3, "ridges": 4, "ridge": 0.12, "twist": 6.0})
		part(hip, "Thigh", ts, mat)
		var knee := joint(hip, "Knee", knee_at)
		var foot_at := Vector3(knee_at.x + out.x * spread * 0.35, 0.05, knee_at.z + out.z * spread * 0.35)
		var ss := Sculpt.new(); var sp := ss.add_painter(look)
		ss.tube([knee_at, knee_at.lerp(foot_at, 0.5) + out * 0.03, foot_at + Vector3(0, 0.04, 0)], [thick * 0.85, thick * 0.75, thick * 0.65], sp, {"sides": 8, "per": 3, "ridges": 4, "ridge": 0.12, "twist": 6.0})
		ss.blob(knee_at, Vector3.ONE * thick * 1.05, sp, {"lat": 5, "lon": 8})
		foot.call(ss, foot_at)
		part(knee, "Shin", ss, mat)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


## Two glowing eyes with dark pupils; the white part is the creature's glowing core.
func _eyes(parent: Node3D, spots: Array, size: float, facing: Vector3) -> MeshInstance3D:
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for at in spots: es.blob(at, Vector3(size, size * 0.9, size * 0.7), ew, {"lat": 6, "lon": 9, "basis": Basis.looking_at(facing, Vector3.UP)})
	var core := part(parent, "GlowingEyes", es, eye_glow); core.material_override = eye_glow
	var ps := Sculpt.new(); var pp := ps.add_painter(func (p, n, v, w): return Color("#1b0a10"))
	for at in spots: ps.blob(at + facing.normalized() * size * 0.62, Vector3(size * 0.42, size * 0.55, size * 0.18), pp, {"lat": 5, "lon": 8, "basis": Basis.looking_at(facing, Vector3.UP)})
	part(parent, "Pupils", ps, shiny)
	return core


## A row of sugar-crystal teeth from `a` to `b`, pointing `dir`.
func _teeth(s: Sculpt, painter: int, a: Vector3, b: Vector3, count: int, dir: Vector3, length: float, width: float) -> void:
	for k in range(count):
		var t := (k + 0.5) / count
		var l := length * (0.75 + 0.35 * absf(sin(k * 2.3)))
		s.crystal(a.lerp(b, t), dir, l, width, painter, 4, k * 0.7)


# ----------------------------------------------------------------- A: bonbon

## A: a big twist-wrapped bonbon in pink-and-cream striped foil. The wrapper is torn open at
## the top where two eyes peer out, the whole front splits into a mouth of sugar-crystal
## teeth with a caramel tongue, and the crinkled twist ends flick like ears.
func _bonbon() -> Node3D:
	var stripes := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var band := fposmod((p.x + p.y * 0.7 + p.z * 0.25) * 3.4, 1.0)
		var c := PINK.lerp(CREAM, smoothstep(0.42, 0.5, band) * smoothstep(0.92, 0.84, band))
		c = c.lerp(GOLD, smoothstep(0.04, 0.0, absf(band - 0.46)) * 0.8)
		return c.lightened(clampf(n.y, 0.0, 1.0) * 0.12 + absf(Sculpt.noise(p * 16.0)) * 0.12).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)
	var body_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		# The mouth: a dark band across the lower front, hidden while the jaw is shut.
		if p.y < 0.6 and p.y > 0.4 and n.z < -0.1: return MOUTH
		# A torn hole on top where the eyes peer out.
		if Vector2(p.x / 0.3, (p.z + 0.12) / 0.17).length() < 1.0 and p.y > 0.8: return MOUTH
		return stripes.call(p, n, v, w)
	var head := joint(root, "Head", Vector3(0, 0.66, 0.05))
	var hs := Sculpt.new(); var bp := hs.add_painter(body_paint); var sp := hs.add_painter(stripes)
	var tooth := hs.add_painter(func (p, n, v, w): return CREAM.lerp(Color.WHITE, v).darkened(0.05 * (1.0 - v)))
	hs.tube([Vector3(-0.38, 0.68, 0.0), Vector3(0, 0.7, 0.0), Vector3(0.38, 0.68, 0.0)], [0.4, 0.42, 0.4], bp, {"sides": 30, "per": 7, "flat": 1.05, "side": Vector3.FORWARD, "cap_len": 0.55, "cap_rings": 4, "lump": 0.05})
	# Torn wrapper flaps curling up round the eye hole.
	for k in range(6):
		var ang := TAU * k / 6.0 + 0.3
		var at := Vector3(cos(ang) * 0.3, 1.05, -0.12 + sin(ang) * 0.17)
		var out := Vector3(cos(ang), 0.9, sin(ang) * 0.6).normalized()
		hs.tube([at - out * 0.02, at + out * 0.07, at + out * 0.11 + Vector3(0, -0.02, 0)], [0.05, 0.035, 0.005], sp, {"sides": 6, "per": 2, "flat": 0.25, "side": Vector3.UP.cross(out), "cap0": false})
	# Upper teeth hanging over the mouth.
	_teeth(hs, tooth, Vector3(-0.3, 0.61, -0.37), Vector3(0.3, 0.61, -0.37), 6, Vector3(0, -1, -0.2), 0.2, 0.055)
	for side in [-1.0, 1.0]: hs.crystal(Vector3(0.36 * side, 0.6, -0.3), Vector3(0.1 * side, -1, -0.2), 0.12, 0.035, tooth, 4)
	part(head, "Bonbon", hs, foil_mat)
	var core := _eyes(head, [Vector3(-0.1, 1.04, -0.16), Vector3(0.1, 1.04, -0.16)], 0.09, Vector3(0, 0.45, -1))
	# Twist ends: a pinched neck and a crinkled fan of foil, each on its own joint.
	var ears: Array = []
	for side in [-1.0, 1.0]:
		var neck := Vector3(0.74 * side, 0.69, 0.0)
		var ear := joint(head, ("Left" if side < 0 else "Right") + "Twist", neck)
		var es := Sculpt.new(); var ep := es.add_painter(stripes)
		es.tube([neck - Vector3(0.1 * side, 0, 0), neck, neck + Vector3(0.12 * side, 0.02, 0), neck + Vector3(0.3 * side, 0.06, 0)], [0.1, 0.06, 0.12, 0.27], ep, {"sides": 20, "per": 3, "ridges": 13, "ridge": 0.13, "cap0": false, "cap_len": 0.12, "cap_rings": 2, "lump": 0.18})
		part(ear, "TwistEnd", es, foil_mat)
		ears.append(ear)
	# The jaw: the lower half of the sweet, with a row of teeth and a caramel tongue.
	var jaw := joint(head, "Jaw", Vector3(0, 0.52, 0.2))
	var js := Sculpt.new(); var jp := js.add_painter(stripes); var jt := js.add_painter(func (p, n, v, w): return CREAM.lerp(Color.WHITE, v))
	var inside := js.add_painter(func (p, n, v, w): return MOUTH.lightened(0.05))
	var tongue := js.add_painter(func (p, n, v, w): return Color("#e09a3c").lightened(clampf(n.y, 0.0, 1.0) * 0.25))
	js.tube([Vector3(-0.33, 0.44, -0.12), Vector3(0, 0.42, -0.16), Vector3(0.33, 0.44, -0.12)], [0.24, 0.26, 0.24], jp, {"sides": 24, "per": 6, "flat": 1.3, "side": Vector3.FORWARD, "cap_len": 0.6, "lump": 0.05})
	js.blob(Vector3(0, 0.53, -0.14), Vector3(0.3, 0.05, 0.22), inside, {"lat": 4, "lon": 12})
	js.blob(Vector3(0, 0.56, -0.2), Vector3(0.13, 0.04, 0.17), tongue, {"lat": 5, "lon": 9, "lump": 0.1})
	_teeth(js, jt, Vector3(-0.26, 0.53, -0.39), Vector3(0.26, 0.53, -0.39), 5, Vector3(0, 1, -0.15), 0.15, 0.05)
	part(jaw, "LowerJaw", js, foil_mat)
	# Licorice legs with gumdrop feet.
	var lic := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return LICORICE.lightened(clampf(w * 0.5 + 0.2, 0.0, 1.0) * 0.25)
	var foot := func (s: Sculpt, at: Vector3) -> void:
		var gp := s.add_painter(func (p, n, v, w): return PINK.lightened(0.15 + clampf(n.y, 0.0, 1.0) * 0.25))
		s.lathe(at + Vector3(0, -0.04, 0), [Vector2(0, 0.08), Vector2(0.05, 0.07), Vector2(0.075, 0.02), Vector2(0.08, 0.0), Vector2(0, -0.005)], gp, {"sides": 10})
	var legs := _legs([Vector3(-0.28, 0.36, -0.12), Vector3(0.28, 0.36, -0.12), Vector3(-0.28, 0.36, 0.16), Vector3(0.28, 0.36, 0.16)], 0.55, 0.06, 0.045, lic, foot, shiny)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.15)
	return _with_visual(node, head, legs[0], legs[1], jaw, ears)


# ---------------------------------------------------------------- B: gift box

static func polka(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return TEAL.lightened(clampf(n.y, 0.0, 1.0) * 0.12 + Sculpt.noise(p * 12.0) * 0.04).darkened(clampf(-n.y, 0.0, 1.0) * 0.35)


## Cream polka dots stuck flat on the faces of a box (center, size), skipping the ribbon.
func _dots(s: Sculpt, center: Vector3, size: Vector3, faces: Array, spacing: float) -> void:
	var dp := s.add_painter(func (p, n, v, w): return CREAM.darkened(clampf(-n.y, 0.0, 1.0) * 0.3))
	for face: Vector3 in faces:
		var a := Vector3(1, 0, 0) if absf(face.x) < 0.5 else Vector3(0, 0, 1)
		var b := face.cross(a).abs()
		var ext_a := (size * a).length() * 0.5 - 0.05; var ext_b := (size * b).length() * 0.5 - 0.05
		var row := 0
		var u := -ext_a
		while u <= ext_a:
			var vv := -ext_b + (spacing * 0.5 if row % 2 == 1 else 0.0)
			while vv <= ext_b:
				var at := center + a * u + b * vv + face * ((size * face.abs()).length() * 0.5 + 0.004)
				if absf((at - center).x) > 0.11 and absf((at - center).z) > 0.11:
					s.blob(at, Vector3(0.032, 0.032, 0.032) * (Vector3.ONE - face.abs() * 0.85), dp, {"lat": 4, "lon": 8})
				vv += spacing
			u += spacing * 0.87; row += 1


static func ribbon(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return RIBBON.lightened(clampf(n.y, 0.0, 1.0) * 0.2 + absf(Sculpt.noise(p * 30.0)) * 0.1).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)


## B: a wrapped present in teal polka-dot paper and red ribbon, its big bow flopping like
## ears. Glowing eyes stare out of the dark gap under the lid, and the lower half of the
## box drops open on a mouth of candy-corn teeth with a long ribbon tongue.
func _giftbox() -> Node3D:
	var head := joint(root, "Head", Vector3(0, 0.75, 0.05))
	var hs := Sculpt.new(); var pp := hs.add_painter(polka); var rp := hs.add_painter(ribbon)
	var gap := hs.add_painter(func (p, n, v, w): return MOUTH)
	var corn := hs.add_painter(func (p, n, v, w): return Color("#fff6e0") if v > 0.62 else Color("#f39a2a") if v > 0.3 else Color("#f6d23c"))
	# Upper box, a dark slit, then the lid sitting proud on top.
	slab(hs, pp, Vector3(0, 0.71, 0.02), Vector3(0.92, 0.3, 0.84), Basis.IDENTITY, 0.12, 0.0)
	slab(hs, pp, Vector3(0, 0.89, 0.16), Vector3(0.92, 0.12, 0.56), Basis.IDENTITY, 0.2, 0.0)
	slab(hs, gap, Vector3(0, 0.89, -0.15), Vector3(0.88, 0.1, 0.5), Basis.IDENTITY, 0.2, 0.0)
	_dots(hs, Vector3(0, 0.71, 0.02), Vector3(0.92, 0.3, 0.84), [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3.BACK], 0.15)
	_dots(hs, Vector3(0, 1.0, 0.02), Vector3(1.0, 0.16, 0.92), [Vector3.UP], 0.17)
	slab(hs, pp, Vector3(0, 1.0, 0.02), Vector3(1.0, 0.16, 0.92), Basis.IDENTITY, 0.25, 0.02)
	# Ribbon crossing the lid and running down the box.
	slab(hs, rp, Vector3(0, 1.0, 0.02), Vector3(0.16, 0.18, 0.94), Basis.IDENTITY, 0.25, 0.0)
	slab(hs, rp, Vector3(0, 1.0, 0.02), Vector3(1.02, 0.18, 0.16), Basis.IDENTITY, 0.25, 0.0)
	slab(hs, rp, Vector3(0, 0.71, 0.02), Vector3(0.16, 0.32, 0.86), Basis.IDENTITY, 0.12, 0.0)
	slab(hs, rp, Vector3(0, 0.71, 0.02), Vector3(0.94, 0.32, 0.16), Basis.IDENTITY, 0.12, 0.0)
	# Upper candy-corn teeth along the front edge.
	_teeth(hs, corn, Vector3(-0.38, 0.58, -0.43), Vector3(0.38, 0.58, -0.43), 6, Vector3(0, -1, -0.08), 0.2, 0.06)
	hs.blob(Vector3(0, 1.1, 0.02), Vector3(0.1, 0.07, 0.1), rp, {"lat": 5, "lon": 9})
	part(head, "Box", hs, shiny)
	var core := _eyes(head, [Vector3(-0.17, 0.9, -0.41), Vector3(0.17, 0.9, -0.41)], 0.06, Vector3(0, 0.05, -1))
	# The bow: two big loops on their own joints so they flop, and two trailing tails.
	var ears: Array = []
	for side in [-1.0, 1.0]:
		var knot := Vector3(0.06 * side, 1.12, 0.02)
		var ear := joint(head, ("Left" if side < 0 else "Right") + "BowLoop", knot)
		var bs := Sculpt.new(); var bp := bs.add_painter(ribbon)
		bs.tube([knot, knot + Vector3(0.14 * side, 0.18, -0.04), knot + Vector3(0.32 * side, 0.2, 0.0), knot + Vector3(0.3 * side, 0.05, 0.04), knot + Vector3(0.1 * side, -0.01, 0.02)], [0.05, 0.06, 0.07, 0.06, 0.05], bp, {"sides": 10, "per": 4, "flat": 0.3, "side": Vector3.FORWARD})
		bs.tube([knot, knot + Vector3(0.12 * side, -0.06, -0.12), knot + Vector3(0.2 * side, -0.1, -0.3)], [0.05, 0.055, 0.06], bp, {"sides": 8, "per": 3, "flat": 0.25, "side": Vector3.UP, "cap_len": 0.2})
		part(ear, "BowLoop", bs, shiny)
		ears.append(ear)
	# The jaw: the lower half of the box.
	var jaw := joint(head, "Jaw", Vector3(0, 0.52, 0.42))
	var js := Sculpt.new(); var jp := js.add_painter(polka); var jr := js.add_painter(ribbon); var jg := js.add_painter(func (p, n, v, w): return MOUTH.lightened(0.04))
	var jc := js.add_painter(func (p, n, v, w): return Color("#fff6e0") if v > 0.62 else Color("#f39a2a") if v > 0.3 else Color("#f6d23c"))
	slab(js, jp, Vector3(0, 0.43, 0.02), Vector3(0.92, 0.24, 0.84), Basis.IDENTITY, 0.15, 0.0)
	slab(js, jr, Vector3(0, 0.43, 0.02), Vector3(0.16, 0.26, 0.86), Basis.IDENTITY, 0.15, 0.0)
	slab(js, jr, Vector3(0, 0.43, 0.02), Vector3(0.94, 0.26, 0.16), Basis.IDENTITY, 0.15, 0.0)
	slab(js, jg, Vector3(0, 0.55, -0.02), Vector3(0.82, 0.03, 0.72), Basis.IDENTITY, 0.3, 0.0)
	_dots(js, Vector3(0, 0.43, 0.02), Vector3(0.92, 0.24, 0.84), [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3.BACK], 0.15)
	_teeth(js, jc, Vector3(-0.33, 0.54, -0.41), Vector3(0.33, 0.54, -0.41), 5, Vector3(0, 1, -0.08), 0.17, 0.055)
	# A long striped ribbon tongue lolling out over the lower lip.
	var tongue := js.add_painter(func (p, n, v, w): return TONGUE.lerp(CREAM, smoothstep(0.45, 0.5, fposmod(v * 5.0, 1.0)) * 0.7))
	js.tube([Vector3(0.0, 0.57, 0.05), Vector3(0.02, 0.58, -0.3), Vector3(0.05, 0.52, -0.48), Vector3(0.08, 0.36, -0.52)], [0.07, 0.08, 0.075, 0.06], tongue, {"sides": 10, "per": 3, "flat": 2.2, "side": Vector3.RIGHT, "cap_len": 0.5})
	part(jaw, "LowerBox", js, shiny)
	# Candy-cane legs, curling out from under the corners like a spider's.
	var cane := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var stripe := fposmod(p.y * 9.0 + atan2(p.z, p.x) * 0.0 + (p.x + p.z) * 6.0, 1.0)
		return CREAM.lerp(RIBBON, smoothstep(0.45, 0.5, stripe) * smoothstep(0.95, 0.9, stripe)).lightened(clampf(n.y, 0.0, 1.0) * 0.15)
	var foot := func (s: Sculpt, at: Vector3) -> void:
		var fp := s.add_painter(func (p, n, v, w): return RIBBON.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
		s.blob(at + Vector3(0, 0.0, 0), Vector3(0.05, 0.04, 0.05), fp, {"lat": 5, "lon": 8})
	var legs := _legs([Vector3(-0.36, 0.34, -0.26), Vector3(0.36, 0.34, -0.26), Vector3(-0.36, 0.34, 0.3), Vector3(0.36, 0.34, 0.3)], 0.6, 0.16, 0.04, cane, foot, shiny)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.1)
	return _with_visual(node, head, legs[0], legs[1], jaw, ears)


# --------------------------------------------------------------- C: choco bar

## C: a long chocolate bar half out of its blue wrapper, low to the ground like a crocodile.
## The torn-open front is the snout: chocolate jaws studded with pieces of the bar, silver foil
## curling back from the tear, eyes bulging on top and a crimped wrapper end for a tail.
func _chocobar() -> Node3D:
	var wrap := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := WRAP_BLUE.lerp(Color("#f2c230"), smoothstep(0.03, 0.0, absf(p.y - 0.52) - 0.04) * float(p.z > 0.0))
		c = c.lerp(Color("#f4f0e6"), smoothstep(0.012, 0.0, absf(p.y - 0.52) - 0.06) * float(p.z > 0.0) * 0.0)
		return c.lightened(clampf(n.y, 0.0, 1.0) * 0.18 + absf(Sculpt.noise(p * 14.0)) * 0.15).darkened(clampf(-n.y, 0.0, 1.0) * 0.35)
	var choc := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var groove := minf(absf(fposmod(p.x * 6.0 + 0.5, 1.0) - 0.5), absf(fposmod(p.z * 6.0, 1.0) - 0.5))
		return CHOC.lerp(CHOC_HI, clampf(0.3 + n.y * 0.4, 0.0, 1.0)).darkened(smoothstep(0.08, 0.02, groove) * 0.35 * clampf(n.y, 0.0, 1.0))
	var foil := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return FOIL.lightened(absf(Sculpt.noise(p * 25.0)) * 0.3).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)
	var head := joint(root, "Head", Vector3(0, 0.52, -0.3))
	var bs := Sculpt.new(); var wp := bs.add_painter(wrap); var cp := bs.add_painter(choc); var fp := bs.add_painter(foil)
	var dark := bs.add_painter(func (p, n, v, w): return MOUTH)
	var tooth := bs.add_painter(func (p, n, v, w): return CHOC_HI.lerp(CHOC, v * 0.5))
	# The wrapped back two thirds of the bar.
	bs.tube([Vector3(0, 0.5, 0.75), Vector3(0, 0.52, 0.3), Vector3(0, 0.53, -0.15)], [0.22, 0.24, 0.24], wp, {"sides": 16, "per": 3, "flat": 1.7, "side": Vector3.RIGHT, "square": 0.75, "cap0": false, "cap1": false, "lump": 0.08})
	# A label band round the middle.
	bs.tube([Vector3(0, 0.52, 0.12), Vector3(0, 0.52, 0.32)], [0.255, 0.255], bs.add_painter(func (p, n, v, w): return Color("#f2c230").lightened(clampf(n.y, 0.0, 1.0) * 0.2).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)), {"sides": 16, "per": 1, "flat": 1.7, "side": Vector3.RIGHT, "square": 0.75, "cap0": false, "cap1": false})
	# The upper jaw: bare chocolate snout, square-scored, ending in the dark mouth.
	bs.tube([Vector3(0, 0.55, -0.12), Vector3(0, 0.55, -0.45), Vector3(0, 0.53, -0.72)], [0.15, 0.15, 0.13], cp, {"sides": 14, "per": 3, "flat": 2.4, "side": Vector3.RIGHT, "square": 0.85, "cap0": false, "cap_len": 0.4})
	bs.tube([Vector3(0, 0.44, -0.2), Vector3(0, 0.45, -0.68)], [0.04, 0.035], dark, {"sides": 8, "per": 2, "flat": 7.0, "side": Vector3.RIGHT, "cap_len": 0.5})
	_teeth(bs, tooth, Vector3(-0.3, 0.46, -0.66), Vector3(-0.32, 0.46, -0.2), 5, Vector3(0, -1, 0), 0.1, 0.035)
	_teeth(bs, tooth, Vector3(0.3, 0.46, -0.66), Vector3(0.32, 0.46, -0.2), 5, Vector3(0, -1, 0), 0.1, 0.035)
	_teeth(bs, tooth, Vector3(-0.2, 0.46, -0.74), Vector3(0.2, 0.46, -0.74), 4, Vector3(0, -1, -0.2), 0.1, 0.035)
	# Torn wrapper and foil peeling back from the tear like a collar.
	for k in range(9):
		var ang := TAU * k / 9.0
		var dir := Vector3(cos(ang) * 1.7, sin(ang), 0).normalized()
		var at := Vector3(dir.x * 0.38, 0.52 + dir.y * 0.23, -0.15)
		var painter := wp if k % 2 == 0 else fp
		bs.tube([at, at + dir * 0.06 + Vector3(0, 0, -0.08), at + dir * 0.13 + Vector3(0, 0, -0.05)], [0.07, 0.05, 0.008], painter, {"sides": 6, "per": 2, "flat": 0.22, "side": dir, "cap0": false})
	# Eye bumps on top of the snout, like a crocodile's.
	for side in [-1.0, 1.0]: bs.blob(Vector3(0.13 * side, 0.68, -0.22), Vector3(0.09, 0.07, 0.09), cp, {"lat": 6, "lon": 9})
	part(head, "Bar", bs, shiny)
	var core := _eyes(head, [Vector3(-0.13, 0.72, -0.27), Vector3(0.13, 0.72, -0.27)], 0.055, Vector3(0, 0.3, -1))
	# The crimped wrapper end at the back is the tail.
	var tail := joint(root, "WrapperTail", Vector3(0, 0.5, 0.75))
	var ts := Sculpt.new(); var tp := ts.add_painter(wrap)
	ts.tube([Vector3(0, 0.5, 0.72), Vector3(0, 0.5, 0.86), Vector3(0, 0.49, 0.98), Vector3(0, 0.5, 1.12)], [0.2, 0.08, 0.1, 0.22], tp, {"sides": 14, "per": 3, "flat": 1.8, "side": Vector3.RIGHT, "ridges": 9, "ridge": 0.3, "cap0": false, "cap_len": 0.1, "cap_rings": 2})
	part(tail, "CrimpedEnd", ts, foil_mat)
	# The lower jaw.
	var jaw := joint(head, "Jaw", Vector3(0, 0.42, -0.12))
	var js := Sculpt.new(); var jc := js.add_painter(choc); var jt := js.add_painter(func (p, n, v, w): return CHOC_HI.lerp(CHOC, v * 0.5))
	var jd := js.add_painter(func (p, n, v, w): return Color("#e09a3c").lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	js.tube([Vector3(0, 0.36, -0.14), Vector3(0, 0.36, -0.45), Vector3(0, 0.37, -0.7)], [0.08, 0.08, 0.07], jc, {"sides": 12, "per": 3, "flat": 4.2, "side": Vector3.RIGHT, "square": 0.85, "cap0": false, "cap_len": 0.5})
	js.blob(Vector3(0, 0.43, -0.4), Vector3(0.18, 0.025, 0.22), jd, {"lat": 4, "lon": 10, "lump": 0.2})
	_teeth(js, jt, Vector3(-0.28, 0.42, -0.64), Vector3(-0.3, 0.42, -0.2), 5, Vector3(0, 1, 0), 0.09, 0.033)
	_teeth(js, jt, Vector3(0.28, 0.42, -0.64), Vector3(0.3, 0.42, -0.2), 5, Vector3(0, 1, 0), 0.09, 0.033)
	part(jaw, "LowerJaw", js, shiny)
	# Four stubby chocolate-wafer legs.
	var wafer := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#c78a4a").lerp(Color("#e6b071"), clampf(0.5 + w * 0.5, 0.0, 1.0)).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)
	var foot := func (s: Sculpt, at: Vector3) -> void:
		var fc := s.add_painter(choc)
		s.blob(at + Vector3(0, 0.01, -0.03), Vector3(0.07, 0.04, 0.09), fc, {"lat": 5, "lon": 8})
	var legs := _legs([Vector3(-0.32, 0.42, -0.2), Vector3(0.32, 0.42, -0.2), Vector3(-0.32, 0.42, 0.5), Vector3(0.32, 0.42, 0.5)], 0.4, 0.02, 0.055, wafer, foot, material)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.2)
	return _with_visual(node, head, legs[0], legs[1], jaw, [], [tail])
