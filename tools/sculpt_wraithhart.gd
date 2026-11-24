extends "res://tools/sculpt_stormhorn_boss.gd"
## The Wraithhart of Hollowmourn, sculpted by hand: a lean spectral stag with antlers of dead
## bark and pale, burning eyes; moonlight catches its antlers before it rushes. Three designs,
## each built on a real deer:
##   stag     - a gaunt red deer stag, its ribs and hip bones showing through an ash-grey coat,
##              a shaggy neck mane, a twelve-point "royal" head of antlers made of dead bark and
##              lichen, cold light in its eyes and grave-mist curling round its hooves
##   skull    - a stag dead and still walking: a bare skull for a head with light in the eye
##             sockets, the hide rotted away over the ribs and spine, and the antlers shedding
##              their velvet in long ragged strips the way a real stag's do in late summer
##   giant    - the giant deer of the Ice Age (Megaloceros, the "Irish elk"), with the widest
##              antlers any deer ever grew: huge flat palms of bark fringed with tines, moss
##              and lichen growing on them, ghost-light glowing along their edges

const MOON := Color("#cfe4ff")

var mist_mat: StandardMaterial3D
var wisp_mat: StandardMaterial3D
var kind := "stag"


func _init() -> void:
	super()
	glow.albedo_color = Color("#b8d4ff"); glow.emission = Color("#a8c8ff"); glow.emission_energy_multiplier = 1.4
	mist_mat = StandardMaterial3D.new()
	mist_mat.vertex_color_use_as_albedo = true
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Ghost-fire: additive, so it glows wherever it overlaps.
	wisp_mat = mist_mat.duplicate()
	wisp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wisp_mat.no_depth_test = false


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Wraithhart"
	kind = variant
	if not variant in ["stag", "skull", "giant"]: return null
	return _hart()


# ------------------------------------------------------------------ painters

