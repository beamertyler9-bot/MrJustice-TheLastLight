extends "res://tools/creature_kit.gd"
## The Sugarspike Wasp of S'morewood, three takes. Hard-candy shells, glassy spun-sugar wings,
## sharp sugar spikes, and a sting that fires shards of sugar.
## A: a hornet built of faceted rock candy, amber and gold, with a crystal sting.
## B: a wasp whose abdomen is a striped swirl lollipop, with cellophane wings and a gumdrop thorax.
## C: a candy-corn wasp: a tapering tri-colour abdomen and a thorax bristling with sugar spikes.

const AMBER := Color("#e8902a")
const GOLD := Color("#f2c230")
const DARK := Color("#2a120a")
const CREAM := Color("#fff4dc")
const RED := Color("#e0303a")
const ORANGE := Color("#f08a1c")

var shiny: StandardMaterial3D
var wing_mat: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	shiny = StandardMaterial3D.new()
	shiny.vertex_color_use_as_albedo = true
	shiny.vertex_color_is_srgb = true
	shiny.roughness = 0.15
	shiny.metallic_specular = 0.85
	wing_mat = StandardMaterial3D.new()
	wing_mat.vertex_color_use_as_albedo = true
	wing_mat.vertex_color_is_srgb = true
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_mat.roughness = 0.08
	wing_mat.metallic_specular = 1.0
	glow.albedo_color = Color("#d0302a"); glow.emission = Color("#ff4a3a")
	glow.emission_energy_multiplier = 0.8


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "SugarspikeWasp"
	match variant:
		"rockcandy": return _rock_candy()
		"lollipop": return _lollipop()
		"candycorn": return _candy_corn()
	return null


func _with_visual(node: Node3D, head: Node3D, hips: Array, knees: Array, wings: Array, jaw: Node3D = null) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {}
	if jaw != null: features[&"jaw"] = node.get_path_to(jaw)
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": paths.call(wings), "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": [], "features": features}
	node.set_meta("rig_bindings", rig)
	return node


## Two pairs of glassy wings from the thorax, each on its own joint (left, right, left, right).
## `tint` colours the membrane, `vein` the veins.
func wings(at: Vector3, length: float, tint: Color, vein: Color) -> Array:
	var out: Array = []
	for pair in range(2):
		for side: float in [-1.0, 1.0]:
			var root_at := at + Vector3(0.07 * side, 0.03 - pair * 0.02, pair * 0.12)
			var node := joint(root, "%sWing%d" % ["Left" if side < 0 else "Right", pair], root_at)
			var ws := Sculpt.new()
			var mem := ws.add_painter(func (p, n, v, w): return Color(tint.r, tint.g, tint.b, 0.58).lightened(clampf(absf(n.y), 0.0, 1.0) * 0.15))
			var vp := ws.add_painter(func (p, n, v, w): return vein)
			var l := length * (1.0 if pair == 0 else 0.75)
			var dir := Vector3(side, 0.12, 0.38 + pair * 0.25).normalized()
			var center := root_at + dir * l * 0.5
			ws.blob(center, Vector3(l * 0.5, 0.008, l * 0.22), mem, {"lat": 4, "lon": 14, "basis": Basis.looking_at(Vector3(-dir.z, 0, dir.x) * side, Vector3.UP)})
			for k in range(3):
				var off := (k - 1) * l * 0.08
				var side_dir := Vector3(-dir.z, 0, dir.x).normalized() * side
				ws.tube([root_at + side_dir * off * 0.3, center + side_dir * off + Vector3(0, 0.01, 0), root_at + dir * l * 0.92 + side_dir * off * 0.4], [0.006, 0.005, 0.003], vp, {"sides": 4, "per": 2, "cap_rings": 1})
			part(node, "Wing", ws, wing_mat)
			out.append(node)
	return out


