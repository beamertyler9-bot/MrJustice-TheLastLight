extends "res://tools/sculpt_dune_maw.gd"
## Desert lizards of the Sunspire Dunes (the Dune Monitor and the Thorn Devil), sculpted by hand. Every design
## wears a proper scale texture (overlapping scales with a matching normal map) instead of fur
## grain. Three designs, each built on a real desert lizard:
##   sandfish - the sandfish skink that "swims" through dunes: glossy, banded, shovel-snouted
##   monitor  - a desert monitor: long neck, long narrow head with slit nostrils near the eyes,
##              beaded scales, heavy claws, a long keeled tail and a long forked tongue
##   devil    - a thorny devil / horned lizard: a broad flat body armoured all over in conical
##              spines, a crown of horns, a spiked "false head" knob on the neck and rust,
##              ochre and cream camouflage


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/scale_detail_gray.png")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/cast/scale_normal.png")
	material.normal_scale = 0.8
	material.uv1_scale = Vector3(5.5, 5.5, 5.5)
	material.roughness = 0.62


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "SandswimSkink"
	match variant:
		"sandfish": return _sandfish()
		"monitor": return _monitor()
		"devil": return _devil()
		"devil_wild": return _as_wildlife(_devil(), "thorn_devil", "lizard", 1.7)
	return null


## A tail of chained segments that the game swings; `flat` < 1 squeezes it side to side.
func _tail(paint: Callable, start: Vector3, count: int, step: Vector3, r0: float, flat: float, keel: Callable = Callable()) -> Array:
	var tails: Array = []
	var parent: Node3D = root
	var at := start
	for k in range(count):
		var dir := step + Vector3(0.04 * sin(k * 0.9), 0, 0)
		var node := joint(parent, "Tail" if k == 0 else "TailSegment", at)
		var ra: float = lerpf(r0, 0.015, pow(float(k) / count, 0.8)); var rb: float = lerpf(r0, 0.015, pow(float(k + 1) / count, 0.8))
		var ts := Sculpt.new(); var tp := ts.add_painter(paint)
		var next := at + dir
		ts.tube([at - dir * 0.15, at.lerp(next, 0.5), next + dir * 0.12], [ra * 1.02, (ra + rb) * 0.5, rb], tp, {"sides": 14, "per": 2, "flat": flat, "cap1": k == count - 1})
		if keel.is_valid(): keel.call(ts, at, next, (ra + rb) * 0.5)
		part(node, "Segment", ts)
		tails.append(node); parent = node; at = next
	return tails


# ------------------------------------------------------------------ B: desert monitor

