extends RefCounted

static var _scenes: Dictionary = {}
const Appearance = preload("res://scripts/resident_appearance.gd")
var profile: Dictionary = {}
const MODELS = ["peasant_1", "peasant_2", "peasant_3", "peasant_4", "peasant_5", "peasant_6", "city_dwellers_1", "city_dwellers_2", "rich_citizzens_1", "rich_citizzens_2", "rich_citizzens_3", "rich_citizzens_4"]
var skeleton: Skeleton3D
var player: AnimationPlayer
var rig: Node3D
var motion = ""
var elapsed = 0.0
var context = "home"
var travel_speed = 1.1
var wave_weight = 0.0
var initial_phase = 0.0
var gaze_weight = 0.0
var neck = -1
var head_bone = -1
const GLANCES = [Vector2(0, 0), Vector2(1.5, 0), Vector2(2.5, 0.18), Vector2(3.8, 0.18), Vector2(4.6, 0), Vector2(6, 0), Vector2(7.2, -0.14), Vector2(8.6, -0.14), Vector2(9.6, 0), Vector2(12, 0)]
var upper = -1
var lower = -1
var hand = -1

static func eligible(actor) -> bool:
	return actor.race in ["human", "orc", "dwarf", "elf", "smallfolk"]

func attach(actor, coat: String = "#55776d") -> bool:
	if not eligible(actor): return false
	profile = Appearance.design(str(actor.get_meta("id", actor.name)), actor.race, actor.role, Color(coat))
	context = actor.role
	var index = posmod(hash(str(actor.get_meta("id", actor.name))), MODELS.size())
	var id = MODELS[index]
	if profile.id == "brindlewick_smith": id = "peasant_1"
	elif profile.id in ["ironbell_smith", "brindlewick_merchant", "brindlewick_baker"]: id = "peasant_6"
	if not _scenes.has(id): _scenes[id] = load("res://assets/imported/people/" + id + ".scn")
	if _scenes[id] == null: return false
	actor.visual = Node3D.new(); actor.visual.name = "AuthoredHouseholdResident"; actor.add_child(actor.visual)
	actor.visual.add_to_group("batch_dynamic"); actor.visual.set_meta("cast_generation", "v26-shared-skinned")
	actor.visual.set_meta("costume", profile.costume); actor.visual.set_meta("region", profile.region)
	rig = _scenes[id].instantiate(); actor.visual.add_child(rig)
	rig.scale = Vector3(float(profile.broad), float(profile.height) / 1.82, sqrt(float(profile.broad))) * (1.82 / float(rig.get_meta("model_height", 1.82)))
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	player = rig.get_node("ResidentMotion"); player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	profile.head_level = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin.y
	for mesh in rig.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_end = 88; mesh.visibility_range_end_margin = 5
		if mesh is MeshInstance3D: mesh.mesh = Appearance.palette_mesh(mesh.mesh, profile)
	actor.body_radius = 0.31 * float(profile.broad)
	var collision = CollisionShape3D.new(); collision.name = "ResidentCapsule"; collision.shape = CapsuleShape3D.new(); collision.shape.radius = actor.body_radius; collision.shape.height = profile.height; collision.position.y = profile.height * 0.5; actor.add_child(collision)
	actor.greeting = Label3D.new(); actor.greeting.name = "BriefGreeting"; actor.greeting.position.y = profile.height + 0.24; actor.greeting.font_size = 36; actor.greeting.pixel_size = 0.0045; actor.greeting.outline_size = 6; actor.greeting.modulate = Color("#f8e7ba"); actor.greeting.billboard = BaseMaterial3D.BILLBOARD_ENABLED; actor.greeting.hide(); actor.add_child(actor.greeting)
	Appearance.add_features(actor, skeleton, profile)
	var natural = AnimationLibrary.new()
	for alias in ["idle", "wait", "chat", "work", "arms"]: natural.add_animation(alias, player.get_animation("idle").duplicate())
	player.add_animation_library("natural", natural)
	initial_phase = float(posmod(hash(str(actor.name)), 1000)) * 0.001
	upper = skeleton.find_bone("Upperarm_R"); lower = skeleton.find_bone("Lowerarm_R"); hand = skeleton.find_bone("Hand_R")
	neck = skeleton.find_bone("Neck_01"); head_bone = skeleton.find_bone("Head")
	animate(0, false, false)
	return true

func _aim(bone: int, child: int, target: Vector3, weight: float) -> void:
	if bone < 0 or child < 0: return
	var global = skeleton.get_bone_global_pose(bone); var from = skeleton.get_bone_global_pose(child).origin - global.origin
	var to = target - global.origin
	if from.length_squared() < 1.0e-05 or to.length_squared() < 1.0e-05: return
	var q = global.basis.get_rotation_quaternion()
	var delta = q.inverse() * Quaternion(from.normalized(), to.normalized()) * q
	skeleton.set_bone_pose_rotation(bone, (skeleton.get_bone_pose_rotation(bone) * Quaternion.IDENTITY.slerp(delta, weight)).normalized())
	skeleton.force_update_all_bone_transforms()
func animate(dt: float, moving: bool, greeting: bool) -> void:
	if player == null or dt < 0: return
	if dt == 0 and elapsed > 0: return
	var next = "walk" if moving else "natural/wait"
	if next != motion:
		player.play(next, 0.18); motion = next
		if elapsed == 0: player.seek(initial_phase * player.get_animation(next).length, true)
	player.speed_scale = clampf(travel_speed / 1.1, 0.15, 2.5) if moving else 1.0
	player.advance(dt); elapsed += dt
	gaze_weight = lerpf(gaze_weight, 0.0 if moving or greeting else 1.0, 1 - exp(-dt * 6))
	if gaze_weight > 0.0001:
		var phase = fposmod(elapsed + initial_phase * 12, 12.0); var yaw = 0.0
		for i in range(GLANCES.size() - 1):
			if phase <= GLANCES[i + 1].x:
				var blend = smoothstep(GLANCES[i].x, GLANCES[i + 1].x, phase)
				yaw = lerpf(GLANCES[i].y, GLANCES[i + 1].y, blend) * gaze_weight; break
		for link in [[neck, 0.45], [head_bone, 0.55]]:
			if link[0] < 0: continue
			var q = Quaternion(Vector3.UP, yaw * link[1]) * Quaternion(Vector3.RIGHT, absf(yaw) * 0.12 * link[1])
			skeleton.set_bone_pose_rotation(link[0], (skeleton.get_bone_pose_rotation(link[0]) * q).normalized())
		skeleton.force_update_all_bone_transforms()
	wave_weight = lerpf(wave_weight, 1.0 if greeting and not moving else 0.0, 1 - exp(-dt * 6))
	if wave_weight > 0.0001 and upper >= 0:
		var shoulder = skeleton.get_bone_global_pose(upper).origin


		var side = -1.0 if shoulder.x < 0 else 1.0
		_aim(upper, lower, shoulder + Vector3(side * 0.38, -0.08, 0.16), wave_weight)
		_aim(lower, hand, shoulder + Vector3(side * (0.25 + sin(elapsed * 5) * 0.035), 0.59, 0.28), wave_weight)
