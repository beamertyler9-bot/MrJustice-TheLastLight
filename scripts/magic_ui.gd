extends RefCounted

const Spellbook = preload("res://scripts/spellbook.gd")
const PAPER := Color("#f7edd8")
const INK := Color("#15191e")
const SLATE := Color("#262c33")
const FAINT := Color("#b9b3a7")
const CYAN := Color("#85e1e5")
const GOLD := Color("#e7c783")
const VIOLET := Color("#b59bff")
const RED := Color("#e47772")
const PALETTE := ["#ff794e", "#ffd36c", "#82df9b", "#82d9ff", "#8c9aff", "#b68bff", "#efb6ff", "#fff7d8"]
const FORM_NAMES := {"volley": "Volley", "beam": "Beam", "burst": "Burst", "ward": "Ward", "mend": "Mend", "step": "Step", "touch": "Touch", "field": "Field", "cone": "Cone", "rain": "Rain", "orbitals": "Orbitals", "trap": "Trap", "wall": "Wall", "summon": "Summon", "strike": "Sky strike"}
const STEP_NAMES := ["Essence", "Delivery", "Weave", "Appearance", "Test", "Inscribe"]
const COLOR_KEYS := ["color", "core_color", "rim_color", "trail_color", "accent"]
const HISTORY_LIMIT := 48
const PREVIEW_RECT := Rect2(842, 142, 358, 288)
const STEPS := {"count": 1.0, "power": 1.0, "speed": 1.0, "spread": 1.0, "size": 0.01, "lifetime": 0.1, "radius": 0.1, "intensity": 1.0, "delay": 0.1, "pulses": 1.0, "interval": 0.1, "duration": 0.5, "force": 1.0, "range": 1.0, "mass_limit": 0.5, "pierces": 1.0, "bounces": 1.0, "chains": 1.0, "particle_density": 0.25, "particle_size": 0.1, "trail_width": 0.1, "spin": 0.25, "pulse_speed": 0.25, "glow": 0.1, "opacity": 0.05, "stage_delay": 0.1, "repeat_contacts": 1.0, "stagger": 0.05, "homing": 0.25, "orbit_radius": 0.1, "return_time": 0.1, "hold_time": 0.1, "slow_factor": 0.05, "edge_noise": 0.1, "trail_length": 0.1, "trail_fade": 0.1, "particle_drift": 0.1, "impact_scale": 0.1, "cast_scale": 0.1, "residual_motes": 0.25, "cone_angle": 5.0, "rain_height": 0.5, "wall_width": 0.25, "wall_height": 0.25, "wall_thickness": 0.1, "summon_count": 1.0}
var h
var game
var draft: Dictionary = {}
var selected_id := ""
var selected_stage := 0
var editor_step := 0
var tab := 0
var page := 0
var preset_index := 0
var creator_mode := "guided"
var section := 0
var template_page := 0
var color_target := "color"
var library_filter := "all"
var search_query := ""
var delete_pending := ""
var status := ""
var name_entry: LineEdit
var search_entry: LineEdit


var number_entries: Dictionary = {}
var _visible_numbers: Dictionary = {}
var rehearsal
var rehearsal_target := "enemy"
var rehearsal_status := "none"
var rehearsal_cover := false
var _serial := 0
var _last_mode := ""
var _starters: Array = Spellbook.starters()
var _undo: Array = []
var _redo: Array = []
var _name_change_active := false
var _syncing_fields := false
var _text_pointers: Dictionary = {}
var _preview_signature := 0
var _preview_rect := Rect2()
var _preview_viewport_size := Vector2.ZERO
var _manual_rehearsal_target := false

func setup(hud) -> void:
	h = hud
	game = hud.game
	if is_instance_valid(name_entry): return
	name_entry = _text_field("SpellName", "Give your spell a name", 36)
	name_entry.text_changed.connect(_name_changed)
	name_entry.text_submitted.connect(_text_submitted)
	name_entry.focus_exited.connect(_name_focus_exited)
	search_entry = _text_field("SpellSearch", "Search spells or elements", 64)
	search_entry.text_changed.connect(_search_changed)
	search_entry.text_submitted.connect(_text_submitted)
	for key in Spellbook.LIMITS: _create_number_entry(str(key))
	for channel in ["r", "g", "b"]: _create_number_entry("rgb_" + channel)

func _text_field(node_name: String, placeholder: String, length_limit: int) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	field.max_length = length_limit
	field.placeholder_text = placeholder
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	field.virtual_keyboard_enabled = true
	field.clear_button_enabled = true
	field.add_theme_font_override("font", h.body_font)
	field.add_theme_font_size_override("font_size", 20)
	field.add_theme_color_override("font_color", PAPER)
	field.add_theme_color_override("caret_color", CYAN)
	var style := StyleBoxFlat.new()
	style.bg_color = SLATE
	style.border_color = Color(CYAN, 0.65)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	field.add_theme_stylebox_override("normal", style)
	var focused: StyleBoxFlat = style.duplicate()
	focused.border_color = CYAN
	focused.set_border_width_all(2)
	field.add_theme_stylebox_override("focus", focused)
	field.hide()
	h.add_child(field)
	return field

func _create_number_entry(key: String) -> void:
	var field := _text_field("SpellNumber_" + key, "", 24)
	field.clear_button_enabled = false


	field.add_theme_constant_override("minimum_character_width", 1)
	field.select_all_on_focus = true
	field.virtual_keyboard_show_on_focus = true
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER if _whole_number(key) else LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	field.add_theme_font_size_override("font_size", 20)
	field.set_meta("number_key", key)
	field.set_meta("editing_number", false)
	field.focus_entered.connect(_number_focus_entered.bind(field))
	field.focus_exited.connect(_number_focus_exited.bind(field))
	field.text_submitted.connect(_number_submitted.bind(field))
	number_entries[key] = field
	_number_error(field, false)

func numeric_entry(key: String) -> LineEdit:

	return number_entries.get(key)

func _whole_number(key: String) -> bool:
	return key in Spellbook.INTEGER_FIELDS or key.begins_with("rgb_")

func _text_fields() -> Array:
	return [name_entry, search_entry] + number_entries.values()

func _number_text(key: String) -> String:
	var recipe := _recipe()
	if recipe.is_empty(): return ""
	if key.begins_with("rgb_"):
		var color := Color(str(recipe.get(color_target, "#ffffff")))
		return str(int(roundf(float(color[key.right(1)]) * 255.0)))
	return _format_number(float(recipe.get(key, 0)), _whole_number(key))

func _format_number(value: float, whole := false) -> String:
	if whole: return str(int(value))
	var text := String.num(value, 6)
	if text.contains("."):
		while text.ends_with("0"): text = text.left(-1)
		if text.ends_with("."): text = text.left(-1)
	return text

func _number_error(field: LineEdit, invalid: bool) -> void:
	var normal: StyleBoxFlat = field.get_theme_stylebox("normal").duplicate()
	normal.border_color = RED if invalid else Color(PAPER, 0.35)
	field.add_theme_stylebox_override("normal", normal)

func _number_focus_entered(field: LineEdit) -> void:
	if not field.has_meta("number_context"): return
	var context: Dictionary = field.get_meta("number_context").duplicate(true)
	context["initial_text"] = field.text
	field.set_meta("edit_context", context)
	field.set_meta("editing_number", true)
	_number_error(field, false)
	status = "Editing %s · Enter or tap away to apply · Esc cancels." % str(field.get_meta("number_context").title).to_lower()

func _number_focus_exited(field: LineEdit) -> void:
	_finish_number(field)

func _number_submitted(_value: String, _field: LineEdit) -> void:
	_release_text_focus()

func _finish_number(field: LineEdit) -> bool:
	if not bool(field.get_meta("editing_number", false)): return true


	field.set_meta("editing_number", false)
	var context: Dictionary = field.get_meta("edit_context", {})
	var key := str(field.get_meta("number_key"))
	if draft.is_empty() or game.mode != "spellforge" or not delete_pending.is_empty() or int(context.get("stage", -1)) != selected_stage or str(context.get("id", "")) != str(draft.get("id", "")) or (key.begins_with("rgb_") and str(context.get("color", "")) != color_target):
		field.text = _number_text(key)
		return true
	var raw := field.text.strip_edges()


	if raw == str(context.get("initial_text", "")):
		field.text = _number_text(key)
		status = "Value unchanged · draft only."
		return true
	var valid := raw.is_valid_float()
	var amount := float(raw) if valid else 0.0
	valid = valid and is_finite(amount)
	if valid and _whole_number(key): valid = amount == floorf(amount)
	if not valid:
		status = "Value rejected · enter a finite %s. Draft unchanged." % ("whole number" if _whole_number(key) else "number")
		field.text = _number_text(key)
		_number_error(field, true)
		return false
	var limits: Array = context.get("limits", [0.0, 0.0])
	var bounded := clampf(amount, float(limits[0]), float(limits[1]))
	var changes: Dictionary = {}
	if key.begins_with("rgb_"):
		var color := Color(str(_recipe()[color_target]))
		color[key.right(1)] = bounded / 255.0
		changes[color_target] = "#" + color.to_html(false)
	else:
		if not setting_enabled(key):
			field.text = _number_text(key)
			return true
		changes[key] = int(bounded) if _whole_number(key) else bounded
	var needs_change := false
	for changed_key in changes:
		if _recipe().get(changed_key) != changes[changed_key]: needs_change = true
	var applied := _apply_changes(changes) if needs_change else false
	field.text = _number_text(key)
	if needs_change and not applied:
		status = "Value rejected · that change could not be applied. Draft unchanged."
		_number_error(field, true)
		return false
	_number_error(field, false)
	status = "%s %s%s · draft only." % [str(context.get("title", key)).capitalize(), "set to " if applied else "kept at ", field.text]
	if not is_equal_approx(amount, bounded): status = "Clamped to %s (%s–%s) · draft only." % [field.text, _format_number(limits[0]), _format_number(limits[1])]
	return true

