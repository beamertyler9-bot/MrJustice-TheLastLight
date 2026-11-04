extends Node


const B = preload("res://scripts/build.gd")
const Ring = preload("res://scripts/entrance_ring.gd")
const FLOOR_Y = 0.034
const LANDING_Y = 0.2
const OUTSIDE_OFFSET = 1.5
const INSIDE_OFFSET = 1.35

static func attach_building(house: Node3D, width: float, depth: float, identity: String, options: Dictionary = {}) -> void:
	if house.get_meta("entry_via_ring_only", false): return
	house.set_meta("entry_via_ring_only", true)
	house.set_meta("building_access_id", identity)
	house.set_meta("building_width", width); house.set_meta("building_depth", depth)
	var front = depth * 0.5
	var door_width = float(options.get("door_width", 2.06)); var door_height = float(options.get("door_height", 2.48))
	var door = Node3D.new(); door.name = "BuildingDoor"; house.add_child(door)
	var timber = B.world_surface("timber", "#665341")
	var iron = B.mat("#414b46", 0.5)


	var door_center = Vector3(0, door_height * 0.5 - 0.02, front - 0.1)
	var door_size = Vector3(door_width, door_height, 0.14)
	var leaf = B.box(door, door_center, door_size, timber)
	leaf.name = "ClosedTimberDoor"
	var shape = BoxShape3D.new(); shape.size = door_size
	var blocker = B.solid(door, door_center, shape); blocker.name = "ClosedDoorBlocker"
	blocker.add_to_group("building_door_blocker"); blocker.set_meta("building_frame", NodePath("../.."))
	for x in [-0.75, -0.375, 0, 0.375, 0.75]:
		for side in [-1, 1]: B.box(door, Vector3(x * door_width / 2.06, door_center.y, front - 0.1 + side * 0.076), Vector3(0.012, door_height - 0.13, 0.008), B.mat("#443e32"))
	for y in [0.43, door_height - 0.55]:
		for side in [-1, 1]: B.box(door, Vector3(0, y, front - 0.1 + side * 0.085), Vector3(door_width - 0.13, 0.1, 0.025), iron)
	for side in [-1, 1]: B.ball(door, Vector3(0.65, 1.15, front - 0.1 + side * 0.12), Vector3(0.13, 0.13, 0.09), B.mat("#b5ac78", 0.5))

	var outside = Vector3(0, LANDING_Y, front + OUTSIDE_OFFSET)
	var inside: Vector3 = options.get("inside", Vector3(0, LANDING_Y, front - INSIDE_OFFSET))
	var title = str(house.get_meta("building_title", "Home"))
	if title.is_empty(): title = "Home"
	_marker(house, "BuildingEntry", identity + "_enter", "Enter " + title, outside, inside, title)
	_marker(house, "BuildingExit", identity + "_exit", "Leave " + title, inside, outside, "The open road")


	var refresh = load("res://scripts/building_access.gd").new()
	refresh.name = "AccessStartupRefresh"; house.add_child(refresh)

func _ready() -> void:


	get_tree().physics_frame.connect(_second_physics_frame, CONNECT_ONE_SHOT)

func _second_physics_frame() -> void:
	if not is_inside_tree(): return
	get_tree().physics_frame.connect(_finish_saved_clearance, CONNECT_ONE_SHOT)

func _finish_saved_clearance() -> void:
	var house = get_parent() as Node3D
	if not is_instance_valid(house) or not house.is_inside_tree(): return
	var owner = house.get_parent()
	while owner != null:
		if owner.has_method("_rehome_building_saved_positions"):
			owner._rehome_building_saved_positions(house)
			break
		owner = owner.get_parent()
	queue_free()

static func _marker(house: Node3D, title: String, identity: String, label: String, position: Vector3, destination: Vector3, location: String) -> void:
	var marker = Node3D.new(); marker.name = title; marker.position = position
	marker.set_meta("id", identity); marker.set_meta("kind", "entrance"); marker.set_meta("label", label)
	marker.set_meta("destination_local", destination); marker.set_meta("destination_frame", NodePath("..")); marker.set_meta("location_name", location)
	marker.set_meta("ring_ground_offset", FLOOR_Y - position.y)
	marker.add_to_group("interactable"); house.add_child(marker)
	Ring.build_marker(marker)

static func ground_exterior(house: Node3D, world) -> void:


	var paths = load("res://scripts/building_paths.gd")
	var transform_value: Transform3D = paths.frame(house)
	var entry = house.get_node("BuildingEntry") as Node3D
	var p = transform_value * entry.position
	var floor_height: float = world.surface_height_at(p.x, p.z) + 0.018
	entry.position = transform_value.affine_inverse() * Vector3(p.x, floor_height + LANDING_Y - 0.018, p.z)
	house.get_node("BuildingExit").set_meta("destination_local", entry.position)
	var visual = entry.get_node("EntranceRing") as Node3D
	entry.set_meta("ring_ground_offset", 0.018 - LANDING_Y)
	visual.position.y = 0.018 - LANDING_Y



	var level = true
	for i in range(8):
		var q = Vector2(p.x, p.z) + Vector2(cos(i * TAU / 8), sin(i * TAU / 8)) * 0.8
		level = level and absf(world.surface_height_at(q.x, q.y) + 0.018 - floor_height) < 0.001
	if level: return
	var samples = {}
	for art in visual.get_children():
		if not art is MeshInstance3D: continue
		var source = art.mesh as TorusMesh
		if source == null: continue


		var arrays = source.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var art_frame: Transform3D = paths.frame(art); var inverse = art_frame.affine_inverse()
		var changed = false
		for i in vertices.size():
			var v = art_frame * vertices[i]; var key = Vector2(v.x, v.z).snapped(Vector2.ONE * 1.0e-05)
			if not samples.has(key): samples[key] = world.surface_height_at(v.x, v.z) + 0.018 - floor_height
			var shift: float = samples[key]
			changed = changed or absf(shift) > 0.001
			vertices[i] = inverse * (v + Vector3.UP * shift)
		if changed:
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); art.mesh = mesh
