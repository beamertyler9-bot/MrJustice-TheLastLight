extends "res://tools/sculpt_mourning_knight.gd"
## The Shard Sentinel of Prismere, sculpted by hand: a tall guardian of crystal plates grown on
## a core of stone, with a great maul; its joints brighten before the hammer falls. Three designs,
## each built on a real crystal:
##   quartz   - rock crystal: six-sided prisms ending in six-faced points, growing in clusters
##              ("druses") out of grey granite the way they line a vein, milky at the root and
##              water-clear at the tip, with a few amethyst points among them
##   bismuth  - bismuth as it crystallises when molten bismuth cools: stair-stepped square
##              "hopper" crystals, hollow in the middle, their thin oxide skin shining gold,
##              rose, blue and green
##   selenite - the giant gypsum beams of the Cave of the Crystals at Naica in Mexico (some over
##              11 m long): long, flat-sided, pearly translucent blades with fine lengthwise
##              striations, growing out of dark cave rock
## The maul is held as a real one is: both hands on the haft, the hands well apart (the lead hand
## near the head, the other near the butt), the head carried up over the right shoulder ready for
## an overhead blow.

var crystal_mat: StandardMaterial3D
var kindc := "quartz"


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(2.5, 2.5, 2.5); material.metallic = 0.0; material.roughness = 0.85
	crystal_mat = StandardMaterial3D.new()
	crystal_mat.vertex_color_use_as_albedo = true; crystal_mat.vertex_color_is_srgb = true
	crystal_mat.roughness = 0.08; crystal_mat.metallic_specular = 1.0
	crystal_mat.rim_enabled = true; crystal_mat.rim = 0.6; crystal_mat.rim_tint = 0.3
	crystal_mat.emission_enabled = true; crystal_mat.emission_energy_multiplier = 0.25
	crystal_mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ShardSentinel"
	kindc = variant
	kind = "sentinel"
	match variant:
		"quartz":
			glow.albedo_color = Color("#d8f4ff").darkened(0.2); glow.emission = Color("#c8f0ff")
			crystal_mat.emission = Color("#5a6a8a")
		"bismuth":
			glow.albedo_color = Color("#ffb8e8").darkened(0.2); glow.emission = Color("#ffa0e0")
			crystal_mat.metallic = 0.85; crystal_mat.roughness = 0.2; crystal_mat.emission = Color("#3a2a3a")
		"selenite":
			glow.albedo_color = Color("#fff0c8").darkened(0.2); glow.emission = Color("#ffe8b0")
			crystal_mat.emission = Color("#6a6050"); crystal_mat.roughness = 0.25
		_: return null
	glow.emission_energy_multiplier = 2.2
	return _sentinel()


# ------------------------------------------------------------------ painters

static func granite(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#3a3a3e").lerp(Color("#7a7a80"), clampf(n.y * 0.2 + 0.4 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
	c = c.lerp(Color("#d8d4cc"), smoothstep(0.7, 0.78, Sculpt.noise(p * 60.0)) * 0.6)
	c = c.lerp(Color("#141416"), smoothstep(0.72, 0.8, Sculpt.noise(p * 45.0 + Vector3(3, 0, 0))) * 0.7)
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.3)


