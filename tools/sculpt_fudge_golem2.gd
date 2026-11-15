extends "res://tools/creature_kit.gd"
## Fudge Golem, second round of designs: a chocolate-armoured knight, a candy-bar ogre and a
## molten fudge ooze. All keep the hook: chunky cocoa plates, soft caramel joints, a slow
## sticky slam telegraphed by a wobble.

const DARK_CHOC := Color("#2c170e")
const DARK_CHOC_HI := Color("#4f2c1b")
const MILK_CHOC := Color("#55301d")
const MILK_CHOC_HI := Color("#70412a")
const WHITE_CHOC := Color("#f0e2c4")
const CARAMEL := Color("#e0a040")
const CARAMEL_GLOW := Color("#ffb648")
const NOUGAT := Color("#efe0c2")
const PEANUT := Color("#c08a4e")
const FUDGE_HOT := Color("#4a2516")
const COCOA_CRUST := Color("#7a5236")

var candy: StandardMaterial3D
var caramel_glow: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	material.roughness = 0.6
	candy = StandardMaterial3D.new()
	candy.vertex_color_use_as_albedo = true
	candy.vertex_color_is_srgb = true
	candy.roughness = 0.2
	candy.metallic_specular = 0.75
	glow.albedo_color = CARAMEL_GLOW.darkened(0.15); glow.emission = CARAMEL_GLOW
	glow.emission_energy_multiplier = 0.9
	caramel_glow = glow.duplicate()
	caramel_glow.emission_energy_multiplier = 0.55


