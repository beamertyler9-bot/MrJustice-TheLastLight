extends "res://tools/sculpt_thistle_jackal.gd"
## The Glass Anubid, boss of the Sunspire Dunes, sculpted by hand: a giant jackal guardian of
## the desert tombs, built like a real jackal (the African golden wolf the Egyptians drew Anubis
## from: long slim legs, deep narrow chest, long muzzle, tall ears) and dressed like the Anubis
## statue from Tutankhamun's tomb: black body, gold-leaf eyebrows, eye rims and ear linings,
## a gold collar with a band knotted round the neck, silver claws and eyes of white calcite
## with dark pupils. Bright prism seams of rainbow light run through it and blaze up as it
## gathers its beam, which it fires from its open jaws. Three designs:
##   obsidian    - black volcanic glass, polished, with the shrine statue's gold and silver
##   desertglass - a weathered sandstone statue with yellow-green desert glass (the glass of
##                 Tutankhamun's pectoral scarab) bursting out along its spine and shoulders
##   crystal     - clear glass all through, its bones and a prism heart glowing inside it

const GOLD_LEAF := Color("#d9ab45")
const SILVER := Color("#d4d8dc")
const LAPIS_BLUE := Color("#25418a")
const TURQ := Color("#3fb8a8")
const CARNELIAN := Color("#a63a22")

var kind := "obsidian"
var prism_mat: StandardMaterial3D
var glass_mat: StandardMaterial3D


func _init() -> void:
	super()
	prism_mat = StandardMaterial3D.new()
	prism_mat.vertex_color_use_as_albedo = true
	prism_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_mat = StandardMaterial3D.new()
	glass_mat.vertex_color_use_as_albedo = true
	glass_mat.roughness = 0.08
	glass_mat.metallic_specular = 1.0
	glass_mat.rim_enabled = true
	glass_mat.rim = 0.6


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GlassAnubid"
	kind = variant
	leg_len = 1.12; whiskers = false
	match variant:
		"obsidian":
			material.albedo_texture = null; material.roughness = 0.12; material.metallic_specular = 1.0
			fur_base = Color("#141418"); fur_belly = GOLD_LEAF
			_eyes(Color("#fff2b0"))
			return _obsidian()
		"desertglass":
			material.albedo_texture = load("res://assets/cast/stone_detail_soft.png"); material.roughness = 0.85
			fur_base = Color("#b39066"); fur_belly = GOLD_LEAF
			_eyes(Color("#d8ff6a"))
			return _desertglass()
		"crystal":
			material.albedo_texture = null; material.roughness = 0.05; material.metallic_specular = 1.0
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.rim_enabled = true; material.rim = 0.8
			fur_base = Color("#9fd8e0"); fur_belly = Color("#e8fbff")
			_eyes(Color("#bff8ff"))
			return _crystal()
	return null


# ------------------------------------------------------------------ painters

## Polished black glass with the soft ripples (conchoidal fractures) obsidian breaks with.
func obsidian() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#0c0c10").lerp(Color("#2c2c38"), clampf(n.y * 0.4 + 0.1 + Sculpt.fbm(p * 3.0) * 0.3, 0.0, 1.0))
		return c.lightened(smoothstep(0.75, 1.0, sin(Sculpt.fbm(p * 2.5) * 30.0)) * 0.08)


## Weathered sandstone, scoured pale and pitted, darker in the hollows.
func sandstone() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#b59d76").lerp(Color("#6f5a40"), clampf(Sculpt.fbm(p * 9.0) * 0.5 + 0.25 - n.y * 0.35, 0.0, 1.0))
		c = c.lerp(Color("#d9cba8"), smoothstep(0.2, 0.5, Sculpt.noise(p * 5.0)) * 0.35)
		c = c.darkened(smoothstep(0.88, 0.98, absf(sin(Sculpt.fbm(p * 3.0) * 12.0))) * 0.45)
		return c.darkened(smoothstep(0.45, 0.6, Sculpt.noise(p * 38.0)) * 0.25)


## Clear glass, faintly blue-green, a little denser where it faces away (so edges read).
func clear_glass() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#b8eef2").lerp(Color("#5fb8c8"), clampf(0.4 - n.y * 0.4 + Sculpt.noise(p * 6.0) * 0.2, 0.0, 1.0))
		return Color(c.r, c.g, c.b, 0.32 + 0.25 * clampf(-n.y, 0.0, 1.0))


