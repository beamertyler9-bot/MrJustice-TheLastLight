extends RefCounted




const PROFILE_NAMES := ["organic", "torso", "skull", "calf", "boot", "hair", "cloth", "rock", "plate", "snout", "horn", "leaf", "fur"]
const SECTORS := 20
const ROWS := 14
const MATERIAL_LIMIT := 256
const TUBE_LIMIT := 96
const TUBE_INPUT_LIMIT := 16
static var materials: Dictionary = {}
static var textures: Dictionary = {}
static var profile_meshes: Dictionary = {}
static var tube_meshes: Dictionary = {}

static func material(kind: String, tint: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var family := kind if kind in ["skin", "cloth", "leather", "bark", "stone", "metal", "fur", "hair", "crystal", "ceramic", "bone"] else "skin"
	var color := Color(_channel(tint.r), _channel(tint.g), _channel(tint.b), 1.0)
	var metallic := snappedf(clampf(metal if is_finite(metal) else 0.0, 0.0, 1.0), 0.0625)
	var emission := snappedf(clampf(glow if is_finite(glow) else 0.0, 0.0, 8.0), 0.0625)
	var key := "%s:%s:%s:%s" % [family, color.to_html(false), metallic, emission]
	if materials.has(key): return materials[key]
	var surface := StandardMaterial3D.new()
	surface.resource_name = "Cast %s %s" % [family, color.to_html(false)]
	surface.albedo_color = color
	surface.metallic = metallic
	surface.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	surface.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	surface.cull_mode = BaseMaterial3D.CULL_BACK
	surface.roughness = {"skin": 0.76, "cloth": 0.94, "leather": 0.68, "bark": 0.96, "stone": 0.93, "metal": 0.37, "fur": 0.97, "hair": 0.64, "crystal": 0.22, "ceramic": 0.34, "bone": 0.73}[family]
	surface.metallic_specular = 0.25 if family in ["skin", "cloth", "fur", "bark"] else 0.48
	var prefix := family
	if family == "cloth": prefix = "fabric_pattern_07"
	if family == "leather": prefix = "brown_leather"
	if family == "bark": prefix = "bark_brown_02"
	if family == "cloth" or family == "leather":


		surface.albedo_texture = _texture("%s_color.png" % family)
		surface.normal_texture = _texture("%s_nor_gl_1k.jpg" % prefix)
		surface.roughness_texture = _texture("%s_rough_1k.jpg" % prefix)
	elif family == "bark":
		surface.albedo_texture = _texture("bark_brown_02_diff_1k.jpg")
		surface.normal_texture = _texture("bark_brown_02_nor_gl_1k.jpg")
		surface.roughness_texture = _texture("bark_brown_02_rough_1k.jpg")
	else:
		surface.albedo_texture = _texture("%s_color.png" % family)
		surface.normal_texture = _texture("%s_normal.png" % family)
		surface.roughness_texture = _texture("%s_rough.png" % family)
	surface.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	surface.normal_enabled = surface.normal_texture != null
	surface.normal_scale = {"skin": 0.07, "cloth": 0.14, "leather": 0.13, "bark": 0.34, "stone": 0.22, "metal": 0.1, "fur": 0.19, "hair": 0.22, "crystal": 0.08, "ceramic": 0.06, "bone": 0.1}[family]
	var density: float = {"skin": 1.0, "cloth": 2.4, "leather": 1.7, "bark": 1.0, "stone": 1.3, "metal": 1.2, "fur": 2.0, "hair": 1.0, "crystal": 1.0, "ceramic": 1.0, "bone": 1.2}[family]
	surface.uv1_scale = Vector3(density, density, density)
	surface.set_meta("static_palette", true)
	surface.set_meta("cast_family", family)
	if emission > 0.0:
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = emission
	_cache_put(materials, key, surface, MATERIAL_LIMIT)
	return surface

static func _channel(value: float) -> float:
	return snappedf(clampf(value if is_finite(value) else 0.7, 0.0, 1.0), 1.0 / 64.0)

static func _texture(filename: String) -> Texture2D:
	if not textures.has(filename): textures[filename] = load("res://assets/cast/" + filename)
	return textures[filename]

static func _cache_put(cache: Dictionary, key: String, resource: Resource, limit: int) -> void:


	if cache.size() >= limit: cache.erase(cache.keys()[0])
	cache[key] = resource

static func sculpt(parent: Node3D, at: Vector3, size: Vector3, surface: Material, profile: String = "organic") -> MeshInstance3D:
	var family := profile if profile in PROFILE_NAMES else "organic"
	if not profile_meshes.has(family): profile_meshes[family] = _sculpt_mesh(family)
	var node := MeshInstance3D.new()
	node.mesh = profile_meshes[family]
	node.material_override = surface
	node.position = at if at.is_finite() else Vector3.ZERO
	node.scale = Vector3(maxf(absf(size.x), 0.0001), maxf(absf(size.y), 0.0001), maxf(absf(size.z), 0.0001)) if size.is_finite() else Vector3.ONE
	parent.add_child(node)
	return node

static func finish(part: Node3D) -> void:
	preload("res://scripts/cast_batch.gd").finish(part)

static func _section(profile: String, v: float) -> Vector3:


	var envelope := pow(maxf(0.0, sin(v * PI)), 0.57)
	var section := Vector3(0.5 * envelope, 0.5 * envelope, 0.0)
	match profile:
		"torso":
			section.x *= 0.73 + 0.32 * exp(-pow((v - 0.74) / 0.18, 2.0)) + 0.14 * exp(-pow((v - 0.15) / 0.19, 2.0))
			section.y *= 0.73 + 0.16 * exp(-pow((v - 0.42) / 0.28, 2.0))
			section.z = 0.035 * sin(v * PI) - 0.045 * exp(-pow((v - 0.78) / 0.2, 2.0))
		"skull":
			section.x *= 0.69 + 0.31 * smoothstep(0.15, 0.52, v)
			section.y *= 0.91 + 0.08 * sin(v * PI)
			section.z = 0.035 * exp(-pow((v - 0.3) / 0.23, 2.0))
		"calf":
			section.x *= 0.6 + 0.4 * exp(-pow((v - 0.64) / 0.26, 2.0))
			section.y *= 0.55 + 0.45 * exp(-pow((v - 0.62) / 0.24, 2.0))
			section.z = -0.055 * sin(v * PI)
		"boot":
			section.x *= 0.73 + 0.21 * exp(-pow((v - 0.25) / 0.23, 2.0))
			section.y *= 0.58 + 0.61 * exp(-pow((v - 0.22) / 0.22, 2.0))
			section.z = 0.18 * exp(-pow((v - 0.22) / 0.23, 2.0)) - 0.055 * v
		"hair":
			section.x *= 0.87 + 0.13 * v
			section.z = -0.055 * sin(v * PI)
		"cloth":
			section.x *= 1.08 - v * 0.33
			section.y *= 0.89 - v * 0.14
		"plate":
			section.x = 0.5 * pow(maxf(0.0, sin(v * PI)), 0.36)
			section.y = section.x * 0.55
			section.z = 0.055 * sin(v * PI)
		"snout":
			section.x *= 0.78 + 0.22 * sin(v * PI)
			section.z = 0.1 * sin(v * PI)
		"horn":
			section.x = 0.48 * pow(maxf(0.0, sin(v * PI)), 0.62) * (1.0 - v * 0.84)
			section.y = section.x * 0.84
			section.z = 0.31 * v * v
		"leaf":
			section.x = 0.5 * pow(maxf(0.0, sin(v * PI)), 0.9)
			section.y = section.x * (0.25 + 0.05 * sin(v * PI))
			section.z = 0.12 * sin(v * PI)
	return section

static func _point(profile: String, v: float, u: float) -> Vector3:
	var angle := u * TAU
	var section := _section(profile, v)
	var cosine := cos(angle)
	var sine := sin(angle)
	var ripple := 1.0
	if profile == "rock": ripple += 0.085 * sin(angle * 3.0 + v * 5.0) + 0.04 * cos(angle * 5.0 - v * 3.0)
	if profile == "cloth": ripple += 0.045 * sin(angle * 8.0 + v * 0.7) * (1.0 - v)
	if profile == "hair": ripple += 0.035 * sin(angle * 7.0 + v * 4.0) * sin(v * PI)
	if profile == "fur": ripple += 0.045 * sin(angle * 6.0 + v * 9.0) * sin(v * PI)
	if profile == "plate":
		cosine = signf(cosine) * pow(absf(cosine), 0.62)
		sine = signf(sine) * pow(absf(sine), 0.62)
	if profile == "skull" and sine > 0.0: sine = pow(sine, 0.82)
	return Vector3(cosine * section.x * ripple, v - 0.5, sine * section.y * ripple + section.z)

static func _sculpt_mesh(profile: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	for row in range(ROWS + 1):
		var v := float(row) / float(ROWS)
		for sector in range(SECTORS + 1):
			var u := float(sector) / float(SECTORS)
			var point := _point(profile, v, u)
			var along := _point(profile, minf(1.0, v + 0.0005), u) - _point(profile, maxf(0.0, v - 0.0005), u)
			var around := _point(profile, v, u + 0.0005) - _point(profile, v, u - 0.0005)
			var normal := along.cross(around).normalized()
			if row == 0: normal = Vector3.DOWN
			if row == ROWS: normal = Vector3.UP
			var tangent := Vector3(-sin(u * TAU), 0.0, cos(u * TAU)) if around.length_squared() < 1.0e-09 else around.normalized()
			vertices.append(point)
			normals.append(normal)
			uvs.append(Vector2(u, 1.0 - v))
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1.0]))
	for row in range(ROWS):
		for sector in range(SECTORS):
			var i := row * (SECTORS + 1) + sector
			var next := i + SECTORS + 1
			if row > 0: indices.append_array(PackedInt32Array([i, i + 1, next]))
			if row < ROWS - 1: indices.append_array(PackedInt32Array([i + 1, next + 1, next]))



	var bounds := AABB(vertices[0], Vector3.ZERO)
	for point in vertices: bounds = bounds.expand(point)
	var multiplier := Vector3.ONE / bounds.size
	var center := bounds.get_center()
	for i in range(vertices.size()):
		vertices[i] = (vertices[i] - center) * multiplier
		normals[i] = (normals[i] / multiplier).normalized()
		var tangent := Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2]) * multiplier
		tangent = (tangent - normals[i] * tangent.dot(normals[i])).normalized()
		tangents[i * 4] = tangent.x
		tangents[i * 4 + 1] = tangent.y
		tangents[i * 4 + 2] = tangent.z
	return _mesh(vertices, normals, uvs, tangents, indices, "Cast " + profile)

