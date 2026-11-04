extends RefCounted




const ROWS := 10
const COLUMNS := 8
const STEP := 1.0 / 60.0
const MAX_SUBSTEPS := 8
const ITERATIONS := 3
const TELEPORT_DISTANCE := 2.5
const AIR_RESPONSE := 0.22
const ACCELERATION_RESPONSE := 0.28
const DAMPING := 5.2
const TURN_FOLLOW := 0.55

var mesh := ArrayMesh.new()
var rest := PackedVector3Array()
var positions := PackedVector3Array()
var previous := PackedVector3Array()
var _local := PackedVector3Array()
var _seam_points := PackedVector3Array()
var _tether_limits: Array[float] = []
var _vertical_limits: Array[float] = []
var _horizontal_limits: Array[float] = []
var _row_accelerations: Array[Vector3] = []
var _edge_a := PackedInt32Array()
var _edge_b := PackedInt32Array()
var _world_lengths := PackedFloat32Array()
var _edge_stiffness := PackedFloat32Array()
var _vertex_bytes := PackedByteArray()
var _normal_offset := 0
var _normal_stride := 0
var _last_frame := Transform3D.IDENTITY
var _last_step := STEP
var _last_velocity := Vector3.ZERO
var _initialized := false
var _last_colliders: Array = []
var last_substeps := 0
var resets := 0

func _init() -> void:
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(ROWS + 1):
		var v := float(row) / ROWS
		for col in range(COLUMNS + 1):
			var u := float(col) / COLUMNS
			rest.append(Vector3((u - 0.5) * lerpf(0.69, 1.27, v), -v * 1.51, 0.06 + sin(u * 25.0) * 0.014 * v))
			uvs.append(Vector2(u, v))
			normals.append(Vector3.BACK)
	for row in range(ROWS + 1):
		for col in range(COLUMNS + 1):
			var i := row * (COLUMNS + 1) + col
			if col < COLUMNS:
				_link(i, i + 1, 1.0)
			if row < ROWS:
				_link(i, i + COLUMNS + 1, 1.0)
			if col < COLUMNS and row < ROWS:
				_link(i, i + COLUMNS + 2, 0.65)
				_link(i + 1, i + COLUMNS + 1, 0.65)
				indices.append_array(PackedInt32Array([i, i + COLUMNS + 1, i + 1, i + 1, i + COLUMNS + 1, i + COLUMNS + 2]))
			if col + 2 <= COLUMNS:
				_link(i, i + 2, 0.32)
			if row + 2 <= ROWS:
				_link(i, i + (COLUMNS + 1) * 2, 0.32)
	positions = rest.duplicate()
	previous = rest.duplicate()
	_local = rest.duplicate()
	_seam_points.resize(COLUMNS + 1)
	_tether_limits.resize(rest.size())
	_vertical_limits.resize(rest.size())
	_horizontal_limits.resize(rest.size())
	_row_accelerations.resize(ROWS + 1)
	_world_lengths.resize(_edge_a.size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = rest
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	var format := mesh.surface_get_format(0)
	_normal_offset = RenderingServer.mesh_surface_get_format_offset(format, rest.size(), Mesh.ARRAY_NORMAL)
	_normal_stride = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format, rest.size())
	_vertex_bytes = RenderingServer.mesh_get_surface(mesh.get_rid(), 0).vertex_data
	mesh.custom_aabb = AABB(Vector3(-1.0, -1.8, -1.0), Vector3(2.0, 2.0, 2.8))

func _link(a: int, b: int, stiffness: float) -> void:
	_edge_a.append(a)
	_edge_b.append(b)
	_edge_stiffness.append(stiffness)

func reset(frame: Transform3D) -> void:
	if not frame.is_finite():
		return
	for i in range(rest.size()):
		positions[i] = frame * rest[i]
		previous[i] = positions[i]
		_local[i] = rest[i]
	_last_frame = frame
	_last_step = STEP
	_last_velocity = Vector3.ZERO
	_last_colliders.clear()
	_initialized = true
	resets += 1
	last_substeps = 0



