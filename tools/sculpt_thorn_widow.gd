extends "res://tools/sculpt_grave_creeper.gd"
## The Thorn Widow of Hollowmourn, sculpted by hand: a great spider on spindly legs studded with
## thorns, its abdomen dark as bark; the strands of its web tremble before it pounces. Three
## designs, each built on a real spider:
##   bark    - Darwin's bark spider of Madagascar, which spins the biggest orb webs on Earth (across
##             whole rivers) and is coloured and knobbed like bark: a lumpy, two-horned abdomen
##             with lichen on it, banded legs and long strands of silk trailing behind
##   widow   - a black widow wrapped in brambles: a glossy black ball of an abdomen with the blood-red
##             hourglass beneath and a red spot on top, long glossy legs, and a briar of thorns and
##             rose hips grown through its legs
##   spiny   - a spiny orb-weaver (Gasteracantha and its kin): a hard, wide, flat abdomen ringed with
##             long curved thorns and dotted with pale spots, set on a small body and thick legs
## Every spider has eight eyes in rows (the front middle pair biggest), fanged jaws (chelicerae),
## a pair of feelers (pedipalps) and spinnerets at the tail.

var shiny_mat: StandardMaterial3D
var silk_mat: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = load("res://assets/cast/bark_detail_gray.png")
	shiny_mat = material.duplicate()
	shiny_mat.albedo_texture = null; shiny_mat.roughness = 0.18; shiny_mat.metallic_specular = 0.9
	silk_mat = StandardMaterial3D.new()
	silk_mat.vertex_color_use_as_albedo = true
	silk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "ThornWidow"
	kind = variant
	match variant:
		"bark": glow.albedo_color = Color("#ffb060").darkened(0.2); glow.emission = Color("#ffb060")
		"widow": glow.albedo_color = Color("#ff3020").darkened(0.2); glow.emission = Color("#ff3a2a")
		"spiny": glow.albedo_color = Color("#c8ff9a").darkened(0.2); glow.emission = Color("#c8ff9a")
	glow.emission_energy_multiplier = 1.8
	if not variant in ["bark", "widow", "spiny"]: return null
	return _spider()


# ------------------------------------------------------------------ painters

