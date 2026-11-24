extends "res://tools/sculpt_hellhound.gd"
## The Hollow Hound of Hollowmourn, sculpted by hand: a ribbed shadow of a dog that walks on
## smoke, its breath fogging in the cold and a low growl giving it away. Three designs, each built
## on a real animal or a real legend:
##   shuck    - Black Shuck, the "church grim" of English folklore: a huge shaggy black hound the
##              size of a calf, built on the Irish wolfhound (long legs, deep chest, a long head
##              with a wiry beard and brows), with eyes like glowing saucers and a broken chain
##              still hanging from its iron collar
##   thylacine- the ghost of the Tasmanian tiger, a hunter that died out in 1936: a stiff tail thick
##              at the root like a kangaroo's, dark stripes across its back and rump like ribs, and
##              jaws that gape wider than any dog's
##   shadow   - a wolf made of shadow and smoke, so thin you can see its bones: the skull, the ribs
##              and the spine dim inside it, smoke streaming off its back

const COLD := Color("#cfe8ff")

var shadow_mat: StandardMaterial3D
var bone_mat: StandardMaterial3D
var mist_mat: StandardMaterial3D


func _init() -> void:
	super()
	throat_paint = func (_p, _n, v, _w): return Color("#e8f4ff").lerp(Color("#7aa8e0"), clampf(v, 0.0, 1.0) * 0.6)
	claw_tip = Color("#3a3a40")
	mist_mat = StandardMaterial3D.new()
	mist_mat.vertex_color_use_as_albedo = true
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bone_mat = material.duplicate()
	bone_mat.albedo_texture = load("res://assets/cast/bark_detail_gray.png")


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "HollowHound"
	kind = variant
	match variant:
		"shuck":
			_eyes(Color("#6aff3a")); glow.emission_energy_multiplier = 2.4
			o = {"sh": 1.0, "hp": 0.9, "chest": 0.22, "waist": 0.14, "hipr": 0.15, "neck": 0.15, "head": 1.3, "muzzle": 0.28, "ear": 0.1, "round_ears": false, "tail": 0.7, "leg": 1.2, "bulk": 1.15}
			return _shuck()
		"thylacine":
			_eyes(Color("#5ab8ff")); glow.emission_energy_multiplier = 1.8
			o = {"sh": 0.74, "hp": 0.77, "chest": 0.17, "waist": 0.12, "hipr": 0.15, "neck": 0.12, "head": 1.25, "muzzle": 0.27, "ear": 0.085, "round_ears": false, "tail": 0.6, "leg": 1.05, "bulk": 1.0}
			return _thylacine()
		"shadow":
			_eyes(Color("#eef4ff")); glow.emission_energy_multiplier = 2.6
			o = {"sh": 0.92, "hp": 0.82, "chest": 0.2, "waist": 0.13, "hipr": 0.14, "neck": 0.13, "head": 1.15, "muzzle": 0.25, "ear": 0.13, "round_ears": false, "tail": 0.65, "leg": 1.15, "bulk": 1.05}
			return _shadow()
	return null


# ------------------------------------------------------------------ painters

