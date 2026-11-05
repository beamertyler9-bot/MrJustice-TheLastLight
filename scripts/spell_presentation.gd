extends RefCounted



const MAX_PROJECTILES := 42
const MAX_TRANSIENTS := 32
const MAX_TRAIL_SAMPLES := 24
const MAX_PROJECTILE_MOTES := 24
const MAX_TRANSIENT_MOTES := 32
const MAX_PARTICLES := MAX_PROJECTILES * MAX_PROJECTILE_MOTES + MAX_TRANSIENTS * MAX_TRANSIENT_MOTES
const MAX_MATERIALS := (MAX_PROJECTILES + MAX_TRANSIENTS) * 3 + 2
const MAX_NODES := 1100
const MAX_MESHES := 48
const ELEMENTS := ["flame", "frost", "storm", "grove", "light", "shadow", "water", "wind", "earth", "metal", "void", "time"]
const STYLES := ["elemental", "astral", "spectral", "crystal", "ink", "molten", "runic", "botanical"]
const ENERGY = preload("res://shaders/magic/energy.gdshader")
const FLAME = preload("res://shaders/magic/flame.gdshader")
const SURFACE = preload("res://shaders/magic/surface.gdshader")
const HALO = preload("res://shaders/magic/halo.gdshader")
const LENS = preload("res://shaders/magic/lens.gdshader")
const SEAL = preload("res://shaders/magic/seal.gdshader")
const MOTE = preload("res://shaders/magic/mote.gdshader")
const SMOKE = preload("res://shaders/magic/smoke.gdshader")
var _owner: WeakRef
var _projectiles: Dictionary = {}
var visuals: Array = []
var _lights: Array[OmniLight3D] = []
var _meshes: Dictionary = {}
var _mote_material: ShaderMaterial
var _smoke_material: ShaderMaterial

func setup(runtime) -> void:
	clear()
	_owner = weakref(runtime)

func _runtime() -> Node3D:
	return _owner.get_ref() if _owner != null and is_instance_valid(_owner.get_ref()) else null

func _settings() -> Dictionary:
	var runtime := _runtime()
	if runtime == null: return {}
	var game: Variant = runtime.get("game")
	if not is_instance_valid(game): return {}
	var state: Variant = game.get("state")
	return state.settings if state != null and state.get("settings") is Dictionary else {}

func _number(spell: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = spell.get(key, fallback)
	return clampf(float(value), low, high) if (value is float or value is int) and is_finite(float(value)) else fallback

func _color(spell: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = spell.get(key, "")
	return value if value is Color else Color.from_string(str(value), fallback)

func _family(spell: Dictionary) -> String:
	var element := str(spell.get("element", "light"))
	return "void" if element == "gravity" else element if element in ELEMENTS else "light"

func _material(shader: Shader, spell: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader = shader
	var body := _color(spell, "color", Color("a764ed"))
	var accent := _color(spell, "accent", Color("ffefc8"))
	material.set_shader_parameter("body_color", body)
	material.set_shader_parameter("core_color", _color(spell, "core_color", accent))
	material.set_shader_parameter("rim_color", _color(spell, "rim_color", body.lerp(accent, 0.4)))
	material.set_shader_parameter("trail_color", _color(spell, "trail_color", body))
	material.set_shader_parameter("edge_noise", _number(spell, "edge_noise", 0.5, 0.0, 2.0))
	material.set_shader_parameter("style", float(maxi(0, STYLES.find(str(spell.get("material_style", "elemental"))))))
	material.set_shader_parameter("family", float(ELEMENTS.find(_family(spell))))
	if shader == SEAL or shader == ENERGY: material.set_shader_parameter("sigil", float(maxi(0, ["circle", "star", "clock", "petals", "fracture"].find(str(spell.get("sigil", "circle"))))))
	_set_material_clock(material, spell, 0.0, 1.0)
	return material

func _set_material_clock(material: ShaderMaterial, spell: Dictionary, age: float, envelope: float) -> void:
	var low_flash := bool(_settings().get("low_flash", false))
	material.set_shader_parameter("age", maxf(0.0, age))
	material.set_shader_parameter("opacity", _number(spell, "opacity", 1.0, 0.08, 1.0) * envelope)
	material.set_shader_parameter("brightness", minf(_number(spell, "glow", 1.0, 0.0, 2.0), 0.8 if low_flash else 2.0))
	material.set_shader_parameter("low_flash", 1.0 if low_flash else 0.0)

func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind): return _meshes[kind]
	var mesh: Mesh
	match kind:
		"quad":
			var quad := QuadMesh.new(); quad.size = Vector2.ONE; mesh = quad
		"shock_card", "star_card":
			# Same unit quad, tagged through vertex colour so the halo shader draws a
			# shockwave ring (red) or a contact star-burst (green).
			var source := QuadMesh.new(); source.size = Vector2.ONE
			var arrays := source.get_mesh_arrays()
			var tag := Color(1, 0, 0, 1) if kind == "shock_card" else Color(0, 1, 0, 1)
			var colors := PackedColorArray(); colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()); colors.fill(tag)
			arrays[Mesh.ARRAY_COLOR] = colors
			var tagged := ArrayMesh.new(); tagged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); mesh = tagged
		"blade", "shard", "bolt", "leaf", "stone", "moth", "rune", "spark": mesh = _faceted_mesh(kind)
		"crystal_ribs": mesh = _crystal_rib_mesh()
		"clock_arc": mesh = _clock_arc_mesh()
		"contact_sigil_circle", "contact_sigil_star", "contact_sigil_clock", "contact_sigil_petals", "contact_sigil_fracture": mesh = _contact_sigil_mesh(kind.trim_prefix("contact_sigil_"))
		"selected_star": mesh = _star_mesh()
		"selected_moth": mesh = _moth_mesh()
		"selected_comet": mesh = _comet_mesh()
		"selected_lance":
			var lance := CylinderMesh.new(); lance.top_radius = 0.0; lance.bottom_radius = 0.22; lance.height = 1.5; lance.radial_segments = 6; mesh = lance
		"selected_disc":
			var disc := CylinderMesh.new(); disc.top_radius = 0.5; disc.bottom_radius = 0.5; disc.height = 0.09; disc.radial_segments = 16; mesh = disc
		"selected_ring":
			var ring := TorusMesh.new(); ring.outer_radius = 0.55; ring.inner_radius = 0.42; ring.rings = 24; ring.ring_segments = 5; mesh = ring
		"arc", "crescent", "ring", "sigil_circle", "sigil_star", "sigil_clock", "sigil_petals", "sigil_fracture": mesh = _arc_mesh(kind)
		"cube": mesh = BoxMesh.new()
		_:
			var orb := SphereMesh.new(); orb.radius = 0.5; orb.height = 1.0; orb.radial_segments = 8; orb.rings = 3; mesh = orb
	_meshes[kind] = mesh
	return mesh

func _faceted_mesh(kind: String) -> ArrayMesh:
	if kind == "leaf": return _leaf_mesh()
	var width := 0.16; var height := 0.06; var front := -0.72; var back := 0.32
	if kind == "leaf": width = 0.24; height = 0.035; front = -0.45; back = 0.35
	elif kind == "shard": width = 0.24; height = 0.14; front = -0.49; back = 0.38
	elif kind == "bolt": width = 0.075; height = 0.075; front = -0.9; back = 0.35
	elif kind == "stone": width = 0.42; height = 0.33; front = -0.38; back = 0.41
	elif kind == "moth": width = 0.65; height = 0.03; front = -0.42; back = 0.33
	elif kind == "rune": width = 0.22; height = 0.02; front = -0.2; back = 0.2
	elif kind == "spark": width = 0.065; height = 0.055; front = -0.5; back = 0.25
	var ring := [Vector3(-width, 0, 0), Vector3(0, height, 0), Vector3(width, 0, 0), Vector3(0, -height, 0)]
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for end in [Vector3(0, 0, front), Vector3(0, 0, back)]:
		for i in range(4):
			var a: Vector3 = ring[i]; var b: Vector3 = ring[(i + 1) % 4]
			var normal := (b - a).cross(end - a).normalized()
			for point in [a, b, end]: vertices.append(point); normals.append(normal)
			uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _triangle_mesh(vertices: PackedVector3Array, ribbon_uv := false) -> ArrayMesh:
	var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		for j in range(3): normals.append(normal)
		if ribbon_uv:
			uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)] if i % 6 == 0 else [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]))
		else: uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _star_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	for side in [-1.0, 1.0]:
		for i in range(10):
			var a := float(i) * TAU / 10.0; var b := float(i + 1) * TAU / 10.0
			var ra := 0.62 if i % 2 == 0 else 0.26; var rb := 0.62 if i % 2 == 1 else 0.26
			vertices.append_array(PackedVector3Array([Vector3(0, 0, side * 0.07), Vector3(sin(a) * ra, cos(a) * ra, 0), Vector3(sin(b) * rb, cos(b) * rb, 0)]))
	return _triangle_mesh(vertices)

