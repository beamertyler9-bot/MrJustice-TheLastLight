extends Node
## Game-feel director: hit stop, phone vibration and impact squash.
##
## Hit stop briefly slows the whole game (Engine.time_scale) when a blow lands, which is
## what makes hits read as heavy. It is timed in real milliseconds so it always ends,
## overlapping requests extend rather than stack, and it never runs outside gameplay.
## Vibration and squash respect the "camera shake" accessibility setting.

const STOP_SCALE := 0.06
const MAX_STOP := 0.14

var game
var _stop_until_ms := 0
var _stopping := false
var _rumble_ready_ms := 0


func setup(owner_game) -> void:
	game = owner_game
	name = "GameFeel"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _shake_allowed() -> bool:
	return game == null or game.state == null or bool(game.state.settings.get("camera_shake", true))


func hit_stop(duration: float) -> void:
	if game == null or str(game.get("mode")) != "play" or duration <= 0.0: return
	var until := Time.get_ticks_msec() + int(minf(duration, MAX_STOP) * 1000.0)
	_stop_until_ms = maxi(_stop_until_ms, until)
	if not _stopping:
		_stopping = true
		Engine.time_scale = STOP_SCALE


func rumble(ms: int, strength: float) -> void:
	if not OS.has_feature("mobile") or not _shake_allowed(): return
	var now := Time.get_ticks_msec()
	if now < _rumble_ready_ms: return
	_rumble_ready_ms = now + 40
	Input.vibrate_handheld(clampi(ms, 8, 120), clampf(strength, 0.05, 1.0))


## Quick squash-and-stretch pop on whatever was hit (its model if it exposes one).
func squash(target: Node, strength: float = 1.0) -> void:
	if not is_instance_valid(target) or not _shake_allowed(): return
	var body: Node3D = null
	for key in ["model", "visual", "rig"]:
		var candidate = target.get(key)
		if candidate is Node3D and is_instance_valid(candidate): body = candidate; break
	if body == null or body.has_meta("feel_squashing"): return
	# Defeated targets play their own shrink-away; don't fight it.
	var health = target.get("health")
	if health != null and int(health) <= 0: return
	var base: Vector3 = body.scale
	if base.length() < 0.01: return
	body.set_meta("feel_squashing", true)
	var s := clampf(strength, 0.2, 1.2)
	var tween := body.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(body, "scale", base * Vector3(1.0 + 0.16 * s, 1.0 - 0.18 * s, 1.0 + 0.16 * s), 0.045)
	tween.tween_property(body, "scale", base * Vector3(1.0 - 0.06 * s, 1.0 + 0.08 * s, 1.0 - 0.06 * s), 0.07)
	tween.tween_property(body, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		if is_instance_valid(body): body.remove_meta("feel_squashing"))


func _process(_dt: float) -> void:
	if not _stopping: return
	var leaving_play: bool = game == null or str(game.get("mode")) != "play"
	if Time.get_ticks_msec() >= _stop_until_ms or leaving_play:
		_stopping = false
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	if _stopping: Engine.time_scale = 1.0
