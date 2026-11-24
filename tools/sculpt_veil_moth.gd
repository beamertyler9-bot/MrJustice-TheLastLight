extends "res://tools/sculpt_sugarspike_wasp.gd"
## The Veil Moth of Hollowmourn, sculpted by hand: a moth as wide as a cart, its wings torn
## like an old burial shroud and marked with eyes that seem to watch you; it folds them before
## beating out a gust that sends you reeling. Three designs, each built on a real moth:
##   deathshead - the death's-head hawkmoth (Acherontia), the moth with a skull on its back:
##                narrow dark mottled forewings, yellow hindwings banded black, a banded body,
##                and a pale skull on the thorax. The real one squeaks when it is disturbed
##   eyespot   - a giant silk moth like the polyphemus or the owl moth, whose hindwings carry
##               huge staring eyespots (ringed black, gold and pale blue) that it flashes at
##               anything that comes near; a thick fur collar and broad feathery antennae
##   moon      - the ghost of a moon moth (the luna moth and the comet moth), pale as a shroud
##               and half see-through, with long twisting tails trailing from its hindwings
##               and small glowing window-spots
##   veil      - all three in one: the death's-head's skull, banded body and dark mottled
##               forewings, the silk moth's staring eyespots and feathery antennae, and
##               hindwings that fade from bone-yellow into a see-through ghostly veil trailing
##               the moon moth's long tails

var kind := "deathshead"
var wing_solid: StandardMaterial3D
var wing_ghost: StandardMaterial3D
var fur_mat: StandardMaterial3D


func _init() -> void:
	super()
	wing_solid = StandardMaterial3D.new()
	wing_solid.vertex_color_use_as_albedo = true; wing_solid.vertex_color_is_srgb = true
	wing_solid.cull_mode = BaseMaterial3D.CULL_DISABLED; wing_solid.roughness = 0.9
	wing_solid.albedo_texture = load("res://assets/cast/fur_detail_gray.png"); wing_solid.uv1_triplanar = true; wing_solid.uv1_scale = Vector3(4, 4, 4)
	wing_ghost = wing_solid.duplicate()
	wing_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fur_mat = StandardMaterial3D.new()
	fur_mat.vertex_color_use_as_albedo = true; fur_mat.vertex_color_is_srgb = true; fur_mat.roughness = 0.95
	fur_mat.albedo_texture = load("res://assets/cast/fur_detail_gray.png"); fur_mat.uv1_triplanar = true; fur_mat.uv1_scale = Vector3(5, 5, 5)
	material = fur_mat
	glow.albedo_color = Color("#c8ffd0").darkened(0.2); glow.emission = Color("#c8ffd0"); glow.emission_energy_multiplier = 1.6


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "VeilMoth"
	kind = variant
	match variant:
		"deathshead": return _moth(Color("#ffd27a"))
		"eyespot": return _moth(Color("#c8e8ff"))
		"moon": return _moth(Color("#d0ffe0"))
		"veil": return _moth(Color("#d0ffe0"))
	return null


# ------------------------------------------------------------------ the wing membrane

## A torn notch in the wing's edge at angle `a`: a few deep V-shaped rips and a ragged fringe.
static func tear(a: float, seed: float) -> float:
	var r := 1.0 - 0.09 * smoothstep(0.4, 0.8, Sculpt.noise(Vector3(a * 3.5, seed, 0.0)))
	for k in range(3):
		var c := fposmod(seed * 0.37 + k * 0.29, 1.0)
		r -= 0.3 * maxf(0.0, 1.0 - absf(fposmod(a * 0.33 + 0.1, 1.0) - c) / 0.05)
	return maxf(r, 0.35)


