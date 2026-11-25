extends "res://tools/sculpt_veil_moth.gd"
## The Glasswing Reaver of Prismere, sculpted by hand: a hunting insect with a dark body and
## wings like blades of clear glass; it lines its wings up before it sweeps through you. Three
## designs, each built on a real insect:
##   dragonfly - the griffinfly (Meganeura, the giant dragonfly of the Coal Age with a wingspan
##               of 70 cm) and today's darners: four long clear wings held flat out like blades,
##               each stiffened by a thick leading vein with a dark cell near the tip (the
##               pterostigma); huge compound eyes meeting on top of the head; a long segmented
##               abdomen ringed with pale bands; spiny legs held forward as a basket, and a hinged
##               "mask" under the face that shoots out to seize prey
##   robberfly - the robber fly (Asilidae), the hawk of the insect world: a bristly humped
##               thorax, a "beard" of stiff bristles (the mystax) over the face, a dagger beak,
##               bulging eyes, strong spiny legs, a long tapering abdomen, and only two wings,
##               smoky glass, laid back over the body like closed scissors
##   glasswing - the glasswing butterfly (Greta oto), whose wings are clear windows in dark
##               borders with a white bar near the tip; here the windows are glass blades and its
##               long tongue is a curved, sharpened sickle

var kindr := "dragonfly"
var glass: StandardMaterial3D
var carapace: StandardMaterial3D


func _init() -> void:
	super()
	glass = StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true; glass.vertex_color_is_srgb = true
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.04; glass.metallic_specular = 1.0
	glass.rim_enabled = true; glass.rim = 0.8; glass.rim_tint = 0.3
	carapace = StandardMaterial3D.new()
	carapace.vertex_color_use_as_albedo = true; carapace.vertex_color_is_srgb = true
	carapace.roughness = 0.22; carapace.metallic = 0.35; carapace.metallic_specular = 0.9
	carapace.rim_enabled = true; carapace.rim = 0.35
	material = carapace
	shiny = carapace


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GlasswingReaver"
	kindr = variant
	match variant:
		"dragonfly": return _dragonfly()
		"robberfly": return _robberfly()
		"glasswing": return _glasswing()
	return null


# ------------------------------------------------------------------ the glass blade

## A wing as a thin two-sided blade from `root_at`, its leading edge running out along angle `a`
## (0 straight out to the side, positive swept back). `shape(t)` gives [leading-edge offset,
## chord] at each point t along the span. The painter gets v = along the span, w = across it.
func blade(s: Sculpt, painter: int, root_at: Vector3, side: float, a: float, length: float, shape: Callable, lift: float, nt := 26, nc := 7) -> Array:
	var d := Vector3(cos(a) * side, 0.0, sin(a))
	var back := Vector3(-sin(a) * side, 0.0, cos(a)) * side * side
	var grid: Array = []
	for layer in [0, 1]:
		var base := s._v.size()
		for i in range(nt + 1):
			var t := i / float(nt)
			var sh: Array = shape.call(t)
			for j in range(nc + 1):
				var c := j / float(nc)
				var q := root_at + d * length * t + back * (float(sh[0]) + float(sh[1]) * c) + Vector3(0, lift * t * t + 0.012 * sin(PI * c) * (1.0 - t) + (0.002 if layer == 0 else -0.002), 0)
				s._v.append(q); s._along.append(t); s._ridge.append(c); s._painter.append(painter)
				if layer == 0: grid.append(q)
		var want := Vector3.UP if layer == 0 else Vector3.DOWN
		for i in range(nt):
			for j in range(nc):
				var k := base + i * (nc + 1) + j
				var pa: Vector3 = s._v[k]; var pb: Vector3 = s._v[k + nc + 1]; var pc: Vector3 = s._v[k + 1]
				if (pc - pa).cross(pb - pa).dot(want) > 0.0: s._i.append_array(PackedInt32Array([k, k + nc + 1, k + 1, k + 1, k + nc + 1, k + nc + 2]))
				else: s._i.append_array(PackedInt32Array([k, k + 1, k + nc + 1, k + 1, k + nc + 2, k + nc + 1]))
	return [grid, nt, nc]


