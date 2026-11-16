extends "res://tools/creature_kit.gd"
## The Grassland Colossus of the Windbell Plains, sculpted by hand: a slow giant of earth and
## grass on root feet that rears up before a broad stomp. About 3.6 m tall.
##   sod   - a giant of stacked turf slabs, a meadow of tall grass and wildflowers growing on
##           its shoulders and a mossy boulder for a head
##   hay   - a giant of round and square hay bales bound with twine, with sheaf arms and a
##           crown of wheat
##   hill  - a hunched giant carrying a grassy hill on its back, with a gnarled little tree and
##           standing stones on top, its small stone face peering out from under the hill

const SOIL := Color("#6b4a2e")
const SOIL_LIGHT := Color("#8a6440")
const GRASS := Color("#5e8a2e")
const GRASS_LIGHT := Color("#9dbb4f")
const STONE := Color("#7d7a70")
const STRAW := Color("#d7b860")
const STRAW_DARK := Color("#a5853c")
const TWINE := Color("#5a3d24")
const GRASS_ROOT := Color("#4f7428")
const GRASS_TIP := Color("#d2c46c")


## Straw grain on limbs (ridges), and a hook that dresses each knee and elbow.
var limb_ridges := 0
var dress_limb := Callable()


func _init() -> void:
	super("res://assets/cast/bark_detail_gray.png")
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GrasslandColossus"
	match variant:
		"sod": return _sod()
		"hay": return _hay()
		"hill": return _hill()
	return null


func _eyes(color: Color) -> void:
	glow.albedo_color = color.darkened(0.25); glow.emission = color
	glow.emission_energy_multiplier = 1.4


# ------------------------------------------------------------------ painters

static func soil(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var g := Sculpt.fbm(p * 3.5)
	var c := SOIL.lerp(SOIL_LIGHT, clampf(0.45 + g * 0.8, 0.0, 1.0))
	c = c.lerp(STONE, smoothstep(0.32, 0.45, Sculpt.noise(p * 6.0)) * 0.7)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.25)


