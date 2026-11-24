extends "res://tools/creature_kit.gd"
## The Pale Watcher, boss of Hollowmourn's ruined abbey, sculpted by hand: a tall masked
## presence that floats above the broken floor; bells ring and the light dims before its gaze
## falls on you. Three designs, each built on real things from churches and abbeys:
##   veiled   - a funeral statue come alive, carved like the famous veiled marbles of Naples and
##              Venice (Sanmartino's Veiled Christ, the Veiled Virgin) where a thin marble veil
##              lies over a face you can still make out. A pale saint in deep-folded robes, a
##              halo hung with little bells, a handbell held by its handle in one hand
##   belfry   - the abbey's great bell come down from its tower: a cracked bronze church bell
##              green with verdigris for a lower body, its clapper a burning eye, and rising out
##              of its crown a gaunt hooded figure in a white Venetian "bauta" mask (the mask with
##              a jutting chin and no mouth), bell-ropes trailing from its wrists
##   wheels   - the ophanim of the Book of Ezekiel ("their rims were full of eyes round about"):
##              two great interlocking wheels covered in eyes turning round a serene white mask,
##              with six pale wings as Isaiah gives the seraphim (two over the face, two over the
##              feet, two to fly) and bells hung from the rims

const MARBLE := Color("#e8e4dc")
const BRONZE := Color("#6a4a2a")
const VERDIGRIS := Color("#5aa08a")

var kind := "veiled"
var veil_mat: StandardMaterial3D
var mist_mat: StandardMaterial3D
var bronze_mat: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/stone_detail_soft.png")
	material.uv1_scale = Vector3(2, 2, 2); material.roughness = 0.55
	veil_mat = StandardMaterial3D.new()
	veil_mat.vertex_color_use_as_albedo = true
	veil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED; veil_mat.roughness = 0.6
	mist_mat = StandardMaterial3D.new()
	mist_mat.vertex_color_use_as_albedo = true
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bronze_mat = StandardMaterial3D.new()
	bronze_mat.vertex_color_use_as_albedo = true
	bronze_mat.metallic = 0.55; bronze_mat.roughness = 0.45; bronze_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color("#e8f0ff").darkened(0.2); glow.emission = Color("#dfe8ff"); glow.emission_energy_multiplier = 2.2


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "PaleWatcher"
	kind = variant
	match variant:
		"veiled": return _veiled()
		"belfry": return _belfry()
		"wheels": return _wheels()
	return null


# ------------------------------------------------------------------ painters

## Pale marble, grey-veined, darker in the deep folds.
static func marble(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#b8b4ac").lerp(MARBLE, clampf(n.y * 0.25 + 0.6 + Sculpt.fbm(p * 4.0) * 0.2, 0.0, 1.0))
	var vein := smoothstep(0.03, 0.0, absf(Sculpt.fbm(p * 3.0 + Vector3(2, 0, 0)) - 0.5) * 0.6)
	c = c.lerp(Color("#8a8a90"), vein * 0.5)
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.25)


