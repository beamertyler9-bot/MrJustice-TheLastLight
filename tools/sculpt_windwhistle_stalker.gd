extends "res://tools/creature_kit.gd"
## The Windwhistle Stalker of the Windbell Plains, sculpted by hand: a big wild cat that creeps
## through the tall grass and whistles before it lunges. Three designs share one big-cat body
## (long heavy muzzle, small round ears, deep chest, thick forelegs and big paws):
##   lion       - a tawny plains lion with a mane of dark hair and grass blades with seed heads
##   tiger      - a straw-gold grass tiger with dark stripes and a crest of grass along its back
##   sabertooth - a stocky, bob-tailed sabertooth with huge curved fangs and a bristly ruff

const NOSE := Color("#3a2522")
const FANG := Color("#f0e6cc")
const MOUTH := Color("#4f1d22")
const WHISKER := Color("#f2ecdc")
const GRASS_ROOT := Color("#56752b")
const GRASS_TIP := Color("#d6c46e")

var fur_base := Color("#c39a5c")
var fur_dark := Color("#8d6a3a")
var fur_light := Color("#ecdcb5")
var spots := 0.0
var stripes := 0.0
var stripe_color := Color("#1b1610")
## Per-design body shape.
var rump_drop := 0.0
var saber := 0.0
var bobtail := false
## Mesh density multiplier: stripes and spots are painted per vertex, so they need more.
var dense := 1


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.2, 3.2, 3.2)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "WindwhistleStalker"
	match variant:
		"lion": return _lion()
		"tiger": return _tiger()
		"sabertooth": return _sabertooth()
	return null


func _eyes(color: Color) -> void:
	glow.albedo_color = color.darkened(0.25); glow.emission = color
	glow.emission_energy_multiplier = 1.15


## Big-cat fur: darker along the back, pale belly, chin, muzzle and brow spots, with optional
## spots or tiger stripes.
func fur() -> Callable:
	var base := fur_base; var dark := fur_dark; var light := fur_light
	var spotty := spots; var stripy := stripes; var ink := stripe_color
	return func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
		var streak := Sculpt.fbm(Vector3(p.x * 10.0, p.y * 10.0, p.z * 3.0))
		var c := base.lerp(dark, clampf(n.y * 0.7 - 0.1 + streak * 0.5, 0.0, 1.0) * 0.7)
		var pale := smoothstep(-0.2, -0.7, n.y) * smoothstep(0.92, 0.7, p.y) * smoothstep(-0.95, -0.7, p.z)
		pale = maxf(pale, smoothstep(-0.93, -0.98, p.z) * smoothstep(1.0, 0.97, p.y))
		pale = maxf(pale, smoothstep(0.95, 0.91, p.y) * smoothstep(-0.8, -0.86, p.z))
		for side in [-1.0, 1.0]:
			pale = maxf(pale, smoothstep(0.03, 0.015, p.distance_to(Vector3(0.065 * side, 1.06, -0.93))))
		c = c.lerp(light, pale)
		if spotty > 0.0:
			var s := Sculpt.noise(Vector3(p.x * 22.0, p.y * 22.0, p.z * 22.0))
			c = c.lerp(dark.darkened(0.1), smoothstep(0.36, 0.46, s) * spotty * (1.0 - pale) * smoothstep(-0.6, 0.2, n.y))
		if stripy > 0.0:
			var wobble := Sculpt.fbm(p * 2.5) * 1.6 + Sculpt.noise(p * 9.0) * 0.5
			var band := sin(p.z * 44.0 + wobble + absf(p.x) * 6.0) if p.y > 0.55 or p.z < -0.75 else sin(p.y * 48.0 + wobble)
			if p.z < -0.75: band = sin(p.y * 70.0 + absf(p.x) * 30.0 + wobble)
			var width := 0.7 + 0.12 * Sculpt.noise(p * 3.0)
			c = c.lerp(ink, smoothstep(width, width + 0.08, band) * stripy * (1.0 - pale) * smoothstep(-0.8, -0.2, n.y))
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


