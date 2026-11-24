extends "res://tools/creature_kit.gd"
## Temple guardians of the Sunspire Dunes, sculpted by hand: carved sandstone statues of an
## ancient desert temple, woken again. They carry no weapons. Each has a great gem set in its
## head that gathers light and fires it as a beam, and their joints glow as the light builds.
## Built like real temple statues: an idealised body, a pleated kilt with a stiff apron and a
## carved belt, a broad beaded collar, gilded armbands and sandals, gilding worn through in
## patches. Three designs:
##   pharaoh - the Pharaoh Guardian: a royal face with kohl-lined eyes under a crisply striped
##             headdress with lappets, a false beard, and the gem set in a cobra on the brow
##   lion    - the Lion Warden: a lion-headed statue (like the lioness goddesses of the temple
##             walls) with a heavy carved ruff of mane, wearing a gilded sun disc with the gem
##   sunken  - the Sunken Sentinel: the oldest, scoured almost faceless by sand, cracked from
##             head to foot with light pouring out of the cracks, a shoulder broken away, rags
##             of linen hanging from it and the gem burning in its brow

const SANDSTONE := Color("#d2b282")
const SANDSTONE_DARK := Color("#9a7b52")
const GOLD := Color("#dcb04a")
const LAPIS := Color("#284a8f")
const KOHL := Color("#1e1712")
const LIGHT := Color("#5ff0e0")

var style := "pharaoh"
var lights: Sculpt
var lights_paint: int


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	material.roughness = 0.88
	glow.albedo_color = LIGHT.darkened(0.3); glow.emission = LIGHT; glow.emission_energy_multiplier = 1.5


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "TempleGuardian"
	style = variant
	if not variant in ["pharaoh", "lion", "sunken"]: return null
	return _guardian()


## Smooth carved sandstone: warm, slightly darker in hollows and underneath, with fine grain.
## The sunken guardian is paler, scoured and pitted.
func stone() -> Callable:
	var worn := style == "sunken"
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := SANDSTONE.lerp(SANDSTONE_DARK, clampf(Sculpt.fbm(p * 12.0) * 0.25 + 0.15 - n.y * 0.2, 0.0, 1.0))
		if worn:
			c = c.lerp(Color("#e6d6b2"), smoothstep(0.2, 0.5, Sculpt.noise(p * 6.0)) * 0.4)
			c = c.darkened(smoothstep(0.45, 0.6, Sculpt.noise(p * 40.0)) * 0.2)
		return c


## Gilding, rubbed through to the stone in patches.
func gilt() -> Callable:
	var base := stone(); var keep := 0.25 if style == "sunken" else 0.62
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var g := GOLD.lerp(GOLD.darkened(0.4), clampf(-n.y * 0.5 + 0.2, 0.0, 1.0)).lightened(smoothstep(0.5, 1.0, n.y) * 0.18)
		return g.lerp(base.call(p, n, v, w), smoothstep(keep - 0.08, keep + 0.04, Sculpt.fbm(p * 6.0) + 0.5))


## Crisp painted bands of gold and lapis blue along `axis` (for the headdress and collar).
func stripes(count: float, axis: Vector3) -> Callable:
	var g := gilt(); var base := stone(); var worn := style == "sunken"
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var t := fposmod(p.dot(axis) * count, 1.0)
		var blue := smoothstep(0.46, 0.5, t) * smoothstep(1.0, 0.96, t)
		var c: Color = g.call(p, n, v, w).lerp(LAPIS.lightened(clampf(n.y, 0.0, 1.0) * 0.15), blue)
		if worn: c = c.lerp(base.call(p, n, v, w), smoothstep(0.3, 0.6, Sculpt.fbm(p * 7.0) + 0.4))
		return c


## A lathe profile with many more rings, so painted stripes have vertices to land on.
static func dense(profile: Array, per: int) -> Array:
	var out: Array = []
	for k in range(profile.size() - 1):
		var a: Vector2 = profile[k]; var b: Vector2 = profile[k + 1]
		for i in range(per):
			var q := a.lerp(b, float(i) / per)
			if q.x > 0.0001 or i == 0: out.append(q)
	out.append(profile[-1])
	return out