static func tube(parent: Node3D, points: PackedVector3Array, radii: PackedFloat32Array, surface: Material, sides: int = 8) -> MeshInstance3D:
	var path := PackedVector3Array()
	var widths := PackedFloat32Array()
	for i in range(mini(points.size(), TUBE_INPUT_LIMIT)):
		if not points[i].is_finite(): continue
		var point := points[i].snapped(Vector3.ONE * 0.0009765625)
		if not path.is_empty() and point.distance_squared_to(path[-1]) < 1.0e-07: continue
		path.append(point)
		var width := radii[mini(i, radii.size() - 1)] if not radii.is_empty() else 0.05


		widths.append(clampf(snappedf(width if is_finite(width) else 0.05, 0.000244140625), 0.00075, 8.0))
	if path.size() < 2:
		path = PackedVector3Array([Vector3(0, -0.05, 0), Vector3(0, 0.05, 0)])
		widths = PackedFloat32Array([0.025, 0.025])
	var sectors := clampi(sides, 4, 12)
	var key := "%s:%s:%s" % [path, widths, sectors]
	if not tube_meshes.has(key): _cache_put(tube_meshes, key, _tube_mesh(path, widths, sectors), TUBE_LIMIT)
	var node := MeshInstance3D.new()
	node.mesh = tube_meshes[key]
	node.material_override = surface
	parent.add_child(node)
	return node

