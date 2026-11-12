extends RefCounted
## Occlusion culling: hidden shapes that tell the renderer what can't be seen, so anything
## completely behind them is skipped (not drawn, not shadowed). They are kept just inside
## the real surfaces so nothing visible is ever culled by mistake:
##  - terrain: a coarse sheet a little under each ground chunk, so hills and ridges hide
##    the trees, houses and creatures behind them;
##  - houses: their four walls (with the doorway left open), so a street of houses hides
##    what's behind it, and from inside a house the outside world isn't drawn at all;
##  - Blackthorn Keep: every solid stretch of its partition walls.
## Occluders never move once placed (moving them forces a rebuild), and they are freed
## with the chunk or building they belong to.

## Terrain: every CELL samples one corner; each corner sits below the lowest ground
## anywhere in the cells around it, so the sheet stays under the ground everywhere.
const CELL := 4
const SINK := 0.6


static func terrain(root: Node3D, verts: PackedVector3Array, steps: int) -> void:
	var side := steps + 1
	if verts.size() != side * side: return
	var corners := steps / CELL + 1
	var points := PackedVector3Array()
	for cz in range(corners):
		for cx in range(corners):
			var lowest := INF
			for z in range(maxi(0, (cz - 1) * CELL), mini(steps, (cz + 1) * CELL) + 1):
				for x in range(maxi(0, (cx - 1) * CELL), mini(steps, (cx + 1) * CELL) + 1):
					lowest = minf(lowest, verts[z * side + x].y)
			var at: Vector3 = verts[mini(cz * CELL, steps) * side + mini(cx * CELL, steps)]
			points.append(Vector3(at.x, lowest - SINK, at.z))
	var indices := PackedInt32Array()
	for z in range(corners - 1):
		for x in range(corners - 1):
			var i := z * corners + x
			indices.append_array([i, i + 1, i + corners, i + 1, i + corners + 1, i + corners])
	_add(root, "TerrainOccluder", points, indices)


## A house's walls (centred inside the wall boxes), leaving the doorway open.
static func house(parent: Node3D, width: float, depth: float, height: float, door_width: float = 2.0, door_height: float = 2.39) -> void:
	var w := width * 0.5; var d := depth * 0.5
	var quads: Array = [
		[Vector3(-w, 0, -d), Vector3(w, 0, -d), Vector3(w, height, -d), Vector3(-w, height, -d)],
		[Vector3(-w, 0, d), Vector3(-w, 0, -d), Vector3(-w, height, -d), Vector3(-w, height, d)],
		[Vector3(w, 0, -d), Vector3(w, 0, d), Vector3(w, height, d), Vector3(w, height, -d)],
		[Vector3(-w, 0, d), Vector3(-door_width * 0.5, 0, d), Vector3(-door_width * 0.5, height, d), Vector3(-w, height, d)],
		[Vector3(door_width * 0.5, 0, d), Vector3(w, 0, d), Vector3(w, height, d), Vector3(door_width * 0.5, height, d)],
		[Vector3(-door_width * 0.5, door_height, d), Vector3(door_width * 0.5, door_height, d), Vector3(door_width * 0.5, height, d), Vector3(-door_width * 0.5, height, d)],
	]
	_quads(parent, "HouseOccluder", quads)


## One straight stretch of solid wall (in the parent's space) from a to b, floor y to
## y + height; used for each solid span between doorways.
static func wall_span(parent: Node3D, a: Vector2, b: Vector2, y: float, height: float) -> void:
	if a.distance_to(b) < 0.5 or height < 0.5: return
	_quads(parent, "WallOccluder", [[Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(b.x, y + height, b.y), Vector3(a.x, y + height, a.y)]])


static func _quads(parent: Node3D, label: String, quads: Array) -> void:
	var points := PackedVector3Array(); var indices := PackedInt32Array()
	for quad in quads:
		var i := points.size()
		for p in quad: points.append(p)
		indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])
	_add(parent, label, points, indices)


static func _add(parent: Node3D, label: String, points: PackedVector3Array, indices: PackedInt32Array) -> void:
	var shape := ArrayOccluder3D.new()
	shape.set_arrays(points, indices)
	var occluder := OccluderInstance3D.new()
	occluder.name = label
	occluder.occluder = shape
	parent.add_child(occluder)
