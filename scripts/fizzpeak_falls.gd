extends RefCounted
## Fizzpeak's waterfalls and its cola lake.
##
## The cola river runs down Fizzpeak as a ribbon that follows the ground. Where it drops
## steeply (three big drops: about 100 m, 70 m and 55 m) a curtain of falling cola leaves
## the lip, arcs clear of the cliff and lands in a churn of foam and drifting spray. Where
## the river runs into the foothill lake it foams, and fizz springs bubble up across the
## lake. Everything here is a handful of see-through quads with animated shaders: no
## scripts run per frame, and each piece is only drawn within its visibility range.

const W = preload("res://scripts/water_profile.gd")
const CURTAIN_SHADER = preload("res://shaders/waterfall.gdshader")
const MIST_SHADER = preload("res://shaders/fizz_mist.gdshader")
const FOAM_SHADER = preload("res://shaders/fizz_foam.gdshader")
const MIN_DROP := 20.0
const MAX_FALLS := 3
const CURTAIN_RANGE := 1400.0
const SPRAY_RANGE := 320.0


static func build(parent: Node3D) -> void:
	var holder := Node3D.new(); holder.name = "FizzpeakFalls"
	parent.add_child(holder)
	var cascade: Dictionary = {}
	for river in W.watercourses():
		if str(river.get("id", "")) == "fizzpeak_cascade": cascade = river
	if cascade.is_empty(): return
	var sections: Array = cascade.sections
	for fall in drops(sections): _fall(holder, sections, fall[1], fall[2])
	for lake in W.lakes():
		if str(lake.get("id", "")) == "fizzpeak_foothill_lake": _lake(holder, lake, sections[-1])


static func _center(s: Dictionary) -> Vector2:
	return s.get("channel_center", (s.left + s.right) * 0.5)


## The steepest stretches of the river: [drop, from section, to section], biggest first,
## never overlapping.
static func drops(sections: Array) -> Array:
	var found: Array = []
	for i in range(sections.size()):
		var ci := _center(sections[i])
		for j in range(i + 1, mini(sections.size(), i + 60)):
			var horizontal := ci.distance_to(_center(sections[j]))
			if horizontal > 30.0: break
			var drop: float = float(sections[i].height) - float(sections[j].height)
			if drop > MIN_DROP and drop / maxf(horizontal, 0.1) > 1.5: found.append([drop, i, j])
	found.sort_custom(func (a, b): return a[0] > b[0])
	var chosen: Array = []
	for candidate in found:
		var clash := false
		for other in chosen:
			if not (candidate[2] < other[1] - 5 or candidate[1] > other[2] + 5): clash = true
		if not clash: chosen.append(candidate)
		if chosen.size() >= MAX_FALLS: break
	return chosen


