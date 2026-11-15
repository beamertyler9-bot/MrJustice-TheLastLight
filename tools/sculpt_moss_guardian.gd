extends "res://tools/creature_kit.gd"
## The Moss Guardian, sculpted by hand: the old stone guardians of the Mossbound garden,
## grown over with moss, ferns and flowers. Its core is the glowing rune in its chest.

const STONE := Color("#7d8073")
const STONE_LIGHT := Color("#aaa995")
const STONE_DARK := Color("#43463e")
const LICHEN := Color("#c4bd76")
const RUNE := Color("#9ff0c4")

var rune_glow: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_gray.png")
	glow.albedo_color = RUNE.darkened(0.35); glow.emission = RUNE
	glow.emission_energy_multiplier = 0.8
	material.uv1_scale = Vector3(4.0, 4.0, 4.0)
	rune_glow = glow


static func stone(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var grain := Sculpt.fbm(p * 5.0)
	var c := STONE.lerp(STONE_LIGHT, clampf(0.5 + grain * 0.9, 0.0, 1.0))
	c = c.lerp(STONE_DARK, clampf(-w, 0.0, 1.0) * 0.5 + clampf(-grain - 0.35, 0.0, 1.0) * 0.6)
	c = c.lerp(LICHEN, smoothstep(0.55, 0.68, Sculpt.noise(p * 16.0 + Vector3(2, 7, 1))) * 0.55)
	c = c.lerp(STONE_DARK, clampf(1.0 - p.y / 0.25, 0.0, 1.0) * 0.4)
	var moss := smoothstep(0.42, 0.78, n.y + 0.5 * Sculpt.fbm(p * 3.7))
	return c.lerp(moss_color(p), moss)


static func bare_stone(p: Vector3, _n: Vector3, _v: float, w: float) -> Color:
	var grain := Sculpt.fbm(p * 5.0)
	var c := STONE.lerp(STONE_LIGHT, clampf(0.5 + grain * 0.9, 0.0, 1.0))
	return c.lerp(STONE_DARK, clampf(-w, 0.0, 1.0) * 0.5 + clampf(-grain - 0.35, 0.0, 1.0) * 0.6)


## Moss with stones showing through in places.
static func mound(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var rock := smoothstep(0.3, 0.42, Sculpt.fbm(p * 2.6 + Vector3(5, 2, 8)))
	var c := moss(p, n, v, w).darkened(clampf(0.75 - p.y, 0.0, 1.0) * 0.5)
	return c.lerp(bare_stone(p, n, v, w), rock)


## A carved rune, darkened round the edge, for the core to sit in.
static func around(spot: Vector3, radius: float, base: Callable) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c: Color = base.call(p, n, v, w)
		return c.lerp(STONE_DARK.darkened(0.4), smoothstep(radius, radius * 0.55, p.distance_to(spot)))


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "MossGuardian"
	match variant:
		"statue": return _statue()
		"mound": return _mound()
		"warden": return _warden()
		"rockmound": return _rockmound()
	return null


func _rune(parent: Node3D, at: Vector3, size: float) -> MeshInstance3D:
	var rs := Sculpt.new(); var white := rs.add_painter(func (p, n, v, w): return Color.WHITE)
	rs.blob(at, Vector3(0.05, 0.1, 0.014) * size, white, {"lat": 5, "lon": 8})
	for side in [-1.0, 1.0]:
		rs.blob(at + Vector3(0.055 * side, -0.025, 0.004) * size, Vector3(0.028, 0.06, 0.012) * size, white, {"basis": Basis(Vector3.BACK, -0.75 * side), "lat": 4, "lon": 7})
	rs.blob(at + Vector3(0, -0.1, 0.004) * size, Vector3(0.012, 0.05, 0.01) * size, white, {"lat": 4, "lon": 6})
	var core := part(parent, "GlowingRune", rs, glow)
	core.material_override = glow
	return core


func _eyes(parent: Node3D, spots: Array, size: Vector3) -> void:
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in spots: es.blob(e, size, white, {"lat": 5, "lon": 8})
	var eyes := part(parent, "GlowingEyes", es, glow)
	eyes.material_override = glow


## A: an old garden statue come alive: carved stone, moss pauldrons with flowers, vines
## round its forearms and big stone fists for slamming.
func _statue() -> Node3D:
	var body := Sculpt.new()
	var rune_at := Vector3(0, 1.22, -0.42)
	var b := body.add_painter(around(rune_at, 0.15, stone)); var m := body.add_painter(moss)
	body.tube([Vector3(0, 0.62, 0.02), Vector3(0, 0.86, 0.02), Vector3(0, 1.14, 0.0), Vector3(0, 1.4, 0.0), Vector3(0, 1.56, 0.01)], [0.27, 0.28, 0.4, 0.43, 0.32], b, {"sides": 16, "lump": 0.05, "flat": 1.22})
	body.blob(Vector3(0, 0.64, 0.02), Vector3(0.34, 0.17, 0.26), body.add_painter(stone), {"lat": 7, "lon": 14, "lump": 0.08})
	moss_collar(body, m, Vector3(0, 1.55, 0.0), 0.27, 16, 0.075)
	flowers(body, [Vector3(-0.2, 1.6, 0.12), Vector3(0.18, 1.61, 0.16), Vector3(0.05, 1.6, 0.26)], 0.03)
	part(root, "Body", body)
	var core := _rune(root, rune_at, 1.0)

	var head := joint(root, "Head", Vector3(0, 1.6, 0))
	var eyes := [Vector3(-0.075, 1.82, -0.175), Vector3(0.075, 1.82, -0.175)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.07, 1.705, 0.14, 0.022), -0.12, bare_stone)); var hb := hs.add_painter(bare_stone); var hm := hs.add_painter(moss)
	hs.tube([Vector3(0, 1.52, 0), Vector3(0, 1.7, -0.01)], [0.13, 0.12], hb, {"sides": 10})
	hs.blob(Vector3(0, 1.8, -0.02), Vector3(0.18, 0.22, 0.19), f, {"lat": 11, "lon": 16, "lump": 0.05})
	hs.tube([Vector3(-0.16, 1.88, -0.13), Vector3(0, 1.865, -0.19), Vector3(0.16, 1.88, -0.13)], [0.035, 0.045, 0.035], hb, {"sides": 8, "per": 3, "cap_rings": 2})
	hs.tube([Vector3(0, 1.85, -0.185), Vector3(0, 1.77, -0.215)], [0.028, 0.035], hb, {"sides": 7, "per": 2, "cap_rings": 2})
	hs.blob(Vector3(0, 1.97, 0.02), Vector3(0.2, 0.08, 0.21), hm, {"lat": 6, "lon": 12, "lump": 0.5})
	hanging(hs, hm, [Vector3(-0.15, 1.9, 0.1), Vector3(-0.06, 1.93, 0.17), Vector3(0.05, 1.93, 0.18), Vector3(0.14, 1.9, 0.12), Vector3(0.18, 1.88, 0.02)], 0.2, 0.03, Vector3(0, 0, 0.05))
	flowers(hs, [Vector3(0.1, 2.03, -0.06)], 0.025)
	part(head, "StoneHead", hs)
	_eyes(head, eyes, Vector3(0.03, 0.022, 0.02))
	var ferns := [
		sprout(head, "FernLeft", Vector3(-0.1, 2.0, 0.03), Vector3(-0.6, 0, 0.3), 0.22, 5),
		sprout(head, "FernRight", Vector3(0.08, 2.01, 0.08), Vector3(0.5, 0, 0.4), 0.18, 4)]

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.5 * side, 1.45, 0))
		var us := Sculpt.new(); var ub := us.add_painter(stone); var um := us.add_painter(moss)
		us.tube([Vector3(0.36 * side, 1.48, 0), Vector3(0.56 * side, 1.4, 0), Vector3(0.6 * side, 1.15, 0), Vector3(0.61 * side, 1.0, 0)], [0.14, 0.14, 0.12, 0.11], ub, {"sides": 12, "lump": 0.06, "side": Vector3.BACK})
		us.blob(Vector3(0.53 * side, 1.52, 0), Vector3(0.21, 0.15, 0.2), ub, {"lat": 8, "lon": 13, "lump": 0.1})
		moss_clump(us, um, Vector3(0.53 * side, 1.64, 0.0), 0.14, 4)
		flowers(us, [Vector3(0.48 * side, 1.7, -0.06), Vector3(0.6 * side, 1.68, 0.06)], 0.026)
		part(shoulder, "Pauldron", us)
		var elbow := joint(shoulder, "Elbow", Vector3(0.61 * side, 1.0, 0))
		var fs := Sculpt.new(); var fb := fs.add_painter(stone); var fk := fs.add_painter(bare_stone)
		fs.tube([Vector3(0.61 * side, 1.04, 0), Vector3(0.63 * side, 0.8, -0.03), Vector3(0.64 * side, 0.62, -0.05)], [0.12, 0.14, 0.15], fb, {"sides": 12, "lump": 0.06, "side": Vector3.BACK})
		fs.blob(Vector3(0.64 * side, 0.52, -0.06), Vector3(0.17, 0.15, 0.17), fk, {"lat": 8, "lon": 12, "lump": 0.1})
		for k in range(4):
			fs.blob(Vector3((0.64 + (k - 1.5) * 0.065) * side, 0.5, -0.2), Vector3(0.042, 0.05, 0.045), fk, {"lat": 5, "lon": 7})
		vine(fs, [Vector3(0.61 * side, 1.0, 0), Vector3(0.63 * side, 0.8, -0.03), Vector3(0.64 * side, 0.62, -0.05)], 0.145, 1.6, 0.018, 4)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.2 * side, 0.6, 0.02))
		var ts := Sculpt.new(); var tb := ts.add_painter(stone)
		ts.tube([Vector3(0.19 * side, 0.7, 0.02), Vector3(0.21 * side, 0.46, 0.01), Vector3(0.22 * side, 0.32, 0.0)], [0.17, 0.16, 0.14], tb, {"sides": 12, "lump": 0.06})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.22 * side, 0.32, 0))
		var ss := Sculpt.new(); var sb := ss.add_painter(stone)
		ss.tube([Vector3(0.22 * side, 0.36, 0), Vector3(0.23 * side, 0.18, -0.01), Vector3(0.23 * side, 0.1, -0.02)], [0.14, 0.14, 0.15], sb, {"sides": 12, "lump": 0.06})
		ss.blob(Vector3(0.23 * side, 0.065, -0.07), Vector3(0.15, 0.07, 0.21), sb, {"lat": 6, "lon": 12, "lump": 0.08})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": ferns}, 0.86)