## Concentric gold and lapis rings round the neck, like the rows of beads in a broad collar.
func collar_rings(count: float) -> Callable:
	var g := gilt(); var base := stone(); var worn := style == "sunken"
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var t := fposmod(Vector2(p.x / 1.05, p.z / 0.6).length() * count, 1.0)
		var blue := smoothstep(0.42, 0.48, t) * smoothstep(0.98, 0.92, t)
		var c: Color = g.call(p, n, v, w).lerp(LAPIS.lightened(0.1), blue)
		c = c.lerp(Color("#3fb8a8"), smoothstep(0.66, 0.7, t) * smoothstep(0.82, 0.78, t) * 0.8)
		if worn: c = c.lerp(base.call(p, n, v, w), smoothstep(0.3, 0.6, Sculpt.fbm(p * 7.0) + 0.4))
		return c


## A glowing ring round a joint, lying across `axis`.
func glow_ring(center: Vector3, axis: Vector3, radius: float, thick: float, parent: Node3D) -> void:
	var s := Sculpt.new(); var lw := s.add_painter(func (p, n, v, w): return Color.WHITE)
	var a := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.UP).normalized(); var b := axis.cross(a).normalized()
	var pts: Array = []; var r: Array = []
	for k in range(15):
		var t := TAU * k / 14.0
		pts.append(center + (a * cos(t) + b * sin(t)) * radius); r.append(thick)
	s.tube(pts, r, lw, {"sides": 5, "per": 2, "cap_rings": 1})
	part(parent, "JointLight", s, glow).material_override = glow


## Glowing cracks (light seeping out) running across a surface from `a` to `b`.
func crack(s: Sculpt, painter: int, a: Vector3, b: Vector3, jag: float, across: Vector3) -> void:
	var pts: Array = [a]; var r: Array = [0.007]
	for k in range(1, 5):
		var t := k / 5.0
		pts.append(a.lerp(b, t) + across.normalized() * jag * (1.0 if k % 2 == 0 else -1.0)); r.append(0.009)
	pts.append(b); r.append(0.004)
	s.tube(pts, r, painter, {"sides": 4, "per": 1, "cap_rings": 1})


## An open stone hand: a palm, four slightly curled fingers and a thumb.
func hand(s: Sculpt, painter: int, wrist: Vector3, side: float) -> void:
	var palm := wrist + Vector3(0.008 * side, -0.06, -0.01)
	s.blob(palm, Vector3(0.03, 0.055, 0.045), painter, {"lat": 5, "lon": 8})
	for f in range(4):
		var z := -0.03 + f * 0.02
		var base := palm + Vector3(0.0, -0.05, z)
		s.tube([base, base + Vector3(0.006 * side, -0.045, -0.006), base + Vector3(0.0, -0.08, -0.018)], [0.011, 0.0095, 0.008], painter, {"sides": 6, "per": 2, "cap_rings": 2})
	var tb := palm + Vector3(-0.015 * side, -0.02, -0.04)
	s.tube([tb, tb + Vector3(-0.01 * side, -0.03, -0.025), tb + Vector3(-0.005 * side, -0.055, -0.035)], [0.012, 0.01, 0.008], painter, {"sides": 6, "per": 2, "cap_rings": 2})


