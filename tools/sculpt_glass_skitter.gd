extends "res://tools/creature_kit.gd"
## The Glass Skitter, sculpted by hand: a six-legged crystal crawler that haunts the
## caravan roads. Its core is its cluster of glowing eyes.

const SLATE := Color("#3d3b3f")
const SLATE_LIGHT := Color("#68646a")
const SLATE_DARK := Color("#1f1e22")
const QUARTZ := Color("#cfe9f0")
const QUARTZ_DEEP := Color("#5d93a8")
const AMETHYST := Color("#b48ae6")
const AMETHYST_DEEP := Color("#4b2c78")
const AMBER := Color("#ffb347")

var crystal_low: Color = QUARTZ_DEEP
var crystal_high: Color = QUARTZ


func _init() -> void:
	super("res://assets/cast/stone_detail_gray.png")
	material.uv1_scale = Vector3(3.5, 3.5, 3.5)
	glow.albedo_color = AMBER.darkened(0.2); glow.emission = AMBER
	glow.emission_energy_multiplier = 1.0


static func shell(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var grain := Sculpt.fbm(p * 6.0)
	var c := SLATE.lerp(SLATE_LIGHT, clampf(0.45 + grain * 0.9 + n.y * 0.25, 0.0, 1.0))
	return c.lerp(SLATE_DARK, clampf(-w, 0.0, 1.0) * 0.5 + clampf(-n.y, 0.0, 1.0) * 0.45)


func crystal_painter() -> Callable:
	var low := crystal_low; var high := crystal_high
	return func (p: Vector3, n: Vector3, v: float, _w: float) -> Color:
		var c := low.lerp(high, clampf(v * 1.1 + n.y * 0.2, 0.0, 1.0))
		return c.lightened(clampf(Sculpt.noise(n * 3.0 + p * 2.0) * 0.25, 0.0, 0.25))


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GlassSkitter"
	match variant:
		"crab": return _crab()
		"spider": return _spider()
		"geode": return _geode()
	return null


## Six legs from hips, each: femur up to the knee, then a shin down to a pointed foot.
## Returns [hips, knees].
func _legs(spread: float, lift: float, reach: float, thick: float, glassy: bool, spikes: bool) -> Array:
	var hips: Array = []; var knees: Array = []
	var zs := [-0.29, 0.0, 0.29]
	for row in range(3):
		for side in [-1.0, 1.0]:
			var label := "%d%s" % [row, "L" if side < 0 else "R"]
			var hip_at := Vector3(0.23 * side, 0.45, zs[row])
			var fan := (row - 1) * 0.55
			var out := Vector3(side * cos(fan), 0, sin(fan)).normalized()
			var knee_at := hip_at + out * spread + Vector3(0, lift, 0)
			var foot_at := knee_at + out * reach * 0.45 + Vector3(0, -knee_at.y + 0.02, 0)
			var hip := joint(root, "Hip" + label, hip_at)
			var fs := Sculpt.new(); var fp := fs.add_painter(shell)
			fs.tube([hip_at - out * 0.05, hip_at.lerp(knee_at, 0.5) + Vector3(0, 0.06, 0), knee_at], [thick, thick * 0.95, thick * 0.8], fp, {"sides": 7, "per": 3, "cap_rings": 2})
			part(hip, "Femur", fs)
			var knee := joint(hip, "Knee", knee_at)
			var ss := Sculpt.new(); var sp := ss.add_painter(shell)
			var mid := knee_at.lerp(foot_at, 0.45) + out * 0.06
			if glassy:
				ss.blob(knee_at, Vector3.ONE * thick * 1.1, sp, {"lat": 5, "lon": 8})
				part(knee, "Knuckle", ss)
				var gs := Sculpt.new(); var gp := gs.add_painter(crystal_painter())
				gs.tube([knee_at, mid, foot_at], [thick * 0.75, thick * 0.6, thick * 0.12], gp, {"sides": 6, "per": 3, "cap_rings": 1, "facet": true})
				part(knee, "GlassShin", gs, gloss)
			else:
				ss.tube([knee_at, mid, foot_at + Vector3(0, 0.03, 0)], [thick * 0.8, thick * 0.65, thick * 0.3], sp, {"sides": 7, "per": 3, "cap_rings": 1})
				part(knee, "Shin", ss)
				var cs := Sculpt.new(); var cp := cs.add_painter(crystal_painter())
				cs.crystal(foot_at + Vector3(0, 0.06, 0), Vector3(0, -1, 0) + out * 0.2, 0.09, thick * 0.32, cp)
				if spikes: cs.crystal(knee_at, Vector3(0, 1, 0) + out * 0.4, 0.16, thick * 0.45, cp)
				part(knee, "CrystalTips", cs, gloss)
			hips.append(hip); knees.append(knee)
	return [hips, knees]


func _eyes_core(head: Node3D, spots: Array, size: float) -> MeshInstance3D:
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for k in range(spots.size()): es.blob(spots[k], Vector3.ONE * size * (1.0 if k < 2 else 0.6), white, {"lat": 4, "lon": 7})
	var core := part(head, "GlowingEyes", es, glow)
	core.material_override = glow
	return core


## A: a slate-shelled crab with a ridge of quartz shards on its back and crystal-tipped
## pincers.
func _crab() -> Node3D:
	var body := Sculpt.new(); var sp := body.add_painter(shell)
	body.rock(Vector3(0, 0.52, 0.02), Vector3(0.44, 0.2, 0.5), sp, {"lat": 6, "lon": 12, "lump": 0.12})
	body.blob(Vector3(0, 0.42, 0.02), Vector3(0.34, 0.12, 0.42), sp, {"lat": 6, "lon": 12})
	part(root, "Carapace", body)
	var cs := Sculpt.new(); var cp := cs.add_painter(crystal_painter())
	var shards := [[0.0, 0.05, 0.55, 0.0], [-0.14, -0.12, 0.42, -0.35], [0.15, -0.1, 0.45, 0.35], [-0.08, 0.2, 0.38, -0.2], [0.1, 0.22, 0.4, 0.25], [-0.25, 0.08, 0.3, -0.7], [0.26, 0.06, 0.32, 0.7], [0.0, -0.28, 0.3, 0.0], [0.0, 0.34, 0.28, 0.1]]
	for sh in shards:
		var base := Vector3(sh[0], 0.62, sh[1])
		cs.crystal(base, Vector3(sh[3] * 0.8, 1.0, sh[1] * 0.8), sh[2], 0.06 + sh[2] * 0.08, cp, 6, sh[0] * 3.0)
	part(root, "QuartzRidge", cs, gloss)
	var head := joint(root, "Head", Vector3(0, 0.45, -0.46))
	var hs := Sculpt.new(); var hp := hs.add_painter(shell)
	hs.rock(Vector3(0, 0.48, -0.56), Vector3(0.2, 0.12, 0.15), hp, {"lat": 5, "lon": 9, "lump": 0.1})
	var claws := Sculpt.new(); var clp := claws.add_painter(crystal_painter())
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.12 * side, 0.44, -0.62), Vector3(0.2 * side, 0.4, -0.76), Vector3(0.1 * side, 0.36, -0.88)], [0.045, 0.04, 0.03], hp, {"sides": 7, "per": 3, "cap_rings": 1})
		claws.crystal(Vector3(0.1 * side, 0.36, -0.88), Vector3(-0.6 * side, -0.2, -0.4), 0.12, 0.025, clp)
	part(head, "Head", hs)
	part(head, "PincerTips", claws, gloss)
	var core := _eyes_core(head, [Vector3(-0.07, 0.53, -0.69), Vector3(0.07, 0.53, -0.69), Vector3(-0.13, 0.52, -0.64), Vector3(0.13, 0.52, -0.64)], 0.03)
	var legs := _legs(0.38, 0.1, 0.6, 0.055, false, true)
	return _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.35)


