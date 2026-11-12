extends RefCounted

const HOLD_SECONDS := 0.24
const SPEED := 22.0
const GLIDE_SPEED := 13.0
const MAX_ALTITUDE := 1600.0
const BOOST_TAP_WINDOW := 0.3
const BOOST_DURATION := 1.35
const BOOST_WINDUP := 0.14
const BOOST_SPEED := 58.0
const BOOST_RECOVERY := 3.0
const BOOST_RAMP := 0.35        # seconds to build from flying speed up to boost speed
const NEUTRAL_PITCH := 0.18     # the camera's resting tilt: boosting there flies level
const BOOST_CLIMB := 0.55       # how steeply looking up or down can climb or dive
var enabled := false
var armed := false
var held := false
var active := false
var hold_age := 0.0
var age := 0.0
var boost_left := 0.0
var boost_age := 0.0
var boost_recovery := 0.0
var _tap_window := 0.0
var _boost_pending := false

func set_enabled(value: bool) -> void:
	enabled = value
	cancel()

func set_jump(value: bool) -> void:
	if value == held: return
	held = value
	if not value:
		if boost_left > 0.0: boost_recovery = BOOST_RECOVERY
		boost_left = 0.0
		boost_age = 0.0
		hold_age = 0.0
		return
	if not active: return
	if boost_left > 0.0 or boost_recovery > 0.0:
		_tap_window = 0.0
		return
	if _tap_window > 0.0:
		boost_left = BOOST_DURATION
		boost_age = 0.0
		_boost_pending = true
		_tap_window = 0.0
	else: _tap_window = BOOST_TAP_WINDOW

func note_double_jump() -> void:
	if enabled:
		armed = true
		hold_age = 0.0

func tick(dt: float, allowed: bool, grounded: bool) -> bool:
	if not is_finite(dt) or dt <= 0.0: return false
	if not enabled or not allowed or grounded:
		cancel()
		return false
	if active:
		age += dt
		if boosting():
			boost_age += dt
			boost_left -= dt
			if boost_left <= 0.0:
				# The boost runs its course, then eases back to normal flight.
				boost_left = 0.0
				boost_recovery = BOOST_RECOVERY
		boost_recovery = maxf(0.0, boost_recovery - dt)
		_tap_window = maxf(0.0, _tap_window - dt)
		return false
	if armed and held:
		hold_age += dt
		if hold_age >= HOLD_SECONDS:
			active = true
			age = 0.0
			return true
	return false

func powered() -> bool:
	return enabled and active and held

func boosting() -> bool:
	return enabled and active and held and boost_left > 0.0

func thrusting() -> bool:
	return boosting() and boost_age >= BOOST_WINDUP

func consume_boost() -> bool:
	var result := _boost_pending
	_boost_pending = false
	return result

func suspend_input() -> void:
	if boosting(): boost_recovery = BOOST_RECOVERY
	boost_age = 0.0
	held = false
	hold_age = 0.0
	_tap_window = 0.0
	boost_left = 0.0
	_boost_pending = false

func boost_direction(stick: Vector2, yaw: float, pitch := 0.0) -> Vector3:
	if not stick.is_finite() or not is_finite(yaw) or not is_finite(pitch): return Vector3.ZERO

	# Level flight at the camera's resting tilt; look further up or down to climb or dive.
	var tilt := clampf(pitch - NEUTRAL_PITCH, -BOOST_CLIMB, BOOST_CLIMB)
	return Vector3(-sin(yaw) * cos(tilt), -sin(tilt), -cos(yaw) * cos(tilt))

func desired_velocity(stick: Vector2, yaw: float, pitch: float) -> Vector3:
	if not active or not stick.is_finite() or not is_finite(yaw) or not is_finite(pitch): return Vector3.ZERO
	stick = stick.limit_length()
	if boosting():
		# No stall before the burst: speed builds smoothly from flying speed to boost speed.
		return boost_direction(stick, yaw, pitch) * lerpf(SPEED, BOOST_SPEED, smoothstep(0.0, BOOST_RAMP, boost_age))
	if stick.length() < 0.12: return Vector3.ZERO
	var speed := SPEED if powered() else GLIDE_SPEED
	var forward := boost_direction(stick, yaw, pitch)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return (right * stick.x - forward * stick.y) * speed

func cancel() -> void:
	boost_age = 0.0
	armed = false
	held = false
	active = false
	hold_age = 0.0
	age = 0.0
	boost_left = 0.0
	boost_recovery = 0.0
	_tap_window = 0.0
	_boost_pending = false
