extends "res://tools/creature_kit.gd"
## The Thistle Jackal of the Windbell Plains, sculpted by hand: a lean, long-legged jackal
## that hunts in packs through the meadows, with big upright ears and a narrow muzzle.
##   thistleback - a golden jackal with a dark saddle, purple thistle heads and spiny thistle
##                 leaves growing along its back
##   burrcoat    - a shaggy, dusty jackal with spiky burrs caught all through its coat
##   thistledown - a red, black-legged maned jackal with a mane of white thistledown fluff

const NOSE := Color("#1c1715")
const FANG := Color("#efe5cb")
const MOUTH := Color("#5a2228")
const WHISKER := Color("#e8e2d2")
const THISTLE := Color("#9b4fa8")
const THISTLE_TIP := Color("#d68bd6")
const SPINY := Color("#5f7a3a")

var fur_base := Color("#b98f55")
var fur_saddle := Color("#3e3a33")
var fur_belly := Color("#e8dcc0")
var fur_leg := Color("#b06d3a")
var saddle := 1.0
var dark_legs := false
var leg_len := 1.0


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.4, 3.4, 3.4)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ThistleJackal"
	match variant:
		"thistleback": return _thistleback()
		"burrcoat": return _burrcoat()
		"thistledown": return _thistledown()
	return null


func _eyes(color: Color) -> void:
	glow.albedo_color = color.darkened(0.25); glow.emission = color
	glow.emission_energy_multiplier = 1.15


## Jackal fur: a grizzled dark saddle over the back, pale throat and belly, warm russet legs
## and muzzle.
func fur() -> Callable:
	var base := fur_base; var dark := fur_saddle; var belly := fur_belly; var leg := fur_leg
	var sad := saddle; var black_legs := dark_legs
	return func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
		var grain := Sculpt.fbm(Vector3(p.x * 11.0, p.y * 11.0, p.z * 4.0))
		var c := base.lerp(base.darkened(0.2), clampf(grain * 0.6 + 0.3, 0.0, 1.0))
		var on_back := smoothstep(0.25, 0.7, n.y) * smoothstep(0.66, 0.8, p.y) * smoothstep(-0.5, -0.3, p.z) * smoothstep(0.62, 0.45, p.z)
		var flecks := smoothstep(0.2, 0.5, Sculpt.noise(p * 40.0))
		c = c.lerp(dark.lerp(Color("#bdb6a6"), flecks * 0.45), on_back * sad)
		var legs := smoothstep(0.5, 0.36, p.y)
		c = c.lerp(Color("#151210") if black_legs else leg, legs * (0.95 if black_legs else 0.6))
		var pale := smoothstep(-0.25, -0.7, n.y) * smoothstep(0.85, 0.6, p.y) * smoothstep(0.55, 0.3, p.y + 0.0)
		pale = maxf(pale, smoothstep(-0.25, -0.7, n.y) * smoothstep(0.62, 0.7, p.y))
		pale = maxf(pale, smoothstep(0.98, 0.94, p.y) * smoothstep(-0.55, -0.68, p.z) * smoothstep(0.0, -0.3, n.y + 0.2))
		c = c.lerp(belly, pale * (1.0 - legs))
		c = c.lerp(leg.lightened(0.05), smoothstep(-0.78, -0.86, p.z) * smoothstep(0.96, 1.0, p.y) * 0.5)
		return c


## A purple thistle head: a spiny green bulb under a brush of purple florets.
func thistle(s: Sculpt, green: int, purple: int, base: Vector3, dir: Vector3, size: float) -> void:
	var d := dir.normalized()
	s.tube([base - d * size * 0.6, base + d * size * 0.6], [size * 0.25, size * 0.25], green, {"sides": 5, "per": 1, "cap_rings": 1})
	var bulb := base + d * size * 1.0
	s.blob(bulb, Vector3.ONE * size * 0.55, green, {"lat": 4, "lon": 7})
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	for k in range(6):
		var out := (side.rotated(d, TAU * k / 6.0) + d * 0.2).normalized()
		s.crystal(bulb + out * size * 0.4, out - d * 0.3, size * 0.45, size * 0.07, green, 3)
	s.tube([bulb + d * size * 0.3, bulb + d * size * 0.75, bulb + d * size * 1.05], [size * 0.42, size * 0.55, size * 0.5], purple, {"sides": 10, "per": 1, "ridges": 10, "ridge": 0.28, "cap_rings": 2, "cap_len": 0.5})


