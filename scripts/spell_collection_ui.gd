extends RefCounted

const Book = preload("res://scripts/spellbook.gd")
const Collection = preload("res://scripts/spell_collection.gd")
const Art = preload("res://scripts/lantern_ledger_art.gd")
const PAPER := Art.PAPER
const INK := Art.INK
const SLATE := Color("#233e43")
const FAINT := Color("#bdc9bf")
const CYAN := Color("#91cdbb")
const GOLD := Color("#d9bd7b")
const VIOLET := Color("#b59bff")
const SEARCH_RECT := Rect2(60, 118, 590, 46)
const PAGE_SIZE := 5
var h
var game
var search_entry: LineEdit

var name_entry: LineEdit
var selected_id := "fireball"
var search_query := ""
var element_filter := "all"
var role_filter := "all"
var source_filter := "collection"
var page := 0
var status := "All %d curated spells are ready to equip." % Collection.all_spells().size()
var _text_pointers: Dictionary = {}

func setup(hud) -> void:
	h = hud; game = hud.game
	if is_instance_valid(search_entry): return
	search_entry = LineEdit.new()
	search_entry.name = "CollectionSearch"
	search_entry.placeholder_text = "Search names, deliveries or effects"
	search_entry.max_length = 64
	search_entry.clear_button_enabled = true
	search_entry.virtual_keyboard_enabled = true
	search_entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	search_entry.add_theme_font_override("font", Art.font())
	search_entry.add_theme_font_size_override("font_size", 19)
	search_entry.add_theme_color_override("font_color", Art.INK)
	search_entry.add_theme_color_override("font_placeholder_color", Art.MUTED)
	search_entry.add_theme_color_override("caret_color", Art.RED)
	var style := StyleBoxFlat.new()
	style.bg_color = Art.PAPER.lightened(0.08); style.border_color = Color(Art.BRASS, 0.65)
	style.set_border_width_all(1); style.content_margin_left = 14; style.content_margin_right = 12
	search_entry.add_theme_stylebox_override("normal", style)
	var focused: StyleBoxFlat = style.duplicate(); focused.border_color = Art.RED; focused.set_border_width_all(2)
	search_entry.add_theme_stylebox_override("focus", focused)
	search_entry.text_changed.connect(_search_changed)
	search_entry.text_submitted.connect(func (_value: String): cancel_draft())
	search_entry.hide(); h.add_child(search_entry)

func library() -> Array:
	return game.state.collection_spells() if game != null and game.state != null else []

func filtered_library() -> Array:
	var result: Array = []
	var query := search_query.strip_edges().to_lower()
	for spell in library():
		var note := Collection.metadata(str(spell.id))


		if query.is_empty():
			if source_filter == "collection" and note.is_empty(): continue
			if source_filter == "archive" and not note.is_empty(): continue
		if element_filter != "all" and spell.element != element_filter: continue
		if role_filter != "all" and Collection.role(spell) != role_filter: continue
		if not query.is_empty():
			var terms: Array = [spell.name, spell.element, spell.form, Collection.role(spell), note.get("summary", "")]
			for stage in Book.stage_list(spell): terms.append_array([stage.form, stage.effect, stage.secondary_effect, stage.tertiary_effect, stage.projectile, stage.trajectory])
			if not " ".join(terms).to_lower().contains(query): continue
		result.append(spell)
	return result

func selected_spell() -> Dictionary:
	var spell: Dictionary = game.state.spell_by_id(selected_id)
	if spell.is_empty():
		var choices := filtered_library()
		if not choices.is_empty(): selected_id = str(choices[0].id); spell = choices[0].duplicate(true)
	return spell

func _search_changed(value: String) -> void:
	search_query = value.left(64).strip_edges().to_lower(); page = 0
	_choose_first_visible()
	h.queue_redraw()

func _choose_first_visible() -> void:
	var choices := filtered_library()
	for spell in choices:
		if spell.id == selected_id: return
	selected_id = str(choices[0].id) if not choices.is_empty() else ""

