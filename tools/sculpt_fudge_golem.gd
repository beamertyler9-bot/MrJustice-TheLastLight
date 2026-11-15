extends "res://tools/creature_kit.gd"
## The Fudge Golem of S'morewood, sculpted by hand and kept close to the original: a chunky
## fudge golem with chocolate-bar plates on its chest, soft glossy caramel joints, chocolate
## dripping from its head and shoulders, sprinkles, a cherry on top and the mint leaf glowing
## in its chest. It wobbles before a slow, sticky slam.

const FUDGE := Color("#5a3220")
const FUDGE_LIGHT := Color("#764631")
const FUDGE_DARK := Color("#361d12")
const CHOCOLATE := Color("#3d2216")
const CARAMEL := Color("#d99a3c")
const CARAMEL_LIGHT := Color("#f4c56a")
const CHERRY := Color("#c8141c")
const MINT_LEAF := Color("#9deccb")
const SPRINKLES := [Color("#ff6fa8"), Color("#7fd7ff"), Color("#fff07a"), Color("#8ef08a"), Color("#ffffff")]

var candy: StandardMaterial3D
var skin: Callable = fudge
var joint_skin: Callable = caramel
var joint_mat: Material
var style := "classic"


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(2.0, 2.0, 2.0)
	material.roughness = 0.55
	material.vertex_color_is_srgb = true
	candy = StandardMaterial3D.new()
	candy.vertex_color_use_as_albedo = true
	candy.vertex_color_is_srgb = true
	candy.roughness = 0.18
	candy.metallic_specular = 0.8
	glow.albedo_color = MINT_LEAF.darkened(0.15); glow.emission = MINT_LEAF
	glow.emission_energy_multiplier = 0.55
	joint_mat = candy


