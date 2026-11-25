extends "res://tools/sculpt_shard_sentinel.gd"
## The Aurora Custodian, boss of Prismere: an ancient guardian of stone and crystal that floats
## above the ground, wheeling rings about it; a chime sounds and the rings line up before it
## throws light split by its prisms. Three designs, each built on real things:
##   armillary - an archaic stone colossus (the stiff, broad-shouldered kouros statues of early
##               Greece, with their almond eyes and "archaic smile") whose legs have broken away
##               into a hanging cluster of crystal, turning inside an armillary sphere - the old
##               astronomer's instrument of bronze rings for the meridian, the equator and the
##               ecliptic tilted 23.4 degrees to it; a glass prism floats over each open palm
##   moai      - a moai of Rapa Nui: a great head on a slender torso carved from volcanic tuff,
##               heavy brow, long nose, pursed lips, long ears, arms carved down its sides with
##               long fingers meeting over the belly, a red scoria topknot (pukao), and eyes of
##               white coral with dark pupils as were found at Anakena - here the pupils are
##               glowing crystal; stone rings circle it like a planet's
##   aurora    - a seraph of crystal and stone: its body one great quartz point hanging point-
##               down, a carved stone mask for a face with three halo rings behind it, arms of
##               floating stone blocks with no joints between them, and curtains of aurora light
##               hanging from its crown - green at their lower edges and fading up through violet
##               into red, as the real aurora glows (oxygen green low, red high, nitrogen violet)

var kinda := "armillary"
var bronze: StandardMaterial3D
var aurora_mat: StandardMaterial3D


func _init() -> void:
	super()
	bronze = StandardMaterial3D.new()
	bronze.vertex_color_use_as_albedo = true; bronze.vertex_color_is_srgb = true
	bronze.metallic = 0.7; bronze.roughness = 0.35
	aurora_mat = StandardMaterial3D.new()
	aurora_mat.vertex_color_use_as_albedo = true; aurora_mat.vertex_color_is_srgb = true
	aurora_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aurora_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aurora_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aurora_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "AuroraCustodian"
	kinda = variant; kindc = "quartz"; kind = "sentinel"
	crystal_mat.emission = Color("#6a7aa8"); crystal_mat.emission_energy_multiplier = 0.4
	match variant:
		"armillary":
			glow.albedo_color = Color("#bff0ff").darkened(0.2); glow.emission = Color("#bff0ff")
		"moai":
			glow.albedo_color = Color("#9affd8").darkened(0.2); glow.emission = Color("#8affd0")
		"aurora":
			glow.albedo_color = Color("#c8ffe0").darkened(0.2); glow.emission = Color("#b0ffd8")
		_: return null
	glow.emission_energy_multiplier = 2.2
	match variant:
		"armillary": return _armillary()
		"moai": return _moai()
	return _aurora()


# ------------------------------------------------------------------ shared