## Rainbow light, the hue drifting along the seam so the seams read as split light.
static func prism(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color.from_hsv(fposmod(p.x * 1.3 + p.y * 2.1 + p.z * 1.7, 1.0), 0.75, 1.0).lerp(Color.WHITE, 0.15 + 0.35 * sin(v * PI))


static func gold_leaf(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return GOLD_LEAF.lerp(GOLD_LEAF.darkened(0.45), clampf(-n.y * 0.4 + 0.25 + Sculpt.noise(p * 30.0) * 0.15, 0.0, 1.0)).lightened(smoothstep(0.4, 1.0, n.y) * 0.2)


static func silver(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return SILVER.darkened(clampf(0.3 - n.y * 0.3, 0.0, 0.5)).lerp(Color("#5a5e63"), (1.0 - v) * 0.3)


## Collar bands by ring: gold, lapis, gold, turquoise, gold, carnelian.
static func collar_band(_p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var colors := [GOLD_LEAF, LAPIS_BLUE, GOLD_LEAF, TURQ, GOLD_LEAF, CARNELIAN]
	var c: Color = colors[int(floorf(v * 10.0)) % colors.size()] if v < 0.58 else GOLD_LEAF
	return c.darkened(clampf(-n.y * 0.4 + 0.1, 0.0, 0.5)).lightened(smoothstep(0.5, 1.0, n.y) * 0.15)


# ------------------------------------------------------------------ shared body

## A lathe profile with more rings, so painted bands have vertices to land on.
static func dense(profile: Array, per: int) -> Array:
	var out: Array = []
	for k in range(profile.size() - 1):
		var a: Vector2 = profile[k]; var b: Vector2 = profile[k + 1]
		for i in range(per):
			out.append(a.lerp(b, float(i) / per))
	out.append(profile[-1])
	return out


## The body's surface at length z, angle ang round it (0 on top), pushed out by `out`.
func body_point(z: float, ang: float, lift: float, out := 1.04) -> Vector3:
	var zs := [0.5, 0.3, 0.02, -0.22, -0.4]; var ys := [0.74, 0.78, 0.76, 0.8, 0.86]; var rs := [0.13, 0.16, 0.13, 0.19, 0.17]
	var k := 0
	while k < 3 and z < float(zs[k + 1]): k += 1
	var t := clampf((z - float(zs[k])) / (float(zs[k + 1]) - float(zs[k])), 0.0, 1.0)
	var y: float = lerpf(ys[k], ys[k + 1], t) + lift; var r: float = lerpf(rs[k], rs[k + 1], t) * out
	return Vector3(sin(ang) * r * 0.85, y + cos(ang) * r, z)


## A jagged seam of light running over the body from (z0, a0) to (z1, a1).
func body_seam(s: Sculpt, painter: int, lift: float, z0: float, a0: float, z1: float, a1: float, seed: float) -> void:
	var pts: Array = []; var r: Array = []
	for k in range(7):
		var t := k / 6.0
		var jag := 0.12 * (1.0 if k % 2 == 0 else -1.0) * (0.5 + 0.5 * Sculpt.noise(Vector3(seed, k, 0) * 1.7))
		pts.append(body_point(lerpf(z0, z1, t), lerpf(a0, a1, t) + jag, lift, 1.03)); r.append(0.016 * sin(PI * (0.15 + 0.7 * t)))
	s.tube(pts, r, painter, {"sides": 4, "per": 2, "cap_rings": 1})


## A boss-sized jackal: the shared jackal with a deeper chest, heavier shoulders and neck,
## taller ears, gold eye rims and brows, a jewelled collar with a knotted band and silver claws.
func _anubid(skin: Callable, gold_paint: Callable, claw_paint: Callable) -> Dictionary:
	var parts := _jackal(skin)
	var lift: float = parts.lift; var up := Vector3(0, lift, 0)
	var b: Sculpt = parts.body; var bp: int = parts.body_painter
	b.blob(Vector3(0, 0.74, -0.24) + up, Vector3(0.15, 0.2, 0.18), bp, {"lat": 10, "lon": 14})
	for side: float in [-1.0, 1.0]:
		b.blob(Vector3(0.1 * side, 0.83, -0.28) + up, Vector3(0.085, 0.13, 0.12), bp, {"lat": 8, "lon": 10})
		b.blob(Vector3(0.08 * side, 0.79, 0.34) + up, Vector3(0.07, 0.11, 0.12), bp, {"lat": 8, "lon": 10})
	b.tube([Vector3(0, 0.84, -0.34) + up, Vector3(0, 0.92, -0.48) + up, Vector3(0, 0.99, -0.6) + up], [0.15, 0.125, 0.1], bp, {"sides": 12, "per": 3})
	# The collar, lying over the base of the neck, and the band knotted behind it.
	var gp := b.add_painter(gold_paint)
	b.lathe(Vector3(0, 0.9, -0.46) + up, dense([Vector2(0.125, 0.015), Vector2(0.17, -0.005), Vector2(0.235, -0.03), Vector2(0.24, -0.045), Vector2(0.13, -0.02)], 10), b.add_painter(collar_band), {"sides": 28, "basis": Basis(Vector3.RIGHT, -0.62) * Basis.from_scale(Vector3(0.95, 1.0, 1.0))})
	var band := b.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return CARNELIAN.darkened(clampf(-n.y * 0.4 + 0.1, 0.0, 0.5)))
	b.blob(Vector3(0, 1.02, -0.43) + up, Vector3(0.032, 0.022, 0.026), band, {"lat": 5, "lon": 8})
	for side: float in [-1.0, 1.0]:
		b.tube([Vector3(0.02 * side, 1.03, -0.43) + up, Vector3(0.06 * side, 1.0, -0.35) + up, Vector3(0.09 * side, 0.94, -0.26) + up, Vector3(0.1 * side, 0.9, -0.2) + up], [0.022, 0.024, 0.022, 0.014], band, {"sides": 6, "per": 3, "flat": 0.35, "side": Vector3(side, 1, 0)})
	# Gold brows, eye rims and the long painted line out from each eye.
	var hs: Sculpt = parts.head_sculpt; var h := up
	var hg := hs.add_painter(gold_paint)
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.05 * side, 1.026, -0.733) + h, Vector3(0.036, 0.019, 0.012), hg, {"lat": 5, "lon": 8, "basis": Basis(Vector3.BACK, 0.25 * side)})
		hs.tube([Vector3(0.02 * side, 1.04, -0.758) + h, Vector3(0.05 * side, 1.05, -0.742) + h, Vector3(0.085 * side, 1.066, -0.712) + h], [0.006, 0.009, 0.005], hg, {"sides": 5, "per": 2})
		(parts.core_sculpt as Sculpt).blob(Vector3(0.05 * side, 1.026, -0.739) + h, Vector3(0.03, 0.012, 0.011), 0, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.25 * side)})
		hs.tube([Vector3(0.07 * side, 1.02, -0.725) + h, Vector3(0.095 * side, 1.015, -0.69) + h], [0.006, 0.004], hg, {"sides": 5, "per": 1})
	for ear in parts.ears: (ear as Node3D).scale = Vector3(1.0, 1.4, 1.0)
	for hip in parts.hips: (hip as Node3D).scale = Vector3(1.45, 1.0, 1.35)
	# Silver claws on every toe.
	for k in range(parts.knees.size()):
		var side := -1.0 if k % 2 == 0 else 1.0
		var paw := Vector3(0.12 * side, 0.032, -0.34 if k < 2 else 0.32)
		var cs := Sculpt.new(); var cp := cs.add_painter(claw_paint)
		for c in range(4):
			var toe := paw + Vector3((c - 1.5) * 0.022, -0.004, -0.05)
			cs.crystal(toe + Vector3(0, -0.004, -0.014), Vector3(0, -0.45, -1.0), 0.04, 0.008, cp, 5)
		part(parts.knees[k], "Claws", cs, glass_mat)
	var lp := Node3D.new(); lp.name = "LaunchPoint"; (parts.head as Node3D).add_child(lp)
	lp.position = Vector3(0, 0.955, -0.92) + h - _world(parts.head)
	return parts