## B: a dark spider whose whole abdomen is a cut gem glowing from inside, on long glass legs.
func _spider() -> Node3D:
	crystal_low = Color("#a3561c"); crystal_high = Color("#ffd58a")
	var body := Sculpt.new(); var sp := body.add_painter(shell)
	body.blob(Vector3(0, 0.5, -0.12), Vector3(0.24, 0.15, 0.28), sp, {"lat": 7, "lon": 12, "lump": 0.05})
	body.tube([Vector3(0, 0.52, 0.08), Vector3(0, 0.56, 0.18)], [0.08, 0.07], sp, {"sides": 8})
	part(root, "Thorax", body)
	var gem := Sculpt.new()
	var gp := gem.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var facet := Sculpt.noise(n * 4.0 + Vector3(3, 1, 2))
		var c := Color("#b8601c").lerp(Color("#ffcf7a"), clampf(0.45 + n.y * 0.35 + facet * 0.6, 0.0, 1.0))
		return c.lightened(smoothstep(0.42, 0.6, facet) * 0.45))
	gem.rock(Vector3(0, 0.68, 0.45), Vector3(0.36, 0.3, 0.42), gp, {"lat": 6, "lon": 9, "lump": 0.06, "basis": Basis(Vector3.RIGHT, -0.35)})
	var gem_glass := gloss.duplicate()
	gem_glass.roughness = 0.06
	gem_glass.emission = Color("#ff8a2a")
	gem_glass.emission_energy_multiplier = 0.55
	part(root, "GemAbdomen", gem, gem_glass)
	var head := joint(root, "Head", Vector3(0, 0.45, -0.38))
	var hs := Sculpt.new(); var hp := hs.add_painter(shell)
	hs.blob(Vector3(0, 0.5, -0.42), Vector3(0.14, 0.11, 0.12), hp, {"lat": 6, "lon": 10})
	var fangs := Sculpt.new(); var fp := fangs.add_painter(crystal_painter())
	for side in [-1.0, 1.0]: fangs.crystal(Vector3(0.05 * side, 0.43, -0.5), Vector3(0.1 * side, -1.0, -0.4), 0.12, 0.022, fp)
	part(head, "Head", hs)
	part(head, "Fangs", fangs, gloss)
	var core := _eyes_core(head, [Vector3(-0.045, 0.56, -0.51), Vector3(0.045, 0.56, -0.51), Vector3(-0.09, 0.55, -0.48), Vector3(0.09, 0.55, -0.48), Vector3(-0.03, 0.6, -0.48), Vector3(0.03, 0.6, -0.48)], 0.026)
	var legs := _legs(0.42, 0.22, 0.85, 0.045, true, false)
	return _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.3)


