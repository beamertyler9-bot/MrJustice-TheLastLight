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
	if not variant in ["monitor", "ankylos", "thornback", "drake"]: return null
	if variant == "drake": kinde = "monitor"; drake = true
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
	s.tube(pts, rr, p, {"sides": 5, "per": 1})

## A basalt plate (an osteoderm or a clinker): a low faceted rock lying on the surface at `at`
## facing `up`, with a seam of lava round its foot.
func plate(s: Sculpt, sp: int, lava: Sculpt, lp: int, at: Vector3, up: Vector3, size: float, seed: int, keel := 0.0) -> void:
	var u := up.normalized()
	var b := Basis(Quaternion(Vector3.UP, u))
	s.rock(at, Vector3(size, size * 0.45, size * 0.9), sp, {"seed": seed, "basis": b})
	if keel > 0.0: s.crystal(at + u * size * 0.3, u, keel, size * 0.35, sp, 4, seed * 0.7)
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
	var us := Sculpt.new(); var up := us.add_painter(basalt); var lv := Sculpt.new(); var lp := lv.add_painter(molten)
	us.blob(hip, Vector3(thick * 1.6, thick * 1.4, thick * 1.6), up, {"lat": 7, "lon": 10, "lump": 0.08})
	us.tube([hip, hip.lerp(kn, 0.5) + Vector3(0, 0.05, 0), kn], [thick * 1.3, thick * 1.2, thick], up, {"sides": 12, "per": 2, "lump": 0.08})
	plate(us, up, lv, lp, hip.lerp(kn, 0.4) + Vector3(0, thick * 1.1, 0), Vector3(0.3 * side, 1, 0), thick * 0.9, int(hip.x * 10.0 + hip.z * 7.0))
	part(h, "UpperLeg", us)
	part(h, "UpperLava", lv, lava_mat)
	var knee := joint(h, knee_name, kn)
	var ls := Sculpt.new(); var lpp := ls.add_painter(basalt); var cl := ls.add_painter(horn)
	var lv2 := Sculpt.new(); var lp2 := lv2.add_painter(molten)
	ls.blob(kn, Vector3.ONE * thick * 1.05, lpp, {"lat": 6, "lon": 8, "lump": 0.08})
	ls.tube([kn, kn.lerp(ft, 0.5) + Vector3(0.02 * side, 0, 0), ft + Vector3(0, thick * 0.6, 0)], [thick * 0.95, thick * 0.85, thick * 0.8], lpp, {"sides": 12, "per": 2, "lump": 0.08})
	vein(lv2, lp2, kn + Vector3(0, -0.02, -thick * 0.9), ft + Vector3(0.02 * side, thick * 0.8, -thick * 0.8), Vector3(0, 0, -1), 0.04, hip.x, 0.022)
	# A broad foot with five hooked claws.
	ls.blob(ft + Vector3(0, thick * 0.45, -thick * 0.2), Vector3(thick * 1.25, thick * 0.55, thick * 1.35), lpp, {"lat": 6, "lon": 9, "lump": 0.06})
	for c in range(5):
		var cd := Vector3((c - 2) * 0.32 + side * 0.15, 0.0, -1.0).normalized()
		var cb := ft + Vector3(0, thick * 0.35, -thick * 0.2) + cd * thick * 1.1
		ls.tube([cb, cb + cd * thick * 0.6 + Vector3(0, 0.01, 0), cb + cd * thick * 1.0 + Vector3(0, -thick * 0.35, 0)], [thick * 0.26, thick * 0.18, 0.003], cl, {"sides": 6, "per": 2, "cap1": false})
	part(knee, "LowerLeg", ls)
	part(knee, "LowerLava", lv2, lava_mat)
	list_h.append(h); list_k.append(knee)


# ------------------------------------------------------------------ the beast