## A wing as a thin two-sided sheet fanning out from `root_at` between angles a0 and a1 (0 is
## straight out to the side, positive sweeps back). `rf` gives the outline's distance at each
## angle. The painter gets the point on the wing; the wing tilts up by `lift` towards its tip.
func wing_sheet(s: Sculpt, painter: int, root_at: Vector3, side: float, a0: float, a1: float, rf: Callable, length: float, seed: float, na := 30, nr := 10, lift := 0.06) -> void:
	for layer in [0, 1]:
		var base := s._v.size()
		for i in range(na + 1):
			var u := float(i) / na
			var a := lerpf(a0, a1, u)
			var R: float = float(rf.call(u)) * length * tear(u * 3.0, seed)
			var d := Vector3(cos(a) * side, 0, sin(a))
			for j in range(nr + 1):
				var t := float(j) / nr
				var p := root_at + d * R * t + Vector3(0, lift * t * t + (0.004 if layer == 0 else -0.004) - 0.03 * sin(PI * u) * t, 0)
				s._v.append(p); s._along.append(t); s._ridge.append(u); s._painter.append(painter)
		var up: bool = (side > 0) != (layer == 1)
		for i in range(na):
			for j in range(nr):
				var a := base + i * (nr + 1) + j
				var b := a + nr + 1
				if up: s._i.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
				else: s._i.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))


## Forewing outline: the leading edge runs straight out to the tip, the outer edge falls back
## to the hind corner, the inner edge runs back in to the body.
static func fore_outline(u: float) -> float:
	return 1.0 - 0.42 * smoothstep(0.0, 0.6, u) - 0.42 * smoothstep(0.6, 1.0, u)


static func hind_outline(u: float) -> float:
	return (0.5 + 0.5 * sin(PI * clampf(u * 1.1, 0.0, 1.0))) * (1.0 - 0.6 * smoothstep(0.75, 1.0, u))


## Local 2D position on a wing (x out to the side, y back along the body).
static func wing_xy(p: Vector3, root_at: Vector3, side: float) -> Vector2:
	return Vector2((p.x - root_at.x) * side, p.z - root_at.z)


# ------------------------------------------------------------------ painters

static func dh_fore(p: Vector3, xy: Vector2, t: float) -> Color:
	var c := Color("#1e1816").lerp(Color("#5e5852"), clampf(Sculpt.fbm(p * 7.0) * 0.8 + 0.35, 0.0, 1.0))
	c = c.lerp(Color("#8a6a3a"), smoothstep(0.55, 0.8, Sculpt.noise(p * 5.0 + Vector3(2, 0, 1))) * 0.5)
	c = c.lerp(Color("#c8bca0"), smoothstep(0.035, 0.0, absf(t - 0.55 - 0.05 * sin(xy.y * 20.0))) * 0.5)
	c = c.lerp(Color("#c8bca0"), smoothstep(0.03, 0.0, absf(t - 0.82 - 0.04 * sin(xy.y * 25.0))) * 0.35)
	c = c.lerp(Color("#e0d4b0"), smoothstep(0.06, 0.0, (Vector2(0.38, 0.08) - xy).length() - 0.02) * 0.8)
	return c


static func dh_hind(p: Vector3, _xy: Vector2, t: float) -> Color:
	var c := Color("#c8b468").lerp(Color("#a89048"), clampf(Sculpt.fbm(p * 6.0) * 0.5 + 0.3, 0.0, 1.0))
	c = c.lerp(Color("#141010"), smoothstep(0.08, 0.02, absf(t - 0.5)))
	c = c.lerp(Color("#141010"), smoothstep(0.1, 0.04, absf(t - 0.86)))
	return c.lerp(Color("#2a221e"), smoothstep(0.25, 0.08, t))


static func eye_ring(xy: Vector2, c: Vector2, r: float, base: Color) -> Color:
	var d := (xy - c).length() / r
	if d > 1.25: return base
	if d > 1.0: return base.lerp(Color("#d8b8a8"), (1.25 - d) * 3.0)
	if d > 0.8: return Color("#0e0a0a")
	if d > 0.55: return Color("#d8b440")
	if d > 0.3: return Color("#8ab0d8")
	return Color("#0a0606")


static func silk_wing(p: Vector3, xy: Vector2, t: float) -> Color:
	var c := Color("#5a4a52").lerp(Color("#9a8a8e"), clampf(Sculpt.fbm(p * 6.0) * 0.6 + 0.45, 0.0, 1.0))
	c = c.lerp(Color("#e8dcd0"), smoothstep(0.03, 0.0, absf(t - 0.74 - 0.03 * sin(xy.y * 18.0))) * 0.7)
	c = c.lerp(Color("#3a2a2e"), smoothstep(0.03, 0.0, absf(t - 0.79 - 0.03 * sin(xy.y * 18.0))) * 0.7)
	return c.lerp(Color("#3a2e30"), smoothstep(0.3, 0.05, t) * 0.5)


