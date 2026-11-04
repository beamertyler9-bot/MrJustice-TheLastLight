extends Node

const State = preload("res://scripts/state.gd")
const Book = preload("res://scripts/spellbook.gd")
const Magic = preload("res://scripts/magic.gd")
const Hero = preload("res://scripts/hero_visual.gd")
const B = preload("res://scripts/build.gd")

class PracticeCaster:
	extends CharacterBody3D
	var active := true
	var yaw := 0.0
	var visual: Node3D
	var camera: Camera3D
	var held_body = null
	var throw_pending := false
	var state
	func magic_hands_busy() -> bool: return false
	func grimoire_equipped() -> bool: return true
	func receive_impulse(_value: Vector3) -> void: pass
	func take_damage(amount: int) -> void: state.health = maxi(1, state.health - amount)

class PracticeDummy:
	extends CharacterBody3D
	var health := 1000000
	var hits := 0
	var recovery := 0.0
	var cooldown := 0.0
	var impulse := Vector3.ZERO
	var home := Vector3.ZERO
	var model: Node3D
	var recoil := 0.0
	func take_damage(amount: int) -> void:
		health = maxi(1, health - amount); hits += amount; recoil = 0.22
	func receive_impulse(value: Vector3) -> void: impulse += value
	func _physics_process(dt: float) -> void:
		if bool(get_meta("magic_stasis", false)): return
		dt *= float(get_meta("magic_time_scale", 1.0))
		recovery = maxf(0.0, recovery - dt); cooldown = maxf(0.0, cooldown - dt)
		velocity.x = impulse.x; velocity.z = impulse.z
		velocity.y += impulse.y * dt - 9.8 * float(get_meta("magic_gravity_scale", 1.0)) * dt
		impulse = impulse.move_toward(Vector3.ZERO, dt * 8.0)
		move_and_slide()
		if global_position.y < -4.0: global_position = home; velocity = Vector3.ZERO
		recoil = maxf(0.0, recoil - dt)
		if is_instance_valid(model): model.rotation.x = sin(recoil * 25.0) * recoil * 0.3

class PracticeGame:
	extends Node3D
	var state = State.new()
	var player: PracticeCaster
	var world: Node3D
	var magic
	var audio = null
	var mode := "play"
	func toast(_message: String) -> void: pass
	func is_title_context() -> bool: return false

var hud
var viewport: SubViewport
var surface: SubViewportContainer
var preview: PracticeGame
var dummy: PracticeDummy
var props: Array = []
var camera: Camera3D
var cover: StaticBody3D
var readout: Label
var caption: Label
var current_spell: Dictionary = {}
var target_kind := "enemy"
var target_status := "none"
var cover_enabled := false
var _manual_target := false
var _signature := ""
var _rect := Rect2()
var _touches: Dictionary = {}
var _mouse_owned := false
var _replay_wait := -1.0
var _casting_time := -1.0
var _age := 0.0
var _camera_yaw := 0.4
var _camera_pitch := 0.35
var _camera_distance := 8.8
var _borrowed_physics := false
var _real_space := RID()
var _last_error := ""
var _real_camera: WeakRef
var _real_camera_mask := 0
var _exiting := false

func setup(owner_hud) -> void:
	hud = owner_hud
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() == null: hud.add_child(self)
	set_process(true)

func _make_surface() -> void:
	if is_instance_valid(surface): return
	surface = SubViewportContainer.new(); surface.name = "SpellRehearsalSurface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE; surface.stretch = true
	hud.add_child(surface)
	viewport = SubViewport.new(); viewport.name = "PrivateSpellWorld"
	viewport.own_world_3d = true; viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false; viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	surface.add_child(viewport)
	caption = Label.new(); caption.text = "SPELL REHEARSAL · REAL COLLISIONS"
	caption.position = Vector2(12, 8); caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color("#b9e7e9"))
	caption.add_theme_color_override("font_outline_color", Color("#10151f")); caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; surface.add_child(caption)
	readout = Label.new(); readout.add_theme_font_size_override("font_size", 12)
	readout.add_theme_color_override("font_color", Color("#f4e4c3"))
	readout.add_theme_color_override("font_outline_color", Color("#10151f")); readout.add_theme_constant_override("outline_size", 4)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE; surface.add_child(readout)

