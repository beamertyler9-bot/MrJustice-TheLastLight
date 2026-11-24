extends "res://tools/creature_kit.gd"
## The Kiteclaw Raptor of the Windbell Plains, sculpted by hand: a big flying hunter with a
## long tail and sail-like wings whose shadow and cry come before its dive. About 4 m across.
##   raptor    - a feathered dromaeosaur with great feathered arm-wings, a toothy snout,
##               sickle claws and a fan of feathers at the end of its long tail
##   kite      - a huge red kite: rufous plumage, pale streaked head, hooked beak, black-tipped
##               wings with white windows, a deeply forked tail and big yellow talons
##   pterosaur - a crested pterosaur whose wing membranes are patterned like a patchwork kite,
##               with a diamond vane and ribbons at the end of its tail

const BEAK := Color("#d9a43a")
const TALON := Color("#2a2420")
const MOUTH := Color("#5a2228")
const FANG := Color("#efe5cb")

var feather_mat: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/fur_detail_gray.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	feather_mat = StandardMaterial3D.new()
	feather_mat.vertex_color_use_as_albedo = true
	feather_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	feather_mat.roughness = 0.85


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "KiteclawRaptor"
	match variant:
		"raptor": return _raptor()
		"kite": return _kite()
		"pterosaur": return _pterosaur()
	return null


func _eyes(color: Color) -> void:
	glow.albedo_color = color.darkened(0.25); glow.emission = color
	glow.emission_energy_multiplier = 1.2


## A flat feather from `base` along `dir`, thin along `normal`.
func feather(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, normal: Vector3, curl := 0.0, per := 2) -> void:
	var d := dir.normalized()
	var mid := base + d * length * 0.5 + normal * length * curl * 0.3
	var tip := base + d * length + normal * length * curl
	s.tube([base, mid, tip], [width * 0.45, width, 0.003], painter, {"sides": 5 if per > 1 else 4, "per": per, "flat": 0.12, "side": normal, "cap_rings": 1, "cap1": false})


## Feather colours: a base colour barred with a lighter one along each feather, with a dark tip.
func barred(base: Color, bar: Color, tip: Color, bars: float) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := base.lerp(bar, smoothstep(0.55, 0.8, sin(v * bars * PI)) * 0.8 * float(bars > 0.0))
		return c.lerp(tip, smoothstep(0.7, 0.95, v)).darkened(Sculpt.noise(p * 20.0) * 0.08)


## A feathered wing on its own joint at the shoulder: arm bones, a fan of long primaries at
## the hand, secondaries along the forearm and a layer of coverts over them.
func feathered_wing(side: float, shoulder: Vector3, span: float, chord: float, arm_paint: Callable, primary: Callable, secondary: Callable, covert: Callable, primaries := 9, droop := 0.0) -> Node3D:
	var node := joint(root, "%sWing" % ("Left" if side < 0 else "Right"), shoulder)
	var s := Sculpt.new()
	var ap := s.add_painter(arm_paint); var pp := s.add_painter(primary); var sp := s.add_painter(secondary); var cp := s.add_painter(covert)
	var up := Vector3.UP
	var elbow := shoulder + Vector3(side * span * 0.32, 0.02, 0.06)
	var wrist := shoulder + Vector3(side * span * 0.62, 0.0 - droop * 0.3, -0.02)
	var hand := shoulder + Vector3(side * span * 0.78, -droop * 0.5, 0.02)
	s.tube([shoulder, elbow, wrist, hand], [0.07, 0.05, 0.04, 0.025], ap, {"sides": 7, "per": 3, "flat": 0.6, "side": up})
	# Primaries fan from the hand, sweeping from straight out to back.
	for k in range(primaries):
		var t := float(k) / (primaries - 1)
		var base := wrist.lerp(hand, t)
		var dir := Vector3(side * (1.0 - t * 0.55), -droop * 0.2, 0.15 + t * 0.95)
		feather(s, pp, base, dir, chord * (1.0 + (1.0 - absf(t - 0.25)) * 0.35), chord * 0.2, up, -0.04)
	# Secondaries hang back from the forearm.
	for k in range(8):
		var t := float(k) / 7.0
		var base := shoulder.lerp(wrist, 0.15 + t * 0.85) + Vector3(0, 0.005, 0)
		feather(s, sp, base, Vector3(side * 0.12, -0.02, 1.0), chord * (0.95 - t * 0.1), chord * 0.24, up, -0.03)
	# Coverts: shorter feathers layered over the bases.
	for k in range(10):
		var t := float(k) / 9.0
		var base := shoulder.lerp(hand, 0.08 + t * 0.9) + Vector3(0, 0.018, -0.02)
		feather(s, cp, base, Vector3(side * (0.25 + t * 0.3), -0.04, 1.0), chord * 0.42, chord * 0.22, up, -0.02)
	part(node, "Wing", s, feather_mat)
	return node


