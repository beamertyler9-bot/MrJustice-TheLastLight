extends "res://tools/sculpt_thistle_jackal.gd"
## The Furnace Hound of the Ashfall Caldera, sculpted by hand: a hunting dog of the volcano,
## its hide charred black and cracked over the fire inside it, smoke leaking from its mouth and
## its paws glowing white-hot before it rushes. Three designs, each built on a real animal:
##   hyena   - a spotted hyena: a sloping back (tall at the shoulder, low at the hips), a
##             huge head with bone-crushing jaws, round ears, a bristling mane and a short bushy
##             tail; its spots are glowing embers
##   mastiff - a war mastiff: a massive chest and head, short muzzle, heavy dewlap, a spiked
##             iron collar, an iron furnace door set in its chest and chimneys on its shoulders
##   wolf    - a grey wolf: long-legged and deep-chested, a thick ruff of ash-grey fur tipped
##             with embers, a long bushy tail and lava running in the cracks of its legs

const CHAR := Color("#1d1a19")
const CHAR_LIGHT := Color("#4a4441")
const EMBER := Color("#ff6a1a")

var kind := "hyena"
var ember_mat: StandardMaterial3D
var iron_mat: StandardMaterial3D
var o: Dictionary = {}


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/fur_detail_gray.png")
	ember_mat = StandardMaterial3D.new()
	ember_mat.vertex_color_use_as_albedo = true
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	iron_mat = StandardMaterial3D.new()
	iron_mat.vertex_color_use_as_albedo = true
	iron_mat.metallic = 0.7; iron_mat.roughness = 0.45


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "FurnaceHound"
	kind = variant
	_eyes(Color("#ffb347"))
	match variant:
		"hyena":
			o = {"sh": 0.86, "hp": 0.64, "chest": 0.2, "waist": 0.15, "hipr": 0.15, "neck": 0.14, "head": 1.25, "muzzle": 0.2, "ear": 0.09, "round_ears": true, "tail": 0.32, "leg": 1.3, "bulk": 1.15}
			return _hyena()
		"mastiff":
			o = {"sh": 0.8, "hp": 0.76, "chest": 0.26, "waist": 0.2, "hipr": 0.19, "neck": 0.17, "head": 1.4, "muzzle": 0.13, "ear": 0.07, "round_ears": true, "tail": 0.35, "leg": 1.55, "bulk": 1.4}
			return _mastiff()
		"wolf":
			o = {"sh": 0.82, "hp": 0.78, "chest": 0.19, "waist": 0.13, "hipr": 0.14, "neck": 0.12, "head": 1.1, "muzzle": 0.24, "ear": 0.12, "round_ears": false, "tail": 0.6, "leg": 1.15, "bulk": 1.05}
			return _wolf()
	return null


# ------------------------------------------------------------------ painters