## Veins along a blade from `blade()`: a thick leading vein and thinner ones running out along
## the chord fractions in `at`.
func veins(s: Sculpt, painter: int, info: Array, at: Array, thick: float) -> void:
	var grid: Array = info[0]; var nt: int = info[1]; var nc: int = info[2]
	var lines: Array = [0.0]; lines.append_array(at)
	for li in range(lines.size()):
		var c: float = lines[li]
		var j := int(round(c * nc))
		var pts: Array = []; var rr: Array = []
		for i in range(0, nt + 1, 2):
			pts.append((grid[i * (nc + 1) + j] as Vector3) + Vector3(0, 0.003, 0)); rr.append(lerpf(thick if li == 0 else thick * 0.4, 0.002, i / float(nt)))
		s.tube(pts, rr, painter, {"sides": 4 if li == 0 else 3, "per": 1, "cap1": false})


## Compound eyes: dark, faceted and iridescent, shifting colour as they turn, with a faint
## light of their own; the glowing "core" is the three small simple eyes (ocelli) between them.
func compound_eyes(head: Node3D, centres: Array, radii: Vector3, deep: Color, sheen: Color, ocelli_at: Vector3) -> MeshInstance3D:
	var em := carapace.duplicate() as StandardMaterial3D
	em.roughness = 0.12; em.metallic = 0.5
	em.emission_enabled = true; em.emission = sheen.darkened(0.5); em.emission_energy_multiplier = 0.35
	var es := Sculpt.new()
	var ep := es.add_painter(func (p: Vector3, n: Vector3, _v, _w) -> Color:
		var c := deep.lerp(sheen, clampf(0.35 + n.y * 0.35 + absf(n.x) * 0.3, 0.0, 1.0))
		c = c.lerp(Color.from_hsv(fposmod(0.45 + n.x * 0.25 + n.z * 0.15, 1.0), 0.6, 0.9), 0.25)
		# Facets: a fine speckle of lit lenses and dark seams.
		var f := Sculpt.noise(p * 95.0)
		return c.lightened(smoothstep(0.35, 0.6, f) * 0.25).darkened(smoothstep(-0.3, -0.55, f) * 0.4))
	for c: Vector3 in centres:
		es.blob(c, radii, ep, {"lat": 14, "lon": 20})
	part(head, "CompoundEyes", es, em)
	var os := Sculpt.new(); var ow := os.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	os.blob(ocelli_at, Vector3.ONE * 0.016, ow, {"lat": 4, "lon": 6})
	for side in [-1.0, 1.0]: os.blob(ocelli_at + Vector3(0.025 * side, -0.012, 0.02), Vector3.ONE * 0.012, ow, {"lat": 4, "lon": 6})
	var core := part(head, "Ocelli", os, glow); core.material_override = glow
	return core


# ------------------------------------------------------------------ painters

## Clear glass, faintly tinted, catching a rainbow along the trailing edge and the tip.
func clear_glass(tint: Color, base_tint: Color) -> Callable:
	return func (p: Vector3, _n: Vector3, v: float, w: float) -> Color:
		var c := tint.lerp(base_tint, smoothstep(0.2, 0.0, v))
		var edge := maxf(smoothstep(0.75, 1.0, w), smoothstep(0.88, 1.0, v))
		c = c.lerp(Color.from_hsv(fposmod(v * 1.5 + w * 0.6 + p.y, 1.0), 0.55, 1.0), edge * 0.6)
		var a := 0.42 + 0.4 * edge + 0.2 * smoothstep(0.2, 0.0, v) + 0.1 * Sculpt.noise(p * 14.0)
		return Color(c.r, c.g, c.b, a)


