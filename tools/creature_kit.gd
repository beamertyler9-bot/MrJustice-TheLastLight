extends RefCounted
## Shared kit for hand-sculpted creatures (see creature_sculpt.gd): the palette and painters
## (bark, moss, leaves, mushroom caps, carved faces), rig joints and parts, and shared pieces
## such as root fingers, sprouts and moss clumps. A creature script extends this and builds
## its model with the same rig joints the game animates: head, core (the glowing eyes),
## arms, forearms, hips, knees and swaying leaves.

const Sculpt = preload("res://tools/creature_sculpt.gd")

const BARK := Color("#6e5136")
const BARK_LIGHT := Color("#977250")
const BARK_DARK := Color("#35261a")
const MOSS := Color("#4c742a")
const MOSS_LIGHT := Color("#8aa845")
const LEAF := Color("#6f9b38")
const LEAF_LIGHT := Color("#b4cf5a")
const SOCKET := Color("#170f09")
const GLOW := Color("#ffc65c")
const CAP := Color("#b4532f")
const CAP_SPOT := Color("#f1e2bd")
const GILL := Color("#dcc59a")
const TUSK := Color("#cdb68b")

var material: StandardMaterial3D
var glow: StandardMaterial3D
var root: Node3D
var gloss: StandardMaterial3D


func _init(detail := "res://assets/cast/bark_detail_gray.png") -> void:
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(detail)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(2.4, 2.4, 2.4)
	material.roughness = 0.93
	glow = StandardMaterial3D.new()
	glow.albedo_color = GLOW
	glow.emission_enabled = true
	glow.emission = GLOW
	glow.emission_energy_multiplier = 1.1
	glow.roughness = 0.4
	gloss = StandardMaterial3D.new()
	gloss.vertex_color_use_as_albedo = true
	gloss.roughness = 0.14
	gloss.metallic = 0.25
	gloss.metallic_specular = 0.9
	gloss.emission_enabled = true
	gloss.emission = Color("#3a4a55")
	gloss.emission_energy_multiplier = 0.6


# ---------------------------------------------------------------- painters

