extends "res://tools/creature_kit.gd"
## The Frost Brute, sculpted by hand: a huge troll of the snowy heights that bowls in with a
## freezing breath. About two and a half times Mr. Justice's height.

const SNOW := Color("#eef3f7")
const SNOW_SHADE := Color("#b9c8d6")
const ICE_LOW := Color("#4f8fb8")
const ICE_HIGH := Color("#d8f3ff")
const FROST_SKIN := Color("#5f7f96")
const FROST_SKIN_DARK := Color("#34495a")
const TROLL_STONE := Color("#4f5964")
const TROLL_STONE_DARK := Color("#272d33")
const YETI_FUR := Color("#dfe6ec")
const YETI_SHADE := Color("#9fb0bf")
const TUSK_IVORY := Color("#efe6cf")
const ICE_GLOW := Color("#8fe3ff")

var ice_mat: StandardMaterial3D


func _init() -> void:
	super("res://assets/cast/stone_detail_gray.png")
	material.uv1_scale = Vector3(2.5, 2.5, 2.5)
	glow.albedo_color = ICE_GLOW.darkened(0.2); glow.emission = ICE_GLOW
	glow.emission_energy_multiplier = 1.1
	ice_mat = gloss.duplicate()
	ice_mat.emission = Color("#3d6f8f")
	ice_mat.emission_energy_multiplier = 0.5


static func ice(p: Vector3, n: Vector3, v: float, _w: float) -> Color:
	return ICE_LOW.lerp(ICE_HIGH, clampf(v * 0.9 + n.y * 0.3 + Sculpt.noise(p * 6.0) * 0.25, 0.0, 1.0))


## Snow settles on anything facing up.
static func snowy(base: Callable) -> Callable:
	return func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var c: Color = base.call(p, n, v, w)
		var snow := smoothstep(0.55, 0.8, n.y + 0.3 * Sculpt.fbm(p * 4.0))
		return c.lerp(SNOW.lerp(SNOW_SHADE, clampf(0.5 - n.y * 0.5 + Sculpt.noise(p * 15.0) * 0.3, 0.0, 1.0)), snow)


static func troll_stone(p: Vector3, n: Vector3, _v: float, w: float) -> Color:
	var grain := Sculpt.fbm(p * 3.0)
	var c := TROLL_STONE.lerp(TROLL_STONE.lightened(0.18), clampf(0.5 + grain * 0.6, 0.0, 1.0))
	c = c.lerp(Color("#3f5366"), clampf(Sculpt.noise(p * 1.5 + Vector3(4, 1, 2)) * 0.8, 0.0, 0.5))
	return c.lerp(TROLL_STONE_DARK, clampf(-n.y, 0.0, 1.0) * 0.35 + clampf(-w, 0.0, 1.0) * 0.4)


