extends "res://tools/creature_kit.gd"
## The Sunken Sentinel of the Sunspire Dunes, sculpted by hand: a carved sandstone temple
## guardian, half swallowed by the dunes and woken again, its gilding cracked and flaking, its
## joints glowing as it readies a spear thrust. Built like the guardian statues of an ancient
## desert temple: a pleated kilt and belt, a broad beaded collar, gilded bracers and sandals,
## and a long bronze-bladed spear. Three designs:
##   pharaoh - a royal guardian in a striped headdress with lappets, a false beard and a tall
##             shield carved with an eye
##   lion    - a lion-headed warden with a carved stone mane and a heavy war-spear
##   sunken  - an older guardian worn by centuries of sand: its face scoured almost smooth,
##             deep cracks, linen wrappings hanging in rags, sand drifted up its legs and a
##             broken spear whose stump still blazes

const SANDSTONE := Color("#c9a978")
const SANDSTONE_DARK := Color("#8f7350")
const GOLD := Color("#d8ad48")
const LAPIS := Color("#2f4d8a")
const TURQUOISE := Color("#3fb8a8")
const BRONZE := Color("#9a6a36")
const LIGHT := Color("#5ff0e0")

var style := "pharaoh"


func _init() -> void:
	super("res://assets/cast/stone_detail_mid.png")
	material.uv1_scale = Vector3(2.6, 2.6, 2.6)
	material.roughness = 0.9
	glow.albedo_color = LIGHT.darkened(0.3); glow.emission = LIGHT; glow.emission_energy_multiplier = 1.4


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "SunkenSentinel"
	style = variant
	if not variant in ["pharaoh", "lion", "sunken"]: return null
	return _sentinel()


## Carved sandstone, cracked and weathered: darker in the crevices, with thin dark cracks and
## (for the sunken one) sand-scoured pale patches.
func stone() -> Callable:
	var worn := style == "sunken"
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := SANDSTONE.lerp(SANDSTONE_DARK, clampf(Sculpt.fbm(p * 9.0) * 0.45 + 0.2 - n.y * 0.15, 0.0, 1.0))
		var crack := absf(Sculpt.fbm(p * Vector3(3.0, 6.0, 3.0)) )
		c = c.darkened(smoothstep(0.035 if worn else 0.02, 0.0, crack) * 0.6)
		if worn: c = c.lerp(Color("#e6d2a6"), smoothstep(0.3, 0.55, Sculpt.noise(p * 5.0)) * 0.35)
		return c.lerp(Color("#d9c095"), smoothstep(0.75, 1.0, n.y) * 0.2)


## Gilding, worn through to the sandstone underneath in patches.
func gilt() -> Callable:
	var flaked := 0.7 if style == "sunken" else 0.35
	var base := stone()
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var g := GOLD.lerp(GOLD.darkened(0.35), clampf(-n.y * 0.4 + Sculpt.noise(p * 20.0) * 0.3 + 0.2, 0.0, 1.0)).lightened(smoothstep(0.6, 1.0, n.y) * 0.15)
		var chip := smoothstep(flaked - 0.1, flaked + 0.05, Sculpt.fbm(p * 7.0) + 0.5)
		return g.lerp(base.call(p, n, v, w), chip)


## Painted bands (lapis, gold, turquoise) for the collar and headdress stripes.
func bands(count: float, axis: Vector3) -> Callable:
	var g := gilt(); var worn := style == "sunken"
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var t := fposmod(p.dot(axis) * count, 1.0)
		var c: Color = g.call(p, n, v, w)
		if t > 0.5: c = LAPIS.lerp(LAPIS.lightened(0.15), Sculpt.noise(p * 20.0) * 0.5 + 0.5).lerp(SANDSTONE, smoothstep(0.35, 0.6, Sculpt.fbm(p * 9.0) + (0.3 if worn else -0.2)))
		return c


func glow_ring(s: Sculpt, painter: int, center: Vector3, axis: Vector3, radius: float, thick: float) -> void:
	var a := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.UP).normalized(); var b := axis.cross(a).normalized()
	var pts: Array = []; var r: Array = []
	for k in range(13):
		var t := TAU * k / 12.0
		pts.append(center + (a * cos(t) + b * sin(t)) * radius); r.append(thick)
	s.tube(pts, r, painter, {"sides": 5, "per": 2, "cap_rings": 1})


