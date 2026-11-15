extends "res://tools/creature_kit.gd"
## The Cliffwarden, sculpted by hand: a golem that sleeps as part of a Mosswake cliff, with
## rocky shoulders and lichen camouflage, and wakes in a patter of pebbles to sweep the ledge
## with its great right arm. About two and a quarter times Mr. Justice's height.

const STRATA := [Color("#8a7d68"), Color("#b0a389"), Color("#6a5d4d"), Color("#9c8f78"), Color("#5e564b")]
const ROCK_DARK := Color("#3a352f")
const LICHEN_ORANGE := Color("#d68b2e")
const LICHEN_GREEN := Color("#b8c27a")
const FACE_GLOW := Color("#a8f0c8")


func _init() -> void:
	super("res://assets/cast/stone_detail_gray.png")
	material.uv1_scale = Vector3(1.8, 1.8, 1.8)
	material.vertex_color_is_srgb = true
	glow.albedo_color = FACE_GLOW.darkened(0.3); glow.emission = FACE_GLOW
	glow.emission_energy_multiplier = 1.0


## Cliff rock: horizontal bands of different stone like a cliff face, dark seams between
## them, lichen crusts and moss on top.
static func strata(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var level := p.y * 5.5 + Sculpt.noise(p * 2.2) * 0.7
	var band := int(floor(level))
	var c: Color = STRATA[posmod(band, STRATA.size())]
	c = c.lerp(c.lightened(0.1), clampf(Sculpt.fbm(p * 6.0) * 0.6, 0.0, 1.0))
	var seam: float = level - floor(level)
	c = c.lerp(ROCK_DARK, smoothstep(0.16, 0.0, seam) * 0.8)
	c = c.lerp(ROCK_DARK, clampf(-n.y, 0.0, 1.0) * 0.3)
	var lichen := Sculpt.noise(p * 9.0 + Vector3(4, 2, 7))
	c = c.lerp(LICHEN_ORANGE, smoothstep(0.55, 0.62, lichen) * 0.8)
	c = c.lerp(LICHEN_GREEN, smoothstep(0.56, 0.64, Sculpt.noise(p * 11.0 + Vector3(9, 1, 3))) * 0.7)
	return c.lerp(moss_color(p), smoothstep(0.68, 0.9, n.y + 0.3 * Sculpt.fbm(p * 4.0)))


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Cliffwarden"
	match variant:
		"strata": return _golem(false, false)
		"ledge": return _golem(true, false)
		"slab": return _golem(false, true)
		"classic": return _classic(false)
		"classic_lichen": return _classic(true)
	return null


## The golem. ledge: a cliff ledge on its back with a little tree and a bird's nest.
## slab: built from big angular slabs rather than smooth rock.
func _golem(ledge: bool, slab: bool) -> Node3D:
	var paint := strata
	var body := Sculpt.new(); var bp := body.add_painter(paint)
	if slab:
		body.rock(Vector3(0, 1.05, 0.08), Vector3(0.42, 0.3, 0.32), bp, {"lat": 5, "lon": 7, "lump": 0.25})
		body.rock(Vector3(0, 1.5, 0.08), Vector3(0.55, 0.35, 0.38), bp, {"lat": 5, "lon": 8, "lump": 0.25, "basis": Basis(Vector3.UP, 0.3)})
		body.rock(Vector3(0, 1.85, 0.12), Vector3(0.4, 0.2, 0.3), bp, {"lat": 4, "lon": 7, "lump": 0.3})
		body.rock(Vector3(0, 0.78, 0.06), Vector3(0.36, 0.2, 0.28), bp, {"lat": 4, "lon": 7, "lump": 0.25})
	else:
		body.tube([Vector3(0, 0.72, 0.08), Vector3(0, 1.05, 0.1), Vector3(0, 1.4, 0.12), Vector3(0, 1.7, 0.12), Vector3(0, 1.88, 0.1)], [0.36, 0.4, 0.5, 0.52, 0.36], bp, {"sides": 16, "per": 3, "flat": 1.2, "lump": 0.12})
	# Rocky shoulders: big outcrops, the right one heavier.
	body.rock(Vector3(-0.5, 1.88, 0.08), Vector3(0.24, 0.16, 0.24), bp, {"lat": 5, "lon": 7, "lump": 0.3, "basis": Basis(Vector3.BACK, -0.3)})
	body.rock(Vector3(0.56, 1.92, 0.08), Vector3(0.32, 0.2, 0.3), bp, {"lat": 5, "lon": 7, "lump": 0.3, "basis": Basis(Vector3.BACK, 0.3)})
	var leaves: Array = []
	if ledge:
		body.rock(Vector3(0, 1.98, 0.42), Vector3(0.5, 0.08, 0.32), bp, {"lat": 4, "lon": 8, "lump": 0.2})
		var nest := body.add_painter(func (p, n, v, w): return Color("#7a5a36").lerp(Color("#a8865a"), clampf(0.5 + Sculpt.noise(p * 30.0), 0.0, 1.0)))
		var egg := body.add_painter(func (p, n, v, w): return Color("#a9d4e0").lerp(Color("#5c8899"), smoothstep(0.35, 0.5, Sculpt.noise(p * 40.0))))
		var pts: Array = []; var radii: Array = []
		for k in range(11):
			var ang := TAU * k / 9.0
			pts.append(Vector3(-0.22 + cos(ang) * 0.11, 2.07, 0.5 + sin(ang) * 0.11)); radii.append(0.035)
		body.tube(pts, radii, nest, {"sides": 6, "per": 2, "lump": 0.6, "flat": 0.7, "side": Vector3.UP})
		for e in [Vector3(-0.24, 2.07, 0.49), Vector3(-0.19, 2.07, 0.53)]: body.blob(e, Vector3(0.032, 0.026, 0.026), egg, {"lat": 4, "lon": 7})
		leaves.append(sprout(root, "LedgeTree", Vector3(0.18, 2.03, 0.45), Vector3(0.3, 0, 0.3), 0.42, 7))
	leaves.append(sprout(root, "ShoulderGrass", Vector3(-0.52, 2.0, 0.08), Vector3(-0.5, 0, 0.1), 0.18, 4))
	leaves.append(sprout(root, "ShoulderSprig", Vector3(0.6, 2.08, 0.12), Vector3(0.5, 0, 0.2), 0.22, 5))
	part(root, "Body", body)

	# The head: an outcrop with a deep, dark face and two glowing eyes under a heavy ledge brow.
	var head := joint(root, "Head", Vector3(0, 1.92, -0.12))
	var hs := Sculpt.new(); var hp := hs.add_painter(paint); var dark := hs.add_painter(func (p, n, v, w): return Color("#0e0d0c"))
	hs.rock(Vector3(0, 2.1, -0.2), Vector3(0.28, 0.24, 0.26), hp, {"lat": 6, "lon": 9, "lump": 0.2})
	hs.blob(Vector3(0, 2.07, -0.33), Vector3(0.16, 0.1, 0.08), dark, {"lat": 6, "lon": 10})
	hs.rock(Vector3(0, 2.22, -0.38), Vector3(0.3, 0.07, 0.13), hp, {"lat": 4, "lon": 7, "lump": 0.25, "basis": Basis(Vector3.RIGHT, -0.25)})
	hs.rock(Vector3(0, 1.93, -0.36), Vector3(0.2, 0.06, 0.1), hp, {"lat": 4, "lon": 7, "lump": 0.2})
	part(head, "OutcropHead", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.075 * side, 2.08, -0.405), Vector3(0.035, 0.022, 0.015), ew, {"lat": 4, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow)
	core.material_override = glow

	# Arms: the left one ordinary for a golem, the right one huge, ending in a slab of a fist
	# for sweeping ledges.
	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var big: bool = side > 0.0
		var k: float = 1.35 if big else 1.0
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.6 * side, 1.72, 0.08))
		var us := Sculpt.new(); var up := us.add_painter(paint)
		us.tube([Vector3(0.45 * side, 1.82, 0.08), Vector3(0.7 * side, 1.66, 0.08), Vector3(0.78 * side, 1.36, 0.07), Vector3(0.79 * side, 1.2, 0.08)], [0.2 * k, 0.19 * k, 0.16 * k, 0.15 * k], up, {"sides": 12, "per": 3, "lump": 0.15, "side": Vector3.BACK})
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "Elbow", Vector3(0.79 * side, 1.18, 0.08))
		var fs := Sculpt.new(); var fp := fs.add_painter(paint)
		fs.tube([Vector3(0.79 * side, 1.22, 0.08), Vector3(0.83 * side, 0.92, 0.04), Vector3(0.85 * side, 0.7, 0.0)], [0.16 * k, 0.2 * k, 0.18 * k], fp, {"sides": 12, "per": 3, "lump": 0.15, "side": Vector3.BACK})
		if big:
			fs.rock(Vector3(0.88, 0.48, -0.04), Vector3(0.3, 0.26, 0.3), fp, {"lat": 5, "lon": 8, "lump": 0.25, "basis": Basis(Vector3.UP, 0.4)})
			for f in range(4): fs.rock(Vector3(0.88 + (f - 1.5) * 0.11, 0.34, -0.24), Vector3(0.06, 0.08, 0.07), fp, {"lat": 4, "lon": 6, "lump": 0.2})
		else:
			fs.rock(Vector3(0.86 * side, 0.55, -0.03), Vector3(0.17, 0.15, 0.16), fp, {"lat": 5, "lon": 7, "lump": 0.25})
			for f in range(3): fs.rock(Vector3((0.86 + (f - 1) * 0.08) * side, 0.44, -0.14), Vector3(0.045, 0.07, 0.05), fp, {"lat": 4, "lon": 6, "lump": 0.2})
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.27 * side, 0.82, 0.08))
		var ts := Sculpt.new(); var tp := ts.add_painter(paint)
		ts.tube([Vector3(0.25 * side, 0.92, 0.08), Vector3(0.28 * side, 0.7, 0.08), Vector3(0.29 * side, 0.5, 0.08)], [0.23, 0.21, 0.18], tp, {"sides": 12, "per": 3, "lump": 0.15})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.29 * side, 0.48, 0.08))
		var ss := Sculpt.new(); var sp := ss.add_painter(paint)
		ss.tube([Vector3(0.29 * side, 0.52, 0.08), Vector3(0.3 * side, 0.26, 0.06), Vector3(0.3 * side, 0.14, 0.05)], [0.18, 0.17, 0.19], sp, {"sides": 12, "per": 3, "lump": 0.15})
		ss.rock(Vector3(0.3 * side, 0.08, -0.06), Vector3(0.21, 0.09, 0.28), sp, {"lat": 4, "lon": 7, "lump": 0.2})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": leaves}, 1.2)
	var visual := {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {"fronds": node.get_meta("rig_bindings").leaves}}
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = visual
	node.set_meta("rig_bindings", rig)
	return node


