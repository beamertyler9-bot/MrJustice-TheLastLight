extends "res://tools/creature_kit.gd"
## The Root Reaper of Hollowmourn, sculpted by hand: a tall, lanky, faceless thing grown out of
## the roots of the graveyard trees, with long wooden fingers that drag along the ground. It
## creaks and uncurls before it stalks forward. Three designs, each grown from a real plant:
##   strangler - a strangler fig: its body is a cage of roots that once wrapped a host tree and
##               grew together where they touched, the tree inside long since rotted away to
##               leave a hollow, faint grave-light glowing in the gaps
##   mandrake  - the mandrake of folklore, the root that grows in the shape of a man: a pale,
##               wrinkled, forked root body, a tuft of leaves on its head, root hairs all over it,
##               and only dark holes where a face should be
##   bogoak    - black bog oak (oak preserved for centuries in peat bogs), hung with grey
##               Spanish moss, bracket fungi growing from its shoulders, a split where its face
##               should be glowing with pale foxfire (the glowing fungus of rotting wood)

const GRAVE_LIGHT := Color("#c6f2dc")

var kind := "strangler"


func _init() -> void:
	super()
	glow.albedo_color = Color("#6fd0a0"); glow.emission = Color("#5ad89a"); glow.emission_energy_multiplier = 0.9


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "RootReaper"
	kind = variant
	match variant:
		"strangler": return _figure(fig_bark(), 6, 0.06)
		"mandrake": return _figure(mandrake_skin(), 1, 0.0)
		"bogoak": return _figure(bog_oak(), 4, 0.04)
	return null


# ------------------------------------------------------------------ painters

## Strangler fig bark: smooth pale grey, mottled, darker where the roots fuse together.
func fig_bark() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#6e675e").lerp(Color("#a49a8a"), clampf(n.y * 0.25 + 0.45 + Sculpt.fbm(p * 6.0) * 0.4, 0.0, 1.0))
		c = c.darkened(clampf(-w, 0.0, 1.0) * 0.45)
		return c.lerp(Color("#3e4a34"), smoothstep(0.3, 0.6, Sculpt.fbm(p * 3.0 + Vector3(4, 1, 2))) * smoothstep(0.0, 0.6, n.y) * 0.5)


## Mandrake root: pale, dirty yellowish-tan, wrinkled in rings, with earth caked in the creases.
func mandrake_skin() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#8a7a5a").lerp(Color("#c2b08a"), clampf(n.y * 0.3 + 0.4 + Sculpt.fbm(p * 7.0) * 0.3, 0.0, 1.0))
		c = c.darkened(smoothstep(0.75, 0.95, absf(sin(p.y * 70.0 + Sculpt.noise(p * 6.0) * 3.0))) * 0.35)
		return c.lerp(Color("#3a2c1e"), smoothstep(0.25, 0.65, Sculpt.fbm(p * 4.0 + Vector3(7, 3, 1))) * 0.6).darkened(clampf(-w, 0.0, 1.0) * 0.3)


## Bog oak: near-black wood, deeply grained, with a faint purplish sheen.
func bog_oak() -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#171313").lerp(Color("#3e3534"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(p * 5.0) * 0.4, 0.0, 1.0))
		c = c.lightened(smoothstep(0.85, 1.0, sin(p.y * 55.0 + Sculpt.fbm(p * 3.0) * 8.0)) * 0.12)
		return c.darkened(clampf(-w, 0.0, 1.0) * 0.4)


