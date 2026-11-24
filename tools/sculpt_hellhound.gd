extends "res://tools/sculpt_furnace_hound.gd"
## The Furnace Hound as a true hellhound, sculpted by hand: built on the lean, long-legged grey
## wolf, bigger than a man at the shoulder, its charred black hide split by lava, burning eyes
## and a snarling mouth full of fire, white-hot paws and real flames for a mane. Three designs:
##   cerberus - three heads on three necks, the hound that guards the gates of the underworld
##              in Greek myth, each with a burning mane and a spiked iron collar
##   bone     - the skin burnt away over its ribs and muzzle: a bare skull with fire in the eye
##              sockets, a ribcage with the furnace roaring inside, vertebrae standing out
##              along its spine and a tail of fire
##   infernal - great curling horns, a mane and tail of flame, obsidian spikes down its back and
##              lava drooling from its jaws

const BONE_C := Color("#d8ccb0")

var flame_mat: StandardMaterial3D


func _init() -> void:
	super()
	flame_mat = StandardMaterial3D.new()
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "Hellhound"
	kind = variant
	_eyes(Color("#ff5a1a"))
	glow.emission_energy_multiplier = 2.2
	o = {"sh": 0.9, "hp": 0.8, "chest": 0.21, "waist": 0.14, "hipr": 0.15, "neck": 0.14, "head": 1.25, "muzzle": 0.23, "ear": 0.13, "round_ears": false, "tail": 0.6, "leg": 1.28, "bulk": 1.2}
	match variant:
		"cerberus": return _cerberus()
		"bone": return _bone()
		"infernal": return _infernal()
	return null


# ------------------------------------------------------------------ painters and pieces

## Flame: white-hot at the root, through yellow and orange to red, fading to smoke at the tip.
static func flame(p: Vector3, _n: Vector3, v: float, _w: float) -> Color:
	var f := clampf(v + Sculpt.noise(p * 9.0) * 0.15, 0.0, 1.0)
	if f < 0.25: return Color("#fff3c0").lerp(Color("#ffc23a"), f / 0.25)
	if f < 0.6: return Color("#ffc23a").lerp(Color("#ff5a14"), (f - 0.25) / 0.35)
	if f < 0.85: return Color("#ff5a14").lerp(Color("#a01808"), (f - 0.6) / 0.25)
	return Color("#a01808").lerp(Color("#2a1410"), (f - 0.85) / 0.15)


