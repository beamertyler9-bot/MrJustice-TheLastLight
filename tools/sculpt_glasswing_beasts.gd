extends "res://tools/sculpt_glasswing_reaver.gd"
## The Glasswing Reaver of Prismere, second round: winged hunters whose wings are blades of
## clear glass around a dark body; it lines its wings up before it sweeps through you.
##   wyvern - built on the pterosaurs (Pteranodon, Rhamphorhynchus): the wing is a skin
##            stretched from one hugely long fourth finger back to the ankle, stiffened by
##            fine fibres (actinofibrils) fanning through it; three small clawed fingers at the
##            wrist, a long toothed beak, a crest swept back from the skull and a long tail
##            ending in a diamond-shaped vane. Here the wing skin is glass, the fibres dark lead
##   manta  - built on the manta and devil rays, which "fly" through the sea and leap clear of
##            it: a broad diamond of a body, black above with pale shoulder marks and white
##            beneath, two curled horn-fins (cephalic fins) either side of a wide mouth, gill
##            slits underneath and a whip tail; here the wings turn from dark flesh into glass
##            blades towards their tips, and the tail carries a glass barb like a stingray's
##   falcon - built on the peregrine falcon, the fastest animal alive in its hunting dive: a
##            slate-dark back, a barred pale chest, the black "moustache" under the eye, a
##            hooked, notched beak and yellow feet with black talons; here its long primary
##            flight feathers and its tail are blades of glass

var kindb := "wyvern"
var obsidian: StandardMaterial3D


func _init() -> void:
	super()
	obsidian = carapace.duplicate()
	obsidian.metallic = 0.15; obsidian.roughness = 0.42


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "GlasswingReaver"
	kindb = variant
	match variant:
		"wyvern": return _wyvern()
		"manta": return _manta()
		"falcon": return _falcon()
	return null


# ------------------------------------------------------------------ shared

