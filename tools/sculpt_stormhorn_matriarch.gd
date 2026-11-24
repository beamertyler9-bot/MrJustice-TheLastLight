extends "res://tools/creature_kit.gd"
## The Stormhorn Matriarch, boss of the Windbell Plains, sculpted by hand: a huge plated grazing
## beast with storm-shaped horns that lowers its head and charges down a lane. Three designs,
## all built at about 1.4 m tall and scaled up to stand well over Mr. Justice:
##   bison - a shaggy storm bison with a great hump, slate plates down its back and jagged
##           lightning-bolt horns with glowing tips
##   rhino - an armoured thunder rhino whose heavy plates of hide are split by glowing seams of
##           lightning, with a bolt-shaped horn on its nose
##   muskox - a storm-cloud musk ox: a stone boss across its brow, hooked horns and a long skirt
##            of grey wool, pale on top and dark below like a rain cloud, streaked with lightning

const STORM := Color("#3fa9ff")
const HOOF := Color("#24201d")
const NOSE := Color("#1d1a19")
const MOUTH := Color("#3b1f22")

## Every tube or blob that should glow with storm light is added here, then baked with the glow
## material on the joint it belongs to.
var veins := {}


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(2.6, 2.6, 2.6)
	glow.albedo_color = Color("#2d7fd6"); glow.emission = STORM
	glow.emission_energy_multiplier = 1.25


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "StormhornMatriarch"
	veins = {}
	match variant:
		"bison": return _bison()
		"rhino": return _rhino()
		"muskox": return _muskox()
	return null


## The glowing sculpt that belongs to `parent` (made on first use).
func vein(parent: Node3D) -> Array:
	if not veins.has(parent):
		var s := Sculpt.new()
		veins[parent] = [s, s.add_painter(func (p, n, v, w): return Color.WHITE)]
	return veins[parent]


## A jagged lightning-bolt line from a to b: straight runs with sharp kinks to alternate sides.
func bolt_path(a: Vector3, b: Vector3, kinks: int, jitter: float, across: Vector3) -> Array:
	var path: Array = [a]
	for k in range(1, kinks + 1):
		var t := float(k) / (kinks + 1)
		var side := 1.0 if k % 2 == 1 else -1.0
		path.append(a.lerp(b, t) + across.normalized() * jitter * side * (1.0 - t * 0.4))
	path.append(b)
	return path


## A thin glowing crack of lightning along a surface.
func spark(parent: Node3D, a: Vector3, b: Vector3, kinks: int, jitter: float, across: Vector3, radius: float) -> void:
	var v := vein(parent)
	var path := bolt_path(a, b, kinks, jitter, across)
	var radii: Array = []
	for k in range(path.size()): radii.append(radius * (1.0 - 0.6 * float(k) / (path.size() - 1)))
	(v[0] as Sculpt).tube(path, radii, v[1], {"sides": 4, "per": 1, "cap_rings": 1})


## A storm horn: a thick curved horn that breaks into a jagged bolt toward its glowing tip.
## `points` is its curve from the skull outward.
func storm_horn(s: Sculpt, painter: int, parent: Node3D, points: Array, base_radius: float, jag: float, across: Vector3) -> void:
	var path: Array = []
	var radii: Array = []
	for k in range(points.size()):
		var t := float(k) / (points.size() - 1)
		var p: Vector3 = points[k]
		if k >= 2 and k < points.size() - 1: p += across.normalized() * jag * (1.0 if k % 2 == 0 else -1.0)
		path.append(p)
		radii.append(base_radius * pow(1.0 - t, 0.8) + 0.004)
	s.tube(path, radii, painter, {"sides": 9, "per": 1, "cap_rings": 1, "cap1": false, "lump": 0.05})
	# The last stretch glows, as if the horn were tipped with lightning.
	var v := vein(parent)
	var tail: Array = [path[-3], path[-2], path[-1]]
	var tr: Array = [radii[-3] * 1.12, radii[-2] * 1.18, 0.006]
	(v[0] as Sculpt).tube(tail, tr, v[1], {"sides": 9, "per": 1, "cap_rings": 1})


## A hanging lock of hair, flattened so it lies against the body.
func lock(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, thin: Vector3, droop := 0.2, sides := 6, per := 2, tip := 0.004) -> void:
	var d := dir.normalized()
	var sag := Vector3(0, -length * droop, 0)
	s.tube([base, base + d * length * 0.5 + sag * 0.3, base + d * length + sag], [width, width * 0.8, tip], painter,
		{"sides": sides, "per": per, "lump": 0.4, "cap_rings": 1, "cap1": false, "flat": 0.45, "side": thin})


