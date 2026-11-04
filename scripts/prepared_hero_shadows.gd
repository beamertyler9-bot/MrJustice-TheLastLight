extends Node

const LIBRARY = "res://assets/hero_shadows/hero_shadow_batches.res"
var groups: Array = []
var materials: Dictionary = {}

static func excluded_sources(hero: Node) -> Array:
	var result = []
	for key in ["flame", "inner_flame", "cape"]:
		var source = hero.get(key)
		if is_instance_valid(source): result.append(source)
	for side in hero.get("_bag_straps"):
		for source in side: result.append(source)
	for source in hero.get("ordinary_digit_meshes"): result.append(source)
	for source in hero.get("ordinary_support_digits"): result.append(source)
	var rune = hero.get("_grimoire_rune")
	if is_instance_valid(rune):
		for source in rune.find_children("*", "MeshInstance3D", true, false): result.append(source)
	return result

static func path_to(root: Node, node: Node) -> PackedInt32Array:
	var result = PackedInt32Array()
	while node != root: result.insert(0, node.get_index()); node = node.get_parent()
	return result
static func node_at(root: Node, path: PackedInt32Array) -> Node:
	var node = root
	for index in path:
		if index < 0 or index >= node.get_child_count(): return null
		node = node.get_child(index)
	return node

static func opaque_material(source: MeshInstance3D) -> int:
	var cull = -1
	for surface in range(source.mesh.get_surface_count()):
		var paint = source.get_surface_override_material(surface)
		if paint == null: paint = source.material_override if source.material_override != null else source.mesh.surface_get_material(surface)
		if not paint is StandardMaterial3D: return -1
		if paint.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or paint.next_pass != null or paint.grow or paint.heightmap_enabled or paint.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or paint.fixed_size or paint.proximity_fade_enabled or paint.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return -1
		if cull >= 0 and cull != paint.cull_mode: return -1
		cull = paint.cull_mode
	return cull
static func eligible(source: MeshInstance3D, excluded: Array) -> bool:
	if source.mesh == null or excluded.has(source) or source.get_script() != null or source.skin != null or source.top_level or source.get_child_count() != 0 or source.material_overlay != null: return false
	if not (source.mesh is ArrayMesh or source.mesh is PrimitiveMesh): return false
	if source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or source.visibility_range_begin != 0 or source.visibility_range_end != 0 or source.custom_aabb != AABB() or source.extra_cull_margin != 0 or source.transparency != 0 or source.visibility_parent != NodePath() or source.basis.determinant() == 0: return false
	if source.mesh is ArrayMesh:
		if source.mesh.get_blend_shape_count() != 0: return false
		for surface in range(source.mesh.get_surface_count()):
			if source.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: return false
	return opaque_material(source) >= 0

static func mesh_contract(mesh: Mesh) -> Dictionary:
	var result = {"class": mesh.get_class(), "path": mesh.resource_path, "bounds": mesh.get_aabb(), "surfaces": mesh.get_surface_count(), "shape": {}}
	if mesh is PrimitiveMesh:
		for info in mesh.get_property_list():
			if not (info.usage & PROPERTY_USAGE_STORAGE) or str(info.name).begins_with("metadata/"): continue
			var value = mesh.get(info.name)
			if typeof(value) != TYPE_OBJECT: result.shape[info.name] = value
	elif mesh is ArrayMesh:
		result.vertices = []; result.indices = []
		for surface in range(mesh.get_surface_count()): result.vertices.append(mesh.surface_get_array_len(surface)); result.indices.append(mesh.surface_get_array_index_len(surface))
	return result

static func apply(hero: Node):
	var existing = hero.get_node_or_null("PreparedHeroShadows")
	if existing != null: return existing
	if not ResourceLoader.exists(LIBRARY): return null
	return apply_library(hero, load(LIBRARY))
static func apply_library(hero: Node, library: Resource):
	var renderer = load("res://scripts/prepared_hero_shadows.gd").new(); renderer.name = "PreparedHeroShadows"; hero.add_child(renderer)
	var excluded = excluded_sources(hero)
	for saved in library.get_meta("groups", []):
		var parent = node_at(hero, saved.parent); var sources = []; var valid = parent is Node3D
		for expected in saved.sources:
			var source = node_at(hero, expected.path)
			if not source is MeshInstance3D or source.get_parent() != parent or not eligible(source, excluded): valid = false; break
			if source.layers != saved.layers or source.visible != expected.visible or not source.transform.is_equal_approx(expected.frame) or mesh_contract(source.mesh) != expected.mesh or opaque_material(source) != saved.cull: valid = false; break
			sources.append({"source": source, "shadow": source.cast_shadow, "visible": source.visible})
		if not valid or sources.size() < 2: continue
		var proxy = MeshInstance3D.new(); proxy.name = "PreparedJointShadow"; proxy.mesh = saved.mesh; proxy.layers = saved.layers; proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY; proxy.set_meta("prepared_shadow_proxy", true)
		if not renderer.materials.has(saved.cull):
			var paint = StandardMaterial3D.new(); paint.cull_mode = saved.cull; renderer.materials[saved.cull] = paint
		proxy.material_override = renderer.materials[saved.cull]; proxy.visible = saved.sources[0].visible; parent.add_child(proxy)
		var callback = renderer.release_index.bind(renderer.groups.size())
		var visibility_callback = renderer.source_visibility_changed.bind(renderer.groups.size())
		var group = {"proxy": proxy, "sources": sources, "active": true, "callback": callback, "visibility_callback": visibility_callback}; renderer.groups.append(group)
		for item in sources:
			item.source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; item.source.visibility_changed.connect(visibility_callback); item.source.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	return renderer

func release_index(index: int) -> void:
	if index >= 0 and index < groups.size(): release_group(groups[index])
func source_visibility_changed(index: int) -> void:
	if index < 0 or index >= groups.size() or not groups[index].active: return


	for item in groups[index].sources:
		if is_instance_valid(item.source) and item.source.visible != item.visible: release_group(groups[index]); return
func release_group(group: Dictionary) -> void:
	if not group.active: return
	group.active = false
	if is_instance_valid(group.proxy): group.proxy.hide(); group.proxy.queue_free()
	for item in group.sources:
		if not is_instance_valid(item.source): continue
		item.source.cast_shadow = item.shadow
		if item.source.visibility_changed.is_connected(group.visibility_callback): item.source.visibility_changed.disconnect(group.visibility_callback)
		if item.source.tree_exiting.is_connected(group.callback): item.source.tree_exiting.disconnect(group.callback)
func _exit_tree() -> void:
	for group in groups: release_group(group)