func _build_world() -> void:
	_make_surface()
	preview = PracticeGame.new(); preview.name = "TemporaryRehearsal"
	preview.process_mode = Node.PROCESS_MODE_ALWAYS; viewport.add_child(preview)
	if is_instance_valid(hud.game) and hud.game.state != null:
		preview.state.settings = hud.game.state.settings.duplicate(true)
		preview.audio = hud.game.get("audio")
	preview.state.mana = 100.0; preview.state.health = preview.state.max_health
	preview.world = Node3D.new(); preview.add_child(preview.world)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("#182331")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("#b0c2dd"); env.ambient_light_energy = 0.55
	environment.environment = env; preview.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_energy = 1.2; sun.light_color = Color("#ffedcb"); sun.shadow_enabled = false; preview.add_child(sun)
	var stone = B.world_surface("stone", "#4c5665")
	B.box(preview.world, Vector3(0, -0.22, -1.8), Vector3(13, 0.4, 16), stone, true)
	B.cyl(preview.world, Vector3(0, -0.04, -1.8), 4.1, 0.16, stone, true)
	B.ring(preview.world, Vector3(0, 0.05, -1.8), 3.85, 0.024, B.mat("#b7a173", 0.7))
	for i in range(8):
		var a := float(i) / 8.0 * TAU
		B.box(preview.world, Vector3(cos(a) * 3.8, 0.06, -1.8 + sin(a) * 3.8), Vector3(0.14, 0.07, 0.28), B.mat("#a9a28b", 0.6))
	cover = StaticBody3D.new(); cover.name = "PracticeCover"; cover.collision_layer = 1; cover.collision_mask = 0
	preview.world.add_child(cover)
	B.box(cover, Vector3.ZERO, Vector3(1.6, 1.8, 0.35), stone)
	var cover_shape := CollisionShape3D.new(); var wall_shape := BoxShape3D.new(); wall_shape.size = Vector3(1.6, 1.8, 0.35); cover_shape.shape = wall_shape; cover.add_child(cover_shape)
	cover.position = Vector3(2.0, 0.95, -2.6)
	preview.player = PracticeCaster.new(); preview.player.state = preview.state
	preview.player.process_mode = Node.PROCESS_MODE_ALWAYS
	preview.player.collision_layer = 2; preview.player.collision_mask = 1 | 8
	preview.player.position = Vector3(0, 0.06, 1.3); preview.add_child(preview.player)
	var collision := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.height = Hero.STANDING_HEIGHT_METRES; capsule.radius = 0.21
	collision.shape = capsule; collision.position.y = Hero.STANDING_HEIGHT_METRES * 0.5; preview.player.add_child(collision)
	preview.player.visual = Hero.new(); preview.player.add_child(preview.player.visual)
	preview.player.visual.set_weapon("grimoire")
	preview.player.visual.set_motion_context(Vector3.ZERO, true)
	camera = Camera3D.new(); camera.fov = 49; preview.add_child(camera); camera.current = true
	preview.player.camera = camera; _update_camera()
	preview.magic = Magic.new(); preview.magic.setup(preview); preview.add_child(preview.magic)
	_create_targets()

func _create_targets() -> void:
	dummy = PracticeDummy.new(); dummy.name = "RehearsalDummy"; dummy.process_mode = Node.PROCESS_MODE_ALWAYS
	dummy.collision_layer = 4; dummy.collision_mask = 1 | 8
	dummy.position = Vector3(0, 0.08, -4.6); dummy.home = dummy.position
	preview.world.add_child(dummy); dummy.add_to_group("enemy")
	var shape := CollisionShape3D.new(); var body := CapsuleShape3D.new(); body.height = 1.7; body.radius = 0.34
	shape.shape = body; shape.position.y = 0.85; dummy.add_child(shape)
	dummy.model = Node3D.new(); dummy.add_child(dummy.model)
	var brass = B.mat("#b7a77d", 0.65); var leather = B.mat("#65534a")
	B.cyl(dummy.model, Vector3(0, 0.48, 0), 0.095, 0.85, brass)
	B.ball(dummy.model, Vector3(0, 1.06, 0), Vector3(0.57, 0.7, 0.32), leather)
	B.ball(dummy.model, Vector3(0, 1.57, 0), Vector3.ONE * 0.33, brass)
	B.ring(dummy.model, Vector3(0, 1.1, 0.18), 0.22, 0.025, B.mat("#c4d8e3", 0.3))
	for side in [-1.0, 1.0]: B.ball(dummy.model, Vector3(side * 0.43, 1.08, 0), Vector3(0.22, 0.22, 0.28), brass)
	props = []
	for i in range(3):
		var prop := RigidBody3D.new(); prop.name = "PracticeCrate%d" % i
		prop.process_mode = Node.PROCESS_MODE_ALWAYS; prop.collision_layer = 8; prop.collision_mask = 1 | 2 | 4 | 8
		prop.mass = 2.0 + float(i); prop.linear_damp = 0.2; prop.angular_damp = 0.3
		prop.position = [Vector3(-0.85, 0.4, -0.2), Vector3(0.85, 0.4, -2.5), Vector3(-1.25, 0.4, -3.6)][i]
		var col := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3.ONE * 0.6; col.shape = box; prop.add_child(col)
		B.box(prop, Vector3.ZERO, Vector3.ONE * 0.6, B.world_surface("wood", "#8e6d43"))
		for side in [-1.0, 1.0]: B.box(prop, Vector3(side * 0.23, 0, 0.312), Vector3(0.055, 0.6, 0.025), brass)
		preview.world.add_child(prop); prop.add_to_group("carryable"); props.append(prop)
	_apply_target_options()

