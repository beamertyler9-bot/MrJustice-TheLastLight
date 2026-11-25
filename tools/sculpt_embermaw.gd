extends "res://tools/sculpt_shard_sentinel.gd"
## Embermaw, boss of the Embervein mine, sculpted by hand: a great four-legged beast of the
## deep fire, armoured in cooled basalt with molten rock glowing through every seam and a
## furnace burning in its throat; it rears and slams, and breathes the heat of the mountain.
## Its volcanic armour and glowing core are kept from the original. Three designs:
##   monitor   - a monitor lizard as big as a cart (the Komodo dragon: long, low and heavy, a
##               sprawling gait, a long flat skull, a forked yellow tongue, a deep muscular tail)
##               armoured like a cooling lava flow - pahoehoe ropes on its flanks, a'a clinker
##               plates down its back, glowing cracks between, and basalt columns along its spine
##   ankylos   - an ankylosaur (Ankylosaurus, Euoplocephalus): a broad low body roofed with rows
##               of bony plates (osteoderms) and side spikes, a short beaked head with horns at the
##               back corners of the skull, and a tail ending in a heavy bony club - here the
##               plates are basalt, the club a lump of magma half-cooled
##   thornback - a horned lizard (Phrynosoma) grown huge: a flat round body bristling with
##               spines, a crown of long horns round the back of its head, a short blunt face;
##               the real one squirts blood from its eyes when cornered - this one weeps lava
##   drake     - the monitor grown into a flightless fire drake: a hunched, heavy-shouldered
##               build, a horned and spined head, a mane of basalt spikes, and two small torn
##               wings of scorched skin it can no longer fly with

var kinde := "monitor"
var drake := false
var hide_paint: Callable = basalt
var res := 1
var lava_mat: StandardMaterial3D
var crown_mat: StandardMaterial3D
var attack_glow: StandardMaterial3D
var hurt_glow: StandardMaterial3D


func _init() -> void:
	super()
	material.uv1_scale = Vector3(3, 3, 3); material.roughness = 0.9
	lava_mat = StandardMaterial3D.new()
	lava_mat.vertex_color_use_as_albedo = true; lava_mat.vertex_color_is_srgb = true
	lava_mat.emission_enabled = true; lava_mat.emission = Color("#ff5a10"); lava_mat.emission_energy_multiplier = 1.6
	lava_mat.albedo_color = Color("#ff7a20")


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Embermaw"
	kinde = variant; kindc = "quartz"; kind = "sentinel"
	glow.albedo_color = Color("#ffb030"); glow.emission = Color("#ffa020"); glow.emission_energy_multiplier = 2.6
	attack_glow = glow.duplicate(); attack_glow.emission = Color("#fff0a0"); attack_glow.emission_energy_multiplier = 4.5
	hurt_glow = glow.duplicate(); hurt_glow.emission = Color("#ff2a10"); hurt_glow.albedo_color = Color("#a8200c")
	crown_mat = lava_mat.duplicate(); crown_mat.emission_energy_multiplier = 3.0
	if variant == "spino": drake = true; return _spino()
	if not variant in ["monitor", "ankylos", "thornback", "drake"]: return null
	if variant == "drake": kinde = "monitor"; drake = true; hide_paint = crust; res = 1
	return _beast()


# ------------------------------------------------------------------ painters

