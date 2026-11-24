extends "res://tools/creature_kit.gd"
## The Mourning Knight of Hollowmourn, sculpted by hand: a knight's armour with no one inside,
## still keeping its vigil, hung with torn violet cloth and carrying a long blade; it pauses in a
## guard you can read before it cuts.
##
## Built from the real thing. A knight's harness, head to foot: a helm (the flat-topped great
## helm of the crusades, the sallet with its long tail, or the visored armet), a bevor or gorget
## at the throat, a breastplate with a plackart over the belly, a skirt of fauld lames and the
## tassets hanging over the thighs, mail where plate can't reach (the armpits, the groin, the
## old hauberk), pauldrons over the shoulders, rerebraces, couters with fans at the elbows,
## vambraces, gauntlets with flared cuffs, cuisses, poleyns with fans at the knees, greaves and
## overlapping sabatons. Over it a surcoat or tabard bearing the knight's arms, and a cloak.
##
## Weapons are held the way the fencing books show: the grip runs through the closed fist, the
## fingers wrapped round it with the index by the crossguard and the pommel below the little
## finger, the thumb closing over; the blade leaves the hand on the thumb side with its edges
## in line with the knuckles, and the crossguard lies along the edges. A heater shield hangs on
## the left forearm by its straps (enarmes) with the fist closed on the inner strap, its face
## turned out.
##
##   crusader - a knight of about 1250: a flat-topped great helm with a brass cross and
##              breathing holes, a mail hauberk, a long violet surcoat strewn with silver tears
##              (gouttes de larmes, the heralds' sign of mourning), a heater shield black with
##              silver tears, and an arming sword held in a middle guard, point to the foe
##   gothic   - German Gothic plate of about 1480: fluted plates with cusped brass edges, a
##              sallet with a long tail and a bevor, long pointed sabatons, a torn violet tabard
##              and cloak; it keeps vigil with its greatsword point-down before it, both hands
##              resting on the hilt, as knights stood watch over the dead
##   blackknight - a knight of about 1500 in black plate: a visored armet with a rondel at the
##              back and a tall plume of black and violet feathers, a tabard bearing a mourning
##              hatchment, an empty scabbard at the hip, and the longsword carried on the
##              shoulder

##
## The same harness also makes the Blackthorn Regent, the haunted king of Blackthorn Keep (a
## boss): an antler-crowned suit of royal armour carrying a lantern in one hand and a great
## sword in the other, a royal mantle behind it. Three designs:
##   royal  - parade armour of a king about 1510 (like the Emperor Maximilian's), blackened
##            and etched with gold, a close helmet with a pointed visor under a gold crown from
##            which a stag's antlers branch, a purple mantle with an ermine tippet, a tabard of
##            the royal arms, a lantern of iron and horn
##   thorn  - the same king grown through with blackthorn (Prunus spinosa): thorny black
##            branches wound round every limb, its white blossom and blue-black sloes, antlers
##            that are themselves blackthorn branches, a cloak gone to moss and rags, and a
##            will-o'-the-wisp in its lantern
##   crest  - a king as the Codex Manesse paints them at the tournament: a great helm crowned,
##            with a stag's antlers rising from it as its crest, a royal surcoat and a long
##            cloak

const VIOLET := Color("#b48aff")

var kind := "crusader"
var cloth_mat: StandardMaterial3D
var mail_mat: StandardMaterial3D
var fire_mat: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = null
	material.metallic = 0.4; material.roughness = 0.4
	cloth_mat = StandardMaterial3D.new()
	cloth_mat.vertex_color_use_as_albedo = true; cloth_mat.vertex_color_is_srgb = true
	cloth_mat.albedo_texture = load("res://assets/cast/cloth_color.png")
	cloth_mat.uv1_triplanar = true; cloth_mat.uv1_scale = Vector3(3, 3, 3)
	cloth_mat.roughness = 0.92; cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mail_mat = StandardMaterial3D.new()
	mail_mat.vertex_color_use_as_albedo = true
	mail_mat.metallic = 0.6; mail_mat.roughness = 0.5
	glow.albedo_color = VIOLET.darkened(0.2); glow.emission = VIOLET; glow.emission_energy_multiplier = 2.4
	fire_mat = StandardMaterial3D.new()
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "MourningKnight"
	kind = variant
	if not variant in ["crusader", "gothic", "blackknight", "royal", "thorn", "crest"]: return null
	if variant == "royal" or variant == "crest": glow.albedo_color = Color("#ffe6a0").darkened(0.2); glow.emission = Color("#ffe0a0")
	if variant == "thorn": glow.albedo_color = Color("#b8ff9a").darkened(0.2); glow.emission = Color("#a8ff8a")
	return _knight()


# ------------------------------------------------------------------ painters

