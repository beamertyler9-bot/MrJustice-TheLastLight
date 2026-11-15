extends "res://tools/creature_kit.gd"
## The Windwhistle Stalker of the Windbell Plains, sculpted by hand: a long, low big cat that
## creeps through the tall grass and whistles before it lunges. Three designs share one body:
##   grasslion - a tawny lion whose mane is a great fan of grass blades and seed heads
##   reedlynx  - a spotted plains lynx with hollow reed flutes growing from its back
##   pampas    - a dark panther with pale pampas-grass plumes on its shoulders and tail

const NOSE := Color("#3a2522")
const NOSE_PINK := Color("#b9767a")
const FANG := Color("#f0e6cc")
const MOUTH := Color("#5a2228")
const EAR_PINK := Color("#c98c86")
const WHISKER := Color("#f2ecdc")
const GRASS_ROOT := Color("#56752b")
const GRASS_TIP := Color("#d6c46e")

var fur_base := Color("#b8955a")
var fur_dark := Color("#7a5c34")
var fur_light := Color("#ead8ad")
var spots := 0.0
var stripes := 0.0


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.2, 3.2, 3.2)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "WindwhistleStalker"
	match variant:
		"grasslion": return _grasslion()
		"reedlynx": return _reedlynx()
		"pampas": return _pampas()
	return null


func _eyes(color: Color) -> void:
	glow.albedo_color = color.darkened(0.25); glow.emission = color
	glow.emission_energy_multiplier = 1.15


## Cat fur: darker along the back, pale belly, chin and muzzle, with optional spots and
## grass-shadow stripes.
func fur() -> Callable:
	var base := fur_base; var dark := fur_dark; var light := fur_light
	var spotty := spots; var stripy := stripes
	return func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
		var streak := Sculpt.fbm(Vector3(p.x * 10.0, p.y * 10.0, p.z * 3.0))
		var c := base.lerp(dark, clampf(n.y * 0.7 - 0.1 + streak * 0.5, 0.0, 1.0) * 0.8)
		var belly := smoothstep(-0.2, -0.7, n.y) * smoothstep(0.85, 0.6, p.y)
		belly = maxf(belly, smoothstep(-0.8, -0.88, p.z) * smoothstep(0.93, 0.89, p.y))
		c = c.lerp(light, belly)
		if spotty > 0.0:
			var s := Sculpt.noise(Vector3(p.x * 13.0, p.y * 13.0, p.z * 13.0))
			c = c.lerp(dark.darkened(0.35), smoothstep(0.28, 0.4, s) * spotty * (1.0 - belly) * smoothstep(0.98, 0.9, absf(n.y) + 0.0))
		if stripy > 0.0:
			var band := sin(p.z * 26.0 + Sculpt.noise(p * 4.0) * 3.0)
			c = c.lerp(light.darkened(0.25), smoothstep(0.7, 0.95, band) * stripy * (1.0 - belly))
		return c