static func moon_wing(p: Vector3, xy: Vector2, t: float) -> Color:
	var c := Color("#88b8a0").lerp(Color("#c8e4d4"), clampf(Sculpt.fbm(p * 5.0) * 0.5 + 0.5, 0.0, 1.0))
	var vein := smoothstep(0.012, 0.0, absf(fposmod(atan2(xy.y, xy.x) * 7.0, 1.0) - 0.5) * t * 0.5)
	c = c.lerp(Color("#7a9a8c"), vein * 0.4)
	c = c.lerp(Color("#5a4a6a"), smoothstep(0.05, 0.0, absf(atan2(xy.y, xy.x) + 0.25)) * 0.8)
	return Color(c.r, c.g, c.b, clampf(0.4 + 0.3 * (1.0 - t) - Sculpt.noise(p * 9.0) * 0.1, 0.2, 0.85))


## The veil moth's hindwing: bone-yellow banded black at the root, a great staring eyespot, then
## fading out into a pale see-through veil.
static func veil_hind(p: Vector3, xy: Vector2, t: float) -> Color:
	var c := dh_hind(p, xy, minf(t, 0.7))
	c = eye_ring(xy, Vector2(0.27, 0.25), 0.15, c)
	var ghost := moon_wing(p, xy, t)
	var g := smoothstep(0.6, 0.86, t)
	var out := c.lerp(ghost, g)
	return Color(out.r, out.g, out.b, lerpf(1.0, ghost.a, g))


# ------------------------------------------------------------------ the moth

