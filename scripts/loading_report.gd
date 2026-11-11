extends RefCounted

var path: String
var data: Dictionary = {}
var started: int = 0
var _last_write_ms := -1000
func _init(report_path: String = "user://loading-report.json") -> void: path = report_path
func begin(continuing: bool) -> void:
	started = Time.get_ticks_msec()
	data = {"version": ProjectSettings.get_setting("application/config/version"), "engine": Engine.get_version_info().string, "device": OS.get_model_name(), "system": OS.get_name(), "system_version": OS.get_version(), "graphics": RenderingServer.get_video_adapter_name(), "continuing": continuing, "status": "loading", "phase": "Starting journey", "phases": []}
	var exits = preload("res://scripts/android_exit_report.gd").read_history()
	if not exits.is_empty(): data["previous_android_exits"] = exits
	mark("Starting journey", 0)
func mark(stage: String, nodes: int) -> void:
	if data.is_empty(): return
	data.phase = stage
	data.phases.append({"phase": stage, "elapsed_ms": Time.get_ticks_msec() - started, "nodes": nodes, "static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "system_available_bytes": OS.get_memory_info().get("available", -1)})
	if data.status != "ready" and Time.get_ticks_msec() - _last_write_ms < 350: return
	_last_write_ms = Time.get_ticks_msec()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data, "\t")); file.close()
func finish(nodes: int) -> void:
	data.status = "ready"; mark("Ready", nodes)
func text() -> String:
	var contents = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "No journey has been loaded in this build yet."
	var exits = preload("res://scripts/android_exit_report.gd").read_history()
	if exits.is_empty(): return contents
	var report = JSON.parse_string(contents)
	if not report is Dictionary: report = {"phase": "No journey report yet"}
	report["previous_android_exits"] = exits
	return JSON.stringify(report, "\t")