## B: a walking mound of moss with stones showing through, a stone face set in the front,
## ferns and flowers on top and heavy stone arms.
func _mound() -> Node3D:
	var body := Sculpt.new()
	var rune_at := Vector3(0, 0.93, -0.5)
	var b := body.add_painter(around(rune_at, 0.13, mound)); var m := body.add_painter(moss)
	body.blob(Vector3(0, 1.02, 0.05), Vector3(0.56, 0.52, 0.5), b, {"lat": 12, "lon": 18, "lump": 0.22})
	moss_collar(body, body.add_painter(func (p, n, v, w): return moss_color(p).darkened(0.3)), Vector3(0, 0.66, 0.05), 0.45, 18, 0.1)
	flowers(body, [Vector3(-0.25, 1.45, 0.1), Vector3(0.2, 1.48, 0.0), Vector3(0.05, 1.53, 0.22), Vector3(-0.08, 1.5, -0.15), Vector3(0.32, 1.38, 0.25)], 0.032)
	part(root, "Body", body)
	var core := _rune(root, rune_at, 0.9)
	var top := [
		sprout(root, "FernTop", Vector3(-0.12, 1.52, 0.08), Vector3(-0.4, 0, 0.2), 0.3, 6),
		sprout(root, "FernBack", Vector3(0.18, 1.48, 0.25), Vector3(0.4, 0, 0.5), 0.24, 5),
		sprout(root, "FernSide", Vector3(-0.35, 1.35, 0.2), Vector3(-0.7, 0, 0.3), 0.2, 4)]

	var head := joint(root, "Head", Vector3(0, 1.2, -0.3))
	var eyes := [Vector3(-0.085, 1.25, -0.55), Vector3(0.085, 1.25, -0.55)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.08, 1.115, 0.16, 0.025), -0.45, bare_stone)); var hb := hs.add_painter(bare_stone); var hm := hs.add_painter(moss)
	hs.blob(Vector3(0, 1.2, -0.44), Vector3(0.23, 0.19, 0.13), f, {"lat": 10, "lon": 16, "lump": 0.08})
	hs.tube([Vector3(-0.2, 1.31, -0.5), Vector3(0, 1.3, -0.57), Vector3(0.2, 1.31, -0.5)], [0.04, 0.055, 0.04], hb, {"sides": 8, "per": 3, "cap_rings": 2})
	hs.tube([Vector3(0, 1.28, -0.56), Vector3(0, 1.18, -0.59)], [0.03, 0.038], hb, {"sides": 7, "per": 2, "cap_rings": 2})
	hanging(hs, hm, [Vector3(-0.17, 1.33, -0.52), Vector3(-0.07, 1.35, -0.56), Vector3(0.1, 1.35, -0.55), Vector3(0.18, 1.33, -0.5)], 0.08, 0.022)
	part(head, "StoneFace", hs)
	_eyes(head, eyes, Vector3(0.034, 0.024, 0.02))

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.5 * side, 1.12, -0.05))
		var us := Sculpt.new(); var ub := us.add_painter(stone)
		us.tube([Vector3(0.38 * side, 1.14, -0.05), Vector3(0.64 * side, 1.04, -0.06), Vector3(0.71 * side, 0.82, -0.06)], [0.16, 0.14, 0.12], ub, {"sides": 12, "lump": 0.08, "side": Vector3.BACK})
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "Elbow", Vector3(0.71 * side, 0.82, -0.06))
		var fs := Sculpt.new(); var fb := fs.add_painter(stone); var fk := fs.add_painter(bare_stone)
		fs.tube([Vector3(0.71 * side, 0.86, -0.06), Vector3(0.73 * side, 0.58, -0.09), Vector3(0.74 * side, 0.42, -0.1)], [0.12, 0.15, 0.16], fb, {"sides": 12, "lump": 0.08, "side": Vector3.BACK})
		fs.blob(Vector3(0.74 * side, 0.3, -0.1), Vector3(0.18, 0.16, 0.18), fk, {"lat": 8, "lon": 12, "lump": 0.12})
		for k in range(4):
			fs.blob(Vector3((0.74 + (k - 1.5) * 0.07) * side, 0.28, -0.25), Vector3(0.045, 0.05, 0.045), fk, {"lat": 5, "lon": 7})
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.25 * side, 0.55, 0.05))
		var ts := Sculpt.new(); var tb := ts.add_painter(stone)
		ts.tube([Vector3(0.24 * side, 0.62, 0.05), Vector3(0.26 * side, 0.42, 0.04), Vector3(0.27 * side, 0.3, 0.03)], [0.17, 0.16, 0.15], tb, {"sides": 12, "lump": 0.06})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.27 * side, 0.3, 0.03))
		var ss := Sculpt.new(); var sb := ss.add_painter(stone)
		ss.tube([Vector3(0.27 * side, 0.34, 0.03), Vector3(0.28 * side, 0.16, 0.02), Vector3(0.28 * side, 0.09, 0.0)], [0.15, 0.15, 0.16], sb, {"sides": 12, "lump": 0.06})
		ss.blob(Vector3(0.28 * side, 0.065, -0.06), Vector3(0.16, 0.07, 0.21), sb, {"lat": 6, "lon": 12, "lump": 0.08})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": top}, 0.9)


