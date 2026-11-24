extends "res://tools/creature_kit.gd"
## The Mourning Knight of Hollowmourn, sculpted by hand: a suit of Gothic armour with no one
## inside it, still keeping watch, hung with torn violet cloth and carrying a long blade; it
## pauses in a guard you can read before it cuts. Three designs, each built on real armour and
## real mourning dress of the 1400s:
##   gothic   - German "Gothic" plate of about 1480: fluted, rippled plates with cusped, scalloped
##              edges, a sallet helmet with its long tail and a bevor guarding the chin, pointed
##              sabatons, a longsword, and a torn violet tabard with mourning crape streaming from
##              the helm
##   pleurant - the "pleurants", the hooded weeping mourners carved round the tombs of the Dukes
##              of Burgundy: a knight wrapped in a heavy mourning cloak, its deep hood hiding
##              everything but two violet lights, a long tail (liripipe) hanging from the hood, with
##              armour showing where the cloak falls open and a great sword held point-down
##   hollow   - the armour come apart: every plate floats free, held in place only by violet
##              ghost-fire burning in the gaps; no face in the helm, just flame, and a torn violet
##              banner on a pole at its back

const VIOLET := Color("#b48aff")

var kind := "gothic"
var cloth_mat: StandardMaterial3D
var fire_mat: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = null
	material.metallic = 0.35; material.roughness = 0.42
	cloth_mat = StandardMaterial3D.new()
	cloth_mat.vertex_color_use_as_albedo = true
	cloth_mat.albedo_texture = load("res://assets/cast/cloth_color.png")
	cloth_mat.uv1_triplanar = true; cloth_mat.uv1_scale = Vector3(3, 3, 3)
	cloth_mat.roughness = 0.9; cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fire_mat = StandardMaterial3D.new()
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = VIOLET.darkened(0.2); glow.emission = VIOLET; glow.emission_energy_multiplier = 2.2


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "MourningKnight"
	kind = variant
	if not variant in ["gothic", "pleurant", "hollow"]: return null
	return _knight()


# ------------------------------------------------------------------ painters

