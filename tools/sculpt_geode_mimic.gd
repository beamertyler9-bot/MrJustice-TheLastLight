extends "res://tools/sculpt_mimics.gd"
## The Geode Mimic of Prismere, sculpted by hand: a crab living inside a geode. Shut, it is a
## plain rough round stone; it chimes, the shell splits along its seam and the top half lifts
## like a lid on a mouth lined with crystal teeth, and jointed crab legs carry it.
## Built on real geodes (a knobbly chalcedony or limestone rind, a band of agate just inside the
## rind, and a hollow lined with crystals pointing inwards) and on real crabs (walking legs of
## seven segments ending in a pointed dactyl, the long merus bending up to the "knee", and a
## pair of clawed chelipeds whose movable finger closes on a fixed one):
##   amethyst - the classic amethyst geode: a tan rind, white-and-lavender agate seam, purple
##              crystal teeth; on a shore crab's four pairs of legs, claws folded under the seam
##   boxcrab  - the box crab (Calappa), the "shame-faced crab", which hides its face behind two
##              huge flat claws that look like part of its shell, each with a cockscomb crest;
##              a broad pale limestone geode lined with sky-blue celestine, the claws lifting
##              with the lid like a visor
##   spider   - the Japanese spider crab, the longest-legged crab alive, its spiny orange-and-
##              white legs holding a dark basalt "thunder egg" high above the ground, lined with
##              smoky citrine that glows from inside

var kindg := "amethyst"
var rind_mat: StandardMaterial3D
var gem_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()

# Per-design colours.
var rind_a := Color("#7d7264"); var rind_b := Color("#b9ad97")
var band_a := Color("#efedf2"); var band_b := Color("#9a9ab4"); var band_c := Color("#b9a6d6")
var gem_deep := Color("#4a1f7a"); var gem_pale := Color("#d9c2ff")
var leg_a := Color("#4a3f52"); var leg_b := Color("#8a7a92")
var glow_col := Color("#c89bff")


func _init() -> void:
	super()
	rind_mat = material.duplicate()
	rind_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rind_mat.roughness = 0.85
	gem_mat = StandardMaterial3D.new()
	gem_mat.vertex_color_use_as_albedo = true; gem_mat.vertex_color_is_srgb = true
	gem_mat.roughness = 0.08; gem_mat.metallic_specular = 1.0
	gem_mat.rim_enabled = true; gem_mat.rim = 0.5
	gem_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(variant: String) -> Node3D:
	# "<design>_open" builds the same mimic with its lid lifted, for previews.
	if variant.ends_with("_open"):
		var node := build(variant.trim_suffix("_open"))
		var jaw: Node3D = node.get_node(node.get_meta("rig_bindings").visual_rig.features.jaw)
		jaw.rotation.x = -0.7
		return node
	root = Node3D.new(); root.name = "GeodeMimic"
	kindg = variant
	rng.seed = 4021
	match variant:
		"amethyst":
			return _geode(0.74, 0.52, 0.46, 0.4, 0.82, 0.3, 1.35)
		"boxcrab":
			rind_a = Color("#9a958a"); rind_b = Color("#dcd6c8")
			band_a = Color("#f4f6f8"); band_b = Color("#a9bccc"); band_c = Color("#d8e4ee")
			gem_deep = Color("#2f6fb4"); gem_pale = Color("#d6f0ff")
			leg_a = Color("#c9a88a"); leg_b = Color("#f0e2cc")
			glow_col = Color("#8fd0ff")
			return _geode(0.56, 0.62, 0.4, 0.3, 0.76, 0.24, 1.4)
		"spider":
			rind_a = Color("#2e2a28"); rind_b = Color("#5e554c")
			band_a = Color("#e8dccb"); band_b = Color("#8a6a4a"); band_c = Color("#c9a070")
			gem_deep = Color("#7a3a0a"); gem_pale = Color("#ffd27a")
			leg_a = Color("#b8461e"); leg_b = Color("#f2e6d8")
			glow_col = Color("#ffae3a")
			return _geode(1.12, 0.42, 0.4, 0.36, 1.35, 0.5, 1.25)
	return null


# ------------------------------------------------------------------ painters

