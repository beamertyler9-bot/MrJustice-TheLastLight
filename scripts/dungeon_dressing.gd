extends RefCounted
## Dungeon dressing: every room furnished for what it is, from the dungeon prop set, with
## walkways and doorways kept clear.
##
##   entry hall      banners, braziers, barrels, a runner carpet
##   library archive wall shelves, a long reading table, candles
##   armory workshop sword-and-shield racks, barrels and crates, a work table, keys
##   tomb ceremony   an altar between candles, stone sarcophagi, urns, skulls
##   stores pantry   stacked barrels and boxes, a laden table, bottles
##   boss sanctum    a ring of carved pillars, braziers, red banners, rubble
##   vault treasure  gold chests, coin piles, trunks
## Plus: big rooms get pillars, every dungeon gets wall torches that really give light.

const A = preload("res://scripts/imported_assets.gd")
const B = preload("res://scripts/build.gd")
const S = preload("res://scripts/region_sites.gd")
const MAX_TORCH_LIGHTS := 24

var parent: Node3D
var width := 10.0
var depth := 10.0
var shape := "rect"
var pillar_stone: Material
var avoid: Array = []
var rng := RandomNumberGenerator.new()


## `links`: directions (room-local XZ) toward neighbouring rooms, where the doorways are.
## `keep`: extra room-local points to keep clear (the surface exit).
static func room(owner: Node3D, room_width: float, room_depth: float, room_shape: String, purpose: String, region: int, links: Array, keep: Array, seed_text: String) -> void:
	var d = load("res://scripts/dungeon_dressing.gd").new()
	d.parent = owner; d.width = room_width; d.depth = room_depth; d.shape = room_shape; d.rng.seed = hash("dungeon-room:" + seed_text)
	for dir in links: d.avoid.append(["ray", dir])
	for point in keep: d.avoid.append(["point", point])
	d._furnish(purpose, region)
	owner.add_to_group("furnished_space"); owner.set_meta("purpose", purpose)


func _free(p: Vector2, radius: float = 0.9) -> bool:
	if absf(p.x) > width * 0.5 - 0.4 or absf(p.y) > depth * 0.5 - 0.4: return false
	var q := Vector2(p.x / (width * 0.5), p.y / (depth * 0.5))
	if shape == "ellipse" and q.length_squared() > 0.8: return false
	if shape == "hex" and absf(q.x) + absf(q.y) * 0.5 > 0.88: return false
	for rule in avoid:
		if rule[0] == "ray":
			var dir: Vector2 = rule[1]
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2.ZERO, dir * 40.0)) < 2.3 + radius: return false
		elif p.distance_to(rule[1]) < 2.6 + radius: return false
	return true


func _put(id: String, p: Vector2, height: float, yaw: float, solid: Vector3 = Vector3.ZERO) -> Node3D:
	var node := A.place(parent, id, Vector3(p.x, 0.0, p.y), height, yaw)
	if node != null and solid != Vector3.ZERO:
		var shape := BoxShape3D.new(); shape.size = solid
		B.solid(parent, Vector3(p.x, solid.y * 0.5, p.y), shape)
	return node


## Spots along the walls (and corners), facing into the room.
func _wall_spots(spacing: float, inset: float) -> Array:
	var spots: Array = []
	var hx := width * 0.5 - inset; var hz := depth * 0.5 - inset
	for wall in [[Vector2(0, -1), hx, hz], [Vector2(0, 1), hx, hz], [Vector2(-1, 0), hz, hx], [Vector2(1, 0), hz, hx]]:
		var normal: Vector2 = wall[0]; var half: float = wall[1]; var reach: float = wall[2]
		var tangent := Vector2(-normal.y, normal.x)
		var count := maxi(1, int(half * 2.0 / spacing))
		for i in range(count):
			var t := -half + (float(i) + 0.5) * (half * 2.0 / float(count))
			var p := normal * reach + tangent * t
			spots.append({"p": p, "yaw": atan2(-normal.x, -normal.y), "normal": normal})
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = spots[i]; spots[i] = spots[j]; spots[j] = swap
	return spots