static func bronze_paint(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#5a3a18").lerp(Color("#d8a860"), clampf(n.y * 0.3 + 0.45 + Sculpt.noise(p * 14.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#3a8a78"), smoothstep(0.45, 0.7, Sculpt.noise(p * 6.0 + Vector3(4, 0, 0))) * 0.55)


## Volcanic tuff, as the moai are carved from: grey-brown, pitted, lichen-spotted.
static func tuff(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#4a4440").lerp(Color("#8a8076"), clampf(n.y * 0.25 + 0.4 + Sculpt.fbm(p * 6.0) * 0.45, 0.0, 1.0))
	c = c.lerp(Color("#1a1614"), smoothstep(0.62, 0.75, Sculpt.noise(p * 30.0)) * 0.6)
	c = c.lerp(Color("#b8b088"), smoothstep(0.62, 0.72, Sculpt.noise(p * 9.0 + Vector3(7, 0, 0))) * 0.35)
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.3)


## A ring as a closed tube, `r` round, in the plane given by basis `b` (x and y axes), centred on `c`.
func ring(s: Sculpt, painter: int, c: Vector3, b: Basis, r: float, thick: float, flat := 1.0) -> void:
	var pts: Array = []; var rr: Array = []
	for k in range(49):
		var a := TAU * k / 48.0
		pts.append(c + b * Vector3(cos(a) * r, sin(a) * r, 0)); rr.append(thick)
	s.tube(pts, rr, painter, {"sides": 8, "per": 1, "flat": flat, "side": b.z, "cap0": false, "cap1": false})


## A triangular glass prism floating at `c` along `axis`.
func prism(s: Sculpt, painter: int, c: Vector3, axis: Vector3, length: float, r: float) -> void:
	s.lathe(c, [Vector2(0.0, length * 0.5), Vector2(r, length * 0.5), Vector2(r, -length * 0.5), Vector2(0.0, -length * 0.5)], painter, {"sides": 3, "basis": Basis(Quaternion(Vector3.UP, axis.normalized()))})


func launch(parent: Node3D, at: Vector3) -> void:
	var lp := Node3D.new(); lp.name = "LaunchPoint"; parent.add_child(lp)
	lp.position = at - _world(parent)


func _sway_rig(node: Node3D, head: Node3D, sway: Array) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [],
		"ears": [], "tails": [], "features": {&"smoke": sway.map(func (n): return node.get_path_to(n))}}
	node.set_meta("rig_bindings", rig)
	return node


func glow_part(parent: Node3D, name: String, s: Sculpt) -> MeshInstance3D:
	var m := part(parent, name, s, glow); m.material_override = glow
	return m


# ------------------------------------------------------------------ A: armillary colossus