## A spiny thistle leaf: a flat lobed blade with spines along its edges.
func thistle_leaf(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, thin: Vector3) -> void:
	var d := dir.normalized()
	var across := d.cross(thin).normalized()
	var tip := base + d * length + Vector3(0, -length * 0.15, 0)
	s.tube([base, base.lerp(tip, 0.45) + Vector3(0, length * 0.06, 0), tip], [width * 0.5, width, 0.003], painter, {"sides": 6, "per": 2, "flat": 0.15, "side": thin, "cap_rings": 1, "cap1": false})
	for k in range(3):
		var t := 0.3 + k * 0.22
		var at := base.lerp(tip, t)
		var w := width * (1.0 - absf(t - 0.45) * 1.2)
		for side in [-1.0, 1.0]:
			s.crystal(at + across * w * 0.8 * side, across * side + d * 0.6, width * 0.7, width * 0.08, painter, 3)


## A spiky burr: a round seed ball with hooked spines.
func burr(s: Sculpt, painter: int, at: Vector3, size: float) -> void:
	s.blob(at, Vector3.ONE * size, painter, {"lat": 4, "lon": 6})
	for k in range(7):
		var a := k * 2.4; var b := k * 1.3
		var out := Vector3(cos(a) * sin(b + 0.6), cos(b + 0.6), sin(a) * sin(b + 0.6)).normalized()
		s.crystal(at + out * size * 0.7, out, size * 0.9, size * 0.12, painter, 3)