func tick(_dt: float = 0.0) -> void:
	if not is_instance_valid(search_entry): return
	var browsing: bool = game.mode in ["grimoire", "spellforge"]
	if not browsing:
		if search_entry.visible or search_entry.has_focus() or not _text_pointers.is_empty(): cancel_draft()
		search_entry.hide()
		return
	search_entry.show()
	var ratio: Vector2 = h.get_viewport_rect().size / Vector2(1280, 720)
	if ratio.x <= 0 or ratio.y <= 0: ratio = Vector2.ONE
	search_entry.position = SEARCH_RECT.position * ratio
	search_entry.size = SEARCH_RECT.size
	search_entry.scale = ratio

func cancel_draft() -> void:


	if is_instance_valid(search_entry) and search_entry.has_focus(): search_entry.release_focus()
	_text_pointers.clear()

func begin_edit(_id: String = "", _clone := false) -> bool:
	status = "Spells are ready to equip. Saved personal spells remain read-only."
	return false

func is_text_input_active() -> bool:
	return is_instance_valid(search_entry) and search_entry.visible and search_entry.has_focus()

func owns_pointer(pointer: int) -> bool:
	return _text_pointers.has(pointer)

func handle_input(event: InputEvent) -> bool:
	if game.mode not in ["grimoire", "spellforge"]: return false
	if event is InputEventKey and is_text_input_active():
		if event.pressed and event.keycode == KEY_ESCAPE: cancel_draft()
		return true
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pointer: int = event.index if event is InputEventScreenTouch else -2


		if not event.pressed:
			_text_pointers.erase(pointer)
			return false
		if search_entry.visible and Rect2(search_entry.global_position, search_entry.size * search_entry.scale).has_point(event.position):
			_text_pointers[pointer] = true
			if event is InputEventScreenTouch: search_entry.grab_focus()
			return true
		if search_entry.has_focus(): search_entry.release_focus()
	if event is InputEventScreenDrag and owns_pointer(event.index): return true
	if event is InputEventMouseMotion and owns_pointer(-2): return true
	return false

func dispatch(tag: String) -> bool:


	if not tag.begins_with("collection:") and not tag.begins_with("magic:"): return false
	var pieces := tag.split(":")
	if pieces.size() < 2: return true
	var command := str(pieces[1])
	var value := str(pieces[2]) if pieces.size() > 2 else ""
	match command:
		"select":
			if not game.state.spell_by_id(value).is_empty():
				selected_id = value
				if search_query.is_empty(): source_filter = "archive" if Collection.metadata(value).is_empty() else "collection"
				status = "Choose one of the four slots to equip this spell."
		"source":
			if value in ["collection", "archive"]:
				source_filter = value
				search_query = ""
				search_entry.text = ""
				page = 0
				_choose_first_visible()
				status = "Your saved archive is read-only and ready to equip." if value == "archive" else "All %d curated spells are ready to equip." % Collection.all_spells().size()
		"element":
			if value == "all" or value in Book.ELEMENTS: element_filter = value; page = 0; _choose_first_visible()
		"role":
			if value == "all" or value in Collection.ROLES: role_filter = value; page = 0; _choose_first_visible()
		"page":
			if value.is_valid_int(): page = clampi(page + int(value), 0, maxi(0, ceili(filtered_library().size() / float(PAGE_SIZE)) - 1))
		"slot":
			if value.is_valid_int() and int(value) in range(Book.SLOT_COUNT): game.select_spell_slot(int(value))
		"equip":
			var spell := selected_spell()
			if value.is_valid_int() and int(value) in range(Book.SLOT_COUNT) and not spell.is_empty():
				if game.equip_custom_spell(str(spell.id), int(value)): status = "%s equipped in slot %d." % [spell.name, int(value) + 1]
		"track":
			cancel_draft(); game.track_wizard_tower()
		"close", "cancel", "back":
			cancel_draft(); game.set_mode("play")
		_:
			status = "Collection spells are read-only. Select a spell and equip a slot."
	h.queue_redraw()
	return true