## Charred hide: black, cracked into plates like burnt wood, ash-grey on the edges.
static func char_hide(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := CHAR.lerp(CHAR_LIGHT, clampf(n.y * 0.25 + 0.15 + Sculpt.fbm(p * 7.0) * 0.4, 0.0, 1.0))
	# Charred into plates like burnt wood: deep black cracks, the plates' edges ashy.
	var crack := absf(Sculpt.noise(p * Vector3(14.0, 8.0, 14.0)))
	c = c.lerp(Color("#6e6460"), smoothstep(0.08, 0.16, crack) * smoothstep(0.3, 0.16, crack) * 0.55)
	c = c.lerp(Color("#050404"), smoothstep(0.08, 0.02, crack))
	return c.lerp(Color("#3a1408"), smoothstep(0.5, 0.75, Sculpt.noise(p * 5.0)) * 0.35)


## Ash fur: grey, darker at the roots, flecked with soot.
static func ash_fur(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#5a5450").lerp(Color("#a39b95"), clampf(n.y * 0.35 + 0.35 + Sculpt.fbm(Vector3(p.x * 12.0, p.y * 12.0, p.z * 5.0)) * 0.5, 0.0, 1.0))
	return c.darkened(smoothstep(0.55, 0.7, Sculpt.noise(p * 30.0)) * 0.4)


## A tuft of fur that goes from the coat colour at the root to a glowing ember at the tip.
static func ember_tip(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	return ash_fur(p, n, v, w).darkened(0.2).lerp(Color("#ff8a2a"), smoothstep(0.75, 1.0, v))


static func ember(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color("#ffd27a").lerp(EMBER, clampf(v, 0.0, 1.0) * 0.6)


# ------------------------------------------------------------------ the dog

## The body centre-line and radius at length z (front -z), for placing things on the hide.
func body_at(z: float) -> Array:
	var sh: float = o.sh; var hp: float = o.hp
	var zs := [-0.44, -0.26, 0.02, 0.26, 0.44]
	var ys := [sh - 0.12, sh - 0.06, lerpf(sh, hp, 0.5) - 0.08, hp - 0.03, hp - 0.07]
	var rs := [float(o.chest) * 0.85, float(o.chest), float(o.waist), float(o.hipr), float(o.hipr) * 0.8]
	var k := 0
	while k < 3 and z > float(zs[k + 1]): k += 1
	var t := clampf((z - float(zs[k])) / (float(zs[k + 1]) - float(zs[k])), 0.0, 1.0)
	return [Vector3(0, lerpf(ys[k], ys[k + 1], t), z), lerpf(rs[k], rs[k + 1], t)]


## A point on the hide at length z and angle a round the body (0 on top), pushed out by `out`.
func hide_point(z: float, a: float, out := 1.0) -> Array:
	var b: Array = body_at(z)
	var dir := Vector3(sin(a) * 0.82, cos(a), 0)
	# The shoulder and haunch muscles bulge out of the body tube; ride over them.
	var bulge := (0.45 * exp(-pow((z + 0.3) / 0.13, 2.0)) + 0.4 * exp(-pow((z - 0.34) / 0.13, 2.0))) * absf(sin(a)) * float(o.bulk)
	return [(b[0] as Vector3) + dir * float(b[1]) * (out + bulge), Vector3(sin(a), cos(a), 0)]



## The head's sculpts at (hy, hz) and size hk: skull, jaw, throat fire and eyes.
func head_sculpts(skin: Callable, hy: float, hz: float, hk: float) -> Dictionary:
	var hs := Sculpt.new(); var hpn := hs.add_painter(skin)
	var nose := hs.add_painter(func (p, n, v, w): return Color("#0c0a0a").lightened(clampf(n.y, 0.0, 1.0) * 0.25))
	var fang := hs.add_painter(func (p, n, v, w): return Color("#efe4c8").darkened((1.0 - v) * 0.35))
	var sock := hs.add_painter(func (p, n, v, w): return Color("#120706"))
	var lip := hs.add_painter(func (p, n, v, w): return Color("#1a0e0c"))
	var mz: float = o.muzzle
	hs.blob(Vector3(0, hy, hz), Vector3(0.105, 0.088, 0.11) * hk, hpn, {"lat": 10, "lon": 14})
	var m0 := Vector3(0, hy - 0.012 * hk, hz - 0.06 * hk)
	var tip := Vector3(0, hy - 0.04 * hk, hz - 0.06 * hk - mz)
	hs.tube([m0, m0.lerp(tip, 0.5) + Vector3(0, 0.004, 0), tip], [0.07 * hk, 0.054 * hk, 0.036 * hk], hpn, {"sides": 14, "per": 3, "square": 0.12, "cap0": false, "cap_len": 0.55})
	hs.blob(tip + Vector3(0, 0.01 * hk, -0.03 * hk), Vector3(0.034, 0.026, 0.024) * hk, nose, {"lat": 5, "lon": 8})
	for side: float in [-1.0, 1.0]:
		# Brows, eye sockets, cheeks, the dark lip line and a row of teeth with long fangs.
		hs.blob(Vector3(0.05 * side * hk, hy + 0.045 * hk, hz - 0.075 * hk), Vector3(0.04, 0.016, 0.03) * hk, hpn, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, -0.35 * side)})
		hs.blob(Vector3(0.056 * side * hk, hy + 0.02 * hk, hz - 0.085 * hk), Vector3(0.026, 0.017, 0.014) * hk, sock, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, -0.3 * side)})
		hs.blob(Vector3(0.07 * side * hk, hy - 0.035 * hk, hz - 0.05 * hk), Vector3(0.05, 0.045, 0.06) * hk, hpn, {"lat": 6, "lon": 8})
		hs.tube([Vector3(0.055 * side * hk, hy - 0.06 * hk, hz - 0.04 * hk), tip + Vector3(0.025 * side * hk, -0.03 * hk, 0.03 * hk)], [0.012 * hk, 0.008 * hk], lip, {"sides": 5, "per": 1})
		hs.crystal(tip + Vector3(0.026 * side * hk, -0.03 * hk, 0.05 * hk), Vector3(0, -1, -0.08), 0.05 * hk, 0.01 * hk, fang, 5)
		for k in range(4):
			var at := tip.lerp(Vector3(0.05 * side * hk, hy - 0.06 * hk, hz - 0.05 * hk), 0.25 + k * 0.17) + Vector3(0.02 * side * hk, -0.03 * hk, 0)
			hs.crystal(at, Vector3(0, -1, 0), 0.022 * hk, 0.008 * hk, fang, 4)
	var js := Sculpt.new(); var jp := js.add_painter(skin)
	var jf := js.add_painter(func (p, n, v, w): return Color("#efe4c8").darkened((1.0 - v) * 0.35))
	var tongue := js.add_painter(func (p, n, v, w): return Color("#5a1a14").lerp(Color("#b04020"), v))
	var jtip := Vector3(0, hy - 0.085 * hk, tip.z + 0.025 * hk)
	js.tube([Vector3(0, hy - 0.07 * hk, hz - 0.02), jtip], [0.058 * hk, 0.03 * hk], jp, {"sides": 10, "per": 2, "square": 0.25, "cap_len": 0.5})
	js.tube([Vector3(0, hy - 0.06 * hk, hz - 0.06 * hk), jtip + Vector3(0, 0.022 * hk, 0.02 * hk)], [0.025 * hk, 0.018 * hk], tongue, {"sides": 7, "per": 2, "flat": 1.6})
	for side: float in [-1.0, 1.0]:
		js.crystal(jtip + Vector3(0.02 * side * hk, 0.02 * hk, 0.02 * hk), Vector3(0, 1, -0.1), 0.04 * hk, 0.009 * hk, jf, 5)
		for k in range(3):
			var at := jtip.lerp(Vector3(0.04 * side * hk, hy - 0.07 * hk, hz - 0.03), 0.25 + k * 0.2) + Vector3(0.012 * side * hk, 0.025 * hk, 0)
			js.crystal(at, Vector3(0, 1, 0), 0.02 * hk, 0.007 * hk, jf, 4)
	# The fire of its throat, glowing between the jaws.
	var fs := Sculpt.new(); var fp := fs.add_painter(ember)
	fs.blob(Vector3(0, hy - 0.05 * hk, (hz + tip.z) * 0.5 + 0.03), Vector3(0.035 * hk, 0.03 * hk, mz * 0.4), fp, {"lat": 5, "lon": 8})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.057 * side * hk, hy + 0.02 * hk, hz - 0.093 * hk), Vector3(0.022, 0.011, 0.008) * hk, white, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, -0.3 * side)})
	return {"hs": hs, "hpn": hpn, "js": js, "fs": fs, "es": es, "jaw_at": Vector3(0, hy - 0.055 * hk, hz - 0.02)}

