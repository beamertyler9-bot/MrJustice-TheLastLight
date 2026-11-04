extends Node3D

const GREEN := Color("#78f6a1")
const RED := Color("#ff665e")
const Occupancy = preload("res://scripts/world_occupancy.gd")
var item := ""
var valid := false
var outline: MeshInstance3D
var caption: Label3D
var ink: StandardMaterial3D

func _ready() -> void:
	name = "PlacementBlueprint"
	ink = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.emission_enabled = true
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline = MeshInstance3D.new()
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.material_override = ink
	add_child(outline)
	caption = Label3D.new()
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size = 48
	caption.pixel_size = 0.004
	caption.outline_size = 10
	add_child(caption)
	visible = false

static func dimensions(id: String) -> Dictionary:
	return {"half": Vector2(3.7, 3.6), "center": Vector2(-0.5, -0.6), "distance": 5.4, "height": 2.3, "variation": 0.36} if id == "camp_kit" else {"half": Vector2(1.05, 0.8), "center": Vector2.ZERO, "distance": 2.8, "height": 1.3, "variation": 0.25}

static func solve(game, id: String) -> Dictionary:
	var p = game.player
	var data = dimensions(id)
	var point: Vector3 = p.global_position - p.visual.global_basis.z.normalized() * float(data.distance)
	var result := {"valid": false, "point": point, "reason": "Find clear, level, dry ground.", "item": id}
	if id not in ["camp_kit", "crafting_table"] or game.available_count(id) <= 0:
		result.reason = "No placeable selected."
		return result

	var center_hit: Dictionary = p.ray(point + Vector3.UP * 2.0, point - Vector3.UP * 7.0, 1 | 8)
	if not center_hit.is_empty():
		point.y = center_hit.position.y + 0.025
		result.point = point
	if game.mode != "play" or not p.active or not p.is_on_floor() or p.climbing or p.swimming or p.mantle_time > 0 or p.dodge_time > 0 or p.hooking > 0 or p.ability_aiming or p.beam_charging or p.beam_contact >= 0 or is_instance_valid(p.held_body) or p.visual.is_throwing() or p.visual.grapple_active() or p.visual.bag_progress > 0.05:
		result.reason = "Stand on the ground to place."
		return result
	if game.world.interior_at(p.global_position) != "":
		result.reason = "Set up under the open sky."
		return result
	var scrappers = game.world.get("scrappers")
	if is_instance_valid(scrappers) and scrappers.blocks_placement(Occupancy.placeable_rect(Vector2(point.x, point.z), id)):
		result.reason = "Choose a spot outside the Scrapper camp."
		return result
	if id == "camp_kit" and not center_hit.is_empty() and center_hit.collider.get_meta("terrain", false):
		result["terrain"] = true; return _solve_camp(game, point, result)
	var low := INF
	var high := -INF
	var half: Vector2 = data.half
	var center: Vector2 = data.center
	for x in [-1.0, 0.0, 1.0]:
		for z in [-1.0, 0.0, 1.0]:
			var top := Vector3(point.x + center.x + half.x * x, p.global_position.y + 2.0, point.z + center.y + half.y * z)
			var hit: Dictionary = p.ray(top, top - Vector3.UP * 8.0, 1 | 8)
			if hit.is_empty() or hit.normal.y < 0.92 or hit.position.y <= game.world.water_level + 0.5 or hit.position.y > p.global_position.y + 0.65:
				return result
			if game.world.get("atlas") != null and not game.world.dry_surface_at(Vector2(hit.position.x, hit.position.z)): return result
			low = minf(low, hit.position.y)
			high = maxf(high, hit.position.y)
	if high - low > float(data.variation):
		result.reason = "This ground is too uneven."
		return result
	point.y = high + 0.025
	result.point = point
	var sight: Dictionary = p.ray(p.global_position + Vector3.UP * 1.15, point + Vector3.UP * 0.7, 1 | 8)
	if not sight.is_empty():
		result.reason = "A wall or object blocks this spot."
		return result
	var box := BoxShape3D.new()
	box.size = Vector3(half.x * 2.0, float(data.height), half.y * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform.origin = point + Vector3(center.x, float(data.height) * 0.5 + 0.08, center.y)
	query.collision_mask = 1 | 4 | 8
	query.exclude = [p.get_rid()]
	if not game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		result.reason = "Make room for the whole footprint."
		return result
	result.valid = true
	result.reason = "B  ·  PLACE CAMP" if id == "camp_kit" else "B  ·  PLACE TABLE"
	return result

static func _solve_camp(game, point: Vector3, result: Dictionary) -> Dictionary:
	var p = game.player; var ground: float = game.world.surface_height_at(point.x, point.z)
	point.y = ground + 0.025; result.point = point
	if game.world.get("atlas") != null and not game.world.dry_surface_at(Vector2(point.x, point.z), 6.8):
		result.reason = "Choose dry ground for the whole clearing."; return result
	var low := ground; var high := ground
	for i in range(16):
		var offset = Vector2.from_angle(i * TAU / 16) * 6.8
		var height: float = game.world.surface_height_at(point.x + offset.x, point.z + offset.y)
		low = minf(low, height); high = maxf(high, height)
	if low <= game.world.water_level + 0.35:
		result.reason = "Choose dry ground for the whole clearing."; return result
	var centre: Dictionary = p.ray(point + Vector3.UP * 2, point - Vector3.UP * 3, 1 | 8)
	if centre.is_empty() or not centre.collider.get_meta("terrain", false):
		result.reason = "Choose outdoor ground for your clearing."; return result
	var volume = CylinderShape3D.new(); volume.radius = 6.8; volume.height = high - low + 2.5
	var query = PhysicsShapeQueryParameters3D.new(); query.shape = volume
	query.transform.origin = Vector3(point.x, (high + low + 2.5) * 0.5, point.z)
	query.collision_mask = 1 | 4 | 8; query.exclude = [p.get_rid()]
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query, 128):
		if not hit.collider.get_meta("terrain", false):
			result.reason = "Make room around the circular clearing."; return result
	var sight: Dictionary = p.ray(p.global_position + Vector3.UP * 1.0, point + Vector3.UP * 0.7, 1 | 8)
	if not sight.is_empty() and not sight.collider.get_meta("terrain", false):
		result.reason = "An object blocks this camp site."; return result
	result.valid = true; result.reason = "B  ·  PREPARE CLEARING & CAMP"; return result

