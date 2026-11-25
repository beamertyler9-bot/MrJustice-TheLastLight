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
	obsidian.metallic = 0.2; obsidian.roughness = 0.3


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

func _wyvern() -> Node3D:
	var y := 1.3
	var bs := Sculpt.new(); var bp := bs.add_painter(obsidian_skin)
	var gl := bs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#5a4a8a").lerp(Color("#e8f4ff"), v))
	# Torso with a deep keeled breastbone for the flight muscles, a long neck.
	bs.blob(Vector3(0, y, 0), Vector3(0.2, 0.19, 0.36), bp, {"lat": 10, "lon": 14, "lump": 0.05})
	bs.blob(Vector3(0, y - 0.09, -0.14), Vector3(0.14, 0.15, 0.2), bp, {"lat": 7, "lon": 10})
	bs.tube([Vector3(0, y + 0.04, -0.24), Vector3(0, y + 0.16, -0.42), Vector3(0, y + 0.34, -0.5)], [0.12, 0.1, 0.085], bp, {"sides": 12, "per": 3, "bands": 6, "band": 0.05})
	# Crystal spines down the back.
	for k in range(7): bs.crystal(Vector3(0, y + 0.13 - k * 0.01, -0.18 + k * 0.08), Vector3(0, 1, 0.7), 0.1 - k * 0.008, 0.02, gl, 4)
	# The long tail ending in a diamond-shaped vane of glass, as on Rhamphorhynchus.
	var tail := [Vector3(0, y - 0.01, 0.26), Vector3(0, y - 0.04, 0.6), Vector3(0.04, y - 0.08, 0.95), Vector3(0.02, y - 0.1, 1.25)]
	bs.tube(tail, [0.1, 0.055, 0.03, 0.014], bp, {"sides": 10, "per": 3})
	part(root, "Body", bs)
	var vs := Sculpt.new(); var vg := vs.add_painter(clear_glass(Color("#b8a8f0"), Color("#3a2a5a")))
	var tip: Vector3 = tail[3]
	skin(vs, vg, [tip, tip + Vector3(0.12, 0.0, 0.12), tip + Vector3(0.0, 0.0, 0.3)], [tip, tip + Vector3(-0.12, 0.0, 0.12), tip + Vector3(0.0, 0.0, 0.3)], Vector3.ZERO, 4, 4)
	part(root, "TailVane", vs, glass)
	# The head: a long narrow beak lined with crystal teeth, a swept-back crest of glass.
	var head := joint(root, "Head", Vector3(0, y + 0.37, -0.52))
	var hs := Sculpt.new(); var hp := hs.add_painter(obsidian_skin)
	var tooth := hs.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#8a7ab8").lerp(Color("#f4faff"), v))
	hs.tube([Vector3(0, y + 0.4, -0.46), Vector3(0, y + 0.43, -0.6), Vector3(0, y + 0.4, -0.8), Vector3(0, y + 0.36, -1.02)], [0.1, 0.09, 0.05, 0.012], hp, {"sides": 12, "per": 3, "flat": 0.9, "cap_len": 0.4})
	for side in [-1.0, 1.0]:
		for k in range(6): hs.crystal(Vector3(0.026 * side, y + 0.36, -0.66 - k * 0.055), Vector3(0.2 * side, -1, -0.3), 0.04 - k * 0.003, 0.007, tooth, 4)
		hs.blob(Vector3(0.055 * side, y + 0.45, -0.6), Vector3(0.03, 0.012, 0.045), hp, {"lat": 4, "lon": 6})
	# Draconic brows and swept-back horns of black glass.
	var hn := Sculpt.new(); var hnp := hn.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#140c1c").lerp(Color("#c8b8f0"), v))
	for side in [-1.0, 1.0]:
		hn.tube([Vector3(0.06 * side, y + 0.47, -0.66), Vector3(0.075 * side, y + 0.48, -0.58), Vector3(0.07 * side, y + 0.47, -0.52)], [0.018, 0.026, 0.016], hp, {"sides": 7, "per": 2})
		var h0 := Vector3(0.07 * side, y + 0.46, -0.5)
		var hpts: Array = [h0]; var d := Vector3(0.35 * side, 0.35, 1.0).normalized()
		for k in range(1, 6):
			d = d.rotated(Vector3.RIGHT, 0.12); hpts.append((hpts[k - 1] as Vector3) + d * 0.07)
		hn.tube(hpts, [0.03, 0.026, 0.02, 0.014, 0.008, 0.002], hnp, {"sides": 7, "per": 2, "bands": 4, "band": 0.1, "cap1": false})
	part(head, "Horns", hn)
	var cs := Sculpt.new(); var cg := cs.add_painter(clear_glass(Color("#b8a8f0"), Color("#3a2a5a")))
	skin(cs, cg, [Vector3(0, y + 0.47, -0.62), Vector3(0, y + 0.56, -0.42), Vector3(0, y + 0.7, -0.14)], [Vector3(0, y + 0.43, -0.55), Vector3(0, y + 0.45, -0.42), Vector3(0, y + 0.7, -0.14)], Vector3.ZERO, 5, 4)
	part(head, "Crest", cs, glass)
	var core := glowing_eyes(head, [Vector3(-0.06, y + 0.44, -0.6), Vector3(0.06, y + 0.44, -0.6)], 0.022, Color("#c8a0ff"))
	var jaw := joint(head, "Jaw", Vector3(0, y + 0.36, -0.5))
	var js := Sculpt.new(); var jp := js.add_painter(obsidian_skin)
	var jt := js.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#8a7ab8").lerp(Color("#f4faff"), v))
	js.tube([Vector3(0, y + 0.35, -0.5), Vector3(0, y + 0.34, -0.75), Vector3(0, y + 0.35, -0.98)], [0.05, 0.03, 0.008], jp, {"sides": 8, "per": 3, "flat": 0.8})
	for side in [-1.0, 1.0]:
		for k in range(5): js.crystal(Vector3(0.02 * side, y + 0.36, -0.68 - k * 0.055), Vector3(0.2 * side, 1, -0.3), 0.032, 0.006, jt, 4)
	part(jaw, "Jaw", js).rotation.x = -0.25
	# The wings: arm out to the wrist, three small clawed fingers, then one immense fourth
	# finger carrying the leading edge out to the tip; glass skin from it back to the ankle,
	# with dark fibres fanning through it.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.13 * side, y + 0.08, -0.12)
		var node := joint(root, "%sWing0" % ["Left" if side < 0 else "Right"], sh)
		var e := sh + Vector3(0.3 * side, 0.06, 0.04)
		var w := e + Vector3(0.32 * side, 0.02, -0.08)
		var f1 := w + Vector3(0.3 * side, -0.01, 0.06)
		var f2 := f1 + Vector3(0.3 * side, -0.03, 0.14)
		var tipw := f2 + Vector3(0.22 * side, -0.04, 0.2)
		var ankle := Vector3(0.14 * side, y - 0.18, 0.26)
		var ws := Sculpt.new(); var wb := ws.add_painter(obsidian_skin)
		var claw := ws.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#1a1420").lerp(Color("#d8ccf0"), v))
		ws.tube([sh, e], [0.07, 0.055], wb, {"sides": 8, "per": 2})
		ws.blob(e, Vector3.ONE * 0.042, wb, {"lat": 4, "lon": 6})
		ws.tube([e, w], [0.05, 0.04], wb, {"sides": 8, "per": 2})
		ws.blob(w, Vector3.ONE * 0.04, wb, {"lat": 4, "lon": 6})
		ws.tube([w, f1, f2, tipw], [0.04, 0.03, 0.018, 0.003], wb, {"sides": 7, "per": 2, "cap1": false})
		for k in range(3):
			var c0 := w + Vector3(0.02 * side, 0.02, -0.03)
			var cd := Vector3((0.3 + k * 0.25) * side, 0.1, -1.0).normalized()
			ws.tube([c0, c0 + cd * 0.06, c0 + cd * 0.1 + Vector3(0, -0.03, 0)], [0.012, 0.008, 0.002], claw, {"sides": 5, "per": 2, "cap1": false})
		# A small forward skin (propatagium) from shoulder to wrist.
		var fs := Sculpt.new(); var fg := fs.add_painter(clear_glass(Color("#b8a8f0"), Color("#3a2a5a")))
		skin(fs, fg, [sh, e.lerp(w, 0.5), w], [sh, sh.lerp(w, 0.5) + Vector3(0, 0, -0.06), w], Vector3.ZERO, 4, 3)
		var gs := Sculpt.new()
		var gp := gs.add_painter(func (p: Vector3, _n: Vector3, v: float, u: float) -> Color:
			var c := Color("#c8b8ff").lerp(Color.from_hsv(fposmod(v * 1.2 + u * 0.4, 1.0), 0.5, 1.0), 0.3 + 0.3 * smoothstep(0.6, 1.0, u))
			# The fibres: fine dark lines fanning out from the arm to the trailing edge.
			var fib := smoothstep(0.08, 0.0, absf(fposmod(v * 14.0 + u * 3.0, 1.0) - 0.5) - 0.38)
			c = c.lerp(Color("#1a1028"), fib * 0.7 * smoothstep(0.05, 0.3, u))
			var a := 0.5 + 0.3 * smoothstep(0.75, 1.0, u) + 0.4 * fib * smoothstep(0.05, 0.3, u)
			return Color(c.r, c.g, c.b, clampf(a, 0.0, 0.95)))
		skin(gs, gp, [sh, e, w, f1, f2, tipw], [sh + Vector3(0, -0.03, 0.12), ankle.lerp(sh, 0.6), ankle, ankle, ankle + Vector3(0.1 * side, 0, 0.05), tipw], Vector3(0, -0.03, 0.06), 16, 9)
		part(node, "WingBones", ws, obsidian)
		part(node, "WingFore", fs, glass)
		part(node, "Wing", gs, glass)
		wings.append(node)
	# Hind legs hanging below, with hooked claws.
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var hip_at := Vector3(0.1 * side, y - 0.08, 0.18)
		var hip := joint(root, "Hindleg%s" % ("L" if side < 0 else "R"), hip_at)
		var knee_at := hip_at + Vector3(0.05 * side, -0.14, 0.12)
		var foot := knee_at + Vector3(0.0, -0.1, 0.24)
		var ts := Sculpt.new(); var tp := ts.add_painter(obsidian_skin)
		ts.tube([hip_at, knee_at], [0.07, 0.05], tp, {"sides": 8, "per": 2})
		part(hip, "Thigh", ts, obsidian)
		var knee := joint(hip, "Knee", knee_at)
		var ss := Sculpt.new(); var sp := ss.add_painter(obsidian_skin); var cp := ss.add_painter(func (_p, _n, v: float, _w) -> Color: return Color("#1a1420").lerp(Color("#d8ccf0"), v))
		ss.tube([knee_at, foot], [0.045, 0.03], sp, {"sides": 7, "per": 2})
		for k in range(4):
			var cd := Vector3((k - 1.5) * 0.25, -0.6, 0.8).normalized()
			ss.tube([foot, foot + cd * 0.07, foot + cd * 0.11 + Vector3(0, -0.04, 0)], [0.012, 0.008, 0.002], cp, {"sides": 5, "per": 2, "cap1": false})
		part(knee, "Shin", ss, obsidian)
		hips.append(hip); knees.append(knee)
	var node := _finish({"head": head, "core": core, "arms": [], "forearms": [], "feet": hips, "knees": knees, "leaves": wings}, 1.4)
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
