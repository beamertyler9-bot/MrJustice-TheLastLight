extends "res://tools/sculpt_shard_sentinel.gd"
## The Bellkeeper, boss of the deep dungeon beneath Ironbell, sculpted by hand: the keeper of
## the town's bells, sworn to ring them for the dead, still keeping his oath long after; a
## giant who carries a great two-handed bell-maul and is hung all over with bells.
##
## Built from real bells and bell-ringing. A church bell from the top down: the crown with its
## canons (the cast loops it hangs by), the shoulder, the waist, the thick sound-bow where the
## clapper strikes, and the lip; inside, the clapper (an iron shank with a ball and a flight
## below it). Bells hang from a headstock on a wheel in an oak bell-frame, rung by a rope with
## a "sally" - a woollen grip striped red, white and blue - and a tail end. Bell-founders cast
## them in loam moulds and inscribe them round the waist.
##
## The maul is held as a two-handed maul is: both fists closed round the haft, well apart, the
## leading hand toward the head; at rest carried across the body at the hips ("port arms").
##
##   bellknight - a knight in blackened plate trimmed with bell-bronze, his helm a great bell
##               worn mouth-down with a cross-shaped sight cut in it and his face a glow
##               inside, the canons standing up as a crest; bells on chains at his pauldrons
##               and belt, a funeral tabard, and a maul whose head is a bell turned on its side
##   belfry     - the bell-tower itself got up and walking: a stone tower for a body with
##               louvred belfry openings and a great bell hung inside its chest, a slate spire
##               for a head with a lantern-light in its windows and a weathervane, shoulders of
##               oak bell-frame timbers with bells swinging in them, ropes with striped sallies,
##               and a giant ringer's mallet (a wooden "beetle" bound with iron)
##   tollkeeper - the man who tolled the passing bell, gone to a gaunt giant revenant in a
##               hooded funeral robe, a cracked bronze bell for a head with one eye burning in
##               the dark of its mouth and the clapper hanging out of it like a tongue; handbells
##               on chains at its belt, and a long-hafted bronze bell-maul
##   oathbound  - all of these in one, and the original gilded Bellkeeper behind them: gilt
##               bell-bronze plate over blackened iron, a great bell for a helm with a pointed
##               belfry arch for a face, barred with iron and full of dawn-light, crowned with
##               its canons round a little slate spire; a belfry window cut in the breastplate
##               with iron louvres and a bell of light hanging inside; three-tiered spiked
##               pauldrons each carrying a small oak bell-frame with bells swinging in it;
##               bell-ropes with their striped sallies at the belt; a midnight tabard embroidered
##               with the gold sun-and-bell; a funeral mantle; and the Oath-Bell Maul - a great
##               bell lying crosswise on an iron-banded haft with a spiked hammer-face opposite

var kindb := "bellknight"
var bronze_mat: StandardMaterial3D
var crown_mat: StandardMaterial3D
var attack_glow: StandardMaterial3D
var hurt_glow: StandardMaterial3D


func _init() -> void:
	super()
	material.albedo_texture = null; material.metallic = 0.25; material.roughness = 0.45
	material.vertex_color_is_srgb = true; material.albedo_color = Color.WHITE
	bronze_mat = StandardMaterial3D.new()
	bronze_mat.vertex_color_use_as_albedo = true; bronze_mat.vertex_color_is_srgb = true
	bronze_mat.metallic = 0.75; bronze_mat.roughness = 0.38; bronze_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_mat.vertex_color_is_srgb = true


func build(variant: String) -> Node3D:
	# Everything is built at human size inside a "Giant" node scaled up, so the boss's own
	# body_scale (which the fight code drives) stays 1.
	root = Node3D.new(); root.name = "Giant"
	kindb = variant; kind = "gothic"
	var col := Color("#ffc870")
	if variant == "tollkeeper": col = Color("#9ad8ff")
	glow.albedo_color = col.darkened(0.2); glow.emission = col; glow.emission_energy_multiplier = 1.5
	attack_glow = glow.duplicate(); attack_glow.emission = Color("#fff0c8") if variant != "tollkeeper" else Color("#e8f8ff"); attack_glow.emission_energy_multiplier = 4.0
	hurt_glow = glow.duplicate(); hurt_glow.emission = Color("#ff5a3a"); hurt_glow.albedo_color = Color("#a8301c")
	crown_mat = glow.duplicate(); crown_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; crown_mat.albedo_color.a = 0.85
	match variant:
		"bellknight": return _keeper()
		"belfry": return _keeper()
		"tollkeeper": return _keeper()
		"oathbound": return _grand()
	return null


# ------------------------------------------------------------------ painters