func advance(dt: float, frame: Transform3D, velocity: Vector3, colliders: Array) -> void:
	last_substeps = 0
	if not is_finite(dt) or dt <= 0.0 or not frame.is_finite():
		return
	if not _initialized or frame.origin.distance_to(_last_frame.origin) > TELEPORT_DISTANCE or dt > 0.25:
		reset(frame)
	var elapsed := minf(dt, STEP * MAX_SUBSTEPS)
	last_substeps = mini(MAX_SUBSTEPS, maxi(1, int(ceil(elapsed / STEP))))
	var step := elapsed / last_substeps
	var wind := -(velocity if velocity.is_finite() else Vector3.ZERO).limit_length(8.0) * AIR_RESPONSE
	var inertial := ((velocity - _last_velocity) / maxf(dt, STEP)).limit_length(14.0) if velocity.is_finite() else Vector3.ZERO
	var reference_origin := _last_frame.origin
	var reference_basis := _last_frame.basis.orthonormalized()
	for substep in range(last_substeps):
		var alpha := float(substep + 1) / last_substeps
		var seam := _last_frame.interpolate_with(frame, alpha)


		for edge in range(_edge_a.size()):
			_world_lengths[edge] = (seam.basis * (rest[_edge_b[edge]] - rest[_edge_a[edge]])).length()
		for col in range(COLUMNS + 1):
			_seam_points[col] = seam * rest[col]
		for row in range(1, ROWS + 1):
			_row_accelerations[row] = (Vector3.DOWN * 9.81 + wind * (1.0 - float(row) / ROWS * 0.3) - inertial * ACCELERATION_RESPONSE) * step * step
			for col in range(COLUMNS + 1):
				var i := row * (COLUMNS + 1) + col
				_tether_limits[i] = (seam.basis * (rest[i] - rest[col])).length() * 1.015
				_vertical_limits[i] = (seam.basis * (rest[i] - rest[i - COLUMNS - 1])).length() * 1.04
				var parent := i + 1 if col < COLUMNS / 2 else i - 1 if col > COLUMNS / 2 else i
				_horizontal_limits[i] = (seam.basis * (rest[i] - rest[parent])).length() * 1.04




		var transport := seam.origin - reference_origin
		reference_origin = seam.origin



		var next_basis := seam.basis.orthonormalized()
		var turn := Basis.IDENTITY.slerp(next_basis * reference_basis.inverse(), TURN_FOLLOW)
		reference_basis = next_basis
		for i in range(positions.size()):
			positions[i] = seam.origin + turn * (positions[i] + transport - seam.origin)
			previous[i] = seam.origin + turn * (previous[i] + transport - seam.origin)
		var shapes: Array = []
		for index in range(colliders.size()):
			var shape: Dictionary = colliders[index]
			var shape_frame: Transform3D = shape.transform
			if _last_colliders.size() == colliders.size():
				shape_frame = (_last_colliders[index].transform as Transform3D).interpolate_with(shape_frame, alpha)
			var parts: Array = shape.get("parts", [])
			var profiles: Array[Vector4] = []
			var backs: Array[float] = []
			var maximum_back := 0.24
			for part in range(parts.size()):
				var bounds: AABB = parts[part]
				if _last_colliders.size() == colliders.size() and _last_colliders[index].get("parts", []).size() == parts.size():
					var old_bounds: AABB = _last_colliders[index].parts[part]
					bounds = AABB(old_bounds.position.lerp(bounds.position, alpha), old_bounds.size.lerp(bounds.size, alpha))
				var back := bounds.end.z + 0.018
				if back > 0.24:
					var center := bounds.get_center()
					profiles.append(Vector4(center.x, center.y, bounds.size.x * 0.5, bounds.size.y * 0.5))
					backs.append(back)
					maximum_back = maxf(maximum_back, back)
			shapes.append({"transform": shape_frame, "inverse": shape_frame.affine_inverse(), "half": shape.half, "kind": shape.kind, "profiles": profiles, "backs": backs, "maximum_back": maximum_back, "worn": shape.get("worn", false), "start": shape.get("start", COLUMNS + 1)})
		var retention := exp(-step * DAMPING)
		var ratio := clampf(step / _last_step, 0.1, 2.0)
		for i in range(COLUMNS + 1, positions.size()):
			var old := positions[i]
			var travel := ((positions[i] - previous[i]) * ratio).limit_length(3.5 * step)
			positions[i] += travel * retention + _row_accelerations[i / (COLUMNS + 1)]
			previous[i] = old
		_pin(seam)
		for iteration in range(ITERATIONS):
			for edge in range(_edge_a.size()):

				var e := edge if iteration % 2 == 0 else _edge_a.size() - 1 - edge
				var a := _edge_a[e]
				var b := _edge_b[e]
				var delta := positions[b] - positions[a]
				var length := delta.length()
				if length < 1.0e-06:
					continue
				var a_free := a > COLUMNS
				var b_free := b > COLUMNS
				var free_count := int(a_free) + int(b_free)
				if free_count == 0:
					continue
				var correction := delta * ((length - _world_lengths[e]) / length) * _edge_stiffness[e] / free_count
				if a_free:
					positions[a] += correction
				if b_free:
					positions[b] -= correction
			_limit_stretch(seam)
			_collide(shapes)



		for cleanup in range(1):
			_limit_stretch(seam)
			_collide(shapes, false)
		_last_step = step
	_last_frame = frame
	_last_velocity = velocity if velocity.is_finite() else Vector3.ZERO
	_last_colliders = colliders.duplicate()
	_stabilize_edges()


	var inverse := frame.affine_inverse()
	for point in positions:
		if not point.is_finite() or (inverse * point).length() > 2.2:
			reset(frame)
			break
	_update_mesh(frame)

