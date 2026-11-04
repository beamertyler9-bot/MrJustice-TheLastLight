extends RefCounted


const ORIGINS = {"mine": Vector3(-240, -24, 180), "dungeon": Vector3(240, -24, 180)}
static var masks = {}
static func interior_at(point: Vector3, seed: int) -> String:
 for id in ORIGINS:
  var p: Vector3 = point - ORIGINS[id]
  if p.y < -1.5 or p.y > 13: continue
  var key = "%s:%s" % [id, seed]
  if not masks.has(key):
   if masks.size() > 4: masks.clear()
   masks[key] = _deep_cells(id, deep_layout(id, seed))
  if masks[key].has(Vector2i(floori(p.x), floori(p.z))): return id
 return ""
static func deep_layout(id: String, seed_value: int = 0) -> Dictionary:
 var rooms: Array = []
 var links: Array = []
 if id == "mine":
  rooms = [
   {"id": "mouth", "title": "MINER'S THRESHOLD", "p": Vector2(0, 0), "size": Vector2(14, 14), "ceiling": 5.6},
   {"id": "fork", "title": "THE LANTERN FORK", "p": Vector2(0, -16), "size": Vector2(15, 18), "ceiling": 6.0},
   {"id": "echo", "title": "ECHO BASIN", "p": Vector2(0, -34), "size": Vector2(20, 19), "ceiling": 7.5},
   {"id": "crystal", "title": "GLASSROOT GROTTO", "p": Vector2(21, -14), "size": Vector2(23, 17), "ceiling": 6.8},
   {"id": "shaft", "title": "THE GREAT AIR SHAFT", "p": Vector2(30, -38), "size": Vector2(22, 27), "ceiling": 12.0},
   {"id": "sump", "title": "THE JADE SUMP", "p": Vector2(24, -62), "size": Vector2(20, 18), "ceiling": 6.2},
   {"id": "rift", "title": "CINDER RIFT", "p": Vector2(0, -61), "size": Vector2(22, 23), "ceiling": 7.0},
   {"id": "fungus", "title": "PALECAP HOLLOW", "p": Vector2(-24, -34), "size": Vector2(21, 20), "ceiling": 7.3},
   {"id": "secret", "title": "THE FORGOTTEN WORKINGS", "p": Vector2(-35, -59), "size": Vector2(17, 19), "ceiling": 6.0},
   {"id": "heart", "title": "HEART OF EMBERVEIN", "p": Vector2(0, -90), "size": Vector2(31, 29), "ceiling": 9.0}]
  links = [["mouth", "fork"], ["fork", "echo"], ["fork", "crystal"], ["crystal", "shaft"], ["shaft", "echo"], ["shaft", "sump"], ["sump", "rift"], ["echo", "rift"], ["echo", "fungus"], ["fungus", "secret"], ["secret", "rift"], ["rift", "heart"]]
 else:
  rooms = [
   {"id": "vestibule", "title": "THE SILENT VESTIBULE", "p": Vector2(0, 0), "size": Vector2(14, 14), "ceiling": 5.6},
   {"id": "processional", "title": "PROCESSIONAL GALLERY", "p": Vector2(0, -16), "size": Vector2(14, 16), "ceiling": 6.0},
   {"id": "ossuary", "title": "THE OSSUARY", "p": Vector2(21, -14), "size": Vector2(20, 14), "ceiling": 5.2},
   {"id": "bells", "title": "HALL OF FALLEN BELLS", "p": Vector2(0, -36), "size": Vector2(20, 20), "ceiling": 8.0},
   {"id": "ember", "title": "CHAPEL OF EMBERS", "p": Vector2(-24, -35), "size": Vector2(16, 18), "ceiling": 7.0},
   {"id": "cloister", "title": "THE BROKEN CLOISTER", "p": Vector2(-24, -61), "size": Vector2(18, 20), "ceiling": 6.0},
   {"id": "scriptorium", "title": "THE ECHO SCRIPTORIUM", "p": Vector2(23, -39), "size": Vector2(19, 18), "ceiling": 6.5},
   {"id": "cistern", "title": "CISTERN OF TIDES", "p": Vector2(25, -64), "size": Vector2(20, 20), "ceiling": 6.5},
   {"id": "reliquary", "title": "THE INNER RELIQUARY", "p": Vector2(0, -66), "size": Vector2(18, 20), "ceiling": 7.0},
   {"id": "gate", "title": "THE THREEFOLD GATE", "p": Vector2(0, -85), "size": Vector2(12, 14), "ceiling": 6.0},
   {"id": "throne", "title": "THE BELLKEEPER'S COURT", "p": Vector2(0, -111), "size": Vector2(29, 29), "ceiling": 10.0},
   {"id": "vault", "title": "THE DAWN VAULT", "p": Vector2(31, -111), "size": Vector2(18, 18), "ceiling": 7.0}]
  links = [["vestibule", "processional"], ["processional", "bells"], ["processional", "ossuary"], ["ossuary", "scriptorium"], ["scriptorium", "cistern"], ["cistern", "reliquary"], ["bells", "ember"], ["ember", "cloister"], ["cloister", "reliquary"], ["bells", "reliquary"], ["reliquary", "gate"], ["gate", "throne"], ["throne", "vault"]]
 if seed_value != 0:
  var rng := RandomNumberGenerator.new()
  rng.seed = hash("living-depths:%s:%s" % [seed_value, id])


  for room in rooms:
   if room.id in ["mouth", "vestibule", "gate", "throne", "vault", "heart"]: continue
   room.size += Vector2(rng.randf_range(0.0, 5.0), rng.randf_range(0.0, 4.0))
  var count: int = rng.randi_range(3, 5) if id == "mine" else rng.randi_range(3, 4)
  for index in range(count):
   var branch_id: String = "frontier_" + str(index)
   var at: Vector2
   var anchor: String
   if id == "mine":
    at = Vector2(-52.0 - rng.randf_range(0, 7), -15.0 - index * 18.0 + rng.randf_range(-3, 3))
    anchor = "fungus" if index < 2 else "secret" if index == 2 else "rift" if index == 3 else "heart"
   else:
    var side: float = -1.0 if index < 2 else 1.0
    at = Vector2(side * (49.0 + rng.randf_range(0, 5)), -34.0 - float(index % 2) * 28.0 + rng.randf_range(-3, 3))
    anchor = ("ember" if index == 0 else "cloister") if index < 2 else ("scriptorium" if index == 2 else "cistern")
   rooms.append({"id": branch_id, "title": (["THE COPPER DRIFTS", "ROOTBOUND GALLERY", "THE WANDERER'S HOLLOW", "THE OLD QUARRY", "THE DEEPER WORKINGS"] if id == "mine" else ["THE FORGOTTEN ARCHIVE", "CLOISTER OF ASH", "THE LAMPWARDEN'S CHAMBER", "THE WATER COURT"])[index], "p": at, "size": Vector2(rng.randf_range(14.0, 23.0), rng.randf_range(13.0, 20.0)), "ceiling": rng.randf_range(5.8, 8.2), "optional": true})
   links.append([anchor, branch_id])
   if index > 0 and (id == "mine" or index % 2 == 1): links.append(["frontier_" + str(index - 1), branch_id])
 return {"rooms": rooms, "links": links}

