extends "res://tools/creature_kit.gd"
## EXPERIMENTAL (not in the game): the Treeline Lurker, a very tall, lanky, alien figure,
## black as a shadow, with tiny white eyes, a long swept-back skull and long limbs and
## fingers. It hides behind trees and slips out of sight when you look at it.
##   lurker       - the figure on its own (about 3 m tall, Mr. Justice is 1.22 m)
##   lurker_scale - the same with a grey 1.22 m stand-in for Mr. Justice beside it

const INK := Color("#0a0a0f")
const INK_SHEEN := Color("#272b3a")
const VOID := Color("#010102")


func _init() -> void:
	super("res://assets/cast/bark_detail_gray.png")
	material.uv1_scale = Vector3(1.5, 1.5, 1.5)
	material.roughness = 0.72
	material.metallic_specular = 0.55
	glow.albedo_color = Color("#e8eef5"); glow.emission = Color("#f4f8ff")
	glow.emission_energy_multiplier = 1.8


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "TreelineLurker"
	var node := _lurker()
	if variant == "lurker_scale":
		var ref := MeshInstance3D.new(); ref.name = "MrJusticeHeight"
		var cap := CapsuleMesh.new(); cap.radius = 0.22; cap.height = 1.22; ref.mesh = cap
		var m := StandardMaterial3D.new(); m.albedo_color = Color("#9aa4ad"); ref.material_override = m
		ref.position = Vector3(1.0, 0.61, -0.3)
		node.add_child(ref); ref.owner = node
	return node


