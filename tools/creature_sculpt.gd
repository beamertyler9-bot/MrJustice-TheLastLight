extends RefCounted
## Sculpting helpers for hand-made creature models.
##
## Every part is a smooth closed skin (lofted limbs, lathed caps, blobs) painted with vertex
## colours, and all parts of a creature share one material, so the pieces read as one
## character instead of boxes glued together. Painters get the world position, the normal,
## how far along the part the vertex is (v) and the bark-ridge phase (w), so moss can grow on
## every upward-facing surface and grooves can be darker, across every part alike.
##
## Used only when baking creature scenes; nothing here runs in the game.

var _v := PackedVector3Array()
var _i := PackedInt32Array()
var _along := PackedFloat32Array()
var _ridge := PackedFloat32Array()
var _painter := PackedInt32Array()
var _painters: Array = []
var _facets: Array = []


static func _hash(x: int, y: int, z: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + z * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 32767.5 - 1.0


## Smooth value noise in about -1..1.
static func noise(p: Vector3) -> float:
	var i := p.floor(); var f := p - i
	f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var x := int(i.x); var y := int(i.y); var z := int(i.z)
	var a := lerpf(_hash(x, y, z), _hash(x + 1, y, z), f.x)
	var b := lerpf(_hash(x, y + 1, z), _hash(x + 1, y + 1, z), f.x)
	var c := lerpf(_hash(x, y, z + 1), _hash(x + 1, y, z + 1), f.x)
	var d := lerpf(_hash(x, y + 1, z + 1), _hash(x + 1, y + 1, z + 1), f.x)
	return lerpf(lerpf(a, b, f.y), lerpf(c, d, f.y), f.z)


static func fbm(p: Vector3) -> float:
	return noise(p) * 0.6 + noise(p * 2.03 + Vector3(5.1, 1.7, 3.3)) * 0.3 + noise(p * 4.1 + Vector3(2.2, 7.9, 1.4)) * 0.15


static func _catmull(a, b, c, d, t: float):
	var t2 := t * t; var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3)


static func _smooth_path(points: Array, values: Array, per: int) -> Array:
	var p: Array = []; var r: Array = []
	var n := points.size()
	for s in range(n - 1):
		for k in range(per):
			var t := float(k) / per
			var i0 := maxi(s - 1, 0); var i3 := mini(s + 2, n - 1)
			p.append(_catmull(points[i0], points[s], points[s + 1], points[i3], t))
			r.append(_catmull(float(values[i0]), float(values[s]), float(values[s + 1]), float(values[i3]), t))
	p.append(points[-1]); r.append(float(values[-1]))
	return [p, r]


func add_painter(painter: Callable) -> int:
	_painters.append(painter)
	return _painters.size() - 1


## A grid of rings (each the same number of vertices) closed at either end by a tip vertex.
func _skin(rings: Array, tip_start, tip_end, painter: int, alongs: Array, ridges: Array) -> void:
	var sides: int = rings[0].size()
	var start_index := -1
	if tip_start != null:
		start_index = _v.size(); _v.append(tip_start); _along.append(0.0); _ridge.append(0.0); _painter.append(painter)
	var first := _v.size()
	for k in range(rings.size()):
		for j in range(sides):
			_v.append(rings[k][j]); _along.append(alongs[k]); _ridge.append(ridges[k][j]); _painter.append(painter)
	var end_index := -1
	if tip_end != null:
		end_index = _v.size(); _v.append(tip_end); _along.append(1.0); _ridge.append(0.0); _painter.append(painter)
	for k in range(rings.size() - 1):
		for j in range(sides):
			var j2 := (j + 1) % sides
			var a := first + k * sides + j; var c := first + k * sides + j2
			var b := first + (k + 1) * sides + j; var d := first + (k + 1) * sides + j2
			_i.append_array(PackedInt32Array([a, b, c, c, b, d]))
	for j in range(sides):
		var j2 := (j + 1) % sides
		if start_index >= 0: _i.append_array(PackedInt32Array([start_index, first + j, first + j2]))
		var last := first + (rings.size() - 1) * sides
		if end_index >= 0: _i.append_array(PackedInt32Array([last + j, end_index, last + j2]))


