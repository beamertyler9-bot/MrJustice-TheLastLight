extends "res://tools/sculpt_windwhistle_stalker.gd"
## The Prismstalker of Prismere, sculpted by hand: a low cat whose body bends the light like
## cut glass, so you see it only as a shimmer; a steady glint along its edge gives it away
## before it pounces. Three designs, each built on a real cat:
##   snow     - the snow leopard of the high mountains: pale smoky grey, a deep chest, short
##              forelegs, a small head and a tail nearly as long as its body and very thick;
##              its rosettes here are rings of split rainbow light, like the colour fringes a
##              prism throws
##   clouded  - the clouded leopard: long and low, with the longest canines for its size of
##              any living cat and big "cloud" blotches each edged in black; here each cloud is
##              a pane of coloured glass set in dark lead, like a church window
##   glass    - a cat of clear glass, near-invisible, a cheetah's lean frame (small round head,
##              long legs, black "tear lines" from the eyes) that shows only by the rainbow
##              light it bends at its edges and a bright line of light down its back

var kindp := "snow"
var glint_mat: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = null
	material.roughness = 0.12; material.metallic_specular = 1.0
	material.rim_enabled = true; material.rim = 0.7; material.rim_tint = 0.2
	material.vertex_color_is_srgb = true
	glint_mat = StandardMaterial3D.new()
	glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glint_mat.albedo_color = Color("#ffffff")


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Prismstalker"
	kindp = variant
	dense = 2
	match variant:
		"snow":
			_eyes(Color("#bfefff"))
			return _stalker(snow_coat, 1.35)
		"clouded":
			_eyes(Color("#ffd27a"))
			saber = 0.13
			return _stalker(clouded_coat, 1.4)
		"glass":
			_eyes(Color("#e8f8ff"))
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			material.cull_mode = BaseMaterial3D.CULL_BACK
			material.rim = 1.0
			return _stalker(glass_coat, 1.35)
	return null


# ------------------------------------------------------------------ painters

static func rainbow(t: float) -> Color:
	return Color.from_hsv(fposmod(t, 1.0), 0.65, 1.0)


