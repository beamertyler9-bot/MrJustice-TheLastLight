extends Node
## Keeps frame pacing steady on phones.
##
## Adaptive resolution: when the GPU is the bottleneck (frames are slow but the CPU work for
## the frame is comfortably below the frame time), the 3D view renders at a lower internal
## resolution; when there is headroom it climbs back towards the quality ceiling. The HUD is
## unaffected. Changes are small and rate-limited so they are not visible as popping.

const TARGET_MS := 16.7
const STEP := 0.05
const MIN_SCALE := 0.5
const SETTLE_SECONDS := 0.75

var ceiling := 0.85
var scale := 0.85
var _frame_ms := TARGET_MS
var _cpu_ms := 0.0
var _last_usec := 0
var _settle := 1.5


func _ready() -> void:
	name = "FrameGovernor"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000


func set_ceiling(value: float) -> void:
	ceiling = clampf(value, MIN_SCALE, 1.0)
	scale = minf(scale, ceiling) if scale > 0.0 else ceiling
	if scale < MIN_SCALE: scale = ceiling
	_apply()


func _apply() -> void:
	get_viewport().scaling_3d_scale = scale


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		var ms := (now - _last_usec) / 1000.0
		if ms < 250.0: _frame_ms = lerpf(_frame_ms, ms, 0.08)
	_last_usec = now
	var cpu := (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	_cpu_ms = lerpf(_cpu_ms, cpu, 0.08)
	_settle -= _dt / maxf(Engine.time_scale, 0.01)
	if _settle > 0.0: return
	var gpu_bound := _frame_ms > TARGET_MS * 1.08 and _cpu_ms < _frame_ms * 0.62
	if gpu_bound and scale > MIN_SCALE + 0.001:
		scale = maxf(MIN_SCALE, scale - STEP); _apply(); _settle = SETTLE_SECONDS
	elif _frame_ms < TARGET_MS * 0.86 and scale < ceiling - 0.001:
		scale = minf(ceiling, scale + STEP * 0.5); _apply(); _settle = SETTLE_SECONDS * 2.0


func debug_text() -> String:
	return "frame %.1f ms  cpu %.1f ms  3D scale %.2f" % [_frame_ms, _cpu_ms, scale]