## Porcelain: white, faintly blue in the shadows, crazed with fine cracks.
static func porcelain(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#c8ccd8").lerp(Color("#f6f4f0"), clampf(n.y * 0.2 + 0.7 + n.z * -0.2, 0.0, 1.0))
	return c.darkened(smoothstep(0.92, 0.99, absf(sin(Sculpt.fbm(p * 7.0) * 40.0))) * 0.35)


## Bronze bell-metal, green with verdigris in streaks running down from the crown.
static func bell_bronze(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#3a2818").lerp(Color("#8a6a40"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(p * 6.0) * 0.3, 0.0, 1.0))
	var streak := smoothstep(0.5, 0.75, Sculpt.noise(Vector3(p.x * 9.0, p.y * 1.5, p.z * 9.0)))
	return c.lerp(VERDIGRIS, streak * 0.75)


static func robe(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := Color("#8e8a90").lerp(Color("#dedad6"), clampf(n.y * 0.2 + 0.55 + Sculpt.fbm(p * 5.0) * 0.25, 0.0, 1.0))
	c = c.darkened(clampf(-w, 0.0, 1.0) * 0.35)
	return c.lerp(Color("#5a5660"), smoothstep(0.85, 1.0, v) * 0.4)


static func dark_robe(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := Color("#16141a").lerp(Color("#4a4652"), clampf(n.y * 0.2 + 0.4 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))
	return c.darkened(clampf(-w, 0.0, 1.0) * 0.4)


static func mist(_p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return Color(0.86, 0.88, 0.95, clampf(0.2 - v * 0.18 + n.y * 0.03, 0.0, 1.0))


static func feather(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#b8b4b0").lerp(Color("#f4f2ee"), clampf(n.y * 0.3 + 0.55 + Sculpt.noise(p * 30.0) * 0.15, 0.0, 1.0))
	return c.lerp(Color("#d8c890"), smoothstep(0.85, 1.0, v) * 0.3)


static func gold(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#6a5024").lerp(Color("#e0c070"), clampf(n.y * 0.4 + 0.45 + Sculpt.noise(p * 18.0) * 0.2, 0.0, 1.0))


# ------------------------------------------------------------------ pieces

## A spot the gaze beam flies from.
func launch_point(parent: Node3D, at: Vector3) -> void:
	var lp := Node3D.new(); lp.name = "LaunchPoint"; parent.add_child(lp)
	lp.position = at - _world(parent)


func _rig(node: Node3D, head: Node3D, sway: Array) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [],
		"ears": [], "tails": [], "features": {&"smoke": sway.map(func (n): return node.get_path_to(n))}}
	node.set_meta("rig_bindings", rig)
	return node


## A small bell hanging mouth-down from `top`.
func small_bell(s: Sculpt, painter: int, top: Vector3, size: float) -> void:
	s.lathe(top + Vector3(0, -size, 0), [Vector2(size * 0.62, 0.0), Vector2(size * 0.56, size * 0.12), Vector2(size * 0.4, size * 0.4), Vector2(size * 0.36, size * 0.75), Vector2(size * 0.22, size * 0.95), Vector2(0.0, size)], painter, {"sides": 10})
	s.blob(top + Vector3(0, -size * 1.05, 0), Vector3.ONE * size * 0.15, painter, {"lat": 3, "lon": 5})


## A church bell's profile, from the lip up to the crown (radius, height).
static func bell_profile(r: float, h: float) -> Array:
	return [Vector2(r, 0.0), Vector2(r * 0.98, h * 0.04), Vector2(r * 0.86, h * 0.1), Vector2(r * 0.7, h * 0.26), Vector2(r * 0.62, h * 0.5), Vector2(r * 0.6, h * 0.72), Vector2(r * 0.55, h * 0.88), Vector2(r * 0.38, h * 0.97), Vector2(0.0, h)]


## A mask: an oval face with a straight brow and nose, hollow eyes and a pinched mouth (or, for
## the bauta, a jutting chin and no mouth at all). Built facing -z, centred on `c`.
func mask(s: Sculpt, face: int, dark: int, c: Vector3, k: float, bauta := false) -> Array:
	s.blob(c, Vector3(0.1, 0.13, 0.05) * k, face, {"lat": 10, "lon": 14})
	s.blob(c + Vector3(0, 0.035, -0.035) * k, Vector3(0.08, 0.04, 0.03) * k, face, {"lat": 6, "lon": 10})
	s.tube([c + Vector3(0, 0.03, -0.05) * k, c + Vector3(0, -0.035, -0.066) * k], [0.012 * k, 0.018 * k], face, {"sides": 6, "per": 2})
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		var e := c + Vector3(0.038 * side, 0.012, -0.045) * k
		s.blob(e, Vector3(0.024, 0.014, 0.012) * k, dark, {"lat": 4, "lon": 7})
		eyes.append(e + Vector3(0, 0, -0.006 * k))
	if bauta:
		# The bauta's chin juts out square, with no mouth beneath the nose.
		s.blob(c + Vector3(0, -0.08, -0.04) * k, Vector3(0.07, 0.05, 0.045) * k, face, {"lat": 6, "lon": 10})
		s.tube([c + Vector3(-0.055, -0.115, -0.07) * k, c + Vector3(0, -0.125, -0.085) * k, c + Vector3(0.055, -0.115, -0.07) * k], [0.02 * k, 0.024 * k, 0.02 * k], face, {"sides": 6, "per": 2})
	else:
		s.tube([c + Vector3(-0.02, -0.07, -0.045) * k, c + Vector3(0, -0.074, -0.05) * k, c + Vector3(0.02, -0.07, -0.045) * k], [0.004 * k, 0.005 * k, 0.004 * k], dark, {"sides": 4, "per": 2})
	return eyes


## A pale wing: a fan of long flight feathers over a row of shorter coverts.
func wing_fan(s: Sculpt, painter: int, root_at: Vector3, spread: Vector3, up: Vector3, length: float, count := 9, arc := 1.0, width := 0.085) -> void:
	var sp := spread.normalized(); var u := up.normalized(); var f := sp.cross(u).normalized()
	# Long flight feathers, broad and overlapping, then two rows of shorter coverts over them.
	for row in range(3):
		var n := count if row == 0 else count - 2 - row
		var lk: float = [1.0, 0.62, 0.36][row]
		for k in range(n):
			var t := k / float(maxi(n - 1, 1))
			var dir := (sp * cos(t * arc) + u * sin(t * arc)).normalized()
			var l := length * lk * (0.62 + 0.38 * sin(PI * (0.2 + t * 0.65)))
			var off := f * (0.012 * row)
			s.tube([root_at + off, root_at + dir * l * 0.5 + f * 0.02 + off, root_at + dir * l * 0.92 + off, root_at + dir * l + off], [width * 0.55, width, width * 0.75, 0.006], painter, {"sides": 6, "per": 2, "flat": 0.14, "side": f, "cap1": false})


## An eye on a wheel rim: a white ball, a dark iris looking along `look`, a pupil that glows.
func rim_eye(s: Sculpt, white: int, iris: int, gs: Sculpt, gp: int, c: Vector3, look: Vector3, r: float) -> void:
	s.blob(c, Vector3.ONE * r, white, {"lat": 6, "lon": 9})
	var l := look.normalized()
	s.blob(c + l * r * 0.72, Vector3.ONE * r * 0.55, iris, {"lat": 5, "lon": 8})
	gs.blob(c + l * r * 0.98, Vector3.ONE * r * 0.22, gp, {"lat": 4, "lon": 6})
	# Heavy lids above and below, so each one reads as an eye and not a bead.
	var side := l.cross(Vector3.UP).normalized()
	if side.length() < 0.5: side = Vector3.RIGHT
	var up := side.cross(l).normalized()
	for sgn: float in [-1.0, 1.0]:
		s.tube([c - side * r * 1.05 + up * sgn * r * 0.2, c + up * sgn * r * 0.95 + l * r * 0.35, c + side * r * 1.05 + up * sgn * r * 0.2], [r * 0.18, r * 0.3, r * 0.18], white, {"sides": 5, "per": 2})


# ------------------------------------------------------------------ A: the veiled saint

func _veiled() -> Node3D:
	var body := Sculpt.new(); var mp := body.add_painter(marble)
	# A tall robe in deep vertical folds, floating, its hem breaking up into mist.
	body.tube([Vector3(0, 2.0, 0.02), Vector3(0, 1.7, 0.03), Vector3(0, 1.25, 0.05), Vector3(0, 0.8, 0.08), Vector3(0, 0.45, 0.1)], [0.2, 0.3, 0.33, 0.38, 0.44], mp, {"sides": 36, "per": 4, "ridges": 11, "ridge": 0.09, "side": Vector3.BACK, "flat": 0.75, "cap1": false, "lump": 0.03})
	# Sleeves falling from the arms in long folds.
	for side: float in [-1.0, 1.0]:
		body.tube([Vector3(0.24 * side, 1.92, 0.0), Vector3(0.3 * side, 1.65, -0.02), Vector3(0.28 * side, 1.4, -0.12), Vector3(0.22 * side, 1.3, -0.2)], [0.08, 0.11, 0.15, 0.17], mp, {"sides": 18, "per": 3, "ridges": 6, "ridge": 0.12, "cap1": false})
	part(root, "Robe", body)
	# Folded marble wings rising behind it, as on a cemetery angel.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var wj := joint(root, ("Left" if side < 0 else "Right") + "Wing", Vector3(0.12 * side, 1.95, 0.2))
		var wsc := Sculpt.new(); var wpp := wsc.add_painter(marble)
		wing_fan(wsc, wpp, Vector3(0.12 * side, 1.95, 0.2), Vector3(0.3 * side, -0.85, 0.45), Vector3(0.15 * side, 1, 0.35), 1.3, 12, 1.25, 0.1)
		part(wj, "Wing", wsc)
		wings.append(wj)
	var ms := Sculpt.new(); var mip := ms.add_painter(mist)
	for k in range(16):
		var a := TAU * k / 16.0
		ms.tube([Vector3(sin(a) * 0.4, 0.52, cos(a) * 0.3 + 0.1), Vector3(sin(a) * 0.46, 0.3, cos(a) * 0.36 + 0.1), Vector3(sin(a) * 0.36 + 0.06 * sin(k), 0.1, cos(a) * 0.3 + 0.1)], [0.1, 0.07, 0.01], mip, {"sides": 8, "per": 3, "cap1": false, "lump": 0.3})
	part(root, "Mist", ms, mist_mat)
	# The face: a serene white mask under a thin marble veil you can just see through.
	var head := joint(root, "Head", Vector3(0, 2.05, 0.0))
	var hs := Sculpt.new(); var fp := hs.add_painter(marble); var dk := hs.add_painter(func (p, n, v, w): return Color("#0a0a10"))
	var eyes := mask(hs, fp, dk, Vector3(0, 2.18, -0.03), 1.15)
	part(head, "Mask", hs)
	var vs := Sculpt.new(); var vp := vs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: var c := marble(p, n, v, w); return Color(c.r, c.g, c.b, 0.5))
	vs.blob(Vector3(0, 2.2, 0.0), Vector3(0.16, 0.19, 0.15), vp, {"lat": 12, "lon": 16, "lump": 0.05})
	vs.tube([Vector3(0, 2.3, 0.04), Vector3(0, 2.0, 0.08), Vector3(0, 1.75, 0.1)], [0.15, 0.24, 0.3], vp, {"sides": 26, "per": 3, "ridges": 9, "ridge": 0.1, "cap0": false, "cap1": false})
	part(head, "Veil", vs, veil_mat)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e: Vector3 in eyes: es.blob(e, Vector3(0.018, 0.011, 0.008), ew, {"lat": 4, "lon": 6})
	var core := part(head, "Gaze", es, glow); core.material_override = glow
	launch_point(head, Vector3(0, 2.2, -0.3))
	# A halo of tarnished gold behind the head, little bells hanging all round it.
	var halo := joint(head, "Halo", Vector3(0, 2.22, 0.2))
	var hl := Sculpt.new(); var gp := hl.add_painter(gold)
	var ring: Array = []; var rr: Array = []
	for k in range(25):
		var a := TAU * k / 24.0
		ring.append(Vector3(sin(a) * 0.3, 2.22 + cos(a) * 0.3, 0.2)); rr.append(0.014)
	hl.tube(ring, rr, gp, {"sides": 6, "per": 1})
	for k in range(9):
		var a := lerpf(-2.4, 2.4, k / 8.0)
		var top := Vector3(sin(a) * 0.3, 2.22 + cos(a) * 0.3, 0.2)
		hl.tube([top, top + Vector3(0, -0.06, 0)], [0.004, 0.004], gp, {"sides": 4, "per": 1})
		small_bell(hl, gp, top + Vector3(0, -0.06, 0), 0.04)
	part(halo, "Halo", hl)
	# Arms: the right hand holds a handbell up by its handle; the left is raised, palm out.
	var arms: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := joint(root, ("Left" if side < 0 else "Right") + "Arm", Vector3(0.24 * side, 1.9, 0.0))
		var as_ := Sculpt.new(); var ap := as_.add_painter(marble)
		var wrist := Vector3(0.22 * side, 1.32, -0.22) if side > 0 else Vector3(-0.3, 1.62, -0.2)
		as_.tube([wrist + Vector3(0, 0.04, 0.04), wrist], [0.045, 0.04], ap, {"sides": 10, "per": 1})
		if side > 0:
			# Fist round the handle, the bell hanging below the little finger.
			var hc := wrist + Vector3(0, -0.02, -0.06)
			as_.blob(hc, Vector3(0.035, 0.045, 0.04), ap, {"lat": 6, "lon": 8})
			for f in range(4): as_.tube([hc + Vector3(0.03, 0.03 - f * 0.02, 0.0), hc + Vector3(0.0, 0.03 - f * 0.02, -0.035), hc + Vector3(-0.03, 0.03 - f * 0.02, -0.005)], [0.01, 0.011, 0.009], ap, {"sides": 5, "per": 1})
			var bs := Sculpt.new(); var bp := bs.add_painter(bell_bronze); var hd := bs.add_painter(func (p, n, v, w): return Color("#2a1a12"))
			bs.tube([hc + Vector3(0, 0.07, 0), hc + Vector3(0, -0.06, 0)], [0.012, 0.012], hd, {"sides": 6, "per": 1})
			bs.lathe(hc + Vector3(0, -0.24, 0), bell_profile(0.11, 0.18), bp, {"sides": 16})
			part(sh, "HandBell", bs, bronze_mat)
		else:
			var palm := wrist + Vector3(0, 0.06, -0.03)
			as_.blob(palm, Vector3(0.045, 0.06, 0.016), ap, {"lat": 6, "lon": 8, "basis": Basis(Vector3.UP, 0.3)})
			for f in range(4): as_.tube([palm + Vector3(-0.03 + f * 0.02, 0.05, 0), palm + Vector3(-0.035 + f * 0.022, 0.11 - absf(f - 1.5) * 0.01, -0.01)], [0.009, 0.007], ap, {"sides": 5, "per": 1})
			as_.tube([palm + Vector3(0.04, -0.01, 0), palm + Vector3(0.07, 0.03, -0.01)], [0.01, 0.008], ap, {"sides": 5, "per": 1})
		part(sh, "Hand", as_)
		arms.append(sh)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": [halo] + arms + wings}, 1.6)
	return _rig(node, head, [halo] + arms + wings)


# ------------------------------------------------------------------ B: the belfry wraith

func _belfry() -> Node3D:
	# The great bell: cracked bronze, mouth down, hanging in the air.
	var bell := joint(root, "Bell", Vector3(0, 1.15, 0))
	var bs := Sculpt.new(); var bp := bs.add_painter(bell_bronze); var crack := bs.add_painter(func (p, n, v, w): return Color.WHITE)
	bs.lathe(Vector3(0, 0.35, 0), bell_profile(0.55, 0.95), bp, {"sides": 32})
	# The lip's thick rim and the bands cast round the waist and shoulder.
	for yy: float in [0.37, 0.75, 1.05, 1.17]:
		var r: float = 0.55 if yy < 0.4 else (0.36 if yy < 0.8 else (0.335 if yy < 1.1 else 0.3))
		var ring: Array = []; var rr: Array = []
		for k in range(33):
			var a := TAU * k / 32.0
			ring.append(Vector3(sin(a) * r, yy, cos(a) * r)); rr.append(0.018)
		bs.tube(ring, rr, bp, {"sides": 5, "per": 1})
	part(bell, "Bell", bs, bronze_mat)
	# A crack up its side glowing from within.
	var cs := Sculpt.new(); var cp := cs.add_painter(func (p, n, v, w): return Color.WHITE)
	var cr: Array = []
	for k in range(9):
		var t := k / 8.0
		var r := lerpf(0.55, 0.34, smoothstep(0.0, 0.5, t))
		var a := -0.5 + 0.08 * sin(k * 2.3)
		cr.append(Vector3(sin(a) * (r + 0.004), 0.37 + t * 0.55, -cos(a) * (r + 0.004)))
	cs.tube(cr, [0.012, 0.01, 0.009, 0.008, 0.007, 0.006, 0.005, 0.004, 0.002], cp, {"sides": 4, "per": 1})
	# The clapper, a burning eye hanging in the bell's mouth.
	cs.blob(Vector3(0, 0.42, 0), Vector3.ONE * 0.09, cp, {"lat": 7, "lon": 10})
	var core := part(bell, "Crack", cs, glow); core.material_override = glow
	var ls := Sculpt.new(); var lp := ls.add_painter(func (p, n, v, w): return Color("#2a1a12"))
	ls.tube([Vector3(0, 1.2, 0), Vector3(0, 0.5, 0)], [0.025, 0.02], lp, {"sides": 6, "per": 1})
	part(bell, "ClapperRod", ls, bronze_mat)
	var light := OmniLight3D.new(); light.name = "ClapperLight"; light.light_color = Color("#dfe8ff"); light.light_energy = 1.4; light.omni_range = 3.0
	bell.add_child(light); light.position = Vector3(0, 0.42 - 1.15, 0)
	# Rising from the crown, a gaunt hooded figure in a dark habit.
	var body := Sculpt.new(); var rp := body.add_painter(dark_robe)
	body.tube([Vector3(0, 1.2, 0.0), Vector3(0, 1.45, 0.01), Vector3(0, 1.75, 0.02), Vector3(0, 1.95, 0.02)], [0.26, 0.18, 0.2, 0.17], rp, {"sides": 26, "per": 3, "ridges": 8, "ridge": 0.1, "side": Vector3.BACK, "flat": 0.75})
	part(root, "Habit", body)
	var head := joint(root, "Head", Vector3(0, 2.0, 0.0))
	var hs := Sculpt.new(); var hp := hs.add_painter(dark_robe); var fp := hs.add_painter(porcelain); var dk := hs.add_painter(func (p, n, v, w): return Color("#050407"))
	# A deep pointed cowl, its point falling behind.
	hs.blob(Vector3(0, 2.14, 0.03), Vector3(0.17, 0.2, 0.18), hp, {"lat": 10, "lon": 14, "lump": 0.08})
	hs.tube([Vector3(0, 2.28, 0.08), Vector3(0, 2.36, 0.2), Vector3(0, 2.3, 0.32)], [0.1, 0.05, 0.008], hp, {"sides": 8, "per": 2, "cap1": false})
	hs.blob(Vector3(0, 2.1, -0.08), Vector3(0.12, 0.15, 0.08), dk, {"lat": 7, "lon": 10})
	var eyes := mask(hs, fp, dk, Vector3(0, 2.12, -0.13), 1.05, true)
	part(head, "Cowl", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e: Vector3 in eyes: es.blob(e, Vector3(0.012, 0.008, 0.006), ew, {"lat": 4, "lon": 6})
	part(head, "Gaze", es, glow).material_override = glow
	launch_point(head, Vector3(0, 2.13, -0.4))
	# Long thin arms reaching forward, bell-ropes wound round the wrists and trailing down.
	var arms: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := joint(root, ("Left" if side < 0 else "Right") + "Arm", Vector3(0.18 * side, 1.86, 0.0))
		var as_ := Sculpt.new(); var ap := as_.add_painter(dark_robe); var bn := as_.add_painter(porcelain); var rope := as_.add_painter(func (p, n, v, w): return Color("#7a6648").lerp(Color("#3a2e22"), clampf(sin(v * 80.0) * 0.5 + 0.5, 0.0, 1.0)))
		var el := Vector3(0.32 * side, 1.62, -0.12); var wr := Vector3(0.3 * side, 1.5, -0.42)
		as_.tube([Vector3(0.18 * side, 1.86, 0.0), el, wr + Vector3(0, 0.02, 0.06)], [0.07, 0.08, 0.11], ap, {"sides": 14, "per": 3, "ridges": 5, "ridge": 0.12, "cap1": false})
		# Long porcelain fingers.
		for f in range(4):
			var b0 := wr + Vector3((f - 1.5) * 0.02, -0.01, 0.0)
			as_.tube([b0, b0 + Vector3((f - 1.5) * 0.012, -0.05, -0.07), b0 + Vector3((f - 1.5) * 0.015, -0.12, -0.1)], [0.01, 0.008, 0.004], bn, {"sides": 5, "per": 2, "cap1": false})
		var rp2: Array = []; var rr2: Array = []
		for k in range(12):
			var t := k / 11.0
			rp2.append(wr + Vector3(0.05 * sin(t * 7.0) * side, -t * 0.75, 0.12 * sin(t * PI) + 0.05 * cos(t * 9.0))); rr2.append(0.016)
		as_.tube(rp2, rr2, rope, {"sides": 6, "per": 2})
		part(sh, "Arm", as_)
		arms.append(sh)
	# Little bells on chains hanging round the bell's shoulder.
	var chimes: Array = []
	for k in range(6):
		var a := TAU * k / 6.0 + 0.3
		var top := Vector3(sin(a) * 0.36, 1.05, cos(a) * 0.36)
		var j := joint(root, "Chime%d" % k, top)
		var ch := Sculpt.new(); var chp := ch.add_painter(bell_bronze)
		ch.tube([top, top + Vector3(0, -0.2, 0)], [0.006, 0.006], chp, {"sides": 4, "per": 1})
		small_bell(ch, chp, top + Vector3(0, -0.2, 0), 0.06)
		part(j, "Chime", ch, bronze_mat)
		chimes.append(j)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": [bell] + chimes + arms}, 1.5)
	return _rig(node, head, [bell] + chimes + arms)


# ------------------------------------------------------------------ C: the wheels of eyes

func _wheels() -> Node3D:
	var head := joint(root, "Head", Vector3(0, 1.75, 0.0))
	var hs := Sculpt.new(); var fp := hs.add_painter(porcelain); var dk := hs.add_painter(func (p, n, v, w): return Color("#08060a"))
	var eyes := mask(hs, fp, dk, Vector3(0, 1.78, -0.04), 1.5)
	# A veil of pale cloth behind the mask.
	var cl := hs.add_painter(robe)
	hs.blob(Vector3(0, 1.82, 0.08), Vector3(0.19, 0.24, 0.14), cl, {"lat": 10, "lon": 14, "lump": 0.08})
	part(head, "Mask", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e: Vector3 in eyes: es.blob(e, Vector3(0.016, 0.01, 0.008), ew, {"lat": 4, "lon": 6})
	var core := part(head, "Gaze", es, glow); core.material_override = glow
	launch_point(head, Vector3(0, 1.8, -0.4))
	# Robes hanging from beneath the mask and trailing away into mist.
	var body := Sculpt.new(); var rp := body.add_painter(robe)
	var tops: Array = []
	for k in range(16):
		var a := TAU * k / 16.0
		var t := Vector3(sin(a) * 0.17, 1.6, cos(a) * 0.12 + 0.06)
		var o := Vector3(sin(a), 0, cos(a))
		var l := 1.0 + 0.35 * fposmod(k * 0.618, 1.0)
		body.tube([t, t + o * 0.08 + Vector3(0, -l * 0.4, 0), t + o * 0.14 + Vector3(0.03 * sin(k), -l * 0.8, 0), t + o * 0.1 + Vector3(0, -l, 0)], [0.07, 0.08, 0.06, 0.01], rp, {"sides": 7, "per": 3, "flat": 0.3, "side": o, "cap1": false})
	part(root, "Robes", body)
	# Two great wheels crossing round it, their rims full of eyes, bells hung from them.
	var wheels: Array = []
	for w in range(2):
		var c := Vector3(0, 1.75, 0.0)
		var j := joint(root, "Wheel%d" % w, c)
		var ws := Sculpt.new(); var gp := ws.add_painter(gold); var wp := ws.add_painter(func (p, n, v, ww): return Color("#f0ece4")); var ip := ws.add_painter(func (p, n, v, ww): return Color("#141018"))
		var gs := Sculpt.new(); var gg := gs.add_painter(func (p, n, v, ww): return Color.WHITE)
		var b := Basis(Vector3.UP, 0.55 if w == 0 else -0.55) * Basis(Vector3.RIGHT, 0.25 if w == 0 else -0.2)
		var r := 0.75 if w == 0 else 0.62
		var ring: Array = []; var rr: Array = []
		for k in range(41):
			var a := TAU * k / 40.0
			ring.append(c + b * Vector3(sin(a) * r, cos(a) * r, 0)); rr.append(0.045)
		ws.tube(ring, rr, gp, {"sides": 8, "per": 1})
		var ring2: Array = []; var rr2: Array = []
		for k in range(41):
			var a := TAU * k / 40.0
			ring2.append(c + b * Vector3(sin(a) * (r - 0.09), cos(a) * (r - 0.09), 0)); rr2.append(0.018)
		ws.tube(ring2, rr2, gp, {"sides": 6, "per": 1})
		var count := 14 if w == 0 else 11
		for k in range(count):
			var a := TAU * (k + 0.5) / count
			var at := c + b * Vector3(sin(a) * (r - 0.045), cos(a) * (r - 0.045), 0)
			var look := (b * Vector3(0, 0, -1) + (at - c).normalized() * 0.4).normalized()
			rim_eye(ws, wp, ip, gs, gg, at + b * Vector3(0, 0, -0.03), look, 0.05)
		for k in range(4):
			var a := TAU * k / 4.0 + 0.4
			var top := c + b * Vector3(sin(a) * r, cos(a) * r, 0)
			ws.tube([top, top + Vector3(0, -0.12, 0)], [0.005, 0.005], gp, {"sides": 4, "per": 1})
			small_bell(ws, gp, top + Vector3(0, -0.12, 0), 0.06)
		part(j, "Wheel", ws)
		part(j, "Pupils", gs, glow).material_override = glow
		wheels.append(j)
	# Six pale wings: two folded over the face's sides, two down over the feet, two spread to fly.
	var wings: Array = []
	var wing_cfg := [[Vector3(0.12, 1.95, 0.12), Vector3(1, 0.9, 0.1), Vector3(0, 0, 1), 0.9], [Vector3(0.12, 1.6, 0.12), Vector3(1, -0.2, 0.25), Vector3(0, 1, 0), 1.1], [Vector3(0.1, 1.35, 0.1), Vector3(0.5, -1.0, 0.1), Vector3(0, 0, 1), 0.85]]
	for cfg: Array in wing_cfg:
		for side: float in [-1.0, 1.0]:
			var at: Vector3 = cfg[0]; at.x *= side
			var sp: Vector3 = cfg[1]; sp.x *= side
			var j := joint(root, "Wing%d" % wings.size(), at)
			var fs := Sculpt.new(); var fpp := fs.add_painter(feather)
			wing_fan(fs, fpp, at, sp, cfg[2], cfg[3], 10, 1.1, 0.075)
			part(j, "Wing", fs)
			wings.append(j)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": wheels + wings}, 1.7)
	return _rig(node, head, wheels + wings)