static func darner_body(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#0e1622").lerp(Color("#24384a"), clampf(n.y * 0.5 + 0.3 + Sculpt.fbm(p * 10.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#1f6a6a"), smoothstep(0.3, 0.7, Sculpt.noise(p * 6.0)) * 0.35)


func _dragonfly() -> Node3D:
	glow.albedo_color = Color("#1a8a9a"); glow.emission = Color("#4ae8ff"); glow.emission_energy_multiplier = 0.9
	var y := 1.25
	var bs := Sculpt.new(); var bp := bs.add_painter(darner_body)
	var stripe := bs.add_painter(func (p: Vector3, n: Vector3, _v, _w) -> Color: return Color("#7ae8f0").lerp(Color("#d8fbff"), clampf(n.y, 0.0, 1.0)))
	# The thorax, tilted back, with the pale "shoulder stripes" of a darner.
	bs.blob(Vector3(0, y, 0), Vector3(0.13, 0.15, 0.2), bp, {"lat": 9, "lon": 12, "basis": Basis(Vector3.RIGHT, -0.35)})
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.1 * side, y + 0.1, -0.12), Vector3(0.12 * side, y + 0.02, 0.0), Vector3(0.1 * side, y - 0.08, 0.1)], [0.018, 0.02, 0.016], stripe, {"sides": 6, "per": 2})
	# The long abdomen: ten segments, each ringed in pale cyan, with a stripe down the back.
	var ab: Array = []; var ar: Array = []
	for k in range(11):
		var t := k / 10.0
		ab.append(Vector3(0, y - 0.03 - 0.1 * t * t, 0.16 + t * 1.3)); ar.append(lerpf(0.075, 0.045, t) * (1.15 if k == 1 else 1.0))
	var ring := bs.add_painter(func (p: Vector3, n: Vector3, _v, _w) -> Color:
		var c := darner_body(p, n, 0.0, 0.0)
		c = c.lerp(Color("#7ae8f0"), smoothstep(0.86, 0.96, fposmod((p.z - 0.16) / 0.13, 1.0)) * 0.9)
		return c.lerp(Color("#5ad0e0"), smoothstep(0.03, 0.0, absf(p.x)) * smoothstep(0.5, 0.9, n.y) * 0.8))
	bs.tube(ab, ar, ring, {"sides": 12, "per": 3, "bands": 10, "band": 0.08})
	# Claspers (cerci) at the tip of the tail.
	var tipz: Vector3 = ab[10]
	for side in [-1.0, 1.0]:
		bs.tube([tipz, tipz + Vector3(0.03 * side, 0.0, 0.12), tipz + Vector3(0.015 * side, -0.01, 0.2)], [0.014, 0.01, 0.002], bp, {"sides": 5, "per": 2, "cap1": false})
	part(root, "Body", bs)
	# The head: two huge compound eyes meeting on top, a face with a hinged mask below.
	var head := joint(root, "Head", Vector3(0, y + 0.03, -0.24))
	var hs := Sculpt.new(); var hp := hs.add_painter(darner_body)
	hs.blob(Vector3(0, y - 0.01, -0.3), Vector3(0.09, 0.08, 0.07), hp, {"lat": 6, "lon": 9})
	part(head, "Head", hs)
	var core := compound_eyes(head, [Vector3(0.085, y + 0.06, -0.31), Vector3(-0.085, y + 0.06, -0.31)], Vector3(0.11, 0.12, 0.11), Color("#06141a"), Color("#2ab0b8"), Vector3(0, y + 0.05, -0.42))
	# Mandibles: serrated, crossing in front of the mouth.
	var ms := Sculpt.new(); var mp := ms.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#141a22").lerp(Color("#d8f4ff"), v))
	for side in [-1.0, 1.0]:
		ms.tube([Vector3(0.05 * side, y - 0.05, -0.36), Vector3(0.06 * side, y - 0.07, -0.42), Vector3(-0.01 * side, y - 0.08, -0.46)], [0.02, 0.014, 0.003], mp, {"sides": 6, "per": 2, "cap1": false})
		for k in range(3): ms.crystal(Vector3((0.045 - k * 0.018) * side, y - 0.075, -0.43 - k * 0.012), Vector3(-side, 0, -0.3), 0.025, 0.005, mp, 3)
	part(head, "Mandibles", ms)
	# The mask (labium): a plate folded under the face, armed with two hooks; it is the jaw.
	var jaw := joint(head, "Jaw", Vector3(0, y - 0.07, -0.22))
	var js := Sculpt.new(); var jp := js.add_painter(darner_body)
	var hook := js.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#1a1410").lerp(Color("#d8f4ff"), v))
	js.tube([Vector3(0, y - 0.08, -0.22), Vector3(0, y - 0.1, -0.33), Vector3(0, y - 0.09, -0.4)], [0.035, 0.05, 0.04], jp, {"sides": 8, "per": 2, "flat": 1.6})
	for side in [-1.0, 1.0]:
		js.tube([Vector3(0.04 * side, y - 0.09, -0.4), Vector3(0.05 * side, y - 0.08, -0.46), Vector3(0.0, y - 0.07, -0.49)], [0.016, 0.01, 0.002], hook, {"sides": 5, "per": 2, "cap1": false})
	part(jaw, "Mask", js)
	# Four blade wings, held flat out to the sides.
	var wings: Array = []
	var vein := func (_p, _n, v: float, _w) -> Color: return Color("#1a2430").lerp(Color("#6a8aa0"), v * 0.5)
	for pair in range(2):
		for side: float in [-1.0, 1.0]:
			var root_at := Vector3(0.05 * side, y + 0.12, -0.06 + pair * 0.14)
			var node := joint(root, "%sWing%d" % ["Left" if side < 0 else "Right", pair], root_at)
			var ws := Sculpt.new(); var gp := ws.add_painter(clear_glass(Color("#9ad8f0"), Color("#c89a4a")))
			var shape := (func (t: float) -> Array: return [-0.02 * sin(PI * t), 0.2 * (0.55 + 0.45 * sin(PI * t)) * sqrt(maxf(0.0, 1.0 - pow(t, 8.0)))]) if pair == 0 \
				else (func (t: float) -> Array: return [-0.02 * sin(PI * t), 0.26 * (1.35 - 0.6 * t) * sqrt(maxf(0.0, 1.0 - pow(t, 6.0)))])
			var info := blade(ws, gp, root_at, side, -0.06 if pair == 0 else 0.1, 1.2 if pair == 0 else 1.12, shape, 0.05)
			var vs := Sculpt.new(); var vp := vs.add_painter(vein)
			veins(vs, vp, info, [0.3, 0.55, 0.8], 0.012)
			# The pterostigma: the dark cell on the leading edge near the tip.
			var g: Array = info[0]
			var ps: Vector3 = g[int(info[1] * 0.86) * (int(info[2]) + 1) + 1]
			vs.blob(ps + Vector3(0, 0.004, 0), Vector3(0.05, 0.005, 0.016), vs.add_painter(func (_p, _n, _v, _w) -> Color: return Color("#0c0c10")), {"lat": 3, "lon": 8, "basis": Basis(Vector3.UP, (-0.06 if pair == 0 else 0.1) * -side)})
			part(node, "WingVeins", vs, carapace)
			part(node, "Wing", ws, glass)
			wings.append(node)
	var legs := dangling_legs(Vector3(0, y - 0.06, -0.12), Color("#141a22"), 0.02)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": wings}, 1.35)
	return _with_visual(node, head, legs[0], legs[1], wings, jaw)


