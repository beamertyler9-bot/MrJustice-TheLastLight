extends "res://tools/creature_kit.gd"
## The Cinder Wisp, sculpted by hand: a floating fire spirit that hurls embers from range.
## Flames are drawn unlit so they glow; the core is the bright heart of the fire.

const IRON := Color("#2b2723")
const IRON_LIGHT := Color("#5a5048")
const ASH := Color("#4a4642")
const ASH_DARK := Color("#1d1b1a")
const EMBER := Color("#ff7a1f")
const FLAME_HOT := Color("#fff1a8")
const FLAME := Color("#ffb03a")
const FLAME_RED := Color("#e8461c")
const SMOKE := Color("#3a302c")
const BRONZE := Color("#b4873e")

var flame_mat: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_gray.png")
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	flame_mat = StandardMaterial3D.new()
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = FLAME_HOT; glow.emission = FLAME
	glow.emission_energy_multiplier = 1.4


## Flame colour by height along the flame (v) with flicker noise; tips fade to red/smoke.
static func flame(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	var f := clampf(v + Sculpt.noise(p * 7.0) * 0.18, 0.0, 1.0)
	if f < 0.4: return FLAME_HOT.lerp(FLAME, f / 0.4)
	if f < 0.8: return FLAME.lerp(FLAME_RED, (f - 0.4) / 0.4)
	return FLAME_RED.lerp(SMOKE, (f - 0.8) / 0.2)


static func iron(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return IRON.lerp(IRON_LIGHT, clampf(0.4 + n.y * 0.4 + Sculpt.fbm(p * 9.0) * 0.5, 0.0, 1.0))


## Ash with glowing cracks.
## Ash, going dark into the opening at the end of a sleeve.
static func sleeve(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	return ash(p, n, v, w).lerp(Color("#0d0b0a"), smoothstep(0.93, 0.99, v))


static func ash(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := ASH.lerp(ASH_DARK, clampf(0.5 - n.y * 0.3 + Sculpt.fbm(p * 5.0) * 0.6, 0.0, 1.0))
	var crack := absf(Sculpt.noise(p * Vector3(6.0, 2.5, 6.0)))
	return c.lerp(EMBER, smoothstep(0.08, 0.0, crack) * 0.9)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "CinderWisp"
	match variant:
		"lantern": return _lantern()
		"wraith": return _wraith()
		"flame": return _flame_wisp()
		"lantern_wraith": return _lantern_wraith()
	return null


## A flame tongue from base rising towards tip, wobbling, as its own swaying node.
func tongue(parent: Node3D, name: String, base: Vector3, tip: Vector3, width: float) -> Node3D:
	var node := joint(parent, name, base)
	var s := Sculpt.new(); var fp := s.add_painter(flame)
	var mid := base.lerp(tip, 0.5) + Vector3(Sculpt.noise(base * 4.0), 0, Sculpt.noise(base * 4.0 + Vector3(3, 0, 0))) * 0.08
	s.tube([base, base.lerp(mid, 0.5), mid, mid.lerp(tip, 0.6), tip], [width, width * 0.9, width * 0.7, width * 0.4, 0.004], fp, {"sides": 7, "per": 3, "cap1": false})
	part(node, "Flame", s, flame_mat)
	return node


## Glowing coals drifting round the spirit, each its own swaying node.
func coals(parent: Node3D, center: Vector3, radius: float, count: int) -> Array:
	var nodes: Array = []
	for k in range(count):
		var ang := TAU * k / count + 0.3
		var at := center + Vector3(cos(ang) * radius, sin(k * 2.1) * 0.25, sin(ang) * radius)
		var node := joint(parent, "Coal%d" % k, center)
		var s := Sculpt.new(); var cp := s.add_painter(ash)
		s.rock(at, Vector3.ONE * (0.05 + 0.02 * (k % 3)), cp, {"lat": 4, "lon": 6, "lump": 0.4})
		part(node, "Coal", s)
		nodes.append(node)
	return nodes


## The lantern (from design A) as a carried thing: built in its own space round (0, 1.3, 0)
## and hung under `parent` at `at`, scaled by k. Returns its flame heart (the core).
func lantern(parent: Node3D, at: Vector3, k: float) -> MeshInstance3D:
	var holder := Node3D.new(); holder.name = "Lantern"
	parent.add_child(holder)
	holder.position = at - _world(parent); holder.scale = Vector3.ONE * k
	var origin := Vector3(0, 1.3, 0)
	var ls := Sculpt.new(); var ip := ls.add_painter(iron); var bp := ls.add_painter(func (p, n, v, w): return BRONZE.darkened(clampf(-n.y, 0.0, 1.0) * 0.4 + Sculpt.noise(p * 20.0) * 0.1))
	ls.lathe(Vector3(0, 1.62, 0), [Vector2(0, 0.24), Vector2(0.06, 0.22), Vector2(0.1, 0.12), Vector2(0.3, 0.02), Vector2(0.31, -0.02), Vector2(0.26, -0.02), Vector2(0, -0.01)], ip, {"sides": 6})
	ls.lathe(Vector3(0, 0.98, 0), [Vector2(0, 0.04), Vector2(0.27, 0.04), Vector2(0.28, 0.0), Vector2(0.14, -0.1), Vector2(0, -0.12)], ip, {"sides": 6})
	for j in range(6):
		var ang := TAU * (j + 0.5) / 6.0
		var out := Vector3(cos(ang), 0, sin(ang))
		ls.tube([out * 0.26 + Vector3(0, 1.0, 0), out * 0.3 + Vector3(0, 1.3, 0), out * 0.27 + Vector3(0, 1.62, 0)], [0.026, 0.03, 0.026], ip, {"sides": 6, "per": 3, "cap_rings": 1})
	ls.tube([Vector3(0, 1.86, 0), Vector3(0, 1.93, 0)], [0.025, 0.025], ip, {"sides": 6})
	ls.lathe(Vector3(0, 1.99, 0), [Vector2(0.0, 0.07), Vector2(0.06, 0.05), Vector2(0.07, 0.0), Vector2(0.06, -0.05), Vector2(0.0, -0.07)], ip, {"sides": 8})
	ls.tube([Vector3(0, 0.86, 0), Vector3(0, 0.78, 0)], [0.014, 0.014], ip, {"sides": 5})
	ls.lathe(Vector3(0, 0.74, 0), [Vector2(0, 0.06), Vector2(0.03, 0.055), Vector2(0.06, 0.0), Vector2(0.075, -0.05), Vector2(0.06, -0.05), Vector2(0, -0.03)], bp, {"sides": 12})
	var shell := MeshInstance3D.new(); shell.name = "LanternCage"; shell.mesh = ls.commit(material, origin); holder.add_child(shell)
	var fs := Sculpt.new()
	var face := fs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return flame(p, n, 1.0 - v, w))
	fs.lathe(Vector3(0, 1.02, 0), [Vector2(0, 0.66), Vector2(0.06, 0.6), Vector2(0.14, 0.48), Vector2(0.2, 0.32), Vector2(0.21, 0.18), Vector2(0.18, 0.06), Vector2(0, 0.02)], face, {"sides": 14, "wobble": 0.05})
	var dark := fs.add_painter(func (p, n, v, w): return Color("#2a0d05"))
	for side in [-1.0, 1.0]:
		fs.blob(Vector3(0.075 * side, 1.37, -0.18), Vector3(0.055, 0.022, 0.012), dark, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.4 * side)})
	fs.blob(Vector3(0, 1.235, -0.205), Vector3(0.085, 0.024, 0.012), dark, {"lat": 4, "lon": 8})
	var tooth := fs.add_painter(func (p, n, v, w): return FLAME_HOT)
	for j in range(3): fs.crystal(Vector3((j - 1) * 0.045, 1.26, -0.214), Vector3(0, -1, -0.1), 0.03, 0.012, tooth, 4)
	for j in range(4):
		var ang := TAU * j / 4.0 + 0.4
		var base := Vector3(cos(ang) * 0.08, 0.86, sin(ang) * 0.08)
		fs.tube([base, base + Vector3(cos(ang) * 0.05, -0.12, sin(ang) * 0.05), base + Vector3(cos(ang) * 0.09, -0.3 - 0.08 * (j % 2), sin(ang) * 0.09)], [0.05, 0.035, 0.003], fs.add_painter(flame), {"sides": 7, "per": 3, "cap1": false})
	var spirit := MeshInstance3D.new(); spirit.name = "SpiritFlame"; spirit.mesh = fs.commit(flame_mat, origin); holder.add_child(spirit)
	var hs := Sculpt.new(); var hw := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	hs.blob(Vector3(0, 1.2, 0), Vector3(0.09, 0.12, 0.09), hw, {"lat": 6, "lon": 8})
	var heart := MeshInstance3D.new(); heart.name = "FlameHeart"; heart.mesh = hs.commit(glow, origin); holder.add_child(heart)
	heart.material_override = glow
	var launch := Node3D.new(); launch.name = "LaunchPoint"; holder.add_child(launch)
	return heart


## The chosen design: the Ash Wraith carrying the Lantern Spirit. It raises the lantern to
## attack, and its embers fly from the lantern.
func _lantern_wraith() -> Node3D:
	var body := Sculpt.new(); var ap := body.add_painter(ash)
	body.lathe(Vector3(0, 0.45, 0), [Vector2(0, 1.12), Vector2(0.2, 1.05), Vector2(0.27, 0.9), Vector2(0.3, 0.6), Vector2(0.36, 0.3), Vector2(0.42, 0.06), Vector2(0.38, 0.0), Vector2(0.2, 0.1), Vector2(0, 0.12)], ap, {"sides": 16, "wobble": 0.35})
	# The left arm hangs, its hand hidden in a ragged sleeve.
	body.tube([Vector3(-0.24, 1.44, 0.0), Vector3(-0.34, 1.2, 0.02), Vector3(-0.37, 0.95, -0.02), Vector3(-0.38, 0.8, -0.03)], [0.09, 0.08, 0.1, 0.12], body.add_painter(sleeve), {"sides": 10, "per": 3, "cap_len": 0.3, "lump": 0.15})
	part(root, "Robe", body)
	var head := joint(root, "Head", Vector3(0, 1.5, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(ash); var void_p := hs.add_painter(func (p, n, v, w): return Color("#0d0b0a"))
	hs.blob(Vector3(0, 1.66, 0.02), Vector3(0.25, 0.28, 0.25), hp, {"lat": 10, "lon": 14, "lump": 0.08})
	hs.tube([Vector3(0, 1.88, 0.05), Vector3(0, 1.96, 0.18), Vector3(0, 1.94, 0.3)], [0.1, 0.06, 0.01], hp, {"sides": 8, "per": 3, "cap1": false})
	hs.blob(Vector3(0, 1.62, -0.17), Vector3(0.17, 0.19, 0.1), void_p, {"lat": 8, "lon": 12})
	part(head, "Hood", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.07 * side, 1.65, -0.255), Vector3(0.035, 0.018, 0.015), ew, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.3 * side)})
	var eye_glow := glow.duplicate()
	var eyes := part(head, "EmberEyes", es, eye_glow); eyes.material_override = eye_glow
	# The right arm holds the lantern out in front.
	var shoulder := joint(root, "RightShoulder", Vector3(0.25, 1.42, 0))
	var us := Sculpt.new(); var up := us.add_painter(ash)
	us.tube([Vector3(0.2, 1.46, 0.0), Vector3(0.33, 1.3, -0.02), Vector3(0.37, 1.12, -0.05)], [0.09, 0.08, 0.075], up, {"sides": 10, "per": 3, "lump": 0.15})
	part(shoulder, "Sleeve", us)
	var elbow := joint(shoulder, "Elbow", Vector3(0.37, 1.12, -0.05))
	var fs := Sculpt.new(); var fp := fs.add_painter(sleeve); var hand := fs.add_painter(func (p, n, v, w): return Color("#2a201b").lerp(EMBER, smoothstep(0.08, 0.0, absf(Sculpt.noise(p * 18.0))) * 0.7))
	fs.tube([Vector3(0.37, 1.14, -0.05), Vector3(0.39, 1.08, -0.2), Vector3(0.41, 1.03, -0.33)], [0.075, 0.09, 0.115], fp, {"sides": 10, "per": 3, "cap_len": 0.3, "lump": 0.15})
	fs.blob(Vector3(0.41, 1.01, -0.36), Vector3(0.045, 0.05, 0.045), hand, {"lat": 5, "lon": 8})
	for f in range(3): fs.tube([Vector3(0.41 + (f - 1) * 0.022, 1.0, -0.38), Vector3(0.41 + (f - 1) * 0.025, 0.96, -0.395), Vector3(0.41 + (f - 1) * 0.02, 0.94, -0.37)], [0.013, 0.011, 0.006], hand, {"sides": 5, "per": 2, "cap_rings": 1})
	part(elbow, "Forearm", fs)
	var core := lantern(elbow, Vector3(0.41, 0.56, -0.37), 0.56)
	var tatters: Array = []
	for k in range(8):
		var ang := TAU * k / 8.0 + 0.2
		var at := Vector3(cos(ang) * 0.38, 0.5, sin(ang) * 0.38)
		var node := joint(root, "Tatter%d" % k, at)
		var ts := Sculpt.new(); var tp := ts.add_painter(func (p, n, v, w): return ash(p, n, v, w).lerp(SMOKE.darkened(0.3), v))
		ts.tube([at, at + Vector3(cos(ang) * 0.06, -0.18, sin(ang) * 0.06), at + Vector3(cos(ang) * 0.08, -0.36 - 0.06 * (k % 3), sin(ang) * 0.08)], [0.08, 0.05, 0.004], tp, {"sides": 7, "per": 3, "cap1": false, "flat": 0.4, "side": Vector3(cos(ang), 0, sin(ang))})
		part(node, "Tatter", ts)
		tatters.append(node)
	return _finish({"head": head, "core": core, "arms": [shoulder], "forearms": [elbow], "feet": [], "knees": [], "leaves": tatters}, 1.15)