func _moth_mesh() -> ArrayMesh:
	var outline := [Vector2(0, 0.42), Vector2(-0.11, 0.12), Vector2(-0.62, 0.38), Vector2(-0.7, -0.18), Vector2(-0.2, -0.35), Vector2(0, -0.18), Vector2(0.2, -0.35), Vector2(0.7, -0.18), Vector2(0.62, 0.38), Vector2(0.11, 0.12)]
	var vertices := PackedVector3Array()
	for i in range(outline.size()):
		var a: Vector2 = outline[i]; var b: Vector2 = outline[(i + 1) % outline.size()]
		vertices.append_array(PackedVector3Array([Vector3(0, 0, 0.045), Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0)]))
	return _triangle_mesh(vertices)

func _comet_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	for point in _mesh("orb").get_faces(): vertices.append(point * 0.76)
	var tail := CylinderMesh.new(); tail.top_radius = 0.0; tail.bottom_radius = 0.26; tail.height = 1.2; tail.radial_segments = 6
	for point in tail.get_faces(): vertices.append(Basis(Vector3.RIGHT, PI * 0.5) * point + Vector3(0, 0, 0.68))
	return _triangle_mesh(vertices)

func _leaf_mesh() -> ArrayMesh:

	var vertices := PackedVector3Array()
	var outline := [Vector3(0, 0, -0.52), Vector3(-0.14, 0, -0.26), Vector3(-0.24, -0.025, 0.03), Vector3(-0.12, 0, 0.28), Vector3(0, 0, 0.4), Vector3(0.12, 0, 0.28), Vector3(0.24, -0.025, 0.03), Vector3(0.14, 0, -0.26)]
	var center := Vector3(0, 0.065, -0.02)
	for i in range(outline.size()):
		vertices.append_array(PackedVector3Array([outline[i], outline[(i + 1) % outline.size()], center]))
	return _triangle_mesh(vertices)

func _crystal_rib_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array(); var faces := _mesh("shard").get_faces()
	for i in range(7):
		var offset := float(i) - 3.0
		var basis := Basis(Vector3.BACK, offset * 0.19) * Basis(Vector3.RIGHT, PI * 0.5)
		var size := Vector3(0.35, 0.65, 0.8 + sin(float(i + 1) * PI / 8.0) * 0.55)
		var origin := Vector3(offset * 0.1, -0.1, absf(offset) * 0.035)
		for face in faces: vertices.append(basis * (face * size) + origin)
		for rib in range(3):
			var rib_size := Vector3(0.53 - float(rib) * 0.08, 0.24, 0.13)
			var rib_origin := Vector3(0, 0, -0.1 - float(rib) * 0.15)
			for face in faces: vertices.append(basis * (face * rib_size + rib_origin) + origin)
	return _triangle_mesh(vertices)

func _mesh_stroke(vertices: PackedVector3Array, a: Vector3, b: Vector3, width: float) -> void:
	var side := (b - a).cross(Vector3.BACK).normalized() * width * 0.5
	vertices.append_array(PackedVector3Array([a - side, a + side, b - side, a + side, b + side, b - side]))

func _clock_arc_mesh() -> ArrayMesh:

	var vertices := PackedVector3Array()
	for i in range(30):
		if i % 10 >= 8: continue
		var a := float(i) * TAU / 30.0; var b := a + TAU / 30.0 * 0.73
		var outer := 0.51; var inner := 0.475
		vertices.append_array(PackedVector3Array([Vector3(cos(a) * inner, sin(a) * inner, 0), Vector3(cos(a) * outer, sin(a) * outer, 0), Vector3(cos(b) * inner, sin(b) * inner, 0), Vector3(cos(a) * outer, sin(a) * outer, 0), Vector3(cos(b) * outer, sin(b) * outer, 0), Vector3(cos(b) * inner, sin(b) * inner, 0)]))
		var radial := Vector3(cos(a), sin(a), 0)
		_mesh_stroke(vertices, radial * 0.44, radial * (0.37 if i % 5 == 0 else 0.4), 0.011 if i % 5 == 0 else 0.006)
	_mesh_stroke(vertices, Vector3.ZERO, Vector3(0.0, 0.31, 0), 0.018)
	_mesh_stroke(vertices, Vector3.ZERO, Vector3(-0.2, -0.1, 0), 0.025)
	return _triangle_mesh(vertices, true)

func _contact_sigil_mesh(sigil: String) -> ArrayMesh:
	var vertices := PackedVector3Array()


	for i in range(48):
		if sigil == "fracture" and i % 12 < 3: continue
		var a := float(i) * TAU / 48.0; var b := float(i + 1) * TAU / 48.0
		var ra := 0.48; var rb := 0.48
		if sigil == "star": ra += cos(a * 5.0) * 0.065; rb += cos(b * 5.0) * 0.065
		elif sigil == "petals": ra += cos(a * 6.0) * 0.042; rb += cos(b * 6.0) * 0.042
		_mesh_stroke(vertices, Vector3(cos(a) * ra, sin(a) * ra, 0), Vector3(cos(b) * rb, sin(b) * rb, 0), 0.008)
		if i % 4 != 0:
			_mesh_stroke(vertices, Vector3(cos(a) * 0.37, sin(a) * 0.37, 0), Vector3(cos(b) * 0.37, sin(b) * 0.37, 0), 0.004)
	for i in range(16):
		var a := float(i) * TAU / 16.0; var radial := Vector3(cos(a), sin(a), 0); var tangent := Vector3(-sin(a), cos(a), 0)
		var center := radial * 0.422
		_mesh_stroke(vertices, center - radial * 0.018, center + radial * 0.018, 0.005)
		_mesh_stroke(vertices, center - radial * 0.006, center + tangent * (0.016 if i % 2 == 0 else -0.016), 0.004)
		if i % 3 == 0: _mesh_stroke(vertices, center + tangent * 0.013, center + radial * 0.014 + tangent * 0.013, 0.004)
		if sigil == "clock": _mesh_stroke(vertices, radial * 0.29, radial * (0.34 if i % 4 == 0 else 0.32), 0.006)
	return _triangle_mesh(vertices, true)

func _orbit_mesh(spell: Dictionary) -> TorusMesh:

	var width_step := clampi(roundi(_number(spell, "trail_width", 1.0, 0.5, 2.0) * 10.0), 5, 20)
	var key := "projectile_orbit_%d" % width_step
	if not _meshes.has(key):
		var torus := TorusMesh.new(); torus.outer_radius = 1.0; torus.inner_radius = 1.0 - float(width_step) * 0.0045
		torus.rings = 24; torus.ring_segments = 5; _meshes[key] = torus
	return _meshes[key]

func _arc_mesh(kind: String) -> ArrayMesh:
	var vertices := PackedVector3Array(); var uvs := PackedVector2Array(); var indices := PackedInt32Array()
	var extent := TAU if kind == "ring" or kind.begins_with("sigil_") else 4.5 if kind == "arc" else 2.9
	for i in range(25):
		var progress := float(i) / 24.0; var angle := progress * extent
		var width := 0.018 if kind == "ring" or kind.begins_with("sigil_") else 0.045 * sin(progress * PI) + 0.005
		var shape_radius := 0.5
		if kind == "sigil_star": shape_radius += cos(angle * 5.0) * 0.1
		elif kind == "sigil_petals": shape_radius += cos(angle * 6.0) * 0.07
		elif kind == "sigil_clock": shape_radius += 0.035 if i % 2 == 0 else 0.0
		for radius in [shape_radius - width, shape_radius + width]: vertices.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0))
		uvs.append(Vector2(progress, 0)); uvs.append(Vector2(progress, 1))
		if i < 24 and (kind != "sigil_fracture" or i % 8 > 1):
			var j := i * 2; indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	if kind == "crescent":
		for layer in range(2):
			var offset := vertices.size()
			for i in range(25):
				var progress := float(i) / 24.0; var angle := progress * extent
				var radius := 0.54 + float(layer) * 0.045; var width := sin(progress * PI) * (0.006 if layer == 0 else 0.0025)
				for r in [radius - width, radius + width]: vertices.append(Vector3(cos(angle) * r, sin(angle) * r, float(layer) * 0.012))
				uvs.append(Vector2(progress, 0)); uvs.append(Vector2(progress, 1))
				if i < 24:
					var j := offset + i * 2; indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _piece(parent: Node3D, title: String, shape: String, material: Material, size := Vector3.ONE, point := Vector3.ZERO) -> MeshInstance3D:
	var piece := MeshInstance3D.new(); piece.name = title; piece.mesh = _mesh(shape)
	piece.material_override = material; piece.scale = size; piece.position = point
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)
	return piece

