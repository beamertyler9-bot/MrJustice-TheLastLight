extends RefCounted
## Proper little fish for every catch: a smooth, shaped body (darker back, pale belly, the
## species' own markings), a forked tail, dorsal, pectoral and anal fins, and bright eyes.
## Each fish is one mesh with two surfaces (body and fins), coloured per vertex, so it costs
## two draws however detailed it looks. Head points along +X, centred at y = 0.12, the same
## frame as the old models, so hands and fishing lines hold them the same way.

const SPECIES := {
	# length, height, width (of the body), back, belly, fin, pattern, tail fork, dorsal style
	"lake_fish": {"length": 0.46, "height": 0.17, "width": 0.11, "back": "#4d6e55", "belly": "#d9e2c3", "fin": "#7f9a6d", "pattern": "stripe", "fork": 0.35, "dorsal": "spiny"},
	"silver_trout": {"length": 0.48, "height": 0.15, "width": 0.1, "back": "#5b7f8d", "belly": "#eef3f2", "fin": "#9fb7bd", "pattern": "trout", "fork": 0.2, "dorsal": "soft"},
	"reed_perch": {"length": 0.42, "height": 0.2, "width": 0.11, "back": "#59702f", "belly": "#e9e2a6", "fin": "#d6773a", "pattern": "bars", "fork": 0.3, "dorsal": "spiny"},
	"golden_carp": {"length": 0.4, "height": 0.23, "width": 0.13, "back": "#b9822a", "belly": "#ffe7a3", "fin": "#d99a3a", "pattern": "scales", "fork": 0.25, "dorsal": "long"},
	"moon_eel": {"length": 0.66, "height": 0.08, "width": 0.07, "back": "#4a3f6b", "belly": "#cfc8ee", "fin": "#8b80ad", "pattern": "moon", "fork": 0.0, "dorsal": "eel"},
	"crystal_koi": {"length": 0.42, "height": 0.2, "width": 0.12, "back": "#f4eefc", "belly": "#ffffff", "fin": "#d9c4f5", "pattern": "koi", "fork": 0.15, "dorsal": "long", "glow": 0.25},
	"cola_carp": {"length": 0.4, "height": 0.22, "width": 0.13, "back": "#5a301c", "belly": "#d9a36d", "fin": "#8a4c2a", "pattern": "fizz", "fork": 0.25, "dorsal": "long"},
	"fizzfin": {"length": 0.38, "height": 0.17, "width": 0.1, "back": "#e0742d", "belly": "#ffe2bf", "fin": "#ffb26b", "pattern": "fizz", "fork": 0.4, "dorsal": "sail"},
	"frost_char": {"length": 0.46, "height": 0.16, "width": 0.1, "back": "#3f6f86", "belly": "#f1e3dc", "fin": "#e9845f", "pattern": "char", "fork": 0.15, "dorsal": "soft"},
	"sunscale_bream": {"length": 0.4, "height": 0.27, "width": 0.09, "back": "#a8862f", "belly": "#fff1b8", "fin": "#e0b54a", "pattern": "scales", "fork": 0.45, "dorsal": "spiny"},
}
const RINGS := 18
const SIDES := 14
const CENTER_Y := 0.12

static var _meshes: Dictionary = {}
static var _body_material: StandardMaterial3D
static var _fin_material: StandardMaterial3D


static func supports(kind: String) -> bool:
	return SPECIES.has(kind)


static func build(parent: Node3D, kind: String) -> Node3D:
	var fish := MeshInstance3D.new(); fish.name = "Fish"
	fish.mesh = mesh(kind)
	parent.add_child(fish)
	return fish


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind): return _meshes[kind]
	var spec: Dictionary = SPECIES.get(kind, SPECIES.lake_fish)
	var result := ArrayMesh.new()
	_add_surface(result, _body(spec), _materials()[0])
	_add_surface(result, _fins(spec), _materials()[1])
	_meshes[kind] = result
	return result