func show_solution(solution: Dictionary) -> void:
	var next_item := str(solution.item)
	if item != next_item:
		item = next_item
		_build_outline()
	valid = bool(solution.valid)
	global_position = solution.point
	var color := GREEN if valid else RED
	ink.albedo_color = color
	ink.emission = color * 0.5
	caption.modulate = color
	caption.text = str(solution.reason)
	caption.position = Vector3(0, 2.05 if item == "camp_kit" else 1.5, 0)
	visible = true

func _build_outline() -> void:
	var lines: Array[Vector3] = []
	var data := dimensions(item)
	var half: Vector2 = data.half
	var center: Vector2 = data.center
	var corners: Array[Vector3] = []
	for offset in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		corners.append(Vector3(center.x + offset.x, 0.055, center.y + offset.y))
	for i in range(4):
		lines.append(corners[i]); lines.append(corners[(i + 1) % 4])
	if item == "crafting_table":
		for y in [0.94, 1.08]:
			var table_corners := [Vector3(-0.83, y, -0.58), Vector3(0.83, y, -0.58), Vector3(0.83, y, 0.58), Vector3(-0.83, y, 0.58)]
			for i in range(4):
				lines.append(table_corners[i]); lines.append(table_corners[(i + 1) % 4])
		for x in [-0.63, 0.63]:
			for z in [-0.42, 0.42]:
				lines.append(Vector3(x, 0.05, z)); lines.append(Vector3(x, 0.96, z))
	else:
		for i in range(64):
			var a = float(i) * TAU / 64; var b = float(i + 1) * TAU / 64
			lines.append(Vector3(cos(a) * 6.8, 0.05, sin(a) * 6.8)); lines.append(Vector3(cos(b) * 6.8, 0.05, sin(b) * 6.8))
		for z in [-3.4, -0.6]:
			var top := Vector3(-2, 1.64, z)
			for x in [-3.2, -0.8]:
				lines.append(top); lines.append(Vector3(x, 0.08, z))
		lines.append(Vector3(-2, 1.64, -3.4)); lines.append(Vector3(-2, 1.64, -0.6))
		for x in [-3.2, -0.8]:
			lines.append(Vector3(x, 0.08, -3.4)); lines.append(Vector3(x, 0.08, -0.6))
		for i in range(32):
			var a := float(i) * TAU / 32.0
			var b := float(i + 1) * TAU / 32.0
			lines.append(Vector3(cos(a) * 0.7, 0.08, sin(a) * 0.7)); lines.append(Vector3(cos(b) * 0.7, 0.08, sin(b) * 0.7))
	var wire := ImmediateMesh.new()
	wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for p in lines: wire.surface_add_vertex(p)
	wire.surface_end()
	outline.mesh = wire