func _cancel_number(field: LineEdit) -> void:
	field.set_meta("editing_number", false)
	field.text = _number_text(str(field.get_meta("number_key")))
	_number_error(field, false)
	field.release_focus()
	_hide_keyboard()
	status = "Number edit cancelled · draft unchanged."

func _discard_number_edits() -> void:
	for field in number_entries.values(): field.set_meta("editing_number", false)

func _name_changed(value: String) -> void:
	if _syncing_fields or draft.is_empty() or game.mode != "spellforge": return
	if str(draft.name) == value: return
	if not _name_change_active: _remember()

	draft.name = value.left(36)
	_name_change_active = true
	status = "Name changed · draft only."

func _name_focus_exited() -> void:
	_name_change_active = false

func _search_changed(value: String) -> void:
	search_query = value.left(64).strip_edges().to_lower()
	page = 0
	var matches := filtered_library()
	var keeps_selection := false
	for spell in matches:
		if str(spell.id) == selected_id: keeps_selection = true
	if not keeps_selection and not matches.is_empty(): selected_id = str(matches[0].id)

func _text_submitted(_value: String) -> void:
	_release_text_focus()

func _release_text_focus() -> bool:
	var accepted := true
	for field in _text_fields():
		if is_instance_valid(field) and field.has_focus():
			if field.has_meta("number_key"): accepted = _finish_number(field) and accepted
			field.release_focus()
	_hide_keyboard()
	return accepted

func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()

func tick(_dt: float = 0.0) -> void:
	if not is_instance_valid(name_entry): return
	if _last_mode == "spellforge" and game.mode != "spellforge":
		_close_rehearsal()
		if game.mode != "grimoire": cancel_draft()
	var editing: bool = game.mode == "spellforge" and not draft.is_empty() and delete_pending.is_empty()
	var browsing: bool = game.mode == "grimoire" and delete_pending.is_empty()
	name_entry.visible = editing
	search_entry.visible = browsing
	if not editing:
		_discard_number_edits()
		for field in number_entries.values(): field.hide()
	for field in _text_fields():
		if not field.visible and field.has_focus():
			field.release_focus()
			_hide_keyboard()
	var ratio: Vector2 = h.get_viewport_rect().size / Vector2(1280, 720)
	if ratio.x <= 0 or ratio.y <= 0: ratio = Vector2.ONE
	name_entry.position = Vector2(80, 142) * ratio
	name_entry.size = Vector2(734, 48)
	name_entry.scale = ratio
	search_entry.position = Vector2(80, 144) * ratio
	search_entry.size = Vector2(340, 48)
	search_entry.scale = ratio
	for key in number_entries:
		var field: LineEdit = number_entries[key]
		if field.has_meta("number_rect"):
			var rect: Rect2 = field.get_meta("number_rect")
			field.position = rect.position * ratio
			field.size = rect.size
			field.scale = ratio
	_last_mode = str(game.mode)

func near_altar() -> bool:
	return game.has_method("near_spell_altar") and game.near_spell_altar()

func library() -> Array:
	var value = game.state.get("spellbook")
	return value if value is Array else []

func filtered_library() -> Array:
	var result: Array = []
	for spell in library():
		var starter := is_starter(str(spell.id))
		if library_filter == "starter" and not starter: continue
		if library_filter == "custom" and starter: continue
		if not search_query.is_empty():
			var haystack := "%s %s %s %s %s %s" % [spell.name, spell.form, spell.element, spell.get("effect", ""), spell.get("secondary_effect", ""), spell.get("tertiary_effect", "")]
			if not haystack.to_lower().contains(search_query): continue
		result.append(spell)
	return result

func selected_spell() -> Dictionary:
	var spell: Dictionary = game.state.spell_by_id(selected_id)
	if spell.is_empty() and not library().is_empty():
		selected_id = str(library()[0].id)
		spell = game.state.spell_by_id(selected_id)
	return spell

func is_starter(id: String) -> bool:
	for spell in _starters:
		if str(spell.id) == id: return true
	return false

func _new_id() -> String:
	_serial += 1
	var id := "custom_%d_%d" % [Time.get_ticks_msec(), _serial]
	while not game.state.spell_by_id(id).is_empty():
		_serial += 1
		id = "custom_%d_%d" % [Time.get_ticks_msec(), _serial]
	return id

func begin_edit(id: String = "", clone := false) -> bool:
	if not near_altar():
		status = "Create and edit beside the tower's spell altar."
		if game.has_method("toast"): game.toast(status)
		return false
	var source: Dictionary = game.state.spell_by_id(id) if not id.is_empty() else {}
	if not id.is_empty() and source.is_empty(): return false
	if not clone and not source.is_empty() and is_starter(id): clone = true
	var candidate: Dictionary = Spellbook.sanitize(source) if not source.is_empty() else Spellbook.defaults(_new_id())
	if candidate.is_empty(): return false
	if clone:
		candidate.id = _new_id()
		candidate.name = (str(candidate.name).left(30) + " remix").left(36)
	_discard_number_edits()
	draft = candidate.duplicate(true)
	selected_stage = 0
	editor_step = 0
	tab = 0
	section = 0
	creator_mode = "guided" if source.is_empty() else "advanced"
	color_target = "color"
	delete_pending = ""
	_undo.clear()
	_redo.clear()
	_name_change_active = false
	_sync_name()
	_release_text_focus()
	status = "Unsaved draft · test safely, then inscribe at the altar."
	tick()
	return true

func cancel_draft() -> void:
	_close_rehearsal()
	_discard_number_edits()
	draft.clear()
	_undo.clear()
	_redo.clear()
	_text_pointers.clear()
	_name_change_active = false
	delete_pending = ""
	status = ""
	_release_text_focus()
	if is_instance_valid(name_entry): name_entry.hide()
	for field in number_entries.values(): field.hide()

func _safe_root() -> Dictionary:
	if draft.is_empty(): return {}
	var candidate := draft.duplicate(true)
	if str(candidate.get("name", "")).strip_edges().is_empty(): candidate.name = "Unnamed spell"
	return candidate

func _recipe() -> Dictionary:


	if draft.is_empty(): return {}
	if selected_stage == 0:
		var first := draft.duplicate()
		first.erase("stages")
		return first
	var successors: Variant = draft.get("stages", [])
	if not successors is Array or selected_stage > successors.size(): return {}
	return successors[selected_stage - 1].duplicate() if successors[selected_stage - 1] is Dictionary else {}

func _snapshot() -> Dictionary:
	return {"draft": draft.duplicate(true), "stage": selected_stage}

func _remember() -> void:
	_undo.append(_snapshot())
	if _undo.size() > HISTORY_LIMIT: _undo.pop_front()
	_redo.clear()

func _sync_name() -> void:
	if not is_instance_valid(name_entry): return
	_syncing_fields = true
	name_entry.text = str(draft.get("name", ""))
	_syncing_fields = false

func _commit(candidate: Dictionary, message := "Draft changed · not inscribed.") -> bool:
	if candidate.is_empty(): return false
	var local_name := str(candidate.get("name", ""))
	var safe := candidate.duplicate(true)
	if local_name.strip_edges().is_empty(): safe.name = "Unnamed spell"
	var canonical := Spellbook.sanitize(safe)
	if canonical.is_empty():
		status = "That combination could not be applied. Your draft is unchanged."
		return false
	canonical.name = local_name
	if canonical == draft: return false
	_remember()
	draft = canonical
	selected_stage = clampi(selected_stage, 0, Spellbook.stage_count(_safe_root()) - 1)
	_name_change_active = false
	_sync_name()
	status = message
	return true

func _apply_changes(changes: Dictionary) -> bool:
	if draft.is_empty() or game.mode != "spellforge" or not delete_pending.is_empty(): return false
	var local_name := str(draft.name)
	var candidate := Spellbook.update_stage(_safe_root(), selected_stage, changes)
	if candidate.is_empty(): return false
	candidate.name = local_name
	return _commit(candidate)

func _history(redoing: bool) -> void:
	if draft.is_empty() or game.mode != "spellforge" or not delete_pending.is_empty(): return
	var source: Array = _redo if redoing else _undo
	var target: Array = _undo if redoing else _redo
	if source.is_empty(): return
	target.append(_snapshot())
	var previous: Dictionary = source.pop_back()
	draft = previous.draft.duplicate(true)
	selected_stage = int(previous.stage)
	_name_change_active = false
	_sync_name()
	status = "Redid draft change." if redoing else "Undid draft change."

func _section_keys() -> Array:
	match editor_step:
		0: return ["element", "power", "targeting"]
		1:
			match section:
				0: return ["form", "projectile", "trajectory", "impact", "range", "radius"]
				1: return ["count", "power", "speed", "spread", "size", "lifetime", "radius", "duration"]
				2: return ["pierces", "bounces", "chains", "stagger", "homing", "return_time"]
				3: return ["orbit_radius", "hold_time", "cone_angle", "rain_height", "duration", "radius", "wall_width", "wall_height", "wall_thickness", "summon_kind", "summon_count"]
		2:
			match section:
				0: return ["effect", "secondary_effect", "tertiary_effect", "targeting", "condition", "repeat_contacts"]
				1: return ["when", "stage_delay", "trigger", "delay", "pulses", "interval"]
				2: return ["force", "mass_limit", "duration", "range", "slow_factor", "orbit_radius"]
		3:
			match section:
				0: return ["color", "accent", "core_color", "rim_color", "trail_color", "intensity"]
				1: return ["particles", "particle_density", "particle_size", "intensity", "glow", "opacity"]
				2: return ["trail", "spin", "trail_width", "pulse_speed", "trail_length", "trail_fade"]
				3: return ["material_style", "sigil", "impact_accent", "edge_noise", "particle_drift"]
				4: return ["cast_scale", "impact_scale", "residual_motes"]
	return []