## Turf: grass on the upward faces, soil and pebbles on the sides, with a ragged edge.
static func turf(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var g := Sculpt.fbm(p * 4.0)
	var grass := GRASS.lerp(GRASS_LIGHT, clampf(0.4 + g * 0.9, 0.0, 1.0))
	return soil(p, n, v, w).lerp(grass, smoothstep(0.25, 0.55, n.y + g * 0.35))


static func stone(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var g := Sculpt.fbm(p * 5.0)
	var c := STONE.lerp(Color("#a19d90"), clampf(0.4 + g, 0.0, 1.0))
	return c.lerp(Color("#5d7a33"), smoothstep(0.35, 0.7, n.y + g * 0.4) * 0.8)


static func straw(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var streak := Sculpt.noise(Vector3(p.x * 40.0, p.y * 6.0, p.z * 40.0))
	var c := STRAW.lerp(STRAW_DARK, clampf(0.3 + streak * 1.1, 0.0, 1.0))
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.2 + clampf(-w, 0.0, 1.0) * 0.25).lightened(clampf(w, 0.0, 1.0) * 0.12)


func grass_paint() -> Callable:
	return func (p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
		var shade := Sculpt.noise(p * 7.0)
		return GRASS_ROOT.lerp(GRASS_TIP, clampf(v * 1.1 + shade * 0.25, 0.0, 1.0)).darkened(0.06 + shade * 0.08)


# ------------------------------------------------------------------ pieces

func blade(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, thin: Vector3, droop := 0.25) -> Vector3:
	var d := dir.normalized()
	var mid := base + d * length * 0.5 + Vector3(0, -length * droop * 0.25, 0)
	var tip := base + d * length + Vector3(0, -length * droop, 0)
	s.tube([base, mid, tip], [width, width * 0.8, 0.002], painter, {"sides": 5, "per": 1, "flat": 0.18, "side": thin, "cap_rings": 1, "cap1": false})
	return tip


## A clump of tall grass blades springing from a patch of ground.
func grass_clump(s: Sculpt, painter: int, center: Vector3, radius: float, count: int, height: float, lean := Vector3.ZERO) -> void:
	for k in range(count):
		var ang := k * 2.399 + center.x * 3.0
		var r := radius * sqrt((k + 0.5) / count)
		var radial := Vector3(cos(ang), 0, sin(ang))
		var base := center + radial * r
		var dir := radial * 0.3 + Vector3.UP + lean
		blade(s, painter, base, dir, height * (0.7 + 0.5 * absf(Sculpt.noise(base * 9.0))), 0.022, radial, 0.3)


## A seed head of wheat: plump grains along the top of a stalk.
func wheat(s: Sculpt, stalk: int, grain: int, base: Vector3, dir: Vector3, length: float) -> void:
	var d := dir.normalized()
	var top := base + d * length
	s.tube([base, base.lerp(top, 0.5) + Vector3(0, 0.02, 0), top], [0.008, 0.007, 0.005], stalk, {"sides": 4, "per": 1, "cap_rings": 1})
	for k in range(5):
		var at := top + d * (0.02 + k * 0.022)
		var side := d.cross(Vector3.UP).normalized() * (0.012 if k % 2 == 0 else -0.012)
		s.blob(at + side, Vector3(0.012, 0.012, 0.02), grain, {"lat": 3, "lon": 5, "basis": Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.BACK)})


## Root feet: a broad earthen foot with roots spreading from it into the ground.
func root_foot(s: Sculpt, skin: int, at: Vector3, side: float) -> void:
	s.blob(at + Vector3(0, 0.08, -0.05), Vector3(0.3, 0.15, 0.36), skin, {"lat": 6, "lon": 10, "lump": 0.35})
	var dirs: Array = []
	for k in range(6):
		var ang := -PI * 0.5 + (k - 2.5) * 0.42 + (0.2 * side if k > 3 else 0.0)
		dirs.append(Vector3(cos(ang) * 0.9 + side * 0.15, 0.0, sin(ang)).normalized())
	roots(s, skin, at + Vector3(0, 0.06, -0.05), dirs, 0.5, 0.075, 0.08)


## Legs: thick earthen pillars on root feet. Returns [hips, knees].
func earth_legs(skin: Callable, hip_y: float, width: float, radius: float) -> Array:
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(width * side, hip_y, 0.04)
		var knee_at := Vector3((width + 0.04) * side, hip_y * 0.52, -0.06)
		var ankle := Vector3((width + 0.06) * side, 0.2, -0.02)
		var hip := joint(root, label + "Leg", hip_at)
		var us := Sculpt.new(); var up := us.add_painter(skin)
		us.tube([hip_at + Vector3(0, 0.1, 0), hip_at.lerp(knee_at, 0.5), knee_at], [radius, radius * 0.85, radius * 0.75], up, {"sides": 11 if limb_ridges == 0 else 18, "per": 3, "lump": 0.25, "ridges": limb_ridges, "ridge": 0.06})
		part(hip, "Thigh", us)
		var knee := joint(hip, label + "Knee", knee_at)
		var ls := Sculpt.new(); var lp := ls.add_painter(skin)
		ls.blob(knee_at, Vector3.ONE * radius * 0.8, lp, {"lat": 6, "lon": 9, "lump": 0.3})
		ls.tube([knee_at, knee_at.lerp(ankle, 0.5), ankle], [radius * 0.75, radius * 0.78, radius * 0.9], lp, {"sides": 11 if limb_ridges == 0 else 18, "per": 3, "lump": 0.25, "ridges": limb_ridges, "ridge": 0.06})
		root_foot(ls, lp, Vector3(ankle.x, 0.0, ankle.z), side)
		if dress_limb.is_valid(): dress_limb.call(ls, knee_at + Vector3(0, 0.0, -radius * 0.6), side, "knee")
		part(knee, "Shin", ls)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


## Arms: long heavy arms; `fist` builds each hand. Returns [shoulders, elbows].
func earth_arms(skin: Callable, shoulder: Vector3, elbow: Vector3, wrist: Vector3, radius: float, fist: Callable) -> Array:
	var shoulders: Array = []; var elbows: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var sh := Vector3(shoulder.x * side, shoulder.y, shoulder.z)
		var el := Vector3(elbow.x * side, elbow.y, elbow.z)
		var wr := Vector3(wrist.x * side, wrist.y, wrist.z)
		var arm := joint(root, label + "Arm", sh)
		var us := Sculpt.new(); var up := us.add_painter(skin)
		us.tube([sh, sh.lerp(el, 0.5), el], [radius, radius * 0.85, radius * 0.8], up, {"sides": 10 if limb_ridges == 0 else 18, "per": 3, "lump": 0.28, "ridges": limb_ridges, "ridge": 0.06})
		us.blob(el, Vector3.ONE * radius * 0.85, up, {"lat": 6, "lon": 9, "lump": 0.3})
		part(arm, "Upper", us)
		var fore := joint(arm, label + "Forearm", el)
		var fs := Sculpt.new(); var fp := fs.add_painter(skin)
		fs.tube([el, el.lerp(wr, 0.5), wr], [radius * 0.8, radius * 0.85, radius * 0.9], fp, {"sides": 10 if limb_ridges == 0 else 18, "per": 3, "lump": 0.28, "ridges": limb_ridges, "ridge": 0.06})
		fist.call(fs, fp, wr, side)
		if dress_limb.is_valid(): dress_limb.call(fs, el + Vector3(side * radius * 0.4, 0.05, radius * 0.3), side, "elbow")
		part(fore, "Forearm", fs)
		shoulders.append(arm); elbows.append(fore)
	return [shoulders, elbows]


func _close(head: Node3D, core: Node3D, arms: Array, legs: Array, fronds: Array, scale: float) -> Node3D:
	var node := _finish({"head": head, "core": core, "arms": arms[0], "forearms": arms[1], "feet": legs[0], "knees": legs[1], "leaves": fronds}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var features := {}
	if not fronds.is_empty(): features[&"fronds"] = fronds.map(func (n): return node.get_path_to(n))
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": features}
	node.set_meta("rig_bindings", rig)
	return node


func _frond(fronds: Array, parent: Node3D, name: String, at: Vector3, s: Sculpt) -> void:
	var j := joint(parent, name, at)
	part(j, "Grass", s)
	fronds.append(j)


## Glowing eyes set deep in a dark slit.
func _eye_slit(hs: Sculpt, at: Vector3, spread: float, size: float) -> Sculpt:
	var dark := hs.add_painter(func (p, n, v, w): return Color("#120d08"))
	hs.blob(at, Vector3(spread + size * 1.6, size * 1.1, size * 0.8), dark, {"lat": 4, "lon": 8})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(at + Vector3(spread * side, 0, -size * 0.45), Vector3(size, size * 0.7, size * 0.5), white, {"lat": 4, "lon": 7})
	return es


# ------------------------------------------------------------------ A: sod giant

func _sod() -> Node3D:
	_eyes(Color("#d7ff6a"))
	var skin := func (p, n, v, w): return soil(p, n, v, w)
	dress_limb = func (s: Sculpt, at: Vector3, side: float, kind: String) -> void:
		var g := s.add_painter(grass_paint()); var m := s.add_painter(moss)
		moss_clump(s, m, at, 0.12, 3)
		grass_clump(s, g, at + Vector3(0, 0.04, 0), 0.1, 7, 0.22, Vector3(side * 0.3, 0, 0))
	var legs := earth_legs(skin, 1.3, 0.36, 0.3)
	var body := Sculpt.new(); var tp := body.add_painter(turf); var sp := body.add_painter(stone)
	var gp := body.add_painter(grass_paint())
	# A torso of turf slabs stacked like cut sods, each a little askew, grass hanging over
	# their edges and stones pressed into the soil.
	var slabs := [[1.42, 1.05, 0.78, 0.08, 0.02], [1.78, 1.32, 0.9, -0.1, -0.03], [2.12, 1.55, 0.96, 0.06, 0.0], [2.42, 1.42, 0.86, -0.05, -0.04]]
	for k in range(slabs.size()):
		var sl: Array = slabs[k]
		var c := Vector3(0.04 * (k % 2 * 2 - 1), sl[0], sl[4])
		slab(body, tp, c, Vector3(sl[1], 0.38, sl[2]), Basis(Vector3.UP, sl[3]), 0.45, 0.12)
		for e in range(10):
			var ang := TAU * e / 10.0 + k
			var edge := c + Vector3(cos(ang) * float(sl[1]) * 0.48, 0.17, sin(ang) * float(sl[2]) * 0.48)
			var out := Vector3(cos(ang), 0, sin(ang))
			blade(body, gp, edge, out + Vector3(0, -0.6, 0), 0.16 + 0.06 * absf(Sculpt.noise(edge * 5.0)), 0.022, Vector3(-sin(ang), 0, cos(ang)).cross(out + Vector3(0, -0.6, 0)).normalized(), 0.15)
		for st in range(3):
			var ang := st * 2.1 + k * 1.3
			body.rock(c + Vector3(cos(ang) * float(sl[1]) * 0.5, -0.04, sin(ang) * float(sl[2]) * 0.5), Vector3(0.09, 0.07, 0.08), sp)
	# Shoulders: big mossy boulders.
	for side in [-1.0, 1.0]:
		body.rock(Vector3(0.72 * side, 2.38, 0.0), Vector3(0.32, 0.26, 0.32), sp, {"lat": 6, "lon": 9})
	var fist := func (s: Sculpt, painter: int, wr: Vector3, side: float) -> void:
		var stone_p := s.add_painter(stone)
		s.rock(wr + Vector3(0, -0.18, -0.04), Vector3(0.27, 0.25, 0.27), stone_p, {"lat": 6, "lon": 9})
		var rp := s.add_painter(bark)
		roots(s, rp, wr + Vector3(0, 0.1, 0), [Vector3(side * 0.3, -1, -0.4), Vector3(-side * 0.4, -1, 0.2), Vector3(0, -1, 0.5)], 0.42, 0.04, 0.05, true)
	var arms := earth_arms(skin, Vector3(0.78, 2.3, 0.0), Vector3(0.98, 1.62, -0.08), Vector3(1.03, 1.08, -0.12), 0.24, fist)

	var head := joint(root, "Head", Vector3(0, 2.62, -0.2))
	var hs := Sculpt.new(); var hsp := hs.add_painter(stone)
	hs.rock(Vector3(0, 2.78, -0.24), Vector3(0.3, 0.26, 0.28), hsp, {"lat": 7, "lon": 10})
	hs.rock(Vector3(0, 2.92, -0.3), Vector3(0.24, 0.08, 0.16), hsp)
	var es := _eye_slit(hs, Vector3(0, 2.8, -0.49), 0.1, 0.042)
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	part(root, "Body", body)

	# A meadow on its shoulders and head: tall grass, wildflowers and wheat, swaying.
	var fronds: Array = []
	for side in [-1.0, 1.0]:
		var ms := Sculpt.new(); var mg := ms.add_painter(grass_paint())
		var top := Vector3(0.72 * side, 2.6, 0.0)
		grass_clump(ms, mg, top, 0.22, 16, 0.42, Vector3(side * 0.2, 0, 0.1))
		flowers(ms, [top + Vector3(0.1 * side, 0.02, -0.12), top + Vector3(-0.08 * side, 0.03, 0.1), top + Vector3(0.15 * side, 0.0, 0.08)], 0.05)
		_frond(fronds, arms[0][0 if side < 0 else 1], "Meadow", top, ms)
	var crown := Sculpt.new(); var cg := crown.add_painter(grass_paint())
	grass_clump(crown, cg, Vector3(0, 3.0, -0.28), 0.18, 14, 0.36, Vector3(0, 0, 0.25))
	_frond(fronds, head, "Crown", Vector3(0, 3.0, -0.28), crown)
	var back := Sculpt.new(); var bg := back.add_painter(grass_paint())
	var stalk := back.add_painter(func (p, n, v, w): return Color("#b39c5a"))
	var grain := back.add_painter(func (p, n, v, w): return Color("#e0c46e").darkened(Sculpt.noise(p * 30.0) * 0.1))
	grass_clump(back, bg, Vector3(0, 2.62, 0.18), 0.4, 22, 0.5, Vector3(0, 0, 0.3))
	for k in range(5):
		var ang := k * 1.3
		wheat(back, stalk, grain, Vector3(cos(ang) * 0.25, 2.6, 0.2 + sin(ang) * 0.2), Vector3(cos(ang) * 0.3, 1.0, 0.3), 0.45)
	flowers(back, [Vector3(-0.3, 2.62, 0.05), Vector3(0.28, 2.62, 0.3), Vector3(0.05, 2.63, 0.42)], 0.05)
	_frond(fronds, root, "Meadow", Vector3(0, 2.62, 0.18), back)
	return _close(head, core, arms, legs, fronds, 1.2)


# ------------------------------------------------------------------ B: haybale colossus

func _hay() -> Node3D:
	_eyes(Color("#ffb347"))
	var skin := func (p, n, v, w): return straw(p, n, v, w)
	limb_ridges = 16
	dress_limb = func (s: Sculpt, at: Vector3, side: float, kind: String) -> void:
		var tw2 := s.add_painter(func (p, n, v, w): return TWINE)
		var sp3 := s.add_painter(straw)
		s.blob(at, Vector3(0.05, 0.05, 0.05), tw2, {"lat": 3, "lon": 5})
		for k in range(8):
			var ang := TAU * k / 8.0
			s.tube([at, at + Vector3(cos(ang) * 0.14 + side * 0.05, -0.04 + sin(ang) * 0.1, -0.08)], [0.012, 0.002], sp3, {"sides": 3, "per": 1, "cap_rings": 1, "cap1": false})
	var body := Sculpt.new(); var hp := body.add_painter(straw)
	var tw := body.add_painter(func (p, n, v, w): return TWINE.lightened(Sculpt.noise(p * 20.0) * 0.1))
	var gp := body.add_painter(grass_paint())
	# A round bale for a belly and chest, standing on end like a great wheel, with twine
	# bands; square bales stacked on its shoulders.
	body.tube([Vector3(-0.56, 1.85, 0.02), Vector3(0.56, 1.85, 0.02)], [0.68, 0.68], hp, {"sides": 40, "per": 1, "cap_rings": 3, "cap_len": 0.25, "lump": 0.08, "ridges": 40, "ridge": 0.035})
	for k in range(3):
		var x := -0.32 + k * 0.32
		body.tube([Vector3(x - 0.015, 1.85, 0.02), Vector3(x + 0.015, 1.85, 0.02)], [0.695, 0.695], tw, {"sides": 22, "per": 1, "cap0": false, "cap1": false})
	# A spiral swirl on each flat face of the round bale.
	for side in [-1.0, 1.0]:
		var pts: Array = []; var radii: Array = []
		for k in range(28):
			var t := k / 27.0
			var ang := t * TAU * 3.0
			pts.append(Vector3(0.615 * side + side * 0.035, 1.85 + sin(ang) * t * 0.55, 0.02 + cos(ang) * t * 0.55))
			radii.append(0.012)
		body.tube(pts, radii, body.add_painter(func (p, n, v, w): return STRAW_DARK.darkened(0.15)), {"sides": 4, "per": 1, "flat": 0.4, "side": Vector3.RIGHT, "cap_rings": 1})
	for side in [-1.0, 1.0]:
		slab(body, hp, Vector3(0.72 * side, 2.48, 0.0), Vector3(0.62, 0.36, 0.5), Basis(Vector3.UP, 0.12 * side), 0.25, 0.08)
		for k in range(2):
			var z := -0.12 + k * 0.24
			body.tube([Vector3(0.72 * side, 2.665, z), Vector3(0.72 * side + 0.32 * side, 2.48, z), Vector3(0.72 * side, 2.295, z)], [0.014, 0.014, 0.014], tw, {"sides": 4, "per": 2, "cap_rings": 1})
	slab(body, hp, Vector3(0, 1.22, 0.02), Vector3(0.9, 0.34, 0.55), Basis.IDENTITY, 0.25, 0.08)
	# Loose straw sticking out everywhere.
	for k in range(90):
		var a := k * 2.399; var b := k * 0.77
		var dir := Vector3(cos(a), sin(b) * 0.6, sin(a)).normalized()
		var at := Vector3(dir.x * 0.6, 1.85 + dir.y * 0.66, 0.02 + dir.z * 0.66) if k < 60 else Vector3((0.72 + dir.x * 0.3) * (1.0 if k % 2 == 0 else -1.0), 2.48 + dir.y * 0.2, dir.z * 0.25)
		blade(body, hp, at, dir + Vector3(0, 0.2, 0), 0.12 + 0.08 * absf(Sculpt.noise(at * 7.0)), 0.011, dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.95 else Vector3.RIGHT, 0.25)
	# Legs: straw bundles tied with twine, on root feet.
	var legs := earth_legs(skin, 1.25, 0.36, 0.26)
	var fist := func (s: Sculpt, painter: int, wr: Vector3, side: float) -> void:
		s.blob(wr + Vector3(0, -0.16, -0.03), Vector3(0.22, 0.24, 0.22), painter, {"lat": 6, "lon": 9, "lump": 0.25})
		var twp := s.add_painter(func (p, n, v, w): return TWINE)
		s.tube([wr + Vector3(0, 0.05, 0), wr + Vector3(0, 0.0, 0)], [0.235, 0.235], twp, {"sides": 12, "per": 1, "cap0": false, "cap1": false})
		var sp2 := s.add_painter(straw)
		for k in range(7):
			var ang := TAU * k / 7.0
			s.tube([wr + Vector3(cos(ang) * 0.12, -0.3, sin(ang) * 0.12), wr + Vector3(cos(ang) * 0.2, -0.46, sin(ang) * 0.2 - 0.04)], [0.03, 0.004], sp2, {"sides": 4, "per": 1, "cap_rings": 1, "cap1": false})
	var arms := earth_arms(skin, Vector3(0.82, 2.3, 0.0), Vector3(1.0, 1.65, -0.08), Vector3(1.04, 1.1, -0.12), 0.21, fist)

	# The head: a small square bale with straw fringe, glowing eyes, and a crown of wheat.
	var head := joint(root, "Head", Vector3(0, 2.6, -0.12))
	var hs := Sculpt.new(); var hsp := hs.add_painter(straw)
	slab(hs, hsp, Vector3(0, 2.86, -0.18), Vector3(0.5, 0.42, 0.42), Basis.IDENTITY, 0.35, 0.1)
	var htw := hs.add_painter(func (p, n, v, w): return TWINE)
	hs.tube([Vector3(-0.26, 3.08, -0.18), Vector3(0, 3.1, -0.18), Vector3(0.26, 3.08, -0.18)], [0.014, 0.014, 0.014], htw, {"sides": 4, "per": 2, "cap_rings": 1})
	var es := _eye_slit(hs, Vector3(0, 2.86, -0.39), 0.1, 0.04)
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	part(root, "Body", body)
	var fronds: Array = []
	var crown := Sculpt.new(); var stalk := crown.add_painter(func (p, n, v, w): return Color("#b39c5a"))
	var grain := crown.add_painter(func (p, n, v, w): return Color("#e0c46e").darkened(Sculpt.noise(p * 30.0) * 0.1))
	for k in range(9):
		var ang := TAU * k / 9.0
		wheat(crown, stalk, grain, Vector3(cos(ang) * 0.12, 3.06, -0.18 + sin(ang) * 0.1), Vector3(cos(ang) * 0.45, 1.0, sin(ang) * 0.35 + 0.1), 0.32)
	_frond(fronds, head, "Wheat", Vector3(0, 3.06, -0.18), crown)
	return _close(head, core, arms, legs, fronds, 1.2)


# ------------------------------------------------------------------ C: barrow hill

func _hill() -> Node3D:
	_eyes(Color("#9dfff0"))
	var skin := func (p, n, v, w): return soil(p, n, v, w)
	var legs := earth_legs(skin, 1.15, 0.38, 0.3)
	var body := Sculpt.new(); var sp := body.add_painter(soil); var tp := body.add_painter(turf); var st := body.add_painter(stone)
	var rp := body.add_painter(bark)
	# A hunched trunk of earth and tangled roots under a grassy hill it carries on its back.
	body.tube([Vector3(0, 1.2, 0.08), Vector3(0, 1.6, 0.04), Vector3(0, 1.95, -0.12), Vector3(0, 2.15, -0.3)], [0.45, 0.5, 0.52, 0.4], sp, {"sides": 14, "per": 3, "flat": 1.25, "lump": 0.25})
	for k in range(7):
		var ang := k * 0.9
		var from := Vector3(cos(ang) * 0.5, 1.4 + k * 0.1, -0.25 + sin(ang) * 0.2)
		body.tube([from, from + Vector3(-cos(ang) * 0.2, 0.25, -0.12), from + Vector3(-cos(ang) * 0.35, 0.5, -0.05)], [0.04, 0.035, 0.02], rp, {"sides": 5, "per": 2, "cap_rings": 1, "lump": 0.3})
	body.rock(Vector3(0, 2.32, 0.25), Vector3(1.05, 0.62, 0.95), tp, {"lat": 12, "lon": 20, "lump": 0.18})
	body.blob(Vector3(0, 2.05, 0.2), Vector3(0.95, 0.35, 0.85), sp, {"lat": 8, "lon": 14, "lump": 0.3})
	# Standing stones on the hill.
	for spec in [[Vector3(0.45, 2.78, 0.45), 0.1], [Vector3(-0.35, 2.84, 0.55), -0.15], [Vector3(0.6, 2.66, 0.05), 0.25]]:
		body.rock(spec[0] + Vector3(0, 0.12, 0), Vector3(0.13, 0.28, 0.09), st, {"lat": 6, "lon": 8, "lump": 0.3, "basis": Basis(Vector3.FORWARD, spec[1]) * Basis(Vector3.UP, spec[1] * 3.0)})
	var fist := func (s: Sculpt, painter: int, wr: Vector3, side: float) -> void:
		s.blob(wr + Vector3(0, -0.12, -0.02), Vector3(0.24, 0.2, 0.24), painter, {"lat": 6, "lon": 9, "lump": 0.35})
		var rpp := s.add_painter(bark)
		roots(s, rpp, wr + Vector3(0, -0.15, -0.05), [Vector3(side * 0.2, -1, -0.7), Vector3(0, -1, -0.8), Vector3(-side * 0.2, -1, -0.7), Vector3(-side * 0.6, -0.8, -0.1)], 0.4, 0.05, 0.05, true)
	var arms := earth_arms(skin, Vector3(0.7, 2.05, -0.2), Vector3(0.95, 1.35, -0.38), Vector3(1.0, 0.72, -0.45), 0.26, fist)

	# A small stone face peering out from under the front of the hill.
	var head := joint(root, "Head", Vector3(0, 2.05, -0.55))
	var hs := Sculpt.new(); var hsp := hs.add_painter(stone)
	hs.rock(Vector3(0, 2.08, -0.66), Vector3(0.24, 0.2, 0.2), hsp, {"lat": 6, "lon": 9})
	var es := _eye_slit(hs, Vector3(0, 2.1, -0.83), 0.08, 0.035)
	var beard := hs.add_painter(func (p, n, v, w): return GRASS.lerp(Color("#3d5c22"), v))
	for k in range(8):
		var x := (k - 3.5) * 0.045
		hs.tube([Vector3(x, 1.97, -0.8), Vector3(x * 1.1, 1.84, -0.82), Vector3(x * 1.2, 1.7, -0.8)], [0.025, 0.018, 0.003], beard, {"sides": 5, "per": 2, "cap_rings": 1, "cap1": false, "lump": 0.4})
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	part(root, "Body", body)

	# On top of the hill: tall grass, flowers and a gnarled little tree, all swaying.
	var fronds: Array = []
	var top := Sculpt.new(); var tg := top.add_painter(grass_paint())
	for spot in [Vector3(-0.4, 2.82, 0.2), Vector3(0.2, 2.9, 0.3), Vector3(-0.1, 2.85, -0.1), Vector3(0.5, 2.7, 0.55), Vector3(-0.55, 2.6, 0.6)]:
		grass_clump(top, tg, spot, 0.2, 10, 0.32)
	flowers(top, [Vector3(-0.25, 2.88, 0.0), Vector3(0.35, 2.82, 0.4), Vector3(-0.5, 2.7, 0.45), Vector3(0.0, 2.92, 0.5)], 0.05)
	_frond(fronds, root, "HillGrass", Vector3(0, 2.85, 0.25), top)
	var tree := Sculpt.new(); var trp := tree.add_painter(bark); var lp := tree.add_painter(leaf)
	var trunk := [Vector3(-0.1, 2.85, 0.35), Vector3(-0.05, 3.2, 0.4), Vector3(0.08, 3.5, 0.32), Vector3(0.12, 3.75, 0.38)]
	tree.tube(trunk, [0.07, 0.055, 0.045, 0.035], trp, {"sides": 7, "per": 3, "lump": 0.3})
	tree.tube([trunk[2], trunk[2] + Vector3(-0.3, 0.25, 0.05)], [0.03, 0.015], trp, {"sides": 5, "per": 1, "cap_rings": 1})
	for spec in [[Vector3(0.12, 3.85, 0.38), 0.28], [Vector3(-0.28, 3.68, 0.42), 0.22], [Vector3(0.3, 3.65, 0.25), 0.2]]:
		tree.blob(spec[0], Vector3(spec[1], spec[1] * 0.7, spec[1]), lp, {"lat": 6, "lon": 9, "lump": 0.5})
	_frond(fronds, root, "HillTree", Vector3(-0.1, 2.85, 0.35), tree)
	return _close(head, core, arms, legs, fronds, 1.15)