## C: a round beetle whose shell is a split-open geode full of purple crystals.
func _geode() -> Node3D:
	crystal_low = AMETHYST_DEEP; crystal_high = AMETHYST
	var body := Sculpt.new(); var sp := body.add_painter(shell)
	var inner := body.add_painter(func (p, n, v, w): return Color("#e9e2ef").lerp(Color("#8a7a96"), clampf(0.5 + Sculpt.noise(p * 20.0), 0.0, 1.0)))
	for side in [-1.0, 1.0]:
		body.rock(Vector3(0.2 * side, 0.58, 0.05), Vector3(0.28, 0.26, 0.5), sp, {"lat": 6, "lon": 12, "lump": 0.12, "basis": Basis(Vector3.BACK, 0.22 * side)})
	body.blob(Vector3(0, 0.6, 0.05), Vector3(0.14, 0.18, 0.44), inner, {"lat": 6, "lon": 12, "lump": 0.1})
	body.blob(Vector3(0, 0.42, 0.04), Vector3(0.36, 0.12, 0.44), sp, {"lat": 6, "lon": 12})
	part(root, "GeodeShell", body)
	var cs := Sculpt.new(); var cp := cs.add_painter(crystal_painter())
	for k in range(11):
		var z := -0.36 + k * 0.072
		var lean := 0.35 if k % 2 == 0 else -0.35
		cs.crystal(Vector3(lean * 0.12, 0.7, z), Vector3(lean, 1.0, 0.0), 0.16 + 0.12 * absf(sin(k * 1.7)), 0.05, cp, 6, k)
	part(root, "Amethyst", cs, gloss)
	var head := joint(root, "Head", Vector3(0, 0.45, -0.46))
	var hs := Sculpt.new(); var hp := hs.add_painter(shell)
	hs.rock(Vector3(0, 0.47, -0.55), Vector3(0.21, 0.13, 0.15), hp, {"lat": 5, "lon": 9, "lump": 0.1})
	var horn := Sculpt.new(); var hc := horn.add_painter(crystal_painter())
	horn.crystal(Vector3(0, 0.55, -0.62), Vector3(0, 0.8, -1.0), 0.32, 0.055, hc)
	for side in [-1.0, 1.0]: horn.crystal(Vector3(0.1 * side, 0.4, -0.66), Vector3(0.3 * side, -0.3, -1.0), 0.12, 0.025, hc)
	part(head, "Head", hs)
	part(head, "CrystalHorn", horn, gloss)
	var core := _eyes_core(head, [Vector3(-0.1, 0.52, -0.67), Vector3(0.1, 0.52, -0.67)], 0.032)
	var legs := _legs(0.3, 0.05, 0.5, 0.06, false, false)
	return _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.4)