static func dark_choc(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return DARK_CHOC.lerp(DARK_CHOC_HI, clampf(0.25 + n.y * 0.45, 0.0, 1.0))


static func milk_choc(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return MILK_CHOC.lerp(MILK_CHOC_HI, clampf(0.3 + n.y * 0.4 + Sculpt.noise(p * 5.0) * 0.15, 0.0, 1.0))


static func white_choc(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return WHITE_CHOC.darkened(clampf(-n.y, 0.0, 1.0) * 0.25)


static func hot_fudge(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return FUDGE_HOT.lerp(FUDGE_HOT.lightened(0.25), clampf(0.2 + n.y * 0.5, 0.0, 1.0))


static func crust(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := COCOA_CRUST.lerp(COCOA_CRUST.lightened(0.15), clampf(Sculpt.fbm(p * 8.0) * 0.6 + 0.3, 0.0, 1.0))
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.4)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "FudgeGolem"
	match variant:
		"knight": return _knight()
		"ogre": return _ogre()
		"ooze": return _ooze()
	return null


func _with_visual(node: Node3D, head: Node3D) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node


## A glowing caramel ball for a joint.
func caramel_joint(parent: Node3D, at: Vector3, size: float) -> void:
	var s := Sculpt.new(); var w := s.add_painter(func (p, n, v, w): return Color.WHITE)
	s.blob(at, Vector3.ONE * size, w, {"lat": 6, "lon": 9, "lump": 0.12})
	var m := part(parent, "CaramelJoint", s, caramel_glow); m.material_override = caramel_glow


## A: tall and upright in glossy dark-chocolate armour with white-chocolate trim; molten
## caramel glows at every joint and through the visor, and a caramel heart glows in the chest.
func _knight() -> Node3D:
	var body := Sculpt.new(); var dp := body.add_painter(dark_choc); var wp := body.add_painter(white_choc); var mp := body.add_painter(milk_choc)
	body.tube([Vector3(0, 0.66, 0.02), Vector3(0, 0.92, 0.02), Vector3(0, 1.2, 0.0), Vector3(0, 1.48, 0.0), Vector3(0, 1.62, 0.0)], [0.27, 0.28, 0.36, 0.4, 0.28], mp, {"sides": 16, "per": 3, "flat": 1.15})
	# Breastplate with a white trim ring and a ridge down the middle.
	body.tube([Vector3(0, 1.0, 0.0), Vector3(0, 1.3, -0.02), Vector3(0, 1.56, 0.0)], [0.36, 0.42, 0.36], dp, {"sides": 16, "per": 3, "flat": 1.15, "cap_len": 0.2, "bands": 3, "band": 0.04})
	var belt: Array = []; var belt_r: Array = []
	for k in range(15):
		var ang := TAU * k / 13.0
		belt.append(Vector3(cos(ang) * 0.36, 0.98, sin(ang) * 0.32)); belt_r.append(0.04)
	body.tube(belt, belt_r, wp, {"sides": 7, "per": 2})
	# A tasset skirt of chocolate plates.
	for k in range(6):
		var ang := -PI * 0.5 + (k - 2.5) * 0.42
		var at := Vector3(cos(ang) * 0.33, 0.78, sin(ang) * 0.3)
		slab(body, dp, at, Vector3(0.2, 0.26, 0.05), Basis(Vector3.UP, -ang - PI * 0.5) * Basis(Vector3.RIGHT, 0.2), 0.4, 0.0)
	# Chocolate-bar squares embossed on the breastplate, round the caramel heart.
	for row in range(2):
		for side in [-1.0, 1.0]:
			slab(body, dp, Vector3(0.14 * side, 1.42 - row * 0.2, -0.44 + row * 0.01), Vector3(0.16, 0.05, 0.15), Basis(Vector3.RIGHT, -0.1 - PI * 0.5), 0.5, 0.0)
	part(root, "Body", body, candy)
	var hs := Sculpt.new(); var hw := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	hs.rock(Vector3(0, 1.32, -0.47), Vector3(0.08, 0.1, 0.04), hw, {"lat": 4, "lon": 6, "lump": 0.0})
	var core := part(root, "CaramelHeart", hs, glow)
	core.material_override = glow

	var head := joint(root, "Head", Vector3(0, 1.79, -0.045))
	var helm := Sculpt.new(); var hd := helm.add_painter(dark_choc); var hwp := helm.add_painter(white_choc)
	helm.tube([Vector3(0, 1.66, -0.04), Vector3(0, 1.86, -0.05), Vector3(0, 2.0, -0.04)], [0.19, 0.21, 0.18], hd, {"sides": 16, "per": 3, "square": 0.3, "cap_len": 0.5})
	helm.tube([Vector3(0, 1.98, 0.18), Vector3(0, 2.12, 0.0), Vector3(0, 2.06, -0.2)], [0.03, 0.05, 0.03], hwp, {"sides": 8, "per": 3, "flat": 0.4, "cap_rings": 2})
	for side in [-1.0, 1.0]:
		helm.tube([Vector3(0.15 * side, 1.9, -0.06), Vector3(0.3 * side, 1.96, -0.02), Vector3(0.38 * side, 2.1, 0.02), Vector3(0.36 * side, 2.26, 0.08)], [0.06, 0.05, 0.035, 0.004], hwp, {"sides": 8, "per": 3, "cap1": false})
	helm.tube([Vector3(-0.17, 1.92, -0.21), Vector3(0, 1.95, -0.27), Vector3(0.17, 1.92, -0.21)], [0.03, 0.035, 0.03], hwp, {"sides": 7, "per": 3, "cap_rings": 2})
	part(head, "Helm", helm, candy)
	var vs := Sculpt.new(); var vw := vs.add_painter(func (p, n, v, w): return Color.WHITE)
	vs.tube([Vector3(-0.13, 1.86, -0.225), Vector3(0, 1.85, -0.262), Vector3(0.13, 1.86, -0.225)], [0.02, 0.024, 0.02], vw, {"sides": 6, "per": 3, "cap_rings": 1})
	var visor := part(head, "VisorGlow", vs, caramel_glow); visor.material_override = caramel_glow

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.44 * side, 1.44, 0))
		var us := Sculpt.new(); var up := us.add_painter(milk_choc); var ud := us.add_painter(dark_choc); var uw := us.add_painter(white_choc)
		us.tube([Vector3(0.44 * side, 1.46, 0.0), Vector3(0.5 * side, 1.25, 0.0), Vector3(0.52 * side, 1.1, 0.0)], [0.12, 0.115, 0.11], up, {"sides": 12, "per": 3})
		us.lathe(Vector3(0.47 * side, 1.56, 0.0), [Vector2(0, 0.14), Vector2(0.14, 0.12), Vector2(0.22, 0.04), Vector2(0.25, -0.06), Vector2(0.2, -0.08), Vector2(0, -0.04)], ud, {"sides": 16, "basis": Basis(Vector3.BACK, -0.25 * side)})
		us.tube([Vector3(0.28 * side, 1.5, 0.12), Vector3(0.47 * side, 1.47, 0.24), Vector3(0.66 * side, 1.5, 0.12)], [0.025, 0.025, 0.025], uw, {"sides": 6, "per": 3, "cap_rings": 1})
		part(shoulder, "Pauldron", us, candy)
		caramel_joint(shoulder, Vector3(0.5 * side, 1.07, 0.0), 0.1)
		var elbow := joint(shoulder, "Forearm", Vector3(0.52 * side, 1.04, -0.015))
		var fs := Sculpt.new(); var fd := fs.add_painter(dark_choc); var fm := fs.add_painter(milk_choc)
		fs.tube([Vector3(0.52 * side, 1.0, -0.02), Vector3(0.55 * side, 0.8, -0.04), Vector3(0.56 * side, 0.64, -0.05)], [0.12, 0.15, 0.14], fd, {"sides": 12, "per": 4, "bands": 2, "band": 0.05, "cap_len": 0.3})
		slab(fs, fm, Vector3(0.57 * side, 0.54, -0.07), Vector3(0.18, 0.16, 0.2), Basis.IDENTITY, 0.5, 0.0)
		for f in range(4): slab(fs, fd, Vector3((0.57 + (f - 1.5) * 0.045) * side, 0.44, -0.14), Vector3(0.04, 0.12, 0.06), Basis.IDENTITY, 0.6, 0.0)
		part(elbow, "Gauntlet", fs, candy)
		if side > 0.0: _sword(elbow, Vector3(0.57, 0.5, -0.12))
		else: _shield(elbow, Vector3(-0.72, 0.76, -0.1))
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.2 * side, 0.72, 0.025))
		var ts := Sculpt.new(); var tp := ts.add_painter(milk_choc)
		ts.tube([Vector3(0.2 * side, 0.78, 0.02), Vector3(0.2 * side, 0.42, 0.01)], [0.14, 0.12], tp, {"sides": 12, "per": 3})
		part(hip, "Thigh", ts, candy)
		var knee := joint(hip, "Knee", Vector3(0.2 * side, 0.38, 0.01))
		caramel_joint(knee, Vector3(0.2 * side, 0.4, -0.04), 0.09)
		var ss := Sculpt.new(); var sd := ss.add_painter(dark_choc)
		ss.tube([Vector3(0.2 * side, 0.38, 0.01), Vector3(0.2 * side, 0.12, 0.0)], [0.13, 0.13], sd, {"sides": 12, "per": 3, "bands": 2, "band": 0.05})
		slab(ss, sd, Vector3(0.2 * side, 0.06, -0.08), Vector3(0.22, 0.12, 0.38), Basis.IDENTITY, 0.5, 0.0)
		part(knee, "Greave", ss, candy)
		hips.append(hip); knees.append(knee)
	return _with_visual(_finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.3), head)


