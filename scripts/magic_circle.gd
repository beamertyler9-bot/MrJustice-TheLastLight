extends Node3D
## The element's animated magic circle (assets/magic_circles, painted flipbooks).
## Appears where a spell is cast: in front of the casting hand (or lantern) facing the aim,
## and flat on the ground under spells that land on an area. Pops open, turns, fades out.

const SHEETS := {
	"flame": preload("res://assets/magic_circles/flame.png"), "frost": preload("res://assets/magic_circles/frost.png"),
	"storm": preload("res://assets/magic_circles/storm.png"), "grove": preload("res://assets/magic_circles/grove.png"),
	"light": preload("res://assets/magic_circles/light.png"), "shadow": preload("res://assets/magic_circles/shadow.png"),
	"water": preload("res://assets/magic_circles/water.png"), "wind": preload("res://assets/magic_circles/wind.png"),
	"earth": preload("res://assets/magic_circles/earth.png"), "metal": preload("res://assets/magic_circles/metal.png"),
	"void": preload("res://assets/magic_circles/void.png"), "time": preload("res://assets/magic_circles/time.png")}
const SHADER = preload("res://shaders/magic/magic_circle.gdshader")
static var _quad: QuadMesh
static var _materials: Dictionary = {}

var life := 0.8
var age := 0.0
var size := 1.0
var spin := 1.0
## Held circles (spell charging) stay until released; their size is driven from outside.
var held := false
## While this returns true (the spell is still active) the circle stays at full strength.
var keep_while := Callable()
const POP := 0.22
const FADE := 0.45
const MAX_HOLD := 16.0
var _card: MeshInstance3D
var _material: ShaderMaterial


static func element_of(spell: Dictionary) -> String:
	var element := str(spell.get("element", "light"))
	if element == "gravity": element = "void"
	return element if SHEETS.has(element) else "light"


## A circle standing up in front of a point, facing `direction` (the hand / lantern cast).
static func at_hand(parent: Node, spell: Dictionary, point: Vector3, direction: Vector3, radius: float, duration: float = 0.8) -> Node3D:
	var circle = load("res://scripts/magic_circle.gd").new()
	circle.configure(element_of(spell), radius, duration)
	parent.add_child(circle)
	circle.place_facing(point, direction)
	return circle


## A circle lying flat on the ground (area spells, at the target).
static func on_ground(parent: Node, spell: Dictionary, point: Vector3, radius: float, duration: float = 1.0) -> Node3D:
	var circle = load("res://scripts/magic_circle.gd").new()
	circle.configure(element_of(spell), radius, duration)
	parent.add_child(circle)
	circle.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), point + Vector3.UP * 0.06)
	return circle


## A circle hanging flat in the sky, seen from below (rain spells pour out of it).
static func in_sky(parent: Node, spell: Dictionary, point: Vector3, radius: float, duration: float = 2.0, viewer: Vector3 = Vector3.INF) -> Node3D:
	var circle = load("res://scripts/magic_circle.gd").new()
	circle.configure(element_of(spell), radius, duration)
	parent.add_child(circle)
	# Flat and level, facing straight down at the ground it rains on.
	circle.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), point)
	return circle


func configure(element: String, radius: float, duration: float) -> void:
	size = clampf(radius, 0.2, 6.0); life = clampf(duration, 0.3, 12.0)
	if _quad == null:
		_quad = QuadMesh.new(); _quad.size = Vector2.ONE * 2.0
	if not _materials.has(element):
		var material := ShaderMaterial.new(); material.shader = SHADER
		material.set_shader_parameter("sheet", SHEETS[element])
		_materials[element] = material
	# Each circle fades on its own, so it gets its own copy of the shared material.
	_material = (_materials[element] as ShaderMaterial).duplicate()
	spin = 1.0 if element != "time" else -0.6


func _ready() -> void:
	name = "MagicCircle"
	top_level = true
	_card = MeshInstance3D.new(); _card.mesh = _quad; _card.material_override = _material
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _card.extra_cull_margin = 2.0
	add_child(_card)
	_update()


func place_facing(point: Vector3, direction: Vector3) -> void:
	var z := -direction.normalized()
	if z.length_squared() < 0.5: z = Vector3.BACK
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1.0e-4: x = Vector3.RIGHT
	x = x.normalized()
	global_transform = Transform3D(Basis(x, z.cross(x).normalized(), z), point)


## Charging: show the circle at `amount` of its full size (0..1) without aging out.
func set_charge(amount: float) -> void:
	held = true
	_card.scale = Vector3.ONE * size * lerpf(0.25, 1.0, smoothstep(0.0, 1.0, amount))
	_material.set_shader_parameter("opacity", lerpf(0.5, 1.0, amount))


## Let go of a charging circle: it stays fully open, then fades (or keeps going while
## `keep_while` says the spell is still active).
func release() -> void:
	held = false
	_hold_age = 0.0
	age = POP
	life = maxf(life, POP + FADE + 0.3)


## Keep the circle up for as long as `check` returns true (the spell is still active).
func keep_alive(check: Callable) -> void:
	keep_while = check


var _hold_age := 0.0
var _clock := 0.0

func _process(dt: float) -> void:
	_clock += dt
	_card.rotate_object_local(Vector3.BACK, dt * spin * (2.4 if held else 1.2))
	_material.set_shader_parameter("clock", _clock)
	if held: return
	_hold_age += dt
	var plateau := maxf(life - FADE, POP)
	if age + dt >= plateau and _hold_age < MAX_HOLD and keep_while.is_valid() and bool(keep_while.call()):
		# Still active: stay fully open at the start of the fade.
		age = maxf(age, plateau)
	else:
		age += dt
	if age >= life:
		queue_free(); return
	_update()


func _update() -> void:
	var pop := smoothstep(0.0, POP, age)
	var overshoot := 1.0 + sin(clampf(age / 0.35, 0.0, 1.0) * PI) * 0.12
	_card.scale = Vector3.ONE * size * maxf(pop * overshoot, 0.01)
	_material.set_shader_parameter("opacity", 1.0 - smoothstep(maxf(life - FADE, POP), life, age))
