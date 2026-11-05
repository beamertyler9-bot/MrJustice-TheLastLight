extends RefCounted
## Natural cave dressing, laid over the whole cave once its rock shell is built.
##
## Everywhere: stalactites hang from the ceiling (kept well above head height), stalagmite
## clusters and boulders crowd the foot of the walls so the walls stop reading as smooth
## sheets, all in the same world-projected rock as the walls.
## Each region then grows its own life:
##   9  valley    glowing teal mushrooms, moss
##   10 sweets    candy crystals, chocolate drips
##   11 plains    glowing mushrooms, moss, small blue crystals
##   12 desert    sand drifts, old skulls
##   13 volcanic  lava cracks and lava pools
##   14 haunted   ghost-blue mushrooms, drifting wisps, skulls, lichen
##   15 crystal   big glowing crystal clusters
## A few glowing features also cast a soft coloured light.

const B = preload("res://scripts/build.gd")
const S = preload("res://scripts/region_sites.gd")
const Shell = preload("res://scripts/interior_surfaces.gd")
const Architecture = preload("res://scripts/interior_architecture.gd")
const A = preload("res://scripts/imported_assets.gd")
const GLOW = preload("res://shaders/cave_glow.gdshader")
const MAX_LIGHTS := 5

static var _spike: ArrayMesh
static var _boulder: ArrayMesh
static var _crystal: ArrayMesh
static var _cap: SphereMesh
static var _stem: CylinderMesh
static var _orb: SphereMesh
static var _pool: CylinderMesh
static var _glows: Dictionary = {}


static func glow(color: String, core: String, energy: float = 1.2, mode: int = 0) -> ShaderMaterial:
	var key := "%s:%s:%.2f:%d" % [color, core, energy, mode]
	if not _glows.has(key):
		var material := ShaderMaterial.new(); material.shader = GLOW
		material.set_shader_parameter("glow_color", Color(color)); material.set_shader_parameter("core_color", Color(core))
		material.set_shader_parameter("energy", energy); material.set_shader_parameter("mode", mode)
		_glows[key] = material
	return _glows[key]


static func _meshes() -> void:
	if _spike != null: return
	# A rough, slightly twisted cone (base at y=0, tip at y=1).
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_smooth_group(-1)
	var rings := [[0.0, 1.0], [0.28, 0.72], [0.6, 0.4], [0.86, 0.15]]
	var sides := 7
	var ring_points: Array = []
	for r in range(rings.size()):
		var row: Array = []
		for i in range(sides):
			var a := float(i) / float(sides) * TAU + float(r) * 0.35
			var wobble := 1.0 + 0.16 * sin(float(i) * 2.7 + float(r) * 1.9)
			row.append(Vector3(cos(a), 0.0, sin(a)) * float(rings[r][1]) * wobble + Vector3(0.0, float(rings[r][0]), 0.0))
		ring_points.append(row)
	for r in range(rings.size() - 1):
		for i in range(sides):
			var j := (i + 1) % sides
			var a0: Vector3 = ring_points[r][i]; var a1: Vector3 = ring_points[r][j]
			var b0: Vector3 = ring_points[r + 1][i]; var b1: Vector3 = ring_points[r + 1][j]
			for v in [a0, b0, a1, a1, b0, b1]: st.add_vertex(v)
	var tip := Vector3(0.04, 1.0, -0.03)
	for i in range(sides):
		var j := (i + 1) % sides
		for v in [ring_points[rings.size() - 1][i], tip, ring_points[rings.size() - 1][j]]: st.add_vertex(v)
	st.generate_normals(); _spike = st.commit()

	# A lumpy, faceted boulder with a flattened underside.
	var sphere := SphereMesh.new(); sphere.radial_segments = 9; sphere.rings = 6; sphere.radius = 0.5; sphere.height = 1.0
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var shaped := PackedVector3Array()
	for v in verts:
		var d := v.normalized() if v.length() > 0.001 else Vector3.UP
		var bump := 0.82 + 0.16 * sin(d.x * 5.1 + d.z * 3.3) + 0.1 * sin(d.y * 7.3 - d.x * 4.1)
		var p := d * 0.5 * bump
		p.y = maxf(p.y, -0.18)
		shaped.append(p)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_smooth_group(-1)
	for i in index: st.add_vertex(shaped[i])
	st.generate_normals(); _boulder = st.commit()

	# A hexagonal crystal with a pointed tip.
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_smooth_group(-1)
	for i in range(6):
		var a := float(i) / 6.0 * TAU; var b := float(i + 1) / 6.0 * TAU
		var p0 := Vector3(cos(a), 0.0, sin(a)) * 0.5; var p1 := Vector3(cos(b), 0.0, sin(b)) * 0.5
		var q0 := Vector3(cos(a), 0.0, sin(a)) * 0.44 + Vector3.UP * 0.72; var q1 := Vector3(cos(b), 0.0, sin(b)) * 0.44 + Vector3.UP * 0.72
		for v in [p0, q0, p1, p1, q0, q1, q0, Vector3(0.03, 1.0, 0.0), q1]: st.add_vertex(v)
	st.generate_normals(); _crystal = st.commit()

	_cap = SphereMesh.new(); _cap.is_hemisphere = true; _cap.radius = 0.5; _cap.height = 0.5; _cap.radial_segments = 10; _cap.rings = 3
	_stem = CylinderMesh.new(); _stem.top_radius = 0.06; _stem.bottom_radius = 0.09; _stem.height = 1.0; _stem.radial_segments = 6; _stem.rings = 1
	_orb = SphereMesh.new(); _orb.radius = 0.5; _orb.height = 1.0; _orb.radial_segments = 8; _orb.rings = 4
	_pool = CylinderMesh.new(); _pool.top_radius = 0.5; _pool.bottom_radius = 0.5; _pool.height = 0.02; _pool.radial_segments = 14; _pool.rings = 1


