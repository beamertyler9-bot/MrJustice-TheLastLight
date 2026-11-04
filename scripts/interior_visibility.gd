extends Node3D

var house: Node3D
var width = 0.0
var depth = 0.0
var geometry: Array = []
var showing = true
func setup(owner: Node3D, w: float, d: float): house = owner; width = w; depth = d; process_priority = 1000
func capture_geometry():
	geometry = []
	for node in find_children("*", "GeometryInstance3D", true, false):
		var record = [node, node.visible]; geometry.append(record)
		node.tree_exiting.connect(_release.bind(record), CONNECT_ONE_SHOT)
func _release(record: Array):
	if is_instance_valid(record[0]): record[0].visible = record[1]
	record[0] = null
func refresh_visibility():
	if not is_instance_valid(house): return
	var camera = get_viewport().get_camera_3d()
	if camera == null: return
	var local = house.to_local(camera.global_position)
	var visible_room = absf(local.x) <= width * 0.5 + 0.4 and absf(local.z) <= depth * 0.5 + 0.4
	if not visible_room and local.z >= depth * 0.5 - 0.35:
		visible_room = true
		var points = []
		for x in [-1.3, 1.3]:
			for y in [-0.1, 2.85]: points.append(house.to_global(Vector3(x, y, depth * 0.5 + 0.15)))
		var inside = camera.global_position - camera.global_basis.z * maxf(camera.near * 2, 1.0)
		for plane in camera.get_frustum():
			var side = 1.0 if plane.distance_to(inside) >= 0 else -1.0
			if points.all(func (point): return plane.distance_to(point) * side < -0.25): visible_room = false; break
	if visible_room == showing: return
	showing = visible_room
	for record in geometry:
		if is_instance_valid(record[0]): record[0].visible = showing and record[1]
func _process(_dt: float): refresh_visibility()
