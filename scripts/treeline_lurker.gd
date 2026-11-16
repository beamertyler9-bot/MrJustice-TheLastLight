extends Node3D
## The Treeline Lurker of Hollowmourn: a very tall shadow figure that watches Mr. Justice
## from behind trees. It never attacks; it only watches.
##
## - It peeks out from behind a tree some way off, leaning out to stare at him.
## - When he looks straight at it, it melts away and reappears behind another tree.
## - While he looks away it creeps a little closer, tree by tree, out of his sight, but it
##   never comes nearer than about ten metres.
## - If he walks up to it, it melts away and turns up again further off.
## - It leaves when he leaves Hollowmourn.
## - Very rarely one turns up anywhere else in the world (a "wanderer"): it follows him for a
##   minute or two, from behind trees or, where there are none, standing out in the open at a
##   distance, and then fades away for good.
##
## Spawned and retired by scripts/ecology.gd.

const MODEL := "res://assets/creatures/treeline_lurker.scn"
const SEEN_TO_VANISH := 0.3
const FADE_OUT := 0.3
const FADE_IN := 0.7
## It keeps at least this far from him, and slips away if he comes nearer than TOO_CLOSE.
const NEAREST := 10.0
const TOO_CLOSE := 8.0
const LEAVE_DISTANCE := 75.0

var game
var model: Node3D
var meshes: Array = []
var head: Node3D
var arms: Array = []
var forearms: Array = []
var legs: Array = []
var knees: Array = []
var wisps: Array = []

var state := "hidden"
var tree: Node3D = null
var peek_side := 1.0
## The world direction it leans out toward, past the edge of its trunk.
var peek_dir := Vector3.RIGHT
## Where it stands when there is no tree to hide behind (INF when it is at a tree).
var open_spot := Vector3.INF
## A wanderer follows him outside Hollowmourn for `lifetime` seconds, then leaves for good.
var wanderer := false
var lifetime := -1.0
var leaving := false
var timer := 0.0
var seen_time := 0.0
var fade := 1.0
var clock := 0.0


func setup(context) -> void:
	game = context
	name = "TreelineLurker"
	model = load(MODEL).instantiate()
	add_child(model)
	var rig: Dictionary = model.get_meta("rig_bindings", {})
	head = model.get_node_or_null(rig.get("head", NodePath("")))
	for key in ["arms", "forearms", "feet", "knees", "leaves"]:
		var list: Array = []
		for path in rig.get(key, []):
			var node := model.get_node_or_null(path)
			if node != null: list.append(node)
		match key:
			"arms": arms = list
			"forearms": forearms = list
			"feet": legs = list
			"knees": knees = list
			"leaves": wisps = list
	for m in model.find_children("*", "GeometryInstance3D", true, false): meshes.append(m)
	# Its tiny white eyes shine a little brighter here, so they catch the light in Hollowmourn's
	# gloom even when the rest of it is lost in the dark.
	var eyes := model.find_child("Eyes", true, false)
	if eyes is GeometryInstance3D and eyes.material_override is StandardMaterial3D:
		var bright: StandardMaterial3D = eyes.material_override.duplicate()
		bright.emission_energy_multiplier = 7.0
		eyes.material_override = bright
		# A faint cold light from its eyes, just enough to pick out the edge of its face.
		var shine := OmniLight3D.new(); shine.light_color = Color("#dfe9ff"); shine.light_energy = 0.6
		shine.omni_range = 0.9; shine.shadow_enabled = false
		shine.position = Vector3(0, 2.88, -0.6) - (eyes.get_parent() as Node3D).position
		eyes.get_parent().add_child(shine)
	_set_fade(1.0)
	timer = randf_range(1.0, 2.5)


## True while Mr. Justice is in Hollowmourn and outdoors, which is where it hunts.
static func hunting_ground(context) -> bool:
	var p: Vector3 = context.player.global_position
	return int(context.world.biome_at(p.x, p.z)) == 14


