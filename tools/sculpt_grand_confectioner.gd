extends "res://tools/creature_kit.gd"
## The Grand Confectioner, boss of S'morewood: an enchanted copper confectionery automaton that
## winds up its beaters before each attack. Three takes, all riveted copper and brass with a
## wind-up key in the back and a glowing heart of sugar-furnace light.
## A: a colossal stand mixer walking on piston legs, its bowl-belly full of batter, whisks for hands.
## B: a tall clockwork pastry chef in an enamel toque, with a brass moustache, an oven-window
##    chest, a rolling-pin arm and a whisk arm.
## C: a candy-factory engine: a boiler chest, glass syrup tanks on its shoulders, a hopper head
##    spilling sweets, a ladle arm and a beater arm.

const COPPER := Color("#a8582a")
const COPPER_HI := Color("#e8935a")
const PATINA := Color("#4f8f7c")
const BRASS := Color("#c99a36")
const BRASS_HI := Color("#f0cf6a")
const ENAMEL := Color("#f4eee2")
const IRON := Color("#3a3634")
const FURNACE := Color("#ff9a3a")
const BATTER := Color("#f3d9a6")

var metal: StandardMaterial3D
var enamel_mat: StandardMaterial3D
var glass_mat: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	metal = StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.vertex_color_is_srgb = true
	metal.metallic = 0.75
	metal.roughness = 0.32
	metal.metallic_specular = 0.8
	enamel_mat = StandardMaterial3D.new()
	enamel_mat.vertex_color_use_as_albedo = true
	enamel_mat.vertex_color_is_srgb = true
	enamel_mat.roughness = 0.2
	enamel_mat.metallic_specular = 0.7
	glass_mat = StandardMaterial3D.new()
	glass_mat.vertex_color_use_as_albedo = true
	glass_mat.vertex_color_is_srgb = true
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.metallic_specular = 1.0
	glow.albedo_color = FURNACE.darkened(0.2); glow.emission = FURNACE
	glow.emission_energy_multiplier = 1.0


static func copper(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := COPPER.lerp(COPPER_HI, clampf(0.35 + n.y * 0.4 + Sculpt.fbm(p * 4.0) * 0.4, 0.0, 1.0))
	# A little green patina gathered in the hollows and underneath.
	c = c.lerp(PATINA, smoothstep(0.55, 0.8, Sculpt.noise(p * 6.0) + clampf(-n.y, 0.0, 1.0) * 0.4) * 0.45)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.3)


