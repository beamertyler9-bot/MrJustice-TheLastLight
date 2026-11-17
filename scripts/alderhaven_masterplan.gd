extends RefCounted

const B = preload("res://scripts/build.gd")
const ORIGIN_OFFSET = Vector2(-130, 30)
const DISTRICTS = [
 {"name": "Cola Quays", "p": Vector2(-57, 59)},
 {"name": "Baker's Row", "p": Vector2(77, -47)},
 {"name": "Orchard Ward", "p": Vector2(-73, -77)},
 {"name": "Graham Market", "p": Vector2.ZERO},
 {"name": "Clockpantry", "p": Vector2(0, -79)},
 {"name": "Hearthhomes", "p": Vector2(68, 71)}
]
static var _data: Dictionary = {}
static var _plots: Array = []
static var _streets: Array = []
static var _center := Vector2.INF
static var _floor := 0.0
static var _pads: Dictionary = {}
static var _lanes: Dictionary = {}
static var _water: Dictionary = {}
static func _v(a) -> Vector2: return Vector2(a[0], a[1])
static func _load() -> void:
 if not _data.is_empty(): return
 _data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/alderhaven_plan.json"))
 for row in _data.plots:
  var rotated: bool = row.door in ["E", "W"]
  _plots.append({"p": _v(row.position), "w": float(row.footprint[1] if rotated else row.footprint[0]), "d": float(row.footprint[0] if rotated else row.footprint[1]), "heading": {"N": PI, "S": 0.0, "E": PI / 2, "W": -PI / 2}[row.door], "district": int(row.district), "index": int(row.index), "purpose": str(row.purpose), "title": str(row.title), "shop": str(row.shop), "approach": _v(row.approach), "footprint": _v(row.footprint)})
 for route in _data.roads:
  for i in range(route.points.size() - 1):
   _streets.append({"a": _v(route.points[i]), "b": _v(route.points[i + 1]), "width": float(route.width), "owner": int(route.owner), "kind": str(route.kind)})
static func plots() -> Array:
 _load(); return _plots.duplicate(true)
static func streets() -> Array:
 _load(); return _streets
static func roads(site_pos: Vector2) -> Array:
 _load(); var result: Array = []
 for r in _streets: result.append([site_pos + r.a, site_pos + r.b])

 var corners = [Vector2(-16, -17), Vector2(16, -17), Vector2(16, 17), Vector2(-16, 17)]
 for i in range(4): result.append([site_pos + corners[i], site_pos + corners[(i + 1) % 4]])
 return result
static func _cells(bounds: Rect2) -> Array:
 var result = []
 for z in range(floori(bounds.position.y / 32), floori(bounds.end.y / 32) + 1):
  for x in range(floori(bounds.position.x / 32), floori(bounds.end.x / 32) + 1): result.append(Vector2i(x, z))
 return result
static func configure(center: Vector2, floor_height: float) -> void:
 _load(); _center = center; _floor = floor_height; _pads.clear(); _lanes.clear(); _water.clear()
 for plot in _plots:
  var rect = Rect2(plot.p - plot.footprint * 0.5, plot.footprint).grow(2)
  var record = {"rect": rect, "height": _grade(plot.p)}
  for key in _cells(rect.grow(8)):
   if not _pads.has(key): _pads[key] = []
   _pads[key].append(record)
 for r in _streets:
  if r.kind == "bridge": continue
  var rect = Rect2(r.a, Vector2.ZERO).expand(r.b).grow(r.width * 0.5 + 9)
  for key in _cells(rect):
   if not _lanes.has(key): _lanes[key] = []
   _lanes[key].append(r)

 var raw = FileAccess.open("res://assets/world/fixed/water.bin", FileAccess.READ).get_var()
 var vicinity = Rect2(center - Vector2(230, 210), Vector2(460, 420))
 for river in raw.rivers:
  for i in range(river.sections.size() - 1):
   var a = river.sections[i]; var b = river.sections[i + 1]
   var polygon = PackedVector2Array([a.left - center, a.right - center, b.right - center, b.left - center])
   var bounds = Rect2(a.left, Vector2.ZERO).expand(a.right).expand(b.left).expand(b.right)
   if not bounds.grow(14).intersects(vicinity): continue
   for key in _cells(Rect2(bounds.position - center, bounds.size).grow(14)):
    if not _water.has(key): _water[key] = []
    _water[key].append(polygon)
static func _grade(p: Vector2) -> float:
 return _floor - 3.0 * (1.0 - smoothstep(-90, -35, p.x)) + 1.5 * (1.0 - smoothstep(-70, -35, p.y))
