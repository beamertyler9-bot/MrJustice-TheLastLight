extends RefCounted

const Fixed = preload("res://scripts/fixed_world.gd")
var data: Dictionary
var compact := false
func _init():
 data = FileAccess.open("res://assets/world/fixed/prior_ground.bin", FileAccess.READ).get_var()
 assert(data.from_revision == 31 and data.to_revision == 32)
 compact = int(Fixed.metadata().get("geography_revision", 0)) > 0
func _vertex(cell: Vector2i) -> float:
 var index = cell.y * int(data.width) + cell.x; var ids: PackedInt32Array = data.indices
 var low = 0; var high = ids.size()
 while low < high:
  var middle = (low + high) / 2
  if ids[middle] < index: low = middle + 1
  else: high = middle
 if low < ids.size() and ids[low] == index: return -128.0 + data.heights.decode_u16(low * 2) / 64.0
 var at: Vector2 = data.origin + Vector2(cell) * 3
 if compact: return load("res://scripts/compact_geography.gd").source_height(at)
 return Fixed.height_at(at)
func height_at(point: Vector2) -> float:
 var q = (point - data.origin) / 3
 q.x = clampf(q.x, 0, int(data.width) - 1.001); q.y = clampf(q.y, 0, int(data.height) - 1.001)
 var cell = Vector2i(q.floor()); var u = q.x - cell.x; var v = q.y - cell.y
 var a = _vertex(cell); var b = _vertex(cell + Vector2i(1, 0)); var c = _vertex(cell + Vector2i(0, 1))
 if u + v <= 1: return a + (b - a) * u + (c - a) * v
 var d = _vertex(cell + Vector2i.ONE)
 return d + (c - d) * (1 - u) + (b - d) * (1 - v)