func _reset_section() -> void:
	var keys := _section_keys()
	if keys.is_empty() or draft.is_empty(): return
	var defaults := Spellbook.defaults(str(draft.id))
	var changes: Dictionary = {}
	for key in keys:
		if selected_stage == 0 and key in ["when", "condition", "stage_delay", "repeat_contacts"]: continue
		changes[key] = defaults[key]
	if _apply_changes(changes): status = "%s section reset · Undo can restore it." % STEP_NAMES[editor_step]

func handle_input(event: InputEvent) -> bool:
	if game.mode not in ["spellforge", "grimoire"]: return false
	for field in _text_fields():
		if not is_instance_valid(field) or not field.visible: continue
		if event is InputEventKey and field.has_focus():
			if event.pressed and event.keycode == KEY_ESCAPE:
				if field.has_meta("number_key"): _cancel_number(field)
				else: _release_text_focus()
				h.get_viewport().set_input_as_handled()
			return true
	if event is InputEventKey and game.mode == "spellforge" and event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			_history(event.shift_pressed)
			return true
		if event.keycode == KEY_Y:
			_history(true)
			return true
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pointer: int = event.index if event is InputEventScreenTouch else -2

		if not event.pressed:
			_text_pointers.erase(pointer)
			if is_instance_valid(rehearsal) and rehearsal.has_method("handle_input"):
				rehearsal.handle_input(event)
			return false
		for field in _text_fields():
			if not is_instance_valid(field) or not field.visible or not field.editable: continue
			if Rect2(field.global_position, field.size * field.scale).has_point(event.position):
				_text_pointers[pointer] = true
				if event is InputEventScreenTouch: field.grab_focus()
				return true


		_release_text_focus()
	if event is InputEventScreenDrag and _text_pointers.has(event.index): return true
	if event is InputEventMouseMotion and _text_pointers.has(-2): return true
	if is_instance_valid(rehearsal) and game.mode == "spellforge" and rehearsal.has_method("handle_input"):
		return rehearsal.handle_input(event)
	return false

func action(rect: Rect2, value: String, tag: String, active := false, enabled := true, font_size := 17) -> void:
	var fill := Color("#36565a") if active else SLATE
	h.panel(rect, fill if enabled else Color(INK, 0.7), Color(CYAN if active else PAPER, 0.72 if active else 0.22), 3)
	h.centered(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - font_size * 0.54), value, font_size, PAPER if enabled else FAINT)
	if enabled and not tag.is_empty(): h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": tag, "mode": game.mode})

func label(pos: Vector2, value: String, size_value := 16, color := PAPER, serif := false) -> void:
	h.txt(pos, value, size_value, color, serif)

func _fit(value: String, width: float, size_value: int) -> String:
	var result := value
	while h.body_font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > width and result.length() > 1:
		result = result.left(result.length() - 2) + "…"
	return result

func _bounded_paragraph(pos: Vector2, value: String, width: float, size_value: int, max_lines: int, color := FAINT) -> void:
	var lines: Array[String] = []
	var current := ""
	for word in value.split(" "):
		var candidate := current + (" " if not current.is_empty() else "") + word
		if h.body_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else: current = candidate
	if not current.is_empty(): lines.append(current)
	for index in range(mini(max_lines, lines.size())):
		var line: String = lines[index]
		if index == max_lines - 1 and lines.size() > max_lines: line += "…"
		label(pos + Vector2(0, index * size_value * 1.48), _fit(line, width, size_value), size_value, color)

func sheet(title: String, eyebrow: String, close_tag: String, close_label := "×  Close") -> void:
	h.panel(Rect2(44, 32, 1192, 656), Color(INK, 0.99), Color(PAPER, 0.4), 2)
	h.draw_rect(Rect2(44, 32, 6, 656), VIOLET)
	label(Vector2(80, 49), eyebrow, 12, CYAN)
	label(Vector2(78, 69), title, 36, PAPER, true)
	action(Rect2(1072, 56, 128, 48), close_label, close_tag)

func draw(mode: String) -> void:
	tick()
	_visible_numbers.clear()
	if mode == "grimoire": draw_grimoire()
	elif mode == "spellforge":
		if not delete_pending.is_empty():
			draw_grimoire()
			draw_delete()
		else:
			if draft.is_empty() and not begin_edit():
				draw_grimoire()
				return
			draw_editor()
	for key in number_entries:
		var field: LineEdit = number_entries[key]
		if not _visible_numbers.has(key):
			if field.has_focus(): field.release_focus()
			field.hide()
	_order_number_focus()

func _order_number_focus() -> void:
	var fields: Array = []
	for field in _text_fields():
		if is_instance_valid(field) and field.visible and field.editable: fields.append(field)
	fields.sort_custom(func (a: LineEdit, b: LineEdit) -> bool:
		return a.position.x < b.position.x if is_equal_approx(a.position.y, b.position.y) else a.position.y < b.position.y)
	for index in range(fields.size()):
		fields[index].focus_next = fields[index].get_path_to(fields[(index + 1) % fields.size()])
		fields[index].focus_previous = fields[index].get_path_to(fields[posmod(index - 1, fields.size())])

func draw_grimoire() -> void:
	sheet("THE TRAVELER'S GRIMOIRE", "KEEP YOUR OWN CONSTELLATION", "magic:close")
	var spells := filtered_library()
	var spell := selected_spell()
	var per_page := 5
	page = clampi(page, 0, maxi(0, (spells.size() - 1) / per_page))
	label(Vector2(80, 121), "%d FOUND  /  %d OF %d INSCRIBED" % [spells.size(), library().size(), Spellbook.MAX_SPELLS], 12, FAINT)
	for index in range(3):
		var filter: String = ["all", "starter", "custom"][index]
		action(Rect2(80 + index * 116, 202, 108, 44), ["All", "Starters", "Your spells"][index], "magic:filter:" + filter, library_filter == filter, true, 14)
	for index in range(page * per_page, mini(spells.size(), page * per_page + per_page)):
		var entry: Dictionary = spells[index]
		var rect := Rect2(80, 254 + (index % per_page) * 60, 340, 54)
		action(rect, "", "magic:select:" + str(entry.id), str(entry.id) == selected_id)
		h.draw_rect(Rect2(rect.position + Vector2(5, 8), Vector2(4, 38)), Color(entry.color))
		label(rect.position + Vector2(18, 6), _fit(str(entry.name), 304, 17), 17)
		label(rect.position + Vector2(18, 31), "%s · %d mana · %d stage%s" % [str(entry.form).capitalize(), int(Spellbook.cost(entry)), Spellbook.stage_count(entry), "s" if Spellbook.stage_count(entry) != 1 else ""], 12, FAINT)
	if spells.is_empty(): h.paragraph(Vector2(92, 286), "No matching spells. Try another search or filter.", 316, 18, FAINT)
	var pages := maxi(1, ceili(float(spells.size()) / per_page))
	action(Rect2(80, 566, 56, 44), "‹", "magic:page:-1", false, page > 0)
	h.centered(Vector2(250, 579), "%02d / %02d" % [page + 1, pages], 15, FAINT)
	action(Rect2(364, 566, 56, 44), "›", "magic:page:1", false, page < pages - 1)
	if not spell.is_empty() and not spells.is_empty():
		draw_preview(Rect2(448, 151, 300, 288), spell)
		label(Vector2(772, 152), "SELECTED INSCRIPTION", 12, CYAN)
		label(Vector2(772, 176), _fit(str(spell.name), 428, 26), 26, PAPER)
		_bounded_paragraph(Vector2(772, 241), Spellbook.describe(spell), 428, 16, 4)
		label(Vector2(772, 351), "%d MANA   /   %.1f s RECAST" % [int(Spellbook.cost(spell)), Spellbook.cooldown(spell)], 20, GOLD)
		label(Vector2(772, 384), "Grimoire equipped · your active spell is ready." if str(game.state.equipment) == "grimoire" else "Equip the grimoire to cast assigned spells.", 14, CYAN if str(game.state.equipment) == "grimoire" else FAINT)
		label(Vector2(448, 458), "SPELL SLOTS  /  ASSIGN A SPELL · EQUIP THE BOOK AS YOUR WEAPON", 12, CYAN)
		var slots: Array = game.state.spell_slots
		for index in range(Spellbook.SLOT_COUNT):
			var rect := Rect2(448 + index * 190, 484, 182, 64)
			var equipped: Dictionary = game.state.spell_by_id(str(slots[index])) if index < slots.size() else {}
			action(rect, "", "magic:slot:" + str(index), index == int(game.state.active_spell_slot))
			label(rect.position + Vector2(12, 7), "SLOT %d%s" % [index + 1, " · ACTIVE" if index == int(game.state.active_spell_slot) else ""], 11, CYAN if index == int(game.state.active_spell_slot) else FAINT)
			label(rect.position + Vector2(12, 30), _fit(str(equipped.get("name", "Empty")), 158, 15), 15)
		var active_slot := clampi(int(game.state.active_spell_slot), 0, Spellbook.SLOT_COUNT - 1)
		action(Rect2(448, 562, 358, 48), "Assign to spell slot %d" % [active_slot + 1], "magic:equip:" + str(active_slot), true)
		var available := near_altar()
		action(Rect2(822, 562, 112, 48), "Remix", "magic:clone", false, available)
		action(Rect2(946, 562, 112, 48), "Edit", "magic:edit", false, available and not is_starter(selected_id))
		action(Rect2(1070, 562, 130, 48), "Delete", "magic:delete", false, available and not is_starter(selected_id))
	action(Rect2(80, 622, 164, 48), "+  New spell", "magic:new", near_altar())
	action(Rect2(256, 622, 164, 48), "Find tower", "magic:track")
	action(Rect2(448, 622, 226, 48), "Grimoire equipped" if str(game.state.equipment) == "grimoire" else "Equip grimoire", "magic:ready_grimoire", str(game.state.equipment) == "grimoire", game.has_method("ready_grimoire"))
	h.paragraph(Vector2(692, 629), status if not status.is_empty() else ("Altar in reach · create, remix and edit here." if near_altar() else "Create at the tower altar. Browse and assign spells anywhere."), 508, 14, CYAN if near_altar() else FAINT)

