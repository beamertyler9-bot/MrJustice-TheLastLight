extends SceneTree
## Creature remesher (offline tool; run headless with the scene paths as arguments).
##
## Enemy models were assembled from separate primitive shapes (body, head, brows, muzzle,
## limbs) that simply intersect, each with its own material. This rebuilds every rigid group
## of a model (the meshes that move with one joint) as ONE continuous, smoothly blended
## skin with ONE shared material:
##   1. each body part is voxelised and filled solid;
##   2. the union is blurred a little, so the parts melt into each other with soft fillets;
##   3. a surface-nets mesh is taken from it, with smooth normals from the field;
##   4. each vertex takes the colour of the part it came from, blended softly at the joins;
##   5. the mesh is simplified to a phone-friendly triangle budget;
##   6. one triplanar material (the creature's own texture and finish) covers every part.
## Thin or small details (eyes, teeth, spikes, horns, glowing cores) and anything the rig
## refers to are left as they are. Joints, rig bindings and metadata are untouched.
##
## Usage: Godot --headless --path . --script tools/creature_remesh.gd -- [--dry] path.scn ...

const ISO := 0.5
const COLOR_GAIN := 1.0
const GRID := 46            # cells along the longest side of a group
const MIN_VOXEL := 0.012
const DETAIL_THIN := 0.055   # parts thinner than this (m) stay as they are
const DETAIL_VOLUME := 0.004
const TRI_BUDGET_PER_M := 760.0   # triangles per metre of group size (clamped below)

var _texture_average: Dictionary = {}
var _hard := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dry := "--dry" in args
	for path in args:
		if path.begins_with("--"): continue
		var packed: PackedScene = load(path)
		var model: Node3D = packed.instantiate()
		root.add_child(model)
		await process_frame
		var report := remesh(model)
		await process_frame
		if not dry:
			for node in model.find_children("*", "", true, false): if node.owner == null and node != model: node.owner = model
			var out := PackedScene.new()
			var err := out.pack(model)
			if err == OK: err = ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
			report += " saved=%d" % err
		print("REMESH ", path.get_file(), " ", report)
		model.queue_free()
		await process_frame
	quit()


func _protected(model: Node3D) -> Dictionary:
	var keep := {}
	var rig = model.get_meta("rig_bindings", {})
	var stack: Array = [rig]
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is NodePath:
			var node := model.get_node_or_null(value)
			if node is MeshInstance3D: keep[node] = true
		elif value is Array: stack.append_array(value)
		elif value is Dictionary: stack.append_array(value.values())
	return keep


static func _material_of(mesh: MeshInstance3D) -> Material:
	if mesh.material_override: return mesh.material_override
	if mesh.mesh and mesh.mesh.get_surface_count() > 0:
		var surface := mesh.get_surface_override_material(0)
		return surface if surface else mesh.mesh.surface_get_material(0)
	return null


func _average(texture: Texture2D) -> Color:
	if texture == null: return Color.WHITE
	if _texture_average.has(texture): return _texture_average[texture]
	var image := texture.get_image()
	if image == null: return Color.WHITE
	if image.is_compressed(): image.decompress()
	image = image.duplicate(); image.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	var sum := Color(0, 0, 0, 0)
	for y in range(8):
		for x in range(8): sum += image.get_pixel(x, y)
	_texture_average[texture] = sum / 64.0
	return sum / 64.0


func _part_color(material: Material) -> Color:
	if material is StandardMaterial3D:
		var m: StandardMaterial3D = material
		var base := m.albedo_color
		if m.albedo_texture: base *= _average(m.albedo_texture)
		return Color(base.r, base.g, base.b, 1.0)
	return Color(0.7, 0.7, 0.7)


