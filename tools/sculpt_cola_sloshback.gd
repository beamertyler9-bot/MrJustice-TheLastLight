extends "res://tools/creature_kit.gd"
## The Cola Sloshback of S'morewood, three takes. Glossy cola-brown skin catching amber light,
## creamy foam, fizzing bubbles, and a glowing throat that swells before it sprays.
## A: a squat toad frothing with foam and carbonation bubbles, warted with bottle caps.
## B: a frog made from a cola bottle lying on its belly, spraying from the bottle's neck.
## C: a long axolotl with frothy foam gills and a glass dome on its back full of sloshing cola.

const COLA := Color("#2e0f06")
const COLA_HI := Color("#7a2e10")
const AMBER := Color("#e08a2a")
const FOAM := Color("#f4e8d2")
const FOAM_SHADE := Color("#d8c3a2")
const CAP_RED := Color("#c4202a")
const SILVER := Color("#c9ccd2")

var shiny: StandardMaterial3D
var throat_glow: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_soft.png")
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	shiny = StandardMaterial3D.new()
	shiny.vertex_color_use_as_albedo = true
	shiny.vertex_color_is_srgb = true
	shiny.roughness = 0.12
	shiny.metallic_specular = 0.85
	glow.albedo_color = Color("#c86a1a"); glow.emission = Color("#ff9a2a")
	glow.emission_energy_multiplier = 0.85
	throat_glow = glow