## A chocolate greatsword gripped in the fist at `grip`: a dark blade with a white-chocolate
## edge, a white crossguard and a glowing caramel pommel.
func _sword(parent: Node3D, grip: Vector3) -> void:
	var axis := Vector3(0.06, 0.72, -0.69).normalized()
	var s := Sculpt.new(); var dp := s.add_painter(dark_choc); var wp := s.add_painter(white_choc); var cp := s.add_painter(func (p, n, v, w): return CARAMEL)
	var face := Basis.looking_at(axis, Vector3.BACK)
	s.tube([grip - axis * 0.16, grip + axis * 0.12], [0.03, 0.03], dp, {"sides": 8, "per": 1})
	s.blob(grip - axis * 0.19, Vector3.ONE * 0.05, cp, {"lat": 5, "lon": 8})
	slab(s, wp, grip + axis * 0.15, Vector3(0.05, 0.32, 0.06), face, 0.5, 0.0)
	slab(s, wp, grip + axis * 0.6, Vector3(0.025, 0.23, 0.8), face, 0.3, 0.0)
	slab(s, dp, grip + axis * 0.58, Vector3(0.06, 0.17, 0.76), face, 0.3, 0.0)
	for k in range(3): slab(s, dp, grip + axis * (0.35 + k * 0.2) + face.x * 0.03, Vector3(0.03, 0.12, 0.15), face, 0.5, 0.0)
	s.crystal(grip + axis * 0.99, axis, 0.16, 0.11, wp, 4, PI * 0.25)
	part(parent, "ChocolateGreatsword", s, candy)