static func steel(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var c := Color("#2a2c33").lerp(Color("#80848e"), clampf(n.y * 0.3 + 0.35 + Sculpt.fbm(p * 6.0) * 0.25, 0.0, 1.0))
	c = c.lerp(Color("#c8ccd6"), clampf(w, 0.0, 1.0) * 0.5)
	return c.lerp(Color("#5a3a22"), smoothstep(0.68, 0.8, Sculpt.noise(p * 17.0)) * 0.3)


static func black_steel(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	return steel(p, n, v, w).darkened(0.55).lerp(Color("#2a2434"), 0.15)


static func ghost_fire(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	var a := (1.0 - v) * (0.55 + 0.3 * Sculpt.noise(p * 12.0))
	return Color(0.62 * a, 0.4 * a, 1.0 * a, 1.0)


## Horn: near-black, ridged, paling to dull bone at the tip.
static func horn(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0e0c10").lerp(Color("#3a3238"), clampf(n.y * 0.3 + 0.3 + smoothstep(0.6, 0.95, sin(v * 60.0)) * 0.4, 0.0, 1.0))
	return c.lerp(Color("#8a7e6e"), smoothstep(0.6, 1.0, v) * 0.6)


## Blackened steel etched in bands of gold, the way the royal armourers decorated parade armour.
static func gilt_black(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var c := black_steel(p, n, v, w)
	var band := smoothstep(0.9, 0.95, fposmod(p.y * 7.0 + 0.3 * sin(p.x * 20.0 + p.z * 20.0), 1.0))
	var scroll := smoothstep(0.78, 0.86, Sculpt.noise(p * 26.0)) * smoothstep(0.7, 0.95, fposmod(p.y * 9.0, 1.0))
	return c.lerp(Color("#a8843e"), clampf(band + scroll * 0.6, 0.0, 1.0) * 0.7)


## Ermine: white fur dotted with the black tail-tips, as on royal robes.
static func ermine(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#d8d4cc").lerp(Color("#f6f4ee"), clampf(n.y * 0.3 + 0.5 + Sculpt.noise(p * 40.0) * 0.2, 0.0, 1.0))
	var cell := Vector2(fposmod(p.x * 14.0 + p.z * 14.0 + floorf(p.y * 14.0) * 0.5, 1.0) - 0.5, fposmod(p.y * 14.0, 1.0) - 0.5)
	return Color("#111014") if cell.length() < 0.16 else c


static func royal_purple(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#1e0a24").lerp(Color("#5a1a62"), clampf(0.45 + 0.3 * sin(p.x * 36.0 + p.z * 28.0) + n.y * 0.15 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#3a2a40"), smoothstep(0.85, 1.0, v) * 0.5)


static func moss_rag(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0b0a09").lerp(Color("#24221c"), clampf(0.4 + 0.3 * sin(p.x * 30.0 + p.z * 26.0) + n.y * 0.2 + Sculpt.fbm(p * 6.0) * 0.4, 0.0, 1.0))
	c = c.lerp(Color("#1e2a16"), smoothstep(0.3, 0.7, Sculpt.noise(p * 7.0) + n.y * 0.3) * 0.5)
	return c.lerp(Color("#2a241e"), smoothstep(0.7, 1.0, v) * 0.6)


## The royal arms: quarterly sable and or (black and gold).
static func royal_arms(p: Vector3, n: Vector3, v: float, w: float) -> Color:
	var gold_q := (p.x > 0.0) == (p.y > 1.05)
	var c := Color("#6e5016") if gold_q else Color("#141218")
	return c.darkened(clampf(-n.y * 0.2 + smoothstep(0.85, 1.0, v) * 0.4, 0.0, 0.6))


static func brass(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#5a4422").lerp(Color("#b8924e"), clampf(n.y * 0.4 + 0.45 + Sculpt.noise(p * 20.0) * 0.2, 0.0, 1.0))


static func leather(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#1e1410").lerp(Color("#4a3226"), clampf(n.y * 0.3 + 0.4 + Sculpt.noise(p * 30.0) * 0.3, 0.0, 1.0))


## Mail: rows of small rings catching the light.
static func mail(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var rows := absf(sin(p.y * 150.0 + sin((p.x + p.z) * 150.0) * 1.3))
	return Color("#1e2024").lerp(Color("#8c9098"), smoothstep(0.35, 0.95, rows) * clampf(0.6 + n.y * 0.3, 0.2, 1.0))


static func violet_cloth(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#22142c").lerp(Color("#5e3676"), clampf(0.45 + 0.3 * sin(p.x * 40.0 + p.z * 31.0) + n.y * 0.15 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#6a5a70"), smoothstep(0.85, 1.0, v) * 0.4)


static func black_cloth(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0c0b10").lerp(Color("#2e2836"), clampf(0.45 + 0.3 * sin(p.x * 34.0 + p.z * 27.0) + n.y * 0.15 + Sculpt.fbm(p * 5.0) * 0.3, 0.0, 1.0))
	return c.lerp(Color("#4a3a5a"), smoothstep(0.85, 1.0, v) * 0.4)


## A field strewn with silver teardrops (gouttes de larmes), in 2D coordinates on the cloth.
static func tears(uv: Vector2, field: Color, spacing: float) -> Color:
	var row := floorf(uv.y / spacing)
	var x := uv.x + (spacing * 0.5 if int(row) % 2 != 0 else 0.0)
	var cu := fposmod(x, spacing) - spacing * 0.5
	var cv := fposmod(uv.y, spacing) - spacing * 0.5
	var r := spacing * 0.17
	var inside := Vector2(cu, cv + r * 0.6).length() < r
	if cv + r * 0.6 > 0.0 and cv < r * 1.9:
		inside = inside or absf(cu) < r * (1.0 - (cv + r * 0.6) / (r * 2.5))
	return Color("#d8dce4") if inside else field


# ------------------------------------------------------------------ pieces

## Hammered plate: faces lit flat so the armour reads as hard metal with crisp edges.
func steel_part(parent: Node3D, name: String, s: Sculpt) -> MeshInstance3D:
	s._facets.append(Vector2i(0, s._i.size()))
	return part(parent, name, s)


## A cusped (scalloped) rim round a limb, in the Gothic manner.
func rim(s: Sculpt, painter: int, c: Vector3, axis: Vector3, r: float, cusp := 8, depth := 0.0) -> void:
	var a := axis.normalized(); var u := a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized(); var v := a.cross(u)
	var ring: Array = []; var rr: Array = []
	for k in range(cusp * 2 + 1):
		var t := TAU * k / (cusp * 2.0)
		var rad := r * (1.0 if depth == 0.0 else lerpf(1.0, 1.0 / (1.0 + depth), 0.5 + 0.5 * cos(t)))
		ring.append(c + (u * cos(t) + v * sin(t)) * rad + a * (0.01 if k % 2 == 0 else -0.004)); rr.append(0.008)
	s.tube(ring, rr, painter, {"sides": 5, "per": 1})


## Torn cloth hanging from a row of points, strips of different lengths.
func drape(s: Sculpt, painter: int, tops: Array, length: float, out: Vector3, width: float, seed := 0.0, ragged := 0.45) -> void:
	for k in range(tops.size()):
		var t: Vector3 = tops[k]
		var l := length * (1.0 - ragged + ragged * fposmod(k * 0.618 + seed, 1.0))
		var sway := Vector3(0.02 * sin(k * 2.3 + seed), 0, 0.02 * cos(k * 1.7 + seed))
		var pts := [t, t + Vector3(0, -l * 0.35, 0) + out * 0.03 + sway * 0.5, t + Vector3(0, -l * 0.7, 0) + out * 0.05 + sway, t + Vector3(0, -l, 0) + out * 0.06 + sway * 1.4]
		s.tube(pts, [width, width, width * 0.95, width * 0.7], painter, {"sides": 6, "per": 2, "flat": 0.12, "side": out.normalized() if out.length() > 0.0 else Vector3.BACK, "cap1": false})


## A closed fist round a grip. The grip runs along `d` through `c`; the forearm comes in along
## `a`; the back of the hand faces `bh`. The index finger is nearest the end the blade leaves
## from (+d), the little finger nearest the pommel.
func fist(s: Sculpt, painter: int, c: Vector3, d: Vector3, a: Vector3, bh: Vector3, grip_r: float) -> void:
	var front := d.cross(bh).normalized()
	if front.dot(a) < 0.0: front = -front
	# The back of the hand: a plate over the knuckles.
	s.blob(c + bh * (grip_r + 0.022) - a * 0.01, Vector3(0.02, 0.05, 0.045), painter, {"lat": 5, "lon": 8, "basis": Basis(bh, d, bh.cross(d)).orthonormalized()})
	# Four fingers, each curled round the grip from the back of the hand to the palm.
	for k in range(4):
		var off := d * (0.03 - k * 0.022)
		var pts: Array = []; var rr: Array = []
		for j in range(6):
			var t := lerpf(0.0, PI * 1.25, j / 5.0)
			pts.append(c + off + (bh * cos(t) + front * sin(t)) * (grip_r + 0.014)); rr.append(0.0115)
		s.tube(pts, rr, painter, {"sides": 5, "per": 1})
	# The thumb closing over the fingers on the blade side.
	var tb := c + d * 0.045
	s.tube([tb + bh * (grip_r + 0.01) - a * 0.02, tb + front * (grip_r + 0.012) + bh * 0.008, tb + front * (grip_r + 0.01) - bh * (grip_r * 0.6)], [0.013, 0.012, 0.01], painter, {"sides": 5, "per": 2})
	# The heel of the hand and the wrist behind it.
	s.blob(c - a * 0.035 + bh * 0.01, Vector3(0.038, 0.045, 0.04), painter, {"lat": 5, "lon": 8})


## A sword: the grip centred on `c`, the blade along `d`, its edges along `e`.
func sword(s: Sculpt, sp: int, gp: int, bp: int, c: Vector3, d: Vector3, e: Vector3, blade: float, grip: float, width: float, wavy := false) -> void:
	var f := d.cross(e).normalized()
	var guard := c + d * (grip * 0.5 + 0.01)
	# Grip wrapped in leather, a wheel pommel below it.
	s.tube([c - d * grip * 0.5, guard - d * 0.01], [0.016, 0.017], gp, {"sides": 7, "per": 1})
	var pom := c - d * (grip * 0.5 + 0.025)
	s.tube([pom - f * 0.016, pom + f * 0.016], [0.034, 0.034], bp, {"sides": 10, "per": 1})
	s.blob(pom - d * 0.025, Vector3.ONE * 0.012, bp, {"lat": 4, "lon": 6})
	# The crossguard lying along the edges, its ends turned slightly toward the blade.
	var q := 0.07 + width * 0.8
	s.tube([guard - e * q + d * 0.02, guard - e * q * 0.5, guard, guard + e * q * 0.5, guard + e * q + d * 0.02], [0.012, 0.014, 0.016, 0.014, 0.012], bp, {"sides": 6, "per": 2})
	# The blade: a long flattened diamond, tapering to the point, a dark fuller down its middle.
	var tip := guard + d * blade
	if wavy:
		# A flamberge: the blade's edges rippling like a flame all the way to the point.
		var pts: Array = []; var rr: Array = []
		for k in range(25):
			var t := k / 24.0
			pts.append(guard + d * (0.01 + blade * t) + e * width * 0.22 * sin(t * TAU * 5.5) * smoothstep(0.08, 0.2, t) * (1.0 - t * 0.6))
			rr.append(width * lerpf(0.55, 0.32, t) * (1.0 - smoothstep(0.9, 1.0, t)) + 0.002)
		s.tube(pts, rr, sp, {"sides": 4, "per": 1, "flat": 0.16, "side": f, "cap1": false})
	else:
		s.tube([guard + d * 0.01, guard + d * blade * 0.5, guard + d * blade * 0.88, tip], [width * 0.5, width * 0.43, width * 0.3, 0.002], sp, {"sides": 4, "per": 3, "flat": 0.16, "side": f, "cap1": false})
	var fuller := s.add_painter(func (p, n, v, w): return Color("#16171c"))
	for sgn: float in [-1.0, 1.0]:
		s.tube([guard + d * 0.03 + f * sgn * width * 0.075, guard + d * blade * 0.6 + f * sgn * width * 0.06], [width * 0.09, width * 0.05], fuller, {"sides": 4, "per": 1, "flat": 0.3, "side": f})


## A heater shield: flat-topped, its sides curving to a point, a little convex. Centred on `c`,
## facing `nrm`, with `up` along its height; `paint` gets the 2D point on its face.
func heater(s: Sculpt, c: Vector3, nrm: Vector3, up: Vector3, w: float, h: float, paint: Callable, rim_p: int) -> void:
	var n := nrm.normalized(); var u := up.normalized(); var r := u.cross(n).normalized()
	var face := s.add_painter(func (p: Vector3, nn: Vector3, v: float, ww: float) -> Color:
		var q := p - c
		return paint.call(Vector2(q.dot(r), q.dot(u))))
	var back := s.add_painter(leather)
	var outline := func (yy: float) -> float:
		var t := clampf((yy + h * 0.5) / h, 0.0, 1.0)
		return w * 0.5 * (1.0 if t > 0.45 else sqrt(1.0 - pow((0.45 - t) / 0.45, 2.0)) * 0.98 + 0.02)
	for layer in [0, 1]:
		var base := s._v.size()
		var nu := 14; var nv := 18
		for j in range(nv + 1):
			var yy := lerpf(-h * 0.5, h * 0.5, j / float(nv))
			var half: float = outline.call(yy)
			for i in range(nu + 1):
				var xx := lerpf(-half, half, i / float(nu))
				var bulge := 0.05 * (1.0 - pow(xx / (w * 0.5), 2.0))
				var p := c + r * xx + u * yy + n * (bulge + (0.012 if layer == 0 else -0.004))
				s._v.append(p); s._along.append(0.0); s._ridge.append(0.0); s._painter.append(face if layer == 0 else back)
		for j in range(nv):
			for i in range(nu):
				var a := base + j * (nu + 1) + i; var b := a + nu + 1
				if layer == 0: s._i.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
				else: s._i.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	# A steel rim round the edge.
	var ring: Array = []; var rr: Array = []
	for k in range(25):
		var t := k / 24.0
		var yy: float; var xx: float
		if t < 0.5:
			yy = lerpf(h * 0.5, -h * 0.5, t * 2.0); xx = outline.call(yy)
		else:
			yy = lerpf(-h * 0.5, h * 0.5, (t - 0.5) * 2.0); xx = -outline.call(yy)
		ring.append(c + r * xx + u * yy + n * 0.006); rr.append(0.012)
	ring.append(ring[0])
	rr.append(0.012)
	s.tube(ring, rr, rim_p, {"sides": 5, "per": 1})


## A sheet of cloth hanging from `tops`: column i drops `lens[i]`, and stands off the body along
## `outs[i]` by `offset(i, t, y)`. Faces are turned to look outward.
func cloth_sheet(s: Sculpt, painter: int, tops: Array, outs: Array, lens: Array, offset: Callable, rows := 14) -> void:
	var base := s._v.size()
	var nc := tops.size()
	for i in range(nc):
		var top: Vector3 = tops[i]; var o: Vector3 = outs[i]; var l: float = lens[i]
		for j in range(rows + 1):
			var t := j / float(rows)
			var yy := top.y - l * t
			var wave := 0.012 * sin(i * 1.9 + t * 5.0) * t
			var p := top + Vector3(0, -l * t, 0) + o * (float(offset.call(i, t, yy)) + wave)
			s._v.append(p); s._along.append(t); s._ridge.append(0.0); s._painter.append(painter)
	for i in range(nc - 1):
		var o: Vector3 = (outs[i] as Vector3) + (outs[i + 1] as Vector3)
		for j in range(rows):
			var a := base + i * (rows + 1) + j; var b := a + rows + 1
			var pa: Vector3 = s._v[a]; var pb: Vector3 = s._v[b]; var pc: Vector3 = s._v[a + 1]
			var nrm := (pc - pa).cross(pb - pa)
			if nrm.dot(o) >= 0.0: s._i.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
			else: s._i.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))


## A cloak hung round the back from shoulder to shoulder, flaring as it falls, torn at the hem.
func cloak(s: Sculpt, painter: int, r: float, top_y: float, length: float, spread: float, ragged: float) -> void:
	var tops: Array = []; var outs: Array = []; var lens: Array = []
	var n := 18
	for k in range(n + 1):
		var a := lerpf(-spread, spread, k / float(n))
		tops.append(Vector3(sin(a) * r, top_y, 0.04 + cos(a) * r * 0.55))
		outs.append(Vector3(sin(a), 0, cos(a)).normalized())
		lens.append(length * (1.0 - ragged * fposmod(k * 0.618 + 0.3, 1.0)) * (1.0 - 0.25 * pow(absf(a) / spread, 2.0)))
	cloth_sheet(s, painter, tops, outs, lens, func (i: int, t: float, yy: float) -> float: return 0.02 + 0.14 * t * t, 16)


## A blackthorn branch along `path`: black bark, long spines, white five-petalled blossom and
## blue-black sloes.
func blackthorn(s: Sculpt, path: Array, thick: float, flowers := 3) -> void:
	var bark := s.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#0e0b0a").lerp(Color("#2e2622"), clampf(n.y * 0.3 + 0.3 + Sculpt.noise(p * 40.0) * 0.3, 0.0, 1.0)))
	var spine := s.add_painter(func (p, n, v, w): return Color("#120e0c").lerp(Color("#6a5a4a"), v))
	var bl := s.add_painter(func (p, n, v, w): return Color("#f4f0e8").lerp(Color("#e8c8d0"), clampf(1.0 - n.y, 0.0, 1.0) * 0.3))
	var sl := s.add_painter(func (p, n, v, w): return Color("#141830").lerp(Color("#6a7aa8"), clampf(n.y * 0.5 + 0.2, 0.0, 1.0)))
	var rr: Array = []
	for k in range(path.size()): rr.append(thick * (1.0 - 0.4 * k / float(path.size())))
	s.tube(path, rr, bark, {"sides": 6, "per": 2, "lump": 0.25})
	for k in range(1, path.size() - 1):
		var a: Vector3 = path[k]; var d: Vector3 = ((path[k + 1] as Vector3) - (path[k - 1] as Vector3)).normalized()
		var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized().rotated(d, k * 2.4)
		s.crystal(a, (side + d * 0.3).normalized(), thick * 3.5, thick * 0.5, spine, 4)
	for q in range(flowers):
		var at: Vector3 = path[1 + (q * 3) % maxi(path.size() - 2, 1)]
		for pt in range(5):
			var a := TAU * pt / 5.0
			s.blob(at + Vector3(cos(a) * 0.013, 0.012, sin(a) * 0.013), Vector3(0.011, 0.004, 0.011), bl, {"lat": 3, "lon": 5})
		var sa: Vector3 = path[(q * 3 + 2) % path.size()]
		s.blob(sa + Vector3(0, -0.014, 0), Vector3.ONE * 0.015, sl, {"lat": 4, "lon": 6})


## A gnarled blackthorn branch growing from `start` along `dir`, bending as it goes, studded with
## long spines, forking `depth` more times, white blossom and blue-black sloes at its tips.
## `rise` pulls it upward (negative to droop); `ground` keeps it lying along the ground.
func thorn_branch(s: Sculpt, start: Vector3, dir: Vector3, length: float, thick: float, depth: int, seed: float, rise := 0.08, ground := false) -> void:
	if not has_meta("tb_paint") or (get_meta("tb_sculpt") as Object) != s:
		var bark := s.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var c := Color("#0c0908").lerp(Color("#2e2420"), clampf(n.y * 0.25 + 0.3 + Sculpt.noise(p * 50.0) * 0.35, 0.0, 1.0))
			return c.lerp(Color("#4a5a3a"), smoothstep(0.72, 0.9, Sculpt.noise(p * 17.0)) * 0.5))
		var spine := s.add_painter(func (p, n, v, w): return Color("#100c0a").lerp(Color("#9a8a72"), v * v))
		var petal := s.add_painter(func (p, n, v, w): return Color("#e6e0d6").lerp(Color("#fffcf6"), clampf(n.y, 0.0, 1.0)))
		var heart := s.add_painter(func (p, n, v, w): return Color("#c8a040"))
		var sloe := s.add_painter(func (p, n, v, w): return Color("#10142a").lerp(Color("#7a88b8"), clampf(n.y * 0.6 + 0.1, 0.0, 1.0)))
		set_meta("tb_paint", [bark, spine, petal, heart, sloe]); set_meta("tb_sculpt", s)
	var P: Array = get_meta("tb_paint")
	var pts: Array = []; var rr: Array = []
	var d := dir.normalized(); var p := start
	var n := 7
	for k in range(n + 1):
		var t := k / float(n)
		pts.append(p); rr.append(lerpf(thick, thick * 0.22, t))
		var wob := Vector3(sin(seed * 3.1 + k * 1.7), cos(seed * 2.3 + k * 2.1) * (0.15 if ground else 0.6), sin(seed * 1.3 + k * 2.9))
		d = (d + wob * 0.38 + Vector3(0, rise, 0)).normalized()
		if ground: d.y = clampf(d.y, -0.05, 0.12); d = d.normalized()
		p += d * length / n
		if ground: p.y = maxf(p.y, 0.012)
	s.tube(pts, rr, P[0], {"sides": 6, "per": 1, "lump": 0.3, "cap1": false})
	# Knots where it bends, and long spines off every side (blackthorn's spines are short
	# side-shoots grown into points).
	for k in range(1, n):
		var a: Vector3 = pts[k]; var dd: Vector3 = ((pts[k + 1] as Vector3) - (pts[k - 1] as Vector3)).normalized()
		var sd := dd.cross(Vector3.UP if absf(dd.y) < 0.9 else Vector3.RIGHT).normalized().rotated(dd, seed + k * 2.4)
		s.crystal(a, (sd + dd * 0.35).normalized(), float(rr[k]) * 2.2 + 0.03, float(rr[k]) * 0.45, P[1], 4)
		if k % 3 == 1: s.blob(a, Vector3.ONE * float(rr[k]) * 1.35, P[0], {"lat": 4, "lon": 6, "lump": 0.3})
	if depth > 0:
		for b in range(1 if depth == 1 and fposmod(seed, 3.0) < 1.0 else 2):
			var k := 2 + b * 2 + int(fposmod(seed, 2.0))
			var at: Vector3 = pts[mini(k, n - 1)]
			var dd: Vector3 = ((pts[mini(k + 1, n)] as Vector3) - at).normalized()
			var sd := dd.cross(Vector3.UP if absf(dd.y) < 0.9 else Vector3.RIGHT).normalized().rotated(dd, seed * 1.7 + b * PI)
			thorn_branch(s, at, (dd + sd * 0.9).normalized(), length * 0.55, float(rr[k]) * 0.85, depth - 1, seed * 1.37 + b * 5.1 + 1.0, rise, ground)
	# Blossom at the tip, and a sloe hanging below it.
	var tip: Vector3 = pts[n]
	if not ground and depth == 0 and fposmod(seed * 7.3, 2.0) < 1.2:
		for f in range(1):
			var fc := tip + Vector3(0.02 * sin(seed + f * 2.0), 0.012 + 0.01 * f, 0.02 * cos(seed + f * 2.0))
			for pt in range(5):
				var a := TAU * pt / 5.0 + seed
				s.blob(fc + Vector3(cos(a) * 0.016, 0.0, sin(a) * 0.016), Vector3(0.014, 0.005, 0.014), P[2], {"lat": 3, "lon": 5})
			s.blob(fc + Vector3(0, 0.004, 0), Vector3.ONE * 0.006, P[3], {"lat": 3, "lon": 4})
	if not ground and depth == 0 and fposmod(seed * 5.1, 3.0) < 1.0:
		var mid: Vector3 = pts[n - 2]
		s.tube([mid, mid + Vector3(0, -0.04, 0)], [0.003, 0.003], P[0], {"sides": 4, "per": 1})
		s.blob(mid + Vector3(0, -0.055, 0), Vector3(0.02, 0.022, 0.02), P[4], {"lat": 5, "lon": 7})


# ------------------------------------------------------------------ the knight

func _knight() -> Node3D:
	var crusader := kind == "crusader"; var gothic := kind == "gothic"; var black := kind == "blackknight"
	var regent := kind in ["royal", "thorn", "crest"]
	var plate_paint: Callable = black_steel if black else steel
	if kind == "royal": plate_paint = gilt_black
	if kind == "thorn": plate_paint = func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		# Old iron left out for a century: near-black, rusted through in patches, moss in the hollows.
		var c := steel(p, n, v, w).darkened(0.55)
		c = c.lerp(Color("#4a2414"), smoothstep(0.55, 0.78, Sculpt.noise(p * 7.0)) * 0.6)
		c = c.lerp(Color("#6a3a1a"), smoothstep(0.7, 0.85, Sculpt.noise(p * 23.0)) * 0.3)
		return c.lerp(Color("#1a2212"), smoothstep(0.65, 0.95, n.y * 0.6 + Sculpt.noise(p * 11.0) * 0.5) * 0.3)
	var fl := 9 if gothic else 0

	# ---- torso
	var body := Sculpt.new(); var sp := body.add_painter(plate_paint); var bp := body.add_painter(brass)
	var dark := body.add_painter(func (p, n, v, w): return Color("#040306"))
	var ms := Sculpt.new(); var mp := ms.add_painter(mail)
	if crusader:
		# A mail hauberk to the knees with a coif over the head, belted at the waist.
		ms.tube([Vector3(0, 0.56, 0.0), Vector3(0, 0.88, 0.0), Vector3(0, 1.04, 0.0), Vector3(0, 1.3, -0.02), Vector3(0, 1.46, 0.0)], [0.25, 0.2, 0.16, 0.21, 0.18], mp, {"sides": 18, "per": 3, "side": Vector3.BACK, "flat": 0.68, "cap0": false})
		ms.tube([Vector3(0, 1.44, 0.0), Vector3(0, 1.52, 0.0)], [0.17, 0.1], mp, {"sides": 14, "per": 1, "side": Vector3.BACK, "flat": 0.8})
	else:
		# Plate: the breastplate swelling at the chest with a ridge down its middle, the plackart
		# rising to a point over the belly, the fauld's lames flaring over the hips.
		var tp := [Vector3(0, 1.0, 0.0), Vector3(0, 1.12, -0.01), Vector3(0, 1.3, -0.02), Vector3(0, 1.45, 0.0)]
		var o := {"sides": 18, "per": 3, "side": Vector3.BACK, "flat": 0.62}
		if gothic: o["ridges"] = fl; o["ridge"] = 0.06
		body.tube(tp, [0.15, 0.17, 0.215, 0.19], sp, o)
		body.blob(Vector3(0, 1.3, -0.06), Vector3(0.19, 0.13, 0.11), sp, {"lat": 8, "lon": 12})
		body.tube([Vector3(0, 1.03, -0.115), Vector3(0, 1.24, -0.165), Vector3(0, 1.42, -0.14)], [0.01, 0.014, 0.01], sp, {"sides": 5, "per": 2})
		body.blob(Vector3(0, 1.08, -0.09), Vector3(0.145, 0.1, 0.045), sp, {"lat": 6, "lon": 10, "basis": Basis(Vector3.RIGHT, 0.15)})
		body.crystal(Vector3(0, 1.12, -0.12), Vector3(0, 1, -0.2), 0.13, 0.045, sp, 4)
		if gothic:
			rim(body, bp, Vector3(0, 1.17, -0.11), Vector3(0, 0.3, -1), 0.06, 5)
		for k in range(4):
			var yy := 0.97 - k * 0.045
			body.tube([Vector3(0, yy + 0.025, 0), Vector3(0, yy - 0.025, 0)], [0.162 + k * 0.014, 0.17 + k * 0.014], sp, {"sides": 18, "per": 1, "side": Vector3.BACK, "flat": 0.72})
			if gothic: rim(body, bp, Vector3(0, yy - 0.026, 0), Vector3.UP, 0.172 + k * 0.014, 12, 0.35)
		# Tassets over the thighs.
		for side: float in [-1.0, 1.0]:
			for k in range(3):
				slab(body, sp, Vector3(0.1 * side, 0.8 - k * 0.055, -0.1 - k * 0.006), Vector3(0.15, 0.06, 0.018), Basis(Vector3.RIGHT, -0.15) * Basis(Vector3.BACK, -0.1 * side), 0.4, 0.0)
		# Mail at the groin and the armpits, where plate can't reach.
		ms.tube([Vector3(0, 0.85, 0), Vector3(0, 0.68, 0.01)], [0.17, 0.2], mp, {"sides": 16, "per": 2, "side": Vector3.BACK, "flat": 0.75, "cap1": false})
		# The gorget round the neck.
		body.tube([Vector3(0, 1.44, 0.0), Vector3(0, 1.5, 0.0), Vector3(0, 1.54, 0.0)], [0.15, 0.1, 0.085], sp, {"sides": 16, "per": 1, "side": Vector3.BACK, "flat": 0.85})
	# A sword belt slung low round the hips with a brass buckle.
	var belt := body.add_painter(leather)
	body.tube([Vector3(0, 0.98 if crusader else 0.9, 0), Vector3(0, 0.96 if crusader else 0.88, 0)], [0.185 if crusader else 0.21, 0.19 if crusader else 0.215], belt, {"sides": 18, "per": 1, "side": Vector3.BACK, "flat": 0.72})
	body.blob(Vector3(0, 0.97 if crusader else 0.89, -0.15), Vector3(0.03, 0.025, 0.012), bp, {"lat": 4, "lon": 6})
	body.blob(Vector3(0, 1.5, 0.0), Vector3(0.06, 0.03, 0.06), dark, {"lat": 4, "lon": 8})
	if black:
		# The breastplate embossed as a ribcage, ghost-light glowing between the ribs.
		var rb := Sculpt.new(); var rbg := rb.add_painter(func (p, n, v, w): return Color.WHITE)
		for k in range(5):
			var yy := 1.38 - k * 0.055
			for side: float in [-1.0, 1.0]:
				var pts: Array = []; var rr: Array = []
				for j in range(6):
					var a := lerpf(0.08, 1.25, j / 5.0)
					pts.append(Vector3(sin(a) * (0.2 - k * 0.008) * side, yy - 0.04 * sin(a) - 0.01 * j, -cos(a) * 0.175 - 0.005)); rr.append(0.011 - j * 0.001)
				body.tube(pts, rr, sp, {"sides": 5, "per": 2})
				var gl: Array = []
				for q in pts: gl.append((q as Vector3) + Vector3(0, -0.027, 0.004))
				rb.tube(gl, [0.004, 0.004, 0.004, 0.004, 0.003, 0.002], rbg, {"sides": 4, "per": 1})
		body.tube([Vector3(0, 1.41, -0.18), Vector3(0, 1.17, -0.185)], [0.016, 0.012], sp, {"sides": 5, "per": 2})
		var dim := glow.duplicate() as StandardMaterial3D
		dim.emission_energy_multiplier = 0.9; dim.albedo_color = Color("#5a3a8a")
		part(root, "RibGlow", rb, dim).material_override = dim
	steel_part(root, "Body", body)
	if ms.triangles() > 0: part(root, "Mail", ms, mail_mat)

	# ---- the helm, with nothing in it but two violet lights
	var head := joint(root, "Head", Vector3(0, 1.55, 0.0))
	var hs := Sculpt.new(); var hp := hs.add_painter(plate_paint); var hb := hs.add_painter(brass); var hd := hs.add_painter(func (p, n, v, w): return Color("#040306"))
	var eyes: Array = []
	var hy := 1.68
	match kind:
		"crusader", "crest":
			# A great helm: a tall flat-topped barrel with a brass cross over the face, a pair of
			# eye-slits either side of it, and breathing holes on the right cheek.
			hs.tube([Vector3(0, 1.52, 0.0), Vector3(0, 1.66, -0.005), Vector3(0, 1.8, 0.0)], [0.13, 0.135, 0.125], hp, {"sides": 16, "per": 3, "flat": 0.92, "cap1": false})
			hs.lathe(Vector3(0, 1.8, 0), [Vector2(0.125, 0.0), Vector2(0.07, 0.025), Vector2(0.0, 0.03)], hp, {"sides": 16, "basis": Basis.from_scale(Vector3(1, 1, 0.92))})
			hs.tube([Vector3(0, 1.79, -0.125), Vector3(0, 1.6, -0.135), Vector3(0, 1.53, -0.128)], [0.016, 0.018, 0.016], hb, {"sides": 5, "per": 2})
			hs.tube([Vector3(-0.115, 1.7, -0.07), Vector3(0, 1.7, -0.14), Vector3(0.115, 1.7, -0.07)], [0.013, 0.015, 0.013], hb, {"sides": 5, "per": 3})
			for side: float in [-1.0, 1.0]:
				hs.tube([Vector3(0.025 * side, 1.672, -0.128), Vector3(0.1 * side, 1.672, -0.09)], [0.009, 0.007], hd, {"sides": 4, "per": 2})
				eyes.append(Vector3(0.05 * side, 1.672, -0.12))
			for k in range(9): hs.blob(Vector3(0.045 + (k % 3) * 0.025, 1.6 - (k / 3) * 0.025, -0.124 + (k % 3) * 0.012), Vector3.ONE * 0.006, hd, {"lat": 3, "lon": 4})
			# The mail coif showing below the helm, over the shoulders.
			var cs := Sculpt.new(); var cp := cs.add_painter(mail)
			cs.tube([Vector3(0, 1.56, 0.0), Vector3(0, 1.47, 0.0)], [0.14, 0.2], cp, {"sides": 16, "per": 1, "side": Vector3.BACK, "flat": 0.85, "cap0": false})
			part(head, "Coif", cs, mail_mat)
		"royal", "thorn":
			# A close helmet: a rounded skull, a visor drawn forward to a point like a sparrow's
			# beak with a sight-slit across it, a bevor rising over the chin, a gorget below.
			hs.blob(Vector3(0, hy + 0.01, 0.01), Vector3(0.125, 0.135, 0.145), hp, {"lat": 10, "lon": 16})
			hs.tube([Vector3(0, hy + 0.14, -0.06), Vector3(0, hy + 0.155, 0.04), Vector3(0, hy + 0.11, 0.15)], [0.011, 0.014, 0.011], hp, {"sides": 5, "per": 2})
			for side: float in [-1.0, 1.0]:
				slab(hs, hp, Vector3(0.05 * side, hy - 0.01, -0.105), Vector3(0.1, 0.12, 0.014), Basis(Vector3.UP, -0.5 * side) * Basis(Vector3.RIGHT, -0.15), 0.3, 0.0)
				eyes.append(Vector3(0.042 * side, hy + 0.028, -0.14))
			hs.tube([Vector3(-0.1, hy + 0.03, -0.09), Vector3(0, hy + 0.028, -0.152), Vector3(0.1, hy + 0.03, -0.09)], [0.009, 0.011, 0.009], hd, {"sides": 5, "per": 3})
			for k in range(5): hs.tube([Vector3(0.012 + k * 0.012, hy - 0.03 - k * 0.012, -0.145 + k * 0.008), Vector3(0.05 + k * 0.01, hy - 0.035 - k * 0.012, -0.12 + k * 0.006)], [0.004, 0.004], hd, {"sides": 4, "per": 1})
			hs.blob(Vector3(0, hy - 0.1, -0.04), Vector3(0.12, 0.075, 0.11), hp, {"lat": 7, "lon": 12})
		"gothic":
			# A sallet: a deep rounded bowl drawn out behind into a long tail, a low comb on top,
			# a sight cut across the front; the bevor rising over the chin to meet it.
			hs.blob(Vector3(0, hy + 0.01, 0.0), Vector3(0.13, 0.12, 0.15), hp, {"lat": 10, "lon": 16})
			hs.tube([Vector3(0, hy - 0.03, 0.06), Vector3(0, hy - 0.08, 0.2), Vector3(0, hy - 0.11, 0.3)], [0.125, 0.12, 0.085], hp, {"sides": 16, "per": 3, "flat": 0.25, "side": Vector3(0, 1, 0.35).normalized()})
			hs.tube([Vector3(0, hy + 0.12, -0.11), Vector3(0, hy + 0.135, 0.0), Vector3(0, hy + 0.1, 0.16)], [0.008, 0.011, 0.008], hp, {"sides": 5, "per": 2})
			hs.tube([Vector3(-0.105, hy + 0.0, -0.08), Vector3(0, hy - 0.005, -0.145), Vector3(0.105, hy + 0.0, -0.08)], [0.011, 0.012, 0.011], hd, {"sides": 5, "per": 3})
			for side: float in [-1.0, 1.0]: eyes.append(Vector3(0.045 * side, hy - 0.004, -0.135))
			hs.blob(Vector3(0, hy - 0.1, -0.05), Vector3(0.125, 0.085, 0.115), hp, {"lat": 7, "lon": 12})
			hs.blob(Vector3(0, hy - 0.06, -0.12), Vector3(0.09, 0.04, 0.05), hp, {"lat": 5, "lon": 9})
			rim(hs, hb, Vector3(0, hy - 0.04, -0.07), Vector3(0, 1, 0.2), 0.12, 10, 0.25)
		"blackknight":
			# A visored armet: a rounded skull, a visor drawn to a blunt point in front with a
			# sight slit and breaths, cheek-plates meeting at the chin, a rondel on a stem behind.
			hs.blob(Vector3(0, hy + 0.01, 0.01), Vector3(0.125, 0.135, 0.145), hp, {"lat": 10, "lon": 16})
			hs.tube([Vector3(0, hy + 0.15, -0.07), Vector3(0, hy + 0.16, 0.04), Vector3(0, hy + 0.11, 0.15)], [0.012, 0.015, 0.012], hp, {"sides": 5, "per": 2})
			# A grotesque visor (Henry VIII's horned helmet of 1512 wore a face like this): two
			# angled plates meeting in a sharp prow, slanted eye-slits glaring down toward the
			# middle, and a black mouth hung with iron fangs.
			for side: float in [-1.0, 1.0]:
				slab(hs, hp, Vector3(0.052 * side, hy - 0.025, -0.11), Vector3(0.105, 0.17, 0.016), Basis(Vector3.UP, -0.62 * side) * Basis(Vector3.RIGHT, 0.12), 0.25, 0.0)
				hs.tube([Vector3(0.016 * side, hy - 0.004, -0.152), Vector3(0.05 * side, hy + 0.012, -0.135), Vector3(0.088 * side, hy + 0.03, -0.11)], [0.011, 0.012, 0.008], hd, {"sides": 5, "per": 2})
				eyes.append(Vector3(0.05 * side, hy + 0.012, -0.14))
				hs.tube([Vector3(0.02 * side, hy + 0.03, -0.158), Vector3(0.1 * side, hy + 0.065, -0.105)], [0.013, 0.009], hp, {"sides": 5, "per": 1})
			hs.tube([Vector3(0, hy + 0.07, -0.145), Vector3(0, hy - 0.02, -0.168), Vector3(0, hy - 0.115, -0.15)], [0.012, 0.015, 0.01], hp, {"sides": 5, "per": 2})
			hs.blob(Vector3(0, hy - 0.075, -0.142), Vector3(0.06, 0.018, 0.018), hd, {"lat": 4, "lon": 8})
			for k in range(8):
				var x := -0.05 + k * (0.1 / 7.0)
				var l := 0.05 if k == 1 or k == 6 else 0.025
				hs.crystal(Vector3(x, hy - 0.062, -0.15 + absf(x) * 0.4), Vector3(0, -1, -0.15), l, 0.006, hp, 3)
			hs.blob(Vector3(0, hy - 0.11, -0.03), Vector3(0.115, 0.07, 0.11), hp, {"lat": 7, "lon": 12})
			hs.tube([Vector3(0, hy - 0.05, 0.13), Vector3(0, hy - 0.07, 0.2)], [0.012, 0.01], hp, {"sides": 5, "per": 1})
			hs.tube([Vector3(0, hy - 0.07, 0.195), Vector3(0, hy - 0.07, 0.215)], [0.05, 0.05], hp, {"sides": 12, "per": 1, "flat": 0.2, "side": Vector3.BACK})
	steel_part(head, "Helm", hs)
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for e: Vector3 in eyes:
		if black:
			var sd := signf(e.x)
			es.tube([Vector3(0.02 * sd, hy - 0.002, -0.15), Vector3(0.05 * sd, hy + 0.012, -0.136), Vector3(0.082 * sd, hy + 0.027, -0.113)], [0.006, 0.007, 0.004], ew, {"sides": 5, "per": 2})
		else: es.blob(e, Vector3(0.016, 0.008, 0.006), ew, {"lat": 4, "lon": 6})
	var core := part(head, "GhostEyes", es, glow); core.material_override = glow
	if regent:
		# A gold crown round the helm, and a stag's antlers branching up out of it (for the
		# thorn-grown king, blackthorn branches in their place).
		var cr := Sculpt.new(); var gp := cr.add_painter(brass if kind != "thorn" else func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return brass(p, n, v, w).darkened(0.5).lerp(Color("#3e7a5e"), smoothstep(-0.1, 0.35, Sculpt.noise(p * 14.0)) * 0.75)); var jp := cr.add_painter(func (p, n, v, w): return Color("#7a1a3a").lightened(clampf(n.y, 0.0, 1.0) * 0.3))
		var ctop := hy + (0.12 if kind == "crest" else 0.1)
		var cr_r := 0.14 if kind == "crest" else 0.132
		var ring: Array = []; var rr: Array = []
		for k in range(25):
			var a := TAU * k / 24.0
			ring.append(Vector3(sin(a) * cr_r, ctop, 0.01 + cos(a) * (cr_r + 0.012))); rr.append(0.016)
		cr.tube(ring, rr, gp, {"sides": 6, "per": 1, "flat": 2.2, "side": Vector3.UP})
		for k in range(8):
			var a := TAU * k / 8.0
			var at := Vector3(sin(a) * cr_r, ctop + 0.015, 0.01 + cos(a) * (cr_r + 0.012))
			cr.crystal(at, Vector3(sin(a) * 0.15, 1.0, cos(a) * 0.15).normalized(), 0.06, 0.018, gp, 4)
			cr.blob(at + Vector3(0, -0.012, 0) + Vector3(sin(a), 0, cos(a)) * 0.012, Vector3.ONE * 0.012, jp, {"lat": 4, "lon": 6})
		var wood := cr.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#120e0c").lerp(Color("#3a2e26"), clampf(n.y * 0.3 + 0.3 + Sculpt.noise(p * 30.0) * 0.3, 0.0, 1.0)))
		var ant := cr.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#5a4a38").lerp(Color("#d8ccb0"), clampf(v * 0.9 + n.y * 0.1, 0.0, 1.0)))
		var ap: int = wood if kind == "thorn" else ant
		if kind == "thorn":
			# Antlers of blackthorn: gnarled black branches forking up out of the crown.
			for side: float in [-1.0, 1.0]:
				thorn_branch(cr, Vector3(0.09 * side, ctop + 0.01, 0.0), Vector3(0.6 * side, 1.0, 0.15), 0.6, 0.034, 1, 1.3 + side, 0.12)
		for side: float in ([] if kind == "thorn" else [-1.0, 1.0]):
			var base := Vector3(0.1 * side, ctop + 0.01, 0.0)
			var beam: Array = []; var br: Array = []
			for k in range(9):
				var t := k / 8.0
				beam.append(base + Vector3((0.12 * t + 0.1 * t * t) * side, 0.5 * t - 0.06 * t * t, 0.12 * t * t)); br.append(lerpf(0.028, 0.008, t))
			cr.tube(beam, br, ap, {"sides": 7, "per": 2, "lump": 0.15 if kind == "thorn" else 0.05})
			# Tines: brow, bez and trez forward, a crown of points at the top.
			for tk: Array in [[0.15, Vector3(0.2 * side, 0.4, -1.0), 0.14], [0.35, Vector3(0.3 * side, 0.6, -0.8), 0.17], [0.55, Vector3(0.2 * side, 0.9, -0.5), 0.15], [0.85, Vector3(0.4 * side, 1.0, -0.2), 0.12], [1.0, Vector3(0.6 * side, 0.8, 0.4), 0.1]]:
				var at: Vector3 = beam[int(round(float(tk[0]) * 8.0))]
				var d: Vector3 = (tk[1] as Vector3).normalized()
				var l: float = tk[2]
				cr.tube([at, at + d * l * 0.6 + Vector3(0, 0.02, 0), at + d * l + Vector3(0, 0.04, 0)], [0.014, 0.01, 0.003], ap, {"sides": 6, "per": 2, "cap1": false})
		steel_part(head, "Crown", cr)
	if black:
		# Great backswept horns from the temples, and a crown of iron thorns round the brow.
		var hn := Sculpt.new(); var hnp := hn.add_painter(horn); var tn := hn.add_painter(black_steel)
		for side: float in [-1.0, 1.0]:
			var pts: Array = []; var rr: Array = []
			# A ram's curl: back from the temple, round and down, the tip turning forward by the cheek.
			for k in range(14):
				var t := k / 13.0
				var ang := lerpf(PI * 0.55, PI * 1.85, t)
				var r := lerpf(0.1, 0.045, t)
				pts.append(Vector3((0.105 + 0.1 * t) * side, hy - 0.01 + r * sin(ang), 0.05 - r * cos(ang)))
				rr.append(lerpf(0.034, 0.006, pow(t, 0.9)))
			hn.tube(pts, rr, hnp, {"sides": 8, "per": 2, "cap1": false, "ridges": 0})
		for k in range(13):
			var a := TAU * k / 13.0
			var at := Vector3(sin(a) * 0.128, hy + 0.075, 0.01 + cos(a) * 0.145)
			hn.crystal(at, Vector3(sin(a) * 0.4, 1.0, cos(a) * 0.4).normalized(), 0.07 + 0.04 * (k % 2), 0.014, tn, 4)
		steel_part(head, "Horns", hn)
		# A torn black mourning veil hanging from the crown down the back.
		var vl := Sculpt.new(); var vp := vl.add_painter(black_cloth)
		var tops: Array = []
		for k in range(7): tops.append(Vector3(0.11 * (k - 3) / 3.0, hy + 0.06, 0.1 + 0.03 * (1.0 - absf(k - 3) / 3.0)))
		drape(vl, vp, tops, 0.62, Vector3(0, 0, 1), 0.04, 5.0)
		part(head, "Veil", vl, cloth_mat)
		# Ghost-fire streaming back from the eye sockets.
		var ef := Sculpt.new(); var efp := ef.add_painter(ghost_fire)
		for e: Vector3 in eyes:
			var sd := signf(e.x)
			var trail: Array = []; var tr: Array = []
			for j in range(8):
				var t := j / 7.0
				trail.append(e + Vector3(sd * (0.02 + 0.07 * t + 0.012 * sin(t * 9.0)), 0.01 + 0.08 * t * t + 0.015 * sin(t * 7.0), 0.02 + 0.32 * t)); tr.append(lerpf(0.02, 0.002, t))
			ef.tube(trail, tr, efp, {"sides": 7, "per": 2, "cap1": false})
		part(head, "EyeFire", ef, fire_mat)
	if gothic:
		# Mourning crape: long black streamers tied at the back of the helm.
		var cr := Sculpt.new(); var crp := cr.add_painter(black_cloth)
		var tops: Array = []
		for k in range(4): tops.append(Vector3(0.035 * (k - 1.5), hy - 0.02, 0.27))
		drape(cr, crp, tops, 0.7, Vector3(0, 0, 1), 0.03, 1.0)
		part(head, "Crape", cr, cloth_mat)

	# ---- arms. Right: the sword arm. Left: the shield arm (crusader) or a second hand on the hilt.
	var arms: Array = []; var forearms: Array = []
	var sw_c := Vector3.ZERO; var sw_d := Vector3.UP; var sw_e := Vector3.BACK
	var sh_c := Vector3.ZERO
	match kind:
		"crusader":
			# A middle guard: the forearm reaching forward, the blade rising forward from the fist,
			# its point at the height of a man's face.
			sw_c = Vector3(0.2, 1.02, -0.36); sw_d = Vector3(-0.08, 0.6, -0.8).normalized()
		"gothic":
			# Vigil: the greatsword stood point-down before it, both hands on the grip below the pommel.
			sw_c = Vector3(0.0, 1.05, -0.26); sw_d = Vector3(0, -1, 0)
		"blackknight":
			# The sword carried on the shoulder, the fist low before the hip.
			sw_c = Vector3(0.21, 1.0, -0.17); sw_d = Vector3(0.02, 0.86, 0.5).normalized()
		"royal", "thorn", "crest":
			# A low guard with the great sword, the point raised forward at the enemy's chest.
			sw_c = Vector3(0.22, 1.0, -0.28); sw_d = Vector3(-0.08, 0.45, -0.89).normalized()
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var sh_at := Vector3(0.23 * side, 1.42, 0.0)
		var shoulder := joint(root, label + "Shoulder", sh_at)
		var us := Sculpt.new(); var up := us.add_painter(plate_paint); var ub := us.add_painter(brass)
		var elbow_at := Vector3(0.27 * side, 1.13, 0.03)
		var wrist := Vector3(0.29 * side, 0.88, 0.0)
		var fc := Vector3(0.3 * side, 0.8, 0.0)
		var fd := Vector3(0, -1, 0)
		var hand_kind := "open"
		if side > 0.0:
			fc = sw_c; fd = sw_d
			hand_kind = "sword"
		elif crusader:
			hand_kind = "shield"
			elbow_at = Vector3(-0.29, 1.13, 0.05)
			fc = Vector3(-0.27, 1.02, -0.24); fd = Vector3(0, 1, 0)
		elif gothic:
			hand_kind = "sword"
			fc = sw_c + Vector3(0, 0.09, 0); fd = sw_d
		elif regent:
			# The lantern held up before it by its ring, the fist closed round the ring.
			hand_kind = "lantern"
			elbow_at = Vector3(-0.29, 1.12, 0.04)
			fc = Vector3(-0.3, 1.1, -0.3); fd = Vector3(0, 0, -1)
		if hand_kind != "open":
			if (side > 0.0 or gothic) and hand_kind != "lantern":
				elbow_at = Vector3(0.27 * side, 1.12, 0.06)
			wrist = fc - (fc - elbow_at).normalized() * 0.07
		var fa := (fc - wrist).normalized()
		if crusader and side < 0.0:
			# Shield arm: the hand closed round the inner strap, back of the hand outward.
			wrist = fc + Vector3(0.0, 0.0, 0.06)
			fa = (fc - wrist).normalized()
		# Pauldron: a dome over the shoulder with three lames below, a raised guard by the neck.
		if crusader:
			us.tube([sh_at + Vector3(0.02 * side, 0.03, 0), elbow_at + Vector3(0, 0.02, 0)], [0.07, 0.06], us.add_painter(mail), {"sides": 12, "per": 2})
			# Ailettes: small square plates standing on the shoulders, painted with the arms.
			var ail := us.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return tears(Vector2(p.z, p.y), Color("#121014"), 0.05))
			slab(us, ail, sh_at + Vector3(0.07 * side, 0.1, 0.02), Vector3(0.012, 0.15, 0.13), Basis(Vector3.BACK, -0.25 * side), 0.2, 0.0)
		else:
			us.blob(sh_at + Vector3(0.05 * side, 0.035, 0), Vector3(0.1, 0.065, 0.11), up, {"lat": 8, "lon": 12})
			for k in range(3):
				var ly := sh_at.y - 0.03 - k * 0.04
				us.tube([Vector3((0.22 + k * 0.01) * side, ly, 0), Vector3((0.36 - k * 0.012) * side, ly - 0.03, 0)], [0.085 - k * 0.01, 0.08 - k * 0.01], up, {"sides": 14, "per": 1, "flat": 1.2})
			us.tube([Vector3(0.14 * side, sh_at.y + 0.08, -0.07), Vector3(0.15 * side, sh_at.y + 0.13, 0.0), Vector3(0.14 * side, sh_at.y + 0.08, 0.07)], [0.012, 0.014, 0.012], up, {"sides": 5, "per": 2})
			if gothic: rim(us, ub, sh_at + Vector3(0.12 * side, -0.07, 0), Vector3(side, -0.5, 0), 0.085, 8)
			if black:
				# Thorn-spikes raking up off the pauldron, and a jagged edge to every lame.
				for k in range(3):
					us.crystal(sh_at + Vector3((0.06 + k * 0.035) * side, 0.08 - k * 0.012, -0.03 + k * 0.03), Vector3(side * (0.3 + k * 0.2), 1.0, 0.2).normalized(), 0.15 - k * 0.03, 0.025, up, 4)
				for k in range(3): rim(us, up, Vector3((0.3 - k * 0.002) * side, sh_at.y - 0.05 - k * 0.04, 0), Vector3(side, -0.3, 0), 0.08 - k * 0.01, 7, 0.4)
			# The rerebrace down the upper arm.
			var ro := {"sides": 14, "per": 2}
			if gothic: ro["ridges"] = 6; ro["ridge"] = 0.07
			us.tube([sh_at + Vector3(0.04 * side, -0.06, 0), elbow_at + Vector3(0, 0.04, 0)], [0.062, 0.056], up, ro)
		if crusader: part(shoulder, "Pauldron", us)
		else: steel_part(shoulder, "Pauldron", us)
		var elbow := joint(shoulder, "Forearm", elbow_at)
		var fs := Sculpt.new(); var fp := fs.add_painter(plate_paint); var fb := fs.add_painter(brass)
		# The couter cupping the elbow, with its fan.
		fs.blob(elbow_at, Vector3(0.062, 0.062, 0.066), fp, {"lat": 6, "lon": 9})
		fs.blob(elbow_at + Vector3(0.055 * side, 0.0, 0.02), Vector3(0.012, 0.08, 0.07), fp, {"lat": 4, "lon": 8, "basis": Basis(Vector3.UP, 0.4 * side)})
		# The vambrace to the wrist, then the gauntlet's flared, pointed cuff.
		var vo := {"sides": 14, "per": 2}
		if gothic: vo["ridges"] = 6; vo["ridge"] = 0.07
		fs.tube([elbow_at + (wrist - elbow_at) * 0.12, wrist], [0.054, 0.044], fp, vo)
		fs.tube([wrist - fa * 0.01, wrist + fa * 0.045], [0.062, 0.05], fp, {"sides": 12, "per": 1, "cap_rings": 1})
		fs.crystal(wrist + fa * 0.01, (-fa + Vector3(side * 0.6, 0, 0)).normalized(), 0.08, 0.025, fp, 4)
		if gothic: rim(fs, fb, wrist - fa * 0.012, fa, 0.063, 7)
		if hand_kind == "open":
			# A gauntleted hand hanging relaxed, fingers half curled.
			fs.blob(fc, Vector3(0.035, 0.055, 0.045), fp, {"lat": 6, "lon": 9})
			for k in range(4):
				fs.tube([fc + Vector3(-0.01 * side, -0.04, -0.03 + k * 0.02), fc + Vector3(-0.025 * side, -0.08, -0.03 + k * 0.02), fc + Vector3(-0.04 * side, -0.09, -0.035 + k * 0.02)], [0.011, 0.01, 0.008], fp, {"sides": 5, "per": 1})
				# Long clawed fingertips on the black knight's gauntlet.
				if black: fs.crystal(fc + Vector3(-0.04 * side, -0.09, -0.035 + k * 0.02), Vector3(-0.5 * side, -1.0, -0.1).normalized(), 0.07, 0.009, fp, 4)
		else:
			var bh := fa.cross(fd).normalized() if side > 0.0 else fd.cross(fa).normalized()
			if bh.length() < 0.5: bh = Vector3(side, 0, 0)
			fist(fs, fp, fc, fd, fa, bh, 0.017)
			if side > 0.0: sw_e = fa.cross(fd).cross(fd).normalized() * -1.0
		steel_part(elbow, "Vambrace", fs)
		if side > 0.0:
			var ss := Sculpt.new(); var ssp := ss.add_painter(steel); var sgp := ss.add_painter(leather); var sbp := ss.add_painter(brass)
			var e := fd.cross(Vector3.RIGHT).normalized() if absf(fd.x) < 0.9 else Vector3.UP
			# Edges in line with the knuckles: the edge points along the forearm's line.
			e = (fa - fd * fa.dot(fd)).normalized()
			var blade := 1.0; var grip := 0.2; var width := 0.05
			if regent: blade = 1.25; grip = 0.28; width = 0.062
			if gothic: blade = 1.0; grip = 0.3; width = 0.058
			var gc := fc
			if gothic: gc = fc + Vector3(0, 0.05, 0)
			if black:
				blade = 1.2; grip = 0.24; width = 0.06
				ssp = ss.add_painter(black_steel)
			sword(ss, ssp, sgp, sbp, gc, fd, e, blade, grip, width, black)
			if black:
				var rs := Sculpt.new(); var rp := rs.add_painter(func (p, n, v, w): return Color.WHITE)
				var guard := gc + fd * (grip * 0.5 + 0.01)
				var ff := fd.cross(e).normalized()
				for sgn: float in [-1.0, 1.0]:
					var rpts: Array = []; var rrr: Array = []
					for k in range(16):
						var t := 0.06 + 0.8 * k / 15.0
						rpts.append(guard + fd * blade * t + e * width * 0.22 * sin(t * TAU * 5.5) * smoothstep(0.08, 0.2, t) * (1.0 - t * 0.6) + ff * sgn * width * 0.09); rrr.append(0.0035)
					rs.tube(rpts, rrr, rp, {"sides": 4, "per": 1})
				part(elbow, "Runes", rs, glow).material_override = glow
			steel_part(elbow, "Sword", ss)
		if regent and side < 0.0:
			# A lantern of iron and horn hanging from the fist by its ring: four corner posts, a
			# pierced conical roof, panes of thin horn, and a cold flame inside.
			var ln := Sculpt.new(); var ip := ln.add_painter(black_steel); var hn := ln.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#c8a868").lerp(Color("#f0d8a0"), clampf(n.y * 0.3 + 0.5, 0.0, 1.0)))
			var ring_c := fc + Vector3(0, -0.01, 0)
			var rpts: Array = []; var rrr: Array = []
			for k in range(13):
				var a := TAU * k / 12.0
				rpts.append(ring_c + Vector3(sin(a) * 0.035, -0.02 + cos(a) * 0.035 - 0.015, 0)); rrr.append(0.006)
			ln.tube(rpts, rrr, ip, {"sides": 5, "per": 1})
			var top := ring_c + Vector3(0, -0.08, 0)
			ln.lathe(top + Vector3(0, -0.07, 0), [Vector2(0.09, 0.0), Vector2(0.06, 0.03), Vector2(0.0, 0.07)], ip, {"sides": 8})
			var lb := top + Vector3(0, -0.3, 0)
			for k in range(4):
				var a := TAU * (k + 0.5) / 4.0
				var off := Vector3(sin(a) * 0.075, 0, cos(a) * 0.075)
				ln.tube([top + Vector3(0, -0.07, 0) + off, lb + off], [0.007, 0.007], ip, {"sides": 4, "per": 1})
			ln.lathe(lb + Vector3(0, -0.02, 0), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.088, 0.02), Vector2(0.0, 0.025)], ip, {"sides": 8})
			part(elbow, "Lantern", ln)
			var pn := Sculpt.new(); var pnp := pn.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color(0.95, 0.85, 0.6, 0.45))
			pn.tube([top + Vector3(0, -0.075, 0), lb + Vector3(0, 0.015, 0)], [0.068, 0.068], pnp, {"sides": 4, "per": 1, "cap0": false, "cap1": false, "twist": 0.0})
			var pm := StandardMaterial3D.new(); pm.vertex_color_use_as_albedo = true; pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pm.cull_mode = BaseMaterial3D.CULL_DISABLED; pm.emission_enabled = true; pm.emission = glow.emission * 0.35
			part(elbow, "Panes", pn, pm)
			var fl2 := Sculpt.new(); var flp := fl2.add_painter(func (p, n, v, w): return Color.WHITE)
			var fcen := (top + lb) * 0.5 + Vector3(0, -0.02, 0)
			fl2.blob(fcen, Vector3(0.03, 0.05, 0.03), flp, {"lat": 5, "lon": 8})
			fl2.crystal(fcen + Vector3(0, 0.03, 0), Vector3.UP, 0.06, 0.022, flp, 5)
			part(elbow, "LanternFlame", fl2, glow).material_override = glow
			var ll := OmniLight3D.new(); ll.name = "LanternLight"; ll.light_color = glow.emission if kind != "thorn" else Color("#e8f0d8"); ll.light_energy = 0.8 if kind != "thorn" else 0.35; ll.omni_range = 2.2 if kind != "thorn" else 1.2
			elbow.add_child(ll); ll.position = fcen - _world(elbow)
		if crusader and side < 0.0:
			# The heater shield on the forearm: black, strewn with silver tears, edged in steel.
			var sh := Sculpt.new(); var shr := sh.add_painter(steel)
			var mid := (elbow_at + fc) * 0.5
			var nrm := Vector3(-0.85, 0.0, -0.53).normalized()
			heater(sh, mid + nrm * 0.07 + Vector3(0, -0.04, 0), nrm, Vector3(0.0, 1.0, 0.12), 0.5, 0.64, func (uv: Vector2) -> Color: return tears(uv, Color("#121014"), 0.085), shr)
			part(elbow, "Shield", sh)
		if side > 0.0:
			arms.push_front(shoulder); forearms.push_front(elbow)
		else:
			arms.append(shoulder); forearms.append(elbow)

	# ---- legs: cuisses, poleyns with fans, greaves, pointed sabatons (mail chausses for the crusader)
	var hips: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip_at := Vector3(0.1 * side, 0.88, 0.0)
		var hip := joint(root, label + "Hip", hip_at)
		var ts := Sculpt.new(); var tp2 := ts.add_painter(mail if crusader else plate_paint); var tb := ts.add_painter(brass)
		var knee_at := Vector3(0.11 * side, 0.49, -0.02)
		var co := {"sides": 14, "per": 2}
		if gothic: co["ridges"] = 8; co["ridge"] = 0.06
		ts.tube([hip_at + Vector3(0, 0.02, 0), hip_at.lerp(knee_at, 0.5) + Vector3(0, 0, -0.008), knee_at + Vector3(0, 0.05, 0)], [0.098, 0.086, 0.068], tp2, co)
		if crusader: part(hip, "Cuisse", ts, mail_mat)
		else: steel_part(hip, "Cuisse", ts)
		var knee := joint(hip, "Knee", knee_at)
		var ls := Sculpt.new(); var lp := ls.add_painter(plate_paint); var lb := ls.add_painter(brass); var lm := ls.add_painter(mail)
		ls.blob(knee_at + Vector3(0, 0, -0.03), Vector3(0.068, 0.065, 0.06), lp, {"lat": 6, "lon": 9})
		ls.blob(knee_at + Vector3(0.062 * side, 0, -0.005), Vector3(0.012, 0.07, 0.065), lp, {"lat": 4, "lon": 8})
		var ankle := Vector3(0.11 * side, 0.1, 0.0)
		var go := {"sides": 14, "per": 2}
		if gothic: go["ridges"] = 6; go["ridge"] = 0.06
		ls.tube([knee_at + Vector3(0, -0.04, 0.005), knee_at.lerp(ankle, 0.4) + Vector3(0, 0, 0.012), ankle], [0.058, 0.062, 0.044], lm if crusader else lp, go)
		if crusader: ls.tube([knee_at + Vector3(0, -0.05, -0.02), ankle + Vector3(0, 0.03, -0.02)], [0.05, 0.04], lp, {"sides": 10, "per": 1, "flat": 0.5, "side": Vector3.BACK})
		var toe := Vector3(0.11 * side, 0.025, -0.3 if gothic else -0.2)
		ls.tube([ankle + Vector3(0, -0.025, 0.05), Vector3(0.11 * side, 0.045, -0.06), toe], [0.058, 0.05, 0.006], lm if crusader else lp, {"sides": 10, "per": 3, "flat": 0.55, "bands": 6, "band": 0.12, "cap1": false})
		if gothic: rim(ls, lb, knee_at + Vector3(0, -0.065, 0), Vector3.UP, 0.06, 8)
		steel_part(knee, "Greave", ls)
		hips.append(hip); knees.append(knee)

	# ---- cloth: whole garments that hang from the shoulders and tear only at the hem
	var cs := Sculpt.new()
	var surcoat := cs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return tears(Vector2(p.x + p.z * 0.6, p.y), violet_cloth(p, n, v, w), 0.11))
	var cv := cs.add_painter(violet_cloth); var cb := cs.add_painter(black_cloth)
	# How far the body stands out in front at each height (the garment hangs over it).
	var depth: Array = [Vector2(1.46, 0.12), Vector2(1.3, 0.17), Vector2(1.1, 0.14), Vector2(0.98, 0.12), Vector2(0.85, 0.15), Vector2(0.5, 0.19), Vector2(0.0, 0.22)]
	if not crusader: depth = [Vector2(1.46, 0.14), Vector2(1.3, 0.2), Vector2(1.12, 0.19), Vector2(0.98, 0.15), Vector2(0.88, 0.2), Vector2(0.6, 0.23), Vector2(0.0, 0.25)]
	var depth_at := func (yy: float) -> float:
		for k in range(depth.size() - 1):
			var a: Vector2 = depth[k]; var b: Vector2 = depth[k + 1]
			if yy <= a.x and yy >= b.x: return lerpf(a.y, b.y, (a.x - yy) / (a.x - b.x))
		return (depth[-1] as Vector2).y
	var panel := func (painter: int, f: float, top_y: float, half: float, length: float, ragged: float, seed: float, split: bool) -> void:
		var tops: Array = []; var outs: Array = []; var lens: Array = []
		var n := 30
		for k in range(n + 1):
			var x := lerpf(-half, half, k / float(n))
			tops.append(Vector3(x, top_y, 0)); outs.append(Vector3(0, 0, f))
			var l := length * (1.0 - ragged * fposmod(int(k / 2.5) * 0.618 + seed, 1.0))
			if split and absf(x) < half * 0.12: l = minf(l, length * 0.55)
			lens.append(l)
		cloth_sheet(cs, painter, tops, outs, lens, func (i: int, t: float, yy: float) -> float:
			var x: float = (tops[i] as Vector3).x
			return float(depth_at.call(yy)) + 0.025 - pow(absf(x) / half, 2.0) * 0.05, 40)
	if crusader:
		# A long sleeveless surcoat to below the knee, split at the front, torn at the hem.
		panel.call(surcoat, -1.0, 1.44, 0.19, 1.0, 0.2, 1.0, true)
		panel.call(surcoat, 1.0, 1.44, 0.19, 1.0, 0.2, 2.0, true)
		cloak(cs, cv, 0.28, 1.47, 1.32, 1.3, 0.3)
	elif gothic:
		# A short torn tabard over the fauld, front and back, and a long black cloak.
		panel.call(cv, -1.0, 1.0, 0.17, 0.42, 0.4, 1.0, false)
		panel.call(cv, 1.0, 1.0, 0.17, 0.42, 0.4, 2.0, false)
		cloak(cs, cb, 0.3, 1.48, 1.4, 1.45, 0.35)
	elif regent:
		var arms_p := cs.add_painter(royal_arms)
		if kind == "royal" or kind == "crest":
			# A tabard of the royal arms, a long purple mantle, an ermine tippet over the shoulders.
			panel.call(arms_p, -1.0, 1.44, 0.19, 0.95 if kind == "crest" else 0.7, 0.12, 1.0, kind == "crest")
			panel.call(arms_p, 1.0, 1.44, 0.19, 0.95 if kind == "crest" else 0.7, 0.12, 2.0, kind == "crest")
			cloak(cs, cs.add_painter(royal_purple), 0.3, 1.5, 1.65, 1.5, 0.12)
			if kind == "royal":
				var tops: Array = []; var outs: Array = []; var lens: Array = []
				for k in range(41):
					var a := lerpf(-PI, PI, k / 40.0)
					tops.append(Vector3(sin(a) * 0.16, 1.56, cos(a) * 0.14)); outs.append(Vector3(sin(a), 0, cos(a))); lens.append(0.16)
				cloth_sheet(cs, cs.add_painter(ermine), tops, outs, lens, func (i: int, t: float, yy: float) -> float: return 0.02 + 0.12 * sqrt(t), 8)
		else:
			# A cloak gone to moss and rags.
			cloak(cs, cs.add_painter(moss_rag), 0.3, 1.5, 1.55, 1.2, 0.5)
			panel.call(cs.add_painter(moss_rag), -1.0, 1.0, 0.17, 0.5, 0.5, 1.0, false)
	else:
		# A tabard bearing a mourning hatchment: a black lozenge strewn with silver tears on violet.
		var hatch := cs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var q := Vector2(p.x, p.y - 0.88)
			if absf(q.x) / 0.12 + absf(q.y) / 0.16 < 1.0: return tears(Vector2(p.x, p.y), Color("#0e0c12"), 0.065)
			if absf(q.x) / 0.12 + absf(q.y) / 0.16 < 1.12: return Color("#c8ccd4")
			return violet_cloth(p, n, v, w))
		panel.call(hatch, -1.0, 1.1, 0.17, 0.62, 0.2, 1.0, false)
		panel.call(cv, 1.0, 1.1, 0.17, 0.62, 0.2, 2.0, false)
		cloak(cs, cv, 0.26, 1.48, 1.1, 1.05, 0.35)
		# An empty scabbard hanging at the left hip.
		var sb := cs.add_painter(leather); var sbr := cs.add_painter(brass)
		var top := Vector3(-0.22, 0.88, -0.06)
		var dirv := Vector3(-0.1, -0.75, 0.65).normalized()
		cs.tube([top, top + dirv * 0.5, top + dirv * 0.9], [0.03, 0.027, 0.018], sb, {"sides": 6, "per": 2, "flat": 0.35, "side": Vector3.RIGHT})
		cs.tube([top + dirv * 0.88, top + dirv * 0.94], [0.02, 0.008], sbr, {"sides": 6, "per": 1})
	part(root, "Cloth", cs, cloth_mat)

	if black:
		# Ghost-fire smouldering round its feet and leaking from the gaps in the armour.
		var gf := Sculpt.new(); var gfp := gf.add_painter(ghost_fire)
		for k in range(14):
			var a := TAU * k / 14.0
			var at := Vector3(sin(a) * 0.22, 0.02, cos(a) * 0.2 - 0.04)
			gf.tube([at, at + Vector3(0.02 * sin(k), 0.12, 0.02 * cos(k)), at + Vector3(0.04 * sin(k * 1.7), 0.22 + 0.06 * (k % 3), 0.0)], [0.045, 0.03, 0.002], gfp, {"sides": 6, "per": 2, "cap1": false})
		for sh: Node3D in arms:
			var sf := Sculpt.new(); var sfp := sf.add_painter(ghost_fire)
			var at := _world(sh) + Vector3(0, -0.06, 0)
			for k in range(3): sf.tube([at, at + Vector3(0.03 * (k - 1), 0.1, 0.02), at + Vector3(0.05 * (k - 1), 0.18, 0.05)], [0.03, 0.02, 0.002], sfp, {"sides": 6, "per": 2, "cap1": false})
			part(sh, "GhostFire", sf, fire_mat)
		for at: Vector3 in [Vector3(0, 1.52, 0.0), Vector3(0, 0.95, 0.0)]:
			for k in range(3): gf.tube([at, at + Vector3(0.03 * (k - 1), 0.1, 0.02), at + Vector3(0.05 * (k - 1), 0.18, 0.05)], [0.03, 0.02, 0.002], gfp, {"sides": 6, "per": 2, "cap1": false})
		part(root, "GhostFire", gf, fire_mat)
	if kind == "thorn":
		# Blackthorn has grown up through the empty armour and out of every gap in it.
		# The breastplate burst open from inside: a ragged hole, its torn plate curling outward,
		# a will-o'-the-wisp glow at its heart and branches thrusting out of it.
		var hole := Vector3(0.03, 1.26, -0.18)
		var bp_ := Sculpt.new(); var hbp := bp_.add_painter(plate_paint); var hdk := bp_.add_painter(func (p, n, v, w): return Color("#050404"))
		bp_.blob(hole + Vector3(0, 0, 0.01), Vector3(0.085, 0.1, 0.03), hdk, {"lat": 6, "lon": 10, "lump": 0.25})
		for k in range(7):
			var a := TAU * k / 7.0 + 0.3
			var e := hole + Vector3(cos(a) * 0.085, sin(a) * 0.1, -0.005)
			bp_.crystal(e, (Vector3(cos(a), sin(a), -1.2)).normalized(), 0.08 + 0.04 * (k % 2), 0.035, hbp, 3)
		steel_part(root, "BurstPlate", bp_)
		var hg := Sculpt.new(); var hgp := hg.add_painter(func (p, n, v, w): return Color.WHITE)
		hg.blob(hole + Vector3(0, 0, -0.012), Vector3(0.035, 0.045, 0.012), hgp, {"lat": 5, "lon": 8})
		part(root, "WispHeart", hg, glow).material_override = glow
		var tb := Sculpt.new()
		for k in range(3):
			var a := TAU * k / 3.0 + 0.9
			thorn_branch(tb, hole + Vector3(cos(a) * 0.04, sin(a) * 0.05, 0.0), Vector3(cos(a) * 0.9, sin(a) * 0.6 + 0.25, -0.9), 0.36 + 0.06 * (k % 2), 0.026, 0, 3.0 + k * 1.9, 0.06)
		# Up out of the neck behind the helm and spreading round its back: a thorny mantle.
		for k in range(3):
			var x := (k - 1) * 0.1
			thorn_branch(tb, Vector3(x, 1.5, 0.1), Vector3(x * 4.5, 1.0, 0.8), 0.7, 0.03, 1, 11.0 + k * 2.3, 0.05)
		# Out of the fauld at the waist.
		for side: float in [-1.0, 1.0]:
			thorn_branch(tb, Vector3(0.18 * side, 0.92, -0.04), Vector3(side, 0.15, -0.2), 0.28, 0.018, 0, 21.0 + side, 0.02)
		part(root, "Blackthorn", tb)
		# Out of the pauldrons, elbows and knees, on their own joints so they move with the limbs.
		for k in range(arms.size()):
			var sh: Node3D = arms[k]; var fa: Node3D = forearms[k]
			var sd := signf(_world(sh).x)
			var s1 := Sculpt.new()
			thorn_branch(s1, _world(sh) + Vector3(0.1 * sd, 0.0, 0.0), Vector3(sd, 0.8, 0.15), 0.4, 0.024, 1, 31.0 + sd, 0.06)
			part(sh, "Blackthorn", s1)
			var s2 := Sculpt.new()
			thorn_branch(s2, _world(fa) + Vector3(0.04 * sd, 0.0, 0.03), Vector3(sd, -0.3, 0.6), 0.25, 0.016, 0, 41.0 + sd, -0.02)
			part(fa, "Blackthorn", s2)
			var mss := Sculpt.new(); var mmp := mss.add_painter(moss_rag)
			var drips: Array = []
			for q in range(7): drips.append(_world(sh) + Vector3((0.04 + q * 0.025) * sd, -0.06, -0.07 + q * 0.025))
			hanging(mss, mmp, drips, 0.28, 0.012, Vector3.ZERO)
			part(sh, "Moss", mss, cloth_mat)
		for k in range(hips.size()):
			var kn: Node3D = knees[k]
			var sd := signf(_world(kn).x)
			var s3 := Sculpt.new()
			thorn_branch(s3, _world(kn) + Vector3(0.05 * sd, 0.0, -0.03), Vector3(sd, 0.4, -0.5), 0.25, 0.016, 0, 51.0 + sd, 0.04)
			part(kn, "Blackthorn", s3)
		# Little twigs creeping out of the visor's sight.
		var vs := Sculpt.new()
		for side: float in [-1.0, 1.0]: thorn_branch(vs, Vector3(0.08 * side, 1.71, -0.11), Vector3(side, 0.35, -0.4), 0.17, 0.008, 0, 71.0 + side, 0.05)
		part(head, "Blackthorn", vs)
		remove_meta("tb_paint"); remove_meta("tb_sculpt")
	var scale := 1.42 if not black else 1.55
	if regent: scale = 1.8
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": hips, "knees": knees, "leaves": []}, scale)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["visual_rig"] = {"head": node.get_path_to(head), "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	node.set_meta("rig_bindings", rig)
	return node