func _close(head: Node3D, core: Node3D, wings: Array, hips: Array, knees: Array, tails: Array, jaw: Node3D, scale: float) -> Node3D:
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {}
	if jaw != null: features[&"jaw"] = node.get_path_to(jaw)
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": paths.call(wings), "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tails), "features": features}
	node.set_meta("rig_bindings", rig)
	return node


## Legs tucked back in flight, ending in clawed feet hanging ready to strike.
func hanging_legs(skin: Callable, scale_paint: Callable, hip_y: float, hip_z: float, length: float, sickle: bool, trousers := Callable()) -> Array:
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var hip_at := Vector3(0.12 * side, hip_y, hip_z)
		var knee_at := hip_at + Vector3(0.02 * side, -length * 0.4, -0.12)
		var hip := joint(root, ("Left" if side < 0 else "Right") + "Leg", hip_at)
		var us := Sculpt.new(); var up := us.add_painter(skin)
		us.tube([hip_at, knee_at], [0.085, 0.06], up, {"sides": 8, "per": 2})
		if trousers.is_valid():
			# Feathered "trousers": layers of feathers hanging back off the thigh.
			var tp := us.add_painter(trousers)
			for k in range(9):
				var ang := (k - 4) * 0.42
				var base := hip_at.lerp(knee_at, 0.25 + (k % 3) * 0.2) + Vector3(sin(ang) * 0.06 * side, 0.0, -cos(ang) * 0.04)
				feather(us, tp, base, Vector3(sin(ang) * 0.4 * side, -0.7, 0.75), 0.15, 0.04, Vector3(side, 0, 0), 0.05)
		part(hip, "Thigh", us)
		var knee := joint(hip, ("Left" if side < 0 else "Right") + "Knee", knee_at)
		var ls := Sculpt.new(); var lp := ls.add_painter(scale_paint); var cp := ls.add_painter(func (p, n, v, w): return TALON.lightened(v * 0.15))
		var ankle := knee_at + Vector3(0, -length * 0.42, 0.12)
		ls.tube([knee_at, ankle], [0.04, 0.032], lp, {"sides": 7, "per": 2})
		for t in range(4):
			var spread := (t - 1.5) * 0.35
			var dir := Vector3(sin(spread) * 0.8, -0.45, -cos(spread)) if t < 3 else Vector3(0, -0.4, 1.0)
			var toe_end := ankle + dir.normalized() * 0.11
			ls.tube([ankle, toe_end], [0.022, 0.016], lp, {"sides": 6, "per": 1, "cap_rings": 1})
			ls.tube([toe_end, toe_end + (dir + Vector3(0, -0.8, 0)).normalized() * 0.06, toe_end + Vector3(0, -0.09, 0) + dir.normalized() * 0.02], [0.013, 0.008, 0.002], cp, {"sides": 5, "per": 2, "cap_rings": 1})
		if sickle:
			var inner := ankle + Vector3(-0.02 * side, 0.02, -0.04)
			# The big curved sickle claw on the second toe, held raised.
			ls.tube([inner, inner + Vector3(0, 0.05, -0.05), inner + Vector3(0, 0.07, -0.12), inner + Vector3(0, 0.02, -0.19), inner + Vector3(0, -0.04, -0.2)], [0.022, 0.02, 0.015, 0.008, 0.002], cp, {"sides": 7, "per": 2, "flat": 0.6, "side": Vector3.RIGHT, "cap_rings": 1})
		part(knee, "Foot", ls)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


