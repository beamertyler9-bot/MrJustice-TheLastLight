extends "res://tools/sculpt_stormhorn_matriarch.gd"
## The Stormhorn Matriarch, boss of the Windbell Plains, sculpted by hand: a colossal plated
## grazer with storm-shaped horns that stamps out a charge lane. Three designs, each far bigger
## than the storm beasts that roam the plains:
##   frill  - a horned frill-dinosaur: a great slate frill veined with lightning and fringed
##            with spikes, two long bolt-shaped brow horns and a beak
##   club   - a low, broad armoured dinosaur covered in bands of slate plates with lightning
##            crackling between them, side spikes, swept-back storm horns and a tail club
##   elk    - a towering giant elk with huge antlers whose tines are jagged lightning bolts,
##            slate armour on its shoulders and neck, and a dark shaggy mane


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "StormhornMatriarch"
	veins = {}
	match variant:
		"frill": return _frill()
		"club": return _club()
		"elk": return _elk()
	return null


## Height of the top of a body tube and its radius at z, from its spine points and radii.
static func along(spine: Array, radii: Array, z: float) -> Vector2:
	for k in range(spine.size() - 1):
		var a: Vector3 = spine[k]; var b: Vector3 = spine[k + 1]
		if (z <= a.z and z >= b.z) or (z >= a.z and z <= b.z):
			var t := (z - a.z) / (b.z - a.z)
			return Vector2(lerpf(a.y, b.y, t), lerpf(radii[k], radii[k + 1], t))
	var last: Vector3 = spine[-1] if absf(z - (spine[-1] as Vector3).z) < absf(z - (spine[0] as Vector3).z) else spine[0]
	return Vector2(last.y, radii[-1] if last == spine[-1] else radii[0])


## A storm horn grown straight from base along dir, `count` points long.
func bolt_horn(s: Sculpt, painter: int, parent: Node3D, base: Vector3, dir: Vector3, length: float, radius: float, jag: float, across: Vector3, curl := Vector3.ZERO, count := 6) -> void:
	var pts: Array = []
	for k in range(count):
		var t := float(k) / (count - 1)
		pts.append(base + dir.normalized() * length * t + curl * t * t)
	storm_horn(s, painter, parent, pts, radius, jag, across)