func action(rect: Rect2, value: String, tag: String, active := false, enabled := true, font_size := 15) -> void:
	var hover: bool = rect.has_point(h.mouse_pos - h.drawing_offset)
	Art.draw_button(h, rect, active and enabled, 1.0 if hover and enabled else 0.0)
	if not enabled: h.draw_rect(rect.grow(-2), Color(Art.PAPER, 0.4))
	h.centered(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - font_size * 0.54), _fit(value, rect.size.x - 14, font_size), font_size, (PAPER if active else INK) if enabled else Art.MUTED)
	if enabled and not tag.is_empty(): h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": tag, "mode": game.mode})

func _fit(value: String, width: float, font_size: int, serif := false) -> String:
	var result := value
	while Art.font(serif).get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and result.length() > 1: result = result.left(result.length() - 2) + "…"
	return result

func _paragraph(pos: Vector2, value: String, width: float, font_size: int, max_lines: int, color := FAINT) -> void:
	var lines: Array[String] = []; var current := ""
	for word in value.split(" "):
		var next := current + (" " if not current.is_empty() else "") + word
		if h.body_font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty(): lines.append(current); current = word
		else: current = next
	if not current.is_empty(): lines.append(current)
	for index in range(mini(max_lines, lines.size())):
		var line := lines[index]
		if index == max_lines - 1 and lines.size() > max_lines: line += "…"
		h.txt(pos + Vector2(0, index * font_size * 1.42), _fit(line, width, font_size), font_size, color)

func draw(mode: String) -> void:
	if mode not in ["grimoire", "spellforge"]: return
	tick()
	var previous_context = h.get("paper_context")
	if previous_context != null: h.set("paper_context", false)
	Art.draw_frame(h, Rect2(20, 16, 1240, 686))
	h.centered(Vector2(640, 38), "THE LIVING GRIMOIRE", 27, PAPER, true)
	h.txt(Vector2(60, 91), _fit(status, 1016, 12), 12, Art.MUTED)
	action(Rect2(1092, 52, 108, 48), "×  Close", "collection:close")
	action(Rect2(676, 118, 136, 46), "Collection · %d" % Collection.all_spells().size(), "collection:source:collection", source_filter == "collection", true, 13)
	action(Rect2(820, 118, 132, 46), "Saved archive", "collection:source:archive", source_filter == "archive", true, 13)
	action(Rect2(962, 118, 238, 46), "Find tower archive", "collection:track")
	var elements: Array = ["all"] + Book.ELEMENTS
	for index in range(elements.size()):
		var family := str(elements[index])
		action(Rect2(60 + index * 88, 182, 84, 44), "All" if family == "all" else family.capitalize(), "collection:element:" + family, element_filter == family, true, 13)
	var roles: Array = ["all"] + Collection.ROLES
	for index in range(roles.size()):
		var purpose := str(roles[index])
		action(Rect2(60 + index * 143, 234, 139, 44), "All roles" if purpose == "all" else purpose.capitalize(), "collection:role:" + purpose, role_filter == purpose, true, 14)
	var filtered := filtered_library()
	var pages := maxi(1, ceili(filtered.size() / float(PAGE_SIZE)))
	page = clampi(page, 0, pages - 1)
	h.txt(Vector2(60, 292), "%d SPELLS  ·  %s" % [filtered.size(), "COLLECTION & ARCHIVE SEARCH" if not search_query.is_empty() else ("SAVED ARCHIVE · READ-ONLY" if source_filter == "archive" else "CURATED COLLECTION")], 12, Art.MUTED)
	for index in range(mini(PAGE_SIZE, filtered.size() - page * PAGE_SIZE)):
		var spell: Dictionary = filtered[page * PAGE_SIZE + index]
		var rect := Rect2(60, 316 + index * 58, 590, 52)
		var chosen: bool = spell.id == selected_id
		h.panel(rect, Color("#304a47") if chosen else SLATE, Color(Art.BRASS if chosen else Art.SILVER, 0.85 if chosen else 0.4), 3)
		if chosen: h.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(3, 48)), Art.RED)
		_glyph(Rect2(rect.position + Vector2(8, 5), Vector2(42, 42)), spell)
		h.txt(rect.position + Vector2(62, 4), _fit(str(spell.name), 500, 18, true), 18, PAPER, true)
		h.txt(rect.position + Vector2(62, 30), _fit("%s · %s · %d mana · %s" % [str(spell.element).capitalize(), str(spell.form).capitalize(), int(Book.cost(spell)), Collection.role(spell).capitalize()], 500, 12), 12, GOLD if chosen else FAINT)
		h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": "collection:select:" + str(spell.id), "mode": game.mode})
	if filtered.is_empty(): _paragraph(Vector2(80, 350), "No spells match. Change the family or role, or clear the search.", 540, 18, 3, Art.MUTED)
	action(Rect2(60, 616, 108, 44), "‹  Previous", "collection:page:-1", false, page > 0, 14)
	h.centered(Vector2(355, 627), "%d / %d" % [page + 1, pages], 17, Art.MUTED)
	action(Rect2(542, 616, 108, 44), "Next  ›", "collection:page:1", false, page < pages - 1, 14)
	_draw_details(selected_spell())
	if previous_context != null: h.set("paper_context", previous_context)