func _along_walls(ids: Array, count: int, height: float, inset: float, spacing: float, solid: Vector3 = Vector3.ZERO, radius: float = 0.8, lift: float = 0.0) -> int:
	var placed := 0
	for spot in _wall_spots(spacing, inset):
		if placed >= count: break
		if not _free(spot.p, radius): continue
		var node := _put(ids[placed % ids.size()], spot.p, height, spot.yaw, solid)
		if node != null: node.position.y = lift
		placed += 1
	return placed


func _corners(ids: Array, height: float, inset: float, solid: Vector3 = Vector3.ZERO) -> void:
	var i := 0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p := Vector2(sx * (width * 0.5 - inset), sz * (depth * 0.5 - inset))
			if _free(p, 0.6):
				_put(ids[i % ids.size()], p, height, rng.randf() * TAU, solid)
			i += 1


func _brazier(p: Vector2, light: bool) -> void:
	if not _free(p, 0.8): return
	_put("avra_allassets_with_texture_brazier", p, 0.75, rng.randf() * TAU, Vector3(1.1, 0.75, 1.1))
	B.flame(parent, Vector3(p.x, 0.95, p.y), Vector3(0.6, 0.8, 0.6))
	if light:
		var lamp := OmniLight3D.new(); lamp.position = Vector3(p.x, 1.8, p.y)
		lamp.light_color = Color("#ffae5c"); lamp.light_energy = 1.1; lamp.omni_range = 8.0
		lamp.distance_fade_enabled = true; lamp.distance_fade_begin = 20.0; lamp.distance_fade_length = 6.0
		parent.add_child(lamp)


func _runner(color: String) -> void:
	var length := depth - 2.0
	if length < 3.0: return
	B.box(parent, Vector3(0, 0.035, 0), Vector3(1.8, 0.02, length), B.mat("#c9a35a", 0.3))
	B.box(parent, Vector3(0, 0.04, 0), Vector3(1.6, 0.02, length - 0.2), B.mat(color))


func _pillars() -> void:
	if width < 9.5 or depth < 9.5: return
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pillar(Vector2(sx * width * 0.3, sz * depth * 0.3))


## A carved stone pillar: plinth, eight-sided shaft, capital, reaching the vault.
func _pillar(p: Vector2) -> void:
	if not _free(p, 0.6): return
	var node := Node3D.new(); node.name = "StonePillar"; node.position = Vector3(p.x, 0, p.y); parent.add_child(node)
	B.box(node, Vector3(0, 0.22, 0), Vector3(1.15, 0.44, 1.15), pillar_stone, true)
	B.box(node, Vector3(0, 0.52, 0), Vector3(0.95, 0.16, 0.95), pillar_stone)
	B.cyl(node, Vector3(0, 3.6, 0), 0.36, 6.2, pillar_stone, true)
	B.box(node, Vector3(0, 6.62, 0), Vector3(0.95, 0.18, 0.95), pillar_stone)
	B.box(node, Vector3(0, 6.86, 0), Vector3(1.2, 0.3, 1.2), pillar_stone)


func _sarcophagus(p: Vector2, yaw: float, stone: Material) -> void:
	if not _free(p, 1.2): return
	var node := Node3D.new(); node.position = Vector3(p.x, 0, p.y); node.rotation.y = yaw; parent.add_child(node)
	B.box(node, Vector3(0, 0.42, 0), Vector3(1.0, 0.84, 2.2), stone, true)
	B.box(node, Vector3(0, 0.9, 0), Vector3(1.12, 0.14, 2.32), stone)
	B.box(node, Vector3(0, 1.0, 0.15), Vector3(0.5, 0.08, 1.2), stone)