static func fudge(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := FUDGE.lerp(FUDGE_LIGHT, clampf(0.4 + n.y * 0.3 + Sculpt.fbm(p * 4.0) * 0.5, 0.0, 1.0))
	return c.lerp(FUDGE_DARK, clampf(-n.y, 0.0, 1.0) * 0.45)


static func chocolate(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return CHOCOLATE.lerp(CHOCOLATE.lightened(0.18), clampf(0.3 + n.y * 0.4, 0.0, 1.0))


static func caramel(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return CARAMEL.lerp(CARAMEL_LIGHT, clampf(0.35 + n.y * 0.5 + Sculpt.noise(p * 8.0) * 0.2, 0.0, 1.0))


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "FudgeGolem"
	match variant:
		"classic": return _golem()
		"smore":
			style = "smore"; skin = graham; joint_skin = marshmallow
			joint_mat = material
			glow.albedo_color = Color("#ff9a3c").darkened(0.15); glow.emission = Color("#ff8a2a")
			return _golem()
		"brownie":
			style = "brownie"; skin = brownie; joint_skin = frosting
			return _golem()
	return null


## Chocolate drips hanging from each spot, ending in a round drop.
func drips(s: Sculpt, painter: int, spots: Array, length: float) -> void:
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var l := length * (0.5 + 0.6 * absf(Sculpt.noise(at * 9.0 + Vector3(k, 0, 0))))
		var r := 0.03 + 0.012 * (k % 3)
		s.tube([at + Vector3(0, 0.02, 0), at + Vector3(0, -l * 0.6, 0), at + Vector3(0, -l, 0)], [r, r * 0.8, r * 0.75], painter, {"sides": 7, "per": 2, "cap_rings": 2})
		s.blob(at + Vector3(0, -l - r * 0.4, 0), Vector3.ONE * r * 1.25, painter, {"lat": 5, "lon": 7})


func sprinkles(s: Sculpt, center: Vector3, radius: float, count: int, rise: float) -> void:
	var painters: Array = []
	for c in SPRINKLES: painters.append(s.add_painter(func (p, n, v, w): return c))
	for k in range(count):
		var ang := k * 2.39996
		var d := radius * sqrt((k + 0.5) / count)
		var at := center + Vector3(cos(ang) * d, rise * (1.0 - (d / radius) * (d / radius)), sin(ang) * d)
		var dir := Vector3(cos(ang * 3.1), 0.15, sin(ang * 3.1)).normalized()
		s.tube([at - dir * 0.025, at + dir * 0.025], [0.009, 0.009], painters[k % painters.size()], {"sides": 5, "per": 1, "cap_rings": 1})


func _golem() -> Node3D:
	var body := Sculpt.new(); var fp := body.add_painter(skin); var cp := body.add_painter(chocolate)
	body.tube([Vector3(0, 0.68, 0.03), Vector3(0, 0.95, 0.03), Vector3(0, 1.25, 0.02), Vector3(0, 1.5, 0.0), Vector3(0, 1.64, 0.0)], [0.3, 0.33, 0.4, 0.42, 0.3], fp, {"sides": 16, "per": 3, "flat": 1.15, "lump": 0.1 if style != "brownie" else 0.05, "square": 0.85 if style == "brownie" else 0.0, "facet": style == "brownie"})
	if style == "smore": _smore_body(body)
	elif style == "brownie": _brownie_body(body)
	else: _classic_body(body, cp)
	part(root, "Body", body)
	var ls := Sculpt.new(); var lw := ls.add_painter(func (p, n, v, w): return Color.WHITE)
	if style == "smore":
		ls.rock(Vector3(0, 1.3, -0.47), Vector3(0.09, 0.08, 0.05), lw, {"lat": 4, "lon": 6, "lump": 0.3})
	else:
		ls.blob(Vector3(0, 1.32, -0.45), Vector3(0.075, 0.12, 0.03), lw, {"lat": 6, "lon": 10})
		ls.crystal(Vector3(0, 1.2, -0.45), Vector3(0, -1, -0.1), 0.06, 0.012, lw, 4)
	var core := part(root, "GlowingLeaf", ls, glow)
	core.material_override = glow
	return _golem_rest(core)


func _classic_body(body: Sculpt, cp: int) -> void:
	# A chocolate bar set into the chest: a slab with six raised squares.
	var tilt := Basis(Vector3.RIGHT, -0.08)
	slab(body, cp, Vector3(0, 1.3, -0.36), Vector3(0.44, 0.06, 0.6), tilt * Basis(Vector3.RIGHT, PI * 0.5), 0.25, 0.0)
	for row in range(3):
		for side in [-1.0, 1.0]:
			slab(body, cp, Vector3(0.105 * side, 1.49 - row * 0.19, -0.4 + row * 0.015), Vector3(0.18, 0.16, 0.05), tilt, 0.35, 0.0)
	# Chocolate poured over the shoulders, dripping down.
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.3 * side, 1.64, 0.0), Vector3(0.22, 0.07, 0.22), cp, {"lat": 6, "lon": 10, "lump": 0.25})
	drips(body, cp, [Vector3(-0.42, 1.6, -0.08), Vector3(-0.3, 1.6, -0.2), Vector3(0.36, 1.6, -0.16), Vector3(0.44, 1.58, 0.06), Vector3(-0.4, 1.58, 0.12), Vector3(0.2, 1.62, 0.2)], 0.2)
	sprinkles(body, Vector3(0.3, 1.7, 0.0), 0.16, 8, 0.02)
	sprinkles(body, Vector3(-0.3, 1.7, 0.0), 0.16, 8, 0.02)


func _golem_rest(core: MeshInstance3D) -> Node3D:
	var head := joint(root, "Head", Vector3(0, 1.79, -0.045))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin); var hc := hs.add_painter(chocolate)
	var dark := hs.add_painter(func (p, n, v, w): return Color("#1d0f09")); var shine := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	if style == "smore":
		# The head is a giant toasted marshmallow.
		hp = hs.add_painter(marshmallow)
		hs.tube([Vector3(0, 1.66, -0.06), Vector3(0, 2.06, -0.06)], [0.23, 0.23], hp, {"sides": 16, "per": 3, "cap_len": 0.35, "lump": 0.05})
	elif style == "brownie":
		hs.tube([Vector3(0, 1.66, -0.06), Vector3(0, 2.0, -0.06)], [0.21, 0.22], hp, {"sides": 16, "per": 2, "flat": 1.05, "square": 0.85, "cap_len": 0.3, "lump": 0.05, "facet": true})
		_frosting_cap(hs, Vector3(0, 2.03, -0.06), 0.29)
	else:
		hs.blob(Vector3(0, 1.86, -0.06), Vector3(0.22, 0.24, 0.21), hp, {"lat": 11, "lon": 15, "lump": 0.06})
		# Chocolate frosting poured over the top of the head, dripping down the sides.
		hs.blob(Vector3(0, 2.01, -0.05), Vector3(0.23, 0.11, 0.22), hc, {"lat": 7, "lon": 13, "lump": 0.2})
		drips(hs, hc, [Vector3(-0.2, 1.97, -0.1), Vector3(0.21, 1.96, -0.02), Vector3(-0.12, 1.96, 0.15), Vector3(0.14, 1.97, 0.14), Vector3(0.0, 1.96, 0.2)], 0.14)
		sprinkles(hs, Vector3(0, 2.07, -0.05), 0.17, 14, 0.04)
	# An angry brow, a blunt nose, dark eyes and a frowning mouth.
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.15 * side, 1.95, -0.2), Vector3(0.04 * side, 1.92, -0.25)], [0.032, 0.036], hc, {"sides": 7, "per": 2, "cap_rings": 2})
		hs.blob(Vector3(0.08 * side, 1.88, -0.235), Vector3(0.034, 0.03, 0.02), dark, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.088 * side, 1.893, -0.252), Vector3(0.009, 0.009, 0.005), shine, {"lat": 3, "lon": 5})
	hs.blob(Vector3(0, 1.82, -0.265), Vector3(0.045, 0.05, 0.04), hp, {"lat": 6, "lon": 8})
	hs.tube([Vector3(-0.08, 1.725, -0.235), Vector3(0, 1.74, -0.25), Vector3(0.08, 1.725, -0.235)], [0.014, 0.016, 0.014], dark, {"sides": 6, "per": 3, "cap_rings": 1})
	part(head, "Head", hs)
	if style == "classic": _cherry(head)
	return _limbs(head, core)