func _rind() -> Callable:
	var a := rind_a; var b := rind_b
	return func (p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
		var c := a.lerp(b, clampf(0.45 + Sculpt.fbm(p * 7.0) * 0.9 + n.y * 0.15, 0.0, 1.0))
		return c.darkened(smoothstep(0.3, 0.5, Sculpt.noise(p * 19.0)) * 0.35)


func _agate() -> Callable:
	var a := band_a; var b := band_b; var cc := band_c
	return func (p: Vector3, _n: Vector3, _v: float, _w: float) -> Color:
		var r := Vector2(p.x, p.z).length()
		var f := sin(r * 110.0 + Sculpt.noise(p * 7.0) * 5.0)
		return a.lerp(b, smoothstep(0.2, 0.8, f)).lerp(cc, smoothstep(0.1, -0.7, f) * 0.8)


func _gem() -> Callable:
	var d := gem_deep; var pl := gem_pale
	return func (p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
		return d.lerp(pl, clampf(v * 0.9 + Sculpt.noise(p * 13.0) * 0.25, 0.0, 1.0))


func _cave() -> Callable:
	var d := gem_deep
	return func (p: Vector3, _n: Vector3, _v: float, _w: float) -> Color: return d.darkened(0.55 + Sculpt.noise(p * 11.0) * 0.2)


func _chitin() -> Callable:
	var a := leg_a; var b := leg_b; var spotted := kindg != "amethyst"
	return func (p: Vector3, n: Vector3, v: float, _w: float) -> Color:
		var c := a.lerp(b, clampf(0.3 + n.y * 0.35 + Sculpt.fbm(p * 8.0) * 0.4, 0.0, 1.0))
		if spotted: c = c.lerp(b, smoothstep(0.3, 0.42, Sculpt.noise(p * 15.0)) * 0.8)
		return c.darkened(smoothstep(0.7, 1.0, v) * 0.35)


func _knuckle() -> Callable:
	var a := leg_a
	return func (_p: Vector3, n: Vector3, _v: float, _w: float) -> Color: return a.darkened(0.45).lightened(clampf(n.y, 0.0, 1.0) * 0.1)


# ------------------------------------------------------------------ the shell

const WOB := 0.14


## How far the wavy split seam rises or falls at angle `th` round a rim of radius `r`
## (the same sum the lathe uses, so crystals sit exactly on the seam).
static func seam_y(c: Vector3, th: float, r: float) -> float:
	return WOB * r * Sculpt.noise(Vector3(cos(th), sin(th), 0.0) * 2.5 + c)


## One half of the geode: knobbly rind outside, an agate seam, a cave lined with crystals
## pointing inwards, and a ring of longer crystal teeth round the lip.
func half(rs: Sculpt, gs: Sculpt, c: Vector3, rr: float, h: float, up: bool, teeth: float) -> void:
	var sg := 1.0 if up else -1.0
	var rp := rs.add_painter(_rind()); var ap := rs.add_painter(_agate()); var cp := rs.add_painter(_cave())
	var gp := gs.add_painter(_gem())
	var shape := [Vector2(0.0, 1.0), Vector2(0.42, 0.95), Vector2(0.7, 0.8), Vector2(0.88, 0.58), Vector2(0.97, 0.3), Vector2(1.0, 0.0)]
	var t := 0.075
	var outer: Array = []; var inner: Array = []
	for q: Vector2 in shape:
		outer.append(Vector2(q.x * rr, q.y * h * sg))
		inner.append(Vector2(q.x * (rr - t), q.y * (h - t) * sg))
	if not up: outer.reverse()
	if up: inner.reverse()
	rs.lathe(c, outer, rp, {"sides": 28, "wobble": WOB})
	rs.lathe(c, inner, cp, {"sides": 28, "wobble": WOB})
	var ring: Array = []
	for k in range(7): ring.append(Vector2(lerpf(rr, rr - t, k / 6.0), 0.0))
	rs.lathe(c, ring, ap, {"sides": 28, "wobble": WOB})
	# Botryoidal knobs: the bumpy "cauliflower" skin of a real geode.
	for k in range(46):
		var th := rng.randf() * TAU; var el := rng.randf_range(0.12, 1.0)
		var q := Vector3(cos(th) * sqrt(1.0 - el * el) * rr, el * h * sg, sin(th) * sqrt(1.0 - el * el) * rr)
		rs.blob(c + q * 0.97, Vector3.ONE * rng.randf_range(0.035, 0.08), rp, {"lat": 4, "lon": 6, "lump": 0.35})
	# Crystals lining the cave, every one pointing towards the middle.
	for k in range(64):
		var th := rng.randf() * TAU; var el := rng.randf_range(0.05, 0.95)
		var dir := Vector3(cos(th) * sqrt(1.0 - el * el), el * sg, sin(th) * sqrt(1.0 - el * el))
		var at := c + Vector3(dir.x * (rr - t), dir.y * (h - t), dir.z * (rr - t)) * 0.99
		var aim := (c - at).normalized() + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
		gs.crystal(at, aim, rng.randf_range(0.06, 0.14), rng.randf_range(0.018, 0.034), gp, 6, rng.randf() * PI)
	# The teeth: longer crystals round the lip, biggest at the front.
	var n := 22
	for k in range(n):
		var th := TAU * (k + 0.5) / n
		var front := clampf(-sin(th), 0.0, 1.0)
		var r0 := rr - t * 0.6
		var at := c + Vector3(cos(th) * r0, seam_y(c, th, r0) + 0.01 * sg, sin(th) * r0)
		var aim := Vector3(-cos(th) * 0.45, -sg, -sin(th) * 0.45)
		gs.crystal(at, aim, teeth * (0.55 + 0.6 * front) * rng.randf_range(0.8, 1.15), 0.024 + 0.012 * front, gp, 6, rng.randf() * PI)


## Crab legs: a short coxa, the long merus up and out to the knee, then carpus, propodus and a
## pointed dactyl down to the ground; dark joint membranes between the segments.
func crab_legs(spots: Array, span: float, rise: float, thick: float, spiny: bool) -> Array:
	var hips: Array = []; var knees: Array = []
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		var out := Vector3(signf(at.x), 0.0, at.z * 1.6).normalized()
		var hip := joint(root, ("Foreleg%d" if at.z < 0.0 else "Hindleg%d") % k, at)
		var knee_at := at + out * span * 0.42 + Vector3(0, rise, 0)
		var ts := Sculpt.new(); var tp := ts.add_painter(_chitin()); var kp := ts.add_painter(_knuckle())
		ts.blob(at, Vector3.ONE * thick * 0.95, kp, {"lat": 5, "lon": 7})
		var side_n := out.cross(Vector3.UP).normalized()
		ts.tube([at + out * 0.03, at.lerp(knee_at, 0.5) + Vector3(0, 0.03, 0), knee_at], [thick * 1.15, thick * 1.2, thick * 0.9], tp, {"sides": 10, "per": 3, "flat": 0.5, "side": side_n})
		if spiny:
			var sp := ts.add_painter(func (_p, _n, v, _w): return leg_b.lerp(Color.WHITE, v))
			for j in range(4):
				var s0 := at.lerp(knee_at, 0.2 + j * 0.2)
				ts.crystal(s0 + Vector3(0, thick * 0.8, 0), Vector3(out.x * 0.3, 1.0, out.z * 0.3), thick * 1.1, thick * 0.25, sp, 4)
		part(hip, "Merus", ts, flesh)
		var knee := joint(hip, "Knee", knee_at)
		var foot := Vector3(at.x, 0.0, at.z) + out * span + Vector3(0, 0.015, 0)
		var c2 := knee_at + out * span * 0.2 - Vector3(0, rise * 0.15, 0)
		var c3 := foot + out * -0.04 + Vector3(0, 0.22 + rise * 0.15, 0)
		var ss := Sculpt.new(); var sp2 := ss.add_painter(_chitin()); var kp2 := ss.add_painter(_knuckle())
		var tip := ss.add_painter(func (_p, _n, v, _w): return leg_a.darkened(0.6).lerp(Color("#1a1410"), v))
		ss.blob(knee_at, Vector3.ONE * thick * 0.8, kp2, {"lat": 5, "lon": 7})
		ss.tube([knee_at, c2], [thick * 0.8, thick * 0.75], sp2, {"sides": 8, "per": 2})
		ss.blob(c2, Vector3.ONE * thick * 0.66, kp2, {"lat": 4, "lon": 6})
		ss.tube([c2, c2.lerp(c3, 0.5) + out * 0.02, c3], [thick * 0.78, thick * 0.74, thick * 0.55], sp2, {"sides": 9, "per": 3, "flat": 0.55, "side": out.cross(Vector3.UP).normalized()})
		ss.blob(c3, Vector3.ONE * thick * 0.5, kp2, {"lat": 4, "lon": 6})
		ss.tube([c3, c3.lerp(foot, 0.55) + out * 0.03, foot], [thick * 0.5, thick * 0.32, 0.003], tip, {"sides": 7, "per": 3, "cap1": false})
		if spiny:
			var sp3 := ss.add_painter(func (_p, _n, v, _w): return leg_b.lerp(Color.WHITE, v))
			for j in range(3): ss.crystal(c2.lerp(c3, 0.2 + j * 0.3) + Vector3(0, thick * 0.5, 0), Vector3(out.x * 0.5, 1.0, out.z * 0.5), thick * 0.9, thick * 0.2, sp3, 4)
		part(knee, "Shin", ss, flesh)
		hips.append(hip); knees.append(knee)
	return [hips, knees]


## A crab claw (cheliped): merus and carpus from `base`, a swollen palm, a fixed finger and a
## movable finger closing on it, their inner edges set with small crystal teeth. The palm runs
## along `along`, the fingers point along `point`, `flat` presses the palm into a plate.
func claw(s: Sculpt, gs: Sculpt, base: Vector3, elbow: Vector3, palm0: Vector3, palm1: Vector3, point: Vector3, size: float, flat: float, crest: bool) -> void:
	var cp := s.add_painter(_chitin()); var kp := s.add_painter(_knuckle())
	var rp := s.add_painter(_rind())
	var fp := s.add_painter(func (_p, _n, v, _w): return leg_a.darkened(0.55).lerp(Color("#15100c"), v))
	var gp := gs.add_painter(_gem())
	s.blob(base, Vector3.ONE * size * 0.32, kp, {"lat": 5, "lon": 7})
	s.tube([base, elbow], [size * 0.3, size * 0.27], cp, {"sides": 9, "per": 2})
	s.blob(elbow, Vector3.ONE * size * 0.28, kp, {"lat": 5, "lon": 7})
	s.tube([elbow, palm0], [size * 0.27, size * 0.33], cp, {"sides": 9, "per": 2})
	var along := (palm1 - palm0).normalized()
	var face := along.cross(point).normalized()
	# The palm: a swollen, armoured propodus, its outside rind-like so it passes for stone.
	s.tube([palm0, palm0.lerp(palm1, 0.5), palm1], [size * 0.42, size * 0.5, size * 0.4], rp if flat > 0.0 else cp, {"sides": 12, "per": 3, "flat": 1.0 - flat * 0.6, "side": face, "lump": 0.06})
	var f0 := palm1 + point * size * 0.15
	var fixed_tip := f0 + point * size * 0.75 + along * size * 0.15
	s.tube([f0, f0.lerp(fixed_tip, 0.5), fixed_tip], [size * 0.2, size * 0.15, 0.004], fp, {"sides": 8, "per": 3, "cap1": false})
	var m0 := f0 - along * size * 0.28 + face * 0.0
	var m_tip := m0 + point * size * 0.8 - along * size * 0.05
	s.tube([m0, m0.lerp(m_tip, 0.5) - along * size * 0.04, m_tip], [size * 0.19, size * 0.14, 0.004], fp, {"sides": 8, "per": 3, "cap1": false})
	for j in range(3):
		var tb := f0.lerp(fixed_tip, 0.15 + j * 0.25)
		gs.crystal(tb, -along + point * 0.2, size * 0.12, size * 0.035, gp, 5)
	if crest:
		# The box crab's cockscomb: a row of crystal points along the top of the palm.
		for j in range(6):
			var at := palm0.lerp(palm1, 0.05 + j * 0.18) + Vector3(0, size * 0.42, 0)
			gs.crystal(at, Vector3(0, 1, 0) - point * 0.3, size * (0.18 + 0.06 * (j % 2)), size * 0.05, gp, 6, j * 0.7)


# ------------------------------------------------------------------ the mimic

func _geode(height: float, rr: float, h_up: float, h_dn: float, span: float, rise: float, scale: float) -> Node3D:
	var c := Vector3(0, height, 0)
	var head := joint(root, "Head", c)
	# The bottom half rides on the head; the top half is the jaw, hinged at the back of the seam
	# and turned round so that opening the jaw lifts the lid at the front.
	var hinge := c + Vector3(0, seam_y(c, PI * 0.5, rr), rr * 0.92)
	var jaw := joint(head, "Jaw", hinge); jaw.rotation.y = PI
	var lid := Node3D.new(); lid.name = "Lid"; lid.rotation.y = PI; jaw.add_child(lid)
	var bs := Sculpt.new(); var bg := Sculpt.new()
	half(bs, bg, c, rr, h_dn, false, 0.13 if kindg != "boxcrab" else 0.11)
	part(head, "ShellBase", bs, rind_mat); part(head, "CrystalsBase", bg, gem_mat)
	var ls := Sculpt.new(); var lg := Sculpt.new()
	half(ls, lg, c + Vector3(0, 0.012, 0), rr, h_up, true, 0.16 if kindg != "boxcrab" else 0.13)
	# Stalked crab eyes down in the cave, glowing.
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	var stalk := Sculpt.new(); var stp := stalk.add_painter(_chitin())
	for side in [-1.0, 1.0]:
		var e0 := c + Vector3(0.09 * side, -h_dn * 0.45, -rr * 0.35)
		var e1 := c + Vector3(0.15 * side, 0.07, -rr * 0.5)
		stalk.tube([e0, e0.lerp(e1, 0.5) + Vector3(0.02 * side, 0, 0), e1], [0.03, 0.025, 0.022], stp, {"sides": 7, "per": 2})
		es.blob(e1 + Vector3(0, 0.03, -0.01), Vector3(0.055, 0.06, 0.055), ew, {"lat": 5, "lon": 8})
	part(head, "EyeStalks", stalk, flesh)
	dim_eyes.albedo_color = glow_col; dim_eyes.emission = glow_col; dim_eyes.emission_energy_multiplier = 1.6
	var core := part(head, "Eyes", es, dim_eyes); core.material_override = dim_eyes
	var light := OmniLight3D.new(); light.name = "CaveGlow"; light.light_color = glow_col
	light.light_energy = 0.7 if kindg == "spider" else 0.45; light.omni_range = rr * 2.2
	light.position = Vector3(0, -h_dn * 0.3, 0); head.add_child(light)
	# The claws.
	var cs := Sculpt.new(); var cg := Sculpt.new()
	match kindg:
		"amethyst":
			# A shore crab's claws, folded under the front of the seam.
			for side in [-1.0, 1.0]:
				var b0 := c + Vector3(0.24 * side, -h_dn * 0.55, -rr * 0.6)
				claw(cs, cg, b0, b0 + Vector3(0.2 * side, -0.06, -0.18), c + Vector3(0.3 * side, -h_dn * 0.4, -rr - 0.12),
					c + Vector3(0.08 * side, -h_dn * 0.33, -rr - 0.16), Vector3(-side * 0.5, 0.15, -0.6).normalized(), 0.24, 0.0, false)
			part(head, "Claws", cs, flesh); part(head, "ClawTeeth", cg, gem_mat)
		"boxcrab":
			# Two huge flat claws held up over the face like a visor; they lift with the lid.
			for side in [-1.0, 1.0]:
				var b0 := c + Vector3(0.3 * side, -h_dn * 0.6, -rr * 0.55)
				claw(cs, cg, b0, b0 + Vector3(0.14 * side, -0.02, -0.14), c + Vector3(0.4 * side, -0.08, -rr * 0.82),
					c + Vector3(0.06 * side, -0.04, -rr - 0.06), Vector3(-side * 0.2, -0.9, -0.15).normalized(), 0.46, 1.0, true)
			part(lid, "Claws", cs, flesh); part(lid, "ClawCrests", cg, gem_mat)
		"spider":
			# The spider crab's long, thin chelipeds, held low in front.
			for side in [-1.0, 1.0]:
				var b0 := c + Vector3(0.18 * side, -h_dn * 0.6, -rr * 0.6)
				claw(cs, cg, b0, b0 + Vector3(0.3 * side, -0.15, -0.35), c + Vector3(0.36 * side, -0.62, -rr - 0.45),
					c + Vector3(0.28 * side, -0.78, -rr - 0.6), Vector3(-side * 0.2, -0.4, -0.8).normalized(), 0.16, 0.0, false)
			part(head, "Claws", cs, flesh); part(head, "ClawTeeth", cg, gem_mat)
	part(lid, "ShellLid", ls, rind_mat); part(lid, "CrystalsLid", lg, gem_mat)
	# Eight walking legs from under the seam.
	var spots: Array = []
	for z: float in [-0.2, -0.04, 0.12, 0.27]:
		var zz := z * rr / 0.5
		for side in [-1.0, 1.0]:
			spots.append(c + Vector3(side * sqrt(maxf(rr * rr - zz * zz, 0.01)) * 0.78, -h_dn * 0.42, zz))
	var thick: float = {"amethyst": 0.072, "boxcrab": 0.068, "spider": 0.048}[kindg]
	var legs := crab_legs(spots, span, rise, thick, kindg == "spider")
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": legs[0], "knees": legs[1], "leaves": []}, scale)
	return _with_visual(node, head, legs[0], legs[1], jaw)