func _record(node: Node3D, spell: Dictionary, primary_shader: Shader) -> Dictionary:
	var materials := [_material(primary_shader, spell), _material(ENERGY, spell), _material(LENS if _family(spell) == "void" else HALO, spell)]
	return {"node": node, "spell": spell.duplicate(true), "family": _family(spell), "materials": materials, "age": 0.0, "parts": [], "trail": [], "light": true}

func _selected_shape(spell: Dictionary, fallback: String) -> String:
	match str(spell.get("projectile", "orb")):
		"cube": return "cube"
		"blade", "lance", "shard": return "blade"
		"disc", "ring": return "ring"
		"moth": return "moth"
		"star": return "rune"
	return fallback

func projectile_node(spell: Dictionary) -> Node3D:
	_prune_projectiles()
	var runtime := _runtime()
	if runtime == null or _projectiles.size() >= MAX_PROJECTILES: return null
	var node := Node3D.new(); node.name = "Spell_" + _family(spell); runtime.add_child(node)
	var data := _record(node, spell, FLAME if _family(spell) == "flame" else SURFACE)
	_projectiles[node.get_instance_id()] = data
	_build_family(data, false)
	_add_silhouette(data)
	_add_projectile_orbit(data)
	var halo := _piece(node, "ContainedHalo", "quad", data.materials[2], Vector3.ONE * _number(spell, "size", 0.18, 0.06, 0.75) * 8.0)
	data.halo = halo
	var trail := MeshInstance3D.new(); trail.name = "WorldTrail"; trail.mesh = ArrayMesh.new()
	trail.material_override = data.materials[1]; trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(trail); trail.top_level = true; trail.global_transform = Transform3D.IDENTITY; trail.visible = false
	data.trail_node = trail
	node.set_meta("trail_points", data.trail)
	_particles(node, data, MAX_PROJECTILE_MOTES)
	_animate(data, 0.0, 0.0, false)
	return node

func _build_family(data: Dictionary, impact: bool) -> void:
	var node: Node3D = data.node; var spell: Dictionary = data.spell
	var unit := 1.0 if impact else _number(spell, "size", 0.18, 0.06, 0.75) * 2.7
	var primary: Material = data.materials[0]; var energy: Material = data.materials[1]
	var family: String = data.family
	var count := 6 if impact else 3
	match family:
		"flame":
			for i in range(3 if not impact else 6):
				var card := _piece(node, "PhoenixBody" if i == 0 else "FlameTongue%d" % i, "quad", primary, Vector3(0.62, 1.05, 1) * unit)
				data.parts.append({"node": card, "role": "flame", "seed": float(i), "unit": unit})
			if not impact:
				data.plumage = _flame_instances(node, "PhoenixPlumage", primary, 16)
				var wake := _flame_instances(node, "PhoenixWake", primary, 8)
				wake.top_level = true; wake.global_transform = Transform3D.IDENTITY; data.wake = wake
		"frost":
			for i in range(5 if impact else 2):
				var blade := _piece(node, "CrystalBlade" if i == 0 else "IceFacet%d" % i, _selected_shape(spell, "blade"), primary, Vector3.ONE * unit)
				data.parts.append({"node": blade, "role": "ice_splinter" if impact else "blade", "seed": float(i), "unit": unit})

			var ribs := _piece(node, "RefractiveCrystalRibs", "crystal_ribs", primary, Vector3.ONE * unit)
			data.parts.append({"node": ribs, "role": "crystal_ribs", "seed": 0.0, "unit": unit})
		"storm":
			for i in range(6 if impact else 3):
				var strand := MeshInstance3D.new(); strand.name = "SerpentSpine" if i == 0 else "LightningFork%d" % i
				strand.mesh = ArrayMesh.new(); strand.material_override = energy; strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(strand)
				data.parts.append({"node": strand, "role": "lightning", "seed": float(i), "unit": unit})
		"grove":
			var vine := _piece(node, "LivingVine", "arc", energy, Vector3(0.8, 1.3, 1) * unit)
			data.parts.append({"node": vine, "role": "vine", "seed": 0.0, "unit": unit})
			for i in range(6 if impact else 4):
				var leaf := _piece(node, "VeinedLeaf%d" % i, _selected_shape(spell, "leaf"), primary, Vector3.ONE * unit * 0.72)
				data.parts.append({"node": leaf, "role": "leaf", "seed": float(i), "unit": unit})
		"light":
			var seal := _piece(node, "EngravedSun", "ring", energy, Vector3.ONE * unit * 1.4)
			data.parts.append({"node": seal, "role": "sun", "seed": 0.0, "unit": unit})
			for i in range(4):
				var ray := _piece(node, "PrismaticRay%d" % i, _selected_shape(spell, "blade"), primary, Vector3(0.3, 0.6, 1.5) * unit)
				data.parts.append({"node": ray, "role": "ray", "seed": float(i), "unit": unit})
		"shadow":
			for i in range(5 if impact else 3):
				var ink := _piece(node, "InkMoth" if i == 0 else "TornWisp%d" % i, _selected_shape(spell, "moth"), primary, Vector3.ONE * unit)
				data.parts.append({"node": ink, "role": "ink", "seed": float(i), "unit": unit})
		"water":
			for i in range(3):
				var sheet := _piece(node, "WaterSheet%d" % i, "crescent", energy, Vector3(1.1, 1.4, 1) * unit)
				data.parts.append({"node": sheet, "role": "water", "seed": float(i), "unit": unit})
			for i in range(3):
				var drop := _piece(node, "PressureDrop%d" % i, _selected_shape(spell, "orb"), primary, Vector3(0.17, 0.28, 0.17) * unit)
				data.parts.append({"node": drop, "role": "drop", "seed": float(i), "unit": unit})
		"wind":
			for i in range(4):
				var stream := _piece(node, "PressureCrescent%d" % i, "crescent", energy, Vector3.ONE * unit)
				data.parts.append({"node": stream, "role": "wind", "seed": float(i), "unit": unit})
		"earth":
			for i in range(6 if impact else 3):
				var rock := _piece(node, "MineralLance" if i == 0 else "LiftedFragment%d" % i, _selected_shape(spell, "stone"), primary, Vector3.ONE * unit * (1.0 if i == 0 else 0.45))
				data.parts.append({"node": rock, "role": "stone", "seed": float(i), "unit": unit})
			_piece(node, "MineralSeam", "arc", energy, Vector3.ONE * unit * 1.4)
		"metal":
			for i in range(6 if impact else 3):
				var blade := _piece(node, "ForgedBlade%d" % i, _selected_shape(spell, "blade"), primary, Vector3.ONE * unit)
				data.parts.append({"node": blade, "role": "metal", "seed": float(i), "unit": unit})
			_piece(node, "ResonantEdge", "arc", energy, Vector3.ONE * unit * 1.5)
		"void":
			var core := _piece(node, "DarkSeed", _selected_shape(spell, "orb"), primary, Vector3.ONE * unit * 0.6)
			data.parts.append({"node": core, "role": "void_core", "seed": 0.0, "unit": unit})
			for i in range(3):
				var orbit := _piece(node, "BrokenOrbit%d" % i, "arc", energy, Vector3.ONE * unit * (1.4 + i * 0.22))
				data.parts.append({"node": orbit, "role": "void", "seed": float(i), "unit": unit})
			for i in range(3):
				var debris := _piece(node, "OrbitingDebris%d" % i, "stone", primary, Vector3.ONE * unit * 0.11)
				data.parts.append({"node": debris, "role": "debris", "seed": float(i), "unit": unit})
		"time":
			for i in range(3):
				var arc := _piece(node, "FracturedClockArc%d" % i, "clock_arc", energy, Vector3.ONE * unit * (1.2 + i * 0.25))
				data.parts.append({"node": arc, "role": "clock", "seed": float(i), "unit": unit})
			for i in range(4):
				var tick_mark := _piece(node, "SuspendedSecond%d" % i, "rune", primary, Vector3(0.17, 0.12, 0.7) * unit)
				data.parts.append({"node": tick_mark, "role": "second", "seed": float(i), "unit": unit})