## Builds the dog on the jackal's rig parts (see _close in the jackal sculpt).
func canid(skin: Callable, glow_paws: bool) -> Dictionary:
	var sh: float = o.sh; var hp: float = o.hp; var hk: float = o.head; var bulk: float = o.bulk
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	var zs := [-0.44, -0.26, 0.02, 0.26, 0.44]
	var pts: Array = []; var rs: Array = []
	for z in zs:
		var b: Array = body_at(z)
		pts.append(b[0]); rs.append(b[1])
	body.tube(pts, rs, bp, {"sides": 24, "per": 6, "flat": 0.82, "lump": 0.04})
	body.blob(Vector3(0, sh - 0.22, -0.3), Vector3(0.13, 0.19, 0.16) * bulk, bp, {"lat": 9, "lon": 12})
	for side: float in [-1.0, 1.0]:
		body.blob(Vector3(0.09 * side, sh - 0.12, -0.3), Vector3(0.08, 0.15, 0.13) * bulk, bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.08 * side, hp - 0.06, 0.34), Vector3(0.08, 0.13, 0.13) * (0.6 + 0.4 * bulk), bp, {"lat": 7, "lon": 10})
	body.tube([Vector3(0, sh - 0.06, -0.38), Vector3(0, sh + 0.04, -0.5), Vector3(0, sh + 0.12, -0.58)], [float(o.neck) * 1.1, o.neck, float(o.neck) * 0.85], bp, {"sides": 13, "per": 3})
	var parts := {"body": body, "body_painter": bp, "lift": 0.0}

	# The head: a broad skull with a clear stop above the eyes, heavy brows, muscular cheeks, a
	# tapering muzzle with a big nose pad, and a snarling open jaw full of teeth with the fire of
	# its throat showing inside.
	var hy := sh + 0.14; var hz := -0.62
	var hd := head_sculpts(skin, hy, hz, hk)
	var head := joint(root, "Head", Vector3(0, sh + 0.12, -0.58))
	parts["head"] = head; parts["head_sculpt"] = hd.hs; parts["head_painter"] = hd.hpn
	var jaw := joint(head, "Jaw", hd.jaw_at)
	parts["jaw"] = jaw; parts["jaw_sculpt"] = hd.js
	part(head, "ThroatFire", hd.fs, ember_mat)
	var es: Sculpt = hd.es
	parts["core_sculpt"] = es
	var ears: Array = []; var ear_sculpts: Array = []
	var er: float = o.ear
	for side: float in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.06 * side * hk, hy + 0.07 * hk, hz + 0.02))
		var xs := Sculpt.new(); var xb := xs.add_painter(skin); var xi := xs.add_painter(func (p, n, v, w): return Color("#3a2a26"))
		var base := Vector3(0.06 * side * hk, hy + 0.06 * hk, hz + 0.02)
		if o.round_ears:
			xs.blob(base + Vector3(0.02 * side, er * 0.6, 0.0), Vector3(er * 0.55, er * 0.7, er * 0.18), xb, {"lat": 6, "lon": 9, "basis": Basis(Vector3.BACK, -0.35 * side)})
			xs.blob(base + Vector3(0.02 * side, er * 0.6, -0.012), Vector3(er * 0.4, er * 0.55, er * 0.1), xi, {"lat": 5, "lon": 8, "basis": Basis(Vector3.BACK, -0.35 * side)})
		else:
			xs.tube([base, base + Vector3(0.025 * side, er * 0.6, 0.0), base + Vector3(0.04 * side, er * 1.2, 0.01)], [er * 0.45, er * 0.3, 0.004], xb, {"sides": 8, "per": 2, "flat": 0.4, "side": Vector3.BACK, "cap1": false})
		ears.append(ear); ear_sculpts.append(xs)
	parts["ears"] = ears; parts["ear_sculpts"] = ear_sculpts

	# Legs: a dog's leg (upright forelegs, angled hind legs with a high hock), standing on its
	# toes; the paw pads and claws glow white-hot.
	var L: float = o.leg
	var hips: Array = []; var knees: Array = []
	var glow_s := Sculpt.new(); var gp := glow_s.add_painter(ember)
	for row in [["Front", -0.3, true], ["Hind", 0.36, false]]:
		for side: float in [-1.0, 1.0]:
			var front: bool = row[2]; var z: float = row[1]
			var x := 0.11 * side * (0.8 + 0.2 * bulk)
			var top := Vector3(x, (sh - 0.18) if front else (hp - 0.1), z)
			var hip := joint(root, str(row[0]) + ("Left" if side < 0 else "Right") + "Leg", top)
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at := Vector3(x * 1.05, top.y * 0.5, z - 0.01) if front else Vector3(x * 1.05, top.y * 0.58, z - 0.1)
			us.tube([top + Vector3(0, 0.1, 0.02), top.lerp(knee_at, 0.5), knee_at], [0.1 * L, 0.075 * L, 0.05 * L] if front else [0.13 * L, 0.095 * L, 0.055 * L], up, {"sides": 11, "per": 3})
			part(hip, "Upper", us)
			var knee := joint(hip, "Elbow" if front else "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cp := ls.add_painter(func (p, n, v, w): return Color("#2a1a12").lerp(Color("#ffb060"), v))
			var paw := Vector3(x * 1.05, 0.04, z - 0.04)
			if front:
				ls.tube([knee_at, Vector3(x * 1.05, 0.14, z - 0.01), paw + Vector3(0, 0.03, 0.02)], [0.048 * L, 0.04 * L, 0.04 * L], lp, {"sides": 10, "per": 3})
			else:
				var hock := Vector3(x * 1.05, 0.25, z + 0.06)
				ls.tube([knee_at, hock, paw + Vector3(0, 0.03, 0.02)], [0.052 * L, 0.04 * L, 0.04 * L], lp, {"sides": 10, "per": 3})
				ls.blob(hock + Vector3(0, 0, 0.015), Vector3(0.035, 0.04, 0.035) * L, lp, {"lat": 5, "lon": 7})
			ls.blob(paw, Vector3(0.05, 0.034, 0.06) * L, lp, {"lat": 6, "lon": 9})
			for c in range(4):
				var toe := paw + Vector3((c - 1.5) * 0.024 * L, -0.006, -0.05 * L + absf(c - 1.5) * 0.01)
				ls.blob(toe, Vector3(0.018, 0.022, 0.022) * L, lp, {"lat": 4, "lon": 6})
				ls.tube([toe + Vector3(0, 0.0, -0.015), toe + Vector3(0, -0.012, -0.035 * L), toe + Vector3(0, -0.03, -0.04 * L)], [0.008 * L, 0.006 * L, 0.001], cp, {"sides": 5, "per": 2, "cap1": false})
			part(knee, "Lower", ls)
			if glow_paws:
				# Glowing cracks over the paw and a glowing pad under each toe.
				var gs := Sculpt.new(); var gpp := gs.add_painter(ember)
				for c in range(4):
					var toe := paw + Vector3((c - 1.5) * 0.024 * L, -0.02, -0.05 * L + absf(c - 1.5) * 0.01)
					gs.blob(toe, Vector3(0.014, 0.008, 0.016) * L, gpp, {"lat": 3, "lon": 6})
				gs.tube([paw + Vector3(-0.03, 0.03, -0.02) * L, paw + Vector3(0.0, 0.05, 0.0) * L, paw + Vector3(0.02, 0.09, 0.02) * L, knee_at.lerp(paw, 0.5) + Vector3(0.035 * side, 0, 0)], [0.006, 0.008, 0.007, 0.003], gpp, {"sides": 4, "per": 2, "cap_rings": 1})
				part(knee, "HotPaw", gs, ember_mat)
			hips.append(hip); knees.append(knee)
	parts["hips"] = hips; parts["knees"] = knees

	var tail := joint(root, "Tail", Vector3(0, hp - 0.02, 0.46))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	var tl: float = o.tail
	ts.tube([Vector3(0, hp - 0.02, 0.44), Vector3(0, hp - 0.08, 0.46 + tl * 0.35), Vector3(0, hp - 0.2 - tl * 0.25, 0.46 + tl * 0.6), Vector3(0, hp - 0.25 - tl * 0.5, 0.46 + tl * 0.72)], [0.04, 0.065, 0.07, 0.035], tp, {"sides": 10, "per": 3, "lump": 0.3, "cap1": false})
	parts["tails"] = [tail]; parts["tail_sculpts"] = [ts]; parts["tail_tip"] = Vector3(0, hp - 0.25 - tl * 0.5, 0.46 + tl * 0.72)
	parts["fronds"] = []
	parts["glow_sculpt"] = glow_s
	return parts


## Opens the jaw a little at rest, so the hound always bares its teeth and its glowing throat.
func _snarl(node: Node3D) -> Node3D:
	var j := node.find_child("Jaw", true, false)
	if j != null:
		for m in j.get_children():
			if m is MeshInstance3D: (m as MeshInstance3D).rotation.x = -0.28
	return node


## Smoke curling from the corners of the mouth, on the jaw so it moves with it.
func mouth_smoke(parts: Dictionary) -> void:
	var hk: float = o.head; var sh: float = o.sh
	var ss := Sculpt.new(); var sp := ss.add_painter(func (p, n, v, w): return Color("#3c3836").lerp(Color("#8c8580"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0)))
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.05 * side * hk, sh + 0.06, -0.62 - 0.05 * hk - float(o.muzzle) * 0.5)
		for k in range(3):
			ss.blob(at + Vector3(0.03 * side * k, 0.04 * k, 0.05 * k), Vector3.ONE * (0.025 + 0.012 * k), sp, {"lat": 5, "lon": 7, "lump": 0.5})
	part(parts.jaw, "Smoke", ss)