func show_spell(raw: Dictionary, rect: Rect2) -> void:
	if not is_instance_valid(hud) or not is_instance_valid(hud.game): return
	if not hud.game is Node3D: return
	var spell := raw.duplicate(true)
	if str(spell.get("name", "")).strip_edges().is_empty(): spell.name = "Unnamed spell"
	var clean := Book.sanitize(spell)
	if clean.is_empty(): return
	if not is_instance_valid(preview): _build_world()
	_suspend_world_render()
	_rect = rect
	var ratio: Vector2 = hud.get_viewport_rect().size / Vector2(1280, 720)
	if ratio.x <= 0 or ratio.y <= 0: ratio = Vector2.ONE
	surface.position = rect.position * ratio; surface.size = rect.size * ratio

	readout.position = Vector2(12, maxf(12, rect.size.y * ratio.y - 26))
	surface.show()
	var signature := JSON.stringify(clean)
	if signature != _signature:
		_signature = signature; current_spell = clean
		if not _manual_target: target_kind = "objects" if str(clean.targeting) == "objects" else "enemy"
		_apply_target_options(); _replay_wait = 0.18
	_sync_physics()

func replay(raw: Dictionary = {}) -> bool:
	var clean := Book.sanitize(current_spell if raw.is_empty() else raw)
	if clean.is_empty(): return false
	if not is_instance_valid(preview): _build_world()
	current_spell = clean; _replay_wait = -1.0
	reset(); _apply_target_options()
	preview.player.visual.begin_grimoire_cast(Color(str(clean.color)), 0.62)
	var aim := dummy.global_position + Vector3.UP * 0.9
	if target_kind == "objects" and not props.is_empty(): aim = props[0].global_position
	if str(clean.targeting) == "projectiles":

		var incoming := Book.defaults("rehearsal_incoming"); incoming.element = "light"; incoming.count = 4
		incoming.speed = 8.0; incoming.lifetime = 3.0; incoming.spread = 18.0; incoming.trajectory = "fan"
		preview.magic.cast(incoming, Vector3(0, 1, -8)); preview.magic.cooldown_remaining = 0.0; preview.state.mana = 100.0
	var accepted: bool = preview.magic.cast(clean, aim)
	_last_error = ""
	if not accepted and preview.magic.has_method("admission_reason"): _last_error = preview.magic.admission_reason(clean, aim)
	if accepted: _casting_time = 0.0
	return accepted

func reset() -> void:
	_replay_wait = -1.0; _casting_time = -1.0; _age = 0.0
	_last_error = ""
	if not is_instance_valid(preview): return
	preview.magic.clear_effects(); preview.state.mana = 100.0; preview.state.health = preview.state.max_health
	if is_instance_valid(dummy): dummy.free()
	for prop in props:
		if is_instance_valid(prop): prop.free()
	props.clear(); _create_targets()
	preview.player.visual.cancel_grimoire_cast()
	preview.player.position = Vector3(0, 0.06, 1.3)
	_sync_physics()

func set_target_kind(value: String) -> void:
	if value not in ["enemy", "objects", "both"]: return
	target_kind = value; _manual_target = true; _apply_target_options()

func set_target_status(value: String) -> void:
	if value not in ["none", "wet", "frozen", "burning"]: return
	target_status = value
	if is_instance_valid(preview):
		reset(); _apply_target_options()

func set_cover(enabled: bool) -> void:
	cover_enabled = enabled; _apply_target_options()

func _apply_target_options() -> void:
	if is_instance_valid(dummy):
		dummy.visible = target_kind != "objects"; dummy.collision_layer = 4 if dummy.visible else 0
		if dummy.visible and not dummy.is_in_group("enemy"): dummy.add_to_group("enemy")
		elif not dummy.visible and dummy.is_in_group("enemy"): dummy.remove_from_group("enemy")
	for prop in props:
		if is_instance_valid(prop): prop.visible = true
	if is_instance_valid(cover): cover.position = Vector3(0 if cover_enabled else 2.0, 0.95, -2.6)
	if target_status != "none" and is_instance_valid(preview) and is_instance_valid(preview.magic) and is_instance_valid(dummy) and preview.magic.has_method("set_status"):
		preview.magic.set_status(dummy, target_status, 10.0)

