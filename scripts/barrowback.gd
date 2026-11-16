extends Node3D
## Barrowback, the walking hill: one enormous, friendly giant of earth and roots carrying a
## grassy hill on its back, with a ring of standing stones and three trees on top. It never
## fights; it plods for ever round a long loop through Mosswake Valley, the Windbell Plains,
## Prismere, the Sunspire Dunes and S'morewood (assets/world/barrowback_route.json, made by
## tools/barrowback_route.gd), steering wide of every town, village and site.
##
## It is solid: Mr. Justice can climb the curtain of roots hanging down its right side up
## onto its back and walk about among the stones and trees, and it carries him along as it
## walks. Where it is on its loop follows the journey clock, so it carries on from save to save.

const MODEL := "res://assets/creatures/barrowback.scn"
const ROUTE := "res://assets/world/barrowback_route.json"
## How many times bigger than its sculpt it stands (its back is about 40 m up).
const GROWTH := 12.0
## Walking pace along its loop, metres per second (about two and a half hours a lap).
const SPEED := 1.6
## Metres covered in one full left-right stride.
const STRIDE := 18.0
## Where on its loop it starts, so it isn't standing by Mosswake when a journey begins.
const START := 2400.0

var game
var model: Node3D
var points := PackedVector2Array()
var marks := PackedFloat32Array()
var total := 0.0
var size := 1.0
var head: Node3D
var hips: Array = []
var knees: Array = []
var arms: Array = []
var forearms: Array = []
var fronds: Array = []
## Each solid part: [AnimatableBody3D, the node it follows].
var followers: Array = []
var curtain: AnimatableBody3D
var clock := 0.0
var bob := 0.0


func setup(context) -> void:
	game = context
	name = "Barrowback"
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROUTE))
	if not data is Dictionary: return
	for q in data.points: points.append(Vector2(q[0], q[1]))
	marks.append(0.0)
	for i in range(points.size()):
		total += points[i].distance_to(points[(i + 1) % points.size()])
		marks.append(total)
	model = load(MODEL).instantiate()
	var rest: Vector3 = model.get_meta("actor_properties", {}).get("rest_scale", Vector3.ONE)
	size = GROWTH * rest.x
	model.scale = Vector3.ONE * size
	add_child(model)
	var rig: Dictionary = model.get_meta("rig_bindings", {})
	head = model.get_node_or_null(rig.get("head", NodePath("")))
	hips = _nodes(rig.get("feet", [])); knees = _nodes(rig.get("knees", []))
	arms = _nodes(rig.get("arms", [])); forearms = _nodes(rig.get("forearms", []))
	fronds = _nodes(rig.get("leaves", []))
	for m in model.find_children("*", "GeometryInstance3D", true, false):
		m.visibility_range_end = 0.0
		m.extra_cull_margin = 4.0
	_place(0.0, true)
	_build_solids()
	_follow(true)


func _nodes(paths: Array) -> Array:
	var list: Array = []
	for path in paths:
		var node := model.get_node_or_null(path)
		if node != null: list.append(node)
	return list


# ------------------------------------------------------------------ walking

func _physics_process(dt: float) -> void:
	if game == null or model == null or points.is_empty(): return
	clock += dt
	var before := curtain.global_transform if is_instance_valid(curtain) else Transform3D()
	_place(dt)
	_animate()
	_follow()
	# Mr. Justice clinging to its root curtain is carried with it.
	var player = game.player
	if is_instance_valid(curtain) and is_instance_valid(player) and bool(player.get("climbing")):
		var surface = player.get("climb_surface")
		if surface is WeakRef and surface.get_ref() == curtain:
			var delta := curtain.global_transform * before.affine_inverse()
			player.global_position = delta * player.global_position


## Distance along its loop now.
func _progress() -> float:
	var journey: float = float(game.state.journey_time) if game.state != null and "journey_time" in game.state else clock
	return fposmod(START + journey * SPEED, total)


