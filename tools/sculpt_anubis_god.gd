extends "res://tools/sculpt_sunken_sentinel.gd"
## The Glass Anubid, boss of the Sunspire Dunes, as the god Anubis himself: a towering figure
## with a man's body and a jackal's head, the way the Egyptians painted him in the tombs,
## carved out of polished black volcanic glass. He is dressed like a god in the tomb paintings:
## a striped lapis-and-black wig with lappets in front of the shoulders, a broad jewelled
## collar, gold arm bands and bracers, a pleated white kilt with a gold belt and apron, gold
## sandals. Like the Anubis statue from Tutankhamun's tomb his brows, eye rims and ear linings
## are gold leaf. In his right hand he holds a was-sceptre (the forked staff of the gods,
## topped with an animal head) with a great prism in its head, which fires his beam; in his
## left hand, an ankh. Seams of rainbow light run through the glass, and a halo of black glass
## blades hangs behind his head like a sun disc. Two designs:
##   god   - straight human legs in gold sandals, as in the tomb paintings
##   beast - the legs of a jackal (up on its toes, with a backward-bent ankle), more monstrous

const OBSIDIAN := Color("#0d0d12")
const LEAF_GOLD := Color("#d9ab45")

var legs_kind := "god"
var prism_mat: StandardMaterial3D
var glass_mat: StandardMaterial3D
var matte: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = null
	material.roughness = 0.14; material.metallic_specular = 1.0
	matte = StandardMaterial3D.new()
	matte.vertex_color_use_as_albedo = true
	matte.albedo_texture = load("res://assets/cast/cloth_color.png")
	matte.uv1_triplanar = true; matte.uv1_scale = Vector3(3, 3, 3)
	matte.roughness = 0.8
	prism_mat = StandardMaterial3D.new()
	prism_mat.vertex_color_use_as_albedo = true
	prism_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_mat = StandardMaterial3D.new()
	glass_mat.vertex_color_use_as_albedo = true
	glass_mat.roughness = 0.06; glass_mat.metallic_specular = 1.0
	glass_mat.rim_enabled = true; glass_mat.rim = 0.5
	glow.albedo_color = Color("#fff6d8"); glow.emission = Color("#ffe9a8"); glow.emission_energy_multiplier = 1.8


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GlassAnubid"
	if not variant in ["god", "beast"]: return null
	legs_kind = variant
	return _anubis()


# ------------------------------------------------------------------ painters