## An ash-grey coat, darker along the back, pale on the belly, with a faint cold sheen.
static func ash_coat(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#4a4c54").lerp(Color("#24252c"), clampf(n.y * 0.45 + Sculpt.fbm(p * 7.0) * 0.4 + 0.15, 0.0, 1.0))
	c = c.lerp(Color("#8a8e9a"), smoothstep(-0.25, -0.7, n.y) * 0.5)
	return c.darkened(smoothstep(0.62, 0.42, p.y) * 0.35)


## Dead bark: grey-brown, deeply furrowed, blotched with pale green lichen.
static func bark_antler(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#4a4038").lerp(Color("#8a7e70"), clampf(n.y * 0.3 + 0.35 + Sculpt.fbm(p * 9.0) * 0.4, 0.0, 1.0))
	c = c.darkened(smoothstep(0.8, 0.97, absf(sin(Sculpt.fbm(p * 4.0) * 26.0))) * 0.4)
	c = c.lerp(Color("#a8b890"), smoothstep(0.55, 0.75, Sculpt.noise(p * 16.0)) * 0.6)
	return c.lightened(smoothstep(0.75, 1.0, v) * 0.15)


static func bone_c(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#d6cdb6").lerp(Color("#6e6250"), clampf(0.15 - n.y * 0.25 + Sculpt.fbm(p * 14.0) * 0.5, 0.0, 1.0))


## Grave-mist: pale blue-white, fading out towards its edges (alpha from the normal's facing).
static func mist(_p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#c9dcff")
	return Color(c.r, c.g, c.b, 0.18 + 0.12 * clampf(n.y, 0.0, 1.0) - v * 0.1)


# ------------------------------------------------------------------ antlers

## A branching red-deer antler from `base`: the beam sweeps up and back; a brow tine and a bez
## tine reach forward low down, a trez tine halfway up, and a crown of tines at the top.
## Returns the tine tips.
func royal_antler(s: Sculpt, painter: int, base: Vector3, side: float, size: float) -> Array:
	var tips: Array = []
	var beam := [base, base + Vector3(0.14 * side, 0.14, 0.08) * size, base + Vector3(0.3 * side, 0.32, 0.14) * size, base + Vector3(0.42 * side, 0.5, 0.1) * size, base + Vector3(0.46 * side, 0.66, 0.02) * size]
	s.tube(beam, [0.04 * size, 0.035 * size, 0.03 * size, 0.026 * size, 0.02 * size], painter, {"sides": 8, "per": 3, "lump": 0.12, "ridges": 6, "ridge": 0.06})
	s.blob(base, Vector3(0.05, 0.035, 0.05) * size, painter, {"lat": 4, "lon": 8, "lump": 0.5})
	var tine := func (at: Vector3, dir: Vector3, l: float, r: float) -> void:
		var d := dir.normalized()
		var tip := at + d * l + Vector3(0, l * 0.25, 0)
		s.tube([at, at + d * l * 0.5 + Vector3(0, l * 0.06, 0), tip], [r, r * 0.7, r * 0.12], painter, {"sides": 7, "per": 2, "lump": 0.12, "cap1": false})
		tips.append(tip)
	tine.call((beam[0] as Vector3).lerp(beam[1], 0.4), Vector3(0.1 * side, 0.15, -1.0), 0.3 * size, 0.024 * size)
	tine.call((beam[1] as Vector3).lerp(beam[2], 0.2), Vector3(0.2 * side, 0.2, -1.0), 0.25 * size, 0.02 * size)
	tine.call((beam[2] as Vector3).lerp(beam[3], 0.5), Vector3(0.3 * side, 0.4, -1.0), 0.22 * size, 0.018 * size)
	for k in range(3):
		var a := (k - 1) * 0.7
		tine.call(beam[4], Vector3(side * (0.4 + 0.3 * cos(a)), 1.0, sin(a) * 0.8 - 0.1), 0.2 * size, 0.017 * size)
	return tips


## A giant deer's antler: the beam sweeps far out sideways into a huge flat palm, a brow tine
## low down, tines fringing the palm's back edge. Returns the tine tips.
func palm_antler(s: Sculpt, painter: int, base: Vector3, side: float) -> Array:
	var tips: Array = []
	var beam := [base, base + Vector3(0.25 * side, 0.08, 0.04), base + Vector3(0.5 * side, 0.14, 0.08), base + Vector3(0.72 * side, 0.2, 0.12)]
	s.tube(beam, [0.06, 0.05, 0.045, 0.04], painter, {"sides": 10, "per": 3, "lump": 0.1, "ridges": 6, "ridge": 0.05})
	s.blob(base, Vector3(0.06, 0.04, 0.06), painter, {"lat": 4, "lon": 8, "lump": 0.5})
	# The brow tine, palmate, reaching forward over the face.
	s.blob(base + Vector3(0.12 * side, 0.06, -0.12), Vector3(0.07, 0.02, 0.1), painter, {"lat": 5, "lon": 8, "basis": Basis(Vector3.RIGHT, 0.3)})
	var palm := base + Vector3(1.05 * side, 0.32, 0.18)
	var pb := Basis(Vector3.UP, side * 0.3) * Basis(Vector3.FORWARD, -side * 0.35) * Basis(Vector3.RIGHT, -0.25)
	s.blob(palm, Vector3(0.42, 0.04, 0.3), painter, {"lat": 7, "lon": 14, "basis": pb, "lump": 0.12})
	s.blob(palm + pb * Vector3(-0.25 * side, 0.0, 0.0), Vector3(0.22, 0.05, 0.18), painter, {"lat": 5, "lon": 10, "basis": pb})
	for k in range(8):
		var a := lerpf(-1.5, 1.35, k / 7.0)
		var edge := palm + pb * Vector3(side * cos(a) * 0.4, 0.01, sin(a) * 0.28)
		var dir := (pb * Vector3(side * cos(a) * 0.6, 0.9, sin(a) * 0.7)).normalized()
		var l := 0.22 + 0.08 * cos(a * 0.8)
		s.tube([edge, edge + dir * l * 0.5, edge + dir * l], [0.03, 0.022, 0.004], painter, {"sides": 7, "per": 2, "lump": 0.12, "cap1": false})
		tips.append(edge + dir * l)
	return tips


## Glowing tips catching the moonlight.
func moon_tips(s: Sculpt, tips: Array, size: float) -> void:
	var p := s.add_painter(func (pp, n, v, w): return Color.WHITE)
	for t in tips: s.blob(t, Vector3.ONE * size, p, {"lat": 3, "lon": 6})


# ------------------------------------------------------------------ the hart

func _hart() -> Node3D:
	var giant := kind == "giant"
	var coat := Callable(ash_coat)
	var mane := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#26242a").lerp(Color("#6a6670"), clampf(Sculpt.noise(p * 12.0) * 0.4 + 0.25 + v * 0.35, 0.0, 1.0))
		if kind == "skull": c = Color("#18171c").lerp(Color("#a8bede"), smoothstep(0.55, 1.0, v) * 0.8)
		return c
	var body := Sculpt.new(); var bp := body.add_painter(coat); var mp := body.add_painter(mane); var bn := body.add_painter(bone_c)
	var dark := body.add_painter(func (p, n, v, w): return Color("#0b0a0c"))
	var glow_s := Sculpt.new(); var gw := glow_s.add_painter(func (p, n, v, w): return Color.WHITE)
	# A lean, deep-chested body with a tucked-up belly; the giant is heavier at the shoulder.
	var k := 1.15 if giant else 1.0
	body.tube([Vector3(0, 1.1, 0.58), Vector3(0, 1.12, 0.35), Vector3(0, 1.06, 0.0), Vector3(0, 1.16, -0.3), Vector3(0, 1.2, -0.45)], [0.22 * k, 0.25 * k, 0.21 * k, 0.29 * k, 0.25 * k], bp, {"sides": 18, "per": 3, "flat": 0.72, "lump": 0.03})
	body.blob(Vector3(0, 1.0, -0.38), Vector3(0.17, 0.24, 0.19) * k, bp, {"lat": 7, "lon": 11})
	for side: float in [-1.0, 1.0]:
		body.blob(Vector3(0.12 * side, 1.12, 0.42), Vector3(0.11, 0.2, 0.19), bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.13 * side, 1.16, -0.32), Vector3(0.12, 0.19, 0.16) * k, bp, {"lat": 6, "lon": 9})
		# Hip bones jutting under the skin.
		body.blob(Vector3(0.13 * side, 1.26, 0.38), Vector3(0.045, 0.035, 0.05), bp, {"lat": 4, "lon": 7})
	body.tube([Vector3(0, 1.25, -0.42), Vector3(0, 1.45, -0.6), Vector3(0, 1.62, -0.72)], [0.2 * k, 0.15 * k, 0.12 * k], bp, {"sides": 14, "per": 3, "flat": 0.8})
	# Ribs: showing through the gaunt hide on the stag and the giant; bare bone on the skull hart.
	for side: float in [-1.0, 1.0]:
		if kind == "skull":
			body.blob(Vector3(0.06 * side, 1.07, -0.08), Vector3(0.125, 0.19, 0.28), dark, {"lat": 7, "lon": 10})
			# The ghost-light heart burning inside the empty rib cage.
			glow_s.blob(Vector3(0.15 * side, 1.05, -0.07), Vector3(0.04, 0.08, 0.1), gw, {"lat": 6, "lon": 8})
			glow_s.crystal(Vector3(0.16 * side, 1.1, -0.07), Vector3(0, 1, 0.15), 0.12, 0.04, gw, 6)
			# Ragged hide hanging from the torn edge under the ribs and along the belly.
			for j in range(7):
				var z := lerpf(-0.32, 0.22, j / 6.0)
				var l := 0.12 + 0.12 * fposmod(j * 0.618 + side, 1.0)
				var top := Vector3(0.19 * side, 0.93 + 0.03 * sin(j * 1.7), z)
				body.tube([top, top + Vector3(0.015 * side, -l * 0.5, 0.02), top + Vector3(0.0, -l, 0.04)], [0.035, 0.025, 0.004], bp, {"sides": 5, "per": 2, "flat": 0.25, "side": Vector3(0, 0, 1), "cap1": false, "lump": 0.4})
		for r in range(7 if kind == "skull" else 6):
			var z := (-0.3 + r * 0.07) if kind == "skull" else (-0.26 + r * 0.075)
			var pts: Array = []; var rr: Array = []
			for j in range(6):
				var a := lerpf(0.25, 2.3, j / 5.0)
				var rad := (0.23 if kind == "skull" else 0.215) * (1.0 - absf(z + 0.05) * 0.4)
				pts.append(Vector3(sin(a) * rad * (0.9 if kind == "skull" else 0.78) * side, 1.08 + cos(a) * rad, z + j * 0.01)); rr.append(0.014 if kind == "skull" else 0.011)
			body.tube(pts, rr, bn if kind == "skull" else bp, {"sides": 5, "per": 2, "cap_rings": 1})
	if kind == "skull":
		# The spine standing out along the back.
		for j in range(12):
			var z := lerpf(-0.42, 0.55, j / 11.0)
			body.blob(Vector3(0, 1.3 - absf(z - 0.05) * 0.1, z), Vector3(0.035, 0.03, 0.03), bn, {"lat": 4, "lon": 6})
			body.crystal(Vector3(0, 1.3 - absf(z - 0.05) * 0.1, z), Vector3(0, 1, 0.35), lerpf(0.16, 0.05, j / 11.0), 0.016, bn, 4)
		for j in range(6):
			var t := j / 5.0
			var at := Vector3(0, lerpf(1.43, 1.74, t), lerpf(-0.42, -0.7, t))
			body.blob(at, Vector3(0.04, 0.03, 0.035), bn, {"lat": 4, "lon": 6})
			body.crystal(at, Vector3(0, 1, 0.5), 0.05, 0.012, bn, 4)
		for side: float in [-1.0, 1.0]:
			# The pelvis wings breaking through the rump, the shoulder blades through the withers.
			body.blob(Vector3(0.12 * side, 1.27, 0.38), Vector3(0.07, 0.04, 0.09), bn, {"lat": 5, "lon": 8, "basis": Basis(Vector3.BACK, 0.4 * side)})
			body.blob(Vector3(0.07 * side, 1.29, 0.5), Vector3(0.05, 0.03, 0.06), bn, {"lat": 4, "lon": 7})
			body.blob(Vector3(0.23 * side, 1.2, -0.3), Vector3(0.012, 0.09, 0.055), bn, {"lat": 5, "lon": 8, "basis": Basis(Vector3.RIGHT, -0.35)})
	# A shaggy mane down the throat and along the neck.
	for j in range(14):
		var t := j / 13.0
		var at := Vector3(0, lerpf(1.52, 1.1, t), lerpf(-0.72, -0.5, t))
		for side: float in [-1.0, 1.0]:
			lock(body, mp, at + Vector3(0.04 * side, -0.05, -0.07), Vector3(side * 0.15, -1.0, -0.2), 0.2 + 0.1 * sin(t * PI), 0.03, Vector3(side, 0, 0), 0.05, 5, 1)
		if kind == "stag" and j % 2 == 0:
			lock(body, mp, Vector3(0, lerpf(1.7, 1.32, t), lerpf(-0.66, -0.4, t)), Vector3(0, 0.6, 1.0), 0.13, 0.03, Vector3.RIGHT, -0.05, 5, 1)

	# ---- the head
	var head := joint(root, "Head", Vector3(0, 1.62, -0.74))
	var hs := Sculpt.new(); var hp := hs.add_painter(bone_c if kind == "skull" else coat)
	var horn := hs.add_painter(bark_antler if kind != "skull" else func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return bark_antler(p, n, v, w).darkened(0.45))
	var nose := hs.add_painter(func (p, n, v, w): return Color("#141214").lightened(clampf(n.y, 0.0, 1.0) * 0.15))
	var black := hs.add_painter(func (p, n, v, w): return Color("#050506"))
	hs.blob(Vector3(0, 1.68, -0.8), Vector3(0.12, 0.12, 0.14), hp, {"lat": 9, "lon": 12})
	if kind == "skull":
		hs.tube([Vector3(0, 1.66, -0.86), Vector3(0, 1.57, -1.0), Vector3(0, 1.5, -1.12)], [0.085, 0.062, 0.042], hp, {"sides": 12, "per": 3, "square": 0.35, "flat": 0.85, "cap_rings": 2, "cap_len": 0.4})
	else:
		hs.tube([Vector3(0, 1.66, -0.86), Vector3(0, 1.58, -1.0), Vector3(0, 1.51, -1.09)], [0.095, 0.075, 0.058], hp, {"sides": 12, "per": 3, "square": 0.3, "flat": 0.88, "cap_rings": 2, "cap_len": 0.5})
	var eye_pts := [Vector3(-0.11, 1.69, -0.868), Vector3(0.11, 1.69, -0.868)]
	if kind == "skull":
		var en := Vector3(0.8, 0.1, -0.6).normalized() * 0.03
		eye_pts = [Vector3(-0.1, 1.69, -0.862) + Vector3(-en.x, en.y, en.z), Vector3(0.1, 1.69, -0.862) + en]
	if kind == "skull":
		# A bare deer skull: the nasal opening, the long toothed jaw, deep eye sockets.
		hs.blob(Vector3(0, 1.545, -1.06), Vector3(0.026, 0.022, 0.07), black, {"lat": 4, "lon": 7})
		var crack := [Vector3(0.03, 1.805, -0.7), Vector3(0.0, 1.81, -0.76), Vector3(0.025, 1.795, -0.82), Vector3(-0.01, 1.76, -0.88), Vector3(0.01, 1.7, -0.95)]
		hs.tube(crack, [0.008, 0.007, 0.006, 0.005, 0.002], black, {"sides": 4, "per": 2})
		for side: float in [-1.0, 1.0]:
			# Deep round eye sockets with a raised bony rim, a cheekbone arch beneath.
			var sc := Vector3(0.1 * side, 1.69, -0.862)
			var nrm := Vector3(0.8 * side, 0.1, -0.6).normalized()
			var ua := nrm.cross(Vector3.UP).normalized(); var va := ua.cross(nrm).normalized()
			hs.blob(sc, Vector3(0.036, 0.036, 0.03), black, {"lat": 5, "lon": 8})
			var ring: Array = []; var rr: Array = []
			for j in range(13):
				var a := TAU * j / 12.0
				ring.append(sc + nrm * 0.008 + (ua * cos(a) + va * sin(a)) * 0.042); rr.append(0.013 if sin(a) > 0.0 else 0.01)
			hs.tube(ring, rr, hp, {"sides": 5, "per": 2, "cap0": false, "cap1": false})
			# A heavy brow ridge slanting down over each socket, giving it a scowl.
			hs.tube([Vector3(0.05 * side, 1.722, -0.91), Vector3(0.095 * side, 1.737, -0.89), Vector3(0.13 * side, 1.736, -0.85)], [0.009, 0.014, 0.007], hp, {"sides": 6, "per": 2})
			hs.tube([sc + Vector3(0.0, -0.05, -0.02), Vector3(0.105 * side, 1.635, -0.8), Vector3(0.1 * side, 1.64, -0.74)], [0.016, 0.014, 0.012], hp, {"sides": 6, "per": 2})
			for t in range(6): hs.crystal(Vector3(0.042 * side, 1.515, -0.92 - t * 0.024), Vector3(0, -1, -0.1), 0.03, 0.008, hp, 4)
	else:
		hs.blob(Vector3(0, 1.5, -1.13), Vector3(0.058, 0.044, 0.03), nose, {"lat": 4, "lon": 8})
		for side: float in [-1.0, 1.0]:
			hs.blob(Vector3(0.1 * side, 1.72, -0.87), Vector3(0.042, 0.02, 0.03), hp, {"lat": 4, "lon": 6, "basis": Basis(Vector3.BACK, 0.3 * side)})
			hs.blob(Vector3(0.105 * side, 1.69, -0.862), Vector3(0.028, 0.022, 0.02), black, {"lat": 4, "lon": 6})
	var tips: Array = []
	for side: float in [-1.0, 1.0]:
		var base := Vector3(0.07 * side, 1.78, -0.76)
		if giant: tips.append_array(palm_antler(hs, horn, base, side))
		else: tips.append_array(royal_antler(hs, horn, base, side, 1.35))
	if kind == "skull":
		# Velvet peeling off the antlers in long ragged strips, hanging and swaying.
		var vel := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#6a3a36").lerp(Color("#2a0e10"), v * 0.7))
		for j in range(16):
			var t: Vector3 = tips[(j * 5) % tips.size()]
			var at := t.lerp(Vector3(0.1 * signf(t.x), 1.85, -0.76), 0.35 + 0.25 * fposmod(j * 0.618, 1.0))
			var l := 0.16 + 0.22 * fposmod(j * 0.37, 1.0)
			hs.tube([at, at + Vector3(0.01, -l * 0.5, 0.02), at + Vector3(0.02, -l, 0.03)], [0.02, 0.014, 0.002], vel, {"sides": 5, "per": 2, "flat": 0.3, "side": Vector3.RIGHT, "cap1": false})
	if giant:
		# Moss on the palms and ghost-light running along their edges.
		var mp2 := hs.add_painter(moss)
		for side: float in [-1.0, 1.0]: moss_clump(hs, mp2, Vector3(1.0 * side, 2.12, -0.56), 0.1, 4)
	var mt := Sculpt.new()
	if kind == "skull":
		var fp := mt.add_painter(func (pp, n, v, w): return Color.WHITE)
		for t: Vector3 in tips:
			mt.blob(t, Vector3.ONE * 0.012, fp, {"lat": 3, "lon": 6})
			mt.crystal(t, Vector3(0, 1, 0.25), 0.07, 0.013, fp, 5)
	else:
		moon_tips(mt, tips, 0.011)
	part(head, "MoonTips", mt, glow).material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.55, -0.88))
	var js := Sculpt.new(); var jp := js.add_painter(bone_c if kind == "skull" else coat)
	if kind == "skull":
		for side: float in [-1.0, 1.0]:
			js.tube([Vector3(0.06 * side, 1.6, -0.78), Vector3(0.05 * side, 1.53, -0.86), Vector3(0.036 * side, 1.49, -1.0), Vector3(0.014 * side, 1.48, -1.1)], [0.022, 0.02, 0.016, 0.014], jp, {"sides": 6, "per": 2, "flat": 0.6, "side": Vector3.RIGHT})
			for t in range(5): js.crystal(Vector3(0.037 * side, 1.495, -0.93 - t * 0.026), Vector3(0, 1, -0.1), 0.022, 0.008, jp, 4)
	else:
		js.tube([Vector3(0, 1.55, -0.86), Vector3(0, 1.49, -1.04)], [0.058, 0.04], jp, {"sides": 9, "per": 2, "flat": 1.0, "cap_rings": 2})
	var eye_sculpt := eyes(eye_pts, Vector3(0.028, 0.02, 0.02) if kind != "skull" else Vector3(0.014, 0.014, 0.014))
	if kind == "skull":
		var ep := eye_sculpt.add_painter(func (p, n, v, w): return Color.WHITE)
		var fire := Sculpt.new()
		var fpp := fire.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var a := (1.0 - v) * (0.45 + 0.35 * absf(n.dot(Vector3(0, 0, -1))))
			return Color(0.55 * a, 0.75 * a, 1.0 * a, 1.0))
		for e: Vector3 in eye_pts:
			var sd := signf(e.x)
			# Ghost-fire streaming back from each socket, flickering as it goes.
			var trail: Array = []; var tr: Array = []
			for j in range(8):
				var t := j / 7.0
				trail.append(e + Vector3(sd * (0.012 + 0.05 * t + 0.015 * sin(t * 9.0)), 0.015 + 0.13 * t * t + 0.02 * sin(t * 7.0 + 1.0), 0.02 + 0.36 * t)); tr.append(lerpf(0.026, 0.003, t))
			fire.tube(trail, tr, fpp, {"sides": 8, "per": 2, "cap1": false})
			for q2 in range(2):
				var off := Vector3(sd * 0.02, 0.03 * (q2 * 2 - 1), 0.0)
				var tt: Array = trail.slice(1).map(func (q): return q + off * (q.z - e.z) * 4.0)
				fire.tube(tt, tr.slice(1).map(func (r): return r * 0.6), fpp, {"sides": 6, "per": 2, "cap1": false})
		part(head, "EyeFire", fire, wisp_mat)
		# Ghost-fire curling up out of the empty rib cage too.
		var hf := Sculpt.new(); var hfp := hf.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var a := (1.0 - v) * 0.8
			return Color(0.55 * a, 0.75 * a, 1.0 * a, 1.0))
		for side: float in [-1.0, 1.0]:
			for q2 in range(3):
				var b := Vector3(0.19 * side, 1.0 + 0.05 * q2, -0.2 + 0.12 * q2)
				hf.tube([b, b + Vector3(0.04 * side, 0.08, 0.03), b + Vector3(0.02 * side, 0.17, 0.08), b + Vector3(0.05 * side, 0.25, 0.1)], [0.04, 0.03, 0.016, 0.002], hfp, {"sides": 7, "per": 2, "cap1": false})
		part(root, "HeartFire", hf, wisp_mat)
		eye_sculpt.blob(Vector3(0, 1.5, -0.94), Vector3(0.022, 0.02, 0.06), ep, {"lat": 4, "lon": 7})
	var ears: Array = []; var ear_sculpts: Array = []
	for side: float in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.1 * side, 1.73, -0.73))
		var xs := Sculpt.new(); var xp := xs.add_painter(coat)
		if kind != "skull":
			xs.tube([Vector3(0.1 * side, 1.73, -0.73), Vector3(0.18 * side, 1.78, -0.71), Vector3(0.25 * side, 1.8, -0.69)], [0.035, 0.042, 0.008], xp, {"sides": 7, "per": 2, "flat": 0.4, "side": Vector3(0, 1, 0.3), "cap_rings": 1})
		else:
			xs.tube([Vector3(0.1 * side, 1.73, -0.73), Vector3(0.16 * side, 1.76, -0.71), Vector3(0.21 * side, 1.75, -0.69)], [0.025, 0.026, 0.004], xp, {"sides": 6, "per": 2, "flat": 0.3, "side": Vector3(0, 1, 0.3), "cap1": false, "lump": 0.4})
		ears.append(ear); ear_sculpts.append(xs)
	var rot := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return ash_coat(p, n, v, w).lerp(bone_c(p, n, v, w), smoothstep(0.4, 0.3, p.y + Sculpt.noise(p * 22.0) * 0.16) * 0.85)
	var leg_rig := legs(coat, 0.14, -0.36, 0.46, 1.08, 0.72, rot if kind == "skull" else Callable(), 2, 1.62)
	# Grave-mist curling round each hoof.
	for i in range(4):
		var front := i < 2
		var x := 0.14 * (-1.0 if i % 2 == 0 else 1.0)
		var ms := Sculpt.new(); var mpp := ms.add_painter(mist)
		var at := Vector3(x, 0.08, -0.38 if front else 0.48)
		for j in range(4):
			var a := TAU * j / 4.0 + i
			ms.blob(at + Vector3(cos(a) * 0.08, 0.03 + 0.03 * j, sin(a) * 0.08), Vector3(0.09, 0.05, 0.09) * (1.0 + 0.2 * j), mpp, {"lat": 5, "lon": 8, "lump": 0.5})
		part(leg_rig.knees[i], "Mist", ms, mist_mat)
	var tail := joint(root, "Tail", Vector3(0, 1.14, 0.6))
	var ts := Sculpt.new(); var tp := ts.add_painter(coat)
	if kind == "skull":
		var tb := ts.add_painter(bone_c)
		for j in range(6): ts.blob(Vector3(0, 1.22 - j * 0.04, 0.58 + j * 0.03 - j * j * 0.002), Vector3(0.024, 0.018, 0.02) * (1.0 - j * 0.1), tb, {"lat": 4, "lon": 6})
	else:
		ts.tube([Vector3(0, 1.14, 0.58), Vector3(0, 1.08, 0.66), Vector3(0, 1.0, 0.68)], [0.04, 0.035, 0.02], tp, {"sides": 7, "per": 2, "cap1": false})
	if kind == "skull": part(root, "GhostLight", glow_s, glow).material_override = glow
	# Spectral mist streaming back off its shoulders and rump as if it were half made of fog.
	var ws := Sculpt.new(); var wp := ws.add_painter(mist)
	for j in range(9):
		var t := j / 8.0
		var at := Vector3(0.1 * sin(j * 2.1), 1.3 - t * 0.12, -0.35 + t * 1.0)
		ws.blob(at + Vector3(0, 0.02, 0.1 * t), Vector3(0.12, 0.07, 0.16) * (0.8 + t * 0.7), wp, {"lat": 5, "lon": 8, "lump": 0.6})
	part(root, "Mist", ws, mist_mat)
	var light := OmniLight3D.new(); light.name = "MoonGlow"
	light.light_color = MOON; light.light_energy = 0.8; light.omni_range = 2.6; light.shadow_enabled = false
	head.add_child(light); light.position = Vector3(0, 0.45, 0.05)
	if kind == "skull":
		var heart := OmniLight3D.new(); heart.name = "GhostHeart"
		heart.light_color = Color("#9fd0ff"); heart.light_energy = 1.2; heart.omni_range = 1.4; heart.shadow_enabled = false
		root.add_child(heart); heart.position = Vector3(0, 1.07, -0.07)
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": ears, "ear_sculpts": ear_sculpts,
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail], "tail_sculpts": [ts], "fronds": [], "frond_sculpts": []}, 1.55 if giant else 1.45)
