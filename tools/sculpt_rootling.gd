extends "res://tools/creature_kit.gd"
## The Rootling Sentinel, sculpted by hand: the Mossback Brute design wearing the Capwood
## Sage's spotted mushroom cap. The other drafts are kept for reference.



func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "RootlingSentinel"
	match variant:
		"stump": return _stump()
		"sage": return _sage()
		"brute": return _brute()
		"mossback": return _mossback()
	return null


## A: a walking tree stump with its face in the trunk and sprouts on top.
func _stump() -> Node3D:
	var body := Sculpt.new(); var b := body.add_painter(bark); var m := body.add_painter(moss)
	body.tube([Vector3(0, 0.48, 0.02), Vector3(0, 0.75, 0.02), Vector3(0, 1.05, 0.0), Vector3(0, 1.3, 0.0), Vector3(0, 1.5, 0.02)], [0.31, 0.36, 0.40, 0.38, 0.3], b, {"sides": 16, "ridges": 8, "ridge": 0.11, "lump": 0.1, "flat": 1.1})
	for k in range(3):
		var at := Vector3(0.37 - k * 0.03, 0.92 + k * 0.1, 0.12 + k * 0.05)
		var shelf := body.add_painter(func (p, n, v, w): return CAP_SPOT.darkened(0.1 + (1.0 - clampf(n.y, 0, 1)) * 0.25).lerp(CAP, 0.25 * k))
		body.blob(at, Vector3(0.085 - k * 0.015, 0.022, 0.065 - k * 0.01), shelf, {"basis": Basis(Vector3.UP, -0.5), "lat": 4, "lon": 8})
	part(root, "Body", body)

	var head := joint(root, "Head", Vector3(0, 1.5, 0))
	var eyes := [Vector3(-0.11, 1.76, -0.27), Vector3(0.11, 1.76, -0.27)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.13, 1.595, 0.26, 0.05), -0.18)); var hb := hs.add_painter(bark); var hm := hs.add_painter(moss)
	hs.tube([Vector3(0, 1.48, 0), Vector3(0, 1.68, 0), Vector3(0, 1.86, 0.01), Vector3(0, 1.98, 0.02)], [0.32, 0.31, 0.29, 0.26], f, {"sides": 18, "per": 7, "ridges": 8, "ridge": 0.07, "lump": 0.08, "flat": 1.05})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.25 * side, 1.88, -0.19), Vector3(0.13 * side, 1.84, -0.27), Vector3(0.03 * side, 1.8, -0.3)], [0.045, 0.06, 0.04], hb, {"sides": 8, "per": 2, "cap_rings": 2, "lump": 0.2})
	hs.blob(Vector3(0, 1.69, -0.3), Vector3(0.055, 0.05, 0.05), hb, {"lat": 6, "lon": 8, "lump": 0.3})
	moss_collar(hs, hm, Vector3(0, 1.515, 0.0), 0.335, 22, 0.08)
	part(head, "Stump", hs)
	var es := Sculpt.new(); var gp := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e + Vector3(0, 0, -0.01), Vector3(0.042, 0.036, 0.03), gp, {"lat": 5, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var sprouts := [
		sprout(head, "SproutLeft", Vector3(-0.12, 2.0, 0.04), Vector3(-0.5, 0, 0.2), 0.3, 4),
		sprout(head, "SproutTop", Vector3(0.04, 2.03, -0.02), Vector3(0.1, 0, -0.2), 0.38, 5),
		sprout(head, "SproutRight", Vector3(0.15, 1.98, 0.08), Vector3(0.5, 0, 0.3), 0.24, 3)]

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.4 * side, 1.36, 0))
		var us := Sculpt.new(); var ub := us.add_painter(bark); var um := us.add_painter(moss)
		us.tube([Vector3(0.26 * side, 1.4, 0), Vector3(0.46 * side, 1.36, 0), Vector3(0.53 * side, 1.18, 0.01), Vector3(0.55 * side, 0.97, 0)], [0.15, 0.15, 0.13, 0.12], ub, {"sides": 10, "ridges": 5, "ridge": 0.08, "lump": 0.1, "side": Vector3.BACK})
		moss_clump(us, um, Vector3(0.44 * side, 1.47, 0.0), 0.15, 4)
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "RootElbow", Vector3(0.55 * side, 0.98, 0))
		var fs := Sculpt.new(); var fb := fs.add_painter(bark)
		fs.tube([Vector3(0.55 * side, 1.03, 0), Vector3(0.57 * side, 0.8, -0.03), Vector3(0.58 * side, 0.63, -0.05)], [0.12, 0.125, 0.14], fb, {"sides": 10, "ridges": 5, "ridge": 0.08, "lump": 0.1, "side": Vector3.BACK})
		roots(fs, fb, Vector3(0.58 * side, 0.6, -0.05), [Vector3(-0.35 * side, 0, -0.9), Vector3(0.25 * side, 0, -1.0), Vector3(0.9 * side, 0, -0.3), Vector3(0.3 * side, 0, 0.9)], 0.17, 0.05, 0.26)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.19 * side, 0.62, 0.04))
		var ts := Sculpt.new(); var tb := ts.add_painter(bark)
		ts.tube([Vector3(0.17 * side, 0.74, 0.03), Vector3(0.2 * side, 0.52, 0.02), Vector3(0.22 * side, 0.34, 0.0)], [0.16, 0.15, 0.13], tb, {"sides": 10, "ridges": 5, "ridge": 0.07, "lump": 0.1})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "RootKnee", Vector3(0.22 * side, 0.34, 0))
		var ss := Sculpt.new(); var sb := ss.add_painter(bark)
		ss.tube([Vector3(0.22 * side, 0.38, 0), Vector3(0.23 * side, 0.18, -0.02), Vector3(0.23 * side, 0.08, -0.04)], [0.13, 0.13, 0.15], sb, {"sides": 10, "ridges": 5, "ridge": 0.07, "lump": 0.1})
		roots(ss, sb, Vector3(0.23 * side, 0.08, -0.04), [Vector3(-0.3, 0, -1), Vector3(0.3, 0, -1), Vector3(0.95 * side, 0, -0.2), Vector3(0, 0, 1)], 0.22, 0.06, 0.06)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": sprouts}, 0.75)


