extends "res://tools/sculpt_kiteclaw_raptor.gd"
## The Ash Harpy of the Ashfall Caldera, sculpted by hand: a great bird of prey of the volcano,
## its feathers sooty and layered, their tips smouldering like embers, its eyes burning; it
## spreads its wings before beating up a gust of hot ash. Three designs:
##   eagle   - a giant harpy eagle (the bird the harpies of myth gave their name to): a grey
##             face, a double crest of long feathers it raises in anger, a black band across the
##             chest, barred feathered "trousers", the biggest talons of any eagle and broad
##             rounded wings for flying through forest — here, through ash clouds
##   harpy   - the harpy of Greek myth: a vulture's body and wings with the gaunt, bony face of
##             a hag, wild ragged ash-grey hair, clawed hands at the bend of each wing, glowing
##             eyes and a mouth of needle teeth
##   vulture - a lappet-faced vulture, the biggest vulture of Africa: a bare head with folds of
##             skin on the cheeks, here charred black and cracked with glowing coals, a huge
##             hooked beak, a ruff of ash feathers, and long broad wings with ragged, burnt,
##             smoking fingertips

const EMBER_C := Color("#ff7a24")

var smoke_mat: StandardMaterial3D


func _init() -> void:
	super()
	smoke_mat = StandardMaterial3D.new()
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.roughness = 1.0
	feather_mat.vertex_color_is_srgb = true
	feather_mat.albedo_color = Color(0.55, 0.55, 0.55)


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "AshHarpy"
	match variant:
		"eagle": return _eagle()
		"harpy": return _harpy()
		"vulture": return _vulture()
	return null


# ------------------------------------------------------------------ painters

