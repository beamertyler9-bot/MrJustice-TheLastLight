extends RefCounted


static func project(point: Vector3, a: Vector3, b: Vector3, radius: float) -> Vector3:
	if point.distance_to(a) <= radius and point.distance_to(b) <= radius: return point
	var on_a = a + (point - a).limit_length(radius)


	if a.distance_squared_to(b) < 1.0e-10: return on_a
	if on_a.distance_to(b) <= radius + 1.0e-06: return on_a
	var on_b = b + (point - b).limit_length(radius)
	if on_b.distance_to(a) <= radius + 1.0e-06: return on_b
	var centre = (a + b) * 0.5
	var axis = (b - a).normalized()
	var circle_radius = sqrt(maxf(0.0, radius * radius - a.distance_squared_to(b) * 0.25))
	var radial = (point - centre).slide(axis)
	if radial.length_squared() < 1.0e-06: radial = Vector3.FORWARD.slide(axis)
	if radial.length_squared() < 1.0e-06: radial = Vector3.UP.slide(axis)
	return centre + radial.normalized() * circle_radius
