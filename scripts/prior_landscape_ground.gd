extends RefCounted

var data: Dictionary
func _init():
	data = FileAccess.open_compressed("res://assets/world/fixed/prior_landscape.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD).get_var()
static func supported_by(point: Vector3, clearing: Vector3) -> bool:
	return Vector2(point.x - clearing.x, point.z - clearing.z).length() <= 5.2 and point.y >= clearing.y - 0.5 and point.y <= clearing.y + 3.0
static func rebase_clearings(state):
	var shifts = []
	for record in state.camp_clearings:
		var raw: Array = record.position; var old_point = Vector3(raw[0], raw[1], raw[2])
		var height: float = preload("res://scripts/water_profile.gd").terrain_height(Vector2(old_point.x, old_point.z))
		shifts.append({"point": old_point, "delta": height - old_point.y}); record.position = [old_point.x, height, old_point.z]
	for field in ["player_position", "checkpoint", "camp_position", "workbench_position", "death_echo_position"]:
		if field == "camp_position" and not state.camp_placed: continue
		if field == "workbench_position" and not state.workbench_placed: continue
		if field == "death_echo_position" and not state.death_echo_active: continue
		var point: Vector3 = state.get(field)
		for shift in shifts:
			if supported_by(point, shift.point): point.y += float(shift.delta); break
		state.set(field, point)
	for record in state.world_loot:
		var raw: Array = record.position; var point = Vector3(raw[0], raw[1], raw[2])
		for shift in shifts:
			if supported_by(point, shift.point): point.y += float(shift.delta); break
		record.position = [point.x, point.y, point.z]
func height_at(p: Vector2) -> float:
	var q: Vector2 = (p - data.origin) / 3.0
	q.x = clampf(q.x, 0, int(data.width) - 1.001); q.y = clampf(q.y, 0, int(data.height) - 1.001)
	var x = floori(q.x); var z = floori(q.y); var u = q.x - x; var v = q.y - z; var i = (z * int(data.width) + x) * 2
	var bytes: PackedByteArray = data.heights
	var a = bytes.decode_u16(i) / 64.0 - 128.0; var b = bytes.decode_u16(i + 2) / 64.0 - 128.0; var c = bytes.decode_u16(i + int(data.width) * 2) / 64.0 - 128.0
	if u + v <= 1: return a + (b - a) * u + (c - a) * v
	var d = bytes.decode_u16(i + int(data.width) * 2 + 2) / 64.0 - 128.0
	return d + (c - d) * (1 - u) + (b - d) * (1 - v)