## A smooth limb along a path. Options: sides, per (smoothing steps per segment), flat (squash
## across), side (which way the squash faces), ridges/ridge (bark grooves), twist, lump
## (noise bulges), cap0/cap1 (round the ends).
func tube(points: Array, radii: Array, painter: int, opts: Dictionary = {}) -> void:
	var sides: int = opts.get("sides", 10)
	var smooth := _smooth_path(points, radii, int(opts.get("per", 3)))
	var path: Array = smooth[0]; var rad: Array = smooth[1]
	var flat: float = opts.get("flat", 1.0)
	var ridges: int = opts.get("ridges", 0); var depth: float = opts.get("ridge", 0.0)
	var twist: float = opts.get("twist", 0.0); var lump: float = opts.get("lump", 0.0)
	var square: float = opts.get("square", 0.0); var cap_len: float = opts.get("cap_len", 0.9)
	var bands: int = opts.get("bands", 0); var band_depth: float = opts.get("band", 0.0)
	var count := path.size()
	var tangents: Array = []
	for k in range(count):
		var a: Vector3 = path[maxi(k - 1, 0)]; var b: Vector3 = path[mini(k + 1, count - 1)]
		tangents.append((b - a).normalized())
	var hint: Vector3 = opts.get("side", Vector3.RIGHT)
	if absf(hint.normalized().dot(tangents[0])) > 0.95: hint = Vector3.FORWARD
	var normal: Vector3 = (hint - tangents[0] * hint.dot(tangents[0])).normalized()
	var rings: Array = []; var alongs: Array = []; var ridge_values: Array = []
	var cap_rings: int = opts.get("cap_rings", 3)
	var frames: Array = []
	for k in range(count):
		var t: Vector3 = tangents[k]
		normal = (normal - t * normal.dot(t)).normalized()
		frames.append([path[k], rad[k], normal, t.cross(normal), t, float(k) / (count - 1)])
	var expanded: Array = []
	if opts.get("cap0", true):
		var f0: Array = frames[0]
		for c in range(cap_rings, 0, -1):
			var ang := float(c) / (cap_rings + 1) * PI * 0.5
			expanded.append([f0[0] - f0[4] * f0[1] * sin(ang) * cap_len, f0[1] * cos(ang), f0[2], f0[3], f0[4], 0.0])
	expanded.append_array(frames)
	if opts.get("cap1", true):
		var f1: Array = frames[-1]
		for c in range(1, cap_rings + 1):
			var ang := float(c) / (cap_rings + 1) * PI * 0.5
			expanded.append([f1[0] + f1[4] * f1[1] * sin(ang) * cap_len, f1[1] * cos(ang), f1[2], f1[3], f1[4], 1.0])
	for f in expanded:
		var ring := PackedVector3Array(); var w: Array = []
		for j in range(sides):
			var ang: float = TAU * j / sides + twist * f[5]
			var dir: Vector3 = f[2] * cos(ang) * flat + f[3] * sin(ang)
			var phase: float = sin(ang * ridges + f[5] * 3.0 + noise(f[0] * 3.0) * 1.5) if ridges > 0 else 0.0
			var r: float = f[1] * (1.0 + depth * phase)
			if bands > 0:
				# Stacked layers: a groove between each band, like stone laid in courses.
				var layer: float = fposmod(f[5] * bands, 1.0)
				r *= 1.0 - band_depth * (1.0 - smoothstep(0.0, 0.14, layer) * smoothstep(1.0, 0.86, layer))
			if square > 0.0:
				var base_ang := TAU * j / sides
				r *= lerpf(1.0, minf(1.0 / maxf(absf(cos(base_ang)), absf(sin(base_ang))), 1.3), square)
			var p: Vector3 = f[0] + dir * r
			if lump > 0.0: p += dir.normalized() * f[1] * lump * fbm(p * 3.1)
			ring.append(p); w.append(phase)
		rings.append(ring); alongs.append(f[5]); ridge_values.append(w)
	var tip0 = null; var tip1 = null
	if opts.get("cap0", true): tip0 = frames[0][0] - frames[0][4] * frames[0][1] * cap_len
	if opts.get("cap1", true): tip1 = frames[-1][0] + frames[-1][4] * frames[-1][1] * cap_len
	var first := _i.size()
	_skin(rings, tip0, tip1, painter, alongs, ridge_values)
	if opts.get("facet", false): _facets.append(Vector2i(first, _i.size()))


## A squashed sphere. Options: basis (turn it), lat/lon (detail), lump.
func blob(center: Vector3, radii: Vector3, painter: int, opts: Dictionary = {}) -> void:
	var lat: int = opts.get("lat", 7); var lon: int = opts.get("lon", 10)
	var basis: Basis = opts.get("basis", Basis.IDENTITY)
	var lump: float = opts.get("lump", 0.0)
	var rings: Array = []; var alongs: Array = []; var ridge_values: Array = []
	for k in range(1, lat):
		var phi := PI * float(k) / lat
		var ring := PackedVector3Array(); var w: Array = []
		for j in range(lon):
			var th := TAU * j / lon
			var unit := Vector3(sin(phi) * cos(th), -cos(phi), -sin(phi) * sin(th))
			var p := center + basis * (unit * radii)
			if lump > 0.0: p += (basis * unit).normalized() * radii.length() * 0.577 * lump * fbm(p * 3.1)
			ring.append(p); w.append(0.0)
		rings.append(ring); alongs.append(float(k) / lat); ridge_values.append(w)
	_skin(rings, center + basis * Vector3(0, -radii.y, 0), center + basis * Vector3(0, radii.y, 0), painter, alongs, ridge_values)