## Cooled basalt: near-black, glassy where it caught the light, rough and pitted.
static func basalt(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#121012").lerp(Color("#4a4448"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(p * 6.0) * 0.45, 0.0, 1.0))
	c = c.lerp(Color("#6a5a58"), smoothstep(0.6, 0.75, Sculpt.noise(p * 22.0)) * 0.3)
	# Heat showing through low down and in the hollows.
	return c.lerp(Color("#7a2a0c"), smoothstep(-0.2, -0.8, n.y) * 0.45)


## Ropy pahoehoe: dark skins of rock pulled into folds, glowing between the folds.
static func pahoehoe(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := basalt(p, n, v, w)
	var rope := absf(sin(p.z * 26.0 + sin(p.y * 9.0 + p.x * 4.0) * 2.0))
	return c.lerp(Color("#ff6a14"), smoothstep(0.08, 0.0, rope) * 0.8)


## Cooled lava crust: dark basalt broken into plates (a cellular pattern, as a flow's crust
## cracks into polygons), each plate a little different, molten rock glowing in the seams
## between them - brighter low down and on the belly, where the heat is.
static func crust(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var q := p * 4.2
	var cell := q.floor()
	var d1 := 9.0; var d2 := 9.0; var id := Vector3.ZERO
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var c := cell + Vector3(x, y, z)
				var h := Vector3(fposmod(sin(c.dot(Vector3(127.1, 311.7, 74.7))) * 43758.5453, 1.0), fposmod(sin(c.dot(Vector3(269.5, 183.3, 246.1))) * 43758.5453, 1.0), fposmod(sin(c.dot(Vector3(113.5, 271.9, 124.6))) * 43758.5453, 1.0))
				var d := (c + h - q).length()
				if d < d1: d2 = d1; d1 = d; id = c
				elif d < d2: d2 = d
	var tint := fposmod(sin(id.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)
	var c0 := Color("#121012").lerp(Color("#3a3436"), clampf(n.y * 0.35 + 0.3 + tint * 0.3 + Sculpt.noise(p * 20.0) * 0.12, 0.0, 1.0))
	# The plate's own edge catches the light a little.
	c0 = c0.lightened(smoothstep(0.18, 0.1, d2 - d1) * 0.08)
	var heat := 0.3 + 0.7 * smoothstep(0.15, -0.7, n.y)
	var seam := smoothstep(0.07, 0.025, d2 - d1) * heat
	var c1 := Color("#ff4a08").lerp(Color("#ffb030"), smoothstep(0.03, 0.0, d2 - d1))
	return c0.lerp(c1, seam)


static func ember_belly(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := basalt(p, n, v, w)
	var scale := absf(sin(p.x * 30.0)) * absf(sin(p.z * 24.0))
	return c.lerp(Color("#d84a10"), smoothstep(-0.3, -0.85, n.y) * smoothstep(0.1, 0.5, scale) * 0.9)


static func horn(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color("#1a1210").lerp(Color("#c8a080"), v * v).lerp(Color("#ff8a30"), smoothstep(0.85, 1.0, v) * 0.6)


static func molten(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color("#ff4a08").lerp(Color("#ffd060"), clampf(Sculpt.noise(p * 10.0) * 0.6 + 0.4 + v * 0.2, 0.0, 1.0))


# ------------------------------------------------------------------ pieces

## A thick glowing vein of lava over the surface, jagged, from `a` to `b`.
func vein(s: Sculpt, p: int, a: Vector3, b: Vector3, out: Vector3, jag: float, seed: float, w := 0.03) -> void:
	var pts: Array = []; var rr: Array = []
	var side := (b - a).cross(out).normalized()
	for k in range(7):
		var t := k / 6.0
		pts.append(a.lerp(b, t) + side * jag * sin(seed + k * 2.7) * (1.0 - absf(t - 0.5) * 1.4) + out * 0.01)
		rr.append(w * (1.0 - absf(t - 0.4) * 1.2) + 0.004)
	s.tube(pts, rr, p, {"sides": 4, "per": 1, "cap_rings": 1})

## A basalt plate (an osteoderm or a clinker): a low faceted rock lying on the surface at `at`
## facing `up`, with a seam of lava round its foot.
func plate(s: Sculpt, sp: int, lava: Sculpt, lp: int, at: Vector3, up: Vector3, size: float, seed: int, keel := 0.0) -> void:
	var u := up.normalized()
	var b := Basis(Quaternion(Vector3.UP, u))
	s.rock(at, Vector3(size, size * 0.45, size * 0.9), sp, {"seed": seed, "basis": b, "lat": 4, "lon": 6} if drake else {"seed": seed, "basis": b})
	if keel > 0.0: s.crystal(at + u * size * 0.3, u, keel, size * 0.35, sp, 4, seed * 0.7)
	if drake: return
	var ring: Array = []; var rr: Array = []
	for k in range(9):
		var a := TAU * k / 8.0
		ring.append(at + b * Vector3(cos(a) * size * 1.02, -size * 0.2, sin(a) * size * 0.92)); rr.append(size * 0.06)
	lava.tube(ring, rr, lp, {"sides": 4, "per": 1})


## A sprawling leg from `hip` out to the elbow or knee and down to a broad clawed foot.
func leg(parent: Node3D, hip_name: String, knee_name: String, hip: Vector3, side: float, front: bool, thick: float, list_h: Array, list_k: Array) -> void:
	var h := joint(parent, hip_name, hip)
	var kn := hip + Vector3(0.42 * side, 0.04, -0.06 if front else 0.12)
	var ft := Vector3(kn.x + 0.1 * side, 0.0, kn.z + (-0.12 if front else 0.04))
	var us := Sculpt.new(); var up := us.add_painter(hide_paint); var lv := Sculpt.new(); var lp := lv.add_painter(molten)
	us.blob(hip, Vector3(thick * 1.6, thick * 1.4, thick * 1.6), up, {"lat": 7 * res, "lon": 10 * res, "lump": 0.08})
	us.tube([hip, hip.lerp(kn, 0.5) + Vector3(0, 0.05, 0), kn], [thick * 1.35, thick * 1.25, thick], up, {"sides": 12 * res, "per": 2 * res, "lump": 0.08})
	plate(us, up, lv, lp, hip.lerp(kn, 0.4) + Vector3(0, thick * 1.1, 0), Vector3(0.3 * side, 1, 0), thick * 0.9, int(hip.x * 10.0 + hip.z * 7.0))
	part(h, "UpperLeg", us)
	part(h, "UpperLava", lv, lava_mat)
	var knee := joint(h, knee_name, kn)
	var ls := Sculpt.new(); var lpp := ls.add_painter(hide_paint); var cl := ls.add_painter(horn)
	var lv2 := Sculpt.new(); var lp2 := lv2.add_painter(molten)
	ls.blob(kn, Vector3.ONE * thick * 1.05, lpp, {"lat": 6 * res, "lon": 8 * res, "lump": 0.08})
	ls.tube([kn, kn.lerp(ft, 0.5) + Vector3(0.02 * side, 0, 0), ft + Vector3(0, thick * 0.6, 0)], [thick * 0.95, thick * 0.85, thick * 0.8], lpp, {"sides": 12 * res, "per": 2 * res, "lump": 0.08})
	vein(lv2, lp2, kn + Vector3(0, -0.02, -thick * 0.9), ft + Vector3(0.02 * side, thick * 0.8, -thick * 0.8), Vector3(0, 0, -1), 0.04, hip.x, 0.022)
	# A broad foot with five hooked claws.
	ls.blob(ft + Vector3(0, thick * 0.45, -thick * 0.2), Vector3(thick * 1.25, thick * 0.55, thick * 1.35), lpp, {"lat": 6, "lon": 9, "lump": 0.06})
	for c in range(5):
		var cd := Vector3((c - 2) * 0.32 + side * 0.15, 0.0, -1.0).normalized()
		var cb := ft + Vector3(0, thick * 0.35, -thick * 0.2) + cd * thick * 1.1
		ls.tube([cb, cb + cd * thick * 0.6 + Vector3(0, 0.01, 0), cb + cd * thick * 1.0 + Vector3(0, -thick * 0.35, 0)], [thick * 0.26, thick * 0.18, 0.003], cl, {"sides": 6, "per": 2, "cap1": false})
	if drake:
		# Scutes of cooled crust down the front of the forearm or shin, a spur at the elbow.
		for k in range(3): plate(ls, lpp, lv2, lp2, kn.lerp(ft, 0.15 + k * 0.25) + Vector3(0.04 * side, 0.02, -thick * 0.75), Vector3(0.3 * side, 0.2, -1), thick * 0.55, int(hip.z * 13.0) + k, thick * 0.3)
		ls.crystal(kn + Vector3(0.03 * side, 0.02, thick * 0.6), Vector3(0.4 * side, 0.4, 1), thick * 1.6, thick * 0.35, cl, 4)
	part(knee, "LowerLeg", ls)
	part(knee, "LowerLava", lv2, lava_mat)
	list_h.append(h); list_k.append(knee)


# ------------------------------------------------------------------ the beast

func _beast() -> Node3D:
	var monitor := kinde == "monitor"; var ank := kinde == "ankylos"; var thorn := kinde == "thornback"
	var bs := Sculpt.new(); var sp := bs.add_painter(crust if drake else (pahoehoe if monitor else basalt)); var bp := bs.add_painter(ember_belly); var hp := bs.add_painter(horn)
	var lava := Sculpt.new(); var lp := lava.add_painter(molten)
	var y := 0.78
	# ---- the body
	var spine: Array; var rads: Array
	if monitor and drake:
		spine = [Vector3(0, y + 0.3, -1.0), Vector3(0, y + 0.24, -0.58), Vector3(0, y + 0.1, 0.0), Vector3(0, y - 0.02, 0.6), Vector3(0, y - 0.1, 1.0)]
		rads = [0.34, 0.56, 0.54, 0.44, 0.32]
	elif monitor:
		spine = [Vector3(0, y + 0.08, -0.95), Vector3(0, y + 0.06, -0.55), Vector3(0, y + 0.02, 0.0), Vector3(0, y - 0.04, 0.6), Vector3(0, y - 0.1, 1.0)]
		rads = [0.3, 0.44, 0.5, 0.44, 0.32]
	elif ank:
		spine = [Vector3(0, y + 0.0, -0.85), Vector3(0, y + 0.12, -0.45), Vector3(0, y + 0.18, 0.05), Vector3(0, y + 0.1, 0.55), Vector3(0, y - 0.05, 0.95)]
		rads = [0.34, 0.6, 0.7, 0.6, 0.36]
	else:
		spine = [Vector3(0, y + 0.02, -0.8), Vector3(0, y + 0.08, -0.4), Vector3(0, y + 0.1, 0.05), Vector3(0, y + 0.04, 0.5), Vector3(0, y - 0.06, 0.85)]
		rads = [0.36, 0.62, 0.72, 0.6, 0.34]
	bs.tube(spine, rads, sp, {"sides": 30 if drake else 22, "per": 6 if drake else 4, "flat": 0.62 if not monitor else 0.75, "side": Vector3.UP, "lump": 0.05, "cap0": false})
	bs.tube([spine[1] + Vector3(0, -0.18, 0), spine[3] + Vector3(0, -0.18, 0)], [rads[1] * 0.75, rads[3] * 0.75], bp, {"sides": 16, "per": 3, "flat": 0.5, "side": Vector3.UP})
	# ---- armour along the back
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	if monitor:
		# A'a clinker plates in a broad band down the back, and a crest of basalt columns.
		for k in range(14):
			var t := k / 13.0
			var at := along_line(spine, 0.05 + t * 0.9)
			var r: float = lerpf(rads[1], rads[3], t) * (1.0 - 0.3 * absf(t - 0.5))
			for sx: float in [-1.0, 0.0, 1.0]:
				var a := sx * 0.7
				var nrm := Vector3(sin(a), cos(a), 0)
				plate(bs, sp, lava, lp, at + Vector3(sin(a) * r * 0.85, cos(a) * r * 0.62, 0), nrm, 0.14 + 0.04 * (k % 2), k * 3 + int(sx) + 5, 0.06 if sx == 0.0 else 0.0)
			beam(bs, sp, at + Vector3(0, r * 0.7, 0), Vector3(0, 1, 0.3), 0.2 + 0.25 * sin(PI * t), 0.09, 0.07, k * 0.8)
	elif ank:
		# Rows of osteoderms across the back, a keel on each, side spikes along the flanks,
		# and a collar of plates over the neck.
		for row in range(6):
			var t := 0.12 + row * 0.15
			var at := along_line(spine, t)
			var r: float = lerpf(rads[1], rads[3], t)
			for k in range(5):
				var a := lerpf(-1.1, 1.1, k / 4.0)
				var nrm := Vector3(sin(a), cos(a) * 0.9, 0).normalized()
				plate(bs, sp, lava, lp, at + Vector3(sin(a) * r, cos(a) * r * 0.62, 0) * 0.98, nrm, 0.17, row * 7 + k, 0.14 + 0.06 * (k % 2))
			for side: float in [-1.0, 1.0]:
				bs.crystal(at + Vector3(side * r * 0.98, -0.05, 0), Vector3(side, 0.05, 0.15 * (row - 2.5)), 0.38 + 0.12 * sin(PI * row / 5.0), 0.09, hp, 4, row)
		for k in range(4):
			var a := lerpf(-0.9, 0.9, k / 3.0)
			plate(bs, sp, lava, lp, spine[0] + Vector3(sin(a) * 0.3, 0.22, 0.05), Vector3(sin(a), 1, 0), 0.1, 50 + k, 0.1)
	else:
		# A forest of spines over the flat back, longest along the sides, each with lava at its root.
		for k in range(90):
			var t := rng.randf_range(0.08, 0.95)
			var a := rng.randf_range(-1.35, 1.35)
			var at := along_line(spine, t)
			var r: float = lerpf(rads[1], rads[3], t)
			var nrm := Vector3(sin(a), cos(a) * 0.62, 0).normalized()
			var base := at + Vector3(sin(a) * r * 0.98, cos(a) * r * 0.6, 0)
			bs.crystal(base, nrm + Vector3(0, 0.3, 0.4), 0.14 + absf(a) * 0.16, 0.045 + absf(a) * 0.015, hp, 4, k)
			if k % 3 == 0: lava.blob(base, Vector3.ONE * 0.04, lp, {"lat": 3, "lon": 5})
		# The fringe of flat scales round the body's edge.
		for k in range(24):
			var t := k / 23.0
			for side: float in [-1.0, 1.0]:
				var at := along_line(spine, 0.12 + t * 0.78)
				var r: float = lerpf(rads[1], rads[3], t)
				bs.crystal(at + Vector3(side * r * 1.0, -0.12, 0), Vector3(side, -0.2, 0.2), 0.2, 0.06, hp, 4, k)
	# Glowing cracks across the flanks.
	for side: float in [-1.0, 1.0]:
		for k in range(5):
			var at := along_line(spine, 0.2 + k * 0.15)
			var r: float = rads[2] * 0.95
			vein(lava, lp, at + Vector3(side * r * 0.98, 0.14, -0.1), at + Vector3(side * r * 0.92, -0.28, 0.08), Vector3(side, 0, 0), 0.06, k + side, 0.035)
	part(root, "Body", bs)
	part(root, "BodyLava", lava, lava_mat)

	# ---- the awakened furnace: vents opening along the spine, shown when enraged
	var cr := Sculpt.new(); var crp := cr.add_painter(molten)
	for k in range(7):
		var t := 0.15 + k * 0.11
		var at := along_line(spine, t)
		var r: float = lerpf(rads[1], rads[3], t)
		cr.crystal(at + Vector3(0, r * (0.8 if not monitor else 0.75), 0), Vector3(0, 1, 0.3), 0.3 + 0.15 * sin(PI * k / 6.0), 0.06, crp, 5, k)
	var crown := part(root, "AwakenedDorsalFurnace", cr, crown_mat); crown.material_override = crown_mat
	crown.visible = false

	# ---- the head
	var head_at: Vector3 = (spine[0] as Vector3) + (Vector3(0, 0.32, -0.42) if drake else Vector3(0, 0.05, -0.1))
	if drake:
		# A thick neck rising forward from the shoulders.
		bs.tube([spine[1], spine[0], head_at + Vector3(0, -0.05, 0.12)], [rads[1] * 0.75, 0.36, 0.3], sp, {"sides": 22, "per": 4, "lump": 0.05, "bands": 8, "band": 0.05})
	var head := joint(root, "FurnaceSkull", head_at)
	var hs := Sculpt.new(); var hb := hs.add_painter(hide_paint); var hh := hs.add_painter(horn); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#060404"))
	var hl := Sculpt.new(); var hlp := hl.add_painter(molten)
	var snout: Vector3; var jaw_at: Vector3; var eyes: Array = []
	if monitor:
		# A long flat skull, the snout narrowing, nostrils near the tip, heavy brows.
		if drake:
			# A broad, heavy skull: a domed cranium behind and a wide, flat, blunt snout in front.
			hs.blob(head_at + Vector3(0, 0.04, -0.15), Vector3(0.3, 0.17, 0.27), hb, {"lat": 10, "lon": 14, "lump": 0.04})
			hs.blob(head_at + Vector3(0, -0.01, -0.5), Vector3(0.3, 0.12, 0.32), hb, {"lat": 9, "lon": 14, "lump": 0.04})
			hs.blob(head_at + Vector3(0, 0.04, -0.32), Vector3(0.22, 0.13, 0.2), hb, {"lat": 7, "lon": 10, "lump": 0.04})
			# The upper lip line, a ridge running back from the snout's corners.
			for sd: float in [-1.0, 1.0]:
				hs.tube([head_at + Vector3(0.26 * sd, -0.06, -0.72), head_at + Vector3(0.3 * sd, -0.07, -0.45), head_at + Vector3(0.27 * sd, -0.06, -0.15)], [0.03, 0.035, 0.03], hb, {"sides": 8, "per": 3})
		else:
			hs.tube([head_at, head_at + Vector3(0, 0.02, -0.25), head_at + Vector3(0, -0.02, -0.55), head_at + Vector3(0, -0.06, -0.78)], [0.34, 0.32, 0.23, 0.13], hb, {"sides": 16, "per": 3, "flat": 1.45, "lump": 0.05, "cap0": false})
		snout = head_at + Vector3(0, -0.06, -0.8)
		for side: float in [-1.0, 1.0]:
			if drake:
				# A heavy brow ridge overhanging each eye, the eye set in a deep socket on the
				# side of the broad skull.
				hs.tube([head_at + Vector3(0.08 * side, 0.2, -0.46), head_at + Vector3(0.18 * side, 0.21, -0.35), head_at + Vector3(0.27 * side, 0.17, -0.24), head_at + Vector3(0.31 * side, 0.1, -0.1)], [0.03, 0.05, 0.05, 0.03], hb, {"sides": 10, "per": 3})
				hs.blob(head_at + Vector3(0.22 * side, 0.11, -0.33), Vector3(0.04, 0.035, 0.07), hd, {"lat": 6, "lon": 9})
				eyes.append(head_at + Vector3(0.237 * side, 0.11, -0.33))
				# Cheek plates behind the eye and down to the jaw hinge.
				for k in range(3): plate(hs, hb, hl, hlp, head_at + Vector3(0.3 * side, 0.02 - k * 0.04, -0.1 + k * 0.08), Vector3(side, 0.3, 0.2), 0.07, 60 + k, 0.05)
			else:
				hs.tube([head_at + Vector3(0.08 * side, 0.15, -0.38), head_at + Vector3(0.17 * side, 0.14, -0.22), head_at + Vector3(0.2 * side, 0.1, -0.05)], [0.035, 0.045, 0.03], hb, {"sides": 6, "per": 2})
				eyes.append(head_at + Vector3(0.18 * side, 0.08, -0.28))
			hs.blob(snout + (Vector3(0.1 * side, 0.09, 0.12) if drake else Vector3(0.05 * side, 0.06, 0.04)), Vector3(0.035, 0.02, 0.035) if drake else Vector3(0.025, 0.015, 0.03), hd, {"lat": 4, "lon": 6})
			if not drake: for k in range(4): plate(hs, hb, hl, hlp, head_at + Vector3(0.1 * side, 0.15, -0.05 - k * 0.12), Vector3(0.3 * side, 1, 0), 0.05, 30 + k, 0.0)
		jaw_at = head_at + (Vector3(0, -0.1, 0.05) if drake else Vector3(0, -0.12, 0.05))
	elif ank:
		# A short deep skull with a beak, horns at the back corners and over the eyes.
		hs.blob(head_at + Vector3(0, 0, -0.18), Vector3(0.38, 0.3, 0.36), hb, {"lat": 10, "lon": 14, "lump": 0.08})
		hs.tube([head_at + Vector3(0, -0.04, -0.4), head_at + Vector3(0, -0.08, -0.55)], [0.18, 0.1], hb, {"sides": 12, "per": 2, "flat": 1.3, "cap_len": 0.5})
		snout = head_at + Vector3(0, -0.1, -0.58)
		hs.tube([snout + Vector3(0, 0.06, 0.04), snout + Vector3(0, -0.02, -0.04), snout + Vector3(0, -0.1, -0.02)], [0.08, 0.05, 0.01], hh, {"sides": 8, "per": 2, "flat": 1.3})
		for side: float in [-1.0, 1.0]:
			hs.crystal(head_at + Vector3(0.26 * side, 0.08, 0.02), Vector3(side, 0.2, 0.6), 0.28, 0.07, hh, 5)
			hs.crystal(head_at + Vector3(0.22 * side, -0.08, -0.05), Vector3(side, -0.6, 0.4), 0.2, 0.06, hh, 5)
			hs.crystal(head_at + Vector3(0.18 * side, 0.16, -0.3), Vector3(side * 0.6, 0.6, -0.2), 0.12, 0.04, hh, 5)
			eyes.append(head_at + Vector3(0.22 * side, 0.06, -0.3))
			for k in range(3): plate(hs, hb, hl, hlp, head_at + Vector3(0.1 * side, 0.2, -0.05 - k * 0.12), Vector3(0.3 * side, 1, 0), 0.06, 40 + k, 0.04)
		jaw_at = head_at + Vector3(0, -0.14, 0.0)
	else:
		# A short blunt head, flat on top, with a crown of long horns round the back.
		hs.blob(head_at + Vector3(0, 0, -0.18), Vector3(0.4, 0.26, 0.36), hb, {"lat": 10, "lon": 14, "lump": 0.06})
		hs.tube([head_at + Vector3(0, -0.02, -0.35), head_at + Vector3(0, -0.06, -0.5)], [0.2, 0.12], hb, {"sides": 12, "per": 2, "flat": 1.5, "cap_len": 0.5})
		snout = head_at + Vector3(0, -0.06, -0.52)
		for k in range(9):
			var a := lerpf(-1.4, 1.4, k / 8.0)
			var l := 0.34 + 0.2 * (1.0 - absf(a) / 1.4) if absf(a) > 0.2 else 0.2
			hs.crystal(head_at + Vector3(sin(a) * 0.3, 0.08, cos(a) * 0.12 + 0.05), Vector3(sin(a) * 1.0, 0.5, 1.0), l, 0.05, hh, 5, k)
		for side: float in [-1.0, 1.0]:
			hs.crystal(head_at + Vector3(0.2 * side, 0.16, -0.25), Vector3(side * 0.5, 1, 0), 0.12, 0.035, hh, 4)
			eyes.append(head_at + Vector3(0.22 * side, 0.08, -0.25))
			# Lava weeping from the eye down the cheek.
			hl.tube([head_at + Vector3(0.24 * side, 0.05, -0.27), head_at + Vector3(0.27 * side, -0.05, -0.25), head_at + Vector3(0.28 * side, -0.16, -0.22)], [0.02, 0.018, 0.024], hlp, {"sides": 5, "per": 2})
		jaw_at = head_at + Vector3(0, -0.12, 0.0)
	# Eyes: molten slits under the brows.
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for e: Vector3 in eyes:
		if drake:
			# A narrow, slanted, deep-set eye: molten, with a black slit, under the brow.
			var eb := Basis(Vector3.UP, -0.35 * signf(e.x)) * Basis(Vector3.FORWARD, 0.3 * signf(e.x))
			es.blob(e, Vector3(0.02, 0.022, 0.055), ew, {"lat": 6, "lon": 9, "basis": eb})
			hs.blob(e + Vector3(signf(e.x) * 0.018, 0, -0.004), Vector3(0.004, 0.02, 0.008), hd, {"lat": 4, "lon": 6})
		else:
			es.blob(e, Vector3(0.04, 0.025, 0.05), ew, {"lat": 4, "lon": 7})
			hs.blob(e + Vector3(signf(e.x) * 0.03, 0, 0), Vector3(0.008, 0.022, 0.025), hd, {"lat": 3, "lon": 5})
	part(head, "Skull", hs)
	part(head, "SkullLava", hl, lava_mat)
	part(head, "Eyes", es, glow).material_override = glow
	# The throat: the furnace glowing in the mouth (the boss's core).
	var ts := Sculpt.new(); var tw := ts.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	var throat_at := snout.lerp(jaw_at, 0.45) + Vector3(0, -0.02, 0)
	ts.blob(throat_at + Vector3(0, -0.04, 0), Vector3(0.16 if not monitor else (0.22 if drake else 0.13), 0.08, 0.26 if monitor else 0.2), tw, {"lat": 5, "lon": 9})
	var core := part(head, "FurnaceThroat", ts, glow); core.material_override = glow
	# Upper teeth.
	var teeth_p := hs.add_painter(horn)
	var tl := Sculpt.new(); var tlp := tl.add_painter(horn)
	for side: float in [-1.0, 1.0]:
		var n := 7 if monitor else 5
		for k in range(n):
			var at := snout.lerp(jaw_at, 0.05 + k / float(n) * 0.75) + Vector3(side * ((0.26 - k * 0.01) if drake else (0.06 + k * (0.025 if monitor else 0.035))), -0.02, 0)
			tl.crystal(at, Vector3(0, -1, 0.1), 0.06 + (0.03 if k == 1 else 0.0), 0.014, tlp, 4)
	part(head, "Teeth", tl)
	# The jaw, hinged at the back.
	var jaw := joint(head, "HingedBasaltJaw", jaw_at)
	var js := Sculpt.new(); var jp := js.add_painter(hide_paint); var jt := js.add_painter(horn)
	var jl := Sculpt.new(); var jlp := jl.add_painter(molten)
	var jaw_tip := snout + Vector3(0, -0.12, 0.04)
	js.tube([jaw_at + Vector3(0, -0.02, 0.02), jaw_at.lerp(jaw_tip, 0.5) + Vector3(0, -0.04, 0), jaw_tip], [0.2 if not monitor else (0.13 if drake else 0.18), 0.16 if not monitor else (0.11 if drake else 0.13), 0.13 if drake else 0.06], jp, {"sides": 14 * res, "per": 3 * res, "flat": 2.4 if drake else 1.5, "lump": 0.05})
	jl.blob(jaw_at.lerp(jaw_tip, 0.45) + Vector3(0, 0.07, 0), Vector3(0.2 if drake else 0.11, 0.025, (jaw_tip - jaw_at).length() * 0.42), jlp, {"lat": 4, "lon": 8})
	for side: float in [-1.0, 1.0]:
		var n := 6 if monitor else 4
		for k in range(n):
			var at := jaw_tip.lerp(jaw_at, 0.08 + k / float(n) * 0.7) + Vector3(side * ((0.24 - k * 0.01) if drake else (0.05 + k * 0.03)), 0.06, 0)
			js.crystal(at, Vector3(0, 1, -0.1), 0.05, 0.012, jt, 4)
	if monitor:
		# The forked tongue, flicking out.
		var tongue := js.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#ffb020").lerp(Color("#ff4a08"), v))
		for side: float in [-1.0, 1.0]:
			js.tube([jaw_tip + Vector3(0, 0.08, 0.2), jaw_tip + Vector3(0, 0.07, -0.05), jaw_tip + Vector3(0.05 * side, 0.08, -0.25)], [0.02, 0.014, 0.003], tongue, {"sides": 5, "per": 2, "flat": 1.6, "cap1": false})
	if drake:
		var jlv := jl.add_painter(molten)
		for side: float in [-1.0, 1.0]:
			for k in range(4): plate(js, jp, jl, jlv, jaw_at.lerp(jaw_tip, 0.15 + k * 0.22) + Vector3(0.24 * side, -0.06, 0), Vector3(side, -0.4, 0), 0.07, 80 + k + int(side), 0.03)
	if ank or thorn:
		for side: float in [-1.0, 1.0]: js.crystal(jaw_at + Vector3(0.2 * side, -0.08, -0.1), Vector3(side, -0.6, 0.4), 0.16, 0.04, jt, 4)
	part(jaw, "Jaw", js).rotation.x = -0.42 if drake else -0.3
	part(jaw, "MoltenMouthFloor", jl, lava_mat).rotation.x = -0.42 if drake else -0.3

	# ---- the tail
	var tail_at: Vector3 = spine[4]
	var tail := joint(root, "ArticulatedFurnaceTail", tail_at)
	var tls := Sculpt.new(); var tlb := tls.add_painter(crust if drake else (pahoehoe if monitor else basalt)); var th := tls.add_painter(horn)
	var tlv := Sculpt.new(); var tlvp := tlv.add_painter(molten)
	var tpts: Array = []; var trr: Array = []
	var tl_len := 1.9 if monitor else (1.3 if ank else 0.8)
	for k in range(8):
		var t := k / 7.0
		tpts.append(tail_at + Vector3(0.18 * sin(t * 2.2), -0.6 * t * t + (-0.05 if monitor else 0.05) * t, tl_len * t)); trr.append(lerpf(rads[4] * 0.95, 0.06 if not ank else 0.1, t))
	tls.tube(tpts, trr, tlb, {"sides": 14 * res, "per": 3 * res, "lump": 0.05, "flat": 0.8, "side": Vector3.UP})
	for k in range(7):
		var at: Vector3 = tpts[k]; var r: float = trr[k]
		if monitor: beam(tls, tlb, at + Vector3(0, r * 0.7, 0), Vector3(0, 1, 0.4), 0.1 + 0.05 * (1.0 - k / 7.0), 0.05, 0.04, k)
		elif thorn: for side: float in [-1.0, 1.0]: tls.crystal(at + Vector3(side * r * 0.9, 0.0, 0), Vector3(side, 0.3, 0.3), 0.08, 0.025, th, 4, k)
		else:
			for side: float in [-1.0, 1.0]: tls.crystal(at + Vector3(side * r * 0.9, 0.04, 0), Vector3(side, 0.2, 0.5), 0.12, 0.035, th, 4, k)
		tlv.tube([at + Vector3(0, r * 0.75, -0.04), at + Vector3(0.02, r * 0.72, 0.06)], [0.012, 0.01], tlvp, {"sides": 4, "per": 1})
	if ank:
		# The club: two great knobs of basalt round a molten core, cracked and glowing.
		var cend: Vector3 = tpts[7]
		for side: float in [-1.0, 1.0]: tls.rock(cend + Vector3(side * 0.14, 0, 0.05), Vector3(0.2, 0.16, 0.24), tlb, {"seed": 9 + int(side)})
		tls.rock(cend + Vector3(0, 0.04, 0.2), Vector3(0.14, 0.12, 0.14), tlb, {"seed": 12})
		for k in range(5): crack(tlv, tlvp, cend + Vector3(-0.2 + k * 0.1, 0.17, -0.1), cend + Vector3(-0.15 + k * 0.08, 0.1, 0.3), Vector3(0, 1, 0), 0.04, k)
	part(tail, "Tail", tls)
	part(tail, "TailLava", tlv, lava_mat)

	if drake: _drake_extras(spine, rads, head, head_at, jaw, jaw_at)
	# ---- the legs
	var arms: Array = []; var forearms: Array = []; var feet: Array = []; var knees: Array = []
	var front_at := along_line(spine, 0.18); var back_at := along_line(spine, 0.82)
	var thick := 0.15 if monitor else 0.17
	for side: float in [-1.0, 1.0]:
		leg(root, ("LeftShovelShoulder" if side < 0 else "RightShovelShoulder"), ("LeftShovelElbow" if side < 0 else "RightShovelElbow"), front_at + Vector3(side * rads[1] * 0.85, -0.18, 0), side, true, thick, arms, forearms)
	for side: float in [-1.0, 1.0]:
		leg(root, ("LeftHindHip" if side < 0 else "RightHindHip"), ("LeftHindKnee" if side < 0 else "RightHindKnee"), back_at + Vector3(side * rads[3] * 0.85, -0.18, 0), side, false, thick * 1.08, feet, knees)

	var giant := root
	root = Node3D.new(); root.name = "Embermaw"
	root.add_child(giant); giant.name = "Giant"; giant.scale = Vector3.ONE * 1.3
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": feet, "knees": knees, "leaves": []}, 1.0)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["boss_jaw"] = node.get_path_to(jaw); rig["boss_tail"] = node.get_path_to(tail)
	rig["phase_crown"] = node.get_path_to(crown)
	rig["boss_bells"] = []; rig["boss_cloth"] = []
	node.set_meta("rig_bindings", rig)
	node.set_meta("actor_properties", {"rest_scale": Vector3.ONE, "normal_glow": glow, "attack_glow": attack_glow, "hurt_glow": hurt_glow, &"body_scale": 1.0})
	return node


static func along_line(pts: Array, t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


## The drake's horns, spines and torn wings.
func _drake_extras(spine: Array, rads: Array, head: Node3D, head_at: Vector3, jaw: Node3D, jaw_at: Vector3) -> void:
	var hs := Sculpt.new(); var hh := hs.add_painter(horn); var hb := hs.add_painter(basalt)
	var hl := Sculpt.new(); var hlp := hl.add_painter(molten)
	var hl_seams: Array = []
	for side: float in [-1.0, 1.0]:
		# No horns: a jagged crest of cooled-lava plates runs back along each side of the skull,
		# split by glowing seams, like the crust breaking on a lava flow.
		for k in range(5):
			var at := head_at + Vector3(0.13 * side, 0.2 - k * 0.01, -0.3 + k * 0.11)
			beam(hs, hb, at, Vector3(0.45 * side, 1.0, 0.55 + k * 0.1), 0.12 + 0.05 * sin(PI * k / 4.0), 0.07, 0.04, k * 0.9 + side)
			hl_seams.append(at)
		# Heavy brow ridge with short spikes.
		hs.tube([head_at + Vector3(0.07 * side, 0.2, -0.42), head_at + Vector3(0.17 * side, 0.2, -0.28), head_at + Vector3(0.2 * side, 0.17, -0.12)], [0.04, 0.055, 0.04], hb, {"sides": 7, "per": 2})
		for k in range(3): hs.crystal(head_at + Vector3((0.1 + k * 0.04) * side, 0.24, -0.36 + k * 0.1), Vector3(0.5 * side, 1, 0.5), 0.08, 0.02, hh, 4)
		# Cheek spines fanning back.
		for k in range(3): hs.crystal(head_at + Vector3(0.28 * side, -0.02 - k * 0.05, -0.1 + k * 0.04), Vector3(side, -0.2 - k * 0.2, 0.7), 0.18 - k * 0.03, 0.03, hh, 4)
	# A mane of basalt spikes down the neck.
	for k in range(6):
		var at := along_line(spine, 0.02 + k * 0.05)
		var nk := head_at.lerp(spine[1], 0.15 + k * 0.15)
		hs.crystal(nk + Vector3(0, 0.26 - k * 0.01, 0), Vector3(0, 1, 0.9), 0.3 - k * 0.02, 0.05, hh, 5, k)
	for at: Vector3 in hl_seams: hl.blob(at + Vector3(0, 0.005, 0), Vector3(0.05, 0.015, 0.06), hlp, {"lat": 3, "lon": 6})
	# Molten rock dripping from the corners of the mouth.
	for side: float in [-1.0, 1.0]:
		var c0 := head_at + Vector3(0.12 * side, -0.1, -0.35)
		hl.tube([c0, c0 + Vector3(0.01 * side, -0.1, 0.0), c0 + Vector3(0.0, -0.2, 0.01)], [0.025, 0.018, 0.026], hlp, {"sides": 5, "per": 2})
	part(head, "Crest", hs)
	part(head, "CrestLava", hl, lava_mat)
	var cs := Sculpt.new(); var ch := cs.add_painter(horn)
	for side: float in [-1.0, 1.0]:
		for k in range(3): cs.crystal(jaw_at + Vector3((0.15 - k * 0.04) * side, -0.12, -0.15 - k * 0.15), Vector3(0.3 * side, -1, 0.4), 0.12, 0.03, ch, 4)
	part(jaw, "ChinSpikes", cs).rotation.x = -0.3
	# Two small wings folded tight against the shoulders, as a bat folds them: the arm bent back
	# along the flank, the long fingers lying alongside it, the scorched skin gathered between
	# them in pleats; ragged at the edge, too torn to fly.
	var ws := Sculpt.new(); var wb := ws.add_painter(basalt); var wc := ws.add_painter(horn)
	var skin := ws.add_painter(func (p: Vector3, _n, v: float, _w) -> Color:
		var c := Color("#1c100c").lerp(Color("#5a2414"), clampf(Sculpt.noise(p * 9.0) * 0.6 + 0.35, 0.0, 1.0))
		return c.lerp(Color("#ff6a14"), smoothstep(0.9, 1.0, v) * 0.3))
	var shoulder := along_line(spine, 0.2)
	for side: float in [-1.0, 1.0]:
		var r0 := shoulder + Vector3(rads[1] * 0.6 * side, rads[1] * 0.55, 0.05)
		var el := r0 + Vector3(0.12 * side, 0.32, 0.3)
		var wr := el + Vector3(0.04 * side, -0.12, 0.45)
		ws.tube([r0, r0.lerp(el, 0.5) + Vector3(0.02 * side, 0.03, 0), el], [0.08, 0.07, 0.06], wb, {"sides": 9, "per": 2})
		ws.blob(el, Vector3.ONE * 0.07, wb, {"lat": 5, "lon": 7})
		ws.crystal(el, Vector3(0.2 * side, 1.0, -0.5), 0.16, 0.035, wc, 4)
		ws.tube([el, wr], [0.06, 0.045], wb, {"sides": 8, "per": 2})
		ws.blob(wr, Vector3.ONE * 0.05, wb, {"lat": 5, "lon": 7})
		# Fingers lying back and down along the flank, fanned only a little.
		var tips: Array = []
		for k in range(3):
			var t := wr + Vector3((0.1 + k * 0.03) * side, -0.12 - k * 0.14, 0.5 - k * 0.06)
			tips.append(t)
			ws.tube([wr, wr.lerp(t, 0.5) + Vector3(0.03 * side, 0.03, 0), t], [0.035, 0.026, 0.006], wb, {"sides": 7, "per": 3, "cap1": false})
			ws.crystal(t, (t - wr).normalized(), 0.07, 0.012, wc, 4)
		# The skin: a pleated sheet from the arm down across the fingers to the flank.
		var lines: Array = [[r0, el, wr], [r0 + Vector3(0.02 * side, -0.1, 0.1), el + Vector3(0.05 * side, -0.2, 0.05), tips[0]], [r0 + Vector3(0.03 * side, -0.18, 0.2), el + Vector3(0.07 * side, -0.36, 0.1), tips[1]], [r0 + Vector3(0.02 * side, -0.25, 0.3), el + Vector3(0.06 * side, -0.48, 0.15), tips[2]]]
		for li in range(lines.size() - 1):
			var la: Array = lines[li]; var lb: Array = lines[li + 1]
			var rows := 5; var cols := 3
			for layer in [0, 1]:
				var base := ws._v.size()
				for ri in range(rows + 1):
					for ci in range(cols + 1):
						var u := ci / float(cols); var t := ri / float(rows)
						var q := along_line(la, t).lerp(along_line(lb, t), u)
						# Pleated: the skin bows out between each pair of fingers.
						q += Vector3(0.05 * side * sin(PI * u), 0, 0) + Vector3(0.003 * side if layer == 0 else -0.003 * side, 0, 0)
						ws._v.append(q); ws._along.append(t); ws._ridge.append(u); ws._painter.append(skin)
				for ri in range(rows):
					for ci in range(cols):
						if ri == rows - 1 and (ci + li) % 3 == 1: continue
						var k := base + ri * (cols + 1) + ci
						if layer == 0: ws._i.append_array(PackedInt32Array([k, k + cols + 1, k + 1, k + 1, k + cols + 1, k + cols + 2]))
						else: ws._i.append_array(PackedInt32Array([k, k + 1, k + cols + 1, k + 1, k + cols + 2, k + cols + 1]))
	var wmat := material.duplicate() as StandardMaterial3D
	wmat.cull_mode = BaseMaterial3D.CULL_DISABLED; wmat.albedo_texture = null; wmat.vertex_color_is_srgb = true
	part(root, "TornWings", ws, wmat)


# ------------------------------------------------------------------ the magma spinosaurus

## Embermaw as a spinosaur of the deep fire, built on Spinosaurus aegyptiacus: a long, narrow,
## crocodile-like snout with conical interlocking teeth and a rosette of longer teeth at the
## tip, nostrils set far back up the snout, a small crest between the eyes; a long S-curved
## neck; a great sail along the back held up by elongated neural spines; strong forelimbs with
## a hooked thumb claw; short hind legs with broad flat feet; and a long tail flattened side to
## side into a paddle, finned with tall spines. Here it is made of the volcano: a hide of
## cooled-lava crust split by glowing seams, the sail's spines columns of basalt with molten
## rock showing through the cracked crust between them, magma dripping from its jaws, and a
## furnace burning in its throat.
## Scorched bone: pale where it stands proud, charred black in the hollows and toward the
## back of the skull where the fire is fiercest.
static func scorched_bone(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#3a2e26").lerp(Color("#d8ccb0"), clampf(n.y * 0.4 + 0.3 + Sculpt.fbm(p * 9.0) * 0.5, 0.0, 1.0))
	# Charred black in broad patches and in the creases.
	c = c.lerp(Color("#0e0908"), smoothstep(-0.12, 0.25, Sculpt.noise(p * 5.0 + Vector3(3, 0, 0))) * 0.9)
	# Hairline cracks glowing with the fire inside.
	c = c.lerp(Color("#ff6a14"), maxf(smoothstep(0.04, 0.0, absf(Sculpt.noise(p * 11.0))), smoothstep(0.03, 0.0, absf(Sculpt.noise(p * 23.0 + Vector3(7, 0, 0))))) * 0.95)
	return c.lerp(Color("#ff7a20"), smoothstep(-0.2, -0.8, n.y) * 0.3)


func fire_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## One tongue of flame from `base`, rising along `dir` and curling with the wind `sweep`:
## white-yellow at the root, orange, then red and fading at the tip.
func flame(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, sweep: Vector3, seed: float) -> void:
	var pts: Array = []; var rr: Array = []
	var d := dir.normalized()
	for k in range(6):
		var t := k / 5.0
		pts.append(base + d * length * t + sweep * length * t * t + Vector3(sin(seed + t * 5.0), 0, cos(seed * 1.3 + t * 4.0)) * width * 0.5 * t)
		rr.append(width * (1.0 - t) * (0.6 + 0.4 * sin(PI * clampf(t * 1.6 + 0.2, 0.0, 1.0))) + 0.003)
	s.tube(pts, rr, painter, {"sides": 5, "per": 1, "cap1": false, "cap_rings": 1})


static func fire_paint(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#ffd060").lerp(Color("#ff7010"), smoothstep(0.0, 0.35, v)).lerp(Color("#c0200a"), smoothstep(0.4, 0.9, v))
	return Color(c.r, c.g, c.b, (1.0 - smoothstep(0.45, 1.0, v)) * 0.55)


func _spino() -> Node3D:
	var lava := Sculpt.new(); var lp := lava.add_painter(molten)
	var bs := Sculpt.new(); var sp := bs.add_painter(crust); var hp := bs.add_painter(horn)
	var col := bs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return basalt(p, n, v, w).lerp(Color("#ff5a10"), smoothstep(0.25, 0.0, v) * 0.6))
	# ---- body: a deep chest, narrow from side to side, the back rising to the shoulders
	var spine := [Vector3(0, 1.22, 0.78), Vector3(0, 1.3, 0.38), Vector3(0, 1.38, -0.05), Vector3(0, 1.46, -0.45)]
	var rads := [0.32, 0.43, 0.48, 0.4]
	bs.tube(spine, rads, sp, {"sides": 22, "per": 5, "flat": 0.72, "side": Vector3.RIGHT, "lump": 0.05, "cap0": false, "cap1": false})
	bs.blob(Vector3(0, 1.2, -0.12), Vector3(0.33, 0.37, 0.48), sp, {"lat": 10, "lon": 14, "lump": 0.05})
	# ---- neck: a long S-curve rising forward to the head
	var neck := [Vector3(0, 1.48, -0.5), Vector3(0, 1.72, -0.78), Vector3(0, 1.97, -0.92), Vector3(0, 2.08, -1.06)]
	bs.tube(neck, [0.34, 0.25, 0.19, 0.16], sp, {"sides": 18, "per": 4, "flat": 0.85, "side": Vector3.RIGHT, "lump": 0.05, "cap0": false, "bands": 8, "band": 0.04})
	for k in range(8):
		var at := along_line(neck, 0.08 + k * 0.12)
		bs.crystal(at + Vector3(0, 0.15 - k * 0.012, 0.04), Vector3(0, 1, 0.6), 0.1, 0.03, hp, 4, k)
	# ---- the sail: basalt columns rising from the spine, highest over the middle of the back
	# in a gentle double arch; cracked crust plates between them with lava glowing through.
	var sail_base: Array = []; var sail_top: Array = []
	var n := 17
	var sail_line := [Vector3(0, 1.62, -0.62), Vector3(0, 1.72, -0.3), Vector3(0, 1.72, 0.1), Vector3(0, 1.64, 0.5), Vector3(0, 1.5, 0.9), Vector3(0, 1.32, 1.25)]
	for k in range(n):
		var t := k / float(n - 1)
		var base := along_line(sail_line, t)
		# The classic spinosaur sail: low at each end, rising to a broad crest with a shallow dip
		# in the middle.
		var hh := 0.12 + 0.78 * pow(sin(PI * t), 0.7) * (1.0 - 0.14 * pow(sin(PI * t * 2.0), 2.0))
		var top := base + Vector3(0, hh, 0.18 * (t - 0.5))
		var h := hh
		sail_base.append(base); sail_top.append(top)
		beam(bs, col, base - Vector3(0, 0.08, 0), (top - base).normalized(), h + 0.12, 0.055, 0.045, k * 0.6)
		bs.crystal(top, (top - base).normalized() + Vector3(0, 0, 0.3), 0.08 + 0.06 * sin(PI * t), 0.03, hp, 4, k)
	# The molten membrane, set inside the columns.
	var mem := lava.add_painter(func (p: Vector3, _n, v: float, _w) -> Color: return Color("#ff3a06").lerp(Color("#ffc040"), clampf(Sculpt.noise(p * 8.0) * 0.5 + 0.5 - v * 0.5, 0.0, 1.0)))
	for layer in [0, 1]:
		var base_i := lava._v.size()
		for k in range(n):
			for j in range(5):
				var t := j / 4.0
				var q: Vector3 = (sail_base[k] as Vector3).lerp(sail_top[k], t * 0.94) + Vector3(0.006 if layer == 0 else -0.006, 0, 0)
				lava._v.append(q); lava._along.append(t); lava._ridge.append(k / float(n)); lava._painter.append(mem)
		for k in range(n - 1):
			for j in range(4):
				var a := base_i + k * 5 + j; var b := a + 5
				if layer == 0: lava._i.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
				else: lava._i.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	# Crust plates over both faces of the sail, gaps between them showing the lava.
	var rng := RandomNumberGenerator.new(); rng.seed = 404
	for k in range(n - 1):
		for j in range(6):
			var t := (j + 0.5) / 6.0
			var c: Vector3 = (sail_base[k] as Vector3).lerp(sail_top[k], t * 0.9).lerp((sail_base[k + 1] as Vector3).lerp(sail_top[k + 1], t * 0.9), 0.5)
			if (j + k) % 4 == 3: continue
			for side: float in [-1.0, 1.0]:
				var sz := 0.065 * (1.0 - t * 0.3) * rng.randf_range(0.85, 1.15)
				bs.rock(c + Vector3(side * 0.025, rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02)), Vector3(sz * 0.35, sz * 1.1, sz * 0.95), sp, {"seed": k * 9 + j * 3 + int(side), "lat": 3, "lon": 5})
	# Glowing seams down the flanks and under the belly.
	for side: float in [-1.0, 1.0]:
		for k in range(5):
			var at := along_line(spine, 0.12 + k * 0.18)
			vein(lava, lp, at + Vector3(side * 0.33, 0.16, -0.08), at + Vector3(side * 0.29, -0.3, 0.1), Vector3(side, 0, 0), 0.02, k + side, 0.022)
	# Magma dripping from the belly.
	for k in range(4):
		var at := along_line(spine, 0.25 + k * 0.18) + Vector3(0.05 * (k % 2 * 2 - 1), -0.43, 0)
		lava.tube([at, at + Vector3(0, -0.1 - 0.06 * (k % 2), 0), at + Vector3(0, -0.18 - 0.08 * (k % 2), 0)], [0.025, 0.018, 0.028], lp, {"sides": 5, "per": 2})
	# Fire burning along the crest of the sail and licking up from the seams on the back.
	var bfire := Sculpt.new(); var bfp := bfire.add_painter(fire_paint)
	for k in range(n):
		var top: Vector3 = sail_top[k]
		flame(bfire, bfp, top, Vector3(0, 1, 0.25), 0.2 + 0.16 * sin(PI * k / float(n - 1)), 0.045, Vector3(0, 0.2, 0.8), k * 1.1)
	for k in range(10):
		var at := along_line(spine, 0.05 + k * 0.1) + Vector3(0.16 * (k % 2 * 2 - 1), 0.32, 0)
		flame(bfire, bfp, at, Vector3(0.3 * (k % 2 * 2 - 1), 1, 0.3), 0.18, 0.035, Vector3(0, 0.2, 0.8), k * 0.9)
	var bf := part(root, "BodyFire", bfire, fire_material())
	bf.material_override = fire_material()
	# More lava running down the flanks and dripping from the belly.
	for side: float in [-1.0, 1.0]:
		for k in range(4):
			var at := along_line(spine, 0.2 + k * 0.2) + Vector3(side * 0.3, -0.1, 0)
			lava.tube([at, at + Vector3(side * 0.03, -0.14, 0.02), at + Vector3(side * 0.02, -0.3, 0.03)], [0.022, 0.018, 0.026], lp, {"sides": 5, "per": 2})
	part(root, "Body", bs)
	part(root, "BodyLava", lava, lava_mat)

	# ---- the awakened furnace: lava bursting from the tips of the sail, shown when enraged
	var cr := Sculpt.new(); var crp := cr.add_painter(molten)
	for k in range(n):
		var top: Vector3 = sail_top[k]
		cr.crystal(top + Vector3(0, 0.05, 0), Vector3(0, 1, 0.2), 0.22 + 0.1 * sin(PI * k / float(n - 1)), 0.05, crp, 5, k)
	var crown := part(root, "AwakenedDorsalFurnace", cr, crown_mat); crown.material_override = crown_mat
	crown.visible = false

	# ---- the head
	var head_at: Vector3 = neck[3]
	var head := joint(root, "FurnaceSkull", head_at)
	var hs := Sculpt.new(); var hb := hs.add_painter(scorched_bone); var hh := hs.add_painter(horn); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#050303"))
	var hl := Sculpt.new(); var hlp := hl.add_painter(molten)
	var fire := fire_material()
	var fs_head := Sculpt.new(); var hfp := fs_head.add_painter(fire_paint)
	var tip := head_at + Vector3(0, -0.14, -0.95)
	# The skull, deep at the back, and the long narrow snout, flared a little at the tip.
	hs.blob(head_at + Vector3(0, 0.03, -0.12), Vector3(0.13, 0.15, 0.2), hb, {"lat": 9, "lon": 12, "lump": 0.04})
	hs.tube([head_at + Vector3(0, 0.05, -0.08), head_at + Vector3(0, 0.03, -0.3), head_at + Vector3(0, -0.03, -0.55), tip + Vector3(0, 0.02, 0.08), tip], [0.15, 0.105, 0.075, 0.08, 0.065], hb, {"sides": 14, "per": 3, "flat": 0.8, "side": Vector3.RIGHT, "lump": 0.03, "cap_len": 0.5})
	# The crest between the eyes and a ridge of small spines down the snout.
	hs.tube([head_at + Vector3(0, 0.17, -0.06), head_at + Vector3(0, 0.2, -0.2), head_at + Vector3(0, 0.12, -0.38)], [0.03, 0.05, 0.02], hb, {"sides": 8, "per": 2, "flat": 0.4, "side": Vector3.RIGHT})
	for k in range(6): hs.crystal(head_at + Vector3(0, 0.1 - k * 0.025, -0.4 - k * 0.07), Vector3(0, 1, 0.4), 0.05, 0.015, hh, 4, k)
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		# The bare skull's openings: a great round orbit, the antorbital opening in front of it
		# and the nostril far back up the snout, all dark; the cheekbone (jugal) below the orbit
		# and a heavy brow above.
		hs.tube([head_at + Vector3(0.05 * side, 0.16, -0.22), head_at + Vector3(0.12 * side, 0.15, -0.1), head_at + Vector3(0.14 * side, 0.1, 0.03)], [0.025, 0.035, 0.025], hb, {"sides": 7, "per": 2})
		hs.blob(head_at + Vector3(0.11 * side, 0.08, -0.11), Vector3(0.035, 0.065, 0.07), hd, {"lat": 6, "lon": 8})
		# The temporal opening behind the orbit.
		hs.blob(head_at + Vector3(0.12 * side, 0.06, 0.03), Vector3(0.03, 0.045, 0.04), hd, {"lat": 5, "lon": 7})
		hs.tube([head_at + Vector3(0.12 * side, 0.01, 0.04), head_at + Vector3(0.13 * side, 0.0, -0.12), head_at + Vector3(0.1 * side, -0.02, -0.28)], [0.025, 0.028, 0.02], hb, {"sides": 7, "per": 2})
		hs.blob(head_at + Vector3(0.09 * side, 0.03, -0.27), Vector3(0.028, 0.035, 0.07), hd, {"lat": 5, "lon": 8})
		hs.blob(head_at + Vector3(0.04 * side, 0.075, -0.42), Vector3(0.014, 0.012, 0.045), hd, {"lat": 4, "lon": 6})
		# Ridged nasal bones along the top of the snout, and a jutting brow knob over the orbit.
		hs.tube([head_at + Vector3(0.03 * side, 0.1, -0.2), head_at + Vector3(0.035 * side, 0.08, -0.5), head_at + Vector3(0.03 * side, 0.03, -0.8)], [0.016, 0.014, 0.01], hb, {"sides": 6, "per": 3})
		hs.crystal(head_at + Vector3(0.1 * side, 0.17, -0.12), Vector3(0.4 * side, 1, 0.5), 0.09, 0.03, hb, 5)
		# Cheek spikes jutting from the jugal, sweeping back.
		for k in range(3): hs.crystal(head_at + Vector3(0.14 * side, -0.01 - k * 0.025, -0.02 + k * 0.05), Vector3(side, -0.15 - k * 0.15, 0.9), 0.12 - k * 0.02, 0.022, hb, 4)
		eyes.append(head_at + Vector3(0.14 * side, 0.08, -0.115))
		# Flames pouring out of each eye socket, swept back.
		for k in range(5): flame(fs_head, hfp, head_at + Vector3(0.13 * side, 0.1, -0.13 + k * 0.025), Vector3(0.4 * side, 1, 0.5), 0.26 + 0.06 * k, 0.035, Vector3(0, 0.3, 1.3), k + side)
	# The skull wreathed in fire: tongues of flame rising off the crown, the crest and the back
	# of the skull, streaming back over the neck.
	for k in range(30):
		var t := k / 29.0
		var at := (head_at + Vector3(0, 0.1, -0.72)).lerp(head_at + Vector3(0, 0.14, 0.12), t) + Vector3(0.08 * sin(k * 2.4), 0.02 * sin(k * 1.7), 0)
		flame(fs_head, hfp, at, Vector3(0.3 * sin(k * 2.4), 1, 0.3), 0.3 + 0.45 * sin(PI * clampf(t * 1.2, 0.0, 1.0)) + 0.08 * (k % 3), 0.045 + 0.025 * sin(PI * t), Vector3(0, 0.25, 1.5), k * 0.7)
	# A great plume of fire streaming back off the skull like a mane.
	for k in range(8):
		var at := head_at + Vector3(0.05 * sin(k * 1.9), 0.2, -0.05 + k * 0.03)
		flame(fs_head, hfp, at, Vector3(0.2 * sin(k * 1.9), 1, 0.7), 0.75 + 0.15 * (k % 3), 0.07, Vector3(0, 0.1, 1.2), k * 1.7)
	# Fire licking from the corners of the mouth, the nostrils and along the jaws.
	for side: float in [-1.0, 1.0]:
		for k in range(3): flame(fs_head, hfp, head_at + Vector3(0.1 * side, -0.07, -0.05 - k * 0.04), Vector3(side * 0.6, 0.7, 0.6), 0.22, 0.04, Vector3(0, 0.3, 1.0), k + side * 3.0)
		flame(fs_head, hfp, head_at + Vector3(0.04 * side, 0.09, -0.42), Vector3(side * 0.3, 1, 0.4), 0.18, 0.025, Vector3(0, 0.3, 1.0), side)
		for k in range(5): flame(fs_head, hfp, head_at + Vector3(0.075 * side, -0.02, -0.25 - k * 0.12), Vector3(side * 0.7, 0.6, 0.4), 0.12, 0.022, Vector3(0, 0.3, 0.8), k * 2.0 + side)
	for side: float in [-1.0, 1.0]:
		for k in range(4): flame(fs_head, hfp, head_at + Vector3(0.13 * side, 0.06 - k * 0.03, 0.0 + k * 0.03), Vector3(side, 0.6, 0.5), 0.2, 0.04, Vector3(0, 0.4, 1.0), k * 1.3 + side)
	# Upper teeth: conical, set along the jaw edge, the longest in the rosette at the tip.
	var tl := Sculpt.new(); var tlp := tl.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#2a1c18").lerp(Color("#f0d8b0"), v).lerp(Color("#ffb040"), smoothstep(0.85, 1.0, v) * 0.5))
	for side: float in [-1.0, 1.0]:
		for k in range(10):
			var t := k / 9.0
			var at := (head_at + Vector3(0, -0.05, -0.18)).lerp(tip + Vector3(0, -0.04, 0.02), t) + Vector3(side * lerpf(0.075, 0.055, t), 0, 0)
			var ln := 0.045 + (0.05 if k >= 8 else 0.0) + 0.012 * (k % 2)
			tl.crystal(at, Vector3(side * 0.15, -1, -0.12 if k >= 8 else 0.05), ln, 0.012, tlp, 4)
	part(head, "Teeth", tl)
	# Magma drooling from the upper jaw.
	for k in range(3):
		var at := (head_at + Vector3(0, -0.06, -0.3)).lerp(tip, 0.25 + k * 0.25) + Vector3(0.06 * (k % 2 * 2 - 1), 0, 0)
		hl.tube([at, at + Vector3(0, -0.06, 0), at + Vector3(0, -0.1 - 0.03 * k, 0.01)], [0.012, 0.008, 0.014], hlp, {"sides": 5, "per": 2})
	part(head, "Skull", hs)
	part(head, "SkullLava", hl, lava_mat)
	part(head, "SkullFire", fs_head, fire).material_override = fire
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for e: Vector3 in eyes:
		var eb := Basis(Vector3.UP, -0.3 * signf(e.x)) * Basis(Vector3.FORWARD, 0.25 * signf(e.x))
		es.blob(e, Vector3(0.03, 0.04, 0.045), ew, {"lat": 6, "lon": 8, "basis": eb})
	part(head, "Eyes", es, glow).material_override = glow
	# The furnace in the throat: the boss's glowing core.
	var ts := Sculpt.new(); var tw := ts.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	ts.blob(head_at + Vector3(0, -0.07, -0.25), Vector3(0.07, 0.04, 0.2), tw, {"lat": 5, "lon": 8})
	var core := part(head, "FurnaceThroat", ts, glow); core.material_override = glow
	# The lower jaw, hinged at the back of the skull, gaping.
	var jaw_at := head_at + Vector3(0, -0.06, 0.02)
	var jaw := joint(head, "HingedBasaltJaw", jaw_at)
	var js := Sculpt.new(); var jp := js.add_painter(scorched_bone); var jt := js.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#2a1c18").lerp(Color("#f0d8b0"), v))
	var jl := Sculpt.new(); var jlp := jl.add_painter(molten)
	var jtip := tip + Vector3(0, -0.07, 0.03)
	js.tube([jaw_at + Vector3(0, -0.04, 0.0), jaw_at.lerp(jtip, 0.4) + Vector3(0, -0.06, 0), jtip + Vector3(0, -0.01, 0.06), jtip], [0.1, 0.07, 0.055, 0.045], jp, {"sides": 12, "per": 3, "flat": 0.85, "side": Vector3.RIGHT, "lump": 0.03, "cap_len": 0.5})
	jl.blob(jaw_at.lerp(jtip, 0.45) + Vector3(0, 0.01, 0), Vector3(0.045, 0.012, 0.36), jlp, {"lat": 4, "lon": 8})
	for side: float in [-1.0, 1.0]:
		for k in range(9):
			var t := k / 8.0
			var at := (jaw_at + Vector3(0, -0.01, -0.2)).lerp(jtip + Vector3(0, 0.03, 0.02), t) + Vector3(side * lerpf(0.06, 0.045, t), 0, 0)
			js.crystal(at, Vector3(side * 0.15, 1, 0.05), 0.04 + (0.045 if k >= 7 else 0.0), 0.011, jt, 4)
		# A dewlap of crust plates along the throat.
		for k in range(3): plate(js, jp, jl, jlp, jaw_at.lerp(jtip, 0.1 + k * 0.15) + Vector3(0.06 * side, -0.09, 0), Vector3(side, -0.6, 0), 0.05, 90 + k, 0.0)
	# Magma pouring over the lip of the lower jaw.
	jl.tube([jtip + Vector3(0, 0.02, 0.05), jtip + Vector3(0, -0.07, 0.04), jtip + Vector3(0, -0.14, 0.05)], [0.014, 0.01, 0.018], jlp, {"sides": 5, "per": 2})
	part(jaw, "Jaw", js).rotation.x = -0.32
	part(jaw, "MoltenMouthFloor", jl, lava_mat).rotation.x = -0.32

	# ---- the tail: long, flattened side to side into a paddle, finned with tall spines
	var tail_at: Vector3 = spine[0]
	var tail := joint(root, "ArticulatedFurnaceTail", tail_at)
	var tls := Sculpt.new(); var tlb := tls.add_painter(crust); var tcol := tls.add_painter(func (p: Vector3, nn: Vector3, v: float, w: float) -> Color: return basalt(p, nn, v, w).lerp(Color("#ff5a10"), smoothstep(0.25, 0.0, v) * 0.6))
	var tlv := Sculpt.new(); var tlvp := tlv.add_painter(molten)
	var tpts: Array = []; var trr: Array = []
	for k in range(9):
		var t := k / 8.0
		tpts.append(tail_at + Vector3(0.22 * sin(t * 2.6), -0.75 * t * t - 0.05 * t, 2.1 * t)); trr.append(lerpf(0.27, 0.06, pow(t, 0.8)))
	tls.tube(tpts, trr, tlb, {"sides": 16, "per": 3, "lump": 0.04, "flat": 0.6, "side": Vector3.RIGHT})
	for k in range(1, 9):
		var at: Vector3 = tpts[k]; var r: float = trr[k]
		var t := k / 8.0
		var h := 0.12 + 0.3 * sin(PI * clampf(t * 1.1, 0.0, 1.0))
		beam(tls, tcol, at + Vector3(0, r * 0.5, 0), Vector3(0, 1, 0.5).normalized(), h, 0.05, 0.035, k * 0.7)
		if t > 0.3: beam(tls, tcol, at - Vector3(0, r * 0.5, 0), Vector3(0, -1, 0.4).normalized(), h * 0.55, 0.045, 0.03, k * 0.9)
		vein(tlv, tlvp, at + Vector3(0.12 * r, r * 0.45, -0.06), at + Vector3(0.1 * r, -r * 0.45, 0.06), Vector3(1, 0, 0), 0.03, k, 0.02)
		vein(tlv, tlvp, at + Vector3(-0.12 * r, r * 0.45, -0.06), at + Vector3(-0.1 * r, -r * 0.45, 0.06), Vector3(-1, 0, 0), 0.03, k + 2.0, 0.02)
	var tfire := Sculpt.new(); var tfp := tfire.add_painter(fire_paint)
	for k in range(1, 9, 2):
		var at: Vector3 = tpts[k]; var r: float = trr[k]
		var hgt := 0.12 + 0.3 * sin(PI * clampf(k / 8.0 * 1.1, 0.0, 1.0))
		flame(tfire, tfp, at + Vector3(0, r * 0.5 + hgt * 0.9, hgt * 0.4), Vector3(0, 1, 0.4), 0.16, 0.035, Vector3(0, 0.2, 0.8), k)
	part(tail, "TailFire", tfire, fire_material()).material_override = fire_material()
	part(tail, "Tail", tls)
	part(tail, "TailLava", tlv, lava_mat)

	# ---- hind legs: short and massive, broad flat feet with three forward toes
	var feet: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var h := Vector3(0.26 * side, 1.16, 0.4)
		var hip := joint(root, ("LeftHindHip" if side < 0 else "RightHindHip"), h)
		var kn := h + Vector3(0.05 * side, -0.46, -0.24)
		var an := kn + Vector3(0.0, -0.36, 0.26)
		var ft := Vector3(an.x, 0.0, an.z - 0.05)
		var us := Sculpt.new(); var up := us.add_painter(crust); var lv := Sculpt.new(); var lvp := lv.add_painter(molten)
		us.blob(h + Vector3(0, -0.06, -0.02), Vector3(0.24, 0.33, 0.32), up, {"lat": 9, "lon": 12, "lump": 0.05})
		us.tube([h, h.lerp(kn, 0.5) + Vector3(0, 0, -0.04), kn], [0.22, 0.19, 0.13], up, {"sides": 14, "per": 2, "lump": 0.05})
		vein(lv, lvp, h + Vector3(0.18 * side, 0.1, -0.05), kn + Vector3(0.08 * side, 0.05, 0.0), Vector3(side, 0, 0), 0.05, side, 0.03)
		part(hip, "Thigh", us)
		part(hip, "ThighLava", lv, lava_mat)
		var knee := joint(hip, ("LeftHindKnee" if side < 0 else "RightHindKnee"), kn)
		var ls := Sculpt.new(); var lpp := ls.add_painter(crust); var cl := ls.add_painter(horn); var lv2 := Sculpt.new(); var lp2 := lv2.add_painter(molten)
		ls.blob(kn, Vector3.ONE * 0.13, lpp, {"lat": 6, "lon": 8})
		ls.tube([kn, kn.lerp(an, 0.5), an], [0.13, 0.11, 0.085], lpp, {"sides": 12, "per": 2, "lump": 0.05})
		ls.tube([an, ft + Vector3(0, 0.07, 0)], [0.085, 0.08], lpp, {"sides": 12, "per": 2})
		vein(lv2, lp2, kn + Vector3(0, -0.02, -0.09), an + Vector3(0, 0.02, -0.07), Vector3(0, 0, -1), 0.03, side + 1.0, 0.02)
		for k in range(3):
			var dir := Vector3((k - 1) * 0.42, 0, -1).normalized()
			var t0 := ft + Vector3(0, 0.05, 0)
			var t1 := t0 + dir * 0.2 + Vector3(0, -0.02, 0)
			ls.tube([t0, t0.lerp(t1, 0.5) + Vector3(0, 0.01, 0), t1], [0.05, 0.045, 0.038], lpp, {"sides": 8, "per": 2})
			ls.tube([t1, t1 + dir * 0.06 + Vector3(0, -0.01, 0), t1 + dir * 0.09 + Vector3(0, -0.05, 0)], [0.03, 0.02, 0.003], cl, {"sides": 6, "per": 2, "cap1": false})
		ls.tube([ft + Vector3(0, 0.08, 0.06), ft + Vector3(0, 0.03, 0.14)], [0.03, 0.004], cl, {"sides": 5, "per": 2, "cap1": false})
		part(knee, "Shin", ls)
		part(knee, "ShinLava", lv2, lava_mat)
		feet.append(hip); knees.append(knee)

	# ---- forelimbs: strong arms held forward, a great hooked thumb claw and three fingers
	var arms: Array = []; var forearms: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.28 * side, 1.28, -0.5)
		var arm := joint(root, ("LeftShovelShoulder" if side < 0 else "RightShovelShoulder"), sh)
		var el := sh + Vector3(0.07 * side, -0.26, 0.02)
		var wr := el + Vector3(-0.02 * side, -0.12, -0.25)
		var us := Sculpt.new(); var up := us.add_painter(crust)
		us.blob(sh, Vector3(0.11, 0.12, 0.12), up, {"lat": 7, "lon": 9, "lump": 0.05})
		us.tube([sh, sh.lerp(el, 0.5), el], [0.12, 0.1, 0.08], up, {"sides": 12, "per": 2, "lump": 0.05})
		part(arm, "UpperArm", us)
		var fore := joint(arm, ("LeftShovelElbow" if side < 0 else "RightShovelElbow"), el)
		var fs := Sculpt.new(); var fp := fs.add_painter(crust); var fc := fs.add_painter(horn); var flv := Sculpt.new(); var flp := flv.add_painter(molten)
		fs.blob(el, Vector3.ONE * 0.07, fp, {"lat": 6, "lon": 8})
		fs.tube([el, el.lerp(wr, 0.5), wr], [0.08, 0.07, 0.06], fp, {"sides": 12, "per": 2, "lump": 0.05})
		vein(flv, flp, el + Vector3(0, -0.02, -0.06), wr + Vector3(0, 0.02, -0.04), Vector3(0, -0.3, -1).normalized(), 0.02, side, 0.015)
		fs.blob(wr + Vector3(0, -0.03, -0.04), Vector3(0.06, 0.05, 0.07), fp, {"lat": 6, "lon": 8})
		# The thumb: a great hooked claw on the inner side.
		var th0 := wr + Vector3(-0.04 * side, -0.02, -0.05)
		fs.tube([th0, th0 + Vector3(-0.03 * side, -0.02, -0.06), th0 + Vector3(-0.03 * side, -0.1, -0.12), th0 + Vector3(-0.02 * side, -0.17, -0.09)], [0.035, 0.03, 0.018, 0.003], fc, {"sides": 7, "per": 2, "cap1": false})
		for k in range(3):
			var f0 := wr + Vector3((0.0 + k * 0.03) * side, -0.05, -0.08)
			fs.tube([f0, f0 + Vector3(0.01 * side, -0.05, -0.05), f0 + Vector3(0.01 * side, -0.1, -0.06)], [0.022, 0.018, 0.014], fp, {"sides": 6, "per": 2})
			fs.tube([f0 + Vector3(0.01 * side, -0.1, -0.06), f0 + Vector3(0.01 * side, -0.14, -0.04)], [0.015, 0.002], fc, {"sides": 5, "per": 1, "cap1": false})
		part(fore, "Forearm", fs)
		part(fore, "ForearmLava", flv, lava_mat)
		arms.append(arm); forearms.append(fore)

	var giant := root
	root = Node3D.new(); root.name = "Embermaw"
	root.add_child(giant); giant.name = "Giant"; giant.scale = Vector3.ONE * 1.75
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": feet, "knees": knees, "leaves": []}, 1.0)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["boss_jaw"] = node.get_path_to(jaw); rig["boss_tail"] = node.get_path_to(tail)
	rig["phase_crown"] = node.get_path_to(crown)
	rig["boss_bells"] = []; rig["boss_cloth"] = []
	node.set_meta("rig_bindings", rig)
	node.set_meta("actor_properties", {"rest_scale": Vector3.ONE, "normal_glow": glow, "attack_glow": attack_glow, "hurt_glow": hurt_glow, &"body_scale": 1.0})
	return node