static func _deep_cells(id: String, layout: Dictionary) -> Dictionary:
 var cells: Dictionary = {}
 var centers: Dictionary = {}
 for room in layout.rooms:
  centers[room.id] = room.p
  var half: Vector2 = room.size * 0.5
  for z in range(floori(room.p.y - half.y), ceili(room.p.y + half.y)):
   for x in range(floori(room.p.x - half.x), ceili(room.p.x + half.x)):
    var q: Vector2 = (Vector2(x + 0.5, z + 0.5) - room.p) / half


    var edge: float = 1.0 + 0.07 * sin(q.y * 7.0 + room.p.x) + 0.04 * sin(q.x * 9.0)
    if id == "mine" and q.length_squared() > edge:
     continue
    var key := Vector2i(x, z)
    cells[key] = maxf(float(cells.get(key, 0.0)), float(room.ceiling))
 for link in layout.links:
  var a: Vector2 = centers[link[0]]
  var b: Vector2 = centers[link[1]]
  var radius: float = 2.6 if id == "mine" else 2.4
  for z in range(floori(minf(a.y, b.y) - radius), ceili(maxf(a.y, b.y) + radius)):
   for x in range(floori(minf(a.x, b.x) - radius), ceili(maxf(a.x, b.x) + radius)):
    var p := Vector2(x + 0.5, z + 0.5)
    if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= radius:
     var key := Vector2i(x, z)
     cells[key] = maxf(float(cells.get(key, 0.0)), 4.8)


 for z in range(-35, 7):
  for x in range(-7, 7):
   var key := Vector2i(x, z)
   cells[key] = maxf(float(cells.get(key, 0.0)), 5.6)
 for z in range(-21, -7):
  for x in range(7, 25):
   var key := Vector2i(x, z)
   cells[key] = maxf(float(cells.get(key, 0.0)), 5.6)
 return cells