static func _materials() -> Array:
	if _body_material == null:
		_body_material = StandardMaterial3D.new()
		_body_material.vertex_color_use_as_albedo = true
		_body_material.roughness = 0.32; _body_material.metallic = 0.15
		_body_material.metallic_specular = 0.7
		_fin_material = StandardMaterial3D.new()
		_fin_material.vertex_color_use_as_albedo = true
		_fin_material.roughness = 0.55
		_fin_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return [_body_material, _fin_material]


static func _add_surface(target: ArrayMesh, tool: SurfaceTool, material: Material) -> void:
	tool.generate_normals()
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tool.commit_to_arrays())
	target.surface_set_material(target.get_surface_count() - 1, material)


## How thick the body is along its length (t = 0 at the tail, 1 at the nose).
static func _profile(t: float, eel: bool) -> float:
	if eel: return clampf(0.35 + 0.65 * smoothstep(0.0, 0.25, t), 0.0, 1.0) * (1.0 - pow(smoothstep(0.86, 1.0, t), 1.6) * 0.85)
	var peduncle := 0.28 + 0.72 * smoothstep(0.0, 0.42, t)
	var nose := 1.0 - pow(smoothstep(0.66, 1.0, t), 2.2) * 0.72
	return peduncle * nose


static func _pattern(spec: Dictionary, t: float, up: float, side: float, x: float) -> Color:
	# up: -1 belly .. 1 back; side: which flank (for koi patches)
	var back := Color(spec.back); var belly := Color(spec.belly)
	var color := belly.lerp(back, smoothstep(-0.35, 0.55, up))
	match str(spec.pattern):
		"stripe":
			if absf(up - 0.05) < 0.12 and t > 0.12 and t < 0.85: color = color.darkened(0.35)
		"trout":
			if absf(up - 0.0) < 0.14 and t > 0.15 and t < 0.85: color = color.lerp(Color("#e7909a"), 0.55)
			if up > 0.2 and fmod(floor(t * 23.0) + floor(up * 9.0), 3.0) == 0.0: color = color.darkened(0.45)
		"bars":
			if up > -0.25 and fmod(floor(t * 7.0), 2.0) == 0.0 and t > 0.15 and t < 0.85: color = color.darkened(0.4)
		"scales":
			if fmod(floor(t * 16.0) + floor((up + 1.0) * 5.0), 2.0) == 0.0: color = color.lightened(0.12)
			else: color = color.darkened(0.06)
		"moon":
			if up > 0.1 and fmod(floor(t * 11.0), 3.0) == 0.0 and absf(fmod(up * 6.0, 2.0) - 1.0) < 0.6: color = Color("#e8e2ff")
		"koi":
			var patch := sin(t * 11.0 + side * 2.3) + sin(up * 5.0 + t * 4.0 + side)
			if patch > 0.7 and up > -0.4: color = Color("#8e54d6")
			elif patch < -1.1 and up > 0.0: color = Color("#2f2340")
		"fizz":
			if fmod(floor(t * 29.0) * 7.0 + floor((up + 1.0) * 11.0) * 3.0 + floor(side * 5.0), 11.0) == 0.0: color = color.lerp(Color("#fff3df"), 0.8)
		"char":
			if up > -0.1 and fmod(floor(t * 19.0) + floor((up + 1.0) * 7.0) * 2.0, 4.0) == 0.0: color = color.lerp(Color("#f6d2c4"), 0.75)
			if up < -0.55: color = color.lerp(Color("#e9845f"), 0.5)
	return color