func _monitor() -> Node3D:
	# Sandy olive-tan with cross-bands of dark spots, scattered yellow dots, a dark stripe
	# behind each eye and a cream belly.
	var hide := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#b89a64").lerp(Color("#7a6440"), clampf(n.y * 0.35 + Sculpt.fbm(p * 4.0) * 0.5 + 0.05, 0.0, 1.0))
		var band := sin(p.z * 9.0 + Sculpt.fbm(p * 2.0) * 1.2)
		var spots := smoothstep(0.05, 0.3, Sculpt.noise(p * 18.0))
		c = c.lerp(Color("#2a2016"), smoothstep(-0.1, 0.3, band) * (0.6 + 0.4 * spots) * smoothstep(-0.4, 0.2, n.y) * 0.95)
		# Pale yellow eye-spots set in the dark bands, like a desert monitor's.
		var dots := smoothstep(0.5, 0.62, Sculpt.noise(p * 26.0 + Vector3(3, 7, 1)))
		c = c.lerp(Color("#e8cf78"), dots * smoothstep(-0.2, 0.4, n.y) * 0.85)
		if p.z < -0.72 and p.z > -0.95: c = c.lerp(Color("#2a2018"), smoothstep(0.03, 0.01, absf(p.y - (0.77 - (p.z + 0.89) * 0.6))) * smoothstep(0.03, 0.06, absf(p.x)) * 0.8)
		return c.lerp(Color("#efe2c2"), smoothstep(-0.25, -0.65, n.y) * 0.85)
	var body := Sculpt.new(); var bp := body.add_painter(hide)
	body.tube([Vector3(0, 0.55, -0.36), Vector3(0, 0.58, -0.06), Vector3(0, 0.55, 0.3), Vector3(0, 0.49, 0.58)], [0.26, 0.31, 0.31, 0.24], bp, {"sides": 18, "per": 3, "flat": 1.18})
	for side in [-1.0, 1.0]:
		body.blob(Vector3(0.17 * side, 0.55, -0.3), Vector3(0.1, 0.14, 0.13), bp, {"lat": 6, "lon": 9})
		body.blob(Vector3(0.17 * side, 0.52, 0.45), Vector3(0.11, 0.15, 0.15), bp, {"lat": 6, "lon": 9})
	# A long, thick neck carried high, with loose skin folds and a throat pouch.
	body.tube([Vector3(0, 0.57, -0.34), Vector3(0, 0.63, -0.55), Vector3(0, 0.7, -0.72)], [0.2, 0.15, 0.12], bp, {"sides": 16, "per": 3, "flat": 1.05})
	body.blob(Vector3(0, 0.56, -0.62), Vector3(0.1, 0.07, 0.12), bp, {"lat": 5, "lon": 8})
	for k in range(3):
		var z := -0.45 - k * 0.09
		for side in [-1.0, 1.0]:
			body.tube([Vector3(0.08 * side, 0.66 + k * 0.03, z), Vector3(0.15 * side, 0.58 + k * 0.03, z - 0.02), Vector3(0.12 * side, 0.5 + k * 0.03, z - 0.04)], [0.02, 0.024, 0.018], bp, {"sides": 5, "per": 2, "cap_rings": 1})
	var keel := func (ts: Sculpt, a: Vector3, b: Vector3, r: float) -> void:
		var kp := ts.add_painter(func (p, n, v, w): return Color("#5a4a30").lerp(Color("#b09a6a"), v))
		for i in range(3):
			var at := a.lerp(b, (i + 0.5) / 3.0)
			for side in [-1.0, 1.0]: ts.crystal(at + Vector3(0.015 * side, r * 0.95, 0), Vector3(0.2 * side, 1, 0.4), r * 0.3 + 0.01, 0.008, kp, 4)
	var tails := _tail(hide, Vector3(0, 0.48, 0.58), 9, Vector3(0, -0.03, 0.31), 0.24, 0.72, keel)
	var head := joint(root, "Head", Vector3(0, 0.7, -0.74))
	var hs := Sculpt.new(); var hp := hs.add_painter(hide); var dark := hs.add_painter(func (p, n, v, w): return Color("#16110c"))
	var tooth := hs.add_painter(func (p, n, v, w): return TOOTH); var mouth := hs.add_painter(func (p, n, v, w): return MOUTH)
	# A long, narrow head with a flat crown, heavy brows and slit nostrils near the eyes.
	hs.tube([Vector3(0, 0.72, -0.71), Vector3(0, 0.75, -0.86), Vector3(0, 0.72, -1.02), Vector3(0, 0.68, -1.15), Vector3(0, 0.66, -1.2)], [0.115, 0.115, 0.085, 0.055, 0.02], hp, {"sides": 16, "per": 3, "flat": 1.05, "square": 0.3, "cap1": false})
	hs.blob(Vector3(0, 0.68, -0.8), Vector3(0.12, 0.06, 0.12), hp, {"lat": 5, "lon": 9})
	# Heavy jowls of jaw muscle behind the mouth.
	for side in [-1.0, 1.0]: hs.blob(Vector3(0.095 * side, 0.69, -0.79), Vector3(0.05, 0.06, 0.09), hp, {"lat": 5, "lon": 8})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.078 * side, 0.82, -0.885), Vector3(0.05, 0.026, 0.07), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.FORWARD, side * 0.35)})
		hs.blob(Vector3(0.098 * side, 0.778, -0.89), Vector3(0.03, 0.026, 0.032), dark, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.062 * side, 0.765, -0.99), Vector3(0.006, 0.006, 0.022), dark, {"lat": 3, "lon": 6})
		hs.blob(Vector3(0.11 * side, 0.7, -0.74), Vector3(0.01, 0.02, 0.016), dark, {"lat": 3, "lon": 6})
		for k in range(8):
			hs.crystal(Vector3((0.095 - k * 0.009) * side, 0.655, -0.8 - k * 0.045), Vector3(0, -1, 0.1), 0.035, 0.008, tooth, 4)
	hs.blob(Vector3(0, 0.655, -0.94), Vector3(0.07, 0.015, 0.16), mouth, {"lat": 4, "lon": 9})
	part(head, "Head", hs)
	var core := _eyes(head, [Vector3(-0.112, 0.78, -0.892), Vector3(0.112, 0.78, -0.892)], 0.02)
	var jaw := joint(head, "Jaw", Vector3(0, 0.64, -0.74))
	var js := Sculpt.new(); var jp := js.add_painter(hide); var jt := js.add_painter(func (p, n, v, w): return TOOTH)
	var jm := js.add_painter(func (p, n, v, w): return MOUTH); var tongue := js.add_painter(func (p, n, v, w): return Color("#c0c4d8").lerp(Color("#5a5c7a"), v))
	js.tube([Vector3(0, 0.65, -0.72), Vector3(0, 0.625, -0.95), Vector3(0, 0.63, -1.13)], [0.1, 0.07, 0.03], jp, {"sides": 14, "per": 3, "flat": 1.1, "cap_len": 0.5})
	js.blob(Vector3(0, 0.655, -0.93), Vector3(0.06, 0.012, 0.15), jm, {"lat": 4, "lon": 9})
	for side in [-1.0, 1.0]:
		for k in range(7):
			js.crystal(Vector3((0.085 - k * 0.008) * side, 0.66, -0.82 - k * 0.045), Vector3(0, 1, 0.1), 0.03, 0.007, jt, 4)
	# A long, deeply forked tongue, blue-grey like a real monitor's.
	js.tube([Vector3(0, 0.66, -0.9), Vector3(0, 0.665, -1.1), Vector3(0, 0.655, -1.32)], [0.014, 0.012, 0.009], tongue, {"sides": 6, "per": 2, "flat": 0.5, "side": Vector3.UP})
	for side in [-1.0, 1.0]:
		js.tube([Vector3(0, 0.655, -1.31), Vector3(0.03 * side, 0.65, -1.4), Vector3(0.055 * side, 0.64, -1.45)], [0.008, 0.005, 0.0015], tongue, {"sides": 5, "per": 2, "cap1": false})
	part(jaw, "Jaw", js).rotation.x = -0.22
	var leg_rig := lizard_legs(hide, [["Front", -0.3, 0.55], ["Hind", 0.44, 0.52]], 1.3)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": leg_rig.hips, "knees": leg_rig.knees, "leaves": tails}, 1.8)
	return _rig(node, head, [], [], jaw, tails)


