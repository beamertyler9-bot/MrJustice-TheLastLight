extends RefCounted

var points: Dictionary = {}
var primary := -1

func begin(id: int, point: Vector2) -> bool:
	if id < 0 or not point.is_finite() or points.has(id) or points.size() >= 2: return false
	points[id] = point
	if primary == -1: primary = id
	return true

func owns(id: int) -> bool:
	return points.has(id)

func drag(id: int, point: Vector2) -> Dictionary:
	if not points.has(id) or not point.is_finite(): return {}
	var previous: Vector2 = points[id]
	if points.size() == 1:
		points[id] = point
		return {"look": point - previous}
	var other: int = int(points.keys()[0])
	if other == id: other = int(points.keys()[1])
	var before := previous.distance_to(points[other])
	points[id] = point
	var after := point.distance_to(points[other])

	if before < 16.0 or after < 16.0: return {}
	return {"zoom": clampf(log(before / after) * 3.5, -1.5, 1.5)}

func end(id: int) -> void:
	points.erase(id)
	if primary == id: primary = int(points.keys()[0]) if not points.is_empty() else -1

func clear() -> void:
	points.clear()
	primary = -1