## Four legs with cloven hooves. Rows are [label, hip z, front?]; `thick` scales their girth.
func legs(skin: Callable, width: float, front_z: float, hind_z: float, hip_y: float, thick: float, stocking := Callable()) -> Dictionary:
	# The upper legs always wear the coat; `stocking` (if given) colours the shins.
	var hips: Array = []; var knees: Array = []
	for row in [["Front", front_z, true], ["Hind", hind_z, false]]:
		for side in [-1.0, 1.0]:
			var front: bool = row[2]; var z: float = row[1]
			var x: float = width * side
			var hip := joint(root, row[0] + ("Left" if side < 0 else "Right") + "Leg", Vector3(x, hip_y, z))
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at: Vector3
			if front:
				knee_at = Vector3(x, 0.36, z - 0.02)
				us.tube([Vector3(x * 1.02, hip_y + 0.16, z + 0.03), Vector3(x * 1.05, 0.56, z - 0.02), knee_at], [0.17 * thick, 0.13 * thick, 0.085 * thick], up, {"sides": 11, "per": 3})
			else:
				knee_at = Vector3(x, 0.4, z - 0.08)
				us.tube([Vector3(x * 0.95, hip_y + 0.16, z + 0.06), Vector3(x * 1.05, 0.6, z), knee_at], [0.21 * thick, 0.15 * thick, 0.085 * thick], up, {"sides": 11, "per": 3})
			part(hip, "Upper", us)
			var knee := joint(hip, "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(stocking if stocking.is_valid() else skin)
			var hf := ls.add_painter(func (p, n, v, w): return HOOF.lightened(clampf(n.y, 0.0, 1.0) * 0.18))
			var hoof := Vector3(x, 0.05, knee_at.z + (-0.02 if front else 0.05))
			if front:
				ls.tube([knee_at, Vector3(x, 0.18, knee_at.z - 0.01), hoof + Vector3(0, 0.05, 0)], [0.08 * thick, 0.066 * thick, 0.07 * thick], lp, {"sides": 10, "per": 3})
			else:
				ls.tube([knee_at, Vector3(x, 0.27, knee_at.z + 0.09), Vector3(x, 0.13, knee_at.z + 0.07), hoof + Vector3(0, 0.05, 0)], [0.08 * thick, 0.066 * thick, 0.062 * thick, 0.068 * thick], lp, {"sides": 10, "per": 3})
			for t in [-1.0, 1.0]:
				ls.blob(hoof + Vector3(0.032 * t * thick, -0.004, -0.025), Vector3(0.038 * thick, 0.05, 0.06 * thick), hf, {"lat": 5, "lon": 8})
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)
	return {"hips": hips, "knees": knees}


