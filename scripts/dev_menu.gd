extends RefCounted

const Tools = preload("res://scripts/dev_tools.gd")
const Catalog = preload("res://scripts/crafting.gd")
const Quests = preload("res://scripts/quests.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Wildlife = preload("res://scripts/wildlife.gd")
const Art = preload("res://scripts/lantern_ledger_art.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
const TABS := ["Travel", "Inventory", "Magic", "Quests", "Creatures", "World & tools"]
const PAGE_SIZE := 6
const PAPER := Art.PAPER
const MUTED := Art.MUTED
const CYAN := Color("#236c62")
var h
var game
var controller
var search_entry: LineEdit
var tab := 0
var page := 0
var query := ""
var commands: Array = []
var return_mode := "play"
var was_open := false

func setup(hud) -> void:
	h = hud
	game = hud.game
	controller = game.get("dev_tools")
	if controller == null:
		controller = Tools.new()
		controller.setup(game)
	if is_instance_valid(search_entry): return
	search_entry = LineEdit.new()
	search_entry.name = "DevSearch"
	search_entry.placeholder_text = "Search this tab by name, type, item or feature…"
	search_entry.max_length = 70
	search_entry.clear_button_enabled = true
	search_entry.virtual_keyboard_enabled = true
	search_entry.add_theme_font_override("font", Art.font())
	search_entry.add_theme_font_size_override("font_size", 21)
	search_entry.add_theme_color_override("font_color", Art.INK)
	search_entry.add_theme_color_override("font_placeholder_color", Art.MUTED)
	search_entry.add_theme_color_override("caret_color", Art.RED)
	var style := StyleBoxFlat.new()
	style.bg_color = Art.PAPER.lightened(0.08)
	style.border_color = Color(Art.BRASS, 0.65)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	search_entry.add_theme_stylebox_override("normal", style)
	var focus: StyleBoxFlat = style.duplicate()
	focus.border_color = Art.RED
	focus.set_border_width_all(2)
	search_entry.add_theme_stylebox_override("focus", focus)
	search_entry.text_changed.connect(_search_changed)
	search_entry.text_submitted.connect(_submit_search)
	search_entry.hide()
	h.add_child(search_entry)

func _search_changed(value: String) -> void:
	query = value.to_lower().strip_edges()
	page = 0
	h.queue_redraw()

func _submit_search(_value: String) -> void:
	search_entry.release_focus()
	_hide_keyboard()

func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()

func tick(_dt: float = 0.0) -> void:
	if not is_instance_valid(search_entry): return
	var opened: bool = game.mode == "dev"
	search_entry.visible = opened
	if not opened and search_entry.has_focus():
		search_entry.release_focus()
		_hide_keyboard()
	if opened and not was_open:
		page = 0
		controller.status = "Travel directly to towns, cities and ground sky lifts. Buildings, caves and dungeons arrive outside."
	was_open = opened
	var ratio: Vector2 = h.get_viewport_rect().size / Vector2(1280, 720)
	if ratio.x <= 0 or ratio.y <= 0: ratio = Vector2.ONE
	search_entry.position = Vector2(278, 122) * ratio
	search_entry.size = Vector2(920, 52)
	search_entry.scale = ratio

func handle_input(event: InputEvent) -> bool:
	if game.mode != "dev" or not is_instance_valid(search_entry): return false
	if event is InputEventKey and search_entry.has_focus():
		if event.pressed and event.keycode == KEY_ESCAPE:
			search_entry.release_focus()
			_hide_keyboard()
			h.get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if not event.pressed: return false
		return Rect2(search_entry.global_position, search_entry.size * search_entry.scale).has_point(event.position)
	return false

func _action(rect: Rect2, title: String, tag: String, active := false, enabled := true) -> void:
	var hover: bool = rect.has_point(h.mouse_pos - h.drawing_offset)
	Art.draw_button(h, rect, active and enabled, 1.0 if hover and enabled else 0.0)
	if not enabled: h.draw_rect(rect.grow(-2), Color(PAPER, 0.4))
	var font_size := 17
	while Art.font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 14 and font_size > 12: font_size -= 1
	h.centered(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - font_size * 0.55), _fit(title, rect.size.x - 14, font_size), font_size, (PAPER if active else Art.INK) if enabled else MUTED)
	if enabled: h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": tag, "mode": game.mode})

func _fit(value: String, width: float, font_size := 17, serif := false) -> String:
	var result := value
	while Art.font(serif).get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and result.length() > 2:
		result = result.left(result.length() - 2) + "…"
	return result

func _command(title: String, action: String, payload: Variant = null) -> Dictionary:
	return {"label": title, "action": action, "payload": payload}

func _row(title: String, detail: String, actions: Array, item_id := "", spell_id := "") -> Dictionary:
	return {"title": title, "detail": detail, "actions": actions, "item_id": item_id, "spell_id": spell_id}

func rows() -> Array:
	var result: Array = []
	match tab:
		0:
			result.append(_row("Return to previous location", "Travel sets a reversible return point.", [_command("Return", "return")]))
			for destination in controller.destinations():
				result.append(_row(str(destination.name), str(destination.kind), [_command("Travel", "travel", destination.id)]))
		1:
			result.append(_row("Inventory & crafting", "Open your real satchel, equipment or recipe window.", [_command("Inventory", "open", "bag"), _command("Craft", "open", "craft")]))
			for id in Catalog.ITEMS:
				var owned: bool = game.state.unlocked.get(id, false) or game.state.upgrades.get(id, false)
				var unique: bool = Catalog.WEAPONS.has(id) or Catalog.UPGRADES.has(id)
				var detail: String = "Owned" if unique and owned else ("Not owned" if unique else "%d in inventory" % int(game.state.items.get(id, 0)))
				if Catalog.WEAPONS.has(id): detail = "Weapon / equipment · " + detail
				if Catalog.UPGRADES.has(id): detail = "Upgrade · " + detail
				if game.state.equipment == id: detail += " · equipped"
				var actions: Array = [_command("Grant +1", "grant", {"id": id, "amount": 1})]
				if not unique: actions.append(_command("Grant +10", "grant", {"id": id, "amount": 10}))
				if Catalog.WEAPONS.has(id): actions.append(_command("Equip", "equip", id))
				result.append(_row(Catalog.item_name(id), detail, actions, str(id)))
		2:
			var flight: bool = is_instance_valid(game.player) and game.player.light_flight.enabled
			result.append(_row("Seraph Flight: " + ("ON" if flight else "OFF"), "Double jump + hold to fly. Stop to hover; double-tap and hold A/Space to boost.", [_command("Turn off" if flight else "Turn on", "light_flight")]))
			result.append(_row("Spell library & quick slots", "Browse and equip existing magic anywhere.", [_command("Open library", "open", "grimoire")]))
			result.append(_row("Wizard's spell archive", "Visit the tower and browse predefined spells.", [_command("Travel archive", "travel", "spell_altar"), _command("Browse here", "altar")]))
			var infinite: bool = game.state.infinite_mana()
			result.append(_row("Infinite mana: " + ("ON" if infinite else "OFF"), "Every spell is free while this is on. Turn it off to play normally.", [_command("Turn off" if infinite else "Turn on", "infinite_mana")]))
			result.append(_row("Restore testing resources", "Refill health, mana and stamina immediately.", [_command("Restore", "restore")]))
			result.append(_row("Restore starter spells", "Adds missing predefined starters; keeps saved legacy spells.", [_command("Restore starters", "starters")]))
			result.append(_row("Physics magic practice object", "Create a real throwable stone in front of you.", [_command("Spawn stone", "spawn_object")]))
			for spell in game.state.collection_spells():
				result.append(_row(str(spell.name), str(spell.get("form", "")) + " · " + str(spell.get("effect", "elemental")), [_command("Equip in library", "open", "grimoire")], "", str(spell.id)))
		3:
			result.append(_row("Journal & expeditions", "Inspect actual requests, progress, rewards and expedition goals.", [_command("Open journal", "open", "journal")]))
			if game.quests != null:
				for request in game.quests.entries():
					result.append(_row(str(request.name), str(request.owner) + " · " + str(request.status), [_command("Visit giver", "quest_giver", request.id), _command("Track", "quest_track", request.id)]))
		4:
			result.append(_row("Undo / clear developer spawns", "Removes test actors only. Test deaths grant no loot or quest progress.", [_command("Undo last", "undo_spawn"), _command("Clear all", "clear_spawns")]))
			result.append(_row("Combat resources", "Refill health, mana and stamina before a test fight.", [_command("Restore", "restore")]))
			for id in Enemy.SPECIES:
				result.append(_row(str(Enemy.SPECIES[id].name), "Enemy · production model and combat behavior", [_command("Spawn enemy", "spawn_enemy", id)]))
			for id in ["embermaw", "bellkeeper"]:
				result.append(_row("Test " + str(id).capitalize(), "Boss · spawn inside its mine / crypt; no seal changes", [_command("Spawn boss", "spawn_boss", id)]))
			var seen: Array = []
			for species in Wildlife.POOL_SPECIES:
				if species in seen: continue
				seen.append(species)
				result.append(_row(str(species).capitalize(), "Wildlife · outdoors, normal roaming behavior", [_command("Spawn wildlife", "spawn_wildlife", species)]))
		5:
			result.append(_row("World daytime", "Changes the actual day / night lighting cycle.", [_command("Dawn", "time", "dawn"), _command("Noon", "time", "noon"), _command("Dusk", "time", "dusk"), _command("Night", "time", "night")]))
			result.append(_row("Rendering quality", "Apply actual mobile render distance, resolution and shadows.", [_command("Low", "quality", 0), _command("Balanced", "quality", 1), _command("High", "quality", 2)]))
			result.append(_row("Settings & controls", "Volume, music, sensitivity and control help.", [_command("Settings", "open", "settings"), _command("Controls", "open", "controls")]))
			result.append(_row("Health, mana & stamina", "Restore actual resources for movement or combat testing.", [_command("Restore", "restore")]))
			result.append(_row("Physics test stone", "Lift, throw or target it with physics spells.", [_command("Spawn stone", "spawn_object")]))
			result.append(_row("Developer spawn cleanup", "Undo last or clear all test creatures and objects.", [_command("Undo last", "undo_spawn"), _command("Clear all", "clear_spawns")]))
			result.append(_row("All feature windows", "Direct access to inventory, crafting and journal.", [_command("Inventory", "open", "bag"), _command("Craft", "open", "craft"), _command("Journal", "open", "journal")]))
	if query.is_empty(): return result
	return result.filter(func (row): return (str(row.title) + " " + str(row.detail)).to_lower().contains(query))

func draw() -> void:
	tick()
	if game.mode != "dev": return
	var previous_context = h.get("paper_context")
	if previous_context != null: h.set("paper_context", false)
	Art.draw_frame(h, Rect2(20, 16, 1240, 686))
	h.centered(Vector2(640, 38), "THE DEVELOPER'S FIELDKIT", 26, PAPER, true)
	h.txt(Vector2(76, 91), _fit(str(controller.status), 970, 13), 13, CYAN)
	_action(Rect2(1072, 56, 128, 48), "Close", "dev:close")
	for index in range(TABS.size()):
		_action(Rect2(72, 122 + index * 62, 184, 52), TABS[index], "dev:tab:%d" % index, index == tab)
	h.txt(Vector2(76, 519), "TEST ACTORS", 12, CYAN)
	h.txt(Vector2(76, 543), "%d / %d active" % [controller.live_spawns().size(), Tools.MAX_TEST_SPAWNS], 17, Art.INK)
	h.paragraph(Vector2(76, 576), "All locations available.\nDiscovery bypass: DEV only.", 178, 14, MUTED)
	var entries: Array = rows()
	var pages: int = maxi(1, ceili(float(entries.size()) / PAGE_SIZE))
	page = clampi(page, 0, pages - 1)
	h.txt(Vector2(280, 186), "%s · %d results · page %d / %d" % [TABS[tab], entries.size(), page + 1, pages], 16, CYAN)
	commands.clear()
	for slot in range(PAGE_SIZE):
		var index: int = page * PAGE_SIZE + slot
		if index >= entries.size(): break
		var row: Dictionary = entries[index]
		var y: float = 218 + slot * 59
		h.draw_rect(Rect2(278, y, 920, 54), Color(Art.BRASS, 0.065))
		h.draw_line(Vector2(278, y + 56), Vector2(1198, y + 56), Color(Art.BRASS, 0.28), 1)
		var actions: Array = row.actions
		var action_width: float = 114 if actions.size() < 4 else 82
		var left: float = 1188 - actions.size() * (action_width + 6)
		var painting: Texture2D = Art.item_texture(str(row.item_id)) if str(row.item_id) != "" else Art.spell_texture(str(row.spell_id))
		if painting == null and str(row.item_id) != "": painting = ItemIcons.texture(str(row.item_id))
		var text_x := 344.0 if painting != null else 290.0
		if painting != null: Art.draw_fitted(h, painting, Rect2(290, y + 4, 44, 44))
		h.txt(Vector2(text_x, y + 6), _fit(str(row.title), left - text_x - 10, 19, true), 19, Art.INK, true)
		h.txt(Vector2(text_x, y + 31), _fit(str(row.detail), left - text_x - 10, 14), 14, MUTED)
		for action_index in range(actions.size()):
			var command_index: int = commands.size()
			commands.append(actions[action_index])
			_action(Rect2(left + action_index * (action_width + 6), y + 4, action_width, 46), str(actions[action_index].label), "dev:run:%d" % command_index)
	if entries.is_empty(): h.txt(Vector2(294, 254), "No matching tools. Clear search or choose another tab.", 21, MUTED)
	_action(Rect2(278, 582, 128, 46), "← Previous", "dev:prev", false, page > 0)
	_action(Rect2(1070, 582, 128, 46), "Next →", "dev:next", false, page < pages - 1)
	h.txt(Vector2(424, 595), "Search filters the selected tab", 16, MUTED)
	if previous_context != null: h.set("paper_context", previous_context)

func dispatch(tag: String) -> bool:
	if not tag.begins_with("dev:"): return false
	var parts: PackedStringArray = tag.split(":")
	if tag == "dev:open":
		if game.mode in ["play", "pause"]:
			return_mode = game.mode
			game.set_mode("dev")
		return true
	if game.mode != "dev": return false
	match parts[1]:
		"close": game.set_mode(return_mode if return_mode in ["play", "pause"] else "play")
		"tab":
			if parts.size() != 3 or not parts[2].is_valid_int(): return false
			tab = clampi(int(parts[2]), 0, TABS.size() - 1)
			page = 0
			query = ""
			search_entry.text = ""
		"prev": page = maxi(0, page - 1)
		"next": page += 1
		"run":
			if parts.size() != 3 or not parts[2].is_valid_int(): return false
			var index: int = int(parts[2])
			if index < 0 or index >= commands.size(): return false
			var command: Dictionary = commands[index]
			controller.execute(str(command.action), command.payload, true)
		_: return false
	if is_instance_valid(search_entry):
		search_entry.release_focus()
		_hide_keyboard()
	h.queue_redraw()
	return true