static func cola(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	# Dark cola that glows amber where it thins and where the light comes through from above.
	var c := COLA.lerp(COLA_HI, clampf(0.25 + n.y * 0.5 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
	c = c.lerp(AMBER, smoothstep(0.55, 0.85, Sculpt.noise(p * 3.0 + Vector3(0.3, 0.1, 0)) + 0.4) * 0.35)
	return c.darkened(clampf(-n.y, 0.0, 1.0) * 0.4)


static func foam(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return FOAM.lerp(FOAM_SHADE, clampf(0.5 - n.y * 0.5 + Sculpt.noise(p * 18.0) * 0.4, 0.0, 1.0))


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ColaSloshback"
	match variant:
		"toad": return _toad()
		"bottle": return _bottle()
		"axolotl": return _axolotl()
		"toad_wild": return _as_wildlife(_toad(), "fizz_toad", "frog", 0.55)
		"axolotl_wild": return _as_wildlife(_axolotl(), "slosh_axolotl", "lizard", 0.6)
	return null


## Turns a finished model into wildlife: its regional visual rig becomes the rig, and the whole
## thing is shrunk to a critter's size inside a "Body" node (wildlife keeps no rest scale).
func _as_wildlife(node: Node3D, id: String, form: String, scale_k: float) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings").visual_rig
	var nodes := {}
	for key in rig:
		if rig[key] is NodePath: nodes[key] = node.get_node(rig[key])
		elif rig[key] is Array: nodes[key] = rig[key].map(func (p): return node.get_node(p))
		elif rig[key] is Dictionary:
			var f := {}
			for k in rig[key]:
				var v = rig[key][k]
				f[k] = node.get_node(v) if v is NodePath else v.map(func (p): return node.get_node(p))
			nodes[key] = f
	var body := Node3D.new(); body.name = "Body"; body.scale = Vector3.ONE * scale_k
	for child in node.get_children(): child.reparent(body, false)
	for launch in body.find_children("LaunchPoint", "", true, false): launch.free()
	node.add_child(body)
	var paths := {}
	for key in nodes:
		var v = nodes[key]
		if v is Node: paths[key] = node.get_path_to(v)
		elif v is Array: paths[key] = v.map(func (n): return node.get_path_to(n))
		elif v is Dictionary:
			var f := {}
			for k in v: f[k] = node.get_path_to(v[k]) if v[k] is Node else v[k].map(func (n): return node.get_path_to(n))
			paths[key] = f
	for k in node.get_meta_list(): node.remove_meta(k)
	node.set_meta("species", id); node.set_meta("anatomy", form)
	node.set_meta("rig_bindings", paths); node.set_meta("actor_properties", {})
	node.set_meta("geometry_revision", "sculpted-1"); node.set_meta("sculpt_triangles", triangles(node))
	_own(node, node)
	return node


func _with_visual(node: Node3D, head: Node3D, hips: Array, knees: Array, throat: Node3D, jaw: Node3D = null, tails: Array = []) -> Node3D:
	var rig: Dictionary = node.get_meta("rig_bindings")
	var paths := func (list: Array) -> Array: return list.map(func (n): return node.get_path_to(n))
	var features := {&"glowing_throat": node.get_path_to(throat)}
	if jaw != null: features[&"jaw"] = node.get_path_to(jaw)
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": paths.call(hips), "knees": paths.call(knees),
		"ears": [], "tails": paths.call(tails), "features": features}
	node.set_meta("rig_bindings", rig)
	return node


## Frog legs: short front legs and big folded hind legs, each ending in webbed toes.
func frog_legs(front_y: float, back_y: float, front_z: float, back_z: float, width: float, scale_k: float) -> Array:
	var hips: Array = []; var knees: Array = []
	for spec in [[-1.0, true], [1.0, true], [-1.0, false], [1.0, false]]:
		var side: float = spec[0]; var front: bool = spec[1]
		var hip_at := Vector3(width * side, front_y if front else back_y, front_z if front else back_z)
		var hip := joint(root, ("Foreleg%d" if front else "Hindleg%d") % hips.size(), hip_at)
		# Front legs prop the chest up; hind legs fold up alongside the body, knee forward and
		# foot tucked back under the hip, ready to spring.
		var knee_at := hip_at + (Vector3(0.07 * side, -0.15, -0.05) if front else Vector3(0.17 * side, -0.12, -0.2)) * scale_k
		var foot := Vector3(hip_at.x + (0.1 if front else 0.13) * side * scale_k, 0.035, hip_at.z + (-0.13 if front else 0.06) * scale_k)
		var ts := Sculpt.new(); var tp := ts.add_painter(cola)
		ts.tube([hip_at, hip_at.lerp(knee_at, 0.5) + Vector3(0, 0.03, 0), knee_at], [0.09 * scale_k if front else 0.13 * scale_k, 0.075 * scale_k, 0.06 * scale_k], tp, {"sides": 10, "per": 3})
		part(hip, "Thigh", ts, shiny)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(cola); var web := ss.add_painter(func (p, n, v, w): return COLA_HI.lerp(AMBER, 0.35))
		ss.tube([knee_at, knee_at.lerp(foot, 0.5), foot + Vector3(0, 0.03, 0)], [0.06 * scale_k, 0.05 * scale_k, 0.04 * scale_k], sp, {"sides": 9, "per": 3})
		var forward := Vector3(0.25 * side, 0, -1.0 if front else 0.6).normalized()
		for t in range(3):
			var spread := (t - 1) * 0.5
			var d := forward.rotated(Vector3.UP, spread)
			var tip := foot + d * (0.13 if front else 0.15) * scale_k
			ss.tube([foot + Vector3(0, 0.02, 0), tip + Vector3(0, 0.005, 0)], [0.022 * scale_k, 0.012 * scale_k], sp, {"sides": 6, "per": 1, "cap_rings": 1})
			ss.blob(tip + Vector3(0, 0.008, 0), Vector3.ONE * 0.022 * scale_k, web, {"lat": 4, "lon": 6})
		ss.blob(foot + forward * 0.06 * scale_k + Vector3(0, 0.01, 0), Vector3(0.09, 0.012, 0.08) * scale_k, web, {"lat": 4, "lon": 8, "basis": Basis.looking_at(forward, Vector3.UP)})
		part(knee, "Foot", ss, shiny)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


## Bulging frog eyes: an amber iris with a dark wide pupil on a glossy cola mound.
func frog_eyes(s: Sculpt, parent: Node3D, spots: Array, size: float) -> void:
	var mound := s.add_painter(cola)
	var es := Sculpt.new(); var iris := es.add_painter(func (p, n, v, w): return Color("#f0a23a").lerp(Color("#7a3a0a"), clampf(-n.y * 0.6 + 0.2, 0.0, 1.0)))
	var pupil := es.add_painter(func (p, n, v, w): return Color("#0c0402"))
	for at: Vector3 in spots:
		s.blob(at + Vector3(0, -size * 0.25, 0), Vector3.ONE * size * 1.15, mound, {"lat": 6, "lon": 9})
		var out := Vector3(signf(at.x) * 0.8, 0.35, -0.5).normalized()
		es.blob(at + out * size * 0.35, Vector3.ONE * size * 0.82, iris, {"lat": 6, "lon": 9})
		es.blob(at + out * size * 1.0, Vector3(size * 0.55, size * 0.32, size * 0.18), pupil, {"lat": 4, "lon": 8, "basis": Basis.looking_at(out, Vector3.UP)})
	part(parent, "Eyes", es, shiny)


## Carbonation: little bubbles half sunk into a surface around `center`.
func bubbles(s: Sculpt, center: Vector3, radii: Vector3, count: int, size: float) -> void:
	var bp := s.add_painter(func (p, n, v, w): return Color("#ffe9c4").lerp(AMBER, 0.3).lightened(clampf(n.y, 0.0, 1.0) * 0.3))
	for k in range(count):
		var u := fposmod(k * 0.618, 1.0); var v := fposmod(k * 0.381 + 0.2, 1.0)
		var dir := Vector3(cos(u * TAU) * sin(v * PI * 0.6 + 0.3), cos(v * PI * 0.6 + 0.3), sin(u * TAU) * sin(v * PI * 0.6 + 0.3))
		s.blob(center + dir * radii, Vector3.ONE * size * (0.5 + 0.7 * absf(sin(k * 1.9))), bp, {"lat": 4, "lon": 6})


# ------------------------------------------------------------------- A: toad

## A: a big, squat toad of glossy cola with a head of creamy foam frothing over its back,
## carbonation bubbles all over, bottle-cap warts, and a huge amber throat sac.
func _toad() -> Node3D:
	var bs := Sculpt.new(); var cp := bs.add_painter(cola); var fp := bs.add_painter(foam)
	bs.blob(Vector3(0, 0.5, 0.08), Vector3(0.48, 0.33, 0.5), cp, {"lat": 10, "lon": 16, "lump": 0.06})
	# Foam frothing along the back and spilling down the sides.
	for k in range(14):
		var at := Vector3(sin(k * 2.4) * 0.22, 0.8 - absf(sin(k * 2.4)) * 0.08, -0.12 + fposmod(k * 0.37, 0.55))
		bs.blob(at, Vector3(0.1, 0.07, 0.1) * (0.8 + 0.5 * absf(cos(k * 1.3))), fp, {"lat": 7, "lon": 10, "lump": 0.12})
	for k in range(6):
		var side := -1.0 if k % 2 == 0 else 1.0
		var top := Vector3(0.24 * side, 0.74, -0.05 + k * 0.08)
		bs.tube([top, top + Vector3(0.1 * side, -0.12, 0), top + Vector3(0.13 * side, -0.22 - 0.05 * (k % 3), 0)], [0.04, 0.03, 0.025], fp, {"sides": 7, "per": 3})
	bubbles(bs, Vector3(0, 0.5, 0.08), Vector3(0.48, 0.33, 0.5), 26, 0.035)
	# Bottle-cap warts.
	var capp := bs.add_painter(func (p, n, v, w): return CAP_RED.lightened(clampf(n.y, 0.0, 1.0) * 0.2))
	for at: Vector3 in [Vector3(0.36, 0.56, 0.2), Vector3(-0.38, 0.52, 0.12), Vector3(0.2, 0.42, 0.48)]:
		var out := (at - Vector3(0, 0.5, 0.08)).normalized()
		bs.tube([at, at + out * 0.025], [0.05, 0.05], capp, {"sides": 14, "per": 1, "ridges": 14, "ridge": 0.12, "cap_len": 0.15, "cap_rings": 1})
	part(root, "Body", bs, shiny)
	var head := joint(root, "Head", Vector3(0, 0.52, -0.3))
	var hs := Sculpt.new(); var hc := hs.add_painter(cola); var mouth := hs.add_painter(func (p, n, v, w): return Color("#120502"))
	hs.blob(Vector3(0, 0.52, -0.38), Vector3(0.4, 0.2, 0.28), hc, {"lat": 8, "lon": 14, "lump": 0.04})
	hs.tube([Vector3(-0.36, 0.44, -0.3), Vector3(-0.2, 0.41, -0.58), Vector3(0, 0.4, -0.64), Vector3(0.2, 0.41, -0.58), Vector3(0.36, 0.44, -0.3)], [0.012, 0.014, 0.015, 0.014, 0.012], mouth, {"sides": 6, "per": 3})
	for side in [-1.0, 1.0]: hs.blob(Vector3(0.05 * side, 0.6, -0.64), Vector3(0.012, 0.008, 0.01), mouth, {"lat": 3, "lon": 5})
	frog_eyes(hs, head, [Vector3(-0.22, 0.72, -0.36), Vector3(0.22, 0.72, -0.36)], 0.085)
	part(head, "Head", hs, shiny)
	var throat := joint(head, "Throat", Vector3(0, 0.32, -0.4))
	var ts := Sculpt.new(); var tw := ts.add_painter(func (p, n, v, w): return Color.WHITE)
	ts.blob(Vector3(0, 0.32, -0.42), Vector3(0.26, 0.16, 0.2), tw, {"lat": 7, "lon": 12})
	var core := part(throat, "ThroatSac", ts, throat_glow); core.material_override = throat_glow
	var launch := Node3D.new(); launch.name = "LaunchPoint"; head.add_child(launch); launch.position = Vector3(0, 0.42, -0.68) - Vector3(0, 0.52, -0.3)
	var legs := frog_legs(0.38, 0.4, -0.18, 0.36, 0.3, 1.25)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.2)
	return _with_visual(node, head, legs[0], legs[1], throat)


# ------------------------------------------------------------------ B: bottle

## B: a frog that is a glass cola bottle lying on its belly: the shoulders of the bottle are its
## head with eyes perched on top, the bottle's neck is its spout of a mouth, the red cap sits
## crooked on its head, the label wraps its middle, and foam fizzes out of the neck.
func _bottle() -> Node3D:
	var body := Basis(Vector3.RIGHT, PI * 0.5 - 0.1)
	var bs := Sculpt.new(); var cp := bs.add_painter(cola)
	var label := bs.add_painter(func (p, n, v, w): return CAP_RED.lerp(Color("#f4ece0"), smoothstep(0.01, 0.0, absf(fposmod(p.z * 6.0, 1.0) - 0.5) - 0.12)).darkened(clampf(-n.y, 0.0, 1.0) * 0.3))
	# Bottle profile (radius, height) from the base to the shoulders; the neck is the head.
	bs.lathe(Vector3(0, 0.42, 0.55), [Vector2(0, 0.0), Vector2(0.26, 0.0), Vector2(0.31, -0.05), Vector2(0.33, -0.2), Vector2(0.3, -0.42), Vector2(0.33, -0.62), Vector2(0.34, -0.8)], cp, {"sides": 18, "basis": body})
	bs.lathe(Vector3(0, 0.42, 0.55), [Vector2(0.345, -0.3), Vector2(0.345, -0.56)], label, {"sides": 18, "basis": body})
	part(root, "Bottle", bs, shiny)
	var head := joint(root, "Head", Vector3(0, 0.45, -0.3))
	var hs := Sculpt.new(); var hc := hs.add_painter(cola); var fp := hs.add_painter(foam)
	hs.lathe(Vector3(0, 0.42, 0.55), [Vector2(0.34, -0.8), Vector2(0.3, -0.98), Vector2(0.16, -1.12), Vector2(0.1, -1.24), Vector2(0.1, -1.36), Vector2(0.12, -1.38), Vector2(0.12, -1.42), Vector2(0, -1.42)], hc, {"sides": 18, "basis": body})
	# Foam frothing out of the open neck and dribbling down the chin.
	var mouth_at := Vector3(0, 0.42, 0.55) + body * Vector3(0, -1.43, 0)
	for k in range(7):
		hs.blob(mouth_at + Vector3(sin(k * 2.2) * 0.07, 0.03 + absf(cos(k * 1.7)) * 0.05, -0.02 - k * 0.006), Vector3(0.06, 0.05, 0.05), fp, {"lat": 5, "lon": 7, "lump": 0.3})
	hs.tube([mouth_at + Vector3(0.04, -0.06, 0), mouth_at + Vector3(0.05, -0.16, 0.03), mouth_at + Vector3(0.04, -0.22, 0.05)], [0.03, 0.025, 0.03], fp, {"sides": 7, "per": 3})
	# The crooked bottle cap worn like a crown.
	var capp := hs.add_painter(func (p, n, v, w): return CAP_RED.lightened(clampf(n.y, 0.0, 1.0) * 0.25))
	hs.tube([Vector3(0.0, 0.66, -0.4), Vector3(0.02, 0.71, -0.41)], [0.1, 0.1], capp, {"sides": 18, "per": 1, "ridges": 18, "ridge": 0.1, "cap_len": 0.15, "cap_rings": 1, "side": Vector3.RIGHT})
	frog_eyes(hs, head, [Vector3(-0.2, 0.66, -0.3), Vector3(0.2, 0.66, -0.3)], 0.08)
	part(head, "Neck", hs, shiny)
	var throat := joint(head, "Throat", Vector3(0, 0.25, -0.36))
	var ts := Sculpt.new(); var tw := ts.add_painter(func (p, n, v, w): return Color.WHITE)
	ts.blob(Vector3(0, 0.25, -0.38), Vector3(0.2, 0.13, 0.17), tw, {"lat": 7, "lon": 12})
	var core := part(throat, "ThroatSac", ts, throat_glow); core.material_override = throat_glow
	var launch := Node3D.new(); launch.name = "LaunchPoint"; head.add_child(launch); launch.position = mouth_at - Vector3(0, 0.45, -0.3)
	var legs := frog_legs(0.36, 0.36, -0.2, 0.38, 0.27, 1.15)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.2)
	return _with_visual(node, head, legs[0], legs[1], throat)


# ----------------------------------------------------------------- C: axolotl

## C: a long, low axolotl of cola with three frothy foam gills each side of its broad head, a
## glass dome on its back with cola sloshing inside, and a long finned tail.
func _axolotl() -> Node3D:
	var bs := Sculpt.new(); var cp := bs.add_painter(cola)
	bs.tube([Vector3(0, 0.36, -0.2), Vector3(0, 0.38, 0.15), Vector3(0, 0.34, 0.5)], [0.22, 0.25, 0.2], cp, {"sides": 14, "per": 3, "flat": 1.3, "side": Vector3.RIGHT, "cap_len": 0.5})
	part(root, "Body", bs, shiny)
	# The glass dome with cola sloshing at an angle inside it.
	var ds := Sculpt.new()
	var inner := ds.add_painter(func (p, n, v, w): return COLA_HI.lerp(AMBER, 0.45).darkened(clampf(-n.y, 0.0, 1.0) * 0.3) if n.y < 0.8 else FOAM)
	# The cola inside, tilted as it sloshes, with a foamy surface.
	ds.blob(Vector3(0, 0.58, 0.15), Vector3(0.2, 0.1, 0.24), inner, {"lat": 7, "lon": 12, "basis": Basis(Vector3.BACK, 0.25)})
	ds.lathe(Vector3(0, 0.56, 0.15), [Vector2(0.23, 0.03), Vector2(0.27, 0.03), Vector2(0.27, 0.0), Vector2(0.23, -0.02)], ds.add_painter(func (p, n, v, w): return SILVER), {"sides": 16})
	bubbles(ds, Vector3(0, 0.6, 0.15), Vector3(0.22, 0.2, 0.26), 12, 0.03)
	part(root, "Dome", ds, shiny)
	var gs := Sculpt.new(); var gp := gs.add_painter(func (p, n, v, w): return Color(1, 0.93, 0.82, 1))
	gs.blob(Vector3(0, 0.6, 0.15), Vector3(0.235, 0.22, 0.275), gp, {"lat": 9, "lon": 14})
	var glass := StandardMaterial3D.new(); glass.vertex_color_use_as_albedo = true; glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(1, 1, 1, 0.28); glass.roughness = 0.05; glass.metallic_specular = 1.0
	part(root, "GlassDome", gs, glass)
	# Tail with a fin.
	var tails: Array = []
	var parent: Node3D = root; var at := Vector3(0, 0.33, 0.55)
	for k in range(4):
		var node := joint(parent, "Tail%d" % k, at)
		var next := at + Vector3(0, -0.03, 0.24)
		var ts := Sculpt.new(); var tp := ts.add_painter(cola); var fin := ts.add_painter(func (p, n, v, w): return COLA_HI.lerp(AMBER, 0.45))
		var r0 := lerpf(0.17, 0.04, k / 4.0); var r1 := lerpf(0.17, 0.04, (k + 1) / 4.0)
		ts.tube([at - Vector3(0, 0, 0.04), at.lerp(next, 0.5), next + Vector3(0, 0, 0.03)], [r0, (r0 + r1) * 0.5, r1], tp, {"sides": 10, "per": 2, "flat": 0.75, "side": Vector3.RIGHT})
		ts.tube([at + Vector3(0, r0 * 0.6, 0), next + Vector3(0, r1 * 0.6 + 0.04, 0)], [0.06, 0.06], fin, {"sides": 6, "per": 1, "flat": 0.12, "side": Vector3.RIGHT, "cap_len": 0.3})
		part(node, "Segment", ts, shiny)
		tails.append(node); parent = node; at = next
	var head := joint(root, "Head", Vector3(0, 0.38, -0.25))
	var hs := Sculpt.new(); var hc := hs.add_painter(cola); var fp := hs.add_painter(foam); var mouth := hs.add_painter(func (p, n, v, w): return Color("#120502"))
	hs.blob(Vector3(0, 0.4, -0.42), Vector3(0.3, 0.17, 0.24), hc, {"lat": 8, "lon": 12})
	hs.tube([Vector3(-0.24, 0.34, -0.42), Vector3(0, 0.33, -0.64), Vector3(0.24, 0.34, -0.42)], [0.01, 0.012, 0.01], mouth, {"sides": 6, "per": 3})
	# Frothy gills: three branching stalks of foam each side, pink-tipped.
	var tip := hs.add_painter(func (p, n, v, w): return Color("#f2a8b4").lerp(FOAM, 0.3))
	for side in [-1.0, 1.0]:
		for g in range(3):
			var base := Vector3(0.24 * side, 0.5 - g * 0.06, -0.36 + g * 0.05)
			var end := base + Vector3((0.16 + g * 0.03) * side, 0.12 - g * 0.06, 0.12)
			hs.tube([base, base.lerp(end, 0.5) + Vector3(0, 0.03, 0), end], [0.035, 0.03, 0.022], tip, {"sides": 7, "per": 3})
			for b in range(6):
				var bud := base.lerp(end, 0.2 + b * 0.15)
				for up in [-1.0, 1.0]:
					hs.blob(bud + Vector3(0, 0.035 * up, 0.012 * up), Vector3(0.03, 0.022, 0.02), fp if b < 4 else tip, {"lat": 4, "lon": 6, "lump": 0.25})
	frog_eyes(hs, head, [Vector3(-0.16, 0.5, -0.52), Vector3(0.16, 0.5, -0.52)], 0.05)
	part(head, "Head", hs, shiny)
	var throat := joint(head, "Throat", Vector3(0, 0.27, -0.45))
	var ts2 := Sculpt.new(); var tw := ts2.add_painter(func (p, n, v, w): return Color.WHITE)
	ts2.blob(Vector3(0, 0.27, -0.46), Vector3(0.18, 0.1, 0.15), tw, {"lat": 7, "lon": 12})
	var core := part(throat, "ThroatSac", ts2, throat_glow); core.material_override = throat_glow
	var launch := Node3D.new(); launch.name = "LaunchPoint"; head.add_child(launch); launch.position = Vector3(0, 0.34, -0.66) - Vector3(0, 0.38, -0.25)
	var legs := frog_legs(0.3, 0.3, -0.12, 0.42, 0.22, 0.9)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, 1.25)
	return _with_visual(node, head, legs[0], legs[1], throat, null, tails)
