extends RefCounted


const BASE = ["#416b4e", "#a68b9a", "#8a9278", "#b9aa8c", "#62534f", "#605969", "#8f9b9e"]
const LITTER = ["#7b8758", "#b99daa", "#b3ae91", "#cec1a5", "#8a6d5e", "#857b94", "#b5bec3"]
const GRASS = ["#548361", "#b184a3", "#919877", "#a99e81", "#74655d", "#7a7089", "#90a7a4"]
const MEADOW = ["#8ca96b", "#d5a2bc", "#b7af8f", "#c5b697", "#a47a61", "#a69aaf", "#afbec8"]
const FERN = ["#4f8469", "#ca8cba", "#7e9365", "#9b9d69", "#76665a", "#8b7c9b", "#91bbb8"]
const PATH = ["#b39c76", "#ba9b83", "#c0ad7d", "#d4b37e", "#9d806b", "#a08e95", "#bdc5be"]
const ROCK = ["#7d8a79", "#9c8a9b", "#a5a58c", "#b39a76", "#7e726e", "#8d8497", "#a9bfc3"]
static var painted_meshes = {}
static func color_for(region: int) -> Color: return Color(BASE[clampi(region - 9, 0, 6)])
static func configure(material: ShaderMaterial) -> void:
	material.set_shader_parameter("regional_albedo", load("res://assets/surfaces/regions/albedo-layers.res"))
	material.set_shader_parameter("regional_relief", load("res://assets/surfaces/regions/relief-layers.res"))
	material.set_shader_parameter("regional_map", load("res://assets/surfaces/regions/biomes.png"))
	var bounds = preload("res://scripts/fixed_world.gd").bounds()
	material.set_shader_parameter("regional_map_origin", bounds.position)
	material.set_shader_parameter("regional_map_extent", bounds.size)
	material.set_shader_parameter("regional_surfaces", true)
static func paint_mesh(source: Mesh, key: String, colors: Array, bark_surface: int = -1) -> ArrayMesh:
	if not painted_meshes.has(key):
		var result: ArrayMesh = source.duplicate()
		for surface in range(result.get_surface_count()):
			var original = source.surface_get_material(surface); var texture = null; var cutoff = 0.0
			if original is StandardMaterial3D:
				texture = original.albedo_texture
				if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: cutoff = original.alpha_scissor_threshold
			elif original is ShaderMaterial:
				texture = original.get_shader_parameter("albedo_texture")
			var paint = ShaderMaterial.new(); paint.shader = preload("res://shaders/regional_plant.gdshader")
			paint.set_shader_parameter("tint", Color(colors[mini(surface, colors.size() - 1)])); paint.set_shader_parameter("textured", texture != null)
			if texture: paint.set_shader_parameter("albedo_texture", texture)
			paint.set_shader_parameter("alpha_cutoff", cutoff); paint.set_shader_parameter("candy_surface", true); paint.set_shader_parameter("candy_bark", surface == bark_surface)
			result.surface_set_material(surface, paint)
		result.set_meta("biome_art_revision", 32); painted_meshes[key] = result
	return painted_meshes[key]
static func paint_model(node: Node3D, key: String, colors: Array) -> void:
	for art in node.find_children("*", "MeshInstance3D", true, false):
		art.mesh = paint_mesh(art.mesh, key, colors)
		art.material_override = null