## Embers spattered over the hide (on their own mesh, so they glow).
func ember_spots(count: int, size: float, seed_k: float) -> Sculpt:
	var s := Sculpt.new(); var p := s.add_painter(ember)
	for k in range(count):
		var z := lerpf(-0.2, 0.22, fposmod(k * 0.7548777 + seed_k, 1.0))
		var a := lerpf(-2.0, 2.0, fposmod(k * 0.5698403 + seed_k * 0.3, 1.0))
		var hpnt: Array = hide_point(z, a, 1.005)
		var n: Vector3 = hpnt[1]
		var sz := size * (0.6 + 0.6 * fposmod(k * 0.53, 1.0))
		s.blob(hpnt[0], Vector3(sz, sz * 0.35, sz), p, {"lat": 3, "lon": 6, "basis": Basis(n.cross(Vector3.BACK).normalized(), n, Vector3.BACK)})
	return s


## Cracks in the charred hide with the fire showing through, zig-zagging over the flanks.
func ember_seams(count: int, thick: float) -> Sculpt:
	var s := Sculpt.new(); var p := s.add_painter(ember)
	for k in range(count):
		var z0 := lerpf(-0.2, 0.12, fposmod(k * 0.7548777 + 0.2, 1.0))
		var a0 := (0.6 + 0.9 * fposmod(k * 0.5698403, 1.0)) * (1.0 if k % 2 == 0 else -1.0)
		var pts: Array = []; var r: Array = []
		for j in range(6):
			var t := j / 5.0
			var jag := 0.12 * (1.0 if j % 2 == 0 else -1.0)
			var hp_: Array = hide_point(z0 + 0.16 * t * (1.0 if k % 3 == 0 else -1.0), a0 + (0.7 * t + jag) * signf(a0), 1.01)
			pts.append(hp_[0]); r.append(thick * sin(PI * (0.12 + 0.76 * t)))
		s.tube(pts, r, p, {"sides": 4, "per": 2, "cap_rings": 1})
	return s