## B: a slim old root spirit under a spotted mushroom cap, with a hanging root beard.
func _sage() -> Node3D:
	var body := Sculpt.new(); var b := body.add_painter(bark); var m := body.add_painter(moss)
	body.tube([Vector3(0, 0.46, 0.02), Vector3(0, 0.78, 0.02), Vector3(0, 1.08, 0.0), Vector3(0, 1.32, 0.0), Vector3(0, 1.48, 0.0)], [0.33, 0.29, 0.23, 0.21, 0.16], b, {"sides": 16, "ridges": 9, "ridge": 0.1, "twist": 0.9, "lump": 0.08, "flat": 1.08})
	moss_collar(body, m, Vector3(0, 1.41, 0.0), 0.2, 13, 0.075)
	part(root, "Body", body)

	var head := joint(root, "Head", Vector3(0, 1.45, 0))
	var eyes := [Vector3(-0.085, 1.65, -0.19), Vector3(0.085, 1.65, -0.19)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.07, 1.51, 0.14, 0.03), -0.12)); var hb := hs.add_painter(bark); var hc := hs.add_painter(cap)
	hs.blob(Vector3(0, 1.62, -0.01), Vector3(0.21, 0.23, 0.2), f, {"lat": 10, "lon": 14, "lump": 0.12})
	hs.tube([Vector3(0, 1.6, -0.18), Vector3(0, 1.57, -0.27), Vector3(0.0, 1.52, -0.34)], [0.035, 0.025, 0.01], hb, {"sides": 7, "per": 2, "cap_rings": 1})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.16 * side, 1.73, -0.13), Vector3(0.08 * side, 1.72, -0.19), Vector3(0.02 * side, 1.7, -0.2)], [0.03, 0.035, 0.025], hb, {"sides": 7, "per": 2, "cap_rings": 1, "lump": 0.2})
	hs.lathe(Vector3(0, 1.8, 0.0), [Vector2(0, 0.24), Vector2(0.18, 0.225), Vector2(0.34, 0.15), Vector2(0.47, 0.04), Vector2(0.54, -0.06), Vector2(0.53, -0.1), Vector2(0.46, -0.07), Vector2(0.3, -0.03), Vector2(0.14, -0.01), Vector2(0, 0.0)], hc, {"sides": 18, "wobble": 0.12, "basis": Basis(Vector3.RIGHT, 0.12)})
	part(head, "CappedHead", hs)
	var es := Sculpt.new(); var gp := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e + Vector3(0, 0, -0.005), Vector3(0.034, 0.03, 0.025), gp, {"lat": 5, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var beard: Array = []
	for k in range(5):
		var x := (k - 2) * 0.05
		var strand := joint(head, "BeardRoot%d" % k, Vector3(x, 1.5, -0.19 + absf(x) * 0.4))
		var bs := Sculpt.new(); var bb := bs.add_painter(bark)
		var start := Vector3(x, 1.52, -0.19 + absf(x) * 0.4)
		var length := 0.4 - absf(x) * 1.4
		bs.tube([start, start + Vector3(x * 0.2, -length * 0.35, -0.08), start + Vector3(x * 0.5 + 0.02, -length * 0.7, -0.11), start + Vector3(x * 0.6, -length, -0.1)], [0.028, 0.024, 0.016, 0.006], bb, {"sides": 6, "per": 2, "cap_rings": 1})
		part(strand, "Strand", bs)
		beard.append(strand)

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.28 * side, 1.3, 0))
		var us := Sculpt.new(); var ub := us.add_painter(bark); var um := us.add_painter(moss)
		us.tube([Vector3(0.17 * side, 1.34, 0), Vector3(0.34 * side, 1.29, 0), Vector3(0.41 * side, 1.02, 0.01)], [0.1, 0.09, 0.075], ub, {"sides": 9, "ridges": 4, "ridge": 0.08, "lump": 0.1, "side": Vector3.BACK})
		moss_clump(us, um, Vector3(0.29 * side, 1.37, 0.0), 0.1, 3)
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "RootElbow", Vector3(0.41 * side, 1.02, 0))
		var fs := Sculpt.new(); var fb := fs.add_painter(bark)
		fs.tube([Vector3(0.41 * side, 1.05, 0), Vector3(0.43 * side, 0.83, -0.04), Vector3(0.44 * side, 0.67, -0.06)], [0.075, 0.07, 0.065], fb, {"sides": 9, "ridges": 4, "ridge": 0.08, "lump": 0.1, "side": Vector3.BACK})
		roots(fs, fb, Vector3(0.44 * side, 0.65, -0.06), [Vector3(-0.3 * side, 0, -0.9), Vector3(0.2 * side, 0, -1.0), Vector3(0.85 * side, 0, -0.4), Vector3(0.4 * side, 0, 0.9)], 0.24, 0.032, 0.3)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.15 * side, 0.6, 0.03))
		var ts := Sculpt.new(); var tb := ts.add_painter(bark)
		ts.tube([Vector3(0.14 * side, 0.7, 0.03), Vector3(0.16 * side, 0.5, 0.02), Vector3(0.18 * side, 0.33, 0.0)], [0.12, 0.11, 0.095], tb, {"sides": 9, "ridges": 4, "ridge": 0.07, "lump": 0.1})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "RootKnee", Vector3(0.18 * side, 0.33, 0))
		var ss := Sculpt.new(); var sb := ss.add_painter(bark)
		ss.tube([Vector3(0.18 * side, 0.36, 0), Vector3(0.19 * side, 0.18, -0.02), Vector3(0.19 * side, 0.08, -0.03)], [0.095, 0.095, 0.11], sb, {"sides": 9, "ridges": 4, "ridge": 0.07, "lump": 0.1})
		roots(ss, sb, Vector3(0.19 * side, 0.08, -0.03), [Vector3(-0.35, 0, -1), Vector3(0.35, 0, -1), Vector3(0.95 * side, 0, -0.1), Vector3(0, 0, 1)], 0.2, 0.045, 0.06)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": beard}, 0.78)