func _sentinel() -> Node3D:
	var st := stone(); var gp := gilt()
	var worn := style == "sunken"
	var body := Sculpt.new(); var bp := body.add_painter(st); var bg := body.add_painter(gp)
	var collar := body.add_painter(bands(34.0, Vector3(0, -0.3, 0) + Vector3(0, 0, 0)))
	var lights := Sculpt.new(); var lw := lights.add_painter(func (p, n, v, w): return Color.WHITE)
	# Torso: a broad, idealised chest narrowing to the waist.
	body.tube([Vector3(0, 0.92, 0.0), Vector3(0, 1.1, -0.01), Vector3(0, 1.32, 0.0), Vector3(0, 1.47, 0.01)], [0.12, 0.12, 0.145, 0.13], bp, {"sides": 18, "per": 3, "flat": 1.55})
	for side in [-1.0, 1.0]:
		# Carved chest muscles and the curve of the shoulder.
		body.blob(Vector3(0.09 * side, 1.33, -0.09), Vector3(0.1, 0.07, 0.06), bp, {"lat": 5, "lon": 9})
		body.blob(Vector3(0.22 * side, 1.44, 0.0), Vector3(0.09, 0.08, 0.09), bp, {"lat": 5, "lon": 8})
	for row in range(3):
		for side in [-1.0, 1.0]: body.blob(Vector3(0.045 * side, 1.18 - row * 0.075, -0.11), Vector3(0.04, 0.032, 0.02), bp, {"lat": 3, "lon": 6})
	body.tube([Vector3(0, 1.46, 0.0), Vector3(0, 1.62, 0.0)], [0.065, 0.058], bp, {"sides": 12, "per": 2})
	# The broad collar: rows of painted beads over the shoulders and chest.
	body.lathe(Vector3(0, 1.5, 0.0), [Vector2(0.07, 0.03), Vector2(0.18, 0.0), Vector2(0.26, -0.06), Vector2(0.27, -0.09), Vector2(0.2, -0.06), Vector2(0.07, 0.0)], collar, {"sides": 22, "basis": Basis.from_scale(Vector3(1.05, 1, 0.62))})
	# Belt and pleated kilt with a stiff front apron.
	body.tube([Vector3(0, 0.94, 0.0), Vector3(0, 0.99, 0.0)], [0.125, 0.125], bg, {"sides": 18, "per": 1, "flat": 1.55, "cap_rings": 1})
	body.lathe(Vector3(0, 0.94, 0.0), [Vector2(0.17, 0.02), Vector2(0.2, -0.12), Vector2(0.24, -0.3), Vector2(0.245, -0.33), Vector2(0.0, -0.32)], bp, {"sides": 24, "basis": Basis.from_scale(Vector3(1.15, 1, 0.75))})
	for k in range(12):
		var a := lerpf(-1.1, 1.1, k / 11.0)
		body.tube([Vector3(sin(a) * 0.19, 0.92, -cos(a) * 0.13), Vector3(sin(a) * 0.28, 0.63, -cos(a) * 0.185)], [0.01, 0.01], bp, {"sides": 4, "per": 1, "cap_rings": 1})
	slab(body, bg, Vector3(0, 0.78, -0.19), Vector3(0.15, 0.3, 0.03), Basis(Vector3.RIGHT, 0.12), 0.4, 0.0)
	# A glowing seam down the middle of the chest, where the guardian's light shows through.
	lights.tube([Vector3(0, 1.26, -0.128), Vector3(0, 1.06, -0.122)], [0.01, 0.008], lw, {"sides": 5, "per": 1, "cap_rings": 1})
	if worn:
		# Linen wrappings hanging in rags from the waist and shoulders.
		var rag := body.add_painter(func (p, n, v, w): return Color("#cbbb98").darkened(v * 0.3 + Sculpt.noise(p * 12.0) * 0.15))
		for k in range(9):
			var a := lerpf(-2.6, 2.6, k / 8.0) + 0.2 * sin(k * 3.1)
			var top := Vector3(sin(a) * 0.22, 0.9, -cos(a) * 0.16)
			body.tube([top, top + Vector3(sin(a) * 0.05, -0.2, -cos(a) * 0.03), top + Vector3(sin(a) * 0.06 + 0.02, -0.38 - 0.1 * (k % 3), -cos(a) * 0.02)], [0.04, 0.035, 0.012], rag, {"sides": 5, "per": 2, "flat": 0.3, "side": Vector3(sin(a), 0, -cos(a)), "cap1": false})
		for side in [-1.0, 1.0]:
			body.tube([Vector3(0.16 * side, 1.47, -0.1), Vector3(0.05 * side, 1.25, -0.14), Vector3(-0.1 * side, 1.0, -0.13)], [0.03, 0.035, 0.03], rag, {"sides": 5, "per": 3, "flat": 0.35, "side": Vector3(0, 0, -1)})
	part(root, "Body", body)
	var core := part(root, "Light", lights, glow)
	core.material_override = glow

	# ---- head
	var head := joint(root, "Head", Vector3(0, 1.64, 0.0))
	var hs := Sculpt.new(); var hp := hs.add_painter(st); var hg := hs.add_painter(gp)
	var stripes := hs.add_painter(bands(48.0, Vector3(0, -1, 0)))
	var eyes: Array = []
	match style:
		"pharaoh":
			# A serene carved face under the striped nemes headdress, with lappets falling in
			# front of the shoulders, a cobra on the brow and a long false beard.
			hs.blob(Vector3(0, 1.77, -0.01), Vector3(0.095, 0.125, 0.105), hp, {"lat": 8, "lon": 12})
			hs.tube([Vector3(0, 1.8, -0.11), Vector3(0, 1.76, -0.135)], [0.018, 0.014], hp, {"sides": 6, "per": 1})
			hs.blob(Vector3(0, 1.71, -0.105), Vector3(0.04, 0.012, 0.012), hs.add_painter(func (p, n, v, w): return SANDSTONE_DARK.darkened(0.3)), {"lat": 3, "lon": 6})
			hs.tube([Vector3(0, 1.67, -0.1), Vector3(0, 1.58, -0.11), Vector3(0, 1.52, -0.09)], [0.03, 0.028, 0.024], hg, {"sides": 8, "per": 2, "bands": 4, "band": 0.15})
			hs.lathe(Vector3(0, 1.84, 0.025), [Vector2(0.0, 0.085), Vector2(0.09, 0.065), Vector2(0.125, 0.0), Vector2(0.14, -0.09), Vector2(0.135, -0.14)], stripes, {"sides": 20, "basis": Basis.from_scale(Vector3(1.2, 1, 1.0))})
			for side in [-1.0, 1.0]:
				hs.tube([Vector3(0.125 * side, 1.76, -0.02), Vector3(0.155 * side, 1.6, -0.05), Vector3(0.15 * side, 1.44, -0.08)], [0.05, 0.055, 0.05], stripes, {"sides": 8, "per": 2, "flat": 0.35, "side": Vector3(side, 0, 0), "cap_len": 0.2})
				hs.blob(Vector3(0.045 * side, 1.79, -0.11), Vector3(0.03, 0.009, 0.012), hp, {"lat": 3, "lon": 6})
			hs.tube([Vector3(0, 1.9, -0.11), Vector3(0, 1.95, -0.15), Vector3(0, 1.98, -0.13)], [0.016, 0.02, 0.012], hg, {"sides": 6, "per": 2})
			hs.tube([Vector3(0, 1.88, 0.2), Vector3(0, 1.74, 0.22), Vector3(0, 1.62, 0.18)], [0.06, 0.05, 0.02], stripes, {"sides": 8, "per": 2, "cap1": false})
			eyes = [Vector3(-0.045, 1.785, -0.112), Vector3(0.045, 1.785, -0.112)]
		"lion":
			# A lion's head in carved stone: a heavy brow and muzzle, and a mane cut in rows
			# of stylised locks, gilded at the tips.
			hs.blob(Vector3(0, 1.8, 0.0), Vector3(0.14, 0.15, 0.14), hp, {"lat": 8, "lon": 12})
			hs.tube([Vector3(0, 1.79, -0.1), Vector3(0, 1.75, -0.2)], [0.08, 0.065], hp, {"sides": 12, "per": 2, "square": 0.4, "cap_len": 0.5})
			hs.blob(Vector3(0, 1.77, -0.255), Vector3(0.035, 0.025, 0.02), hs.add_painter(func (p, n, v, w): return SANDSTONE_DARK.darkened(0.4)), {"lat": 4, "lon": 6})
			for side in [-1.0, 1.0]:
				hs.blob(Vector3(0.06 * side, 1.86, -0.12), Vector3(0.05, 0.02, 0.04), hp, {"lat": 3, "lon": 7})
				hs.tube([Vector3(0.11 * side, 1.92, 0.0), Vector3(0.15 * side, 1.98, 0.02)], [0.035, 0.012], hp, {"sides": 6, "per": 1, "cap_rings": 1})
				hs.crystal(Vector3(0.035 * side, 1.72, -0.22), Vector3(0, -1, -0.1), 0.05, 0.012, hs.add_painter(func (p, n, v, w): return Color("#efe3c3")), 4)
			for ring in range(3):
				var count := 12 + ring * 3
				for k in range(count):
					var a := TAU * k / count
					if sin(a) < -0.35 and ring == 0: continue
					var dir := Vector3(cos(a), sin(a) * 0.9, 0)
					var base := Vector3(0, 1.8, 0.02 + ring * 0.05) + dir * (0.15 + ring * 0.035)
					hs.tube([base, base + dir * 0.07 + Vector3(0, -0.02, 0.05), base + dir * 0.13 + Vector3(0, -0.06, 0.08)], [0.035, 0.03, 0.01], hg if ring == 2 else hp, {"sides": 5, "per": 2, "flat": 0.6, "side": Vector3.BACK, "cap1": false})
			eyes = [Vector3(-0.058, 1.83, -0.13), Vector3(0.058, 1.83, -0.13)]
		"sunken":
			# A worn, almost faceless head: the features scoured away by sand, a cracked crown
			# band, and eye sockets that still burn.
			hs.blob(Vector3(0, 1.78, -0.01), Vector3(0.105, 0.13, 0.115), hp, {"lat": 8, "lon": 12, "lump": 0.15})
			hs.tube([Vector3(0, 1.88, 0.0), Vector3(0, 1.91, 0.0)], [0.115, 0.11], hg, {"sides": 16, "per": 1, "cap_rings": 1, "lump": 0.2})
			for side in [-1.0, 1.0]:
				hs.blob(Vector3(0.042 * side, 1.79, -0.1), Vector3(0.03, 0.02, 0.012), hs.add_painter(func (p, n, v, w): return Color("#2a2018")), {"lat": 3, "lon": 6})
			hs.blob(Vector3(0, 1.75, -0.12), Vector3(0.02, 0.03, 0.015), hp, {"lat": 3, "lon": 5})
			eyes = [Vector3(-0.042, 1.79, -0.118), Vector3(0.042, 1.79, -0.118)]
	part(head, "Head", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e, Vector3(0.022, 0.013, 0.008), ew, {"lat": 4, "lon": 7})
	part(head, "Eyes", es, glow).material_override = glow

	# ---- arms: the right holds the spear, the left a shield (or nothing)
	var arms: Array = []; var forearms: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.27 * side, 1.43, 0))
		var us := Sculpt.new(); var up := us.add_painter(st); var ug := us.add_painter(gp)
		var ul := Sculpt.new(); var ulw := ul.add_painter(func (p, n, v, w): return Color.WHITE)
		us.blob(Vector3(0.28 * side, 1.43, 0.0), Vector3(0.08, 0.08, 0.08), up, {"lat": 6, "lon": 9})
		us.tube([Vector3(0.3 * side, 1.41, 0.0), Vector3(0.33 * side, 1.24, 0.0), Vector3(0.35 * side, 1.1, 0.01)], [0.068, 0.06, 0.05], up, {"sides": 12, "per": 3})
		us.tube([Vector3(0.315 * side, 1.33, 0.0), Vector3(0.32 * side, 1.29, 0.0)], [0.068, 0.068], ug, {"sides": 12, "per": 1, "cap_rings": 1})
		glow_ring(ul, ulw, Vector3(0.35 * side, 1.08, 0.01), Vector3(0, 1, 0), 0.054, 0.011)
		part(shoulder, "UpperArm", us)
		part(shoulder, "ElbowLight", ul, glow).material_override = glow
		var elbow := joint(shoulder, "Forearm", Vector3(0.35 * side, 1.08, 0.01))
		var fs := Sculpt.new(); var fp := fs.add_painter(st); var fg := fs.add_painter(gp)
		fs.tube([Vector3(0.35 * side, 1.07, 0.0), Vector3(0.37 * side, 0.92, -0.04), Vector3(0.38 * side, 0.8, -0.08)], [0.052, 0.048, 0.04], fp, {"sides": 12, "per": 3})
		# Gilded bracer and a clenched fist.
		fs.tube([Vector3(0.37 * side, 0.94, -0.03), Vector3(0.38 * side, 0.84, -0.07)], [0.055, 0.05], fg, {"sides": 12, "per": 1, "cap_rings": 1, "bands": 2, "band": 0.12})
		fs.blob(Vector3(0.385 * side, 0.75, -0.1), Vector3(0.045, 0.055, 0.05), fp, {"lat": 6, "lon": 8})
		part(elbow, "Forearm", fs)
		if side > 0.0: _spear(elbow, Vector3(0.385, 0.75, -0.1))
		elif style == "pharaoh": _shield(elbow, Vector3(-0.47, 0.95, -0.12))
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs, with glowing knees, gilded sandals and (for the sunken one) drifted sand
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.12 * side, 0.7, 0.0))
		var ts := Sculpt.new(); var tp := ts.add_painter(st)
		ts.tube([Vector3(0.12 * side, 0.8, 0.0), Vector3(0.13 * side, 0.56, -0.01), Vector3(0.13 * side, 0.42, 0.0)], [0.088, 0.075, 0.062], tp, {"sides": 12, "per": 3})
		var kl := Sculpt.new(); var klw := kl.add_painter(func (p, n, v, w): return Color.WHITE)
		glow_ring(kl, klw, Vector3(0.13 * side, 0.4, 0.0), Vector3(0, 1, 0), 0.066, 0.012)
		part(hip, "Thigh", ts)
		part(hip, "KneeLight", kl, glow).material_override = glow
		var knee := joint(hip, "Knee", Vector3(0.13 * side, 0.4, 0.0))
		var ss := Sculpt.new(); var sp := ss.add_painter(st); var sg := ss.add_painter(gp)
		ss.tube([Vector3(0.13 * side, 0.4, 0.0), Vector3(0.13 * side, 0.2, 0.01), Vector3(0.13 * side, 0.07, 0.0)], [0.06, 0.052, 0.042], sp, {"sides": 12, "per": 3})
		slab(ss, sp, Vector3(0.13 * side, 0.035, -0.06), Vector3(0.1, 0.065, 0.24), Basis.IDENTITY, 0.5, 0.0)
		slab(ss, sg, Vector3(0.13 * side, 0.01, -0.06), Vector3(0.12, 0.022, 0.26), Basis.IDENTITY, 0.4, 0.0)
		ss.tube([Vector3(0.085 * side, 0.06, -0.12), Vector3(0.13 * side, 0.08, -0.03), Vector3(0.175 * side, 0.06, -0.12)], [0.012, 0.012, 0.012], sg, {"sides": 5, "per": 2, "cap_rings": 1})
		if worn:
			var sand := ss.add_painter(func (p, n, v, w): return Color("#d8bf8a").darkened(Sculpt.noise(p * 10.0) * 0.1))
			ss.blob(Vector3(0.13 * side, 0.06, 0.0), Vector3(0.14, 0.09, 0.18), sand, {"lat": 6, "lon": 10, "lump": 0.25})
		part(knee, "Shin", ss)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.3)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node