func _cherry(head: Node3D) -> void:
	var cherry := Sculpt.new(); var cr := cherry.add_painter(func (p, n, v, w): return CHERRY.lightened(clampf(n.y, 0.0, 1.0) * 0.2)); var stem := cherry.add_painter(func (p, n, v, w): return Color("#5a6b22"))
	cherry.blob(Vector3(0.02, 2.17, -0.04), Vector3(0.075, 0.07, 0.075), cr, {"lat": 8, "lon": 12})
	cherry.tube([Vector3(0.02, 2.22, -0.04), Vector3(0.05, 2.3, -0.02), Vector3(0.1, 2.36, 0.02)], [0.008, 0.007, 0.006], stem, {"sides": 5, "per": 3, "cap_rings": 1})
	part(head, "Cherry", cherry, candy)


func _limbs(head: Node3D, core: MeshInstance3D) -> Node3D:

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.44 * side, 1.44, 0))
		var us := Sculpt.new(); var up := us.add_painter(skin)
		us.tube([Vector3(0.44 * side, 1.5, 0.0), Vector3(0.52 * side, 1.25, 0.01), Vector3(0.54 * side, 1.08, 0.0)], [0.15, 0.14, 0.13], up, {"sides": 12, "per": 3, "lump": 0.1})
		part(shoulder, "UpperArm", us)
		var joints := Sculpt.new(); var jp := joints.add_painter(joint_skin)
		joints.blob(Vector3(0.42 * side, 1.5, 0.0), Vector3.ONE * 0.16, jp, {"lat": 8, "lon": 12, "lump": 0.08})
		part(shoulder, "CaramelShoulder", joints, joint_mat)
		var elbow := joint(shoulder, "Forearm", Vector3(0.54 * side, 1.04, -0.015))
		var fs := Sculpt.new(); var fpp := fs.add_painter(skin)
		fs.tube([Vector3(0.54 * side, 1.02, -0.015), Vector3(0.57 * side, 0.8, -0.04), Vector3(0.58 * side, 0.64, -0.05)], [0.13, 0.155, 0.14], fpp, {"sides": 12, "per": 3, "lump": 0.1})
		fs.blob(Vector3(0.59 * side, 0.55, -0.06), Vector3(0.14, 0.12, 0.13), fpp, {"lat": 7, "lon": 10, "lump": 0.1})
		for f in range(3):
			var base := Vector3((0.59 + (f - 1) * 0.07) * side, 0.48, -0.14)
			fs.tube([base, base + Vector3(0, -0.08, -0.03), base + Vector3(0, -0.13, 0.0)], [0.04, 0.036, 0.03], fpp, {"sides": 7, "per": 2, "cap_rings": 2})
		part(elbow, "Forearm", fs)
		var ej := Sculpt.new(); var ejp := ej.add_painter(joint_skin)
		ej.blob(Vector3(0.545 * side, 1.05, -0.015), Vector3.ONE * 0.12, ejp, {"lat": 7, "lon": 10, "lump": 0.08})
		part(elbow, "CaramelElbow", ej, joint_mat)
		arms.append(shoulder); forearms.append(elbow)

	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.22 * side, 0.72, 0.025))
		var ts := Sculpt.new(); var tp := ts.add_painter(skin)
		ts.tube([Vector3(0.21 * side, 0.8, 0.025), Vector3(0.22 * side, 0.6, 0.02), Vector3(0.22 * side, 0.42, 0.01)], [0.17, 0.155, 0.14], tp, {"sides": 12, "per": 3, "lump": 0.1})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", Vector3(0.22 * side, 0.38, 0.01))
		var kj := Sculpt.new(); var kjp := kj.add_painter(joint_skin)
		kj.blob(Vector3(0.22 * side, 0.39, -0.01), Vector3(0.14, 0.11, 0.14), kjp, {"lat": 7, "lon": 10, "lump": 0.08})
		part(knee, "CaramelKnee", kj, joint_mat)
		var ss := Sculpt.new(); var sp := ss.add_painter(skin); var sc := ss.add_painter(chocolate)
		ss.tube([Vector3(0.22 * side, 0.38, 0.01), Vector3(0.22 * side, 0.2, 0.0), Vector3(0.22 * side, 0.1, -0.01)], [0.13, 0.13, 0.14], sp, {"sides": 12, "per": 3, "lump": 0.1})
		slab(ss, sc, Vector3(0.22 * side, 0.06, -0.07), Vector3(0.24, 0.12, 0.36), Basis.IDENTITY, 0.6, 0.05)
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.25)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node


