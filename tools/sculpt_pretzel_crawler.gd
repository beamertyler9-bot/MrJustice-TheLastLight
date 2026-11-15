extends "res://tools/creature_kit.gd"
## The Pretzel Crawler of S'morewood, three takes. Glossy baked-brown dough, cracks showing
## pale crumb, coarse white salt, and mustard-yellow eyes.
## A: a scorpion whose back is a big pretzel knot and whose tail is a twisted pretzel rope.
## B: a spider whose body is an upright pretzel knot, like a wheel, on long pretzel-rod legs.
## C: a long centipede braided from two strands of dough, with hooked pretzel mandibles.

const CRUST := Color("#4e220a")
const CRUST_HI := Color("#83431a")
const CRUMB := Color("#e2b673")
const SALT := Color("#f6f3ec")
const MUSTARD := Color("#f2b81c")

var shiny: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	shiny = StandardMaterial3D.new()
	shiny.vertex_color_use_as_albedo = true
	shiny.vertex_color_is_srgb = true
	shiny.roughness = 0.38
	shiny.metallic_specular = 0.6
	glow.albedo_color = MUSTARD.darkened(0.2); glow.emission = MUSTARD
	glow.emission_energy_multiplier = 0.7


static func crust(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := CRUST.lerp(CRUST_HI, clampf(0.4 + n.y * 0.45 + Sculpt.fbm(p * 6.0) * 0.5, 0.0, 1.0))
	# Pale crumb showing through cracks in the crust.
	var crack := Sculpt.noise(p * 13.0)
	c = c.lerp(CRUMB, smoothstep(0.42, 0.55, crack) * 0.55)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.4)


## A pretzel stick: crust scored with a spiral line.
static func rod(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := CRUST.lerp(CRUST_HI, clampf(0.45 + n.y * 0.4, 0.0, 1.0))
	return c.darkened(smoothstep(0.85, 0.95, absf(sin((p.x + p.y + p.z) * 40.0))) * 0.3).darkened(clampf(-n.y, 0.0, 1.0) * 0.35)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "PretzelCrawler"
	match variant:
		"scorpion": return _scorpion()
		"wheel": return _wheel()
		"braid": return _braid()
	return null


func _with_visual(node: Node3D, head: Node3D, hips: Array, knees: Array, jaw: Node3D = null, tails: Array = [], pincers: Array = []) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {}
	if jaw != null: features[&"jaw"] = node.get_path_to(jaw)
	if not pincers.is_empty(): features[&"pincers"] = paths.call(pincers)
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tails), "features": features}
	node.set_meta("rig_bindings", rig)
	return node


## The classic pretzel knot in its own plane (x right, y up), `size` across: two ends cross
## at the twist and meet the big loop. `basis` places the plane; returns the path.
func knot_path(center: Vector3, size: float, basis: Basis) -> Array:
	# Starting with one arm resting on the lower left of the belly: up through the twist to the
	# upper right lobe, round the right side, along the fat belly, up the left side, round the
	# upper left lobe, back through the twist and down onto the belly's lower right.
	var flat := [Vector3(-0.4, -0.12, 0.03), Vector3(-0.2, 0.02, 0.05), Vector3(0.0, 0.16, 0.06), Vector3(0.18, 0.34, 0.04),
		Vector3(0.38, 0.47, 0), Vector3(0.6, 0.32, 0), Vector3(0.62, 0.0, 0), Vector3(0.44, -0.32, 0), Vector3(0.0, -0.46, 0),
		Vector3(-0.44, -0.32, 0), Vector3(-0.62, 0.0, 0), Vector3(-0.6, 0.32, 0), Vector3(-0.38, 0.47, 0), Vector3(-0.18, 0.34, -0.04),
		Vector3(0.0, 0.16, -0.06), Vector3(0.2, 0.02, -0.05), Vector3(0.4, -0.12, -0.03)]
	return flat.map(func (q): return center + basis * (q * size))