func _close(parts: Dictionary, scale: float) -> Node3D:
	part(root, "Body", parts.body)
	part(parts.head, "Head", parts.head_sculpt)
	part(parts.jaw, "Jaw", parts.jaw_sculpt)
	var core := part(parts.head, "GlowingEyes", parts.eye_sculpt, glow)
	core.material_override = glow
	for k in range(parts.ears.size()): part(parts.ears[k], "Ear", parts.ear_sculpts[k])
	for k in range(parts.tails.size()): part(parts.tails[k], "Tail", parts.tail_sculpts[k])
	for k in range(parts.fronds.size()): part(parts.fronds[k], "Hair", parts.frond_sculpts[k])
	for owner in veins:
		var m := part(owner, "StormLight", veins[owner][0], glow)
		m.material_override = glow
	var node := _finish({"head": parts.head, "core": core, "arms": [], "forearms": [], "feet": parts.hips, "knees": parts.knees, "leaves": parts.fronds}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {&"jaw": node.get_path_to(parts.jaw)}
	if not parts.fronds.is_empty(): features[&"fronds"] = paths.call(parts.fronds)
	rig["visual_rig"] = {"head": node.get_path_to(parts.head), "wings": [], "wing_meshes": [], "legs": paths.call(parts.hips), "knees": paths.call(parts.knees),
		"ears": paths.call(parts.ears), "tails": paths.call(parts.tails), "features": features}
	node.set_meta("rig_bindings", rig)
	return node


## Small round eyes that glow storm-blue, set at the given points.
func eyes(at: Array, size: Vector3) -> Sculpt:
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for p in at: es.blob(p, size, white, {"lat": 5, "lon": 8})
	return es


## Slate plates: grey stone, lighter on top, darker in its cracks.
static func slate(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#4d555e").lerp(Color("#8d98a2"), clampf(n.y * 0.6 + 0.2 + Sculpt.noise(p * 9.0) * 0.35, 0.0, 1.0))
	return c.darkened(smoothstep(0.25, 0.5, Sculpt.fbm(p * 7.0 + Vector3(2, 5, 1))) * 0.35)


static func horn_paint(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#3a3f46").lerp(Color("#c9d3da"), clampf(v * 1.2 - 0.1, 0.0, 1.0))
	return c.lightened(clampf(n.y, 0.0, 1.0) * 0.12).darkened(Sculpt.noise(p * 30.0) * 0.08)


# ------------------------------------------------------------------ A: storm bison

func _bison() -> Node3D:
	var coat := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var streak := Sculpt.fbm(Vector3(p.x * 9.0, p.y * 6.0, p.z * 9.0))
		var light := Color("#7b5838").lerp(Color("#5a3d25"), smoothstep(0.2, -0.3, p.z))
		var c := light.lerp(Color("#2c1d13"), clampf(smoothstep(0.1, -0.5, p.z) * 0.6 + streak * 0.35 + smoothstep(0.45, 0.15, p.y) * 0.5, 0.0, 1.0))
		return c.lerp(Color("#5e6870"), smoothstep(0.75, 1.0, n.y) * 0.12)
	var hair := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#24170f").lerp(Color("#6a4a2e"), clampf(0.25 + Sculpt.noise(p * 11.0) * 0.4 + v * 0.3, 0.0, 1.0))
	var body := Sculpt.new(); var bp := body.add_painter(coat); var hp := body.add_painter(hair); var plate := body.add_painter(slate)
	body.tube([Vector3(0, 0.74, 0.72), Vector3(0, 0.8, 0.45), Vector3(0, 0.83, 0.1), Vector3(0, 0.92, -0.2), Vector3(0, 0.92, -0.44)], [0.27, 0.34, 0.37, 0.43, 0.38], bp, {"sides": 16, "per": 3, "flat": 0.82, "lump": 0.05})
	body.blob(Vector3(0, 1.12, -0.26), Vector3(0.27, 0.26, 0.36), bp, {"lat": 9, "lon": 12, "lump": 0.08})
	body.blob(Vector3(0, 0.62, -0.42), Vector3(0.28, 0.3, 0.26), bp, {"lat": 8, "lon": 12})
	body.tube([Vector3(0, 0.98, -0.42), Vector3(0, 0.86, -0.62), Vector3(0, 0.74, -0.74)], [0.36, 0.32, 0.27], bp, {"sides": 14, "per": 3, "flat": 0.85, "lump": 0.08})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.17 * side, 0.84, 0.55), Vector3(0.16, 0.22, 0.22), bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.2 * side, 0.88, -0.36), Vector3(0.16, 0.24, 0.2), bp, {"lat": 7, "lon": 10, "lump": 0.1})
	# A woolly cape over the hump, shoulders and chest: locks hanging down and back.
	for k in range(34):
		var t := float(k) / 33.0
		var ang := lerpf(-2.5, 2.5, t) + Sculpt.noise(Vector3(k, 1, 1)) * 0.15
		for ring in range(2):
			var z := -0.5 + ring * 0.2 + Sculpt.noise(Vector3(k, ring, 3)) * 0.04
			var center := Vector3(0, 0.9 + ring * 0.08, z)
			var radial := Vector3(sin(ang), cos(ang), 0)
			var reach := Vector3(0.36, 0.34 + ring * 0.04, 0)
			var base := center + radial * reach
			if base.y < 0.62: continue
			var dir := radial * 0.4 + Vector3(0, -1.0, 0.35 + ring * 0.2)
			lock(body, hp, base, dir, 0.24 + 0.08 * absf(Sculpt.noise(Vector3(k, ring, 5) * 1.7)), 0.07, Vector3(radial.x, radial.y, 0), 0.15)
	# Slate plates down the hump and back, overlapping like roof tiles, and two rows on the flanks.
	var spine := func (z: float) -> float:
		if z < -0.1: return 1.36 - absf(z + 0.28) * 0.75
		return 1.2 - (z + 0.1) * 0.12
	for k in range(9):
		var z := -0.52 + k * 0.14
		var y: float = spine.call(z)
		body.rock(Vector3(0, y - 0.03, z), Vector3(0.13 - k * 0.006, 0.06, 0.12), plate, {"lat": 4, "lon": 7, "lump": 0.15, "basis": Basis(Vector3.RIGHT, -0.25)})
		if k > 0 and k < 8:
			for side in [-1.0, 1.0]:
				body.rock(Vector3(0.17 * side, y - 0.11, z + 0.04), Vector3(0.1, 0.045, 0.1), plate, {"lat": 4, "lon": 6, "lump": 0.2, "basis": Basis.from_euler(Vector3(-0.2, 0, -side * 0.75))})
	# Long hair on the front legs.
	var fronds: Array = []; var frond_sculpts: Array = []
	var head := joint(root, "Head", Vector3(0, 0.74, -0.76))
	var hs := Sculpt.new(); var hdp := hs.add_painter(coat); var hhp := hs.add_painter(hair); var nose := hs.add_painter(func (p, n, v, w): return NOSE.lightened(clampf(n.y, 0.0, 1.0) * 0.15))
	var horn := hs.add_painter(horn_paint); var hplate := hs.add_painter(slate)
	# A massive, broad skull carried low, a deep muzzle and a woolly topknot.
	hs.blob(Vector3(0, 0.66, -0.86), Vector3(0.2, 0.21, 0.19), hdp, {"lat": 9, "lon": 12})
	hs.tube([Vector3(0, 0.6, -0.92), Vector3(0, 0.5, -1.0), Vector3(0, 0.43, -1.06)], [0.16, 0.135, 0.11], hdp, {"sides": 12, "per": 3, "square": 0.45, "flat": 1.15, "cap_rings": 2, "cap_len": 0.5})
	hs.blob(Vector3(0, 0.42, -1.1), Vector3(0.1, 0.06, 0.04), nose, {"lat": 5, "lon": 9})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.04 * side, 0.43, -1.137), Vector3(0.018, 0.024, 0.008), hs.add_painter(func (p, n, v, w): return Color("#080706")), {"lat": 3, "lon": 6})
		hs.blob(Vector3(0.12 * side, 0.6, -0.95), Vector3(0.07, 0.08, 0.07), hdp, {"lat": 5, "lon": 8})
	hs.blob(Vector3(0, 0.8, -0.86), Vector3(0.2, 0.13, 0.15), hhp, {"lat": 6, "lon": 10, "lump": 0.6})
	for k in range(14):
		var ang := lerpf(-2.4, 2.4, float(k) / 13.0)
		var base := Vector3(sin(ang) * 0.19, 0.8 + cos(ang) * 0.11, -0.9)
		lock(hs, hhp, base, Vector3(sin(ang) * 0.6, cos(ang) * 0.5 - 0.3, -0.5), 0.12, 0.05, Vector3(sin(ang), cos(ang), 0), 0.2, 5, 1)
	# A slate plate on the brow between the horns.
	hs.rock(Vector3(0, 0.84, -0.93), Vector3(0.13, 0.05, 0.08), hplate, {"lat": 4, "lon": 7, "lump": 0.12, "basis": Basis(Vector3.RIGHT, 0.9)})
	spark(head, Vector3(-0.07, 0.86, -0.985), Vector3(0.07, 0.83, -0.98), 3, 0.015, Vector3.UP, 0.007)
	# Storm horns: out to the sides, then up, breaking into a bolt at the tips.
	for side in [-1.0, 1.0]:
		storm_horn(hs, horn, head, [Vector3(0.15 * side, 0.8, -0.86), Vector3(0.28 * side, 0.82, -0.87), Vector3(0.39 * side, 0.9, -0.88),
			Vector3(0.43 * side, 1.0, -0.88), Vector3(0.45 * side, 1.1, -0.9), Vector3(0.5 * side, 1.2, -0.9), Vector3(0.52 * side, 1.3, -0.92)], 0.075, 0.035, Vector3(side, 0, 0))
	# A long beard.
	for k in range(9):
		var x := (k - 4) * 0.03
		lock(hs, hhp, Vector3(x, 0.42, -0.98 + absf(x) * 0.5), Vector3(x * 1.5, -1.0, 0.25), 0.2 + 0.06 * (1.0 - absf(x) * 6.0), 0.045, Vector3(1, 0, 0), 0.1, 5, 1)
	var jaw := joint(head, "Jaw", Vector3(0, 0.42, -0.92))
	var js := Sculpt.new(); var jp := js.add_painter(coat); var mouth := js.add_painter(func (p, n, v, w): return MOUTH)
	js.tube([Vector3(0, 0.43, -0.9), Vector3(0, 0.39, -1.05)], [0.08, 0.06], jp, {"sides": 10, "per": 2, "square": 0.4, "flat": 1.2, "cap_rings": 2})
	js.blob(Vector3(0, 0.43, -1.02), Vector3(0.06, 0.012, 0.05), mouth, {"lat": 4, "lon": 8})
	var eye_sculpt := eyes([Vector3(-0.165, 0.67, -0.95), Vector3(0.165, 0.67, -0.95)], Vector3(0.022, 0.02, 0.022))
	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.18 * side, 0.7, -0.82))
		var xs := Sculpt.new(); var xp := xs.add_painter(hair)
		xs.tube([Vector3(0.17 * side, 0.7, -0.82), Vector3(0.25 * side, 0.68, -0.81), Vector3(0.29 * side, 0.66, -0.8)], [0.04, 0.035, 0.01], xp, {"sides": 7, "per": 2, "flat": 0.4, "side": Vector3.UP, "cap_rings": 1})
		ears.append(ear); ear_sculpts.append(xs)
	var leg_rig := legs(coat, 0.21, -0.36, 0.55, 0.72, 1.0)
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var fs := Sculpt.new(); var fp := fs.add_painter(hair)
		for b in range(7):
			var ang := lerpf(-1.2, 1.2, b / 6.0)
			var at := Vector3(0.21 * side + cos(ang) * 0.13 * side, 0.62, -0.36 + sin(ang) * 0.12)
			lock(fs, fp, at, Vector3(cos(ang) * side * 0.3, -1.0, sin(ang) * 0.3), 0.26, 0.05, Vector3(cos(ang) * side, 0, sin(ang)), 0.05, 5, 1)
		var j := joint(leg_rig.hips[k], "Chaps", Vector3(0.21 * side, 0.62, -0.36))
		fronds.append(j); frond_sculpts.append(fs)
	var tail := joint(root, "Tail", Vector3(0, 0.88, 0.8))
	var ts := Sculpt.new(); var tp := ts.add_painter(coat)
	ts.tube([Vector3(0, 0.88, 0.78), Vector3(0, 0.78, 0.86), Vector3(0, 0.6, 0.9)], [0.04, 0.03, 0.025], tp, {"sides": 7, "per": 2, "cap1": false})
	var tip := joint(tail, "TailTip", Vector3(0, 0.6, 0.9))
	var tts := Sculpt.new(); var ttp := tts.add_painter(hair)
	for k in range(5):
		var ang := TAU * k / 5.0
		lock(tts, ttp, Vector3(0, 0.62, 0.9) + Vector3(cos(ang), 0, sin(ang)) * 0.015, Vector3(cos(ang) * 0.25, -1.0, sin(ang) * 0.25), 0.2, 0.035, Vector3(cos(ang), 0, sin(ang)), 0.05, 5, 1)
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": ears, "ear_sculpts": ear_sculpts,
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail, tip], "tail_sculpts": [ts, tts], "fronds": fronds, "frond_sculpts": frond_sculpts}, 1.9)


