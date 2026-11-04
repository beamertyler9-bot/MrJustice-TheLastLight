extends RefCounted

const B = preload("res://scripts/build.gd")
const Art = preload("res://scripts/landmark_art.gd")
const A = preload("res://scripts/imported_assets.gd")
static var materials = {}
static var arches = {}
static var window_pane: Mesh
static func stone(region: int, floor: bool = false, castle: bool = false, cave: bool = false) -> ShaderMaterial:
 var key = "%d:%s:%s:%s" % [region, floor, castle, cave]
 if not materials.has(key):
  var palette = ["#697463", "#aa828c", "#99917a", "#bfa27f", "#514d4d", "#5f5b69", "#8495ac"]
  var m = ShaderMaterial.new(); m.shader = preload("res://shaders/interior_stone.gdshader")
  m.set_shader_parameter("stone_color", Color("#454552" if castle and floor else "#666575" if castle else palette[clampi(region - 9, 0, 6)]))
  m.set_shader_parameter("detail_tex", preload("res://assets/surfaces/stone.png")); m.set_shader_parameter("masonry", not cave); m.set_shader_parameter("polished", castle and floor); materials[key] = m
 return materials[key]
static func arch(parent: Node3D, width: float, spring: float, rise: float, depth: float, material: Material) -> void:
 var key = Vector4(width, spring, rise, depth)
 if arches.has(key):
  B.mesh(parent, arches[key], material); return
 var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var path = []
 for i in range(17):
  var x = -width * 0.5 + width * i / 16.0; var y = spring + rise * (1 - pow(absf(x) / (width * 0.5), 1.5)); path.append(Vector2(x, y))
 for i in range(path.size() - 1):
  var a: Vector2 = path[i]; var b: Vector2 = path[i + 1]; var tangent = (b - a).normalized(); var side = Vector2(-tangent.y, tangent.x) * 0.1
  var aa = a - side; var ab = a + side; var ba = b - side; var bb = b + side
  var points = [Vector3(aa.x, aa.y, -depth), Vector3(ab.x, ab.y, -depth), Vector3(ba.x, ba.y, -depth), Vector3(bb.x, bb.y, -depth), Vector3(aa.x, aa.y, depth), Vector3(ab.x, ab.y, depth), Vector3(ba.x, ba.y, depth), Vector3(bb.x, bb.y, depth)]
  for quad in [[0, 1, 2, 1, 3, 2], [4, 6, 5, 5, 6, 7], [0, 2, 4, 2, 6, 4], [1, 5, 3, 3, 5, 7]]:
   for j in range(0, quad.size(), 3):
    var normal = (points[quad[j + 1]] - points[quad[j]]).cross(points[quad[j + 2]] - points[quad[j]]).normalized()
    for k in range(3): st.set_normal(normal); st.set_uv(Vector2(points[quad[j + k]].x, points[quad[j + k]].y)); st.add_vertex(points[quad[j + k]])
 arches[key] = st.commit(); B.mesh(parent, arches[key], material)
static func portal(parent: Node3D, at: Vector3, yaw: float, castle: bool = false):
 var node = Node3D.new(); node.name = "DungeonDoorway_%d" % parent.get_child_count(); node.position = at; node.rotation.y = yaw; parent.add_child(node)
 var material = B.world_surface("stone", "#8b8191" if castle else "#928778")
 if not castle and not A.entry("p32_dungeon_gate").is_empty():
  var gate = Art.module(node, "p32_dungeon_gate", Vector3.ZERO, Vector3(4.8, 4.5, 0.65))
  for part in gate.find_children("*", "MeshInstance3D", true, false):
   var points = part.mesh.get_faces(); var frame = part.transform; var ancestor = part.get_parent()
   while ancestor != node:
    frame = ancestor.transform * frame; ancestor = ancestor.get_parent()
   for i in range(points.size()): points[i] = frame * points[i]
   var shape = ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points); B.solid(node, Vector3.ZERO, shape)
  node.set_meta("clear_width", 3.88); return node
 for side in [-1, 1]:
  B.box(node, Vector3(side * 2.15, 1.65, 0), Vector3(0.42, 3.3, 0.48), material, true)
  B.box(node, Vector3(side * 2.15, 0.12, 0), Vector3(0.66, 0.24, 0.75), material, true)
 arch(node, 4.3, 3.3, 1.25, 0.25, material)
 node.set_meta("clear_width", 3.88)
 return node