## Sooty plumage: charcoal on top, ashy grey below, smudged with soot.
static func soot(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#2a2726").lerp(Color("#6e6964"), clampf(0.35 - n.y * 0.45 + Sculpt.fbm(p * 8.0) * 0.35, 0.0, 1.0))
	return c.darkened(smoothstep(0.5, 0.7, Sculpt.noise(p * 22.0)) * 0.3)


## A feather painter: `base` barred with `bar`, the tip smouldering into a glowing ember.
func ember_feather(base: Color, bar: Color, bars: float, ember := 0.85) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := base.lerp(bar, smoothstep(0.55, 0.8, sin(v * bars * PI)) * 0.8 * float(bars > 0.0))
		c = c.darkened(Sculpt.noise(p * 20.0) * 0.1)
		if ember >= 1.0: return c
		return c.lerp(Color("#1a0d08"), smoothstep(ember - 0.12, ember, v)).lerp(EMBER_C, smoothstep(ember, 1.0, v))


## Bare skin, charred black and cracked, with coals glowing in the cracks.
static func charred_skin(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#191312").lerp(Color("#3e2c28"), clampf(n.y * 0.3 + 0.3 + Sculpt.fbm(p * 18.0) * 0.4, 0.0, 1.0))
	var crack := absf(Sculpt.noise(p * Vector3(28.0, 18.0, 28.0)))
	return c.lerp(Color("#ff6a1a"), smoothstep(0.06, 0.015, crack))


static func wisp(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return Color("#3a3634").lerp(Color("#8a847e"), clampf(n.y * 0.4 + 0.4, 0.0, 1.0)).lerp(Color("#5a5450"), v * 0.5)


# ------------------------------------------------------------------ shared pieces

## A bird's body lying level for flight: the trunk, the neck rising to the head, layered
## contour feathers lying back along it. Returns the body sculpt.
func bird_body(paint: Callable, feather_paint: Callable, length: float, girth: float, neck_top: Vector3) -> Sculpt:
	var body := Sculpt.new(); var bp := body.add_painter(paint); var cp := body.add_painter(feather_paint)
	body.tube([Vector3(0, 1.0, 0.42 * length), Vector3(0, 1.04, 0.15), Vector3(0, 1.05, -0.15), Vector3(0, 1.1, -0.35)], [0.13 * girth, 0.23 * girth, 0.25 * girth, 0.18 * girth], bp, {"sides": 14, "per": 3, "flat": 0.85, "lump": 0.05})
	body.tube([Vector3(0, 1.12, -0.35), Vector3(0, 1.18, -0.45), neck_top], [0.14 * girth, 0.11 * girth, 0.09 * girth], bp, {"sides": 11, "per": 3})
	for row in range(8):
		var z := -0.34 + row * 0.1
		var radius := (0.22 - absf(z + 0.05) * 0.25) * girth
		var y0 := 1.05 + (0.02 if z < 0.0 else -0.04 * z)
		for k in range(9):
			var ang := PI * (-0.6 + 1.2 * (k + (row % 2) * 0.5) / 8.0)
			var radial := Vector3(sin(ang), cos(ang), 0)
			var base := Vector3(0, y0, z) + Vector3(radial.x * radius * 0.85, radial.y * radius, 0)
			feather(body, cp, base, radial * 0.25 + Vector3(0, 0, 1.0), 0.17, 0.06, radial, 0.06, 1)
	return body


## A broad tail fan of `count` feathers.
func tail_fan(paint: Callable, count: int, length: float, spread: float, at: Vector3) -> Node3D:
	var tail := joint(root, "Tail", at)
	var ts := Sculpt.new(); var tf := ts.add_painter(paint)
	for k in range(count):
		var t := (k - (count - 1) * 0.5) / ((count - 1) * 0.5)
		feather(ts, tf, at + Vector3(t * 0.05, 0, -0.04), Vector3(t * spread, -0.05, 1.0), length * (1.0 - absf(t) * 0.12), 0.09, Vector3.UP, 0.03)
	part(tail, "Tail", ts, feather_mat)
	return tail


## Smoke trailing back from the wingtips, on the wing joints so it follows the wingbeat.
func wing_smoke(wings: Array, span: float) -> void:
	for k in range(wings.size()):
		var side := -1.0 if k == 0 else 1.0
		var w: Node3D = wings[k]
		var at := _world(w) + Vector3(side * span * 0.8, -0.02, 0.35)
		var s := Sculpt.new(); var sp := s.add_painter(wisp)
		for j in range(4):
			s.blob(at + Vector3(side * 0.03 * j, 0.03 * j, 0.14 * j), Vector3(0.05, 0.04, 0.08) * (1.0 + j * 0.45), sp, {"lat": 5, "lon": 7, "lump": 0.6})
		part(w, "Smoke", s, smoke_mat)


## Glowing ember tips over a wing's trailing edge, on their own glowing mesh.
func ember_edge(wing: Node3D, side: float, shoulder: Vector3, span: float, chord: float) -> void:
	var s := Sculpt.new(); var p := s.add_painter(func (pp, n, v, w): return Color("#ffb060").lerp(EMBER_C, v))
	for k in range(14):
		var t := k / 13.0
		var at := shoulder + Vector3(side * span * (0.08 + t * 0.72), -0.01, chord * (1.0 - t * 0.35) + 0.04 + t * t * chord * 0.5)
		s.blob(at, Vector3(0.022, 0.008, 0.03), p, {"lat": 3, "lon": 5})
	var m := part(wing, "Embers", s, glow); m.material_override = glow


# ------------------------------------------------------------------ A: harpy eagle

func _eagle() -> Node3D:
	_eyes(Color("#ff8a2a"))
	var grey := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#7d7873").lerp(Color("#a8a29c"), clampf(n.y * 0.4 + 0.4 + Sculpt.fbm(p * 10.0) * 0.3, 0.0, 1.0))
	var black := ember_feather(Color("#1e1c1c"), Color("#3a3634"), 0.0, 0.9)
	var belly := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := Color("#c9c2b8").lerp(Color("#8e877e"), Sculpt.fbm(p * 12.0) * 0.4 + 0.2)
		# The black chest band.
		return c.lerp(Color("#1a1818"), smoothstep(-0.18, -0.24, p.z) * smoothstep(-0.44, -0.38, p.z) * smoothstep(-0.2, -0.6, n.y))
	var body := bird_body(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return soot(p, n, v, w).lerp(belly.call(p, n, v, w), smoothstep(-0.15, -0.55, n.y)), ember_feather(Color("#2e2b2a"), Color("#545050"), 1.0, 1.2), 1.0, 1.15, Vector3(0, 1.3, -0.56))
	part(root, "Body", body)
	var head := joint(root, "Head", Vector3(0, 1.3, -0.58))
	var hs := Sculpt.new(); var hp := hs.add_painter(grey)
	var beak := hs.add_painter(func (p, n, v, w): return Color("#2a2622").lerp(Color("#5a524a"), clampf(n.y, 0.0, 1.0) * 0.4))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#0d0a09"))
	# A big rounded head with a facial disc, a massive hooked black beak and a heavy brow.
	hs.blob(Vector3(0, 1.34, -0.62), Vector3(0.12, 0.12, 0.13), hp, {"lat": 9, "lon": 13})
	hs.blob(Vector3(0, 1.33, -0.69), Vector3(0.115, 0.105, 0.06), hp, {"lat": 7, "lon": 11})
	hs.tube([Vector3(0, 1.335, -0.73), Vector3(0, 1.33, -0.8), Vector3(0, 1.3, -0.845), Vector3(0, 1.245, -0.84)], [0.05, 0.04, 0.022, 0.003], beak, {"sides": 8, "per": 3, "flat": 0.7, "side": Vector3.RIGHT, "cap_rings": 1})
	# Forward-facing eyes in dark sockets under a heavy, frowning brow.
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.055 * side, 1.36, -0.74), Vector3(0.03, 0.025, 0.012), dark, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.056 * side, 1.392, -0.742), Vector3(0.045, 0.014, 0.03), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, -0.3 * side)})
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]: es.blob(Vector3(0.056 * side, 1.36, -0.751), Vector3(0.021, 0.018, 0.008), white, {"lat": 4, "lon": 7})
	# The double crest: two fans of long black feathers standing up from the back of the head,
	# their tips glowing.
	var crest := hs.add_painter(ember_feather(Color("#1a1818"), Color("#3a3634"), 0.0, 0.78))
	for side: float in [-1.0, 1.0]:
		for k in range(9):
			var t := k / 8.0
			var base := Vector3(0.035 * side * (1.0 - t * 0.4), 1.45 - t * 0.06, -0.62 + t * 0.12)
			feather(hs, crest, base, Vector3(side * (0.25 + t * 0.35), 1.0 - t * 0.4, 0.4 + t * 0.8), 0.22 - absf(t - 0.3) * 0.12, 0.04, Vector3(side, 0, -0.3).normalized(), -0.12)
	part(head, "Head", hs)
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.3, -0.76))
	var js := Sculpt.new(); var jb := js.add_painter(func (p, n, v, w): return Color("#2a2622"))
	js.tube([Vector3(0, 1.3, -0.76), Vector3(0, 1.29, -0.83)], [0.03, 0.012], jb, {"sides": 7, "per": 2, "flat": 0.7, "side": Vector3.RIGHT, "cap_rings": 1})
	part(jaw, "Jaw", js)
	# Broad rounded wings, dark grey barred with black, ember-tipped.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.16 * side, 1.14, -0.2)
		var w := feathered_wing(side, sh, 2.2, 0.82, soot, ember_feather(Color("#2b2827"), Color("#5a5652"), 4.0), ember_feather(Color("#353130"), Color("#625d58"), 3.0), ember_feather(Color("#3a3634"), Color("#5e5955"), 1.0, 1.2), 10, 0.06)
		wings.append(w)
	# Thick legs in barred feather trousers, and the biggest talons of any eagle.
	var legs := hanging_legs(soot, func (p, n, v, w): return Color("#c9a83a").lerp(Color("#8a6a1a"), Sculpt.noise(p * 30.0) * 0.5 + 0.3), 0.95, 0.15, 0.7, false, ember_feather(Color("#c9c2b8"), Color("#2a2626"), 3.0, 0.95))
	for k in range(2): (legs[1][k] as Node3D).get_child(0).scale = Vector3.ONE * 1.25
	var tail := tail_fan(ember_feather(Color("#2b2827"), Color("#8a847e"), 3.0), 12, 0.62, 0.5, Vector3(0, 1.0, 0.42))
	return _close(head, core, wings, legs[0], legs[1], [tail], jaw, 1.15)