## Blackened steel, bright along the edges and ridges, with a faint violet sheen.
static func steel(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#24262c").lerp(Color("#73767f"), clampf(n.y * 0.3 + 0.35 + Sculpt.fbm(p * 6.0) * 0.25, 0.0, 1.0))
	c = c.lerp(Color("#c8ccd6"), clampf(w, 0.0, 1.0) * 0.5)
	c = c.lerp(Color("#3a3444"), smoothstep(0.55, 0.8, Sculpt.noise(p * 4.0)) * 0.25)
	return c.lerp(Color("#5a3a22"), smoothstep(0.66, 0.8, Sculpt.noise(p * 17.0)) * 0.35)


static func brass(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#5a4422").lerp(Color("#b08a4a"), clampf(n.y * 0.4 + 0.4 + Sculpt.noise(p * 20.0) * 0.2, 0.0, 1.0))


## Mourning violet: deep and faded, darker in the folds, frayed paler at the torn ends.
static func violet_cloth(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#1e1226").lerp(Color("#5a3470"), clampf(0.45 + 0.35 * sin(p.x * 40.0 + p.z * 31.0) + n.y * 0.2 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#7a6a80"), smoothstep(0.82, 1.0, v) * 0.35)


static func black_cloth(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0c0b10").lerp(Color("#2e2836"), clampf(0.45 + 0.35 * sin(p.x * 34.0 + p.z * 27.0) + n.y * 0.2 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#4a3a5a"), smoothstep(0.85, 1.0, v) * 0.4)


static func ghost_fire(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	var a := (1.0 - v) * (0.6 + 0.3 * Sculpt.noise(p * 12.0))
	return Color(0.62 * a, 0.42 * a, 1.0 * a, 1.0)


# ------------------------------------------------------------------ pieces

## Hammered plate: every face lit flat, so the armour reads as hard metal with crisp edges.
func steel_part(parent: Node3D, name: String, s: Sculpt) -> MeshInstance3D:
	s._facets.append(Vector2i(0, s._i.size()))
	return part(parent, name, s)


## A plate along a limb: fluted (rippled) like Gothic armour when `flutes` > 0.
func plate(s: Sculpt, painter: int, pts: Array, radii: Array, flutes := 0, flat := 1.0) -> void:
	var o := {"sides": 16, "per": 3, "flat": flat}
	if flutes > 0: o["ridges"] = flutes; o["ridge"] = 0.07
	s.tube(pts, radii, painter, o)


## A cusped rim: a thin ring round a limb with a scalloped edge.
func rim(s: Sculpt, painter: int, c: Vector3, axis: Vector3, r: float, cusp := 8) -> void:
	var a := axis.normalized(); var u := a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized(); var v := a.cross(u)
	var ring: Array = []; var rr: Array = []
	for k in range(cusp * 2 + 1):
		var t := TAU * k / (cusp * 2.0)
		ring.append(c + (u * cos(t) + v * sin(t)) * r + a * (0.012 if k % 2 == 0 else -0.004)); rr.append(0.009)
	s.tube(ring, rr, painter, {"sides": 5, "per": 1})


## Torn cloth hanging from a row of points: strips of different lengths, swaying apart a little.
func drape(s: Sculpt, painter: int, tops: Array, length: float, out: Vector3, width: float, seed := 0.0) -> void:
	for k in range(tops.size()):
		var t: Vector3 = tops[k]
		var l := length * (0.65 + 0.45 * fposmod(k * 0.618 + seed, 1.0))
		var sway := Vector3(0.03 * sin(k * 2.3 + seed), 0, 0.03 * cos(k * 1.7 + seed))
		var pts := [t, t + Vector3(0, -l * 0.35, 0) + out * 0.04 + sway * 0.5, t + Vector3(0, -l * 0.7, 0) + out * 0.07 + sway, t + Vector3(0, -l, 0) + out * 0.08 + sway * 1.4]
		var dir: Vector3 = (pts[3] - pts[0]).normalized()
		var side := dir.cross(out).normalized() if out.length() > 0.0 else Vector3.RIGHT
		s.tube(pts, [width, width, width * 0.9, width * 0.5], painter, {"sides": 6, "per": 2, "flat": 0.15, "side": out.normalized() if out.length() > 0.0 else Vector3.BACK, "cap1": false, "lump": 0.3})


## A tongue of ghost-fire from `base` along `dir`.
func flame(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, seed: float) -> void:
	var d := dir.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	s.tube([base, base + d * length * 0.35 + side * 0.02 * sin(seed * 2.3), base + d * length * 0.7 - side * 0.025 * sin(seed * 1.7), base + d * length], [width, width * 0.8, width * 0.45, 0.003], painter, {"sides": 7, "per": 3, "cap1": false})


# ------------------------------------------------------------------ the knight

func _knight() -> Node3D:
	var gothic := kind == "gothic"; var hood := kind == "pleurant"; var hollow := kind == "hollow"
	var gap := 0.035 if hollow else 0.0
	var fl := 10 if gothic else 0
	var fire := Sculpt.new(); var fp := fire.add_painter(ghost_fire)
	var fire_j: Array = []

	# ---- the torso: breastplate with a waist, fauld lames over the hips, the dark empty neck
	var body := Sculpt.new(); var sp := body.add_painter(steel); var bp := body.add_painter(brass)
	var dark := body.add_painter(func (p, n, v, w): return Color("#050407"))
	plate(body, sp, [Vector3(0, 0.98, 0.0), Vector3(0, 1.1, -0.01), Vector3(0, 1.3, -0.02), Vector3(0, 1.45, 0.0)], [0.15, 0.18, 0.24, 0.2], fl, 0.62)
	# The breastplate swelling out in front, with a ridge down its middle, and the pointed
	# plackart rising over its lower half.
	body.blob(Vector3(0, 1.3, -0.06), Vector3(0.21, 0.15, 0.12), sp, {"lat": 8, "lon": 12})
	body.tube([Vector3(0, 1.02, -0.11), Vector3(0, 1.25, -0.175), Vector3(0, 1.42, -0.15)], [0.012, 0.016, 0.012], sp, {"sides": 5, "per": 2})
	body.blob(Vector3(0, 1.08, -0.1), Vector3(0.15, 0.12, 0.05), sp, {"lat": 6, "lon": 10, "basis": Basis(Vector3.RIGHT, 0.2)})
	body.crystal(Vector3(0, 1.12, -0.13), Vector3(0, 1, -0.25), 0.14, 0.05, sp, 4)
	if gothic: for k in range(5): body.tube([Vector3(-0.12 + k * 0.06, 1.02, -0.13), Vector3(-0.1 + k * 0.05, 1.18, -0.15)], [0.008, 0.006], sp, {"sides": 4, "per": 1})
	for k in range(3):
		var yy := 0.93 - k * 0.055 - (gap * k)
		body.tube([Vector3(0, yy + 0.03, 0), Vector3(0, yy - 0.03, 0)], [0.165 + k * 0.012, 0.172 + k * 0.012], sp, {"sides": 16, "per": 1, "flat": 0.72})
		if gothic: rim(body, bp, Vector3(0, yy - 0.032, 0), Vector3.UP, (0.17 + k * 0.012), 10)
	body.blob(Vector3(0, 1.5, 0.0), Vector3(0.075, 0.04, 0.07), dark, {"lat": 4, "lon": 8})
	body.tube([Vector3(0, 1.46, 0.0), Vector3(0, 1.52, 0.0)], [0.11, 0.095], sp, {"sides": 14, "per": 1, "flat": 0.85})
	# Tassets over the thighs.
	for side: float in [-1.0, 1.0]:
		slab(body, sp, Vector3(0.11 * side, 0.74 - gap * 2.0, -0.08), Vector3(0.15, 0.17, 0.02), Basis(Vector3.RIGHT, -0.12) * Basis(Vector3.BACK, -0.08 * side), 0.4, 0.02)
	if hollow:
		for k in range(4): flame(fire, fp, Vector3(0.1 * sin(k * 2.0), 0.86, 0.08 * cos(k * 2.0)), Vector3(0.1 * sin(k), 1.0, 0.1), 0.16, 0.05, k)
		for k in range(3): flame(fire, fp, Vector3(0.05 * (k - 1), 1.5, 0.02), Vector3(0.1 * (k - 1), 1.0, 0.05), 0.2, 0.05, k + 3)
	steel_part(root, "Body", body)

	# ---- the head: a sallet with a long tail and a bevor; nothing inside but a violet light
	var head := joint(root, "Head", Vector3(0, 1.62 + gap * 2.0, 0.0))
	var hs := Sculpt.new(); var hp := hs.add_painter(steel); var hd := hs.add_painter(func (p, n, v, w): return Color("#050407"))
	var hy := 1.66 + gap * 2.0
	var eyes: Array = []
	if hood:
		var cl := hs.add_painter(black_cloth)
		hs.blob(Vector3(0, hy + 0.01, 0.01), Vector3(0.17, 0.19, 0.19), cl, {"lat": 9, "lon": 12, "lump": 0.12})
		# A hood peaked at the crown and falling in folds over the shoulders.
		hs.tube([Vector3(0, hy + 0.12, 0.02), Vector3(0, hy + 0.22, 0.08), Vector3(0, hy + 0.24, 0.16)], [0.11, 0.06, 0.01], cl, {"sides": 8, "per": 2, "cap1": false})
		hs.tube([Vector3(-0.2, hy - 0.16, 0.02), Vector3(0, hy - 0.2, 0.1), Vector3(0.2, hy - 0.16, 0.02)], [0.07, 0.09, 0.07], cl, {"sides": 8, "per": 3, "lump": 0.2})
		hs.blob(Vector3(0, hy - 0.03, -0.155), Vector3(0.1, 0.125, 0.05), hd, {"lat": 6, "lon": 9})
		# The hood's brim drooping forward over the face, and its long liripipe hanging behind.
		hs.tube([Vector3(-0.13, hy + 0.06, -0.1), Vector3(0, hy + 0.13, -0.17), Vector3(0.13, hy + 0.06, -0.1)], [0.04, 0.05, 0.04], cl, {"sides": 7, "per": 3})
		hs.tube([Vector3(0, hy + 0.12, 0.12), Vector3(0, hy - 0.05, 0.24), Vector3(0.02, hy - 0.35, 0.28), Vector3(0.0, hy - 0.7, 0.26)], [0.07, 0.055, 0.04, 0.02], cl, {"sides": 8, "per": 3, "cap1": false})
		for side: float in [-1.0, 1.0]: eyes.append(Vector3(0.04 * side, hy - 0.01, -0.19))
	else:
		hs.blob(Vector3(0, hy, 0.01), Vector3(0.125, 0.13, 0.15), hp, {"lat": 10, "lon": 14})
		# The sallet's tail sweeping down behind the neck.
		hs.tube([Vector3(0, hy - 0.02, 0.08), Vector3(0, hy - 0.08, 0.2), Vector3(0, hy - 0.12, 0.27)], [0.11, 0.1, 0.07], hp, {"sides": 14, "per": 3, "flat": 0.3, "side": Vector3.UP})
		if gothic:
			# A low comb along the crown.
			hs.tube([Vector3(0, hy + 0.12, -0.08), Vector3(0, hy + 0.14, 0.04), Vector3(0, hy + 0.08, 0.2)], [0.012, 0.014, 0.01], hp, {"sides": 5, "per": 2})
		# The visor slit and the bevor rising over the chin.
		hs.tube([Vector3(-0.1, hy, -0.105), Vector3(0, hy - 0.005, -0.135), Vector3(0.1, hy, -0.105)], [0.012, 0.014, 0.012], hd, {"sides": 5, "per": 3})
		if not hollow: hs.blob(Vector3(0, hy - 0.1, -0.05), Vector3(0.115, 0.08, 0.1), hp, {"lat": 7, "lon": 10})
		for side: float in [-1.0, 1.0]: eyes.append(Vector3(0.04 * side, hy, -0.128))
		if hollow:
			# No face: violet fire where the face should be, and burning up out of the crown.
			for k in range(5): flame(fire, fp, Vector3(0.03 * (k - 2), hy + 0.1, 0.0), Vector3(0.15 * (k - 2), 1.0, 0.25), 0.22 + 0.06 * (k % 2), 0.045, k + 10)
	if hood: part(head, "Helm", hs, cloth_mat)
	else: steel_part(head, "Helm", hs)
	if hood:
		# Armour under the hood: a glimpse of a bevor at the throat.
		var bv := Sculpt.new(); var bvp := bv.add_painter(steel)
		bv.blob(Vector3(0, hy - 0.13, -0.06), Vector3(0.1, 0.06, 0.08), bvp, {"lat": 6, "lon": 9})
		steel_part(head, "Bevor", bv)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e: Vector3 in eyes: es.blob(e, Vector3(0.018, 0.01, 0.008), ew, {"lat": 4, "lon": 6})
	var core := part(head, "GhostEyes", es, glow); core.material_override = glow
	if gothic:
		# Mourning crape: long black-violet streamers tied at the back of the helm.
		var cr := Sculpt.new(); var crp := cr.add_painter(violet_cloth)
		var tops: Array = []
		for k in range(4): tops.append(Vector3(0.04 * (k - 1.5), hy + 0.02, 0.16))
		drape(cr, crp, tops, 0.75, Vector3(0, 0, 1), 0.035, 1.0)
		part(head, "Crape", cr, cloth_mat)

	# ---- arms: fluted pauldrons, couters with fans, vambraces, gauntlets with flared cuffs;
	# the longsword in the right hand held in a low guard
	var arms: Array = []; var forearms: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var sh_at := Vector3(0.27 * side, 1.44, 0)
		var shoulder := joint(root, label + "Shoulder", sh_at + Vector3(gap * 2.0 * side, 0, 0))
		var us := Sculpt.new(); var up := us.add_painter(steel); var ub := us.add_painter(brass)
		var o := Vector3(gap * 2.0 * side, 0, 0)
		us.blob(sh_at + o + Vector3(0.02 * side, 0.04, 0), Vector3(0.13, 0.08, 0.14), up, {"lat": 8, "lon": 12})
		for k in range(2):
			us.tube([sh_at + o + Vector3(0.04 * side, -0.02 - k * 0.05, 0), sh_at + o + Vector3(0.1 * side, -0.05 - k * 0.05, 0)], [0.1 - k * 0.012, 0.1 - k * 0.012], up, {"sides": 14, "per": 1, "flat": 1.2})
		if gothic:
			us.blob(sh_at + o + Vector3(-0.02 * side, 0.11, 0), Vector3(0.025, 0.06, 0.1), up, {"lat": 4, "lon": 8})
			rim(us, ub, sh_at + o + Vector3(0.1 * side, -0.1, 0), Vector3(side, -0.4, 0), 0.085, 8)
		var elbow_at := Vector3(0.33 * side, 1.12, 0.01) + o
		plate(us, up, [sh_at + o + Vector3(0.03 * side, -0.04, 0), elbow_at + Vector3(0, 0.03, 0)], [0.075, 0.068], fl / 2)
		steel_part(shoulder, "Pauldron", us)
		var elbow := joint(shoulder, "Forearm", elbow_at + Vector3(0, -gap, 0))
		var fs := Sculpt.new(); var fp2 := fs.add_painter(steel); var fb := fs.add_painter(brass)
		var e2 := elbow_at + Vector3(0, -gap, 0)
		fs.blob(e2, Vector3(0.075, 0.075, 0.08), fp2, {"lat": 6, "lon": 9})
		fs.blob(e2 + Vector3(0.065 * side, 0.0, 0.035), Vector3(0.014, 0.09, 0.075), fp2, {"lat": 4, "lon": 8, "basis": Basis(Vector3.UP, 0.4 * side)})
		var wrist := e2 + Vector3(0.025 * side, -0.25, -0.05)
		plate(fs, fp2, [e2 + Vector3(0, -0.03, 0), wrist], [0.064, 0.052], fl / 2)
		# The gauntlet: a flared, pointed cuff and an armoured fist.
		fs.tube([wrist + Vector3(0, 0.04, 0), wrist + Vector3(0, -0.03, 0)], [0.08, 0.058], fp2, {"sides": 12, "per": 1, "cap_rings": 1})
		fs.crystal(wrist + Vector3(0, 0.02, 0.0), Vector3(0, 1.0, 0.25), 0.1, 0.03, fp2, 4)
		var fist := wrist + Vector3(0, -0.08, -0.01)
		fs.blob(fist, Vector3(0.055, 0.065, 0.065), fp2, {"lat": 6, "lon": 9})
		for f in range(4): fs.blob(fist + Vector3(-0.02 * side, 0.03 - f * 0.022, -0.045), Vector3(0.022, 0.012, 0.02), fp2, {"lat": 4, "lon": 6})
		if gothic: rim(fs, fb, wrist + Vector3(0, 0.035, 0), Vector3.UP, 0.066, 8)
		if hollow:
			flame(fire, fp, sh_at + o * 0.5 + Vector3(0, -0.02, 0), Vector3(side, 0.6, 0), 0.12, 0.04, side)
			flame(fire, fp, elbow_at + Vector3(0, -gap * 0.5, 0), Vector3(side * 0.5, 1.0, 0.2), 0.1, 0.035, side + 4)
		steel_part(elbow, "Vambrace", fs)
		if side > 0.0:
			# A longsword (a greatsword for the hooded mourner) held in a low guard, point forward.
			var sw := Sculpt.new(); var swp := sw.add_painter(steel); var swg := sw.add_painter(brass)
			var grip := sw.add_painter(func (p, n, v, w): return Color("#1a1218").lerp(Color("#3a2a40"), clampf(sin(p.y * 160.0) * 0.5 + 0.5, 0.0, 1.0)))
			var blade_len := 1.25 if hood else 1.0
			var d := Vector3(-0.05, -0.62, -0.78).normalized() if not hood else Vector3(-0.02, -1.0, -0.12).normalized()
			var hilt := fist
			sw.tube([hilt - d * 0.12, hilt + d * 0.1], [0.018, 0.018], grip, {"sides": 6, "per": 1})
			sw.blob(hilt - d * 0.14, Vector3.ONE * 0.03, swg, {"lat": 5, "lon": 7})
			var cg := hilt + d * 0.12
			var across := d.cross(Vector3.RIGHT).normalized()
			if absf(across.length()) < 0.1: across = Vector3.BACK
			var xg := Vector3.RIGHT
			sw.tube([cg - xg * 0.13, cg, cg + xg * 0.13], [0.014, 0.018, 0.014], swg, {"sides": 6, "per": 2})
			sw.tube([cg + d * 0.01, cg + d * blade_len * 0.5, cg + d * blade_len], [0.035, 0.03, 0.004], swp, {"sides": 4, "per": 3, "flat": 0.22, "side": across, "cap1": false})
			sw.tube([cg + d * 0.02, cg + d * blade_len * 0.85], [0.006, 0.004], sw.add_painter(func (p, n, v, w): return Color("#0a0a0e")), {"sides": 4, "per": 1})
			steel_part(elbow, "Sword", sw)
			if hollow or gothic:
				var rs := Sculpt.new(); var rp := rs.add_painter(func (p, n, v, w): return Color.WHITE)
				rs.tube([cg + d * 0.06 + across * 0.004, cg + d * blade_len * 0.7 + across * 0.004], [0.005, 0.003], rp, {"sides": 4, "per": 1})
				part(elbow, "Runes", rs, glow).material_override = glow
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs: fluted cuisses, poleyns with side fans, greaves, long pointed sabatons
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(0.11 * side, 0.86 - gap * 3.0, 0.0)
		var hip := joint(root, label + "Hip", hip_at)
		var ts := Sculpt.new(); var tp := ts.add_painter(steel); var tb := ts.add_painter(brass)
		var knee_at := Vector3(0.12 * side, 0.5 - gap * 3.0, -0.02)
		plate(ts, tp, [hip_at + Vector3(0, 0.03, 0), hip_at.lerp(knee_at, 0.5) + Vector3(0, 0, -0.01), knee_at + Vector3(0, 0.05, 0)], [0.12, 0.105, 0.085], fl)
		steel_part(hip, "Cuisse", ts)
		var knee := joint(hip, "Knee", knee_at + Vector3(0, -gap, 0))
		var ls := Sculpt.new(); var lp := ls.add_painter(steel); var lb := ls.add_painter(brass)
		var k2 := knee_at + Vector3(0, -gap, 0)
		ls.blob(k2 + Vector3(0, 0, -0.035), Vector3(0.08, 0.075, 0.07), lp, {"lat": 6, "lon": 9})
		ls.blob(k2 + Vector3(0.075 * side, 0, -0.01), Vector3(0.014, 0.08, 0.07), lp, {"lat": 4, "lon": 8})
		var ankle := Vector3(0.12 * side, 0.1, 0.0)
		plate(ls, lp, [k2 + Vector3(0, -0.04, 0), k2.lerp(ankle, 0.45) + Vector3(0, 0, 0.012), ankle], [0.08, 0.085, 0.058], fl / 2)
		# The sabaton: a long pointed foot of overlapping lames.
		var toe := Vector3(0.12 * side, 0.03, -0.3 if gothic else -0.22)
		ls.tube([ankle + Vector3(0, -0.02, 0.04), Vector3(0.12 * side, 0.045, -0.06), toe], [0.07, 0.06, 0.006], lp, {"sides": 10, "per": 3, "flat": 0.55, "bands": 6, "band": 0.12, "cap1": false})
		if gothic: rim(ls, lb, k2 + Vector3(0, -0.07, 0), Vector3.UP, 0.07, 8)
		if hollow:
			flame(fire, fp, k2 + Vector3(0, gap * 0.5, 0), Vector3(side * 0.4, 1.0, -0.2), 0.11, 0.035, side + 8)
			flame(fire, fp, hip_at + Vector3(0, gap * 1.5, 0), Vector3(side * 0.3, 1.0, 0), 0.12, 0.04, side + 9)
		steel_part(knee, "Greave", ls)
		hips.append(hip); knees.append(knee)

	# ---- cloth
	var cs := Sculpt.new(); var cvp := cs.add_painter(violet_cloth); var cbp := cs.add_painter(black_cloth)
	if gothic:
		# A torn violet tabard over the breastplate, front and back, and a short cape.
		for f: float in [-1.0, 1.0]:
			var tops: Array = []
			for k in range(7): tops.append(Vector3(-0.15 + k * 0.05, 1.02, 0.15 * f + (0.0 if f > 0 else -0.0)))
			drape(cs, cvp, tops, 0.5, Vector3(0, 0, f), 0.03, f)
		var cape: Array = []
		for k in range(11):
			var a := lerpf(-1.2, 1.2, k / 10.0)
			cape.append(Vector3(sin(a) * 0.27, 1.47, 0.04 + cos(a) * 0.1))
		drape(cs, cvp, cape, 0.62, Vector3(0, 0, 1), 0.04, 2.0)
	elif hood:
		# A heavy mourning cloak from the shoulders to the ground, falling open in front.
		var tops: Array = []; var outs: Array = []
		for k in range(25):
			var a := lerpf(-2.65, 2.65, k / 24.0)
			tops.append(Vector3(sin(a) * 0.32, 1.47, cos(a) * 0.19 + 0.02))
		for k in range(tops.size()):
			var t: Vector3 = tops[k]
			var out := Vector3(t.x, 0, t.z - 0.02).normalized()
			drape(cs, cbp, [t], 1.42, out * 1.6, 0.11, k * 0.37)
		# A mantle over the shoulders.
		cs.blob(Vector3(0, 1.43, 0.02), Vector3(0.33, 0.1, 0.2), cbp, {"lat": 6, "lon": 14, "lump": 0.2})
	else:
		# A torn banner on a pole strapped to its back.
		var pole := cs.add_painter(func (p, n, v, w): return Color("#2a2018").lerp(Color("#4a3a2a"), clampf(Sculpt.noise(p * 20.0) + 0.5, 0.0, 1.0)))
		cs.tube([Vector3(0.08, 0.95, 0.2), Vector3(0.12, 2.45, 0.24)], [0.022, 0.018], pole, {"sides": 6, "per": 1})
		cs.tube([Vector3(0.12, 2.4, 0.24), Vector3(-0.38, 2.4, 0.26)], [0.014, 0.014], pole, {"sides": 6, "per": 1})
		var tops: Array = []
		for k in range(9): tops.append(Vector3(0.1 - k * 0.055, 2.39, 0.25))
		drape(cs, cvp, tops, 0.75, Vector3(0, 0, 1), 0.035, 3.0)
		# Shreds of a tabard still clinging to the floating plates.
		var shreds: Array = []
		for k in range(5): shreds.append(Vector3(-0.1 + k * 0.05, 0.98, -0.16))
		drape(cs, cvp, shreds, 0.35, Vector3(0, 0, -1), 0.03, 4.0)
	part(root, "Cloth", cs, cloth_mat)
	if fire.triangles() > 0: part(root, "GhostFire", fire, fire_mat)
	var light := OmniLight3D.new(); light.name = "GhostLight"; light.light_color = VIOLET; light.light_energy = 0.7; light.omni_range = 1.8
	head.add_child(light); light.position = Vector3(0, 0.02, -0.25)
	if hood: light.position = Vector3(0, -0.6, -0.35); light.light_energy = 0.4

	var scale := 1.45
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