static func portals(parent: Node3D, plan: Dictionary, floor_at: Callable, castle: bool = false):
 var used = {}
 for edge in plan.links:
  var a: Dictionary = plan.rooms[int(edge[0])]; var b: Dictionary = plan.rooms[int(edge[1])]
  if a.level != b.level: continue
  for pair in [[a, b], [b, a]]:
   var from: Dictionary = pair[0]; var to: Dictionary = pair[1]; var delta: Vector2 = (to.p - from.p).normalized()
   var length = minf(from.size.x * 0.5 / maxf(absf(delta.x), 0.001), from.size.y * 0.5 / maxf(absf(delta.y), 0.001))
   var p: Vector2 = from.p + delta * (length + 0.65)
   var key = Vector3(roundf(p.x), int(from.level), roundf(p.y))
   if used.has(key): continue
   used[key] = true
   var y: float = floor_at.call(p, int(from.level)); portal(parent, Vector3(p.x, y, p.y), atan2(delta.x, delta.y), castle)
static func room(parent: Node3D, size: Vector2, height: float, purpose: String):
 var node = Node3D.new(); node.name = "GothicVault"; parent.add_child(node)
 var trim = B.world_surface("stone", "#8c8093"); var iron = B.mat("#423b49", 0.4)
 var width = size.x; var spring = maxf(2.5, height - 2.0)
 for z in [-size.y * 0.28, 0, size.y * 0.28]:
  var rib = Node3D.new(); rib.position.z = z; node.add_child(rib); arch(rib, width, spring, 1.8, 0.11, trim)
  for side in [-1, 1]:
   B.box(rib, Vector3(side * width * 0.5, spring * 0.5, 0), Vector3(0.22, spring, 0.28), trim)
 for side in [-1, 1]:
  for z in [-size.y * 0.23, size.y * 0.23]:
   var window = Node3D.new(); window.name = "GothicInteriorWindow"; window.position = Vector3(side * (size.x * 0.5 - 0.24), 1.35, z); window.rotation.y = -side * PI * 0.5; node.add_child(window)
   _window(window)
 var runner = Node3D.new(); runner.name = "BurgundyRunner"; node.add_child(runner)
 B.box(runner, Vector3(0, 0.025, 0), Vector3(minf(2.8, size.x * 0.25), 0.025, maxf(1, size.y - 2)), B.world_surface("cloth", "#793747"))
 for x in [-1.28, 1.28]: B.box(node, Vector3(x, 0.047, 0), Vector3(0.035, 0.006, maxf(1, size.y - 2)), B.mat("#b59a66", 0.25))
 var chandelier = Node3D.new(); chandelier.position = Vector3(0, height - 1.35, 0); node.add_child(chandelier)
 B.ring(chandelier, Vector3.ZERO, 0.68, 0.05, iron)
 for i in range(6):
  var a = i * TAU / 6; var p = Vector3(cos(a) * 0.68, 0.12, sin(a) * 0.68)
  B.cyl(chandelier, p, 0.045, 0.3, B.mat("#d1bb88")); B.ball(chandelier, p + Vector3.UP * 0.22, Vector3(0.07, 0.16, 0.07), B.mat("#f2b769", 0, 0.5))
 if "throne" in purpose.to_lower():
  var at = Vector3(0, 0, -size.y * 0.33)
  B.box(node, at + Vector3.UP * 0.22, Vector3(4, 0.44, 3.0), trim, true)
  B.box(node, at + Vector3.UP * 0.8, Vector3(1.8, 0.35, 1.5), B.world_surface("cloth", "#713348"))
  B.box(node, at + Vector3(0, 2.05, -0.65), Vector3(1.8, 2.7, 0.25), trim); arch(node, 2, 3.0, 1.2, 0.18, trim)
 if "chapel" in purpose.to_lower():
  for side in [-1, 1]:
   for z in [-3, 1, 5]: B.box(node, Vector3(side * 4, 0.5, z), Vector3(3, 0.18, 0.7), B.world_surface("timber", "#5d4146"), true)
 node.set_meta("gothic_room", purpose)
static func _window(parent: Node3D):
 var material = B.world_surface("stone", "#9a8494"); arch(parent, 1.5, 2.3, 1.1, 0.08, material)
 for side in [-1, 1]: B.box(parent, Vector3(side * 0.75, 1.15, 0), Vector3(0.14, 2.3, 0.18), material)
 if window_pane == null:
  var face: Array[PackedVector3Array] = [PackedVector3Array([Vector3(-0.64, 0.12, -0.06), Vector3(0.64, 0.12, -0.06), Vector3(0.64, 2.25, -0.06), Vector3(0, 3.2, -0.06), Vector3(-0.64, 2.25, -0.06)])]
  window_pane = B._flat_geometry(face)

 var glass = B.mat("#7396b8", 0, 0.22)
 if not materials.has("glass"):
  glass = glass.duplicate(); glass.cull_mode = BaseMaterial3D.CULL_DISABLED; materials["glass"] = glass
 var pane = B.mesh(parent, window_pane, materials["glass"])
 B.box(parent, Vector3(0, 1.4, 0.02), Vector3(0.06, 2.8, 0.08), material)
 pane.name = "MoonlitGlass"
