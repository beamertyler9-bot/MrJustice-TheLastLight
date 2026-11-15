extends "res://tools/creature_kit.gd"
## The Stonejaw Wyrm, Mosswake Valley's boss, sculpted by hand: the original's long burrowing
## wyrm with its horned head and great underbite, done properly. Massive layered cliff-stone
## scales run down its back like shingles; it surfaces in a spill of stones and charges.

const HIDE := Color("#6f7d6c")
const HIDE_DARK := Color("#3c463b")
const BELLY := Color("#a9ad90")
const PLATE := Color("#8e8a7c")
const PLATE_LIGHT := Color("#b1ab98")
const PLATE_DARK := Color("#4f4b42")
const HORN := Color("#e4cf9c")
const EYE := Color("#ffb347")

const TAIL_START := Vector3(0, 0.42, 0.53)
const TAIL_STEP := Vector3(0, -0.025, 0.33)
const TAIL_SEGMENTS := 7


func _init() -> void:
	super("res://assets/cast/stone_detail_mid.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	material.vertex_color_is_srgb = true
	glow.albedo_color = EYE.darkened(0.2); glow.emission = EYE
	glow.emission_energy_multiplier = 1.0


## Thick stony hide: darker on top, pale ridged belly scutes underneath, moss in the creases.
static func hide(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := HIDE.lerp(HIDE_DARK, clampf(n.y * 0.6 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
	var belly := smoothstep(-0.2, -0.6, n.y)
	var scute := 0.85 + 0.15 * sin(p.z * 38.0)
	c = c.lerp(BELLY * scute, belly)
	return c.lerp(moss_color(p), smoothstep(0.5, 0.62, Sculpt.noise(p * 6.0 + Vector3(3, 8, 1))) * smoothstep(0.2, 0.6, n.y) * 0.8)


## Cliff-stone plates: layered stone with darker edges and a little lichen.
static func plate(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var level := p.y * 14.0 + Sculpt.noise(p * 3.0) * 0.8
	var c := PLATE.lerp(PLATE_LIGHT, clampf(0.5 + sin(level) * 0.35 + Sculpt.fbm(p * 7.0) * 0.4, 0.0, 1.0))
	c = c.lerp(PLATE_DARK, clampf(-n.y, 0.0, 1.0) * 0.6)
	c = c.lerp(Color("#c4bd76"), smoothstep(0.55, 0.65, Sculpt.noise(p * 12.0 + Vector3(5, 1, 2))) * 0.6)
	return c.lerp(moss_color(p), smoothstep(0.62, 0.72, Sculpt.noise(p * 5.0 + Vector3(1, 9, 4))) * smoothstep(0.4, 0.8, n.y) * 0.85)


static func horn(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return HORN.darkened((1.0 - v) * 0.3)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "StonejawWyrm"
	match variant:
		"classic": return _wyrm(false)
		"mossy": return _wyrm(true)
	return null


## Shingled stone plates along a stretch of back from a to b, sized to the body's radius.
func _plates(s: Sculpt, painter: int, a: Vector3, b: Vector3, radius: float, count: int) -> void:
	for k in range(count):
		var t := (k + 0.5) / count
		var at := a.lerp(b, t)
		var size := radius * (1.0 - 0.15 * t)
		s.rock(at + Vector3(0, radius * 0.88, 0), Vector3(size * 1.15, size * 0.32, size * 0.75), painter, {"lat": 4, "lon": 7, "lump": 0.25, "basis": Basis(Vector3.RIGHT, -0.3)})
		for side in [-1.0, 1.0]:
			s.rock(at + Vector3(side * radius * 0.82, radius * 0.45, 0.02), Vector3(size * 0.45, size * 0.3, size * 0.55), painter, {"lat": 4, "lon": 6, "lump": 0.25, "basis": Basis(Vector3.BACK, side * 0.7) * Basis(Vector3.RIGHT, -0.2)})


func _wyrm(mossy: bool) -> Node3D:
	var body := Sculpt.new(); var hp := body.add_painter(hide); var pp := body.add_painter(plate)
	body.tube([Vector3(0, 0.7, -0.62), Vector3(0, 0.62, -0.3), Vector3(0, 0.52, 0.15), Vector3(0, 0.45, 0.6)], [0.3, 0.36, 0.36, 0.32], hp, {"sides": 16, "per": 3, "flat": 1.15, "lump": 0.08})
	_plates(body, pp, Vector3(0, 0.64, -0.4), Vector3(0, 0.47, 0.5), 0.35, 4)
	if mossy:
		for spot in [Vector3(-0.12, 0.98, -0.1), Vector3(0.15, 0.95, 0.3)]:
			moss_clump(body, body.add_painter(moss), spot, 0.12, 4)
	part(root, "BeastBody", body)

	# The tail: a chain of segments the game swings, each with its own shingled plates.
	var tail_nodes: Array = []
	var parent: Node3D = root
	var at := TAIL_START
	for k in range(TAIL_SEGMENTS):
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var r0: float = lerpf(0.31, 0.07, float(k) / TAIL_SEGMENTS)
		var r1: float = lerpf(0.31, 0.07, float(k + 1) / TAIL_SEGMENTS)
		var ts := Sculpt.new(); var tp := ts.add_painter(hide); var tpp := ts.add_painter(plate)
		var next := at + TAIL_STEP
		ts.tube([at - TAIL_STEP * 0.15, at.lerp(next, 0.5), next + TAIL_STEP * 0.12], [r0 * 1.02, (r0 + r1) * 0.5, r1], tp, {"sides": 14, "per": 2, "flat": 1.15, "lump": 0.08})
		_plates(ts, tpp, at, next, (r0 + r1) * 0.5, 1)
		if k == TAIL_SEGMENTS - 1:
			# A club of stone at the tip of the tail.
			ts.rock(next + TAIL_STEP * 0.35, Vector3(0.16, 0.13, 0.2), tpp, {"lat": 5, "lon": 7, "lump": 0.3})
			for side in [-1.0, 1.0]: ts.crystal(next + TAIL_STEP * 0.35 + Vector3(side * 0.1, 0.05, 0), Vector3(side, 0.5, 0.4), 0.14, 0.03, ts.add_painter(horn), 5)
		part(node, "Segment", ts)
		tail_nodes.append(node)
		parent = node; at = next

	# The head: a heavy stone skull with a brow of plates, curving bone horns, glowing eyes and
	# the great underbiting stone jaw full of teeth.
	var head := joint(root, "Head", Vector3(0, 0.54, -0.65))
	var hs := Sculpt.new(); var hhp := hs.add_painter(hide); var hpp := hs.add_painter(plate); var hn := hs.add_painter(horn)
	var mouth := hs.add_painter(func (p, n, v, w): return Color("#3a1d18"))
	# A wide, flat wedge of a skull tapering to the snout.
	hs.tube([Vector3(0, 0.8, -0.52), Vector3(0, 0.79, -0.78), Vector3(0, 0.75, -1.0), Vector3(0, 0.71, -1.16)], [0.24, 0.22, 0.17, 0.12], hhp, {"sides": 14, "per": 3, "flat": 1.5, "square": 0.55, "cap_len": 0.5, "lump": 0.07})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.06 * side, 0.76, -1.24), Vector3(0.025, 0.02, 0.012), mouth, {"lat": 4, "lon": 6})
	# The stone underbite jaw, jutting past the snout.
	hs.tube([Vector3(0, 0.55, -0.56), Vector3(0, 0.52, -0.9), Vector3(0, 0.53, -1.22)], [0.17, 0.15, 0.13], hpp, {"sides": 14, "per": 3, "flat": 1.65, "square": 0.75, "cap_len": 0.35, "lump": 0.12, "facet": true})
	hs.blob(Vector3(0, 0.62, -0.92), Vector3(0.27, 0.035, 0.25), mouth, {"lat": 5, "lon": 10})
	for side in [-1.0, 1.0]:
		# Heavy brow ridge over each eye, and the horns sweeping up and back behind it.
		hs.rock(Vector3(0.24 * side, 0.98, -0.8), Vector3(0.15, 0.06, 0.13), hpp, {"lat": 4, "lon": 6, "lump": 0.2, "basis": Basis(Vector3.BACK, 0.45 * side) * Basis(Vector3.RIGHT, 0.2)})
		for k in range(3):
			var base := Vector3(0.24 * side, 0.95 - k * 0.06, -0.64 + k * 0.1)
			hs.tube([base, base + Vector3(0.06 * side, 0.18 - k * 0.03, 0.06), base + Vector3(0.1 * side, 0.36 - k * 0.07, 0.18)], [0.05 - k * 0.008, 0.035, 0.004], hn, {"sides": 7, "per": 3, "cap1": false})
		# Teeth: upper ones hanging over the jaw, lower ones jutting up from the underbite.
		for k in range(4):
			hs.crystal(Vector3((0.26 - k * 0.04) * side, 0.66, -0.8 - k * 0.11), Vector3(0, -1.0, -0.1), 0.07, 0.018, hn, 5)
			hs.crystal(Vector3((0.28 - k * 0.04) * side, 0.6, -0.86 - k * 0.11), Vector3(0.1 * side, 1.0, -0.1), 0.09 + 0.02 * (k % 2), 0.022, hn, 5)
		hs.crystal(Vector3(0.13 * side, 0.6, -1.25), Vector3(0.05 * side, 1.0, -0.25), 0.13, 0.028, hn, 5)
	part(head, "Head", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.315 * side, 0.88, -0.8), Vector3(0.035, 0.03, 0.04), ew, {"lat": 4, "lon": 8})
	var core := part(head, "GlowingEyes", es, glow)
	core.material_override = glow

	# Four sprawling lizard legs: the upper leg reaches out sideways to the elbow, the lower leg
	# plants down to a broad clawed foot. Front pair under the shoulders, hind pair at the hips.
	var feet: Array = []; var knees: Array = []
	for row in [["Front", -0.32, 0.52], ["Hind", 0.42, 0.44]]:
		for side in [-1.0, 1.0]:
			var label: String = row[0] + ("Left" if side < 0 else "Right")
			var z: float = row[1]; var y: float = row[2]
			var hip_at := Vector3(0.3 * side, y, z)
			var elbow_at := Vector3(0.64 * side, y - 0.02, z + 0.02)
			var foot_at := Vector3(0.72 * side, 0.05, z - 0.06)
			var hip := joint(root, label + "Leg", hip_at)
			var us := Sculpt.new(); var up := us.add_painter(hide); var upp := us.add_painter(plate)
			us.tube([hip_at - Vector3(0.08 * side, 0, 0), hip_at.lerp(elbow_at, 0.5) + Vector3(0, 0.04, 0), elbow_at], [0.17, 0.15, 0.12], up, {"sides": 11, "per": 3, "lump": 0.08, "side": Vector3.UP})
			us.rock(hip_at.lerp(elbow_at, 0.45) + Vector3(0, 0.1, 0), Vector3(0.11, 0.04, 0.09), upp, {"lat": 4, "lon": 6, "lump": 0.25, "basis": Basis(Vector3.BACK, 0.3 * side)})
			part(hip, "UpperLeg", us)
			var knee := joint(hip, "Elbow" if row[0] == "Front" else "Knee", elbow_at)
			var ls := Sculpt.new(); var lp := ls.add_painter(hide); var cl := ls.add_painter(horn)
			ls.tube([elbow_at + Vector3(0, 0.03, 0), elbow_at.lerp(foot_at, 0.5) + Vector3(0.03 * side, 0, 0), foot_at + Vector3(0, 0.05, 0)], [0.125, 0.105, 0.095], lp, {"sides": 11, "per": 3, "lump": 0.08})
			ls.blob(foot_at + Vector3(0, 0.0, -0.04), Vector3(0.14, 0.055, 0.15), lp, {"lat": 6, "lon": 10, "lump": 0.1})
			for t in range(4):
				var ang := -0.9 + t * 0.55
				var dir := Vector3(sin(ang) * side, 0, -cos(ang))
				var toe := foot_at + Vector3(0, 0.01, -0.04) + dir * 0.08
				ls.tube([toe, toe + dir * 0.1 + Vector3(0, -0.015, 0)], [0.04, 0.03], lp, {"sides": 6, "per": 2, "cap_rings": 1})
				ls.crystal(toe + dir * 0.11 + Vector3(0, -0.01, 0), dir + Vector3(0, -0.4, 0), 0.08, 0.016, cl, 5)
			part(knee, "LowerLeg", ls)
			feet.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": feet, "knees": knees, "leaves": tail_nodes}, 1.7)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": rig.leaves, "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
