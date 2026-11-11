extends RefCounted
static func closest(node: Node3D, point: Vector3) -> Vector3:
 var best = node.global_position; var distance = INF
 for child in node.find_children("*", "CollisionShape3D", true, false):
  if child.disabled or child.shape == null: continue
  var local = child.to_local(point); var q = Vector3.ZERO
  if child.shape is CapsuleShape3D:
   var shape = child.shape; var half = maxf(0, shape.height / 2 - shape.radius)
   var axis = Vector3(0, clampf(local.y, -half, half), 0); var offset = local - axis
   q = axis + offset.limit_length(shape.radius)
  elif child.shape is SphereShape3D: q = local.limit_length(child.shape.radius)
  elif child.shape is BoxShape3D: q = local.clamp(-child.shape.size / 2, child.shape.size / 2)
  else: continue
  q = child.to_global(q)
  if point.distance_squared_to(q) < distance: distance = point.distance_squared_to(q); best = q
 return best