func _armillary() -> Node3D:
	var bs := Sculpt.new(); var sp := bs.add_painter(granite); var cp := bs.add_painter(quartz)
	var dk := bs.add_painter(func (_p, _n, _v, _w): return Color("#0a0c12"))
	# The torso of an archaic statue: broad square shoulders, a narrow waist, the chest muscles
	# and ribs cut as flat stylised planes.
	bs.blob(Vector3(0, 1.58, 0), Vector3(0.34, 0.3, 0.2), sp, {"lat": 10, "lon": 14, "lump": 0.03})
	for side in [-1.0, 1.0]:
		bs.blob(Vector3(0.14 * side, 1.62, -0.13), Vector3(0.13, 0.09, 0.06), sp, {"lat": 6, "lon": 9})
		bs.blob(Vector3(0.34 * side, 1.74, 0), Vector3(0.15, 0.13, 0.14), sp, {"lat": 7, "lon": 10})
		for k in range(3): bs.tube([Vector3(0.06 * side, 1.44 - k * 0.06, -0.17), Vector3(0.2 * side, 1.47 - k * 0.06, -0.13)], [0.016, 0.012], sp, {"sides": 5, "per": 1})
	bs.blob(Vector3(0, 1.26, 0), Vector3(0.22, 0.2, 0.16), sp, {"lat": 8, "lon": 12})
	bs.tube([Vector3(0, 1.8, 0), Vector3(0, 1.92, 0)], [0.1, 0.09], sp, {"sides": 10, "per": 2})
	# Cracked open over the heart, a light burning inside.
	var gs := Sculpt.new(); var gw := gs.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	gs.blob(Vector3(0, 1.6, -0.17), Vector3(0.07, 0.09, 0.04), gw, {"lat": 6, "lon": 8})
	for k in range(5): crack(bs, dk, Vector3(0, 1.6, -0.19), Vector3(0, 1.6, -0.19) + Vector3(cos(k * 1.3) * 0.25, sin(k * 1.3) * 0.22, 0), Vector3(0, 0, -1), 0.03, k)
	cluster(bs, cp, Vector3(0, 1.6, -0.16), Vector3(0, 0, -1), 5, 0.14, 0.03, 0.4)
	# Below the waist it has broken away into hanging crystal.
	cluster(bs, cp, Vector3(0, 1.12, 0), Vector3(0, -1, 0), 9, 0.7, 0.09, 1.1, 0.5)
	part(root, "Torso", bs)
	var head := joint(root, "Head", Vector3(0, 2.02, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(granite); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#0a0c12"))
	var hc := hs.add_painter(quartz)
	hs.blob(Vector3(0, 2.05, 0), Vector3(0.14, 0.17, 0.15), hp, {"lat": 10, "lon": 14})
	# Hair as a cap of beaded braids falling behind, as on the kouroi.
	for k in range(9):
		var a := lerpf(-1.3, 1.3, k / 8.0)
		var top := Vector3(sin(a) * 0.13, 2.12, cos(a) * 0.1 + 0.03)
		hs.tube([top, top + Vector3(sin(a) * 0.03, -0.18, 0.06), top + Vector3(sin(a) * 0.04, -0.34, 0.05)], [0.03, 0.028, 0.02], hp, {"sides": 6, "per": 3, "bands": 6, "band": 0.25})
	hs.tube([Vector3(-0.1, 2.1, -0.12), Vector3(0, 2.11, -0.145), Vector3(0.1, 2.1, -0.12)], [0.018, 0.02, 0.018], hp, {"sides": 6, "per": 2})
	hs.tube([Vector3(0, 2.09, -0.14), Vector3(0, 2.02, -0.165)], [0.016, 0.024], hp, {"sides": 6, "per": 2})
	# The archaic smile.
	hs.tube([Vector3(-0.045, 1.965, -0.135), Vector3(0, 1.958, -0.148), Vector3(0.045, 1.965, -0.135)], [0.008, 0.009, 0.008], hd, {"sides": 4, "per": 2})
	# A crystal set in the brow.
	hs.crystal(Vector3(0, 2.14, -0.13), Vector3(0, 0.4, -1), 0.06, 0.018, hc, 6)
	part(head, "Head", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.05 * side, 2.065, -0.135), Vector3(0.028, 0.011, 0.01), ew, {"lat": 4, "lon": 7})
	es.blob(Vector3(0, 1.6, -0.17), Vector3(0.06, 0.08, 0.035), ew, {"lat": 6, "lon": 8})
	var core := glow_part(head, "Eyes", es)
	launch(head, Vector3(0, 2.06, -0.5))
	# Arms held out, forearms raised, palms open and turned up, a glass prism floating over each.
	var sway: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.38 * side, 1.74, 0)
		var arm := joint(root, "%sArm" % ("Left" if side < 0 else "Right"), sh)
		var el := sh + Vector3(0.22 * side, -0.28, -0.08)
		var wr := el + Vector3(0.08 * side, 0.05, -0.32)
		var as_ := Sculpt.new(); var ap := as_.add_painter(granite); var pr := as_.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#e8f4ff").lerp(Color.from_hsv(fposmod(p.x * 3.0 + v, 1.0), 0.5, 1.0), 0.35))
		as_.tube([sh, sh.lerp(el, 0.5), el], [0.12, 0.1, 0.085], ap, {"sides": 10, "per": 2})
		as_.blob(el, Vector3.ONE * 0.085, ap, {"lat": 6, "lon": 8})
		as_.tube([el, wr], [0.08, 0.065], ap, {"sides": 10, "per": 2})
		# An open hand, palm up: a flat palm and four fingers curled a little, thumb aside.
		as_.blob(wr + Vector3(0, 0.0, -0.06), Vector3(0.07, 0.03, 0.08), ap, {"lat": 5, "lon": 8})
		for f in range(4):
			var f0 := wr + Vector3((0.045 - f * 0.03) * side * 0.9, 0.0, -0.13)
			as_.tube([f0, f0 + Vector3(0, 0.01, -0.06), f0 + Vector3(0, 0.04, -0.09)], [0.017, 0.015, 0.012], ap, {"sides": 6, "per": 2})
		as_.tube([wr + Vector3(0.06 * side, 0, -0.05), wr + Vector3(0.1 * side, 0.03, -0.1)], [0.018, 0.014], ap, {"sides": 6, "per": 2})
		var pc := wr + Vector3(0, 0.2, -0.08)
		prism(as_, pr, pc, Vector3(0.3 * side, 0.4, -1.0), 0.24, 0.07)
		part(arm, "Arm", as_)
		sway.append(arm)
	# The armillary sphere: bronze rings for the meridian, the equator and the ecliptic, and
	# a crystal-studded band for the zodiac.
	var c := Vector3(0, 1.55, 0)
	var defs := [[Basis(Vector3.UP, 0.2), 1.05, 0.035], [Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.1), 1.0, 0.035], [Basis(Vector3.RIGHT, PI * 0.5 - 0.41) * Basis(Vector3.FORWARD, 0.3), 0.95, 0.07]]
	for k in range(defs.size()):
		var j := joint(root, "Ring%d" % k, c)
		var rs := Sculpt.new(); var rp := rs.add_painter(bronze_paint); var rc := rs.add_painter(quartz)
		var b: Basis = defs[k][0]
		ring(rs, rp, c, b, defs[k][1], defs[k][2], 0.35 if k == 2 else 1.0)
		if k == 2:
			for z in range(12):
				var a := TAU * z / 12.0
				rs.crystal(c + b * Vector3(cos(a), sin(a), 0) * float(defs[k][1]), b * Vector3(cos(a), sin(a), 0), 0.1, 0.025, rc, 6)
		if k == 0:
			for z in range(2):
				var a := PI * 0.5 + PI * z
				rs.blob(c + b * Vector3(cos(a), sin(a), 0) * float(defs[k][1]), Vector3.ONE * 0.06, rp, {"lat": 5, "lon": 8})
		part(j, "Ring", rs, bronze)
		sway.append(j)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": sway}, 1.6)
	return _sway_rig(node, head, sway)


