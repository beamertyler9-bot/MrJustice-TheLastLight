extends RefCounted
## Blackthorn Keep's interior: real structure on every one of its seven floors.
##
## Each floor is a solid block (x -32..32, z -32..20) with six rooms in two rows of three and
## a long landing between the rows, plus the stair tower to the east (x 32..52):
##   - stone partition walls between the rooms and between each row and the landing, every
##     room entered through one arched doorway from the landing, flanked by torches;
##   - the landing opens into the stair tower through a single grand doorway;
##   - in the tower, solid stone flights with real steps, a thick underside, parapet walls
##     you can't fall over, and lantern-topped newel posts; switching back floor to floor.
## Rooms are furnished by castle_dressing.gd.

const B = preload("res://scripts/build.gd")
const S = preload("res://scripts/region_sites.gd")
const Architecture = preload("res://scripts/interior_architecture.gd")
const A = preload("res://scripts/imported_assets.gd")

const LEVELS := 7
const WALL_HEIGHT := 7.3
const WALL := 0.6
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 4.2
const ROOM_X := [-22.0, 0.0, 22.0]


## The castle's floor plan as 2 m cells: the whole main block plus the stair tower.
static func cells() -> Dictionary:
	var result := {}
	for z in range(-16, 10):
		for x in range(-16, 16): result[Vector2i(x, z)] = true
	for z in range(-14, 12):
		for x in range(16, 26): result[Vector2i(x, z)] = true
	return result


static func floor_y(level: int) -> float:
	return float(level - 2) * 7.5


## A straight wall from a to b (site XZ) on one floor, with doorway openings
## [[distance along the wall, width, height], ...]: solid piers, lintels above the doors.
static func _wall_line(parent: Node3D, a: Vector2, b: Vector2, y: float, openings: Array, material: Material, trim: Material) -> void:
	var length := a.distance_to(b); var dir := (b - a) / length
	var yaw := atan2(dir.x, dir.y)
	var cuts: Array = openings.duplicate(); cuts.sort_custom(func (p, q): return float(p[0]) < float(q[0]))
	var t := 0.0
	var spans: Array = []
	for cut in cuts:
		var c0 := float(cut[0]) - float(cut[1]) * 0.5; var c1 := float(cut[0]) + float(cut[1]) * 0.5
		if c0 > t + 0.01: spans.append([t, c0, 0.0, WALL_HEIGHT])
		spans.append([c0, c1, float(cut[2]), WALL_HEIGHT])
		t = c1
	if t < length - 0.01: spans.append([t, length, 0.0, WALL_HEIGHT])
	for span in spans:
		var from := float(span[0]); var to := float(span[1]); var bottom := float(span[2]); var top := float(span[3])
		if to - from < 0.01 or top - bottom < 0.01: continue
		var mid := a + dir * (from + to) * 0.5
		preload("res://scripts/occluders.gd").wall_span(parent, a + dir * from, a + dir * to, y + bottom, top - bottom)
		var piece := B.box(parent, Vector3(mid.x, y + (bottom + top) * 0.5, mid.y), Vector3(WALL, top - bottom, to - from), material, true)
		piece.rotation.y = yaw
		var collider := parent.get_child(parent.get_child_count() - 1)
		if collider is StaticBody3D: collider.rotation.y = yaw
	# Door dressing: stone jambs and an arch in each opening.
	for cut in cuts:
		var at := a + dir * float(cut[0])
		var frame := Node3D.new(); frame.name = "CastleDoorway"; frame.position = Vector3(at.x, y, at.y); frame.rotation.y = yaw + PI * 0.5
		parent.add_child(frame)
		var w := float(cut[1]); var h := float(cut[2])
		for side in [-1, 1]:
			B.box(frame, Vector3(side * (w * 0.5 - 0.12), h * 0.5, 0), Vector3(0.34, h, WALL + 0.16), trim)
		B.box(frame, Vector3(0, h - 0.12, 0), Vector3(w + 0.1, 0.3, WALL + 0.16), trim)
		Architecture.arch(frame, w - 0.3, h - 1.15, 0.95, WALL * 0.5 + 0.08, trim)