## Moss with lots of rock showing through.
static func rocky_mound(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var rock := smoothstep(0.02, 0.2, Sculpt.fbm(p * 2.4 + Vector3(5, 2, 8)) - clampf(n.y, 0.0, 1.0) * 0.25)
	var c := moss(p, n, v, w).darkened(clampf(0.8 - p.y, 0.0, 1.0) * 0.45)
	return c.lerp(stone(p, n, v, w), rock)


## Points on the mound's skin at the given angles (radians round, radians up).
static func on_mound(center: Vector3, radii: Vector3, around: float, up: float, sink := 0.9) -> Vector3:
	return center + Vector3(cos(up) * sin(around), sin(up), -cos(up) * cos(around)) * radii * sink


## The chosen design: the Moss Mound, made rockier, hung with vines, with boulder clubs
## for hands.
func _rockmound() -> Node3D:
	var body := Sculpt.new()
	var rune_at := Vector3(0, 0.9, -0.5)
	var center := Vector3(0, 1.02, 0.05); var radii := Vector3(0.56, 0.52, 0.5)
	var b := body.add_painter(around(rune_at, 0.13, rocky_mound)); var st := body.add_painter(stone)
	body.blob(center, radii, b, {"lat": 12, "lon": 18, "lump": 0.2})
	var rocks := [[0.9, 0.55, 0.17], [-0.95, 0.5, 0.15], [2.4, 0.6, 0.2], [-2.3, 0.45, 0.18], [3.1, 0.2, 0.2], [1.6, -0.05, 0.16], [-1.55, 0.05, 0.17], [0.4, 0.95, 0.14], [-0.5, 1.05, 0.13], [2.0, 1.0, 0.15], [-2.6, 0.9, 0.12], [0.0, -0.35, 0.13], [0.55, -0.1, 0.11]]
	for r in rocks:
		body.rock(on_mound(center, radii, r[0], r[1], 0.93), Vector3(r[2] * 1.2, r[2] * 0.85, r[2]), st, {"basis": Basis.from_euler(Vector3(r[1], r[0], 0.3))})
	var vine_spots: Array = []; var vine_out: Array = []
	for k in range(13):
		var ang := -2.7 + k * 0.45 + Sculpt.noise(Vector3(k, 3, 0)) * 0.15
		if absf(ang) < 0.45: continue
		var spot := on_mound(center, radii, ang, -0.12 + 0.1 * Sculpt.noise(Vector3(k, 1, 1)), 0.98)
		vine_spots.append(spot)
		vine_out.append(Vector3(spot.x - center.x, 0, spot.z - center.z).normalized() * 0.04)
	hanging_vines(body, vine_spots, 0.75, vine_out)
	flowers(body, [Vector3(-0.25, 1.45, 0.1), Vector3(0.2, 1.48, 0.0), Vector3(0.05, 1.53, 0.22), Vector3(-0.1, 1.5, -0.15), Vector3(0.32, 1.38, 0.25)], 0.032)
	part(root, "Body", body)
	var core := _rune(root, rune_at, 0.9)
	var top := [
		sprout(root, "FernTop", Vector3(-0.12, 1.52, 0.08), Vector3(-0.4, 0, 0.2), 0.3, 6),
		sprout(root, "FernBack", Vector3(0.18, 1.48, 0.25), Vector3(0.4, 0, 0.5), 0.24, 5),
		sprout(root, "FernSide", Vector3(-0.35, 1.35, 0.2), Vector3(-0.7, 0, 0.3), 0.2, 4)]

	var head := joint(root, "Head", Vector3(0, 1.2, -0.3))
	var eyes := [Vector3(-0.085, 1.25, -0.55), Vector3(0.085, 1.25, -0.55)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.08, 1.115, 0.16, 0.025), -0.45, bare_stone)); var hb := hs.add_painter(stone)
	hs.blob(Vector3(0, 1.2, -0.44), Vector3(0.23, 0.19, 0.13), f, {"lat": 10, "lon": 16, "lump": 0.1})
	for side in [-1.0, 1.0]:
		hs.rock(Vector3(0.11 * side, 1.31, -0.53), Vector3(0.12, 0.05, 0.07), hb, {"basis": Basis(Vector3.BACK, 0.25 * side), "lat": 4, "lon": 6, "lump": 0.25})
	hs.tube([Vector3(0, 1.28, -0.56), Vector3(0, 1.18, -0.59)], [0.03, 0.038], hs.add_painter(bare_stone), {"sides": 7, "per": 2, "cap_rings": 2})
	hanging_vines(hs, [Vector3(-0.2, 1.3, -0.47), Vector3(0.21, 1.28, -0.46)], 0.22)
	part(head, "StoneFace", hs)
	_eyes(head, eyes, Vector3(0.034, 0.024, 0.02))

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.5 * side, 1.12, -0.05))
		var us := Sculpt.new(); var ub := us.add_painter(stone)
		us.tube([Vector3(0.38 * side, 1.14, -0.05), Vector3(0.64 * side, 1.04, -0.06), Vector3(0.71 * side, 0.82, -0.06)], [0.16, 0.14, 0.12], ub, {"sides": 12, "lump": 0.12, "side": Vector3.BACK})
		us.rock(Vector3(0.58 * side, 1.18, -0.05), Vector3(0.2, 0.14, 0.18), ub, {"basis": Basis(Vector3.BACK, 0.3 * side)})
		us.rock(Vector3(0.68 * side, 1.0, 0.04), Vector3(0.1, 0.09, 0.09), ub)
		hanging_vines(us, [Vector3(0.62 * side, 1.12, -0.18), Vector3(0.74 * side, 1.08, 0.06)], 0.4, [Vector3(0.02 * side, 0, -0.02), Vector3(0.03 * side, 0, 0.02)])
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "Elbow", Vector3(0.71 * side, 0.82, -0.06))
		var fs := Sculpt.new(); var fb := fs.add_painter(stone)
		fs.tube([Vector3(0.71 * side, 0.86, -0.06), Vector3(0.73 * side, 0.62, -0.09), Vector3(0.74 * side, 0.46, -0.1)], [0.12, 0.15, 0.17], fb, {"sides": 12, "lump": 0.12, "side": Vector3.BACK})
		fs.rock(Vector3(0.75 * side, 0.32, -0.11), Vector3(0.25, 0.23, 0.24), fb, {"basis": Basis.from_euler(Vector3(0.3, 0.5 * side, 0.2)), "lat": 6, "lon": 8, "lump": 0.3})
		fs.rock(Vector3(0.84 * side, 0.4, -0.25), Vector3(0.11, 0.1, 0.1), fb, {"basis": Basis(Vector3.UP, 0.7)})
		fs.rock(Vector3(0.62 * side, 0.27, -0.25), Vector3(0.1, 0.09, 0.1), fb, {"basis": Basis(Vector3.RIGHT, 0.5)})
		part(elbow, "BoulderClub", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.25 * side, 0.55, 0.05))
		var ts := Sculpt.new(); var tb := ts.add_painter(stone)
		ts.tube([Vector3(0.24 * side, 0.62, 0.05), Vector3(0.26 * side, 0.42, 0.04), Vector3(0.27 * side, 0.3, 0.03)], [0.17, 0.16, 0.15], tb, {"sides": 12, "lump": 0.1})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.27 * side, 0.3, 0.03))
		var ss := Sculpt.new(); var sb := ss.add_painter(stone)
		ss.tube([Vector3(0.27 * side, 0.34, 0.03), Vector3(0.28 * side, 0.16, 0.02), Vector3(0.28 * side, 0.1, 0.0)], [0.15, 0.15, 0.16], sb, {"sides": 12, "lump": 0.1})
		ss.rock(Vector3(0.28 * side, 0.07, -0.06), Vector3(0.17, 0.08, 0.22), sb, {"lat": 4, "lon": 7, "lump": 0.2})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": top}, 1.42)