## Darker slate for armour that should read against the sky.
static func slate_dark(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	return slate(p, n, v, w).darkened(0.3)


static func antler(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#5e4c3a").lerp(Color("#d9ccb2"), clampf(v * 0.9 + n.y * 0.15, 0.0, 1.0))
	return c.darkened(Sculpt.noise(p * 25.0) * 0.1)


# ------------------------------------------------------------------ A: storm frill

func _frill() -> Node3D:
	var skin := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#66716a").lerp(Color("#343d39"), clampf(n.y * 0.5 + 0.25 + Sculpt.fbm(p * 5.0) * 0.5, 0.0, 1.0))
		var band := sin(p.z * 16.0 + Sculpt.fbm(p * 2.0) * 3.0)
		c = c.lerp(Color("#28302d"), smoothstep(0.55, 0.8, band) * smoothstep(0.1, 0.6, n.y) * 0.7)
		return c.lerp(Color("#a9a58d"), smoothstep(-0.3, -0.8, n.y) * 0.6)
	var spine := [Vector3(0, 0.84, 0.78), Vector3(0, 0.96, 0.42), Vector3(0, 0.94, 0.05), Vector3(0, 0.87, -0.3), Vector3(0, 0.78, -0.5)]
	var radii := [0.3, 0.44, 0.46, 0.42, 0.33]
	var body := Sculpt.new(); var bp := body.add_painter(skin); var plate := body.add_painter(slate_dark)
	body.tube(spine, radii, bp, {"sides": 18, "per": 3, "flat": 0.84, "lump": 0.04})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.2 * side, 0.88, 0.45), Vector3(0.2, 0.3, 0.28), bp, {"lat": 7, "lon": 10})
		body.blob(Vector3(0.22 * side, 0.78, -0.3), Vector3(0.18, 0.26, 0.22), bp, {"lat": 7, "lon": 10})
	body.tube([Vector3(0, 0.8, -0.45), Vector3(0, 0.75, -0.64)], [0.3, 0.25], bp, {"sides": 14, "per": 2, "flat": 0.85})
	# Rows of bony knobs down the back.
	for k in range(12):
		var z := -0.4 + k * 0.1
		var at := along(spine, radii, z)
		for j in [-2, -1, 0, 1, 2]:
			var ang: float = j * 0.38
			var r: float = at.y * (1.0 - absf(j) * 0.02)
			var c := Vector3(sin(ang) * r * 0.84, at.x + cos(ang) * r - 0.01, z + (0.05 if j % 2 == 0 else 0.0))
			body.rock(c, Vector3(0.06, 0.035, 0.06) * (1.3 if j == 0 else 1.0), plate, {"lat": 3, "lon": 5, "lump": 0.2})
	var head := joint(root, "Head", Vector3(0, 0.74, -0.66))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin); var horn := hs.add_painter(horn_paint)
	var beak := hs.add_painter(func (p, n, v, w): return Color("#2a2622").lerp(Color("#5a524a"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0)))
	var frill_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var q := p - Vector3(0, 0.8, -0.66)
		var ang := atan2(q.x, q.y)
		var rad := Vector2(q.x, q.y - 0.05).length()
		var c := Color("#29323f").lerp(Color("#667a8f"), clampf(rad * 1.4 - 0.2 + Sculpt.noise(p * 8.0) * 0.2, 0.0, 1.0))
		c = c.lerp(Color("#1b222b"), smoothstep(0.6, 0.85, sin(ang * 9.0)) * smoothstep(0.15, 0.3, rad) * 0.6)
		return c.lerp(Color("#a6b4c1"), smoothstep(0.62, 0.7, rad) * 0.6)
	var fp := hs.add_painter(frill_paint)
	# A long beaked skull.
	hs.blob(Vector3(0, 0.76, -0.75), Vector3(0.2, 0.2, 0.2), hp, {"lat": 9, "lon": 12})
	hs.tube([Vector3(0, 0.74, -0.8), Vector3(0, 0.66, -0.98), Vector3(0, 0.57, -1.1)], [0.17, 0.13, 0.085], hp, {"sides": 12, "per": 3, "flat": 0.78, "square": 0.2, "cap1": false})
	hs.tube([Vector3(0, 0.57, -1.09), Vector3(0, 0.5, -1.18), Vector3(0, 0.44, -1.22)], [0.085, 0.05, 0.01], beak, {"sides": 10, "per": 2, "flat": 0.7, "cap0": false})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.13 * side, 0.86, -0.85), Vector3(0.07, 0.035, 0.06), hp, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.16 * side, 0.68, -0.8), Vector3(0.07, 0.09, 0.1), hp, {"lat": 5, "lon": 8})
		hs.crystal(Vector3(0.2 * side, 0.66, -0.78), Vector3(side, -0.6, 0.3), 0.12, 0.03, horn, 6)
	# The frill: a great shield rising up and back from the skull.
	var fb := Basis(Vector3.RIGHT, 0.55)
	var fc := Vector3(0, 1.05, -0.56)
	hs.blob(fc, Vector3(0.62, 0.5, 0.045), fp, {"lat": 12, "lon": 22, "basis": fb})
	var face := fb * Vector3(0, 0, -1)
	# Spikes round the rim, with two tall storm-bolt spikes at the top.
	for k in range(15):
		var a := lerpf(-1.75, 1.75, k / 14.0)
		var out := fb * Vector3(sin(a), cos(a), 0)
		var rim := fc + fb * Vector3(sin(a) * 0.6, cos(a) * 0.48, 0)
		if k == 5 or k == 9:
			bolt_horn(hs, horn, head, rim - out * 0.04, out + Vector3(0, 0.3, 0), 0.42, 0.05, 0.03, face, Vector3(0, 0, 0.05))
		else:
			hs.crystal(rim - out * 0.03, out, 0.15 + 0.05 * cos(a * 2.0), 0.035, horn, 5)
	# Lightning veins branching across the face of the frill.
	for a in [-1.2, -0.6, 0.0, 0.6, 1.2]:
		var from := fc + fb * Vector3(sin(a) * 0.1, cos(a) * 0.08 - 0.05, 0) + face * 0.05
		var to := fc + fb * Vector3(sin(a) * 0.5, cos(a) * 0.4, 0) + face * 0.05
		spark(head, from, to, 4, 0.03, fb * Vector3(cos(a), -sin(a), 0), 0.011)
	# Two long brow horns that sweep forward and break into bolts; a short nose horn.
	for side in [-1.0, 1.0]:
		bolt_horn(hs, horn, head, Vector3(0.1 * side, 0.9, -0.8), Vector3(0.12 * side, 0.4, -1.0), 0.62, 0.065, 0.03, Vector3.UP, Vector3(0, 0.08, 0), 7)
	bolt_horn(hs, horn, head, Vector3(0, 0.72, -1.0), Vector3(0, 1.0, -0.4), 0.16, 0.045, 0.012, Vector3(0, 0, 1), Vector3.ZERO, 4)
	var jaw := joint(head, "Jaw", Vector3(0, 0.6, -0.82))
	var js := Sculpt.new(); var jp := js.add_painter(skin); var jb := js.add_painter(func (p, n, v, w): return Color("#2a2622"))
	js.tube([Vector3(0, 0.6, -0.8), Vector3(0, 0.53, -1.0)], [0.12, 0.08], jp, {"sides": 10, "per": 2, "flat": 0.75, "cap1": false})
	js.tube([Vector3(0, 0.53, -0.99), Vector3(0, 0.49, -1.12)], [0.08, 0.02], jb, {"sides": 10, "per": 2, "flat": 0.7, "cap0": false})
	var eye_sculpt := eyes([Vector3(-0.172, 0.82, -0.85), Vector3(0.172, 0.82, -0.85)], Vector3(0.026, 0.02, 0.024))
	var leg_rig := legs(skin, 0.27, -0.3, 0.45, 0.8, 1.45, Callable(), 3)
	var tail := joint(root, "Tail", Vector3(0, 0.84, 0.76))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin)
	ts.tube([Vector3(0, 0.86, 0.72), Vector3(0, 0.8, 0.96), Vector3(0, 0.7, 1.16)], [0.22, 0.16, 0.11], tp, {"sides": 12, "per": 3, "flat": 0.85, "cap1": false})
	var tip := joint(tail, "TailTip", Vector3(0, 0.7, 1.16))
	var tts := Sculpt.new(); var ttp := tts.add_painter(skin)
	tts.tube([Vector3(0, 0.7, 1.14), Vector3(0, 0.6, 1.4), Vector3(0, 0.52, 1.62)], [0.11, 0.065, 0.015], ttp, {"sides": 10, "per": 3, "flat": 0.85, "cap0": false})
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": [], "ear_sculpts": [],
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail, tip], "tail_sculpts": [ts, tts], "fronds": [], "frond_sculpts": []}, 2.0)


