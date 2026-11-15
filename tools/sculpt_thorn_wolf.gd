extends "res://tools/creature_kit.gd"
## The Thorn Wolf, sculpted by hand: a big wolf of the wild woods with brambles grown into
## its coat. Its core is its glowing eyes.

const FUR := Color("#4d5148")
const FUR_DARK := Color("#2c2f2a")
const FUR_LIGHT := Color("#9a957c")
const NOSE := Color("#1a1716")
const FANG := Color("#efe4c8")
const BONE := Color("#d8cfb4")

var fur_base := FUR
var fur_dark := FUR_DARK
var fur_light := FUR_LIGHT


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	glow.albedo_color = Color("#ffb444").darkened(0.2); glow.emission = Color("#ffb444")
	glow.emission_energy_multiplier = 1.0


func fur() -> Callable:
	var base := fur_base; var dark := fur_dark; var light := fur_light
	return func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
		var streak := Sculpt.fbm(Vector3(p.x * 9.0, p.y * 9.0, p.z * 3.0))
		var c := base.lerp(dark, clampf(n.y * 0.9 + streak * 0.6, 0.0, 1.0))
		c = c.lerp(light, clampf(-n.y * 0.9 - 0.1 + streak * 0.3, 0.0, 1.0))
		return c


const WHITE_FUR := Color("#e6e1d4")
const PINK := Color("#de8593")
const MOUTH := Color("#9c4352")


## Fur with white markings: chest blaze, belly, muzzle, brows, paws and tail tip.
func fur_accent() -> Callable:
	var base := fur()
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c: Color = base.call(p, n, v, w)
		var white := smoothstep(-0.25, -0.65, n.y) * smoothstep(0.8, 0.62, p.y)
		white = maxf(white, smoothstep(-0.32, -0.5, p.z) * smoothstep(-0.15, -0.5, n.z) * smoothstep(0.97, 0.85, p.y) * smoothstep(-0.95, -0.85, p.z))
		white = maxf(white, smoothstep(-0.84, -0.9, p.z) * smoothstep(1.045, 1.02, p.y))
		white = maxf(white, smoothstep(0.13, 0.08, p.y))
		white = maxf(white, smoothstep(1.0, 1.1, p.z))
		for side in [-1.0, 1.0]:
			white = maxf(white, smoothstep(0.045, 0.02, p.distance_to(Vector3(0.075 * side, 1.165, -0.835))))
		return c.lerp(WHITE_FUR.darkened(clampf(-n.y, 0.0, 1.0) * 0.15 + Sculpt.noise(p * 25.0) * 0.05), white)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ThornWolf"
	match variant:
		"briar": return _briar_wolf()
		"thornback": return _thornback()
		"bramble": return _bramble_hound()
	return null


