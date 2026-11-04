extends RefCounted
const B = preload("res://scripts/build.gd")
static var palette_cache: Dictionary = {}
static func palette_mesh(source: Mesh, d: Dictionary) -> Mesh:
	var bare_head = d.race == "smallfolk" or d.id in ["ironbell_smith", "brindlewick_merchant", "brindlewick_baker"]
	var key = str(source.get_instance_id()) + str(d.skin) + str(d.coat) + str(bare_head)
	if palette_cache.has(key): return palette_cache[key]
	var mesh = source.duplicate()
	if bare_head:
		mesh = _remove_hat(source, d.head_level)
	for surface in range(mesh.get_surface_count()):
		var old = source.surface_get_material(surface)
		var texture = old.albedo_texture if old is StandardMaterial3D else old.get_shader_parameter("albedo_texture")
		var material = StandardMaterial3D.new(); material.roughness = 0.88
		if texture != null:
			var image = texture.get_image(); image.decompress(); image.convert(Image.FORMAT_RGBA8)
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var c = image.get_pixel(x, y)


					if c.is_equal_approx(Color8(255, 211, 186)): image.set_pixel(x, y, d.skin)
					elif c.is_equal_approx(Color8(255, 235, 211)): image.set_pixel(x, y, Color(d.skin).lightened(0.13))
					elif c.is_equal_approx(Color8(77, 107, 78)): image.set_pixel(x, y, d.coat)
					elif c.is_equal_approx(Color8(151, 75, 66)): image.set_pixel(x, y, Color(d.coat).darkened(0.15))
			material.albedo_texture = ImageTexture.create_from_image(image)
		mesh.surface_set_material(surface, material)
	for surface in range(mesh.get_surface_count()):
		var original = mesh.surface_get_material(surface)
		var toon = ShaderMaterial.new(); toon.shader = load("res://shaders/pack_toon.gdshader")
		toon.set_shader_parameter("tint", Color.WHITE); toon.set_shader_parameter("textured", original.albedo_texture != null)
		if original.albedo_texture: toon.set_shader_parameter("albedo_texture", original.albedo_texture)
		mesh.surface_set_material(surface, toon)
	if palette_cache.size() >= 128: palette_cache.erase(palette_cache.keys()[0])
	palette_cache[key] = mesh
	return mesh

static func _remove_hat(source: Mesh, head_level: float) -> Mesh:
	var mesh = ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var data = source.surface_get_arrays(surface)
		var texture = source.surface_get_material(surface).albedo_texture
		var image = texture.get_image(); image.decompress()
		var points = data[Mesh.ARRAY_VERTEX]; var uv = data[Mesh.ARRAY_TEX_UV]
		var indices = data[Mesh.ARRAY_INDEX]
		if indices == null or indices.is_empty(): indices = PackedInt32Array(range(points.size()))
		var kept = PackedInt32Array()
		for i in range(0, indices.size(), 3):
			var point = (points[indices[i]] + points[indices[i + 1]] + points[indices[i + 2]]) / 3
			var at = uv[indices[i]]
			var color = image.get_pixel(clampi(int(at.x * image.get_width()), 0, image.get_width() - 1), clampi(int(at.y * image.get_height()), 0, image.get_height() - 1))
			var skin = color.is_equal_approx(Color8(255, 211, 186)) or color.is_equal_approx(Color8(255, 235, 211))
			if point.y > head_level + 0.12 and not skin: continue
			kept.append_array(PackedInt32Array([indices[i], indices[i + 1], indices[i + 2]]))
		data[Mesh.ARRAY_INDEX] = kept; mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh

static func attachment(skeleton: Skeleton3D, bone: String, title: String) -> Node3D:
	var socket = BoneAttachment3D.new(); socket.name = title + "Socket"; socket.bone_name = bone; skeleton.add_child(socket)


	var node = Node3D.new(); node.name = title; node.basis = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).basis.inverse(); socket.add_child(node)
	return node