static func _tilt(rng: RandomNumberGenerator, amount: float) -> Basis:
	return Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-amount, amount)) * Basis(Vector3.BACK, rng.randf_range(-amount, amount))


static func dress(live: Node3D, id: String, record: Dictionary) -> void:
	_meshes()
	var region := int(record.region)
	var cells: Dictionary = S.cells(id)
	var step: float = S.STEP
	var floor_at := func (p: Vector2) -> float: return S.floor_height(id, p)
	var height_at := func (p: Vector2) -> float: return S.ceiling_height(id, p)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("cave-dressing:" + id)
	var rock: Material = Architecture.stone(region, false, false, true)
	var plan: Dictionary = S.layout(id)
	# Keep the way in, the way out and the treasure clear.
	var clear: Array[Vector2] = [Vector2(0, 4), Vector2(0, 6)]
	if not plan.rooms.is_empty(): clear.append((plan.rooms.back().p as Vector2) + Vector2(0, 1.5))
	for room in plan.rooms: clear.append(room.p)
	var hanging: Array[Transform3D] = []; var rising: Array[Transform3D] = []; var boulders: Array[Transform3D] = []
	var moss: Array[Transform3D] = []; var stems: Array[Transform3D] = []; var caps: Array[Transform3D] = []
	var crystals: Array = []; var wisps: Array[Transform3D] = []; var pools: Array[Transform3D] = []
	var lights: Array = []
	var drip_material: Material = rock
	if region == 10: drip_material = B.mat("#6a3d27", 0.15)
	var moss_color: String = {9: "#4e6b33", 11: "#5d7c3a", 14: "#6d7a69", 12: "#d6b47e"}.get(region, "")
	var cap_color: Array = {9: ["#3fe0c0", "#c8fff4"], 11: ["#7fe36b", "#efffd8"], 14: ["#7fb6ff", "#e2f0ff"]}.get(region, [])
	var crystal_colors: Array = {15: [["#a879ff", "#f1e3ff"], ["#56d6ff", "#e3fbff"], ["#ff86d0", "#ffe6f6"]], 11: [["#6fc4ff", "#e6f7ff"]], 10: [["#ff8fc0", "#ffe9f3"], ["#8fe8c8", "#effff8"], ["#e0a35a", "#fff1d8"]]}.get(region, [])
	var cells_sorted: Array = cells.keys()
	cells_sorted.sort()
	for cell in cells_sorted:
		var center := (Vector2(cell) + Vector2.ONE * 0.5) * step
		var blocked := false
		for spot in clear:
			if center.distance_to(spot) < 3.2:
				blocked = true
				break
		var wall := Vector2.ZERO
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(cell + d): wall += Vector2(d)
		var edge := wall != Vector2.ZERO
		if edge: wall = wall.normalized()
		var floor_y: float = floor_at.call(center)
		# Stalactites anywhere the roof is high enough to keep them above Mr. Justice's head.
		if rng.randf() < 0.2:
			for k in range(rng.randi_range(1, 3)):
				var at := center + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
				var roof: float = Shell.ceiling_at(cells, step, floor_at, height_at, true, at)
				var room_height: float = roof - float(floor_at.call(at))
				if room_height < 3.3: continue
				var length := rng.randf_range(0.45, minf(2.1, room_height - 2.55))
				var width := length * rng.randf_range(0.18, 0.28)
				var basis := Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, rng.randf() * TAU)
				hanging.append(Transform3D(basis.scaled(Vector3(width, length, width)), Vector3(at.x, roof + 0.12, at.y)))
		if not edge or blocked:
			# Open floor: the odd lava crack, wisp or puddle.
			if region == 13 and rng.randf() < 0.07 and not blocked: _lava_crack(live, rng, center, floor_at)
			if region == 14 and rng.randf() < 0.05:
				wisps.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.07, 0.12)), Vector3(center.x, floor_y + rng.randf_range(1.3, 2.4), center.y)))
			continue
		var base := center + wall * 0.45
		var roll := rng.randf()
		if roll < 0.34:
			var size := rng.randf_range(0.8, 1.8)
			var at := base + wall * 0.25 + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
			boulders.append(Transform3D(_tilt(rng, 0.25).scaled(Vector3(size * rng.randf_range(0.9, 1.3), size * rng.randf_range(0.6, 0.9), size)), Vector3(at.x, float(floor_at.call(at)) - size * 0.08, at.y)))
		elif roll < 0.56:
			for k in range(rng.randi_range(1, 3)):
				var at := base + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
				var height := rng.randf_range(0.5, 2.0) * (1.0 if k == 0 else 0.55)
				var width := height * rng.randf_range(0.22, 0.32)
				var y: float = floor_at.call(at) - 0.08
				rising.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width)), Vector3(at.x, y, at.y)))
				if k == 0 and height > 1.0:
					var shape := CylinderShape3D.new(); shape.radius = width * 0.75; shape.height = height
					B.solid(live, Vector3(at.x, y + height * 0.5, at.y), shape)
		# Moss / lichen / sand gathers along the foot of the walls.
		if moss_color != "" and rng.randf() < 0.4:
			var at := base + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
			var spread := rng.randf_range(0.9, 1.7)
			var tall := 0.28 if region == 12 else 0.05
			moss.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(spread, tall, spread * rng.randf_range(0.6, 1.0))), Vector3(at.x, float(floor_at.call(at)) + 0.01, at.y)))
		# Glowing mushrooms.
		if not cap_color.is_empty() and rng.randf() < 0.22:
			var cluster := base - wall * 0.15
			for k in range(rng.randi_range(3, 6)):
				var at := cluster + Vector2(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.55, 0.55))
				var tall := rng.randf_range(0.14, 0.5); var cap := tall * rng.randf_range(0.5, 0.85)
				var y: float = floor_at.call(at)
				stems.append(Transform3D(Basis.from_scale(Vector3(cap * 0.9, tall, cap * 0.9)), Vector3(at.x, y + tall * 0.5, at.y)))
				caps.append(Transform3D(_tilt(rng, 0.2).scaled(Vector3(cap, cap * 0.8, cap)), Vector3(at.x, y + tall - cap * 0.05, at.y)))
			if lights.size() < MAX_LIGHTS and rng.randf() < 0.5: lights.append([Vector3(cluster.x, floor_y + 0.8, cluster.y), cap_color[0]])
		# Crystal clusters.
		if not crystal_colors.is_empty() and rng.randf() < (0.45 if region == 15 else 0.24 if region == 10 else 0.06):
			var palette: Array = crystal_colors[rng.randi() % crystal_colors.size()]
			var cluster := base + wall * 0.1
			var big := (2.6 if rng.randf() < 0.3 else 1.7) if region == 15 else 0.9
			for k in range(rng.randi_range(4, 7)):
				var at := cluster + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))
				var tall := rng.randf_range(0.4, 1.4) * big * (1.0 if k == 0 else 0.6)
				var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
				var transform := Transform3D(lean.scaled(Vector3(tall * 0.32, tall, tall * 0.32)), Vector3(at.x, float(floor_at.call(at)) - 0.05, at.y))
				crystals.append([transform, palette])
			if lights.size() < MAX_LIGHTS and region != 10 and rng.randf() < 0.6: lights.append([Vector3(cluster.x, floor_y + 1.0, cluster.y), palette[0]])
		# Lava pools (volcanic) and skulls (desert, haunted).
		if region == 13 and rng.randf() < 0.1:
			var at := base - wall * 0.35
			var size := rng.randf_range(0.9, 1.6)
			pools.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, 1.0, size * rng.randf_range(0.6, 1.0))), Vector3(at.x, float(floor_at.call(at)) + 0.03, at.y)))
			if lights.size() < MAX_LIGHTS: lights.append([Vector3(at.x, floor_y + 0.7, at.y), "#ff6a24"])
		if region in [12, 14] and rng.randf() < 0.07:
			var at := base - wall * 0.2
			A.place(live, "ruin_skull", Vector3(at.x, float(floor_at.call(at)), at.y), rng.randf_range(0.28, 0.4), rng.randf() * TAU)
	# One batch per kind of thing.
	B.instances(live, hanging, _spike, drip_material)
	B.instances(live, rising, _spike, drip_material)
	B.instances(live, boulders, _boulder, rock)
	if moss_color != "": B.instances(live, moss, _boulder, B.mat(moss_color))
	if not cap_color.is_empty():
		B.instances(live, stems, _stem, B.mat("#d9d2bd"))
		B.instances(live, caps, _cap, glow(cap_color[0], cap_color[1], 1.15))
	var by_palette: Dictionary = {}
	for entry in crystals:
		var key: String = entry[1][0]
		if not by_palette.has(key): by_palette[key] = {"palette": entry[1], "transforms": [] as Array[Transform3D]}
		by_palette[key].transforms.append(entry[0])
	for key in by_palette:
		var palette: Array = by_palette[key].palette
		var material: Material = B.mat(palette[0], 0.2) if region == 10 else glow(palette[0], palette[1], 1.05)
		B.instances(live, by_palette[key].transforms, _crystal, material)
	B.instances(live, wisps, _orb, glow("#7fc8ff", "#e6f6ff", 1.3, 2))
	B.instances(live, pools, _pool, glow("#ff5a1a", "#ffd27a", 1.4, 1))
	for light in lights:
		var lamp := OmniLight3D.new(); lamp.name = "CaveGlow"
		lamp.position = light[0]; lamp.light_color = Color(light[1]); lamp.light_energy = 0.9; lamp.omni_range = 7.0
		lamp.shadow_enabled = false; lamp.distance_fade_enabled = true; lamp.distance_fade_begin = 22.0; lamp.distance_fade_length = 8.0
		live.add_child(lamp)
	# Lit by ambient, glows and lanterns only: no stray sun shadows underground.
	for child in live.get_children():
		if child is MultiMeshInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	live.set_meta("cave_dressing", {"stalactites": hanging.size(), "stalagmites": rising.size(), "boulders": boulders.size(), "glows": lights.size()})