## A: an iron lantern with a fire spirit inside, glaring out through its bars; flames stream
## out below it and a little bell hangs underneath.
func _lantern() -> Node3D:
	var head := joint(root, "Head", Vector3(0, 1.3, 0))
	var ls := Sculpt.new(); var ip := ls.add_painter(iron); var bp := ls.add_painter(func (p, n, v, w): return BRONZE.darkened(clampf(-n.y, 0.0, 1.0) * 0.4 + Sculpt.noise(p * 20.0) * 0.1))
	ls.lathe(Vector3(0, 1.62, 0), [Vector2(0, 0.24), Vector2(0.06, 0.22), Vector2(0.1, 0.12), Vector2(0.3, 0.02), Vector2(0.31, -0.02), Vector2(0.26, -0.02), Vector2(0, -0.01)], ip, {"sides": 6})
	ls.lathe(Vector3(0, 0.98, 0), [Vector2(0, 0.04), Vector2(0.27, 0.04), Vector2(0.28, 0.0), Vector2(0.14, -0.1), Vector2(0, -0.12)], ip, {"sides": 6})
	for k in range(6):
		var ang := TAU * (k + 0.5) / 6.0
		var out := Vector3(cos(ang), 0, sin(ang))
		ls.tube([out * 0.26 + Vector3(0, 1.0, 0), out * 0.3 + Vector3(0, 1.3, 0), out * 0.27 + Vector3(0, 1.62, 0)], [0.022, 0.026, 0.022], ip, {"sides": 6, "per": 3, "cap_rings": 1})
	ls.tube([Vector3(0, 1.86, 0), Vector3(0, 1.93, 0)], [0.02, 0.02], ip, {"sides": 6})
	ls.lathe(Vector3(0, 1.98, 0), [Vector2(0.0, 0.06), Vector2(0.05, 0.04), Vector2(0.06, 0.0), Vector2(0.05, -0.04), Vector2(0.0, -0.06)], ip, {"sides": 8})
	ls.tube([Vector3(0, 0.86, 0), Vector3(0, 0.76, 0)], [0.012, 0.012], ip, {"sides": 5})
	ls.lathe(Vector3(0, 0.72, 0), [Vector2(0, 0.06), Vector2(0.03, 0.055), Vector2(0.06, 0.0), Vector2(0.075, -0.05), Vector2(0.06, -0.05), Vector2(0, -0.03)], bp, {"sides": 12})
	part(head, "Lantern", ls)
	var fs := Sculpt.new()
	var face := fs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := flame(p, n, 1.0 - v, w)
		for side in [-1.0, 1.0]:
			var e := Vector3(0.075 * side, 1.38, -0.2)
			var d := Vector2((p.x - e.x) / 0.06, (p.y - e.y + (p.x - e.x) * 0.5 * side) / 0.025).length()
			if p.z < -0.08: c = c.lerp(Color("#3a1408"), smoothstep(1.2, 0.8, d))
		var m := Vector2(p.x / 0.09, (p.y - 1.22 - absf(p.x) * 0.5) / 0.022).length()
		if p.z < -0.08: c = c.lerp(Color("#3a1408"), smoothstep(1.2, 0.8, m))
		return c)
	fs.lathe(Vector3(0, 1.02, 0), [Vector2(0, 0.66), Vector2(0.06, 0.6), Vector2(0.14, 0.48), Vector2(0.2, 0.32), Vector2(0.21, 0.18), Vector2(0.18, 0.06), Vector2(0, 0.02)], face, {"sides": 14, "wobble": 0.05, "basis": Basis(Vector3.UP, 0.0)})
	var dark := fs.add_painter(func (p, n, v, w): return Color("#2a0d05"))
	for side in [-1.0, 1.0]:
		fs.blob(Vector3(0.075 * side, 1.37, -0.18), Vector3(0.055, 0.02, 0.012), dark, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.4 * side)})
	fs.blob(Vector3(0, 1.235, -0.205), Vector3(0.085, 0.022, 0.012), dark, {"lat": 4, "lon": 8})
	for k in range(3): fs.crystal(Vector3((k - 1) * 0.045, 1.26, -0.214), Vector3(0, -1, -0.1), 0.03, 0.012, fs.add_painter(func (p, n, v, w): return FLAME_HOT), 4)
	part(head, "SpiritFlame", fs, flame_mat)
	var hs := Sculpt.new(); var hw := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	hs.blob(Vector3(0, 1.2, 0), Vector3(0.09, 0.12, 0.09), hw, {"lat": 6, "lon": 8})
	var core := part(head, "FlameHeart", hs, glow)
	core.material_override = glow
	var trail: Array = []
	for k in range(5):
		var ang := TAU * k / 5.0
		var at := Vector3(cos(ang) * 0.12, 0.96, sin(ang) * 0.12)
		trail.append(tongue(root, "Trail%d" % k, at, Vector3(cos(ang) * 0.28, 0.25 + 0.12 * (k % 2), sin(ang) * 0.28 + 0.12), 0.07))
	return _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": trail + coals(root, Vector3(0, 1.2, 0), 0.55, 4)}, 1.2)