# ------------------------------------------------------------------ B: storm club

func _club() -> Node3D:
	var skin := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#5a5444").lerp(Color("#36322a"), clampf(n.y * 0.5 + 0.2 + Sculpt.fbm(p * 6.0) * 0.5, 0.0, 1.0))
		return c.lerp(Color("#9a9078"), smoothstep(-0.3, -0.8, n.y) * 0.5)
	var spine := [Vector3(0, 0.62, 0.76), Vector3(0, 0.72, 0.4), Vector3(0, 0.74, 0.0), Vector3(0, 0.7, -0.35), Vector3(0, 0.62, -0.56)]
	var radii := [0.3, 0.42, 0.44, 0.4, 0.3]
	var wide := 1.45
	var body := Sculpt.new(); var bp := body.add_painter(skin); var plate := body.add_painter(slate_dark)
	body.tube(spine, radii, bp, {"sides": 20, "per": 3, "flat": wide, "lump": 0.03})
	body.tube([Vector3(0, 0.66, -0.5), Vector3(0, 0.6, -0.68)], [0.29, 0.25], bp, {"sides": 16, "per": 2, "flat": 1.3})
	var horn := body.add_painter(horn_paint)
	# Bands of slate plates over the back, a ring of spikes down each side and storm light
	# crackling in the seams between bands.
	for k in range(10):
		var z := -0.5 + k * 0.13
		var at := along(spine, radii, z)
		var r: float = at.y
		for j in range(-4, 5):
			var ang: float = j * 0.3 + (0.15 if k % 2 == 1 else 0.0)
			if absf(ang) > 1.3: continue
			var outward := Vector3(sin(ang) * wide, cos(ang), 0).normalized()
			var c := Vector3(sin(ang) * r * wide * 0.98, at.x + cos(ang) * r * 0.98, z)
			var size := 0.1 if absf(j) < 3 else 0.08
			body.rock(c, Vector3(size, 0.04, size * 0.85), plate, {"lat": 4, "lon": 6, "lump": 0.2, "basis": Basis.looking_at(outward, Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)})
		for side in [-1.0, 1.0]:
			var base := Vector3(side * r * wide * 0.97, at.x + 0.02, z)
			var big := k < 3
			if big and k != 1:
				bolt_horn(body, horn, root, base, Vector3(side, 0.35, 0.35), 0.4 - k * 0.06, 0.06, 0.025, Vector3.UP, Vector3(0, 0, 0.06), 5)
			else:
				body.crystal(base, Vector3(side, 0.2, 0.5), 0.2 - absf(z) * 0.06, 0.04, horn, 5)
		if k % 3 == 1:
			var seam := z + 0.065
			var s2 := along(spine, radii, seam)
			for side in [-1.0, 1.0]:
				var a0 := Vector3(0, s2.x + s2.y + 0.07, seam)
				var a1 := Vector3(side * sin(1.15) * s2.y * wide * 1.04, s2.x + cos(1.15) * s2.y + 0.06, seam)
				spark(root, a0, a1, 5, 0.035, Vector3(0, 0, 1), 0.017)
	var head := joint(root, "Head", Vector3(0, 0.6, -0.7))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin); var hplate := hs.add_painter(slate); var hhorn := hs.add_painter(horn_paint)
	var beak := hs.add_painter(func (p, n, v, w): return Color("#2a2622"))
	# A low, broad, triangular head capped with plates.
	hs.blob(Vector3(0, 0.6, -0.8), Vector3(0.24, 0.15, 0.2), hp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 0.58, -0.86), Vector3(0, 0.52, -1.02)], [0.16, 0.1], hp, {"sides": 12, "per": 2, "flat": 1.4, "cap1": false})
	hs.tube([Vector3(0, 0.52, -1.01), Vector3(0, 0.49, -1.08)], [0.1, 0.03], beak, {"sides": 12, "per": 2, "flat": 1.4, "cap0": false})
	for i in range(5):
		var x := (i - 2) * 0.085
		hs.rock(Vector3(x, 0.73 - absf(x) * 0.3, -0.8 - absf(x) * 0.1), Vector3(0.05, 0.025, 0.06), hplate, {"lat": 3, "lon": 6, "lump": 0.2})
	hs.rock(Vector3(0, 0.66, -0.98), Vector3(0.07, 0.03, 0.06), hplate, {"lat": 3, "lon": 6, "lump": 0.2})
	# Storm horns swept back from the corners of the skull; short horns on the cheeks.
	for side in [-1.0, 1.0]:
		storm_horn(hs, hhorn, head, [Vector3(0.2 * side, 0.66, -0.72), Vector3(0.3 * side, 0.7, -0.68), Vector3(0.38 * side, 0.76, -0.62),
			Vector3(0.43 * side, 0.83, -0.56), Vector3(0.48 * side, 0.9, -0.5), Vector3(0.52 * side, 0.97, -0.43)], 0.06, 0.03, Vector3.UP)
		hs.crystal(Vector3(0.22 * side, 0.54, -0.78), Vector3(side * 0.7, -0.5, 0.4), 0.13, 0.035, hhorn, 5)
	var jaw := joint(head, "Jaw", Vector3(0, 0.5, -0.84))
	var js := Sculpt.new(); var jp := js.add_painter(skin)
	js.tube([Vector3(0, 0.5, -0.82), Vector3(0, 0.46, -1.0)], [0.12, 0.08], jp, {"sides": 10, "per": 2, "flat": 1.4, "cap_rings": 2})
	var eye_sculpt := eyes([Vector3(-0.226, 0.64, -0.86), Vector3(0.226, 0.64, -0.86)], Vector3(0.024, 0.018, 0.022))
	var leg_rig := legs(skin, 0.36, -0.35, 0.45, 0.6, 1.5, Callable(), 3)
	# A long tail ending in a heavy bony club that crackles with lightning.
	var tail := joint(root, "Tail", Vector3(0, 0.64, 0.74))
	var ts := Sculpt.new(); var tp := ts.add_painter(skin); var tpl := ts.add_painter(slate)
	ts.tube([Vector3(0, 0.64, 0.7), Vector3(0, 0.6, 0.98), Vector3(0, 0.52, 1.3)], [0.25, 0.16, 0.09], tp, {"sides": 14, "per": 3, "flat": 1.2, "cap1": false})
	for k in range(4):
		var z := 0.82 + k * 0.13
		for side in [-1.0, 1.0]: ts.crystal(Vector3(side * (0.2 - k * 0.035), 0.6 - k * 0.025, z), Vector3(side, 0.1, 0.4), 0.11, 0.03, ts.add_painter(horn_paint), 5)
	var tip := joint(tail, "TailTip", Vector3(0, 0.52, 1.3))
	var tts := Sculpt.new(); var ttp := tts.add_painter(skin); var club := tts.add_painter(slate)
	tts.tube([Vector3(0, 0.52, 1.28), Vector3(0, 0.48, 1.56)], [0.09, 0.07], ttp, {"sides": 10, "per": 2, "cap0": false})
	for side in [-1.0, 1.0]:
		tts.rock(Vector3(0.1 * side, 0.47, 1.66), Vector3(0.13, 0.1, 0.16), club, {"lat": 6, "lon": 9, "lump": 0.18})
	tts.rock(Vector3(0, 0.47, 1.72), Vector3(0.09, 0.09, 0.1), club, {"lat": 5, "lon": 8, "lump": 0.18})
	for a in [0.0, 1.6, 3.2, 4.7]:
		spark(tip, Vector3(0, 0.47, 1.66) + Vector3(cos(a) * 0.12, sin(a) * 0.1, -0.12), Vector3(0, 0.47, 1.66) + Vector3(cos(a) * 0.2, sin(a) * 0.12, 0.12), 3, 0.025, Vector3(-sin(a), cos(a), 0), 0.011)
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": [], "ear_sculpts": [],
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail, tip], "tail_sculpts": [ts, tts], "fronds": [], "frond_sculpts": []}, 2.1)