static func apron(parent: Node3D, material: Material) -> void:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)


	var rows = [[0.18, 0.095, 0.19], [-0.09, 0.16, 0.19], [-0.25, 0.19, 0.22], [-0.45, 0.22, 0.24]]
	for row in range(rows.size() - 1):
		for col in range(8):
			for corner in [Vector2i(row, col), Vector2i(row + 1, col + 1), Vector2i(row, col + 1), Vector2i(row, col), Vector2i(row + 1, col), Vector2i(row + 1, col + 1)]:
				var u = float(corner.y) / 8; var r = rows[corner.x]
				var x = (u * 2 - 1) * r[1]
				var z = r[2] - 0.045 * pow(u * 2 - 1, 2) + sin(u * PI * 6) * 0.007
				st.set_uv(Vector2(u, float(corner.x) / 3)); st.add_vertex(Vector3(x, r[0], z))
	st.generate_normals(); st.generate_tangents()
	var mesh = B.mesh(parent, st.commit(), material); mesh.name = "DrapedApron"
	if material is StandardMaterial3D: material.cull_mode = BaseMaterial3D.CULL_DISABLED

static func add_features(actor, skeleton: Skeleton3D, d: Dictionary) -> void:
	var head = attachment(skeleton, "Head", "IdentityHead")
	actor.head = head; head.set_meta("hair_design", d.hair)
	if d.race == "smallfolk" or d.id in ["ironbell_smith", "brindlewick_merchant", "brindlewick_baker"]:
		B.ball(head, Vector3(0, 0.2, 0), Vector3(0.26, 0.17, 0.24), B.mat(Color(d.hair_color).to_html()))
	var skin = B.mat(Color(d.skin).to_html()); var hair = B.mat(Color(d.hair_color).to_html()); var cloth = B.world_surface("cloth", Color(d.coat).to_html())
	var features = ""
	if d.race in ["elf", "orc"]:
		features = "pointed_ears" if d.race == "elf" else "tusks_and_broad_orc"
		for side in [-1.0, 1.0]:
			var ear = B.facet(head, Vector3(side * 0.145, 0.12, 0.015), Vector3(0.15, 0.1, 0.055), skin); ear.rotation.z = -side * 0.5
			if d.race == "orc":
				B.branch(head, Vector3(side * 0.065, 0.025, 0.125), Vector3(side * 0.075, 0.12, 0.145), 0.02, B.mat("#ead8b0"))
	if d.race == "dwarf" or d.id == "ironbell_smith":
		features = "copper_braids" if d.feminine else "braided_beard"
		for side in [-1.0, 1.0]:
			for i in range(5):
				B.ball(head, Vector3(side * (0.12 + sin(i * 1.7) * 0.012), 0.15 - i * 0.055, 0.07), Vector3(0.055, 0.075, 0.065), hair)
			B.ring(head, Vector3(side * 0.12, -0.05, 0.07), 0.027, 0.009, B.mat("#b99850", 0.6))
	if d.hair in ["silver_beard", "silver_bun"]:
		B.ball(head, Vector3(0, 0.21, -0.1), Vector3(0.19, 0.15, 0.13), hair)
		if d.hair == "silver_beard": B.facet(head, Vector3(0, -0.02, 0.12), Vector3(0.15, 0.29, 0.11), hair)
	if d.race == "smallfolk":
		features = "smallfolk_curls"
		for i in range(6): B.ball(head, Vector3(cos(i * TAU / 6) * 0.11, 0.23, sin(i * TAU / 6) * 0.08), Vector3(0.1, 0.09, 0.095), hair)
	var body_bone = "Spine_02" if skeleton.find_bone("Spine_02") >= 0 else "Spine_01"
	var body = attachment(skeleton, body_bone, "IdentityCostume")
	if "apron" in str(d.costume):
		var leather = B.world_surface("leather", "#684533" if d.role == "smith" else "#d4c3a1")
		apron(body, leather)
		for side in [-1.0, 1.0]: B.beveled_box(body, Vector3(side * 0.1, 0.14, 0.17), Vector3(0.035, 0.22, 0.03), leather)
		B.box(body, Vector3(0.08, -0.22, 0.232), Vector3(0.1, 0.08, 0.004), cloth)
	elif d.costume == "rowan_shawl":
		for side in [-1.0, 1.0]:
			var shawl = B.beveled_box(body, Vector3(side * 0.12, 0.05, 0.17), Vector3(0.2, 0.3, 0.045), cloth); shawl.rotation.z = side * 0.38
	elif d.role == "guard":
		for side in [-1.0, 1.0]: B.beveled_box(body, Vector3(side * 0.22, 0.14, 0), Vector3(0.16, 0.08, 0.24), B.mat("#8a9697", 0.65))
	actor.visual.set_meta("race_features", features)
	B.batch_static(head); B.batch_static(body)