func _beast() -> Node3D:
	var monitor := kinde == "monitor"; var ank := kinde == "ankylos"; var thorn := kinde == "thornback"
	var bs := Sculpt.new(); var sp := bs.add_painter(pahoehoe if monitor else basalt); var bp := bs.add_painter(ember_belly); var hp := bs.add_painter(horn)
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
	bs.tube(spine, rads, sp, {"sides": 22, "per": 4, "flat": 0.62 if not monitor else 0.75, "side": Vector3.UP, "lump": 0.05, "cap0": false})
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
		bs.tube([spine[1], spine[0], head_at + Vector3(0, -0.05, 0.12)], [rads[1] * 0.75, 0.36, 0.3], sp, {"sides": 18, "per": 3, "lump": 0.05, "bands": 8, "band": 0.05})
	var head := joint(root, "FurnaceSkull", head_at)
	var hs := Sculpt.new(); var hb := hs.add_painter(basalt); var hh := hs.add_painter(horn); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#060404"))
	var hl := Sculpt.new(); var hlp := hl.add_painter(molten)
	var snout: Vector3; var jaw_at: Vector3; var eyes: Array = []
	if monitor:
		# A long flat skull, the snout narrowing, nostrils near the tip, heavy brows.
		hs.tube([head_at, head_at + Vector3(0, 0.02, -0.25), head_at + Vector3(0, -0.02, -0.55), head_at + Vector3(0, -0.06, -0.78)], ([0.21, 0.2, 0.15, 0.09] if drake else [0.34, 0.32, 0.23, 0.13]), hb, {"sides": 16, "per": 3, "flat": 1.6 if drake else 1.45, "lump": 0.05, "cap0": false})
		snout = head_at + Vector3(0, -0.06, -0.8)
		for side: float in [-1.0, 1.0]:
			hs.tube([head_at + Vector3(0.08 * side, 0.15, -0.38), head_at + Vector3(0.17 * side, 0.14, -0.22), head_at + Vector3(0.2 * side, 0.1, -0.05)], [0.035, 0.045, 0.03], hb, {"sides": 6, "per": 2})
			eyes.append(head_at + (Vector3(0.2 * side, 0.1, -0.3) if drake else Vector3(0.18 * side, 0.08, -0.28)))
			hs.blob(snout + Vector3(0.05 * side, 0.06, 0.04), Vector3(0.025, 0.015, 0.03), hd, {"lat": 4, "lon": 6})
			for k in range(4): plate(hs, hb, hl, hlp, head_at + Vector3(0.1 * side, 0.15, -0.05 - k * 0.12), Vector3(0.3 * side, 1, 0), 0.05, 30 + k, 0.0)
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
		es.blob(e, Vector3(0.04, 0.025, 0.05), ew, {"lat": 4, "lon": 7})
		hs.blob(e + Vector3(signf(e.x) * 0.03, 0, 0), Vector3(0.008, 0.022, 0.025), hd, {"lat": 3, "lon": 5})
	part(head, "Skull", hs)
	part(head, "SkullLava", hl, lava_mat)
	part(head, "Eyes", es, glow).material_override = glow
	# The throat: the furnace glowing in the mouth (the boss's core).
	var ts := Sculpt.new(); var tw := ts.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	var throat_at := snout.lerp(jaw_at, 0.45) + Vector3(0, -0.02, 0)
	ts.blob(throat_at + Vector3(0, -0.04, 0), Vector3(0.16 if not monitor else 0.13, 0.08, 0.26 if monitor else 0.2), tw, {"lat": 5, "lon": 9})
	var core := part(head, "FurnaceThroat", ts, glow); core.material_override = glow
	# Upper teeth.
	var teeth_p := hs.add_painter(horn)
	var tl := Sculpt.new(); var tlp := tl.add_painter(horn)
	for side: float in [-1.0, 1.0]:
		var n := 7 if monitor else 5
		for k in range(n):
			var at := snout.lerp(jaw_at, 0.05 + k / float(n) * 0.75) + Vector3(side * (0.06 + k * (0.025 if monitor else 0.035)), -0.02, 0)
			tl.crystal(at, Vector3(0, -1, 0.1), 0.06 + (0.03 if k == 1 else 0.0), 0.014, tlp, 4)
	part(head, "Teeth", tl)
	# The jaw, hinged at the back.
	var jaw := joint(head, "HingedBasaltJaw", jaw_at)
	var js := Sculpt.new(); var jp := js.add_painter(basalt); var jt := js.add_painter(horn)
	var jl := Sculpt.new(); var jlp := jl.add_painter(molten)
	var jaw_tip := snout + Vector3(0, -0.12, 0.04)
	js.tube([jaw_at + Vector3(0, -0.02, 0.02), jaw_at.lerp(jaw_tip, 0.5) + Vector3(0, -0.04, 0), jaw_tip], [0.2 if not monitor else (0.13 if drake else 0.18), 0.16 if not monitor else (0.1 if drake else 0.13), 0.06], jp, {"sides": 14, "per": 3, "flat": 1.5, "lump": 0.05})
	jl.blob(jaw_at.lerp(jaw_tip, 0.45) + Vector3(0, 0.07, 0), Vector3(0.11, 0.025, (jaw_tip - jaw_at).length() * 0.42), jlp, {"lat": 4, "lon": 8})
	for side: float in [-1.0, 1.0]:
		var n := 6 if monitor else 4
		for k in range(n):
			var at := jaw_tip.lerp(jaw_at, 0.08 + k / float(n) * 0.7) + Vector3(side * (0.05 + k * 0.03), 0.06, 0)
			js.crystal(at, Vector3(0, 1, -0.1), 0.05, 0.012, jt, 4)
	if monitor:
		# The forked tongue, flicking out.
		var tongue := js.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#ffb020").lerp(Color("#ff4a08"), v))
		for side: float in [-1.0, 1.0]:
			js.tube([jaw_tip + Vector3(0, 0.08, 0.2), jaw_tip + Vector3(0, 0.07, -0.05), jaw_tip + Vector3(0.05 * side, 0.08, -0.25)], [0.02, 0.014, 0.003], tongue, {"sides": 5, "per": 2, "flat": 1.6, "cap1": false})
	if ank or thorn:
		for side: float in [-1.0, 1.0]: js.crystal(jaw_at + Vector3(0.2 * side, -0.08, -0.1), Vector3(side, -0.6, 0.4), 0.16, 0.04, jt, 4)
	part(jaw, "Jaw", js).rotation.x = -0.3
	part(jaw, "MoltenMouthFloor", jl, lava_mat).rotation.x = -0.3

	# ---- the tail
	var tail_at: Vector3 = spine[4]
	var tail := joint(root, "ArticulatedFurnaceTail", tail_at)
	var tls := Sculpt.new(); var tlb := tls.add_painter(pahoehoe if monitor else basalt); var th := tls.add_painter(horn)
	var tlv := Sculpt.new(); var tlvp := tlv.add_painter(molten)
	var tpts: Array = []; var trr: Array = []
	var tl_len := 1.9 if monitor else (1.3 if ank else 0.8)
	for k in range(8):
		var t := k / 7.0
		tpts.append(tail_at + Vector3(0.18 * sin(t * 2.2), -0.6 * t * t + (-0.05 if monitor else 0.05) * t, tl_len * t)); trr.append(lerpf(rads[4] * 0.95, 0.06 if not ank else 0.1, t))
	tls.tube(tpts, trr, tlb, {"sides": 14, "per": 3, "lump": 0.05, "flat": 0.8, "side": Vector3.UP})
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
	# Two small torn wings rising off the shoulders: arm, wrist and three fingers, scorched
	# skin between them, ragged and holed.
	var ws := Sculpt.new(); var wb := ws.add_painter(basalt); var wc := ws.add_painter(horn)
	var skin := ws.add_painter(func (p: Vector3, _n, v: float, w: float) -> Color: return Color("#1a0e0c").lerp(Color("#6a2a14"), clampf(Sculpt.noise(p * 9.0) * 0.6 + 0.3, 0.0, 1.0)).lerp(Color("#ff6a14"), smoothstep(0.9, 1.0, v) * 0.25))
	var wrng := RandomNumberGenerator.new(); wrng.seed = 31
	var shoulder := along_line(spine, 0.22)
	for side: float in [-1.0, 1.0]:
		var r0 := shoulder + Vector3(rads[1] * 0.5 * side, rads[1] * 0.55, 0.05)
		var el := r0 + Vector3(0.35 * side, 0.4, 0.15)
		var wr := el + Vector3(0.2 * side, 0.35, 0.3)
		var tips := [wr + Vector3(0.5 * side, 0.2, 0.3), wr + Vector3(0.45 * side, -0.15, 0.6), wr + Vector3(0.15 * side, -0.45, 0.65)]
		ws.tube([r0, el], [0.07, 0.055], wb, {"sides": 8, "per": 2})
		ws.blob(el, Vector3.ONE * 0.055, wb, {"lat": 4, "lon": 6})
		ws.tube([el, wr], [0.05, 0.04], wb, {"sides": 8, "per": 2})
		ws.crystal(wr, Vector3(0.2 * side, 1, -0.6), 0.14, 0.03, wc, 4)
		for t: Vector3 in tips: ws.tube([wr, wr.lerp(t, 0.5) + Vector3(0, 0.04, 0), t], [0.03, 0.022, 0.004], wb, {"sides": 6, "per": 2, "cap1": false})
		# Skin: fans between the fingers and back to the body, its edge torn.
		var edges := [[tips[0], tips[1]], [tips[1], tips[2]], [tips[2], shoulder + Vector3(rads[1] * 0.6 * side, rads[1] * 0.3, 0.5)]]
		for e: Array in edges:
			var a: Vector3 = e[0]; var b: Vector3 = e[1]
			var n := 6
			for layer in [0, 1]:
				var base := ws._v.size()
				ws._v.append(wr); ws._along.append(0.0); ws._ridge.append(0.0); ws._painter.append(skin)
				for k in range(n + 1):
					var t := k / float(n)
					var edge := a.lerp(b, t)
					var pull := 0.72 + 0.2 * sin(PI * t) * 0.0 - (wrng.randf() * 0.25 if k > 0 and k < n else 0.0)
					var q := wr.lerp(edge, pull if (k > 0 and k < n) else 1.0) + Vector3(0, -0.05 * sin(PI * t), 0)
					ws._v.append(q); ws._along.append(1.0); ws._ridge.append(t); ws._painter.append(skin)
				for k in range(n):
					if k == 2 and e == edges[1]: continue
					if layer == 0: ws._i.append_array(PackedInt32Array([base, base + k + 1, base + k + 2]))
					else: ws._i.append_array(PackedInt32Array([base, base + k + 2, base + k + 1]))
	var wmat := material.duplicate() as StandardMaterial3D
	wmat.cull_mode = BaseMaterial3D.CULL_DISABLED; wmat.albedo_texture = null; wmat.vertex_color_is_srgb = true
	part(root, "TornWings", ws, wmat)