## A chocolate-bar shield on the forearm: dark squares in a white-chocolate rim.
func _shield(parent: Node3D, at: Vector3) -> void:
	var s := Sculpt.new(); var dp := s.add_painter(dark_choc); var wp := s.add_painter(white_choc); var mp := s.add_painter(milk_choc)
	var face := Basis(Vector3.UP, 0.45)
	var flat := face * Basis(Vector3.RIGHT, -PI * 0.5)
	slab(s, wp, at, Vector3(0.54, 0.06, 0.68), flat, 0.6, 0.0)
	slab(s, mp, at + face * Vector3(0, 0, -0.025), Vector3(0.46, 0.05, 0.6), flat, 0.5, 0.0)
	for row in range(3):
		for col in [-1.0, 1.0]:
			slab(s, dp, at + face * Vector3(0.105 * col, 0.185 - row * 0.185, -0.05), Vector3(0.17, 0.05, 0.15), flat, 0.6, 0.0)
	part(parent, "ChocolateBarShield", s, candy)


## B: a squat, hunched ogre of milk chocolate whose back is a broken-open candy bar: chocolate
## coat, a gold caramel layer and nougat studded with peanuts, with peanut tusks and huge fists.
func _ogre() -> Node3D:
	var layered := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var level := p.y - 1.0 + (p.z - 0.45) * 0.45
		if level < 0.12: return milk_choc(p, n, v, w).darkened(0.1)
		if level < 0.25: return NOUGAT.darkened(Sculpt.noise(p * 20.0) * 0.08)
		if level < 0.33: return CARAMEL.lightened(clampf(n.y, 0.0, 1.0) * 0.2)
		return dark_choc(p, n, v, w)
	var body := Sculpt.new(); var mp := body.add_painter(milk_choc); var lp := body.add_painter(layered); var pn := body.add_painter(func (p, n, v, w): return PEANUT.lerp(PEANUT.lightened(0.2), clampf(n.y, 0.0, 1.0)))
	body.tube([Vector3(0, 0.55, 0.12), Vector3(0, 0.82, 0.15), Vector3(0, 1.1, 0.08), Vector3(0, 1.3, -0.08), Vector3(0, 1.38, -0.24)], [0.36, 0.44, 0.5, 0.44, 0.3], mp, {"sides": 16, "per": 3, "flat": 1.2, "lump": 0.08})
	# The broken candy bar across the back: a thick slab with jagged ends.
	slab(body, lp, Vector3(0, 1.2, 0.5), Vector3(0.82, 0.5, 0.46), Basis(Vector3.RIGHT, -0.55), 0.25, 0.04, true)
	for side in [-1.0, 1.0]:
		for k in range(3):
			body.rock(Vector3(0.44 * side, 1.08 + k * 0.12, 0.5 + k * 0.06), Vector3(0.08, 0.09, 0.11), lp, {"lat": 4, "lon": 6, "lump": 0.4})
	for k in range(10):
		var at := Vector3(-0.32 + fposmod(k * 0.37, 0.64), 1.3 + fposmod(k * 0.23, 0.12), 0.72 + fposmod(k * 0.17, 0.05))
		body.blob(at, Vector3(0.04, 0.032, 0.055), pn, {"lat": 4, "lon": 7, "basis": Basis(Vector3.UP, k)})
	# Caramel stretching in strings from the broken bar.
	var cs := body.add_painter(func (p, n, v, w): return CARAMEL.lightened(clampf(n.y, 0.0, 1.0) * 0.25))
	for k in range(4):
		var a := Vector3(-0.3 + k * 0.2, 1.3 + (k % 2) * 0.05, 0.62)
		body.tube([a, a + Vector3(0.03, -0.14, 0.1), a + Vector3(0.0, -0.28, 0.06)], [0.016, 0.01, 0.014], cs, {"sides": 5, "per": 3, "cap_rings": 1})
	# A torn candy wrapper worn as a loincloth: red foil with a gold band.
	var foil := body.add_painter(func (p, n, v, w): return Color("#c4202a").lerp(Color("#e8b33a"), smoothstep(0.02, 0.0, absf(p.y - 0.6))).lightened(clampf(n.y, 0.0, 1.0) * 0.2 + absf(Sculpt.noise(p * 18.0)) * 0.2))
	var band: Array = []; var band_r: Array = []
	for k in range(15):
		var ang := TAU * k / 13.0
		band.append(Vector3(cos(ang) * 0.44, 0.62 + 0.02 * sin(ang * 5.0), 0.13 + sin(ang) * 0.37)); band_r.append(0.06)
	body.tube(band, band_r, foil, {"sides": 8, "per": 2, "flat": 0.5, "side": Vector3.UP, "lump": 0.3})
	var flap_foil := body.add_painter(func (p, n, v, w): return Color("#c4202a").lerp(Color("#e8b33a"), smoothstep(0.03, 0.015, absf(p.y - 0.47))).lightened(clampf(-n.z, 0.0, 1.0) * 0.12 + absf(Sculpt.noise(p * 22.0)) * 0.25))
	for flap in [Vector3(0.0, 0.44, -0.27), Vector3(0.0, 0.46, 0.5)]:
		slab(body, flap_foil, flap, Vector3(0.36, 0.03, 0.3), Basis(Vector3.UP, 0.0 if flap.z < 0 else PI) * Basis(Vector3.RIGHT, -0.12 - PI * 0.5), 0.5, 0.35, true)
	# Crimped wrapper ends twisted at each hip.
	for side in [-1.0, 1.0]:
		var at := Vector3(0.44 * side, 0.6, 0.1)
		body.tube([at, at + Vector3(0.07 * side, -0.02, 0)], [0.05, 0.02], foil, {"sides": 6, "per": 1, "cap1": false})
		body.tube([at + Vector3(0.07 * side, -0.02, 0), at + Vector3(0.17 * side, -0.06, 0)], [0.02, 0.08], foil, {"sides": 6, "per": 2, "lump": 0.5, "facet": true})
	var ogre_mat := candy.duplicate(); ogre_mat.roughness = 0.55; ogre_mat.metallic_specular = 0.4
	part(root, "Body", body, ogre_mat)
	var hs := Sculpt.new(); var hw := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	hs.blob(Vector3(0, 1.05, -0.47), Vector3(0.08, 0.08, 0.03), hw, {"lat": 5, "lon": 8})
	var core := part(root, "CaramelHeart", hs, glow)
	core.material_override = glow

	var head := joint(root, "Head", Vector3(0, 1.3, -0.3))
	var hd := Sculpt.new(); var hm := hd.add_painter(milk_choc); var dark := hd.add_painter(func (p, n, v, w): return Color("#1a0c06")); var tusk := hd.add_painter(func (p, n, v, w): return PEANUT.lightened(0.15))
	hd.blob(Vector3(0, 1.32, -0.44), Vector3(0.2, 0.17, 0.18), hm, {"lat": 9, "lon": 13, "lump": 0.08})
	hd.blob(Vector3(0, 1.2, -0.5), Vector3(0.2, 0.08, 0.15), hm, {"lat": 6, "lon": 11})
	hd.tube([Vector3(-0.17, 1.41, -0.52), Vector3(0, 1.39, -0.6), Vector3(0.17, 1.41, -0.52)], [0.04, 0.05, 0.04], hm, {"sides": 8, "per": 3, "cap_rings": 2})
	for side in [-1.0, 1.0]:
		hd.tube([Vector3(0.12 * side, 1.2, -0.6), Vector3(0.14 * side, 1.29, -0.65), Vector3(0.12 * side, 1.36, -0.66)], [0.04, 0.025, 0.004], tusk, {"sides": 7, "per": 3, "cap1": false})
		hd.blob(Vector3(0.21 * side, 1.33, -0.42), Vector3(0.05, 0.07, 0.03), hm, {"lat": 5, "lon": 7, "basis": Basis(Vector3.UP, 0.5 * side)})
	hd.tube([Vector3(-0.09, 1.25, -0.62), Vector3(0, 1.235, -0.655), Vector3(0.09, 1.25, -0.62)], [0.014, 0.018, 0.014], dark, {"sides": 6, "per": 3, "cap_rings": 1})
	part(head, "Head", hd, ogre_mat)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.085 * side, 1.345, -0.6), Vector3(0.042, 0.03, 0.02), ew, {"lat": 4, "lon": 7})
	var eyes := part(head, "Eyes", es, caramel_glow); eyes.material_override = caramel_glow

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.5 * side, 1.28, -0.08))
		var us := Sculpt.new(); var up := us.add_painter(milk_choc)
		us.tube([Vector3(0.36 * side, 1.32, -0.06), Vector3(0.6 * side, 1.24, -0.08), Vector3(0.68 * side, 0.98, -0.1)], [0.2, 0.18, 0.15], up, {"sides": 12, "per": 3, "lump": 0.08})
		# A broken chunk of candy bar stuck on the shoulder, its layers showing.
		var chunk := us.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var level: float = p.y - 1.33
			if level < 0.05: return milk_choc(p, n, v, w).darkened(0.1)
			if level < 0.1: return NOUGAT.darkened(Sculpt.noise(p * 20.0) * 0.08)
			if level < 0.13: return CARAMEL.lightened(clampf(n.y, 0.0, 1.0) * 0.2)
			return dark_choc(p, n, v, w))
		slab(us, chunk, Vector3(0.52 * side, 1.43, -0.05), Vector3(0.36, 0.21, 0.32), Basis(Vector3.BACK, -0.3 * side) * Basis(Vector3.UP, 0.25 * side), 0.2, 0.06, true)
		part(shoulder, "UpperArm", us, ogre_mat)
		caramel_joint(shoulder, Vector3(0.68 * side, 0.97, -0.1), 0.12)
		var elbow := joint(shoulder, "Forearm", Vector3(0.68 * side, 0.96, -0.1))
		var fs := Sculpt.new(); var fp := fs.add_painter(milk_choc); var fd := fs.add_painter(dark_choc)
		fs.tube([Vector3(0.68 * side, 0.94, -0.1), Vector3(0.72 * side, 0.6, -0.15), Vector3(0.72 * side, 0.36, -0.18)], [0.15, 0.18, 0.17], fp, {"sides": 12, "per": 3, "lump": 0.08})
		fs.rock(Vector3(0.72 * side, 0.24, -0.2), Vector3(0.2, 0.17, 0.2), fd, {"lat": 5, "lon": 8, "lump": 0.2})
		part(elbow, "ChunkFist", fs, ogre_mat)
		arms.append(shoulder); forearms.append(elbow)
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.24 * side, 0.55, 0.12))
		var ts := Sculpt.new(); var tp := ts.add_painter(milk_choc)
		ts.tube([Vector3(0.23 * side, 0.65, 0.12), Vector3(0.26 * side, 0.32, 0.08)], [0.19, 0.17], tp, {"sides": 12, "per": 3, "lump": 0.08})
		part(hip, "Thigh", ts, ogre_mat)
		var knee := joint(hip, "Knee", Vector3(0.26 * side, 0.3, 0.07))
		caramel_joint(knee, Vector3(0.26 * side, 0.31, 0.02), 0.1)
		var ss := Sculpt.new(); var sp := ss.add_painter(milk_choc); var sd := ss.add_painter(dark_choc)
		ss.tube([Vector3(0.26 * side, 0.32, 0.07), Vector3(0.27 * side, 0.1, 0.03)], [0.16, 0.18], sp, {"sides": 12, "per": 3, "lump": 0.08})
		slab(ss, sd, Vector3(0.27 * side, 0.06, -0.06), Vector3(0.28, 0.12, 0.38), Basis.IDENTITY, 0.5, 0.03)
		part(knee, "Shin", ss, ogre_mat)
		hips.append(hip); knees.append(knee)
	return _with_visual(_finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.3), head)


