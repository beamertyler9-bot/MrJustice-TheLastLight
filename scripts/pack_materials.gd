extends RefCounted


const SHADER = preload("res://shaders/pack_toon.gdshader")
static var _materials: Dictionary = {}

static func apply(mesh: Mesh) -> void:
	for i in range(mesh.get_surface_count()):
		var original = mesh.surface_get_material(i)
		if not original is StandardMaterial3D or original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key = original.get_instance_id()
		if not _materials.has(key):
			var mat = ShaderMaterial.new(); mat.shader = SHADER
			mat.set_shader_parameter("tint", original.albedo_color)
			mat.set_shader_parameter("textured", original.albedo_texture != null)
			if original.albedo_texture: mat.set_shader_parameter("albedo_texture", original.albedo_texture)
			_materials[key] = mat
		mesh.surface_set_material(i, _materials[key])