func _process(dt: float) -> void:
	if game == null or not is_instance_valid(game.player): return
	var player: Node3D = game.player
	clock += dt
	var to_player := player.global_position - global_position; to_player.y = 0.0
	var distance := to_player.length()
	var seen := _seen() if fade < 0.9 else false
	seen_time = seen_time + dt if seen else 0.0
	if lifetime > 0.0:
		lifetime -= dt
		if lifetime <= 0.0:
			leaving = true
			if state in ["appearing", "lurking"]: _vanish(0.0, 0.0)
	if leaving and state == "hidden":
		queue_free(); return
	match state:
		"hidden":
			# Out of sight; once the timer runs out, pick a tree (or, for a wanderer with no
			# trees about, a spot in the open) out of his view to appear at.
			timer -= dt
			if timer <= 0.0:
				if _pick_spot(player, 14.0, 26.0): state = "appearing"
				else: timer = 1.5
		"appearing":
			fade = maxf(0.0, fade - dt / FADE_IN)
			if seen_time > SEEN_TO_VANISH and fade < 0.5: _vanish(1.5, 3.0)
			elif fade <= 0.0:
				state = "lurking"; timer = randf_range(4.0, 8.0)
		"lurking":
			_place(player, dt)
			if seen_time > SEEN_TO_VANISH: _vanish(1.5, 3.5)
			elif distance < TOO_CLOSE: _vanish(4.0, 7.0)
			else:
				timer -= dt
				if timer <= 0.0 and not seen:
					# Creep a little closer (or keep up, if he has walked on): slip to a nearer
					# tree or spot he isn't looking at.
					state = "slipping"
					timer = randf_range(4.0, 8.0)
		"slipping":
			fade = minf(1.0, fade + dt / 0.2)
			if fade >= 1.0:
				if not _pick_spot(player, maxf(NEAREST, minf(distance, 26.0) - 6.0), maxf(NEAREST + 3.0, minf(distance, 26.0) - 1.0)):
					if not _pick_spot(player, 14.0, 26.0): _place(player, 1.0, true)
				state = "appearing"
		"vanishing":
			fade = minf(1.0, fade + dt / FADE_OUT)
			if fade >= 1.0: state = "hidden"
	_set_fade(fade)
	_animate(dt)


## Is Mr. Justice looking at it? Its head or chest must be near the middle of his view, close
## enough to make out, and not hidden behind a tree trunk or a hill.
func _seen() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return false
	var forward := -camera.global_basis.z
	for height: float in [2.85, 2.1]:
		var point := global_position + Vector3.UP * height
		var to := point - camera.global_position
		var distance := to.length()
		if distance > 45.0 or not camera.is_position_in_frustum(point): continue
		if forward.dot(to / distance) < 0.82: continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point)
		# Its own tree doesn't hide it: it is leaning out from behind that trunk.
		var skip: Array[RID] = []
		if game.player is CollisionObject3D: skip.append(game.player.get_rid())
		if is_instance_valid(tree):
			for body in tree.find_children("*", "CollisionObject3D", true, false): skip.append(body.get_rid())
			if tree is CollisionObject3D: skip.append(tree.get_rid())
		query.exclude = skip
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false


func _visible_from_camera(point: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera != null and camera.is_position_in_frustum(point + Vector3.UP * 2.0)


## A tree between `near` and `far` metres from Mr. Justice; with `hidden`, one he isn't
## looking toward.
func _pick_tree(player: Node3D, near: float, far: float, hidden: bool) -> Node3D:
	var best: Node3D = null; var best_score := INF
	var p := player.global_position
	for node in get_tree().get_nodes_in_group("harvestable"):
		if not node is Node3D or str(node.get_meta("kind", "")) != "tree" or node == tree: continue
		var at: Vector3 = node.global_position
		var d := Vector2(at.x - p.x, at.z - p.z).length()
		if d < near or d > far: continue
		if hidden and _visible_from_camera(at): continue
		var score := absf(d - (near + far) * 0.5) + randf() * 3.0
		if score < best_score: best_score = score; best = node
	return best


## Choose where to appear next: a tree he isn't looking toward, or for a wanderer with no
## trees nearby, a patch of open ground behind or beside him. Returns false if neither.
func _pick_spot(player: Node3D, near: float, far: float) -> bool:
	var next := _pick_tree(player, near, far, true)
	if next != null:
		open_spot = Vector3.INF
		_take_tree(next, player)
		return true
	if not wanderer: return false
	var camera := get_viewport().get_camera_3d()
	var back := Vector3.BACK if camera == null else camera.global_basis.z
	back.y = 0.0
	for attempt in range(10):
		var dir := back.normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2))
		var at := player.global_position + dir * randf_range(near, far)
		at.y = _ground(at)
		if _visible_from_camera(at): continue
		# Not in the middle of a village or other settled ground.
		if game.world.has_method("reserved_at") and game.world.reserved_at(Vector2(at.x, at.z), 2.0): continue
		tree = null; open_spot = at
		_place(player, 1.0, true)
		return true
	return false