# ------------------------------------------------------------------ B: moai

func _moai() -> Node3D:
	var bs := Sculpt.new(); var tp := bs.add_painter(tuff); var cp := bs.add_painter(quartz)
	var vein := bs.add_painter(func (_p, _n, _v, _w): return Color("#7affd0"))
	# The slender torso, arms carved down its sides with long fingers meeting over the belly.
	bs.blob(Vector3(0, 1.35, 0), Vector3(0.28, 0.42, 0.2), tp, {"lat": 10, "lon": 14, "lump": 0.03})
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.27 * side, 1.62, 0.0), Vector3(0.3 * side, 1.38, -0.02), Vector3(0.26 * side, 1.16, -0.1), Vector3(0.12 * side, 1.08, -0.18)], [0.06, 0.055, 0.05, 0.045], tp, {"sides": 8, "per": 3})
		for f in range(4):
			var f0 := Vector3(0.12 * side, 1.1 - f * 0.025, -0.19)
			bs.tube([f0, f0 + Vector3(-0.07 * side, -0.01, -0.005), f0 + Vector3(-0.11 * side, -0.02, 0.0)], [0.014, 0.013, 0.01], tp, {"sides": 5, "per": 2})
		bs.blob(Vector3(0.1 * side, 1.52, -0.18), Vector3(0.018, 0.018, 0.01), tp, {"lat": 4, "lon": 6})
	# The base, broken off jagged, grown through with crystal.
	cluster(bs, cp, Vector3(0, 0.98, 0), Vector3(0, -1, 0), 9, 0.55, 0.1, 0.7, 0.55)
	for k in range(6):
		var a := Vector3(sin(k * 2.1) * 0.2, 1.15 + k * 0.08, -0.19 + absf(sin(k * 2.1)) * 0.03)
		crack(bs, vein, a, a + Vector3(sin(k * 1.7) * 0.15, 0.12, 0), Vector3(0, 0, -1), 0.02, k)
	part(root, "Torso", bs)
	var head := joint(root, "Head", Vector3(0, 1.98, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(tuff); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#0e0c0a"))
	var coral := hs.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#eae4d8").darkened(Sculpt.noise(p * 40.0) * 0.1))
	var scoria := hs.add_painter(func (p: Vector3, n: Vector3, _v, _w) -> Color: return Color("#6a2418").lerp(Color("#b04a30"), clampf(n.y * 0.3 + 0.4 + Sculpt.fbm(p * 8.0) * 0.4, 0.0, 1.0)))
	# The long head: a deep heavy brow, a long straight nose with flared nostrils, pursed lips,
	# a jutting chin and long ears.
	hs.blob(Vector3(0, 2.0, 0.02), Vector3(0.24, 0.38, 0.22), hp, {"lat": 12, "lon": 14})
	hs.tube([Vector3(-0.2, 2.2, -0.15), Vector3(0, 2.22, -0.2), Vector3(0.2, 2.2, -0.15)], [0.05, 0.06, 0.05], hp, {"sides": 8, "per": 3})
	hs.tube([Vector3(0, 2.18, -0.2), Vector3(0, 2.0, -0.26), Vector3(0, 1.88, -0.29)], [0.04, 0.05, 0.06], hp, {"sides": 8, "per": 3, "flat": 1.2})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.05 * side, 1.86, -0.27), Vector3(0.04, 0.03, 0.03), hp, {"lat": 5, "lon": 7})
		hs.blob(Vector3(0.03 * side, 1.85, -0.3), Vector3(0.012, 0.01, 0.01), hd, {"lat": 3, "lon": 5})
		hs.tube([Vector3(0.23 * side, 2.18, 0.02), Vector3(0.25 * side, 2.0, 0.03), Vector3(0.23 * side, 1.78, 0.04)], [0.04, 0.035, 0.025], hp, {"sides": 7, "per": 3, "flat": 0.5, "side": Vector3.RIGHT})
		# White coral eyes in deep sockets.
		hs.blob(Vector3(0.1 * side, 2.12, -0.16), Vector3(0.07, 0.04, 0.03), hd, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.1 * side, 2.12, -0.175), Vector3(0.055, 0.03, 0.02), coral, {"lat": 5, "lon": 8})
	hs.tube([Vector3(-0.06, 1.77, -0.22), Vector3(0, 1.76, -0.25), Vector3(0.06, 1.77, -0.22)], [0.022, 0.028, 0.022], hp, {"sides": 6, "per": 2})
	hs.tube([Vector3(-0.055, 1.73, -0.215), Vector3(0, 1.725, -0.24), Vector3(0.055, 1.73, -0.215)], [0.02, 0.024, 0.02], hp, {"sides": 6, "per": 2})
	hs.blob(Vector3(0, 1.66, -0.18), Vector3(0.12, 0.06, 0.07), hp, {"lat": 6, "lon": 9})
	# The pukao: a broad cylinder of red scoria balanced on the head.
	hs.lathe(Vector3(0, 2.4, 0.03), [Vector2(0.0, 0.14), Vector2(0.16, 0.14), Vector2(0.24, 0.1), Vector2(0.26, -0.05), Vector2(0.22, -0.1), Vector2(0.0, -0.1)], scoria, {"sides": 16})
	part(head, "Head", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.1 * side, 2.12, -0.193), Vector3(0.022, 0.022, 0.008), ew, {"lat": 4, "lon": 7})
	var core := glow_part(head, "Eyes", es)
	launch(head, Vector3(0, 2.12, -0.5))
	# Stone rings circling it like a planet's, set with crystal, and a halo ring behind the head.
	var sway: Array = []
	var defs := [[Vector3(0, 1.3, 0), Basis(Vector3.RIGHT, PI * 0.5 + 0.25), 0.85, 0.05], [Vector3(0, 1.3, 0), Basis(Vector3.RIGHT, PI * 0.5 - 0.3) * Basis(Vector3.FORWARD, 0.25), 1.0, 0.035], [Vector3(0, 2.05, 0.3), Basis.IDENTITY, 0.55, 0.035]]
	for k in range(defs.size()):
		var c: Vector3 = defs[k][0]
		var j := joint(root, "Ring%d" % k, c)
		var rs := Sculpt.new(); var rp := rs.add_painter(tuff); var rc := rs.add_painter(quartz)
		var b: Basis = defs[k][1]
		ring(rs, rp, c, b, defs[k][2], defs[k][3], 0.6)
		for z in range(10 if k < 2 else 8):
			var a := TAU * z / (10.0 if k < 2 else 8.0) + k
			var at := c + b * Vector3(cos(a), sin(a), 0) * float(defs[k][2])
			rs.crystal(at, b * Vector3(cos(a), sin(a), 0) + Vector3(0, 0.3, 0), 0.12, 0.03, rc, 6, z)
		part(j, "Ring", rs)
		sway.append(j)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": sway}, 1.55)
	return _sway_rig(node, head, sway)