# ------------------------------------------------------------------ A: feathered raptor

func _raptor() -> Node3D:
	_eyes(Color("#ffb52e"))
	# Mottled ochre and umber plumage, darker along the back, cream underneath.
	var body_paint := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var mottle := smoothstep(0.15, 0.45, Sculpt.noise(p * 11.0))
		var c := Color("#a8743a").lerp(Color("#4e3420"), clampf(n.y * 0.6 + mottle * 0.45, 0.0, 1.0) * 0.8)
		return c.lerp(Color("#e2cfa6"), smoothstep(-0.25, -0.75, n.y))
	var scale_paint := func (p, n, v, w): return Color("#3e372c").lerp(Color("#6e6048"), Sculpt.noise(p * 30.0) * 0.5 + 0.3)
	var contour := barred(Color("#8a5a2e"), Color("#c99a5a"), Color("#3a2716"), 1.0)
	var down := func (p, n, v, w): return Color("#c9a978").lerp(Color("#8a6236"), v * 0.5)
	var blue := barred(Color("#3d5a6e"), Color("#a9c8d4"), Color("#141c22"), 4.0)
	var body := Sculpt.new(); var bp := body.add_painter(body_paint)
	body.tube([Vector3(0, 1.0, 0.42), Vector3(0, 1.04, 0.15), Vector3(0, 1.05, -0.15), Vector3(0, 1.08, -0.35)], [0.12, 0.2, 0.22, 0.16], bp, {"sides": 13, "per": 3, "flat": 0.85, "lump": 0.05})
	body.tube([Vector3(0, 1.1, -0.35), Vector3(0, 1.22, -0.48), Vector3(0, 1.32, -0.6)], [0.12, 0.085, 0.075], bp, {"sides": 10, "per": 3})
	# Layered contour feathers over the back and flanks, lying back toward the tail.
	var cp := body.add_painter(contour); var dp := body.add_painter(down)
	for row in range(8):
		var z := -0.36 + row * 0.105
		var radius := 0.2 - absf(z + 0.05) * 0.25
		var y0 := 1.05 + (0.02 if z < 0.0 else -0.04 * z)
		for k in range(9):
			var ang := PI * (-0.55 + 1.1 * (k + (row % 2) * 0.5) / 8.0)
			var radial := Vector3(sin(ang), cos(ang), 0)
			var base := Vector3(0, y0, z) + Vector3(radial.x * radius * 0.85, radial.y * radius, 0)
			feather(body, cp, base, radial * 0.25 + Vector3(0, 0, 1.0), 0.16, 0.055, radial, 0.06, 1)
	# Soft downy feathers on the chest and belly, and a shaggy ruff down the neck.
	for k in range(14):
		var ang := PI * (0.55 + 0.9 * (k % 7) / 6.0)
		var radial := Vector3(sin(ang), cos(ang), 0)
		var base := Vector3(0, 1.04, -0.28 + (k / 7) * 0.18) + Vector3(radial.x * 0.17, radial.y * 0.2, 0)
		feather(body, dp, base, radial * 0.3 + Vector3(0, -0.3, 1.0), 0.09, 0.035, radial, 0.05, 1)
	for k in range(16):
		var t := (k % 8) / 7.0
		var side := -1.0 if k < 8 else 1.0
		var at := Vector3(0.05 * side, 1.31 - t * 0.2, -0.58 + t * 0.24)
		feather(body, cp, at, Vector3(side * 0.6, 0.15, 1.0), 0.13, 0.04, Vector3(side, 0.3, 0).normalized(), 0.08, 1)
	var head := joint(root, "Head", Vector3(0, 1.33, -0.64))
	var hs := Sculpt.new(); var hp := hs.add_painter(body_paint)
	var dark := hs.add_painter(func (p, n, v, w): return Color("#120d0a"))
	var fang := hs.add_painter(func (p, n, v, w): return FANG)
	# A deep skull and a long tapering snout with a ridge over the nose, a heavy brow over a
	# fierce amber eye, sharp teeth along the jaw and a feathered face.
	hs.blob(Vector3(0, 1.375, -0.68), Vector3(0.07, 0.075, 0.1), hp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 1.375, -0.7), Vector3(0, 1.362, -0.8), Vector3(0, 1.342, -0.9), Vector3(0, 1.33, -0.95)], [0.062, 0.05, 0.034, 0.02], hp, {"sides": 11, "per": 3, "square": 0.35, "flat": 0.82, "side": Vector3.RIGHT, "cap_rings": 2})
	hs.tube([Vector3(0, 1.42, -0.7), Vector3(0, 1.4, -0.8), Vector3(0, 1.37, -0.9)], [0.022, 0.018, 0.01], hp, {"sides": 6, "per": 2, "cap_rings": 1})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.05 * side, 1.415, -0.72), Vector3(0.032, 0.012, 0.038), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, 0.35 * side)})
		hs.blob(Vector3(0.056 * side, 1.392, -0.715), Vector3(0.026, 0.02, 0.02), dark, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.022 * side, 1.37, -0.93), Vector3(0.006, 0.004, 0.009), dark, {"lat": 3, "lon": 5})
		for k in range(7):
			hs.crystal(Vector3(0.03 * side - k * 0.0015 * side, 1.322, -0.76 - k * 0.026), Vector3(0, -1, -0.12), 0.026, 0.006, fang, 4)
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.blob(Vector3(0.062 * side, 1.392, -0.728), Vector3(0.021, 0.016, 0.014), white, {"lat": 6, "lon": 10})
		hs.blob(Vector3(0.064 * side, 1.392, -0.741), Vector3(0.0045, 0.013, 0.004), dark, {"lat": 3, "lon": 6})
	var crest := hs.add_painter(barred(Color("#3d5a6e"), Color("#9cc4d6"), Color("#1d2a33"), 2.0))
	var face := hs.add_painter(contour)
	# A tall swept-back crest of blue feathers, and feathers swept back over the cheeks.
	for k in range(7):
		var spread := (k - 3) * 0.12
		feather(hs, crest, Vector3(spread * 0.15, 1.43, -0.72 + absf(k - 3) * 0.02), Vector3(spread, 0.55, 1.0), 0.26 - absf(k - 3) * 0.025, 0.034, Vector3(1, 0, -spread).normalized(), 0.18)
	for side in [-1.0, 1.0]:
		for k in range(5):
			var at := Vector3(0.062 * side, 1.37 - k * 0.012, -0.68 + k * 0.015)
			feather(hs, face, at, Vector3(side * 0.4, -0.1, 1.0), 0.1, 0.03, Vector3(side, 0, 0), 0.05)
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.32, -0.7))
	var js := Sculpt.new(); var jp := js.add_painter(body_paint); var mp := js.add_painter(func (p, n, v, w): return MOUTH); var jf := js.add_painter(func (p, n, v, w): return FANG)
	js.tube([Vector3(0, 1.318, -0.68), Vector3(0, 1.31, -0.8), Vector3(0, 1.304, -0.92)], [0.05, 0.035, 0.02], jp, {"sides": 9, "per": 2, "square": 0.35, "flat": 0.82, "side": Vector3.RIGHT, "cap_rings": 1})
	js.blob(Vector3(0, 1.325, -0.8), Vector3(0.028, 0.006, 0.1), mp, {"lat": 3, "lon": 6})
	for side in [-1.0, 1.0]:
		for k in range(6): js.crystal(Vector3(0.022 * side, 1.322, -0.76 - k * 0.026), Vector3(0, 1, -0.1), 0.018, 0.005, jf, 4)
	part(jaw, "Jaw", js)
	# Broad, sail-like feathered arm-wings: slate blue barred with pale blue, dark tips, with
	# ochre coverts over the arm.
	var wings: Array = []
	for side in [-1.0, 1.0]:
		wings.append(feathered_wing(side, Vector3(0.14 * side, 1.12, -0.25), 2.3, 0.8, body_paint,
			blue, barred(Color("#4b6170"), Color("#a9c8d4"), Color("#1d262c"), 3.0),
			barred(Color("#8a6236"), Color("#d2a868"), Color("#4a3018"), 2.0), 11, 0.05))
	var legs := hanging_legs(body_paint, scale_paint, 0.98, 0.2, 0.7, true, contour)
	# A long stiff tail feathered along both sides, ending in a broad fan.
	var tail := joint(root, "Tail", Vector3(0, 1.0, 0.42))
	var ts := Sculpt.new(); var tp := ts.add_painter(body_paint); var tf := ts.add_painter(blue)
	ts.tube([Vector3(0, 1.0, 0.4), Vector3(0, 0.99, 0.9), Vector3(0, 0.98, 1.4), Vector3(0, 0.98, 1.75)], [0.1, 0.06, 0.04, 0.025], tp, {"sides": 9, "per": 3, "flat": 1.2, "side": Vector3.RIGHT})
	for k in range(8):
		var z := 0.55 + k * 0.1
		for side in [-1.0, 1.0]:
			feather(ts, tf, Vector3(0.03 * side, 0.99, z), Vector3(side * 0.9, 0.0, 1.0), 0.2 + k * 0.012, 0.05, Vector3.UP, 0.02, 1)
	for k in range(13):
		var t := (k - 6) / 6.0
		feather(ts, tf, Vector3(t * 0.04, 0.985, 1.3 + absf(t) * 0.08), Vector3(t * 0.75, 0.0, 1.0), 0.62 - absf(t) * 0.16, 0.08, Vector3.UP, 0.02)
	part(tail, "Tail", ts, feather_mat)
	part(root, "Body", body)
	return _close(head, core, wings, legs[0], legs[1], [tail], jaw, 1.0)


