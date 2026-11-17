extends RefCounted

const B = preload("res://scripts/build.gd")
const Shared = preload("res://scripts/alderhaven_masterplan.gd")
static var _plots: Array = []
static var _streets: Array = []
static var _center = Vector2.ZERO
static var _floor = 38.0
static var _water: Dictionary = {}
static func v(a) -> Vector2: return Vector2(a[0], a[1])
static func _load():
 if not _plots.is_empty(): return
 var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/brindlewick_plan.json"))
 var purposes = ["library", "home", "home", "inn", "stores", "workshop", "stores", "stores", "home", "stores", "bakery", "stores"]
 var shops = ["", "", "", "grocer", "general", "blacksmith", "general", "alchemist", "", "trader", "grocer", "general"]
 for row in data.plots:
  var i = int(row.number) - 1; var rotated: bool = row.door in ["E", "W"]
  _plots.append({"p": v(row.position), "w": float(row.footprint[1] if rotated else row.footprint[0]), "d": float(row.footprint[0] if rotated else row.footprint[1]), "heading": {"N": PI, "S": 0.0, "E": PI / 2, "W": -PI / 2}[row.door], "district": 0, "index": i, "purpose": purposes[i], "shop": shops[i], "title": str(row.title), "approach": v(row.approach), "footprint": v(row.footprint)})
 for route in data.roads:
  for i in range(route.points.size() - 1): _streets.append({"a": v(route.points[i]), "b": v(route.points[i + 1]), "width": float(route.width)})
static func plots() -> Array:
 _load(); return _plots.duplicate(true)
static func streets() -> Array:
 _load(); return _streets
static func configure(center: Vector2, floor_height: float):
 _load(); _center = center; _floor = floor_height
 var raw = FileAccess.open("res://assets/world/fixed/water.bin", FileAccess.READ).get_var()
 var vicinity = Rect2(center - Vector2(150, 150), Vector2(300, 300))
 for river in raw.rivers:
  for i in range(river.sections.size() - 1):
   var a = river.sections[i]; var b = river.sections[i + 1]
   var bounds = Rect2(a.left, Vector2.ZERO).expand(a.right).expand(b.left).expand(b.right)
   if not bounds.grow(12).intersects(vicinity): continue
   var polygon = PackedVector2Array([a.left - center, a.right - center, b.right - center, b.left - center])
   for key in Shared._cells(Rect2(bounds.position - center, bounds.size).grow(12)):
    if not _water.has(key): _water[key] = []
    _water[key].append(polygon)
static func reroute(roads: Array) -> Array:

 var kept: Array = []; var bounds = Rect2(-82, -70, 157, 150)
 for road in roads:
  if bounds.has_point(road.a - _center) and bounds.has_point(road.b - _center): continue
  kept.append(road)
 for endpoint in [{"p": Vector2(-78, -64), "route": "Frostharbor Road"}, {"p": Vector2(68, -16), "route": "Valley Road"}]:
  var nearest = Vector2.INF; var distance = INF
  for road in kept:
   if road.name != endpoint.route: continue
   for point in [road.a, road.b]:
    var d: float = point.distance_squared_to(_center + endpoint.p)
    if d < distance: distance = d; nearest = point
  if nearest == Vector2.INF: continue
  _streets.append({"a": endpoint.p, "b": nearest - _center, "width": 5.0})
  var a: Vector2 = _center + endpoint.p
  kept.append({"a": a, "b": nearest, "ah": _floor, "bh": _floor, "bounds": Rect2(a, Vector2.ZERO).expand(nearest).grow(12), "name": endpoint.route, "kind": "road"})
 return kept
static func grade(p: Vector2) -> float: return _floor + 0.8 * smoothstep(-20, 65, p.y) + 0.5 * (1.0 - smoothstep(-65, -15, p.x))
static func affects(point: Vector2) -> bool:
 var p = point - _center; return absf(p.x) < 135 and absf(p.y) < 140
static func terrain_height(point: Vector2, original: float) -> float:
 if not affects(point): return original
 var p = point - _center

 var mine_delta = (p - Vector2(-65, -85)).abs() - Vector2(30, 25)
 var mine_blend = smoothstep(0, 6, maxf(mine_delta.x, mine_delta.y))
 if mine_blend <= 0: return original
 for polygon in _water.get(Vector2i(floori(p.x / 32), floori(p.y / 32)), []):
  if Geometry2D.is_point_in_polygon(p, polygon): return original
  for i in range(polygon.size()):
   if p.distance_to(Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % polygon.size()])) < 10: return original
 var outside = maxf(maxf(-76 - p.x, p.x - 70), maxf(-61 - p.y, p.y - 76))
 var result = lerpf(original, grade(p), 1.0 - smoothstep(0, 38, outside))
 for plot in _plots:
  var q = (p - plot.p).abs() - plot.footprint * 0.5 - Vector2.ONE * 2
  var weight = 1.0 - smoothstep(0, 5, maxf(q.x, q.y))
  result = lerpf(result, grade(plot.p), weight)
 var yard = (p - Vector2(58, 18)).abs() - Vector2(7, 10)
 result = lerpf(result, grade(Vector2(58, 18)), 1.0 - smoothstep(0, 4, maxf(yard.x, yard.y)))
 return lerpf(original, result, mine_blend)