## The shared jackal: body, head, jaw, ears, legs and tail on the game's rig.
func _jackal(skin: Callable) -> Dictionary:
	var L := leg_len
	var lift := (L - 1.0) * 0.4
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	var up := Vector3(0, lift, 0)
	body.tube([Vector3(0, 0.74, 0.5) + up, Vector3(0, 0.78, 0.3) + up, Vector3(0, 0.76, 0.02) + up, Vector3(0, 0.8, -0.22) + up, Vector3(0, 0.86, -0.4) + up], [0.13, 0.16, 0.125, 0.17, 0.15], bp, {"sides": 13, "per": 3, "flat": 0.8, "lump": 0.03})
	body.blob(Vector3(0, 0.71, -0.26) + up, Vector3(0.12, 0.17, 0.15), bp, {"lat": 7, "lon": 11})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.075 * side, 0.74, 0.36) + up, Vector3(0.1, 0.14, 0.15), bp, {"lat": 6, "lon": 9})
	body.tube([Vector3(0, 0.84, -0.38) + up, Vector3(0, 0.92, -0.5) + up, Vector3(0, 0.98, -0.58) + up], [0.13, 0.1, 0.09], bp, {"sides": 11, "per": 3, "cap0": false})
	var parts := {"body": body, "body_painter": bp, "lift": lift}

	var head := joint(root, "Head", Vector3(0, 0.99, -0.6) + up)
	var hs := Sculpt.new(); var hp := hs.add_painter(skin)
	var nose := hs.add_painter(func (p, n, v, w): return NOSE.lightened(clampf(n.y, 0.0, 1.0) * 0.15))
	var fang := hs.add_painter(func (p, n, v, w): return FANG)
	var dark := hs.add_painter(func (p, n, v, w): return Color("#120d0a"))
	var whisk := hs.add_painter(func (p, n, v, w): return WHISKER)
	var h := up
	# A flat-topped skull running smoothly into a long, tapering muzzle.
	hs.blob(Vector3(0, 1.012, -0.64) + h, Vector3(0.1, 0.085, 0.115), hp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 1.0, -0.64) + h, Vector3(0, 0.993, -0.72) + h, Vector3(0, 0.975, -0.81) + h, Vector3(0, 0.957, -0.905) + h], [0.08, 0.06, 0.044, 0.03], hp, {"sides": 11, "per": 3, "square": 0.25, "flat": 1.1, "cap0": false, "cap_rings": 2, "cap_len": 0.5})
	hs.blob(Vector3(0, 0.961, -0.935) + h, Vector3(0.023, 0.017, 0.016), nose, {"lat": 4, "lon": 7})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.042 * side, 1.046, -0.735) + h, Vector3(0.03, 0.011, 0.02), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, 0.35 * side)})
		hs.blob(Vector3(0.05 * side, 1.024, -0.751) + h, Vector3(0.006, 0.006, 0.004), dark, {"lat": 3, "lon": 6})
		hs.crystal(Vector3(0.022 * side, 0.948, -0.855) + h, Vector3(0, -1, -0.05), 0.03, 0.007, fang, 5)
		for k in range(3):
			var from := Vector3(0.03 * side, 0.955 + k * 0.007, -0.88) + h
			hs.tube([from, from + Vector3(0.07 * side, 0.002 - k * 0.01, 0.03), from + Vector3(0.13 * side, -0.01 - k * 0.02, 0.07)], [0.0028, 0.002, 0.001], whisk, {"sides": 3, "per": 2, "cap_rings": 1})
	parts["head"] = head; parts["head_sculpt"] = hs; parts["head_painter"] = hp

	var jaw := joint(head, "Jaw", Vector3(0, 0.955, -0.7) + h)
	var js := Sculpt.new(); var jp := js.add_painter(skin)
	var mouth := js.add_painter(func (p, n, v, w): return MOUTH)
	var jfang := js.add_painter(func (p, n, v, w): return FANG)
	js.tube([Vector3(0, 0.945, -0.7) + h, Vector3(0, 0.932, -0.87) + h], [0.045, 0.024], jp, {"sides": 9, "per": 2, "square": 0.3, "cap_rings": 2})
	js.blob(Vector3(0, 0.95, -0.82) + h, Vector3(0.026, 0.01, 0.055), mouth, {"lat": 4, "lon": 7})
	for side in [-1.0, 1.0]: js.crystal(Vector3(0.017 * side, 0.94, -0.84) + h, Vector3(0, 1, -0.05), 0.022, 0.006, jfang, 5)
	parts["jaw"] = jaw; parts["jaw_sculpt"] = js

	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.05 * side, 1.024, -0.739) + h, Vector3(0.022, 0.012, 0.012), white, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.3 * side)})
	parts["core_sculpt"] = es

	# Big upright ears, dark on the back and pale and furry inside.
	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.06 * side, 1.07, -0.63) + h)
		var xs := Sculpt.new()
		var back := xs.add_painter(func (p, n, v, w): return fur_base.darkened(0.25 + v * 0.35))
		var inner := xs.add_painter(func (p, n, v, w): return fur_belly.darkened(0.05 + v * 0.1))
		xs.tube([Vector3(0.058 * side, 1.06, -0.625) + h, Vector3(0.08 * side, 1.15, -0.62) + h, Vector3(0.1 * side, 1.25, -0.61) + h], [0.052, 0.036, 0.004], back, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.4, "side": Vector3.BACK})
		xs.tube([Vector3(0.059 * side, 1.065, -0.638) + h, Vector3(0.079 * side, 1.145, -0.634) + h, Vector3(0.097 * side, 1.23, -0.625) + h], [0.036, 0.024, 0.003], inner, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.3, "side": Vector3.BACK})
		ears.append(ear); ear_sculpts.append(xs)
	parts["ears"] = ears; parts["ear_sculpts"] = ear_sculpts

	# Long slim legs on small neat paws.
	var hips: Array = []; var knees: Array = []
	for row in [["Front", -0.28, true], ["Hind", 0.36, false]]:
		for side in [-1.0, 1.0]:
			var front: bool = row[2]
			var label: String = row[0] + ("Left" if side < 0 else "Right")
			var hip := joint(root, label + "Leg", Vector3(0.11 * side, 0.7 + lift, row[1]))
			var us := Sculpt.new(); var upp := us.add_painter(skin)
			var knee_at: Vector3
			if front:
				knee_at = Vector3(0.12 * side, 0.38 * L, -0.28)
				us.tube([Vector3(0.1 * side, 0.86 + lift, -0.25), Vector3(0.12 * side, 0.6 * L, -0.3), knee_at], [0.09, 0.062, 0.042], upp, {"sides": 9, "per": 3})
			else:
				knee_at = Vector3(0.12 * side, 0.42 * L, 0.24)
				us.tube([Vector3(0.09 * side, 0.82 + lift, 0.38), Vector3(0.12 * side, 0.6 * L, 0.32), knee_at], [0.12, 0.085, 0.048], upp, {"sides": 9, "per": 3})
			part(hip, "Upper", us)
			var knee := joint(hip, "Elbow" if front else "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var cp := ls.add_painter(func (p, n, v, w): return Color("#2a231d"))
			var paw: Vector3
			if front:
				paw = Vector3(0.12 * side, 0.032, -0.34)
				ls.tube([knee_at, Vector3(0.12 * side, 0.15 * L, -0.3), paw + Vector3(0, 0.03, 0.025)], [0.04, 0.032, 0.031], lp, {"sides": 8, "per": 3})
			else:
				paw = Vector3(0.12 * side, 0.032, 0.32)
				ls.tube([knee_at, Vector3(0.12 * side, 0.28 * L, 0.38), Vector3(0.12 * side, 0.1, 0.36), paw + Vector3(0, 0.03, 0.025)], [0.044, 0.035, 0.031, 0.031], lp, {"sides": 8, "per": 3})
			ls.blob(paw, Vector3(0.045, 0.03, 0.058), lp, {"lat": 5, "lon": 8})
			for c in range(4):
				var toe := paw + Vector3((c - 1.5) * 0.022, -0.004, -0.05)
				ls.blob(toe, Vector3(0.015, 0.02, 0.018), lp, {"lat": 3, "lon": 5})
				ls.crystal(toe + Vector3(0, -0.008, -0.012), Vector3(0, -0.4, -1.0), 0.025, 0.006, cp, 4)
			part(knee, "Lower", ls)
			hips.append(hip); knees.append(knee)
	parts["hips"] = hips; parts["knees"] = knees

	# A bushy tail carried low, with a black tip.
	var tail := joint(root, "Tail", Vector3(0, 0.74, 0.52) + up)
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	var tip_paint := ts.add_painter(func (p, n, v, w): return Color("#1a1612"))
	ts.tube([Vector3(0, 0.75, 0.5) + up, Vector3(0, 0.64, 0.68) + up, Vector3(0, 0.48, 0.8) + up, Vector3(0, 0.38, 0.86) + up], [0.045, 0.08, 0.078, 0.05], tp, {"sides": 10, "per": 3, "lump": 0.25, "cap1": false})
	ts.tube([Vector3(0, 0.39, 0.855) + up, Vector3(0, 0.33, 0.885) + up, Vector3(0, 0.28, 0.9) + up], [0.05, 0.04, 0.012], tip_paint, {"sides": 10, "per": 2, "lump": 0.3, "cap0": false})
	parts["tails"] = [tail]; parts["tail_sculpts"] = [ts]
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


func _frond(parts: Dictionary, parent: Node3D, name: String, at: Vector3, s: Sculpt) -> void:
	var j := joint(parent, name, at)
	part(j, "Plants", s)
	parts.fronds.append(j)


## Bristly tufts of fur standing up along the nape and shoulders.
func _bristles(s: Sculpt, painter: int, lift: float, count: int, length: float) -> void:
	for k in range(count):
		var t := float(k) / (count - 1)
		var z := lerpf(-0.56, -0.18, t)
		var y := lerpf(1.06, 0.97, t) + lift
		for side in [-1.0, 1.0]:
			var at := Vector3(0.035 * side, y - 0.03, z)
			tufts(s, painter, [at], [Vector3(side * 0.35, 1.0, 0.55)], length * (1.0 - absf(t - 0.4) * 0.6), 0.022)


# ------------------------------------------------------------------ A: thistleback

func _thistleback() -> Node3D:
	_eyes(Color("#ffc94a"))
	var parts := _jackal(fur())
	var lift: float = parts.lift
	_bristles(parts.body, parts.body_painter, lift, 7, 0.11)
	# A row of thistles grows from its back: purple heads on spiny stems, with jagged spiny
	# leaves splaying out over its shoulders and hips.
	var plants := Sculpt.new()
	var green := plants.add_painter(func (p, n, v, w): return SPINY.lerp(Color("#8fa65a"), clampf(n.y * 0.4 + Sculpt.noise(p * 15.0) * 0.4 + 0.3, 0.0, 1.0)))
	var purple := plants.add_painter(func (p, n, v, w): return THISTLE.lerp(THISTLE_TIP, clampf(v * 0.8 + Sculpt.noise(p * 40.0) * 0.4, 0.0, 1.0)))
	for spec in [[-0.32, 1.02, 0.0, 0.05], [-0.16, 0.99, 0.15, 0.06], [0.0, 0.94, -0.12, 0.045], [0.16, 0.95, 0.1, 0.055], [0.32, 0.93, -0.06, 0.04]]:
		var base := Vector3(spec[2] * 0.25, float(spec[1]) + lift, spec[0])
		thistle(plants, green, purple, base, Vector3(spec[2], 1.0, 0.25), spec[3])
	for spec in [[-0.3, 1.0, -1.0], [-0.3, 1.0, 1.0], [0.3, 0.94, -1.0], [0.3, 0.94, 1.0], [-0.05, 0.96, -1.0], [0.1, 0.95, 1.0]]:
		var side: float = spec[2]
		var dir := Vector3(side * 0.9, 0.45, 0.35)
		thistle_leaf(plants, green, Vector3(0.04 * side, float(spec[1]) + lift - 0.01, spec[0]), dir, 0.2, 0.04, Vector3(-0.35 * side, 1.0, 0.0).normalized())
	_frond(parts, root, "Thistles", Vector3(0, 0.98 + lift, 0.0), plants)
	return _close(parts, 1.1)


# ------------------------------------------------------------------ B: burr-coat

func _burrcoat() -> Node3D:
	_eyes(Color("#ffdb6e"))
	fur_base = Color("#a28c6c"); fur_saddle = Color("#5b4e40"); fur_belly = Color("#ded2b8"); fur_leg = Color("#9a7450"); saddle = 0.7
	var parts := _jackal(fur())
	var lift: float = parts.lift
	var body: Sculpt = parts.body; var bp: int = parts.body_painter
	# A shaggy ruff of bristly seed-like fur round its neck and down its back.
	_bristles(body, bp, lift, 9, 0.14)
	for ring in range(2):
		for k in range(11):
			var ang := PI * (-0.15 + 1.3 * k / 10.0)
			var radial := Vector3(cos(ang), sin(ang), 0)
			tufts(body, bp, [Vector3(0, 0.9 + lift, -0.48 + ring * 0.09) + radial * 0.11], [radial * 0.7 + Vector3(0, -0.1, 0.7)], 0.12, 0.026)
	# Spiky burrs caught all through its coat.
	var bur := body.add_painter(func (p, n, v, w): return Color("#4a2f18").lerp(Color("#8a5a2a"), clampf(Sculpt.noise(p * 30.0) + 0.4, 0.0, 1.0)))
	var spots := [Vector3(0.1, 0.92, -0.42), Vector3(-0.12, 0.9, -0.36), Vector3(0.14, 0.83, -0.2), Vector3(-0.15, 0.82, -0.12), Vector3(0.08, 0.92, -0.05),
		Vector3(-0.06, 0.92, 0.12), Vector3(0.13, 0.8, 0.2), Vector3(-0.14, 0.82, 0.3), Vector3(0.1, 0.88, 0.4), Vector3(-0.04, 0.92, 0.33),
		Vector3(0.0, 0.7, -0.15), Vector3(0.16, 0.7, 0.35), Vector3(-0.16, 0.66, 0.42)]
	for at in spots: burr(body, bur, at + Vector3(0, lift, 0), 0.032)
	var ts: Sculpt = parts.tail_sculpts[0]; var tb := ts.add_painter(func (p, n, v, w): return Color("#7a5631"))
	for at in [Vector3(0.05, 0.64, 0.7), Vector3(-0.06, 0.52, 0.8), Vector3(0.03, 0.46, 0.84)]: burr(ts, tb, at + Vector3(0, lift, 0), 0.028)
	return _close(parts, 1.1)


# ------------------------------------------------------------------ C: thistledown

func _thistledown() -> Node3D:
	_eyes(Color("#ffb54a"))
	fur_base = Color("#b8642f"); fur_saddle = Color("#2a201a"); fur_belly = Color("#ead9bd"); fur_leg = Color("#2a201a"); saddle = 0.0; dark_legs = true; leg_len = 1.18
	var parts := _jackal(fur())
	var lift: float = parts.lift
	# A mane of white thistledown: soft fluffy tufts from the crown down the neck and spine,
	# swaying as it moves; the same fluff on its tail tip.
	var down_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#d8d0bd").lerp(Color("#fbf8ef"), clampf(v * 1.2 + Sculpt.noise(p * 22.0) * 0.2, 0.0, 1.0))
	var mane := Sculpt.new(); var dp := mane.add_painter(down_paint)
	var seed := mane.add_painter(func (p, n, v, w): return Color("#4a3a2a"))
	for k in range(22):
		var t := k / 21.0
		var z := lerpf(-0.62, 0.1, t) + Sculpt.noise(Vector3(k, 1, 0) * 3.1) * 0.03
		var x := Sculpt.noise(Vector3(k, 2, 0) * 2.7) * 0.09
		var y := lerpf(1.08, 0.93, t) + lift + 0.01 - absf(x) * 0.4
		var r := 0.042 * (1.0 - absf(t - 0.3) * 0.6) * (0.8 + 0.4 * absf(Sculpt.noise(Vector3(k, 3, 0) * 1.7)))
		var c := Vector3(x, y + r * 0.6, z)
		mane.blob(c, Vector3(r, r * 0.9, r * 1.1), dp, {"lat": 5, "lon": 8, "lump": 0.35})
		for wisp in range(3):
			var a2 := k * 1.7 + wisp * 2.1
			var d := Vector3(cos(a2) * 0.8, 0.6, sin(a2) * 0.8 + 0.3).normalized()
			mane.tube([c, c + d * r * 1.6, c + d * r * 2.3], [r * 0.25, r * 0.18, 0.002], dp, {"sides": 4, "per": 1, "cap_rings": 1})
		mane.blob(Vector3(x * 0.6, y - 0.01, z), Vector3(0.008, 0.008, 0.008), seed, {"lat": 3, "lon": 5})
	_frond(parts, root, "Thistledown", Vector3(0, 1.0 + lift, -0.3), mane)
	var ts: Sculpt = parts.tail_sculpts[0]; var tdp := ts.add_painter(down_paint)
	for k in range(6):
		var ang := TAU * k / 6.0
		var dir := Vector3(cos(ang) * 0.6, -0.5, 0.3 + sin(ang) * 0.6)
		var base := Vector3(0, 0.33 + lift, 0.88)
		ts.tube([base, base + dir.normalized() * 0.06, base + dir.normalized() * 0.11], [0.015, 0.035, 0.004], tdp, {"sides": 7, "per": 2, "lump": 0.8, "cap_rings": 1})
	return _close(parts, 1.1)