func _flame_instances(parent: Node3D, title: String, material: Material, amount: int) -> MultiMeshInstance3D:
	var cards := MultiMeshInstance3D.new(); cards.name = title
	cards.multimesh = MultiMesh.new(); cards.multimesh.transform_format = MultiMesh.TRANSFORM_3D; cards.multimesh.use_colors = true
	cards.multimesh.mesh = _mesh("quad"); cards.multimesh.instance_count = amount; cards.multimesh.visible_instance_count = 0
	cards.material_override = material; cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(cards)
	return cards

func _card_transform(container: Node3D, point: Vector3, size: Vector2, roll: float) -> Transform3D:
	var camera := _camera(); var basis := Basis.IDENTITY
	if camera != null:
		var direction := camera.global_position - container.to_global(point)
		if direction.length_squared() > 0.0001:
			var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.995 else Vector3.UP
			basis = container.global_basis.inverse() * Basis.looking_at(direction, up, true)
	basis = basis * Basis(Vector3.BACK, roll)
	return Transform3D(basis.scaled(Vector3(size.x, size.y, 1.0)), point)

func _animate_flame_instances(data: Dictionary, age: float) -> void:
	var spell: Dictionary = data.spell; var unit := _number(spell, "size", 0.18, 0.06, 0.75) * 2.7
	var cards: MultiMeshInstance3D = data.plumage; cards.multimesh.visible_instance_count = 16
	for i in range(16):
		var side := -1.0 if i < 8 else 1.0; var fraction := float(i % 8 + 1) / 8.0
		var flap := sin(age * 7.5 - fraction * 2.4) * 0.12
		var point := Vector3(side * fraction * 1.35, sin(fraction * PI) * (0.56 + flap) - fraction * 0.12, fraction * 0.39) * unit
		var size := Vector2(0.59 - fraction * 0.16, 0.76 + sin(fraction * PI) * 0.27) * unit
		cards.multimesh.set_instance_transform(i, _card_transform(cards, point, size, side * (-0.34 - fraction * 0.34) + flap))
		cards.multimesh.set_instance_color(i, Color(fposmod(float(i) * 0.618, 1.0), 1, 1, 0.85 - fraction * 0.22))
	var wake: MultiMeshInstance3D = data.wake; var history: Array = data.trail
	var amount := mini(history.size(), 4 if int(_settings().get("quality", 1)) == 0 else 8)
	if str(spell.get("trail", "ribbon")) == "none": amount = 0
	wake.multimesh.visible_instance_count = amount
	for i in range(amount):
		var fraction := float(i) / float(maxi(1, amount - 1)); var sample: Dictionary = history[roundi(fraction * float(history.size() - 1))]
		var alpha := pow(clampf(1.0 - (age - float(sample.age)) / _number(spell, "trail_length", 1.0, 0.08, 3.0), 0, 1), _number(spell, "trail_fade", 1.0, 0.1, 3.0))
		var size := Vector2(0.38 + fraction * 0.2, 0.66 + fraction * 0.22) * unit * _number(spell, "trail_width", 1.0, 0.5, 2.0)
		wake.multimesh.set_instance_transform(i, _card_transform(wake, sample.point, size, sin(age * 3 + float(i)) * 0.15))
		wake.multimesh.set_instance_color(i, Color(fposmod(float(i) * 0.381, 1), 1, 1, alpha * (0.24 + fraction * 0.35)))

func _add_silhouette(data: Dictionary) -> void:
	var style := str(data.spell.get("projectile", "orb")); var node: Node3D = data.node
	var unit := _number(data.spell, "size", 0.18, 0.06, 0.75) * 2.7
	var selected: MeshInstance3D
	if style in ["serpent", "ribbon"]:
		var strip := MeshInstance3D.new(); strip.name = "SelectedProjectile"
		strip.mesh = ArrayMesh.new(); strip.material_override = data.materials[1]; strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(strip)
		data.parts.append({"node": strip, "role": "silhouette_ribbon", "seed": 0.0 if style == "serpent" else 1.0, "unit": unit})
		selected = strip
	else:
		var mesh_name := "orb"; var dimensions := Vector3.ONE * unit; var base_rotation := Vector3.ZERO
		match style:
			"cube": mesh_name = "cube"; dimensions *= 0.75
			"orb": dimensions *= 0.65
			"blade", "shard", "bolt": mesh_name = style
			"star", "moth", "comet": mesh_name = "selected_" + style
			"lance", "disc", "ring": mesh_name = "selected_" + style; base_rotation.x = PI * 0.5
		selected = _piece(node, "SelectedProjectile", mesh_name, data.materials[1] if data.family == "flame" else data.materials[0], dimensions, Vector3(0, 0, -unit * 0.1))
		selected.rotation = base_rotation; data.selected_rotation = base_rotation
	data.selected = selected

func _add_projectile_orbit(data: Dictionary) -> void:
	if str(data.spell.get("trail", "ribbon")) != "orbit": return
	var orbit := MeshInstance3D.new(); orbit.name = "OrbitTrail"; orbit.mesh = _orbit_mesh(data.spell)
	orbit.material_override = data.materials[1]; orbit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orbit.scale = Vector3.ONE * _number(data.spell, "size", 0.18, 0.06, 0.75) * 1.7
	data.node.add_child(orbit)
	data.parts.append({"node": orbit, "role": "projectile_orbit", "seed": 0.0, "unit": 1.0})

func _particle_shape(spell: Dictionary) -> String:
	match str(spell.get("particles", "sparks")):
		"embers": return "blade"
		"petals": return "leaf"
		"runes", "stars": return "rune"
		"shards": return "stone"
	return "spark"

func _particles(node: Node3D, data: Dictionary, maximum: int) -> void:
	if _mote_material == null: _mote_material = ShaderMaterial.new(); _mote_material.shader = MOTE
	var spell: Dictionary = data.spell
	var residual := _number(spell, "residual_motes", 1.0, 0.0, 2.0) if data.has("life") else 1.0
	var amount := clampi(roundi(_number(spell, "intensity", 2, 1, 6) * 5.0 * _number(spell, "particle_density", 1.0, 0.0, 2.0) * residual), 0, maximum)
	var dust := MultiMeshInstance3D.new(); dust.name = "SpellParticles"
	dust.multimesh = MultiMesh.new(); dust.multimesh.transform_format = MultiMesh.TRANSFORM_3D; dust.multimesh.use_colors = true
	dust.multimesh.mesh = _mesh(_particle_shape(spell)); dust.multimesh.instance_count = amount
	dust.material_override = _mote_material; dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(dust); data.dust = dust

func animate_projectile(bolt: Dictionary, dt: float) -> void:
	var node: Variant = bolt.get("node")
	if not is_instance_valid(node) or not _projectiles.has(node.get_instance_id()): return
	var point: Variant = bolt.get("position", node.global_position)
	if not point is Vector3 or not point.is_finite(): return
	var age := _number(bolt, "age", 0.0, 0.0, 3600.0)
	node.global_position = point
	var data: Dictionary = _projectiles[node.get_instance_id()]
	data.age = age
	_record_trail(data, point, age)
	_animate(data, age, maxf(0.0, dt) if is_finite(dt) else 0.0, false)

func _record_trail(data: Dictionary, point: Vector3, age: float) -> void:
	var trail: Array = data.trail; var spell: Dictionary = data.spell
	var life := _number(spell, "trail_length", 1.0, 0.08, 3.0)
	while not trail.is_empty() and (trail.size() >= MAX_TRAIL_SAMPLES or age - float(trail[0].age) > life): trail.pop_front()
	if trail.is_empty() or (trail.back().point as Vector3).distance_squared_to(point) > 0.0004:
		trail.append({"point": point, "age": age})
	var mesh: MeshInstance3D = data.trail_node
	if str(spell.get("trail", "ribbon")) == "none" or trail.size() < 2:
		mesh.visible = false; return
	var points := PackedVector3Array(); var alpha := PackedFloat32Array()
	var fade := _number(spell, "trail_fade", 1.0, 0.1, 3.0)
	for sample in trail:
		points.append(sample.point); alpha.append(pow(clampf(1.0 - (age - float(sample.age)) / life, 0.0, 1.0), fade))
	_strip(mesh, points, _number(spell, "size", 0.18, 0.06, 0.75) * _number(spell, "trail_width", 1.0, 0.3, 2.0), alpha)

