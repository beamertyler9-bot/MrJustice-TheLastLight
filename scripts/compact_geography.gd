extends RefCounted



const REVISION = 1
const SCALE = 0.75
static var _anchors: Array = []
static var _old_grid: Dictionary = {}
static var _new_grid: Dictionary = {}
static func configure(anchors: Array) -> void:
 _anchors = anchors; _old_grid.clear(); _new_grid.clear()
 for anchor in anchors:
  _index(_old_grid, anchor.old, anchor)
  _index(_new_grid, anchor.old * SCALE, anchor)
static func _index(grid: Dictionary, center: Vector2, anchor: Dictionary) -> void:
 var extent = float(anchor.outer)
 for z in range(floori((center.y - extent) / 256), floori((center.y + extent) / 256) + 1):
  for x in range(floori((center.x - extent) / 256), floori((center.x + extent) / 256) + 1):
   var key = Vector2i(x, z)
   if not grid.has(key): grid[key] = []
   grid[key].append(anchor)
static func _load() -> void:
 if _anchors.is_empty(): configure(load("res://scripts/fixed_world.gd").metadata().get("compact_anchors", []))
static func _anchor(p: Vector2, grid: Dictionary, compact: bool) -> Dictionary:
 var best = INF; var chosen = {}
 for anchor in grid.get(Vector2i(floori(p.x / 256), floori(p.y / 256)), []):
  var center: Vector2 = anchor.old * SCALE if compact else anchor.old
  var d = (p - center).abs(); var radius = maxf(d.x, d.y)
  if radius < float(anchor.outer) * (SCALE if compact else 1.0) and radius / float(anchor.outer) < best:
   best = radius / float(anchor.outer); chosen = anchor
 return chosen
static func _factor(radius: float, anchor: Dictionary) -> float:
 return lerpf(1.0, SCALE, smoothstep(float(anchor.inner), float(anchor.outer), radius))
static func point(old: Vector2) -> Vector2:
 _load(); var a = _anchor(old, _old_grid, false)
 if a.is_empty(): return old * SCALE
 var q = old - a.old; var d = q.abs()
 return a.old * SCALE + q * _factor(maxf(d.x, d.y), a)
static func source(compact: Vector2) -> Vector2:
 _load(); var a = _anchor(compact, _new_grid, true)
 if a.is_empty(): return compact / SCALE
 var q = compact - a.old * SCALE; var d = q.abs(); var radius = maxf(d.x, d.y)
 if radius <= float(a.inner): return a.old + q
 var lo = radius; var hi = radius / SCALE
 for i in range(18):
  var mid = (lo + hi) * 0.5
  if mid * _factor(mid, a) < radius: lo = mid
  else: hi = mid
 return a.old + q * ((lo + hi) * 0.5 / maxf(radius, 1.0e-06))
static func interior(at: Vector3, seed_value: int = 64127) -> bool:


 if at.y >= 0: return false
 if at.y >= -26 and at.y <= -10 and not load("res://scripts/locations.gd").interior_at(at, seed_value).is_empty(): return true
 if not load("res://scripts/mosswake_layouts.gd").interior_at(at).is_empty(): return true
 return not load("res://scripts/region_sites.gd").interior_at(at).is_empty()
static func outdoor(at: Vector3, seed_value: int = 64127) -> Vector3:
 if interior(at, seed_value): return at
 var p = point(Vector2(at.x, at.z))
 return Vector3(p.x, at.y, p.y)
static var _prior: Dictionary = {}
static func source_height(p: Vector2) -> float:
 if _prior.is_empty():
  var file = FileAccess.open_compressed("res://assets/world/fixed/prior_compaction_ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
  assert(file != null, "Missing versioned prior geography support")
  _prior = file.get_var(); file.close()
 var q = (p - _prior.origin) / 3; q.x = clampf(q.x, 0, int(_prior.width) - 1.001); q.y = clampf(q.y, 0, int(_prior.height) - 1.001)
 var x = floori(q.x); var z = floori(q.y); var u = q.x - x; var v = q.y - z; var index = (z * int(_prior.width) + x) * 2
 var bytes: PackedByteArray = _prior.heights
 var a = -128.0 + bytes.decode_u16(index) / 64.0; var b = -128.0 + bytes.decode_u16(index + 2) / 64.0
 var c = -128.0 + bytes.decode_u16(index + int(_prior.width) * 2) / 64.0
 if u + v <= 1: return a + (b - a) * u + (c - a) * v
 var d = -128.0 + bytes.decode_u16(index + int(_prior.width) * 2 + 2) / 64.0
 return d + (c - d) * (1 - u) + (b - d) * (1 - v)
static func release_source() -> void: _prior.clear()
static func _floor_delta(at: Vector3) -> float:
 if interior(at): return 0
 var p = Vector2(at.x, at.z); var h = source_height(p)


 if absf(at.y - h) > 0.75: return 0
 return load("res://scripts/water_profile.gd").terrain_height(point(p)) - h
static func _migrated(at: Vector3, clearings: Array, legacy_seed: int = 0) -> Vector3:


 if legacy_seed != 0 and at.y < 0 and not interior(at):
  var room = load("res://scripts/legacy_deep_envelopes.gd").interior_at(at, legacy_seed)
  if not room.is_empty(): return load("res://scripts/locations.gd").INTERIORS[room] + Vector3(0, 0.24, 4)
 if interior(at): return at
 var delta = _floor_delta(at)
 for clearing in clearings:
  var raw: Array = clearing.position; var old = Vector3(raw[0], raw[1], raw[2])
  if Vector2(at.x - old.x, at.z - old.z).length() <= 12 and absf(at.y - old.y) <= 0.8:
   delta = float(clearing.delta); break
 var result = outdoor(at); result.y += delta; return result
static func _migrated_array(raw: Array, clearings: Array, legacy_seed: int = 0) -> Array:
 if interior(Vector3(raw[0], raw[1], raw[2])): return raw.duplicate()
 var p = _migrated(Vector3(raw[0], raw[1], raw[2]), clearings, legacy_seed)


 var delta = p.y - float(raw[1])
 return [p.x, raw[1] if absf(delta) < 1.0e-05 else p.y, p.z]
static func migrate(state, prior_seed: int = 0) -> bool:
 if not state.expanded_world or int(state.geography_revision) >= REVISION: return false
 var legacy_seed = (prior_seed if prior_seed != 0 else int(state.seed_value)) if state.world_id != "mr-justice-world-01" else 0
 var clearings = []
 for record in state.camp_clearings:
  var raw: Array = record.position; var at = Vector3(raw[0], raw[1], raw[2])
  clearings.append({"position": raw.duplicate(), "delta": _floor_delta(at)})
 state.player_position = _migrated(state.player_position, clearings, legacy_seed); state.checkpoint = _migrated(state.checkpoint, clearings, legacy_seed)
 state.camp_position = _migrated(state.camp_position, clearings, legacy_seed); state.workbench_position = _migrated(state.workbench_position, clearings, legacy_seed); state.death_echo_position = _migrated(state.death_echo_position, clearings, legacy_seed)
 for record in state.camp_clearings: record.position = _migrated_array(record.position, clearings, legacy_seed)
 for record in state.world_loot: record.position = _migrated_array(record.position, clearings, legacy_seed)
 state.geography_revision = REVISION
 release_source()
 return true
