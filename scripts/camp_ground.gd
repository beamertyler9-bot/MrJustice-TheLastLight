extends RefCounted

const INNER := 5.2
const OUTER := 6.8
const REGROW_SECONDS := 180.0
const LIMIT := 8
var state
var completed: Dictionary = {}
var dirty_positions: Array[Vector2] = []
func setup(data) -> void: state = data
static func valid(raw: Variant) -> bool:
 if not raw is Array or raw.size() > LIMIT: return false
 for record in raw:
  if not record is Dictionary or not record.has("packed_at") or not record.get("position") is Array or record.position.size() != 3: return false
  for n in record.position:
   if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n)) > 100000: return false
  var time: Variant = record.get("packed_at", -1)
  if not (time is int or time is float) or not is_finite(float(time)) or float(time) < -1 or float(time) > 1000000000000.0: return false
 return true
func place(point: Vector3) -> Vector3:
 dirty_positions.append(Vector2(point.x, point.z))
 pack()
 for i in range(state.camp_clearings.size() - 1, -1, -1):
  var record = state.camp_clearings[i]
  if Vector2(record.position[0] - point.x, record.position[2] - point.z).length() < 0.5:
   dirty_positions.append(Vector2(record.position[0], record.position[2])); completed.erase(str(record.position)); state.camp_clearings.remove_at(i)
 state.camp_clearings.append({"position": [point.x, point.y - 0.025, point.z], "packed_at": -1.0})
 while state.camp_clearings.size() > LIMIT:
  var removed = state.camp_clearings.pop_front()
  dirty_positions.append(Vector2(removed.position[0], removed.position[2])); completed.erase(str(removed.position))
 state.camp_position = point; state.camp_placed = true
 return point
func pack() -> void:
 for record in state.camp_clearings:
  if float(record.packed_at) < 0: record.packed_at = state.journey_time
func near_point(point: Vector2, margin: float = 0.0) -> bool:
 for record in state.camp_clearings:
  if point.distance_to(Vector2(record.position[0], record.position[2])) <= OUTER + margin: return true
 return false
func fine_cell(left: float, near: float) -> bool:

 return near_point(Vector2(left + 1.5, near + 1.5), 4.3)
func height_for(point: Vector2, base: float) -> float:
 var h = base
 for record in state.camp_clearings:
  var distance = point.distance_to(Vector2(record.position[0], record.position[2]))
  if distance < OUTER: h = lerpf(h, float(record.position[1]), 1.0 - smoothstep(INNER, OUTER, distance))
 return h
func growth(record: Dictionary) -> float:
 return 1.0 if float(record.packed_at) < 0 else 1.0 - smoothstep(0.0, REGROW_SECONDS, maxf(0, state.journey_time - float(record.packed_at)))
func soil_weight(point: Vector2) -> float:
 var result := 0.0
 for record in state.camp_clearings:
  var distance = point.distance_to(Vector2(record.position[0], record.position[2]))
  result = maxf(result, (1.0 - smoothstep(4.4, 6.2, distance)) * growth(record))
 return result
func grass_blocked(point: Vector2, clearance: float) -> bool:
 for record in state.camp_clearings:
  if growth(record) > 0.001 and point.distance_to(Vector2(record.position[0], record.position[2])) < 4.65 + clearance: return true
 return false
func shader_records() -> PackedVector4Array:
 var result := PackedVector4Array()
 for record in state.camp_clearings: result.append(Vector4(record.position[0], record.position[2], growth(record), 0))
 while result.size() < LIMIT: result.append(Vector4.ZERO)
 return result
func newly_regrown() -> bool:
 var changed := false
 for record in state.camp_clearings:
  var key = str(record.position)
  if float(record.packed_at) >= 0 and growth(record) <= 0.001 and not completed.has(key):
   completed[key] = true; changed = true; dirty_positions.append(Vector2(record.position[0], record.position[2]))
 return changed
