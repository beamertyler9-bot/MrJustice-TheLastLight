extends "res://tools/creature_kit.gd"
## The Ironhide Boar, sculpted by hand: a big tusked boar that lowers its head and charges.
## Its core is its small glowing eyes.

const HIDE := Color("#5b4434")
const HIDE_DARK := Color("#2e221a")
const HIDE_LIGHT := Color("#8a6e55")
const SNOUT := Color("#c9877a")
const SNOUT_DARK := Color("#3a201c")
const HOOF := Color("#2a2420")
const IVORY := Color("#efe3c4")
const IRON_PLATE := Color("#5d6166")
const RUST := Color("#9a5a32")
const BONE_PLATE := Color("#d6c8a6")

var hide_base := HIDE
var hide_dark := HIDE_DARK
var hide_light := HIDE_LIGHT


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	glow.albedo_color = Color("#ff8a3a").darkened(0.2); glow.emission = Color("#ff8a3a")
	glow.emission_energy_multiplier = 1.0


func hide() -> Callable:
	var base := hide_base; var dark := hide_dark; var light := hide_light
	return func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
		var streak := Sculpt.fbm(Vector3(p.x * 10.0, p.y * 10.0, p.z * 3.0))
		var c := base.lerp(dark, clampf(n.y * 0.7 + streak * 0.5, 0.0, 1.0))
		c = c.lerp(light, clampf(-n.y * 0.6 + streak * 0.2, 0.0, 1.0))
		return c.lerp(HOOF, smoothstep(0.3, 0.12, p.y) * 0.7)