## A glowing crack of lava wandering across the cave floor.
static func _lava_crack(live: Node3D, rng: RandomNumberGenerator, center: Vector2, floor_at: Callable) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heading := rng.randf() * TAU
	var at := center
	var previous_left := Vector3.ZERO; var previous_right := Vector3.ZERO
	var segments := rng.randi_range(4, 7)
	for i in range(segments + 1):
		var dir := Vector2(cos(heading), sin(heading))
		var side := Vector2(-dir.y, dir.x)
		var width := 0.06 + 0.16 * sin(float(i) / float(segments) * PI)
		var y: float = float(floor_at.call(at)) + 0.025
		var left := Vector3(at.x + side.x * width, y, at.y + side.y * width)
		var right := Vector3(at.x - side.x * width, y, at.y - side.y * width)
		if i > 0:
			for v in [previous_left, left, previous_right, previous_right, left, right]:
				st.set_normal(Vector3.UP); st.add_vertex(v)
		previous_left = left; previous_right = right
		heading += rng.randf_range(-0.6, 0.6)
		at += Vector2(cos(heading), sin(heading)) * rng.randf_range(0.4, 0.7)
	var crack := MeshInstance3D.new(); crack.name = "LavaCrack"; crack.mesh = st.commit()
	crack.material_override = glow("#ff4a12", "#ffd27a", 1.5, 1)
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	live.add_child(crack)