## C: a slumped, melting giant of hot fudge, dripping everywhere and pooling at its feet, with
## crusts of hardened cocoa floating on it and two caramel eyes glowing out of the goo.
func _ooze() -> Node3D:
	var body := Sculpt.new(); var fp := body.add_painter(hot_fudge)
	body.lathe(Vector3(0, 0.0, 0.03), [Vector2(0, 1.78), Vector2(0.2, 1.74), Vector2(0.36, 1.58), Vector2(0.44, 1.3), Vector2(0.46, 0.95), Vector2(0.5, 0.6), Vector2(0.62, 0.25), Vector2(0.78, 0.08), Vector2(0.86, 0.03), Vector2(0.8, 0.0), Vector2(0, 0.0)], fp, {"sides": 18, "wobble": 0.3})
	var drip_spots: Array = []
	for k in range(14):
		var ang := TAU * k / 14.0 + 0.2
		var y := 1.0 + 0.55 * absf(sin(k * 1.7))
		var r := 0.45 if y < 1.3 else 0.4
		drip_spots.append(Vector3(cos(ang) * r, y, 0.03 + sin(ang) * r))
	for k in range(drip_spots.size()):
		var at: Vector3 = drip_spots[k]
		var out := Vector3(at.x, 0, at.z - 0.03).normalized()
		var l := 0.2 + 0.25 * absf(Sculpt.noise(at * 7.0))
		body.tube([at, at + out * 0.03 + Vector3(0, -l * 0.5, 0), at + out * 0.05 + Vector3(0, -l, 0)], [0.05, 0.045, 0.04], fp, {"sides": 7, "per": 2, "cap_rings": 2})
		body.blob(at + out * 0.05 + Vector3(0, -l - 0.02, 0), Vector3.ONE * 0.05, fp, {"lat": 4, "lon": 7})
	for k in range(9):
		var ang := k * 2.39996
		var y := 0.85 + fposmod(k * 0.29, 0.75)
		var r := 0.47 - (y - 0.85) * 0.12
		body.blob(Vector3(cos(ang) * r, y, 0.03 + sin(ang) * r), Vector3(0.05, 0.05, 0.05) * (0.6 + 0.4 * (k % 3)), fp, {"lat": 5, "lon": 7})
	part(root, "Body", body, candy)
	var cs := Sculpt.new(); var cp := cs.add_painter(crust)
	for k in range(7):
		var ang := k * 2.1 + 0.5
		var y := 0.9 + fposmod(k * 0.31, 0.75)
		var r := 0.47 - (y - 0.9) * 0.12
		var at := Vector3(cos(ang) * r, y, 0.03 + sin(ang) * r)
		cs.rock(at, Vector3(0.13, 0.04, 0.11), cp, {"lat": 4, "lon": 6, "lump": 0.3, "basis": Basis.looking_at(Vector3(at.x, 0, at.z).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)})
	cs.rock(Vector3(0, 1.74, 0.0), Vector3(0.2, 0.06, 0.18), cp, {"lat": 4, "lon": 7, "lump": 0.3})
	part(root, "CocoaCrusts", cs)
	var hs := Sculpt.new(); var hw := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	hs.blob(Vector3(0, 1.1, -0.45), Vector3(0.07, 0.07, 0.03), hw, {"lat": 5, "lon": 8})
	var core := part(root, "CaramelHeart", hs, glow)
	core.material_override = glow

	var head := joint(root, "Head", Vector3(0, 1.5, -0.2))
	var hd := Sculpt.new(); var hp := hd.add_painter(hot_fudge); var dark := hd.add_painter(func (p, n, v, w): return Color("#120804"))
	hd.blob(Vector3(0, 1.48, -0.34), Vector3(0.26, 0.2, 0.12), hp, {"lat": 8, "lon": 12, "lump": 0.15})
	hd.blob(Vector3(0, 1.36, -0.43), Vector3(0.14, 0.05, 0.04), dark, {"lat": 5, "lon": 9})
	drips(hd, hp, [Vector3(-0.1, 1.33, -0.44), Vector3(0.06, 1.32, -0.45), Vector3(0.14, 1.36, -0.42)], 0.12)
	part(head, "Face", hd, candy)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.1 * side, 1.52, -0.45), Vector3(0.04, 0.035, 0.02), ew, {"lat": 5, "lon": 8})
	var eyes := part(head, "Eyes", es, caramel_glow); eyes.material_override = caramel_glow

	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.42 * side, 1.4, 0.0))
		var us := Sculpt.new(); var up := us.add_painter(hot_fudge)
		us.tube([Vector3(0.3 * side, 1.44, 0.0), Vector3(0.56 * side, 1.3, -0.02), Vector3(0.64 * side, 1.02, -0.04)], [0.16, 0.14, 0.12], up, {"sides": 12, "per": 3, "lump": 0.15})
		part(shoulder, "UpperArm", us, candy)
		var elbow := joint(shoulder, "Forearm", Vector3(0.64 * side, 1.0, -0.04))
		var fs := Sculpt.new(); var fp2 := fs.add_painter(hot_fudge)
		fs.tube([Vector3(0.64 * side, 1.02, -0.04), Vector3(0.68 * side, 0.7, -0.08), Vector3(0.7 * side, 0.46, -0.1)], [0.12, 0.15, 0.17], fp2, {"sides": 12, "per": 3, "lump": 0.18})
		fs.blob(Vector3(0.7 * side, 0.4, -0.11), Vector3(0.17, 0.12, 0.16), fp2, {"lat": 6, "lon": 10, "lump": 0.2})
		drips(fs, fp2, [Vector3(0.62 * side, 0.34, -0.2), Vector3(0.72 * side, 0.32, -0.24), Vector3(0.8 * side, 0.34, -0.14)], 0.14)
		part(elbow, "MeltingHand", fs, candy)
		arms.append(shoulder); forearms.append(elbow)
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.24 * side, 0.55, 0.05))
		var ts := Sculpt.new(); var tp := ts.add_painter(hot_fudge)
		ts.tube([Vector3(0.24 * side, 0.6, 0.05), Vector3(0.26 * side, 0.32, 0.03)], [0.2, 0.19], tp, {"sides": 12, "per": 3, "lump": 0.15})
		part(hip, "Thigh", ts, candy)
		var knee := joint(hip, "Knee", Vector3(0.26 * side, 0.3, 0.03))
		var ss := Sculpt.new(); var sp := ss.add_painter(hot_fudge)
		ss.tube([Vector3(0.26 * side, 0.32, 0.03), Vector3(0.28 * side, 0.08, 0.0)], [0.19, 0.24], sp, {"sides": 12, "per": 3, "lump": 0.2})
		part(knee, "Shin", ss, candy)
		hips.append(hip); knees.append(knee)
	return _with_visual(_finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.3), head)


## Chocolate drips hanging from each spot, ending in a round drop.
func drips(s: Sculpt, painter: int, spots: Array, length: float) -> void:
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var l := length * (0.5 + 0.6 * absf(Sculpt.noise(at * 9.0 + Vector3(k, 0, 0))))
		var r := 0.03 + 0.012 * (k % 3)
		s.tube([at + Vector3(0, 0.02, 0), at + Vector3(0, -l * 0.6, 0), at + Vector3(0, -l, 0)], [r, r * 0.8, r * 0.75], painter, {"sides": 7, "per": 2, "cap_rings": 2})
		s.blob(at + Vector3(0, -l - r * 0.4, 0), Vector3.ONE * r * 1.25, painter, {"lat": 5, "lon": 7})