# ------------------------------------------------------------------ B: thunder rhino

func _rhino() -> Node3D:
	var hide := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var mottle := Sculpt.fbm(p * 6.0)
		var c := Color("#6b7177").lerp(Color("#3f454b"), clampf(n.y * 0.4 + 0.3 + mottle * 0.6, 0.0, 1.0))
		c = c.lightened(smoothstep(0.3, 0.45, Sculpt.noise(p * 26.0)) * 0.12)
		c = c.lerp(Color("#8d9297"), clampf(-n.y * 0.5, 0.0, 1.0) * 0.4)
		return c.darkened(smoothstep(0.3, 0.1, p.y) * 0.3)
	var body := Sculpt.new(); var bp := body.add_painter(hide)
	# The barrel, with two great shields of hide over the shoulders and the rump. Deep folds
	# run down its sides where the shields meet the saddle, and storm light burns in them.
	body.tube([Vector3(0, 0.76, 0.7), Vector3(0, 0.8, 0.4), Vector3(0, 0.8, 0.0), Vector3(0, 0.84, -0.35), Vector3(0, 0.8, -0.5)], [0.3, 0.4, 0.41, 0.43, 0.36], bp, {"sides": 18, "per": 3, "flat": 0.86})
	body.blob(Vector3(0, 0.85, -0.3), Vector3(0.4, 0.43, 0.27), bp, {"lat": 9, "lon": 16, "lump": 0.05})
	body.blob(Vector3(0, 0.82, 0.44), Vector3(0.37, 0.41, 0.3), bp, {"lat": 9, "lon": 16, "lump": 0.05})
	for fold in [[-0.04, 0.44], [0.17, 0.42]]:
		var z: float = fold[0]; var r: float = fold[1]
		var arc: Array = []; var ar: Array = []
		for i in range(9):
			var ang := lerpf(-1.75, 1.75, i / 8.0)
			arc.append(Vector3(sin(ang) * r * 0.9, 0.8 + cos(ang) * r * 1.02, z))
			ar.append(0.026)
		body.tube(arc, ar, bp, {"sides": 7, "per": 2, "cap_rings": 1, "lump": 0.3})
		for side in [-1.0, 1.0]:
			spark(root, Vector3(0.06 * side, 0.8 + r * 1.06, z - 0.045), Vector3(sin(1.6) * r * 0.97 * side, 0.8 + cos(1.6) * r, z - 0.04), 5, 0.025, Vector3(0, 0, 1), 0.013)
	body.blob(Vector3(0, 0.62, -0.4), Vector3(0.28, 0.24, 0.22), bp, {"lat": 7, "lon": 10})
	# A heavy neck with thick folds.
	for k in range(3):
		var z := -0.5 - k * 0.08
		body.tube([Vector3(-0.3 + k * 0.02, 0.85 - k * 0.04, z), Vector3(0, 1.0 - k * 0.07, z - 0.02), Vector3(0.3 - k * 0.02, 0.85 - k * 0.04, z)], [0.06, 0.07, 0.06], bp, {"sides": 7, "per": 3, "cap_rings": 1})
	body.tube([Vector3(0, 0.84, -0.48), Vector3(0, 0.78, -0.66)], [0.33, 0.28], bp, {"sides": 14, "per": 2, "flat": 0.9, "cap0": false})
	var head := joint(root, "Head", Vector3(0, 0.76, -0.68))
	var hs := Sculpt.new(); var hp := hs.add_painter(hide); var horn := hs.add_painter(horn_paint); var mouth := hs.add_painter(func (p, n, v, w): return NOSE)
	# A long sloping head, a pointed upper lip and a dip before the brow.
	hs.tube([Vector3(0, 0.84, -0.66), Vector3(0, 0.79, -0.86), Vector3(0, 0.65, -1.06), Vector3(0, 0.54, -1.2)], [0.25, 0.21, 0.17, 0.13], hp, {"sides": 13, "per": 3, "flat": 0.85, "cap_rings": 2, "cap_len": 0.6, "square": 0.2})
	hs.blob(Vector3(0, 0.49, -1.25), Vector3(0.075, 0.06, 0.05), hp, {"lat": 5, "lon": 8})
	hs.blob(Vector3(0, 0.47, -1.22), Vector3(0.09, 0.02, 0.04), mouth, {"lat": 4, "lon": 8})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.065 * side, 0.58, -1.225), Vector3(0.02, 0.025, 0.012), mouth, {"lat": 3, "lon": 6})
		hs.tube([Vector3(0.16 * side, 0.72, -0.86), Vector3(0.17 * side, 0.78, -0.9)], [0.04, 0.03], hp, {"sides": 7, "per": 2, "cap_rings": 1})
	# The great nose horn: a broad blade jagged like a lightning bolt, and a stubby second horn.
	var bolt := [Vector3(0, 0.62, -1.13), Vector3(0, 0.8, -1.18), Vector3(0, 0.9, -1.1), Vector3(0, 1.04, -1.16), Vector3(0, 1.14, -1.06), Vector3(0, 1.3, -1.1)]
	var radii := [0.1, 0.08, 0.064, 0.05, 0.034, 0.004]
	hs.tube(bolt, radii, horn, {"sides": 8, "per": 1, "cap_rings": 1, "cap1": false, "flat": 0.55, "side": Vector3.RIGHT})
	var v := vein(head)
	(v[0] as Sculpt).tube([bolt[3], bolt[4], bolt[5]], [0.05, 0.034, 0.006], v[1], {"sides": 8, "per": 1, "cap_rings": 1, "flat": 0.55, "side": Vector3.RIGHT})
	storm_horn(hs, horn, head, [Vector3(0, 0.86, -0.9), Vector3(0, 0.93, -0.92), Vector3(0, 1.0, -0.9), Vector3(0, 1.06, -0.88)], 0.055, 0.015, Vector3(0, 0, 1))
	var jaw := joint(head, "Jaw", Vector3(0, 0.52, -0.92))
	var js := Sculpt.new(); var jp := js.add_painter(hide)
	js.tube([Vector3(0, 0.53, -0.9), Vector3(0, 0.48, -1.16)], [0.09, 0.06], jp, {"sides": 10, "per": 2, "flat": 1.1, "cap_rings": 2})
	var eye_sculpt := eyes([Vector3(-0.18, 0.77, -0.92), Vector3(0.18, 0.77, -0.92)], Vector3(0.02, 0.016, 0.02))
	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.13 * side, 0.94, -0.7))
		var xs := Sculpt.new(); var xp := xs.add_painter(hide); var tuft := xs.add_painter(func (p, n, v, w): return Color("#2a2522"))
		xs.tube([Vector3(0.12 * side, 0.93, -0.7), Vector3(0.16 * side, 1.04, -0.68), Vector3(0.18 * side, 1.12, -0.66)], [0.045, 0.05, 0.02], xp, {"sides": 8, "per": 2, "cap_rings": 1, "flat": 0.6, "side": Vector3.BACK})
		for b in range(4): lock(xs, tuft, Vector3(0.18 * side, 1.11, -0.66), Vector3(side * (0.2 + b * 0.1), 1.0, 0.1), 0.06, 0.015, Vector3.BACK, 0.2, 4, 1)
		ears.append(ear); ear_sculpts.append(xs)
	var leg_rig := legs(hide, 0.25, -0.34, 0.5, 0.66, 1.35)
	var tail := joint(root, "Tail", Vector3(0, 0.95, 0.78))
	var ts := Sculpt.new(); var tp := ts.add_painter(hide)
	ts.tube([Vector3(0, 0.95, 0.76), Vector3(0, 0.84, 0.84), Vector3(0, 0.7, 0.86)], [0.035, 0.025, 0.02], tp, {"sides": 7, "per": 2, "cap1": false})
	var tip := joint(tail, "TailTip", Vector3(0, 0.7, 0.86))
	var tts := Sculpt.new(); var ttp := tts.add_painter(func (p, n, v, w): return Color("#2a2522"))
	for k in range(4):
		var ang := TAU * k / 4.0
		lock(tts, ttp, Vector3(0, 0.71, 0.86), Vector3(cos(ang) * 0.3, -1.0, sin(ang) * 0.3), 0.1, 0.022, Vector3(cos(ang), 0, sin(ang)), 0.05, 4, 1)
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": ears, "ear_sculpts": ear_sculpts,
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail, tip], "tail_sculpts": [ts, tts], "fronds": [], "frond_sculpts": []}, 1.85)