func _draw_details(spell: Dictionary) -> void:
	Art.draw_frame(h, Rect2(676, 302, 524, 306), true)
	if spell.is_empty():
		h.txt(Vector2(700, 330), "Select a spell to read its notes.", 20, PAPER)
		return
	var note := Collection.metadata(str(spell.id))
	var curated := not note.is_empty()
	_glyph(Rect2(692, 310, 112, 112), spell)
	h.txt(Vector2(816, 318), _fit(str(spell.name), 364, 24, true), 24, PAPER, true)
	h.txt(Vector2(816, 352), _fit("%s / %s / %s" % [str(spell.element).capitalize(), Collection.role(spell).capitalize(), str(spell.form).capitalize()], 364, 13), 13, CYAN)
	h.txt(Vector2(816, 377), (("BASIC" if Collection.tier(str(spell.id)) == "basic" else "ADVANCED") + " " + str(spell.element).to_upper() + " SPELL" + (" · HOLD TO CHARGE" if float(spell.get("charge", 0.0)) > 0.0 else "")) if curated else "SAVED LEGACY SPELL · READ-ONLY", 11, GOLD)
	_paragraph(Vector2(696, 427), str(note.get("summary", "Your saved spell remains intact and ready to equip.")), 484, 16, 2, PAPER)
	h.txt(Vector2(696, 477), "%d MANA    /    %.1f s RECOVERY    /    %d STAGE%s" % [int(Book.cost(spell)), Book.cooldown(spell), Book.stage_count(spell), "S" if Book.stage_count(spell) != 1 else ""], 13, GOLD)
	h.txt(Vector2(696, 501), _fit(Collection.damage_summary(spell), 484, 14), 14, CYAN)
	_paragraph(Vector2(696, 529), str(note.get("tactics", Book.describe(spell))), 484, 14, 3)
	for slot in range(Book.SLOT_COUNT):
		var rect := Rect2(676 + slot * 133, 616, 125, 44)
		var equipped: Dictionary = game.state.spell_by_id(str(game.state.spell_slots[slot]))
		var active: bool = game.state.active_spell_slot == slot
		h.panel(rect, Color("#36534c") if active else SLATE, Color(CYAN if str(equipped.get("id", "")) == str(spell.id) else Art.SILVER, 0.85 if active else 0.4), 3)
		h.txt(rect.position + Vector2(9, 3), "EQUIP SLOT %d%s" % [slot + 1, " · ACTIVE" if active else ""], 10, CYAN if active else FAINT)
		h.txt(rect.position + Vector2(9, 21), _fit(str(equipped.get("name", "Empty")), 107, 12), 12, PAPER)
		h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": "collection:equip:" + str(slot), "mode": game.mode})