func _moth(eye: Color) -> Node3D:
	glow.albedo_color = eye.darkened(0.2); glow.emission = eye; glow.emission_energy_multiplier = 1.0
	var y := 1.25
	var furry := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color.WHITE
	var abd := Callable(); var thx := Callable(); var leg_c := Color("#2a2420")
	match kind:
		"deathshead", "veil":
			thx = func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#1c1816").lerp(Color("#4a4440"), clampf(Sculpt.fbm(p * 12.0) * 0.6 + 0.3 + n.y * 0.2, 0.0, 1.0))
			abd = func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
				var c := Color("#c8b468").lerp(Color("#a08a40"), clampf(Sculpt.fbm(p * 10.0) * 0.5 + 0.3, 0.0, 1.0))
				c = c.lerp(Color("#121010"), smoothstep(0.3, 0.6, sin(p.z * 48.0)) * 0.9)
				return c.lerp(Color("#5a6a7a"), smoothstep(0.035, 0.015, absf(p.x)) * smoothstep(0.3, 0.7, n.y) * 0.9)
		"eyespot":
			thx = func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#6a5a5e").lerp(Color("#b8a8a4"), clampf(Sculpt.fbm(p * 12.0) * 0.6 + 0.4 + n.y * 0.2, 0.0, 1.0))
			abd = func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#5a4a4e").lerp(Color("#9a8a88"), clampf(Sculpt.fbm(p * 12.0) * 0.5 + 0.4, 0.0, 1.0)).darkened(smoothstep(0.6, 0.9, sin(p.z * 44.0)) * 0.3)
			leg_c = Color("#4a3a3a")
		"moon":
			thx = func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#c8d4cc").lerp(Color("#f4f8f4"), clampf(Sculpt.fbm(p * 12.0) * 0.6 + 0.5, 0.0, 1.0))
			abd = thx
			leg_c = Color("#6a5a6a")
	# The body: a big furry thorax, a tapering banded abdomen and a fur collar.
	var bs := Sculpt.new(); var tp := bs.add_painter(thx); var ap := bs.add_painter(abd)
	bs.blob(Vector3(0, y, 0), Vector3(0.17, 0.16, 0.2), tp, {"lat": 9, "lon": 12, "lump": 0.15})
	var ab: Array = []; var ar: Array = []
	for k in range(7):
		var t := k / 6.0
		ab.append(Vector3(0, y - 0.02 - 0.12 * t * t, 0.16 + t * 0.62)); ar.append(0.15 * (1.0 - t * 0.75) + 0.01)
	bs.tube(ab, ar, ap, {"sides": 14, "per": 3, "bands": 7, "band": 0.1, "cap1": true})
	var fur_spots: Array = []; var fur_dirs: Array = []
	for k in range(60):
		var a := TAU * fposmod(k * 0.618, 1.0); var z := lerpf(-0.18, 0.12, fposmod(k * 0.37, 1.0))
		var at := Vector3(sin(a) * 0.16, y + cos(a) * 0.15, z)
		fur_spots.append(at); fur_dirs.append((Vector3(sin(a), cos(a), 0) * 0.6 + Vector3(0, 0, 0.5)).normalized())
	tufts(bs, tp, fur_spots, fur_dirs, 0.08, 0.025)
	if kind == "deathshead" or kind == "veil":
		# The skull on its back: a pale skull with dark sockets on the top of the thorax.
		var bone := bs.add_painter(func (p, n, v, w): return Color("#e0d4b0").lerp(Color("#a89870"), clampf(Sculpt.fbm(p * 20.0) * 0.6, 0.0, 1.0)))
		var dark := bs.add_painter(func (p, n, v, w): return Color("#0c0808"))
		bs.blob(Vector3(0, y + 0.15, 0.0), Vector3(0.09, 0.03, 0.1), bone, {"lat": 5, "lon": 10})
		bs.blob(Vector3(0, y + 0.145, -0.09), Vector3(0.05, 0.025, 0.04), bone, {"lat": 4, "lon": 8})
		for side: float in [-1.0, 1.0]: bs.blob(Vector3(0.035 * side, y + 0.172, -0.01), Vector3(0.026, 0.012, 0.03), dark, {"lat": 4, "lon": 6})
		bs.blob(Vector3(0, y + 0.165, -0.06), Vector3(0.01, 0.008, 0.016), dark, {"lat": 3, "lon": 5})
	part(root, "Body", bs)
	# The head: big compound eyes, feathery antennae and a coiled tongue.
	var head := joint(root, "Head", Vector3(0, y - 0.02, -0.2))
	var hs := Sculpt.new(); var hp := hs.add_painter(thx); var ant := hs.add_painter(func (p, n, v, w): return leg_c.lightened(0.25))
	hs.blob(Vector3(0, y - 0.03, -0.24), Vector3(0.1, 0.09, 0.08), hp, {"lat": 7, "lon": 10})
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		eyes.append(Vector3(0.075 * side, y - 0.01, -0.27))
		# A broad feathery antenna: a curving shaft combed with fine branches on both sides.
		var b0 := Vector3(0.04 * side, y + 0.05, -0.3)
		var shaft: Array = []
		for k in range(9):
			var t := k / 8.0
			shaft.append(b0 + Vector3(0.18 * side * t, 0.22 * t - 0.08 * t * t, -0.2 * t))
		hs.tube(shaft, [0.008, 0.008, 0.007, 0.007, 0.006, 0.006, 0.005, 0.004, 0.003], ant, {"sides": 4, "per": 1})
		var comb := 0.07 if kind != "deathshead" else 0.0
		if comb > 0.0:
			for k in range(1, 9):
				var t := k / 8.0
				var sp: Vector3 = shaft[k]
				var l := comb * sin(PI * clampf(t * 1.1, 0.0, 1.0))
				for e: float in [-1.0, 1.0]:
					hs.tube([sp, sp + Vector3(0.3 * side, -0.2, -0.6 * e).normalized() * l], [0.003, 0.001], ant, {"sides": 3, "per": 1, "cap1": false})
	var tongue := [Vector3(0, y - 0.09, -0.3)]
	for k in range(12):
		var a := k * 0.9
		tongue.append(Vector3(0, y - 0.1 - 0.035 * (1.0 - k / 12.0) * (1.0 - cos(a)), -0.31 - 0.035 * (1.0 - k / 12.0) * sin(a)))
	var trr: Array = []
	for k in range(tongue.size()): trr.append(0.007)
	hs.tube(tongue, trr, ant, {"sides": 4, "per": 1})
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	var ce := hs.add_painter(func (p, n, v, w): return Color("#100c0c").lerp(Color("#3a3430"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0)))
	for e: Vector3 in eyes:
		hs.blob(e, Vector3(0.048, 0.054, 0.048), ce, {"lat": 6, "lon": 9})
		es.blob(e + Vector3(0.022 * signf(e.x), 0.0, -0.028), Vector3(0.022, 0.026, 0.016), ew, {"lat": 5, "lon": 8})
	part(head, "Head", hs)
	var core := part(head, "CompoundEyes", es, glow); core.material_override = glow

	# Four wings, each on its own joint: left fore, right fore, left hind, right hind.
	var wings: Array = []
	for pair in range(2):
		for side: float in [-1.0, 1.0]:
			var root_at := Vector3(0.12 * side, y + 0.08, -0.06 + pair * 0.12)
			var node := joint(root, "%sWing%d" % ["Left" if side < 0 else "Right", pair], root_at)
			var ws := Sculpt.new()
			var paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
				var xy := wing_xy(p, root_at, side)
				match kind:
					"deathshead": return dh_fore(p, xy, v) if pair == 0 else dh_hind(p, xy, v)
					"veil": return eye_ring(xy, Vector2(0.52, 0.12), 0.06, dh_fore(p, xy, v)) if pair == 0 else veil_hind(p, xy, v)
					"eyespot":
						var base := silk_wing(p, xy, v)
						if pair == 0: return eye_ring(xy, Vector2(0.46, 0.2), 0.06, base)
						return eye_ring(xy, Vector2(0.3, 0.3), 0.19, base)
				return moon_wing(p, xy, v)
			var wp := ws.add_painter(paint)
			var seed := pair * 3.0 + side * 1.7 + 0.4
			var mat: Material = wing_ghost if kind == "moon" or (kind == "veil" and pair == 1) else wing_solid
			if pair == 0:
				var flen := 1.15 if kind == "deathshead" or kind == "veil" else 1.05
				var a0 := -0.42 if kind == "deathshead" or kind == "veil" else -0.32
				wing_sheet(ws, wp, root_at, side, a0, 0.95, fore_outline, flen, seed)
			else:
				var hlen := 0.62 if kind == "deathshead" else 0.78
				wing_sheet(ws, wp, root_at, side, 0.25, 1.5, hind_outline, hlen, seed)
				if kind == "moon" or kind == "veil":
					# The long twisting tail trailing from the hindwing, ragged at the end.
					var tail: Array = []; var tr: Array = []
					var t0 := root_at + Vector3(0.36 * side, 0.03, 0.55)
					for k in range(9):
						var t := k / 8.0
						tail.append(t0 + Vector3(0.12 * side * sin(t * 2.4), -0.05 * t, 0.85 * t)); tr.append(lerpf(0.07, 0.03, t) * (1.0 - 0.5 * absf(sin(t * 9.0)) * t))
					var tpp := wp if kind == "moon" else ws.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return moon_wing(p, wing_xy(p, root_at, side), 0.3 + v * 0.6))
					ws.tube(tail, tr, tpp, {"sides": 6, "per": 2, "flat": 0.12, "side": Vector3.UP, "twist": 1.2, "cap1": false})
			part(node, "Wing", ws, mat)
			# Glowing eyes on the wings: the eyespot moth's pupils stare, the moon moth's windows shine.
			var gs := Sculpt.new(); var gw := gs.add_painter(func (p, n, v, w): return Color.WHITE)
			var spot := Vector2.ZERO; var sr := 0.0
			if kind == "eyespot": spot = Vector2(0.3, 0.3) if pair == 1 else Vector2(0.46, 0.2); sr = 0.05 if pair == 1 else 0.016
			elif kind == "moon": spot = Vector2(0.4, 0.22) if pair == 0 else Vector2(0.32, 0.3); sr = 0.03
			elif kind == "veil": spot = Vector2(0.27, 0.25) if pair == 1 else Vector2(0.52, 0.12); sr = 0.042 if pair == 1 else 0.016
			if sr > 0.0:
				var at := root_at + Vector3(spot.x * side, 0.0, spot.y)
				var lift_y := 0.06 * pow((Vector2(spot.x, spot.y).length()) / 0.9, 2.0)
				gs.blob(at + Vector3(0, lift_y + 0.006, 0), Vector3(sr, 0.006, sr), gw, {"lat": 3, "lon": 10})
				gs.blob(at + Vector3(0, lift_y - 0.006, 0), Vector3(sr, 0.006, sr), gw, {"lat": 3, "lon": 10})
				part(node, "WingEye", gs, glow).material_override = glow
			wings.append(node)
	var legs := dangling_legs(Vector3(0, y - 0.06, -0.04), leg_c, 0.022)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": wings}, 1.4)
	return _with_visual(node, head, legs[0], legs[1], wings)
