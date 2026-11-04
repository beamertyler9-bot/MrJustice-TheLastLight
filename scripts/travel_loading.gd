extends Node


const Locations = preload("res://scripts/locations.gd")
var game
var world
var point: Vector3
var origin: Vector3
var title: String
var previous_mode: String
var completed: Callable
var live = false
var graphics

func begin(context, destination: Vector3, label: String, callback: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = context; world = game.world; point = destination; origin = game.player.global_position
	title = label; completed = callback; previous_mode = game.mode; live = true
	game.loading_text = "Travelling to " + title
	game.set_mode("loading")
	_run.call_deferred()

func _valid() -> bool:
	return live and is_instance_valid(game) and is_instance_valid(world) and game.world == world and is_instance_valid(game.player)

func _work_left() -> bool:
	return not world.pending.is_empty() or not world.stream_job.is_empty() or not world.settlement_jobs.is_empty() or (world.society != null and (not world.society.jobs.is_empty() or not world.society.proxy_jobs.is_empty())) or (is_instance_valid(world.scrappers) and not world.scrappers.jobs.is_empty())

func _prepare(destination: Vector3) -> void:
	graphics.position_at(destination)
	world.stream_at(destination, false)


	await get_tree().process_frame
	if not _valid(): return
	var slices = 0
	while _work_left():
		var deadline = Time.get_ticks_usec() + 4000
		if not world.settlement_jobs.is_empty(): Locations.step_settlement(world)
		elif world.society != null and not world.society.jobs.is_empty(): world.society.step()
		elif world.society != null and not world.society.proxy_jobs.is_empty(): world.society.step_proxy()
		elif is_instance_valid(world.scrappers) and not world.scrappers.jobs.is_empty(): world.scrappers.step()
		while Time.get_ticks_usec() < deadline and (not world.pending.is_empty() or not world.stream_job.is_empty()): world.stream_step()



		if world.pending.is_empty() and world.stream_job.is_empty() and is_instance_valid(world.scrappers): world.scrappers.stream_at(destination, false)
		slices += 1
		game.loading_text = "Preparing " + title + " · " + ("buildings" if not world.settlement_jobs.is_empty() or (world.society != null and not world.society.jobs.is_empty()) else "nearby scenery")
		if slices % 32 == 0: await graphics.draw_frame()
		if not _valid(): return
		await get_tree().process_frame
		if not _valid(): return


	world.stream_at(destination, true)
	await get_tree().physics_frame

func _run() -> void:

	await get_tree().process_frame
	if not _valid(): return
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	if not _valid(): return
	graphics = preload("res://scripts/render_loading.gd").new(); add_child(graphics)
	graphics.begin(game.get_viewport(), point, 14000 if world.atlas != null else 220)
	await get_tree().process_frame
	if not _valid(): return
	await _prepare(point)
	if not _valid(): return
	var success: bool = game._place_teleport(point, title, true, false, true, true)
	if not success:
		game.loading_text = "Returning to your previous location"
		await _prepare(origin)
		if not _valid(): return
		game.player.global_position = origin; game.player.reset_motion(); game.player.update_camera(1.0)
	await graphics.draw_frame()
	if not _valid(): return
	graphics.finish()
	game.player.camera.make_current()
	live = false; game.travel_loading = null

	var parents = game.modal_parents.duplicate()
	game.set_mode("play" if success else previous_mode)
	if not success: game.modal_parents = parents
	if completed.is_valid(): completed.call(success)
	game.travel_finished.emit(success)
	queue_free()

func cancel() -> void:
	live = false
	if is_instance_valid(graphics): graphics.finish()
	if is_instance_valid(game) and game.travel_loading == self: game.travel_loading = null
	queue_free()

func _exit_tree() -> void:
	live = false
	if is_instance_valid(graphics): graphics.finish()