# ------------------------------------------------------------------ C: thorny devil

func _devil() -> Node3D:
	# Rust, ochre and cream camouflage in bold patches, with a pale stripe down the spine.
	var camo := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var a := Sculpt.fbm(p * 3.0); var b := Sculpt.noise(p * 6.0 + Vector3(5, 2, 9))
		var c := Color("#b38a52").lerp(Color("#76361d"), smoothstep(-0.06, 0.06, a))
		# Each rust patch is outlined in near-black, as on a real thorny devil.
		c = c.lerp(Color("#24150c"), smoothstep(0.03, 0.0, absf(a)) * 0.85)
		c = c.lerp(Color("#3c2416"), smoothstep(0.38, 0.52, b) * 0.6)
		c = c.lerp(Color("#e8d4a4"), smoothstep(0.05, 0.02, absf(p.x)) * smoothstep(0.3, 0.7, n.y) * 0.85)
		return c.lerp(Color("#e3cfa2"), smoothstep(-0.25, -0.65, n.y) * 0.8)
	var spike := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#c29a62").lerp(Color("#2e1c10"), pow(v, 1.6))
	var body := Sculpt.new(); var bp := body.add_painter(camo); var sp := body.add_painter(spike)
	var spine := [Vector3(0, 0.44, -0.1), Vector3(0, 0.48, 0.1), Vector3(0, 0.46, 0.34), Vector3(0, 0.4, 0.52)]
	var radii := [0.23, 0.33, 0.33, 0.22]
	body.tube(spine, radii, bp, {"sides": 20, "per": 3, "flat": 1.45, "lump": 0.05})
	# Conical spines everywhere on top, bigger along the back and sides.
	for k in range(90):
		var t := float(k) / 90.0
		var z := lerpf(-0.08, 0.5, t)
		var ang := lerpf(-1.4, 1.4, fposmod(k * 0.618034, 1.0))
		var c := Vector3.ZERO; var r := 0.0
		for i in range(spine.size() - 1):
			var a: Vector3 = spine[i]; var b: Vector3 = spine[i + 1]
			if z >= a.z and z <= b.z:
				var f := (z - a.z) / (b.z - a.z)
				c = a.lerp(b, f); r = lerpf(radii[i], radii[i + 1], f)
		var dir := Vector3(sin(ang) * 1.45, cos(ang), 0).normalized()
		var at := c + Vector3(sin(ang) * r * 1.42, cos(ang) * r * 0.97, 0)
		var big := absf(ang) < 0.25 or absf(absf(ang) - 1.2) < 0.2 or k % 7 == 0
		body.crystal(at, dir + Vector3(0, 0.25, 0.15), (0.16 if big else 0.07) + 0.03 * Sculpt.noise(at * 13.0), 0.03 if big else 0.014, sp, 5)
		if big:
			# A rosette of little thorns round each big one.
			var t1 := dir.cross(Vector3.BACK).normalized(); var t2 := dir.cross(t1)
			for j in range(3):
				var o := (t1 * cos(j * 2.1) + t2 * sin(j * 2.1)) * 0.045
				body.crystal(at + o, dir + o * 6.0, 0.045, 0.01, sp, 4)
	# The spiked "false head" knob on the back of the neck.
	body.tube([Vector3(0, 0.46, -0.08), Vector3(0, 0.47, -0.36)], [0.2, 0.17], bp, {"sides": 16, "per": 2, "flat": 1.3})
	body.blob(Vector3(0, 0.62, -0.2), Vector3(0.09, 0.07, 0.08), bp, {"lat": 6, "lon": 9})
	for side in [-1.0, 1.0]: body.crystal(Vector3(0.05 * side, 0.66, -0.2), Vector3(side * 0.5, 1, 0.1), 0.14, 0.025, sp, 5)
	var keel := func (ts: Sculpt, a: Vector3, b: Vector3, r: float) -> void:
		var kp := ts.add_painter(spike)
		for i in range(3):
			var at := a.lerp(b, (i + 0.5) / 3.0)
			for ang in [-0.9, 0.0, 0.9]:
				var dir := Vector3(sin(ang), cos(ang), 0)
				ts.crystal(at + dir * r * 0.95, dir + Vector3(0, 0.2, 0.3), r * 0.5 + 0.02, r * 0.18 + 0.006, kp, 4)
	var tails := _tail(camo, Vector3(0, 0.39, 0.5), 5, Vector3(0, -0.04, 0.26), 0.2, 1.0, keel)
	var head := joint(root, "Head", Vector3(0, 0.46, -0.34))
	var hs := Sculpt.new(); var hp := hs.add_painter(camo); var hsp := hs.add_painter(spike); var dark := hs.add_painter(func (p, n, v, w): return Color("#16110c"))
	var mouth := hs.add_painter(func (p, n, v, w): return MOUTH)
	# A small, blunt, rounded head with a great curved horn over each eye and, like a horned
	# lizard, a crown of horns round the back of the skull.
	hs.tube([Vector3(0, 0.48, -0.32), Vector3(0, 0.51, -0.47), Vector3(0, 0.47, -0.62), Vector3(0, 0.43, -0.69)], [0.19, 0.18, 0.11, 0.035], hp, {"sides": 16, "per": 3, "flat": 1.25, "cap1": false})
	for side in [-1.0, 1.0]:
		hs.blob(Vector3(0.115 * side, 0.54, -0.5), Vector3(0.045, 0.03, 0.05), hp, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.14 * side, 0.52, -0.51), Vector3(0.028, 0.026, 0.028), dark, {"lat": 5, "lon": 8})
		hs.tube([Vector3(0.1 * side, 0.57, -0.47), Vector3(0.14 * side, 0.66, -0.44), Vector3(0.16 * side, 0.72, -0.38)], [0.03, 0.02, 0.003], hsp, {"sides": 6, "per": 3, "cap1": false})
		hs.blob(Vector3(0.03 * side, 0.46, -0.65), Vector3(0.008, 0.008, 0.006), dark, {"lat": 3, "lon": 5})
	# The crown: big horns fanning back from the rear of the skull, longest in the middle pair.
	for k in range(6):
		var a := lerpf(-1.25, 1.25, k / 5.0)
		var base := Vector3(sin(a) * 0.17, 0.56 + cos(a) * 0.1, -0.4)
		var dir := Vector3(sin(a) * 0.9, 0.55 + cos(a) * 0.35, 1.0)
		thorn(hs, hsp, base, dir, 0.22 + 0.08 * cos(a), 0.035, Vector3(0, 0.05, 0))
	for k in range(10):
		var a := lerpf(-1.3, 1.3, fposmod(k * 0.618, 1.0)); var z := -0.36 - (k % 4) * 0.05
		hs.crystal(Vector3(sin(a) * 0.13, 0.5 + cos(a) * 0.1, z), Vector3(sin(a), cos(a), 0.2), 0.045, 0.01, hsp, 4)
	hs.blob(Vector3(0, 0.425, -0.52), Vector3(0.1, 0.012, 0.11), mouth, {"lat": 4, "lon": 8})
	part(head, "Head", hs)
	var core := _eyes(head, [Vector3(-0.158, 0.522, -0.515), Vector3(0.158, 0.522, -0.515)], 0.018)
	var jaw := joint(head, "Jaw", Vector3(0, 0.42, -0.36))
	var js := Sculpt.new(); var jp := js.add_painter(camo); var jsp := js.add_painter(spike)
	js.tube([Vector3(0, 0.42, -0.36), Vector3(0, 0.4, -0.52), Vector3(0, 0.41, -0.64)], [0.12, 0.09, 0.03], jp, {"sides": 14, "per": 3, "flat": 1.25, "cap_len": 0.5})
	for side in [-1.0, 1.0]:
		for k in range(3): js.crystal(Vector3(0.12 * side, 0.38, -0.4 - k * 0.07), Vector3(side, -0.5, 0.2), 0.06, 0.012, jsp, 4)
	part(jaw, "Jaw", js).rotation.x = -0.15
	var leg_rig := lizard_legs(camo, [["Front", -0.12, 0.44], ["Hind", 0.4, 0.42]], 1.25)
	# Spines on the upper legs too.
	for k in range(leg_rig.hips.size()):
		var hip: Node3D = leg_rig.hips[k]
		var side := -1.0 if k % 2 == 0 else 1.0
		var ls := Sculpt.new(); var lp := ls.add_painter(spike)
		var base: Vector3 = hip.position + Vector3(0.14 * side, 0.06, 0)
		for i in range(3): ls.crystal(base + Vector3(0.06 * i * side, -0.01 * i, 0), Vector3(side * 0.4, 1, 0.2), 0.07, 0.015, lp, 4)
		part(hip, "Spines", ls)
	part(root, "Body", body)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": leg_rig.hips, "knees": leg_rig.knees, "leaves": tails}, 2.1)
	return _rig(node, head, leg_rig.hips, leg_rig.knees, jaw, tails)


## Turns a finished model into wildlife: its visual rig becomes the rig, and the whole thing is
## sized inside a "Body" node (wildlife keeps no rest scale). The Thorn Devil is a peaceful
## grazer of ants and seeds, so it roams with the dune wildlife rather than fighting.
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