## The spear: a long shaft held upright in the fist, a bronze leaf blade with a glowing ring
## at its socket. The sunken guardian's is snapped off, its broken end blazing.
func _spear(parent: Node3D, grip: Vector3) -> void:
	var s := Sculpt.new(); var shaft := s.add_painter(func (p, n, v, w): return Color("#6a4a2a").lerp(Color("#3a281a"), Sculpt.noise(p * 14.0) * 0.5 + 0.3))
	var blade := s.add_painter(func (p, n, v, w): return BRONZE.lerp(Color("#d9a85a"), clampf(n.y * 0.4 + 0.3, 0.0, 1.0)).lerp(Color("#3f6e5a"), smoothstep(0.35, 0.6, Sculpt.noise(p * 16.0)) * 0.5))
	var g := gilt()
	var gp := s.add_painter(g)
	var axis := Vector3(0, 1, -0.12).normalized()
	var l := Sculpt.new(); var lw := l.add_painter(func (p, n, v, w): return Color.WHITE)
	if style == "sunken":
		s.tube([grip - axis * 0.55, grip + axis * 0.75], [0.028, 0.026], shaft, {"sides": 8, "per": 1, "cap_rings": 1})
		for k in range(5):
			var a := TAU * k / 5.0
			s.crystal(grip + axis * 0.77, axis + Vector3(cos(a), 0, sin(a)) * 0.5, 0.06, 0.012, shaft, 3)
		l.blob(grip + axis * 0.79, Vector3.ONE * 0.035, lw, {"lat": 4, "lon": 6})
		l.tube([grip + axis * 0.6, grip + axis * 0.7], [0.034, 0.034], lw, {"sides": 8, "per": 1, "cap_rings": 1})
	else:
		var length := 1.55 if style == "pharaoh" else 1.45
		s.tube([grip - axis * 0.5, grip + axis * length], [0.026, 0.024], shaft, {"sides": 8, "per": 1, "cap_rings": 1})
		s.tube([grip + axis * (length - 0.02), grip + axis * (length + 0.08)], [0.034, 0.03], gp, {"sides": 8, "per": 1, "cap_rings": 1})
		var tip := grip + axis * (length + 0.08)
		var wide := 0.07 if style == "pharaoh" else 0.095
		s.tube([tip, tip + axis * 0.12, tip + axis * 0.32, tip + axis * 0.42], [wide * 0.6, wide, wide * 0.5, 0.002], blade, {"sides": 8, "per": 2, "flat": 0.18, "side": Vector3(0, 0, 1), "cap0": false})
		glow_ring(l, lw, grip + axis * (length + 0.03), axis, 0.04, 0.009)
		s.tube([grip - axis * 0.5, grip - axis * 0.58], [0.03, 0.01], gp, {"sides": 8, "per": 1})
	part(parent, "Spear", s)
	part(parent, "SpearLight", l, glow).material_override = glow