## Shaggy black fur, wiry and rusty-brown at the tips like a wolfhound's.
static func shuck_fur(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0e0e10").lerp(Color("#2c2a2c"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(Vector3(p.x * 14.0, p.y * 14.0, p.z * 6.0)) * 0.5, 0.0, 1.0))
	return c.lerp(Color("#4a3a32"), smoothstep(0.7, 1.0, v) * 0.35)


## A thylacine's coat, gone ghost-pale: ash-fawn above, pale below, with dark bands across the
## back and rump and a pale mask round the eyes.
static func thyla_coat(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#1e2026").lerp(Color("#5a5e68"), clampf(-n.y * 0.5 + 0.2 + Sculpt.fbm(p * 9.0) * 0.3, 0.0, 1.0))
	var back := smoothstep(-0.55, 0.0, n.y) * smoothstep(-0.2, -0.02, p.z)
	var band := smoothstep(0.45, 0.7, sin(p.z * 70.0 + Sculpt.noise(p * 7.0) * 0.8 + absf(p.x) * 4.0))
	return c.lerp(Color("#0a0a0e"), band * back * 0.6)


## Smoke: dark, half see-through, thinning towards its tips.
static func smoke(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#1a1a20").lerp(Color("#56586a"), clampf(n.y * 0.4 + 0.3 + Sculpt.noise(p * 8.0) * 0.3, 0.0, 1.0))
	return Color(c.r, c.g, c.b, clampf(0.55 - v * 0.45 + Sculpt.noise(p * 11.0) * 0.12, 0.0, 1.0))


## Breath fog: pale and faint.
static func fog(_p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return Color(0.86, 0.9, 0.96, clampf(0.14 + 0.08 * n.y - v * 0.1, 0.0, 1.0))


## A shadow body: near-black and half see-through, thicker in some places than others.
static func shade(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#08080c").lerp(Color("#2a2c3a"), clampf(n.y * 0.35 + 0.25 + Sculpt.fbm(p * 6.0) * 0.35, 0.0, 1.0))
	return Color(c.r, c.g, c.b, clampf(0.45 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))


# ------------------------------------------------------------------ shared pieces

## Smoke curling up round each paw instead of a clean footfall, and fog on its breath.
func smoke_and_fog(parts: Dictionary, paw_smoke := 1.0) -> void:
	var hk: float = o.head
	for knee: Node3D in parts.knees:
		var kw := _world(knee)
		var at := Vector3(kw.x, 0.06, kw.z - 0.04)
		var ss := Sculpt.new(); var sp := ss.add_painter(smoke)
		for k in range(6):
			var a := TAU * k / 6.0 + kw.z * 7.0
			ss.blob(at + Vector3(cos(a) * 0.06, 0.02 + 0.025 * (k % 3), sin(a) * 0.06) * paw_smoke, Vector3(0.07, 0.045, 0.07) * paw_smoke * (0.8 + 0.3 * (k % 2)), sp, {"lat": 5, "lon": 8, "lump": 0.5})
		for k in range(2):
			tongue_of_fire(ss, sp, at + Vector3(0.03 * (k * 2 - 1), 0.04, 0.0), Vector3(0.3 * (k * 2 - 1), 1.0, 0.4), 0.2 * paw_smoke, 0.04 * paw_smoke, k + kw.x * 10.0)
		part(knee, "Smoke", ss, mist_mat)
	# Breath fog in front of the muzzle, on the head so it moves with it.
	var fs := Sculpt.new(); var fp := fs.add_painter(fog)
	var tip := Vector3(0, float(o.sh) + 0.14 - 0.05 * hk, -0.62 - 0.06 * hk - float(o.muzzle))
	for k in range(5):
		fs.blob(tip + Vector3(0.03 * sin(k * 2.3), -0.01 + 0.015 * k, -0.04 - 0.04 * k), Vector3(0.035, 0.025, 0.04) * (1.0 + 0.3 * k), fp, {"lat": 5, "lon": 8, "lump": 0.5})
	part(parts.head, "BreathFog", fs, mist_mat)


## Bigger glowing eyes, set into the brows.
func saucer_eyes(parts: Dictionary, size: float) -> void:
	var es: Sculpt = parts.core_sculpt
	var hk: float = o.head; var hy: float = float(o.sh) + 0.14
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.057 * side * hk, hy + 0.02 * hk, -0.62 - 0.092 * hk), Vector3(size, size * 0.8, size * 0.5) * hk, 0, {"lat": 5, "lon": 8})


# ------------------------------------------------------------------ A: black shuck

func _shuck() -> Node3D:
	var parts := canid(shuck_fur, false)
	var sh: float = o.sh; var hk: float = o.head; var hp: float = o.hp
	var hy := sh + 0.14; var hz := -0.62
	saucer_eyes(parts, 0.034)
	# A shaggy, wiry coat all over: long ragged locks hanging off the back, flanks and belly.
	var cs := Sculpt.new(); var cp := cs.add_painter(shuck_fur)
	for k in range(170):
		var z := lerpf(-0.46, 0.44, fposmod(k * 0.7548777, 1.0))
		var a := lerpf(-2.6, 2.6, fposmod(k * 0.5698403, 1.0))
		var pt: Array = hide_point(z, a, 0.96)
		var n: Vector3 = pt[1]
		shag(cs, cp, pt[0], (n * 0.45 + Vector3(0, -0.5, 0.55)).normalized(), 0.13 + 0.06 * absf(sin(a)), 0.03, 0.4)
	# A ragged ruff down the neck and throat.
	for k in range(40):
		var t := fposmod(k * 0.618, 1.0); var a := lerpf(-2.4, 2.4, fposmod(k * 0.37, 1.0))
		var c := Vector3(0, lerpf(sh - 0.06, sh + 0.12, t), lerpf(-0.38, -0.58, t))
		var at := c + Vector3(sin(a) * 0.13, cos(a) * 0.12, 0)
		shag(cs, cp, at, Vector3(sin(a) * 0.6, cos(a) * 0.4 - 0.3, 0.6), 0.14, 0.03, 0.4)
	part(root, "Shag", cs)
	# The wolfhound's wiry beard and eyebrows.
	var hs: Sculpt = parts.head_sculpt; var hpn: int = parts.head_painter
	var hc := hs.add_painter(shuck_fur)
	var mz: float = o.muzzle
	for k in range(14):
		var t := k / 13.0
		var side := -1.0 if k % 2 == 0 else 1.0
		var at := Vector3(0.04 * side * hk, hy - 0.05 * hk, hz - 0.06 * hk - mz * lerpf(0.2, 0.95, t))
		shag(hs, hc, at, Vector3(0.2 * side, -1.0, -0.15), 0.07 + 0.03 * (1.0 - t), 0.018, 0.1)
	for side: float in [-1.0, 1.0]:
		for k in range(4):
			shag(hs, hc, Vector3((0.03 + 0.012 * k) * side * hk, hy + 0.05 * hk, hz - 0.08 * hk), Vector3(0.3 * side, 0.5, -1.0), 0.07, 0.012, 0.15)
	# Its long tail is shaggy too.
	var ts: Sculpt = parts.tail_sculpts[0]; var tcp := ts.add_painter(shuck_fur)
	var tl: float = o.tail
	for k in range(16):
		var t := k / 15.0
		var at := Vector3(0, hp - 0.02 - t * (0.25 + tl * 0.5), 0.46 + t * tl * 0.72)
		shag(ts, tcp, at, Vector3(0.5 * sin(k * 2.0), -1.0, 0.4), 0.12, 0.025, 0.2)
	# An iron collar with a length of broken chain still hanging from it.
	var irons := Sculpt.new(); var ip := irons.add_painter(iron)
	var cc := Vector3(0, sh + 0.04, -0.5)
	spiked_collar(irons, ip, cc, Vector3(0, 0.5, -1), 0.16)
	var link := cc + Vector3(0, -0.17, -0.06)
	for k in range(7):
		var d := Vector3(0.03 * sin(k * 1.3), -0.06, 0.012)
		var ring: Array = []; var rr: Array = []
		var u := Vector3.RIGHT if k % 2 == 0 else Vector3.BACK
		for j in range(9):
			var a := TAU * j / 8.0
			ring.append(link + u * cos(a) * 0.022 + Vector3(0, sin(a) * 0.036, 0)); rr.append(0.008)
		irons.tube(ring, rr, ip, {"sides": 5, "per": 1})
		link += d
	part(root, "Collar", irons, iron_mat)
	smoke_and_fog(parts, 1.3)
	return _snarl(_close(parts, 1.5))


# ------------------------------------------------------------------ B: thylacine

func _thylacine() -> Node3D:
	var parts := canid(thyla_coat, false)
	var hp: float = o.hp; var hk: float = o.head; var sh: float = o.sh
	saucer_eyes(parts, 0.02)
	# The thylacine's tail: stiff and thick at the root, tapering straight out behind.
	var ts := Sculpt.new(); var tp := ts.add_painter(thyla_coat)
	ts.tube([Vector3(0, hp - 0.03, 0.4), Vector3(0, hp - 0.06, 0.56), Vector3(0, hp - 0.12, 0.76), Vector3(0, hp - 0.2, 0.98)], [0.09, 0.065, 0.04, 0.012], tp, {"sides": 11, "per": 3, "cap1": false})
	parts["tail_sculpts"] = [ts]
	# Pale fur round the eyes, and short whiskers.
	var hs: Sculpt = parts.head_sculpt
	var mask := hs.add_painter(func (p, n, v, w): return Color("#c8c2b4"))
	var hy := sh + 0.14; var hz := -0.62
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.058 * side * hk, hy + 0.012 * hk, hz - 0.084 * hk), Vector3(0.034, 0.026, 0.016) * hk, mask, {"lat": 5, "lon": 8, "basis": Basis(Vector3.BACK, -0.3 * side)})
	# Its stripes glow with ghost-light, like ribs showing through a shadow.
	var gs := Sculpt.new(); var gp := gs.add_painter(func (p, n, v, w): return Color.WHITE)
	for k in range(15):
		var z := lerpf(-0.14, 0.43, k / 14.0)
		var pts: Array = []; var rr: Array = []
		var span := 1.5 + 0.5 * sin(PI * k / 14.0)
		for j in range(9):
			var t := j / 8.0
			var hpnt: Array = hide_point(z + 0.012 * sin(t * 9.0 + k), lerpf(-span, span, t), 1.012)
			pts.append(hpnt[0]); rr.append(0.011 * sin(PI * (0.06 + 0.88 * t)) + 0.002)
		gs.tube(pts, rr, gp, {"sides": 4, "per": 2, "cap_rings": 1, "flat": 0.5})
	var tgs := Sculpt.new(); var tgp := tgs.add_painter(func (p, n, v, w): return Color.WHITE)
	for k in range(4):
		var c := Vector3(0, hp - 0.05 - k * 0.025, 0.5 + k * 0.08)
		var r := 0.085 - k * 0.012
		var ring: Array = []; var rr2: Array = []
		for j in range(7):
			var a := lerpf(-1.6, 1.6, j / 6.0)
			ring.append(c + Vector3(sin(a) * r, cos(a) * r, 0)); rr2.append(0.008)
		tgs.tube(ring, rr2, tgp, {"sides": 4, "per": 2, "cap_rings": 1})
	part(root, "GhostStripes", gs, glow).material_override = glow
	# Ghost-mist trailing off its back.
	var ws := Sculpt.new(); var wp := ws.add_painter(fog)
	for k in range(8):
		var t := k / 7.0
		var b: Array = body_at(lerpf(-0.36, 0.4, t))
		ws.blob((b[0] as Vector3) + Vector3(0.05 * sin(k * 2.1), float(b[1]) * 0.85, 0.06 * t), Vector3(0.08, 0.05, 0.12) * (0.8 + t * 0.6), wp, {"lat": 5, "lon": 8, "lump": 0.6})
	part(root, "Mist", ws, mist_mat)
	smoke_and_fog(parts, 1.0)
	part(parts.tails[0], "GhostStripes", tgs, glow).material_override = glow
	var node := _close(parts, 1.6)
	# The thylacine's famous gape: its jaws hang open far wider than a dog's.
	var j := node.find_child("Jaw", true, false)
	if j != null:
		for m in j.get_children():
			if m is MeshInstance3D: (m as MeshInstance3D).rotation.x = -0.62
	return node


# ------------------------------------------------------------------ C: shadow wolf

func _shadow() -> Node3D:
	material = material.duplicate()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = null
	var parts := canid(shade, false)
	var sh: float = o.sh; var hk: float = o.head; var hp: float = o.hp
	saucer_eyes(parts, 0.018)
	# The skeleton showing dimly through the shadow: skull, ribs, spine, pelvis and leg bones.
	var hy := sh + 0.14; var hz := -0.62
	var skull := head_sculpts(bone_c, hy - 0.005, hz + 0.005, hk * 0.86)
	part(parts.head, "Skull", skull.hs, bone_mat)
	part(parts.jaw, "Mandible", skull.js, bone_mat)
	var rs := Sculpt.new(); var rp := rs.add_painter(bone_c)
	for side: float in [-1.0, 1.0]:
		for k in range(8):
			var z := lerpf(-0.3, 0.14, k / 7.0)
			var pts: Array = []; var rr: Array = []
			for j in range(6):
				var hpnt: Array = hide_point(z + j * 0.016, side * lerpf(0.2, 2.5, j / 5.0), 0.86)
				pts.append(hpnt[0]); rr.append(0.014 - j * 0.0014)
			rs.tube(pts, rr, rp, {"sides": 5, "per": 2, "cap_rings": 1})
		rs.blob(Vector3(0.07 * side, hp - 0.02, 0.32), Vector3(0.05, 0.03, 0.09), rp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, 0.4 * side)})
		rs.tube([Vector3(0.1 * side, sh - 0.02, -0.36), Vector3(0.12 * side, sh - 0.2, -0.28)], [0.025, 0.012], rp, {"sides": 5, "per": 2, "flat": 0.4, "side": Vector3.RIGHT})
	for k in range(18):
		var z := lerpf(-0.56, 0.44, k / 17.0)
		var at: Vector3
		if z < -0.44: at = Vector3(0, sh + (-0.44 - z) * 0.6, z)
		else:
			var b: Array = body_at(z)
			at = (b[0] as Vector3) + Vector3(0, float(b[1]) * 0.75, 0)
		rs.blob(at, Vector3(0.026, 0.022, 0.024), rp, {"lat": 4, "lon": 6})
		if z > -0.44: rs.crystal(at, Vector3(0, 1, 0.4), 0.05, 0.012, rp, 4)
	part(root, "Bones", rs, bone_mat)
	for i in range(parts.hips.size()):
		var hip: Node3D = parts.hips[i]; var knee: Node3D = parts.knees[i]
		var top := _world(hip); var kn := _world(knee)
		var us := Sculpt.new(); var up := us.add_painter(bone_c)
		us.tube([top + Vector3(0, 0.06, 0), kn], [0.022, 0.016], up, {"sides": 6, "per": 2})
		us.blob(kn, Vector3.ONE * 0.022, up, {"lat": 4, "lon": 6})
		part(hip, "Bone", us, bone_mat)
		var ls := Sculpt.new(); var lp := ls.add_painter(bone_c)
		ls.tube([kn, Vector3(kn.x, 0.06, kn.z - 0.03)], [0.016, 0.012], lp, {"sides": 6, "per": 2})
		part(knee, "Bone", ls, bone_mat)
	# Smoke streaming off its back and tail like a guttering fire.
	var ss := Sculpt.new(); var sp := ss.add_painter(smoke)
	for k in range(14):
		var z := lerpf(-0.5, 0.42, k / 13.0)
		var at: Vector3
		if z < -0.44: at = Vector3(0, sh + 0.02 + (-0.44 - z) * 0.6, z)
		else:
			var b: Array = body_at(z)
			at = (b[0] as Vector3) + Vector3(0, float(b[1]) * 0.85, 0)
		tongue_of_fire(ss, sp, at, Vector3(0.3 * sin(k * 2.1), 0.7, 1.0), 0.22 + 0.08 * sin(k * 1.3), 0.05, k)
	part(root, "Smoke", ss, mist_mat)
	var tsm := Sculpt.new(); var tsp := tsm.add_painter(smoke)
	var tip: Vector3 = parts.tail_tip
	for k in range(4): tongue_of_fire(tsm, tsp, tip + Vector3(0.02 * sin(k * 2.0), 0.03 * k, -0.05 * k), Vector3(0.3 * sin(k * 2.7), 0.5, 1.0), 0.25, 0.05, k)
	part(parts.tails[0], "Smoke", tsm, mist_mat)
	smoke_and_fog(parts, 1.4)
	return _snarl(_close(parts, 1.5))