func _furnish(purpose: String, region: int) -> void:
	var desert := region == 12
	var stone := B.world_surface("stone", "#b9a27c" if desert else "#857f8c")
	pillar_stone = B.world_surface("stone", "#c4ae86" if desert else ["#8e8a7c", "#9a7c6c", "#938d78", "#c4ae86", "#5e5552", "#6d6a78", "#8a90a8"][clampi(region - 9, 0, 6)])
	_pillars()
	if "entry" in purpose:
		_runner(["#5e2a26", "#6b3520", "#4a5a2a", "#6d4e22", "#4e1f18", "#2c3350", "#46336a"][clampi(region - 9, 0, 6)])
		_along_walls(["dungeon_banner_patterna_red", "dungeon_banner_patternb_brown", "dungeon_banner_shield_blue"], 3, 2.4, 0.42, 3.0, Vector3.ZERO, 0.6, 1.3)
		_brazier(Vector2(-1.9, -depth * 0.5 + 2.2), true); _brazier(Vector2(1.9, -depth * 0.5 + 2.2), false)
		_corners(["dungeon_barrel_small_stack", "dungeon_box_stacked"], 1.0, 1.0, Vector3(1.0, 1.0, 0.9))
	elif "library" in purpose:
		_along_walls(["dungeon_wall_shelves", "dungeon_shelves", "dungeon_wall_shelves"], 5, 2.6, 0.35, 2.4, Vector3(1.2, 2.6, 0.5))
		var table := Vector2(-width * 0.12, depth * 0.08)
		if _free(table, 1.2):
			_put("dungeon_table_long_decorated_a", table, 1.0, PI * 0.5, Vector3(2.2, 1.0, 1.1))
			var candles := _put("dungeon_candle_triple", table + Vector2(0.4, 0.1), 0.45, 0.0)
			if candles != null: candles.position.y = 1.0
		_along_walls(["dungeon_shelf_small_candles"], 2, 1.4, 0.35, 3.0)
	elif "armory" in purpose:
		_along_walls(["dungeon_sword_shield", "dungeon_sword_shield_broken", "dungeon_keyring_hanging"], 5, 1.0, 0.32, 2.6, Vector3.ZERO, 0.6, 1.5)
		_corners(["dungeon_barrel_large_decorated", "dungeon_box_stacked", "dungeon_barrel_small_stack", "qprop_crate_wooden"], 1.1, 0.9, Vector3(1.0, 1.1, 1.0))
		var bench := Vector2(width * 0.15, -depth * 0.12)
		if _free(bench, 1.2): _put("dungeon_table_medium_tablecloth", bench, 0.95, 0.2, Vector3(1.8, 0.95, 1.8))
	elif "tomb" in purpose:
		var altar := Vector2(0, -depth * 0.5 + 1.8)
		if _free(altar, 1.0):
			_put("ruin_altar", altar, 1.3, 0.0, Vector3(1.4, 1.3, 1.4))
			for side in [-1, 1]: _put("dungeon_candle_triple", altar + Vector2(side * 1.2, 0.3), 0.9, 0.0)
		for side in [-1, 1]: _sarcophagus(Vector2(side * width * 0.24, depth * 0.05), 0.0, stone)
		_along_walls(["ruin_vase", "ruin_vase", "dungeon_candle_triple"], 5, 0.8, 0.6, 2.2)
		_along_walls(["dungeon_banner_patternc_white"], 2, 2.4, 0.42, 4.0, Vector3.ZERO, 0.6, 1.3)
	elif "stores" in purpose or "pantry" in purpose:
		_corners(["dungeon_barrel_large_decorated", "dungeon_barrel_small_stack", "dungeon_box_stacked", "dungeon_barrel_large_decorated"], 1.15, 0.9, Vector3(1.0, 1.15, 1.0))
		_along_walls(["dungeon_box_stacked", "dungeon_barrel_small_stack", "qprop_barrel", "dungeon_bottle_a_green"], 5, 1.0, 0.7, 2.0, Vector3(0.9, 1.0, 0.9))
		var table := Vector2(width * 0.1, depth * 0.1)
		if _free(table, 1.2):
			_put("dungeon_table_long_decorated_a", table, 1.0, 0.0, Vector3(1.1, 1.0, 2.2))
	elif "boss" in purpose:
		for i in range(6):
			var a := float(i) / 6.0 * TAU + PI / 6.0
			_pillar(Vector2(cos(a) * width * 0.36, sin(a) * depth * 0.36))
		_brazier(Vector2(-width * 0.25, -depth * 0.5 + 1.5), true); _brazier(Vector2(width * 0.25, -depth * 0.5 + 1.5), true)
		_along_walls(["dungeon_banner_patterna_red"], 4, 2.6, 0.42, 3.2, Vector3.ZERO, 0.6, 1.4)
		_corners(["dungeon_rubble_large", "dungeon_rubble_half"], 0.7, 1.2)
	elif "vault" in purpose or "treasure" in purpose:
		_corners(["dungeon_chest_gold", "dungeon_coin_stack_large", "dungeon_trunk_medium_a", "dungeon_chest"], 0.9, 1.0, Vector3(1.2, 0.9, 1.0))
		_along_walls(["dungeon_coin_stack_large", "dungeon_chest", "dungeon_trunk_medium_a"], 3, 0.8, 0.9, 2.6, Vector3(1.1, 0.8, 1.0))
	else:
		_corners(["dungeon_barrel_small_stack", "dungeon_box_stacked"], 1.0, 1.0, Vector3(1.0, 1.0, 0.9))
	# Age and ruin everywhere: rubble, the odd fallen stone, a skull in a corner.
	for i in range(2):
		var p := Vector2(rng.randf_range(-0.4, 0.4) * width, rng.randf_range(-0.4, 0.4) * depth)
		if _free(p, 0.9): _put(["dungeon_rubble_half", "dungeon_rubble_large"][i], p, rng.randf_range(0.35, 0.6), rng.randf() * TAU)