static func _body(spec: Dictionary) -> SurfaceTool:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := float(spec.length); var height := float(spec.height) * 0.5; var width := float(spec.width) * 0.5
	var eel: bool = spec.dorsal == "eel"
	var rings: Array = []
	for r in range(RINGS + 1):
		var t := float(r) / RINGS
		var x := -length * 0.5 + length * t
		var thick := _profile(t, eel)
		var ring: Array = []
		for s in range(SIDES):
			var a := TAU * s / SIDES
			var up := cos(a)
			var flank := sin(a)
			# A slightly flat belly and a rounded back.
			var y := up * height * thick * (1.0 if up > 0.0 else 0.82) + (sin(t * PI * 3.0) * 0.004 if eel else 0.0)
			var z := flank * width * thick
			ring.append([Vector3(x, CENTER_Y + y, z), _pattern(spec, t, up, signf(flank), x)])
		rings.append(ring)
	for r in range(RINGS):
		for s in range(SIDES):
			var a: Array = rings[r][s]; var b: Array = rings[r][(s + 1) % SIDES]
			var c: Array = rings[r + 1][s]; var d: Array = rings[r + 1][(s + 1) % SIDES]
			for v in [a, c, b, b, c, d]:
				tool.set_color(v[1]); tool.add_vertex(v[0])
	# Close the nose and the tail end.
	for end in [[0, -1.0], [RINGS, 1.0]]:
		var ring: Array = rings[end[0]]
		var centre := Vector3.ZERO
		for v in ring: centre += v[0]
		centre /= ring.size(); centre.x += 0.012 * end[1]
		for s in range(SIDES):
			var a: Array = ring[s]; var b: Array = ring[(s + 1) % SIDES]
			var tri := [a, b] if end[1] > 0 else [b, a]
			tool.set_color(a[1]); tool.add_vertex(centre)
			tool.set_color(tri[0][1]); tool.add_vertex(tri[0][0])
			tool.set_color(tri[1][1]); tool.add_vertex(tri[1][0])
	# Eyes: a pale ring, a dark pupil and a tiny highlight, on both sides.
	var eye_x := length * 0.5 - length * (0.1 if eel else 0.16)
	var eye_t := (eye_x + length * 0.5) / length
	var eye_size := height * (0.3 if not eel else 0.5)
	for side in [-1.0, 1.0]:
		var at := Vector3(eye_x, CENTER_Y + height * 0.28 * _profile(eye_t, eel), side * (width * _profile(eye_t, eel) * 0.97 + 0.004))
		_disc(tool, at, Vector3(0, 0, side), eye_size, Color("#f2efe0"))
		_disc(tool, at + Vector3(0.002, 0, side * 0.003), Vector3(0, 0, side), eye_size * 0.62, Color("#141414"))
		_disc(tool, at + Vector3(0.006, eye_size * 0.18, side * 0.005), Vector3(0, 0, side), eye_size * 0.18, Color("#ffffff"))
	return tool


static func _disc(tool: SurfaceTool, at: Vector3, facing: Vector3, radius: float, color: Color) -> void:
	var u := Vector3(1, 0, 0); var v := Vector3(0, 1, 0)
	for i in range(10):
		var a := TAU * i / 10.0; var b := TAU * (i + 1) / 10.0
		var p1 := at + (u * cos(a) + v * sin(a)) * radius
		var p2 := at + (u * cos(b) + v * sin(b)) * radius
		tool.set_color(color)
		if facing.z > 0: tool.add_vertex(at); tool.add_vertex(p2); tool.add_vertex(p1)
		else: tool.add_vertex(at); tool.add_vertex(p1); tool.add_vertex(p2)


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	tool.set_color(ca); tool.add_vertex(a)
	tool.set_color(cb); tool.add_vertex(b)
	tool.set_color(cc); tool.add_vertex(c)