## The chosen design: the Mossback Brute wearing the Capwood Sage's mushroom cap.
func _mossback() -> Node3D:
	var body := Sculpt.new()
	var back_moss := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := bark(p, n, v, w)
		return c.lerp(moss_color(p), smoothstep(0.0, 0.45, n.z * 0.8 + n.y * 0.6 + Sculpt.fbm(p * 5.0) * 0.4))
	var b := body.add_painter(back_moss); var m := body.add_painter(moss); var bb := body.add_painter(bare); var c := body.add_painter(cap)
	body.tube([Vector3(0, 0.52, 0.1), Vector3(0, 0.8, 0.12), Vector3(0, 1.08, 0.07), Vector3(0, 1.26, -0.05), Vector3(0, 1.38, -0.2)], [0.31, 0.39, 0.44, 0.37, 0.25], b, {"sides": 16, "ridges": 7, "ridge": 0.1, "lump": 0.12, "flat": 1.2})
	var patchy := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var bark_patch := smoothstep(-0.15, -0.35, Sculpt.fbm(p * 4.0 + Vector3(1, 9, 4)) - clampf(-n.y, 0.0, 1.0) * 0.5)
		return moss(p, n, v, w).lerp(bare(p, n, v, w), bark_patch))
	body.blob(Vector3(0, 1.15, 0.2), Vector3(0.36, 0.25, 0.25), patchy, {"lat": 9, "lon": 14, "lump": 0.35})
	for shroom in [[Vector3(-0.22, 1.33, 0.26), 0.2, -0.5], [Vector3(0.27, 1.25, 0.32), 0.15, 0.6], [Vector3(0.05, 1.1, 0.43), 0.12, 0.2]]:
		var at: Vector3 = shroom[0]; var size: float = shroom[1]
		var top := at + Vector3(shroom[2] * 0.05, size * 0.6, 0.04)
		body.tube([at - Vector3(0, 0.06, 0), at.lerp(top, 0.5) + Vector3(0, 0, 0.01), top], [size * 0.2, size * 0.15, size * 0.13], bb, {"sides": 7, "per": 2, "cap_rings": 1})
		mushroom_cap(body, c, top, size, Basis(Vector3.FORWARD, shroom[2] * 0.4))
	part(root, "Body", body)
	var saplings := [
		sprout(root, "BackSapling", Vector3(0.08, 1.37, 0.24), Vector3(0.2, 0, 0.5), 0.45, 6),
		sprout(root, "BackSproutLeft", Vector3(-0.3, 1.22, 0.3), Vector3(-0.6, 0, 0.4), 0.22, 3)]

	var head := joint(root, "Head", Vector3(0, 1.36, -0.3))
	var eyes := [Vector3(-0.09, 1.39, -0.645), Vector3(0.09, 1.39, -0.645)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.13, 1.255, 0.26, 0.05), -0.5, bare)); var hb := hs.add_painter(bare); var ht := hs.add_painter(tusk); var hc := hs.add_painter(cap)
	hs.blob(Vector3(0, 1.38, -0.47), Vector3(0.22, 0.19, 0.2), f, {"lat": 11, "lon": 16, "lump": 0.12})
	hs.tube([Vector3(-0.2, 1.47, -0.57), Vector3(-0.08, 1.455, -0.665), Vector3(0.08, 1.455, -0.665), Vector3(0.2, 1.47, -0.57)], [0.045, 0.058, 0.058, 0.045], hb, {"sides": 9, "per": 3, "cap_rings": 2, "lump": 0.2})
	hs.blob(Vector3(0, 1.36, -0.675), Vector3(0.05, 0.045, 0.045), hb, {"lat": 6, "lon": 8, "lump": 0.25})
	hs.blob(Vector3(0, 1.22, -0.55), Vector3(0.2, 0.075, 0.16), hb, {"lat": 7, "lon": 12, "lump": 0.2})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.12 * side, 1.23, -0.66), Vector3(0.14 * side, 1.33, -0.71), Vector3(0.12 * side, 1.39, -0.71)], [0.03, 0.02, 0.006], ht, {"sides": 6, "per": 2, "cap_rings": 1})
	mushroom_cap(hs, hc, Vector3(0, 1.53, -0.43), 0.74, Basis(Vector3.RIGHT, 0.26))
	part(head, "CappedHead", hs)
	var es := Sculpt.new(); var gp := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e + Vector3(0, 0, -0.005), Vector3(0.04, 0.032, 0.028), gp, {"lat": 5, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.48 * side, 1.28, -0.08))
		var us := Sculpt.new(); var ub := us.add_painter(bark); var um := us.add_painter(moss)
		us.tube([Vector3(0.33 * side, 1.34, -0.06), Vector3(0.55 * side, 1.29, -0.08), Vector3(0.63 * side, 1.13, -0.1), Vector3(0.65 * side, 1.0, -0.1)], [0.2, 0.19, 0.15, 0.125], ub, {"sides": 12, "ridges": 6, "ridge": 0.1, "lump": 0.12, "side": Vector3.BACK})
		moss_clump(us, um, Vector3(0.5 * side, 1.44, -0.06), 0.15, 4)
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "RootElbow", Vector3(0.65 * side, 1.0, -0.1))
		var fs := Sculpt.new(); var fb := fs.add_painter(bark); var fh := fs.add_painter(bare)
		fs.tube([Vector3(0.65 * side, 1.04, -0.1), Vector3(0.68 * side, 0.82, -0.13), Vector3(0.7 * side, 0.55, -0.16), Vector3(0.7 * side, 0.38, -0.18), Vector3(0.7 * side, 0.27, -0.2)], [0.13, 0.17, 0.175, 0.15, 0.15], fb, {"sides": 12, "per": 4, "ridges": 6, "ridge": 0.1, "lump": 0.12, "side": Vector3.BACK})
		roots(fs, fh, Vector3(0.7 * side, 0.22, -0.28), [Vector3(-0.4 * side, 0, -1), Vector3(0, 0, -1), Vector3(0.4 * side, 0, -1), Vector3(-0.9 * side, 0, -0.2)], 0.14, 0.048, 0.13)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.22 * side, 0.56, 0.12))
		var ts := Sculpt.new(); var tb := ts.add_painter(bark)
		ts.tube([Vector3(0.21 * side, 0.66, 0.12), Vector3(0.24 * side, 0.46, 0.1), Vector3(0.26 * side, 0.31, 0.07)], [0.18, 0.17, 0.15], tb, {"sides": 12, "ridges": 6, "ridge": 0.09, "lump": 0.1})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "RootKnee", Vector3(0.26 * side, 0.31, 0.07))
		var ss := Sculpt.new(); var sb := ss.add_painter(bark)
		ss.tube([Vector3(0.26 * side, 0.35, 0.07), Vector3(0.27 * side, 0.18, 0.04), Vector3(0.27 * side, 0.09, 0.02)], [0.15, 0.15, 0.17], sb, {"sides": 12, "ridges": 6, "ridge": 0.09, "lump": 0.1})
		roots(ss, sb, Vector3(0.27 * side, 0.08, 0.02), [Vector3(-0.35, 0, -1), Vector3(0.35, 0, -1), Vector3(0.95 * side, 0, -0.1), Vector3(0, 0, 1)], 0.24, 0.065, 0.06)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": saplings}, 0.97)