## Skin like wet soot: almost black, with a faint cold blue sheen where the light catches it.
static func ink(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var grain := Sculpt.fbm(Vector3(p.x * 6.0, p.y * 2.0, p.z * 6.0))
	return INK.lerp(INK_SHEEN, clampf(n.y * 0.3 + grain * 0.45 + 0.05, 0.0, 1.0))


## A long jointed finger: segments of the given lengths, each bending further along `curl`.
func finger(s: Sculpt, painter: int, base: Vector3, dir: Vector3, curl: Vector3, lengths: Array, radius: float) -> void:
	var at := base; var d := dir.normalized()
	var pts: Array = [at]; var radii: Array = [radius]
	for k in range(lengths.size()):
		d = (d + curl * (0.35 + k * 0.2)).normalized()
		at += d * float(lengths[k])
		pts.append(at); radii.append(radius * (0.85 - k * 0.22))
		if k < lengths.size() - 1: s.blob(at, Vector3.ONE * radius * (1.15 - k * 0.2), painter, {"lat": 4, "lon": 6})
	radii[-1] = 0.002
	s.tube(pts, radii, painter, {"sides": 6, "per": 2, "cap_rings": 1, "cap1": false})


func _lurker() -> Node3D:
	# Torso: a narrow pelvis, a wasp-thin waist, a ribcage and a deep forward hunch, with a
	# ridge of vertebrae down its back.
	var body := Sculpt.new(); var bp := body.add_painter(ink)
	body.tube([Vector3(0, 1.6, 0.0), Vector3(0, 1.72, 0.01), Vector3(0, 1.92, 0.05), Vector3(0, 2.2, 0.03), Vector3(0, 2.42, -0.07), Vector3(0, 2.54, -0.18)], [0.1, 0.09, 0.06, 0.13, 0.14, 0.11], bp, {"sides": 12, "per": 3, "flat": 1.35, "lump": 0.04})
	for k in range(5):
		var y := 2.12 + k * 0.075
		var pts: Array = []; var radii: Array = []
		for j in range(9):
			var ang := PI * (0.15 + 0.7 * j / 8.0)
			pts.append(Vector3(cos(ang) * 0.17 * (1.0 - absf(k - 2.5) * 0.05), y - sin(ang) * 0.02, 0.02 - (y - 2.12) * 0.3 - sin(ang) * 0.115 * (1.0 - absf(k - 2.5) * 0.05)))
			radii.append(0.012)
		body.tube(pts, radii, bp, {"sides": 5, "per": 2, "cap_rings": 1})
	var spine := [[1.6, 0.0, 0.1], [1.72, 0.01, 0.09], [1.92, 0.05, 0.06], [2.2, 0.03, 0.13], [2.42, -0.07, 0.14], [2.54, -0.18, 0.11]]
	for k in range(12):
		var y := 1.7 + k * 0.07
		var i := 0
		while i < spine.size() - 2 and y > float(spine[i + 1][0]): i += 1
		var f := clampf((y - float(spine[i][0])) / (float(spine[i + 1][0]) - float(spine[i][0])), 0.0, 1.0)
		var z := lerpf(spine[i][1], spine[i + 1][1], f) + lerpf(spine[i][2], spine[i + 1][2], f) - 0.012
		body.blob(Vector3(0, y, z), Vector3(0.018, 0.02, 0.016), bp, {"lat": 4, "lon": 6})
	body.tube([Vector3(0, 2.53, -0.18), Vector3(0, 2.66, -0.31), Vector3(0, 2.8, -0.41)], [0.05, 0.04, 0.038], bp, {"sides": 9, "per": 3, "ridges": 6, "ridge": 0.12})
	for side in [-1.0, 1.0]:
		body.tube([Vector3(0.04 * side, 2.54, -0.17), Vector3(0.14 * side, 2.56, -0.17), Vector3(0.21 * side, 2.52, -0.16)], [0.045, 0.04, 0.045], bp, {"sides": 8, "per": 2})

	# A long, narrow skull swept far back, with large slanted black eye sockets holding tiny
	# white eyes, slit nostrils and a thin lipless mouth.
	var head := joint(root, "Head", Vector3(0, 2.75, -0.4))
	var hs := Sculpt.new(); var hp := hs.add_painter(ink)
	var void_paint := hs.add_painter(func (p, n, v, w): return VOID)
	hs.tube([Vector3(0, 2.71, -0.48), Vector3(0, 2.78, -0.48), Vector3(0, 2.88, -0.46), Vector3(0, 2.98, -0.43), Vector3(0, 3.07, -0.38), Vector3(0, 3.12, -0.33)], [0.026, 0.058, 0.074, 0.092, 0.097, 0.075], hp, {"sides": 16, "per": 3, "flat": 0.88, "side": Vector3.RIGHT, "cap_rings": 4, "cap_len": 0.8})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.009 * side, 2.79, -0.53), Vector3(0.003, 0.009, 0.004), void_paint, {"lat": 3, "lon": 5})
		es.blob(Vector3(0.028 * side, 2.878, -0.524), Vector3(0.0055, 0.0055, 0.003), white, {"lat": 4, "lon": 6})
	hs.blob(Vector3(0, 2.755, -0.528), Vector3(0.02, 0.0025, 0.005), void_paint, {"lat": 3, "lon": 7})
	part(head, "Head", hs)
	var core := part(head, "Eyes", es, glow); core.material_override = glow

	# Arms that hang to its knees, ending in narrow hands with three long curled fingers and
	# a thumb.
	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := Vector3(0.22 * side, 2.5, -0.16)
		var elbow := Vector3(0.31 * side, 1.82, -0.1)
		var wrist := Vector3(0.34 * side, 1.12, -0.2)
		var arm := joint(root, label + "Arm", shoulder)
		var us := Sculpt.new(); var up := us.add_painter(ink)
		us.tube([shoulder, shoulder.lerp(elbow, 0.5) + Vector3(0.01 * side, 0, 0), elbow], [0.045, 0.034, 0.032], up, {"sides": 8, "per": 3})
		us.blob(elbow, Vector3(0.036, 0.04, 0.036), up, {"lat": 5, "lon": 8})
		us.crystal(elbow + Vector3(0, 0.0, 0.02), Vector3(0.2 * side, 0.3, 1.0), 0.06, 0.012, up, 5)
		part(arm, "Upper", us)
		var fore := joint(arm, label + "Forearm", elbow)
		var fs := Sculpt.new(); var fp := fs.add_painter(ink)
		fs.tube([elbow, elbow.lerp(wrist, 0.5), wrist], [0.03, 0.024, 0.02], fp, {"sides": 8, "per": 3})
		var knuckles := wrist + Vector3(0.006 * side, -0.13, -0.02)
		fs.tube([wrist + Vector3(0, 0.01, 0), wrist + Vector3(0.004 * side, -0.065, -0.01), knuckles], [0.022, 0.034, 0.03], fp, {"sides": 8, "per": 2, "flat": 0.5, "side": Vector3.RIGHT, "cap_rings": 2})
		var inward := Vector3(-side, 0, 0)
		for f in range(3):
			var off := (f - 1) * 0.026
			finger(fs, fp, knuckles + Vector3(0, 0, off), Vector3(0.04 * side, -1.0, off * 4.5 - 0.06), inward * 0.55 + Vector3(0, 0, -0.25), [0.17 - absf(f - 1) * 0.02, 0.14, 0.12], 0.012)
		finger(fs, fp, wrist + Vector3(-0.006 * side, -0.07, -0.03), Vector3(-0.08 * side, -1.0, -0.3), inward * 0.45, [0.1, 0.08], 0.011)
		part(fore, "Forearm", fs)
		arms.append(arm); forearms.append(fore)

	# Long legs that bend backward like a hound's hind legs, on three long splayed toes.
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(0.1 * side, 1.62, 0.0)
		var knee_at := Vector3(0.12 * side, 1.02, -0.18)
		var hock := Vector3(0.12 * side, 0.42, 0.14)
		var ball := Vector3(0.12 * side, 0.05, -0.04)
		var hip := joint(root, label + "Leg", hip_at)
		var ts := Sculpt.new(); var tp := ts.add_painter(ink)
		ts.tube([hip_at + Vector3(0, 0.06, 0), hip_at.lerp(knee_at, 0.5), knee_at], [0.068, 0.05, 0.04], tp, {"sides": 8, "per": 3})
		ts.blob(knee_at, Vector3(0.042, 0.048, 0.045), tp, {"lat": 5, "lon": 8})
		part(hip, "Thigh", ts)
		var knee := joint(hip, label + "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(ink)
		ss.tube([knee_at, knee_at.lerp(hock, 0.5), hock], [0.038, 0.03, 0.028], sp, {"sides": 8, "per": 3})
		ss.blob(hock, Vector3(0.03, 0.034, 0.034), sp, {"lat": 4, "lon": 7})
		ss.tube([hock, hock.lerp(ball, 0.5), ball], [0.028, 0.024, 0.024], sp, {"sides": 8, "per": 2})
		for t in range(3):
			var spread := (t - 1) * 0.35
			var dir := Vector3(sin(spread) + side * 0.1, -0.12, -cos(spread))
			finger(ss, sp, ball, dir, Vector3(0, -0.25, 0), [0.08, 0.06, 0.04], 0.016)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.0)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