# ------------------------------------------------------------------ A: hyena

func _hyena() -> Node3D:
	var parts := canid(char_hide, true)
	# The spots of a spotted hyena, as glowing embers in the charred hide.
	part(root, "EmberSpots", ember_spots(40, 0.03, 0.1), ember_mat)
	part(root, "EmberCracks", ember_seams(6, 0.012), ember_mat)
	# A bristling mane from the crown down the neck and back, its tips smouldering.
	var ms := Sculpt.new(); var mp := ms.add_painter(ember_tip)
	for k in range(16):
		var z := lerpf(-0.56, 0.2, k / 15.0)
		var b: Array = body_at(maxf(z, -0.44))
		var top: Vector3 = (b[0] as Vector3) + Vector3(0, float(b[1]) * 0.92, 0)
		if z < -0.44: top = Vector3(0, o.sh + 0.04 + (-0.44 - z) * 0.6, z)
		var l := 0.13 * (1.0 - absf(k - 4.0) / 18.0)
		for side: float in [-1.0, 0.0, 1.0]:
			ms.tube([top + Vector3(0.02 * side, 0, 0), top + Vector3(0.04 * side, l * 0.7, l * 0.35), top + Vector3(0.05 * side, l, l * 0.7)], [0.018, 0.012, 0.002], mp, {"sides": 5, "per": 2, "cap1": false, "flat": 0.6})
	_frond(parts, root, "Mane", Vector3(0, o.sh, -0.2), ms)
	return _snarl(_close(parts, 1.35))