func _is_detail(mesh: MeshInstance3D, keep: Dictionary) -> bool:
	if keep.has(mesh) or mesh.mesh == null: return true
	if mesh.skin != null or mesh.get_parent() is Skeleton3D or not mesh.skeleton.is_empty() and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D: return true
	var material := _material_of(mesh)
	if material is StandardMaterial3D and (material.emission_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED): return true
	if not material is StandardMaterial3D: return true
	var size: Vector3 = (mesh.get_aabb().size * mesh.transform.basis.get_scale().abs())
	var thin := minf(size.x, minf(size.y, size.z))
	return thin < DETAIL_THIN or size.x * size.y * size.z < DETAIL_VOLUME


func remesh(model: Node3D) -> String:
	var keep := _protected(model)
	var groups := {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if _is_detail(mesh, keep): continue
		var owner_node: Node3D = mesh.get_parent()
		if not groups.has(owner_node): groups[owner_node] = []
		groups[owner_node].append(mesh)
	# One shared material for the whole creature, from its largest body part.
	var dominant: MeshInstance3D = null; var biggest := 0.0
	for g in groups:
		for mesh in groups[g]:
			var v: float = mesh.get_aabb().get_volume()
			if v > biggest: biggest = v; dominant = mesh
	if dominant == null: return "nothing to do"
	var source := _material_of(dominant)
	var family := ""
	if source is StandardMaterial3D:
		family = (str(source.resource_name) + " " + (source.albedo_texture.resource_path if source.albedo_texture else "")).to_lower()
	_hard = false
	for word in ["stone", "crystal", "metal", "rock", "glass", "iron", "steel"]:
		if family.contains(word): _hard = true
	# Built things (golems, knights, mimics, machines) keep crisp faces whatever their texture.
	var anatomy := str(model.get_meta("anatomy", ""))
	var species := str(model.get_meta("species", ""))
	var path := str(model.scene_file_path)
	# Built, faceted designs (and two with signature thin details) are kept exactly as built;
	# every other creature gets the single smooth skin.
	_hard = false
	for word in ["cliffwarden", "geode_mimic", "shard_sentinel", "wrapper_mimic", "thorn_wolf", "cinder_wisp", "dissonan", "boss_dungeon", "scrapper", "glass_skitter", "root_reaper"]:
		if species.contains(word) or path.contains(word): _hard = true
	if _hard: return "kept as built (hard-surfaced or signature detail)"
	var skin := _skin_material(source)
	var before := 0; var after := 0; var parts := 0
	for g in groups:
		var meshes: Array = groups[g]
		parts += meshes.size()
		for m in meshes: before += _tri_count(m.mesh)
		var built := _rebuild_group(g, meshes)
		if built.is_empty(): continue
		if built[0] != null:
			after += _tri_count(built[0])
			var node := MeshInstance3D.new(); node.name = "Skin"; node.mesh = built[0]; node.material_override = skin
			node.cast_shadow = (meshes[0] as MeshInstance3D).cast_shadow
			g.add_child(node)
			g.move_child(node, 0)
		if built[1] != null:
			after += _tri_count(built[1])
			var detail := MeshInstance3D.new(); detail.name = "Details"; detail.mesh = built[1]; detail.material_override = _detail_material()
			detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(detail)
		for m in meshes: m.get_parent().remove_child(m); m.free()
	return "groups=%d parts=%d tris %d -> %d %s [%s]" % [groups.size(), parts, before, after, "HARD" if _hard else "organic", family.get_slice(" ", 0) + " " + family.get_file()]


static func _tri_count(mesh: Mesh) -> int:
	var total := 0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var indices = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return total


func _skin_material(source: Material) -> StandardMaterial3D:
	# Clean colours with the shading baked into them: no wrapped texture.
	var m := StandardMaterial3D.new()
	m.resource_name = "Creature skin"
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.62
	m.metallic_specular = 0.45
	if source is StandardMaterial3D: m.metallic = minf(source.metallic, 0.3)
	return m


## Splits every mesh of a group into its connected islands (merged meshes hide eyes,
## teeth and spikes inside them). Returns [body_islands, detail_triangles], where each
## island is {tris: [[a,b,c,color]...], color}.
func _islands(meshes: Array) -> Array:
	var bodies: Array = []
	var details: Array = []
	for mesh in meshes:
		var material := _material_of(mesh)
		var tint := Color.WHITE
		var use_vertex := false
		if material is StandardMaterial3D:
			tint = material.albedo_color
			use_vertex = material.vertex_color_use_as_albedo
		var frame: Transform3D = mesh.transform
		for s in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vcol = arrays[Mesh.ARRAY_COLOR]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var indexed: bool = indices != null and indices.size() > 0
			var count: int = indices.size() if indexed else verts.size()
			# Weld by position, then union-find over triangles.
			var weld := {}
			var vid := PackedInt32Array(); vid.resize(verts.size())
			for i in range(verts.size()):
				var key := Vector3i(roundi(verts[i].x * 2000.0), roundi(verts[i].y * 2000.0), roundi(verts[i].z * 2000.0))
				if not weld.has(key): weld[key] = weld.size()
				vid[i] = weld[key]
			var parent := PackedInt32Array(); parent.resize(weld.size())
			for i in range(parent.size()): parent[i] = i
			var tri_list: Array = []
			for i in range(0, count, 3):
				var ia: int = indices[i] if indexed else i
				var ib: int = indices[i + 1] if indexed else i + 1
				var ic: int = indices[i + 2] if indexed else i + 2
				tri_list.append([ia, ib, ic])
				_union(parent, vid[ia], vid[ib]); _union(parent, vid[ib], vid[ic])
			var groups := {}
			for t in tri_list:
				var root_id := _find(parent, vid[t[0]])
				if not groups.has(root_id): groups[root_id] = []
				var color := tint
				if use_vertex and vcol != null and vcol.size() == verts.size():
					color = tint * ((vcol[t[0]] + vcol[t[1]] + vcol[t[2]]) / 3.0)
				groups[root_id].append([frame * verts[t[0]], frame * verts[t[1]], frame * verts[t[2]], Color(color.r, color.g, color.b, 1.0)])
			for key in groups:
				var tris: Array = groups[key]
				var box := AABB(tris[0][0], Vector3.ZERO)
				var sum := Color(0, 0, 0, 0)
				for t in tris:
					box = box.expand(t[0]).expand(t[1]).expand(t[2]); sum += t[3]
				var thin := minf(box.size.x, minf(box.size.y, box.size.z))
				if thin < DETAIL_THIN or box.get_volume() < DETAIL_VOLUME or tris.size() < 6:
					details.append_array(tris)
				else:
					bodies.append({"tris": tris, "color": sum / tris.size()})
	return [bodies, details]


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]; i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a); var rb := _find(parent, b)
	if ra != rb: parent[ra] = rb