static func design(id: String, race: String, role: String, coat: Color) -> Dictionary:
	var seed := absi(hash(id))
	var variant := seed % 4
	var region := "brindlewick"
	for place in ["ironbell", "alderhaven", "sunspire", "frostharbor"]:
		if id.begins_with(place): region = place
	var feminine := seed % 3 != 0
	var age := 2 if seed % 7 == 0 else 0
	var hair: String = ["swept", "cropped", "curls", "bun"][variant]
	var skin: Color = [Color("#c49373"), Color("#b67f60"), Color("#d1ab89"), Color("#8c5f49")][variant]
	var hair_color: Color = [Color("#443329"), Color("#5b3a2b"), Color("#776044"), Color("#282c2c")][variant]
	var height: float = {"human": 1.82, "elf": 2.04, "dwarf": 1.46, "orc": 2.45, "smallfolk": 1.16}.get(race, 1.82)
	var broad: float = {"human": 1.0, "elf": 0.8, "dwarf": 1.28, "orc": 1.7, "smallfolk": 0.76}.get(race, 1.0)
	var face_size: Vector3 = {"human": Vector3(0.395, 0.385, 0.35), "elf": Vector3(0.335, 0.38, 0.325), "dwarf": Vector3(0.43, 0.36, 0.37), "orc": Vector3(0.57, 0.48, 0.44), "smallfolk": Vector3(0.315, 0.33, 0.29)}.get(race, Vector3(0.395, 0.385, 0.35))
	var costume := "workcoat"
	if race == "elf": hair = "long_waves" if feminine else "short_braid"
	elif race == "dwarf": hair = "copper_braids" if feminine else "braided_beard"
	elif race == "orc":
		hair = "tied_orc"
		skin = [Color("#78805a"), Color("#71845d"), Color("#657c62"), Color("#8a895f")][variant]
		hair_color = Color("#292e28")
	elif race == "smallfolk": hair = "honey_curls"
	if role == "smith": costume = "smith_apron"
	elif role in ["baker", "gardener"]: costume = "linen_apron"
	elif role == "weaver": costume = "layered_tunic"
	elif role == "guard": costume = "watch_coat"
	elif role == "wizard":
		costume = "spellwright_robe"; hair = "silver_beard"; age = 2; feminine = false; hair_color = Color("#b9b8a5")
	if race == "elf" and role == "gardener": costume = "herbalist_layers"
	match id:
		"brindlewick_merchant":
			costume = "rowan_shawl"; hair = "silver_bun"; hair_color = Color("#c6c2b2"); age = 2; feminine = true; skin = Color("#c4977d"); coat = Color("#955638")
		"brindlewick_smith":
			costume = "bramm_apron"; hair = "tied_orc"; skin = Color("#7a8053"); hair_color = Color("#292c26"); feminine = false; variant = 1; age = 0
		"ironbell_smith":
			costume = "hester_apron"; hair = "copper_braids"; skin = Color("#c69577"); hair_color = Color("#9c542e"); coat = Color("#713c49"); feminine = true; variant = 2; age = 0
		"brindlewick_baker":
			costume = "honey_apron"; hair = "honey_curls"; hair_color = Color("#856137"); skin = Color("#c89f7b"); feminine = true; variant = 0
		"brindlewick_gardener":
			costume = "herbalist_layers"; hair = "long_waves"; hair_color = Color("#a99b78"); skin = Color("#cfb59a"); coat = Color("#69735b"); feminine = true; variant = 0
		"ironbell_merchant":
			costume = "market_coat"; hair = "dark_bun"; hair_color = Color("#332922"); skin = Color("#9d7053"); coat = Color("#725263"); feminine = true; variant = 3; age = 1
	face_size.x *= [1.0, 0.96, 1.035, 0.98][variant]
	face_size.z *= [1.0, 1.025, 0.96, 1.04][variant]
	if region == "sunspire": coat = coat.lightened(0.17)
	elif region == "frostharbor": coat = coat.darkened(0.09)
	return {"id": id, "race": race, "role": role, "region": region, "variant": variant, "height": height, "broad": broad, "face_size": face_size, "skin": skin, "hair": hair, "hair_color": hair_color, "coat": coat, "feminine": feminine, "age": age, "costume": costume}