func draw_editor() -> void:
	sheet("THE ARCANE WORKSHOP", "WIZARD'S TOWER / UNSAVED SPELL", "magic:cancel", "×  Cancel")
	label(Vector2(80, 120), "SPELL NAME  /  TAP TO TYPE", 12, FAINT)
	action(Rect2(80, 202, 114, 44), "Guided", "magic:mode:guided", creator_mode == "guided", true, 15)
	action(Rect2(202, 202, 114, 44), "Advanced", "magic:mode:advanced", creator_mode == "advanced", true, 15)
	action(Rect2(332, 202, 96, 44), "↶  Undo", "magic:undo", false, not _undo.is_empty(), 15)
	action(Rect2(436, 202, 96, 44), "↷  Redo", "magic:redo", false, not _redo.is_empty(), 15)
	action(Rect2(540, 202, 274, 44), "Reset this section", "magic:reset_section", false, not _section_keys().is_empty(), 15)
	for index in range(STEP_NAMES.size()):
		action(Rect2(80 + index * 124, 254, 114, 44), STEP_NAMES[index], "magic:step:" + str(index), editor_step == index, true, 14)
	if creator_mode == "guided" and editor_step == 0: draw_guided()
	else:
		draw_stage_cards()
		match editor_step:
			0: draw_essence()
			1: draw_delivery()
			2: draw_weave()
			3: draw_appearance()
			4: draw_test()
			5: draw_inscribe()
	var preview_recipe := _safe_root()
	draw_preview(PREVIEW_RECT, preview_recipe)
	action(Rect2(842, 438, 174, 44), "↻  Replay", "magic:replay", false, is_instance_valid(rehearsal), 15)
	action(Rect2(1026, 438, 174, 44), "Reset practice", "magic:rehearsal_reset", false, is_instance_valid(rehearsal), 15)
	label(Vector2(842, 493), "%d MANA" % int(Spellbook.cost(preview_recipe)), 25, GOLD)
	label(Vector2(1044, 502), "%.1f s recast" % Spellbook.cooldown(preview_recipe), 16, CYAN)
	h.paragraph(Vector2(842, 536), compatibility_hint(), 358, 14, FAINT)
	action(Rect2(80, 622, 114, 48), "‹  Library", "magic:cancel", false, true, 15)
	label(Vector2(210, 637), _fit(status if not status.is_empty() else "Draft only · Inscribe commits at the altar.", 604, 13), 13, RED if status.begins_with("Value rejected") else FAINT)
	var valid := not Spellbook.sanitize(draft).is_empty()
	var overwrites: bool = not game.state.spell_by_id(str(draft.id)).is_empty()
	if editor_step == 5:
		action(Rect2(842, 622, 358, 48), "Inscribe changes" if overwrites else "Inscribe new spell", "magic:save", true, valid and near_altar() and (overwrites or library().size() < Spellbook.MAX_SPELLS))
	else: action(Rect2(842, 622, 358, 48), "Review & inscribe  ›", "magic:step:5", true)

func creator_templates() -> Array:

	var result: Array = []
	var templates := Spellbook.templates()
	for effect in ["levitate", "gravity_well", "push"]:
		for spell in _starters:
			if str(spell.get("effect", "elemental")) == effect: result.append(spell)
	for spell in templates:
		var found := false
		for existing in result:
			if existing.id == spell.id: found = true
		if not found: result.append(spell)
	return result

func draw_guided() -> void:
	var templates := creator_templates()
	var per_page := 6
	var pages := maxi(1, ceili(float(templates.size()) / per_page))
	template_page = clampi(template_page, 0, pages - 1)
	label(Vector2(80, 310), "START WITH A WORKING RECIPE · ALL SETTINGS STAY EDITABLE", 12, CYAN)
	for index in range(template_page * per_page, mini(templates.size(), (template_page + 1) * per_page)):
		var spell: Dictionary = templates[index]
		var local_index: int = index % per_page
		var rect := Rect2(80 + (local_index % 2) * 380, 336 + (local_index / 2) * 74, 354, 66)
		action(rect, "", "magic:template:" + str(index), str(draft.name) == str(spell.name))
		label(rect.position + Vector2(14, 8), _fit(str(spell.name), 326, 18), 18)
		label(rect.position + Vector2(14, 36), _fit("%s · %d stage%s · %d mana" % [FORM_NAMES.get(str(spell.form), str(spell.form)), Spellbook.stage_count(spell), "s" if Spellbook.stage_count(spell) != 1 else "", int(Spellbook.cost(spell))], 326, 13), 13, CYAN)
	action(Rect2(80, 568, 56, 44), "‹", "magic:templates:-1", false, template_page > 0)
	h.centered(Vector2(447, 580), "%d / %d · Choose a recipe, then open any step." % [template_page + 1, pages], 14, FAINT)
	action(Rect2(758, 568, 56, 44), "›", "magic:templates:1", false, template_page < pages - 1)

func draw_stage_cards() -> void:
	var stages := Spellbook.stage_list(_safe_root())
	for index in range(stages.size()):
		var spell: Dictionary = stages[index]
		var rect := Rect2(80 + index * 152, 310, 144, 52)
		action(rect, "", "magic:stage:" + str(index), selected_stage == index)
		var timing: String = "ON CAST" if index == 0 else {"hit": "ON FIRST HIT", "delay": "AFTER DELAY", "end": "WHEN IT ENDS"}.get(str(spell.when), "ON FIRST HIT")
		label(rect.position + Vector2(9, 5), "%d · %s" % [index + 1, timing], 11, CYAN if index == selected_stage else FAINT)
		label(rect.position + Vector2(9, 25), _fit("%s %s" % [str(spell.element).capitalize(), FORM_NAMES.get(str(spell.form), str(spell.form))], 126, 14), 14)
	action(Rect2(688, 310, 58, 52), "+", "magic:stage_add", false, stages.size() < 4, 24)
	action(Rect2(756, 310, 58, 52), "−", "magic:stage_remove", false, selected_stage > 0, 24)

func _subsections(names: Array) -> void:
	section = clampi(section, 0, names.size() - 1)
	var width := (734.0 - float(names.size() - 1) * 8.0) / float(names.size())
	for index in range(names.size()):
		action(Rect2(80 + index * (width + 8), 372, width, 44), str(names[index]), "magic:section:" + str(index), section == index, true, 14)

func _cell(column: int, row: int) -> Rect2:
	return Rect2(80 + column * 380, 426 + row * 65, 354, 61)

func numeric(rect: Rect2, key: String, title: String, suffix := "", enabled := true) -> void:
	label(rect.position, _fit(title, rect.size.x, 11), 11, FAINT)
	var limits := _numeric_limits(key)
	_draw_number_entry(rect, key, title, limits, suffix, enabled)

func _draw_number_entry(rect: Rect2, key: String, title: String, limits: Array, suffix := "", enabled := true) -> void:
	var field: LineEdit = number_entries[key]
	var desired_width := 88.0 if rect.size.x < 220.0 else 146.0
	var minimum := field.get_combined_minimum_size()
	var width := maxf(desired_width, minimum.x)
	var field_rect := Rect2(rect.position + Vector2(0, 17) + h.drawing_offset, Vector2(width, maxf(44.0, minimum.y)))
	field.set_meta("number_rect", field_rect)
	field.set_meta("number_context", {"id": str(draft.get("id", "")), "stage": selected_stage, "color": color_target, "title": title, "limits": limits.duplicate()})
	field.editable = enabled
	field.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	field.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	field.modulate = Color.WHITE if enabled else Color(FAINT, 0.55)
	if not field.has_focus(): field.text = _number_text(key)
	var ratio: Vector2 = h.get_viewport_rect().size / Vector2(1280, 720)
	if ratio.x <= 0 or ratio.y <= 0: ratio = Vector2.ONE
	field.position = field_rect.position * ratio
	field.size = field_rect.size
	field.scale = ratio
	field.show()
	_visible_numbers[key] = true
	var hint := "%s–%s%s" % [_format_number(float(limits[0])), _format_number(float(limits[1])), suffix]
	var hint_pos := rect.position + Vector2(width + 12, 21)
	label(hint_pos, _fit(hint, rect.size.x - width - 12, 12), 12, FAINT)
	label(hint_pos + Vector2(0, 20), "Tap to type" if enabled else "Not used", 10, CYAN if enabled else FAINT)
	field.accessibility_name = title.capitalize()
	field.accessibility_description = "Allowed %s. %s. Enter or tap away applies to the draft. Escape cancels." % [hint, "Whole numbers" if _whole_number(key) else "Decimal numbers"]
	field.tooltip_text = field.accessibility_name + ": " + field.accessibility_description