## A dough rope along `path`, glossy crust, with salt scattered on its upper side.
func dough(s: Sculpt, path: Array, radius: float, salt_count: int, salt_size: float, seed := 0) -> void:
	var cp := s.add_painter(crust); var sp := s.add_painter(func (p, n, v, w): return SALT.darkened(clampf(-n.y, 0.0, 1.0) * 0.2))
	var radii: Array = []
	for k in range(path.size()):
		var mid := 1.0 - absf(float(k) / maxf(path.size() - 1, 1) * 2.0 - 1.0)
		radii.append(radius * (0.72 + 0.45 * mid if path.size() > 12 else 0.9 + 0.15 * sin(k * 1.7 + seed)))
	s.tube(path, radii, cp, {"sides": 10, "per": 3, "lump": 0.12})
	salt(s, sp, path, radius, salt_count, salt_size, seed)


## Coarse salt crystals: little white cubes sitting on top of a rope.
func salt(s: Sculpt, painter: int, path: Array, radius: float, count: int, size: float, seed := 0) -> void:
	for k in range(count):
		var t := fposmod(k * 0.618 + seed * 0.37, 1.0) * (path.size() - 1)
		var i := mini(int(t), path.size() - 2)
		var at: Vector3 = (path[i] as Vector3).lerp(path[i + 1], t - i)
		var tangent: Vector3 = ((path[i + 1] as Vector3) - (path[i] as Vector3)).normalized()
		var side := tangent.cross(Vector3.UP).normalized() if absf(tangent.y) < 0.95 else Vector3.RIGHT
		var up := side.cross(tangent).normalized()
		if up.y < 0.0: up = -up
		var dir := (up + side * sin(k * 2.3) * 0.6).normalized()
		s.crystal(at + dir * radius * 0.8, dir, size * (1.1 + 0.6 * absf(sin(k * 1.3))), size * 0.8, painter, 4, k * 0.9)


## Pretzel-rod legs: up and out to a knee, then down to a blunt tip. `spots` are the hips.
func rod_legs(spots: Array, reach: float, rise: float, thick: float) -> Array:
	var hips: Array = []; var knees: Array = []
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var out := Vector3(at.x, 0, at.z * 0.35).normalized()
		var label := ("Foreleg%d" if k < 2 else "Hindleg%d") % k
		var hip := joint(root, label, at)
		var knee_at := at + out * reach * 0.45 + Vector3(0, rise, 0)
		var ts := Sculpt.new(); var tp := ts.add_painter(rod); var sp := ts.add_painter(func (p, n, v, w): return SALT)
		ts.tube([at, knee_at], [thick, thick * 0.9], tp, {"sides": 7, "per": 1, "cap_rings": 2})
		salt(ts, sp, [at, knee_at], thick, 2, thick * 0.7, k)
		part(hip, "Thigh", ts, shiny)
		var knee := joint(hip, "Knee", knee_at)
		var foot := Vector3(at.x + out.x * reach, 0.03, at.z + out.z * reach)
		var ss := Sculpt.new(); var spp := ss.add_painter(rod); var kp := ss.add_painter(crust)
		ss.tube([knee_at, foot], [thick * 0.9, thick * 0.75], spp, {"sides": 7, "per": 1, "cap_rings": 2})
		ss.blob(knee_at, Vector3.ONE * thick * 1.35, kp, {"lat": 5, "lon": 7, "lump": 0.2})
		part(knee, "Shin", ss, shiny)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


func _eyes(parent: Node3D, spots: Array, size: float) -> MeshInstance3D:
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for at in spots: es.blob(at, Vector3.ONE * size, ew, {"lat": 5, "lon": 8})
	var core := part(parent, "MustardEyes", es, glow); core.material_override = glow
	return core


# ----------------------------------------------------------------- A: scorpion

