extends Node


const PORTRAIT_SIZE := Vector2i(320, 400)
var viewport: SubViewport
var camera: Camera3D
var subject: Node3D
var speaker_id := ""
var capture_serial := 0
var head_point := Vector3.ZERO
var _source_instance := 0
var _ready_serial := 0
var _texture: ViewportTexture

func _ready() -> void:
	set_process(false)
	set_physics_process(false)

func texture_for(speaker: Node3D) -> Texture2D:
	if not is_instance_valid(speaker): return null
	var visual = speaker.get("visual")
	if not is_instance_valid(visual) or not visual is Node3D: return null
	if _source_instance != visual.get_instance_id(): _capture(speaker, visual)
	return _texture if _ready_serial == capture_serial else null

func _ensure_viewport() -> void:
	if viewport != null: return

	viewport = SubViewport.new()
	viewport.name = "CachedDialoguePortrait"
	viewport.size = PORTRAIT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#ebdfcf")
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, -32, 0)
	key.light_color = Color("#fff1d4")
	key.light_energy = 1.3
	key.shadow_enabled = false
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, 145, 0)
	fill.light_color = Color("#bacfd2")
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	viewport.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 12.0
	viewport.add_child(camera)
	camera.current = true
	_texture = viewport.get_texture()

func _capture(speaker: Node3D, visual: Node3D) -> void:
	_ensure_viewport()


	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(subject):
		subject.hide()
		subject.queue_free()
	_source_instance = visual.get_instance_id()
	speaker_id = str(speaker.get_meta("id", speaker.name))
	capture_serial += 1
	_ready_serial = 0


	subject = visual.duplicate(0) as Node3D
	subject.name = "SpeakerSnapshot"
	subject.transform = Transform3D.IDENTITY
	subject.process_mode = Node.PROCESS_MODE_DISABLED
	subject.visible = true
	viewport.add_child(subject)
	for mesh in subject.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_begin = 0
		mesh.visibility_range_end = 0

	var skeletons := subject.find_children("*", "Skeleton3D", true, false)
	for skeleton in skeletons: skeleton.reset_bone_poses()
	for animation in subject.find_children("*", "AnimationPlayer", true, false):
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if animation.has_animation("natural/wait"):
			animation.play("natural/wait")
			animation.seek(0.6, true)
		animation.stop(true)
	var height := 1.82
	var presenter = speaker.get("imported_actor")
	if presenter != null: height = float(presenter.profile.get("height", height))
	head_point = Vector3(0, height * 0.86, 0)
	if not skeletons.is_empty():
		var skeleton: Skeleton3D = skeletons[0]
		skeleton.force_update_all_bone_transforms()
		var head := skeleton.find_bone("Head")
		if head >= 0:
			head_point = subject.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(head).origin


	camera.size = height * 0.56
	var focus := Vector3(0, head_point.y - height * 0.105, 0)
	camera.position = focus + Vector3(height * 0.12, height * 0.015, height * 2.4)
	camera.look_at(focus)
	if not RenderingServer.frame_post_draw.is_connected(_capture_finished):
		RenderingServer.frame_post_draw.connect(_capture_finished, CONNECT_ONE_SHOT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _capture_finished() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ready_serial = capture_serial