## Wall torches all along the dungeon's walls and corridors; the nearest few light up.
static func torches(live: Node3D, id: String) -> void:
	var cells: Dictionary = S.cells(id)
	var keys: Array = cells.keys(); keys.sort()
	var lights := 0
	for cell in keys:
		if posmod(cell.x * 3 + cell.y * 5, 7) != 0: continue
		var walls: Array = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(cell + d): walls.append(d)
		if walls.size() != 1: continue
		var d: Vector2i = walls[0]
		var center := (Vector2(cell) + Vector2.ONE * 0.5) * S.STEP
		if center.distance_to(Vector2(0, 4)) < 4.0: continue
		var on_wall := center + Vector2(d) * 0.72
		var y := S.floor_height(id, on_wall)
		var yaw := atan2(-float(d.x), -float(d.y))
		var torch := A.place(live, "dungeon_torch_mounted", Vector3(on_wall.x, y + 1.9, on_wall.y), 0.75, yaw)
		var flame_at := Vector3(on_wall.x, y + 2.75, on_wall.y) - Vector3(float(d.x), 0, float(d.y)) * 0.18
		B.flame(live, flame_at, Vector3(0.26, 0.42, 0.26))
		if torch != null and lights < MAX_TORCH_LIGHTS and posmod(cell.x + cell.y, 2) == 0:
			# Only nearby torch lights are drawn (distance fade), so a long dungeon stays cheap.
			var lamp := OmniLight3D.new(); lamp.name = "TorchLight"; lamp.position = flame_at - Vector3(float(d.x), 0, float(d.y)) * 0.4
			lamp.light_color = Color("#ffad5a"); lamp.light_energy = 0.95; lamp.omni_range = 7.5
			lamp.distance_fade_enabled = true; lamp.distance_fade_begin = 14.0; lamp.distance_fade_length = 6.0
			live.add_child(lamp); lights += 1