## A halo of floating prisms in an arc behind the head, like the sun disc on a god's head;
## each hangs on its own joint so it drifts and sways. `paint` colours them, `mat` is their look.
func _halo(parts: Dictionary, count: int, mat: Material, paint: Callable, length: float, cores := false) -> void:
	var c := Vector3(0, 1.12 + float(parts.lift), -0.5)
	for k in range(count):
		var a := PI * (0.08 + 0.84 * k / float(count - 1))
		var out := Vector3(cos(a), sin(a), 0.15)
		var at := c + Vector3(cos(a) * 0.3, sin(a) * 0.3, 0.0)
		var j := joint(root, "Prism%d" % k, at)
		var s := Sculpt.new(); var pp := s.add_painter(paint)
		var l := length * (1.0 if k % 2 == 0 else 0.7) * (1.15 if k == count / 2 else 1.0)
		s.crystal(at - out * l * 0.35, out, l, l * 0.22, pp, 6, 0.3)
		s.crystal(at - out * l * 0.3, -out, l * 0.3, l * 0.22, pp, 6, 0.3)
		part(j, "Prism", s, mat)
		if cores:
			var gs := Sculpt.new(); var gp := gs.add_painter(prism)
			gs.crystal(at - out * l * 0.2, out, l * 0.55, l * 0.1, gp, 4)
			part(j, "PrismCore", gs, prism_mat)
		parts.fronds.append(j)