func _camera() -> Camera3D:
	var runtime := _runtime()
	return runtime.get_viewport().get_camera_3d() if runtime != null and runtime.is_inside_tree() else null

func _face(node: Node3D, roll := 0.0) -> void:
	var camera := _camera()
	if camera != null and node.global_position.distance_squared_to(camera.global_position) > 0.0001:
		var direction := (camera.global_position - node.global_position).normalized()
		var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.995 else Vector3.UP
		node.look_at(camera.global_position, up, true)
		node.rotate_object_local(Vector3.BACK, roll)
	else: node.rotation = Vector3(0, 0, roll)

func _strip(node: MeshInstance3D, points: PackedVector3Array, width: float, alpha := PackedFloat32Array()) -> void:
	_strip_paths(node, [points], [width], [alpha])

func _strip_paths(node: MeshInstance3D, paths: Array, widths: Array, alphas: Array = []) -> void:
	var mesh: ArrayMesh = node.mesh; mesh.clear_surfaces()
	if paths.is_empty(): node.visible = false; return
	var camera := _camera()
	var eye := node.to_local(camera.global_position) if camera != null else Vector3(0, 1, 8)
	var vertices := PackedVector3Array(); var uvs := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array()
	for path_index in range(paths.size()):
		var points: PackedVector3Array = paths[path_index]
		if points.size() < 2: continue
		var width: float = widths[path_index]; var offset := vertices.size()
		var alpha: PackedFloat32Array = alphas[path_index] if path_index < alphas.size() else PackedFloat32Array()
		for i in range(points.size()):
			var tangent := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
			if tangent.length_squared() < 1.0e-06: tangent = Vector3.FORWARD
			var side := tangent.normalized().cross((eye - points[i]).normalized()).normalized()
			if side.length_squared() < 0.5: side = Vector3.RIGHT
			var progress := float(i) / float(points.size() - 1)
			var taper := pow(maxf(0.02, sin(progress * PI)), 0.3)
			vertices.append(points[i] - side * width * 0.5 * taper); vertices.append(points[i] + side * width * 0.5 * taper)
			uvs.append(Vector2(progress, 0)); uvs.append(Vector2(progress, 1))
			var color := Color(1, 1, 1, alpha[i] if alpha.size() == points.size() else 1.0)
			colors.append(color); colors.append(color)
			if i < points.size() - 1:
				var j := offset + i * 2; indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	if vertices.is_empty(): node.visible = false; return
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); node.visible = true

func _lightning(piece: MeshInstance3D, seed: float, unit: float, clock: float, angle: float, impact: bool, progress: float) -> void:
	var low_flash := bool(_settings().get("low_flash", false))
	var step_clock := floorf(clock * (5.0 if low_flash else 12.0))
	var end := Vector3(cos(angle), 0.2 + sin(seed * 1.7) * 0.45, sin(angle)) * (0.35 + progress * 1.45) if impact else Vector3((seed - 1.0) * 0.53, cos(seed * 2.4) * 0.24, -0.95)
	var start := Vector3(0, 0.05, 0) if impact else Vector3((seed - 1.0) * 0.12, 0, 0.42)
	var points := PackedVector3Array()
	for i in range(13):
		var fraction := float(i) / 12.0
		var point := start.lerp(end, fraction)
		var jag := Vector3(sin(float(i) * 23.7 + step_clock * 2.9 + seed) * 0.16, sin(float(i) * 13.4 - step_clock * 3.3 + seed) * 0.12, 0)
		point += jag * sin(fraction * PI); points.append(point * unit)
	# Bolder strokes so the cel-shaded bolt (ink edge + bright core) stays readable on phones.
	var paths: Array = [points]; var widths: Array = [unit * (0.095 if seed == 0 else 0.045)]


	for branch in range(2 if seed < 1.0 else 1):
		var root_index := 4 + branch * 3; var branch_start := points[root_index]
		var side := -1.0 if fmod(seed + float(branch), 2.0) < 1.0 else 1.0
		var branch_end := branch_start + Vector3(side * (0.29 + float(branch) * 0.11), 0.19 + sin(seed) * 0.12, -0.3) * unit
		var fork := PackedVector3Array()
		for i in range(6):
			var fraction := float(i) / 5.0
			var point := branch_start.lerp(branch_end, fraction)
			point += Vector3(sin(float(i) * 17.1 + step_clock + seed), cos(float(i) * 11.7 + step_clock), 0) * sin(fraction * PI) * unit * 0.055
			fork.append(point)
		paths.append(fork); widths.append(unit * 0.026)
	_strip_paths(piece, paths, widths)
	piece.set_meta("lightning_paths", paths.size())
	piece.set_meta("lightning_step", step_clock)

func _time_motion(clock: float) -> float:

	var cycle := floorf(clock * 1.5); var fraction := fposmod(clock * 1.5, 1.0)
	return (cycle + smoothstep(0.46, 0.92, fraction)) / 1.5