# ------------------------------------------------------------------ B: red kite

func _kite() -> Node3D:
	_eyes(Color("#ffe14a"))
	var rufous := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var streak := smoothstep(0.6, 0.9, sin(p.x * 60.0 + p.z * 8.0 + Sculpt.noise(p * 9.0) * 2.0))
		return Color("#b0512a").lerp(Color("#5a2a14"), streak * 0.6).lerp(Color("#c9824a"), smoothstep(-0.2, -0.8, n.y) * 0.5)
	var pale := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var streak := smoothstep(0.5, 0.9, sin(p.x * 70.0 + Sculpt.noise(p * 12.0) * 3.0))
		return Color("#c9c4ba").lerp(Color("#4a3a2c"), streak * 0.75)
	var scale_paint := func (p, n, v, w): return Color("#e2b23a").lerp(Color("#b5862a"), Sculpt.noise(p * 30.0) * 0.5 + 0.3)
	var body := Sculpt.new(); var bp := body.add_painter(rufous)
	body.blob(Vector3(0, 1.05, 0.0), Vector3(0.22, 0.22, 0.45), bp, {"lat": 10, "lon": 14, "lump": 0.08})
	body.tube([Vector3(0, 1.12, -0.3), Vector3(0, 1.2, -0.44)], [0.15, 0.11], bp, {"sides": 11, "per": 2})
	# Breast feathers lying in rows.
	var breast := body.add_painter(barred(Color("#a24a24"), Color("#d08850"), Color("#3a1a0c"), 0.0))
	for row in range(3):
		for k in range(7):
			var ang := (k - 3) * 0.35
			feather(body, breast, Vector3(sin(ang) * 0.17, 0.98 - row * 0.03, -0.3 + row * 0.18) + Vector3(0, -0.1, 0) * absf(cos(ang)), Vector3(sin(ang) * 0.3, -0.5, 1.0), 0.16, 0.06, Vector3(sin(ang), -0.8, 0).normalized(), 0.05)
	var head := joint(root, "Head", Vector3(0, 1.24, -0.46))
	var hs := Sculpt.new(); var hp := hs.add_painter(pale)
	var beak := hs.add_painter(func (p, n, v, w): return BEAK.lerp(Color("#2a2420"), smoothstep(0.4, 0.9, v)))
	var cere := hs.add_painter(func (p, n, v, w): return Color("#e8c23a"))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#120d0a"))
	hs.blob(Vector3(0, 1.28, -0.54), Vector3(0.11, 0.1, 0.12), hp, {"lat": 8, "lon": 12})
	hs.blob(Vector3(0, 1.275, -0.635), Vector3(0.045, 0.035, 0.03), cere, {"lat": 4, "lon": 7})
	# A hooked beak: thick at the base, curving down to a sharp point.
	hs.tube([Vector3(0, 1.275, -0.64), Vector3(0, 1.27, -0.69), Vector3(0, 1.245, -0.725), Vector3(0, 1.21, -0.72)], [0.035, 0.028, 0.016, 0.003], beak, {"sides": 8, "per": 3, "flat": 0.7, "side": Vector3.RIGHT, "cap_rings": 1})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.062 * side, 1.3, -0.6), Vector3(0.024, 0.024, 0.02), dark, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.058 * side, 1.332, -0.6), Vector3(0.032, 0.009, 0.03), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, 0.25 * side)})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.068 * side, 1.3, -0.605), Vector3(0.016, 0.016, 0.012), white, {"lat": 4, "lon": 6})
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.25, -0.64))
	var js := Sculpt.new(); var jb := js.add_painter(func (p, n, v, w): return BEAK.darkened(0.1))
	js.tube([Vector3(0, 1.252, -0.635), Vector3(0, 1.245, -0.69)], [0.024, 0.01], jb, {"sides": 7, "per": 2, "flat": 0.7, "side": Vector3.RIGHT, "cap_rings": 1})
	part(jaw, "Jaw", js)
	# Long, angled wings: rufous coverts, white windows at the base of black-tipped primaries.
	var wings: Array = []
	var primaries := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#ece8de").lerp(Color("#1a1612"), smoothstep(0.35, 0.6, v)).darkened(Sculpt.noise(p * 20.0) * 0.06)
	for side in [-1.0, 1.0]:
		wings.append(feathered_wing(side, Vector3(0.15 * side, 1.15, -0.12), 2.2, 0.62, rufous, primaries,
			barred(Color("#3a2a20"), Color("#6a4a34"), Color("#14100c"), 3.0), barred(Color("#a8542a"), Color("#d89a5a"), Color("#4a2412"), 0.0), 8, 0.08))
	var legs := hanging_legs(rufous, scale_paint, 0.95, 0.15, 0.62, false)
	# The deeply forked tail of a kite.
	var tail := joint(root, "Tail", Vector3(0, 1.02, 0.42))
	var ts := Sculpt.new(); var tf := ts.add_painter(barred(Color("#b8582c"), Color("#dc9a5c"), Color("#2a1810"), 0.0))
	for k in range(10):
		var t := (k - 4.5) / 4.5
		var length := 0.45 + absf(t) * 0.38
		feather(ts, tf, Vector3(t * 0.06, 1.02, 0.38), Vector3(t * 0.32, -0.04, 1.0), length, 0.08, Vector3.UP, 0.02)
	part(tail, "Tail", ts, feather_mat)
	part(root, "Body", body)
	return _close(head, core, wings, legs[0], legs[1], [tail], jaw, 1.05)


