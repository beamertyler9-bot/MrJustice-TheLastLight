extends RefCounted

const Shell = preload("res://scripts/interior_surfaces.gd")
static func rehome(world, point: Vector3, footprint: float) -> Vector3:
 var id: String = world.interior_at(point)
 var sites = load("res://scripts/region_sites.gd"); var moss = load("res://scripts/mosswake_layouts.gd"); var places = load("res://scripts/locations.gd")
 var origin: Vector3; var cells: Dictionary; var step: float; var floor_at: Callable; var height_at: Callable; var cave = false
 var record: Dictionary = sites.site(id)
 if not record.is_empty():
  origin = sites.origin(id); cells = sites.cells(id); step = sites.STEP; cave = record.kind == "cave"
  var level = clampi(floori((point.y - origin.y + 15.3) / 7.5), 0, 6) if sites.layout(id).castle else 0
  floor_at = func (p: Vector2) -> float: return sites.floor_height(id, p, level)
  height_at = func (p: Vector2) -> float:
   if sites.layout(id).castle:
    for room in sites.layout(id).rooms:
     if int(room.level) == level and Rect2(room.p - room.size * 0.5, room.size).has_point(p): return 5.2 + 1.8 * (1 - pow(clampf(absf(p.x - room.p.x) / (room.size.x * 0.5), 0, 1), 1.5))
   return sites.ceiling_height(id, p)
 elif id in ["rootglow", "cedarwatch"]:
  origin = moss.ORIGINS[id]; cells = moss.cells(id); step = moss.STEP; cave = id == "rootglow"
  floor_at = func (p: Vector2) -> float: return moss.floor_height(id, p)
  height_at = func (p: Vector2) -> float: return moss.ceiling_height(id, p)
 elif id in ["mine", "dungeon"]:
  origin = places.INTERIORS[id]; cells = places._deep_cells(id, places.deep_layout(id, world.state.seed_value)); step = 1.0; cave = id == "mine"
  floor_at = func (_p: Vector2) -> float: return 0.0
  height_at = func (p: Vector2) -> float: return float(cells.get(Vector2i(p.floor()), 5.6))
 else: return point
 var p = Vector2(point.x - origin.x, point.z - origin.z); var roof = INF
 for offset in [Vector2.ZERO, Vector2(footprint, 0), Vector2(-footprint, 0), Vector2(0, footprint), Vector2(0, -footprint)]:
  if cells.has(Vector2i(((p + offset) / step).floor())): roof = minf(roof, Shell.ceiling_at(cells, step, floor_at, height_at, cave, p + offset))
 var floor_y: float = floor_at.call(p)
 if point.y >= origin.y + floor_y - 0.1 and point.y <= origin.y + roof - 1.3: return point
 var y = clampf(point.y - origin.y, floor_y + 0.035, maxf(floor_y + 0.035, roof - 1.3))
 return Vector3(point.x, origin.y + y, point.z)