## A shaggy lock of hair: a lumpy cone that droops toward its tip.
func lock(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, radius: float, droop := 0.3) -> void:
	var d := dir.normalized()
	var sag := Vector3(0, -length * droop, 0)
	s.tube([base, base + d * length * 0.5 + sag * 0.3, base + d * length + sag], [radius, radius * 0.75, 0.003], painter, {"sides": 6, "per": 2, "lump": 0.45, "cap_rings": 1, "cap1": false})


## A wheat-like seed head: a short chain of plump grains along a stalk end.
func seed_head(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float) -> void:
	var d := dir.normalized()
	for k in range(5):
		var at := base + d * length * (k + 0.5) / 5.0
		var side := d.cross(Vector3.UP).normalized() * (0.012 if k % 2 == 0 else -0.012)
		s.blob(at + side, Vector3(0.016, 0.016, 0.026), painter, {"lat": 4, "lon": 6, "basis": Basis.looking_at(d, Vector3.UP)})


## The shared big cat: body, head, jaw, ears, legs and tail on the game's rig.
func _cat(skin: Callable) -> Dictionary:
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	var rd := rump_drop; var d := dense
	body.tube([Vector3(0, 0.8 - rd, 0.7), Vector3(0, 0.86 - rd, 0.45), Vector3(0, 0.83 - rd * 0.5, 0.12), Vector3(0, 0.91, -0.2), Vector3(0, 0.96, -0.42)], [0.18, 0.24, 0.2, 0.27, 0.24], bp, {"sides": 14 * d, "per": 3 * d, "flat": 0.78, "lump": 0.03})
	body.blob(Vector3(0, 0.75, -0.32), Vector3(0.2, 0.27, 0.25), bp, {"lat": 8 * d, "lon": 12 * d})
	body.blob(Vector3(0, 0.71 - rd * 0.5, 0.08), Vector3(0.15, 0.12, 0.25), bp, {"lat": 6 * d, "lon": 10 * d})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.11 * side, 0.8 - rd, 0.5), Vector3(0.13, 0.19, 0.2), bp, {"lat": 7 * d, "lon": 10 * d})
		body.blob(Vector3(0.13 * side, 0.9, -0.32), Vector3(0.12, 0.17, 0.16), bp, {"lat": 7 * d, "lon": 10 * d})
	body.tube([Vector3(0, 0.93, -0.42), Vector3(0, 0.96, -0.6), Vector3(0, 0.98, -0.72)], [0.22, 0.18, 0.16], bp, {"sides": 12 * d, "per": 3 * d, "cap0": false})
	var parts := {"body": body, "body_painter": bp}

	var head := joint(root, "Head", Vector3(0, 0.99, -0.74))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin)
	var nose := hs.add_painter(func (p, n, v, w): return NOSE.lightened(clampf(n.y, 0.0, 1.0) * 0.12))
	var fang := hs.add_painter(func (p, n, v, w): return FANG.darkened((1.0 - v) * 0.08))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#120d0a"))
	var whisk := hs.add_painter(func (p, n, v, w): return WHISKER)
	# A long skull, heavy cheeks, a straight broad nose bridge and a big boxy muzzle.
	hs.blob(Vector3(0, 1.02, -0.81), Vector3(0.14, 0.115, 0.16), hp, {"lat": 9 * d, "lon": 14 * d})
	hs.tube([Vector3(0, 1.0, -0.86), Vector3(0, 0.975, -0.94), Vector3(0, 0.965, -1.0)], [0.09, 0.08, 0.072], hp, {"sides": 12 * d, "per": 3 * d, "square": 0.55, "flat": 1.2, "cap_rings": 2, "cap_len": 0.5})
	hs.tube([Vector3(0, 1.08, -0.84), Vector3(0, 1.045, -0.95), Vector3(0, 1.012, -1.02)], [0.062, 0.052, 0.042], hp, {"sides": 10 * d, "per": 3 * d, "square": 0.5, "flat": 1.25, "cap_rings": 2})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.088 * side, 0.975, -0.86), Vector3(0.078, 0.072, 0.08), hp, {"lat": 6 * d, "lon": 9 * d})
		hs.blob(Vector3(0.042 * side, 0.955, -0.99), Vector3(0.05, 0.045, 0.05), hp, {"lat": 6, "lon": 9})
		# A heavy scowling brow over small forward eyes with round pupils.
		hs.blob(Vector3(0.066 * side, 1.066, -0.93), Vector3(0.054, 0.02, 0.034), hp, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.34 * side)})
		hs.blob(Vector3(0.069 * side, 1.032, -0.955), Vector3(0.03, 0.019, 0.014), dark, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.25 * side)})
		hs.blob(Vector3(0.069 * side, 1.032, -0.971), Vector3(0.008, 0.008, 0.004), dark, {"lat": 3, "lon": 6})
		# Upper fangs: ordinary canines, or long curved sabres.
		var tooth := Vector3(0.042 * side, 0.94, -1.005)
		if saber > 0.0:
			hs.tube([tooth + Vector3(0, 0.02, 0), tooth + Vector3(0, -saber * 0.5, 0.0), tooth + Vector3(0, -saber, saber * 0.22)], [0.019, 0.015, 0.002], fang, {"sides": 8, "per": 3, "flat": 0.5, "side": Vector3.RIGHT, "cap_rings": 1, "cap1": false})
		else:
			hs.crystal(tooth, Vector3(0, -1, -0.1), 0.07, 0.012, fang, 6)
		for k in range(4):
			var from := Vector3(0.07 * side, 0.955 + k * 0.009, -0.995)
			hs.tube([from, from + Vector3(0.1 * side, 0.004 - k * 0.012, 0.03), from + Vector3(0.2 * side, -0.012 - k * 0.026, 0.08)], [0.0035, 0.0028, 0.0015], whisk, {"sides": 3, "per": 2, "cap_rings": 1})
	hs.blob(Vector3(0, 0.997, -1.032), Vector3(0.036, 0.022, 0.018), nose, {"lat": 4, "lon": 8})
	parts["head"] = head; parts["head_sculpt"] = hs; parts["head_painter"] = hp

	var jaw := joint(head, "Jaw", Vector3(0, 0.935, -0.86))
	var js := Sculpt.new(); var jp := js.add_painter(skin)
	var mouth := js.add_painter(func (p, n, v, w): return MOUTH)
	var jfang := js.add_painter(func (p, n, v, w): return FANG)
	js.tube([Vector3(0, 0.918, -0.84), Vector3(0, 0.902, -0.98)], [0.07, 0.048], jp, {"sides": 10, "per": 2, "square": 0.45, "flat": 1.1, "cap_rings": 2})
	js.blob(Vector3(0, 0.893, -0.965), Vector3(0.05, 0.03, 0.035), jp, {"lat": 5, "lon": 8})
	js.blob(Vector3(0, 0.928, -0.94), Vector3(0.045, 0.012, 0.06), mouth, {"lat": 4, "lon": 8})
	for side in [-1.0, 1.0]: js.crystal(Vector3(0.034 * side, 0.918, -0.99), Vector3(0, 1, -0.1), 0.035 if saber <= 0.0 else 0.02, 0.009, jfang, 5)
	parts["jaw"] = jaw; parts["jaw_sculpt"] = js

	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.069 * side, 1.032, -0.958), Vector3(0.025, 0.015, 0.014), white, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.25 * side)})
	parts["core_sculpt"] = es

	# Small, rounded ears set to the sides, pale inside and dark on the back.
	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.105 * side, 1.1, -0.78))
		var xs := Sculpt.new()
		var back := xs.add_painter(func (p, n, v, w): return fur_dark.darkened(0.45))
		var inner := xs.add_painter(func (p, n, v, w): return fur_light.darkened(0.1))
		xs.tube([Vector3(0.1 * side, 1.09, -0.775), Vector3(0.118 * side, 1.135, -0.77), Vector3(0.128 * side, 1.16, -0.766)], [0.048, 0.043, 0.022], back, {"sides": 9, "per": 2, "cap_rings": 2, "flat": 0.38, "side": Vector3.BACK})
		xs.tube([Vector3(0.1 * side, 1.095, -0.787), Vector3(0.116 * side, 1.132, -0.783), Vector3(0.124 * side, 1.15, -0.78)], [0.032, 0.028, 0.012], inner, {"sides": 9, "per": 2, "cap_rings": 2, "flat": 0.3, "side": Vector3.BACK})
		ears.append(ear); ear_sculpts.append(xs)
	parts["ears"] = ears; parts["ear_sculpts"] = ear_sculpts

	var hips: Array = []; var knees: Array = []
	for row in [["Front", -0.33, true], ["Hind", 0.5, false]]:
		for side in [-1.0, 1.0]:
			var front: bool = row[2]
			var label: String = row[0] + ("Left" if side < 0 else "Right")
			var hip := joint(root, label + "Leg", Vector3(0.16 * side, 0.8 - (0.0 if front else rd), row[1]))
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at: Vector3
			if front:
				knee_at = Vector3(0.18 * side, 0.42, -0.33)
				us.tube([Vector3(0.15 * side, 0.98, -0.3), Vector3(0.18 * side, 0.66, -0.36), knee_at], [0.14, 0.11, 0.085], up, {"sides": 11 * d, "per": 3 * d})
			else:
				knee_at = Vector3(0.18 * side, 0.46 - rd * 0.5, 0.36)
				us.tube([Vector3(0.13 * side, 0.96 - rd, 0.52), Vector3(0.18 * side, 0.68 - rd, 0.44), knee_at], [0.19, 0.14, 0.08], up, {"sides": 11 * d, "per": 3 * d})
			part(hip, "Upper", us)
			var knee := joint(hip, "Elbow" if front else "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cp := ls.add_painter(func (p, n, v, w): return FANG.darkened(0.15 + (1.0 - v) * 0.45))
			var paw: Vector3
			if front:
				paw = Vector3(0.18 * side, 0.055, -0.43)
				ls.tube([knee_at, Vector3(0.18 * side, 0.2, -0.36), paw + Vector3(0, 0.04, 0.03)], [0.085, 0.07, 0.07], lp, {"sides": 10 * d, "per": 3 * d})
				ls.blob(paw, Vector3(0.1, 0.058, 0.11), lp, {"lat": 6, "lon": 10})
			else:
				paw = Vector3(0.18 * side, 0.05, 0.44)
				ls.tube([knee_at, Vector3(0.18 * side, 0.33, 0.54), Vector3(0.18 * side, 0.12, 0.5), paw + Vector3(0, 0.04, 0.03)], [0.075, 0.06, 0.055, 0.055], lp, {"sides": 10 * d, "per": 3 * d})
				ls.blob(paw, Vector3(0.085, 0.05, 0.1), lp, {"lat": 6, "lon": 10})
			for c in range(4):
				var toe := paw + Vector3((c - 1.5) * (0.042 if front else 0.036), -0.005, -0.09)
				ls.blob(toe, Vector3(0.028, 0.034, 0.03), lp, {"lat": 4, "lon": 6})
				if front: ls.crystal(toe + Vector3(0, -0.01, -0.02), Vector3((c - 1.5) * 0.1, -0.5, -1.0), 0.05, 0.01, cp, 5)
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)
	parts["hips"] = hips; parts["knees"] = knees

	var tail := joint(root, "Tail", Vector3(0, 0.83 - rd, 0.68))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	var tts := Sculpt.new(); var ttp := tts.add_painter(skin)
	var tail_tip: Node3D
	if bobtail:
		ts.tube([Vector3(0, 0.84 - rd, 0.64), Vector3(0, 0.81 - rd, 0.78), Vector3(0, 0.76 - rd, 0.88)], [0.07, 0.06, 0.048], tp, {"sides": 10, "per": 2, "cap1": false})
		tail_tip = joint(tail, "TailTip", Vector3(0, 0.76 - rd, 0.88))
		tts.tube([Vector3(0, 0.76 - rd, 0.87), Vector3(0, 0.73 - rd, 0.93)], [0.048, 0.035], ttp, {"sides": 10, "per": 2, "cap0": false})
	else:
		ts.tube([Vector3(0, 0.84, 0.64), Vector3(0, 0.76, 0.9), Vector3(0, 0.6, 1.08), Vector3(0, 0.48, 1.24)], [0.066, 0.06, 0.054, 0.05], tp, {"sides": 9 * d, "per": 3 * d, "cap1": false})
		tail_tip = joint(tail, "TailTip", Vector3(0, 0.48, 1.23))
		tts.tube([Vector3(0, 0.48, 1.22), Vector3(0, 0.42, 1.42), Vector3(0, 0.45, 1.6), Vector3(0, 0.55, 1.72)], [0.05, 0.046, 0.043, 0.038], ttp, {"sides": 9 * d, "per": 3 * d, "cap0": false})
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


