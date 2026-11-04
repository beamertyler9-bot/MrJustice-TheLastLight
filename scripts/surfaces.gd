extends RefCounted



static var materials: Dictionary = {}
static var textures: Dictionary = {}
static var normals: Dictionary = {}
const FAMILIES = ["stone", "timber", "cloth", "leather", "ground", "roof"]

static func texture(kind: String) -> Texture2D:
	if not textures.has(kind):
		textures[kind] = load("res://assets/surfaces/%s.png" % kind)
	return textures[kind]

static func normal_detail(kind: String) -> Texture2D:
	if not normals.has(kind):
		if kind == "roof":
			normals[kind] = load("res://assets/surfaces/roof_normal.png")
			return normals[kind]
		var noise := FastNoiseLite.new()
		noise.seed = 2791 if kind == "stone" else 4913
		noise.frequency = 0.065 if kind == "stone" else 0.18
		noise.fractal_octaves = 3
		var tile := NoiseTexture2D.new()
		tile.width = 256
		tile.height = 256
		tile.seamless = true
		tile.generate_mipmaps = true
		tile.as_normal_map = true
		tile.bump_strength = 0.25 if kind == "stone" else 0.1
		tile.noise = noise
		normals[kind] = tile
	return normals[kind]

static func get_surface(kind: String, tint: Color, metallic: float = 0.0, world_projection: bool = false) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [kind, tint.to_html(), metallic, world_projection]
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = metallic
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.roughness = 0.8
	material.set_meta("static_palette", true)
	material.set_meta("surface_family", kind)
	var family := kind
	if kind == "plaster": family = "stone"
	if kind == "fur": family = "cloth"
	if family in FAMILIES:
		material.albedo_texture = texture(family)
		material.uv1_triplanar = world_projection
		material.uv1_world_triplanar = world_projection
		material.uv1_triplanar_sharpness = 5.0
		var density := {"stone": 0.8, "timber": 0.55, "cloth": 3.0, "leather": 2.3, "ground": 0.5, "roof": 0.55}[family] as float
		material.uv1_scale = Vector3.ONE * density
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var gain := {"stone": 1.55, "timber": 2.1, "cloth": 1.28, "leather": 1.7, "ground": 1.65, "roof": 1.45}[family] as float



		gain = minf(gain, 1.0 / maxf(0.001, maxf(tint.r, maxf(tint.g, tint.b))))
		material.albedo_color = Color(tint.r * gain, tint.g * gain, tint.b * gain, 1.0)
		material.roughness = {"stone": 0.9, "timber": 0.8, "cloth": 0.86, "leather": 0.58, "ground": 0.97, "roof": 0.84}[family]
		if family in ["stone", "leather", "roof"]:
			material.normal_enabled = true
			material.normal_texture = normal_detail(family)
			material.normal_scale = 0.3 if family in ["stone", "roof"] else 0.12
	if kind == "plaster":
		material.albedo_texture = texture("plaster"); material.albedo_color = tint
		material.normal_enabled = false; material.uv1_scale = Vector3.ONE * 0.23
	if kind == "skin":
		material.roughness = 0.74
		material.metallic_specular = 0.28
	if kind == "silver":
		material.metallic = 0.78
		material.roughness = 0.2
		material.metallic_specular = 0.65
	if kind == "fur": material.uv1_scale = Vector3.ONE * 5.0
	materials[key] = material
	return material