func choice(rect: Rect2, key: String, title: String, values: Array, enabled := true) -> void:
	var recipe := _recipe()
	label(rect.position, _fit(title, rect.size.x, 11), 11, FAINT)
	var y: float = rect.position.y + 17
	var value := str(recipe.get(key, ""))
	var title_value := value.replace("_", " ").capitalize()
	if key == "when": title_value = {"hit": "On first hit", "delay": "After a delay", "end": "When it ends"}.get(value, title_value)
	if key == "trigger": title_value = {"impact": "On contact", "delay": "After contact delay", "pulse": "Pulse after contact"}.get(value, title_value)
	if key == "when" and selected_stage == 0: title_value = "On cast"
	if key == "condition" and selected_stage == 0: title_value = "Always · first stage"
	if key == "targeting" and not _composition(): title_value = "Caster" if str(recipe.form) in ["ward", "mend", "step"] else "Delivery behavior"
	h.centered(Vector2(rect.get_center().x, y + 10), _fit(title_value, rect.size.x - 108, 17), 17, PAPER if enabled else FAINT)
	action(Rect2(rect.position.x, y, 48, 44), "‹", "magic:cycle:" + key + ":-1", false, enabled and not values.is_empty())
	action(Rect2(rect.end.x - 48, y, 48, 44), "›", "magic:cycle:" + key + ":1", false, enabled and not values.is_empty())

func _enum(rect: Rect2, key: String, title: String) -> void:
	choice(rect, key, title, _values_for(key), setting_enabled(key))

func _values_for(key: String) -> Array:
	var values: Array = Spellbook.ENUMS.get(key, []).duplicate()
	var form := str(_recipe().get("form", ""))
	if key == "targeting" and form not in ["burst", "field"]:
		values.erase("caster")
		values.erase("projectiles")
	if key in ["effect", "secondary_effect", "tertiary_effect"]:
		if form not in ["burst", "field"]: values.erase("shield")
		if form == "summon": values.erase("enchant")
	return values

func _number(rect: Rect2, key: String, title: String, suffix := "") -> void:
	numeric(rect, key, title, suffix, setting_enabled(key))

func _numeric_limits(key: String) -> Array:
	var limits: Array = Spellbook.LIMITS.get(key, [0.0, 0.0]).duplicate()
	if key == "range":
		var form := str(_recipe().get("form", ""))
		if form == "cone": limits[1] = 16.0
		elif form == "summon": limits[1] = 8.0
	return limits


func stage_effect_summary() -> String:
	var s := _recipe()
	if s.is_empty(): return "Choose a stage to see its effect."
	match str(s.form):
		"ward": return "Protection stage · absorbs damage; it does not strike enemies."
		"mend": return "Healing stage · heals the caster."
		"step": return "Movement stage · moves the caster and stops at cover."
		"wall": return "Cover stage · creates a solid temporary wall."
		"summon": return "Summoning stage · your guardian attacks eligible enemies."
	if "elemental" not in [s.effect, s.secondary_effect, s.tertiary_effect]:
		return "Utility stage · no direct damage. Add Elemental in Weave to damage enemies."
	if str(s.targeting) not in ["enemies", "both"]:
		return "Current targets · no enemy damage. Choose Enemies or Both for elemental damage."
	return "Elemental damage · %d per hit. Appearance colors do not change damage." % Spellbook.damage(s)

func draw_essence() -> void:
	section = 0
	label(Vector2(80, 382), "CHOOSE WHAT THIS STAGE DOES", 13, CYAN)
	_enum(_cell(0, 0), "element", "ELEMENT · GAMEPLAY FAMILY" if _composition() else "ELEMENT · VISUAL FAMILY FOR THIS DELIVERY")
	_number(_cell(1, 0), "power", "EFFECT POWER")
	_enum(_cell(0, 1), "targeting", "TARGET GROUP")
	var s := _recipe()
	var note: String = {"flame": "Flame burns; wet targets produce steam.", "frost": "Frost freezes; wet targets freeze longer.", "storm": "Storm conducts between nearby wet targets.", "grove": "Grove returns a little health to the caster.", "light": "Light strikes and repels affected enemies.", "shadow": "Shadow delays enemy attacks.", "water": "Water applies wet for later reactions.", "wind": "Wind pushes affected enemies.", "earth": "Earth deals a heavy elemental strike.", "metal": "Metal deals a focused elemental strike.", "void": "Void draws affected enemies inward.", "time": "Time slows affected enemies for a finite duration."}.get(str(s.get("element", "")), "")
	if str(s.get("form", "")) == "ward": note = "Ward absorbs %d damage for %.1f s. Element changes its look." % [int(s.power) + 1, 3.0 + float(s.power) * 0.8]
	elif str(s.get("form", "")) == "mend": note = "Mend restores %d hearts to the caster. Element changes its look." % maxi(1, ceili(float(s.power) * 0.6))
	elif str(s.get("form", "")) == "step": note = "Step moves the caster up to %.1f m and stops at cover." % float(s.radius)
	elif str(s.get("form", "")) == "wall": note = "Wall creates finite solid cover. Shape and lifetime are in Delivery → Special."
	if _composition() and "elemental" not in [s.effect, s.secondary_effect, s.tertiary_effect]:
		note = "This stage changes movement, status or properties. Its element controls appearance."
	elif _composition() and str(s.targeting) not in ["enemies", "both"]:
		note = "The target filter controls who receives damage. Choose Enemies or Both for offensive magic."
	h.paragraph(Vector2(460, 499), note, 354, 15, PAPER)
	h.paragraph(Vector2(80, 566), stage_effect_summary(), 734, 14, CYAN)

func draw_delivery() -> void:
	_subsections(["Delivery", "Flight", "Contacts", "Special"])
	match section:
		0:
			_enum(_cell(0, 0), "form", "DELIVERY")
			_enum(_cell(1, 0), "projectile", "PROJECTILE SILHOUETTE")
			_enum(_cell(0, 1), "trajectory", "FLIGHT PATH")
			_enum(_cell(1, 1), "impact", "CONTACT BEHAVIOR")
			_number(_cell(0, 2), "range", "AIM RANGE", " m")
			_number(_cell(1, 2), "radius", "AREA RADIUS / STEP DISTANCE", " m")
		1: draw_flight()
		2:
			_number(_cell(0, 0), "pierces", "PIERCE CONTACTS")
			_number(_cell(1, 0), "bounces", "BOUNCES")
			_number(_cell(0, 1), "chains", "CHAIN TARGETS")
			_number(_cell(1, 1), "stagger", "TIME BETWEEN LAUNCHES", " s")
			_number(_cell(0, 2), "homing", "SEEKING STRENGTH")
			_number(_cell(1, 2), "return_time", "START RETURNING AFTER", " s")
		3: draw_special_delivery()

func draw_flight() -> void:
	var s := _recipe()
	_number(_cell(0, 0), "count", "INITIAL PROJECTILE COUNT")
	_number(_cell(1, 0), "power", "EFFECT POWER")
	_number(_cell(0, 1), "speed", "PROJECTILE SPEED", " m/s")
	_number(_cell(1, 1), "spread", "PROJECTILE SPREAD", "°")
	if str(s.get("form", "")) in ["volley", "rain", "orbitals"]:
		_number(_cell(0, 2), "size", "PROJECTILE SIZE / BEAM WIDTH", " m")
		_number(_cell(1, 2), "lifetime", "PROJECTILE LIFETIME", " s")
	elif str(s.get("form", "")) in ["beam", "touch"]:
		_number(_cell(0, 2), "size", "CONTACT SWEEP WIDTH", " m")
		_number(_cell(1, 2), "radius", "STORM CONDUCTION / STATUS RADIUS", " m")
	else:
		_number(_cell(0, 2), "radius", "AREA RADIUS / STEP DISTANCE", " m")
		_number(_cell(1, 2), "duration", "FINITE EFFECT DURATION", " s")

func draw_special_delivery() -> void:
	var s := _recipe()
	match str(s.get("form", "")):
		"wall":
			_number(_cell(0, 0), "wall_width", "WALL WIDTH", " m")
			_number(_cell(1, 0), "wall_height", "WALL HEIGHT", " m")
			_number(_cell(0, 1), "wall_thickness", "WALL THICKNESS", " m")
			_number(_cell(1, 1), "duration", "WALL LIFETIME", " s")
			h.paragraph(Vector2(80, 565), "Solid cover blocks placement. Two constructs per caster; each expires after its lifetime.", 734, 14, FAINT)
		"summon":
			_enum(_cell(0, 0), "summon_kind", "GUARDIAN SHAPE")
			_number(_cell(1, 0), "summon_count", "GUARDIANS · TWO PER CASTER")
			_number(_cell(0, 1), "duration", "GUARDIAN LIFETIME", " s")
			h.paragraph(Vector2(460, 500), "Guardians need visible targets and expire without loot or quest progress.", 354, 14, FAINT)
		_:
			_number(_cell(0, 0), "orbit_radius", "ORBIT / SPIRAL RADIUS", " m")
			_number(_cell(1, 0), "hold_time", "ORBITALS · HOLD BEFORE RELEASE", " s")
			_number(_cell(0, 1), "cone_angle", "CONE OPENING", "°")
			_number(_cell(1, 1), "rain_height", "RAIN RELEASE HEIGHT", " m")
			_number(_cell(0, 2), "duration", "FINITE EFFECT DURATION", " s")
			_number(_cell(1, 2), "radius", "AREA RADIUS", " m")