static func reserved(local: Vector2, padding: float = 0) -> bool:
 _load()
 if not Rect2(-100, -90, 190, 190).grow(padding).has_point(local): return false
 if Rect2(-13, -12, 26, 24).grow(padding).has_point(local) or Rect2(50, 7, 16, 22).grow(padding).has_point(local): return true
 for plot in _plots:
  if Rect2(plot.p - plot.footprint * 0.5, plot.footprint).grow(padding + 3).has_point(local): return true
  var front = plot.p + Vector2(sin(plot.heading), cos(plot.heading)) * (plot.d * 0.5 + 1.5)
  if local.distance_to(Geometry2D.get_closest_point_to_segment(local, front, plot.approach)) < padding + 1.6: return true
 for r in _streets:
  if local.distance_to(Geometry2D.get_closest_point_to_segment(local, r.a, r.b)) < r.width * 0.5 + padding + 1: return true
 return Rect2(-73, 58, 39, 16).grow(padding).has_point(local)
static func path_distance(point: Vector2) -> float:
 if not affects(point): return INF
 var p = point - _center; var nearest = INF
 for r in _streets: nearest = minf(nearest, p.distance_to(Geometry2D.get_closest_point_to_segment(p, r.a, r.b)))
 return nearest
static func seat(world, p: Vector2) -> Vector3: return Vector3(p.x, world.surface_height_at(_center.x + p.x, _center.y + p.y), p.y)
static func infrastructure(world, parent: Node3D, site: Dictionary):
 _load(); var P = load("res://scripts/locations.gd")
 for route in _streets: Shared._paint_street(world, parent, site.pos, route.a, route.b, route.width)
 Shared._paint_street(world, parent, site.pos, Vector2(-11, 0), Vector2(11, 0), 21)
 var green = Node3D.new(); green.name = "VillageGreen"; parent.add_child(green)
 for p in [Vector2(-7, -7), Vector2(7, 7)]:
  if free_site(world, p, Vector2(4, 2)): P.bench(green, seat(world, p), PI / 2)
 for p in [Vector2(-10, -9), Vector2(10, 9), Vector2(-39, -28), Vector2(20, 29)]:
  if free_site(world, p, Vector2(1, 1)): P.lantern(parent, seat(world, p))
 if free_site(world, Vector2(7, -7), Vector2(3, 1)):
  var board = Node3D.new(); board.name = "VillageNoticeboard"; board.add_to_group("batch_dynamic"); green.add_child(board); board.position = seat(world, Vector2(7, -7))
  var timber = B.world_surface("timber", "#705a40")
  B.box(board, Vector3(0, 1.7, 0), Vector3(2.4, 1.4, 0.16), timber).name = "NoticeBoardSurface"
  for x in [-0.55, 0.55]: B.box(board, Vector3(x, 1.7, 0.09), Vector3(0.65, 0.85, 0.02), B.mat("#e0d3b1"))
  B.box(board, Vector3(0, 0.8, 0), Vector3(0.15, 1.6, 0.15), timber, true)
  var notice = P.interaction(board, "brindlewick_village_notices", "lore", "Read village notices", Vector3(0, 1, 0))
  notice.set_meta("text", "Welcome to Brindlewick. Auntie Rowan sells supplies; Bramm Emberhand works the forge. Speak with Forester Pip, Juniper, Tansy, Nim, Lethiel and Tobin for local work.")
 for p in [Vector2(-7, 6), Vector2(7, -1)]: P.garden(green, seat(world, p), true)
 for p in [Vector2(-68, 64), Vector2(-61, 64), Vector2(-54, 64), Vector2(-47, 64)]: P.garden(parent, seat(world, p), true)
 if free_site(world, Vector2(58, 18), Vector2(13, 19)):
  var yard = Node3D.new(); yard.name = "BlacksmithYard"; yard.position = seat(world, Vector2(58, 18))

  for x in range(52, 65):
   for z in range(9, 28): yard.position.y = maxf(yard.position.y, world.surface_height_at(_center.x + x, _center.y + z) + 0.08)
  parent.add_child(yard)
  Shared.support_house(world, yard, {"w": 12.0, "d": 18.0})
  var stone = B.world_surface("stone", "#938976"); var wood = B.world_surface("timber", "#70553b")
  B.box(yard, Vector3(0, -0.2, 0), Vector3(12, 0.4, 18), stone, true)
  Shared.compact_forge(yard, 12, 18)
  var forge = P.interaction(yard, "brindlewick_yard_forge", "workbench", "Use Bramm's forge", Vector3(-2, 0.05, -6)); forge.set_meta("station", "forge")
  load("res://scripts/shop_architecture.gd").prop(yard, "kaykit_anvil", Vector3(0, 0.02, -3), Vector3(1.2, 0.9, 0.8), 0, true)
  load("res://scripts/shop_architecture.gd").prop(yard, "resource_wood_log_stack", Vector3(3, 0.02, 5), Vector3(2.2, 1, 3), 0, true)
  for x in [-5.5, 5.5]:
   for z in [-8.5, 0, 8.5]: B.box(yard, Vector3(x, 1.55, z), Vector3(0.22, 3.1, 0.22), wood, true)
  B.box(yard, Vector3(0, 3.25, 0), Vector3(12.5, 0.22, 18.5), B.world_surface("stone", "#635b51"))
  Shared._paint_street(world, parent, site.pos, Vector2(35, 32), Vector2(58, 32), 2.5)
  Shared._paint_street(world, parent, site.pos, Vector2(58, 32), Vector2(58, 27), 2.5)
 var wood = B.world_surface("timber", "#70553b")
 for entry in [{"p": Vector2(17, 73), "title": "BRINDLEWICK"}, {"p": Vector2(-72, -55), "title": "FROSTHARBOR"}, {"p": Vector2(64, -29), "title": "BELLCROWN"}]:
  if not free_site(world, entry.p, Vector2(4, 1)): continue
  var at = seat(world, entry.p); P.signboard(parent, at + Vector3.UP * 2.1, entry.title, 0, 3, "settlement_entrance")
  B.box(parent, at + Vector3.UP * 0.9, Vector3(0.16, 1.8, 0.16), wood, true)
 B.batch_static(parent)