static func protected_water(local: Vector2) -> bool:
 var key = Vector2i(floori(local.x / 32), floori(local.y / 32))
 for polygon in _water.get(key, []):
  if Geometry2D.is_point_in_polygon(local, polygon): return true
  for i in range(polygon.size()):
   if local.distance_to(Geometry2D.get_closest_point_to_segment(local, polygon[i], polygon[(i + 1) % polygon.size()])) < 12: return true
 return false
static func terrain_height(point: Vector2, original: float, _site_pos: Vector2, _site_floor: float) -> float:
 var p = point - _center
 if absf(p.x) > 215 or absf(p.y) > 190 or protected_water(p): return original
 var outside = maxf(maxf(-100 - p.x, p.x - 105), maxf(-115 - p.y, p.y - 110))
 var result = lerpf(original, _grade(p), 1.0 - smoothstep(0, 48, outside))
 var key = Vector2i(floori(p.x / 32), floori(p.y / 32))
 for r in _lanes.get(key, []):
  var near = Geometry2D.get_closest_point_to_segment(p, r.a, r.b)
  var weight = 1.0 - smoothstep(r.width * 0.5 + 1, r.width * 0.5 + 9, p.distance_to(near))
  if weight > 0: result = lerpf(result, _grade(near), weight)
 var strongest = 0.0; var target = result
 for pad in _pads.get(key, []):
  var q = (p - pad.rect.get_center()).abs() - pad.rect.size * 0.5
  var weight = 1.0 - smoothstep(0, 8, maxf(q.x, q.y))
  if weight > strongest: strongest = weight; target = pad.height
 return lerpf(result, target, strongest)
static func reserved(local: Vector2, padding: float) -> bool:
 _load()
 if Rect2(-18, -19, 36, 38).grow(padding).has_point(local): return true
 for p in _plots:
  if Rect2(p.p - p.footprint * 0.5, p.footprint).grow(padding + 3).has_point(local): return true
  var heading = Vector2(sin(p.heading), cos(p.heading))
  var door = p.p + heading * (p.d * 0.5 + 1.5)
  if local.distance_to(Geometry2D.get_closest_point_to_segment(local, door, p.approach)) < padding + 1.5: return true
 for r in _streets:
  if local.distance_to(Geometry2D.get_closest_point_to_segment(local, r.a, r.b)) < r.width * 0.5 + padding + 1: return true
 return Rect2(-106, 20, 35, 17).grow(padding).has_point(local)
static func attach_path(world, house: Node3D, site: Dictionary, plot: Dictionary) -> void:
 var paths = load("res://scripts/building_paths.gd")
 var access = load("res://scripts/building_access.gd")
 access.ground_exterior(house, world)
 var frame: Transform3D = paths.frame(house)
 var entry: Vector3 = frame * house.get_node("BuildingEntry").position
 var target: Vector2 = site.pos + plot.approach
 var points = PackedVector2Array([Vector2(entry.x, entry.z), target])
 if points[0].distance_to(points[1]) < 0.15: points[1] += Vector2(sin(plot.heading), cos(plot.heading)) * 0.2
 var node = Node3D.new(); node.name = "BuildingApproach"; node.add_to_group("batch_dynamic"); house.add_child(node)
 node.set_meta("centerline", PackedVector3Array([entry, Vector3(target.x, world.surface_height_at(target.x, target.y) + 0.018, target.y)]))
 node.set_meta("obstacles", [])
 var mesh = paths._paint(paths._ribbon(world, points, entry, frame.affine_inverse()), world, frame)
 var art = B.mesh(node, mesh, paths.surface_material(world.ground_mat)); art.name = "Surface"; art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 B.solid(node, Vector3.ZERO, mesh.create_trimesh_shape())
