extends RefCounted
## Gives trees and plants wind: their materials switch to swaying versions of the same look
## (pack_toon → pack_toon_sway, plain lit leaves → foliage_sway). Rocks, pebbles, stumps,
## mushrooms, cacti and crystals stay still.

const STILL := ["rock", "pebble", "petal", "mushroom", "cactus", "crystal", "trunk", "stump", "log", "path"]
static var _meshes := {}
static var _materials := {}

static func sways(id: String) -> bool:
	if not (id.begins_with("qnat_") or id.begins_with("nature_")): return false
	for word in STILL:
		if word in id: return false
	return true

## A copy of the mesh whose materials sway (shared per source mesh).
static func apply(mesh: Mesh) -> Mesh:
	if mesh == null or not mesh is ArrayMesh: return mesh
	var key := mesh.get_instance_id()
	if _meshes.has(key): return _meshes[key]
	var result: ArrayMesh = mesh.duplicate()
	for surface in range(result.get_surface_count()):
		var swaying = material(result.surface_get_material(surface))
		if swaying != null: result.surface_set_material(surface, swaying)
	for meta in mesh.get_meta_list(): result.set_meta(meta, mesh.get_meta(meta))
	_meshes[key] = result
	return result

static func material(source: Material) -> Material:
	if source == null: return null
	var key := source.get_instance_id()
	if _materials.has(key): return _materials[key]
	var result: ShaderMaterial = null
	if source is ShaderMaterial and source.shader != null:
		var path: String = source.shader.resource_path
		if path == "res://shaders/pack_toon.gdshader":
			result = source.duplicate(); result.shader = preload("res://shaders/pack_toon_sway.gdshader")
		elif path in ["res://shaders/regional_plant.gdshader", "res://shaders/pack_toon_sway.gdshader", "res://shaders/foliage_sway.gdshader"]:
			result = source
	elif source is StandardMaterial3D:
		result = ShaderMaterial.new(); result.shader = preload("res://shaders/foliage_sway.gdshader")
		result.set_shader_parameter("albedo_color", source.albedo_color)
		result.set_shader_parameter("textured", source.albedo_texture != null)
		if source.albedo_texture != null: result.set_shader_parameter("albedo_texture", source.albedo_texture)
		result.set_shader_parameter("use_vertex_color", source.vertex_color_use_as_albedo)
		result.set_shader_parameter("roughness", source.roughness)
		if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: result.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold)
		elif source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: result.set_shader_parameter("alpha_cutoff", 0.5)
	_materials[key] = result
	return result
