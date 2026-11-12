extends RefCounted
## Makes a home feel lived in, on top of the basic furniture from building_interiors.gd:
##  - a stone hearth on the wall opposite the door, with a mantel, chimney breast, a fire
##    that throws warm light, logs and a woodpile, and a patterned rug in front of it;
##  - framed paintings on the side walls, a bottle shelf above the table, potted plants,
##    and a mantel candle and jug;
##  - warmer, brighter room light.
## Positions follow the same layout as the furniture (bed side, table side), so nothing
## overlaps it or blocks the door.

const B = preload("res://scripts/build.gd")
const O = preload("res://scripts/world_overhaul.gd")

static func add(room: Node3D, width: float, depth: float, profile: Dictionary, region: int) -> void:
	var side: int = -1 if int(profile.layout) % 2 == 0 else 1
	var back: int = -1 if int(profile.layout) < 2 else 1
	var rng := RandomNumberGenerator.new(); rng.seed = hash("comfort:" + str(profile.identity))
	var stone := B.world_surface("stone", ["#8d857a", "#9a8270", "#8f8a79", "#c2a985", "#6f6763", "#7b7886", "#8f97a6"][clampi(region - 9, 0, 6)])
	var timber := B.world_surface("timber", "#6e5340")
	var wall_z := -depth * 0.5 + 0.12
	if width >= 5.2 and depth >= 5.0: _hearth(room, Vector3(0, 0, wall_z), stone, timber, rng)
	# Paintings: above the bed on its wall, and over the floor lantern on the other wall.
	var bed: Vector3 = profile.bed
	_painting(room, Vector3(side * (width * 0.5 - 0.07), 1.75, bed.z), atan2(-float(side), 0.0), rng)
	_painting(room, Vector3(-side * (width * 0.5 - 0.07), 1.8, 0.0), atan2(float(side), 0.0), rng)
	# A shelf of bottles above the table.
	var table: Vector3 = profile.table
	O.fit(room, "qprop_shelf_small_bottles", Vector3(-side * (width * 0.5 - 0.2), 1.45, table.z), Vector3(0.95, 0.5, 0.3), atan2(float(side), 0.0))
	# Plants: one in the free front corner, one beside the hearth.
	var front_corner := Vector3(-side * (width * 0.5 - 0.5), 0.0, depth * 0.5 - 0.55)
	O.fit(room, "interior_mdvl_interiors_pottedplant_01", front_corner, Vector3(0.55, 0.95, 0.55), rng.randf() * TAU)
	if width >= 6.0:
		O.fit(room, "interior_mdvl_interiors_pottedplant_01", Vector3(-side * 1.45, 0.0, wall_z + 0.5), Vector3(0.5, 0.85, 0.5), rng.randf() * TAU)
	# The room light: warmer and a little brighter.
	for child in room.get_children():
		if child is OmniLight3D:
			child.light_energy = 0.75; child.light_color = Color("#ffd29a"); child.omni_range = 5.5
	room.get_parent().set_meta("home_comfort", true)


static func _hearth(room: Node3D, at: Vector3, stone: Material, timber: Material, rng: RandomNumberGenerator) -> void:
	var hearth := Node3D.new(); hearth.name = "Hearth"; hearth.position = at; room.add_child(hearth)
	# Floor slab, firebox surround and the dark opening.
	B.box(hearth, Vector3(0, 0.06, 0.62), Vector3(1.9, 0.12, 0.7), stone)
	B.box(hearth, Vector3(-0.66, 0.62, 0.32), Vector3(0.38, 1.24, 0.6), stone, true)
	B.box(hearth, Vector3(0.66, 0.62, 0.32), Vector3(0.38, 1.24, 0.6), stone, true)
	B.box(hearth, Vector3(0, 1.12, 0.32), Vector3(1.7, 0.24, 0.6), stone)
	B.box(hearth, Vector3(0, 0.55, 0.08), Vector3(0.96, 1.0, 0.12), B.mat("#1d1612"))
	# Mantel shelf and chimney breast up to the beams.
	B.box(hearth, Vector3(0, 1.3, 0.38), Vector3(2.0, 0.1, 0.42), timber)
	B.box(hearth, Vector3(0, 2.3, 0.22), Vector3(1.3, 1.9, 0.44), stone)
	# The fire: logs, flames and a warm, flickering glow.
	for i in range(3):
		var log := B.cyl(hearth, Vector3(-0.2 + i * 0.2, 0.2, 0.32), 0.07, 0.62, B.mat("#4a3423"))
		log.rotation = Vector3(0, 0.3 * (i - 1), PI * 0.5)
	B.flame(hearth, Vector3(-0.08, 0.48, 0.34), Vector3(0.42, 0.55, 0.3))
	B.flame(hearth, Vector3(0.14, 0.42, 0.3), Vector3(0.32, 0.42, 0.24))
	var glow := OmniLight3D.new(); glow.name = "HearthGlow"; glow.position = Vector3(0, 0.7, 0.9)
	glow.light_color = Color("#ff9447"); glow.light_energy = 1.0; glow.omni_range = 4.5; glow.shadow_enabled = false
	glow.distance_fade_enabled = true; glow.distance_fade_begin = 20.0; glow.distance_fade_length = 6.0
	hearth.add_child(glow)
	glow.set_script(load("res://scripts/hearth_flicker.gd"))
	# On the mantel: a candle and a jug; beside it, the woodpile; in front, a rug.
	O.fit(hearth, "interior_mdvl_interiors_candle_01", Vector3(-0.65, 1.36, 0.42), Vector3(0.12, 0.3, 0.12))
	O.fit(hearth, "qprop_vase_2", Vector3(0.55, 1.36, 0.42), Vector3(0.24, 0.3, 0.24), rng.randf() * TAU)
	O.fit(hearth, "interior_mdvl_interiors_woodpile_01", Vector3(1.35, 0.0, 0.42), Vector3(0.75, 0.55, 0.5))
	O.fit(hearth, "interior_mdvl_interiors_rug_01", Vector3(0, 0.068, 1.55), Vector3(1.9, 0.03, 1.25))


static func _painting(room: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	O.fit(room, "interior_mdvl_interiors_painting_01", at, Vector3(rng.randf_range(0.75, 1.05), rng.randf_range(0.6, 0.8), 0.06), yaw)


## Shops: pictures high on the side walls, plants by the door and warmer light.
static func shop(room: Node3D, width: float, depth: float, identity: String) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("shop-comfort:" + identity)
	for side in [-1, 1]:
		_painting(room, Vector3(side * (width * 0.5 - 0.07), 2.35, -depth * 0.12), atan2(-float(side), 0.0), rng)
		O.fit(room, "interior_mdvl_interiors_pottedplant_01", Vector3(side * (width * 0.5 - 0.5), 0.0, depth * 0.5 - 0.55), Vector3(0.5, 0.9, 0.5), rng.randf() * TAU)
	# (Shops already have their own warm light; a second one only doubled the cost.)
	for child in room.get_children():
		if child is OmniLight3D: child.light_energy = maxf(child.light_energy, 0.7); child.light_color = Color("#ffd8a4")