func _point_at(distance: float) -> Vector2:
	var d := fposmod(distance, total)
	var lo := 0; var hi := points.size()
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if marks[mid] <= d: lo = mid
		else: hi = mid
	var a := points[lo]; var b := points[(lo + 1) % points.size()]
	var span := marks[lo + 1] - marks[lo]
	return a.lerp(b, (d - marks[lo]) / maxf(span, 0.001))


func _ground(p: Vector2) -> float:
	var h := 0.0
	for offset in [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
		h += float(game.world.height_at(p.x + offset.x, p.y + offset.y))
	return h / 5.0


func _place(dt: float, snap := false) -> void:
	var s := _progress()
	var here := _point_at(s)
	var dir := _point_at(s + 25.0) - _point_at(s - 25.0)
	var yaw := atan2(-dir.x, -dir.y) if dir.length() > 0.01 else model.rotation.y
	var stride := s / STRIDE * TAU
	bob = absf(sin(stride)) * 0.35
	var target := Vector3(here.x, _ground(here) - 0.4 - bob, here.y)
	model.global_position = target
	model.rotation.y = yaw if snap else lerp_angle(model.rotation.y, yaw, 1.0 - exp(-dt * 0.5))


## A slow, heavy walk: legs swinging in long strides, knuckles swinging low, its little stone
## face peering about, and the grass and trees on its back swaying.
func _animate() -> void:
	var stride := _progress() / STRIDE * TAU
	for k in range(hips.size()):
		var s := 1.0 if k == 0 else -1.0
		var swing := sin(stride) * s
		hips[k].rotation.x = swing * 0.2
		if k < knees.size(): knees[k].rotation.x = maxf(0.0, -swing) * 0.3
	for k in range(arms.size()):
		var s := -1.0 if k == 0 else 1.0
		arms[k].rotation.x = sin(stride) * s * 0.14
		if k < forearms.size(): forearms[k].rotation.x = -0.05 + maxf(0.0, sin(stride) * s) * 0.12
	if head != null:
		head.rotation.y = sin(clock * 0.07) * 0.35
		head.rotation.x = sin(clock * 0.11) * 0.06
	for k in range(fronds.size()):
		fronds[k].rotation = Vector3(sin(clock * 0.6 + k * 1.3) * 0.025, 0.0, sin(clock * 0.5 + k * 0.9) * 0.03)


# ------------------------------------------------------------------ solid parts

## Bodies for its back, torso, head, legs, arms and the root curtain, each following the part
## of the model it belongs to.
func _build_solids() -> void:
	var shell := model.get_node_or_null("HillCollision") as MeshInstance3D
	var main := _body("Back")
	if shell != null and shell.mesh != null:
		var faces := shell.mesh.get_faces()
		for i in range(faces.size()): faces[i] = faces[i] * size
		var concave := ConcavePolygonShape3D.new(); concave.set_faces(faces)
		var cs := CollisionShape3D.new(); cs.shape = concave; main.add_child(cs)
	_capsule(main, Vector3(0, 1.2, 0.08), Vector3(0, 2.1, -0.28), 0.47)
	# The standing stones and tree trunks on its back are solid too.
	for solid in model.get_meta("barrowback_solids", []):
		var base: Vector3 = solid[0]
		_capsule(main, base, base + Vector3(0, float(solid[2]), 0), float(solid[1]))
	followers.append([main, model])
	var info: Dictionary = model.get_meta("barrowback_curtain", {})
	if not info.is_empty():
		curtain = _body("RootCurtain")
		curtain.set_meta("climbable", true)
		# Solid from the rim of the hill right down to the ground, so it can be grabbed from
		# the ground even where the hanging roots end a little above it.
		var top := float(info.center.y) + float(info.size.y) * 0.5
		var box := BoxShape3D.new(); box.size = Vector3(info.size.x, top + 0.05, info.size.z) * size
		var cs := CollisionShape3D.new(); cs.shape = box
		cs.position = Vector3(info.center.x, (top - 0.05) * 0.5, info.center.z) * size
		curtain.add_child(cs)
		followers.append([curtain, model])
	if head != null:
		var hb := _body("Head")
		var sphere := SphereShape3D.new(); sphere.radius = 0.24 * size
		var cs := CollisionShape3D.new(); cs.shape = sphere; cs.position = (Vector3(0, 2.08, -0.66) - head.position) * size
		hb.add_child(cs)
		followers.append([hb, head])
	# Legs: thigh from the hip joint, shin and foot from the knee joint.
	for k in range(hips.size()):
		var hip: Node3D = hips[k]
		var hip_at: Vector3 = hip.position
		var knee: Node3D = knees[k] if k < knees.size() else null
		var knee_at: Vector3 = hip_at + (knee.position if knee != null else Vector3(0, -0.55, 0))
		var thigh := _body("Thigh%d" % k)
		_capsule(thigh, (hip_at + Vector3(0, 0.1, 0)) - hip_at, knee_at - hip_at, 0.27)
		followers.append([thigh, hip])
		if knee != null:
			var shin := _body("Shin%d" % k)
			var ankle := Vector3(knee_at.x * 1.04, 0.2, -0.02)
			_capsule(shin, Vector3.ZERO, ankle - knee_at, 0.24)
			var foot := BoxShape3D.new(); foot.size = Vector3(0.6, 0.2, 0.75) * size
			var fs := CollisionShape3D.new(); fs.shape = foot; fs.position = (Vector3(ankle.x, 0.1, -0.05) - knee_at) * size
			shin.add_child(fs)
			followers.append([shin, knee])
	# Arms: upper arm from the shoulder, forearm and fist from the elbow.
	for k in range(arms.size()):
		var arm: Node3D = arms[k]
		var sh: Vector3 = arm.position
		var fore: Node3D = forearms[k] if k < forearms.size() else null
		var el: Vector3 = sh + (fore.position if fore != null else Vector3(0.25, -0.7, -0.18))
		var side := signf(sh.x)
		var upper := _body("UpperArm%d" % k)
		_capsule(upper, Vector3.ZERO, el - sh, 0.24)
		followers.append([upper, arm])
		if fore != null:
			var lower := _body("Forearm%d" % k)
			var wrist := Vector3(1.0 * side, 0.72, -0.45)
			_capsule(lower, Vector3.ZERO, wrist - el, 0.22)
			var fist := SphereShape3D.new(); fist.radius = 0.24 * size
			var fc := CollisionShape3D.new(); fc.shape = fist; fc.position = (wrist + Vector3(0, -0.12, -0.02) - el) * size
			lower.add_child(fc)
			followers.append([lower, fore])


func _body(label: String) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = label
	body.sync_to_physics = true
	body.top_level = true
	add_child(body)
	return body


## A capsule between two points given in the followed node's own (unscaled) frame.
func _capsule(body: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
	var from := a * size; var to := b * size
	var axis := to - from
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius * size
	capsule.height = axis.length() + capsule.radius * 2.0
	var cs := CollisionShape3D.new(); cs.shape = capsule
	var up := axis.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	cs.transform = Transform3D(Basis(side, up, side.cross(up)), (from + to) * 0.5)
	body.add_child(cs)


func _follow(snap := false) -> void:
	for pair in followers:
		var body: AnimatableBody3D = pair[0]; var node: Node3D = pair[1]
		var t := Transform3D(node.global_basis.orthonormalized(), node.global_position)
		if snap:
			body.sync_to_physics = false
			body.global_transform = t
			body.sync_to_physics = true
		else:
			body.global_transform = t


## Where Barrowback is now.
func where() -> Vector3:
	return model.global_position if model != null else Vector3.ZERO


## A spot on the ground beside the foot of its root curtain, for the travel menu.
func approach_point() -> Vector3:
	if model == null: return Vector3.ZERO
	var info: Dictionary = model.get_meta("barrowback_curtain", {"center": Vector3(1.07, 1.25, 0.25)})
	var local := Vector3(float(info.center.x) + 0.3, 0.0, float(info.center.z)) * size
	var at := model.global_position + model.global_basis.orthonormalized() * local
	at.y = float(game.world.height_at(at.x, at.z)) + 0.2
	return at