static func yeti_fur(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	var streak := Sculpt.fbm(Vector3(p.x * 8.0, p.y * 3.0, p.z * 8.0))
	return YETI_FUR.lerp(YETI_SHADE, clampf(0.35 - n.y * 0.4 + streak * 0.5, 0.0, 1.0))


static func frost_skin(p: Vector3, n: Vector3, _v: float, _w: float) -> Color:
	return FROST_SKIN.lerp(FROST_SKIN_DARK, clampf(0.35 - n.y * 0.4 + Sculpt.fbm(p * 7.0) * 0.5, 0.0, 1.0))


func build(variant: String) -> Node3D:
	root = Node3D.new(); root.name = "FrostBrute"
	match variant:
		"yeti": return _yeti()
		"glacier": return _glacier()
		"giant": return _ice_giant()
		"glacier2": return _glacier_troll()
	return null


## The troll's body on the game's rig. body/limb/face are painters; returns the parts so each
## design can dress it.
## Where the right fist grips a club, and the line the handle runs along through it.
const GRIP := Vector3(0.79, 0.5, -0.1)
var GRIP_AXIS := Vector3(0.03, -0.42, -1.0).normalized()


func _troll(body_skin: Callable, limb_skin: Callable, face_skin: Callable, hand_skin: Callable, grip_right := false) -> Dictionary:
	var parts := {}
	var body := Sculpt.new(); var bp := body.add_painter(body_skin)
	body.tube([Vector3(0, 0.82, 0.12), Vector3(0, 1.15, 0.12), Vector3(0, 1.45, 0.12), Vector3(0, 1.68, 0.1), Vector3(0, 1.8, 0.06)], [0.38, 0.45, 0.5, 0.48, 0.3], bp, {"sides": 16, "per": 3, "flat": 1.22, "lump": 0.08})
	body.blob(Vector3(0, 1.15, -0.05), Vector3(0.36, 0.34, 0.3), bp, {"lat": 9, "lon": 14, "lump": 0.05})
	parts.body = body; parts.body_painter = bp

	var head := joint(root, "Head", Vector3(0, 1.92, -0.22))
	var hs := Sculpt.new(); var hp := hs.add_painter(face_skin); var tp := hs.add_painter(func (p, n, v, w): return TUSK_IVORY.darkened((1.0 - v) * 0.2))
	var dark := hs.add_painter(func (p, n, v, w): return Color("#121a20"))
	hs.blob(Vector3(0, 1.99, -0.31), Vector3(0.25, 0.24, 0.24), hp, {"lat": 10, "lon": 15, "lump": 0.06})
	hs.tube([Vector3(-0.22, 2.08, -0.44), Vector3(-0.08, 2.07, -0.53), Vector3(0.08, 2.07, -0.53), Vector3(0.22, 2.08, -0.44)], [0.055, 0.07, 0.07, 0.055], hp, {"sides": 9, "per": 3, "cap_rings": 2, "lump": 0.15})
	hs.blob(Vector3(0, 1.96, -0.56), Vector3(0.08, 0.1, 0.09), hp, {"lat": 7, "lon": 10, "lump": 0.1})
	hs.blob(Vector3(0, 1.83, -0.46), Vector3(0.26, 0.11, 0.2), hp, {"lat": 7, "lon": 13, "lump": 0.08})
	hs.blob(Vector3(0, 1.875, -0.5), Vector3(0.17, 0.03, 0.12), dark, {"lat": 4, "lon": 10})
	for side in [-1.0, 1.0]:
		hs.crystal(Vector3(0.14 * side, 1.86, -0.6), Vector3(0.15 * side, 1.0, -0.15), 0.14, 0.028, tp, 6)
		hs.tube([Vector3(0.23 * side, 2.0, -0.28), Vector3(0.33 * side, 2.04, -0.26), Vector3(0.4 * side, 2.1, -0.22)], [0.07, 0.05, 0.01], hp, {"sides": 8, "per": 2, "cap1": false, "flat": 0.5, "side": Vector3.BACK})
	parts.head = head; parts.head_sculpt = hs; parts.head_painter = hp
	var es := Sculpt.new(); var ew := es.add_painter(func (p, n, v, w): return Color.WHITE)
	for side in [-1.0, 1.0]: es.blob(Vector3(0.1 * side, 2.02, -0.505), Vector3(0.035, 0.025, 0.02), ew, {"lat": 4, "lon": 8})
	parts.eyes = es

	var arms: Array = []; var forearms: Array = []; var arm_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var shoulder := joint(root, label + "Shoulder", Vector3(0.57 * side, 1.67, 0.09))
		var us := Sculpt.new(); var up := us.add_painter(limb_skin)
		us.tube([Vector3(0.4 * side, 1.76, 0.08), Vector3(0.66 * side, 1.62, 0.08), Vector3(0.72 * side, 1.32, 0.07), Vector3(0.72 * side, 1.16, 0.08)], [0.22, 0.2, 0.16, 0.15], up, {"sides": 12, "per": 3, "lump": 0.08, "side": Vector3.BACK})
		var elbow := joint(shoulder, "Elbow", Vector3(0.72 * side, 1.15, 0.08))
		var fs := Sculpt.new(); var fp := fs.add_painter(limb_skin); var hd := fs.add_painter(hand_skin)
		fs.tube([Vector3(0.72 * side, 1.19, 0.08), Vector3(0.75 * side, 0.88, 0.03), Vector3(0.77 * side, 0.64, 0.0)], [0.155, 0.19, 0.16], fp, {"sides": 12, "per": 3, "lump": 0.08, "side": Vector3.BACK})
		if grip_right and side > 0.0:
			# A closed fist round the club handle: the palm on the inside, four fingers curled
			# over the outside and under the handle, the thumb across the top.
			var out := (Vector3.RIGHT - GRIP_AXIS * Vector3.RIGHT.dot(GRIP_AXIS)).normalized()
			var down := GRIP_AXIS.cross(out)
			if down.y > 0.0: down = -down
			fs.blob(GRIP + Vector3(-0.05, 0.02, 0.03), Vector3(0.12, 0.14, 0.15), hd, {"lat": 7, "lon": 11, "lump": 0.08})
			for f in range(4):
				var c := GRIP + GRIP_AXIS * ((f - 1.5) * 0.068)
				var pts: Array = []
				for a in [-1.3, -0.3, 0.7, 1.6, 2.3]: pts.append(c + (out * cos(a) + down * sin(a)) * 0.105)
				fs.tube(pts, [0.052, 0.05, 0.048, 0.045, 0.04], hd, {"sides": 7, "per": 2, "cap_rings": 2})
			var over := -down
			fs.tube([GRIP - out * 0.1 + GRIP_AXIS * 0.1, GRIP + over * 0.1 - out * 0.02 + GRIP_AXIS * 0.06, GRIP + over * 0.08 + out * 0.07 + GRIP_AXIS * 0.02], [0.05, 0.045, 0.038], hd, {"sides": 7, "per": 2, "cap_rings": 2})
		else:
			fs.blob(Vector3(0.78 * side, 0.52, -0.03), Vector3(0.17, 0.15, 0.16), hd, {"lat": 7, "lon": 11, "lump": 0.08})
			for f in range(3):
				var base := Vector3((0.78 + (f - 1) * 0.08) * side, 0.45, -0.12)
				fs.tube([base, base + Vector3(0, -0.1, -0.05), base + Vector3(0, -0.17, 0.0)], [0.05, 0.045, 0.035], hd, {"sides": 7, "per": 2, "cap_rings": 2})
			fs.tube([Vector3(0.68 * side, 0.52, -0.1), Vector3(0.64 * side, 0.45, -0.18), Vector3(0.66 * side, 0.4, -0.2)], [0.05, 0.045, 0.035], hd, {"sides": 7, "per": 2, "cap_rings": 2})
		arms.append(shoulder); forearms.append(elbow); arm_sculpts.append([us, fs])
	parts.arms = arms; parts.forearms = forearms; parts.arm_sculpts = arm_sculpts

	var hips: Array = []; var knees: Array = []; var leg_sculpts: Array = []
	for side in [-1.0, 1.0]:
		var label := "Left" if side < 0 else "Right"
		var hip := joint(root, label + "Hip", Vector3(0.29 * side, 0.85, 0.1))
		var ts := Sculpt.new(); var tp2 := ts.add_painter(limb_skin)
		ts.tube([Vector3(0.27 * side, 0.96, 0.1), Vector3(0.3 * side, 0.72, 0.1), Vector3(0.3 * side, 0.53, 0.1)], [0.25, 0.22, 0.18], tp2, {"sides": 12, "per": 3, "lump": 0.08})
		var knee := joint(hip, "Knee", Vector3(0.29 * side, 0.51, 0.105))
		var ss := Sculpt.new(); var sp := ss.add_painter(limb_skin); var fp2 := ss.add_painter(hand_skin)
		ss.tube([Vector3(0.3 * side, 0.55, 0.1), Vector3(0.31 * side, 0.27, 0.08), Vector3(0.31 * side, 0.14, 0.06)], [0.18, 0.17, 0.18], sp, {"sides": 12, "per": 3, "lump": 0.08})
		ss.blob(Vector3(0.31 * side, 0.08, -0.06), Vector3(0.19, 0.09, 0.27), fp2, {"lat": 6, "lon": 12, "lump": 0.08})
		for t in range(3): ss.blob(Vector3((0.31 + (t - 1) * 0.09) * side, 0.06, -0.31), Vector3(0.05, 0.05, 0.06), fp2, {"lat": 5, "lon": 7})
		hips.append(hip); knees.append(knee); leg_sculpts.append([ts, ss])
	parts.hips = hips; parts.knees = knees; parts.leg_sculpts = leg_sculpts
	return parts


func _close(parts: Dictionary, core: MeshInstance3D, scale: float, extra_leaves := []) -> Node3D:
	part(root, "Body", parts.body)
	part(parts.head, "Head", parts.head_sculpt)
	if core == null:
		core = part(parts.head, "GlowingEyes", parts.eyes, glow)
		core.material_override = glow
	for k in range(2):
		part(parts.arms[k], "UpperArm", parts.arm_sculpts[k][0])
		part(parts.forearms[k], "Forearm", parts.arm_sculpts[k][1])
		part(parts.hips[k], "Thigh", parts.leg_sculpts[k][0])
		part(parts.knees[k], "Shin", parts.leg_sculpts[k][1])
	return _finish({"head": parts.head, "core": core, "arms": parts.arms, "forearms": parts.forearms, "feet": parts.hips, "knees": parts.knees, "leaves": extra_leaves}, scale)


## Icicles hanging from each spot.
func icicles(parent: Node3D, spots: Array, length: float) -> void:
	var s := Sculpt.new(); var ip := s.add_painter(func (p, n, v, w): return ICE_HIGH.lerp(ICE_LOW, v * 0.7))
	for k in range(spots.size()):
		var at: Vector3 = spots[k]
		s.crystal(at + Vector3(0, 0.02, 0), Vector3(Sculpt.noise(at * 9.0) * 0.15, -1, 0), length * (0.6 + 0.5 * absf(Sculpt.noise(at * 13.0))), 0.022, ip, 5)
	part(parent, "Icicles", s, ice_mat)


## Ice crystals jutting from each spot along the given directions.
func ice_spikes(parent: Node3D, spots: Array, length: float, radius: float) -> void:
	var s := Sculpt.new(); var ip := s.add_painter(ice)
	for sp in spots:
		s.crystal(sp[0], sp[1], length * sp[2], radius * sp[2], ip, 6, sp[2] * 4.0)
	part(parent, "IceCrystals", s, ice_mat)


## A: a shaggy white yeti-troll with a blue face, tusks and icicles in its fur.
func _yeti() -> Node3D:
	material.albedo_texture = load("res://assets/cast/fur_detail_gray.png"); material.uv1_scale = Vector3(2.2, 2.2, 2.2)
	var face := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		var skin := frost_skin(p, n, v, w)
		return yeti_fur(p, n, v, w).lerp(skin, smoothstep(-0.4, -0.48, p.z) * smoothstep(2.12, 2.08, p.y) * smoothstep(1.74, 1.8, p.y))
	var parts := _troll(yeti_fur, yeti_fur, face, frost_skin)
	var body: Sculpt = parts.body
	for ring in range(2):
		var pts: Array = []; var radii: Array = []
		for k in range(15):
			var ang := TAU * k / 13.0 + ring * 0.5
			pts.append(Vector3(cos(ang) * (0.42 - ring * 0.05), 1.72 - ring * 0.12 + sin(ang * 2.0) * 0.03, 0.06 + sin(ang) * (0.34 - ring * 0.04)))
			radii.append(0.1 + 0.03 * Sculpt.noise(Vector3(k, ring, 2)))
		body.tube(pts, radii, parts.body_painter, {"sides": 9, "per": 3, "lump": 0.5, "side": Vector3.UP})
	var hs: Sculpt = parts.head_sculpt
	hs.blob(Vector3(0, 2.18, -0.26), Vector3(0.24, 0.12, 0.24), parts.head_painter, {"lat": 6, "lon": 12, "lump": 0.5})
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var fs: Sculpt = parts.arm_sculpts[k][1]
		var fp := fs.add_painter(yeti_fur)
		hanging(fs, fp, [Vector3(0.83 * side, 1.0, 0.08), Vector3(0.86 * side, 0.85, 0.02), Vector3(0.84 * side, 0.72, 0.1)], 0.16, 0.05, Vector3(0.03 * side, 0, 0))
		icicles(parts.forearms[k], [Vector3(0.77 * side, 0.66, 0.14), Vector3(0.8 * side, 0.7, -0.08), Vector3(0.7 * side, 0.68, 0.12)], 0.14)
	icicles(parts.head, [Vector3(-0.1, 1.73, -0.5), Vector3(0.0, 1.72, -0.52), Vector3(0.11, 1.73, -0.5)], 0.1)
	ice_spikes(root, [[Vector3(-0.2, 1.75, 0.4), Vector3(-0.4, 1, 0.6), 1.0], [Vector3(0.15, 1.8, 0.38), Vector3(0.3, 1, 0.5), 0.8], [Vector3(0.0, 1.55, 0.55), Vector3(0, 0.6, 1), 0.7]], 0.32, 0.07)
	return _close(parts, null, 1.15)


## B: a stone-skinned troll capped with snow, ice crystals bursting from its back, carrying a
## frozen log club.
func _glacier() -> Node3D:
	var stone_snow := snowy(troll_stone)
	var parts := _troll(stone_snow, stone_snow, stone_snow, stone_snow)
	ice_spikes(root, [[Vector3(-0.22, 1.85, 0.32), Vector3(-0.4, 1, 0.5), 1.0], [Vector3(0.18, 1.88, 0.3), Vector3(0.35, 1, 0.45), 1.1], [Vector3(0.0, 1.7, 0.48), Vector3(0, 0.8, 1), 0.9], [Vector3(-0.32, 1.55, 0.42), Vector3(-0.8, 0.5, 0.6), 0.7], [Vector3(0.34, 1.5, 0.42), Vector3(0.8, 0.5, 0.6), 0.75], [Vector3(0.0, 1.35, 0.56), Vector3(0, 0.3, 1), 0.6]], 0.42, 0.08)
	icicles(parts.head, [Vector3(-0.15, 2.03, -0.55), Vector3(-0.05, 2.02, -0.58), Vector3(0.06, 2.02, -0.58), Vector3(0.16, 2.03, -0.55)], 0.09)
	var cs := Sculpt.new()
	var wood := cs.add_painter(snowy(func (p, n, v, w): return bare(p, n, v, w).darkened(0.15)))
	cs.tube([Vector3(0.78, 0.6, -0.04), Vector3(0.8, 0.42, -0.35), Vector3(0.82, 0.2, -0.72)], [0.06, 0.09, 0.13], wood, {"sides": 10, "per": 3, "ridges": 5, "ridge": 0.1, "lump": 0.15, "side": Vector3.UP})
	part(parts.forearms[1], "FrozenClub", cs)
	icicles(parts.forearms[1], [Vector3(0.78, 0.36, -0.48), Vector3(0.86, 0.3, -0.6), Vector3(0.8, 0.23, -0.7), Vector3(0.74, 0.3, -0.58)], 0.12)
	return _close(parts, null, 1.15)


## The chosen design: the Glacier Troll, finished. Stone hide with rocky plates on its
## shoulders and back, snow on everything facing up, ice crystals bursting from its back,
## icicles on its brow and a gnarled frozen log club.
func _glacier_troll() -> Node3D:
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	# Show the painted colours as painted (stone dark enough for the snow to stand out).
	material.vertex_color_is_srgb = true
	ice_mat.vertex_color_is_srgb = true
	var stone_snow := snowy(troll_stone)
	var parts := _troll(stone_snow, stone_snow, stone_snow, stone_snow, true)
	var body: Sculpt = parts.body; var bp: int = parts.body_painter
	for plate in [[Vector3(-0.3, 1.82, 0.12), 0.2], [Vector3(0.3, 1.84, 0.14), 0.22], [Vector3(0.0, 1.62, 0.5), 0.2], [Vector3(-0.28, 1.38, 0.5), 0.16], [Vector3(0.3, 1.3, 0.48), 0.15]]:
		body.rock(plate[0], Vector3(plate[1] * 1.2, plate[1] * 0.6, plate[1]), bp, {"lat": 5, "lon": 7, "lump": 0.3, "basis": Basis.from_euler(Vector3(0.3, plate[0].x * 3.0, 0.2))})
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var us: Sculpt = parts.arm_sculpts[k][0]
		us.rock(Vector3(0.6 * side, 1.82, 0.08), Vector3(0.2, 0.12, 0.19), us.add_painter(stone_snow), {"lat": 5, "lon": 7, "lump": 0.3, "basis": Basis(Vector3.BACK, 0.3 * side)})
	ice_spikes(root, [[Vector3(-0.22, 1.86, 0.36), Vector3(-0.4, 1, 0.5), 1.0], [Vector3(0.18, 1.9, 0.34), Vector3(0.35, 1, 0.45), 1.15], [Vector3(0.0, 1.72, 0.52), Vector3(0, 0.8, 1), 0.9], [Vector3(-0.34, 1.56, 0.44), Vector3(-0.8, 0.5, 0.6), 0.7], [Vector3(0.36, 1.5, 0.44), Vector3(0.8, 0.5, 0.6), 0.75], [Vector3(0.0, 1.38, 0.58), Vector3(0, 0.3, 1), 0.6], [Vector3(0.62, 1.95, 0.1), Vector3(0.4, 1, 0.2), 0.5], [Vector3(-0.62, 1.93, 0.1), Vector3(-0.4, 1, 0.2), 0.45]], 0.42, 0.08)
	icicles(parts.head, [Vector3(-0.17, 2.03, -0.54), Vector3(-0.06, 2.02, -0.58), Vector3(0.06, 2.02, -0.58), Vector3(0.17, 2.03, -0.54)], 0.09)
	var cs := Sculpt.new()
	var wood := cs.add_painter(snowy(func (p, n, v, w): return bare(p, n, v, w).darkened(0.2)))
	# The club's handle runs straight through the closed fist, a stub showing behind it.
	var along := func (t: float) -> Vector3: return GRIP + GRIP_AXIS * t
	cs.tube([along.call(-0.2), along.call(0.0), along.call(0.22), along.call(0.45), along.call(0.66), along.call(0.84)], [0.055, 0.055, 0.062, 0.09, 0.12, 0.14], wood, {"sides": 10, "per": 3, "ridges": 6, "ridge": 0.12, "lump": 0.22, "side": Vector3.UP})
	cs.blob(along.call(0.5) + Vector3(0.09, 0.0, 0.0), Vector3(0.06, 0.05, 0.06), wood, {"lat": 5, "lon": 7, "lump": 0.3})
	cs.blob(along.call(0.7) + Vector3(-0.1, 0.03, 0.0), Vector3(0.05, 0.045, 0.05), wood, {"lat": 5, "lon": 7, "lump": 0.3})
	part(parts.forearms[1], "FrozenClub", cs)
	var ice_s := Sculpt.new(); var ip := ice_s.add_painter(ice)
	var tip: Vector3 = along.call(0.9)
	ice_s.rock(tip, Vector3(0.17, 0.14, 0.15), ip, {"lat": 5, "lon": 7, "lump": 0.25})
	for c in [[Vector3(0.0, 1.0, 0.0), 0.2], [Vector3(0.7, 0.4, -0.3), 0.15], [Vector3(-0.6, 0.3, -0.4), 0.14], [GRIP_AXIS, 0.16]]:
		ice_s.crystal(tip, c[0], c[1] + 0.12, 0.045, ip, 6)
	part(parts.forearms[1], "IceChunk", ice_s, ice_mat)
	icicles(parts.forearms[1], [along.call(0.42) + Vector3(0, -0.07, 0), along.call(0.58) + Vector3(0.04, -0.1, 0), along.call(0.72) + Vector3(-0.03, -0.12, 0)], 0.11)
	return _close(parts, null, 1.15)


## C: a giant of solid ice with snow drifts on its shoulders and a glowing heart of cold in its
## chest.
func _ice_giant() -> Node3D:
	var ice_body := func (p: Vector3, n: Vector3, v: float, w: float) -> Color:
		return ICE_LOW.darkened(0.15).lerp(ICE_HIGH, clampf(0.35 + n.y * 0.35 + Sculpt.fbm(p * 3.0) * 0.5, 0.0, 1.0))
	var parts := _troll(ice_body, ice_body, ice_body, ice_body)
	# Draw the giant itself in glassy ice: swap every sculpted part to the ice material.
	var snow_s := Sculpt.new(); var sp := snow_s.add_painter(snowy(func (p, n, v, w): return SNOW))
	for side in [-1.0, 1.0]: moss_clump(snow_s, sp, Vector3(0.45 * side, 1.86, 0.08), 0.2, 4)
	moss_clump(snow_s, sp, Vector3(0, 2.2, -0.28), 0.16, 4)
	part(root, "SnowDrifts", snow_s)
	ice_spikes(root, [[Vector3(-0.2, 1.85, 0.3), Vector3(-0.3, 1, 0.4), 1.0], [Vector3(0.2, 1.85, 0.3), Vector3(0.3, 1, 0.4), 1.0], [Vector3(0.0, 1.9, 0.2), Vector3(0, 1, 0.3), 1.2]], 0.4, 0.08)
	var hs := Sculpt.new(); var hw := hs.add_painter(func (p, n, v, w): return Color.WHITE)
	hs.rock(Vector3(0, 1.4, -0.42), Vector3(0.12, 0.15, 0.08), hw, {"lat": 4, "lon": 6, "lump": 0.1})
	var core := part(root, "HeartOfCold", hs, glow)
	core.material_override = glow
	var node := _close(parts, core, 1.15)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		if m.name in ["Body", "Head", "UpperArm", "Forearm", "Thigh", "Shin"]: m.mesh.surface_set_material(0, ice_mat)
	var eyes := parts.eyes as Sculpt
	var e := part(parts.head, "GlowingEyes", eyes, glow); e.owner = node
	return node