## Polished black glass with the soft ripples obsidian breaks with.
static func obsidian(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := OBSIDIAN.lerp(Color("#2e2e3a"), clampf(n.y * 0.35 + 0.1 + Sculpt.fbm(p * 3.0) * 0.3, 0.0, 1.0))
	return c.lightened(smoothstep(0.75, 1.0, sin(Sculpt.fbm(p * 2.5) * 30.0)) * 0.08)


static func goldleaf(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return LEAF_GOLD.lerp(LEAF_GOLD.darkened(0.45), clampf(-n.y * 0.4 + 0.25 + Sculpt.noise(p * 30.0) * 0.15, 0.0, 1.0)).lightened(smoothstep(0.4, 1.0, n.y) * 0.2)


## Rainbow light, the hue drifting along the seam.
static func prism(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color.from_hsv(fposmod(p.x * 1.3 + p.y * 2.1 + p.z * 1.7, 1.0), 0.75, 1.0).lerp(Color.WHITE, 0.15 + 0.35 * sin(v * PI))


## The wig: stripes of lapis blue and black.
static func wig(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var t := fposmod(p.y * 34.0, 1.0)
	var c := Color("#1e3a86").lerp(Color("#0c0f1e"), smoothstep(0.45, 0.52, t) * smoothstep(1.0, 0.93, t))
	return c.lightened(smoothstep(0.3, 1.0, n.y) * 0.15).darkened(clampf(-n.y * 0.3, 0.0, 0.3))


static func linen_white(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#f1ebda").darkened(clampf(-n.y * 0.25 + Sculpt.fbm(p * 8.0) * 0.08 + 0.04, 0.0, 0.35))


## A jagged seam of light from a to b.
func seam(s: Sculpt, painter: int, a: Vector3, b: Vector3, across: Vector3, jag: float, thick: float) -> void:
	var pts: Array = []; var r: Array = []
	for k in range(6):
		var t := k / 5.0
		pts.append(a.lerp(b, t) + across.normalized() * jag * (1.0 if k % 2 == 0 else -1.0) * (0.4 + 0.6 * sin(PI * t)))
		r.append(thick * 1.6 * (0.35 + 0.65 * sin(PI * (0.1 + 0.8 * t))))
	s.tube(pts, r, painter, {"sides": 4, "per": 2, "cap_rings": 1})


# ------------------------------------------------------------------ the god

func _anubis() -> Node3D:
	var body := Sculpt.new(); var bp := body.add_painter(obsidian); var bg := body.add_painter(goldleaf)
	var cloth := Sculpt.new(); var kp := cloth.add_painter(linen_white); var kg := cloth.add_painter(goldleaf)
	var kd := cloth.add_painter(func (p, n, v, w): return Color("#b9b09a"))
	var lights := Sculpt.new(); var lp := lights.add_painter(prism)
	# A god's body: broad shoulders, deep chest, narrow waist, carved muscles.
	body.tube([Vector3(0, 0.98, 0.0), Vector3(0, 1.12, -0.01), Vector3(0, 1.3, 0.0), Vector3(0, 1.46, 0.01)], [0.11, 0.115, 0.145, 0.135], bp, {"sides": 20, "per": 3, "flat": 1.7})
	for side: float in [-1.0, 1.0]:
		body.blob(Vector3(0.085 * side, 1.34, -0.095), Vector3(0.105, 0.06, 0.045), bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.17 * side, 1.3, 0.02), Vector3(0.075, 0.14, 0.095), bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.11 * side, 1.47, 0.03), Vector3(0.12, 0.06, 0.08), bp, {"lat": 6, "lon": 9})
	for row in range(3):
		for side: float in [-1.0, 1.0]: body.blob(Vector3(0.042 * side, 1.2 - row * 0.07, -0.105), Vector3(0.038, 0.031, 0.022), bp, {"lat": 4, "lon": 7})
	body.tube([Vector3(0, 1.45, 0.0), Vector3(0, 1.66, -0.01)], [0.075, 0.066], bp, {"sides": 14, "per": 2})
	# The broad collar of gold, lapis and turquoise beads.
	cloth.lathe(Vector3(0, 1.52, 0.0), dense([Vector2(0.07, 0.025), Vector2(0.18, 0.0), Vector2(0.27, -0.06), Vector2(0.28, -0.085), Vector2(0.22, -0.06), Vector2(0.07, 0.0)], 7), cloth.add_painter(collar_rings(24.0)), {"sides": 28, "basis": Basis.from_scale(Vector3(1.05, 1, 0.62))})
	# Seams of light across the chest and down the stomach.
	seam(lights, lp, Vector3(-0.21, 1.42, -0.06), Vector3(-0.02, 1.2, -0.125), Vector3(1, 0.4, 0), 0.02, 0.011)
	seam(lights, lp, Vector3(0.2, 1.36, -0.07), Vector3(0.05, 1.05, -0.12), Vector3(1, 0.3, 0), 0.018, 0.01)
	seam(lights, lp, Vector3(-0.06, 1.12, -0.12), Vector3(-0.12, 0.99, -0.1), Vector3(1, 0, 0), 0.012, 0.008)
	seam(lights, lp, Vector3(-0.15, 1.4, 0.1), Vector3(0.14, 1.1, 0.1), Vector3(1, 1, 0), 0.025, 0.011)
	seam(lights, lp, Vector3(0.24, 1.48, -0.02), Vector3(0.12, 1.5, -0.08), Vector3(0, 1, 0), 0.01, 0.008)
	seam(lights, lp, Vector3(-0.17, 1.25, -0.08), Vector3(-0.22, 1.05, -0.02), Vector3(0, 0, 1), 0.012, 0.009)
	# The kilt: a gold belt, pleated white linen and a stiff gold apron striped with lapis.
	cloth.tube([Vector3(0, 0.96, 0.0), Vector3(0, 1.01, 0.0)], [0.15, 0.15], kg, {"sides": 20, "per": 1, "flat": 1.4, "cap_rings": 1})
	slab(cloth, kg, Vector3(0, 0.985, -0.15), Vector3(0.1, 0.065, 0.02), Basis.IDENTITY, 0.4, 0.0)
	cloth.lathe(Vector3(0, 0.965, 0.0), [Vector2(0.18, 0.02), Vector2(0.22, -0.1), Vector2(0.27, -0.3), Vector2(0.275, -0.32), Vector2(0.0, -0.31)], kp, {"sides": 28, "basis": Basis.from_scale(Vector3(1.12, 1, 0.9))})
	for k in range(17):
		var a := lerpf(-1.35, 1.35, k / 16.0)
		cloth.tube([Vector3(sin(a) * 0.21, 0.94, -cos(a) * 0.17), Vector3(sin(a) * 0.305, 0.66, -cos(a) * 0.245)], [0.007, 0.007], kd, {"sides": 4, "per": 1, "cap_rings": 1})
	var apron := cloth.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return LAPIS if fposmod(p.y * 30.0, 1.0) < 0.35 else goldleaf(p, n, v, w))
	cloth.tube([Vector3(0, 0.95, -0.185), Vector3(0, 0.82, -0.215), Vector3(0, 0.66, -0.25)], [0.065, 0.075, 0.09], apron, {"sides": 8, "per": 6, "flat": 0.2, "side": Vector3(0, 0, 1), "cap_rings": 1})
	part(root, "Body", body)
	part(root, "Kilt", cloth, matte)

	# ---- the jackal head
	var head := joint(root, "Head", Vector3(0, 1.64, 0.0))
	var hs := Sculpt.new(); var hp := hs.add_painter(obsidian); var hg := hs.add_painter(goldleaf)
	var nose := hs.add_painter(func (p, n, v, w): return Color("#050507"))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#16070a"))
	hs.blob(Vector3(0, 1.77, 0.01), Vector3(0.1, 0.095, 0.12), hp, {"lat": 10, "lon": 14})
	hs.tube([Vector3(0, 1.765, -0.06), Vector3(0, 1.745, -0.18), Vector3(0, 1.72, -0.3), Vector3(0, 1.7, -0.37)], [0.078, 0.06, 0.042, 0.03], hp, {"sides": 12, "per": 3, "square": 0.25, "flat": 1.08, "cap0": false, "cap_rings": 2, "cap_len": 0.5})
	hs.blob(Vector3(0, 1.704, -0.395), Vector3(0.024, 0.018, 0.016), nose, {"lat": 4, "lon": 7})
	for side: float in [-1.0, 1.0]:
		# Gold-leaf brows slanting down to the nose, gold eye rims and the painted line.
		hs.blob(Vector3(0.05 * side, 1.79, -0.094), Vector3(0.04, 0.021, 0.013), hg, {"lat": 5, "lon": 8, "basis": Basis(Vector3.BACK, 0.25 * side)})
		hs.tube([Vector3(0.018 * side, 1.81, -0.127), Vector3(0.05 * side, 1.82, -0.11), Vector3(0.088 * side, 1.838, -0.08)], [0.006, 0.009, 0.005], hg, {"sides": 5, "per": 2})
		hs.tube([Vector3(0.075 * side, 1.786, -0.088), Vector3(0.1 * side, 1.78, -0.05)], [0.006, 0.004], hg, {"sides": 5, "per": 1})
		hs.blob(Vector3(0.065 * side, 1.73, -0.12), Vector3(0.05, 0.035, 0.07), hp, {"lat": 5, "lon": 8})
		hs.crystal(Vector3(0.024 * side, 1.69, -0.31), Vector3(0, -1, -0.05), 0.035, 0.008, hs.add_painter(func (p, n, v, w): return Color("#f2ead4")), 5)
	# A gold band round the brow and the striped wig behind the ears, its lappets in front
	# of the shoulders ending in gold.
	var wgs := Sculpt.new(); var wp := wgs.add_painter(wig)
	hs.tube([Vector3(-0.11, 1.83, 0.02), Vector3(0, 1.865, -0.06), Vector3(0.11, 1.83, 0.02)], [0.011, 0.013, 0.011], hg, {"sides": 6, "per": 3, "cap_rings": 1})
	wgs.blob(Vector3(0, 1.79, 0.05), Vector3(0.12, 0.1, 0.095), wp, {"lat": 14, "lon": 16})
	wgs.tube([Vector3(0, 1.8, 0.1), Vector3(0, 1.64, 0.12), Vector3(0, 1.5, 0.1)], [0.075, 0.08, 0.065], wp, {"sides": 12, "per": 6, "flat": 1.6})
	for side: float in [-1.0, 1.0]:
		var lap := [Vector3(0.1 * side, 1.78, 0.03), Vector3(0.15 * side, 1.62, -0.02), Vector3(0.155 * side, 1.46, -0.07)]
		wgs.tube(lap, [0.05, 0.062, 0.065], wp, {"sides": 8, "per": 8, "flat": 0.32, "side": Vector3(side, 0, 0.3).normalized(), "cap_len": 0.2})
		hs.tube([Vector3(0.155 * side, 1.475, -0.066), Vector3(0.155 * side, 1.45, -0.072)], [0.068, 0.066], hg, {"sides": 8, "per": 1, "flat": 0.34, "side": Vector3(side, 0, 0.3).normalized(), "cap_rings": 1})
	part(head, "Head", hs)
	part(head, "Wig", wgs, matte)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.05 * side, 1.79, -0.106), Vector3(0.034, 0.014, 0.012), ew, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.25 * side)})
	part(head, "Eyes", es, glow).material_override = glow
	var hl := Sculpt.new(); var hlp := hl.add_painter(prism)
	seam(hl, hlp, Vector3(0.0, 1.86, -0.02), Vector3(0.0, 1.77, -0.17), Vector3(1, 0, 0), 0.008, 0.007)
	seam(hl, hlp, Vector3(0.08, 1.8, 0.0), Vector3(0.06, 1.72, -0.16), Vector3(0, 1, 0), 0.01, 0.006)
	part(head, "PrismSeams", hl, prism_mat)
	# The jaw, opening as the beam gathers.
	var jaw := joint(head, "Jaw", Vector3(0, 1.71, -0.07))
	var js := Sculpt.new(); var jp := js.add_painter(obsidian); var jm := js.add_painter(func (p, n, v, w): return Color("#4a0f1c"))
	js.tube([Vector3(0, 1.7, -0.07), Vector3(0, 1.685, -0.22), Vector3(0, 1.675, -0.34)], [0.05, 0.035, 0.022], jp, {"sides": 10, "per": 2, "square": 0.3, "cap_rings": 2})
	js.blob(Vector3(0, 1.695, -0.22), Vector3(0.028, 0.01, 0.07), jm, {"lat": 4, "lon": 7})
	for side: float in [-1.0, 1.0]: js.crystal(Vector3(0.02 * side, 1.69, -0.3), Vector3(0, 1, -0.05), 0.03, 0.007, js.add_painter(func (p, n, v, w): return Color("#f2ead4")), 5)
	part(jaw, "Jaw", js)
	# Tall ears, black glass outside and gold leaf inside.
	var ears: Array = []
	for side: float in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.065 * side, 1.84, 0.0))
		var xs := Sculpt.new(); var xb := xs.add_painter(obsidian); var xg := xs.add_painter(goldleaf)
		xs.tube([Vector3(0.065 * side, 1.83, 0.01), Vector3(0.09 * side, 1.98, 0.015), Vector3(0.105 * side, 2.12, 0.02)], [0.06, 0.042, 0.004], xb, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.4, "side": Vector3.BACK})
		xs.tube([Vector3(0.066 * side, 1.84, -0.005), Vector3(0.089 * side, 1.975, -0.002), Vector3(0.102 * side, 2.1, 0.005)], [0.042, 0.028, 0.003], xg, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.3, "side": Vector3.BACK})
		part(ear, "Ear", xs)
		ears.append(ear)

	# ---- arms: gold arm bands and bracers; the was-sceptre in the right hand, an ankh in the left
	var arms: Array = []; var forearms: Array = []
	var core: MeshInstance3D
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.29 * side, 1.44, 0))
		var us := Sculpt.new(); var up := us.add_painter(obsidian); var ug := us.add_painter(goldleaf); var ul := us.add_painter(prism)
		us.blob(Vector3(0.285 * side, 1.44, 0.0), Vector3(0.088, 0.085, 0.088), up, {"lat": 7, "lon": 10})
		us.tube([Vector3(0.305 * side, 1.41, 0.0), Vector3(0.33 * side, 1.26, 0.0), Vector3(0.35 * side, 1.13, 0.015)], [0.074, 0.066, 0.054], up, {"sides": 14, "per": 3})
		us.blob(Vector3(0.325 * side, 1.28, -0.04), Vector3(0.046, 0.068, 0.04), up, {"lat": 6, "lon": 9})
		us.tube([Vector3(0.318 * side, 1.34, 0.0), Vector3(0.322 * side, 1.31, 0.0)], [0.073, 0.073], ug, {"sides": 14, "per": 1, "cap_rings": 1})
		part(shoulder, "UpperArm", us)
		var sl := Sculpt.new(); var slp := sl.add_painter(prism)
		seam(sl, slp, Vector3(0.36 * side, 1.4, -0.03), Vector3(0.39 * side, 1.18, 0.0), Vector3(0, 0, 1), 0.012, 0.008)
		part(shoulder, "PrismSeam", sl, prism_mat)
		var elbow := joint(shoulder, "Forearm", Vector3(0.35 * side, 1.11, 0.015))
		var fs := Sculpt.new(); var fp := fs.add_painter(obsidian); var fg := fs.add_painter(goldleaf)
		fs.tube([Vector3(0.35 * side, 1.1, 0.01), Vector3(0.365 * side, 0.97, -0.02), Vector3(0.375 * side, 0.86, -0.04)], [0.058, 0.052, 0.038], fp, {"sides": 14, "per": 3})
		fs.tube([Vector3(0.365 * side, 0.97, -0.022), Vector3(0.373 * side, 0.88, -0.038)], [0.056, 0.05], fg, {"sides": 14, "per": 1, "cap_rings": 1, "bands": 2, "band": 0.12})
		var wrist := Vector3(0.378 * side, 0.85, -0.045)
		# A closed fist round the shaft (right) or the ankh's loop (left).
		fs.blob(wrist + Vector3(0.0, -0.055, -0.01), Vector3(0.042, 0.055, 0.05), fp, {"lat": 6, "lon": 9})
		for f in range(4): fs.blob(wrist + Vector3(-0.025 * side, -0.03 - f * 0.024, -0.045), Vector3(0.02, 0.013, 0.02), fp, {"lat": 4, "lon": 6})
		part(elbow, "Forearm", fs)
		if side > 0.0:
			# The was-sceptre: a long staff of black wood banded with gold, forked at the
			# foot, with a slanting animal head at the top holding a great prism.
			var ws := Sculpt.new(); var wd := ws.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return LEAF_GOLD if fposmod(p.y * 5.0, 1.0) < 0.12 else Color("#17110d").lightened(clampf(n.y, 0.0, 1.0) * 0.1))
			var wg := ws.add_painter(goldleaf)
			var x := 0.378; var z := -0.09
			ws.tube([Vector3(x, 0.1, z), Vector3(x, 1.1, z), Vector3(x, 2.0, z)], [0.022, 0.021, 0.02], wd, {"sides": 8, "per": 6})
			for f: float in [-1.0, 1.0]: ws.tube([Vector3(x, 0.12, z), Vector3(x, 0.06, z + 0.03 * f), Vector3(x, 0.0, z + 0.035 * f)], [0.018, 0.014, 0.01], wg, {"sides": 6, "per": 2})
			ws.tube([Vector3(x, 1.98, z), Vector3(x, 2.06, z - 0.02), Vector3(x, 2.1, z - 0.09), Vector3(x, 2.11, z - 0.17)], [0.026, 0.034, 0.03, 0.02], wg, {"sides": 8, "per": 3})
			for f: float in [-1.0, 1.0]: ws.tube([Vector3(x + 0.012 * f, 2.11, z - 0.04), Vector3(x + 0.02 * f, 2.17, z - 0.02)], [0.012, 0.004], wg, {"sides": 5, "per": 1})
			part(elbow, "WasSceptre", ws)
			var gs := Sculpt.new(); var gw := gs.add_painter(func (p, n, v, w): return Color.WHITE)
			gs.crystal(Vector3(x, 2.11, z - 0.15), Vector3(0, 0, -1), 0.13, 0.034, gw, 6, PI / 6.0)
			core = part(elbow, "Prism", gs, glow); core.material_override = glow
			launch_point(elbow, Vector3(x, 2.11, z - 0.3))
		else:
			# The ankh, held by its loop.
			var as_ := Sculpt.new(); var ap := as_.add_painter(goldleaf)
			var c := Vector3(-0.378, 0.78, -0.05)
			var pts: Array = []
			for k in range(12):
				var a := TAU * k / 12.0
				pts.append(c + Basis(Vector3.UP, -0.6) * Vector3(0, sin(a) * 0.09, cos(a) * 0.055))
			pts.append(pts[0]); pts.append(pts[1])
			var rr: Array = []
			for k in range(pts.size()): rr.append(0.014)
			as_.tube(pts, rr, ap, {"sides": 6, "per": 3, "cap_rings": 1})
			var tb := Basis(Vector3.UP, -0.6)
			as_.tube([c + tb * Vector3(0, -0.09, -0.12), c + tb * Vector3(0, -0.09, 0.12)], [0.019, 0.019], ap, {"sides": 6, "per": 1, "flat": 1.3, "cap_rings": 1})
			as_.tube([c + Vector3(0, -0.09, 0), c + Vector3(0, -0.34, 0)], [0.02, 0.024], ap, {"sides": 6, "per": 1, "flat": 1.3, "cap_rings": 1})
			part(elbow, "Ankh", as_)
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.12 * side, 0.9, 0.0))
		var ts := Sculpt.new(); var tp := ts.add_painter(obsidian)
		var knee_at := Vector3(0.13 * side, 0.5, 0.0) if legs_kind == "god" else Vector3(0.13 * side, 0.6, -0.12)
		ts.tube([Vector3(0.12 * side, 0.93, 0.0), Vector3(0.13 * side, 0.72, -0.02 if legs_kind == "god" else -0.05), knee_at], [0.105, 0.09, 0.066], tp, {"sides": 14, "per": 3})
		part(hip, "Thigh", ts)
		var tl := Sculpt.new(); var tlp := tl.add_painter(prism)
		seam(tl, tlp, Vector3(0.2 * side, 0.88, -0.02), Vector3(0.19 * side, 0.6, -0.04), Vector3(0, 0, 1), 0.012, 0.009)
		part(hip, "PrismSeam", tl, prism_mat)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(obsidian); var sg := ss.add_painter(goldleaf)
		if legs_kind == "god":
			ss.tube([knee_at, Vector3(0.13 * side, 0.36, 0.015), Vector3(0.13 * side, 0.18, 0.005), Vector3(0.13 * side, 0.08, 0.0)], [0.066, 0.07, 0.05, 0.04], sp, {"sides": 14, "per": 3})
			ss.blob(Vector3(0.13 * side, 0.045, -0.055), Vector3(0.052, 0.038, 0.11), sp, {"lat": 6, "lon": 9})
			for t in range(5): ss.blob(Vector3((0.13 + (t - 2) * 0.018) * side, 0.028, -0.15 + absf(t - 1.5) * 0.008), Vector3(0.012, 0.015, 0.017), sp, {"lat": 3, "lon": 5})
			slab(ss, sg, Vector3(0.13 * side, 0.008, -0.06), Vector3(0.12, 0.018, 0.27), Basis.IDENTITY, 0.4, 0.0)
			ss.tube([Vector3(0.085 * side, 0.032, -0.12), Vector3(0.13 * side, 0.065, -0.065), Vector3(0.175 * side, 0.032, -0.12)], [0.009, 0.009, 0.009], sg, {"sides": 5, "per": 2, "cap_rings": 1})
			ss.tube([Vector3(0.13 * side, 0.15, 0.005), Vector3(0.13 * side, 0.12, 0.003)], [0.05, 0.048], sg, {"sides": 12, "per": 1, "cap_rings": 1})
		else:
			# A jackal's hind leg: a long shin back to the raised heel, then up on the toes.
			var hock := Vector3(0.13 * side, 0.28, 0.14)
			ss.tube([knee_at, Vector3(0.13 * side, 0.4, 0.03), hock], [0.068, 0.058, 0.04], sp, {"sides": 14, "per": 3})
			ss.blob(hock, Vector3(0.042, 0.045, 0.045), sp, {"lat": 5, "lon": 8})
			ss.tube([hock, Vector3(0.13 * side, 0.12, 0.04), Vector3(0.13 * side, 0.045, -0.04)], [0.04, 0.036, 0.035], sp, {"sides": 12, "per": 3})
			ss.tube([Vector3(0.13 * side, 0.2, 0.1), Vector3(0.13 * side, 0.17, 0.08)], [0.045, 0.043], sg, {"sides": 12, "per": 1, "cap_rings": 1})
			ss.blob(Vector3(0.13 * side, 0.04, -0.07), Vector3(0.055, 0.035, 0.07), sp, {"lat": 6, "lon": 9})
			for t in range(4):
				var toe := Vector3((0.13 + (t - 1.5) * 0.026) * side, 0.03, -0.13)
				ss.blob(toe, Vector3(0.017, 0.022, 0.022), sp, {"lat": 3, "lon": 5})
				ss.crystal(toe + Vector3(0, -0.005, -0.015), Vector3(0, -0.45, -1.0), 0.05, 0.009, ss.add_painter(func (p, n, v, w): return Color("#d4d8dc")), 5)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	part(root, "PrismSeams", lights, prism_mat)

	# ---- the halo of black glass blades behind his head, each blade split by light
	var halo: Array = []
	var c := Vector3(0, 1.86, 0.16)
	for k in range(11):
		var a := PI * (-0.08 + 1.16 * k / 10.0)
		var out := Vector3(cos(a), sin(a), 0.0)
		var at := c + out * 0.33
		var j := joint(root, "Blade%d" % k, at)
		var s := Sculpt.new(); var sp := s.add_painter(obsidian)
		var l := (0.26 if k % 2 == 0 else 0.18) * (1.2 if k == 5 else 1.0)
		s.crystal(at - out * l * 0.25, out, l, l * 0.2, sp, 4, PI * 0.25)
		part(j, "Blade", s, glass_mat)
		var gs := Sculpt.new(); var gp := gs.add_painter(prism)
		gs.crystal(at - out * l * 0.2 + Vector3(0, 0, -0.012), out, l * 0.7, l * 0.05, gp, 4, PI * 0.25)
		part(j, "Light", gs, prism_mat)
		halo.append(j)
	var ring := Sculpt.new(); var rg := ring.add_painter(goldleaf)
	var rpts: Array = []; var rr: Array = []
	for k in range(15):
		var a := PI * (-0.1 + 1.2 * k / 14.0)
		rpts.append(c + Vector3(cos(a), sin(a), 0) * 0.3); rr.append(0.014)
	ring.tube(rpts, rr, rg, {"sides": 6, "per": 3})
	var rj := joint(root, "SunRing", c)
	part(rj, "Ring", ring)
	halo.append(rj)

	var scale := 1.75
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": halo}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [],
		"ears": ears.map(func (e): return node.get_path_to(e)), "tails": [],
		"features": {&"jaw": node.get_path_to(jaw), &"smoke": halo.map(func (e): return node.get_path_to(e))}}
	node.set_meta("rig_bindings", rig)
	return node


## A spot the beam flies from, hung under `parent`.
func launch_point(parent: Node3D, at: Vector3) -> void:
	var lp := Node3D.new(); lp.name = "LaunchPoint"; parent.add_child(lp)
	lp.position = at - _world(parent)