static func _tube_mesh(path: PackedVector3Array, widths: PackedFloat32Array, sectors: int) -> ArrayMesh:
	var centers := PackedVector3Array()
	var radii := PackedFloat32Array()
	for segment in range(path.size() - 1):
		for step in range(3):
			var t := float(step) / 3.0
			centers.append(path[segment].cubic_interpolate(path[segment + 1], path[maxi(segment - 1, 0)], path[mini(segment + 2, path.size() - 1)], t))
			radii.append(lerpf(widths[segment], widths[segment + 1], t))
	centers.append(path[-1])
	radii.append(widths[-1])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	var previous_side := Vector3.ZERO
	var distance := 0.0
	for row in range(centers.size()):
		var direction := (centers[mini(row + 1, centers.size() - 1)] - centers[maxi(row - 1, 0)]).normalized()
		if direction.length_squared() < 0.1: direction = Vector3.UP


		var side := previous_side - direction * previous_side.dot(direction)
		if side.length_squared() < 1.0e-05:
			side = direction.cross(Vector3.FORWARD if absf(direction.z) < 0.85 else Vector3.UP)
		side = side.normalized()
		var across := side.cross(direction).normalized()
		previous_side = side
		if row > 0: distance += centers[row].distance_to(centers[row - 1])
		var radius_slope := (radii[mini(row + 1, radii.size() - 1)] - radii[maxi(row - 1, 0)]) / maxf(1.0e-05, centers[mini(row + 1, centers.size() - 1)].distance_to(centers[maxi(row - 1, 0)]))
		for sector in range(sectors + 1):
			var u := float(sector) / float(sectors)
			var angle := u * TAU
			var radial := side * cos(angle) + across * sin(angle)
			var normal := (radial - direction * radius_slope).normalized()
			var tangent := (-side * sin(angle) + across * cos(angle)).normalized()
			vertices.append(centers[row] + radial * radii[row])
			normals.append(normal)
			uvs.append(Vector2(u, distance))


			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, -1.0]))
	for row in range(centers.size() - 1):
		for sector in range(sectors):
			var i := row * (sectors + 1) + sector
			var next := i + sectors + 1
			indices.append_array(PackedInt32Array([i, i + 1, next, i + 1, next + 1, next]))

	for end in [0, centers.size() - 1]:
		var direction := (centers[1] - centers[0]).normalized() if end == 0 else (centers[-1] - centers[-2]).normalized()
		var normal := -direction if end == 0 else direction
		var start := vertices.size()
		var first: int = end * (sectors + 1)
		var side := (vertices[first] - centers[end]).normalized()
		var handedness := 1.0 if end == 0 else -1.0
		vertices.append(centers[end])
		normals.append(normal)
		uvs.append(Vector2(0.5, 0.5))
		tangents.append_array(PackedFloat32Array([side.x, side.y, side.z, handedness]))
		for sector in range(sectors + 1):
			var angle := float(sector) / float(sectors) * TAU
			vertices.append(vertices[first + sector])
			normals.append(normal)
			uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))
			tangents.append_array(PackedFloat32Array([side.x, side.y, side.z, handedness]))
		for sector in range(sectors):
			if end == 0: indices.append_array(PackedInt32Array([start, start + sector + 2, start + sector + 1]))
			else: indices.append_array(PackedInt32Array([start, start + sector + 1, start + sector + 2]))
	return _mesh(vertices, normals, uvs, tangents, indices, "Cast curved tube")

static func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, tangents: PackedFloat32Array, indices: PackedInt32Array, label: String) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var shape := ArrayMesh.new()
	shape.resource_name = label
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return shape
