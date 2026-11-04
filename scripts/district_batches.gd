extends Node3D

const STATES = ["layers", "cast_shadow", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "lod_bias", "gi_mode", "gi_lightmap_texel_scale", "ignore_occlusion_culling", "extra_cull_margin"]
const LIBRARY = "res://assets/world/district_batches/"
const PACK_TOON_DEFAULTS = {"tint": Color.WHITE, "albedo_texture": null, "textured": false, "shadow_tint": Color(0.44, 0.5, 0.57, 1), "rim_blend": 0.055}
var groups: Array = []
var mutating = false
var audit_clock = 0.0
var audit_index = 0
var last_view = Vector3.INF
var last_detail_range = -1.0

## Frequently rebuilt libraries stay loaded instead of being re-read from disk each time.
const CACHED_LIBRARIES := ["housing-vistas"]
static var _library_cache: Dictionary = {}
## Incremental builds bind saved cells a little at a time (per-frame time budget) so a
## rebuild never freezes a frame; sources simply render unbatched until bound.
const BIND_BUDGET_USEC := 1500
var pending_cells: Array = []
var pending_index := 0
var pending_owners: Dictionary = {}

static func rebuild(owner: Node3D, key: String, library: Resource = null, incremental: bool = false):
	var previous = owner.get_node_or_null("DistrictBatches")
	if previous: previous.free()
	return build(owner, key, library, incremental)
static func build(owner: Node3D, key: String, library: Resource = null, incremental: bool = false):
	var previous = owner.get_node_or_null("DistrictBatches")
	if previous: return previous
	if library == null:
		var path = LIBRARY + key + ".res"
		if not ResourceLoader.exists(path): return null
		if key in CACHED_LIBRARIES:
			if not _library_cache.has(path): _library_cache[path] = load(path)
			library = _library_cache[path]
		else:
			library = load(path)
	if library.get_meta("schema", 0) != 1: return null
	var renderer = load("res://scripts/district_batches.gd").new(); renderer.name = "DistrictBatches"; renderer.add_to_group("batch_dynamic"); owner.add_child(renderer)
	var owners = {"@root": owner}
	for n in owner.find_children("*", "Node3D", true, false):
		if (n.is_in_group("settlement_building") or n.is_in_group("housing_representation")) and n.has_meta("plot_id"): owners[str(n.get_meta("plot_id"))] = n
	if incremental:
		renderer.pending_cells = library.get_meta("cells", [])
		renderer.pending_index = 0
		renderer.pending_owners = owners
		return renderer
	for saved in library.get_meta("cells", []): renderer._bind(saved, owners)
	renderer.refresh_visibility()
	renderer.last_detail_range = preload("res://scripts/imported_assets.gd").detail_range()
	return renderer

static func mesh_of(source): return source.mesh if source is MeshInstance3D else source.multimesh.mesh if source is MultiMeshInstance3D and source.multimesh else null
static func material_of(source, surface: int):
	if source.material_override: return source.material_override
	if source is MeshInstance3D and source.get_surface_override_material(surface): return source.get_surface_override_material(surface)
	return mesh_of(source).surface_get_material(surface)
static func mesh_contract(mesh: Mesh): return preload("res://scripts/prepared_hero_shadows.gd").mesh_contract(mesh)
static func value_contract(value):

	if value == null: return null
	if value is float: return PackedFloat32Array([value])[0]
	if value is Resource: return {"class": value.get_class(), "path": value.resource_path}
	return value
static func material_contract(material: Material) -> Dictionary:
	var result = {"class": material.get_class()}
	for property in material.get_property_list():
		var key = str(property.name)
		if not (property.usage & PROPERTY_USAGE_STORAGE) or key in ["resource_name", "resource_local_to_scene", "resource_path"]: continue
		var value = material.get(key)
		if typeof(value) in [TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]: continue
		result[key] = value_contract(value)
	return normalize_material_contract(result)
static func normalize_material_contract(contract: Dictionary) -> Dictionary:
	if contract.get("class") != "ShaderMaterial" or contract.get("shader", {}).get("path", "") != "res://shaders/pack_toon.gdshader": return contract


	for uniform in PACK_TOON_DEFAULTS:
		var key = "shader_parameter/" + uniform
		contract[key] = value_contract(contract.get(key) if contract.get(key) != null else PACK_TOON_DEFAULTS[uniform])
	return contract
static func node_at(owner: Node, path: PackedInt32Array):
	var node = owner
	for index in path:
		if index < 0 or index >= node.get_child_count(): return null
		node = node.get_child(index)
	return node