static func bell_bronze(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#3a2410").lerp(Color("#c89448"), clampf(n.y * 0.25 + 0.42 + Sculpt.noise(p * 14.0) * 0.3, 0.0, 1.0))
	c = c.lerp(Color("#e8c070"), smoothstep(0.6, 0.8, Sculpt.noise(p * 30.0)) * 0.3)
	return c.lerp(Color("#2a7262"), smoothstep(0.35, 0.65, Sculpt.noise(p * 5.0 + Vector3(4, 0, 0))) * clampf(0.7 - n.y * 0.5, 0.0, 1.0) * 0.6)


static func black_iron(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#121318").lerp(Color("#4a4c56"), clampf(n.y * 0.3 + 0.35 + Sculpt.noise(p * 16.0) * 0.25, 0.0, 1.0))
	# Fine engraved lines running round the plates.
	c = c.lerp(Color("#8a7448"), smoothstep(-0.01, 0.02, absf(fposmod(p.y * 22.0 + Sculpt.noise(p * 4.0) * 0.6, 1.0) - 0.5) - 0.46) * 0.5)
	return c.lerp(Color("#4a2a1a"), smoothstep(0.6, 0.8, Sculpt.noise(p * 8.0)) * 0.35)


static func funeral_cloth(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0c1024").lerp(Color("#28305a"), clampf(n.y * 0.25 + 0.35 + Sculpt.fbm(p * 7.0) * 0.35, 0.0, 1.0))
	return c.darkened(v * 0.3)


static func oak(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var g := absf(sin(p.x * 30.0 + p.z * 30.0 + Sculpt.noise(p * Vector3(3, 18, 3)) * 4.0))
	return Color("#2a1c10").lerp(Color("#6a4a2a"), clampf(0.4 + g * 0.3 + n.y * 0.15, 0.0, 1.0))


static func tower_stone(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#3e3c40").lerp(Color("#8a867e"), clampf(n.y * 0.2 + 0.4 + Sculpt.fbm(p * 6.0) * 0.4, 0.0, 1.0))
	# Courses of ashlar: dark mortar lines every row, staggered joints.
	var row := floorf(p.y * 9.0)
	var mortar := maxf(smoothstep(0.08, 0.0, fposmod(p.y * 9.0, 1.0)), smoothstep(0.05, 0.0, fposmod((p.x + p.z) * 5.0 + row * 0.5, 1.0)))
	c = c.darkened(mortar * 0.55)
	return c.lerp(Color("#3a4a2a"), smoothstep(0.62, 0.8, Sculpt.noise(p * 9.0)) * 0.35)


static func slate(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#1e2228").lerp(Color("#4a5260"), clampf(n.y * 0.3 + 0.35 + Sculpt.noise(p * 12.0) * 0.25, 0.0, 1.0))
	return c.darkened(smoothstep(0.85, 1.0, fposmod(p.y * 18.0, 1.0)) * 0.5)


static func sally(p: Vector3, _n: Vector3, _v: float, _w: float) -> Color:
	var b := fposmod(p.y * 12.0 + p.x * 3.0, 3.0)
	return Color("#a8201c") if b < 1.0 else (Color("#e8e0d0") if b < 2.0 else Color("#1c3a8a"))


static func pale_flesh(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#4a4a50").lerp(Color("#a8a49c"), clampf(n.y * 0.3 + 0.4 + Sculpt.noise(p * 15.0) * 0.3, 0.0, 1.0))


# ------------------------------------------------------------------ pieces

## A church bell hanging from `top`, mouth along `down`: crown and canons, waist, sound-bow
## and lip, with the clapper inside. `r` is the radius at the lip.
func church_bell(s: Sculpt, painter: int, top: Vector3, down: Vector3, r: float, clapper := true) -> void:
	var d := down.normalized()
	var h := r * 1.25
	var prof: Array = []
	for q: Vector2 in [Vector2(0.0, 1.0), Vector2(0.38, 0.97), Vector2(0.55, 0.88), Vector2(0.6, 0.72), Vector2(0.62, 0.5), Vector2(0.7, 0.26), Vector2(0.86, 0.1), Vector2(0.98, 0.04), Vector2(1.0, 0.0), Vector2(0.9, 0.0), Vector2(0.8, 0.06), Vector2(0.55, 0.22), Vector2(0.48, 0.6), Vector2(0.0, 0.85)]:
		prof.append(Vector2(q.x * r, q.y * h))
	var b := Basis(Quaternion(Vector3.UP, -d))
	s.lathe(top + d * h, prof, painter, {"sides": 16, "basis": b})
	# The canons: cast loops on the crown.
	var a := b * Vector3.RIGHT
	for k in range(2):
		var sx := -1.0 if k == 0 else 1.0
		s.tube([top + a * r * 0.15 * sx, top - d * r * 0.18 + a * r * 0.12 * sx, top - d * r * 0.18 - a * r * 0.02 * sx], [r * 0.05, r * 0.05, r * 0.05], painter, {"sides": 5, "per": 2})
	if clapper:
		s.tube([top + d * h * 0.15, top + d * h * 0.85], [r * 0.05, r * 0.05], painter, {"sides": 5, "per": 1})
		s.blob(top + d * h * 0.9, Vector3.ONE * r * 0.14, painter, {"lat": 4, "lon": 6})


## A bell on a short chain from `at`, on its own joint so it can swing.
func swinging_bell(parent: Node3D, at: Vector3, r: float, chain: float, list: Array) -> void:
	var j := joint(parent, "OathBell%d" % list.size(), at)
	var s := Sculpt.new(); var bp := s.add_painter(bell_bronze); var ip := s.add_painter(black_iron)
	for k in range(3): s.blob(at + Vector3(0, -chain * (k + 0.5) / 3.0, 0), Vector3(0.012, chain / 7.0, 0.012), ip, {"lat": 3, "lon": 5})
	church_bell(s, bp, at + Vector3(0, -chain, 0), Vector3.DOWN, r)
	part(j, "Bell", s, bronze_mat)
	list.append(j)


## A fist closed round a haft (as fist(), sized for the giant).
func grip(s: Sculpt, painter: int, c: Vector3, d: Vector3, a: Vector3, bh: Vector3, grip_r: float) -> void:
	var front := d.cross(bh).normalized()
	if front.dot(a) < 0.0: front = -front
	s.blob(c + bh * (grip_r + 0.026) - a * 0.012, Vector3(0.026, 0.06, 0.055), painter, {"lat": 5, "lon": 8, "basis": Basis(bh, d, bh.cross(d)).orthonormalized()})
	for k in range(4):
		var off := d * (0.036 - k * 0.026)
		var pts: Array = []; var rr: Array = []
		for j in range(6):
			var t := lerpf(0.0, PI * 1.25, j / 5.0)
			pts.append(c + off + (bh * cos(t) + front * sin(t)) * (grip_r + 0.016)); rr.append(0.014)
		s.tube(pts, rr, painter, {"sides": 5, "per": 1})
	var tb := c + d * 0.052
	s.tube([tb + bh * (grip_r + 0.012) - a * 0.024, tb + front * (grip_r + 0.014) + bh * 0.01, tb + front * (grip_r + 0.012) - bh * (grip_r * 0.6)], [0.016, 0.015, 0.012], painter, {"sides": 5, "per": 2})
	s.blob(c - a * 0.04 + bh * 0.012, Vector3(0.045, 0.054, 0.048), painter, {"lat": 5, "lon": 8})


# ------------------------------------------------------------------ the keeper

func _keeper() -> Node3D:
	var knight := kindb == "bellknight"; var belfry := kindb == "belfry"; var toll := kindb == "tollkeeper"
	var armour: Callable = black_iron
	if belfry: armour = tower_stone
	if toll: armour = func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return funeral_cloth(p, n, v, w).lerp(Color("#2a1a30"), 0.3)
	var limb: Callable = black_iron
	if belfry: limb = oak
	if toll: limb = pale_flesh
	var bells: Array = []; var cloths: Array = []

	# ---- body
	var body := Sculpt.new(); var bp := body.add_painter(armour); var bz := body.add_painter(bell_bronze)
	var dk := body.add_painter(func (_p, _n, _v, _w): return Color("#050406"))
	var gl := Sculpt.new(); var glp := gl.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	if knight:
		# Blackened plate: a broad breastplate engraved round with bell-founders' bands, a
		# skirt of lames over the hips, bronze trim at every edge.
		body.tube([Vector3(0, 0.95, 0), Vector3(0, 1.1, -0.01), Vector3(0, 1.3, -0.02), Vector3(0, 1.47, 0)], [0.23, 0.26, 0.32, 0.29], bp, {"sides": 18, "per": 3, "side": Vector3.BACK, "flat": 0.72})
		body.blob(Vector3(0, 1.3, -0.08), Vector3(0.28, 0.18, 0.15), bp, {"lat": 8, "lon": 12})
		body.tube([Vector3(0, 1.03, -0.17), Vector3(0, 1.32, -0.2), Vector3(0, 1.44, -0.16)], [0.012, 0.016, 0.012], bz, {"sides": 5, "per": 2})
		for k in range(4):
			var yy := 0.93 - k * 0.06
			body.tube([Vector3(0, yy + 0.03, 0), Vector3(0, yy - 0.03, 0)], [0.21 + k * 0.02, 0.22 + k * 0.02], bp, {"sides": 18, "per": 1, "side": Vector3.BACK, "flat": 0.75})
			rim(body, bz, Vector3(0, yy - 0.032, 0), Vector3.UP, 0.222 + k * 0.02, 14, 0.2)
		body.tube([Vector3(0, 1.45, 0), Vector3(0, 1.55, 0)], [0.2, 0.12], bp, {"sides": 16, "per": 1, "side": Vector3.BACK, "flat": 0.85})
	elif belfry:
		# The tower: a square stone shaft with a cornice, two louvred belfry openings in front,
		# dark inside, and the great bell hanging in the chest behind them.
		box(body, bp, Vector3(0, 1.18, 0), Basis.IDENTITY, Vector3(0.27, 0.36, 0.22))
		box(body, bp, Vector3(0, 1.56, 0), Basis.IDENTITY, Vector3(0.31, 0.04, 0.26))
		box(body, bp, Vector3(0, 0.84, 0), Basis.IDENTITY, Vector3(0.3, 0.05, 0.25))
		for side in [-1.0, 1.0]:
			box(body, dk, Vector3(0.11 * side, 1.26, -0.215), Basis.IDENTITY, Vector3(0.07, 0.17, 0.012))
			body.tube([Vector3(0.04 * side, 1.43, -0.22), Vector3(0.11 * side, 1.47, -0.225), Vector3(0.18 * side, 1.43, -0.22)], [0.018, 0.02, 0.018], bp, {"sides": 5, "per": 2})
			for k in range(4): box(body, bp, Vector3(0.11 * side, 1.15 + k * 0.07, -0.225), Basis(Vector3.RIGHT, 0.5), Vector3(0.068, 0.012, 0.02))
		church_bell(body, bz, Vector3(0, 1.42, -0.08), Vector3.DOWN, 0.14)
		gl.blob(Vector3(0, 1.2, -0.1), Vector3(0.1, 0.05, 0.1), glp, {"lat": 4, "lon": 8})
	else:
		# A gaunt giant under a hooded funeral robe: narrow shoulders, a long sunken chest.
		body.tube([Vector3(0, 0.95, 0), Vector3(0, 1.15, 0), Vector3(0, 1.35, -0.01), Vector3(0, 1.5, 0.01)], [0.17, 0.16, 0.19, 0.17], bp, {"sides": 16, "per": 3, "side": Vector3.BACK, "flat": 0.75, "lump": 0.05})
		body.tube([Vector3(0, 1.48, 0.06), Vector3(0, 1.62, 0.12), Vector3(0, 1.82, 0.08)], [0.2, 0.24, 0.22], bp, {"sides": 14, "per": 3, "lump": 0.06, "cap1": false})
		# A rope girdle with knots.
		var rope := body.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#6a5838").darkened(absf(sin(p.x * 80.0 + p.z * 80.0)) * 0.3))
		body.tube([Vector3(0, 0.98, 0), Vector3(0, 0.96, 0)], [0.18, 0.18], rope, {"sides": 16, "per": 1, "flat": 0.75, "side": Vector3.BACK})
	steel_part(root, "Body", body) if knight else part(root, "Body", body)

	# ---- head (the core glows inside it)
	var head := joint(root, "BellHead", Vector3(0, 1.6, 0))
	var hs := Sculpt.new(); var hp := hs.add_painter(armour); var hb := hs.add_painter(bell_bronze); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#040305"))
	var core_s := Sculpt.new(); var cw := core_s.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	var crown_y := 2.2
	if knight:
		# The helm: a great bell worn mouth-down, a cross-shaped sight cut through it, the
		# canons above as a crest, spikes round its lip.
		church_bell(hs, hb, Vector3(0, 2.02, 0), Vector3.DOWN, 0.24, false)
		hs.blob(Vector3(0, 1.73, 0), Vector3(0.2, 0.08, 0.2), hd, {"lat": 4, "lon": 10})
		core_s.blob(Vector3(0, 1.82, -0.19), Vector3(0.11, 0.016, 0.03), cw, {"lat": 4, "lon": 8, "basis": Basis(Vector3.RIGHT, 0.3)})
		core_s.blob(Vector3(0, 1.79, -0.195), Vector3(0.018, 0.085, 0.03), cw, {"lat": 4, "lon": 8, "basis": Basis(Vector3.RIGHT, 0.3)})
		for k in range(10):
			var a := TAU * k / 10.0
			hs.crystal(Vector3(sin(a) * 0.23, 1.73, cos(a) * 0.23), Vector3(sin(a), -0.5, cos(a)), 0.1, 0.02, hp, 4)
		for side in [-1.0, 1.0]:
			hs.tube([Vector3(0.06 * side, 2.04, 0), Vector3(0.12 * side, 2.2, 0), Vector3(0.05 * side, 2.27, 0)], [0.03, 0.03, 0.026], hb, {"sides": 6, "per": 3})
		crown_y = 2.35
	elif belfry:
		# The spire: an eight-sided slate roof with a lantern stage below it, light in its
		# windows, and an iron weathervane at the top.
		box(hs, hp, Vector3(0, 1.67, 0), Basis.IDENTITY, Vector3(0.17, 0.08, 0.15))
		for side in [-1.0, 1.0]:
			box(hs, hd, Vector3(0.07 * side, 1.68, -0.152), Basis.IDENTITY, Vector3(0.035, 0.05, 0.01))
			core_s.blob(Vector3(0.07 * side, 1.68, -0.155), Vector3(0.03, 0.045, 0.008), cw, {"lat": 4, "lon": 6})
		hs.lathe(Vector3(0, 1.75, 0), [Vector2(0.0, 0.48), Vector2(0.06, 0.34), Vector2(0.15, 0.06), Vector2(0.21, 0.0), Vector2(0.0, 0.0)], hs.add_painter(slate), {"sides": 8, "basis": Basis(Vector3.UP, PI / 8.0)})
		var vane := hs.add_painter(black_iron)
		hs.tube([Vector3(0, 2.2, 0), Vector3(0, 2.4, 0)], [0.008, 0.008], vane, {"sides": 4, "per": 1})
		hs.tube([Vector3(0, 2.35, -0.1), Vector3(0, 2.35, 0.12)], [0.006, 0.006], vane, {"sides": 4, "per": 1})
		hs.blob(Vector3(0, 2.38, 0.02), Vector3(0.012, 0.035, 0.07), vane, {"lat": 4, "lon": 6})
		crown_y = 2.55
	else:
		# A cracked bronze bell for a head, its mouth turned down and forward, dark inside with
		# one eye burning, the clapper hanging out of it like a tongue; the hood behind.
		church_bell(hs, hb, Vector3(0, 2.0, -0.04), Vector3(0, -1, -0.35), 0.21, false)
		hs.blob(Vector3(0, 1.74, -0.08), Vector3(0.14, 0.06, 0.12), hd, {"lat": 4, "lon": 10, "basis": Basis(Vector3.RIGHT, 0.33)})
		crack(hs, hd, Vector3(-0.06, 1.95, -0.1), Vector3(-0.1, 1.76, -0.17), Vector3(0, 0.2, -1), 0.025, 1.0)
		core_s.blob(Vector3(0.04, 1.79, -0.12), Vector3(0.04, 0.032, 0.02), cw, {"lat": 5, "lon": 8})
		var cl := hs.add_painter(black_iron)
		hs.tube([Vector3(0, 1.9, -0.02), Vector3(0.01, 1.74, -0.12), Vector3(-0.01, 1.62, -0.2)], [0.014, 0.014, 0.012], cl, {"sides": 5, "per": 2})
		hs.blob(Vector3(-0.01, 1.6, -0.21), Vector3.ONE * 0.04, cl, {"lat": 4, "lon": 7})
		# The hood: a deep cowl drawn up behind and over the bell, open at the front.
		var hood := hs.add_painter(funeral_cloth)
		hs.blob(Vector3(0, 1.9, 0.16), Vector3(0.27, 0.3, 0.22), hood, {"lat": 10, "lon": 14, "lump": 0.08})
		hs.tube([Vector3(-0.27, 1.64, -0.02), Vector3(0, 2.12, -0.12), Vector3(0.27, 1.64, -0.02)], [0.035, 0.04, 0.035], hood, {"sides": 8, "per": 4})
		crown_y = 2.3
	steel_part(head, "Helm", hs) if knight else part(head, "Head", hs)
	var core := part(head, "BellLight", core_s, glow); core.material_override = glow

	# ---- legs
	var feet: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var h := Vector3(0.15 * side, 0.92, 0.0)
		var hip := joint(root, "%sHip" % ("Left" if side < 0 else "Right"), h)
		var kn := h + Vector3(0.02 * side, -0.42, -0.04)
		var ft := kn + Vector3(0.0, -0.44, 0.04)
		var ls := Sculpt.new(); var lp := ls.add_painter(limb if not belfry else tower_stone)
		if toll:
			# Under the robe: hidden but for the hem.
			ls.tube([h, kn], [0.1, 0.085], lp, {"sides": 8, "per": 2})
		else:
			ls.tube([h, h.lerp(kn, 0.5), kn], [0.15, 0.13, 0.105], lp, {"sides": 12, "per": 2, "flat": 0.9})
		part(hip, "Thigh", ls)
		var knee := joint(hip, "%sKnee" % ("Left" if side < 0 else "Right"), kn)
		var ss := Sculpt.new(); var sp := ss.add_painter(limb if not belfry else tower_stone); var sb := ss.add_painter(bell_bronze)
		if knight:
			ss.blob(kn, Vector3(0.09, 0.08, 0.09), sp, {"lat": 6, "lon": 9})
			rim(ss, sb, kn + Vector3(0, 0, -0.06), Vector3(0, 0, -1), 0.07, 6)
			ss.tube([kn, kn.lerp(ft, 0.5), ft + Vector3(0, 0.06, 0)], [0.1, 0.095, 0.075], sp, {"sides": 12, "per": 2})
			ss.tube([ft + Vector3(0, 0.04, 0.04), ft + Vector3(0, 0.03, -0.14), ft + Vector3(0, 0.025, -0.24)], [0.07, 0.065, 0.03], sp, {"sides": 10, "per": 2, "flat": 1.2, "bands": 4, "band": 0.1})
		elif belfry:
			# Buttress legs: stepped stone piers.
			box(ss, sp, kn.lerp(ft, 0.5), Basis.IDENTITY, Vector3(0.1, 0.24, 0.12))
			box(ss, sp, ft + Vector3(0, 0.05, -0.04), Basis.IDENTITY, Vector3(0.13, 0.05, 0.17))
		else:
			ss.tube([kn, ft + Vector3(0, 0.06, 0)], [0.06, 0.05], sp, {"sides": 8, "per": 2})
			ss.tube([ft + Vector3(0, 0.03, 0.03), ft + Vector3(0, 0.02, -0.16)], [0.045, 0.03], sp, {"sides": 8, "per": 2, "flat": 1.3})
		part(knee, "Shin", ss)
		feet.append(hip); knees.append(knee)

	# ---- arms, and the maul held across the body in both hands
	var arms: Array = []; var forearms: Array = []
	var lh := Vector3(-0.16, 0.98, -0.28); var rh := Vector3(0.16, 1.04, -0.33)
	var d := (rh - lh).normalized()
	var maul_head := rh + d * 0.55
	for side: float in [-1.0, 1.0]:
		var sh := Vector3((0.3 if not toll else 0.24) * side, 1.47, 0.0)
		var arm := joint(root, ("LeftPauldron" if side < 0 else "MaulShoulder"), sh)
		var hand := lh if side < 0 else rh
		var el := sh + Vector3(0.06 * side, -0.27, -0.02)
		var us := Sculpt.new(); var up := us.add_painter(limb); var ub := us.add_painter(bell_bronze); var ua := us.add_painter(armour)
		us.tube([sh, sh.lerp(el, 0.5), el], [0.1 if not toll else 0.065, 0.09 if not toll else 0.06, 0.08 if not toll else 0.055], up, {"sides": 10, "per": 2})
		if knight:
			# Layered pauldron lames, bronze-edged.
			for k in range(3):
				us.blob(sh + Vector3(0.03 * side, 0.06 - k * 0.07, 0), Vector3(0.15 - k * 0.012, 0.06, 0.14), ua, {"lat": 5, "lon": 10})
				rim(us, ub, sh + Vector3(0.03 * side, 0.02 - k * 0.07, 0), Vector3.UP, 0.14 - k * 0.012, 8, 0.2)
		elif belfry:
			# Oak bell-frame beams across the shoulders, iron-strapped.
			box(us, up, sh + Vector3(0.02 * side, 0.08, 0), Basis.IDENTITY, Vector3(0.14, 0.05, 0.12))
			box(us, up, sh + Vector3(0.13 * side, 0.0, 0), Basis.IDENTITY, Vector3(0.03, 0.12, 0.11))
		else:
			us.tube([sh + Vector3(-0.08 * side, 0.08, 0.02), sh + Vector3(0.03 * side, 0.04, 0), sh.lerp(el, 0.6) + Vector3(0.06 * side, 0, 0.02)], [0.1, 0.12, 0.1], ua, {"sides": 10, "per": 2, "cap1": false, "lump": 0.05})
		part(arm, "UpperArm", us)
		var fore := joint(arm, ("LeftElbow" if side < 0 else "MaulElbow"), el)
		var fs := Sculpt.new(); var fp := fs.add_painter(limb); var fb := fs.add_painter(bell_bronze); var fa := fs.add_painter(armour)
		var a := (hand - el).normalized()
		fs.blob(el, Vector3.ONE * (0.075 if not toll else 0.05), fp, {"lat": 5, "lon": 8})
		fs.tube([el, el.lerp(hand, 0.5), hand - a * 0.06], [0.075 if not toll else 0.05, 0.07 if not toll else 0.045, 0.06 if not toll else 0.04], fp, {"sides": 10, "per": 2})
		if knight:
			fs.tube([hand - a * 0.16, hand - a * 0.04], [0.07, 0.085], fa, {"sides": 10, "per": 1, "cap1": false})
		if toll:
			fs.tube([el + a * 0.02, el.lerp(hand, 0.55), el.lerp(hand, 0.8)], [0.09, 0.1, 0.11], fa, {"sides": 10, "per": 2, "cap0": false, "cap1": false, "lump": 0.05})
		var bh := Vector3(0, 0.25, -1).normalized(); bh = (bh - d * d.dot(bh)).normalized()
		grip(fs, fp, hand, d, a, bh, 0.03)
		if side > 0:
			# The maul, its haft running through both fists.
			var mp := fs.add_painter(oak); var mi := fs.add_painter(black_iron); var mb := fs.add_painter(bell_bronze)
			var butt := lh - d * 0.16
			fs.tube([butt, maul_head], [0.03, 0.032], mp, {"sides": 8, "per": 1})
			for k in range(4): fs.tube([butt.lerp(maul_head, 0.15 + k * 0.22), butt.lerp(maul_head, 0.18 + k * 0.22)], [0.036, 0.036], mi, {"sides": 8, "per": 1})
			fs.blob(butt - d * 0.02, Vector3.ONE * 0.045, mi, {"lat": 4, "lon": 6})
			var up_axis := d.cross(Vector3(0, 0, -1)).normalized()
			# The head sits across the haft's end like a hammer's: a bronze bell lying crosswise,
			# its crown on one side of the haft and its mouth on the other.
			var across := up_axis if absf(up_axis.y) > 0.3 else Vector3.UP
			if knight:
				church_bell(fs, mb, maul_head + across * 0.2, -across, 0.17, false)
				fs.blob(maul_head - across * 0.05, Vector3(0.12, 0.12, 0.12), mb, {"lat": 6, "lon": 8})
				fs.crystal(maul_head + across * 0.22, across, 0.12, 0.035, mi, 4)
			elif belfry:
				# A ringer's beetle: a great wooden drum bound with iron hoops.
				fs.tube([maul_head + across * 0.24, maul_head - across * 0.24], [0.15, 0.15], mp, {"sides": 14, "per": 1, "cap_len": 0.2})
				for z: float in [-0.2, 0.0, 0.2]: fs.tube([maul_head + across * (z - 0.02), maul_head + across * (z + 0.02)], [0.158, 0.158], mi, {"sides": 14, "per": 1})
			else:
				church_bell(fs, mb, maul_head + across * 0.18, -across, 0.15, false)
				fs.tube([maul_head + across * 0.18, maul_head + across * 0.42], [0.06, 0.008], mi, {"sides": 6, "per": 2, "cap1": false})
				fs.tube([butt.lerp(maul_head, -0.15), butt], [0.02, 0.03], mp, {"sides": 8, "per": 1})
		part(fore, "Forearm", fs)
		if side > 0:
			var mj := Node3D.new(); mj.name = "OathBellMaul"; fore.add_child(mj); mj.position = maul_head - _world(fore)
		arms.append(arm); forearms.append(fore)
		# Bells hung from the shoulders.
		if not toll:
			swinging_bell(arm, sh + Vector3(0.16 * side, -0.02, -0.08), 0.05, 0.12, bells)
			swinging_bell(arm, sh + Vector3(0.12 * side, -0.04, 0.1), 0.045, 0.16, bells)

	# ---- cloth: a tabard front and back, or the funeral robe, or bell-ropes with sallies
	if knight or toll:
		var front := joint(root, "EmbroideredMidnightTabard", Vector3(0, 1.0, -0.2))
		var fcs := Sculpt.new(); var fcp := fcs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
			var c := funeral_cloth(p, n, v, w)
			# A gold bell embroidered on it, with a border.
			var q := Vector2(p.x, p.y - 0.78)
			var bell: float = smoothstep(0.012, 0.0, absf(Vector2(q.x * 1.3, maxf(q.y, 0.0)).length() - 0.09)) * (1.0 if q.y > -0.03 else 0.0)
			return c.lerp(Color("#c89a40"), maxf(bell, smoothstep(0.92, 0.97, absf(p.x) / 0.2))))
		drape(fcs, fcp, [Vector3(-0.15, 1.02, -0.22), Vector3(-0.05, 1.02, -0.225), Vector3(0.05, 1.02, -0.225), Vector3(0.15, 1.02, -0.22)], 0.75 if knight else 0.9, Vector3(0, 0, -0.05), 0.065, 0.3, 0.3)
		part(front, "Tabard", fcs, cloth_mat)
		cloths.append(front)
		var back := joint(root, "WovenFuneralMantle", Vector3(0, 1.45, 0.2))
		var bcs := Sculpt.new(); var bcp := bcs.add_painter(funeral_cloth)
		var tops: Array = []
		for k in range(8): tops.append(Vector3(lerpf(-0.3, 0.3, k / 7.0), 1.5, 0.2 + 0.04 * sin(k / 7.0 * PI)))
		drape(bcs, bcp, tops, 1.25 if knight else 1.4, Vector3(0, 0, 0.12), 0.06, 0.7, 0.35)
		part(back, "Mantle", bcs, cloth_mat)
		cloths.append(back)
		if toll:
			# The robe's long skirts all round.
			for side in [-1.0, 1.0]:
				var sj := joint(root, ("LeftSplitCloth" if side < 0 else "RightSplitCloth"), Vector3(0.18 * side, 1.0, 0))
				var scs := Sculpt.new(); var scp := scs.add_painter(funeral_cloth)
				drape(scs, scp, [Vector3(0.17 * side, 1.0, -0.12), Vector3(0.2 * side, 1.0, -0.02), Vector3(0.19 * side, 1.0, 0.09)], 0.92, Vector3(0.06 * side, 0, 0), 0.07, side, 0.25)
				part(sj, "Skirt", scs, cloth_mat)
				cloths.append(sj)
			# Handbells on chains at the girdle.
			for k in range(4):
				var a := lerpf(-0.9, 0.9, k / 3.0)
				swinging_bell(root, Vector3(sin(a) * 0.19, 0.96, -cos(a) * 0.14), 0.04, 0.14 + 0.05 * (k % 2), bells)
		else:
			for k in range(3): swinging_bell(root, Vector3(lerpf(-0.18, 0.18, k / 2.0), 0.9, 0.18), 0.04, 0.1 + 0.04 * (k % 2), bells)
	else:
		# Bell-ropes hanging from the shoulder frames, each with its striped sally.
		for side in [-1.0, 1.0]:
			for k in range(2):
				var top := Vector3((0.36 + k * 0.06) * side, 1.5, -0.06 + k * 0.14)
				var rj := joint(root, "BellRope%d" % cloths.size(), top)
				var rs := Sculpt.new(); var rp := rs.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#8a7448").darkened(absf(sin(p.y * 120.0)) * 0.25)); var sp2 := rs.add_painter(sally)
				var l := 0.85 + 0.15 * k
				rs.tube([top, top + Vector3(0.03 * side, -l * 0.5, 0), top + Vector3(0.05 * side, -l, 0.02)], [0.012, 0.012, 0.01], rp, {"sides": 5, "per": 2})
				rs.tube([top + Vector3(0.02 * side, -l * 0.35, 0), top + Vector3(0.03 * side, -l * 0.6, 0.005)], [0.03, 0.03], sp2, {"sides": 8, "per": 3})
				part(rj, "Rope", rs)
				cloths.append(rj)
		for k in range(3): swinging_bell(root, Vector3(lerpf(-0.2, 0.2, k / 2.0), 0.86, -0.24), 0.045, 0.06, bells)
	if gl.triangles() > 0: part(root, "Glow", gl, glow).material_override = glow

	# ---- the awakened crown: a ring of spectral bells over the head, shown when enraged
	var cr := Sculpt.new(); var crp := cr.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for k in range(8):
		var a := TAU * k / 8.0
		church_bell(cr, crp, Vector3(sin(a) * 0.32, crown_y + 0.08, cos(a) * 0.32), Vector3.DOWN, 0.05, false)
	var ring_pts: Array = []; var ring_r: Array = []
	for k in range(33):
		var a := TAU * k / 32.0
		ring_pts.append(Vector3(sin(a) * 0.32, crown_y + 0.08, cos(a) * 0.32)); ring_r.append(0.008)
	cr.tube(ring_pts, ring_r, crp, {"sides": 4, "per": 1})
	var crown := part(root, "AwakenedDawnResonance", cr, crown_mat); crown.material_override = crown_mat
	crown.visible = false

	var giant := root
	root = Node3D.new(); root.name = "TheBellkeeper"
	root.add_child(giant); giant.scale = Vector3.ONE * 2.1
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": feet, "knees": knees, "leaves": []}, 1.0)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["boss_bells"] = bells.map(func (n): return node.get_path_to(n))
	rig["boss_cloth"] = cloths.map(func (n): return node.get_path_to(n))
	rig["phase_crown"] = node.get_path_to(crown)
	rig["boss_jaw"] = null; rig["boss_tail"] = null
	node.set_meta("rig_bindings", rig)
	node.set_meta("actor_properties", {"rest_scale": Vector3.ONE, "normal_glow": glow, "attack_glow": attack_glow, "hurt_glow": hurt_glow, &"body_scale": 1.0})
	return node


# ------------------------------------------------------------------ the Oathbound Bellkeeper

## Gilded bell-bronze, warm gold, engraved in bands with founders' lines, dark in the hollows.
static func gilt_bronze(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var c := Color("#2a1a08").lerp(Color("#b8904a"), clampf(n.y * 0.35 + 0.38 + Sculpt.fbm(p * 9.0) * 0.45, 0.0, 1.0))
	c = c.lerp(Color("#f0d890"), smoothstep(0.62, 0.8, Sculpt.noise(p * 28.0)) * 0.3)
	c = c.lerp(Color("#1e1206"), smoothstep(-0.01, 0.02, absf(fposmod(p.y * 16.0 + Sculpt.noise(p * 3.0) * 0.5, 1.0) - 0.5) - 0.46) * 0.8)
	return c.lerp(Color("#2a6a5a"), smoothstep(0.55, 0.75, Sculpt.noise(p * 6.0 + Vector3(4, 0, 0))) * clampf(0.5 - n.y * 0.5, 0.0, 1.0) * 0.5)


static func midnight(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	var c := Color("#0a1030").lerp(Color("#24306a"), clampf(n.y * 0.25 + 0.35 + Sculpt.fbm(p * 7.0) * 0.35, 0.0, 1.0))
	return c.darkened(v * 0.3)


## A pointed (Gothic) arch from the springing points at `a` and `b`, rising to `peak` above.
func arch(s: Sculpt, painter: int, a: Vector3, b: Vector3, peak: float, r: float) -> void:
	var mid := a.lerp(b, 0.5) + Vector3(0, peak, 0)
	var pts: Array = []; var rr: Array = []
	for k in range(9):
		var t := k / 8.0
		var q: Vector3 = a.lerp(mid, t * 2.0) if t <= 0.5 else mid.lerp(b, t * 2.0 - 1.0)
		var bow := sin(PI * fposmod(t * 2.0, 1.0)) * 0.22 * peak if k != 4 else 0.0
		var out := (q - a.lerp(b, 0.5)); out.y = 0.0
		pts.append(q + out.normalized() * bow * 0.5 + Vector3(0, bow * 0.4, 0) if out.length() > 0.001 else q); rr.append(r)
	s.tube(pts, rr, painter, {"sides": 6, "per": 2})


func _grand() -> Node3D:
	var bells: Array = []; var cloths: Array = []
	var glow_s := Sculpt.new(); var gw := glow_s.add_painter(func (_p, _n, _v, _w): return Color.WHITE)

	# ---- the body: a gilded cuirass with a belfry in its breast
	var body := Sculpt.new(); var gb := body.add_painter(gilt_bronze); var bi := body.add_painter(black_iron)
	var dk := body.add_painter(func (_p, _n, _v, _w): return Color("#06040a"))
	body.tube([Vector3(0, 0.95, 0), Vector3(0, 1.1, -0.01), Vector3(0, 1.32, -0.02), Vector3(0, 1.5, 0)], [0.22, 0.25, 0.38, 0.35], gb, {"sides": 20, "per": 3, "side": Vector3.BACK, "flat": 0.66})
	body.blob(Vector3(0, 1.34, -0.07), Vector3(0.32, 0.17, 0.13), gb, {"lat": 9, "lon": 14})
	# The belfry window: a pointed arch cut deep into the breastplate, iron louvres across it,
	# and a bell of light hanging inside.
	box(body, dk, Vector3(0, 1.26, -0.262), Basis.IDENTITY, Vector3(0.095, 0.13, 0.02))
	body.blob(Vector3(0, 1.39, -0.262), Vector3(0.095, 0.07, 0.02), dk, {"lat": 5, "lon": 8})
	arch(body, gb, Vector3(-0.1, 1.13, -0.285), Vector3(0.1, 1.13, -0.285), 0.36, 0.024)
	church_bell(glow_s, gw, Vector3(0, 1.43, -0.272), Vector3.DOWN, 0.075, false)
	for k in range(4): box(body, bi, Vector3(0, 1.17 + k * 0.06, -0.295), Basis(Vector3.RIGHT, 0.6), Vector3(0.09, 0.007, 0.018))
	# Plackart, waist lames with cusped bronze edges, tassets.
	body.blob(Vector3(0, 1.06, -0.12), Vector3(0.2, 0.11, 0.07), gb, {"lat": 6, "lon": 10})
	for k in range(4):
		var yy := 0.94 - k * 0.06
		body.tube([Vector3(0, yy + 0.032, 0), Vector3(0, yy - 0.032, 0)], [0.23 + k * 0.022, 0.24 + k * 0.022], bi if k % 2 else gb, {"sides": 20, "per": 1, "side": Vector3.BACK, "flat": 0.76})
		rim(body, gb, Vector3(0, yy - 0.034, 0), Vector3.UP, 0.243 + k * 0.022, 16, 0.25)
	for side: float in [-1.0, 1.0]:
		for k in range(3):
			slab(body, gb, Vector3(0.13 * side, 0.74 - k * 0.07, -0.12 - k * 0.008), Vector3(0.17, 0.075, 0.022), Basis(Vector3.RIGHT, -0.15) * Basis(Vector3.BACK, -0.1 * side), 0.4, 0.0)
	# The gorget, layered.
	for k in range(3): body.tube([Vector3(0, 1.48 + k * 0.035, 0), Vector3(0, 1.52 + k * 0.035, 0)], [0.24 - k * 0.04, 0.2 - k * 0.04], gb if k != 1 else bi, {"sides": 18, "per": 1, "side": Vector3.BACK, "flat": 0.85})
	# A belt with bronze plaques.
	body.tube([Vector3(0, 0.99, 0), Vector3(0, 0.96, 0)], [0.27, 0.27], bi, {"sides": 20, "per": 1, "flat": 0.76, "side": Vector3.BACK})
	for k in range(7):
		var a := lerpf(-1.2, 1.2, k / 6.0)
		body.blob(Vector3(sin(a) * 0.27, 0.975, -cos(a) * 0.205), Vector3(0.03, 0.032, 0.012), gb, {"lat": 4, "lon": 6, "basis": Basis(Vector3.UP, -a)})
	steel_part(root, "Body", body)

	# ---- the helm: a great bell worn mouth-down, its face a belfry arch full of light
	var head := joint(root, "BellHead", Vector3(0, 1.6, 0))
	var hs := Sculpt.new(); var hg := hs.add_painter(gilt_bronze); var hi := hs.add_painter(black_iron); var hd := hs.add_painter(func (_p, _n, _v, _w): return Color("#06040a"))
	var core_s := Sculpt.new(); var cw := core_s.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	church_bell(hs, hg, Vector3(0, 2.05, 0), Vector3.DOWN, 0.26, false)
	hs.blob(Vector3(0, 1.73, 0), Vector3(0.22, 0.07, 0.22), hd, {"lat": 4, "lon": 12})
	# The arch in its face, two iron bars across it, the light pouring out.
	hs.blob(Vector3(0, 1.82, -0.17), Vector3(0.11, 0.12, 0.05), hd, {"lat": 6, "lon": 10})
	arch(hs, hg, Vector3(-0.12, 1.72, -0.235), Vector3(0.12, 1.72, -0.235), 0.26, 0.02)
	for side in [-1.0, 1.0]: hs.tube([Vector3(0.04 * side, 1.72, -0.245), Vector3(0.04 * side, 1.93, -0.23)], [0.011, 0.011], hi, {"sides": 5, "per": 1})
	hs.tube([Vector3(-0.11, 1.82, -0.24), Vector3(0.11, 1.82, -0.24)], [0.01, 0.01], hi, {"sides": 5, "per": 1})
	core_s.blob(Vector3(0, 1.81, -0.225), Vector3(0.095, 0.1, 0.02), cw, {"lat": 6, "lon": 10})
	# Spikes round the lip and the sound-bow.
	for k in range(12):
		var a := TAU * (k + 0.5) / 12.0
		if absf(sin(a) + 1.0) < 0.25: continue
		hs.crystal(Vector3(sin(a) * 0.255, 1.73, cos(a) * 0.255), Vector3(sin(a), -0.35, cos(a)), 0.12, 0.022, hi, 4)
	# The crown: the canons standing up round a little spire with a gilt orb and cross.
	for k in range(6):
		var a := TAU * k / 6.0
		var c0 := Vector3(sin(a) * 0.07, 2.06, cos(a) * 0.07)
		hs.tube([c0, c0 + Vector3(sin(a) * 0.05, 0.1, cos(a) * 0.05), c0 + Vector3(sin(a) * 0.02, 0.15, cos(a) * 0.02)], [0.022, 0.02, 0.016], hg, {"sides": 6, "per": 2})
	hs.blob(Vector3(0, 2.12, 0), Vector3.ONE * 0.045, hg, {"lat": 6, "lon": 8})
	# Founders' inscription round the helm's waist, its letters burning with the same light.
	for k in range(22):
		var a := TAU * (k + 0.5) / 22.0
		if cos(a) < -0.55: continue
		var at := Vector3(sin(a) * 0.17, 1.95, cos(a) * 0.17)
		core_s.blob(at, Vector3(0.012, 0.022 + 0.008 * (k % 3), 0.006), cw, {"lat": 3, "lon": 4, "basis": Basis(Vector3.UP, a)})
	steel_part(head, "Helm", hs)
	var core := part(head, "BellLight", core_s, glow); core.material_override = glow

	# ---- legs: gilt cuisses, cusped poleyns, greaves and iron sabatons
	var feet: Array = []; var knees: Array = []
	for side: float in [-1.0, 1.0]:
		var h := Vector3(0.15 * side, 0.9, 0.0)
		var hip := joint(root, "%sArmoredHip" % ("Left" if side < 0 else "Right"), h)
		var kn := h + Vector3(0.025 * side, -0.42, -0.04)
		var ft := kn + Vector3(0.0, -0.42, 0.04)
		var ls := Sculpt.new(); var lg := ls.add_painter(gilt_bronze); var li := ls.add_painter(black_iron)
		ls.tube([h, h.lerp(kn, 0.5), kn], [0.16, 0.14, 0.11], li, {"sides": 14, "per": 2, "flat": 0.9})
		ls.tube([h + Vector3(0, -0.02, 0), h + Vector3(0, -0.06, 0)], [0.165, 0.16], lg, {"sides": 14, "per": 1, "flat": 0.9})
		part(hip, "Cuisse", ls)
		var knee := joint(hip, "%sGreave" % ("Left" if side < 0 else "Right"), kn)
		var ss := Sculpt.new(); var sg := ss.add_painter(gilt_bronze); var si := ss.add_painter(black_iron)
		ss.blob(kn, Vector3(0.1, 0.09, 0.1), sg, {"lat": 6, "lon": 9})
		rim(ss, sg, kn + Vector3(0, 0, -0.07), Vector3(0, 0, -1), 0.08, 6, 0.3)
		ss.crystal(kn + Vector3(0, 0, -0.08), Vector3(0, 0.2, -1), 0.1, 0.03, sg, 4)
		ss.tube([kn, kn.lerp(ft, 0.5), ft + Vector3(0, 0.07, 0)], [0.11, 0.1, 0.08], si, {"sides": 14, "per": 2})
		rim(ss, sg, ft + Vector3(0, 0.09, 0), Vector3.UP, 0.085, 8, 0.25)
		ss.tube([ft + Vector3(0, 0.04, 0.05), ft + Vector3(0, 0.035, -0.12), ft + Vector3(0, 0.025, -0.26)], [0.085, 0.075, 0.035], si, {"sides": 10, "per": 2, "flat": 1.25, "bands": 5, "band": 0.12})
		part(knee, "Greave", ss)
		feet.append(hip); knees.append(knee)

	# ---- arms with great spiked pauldrons carrying bell-frames, and the maul in both hands
	var arms: Array = []; var forearms: Array = []
	var lh := Vector3(-0.17, 0.98, -0.32); var rh := Vector3(0.17, 1.05, -0.37)
	var d := (rh - lh).normalized()
	var maul_head := rh + d * 0.62
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.33 * side, 1.48, 0.0)
		var arm := joint(root, ("LeftPauldron" if side < 0 else "MaulShoulder"), sh)
		var hand := lh if side < 0 else rh
		var el := sh + Vector3(0.07 * side, -0.29, -0.03)
		var us := Sculpt.new(); var ug := us.add_painter(gilt_bronze); var ui := us.add_painter(black_iron); var uo := us.add_painter(oak)
		us.tube([sh, sh.lerp(el, 0.5), el], [0.11, 0.1, 0.09], ui, {"sides": 10, "per": 2})
		# Three tiers of gilt lames, the top one ridged with tall spikes.
		for k in range(3):
			var lc := sh + Vector3((0.04 + k * 0.035) * side, 0.08 - k * 0.07, 0)
			us.blob(lc, Vector3(0.2 - k * 0.012, 0.05, 0.18 - k * 0.01), ug if k != 1 else ui, {"lat": 6, "lon": 12, "basis": Basis(Vector3.BACK, -0.35 * side)})
			rim(us, ug, lc + Vector3(0.03 * side, -0.04, 0), Vector3(0.35 * side, 1, 0).normalized(), 0.19 - k * 0.012, 9, 0.25)
		for k in range(3):
			us.crystal(sh + Vector3((0.02 + k * 0.08) * side, 0.14, -0.06 + k * 0.06), Vector3(0.25 * side, 1, 0.05), 0.18 - k * 0.03, 0.03, ui, 4)
		# A little bell-frame of oak and iron along the outer edge, bells swinging in it.
		var f0 := sh + Vector3(0.22 * side, 0.0, -0.12); var f1 := sh + Vector3(0.22 * side, 0.0, 0.12)
		box(us, uo, f0.lerp(f1, 0.5) + Vector3(0, -0.02, 0), Basis.IDENTITY, Vector3(0.025, 0.025, 0.15))
		for e: Vector3 in [f0, f1]: box(us, ui, e + Vector3(-0.02 * side, 0.04, 0), Basis.IDENTITY, Vector3(0.012, 0.06, 0.012))
		part(arm, "Pauldron", us)
		swinging_bell(arm, f0.lerp(f1, 0.25) + Vector3(0, -0.045, 0), 0.055, 0.05, bells)
		swinging_bell(arm, f0.lerp(f1, 0.75) + Vector3(0, -0.045, 0), 0.05, 0.08, bells)
		var fore := joint(arm, ("LeftElbow" if side < 0 else "MaulElbow"), el)
		var fs := Sculpt.new(); var fg := fs.add_painter(gilt_bronze); var fi := fs.add_painter(black_iron)
		var a := (hand - el).normalized()
		fs.blob(el, Vector3.ONE * 0.085, fg, {"lat": 6, "lon": 9})
		rim(fs, fi, el + Vector3(0.04 * side, 0, 0), Vector3(side, 0, 0), 0.075, 6, 0.3)
		fs.tube([el, el.lerp(hand, 0.5), hand - a * 0.07], [0.08, 0.075, 0.066], fi, {"sides": 12, "per": 2})
		rim(fs, fg, el.lerp(hand, 0.55), a, 0.08, 8, 0.2)
		fs.tube([hand - a * 0.18, hand - a * 0.05], [0.075, 0.095], fi, {"sides": 12, "per": 1, "cap1": false})
		var bh := Vector3(0, 0.25, -1).normalized(); bh = (bh - d * d.dot(bh)).normalized()
		grip(fs, fi, hand, d, a, bh, 0.034)
		if side > 0:
			# The Oath-Bell Maul: an iron-banded oak haft running through both fists, a gilt sun
			# at its collar, and for a head a great bell lying crosswise with a spiked iron
			# hammer-face opposite it.
			var mo := fs.add_painter(oak); var mg := fs.add_painter(gilt_bronze); var mi := fs.add_painter(black_iron)
			var butt := lh - d * 0.2
			fs.tube([butt, maul_head], [0.034, 0.037], mo, {"sides": 8, "per": 1})
			for k in range(5): fs.tube([butt.lerp(maul_head, 0.12 + k * 0.19), butt.lerp(maul_head, 0.15 + k * 0.19)], [0.04, 0.04], mg if k % 2 == 0 else mi, {"sides": 8, "per": 1})
			fs.blob(butt - d * 0.03, Vector3.ONE * 0.05, mg, {"lat": 5, "lon": 7})
			var across := Vector3.UP - d * d.dot(Vector3.UP); across = across.normalized()
			church_bell(fs, mg, maul_head + across * 0.26, -across, 0.22, false)
			fs.blob(maul_head - across * 0.02, Vector3.ONE * 0.1, mg, {"lat": 6, "lon": 9})
			fs.tube([maul_head - across * 0.04, maul_head - across * 0.22], [0.08, 0.1], mi, {"sides": 4, "per": 1, "cap_len": 0.15})
			for k in range(4):
				var off := (d * (0.06 if k % 2 == 0 else -0.06) + d.cross(across) * (0.06 if k < 2 else -0.06))
				fs.crystal(maul_head - across * 0.24 + off, -across, 0.07, 0.02, mi, 4)
			var sun := maul_head - d * 0.2
			fs.tube([sun - d * 0.015, sun + d * 0.015], [0.08, 0.08], mg, {"sides": 16, "per": 1})
			for k in range(8):
				var ang := TAU * k / 8.0
				var ray := (across * cos(ang) + d.cross(across) * sin(ang))
				fs.crystal(sun + ray * 0.075, ray, 0.05, 0.012, mg, 3)
		part(fore, "Vambrace", fs)
		if side > 0:
			var mj := Node3D.new(); mj.name = "OathBellMaul"; fore.add_child(mj); mj.position = maul_head - _world(fore)
		arms.append(arm); forearms.append(fore)

	# ---- cloth: the embroidered tabard, side panels, the funeral mantle, and bell-ropes
	var emblem := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c := midnight(p, n, v, w)
		# A gold sun with a bell inside it, and a gold border down each side.
		var q := Vector2(p.x, p.y - 0.72)
		var r := q.length()
		var ring := smoothstep(0.012, 0.0, absf(r - 0.08))
		var rays := smoothstep(0.08, 0.1, r) * smoothstep(0.14, 0.11, r) * smoothstep(0.6, 0.95, cos(atan2(q.y, q.x) * 12.0))
		var bell := smoothstep(0.01, 0.0, absf(Vector2(q.x * 1.4, maxf(q.y + 0.02, 0.0)).length() - 0.05)) * (1.0 if q.y > -0.03 else 0.0)
		var border := smoothstep(0.85, 0.95, absf(p.x) / 0.19)
		return c.lerp(Color("#d8a848"), clampf(ring + rays + bell + border, 0.0, 1.0))
	var front := joint(root, "EmbroideredMidnightTabard", Vector3(0, 1.0, -0.24))
	var fcs := Sculpt.new(); var fcp := fcs.add_painter(emblem)
	var tops: Array = []
	for k in range(5): tops.append(Vector3(lerpf(-0.16, 0.16, k / 4.0), 0.99, -0.255))
	drape(fcs, fcp, tops, 0.72, Vector3(0, 0, -0.05), 0.06, 0.3, 0.15)
	part(front, "Tabard", fcs, cloth_mat)
	cloths.append(front)
	for side in [-1.0, 1.0]:
		var sj := joint(root, ("LeftSplitCloth" if side < 0 else "RightSplitCloth"), Vector3(0.25 * side, 0.98, 0.0))
		var scs := Sculpt.new(); var scp := scs.add_painter(midnight); var rp := scs.add_painter(func (p: Vector3, _n, _v, _w) -> Color: return Color("#8a7448").darkened(absf(sin(p.y * 120.0)) * 0.25)); var sp2 := scs.add_painter(sally)
		drape(scs, scp, [Vector3(0.24 * side, 0.98, -0.1), Vector3(0.27 * side, 0.98, 0.0), Vector3(0.25 * side, 0.98, 0.1)], 0.55, Vector3(0.05 * side, 0, 0), 0.06, side, 0.3)
		# A bell-rope looped from the belt, its striped sally hanging.
		var top := Vector3(0.22 * side, 0.97, -0.17)
		scs.tube([top, top + Vector3(0.03 * side, -0.25, -0.02), top + Vector3(0.05 * side, -0.62, 0.0)], [0.014, 0.014, 0.012], rp, {"sides": 5, "per": 2})
		scs.tube([top + Vector3(0.02 * side, -0.18, -0.015), top + Vector3(0.035 * side, -0.42, -0.012)], [0.034, 0.034], sp2, {"sides": 8, "per": 3})
		part(sj, "SideCloth", scs, cloth_mat)
		cloths.append(sj)
	var back := joint(root, "WovenFuneralMantle", Vector3(0, 1.5, 0.22))
	var bcs := Sculpt.new(); var bcp := bcs.add_painter(midnight); var bgp := bcs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return midnight(p, n, v, w).lerp(Color("#c8983c"), 0.7))
	var mt: Array = []
	for k in range(10): mt.append(Vector3(lerpf(-0.42, 0.42, k / 9.0), 1.53, 0.2 + 0.07 * sin(k / 9.0 * PI)))
	drape(bcs, bcp, mt, 1.45, Vector3(0, 0, 0.22), 0.07, 0.7, 0.3)
	bcs.tube(mt, [0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03], bgp, {"sides": 6, "per": 1})
	part(back, "Mantle", bcs, cloth_mat)
	cloths.append(back)
	for k in range(3): swinging_bell(root, Vector3(lerpf(-0.2, 0.2, k / 2.0), 0.93, 0.21), 0.05, 0.08 + 0.05 * (k % 2), bells)
	part(root, "BelfryLight", glow_s, glow).material_override = glow

	# ---- the great bell of the town, carried on its back in a belfry arch of oak and iron
	# rising over its shoulders, the bell hung from the apex with its inscription alight.
	var fr := Sculpt.new(); var fo := fr.add_painter(oak); var fi2 := fr.add_painter(black_iron); var fg2 := fr.add_painter(gilt_bronze)
	var z := 0.4
	for k in range(2):
		var off := -0.05 + k * 0.1
		arch(fr, fo, Vector3(-0.46, 1.45, z + off), Vector3(0.46, 1.45, z + off), 0.98, 0.05)
	for side in [-1.0, 1.0]:
		fr.tube([Vector3(0.28 * side, 1.42, 0.16), Vector3(0.46 * side, 1.46, z)], [0.05, 0.045], fi2, {"sides": 6, "per": 1})
		for k in range(4): fr.crystal(Vector3((0.5 - k * 0.07) * side, 1.62 + k * 0.19, z), Vector3(side, 0.5, 0), 0.15 - k * 0.02, 0.03, fi2, 4)
	fr.tube([Vector3(-0.16, 2.37, z), Vector3(0.16, 2.37, z)], [0.05, 0.05], fo, {"sides": 8, "per": 1})
	fr.blob(Vector3(0, 2.5, z), Vector3.ONE * 0.06, fg2, {"lat": 6, "lon": 8})
	fr.tube([Vector3(0, 2.54, z), Vector3(0, 2.72, z)], [0.013, 0.013], fg2, {"sides": 4, "per": 1})
	fr.tube([Vector3(-0.06, 2.66, z), Vector3(0.06, 2.66, z)], [0.011, 0.011], fg2, {"sides": 4, "per": 1})
	part(root, "BelfryArch", fr)
	var gj := joint(root, "GreatBell", Vector3(0, 2.36, z))
	var gbs := Sculpt.new(); var gbp := gbs.add_painter(gilt_bronze)
	church_bell(gbs, gbp, Vector3(0, 2.36, z), Vector3.DOWN, 0.32, true)
	part(gj, "Bell", gbs, bronze_mat)
	var ins := Sculpt.new(); var inw := ins.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for k in range(26):
		var a := TAU * (k + 0.5) / 26.0
		var rr := 0.32 * 0.63
		ins.blob(Vector3(sin(a) * rr, 2.36 - 0.32 * 1.25 * 0.48, z + cos(a) * rr), Vector3(0.016, 0.03 + 0.01 * (k % 3), 0.007), inw, {"lat": 3, "lon": 4, "basis": Basis(Vector3.UP, a)})
	part(gj, "Inscription", ins, glow).material_override = glow
	bells.append(gj)


	# ---- the awakened crown: a turning ring of spectral bells over the helm
	var cr := Sculpt.new(); var crp := cr.add_painter(func (_p, _n, _v, _w): return Color.WHITE)
	for k in range(10):
		var a := TAU * k / 10.0
		church_bell(cr, crp, Vector3(sin(a) * 0.6, 2.85, cos(a) * 0.6 + 0.2), Vector3.DOWN, 0.07, false)
	var ring_pts: Array = []; var ring_r: Array = []
	for k in range(41):
		var a := TAU * k / 40.0
		ring_pts.append(Vector3(sin(a) * 0.6, 2.85, cos(a) * 0.6 + 0.2)); ring_r.append(0.012)
	cr.tube(ring_pts, ring_r, crp, {"sides": 4, "per": 1})
	var crown := part(root, "AwakenedDawnResonance", cr, crown_mat); crown.material_override = crown_mat
	crown.visible = false

	var giant := root
	root = Node3D.new(); root.name = "TheBellkeeper"
	root.add_child(giant); giant.scale = Vector3.ONE * 2.05
	var node := _finish({"head": head, "core": core, "arms": arms, "forearms": forearms, "feet": feet, "knees": knees, "leaves": []}, 1.0)
	var rig: Dictionary = node.get_meta("rig_bindings")
	rig["boss_bells"] = bells.map(func (n): return node.get_path_to(n))
	rig["boss_cloth"] = cloths.map(func (n): return node.get_path_to(n))
	rig["phase_crown"] = node.get_path_to(crown)
	rig["boss_jaw"] = null; rig["boss_tail"] = null
	node.set_meta("rig_bindings", rig)
	node.set_meta("actor_properties", {"rest_scale": Vector3.ONE, "normal_glow": glow, "attack_glow": attack_glow, "hurt_glow": hurt_glow, &"body_scale": 1.0})
	return node
