extends RefCounted

const B = preload("res://scripts/build.gd")
static func ceiling_vertex(cells: Dictionary, step: float, floor_at: Callable, height_at: Callable, cave: bool, p: Vector2) -> float:
 var height: float = height_at.call(p)
 if cave:
  var distance = step * 3.0; var cell = Vector2i((p / step).floor())
  for z in range(-3, 4):
   for x in range(-3, 4):
    var key = cell + Vector2i(x, z)
    if not cells.has(key): distance = minf(distance, maxf(0, p.distance_to((Vector2(key) + Vector2.ONE * 0.5) * step) - step * 0.7071))
  height = lerpf(minf(height, maxf(1.75, height * 0.62)), height, smoothstep(0, step * 2, distance))
 return floor_at.call(p) + height
static func ceiling_at(cells: Dictionary, step: float, floor_at: Callable, height_at: Callable, cave: bool, p: Vector2) -> float:

 var base = (p / step).floor() * step; var uv = (p - base) / step; var h = []
 for offset in [Vector2.ZERO, Vector2(step, 0), Vector2(0, step), Vector2.ONE * step]: h.append(ceiling_vertex(cells, step, floor_at, height_at, cave, base + offset))
 return h[0] + (h[1] - h[0]) * uv.x + (h[2] - h[0]) * uv.y if uv.x + uv.y <= 1 else h[3] + (h[2] - h[3]) * (1 - uv.x) + (h[1] - h[3]) * (1 - uv.y)
static func build(parent: Node3D, cells: Dictionary, step: float, floor_at: Callable, height_at: Callable, floor_material: Material, wall_material: Material, cave: bool):
 var heights = {}; var edges = []; var edge_normals = {}
 for cell in cells:
  for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
   if cells.has(cell + d): continue
   var center = (Vector2(cell) + Vector2.ONE * 0.5) * step + Vector2(d) * step * 0.5
   var tangent = Vector2(-d.y, d.x) * step * 0.5
   edges.append([center - tangent, center + tangent, Vector2(d)])
   for p in [center - tangent, center + tangent]: edge_normals[p] = edge_normals.get(p, Vector2.ZERO) + Vector2(d)
 var roof = func (p: Vector2) -> float:
  if heights.has(p): return heights[p]
  var result = ceiling_vertex(cells, step, floor_at, height_at, cave, p); heights[p] = result; return result
 for ceiling in [false, true]:
  var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for cell in cells:
   var p = Vector2(cell) * step; var quad = []
   for offset in [Vector2.ZERO, Vector2(step, 0), Vector2(0, step), Vector2.ONE * step]:
    var at = p + offset; var y: float = roof.call(at) if ceiling else floor_at.call(at); quad.append(Vector3(at.x, y, at.y))
   for tri in [[0, 1, 2], [1, 3, 2]]:
    var n = (quad[tri[1]] - quad[tri[0]]).cross(quad[tri[2]] - quad[tri[0]]).normalized()
    if (ceiling and n.y > 0) or (not ceiling and n.y < 0): n = -n
    var order = tri if not ceiling else [tri[0], tri[2], tri[1]]
    for index in order:
     st.set_normal(n); st.set_uv(Vector2(quad[index].x, quad[index].z) * 0.25); st.add_vertex(quad[index])
  var mesh = st.commit(); var art = B.mesh(parent, mesh, wall_material if ceiling else floor_material)
  art.name = "TunnelCeiling" if ceiling else "TunnelFloor"; B.solid(parent, Vector3.ZERO, mesh.create_trimesh_shape())
 var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for edge in edges:
  var a: Vector2 = edge[0]; var b: Vector2 = edge[1]; var outward: Vector2 = edge[2]; var rows = []
  for i in range(4 if cave else 2):
   var row = []; var t = float(i) / (3 if cave else 1)
   for p in [a, b]:
    var base: float = floor_at.call(p); var top: float = roof.call(p); var at = p
    if cave and i > 0 and i < 3: at += edge_normals[p].normalized() * (0.12 + 0.045 * sin(p.x * 0.7 + p.y * 0.9 + i))
    row.append(Vector3(at.x, lerpf(base - 0.14, top, t), at.y))
   rows.append(row)
  for i in range(rows.size() - 1):
   var quad = [rows[i][0], rows[i][1], rows[i + 1][0], rows[i + 1][1]]
   var normal = Vector3(-outward.x, 0, -outward.y)
   for index in [0, 2, 1, 1, 2, 3]:
    st.set_normal(normal); st.set_uv(Vector2(Vector2(quad[index].x, quad[index].z).dot(Vector2(-outward.y, outward.x)), quad[index].y) * 0.32); st.add_vertex(quad[index])
 var mesh = st.commit(); var art = B.mesh(parent, mesh, wall_material); art.name = "ContinuousTunnelWalls" if cave else "MasonryRoomWalls"
 var shape = mesh.create_trimesh_shape(); shape.backface_collision = true; B.solid(parent, Vector3.ZERO, shape)
 parent.set_meta("continuous_tunnel", cave); parent.set_meta("shell_triangles", mesh.get_faces().size() / 3)