func _bind(saved: Dictionary, owners: Dictionary):
	var group = {"saved": saved, "sources": [], "meshes": [], "materials": [], "parents": [], "draws": [], "links": [], "watches": [], "active": false, "modified": false, "within": false}
	var used = {}
	for expected in saved.sources:
		if not owners.has(expected.owner): return
		var holder = owners[expected.owner]
		if not is_instance_valid(holder) or holder.is_queued_for_deletion(): return
		var source = node_at(holder, expected.path)
		if not _matches(source, expected) or used.has(source.get_instance_id()):
			source = null



			for candidate in holder.find_children("*", "GeometryInstance3D", true, false):
				if not used.has(candidate.get_instance_id()) and _matches(candidate, expected): source = candidate; break
		if source == null: return
		used[source.get_instance_id()] = true
		group.sources.append(source); group.meshes.append(mesh_of(source))
		var paints = []
		for surface in range(mesh_of(source).get_surface_count()): paints.append(material_of(source, surface))
		group.materials.append(paints)
		var parents = []
		var ancestor = source.get_parent()
		while ancestor != get_parent():
			if ancestor is Node3D: parents.append(ancestor)
			ancestor = ancestor.get_parent()
		group.parents.append(parents)
	if not _valid(group, false, false, true): return
	var index = groups.size(); groups.append(group)
	for draw in saved.draws:
		var proxy = MeshInstance3D.new(); proxy.name = "PreparedDistrictSurface"; proxy.mesh = draw.mesh; proxy.material_override = group.materials[draw.source][draw.surface]
		for key in draw.state:
			if not key.begins_with("visibility_range_"): proxy.set(key, draw.state[key])
		proxy.visible = false; add_child(proxy); group.draws.append(proxy)
	var callback = owner_transform_changed.bind(index); var visible_callback = _visibility_changed.bind(index); var exit_callback = _source_exiting.bind(index)
	for source in group.sources:
		var watch = load("res://scripts/stationary_render_watch.gd").new(); source.add_child(watch); watch.setup(self, index); group.watches.append(watch)
		var node = source
		while node != get_parent():
			if not node.visibility_changed.is_connected(visible_callback): node.visibility_changed.connect(visible_callback); group.links.append([node, "visibility_changed", visible_callback])
			if not node.tree_exiting.is_connected(exit_callback): node.tree_exiting.connect(exit_callback); group.links.append([node, "tree_exiting", exit_callback])
			node = node.get_parent()
		var mesh = mesh_of(source)
		var changed = _geometry_changed.bind(index)
		if not mesh.changed.is_connected(changed): mesh.changed.connect(changed); group.links.append([mesh, "changed", changed])
		for surface in range(mesh.get_surface_count()):
			var material = material_of(source, surface)
			if not material.changed.is_connected(changed): material.changed.connect(changed); group.links.append([material, "changed", changed])

func _matches(source, expected: Dictionary) -> bool:
	if not (source is MeshInstance3D or source is MultiMeshInstance3D) or not source.visible: return false
	if (source is MultiMeshInstance3D) != (not expected.instances.is_empty()): return false
	if not (get_parent().global_transform.affine_inverse() * source.global_transform).is_equal_approx(expected.frame): return false
	var mesh = mesh_of(source)
	if mesh == null or mesh_contract(mesh) != expected.mesh: return false
	if not _state_matches(source, expected.state): return false
	if source.material_overlay != null or source.transparency != 0 or source.top_level or source.visibility_parent != NodePath(): return false
	if source is MultiMeshInstance3D:
		if source.multimesh.use_colors or source.multimesh.use_custom_data or source.multimesh.visible_instance_count != -1: return false
		if source.multimesh.instance_count != expected.instances.size() or source.get_meta("instance_transforms", []) != expected.instances: return false
	for surface in range(mesh.get_surface_count()):
		if material_contract(material_of(source, surface)) != normalize_material_contract(expected.materials[surface]): return false
	return true
func _state_matches(source, state: Dictionary) -> bool:
	for key in state:
		if source.get(key) == state[key]: continue
		if key == "visibility_range_end" and source.is_in_group("imported_detail") and state[key] in [55.0, 85.0, 110.0, 750.0] and source.visibility_range_end == preload("res://scripts/imported_assets.gd").detail_range(): continue
		return false
	return true