func _animate(data: Dictionary, age: float, _dt: float, impact: bool) -> void:
	var node: Node3D = data.node; var spell: Dictionary = data.spell
	var progress: float = clampf(age / float(data.get("life", 1.0)), 0.0, 1.0) if impact else 0.0
	var envelope := pow(1.0 - progress, 0.5) if impact else 1.0
	var contact_flash := 1.0 - smoothstep(0.025, 0.2, age) if impact else 0.0
	for index in range(data.materials.size()):
		var material: ShaderMaterial = data.materials[index]
		var layer_envelope := envelope
		if impact and data.family != "flame":
			if index == 1: layer_envelope *= 0.57 + contact_flash * 0.43
			if index == 2 and data.family != "void": layer_envelope *= contact_flash
		_set_material_clock(material, spell, age, layer_envelope)
		if data.family != "flame":
			material.set_shader_parameter("contact_flash", contact_flash)
			material.set_shader_parameter("is_contact", 1.0 if impact else 0.0)
	var spin := _number(spell, "spin", 1.0, -3.0, 3.0)
	var clock := age * _number(spell, "pulse_speed", 1.0, 0.25, 3.0)
	for part in data.parts:
		var piece: MeshInstance3D = part.node; var seed: float = part.seed; var unit: float = part.unit
		var angle := seed * 2.39996 + clock * 0.7 * spin
		match str(part.role):
			"flame":
				piece.position = Vector3(sin(seed * 2.4) * 0.1, cos(seed * 2.1) * 0.1, seed * 0.075) * unit
				if impact: piece.position = Vector3(cos(angle) * (0.15 + progress * 1.0), progress * 0.6, sin(angle) * (0.15 + progress * 0.7))
				_face(piece, sin(clock * 3.0 + seed) * 0.12)
			"wing":
				var fraction := (seed + 1.0) / 3.0; var side: float = part.side
				var flap := sin(clock * 7.5 - fraction * 2.4) * 0.1
				piece.position = Vector3(side * fraction * 1.3, sin(fraction * PI) * (0.52 + flap) - fraction * 0.1, fraction * 0.32) * unit
				piece.scale = Vector3(0.57 - fraction * 0.12, 0.68 + sin(fraction * PI) * 0.25, 1) * unit
				_face(piece, side * (-0.34 - fraction * 0.34) + flap)
			"blade": piece.position = Vector3((seed - 0.5) * 0.18, sin(seed * 2.1) * 0.12, seed * 0.12) * unit; piece.rotation = Vector3(0, seed * 0.13, age * spin * 0.6 + seed * 0.3)
			"crystal_ribs":
				piece.position = Vector3(0, 0.02 + progress * 0.28, 0) * unit
				piece.rotation = Vector3(sin(clock * 0.7) * 0.13, clock * spin * 0.27, sin(clock * 1.2) * 0.06)
				piece.scale = Vector3.ONE * unit * (1.0 + progress * 0.2)
			"ice_splinter":
				var distance := 0.15 + progress * (1.15 + seed * 0.12)
				piece.position = Vector3(cos(angle) * distance, 0.12 + absf(sin(seed * 1.4)) * progress * 0.9, sin(angle) * distance) * unit
				piece.scale = Vector3(0.25, 0.65, 0.85) * unit * (1.0 - progress * 0.3)
				piece.rotation = Vector3(seed * 0.7, age * spin * 1.6, angle)
			"splinter": piece.position = Vector3(cos(angle), sin(seed * 1.4) * 0.6, sin(angle)) * progress * 1.6; piece.rotation = Vector3(seed, age * spin, angle)
			"lightning": _lightning(piece, seed, unit, clock, angle, impact, progress)
			"vine": piece.rotation = Vector3(0.3, sin(clock) * 0.3, age * spin * 0.5)
			"leaf": piece.position = Vector3(cos(angle) * 0.47, sin(angle) * 0.43, 0.06 * seed) * unit; piece.rotation = Vector3(0.85, sin(clock + seed) * 0.35, angle)
			"sun": piece.rotation = Vector3(0, 0, age * spin * 0.4)
			"ray": piece.position = Vector3(cos(angle) * 0.44, sin(angle) * 0.44, 0) * unit * (1.0 + progress); piece.rotation = (Basis(Vector3.BACK, angle - PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)).get_euler()
			"ink": piece.position = Vector3(sin(angle) * 0.25, cos(angle) * 0.2, seed * 0.25) * unit; piece.rotation = Vector3(sin(clock * 2.0 + seed) * 0.5, age * spin * 0.3, seed * 0.9)
			"water": piece.rotation = Vector3(0.4 * seed, seed * 0.6 + age * spin * 0.7, seed * 1.9); piece.position.z = (seed - 1.0) * unit * 0.24
			"drop": piece.position = Vector3(cos(angle) * 0.35, sin(angle) * 0.35, 0.2 + seed * 0.22) * unit * (1 + progress)
			"wind": piece.rotation = Vector3(0.25 * seed, seed * 0.7 + age * spin, seed * 1.8); piece.scale = Vector3.ONE * unit * (0.9 + seed * 0.17 + progress * 0.6)
			"stone": piece.position = Vector3(cos(angle) * 0.4, sin(angle) * 0.2, seed * 0.18) * unit * (0.4 + progress * 1.8 if impact else 1.0); piece.rotation = Vector3(age * spin * 0.7 + seed, seed * 0.7, seed)
			"metal": piece.position = Vector3(cos(angle) * 0.27, sin(angle) * 0.27, seed * 0.15) * unit * (1 + progress); piece.rotation = Vector3(0.0, seed * 0.2, angle)
			"void_core": piece.scale = Vector3.ONE * unit * (0.34 + contact_flash * 0.16 if impact else 0.6); piece.rotation = Vector3(clock * 0.13, clock * 0.27, 0)
			"void":
				piece.rotation = Vector3(0.3 + seed * 0.55 + sin(clock * 0.43 + seed) * 0.11, clock * spin * 0.4 + seed * 0.6, seed * 0.5)
				piece.scale = Vector3(1.0 + sin(clock * 0.8 + seed) * 0.055, 0.82 + seed * 0.06, 1) * unit * (1.4 + seed * 0.22)
			"debris":
				var fall := fposmod(clock * 0.29 + seed * 0.31, 1.0); var radius := 1.12 - fall * 0.79
				var orbit_angle := angle + fall * fall * 3.0
				piece.position = Vector3(cos(orbit_angle) * radius, sin(orbit_angle * 1.4) * radius * 0.4, sin(orbit_angle) * radius * 0.65) * unit
				piece.scale = Vector3.ONE * unit * (0.095 - fall * 0.06); piece.rotation = Vector3(age + seed, age * 0.7, seed)
			"clock":
				var movement := _time_motion(clock + seed * 0.06)
				piece.rotation = Vector3(0.16 + seed * 0.4, seed * 0.22 + sin(movement * 0.25) * 0.06, seed * 1.7 + movement * 0.32 * spin)
				piece.position = Vector3(sin(seed * 2.4) * progress * 0.13, 0.1 + progress * 0.15, cos(seed * 2.4) * progress * 0.13) * unit if impact else Vector3.ZERO
			"second":
				var movement := _time_motion(clock + seed * 0.06); var clock_angle := seed * PI * 0.5 + movement * 0.19 * spin
				piece.position = Vector3(cos(clock_angle) * (0.64 + progress * 0.28), sin(clock_angle) * (0.64 + progress * 0.28), sin(movement + seed) * 0.12) * unit
				piece.rotation = Vector3(sin(movement + seed) * 0.16, movement * 0.13, clock_angle)

			"silhouette_ribbon":
				var points := PackedVector3Array()
				for i in range(16):
					var fraction := float(i) / 15.0
					points.append(Vector3(sin(fraction * TAU * (1.4 if seed == 0 else 0.65) - clock * 3) * (0.25 if seed == 0 else 0.14), sin(fraction * TAU * 2 - clock * 2) * 0.13, 0.6 - fraction * 1.6) * unit)
				_strip(piece, points, unit * (0.13 if seed == 0 else 0.24))
			"projectile_orbit": piece.rotation = Vector3(0.65, age * spin * 0.5, 0.2 + age * spin * 0.8)
			"ripple": piece.rotation.x = -PI * 0.5; piece.scale = Vector3.ONE * (0.6 + progress * (1.2 + seed * 0.35)); piece.position.y = 0.015 + seed * 0.025
			"mist": piece.position = Vector3(sin(seed * 2.4) * 0.4, 0.1 + progress * (0.6 + seed * 0.25), cos(seed * 2.4) * 0.3); _face(piece)
			"contact_star":
				var pop := clampf(age / 0.16, 0.0, 1.0)
				piece.visible = pop < 1.0
				if piece.visible:
					piece.scale = Vector3.ONE * lerpf(2.6, 0.9, pop * pop)
					piece.position = Vector3(0, 0.25, 0)
					_face(piece, pop * 0.6)
			"shockwave":
				var wave := clampf(age / 0.26, 0.0, 1.0)
				piece.visible = wave < 1.0
				if piece.visible:
					piece.scale = Vector3.ONE * (0.6 + (1.0 - pow(1.0 - wave, 3.0)) * 3.6)
					piece.position = Vector3(0, 0.2, 0)
					_face(piece)
	if data.has("halo"): _face(data.halo)
	if data.has("selected"): data.selected.rotation = data.get("selected_rotation", Vector3.ZERO) + Vector3(0, 0, age * spin * 2.0)
	if data.has("plumage"): _animate_flame_instances(data, clock)
	if data.has("smoke"): _animate_smoke(data, age)
	if data.has("dust"): _animate_motes(data, age, progress, envelope, impact)

func _animate_motes(data: Dictionary, age: float, progress: float, envelope: float, impact: bool) -> void:
	var spell: Dictionary = data.spell; var dust: MultiMeshInstance3D = data.dust
	var quality := clampi(int(_settings().get("quality", 1)), 0, 2)
	var amount := dust.multimesh.instance_count
	dust.multimesh.visible_instance_count = mini(amount, maxi(3, roundi(float(amount) * (0.5 if quality == 0 else 0.75 if quality == 1 else 1.0))))
	var unit := 0.65 if impact else _number(spell, "size", 0.18, 0.06, 0.75) * 2.5
	var drift := _number(spell, "particle_drift", 1.0, 0.0, 3.0)
	var spin := _number(spell, "spin", 1.0, -3.0, 3.0)
	var base := _color(spell, "rim_color", _color(spell, "accent", Color("ffedbd")))
	for i in range(amount):
		var seed := float(i) * 2.39996; var fraction := float(i) / float(amount); var angle := seed + age * 0.7 * spin
		var point := Vector3(cos(angle) * (0.2 + fraction * 0.35), sin(angle) * (0.2 + fraction * 0.3), fraction * 0.8) * unit
		match str(data.family):
			"flame": point = Vector3(sin(seed) * 0.45, fposmod(age * 0.6 * drift + fraction, 1.0) * 0.8, fraction * 1.1) * unit
			"frost": point = Vector3(cos(seed + age * 0.12) * 0.68, (fposmod(fraction - age * 0.17 * drift, 1.0) - 0.4) * 0.95, 0.15 + fraction * 1.15) * unit
			"storm": point = Vector3(sin(seed + floorf(age * 10.0)) * 0.3, cos(seed * 1.7) * 0.25, fraction * 1.2) * unit
			"void":
				var fall := fposmod(fraction + age * 0.26 * drift, 1.0); var radius := 1.05 - fall * 0.85
				point = Vector3(cos(angle + fall * 2.8) * radius, sin(seed * 2.1) * radius * 0.55, sin(angle + fall * 2.8) * radius * 0.65) * unit
			"time":
				var movement := _time_motion(age) * drift
				point = Vector3(cos(seed + movement * 0.14) * 0.85, sin(seed + movement * 0.14) * 0.85, sin(seed * 1.7 + movement * 0.3) * 0.14) * unit
			"water": point = Vector3(cos(seed) * 0.34, sin(seed) * 0.24 - fraction * fraction * 0.16, fraction * 1.4) * unit
			"wind": point = Vector3(cos(angle * 1.5) * (0.35 + fraction * 0.3), sin(angle * 1.5) * (0.35 + fraction * 0.3), fraction * 1.2) * unit
			"earth": point.y = -unit * 0.35 + fposmod(fraction + age * 0.1 * drift, 1) * unit * 0.3
			"grove": point.y += sin(age * 0.7 * drift + seed) * unit * 0.2
			_: point.y += sin(age * drift + seed) * unit * 0.14
		if impact: point = point.normalized() * (0.15 + progress * (0.8 + fraction) * 1.35); point.y += progress * (1 - progress) * drift * 0.65
		if impact and str(data.family) in ["frost", "water", "earth", "metal"]: point.y = absf(point.y)
		var size := (0.03 + float(i % 3) * 0.01) * _number(spell, "particle_size", 1.0, 0.3, 2.0) * (0.7 if not impact else 1.0 - progress * 0.6)
		var color := base.lerp(_color(spell, "trail_color", base), fraction * 0.5); color.a = envelope * (0.45 + fraction * 0.35)
		if impact and str(data.family) == "flame" and progress > 0.62: color = Color(0.12, 0.08, 0.06, color.a * 0.6)
		var dimensions := Vector3.ONE * size
		if str(data.family) == "frost":
			color = color.lerp(_color(spell, "core_color", Color("eaffff")), 0.56); color.a *= 0.7
			dimensions *= Vector3(0.6, 0.6, 1.9) if i % 4 == 0 else Vector3(0.65, 0.65, 0.85)
		if str(data.family) == "storm": dimensions *= Vector3(0.45, 0.45, 1.7)
		if str(data.family) == "water": dimensions *= Vector3(0.65, 1.7, 0.65)
		if str(data.family) == "wind": color.a *= 0.62; dimensions *= Vector3(0.35, 0.35, 1.6)
		dust.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, angle).scaled(dimensions), point))
		dust.multimesh.set_instance_color(i, color)

