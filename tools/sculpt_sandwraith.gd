extends "res://tools/sculpt_sunken_sentinel.gd"
## The Sandwraith of the Sunspire Dunes, sculpted by hand: a floating desert ghost that hurls
## blasts of sand from range, drawing the sand in round itself as it gathers a strike. Built on
## desert folklore and real desert things:
##   shroud    - the Shroud Wraith: a tall hooded robe scoured pale by the wind, its face hidden
##               behind an indigo veil wound round the head the way desert travellers wear one,
##               leaving only a slit for two burning eyes; long skeletal hands reach out of the
##               sleeves, and the hem frays into ribbons of blown sand
##   dustdevil - the Dust Devil: a whirlwind of sand (in Arabian folklore a spinning dust devil
##               is a djinn passing) that has pulled itself into a hunched hooded body; the
##               funnel spirals beneath it, sand blows off its hood like the crest of a dune,
##               fire shows through cracks in its crust and its heart is a lump of glass fused
##               by lightning (a fulgurite)
##   mummy     - the Linen Revenant: a hooded mummy wrapped in resin-stained linen, a gilded
##               funeral mask with lapis-striped lappets under its ragged shroud, the wrappings
##               torn open over the ribs to show the heart scarab glowing inside, and its lower
##               body unravelling into trailing strips while sand pours out of it

const SAND := Color("#cfae78")
const SAND_PALE := Color("#ecd7a8")
const SAND_DEEP := Color("#94724a")
const CLOTH := Color("#8c785c")
const CLOTH_DARK := Color("#3b2e22")
const INDIGO := Color("#1c2350")
const BONE := Color("#dfd2b4")
const VOID := Color("#0b0806")
const LINEN := Color("#cbbb93")
const LINEN_DARK := Color("#8f7a57")
const RESIN := Color("#6e4a2a")

var kind := "shroud"


func _init() -> void:
	super()


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Sandwraith"
	kind = variant
	match variant:
		"shroud":
			_light(Color("#ffc95a")); _texture("res://assets/cast/cloth_color.png", 3.0)
			return _shroud()
		"dustdevil":
			_light(Color("#ff8b2c")); _texture("res://assets/cast/stone_detail_soft.png", 4.0)
			return _dust_devil()
		"mummy":
			_light(Color("#5ff0e0")); _texture("res://assets/cast/cloth_color.png", 3.0)
			return _mummy()
	return null


func _light(c: Color) -> void:
	glow.albedo_color = c.lightened(0.1); glow.emission = c; glow.emission_energy_multiplier = 1.6


func _texture(path: String, scale: float) -> void:
	material.albedo_texture = load(path)
	material.uv1_scale = Vector3.ONE * scale
	material.roughness = 0.95


# ------------------------------------------------------------------ painters

## Wind-bleached cloth: dark in the troughs of its folds, scoured pale on the ridges, streaked
## along its length by blowing sand and caked with sand towards the hem.
func cloth(base: Color, dark: Color, caked := 0.55) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := base.lerp(dark, clampf(0.25 - n.y * 0.25 - w * 0.55 + Sculpt.fbm(p * Vector3(7.0, 1.5, 7.0)) * 0.55, 0.0, 1.0))
		c = c.darkened(smoothstep(0.35, 0.6, Sculpt.noise(p * Vector3(5.0, 0.8, 5.0))) * smoothstep(1.1, 0.5, p.y) * 0.3)
		c = c.lightened(smoothstep(0.2, 0.6, Sculpt.noise(p * Vector3(18.0, 1.3, 18.0))) * 0.12)
		return c.lerp(SAND, smoothstep(0.95, 0.3, p.y) * caked)


## Sand: pale on top, with the fine ripples wind leaves in a dune and darker grains between.
func sand() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := SAND.lerp(SAND_DEEP, clampf(0.3 - n.y * 0.35 + Sculpt.fbm(p * 5.0) * 0.6 - w * 0.45, 0.0, 1.0))
		c = c.lerp(Color("#b77a4a"), smoothstep(0.1, 0.5, Sculpt.fbm(p * 2.0 + Vector3(9, 2, 5))) * 0.45)
		var rip := sin(p.y * 40.0 + p.x * 9.0 + Sculpt.noise(p * 3.0) * 4.0)
		c = c.lerp(SAND_PALE, smoothstep(0.45, 0.95, rip) * 0.5).lerp(SAND_DEEP.darkened(0.35), smoothstep(-0.5, -0.95, rip) * 0.45)
		return c.darkened(smoothstep(0.55, 0.7, Sculpt.noise(p * 60.0)) * 0.15)


## Sand thinning out to pale dust towards the end of a ribbon (v).
func blown(from: Color) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := from.lerp(SAND, smoothstep(0.25, 0.7, v)).lerp(SAND_PALE, smoothstep(0.7, 1.0, v))
		return c.darkened(clampf(-n.y * 0.2 + Sculpt.noise(p * 20.0) * 0.08, 0.0, 0.3))