static func slag(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#1c1a1e").lerp(Color("#4a464e"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(p * 7.0) * 0.4, 0.0, 1.0))
	return c.lerp(Color("#5a4a6a"), smoothstep(0.6, 0.8, Sculpt.noise(p * 12.0)) * 0.4)


static func cave_rock(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#2a221c").lerp(Color("#6a5a48"), clampf(n.y * 0.2 + 0.35 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.35)


## Rock crystal: milky and faintly lilac at the root, clear and bright toward the point.
static func quartz(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#b8b4c8").lerp(Color("#f4f8ff"), clampf(v * 0.9 + n.y * 0.1, 0.0, 1.0))
	c = c.lerp(Color("#ffffff"), smoothstep(0.4, 0.7, Sculpt.noise(p * 20.0)) * 0.25)
	return c


static func amethyst(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return Color("#4a2a6a").lerp(Color("#b48ae0"), clampf(v * 0.9 + n.y * 0.15 + Sculpt.noise(p * 14.0) * 0.15, 0.0, 1.0))


## Bismuth's oxide skin: iridescent, the colour running gold to rose to blue to green.
static func bismuth(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var pal := [Color("#e8b84a"), Color("#e8709a"), Color("#9a6ae0"), Color("#4a9ae8"), Color("#4ad8c0"), Color("#d8c860"), Color("#e8b84a")]
	var h := fposmod(Sculpt.noise(p * 5.0) * 0.5 + p.y * 3.0 + absf(n.x) * 0.2 + absf(n.z) * 0.1, 1.0) * 6.0
	var i := int(floorf(h))
	var c: Color = (pal[i] as Color).lerp(pal[i + 1], h - i)
	return c.lerp(Color("#d0ccd4"), smoothstep(0.8, 0.92, Sculpt.noise(p * 25.0)) * 0.5)


## Selenite: pearly and translucent, faint gold, with fine lengthwise striations.
static func selenite(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var stria := absf(sin((p.x * 3.0 + p.z * 5.0 + p.y * 0.4) * 90.0))
	var c := Color("#c8b898").lerp(Color("#f6f0e2"), clampf(0.55 + n.y * 0.15 + v * 0.25 - stria * 0.12, 0.0, 1.0))
	return c


# ------------------------------------------------------------------ crystal growths

## One crystal of this sentinel's kind growing from `at` along `dir`.
func shard(s: Sculpt, p: int, at: Vector3, dir: Vector3, length: float, r: float, seed := 0.0) -> void:
	match kindc:
		"quartz":
			s.crystal(at, dir, length, r, p, 6, seed)
		"bismuth":
			hopper(s, p, at, dir, r * 3.2, 4 + int(fposmod(seed * 3.0, 2.0)), seed)
		"selenite":
			s.crystal(at, dir, length * 1.5, r * 0.85, p, 4, PI * 0.25 + seed * 0.2)


## A bismuth hopper crystal: a stair-stepped square spiral of frames, hollow in the middle,
## rising from `at` along `up`.
func hopper(s: Sculpt, p: int, at: Vector3, up: Vector3, size: float, steps: int, seed: float) -> void:
	var u := up.normalized()
	var a := u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized().rotated(u, seed)
	var b := u.cross(a)
	var bs := Basis(a, u, b)
	for k in range(steps):
		var half := size * 0.5 * (1.0 - k * 0.16)
		var h := size * 0.12
		var c := at + u * (k * h * 0.95)
		var t := size * 0.1
		for side in range(4):
			var ang := side * PI * 0.5
			var off := (a * cos(ang) + b * sin(ang)) * (half - t * 0.5)
			var along := (a * -sin(ang) + b * cos(ang))
			box(s, p, c + off, Basis(along.cross(u).normalized(), u, along), Vector3(t * 0.5, h * 0.5, half))


## A flat-faced box centred on `c`, oriented by `b`, with half-extents `e`.
func box(s: Sculpt, p: int, c: Vector3, b: Basis, e: Vector3) -> void:
	var first := s._i.size()
	var base := s._v.size()
	for k in range(8):
		var q := Vector3(e.x * (1.0 if k & 1 else -1.0), e.y * (1.0 if k & 2 else -1.0), e.z * (1.0 if k & 4 else -1.0))
		s._v.append(c + b * q); s._along.append(0.5 + 0.5 * signf(q.y)); s._ridge.append(0.0); s._painter.append(p)
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f: Array in faces:
		var a0: int = base + f[0]; var a1: int = base + f[1]; var a2: int = base + f[2]; var a3: int = base + f[3]
		var nrm := (s._v[a1] - s._v[a0]).cross(s._v[a2] - s._v[a0])
		var mid := (s._v[a0] + s._v[a2]) * 0.5
		if nrm.dot(mid - c) < 0.0: s._i.append_array(PackedInt32Array([a0, a2, a1, a0, a3, a2]))
		else: s._i.append_array(PackedInt32Array([a0, a1, a2, a0, a2, a3]))
	s._facets.append(Vector2i(first, s._i.size()))


## A cluster of crystals fanning out around `normal` from `at`.
func cluster(s: Sculpt, p: int, at: Vector3, normal: Vector3, count: int, length: float, r: float, seed: float, spread := 0.55, alt := -1) -> void:
	var nrm := normal.normalized()
	var a := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized(); var b := nrm.cross(a)
	for k in range(count):
		var ang := TAU * k / count + seed
		var t := 0.4 + 0.6 * fposmod(k * 0.618 + seed, 1.0)
		var d := (nrm + (a * cos(ang) + b * sin(ang)) * spread * t).normalized()
		var l := length * (0.55 + 0.45 * fposmod(k * 0.37 + seed * 0.3, 1.0)) * (1.25 if k == 0 else 1.0)
		var base := at + (a * cos(ang) + b * sin(ang)) * r * 1.2 * t
		shard(s, alt if (alt >= 0 and k % 4 == 3) else p, base, (nrm * 1.6 if k == 0 else d), l, r * (1.25 if k == 0 else 0.8 + 0.3 * t), seed + k)


# ------------------------------------------------------------------ the sentinel

func _sentinel() -> Node3D:
	var stone: Callable = granite
	var cpaint: Callable = quartz
	match kindc:
		"bismuth": stone = slag; cpaint = bismuth
		"selenite": stone = cave_rock; cpaint = selenite
	var cs := Sculpt.new(); var cp := cs.add_painter(cpaint)
	var ap := cs.add_painter(amethyst) if kindc == "quartz" else -1
	var crystals_root := cs

	# ---- the stone core: a heavy torso, a waist, a pelvis
	var body := Sculpt.new(); var sp := body.add_painter(stone)
	body.tube([Vector3(0, 0.84, 0.0), Vector3(0, 1.0, 0.0), Vector3(0, 1.22, -0.01), Vector3(0, 1.46, 0.0)], [0.18, 0.13, 0.25, 0.29], sp, {"sides": 14, "per": 2, "flat": 0.72, "side": Vector3.BACK, "lump": 0.12})
	body.rock(Vector3(0, 0.84, 0.0), Vector3(0.22, 0.12, 0.17), sp, {"seed": 1})
	body.rock(Vector3(0, 1.52, 0.0), Vector3(0.16, 0.08, 0.13), sp, {"seed": 2})
	steel_part(root, "Core", body)
	# Crystal plates grown over the chest and back, the shoulders, the hips.
	var plates := Sculpt.new(); var pp := plates.add_painter(cpaint); var pa := plates.add_painter(amethyst) if kindc == "quartz" else -1
	# Rows of long crystals lying up the chest like overlapping plates, each row over the next.
	for row in range(3):
		var yy := 1.02 + row * 0.15
		var n := 4 + (row % 2)
		for k in range(n):
			var x := lerpf(-0.17, 0.17, k / float(n - 1)) * (0.8 + row * 0.15)
			var z := -0.13 - row * 0.03 - 0.04 * (1.0 - absf(x) / 0.25)
			shard(plates, pp if (k + row) % 5 != 2 or pa < 0 else pa, Vector3(x, yy, z), Vector3(x * 1.4, 1.0, -0.55), 0.3, 0.05, row * 1.3 + k)
	# A great ridge of crystal standing up the back.
	cluster(plates, pp, Vector3(0, 1.32, 0.17), Vector3(0, 0.9, 1.0), 9, 0.5, 0.06, 2.1, 0.7, pa)
	cluster(plates, pp, Vector3(0, 1.05, 0.15), Vector3(0, 0.4, 1.0), 5, 0.3, 0.045, 7.1, 0.6, pa)
	# Plates over the hips.
	for side: float in [-1.0, 1.0]:
		for k in range(3): shard(plates, pp, Vector3((0.1 + k * 0.04) * side, 0.92 - k * 0.02, -0.12 + k * 0.05), Vector3(side * 0.5, -0.9, -0.3), 0.22, 0.045, k + side)
	part(root, "Plates", plates, crystal_mat)
	# A crystal heart glowing in a split down the chest.
	var hs_ := Sculpt.new(); var hgp := hs_.add_painter(func (p, n, v, w): return Color.WHITE)
	hs_.crystal(Vector3(0, 1.17, -0.2), Vector3(0, 1, -0.15), 0.2, 0.04, hgp, 6)
	var core := part(root, "Heart", hs_, glow); core.material_override = glow

	# ---- head: a small stone head sunk between the shoulders, a crown of crystal, a glowing sight
	var head := joint(root, "Head", Vector3(0, 1.56, 0.0))
	var hd := Sculpt.new(); var hp := hd.add_painter(stone); var hk := hd.add_painter(func (p, n, v, w): return Color("#08080a"))
	hd.rock(Vector3(0, 1.64, -0.02), Vector3(0.11, 0.11, 0.12), hp, {"seed": 5})
	hd.rock(Vector3(0, 1.6, -0.1), Vector3(0.09, 0.06, 0.06), hp, {"seed": 6})
	hd.tube([Vector3(-0.08, 1.685, -0.12), Vector3(0, 1.678, -0.14), Vector3(0.08, 1.685, -0.12)], [0.014, 0.016, 0.014], hk, {"sides": 5, "per": 2})
	steel_part(head, "Head", hd)
	var crown := Sculpt.new(); var crp := crown.add_painter(cpaint)
	# A helm of crystal: long points sweeping back over the skull from the brow, like a crest.
	for k in range(7):
		var x := (k - 3) * 0.035
		shard(crown, crp, Vector3(x, 1.71 + 0.01 * (3 - absf(k - 3)), -0.1 + absf(k - 3) * 0.015), Vector3(x * 2.0, 0.65, 1.0), 0.32 - absf(k - 3) * 0.04, 0.035, k * 0.9)
	for side: float in [-1.0, 1.0]: shard(crown, crp, Vector3(0.1 * side, 1.62, -0.04), Vector3(side, 0.2, 0.6), 0.16, 0.03, side)
	part(head, "Crown", crown, crystal_mat)
	var eg := Sculpt.new(); var egp := eg.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]: eg.blob(Vector3(0.035 * side, 1.68, -0.145), Vector3(0.022, 0.009, 0.006), egp, {"lat": 4, "lon": 6})
	part(head, "Eyes", eg, glow).material_override = glow

	# ---- arms. Both hands on the maul's haft: the right hand near the head, the left near the
	# butt; the head carried up over the right shoulder.
	var lh := Vector3(-0.1, 0.98, -0.3); var rh := Vector3(0.2, 1.36, -0.26)
	var hd_dir := (rh - lh).normalized()
	var arms: Array = []; var forearms: Array = []
	var joints_glow: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var sh_at := Vector3(0.32 * side, 1.44, 0.0)
		var elbow_at := Vector3(0.38, 1.13, -0.04) if side > 0 else Vector3(-0.36, 1.1, -0.04)
		var fc: Vector3 = rh if side > 0 else lh
		var shoulder := joint(root, label + "Shoulder", sh_at)
		var us := Sculpt.new(); var up := us.add_painter(stone)
		us.rock(sh_at + Vector3(0.03 * side, 0.0, 0), Vector3(0.12, 0.11, 0.12), up, {"seed": 7 + side})
		us.tube([sh_at + Vector3(0.02 * side, -0.05, 0), elbow_at + Vector3(0, 0.04, 0)], [0.085, 0.075], up, {"sides": 10, "per": 2, "lump": 0.15})
		steel_part(shoulder, "UpperArm", us)
		var pc := Sculpt.new(); var pcp := pc.add_painter(cpaint)
		cluster(pc, pcp, sh_at + Vector3(0.08 * side, 0.08, 0.0), Vector3(side * 0.8, 1.0, 0.1), 8, 0.48, 0.06, 5.0 + side, 0.65, pc.add_painter(amethyst) if kindc == "quartz" else -1)
		for k in range(3): shard(pc, pcp, sh_at.lerp(elbow_at, 0.3 + k * 0.22) + Vector3(0.07 * side, 0, 0), Vector3(side * 0.6, 0.9, 0.1), 0.24, 0.045, k * 2.0 + side)
		part(shoulder, "Pauldron", pc, crystal_mat)
		var elbow := joint(shoulder, "Forearm", elbow_at)
		var fs := Sculpt.new(); var fp := fs.add_painter(stone)
		var fa := (fc - elbow_at).normalized()
		var wrist := fc - fa * 0.075
		fs.rock(elbow_at, Vector3(0.08, 0.08, 0.08), fp, {"seed": 11 + side})
		fs.tube([elbow_at + fa * 0.04, wrist], [0.08, 0.066], fp, {"sides": 10, "per": 2, "lump": 0.15})
		var bh := fa.cross(hd_dir).normalized() if side > 0.0 else hd_dir.cross(fa).normalized()
		fist(fs, fp, fc, hd_dir, fa, bh, 0.024)
		steel_part(elbow, "Forearm", fs)
		var fcs := Sculpt.new(); var fcp := fcs.add_painter(cpaint)
		var outv := fa.cross(Vector3.UP).normalized() * -side
		if outv.length() < 0.5: outv = Vector3(side, 0, 0)
		for k in range(4):
			shard(fcs, fcp, elbow_at.lerp(wrist, 0.15 + k * 0.22) + outv * 0.06, (outv * 0.6 - fa * 0.8).normalized(), 0.24 - k * 0.03, 0.045, k + side)
		part(elbow, "Shards", fcs, crystal_mat)
		# The joint seam that brightens before a blow.
		var gj := Sculpt.new(); var gjp := gj.add_painter(func (p, n, v, w): return Color.WHITE)
		gj.blob(elbow_at, Vector3(0.088, 0.03, 0.088), gjp, {"lat": 3, "lon": 10})
		part(elbow, "JointGlow", gj, glow).material_override = glow
		if side > 0.0:
			# The maul: a stone haft bound in iron, a great crystal head on it.
			var ms := Sculpt.new(); var mh := ms.add_painter(stone); var mi := ms.add_painter(black_steel)
			var butt := lh - hd_dir * 0.22
			var top := rh + hd_dir * 0.45
			ms.tube([butt, top], [0.026, 0.026], mh, {"sides": 8, "per": 3, "lump": 0.08})
			for q in range(4): ms.tube([butt.lerp(top, 0.05 + q * 0.3), butt.lerp(top, 0.08 + q * 0.3)], [0.032, 0.032], mi, {"sides": 8, "per": 1})
			var hc := top + hd_dir * 0.08
			var across := hd_dir.cross(Vector3.BACK).normalized()
			if across.length() < 0.5: across = Vector3.RIGHT
			ms.rock(hc, Vector3(0.17, 0.15, 0.15), mh, {"seed": 21, "basis": Basis(across, hd_dir, across.cross(hd_dir))})
			for sgn: float in [-1.0, 1.0]: ms.tube([hc - across * 0.13 * sgn, hc - across * 0.17 * sgn], [0.09, 0.09], mi, {"sides": 8, "per": 1})
			steel_part(elbow, "Maul", ms)
			var mc := Sculpt.new(); var mcp := mc.add_painter(cpaint)
			for sgn: float in [-1.0, 1.0]:
				cluster(mc, mcp, hc + across * 0.2 * sgn, across * sgn, 7, 0.32, 0.07, 9.0 + sgn, 0.45, mc.add_painter(amethyst) if kindc == "quartz" else -1)
			cluster(mc, mcp, hc + hd_dir * 0.14, hd_dir, 5, 0.24, 0.05, 12.0, 0.5)
			part(elbow, "MaulHead", mc, crystal_mat)
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs: heavy stone, crystal shards down the shins, knee seams that glow
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(0.14 * side, 0.82, 0.0)
		var knee_at := Vector3(0.16 * side, 0.46, -0.03)
		var hip := joint(root, label + "Hip", hip_at)
		var ts := Sculpt.new(); var tp := ts.add_painter(stone)
		ts.tube([hip_at, knee_at + Vector3(0, 0.04, 0)], [0.11, 0.09], tp, {"sides": 10, "per": 2, "lump": 0.15})
		steel_part(hip, "Thigh", ts)
		var tc := Sculpt.new(); var tcp := tc.add_painter(cpaint)
		for k in range(3): shard(tc, tcp, hip_at.lerp(knee_at, 0.2 + k * 0.25) + Vector3(0.05 * side, 0, -0.08), Vector3(side * 0.3, 0.9, -0.5), 0.26, 0.05, 14.0 + k + side)
		part(hip, "Shards", tc, crystal_mat)
		var knee := joint(hip, "Knee", knee_at)
		var ls := Sculpt.new(); var lp := ls.add_painter(stone)
		var ankle := Vector3(0.16 * side, 0.1, 0.0)
		ls.rock(knee_at, Vector3(0.09, 0.09, 0.09), lp, {"seed": 15 + side})
		ls.tube([knee_at + Vector3(0, -0.04, 0), ankle], [0.09, 0.07], lp, {"sides": 10, "per": 2, "lump": 0.15})
		ls.rock(Vector3(0.16 * side, 0.06, -0.06), Vector3(0.1, 0.06, 0.16), lp, {"seed": 17 + side})
		steel_part(knee, "Shin", ls)
		var sc := Sculpt.new(); var scp := sc.add_painter(cpaint)
		for k in range(4): shard(sc, scp, knee_at.lerp(ankle, 0.1 + k * 0.22) + Vector3(0.03 * side, 0, -0.075), Vector3(0.25 * side, 1.0, -0.45), 0.26, 0.05, k * 1.7 + side)
		part(knee, "Shards", sc, crystal_mat)
		var gk := Sculpt.new(); var gkp := gk.add_painter(func (p, n, v, w): return Color.WHITE)
		gk.blob(knee_at, Vector3(0.1, 0.03, 0.1), gkp, {"lat": 3, "lon": 10})
		part(knee, "JointGlow", gk, glow).material_override = glow
		hips.append(hip); knees.append(knee)

	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.6)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