# ------------------------------------------------------------------ C: kite pterosaur

## Patchwork kite cloth: diamond panels of plains colours with darker stitched seams.
static func kite_cloth(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var a := (p.x + p.z) / 0.5; var b := (p.x - p.z) / 0.5
	var cell := int(floor(a)) + int(floor(b)) * 3
	var colors := [Color("#c8432f"), Color("#e8b33a"), Color("#3f7a8c"), Color("#e8dcc0"), Color("#5e8a2e")]
	var c: Color = colors[posmod(cell, colors.size())]
	var seam := minf(minf(fposmod(a, 1.0), 1.0 - fposmod(a, 1.0)), minf(fposmod(b, 1.0), 1.0 - fposmod(b, 1.0)))
	c = c.lerp(Color("#3a2a1e"), smoothstep(0.07, 0.02, seam) * 0.8)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.15)


func _pterosaur() -> Node3D:
	_eyes(Color("#7affd8"))
	var hide := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return Color("#6b5a48").lerp(Color("#cbb89a"), smoothstep(-0.2, -0.8, n.y)).darkened(Sculpt.noise(p * 14.0) * 0.12)
	var scale_paint := func (p, n, v, w): return Color("#4e4636")
	var body := Sculpt.new(); var bp := body.add_painter(hide)
	body.tube([Vector3(0, 1.0, 0.32), Vector3(0, 1.04, 0.05), Vector3(0, 1.06, -0.2)], [0.08, 0.15, 0.14], bp, {"sides": 11, "per": 3, "flat": 0.9})
	# A long neck rising to a big head with a tall crest and a long, toothless beak.
	body.tube([Vector3(0, 1.08, -0.22), Vector3(0, 1.18, -0.42), Vector3(0, 1.3, -0.56)], [0.09, 0.06, 0.055], bp, {"sides": 9, "per": 3})
	var head := joint(root, "Head", Vector3(0, 1.32, -0.58))
	var hs := Sculpt.new(); var hp := hs.add_painter(hide)
	var beak := hs.add_painter(func (p, n, v, w): return Color("#d9c08a").lerp(Color("#5a4630"), smoothstep(0.5, 1.0, v)))
	var crest := hs.add_painter(func (p, n, v, w): return Color("#e8dcc0").lerp(Color("#c8432f"), 1.0 if fposmod(v * 5.0, 1.0) > 0.6 else 0.0))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#120d0a"))
	hs.blob(Vector3(0, 1.36, -0.62), Vector3(0.07, 0.07, 0.1), hp, {"lat": 7, "lon": 10})
	hs.tube([Vector3(0, 1.35, -0.68), Vector3(0, 1.33, -0.9), Vector3(0, 1.3, -1.12)], [0.045, 0.03, 0.004], beak, {"sides": 8, "per": 3, "flat": 0.75, "side": Vector3.RIGHT, "cap_rings": 1})
	# A long crest swept back from the skull, striped like a kite's spar.
	hs.tube([Vector3(0, 1.4, -0.6), Vector3(0, 1.47, -0.48), Vector3(0, 1.52, -0.32), Vector3(0, 1.54, -0.2)], [0.05, 0.06, 0.04, 0.004], crest, {"sides": 8, "per": 3, "flat": 0.2, "side": Vector3.RIGHT, "cap_rings": 1})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.05 * side, 1.385, -0.66), Vector3(0.018, 0.018, 0.016), dark, {"lat": 4, "lon": 6})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.056 * side, 1.385, -0.665), Vector3(0.012, 0.012, 0.009), white, {"lat": 4, "lon": 6})
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.32, -0.68))
	var js := Sculpt.new(); var jb := js.add_painter(func (p, n, v, w): return Color("#cbb27c").lerp(Color("#5a4630"), smoothstep(0.5, 1.0, v)))
	js.tube([Vector3(0, 1.322, -0.68), Vector3(0, 1.305, -0.9), Vector3(0, 1.288, -1.08)], [0.03, 0.02, 0.003], jb, {"sides": 7, "per": 2, "flat": 0.7, "side": Vector3.RIGHT, "cap_rings": 1})
	part(jaw, "Jaw", js)
	# Membrane wings stretched like kite cloth from a long finger to the body, with the finger
	# bone along the leading edge and a small clawed hand at the wrist.
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(0.1 * side, 1.08, -0.15)
		var node := joint(root, "%sWing" % ("Left" if side < 0 else "Right"), shoulder)
		var s := Sculpt.new(); var bone := s.add_painter(hide); var cloth := s.add_painter(kite_cloth); var claw := s.add_painter(func (p, n, v, w): return TALON)
		var elbow := shoulder + Vector3(side * 0.42, 0.06, 0.02)
		var wrist := shoulder + Vector3(side * 0.8, 0.04, -0.05)
		var tip := shoulder + Vector3(side * 2.05, -0.05, 0.25)
		s.tube([shoulder, elbow, wrist, wrist.lerp(tip, 0.5) + Vector3(0, 0.03, 0), tip], [0.05, 0.035, 0.03, 0.02, 0.004], bone, {"sides": 7, "per": 3})
		for k in range(3):
			s.crystal(wrist + Vector3(0, 0.0, -0.02 - k * 0.012), Vector3(side * 0.2, -0.3, -1.0), 0.06, 0.008, claw, 4)
		# The membrane: a thin sheet spanning from the body to the wingtip, deepest by the body.
		var span: Array = []; var chord: Array = []
		for k in range(7):
			var t := k / 6.0
			span.append(shoulder.lerp(tip, t) + Vector3(0, 0, 0.0) + Vector3(0, 0.03 * sin(t * PI), 0))
			chord.append(lerpf(0.42, 0.04, pow(t, 1.3)))
		var sheet: Array = []
		for k in range(span.size()): sheet.append(span[k] + Vector3(0, 0, chord[k] * 0.85))
		s.tube(sheet, chord, cloth, {"sides": 22, "per": 5, "flat": 0.03, "side": Vector3.UP, "cap_rings": 1})
		part(node, "Wing", s, feather_mat)
		wings.append(node)
	var legs := hanging_legs(hide, scale_paint, 0.98, 0.25, 0.55, false)
	# A long thin tail ending in a diamond kite vane with two ribbon streamers.
	var tail := joint(root, "Tail", Vector3(0, 1.0, 0.32))
	var ts := Sculpt.new(); var tp := ts.add_painter(hide); var vane := ts.add_painter(kite_cloth)
	var ribbon := ts.add_painter(func (p, n, v, w): return Color("#c8432f").lerp(Color("#e8b33a"), (1.0 if fposmod(v * 4.0, 1.0) > 0.5 else 0.0)))
	ts.tube([Vector3(0, 1.0, 0.3), Vector3(0, 0.98, 0.8), Vector3(0, 0.95, 1.3), Vector3(0, 0.95, 1.6)], [0.035, 0.02, 0.014, 0.01], tp, {"sides": 6, "per": 3})
	slab(ts, vane, Vector3(0, 0.95, 1.68), Vector3(0.2, 0.012, 0.2), Basis(Vector3.UP, PI * 0.25), 0.15, 0.0)
	for side in [-1.0, 1.0]:
		var pts: Array = []
		for k in range(7): pts.append(Vector3(side * 0.03 + sin(k * 1.2) * 0.04 * side, 0.94 - k * 0.012, 1.8 + k * 0.08))
		ts.tube(pts, Array(pts.map(func (_q): return 0.022)), ribbon, {"sides": 4, "per": 2, "flat": 0.12, "side": Vector3.UP, "cap_rings": 1})
	part(tail, "Tail", ts, feather_mat)
	part(root, "Body", body)
	return _close(head, core, wings, legs[0], legs[1], [tail], jaw, 1.05)