static func spanish_moss(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return Color("#7d8577").lerp(Color("#b2b8a8"), clampf(n.y * 0.3 + 0.4 + Sculpt.noise(p * 20.0) * 0.3, 0.0, 1.0)).darkened(v * 0.25)


# ------------------------------------------------------------------ shared pieces

## A limb or trunk from `a` to `b` built of `strands` roots twisting round each other (or one
## gnarled root when strands is 1).
func root_bundle(s: Sculpt, painter: int, a: Vector3, b: Vector3, ra: float, rb: float, strands: int, twist: float, bend := Vector3.ZERO) -> void:
	var d := (b - a); var dir := d.normalized()
	var u := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized(); var v := dir.cross(u)
	if strands <= 1:
		s.tube([a, a.lerp(b, 0.35) + bend * 0.6, a.lerp(b, 0.7) + bend * 0.6, b], [ra, lerpf(ra, rb, 0.4) * 1.05, lerpf(ra, rb, 0.75), rb], painter, {"sides": 11, "per": 3, "lump": 0.14, "ridges": 5, "ridge": 0.05})
		return
	for k in range(strands):
		var pts: Array = []; var rr: Array = []
		for j in range(7):
			var t := j / 6.0
			var ang := TAU * k / strands + t * twist
			var r := lerpf(ra, rb, t) * 0.55
			var off := (u * cos(ang) + v * sin(ang)) * r
			pts.append(a + d * t + off + bend * sin(t * PI)); rr.append(lerpf(ra, rb, t) * 0.55)
		s.tube(pts, rr, painter, {"sides": 7, "per": 2, "lump": 0.12})


## Long knobbly wooden fingers from the wrist along `fwd`, curling at the tips, dragging low.
func wood_fingers(s: Sculpt, painter: int, wrist: Vector3, fwd: Vector3, side: float, length: float, count := 4) -> void:
	var f := fwd.normalized(); var right := f.cross(Vector3.UP).normalized(); var up := right.cross(f)
	s.blob(wrist + f * 0.04, Vector3(0.05, 0.035, 0.06), painter, {"lat": 5, "lon": 8, "lump": 0.2, "basis": Basis(right, up, -f)})
	for i in range(count):
		var spread := (i - (count - 1) * 0.5) * 0.28
		var d := (f + right * spread * side * 0.8).normalized()
		var L := length * (0.8 + 0.25 * (1.0 - absf(spread)))
		var k1 := wrist + f * 0.05 + d * L * 0.35 - up * 0.01
		var k2 := k1 + d * L * 0.35 - up * L * 0.08
		var tip := k2 + d * L * 0.25 - up * L * 0.2
		s.tube([wrist + f * 0.05, k1, k2, tip], [0.017, 0.015, 0.011, 0.002], painter, {"sides": 6, "per": 2, "lump": 0.2, "cap1": false})
		s.blob(k1, Vector3.ONE * 0.019, painter, {"lat": 4, "lon": 6, "lump": 0.3})
		s.blob(k2, Vector3.ONE * 0.015, painter, {"lat": 4, "lon": 6, "lump": 0.3})
	# A thumb curling across.
	var t0 := wrist + f * 0.03 - right * 0.04 * side
	s.tube([t0, t0 + f * 0.1 - right * 0.04 * side, t0 + f * 0.17 - up * 0.06], [0.016, 0.012, 0.002], painter, {"sides": 6, "per": 2, "lump": 0.2, "cap1": false})


## Fine root hairs bristling from `at` in roughly the direction `out`.
func root_hairs(s: Sculpt, painter: int, at: Vector3, out: Vector3, count: int, length: float, seed: float) -> void:
	for k in range(count):
		var a := seed + k * 2.39
		var d := (out.normalized() + Vector3(cos(a), sin(a * 1.3), sin(a)) * 0.7).normalized()
		var l := length * (0.6 + 0.6 * fposmod(k * 0.618 + seed, 1.0))
		s.tube([at, at + d * l * 0.5 + Vector3(0, -l * 0.1, 0), at + d * l + Vector3(0, -l * 0.35, 0)], [0.006, 0.004, 0.001], painter, {"sides": 4, "per": 2, "cap1": false})


# ------------------------------------------------------------------ per-design details

## Moss on the shoulders, and the details that make each design its own.
func _extras(body: Sculpt, light: Sculpt, skin: Callable, hips_c: Vector3, chest: Vector3, neck: Vector3) -> void:
	var mp := body.add_painter(moss)
	var lw := light.add_painter(func (p, n, v, w): return Color.WHITE)
	match kind:
		"strangler":
			# Grey-green moss on the shoulders, and aerial roots hanging in curtains from the
			# shoulder yoke and the arms of the cage, the way a strangler fig drops them.
			for side: float in [-1.0, 1.0]:
				moss_clump(body, mp, Vector3(0.2 * side, 1.69, -0.1), 0.07, 4)
				for k in range(5):
					var at := Vector3((0.08 + k * 0.045) * side, 1.64 - k * 0.01, -0.03 + 0.02 * (k % 2))
					var l := 0.35 + 0.25 * fposmod(k * 0.618 + side, 1.0)
					body.tube([at, at + Vector3(0.01 * side, -l * 0.5, 0.03), at + Vector3(0.02 * side, -l, 0.05)], [0.012, 0.009, 0.002], body.add_painter(skin), {"sides": 5, "per": 2, "lump": 0.3, "cap1": false})
			# Grave-light seeping out through cracks where the roots have split.
			for k in range(4):
				var a := TAU * k / 4.0 + 0.5
				var at := hips_c.lerp(neck, 0.25 + 0.15 * k) + Vector3(cos(a) * 0.17, 0, sin(a) * 0.12)
				light.tube([at, at + Vector3(0.0, 0.08, 0.0), at + Vector3(0.01, 0.15, -0.01)], [0.008, 0.01, 0.003], lw, {"sides": 4, "per": 1, "cap_rings": 1})
		"mandrake":
			# The mandrake plant: a rosette of big wilted leaves over the shoulders, with its
			# round yellow-orange fruit (the "love apples") among them, and soil clinging on.
			var lf := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#26331c").lerp(Color("#4e5a30"), clampf(n.y * 0.4 + 0.3, 0.0, 1.0)).lerp(Color("#3a2a18"), smoothstep(0.5, 1.0, v) * 0.7))
			var fruit := body.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#c8781e").lerp(Color("#f0b040"), clampf(n.y * 0.5 + 0.4, 0.0, 1.0)))
			for side: float in [-1.0, 1.0]:
				for k in range(3):
					var a := (0.3 + k * 0.5) * side
					var base := Vector3(0.18 * side, 1.66, -0.05 + k * 0.05)
					var d := Vector3(sin(a) * 0.9, 0.15, cos(a) * 0.4 + 0.2).normalized()
					body.tube([base, base + d * 0.12 + Vector3(0, 0.01, 0), base + d * 0.24 + Vector3(0, -0.2, 0)], [0.02, 0.05, 0.004], lf, {"sides": 6, "per": 2, "flat": 0.2, "side": d.cross(Vector3.UP).normalized(), "cap1": false})
				body.blob(Vector3(0.14 * side, 1.7, 0.02), Vector3.ONE * 0.035, fruit, {"lat": 6, "lon": 8})
				body.blob(Vector3(0.1 * side, 1.69, 0.08), Vector3.ONE * 0.028, fruit, {"lat": 6, "lon": 8})
			for k in range(6):
				var at := Vector3(0.18 * sin(k * 2.3), 1.0 + k * 0.1, -0.12 + 0.05 * cos(k * 1.7))
				root_hairs(body, body.add_painter(skin), at, Vector3(sin(k * 2.3), -0.3, -0.5), 3, 0.18, k * 1.3)
		"bogoak":
			# Curtains of grey Spanish moss hanging from the shoulders and the trunk, and
			# spots of glowing foxfire fungus on the wood.
			var sm := body.add_painter(spanish_moss)
			for side: float in [-1.0, 1.0]:
				for k in range(6):
					var at := Vector3((0.1 + k * 0.035) * side, 1.64, -0.1 + 0.05 * (k % 3))
					var l := 0.3 + 0.3 * fposmod(k * 0.618 + side * 0.3, 1.0)
					body.tube([at, at + Vector3(0.02 * side, -l * 0.45, 0.03), at + Vector3(0.0, -l, 0.05)], [0.022, 0.014, 0.002], sm, {"sides": 5, "per": 2, "lump": 0.5, "cap1": false})
			for k in range(14):
				var t := fposmod(k * 0.618, 1.0)
				var a := TAU * fposmod(k * 0.382, 1.0)
				var at := hips_c.lerp(neck, t) + Vector3(cos(a) * (0.15 - t * 0.06), 0, sin(a) * 0.11)
				light.blob(at, Vector3(0.016, 0.012, 0.016), lw, {"lat": 3, "lon": 6})


# ------------------------------------------------------------------ the figure

func _figure(skin: Callable, strands: int, twist_gap: float) -> Node3D:
	var gaunt := kind != "mandrake"
	var body := Sculpt.new(); var bp := body.add_painter(skin)
	var dark := body.add_painter(func (p, n, v, w): return Color("#070605"))
	var light := Sculpt.new(); var lw := light.add_painter(func (p, n, v, w): return Color.WHITE)
	# A tall, hunched trunk: hips, a narrow waist and a forward-leaning chest.
	var hips_c := Vector3(0, 1.0, 0.04); var chest := Vector3(0, 1.48, -0.06); var neck := Vector3(0, 1.72, -0.16)
	match kind:
		"strangler":
			# A cage of roots that have grown together round a hollow, the grave-light inside.
			body.blob(chest + Vector3(0, -0.12, 0.06), Vector3(0.15, 0.24, 0.1), dark, {"lat": 8, "lon": 10})
			light.blob(chest + Vector3(0, -0.12, -0.04), Vector3(0.07, 0.12, 0.05), lw, {"lat": 6, "lon": 8})
			for k in range(9):
				var a := TAU * k / 9.0
				var bend := Vector3(cos(a) * 0.09, 0, sin(a) * 0.07)
				var top := neck + Vector3(cos(a) * 0.07, -0.04, sin(a) * 0.05)
				var bot := hips_c + Vector3(cos(a) * 0.12, 0.0, sin(a) * 0.09)
				body.tube([bot, bot.lerp(top, 0.3) + bend * 1.6, bot.lerp(top, 0.6) + bend * 1.8 + Vector3(0.04 * sin(a * 3.0), 0, 0), top], [0.04, 0.034, 0.03, 0.03], bp, {"sides": 7, "per": 3, "lump": 0.15})
			# Cross-roots fused across the cage.
			for k in range(5):
				var y := 1.08 + k * 0.13
				var r := 0.16 + sin(PI * (k + 0.5) / 5.0) * 0.06
				body.tube([Vector3(-r, y, -0.02), Vector3(-r * 0.4, y + 0.04, -0.06 - r * 0.6), Vector3(r * 0.5, y - 0.03, -0.05 - r * 0.6), Vector3(r, y + 0.02, 0.0)], [0.022, 0.026, 0.022, 0.02], bp, {"sides": 6, "per": 2, "lump": 0.2})
		"mandrake":
			# A fat, wrinkled tuber of a body, forking into the legs below.
			body.tube([hips_c + Vector3(0, -0.06, 0), hips_c + Vector3(0, 0.18, 0), chest + Vector3(0, -0.05, 0), neck + Vector3(0, -0.06, 0)], [0.16, 0.22, 0.21, 0.1], bp, {"sides": 16, "per": 4, "lump": 0.14, "bands": 14, "band": 0.04})
			root_hairs(body, bp, chest + Vector3(0.17, -0.1, -0.05), Vector3(1, -0.4, -0.2), 4, 0.25, 1.0)
			root_hairs(body, bp, chest + Vector3(-0.18, -0.25, 0.0), Vector3(-1, -0.4, 0.1), 4, 0.25, 2.0)
			root_hairs(body, bp, hips_c + Vector3(0.12, 0.1, -0.1), Vector3(0.6, -0.6, -0.6), 3, 0.2, 3.0)
		"bogoak":
			# A gaunt black trunk, split open over the chest with foxfire glowing inside.
			root_bundle(body, bp, hips_c, neck, 0.16, 0.08, 4, 1.4)
			body.blob(chest + Vector3(0, -0.06, -0.09), Vector3(0.055, 0.17, 0.05), dark, {"lat": 6, "lon": 8})
			light.blob(chest + Vector3(0, -0.06, -0.135), Vector3(0.03, 0.13, 0.015), lw, {"lat": 5, "lon": 8})
	# Shoulders: a heavy root yoke across the top of the chest.
	body.tube([Vector3(-0.27, 1.6, -0.08), Vector3(-0.1, 1.67, -0.12), Vector3(0.1, 1.67, -0.12), Vector3(0.27, 1.6, -0.08)], [0.07, 0.08, 0.08, 0.07], bp, {"sides": 9, "per": 2, "lump": 0.2})
	# Thin roots dangling from the hips and waist, swaying as it walks.
	for k in range(7):
		var a := TAU * k / 7.0 + 0.3
		var at := hips_c + Vector3(cos(a) * 0.13, -0.02 + 0.08 * (k % 2), sin(a) * 0.1)
		var l := 0.3 + 0.15 * fposmod(k * 0.618, 1.0)
		body.tube([at, at + Vector3(cos(a) * 0.06, -l * 0.5, sin(a) * 0.05), at + Vector3(cos(a) * 0.09 + 0.02 * sin(k * 2.0), -l, sin(a) * 0.07)], [0.018, 0.011, 0.002], bp, {"sides": 5, "per": 2, "lump": 0.3, "cap1": false})

	# ---- the head: faceless
	var head := joint(root, "Head", Vector3(0, 1.75, -0.18))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin); var hd := hs.add_painter(func (p, n, v, w): return Color("#060504"))
	var hl := Sculpt.new(); var hlw := hl.add_painter(func (p, n, v, w): return Color.WHITE)
	match kind:
		"strangler":
			# A long, smooth knot of fused roots for a head, bent forward, with no face: only a
			# deep split down the front, grave-light glowing far inside.
			for k in range(5):
				var a := TAU * k / 5.0
				hs.tube([Vector3(cos(a) * 0.05, 1.72, -0.2 + sin(a) * 0.04), Vector3(cos(a) * 0.08, 1.86, -0.28 + sin(a) * 0.06), Vector3(cos(a) * 0.05, 2.0, -0.3 + sin(a) * 0.04), Vector3(cos(a) * 0.01, 2.1, -0.24)], [0.04, 0.05, 0.04, 0.01], hp, {"sides": 7, "per": 3, "lump": 0.15})
			hs.blob(Vector3(0, 1.9, -0.36), Vector3(0.03, 0.12, 0.03), hd, {"lat": 5, "lon": 8})
			hl.blob(Vector3(0, 1.9, -0.385), Vector3(0.012, 0.08, 0.01), hlw, {"lat": 4, "lon": 6})
		"mandrake":
			# A round wrinkled root head, three dark holes for eyes and a gaping mouth, and a
			# tuft of broad mandrake leaves sprouting from the crown.
			# The head hangs forward, lumpy and twisted, a long screaming mouth stretched open.
			hs.blob(Vector3(0, 1.88, -0.26), Vector3(0.14, 0.18, 0.13), hp, {"lat": 12, "lon": 14, "lump": 0.25})
			hs.blob(Vector3(0.05, 1.98, -0.22), Vector3(0.09, 0.08, 0.09), hp, {"lat": 8, "lon": 10, "lump": 0.3})
			for side: float in [-1.0, 1.0]:
				# Deep, drooping, sunken holes for eyes under heavy lumpy brows.
				hs.blob(Vector3(0.058 * side, 1.94, -0.368), Vector3(0.024, 0.032, 0.022), hd, {"lat": 5, "lon": 8, "basis": Basis(Vector3.BACK, -0.5 * side)})
				hs.blob(Vector3(0.06 * side, 1.972, -0.352), Vector3(0.05, 0.02, 0.03), hp, {"lat": 5, "lon": 7, "lump": 0.4, "basis": Basis(Vector3.BACK, 0.3 * side)})
				hs.blob(Vector3(0.075 * side, 1.89, -0.355), Vector3(0.035, 0.03, 0.025), hp, {"lat": 4, "lon": 7, "lump": 0.3})
			# A long, twisted screaming mouth, wider at the bottom.
			hs.blob(Vector3(0.005, 1.79, -0.355), Vector3(0.045, 0.11, 0.03), hd, {"lat": 6, "lon": 9, "basis": Basis(Vector3.BACK, 0.12)})
			hs.blob(Vector3(0.01, 1.73, -0.35), Vector3(0.055, 0.04, 0.03), hd, {"lat": 5, "lon": 8})
			var lf := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#26331c").lerp(Color("#4e5a30"), clampf(n.y * 0.4 + 0.3, 0.0, 1.0)).lerp(Color("#3a2a18"), smoothstep(0.5, 1.0, v) * 0.7))
			for k in range(9):
				var a := TAU * k / 9.0
				var d := Vector3(cos(a) * 0.9, 1.0, sin(a) * 0.9).normalized()
				var base := Vector3(0, 2.04, -0.24)
				hs.tube([base, base + d * 0.14 + Vector3(0, 0.02, 0), base + d * 0.3 + Vector3(0, -0.14, 0)], [0.02, 0.045, 0.004], lf, {"sides": 6, "per": 2, "flat": 0.2, "side": Vector3(-sin(a), 0, cos(a)), "cap1": false})
			root_hairs(hs, hp, Vector3(0, 1.75, -0.32), Vector3(0, -1, -0.3), 5, 0.15, 4.0)
			for side: float in [-1.0, 1.0]: hl.blob(Vector3(0.058 * side, 1.935, -0.38), Vector3(0.006, 0.006, 0.005), hlw, {"lat": 3, "lon": 6})
		"bogoak":
			# A gnarled black stump of a head, split from crown to chin, foxfire inside; grey
			# moss hanging from it like hair.
			root_bundle(hs, hp, Vector3(0, 1.72, -0.18), Vector3(0, 2.05, -0.3), 0.12, 0.06, 3, 1.2, Vector3(0, 0, -0.04))
			hs.blob(Vector3(0, 1.9, -0.34), Vector3(0.04, 0.13, 0.03), hd, {"lat": 5, "lon": 8})
			hl.blob(Vector3(0, 1.9, -0.365), Vector3(0.018, 0.1, 0.012), hlw, {"lat": 4, "lon": 6})
			# Broken branch-stubs like antlers.
			# Broken, branching branch-stubs like antlers.
			for side: float in [-1.0, 1.0]:
				var b0 := Vector3(0.06 * side, 2.0, -0.26); var b1 := Vector3(0.15 * side, 2.14, -0.22); var b2 := Vector3(0.19 * side, 2.3, -0.18)
				hs.tube([b0, b1, b2], [0.032, 0.022, 0.008], hp, {"sides": 6, "per": 2, "lump": 0.25})
				hs.tube([b1, b1 + Vector3(0.1 * side, 0.05, 0.02), b1 + Vector3(0.16 * side, 0.12, 0.03)], [0.018, 0.012, 0.004], hp, {"sides": 5, "per": 2, "lump": 0.25})
				hs.tube([b0.lerp(b1, 0.5), b0.lerp(b1, 0.5) + Vector3(0.02 * side, 0.1, -0.06)], [0.014, 0.003], hp, {"sides": 5, "per": 1, "lump": 0.25})
			var mp := hs.add_painter(spanish_moss)
			for k in range(12):
				var a := lerpf(-1.4, 1.4, k / 11.0)
				var at := Vector3(sin(a) * 0.1, 1.98 - absf(a) * 0.05, -0.24 + cos(a) * 0.02)
				var l := 0.25 + 0.15 * fposmod(k * 0.618, 1.0)
				hs.tube([at, at + Vector3(sin(a) * 0.03, -l * 0.5, 0.03), at + Vector3(sin(a) * 0.05, -l, 0.05)], [0.02, 0.014, 0.002], mp, {"sides": 5, "per": 2, "lump": 0.5, "cap1": false})
	part(head, "Head", hs)
	var core := part(head, "GraveLight", hl, glow); core.material_override = glow

	# ---- arms: very long, ending in long wooden fingers that drag on the ground
	var arms: Array = []; var forearms: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var sh_at := Vector3(0.3 * side, 1.6, -0.08)
		var shoulder := joint(root, label + "Shoulder", sh_at)
		var us := Sculpt.new(); var up := us.add_painter(skin)
		var elbow_at := Vector3(0.42 * side, 1.12, -0.06)
		root_bundle(us, up, sh_at, elbow_at, 0.07 if gaunt else 0.09, 0.05, strands, 1.5, Vector3(0.04 * side, 0, 0))
		us.blob(elbow_at, Vector3.ONE * 0.055, up, {"lat": 5, "lon": 7, "lump": 0.25})
		if kind == "bogoak":
			# Bracket fungi growing in shelves out of the shoulder.
			var fp := us.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#a07a4a").lerp(Color("#e0cca0"), clampf(n.y * 0.5 + 0.3, 0.0, 1.0)))
			for j in range(3):
				var at := sh_at + Vector3(0.05 * side, -0.05 - j * 0.07, 0.04 + j * 0.02)
				us.lathe(at, [Vector2(0, 0.012), Vector2(0.07 - j * 0.012, 0.0), Vector2(0.075 - j * 0.012, -0.012), Vector2(0, -0.01)], fp, {"sides": 10, "basis": Basis(Vector3.FORWARD, -0.2 * side) * Basis.from_scale(Vector3(1.0, 1.0, 0.7))})
		part(shoulder, "UpperArm", us)
		var elbow := joint(shoulder, "Forearm", elbow_at)
		var fs := Sculpt.new(); var fp2 := fs.add_painter(skin)
		var wrist := Vector3(0.47 * side, 0.4, -0.16)
		root_bundle(fs, fp2, elbow_at, wrist, 0.05, 0.035, strands, 1.5)
		wood_fingers(fs, fp2, wrist, Vector3(0.05 * side, -0.9, -0.5), side, 0.4)
		if kind == "mandrake": root_hairs(fs, fp2, elbow_at.lerp(wrist, 0.5), Vector3(side, -0.3, 0), 4, 0.14, side)
		if kind == "bogoak":
			var mp2 := fs.add_painter(spanish_moss)
			for j in range(4):
				var at := elbow_at.lerp(wrist, 0.2 + j * 0.2) + Vector3(0, 0, 0.03)
				fs.tube([at, at + Vector3(0.02 * side, -0.12, 0.04), at + Vector3(0.03 * side, -0.24 - 0.05 * j, 0.06)], [0.016, 0.01, 0.002], mp2, {"sides": 5, "per": 2, "lump": 0.5, "cap1": false})
		part(elbow, "Forearm", fs)
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs: long and thin, knees bent, splaying into roots at the feet
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(0.11 * side, 1.0, 0.04)
		var hip := joint(root, label + "Hip", hip_at)
		var ts := Sculpt.new(); var tp := ts.add_painter(skin)
		var knee_at := Vector3(0.15 * side, 0.55, -0.08)
		root_bundle(ts, tp, hip_at, knee_at, 0.08 if gaunt else 0.11, 0.055, strands, 1.2)
		ts.blob(knee_at, Vector3.ONE * 0.06, tp, {"lat": 5, "lon": 7, "lump": 0.25})
		part(hip, "Thigh", ts)
		var knee := joint(hip, "Knee", knee_at)
		var ls := Sculpt.new(); var lp := ls.add_painter(skin)
		var ankle := Vector3(0.16 * side, 0.1, 0.04)
		root_bundle(ls, lp, knee_at, ankle, 0.055, 0.045, strands, 1.2)
		# The foot spreads into roots gripping the ground.
		var dirs: Array = []
		for k in range(5):
			var a := lerpf(-1.1, 1.1, k / 4.0)
			dirs.append(Vector3(sin(a) * 0.9 + 0.2 * side, -0.25, -cos(a) * 0.9 - 0.15))
		dirs.append(Vector3(0.1 * side, -0.3, 1.0))
		roots(ls, lp, ankle, dirs, 0.22, 0.03, 0.08, true)
		part(knee, "Shin", ls)
		hips.append(hip); knees.append(knee)
	_extras(body, light, skin, hips_c, chest, neck)
	part(root, "Body", body)
	var lm := part(root, "GraveLight", light, glow); lm.material_override = glow
	return _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, 1.4)