## Six thin legs hanging under the thorax, bent at the knee, with hooked feet.
func dangling_legs(at: Vector3, color: Color, thick: float) -> Array:
	var hips: Array = []; var knees: Array = []
	for k in range(6):
		var side := -1.0 if k % 2 == 0 else 1.0
		var row := int(k / 2)
		var hip_at := at + Vector3(0.07 * side, -0.05, -0.06 + row * 0.08)
		var hip := joint(root, ("Foreleg%d" if row == 0 else "Hindleg%d") % k, hip_at)
		var knee_at := hip_at + Vector3(0.16 * side, -0.05, -0.05 + row * 0.07)
		var foot := knee_at + Vector3(0.04 * side, -0.24, 0.08 + row * 0.06)
		var ts := Sculpt.new(); var tp := ts.add_painter(func (p, n, v, w): return color.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
		ts.tube([hip_at, knee_at], [thick, thick * 0.85], tp, {"sides": 6, "per": 1, "cap_rings": 1})
		part(hip, "Thigh", ts, shiny)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(func (p, n, v, w): return color.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
		ss.tube([knee_at, knee_at.lerp(foot, 0.6) + Vector3(0, 0, -0.02), foot, foot + Vector3(0, 0.02, -0.04)], [thick * 0.8, thick * 0.65, thick * 0.5, 0.003], sp, {"sides": 6, "per": 2, "cap0": false})
		part(knee, "Shin", ss, shiny)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


func _head(at: Vector3, shell: Callable, eye_size: float, mandible: Color) -> Array:
	var head := joint(root, "Head", at)
	var hs := Sculpt.new(); var hp := hs.add_painter(shell); var mp := hs.add_painter(func (p, n, v, w): return mandible.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	hs.blob(at + Vector3(0, 0, -0.04), Vector3(0.12, 0.11, 0.1), hp, {"lat": 7, "lon": 10})
	for side: float in [-1.0, 1.0]:
		hs.tube([at + Vector3(0.04 * side, -0.07, -0.1), at + Vector3(0.07 * side, -0.11, -0.15), at + Vector3(0.02 * side, -0.13, -0.18)], [0.02, 0.014, 0.003], mp, {"sides": 6, "per": 3, "cap0": false})
		hs.tube([at + Vector3(0.04 * side, 0.08, -0.1), at + Vector3(0.1 * side, 0.2, -0.18), at + Vector3(0.14 * side, 0.24, -0.28)], [0.01, 0.008, 0.006], mp, {"sides": 5, "per": 3})
	part(head, "Head", hs, shiny)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]:
		es.rock(at + Vector3(0.085 * side, 0.02, -0.07), Vector3(eye_size * 0.7, eye_size, eye_size * 0.8), ew, {"lat": 5, "lon": 7, "lump": 0.1})
	var core := part(head, "CompoundEyes", es, glow); core.material_override = glow
	return [head, core]


func _launch(at: Vector3) -> void:
	var l := Node3D.new(); l.name = "LaunchPoint"; root.add_child(l); l.position = at


# --------------------------------------------------------------- A: rock candy

static func rock_candy(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := AMBER.lerp(GOLD, clampf(0.4 + n.y * 0.5 + Sculpt.noise(p * 9.0) * 0.6, 0.0, 1.0))
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.35)


## A: a hornet of faceted rock candy: amber thorax, gold-and-chocolate banded abdomen, a cluster
## of sugar crystals on its back, ruby compound eyes and a long crystal sting.
func _rock_candy() -> Node3D:
	var y := 1.0
	var bs := Sculpt.new(); var rc := bs.add_painter(rock_candy)
	var band := bs.add_painter(func (p, n, v, w): return GOLD.lightened(clampf(n.y, 0.0, 1.0) * 0.2) if fposmod((p.z - 0.05) * 9.0, 1.0) < 0.55 else DARK.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	var crystal := bs.add_painter(func (p, n, v, w): return CREAM.lerp(AMBER, 0.25 + (1.0 - v) * 0.3))
	bs.rock(Vector3(0, y, -0.02), Vector3(0.14, 0.13, 0.17), rc, {"lat": 6, "lon": 8, "lump": 0.2})
	bs.tube([Vector3(0, y - 0.02, 0.12), Vector3(0, y - 0.06, 0.32), Vector3(0, y - 0.14, 0.52), Vector3(0, y - 0.22, 0.62)], [0.11, 0.16, 0.12, 0.03], band, {"sides": 10, "per": 3, "facet": true, "lump": 0.08})
	for k in range(5):
		bs.crystal(Vector3(sin(k * 2.3) * 0.06, y + 0.1, -0.06 + k * 0.03), Vector3(sin(k * 2.3) * 0.5, 1, 0.3).normalized(), 0.1 + 0.04 * (k % 2), 0.025, crystal, 6, k)
	var sting := bs.add_painter(func (p, n, v, w): return CREAM.lerp(Color("#ffd8a8"), 1.0 - v))
	bs.crystal(Vector3(0, y - 0.22, 0.62), Vector3(0, -0.45, 1).normalized(), 0.22, 0.03, sting, 6)
	part(root, "Body", bs, shiny)
	var hc := _head(Vector3(0, y + 0.02, -0.2), rock_candy, 0.07, DARK)
	var w := wings(Vector3(0, y + 0.09, -0.02), 0.62, Color("#fff0c8"), Color("#c87a20"))
	var legs := dangling_legs(Vector3(0, y - 0.06, -0.04), DARK, 0.018)
	_launch(Vector3(0, y - 0.3, 0.8))
	var node := _finish({"head": hc[0], "core": hc[1], "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": w}, 1.2)
	return _with_visual(node, hc[0], legs[0], legs[1], w)


# ---------------------------------------------------------------- B: lollipop

## B: a wasp with a swirl lollipop for an abdomen, its stick for a sting, a glossy gumdrop
## thorax, pink cellophane wings and licorice legs.
func _lollipop() -> Node3D:
	var y := 1.0
	var bs := Sculpt.new()
	var gum := bs.add_painter(func (p, n, v, w): return Color("#7a2a8a").lightened(clampf(n.y, 0.0, 1.0) * 0.35 + absf(Sculpt.noise(p * 30.0)) * 0.1))
	var swirl := bs.add_painter(func (p, n, v, w):
		var q := Vector2(p.y - (y - 0.04), p.z - 0.36)
		var spiral := fposmod(q.length() * 14.0 - atan2(q.y, q.x) / TAU * 2.0, 1.0)
		return RED.lerp(CREAM, smoothstep(0.45, 0.55, spiral)).lightened(clampf(absf(n.x), 0.0, 1.0) * 0.15))
	var stick := bs.add_painter(func (p, n, v, w): return CREAM.darkened(0.05))
	bs.blob(Vector3(0, y, -0.02), Vector3(0.14, 0.13, 0.15), gum, {"lat": 8, "lon": 12})
	bs.tube([Vector3(0, y - 0.02, 0.1), Vector3(0, y - 0.03, 0.16)], [0.05, 0.04], gum, {"sides": 8, "per": 1})
	var disc: Array = [Vector2(0, 0.06)]
	for k in range(1, 15): disc.append(Vector2(0.23 * k / 15.0, 0.06 * sqrt(1.0 - pow(k / 15.0, 4.0))))
	disc.append(Vector2(0.235, 0.0))
	for k in range(14, 0, -1): disc.append(Vector2(0.23 * k / 15.0, -0.06 * sqrt(1.0 - pow(k / 15.0, 4.0))))
	disc.append(Vector2(0, -0.06))
	bs.lathe(Vector3(0, y - 0.04, 0.36), disc, swirl, {"sides": 40, "basis": Basis(Vector3.BACK, PI * 0.5)})
	bs.tube([Vector3(0, y - 0.04, 0.58), Vector3(0, y - 0.18, 0.74), Vector3(0, y - 0.3, 0.84)], [0.022, 0.02, 0.003], stick, {"sides": 7, "per": 3, "cap0": false})
	part(root, "Body", bs, shiny)
	var hc := _head(Vector3(0, y + 0.02, -0.19), func (p, n, v, w): return Color("#7a2a8a").lightened(clampf(n.y, 0.0, 1.0) * 0.35), 0.065, Color("#1a0a10"))
	var w := wings(Vector3(0, y + 0.1, -0.02), 0.6, Color("#ffc0dc"), Color("#ff7aa8"))
	var legs := dangling_legs(Vector3(0, y - 0.06, -0.03), Color("#1a0a10"), 0.02)
	_launch(Vector3(0, y - 0.32, 0.86))
	var node := _finish({"head": hc[0], "core": hc[1], "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": w}, 1.2)
	return _with_visual(node, hc[0], legs[0], legs[1], w)


# --------------------------------------------------------------- C: candy corn

## C: a sleek wasp whose tapering abdomen is a candy corn (yellow, orange, white tip), with a
## dark hard-candy thorax bristling with sharp sugar spikes and amber wings.
func _candy_corn() -> Node3D:
	var y := 1.0
	var bs := Sculpt.new()
	var corn := bs.add_painter(func (p, n, v, w):
		var c := GOLD if p.z < 0.3 else ORANGE if p.z < 0.48 else CREAM
		return c.lightened(clampf(n.y, 0.0, 1.0) * 0.18).darkened(clampf(-n.y, 0.0, 1.0) * 0.25))
	var shell := bs.add_painter(func (p, n, v, w): return DARK.lightened(clampf(n.y, 0.0, 1.0) * 0.3 + absf(Sculpt.noise(p * 12.0)) * 0.1))
	var spike := bs.add_painter(func (p, n, v, w): return CREAM.lerp(Color("#ffe6b8"), 1.0 - v))
	bs.blob(Vector3(0, y, -0.02), Vector3(0.13, 0.12, 0.16), shell, {"lat": 8, "lon": 12})
	bs.tube([Vector3(0, y - 0.02, 0.1), Vector3(0, y - 0.03, 0.15)], [0.045, 0.035], shell, {"sides": 8, "per": 1})
	# The candy corn: three separately shaped bands (yellow, orange, white tip) so the colours
	# meet in crisp lines, each seam pressed in with a little groove.
	var axis := func (t: float) -> Vector3: return Vector3(0, y - 0.03 - 0.19 * t * t - 0.03 * t, 0.16 + 0.52 * t)
	var radius := func (t: float) -> float: return 0.13 + 0.04 * sin(t * PI * 0.8) - 0.15 * pow(t, 1.6)
	var bands := [[0.0, 0.42, GOLD], [0.42, 0.72, ORANGE], [0.72, 1.0, CREAM]]
	for band: Array in bands:
		var t0: float = band[0]; var t1: float = band[1]; var col: Color = band[2]
		var bp := bs.add_painter(func (p, n, v, w): return col.lightened(clampf(n.y, 0.0, 1.0) * 0.2).darkened(clampf(-n.y, 0.0, 1.0) * 0.25))
		var pts: Array = []; var rs: Array = []
		for k in range(5):
			var t := lerpf(t0, t1, k / 4.0)
			pts.append(axis.call(t)); rs.append(maxf(radius.call(t), 0.01) * (0.97 if k == 0 or k == 4 else 1.0))
		bs.tube(pts, rs, bp, {"sides": 14, "per": 2, "flat": 1.25, "side": Vector3.RIGHT, "square": 0.3, "cap0": t0 == 0.0, "cap1": t1 == 1.0, "cap_len": 0.35 if t0 == 0.0 else 1.6})
	var seam := bs.add_painter(func (p, n, v, w): return Color("#8a4a10"))
	for t: float in [0.42, 0.72]:
		var c: Vector3 = axis.call(t); var c2: Vector3 = axis.call(t + 0.01)
		var r: float = radius.call(t)
		bs.tube([c, c2], [r * 0.985, r * 0.985], seam, {"sides": 14, "per": 1, "flat": 1.25, "side": Vector3.RIGHT, "square": 0.3, "cap0": false, "cap1": false})
	for k in range(9):
		var ang := lerpf(-1.2, 1.2, fposmod(k * 0.618, 1.0))
		var at := Vector3(sin(ang) * 0.1, y + cos(ang) * 0.09, -0.08 + (k % 3) * 0.06)
		bs.crystal(at, Vector3(sin(ang), cos(ang) + 0.3, 0.25).normalized(), 0.08 + 0.05 * (k % 2), 0.018, spike, 5, k)
	part(root, "Body", bs, shiny)
	var hc := _head(Vector3(0, y + 0.02, -0.21), func (p, n, v, w): return DARK.lightened(clampf(n.y, 0.0, 1.0) * 0.3), 0.07, Color("#120604"))
	var w := wings(Vector3(0, y + 0.09, -0.02), 0.64, Color("#ffcf7a"), Color("#a85a10"))
	var legs := dangling_legs(Vector3(0, y - 0.06, -0.03), Color("#1a0a06"), 0.018)
	_launch(Vector3(0, y - 0.24, 0.74))
	var node := _finish({"head": hc[0], "core": hc[1], "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": w}, 1.2)
	return _with_visual(node, hc[0], legs[0], legs[1], w)