# ------------------------------------------------------------------ B: mastiff

func _mastiff() -> Node3D:
	var parts := canid(char_hide, true)
	var sh: float = o.sh; var hk: float = o.head
	var b: Sculpt = parts.body; var bp: int = parts.body_painter
	# Heavy jowls and a dewlap under the throat.
	(parts.head_sculpt as Sculpt).blob(Vector3(0, sh + 0.06, -0.72), Vector3(0.09, 0.05, 0.08) * hk, parts.head_painter, {"lat": 6, "lon": 9})
	b.blob(Vector3(0, sh - 0.04, -0.52), Vector3(0.1, 0.09, 0.1), bp, {"lat": 7, "lon": 10, "lump": 0.1})
	# An iron furnace door set in the chest, its grate glowing; a spiked iron collar.
	var iron := Sculpt.new(); var ip := iron.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#2e2a28").lerp(Color("#6b5a4a"), clampf(n.y * 0.3 + 0.3 + Sculpt.noise(p * 30.0) * 0.3, 0.0, 1.0)))
	var door := Vector3(0, sh - 0.2, -0.56)
	slab(iron, ip, door + Vector3(0, 0, 0.01), Vector3(0.2, 0.024, 0.24), Basis(Vector3.RIGHT, -PI * 0.5 + 0.35), 0.3, 0.0)
	for k in range(4):
		iron.tube([door + Vector3((k - 1.5) * 0.034, 0.08, -0.045), door + Vector3((k - 1.5) * 0.034, -0.08, -0.01)], [0.009, 0.009], ip, {"sides": 5, "per": 1, "cap_rings": 1})
	var ring: Array = []; var rr: Array = []
	for k in range(17):
		var a := TAU * k / 16.0
		ring.append(Vector3(sin(a) * 0.16, sh + 0.02 + cos(a) * 0.15, -0.48 - cos(a) * 0.04)); rr.append(0.028)
	iron.tube(ring, rr, ip, {"sides": 7, "per": 2})
	for k in range(10):
		var a := TAU * k / 10.0
		var out := Vector3(sin(a), cos(a), -0.3).normalized()
		iron.crystal(Vector3(sin(a) * 0.17, sh + 0.02 + cos(a) * 0.16, -0.48 - cos(a) * 0.04), out, 0.07, 0.016, ip, 4)
	# Chimneys on its shoulders, puffing smoke.
	var smoke := iron.add_painter(func (p, n, v, w): return Color("#3c3836").lerp(Color("#8c8580"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0)))
	for side: float in [-1.0, 1.0]:
		var base := Vector3(0.11 * side, sh + 0.08, -0.22)
		iron.tube([base, base + Vector3(0.03 * side, 0.14, 0.06)], [0.035, 0.03], ip, {"sides": 8, "per": 1, "cap_rings": 1})
		iron.tube([base + Vector3(0.03 * side, 0.13, 0.058), base + Vector3(0.032 * side, 0.15, 0.062)], [0.042, 0.04], ip, {"sides": 8, "per": 1, "cap1": false})
	part(root, "Iron", iron, iron_mat)
	var fire := Sculpt.new(); var fp := fire.add_painter(ember)
	for side: float in [-1.0, 1.0]: fire.blob(Vector3(0.11 * side, sh + 0.08, -0.22) + Vector3(0.031 * side, 0.135, 0.06), Vector3(0.03, 0.006, 0.03), fp, {"lat": 3, "lon": 7})
	fire.blob(door + Vector3(0, 0, -0.022), Vector3(0.075, 0.095, 0.012), fp, {"lat": 5, "lon": 8, "basis": Basis(Vector3.RIGHT, 0.35)})
	part(root, "Furnace", fire, ember_mat)
	part(root, "EmberSpots", ember_spots(12, 0.022, 0.4), ember_mat)
	part(root, "EmberCracks", ember_seams(10, 0.016), ember_mat)
	return _snarl(_close(parts, 1.3))