static func along_line(pts: Array, t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


## A two-sided skin stretched between two lines of points, `a` (the leading bones) and `b`
## (where it meets the body); the free edge between their ends bows inwards. The painter gets
## v = along the lines, w = across from a to b.
func skin(s: Sculpt, painter: int, a: Array, b: Array, sag: Vector3, rows := 12, cols := 8) -> void:
	for layer in [0, 1]:
		var base := s._v.size()
		for i in range(rows + 1):
			for j in range(cols + 1):
				var u := j / float(cols)
				var t := i / float(rows)
				var q := along_line(a, t).lerp(along_line(b, t), u) + sag * sin(PI * u) * (0.3 + t) + Vector3(0, 0.002 if layer == 0 else -0.002, 0)
				s._v.append(q); s._along.append(t); s._ridge.append(u); s._painter.append(painter)
		var want := Vector3.UP if layer == 0 else Vector3.DOWN
		for i in range(rows):
			for j in range(cols):
				var k := base + i * (cols + 1) + j
				var pa: Vector3 = s._v[k]; var pb: Vector3 = s._v[k + cols + 1]; var pc: Vector3 = s._v[k + 1]
				if (pc - pa).cross(pb - pa).dot(want) > 0.0: s._i.append_array(PackedInt32Array([k, k + cols + 1, k + 1, k + 1, k + cols + 1, k + cols + 2]))
				else: s._i.append_array(PackedInt32Array([k, k + 1, k + cols + 1, k + 1, k + cols + 2, k + cols + 1]))


func glowing_eyes(head: Node3D, at: Array, r: float, col: Color) -> MeshInstance3D:
	glow.albedo_color = col.darkened(0.3); glow.emission = col; glow.emission_energy_multiplier = 1.0
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for e: Vector3 in at: es.blob(e, Vector3.ONE * r, ew, {"lat": 5, "lon": 8})
	var core := part(head, "Eyes", es, glow); core.material_override = glow
	var ps := Sculpt.new(); var pp := ps.add_painter(func (_p, _n, _v, _w): return Color("#050304"))
	for e: Vector3 in at: ps.blob(e + Vector3(signf(e.x) * r * 0.9, 0, -r * 0.2), Vector3(r * 0.12, r * 0.75, r * 0.3), pp, {"lat": 4, "lon": 6})
	part(head, "Pupils", ps)
	return core


static func obsidian_skin(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#0c0a12").lerp(Color("#3a3448"), clampf(n.y * 0.4 + 0.35 + Sculpt.fbm(p * 9.0) * 0.4, 0.0, 1.0))
	return c.lerp(Color("#5a4a8a"), smoothstep(0.5, 0.65, Sculpt.noise(p * 7.0)) * 0.35)


# ------------------------------------------------------------------ A: wyvern

## A dragon's belly: broad pale plates (scutes) across the underside of chest, neck and tail.
static func wyvern_hide(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := obsidian_skin(p, n, v, w)
	var plate := Color("#5a4a78").lerp(Color("#8a7aa8"), clampf(0.5 + Sculpt.noise(p * 10.0) * 0.4, 0.0, 1.0))
	plate = plate.darkened(smoothstep(0.82, 0.95, fposmod(p.z * 11.0 + p.y * 6.0, 1.0)) * 0.6)
	return c.lerp(plate, smoothstep(-0.35, -0.7, n.y))


func _wyvern() -> Node3D:
	var y := 1.3
	var hornc := func (_p, _n, v: float, _w) -> Color: return Color("#140c1c").lerp(Color("#d0c0f8"), v)
	var glassp := func (_p, _n, v: float, _w) -> Color: return Color("#6a4aa8").lerp(Color("#f0ecff"), v)
	var bs := Sculpt.new(); var bp := bs.add_painter(wyvern_hide); var gl := bs.add_painter(glassp)
	# A deep, muscular chest for the flight muscles, a lean belly.
	bs.blob(Vector3(0, y, -0.06), Vector3(0.22, 0.22, 0.32), bp, {"lat": 12, "lon": 16, "lump": 0.04})
	bs.blob(Vector3(0, y - 0.05, 0.18), Vector3(0.17, 0.16, 0.24), bp, {"lat": 9, "lon": 12, "lump": 0.04})
	# A long S-curved neck carrying the head high.
	var neck := [Vector3(0, y + 0.06, -0.28), Vector3(0, y + 0.22, -0.44), Vector3(0, y + 0.4, -0.48), Vector3(0, y + 0.54, -0.56)]
	bs.tube(neck, [0.14, 0.11, 0.09, 0.08], bp, {"sides": 14, "per": 4, "bands": 9, "band": 0.05})
	# The long tail, ending in a barbed spade of glass, as on the heraldic wyvern.
	var tail := [Vector3(0, y - 0.04, 0.36), Vector3(0, y - 0.1, 0.72), Vector3(0.06, y - 0.18, 1.08), Vector3(0.02, y - 0.22, 1.42), Vector3(-0.04, y - 0.2, 1.7)]
	bs.tube(tail, [0.13, 0.08, 0.05, 0.03, 0.015], bp, {"sides": 12, "per": 4, "bands": 12, "band": 0.05})
	# Glass spines down the back, from the nape to the tip of the tail.
	var spine: Array = [neck[3], neck[2], neck[1], neck[0], Vector3(0, y + 0.18, -0.1), Vector3(0, y + 0.12, 0.18), tail[0], tail[1], tail[2], tail[3]]
	var tops: Array = [0.08, 0.09, 0.11, 0.14, 0.04, 0.04, 0.13, 0.08, 0.05, 0.03]
	for k in range(spine.size() - 1):
		for j in range(2):
			var at: Vector3 = (spine[k] as Vector3).lerp(spine[k + 1], j * 0.5)
			var r: float = lerpf(tops[k], tops[k + 1], j * 0.5)
			var sz := 0.13 if k >= 3 and k <= 6 else 0.09
			bs.crystal(at + Vector3(0, r * 0.95, 0), Vector3(0, 1, 0.6), sz * (1.0 - k * 0.05), 0.022, gl, 4, k * 0.4)
	part(root, "Body", bs)
	var ts := Sculpt.new(); var tg := ts.add_painter(clear_glass(Color("#b8a0f8"), Color("#3a2a5a")))
	var tip: Vector3 = tail[4]
	var fwd := ((tail[4] as Vector3) - (tail[3] as Vector3)).normalized()
	var sideways := fwd.cross(Vector3.UP).normalized()
	skin(ts, tg, [tip - fwd * 0.04, tip + sideways * 0.14 - fwd * 0.06, tip + fwd * 0.3], [tip - fwd * 0.04, tip - sideways * 0.14 - fwd * 0.06, tip + fwd * 0.3], Vector3.ZERO, 5, 4)
	part(root, "TailSpade", ts, glass)
	# The head: a true dragon's head - heavy brows, a long snout with flared nostrils, crystal
	# teeth, swept-back horns and a frill of glass spines behind the jaw.
	var head := joint(root, "Head", Vector3(0, y + 0.56, -0.6))
	var hs := Sculpt.new(); var hp := hs.add_painter(wyvern_hide); var hn := hs.add_painter(hornc)
	var tooth := hs.add_painter(glassp); var dark := hs.add_painter(func (_p, _n, _v, _w): return Color("#050308"))
	hs.blob(Vector3(0, y + 0.6, -0.62), Vector3(0.11, 0.09, 0.12), hp, {"lat": 8, "lon": 12})
	hs.tube([Vector3(0, y + 0.6, -0.66), Vector3(0, y + 0.58, -0.8), Vector3(0, y + 0.55, -0.95)], [0.085, 0.07, 0.052], hp, {"sides": 12, "per": 3, "flat": 1.15, "cap_len": 0.5})
	for side in [-1.0, 1.0]:
		hs.tube([Vector3(0.05 * side, y + 0.66, -0.76), Vector3(0.085 * side, y + 0.67, -0.66), Vector3(0.09 * side, y + 0.65, -0.57)], [0.02, 0.032, 0.02], hp, {"sides": 8, "per": 3})
		hs.blob(Vector3(0.035 * side, y + 0.59, -0.95), Vector3(0.016, 0.012, 0.014), dark, {"lat": 4, "lon": 6})
		hs.blob(Vector3(0.038 * side, y + 0.595, -0.92), Vector3(0.018, 0.012, 0.026), hp, {"lat": 4, "lon": 6})
		# Two great horns swept back and curving down, and a smaller pair beneath them.
		var hpts: Array = [Vector3(0.065 * side, y + 0.66, -0.58)]; var d := Vector3(0.3 * side, 0.45, 1.0).normalized()
		for k in range(1, 7):
			d = d.rotated(Vector3.RIGHT, 0.13); hpts.append((hpts[k - 1] as Vector3) + d * 0.07)
		hs.tube(hpts, [0.035, 0.03, 0.025, 0.018, 0.012, 0.007, 0.002], hn, {"sides": 8, "per": 2, "bands": 5, "band": 0.12, "cap1": false})
		var h2: Array = [Vector3(0.09 * side, y + 0.6, -0.56)]; d = Vector3(0.6 * side, 0.1, 1.0).normalized()
		for k in range(1, 5):
			d = d.rotated(Vector3.UP, -0.1 * side); h2.append((h2[k - 1] as Vector3) + d * 0.05)
		hs.tube(h2, [0.02, 0.015, 0.01, 0.006, 0.002], hn, {"sides": 6, "per": 2, "cap1": false})
		# A frill of glass spines fanning back from the jaw hinge.
		for k in range(4):
			hs.crystal(Vector3(0.1 * side, y + 0.56 - k * 0.025, -0.55 + k * 0.015), Vector3(side, -0.1 - k * 0.2, 0.8), 0.12 - k * 0.015, 0.016, tooth, 4)
		for k in range(6): hs.crystal(Vector3(0.05 * side, y + 0.54, -0.7 - k * 0.045), Vector3(0.15 * side, -1, -0.15), 0.04 - k * 0.003, 0.008, tooth, 4)
		hs.crystal(Vector3(0.045 * side, y + 0.54, -0.88), Vector3(0.1 * side, -1, -0.2), 0.07, 0.012, tooth, 4)
	part(head, "Head", hs)
	glow.albedo_color = Color("#7a3ac8"); glow.emission = Color("#c890ff"); glow.emission_energy_multiplier = 1.1
	var eyes := [Vector3(-0.08, y + 0.63, -0.7), Vector3(0.08, y + 0.63, -0.7)]
	var es := Sculpt.new(); var ew := es.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for e: Vector3 in eyes: es.blob(e, Vector3(0.022, 0.018, 0.028), ew, {"lat": 5, "lon": 8})
	var core := part(head, "Eyes", es, glow); core.material_override = glow
	var ps := Sculpt.new(); var pp := ps.add_painter(func (_p, _n, _v, _w): return Color("#050304"))
	for e: Vector3 in eyes: ps.blob(e + Vector3(signf(e.x) * 0.02, 0, -0.004), Vector3(0.003, 0.016, 0.006), pp, {"lat": 4, "lon": 6})
	part(head, "Pupils", ps)
	var jaw := joint(head, "Jaw", Vector3(0, y + 0.53, -0.6))
	var js := Sculpt.new(); var jp := js.add_painter(wyvern_hide); var jt := js.add_painter(glassp); var jh := js.add_painter(hornc)
	var gum := js.add_painter(func (_p, _n, _v, _w): return Color("#3a1030"))
	js.tube([Vector3(0, y + 0.53, -0.6), Vector3(0, y + 0.5, -0.78), Vector3(0, y + 0.51, -0.92)], [0.075, 0.055, 0.038], jp, {"sides": 10, "per": 3, "flat": 1.2, "cap_len": 0.5})
	js.blob(Vector3(0, y + 0.54, -0.76), Vector3(0.05, 0.012, 0.13), gum, {"lat": 4, "lon": 8})
	for side in [-1.0, 1.0]:
		for k in range(6): js.crystal(Vector3(0.045 * side, y + 0.535, -0.7 - k * 0.04), Vector3(0.15 * side, 1, -0.15), 0.035, 0.007, jt, 4)
		for k in range(3): js.crystal(Vector3(0.05 * side, y + 0.48, -0.66 - k * 0.07), Vector3(0.5 * side, -1, 0.4), 0.05, 0.01, jh, 4)
	part(jaw, "Jaw", js).rotation.x = -0.3
	# The wings: a dragon's wing is built like a bat's - the arm to the wrist, a hooked thumb,
	# then four long finger bones fanning out, with skin stretched between them and back to the
	# flank. Here the skin is glass and its edges scallop in between the fingers.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.17 * side, y + 0.13, -0.14)
		var node := joint(root, "%sWing0" % ["Left" if side < 0 else "Right"], sh)
		var e := sh + Vector3(0.28 * side, 0.14, 0.06)
		var w := e + Vector3(0.36 * side, 0.06, -0.12)
		var tips := [w + Vector3(0.74 * side, 0.12, 0.08), w + Vector3(0.66 * side, 0.02, 0.4), w + Vector3(0.46 * side, -0.06, 0.66), w + Vector3(0.18 * side, -0.12, 0.76)]
		var mids: Array = []
		for t: Vector3 in tips: mids.append(w.lerp(t, 0.5) + Vector3(0, 0.035, 0) + (t - w).cross(Vector3.UP).normalized() * 0.03 * side)
		var flank := Vector3(0.15 * side, y - 0.02, 0.32)
		var ws := Sculpt.new(); var wb := ws.add_painter(wyvern_hide); var claw := ws.add_painter(hornc)
		ws.tube([sh, sh.lerp(e, 0.5) + Vector3(0, 0.03, 0), e], [0.075, 0.065, 0.055], wb, {"sides": 10, "per": 2})
		ws.blob(e, Vector3.ONE * 0.055, wb, {"lat": 5, "lon": 8})
		ws.tube([e, w], [0.05, 0.04], wb, {"sides": 9, "per": 2})
		ws.blob(w, Vector3.ONE * 0.048, wb, {"lat": 5, "lon": 8})
		# The thumb: a hooked claw at the wrist.
		ws.tube([w, w + Vector3(0.02 * side, 0.08, -0.06), w + Vector3(0.0, 0.11, -0.12), w + Vector3(-0.01 * side, 0.08, -0.15)], [0.025, 0.018, 0.01, 0.002], claw, {"sides": 6, "per": 2, "cap1": false})
		for k in range(4):
			var t: Vector3 = tips[k]; var m: Vector3 = mids[k]
			ws.tube([w, m, t], [0.03 - k * 0.003, 0.02 - k * 0.002, 0.006], wb, {"sides": 7, "per": 3, "cap1": false})
			ws.blob(m, Vector3.ONE * (0.022 - k * 0.002), wb, {"lat": 4, "lon": 6})
			ws.crystal(t, (t - m).normalized(), 0.07, 0.008, claw, 4)
		var gs := Sculpt.new()
		var gp := gs.add_painter(func (p: Vector3, _n: Vector3, v: float, u: float) -> Color:
			var c := Color("#c8b0ff").lerp(Color.from_hsv(fposmod(v * 1.2 + u * 0.4 + p.x * 0.3, 1.0), 0.5, 1.0), 0.25 + 0.35 * smoothstep(0.75, 1.0, v))
			# Veins branching out through the skin.
			var vein := smoothstep(0.05, 0.0, absf(fposmod(u * 3.0 + v * 0.6, 1.0) - 0.5) - 0.44) * smoothstep(0.1, 0.4, v)
			c = c.lerp(Color("#1c0e30"), vein * 0.75)
			return Color(c.r, c.g, c.b, clampf(0.45 + 0.35 * smoothstep(0.8, 1.0, v) + 0.4 * vein, 0.0, 0.95)))
		for k in range(3):
			var ta: Vector3 = tips[k]; var tb: Vector3 = tips[k + 1]
			var sag := (w - (ta + tb) * 0.5).normalized() * 0.1
			skin(gs, gp, [w, mids[k], ta], [w, mids[k + 1], tb], sag, 10, 6)
		# From the last finger and the arm back to the flank.
		var t4: Vector3 = tips[3]
		skin(gs, gp, [sh, e, w, mids[3], t4], [sh + Vector3(0, -0.04, 0.12), sh.lerp(flank, 0.5), flank, flank, flank + Vector3(0.06 * side, 0, 0.04)], (w - t4).normalized() * 0.05 + Vector3(0, -0.02, 0), 12, 7)
		# The small fore-skin between shoulder and wrist.
		skin(gs, gp, [sh, e, w], [sh, sh.lerp(w, 0.5) + Vector3(0, 0.02, -0.08), w], Vector3.ZERO, 4, 3)
		part(node, "WingBones", ws, obsidian)
		part(node, "Wing", gs, glass)
		wings.append(node)
	# Strong hind legs hanging beneath: a thick thigh, a backward-bent ankle and three
	# hooked talons forward and one behind.
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var hip_at := Vector3(0.14 * side, y - 0.08, 0.2)
		var hip := joint(root, "Hindleg%s" % ("L" if side < 0 else "R"), hip_at)
		var knee_at := hip_at + Vector3(0.05 * side, -0.2, -0.12)
		var ankle := knee_at + Vector3(0.0, -0.18, 0.16)
		var foot := ankle + Vector3(0.0, -0.14, -0.04)
		var lsc := Sculpt.new(); var lp := lsc.add_painter(wyvern_hide)
		lsc.blob(hip_at + Vector3(0, -0.04, -0.02), Vector3(0.1, 0.13, 0.12), lp, {"lat": 7, "lon": 10})
		lsc.tube([hip_at, knee_at], [0.09, 0.065], lp, {"sides": 10, "per": 2})
		part(hip, "Thigh", lsc, obsidian)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(wyvern_hide); var cp := ss.add_painter(hornc)
		ss.blob(knee_at, Vector3.ONE * 0.06, sp, {"lat": 5, "lon": 8})
		ss.tube([knee_at, ankle, foot], [0.055, 0.04, 0.035], sp, {"sides": 9, "per": 2})
		for k in range(4):
			var cd := Vector3((k - 1) * 0.35, -0.45, -1.0 if k < 3 else 1.0).normalized()
			var t0 := foot + cd * 0.07
			ss.tube([foot, t0], [0.026, 0.02], sp, {"sides": 6, "per": 1})
			ss.tube([t0, t0 + cd * 0.04 + Vector3(0, -0.01, 0), t0 + cd * 0.05 + Vector3(0, -0.06, 0)], [0.02, 0.012, 0.002], cp, {"sides": 6, "per": 2, "cap1": false})
		part(knee, "Shin", ss, obsidian)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": wings}, 1.35)
	return _with_visual(node, head, hips, knees, wings, jaw)


# ------------------------------------------------------------------ B: manta

static func manta_top(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#0a0c12").lerp(Color("#262a36"), clampf(0.3 + Sculpt.fbm(p * 6.0) * 0.5, 0.0, 1.0))
	# The pale "shoulder" chevrons of a manta.
	var sh := smoothstep(0.06, 0.0, absf(absf(p.x) * 0.8 - (p.z + 0.25) * -0.9 - 0.18) - 0.05) * smoothstep(-0.4, -0.1, p.z) * smoothstep(0.15, -0.05, p.z)
	c = c.lerp(Color("#c8d0dc"), sh * smoothstep(0.2, 0.6, n.y) * 0.8)
	var under := Color("#e8ecf0").darkened(smoothstep(0.5, 0.62, Sculpt.noise(p * 11.0)) * 0.7)
	return c.lerp(under, smoothstep(-0.1, -0.5, n.y))


func _manta() -> Node3D:
	var y := 1.35
	var bs := Sculpt.new(); var bp := bs.add_painter(manta_top)
	var dark := bs.add_painter(func (_p, _n, _v, _w): return Color("#050608"))
	var barb := bs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#4a5a7a").lerp(Color("#eaf6ff"), v))
	bs.blob(Vector3(0, y, 0), Vector3(0.3, 0.11, 0.42), bp, {"lat": 10, "lon": 16})
	bs.blob(Vector3(0, y + 0.03, 0.05), Vector3(0.18, 0.08, 0.32), bp, {"lat": 6, "lon": 10})
	# Gill slits underneath, five each side.
	for side in [-1.0, 1.0]:
		for k in range(5): bs.blob(Vector3(0.12 * side, y - 0.105, -0.12 + k * 0.05), Vector3(0.05, 0.006, 0.006), dark, {"lat": 3, "lon": 6})
	# The wide mouth at the front.
	bs.blob(Vector3(0, y - 0.02, -0.41), Vector3(0.16, 0.025, 0.03), dark, {"lat": 4, "lon": 10})
	# A small dorsal fin and the long whip tail with a glass barb at its root.
	bs.crystal(Vector3(0, y + 0.08, 0.32), Vector3(0, 0.6, 1.0), 0.14, 0.04, bp, 3)
	var whip: Array = []; var wr: Array = []
	for k in range(9):
		var t := k / 8.0
		whip.append(Vector3(0.08 * sin(t * 3.0), y - 0.02 - 0.06 * t, 0.38 + 1.5 * t)); wr.append(lerpf(0.035, 0.004, t))
	bs.tube(whip, wr, bp, {"sides": 6, "per": 2, "cap1": false})
	bs.crystal(Vector3(0, y + 0.0, 0.55), Vector3(0, 0.35, 1.0), 0.26, 0.022, barb, 3)
	part(root, "Body", bs)
	var head := joint(root, "Head", Vector3(0, y, -0.32))
	var hs := Sculpt.new(); var hp := hs.add_painter(manta_top)
	var hg := hs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#262a36").lerp(Color("#d8f0ff"), v * v))
	# The horn-fins (cephalic fins), curled forward either side of the mouth, tipped with glass.
	for side in [-1.0, 1.0]:
		var c0 := Vector3(0.2 * side, y, -0.38)
		hs.tube([c0, c0 + Vector3(0.03 * side, 0.02, -0.12), c0 + Vector3(0.0, 0.06, -0.22), c0 + Vector3(-0.04 * side, 0.03, -0.28)], [0.045, 0.04, 0.03, 0.008], hp, {"sides": 8, "per": 3, "flat": 0.45, "side": Vector3(1, 0, 0), "twist": 0.6 * side})
		hs.crystal(c0 + Vector3(-0.04 * side, 0.03, -0.28), Vector3(-0.3 * side, -0.2, -1.0), 0.1, 0.014, hg, 4)
	part(head, "HornFins", hs)
	var core := glowing_eyes(head, [Vector3(-0.29, y + 0.01, -0.3), Vector3(0.29, y + 0.01, -0.3)], 0.024, Color("#8ae8ff"))
	# The wings: broad triangles from the whole length of the body's sides, thick dark flesh at
	# the root thinning out into glass blades towards the tips.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var root_at := Vector3(0.24 * side, y, -0.05)
		var node := joint(root, "%sWing0" % ["Left" if side < 0 else "Right"], root_at)
		var ws := Sculpt.new()
		var wp := ws.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var flesh := manta_top(p, Vector3(0, 1, 0) if n.y >= 0.0 else Vector3(0, -1, 0), v, w)
			var glassc := Color("#bfe8ff").lerp(Color.from_hsv(fposmod(v * 1.4 + w * 0.5, 1.0), 0.5, 1.0), 0.35 + 0.3 * smoothstep(0.6, 1.0, w))
			var k := smoothstep(0.0, 0.3, v)
			var c := flesh.lerp(glassc, k)
			return Color(c.r, c.g, c.b, lerpf(0.95, 0.45 + 0.4 * smoothstep(0.85, 1.0, v), k)))
		var front := Vector3(0.2 * side, y + 0.01, -0.36)
		var rear := Vector3(0.18 * side, y - 0.01, 0.34)
		var tipw := Vector3(1.3 * side, y + 0.12, 0.3)
		var lead := [front, Vector3(0.75 * side, y + 0.06, -0.12), tipw]
		var trail := [rear, Vector3(0.7 * side, y + 0.05, 0.36), tipw]
		var cut := 0.42
		var lead_in: Array = []; var trail_in: Array = []; var lead_out: Array = []; var trail_out: Array = []
		for k in range(5):
			var t := k / 4.0
			lead_in.append(along_line(lead, t * cut)); trail_in.append(along_line(trail, t * cut))
			lead_out.append(along_line(lead, lerpf(cut, 1.0, t))); trail_out.append(along_line(trail, lerpf(cut, 1.0, t)))
		var fl := Sculpt.new(); var flp := fl.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return manta_top(p, Vector3(0, signf(n.y + 0.001), 0), v, w))
		skin(fl, flp, lead_in, trail_in, Vector3(0, -0.02, 0), 6, 8)
		part(node, "WingFlesh", fl, obsidian)
		skin(ws, wp, lead_out, trail_out, Vector3(0, -0.03, 0), 10, 8)
		# The fleshy root of the wing, blending into the body.
		var rs := Sculpt.new(); var rp := rs.add_painter(manta_top)
		rs.tube([Vector3(0.18 * side, y, -0.06), Vector3(0.45 * side, y + 0.03, 0.02), Vector3(0.7 * side, y + 0.05, 0.1)], [0.1, 0.06, 0.02], rp, {"sides": 10, "per": 3, "flat": 0.3, "side": Vector3.UP, "cap1": false})
		part(node, "WingRoot", rs, obsidian)
		part(node, "Wing", ws, glass)
		wings.append(node)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": [], "knees": [], "leaves": wings}, 1.4)
	return _with_visual(node, head, [], [], wings)


# ------------------------------------------------------------------ C: falcon

static func peregrine(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#1c222c").lerp(Color("#4a5464"), clampf(n.y * 0.4 + 0.3 + Sculpt.fbm(p * 10.0) * 0.4, 0.0, 1.0))
	# Pale chest and belly, finely barred with dark.
	var chest := Color("#e6dccc").darkened(smoothstep(0.6, 0.9, sin(p.y * 90.0 + Sculpt.noise(p * 8.0) * 2.0)) * 0.6)
	return c.lerp(chest, smoothstep(-0.1, -0.55, n.y) * smoothstep(0.35, 0.0, p.z))


## One flight feather of glass: a narrow blade with a dark shaft down it.
func feather(s: Sculpt, painter: int, root_at: Vector3, side: float, a: float, length: float, width: float, lift: float) -> void:
	blade(s, painter, root_at, side, a, length, func (t: float) -> Array: return [-width * 0.5, width * (0.6 + 0.4 * sin(PI * minf(t * 1.4, 1.0))) * sqrt(maxf(0.0, 1.0 - pow(t, 4.0)))], lift, 9, 3)


func _falcon() -> Node3D:
	var y := 1.3
	var bs := Sculpt.new(); var bp := bs.add_painter(peregrine)
	bs.blob(Vector3(0, y, 0), Vector3(0.15, 0.16, 0.3), bp, {"lat": 10, "lon": 14, "lump": 0.04})
	bs.blob(Vector3(0, y + 0.04, -0.2), Vector3(0.12, 0.13, 0.14), bp, {"lat": 7, "lon": 10})
	part(root, "Body", bs)
	var head := joint(root, "Head", Vector3(0, y + 0.14, -0.32))
	var hs := Sculpt.new(); var hp := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := peregrine(p, n, v, w)
		# The black hood and the "moustache" stripe below the eye, on a white cheek.
		var cheek := smoothstep(0.4, 0.8, absf(n.x)) * smoothstep(-0.05, 0.25, -(p.y - (y + 0.13)))
		c = c.lerp(Color("#f0ece4"), cheek * 0.9)
		c = c.lerp(Color("#0c0e12"), smoothstep(0.02, 0.0, absf(p.z + 0.39 - (p.y - (y + 0.12)) * 0.4) - 0.015) * smoothstep(0.3, 0.6, absf(n.x)))
		return c.lerp(Color("#121418"), smoothstep(0.2, 0.6, n.y)))
	var cere := hs.add_painter(func (_p, _n, _v, _w): return Color("#e8b830"))
	var beak := hs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#5a6478").lerp(Color("#101216"), v))
	hs.blob(Vector3(0, y + 0.15, -0.36), Vector3(0.1, 0.1, 0.11), hp, {"lat": 8, "lon": 12})
	hs.blob(Vector3(0, y + 0.15, -0.46), Vector3(0.035, 0.03, 0.025), cere, {"lat": 4, "lon": 7})
	hs.tube([Vector3(0, y + 0.15, -0.47), Vector3(0, y + 0.14, -0.53), Vector3(0, y + 0.1, -0.56), Vector3(0, y + 0.07, -0.54)], [0.03, 0.022, 0.012, 0.002], beak, {"sides": 8, "per": 3, "flat": 0.7, "cap1": false})
	for side in [-1.0, 1.0]: hs.blob(Vector3(0.07 * side, y + 0.18, -0.43), Vector3(0.016, 0.026, 0.026), cere, {"lat": 4, "lon": 7})
	part(head, "Head", hs)
	var core := glowing_eyes(head, [Vector3(-0.078, y + 0.18, -0.44), Vector3(0.078, y + 0.18, -0.44)], 0.022, Color("#c8501a"))
	var jaw := joint(head, "Jaw", Vector3(0, y + 0.11, -0.45))
	var js := Sculpt.new(); var jb := js.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#5a6478").lerp(Color("#101216"), v))
	js.tube([Vector3(0, y + 0.11, -0.45), Vector3(0, y + 0.1, -0.5)], [0.02, 0.006], jb, {"sides": 6, "per": 2, "flat": 0.8})
	part(jaw, "Jaw", js)
	# The wings: dark covert feathers along the arm; long glass primaries fanning from the wrist
	# and shorter glass secondaries along the trailing edge.
	var glass_f := func (p: Vector3, _n: Vector3, v: float, w: float) -> Color:
		var c := Color("#bfe0ff").lerp(Color.from_hsv(fposmod(v + p.x * 0.6, 1.0), 0.5, 1.0), 0.3 + 0.3 * smoothstep(0.85, 1.0, v))
		var shaft := smoothstep(0.12, 0.0, absf(w - 0.35))
		c = c.lerp(Color("#141820"), shaft * 0.8)
		return Color(c.r, c.g, c.b, clampf(0.38 + 0.5 * shaft + 0.3 * smoothstep(0.85, 1.0, v), 0.0, 0.95))
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.12 * side, y + 0.08, -0.12)
		var node := joint(root, "%sWing0" % ["Left" if side < 0 else "Right"], sh)
		var cs := Sculpt.new(); var cp := cs.add_painter(peregrine)
		blade(cs, cp, sh, side, -0.05, 0.62, func (t: float) -> Array: return [0.0, 0.3 * (1.0 - 0.45 * t)], 0.05)
		cs.tube([sh, sh + Vector3(0.3 * side, 0.03, -0.01), sh + Vector3(0.6 * side, 0.05, 0.0)], [0.05, 0.04, 0.03], cp, {"sides": 8, "per": 2})
		part(node, "Coverts", cs, obsidian)
		var fs := Sculpt.new(); var fp := fs.add_painter(glass_f)
		var wrist := sh + Vector3(0.6 * side, 0.05, 0.02)
		for k in range(8):
			var a := lerpf(-0.12, 0.75, k / 7.0)
			feather(fs, fp, wrist + Vector3(0, -0.004 * k, 0.03 * k), side, a, lerpf(0.78, 0.5, k / 7.0), 0.09, 0.03)
		for k in range(8):
			var at := sh.lerp(wrist, k / 8.0) + Vector3(0, -0.01, 0.2)
			feather(fs, fp, at, side, 1.25 + 0.04 * k, 0.32, 0.08, 0.0)
		part(node, "Wing", fs, glass)
		wings.append(node)
	# The tail: a fan of glass feathers.
	var ts := Sculpt.new(); var tp := ts.add_painter(glass_f)
	for k in range(8):
		var a := lerpf(1.35, 1.79, k / 7.0)
		feather(ts, tp, Vector3(0, y - 0.02 + 0.002 * k, 0.26), 1.0, a, 0.55, 0.08, 0.0)
	part(root, "Tail", ts, glass)
	# Yellow legs and black talons, drawn up under the body.
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var hip_at := Vector3(0.07 * side, y - 0.12, 0.06)
		var hip := joint(root, "Leg%s" % ("L" if side < 0 else "R"), hip_at)
		var knee_at := hip_at + Vector3(0.0, -0.12, 0.04)
		var foot := knee_at + Vector3(0.0, -0.14, -0.06)
		var ls := Sculpt.new(); var lp := ls.add_painter(peregrine)
		ls.tube([hip_at, knee_at], [0.05, 0.04], lp, {"sides": 8, "per": 2})
		part(hip, "Thigh", ls, obsidian)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var yp := ss.add_painter(func (_p, _n, _v, _w): return Color("#e8b830"))
		var tal := ss.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#2a2420").lerp(Color("#0a0a0c"), v))
		ss.tube([knee_at, foot], [0.022, 0.018], yp, {"sides": 7, "per": 2})
		for k in range(4):
			var cd := Vector3((k - 1.5) * 0.4, -0.2, -1.0 if k < 3 else 1.0).normalized()
			var t0 := foot + cd * 0.05
			ss.tube([foot, t0], [0.014, 0.012], yp, {"sides": 5, "per": 1})
			ss.tube([t0, t0 + cd * 0.03 + Vector3(0, -0.01, 0), t0 + cd * 0.04 + Vector3(0, -0.04, 0)], [0.012, 0.008, 0.002], tal, {"sides": 5, "per": 2, "cap1": false})
		part(knee, "Foot", ss, obsidian)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": wings}, 1.45)
	return _with_visual(node, head, hips, knees, wings, jaw)