## A: a scorpion: a big pretzel knot lies across its back as the shell, two pretzel-loop claws
## reach forward, and its tail is a twisted two-strand pretzel rope curling up over it with a
## salted dough sting.
func _scorpion() -> Node3D:
	# The body: a salted dough head-plate and a segmented dough tail-end under the knot.
	var bs := Sculpt.new()
	var cp := bs.add_painter(crust); var sp := bs.add_painter(func (p, n, v, w): return SALT.darkened(clampf(-n.y, 0.0, 1.0) * 0.2))
	bs.blob(Vector3(0, 0.28, -0.12), Vector3(0.25, 0.13, 0.24), cp, {"lat": 7, "lon": 12, "lump": 0.12})
	for k in range(4):
		var z := 0.1 + k * 0.12
		bs.blob(Vector3(0, 0.39 - k * 0.015, z), Vector3(0.24 - k * 0.03, 0.12 - k * 0.01, 0.09), cp, {"lat": 6, "lon": 12, "lump": 0.1})
	# The pretzel shell: a big, thick salted knot domed over the back.
	dough(bs, knot_path(Vector3(0, 0.43, 0.08), 0.62, Basis(Vector3.RIGHT, -PI * 0.5 + 0.12) * Basis(Vector3.FORWARD, PI)), 0.085, 22, 0.032)
	part(root, "Shell", bs, shiny)
	# The tail: one continuous two-strand pretzel twist arching up over the back, cut into
	# segments that swing, ending in a dough bulb and a dark baked sting.
	var spine := [Vector3(0, 0.26, 0.52), Vector3(0, 0.38, 0.74), Vector3(0, 0.6, 0.86), Vector3(0, 0.84, 0.84), Vector3(0, 1, 0.68), Vector3(0, 1.04, 0.48)]
	var tails: Array = []
	var parent: Node3D = root
	var twist_at := 0.0
	for seg in range(spine.size() - 1):
		var a: Vector3 = spine[seg]; var b: Vector3 = spine[seg + 1]
		var node := joint(parent, "Tail%d" % seg, a)
		var ts := Sculpt.new(); var tcp := ts.add_painter(crust); var tsp := ts.add_painter(func (p, n, v, w): return SALT)
		var axis := (b - a).normalized(); var side := axis.cross(Vector3.RIGHT).normalized()
		var r0 := lerpf(0.085, 0.045, float(seg) / (spine.size() - 1))
		var r1 := lerpf(0.085, 0.045, float(seg + 1) / (spine.size() - 1))
		for strand in [0.0, PI]:
			var path: Array = []; var radii: Array = []
			for i in range(6):
				var t := i / 5.0
				var r := lerpf(r0, r1, t)
				var ang: float = strand + twist_at + t * PI * 1.1
				path.append(a.lerp(b, t) + (Vector3.RIGHT * cos(ang) + side * sin(ang)) * r * 0.62)
				radii.append(r * 0.62)
			ts.tube(path, radii, tcp, {"sides": 9, "per": 2, "lump": 0.08})
			salt(ts, tsp, path, r0 * 0.6, 2, 0.026, seg + int(strand))
		twist_at += PI * 1.1
		if seg == spine.size() - 2:
			var stinger := ts.add_painter(func (p, n, v, w): return Color("#2a1206").lerp(CRUMB, v * 0.3))
			ts.blob(b + Vector3(0, -0.02, -0.04), Vector3(0.085, 0.075, 0.11), tcp, {"lat": 6, "lon": 9, "lump": 0.15})
			ts.tube([b + Vector3(0, -0.05, -0.12), b + Vector3(0, -0.13, -0.2), b + Vector3(0, -0.22, -0.18)], [0.03, 0.02, 0.002], stinger, {"sides": 7, "per": 3, "cap0": false})
		part(node, "Twist", ts, shiny)
		tails.append(node)
		parent = node
	# The head: dough brow, mandibles, mustard eyes, and big dough pincers on pretzel-stick arms.
	var head := joint(root, "Head", Vector3(0, 0.28, -0.3))
	var hs := Sculpt.new(); var hc := hs.add_painter(crust); var hrod := hs.add_painter(rod)
	var hsalt := hs.add_painter(func (p, n, v, w): return SALT)
	hs.blob(Vector3(0, 0.3, -0.34), Vector3(0.19, 0.1, 0.14), hc, {"lat": 6, "lon": 10, "lump": 0.12})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.05 * side, 0.24, -0.44), Vector3(0.08 * side, 0.22, -0.52), Vector3(0.03 * side, 0.21, -0.56)], [0.025, 0.02, 0.004], hc, {"sides": 7, "per": 3, "cap0": false})
		# Arm: two pretzel-stick segments with a dough knuckle between.
		var shoulder := Vector3(0.17 * side, 0.28, -0.36); var elbow := Vector3(0.42 * side, 0.33, -0.46); var wrist := Vector3(0.46 * side, 0.3, -0.7)
		hs.tube([shoulder, elbow], [0.04, 0.036], hrod, {"sides": 8, "per": 1, "cap_rings": 2})
		hs.tube([elbow, wrist], [0.036, 0.034], hrod, {"sides": 8, "per": 1, "cap_rings": 2})
		hs.blob(elbow, Vector3.ONE * 0.05, hc, {"lat": 5, "lon": 8, "lump": 0.2})
	part(head, "Head", hs, shiny)
	# Pincers: each claw is a whole pretzel lying flat, split down the middle into two halves
	# hinged at the wrist, so it opens like a pair of jaws.
	var pincers: Array = []
	for side in [-1.0, 1.0]:
		var wrist := Vector3(0.46 * side, 0.3, -0.7)
		var size := 0.42
		var center := wrist + Vector3(0, 0, -0.46 * size)
		for half in [-1.0, 1.0]:
			var label := "%sPincer%s" % ["Left" if side < 0 else "Right", "In" if half * side < 0 else "Out"]
			var hinge := joint(head, label, wrist + Vector3(0.02 * half, 0, 0))
			var ps := Sculpt.new()
			# The outline of one half: from the top middle round the lobe, down the side and
			# along the belly to the bottom middle, plus its inner arm resting on the belly.
			var rim := [Vector3(0.0, 0.3, 0), Vector3(0.18, 0.44, 0), Vector3(0.38, 0.47, 0), Vector3(0.6, 0.32, 0), Vector3(0.62, 0.0, 0), Vector3(0.44, -0.32, 0), Vector3(0.06, -0.46, 0)]
			var arm := [Vector3(0.03, 0.16, 0), Vector3(0.2, 0.02, 0), Vector3(0.4, -0.12, 0)]
			var to_world := func (q: Vector3) -> Vector3: return center + Vector3(q.x * half, 0.0, -q.y) * size
			dough(ps, rim.map(to_world), 0.042, 5, 0.024, int(side * 3 + half))
			dough(ps, arm.map(to_world), 0.034, 2, 0.02, int(side * 5 + half))
			part(hinge, "Half", ps, shiny)
			pincers.append(hinge)
	var core := _eyes(head, [Vector3(-0.06, 0.38, -0.44), Vector3(0.06, 0.38, -0.44), Vector3(-0.12, 0.36, -0.41), Vector3(0.12, 0.36, -0.41)], 0.026)
	var spots: Array = []
	for k in range(4):
		for side in [-1.0, 1.0]: spots.append(Vector3(0.2 * side, 0.26, -0.1 + k * 0.14))
	var legs := rod_legs(spots, 0.72, 0.26, 0.034)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.2)
	return _with_visual(node, head, legs[0], legs[1], null, tails, pincers)