## Smoky snow-leopard grey, pale beneath, with rosettes that are rings of split rainbow light.
static func snow_coat(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#9aa4b4").lerp(Color("#eef2f6"), clampf(-n.y * 0.7 + 0.25 + Sculpt.fbm(p * 6.0) * 0.2, 0.0, 1.0))
	var r := Sculpt.noise(Vector3(p.x * 13.0, p.y * 13.0, p.z * 9.0))
	var top := smoothstep(-0.7, 0.1, n.y)
	# Each rosette: a dark smoky ring with split rainbow light caught inside it.
	var inner := smoothstep(0.22, 0.3, r) * smoothstep(0.42, 0.36, r)
	var ring := smoothstep(0.36, 0.42, r) * smoothstep(0.56, 0.48, r)
	c = c.lerp(rainbow(p.x * 2.0 + p.z * 1.3 + p.y * 3.0 + r * 2.0), inner * top * 0.9)
	return c.lerp(Color("#2a3040"), ring * top * 0.85)


## Slate blue-grey, the clouds panes of jewel-coloured glass set in black lead.
static func clouded_coat(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#7a8498").lerp(Color("#d8dce6"), clampf(-n.y * 0.6 + 0.3 + Sculpt.fbm(p * 6.0) * 0.2, 0.0, 1.0))
	var q := Vector3(p.x * 5.0, p.y * 5.0, p.z * 3.5)
	var cl := Sculpt.noise(q) + Sculpt.noise(q * 2.3) * 0.3
	var top := smoothstep(-0.7, 0.0, n.y)
	if cl > 0.12:
		# One jewel colour per cloud, drifting slowly across it like light through old glass.
		# Each cloud is cut into panes of jewel glass, the cuts leaded in black.
		var h := fposmod(Sculpt.noise(q * 0.6) * 4.0 + 2.0, 1.0) * 6.0
		var panes: Array = [Color("#2f7ae0"), Color("#9a3ee0"), Color("#e0407e"), Color("#e8b030"), Color("#2fbf9a"), Color("#4a5ae8")]
		var pane: Color = panes[int(h) % 6]
		var cut := smoothstep(0.12, 0.0, minf(fposmod(h, 1.0), 1.0 - fposmod(h, 1.0)))
		c = c.lerp(pane, top * 0.9 * smoothstep(0.12, 0.2, cl)).lerp(Color("#101016"), cut * top)
	return c.lerp(Color("#101016"), smoothstep(0.08, 0.02, absf(cl - 0.12)) * top)


## Clear glass: barely there, the colours of the rainbow showing where the surface turns away.
static func glass_coat(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#e8f4ff").lerp(rainbow(n.x * 0.8 + n.z * 0.5 + p.y * 2.0), 0.35)
	var a := 0.32 + 0.25 * (1.0 - absf(n.z)) + 0.1 * Sculpt.noise(p * 10.0)
	# The cheetah's tear lines from the inner eye down to the mouth.
	for side: float in [-1.0, 1.0]:
		if p.z < -0.93 and absf(p.x - 0.05 * side) < 0.012 and p.y < 1.03 and p.y > 0.94: return Color(0.05, 0.05, 0.08, 0.95)
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))


# ------------------------------------------------------------------ the cat

func _stalker(skin: Callable, scale: float) -> Node3D:
	if kindp == "glass": rump_drop = -0.02
	if kindp == "snow": rump_drop = 0.04
	var parts := _cat(skin)
	var hs: Sculpt = parts.head_sculpt
	# The glint: a bright line of light along the ridge of the back, from the nape to the tail,
	# that holds still as it gathers to pounce.
	var gl := Sculpt.new(); var gp := gl.add_painter(func (p, n, v, w): return Color.WHITE)
	var spine: Array = []; var rr: Array = []
	for k in range(13):
		var t := k / 12.0
		var z := lerpf(-0.66, 0.66, t)
		var y := 1.0 if z < -0.42 else (lerpf(1.18, 1.1, (z + 0.42) / 0.5) if z < 0.08 else lerpf(1.06, 1.03, (z - 0.08) / 0.58))
		spine.append(Vector3(0, y - rump_drop * smoothstep(0.1, 0.6, z) + 0.005, z)); rr.append(0.008)
	gl.tube(spine, rr, gp, {"sides": 4, "per": 2})
	part(root, "EdgeGlint", gl, glint_mat)
	match kindp:
		"snow":
			# The snow leopard's very thick, very long tail, and crystal frost along the spine.
			var ts: Sculpt = parts.tail_sculpts[1]; var tp := ts.add_painter(snow_coat)
			ts.tube([Vector3(0, 0.48, 1.22), Vector3(0, 0.42, 1.42), Vector3(0, 0.45, 1.6), Vector3(0, 0.55, 1.72)], [0.07, 0.068, 0.066, 0.06], tp, {"sides": 12, "per": 3, "cap0": false})
			var ts0: Sculpt = parts.tail_sculpts[0]
			ts0.tube([Vector3(0, 0.84, 0.64), Vector3(0, 0.76, 0.9), Vector3(0, 0.6, 1.08), Vector3(0, 0.48, 1.24)], [0.07, 0.072, 0.07, 0.07], ts0.add_painter(snow_coat), {"sides": 12, "per": 3, "cap1": false})
			var fr := Sculpt.new(); var fp := fr.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#e8f6ff").lerp(rainbow(p.z * 3.0), 0.25))
			for k in range(9):
				var z := lerpf(-0.5, 0.45, k / 8.0)
				for side: float in [-1.0, 1.0]:
					fr.crystal(Vector3(0.05 * side, 1.12 - absf(z) * 0.08, z), Vector3(side * 0.6, 1.0, 0.3), 0.08 + 0.03 * (k % 2), 0.018, fp, 6)
			part(root, "Frost", fr)
		"clouded":
			pass
		"glass":
			# Prism shards standing at the shoulders and hips, splitting the light.
			var fr := Sculpt.new(); var fp := fr.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: var c := rainbow(p.y * 4.0 + p.z * 2.0); return Color(c.r, c.g, c.b, 0.6))
			for at: Vector3 in [Vector3(0.12, 1.08, -0.32), Vector3(-0.12, 1.08, -0.32), Vector3(0.1, 1.0, 0.45), Vector3(-0.1, 1.0, 0.45)]:
				for k in range(3): fr.crystal(at, Vector3(signf(at.x) * (0.4 + k * 0.2), 1.0, 0.4 - k * 0.3), 0.14 - k * 0.03, 0.022, fp, 3)
			part(root, "Prisms", fr, material)
	return _close(parts, scale)
