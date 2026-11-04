extends RefCounted


const REASONS = ["unknown", "self_exit", "signal", "low_memory", "java_crash", "native_crash", "not_responding", "initialization_failure", "permission_changed", "resource_usage", "user_requested", "user_stopped", "dependency_died", "other", "freezer", "package_state_changed", "package_updated"]
static func reason_name(code: int) -> String:
	return REASONS[code] if code >= 0 and code < REASONS.size() else "reason_" + str(code)

static func read_history() -> Array:
	var result = []
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"): return result
	var bridge = Engine.get_singleton("JavaClassWrapper")
	var version = bridge.wrap("android.os.Build$VERSION")
	if bridge.get_exception() != null or version == null: return result
	var sdk: int = version.SDK_INT
	if sdk < 30: return result
	var context = Engine.get_singleton("AndroidRuntime").getApplicationContext()
	if bridge.get_exception() != null or context == null: return result
	var manager = context.getSystemService("activity")
	if bridge.get_exception() != null or manager == null: return result
	var package_name = context.getPackageName()
	var history = manager.getHistoricalProcessExitReasons(package_name, 0, 4)
	if bridge.get_exception() != null or history == null: return result
	var count: int = history.size()
	for i in range(mini(count, 4)):
		var entry = history.get(i)
		if bridge.get_exception() != null or entry == null: break
		var code: int = entry.getReason()
		var row = {"reason": reason_name(code), "reason_code": code, "status": entry.getStatus(), "rss_kb": entry.getRss(), "pss_kb": entry.getPss(), "timestamp_ms": entry.getTimestamp()}
		if bridge.get_exception() != null: break
		if code == 5 and sdk >= 33:
			var stream = entry.getTraceInputStream()
			if bridge.get_exception() == null and stream != null:
				var bytes = stream.readNBytes(262144)
				var readable = bridge.get_exception() == null
				stream.close(); bridge.get_exception()
				if readable and bytes is PackedByteArray:
					if bytes.size() == 262144: row["native_trace_truncated"] = true
					var trace = decode_tombstone(bytes)
					if not trace.is_empty(): row["native_trace"] = trace
		result.append(row)
	return result



static func decode_tombstone(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > 262144: return {}


	var top = _fields(bytes, true, [16])
	if top.is_empty(): return {}
	var result = {}; var signal_fields = _fields(_first(top, 10, PackedByteArray()))
	result["signal"] = _string(_first(signal_fields, 2, PackedByteArray()))
	var message = _string(_first(top, 14, PackedByteArray()))
	if not message.is_empty(): result["abort_message"] = message
	var tid = _first(top, 6, 0)
	for raw in top.get(16, []):
		var item = _fields(raw, true, [2])
		if _first(item, 1, -1) != tid: continue
		var thread = _fields(_first(item, 2, PackedByteArray()), true)
		result["thread"] = _string(_first(thread, 2, PackedByteArray()))
		var frames = []
		for frame_raw in thread.get(4, []).slice(0, 12):
			var frame = _fields(frame_raw)
			var pc = _first(frame, 1, 0)
			frames.append({"library": _string(_first(frame, 6, PackedByteArray())), "function": _string(_first(frame, 4, PackedByteArray())), "relative_pc": "%x" % (pc if pc is int else 0)})
		result["frames"] = frames; break
	return result if not result.get("signal", "").is_empty() else {}

static func _first(fields: Dictionary, id: int, fallback: Variant) -> Variant:
	return fields[id][0] if fields.has(id) and not fields[id].is_empty() else fallback
static func _string(bytes: Variant) -> String:
	return bytes.slice(0, 512).get_string_from_utf8() if bytes is PackedByteArray else ""
static func _varint(bytes: PackedByteArray, state: Array) -> int:
	var value = 0
	for shift in range(0, 70, 7):
		if state[0] >= bytes.size(): state[1] = true; return 0
		var b = bytes[state[0]]; state[0] += 1
		value |= (b & 127) << shift
		if b < 128: return value
	state[1] = true; return 0
static func _fields(bytes: Variant, prefix: bool = false, partial_messages: Array = []) -> Dictionary:
	if not bytes is PackedByteArray: return {}
	var result = {}; var state = [0, false]; var count = 0
	while state[0] < bytes.size() and not state[1]:
		count += 1
		if count > 16384: return {}
		var tag = _varint(bytes, state); var id = tag >> 3; var wire = tag & 7; var value: Variant
		if state[1]: return result if prefix else {}
		if id < 1: return {}
		match wire:
			0: value = _varint(bytes, state)
			2:
				var size = _varint(bytes, state)
				if state[1] or size < 0: return result if prefix else {}
				if size > bytes.size() - state[0]:


					if prefix and id in partial_messages and state[0] < bytes.size():
						if not result.has(id): result[id] = []
						result[id].append(bytes.slice(state[0]))
					return result if prefix else {}
				value = bytes.slice(state[0], state[0] + size); state[0] += size
			1, 5:
				state[0] += 8 if wire == 1 else 4
				if state[0] > bytes.size(): return result if prefix else {}
				continue
			_: return {}
		if state[1]: return result if prefix else {}
		if not result.has(id): result[id] = []
		result[id].append(value)
	return result