func _pin(frame: Transform3D) -> void:
	for i in range(COLUMNS + 1):
		positions[i] = frame * rest[i]
		previous[i] = positions[i]




func _stabilize_edges() -> void:
	for pass_index in range(16):
		var worst := 1.0
		for edge in range(_edge_a.size()):
			if _edge_stiffness[edge] < 0.99:
				continue
			var a := _edge_a[edge]
			var b := _edge_b[edge]
			var delta := positions[b] - positions[a]
			var length := delta.length()
			var rest_length := maxf(1.0e-06, _world_lengths[edge])
			worst = maxf(worst, length / rest_length)
			if length <= rest_length * 1.04:
				continue
			var free_count := int(a > COLUMNS) + int(b > COLUMNS)
			if free_count == 0:
				continue
			var correction := delta * ((length - rest_length * 1.04) / length / free_count)
			if a > COLUMNS:
				positions[a] += correction
				previous[a] += correction
			if b > COLUMNS:
				positions[b] -= correction
				previous[b] -= correction
		if worst < 1.09:
			break





func _limit_stretch(_frame: Transform3D) -> void:
	for row in range(1, ROWS + 1):
		for col in range(COLUMNS + 1):
			var i := row * (COLUMNS + 1) + col
			var seam := _seam_points[col]
			var tether := _tether_limits[i]
			positions[i] = seam + (positions[i] - seam).limit_length(tether)
			var parent := i - COLUMNS - 1
			var length := _vertical_limits[i]
			positions[i] = positions[parent] + (positions[i] - positions[parent]).limit_length(length)
		for offset in range(1, COLUMNS / 2 + 1):
			for side in [-1, 1]:
				var col: int = COLUMNS / 2 + offset * side
				var i: int = row * (COLUMNS + 1) + col
				var parent: int = i - side
				var length := _horizontal_limits[i]
				positions[i] = positions[parent] + (positions[i] - positions[parent]).limit_length(length)