func draw_weave() -> void:
	_subsections(["Effects + condition", "Sequence + timing", "Forces + time"])
	match section:
		0:
			_enum(_cell(0, 0), "effect", "FIRST EFFECT LAYER")
			_enum(_cell(1, 0), "secondary_effect", "SECOND EFFECT LAYER")
			_enum(_cell(0, 1), "tertiary_effect", "THIRD EFFECT LAYER")
			_enum(_cell(1, 1), "targeting", "TARGET GROUP")
			_enum(_cell(0, 2), "condition", "SUCCESSOR REQUIRES · FALSE ENDS CHAIN")
			_number(_cell(1, 2), "repeat_contacts", "SUCCESSOR CONTACTS · MAXIMUM FOUR")
		1:
			_enum(_cell(0, 0), "when", "SUCCESSOR STARTS AFTER PREVIOUS")
			_number(_cell(1, 0), "stage_delay", "SUCCESSOR DELAY", " s")
			_enum(_cell(0, 1), "trigger", "EFFECT LAYERS AFTER CONTACT")
			_number(_cell(1, 1), "delay", "LAYER DELAY", " s")
			_number(_cell(0, 2), "pulses", "LAYER PULSE COUNT")
			_number(_cell(1, 2), "interval", "TIME BETWEEN LAYER PULSES", " s")
		2:
			_number(_cell(0, 0), "force", "DISPLACEMENT FORCE")
			_number(_cell(1, 0), "mass_limit", "MAXIMUM OBJECT MASS", " kg")
			_number(_cell(0, 1), "duration", "FORCE / STATUS DURATION", " s")
			_number(_cell(1, 1), "range", "SELECTION RANGE", " m")
			_number(_cell(0, 2), "slow_factor", "TIME RATE · LOWER IS SLOWER", "×")
			_number(_cell(1, 2), "orbit_radius", "OBJECT ORBIT RADIUS", " m")

func draw_appearance() -> void:
	_subsections(["Colors", "Particles", "Motion", "Style", "Scale"])
	var s := _recipe()
	match section:
		0:
			for index in range(COLOR_KEYS.size()):
				var key: String = COLOR_KEYS[index]
				var rect := Rect2(80 + index * 148, 426, 142, 44)
				action(rect, ["Body", "Core", "Rim", "Trail", "Accent"][index], "magic:color:" + key, color_target == key, true, 14)
				h.draw_rect(Rect2(rect.position + Vector2(5, 8), Vector2(3, 28)), Color(str(s.get(key, "#ffffff"))))
			for index in range(PALETTE.size()):
				var rect := Rect2(80 + index * 93, 478, 83, 44)
				action(rect, "", "magic:palette:" + str(index), str(s.get(color_target, "")) == PALETTE[index])
				h.draw_rect(rect.grow(-8), Color(PALETTE[index]))
			for index in range(3):
				var channel: String = ["r", "g", "b"][index]
				var rect := Rect2(80 + index * 186, 536, 176, 61)
				var title: String = ["RED", "GREEN", "BLUE"][index]
				label(rect.position, title, 11, FAINT)
				_draw_number_entry(rect, "rgb_" + channel, title, [0.0, 255.0])
			numeric(Rect2(638, 536, 176, 61), "intensity", "PARTICLE INTENSITY")
		1:
			_enum(_cell(0, 0), "particles", "PARTICLE MOTIF")
			_number(_cell(1, 0), "particle_density", "PARTICLE DENSITY")
			_number(_cell(0, 1), "particle_size", "PARTICLE SIZE")
			_number(_cell(1, 1), "intensity", "PARTICLE INTENSITY")
			_number(_cell(0, 2), "glow", "BRIGHTNESS")
			_number(_cell(1, 2), "opacity", "OPACITY")
		2:
			_enum(_cell(0, 0), "trail", "TRAIL STYLE")
			_number(_cell(1, 0), "spin", "VISUAL SPIN")
			_number(_cell(0, 1), "trail_width", "TRAIL WIDTH")
			_number(_cell(1, 1), "pulse_speed", "VISUAL PULSE SPEED")
			_number(_cell(0, 2), "trail_length", "TRAIL LENGTH", " s")
			_number(_cell(1, 2), "trail_fade", "TRAIL TAPER")
		3:
			_enum(_cell(0, 0), "material_style", "MATERIAL STYLE · COSMETIC")
			_enum(_cell(1, 0), "sigil", "SIGIL SHAPE")
			_enum(_cell(0, 1), "impact_accent", "CONTACT ACCENT")
			_number(_cell(1, 1), "edge_noise", "EDGE IRREGULARITY")
			_number(_cell(0, 2), "particle_drift", "PARTICLE DRIFT")
			h.paragraph(Vector2(460, 568), "Astral, crystal and other looks keep the chosen gameplay element.", 354, 14, FAINT)
		4:
			_number(_cell(0, 0), "cast_scale", "CAST SIGIL SCALE")
			_number(_cell(1, 0), "impact_scale", "CONTACT VISUAL SCALE")
			_number(_cell(0, 1), "residual_motes", "RESIDUAL MOTES")
			h.paragraph(Vector2(460, 504), "Visual scale does not enlarge the damage radius. Change Delivery for gameplay reach.", 354, 15, FAINT)

func draw_test() -> void:
	label(Vector2(80, 382), "PRIVATE PRACTICE SPACE", 13, CYAN)
	action(Rect2(574, 372, 240, 44), "Cover: on" if rehearsal_cover else "Cover: off", "magic:test_cover", rehearsal_cover, is_instance_valid(rehearsal), 15)
	label(Vector2(80, 430), "TARGETS", 12, FAINT)
	for index in range(3):
		var kind: String = ["enemy", "objects", "both"][index]
		action(Rect2(80 + index * 248, 450, 238, 44), ["Training enemy", "Loose objects", "Both"][index], "magic:test_target:" + kind, rehearsal_target == kind, is_instance_valid(rehearsal), 15)
	label(Vector2(80, 506), "STARTING TARGET STATUS · REPLAY APPLIES YOUR CHOICE", 12, FAINT)
	for index in range(4):
		var target_status: String = ["none", "wet", "burning", "frozen"][index]
		action(Rect2(80 + index * 186, 526, 176, 44), target_status.capitalize(), "magic:test_status:" + target_status, rehearsal_status == target_status, is_instance_valid(rehearsal), 15)
	var reason := _rehearsal_reason()
	h.paragraph(Vector2(80, 586), reason if not reason.is_empty() else "Drag inside the practice view to look. Replay casts the whole chain; Reset clears practice actors.", 734, 13, RED if not reason.is_empty() else FAINT)

func draw_inscribe() -> void:
	label(Vector2(80, 382), "REVIEW THE COMPLETE ORDERED RECIPE", 13, CYAN)
	var stages := Spellbook.stage_list(_safe_root())
	for index in range(stages.size()):
		var s: Dictionary = stages[index]
		var timing: String = "On cast" if index == 0 else {"hit": "On first hit", "delay": "After %.1f s" % float(s.stage_delay), "end": "When previous ends"}.get(str(s.when), "On first hit")
		var layers := str(s.effect).replace("_", " ")
		for key in ["secondary_effect", "tertiary_effect"]:
			if str(s[key]) != "none": layers += " + " + str(s[key]).replace("_", " ")
		label(Vector2(80, 426 + index * 40), _fit("%d. %s → %s %s" % [index + 1, timing, str(s.element).capitalize(), str(s.form).capitalize()], 734, 15), 15)
		var detail := layers + " · " + str(s.targeting).capitalize()
		if index > 0 and str(s.condition) != "always": detail += " · requires %s, otherwise chain ends" % str(s.condition)
		if index > 0 and str(s.when) == "hit" and int(s.repeat_contacts) > 1: detail += " · up to %d contacts" % int(s.repeat_contacts)
		label(Vector2(80, 446 + index * 40), _fit(detail, 734, 11), 11, FAINT)
	var overwrite: bool = not game.state.spell_by_id(str(draft.id)).is_empty()
	var full := not overwrite and library().size() >= Spellbook.MAX_SPELLS
	var note := "Library full · free a custom slot before inscription. Your draft stays here." if full else (("Inscription replaces this saved recipe and keeps its quick slots." if overwrite else "Inscription adds this recipe to your library.") + (" Altar in reach." if near_altar() else " Return to the altar to inscribe."))
	h.paragraph(Vector2(80, 592), note, 734, 13, CYAN if near_altar() and not full else RED)

func _composition() -> bool:
	return str(_recipe().get("form", "")) not in ["ward", "mend", "step", "wall"]

func _has_layer(effects: Array) -> bool:
	if not _composition(): return false
	var s := _recipe()
	for key in ["effect", "secondary_effect", "tertiary_effect"]:
		if str(s.get(key, "none")) in effects: return true
	return false

func _physics() -> bool:
	return _has_layer(["levitate", "push", "pull", "suspend", "orbit", "gravity_well", "repel", "launch"])