static func build(live: Node3D, id: String, record: Dictionary) -> void:
	var region := int(record.region)
	var wall := Architecture.stone(region, false, true, false)
	var trim := B.world_surface("stone", "#8c8093")
	for level in range(LEVELS):
		var y := floor_y(level)
		var holder := Node3D.new(); holder.name = "CastleFloor_%d" % level; live.add_child(holder)
		# Between the room columns.
		for x in [-11.0, 11.0]:
			_wall_line(holder, Vector2(x, -32.0), Vector2(x, -10.0), y, [], wall, trim)
			_wall_line(holder, Vector2(x, -2.0), Vector2(x, 20.0), y, [], wall, trim)
		# Between each row of rooms and the landing: one doorway per room.
		var doors: Array = []
		for rx in ROOM_X: doors.append([float(rx) + 32.0, DOOR_WIDTH, DOOR_HEIGHT])
		_wall_line(holder, Vector2(-32.0, -10.0), Vector2(32.0, -10.0), y, doors, wall, trim)
		_wall_line(holder, Vector2(-32.0, -2.0), Vector2(32.0, -2.0), y, doors, wall, trim)
		# Into the stair tower: one grand doorway from the landing.
		_wall_line(holder, Vector2(32.0, -32.0), Vector2(32.0, 20.0), y, [[26.0, 5.0, 5.2]], wall, trim)
		_torches(holder, y)
	stairs(live, id, region)


## Torches on the landing walls and either side of every doorway.
static func _torches(parent: Node3D, y: float) -> void:
	var lit := 0
	for rx in ROOM_X:
		for row in [[-10.0, 1.0], [-2.0, -1.0]]:
			var wall_z := float(row[0]); var facing := float(row[1])
			for side in [-1, 1]:
				var at := Vector3(float(rx) + side * 2.4, y + 2.3, wall_z + facing * (WALL * 0.5 + 0.05))
				A.place(parent, "dungeon_torch_mounted", at - Vector3(0, 0.4, 0), 0.75, 0.0 if facing > 0 else PI)
				B.flame(parent, at + Vector3(0, 0.45, facing * 0.18), Vector3(0.26, 0.42, 0.26))
				if side == 1 and lit < 3:
					var lamp := OmniLight3D.new(); lamp.name = "LandingTorch"; lamp.position = at + Vector3(0, 0.6, facing * 0.6)
					lamp.light_color = Color("#ffb062"); lamp.light_energy = 0.9; lamp.omni_range = 8.0
					lamp.distance_fade_enabled = true; lamp.distance_fade_begin = 16.0; lamp.distance_fade_length = 6.0
					parent.add_child(lamp); lit += 1


## The stair tower: one stone flight per floor, switching back along the tower.
static func stairs(live: Node3D, id: String, region: int) -> void:
	var stone := Architecture.stone(region, true, true, false)
	var wall := Architecture.stone(region, false, true, false)
	var trim := B.world_surface("stone", "#8c8093")
	for level in range(LEVELS - 1):
		var x := 39.0 if level % 2 == 0 else 47.0
		var start := Vector3(x, floor_y(level), -26.0 if level % 2 == 0 else 20.0)
		var finish := Vector3(x, floor_y(level + 1), 20.0 if level % 2 == 0 else -26.0)
		_flight(live, start, finish, 5.0, stone, wall, trim)
	# Balustrades round the stair well on every upper floor, open only where a flight leaves
	# or arrives, so nobody walks off the edge into the well.
	for level in range(1, LEVELS):
		var y := floor_y(level)
		var holder := Node3D.new(); holder.name = "StairWellRail_%d" % level; live.add_child(holder)
		_rail(holder, Vector2(36.0, -26.0), Vector2(36.0, 20.0), y, wall, trim)
		var flights := [[36.5, 41.5], [44.5, 49.5]]
		for edge in [-26.0, 20.0]:
			# Even floors: flights leave and arrive at the south edge; odd floors at the north.
			var open: bool = (float(edge) < 0.0) == (level % 2 == 0)
			var from := 36.0
			if open:
				for f in flights:
					_rail(holder, Vector2(from, edge), Vector2(float(f[0]), edge), y, wall, trim); from = float(f[1])
			_rail(holder, Vector2(from, edge), Vector2(52.0, edge), y, wall, trim)
	live.set_meta("stairs", LEVELS - 1)


static func _rail(parent: Node3D, a: Vector2, b: Vector2, y: float, wall: Material, trim: Material) -> void:
	var length := a.distance_to(b)
	if length < 0.1: return
	var mid := (a + b) * 0.5
	var node := Node3D.new(); node.position = Vector3(mid.x, y, mid.y); node.rotation.y = atan2(b.x - a.x, b.y - a.y); parent.add_child(node)
	B.box(node, Vector3(0, 0.55, 0), Vector3(0.4, 1.1, length), wall, true)
	B.box(node, Vector3(0, 1.16, 0), Vector3(0.55, 0.12, length + 0.15), trim)