var _detail: StandardMaterial3D
func _detail_material() -> StandardMaterial3D:
	if _detail == null:
		_detail = StandardMaterial3D.new(); _detail.resource_name = "Creature details"
		_detail.vertex_color_use_as_albedo = true; _detail.roughness = 0.4; _detail.metallic_specular = 0.6
	return _detail


func _rebuild_group(group: Node3D, meshes: Array) -> Array:
	var split := _islands(meshes)
	var bodies: Array = split[0]
	var details: Array = split[1]
	if bodies.is_empty(): return []
	var box := AABB(); var first := true
	for island in bodies:
		for t in island.tris:
			if first: box = AABB(t[0], Vector3.ZERO); first = false
			box = box.expand(t[0]).expand(t[1]).expand(t[2])
	var voxel := maxf(MIN_VOXEL, maxf(box.size.x, maxf(box.size.y, box.size.z)) / (GRID * (1.3 if _hard else 1.0)))
	# Anything too thin to survive the blend stays exactly as it was.
	var kept: Array = []
	for island in bodies:
		var ib := AABB(island.tris[0][0], Vector3.ZERO)
		for t in island.tris: ib = ib.expand(t[0]).expand(t[1]).expand(t[2])
		var lo := minf(ib.size.x, minf(ib.size.y, ib.size.z)); var hi := maxf(ib.size.x, maxf(ib.size.y, ib.size.z))
		# Too thin to survive the blend, or long and pointed (spikes, horns, blades).
		if lo < voxel * 3.5 or (hi / maxf(lo, 0.001) > 3.2 and lo < 0.18): details.append_array(island.tris)
		else: kept.append(island)
	bodies = kept
	if bodies.is_empty():
		if details.is_empty(): return []
		var only := SurfaceTool.new(); only.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in details:
			only.set_color(t[3]); only.add_vertex(t[0]); only.add_vertex(t[1]); only.add_vertex(t[2])
		only.generate_normals()
		return [null, only.commit()]
	var pad := 5
	var origin := box.position - Vector3.ONE * voxel * pad
	var nx := int(ceil(box.size.x / voxel)) + pad * 2 + 1
	var ny := int(ceil(box.size.y / voxel)) + pad * 2 + 1
	var nz := int(ceil(box.size.z / voxel)) + pad * 2 + 1
	var total := nx * ny * nz
	var occupancy := PackedFloat32Array(); occupancy.resize(total)
	var color_grid := PackedColorArray(); color_grid.resize(total)
	var has_color := PackedByteArray(); has_color.resize(total)
	# 1. Each island is filled solid on its own; surface voxels carry the triangle's colour.
	for island in bodies:
		var shell := PackedByteArray(); shell.resize(total)
		var lo := Vector3i(nx, ny, nz); var hi := Vector3i(0, 0, 0)
		for t in island.tris:
			var a: Vector3 = (t[0] - origin) / voxel; var b: Vector3 = (t[1] - origin) / voxel; var c: Vector3 = (t[2] - origin) / voxel
			var steps := int(ceil(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) * 2.0)) + 1
			for u in range(steps + 1):
				for v in range(steps + 1 - u):
					var q: Vector3 = a + (b - a) * (float(u) / steps) + (c - a) * (float(v) / steps)
					var x := clampi(int(q.x), 0, nx - 1); var y := clampi(int(q.y), 0, ny - 1); var z := clampi(int(q.z), 0, nz - 1)
					var i := x + nx * (y + ny * z)
					shell[i] = 1
					color_grid[i] = t[3]; has_color[i] = 1
					lo = Vector3i(mini(lo.x, x), mini(lo.y, y), mini(lo.z, z)); hi = Vector3i(maxi(hi.x, x), maxi(hi.y, y), maxi(hi.z, z))
		lo -= Vector3i.ONE; hi += Vector3i.ONE
		lo = Vector3i(maxi(lo.x, 0), maxi(lo.y, 0), maxi(lo.z, 0)); hi = Vector3i(mini(hi.x, nx - 1), mini(hi.y, ny - 1), mini(hi.z, nz - 1))
		var outside := PackedByteArray(); outside.resize(total)
		var queue := PackedInt32Array()
		for z in range(lo.z, hi.z + 1):
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					if x == lo.x or x == hi.x or y == lo.y or y == hi.y or z == lo.z or z == hi.z:
						var i := x + nx * (y + ny * z)
						if shell[i] == 0 and outside[i] == 0: outside[i] = 1; queue.append(i)
		var head := 0
		while head < queue.size():
			var i := queue[head]; head += 1
			var x := i % nx; var y := (i / nx) % ny; var z := i / (nx * ny)
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var X: int = x + d.x; var Y: int = y + d.y; var Z: int = z + d.z
				if X < lo.x or Y < lo.y or Z < lo.z or X > hi.x or Y > hi.y or Z > hi.z: continue
				var j := X + nx * (Y + ny * Z)
				if shell[j] == 0 and outside[j] == 0: outside[j] = 1; queue.append(j)
		for z in range(lo.z, hi.z + 1):
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var i := x + nx * (y + ny * z)
					if outside[i] == 0:
						occupancy[i] = 1.0
						if has_color[i] == 0: color_grid[i] = island.color; has_color[i] = 2
	# 2. Soften so the parts melt together.
	var field := occupancy
	for pass_i in range(1 if _hard else 3): field = _blur(field, nx, ny, nz)
	# 3. Surface nets.
	var cell_vertex := PackedInt32Array(); cell_vertex.resize(total); cell_vertex.fill(-1)
	var positions := PackedVector3Array(); var normals := PackedVector3Array(); var vcolors := PackedColorArray()
	var corner_offsets := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for z in range(nz - 1):
		for y in range(ny - 1):
			for x in range(nx - 1):
				var values := []
				var mask := 0
				for k in range(8):
					var o: Vector3i = corner_offsets[k]
					var value: float = field[(x + o.x) + nx * ((y + o.y) + ny * (z + o.z))]
					values.append(value)
					if value > ISO: mask |= 1 << k
				if mask == 0 or mask == 255: continue
				var sum := Vector3.ZERO; var crossings := 0
				for e in edges:
					var va: float = values[e[0]]; var vb: float = values[e[1]]
					if (va > ISO) == (vb > ISO): continue
					var t := (ISO - va) / (vb - va)
					sum += Vector3(corner_offsets[e[0]]).lerp(Vector3(corner_offsets[e[1]]), t); crossings += 1
				var grid_point := Vector3(x, y, z) + sum / crossings
				cell_vertex[x + nx * (y + ny * z)] = positions.size()
				positions.append(origin + grid_point * voxel)
				normals.append(-_gradient(field, nx, ny, nz, grid_point).normalized())
				vcolors.append(_blend_color(color_grid, has_color, nx, ny, nz, grid_point))
	var indices := PackedInt32Array()
	for z in range(1, nz - 1):
		for y in range(1, ny - 1):
			for x in range(1, nx - 1):
				var here := field[x + nx * (y + ny * z)] > ISO
				if x < nx - 1 and (field[(x + 1) + nx * (y + ny * z)] > ISO) != here:
					_quad(indices, cell_vertex, nx, ny, Vector3i(x, y - 1, z - 1), Vector3i(x, y, z - 1), Vector3i(x, y, z), Vector3i(x, y - 1, z), here)
				if y < ny - 1 and (field[x + nx * ((y + 1) + ny * z)] > ISO) != here:
					_quad(indices, cell_vertex, nx, ny, Vector3i(x - 1, y, z - 1), Vector3i(x - 1, y, z), Vector3i(x, y, z), Vector3i(x, y, z - 1), here)
				if z < nz - 1 and (field[x + nx * (y + ny * (z + 1))] > ISO) != here:
					_quad(indices, cell_vertex, nx, ny, Vector3i(x - 1, y - 1, z), Vector3i(x, y - 1, z), Vector3i(x, y, z), Vector3i(x - 1, y, z), here)
	if indices.is_empty(): return []
	# Soft painted shading: a lighter back, a darker belly and underside, a little variation.
	for i in range(vcolors.size()):
		var n := normals[i]
		var up := clampf(n.y * 0.5 + 0.5, 0.0, 1.0)
		var height := clampf((positions[i].y - box.position.y) / maxf(box.size.y, 0.01), 0.0, 1.0)
		var grain := (sin(positions[i].x * 37.0) * sin(positions[i].z * 29.0 + positions[i].y * 23.0)) * 0.035
		var light := lerpf(0.74, 1.12, up) * lerpf(0.9, 1.04, height) + grain
		var c := vcolors[i] * light
		vcolors[i] = Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), 1.0)
	positions = _smooth(positions, indices, 1 if _hard else 6)
	# 5. Simplify to the budget.
	var size := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var budget := int(clampf(size * TRI_BUDGET_PER_M, 120.0, 1300.0))
	var simplified := _simplify(positions, normals, vcolors, indices, budget)
	var result := ArrayMesh.new()
	if _hard:
		# Stone, crystal and metal keep crisp, faceted faces.
		var flat := SurfaceTool.new(); flat.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sp: PackedVector3Array = simplified[Mesh.ARRAY_VERTEX]; var sc: PackedColorArray = simplified[Mesh.ARRAY_COLOR]; var si: PackedInt32Array = simplified[Mesh.ARRAY_INDEX]
		for i in si:
			flat.set_color(sc[i]); flat.add_vertex(sp[i])
		flat.generate_normals()
		result = flat.commit()
	else:
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, simplified)
	if not details.is_empty():
		# Crisp details join the skin in the same surface: one draw for the whole part.
		var arrays: Array = result.surface_get_arrays(0)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			for i in range(pos.size()): idx.append(i)
		for t in details:
			var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
			var base := pos.size()
			for k in range(3):
				pos.append(t[k]); nor.append(-n); col.append(t[3])
			idx.append_array(PackedInt32Array([base, base + 1, base + 2]))
		arrays[Mesh.ARRAY_VERTEX] = pos; arrays[Mesh.ARRAY_NORMAL] = nor; arrays[Mesh.ARRAY_COLOR] = col; arrays[Mesh.ARRAY_INDEX] = idx
		result = ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [result, null]


