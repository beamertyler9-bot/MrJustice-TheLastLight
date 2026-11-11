extends RefCounted

const F = preload("res://scripts/fixed_world.gd")
var data: Dictionary
func _init(revision: int = 33):
 data = FileAccess.open_compressed("res://assets/world/fixed/terrain-patch-35.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD).get_var()
 if revision < 34:
  var older = FileAccess.open_compressed("res://assets/world/fixed/terrain-patch-34.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD).get_var()
  for index in older.old_samples: data.old_samples[index] = older.old_samples[index]
func _sample(x: int, z: int) -> float:
 var index = z * int(data.width) + x
 if data.old_samples.has(index): return float(data.old_samples[index]) / 64.0 - 128.0
 return F.height_at(data.origin + Vector2(x, z) * 3)
func height_at(p: Vector2) -> float:
 var q = (p - data.origin) / 3.0; q.x = clampf(q.x, 0, data.width - 1.001); q.y = clampf(q.y, 0, data.height - 1.001)
 var x = floori(q.x); var z = floori(q.y); var u = q.x - x; var v = q.y - z
 var a = _sample(x, z); var b = _sample(x + 1, z); var c = _sample(x, z + 1)
 if u + v <= 1: return a + (b - a) * u + (c - a) * v
 var d = _sample(x + 1, z + 1); return d + (c - d) * (1 - u) + (b - d) * (1 - v)
