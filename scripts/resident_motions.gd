extends RefCounted
## Motion-captured townsfolk clips (Human Basic Motions FREE, retargeted to the resident rig).
##
## The clips were baked against peasant_1. Each townsfolk model has its own root
## orientation and hip height, so the first time a model is used the clips are copied and
## corrected to face the same way as that model's original idle and to stand on its own
## hip height. Results are cached per model.

const DIR := "res://assets/animation/residents/"
const FEMALE_MODELS := ["peasant_2", "peasant_4", "peasant_6", "city_dwellers_2", "rich_citizzens_2", "rich_citizzens_4"]
const CLIPS := {"idle_a": "idle_a", "idle_b": "idle_b", "talk": "talk", "walk": "walk"}
static var _cache: Dictionary = {}
static var _sources: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "idle_a.res")

## Pick the set an unflipped rig would need, for diagnostics.
static func set_for(skeleton: Skeleton3D) -> String:
	var root_bone := skeleton.find_bone("Root")
	return "b_" if root_bone >= 0 and absf(skeleton.get_bone_rest(root_bone).basis.get_euler().y) < 0.5 else ""


static func _source(name: String) -> Animation:
	if not _sources.has(name): _sources[name] = load(DIR + name + ".res")
	return _sources[name]


static func library_for(model_id: String, player: AnimationPlayer, skeleton: Skeleton3D) -> AnimationLibrary:
	if _cache.has(model_id): return _cache[model_id]
	var root_bone := skeleton.find_bone("Root")
	var pelvis := skeleton.find_bone("Pelvis")
	if root_bone < 0 or pelvis < 0 or not player.has_animation("idle"): return null
	# This model's own facing: pelvis frame in skeleton space on its original idle's first key.
	var idle := player.get_animation("idle")
	var pelvis_local: Quaternion = skeleton.get_bone_rest(pelvis).basis.get_rotation_quaternion()
	var prefix := ""
	var root_rest: Quaternion = skeleton.get_bone_rest(root_bone).basis.get_rotation_quaternion()
	for t in idle.get_track_count():
		var path := str(idle.track_get_path(t))
		if idle.track_get_type(t) != Animation.TYPE_ROTATION_3D or idle.track_get_key_count(t) == 0: continue
		if path.ends_with(":Pelvis"):
			pelvis_local = idle.track_get_key_value(t, 0)
			prefix = path.split(":")[0]
		elif path.ends_with(":Root"):
			root_rest = idle.track_get_key_value(t, 0)
	if prefix.is_empty(): prefix = "Armature/Skeleton3D"
	var facing: Vector3 = Basis(root_rest * pelvis_local).z
	var model_yaw := atan2(facing.x, facing.z)
	var pelvis_rest: Vector3 = skeleton.get_bone_rest(pelvis).origin
	var female := model_id in FEMALE_MODELS
	# Two rig conventions ship with the townsfolk: most have a 180-degree root, three do not.
	# Clips were baked separately against each, so pick the matching set.
	var unflipped := absf(skeleton.get_bone_rest(root_bone).basis.get_euler().y) < 0.5
	var set_prefix := "b_" if unflipped and ResourceLoader.exists(DIR + "b_f_idle_a.res") else ""
	if unflipped: female = true
	var library := AnimationLibrary.new()
	for alias in CLIPS:
		var source := _source(set_prefix + ("f_" if female else "") + CLIPS[alias])
		if source == null: continue
		var clip: Animation = source.duplicate(true)
		var yaw_fix := model_yaw - float(source.get_meta("ref_pelvis_yaw", model_yaw))
		var root_q: Quaternion = Quaternion(Vector3.UP, yaw_fix) * Quaternion(source.get_meta("ref_root_rotation", root_rest))
		var root_track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(root_track, NodePath(prefix + ":Root"))
		clip.rotation_track_insert_key(root_track, 0.0, root_q.normalized())
		# Stand on this model's hip height (the bake used peasant_1's).
		var lift: Vector3 = pelvis_rest - Vector3(source.get_meta("ref_pelvis_rest", pelvis_rest))
		for t in clip.get_track_count():
			if clip.track_get_type(t) == Animation.TYPE_POSITION_3D and str(clip.track_get_path(t)).ends_with(":Pelvis"):
				for k in clip.track_get_key_count(t):
					clip.track_set_key_value(t, k, clip.track_get_key_value(t, k) + lift)
		library.add_animation(alias, clip)
	_cache[model_id] = library
	return library


static func ground_speed(library: AnimationLibrary) -> float:
	if library == null or not library.has_animation("walk"): return 1.1
	return float(library.get_animation("walk").get_meta("ground_speed", 1.1))