# ------------------------------------------------------------------ B: harpy of myth

func _harpy() -> Node3D:
	_eyes(Color("#ff5a1a"))
	var skin := func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#3e3734").lerp(Color("#77695f"), clampf(n.y * 0.4 + 0.4 + Sculpt.fbm(p * 14.0) * 0.3, 0.0, 1.0)).darkened(smoothstep(0.6, 0.75, Sculpt.noise(p * 40.0)) * 0.25)
	var body := bird_body(soot, ember_feather(Color("#2a2726"), Color("#4e4a48"), 0.0, 1.2), 1.0, 1.1, Vector3(0, 1.32, -0.56))
	# A gaunt bare chest and collarbones where the feathers stop, the ribs showing.
	var bs := body.add_painter(skin)
	body.blob(Vector3(0, 1.12, -0.42), Vector3(0.17, 0.14, 0.12), bs, {"lat": 8, "lon": 12})
	for k in range(4):
		var y := 1.17 - k * 0.04
		body.tube([Vector3(-0.15, y, -0.4), Vector3(0, y - 0.02, -0.53), Vector3(0.15, y, -0.4)], [0.01, 0.012, 0.01], bs, {"sides": 5, "per": 2, "cap_rings": 1})
	part(root, "Body", body)
	var head := joint(root, "Head", Vector3(0, 1.32, -0.56))
	var hs := Sculpt.new(); var hp := hs.add_painter(skin)
	var dark := hs.add_painter(func (p, n, v, w): return Color("#0a0606"))
	var tooth := hs.add_painter(func (p, n, v, w): return Color("#e6dcc4"))
	var hair := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#1e1b1a").lerp(Color("#6e6762"), clampf(n.y * 0.3 + 0.3 + Sculpt.noise(p * 30.0) * 0.4, 0.0, 1.0)).lerp(EMBER_C, smoothstep(0.88, 1.0, v)))
	# A gaunt, bony face: a high skull, sunken cheeks, a sharp chin, a hooked nose like a beak,
	# deep eye sockets and a wide lipless mouth of needle teeth.
	# The skull behind, then a flat gaunt face: a jutting brow ridge, deep black sockets, hollow
	# cheeks under sharp cheekbones, a long hooked nose and a wide gaping mouth.
	hs.blob(Vector3(0, 1.47, -0.58), Vector3(0.105, 0.12, 0.11), hp, {"lat": 10, "lon": 14})
	hs.blob(Vector3(0, 1.43, -0.65), Vector3(0.085, 0.1, 0.055), hp, {"lat": 9, "lon": 12})
	hs.tube([Vector3(-0.075, 1.462, -0.7), Vector3(0, 1.47, -0.712), Vector3(0.075, 1.462, -0.7)], [0.016, 0.02, 0.016], hp, {"sides": 6, "per": 3, "cap_rings": 1})
	for side: float in [-1.0, 1.0]:
		hs.blob(Vector3(0.038 * side, 1.44, -0.692), Vector3(0.026, 0.02, 0.012), dark, {"lat": 5, "lon": 8})
		hs.blob(Vector3(0.068 * side, 1.405, -0.672), Vector3(0.022, 0.016, 0.02), hp, {"lat": 4, "lon": 7})
		hs.tube([Vector3(0.07 * side, 1.4, -0.67), Vector3(0.05 * side, 1.34, -0.69), Vector3(0.02 * side, 1.31, -0.7)], [0.012, 0.014, 0.01], hp, {"sides": 6, "per": 2, "cap_rings": 1})
	hs.tube([Vector3(0, 1.455, -0.71), Vector3(0, 1.41, -0.74), Vector3(0, 1.385, -0.735)], [0.012, 0.016, 0.004], hp, {"sides": 6, "per": 2, "cap_rings": 1})
	hs.blob(Vector3(0, 1.345, -0.698), Vector3(0.045, 0.028, 0.012), dark, {"lat": 5, "lon": 8})
	for k in range(9):
		var x := (k - 4) * 0.01
		hs.crystal(Vector3(x, 1.368, -0.705 + absf(x) * 0.25), Vector3(0, -1, -0.1), 0.024, 0.0035, tooth, 4)
		hs.crystal(Vector3(x, 1.322, -0.703 + absf(x) * 0.25), Vector3(0, 1, -0.1), 0.02, 0.0035, tooth, 4)
	# Wild ragged hair streaming back from the head, smouldering at the ends.
	for k in range(30):
		var a := lerpf(-1.6, 1.6, fposmod(k * 0.618, 1.0))
		var at := Vector3(sin(a) * 0.1, 1.52 + cos(a) * 0.05 - absf(a) * 0.03, -0.64 + fposmod(k * 0.29, 1.0) * 0.12)
		var l := 0.28 + 0.25 * fposmod(k * 0.37, 1.0)
		var wob := 0.04 * sin(k * 2.3)
		hs.tube([at, at + Vector3(sin(a) * 0.09 + wob, 0.05, l * 0.35), at + Vector3(sin(a) * 0.15 - wob, -0.04, l * 0.7), at + Vector3(sin(a) * 0.2 + wob, -0.18, l)], [0.03, 0.024, 0.014, 0.002], hair, {"sides": 5, "per": 2, "cap1": false, "flat": 0.5, "lump": 0.4})
	part(head, "Head", hs)
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]: es.blob(Vector3(0.038 * side, 1.44, -0.703), Vector3(0.012, 0.009, 0.005), white, {"lat": 4, "lon": 7})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.34, -0.66))
	var js := Sculpt.new(); var jp := js.add_painter(skin)
	js.blob(Vector3(0, 1.31, -0.69), Vector3(0.04, 0.02, 0.03), jp, {"lat": 4, "lon": 7})
	part(jaw, "Jaw", js)
	# A vulture's broad wings, with a bony clawed hand at the bend of each.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.17 * side, 1.15, -0.32)
		var w := feathered_wing(side, sh, 2.1, 0.85, soot, ember_feather(Color("#1e1c1c"), Color("#3a3634"), 0.0), ember_feather(Color("#2a2726"), Color("#4e4a48"), 0.0), ember_feather(Color("#3a3634"), Color("#5e5955"), 0.0, 1.2), 9, 0.1)
		var cs := Sculpt.new(); var cp := cs.add_painter(skin); var cl := cs.add_painter(func (p, n, v, w2): return Color("#1a1210"))
		var wrist := sh + Vector3(side * 2.1 * 0.62, -0.03, -0.02)
		for f in range(3):
			var dir := Vector3(side * 0.3, -0.2, -1.0).rotated(Vector3.UP, (f - 1) * 0.35 * side)
			var mid := wrist + dir.normalized() * 0.09
			cs.tube([wrist, mid], [0.018, 0.013], cp, {"sides": 6, "per": 1})
			cs.tube([mid, mid + (dir + Vector3(0, -0.8, 0)).normalized() * 0.07], [0.011, 0.002], cl, {"sides": 5, "per": 2, "cap1": false})
		part(w, "Hand", cs)
		wings.append(w)
	var legs := hanging_legs(skin, func (p, n, v, w): return Color("#3a302a").lerp(Color("#5e4e42"), Sculpt.noise(p * 30.0) * 0.5 + 0.3), 0.95, 0.15, 0.7, false, ember_feather(Color("#2a2726"), Color("#4e4a48"), 0.0))
	var tail := tail_fan(ember_feather(Color("#1e1c1c"), Color("#3a3634"), 0.0), 11, 0.5, 0.45, Vector3(0, 1.0, 0.42))
	return _close(head, core, wings, legs[0], legs[1], [tail], jaw, 1.15)