static func _fall(holder: Node3D, sections: Array, from: int, to: int) -> void:
	var lip: Dictionary = sections[from]
	var foot: Dictionary = sections[to]
	var start := _center(lip)
	var land := _center(foot)
	var ahead := _center(sections[mini(from + 3, sections.size() - 1)]) - start
	var forward := (land - start).normalized().lerp(ahead.normalized(), 0.35).normalized()
	var across: Vector2 = (lip.right - lip.left).normalized()
	var top := float(lip.height) + 0.15
	var bottom := float(foot.height) + 0.05
	var drop := top - bottom
	var reach := start.distance_to(land)
	var width: float = lip.left.distance_to(lip.right)
	# The curtain follows a falling arc (out fast, then down), and is pushed out wherever the
	# cliff bulges, so it always hangs clear of the rock.
	var rows := 26
	var centres: Array = []
	var push := 0.0
	for k in range(rows + 1):
		var t := float(k) / rows
		var y := top - drop * t
		var s := reach * sqrt(t) + push
		var p := start + forward * s
		var tries := 0
		while k > 0 and k < rows and W.terrain_height(p) > y - 0.9 and tries < 40:
			push += 0.5; s += 0.5; p = start + forward * s; tries += 1
		centres.append(Vector3(p.x, y, p.y))
	var verts := PackedVector3Array(); var uvs := PackedVector2Array(); var colors := PackedColorArray(); var ids := PackedInt32Array()
	var columns := 6
	for k in range(rows + 1):
		var t := float(k) / rows
		var half := width * (0.42 + 0.22 * t)
		for c in range(columns + 1):
			var u := float(c) / columns
			var offset: Vector2 = across * (u - 0.5) * 2.0 * half
			verts.append(centres[k] + Vector3(offset.x, 0.0, offset.y))
			uvs.append(Vector2(u, t))
			colors.append(Color.WHITE * (0.82 + 0.18 * sin(u * PI)))
	for k in range(rows):
		for c in range(columns):
			var a := k * (columns + 1) + c
			ids.append_array(PackedInt32Array([a, a + columns + 1, a + 1, a + 1, a + columns + 1, a + columns + 2]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = ids
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var curtain := MeshInstance3D.new(); curtain.name = "FizzpeakWaterfall"; curtain.mesh = mesh
	var material := ShaderMaterial.new(); material.shader = CURTAIN_SHADER
	material.set_shader_parameter("length_m", drop)
	curtain.material_override = material
	_quiet(curtain, CURTAIN_RANGE)
	holder.add_child(curtain)
	# Where it lands: spreading foam rings and a cloud of spray.
	var landing: Vector3 = centres[rows]
	_foam(holder, Vector3(landing.x, bottom + 0.15, landing.z), width * 1.7, 0.8)
	var rng := RandomNumberGenerator.new(); rng.seed = from * 7919 + to
	for i in range(5):
		var spread := Vector3(rng.randf_range(-0.5, 0.5) * width, rng.randf_range(1.0, 2.0 + drop * 0.04), rng.randf_range(-0.5, 0.5) * width)
		_mist(holder, landing + spread, width * rng.randf_range(0.6, 0.95), 0.3, 0.0)
	# A little spray where it pours over the lip.
	_mist(holder, Vector3(start.x, top + 0.6, start.y) + Vector3(forward.x, 0, forward.y) * 1.5, width * 0.55, 0.25, 0.0)


static func _lake(holder: Node3D, lake: Dictionary, inflow: Dictionary) -> void:
	var height := float(lake.height)
	var entry := _center(inflow)
	_foam(holder, Vector3(entry.x, height + 0.15, entry.y), 22.0, 0.65)
	for i in range(3): _mist(holder, Vector3(entry.x + (i - 1) * 4.0, height + 1.2 + i * 0.6, entry.y), 7.0, 0.3, 0.0)
	# Fizz springs: spots well inside the lake where bubbles keep rising.
	var outline: PackedVector2Array = PackedVector2Array(lake.outline)
	var rng := RandomNumberGenerator.new(); rng.seed = 4401
	var springs: Array = []
	for attempt in range(400):
		if springs.size() >= 6: break
		var p: Vector2 = lake.pos + Vector2(rng.randf_range(-1, 1) * lake.extent.x, rng.randf_range(-1, 1) * lake.extent.y) * 0.8
		if not Geometry2D.is_point_in_polygon(p, outline): continue
		var inside := true
		for q in [p + Vector2(30, 0), p - Vector2(30, 0), p + Vector2(0, 30), p - Vector2(0, 30)]:
			if not Geometry2D.is_point_in_polygon(q, outline): inside = false
		var apart := true
		for other in springs: if p.distance_to(other) < 70.0: apart = false
		if inside and apart and W.terrain_height(p) < height - 0.5: springs.append(p)
	for p in springs:
		_foam(holder, Vector3(p.x, height + 0.15, p.y), 11.0, 0.85)
		for i in range(6): _mist(holder, Vector3(p.x + rng.randf_range(-2.0, 2.0), height + 0.3, p.y + rng.randf_range(-2.0, 2.0)), rng.randf_range(0.9, 1.6), 0.9, rng.randf_range(3.5, 6.0))


static func _foam(holder: Node3D, at: Vector3, size: float, strength: float) -> void:
	var quad := QuadMesh.new(); quad.size = Vector2.ONE; quad.orientation = PlaneMesh.FACE_Y
	var foam := MeshInstance3D.new(); foam.name = "FizzFoam"; foam.mesh = quad
	var material := ShaderMaterial.new(); material.shader = FOAM_SHADER
	material.set_shader_parameter("strength", strength)
	foam.material_override = material
	foam.position = at; foam.scale = Vector3(size, 1.0, size)
	_quiet(foam, SPRAY_RANGE)
	holder.add_child(foam)


static func _mist(holder: Node3D, at: Vector3, size: float, strength: float, rise: float) -> void:
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	var puff := MeshInstance3D.new(); puff.name = "FizzMist" if rise <= 0.0 else "FizzBubble"; puff.mesh = quad
	var material := ShaderMaterial.new(); material.shader = MIST_SHADER
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("rise", rise)
	if rise > 0.0: material.set_shader_parameter("mist_color", Color("#fff3df"))
	puff.material_override = material
	puff.position = at; puff.scale = Vector3(size, size, 1.0)
	# Billboards turn to face the camera in the shader, so give them room to do so.
	puff.extra_cull_margin = size + rise
	_quiet(puff, SPRAY_RANGE)
	holder.add_child(puff)


static func _quiet(node: GeometryInstance3D, range_end: float) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = range_end
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