# ------------------------------------------------------------------ C: aurora seraph

func _aurora() -> Node3D:
	var bs := Sculpt.new(); var sp := bs.add_painter(granite); var cp := bs.add_painter(quartz)
	var deep := bs.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#5a6aa8").lerp(Color("#e8fff4"), clampf(v + Sculpt.noise(p * 8.0) * 0.2, 0.0, 1.0)))
	# The body: one great quartz point hanging point-down beneath a stone mantle.
	bs.crystal(Vector3(0, 1.55, 0), Vector3(0, -1, 0), 1.05, 0.3, deep, 6, 0.3)
	cluster(bs, cp, Vector3(0, 1.2, 0), Vector3(0, -1, 0.15), 6, 0.35, 0.12, 0.5, 0.9)
	bs.blob(Vector3(0, 1.66, 0), Vector3(0.36, 0.2, 0.24), sp, {"lat": 10, "lon": 14, "lump": 0.06})
	for side in [-1.0, 1.0]:
		var c := Vector3(0.36 * side, 1.78, 0)
		box(bs, sp, c, Basis(Vector3.FORWARD, -0.35 * side), Vector3(0.13, 0.08, 0.15))
		cluster(bs, cp, c + Vector3(0.05 * side, 0.06, 0), Vector3(0.4 * side, 1, 0), 4, 0.16, 0.04, side)
	bs.tube([Vector3(0, 1.8, 0), Vector3(0, 1.92, 0)], [0.1, 0.08], sp, {"sides": 10, "per": 2})
	part(root, "Body", bs)
	var gs := Sculpt.new(); var gw := gs.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	gs.blob(Vector3(0, 1.38, 0), Vector3(0.09, 0.14, 0.09), gw, {"lat": 6, "lon": 8})
	var heart := part(root, "Heart", gs, glow); heart.material_override = glow
	# The head: a serene carved stone mask.
	var head := joint(root, "Head", Vector3(0, 2.05, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return granite(p, n, v, w).lightened(0.25))
	var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#06080c"))
	hs.blob(Vector3(0, 2.05, 0.02), Vector3(0.14, 0.18, 0.13), hp, {"lat": 10, "lon": 14})
	hs.blob(Vector3(0, 2.06, -0.06), Vector3(0.12, 0.16, 0.07), hp, {"lat": 10, "lon": 12})
	hs.tube([Vector3(0, 2.1, -0.125), Vector3(0, 2.02, -0.145)], [0.016, 0.022], hp, {"sides": 6, "per": 2})
	hs.tube([Vector3(-0.03, 1.955, -0.12), Vector3(0, 1.95, -0.125), Vector3(0.03, 1.955, -0.12)], [0.006, 0.007, 0.006], hd, {"sides": 4, "per": 2})
	part(head, "Mask", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.045 * side, 2.08, -0.115), Vector3(0.03, 0.008, 0.01), ew, {"lat": 4, "lon": 7})
	var core := glow_part(head, "Eyes", es)
	launch(head, Vector3(0, 2.08, -0.5))
	var sway: Array = []
	# Three halo rings behind the head, one inside another, studded with crystal.
	for k in range(3):
		var c := Vector3(0, 2.08, 0.2 + k * 0.04)
		var j := joint(root, "Halo%d" % k, c)
		var rs := Sculpt.new(); var rp := rs.add_painter(granite); var rc := rs.add_painter(quartz)
		var r := 0.34 + k * 0.16
		var b := Basis(Vector3.FORWARD, k * 0.3) * Basis(Vector3.RIGHT, (k - 1) * 0.12)
		ring(rs, rp, c, b, r, 0.03 - k * 0.004, 0.5)
		for z in range(6 + k * 3):
			var a := TAU * z / (6.0 + k * 3.0)
			rs.crystal(c + b * Vector3(cos(a), sin(a), 0) * r, b * Vector3(cos(a), sin(a), 0), 0.08 + 0.03 * (z % 2), 0.02, rc, 6, z)
		part(j, "Halo", rs)
		sway.append(j)
	# Arms of floating stone: an upper block, a forearm block and a hand, with gaps between them
	# where crystal light shows.
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.46 * side, 1.74, 0)
		var arm := joint(root, "%sArm" % ("Left" if side < 0 else "Right"), sh)
		var as_ := Sculpt.new(); var ap := as_.add_painter(granite); var ac := as_.add_painter(quartz)
		var el := sh + Vector3(0.12 * side, -0.38, -0.02)
		var wr := el + Vector3(0.04 * side, -0.3, -0.18)
		box(as_, ap, sh.lerp(el, 0.5), Basis(Vector3.FORWARD, -0.3 * side), Vector3(0.08, 0.15, 0.08))
		box(as_, ap, el.lerp(wr, 0.55), Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.FORWARD, -0.12 * side), Vector3(0.065, 0.12, 0.065))
		as_.crystal(el + Vector3(0, 0.03, 0), Vector3(0.2 * side, -1, -0.2), 0.08, 0.035, ac, 6)
		as_.blob(wr + Vector3(0, -0.04, -0.04), Vector3(0.06, 0.08, 0.03), ap, {"lat": 5, "lon": 7})
		for f in range(4):
			var f0 := wr + Vector3((0.035 - f * 0.023) * side, -0.11, -0.04)
			as_.tube([f0, f0 + Vector3(0, -0.05, -0.01), f0 + Vector3(0, -0.08, -0.03)], [0.015, 0.013, 0.01], ap, {"sides": 6, "per": 2})
		part(arm, "Arm", as_)
		sway.append(arm)
	# Curtains of aurora hanging from a ring at its crown: green at the lower edge, fading up
	# through violet into red, folded in waves like the real curtains.
	var au := Sculpt.new()
	var ap2 := au.add_painter(func (p: Vector3, _n, v: float, w: float) -> Color:
		var c := Color("#4aff9a").lerp(Color("#9a5aff"), smoothstep(0.2, 0.65, v)).lerp(Color("#ff4a6a"), smoothstep(0.7, 1.0, v))
		var streak := 0.6 + 0.4 * sin(w * 70.0 + Sculpt.noise(p * 4.0) * 3.0)
		var a := smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.85, 1.0, v)) * 0.7 * streak
		return Color(c.r, c.g, c.b, a))
	var tops: Array = []; var outs: Array = []; var lens: Array = []
	var n := 26
	for k in range(n + 1):
		var a := lerpf(-2.3, 2.3, k / float(n))
		var r := 0.42 + 0.06 * sin(k * 1.3)
		tops.append(Vector3(sin(a) * r, 1.0, cos(a) * r * 0.8 + 0.18)); outs.append(Vector3(sin(a), 0, cos(a)).normalized())
		lens.append(1.25 + 0.2 * sin(k * 0.9))
	var base := au._v.size()
	for i in range(tops.size()):
		var t0: Vector3 = tops[i]; var o: Vector3 = outs[i]; var l: float = lens[i]
		for j in range(13):
			var t := j / 12.0
			# Rising from the hem upward: v is 0 at the bottom (green) and 1 at the top (red).
			var q := t0 + Vector3(0, l * t, 0) + o * (0.08 * sin(i * 0.9 + t * 4.0) + 0.25 * t * t)
			au._v.append(q); au._along.append(t); au._ridge.append(i / float(n)); au._painter.append(ap2)
	for i in range(tops.size() - 1):
		for j in range(12):
			var a := base + i * 13 + j; var b := a + 13
			au._i.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var aj := joint(root, "Aurora", Vector3(0, 1.6, 0.18))
	part(aj, "Aurora", au, aurora_mat)
	sway.append(aj)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": sway}, 1.6)
	return _sway_rig(node, head, sway)