# ------------------------------------------------------------------ B: robber fly

static func robber_body(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#16141a").lerp(Color("#4a4652"), clampf(n.y * 0.4 + 0.3 + Sculpt.fbm(p * 12.0) * 0.4, 0.0, 1.0))
	return c.lerp(Color("#a89c80"), smoothstep(0.45, 0.6, Sculpt.noise(p * 8.0)) * 0.35)


func _robberfly() -> Node3D:
	glow.albedo_color = Color("#a86a10"); glow.emission = Color("#ffb030"); glow.emission_energy_multiplier = 0.9
	var y := 1.25
	var bs := Sculpt.new(); var bp := bs.add_painter(robber_body)
	var hair := bs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#2a2620").lerp(Color("#d8ccb0"), v * 0.8))
	# The humped, bristly thorax.
	bs.blob(Vector3(0, y + 0.02, 0), Vector3(0.15, 0.18, 0.22), bp, {"lat": 9, "lon": 12, "lump": 0.08})
	var spots: Array = []; var dirs: Array = []
	for k in range(46):
		var a := TAU * fposmod(k * 0.618, 1.0); var z := lerpf(-0.16, 0.16, fposmod(k * 0.37, 1.0))
		spots.append(Vector3(sin(a) * 0.14, y + 0.02 + cos(a) * 0.17, z)); dirs.append((Vector3(sin(a), cos(a), 0) + Vector3(0, 0.2, 0.6)).normalized())
	tufts(bs, hair, spots, dirs, 0.08, 0.008)
	# A long tapering abdomen, black with pale rings, ending in a point.
	var ab: Array = []; var ar: Array = []
	for k in range(9):
		var t := k / 8.0
		ab.append(Vector3(0, y - 0.05 - 0.15 * t * t, 0.18 + t * 0.95)); ar.append(lerpf(0.1, 0.03, t))
	var ring := bs.add_painter(func (p: Vector3, n: Vector3, _v, _w) -> Color:
		return robber_body(p, n, 0.0, 0.0).lerp(Color("#c8c0b0"), smoothstep(0.85, 0.95, fposmod((p.z - 0.18) / 0.12, 1.0)) * 0.8))
	bs.tube(ab, ar, ring, {"sides": 12, "per": 3, "bands": 8, "band": 0.06})
	# Halteres: the little knobbed balancers behind the wings.
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.12 * side, y + 0.02, 0.14), Vector3(0.16 * side, y + 0.0, 0.2)], [0.008, 0.006], bp, {"sides": 4, "per": 1})
		bs.blob(Vector3(0.165 * side, y, 0.21), Vector3.ONE * 0.02, bp, {"lat": 4, "lon": 6})
	part(root, "Body", bs)
	# The head: bulging eyes, a bristle beard over the face and a dagger beak.
	var head := joint(root, "Head", Vector3(0, y - 0.0, -0.22))
	var hs := Sculpt.new(); var hp := hs.add_painter(robber_body); var hh := hs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#3a3428").lerp(Color("#f0e4c0"), v))
	var beak := hs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#0c0a0c").lerp(Color("#c8e8ff"), v * v))
	hs.blob(Vector3(0, y, -0.28), Vector3(0.1, 0.09, 0.07), hp, {"lat": 6, "lon": 9})
	var bspots: Array = []; var bdirs: Array = []
	for k in range(26):
		var a := lerpf(-1.3, 1.3, fposmod(k * 0.618, 1.0)); var h := lerpf(-0.06, 0.03, fposmod(k * 0.41, 1.0))
		bspots.append(Vector3(sin(a) * 0.05, y + h, -0.33)); bdirs.append(Vector3(sin(a) * 0.4, -0.5, -1.0).normalized())
	tufts(hs, hh, bspots, bdirs, 0.11, 0.007)
	hs.tube([Vector3(0, y - 0.06, -0.32), Vector3(0, y - 0.1, -0.42), Vector3(0, y - 0.15, -0.5)], [0.02, 0.012, 0.002], beak, {"sides": 6, "per": 3, "cap1": false})
	part(head, "Head", hs)
	var core := compound_eyes(head, [Vector3(0.1, y + 0.03, -0.29), Vector3(-0.1, y + 0.03, -0.29)], Vector3(0.08, 0.1, 0.085), Color("#140a04"), Color("#c87a20"), Vector3(0, y + 0.1, -0.3))
	# Two smoky glass blades, laid back over the abdomen like closed scissors.
	var wings: Array = []
	var vein := func (_p, _n, v: float, _w) -> Color: return Color("#141016").lerp(Color("#5a5048"), v * 0.5)
	for side: float in [-1.0, 1.0]:
		var root_at := Vector3(0.09 * side, y + 0.12, -0.04)
		var node := joint(root, "%sWing0" % ["Left" if side < 0 else "Right"], root_at)
		var ws := Sculpt.new(); var gp := ws.add_painter(clear_glass(Color("#6a625c"), Color("#2a2018")))
		var shape := func (t: float) -> Array: return [-0.015 * sin(PI * t), 0.22 * (0.5 + 0.5 * sin(PI * minf(t * 1.25, 1.0))) * sqrt(maxf(0.0, 1.0 - pow(t, 5.0)))]
		var info := blade(ws, gp, root_at, side, 1.18, 1.05, shape, 0.04)
		var vs := Sculpt.new(); var vp := vs.add_painter(vein)
		veins(vs, vp, info, [0.28, 0.5, 0.72, 0.9], 0.011)
		part(node, "WingVeins", vs, carapace)
		part(node, "Wing", ws, glass)
		wings.append(node)
	var legs := dangling_legs(Vector3(0, y - 0.08, -0.08), Color("#1c1a1e"), 0.03)
	# Spines bristling on the legs.
	for k in range(legs[1].size()):
		var knee: Node3D = legs[1][k]
		var ss := Sculpt.new(); var sp := ss.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#1a1612").lerp(Color("#d8ccb0"), v))
		var kat := _world(knee)
		var side := -1.0 if k % 2 == 0 else 1.0
		for j in range(5):
			var at := kat + Vector3(0.008 * side * j, -0.04 * j - 0.02, 0.012 * j)
			ss.tube([at, at + Vector3(0.05 * side, -0.01, -0.03)], [0.005, 0.001], sp, {"sides": 3, "per": 1, "cap1": false})
		part(knee, "Spines", ss)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": wings}, 1.4)
	return _with_visual(node, head, legs[0], legs[1], wings)