func setting_enabled(key: String) -> bool:
	if draft.is_empty(): return false
	var s := _recipe()
	if s.is_empty(): return false
	var form := str(s.form)
	var path := str(s.trajectory)
	match key:
		"when", "condition": return selected_stage > 0
		"stage_delay": return selected_stage > 0 and str(s.when) == "delay"
		"repeat_contacts": return selected_stage > 0 and str(s.when) == "hit"
		"projectile", "count", "speed", "lifetime": return form in ["volley", "rain", "orbitals"]
		"trajectory": return form in ["volley", "orbitals"]
		"impact": return form in ["volley", "rain", "orbitals"]
		"spread": return (form == "volley" and path in ["fan", "helix", "seeking", "wave"]) or form == "orbitals"
		"stagger": return form in ["volley", "rain", "orbitals"] and int(s.count) > 1
		"homing": return form in ["volley", "orbitals"] and path == "seeking"
		"return_time": return form in ["volley", "orbitals"] and path == "returning"
		"orbit_radius": return form == "orbitals" or (form == "volley" and path == "spiral") or _has_layer(["orbit"])
		"hold_time": return form == "orbitals"
		"size": return form in ["volley", "beam", "touch", "rain", "orbitals"]
		"effect", "secondary_effect", "tertiary_effect", "trigger": return _composition()
		"targeting": return _composition() and form != "summon"
		"delay": return _composition() and str(s.trigger) == "delay"
		"pulses", "interval": return _composition() and str(s.trigger) == "pulse"
		"force": return _physics() or (str(s.element) == "void" and _has_layer(["elemental"]))
		"mass_limit": return str(s.targeting) in ["objects", "both"] and _has_layer(["levitate", "push", "pull", "suspend", "orbit", "gravity_well", "repel", "launch", "slow", "stasis", "enchant"])
		"slow_factor": return _has_layer(["slow"]) or (str(s.element) == "time" and _has_layer(["elemental"]))
		"range": return form in ["volley", "beam", "burst", "field", "cone", "rain", "trap", "wall", "summon"] or _has_layer(["levitate"])
		"duration": return _has_layer(["levitate", "suspend", "orbit", "gravity_well", "slow", "stasis", "projectile_stasis", "shield", "enchant"]) or form in ["field", "trap", "wall", "summon"] or (str(s.element) in ["water", "time", "void"] and _has_layer(["elemental"]))
		"pierces": return form in ["volley", "rain", "orbitals"] and str(s.impact) == "pierce"
		"bounces": return form in ["volley", "rain", "orbitals"] and str(s.impact) == "bounce"
		"chains": return form in ["volley", "rain", "orbitals"] and str(s.impact) == "chain"
		"radius": return form in ["burst", "field", "step", "rain", "trap"] or _has_layer(["projectile_stasis"]) or (str(s.element) == "storm" and _has_layer(["elemental"]))
		"element": return _has_layer(["elemental"]) or form in ["ward", "mend", "step", "wall", "summon"]
		"trail_width", "trail_length", "trail_fade", "trail_color": return str(s.trail) != "none"
		"cone_angle": return form == "cone"
		"rain_height": return form == "rain"
		"wall_width", "wall_height", "wall_thickness": return form == "wall"
		"summon_kind", "summon_count": return form == "summon"
	return true

func compatibility_hint() -> String:
	if draft.is_empty(): return ""
	if creator_mode == "guided" and editor_step == 0: return "Working templates use the same bounded gameplay as your saved spells. Open Advanced to edit each stage."
	var s := _recipe()
	if editor_step == 3: return "Appearance changes light, color and motion. Damage, contact radius, timing and physics keep their gameplay values."
	if editor_step == 4:
		var reason := _rehearsal_reason()
		return reason if not reason.is_empty() else "Practice uses separate actors and resources. Real health, mana, quests and your saved library stay untouched."
	if editor_step == 5: return "Only Inscribe saves this draft. Cancel returns to the library without changing a saved recipe."
	if _has_layer(["shield"]) and (str(s.form) not in ["burst", "field"] or str(s.targeting) != "caster"): return "Shield protects the caster through Burst or Field with Caster targets. Put damage and self-protection in separate stages."
	if _has_layer(["heal"]) and str(s.targeting) == "objects": return "Heal works on the caster or enemies with health. Throwable objects cannot be healed; choose Enemies or Both targets."
	if str(s.targeting) == "caster" and _has_layer(["elemental"]): return "Elemental damage does not harm the caster. Add Heal or Shield here; use a separate stage for enemy damage."
	if selected_stage > 0 and editor_step == 2:
		var note := "Stage %d follows stage %d. " % [selected_stage + 1, selected_stage]
		if str(s.condition) != "always": note += "If the target is not %s, this chain ends. " % str(s.condition)
		if str(s.when) == "hit": note += "It listens for up to %d valid contact%s." % [int(s.repeat_contacts), "s" if int(s.repeat_contacts) > 1 else ""]
		elif str(s.when) == "delay": note += "It begins %.1f s after the previous release." % float(s.stage_delay)
		else: note += "It waits for the previous stage to finish."
		return note
	if editor_step == 2:
		if not _composition(): return "This delivery has its own behavior. Choose Volley, Beam, Burst, Touch, Field or another contact delivery for effect layers."
		if section == 1: return "The first stage starts on cast. Layer Delay and Pulse happen after contact; successor timing is a separate setting."
		if section == 2: return "Forces keep real collisions and object mass. Time effects alter selected targets for a finite duration."
		return "The first stage always starts on cast. Add a successor for conditions and bounded repeat contacts. Up to three effect layers share each stage."
	if editor_step == 1:
		if str(s.form) == "summon": return "Guardians attack visible enemies with these effect layers. Their target group is fixed; placement reaches up to 8 m. Two guardians per caster."
		if str(s.form) == "cone": return "Cone reaches up to 16 m. Special changes its opening angle. Solid cover blocks selection; flight controls belong to projectiles."
		if str(s.form) == "touch": return "Touch reaches 2 m. Muted flight and range settings do not affect this delivery."
		if str(s.form) in ["ward", "mend", "step"]: return "Ward, Mend and Step act on the caster. Muted projectile and effect-layer settings do not affect them."
		return "Muted settings belong to other deliveries or paths. Special holds shape, guardian and temporary construct controls. Solid cover blocks magic."
	return "Choose a gameplay element and power, then Delivery and Weave. Wet, frozen and burning targets can enable later stage conditions."

func _rehearsal_reason() -> String:
	if not is_instance_valid(rehearsal) or not rehearsal.has_method("stats"): return ""
	var data: Dictionary = rehearsal.stats()
	return str(data.get("admission_reason", ""))

func _ensure_rehearsal() -> bool:
	if is_instance_valid(rehearsal): return true

	if not game is Node3D or not ResourceLoader.exists("res://scripts/spell_rehearsal.gd"): return false
	var script: Script = load("res://scripts/spell_rehearsal.gd")
	if script == null or not script.can_instantiate(): return false
	rehearsal = script.new()
	if not rehearsal is Node:
		rehearsal = null
		return false
	h.add_child(rehearsal)
	rehearsal.setup(h)
	if _manual_rehearsal_target and rehearsal.has_method("set_target_kind"): rehearsal.set_target_kind(rehearsal_target)
	if rehearsal.has_method("set_target_status"): rehearsal.set_target_status(rehearsal_status)
	if rehearsal.has_method("set_cover"): rehearsal.set_cover(rehearsal_cover)
	_preview_signature = 0
	return true

func _close_rehearsal() -> void:
	if is_instance_valid(rehearsal) and rehearsal.has_method("close"): rehearsal.close()
	_preview_signature = 0
	_preview_rect = Rect2()
	_preview_viewport_size = Vector2.ZERO

func draw_preview(rect: Rect2, spell: Dictionary) -> void:
	h.panel(rect, Color("#1b2330"), Color(VIOLET, 0.38), 4)
	if game.mode == "spellforge" and not draft.is_empty() and _ensure_rehearsal():
		var signature := hash(spell)
		if signature != _preview_signature or rect != _preview_rect or h.get_viewport_rect().size != _preview_viewport_size:
			rehearsal.show_spell(spell.duplicate(true), rect)
			if rehearsal.has_method("stats"):
				var data: Dictionary = rehearsal.stats()
				rehearsal_target = str(data.get("target", rehearsal_target))
			_preview_signature = signature
			_preview_rect = rect
			_preview_viewport_size = h.get_viewport_rect().size
		return
	label(rect.position + Vector2(20, 20), "SPELL NOTES" if game.mode == "grimoire" else "PRACTICE PREVIEW", 12, CYAN)
	label(rect.position + Vector2(20, 58), _fit(str(spell.get("name", "Unnamed spell")), rect.size.x - 40, 22), 22, PAPER, true)
	label(rect.position + Vector2(20, 102), "%s · %s" % [str(spell.get("element", "")).capitalize(), str(spell.get("form", "")).capitalize()], 17, GOLD)
	label(rect.position + Vector2(20, 139), "%d ordered stage%s" % [Spellbook.stage_count(spell), "s" if Spellbook.stage_count(spell) != 1 else ""], 16, PAPER)
	h.paragraph(rect.position + Vector2(20, 189), "Remix at the altar to rehearse this recipe." if game.mode == "grimoire" else "The real 3D rehearsal opens when the game world is ready.", rect.size.x - 40, 14, FAINT)

func draw_delete() -> void:
	h.buttons.clear()
	h.draw_rect(Rect2(44, 32, 1192, 656), Color(INK, 0.86))
	h.panel(Rect2(350, 212, 580, 290), INK, Color(RED, 0.7), 3)
	label(Vector2(384, 239), "REMOVE THIS CUSTOM SPELL?", 25, PAPER, true)
	var spell: Dictionary = game.state.spell_by_id(delete_pending)
	h.paragraph(Vector2(384, 284), str(spell.get("name", "Your spell")) + " will leave your library. Its quick slots will use another spell.", 512, 18, FAINT)
	action(Rect2(384, 416, 246, 52), "Keep spell", "magic:delete_cancel", true)
	action(Rect2(646, 416, 250, 52), "Delete spell", "magic:delete_confirm")

func _set_step(index: int) -> void:
	if index < 0 or index >= STEP_NAMES.size(): return
	editor_step = index
	section = 0
	if index != 0: creator_mode = "advanced"

func _legacy_tab(index: int) -> void:
	if index < 0 or index > 5: return
	tab = index
	creator_mode = "advanced"
	editor_step = [1, 1, 3, 2, 2, 2][index]
	section = [0, 1, 0, 0, 1, 2][index]