## Stand at its tree or its spot in the open, facing him.
func _place(player: Node3D, dt: float, snap := false) -> void:
	if is_instance_valid(tree) or open_spot == Vector3.INF:
		_place_at_tree(player, dt, snap); return
	peek_dir = Vector3.ZERO
	var at := open_spot; at.y = _ground(at)
	global_position = at
	var facing := player.global_position - at; facing.y = 0.0
	_face(facing.normalized(), dt, 4.0 if not snap else 1000.0)


func _take_tree(next: Node3D, player: Node3D) -> void:
	tree = next
	peek_side = -1.0 if randf() < 0.5 else 1.0
	_place_at_tree(player, 1.0, true)


## Stand just behind the trunk, on the far side from Mr. Justice, leaning out to one side.
func _place_at_tree(player: Node3D, dt: float, snap := false) -> void:
	if not is_instance_valid(tree): _vanish(1.0, 2.0); return
	var trunk := tree.global_position
	var away := trunk - player.global_position; away.y = 0.0
	if away.length() < 0.1: away = Vector3.FORWARD
	away = away.normalized()
	var side := away.cross(Vector3.UP).normalized() * peek_side
	peek_dir = side
	var target := trunk + away * (_trunk_radius() + 0.6) + side * (_trunk_radius() * 0.85)
	target.y = _ground(target)
	global_position = target if snap else global_position.lerp(target, 1.0 - exp(-dt * 3.0))
	_face(-away, dt, 6.0 if not snap else 1000.0)


func _trunk_radius() -> float:
	if is_instance_valid(tree):
		for shape in tree.find_children("*", "CollisionShape3D", true, false):
			if shape.shape is CylinderShape3D: return (shape.shape as CylinderShape3D).radius
	return 0.45


func _vanish(wait_min: float, wait_max: float) -> void:
	state = "vanishing"
	timer = randf_range(wait_min, wait_max)
	seen_time = 0.0


func _face(dir: Vector3, dt: float, rate: float) -> void:
	if dir.length() < 0.01: return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-dt * rate))


func _ground(at: Vector3) -> float:
	if game.world.has_method("surface_height_at"): return game.world.surface_height_at(at.x, at.z)
	return game.world.height_at(at.x, at.z)


func _set_fade(value: float) -> void:
	visible = value < 0.995
	for m in meshes: m.transparency = value


## A slow, unsettling idle: it sways, cocks its head and leans out from the trunk to stare.
func _animate(dt: float) -> void:
	# Stooped low and leaning out past the trunk, so its head comes out under the branches.
	var out := signf(peek_dir.dot(model.global_basis.x))
	var follow := 1.0 - exp(-dt * 3.0)
	model.rotation.z = lerpf(model.rotation.z, -out * 0.42, follow)
	model.rotation.x = lerpf(model.rotation.x, -0.12 if out != 0.0 else -0.05, follow)
	model.position.y = lerpf(model.position.y, -0.35 if out != 0.0 else 0.0, follow)
	if head != null:
		head.rotation.z = sin(clock * 0.7) * 0.15 + out * 0.55
		head.rotation.x = 0.1 + sin(clock * 0.43) * 0.06
	# Its long fingers flex slowly as it watches.
	for k in range(arms.size()):
		arms[k].rotation.x = sin(clock * 0.9 + k) * 0.04
		if k < forearms.size(): forearms[k].rotation.x = -0.08 + sin(clock * 0.6 + k * 2.0) * 0.06
	for k in range(wisps.size()):
		wisps[k].rotation = Vector3(sin(clock * 1.3 + k * 1.7) * 0.12, sin(clock * 0.8 + k) * 0.1, sin(clock * 1.1 + k * 0.9) * 0.1)