## A tall shield with a rounded top, carved with a great eye and edged in gilding.
func _shield(parent: Node3D, at: Vector3) -> void:
	var s := Sculpt.new(); var sp := s.add_painter(stone()); var sg := s.add_painter(gilt()); var dark := s.add_painter(func (p, n, v, w): return LAPIS.darkened(0.2))
	var face := Basis(Vector3.UP, 0.35)
	var flat := face * Basis(Vector3.RIGHT, -PI * 0.5)
	slab(s, sg, at, Vector3(0.44, 0.05, 0.78), flat, 0.7, 0.0)
	slab(s, sp, at + face * Vector3(0, 0, -0.022), Vector3(0.38, 0.04, 0.72), flat, 0.6, 0.0)
	var c := at + face * Vector3(0, 0.12, -0.045)
	s.blob(c, Vector3(0.1, 0.045, 0.012), sg, {"lat": 4, "lon": 10, "basis": face})
	s.blob(c + face * Vector3(0, 0, -0.006), Vector3(0.035, 0.035, 0.01), dark, {"lat": 4, "lon": 8, "basis": face})
	s.tube([c + face * Vector3(-0.02, -0.04, -0.004), c + face * Vector3(-0.03, -0.12, -0.004), c + face * Vector3(0.02, -0.17, -0.004)], [0.012, 0.012, 0.01], sg, {"sides": 5, "per": 2, "cap_rings": 1})
	part(parent, "Shield", s)