## B: a hooded wraith of ash and smoke with glowing cracks, its hem trailing away to smoke,
## and two ember eyes in the dark of its hood.
func _wraith() -> Node3D:
	var body := Sculpt.new(); var ap := body.add_painter(ash)
	body.lathe(Vector3(0, 0.45, 0), [Vector2(0, 1.12), Vector2(0.2, 1.05), Vector2(0.27, 0.9), Vector2(0.3, 0.6), Vector2(0.36, 0.3), Vector2(0.42, 0.06), Vector2(0.38, 0.0), Vector2(0.2, 0.1), Vector2(0, 0.12)], ap, {"sides": 16, "wobble": 0.35})
	part(root, "Robe", body)
	var head := joint(root, "Head", Vector3(0, 1.5, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(ash); var void_p := hs.add_painter(func (p, n, v, w): return Color("#0d0b0a"))
	hs.blob(Vector3(0, 1.66, 0.02), Vector3(0.25, 0.28, 0.25), hp, {"lat": 10, "lon": 14, "lump": 0.08})
	hs.tube([Vector3(0, 1.88, 0.05), Vector3(0, 1.96, 0.18), Vector3(0, 1.94, 0.3)], [0.1, 0.06, 0.01], hp, {"sides": 8, "per": 3, "cap1": false})
	hs.blob(Vector3(0, 1.62, -0.17), Vector3(0.17, 0.19, 0.1), void_p, {"lat": 8, "lon": 12})
	part(head, "Hood", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.07 * side, 1.65, -0.255), Vector3(0.035, 0.018, 0.015), ew, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, 0.3 * side)})
	var core := part(head, "EmberEyes", es, glow)
	core.material_override = glow
	var tatters: Array = []
	for k in range(8):
		var ang := TAU * k / 8.0 + 0.2
		var at := Vector3(cos(ang) * 0.38, 0.5, sin(ang) * 0.38)
		var node := joint(root, "Tatter%d" % k, at)
		var ts := Sculpt.new(); var tp := ts.add_painter(func (p, n, v, w): return ash(p, n, v, w).lerp(SMOKE.darkened(0.3), v))
		ts.tube([at, at + Vector3(cos(ang) * 0.06, -0.18, sin(ang) * 0.06), at + Vector3(cos(ang) * 0.08, -0.36 - 0.06 * (k % 3), sin(ang) * 0.08)], [0.08, 0.05, 0.004], tp, {"sides": 7, "per": 3, "cap1": false, "flat": 0.4, "side": Vector3(cos(ang), 0, sin(ang))})
		part(node, "Tatter", ts)
		tatters.append(node)
	return _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": tatters + coals(root, Vector3(0, 1.1, 0), 0.6, 5)}, 1.15)