# ------------------------------------------------------------------ C: storm elk

func _elk() -> Node3D:
	var coat := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#76604a").lerp(Color("#4c3b2b"), clampf(n.y * 0.4 + Sculpt.fbm(p * 7.0) * 0.5 + 0.2, 0.0, 1.0))
		c = c.lerp(Color("#3a2c20"), smoothstep(-0.35, -0.6, p.z) * smoothstep(1.1, 1.3, p.y) * 0.8)
		c = c.lerp(Color("#d9cdb4"), smoothstep(0.45, 0.62, p.z) * smoothstep(0.9, 1.05, p.y) * smoothstep(0.3, 0.0, absf(p.x)) * 0.8)
		return c.darkened(smoothstep(0.7, 0.3, p.y) * 0.35)
	var mane := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#2b2018").lerp(Color("#5a4430"), clampf(Sculpt.noise(p * 12.0) * 0.4 + 0.3 + (1.0 - v) * 0.2, 0.0, 1.0))
	var body := Sculpt.new(); var bp := body.add_painter(coat); var mp := body.add_painter(mane); var plate := body.add_painter(slate_dark)
	body.tube([Vector3(0, 1.1, 0.6), Vector3(0, 1.14, 0.35), Vector3(0, 1.12, 0.0), Vector3(0, 1.2, -0.3), Vector3(0, 1.24, -0.45)], [0.24, 0.3, 0.31, 0.33, 0.28], bp, {"sides": 16, "per": 3, "flat": 0.75, "lump": 0.03})
	body.blob(Vector3(0, 1.4, -0.3), Vector3(0.18, 0.16, 0.25), bp, {"lat": 7, "lon": 10})
	body.blob(Vector3(0, 1.04, -0.44), Vector3(0.2, 0.24, 0.2), bp, {"lat": 7, "lon": 10})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.12 * side, 1.12, 0.45), Vector3(0.12, 0.2, 0.2), bp, {"lat": 6, "lon": 9})
	body.tube([Vector3(0, 1.28, -0.45), Vector3(0, 1.46, -0.62), Vector3(0, 1.62, -0.72)], [0.26, 0.18, 0.14], bp, {"sides": 14, "per": 3, "flat": 0.8})
	# A shaggy dark mane down the throat.
	for k in range(14):
		var t := k / 13.0
		var at := Vector3(0, lerpf(1.52, 1.12, t), lerpf(-0.74, -0.52, t))
		for side in [-1.0, 1.0]:
			lock(body, mp, at + Vector3(0.06 * side, -0.05, -0.08), Vector3(side * 0.3, -1.0, -0.2), 0.2 + 0.08 * sin(t * PI), 0.045, Vector3(side, 0, 0), 0.05, 5, 1)
	# Slate armour plates over the shoulders and down the top of the neck.
	for k in range(6):
		var t := k / 5.0
		var at := Vector3(0, lerpf(1.8, 1.58, t), lerpf(-0.7, -0.4, t))
		body.rock(at + Vector3(0, 0.02, 0), Vector3(0.1 - t * 0.02, 0.035, 0.08), plate, {"lat": 4, "lon": 6, "lump": 0.15, "basis": Basis(Vector3.RIGHT, -0.7 + t * 0.4)})
	for side in [-1.0, 1.0]:
		for k in range(2):
			body.rock(Vector3(0.13 * side + 0.07 * k * side, 1.53 - k * 0.07, -0.32 + k * 0.02), Vector3(0.1, 0.035, 0.12), plate, {"lat": 4, "lon": 6, "lump": 0.15, "basis": Basis.from_euler(Vector3(0, 0, -side * (0.35 + k * 0.35)))})
	var head := joint(root, "Head", Vector3(0, 1.62, -0.74))
	var hs := Sculpt.new(); var hp := hs.add_painter(coat); var horn := hs.add_painter(antler); var nose := hs.add_painter(func (p, n, v, w): return NOSE.lightened(clampf(n.y, 0.0, 1.0) * 0.15))
	var hm := hs.add_painter(mane)
	hs.blob(Vector3(0, 1.67, -0.8), Vector3(0.12, 0.12, 0.14), hp, {"lat": 8, "lon": 11})
	hs.tube([Vector3(0, 1.65, -0.86), Vector3(0, 1.57, -1.0), Vector3(0, 1.51, -1.08)], [0.1, 0.08, 0.065], hp, {"sides": 11, "per": 3, "square": 0.3, "flat": 0.9, "cap_rings": 2, "cap_len": 0.5})
	hs.blob(Vector3(0, 1.5, -1.12), Vector3(0.06, 0.045, 0.03), nose, {"lat": 4, "lon": 8})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.025 * side, 1.505, -1.145), Vector3(0.012, 0.016, 0.006), hs.add_painter(func (p, n, v, w): return Color("#080706")), {"lat": 3, "lon": 6})
		hs.blob(Vector3(0.1 * side, 1.72, -0.86), Vector3(0.04, 0.02, 0.03), hp, {"lat": 4, "lon": 6})
	for k in range(6):
		lock(hs, hm, Vector3((k - 2.5) * 0.02, 1.52, -0.9 + absf(k - 2.5) * 0.01), Vector3(0, -1, 0.2), 0.14, 0.03, Vector3.RIGHT, 0.05, 5, 1)
	# The antlers: thick beams sweeping out and back to broad palms, every tine a jagged
	# lightning bolt with a glowing tip.
	for side in [-1.0, 1.0]:
		var beam := [Vector3(0.07 * side, 1.77, -0.76), Vector3(0.25 * side, 1.84, -0.74), Vector3(0.48 * side, 1.9, -0.66), Vector3(0.7 * side, 1.98, -0.56)]
		hs.tube(beam, [0.06, 0.052, 0.046, 0.04], horn, {"sides": 9, "per": 3, "lump": 0.08})
		hs.blob(Vector3(0.88 * side, 2.02, -0.46), Vector3(0.3, 0.05, 0.21), horn, {"lat": 6, "lon": 10, "basis": Basis(Vector3.FORWARD, -side * 0.35) * Basis(Vector3.UP, side * 0.3)})
		# The brow tine juts forward over the face.
		bolt_horn(hs, horn, head, Vector3(0.14 * side, 1.82, -0.76), Vector3(0.15 * side, 0.4, -1.0), 0.26, 0.028, 0.018, Vector3.UP, Vector3.ZERO, 5)
		bolt_horn(hs, horn, head, Vector3(0.36 * side, 1.86, -0.71), Vector3(0.1 * side, 1.0, -0.5), 0.3, 0.03, 0.022, Vector3(0, 0, 1), Vector3.ZERO, 5)
		for k in range(5):
			var a := lerpf(-0.9, 0.9, k / 4.0)
			var edge := Vector3(0.88 * side, 2.02, -0.46) + Basis(Vector3.UP, side * 0.3) * Vector3(side * 0.24 * cos(a), 0.06 + 0.1 * cos(a), sin(a) * 0.19)
			var up := Vector3(side * 0.45 * cos(a), 1.0, sin(a) * 0.5 - 0.15)
			bolt_horn(hs, horn, head, edge, up, 0.26 + 0.08 * cos(a), 0.026, 0.02, Vector3(0, 0, 1), Vector3.ZERO, 5)
	var jaw := joint(head, "Jaw", Vector3(0, 1.55, -0.88))
	var js := Sculpt.new(); var jp := js.add_painter(coat)
	js.tube([Vector3(0, 1.55, -0.86), Vector3(0, 1.49, -1.04)], [0.06, 0.042], jp, {"sides": 9, "per": 2, "flat": 1.0, "cap_rings": 2})
	var eye_sculpt := eyes([Vector3(-0.113, 1.68, -0.86), Vector3(0.113, 1.68, -0.86)], Vector3(0.022, 0.018, 0.02))
	var ears: Array = []; var ear_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var ear := joint(head, "EarLeft" if side < 0 else "EarRight", Vector3(0.1 * side, 1.73, -0.74))
		var xs := Sculpt.new(); var xp := xs.add_painter(coat)
		xs.tube([Vector3(0.1 * side, 1.73, -0.74), Vector3(0.18 * side, 1.77, -0.72), Vector3(0.24 * side, 1.78, -0.7)], [0.035, 0.04, 0.012], xp, {"sides": 7, "per": 2, "flat": 0.4, "side": Vector3(0, 1, 0.3), "cap_rings": 1})
		ears.append(ear); ear_sculpts.append(xs)
	var leg_rig := legs(coat, 0.15, -0.36, 0.48, 1.1, 0.78, Callable(), 2, 1.65)
	var tail := joint(root, "Tail", Vector3(0, 1.16, 0.62))
	var ts := Sculpt.new(); var tp := ts.add_painter(coat)
	ts.tube([Vector3(0, 1.16, 0.6), Vector3(0, 1.1, 0.68), Vector3(0, 1.02, 0.7)], [0.045, 0.04, 0.03], tp, {"sides": 7, "per": 2, "cap1": false})
	var tip := joint(tail, "TailTip", Vector3(0, 1.02, 0.7))
	var tts := Sculpt.new(); var ttp := tts.add_painter(coat)
	tts.tube([Vector3(0, 1.02, 0.69), Vector3(0, 0.96, 0.71)], [0.03, 0.01], ttp, {"sides": 7, "per": 2, "cap0": false})
	return _close({"body": body, "head": head, "head_sculpt": hs, "jaw": jaw, "jaw_sculpt": js, "eye_sculpt": eye_sculpt, "ears": ears, "ear_sculpts": ear_sculpts,
		"hips": leg_rig.hips, "knees": leg_rig.knees, "tails": [tail, tip], "tail_sculpts": [ts, tts], "fronds": [], "frond_sculpts": []}, 1.6)