func grass_paint() -> Callable:
	return func (p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
		var shade := Sculpt.noise(p * 7.0)
		return GRASS_ROOT.lerp(GRASS_TIP, clampf(v * 1.1 + shade * 0.25, 0.0, 1.0)).darkened(0.08 + shade * 0.08)


## A flat blade of grass from `base` along `dir`, drooping at the tip; `thin` is the axis
## the blade is thin along (so its width spans the other way).
func blade(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, thin: Vector3, droop := 0.25) -> Vector3:
	var d := dir.normalized()
	var mid := base + d * length * 0.5 + Vector3(0, -length * droop * 0.25, 0)
	var tip := base + d * length + Vector3(0, -length * droop, 0)
	s.tube([base, mid, tip], [width, width * 0.8, 0.002], painter, {"sides": 6, "per": 2, "flat": 0.18, "side": thin, "cap_rings": 1, "cap1": false})
	return tip


## A wheat-like seed head: a short chain of plump grains along a stalk end.
func seed_head(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float) -> void:
	var d := dir.normalized()
	for k in range(5):
		var at := base + d * length * (k + 0.5) / 5.0
		var side := d.cross(Vector3.UP).normalized() * (0.012 if k % 2 == 0 else -0.012)
		s.blob(at + side, Vector3(0.016, 0.016, 0.026), painter, {"lat": 4, "lon": 6, "basis": Basis.looking_at(d, Vector3.UP)})


## The shared cat: body, head, jaw, ears, legs and tail on the game's rig.
func _cat(skin: Callable) -> Dictionary:
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	body.tube([Vector3(0, 0.74, 0.66), Vector3(0, 0.79, 0.44), Vector3(0, 0.75, 0.12), Vector3(0, 0.8, -0.2), Vector3(0, 0.83, -0.42)], [0.16, 0.21, 0.17, 0.22, 0.19], bp, {"sides": 14, "per": 3, "flat": 0.8, "lump": 0.03})
	body.blob(Vector3(0, 0.69, -0.3), Vector3(0.17, 0.22, 0.21), bp, {"lat": 8, "lon": 12})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.1 * side, 0.73, 0.47), Vector3(0.12, 0.17, 0.18), bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.11 * side, 0.83, -0.3), Vector3(0.1, 0.13, 0.13), bp, {"lat": 7, "lon": 10})
	body.tube([Vector3(0, 0.81, -0.4), Vector3(0, 0.87, -0.55), Vector3(0, 0.91, -0.64)], [0.17, 0.14, 0.12], bp, {"sides": 12, "per": 3, "cap0": false})
	var parts := {"body": body, "body_painter": bp}

	var head := joint(root, "Head", Vector3(0, 0.92, -0.66))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin)
	var nose := hs.add_painter(func (p, n, v, w): return NOSE.darkened(0.2).lightened(clampf(n.y, 0.0, 1.0) * 0.12))
	var fang := hs.add_painter(func (p, n, v, w): return FANG)
	var dark := hs.add_painter(func (p, n, v, w): return Color("#14100d"))
	var whisk := hs.add_painter(func (p, n, v, w): return WHISKER)
	hs.blob(Vector3(0, 0.945, -0.74), Vector3(0.135, 0.12, 0.13), hp, {"lat": 9, "lon": 14})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.072 * side, 0.9, -0.8), Vector3(0.072, 0.062, 0.065), hp, {"lat": 6, "lon": 9})
		hs.blob(Vector3(0.034 * side, 0.888, -0.868), Vector3(0.042, 0.036, 0.036), hp, {"lat": 6, "lon": 9})
		# Heavy brows over slanted eyes, and a slit pupil on each eye.
		hs.blob(Vector3(0.06 * side, 0.982, -0.838), Vector3(0.048, 0.018, 0.03), hp, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.38 * side)})
		hs.blob(Vector3(0.058 * side, 0.956, -0.864), Vector3(0.0045, 0.015, 0.004), dark, {"lat": 3, "lon": 6})
		hs.crystal(Vector3(0.03 * side, 0.878, -0.892), Vector3(0, -1, -0.12), 0.058, 0.009, fang, 5)
		for k in range(3):
			var from := Vector3(0.05 * side, 0.885 + k * 0.01, -0.885)
			hs.tube([from, from + Vector3(0.09 * side, 0.004 - k * 0.012, 0.03), from + Vector3(0.17 * side, -0.01 - k * 0.025, 0.07)], [0.0035, 0.0028, 0.0015], whisk, {"sides": 3, "per": 2, "cap_rings": 1})
	hs.tube([Vector3(0, 0.985, -0.82), Vector3(0, 0.95, -0.875)], [0.045, 0.032], hp, {"sides": 9, "per": 2, "cap_rings": 2})
	hs.blob(Vector3(0, 0.922, -0.895), Vector3(0.022, 0.012, 0.012), nose, {"lat": 4, "lon": 7})
	parts["head"] = head; parts["head_sculpt"] = hs; parts["head_painter"] = hp

	var jaw := joint(head, "Jaw", Vector3(0, 0.875, -0.77))
	var js := Sculpt.new(); var jp := js.add_painter(skin)
	var mouth := js.add_painter(func (p, n, v, w): return MOUTH)
	var jfang := js.add_painter(func (p, n, v, w): return FANG)
	js.tube([Vector3(0, 0.862, -0.76), Vector3(0, 0.848, -0.86)], [0.05, 0.034], jp, {"sides": 10, "per": 2, "square": 0.35, "cap_rings": 2})
	js.blob(Vector3(0, 0.868, -0.835), Vector3(0.034, 0.012, 0.05), mouth, {"lat": 4, "lon": 8})
	for side in [-1.0, 1.0]: js.crystal(Vector3(0.024 * side, 0.858, -0.872), Vector3(0, 1, -0.1), 0.03, 0.007, jfang, 5)
	parts["jaw"] = jaw; parts["jaw_sculpt"] = js

	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.058 * side, 0.955, -0.846), Vector3(0.031, 0.016, 0.02), white, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.28 * side)})
	parts["core_sculpt"] = es

	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.08 * side, 1.03, -0.71))
		var xs := Sculpt.new(); var xp := xs.add_painter(skin); var pink := xs.add_painter(func (p, n, v, w): return EAR_PINK)
		xs.tube([Vector3(0.08 * side, 1.015, -0.715), Vector3(0.1 * side, 1.08, -0.708), Vector3(0.115 * side, 1.135, -0.7)], [0.052, 0.033, 0.004], xp, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.4, "side": Vector3.BACK})
		xs.tube([Vector3(0.081 * side, 1.02, -0.728), Vector3(0.099 * side, 1.075, -0.722), Vector3(0.111 * side, 1.118, -0.715)], [0.034, 0.02, 0.003], pink, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.3, "side": Vector3.BACK})
		ears.append(ear); ear_sculpts.append(xs)
	parts["ears"] = ears; parts["ear_sculpts"] = ear_sculpts

	var hips: Array = []; var knees: Array = []
	for row in [["Front", -0.32, true], ["Hind", 0.47, false]]:
		for side in [-1.0, 1.0]:
			var front: bool = row[2]
			var label: String = row[0] + ("Left" if side < 0 else "Right")
			var hip := joint(root, label + "Leg", Vector3(0.15 * side, 0.72, row[1]))
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at: Vector3
			if front:
				knee_at = Vector3(0.16 * side, 0.38, -0.3)
				us.tube([Vector3(0.13 * side, 0.86, -0.28), Vector3(0.16 * side, 0.6, -0.34), knee_at], [0.115, 0.085, 0.062], up, {"sides": 10, "per": 3})
			else:
				knee_at = Vector3(0.16 * side, 0.42, 0.34)
				us.tube([Vector3(0.12 * side, 0.86, 0.5), Vector3(0.16 * side, 0.62, 0.42), knee_at], [0.16, 0.12, 0.068], up, {"sides": 10, "per": 3})
			part(hip, "Upper", us)
			var knee := joint(hip, "Elbow" if front else "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cp := ls.add_painter(func (p, n, v, w): return FANG.darkened(0.15 + (1.0 - v) * 0.45))
			var paw: Vector3
			if front:
				paw = Vector3(0.16 * side, 0.045, -0.39)
				ls.tube([knee_at, Vector3(0.16 * side, 0.17, -0.33), paw + Vector3(0, 0.03, 0.03)], [0.062, 0.05, 0.05], lp, {"sides": 9, "per": 3})
			else:
				paw = Vector3(0.16 * side, 0.045, 0.4)
				ls.tube([knee_at, Vector3(0.16 * side, 0.3, 0.5), Vector3(0.16 * side, 0.11, 0.47), paw + Vector3(0, 0.03, 0.03)], [0.066, 0.05, 0.045, 0.045], lp, {"sides": 9, "per": 3})
			ls.blob(paw, Vector3(0.072, 0.045, 0.085), lp, {"lat": 6, "lon": 10})
			for c in range(4):
				var toe := paw + Vector3((c - 1.5) * 0.034, 0.0, -0.075)
				ls.blob(toe, Vector3(0.022, 0.028, 0.024), lp, {"lat": 4, "lon": 6})
				if front: ls.crystal(toe + Vector3(0, -0.008, -0.015), Vector3((c - 1.5) * 0.1, -0.5, -1.0), 0.04, 0.008, cp, 5)
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)
	parts["hips"] = hips; parts["knees"] = knees

	var tail := joint(root, "Tail", Vector3(0, 0.76, 0.64))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	ts.tube([Vector3(0, 0.77, 0.6), Vector3(0, 0.72, 0.85), Vector3(0, 0.6, 1.0), Vector3(0, 0.51, 1.14)], [0.062, 0.056, 0.05, 0.046], tp, {"sides": 9, "per": 3, "cap1": false})
	var tail_tip := joint(tail, "TailTip", Vector3(0, 0.51, 1.13))
	var tts := Sculpt.new(); var ttp := tts.add_painter(skin)
	tts.tube([Vector3(0, 0.51, 1.12), Vector3(0, 0.48, 1.3), Vector3(0, 0.55, 1.46), Vector3(0, 0.67, 1.55)], [0.046, 0.043, 0.04, 0.034], ttp, {"sides": 9, "per": 3, "cap0": false})
	parts["tails"] = [tail, tail_tip]; parts["tail_sculpts"] = [ts, tts]
	parts["fronds"] = []
	return parts