# ------------------------------------------------------------------ C: storm-cloud musk ox

func _muskox() -> Node3D:
	# Wool like a storm cloud: pale silver on top, darkening to rain-grey toward the hem.
	var wool := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var puff := Sculpt.fbm(p * 5.0)
		var c := Color("#33373d").lerp(Color("#c8ced3"), clampf(smoothstep(0.55, 1.25, p.y) + n.y * 0.2 + puff * 0.35, 0.0, 1.0))
		return c.darkened(Sculpt.noise(p * 14.0) * 0.06)
	var face := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#3e3832").lerp(Color("#7a7166"), clampf(n.y * 0.4 + Sculpt.noise(p * 12.0) * 0.4 + 0.2, 0.0, 1.0))
	var sock := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#d6d1c4").darkened(clampf(-n.y, 0.0, 1.0) * 0.2 + Sculpt.noise(p * 16.0) * 0.08)
	var body := Sculpt.new(); var bp := body.add_painter(wool); var plate := body.add_painter(slate)
	body.tube([Vector3(0, 0.8, 0.66), Vector3(0, 0.88, 0.4), Vector3(0, 0.9, 0.05), Vector3(0, 1.0, -0.25), Vector3(0, 0.95, -0.46)], [0.3, 0.37, 0.4, 0.44, 0.38], bp, {"sides": 16, "per": 3, "flat": 0.85, "lump": 0.1})
	body.blob(Vector3(0, 1.2, -0.24), Vector3(0.26, 0.2, 0.32), bp, {"lat": 8, "lon": 12, "lump": 0.15})
	body.tube([Vector3(0, 0.98, -0.44), Vector3(0, 0.86, -0.6), Vector3(0, 0.76, -0.7)], [0.36, 0.31, 0.26], bp, {"sides": 14, "per": 3, "flat": 0.9, "lump": 0.12})
	# The skirt: long locks hanging from the flanks, rump and chest almost to the ground.
	var skirt := body.add_painter(wool)
	for k in range(46):
		var t := float(k) / 46.0
		var ang := TAU * t
		var radial := Vector3(sin(ang), 0, -cos(ang))
		var z := radial.z * 0.62 + 0.08
		var x := radial.x * (0.38 if absf(radial.z) < 0.7 else 0.3)
		var top_y := 0.9 + (0.08 if z < -0.1 else 0.0)
		var base := Vector3(x, top_y, z)
		var length := top_y - 0.22 + 0.05 * Sculpt.noise(Vector3(k, 2, 2) * 1.3)
		var dir := radial * 0.22 + Vector3(0, -1.0, 0)
		lock(body, skirt, base, dir, length, 0.085, Vector3(radial.x, 0, radial.z), 0.0, 6, 2, 0.04)
		if k % 2 == 0:
			lock(body, skirt, base + Vector3(0, 0.18, 0) - radial * 0.03, dir + radial * 0.1, length * 0.7, 0.075, Vector3(radial.x, 0, radial.z), 0.0, 6, 2, 0.035)
	# Lightning flickering in the skirt.
	for s in [[0.42, -0.25, 0.1], [-0.42, 0.25, -0.15], [0.41, 0.45, 0.0], [-0.4, -0.45, 0.2]]:
		var sx: float = s[0]; var sz: float = s[1]
		spark(root, Vector3(sx * 1.02, 0.78, sz), Vector3(sx * 1.08, 0.34, sz + float(s[2])), 4, 0.035, Vector3(0, 0, 1), 0.012)
	# A ridge of slate plates over the hump.
	for k in range(6):
		var z := -0.46 + k * 0.13
		var y := 1.38 - absf(z + 0.24) * 0.55
		body.rock(Vector3(0, y, z), Vector3(0.12, 0.05, 0.1), plate, {"lat": 4, "lon": 7, "lump": 0.18, "basis": Basis(Vector3.RIGHT, -0.3)})
	var head := joint(root, "Head", Vector3(0, 0.78, -0.74))
	var hs := Sculpt.new(); var fp := hs.add_painter(face); var wp := hs.add_painter(wool); var horn := hs.add_painter(horn_paint); var bossp := hs.add_painter(slate)
	var nose := hs.add_painter(func (p, n, v, w): return NOSE)
	# A long, heavy face and a pale muzzle, with wool falling from the cheeks and throat.
	hs.blob(Vector3(0, 0.74, -0.84), Vector3(0.17, 0.19, 0.17), fp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 0.7, -0.9), Vector3(0, 0.58, -1.02), Vector3(0, 0.5, -1.1)], [0.14, 0.12, 0.1], fp, {"sides": 12, "per": 3, "square": 0.35, "flat": 1.05, "cap_rings": 2, "cap_len": 0.5})
	hs.blob(Vector3(0, 0.48, -1.13), Vector3(0.085, 0.06, 0.045), hs.add_painter(func (p, n, v, w): return Color("#8a8379")), {"lat": 5, "lon": 9})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.035 * side, 0.5, -1.17), Vector3(0.016, 0.02, 0.008), nose, {"lat": 3, "lon": 6})
	for k in range(16):
		var ang := lerpf(-2.0, 2.0, float(k) / 15.0)
		var base := Vector3(sin(ang) * 0.16, 0.66 - cos(ang) * 0.04, -0.86 + absf(sin(ang)) * 0.03)
		lock(hs, wp, base, Vector3(sin(ang) * 0.4, -1.0, 0.25), 0.28 + 0.12 * cos(ang), 0.06, Vector3(sin(ang), 0, cos(ang)), 0.05, 6, 1)
	# The boss: two great slate plates that meet across the brow, with the horns sweeping down
	# beside the face and hooking up and out into jagged glowing tips.
	for side in [-1.0, 1.0]:
		hs.rock(Vector3(0.1 * side, 0.93, -0.84), Vector3(0.12, 0.06, 0.13), bossp, {"lat": 5, "lon": 8, "lump": 0.12, "basis": Basis.from_euler(Vector3(0.3, 0, -side * 0.35))})
		storm_horn(hs, horn, head, [Vector3(0.17 * side, 0.9, -0.84), Vector3(0.24 * side, 0.86, -0.85), Vector3(0.27 * side, 0.74, -0.88), Vector3(0.28 * side, 0.62, -0.92),
			Vector3(0.33 * side, 0.6, -0.97), Vector3(0.4 * side, 0.68, -1.0), Vector3(0.45 * side, 0.78, -1.01)], 0.08, 0.025, Vector3(0, 0, 1))
	spark(head, Vector3(-0.17, 0.95, -0.9), Vector3(0.17, 0.95, -0.9), 5, 0.02, Vector3.UP, 0.009)
	var jaw := joint(head, "Jaw", Vector3(0, 0.5, -0.94))
	var js := Sculpt.new(); var jp := js.add_painter(face)
	js.tube([Vector3(0, 0.52, -0.92), Vector3(0, 0.47, -1.08)], [0.08, 0.055], jp, {"sides": 10, "per": 2, "flat": 1.1, "cap_rings": 2})
	var eye_sculpt := eyes([Vector3(-0.15, 0.78, -0.95), Vector3(0.15, 0.78, -0.95)], Vector3(0.022, 0.018, 0.02))
	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.16 * side, 0.82, -0.78))
		var xs := Sculpt.new(); var xp := xs.add_painter(face)
		xs.tube([Vector3(0.15 * side, 0.82, -0.78), Vector3(0.21 * side, 0.81, -0.77)], [0.03, 0.012], xp, {"sides": 6, "per": 2, "flat": 0.5, "side": Vector3.UP, "cap_rings": 1})
		ears.append(ear); ear_sculpts.append(xs)
	var leg_rig := legs(wool, 0.21, -0.36, 0.5, 0.72, 1.05, sock)
	var tail := joint(root, "Tail", Vector3(0, 0.92, 0.72))
	var ts := Sculpt.new(); var tp := ts.add_painter(wool)
	lock(ts, tp, Vector3(0, 0.95, 0.7), Vector3(0, -1.0, 0.3), 0.3, 0.07, Vector3.RIGHT, 0.0)
	var tip := joint(tail, "TailTip", Vector3(0, 0.7, 0.78))
	var tts := Sculpt.new(); var ttp := tts.add_painter(wool)
	lock(tts, ttp, Vector3(0, 0.72, 0.78), Vector3(0, -1.0, 0.1), 0.16, 0.05, Vector3.RIGHT, 0.0)
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": ears, "ear_sculpts": ear_sculpts,
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail, tip], "tail_sculpts": [ts, tts], "fronds": [], "frond_sculpts": []}, 1.85)
