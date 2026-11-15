extends "res://tools/creature_kit.gd"
## EXPERIMENTAL (not in the game): the Treeline Lurker, a very tall, lanky figure, black as
## a shadow, with tiny white eyes and long limbs and fingers. It hides behind trees and slips
## out of sight when you look at it.
##   lurker       - the figure on its own (about 3.2 m tall, Mr. Justice is 1.22 m)
##   lurker_scale - the same with a grey 1.22 m stand-in for Mr. Justice beside it

const INK := Color("#0b0b0e")
const INK_SHEEN := Color("#23232b")


func _init() -> void:
	super("res://assets/cast/bark_detail_gray.png")
	material.uv1_scale = Vector3(1.5, 1.5, 1.5)
	material.roughness = 0.8
	glow.albedo_color = Color("#e8eef5"); glow.emission = Color("#f4f8ff")
	glow.emission_energy_multiplier = 1.6


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


## Skin like soot: almost black, with a faint cold sheen where the light catches it.
static func ink(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var grain := Sculpt.fbm(Vector3(p.x * 6.0, p.y * 2.0, p.z * 6.0))
	return INK.lerp(INK_SHEEN, clampf(n.y * 0.35 + grain * 0.45, 0.0, 1.0))


func _lurker() -> Node3D:
	# Torso: a narrow pelvis, a thin waist and a slight forward hunch at the shoulders, with
	# ribs showing through.
	var body := Sculpt.new(); var bp := body.add_painter(ink)
	body.tube([Vector3(0, 1.6, 0.0), Vector3(0, 1.72, 0.01), Vector3(0, 1.92, 0.05), Vector3(0, 2.2, 0.03), Vector3(0, 2.42, -0.07), Vector3(0, 2.54, -0.18)], [0.11, 0.1, 0.075, 0.13, 0.14, 0.11], bp, {"sides": 12, "per": 3, "flat": 1.35, "cap0": true, "lump": 0.04})
	for k in range(5):
		var y := 2.12 + k * 0.075
		var pts: Array = []; var radii: Array = []
		for j in range(9):
			var ang := PI * (0.15 + 0.7 * j / 8.0)
			pts.append(Vector3(cos(ang) * 0.17 * (1.0 - absf(k - 2.5) * 0.05), y - sin(ang) * 0.02, 0.02 - (y - 2.12) * 0.3 - sin(ang) * 0.115 * (1.0 - absf(k - 2.5) * 0.05)))
			radii.append(0.012)
		body.tube(pts, radii, bp, {"sides": 5, "per": 2, "cap_rings": 1})
	body.tube([Vector3(0, 2.53, -0.18), Vector3(0, 2.64, -0.3), Vector3(0, 2.74, -0.39)], [0.05, 0.042, 0.04], bp, {"sides": 9, "per": 3})
	# Thin bony shoulders.
	for side in [-1.0, 1.0]:
		body.tube([Vector3(0.04 * side, 2.54, -0.17), Vector3(0.14 * side, 2.55, -0.17), Vector3(0.21 * side, 2.51, -0.16)], [0.045, 0.04, 0.045], bp, {"sides": 8, "per": 2})

	# A long, narrow skull with no mouth, tapering to a pointed chin.
	var head := joint(root, "Head", Vector3(0, 2.75, -0.4))
	var hs := Sculpt.new(); var hp := hs.add_painter(ink)
	hs.tube([Vector3(0, 2.74, -0.47), Vector3(0, 2.8, -0.46), Vector3(0, 2.9, -0.43), Vector3(0, 2.99, -0.4)], [0.035, 0.072, 0.085, 0.072], hp, {"sides": 14, "per": 3, "flat": 0.9, "side": Vector3.RIGHT, "cap_rings": 3})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.03 * side, 2.885, -0.505), Vector3(0.02, 0.014, 0.01), hs.add_painter(func (p, n, v, w): return Color("#020203")), {"lat": 4, "lon": 7})
		es.blob(Vector3(0.03 * side, 2.885, -0.514), Vector3(0.0075, 0.0075, 0.005), white, {"lat": 4, "lon": 6})
	part(head, "Head", hs)
	var core := part(head, "Eyes", es, glow); core.material_override = glow

	# Arms that hang to its knees, ending in long jointed fingers.
	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := Vector3(0.22 * side, 2.5, -0.16)
		var elbow := Vector3(0.3 * side, 1.82, -0.12)
		var wrist := Vector3(0.33 * side, 1.12, -0.22)
		var arm := joint(root, label + "Arm", shoulder)
		var us := Sculpt.new(); var up := us.add_painter(ink)
		us.tube([shoulder, shoulder.lerp(elbow, 0.5) + Vector3(0.01 * side, 0, 0), elbow], [0.045, 0.036, 0.034], up, {"sides": 8, "per": 3})
		us.blob(elbow, Vector3(0.038, 0.04, 0.038), up, {"lat": 5, "lon": 8})
		part(arm, "Upper", us)
		var fore := joint(arm, label + "Forearm", elbow)
		var fs := Sculpt.new(); var fp := fs.add_painter(ink)
		fs.tube([elbow, elbow.lerp(wrist, 0.5), wrist], [0.032, 0.026, 0.022], fp, {"sides": 8, "per": 3})
		var palm := wrist + Vector3(0.005 * side, -0.07, -0.01)
		fs.blob(palm, Vector3(0.028, 0.065, 0.045), fp, {"lat": 5, "lon": 8})
		for f in range(5):
			var thumb := f == 4
			var spread := (f - 1.5) * 0.03 if not thumb else 0.0
			var root_at := palm + Vector3(0.0, -0.05, -0.03 + spread) if not thumb else palm + Vector3(-0.012 * side, -0.01, -0.05)
			var length := (0.46 - absf(f - 1.5) * 0.05) if not thumb else 0.26
			var dir := Vector3(0.05 * side, -1.0, -0.12 + spread * 1.6).normalized() if not thumb else Vector3(-0.2 * side, -0.7, -0.7).normalized()
			var k1 := root_at + dir * length * 0.42
			var k2 := k1 + (dir + Vector3(0, 0.15, -0.28)).normalized() * length * 0.33
			var tip := k2 + (dir + Vector3(0, 0.35, -0.6)).normalized() * length * 0.25
			fs.tube([root_at, k1, k2, tip], [0.011, 0.009, 0.007, 0.002], fp, {"sides": 6, "per": 2, "cap_rings": 1})
			fs.blob(k1, Vector3(0.011, 0.012, 0.011), fp, {"lat": 4, "lon": 6})
			fs.blob(k2, Vector3(0.009, 0.01, 0.009), fp, {"lat": 4, "lon": 6})
		part(fore, "Forearm", fs)
		arms.append(arm); forearms.append(fore)

	# Long thin legs with a backward knee bend and narrow pointed feet.
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(0.1 * side, 1.62, 0.0)
		var knee_at := Vector3(0.12 * side, 0.86, -0.07)
		var ankle := Vector3(0.12 * side, 0.08, 0.03)
		var hip := joint(root, label + "Leg", hip_at)
		var ts := Sculpt.new(); var tp := ts.add_painter(ink)
		ts.tube([hip_at + Vector3(0, 0.06, 0), hip_at.lerp(knee_at, 0.5), knee_at], [0.07, 0.05, 0.042], tp, {"sides": 8, "per": 3})
		ts.blob(knee_at, Vector3(0.045, 0.05, 0.045), tp, {"lat": 5, "lon": 8})
		part(hip, "Thigh", ts)
		var knee := joint(hip, label + "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(ink)
		ss.tube([knee_at, knee_at.lerp(ankle, 0.5) + Vector3(0, 0, 0.02), ankle], [0.04, 0.03, 0.026], sp, {"sides": 8, "per": 3})
		ss.tube([ankle + Vector3(0, 0.0, 0.04), ankle + Vector3(0, -0.05, -0.08), ankle + Vector3(0, -0.07, -0.26)], [0.035, 0.03, 0.006], sp, {"sides": 8, "per": 2, "flat": 1.3})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.0)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