## Dark bark: grey-brown, deeply furrowed and knotted, blotched with pale lichen.
static func dark_bark(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#241e1a").lerp(Color("#5e5248"), clampf(Sculpt.fbm(Vector3(p.x * 9.0, p.y * 4.0, p.z * 9.0)) * 0.8 + 0.4 + n.y * 0.15, 0.0, 1.0))
	c = c.darkened(smoothstep(0.75, 0.95, absf(sin(Sculpt.fbm(p * 5.0) * 30.0))) * 0.45)
	c = c.darkened(clampf(-w, 0.0, 1.0) * 0.3)
	return c.lerp(LICHEN.darkened(0.15), smoothstep(0.62, 0.76, Sculpt.noise(p * 11.0 + Vector3(3, 2, 1))) * 0.55)


static func gloss_black(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#0a0809").lerp(Color("#2a2428"), clampf(n.y * 0.4 + 0.2 + Sculpt.noise(p * 8.0) * 0.15, 0.0, 1.0))


static func silk(_p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	return Color(0.9, 0.92, 0.95, 0.55 - 0.25 * v)


# ------------------------------------------------------------------ the spider

func _spider() -> Node3D:
	var skin: Callable = dark_bark
	if kind == "widow": skin = gloss_black
	var thorn_c := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#1a1412").lerp(Color("#c8a878") if kind != "spiny" else Color("#c04a2a"), v * 0.85)
	var y := 0.62
	# The cephalothorax: low and broad, sloping up to the eyes at the front.
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	body.blob(Vector3(0, y, -0.22), Vector3(0.22, 0.13, 0.25), bp, {"lat": 8, "lon": 12, "lump": 0.06})
	body.blob(Vector3(0, y + 0.06, -0.36), Vector3(0.14, 0.1, 0.12), bp, {"lat": 6, "lon": 10})
	body.tube([Vector3(0, y, -0.02), Vector3(0, y + 0.02, 0.06)], [0.07, 0.07], bp, {"sides": 8, "per": 1})
	part(root, "Body", body)
	# The abdomen.
	var abd := joint(root, "Abdomen", Vector3(0, y + 0.02, 0.06))
	var ab := Sculpt.new(); var ap := ab.add_painter(skin)
	var ac := Vector3(0, y + 0.12, 0.42)
	match kind:
		"bark":
			ab.blob(ac, Vector3(0.3, 0.26, 0.38), ap, {"lat": 10, "lon": 14, "lump": 0.12})
			for side: float in [-1.0, 1.0]:
				# Two horn-like humps at the front of the abdomen, and knobs all over like bark.
				ab.blob(ac + Vector3(0.17 * side, 0.17, -0.12), Vector3(0.13, 0.1, 0.12), ap, {"lat": 6, "lon": 9, "lump": 0.35})
				ab.tube([ac + Vector3(0.2 * side, 0.22, -0.12), ac + Vector3(0.27 * side, 0.27, -0.06)], [0.05, 0.012], ap, {"sides": 7, "per": 2, "lump": 0.3})
			for k in range(22):
				var a := TAU * fposmod(k * 0.618, 1.0); var b := lerpf(-0.6, 1.2, fposmod(k * 0.37, 1.0))
				var at := ac + Vector3(cos(a) * cos(b) * 0.29, sin(b) * 0.25, sin(a) * cos(b) * 0.37)
				ab.rock(at, Vector3.ONE * (0.03 + 0.03 * fposmod(k * 0.53, 1.0)), ap, {"seed": k})
			moss_clump(ab, ab.add_painter(grave_moss), ac + Vector3(0.05, 0.25, 0.05), 0.08, 4)
		"widow":
			ab.blob(ac + Vector3(0, 0.02, 0.02), Vector3(0.34, 0.32, 0.4), ap, {"lat": 12, "lon": 16})
			var red := ab.add_painter(func (p, n, v, w): return Color("#c01810").lightened(clampf(n.y, 0.0, 1.0) * 0.2))
			# The hourglass on the belly and a red spot above the spinnerets.
			ab.blob(ac + Vector3(0, -0.29, -0.05), Vector3(0.07, 0.03, 0.09), red, {"lat": 4, "lon": 8})
			ab.blob(ac + Vector3(0, -0.28, 0.12), Vector3(0.07, 0.03, 0.09), red, {"lat": 4, "lon": 8})
			ab.blob(ac + Vector3(0, -0.3, 0.035), Vector3(0.03, 0.02, 0.04), red, {"lat": 3, "lon": 6})
			ab.blob(ac + Vector3(0, 0.22, 0.28), Vector3(0.07, 0.04, 0.07), red, {"lat": 4, "lon": 7})
			ab.blob(ac + Vector3(0, 0.3, 0.1), Vector3(0.05, 0.03, 0.05), red, {"lat": 4, "lon": 7})
		"spiny":
			ab.blob(ac + Vector3(0, 0.08, -0.02), Vector3(0.52, 0.16, 0.34), ap, {"lat": 8, "lon": 16, "lump": 0.05, "basis": Basis(Vector3.RIGHT, -0.35)})
			var pale := ab.add_painter(func (p, n, v, w): return Color("#d8ccaa"))
			for k in range(10):
				var a := TAU * k / 10.0
				ab.blob(ac + Vector3(cos(a) * 0.3, 0.22 + sin(a) * 0.06, sin(a) * 0.18), Vector3(0.035, 0.012, 0.035), pale, {"lat": 3, "lon": 6})
			var tp := ab.add_painter(thorn_c)
			for k in range(6):
				var a := lerpf(-0.5, 0.5, (k % 3) / 2.0) * 1.6 + (0.0 if k < 3 else PI)
				var base := ac + Vector3(cos(a) * 0.46, 0.08 + sin(a) * 0.1, sin(a) * 0.28)
				var dir := Vector3(cos(a), 0.55, sin(a) * 0.6).normalized()
				ab.tube([base, base + dir * 0.25, base + dir * 0.48 + Vector3(0, 0.12, 0)], [0.055, 0.032, 0.004], tp, {"sides": 7, "per": 2, "cap1": false})
	# Spinnerets at the tail.
	var st := ac + Vector3(0, -0.12, 0.36 if kind != "spiny" else 0.25)
	for side: float in [-1.0, 1.0]: ab.tube([st + Vector3(0.025 * side, 0.02, -0.04), st + Vector3(0.03 * side, -0.02, 0.03)], [0.02, 0.01], ap, {"sides": 5, "per": 1})
	part(abd, "Abdomen", ab, shiny_mat if kind == "widow" else material)
	# Silk trailing from the spinnerets down to the ground, and a few anchor lines.
	var sk := Sculpt.new(); var sp := sk.add_painter(silk)
	for k in range(4):
		var e := st + Vector3(0.05 * (k - 1.5), -0.28 - 0.06 * k, 0.12 + 0.07 * k)
		sk.tube([st, st.lerp(e, 0.5) + Vector3(0, -0.05, 0), e], [0.005, 0.004, 0.003], sp, {"sides": 3, "per": 3})
	part(abd, "Silk", sk, silk_mat)
	if kind == "widow":
		# A briar of brambles grown round the abdomen.
		var br := Sculpt.new()
		var path: Array = []
		for k in range(14):
			var t := k / 13.0
			var a := t * TAU * 1.3
			path.append(ac + Vector3(cos(a) * 0.36, 0.12 * sin(a * 2.0) - 0.05 + t * 0.1, sin(a) * 0.42))
		briar(br, path, 0.032, 16, 5, 6)
		part(abd, "Briar", br)

	# The head end: eight eyes, the jaws with their fangs, and the feelers.
	var head := joint(root, "Head", Vector3(0, y + 0.06, -0.42))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin); var dk := hs.add_painter(func (p, n, v, w): return Color("#08060a"))
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		var big := Vector3(0.035 * side, y + 0.12, -0.47)
		hs.blob(big, Vector3(0.032, 0.032, 0.028), dk, {"lat": 5, "lon": 8}); eyes.append(big + Vector3(0, 0, -0.008))
		for e in [Vector3(0.085 * side, y + 0.12, -0.45), Vector3(0.06 * side, y + 0.17, -0.42), Vector3(0.1 * side, y + 0.16, -0.38)]:
			hs.blob(e, Vector3.ONE * 0.018, dk, {"lat": 4, "lon": 6}); eyes.append(e + Vector3(0, 0, -0.005))
	part(head, "Head", hs, shiny_mat if kind == "widow" else material)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for k in range(eyes.size()): es.blob(eyes[k], Vector3.ONE * (0.022 if k % 4 == 0 else 0.012), ew, {"lat": 4, "lon": 7})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var pincers: Array = []
	for side: float in [-1.0, 1.0]:
		var cb := Vector3(0.05 * side, y + 0.04, -0.5)
		var ch := joint(head, "Chelicera" + ("Left" if side < 0 else "Right"), cb)
		var cs := Sculpt.new(); var cp := cs.add_painter(skin); var fp := cs.add_painter(func (p, n, v, w): return Color("#1a1210").lerp(Color("#c8b890"), v))
		cs.tube([cb, cb + Vector3(0.005 * side, -0.08, -0.04), cb + Vector3(0.0, -0.14, -0.03)], [0.045, 0.04, 0.03], cp, {"sides": 8, "per": 2})
		cs.tube([cb + Vector3(0, -0.14, -0.03), cb + Vector3(-0.03 * side, -0.2, 0.0), cb + Vector3(-0.05 * side, -0.21, 0.04)], [0.016, 0.01, 0.002], fp, {"sides": 5, "per": 2, "cap1": false})
		part(ch, "Fang", cs, shiny_mat if kind == "widow" else material)
		pincers.append(ch)
		# A feeler beside each jaw.
		var pb := Vector3(0.09 * side, y - 0.02, -0.44)
		var pk := pb + Vector3(0.06 * side, 0.08, -0.1)
		cs = Sculpt.new(); cp = cs.add_painter(skin)
		cs.tube([pb, pk, pk + Vector3(0.02 * side, -0.12, -0.06), pk + Vector3(0.02 * side, -0.2, -0.04)], [0.025, 0.022, 0.02, 0.012], cp, {"sides": 6, "per": 2})
		part(head, "Palp" + ("Left" if side < 0 else "Right"), cs, shiny_mat if kind == "widow" else material)

	# Eight legs on thorny joints: high knees, then down and out to the tip.
	var hips: Array = []; var knees: Array = []
	var reach := 1.3 if kind != "spiny" else 1.05
	var th := 0.034 if kind == "widow" else 0.042 if kind == "bark" else 0.05
	for j in range(4):
		for side: float in [-1.0, 1.0]:
			var at := Vector3(0.14 * side, y - 0.02, -0.34 + j * 0.09)
			var ang := lerpf(-0.95, 0.75, j / 3.0)
			var o := Vector3(side * cos(ang), 0, sin(ang)).normalized()
			var r := reach * (1.0 if j == 0 or j == 3 else 0.88)
			var kn := at + o * r * 0.36 + Vector3(0, 0.42, 0)
			var mid := at + o * r * 0.74 + Vector3(0, 0.12, 0)
			var tip := at + o * r + Vector3(0, -y + 0.01, 0)
			var leg := jleg(root, "Leg%d" % hips.size(), [at, kn, mid, tip], [th, th * 0.95, th * 0.7, th * 0.3], (func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return dark_bark(p, n, v, w).lerp(Color("#8a7a62"), smoothstep(0.6, 0.85, sin(v * 13.0 + 1.0)) * 0.45)) if kind == "bark" else skin)
			hips.append(leg[0]); knees.append(leg[1])
			# Thorns along each leg.
			var ts := Sculpt.new(); var tpp := ts.add_painter(thorn_c)
			for q in range(5): ts.crystal(at.lerp(kn, 0.25 + q * 0.17) + Vector3(0, 0.015, 0), (o * 0.3 + Vector3(0, 1, 0.2)).normalized(), 0.09, 0.016, tpp, 4)
			part(leg[0], "Thorns", ts)
			var ts2 := Sculpt.new(); var tp2 := ts2.add_painter(thorn_c)
			for q in range(4): ts2.crystal(kn.lerp(mid, 0.2 + q * 0.22), (o + Vector3(0, 0.6, 0)).normalized(), 0.08, 0.014, tp2, 4)
			part(leg[1], "Thorns", ts2)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": []}, 1.5)
	return _rig(node, head, hips, knees, null, [abd], pincers)