static func _fins(spec: Dictionary) -> SurfaceTool:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := float(spec.length); var height := float(spec.height) * 0.5; var width := float(spec.width) * 0.5
	var fin := Color(spec.fin); var root := fin.darkened(0.25); var tip := fin.lightened(0.18)
	var eel: bool = spec.dorsal == "eel"
	var tail_x := -length * 0.5
	var y := CENTER_Y
	# Tail: a fan, forked by spec.fork.
	if not eel:
		var span := height * 1.35
		var reach := length * 0.26
		var fork := float(spec.fork)
		var points: Array = []
		for i in range(9):
			var a := lerpf(-1.0, 1.0, i / 8.0)
			var notch := 1.0 - fork * (1.0 - absf(a)) * 1.6
			points.append(Vector3(tail_x - reach * maxf(0.35, notch), y + a * span, 0))
		var base := Vector3(tail_x + 0.01, y, 0)
		for i in range(8): _tri(tool, base, points[i], points[i + 1], root, tip, tip)
	# Dorsal fin along the back.
	var start := 0.3 if spec.dorsal != "eel" else 0.05
	var finish: float = {"spiny": 0.68, "soft": 0.62, "long": 0.72, "sail": 0.75, "eel": 0.85}.get(str(spec.dorsal), 0.65)
	var tall: float = {"spiny": 0.75, "soft": 0.55, "long": 0.5, "sail": 1.25, "eel": 0.45}.get(str(spec.dorsal), 0.6) * height
	var steps := 8
	for i in range(steps):
		var t0 := lerpf(start, finish, float(i) / steps); var t1 := lerpf(start, finish, float(i + 1) / steps)
		var x0 := -length * 0.5 + length * t0; var x1 := -length * 0.5 + length * t1
		var y0 := y + height * _profile(t0, eel) * 0.97; var y1 := y + height * _profile(t1, eel) * 0.97
		var rise0 := tall * sin(PI * float(i) / steps * 0.85 + 0.25)
		var rise1 := tall * sin(PI * float(i + 1) / steps * 0.85 + 0.25)
		if spec.dorsal == "spiny":
			rise0 *= 0.75 + 0.25 * float(i % 2); rise1 *= 0.75 + 0.25 * float((i + 1) % 2)
		_tri(tool, Vector3(x0, y0, 0), Vector3(x1, y1, 0), Vector3(x0 - 0.01, y0 + rise0, 0), root, root, tip)
		_tri(tool, Vector3(x1, y1, 0), Vector3(x1 - 0.01, y1 + rise1, 0), Vector3(x0 - 0.01, y0 + rise0, 0), root, tip, tip)
	if eel:
		# The eel's fin runs underneath too, all the way to its pointed tail.
		for i in range(steps):
			var t0 := lerpf(0.0, 0.5, float(i) / steps); var t1 := lerpf(0.0, 0.5, float(i + 1) / steps)
			var x0 := -length * 0.5 + length * t0; var x1 := -length * 0.5 + length * t1
			var y0 := y - height * _profile(t0, eel) * 0.8; var y1 := y - height * _profile(t1, eel) * 0.8
			_tri(tool, Vector3(x0, y0, 0), Vector3(x0 - 0.01, y0 - tall * 0.7, 0), Vector3(x1, y1, 0), root, tip, root)
		return tool
	# Pectoral fins just behind the gills, swept back and down.
	var gill_x := length * 0.5 - length * 0.3
	var gill_t := (gill_x + length * 0.5) / length
	for side in [-1.0, 1.0]:
		var at := Vector3(gill_x, y - height * 0.25, side * width * _profile(gill_t, false) * 0.95)
		var big := 1.5 if spec.dorsal == "sail" else 1.0
		_tri(tool, at, at + Vector3(-length * 0.16 * big, -height * 0.35 * big, side * width * 0.9 * big), at + Vector3(-length * 0.06, height * 0.05, side * width * 0.3), root, tip, root)
	# Pelvic and anal fins underneath.
	for pair in [[0.55, 0.4], [0.25, 0.5]]:
		var t0: float = pair[0]
		var x0 := -length * 0.5 + length * t0
		var base_y := y - height * _profile(t0, false) * 0.8
		_tri(tool, Vector3(x0, base_y, 0), Vector3(x0 - length * 0.1, base_y, 0), Vector3(x0 - length * 0.08, base_y - height * float(pair[1]), 0), root, root, tip)
	return tool