func _collide(shapes: Array, include_lower: bool = true) -> void:
	for shape in shapes:
		var kind: String = shape.kind
		if not include_lower and kind == "lower_body":
			continue
		var inverse: Transform3D = shape.inverse
		var forward: Transform3D = shape.transform
		var half: Vector3 = shape.half
		var worn: bool = shape.worn
		var profiles: Array = shape.profiles
		var backs: Array = shape.backs
		var maximum_back: float = shape.maximum_back
		for i in range(maxi(COLUMNS + 1, int(shape.start)), positions.size()):
			var point := inverse * positions[i]
			var projected := point
			if kind == "lower_body":
				if point.y >= 1.1 or point.z >= maximum_back:
					if point.z >= 0.24:
						continue
					projected.z = 0.24
				else:
					var target := 0.24
					var gradient := Vector2.ZERO
					for part in range(profiles.size()):
						var back: float = backs[part]
						if back <= target:
							continue
						var profile: Vector4 = profiles[part]
						var center := Vector2(profile.x, profile.y)
						var distance := Vector2(maxf(0.0, absf(point.x - center.x) - profile.z - 0.12), maxf(0.0, absf(point.y - center.y) - profile.w - 0.12)) / 0.34
						var t := clampf(distance.length_squared(), 0.0, 1.0)
						var influence := 1.0 - smoothstep(0.0, 1.0, t)
						var height := 0.24 + (back - 0.24) * influence
						if height > target:
							target = height
							gradient = Vector2(distance.x * signf(point.x - center.x), distance.y * signf(point.y - center.y)) * (back - 0.24) * (12.0 * t * (t - 1.0) / 0.34)
					var fade := clampf((point.y - 0.94) / 0.16, 0.0, 1.0)
					var weight := 1.0 - smoothstep(0.0, 1.0, fade)
					gradient = gradient * weight + Vector2(0, (target - 0.24) * (-6.0 * fade * (1.0 - fade) / 0.16))
					target = lerpf(0.24, target, weight)
					if point.z >= target:
						continue



					var normal := Vector3(-gradient.x, -gradient.y, 1.0)
					projected += normal * ((target - point.z) / normal.length_squared())
			elif kind == "ellipsoid":
				var normalized := point / half
				if normalized.length_squared() >= 1.0:
					continue
				projected = (normalized.normalized() if normalized.length_squared() > 1.0e-06 else Vector3.BACK) * half
			elif kind == "backpack":



				if (not worn and absf(point.x) >= half.x) or absf(point.y) >= half.y or point.z <= -half.z:
					continue
				if point.y + half.y < point.z + half.z:
					projected.y = -half.y - 0.001
				else:
					projected.z = -half.z
			else:
				if absf(point.x) >= half.x or absf(point.y) >= half.y or absf(point.z) >= half.z:
					continue
				var distance := half - point.abs()
				var axis := 0 if distance.x < distance.y and distance.x < distance.z else 1 if distance.y < distance.z else 2
				projected[axis] = half[axis] * (1.0 if point[axis] >= 0.0 else -1.0)
			var correction: Vector3 = forward * projected - positions[i]
			positions[i] += correction
			previous[i] += correction * 0.92

func local_vertices(frame: Transform3D) -> PackedVector3Array:
	var inverse := frame.affine_inverse()
	var vertices := PackedVector3Array()
	vertices.resize(positions.size())
	for i in range(positions.size()):
		vertices[i] = inverse * positions[i]
	return vertices

func _update_mesh(frame: Transform3D) -> void:
	var inverse := frame.affine_inverse()
	for i in range(positions.size()):
		_local[i] = inverse * positions[i]
	for row in range(ROWS + 1):
		for col in range(COLUMNS + 1):
			var i := row * (COLUMNS + 1) + col
			var point := _local[i]
			_vertex_bytes.encode_float(i * 12, point.x)
			_vertex_bytes.encode_float(i * 12 + 4, point.y)
			_vertex_bytes.encode_float(i * 12 + 8, point.z)
			var across := _local[row * (COLUMNS + 1) + mini(COLUMNS, col + 1)] - _local[row * (COLUMNS + 1) + maxi(0, col - 1)]
			var along := _local[mini(ROWS, row + 1) * (COLUMNS + 1) + col] - _local[maxi(0, row - 1) * (COLUMNS + 1) + col]
			var normal := along.cross(across).normalized()
			var encoded := normal.octahedron_encode()
			_vertex_bytes.encode_u16(_normal_offset + i * _normal_stride, int(clampf(encoded.x * 65535.0, 0, 65535)))
			_vertex_bytes.encode_u16(_normal_offset + i * _normal_stride + 2, int(clampf(encoded.y * 65535.0, 0, 65535)))
	mesh.surface_update_vertex_region(0, 0, _vertex_bytes)