static func _paint_street(world, parent: Node3D, center: Vector2, a: Vector2, b: Vector2, width: float) -> void:
 var paths = load("res://scripts/building_paths.gd")
 var art = MeshInstance3D.new(); parent.add_child(art); art.name = "GroundedStreet"
 var ribbon = paths._ribbon(world, PackedVector2Array([center + a, center + b]), Vector3.ZERO, parent.global_transform.affine_inverse(), width * 0.5)
 art.mesh = paths._paint(ribbon, world, parent.global_transform); art.material_override = paths.surface_material(world.ground_mat)
 art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func _bridge(world, parent: Node3D, site: Dictionary, pier: bool = false) -> void:
 var fixed = load("res://scripts/fixed_world.gd")
 var a = Vector2(-92, 28) if pier else Vector2(-143, -40)
 var b = Vector2(-76, 28) if pier else Vector2(-110, -40)
 var ah: float = fixed._original_height(site.pos + a); var bh: float = fixed._original_height(site.pos + b)
 var top = maxf(ah, bh) + 0.15
 var root = Node3D.new(); root.name = "CargoPier" if pier else "WestBridge"; parent.add_child(root)
 root.position = Vector3((a.x + b.x) * 0.5, top, (a.y + b.y) * 0.5)
 var length = a.distance_to(b); var width = 12.0 if pier else 7.0
 var wood = B.world_surface("timber", "#886d4d")
 B.box(root, Vector3(0, -0.16, 0), Vector3(length, 0.32, width), wood, true)
 for x in range(ceili(length)):
  B.box(root, Vector3(-length * 0.5 + x + 0.5, 0.012, 0), Vector3(0.92, 0.045, width - 0.1), wood)
 for side in [-1.0, 1.0]:
  var rail_z = side * (width * 0.5 - 0.15)
  for x in [-length * 0.4, 0.0, length * 0.4]: B.box(root, Vector3(x, 0.5, rail_z), Vector3(0.18, 1.2, 0.18), wood, true)
  B.box(root, Vector3(0, 0.95, rail_z), Vector3(length, 0.16, 0.16), wood, true)
 for side in ([1.0] if pier else [-1.0, 1.0]):
  var edge = Vector2(a.x if side < 0 else b.x, a.y)
  var outside = edge + Vector2(side * 5, 0)
  var ground: float = world.surface_height_at(site.pos.x + outside.x, site.pos.y + outside.y)
  var ramp = Node3D.new(); ramp.name = "CargoPierRamp" if pier else ("WestBridgeRampWest" if side < 0 else "WestBridgeRampEast"); parent.add_child(ramp)
  ramp.position = Vector3((edge.x + outside.x) * 0.5, (top + ground) * 0.5 - 0.08, a.y)
  ramp.rotation.z = atan2((ground - top) * side, 5.0)
  B.box(ramp, Vector3.ZERO, Vector3(sqrt(25 + pow(ground - top, 2)), 0.16, width - 0.4), wood, true)
 root.set_meta("deck_height", top); root.set_meta("start", site.pos + a); root.set_meta("end", site.pos + b)
static func district_art(world, parent: Node3D, site: Dictionary, district: Dictionary) -> void:
 _load(); var P = load("res://scripts/locations.gd")
 var index: int = district.index
 for route in _streets:
  if route.owner != index: continue
  if route.kind == "bridge": _bridge(world, parent, site)
  else: _paint_street(world, parent, site.pos, route.a, route.b, route.width)
 if index == 3:
  _paint_street(world, parent, site.pos, Vector2(-16, 0), Vector2(16, 0), 34)
  var high: float = world.height_at(site.pos.x, site.pos.y)
  var stone = B.world_surface("stone", "#b8aa8c")
  B.cyl(parent, Vector3(0, high + 0.3, 0), 2.4, 0.6, stone, true)
  B.cyl(parent, Vector3(0, high + 0.62, 0), 1.95, 0.08, B.mat("#8dc3cc"), false)
  for p in [Vector2(-8, -8), Vector2(8, -8), Vector2(-8, 8), Vector2(8, 8)]:
   P.stall(parent, Vector3(p.x, world.height_at(site.pos.x + p.x, site.pos.y + p.y), p.y), "#c28b6c")
  for p in [Vector2(-15, -15), Vector2(15, -15), Vector2(-15, 15), Vector2(15, 15)]: P.lantern(parent, Vector3(p.x, world.height_at(site.pos.x + p.x, site.pos.y + p.y), p.y))
  for p in [Vector2(0, 118), Vector2(125, 25), Vector2(-149, -40)]:
   var ground: float = world.height_at(site.pos.x + p.x, site.pos.y + p.y)
   var heading = PI / 2 if p.x > 100 else (-PI / 2 if p.x < -100 else 0.0)
   P.signboard(parent, Vector3(p.x, ground + 2.3, p.y), "ALDERHAVEN", heading, 4, "settlement_entrance")
   for side in [-1, 1]:
    var leg = p + Vector2(cos(heading), -sin(heading)) * float(side) * 1.7
    B.box(parent, Vector3(leg.x, ground + 1.05, leg.y), Vector3(0.14, 2.1, 0.14), B.world_surface("timber", "#78634c"), true)
 elif index == 0:
  _bridge(world, parent, site, true)
  for p in [Vector2(-78, 24), Vector2(-72, 24), Vector2(-50, 65)]: P.barrel(parent, Vector3(p.x, world.height_at(site.pos.x + p.x, site.pos.y + p.y), p.y))
 elif index == 2:
  for x in [-99.0, -47.0]:
   for z in [-95.0, -72.0]: P.garden(parent, Vector3(x, world.height_at(site.pos.x + x, site.pos.y + z), z), true)
 elif index == 4:
  var h: float = world.height_at(site.pos.x - 13.5, site.pos.y - 81)
  B.box(parent, Vector3(-13.5, h + 5.5, -81), Vector3(2.4, 11, 2.4), B.world_surface("stone", "#b4a68e"), true)
  B.ball(parent, Vector3(-13.5, h + 9.0, -79.74), Vector3(1.6, 1.6, 0.08), B.mat("#ead9a8"))
  B.box(parent, Vector3(-13.5, h + 9.25, -79.67), Vector3(0.09, 0.65, 0.07), B.mat("#43515a"))
  B.box(parent, Vector3(-13.25, h + 9.0, -79.66), Vector3(0.6, 0.08, 0.07), B.mat("#43515a"))
 elif index == 5:
  for p in [Vector2(95, 47), Vector2(95, 71), Vector2(42, 94)]: P.garden(parent, Vector3(p.x, world.height_at(site.pos.x + p.x, site.pos.y + p.y), p.y), true)
 B.batch_static(parent)