## Old bone, stained brown in the cracks with sand lodged in them.
static func bone(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := BONE.lerp(Color("#8f7a58"), clampf(0.15 - n.y * 0.2 + Sculpt.fbm(p * 14.0) * 0.55, 0.0, 1.0))
	return c.lerp(SAND_DEEP, smoothstep(0.5, 0.7, Sculpt.noise(p * 30.0)) * 0.4)


## Linen bandages wound round and round, each turn a slightly different shade with a dark
## shadow where it overlaps the last, yellowed with age and stained brown with resin.
func wraps(count: float, stain: float) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var u := (p.y + p.x * 0.12) * count
		var a := fposmod(u, 1.0)
		var shade := fposmod(floorf(u) * 0.618, 1.0)
		var c := LINEN.lerp(LINEN_DARK, clampf(0.2 - n.y * 0.2 + Sculpt.fbm(p * 6.0) * 0.3 + shade * 0.4, 0.0, 1.0))
		c = c.darkened(smoothstep(0.3, 0.0, a) * 0.4)
		c = c.lerp(Color("#a38c5f"), smoothstep(0.0, 0.5, Sculpt.fbm(p * 1.6 + Vector3(2, 6, 1))) * 0.5)
		return c.lerp(RESIN, smoothstep(0.15, 0.6, Sculpt.fbm(p * 2.2 + Vector3(4, 1, 7))) * stain)


# ------------------------------------------------------------------ shared pieces

## Loose grains of sand scattered from a to b, thinning out as they go.
func grains(s: Sculpt, painter: int, a: Vector3, b: Vector3, count: int, spread: float, size: float) -> void:
	for k in range(count):
		var t := (k + 0.5) / count
		var seed := a * 3.7 + Vector3(k * 1.7, k * 0.9, k * 2.3)
		var jitter := Vector3(Sculpt.noise(seed), Sculpt.noise(seed + Vector3(11, 0, 0)), Sculpt.noise(seed + Vector3(0, 0, 13)))
		s.rock(a.lerp(b, t) + jitter * spread * (0.4 + t), Vector3.ONE * size * (1.0 - t * 0.55), painter, {"lat": 3, "lon": 4, "lump": 0.4})


## A ribbon of cloth or sand along `points`, thin across `out`, tapering to nothing, with loose
## grains blowing off its tip.
func ribbon(s: Sculpt, painter: int, grain_p: int, points: Array, width: float, out: Vector3, flat := 0.3, count := 6) -> void:
	var r: Array = []
	for k in range(points.size()): r.append(lerpf(width, 0.004, pow(float(k) / (points.size() - 1), 0.9)))
	s.tube(points, r, painter, {"sides": 7, "per": 3, "cap1": false, "flat": flat, "side": out})
	if count <= 0: return
	var tip: Vector3 = points[-1]; var dir: Vector3 = (tip - (points[-2] as Vector3)).normalized()
	grains(s, grain_p, tip + dir * 0.03, tip + dir * 0.32, count, 0.05, maxf(width * 0.22, 0.008))


## A loop of tube through `points` (closed back on itself).
func loop(s: Sculpt, painter: int, points: Array, radius: float, sides := 7, radii: Array = []) -> void:
	var pts := points.duplicate(); pts.append(points[0]); pts.append(points[1])
	var r: Array = []
	for k in range(pts.size()): r.append(radii[k % radii.size()] if not radii.is_empty() else radius)
	s.tube(pts, r, painter, {"sides": sides, "per": 3, "cap_rings": 1})


## A hood's brim round the face opening: a heavy fold over the brow jutting forward, thinning
## down the cheeks to almost nothing under the chin.
func brim(s: Sculpt, painter: int, center: Vector3, half: Vector2, jut: float, thick: float) -> void:
	var pts: Array = []; var r: Array = []
	for k in range(14):
		var a := TAU * k / 14.0
		var top := maxf(sin(a), 0.0)
		pts.append(center + Vector3(cos(a) * half.x, sin(a) * half.y, -jut * top * top))
		r.append(thick * (0.45 + 0.75 * top))
	loop(s, painter, pts, thick, 8, r)


## A long skeletal hand reaching along `fwd`: knuckled finger bones curling down into claws.
func bone_hand(s: Sculpt, painter: int, claw_p: int, wrist: Vector3, fwd: Vector3, side: float, k: float) -> void:
	var f := fwd.normalized(); var right := f.cross(Vector3.UP).normalized(); var up := right.cross(f).normalized()
	s.blob(wrist + f * 0.035 * k, Vector3(0.042, 0.016, 0.045) * k, painter, {"lat": 5, "lon": 8, "basis": Basis(right, up, -f)})
	var lengths := [0.82, 1.0, 0.94, 0.74]
	for i in range(4):
		var lat := (i - 1.5) * 0.022 * k * side
		var L: float = lengths[i] * k
		var base := wrist + f * 0.03 * k + right * lat * 0.6
		var knuckle := wrist + f * 0.085 * k + right * lat
		var mid := knuckle + f * 0.06 * L + right * lat * 0.2 - up * 0.012 * L
		var tip := mid + f * 0.04 * L - up * 0.04 * L
		s.tube([base, knuckle, mid, tip], [0.009 * k, 0.011 * k, 0.008 * k, 0.006 * k], painter, {"sides": 6, "per": 2, "cap_rings": 1})
		s.blob(knuckle, Vector3.ONE * 0.012 * k, painter, {"lat": 4, "lon": 6})
		s.blob(mid, Vector3.ONE * 0.009 * k, painter, {"lat": 4, "lon": 6})
		thorn(s, claw_p, tip, f * 0.3 - up, 0.05 * L, 0.0065 * k, f * 0.012)
	var tb := wrist + f * 0.03 * k - right * 0.03 * k * side
	var tm := tb + f * 0.04 * k - right * 0.03 * k * side - up * 0.01 * k
	var tt := tm + f * 0.035 * k - up * 0.03 * k
	s.tube([tb, tm, tt], [0.01 * k, 0.009 * k, 0.006 * k], painter, {"sides": 6, "per": 2, "cap_rings": 1})
	thorn(s, claw_p, tt, f * 0.2 - up, 0.04 * k, 0.006 * k)


## A gaunt hand of dried brown skin over the bones, long thin fingers and black nails.
func dry_hand(s: Sculpt, painter: int, nail_p: int, wrist: Vector3, fwd: Vector3, side: float, k: float) -> void:
	var f := fwd.normalized(); var right := f.cross(Vector3.UP).normalized(); var up := right.cross(f).normalized()
	s.blob(wrist + f * 0.045 * k, Vector3(0.04, 0.018, 0.05) * k, painter, {"lat": 6, "lon": 8, "basis": Basis(right, up, -f), "lump": 0.1})
	var lengths := [0.85, 1.0, 0.95, 0.78]
	for i in range(4):
		var lat := (i - 1.5) * 0.02 * k * side
		var L: float = lengths[i] * k
		var knuckle := wrist + f * 0.09 * k + right * lat
		var mid := knuckle + f * 0.055 * L - up * 0.015 * L
		var tip := mid + f * 0.035 * L - up * 0.035 * L
		s.tube([wrist + f * 0.05 * k + right * lat * 0.8, knuckle, mid, tip], [0.011 * k, 0.01 * k, 0.008 * k, 0.006 * k], painter, {"sides": 6, "per": 2, "cap_rings": 1})
		thorn(s, nail_p, tip, f * 0.4 - up, 0.03 * L, 0.0065 * k)
	var tb := wrist + f * 0.04 * k - right * 0.03 * k * side
	var tt := tb + f * 0.06 * k - right * 0.025 * k * side - up * 0.03 * k
	s.tube([tb, tb.lerp(tt, 0.5) - up * 0.005, tt], [0.011 * k, 0.009 * k, 0.006 * k], painter, {"sides": 6, "per": 2, "cap_rings": 1})
	thorn(s, nail_p, tt, f * 0.3 - up, 0.025 * k, 0.006 * k)


## A spot the sand blasts fly from, hung under `parent`.
func launch_point(parent: Node3D, at: Vector3) -> void:
	var lp := Node3D.new(); lp.name = "LaunchPoint"; parent.add_child(lp)
	lp.position = at - _world(parent)


## Hooks the swaying pieces (tatters, ribbons, debris) to the game's smoke motion, which
## sways them, stretches them out as the wraith gathers its strike and lets them fall back.
func _wraith_rig(node: Node3D, head: Node3D, plumes: Array) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [],
		"ears": [], "tails": [], "features": {&"smoke": plumes.map(func (n): return node.get_path_to(n))}}
	node.set_meta("rig_bindings", rig)
	return node