## A swaying clump (a mane section, a crest of grass) on its own joint.
func _frond(parts: Dictionary, parent: Node3D, name: String, at: Vector3, s: Sculpt) -> void:
	var j := joint(parent, name, at)
	part(j, "Blades", s)
	parts.fronds.append(j)


# ------------------------------------------------------------------ A: plains lion

func _lion() -> Node3D:
	_eyes(Color("#ffcf4a"))
	var parts := _cat(fur())
	# The mane: inner rings of thick dark hair round the face and neck, outer rings of grass
	# blades with ripe seed heads, in four sections that sway on their own.
	var hair_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#5e3c1f").lerp(Color("#a8773f"), clampf(v * 0.9 + Sculpt.noise(p * 9.0) * 0.3, 0.0, 1.0)).darkened(clampf(-n.y, 0.0, 1.0) * 0.15)
	var sections := {}
	for key in ["Top", "Left", "Right", "Chin"]:
		var s := Sculpt.new()
		sections[key] = [s, s.add_painter(hair_paint), s.add_painter(grass_paint()), s.add_painter(func (p, n, v, w): return Color("#e2c977").darkened(Sculpt.noise(p * 30.0) * 0.12))]
	for ring in range(5):
		var z := -0.78 + ring * 0.07
		var count := 16 + ring * 2
		var grass := ring >= 3
		for k in range(count):
			var ang := TAU * (k + ring * 0.5) / count
			var radial := Vector3(cos(ang), sin(ang) * 0.95, 0)
			var key := "Chin"
			if sin(ang) > 0.45: key = "Top"
			elif cos(ang) < -0.3: key = "Left"
			elif cos(ang) > 0.3: key = "Right"
			var sec: Array = sections[key]
			var center := Vector3(0, 0.99 - ring * 0.015, z)
			var base := center + radial * (0.15 + ring * 0.018)
			var dir := radial * (0.95 - ring * 0.12) + Vector3(0, 0.05, 0.3 + ring * 0.22)
			var tangent := Vector3(-sin(ang), cos(ang), 0)
			var length := 0.2 + ring * 0.04 + 0.06 * Sculpt.noise(Vector3(k, ring, 1) * 1.7)
			if sin(ang) < -0.6: length *= 1.15
			if grass:
				var tip := blade(sec[0], sec[2], base, dir, length + 0.06, 0.03, dir.normalized().cross(tangent), 0.3)
				if (k + ring) % 4 == 0 and sin(ang) > -0.3:
					seed_head(sec[0], sec[3], tip - dir.normalized() * 0.01, dir + Vector3(0, -0.3, 0.2), 0.12)
			else:
				var hair_dir := radial * (0.7 - ring * 0.12) + Vector3(0, 0.05, 0.55 + ring * 0.2)
				lock(sec[0], sec[1], base, hair_dir, length * (1.15 + ring * 0.15) * (0.75 if ring == 0 else 1.0), 0.036, 0.5)
				lock(sec[0], sec[1], base + tangent * 0.03 + Vector3(0, 0, 0.02), hair_dir + tangent * 0.2, length * (1.05 + ring * 0.15) * (0.75 if ring == 0 else 1.0), 0.03, 0.55)
	_frond(parts, parts.head, "ManeTop", Vector3(0, 1.12, -0.66), sections.Top[0])
	_frond(parts, parts.head, "ManeLeft", Vector3(-0.17, 0.98, -0.66), sections.Left[0])
	_frond(parts, parts.head, "ManeRight", Vector3(0.17, 0.98, -0.66), sections.Right[0])
	_frond(parts, root, "ManeChin", Vector3(0, 0.84, -0.66), sections.Chin[0])
	# A dark tuft at the tail tip with a few grass blades.
	var tts: Sculpt = parts.tail_sculpts[1]; var tuft := tts.add_painter(hair_paint); var gp := tts.add_painter(grass_paint())
	for k in range(8):
		var ang := TAU * k / 8.0
		var dir := Vector3(cos(ang) * 0.4, 0.7 + sin(ang) * 0.4, 0.7)
		lock(tts, tuft, Vector3(0, 0.55, 1.71) + Vector3(cos(ang), sin(ang), 0) * 0.02, dir, 0.13, 0.03, 0.2)
		if k % 2 == 0: blade(tts, gp, Vector3(0, 0.55, 1.71), dir + Vector3(0, 0.2, 0), 0.2, 0.018, dir.normalized().cross(Vector3(-sin(ang), cos(ang), 0)), 0.3)
	return _close(parts, 1.25)