const CLASSIC_STONE := Color("#66737a")
const CLASSIC_PALE := Color("#8c989c")
const CLASSIC_DARK := Color("#46525a")
const LEAF_GLOW := Color("#9deccb")


## Grey-blue stone laid in courses: alternate courses paler, dark seams between them.
static func coursed(lichen: bool) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var course := int(floor(p.y * 5.3 + 0.35))
		var c := CLASSIC_STONE if course % 2 == 0 else CLASSIC_PALE
		c = c.lerp(c.lightened(0.08), clampf(Sculpt.fbm(p * 4.0) * 0.6, 0.0, 1.0)).darkened(clampf(-Sculpt.fbm(p * 9.0) * 0.12, 0.0, 0.1))
		c = c.lerp(CLASSIC_DARK, clampf(-n.y, 0.0, 1.0) * 0.35)
		# Cracks running through the stone.
		c = c.lerp(Color("#2b3236"), smoothstep(0.045, 0.0, absf(Sculpt.noise(p * Vector3(4.0, 7.0, 4.0) + Vector3(3, 0, 5)))) * 0.75)
		if lichen:
			c = c.lerp(LICHEN_GREEN, smoothstep(0.52, 0.6, Sculpt.noise(p * 8.0 + Vector3(9, 1, 3))) * 0.7)
			c = c.lerp(LICHEN_ORANGE, smoothstep(0.58, 0.65, Sculpt.noise(p * 10.0 + Vector3(2, 5, 1))) * 0.6)
			c = c.lerp(moss_color(p), smoothstep(0.7, 0.92, n.y + 0.3 * Sculpt.fbm(p * 4.0)))
		return c