## Laplacian smoothing (vertex moves toward the average of its neighbours).
static func _smooth(positions: PackedVector3Array, indices: PackedInt32Array, rounds: int) -> PackedVector3Array:
	var neighbours: Array = []; neighbours.resize(positions.size())
	for i in range(positions.size()): neighbours[i] = {}
	for i in range(0, indices.size(), 3):
		var a := indices[i]; var b := indices[i + 1]; var c := indices[i + 2]
		neighbours[a][b] = true; neighbours[a][c] = true; neighbours[b][a] = true; neighbours[b][c] = true; neighbours[c][a] = true; neighbours[c][b] = true
	var current := positions
	for r in range(rounds):
		var next := current.duplicate()
		for i in range(current.size()):
			var n: Dictionary = neighbours[i]
			if n.is_empty(): continue
			var sum := Vector3.ZERO
			for j in n: sum += current[j]
			next[i] = current[i].lerp(sum / n.size(), 0.5 if r % 2 == 0 else -0.25 if false else 0.5)
		current = next
	return current


func _simplify(positions: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, budget: int) -> Array:
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	var best := indices
	var count := importer.get_surface_lod_count(0)
	for lod in range(count):
		var candidate := importer.get_surface_lod_indices(0, lod)
		best = candidate
		if candidate.size() / 3 <= budget: break
	print("    lods=%d tris %d -> %d (budget %d)" % [count, indices.size() / 3, best.size() / 3, budget])
	# Keep only the vertices the simplified mesh still uses.
	var remap := {}
	var kept_positions := PackedVector3Array(); var kept_normals := PackedVector3Array(); var kept_colors := PackedColorArray()
	var compact := PackedInt32Array(); compact.resize(best.size())
	for i in range(best.size()):
		var old := best[i]
		if not remap.has(old):
			remap[old] = kept_positions.size()
			kept_positions.append(positions[old]); kept_normals.append(normals[old]); kept_colors.append(colors[old])
		compact[i] = remap[old]
	arrays[Mesh.ARRAY_VERTEX] = kept_positions; arrays[Mesh.ARRAY_NORMAL] = kept_normals; arrays[Mesh.ARRAY_COLOR] = kept_colors
	arrays[Mesh.ARRAY_INDEX] = compact
	return arrays