func _glyph(rect: Rect2, spell: Dictionary) -> void:
	var painting := Art.spell_texture(str(spell.get("id", "")))
	if painting != null:
		Art.draw_fitted(h, painting, rect)
		return
	var c := rect.get_center(); var r := rect.size.x * 0.36
	var color := Color(str(spell.color)); var accent := Color(str(spell.accent))
	h.draw_circle(c, r * 1.2, Color(color, 0.09))
	h.draw_arc(c, r * 1.1, 0, TAU, 32, Color(color, 0.4), 1.0, true)
	match str(spell.form):
		"beam", "touch":
			h.draw_line(c + Vector2(-r, r * 0.8), c + Vector2(r, -r * 0.8), color, 3.0, true)
			h.draw_circle(c + Vector2(r, -r * 0.8), r * 0.22, accent)
		"ward", "field", "burst", "trap":
			h.draw_arc(c, r * 0.75, 0, TAU, 24, color, 2.0, true)
			for index in range(4):
				var direction := Vector2.RIGHT.rotated(index * TAU / 4.0)
				h.draw_line(c + direction * r * 0.5, c + direction * r, accent, 1.5, true)
			if spell.form == "trap": h.draw_line(c + Vector2(-r, r), c + Vector2(r, r), color, 2.0, true)
		"wall":
			h.draw_rect(Rect2(c - Vector2(r * 0.8, r), Vector2(r * 1.6, r * 2)), Color(color, 0.45))
			h.draw_line(c - Vector2(r * 0.8, r), c + Vector2(r * 0.8, -r), accent, 2.0, true)
		"rain":
			for index in range(3):
				var x := (index - 1) * r * 0.65
				h.draw_line(c + Vector2(x, -r), c + Vector2(x - r * 0.25, r * 0.8), color, 2.0, true)
				h.draw_circle(c + Vector2(x - r * 0.25, r * 0.8), r * 0.12, accent)
		"orbitals":
			h.draw_arc(c, r * 0.75, 0, TAU, 24, color, 1.5, true)
			for index in range(3): h.draw_circle(c + Vector2.RIGHT.rotated(index * TAU / 3.0) * r * 0.75, r * 0.2, accent)
		"mend":
			h.draw_line(c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.7, 0), color, 4.0, true)
			h.draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.7), accent, 4.0, true)
		"step":
			for index in range(2):
				var x := (index - 0.5) * r
				h.draw_polyline(PackedVector2Array([c + Vector2(x - r * 0.4, -r * 0.7), c + Vector2(x + r * 0.3, 0), c + Vector2(x - r * 0.4, r * 0.7)]), color if index == 0 else accent, 2.5, true)
		"summon":
			h.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), Color(color, 0.6))
			h.draw_circle(c + Vector2(0, -r * 0.15), r * 0.25, accent)
		"cone":
			h.draw_polyline(PackedVector2Array([c + Vector2(r, -r), c - Vector2(r, 0), c + Vector2(r, r)]), color, 2.0, true)
			h.draw_arc(c - Vector2(r, 0), r * 1.8, -0.5, 0.5, 12, accent, 2.0, true)
		_:
			for index in range(mini(int(spell.count), 3)):
				var p := c + Vector2((index - (mini(int(spell.count), 3) - 1) * 0.5) * r * 0.7, sin(index) * r * 0.25)
				h.draw_circle(p, r * 0.25, color); h.draw_circle(p - Vector2(r * 0.05, r * 0.05), r * 0.1, accent)