# ------------------------------------------------------------------- B: wheel

## B: a spider whose body is one big pretzel knot standing on edge, like a wheel. Its eyes
## glow in the knot's heart, a little dough head sits at the front with hooked fangs, and it
## stalks on six long pretzel rods.
func _wheel() -> Node3D:
	var head := joint(root, "Head", Vector3(0, 0.95, -0.05))
	var bs := Sculpt.new()
	dough(bs, knot_path(Vector3(0, 0.98, 0.12), 0.95, Basis(Vector3.UP, PI * 0.5)), 0.1, 26, 0.035)
	var hub := bs.add_painter(crust)
	bs.blob(Vector3(0, 0.82, 0.1), Vector3(0.14, 0.14, 0.18), hub, {"lat": 6, "lon": 9, "lump": 0.15})
	bs.blob(Vector3(0, 0.78, -0.24), Vector3(0.15, 0.12, 0.13), hub, {"lat": 6, "lon": 9, "lump": 0.15})
	var fang := bs.add_painter(func (p, n, v, w): return CRUMB.lerp(SALT, v))
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.06 * side, 0.72, -0.34), Vector3(0.08 * side, 0.62, -0.4), Vector3(0.04 * side, 0.55, -0.36)], [0.025, 0.018, 0.003], fang, {"sides": 6, "per": 3, "cap0": false})
	part(head, "Knot", bs, shiny)
	var core := _eyes(head, [Vector3(-0.06, 0.84, -0.36), Vector3(0.06, 0.84, -0.36), Vector3(-0.11, 0.8, -0.33), Vector3(0.11, 0.8, -0.33), Vector3(0, 1.0, 0.1)], 0.028)
	var legs := rod_legs([Vector3(-0.12, 0.8, -0.18), Vector3(0.12, 0.8, -0.18), Vector3(-0.14, 0.78, 0.08), Vector3(0.14, 0.78, 0.08), Vector3(-0.12, 0.78, 0.32), Vector3(0.12, 0.78, 0.32)], 1.15, 0.35, 0.032)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.1)
	return _with_visual(node, head, legs[0], legs[1])