static func iron_plate(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := IRON_PLATE.lerp(IRON_PLATE.lightened(0.3), clampf(n.y * 0.5 + Sculpt.noise(p * 8.0) * 0.3, 0.0, 1.0))
	return c.lerp(RUST, smoothstep(0.2, 0.45, Sculpt.fbm(p * 6.0 + Vector3(3, 1, 7))) * 0.75)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "IronhideBoar"
	match variant:
		"ironback": return _ironback()
		"mossback": return _mossback()
		"razorback": return _razorback()
	return null


const SPINE := [Vector3(0, 0.7, 0.68), Vector3(0, 0.78, 0.4), Vector3(0, 0.82, 0.05), Vector3(0, 0.86, -0.22), Vector3(0, 0.78, -0.4)]
const SPINE_R := [0.28, 0.37, 0.4, 0.42, 0.3]
var lean_now := 1.0


## The height of the top of the back at z.
func back_y(z: float) -> float:
	for k in range(SPINE.size() - 1):
		var a: Vector3 = SPINE[k]; var b: Vector3 = SPINE[k + 1]
		if z <= a.z and z >= b.z:
			var t := (a.z - z) / (a.z - b.z)
			return lerpf(a.y + SPINE_R[k] * lean_now, b.y + SPINE_R[k + 1] * lean_now, t)
	return 0.9


func _boar(skin: Callable, lean: float, tusks := true) -> Dictionary:
	var parts := {}
	lean_now = lean
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	var radii: Array = []
	for r in SPINE_R: radii.append(r * lean)
	body.tube(SPINE, radii, bp, {"sides": 14, "per": 3, "flat": 0.82, "lump": 0.06})
	parts.body = body; parts.body_painter = bp
	var head := joint(root, "Head", Vector3(0, 0.67, -0.58))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin)
	var sp := hs.add_painter(func (p, n, v, w): return SNOUT.lerp(SNOUT_DARK, smoothstep(-0.6, -0.9, n.z) * 0.4))
	var nostril := hs.add_painter(func (p, n, v, w): return SNOUT_DARK)
	var ivory := hs.add_painter(func (p, n, v, w): return IVORY.darkened((1.0 - v) * 0.25))
	hs.tube([Vector3(0, 0.8, -0.5), Vector3(0, 0.72, -0.72), Vector3(0, 0.62, -0.92), Vector3(0, 0.55, -1.08)], [0.27, 0.22, 0.15, 0.11], hp, {"sides": 13, "per": 3, "cap_len": 0.4, "square": 0.35, "flat": 1.1})
	hs.blob(Vector3(0, 0.54, -1.12), Vector3(0.11, 0.085, 0.04), sp, {"lat": 6, "lon": 12})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.04 * side, 0.545, -1.155), Vector3(0.02, 0.026, 0.01), nostril, {"lat": 4, "lon": 6})
		hs.tube([Vector3(0.17 * side, 0.92, -0.6), Vector3(0.26 * side, 1.02, -0.58), Vector3(0.3 * side, 1.08, -0.53)], [0.07, 0.045, 0.004], hp, {"sides": 8, "per": 2, "cap1": false, "flat": 0.45, "side": Vector3.BACK})
		if tusks: hs.tube([Vector3(0.08 * side, 0.5, -0.98), Vector3(0.16 * side, 0.56, -1.08), Vector3(0.22 * side, 0.69, -1.06), Vector3(0.22 * side, 0.78, -0.98)], [0.04, 0.032, 0.02, 0.003], ivory, {"sides": 8, "per": 3, "cap1": false})
		hs.tube([Vector3(0.2 * side, 0.85, -0.76), Vector3(0.11 * side, 0.86, -0.84)], [0.035, 0.03], hp, {"sides": 7, "per": 2, "cap_rings": 1})
	hs.blob(Vector3(0, 0.5, -0.86), Vector3(0.14, 0.07, 0.19), hp, {"lat": 6, "lon": 10})
	parts.head = head; parts.head_sculpt = hs; parts.head_painter = hp
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.15 * side, 0.8, -0.83), Vector3(0.024, 0.017, 0.017), ew, {"lat": 4, "lon": 7})
	parts.eyes = es

	var feet: Array = []; var knees: Array = []
	for row in [["Front", -0.35, true], ["Hind", 0.48, false]]:
		for side in [-1.0, 1.0]:
			var front: bool = row[2]
			var hip_at := Vector3(0.3 * side, 0.64, row[1])
			var leg := joint(root, row[0] + ("Left" if side < 0 else "Right") + "Leg", hip_at)
			var us := Sculpt.new(); var up := us.add_painter(skin)
			var knee_at := hip_at + (Vector3(0, -0.25, 0.035) if front else Vector3(0, -0.25, -0.1))
			if front: us.tube([Vector3(0.25 * side, 0.86, -0.32), Vector3(0.29 * side, 0.6, -0.36), knee_at], [0.16 * lean, 0.115, 0.075], up, {"sides": 10, "per": 3})
			else: us.tube([Vector3(0.24 * side, 0.86, 0.55), Vector3(0.29 * side, 0.6, 0.5), knee_at], [0.21 * lean, 0.145, 0.075], up, {"sides": 10, "per": 3})
			part(leg, "Upper", us)
			var knee := joint(leg, "Knee", knee_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(skin); var hf := ls.add_painter(func (p, n, v, w): return HOOF.lightened(clampf(n.y, 0.0, 1.0) * 0.15))
			var hoof := Vector3(knee_at.x, 0.05, knee_at.z + (-0.02 if front else 0.06))
			if front: ls.tube([knee_at, Vector3(knee_at.x, 0.17, knee_at.z - 0.01), hoof + Vector3(0, 0.04, 0)], [0.07, 0.058, 0.06], lp, {"sides": 9, "per": 3})
			else: ls.tube([knee_at, Vector3(knee_at.x, 0.26, knee_at.z + 0.1), Vector3(knee_at.x, 0.12, knee_at.z + 0.08), hoof + Vector3(0, 0.04, 0)], [0.07, 0.06, 0.058, 0.06], lp, {"sides": 9, "per": 3})
			for t in [-1.0, 1.0]: ls.blob(hoof + Vector3(0.028 * t, -0.005, -0.03), Vector3(0.032, 0.05, 0.05), hf, {"lat": 5, "lon": 8})
			part(knee, "Lower", ls)
			feet.append(leg); knees.append(knee)
	parts.feet = feet; parts.knees = knees
	var tail := joint(root, "Tail", Vector3(0, 0.76, 0.73))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	ts.tube([Vector3(0, 0.76, 0.7), Vector3(0, 0.74, 0.82), Vector3(0.06, 0.66, 0.86), Vector3(0.02, 0.6, 0.82), Vector3(-0.02, 0.62, 0.78)], [0.03, 0.025, 0.02, 0.016, 0.01], tp, {"sides": 6, "per": 3})
	parts.tail = tail; parts.tail_sculpt = ts
	return parts


## A bristle crest down the spine: thin dark spikes leaning back.
func bristles(s: Sculpt, from_z: float, to_z: float, count: int, length: float, color_tip: Color) -> void:
	var bp := s.add_painter(func (p, n, v, w): return HIDE_DARK.lerp(color_tip, v))
	for k in range(count):
		var t := float(k) / (count - 1)
		var z := lerpf(from_z, to_z, t)
		var y := back_y(z)
		var x := ((k % 3) - 1) * 0.035
		var l := length * (0.6 + 0.5 * sin(t * PI))
		thorn(s, bp, Vector3(x, y - 0.06, z), Vector3(x * 2.0, 1.0, 0.7), l, 0.022, Vector3(0, 0, 0.03))


func _close(parts: Dictionary, scale: float) -> Node3D:
	part(root, "Body", parts.body)
	part(parts.head, "Head", parts.head_sculpt)
	var core := part(parts.head, "GlowingEyes", parts.eyes, glow)
	core.material_override = glow
	part(parts.tail, "CurlyTail", parts.tail_sculpt)
	return _finish({"head": parts.head, "core": core, "arms": [], "forearms": [], "feet": parts.feet, "knees": parts.knees, "leaves": [parts.tail]}, scale)


## A: a huge bristly boar with overlapping plates of rusted iron along its back and a plate on
## its brow.
func _ironback() -> Node3D:
	var parts := _boar(hide(), 1.0)
	var body: Sculpt = parts.body
	var ip := body.add_painter(iron_plate)
	for row in range(3):
		for k in range(5):
			var z := -0.36 + k * 0.22 + row * 0.04
			var side := float(row - 1)
			var y := back_y(z) - absf(side) * 0.07
			body.rock(Vector3(side * 0.2, y, z), Vector3(0.16, 0.05, 0.14), ip, {"lat": 4, "lon": 6, "lump": 0.15, "basis": Basis.from_euler(Vector3(-0.2, 0, -side * 0.55))})
	bristles(body, -0.5, -0.25, 6, 0.16, HIDE_LIGHT)
	var hs: Sculpt = parts.head_sculpt
	hs.rock(Vector3(0, 0.98, -0.7), Vector3(0.17, 0.05, 0.16), hs.add_painter(iron_plate), {"lat": 4, "lon": 6, "lump": 0.12, "basis": Basis(Vector3.RIGHT, 0.45)})
	return _close(parts, 1.2)


## B: a hulking boar with a blanket of moss on its back, ferns, a mushroom and a couple of
## stones, and mud up its legs.
func _mossback() -> Node3D:
	# Muddy hide with moss growing over the top of the back, so the moss is part of its coat.
	var mossy := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c: Color = hide().call(p, n, v, w)
		c = c.lerp(Color("#3d2f22"), smoothstep(0.45, 0.25, p.y) * 0.7)
		var grow := smoothstep(0.35, 0.75, n.y + 0.4 * Sculpt.fbm(p * 4.0)) * smoothstep(0.95, 1.1, p.y)
		return c.lerp(moss_color(p), grow)
	var parts := _boar(mossy, 1.1, false)
	var body: Sculpt = parts.body
	var mp := body.add_painter(moss)
	# A ridge of moss lumps following the back, with strands hanging down the flanks.
	var strands: Array = []
	for k in range(8):
		var z := -0.3 + k * 0.125
		var x := Sculpt.noise(Vector3(k, 2, 0)) * 0.05
		var width := 0.24 + 0.06 * sin(float(k) / 7.0 * PI)
		body.blob(Vector3(x, back_y(z) - 0.035, z), Vector3(width, 0.08, 0.13), mp, {"lat": 6, "lon": 10, "lump": 0.5})
		for side in [-1.0, 1.0]:
			if (k + int(side > 0.0)) % 2 == 0: strands.append(Vector3(side * (width - 0.02), back_y(z) - 0.1, z))
	body.rock(Vector3(0.12, back_y(0.3) + 0.02, 0.3), Vector3(0.11, 0.08, 0.09), body.add_painter(func (p, n, v, w): return Color("#7d8073").lerp(moss_color(p), smoothstep(0.5, 0.8, n.y))), {})
	# A little cluster of red mushrooms.
	var cp := body.add_painter(cap); var stem := body.add_painter(func (p, n, v, w): return GILL)
	for m in [[Vector3(-0.12, 0.0, -0.05), 0.18], [Vector3(-0.2, 0.0, 0.03), 0.12], [Vector3(-0.05, 0.0, 0.04), 0.1]]:
		var at: Vector3 = m[0]; var size: float = m[1]
		var base := Vector3(at.x, back_y(at.z) - 0.04, at.z)
		var top := base + Vector3(0, 0.05 + size * 0.45, 0)
		body.tube([base, top], [size * 0.14, size * 0.11], stem, {"sides": 7})
		mushroom_cap(body, cp, top, size, Basis(Vector3.FORWARD, at.x * 1.5))
	bristles(body, -0.55, -0.3, 7, 0.16, HIDE_LIGHT)
	# A heavier face: mossy brow, warts on the cheeks and bigger up-curving tusks.
	var hs: Sculpt = parts.head_sculpt; var hp: int = parts.head_painter
	var hm := hs.add_painter(moss)
	hs.tube([Vector3(-0.2, 0.9, -0.74), Vector3(0, 0.93, -0.78), Vector3(0.2, 0.9, -0.74)], [0.05, 0.06, 0.05], hp, {"sides": 8, "per": 3, "cap_rings": 2, "lump": 0.2})
	hs.blob(Vector3(0, 0.98, -0.6), Vector3(0.13, 0.045, 0.12), hm, {"lat": 6, "lon": 10, "lump": 0.6})
	for side in [-1.0, 1.0]:
		for wart in [Vector3(0.17, 0.66, -0.86), Vector3(0.15, 0.6, -0.94)]:
			hs.blob(Vector3(wart.x * side, wart.y, wart.z), Vector3.ONE * 0.03, hp, {"lat": 4, "lon": 6})
		hs.tube([Vector3(0.09 * side, 0.5, -0.98), Vector3(0.19 * side, 0.57, -1.1), Vector3(0.26 * side, 0.74, -1.09), Vector3(0.25 * side, 0.88, -0.98)], [0.05, 0.04, 0.025, 0.003], hs.add_painter(func (p, n, v, w): return IVORY.darkened((1.0 - v) * 0.25)), {"sides": 8, "per": 3, "cap1": false})
	# Bigger eyes, set forward under the brow so they show.
	parts.eyes = Sculpt.new()
	var ew: int = parts.eyes.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: parts.eyes.blob(Vector3(0.16 * side, 0.83, -0.86), Vector3(0.03, 0.022, 0.02), ew, {"lat": 4, "lon": 7})
	var ferns := [sprout(root, "Fern", Vector3(0.05, back_y(0.18) + 0.02, 0.18), Vector3(0.3, 0, 0.4), 0.28, 6), sprout(root, "FernBack", Vector3(-0.12, back_y(0.45), 0.45), Vector3(-0.4, 0, 0.4), 0.22, 5)]
	var node := _close(parts, 1.2)
	var rig: Dictionary = node.get_meta("rig_bindings")
	for f in ferns: rig.leaves.append(node.get_path_to(f))
	node.set_meta("rig_bindings", rig)
	return node


## C: a lean razorback with a tall bristle crest, a bony battering-ram plate on its brow and
## extra-long tusks.
func _razorback() -> Node3D:
	hide_base = Color("#6a4a33"); hide_dark = Color("#24170f"); hide_light = Color("#a4825f")
	var parts := _boar(hide(), 0.88)
	var body: Sculpt = parts.body
	bristles(body, -0.55, 0.55, 26, 0.3, Color("#d9c39a"))
	var hs: Sculpt = parts.head_sculpt
	var bone := hs.add_painter(func (p, n, v, w): return BONE_PLATE.darkened(clampf(-n.y, 0.0, 1.0) * 0.3 + Sculpt.noise(p * 12.0) * 0.1))
	hs.rock(Vector3(0, 0.96, -0.74), Vector3(0.2, 0.07, 0.2), bone, {"lat": 5, "lon": 7, "lump": 0.15, "basis": Basis(Vector3.RIGHT, 0.5)})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.09 * side, 0.52, -1.0), Vector3(0.2 * side, 0.6, -1.12), Vector3(0.28 * side, 0.8, -1.1), Vector3(0.26 * side, 0.94, -0.98)], [0.045, 0.036, 0.022, 0.003], hs.add_painter(func (p, n, v, w): return IVORY.darkened((1.0 - v) * 0.25)), {"sides": 8, "per": 3, "cap1": false})
	return _close(parts, 1.2)