static func bark(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var grain := Sculpt.fbm(Vector3(p.x * 8.0, p.y * 1.7, p.z * 8.0))
	var c := BARK.lerp(BARK_LIGHT, clampf(0.45 + grain * 0.9, 0.0, 1.0))
	c = c.lerp(BARK_DARK, clampf(-w, 0.0, 1.0) * 0.6)
	c = c.lerp(BARK_DARK, clampf(1.0 - p.y / 0.3, 0.0, 1.0) * 0.45)
	var moss := smoothstep(0.5, 0.85, n.y + 0.45 * Sculpt.fbm(p * 4.3))
	return c.lerp(moss_color(p), moss)


## Bark with no moss, for faces and hands.
static func bare(p: Vector3, _n: Vector3, _v: float, w: float) -> Color:
	var grain := Sculpt.fbm(Vector3(p.x * 8.0, p.y * 1.7, p.z * 8.0))
	var c := BARK.lerp(BARK_LIGHT, clampf(0.45 + grain * 0.9, 0.0, 1.0))
	return c.lerp(BARK_DARK, clampf(-w, 0.0, 1.0) * 0.6)


static func moss_color(p: Vector3) -> Color:
	var c := MOSS.lerp(MOSS_LIGHT, clampf(0.5 + Sculpt.fbm(p * 12.0) * 1.1, 0.0, 1.0))
	return c.darkened(clampf(Sculpt.fbm(p * 3.5 + Vector3(7, 1, 3)), 0.0, 1.0) * 0.35)


static func moss(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return moss_color(p).darkened(clampf(-n.y, 0.0, 1.0) * 0.35)


static func leaf(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return LEAF.lerp(LEAF_LIGHT, clampf(0.4 + n.y * 0.4 + Sculpt.noise(p * 20.0) * 0.3, 0.0, 1.0))


static func root_tip(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var grain := Sculpt.fbm(Vector3(p.x * 8.0, p.y * 1.7, p.z * 8.0))
	var c := BARK.lerp(BARK_LIGHT, clampf(0.45 + grain * 0.9, 0.0, 1.0))
	return c.lerp(Color("#c4a57c"), smoothstep(0.55, 1.0, v) * 0.8)


static func tusk(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return TUSK.darkened((1.0 - v) * 0.25)


static func cap(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	if n.y < -0.15: return GILL.darkened(0.15 + Sculpt.noise(p * 40.0) * 0.08)
	var spot := Sculpt.noise(p * 9.0 + Vector3(3, 0, 1))
	var c := CAP.lerp(CAP.lightened(0.18), clampf(n.y, 0.0, 1.0) * 0.5)
	return c.lerp(CAP_SPOT, smoothstep(0.32, 0.42, spot))


## Bark with dark eye sockets and a mouth carved into it.
static func face(eyes: Array, mouth: Rect2, mouth_z: float, base: Callable = bark) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c: Color = base.call(p, n, v, w)
		for e in eyes:
			var d: float = (p - e).length()
			c = c.lerp(SOCKET, smoothstep(0.11, 0.05, d))
		if p.z < mouth_z and mouth.has_point(Vector2(p.x, p.y)):
			var edge := minf(minf(p.x - mouth.position.x, mouth.end.x - p.x), minf(p.y - mouth.position.y, mouth.end.y - p.y))
			c = c.lerp(SOCKET, smoothstep(0.0, 0.025, edge))
		return c


# ---------------------------------------------------------------- scene helpers

static func _world(n: Node3D) -> Vector3:
	var p := Vector3.ZERO
	while n != null:
		p += n.position
		n = n.get_parent() as Node3D
	return p


func joint(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var j := Node3D.new(); j.name = name
	parent.add_child(j)
	j.position = at - _world(parent)
	return j


func part(parent: Node3D, name: String, s: Sculpt, mat: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.name = name
	m.mesh = s.commit(material if mat == null else mat, _world(parent))
	parent.add_child(m)
	return m


# ---------------------------------------------------------------- shared pieces

## Root fingers or toes spreading from `base` in the given directions.
func roots(s: Sculpt, own_painter: int, base: Vector3, dirs: Array, length: float, radius: float, drop: float, use_own := false) -> void:
	var painter := own_painter if use_own else s.add_painter(root_tip)
	for d in dirs:
		var dir: Vector3 = d
		var pts := [base, base + dir * length * 0.4 + Vector3(0, -drop * 0.35, 0), base + dir * length * 0.8 + Vector3(0, -drop * 0.8, 0), base + dir * length + Vector3(0, -drop, 0)]
		s.tube(pts, [radius, radius * 0.8, radius * 0.55, radius * 0.25], painter, {"sides": 6, "per": 2, "cap_rings": 1, "lump": 0.15})


## A sprout: a curved twig with leaves, as its own swaying node.
func sprout(parent: Node3D, name: String, at: Vector3, lean: Vector3, height: float, leaves: int) -> Node3D:
	var node := joint(parent, name, at)
	var s := Sculpt.new(); var b := s.add_painter(bark); var l := s.add_painter(leaf)
	var top := at + lean * height * 0.55 + Vector3(0, height, 0)
	s.tube([at, at + lean * height * 0.15 + Vector3(0, height * 0.5, 0), top], [0.03, 0.022, 0.01], b, {"sides": 6, "per": 2, "cap_rings": 1})
	for k in range(leaves):
		var ang := TAU * k / leaves + 0.4
		var out := Vector3(cos(ang), 0.55, sin(ang)).normalized()
		var basis := Basis.looking_at(out, Vector3.UP).rotated(out, 0.3)
		var t := 0.6 + 0.4 * float(k % 2)
		var stem := at.lerp(top, t)
		s.blob(stem + out * 0.07, Vector3(0.038, 0.009, 0.075), l, {"basis": basis, "lat": 4, "lon": 6})
	part(node, "Sprout", s)
	return node


## A lumpy ring of moss hiding where the head meets the body.
func moss_collar(s: Sculpt, painter: int, center: Vector3, radius: float, count: int, size: float) -> void:
	var pts: Array = []; var radii: Array = []
	for k in range(count + 2):
		var ang := TAU * k / count
		pts.append(center + Vector3(cos(ang) * radius, Sculpt.noise(Vector3(k % count, 0, 0) * 1.7) * 0.02, sin(ang) * radius))
		radii.append(size * (1.0 + 0.3 * Sculpt.noise(Vector3((k % count) * 2.1, 5, 1))))
	s.tube(pts, radii, painter, {"sides": 9, "per": 3, "flat": 0.6, "side": Vector3.UP, "lump": 0.45})


## A soft clump of moss: several overlapping lumps, low and spread out.
func moss_clump(s: Sculpt, painter: int, center: Vector3, size: float, count: int) -> void:
	for k in range(count):
		var ang := TAU * k / count + 0.7
		var at := center + Vector3(cos(ang), 0.0, sin(ang)) * size * (0.55 if k > 0 else 0.0) + Vector3(0, -absf(Sculpt.noise(Vector3(k, 3, 0))) * size * 0.2, 0)
		var r := size * (0.75 if k == 0 else 0.5 + 0.2 * Sculpt.noise(Vector3(k * 1.9, 1, 2)))
		s.blob(at, Vector3(r, r * 0.45, r), painter, {"lat": 7, "lon": 11, "lump": 0.45})


func _finish(rig: Dictionary, scale: float) -> Node3D:
	var paths := {}
	for key in rig:
		var value = rig[key]
		if value is Node: paths[key] = root.get_path_to(value)
		elif value is Array:
			var list: Array = []
			for item in value: list.append(root.get_path_to(item))
			paths[key] = list
		else: paths[key] = value
	for key in ["boss_jaw", "boss_tail", "phase_crown"]: paths[key] = null
	for key in ["boss_bells", "boss_cloth"]: paths[key] = []
	root.set_meta("rig_bindings", paths)
	root.set_meta("actor_properties", {"rest_scale": Vector3.ONE * scale, "normal_glow": glow, "attack_glow": null, "hurt_glow": null})
	root.set_meta("geometry_revision", "sculpted-1")
	root.set_meta("sculpt_triangles", triangles(root))
	_own(root, root)
	return root


static func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)


static func triangles(node: Node) -> int:
	var total := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = m.mesh
		for sidx in range(mesh.get_surface_count()):
			total += mesh.surface_get_arrays(sidx)[Mesh.ARRAY_INDEX].size() / 3
	return total


## The spotted mushroom cap (from the Capwood Sage design), scaled.
func mushroom_cap(s: Sculpt, painter: int, center: Vector3, size: float, tilt: Basis) -> void:
	var profile: Array = []
	for pr in [Vector2(0, 0.24), Vector2(0.18, 0.225), Vector2(0.34, 0.15), Vector2(0.47, 0.04), Vector2(0.54, -0.06), Vector2(0.53, -0.1), Vector2(0.46, -0.07), Vector2(0.3, -0.03), Vector2(0.14, -0.01), Vector2(0, 0.0)]:
		profile.append(pr * size)
	s.lathe(center, profile, painter, {"sides": 18, "wobble": 0.12, "basis": tilt})


## Little garden flowers: five petals round a yellow middle, facing up.
func flowers(s: Sculpt, spots: Array, size: float) -> void:
	var colors := [Color("#f4efe4"), Color("#f2a7c3"), Color("#ffe27a"), Color("#b9c8ff")]
	var painters: Array = []
	for c in colors: painters.append(s.add_painter(func (_p, n, _v, _w): return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.3)))
	var middle := s.add_painter(func (_p, _n, _v, _w): return Color("#e8a93a"))
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var pp: int = painters[k % painters.size()]
		for petal in range(5):
			var ang := TAU * petal / 5.0 + k
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			s.blob(at + dir * size * 0.75, Vector3(size * 0.62, size * 0.16, size * 0.38), pp, {"basis": Basis(Vector3.UP, -ang), "lat": 3, "lon": 6})
		s.blob(at + Vector3(0, size * 0.1, 0), Vector3.ONE * size * 0.38, middle, {"lat": 3, "lon": 6})


## A vine winding round a limb, with a few leaves.
func vine(s: Sculpt, axis: Array, around: float, turns: float, thickness: float, leaf_count: int) -> void:
	var painter := s.add_painter(func (p, n, v, w): return Color("#4f6b2a").lerp(Color("#6d8a37"), clampf(0.5 + Sculpt.noise(p * 15.0), 0.0, 1.0)))
	var lp := s.add_painter(leaf)
	var pts: Array = []; var radii: Array = []
	var steps := 18
	for k in range(steps + 1):
		var t := float(k) / steps
		var seg := t * (axis.size() - 1)
		var i := mini(int(seg), axis.size() - 2)
		var c: Vector3 = (axis[i] as Vector3).lerp(axis[i + 1], seg - i)
		var tangent: Vector3 = ((axis[i + 1] as Vector3) - axis[i]).normalized()
		var side := tangent.cross(Vector3.FORWARD if absf(tangent.z) < 0.9 else Vector3.RIGHT).normalized()
		var up := tangent.cross(side)
		var ang := t * TAU * turns
		pts.append(c + (side * cos(ang) + up * sin(ang)) * around)
		radii.append(thickness)
	s.tube(pts, radii, painter, {"sides": 5, "per": 1, "cap_rings": 1})
	for k in range(leaf_count):
		var at: Vector3 = pts[int(float(k + 0.5) / leaf_count * steps)]
		var c2: Vector3 = axis[0].lerp(axis[-1], float(k + 0.5) / leaf_count)
		var out := (at - c2).normalized()
		s.blob(at + out * 0.035, Vector3(0.03, 0.007, 0.05), lp, {"basis": Basis.looking_at(out + Vector3(0, 0.6, 0), Vector3.UP), "lat": 3, "lon": 6})


## Thin strands hanging down from each point (moss fringes, lichen beards).
func hanging(s: Sculpt, painter: int, spots: Array, length: float, thickness: float, outward: Vector3 = Vector3.ZERO) -> void:
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var l := length * (0.7 + 0.3 * absf(Sculpt.noise(at * 9.0)))
		var sway := Vector3(Sculpt.noise(at * 5.0), 0, Sculpt.noise(at * 5.0 + Vector3(4, 0, 0))) * 0.04
		s.tube([at, at + Vector3(0, -l * 0.5, 0) + outward * 0.5 + sway, at + Vector3(0, -l, 0) + outward + sway * 2.0], [thickness, thickness * 0.8, thickness * 0.3], painter, {"sides": 5, "per": 2, "cap_rings": 1})


static func vine_color(p: Vector3) -> Color:
	return Color("#4a6326").lerp(Color("#6f8c36"), clampf(0.5 + Sculpt.noise(p * 15.0), 0.0, 1.0))


## Vines hanging down from each spot, with leaves along them.
func hanging_vines(s: Sculpt, spots: Array, length: float, outward: Array = []) -> void:
	var vp := s.add_painter(func (p, n, v, w): return vine_color(p))
	var lp := s.add_painter(leaf)
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var out: Vector3 = outward[k] if k < outward.size() else Vector3.ZERO
		var l := length * (0.6 + 0.4 * absf(Sculpt.noise(at * 7.0 + Vector3(k, 0, 0))))
		var sway := Vector3(Sculpt.noise(at * 5.0), 0, Sculpt.noise(at * 5.0 + Vector3(4, 0, 0))) * 0.05
		var curl := Vector3(Sculpt.noise(at * 3.0 + Vector3(1, 1, 1)), 0, Sculpt.noise(at * 3.0 + Vector3(7, 2, 2))) * 0.07
		var pts := [at, at + out * 0.7 + Vector3(0, -l * 0.25, 0) + sway, at + out + Vector3(0, -l * 0.5, 0) + sway * 1.5 + curl, at + out + Vector3(0, -l * 0.75, 0) + sway * 2.0 - curl * 0.5, at + out * 1.1 + Vector3(0, -l, 0) + sway * 2.5 + curl]
		s.tube(pts, [0.014, 0.013, 0.012, 0.01, 0.006], vp, {"sides": 5, "per": 3, "cap_rings": 1})
		var leaves := int(l / 0.085)
		for j in range(leaves):
			var t := (j + 0.7) / (leaves + 0.5)
			var seg := t * 4.0; var i := mini(int(seg), 3)
			var c: Vector3 = (pts[i] as Vector3).lerp(pts[i + 1], seg - i)
			var ang := j * 2.4 + k
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			s.blob(c + dir * 0.035, Vector3(0.028, 0.006, 0.048), lp, {"basis": Basis.looking_at(dir + Vector3(0, -0.5, 0), Vector3.UP), "lat": 3, "lon": 6})


## A curved thorn from base towards dir.
func thorn(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, radius: float, bend := Vector3.ZERO) -> void:
	var d := dir.normalized()
	s.tube([base - d * radius, base + d * length * 0.5 + bend * 0.5, base + d * length + bend], [radius, radius * 0.5, 0.002], painter, {"sides": 5, "per": 2, "cap_rings": 1, "cap1": false})


## Pointed tufts of fur: each spot gets a cone leaning along dir.
func tufts(s: Sculpt, painter: int, spots: Array, dirs: Array, length: float, radius: float) -> void:
	for k in range(spots.size()):
		var d: Vector3 = (dirs[k] if k < dirs.size() else dirs[-1]).normalized()
		var at: Vector3 = spots[k]
		var l := length * (0.75 + 0.35 * absf(Sculpt.noise(at * 11.0)))
		s.tube([at, at + d * l * 0.55 + Vector3(0, -l * 0.08, 0), at + d * l], [radius, radius * 0.6, 0.003], painter, {"sides": 6, "per": 2, "cap_rings": 2, "cap1": false, "side": Vector3.UP, "flat": 0.8})


## A bramble cane along a path with thorns, a few leaves and red rose hips.
func briar(s: Sculpt, path: Array, thickness: float, thorns: int, hips: int, leaves: int) -> void:
	var bp := s.add_painter(func (p, n, v, w): return Color("#5b3a26").lerp(Color("#7b5134"), clampf(0.5 + Sculpt.noise(p * 14.0), 0.0, 1.0)))
	var tp := s.add_painter(func (p, n, v, w): return Color("#d9c8a0").lerp(Color("#7b5134"), 1.0 - v))
	var hp := s.add_painter(func (p, n, v, w): return Color("#b3261c").lightened(clampf(n.y, 0.0, 1.0) * 0.25))
	var lp := s.add_painter(leaf)
	var radii: Array = []
	for k in range(path.size()): radii.append(thickness * (1.0 - 0.4 * float(k) / path.size()))
	s.tube(path, radii, bp, {"sides": 6, "per": 3, "cap_rings": 1})
	var spots := thorns + hips + leaves
	for k in range(spots):
		var t := (k + 0.5) / spots
		var seg := t * (path.size() - 1); var i := mini(int(seg), path.size() - 2)
		var at: Vector3 = (path[i] as Vector3).lerp(path[i + 1], seg - i)
		var along: Vector3 = ((path[i + 1] as Vector3) - path[i]).normalized()
		var ang := k * 2.3
		var side := along.cross(Vector3.UP).normalized()
		if side.length() < 0.1: side = Vector3.RIGHT
		var up := side.cross(along).normalized()
		var out := (side * cos(ang) + up * absf(sin(ang)) * 1.2).normalized()
		var kind := k % 3
		if kind == 0 and thorns > 0: s.crystal(at, out + along * 0.3, thickness * 2.6, thickness * 0.45, tp, 5)
		elif kind == 1 and hips > 0: s.blob(at + out * thickness * 2.0, Vector3(0.028, 0.034, 0.028), hp, {"lat": 4, "lon": 7})
		elif leaves > 0: s.blob(at + out * 0.04, Vector3(0.026, 0.006, 0.044), lp, {"basis": Basis.looking_at(out + along * 0.5, Vector3.UP), "lat": 3, "lon": 6})


## A bevelled block: size is (width, height, length along `axis`), turned by basis.
func slab(s: Sculpt, painter: int, center: Vector3, size: Vector3, basis := Basis.IDENTITY, bevel := 0.3, lump := 0.04, facet := false) -> void:
	var axis := basis * Vector3.BACK
	var half := axis * maxf(size.z * 0.5 - size.y * 0.5 * bevel, 0.01)
	s.tube([center - half, center + half], [size.y * 0.5, size.y * 0.5], painter, {"sides": 12, "per": 1 if not facet else 2, "square": 1.0, "flat": size.x / size.y, "side": basis * Vector3.RIGHT, "cap_len": bevel, "cap_rings": 2, "lump": lump, "facet": facet})