static func _flight(live: Node3D, a: Vector3, b: Vector3, width: float, tread_material: Material, wall: Material, trim: Material) -> void:
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	var rise := b.y - a.y
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var side := Vector3(dir.z, 0, -dir.x)
	var steps := 36
	var going := run / float(steps); var step_rise := rise / float(steps)
	# Smooth, invisible ramp to walk on, along the line of the step nosings.
	var ramp := Node3D.new(); ramp.name = "StairFlight"; live.add_child(ramp)
	ramp.position = (a + b) * 0.5 - Vector3.UP * 0.14
	var span := b - a
	ramp.rotation.y = atan2(dir.x, dir.z)
	ramp.rotation.x = -atan2(span.y, run)
	var shape := BoxShape3D.new(); shape.size = Vector3(width, 0.28, span.length())
	B.solid(ramp, Vector3.ZERO, shape)
	# The flight itself: stepped top, thick sloping stone underside, solid sides.
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var soffit := 1.1
	var profile: Array[Vector2] = []  # (distance along, height) of the stepped top
	for i in range(steps):
		profile.append(Vector2(going * i, step_rise * (i + 1)))
		profile.append(Vector2(going * (i + 1), step_rise * (i + 1)))
	var base := a
	var half := width * 0.5
	var to_world := func (d: float, h: float, s: float) -> Vector3: return base + dir * d + Vector3.UP * h + side * s
	for i in range(steps):
		var d0 := going * i; var d1 := going * (i + 1); var h0 := step_rise * i; var h1 := step_rise * (i + 1)
		# Riser and tread.
		_quad(st, to_world.call(d0, h0, -half), to_world.call(d0, h0, half), to_world.call(d0, h1, half), to_world.call(d0, h1, -half), -dir)
		_quad(st, to_world.call(d0, h1, -half), to_world.call(d0, h1, half), to_world.call(d1, h1, half), to_world.call(d1, h1, -half), Vector3.UP)
		# Sides of this step's slice, down to the sloping underside.
		for s in [-half, half]:
			var under0 := h0 - soffit; var under1 := h1 - soffit
			_quad(st, to_world.call(d0, under0, s), to_world.call(d1, under1, s), to_world.call(d1, h1, s), to_world.call(d0, h1, s), side * signf(s))
	# Underside.
	_quad(st, to_world.call(0.0, -soffit, half), to_world.call(0.0, -soffit, -half), to_world.call(run, rise - soffit, -half), to_world.call(run, rise - soffit, half), Vector3.DOWN)
	var flight_mesh := st.commit()
	B.mesh(live, flight_mesh, tread_material).name = "StoneFlight"
	# Parapets: low stone walls on both sides, with collision so nobody tumbles off.
	for s in [-1.0, 1.0]:
		var wall_node := Node3D.new(); wall_node.name = "StairParapet"; live.add_child(wall_node)
		wall_node.position = (a + b) * 0.5 + side * s * (half - 0.18) + Vector3.UP * 0.35
		wall_node.rotation = ramp.rotation
		B.box(wall_node, Vector3.ZERO, Vector3(0.36, 1.5, span.length()), wall, true)
		B.box(wall_node, Vector3(0, 0.8, 0), Vector3(0.5, 0.12, span.length()), trim)
		# Newel posts with lanterns at the foot and head of the flight.
		for end in [a, b]:
			var post: Vector3 = end + side * s * (half - 0.18)
			B.box(live, post + Vector3.UP * 0.75, Vector3(0.55, 1.5, 0.55), trim, true)
			B.box(live, post + Vector3.UP * 1.56, Vector3(0.68, 0.14, 0.68), trim)
			A.place(live, "kaykit_lantern", post + Vector3.UP * 1.63, 0.45, 0.0)
	var glow := OmniLight3D.new(); glow.name = "StairLantern"; glow.position = a + side * (half + 0.2) + Vector3.UP * 2.4
	glow.light_color = Color("#ffc27a"); glow.light_energy = 0.9; glow.omni_range = 9.0
	glow.distance_fade_enabled = true; glow.distance_fade_begin = 18.0; glow.distance_fade_length = 6.0
	live.add_child(glow)


static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, outward: Vector3) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	if n.dot(outward) < 0.0: n = -n
	for p in [p0, p1, p2, p0, p2, p3]:
		st.set_normal(n); st.add_vertex(p)