## Seams of rainbow light over the flanks, neck and face (on their own meshes, so they glow).
func _seams(parts: Dictionary, count: int) -> void:
	var lift: float = parts.lift
	var s := Sculpt.new(); var pp := s.add_painter(prism)
	var specs := [[0.42, 0.4, -0.15, 1.3], [0.25, 1.1, -0.3, 1.6], [0.45, -0.5, 0.05, -1.4], [0.2, -1.2, -0.38, -0.7], [0.0, 0.1, -0.36, 0.9], [0.4, 1.5, 0.1, 2.2]]
	for i in range(mini(count, specs.size())):
		var sp: Array = specs[i]
		body_seam(s, pp, lift, sp[0], sp[1], sp[2], sp[3], float(i) * 3.1)
	part(root, "PrismSeams", s, prism_mat)
	# A seam down the outside of each leg.
	for k in range(parts.hips.size()):
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := -0.28 if k < 2 else 0.33
		var ls := Sculpt.new(); var lp := ls.add_painter(prism)
		var top := Vector3(0.17 * side, 0.8 + lift, z); var knee := Vector3(0.175 * side, 0.45, z + (0.0 if k < 2 else -0.06))
		ls.tube([top, top.lerp(knee, 0.33) + Vector3(0.01 * side, 0, 0.02), top.lerp(knee, 0.66) + Vector3(0, 0, -0.02), knee], [0.006, 0.012, 0.01, 0.004], lp, {"sides": 4, "per": 2, "cap_rings": 1})
		part(parts.hips[k], "PrismSeam", ls, prism_mat)
	var hs := Sculpt.new(); var hp := hs.add_painter(prism); var h := Vector3(0, lift, 0)
	for side: float in [-1.0, 1.0]:
		hs.tube([Vector3(0.06 * side, 1.06, -0.66) + h, Vector3(0.075 * side, 1.04, -0.62) + h, Vector3(0.08 * side, 1.05, -0.57) + h, Vector3(0.095 * side, 1.01, -0.53) + h], [0.005, 0.007, 0.006, 0.003], hp, {"sides": 4, "per": 2, "cap_rings": 1})
	hs.tube([Vector3(0, 1.065, -0.7) + h, Vector3(0.008, 1.075, -0.64) + h, Vector3(-0.006, 1.08, -0.58) + h, Vector3(0.0, 1.07, -0.53) + h], [0.004, 0.007, 0.006, 0.003], hp, {"sides": 4, "per": 2, "cap_rings": 1})
	part(parts.head, "PrismSeams", hs, prism_mat)


# ------------------------------------------------------------------ A: obsidian

func _obsidian() -> Node3D:
	var parts := _anubid(obsidian(), gold_leaf, silver)
	var lift: float = parts.lift
	_seams(parts, 6)
	# A ridge of black glass blades down the neck and spine, swept back.
	var bs := Sculpt.new(); var bp := bs.add_painter(obsidian())
	for k in range(9):
		var z := lerpf(-0.5, 0.36, k / 8.0)
		var base := body_point(z, 0.0, lift, 0.9) if z > -0.4 else Vector3(0, 1.0 + lift - (z + 0.5) * 0.6, z)
		var l := 0.2 * (1.0 - absf(k - 2.5) / 9.0)
		bs.crystal(base, Vector3(0, 1.0, 0.75), l, 0.035, bp, 4)
	part(root, "Blades", bs, glass_mat)
	_halo(parts, 7, glass_mat, obsidian(), 0.2, true)
	return _close(parts, 2.0)


# ------------------------------------------------------------------ B: desert glass