# ------------------------------------------------------------------ C: glasswing butterfly

func _glasswing() -> Node3D:
	glow.albedo_color = Color("#8a1020"); glow.emission = Color("#ff3048"); glow.emission_energy_multiplier = 0.9
	var y := 1.3
	var dark := func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color: return Color("#1a1210").lerp(Color("#5a4030"), clampf(n.y * 0.4 + 0.3 + Sculpt.fbm(p * 12.0) * 0.4, 0.0, 1.0))
	var bs := Sculpt.new(); var bp := bs.add_painter(dark)
	bs.blob(Vector3(0, y, 0), Vector3(0.08, 0.09, 0.15), bp, {"lat": 8, "lon": 10, "lump": 0.06})
	var ab: Array = []; var ar: Array = []
	for k in range(7):
		var t := k / 6.0
		ab.append(Vector3(0, y - 0.02 - 0.06 * t * t, 0.12 + t * 0.55)); ar.append(lerpf(0.06, 0.025, t))
	bs.tube(ab, ar, bp, {"sides": 10, "per": 3, "bands": 6, "band": 0.06})
	part(root, "Body", bs)
	var head := joint(root, "Head", Vector3(0, y, -0.15))
	var hs := Sculpt.new(); var hp := hs.add_painter(dark)
	var blade_p := hs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#1a1210").lerp(Color("#e8f4ff"), v * v))
	hs.blob(Vector3(0, y, -0.18), Vector3(0.06, 0.055, 0.05), hp, {"lat": 6, "lon": 8})
	for side in [-1.0, 1.0]:
		# Clubbed antennae.
		var a0 := Vector3(0.02 * side, y + 0.04, -0.2)
		var a1 := a0 + Vector3(0.14 * side, 0.36, -0.22)
		hs.tube([a0, a0.lerp(a1, 0.5) + Vector3(0.02 * side, 0.02, 0), a1], [0.007, 0.006, 0.006], hp, {"sides": 4, "per": 2})
		hs.blob(a1, Vector3(0.016, 0.016, 0.03), hp, {"lat": 4, "lon": 6})
	# The tongue, uncoiled into a long curved sickle, sharpened to glass at the tip.
	var sk: Array = []; var sr: Array = []
	for k in range(9):
		var t := k / 8.0
		sk.append(Vector3(0, y - 0.05 - 0.22 * t + 0.08 * t * t * t, -0.21 - 0.3 * sin(t * 1.4))); sr.append(lerpf(0.014, 0.002, t))
	hs.tube(sk, sr, blade_p, {"sides": 6, "per": 2, "flat": 0.35, "side": Vector3.RIGHT, "cap1": false})
	part(head, "Head", hs)
	var core := compound_eyes(head, [Vector3(0.05, y + 0.01, -0.2), Vector3(-0.05, y + 0.01, -0.2)], Vector3.ONE * 0.042, Color("#140406"), Color("#c02838"), Vector3(0, y + 0.05, -0.2))
	# Four wings: clear glass windows in a dark border, a white bar near the forewing tip,
	# the hindwing's border edged with rust.
	var wings: Array = []
	var vein := func (_p, _n, v: float, _w) -> Color: return Color("#140c08").lerp(Color("#3a2418"), v * 0.5)
	for pair in range(2):
		for side: float in [-1.0, 1.0]:
			var root_at := Vector3(0.05 * side, y + 0.07, -0.05 + pair * 0.1)
			var node := joint(root, "%sWing%d" % ["Left" if side < 0 else "Right", pair], root_at)
			var ws := Sculpt.new()
			var fore := pair == 0
			var gp := ws.add_painter(func (p: Vector3, _n: Vector3, v: float, w: float) -> Color:
				var border := maxf(smoothstep(0.84, 0.92, v), maxf(smoothstep(0.86, 0.95, w), smoothstep(0.08, 0.02, w)))
				var c := Color("#c8e8ff").lerp(Color.from_hsv(fposmod(v + w * 0.5, 1.0), 0.5, 1.0), 0.35)
				var a := 0.38 + 0.1 * smoothstep(0.3, 0.0, v)
				var b := Color("#140c0a") if fore else Color("#140c0a").lerp(Color("#a8481c"), smoothstep(0.93, 0.98, w) * 0.8)
				if fore and v > 0.66 and v < 0.78 and w < 0.55: return Color(0.96, 0.95, 0.92, 0.95)
				c = c.lerp(b, border)
				return Color(c.r, c.g, c.b, lerpf(a, 0.97, border)))
			var shape := (func (t: float) -> Array: return [-0.05 * t, (0.12 + 0.42 * t) * sqrt(maxf(0.0, 1.0 - pow(t, 7.0)))]) if fore \
				else (func (t: float) -> Array: return [0.0, 0.46 * pow(sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0)), 0.6)])
			var info := blade(ws, gp, root_at, side, -0.3 if fore else 0.55, 0.95 if fore else 0.72, shape, 0.06)
			var vs := Sculpt.new(); var vp := vs.add_painter(vein)
			veins(vs, vp, info, [0.25, 0.45, 0.65], 0.01)
			part(node, "WingVeins", vs, carapace)
			part(node, "Wing", ws, glass)
			wings.append(node)
	var legs := dangling_legs(Vector3(0, y - 0.05, -0.05), Color("#1a1210"), 0.016)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": wings}, 1.45)
	return _with_visual(node, head, legs[0], legs[1], wings)