# ------------------------------------------------------------------- C: braid

## C: a long, low centipede braided from two strands of dough, salted along the back, with a
## knobbly head, hooked pretzel-loop mandibles that snap, and stubby pretzel-stick legs.
func _braid() -> Node3D:
	var bs := Sculpt.new()
	var spine: Array = []
	for i in range(9): spine.append(Vector3(sin(i * 0.7) * 0.06, 0.32 + 0.03 * sin(i * 1.1), -0.25 + i * 0.17))
	for strand in [0.0, PI]:
		var path: Array = []
		for i in range(spine.size() * 2 - 1):
			var t := i / 2.0
			var k := mini(int(t), spine.size() - 2)
			var at: Vector3 = (spine[k] as Vector3).lerp(spine[k + 1], t - k)
			var ang: float = strand + t * PI * 0.9
			path.append(at + Vector3(cos(ang) * 0.11, sin(ang) * 0.08, 0))
		var r: Array = []
		for i in range(path.size()): r.append(lerpf(0.12, 0.06, float(i) / path.size()))
		var cp := bs.add_painter(crust)
		bs.tube(path, r, cp, {"sides": 10, "per": 2, "lump": 0.12})
	var sp := bs.add_painter(func (p, n, v, w): return SALT)
	salt(bs, sp, spine.map(func (q): return q + Vector3(0, 0.1, 0)), 0.08, 22, 0.035, 2)
	part(root, "Braid", bs, shiny)
	var head := joint(root, "Head", Vector3(0, 0.36, -0.33))
	var hs := Sculpt.new(); var hc := hs.add_painter(crust)
	hs.blob(Vector3(0, 0.38, -0.42), Vector3(0.17, 0.13, 0.15), hc, {"lat": 7, "lon": 10, "lump": 0.18})
	var hsp := hs.add_painter(func (p, n, v, w): return SALT)
	salt(hs, hsp, [Vector3(-0.1, 0.48, -0.4), Vector3(0.1, 0.48, -0.42)], 0.03, 5, 0.03, 4)
	part(head, "Head", hs, shiny)
	var jaw := joint(head, "Mandibles", Vector3(0, 0.33, -0.48))
	var js := Sculpt.new()
	for side in [-1.0, 1.0]:
		dough(js, [Vector3(0.1 * side, 0.32, -0.5), Vector3(0.2 * side, 0.32, -0.62), Vector3(0.14 * side, 0.32, -0.76), Vector3(0.03 * side, 0.32, -0.74)], 0.03, 3, 0.016, int(side))
	part(jaw, "Mandibles", js, shiny)
	var core := _eyes(head, [Vector3(-0.08, 0.45, -0.54), Vector3(0.08, 0.45, -0.54)], 0.03)
	var spots: Array = []
	for k in range(6):
		var side := -1.0 if k % 2 == 0 else 1.0
		spots.append(Vector3(0.12 * side, 0.3, -0.12 + int(k / 2) * 0.42))
	var legs := rod_legs(spots, 0.5, 0.12, 0.028)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.25)
	return _with_visual(node, head, legs[0], legs[1], jaw)