# ------------------------------------------------------------------ C: lappet-faced vulture

func _vulture() -> Node3D:
	_eyes(Color("#ffb02a"))
	var body := bird_body(soot, ember_feather(Color("#2a2523"), Color("#4a4240"), 0.0, 1.2), 1.0, 1.2, Vector3(0, 1.26, -0.6))
	part(root, "Body", body)
	# The ruff: a collar of long ash-grey feathers round the base of the bare neck.
	var rs := Sculpt.new(); var rp := rs.add_painter(ember_feather(Color("#8a847e"), Color("#c4beb6"), 0.0, 0.9))
	for k in range(18):
		var a := TAU * k / 18.0
		var out := Vector3(cos(a), sin(a) * 0.9, 0.0)
		feather(rs, rp, Vector3(0, 1.18, -0.42) + out * 0.13, out * 0.8 + Vector3(0, 0, 0.6), 0.16, 0.05, Vector3(0, 0, -1).cross(out).cross(out).normalized() * -1.0, 0.1)
	part(root, "Ruff", rs, feather_mat)
	var head := joint(root, "Head", Vector3(0, 1.26, -0.6))
	var hs := Sculpt.new(); var hp := hs.add_painter(charred_skin)
	var beak := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#8e8270").lerp(Color("#1e1915"), smoothstep(0.3, 0.9, v)))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#0b0706"))
	# A bare, wrinkled head and neck, with folds of skin (the lappets) hanging on the cheeks.
	hs.tube([Vector3(0, 1.2, -0.48), Vector3(0, 1.25, -0.56), Vector3(0, 1.3, -0.62)], [0.07, 0.06, 0.07], hp, {"sides": 10, "per": 3, "bands": 6, "band": 0.12})
	hs.blob(Vector3(0, 1.33, -0.66), Vector3(0.1, 0.09, 0.11), hp, {"lat": 9, "lon": 12, "lump": 0.12})
	for side: float in [-1.0, 1.0]:
		hs.tube([Vector3(0.07 * side, 1.31, -0.68), Vector3(0.08 * side, 1.26, -0.67), Vector3(0.075 * side, 1.21, -0.65)], [0.03, 0.028, 0.012], hp, {"sides": 6, "per": 2, "flat": 0.4, "side": Vector3(side, 0, 0), "lump": 0.3})
		hs.blob(Vector3(0.055 * side, 1.36, -0.72), Vector3(0.024, 0.02, 0.016), dark, {"lat": 4, "lon": 7})
		hs.blob(Vector3(0.05 * side, 1.385, -0.72), Vector3(0.036, 0.012, 0.03), hp, {"lat": 4, "lon": 7, "basis": Basis(Vector3.BACK, 0.35 * side)})
	# A huge deep hooked beak.
	hs.tube([Vector3(0, 1.34, -0.74), Vector3(0, 1.34, -0.84), Vector3(0, 1.31, -0.9), Vector3(0, 1.25, -0.9)], [0.055, 0.045, 0.025, 0.003], beak, {"sides": 8, "per": 3, "flat": 0.6, "side": Vector3.RIGHT, "cap_rings": 1})
	part(head, "Head", hs)
	var es := Sculpt.new(); var white := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side: float in [-1.0, 1.0]: es.blob(Vector3(0.06 * side, 1.36, -0.732), Vector3(0.016, 0.014, 0.01), white, {"lat": 4, "lon": 7})
	var core := part(head, "GlowingEyes", es, glow); core.material_override = glow
	var jaw := joint(head, "Jaw", Vector3(0, 1.3, -0.76))
	var js := Sculpt.new(); var jb := js.add_painter(func (p, n, v, w): return Color("#bfb292"))
	js.tube([Vector3(0, 1.3, -0.76), Vector3(0, 1.29, -0.86)], [0.035, 0.012], jb, {"sides": 7, "per": 2, "flat": 0.6, "side": Vector3.RIGHT, "cap_rings": 1})
	part(jaw, "Jaw", js)
	# Very long broad wings with spread "fingers" at the tips, burnt ragged and smoking.
	var wings: Array = []
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.18 * side, 1.13, -0.22)
		var w := feathered_wing(side, sh, 2.5, 0.9, soot, ember_feather(Color("#1c1918"), Color("#2e2a28"), 0.0, 0.8), ember_feather(Color("#2a2523"), Color("#4a4240"), 0.0, 0.88), ember_feather(Color("#3a3432"), Color("#5a5250"), 0.0, 1.2), 8, 0.05)
		wings.append(w)
	var legs := hanging_legs(soot, func (p, n, v, w): return Color("#8e8a84").lerp(Color("#5e5a54"), Sculpt.noise(p * 30.0) * 0.5 + 0.3), 0.95, 0.15, 0.7, false)
	var tail := tail_fan(ember_feather(Color("#1c1918"), Color("#2e2a28"), 0.0, 0.85), 12, 0.42, 0.55, Vector3(0, 1.0, 0.42))
	return _close(head, core, wings, legs[0], legs[1], [tail], jaw, 1.15)