func _desertglass() -> Node3D:
	var parts := _anubid(sandstone(), gold_leaf, func (p, n, v, w): return Color("#cfe07a").lerp(Color("#6f7a2c"), 1.0 - v))
	var lift: float = parts.lift
	_seams(parts, 4)
	# Desert glass bursting out of the stone along the spine, shoulders and haunches:
	# translucent yellow-green, clustered like crystals breaking out of a geode.
	var gs := Sculpt.new(); var gp := gs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#e6ef9a").lerp(Color("#8fa33a"), clampf(0.6 - v * 0.6 + Sculpt.noise(p * 20.0) * 0.2, 0.0, 1.0)))
	var spots := [[-0.36, 0.0, 0.22], [-0.26, 0.35, 0.16], [-0.26, -0.35, 0.16], [-0.12, 0.1, 0.18], [0.05, -0.15, 0.13], [0.2, 0.2, 0.15], [0.36, 0.5, 0.17], [0.36, -0.5, 0.17], [0.44, 0.0, 0.12]]
	for i in range(spots.size()):
		var sp: Array = spots[i]
		var base := body_point(sp[0], sp[1], lift, 0.85)
		var out := (base - Vector3(0, body_point(sp[0], 0.0, lift, 0.0).y, sp[0])).normalized()
		for j in range(4):
			var a := j * 2.3 + i
			var d := (out + Vector3(cos(a), 0.2, sin(a)) * 0.45).normalized()
			gs.crystal(base + Vector3(cos(a), 0, sin(a)) * 0.03, d, float(sp[2]) * (0.6 + 0.35 * (j % 3)), 0.035 * (1.0 - 0.15 * j), gp, 6, 0.2)
	part(root, "DesertGlass", gs, glass_mat)
	# A great shard of desert glass on its brow, where the beam gathers.
	var cs := Sculpt.new(); var cp := cs.add_painter(func (p, n, v, w): return Color.WHITE)
	cs.crystal(Vector3(0, 1.08, -0.66) + Vector3(0, lift, 0), Vector3(0, 1.0, -0.35), 0.13, 0.03, cp, 6)
	var gem := part(parts.head, "BrowGlass", cs, glow); gem.material_override = glow
	_halo(parts, 5, glass_mat, func (p, n, v, w): return Color("#e6ef9a").lerp(Color("#8fa33a"), 1.0 - v), 0.2)
	return _close(parts, 2.0)


# ------------------------------------------------------------------ C: clear crystal

func _crystal() -> Node3D:
	var parts := _anubid(clear_glass(), func (p, n, v, w): return Color("#e8fbff"), silver)
	var lift: float = parts.lift; var up := Vector3(0, lift, 0)
	_seams(parts, 3)
	# Inside the glass: the spine, ribs and hip bones glowing faintly, and a prism heart.
	var ks := Sculpt.new(); var kp := ks.add_painter(func (p, n, v, w): return Color("#f4f0e2").lerp(Color("#9fd0d8"), 0.3))
	var spine: Array = []; var sr: Array = []
	for k in range(9):
		var z := lerpf(0.48, -0.5, k / 8.0)
		spine.append(body_point(z, 0.0, lift, 0.55) + Vector3(0, 0, 0)); sr.append(0.025)
	spine.append(Vector3(0, 0.98, -0.6) + up); sr.append(0.02)
	ks.tube(spine, sr, kp, {"sides": 6, "per": 2, "bands": 14, "band": 0.25})
	for j in range(6):
		var z := -0.36 + j * 0.06
		for side: float in [-1.0, 1.0]:
			ks.tube([body_point(z, 0.0, lift, 0.55), body_point(z, 1.0 * side, lift, 0.78), body_point(z + 0.03, 1.9 * side, lift, 0.75), body_point(z + 0.05, 2.6 * side, lift, 0.6)], [0.012, 0.012, 0.01, 0.006], kp, {"sides": 5, "per": 2, "cap_rings": 1})
	ks.blob(Vector3(0, 0.78, 0.38) + up, Vector3(0.1, 0.06, 0.08), kp, {"lat": 5, "lon": 8})
	ks.blob(Vector3(0, 1.0, -0.64) + up, Vector3(0.06, 0.05, 0.07), kp, {"lat": 5, "lon": 8})
	part(root, "Bones", ks)
	var hs := Sculpt.new(); var hp := hs.add_painter(prism)
	for j in range(5):
		var a := j * 1.3
		hs.crystal(Vector3(0, 0.74, -0.24) + up, Vector3(cos(a), sin(a) * 0.8, 0.4 * (j % 2 * 2 - 1)), 0.09, 0.03, hp, 5)
	part(root, "PrismHeart", hs, prism_mat)
	_halo(parts, 9, prism_mat, func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return prism(p, n, v, w).lerp(Color("#e8fbff"), 0.5), 0.13)
	return _close(parts, 2.0)