func _ornament(node: Node3D, data: Dictionary) -> void:
	var trail := str(data.spell.get("trail", "ribbon"))
	if trail == "ribbon":
		var ribbon := _piece(node, "RibbonTrail", "arc", data.materials[1], Vector3(1.5, 0.85, 1))
		ribbon.rotation = Vector3(0.5, 0.2, 0.4)
	elif trail == "orbit":
		for i in range(3):
			var orbit := _piece(node, "OrbitTrail%d" % i, "arc", data.materials[1], Vector3.ONE * (1.0 + i * 0.2))
			orbit.rotation = Vector3(0.6 + i * 0.45, i * 0.6, i * 0.8)

func glyph(point: Vector3, spell: Dictionary, kind: String, life: float, radius: float) -> Node3D:
	var runtime := _runtime()
	if runtime == null or not point.is_finite() or not is_finite(life) or life <= 0 or not is_finite(radius): return null
	while visuals.size() >= MAX_TRANSIENTS: _retire_transient(0)
	var node := Node3D.new(); node.name = "SpellGlyph_" + kind; runtime.add_child(node); node.global_position = point
	var normal: Variant = spell.get("_surface_normal", Vector3.UP)
	if kind in ["impact", "frost", "shadow"] and normal is Vector3 and normal.is_finite() and normal.length_squared() > 0.001:
		node.quaternion = Quaternion(Vector3.UP, normal.normalized())
	var is_flame := _family(spell) == "flame"
	var data := _record(node, spell, FLAME if is_flame else SURFACE)
	data.kind = kind; data.life = clampf(life, 0.04, 18.0); data.radius = clampf(radius, 0.04, 8.0)
	data.radius *= _number(spell, "cast_scale" if kind in ["cast", "anticipation"] else "impact_scale", 1.0, 0.25, 3.0)
	if not is_flame:
		var sigil := str(spell.get("sigil", "circle"))
		if not sigil in ["circle", "star", "clock", "petals", "fracture"]: sigil = "circle"


		var seal := _piece(node, "ContactSigil", "contact_sigil_" + sigil, data.materials[1], Vector3.ONE * 2.1)
		seal.rotation.x = -PI * 0.5
		data.seal = seal
		_build_family(data, true)
	else:
		_build_family(data, true)
		var sigil := str(spell.get("sigil", "circle"))
		if not sigil in ["circle", "star", "clock", "petals", "fracture"]: sigil = "circle"
		var seal := _piece(node, "ContactSigil", "sigil_" + sigil, data.materials[1], Vector3.ONE * 1.9)
		seal.rotation.x = -PI * 0.5
	data.halo = _piece(node, "ImpactHalo", "quad", data.materials[2], Vector3.ONE * 3.0)
	if kind in ["impact", "burst", "beam_end"] and data.family != "void":
		# Punch of contact: a white-hot star and a ring that races outward, both gone in ~0.25 s.
		var star := _piece(node, "ContactStar", "star_card", data.materials[2], Vector3.ONE * 2.2)
		data.parts.append({"node": star, "role": "contact_star", "seed": 0.0, "unit": 1.0})
		var shock := _piece(node, "Shockwave", "shock_card", data.materials[2], Vector3.ONE)
		data.parts.append({"node": shock, "role": "shockwave", "seed": 0.0, "unit": 1.0})
	if is_flame and not kind in ["cast", "anticipation"]: _contact_smoke(node, data)
	if not kind in ["cast", "anticipation"]: _impact_accent(node, data)
	_ornament(node, data)
	_particles(node, data, MAX_TRANSIENT_MOTES)
	node.scale = Vector3.ONE * float(data.radius)
	if kind == "ward":
		var game: Variant = runtime.get("game")
		if is_instance_valid(game) and is_instance_valid(game.get("player")): data.player_offset = point - game.player.global_position
	visuals.append(data); _animate(data, 0, 0, true)
	return node

func _contact_smoke(node: Node3D, data: Dictionary) -> void:
	if _smoke_material == null: _smoke_material = ShaderMaterial.new(); _smoke_material.shader = SMOKE
	var smoke := MultiMeshInstance3D.new(); smoke.name = "ResidualSmoke"
	smoke.multimesh = MultiMesh.new(); smoke.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	smoke.multimesh.use_colors = true; smoke.multimesh.use_custom_data = true; smoke.multimesh.mesh = _mesh("quad"); smoke.multimesh.instance_count = 4
	smoke.material_override = _smoke_material; smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(smoke); smoke.top_level = true; smoke.global_transform = Transform3D.IDENTITY; data.smoke = smoke

func _animate_smoke(data: Dictionary, age: float) -> void:
	var smoke: MultiMeshInstance3D = data.smoke; var node: Node3D = data.node; var radius: float = data.radius
	var amount := 2 if int(_settings().get("quality", 1)) == 0 else 4
	smoke.multimesh.visible_instance_count = amount
	for i in range(amount):
		var fraction := clampf((age - 0.12 - float(i) * 0.035) / maxf(0.1, float(data.life) - 0.12), 0, 1)
		var alpha := smoothstep(0, 0.18, fraction) * (1.0 - smoothstep(0.6, 1.0, fraction)) * 0.24 * _number(data.spell, "opacity", 1, 0.25, 1)
		var point := node.global_position + Vector3(sin(float(i) * 2.399) * (0.2 + fraction * 0.6), 0.22 + fraction * 1.25, cos(float(i) * 2.399) * 0.3) * radius
		smoke.multimesh.set_instance_transform(i, _card_transform(smoke, point, Vector2.ONE * radius * (0.9 + fraction * 1.35), sin(float(i)) * 0.3))
		smoke.multimesh.set_instance_color(i, Color(0.12, 0.105, 0.095, alpha))
		smoke.multimesh.set_instance_custom_data(i, Color(age, float(i) * 1.381, 0, 0))

func _impact_accent(node: Node3D, data: Dictionary) -> void:
	var accent := str(data.spell.get("impact_accent", "bloom"))
	if accent == "bloom": return
	for i in range(2):
		var title := "AccentShards" if accent == "shards" else "AccentRings" if accent == "rings" else "AccentSparks" if accent == "sparks" else "AccentMist"
		var shape := "blade" if accent == "shards" else "ring" if accent == "rings" else "spark" if accent == "sparks" else "quad"
		var piece := _piece(node, title + str(i), shape, data.materials[2] if accent == "mist" else data.materials[1], Vector3.ONE * (0.7 if accent == "shards" else 1.0))
		data.parts.append({"node": piece, "role": "ripple" if accent == "rings" else "mist" if accent == "mist" else "splinter", "seed": float(i) + 0.7, "unit": 1.0})