static func brass(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return BRASS.lerp(BRASS_HI, clampf(0.35 + n.y * 0.5, 0.0, 1.0)).darkened(clampf(-n.y, 0.0, 1.0) * 0.3)


static func iron(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return IRON.lightened(clampf(n.y, 0.0, 1.0) * 0.2 + absf(Sculpt.noise(p * 10.0)) * 0.08)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GrandConfectioner"
	match variant:
		"mixer": return _mixer()
		"chef": return _chef()
		"factory": return _factory()
	return null


func _with_visual(node: Node3D, head: Node3D) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node


## Rivets in a ring round `center` in the plane facing `normal`.
func rivets(s: Sculpt, painter: int, center: Vector3, radius: float, normal: Vector3, count: int, size := 0.022) -> void:
	var n := normal.normalized()
	var a := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized(); var b := n.cross(a)
	for k in range(count):
		var ang := TAU * k / count
		s.blob(center + (a * cos(ang) + b * sin(ang)) * radius, Vector3.ONE * size, painter, {"lat": 3, "lon": 6})


## A balloon whisk: a brass handle along `axis` from `at`, then wire loops bulging out to a tip.
func whisk(s: Sculpt, handle: int, wire: int, at: Vector3, axis: Vector3, length: float, width: float) -> void:
	var d := axis.normalized()
	var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized(); var b := d.cross(a)
	s.tube([at, at + d * length * 0.35], [width * 0.22, width * 0.2], handle, {"sides": 10, "per": 1, "cap_rings": 2})
	var base := at + d * length * 0.35
	for k in range(4):
		var ang := PI * k / 4.0
		var side := a * cos(ang) + b * sin(ang)
		var loop: Array = []
		for i in range(9):
			var t := i / 8.0
			var bulge := sin(t * PI) * width * (0.5 + 0.5 * t)
			loop.append(base + d * length * 0.65 * sin(t * PI * 0.5) + side * bulge * (1.0 if i <= 4 else 1.0) * (1.0 if true else 0.0))
		var back: Array = []
		for i in range(9):
			var t := i / 8.0
			var bulge := sin(t * PI) * width * (0.5 + 0.5 * t)
			back.append(base + d * length * 0.65 * sin(t * PI * 0.5) - side * bulge)
		back.reverse()
		var full: Array = loop.slice(0, 8) + [base + d * length * 0.68] + back.slice(1)
		s.tube(full, full.map(func (_q): return width * 0.035), wire, {"sides": 5, "per": 2, "cap_rings": 1})


## A round gauge with a dial face and a needle.
func gauge(s: Sculpt, rim: int, face: int, needle: int, at: Vector3, normal: Vector3, r: float) -> void:
	var n := normal.normalized()
	s.tube([at - n * 0.03, at + n * 0.02], [r, r], rim, {"sides": 14, "per": 1, "cap_len": 0.2, "cap_rings": 1})
	s.tube([at + n * 0.02, at + n * 0.025], [r * 0.82, r * 0.82], face, {"sides": 14, "per": 1, "cap_len": 0.1, "cap_rings": 1})
	var up := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP).normalized()
	s.tube([at + n * 0.03, at + n * 0.03 + up.rotated(n, 0.7) * r * 0.7], [0.008, 0.004], needle, {"sides": 4, "per": 1, "cap_rings": 1})


## The wind-up key in the back.
func windup_key(s: Sculpt, painter: int, at: Vector3, size: float) -> void:
	s.tube([at, at + Vector3(0, 0, size * 0.6)], [size * 0.08, size * 0.08], painter, {"sides": 8, "per": 1})
	for side in [-1.0, 1.0]:
		s.tube([at + Vector3(0, 0, size * 0.6), at + Vector3(side * size * 0.35, size * 0.12, size * 0.66), at + Vector3(side * size * 0.45, 0, size * 0.66), at + Vector3(side * size * 0.35, -size * 0.12, size * 0.66), at + Vector3(0, 0, size * 0.6)], [size * 0.06, size * 0.07, size * 0.07, size * 0.07, size * 0.06], painter, {"sides": 7, "per": 3, "flat": 0.5, "side": Vector3.BACK})


## Two piston legs: copper thigh, brass knee, iron shin, riveted boot.
func piston_legs(hip_y: float, width: float, boot: Vector3) -> Array:
	var hips: Array = []; var knees: Array = []
	for side in [-1.0, 1.0]:
		var hip_at := Vector3(width * side, hip_y, 0.02)
		var hip := joint(root, ("Left" if side < 0 else "Right") + "Hip", hip_at)
		var knee_at := Vector3(width * 1.05 * side, hip_y * 0.5, -0.04)
		var ts := Sculpt.new(); var cp := ts.add_painter(copper); var bp := ts.add_painter(brass)
		ts.tube([hip_at, knee_at], [0.17, 0.14], cp, {"sides": 12, "per": 1, "cap_rings": 2})
		rivets(ts, bp, hip_at.lerp(knee_at, 0.5), 0.155, Vector3.UP, 8, 0.018)
		part(hip, "Thigh", ts, metal)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var ip := ss.add_painter(iron); var bb := ss.add_painter(brass); var cc := ss.add_painter(copper)
		ss.blob(knee_at, Vector3.ONE * 0.15, bb, {"lat": 6, "lon": 10})
		var foot := Vector3(knee_at.x, 0.1, knee_at.z - 0.02)
		ss.tube([knee_at, foot], [0.09, 0.1], ip, {"sides": 10, "per": 1})
		ss.tube([knee_at + Vector3(0.1 * side, -0.05, 0.06), foot + Vector3(0.1 * side, 0.12, 0.06)], [0.035, 0.035], bb, {"sides": 8, "per": 1})
		slab(ss, cc, Vector3(knee_at.x, boot.y * 0.5, knee_at.z - 0.08), Vector3(boot.x, boot.y, boot.z), Basis.IDENTITY, 0.4, 0.0)
		rivets(ss, bb, Vector3(knee_at.x, boot.y * 0.5, knee_at.z - 0.08 - boot.z * 0.5), boot.y * 0.32, Vector3.FORWARD, 5, 0.016)
		part(knee, "Shin", ss, metal)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


## Two arms: shoulder ball, copper upper arm, brass elbow, and a forearm the caller fills in.
## Returns [shoulders, elbows, forearm sculpts, hand points].
func arms(shoulder_y: float, width: float) -> Array:
	var shoulders: Array = []; var elbows: Array = []; var hands: Array = []
	for side in [-1.0, 1.0]:
		var at := Vector3(width * side, shoulder_y, 0.0)
		var shoulder := joint(root, ("Left" if side < 0 else "Right") + "Shoulder", at)
		var elbow_at := at + Vector3(0.14 * side, -0.48, -0.04)
		var us := Sculpt.new(); var cp := us.add_painter(copper); var bp := us.add_painter(brass)
		us.blob(at, Vector3(0.2, 0.18, 0.2), cp, {"lat": 7, "lon": 12})
		rivets(us, bp, at + Vector3(0, 0.02, 0), 0.19, Vector3.UP, 8, 0.02)
		us.tube([at, elbow_at], [0.12, 0.1], cp, {"sides": 12, "per": 1})
		part(shoulder, "UpperArm", us, metal)
		var elbow := joint(shoulder, "Forearm", elbow_at)
		shoulders.append(shoulder); elbows.append(elbow); hands.append(elbow_at + Vector3(0.03 * side, -0.42, -0.12))
	return [shoulders, elbows, hands]


## Fills in a whisk forearm on `elbow` ending at `hand`.
func whisk_arm(elbow: Node3D, elbow_at: Vector3, hand: Vector3, length: float, width: float) -> void:
	var fs := Sculpt.new(); var bp := fs.add_painter(brass); var cp := fs.add_painter(copper); var wire := fs.add_painter(func (p, n, v, w): return Color("#d8d8dc").lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	fs.blob(elbow_at, Vector3.ONE * 0.1, bp, {"lat": 6, "lon": 10})
	fs.tube([elbow_at, hand], [0.09, 0.11], cp, {"sides": 12, "per": 1})
	fs.tube([hand - (hand - elbow_at).normalized() * 0.05, hand + (hand - elbow_at).normalized() * 0.04], [0.13, 0.12], bp, {"sides": 12, "per": 1, "ridges": 12, "ridge": 0.08})
	whisk(fs, bp, wire, hand, (hand - elbow_at).normalized(), length, width)
	part(elbow, "WhiskForearm", fs, metal)


# -------------------------------------------------------------------- A: mixer

## A: a colossal walking stand mixer. Its belly is a copper mixing bowl brimming with batter
## that drips down the sides; its head is the mixer's domed motor hood with a glowing porthole
## eye and a brass speed lever; both hands are spinning balloon whisks.
func _mixer() -> Node3D:
	var enamel := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return ENAMEL.darkened(clampf(-n.y, 0.0, 1.0) * 0.25).lerp(Color("#e8d8c0"), absf(Sculpt.noise(p * 5.0)) * 0.3)
	var bs := Sculpt.new(); var cp := bs.add_painter(copper); var bp := bs.add_painter(brass)
	var ns := Sculpt.new(); var ep := ns.add_painter(enamel)
	var fs := Sculpt.new(); var batter := fs.add_painter(func (p, n, v, w): return BATTER.lerp(Color("#d9b06a"), clampf(-n.y * 0.5 + Sculpt.noise(p * 8.0) * 0.4, 0.0, 1.0)))
	# The mixer's base plate is its hips, and its neck column rises at the back.
	slab(ns, ep, Vector3(0, 0.98, 0.0), Vector3(0.82, 0.22, 0.95), Basis.IDENTITY, 0.6, 0.02)
	bs.tube([Vector3(-0.42, 0.98, -0.4), Vector3(0.42, 0.98, -0.4)], [0.035, 0.035], bp, {"sides": 8, "per": 1})
	ns.tube([Vector3(0, 1.05, 0.34), Vector3(0, 1.5, 0.38), Vector3(0, 1.92, 0.34)], [0.24, 0.22, 0.23], ep, {"sides": 16, "per": 2, "flat": 1.25, "side": Vector3.RIGHT, "square": 0.45, "cap_len": 0.4})
	# A brass yoke across the top of the column carries the shoulders.
	bs.tube([Vector3(-0.5, 1.86, 0.3), Vector3(0, 1.9, 0.34), Vector3(0.5, 1.86, 0.3)], [0.07, 0.08, 0.07], bp, {"sides": 10, "per": 2})
	# The bowl clamp and the copper mixing bowl for a belly, brimming with batter. (Profiles run
	# rim-first so the surfaces face outward.)
	bs.tube([Vector3(0, 1.08, -0.15), Vector3(0, 1.12, -0.15)], [0.3, 0.3], bp, {"sides": 18, "per": 1, "cap_rings": 1})
	bs.lathe(Vector3(0, 1.1, -0.17), [Vector2(0.47, 0.58), Vector2(0.5, 0.62), Vector2(0.57, 0.64), Vector2(0.53, 0.6), Vector2(0.5, 0.4), Vector2(0.4, 0.16), Vector2(0.22, 0.02), Vector2(0, 0.0)], cp, {"sides": 24})
	bs.lathe(Vector3(0, 1.1, -0.17), [Vector2(0.53, 0.37), Vector2(0.56, 0.35), Vector2(0.56, 0.31), Vector2(0.53, 0.29)], bp, {"sides": 24})
	fs.lathe(Vector3(0, 1.1, -0.17), [Vector2(0, 0.69), Vector2(0.1, 0.68), Vector2(0.24, 0.655), Vector2(0.38, 0.63), Vector2(0.48, 0.59)], batter, {"sides": 24, "wobble": 0.15})
	# Thick batter slopping over the rim in a few heavy drips.
	for ang: float in [-2.2, -1.2, -0.4, 0.9, 2.4]:
		var out := Vector3(cos(ang), 0, sin(ang))
		var top := Vector3(0, 1.72, -0.17) + out * 0.55
		var drop := 0.1 + 0.08 * absf(sin(ang * 3.0))
		fs.blob(top + Vector3(0, 0.02, 0), Vector3(0.12, 0.05, 0.12), batter, {"lat": 5, "lon": 9, "basis": Basis(Vector3.UP, -ang)})
		fs.tube([top + out * 0.02, top + out * 0.05 + Vector3(0, -drop * 0.5, 0), top + out * 0.06 + Vector3(0, -drop, 0)], [0.08, 0.06, 0.065], batter, {"sides": 9, "per": 3})
	windup_key(bs, bp, Vector3(0, 1.55, 0.6), 0.5)
	rivets(bs, bp, Vector3(0, 1.4, 0.62), 0.12, Vector3.BACK, 8, 0.016)
	part(root, "Body", bs, metal)
	part(root, "Enamel", ns, enamel_mat)
	part(root, "Batter", fs, material)
	# The power cord trails behind like a tail, ending in a brass plug.
	var tails: Array = []
	var parent: Node3D = root; var at := Vector3(0, 1.0, 0.48)
	var cord_steps := [Vector3(0, -0.22, 0.22), Vector3(0.08, -0.3, 0.2), Vector3(0.05, -0.2, 0.28), Vector3(-0.06, -0.08, 0.3)]
	for k in range(cord_steps.size()):
		var node := joint(parent, "Cord%d" % k, at)
		var next: Vector3 = at + cord_steps[k]
		next.y = maxf(next.y, 0.08)
		var cs := Sculpt.new(); var cc := cs.add_painter(func (p, n, v, w): return Color("#2a2420").lightened(clampf(n.y, 0.0, 1.0) * 0.25))
		cs.tube([at, at.lerp(next, 0.5) + Vector3(0, -0.02, 0), next], [0.045, 0.045, 0.045], cc, {"sides": 8, "per": 3})
		if k == cord_steps.size() - 1:
			var pb := cs.add_painter(brass)
			var d := (next - at).normalized()
			cs.tube([next, next + d * 0.14], [0.08, 0.07], pb, {"sides": 10, "per": 1, "cap_rings": 2})
			for side in [-1.0, 1.0]: cs.tube([next + d * 0.14 + Vector3(0.03 * side, 0, 0), next + d * 0.24 + Vector3(0.03 * side, 0, 0)], [0.012, 0.012], pb, {"sides": 5, "per": 1})
		part(node, "Cord", cs, metal)
		tails.append(node); parent = node; at = next
	# The head: the mixer's rounded motor hood tilting forward over the bowl, with copper vent
	# grooves, a brass speed lever, a big glowing porthole eye in its brass-rimmed face, and the
	# flat beater on its shaft stirring the batter below.
	var head := joint(root, "Head", Vector3(0, 2.0, 0.3))
	var hs := Sculpt.new(); var hep := hs.add_painter(enamel); var hbp := hs.add_painter(brass); var hcp := hs.add_painter(copper)
	hs.tube([Vector3(0, 2.12, 0.42), Vector3(0, 2.18, 0.12), Vector3(0, 2.14, -0.22), Vector3(0, 2.06, -0.48)], [0.2, 0.27, 0.27, 0.22], hep, {"sides": 20, "per": 3, "flat": 1.05, "side": Vector3.RIGHT, "cap_len": 0.55, "cap_rings": 4})
	for k in range(4):
		var z := 0.22 - k * 0.09
		hs.tube([Vector3(-0.27, 2.2, z), Vector3(0, 2.46, z), Vector3(0.27, 2.2, z)], [0.012, 0.014, 0.012], hcp, {"sides": 6, "per": 3})
	hs.tube([Vector3(-0.29, 2.02, 0.3), Vector3(0.29, 2.02, 0.3)], [0.05, 0.05], hbp, {"sides": 10, "per": 1})
	hs.tube([Vector3(0.27, 2.14, 0.0), Vector3(0.36, 2.2, -0.04), Vector3(0.42, 2.3, -0.06)], [0.024, 0.02, 0.018], hbp, {"sides": 7, "per": 3})
	hs.blob(Vector3(0.42, 2.32, -0.06), Vector3.ONE * 0.04, hbp, {"lat": 5, "lon": 8})
	var face := Vector3(0, 2.07, -0.6)
	hs.lathe(face, [Vector2(0.14, 0.02), Vector2(0.17, 0.0), Vector2(0.17, -0.03), Vector2(0.14, -0.04)], hbp, {"sides": 20, "basis": Basis(Vector3.RIGHT, PI * 0.5 - 0.15)})
	rivets(hs, hbp, face + Vector3(0, 0.0, 0.015), 0.205, Vector3(0, 0.15, -1), 10, 0.014)
	# Brass brows over the porthole make it scowl.
	for side in [-1.0, 1.0]:
		hs.tube([face + Vector3(0.04 * side, 0.17, -0.02), face + Vector3(0.16 * side, 0.2, 0.02)], [0.022, 0.016], hbp, {"sides": 7, "per": 1})
	# The beater: a brass shaft down into the bowl and a flat paddle buried in batter.
	var beater_at := Vector3(0, 1.94, -0.28)
	hs.tube([beater_at, beater_at + Vector3(0, -0.18, 0.02)], [0.04, 0.035], hbp, {"sides": 10, "per": 1})
	hs.tube([beater_at + Vector3(-0.12, -0.18, 0.02), beater_at + Vector3(0, -0.32, 0.03), beater_at + Vector3(0.12, -0.18, 0.02)], [0.025, 0.03, 0.025], hbp, {"sides": 8, "per": 3})
	part(head, "MotorHood", hs, enamel_mat)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	es.blob(face + Vector3(0, 0, -0.01), Vector3(0.135, 0.135, 0.05), ew, {"lat": 7, "lon": 14, "basis": Basis(Vector3.RIGHT, -0.15)})
	var core := part(head, "Porthole", es, glow); core.material_override = glow
	var ps := Sculpt.new(); var pp := ps.add_painter(func (p, n, v, w): return Color("#3a1404"))
	ps.blob(face + Vector3(0, 0, -0.055), Vector3(0.045, 0.06, 0.015), pp, {"lat": 4, "lon": 8, "basis": Basis(Vector3.RIGHT, -0.15)})
	part(head, "Pupil", ps, metal)
	var a := arms(1.86, 0.55)
	for i in range(2):
		var elbow: Node3D = a[1][i]
		whisk_arm(elbow, elbow.position + (a[0][i] as Node3D).position, a[2][i], 0.75, 0.26)
	var legs := piston_legs(0.95, 0.26, Vector3(0.32, 0.22, 0.48))
	var node := _finish({"head": head, "core": core, "arms": a[0], "forearms": a[1], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.15)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": tails.map(func (n): return node.get_path_to(n)), "features": {}}
	node.set_meta("rig_bindings", rig)
	return node


# --------------------------------------------------------------------- B: chef

## B: a tall clockwork pastry chef: copper body under a white enamel apron, an oven-door chest
## with a glowing window and a cake inside, a riveted copper head with a brass handlebar
## moustache and a tall pleated enamel toque, a rolling pin for one arm and a whisk for the other.
func _chef() -> Node3D:
	var bs := Sculpt.new(); var cp := bs.add_painter(copper); var bp := bs.add_painter(brass)
	var apron := bs.add_painter(func (p, n, v, w): return ENAMEL.darkened(clampf(-n.y, 0.0, 1.0) * 0.25 + absf(Sculpt.noise(p * 14.0)) * 0.05))
	var ip := bs.add_painter(iron)
	bs.tube([Vector3(0, 0.95, 0.02), Vector3(0, 1.3, 0.0), Vector3(0, 1.7, -0.02), Vector3(0, 2.0, 0.0)], [0.34, 0.36, 0.42, 0.3], cp, {"sides": 18, "per": 3, "flat": 1.15, "side": Vector3.RIGHT})
	# Apron: a skirt panel from the waist down and a bib over the chest.
	bs.lathe(Vector3(0, 0.62, 0.02), [Vector2(0.37, 0.72), Vector2(0.4, 0.5), Vector2(0.46, 0.2), Vector2(0.5, 0.0)], apron, {"sides": 20})
	slab(bs, apron, Vector3(0, 1.62, -0.36), Vector3(0.5, 0.05, 0.55), Basis(Vector3.RIGHT, -PI * 0.5 + 0.08), 0.4, 0.0)
	# Oven door in the chest: iron frame, brass handle.
	slab(bs, ip, Vector3(0, 1.62, -0.4), Vector3(0.36, 0.04, 0.32), Basis(Vector3.RIGHT, -PI * 0.5 + 0.08), 0.4, 0.0)
	bs.tube([Vector3(-0.14, 1.82, -0.44), Vector3(0.14, 1.82, -0.44)], [0.02, 0.02], bp, {"sides": 8, "per": 1})
	rivets(bs, bp, Vector3(0, 1.62, -0.42), 0.22, Vector3(0, 0, -1), 10, 0.016)
	gauge(bs, bp, bs.add_painter(func (p, n, v, w): return ENAMEL), ip, Vector3(0.28, 1.95, -0.3), Vector3(0.4, 0.2, -1), 0.07)
	windup_key(bs, bp, Vector3(0, 1.6, 0.4), 0.55)
	part(root, "Body", bs, metal)
	var ws := Sculpt.new(); var ww := ws.add_painter(func (p, n, v, w): return Color.WHITE)
	ws.blob(Vector3(0, 1.62, -0.42), Vector3(0.14, 0.11, 0.02), ww, {"lat": 5, "lon": 10})
	var core := part(root, "OvenWindow", ws, glow); core.material_override = glow
	var head := joint(root, "Head", Vector3(0, 2.41, 0.0))
	var hs := Sculpt.new(); var hc := hs.add_painter(copper); var hb := hs.add_painter(brass)
	var toque := hs.add_painter(func (p, n, v, w): return ENAMEL.darkened(clampf(-n.y, 0.0, 1.0) * 0.2 + smoothstep(0.8, 0.95, absf(sin(atan2(p.z, p.x) * 6.0))) * 0.12))
	hs.blob(Vector3(0, 2.51, -0.02), Vector3(0.22, 0.24, 0.22), hc, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, 2.0, 0), Vector3(0, 2.3, -0.01)], [0.11, 0.1], hb, {"sides": 10, "per": 1, "ridges": 10, "ridge": 0.1})
	hs.lathe(Vector3(0, 2.64, -0.02), [Vector2(0.2, 0.0), Vector2(0.21, 0.12), Vector2(0.19, 0.3), Vector2(0.26, 0.42), Vector2(0.27, 0.5), Vector2(0.18, 0.56), Vector2(0, 0.58)], toque, {"sides": 18})
	# Handlebar moustache and riveted brow.
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.0, 2.42, -0.22), Vector3(0.1 * side, 2.43, -0.23), Vector3(0.18 * side, 2.46, -0.19), Vector3(0.21 * side, 2.52, -0.15)], [0.035, 0.03, 0.02, 0.012], hb, {"sides": 8, "per": 3})
	hs.tube([Vector3(-0.15, 2.58, -0.19), Vector3(0.15, 2.58, -0.19)], [0.025, 0.025], hb, {"sides": 8, "per": 1})
	part(head, "Head", hs, metal)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.08 * side, 2.52, -0.2), Vector3(0.04, 0.03, 0.02), ew, {"lat": 5, "lon": 8})
	var eyes := part(head, "Eyes", es, glow); eyes.material_override = glow
	var a := arms(1.95, 0.5)
	# Left: a rolling pin; right: a whisk.
	var left_elbow: Node3D = a[1][0]
	var le := left_elbow.position + (a[0][0] as Node3D).position
	var hand: Vector3 = a[2][0]
	var fs := Sculpt.new(); var fb := fs.add_painter(brass); var fc := fs.add_painter(copper)
	var wood := fs.add_painter(func (p, n, v, w): return Color("#e0b47a").lerp(Color("#b8844c"), clampf(Sculpt.noise(p * 12.0) * 0.6 + 0.3, 0.0, 1.0)))
	fs.blob(le, Vector3.ONE * 0.1, fb, {"lat": 6, "lon": 10})
	fs.tube([le, hand], [0.09, 0.11], fc, {"sides": 12, "per": 1})
	fs.tube([hand + Vector3(0, 0.0, 0.35), hand + Vector3(0, 0.0, -0.45)], [0.11, 0.11], wood, {"sides": 14, "per": 1, "cap_len": 0.2, "cap_rings": 1})
	for z in [0.42, -0.52]: fs.tube([hand + Vector3(0, 0, z), hand + Vector3(0, 0, z + signf(z) * 0.14)], [0.035, 0.03], wood, {"sides": 8, "per": 1})
	part(left_elbow, "RollingPin", fs, metal)
	var right_elbow: Node3D = a[1][1]
	whisk_arm(right_elbow, right_elbow.position + (a[0][1] as Node3D).position, a[2][1], 0.6, 0.2)
	var legs := piston_legs(0.95, 0.22, Vector3(0.26, 0.18, 0.42))
	var node := _finish({"head": head, "core": core, "arms": a[0], "forearms": a[1], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.2)
	return _with_visual(node, head)


# ------------------------------------------------------------------ C: factory

## C: a hulking candy-factory engine: a riveted copper boiler chest with a furnace grate glowing
## in it, glass tanks of bright syrup on each shoulder piped into its back, smokestacks puffing
## sugar, a hopper head with sweets spilling over the rim, a ladle arm and a beater arm.
func _factory() -> Node3D:
	var bs := Sculpt.new(); var cp := bs.add_painter(copper); var bp := bs.add_painter(brass); var ip := bs.add_painter(iron)
	bs.tube([Vector3(0, 0.95, 0.05), Vector3(0, 1.4, 0.0), Vector3(0, 1.95, 0.02)], [0.44, 0.5, 0.46], cp, {"sides": 20, "per": 3, "bands": 4, "band": 0.04})
	for y in [1.15, 1.45, 1.75]: rivets(bs, bp, Vector3(0, y, 0.0), 0.5, Vector3.UP, 16, 0.02)
	# Furnace grate in the chest.
	slab(bs, ip, Vector3(0, 1.4, -0.46), Vector3(0.36, 0.05, 0.3), Basis(Vector3.RIGHT, -PI * 0.5), 0.4, 0.0)
	for k in range(4): bs.tube([Vector3(-0.15 + k * 0.1, 1.27, -0.5), Vector3(-0.15 + k * 0.1, 1.53, -0.5)], [0.015, 0.015], ip, {"sides": 6, "per": 1})
	# Smokestacks.
	for side in [-1.0, 1.0]:
		bs.tube([Vector3(0.22 * side, 1.9, 0.3), Vector3(0.22 * side, 2.45, 0.32)], [0.07, 0.08], ip, {"sides": 10, "per": 1, "cap1": false})
		bs.tube([Vector3(0.22 * side, 2.42, 0.32), Vector3(0.22 * side, 2.48, 0.32)], [0.1, 0.1], bp, {"sides": 10, "per": 1})
	gauge(bs, bp, bs.add_painter(func (p, n, v, w): return ENAMEL), ip, Vector3(-0.3, 1.75, -0.38), Vector3(-0.5, 0.2, -1), 0.08)
	windup_key(bs, bp, Vector3(0, 1.4, 0.5), 0.55)
	part(root, "Boiler", bs, metal)
	# Glass syrup tanks on the shoulders.
	var ts := Sculpt.new()
	var pink := ts.add_painter(func (p, n, v, w): return Color("#ff5a9a").lerp(Color("#ffb0d0"), clampf(n.y, 0.0, 1.0) * 0.5))
	var green := ts.add_painter(func (p, n, v, w): return Color("#4adf8a").lerp(Color("#b0ffd0"), clampf(n.y, 0.0, 1.0) * 0.5))
	ts.tube([Vector3(-0.42, 2.0, 0.15), Vector3(-0.42, 2.32, 0.15)], [0.11, 0.11], pink, {"sides": 12, "per": 1})
	ts.tube([Vector3(0.42, 2.0, 0.15), Vector3(0.42, 2.26, 0.15)], [0.11, 0.11], green, {"sides": 12, "per": 1})
	part(root, "Syrup", ts, enamel_mat)
	var gs := Sculpt.new(); var gp := gs.add_painter(func (p, n, v, w): return Color(1, 1, 1, 0.3))
	for side in [-1.0, 1.0]: gs.tube([Vector3(0.42 * side, 1.98, 0.15), Vector3(0.42 * side, 2.4, 0.15)], [0.13, 0.13], gp, {"sides": 14, "per": 1, "cap_len": 0.3})
	part(root, "Tanks", gs, glass_mat)
	var ws := Sculpt.new(); var ww := ws.add_painter(func (p, n, v, w): return Color.WHITE)
	ws.blob(Vector3(0, 1.4, -0.47), Vector3(0.15, 0.11, 0.02), ww, {"lat": 5, "lon": 10})
	var core := part(root, "Furnace", ws, glow); core.material_override = glow
	var head := joint(root, "Head", Vector3(0, 2.05, -0.02))
	var hs := Sculpt.new(); var hc := hs.add_painter(copper); var hb := hs.add_painter(brass)
	hs.lathe(Vector3(0, 2.0, -0.02), [Vector2(0.12, 0.0), Vector2(0.14, 0.12), Vector2(0.32, 0.4), Vector2(0.34, 0.44), Vector2(0.3, 0.44), Vector2(0.12, 0.2)], hc, {"sides": 18})
	var sweets := [Color("#ff4a6a"), Color("#4ac8ff"), Color("#ffd24a"), Color("#9a6aff"), Color("#5ae08a")]
	for k in range(14):
		var c: Color = sweets[k % sweets.size()]
		var sp := hs.add_painter(func (p, n, v, w): return c.lightened(clampf(n.y, 0.0, 1.0) * 0.3))
		var ang := k * 2.4
		var r := 0.08 + fposmod(k * 0.37, 0.2)
		hs.blob(Vector3(cos(ang) * r, 2.42 + fposmod(k * 0.21, 0.06), -0.02 + sin(ang) * r), Vector3(0.05, 0.035, 0.035), sp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.UP, k)})
	rivets(hs, hb, Vector3(0, 2.3, -0.02), 0.26, Vector3.UP, 12, 0.016)
	part(head, "Hopper", hs, metal)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	es.tube([Vector3(-0.14, 2.2, -0.24), Vector3(0.14, 2.2, -0.24)], [0.025, 0.025], ew, {"sides": 8, "per": 1})
	var eyes := part(head, "Visor", es, glow); eyes.material_override = glow
	var a := arms(1.95, 0.62)
	# Left: a big ladle; right: a beater.
	var left_elbow: Node3D = a[1][0]
	var le := left_elbow.position + (a[0][0] as Node3D).position
	var hand: Vector3 = a[2][0]
	var fs := Sculpt.new(); var fb := fs.add_painter(brass); var fc := fs.add_painter(copper); var syrup := fs.add_painter(func (p, n, v, w): return Color("#ff5a9a"))
	fs.blob(le, Vector3.ONE * 0.11, fb, {"lat": 6, "lon": 10})
	fs.tube([le, hand], [0.1, 0.12], fc, {"sides": 12, "per": 1})
	fs.tube([hand, hand + Vector3(0, -0.05, -0.5)], [0.04, 0.035], fb, {"sides": 8, "per": 1})
	fs.lathe(hand + Vector3(0, -0.02, -0.62), [Vector2(0, -0.12), Vector2(0.12, -0.1), Vector2(0.17, -0.02), Vector2(0.18, 0.04), Vector2(0.15, 0.04), Vector2(0.13, -0.02), Vector2(0, -0.04)], fc, {"sides": 16})
	fs.blob(hand + Vector3(0, -0.01, -0.62), Vector3(0.13, 0.03, 0.13), syrup, {"lat": 4, "lon": 10})
	part(left_elbow, "Ladle", fs, metal)
	var right_elbow: Node3D = a[1][1]
	whisk_arm(right_elbow, right_elbow.position + (a[0][1] as Node3D).position, a[2][1], 0.65, 0.22)
	var legs := piston_legs(0.95, 0.28, Vector3(0.34, 0.2, 0.48))
	var node := _finish({"head": head, "core": core, "arms": a[0], "forearms": a[1], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.15)
	return _with_visual(node, head)
