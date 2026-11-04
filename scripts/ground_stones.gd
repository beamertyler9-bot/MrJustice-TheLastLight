extends Node3D

const B = preload("res://scripts/build.gd")
var world
var chunk: Node3D
var batch: MultiMeshInstance3D
var frames: Array[Transform3D] = []
var proxies: Dictionary = {}
var ids: Array[String] = []
var cells: Dictionary = {}
const CELL_SIZE = 6.0
const POCKET_MAX_SIZE = 0.45
static func build(owner_world, owner_chunk: Node3D, transforms: Array[Transform3D], shape: Mesh, material: Material, stable_ids: Array = []):
	var art = load("res://scripts/ground_stones.gd").new(); art.world = owner_world; art.chunk = owner_chunk; art.frames = transforms.duplicate(); art.name = "CollectableGroundStones"; owner_chunk.add_child(art)
	B.instances(art, transforms, shape, material)
	if not transforms.is_empty():
		art.batch = art.get_child(0); art.batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; art.batch.extra_cull_margin = 0.22
		art.batch.add_to_group("world_detail"); art.batch.visibility_range_end = [50.0, 65.0, 85.0][clampi(int(owner_world.state.settings.quality), 0, 2)]; art.batch.visibility_range_end_margin = 6
	var key = Vector2i(floori(owner_chunk.global_position.x / 48), floori(owner_chunk.global_position.z / 48))
	for i in range(transforms.size()):
		var frame = transforms[i]
		art.ids.append(str(stable_ids[i]) if i < stable_ids.size() and not str(stable_ids[i]).is_empty() else "ground_stone_%d_%d_%d_%d" % [key.x, key.y, roundi(frame.origin.x * 256), roundi(frame.origin.z * 256)])
		var cell = Vector2i(floori(frame.origin.x / CELL_SIZE), floori(frame.origin.z / CELL_SIZE))
		if not art.cells.has(cell): art.cells[cell] = []
		art.cells[cell].append(i)
	art.add_to_group("ground_stone_batches"); art.set_process(false)
	for i in range(art.ids.size()):
		if owner_world.state.taken.has(art.ids[i]): art._hide(i)
	return art
func _hide(index: int) -> void:
	if is_instance_valid(batch):
		var hidden = Transform3D(Basis.from_scale(Vector3.ONE * 1.0e-06), Vector3.ZERO)
		batch.multimesh.set_instance_transform(index, hidden)
		batch.get_meta("instance_transforms")[index] = hidden
	if proxies.has(index):
		var proxy = proxies[index]; proxies.erase(index)
		if is_instance_valid(proxy): proxy.queue_free()
func sync_near(point: Vector3) -> void:
	for index in proxies.keys():
		if world.state.taken.has(ids[index]): _hide(index)
		elif not is_instance_valid(proxies[index]) or proxies[index].global_position.distance_squared_to(point) > 25:
			var old = proxies[index]; proxies.erase(index)
			if is_instance_valid(old): old.queue_free()
	if chunk.global_position.distance_squared_to(Vector3(point.x, chunk.global_position.y, point.z)) > 120 * 120: return
	for i in nearby_frames(point):
		if proxies.has(i) or world.state.taken.has(ids[i]): continue
		var at = to_global(frames[i].origin)
		if at.distance_squared_to(point) > 20.25: continue


		var dimensions = batch.multimesh.mesh.get_aabb().size * (global_transform * frames[i]).basis.get_scale().abs()
		var large = maxf(dimensions.x, maxf(dimensions.y, dimensions.z)) > POCKET_MAX_SIZE
		var proxy = load("res://scripts/mineable.gd").new() if large else Node3D.new()
		if large: proxy.world = world
		proxy.name = ("MineableGroundRock" if large else "PocketStone") + str(i); proxy.position = frames[i].origin
		proxy.set_meta("kind", "rock" if large else "material"); proxy.set_meta("item", "stone"); proxy.set_meta("amount", 3 if large else 1); proxy.set_meta("id", ids[i]); proxy.set_meta("label", "Mine stone" if large else "Pick up stone"); proxy.set_meta("loose_stone", not large)
		proxy.set_meta("ground_stone_art", weakref(self)); proxy.set_meta("ground_stone_index", i)
		add_child(proxy)
		if large:
			var bounds = Transform3D(frames[i].basis, Vector3.ZERO) * batch.multimesh.mesh.get_aabb()
			var shape = BoxShape3D.new(); shape.size = bounds.size.max(Vector3.ONE * 0.05)
			proxy.collider = B.solid(proxy, bounds.get_center(), shape)
		proxy.add_to_group("interactable"); proxies[i] = proxy
		proxy.tree_exiting.connect(_retire_proxy.bind(i), CONNECT_ONE_SHOT)
func nearby_frames(point: Vector3) -> Array:


	var bounds = global_transform.affine_inverse() * AABB(point - Vector3.ONE * 4.5, Vector3.ONE * 9.0)
	var result = []
	for x in range(floori(bounds.position.x / CELL_SIZE), floori(bounds.end.x / CELL_SIZE) + 1):
		for z in range(floori(bounds.position.z / CELL_SIZE), floori(bounds.end.z / CELL_SIZE) + 1):
			result.append_array(cells.get(Vector2i(x, z), []))
	return result
func _retire_proxy(index: int) -> void:
	proxies.erase(index)
	if is_instance_valid(world) and world.state.taken.has(ids[index]): _hide(index)