func beam(start: Vector3, end: Vector3, spell: Dictionary, life: float, width: float) -> Node3D:
	var runtime := _runtime()
	if runtime == null or not start.is_finite() or not end.is_finite() or start.distance_squared_to(end) < 0.0001 or not is_finite(life) or life <= 0: return null
	while visuals.size() >= MAX_TRANSIENTS: _retire_transient(0)
	var node := Node3D.new(); node.name = "SpellBeam"; runtime.add_child(node)
	node.global_transform = Transform3D(Basis.IDENTITY, start)
	var data := _record(node, spell, SURFACE); data.kind = "beam"; data.life = clampf(life, 0.04, 4.0)
	data.start = start; data.end = end; data.width = clampf(width * 1.4, 0.06, 1.0) * _number(spell, "trail_width", 1.0, 0.3, 2.0)
	data.light = false
	for i in range(3):
		var strip := MeshInstance3D.new(); strip.name = "BeamCore" if i == 0 else "BeamFilament%d" % i
		strip.mesh = ArrayMesh.new(); strip.material_override = data.materials[1]; strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(strip); data.parts.append({"node": strip, "seed": float(i)})
	_ornament(node, data); visuals.append(data); _animate_beam(data)
	return node

func _animate_beam(data: Dictionary) -> void:
	var node: Node3D = data.node; var age: float = data.age
	var progress := clampf(age / float(data.life), 0, 1)
	for material in data.materials: _set_material_clock(material, data.spell, age, 1.0 - progress)
	var delta: Vector3 = data.end - data.start; var axis := delta.normalized()
	var right := axis.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.5: right = Vector3.RIGHT
	for part in data.parts:
		var points := PackedVector3Array(); var seed: float = part.seed
		var storm := str(data.family) == "storm"; var step_clock := floorf(age * (5.0 if bool(_settings().get("low_flash", false)) else 12.0))
		for i in range(20):
			var fraction := float(i) / 19.0; var point := delta * fraction
			if storm:
				point += right * sin(float(i) * 23.1 + step_clock * 2.7 + seed) * float(data.width) * (1.15 if seed == 0 else 1.8) * sin(fraction * PI)
				point += axis.cross(right) * sin(float(i) * 13.7 - step_clock * 1.9 + seed) * float(data.width) * 0.7 * sin(fraction * PI)
			elif seed > 0:
				var wave := sin(fraction * TAU * 2.0 - age * 3.0 + seed * PI) * float(data.width) * 0.8
				point += right * wave * sin(fraction * PI)
			points.append(point)

		points[0] = Vector3.ZERO; points[points.size() - 1] = delta
		var width := float(data.width) * (0.95 if seed == 0 else 0.32) * (1.0 - progress * 0.5)
		if storm:
			var fork := PackedVector3Array(); var branch_start := points[8 + int(seed)]
			for i in range(6):
				var fraction := float(i) / 5.0
				fork.append(branch_start.lerp(delta * 0.78 + right * (seed - 1.0) * float(data.width) * 3.5, fraction) + right * sin(float(i) * 11.7 + step_clock) * float(data.width) * 0.5 * sin(fraction * PI))
			_strip_paths(part.node, [points, fork], [width, width * 0.36])
		else: _strip(part.node, points, width)
		part.node.set_meta("supplied_endpoints", PackedVector3Array([data.start, data.end]))

func tick(dt: float) -> void:
	if not is_finite(dt) or dt <= 0: return
	_prune_projectiles()
	for i in range(visuals.size() - 1, -1, -1):
		var data: Dictionary = visuals[i]; data.age += dt
		if not is_instance_valid(data.node) or float(data.age) >= float(data.life): _retire_transient(i); continue
		if data.kind == "ward":
			var runtime := _runtime(); var remaining: Variant = runtime.get("ward_remaining") if runtime != null else null
			if (remaining is float or remaining is int) and float(remaining) <= 0: _retire_transient(i); continue
		if data.kind == "beam": _animate_beam(data); continue
		var node: Node3D = data.node; var progress := float(data.age) / float(data.life)
		var scale_value := float(data.radius) * (0.48 + sin(minf(1.0, progress * 1.7) * PI * 0.5) * 0.65) * pow(1.0 - progress, 0.18)
		if data.kind == "ward":
			scale_value = float(data.radius) * (1.0 + sin(float(data.age) * 2.0) * 0.025)
			var runtime := _runtime(); var game: Variant = runtime.get("game") if runtime != null else null
			if data.has("player_offset") and is_instance_valid(game) and is_instance_valid(game.get("player")): node.global_position = game.player.global_position + data.player_offset
		node.scale = Vector3.ONE * maxf(0.001, scale_value)
		_animate(data, float(data.age), dt, true)
	_update_lights()

func _prune_projectiles() -> void:
	for id in _projectiles.keys():
		if not is_instance_valid(_projectiles[id].node): _projectiles.erase(id)

func _retire_transient(index: int) -> void:
	var data: Dictionary = visuals[index]; visuals.remove_at(index)
	var node: Variant = data.node
	if is_instance_valid(node): node.free()

func _view_origin() -> Vector3:
	var camera := _camera()
	if camera != null: return camera.global_position
	var runtime := _runtime(); var game: Variant = runtime.get("game") if runtime != null else null
	if is_instance_valid(game) and is_instance_valid(game.get("player")): return game.player.global_position
	return Vector3.ZERO

func _update_lights() -> void:
	var runtime := _runtime()
	if runtime == null: return
	for i in range(_lights.size() - 1, -1, -1):
		if not is_instance_valid(_lights[i]): _lights.remove_at(i)
	var candidates: Array = []; var eye := _view_origin()
	var records: Array = _projectiles.values(); records.append_array(visuals)
	for data in records:
		var node: Variant = data.node
		if not is_instance_valid(node) or not bool(data.light): continue
		candidates.append({"point": node.global_position, "spell": data.spell, "distance": eye.distance_squared_to(node.global_position), "id": node.get_instance_id()})
	candidates.sort_custom(func (a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance if not is_equal_approx(a.distance, b.distance) else a.id < b.id)
	if not candidates.is_empty():
		while _lights.size() < 2:
			var light := OmniLight3D.new(); light.name = "SharedSpellLight%d" % _lights.size(); light.shadow_enabled = false
			light.omni_range = 3.8; light.light_energy = 0; runtime.add_child(light); _lights.append(light)
	for i in range(_lights.size()):
		var light := _lights[i]
		if not is_instance_valid(light): continue
		light.visible = i < candidates.size()
		if not light.visible: light.light_energy = 0; continue
		var selected: Dictionary = candidates[i]; light.global_position = selected.point
		light.light_color = _color(selected.spell, "color", Color("a764ed"))
		light.light_energy = 0.24 if bool(_settings().get("low_flash", false)) else 0.72
		light.shadow_enabled = false

func clear() -> void:
	for data in _projectiles.values():
		var node: Variant = data.node
		if is_instance_valid(node): node.free()
	_projectiles.clear()
	while not visuals.is_empty(): _retire_transient(visuals.size() - 1)
	for light in _lights:
		if is_instance_valid(light): light.free()
	_lights.clear(); _meshes.clear(); _mote_material = null; _smoke_material = null

func stats() -> Dictionary:
	_prune_projectiles()
	var result := {"projectile_roots": _projectiles.size(), "transient_roots": visuals.size(), "nodes": 0, "materials": 0, "particles": 0, "trail_samples": 0, "lights_enabled": 0, "mesh_cache": _meshes.size(), "material_cache": 0}
	var records: Array = _projectiles.values(); records.append_array(visuals)
	for data in records:
		var node: Variant = data.node
		if not is_instance_valid(node): continue
		result.nodes += 1 + node.find_children("*", "Node", true, false).size(); result.materials += data.materials.size()
		result.trail_samples += data.trail.size()
		if data.has("dust"): result.particles += data.dust.multimesh.instance_count
	if _mote_material != null: result.materials += 1
	if _smoke_material != null: result.materials += 1
	for light in _lights:
		if not is_instance_valid(light): continue
		result.nodes += 1
		if light.visible and light.light_energy > 0: result.lights_enabled += 1
	return result