## C: a living flame with a charred wooden mask and glowing coals drifting round it.
func _flame_wisp() -> Node3D:
	var body := Sculpt.new(); var fp := body.add_painter(func (p, n, v, w): return flame(p, n, 0.15 + (1.0 - v) * 0.8, w))
	body.lathe(Vector3(0, 0.45, 0), [Vector2(0, 0.0), Vector2(0.18, 0.08), Vector2(0.32, 0.3), Vector2(0.36, 0.55), Vector2(0.3, 0.85), Vector2(0.18, 1.1), Vector2(0.06, 1.3), Vector2(0, 1.36)], fp, {"sides": 16, "wobble": 0.25})
	part(root, "FlameBody", body, flame_mat)
	var flames: Array = []
	for k in range(6):
		var ang := TAU * k / 6.0
		var at := Vector3(cos(ang) * 0.2, 1.35, sin(ang) * 0.2 + 0.05)
		flames.append(tongue(root, "Tongue%d" % k, at, at + Vector3(cos(ang) * 0.25, 0.45 + 0.15 * (k % 2), sin(ang) * 0.25 + 0.1), 0.09))
	var head := joint(root, "Head", Vector3(0, 1.2, -0.2))
	var ms := Sculpt.new()
	var eyes := [Vector3(-0.09, 1.3, -0.36), Vector3(0.09, 1.3, -0.36)]
	var mp := ms.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#3b2a1f").lerp(Color("#6b4a32"), clampf(0.5 + Sculpt.fbm(p * 9.0), 0.0, 1.0))
		var crack := absf(Sculpt.noise(p * Vector3(14.0, 6.0, 14.0)))
		c = c.lerp(EMBER, smoothstep(0.06, 0.0, crack))
		for e in eyes: c = c.lerp(Color("#120806"), smoothstep(0.06, 0.035, p.distance_to(e)))
		return c)
	ms.blob(Vector3(0, 1.22, -0.3), Vector3(0.22, 0.27, 0.07), mp, {"lat": 10, "lon": 14, "lump": 0.1, "basis": Basis(Vector3.RIGHT, 0.1)})
	ms.tube([Vector3(0, 1.26, -0.36), Vector3(0, 1.17, -0.4)], [0.03, 0.035], mp, {"sides": 7, "per": 2, "cap_rings": 2})
	part(head, "CharredMask", ms)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e in eyes: es.blob(e + Vector3(0, 0, -0.01), Vector3(0.03, 0.024, 0.015), ew, {"lat": 4, "lon": 8})
	var core := part(head, "EyeEmbers", es, glow)
	core.material_override = glow
	return _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": flames + coals(root, Vector3(0, 1.0, 0), 0.6, 5)}, 1.2)