# ------------------------------------------------------------------ C: wolf

func _wolf() -> Node3D:
	var parts := canid(ash_fur, true)
	# A thick ruff of ash-grey fur round the neck and shoulders, its tips glowing like embers.
	var rs := Sculpt.new(); var rp := rs.add_painter(ember_tip)
	var spots: Array = []; var dirs: Array = []
	for k in range(70):
		var a := lerpf(-2.3, 2.3, fposmod(k * 0.5698403, 1.0))
		var z := lerpf(-0.56, -0.2, fposmod(k * 0.7548777, 1.0))
		var pt: Array = hide_point(maxf(z, -0.44), a, 0.95)
		var at: Vector3 = pt[0]
		if z < -0.44: at += Vector3(0, (-0.44 - z) * 0.7, z + 0.44)
		var n: Vector3 = pt[1]
		spots.append(at); dirs.append((n * 0.7 + Vector3(0, -0.15, 0.7)).normalized())
	tufts(rs, rp, spots, dirs, 0.13, 0.03)
	_frond(parts, root, "Ruff", Vector3(0, o.sh, -0.35), rs)
	# A bushy tail ending in a smouldering tip.
	var tip: Vector3 = parts.tail_tip
	var tts: Sculpt = parts.tail_sculpts[0]
	tts.tube([tip + Vector3(0, 0.04, -0.03), tip + Vector3(0, -0.05, 0.03)], [0.05, 0.01], tts.add_painter(ember_tip), {"sides": 8, "per": 2, "lump": 0.3})
	# Lava in the cracks running down its legs.
	part(root, "EmberCracks", ember_seams(8, 0.012), ember_mat)
	return _snarl(_close(parts, 1.35))