## C: a tall, lean warden with a crown of ferns, a mossy mantle and a long lichen beard.
func _warden() -> Node3D:
	var body := Sculpt.new()
	var rune_at := Vector3(0, 1.28, -0.31)
	var b := body.add_painter(around(rune_at, 0.12, stone)); var m := body.add_painter(moss)
	body.tube([Vector3(0, 0.68, 0.02), Vector3(0, 0.95, 0.02), Vector3(0, 1.25, 0.0), Vector3(0, 1.5, 0.0), Vector3(0, 1.62, 0.01)], [0.21, 0.23, 0.31, 0.32, 0.22], b, {"sides": 16, "lump": 0.05, "flat": 1.18})
	body.blob(Vector3(0, 0.7, 0.02), Vector3(0.27, 0.15, 0.21), body.add_painter(stone), {"lat": 7, "lon": 14, "lump": 0.08})
	moss_collar(body, m, Vector3(0, 1.6, 0.0), 0.24, 16, 0.085)
	var mantle: Array = []
	for k in range(14):
		var ang := PI * 0.15 + PI * 0.7 * k / 13.0
		mantle.append(Vector3(cos(ang) * 0.31, 1.55, sin(ang) * 0.28))
	hanging(body, m, mantle, 0.42, 0.035, Vector3(0, 0, 0.05))
	part(root, "Body", body)
	var core := _rune(root, rune_at, 0.85)

	var head := joint(root, "Head", Vector3(0, 1.65, 0))
	var eyes := [Vector3(-0.065, 1.9, -0.15), Vector3(0.065, 1.9, -0.15)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.05, 1.755, 0.1, 0.02), -0.1, bare_stone)); var hb := hs.add_painter(bare_stone); var hm := hs.add_painter(moss)
	hs.tube([Vector3(0, 1.58, 0), Vector3(0, 1.76, -0.01)], [0.11, 0.1], hb, {"sides": 10})
	hs.blob(Vector3(0, 1.88, -0.02), Vector3(0.15, 0.24, 0.16), f, {"lat": 12, "lon": 16, "lump": 0.05})
	hs.tube([Vector3(-0.13, 1.96, -0.1), Vector3(0, 1.945, -0.16), Vector3(0.13, 1.96, -0.1)], [0.03, 0.04, 0.03], hb, {"sides": 8, "per": 3, "cap_rings": 2})
	hs.tube([Vector3(0, 1.93, -0.16), Vector3(0, 1.82, -0.195)], [0.024, 0.032], hb, {"sides": 7, "per": 2, "cap_rings": 2})
	hs.blob(Vector3(0, 2.09, 0.0), Vector3(0.14, 0.06, 0.15), hm, {"lat": 6, "lon": 12, "lump": 0.5})
	flowers(hs, [Vector3(-0.08, 2.13, -0.08), Vector3(0.09, 2.12, -0.06)], 0.024)
	part(head, "StoneHead", hs)
	_eyes(head, eyes, Vector3(0.026, 0.02, 0.018))
	var swaying: Array = [
		sprout(head, "FernCrownLeft", Vector3(-0.08, 2.1, 0.03), Vector3(-0.7, 0, 0.1), 0.24, 5),
		sprout(head, "FernCrownMid", Vector3(0.0, 2.12, 0.06), Vector3(0.0, 0, 0.5), 0.3, 6),
		sprout(head, "FernCrownRight", Vector3(0.08, 2.1, 0.03), Vector3(0.7, 0, 0.1), 0.24, 5)]
	for k in range(5):
		var x := (k - 2) * 0.04
		var strand := joint(head, "LichenBeard%d" % k, Vector3(x, 1.74, -0.15))
		var bs := Sculpt.new(); var bp := bs.add_painter(func (p, n, v, w): return LICHEN.lerp(Color("#9fae6a"), v).darkened(0.1 + Sculpt.noise(p * 30.0) * 0.1))
		var start := Vector3(x, 1.76, -0.14 + absf(x) * 0.5)
		var length := 0.42 - absf(x) * 1.8
		bs.tube([start, start + Vector3(x * 0.2, -length * 0.4, -0.06), start + Vector3(x * 0.4, -length * 0.75, -0.08), start + Vector3(x * 0.5, -length, -0.07)], [0.026, 0.022, 0.014, 0.005], bp, {"sides": 6, "per": 2, "cap_rings": 1})
		part(strand, "Strand", bs)
		swaying.append(strand)

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.36 * side, 1.5, 0))
		var us := Sculpt.new(); var ub := us.add_painter(stone); var um := us.add_painter(moss)
		us.tube([Vector3(0.24 * side, 1.53, 0), Vector3(0.42 * side, 1.47, 0), Vector3(0.47 * side, 1.13, 0.01)], [0.11, 0.1, 0.085], ub, {"sides": 11, "lump": 0.06, "side": Vector3.BACK})
		moss_clump(us, um, Vector3(0.38 * side, 1.58, 0.0), 0.12, 4)
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "Elbow", Vector3(0.47 * side, 1.13, 0.01))
		var fs := Sculpt.new(); var fb := fs.add_painter(stone)
		fs.tube([Vector3(0.47 * side, 1.16, 0.01), Vector3(0.49 * side, 0.86, -0.04), Vector3(0.5 * side, 0.66, -0.06)], [0.085, 0.09, 0.1], fb, {"sides": 11, "lump": 0.06, "side": Vector3.BACK})
		roots(fs, fs.add_painter(bare_stone), Vector3(0.5 * side, 0.62, -0.06), [Vector3(-0.3 * side, 0, -0.9), Vector3(0.15 * side, 0, -1.0), Vector3(0.7 * side, 0, -0.6), Vector3(0.4 * side, 0, 0.9)], 0.2, 0.04, 0.24, true)
		vine(fs, [Vector3(0.47 * side, 1.13, 0.01), Vector3(0.49 * side, 0.86, -0.04), Vector3(0.5 * side, 0.68, -0.06)], 0.1, 1.4, 0.014, 3)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.15 * side, 0.68, 0.02))
		var ts := Sculpt.new(); var tb := ts.add_painter(stone)
		ts.tube([Vector3(0.14 * side, 0.76, 0.02), Vector3(0.16 * side, 0.55, 0.01), Vector3(0.18 * side, 0.4, 0.0)], [0.12, 0.11, 0.1], tb, {"sides": 11, "lump": 0.06})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.18 * side, 0.4, 0))
		var ss := Sculpt.new(); var sb := ss.add_painter(stone)
		ss.tube([Vector3(0.18 * side, 0.44, 0), Vector3(0.19 * side, 0.22, -0.01), Vector3(0.19 * side, 0.1, -0.02)], [0.1, 0.1, 0.11], sb, {"sides": 11, "lump": 0.06})
		ss.blob(Vector3(0.19 * side, 0.06, -0.06), Vector3(0.11, 0.06, 0.17), sb, {"lat": 6, "lon": 12, "lump": 0.08})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": swaying}, 0.84)
