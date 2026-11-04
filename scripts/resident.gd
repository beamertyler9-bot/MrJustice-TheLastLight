extends AnimatableBody3D

const B = preload("res://scripts/build.gd")
const ImportedResident = preload("res://scripts/imported_resident.gd")
var imported_actor
const ANIMATION_DISTANCE := 88.0
const GREET_DISTANCE := 3.15

var route := PackedVector3Array()
var route_index := 1
var wait_left := 1.2
var speed := 0.72
var clock := 0.0
var stride := 0.0
var role := "neighbor"
var race := "human"
var body_radius := 0.34
var work_target := Vector3.ZERO
var context: Node
var visual: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var greeting: Label3D
var greeting_time := 0.0
var greeted := false
var forearms: Array[Node3D] = []
var shins: Array[Node3D] = []
var greeting_weight = 0.0
var gait_weight := 0.0
var animation_debt := 0.0
static var sculpt_meshes: Dictionary = {}

func configure(data: Dictionary, waypoints: PackedVector3Array) -> void:
	name = str(data.id)
	for key in ["id", "name", "shop", "dialogue", "race"]:
		set_meta(key, data.get(key, ""))
	set_meta("kind", "npc")
	set_meta("label", "Talk to " + str(data.name))
	set_meta("climbable", false)
	set_meta("greeting", "")
	add_to_group("interactable")
	add_to_group("npc")
	add_to_group("batch_dynamic")
	collision_layer = 8
	collision_mask = 2 | 8
	sync_to_physics = false
	race = str(data.get("race", "human"))
	role = str(data.get("role", "neighbor"))
	route = waypoints
	if not route.is_empty():
		position = route[0]
	work_target = data.get("work_target", position + Vector3(0, 0, 2))
	wait_left = 0.6 + float(absi(hash(name)) % 19) * 0.07
	clock = float(absi(hash(name)) % 71) * 0.13
	speed = 0.55 if race in ["dwarf", "smallfolk"] else 0.72
	make_visual(str(data.get("coat", "#55776d")), str(data.get("accessory", "")))


	set_process(false)
	set_physics_process(false)
	context = get_parent()
	while context != null and not (context.get("mode") is String):
		context = context.get_parent()

func tick(dt: float, player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var distance := global_position.distance_squared_to(player.global_position)
	if distance > ANIMATION_DISTANCE * ANIMATION_DISTANCE:
		if visual.visible: visual.visible = false
		if greeting.visible: greeting.visible = false
		animation_debt = 0.0
		return
	if not visual.visible: visual.visible = true


	if is_instance_valid(context) and str(context.get("mode")) != "play":
		greeting.visible = false
		return
	var step := clampf(dt, 0.0, 0.1)


	if distance > 28.0 * 28.0:
		animation_debt += step
		var interval := 1.0 / 15.0 if distance > 48.0 * 48.0 else 1.0 / 24.0
		if animation_debt < interval: return
		step = minf(0.1, animation_debt)
	animation_debt = 0.0
	clock += step
	var near := distance < GREET_DISTANCE * GREET_DISTANCE
	if near:
		if not greeted:
			greeted = true
			greeting_time = 2.8
			set_meta("greeting", "Need a good blade?" if role == "smith" else "Good to see you!")
		greeting_time = maxf(0.0, greeting_time - step)
		greeting.text = str(get_meta("greeting"))
		greeting.visible = greeting_time > 0
		face(player.global_position, step, 4.5)
		animate(step, false, greeting_time > 1.25)
		return
	if distance > 25.0:
		greeted = false
	greeting.visible = false
	if route.size() < 2:
		animate(step, false, false)
		return
	var moving := false
	if wait_left > 0:
		wait_left = maxf(0.0, wait_left - step)
		face(get_parent().to_global(work_target), step, 2.0)
	else:
		var target := route[route_index]
		var offset := target - position
		var length := offset.length()
		if length < 0.035:
			position = target
			route_index = (route_index + 1) % route.size()
			wait_left = 2.4 if route_index == 1 else 0.65
		else:
			face(get_parent().to_global(target), step, 5.0)
			position += offset / length * minf(length, speed * step)
			moving = true
	animate(step, moving, false)

func face(point: Vector3, dt: float, turn_speed: float) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), minf(1.0, dt * turn_speed))

func animate(dt: float, moving: bool, greeting_pose: bool) -> void:
	if imported_actor != null:
		imported_actor.travel_speed = speed
		imported_actor.animate(dt, moving, greeting_pose)

func make_visual(coat: String, _accessory: String) -> void:
	var presenter = ImportedResident.new()
	if presenter.attach(self, coat): imported_actor = presenter
	else: push_error("No modern resident model for " + race + " / " + str(name))