static func _quad(indices: PackedInt32Array, cell_vertex: PackedInt32Array, nx: int, ny: int, a: Vector3i, b: Vector3i, c: Vector3i, d: Vector3i, flip: bool) -> void:
	var ia := cell_vertex[a.x + nx * (a.y + ny * a.z)]; var ib := cell_vertex[b.x + nx * (b.y + ny * b.z)]
	var ic := cell_vertex[c.x + nx * (c.y + ny * c.z)]; var id := cell_vertex[d.x + nx * (d.y + ny * d.z)]
	if ia < 0 or ib < 0 or ic < 0 or id < 0: return
	if flip: indices.append_array(PackedInt32Array([ia, ib, ic, ia, ic, id]))
	else: indices.append_array(PackedInt32Array([ia, ic, ib, ia, id, ic]))


static func _blur(source: PackedFloat32Array, nx: int, ny: int, nz: int) -> PackedFloat32Array:
	var a := source
	for axis in range(3):
		var b := PackedFloat32Array(); b.resize(a.size())
		var step: int = [1, nx, nx * ny][axis]
		var limit: int = [nx, ny, nz][axis]
		for i in range(a.size()):
			var coord: int = [i % nx, (i / nx) % ny, i / (nx * ny)][axis]
			var left: float = a[i - step] if coord > 0 else a[i]
			var right: float = a[i + step] if coord < limit - 1 else a[i]
			b[i] = (left + a[i] * 2.0 + right) * 0.25
		a = b
	return a