static func affects(point: Vector2) -> bool:
 var p = point - _center
 return absf(p.x) < 215 and absf(p.y) < 190
static func path_distance(point: Vector2) -> float:
 var p = point - _center; var key = Vector2i(floori(p.x / 32), floori(p.y / 32)); var nearest = INF
 for r in _lanes.get(key, []): nearest = minf(nearest, p.distance_to(Geometry2D.get_closest_point_to_segment(p, r.a, r.b)))
 return nearest
static func fit_distant(source: ArrayMesh) -> ArrayMesh:
 var result = ArrayMesh.new(); var fixed = load("res://scripts/fixed_world.gd"); var brindlewick = load("res://scripts/brindlewick_masterplan.gd")
 for surface in range(source.get_surface_count()):
  var arrays = source.surface_get_arrays(surface); var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  for i in range(vertices.size()):
   var p = Vector2(vertices[i].x, vertices[i].z)
   if affects(p) or brindlewick.affects(p): vertices[i].y = fixed.height_at(p)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  result.surface_set_material(surface, source.surface_get_material(surface))
 return result

static func support_house(world, house: Node3D, plot: Dictionary, collision: bool = true) -> void:



 var foundation = Node3D.new(); foundation.name = "GroundedFoundation"; house.add_child(foundation)
 var lowest: float = house.global_position.y - 0.5
 var samples = PackedVector3Array()
 var half = Vector2(plot.w + 0.25, plot.d + 0.25) * 0.5
 var nx = ceili(half.x * 4.0); var nz = ceili(half.y * 4.0)
 for ix in range(nx + 1):
  for iz in range(nz + 1):
   if ix != 0 and ix != nx and iz != 0 and iz != nz: continue
   var local = Vector3(lerpf(-half.x, half.x, float(ix) / nx), 0, lerpf(-half.y, half.y, float(iz) / nz))
   var p: Vector3 = house.to_global(local)
   var ground: float = world.surface_height_at(p.x, p.z)
   lowest = minf(lowest, ground - 0.3); samples.append(Vector3(p.x, ground, p.z))
 var bottom = lowest - house.global_position.y; var top = -0.2
 B.box(foundation, Vector3(0, (bottom + top) * 0.5, 0), Vector3(half.x * 2, top - bottom, half.y * 2), B.world_surface("stone", "#a09a87"), collision)
 foundation.set_meta("bottom_world", lowest); foundation.set_meta("terrain_samples", samples)
 foundation.set_meta("floor_world", house.global_position.y)
static func compact_forge(parent: Node3D, width: float, depth: float) -> void:
 var hearth = Node3D.new(); hearth.name = "CompactWorkingForge"; hearth.add_to_group("working_forge"); parent.add_child(hearth)
 hearth.position = Vector3(0, 0, -depth * 0.5 + 1.3)
 var stone = B.world_surface("stone", "#796c5b"); var iron = B.mat("#464b4d", 0.45)
 B.box(hearth, Vector3(0, 0.22, 0), Vector3(1.6, 0.44, 1.1), stone, true)
 B.box(hearth, Vector3(0, 1.05, -0.45), Vector3(1.6, 1.65, 0.2), stone, true)
 for side in [-1, 1]: B.box(hearth, Vector3(side * 0.69, 0.9, 0), Vector3(0.22, 1.2, 1.1), stone, true)
 B.box(hearth, Vector3(0, 1.55, 0), Vector3(1.7, 0.22, 1.2), stone)
 B.flame(hearth, Vector3(0, 0.55, 0.05), Vector3(0.7, 0.7, 0.65))
 for i in range(5): B.box(hearth, Vector3(-0.5 + i * 0.25, 0.46, 0.04), Vector3(0.04, 0.04, 0.9), iron)