func stats() -> Dictionary:
	var result: Dictionary = {"damage": dummy.hits if is_instance_valid(dummy) else 0, "objects": props.size(), "age": _age, "target": target_kind, "status": target_status, "cover": cover_enabled, "admission_reason": _last_error}
	if is_instance_valid(preview):
		result["mana"] = preview.state.mana
		if preview.magic.has_method("stats"): result.merge(preview.magic.stats(), true)
	return result

func _process(dt: float) -> void: tick(dt)

func tick(dt: float) -> void:
	if not is_instance_valid(preview) or not is_finite(dt) or dt <= 0: return
	if not is_instance_valid(hud) or not is_instance_valid(hud.game) or str(hud.game.mode) != "spellforge": close(); return
	_sync_physics()
	_age += dt
	if _replay_wait >= 0:
		_replay_wait -= dt
		if _replay_wait <= 0: replay()
	preview.magic.tick(minf(dt, 0.15))
	preview.player.visual.animate(dt, "idle", 0.0)
	if _casting_time >= 0:
		_casting_time += dt
		var weight := smoothstep(0.08, 0.25, _casting_time) * (1.0 - smoothstep(0.75, 1.15, _casting_time))
		preview.player.visual._solve_arm(1, Vector3(0.3, 0.38, -0.72), weight)
		if _casting_time > 1.2: _casting_time = -1.0
	var data := stats()
	if is_instance_valid(readout): readout.text = "Spell exceeds practice limits" if not _last_error.is_empty() else "%d damage  ·  %d mana  ·  drag to orbit" % [data.damage, int(data.get("mana", 100))]

func _sync_physics() -> void:
	if not is_inside_tree() or not is_instance_valid(preview): return


	if get_tree().paused:
		if not _borrowed_physics:
			_real_space = hud.game.get_world_3d().space
			_borrowed_physics = true
		PhysicsServer3D.space_set_active(_real_space, false)
		PhysicsServer3D.set_active(true)
		PhysicsServer3D.space_set_active(preview.get_world_3d().space, true)
	elif _borrowed_physics: _restore_physics()

func _restore_physics() -> void:
	if not _borrowed_physics: return
	if _real_space.is_valid(): PhysicsServer3D.space_set_active(_real_space, true)
	if is_inside_tree(): PhysicsServer3D.set_active(not get_tree().paused)
	_borrowed_physics = false; _real_space = RID()

func _suspend_world_render() -> void:
	if _real_camera != null and is_instance_valid(_real_camera.get_ref()): return
	var real_view: Camera3D = hud.get_viewport().get_camera_3d()
	if is_instance_valid(real_view):
		_real_camera = weakref(real_view); _real_camera_mask = real_view.cull_mask; real_view.cull_mask = 0

func _restore_world_render() -> void:
	if _real_camera != null and is_instance_valid(_real_camera.get_ref()): _real_camera.get_ref().cull_mask = _real_camera_mask
	_real_camera = null

func _update_camera() -> void:
	if not is_instance_valid(camera): return
	var focus := Vector3(0, 0.85, -1.8)
	var offset := Vector3(sin(_camera_yaw) * cos(_camera_pitch), sin(_camera_pitch), cos(_camera_yaw) * cos(_camera_pitch)) * _camera_distance
	camera.global_position = focus + offset; camera.look_at(focus)

func drag_camera(delta: Vector2) -> void:
	_camera_yaw -= delta.x * 0.007; _camera_pitch = clampf(_camera_pitch + delta.y * 0.005, 0.12, 1.1); _update_camera()

func handle_input(event: InputEvent) -> bool:
	if not is_instance_valid(surface) or not surface.visible: return false
	var area := Rect2(surface.global_position, surface.size)
	if event is InputEventScreenTouch:
		if event.pressed and area.has_point(event.position): _touches[event.index] = event.position; return true
		if not event.pressed and _touches.has(event.index): _touches.erase(event.index); return true
	elif event is InputEventScreenDrag and _touches.has(event.index):
		drag_camera(event.relative); _touches[event.index] = event.position; return true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and area.has_point(event.position): _mouse_owned = true; return true
			if not event.pressed and _mouse_owned: _mouse_owned = false; return true
		elif event.pressed and area.has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_camera_distance = clampf(_camera_distance + (-0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5), 5.0, 12.0); _update_camera(); return true
	elif event is InputEventMouseMotion and _mouse_owned: drag_camera(event.relative); return true
	return false

func close() -> void:
	_replay_wait = -1.0; _casting_time = -1.0; _touches.clear(); _mouse_owned = false
	if is_instance_valid(preview):
		preview.magic.clear_effects()
		preview.free()
	preview = null; dummy = null; props.clear(); camera = null; cover = null
	if is_instance_valid(surface):
		if _exiting: surface.queue_free()
		else: surface.free()
	surface = null; viewport = null; readout = null; caption = null
	_signature = ""; current_spell.clear(); _restore_physics()
	_restore_world_render()

func _exit_tree() -> void:
	_exiting = true; close()