func _close(parts: Dictionary, scale: float) -> Node3D:
	part(root, "Body", parts.body)
	part(parts.head, "Head", parts.head_sculpt)
	part(parts.jaw, "Jaw", parts.jaw_sculpt)
	var core := part(parts.head, "GlowingEyes", parts.core_sculpt, glow)
	core.material_override = glow
	for k in range(parts.ears.size()): part(parts.ears[k], "Ear", parts.ear_sculpts[k])
	for k in range(parts.tails.size()): part(parts.tails[k], "Fur", parts.tail_sculpts[k])
	var node := _finish({"head": parts.head, "core": core, "arms": [], "forearms": [], "feet": parts.hips, "knees": parts.knees, "leaves": parts.fronds}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {&"jaw": node.get_path_to(parts.jaw)}
	if not parts.fronds.is_empty(): features[&"fronds"] = paths.call(parts.fronds)
	rig["visual_rig"] = {"head": node.get_path_to(parts.head), "wings": [], "wing_meshes": [], "legs": paths.call(parts.hips), "knees": paths.call(parts.knees),
		"ears": paths.call(parts.ears), "tails": paths.call(parts.tails), "features": features}
	node.set_meta("rig_bindings", rig)
	return node


## A swaying clump (a mane section, a row of reeds) on its own joint.
func _frond(parts: Dictionary, parent: Node3D, name: String, at: Vector3, s: Sculpt) -> void:
	var j := joint(parent, name, at)
	part(j, "Blades", s)
	parts.fronds.append(j)


# ------------------------------------------------------------------ A: grass-mane lion

func _grasslion() -> Node3D:
	_eyes(Color("#ffcf4a"))
	var parts := _cat(fur())
	# The mane: rings of grass blades round the neck, fanned out to frame the face, in four
	# sections that sway on their own. A few blades end in ripe seed heads.
	var sections := {}
	for key in ["Top", "Left", "Right", "Chin"]:
		var s := Sculpt.new()
		sections[key] = [s, s.add_painter(grass_paint()), s.add_painter(func (p, n, v, w): return Color("#e2c977").darkened(Sculpt.noise(p * 30.0) * 0.12))]
	for ring in range(4):
		var z := -0.63 + ring * 0.075
		var count := 15 + ring * 2
		for k in range(count):
			var ang := TAU * (k + ring * 0.5) / count
			var radial := Vector3(cos(ang), sin(ang), 0)
			var key := "Chin"
			if sin(ang) > 0.45: key = "Top"
			elif cos(ang) < -0.3: key = "Left"
			elif cos(ang) > 0.3: key = "Right"
			var sec: Array = sections[key]
			var center := Vector3(0, 0.9 - ring * 0.012, z)
			var base := center + radial * (0.13 + ring * 0.012)
			var dir := radial * (1.0 - ring * 0.18) + Vector3(0, 0.12, 0.35 + ring * 0.3)
			var tangent := Vector3(-sin(ang), cos(ang), 0)
			var length := 0.26 + ring * 0.05 + 0.07 * Sculpt.noise(Vector3(k, ring, 1) * 1.7)
			if sin(ang) < -0.6: length *= 0.7
			var tip := blade(sec[0], sec[1], base, dir, length, 0.034 - ring * 0.003, dir.normalized().cross(tangent), 0.22 + ring * 0.05)
			if ring >= 2 and (k + ring) % 5 == 0 and sin(ang) > -0.3:
				seed_head(sec[0], sec[2], tip - dir.normalized() * 0.01, dir + Vector3(0, -0.3, 0.2), 0.12)
	_frond(parts, parts.head, "ManeTop", Vector3(0, 1.02, -0.58), sections.Top[0])
	_frond(parts, parts.head, "ManeLeft", Vector3(-0.14, 0.9, -0.58), sections.Left[0])
	_frond(parts, parts.head, "ManeRight", Vector3(0.14, 0.9, -0.58), sections.Right[0])
	_frond(parts, root, "ManeChin", Vector3(0, 0.78, -0.58), sections.Chin[0])
	# A tuft of grass at the tail tip.
	var tts: Sculpt = parts.tail_sculpts[1]; var gp := tts.add_painter(grass_paint())
	for k in range(9):
		var ang := TAU * k / 9.0
		var dir := Vector3(cos(ang) * 0.5, 0.8 + sin(ang) * 0.5, 0.6)
		blade(tts, gp, Vector3(0, 0.67, 1.54) + Vector3(cos(ang), sin(ang), 0) * 0.02, dir, 0.17 + 0.04 * sin(k * 2.0), 0.022, dir.normalized().cross(Vector3(-sin(ang), cos(ang), 0)), 0.3)
	return _close(parts, 1.2)


# ------------------------------------------------------------------ B: reed-flute lynx

func _reedlynx() -> Node3D:
	_eyes(Color("#d8ff6a"))
	fur_base = Color("#a19c79"); fur_dark = Color("#5e5b44"); fur_light = Color("#e4dfc8"); spots = 1.0
	var parts := _cat(fur())
	var tuft := func (p, n, v, w): return Color("#1d1a15")
	# Long black ear tufts and a pale cheek ruff.
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var xs: Sculpt = parts.ear_sculpts[k]; var tp := xs.add_painter(tuft)
		xs.tube([Vector3(0.113 * side, 1.12, -0.7), Vector3(0.12 * side, 1.19, -0.69), Vector3(0.112 * side, 1.25, -0.675)], [0.014, 0.009, 0.002], tp, {"sides": 5, "per": 2, "cap_rings": 1})
	var hs: Sculpt = parts.head_sculpt; var rp := hs.add_painter(func (p, n, v, w): return fur_light.darkened(0.05 + v * 0.15))
	for side in [-1.0, 1.0]:
		tufts(hs, rp, [Vector3(0.11 * side, 0.9, -0.76), Vector3(0.12 * side, 0.87, -0.73), Vector3(0.1 * side, 0.85, -0.78)], [Vector3(side, -0.7, 0.5), Vector3(side, -0.9, 0.6), Vector3(side * 0.6, -1.0, 0.3)], 0.11, 0.03)
	# Black rings down the tail and a black tip.
	for k in range(2):
		var ts: Sculpt = parts.tail_sculpts[k]; var bp := ts.add_painter(tuft)
		var spots_at: Array = [[0.85, 0.72], [1.03, 0.58]] if k == 0 else [[1.27, 0.48], [1.42, 0.53]]
		for at in spots_at:
			ts.tube([Vector3(0, at[1] + 0.012, at[0] - 0.015), Vector3(0, at[1] - 0.012, at[0] + 0.015)], [0.06 - k * 0.012, 0.06 - k * 0.012], bp, {"sides": 9, "per": 1, "cap_rings": 1})
	var tts: Sculpt = parts.tail_sculpts[1]
	tts.blob(Vector3(0, 0.665, 1.545), Vector3(0.042, 0.05, 0.045), tts.add_painter(tuft), {"lat": 5, "lon": 8})
	# The reed flutes: hollow pipes of different lengths growing from its back, each with
	# finger holes. Wind through them makes the whistle that warns of its lunge.
	var reeds := Sculpt.new()
	var reed := reeds.add_painter(func (p, n, v, w): return Color("#b3a85a").lerp(Color("#7d8a3c"), clampf(1.0 - v + Sculpt.noise(p * 12.0) * 0.3, 0.0, 1.0) * 0.6).darkened(clampf(-w, 0.0, 1.0) * 0.3))
	var hole := reeds.add_painter(func (p, n, v, w): return Color("#1b140c"))
	var sock := reeds.add_painter(fur())
	var specs := [[-0.07, -0.2, 0.36, -0.25], [0.07, -0.12, 0.46, 0.2], [-0.05, 0.0, 0.52, -0.15], [0.06, 0.1, 0.44, 0.25], [-0.04, 0.22, 0.34, -0.2], [0.03, 0.32, 0.26, 0.15]]
	for spec in specs:
		var base := Vector3(spec[0], 0.93 - absf(spec[1] + 0.05) * 0.1, spec[1])
		var dir := Vector3(spec[3] * 0.6, 1.0, 0.55).normalized()
		var top: Vector3 = base + dir * spec[2]
		var r: float = 0.034 + spec[2] * 0.03
		reeds.tube([base - dir * 0.06, base.lerp(top, 0.5), top], [r * 1.05, r, r * 0.95], reed, {"sides": 10, "per": 2, "cap0": false, "cap1": false, "bands": 3, "band": 0.12})
		# A dark mouth just inside the open top, and three finger holes on the front.
		reeds.blob(top - dir * 0.01, Vector3(r * 0.82, 0.004, r * 0.82), hole, {"lat": 2, "lon": 10, "basis": Basis.looking_at(dir, Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)})
		var front := (Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)).normalized()
		for h in range(3):
			reeds.blob(base.lerp(top, 0.45 + h * 0.15) + front * r * 0.92, Vector3(r * 0.32, r * 0.22, r * 0.12), hole, {"lat": 3, "lon": 6, "basis": Basis.looking_at(front, dir)})
		reeds.blob(base + Vector3(0, -0.01, 0), Vector3(r * 2.0, r * 1.0, r * 2.0), sock, {"lat": 5, "lon": 8})
	_frond(parts, root, "Reeds", Vector3(0, 0.93, 0.05), reeds)
	return _close(parts, 1.2)