static func _spread_labels(label: PackedInt32Array, nx: int, ny: int, nz: int, rounds: int) -> PackedInt32Array:
	var current := label
	for r in range(rounds):
		var next := current.duplicate()
		for i in range(current.size()):
			if current[i] >= 0: continue
			var x := i % nx; var y := (i / nx) % ny; var z := i / (nx * ny)
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var X: int = x + d.x; var Y: int = y + d.y; var Z: int = z + d.z
				if X < 0 or Y < 0 or Z < 0 or X >= nx or Y >= ny or Z >= nz: continue
				var v := current[X + nx * (Y + ny * Z)]
				if v >= 0: next[i] = v; break
		current = next
	return current


static func _sample(field: PackedFloat32Array, nx: int, ny: int, nz: int, x: int, y: int, z: int) -> float:
	return field[clampi(x, 0, nx - 1) + nx * (clampi(y, 0, ny - 1) + ny * clampi(z, 0, nz - 1))]


static func _gradient(field: PackedFloat32Array, nx: int, ny: int, nz: int, p: Vector3) -> Vector3:
	var x := int(round(p.x)); var y := int(round(p.y)); var z := int(round(p.z))
	return Vector3(
		_sample(field, nx, ny, nz, x + 1, y, z) - _sample(field, nx, ny, nz, x - 1, y, z),
		_sample(field, nx, ny, nz, x, y + 1, z) - _sample(field, nx, ny, nz, x, y - 1, z),
		_sample(field, nx, ny, nz, x, y, z + 1) - _sample(field, nx, ny, nz, x, y, z - 1)) + Vector3(0, 1e-5, 0)


static func _blend_color(grid: PackedColorArray, has: PackedByteArray, nx: int, ny: int, nz: int, p: Vector3) -> Color:
	var sum := Color(0, 0, 0, 0); var weight := 0.0
	var cx := int(round(p.x)); var cy := int(round(p.y)); var cz := int(round(p.z))
	for dz in range(-2, 3):
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var x := clampi(cx + dx, 0, nx - 1); var y := clampi(cy + dy, 0, ny - 1); var z := clampi(cz + dz, 0, nz - 1)
				var i := x + nx * (y + ny * z)
				if has[i] == 0: continue
				var w := (2.0 if has[i] == 1 else 0.5) / (1.0 + dx * dx + dy * dy + dz * dz)
				sum += grid[i] * w; weight += w
	if weight <= 0.0: return Color(0.6, 0.6, 0.6)
	var c := sum / weight * COLOR_GAIN
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 1.0)