# ---------------------------------------------------------------- S'more and brownie

const GRAHAM := Color("#a8703a")
const GRAHAM_LIGHT := Color("#c48a4a")
const MALLOW := Color("#f7f1e6")
const TOAST := Color("#b8732e")
const BROWNIE := Color("#3a2216")
const BROWNIE_CRUST := Color("#5a3a26")
const FROSTING := Color("#2b160d")
const SUGAR := Color("#f4efe8")
const WALNUT := Color("#a8763f")


## Graham cracker: golden with rows of little docking holes.
static func graham(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := GRAHAM.lerp(GRAHAM_LIGHT, clampf(0.4 + n.y * 0.3 + Sculpt.fbm(p * 6.0) * 0.4, 0.0, 1.0))
	var holes := Vector2(fposmod(p.x * 12.0, 1.0) - 0.5, fposmod(p.y * 12.0, 1.0) - 0.5).length()
	c = c.lerp(GRAHAM.darkened(0.45), smoothstep(0.16, 0.08, holes) * 0.7)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.3)


## Marshmallow: soft white, toasted golden-brown on top with a few charred spots.
static func marshmallow(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var toast := smoothstep(0.2, 0.85, n.y + Sculpt.fbm(p * 5.0) * 0.35)
	var c := MALLOW.lerp(TOAST, toast)
	return c.lerp(Color("#4a2a14"), smoothstep(0.55, 0.65, Sculpt.noise(p * 12.0)) * toast * 0.8)


## Brownie: dark and fudgy with a crackly, lighter crust on top.
static func brownie(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := BROWNIE.lerp(BROWNIE.lightened(0.1), clampf(Sculpt.fbm(p * 7.0) * 0.6 + 0.3, 0.0, 1.0))
	var crust := smoothstep(0.3, 0.8, n.y)
	c = c.lerp(BROWNIE_CRUST, crust)
	return c.lerp(BROWNIE.darkened(0.4), smoothstep(0.05, 0.0, absf(Sculpt.noise(p * 9.0))) * crust)


## Glossy fudge frosting with a dusting of powdered sugar on top.
static func frosting(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := FROSTING.lerp(FROSTING.lightened(0.2), clampf(n.y * 0.5, 0.0, 1.0))
	return c.lerp(SUGAR, smoothstep(0.5, 0.9, n.y) * smoothstep(0.2, 0.5, Sculpt.noise(p * 25.0) + 0.3) * 0.8)


func _smore_body(body: Sculpt) -> void:
	# A s'more stack: graham cracker body, a layer of chocolate and marshmallow squeezed out
	# round the middle, and graham squares on the chest.
	var cp := body.add_painter(chocolate); var mp := body.add_painter(marshmallow); var gp := body.add_painter(graham)
	for ring in [[1.08, 0.075, cp, 0.43], [1.0, 0.1, mp, 0.44]]:
		var pts: Array = []; var radii: Array = []
		for k in range(15):
			var ang := TAU * k / 13.0
			pts.append(Vector3(cos(ang) * ring[3] * 1.12, ring[0] + 0.015 * sin(ang * 3.0), 0.02 + sin(ang) * ring[3] * 0.92))
			radii.append(ring[1] * (1.0 + 0.2 * Sculpt.noise(Vector3(k, ring[0] * 10.0, 0))))
		body.tube(pts, radii, ring[2], {"sides": 9, "per": 3, "lump": 0.3 if ring[2] == mp else 0.05, "flat": 0.7, "side": Vector3.UP})
	for side in [-1.0, 1.0]:
		slab(body, gp, Vector3(0.12 * side, 1.42, -0.38), Vector3(0.22, 0.26, 0.05), Basis(Vector3.RIGHT, -0.1), 0.3, 0.02)
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.3 * side, 1.66, 0.0), Vector3(0.2, 0.09, 0.2), mp, {"lat": 6, "lon": 10, "lump": 0.25})


func _frosting_cap(s: Sculpt, center: Vector3, size: float) -> void:
	var fr := s.add_painter(frosting); var wn := s.add_painter(func (p, n, v, w): return WALNUT.lerp(WALNUT.darkened(0.4), clampf(-n.y + Sculpt.noise(p * 30.0) * 0.4, 0.0, 1.0)))
	s.blob(center, Vector3(size, size * 0.35, size * 0.95), fr, {"lat": 6, "lon": 12, "lump": 0.25})
	drips(s, fr, [center + Vector3(-size * 0.85, -0.02, -size * 0.3), center + Vector3(size * 0.8, -0.03, size * 0.2), center + Vector3(-size * 0.4, -0.02, size * 0.8)], 0.1)
	for k in range(3):
		var ang := k * 2.1 + 0.4
		s.rock(center + Vector3(cos(ang) * size * 0.45, size * 0.3, sin(ang) * size * 0.45), Vector3(0.045, 0.025, 0.035), wn, {"lat": 4, "lon": 6, "lump": 0.5})


func _brownie_body(body: Sculpt) -> void:
	# Chunky brownie with chocolate chips, frosting over the shoulders and a few walnuts.
	var chip := body.add_painter(func (p, n, v, w): return Color("#1f100a"))
	for k in range(22):
		var ang := k * 2.39996
		var y := 0.78 + fposmod(k * 0.37, 0.82)
		var at := Vector3(cos(ang) * 0.42, y, 0.02 + sin(ang) * 0.35)
		body.crystal(at, Vector3(cos(ang), 0.2, sin(ang)), 0.07, 0.04, chip, 5)
	for side in [-1.0, 1.0]:
		_frosting_cap(body, Vector3(0.3 * side, 1.67, 0.0), 0.25)