# ------------------------------------------------------------------ C: pampas panther

func _pampas() -> Node3D:
	_eyes(Color("#9dffc4"))
	fur_base = Color("#434a36"); fur_dark = Color("#262b1f"); fur_light = Color("#8c8f6c"); stripes = 0.55
	var parts := _cat(fur())
	var plume_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#c9b98f").lerp(Color("#f3ead2"), clampf(v * 1.6 - 0.2, 0.0, 1.0)).darkened(Sculpt.noise(p * 18.0) * 0.1 + clampf(-n.y, 0.0, 1.0) * 0.12)
	var stalk_paint := func (p, n, v, w): return Color("#9d8d5c").darkened(0.1)
	# Pampas plumes: a thin stalk and a big feathery head, swaying on their own joints.
	var plume := func (s: Sculpt, sp: int, pp: int, base: Vector3, dir: Vector3, length: float, fat: float) -> void:
		var d := dir.normalized()
		var bend := Vector3(0, -0.06, 0.08) * length
		s.tube([base, base + d * length * 0.35], [0.012, 0.01], sp, {"sides": 5, "per": 1, "cap_rings": 1})
		var a := base + d * length * 0.3
		s.tube([a, a + d * length * 0.3, a + d * length * 0.55 + bend * 0.5, a + d * length * 0.75 + bend], [fat * 0.45, fat, fat * 0.8, 0.004], pp, {"sides": 9, "per": 3, "lump": 0.55, "cap_rings": 2, "cap1": false})
	for side in [-1.0, 1.0]:
		var s := Sculpt.new(); var sp := s.add_painter(stalk_paint); var pp := s.add_painter(plume_paint)
		plume.call(s, sp, pp, Vector3(0.1 * side, 0.92, -0.32), Vector3(side * 0.35, 1.0, 0.45), 0.62, 0.06)
		plume.call(s, sp, pp, Vector3(0.06 * side, 0.94, -0.22), Vector3(side * 0.15, 1.0, 0.7), 0.5, 0.05)
		_frond(parts, root, "PlumeLeft" if side < 0 else "PlumeRight", Vector3(0.08 * side, 0.93, -0.28), s)
	var back := Sculpt.new(); var bsp := back.add_painter(stalk_paint); var bpp := back.add_painter(plume_paint)
	plume.call(back, bsp, bpp, Vector3(0, 0.92, 0.05), Vector3(0.1, 1.0, 0.8), 0.42, 0.045)
	plume.call(back, bsp, bpp, Vector3(0, 0.93, 0.28), Vector3(-0.1, 1.0, 0.9), 0.36, 0.04)
	_frond(parts, root, "PlumeBack", Vector3(0, 0.92, 0.15), back)
	# A ruff of pale seed-fluff round the neck: short feathery tufts swept back.
	var body: Sculpt = parts.body; var fluff := body.add_painter(plume_paint)
	for ring in range(3):
		for k in range(17):
			var ang := TAU * (k + ring * 0.33) / 17.0
			var radial := Vector3(cos(ang), sin(ang) * 0.95, 0)
			var base := Vector3(0, 0.86, -0.55 + ring * 0.07) + radial * (0.15 - ring * 0.008)
			var dir := (radial * (0.75 - ring * 0.15) + Vector3(0, 0.1, 0.7)).normalized()
			var l := 0.17 + 0.05 * Sculpt.noise(Vector3(k, ring, 3) * 1.9)
			var curl := Vector3(0, -0.03, 0.04)
			body.tube([base, base + dir * l * 0.45, base + dir * l * 0.8 + curl * 0.5, base + dir * l + curl], [0.018, 0.026, 0.016, 0.002], fluff, {"sides": 6, "per": 2, "lump": 0.9, "cap_rings": 1, "cap1": false})
	# The big plume on the tail.
	var tts: Sculpt = parts.tail_sculpts[1]
	plume.call(tts, tts.add_painter(stalk_paint), tts.add_painter(plume_paint), Vector3(0, 0.62, 1.51), Vector3(0, 1.0, 0.9), 0.55, 0.075)
	return _close(parts, 1.2)
