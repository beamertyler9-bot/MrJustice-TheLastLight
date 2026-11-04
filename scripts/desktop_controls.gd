extends Node

var game
var enabled := false:
	set(value):
		enabled = value
		set_process(value); set_process_input(value)
var wants_capture := false
var aim_held := false
var primary_held := false
var _last_mode = ""
func setup(context) -> void:
	game = context
	enabled = OS.has_feature("pc_controls") or (OS.has_feature("editor") and DisplayServer.get_name() != "headless")
	process_mode = Node.PROCESS_MODE_ALWAYS
func sync_mode() -> void:
	if not enabled or game == null: return
	var mode = str(game.mode)
	if mode != _last_mode:
		aim_held = false; primary_held = false
		if is_instance_valid(game.player): game.player.end_ability_aim(false)
		_last_mode = mode
	wants_capture = mode == "play" and is_instance_valid(game.player)
	if DisplayServer.get_name() != "headless":
		var desired = Input.MOUSE_MODE_CAPTURED if wants_capture else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != desired: Input.mouse_mode = desired
func _process(_dt: float) -> void:
	if not enabled: return
	sync_mode()
	if aim_held and wants_capture and not game.player.ability_aiming and game.player.cast_time <= 0 and game.player.beam_contact < 0:
		_begin_aim()
func _begin_aim() -> void:
	var player = game.player
	if player.cast_time > 0 or player.beam_contact >= 0 or player.visual.is_grimoire_casting(): return
	if player.begin_ability_aim(player.grimoire_equipped()): player.beam_aim_toggled = player.ability_id == "beam" and not player.grimoire_equipped()
func _input(event: InputEvent) -> void:
	if not enabled or game == null: return
	sync_mode()
	var handled = false
	if event is InputEventKey and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_TAB and game.mode in ["play", "bag"]:
			if event.pressed: game.set_mode("bag" if game.mode == "play" else "play")
			handled = true
		elif code == KEY_ESCAPE:
			if event.pressed: game.navigate_back()
			handled = true
		elif code == KEY_SPACE and game.mode == "play":
			if event.pressed: game.player.jump()
			handled = true
		elif code == KEY_E and game.mode == "play":
			if event.pressed: game.begin_context_action(true)
			else: game.end_context_action(false)
			handled = true
		elif code == KEY_F and game.mode == "play":
			if event.pressed: game.player.toggle_lock_on()
			handled = true
	elif event is InputEventMouseMotion and wants_capture:
		game.player.look(event.relative); handled = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and (wants_capture or aim_held):
			aim_held = event.pressed and wants_capture
			if aim_held: _begin_aim()
			else: game.player.end_ability_aim(false)
			handled = true
		elif event.button_index == MOUSE_BUTTON_LEFT and (wants_capture or primary_held):
			var player = game.player
			if event.pressed and wants_capture:
				primary_held = true
				if player.grimoire_equipped(): player.cast_spell()
				elif player.ability_aiming and player.ability_id == "beam": player.begin_primary_action()
				elif player.ability_aiming: player.use_ability()
				else: player.attack()
			elif not event.pressed:
				primary_held = false; player.end_primary_action(not wants_capture)
			handled = true
		elif wants_capture and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if game.magic != null and game.magic.has_levitated_object(): game.magic.adjust_levitation_distance(0.6 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.6)
			else: game.player.adjust_zoom(-0.6 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.6)
			handled = true
	if handled: get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if enabled and what == NOTIFICATION_WM_CLOSE_REQUEST and game != null:
		game._save_current_state(); get_tree().quit()
func _exit_tree() -> void:
	if enabled and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