# ------------------------------------------------------------------ B: grass tiger

func _tiger() -> Node3D:
	_eyes(Color("#e8ff7a"))
	fur_base = Color("#c99a45"); fur_dark = Color("#9a6a2a"); fur_light = Color("#efe4c6"); stripes = 1.0; stripe_color = Color("#2a2114"); dense = 2
	var parts := _cat(fur())
	# Tiger cheek ruffs.
	var hs: Sculpt = parts.head_sculpt; var rp := hs.add_painter(func (p, n, v, w): return fur_light.darkened(0.05 + v * 0.12))
	for side in [-1.0, 1.0]:
		for k in range(4):
			var at := Vector3(0.13 * side, 0.98 - k * 0.025, -0.86 + k * 0.03)
			lock(hs, rp, at, Vector3(side, -0.4 - k * 0.15, 0.6), 0.1, 0.03, 0.15)
	# A crest of grass blades down its neck and spine that sways as it stalks.
	var crest := Sculpt.new(); var gp := crest.add_painter(grass_paint())
	for k in range(16):
		var z := -0.58 + k * 0.075
		var y := 1.17 - absf(z + 0.4) * 0.12 if z < 0.0 else 1.12 - z * 0.12
		for side in [-1.0, 1.0]:
			var dir := Vector3(side * 0.35, 1.0, 0.75)
			blade(crest, gp, Vector3(0.02 * side, y - 0.03, z), dir, 0.16 + 0.07 * sin(k * 0.8) * (1.0 - absf(z) * 0.5), 0.026, Vector3(1, -0.35 * side, 0).normalized(), 0.25)
	_frond(parts, root, "GrassCrest", Vector3(0, 1.1, -0.1), crest)
	return _close(parts, 1.25)


# ------------------------------------------------------------------ C: sabertooth

func _sabertooth() -> Node3D:
	_eyes(Color("#ffb347"))
	fur_base = Color("#b49a6c"); fur_dark = Color("#6f5a3c"); fur_light = Color("#e6dbbf"); spots = 0.6; dense = 2
	rump_drop = 0.08; saber = 0.2; bobtail = true
	var parts := _cat(fur())
	return _close(parts, 1.25)