func dispatch(tag: String) -> bool:
	if not tag.begins_with("magic:"): return false
	var pieces := tag.split(":")
	if pieces.size() < 2: return true
	var command: String = pieces[1]
	var accepted := _release_text_focus()
	if command == "save" and not accepted: return true
	match command:
		"close":
			cancel_draft()
			game.set_mode("play")
		"cancel", "delete_cancel":
			cancel_draft()
			game.set_mode("grimoire")
		"select":
			if pieces.size() >= 3 and not game.state.spell_by_id(pieces[2]).is_empty():
				selected_id = pieces[2]
				status = ""
		"page":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): page = maxi(0, page + int(pieces[2]))
		"filter":
			if pieces.size() >= 3 and pieces[2] in ["all", "starter", "custom"]:
				library_filter = pieces[2]
				_search_changed(search_entry.text)
		"slot":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): game.select_spell_slot(int(pieces[2]))
		"equip":
			if pieces.size() >= 3 and not selected_spell().is_empty() and game.equip_custom_spell(selected_id, int(pieces[2])): status = "Assigned %s to spell slot %d." % [str(selected_spell().name), int(pieces[2]) + 1]
		"ready_grimoire":
			if game.has_method("ready_grimoire") and game.ready_grimoire(): status = "Grimoire equipped · your active spell is ready."
		"track": game.track_wizard_tower()
		"new", "clone", "edit":
			var id := "" if command == "new" else selected_id
			if not near_altar():
				status = "Find the wizard's tower to create or change spells."
				if game.has_method("toast"): game.toast(status)
			elif game.open_spellforge(): begin_edit(id, command == "clone")
		"step":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): _set_step(int(pieces[2]))
		"tab":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): _legacy_tab(int(pieces[2]))
		"mode":
			if pieces.size() >= 3 and pieces[2] in ["guided", "advanced"]:
				creator_mode = pieces[2]
				if creator_mode == "guided":
					editor_step = 0
					section = 0
		"section":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): section = clampi(int(pieces[2]), 0, 4)
		"stage":
			if pieces.size() >= 3 and pieces[2].is_valid_int():
				var index := int(pieces[2])
				if index >= 0 and index < Spellbook.stage_count(_safe_root()): selected_stage = index
		"stage_add":
			if game.mode == "spellforge" and not draft.is_empty():
				var candidate := Spellbook.add_stage(_safe_root())
				if not candidate.is_empty():
					candidate.name = draft.name
					if _commit(candidate, "Successor added · choose its timing and effects in Weave."):
						selected_stage = Spellbook.stage_count(_safe_root()) - 1
						creator_mode = "advanced"
		"stage_remove":
			if game.mode == "spellforge" and selected_stage > 0 and not draft.is_empty():
				var candidate := Spellbook.remove_stage(_safe_root(), selected_stage)
				if not candidate.is_empty():
					candidate.name = draft.name
					_commit(candidate, "Successor removed · Undo can restore it.")
		"undo": _history(false)
		"redo": _history(true)
		"reset_section": _reset_section()
		"templates":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): template_page = maxi(0, template_page + int(pieces[2]))
		"template":
			if pieces.size() >= 3 and pieces[2].is_valid_int() and not draft.is_empty() and game.mode == "spellforge":
				var templates := creator_templates()
				var index := int(pieces[2])
				if index >= 0 and index < templates.size(): _load_template(templates[index])
		"replay":
			if game.mode == "spellforge" and is_instance_valid(rehearsal): rehearsal.replay(_safe_root())
		"rehearsal_reset":
			if game.mode == "spellforge" and is_instance_valid(rehearsal): rehearsal.reset()
		"test_target":
			if pieces.size() >= 3 and pieces[2] in ["enemy", "objects", "both"]:
				_manual_rehearsal_target = true
				rehearsal_target = pieces[2]
				if is_instance_valid(rehearsal) and rehearsal.has_method("set_target_kind"): rehearsal.set_target_kind(rehearsal_target)
		"test_status":
			if pieces.size() >= 3 and pieces[2] in ["none", "wet", "burning", "frozen"]:
				rehearsal_status = pieces[2]
				if is_instance_valid(rehearsal) and rehearsal.has_method("set_target_status"): rehearsal.set_target_status(rehearsal_status)
		"test_cover":
			rehearsal_cover = not rehearsal_cover
			if is_instance_valid(rehearsal) and rehearsal.has_method("set_cover"): rehearsal.set_cover(rehearsal_cover)
		"save":
			if draft.is_empty() or game.mode != "spellforge": return true
			if not near_altar():
				status = "Return to the altar to inscribe. Your draft is still here."
				if game.has_method("toast"): game.toast(status)
			elif Spellbook.sanitize(draft).is_empty(): status = "Give your spell a valid name before inscription."
			elif library().size() >= Spellbook.MAX_SPELLS and game.state.spell_by_id(str(draft.id)).is_empty(): status = "Library full · free a custom slot before inscription. Your draft is still here."
			elif game.save_custom_spell(draft.duplicate(true)):
				selected_id = str(draft.id)
				cancel_draft()
				library_filter = "all"
				search_query = ""
				search_entry.text = ""
				page = maxi(0, _index_of(selected_id) / 5)
				game.set_mode("grimoire")
				status = "Spell inscribed · assign a slot and equip the grimoire."
			else: status = "Inscription was not accepted. Your draft is still here."
		"delete":
			if near_altar() and not selected_spell().is_empty() and not is_starter(selected_id) and game.open_spellforge():
				_close_rehearsal()
				delete_pending = selected_id
				draft.clear()
				_undo.clear()
				_redo.clear()
		"delete_confirm":
			if not delete_pending.is_empty() and near_altar() and game.delete_custom_spell(delete_pending):
				cancel_draft()
				selected_id = ""
				game.set_mode("grimoire")
				status = "Custom spell removed."
		"value", "adjust", "cycle", "color", "palette", "channel", "preset", "load_preset": _edit_command(command, pieces)
	tick()
	return true

func _index_of(id: String) -> int:
	var spells := library()
	for index in range(spells.size()):
		if str(spells[index].id) == id: return index
	return 0

func _edit_command(command: String, pieces: PackedStringArray) -> void:
	if draft.is_empty() or game.mode != "spellforge" or not delete_pending.is_empty(): return
	var s := _recipe()
	if s.is_empty(): return
	match command:
		"value":
			if pieces.size() >= 4:
				var key: String = pieces[2]
				var values := _values_for(key)
				if setting_enabled(key) and values.has(pieces[3]): _apply_changes(_target_changes(key, pieces[3]))
		"adjust":
			if pieces.size() >= 4 and pieces[3].is_valid_float() and Spellbook.LIMITS.has(pieces[2]) and setting_enabled(pieces[2]):
				var direction := float(pieces[3])
				if not is_finite(direction) or is_zero_approx(direction): return
				var key: String = pieces[2]
				var limits := _numeric_limits(key)
				var step := float(STEPS.get(key, 0.1))
				var current := clampf(float(s[key]), limits[0], limits[1])
				var value := clampf(current + step * signf(direction), limits[0], limits[1])
				if not is_equal_approx(value, float(limits[0])) and not is_equal_approx(value, float(limits[1])): value = clampf(snappedf(value, step), limits[0], limits[1])
				_apply_changes({key: int(roundf(value)) if key in Spellbook.INTEGER_FIELDS else value})
		"cycle":
			if pieces.size() >= 4 and pieces[3].is_valid_int():
				var key: String = pieces[2]
				if Spellbook.ENUMS.has(key) and setting_enabled(key):
					var values := _values_for(key)
					_apply_changes(_target_changes(key, values[posmod(values.find(str(s[key])) + int(pieces[3]), values.size())]))
		"color":
			if pieces.size() >= 3 and pieces[2] in COLOR_KEYS: color_target = pieces[2]
		"palette":
			if pieces.size() >= 3 and pieces[2].is_valid_int() and int(pieces[2]) >= 0 and int(pieces[2]) < PALETTE.size(): _apply_changes({color_target: PALETTE[int(pieces[2])]})
		"channel":
			if pieces.size() >= 4 and pieces[2] in ["r", "g", "b"] and pieces[3].is_valid_int():
				var color := Color(str(s[color_target]))
				var value := clampi(int(roundf(float(color[pieces[2]]) * 255.0)) + int(pieces[3]), 0, 255)
				color[pieces[2]] = float(value) / 255.0
				_apply_changes({color_target: "#" + color.to_html(false)})
		"preset":
			if pieces.size() >= 3 and pieces[2].is_valid_int(): preset_index = posmod(preset_index + int(pieces[2]), _starters.size())
		"load_preset": _load_template(_starters[preset_index])

func _target_changes(key: String, value: String) -> Dictionary:
	var changes := {key: value}
	if key == "form" and value == "summon": changes.targeting = "enemies"
	if key == "form" and value not in ["burst", "field"] and str(_recipe().get("targeting", "")) in ["caster", "projectiles"]: changes.targeting = "enemies"
	if key not in ["effect", "secondary_effect", "tertiary_effect"]: return changes
	var s := _recipe()
	s[key] = value
	var physical := false
	var elemental := false
	for layer in ["effect", "secondary_effect", "tertiary_effect"]:
		if str(s.get(layer, "none")) == "elemental": elemental = true
		elif str(s.get(layer, "none")) in ["levitate", "push", "pull", "suspend", "orbit", "gravity_well", "repel", "launch"]: physical = true


	if physical and elemental and str(s.targeting) == "objects": changes.targeting = "both"
	if value == "enchant": changes.targeting = "objects"
	elif value == "shield": changes.targeting = "caster"
	elif value == "heal" and str(s.targeting) == "objects": changes.targeting = "enemies"
	return changes

func _load_template(recipe: Dictionary) -> void:
	if draft.is_empty(): return
	var candidate := recipe.duplicate(true)
	candidate.id = draft.id
	if _commit(candidate, "Template loaded · every stage remains editable before inscription."):
		selected_stage = 0
		section = 0
