extends Node3D


signal frame_ready
const HERO_RATIO = preload("res://scripts/hero_base.gd").MODEL_SCALE / 0.75
var camera: Camera3D
var viewport: Viewport
var original_disabled = false
var pending = false
var drawn_frames = 0
var live = false

func begin(target: Viewport, point: Vector3, far_plane: float) -> void:
	viewport = target; original_disabled = target.disable_3d; live = true
	camera = Camera3D.new(); camera.fov = 62; camera.near = 0.08; camera.far = far_plane
	add_child(camera); position_at(point); camera.current = true
	viewport.disable_3d = true

func position_at(point: Vector3) -> void:
	if camera == null: return
	camera.global_position = point + Vector3(0.72 * HERO_RATIO, 1.38 * HERO_RATIO + 0.63, 3.45)
	camera.look_at(point + Vector3(0, 1.38 * HERO_RATIO, 0))

func request_frame() -> void:
	if not live or pending: return
	pending = true; viewport.disable_3d = original_disabled
	if DisplayServer.get_name() == "headless": get_tree().process_frame.connect(_drawn, CONNECT_ONE_SHOT)
	else: RenderingServer.frame_post_draw.connect(_drawn, CONNECT_ONE_SHOT)

func draw_frame() -> void:
	request_frame()
	if pending: await frame_ready

func _drawn() -> void:
	if not live: return
	pending = false; drawn_frames += 1; viewport.disable_3d = true; frame_ready.emit()

func finish() -> void:
	if not live: return
	live = false
	if RenderingServer.frame_post_draw.is_connected(_drawn): RenderingServer.frame_post_draw.disconnect(_drawn)
	if is_inside_tree() and get_tree().process_frame.is_connected(_drawn): get_tree().process_frame.disconnect(_drawn)
	pending = false
	if is_instance_valid(viewport): viewport.disable_3d = original_disabled
	if is_instance_valid(camera):
		if camera.current: camera.clear_current(false)
		camera.free(); camera = null

func _exit_tree() -> void: finish()