## The original Cliffwarden's shape, done properly: a stack of stone courses for a body, the
## glowing leaf in its chest, a flat-capped head with a hollow face, a huge banded left arm
## and a smaller right one, and block feet.
func _classic(lichen: bool) -> Node3D:
	# Clean dressed stone like the original: no blotchy detail texture.
	material.albedo_texture = load("res://assets/cast/stone_detail_mid.png")
	material.uv1_scale = Vector3(3.6, 3.6, 3.6)
	material.roughness = 0.9
	var paint := coursed(lichen)
	var body := Sculpt.new(); var bp := body.add_painter(paint)
	var dark := body.add_painter(func (p, n, v, w): return Color("#1c2226"))
	body.tube([Vector3(-0.07, 0.6, 0.02), Vector3(-0.07, 0.86, 0.02), Vector3(-0.07, 1.14, 0.03), Vector3(-0.07, 1.4, 0.03), Vector3(-0.07, 1.56, 0.03)], [0.22, 0.25, 0.3, 0.31, 0.26], bp, {"sides": 16, "per": 6, "flat": 1.85, "square": 0.75, "bands": 5, "band": 0.07, "lump": 0.13, "cap_len": 0.4, "facet": true})
	# Chipped stones jutting from the edges of the courses.
	for chip in [Vector3(-0.6, 1.42, -0.12), Vector3(0.46, 1.36, -0.18), Vector3(-0.55, 0.98, 0.22), Vector3(0.42, 0.86, 0.2), Vector3(0.0, 1.5, 0.3), Vector3(-0.3, 0.72, -0.24)]:
		body.rock(chip, Vector3(0.1, 0.07, 0.09), bp, {"lat": 4, "lon": 6, "lump": 0.35, "basis": Basis.from_euler(chip * 3.0)})
	part(root, "Body", body)
	var cs := Sculpt.new(); var cw := cs.add_painter(func (p, n, v, w): return Color.WHITE)
	cs.blob(Vector3(-0.07, 1.22, -0.3), Vector3(0.075, 0.12, 0.03), cw, {"lat": 6, "lon": 10})
	cs.crystal(Vector3(-0.07, 1.1, -0.3), Vector3(0, -1, -0.1), 0.06, 0.012, cw, 4)
	glow.albedo_color = LEAF_GLOW.darkened(0.15); glow.emission = LEAF_GLOW
	glow.emission_energy_multiplier = 0.55
	var core := part(root, "GlowingLeaf", cs, glow)
	core.material_override = glow

	var head := joint(root, "Head", Vector3(0.06, 1.69, -0.03))
	var hs := Sculpt.new(); var hp := hs.add_painter(paint); var hd := hs.add_painter(func (p, n, v, w): return Color("#14191c"))
	hs.tube([Vector3(0.06, 1.52, -0.04), Vector3(0.06, 1.86, -0.04)], [0.17, 0.19], hp, {"sides": 14, "per": 3, "flat": 1.1, "square": 0.8, "cap_len": 0.3, "lump": 0.12, "facet": true})
	hs.blob(Vector3(0.06, 1.7, -0.175), Vector3(0.14, 0.11, 0.035), hd, {"lat": 6, "lon": 10})
	slab(hs, hp, Vector3(0.06, 1.83, -0.2), Vector3(0.38, 0.07, 0.12), Basis.IDENTITY, 0.4, 0.14, true)
	for side in [-1.0, 1.0]:
		slab(hs, hp, Vector3(0.06 + 0.19 * side, 1.66, -0.18), Vector3(0.08, 0.3, 0.1), Basis(Vector3.BACK, 0.08 * side), 0.4, 0.14, true)
	slab(hs, hp, Vector3(0.02, 1.95, -0.02), Vector3(0.6, 0.16, 0.46), Basis(Vector3.BACK, 0.1), 0.35, 0.16, true)
	part(head, "Head", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.06 + 0.06 * side, 1.72, -0.21), Vector3(0.026, 0.016, 0.01), ew, {"lat": 4, "lon": 8})
	var eye_glow := glow.duplicate()
	var eyes := part(head, "GlowingEyes", es, eye_glow); eyes.material_override = eye_glow

	var arms: Array = []; var forearms: Array = []; var leaves: Array = []
	for side in [-1.0, 1.0]:
		var big: bool = side < 0.0
		var w: float = 0.62 if big else 0.34
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.44 * side, 1.44, 0))
		var us := Sculpt.new(); var up := us.add_painter(paint)
		us.tube([Vector3((0.44 + w * 0.2) * side, 1.5, 0.0), Vector3((0.46 + w * 0.22) * side, 1.08, 0.01)], [w * 0.38, w * 0.36], up, {"sides": 14, "per": 6, "flat": 1.12, "square": 0.8, "bands": 2, "band": 0.06, "cap_len": 0.35, "lump": 0.12, "facet": true})
		slab(us, up, Vector3((0.46 + w * 0.2) * side, 1.58, 0.0), Vector3(w * 1.02, 0.16, w * 0.9), Basis(Vector3.BACK, 0.13 * side), 0.4, 0.16, true)
		part(shoulder, "UpperArm", us)
		if lichen: leaves.append(sprout(shoulder, label + "ShoulderGrass", Vector3((0.48 + w * 0.2) * side, 1.7, 0.05), Vector3(0.5 * side, 0, 0.2), 0.16 if big else 0.12, 4))
		var elbow := joint(shoulder, "Forearm", Vector3(0.54 * side, 1.04, -0.015))
		var fs := Sculpt.new(); var fp := fs.add_painter(paint)
		var fx: float = (0.46 + w * 0.24) * side
		fs.tube([Vector3(fx, 1.08, -0.02), Vector3(fx, 0.5, -0.04)], [w * 0.44, w * 0.48], fp, {"sides": 14, "per": 8, "flat": 1.1, "square": 0.8, "bands": 3, "band": 0.08, "cap_len": 0.3, "lump": 0.12, "facet": true})
		for f in range(4):
			slab(fs, fp, Vector3(fx + (f - 1.5) * w * 0.24, 0.4, -0.12), Vector3(w * 0.2, 0.26, w * 0.24), Basis.IDENTITY, 0.45, 0.14, true)
		part(elbow, "Forearm", fs)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.22 * side, 0.72, 0.025))
		var ts := Sculpt.new(); var tp := ts.add_painter(paint)
		ts.tube([Vector3(0.22 * side, 0.82, 0.02), Vector3(0.22 * side, 0.42, 0.01)], [0.17, 0.16], tp, {"sides": 14, "per": 4, "flat": 1.08, "square": 0.8, "bands": 2, "band": 0.06, "cap_len": 0.3, "lump": 0.12, "facet": true})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.22 * side, 0.38, 0.01))
		var ss := Sculpt.new(); var sp := ss.add_painter(paint)
		ss.tube([Vector3(0.22 * side, 0.44, 0.01), Vector3(0.22 * side, 0.14, 0.0)], [0.15, 0.15], sp, {"sides": 14, "per": 3, "flat": 1.08, "square": 0.8, "cap_len": 0.3, "lump": 0.12, "facet": true})
		slab(ss, sp, Vector3(0.22 * side, 0.07, -0.06), Vector3(0.36, 0.14, 0.5), Basis.IDENTITY, 0.4, 0.14, true)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": leaves}, 1.25)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {"fronds": rig.leaves}}
	node.set_meta("rig_bindings", rig)
	return node