func _guardian() -> Node3D:
	var st := stone(); var gp := gilt()
	var worn := style == "sunken"
	lights = Sculpt.new(); lights_paint = lights.add_painter(func (p, n, v, w): return Color.WHITE)
	var body := Sculpt.new(); var bp := body.add_painter(st); var bg := body.add_painter(gp)
	var collar := body.add_painter(collar_rings(22.0))
	var dark := body.add_painter(func (p, n, v, w): return SANDSTONE_DARK.darkened(0.25))
	# The idealised body of a temple statue: broad shoulders, a deep chest and a narrow waist,
	# carved chest and stomach muscles and the sweep of the back.
	body.tube([Vector3(0, 0.98, 0.0), Vector3(0, 1.12, -0.01), Vector3(0, 1.3, 0.0), Vector3(0, 1.46, 0.01)], [0.105, 0.11, 0.135, 0.125], bp, {"sides": 18, "per": 3, "flat": 1.65})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.085 * side, 1.34, -0.085), Vector3(0.095, 0.065, 0.055), bp, {"lat": 6, "lon": 9})
		body.blob(Vector3(0.16 * side, 1.3, 0.02), Vector3(0.07, 0.13, 0.09), bp, {"lat": 6, "lon": 9})
		body.blob(Vector3(0.24 * side, 1.45, 0.0), Vector3(0.085, 0.075, 0.085), bp, {"lat": 6, "lon": 9})
	for row in range(3):
		for side in [-1.0, 1.0]: body.blob(Vector3(0.04 * side, 1.2 - row * 0.07, -0.1), Vector3(0.036, 0.03, 0.02), bp, {"lat": 4, "lon": 6})
	body.blob(Vector3(0, 1.0, -0.105), Vector3(0.012, 0.012, 0.006), dark, {"lat": 3, "lon": 5})
	body.tube([Vector3(0, 1.45, 0.0), Vector3(0, 1.6, 0.0)], [0.062, 0.055], bp, {"sides": 12, "per": 2})
	# The broad collar: crisp rows of gold and lapis beads lying over the shoulders.
	body.lathe(Vector3(0, 1.5, 0.0), dense([Vector2(0.06, 0.025), Vector2(0.17, 0.0), Vector2(0.25, -0.055), Vector2(0.26, -0.08), Vector2(0.2, -0.055), Vector2(0.06, 0.0)], 6), collar, {"sides": 24, "basis": Basis.from_scale(Vector3(1.05, 1, 0.6))})
	# A carved belt with a gilded buckle panel, a pleated kilt and its stiff triangular apron.
	body.tube([Vector3(0, 0.96, 0.0), Vector3(0, 1.0, 0.0)], [0.115, 0.115], bg, {"sides": 18, "per": 1, "flat": 1.6, "cap_rings": 1})
	slab(body, bg, Vector3(0, 0.98, -0.11), Vector3(0.09, 0.06, 0.02), Basis.IDENTITY, 0.4, 0.0)
	body.lathe(Vector3(0, 0.96, 0.0), [Vector2(0.16, 0.02), Vector2(0.19, -0.1), Vector2(0.235, -0.28), Vector2(0.24, -0.3), Vector2(0.0, -0.29)], bp, {"sides": 26, "basis": Basis.from_scale(Vector3(1.15, 1, 0.72))})
	for k in range(15):
		var a := lerpf(-1.25, 1.25, k / 14.0)
		body.tube([Vector3(sin(a) * 0.185, 0.94, -cos(a) * 0.12), Vector3(sin(a) * 0.272, 0.68, -cos(a) * 0.172)], [0.008, 0.008], dark, {"sides": 4, "per": 1, "cap_rings": 1})
	body.tube([Vector3(0, 0.94, -0.15), Vector3(0, 0.7, -0.185)], [0.08, 0.02], bg, {"sides": 8, "per": 1, "flat": 0.2, "side": Vector3(0, 0, 1), "cap_rings": 1})
	# The light inside: a seam down the chest.
	lights.tube([Vector3(0, 1.27, -0.125), Vector3(0, 1.08, -0.115)], [0.009, 0.007], lights_paint, {"sides": 5, "per": 1, "cap_rings": 1})
	if worn:
		var rag := body.add_painter(func (p, n, v, w): return Color("#cbbb98").darkened(v * 0.3 + Sculpt.noise(p * 12.0) * 0.15))
		for k in range(9):
			var a := lerpf(-2.6, 2.6, k / 8.0) + 0.2 * sin(k * 3.1)
			var top := Vector3(sin(a) * 0.2, 0.92, -cos(a) * 0.14)
			body.tube([top, top + Vector3(sin(a) * 0.05, -0.2, -cos(a) * 0.03), top + Vector3(sin(a) * 0.06 + 0.02, -0.38 - 0.1 * (k % 3), -cos(a) * 0.02)], [0.035, 0.03, 0.01], rag, {"sides": 5, "per": 2, "flat": 0.3, "side": Vector3(sin(a), 0, -cos(a)), "cap1": false})
		body.tube([Vector3(0.16, 1.46, -0.08), Vector3(0.05, 1.25, -0.125), Vector3(-0.1, 1.02, -0.12)], [0.028, 0.032, 0.028], rag, {"sides": 5, "per": 3, "flat": 0.35, "side": Vector3(0, 0, -1)})
		# Cracks across the chest and back with light pouring out of them.
		crack(lights, lights_paint, Vector3(-0.2, 1.42, -0.06), Vector3(0.02, 1.15, -0.12), 0.02, Vector3(1, 0, 0))
		crack(lights, lights_paint, Vector3(0.18, 1.36, -0.07), Vector3(0.08, 1.06, -0.11), 0.018, Vector3(1, 0.2, 0))
		crack(lights, lights_paint, Vector3(-0.1, 1.4, 0.12), Vector3(0.12, 1.08, 0.1), 0.02, Vector3(1, 0, 0))
		crack(lights, lights_paint, Vector3(0.15, 0.94, -0.16), Vector3(0.24, 0.72, -0.15), 0.015, Vector3(1, 0, 0))
		# The left shoulder has broken away, leaving a jagged edge.
		for k in range(6):
			var a := k * 1.05
			body.crystal(Vector3(-0.25, 1.48, 0.0) + Vector3(0, cos(a), sin(a)) * 0.05, Vector3(-0.3, cos(a), sin(a)), 0.05, 0.02, bp, 4)
	part(root, "Body", body)

	# ---- head and the gem
	var head := joint(root, "Head", Vector3(0, 1.62, 0.0))
	var hs := Sculpt.new(); var hp := hs.add_painter(st); var hg := hs.add_painter(gp)
	var hstripe := hs.add_painter(stripes(40.0, Vector3(0, 1, 0)))
	var kohl := hs.add_painter(func (p, n, v, w): return KOHL)
	var gem_at: Vector3
	var gem_size := 0.04
	var eyes: Array = []
	match style:
		"pharaoh":
			# A calm, idealised face: a straight nose, full lips, kohl-lined almond eyes.
			hs.blob(Vector3(0, 1.73, -0.005), Vector3(0.088, 0.115, 0.1), hp, {"lat": 9, "lon": 12})
			hs.tube([Vector3(0, 1.75, -0.098), Vector3(0, 1.715, -0.11)], [0.012, 0.011], hp, {"sides": 6, "per": 1, "cap_rings": 2})
			hs.blob(Vector3(0, 1.67, -0.093), Vector3(0.034, 0.011, 0.012), hs.add_painter(func (p, n, v, w): return Color("#9a6448")), {"lat": 3, "lon": 7})
			for side in [-1.0, 1.0]:
				hs.blob(Vector3(0.038 * side, 1.758, -0.088), Vector3(0.026, 0.009, 0.01), kohl, {"lat": 3, "lon": 7})
				hs.tube([Vector3(0.06 * side, 1.756, -0.08), Vector3(0.085 * side, 1.75, -0.065)], [0.004, 0.002], kohl, {"sides": 4, "per": 1, "cap_rings": 1})
				hs.blob(Vector3(0.038 * side, 1.778, -0.09), Vector3(0.028, 0.006, 0.01), kohl, {"lat": 3, "lon": 6})
			eyes = [Vector3(-0.038, 1.758, -0.094), Vector3(0.038, 1.758, -0.094)]
			# The striped headdress with lappets hanging in front of the shoulders, and its
			# tail gathered at the back; a long plaited false beard.
			# The cap of the headdress over the crown, then its stiff striped wings flaring out
			# behind the face on each side.
			hs.lathe(Vector3(0, 1.8, 0.02), dense([Vector2(0.0, 0.085), Vector2(0.075, 0.07), Vector2(0.105, 0.03), Vector2(0.112, -0.01)], 4), hstripe, {"sides": 22, "basis": Basis.from_scale(Vector3(1.08, 1, 1.05))})
			for side in [-1.0, 1.0]:
				var wing := [Vector3(0.1 * side, 1.81, 0.03), Vector3(0.13 * side, 1.75, 0.04), Vector3(0.165 * side, 1.67, 0.045), Vector3(0.19 * side, 1.58, 0.05)]
				hs.tube(wing, [0.07, 0.085, 0.1, 0.1], hstripe, {"sides": 10, "per": 5, "flat": 0.2, "side": Vector3(side, 0, 0), "cap_len": 0.15})
			hs.tube([Vector3(-0.115, 1.8, -0.06), Vector3(0, 1.815, -0.1), Vector3(0.115, 1.8, -0.06)], [0.012, 0.014, 0.012], hg, {"sides": 6, "per": 2, "cap_rings": 1})
			for side in [-1.0, 1.0]:
				hs.tube([Vector3(0.115 * side, 1.74, -0.03), Vector3(0.14 * side, 1.6, -0.05), Vector3(0.135 * side, 1.44, -0.08)], [0.045, 0.05, 0.045], hstripe, {"sides": 8, "per": 8, "flat": 0.32, "side": Vector3(side, 0, 0), "cap_len": 0.2})
			hs.tube([Vector3(0, 1.8, 0.12), Vector3(0, 1.66, 0.15), Vector3(0, 1.56, 0.12)], [0.05, 0.04, 0.02], hstripe, {"sides": 8, "per": 8, "cap1": false})
			hs.tube([Vector3(0, 1.64, -0.09), Vector3(0, 1.57, -0.1), Vector3(0, 1.51, -0.085)], [0.022, 0.02, 0.018], hg, {"sides": 8, "per": 2, "bands": 5, "band": 0.18})
			# The cobra on the brow, rearing up with the gem set in its hood.
			hs.tube([Vector3(0, 1.815, -0.08), Vector3(0, 1.84, -0.11), Vector3(0, 1.88, -0.115)], [0.012, 0.014, 0.012], hg, {"sides": 6, "per": 2})
			hs.blob(Vector3(0, 1.89, -0.112), Vector3(0.04, 0.045, 0.014), hg, {"lat": 5, "lon": 9})
			gem_at = Vector3(0, 1.89, -0.128); gem_size = 0.032
		"lion":
			# A lion's head: a broad skull and brow, a deep muzzle with whisker pads, a broad
			# nose and rounded ears, set in a heavy carved ruff of mane.
			hs.blob(Vector3(0, 1.76, 0.0), Vector3(0.12, 0.125, 0.12), hp, {"lat": 9, "lon": 12})
			hs.tube([Vector3(0, 1.74, -0.09), Vector3(0, 1.71, -0.17)], [0.075, 0.062], hp, {"sides": 12, "per": 2, "square": 0.35, "cap_len": 0.55})
			for side in [-1.0, 1.0]:
				hs.blob(Vector3(0.035 * side, 1.69, -0.19), Vector3(0.04, 0.035, 0.035), hp, {"lat": 5, "lon": 8})
				hs.blob(Vector3(0.05 * side, 1.8, -0.105), Vector3(0.045, 0.018, 0.035), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.FORWARD, side * 0.25)})
				hs.blob(Vector3(0.048 * side, 1.784, -0.11), Vector3(0.022, 0.012, 0.01), kohl, {"lat": 3, "lon": 6})
				hs.blob(Vector3(0.1 * side, 1.86, 0.01), Vector3(0.04, 0.035, 0.02), hp, {"lat": 4, "lon": 7})
			hs.blob(Vector3(0, 1.735, -0.225), Vector3(0.03, 0.02, 0.016), hs.add_painter(func (p, n, v, w): return SANDSTONE_DARK.darkened(0.45)), {"lat": 4, "lon": 7})
			hs.blob(Vector3(0, 1.66, -0.16), Vector3(0.04, 0.025, 0.03), hp, {"lat": 4, "lon": 7})
			eyes = [Vector3(-0.048, 1.784, -0.117), Vector3(0.048, 1.784, -0.117)]
			# The mass of the mane behind and under the head, and a ruff under the chin.
			hs.blob(Vector3(0, 1.72, 0.06), Vector3(0.19, 0.19, 0.13), hp, {"lat": 8, "lon": 14, "lump": 0.25})
			hs.blob(Vector3(0, 1.62, -0.04), Vector3(0.13, 0.07, 0.09), hp, {"lat": 6, "lon": 10, "lump": 0.3})
			# The ruff: three tiers of broad, flattened locks lying down over the shoulders,
			# carved in the formal style of temple lions, gilded at the edges.
			for tier in range(3):
				var count := 14 + tier * 4
				for k in range(count):
					var a := TAU * (k + tier * 0.5) / count
					if absf(a - PI * 1.5) < 0.5 and tier < 2: continue
					var radial := Vector3(cos(a), sin(a) * 0.85, 0.0)
					var base := Vector3(0, 1.76 - tier * 0.05, 0.03 + tier * 0.03) + radial * (0.145 + tier * 0.035)
					var down := (radial * 0.3 + Vector3(0, -1.0, 0.3)).normalized()
					var base2 := base - radial * 0.02
					hs.tube([base2, base2 + down * 0.07 + radial * 0.02, base2 + down * 0.13 + radial * 0.025], [0.045, 0.04, 0.012], hg if tier == 2 else hp, {"sides": 6, "per": 2, "flat": 0.3, "side": radial, "cap1": false})
			# The sun disc on its head, with a cobra, holding the gem.
			hs.lathe(Vector3(0, 2.0, 0.03), [Vector2(0.0, 0.012), Vector2(0.1, 0.012), Vector2(0.11, 0.0), Vector2(0.1, -0.012), Vector2(0.0, -0.012)], hg, {"sides": 24, "basis": Basis(Vector3.RIGHT, PI * 0.5)})
			hs.tube([Vector3(0, 1.87, 0.02), Vector3(0, 1.9, 0.03)], [0.04, 0.035], hg, {"sides": 8, "per": 1})
			gem_at = Vector3(0, 2.0, 0.005); gem_size = 0.045
		"sunken":
			# Worn almost smooth: a ghost of a face, a cracked crown band, empty glowing eyes.
			hs.blob(Vector3(0, 1.74, -0.01), Vector3(0.095, 0.12, 0.105), hp, {"lat": 9, "lon": 12, "lump": 0.12})
			hs.tube([Vector3(0, 1.75, -0.098), Vector3(0, 1.72, -0.112)], [0.012, 0.01], hp, {"sides": 6, "per": 1, "cap_rings": 2})
			hs.tube([Vector3(0, 1.82, 0.0), Vector3(0, 1.85, 0.0)], [0.102, 0.098], hg, {"sides": 16, "per": 1, "cap_rings": 1, "lump": 0.2})
			for side in [-1.0, 1.0]:
				hs.blob(Vector3(0.04 * side, 1.758, -0.085), Vector3(0.025, 0.017, 0.012), hs.add_painter(func (p, n, v, w): return Color("#2a2018")), {"lat": 3, "lon": 6})
			eyes = [Vector3(-0.04, 1.758, -0.093), Vector3(0.04, 1.758, -0.093)]
			var hc := Sculpt.new(); var hcw := hc.add_painter(func (p, n, v, w): return Color.WHITE)
			crack(hc, hcw, Vector3(0.02, 1.82, -0.103), Vector3(-0.05, 1.67, -0.085), 0.012, Vector3(1, 0, 0))
			part(head, "Crack", hc, glow).material_override = glow
			gem_at = Vector3(0, 1.8, -0.108); gem_size = 0.034
	# A gold setting round the gem.
	var ring: Array = []; var rr: Array = []
	for k in range(13):
		var t := TAU * k / 12.0
		ring.append(gem_at + Vector3(cos(t), sin(t), 0) * gem_size * 1.25 + Vector3(0, 0, 0.008)); rr.append(gem_size * 0.22)
	hs.tube(ring, rr, hg, {"sides": 5, "per": 2, "cap_rings": 1})
	part(head, "Head", hs)
	# The gem is the guardian's core: it flares as the beam gathers.
	var gs := Sculpt.new(); var gw := gs.add_painter(func (p, n, v, w): return Color.WHITE)
	gs.crystal(gem_at + Vector3(0, 0, 0.02), Vector3(0, 0, -1), gem_size * 1.6, gem_size, gw, 6, PI / 6.0)
	var core := part(head, "Gem", gs, glow)
	core.material_override = glow
	var launch := Node3D.new(); launch.name = "LaunchPoint"; head.add_child(launch)
	launch.position = gem_at + Vector3(0, 0, -0.06) - Vector3(0, 1.62, 0.0)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e, Vector3(0.018, 0.008, 0.006), ew, {"lat": 4, "lon": 7})
	part(head, "Eyes", es, glow).material_override = glow

	# ---- arms: bare, with gilded armbands and bracers, open hands
	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.26 * side, 1.43, 0))
		var us := Sculpt.new(); var up := us.add_painter(st); var ug := us.add_painter(gp)
		var broken: bool = worn and side < 0.0
		if not broken: us.blob(Vector3(0.265 * side, 1.43, 0.0), Vector3(0.075, 0.075, 0.075), up, {"lat": 6, "lon": 9})
		us.tube([Vector3(0.285 * side, 1.4, 0.0), Vector3(0.31 * side, 1.25, 0.0), Vector3(0.33 * side, 1.13, 0.015)], [0.064, 0.058, 0.048], up, {"sides": 12, "per": 3})
		us.blob(Vector3(0.305 * side, 1.27, -0.035), Vector3(0.04, 0.06, 0.035), up, {"lat": 5, "lon": 8})
		us.tube([Vector3(0.298 * side, 1.33, 0.0), Vector3(0.302 * side, 1.3, 0.0)], [0.064, 0.064], ug, {"sides": 12, "per": 1, "cap_rings": 1})
		part(shoulder, "UpperArm", us)
		glow_ring(Vector3(0.33 * side, 1.11, 0.015), Vector3(0, 1, 0), 0.05, 0.01, shoulder)
		if worn and side > 0.0:
			var cs := Sculpt.new(); var cw := cs.add_painter(func (p, n, v, w): return Color.WHITE)
			crack(cs, cw, Vector3(0.3, 1.4, -0.06), Vector3(0.33, 1.15, -0.045), 0.01, Vector3(0, 0, 1))
			part(shoulder, "Crack", cs, glow).material_override = glow
		var elbow := joint(shoulder, "Forearm", Vector3(0.33 * side, 1.11, 0.015))
		var fs := Sculpt.new(); var fp := fs.add_painter(st); var fg := fs.add_painter(gp)
		fs.tube([Vector3(0.33 * side, 1.1, 0.01), Vector3(0.345 * side, 0.97, -0.02), Vector3(0.355 * side, 0.86, -0.04)], [0.05, 0.046, 0.034], fp, {"sides": 12, "per": 3})
		fs.tube([Vector3(0.345 * side, 0.96, -0.022), Vector3(0.353 * side, 0.88, -0.038)], [0.05, 0.044], fg, {"sides": 12, "per": 1, "cap_rings": 1, "bands": 2, "band": 0.12})
		hand(fs, fp, Vector3(0.355 * side, 0.86, -0.04), side)
		part(elbow, "Forearm", fs)
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs: glowing knees, gilded sandals, sand drifted round the sunken one's feet
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.11 * side, 0.9, 0.0))
		var ts := Sculpt.new(); var tp := ts.add_painter(st)
		ts.tube([Vector3(0.11 * side, 0.92, 0.0), Vector3(0.12 * side, 0.7, -0.01), Vector3(0.12 * side, 0.52, 0.0)], [0.085, 0.075, 0.058], tp, {"sides": 12, "per": 3})
		part(hip, "Thigh", ts)
		glow_ring(Vector3(0.12 * side, 0.5, 0.0), Vector3(0, 1, 0), 0.062, 0.011, hip)
		var knee := joint(hip, "Knee", Vector3(0.12 * side, 0.5, 0.0))
		var ss := Sculpt.new(); var sp := ss.add_painter(st); var sg := ss.add_painter(gp)
		ss.tube([Vector3(0.12 * side, 0.5, 0.0), Vector3(0.12 * side, 0.36, 0.015), Vector3(0.12 * side, 0.18, 0.005), Vector3(0.12 * side, 0.08, 0.0)], [0.056, 0.058, 0.044, 0.036], sp, {"sides": 12, "per": 3})
		ss.blob(Vector3(0.12 * side, 0.04, -0.05), Vector3(0.048, 0.035, 0.1), sp, {"lat": 5, "lon": 8})
		for t in range(5): ss.blob(Vector3((0.12 + (t - 2) * 0.017) * side, 0.025, -0.14 + absf(t - 1.5) * 0.008), Vector3(0.011, 0.014, 0.016), sp, {"lat": 3, "lon": 5})
		slab(ss, sg, Vector3(0.12 * side, 0.008, -0.055), Vector3(0.11, 0.018, 0.25), Basis.IDENTITY, 0.4, 0.0)
		ss.tube([Vector3(0.08 * side, 0.03, -0.11), Vector3(0.12 * side, 0.06, -0.06), Vector3(0.16 * side, 0.03, -0.11)], [0.008, 0.008, 0.008], sg, {"sides": 5, "per": 2, "cap_rings": 1})
		if worn:
			var sand := ss.add_painter(func (p, n, v, w): return Color("#d8bf8a").darkened(Sculpt.noise(p * 10.0) * 0.1))
			ss.blob(Vector3(0.12 * side, 0.05, -0.02), Vector3(0.13, 0.08, 0.17), sand, {"lat": 6, "lon": 10, "lump": 0.25})
		part(knee, "Shin", ss)
		if worn:
			var cs := Sculpt.new(); var cw := cs.add_painter(func (p, n, v, w): return Color.WHITE)
			crack(cs, cw, Vector3(0.11 * side, 0.46, -0.055), Vector3(0.13 * side, 0.22, -0.045), 0.01, Vector3(1, 0, 0))
			part(knee, "Crack", cs, glow).material_override = glow
		hips.append(hip); knees.append(knee)
	part(root, "Light", lights, glow).material_override = glow
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.35)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