## The shared wolf: body, head, legs and tail on the game's rig. Returns the rig parts so
## each design can add its own coat on top.
func _wolf(skin: Callable, paw_skin: Callable) -> Dictionary:
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	body.tube([Vector3(0, 0.82, 0.64), Vector3(0, 0.86, 0.4), Vector3(0, 0.84, 0.06), Vector3(0, 0.9, -0.27), Vector3(0, 1.0, -0.5)], [0.17, 0.23, 0.21, 0.26, 0.19], bp, {"sides": 14, "per": 3, "flat": 0.82, "lump": 0.05})
	body.blob(Vector3(0, 0.74, -0.27), Vector3(0.2, 0.28, 0.25), bp, {"lat": 8, "lon": 12})
	# A shaggy mane: lumpy rolls of fur round the neck.
	for ring in range(2):
		var pts: Array = []; var radii: Array = []
		for k in range(15):
			var ang := TAU * k / 13.0 + ring * 0.4
			pts.append(Vector3(cos(ang) * (0.2 - ring * 0.02), 0.96 + sin(ang) * (0.19 - ring * 0.02), -0.5 + ring * 0.13 + 0.03 * sin(ang * 3.0)))
			radii.append(0.085 - ring * 0.012 + 0.015 * Sculpt.noise(Vector3(k, ring, 0) * 1.3))
		body.tube(pts, radii, bp, {"sides": 9, "per": 3, "lump": 0.55, "side": Vector3.BACK})
	var parts := {"body": body, "body_painter": bp}

	var head := joint(root, "Head", Vector3(0, 1.03, -0.66))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin)
	var nose := hs.add_painter(func (p, n, v, w): return NOSE.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	var fang := hs.add_painter(func (p, n, v, w): return FANG)
	var pink := hs.add_painter(func (p, n, v, w): return PINK.darkened(clampf(-n.y, 0.0, 1.0) * 0.2))
	var mouth := hs.add_painter(func (p, n, v, w): return MOUTH)
	hs.blob(Vector3(0, 1.09, -0.72), Vector3(0.15, 0.14, 0.17), hp, {"lat": 9, "lon": 14})
	# A squared-off snout and a slightly open jaw, pink inside, with a tongue.
	hs.tube([Vector3(0, 1.075, -0.8), Vector3(0, 1.055, -0.94), Vector3(0, 1.04, -1.05)], [0.095, 0.08, 0.072], hp, {"sides": 12, "per": 3, "cap_rings": 2, "cap_len": 0.45, "square": 0.75, "flat": 1.1})
	hs.blob(Vector3(0, 1.065, -1.085), Vector3(0.05, 0.03, 0.03), nose, {"lat": 5, "lon": 8})
	hs.blob(Vector3(0, 0.975, -0.9), Vector3(0.062, 0.04, 0.13), mouth, {"lat": 6, "lon": 10})
	hs.tube([Vector3(0, 0.955, -0.78), Vector3(0, 0.925, -0.92), Vector3(0, 0.9, -1.02)], [0.07, 0.058, 0.05], hp, {"sides": 12, "per": 3, "cap_rings": 2, "cap_len": 0.5, "square": 0.6, "flat": 1.1})
	hs.tube([Vector3(0, 0.95, -0.82), Vector3(0, 0.945, -0.95), Vector3(0, 0.935, -1.04)], [0.04, 0.036, 0.03], pink, {"sides": 10, "per": 3, "cap_rings": 2, "flat": 0.35, "side": Vector3.UP})
	for side in [-1.0, 1.0]:
		hs.crystal(Vector3(0.045 * side, 1.0, -1.04), Vector3(0, -1, -0.1), 0.065, 0.013, fang, 5)
		hs.crystal(Vector3(0.04 * side, 0.94, -1.0), Vector3(0, 1, -0.1), 0.05, 0.011, fang, 5)
		hs.tube([Vector3(0.085 * side, 1.18, -0.68), Vector3(0.11 * side, 1.29, -0.65), Vector3(0.13 * side, 1.37, -0.63)], [0.065, 0.04, 0.004], hp, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.45, "side": Vector3.BACK})
		hs.tube([Vector3(0.086 * side, 1.19, -0.69), Vector3(0.108 * side, 1.285, -0.663), Vector3(0.125 * side, 1.345, -0.645)], [0.042, 0.026, 0.004], pink, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.35, "side": Vector3.BACK})
		hs.tube([Vector3(0.14 * side, 1.165, -0.8), Vector3(0.06 * side, 1.158, -0.86)], [0.026, 0.022], hp, {"sides": 7, "per": 2, "cap_rings": 1})
	parts["head"] = head; parts["head_sculpt"] = hs
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.078 * side, 1.118, -0.852), Vector3(0.036, 0.028, 0.024), white, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.25 * side)})
	parts["core_sculpt"] = es

	var feet: Array = []; var knees: Array = []
	for row in [["Front", -0.36, true], ["Hind", 0.48, false]]:
		for side in [-1.0, 1.0]:
			var label: String = row[0] + ("Left" if side < 0 else "Right")
			var front: bool = row[2]
			var hip_at := Vector3(0.205 * side, 0.63, row[1])
			var leg := joint(root, label + "Leg", hip_at)
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at: Vector3
			if front:
				knee_at = hip_at + Vector3(0, -0.24, 0.035)
				us.tube([Vector3(0.18 * side, 0.95, -0.29), Vector3(0.2 * side, 0.64, -0.36), knee_at], [0.14, 0.1, 0.072], up, {"sides": 10, "per": 3})
			else:
				knee_at = hip_at + Vector3(0, -0.24, -0.1)
				us.tube([Vector3(0.15 * side, 0.9, 0.52), Vector3(0.19 * side, 0.63, 0.47), knee_at], [0.19, 0.14, 0.075], up, {"sides": 10, "per": 3})
			part(leg, "Upper", us)
			var knee := joint(leg, "Knee" if not front else "Elbow", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var pp := ls.add_painter(paw_skin); var cp := ls.add_painter(func (p, n, v, w): return FANG.darkened(0.3 + (1.0 - v) * 0.4))
			var paw := Vector3(knee_at.x, 0.045, knee_at.z + (-0.06 if front else 0.08))
			if front: ls.tube([knee_at, Vector3(knee_at.x, 0.14, knee_at.z - 0.02), paw + Vector3(0, 0.02, 0.02)], [0.07, 0.056, 0.05], lp, {"sides": 9, "per": 3})
			else: ls.tube([knee_at, Vector3(knee_at.x, 0.26, knee_at.z + 0.12), Vector3(knee_at.x, 0.1, knee_at.z + 0.1), paw + Vector3(0, 0.02, 0.02)], [0.075, 0.06, 0.05, 0.05], lp, {"sides": 9, "per": 3})
			ls.blob(paw + Vector3(0, 0, -0.03), Vector3(0.068, 0.042, 0.085), pp, {"lat": 6, "lon": 10})
			for c in range(3): ls.crystal(paw + Vector3((c - 1) * 0.035, -0.01, -0.1), Vector3((c - 1) * 0.2, -0.6, -1.0), 0.05, 0.01, cp, 5)
			part(knee, "Lower", ls)
			feet.append(leg); knees.append(knee)
	parts["feet"] = feet; parts["knees"] = knees

	var tail := joint(root, "Tail", Vector3(0, 0.82, 0.64))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	ts.tube([Vector3(0, 0.85, 0.6), Vector3(0, 0.82, 0.82), Vector3(0, 0.72, 1.02), Vector3(0, 0.62, 1.16)], [0.065, 0.095, 0.085, 0.03], tp, {"sides": 10, "per": 3, "lump": 0.15})
	parts["tail"] = tail; parts["tail_sculpt"] = ts; parts["tail_painter"] = tp
	return parts


func _close(parts: Dictionary, scale: float) -> Node3D:
	part(root, "Body", parts.body)
	part(parts.head, "Head", parts.head_sculpt)
	var core := part(parts.head, "GlowingEyes", parts.core_sculpt, glow)
	core.material_override = glow
	part(parts.tail, "TailFur", parts.tail_sculpt)
	return _finish({"head": parts.head, "core": core, "arms": [], "forearms": [], "feet": parts.feet, "knees": parts.knees, "leaves": [parts.tail]}, scale)


## A: a dark grey-green wolf with bramble canes grown through its coat, thorns and red rose
## hips along its back and shoulders.
func _briar_wolf() -> Node3D:
	var parts := _wolf(fur_accent(), fur_accent())
	var body: Sculpt = parts.body
	briar(body, [Vector3(-0.2, 0.98, -0.42), Vector3(-0.12, 1.08, -0.2), Vector3(0.02, 1.08, 0.05), Vector3(0.1, 1.06, 0.3), Vector3(0.05, 1.0, 0.58)], 0.022, 6, 4, 4)
	briar(body, [Vector3(0.22, 1.0, -0.4), Vector3(0.18, 1.08, -0.22), Vector3(0.06, 1.1, -0.04), Vector3(-0.12, 1.06, 0.22), Vector3(-0.18, 0.96, 0.42)], 0.02, 6, 3, 3)
	var tp := body.add_painter(func (p, n, v, w): return Color("#d9c8a0").lerp(Color("#7b5134"), 1.0 - v))
	for k in range(7):
		var z := -0.3 + k * 0.14
		thorn(body, tp, Vector3(0, 1.08 - absf(z - 0.1) * 0.08, z), Vector3(0, 1, 0.5), 0.11 + 0.03 * sin(k), 0.024)
	briar(parts.tail_sculpt, [Vector3(0, 0.92, 0.66), Vector3(0.04, 0.9, 0.86), Vector3(-0.02, 0.8, 1.04)], 0.016, 3, 1, 1)
	return _close(parts, 1.15)


## B: a lean wolf of living wood: bark hide, moss on its shoulders and a ridge of big curved
## thorns from its neck to the tip of its tail.
func _thornback() -> Node3D:
	glow.albedo_color = Color("#9cff7a").darkened(0.3); glow.emission = Color("#9cff7a")
	material.albedo_texture = load("res://assets/cast/bark_detail_gray.png"); material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	var parts := _wolf(bark, bare)
	var body: Sculpt = parts.body
	var tp := body.add_painter(func (p, n, v, w): return Color("#e2d3a8").lerp(Color("#6e5136"), 1.0 - v))
	for k in range(10):
		var z := -0.52 + k * 0.12
		var y := 1.12 - absf(z + 0.05) * 0.14
		thorn(body, tp, Vector3(0, y, z), Vector3(0, 1.0, 0.7), 0.2 + 0.08 * sin(k * 0.9), 0.04, Vector3(0, 0, 0.05))
	for side in [-1.0, 1.0]: moss_clump(body, body.add_painter(moss), Vector3(0.14 * side, 1.02, -0.32), 0.1, 3)
	var tp2 = parts.tail_sculpt.add_painter(func (p, n, v, w): return Color("#e2d3a8").lerp(Color("#6e5136"), 1.0 - v))
	for k in range(4): thorn(parts.tail_sculpt, tp2, Vector3(0, 0.9 - k * 0.07, 0.72 + k * 0.13), Vector3(0, 1, 0.8), 0.12, 0.025)
	return _close(parts, 1.15)


## C: a shaggy hound with a great mane of bramble branches, leaves and berries round its
## neck, and a pale bone-coloured face.
func _bramble_hound() -> Node3D:
	fur_base = Color("#5a4636"); fur_dark = Color("#33261d"); fur_light = Color("#a08868")
	var face_skin := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c: Color = fur().call(p, n, v, w)
		return c.lerp(BONE.darkened(clampf(-n.y, 0.0, 1.0) * 0.3), smoothstep(-0.78, -0.86, p.z) * smoothstep(1.2, 1.12, p.y))
	var parts := _wolf(fur(), fur())
	parts.head_sculpt = Sculpt.new()
	# Rebuild the head with the bone-faced painter.
	var hs: Sculpt = parts.head_sculpt; var hp := hs.add_painter(face_skin)
	var nose := hs.add_painter(func (p, n, v, w): return NOSE)
	var fang := hs.add_painter(func (p, n, v, w): return FANG)
	hs.blob(Vector3(0, 1.09, -0.72), Vector3(0.15, 0.14, 0.17), hp, {"lat": 9, "lon": 14})
	hs.tube([Vector3(0, 1.07, -0.8), Vector3(0, 1.04, -0.95), Vector3(0, 1.01, -1.06)], [0.095, 0.072, 0.05], hp, {"sides": 11, "per": 3, "cap_rings": 2})
	hs.blob(Vector3(0, 1.02, -1.085), Vector3(0.042, 0.032, 0.03), nose, {"lat": 5, "lon": 8})
	hs.tube([Vector3(0, 0.98, -0.8), Vector3(0, 0.955, -0.99)], [0.065, 0.04], hp, {"sides": 9, "per": 2, "cap_rings": 2})
	for side in [-1.0, 1.0]:
		hs.crystal(Vector3(0.035 * side, 1.0, -1.0), Vector3(0, -1, -0.15), 0.07, 0.013, fang, 5)
		hs.tube([Vector3(0.085 * side, 1.18, -0.68), Vector3(0.11 * side, 1.29, -0.65), Vector3(0.13 * side, 1.37, -0.63)], [0.065, 0.04, 0.004], hp, {"sides": 8, "per": 2, "cap_rings": 1, "cap1": false, "flat": 0.45, "side": Vector3.BACK})
		hs.tube([Vector3(0.14 * side, 1.15, -0.8), Vector3(0.06 * side, 1.14, -0.86)], [0.03, 0.025], hp, {"sides": 7, "per": 2, "cap_rings": 1})
	var body: Sculpt = parts.body
	for k in range(12):
		var ang := -PI * 0.15 + PI * 1.3 * k / 11.0
		var start := Vector3(cos(ang) * 0.16, 1.0 + sin(ang) * 0.15, -0.46)
		var out := Vector3(cos(ang), sin(ang) * 0.8 + 0.2, 0.9).normalized()
		briar(body, [start, start + out * 0.12 + Vector3(0, 0.03, 0), start + out * 0.26 + Vector3(0, 0.02, 0.04)], 0.016, 1, 1, 2)
	return _close(parts, 1.15)