static func residents() -> Array:
 return [
  {"id": "merchant", "name": "Auntie Rowan", "race": "human", "role": "merchant", "home": 4, "line": "My kettle is warm and the pantry is stocked for travelers."},
  {"id": "smith", "name": "Bramm Emberhand", "race": "orc", "role": "smith", "home": 5, "line": "Good iron, strong tools, and a steady fire. The working yard is just behind my shop."},
  {"id": "resident", "name": "Forester Pip", "race": "human", "role": "forester", "home": 9, "line": "The north road leads out toward the woods. Come back when the trail is safe."},
  {"id": "gardener", "name": "Juniper", "race": "elf", "role": "gardener", "home": 8, "line": "The gardens behind the homes keep our little town growing."},
  {"id": "mason", "name": "Tansy Stonefoot", "race": "dwarf", "role": "mason", "home": 1, "line": "Good foundations make a home. I keep an eye on every stone."},
  {"id": "baker", "name": "Nim Honeybun", "race": "smallfolk", "role": "baker", "home": 10, "line": "Something sweet for supper? Stop at my bakery beside the green."},
  {"id": "weaver", "name": "Lethiel Fernsong", "race": "elf", "role": "weaver", "home": 6, "line": "Rope, supplies and a little careful mending for the road."},
  {"id": "porter", "name": "Tobin Reed", "race": "human", "role": "porter", "home": 11, "line": "Timber and cargo come through this store. We need the roads kept clear."},
  {"id": "innkeeper", "name": "Hesta Wayfarer", "race": "human", "role": "merchant", "home": 3, "line": "A furnished room and a warm meal for the journey."},
  {"id": "herbalist", "name": "Fenna Mosswell", "race": "elf", "role": "merchant", "home": 7, "line": "Mana potions, tonics and herbs, ready for your next outing."},
  {"id": "clerk", "name": "Orrin Bellward", "race": "human", "role": "neighbor", "home": 0, "line": "Meet our neighbors for work and local stories. The hall faces the village green."},
  {"id": "neighbor", "name": "Cora Reed", "race": "human", "role": "neighbor", "home": 2, "line": "The western lane is quiet. I like it that way."}]

static func free_site(world, p: Vector2, size: Vector2) -> bool:
 return not load("res://scripts/world_occupancy.gd").conflicts(world.state, Rect2(_center + p - size * 0.5, size))
static func resident_fallback(world, home: int) -> Vector2:
 var options = [Vector2(-5, -19), Vector2(0, -19), Vector2(5, -19), Vector2(-5, 20), Vector2(0, 20), Vector2(5, 20), Vector2(17, -18), Vector2(17, 0), Vector2(17, 20), Vector2(-35, -18), Vector2(-35, 0), Vector2(-35, 20)]
 for i in range(options.size()):
  var p: Vector2 = options[(home + i) % options.size()]
  if free_site(world, p, Vector2(2, 2)): return p
 return Vector2(10, 76)