static func bone_c(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return BONE_C.lerp(Color("#6b5a44"), clampf(0.2 - n.y * 0.25 + Sculpt.fbm(p * 14.0) * 0.5, 0.0, 1.0)).lerp(Color("#1a1210"), smoothstep(0.55, 0.75, Sculpt.noise(p * 26.0)) * 0.5)


## A tongue of flame from `base` along `dir`, flickering side to side.
func tongue_of_fire(s: Sculpt, painter: int, base: Vector3, dir: Vector3, length: float, width: float, seed: float) -> void:
	var d := dir.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var a := base + d * length * 0.3 + side * 0.03 * sin(seed * 2.3)
	var b := base + d * length * 0.62 - side * 0.035 * sin(seed * 1.7)
	s.tube([base - d * 0.02, a, b, base + d * length], [width, width * 0.85, width * 0.5, 0.004], painter, {"sides": 7, "per": 3, "cap1": false})


## A mane of flame along the top of the neck and shoulders, each tongue its own swaying joint.
func fire_mane(parts: Dictionary, from_z: float, to_z: float, count: int, length: float) -> void:
	for k in range(count):
		var t := k / float(count - 1)
		var z := lerpf(from_z, to_z, t)
		var at: Vector3
		if z < -0.44: at = Vector3(0, float(o.sh) + 0.02 + (-0.44 - z) * 0.65, z)
		else:
			var b: Array = body_at(z)
			at = (b[0] as Vector3) + Vector3(0, float(b[1]) * 0.9, 0)
		var j := joint(root, "Flame%d" % k, at)
		var fs := Sculpt.new(); var fp := fs.add_painter(flame)
		var l := length * (0.65 + 0.5 * sin(PI * t)) * (0.85 + 0.3 * fposmod(k * 0.618, 1.0))
		tongue_of_fire(fs, fp, at, Vector3(0.25 * sin(k * 2.1), 1.0, 0.75), l, 0.045, k)
		if k % 2 == 0:
			for side: float in [-1.0, 1.0]: tongue_of_fire(fs, fp, at + Vector3(0.05 * side, -0.02, 0.02), Vector3(0.6 * side, 0.9, 0.6), l * 0.7, 0.035, k + side)
		part(j, "Fire", fs, flame_mat)
		parts.fronds.append(j)


## Flames streaming from the end of the tail.
func fire_tail(parts: Dictionary) -> void:
	var tip: Vector3 = parts.tail_tip
	var fs := Sculpt.new(); var fp := fs.add_painter(flame)
	for k in range(5):
		var a := TAU * k / 5.0
		tongue_of_fire(fs, fp, tip + Vector3(cos(a) * 0.03, 0.02, sin(a) * 0.03), Vector3(cos(a) * 0.5, 0.9, 0.5 + sin(a) * 0.4), 0.22 + 0.06 * (k % 2), 0.045, k)
	part(parts.tails[0], "Fire", fs, flame_mat)


## A row of spikes standing up along the spine.
func spine_spikes(painter: Callable, count: int, length: float, mat: Material = null) -> void:
	var s := Sculpt.new(); var sp := s.add_painter(painter)
	for k in range(count):
		var z := lerpf(-0.36, 0.4, k / float(count - 1))
		var b: Array = body_at(z)
		var at: Vector3 = (b[0] as Vector3) + Vector3(0, float(b[1]) * 0.85, 0)
		var l := length * (1.0 - absf(k - count * 0.3) / count)
		s.crystal(at, Vector3(0, 1.0, 0.55), l, 0.028, sp, 5, 0.3)
	part(root, "Spikes", s, mat if mat != null else material)


## A spiked iron collar round a neck at `c`, facing along `axis`.
func spiked_collar(s: Sculpt, painter: int, c: Vector3, axis: Vector3, radius: float) -> void:
	var a := axis.normalized(); var u := a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized(); var v := a.cross(u)
	var ring: Array = []; var rr: Array = []
	for k in range(17):
		var t := TAU * k / 16.0
		ring.append(c + (u * cos(t) + v * sin(t)) * radius); rr.append(0.022)
	s.tube(ring, rr, painter, {"sides": 7, "per": 2})
	for k in range(8):
		var t := TAU * k / 8.0
		var out := (u * cos(t) + v * sin(t))
		s.crystal(c + out * radius, out, 0.06, 0.014, painter, 4)


static func iron(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return Color("#2a2624").lerp(Color("#6a5a4c"), clampf(n.y * 0.3 + 0.3 + Sculpt.noise(p * 30.0) * 0.3, 0.0, 1.0))


# ------------------------------------------------------------------ A: cerberus

func _cerberus() -> Node3D:
	var parts := canid(char_hide, true)
	var sh: float = o.sh; var hk: float = o.head
	var b: Sculpt = parts.body; var bp: int = parts.body_painter
	part(root, "EmberSpots", ember_spots(10, 0.018, 0.5), ember_mat)
	fire_mane(parts, -0.58, -0.05, 9, 0.24)
	fire_tail(parts)
	var irons := Sculpt.new(); var ip := irons.add_painter(iron)
	spiked_collar(irons, ip, Vector3(0, sh + 0.04, -0.5), Vector3(0, 0.5, -1), 0.15)
	# Two more heads on their own necks, either side of the first, turned outwards.
	var head: Node3D = parts.head
	var hw := _world(head)
	for side: float in [-1.0, 1.0]:
		var off := Vector3(0.22 * side, -0.08, 0.12)
		b.tube([Vector3(0.1 * side, sh - 0.06, -0.34), Vector3(0.17 * side, sh - 0.02, -0.46), hw + off + Vector3(0, -0.02, 0.06)], [0.12, 0.11, 0.1], bp, {"sides": 12, "per": 3})
		spiked_collar(irons, ip, Vector3(0.16 * side, sh - 0.02, -0.45), Vector3(0.4 * side, 0.4, -1), 0.13)
		var holder := Node3D.new(); holder.name = "HeadLeft" if side < 0 else "HeadRight"
		head.add_child(holder)
		holder.position = off; holder.rotation.y = -0.4 * side; holder.scale = Vector3.ONE * 0.88
		var hd := head_sculpts(char_hide, sh + 0.14, -0.62, hk)
		for spec in [["Head", hd.hs, material], ["Jaw", hd.js, material], ["ThroatFire", hd.fs, ember_mat], ["Eyes", hd.es, glow]]:
			var m := MeshInstance3D.new(); m.name = "Side" + str(spec[0]); holder.add_child(m)
			if spec[0] == "Jaw":
				m.mesh = (spec[1] as Sculpt).commit(spec[2], hd.jaw_at); m.position = hd.jaw_at - hw; m.rotation.x = -0.32
			else: m.mesh = (spec[1] as Sculpt).commit(spec[2], hw)
			if spec[0] == "Eyes": m.material_override = glow
		# Pointed ears and a flaming crest on each side head.
		var xs := Sculpt.new(); var xb := xs.add_painter(char_hide); var fp := xs.add_painter(flame)
		for e: float in [-1.0, 1.0]:
			var base := Vector3(0.06 * e * hk, sh + 0.14 + 0.06 * hk, -0.6)
			xs.tube([base, base + Vector3(0.025 * e, 0.08, 0.0), base + Vector3(0.04 * e, 0.16, 0.01)], [0.06, 0.04, 0.004], xb, {"sides": 8, "per": 2, "flat": 0.4, "side": Vector3.BACK, "cap1": false})
		var m2 := MeshInstance3D.new(); m2.name = "Ears"; m2.mesh = xs.commit(material, hw); holder.add_child(m2)
		var fs := Sculpt.new(); var ffp := fs.add_painter(flame)
		for k in range(4): tongue_of_fire(fs, ffp, Vector3(0, sh + 0.24, -0.58 + k * 0.06), Vector3(0.2 * sin(k * 2.0), 1.0, 0.7), 0.2 - k * 0.02, 0.04, k + side)
		var m3 := MeshInstance3D.new(); m3.name = "Fire"; m3.mesh = fs.commit(flame_mat, hw); holder.add_child(m3)
	part(root, "Collars", irons, iron_mat)
	return _snarl(_close(parts, 1.45))


# ------------------------------------------------------------------ B: bone hound

func _bone() -> Node3D:
	# The skin burnt off the face: bone in front of the eyes, charred hide behind.
	var skull := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return char_hide(p, n, v, w).lerp(bone_c(p, n, v, w), smoothstep(-0.7, -0.76, p.z) if p.y > 0.8 else 0.0)
	var parts := canid(char_hide, true)
	var sh: float = o.sh; var hk: float = o.head
	var hd := head_sculpts(skull, sh + 0.14, -0.62, hk)
	parts["head_sculpt"] = hd.hs; parts["jaw_sculpt"] = hd.js
	# Empty eye sockets with fire in them, instead of eyes.
	var es: Sculpt = parts.core_sculpt
	for side: float in [-1.0, 1.0]:
		es.blob(Vector3(0.057 * side * hk, sh + 0.14 + 0.02 * hk, -0.62 - 0.09 * hk), Vector3(0.028, 0.02, 0.012) * hk, 0, {"lat": 5, "lon": 8})
	# The ribcage: bare ribs over each flank with the furnace glowing between them.
	var rs := Sculpt.new(); var rp := rs.add_painter(bone_c)
	var fire := Sculpt.new(); var fp := fire.add_painter(ember)
	for side: float in [-1.0, 1.0]:
		for k in range(6):
			var z := lerpf(-0.26, 0.12, k / 5.0)
			var pts: Array = []; var rr: Array = []
			for j in range(6):
				var a := side * lerpf(0.35, 2.3, j / 5.0)
				var hpnt: Array = hide_point(z + j * 0.015, a, 1.07)
				pts.append(hpnt[0]); rr.append(0.016 - j * 0.0015)
			rs.tube(pts, rr, rp, {"sides": 6, "per": 2, "cap_rings": 1})
		# A dark hollow behind the ribs, with fire glowing in the gaps between them.
		var hollow := rs.add_painter(func (p, n, v, w): return Color("#0a0606"))
		var g: Array = hide_point(-0.07, side * 1.3, 0.99)
		rs.blob(g[0], Vector3(0.05, 0.13, 0.2), hollow, {"lat": 6, "lon": 9})
		for k in range(5):
			var z := lerpf(-0.26, 0.12, (k + 0.5) / 5.0)
			var pts: Array = []; var rr: Array = []
			for j in range(4):
				var hpnt: Array = hide_point(z + j * 0.012, side * lerpf(0.75, 1.9, j / 3.0), 1.03)
				pts.append(hpnt[0]); rr.append(0.012)
			fire.tube(pts, rr, fp, {"sides": 5, "per": 2, "cap_rings": 1, "flat": 0.5})
	# Vertebrae standing out along the spine.
	for k in range(14):
		var z := lerpf(-0.5, 0.42, k / 13.0)
		var b: Array = body_at(maxf(z, -0.44))
		var at: Vector3 = (b[0] as Vector3) + Vector3(0, float(b[1]) * 0.95, 0)
		if z < -0.44: at = Vector3(0, sh + 0.02 + (-0.44 - z) * 0.6, z)
		rs.blob(at, Vector3(0.03, 0.025, 0.028), rp, {"lat": 4, "lon": 6})
		rs.crystal(at, Vector3(0, 1, 0.5), 0.07 + 0.03 * sin(PI * k / 13.0), 0.016, rp, 4)
	part(root, "Bones", rs)
	part(root, "Furnace", fire, ember_mat)
	fire_mane(parts, -0.58, -0.2, 5, 0.18)
	fire_tail(parts)
	return _snarl(_close(parts, 1.45))


# ------------------------------------------------------------------ C: infernal

func _infernal() -> Node3D:
	var parts := canid(char_hide, true)
	var sh: float = o.sh; var hk: float = o.head
	var hy := sh + 0.14; var hz := -0.62
	part(root, "EmberSpots", ember_spots(14, 0.02, 0.3), ember_mat)
	fire_mane(parts, -0.58, 0.05, 11, 0.26)
	fire_tail(parts)
	spine_spikes(func (p, n, v, w): return Color("#0d0c10").lerp(Color("#3a3446"), clampf(n.y * 0.4 + 0.2, 0.0, 1.0)).lerp(Color("#ff6a1a"), smoothstep(0.0, 0.15, 0.15 - v) * 0.0), 9, 0.16)
	# Great horns sweeping back from the brow and curling up, ridged, glowing at the base.
	var hs := Sculpt.new(); var hp := hs.add_painter(func (p: Vector3, n: Vector3, v: float, w: float) -> Color: return Color("#1a1512").lerp(Color("#5a4a3e"), v * 0.7 + clampf(n.y, 0.0, 1.0) * 0.2).darkened(clampf(-w, 0.0, 1.0) * 0.3))
	for side: float in [-1.0, 1.0]:
		var base := Vector3(0.055 * side * hk, hy + 0.07 * hk, hz - 0.02)
		hs.tube([base, base + Vector3(0.07 * side, 0.08, 0.06), base + Vector3(0.12 * side, 0.12, 0.17), base + Vector3(0.13 * side, 0.08, 0.28), base + Vector3(0.11 * side, 0.12, 0.34)], [0.04, 0.034, 0.026, 0.016, 0.003], hp, {"sides": 9, "per": 3, "ridges": 9, "ridge": 0.08, "cap1": false})
	part(parts.head, "Horns", hs)
	# Lava drooling from the corners of its mouth.
	var ds := Sculpt.new(); var dp := ds.add_painter(ember)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.045 * side * hk, hy - 0.08 * hk, hz - 0.06 * hk - float(o.muzzle) * 0.6)
		ds.tube([at, at + Vector3(0.005 * side, -0.06, 0.0), at + Vector3(0.008 * side, -0.11, 0.01)], [0.012, 0.009, 0.006], dp, {"sides": 5, "per": 2})
		ds.blob(at + Vector3(0.008 * side, -0.125, 0.01), Vector3(0.012, 0.016, 0.012), dp, {"lat": 4, "lon": 6})
	part(parts.head, "Drool", ds, ember_mat)
	return _snarl(_close(parts, 1.45))