# ------------------------------------------------------------------ A: shroud

func _shroud() -> Node3D:
	var robe_paint := cloth(CLOTH, CLOTH_DARK)
	var body := Sculpt.new(); var rp := body.add_painter(robe_paint)
	var dark := body.add_painter(func (p, n, v, w): return VOID)
	# A long robe hanging in deep vertical folds, its hem trailing back in the wind.
	body.tube([Vector3(0, 1.5, 0.02), Vector3(0, 1.25, 0.04), Vector3(0, 0.95, 0.07), Vector3(0, 0.65, 0.13), Vector3(0, 0.4, 0.21)], [0.2, 0.27, 0.32, 0.39, 0.46], rp, {"sides": 34, "per": 4, "ridges": 9, "ridge": 0.1, "flat": 1.12, "cap1": false, "lump": 0.05})
	body.lathe(Vector3(0, 0.43, 0.21), [Vector2(0, 0.3), Vector2(0.4, 0.02), Vector2(0, 0.0)], dark, {"sides": 16})
	# A shoulder mantle over it, its lower edge torn into points.
	body.tube([Vector3(0, 1.6, 0.02), Vector3(0, 1.44, 0.03), Vector3(0, 1.22, 0.06)], [0.16, 0.33, 0.38], rp, {"sides": 28, "per": 3, "ridges": 7, "ridge": 0.12, "flat": 1.15, "cap1": false, "lump": 0.1})
	for k in range(11):
		var ang := TAU * k / 11.0 + 0.2
		var out := Vector3(cos(ang), 0, sin(ang))
		var at := Vector3(cos(ang) * 0.4, 1.23, sin(ang) * 0.36 + 0.06)
		body.tube([at + Vector3(0, 0.03, 0), at + out * 0.02 + Vector3(0, -0.07, 0.02), at + out * 0.03 + Vector3(0, -0.15 - 0.04 * (k % 3), 0.04)], [0.06, 0.04, 0.004], rp, {"sides": 6, "per": 2, "cap1": false, "flat": 0.35, "side": out})
	part(root, "Robe", body)

	# The hood: deep, its brim jutting over the face, its point hanging down the back.
	var head := joint(root, "Head", Vector3(0, 1.5, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(cloth(CLOTH, CLOTH_DARK, 0.0)); var hv := hs.add_painter(func (p, n, v, w): return VOID)
	var veil := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := INDIGO.lerp(Color("#0b0e22"), clampf(0.35 - n.y * 0.3 + Sculpt.fbm(p * 9.0) * 0.4, 0.0, 1.0))
		c = c.darkened(smoothstep(0.6, 1.0, sin(p.y * 62.0 + p.x * 14.0 * signf(p.y - 1.71))) * 0.55)
		return c.lerp(SAND, smoothstep(0.3, 0.7, Sculpt.fbm(p * 4.0 + Vector3(3, 3, 3))) * 0.25))
	var tail := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return INDIGO.lerp(Color("#0d1028"), clampf(-n.y * 0.4 + 0.3, 0.0, 1.0)).lerp(CLOTH, smoothstep(0.3, 0.8, v)).lerp(SAND, smoothstep(0.8, 1.0, v)))
	var gp := hs.add_painter(blown(SAND))
	hs.blob(Vector3(0, 1.74, 0.05), Vector3(0.25, 0.27, 0.27), hp, {"lat": 12, "lon": 16, "lump": 0.08})
	hs.tube([Vector3(0, 1.93, 0.12), Vector3(0, 1.99, 0.26), Vector3(0, 1.93, 0.4), Vector3(0, 1.78, 0.48)], [0.12, 0.08, 0.04, 0.005], hp, {"sides": 10, "per": 3, "cap1": false})
	hs.blob(Vector3(0, 1.69, -0.14), Vector3(0.165, 0.2, 0.11), hv, {"lat": 8, "lon": 12})
	brim(hs, hp, Vector3(0, 1.7, -0.245), Vector2(0.175, 0.22), 0.07, 0.05)
	# The veil, wound round the head so only a slit is left for the eyes.
	hs.blob(Vector3(0, 1.69, -0.185), Vector3(0.14, 0.175, 0.085), veil, {"lat": 16, "lon": 20})
	hs.blob(Vector3(0, 1.712, -0.262), Vector3(0.105, 0.022, 0.014), hv, {"lat": 5, "lon": 10})
	# Each turn of the veil stands out as a fold round the face.
	for j in range(6):
		var y: float = [1.585, 1.62, 1.655, 1.688, 1.745, 1.785][j]
		var tilt := 0.012 * (1.0 if j % 2 == 0 else -1.0)
		var arc: Array = []
		for i in range(7):
			var a := PI * (0.12 + 0.76 * i / 6.0)
			var half := 0.14 * sqrt(maxf(1.0 - pow((y - 1.69) / 0.175, 2.0), 0.05))
			arc.append(Vector3(-cos(a) * half * 1.03, y + tilt * cos(a), -0.185 - sin(a) * 0.088))
		hs.tube(arc, [0.008, 0.013, 0.015, 0.015, 0.015, 0.013, 0.008], veil, {"sides": 6, "per": 2})
	ribbon(hs, tail, gp, [Vector3(0.1, 1.64, 0.2), Vector3(0.17, 1.52, 0.38), Vector3(0.22, 1.38, 0.58), Vector3(0.2, 1.26, 0.8)], 0.06, Vector3.RIGHT, 0.3, 5)
	part(head, "Hood", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.05 * side, 1.71, -0.272), Vector3(0.03, 0.0095, 0.008), ew, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.25 * side)})
	var core := part(head, "Eyes", es, glow); core.material_override = glow

	# Arms: sleeves hanging from the shoulders, wide at the cuff, with bone hands reaching out.
	var arms: Array = []; var forearms: Array = []
	var sleeve := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return (robe_paint.call(p, n, v, w) as Color).lerp(VOID, smoothstep(0.9, 0.97, v))
	for side: float in [1.0, -1.0]:
		var sh := joint(root, "RightShoulder" if side > 0 else "LeftShoulder", Vector3(0.26 * side, 1.44, 0))
		var us := Sculpt.new(); var up := us.add_painter(robe_paint)
		us.tube([Vector3(0.21 * side, 1.49, 0.0), Vector3(0.34 * side, 1.3, -0.02), Vector3(0.38 * side, 1.12, -0.05)], [0.1, 0.09, 0.085], up, {"sides": 12, "per": 3, "lump": 0.14})
		part(sh, "Sleeve", us)
		var el := joint(sh, "Elbow", Vector3(0.38 * side, 1.12, -0.05))
		var fs := Sculpt.new(); var fp := fs.add_painter(sleeve); var bp := fs.add_painter(bone); var cp := fs.add_painter(func (p, n, v, w): return Color("#2a2219").lerp(BONE, v * 0.6))
		var rag := fs.add_painter(blown(CLOTH.darkened(0.1))); var sg := fs.add_painter(blown(SAND))
		fs.tube([Vector3(0.38 * side, 1.14, -0.05), Vector3(0.4 * side, 1.06, -0.19), Vector3(0.42 * side, 1.0, -0.33)], [0.085, 0.11, 0.15], fp, {"sides": 12, "per": 3, "cap_len": 0.25, "lump": 0.14})
		for j in range(3):
			var at := Vector3((0.42 + (j - 1) * 0.07) * side, 0.89, -0.3 + j * 0.02)
			ribbon(fs, rag, sg, [at, at + Vector3(0.01 * side, -0.14, 0.05), at + Vector3(0.02 * side, -0.3 - 0.04 * j, 0.14)], 0.045, Vector3.FORWARD, 0.35, 3)
		fs.tube([Vector3(0.42 * side, 1.0, -0.33), Vector3(0.425 * side, 0.985, -0.42)], [0.035, 0.03], bp, {"sides": 7, "per": 2})
		bone_hand(fs, bp, cp, Vector3(0.425 * side, 0.98, -0.42), Vector3(0.06 * side, -0.25, -1.0), side, 1.85)
		part(el, "Forearm", fs)
		if side > 0: launch_point(el, Vector3(0.46, 0.9, -0.74))
		arms.append(sh); forearms.append(el)

	# The hem frays into ribbons of cloth that turn to blown sand, streaming back.
	var tatters: Array = []
	for k in range(20):
		var ang := TAU * k / 20.0 + 0.13
		var out := Vector3(cos(ang), 0, sin(ang))
		var back := 1.0 + maxf(0.0, sin(ang)) * 1.6
		var at := Vector3(cos(ang) * 0.46 * 1.12, 0.41, sin(ang) * 0.46 + 0.21)
		var node := joint(root, "Tatter%d" % k, at)
		var ts := Sculpt.new(); var tp := ts.add_painter(blown(CLOTH.darkened(0.15))); var tg := ts.add_painter(blown(SAND))
		var drop := 0.24 + 0.08 * ((k * 7) % 4)
		var curl := out.cross(Vector3.UP) * 0.05 * (1.0 if k % 2 == 0 else -1.0)
		ribbon(ts, tp, tg, [at + Vector3(0, 0.06, 0), at + out * 0.04 + Vector3(0, -drop * 0.45, 0.05 * back) + curl, at + out * 0.07 + Vector3(0, -drop * 0.8, 0.14 * back) - curl, at + out * 0.09 + Vector3(0, -drop, 0.28 * back)], 0.1, out, 0.16, 6)
		part(node, "Tatter", ts)
		tatters.append(node)
	return _wraith_rig(_finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": [], "knees": [], "leaves": tatters}, 1.15), head, tatters)


# ------------------------------------------------------------------ B: dust devil

func _dust_devil() -> Node3D:
	var sp := sand()
	var body := Sculpt.new(); var bp := body.add_painter(sp)
	var glass := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#3b3a26").lerp(Color("#8d7d4c"), clampf(n.y * 0.4 + 0.3 + Sculpt.noise(p * 25.0) * 0.3, 0.0, 1.0)))
	var gp := body.add_painter(blown(SAND))
	# The funnel: a whirlwind of sand narrowing to a point at the ground, its streaks spiralling.
	body.tube([Vector3(0, 1.16, 0.03), Vector3(0, 0.92, 0.05), Vector3(0.03, 0.64, 0.1), Vector3(0.05, 0.38, 0.16), Vector3(0.04, 0.16, 0.2), Vector3(0.02, 0.02, 0.22)], [0.34, 0.33, 0.27, 0.18, 0.1, 0.045], bp, {"sides": 26, "per": 5, "ridges": 5, "ridge": 0.24, "twist": 11.0, "cap0": false, "lump": 0.04})
	# The hunched body the whirlwind has pulled itself into, crusted like wind-packed sand.
	body.blob(Vector3(0, 1.3, 0.03), Vector3(0.32, 0.26, 0.25), bp, {"lat": 24, "lon": 32, "lump": 0.14})
	body.blob(Vector3(0, 1.43, 0.08), Vector3(0.28, 0.14, 0.2), bp, {"lat": 16, "lon": 24, "lump": 0.2})
	for side: float in [-1.0, 1.0]:
		body.blob(Vector3(0.27 * side, 1.43, 0.02), Vector3(0.14, 0.12, 0.13), bp, {"lat": 8, "lon": 12, "lump": 0.2})
		# Sand streaming off the shoulders.
		ribbon(body, gp, gp, [Vector3(0.3 * side, 1.5, 0.08), Vector3(0.36 * side, 1.52, 0.3), Vector3(0.4 * side, 1.46, 0.55), Vector3(0.42 * side, 1.38, 0.8)], 0.07, Vector3.UP, 0.4, 7)
	part(root, "Whirlwind", body)
	# The fulgurite heart: a branching knot of glass fused by lightning, bursting out of the
	# chest, gritty outside and glassy black-green within.
	var gs := Sculpt.new(); var gl := gs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#1d2418").lerp(Color("#6e6a3c"), clampf(n.y * 0.3 + 0.2 + Sculpt.noise(p * 25.0) * 0.4, 0.0, 1.0)).lerp(SAND_DEEP, smoothstep(0.6, 0.2, v) * 0.5))
	for j in range(9):
		var a := j * 2.4
		var d := Vector3(cos(a) * 0.8, sin(a) * 0.8 + 0.1, -0.9)
		gs.crystal(Vector3(0.02, 1.3, -0.15) + Vector3(cos(a), sin(a), 0) * 0.045, d, 0.11 + 0.05 * (j % 3), 0.03, gl, 5, 0.5)
	part(root, "Fulgurite", gs, gloss)
	# Fire inside, showing through cracks in the crust.
	var ls := Sculpt.new(); var lw := ls.add_painter(func (p, n, v, w): return Color.WHITE)
	ls.blob(Vector3(0.02, 1.3, -0.16), Vector3(0.06, 0.06, 0.04), lw, {"lat": 5, "lon": 8})
	crack(ls, lw, Vector3(-0.22, 1.42, -0.12), Vector3(-0.05, 1.18, -0.24), 0.02, Vector3(1, 0.3, 0))
	crack(ls, lw, Vector3(0.18, 1.15, -0.2), Vector3(0.3, 1.38, -0.1), 0.02, Vector3(1, -0.3, 0))
	crack(ls, lw, Vector3(0.08, 1.48, -0.14), Vector3(0.2, 1.33, -0.2), 0.015, Vector3(1, 0.5, 0))
	var heart := part(root, "Fire", ls, glow); heart.material_override = glow

	# The hood, packed out of sand; sand blows off its crest like the crest of a dune.
	var head := joint(root, "Head", Vector3(0, 1.52, -0.03))
	var hs := Sculpt.new(); var hp := hs.add_painter(sp); var hv := hs.add_painter(func (p, n, v, w): return VOID.lerp(Color("#5a1d05"), smoothstep(-0.05, -0.3, p.z) * 0.6))
	var hg := hs.add_painter(blown(SAND))
	hs.blob(Vector3(0, 1.74, 0.0), Vector3(0.23, 0.25, 0.25), hp, {"lat": 22, "lon": 28, "lump": 0.12})
	hs.blob(Vector3(0, 1.68, -0.17), Vector3(0.155, 0.185, 0.1), hv, {"lat": 8, "lon": 12})
	brim(hs, hp, Vector3(0, 1.69, -0.255), Vector2(0.17, 0.205), 0.09, 0.055)
	for j in range(3):
		var x := (j - 1) * 0.09
		ribbon(hs, hg, hg, [Vector3(x, 1.94, 0.05), Vector3(x * 1.3, 2.0, 0.28), Vector3(x * 1.6, 1.96, 0.55), Vector3(x * 1.8, 1.86, 0.85)], 0.09 - absf(x) * 0.3, Vector3.UP, 0.35, 8)
	part(head, "Hood", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.06 * side, 1.72, -0.265), Vector3(0.034, 0.016, 0.012), ew, {"lat": 4, "lon": 8, "basis": Basis(Vector3.BACK, -0.3 * side)})
	# A ragged glowing mouth.
	for j in range(5):
		var x := (j - 2) * 0.022
		es.blob(Vector3(x, 1.6 - absf(x) * 0.4, -0.262), Vector3(0.014, 0.024 - absf(x) * 0.2, 0.01), ew, {"lat": 4, "lon": 6})
	var core := part(head, "Eyes", es, glow); core.material_override = glow

	# Arms of twisted sand ending in great hands with claws of black glass.
	var arms: Array = []; var forearms: Array = []
	for side: float in [1.0, -1.0]:
		var sh := joint(root, "RightShoulder" if side > 0 else "LeftShoulder", Vector3(0.28 * side, 1.44, 0.0))
		var us := Sculpt.new(); var up := us.add_painter(sp)
		us.tube([Vector3(0.25 * side, 1.48, 0.0), Vector3(0.39 * side, 1.29, -0.02), Vector3(0.45 * side, 1.1, -0.06)], [0.12, 0.1, 0.085], up, {"sides": 14, "per": 4, "ridges": 3, "ridge": 0.22, "twist": 5.0, "lump": 0.08})
		part(sh, "UpperArm", us)
		var el := joint(sh, "Elbow", Vector3(0.45 * side, 1.1, -0.06))
		var fs := Sculpt.new(); var fp := fs.add_painter(sp); var cp := fs.add_painter(func (p, n, v, w): return Color("#1c1a12").lerp(Color("#6b6440"), (1.0 - v) * 0.5)); var fg := fs.add_painter(blown(SAND))
		fs.tube([Vector3(0.45 * side, 1.12, -0.06), Vector3(0.47 * side, 1.0, -0.2), Vector3(0.48 * side, 0.93, -0.33)], [0.085, 0.08, 0.075], fp, {"sides": 14, "per": 4, "ridges": 3, "ridge": 0.22, "twist": 4.0, "lump": 0.08})
		ribbon(fs, fg, fg, [Vector3(0.47 * side, 1.08, -0.05), Vector3(0.52 * side, 1.02, 0.15), Vector3(0.55 * side, 0.94, 0.38)], 0.05, Vector3.UP, 0.4, 5)
		var wrist := Vector3(0.48 * side, 0.92, -0.36)
		var f := Vector3(0.05 * side, -0.35, -1.0).normalized(); var right := f.cross(Vector3.UP).normalized(); var upv := right.cross(f).normalized()
		fs.blob(wrist + f * 0.06, Vector3(0.075, 0.035, 0.07), fp, {"lat": 7, "lon": 10, "lump": 0.12, "basis": Basis(right, upv, -f)})
		for i in range(3):
			var lat := (i - 1) * 0.045 * side
			var kn := wrist + f * 0.12 + right * lat
			var mid := kn + f * 0.07 + right * lat * 0.3 - upv * 0.02
			fs.tube([wrist + f * 0.06 + right * lat * 0.7, kn, mid], [0.03, 0.028, 0.022], fp, {"sides": 8, "per": 2, "cap_rings": 1, "lump": 0.1})
			fs.crystal(mid - f * 0.01, f * 0.4 - upv, 0.11, 0.02, cp, 5)
		var tb := wrist + f * 0.05 - right * 0.06 * side
		fs.tube([tb, tb + f * 0.05 - right * 0.03 * side - upv * 0.02], [0.028, 0.022], fp, {"sides": 8, "per": 2, "cap_rings": 1})
		fs.crystal(tb + f * 0.05 - right * 0.03 * side - upv * 0.02, f * 0.3 - upv - right * 0.3 * side, 0.08, 0.018, cp, 5)
		part(el, "Forearm", fs)
		if side > 0: launch_point(el, Vector3(0.5, 0.86, -0.6))
		arms.append(sh); forearms.append(el)

	# Ribbons of sand spiralling round the funnel, carrying grit, pebbles and old debris.
	var swirls: Array = []
	var debris := [["pebble", 0.035], ["bone", 0.0], ["shard", 0.0], ["pebble", 0.028]]
	for i in range(6):
		var node := joint(root, "Swirl%d" % i, Vector3(0, 0.65, 0.12))
		var ws := Sculpt.new(); var wp := ws.add_painter(blown(SAND_DEEP)); var wg := ws.add_painter(blown(SAND))
		var pts: Array = []; var r: Array = []
		var phase := TAU * i / 6.0
		for j in range(12):
			var t := j / 11.0
			var y := 0.08 + t * 1.0 + i * 0.03
			var rad := lerpf(0.12, 0.44, t) + 0.07
			var a := phase + t * TAU * 1.1
			pts.append(Vector3(cos(a) * rad, y, sin(a) * rad + 0.12)); r.append(0.004 + 0.04 * sin(PI * t))
		ws.tube(pts, r, wp, {"sides": 7, "per": 2, "flat": 0.45, "side": Vector3(cos(phase), 0, sin(phase)), "lump": 0.3})
		for j in range(14):
			var t := (j + 0.5) / 14.0
			var a := phase + 0.5 + t * TAU * 1.1
			var rad := lerpf(0.12, 0.44, t) + 0.12 + 0.04 * Sculpt.noise(Vector3(i, j, 0) * 1.7)
			ws.rock(Vector3(cos(a) * rad, 0.12 + t * 1.0, sin(a) * rad + 0.12), Vector3.ONE * (0.012 + 0.006 * (j % 3)), wg, {"lat": 3, "lon": 4})
		var item: Array = debris[i % debris.size()]
		var a2 := phase + 2.0
		var at := Vector3(cos(a2) * 0.42, 0.45 + i * 0.1, sin(a2) * 0.42 + 0.12)
		match item[0]:
			"pebble": ws.rock(at, Vector3(1.2, 0.9, 1.0) * item[1], ws.add_painter(func (p, n, v, w): return Color("#7d6448").lerp(Color("#b59a72"), clampf(n.y * 0.5 + 0.4, 0.0, 1.0))), {"lump": 0.3})
			"bone":
				var bpp := ws.add_painter(bone)
				ws.tube([at - Vector3(0.07, 0.02, 0), at + Vector3(0.07, 0.02, 0)], [0.012, 0.012], bpp, {"sides": 6})
				for e in [-1.0, 1.0]: ws.blob(at + Vector3(0.075, 0.022, 0) * e, Vector3(0.022, 0.016, 0.016), bpp, {"lat": 4, "lon": 6})
			"shard": slab(ws, ws.add_painter(func (p, n, v, w): return Color("#a65a33").lerp(Color("#d9b48a"), clampf(n.y * 0.5 + 0.2, 0.0, 1.0))), at, Vector3(0.08, 0.012, 0.06), Basis(Vector3(1, 1, 0).normalized(), 0.6), 0.2, 0.1)
		part(node, "Swirl", ws)
		swirls.append(node)
	return _wraith_rig(_finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": [], "knees": [], "leaves": swirls}, 1.15), head, swirls)


# ------------------------------------------------------------------ C: linen revenant

func _mummy() -> Node3D:
	var wp := wraps(13.0, 0.45)
	var shroud_paint := cloth(Color("#a8936c"), Color("#4a3a2a"), 0.3)
	var body := Sculpt.new(); var bp := body.add_painter(wp); var dark := body.add_painter(func (p, n, v, w): return Color("#1a120b"))
	var bn := body.add_painter(bone); var rag := body.add_painter(blown(LINEN_DARK)); var sg := body.add_painter(blown(SAND))
	# A wrapped torso, narrowing to the waist.
	body.tube([Vector3(0, 1.5, 0.0), Vector3(0, 1.32, 0.0), Vector3(0, 1.12, 0.02), Vector3(0, 0.94, 0.05)], [0.17, 0.235, 0.21, 0.165], bp, {"sides": 28, "per": 8, "flat": 1.25, "lump": 0.05, "bands": 9, "band": 0.05})
	# The wrappings torn open over the ribs, the heart scarab glowing inside.
	body.blob(Vector3(-0.07, 1.27, -0.205), Vector3(0.105, 0.125, 0.05), dark, {"lat": 7, "lon": 10})
	for j in range(4):
		var y := 1.35 - j * 0.048
		body.tube([Vector3(-0.17, y + 0.02, -0.19), Vector3(-0.09, y - 0.005, -0.248), Vector3(0.0, y + 0.01, -0.25)], [0.011, 0.012, 0.01], bn, {"sides": 6, "per": 2, "cap_rings": 1})
	body.tube([Vector3(0.0, 1.4, -0.25), Vector3(0.005, 1.17, -0.245)], [0.014, 0.012], bn, {"sides": 6, "per": 2})
	# Torn ends of the wrappings round the hole.
	var torn: Array = []
	for k in range(12):
		var a := TAU * k / 12.0
		torn.append(Vector3(-0.07 + cos(a) * 0.105, 1.27 + sin(a) * 0.125, -0.238 + 0.03 * absf(cos(a))))
	loop(body, bp, torn, 0.018, 6)
	for j in range(3):
		var at := Vector3(-0.07 + (j - 1) * 0.07, 1.14 + absf(j - 1) * 0.02, -0.235)
		ribbon(body, rag, sg, [at, at + Vector3(0.01, -0.07, -0.02), at + Vector3(0.02 * (j - 1), -0.17, -0.01)], 0.03, Vector3.BACK, 0.25, 0)
	# The broad collar: rows of gold, lapis and turquoise beads.
	body.lathe(Vector3(0, 1.5, 0.0), dense([Vector2(0.15, 0.03), Vector2(0.27, -0.03), Vector2(0.3, -0.07), Vector2(0.28, -0.085), Vector2(0.15, -0.02)], 4), body.add_painter(collar_rings(32.0)), {"sides": 28, "basis": Basis.from_scale(Vector3(1.0, 1.0, 0.72))})
	# Below the waist the wrappings unravel; sand pours out of the open end.
	body.tube([Vector3(0, 0.96, 0.05), Vector3(0, 0.8, 0.1), Vector3(0, 0.63, 0.16), Vector3(0, 0.48, 0.22)], [0.165, 0.15, 0.12, 0.085], bp, {"sides": 22, "per": 5, "flat": 1.2, "cap1": false, "lump": 0.08})
	body.lathe(Vector3(0, 0.5, 0.22), [Vector2(0, 0.06), Vector2(0.08, 0.0), Vector2(0, -0.01)], dark, {"sides": 10})
	var pour: Array = [Vector3(0, 0.5, 0.22), Vector3(0, 0.4, 0.25), Vector3(0, 0.3, 0.27), Vector3(0, 0.2, 0.29)]
	body.tube(pour, [0.05, 0.034, 0.022, 0.004], body.add_painter(sand()), {"sides": 10, "per": 3, "ridges": 4, "ridge": 0.2, "twist": 3.0, "cap1": false})
	grains(body, sg, Vector3(0, 0.24, 0.29), Vector3(0, 0.02, 0.32), 14, 0.05, 0.012)
	# The shroud falls from the head over the shoulders and down the back.
	var shp := body.add_painter(shroud_paint); var shr := body.add_painter(blown(Color("#8a7656")))
	body.tube([Vector3(0, 1.6, 0.1), Vector3(0, 1.44, 0.14), Vector3(0, 1.18, 0.19), Vector3(0, 0.92, 0.27)], [0.17, 0.25, 0.245, 0.23], shp, {"sides": 24, "per": 3, "ridges": 7, "ridge": 0.14, "flat": 1.15, "cap1": false, "lump": 0.1, "side": Vector3.RIGHT})
	for k in range(7):
		var a := PI * (0.12 + 0.76 * k / 6.0)
		var at := Vector3(-cos(a) * 0.25, 0.94, 0.27 + sin(a) * 0.2)
		ribbon(body, shr, sg, [at, at + Vector3(0, -0.12, 0.06), at + Vector3(0, -0.24 - 0.05 * (k % 2), 0.16)], 0.06, Vector3(-cos(a), 0, sin(a)), 0.2, 3)
	part(root, "Body", body)
	var ls := Sculpt.new(); var lw := ls.add_painter(func (p, n, v, w): return Color.WHITE)
	# The heart scarab: a beetle with its wing cases closed.
	ls.blob(Vector3(-0.075, 1.26, -0.235), Vector3(0.036, 0.045, 0.022), lw, {"lat": 6, "lon": 10})
	ls.blob(Vector3(-0.075, 1.315, -0.232), Vector3(0.024, 0.015, 0.018), lw, {"lat": 4, "lon": 8})
	var heart := part(root, "HeartScarab", ls, glow); heart.material_override = glow

	# The head: a gilded funeral mask with lapis-striped lappets, under a ragged linen hood.
	var head := joint(root, "Head", Vector3(0, 1.5, 0))
	var hs := Sculpt.new(); var hw := hs.add_painter(wp); var hsh := hs.add_painter(shroud_paint)
	var gold := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var g := Color("#c79a3a").lerp(Color("#5e4317"), clampf(-n.y * 0.45 + 0.3 + Sculpt.fbm(p * 14.0) * 0.3, 0.0, 1.0)).lightened(smoothstep(0.4, 1.0, n.y) * 0.18)
		g = g.darkened(smoothstep(0.45, 0.7, Sculpt.noise(p * 25.0)) * 0.3).lerp(SAND_DEEP, smoothstep(0.3, 0.6, Sculpt.fbm(p * 7.0)) * 0.35)
		# The lower part of the mask has broken away, showing the dried face beneath.
		var broken := smoothstep(-0.004, 0.004, 1.64 + p.x * 0.4 + Sculpt.noise(p * 35.0) * 0.02 - p.y)
		return g.lerp(Color("#33241a").lerp(Color("#5a4029"), clampf(n.y * 0.5 + Sculpt.fbm(p * 30.0) * 0.4, 0.0, 1.0)), broken))
	var kohl := hs.add_painter(func (p, n, v, w): return Color("#0c0e18"))
	var stripe := hs.add_painter(stripes(26.0, Vector3.UP))
	var hv := hs.add_painter(func (p, n, v, w): return VOID)
	var hg := hs.add_painter(blown(LINEN_DARK)); var hsg := hs.add_painter(blown(SAND))
	hs.blob(Vector3(0, 1.7, 0.02), Vector3(0.15, 0.17, 0.16), hw, {"lat": 10, "lon": 14})
	hs.blob(Vector3(0, 1.67, -0.11), Vector3(0.115, 0.145, 0.07), gold, {"lat": 18, "lon": 22})
	hs.tube([Vector3(-0.09, 1.745, -0.155), Vector3(0, 1.762, -0.178), Vector3(0.09, 1.745, -0.155)], [0.014, 0.016, 0.014], gold, {"sides": 6, "per": 3})
	hs.tube([Vector3(0, 1.735, -0.176), Vector3(0, 1.68, -0.19), Vector3(0, 1.645, -0.198)], [0.012, 0.016, 0.02], gold, {"sides": 7, "per": 2})
	# Under the broken mask, the gaping mouth of the dried face, lips shrunk back from the teeth.
	var tooth := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return BONE.darkened(clampf(0.25 - n.y * 0.2, 0.0, 0.5)))
	hs.blob(Vector3(0, 1.585, -0.165), Vector3(0.05, 0.022, 0.014), hv, {"lat": 5, "lon": 10})
	for i in range(8):
		var x := (i - 3.5) * 0.0125
		hs.blob(Vector3(x, 1.603, -0.176 + x * x * 4.0), Vector3(0.0058, 0.01, 0.006), tooth, {"lat": 4, "lon": 6})
		if i > 0 and i < 7: hs.blob(Vector3(x, 1.566, -0.172 + x * x * 4.0), Vector3(0.0055, 0.009, 0.006), tooth, {"lat": 4, "lon": 6})
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.048 * side, 1.705, -0.163), Vector3(0.036, 0.021, 0.014), kohl, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.048 * side, 1.705, -0.168), Vector3(0.028, 0.015, 0.012), hv, {"lat": 5, "lon": 8})
		hs.tube([Vector3(0.075 * side, 1.705, -0.155), Vector3(0.1 * side, 1.71, -0.135)], [0.006, 0.004], kohl, {"sides": 5, "per": 1})
		# Lappets hanging from under the hood down to the collar.
		slab(hs, stripe, Vector3(0.125 * side, 1.57, -0.07), Vector3(0.075, 0.2, 0.035), Basis(Vector3.UP, 0.25 * side) * Basis(Vector3.RIGHT, PI * 0.5), 0.3, 0.0)
	# The hood, its brim framing the mask, its edge torn.
	hs.blob(Vector3(0, 1.73, 0.05), Vector3(0.2, 0.22, 0.21), hsh, {"lat": 12, "lon": 16, "lump": 0.1})
	hs.blob(Vector3(0, 1.67, -0.06), Vector3(0.14, 0.18, 0.08), hv, {"lat": 6, "lon": 10})
	brim(hs, hsh, Vector3(0, 1.67, -0.12), Vector2(0.16, 0.205), 0.07, 0.045)
	for j in range(5):
		var x := (j - 2) * 0.07
		var at := Vector3(x, 1.51 - absf(x) * 0.2, -0.04)
		ribbon(hs, hg, hsg, [at, at + Vector3(x * 0.2, -0.1, 0.0), at + Vector3(x * 0.3, -0.18 - 0.03 * (j % 2), 0.02)], 0.04, Vector3.BACK, 0.3, 0)
	part(head, "Mask", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.048 * side, 1.705, -0.176), Vector3(0.011, 0.009, 0.006), ew, {"lat": 4, "lon": 8})
	var core := part(head, "Eyes", es, glow); core.material_override = glow

	# Wrapped arms with gold bands, loose bandage ends and gaunt dried hands.
	var arms: Array = []; var forearms: Array = []
	for side: float in [1.0, -1.0]:
		var sh := joint(root, "RightShoulder" if side > 0 else "LeftShoulder", Vector3(0.24 * side, 1.43, 0.0))
		var us := Sculpt.new(); var up := us.add_painter(wp); var ug := us.add_painter(gilt()); var ur := us.add_painter(blown(LINEN_DARK)); var usg := us.add_painter(blown(SAND))
		us.blob(Vector3(0.22 * side, 1.44, 0.0), Vector3(0.09, 0.08, 0.09), up, {"lat": 7, "lon": 10})
		us.tube([Vector3(0.22 * side, 1.46, 0.0), Vector3(0.3 * side, 1.28, -0.02), Vector3(0.33 * side, 1.1, -0.06)], [0.075, 0.062, 0.056], up, {"sides": 14, "per": 5})
		us.tube([Vector3(0.293 * side, 1.31, -0.017), Vector3(0.305 * side, 1.27, -0.022)], [0.066, 0.066], ug, {"sides": 14, "per": 1})
		ribbon(us, ur, usg, [Vector3(0.32 * side, 1.2, -0.03), Vector3(0.36 * side, 1.08, 0.05), Vector3(0.38 * side, 0.94, 0.16), Vector3(0.38 * side, 0.82, 0.3)], 0.035, Vector3.RIGHT, 0.3, 4)
		part(sh, "UpperArm", us)
		var el := joint(sh, "Elbow", Vector3(0.33 * side, 1.1, -0.06))
		var fs := Sculpt.new(); var fp := fs.add_painter(wp); var skin_p := fs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#4a3322").lerp(Color("#7a5a3c"), clampf(n.y * 0.4 + 0.3 + Sculpt.fbm(p * 30.0) * 0.4, 0.0, 1.0)))
		var nail := fs.add_painter(func (p, n, v, w): return Color("#140e0a"))
		fs.tube([Vector3(0.33 * side, 1.11, -0.06), Vector3(0.345 * side, 1.03, -0.2), Vector3(0.355 * side, 0.97, -0.33)], [0.056, 0.05, 0.043], fp, {"sides": 14, "per": 5})
		dry_hand(fs, skin_p, nail, Vector3(0.355 * side, 0.965, -0.35), Vector3(0.02 * side, -0.3, -1.0), side, 1.25)
		part(el, "Forearm", fs)
		if side > 0: launch_point(el, Vector3(0.37, 0.92, -0.55))
		arms.append(sh); forearms.append(el)

	# Long strips of linen trailing from the hips, fraying into sand.
	var strips: Array = []
	for k in range(9):
		var ang := TAU * k / 9.0 + 0.35
		var out := Vector3(cos(ang), 0, sin(ang))
		var back := 1.0 + maxf(0.0, sin(ang)) * 1.3
		var at := Vector3(cos(ang) * 0.17, 0.9 - 0.12 * (k % 3), sin(ang) * 0.14 + 0.08)
		var node := joint(root, "Strip%d" % k, at)
		var ts := Sculpt.new(); var tp := ts.add_painter(blown(LINEN.darkened(0.12))); var tg := ts.add_painter(blown(SAND))
		var drop := 0.55 + 0.1 * (k % 3)
		ribbon(ts, tp, tg, [at, at + out * 0.06 + Vector3(0, -drop * 0.35, 0.06 * back), at + out * 0.1 + Vector3(0, -drop * 0.7, 0.16 * back), at + out * 0.12 + Vector3(0, -drop, 0.3 * back)], 0.05, out, 0.25, 5)
		part(node, "Strip", ts)
		strips.append(node)
	return _wraith_rig(_finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": [], "knees": [], "leaves": strips}, 1.15), head, strips)