## A shape spun round an axis: profile points are (radius, height), from top to bottom.
## Ends with radius 0 are closed.
func lathe(center: Vector3, profile: Array, painter: int, opts: Dictionary = {}) -> void:
	var sides: int = opts.get("sides", 14)
	var basis: Basis = opts.get("basis", Basis.IDENTITY)
	var wobble: float = opts.get("wobble", 0.0)
	var rings: Array = []; var alongs: Array = []; var ridge_values: Array = []
	var tip0 = null; var tip1 = null
	for k in range(profile.size()):
		var pr: Vector2 = profile[k]
		if pr.x <= 0.0001:
			if k == 0: tip0 = center + basis * Vector3(0, pr.y, 0)
			else: tip1 = center + basis * Vector3(0, pr.y, 0)
			continue
		var ring := PackedVector3Array(); var w: Array = []
		for j in range(sides):
			var th := TAU * j / sides
			var local := Vector3(cos(th) * pr.x, pr.y, sin(th) * pr.x)
			if wobble > 0.0: local.y += wobble * pr.x * noise(Vector3(cos(th), sin(th), 0.0) * 2.5 + center)
			ring.append(center + basis * local); w.append(0.0)
		rings.append(ring); alongs.append(float(k) / (profile.size() - 1)); ridge_values.append(w)
	_skin(rings, tip0, tip1, painter, alongs, ridge_values)


## A crystal: a six-sided prism with a pointed tip, drawn with flat faces.
func crystal(base: Vector3, direction: Vector3, length: float, radius: float, painter: int, sides := 6, twist := 0.0) -> void:
	var first := _i.size()
	var t := direction.normalized()
	var hint := Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
	var n := (hint - t * hint.dot(t)).normalized(); var b := t.cross(n)
	var rings: Array = []; var alongs: Array = []; var ridges: Array = []
	for k in range(2):
		var c := base + t * length * (0.0 if k == 0 else 0.72)
		var r := radius * (0.9 if k == 0 else 1.0)
		var ring := PackedVector3Array(); var w: Array = []
		for j in range(sides):
			var ang := TAU * j / sides + twist
			ring.append(c + (n * cos(ang) + b * sin(ang)) * r); w.append(0.0)
		rings.append(ring); alongs.append(0.0 if k == 0 else 0.72); ridges.append(w)
	_skin(rings, base - t * radius * 0.2, base + t * length, painter, alongs, ridges)
	_facets.append(Vector2i(first, _i.size()))


## An angular rock: a low-detail lumpy blob drawn with flat faces.
func rock(center: Vector3, radii: Vector3, painter: int, opts: Dictionary = {}) -> void:
	var first := _i.size()
	var o := opts.duplicate()
	o["lat"] = o.get("lat", 5); o["lon"] = o.get("lon", 7); o["lump"] = o.get("lump", 0.35)
	blob(center, radii, painter, o)
	_facets.append(Vector2i(first, _i.size()))


func triangles() -> int:
	return _i.size() / 3


## Bakes everything added so far into one mesh, moved so `origin` (in the same space the
## parts were placed in) becomes the mesh's origin.
func commit(material: Material, origin := Vector3.ZERO) -> ArrayMesh:
	var normals := PackedVector3Array(); normals.resize(_v.size())
	for t in range(0, _i.size(), 3):
		var a := _v[_i[t]]; var b := _v[_i[t + 1]]; var c := _v[_i[t + 2]]
		var n := (c - a).cross(b - a)
		for k in range(3): normals[_i[t + k]] += n
	var colors := PackedColorArray(); colors.resize(_v.size())
	var verts := PackedVector3Array(); verts.resize(_v.size())
	for k in range(_v.size()):
		var n := normals[k].normalized() if normals[k].length() > 0.0 else Vector3.UP
		normals[k] = n
		colors[k] = _painters[_painter[k]].call(_v[k], n, _along[k], _ridge[k])
		verts[k] = _v[k] - origin
	var indices := _i
	if not _facets.is_empty():
		# Faceted parts get their own corners, each lit by its face's own normal.
		var flat := {}
		for r in _facets:
			for t in range(r.x, r.y, 3): flat[t] = true
		indices = PackedInt32Array()
		for t in range(0, _i.size(), 3):
			if not flat.has(t):
				indices.append_array(PackedInt32Array([_i[t], _i[t + 1], _i[t + 2]]))
				continue
			var a := _v[_i[t]]; var b := _v[_i[t + 1]]; var c := _v[_i[t + 2]]
			var n := (c - a).cross(b - a).normalized()
			for k in range(3):
				var src := _i[t + k]
				indices.append(verts.size())
				verts.append(_v[src] - origin); normals.append(n)
				colors.append(_painters[_painter[src]].call(_v[src], n, _along[src], _ridge[src]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