func _valid(group: Dictionary, active: bool, full: bool = false, binding: bool = false) -> bool:
	if group.modified: return false
	var owner = get_parent()
	for i in range(group.sources.size()):
		var source = group.sources[i]; var expected = group.saved.sources[i]
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not owner.is_ancestor_of(source): return false
		if source.visible == active or mesh_of(source) != group.meshes[i]: return false
		if not (owner.global_transform.affine_inverse() * source.global_transform).is_equal_approx(expected.frame): return false
		if full and mesh_contract(mesh_of(source)) != expected.mesh: return false
		if not _state_matches(source, expected.state): return false
		if source.material_overlay != null or source.transparency != 0 or source.top_level or source.visibility_parent != NodePath(): return false
		if source is MultiMeshInstance3D:
			if source.multimesh.instance_count != expected.instances.size() or source.multimesh.use_colors or source.multimesh.use_custom_data or source.multimesh.visible_instance_count != -1: return false
			if source.get_meta("instance_transforms", []) != expected.instances: return false
		for surface in range(group.materials[i].size()):
			var paint = material_of(source, surface)
			if paint != group.materials[i][surface] or (full and material_contract(paint) != expected.materials[surface]): return false
		for node in group.parents[i]:
			if not is_instance_valid(node) or (not binding and not node.visible): return false
	return true
func _in_range(group: Dictionary, point: Vector3) -> bool:
	for i in range(group.sources.size()):
		var source = group.sources[i]
		if not is_instance_valid(source): return false
		var distance = point.distance_to(get_parent().to_global(group.saved.sources[i].center))
		if source.visibility_range_begin > 0 and distance <= source.visibility_range_begin + source.visibility_range_begin_margin: return false
		if source.visibility_range_end > 0 and distance >= source.visibility_range_end - source.visibility_range_end_margin: return false
	return true
func _activate(group: Dictionary):
	mutating = true
	for source in group.sources: source.hide()
	for proxy in group.draws: proxy.show()
	group.active = true; mutating = false
func _deactivate(group: Dictionary):
	if not group.active: return
	mutating = true
	for proxy in group.draws:
		if is_instance_valid(proxy): proxy.hide()
	for source in group.sources:
		if is_instance_valid(source): source.show()
	group.active = false; mutating = false
func owner_transform_changed(index: int):
	if mutating or index >= groups.size(): return
	var group = groups[index]
	if group.active and not _valid(group, true): _deactivate(group)
func _visibility_changed(index: int):
	if mutating: return
	owner_transform_changed(index)
func _source_exiting(index: int):
	if mutating: return
	_deactivate(groups[index])
func _geometry_changed(index: int):
	groups[index].modified = true; _deactivate(groups[index])
func refresh_visibility():
	_update_ranges(true)
func _update_ranges(audit: bool, only_group: int = -1):
	var camera = get_viewport().get_camera_3d()
	if camera == null: return
	last_view = camera.global_position
	for i in range(groups.size()):
		var group = groups[i]; var inspect_contract = audit and (only_group < 0 or only_group == i)
		var within = _in_range(group, last_view)
		if group.active:
			if not within or (inspect_contract and not _valid(group, true)): _deactivate(group)
		elif within and (inspect_contract or not group.within) and _valid(group, false): _activate(group)
		group.within = within
func _process(dt: float):
	if pending_index < pending_cells.size():
		var started := Time.get_ticks_usec()
		while pending_index < pending_cells.size() and Time.get_ticks_usec() - started < BIND_BUDGET_USEC:
			_bind(pending_cells[pending_index], pending_owners); pending_index += 1
		if pending_index >= pending_cells.size():
			pending_cells = []; pending_owners = {}
			refresh_visibility()
			last_detail_range = preload("res://scripts/imported_assets.gd").detail_range()
		return
	audit_clock += dt
	var camera = get_viewport().get_camera_3d()
	var detail_range = preload("res://scripts/imported_assets.gd").detail_range()
	if detail_range != last_detail_range: last_detail_range = detail_range; refresh_visibility(); return
	var interval = 0.5 / maxi(1, groups.size())
	if camera and (camera.global_position != last_view or audit_clock >= interval):
		var audit = audit_clock >= interval
		if audit: audit_clock = 0
		_update_ranges(audit, audit_index)
		if audit: audit_index = (audit_index + 1) % maxi(1, groups.size())
func _exit_tree():
	mutating = true
	for group in groups:
		for link in group.links:
			if is_instance_valid(link[0]) and link[0].is_connected(link[1], link[2]): link[0].disconnect(link[1], link[2])
		for watch in group.watches:
			if is_instance_valid(watch): watch.detach()
		_deactivate(group)