## C: a hunched, heavy-armed brute with a mossy back that saplings grow out of.
func _brute() -> Node3D:
	var body := Sculpt.new()
	var back_moss := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := bark(p, n, v, w)
		return c.lerp(moss_color(p), smoothstep(0.0, 0.45, n.z * 0.8 + n.y * 0.6 + Sculpt.fbm(p * 5.0) * 0.4))
	var b := body.add_painter(back_moss); var m := body.add_painter(moss)
	body.tube([Vector3(0, 0.52, 0.1), Vector3(0, 0.8, 0.12), Vector3(0, 1.08, 0.06), Vector3(0, 1.28, -0.08), Vector3(0, 1.38, -0.2)], [0.31, 0.39, 0.45, 0.41, 0.29], b, {"sides": 16, "ridges": 7, "ridge": 0.1, "lump": 0.12, "flat": 1.18})
	body.blob(Vector3(0, 1.2, 0.2), Vector3(0.38, 0.27, 0.27), m, {"lat": 8, "lon": 12, "lump": 0.4})
	part(root, "Body", body)
	var saplings := [
		sprout(root, "BackSapling", Vector3(0.1, 1.38, 0.28), Vector3(0.2, 0, 0.5), 0.5, 6),
		sprout(root, "BackSproutLeft", Vector3(-0.2, 1.32, 0.3), Vector3(-0.6, 0, 0.4), 0.26, 4),
		sprout(root, "BackSproutRight", Vector3(0.24, 1.22, 0.36), Vector3(0.6, 0, 0.5), 0.2, 3)]

	var head := joint(root, "Head", Vector3(0, 1.3, -0.28))
	var eyes := [Vector3(-0.095, 1.33, -0.59), Vector3(0.095, 1.33, -0.59)]
	var hs := Sculpt.new()
	var f := hs.add_painter(face(eyes, Rect2(-0.12, 1.19, 0.24, 0.035), -0.5)); var hb := hs.add_painter(bark); var ht := hs.add_painter(tusk)
	hs.blob(Vector3(0, 1.3, -0.42), Vector3(0.23, 0.19, 0.21), f, {"lat": 9, "lon": 14, "lump": 0.15})
	hs.tube([Vector3(-0.21, 1.41, -0.5), Vector3(-0.08, 1.4, -0.6), Vector3(0.08, 1.4, -0.6), Vector3(0.21, 1.41, -0.5)], [0.05, 0.07, 0.07, 0.05], hb, {"sides": 9, "per": 2, "cap_rings": 2, "lump": 0.25})
	hs.blob(Vector3(0, 1.16, -0.5), Vector3(0.21, 0.08, 0.17), hb, {"lat": 6, "lon": 12, "lump": 0.2})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.12 * side, 1.17, -0.62), Vector3(0.14 * side, 1.27, -0.66), Vector3(0.12 * side, 1.33, -0.66)], [0.03, 0.02, 0.006], ht, {"sides": 6, "per": 2, "cap_rings": 1})
	part(head, "Head", hs)
	var es := Sculpt.new(); var gp := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e + Vector3(0, 0, -0.005), Vector3(0.042, 0.032, 0.03), gp, {"lat": 5, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.48 * side, 1.28, -0.08))
		var us := Sculpt.new(); var ub := us.add_painter(bark); var um := us.add_painter(moss)
		us.tube([Vector3(0.33 * side, 1.33, -0.06), Vector3(0.57 * side, 1.27, -0.08), Vector3(0.65 * side, 1.01, -0.1)], [0.19, 0.18, 0.15], ub, {"sides": 11, "ridges": 5, "ridge": 0.07, "lump": 0.12, "side": Vector3.BACK})
		moss_clump(us, um, Vector3(0.52 * side, 1.42, -0.06), 0.17, 4)
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "RootElbow", Vector3(0.65 * side, 1.0, -0.1))
		var fs := Sculpt.new(); var fb := fs.add_painter(bark)
		fs.tube([Vector3(0.65 * side, 1.05, -0.1), Vector3(0.69 * side, 0.68, -0.15), Vector3(0.7 * side, 0.34, -0.18)], [0.15, 0.17, 0.19], fb, {"sides": 11, "ridges": 5, "ridge": 0.07, "lump": 0.12, "side": Vector3.BACK})
		fs.blob(Vector3(0.7 * side, 0.24, -0.19), Vector3(0.16, 0.12, 0.16), fb, {"lat": 6, "lon": 10, "lump": 0.25})
		roots(fs, fb, Vector3(0.7 * side, 0.2, -0.26), [Vector3(-0.4 * side, 0, -1), Vector3(0, 0, -1), Vector3(0.4 * side, 0, -1)], 0.14, 0.05, 0.12)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.22 * side, 0.56, 0.12))
		var ts := Sculpt.new(); var tb := ts.add_painter(bark)
		ts.tube([Vector3(0.21 * side, 0.66, 0.12), Vector3(0.24 * side, 0.46, 0.1), Vector3(0.26 * side, 0.31, 0.07)], [0.18, 0.17, 0.15], tb, {"sides": 10, "ridges": 5, "ridge": 0.07, "lump": 0.1})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "RootKnee", Vector3(0.26 * side, 0.31, 0.07))
		var ss := Sculpt.new(); var sb := ss.add_painter(bark)
		ss.tube([Vector3(0.26 * side, 0.35, 0.07), Vector3(0.27 * side, 0.18, 0.04), Vector3(0.27 * side, 0.09, 0.02)], [0.15, 0.15, 0.17], sb, {"sides": 10, "ridges": 5, "ridge": 0.07, "lump": 0.1})
		roots(ss, sb, Vector3(0.27 * side, 0.08, 0.02), [Vector3(-0.35, 0, -1), Vector3(0.35, 0, -1), Vector3(0.95 * side, 0, -0.1), Vector3(0, 0, 1)], 0.24, 0.065, 0.06)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": saplings}, 0.78)
