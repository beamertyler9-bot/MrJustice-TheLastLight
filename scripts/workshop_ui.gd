extends RefCounted

const Catalog = preload("res://scripts/crafting.gd")
const State = preload("res://scripts/state.gd")
const Art = preload("res://scripts/lantern_ledger_art.gd")
const PAPER := Art.PAPER
const INK := Art.INK
const SLATE := Art.NIGHT
const FAINT := Color("#bdc9bf")
const RED := Art.RED
const CYAN := Color("#91cdbb")
const GOLD := Color("#d9bd7b")
const BATCH_RECT := Rect2(902, 404, 62, 44)
var fieldbook_ref: WeakRef
var f:
	get: return fieldbook_ref.get_ref()
var h
var game
var selected_slot := -1
var split_mode := false
var tray_page := 0
var remove_mode := false
var batch_entry: LineEdit
var _text_pointers: Dictionary = {}

func setup(fieldbook) -> void:
	fieldbook_ref = weakref(fieldbook)
	h = fieldbook.h
	game = fieldbook.game
	if is_instance_valid(batch_entry): return
	batch_entry = LineEdit.new()
	batch_entry.name = "RecipeBatches"
	batch_entry.text = "1"
	batch_entry.max_length = 2
	batch_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	batch_entry.virtual_keyboard_enabled = true
	batch_entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	batch_entry.add_theme_font_override("font", Art.font())
	batch_entry.add_theme_font_size_override("font_size", 23)
	batch_entry.add_theme_constant_override("minimum_character_width", 2)
	batch_entry.add_theme_color_override("font_color", Art.INK)
	batch_entry.add_theme_color_override("caret_color", Art.RED)
	var style := StyleBoxFlat.new()
	style.bg_color = Art.PAPER.lightened(0.08)
	style.border_color = Art.BRASS
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	batch_entry.add_theme_stylebox_override("normal", style)
	var focus: StyleBoxFlat = style.duplicate()
	focus.border_color = Art.RED
	focus.set_border_width_all(2)
	batch_entry.add_theme_stylebox_override("focus", focus)
	batch_entry.text_changed.connect(func (_value: String): h.queue_redraw())
	batch_entry.text_submitted.connect(func (_value: String): cancel_input())
	batch_entry.hide()
	h.add_child(batch_entry)

func repeatable_recipe(id: String) -> bool:
	var recipe: Dictionary = Catalog.RECIPES.get(id, {})
	return not recipe.is_empty() and not bool(recipe.get("upgrade", false)) and not Catalog.WEAPONS.has(str(recipe.get("output", id)))

func batch_count() -> int:
	if not is_instance_valid(batch_entry): return 0
	var value := batch_entry.text.strip_edges()
	if not value.is_valid_int(): return 0
	var amount := int(value)
	return amount if amount >= 1 and amount <= 5 else 0

func tick(_dt := 0.0) -> void:
	if not is_instance_valid(batch_entry): return
	var opened: bool = game.mode == "craft" and repeatable_recipe(str(f.selected_recipe))
	if not opened:
		if batch_entry.visible or batch_entry.has_focus() or not _text_pointers.is_empty(): cancel_input()
		batch_entry.hide()
		return
	var ratio: Vector2 = h.get_viewport_rect().size / Vector2(1280, 720)
	if ratio.x <= 0 or ratio.y <= 0: ratio = Vector2.ONE
	batch_entry.position = (BATCH_RECT.position + h.drawing_offset) * ratio
	batch_entry.size = BATCH_RECT.size
	batch_entry.scale = ratio
	batch_entry.show()

func cancel_input() -> void:
	if is_instance_valid(batch_entry) and batch_entry.has_focus(): batch_entry.release_focus()
	_text_pointers.clear()

func owns_pointer(pointer: int) -> bool:
	return _text_pointers.has(pointer)

func handle_input(event: InputEvent) -> bool:
	if game.mode != "craft" or not is_instance_valid(batch_entry) or not batch_entry.visible: return false
	if event is InputEventKey and batch_entry.has_focus():
		if event.pressed and event.keycode == KEY_ESCAPE:
			cancel_input()
			h.get_viewport().set_input_as_handled()
		return true
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pointer: int = event.index if event is InputEventScreenTouch else -2
		if not event.pressed:
			_text_pointers.erase(pointer)
			return false
		if Rect2(batch_entry.global_position, batch_entry.size * batch_entry.scale).has_point(event.position):
			_text_pointers[pointer] = true
			if event is InputEventScreenTouch: batch_entry.grab_focus()
			return true
		if batch_entry.has_focus(): batch_entry.release_focus()
	if event is InputEventScreenDrag and owns_pointer(event.index): return true
	if event is InputEventMouseMotion and owns_pointer(-2): return true
	return false

func raw_slots() -> Array:
	return game.state.inventory_slots() if game.state.has_method("inventory_slots") else []

func grid_cells() -> Array:
	var value = game.get("craft_grid")
	return value if value is Array else []

func grid_size() -> int:
	return int(game.crafting_size()) if game.has_method("crafting_size") else 2

func at_bench() -> bool:
	return game.has_method("near_workbench") and game.near_workbench()

func display_slots() -> Array:
	var slots: Array = raw_slots()
	var reserved := {}
	for cell in grid_cells():
		if cell is Dictionary and not cell.is_empty():
			var item := str(cell.get("item", ""))
			reserved[item] = int(reserved.get(item, 0)) + int(cell.get("amount", 0))

	for i in range(slots.size()):
		var cell: Dictionary = slots[i]
		var item := str(cell.get("item", ""))
		var amount := int(cell.get("amount", 0))
		var used := mini(amount, int(reserved.get(item, 0)))
		reserved[item] = int(reserved.get(item, 0)) - used
		if amount - used <= 0:
			slots[i] = {}
		else:
			slots[i] = {"item": item, "amount": amount - used}
	return slots

func register(rect: Rect2, tag: String, cell: Dictionary = {}) -> void:
	h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": tag, "mode": game.mode, "item": str(cell.get("item", "")), "amount": int(cell.get("amount", 0))})

func square(rect: Rect2, cell: Dictionary, tag: String, selected := false, number := 0, ghost := false, enabled := true) -> void:
	var fill := Color("#294349") if not selected else Color("#38554f")
	var edge := Color(Art.SILVER, 0.38) if not selected else Art.BRASS.lightened(0.25)
	if ghost:
		fill = Color(Art.NIGHT, 0.7)
		edge = Color(Art.SILVER, 0.2)
	h.panel(rect, fill, edge, 1)
	h.draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(rect.size.x - 3, 3), Color(PAPER, 0.11), 2)
	h.draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(3, rect.size.y - 3), Color(PAPER, 0.07), 2)
	h.draw_line(rect.position + Vector2(3, rect.size.y - 3), rect.end - Vector2(3, 3), Color(INK, 0.5), 3)
	if selected:
		h.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 3)), RED)
	if not cell.is_empty():
		var color := Color(PAPER, 0.3) if ghost else PAPER
		var scale_value: float = (rect.size.x - 17.0) / 88.0
		f.schematic(rect.get_center() - Vector2(0, 3), str(cell.get("item", "")), scale_value, color)
		var amount := int(cell.get("amount", 0))
		if amount > 1:
			var text_value := str(amount)
			var width: float = h.body_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var pos := rect.end - Vector2(width + 6, 22)
			h.txt(pos + Vector2(1, 1), text_value, 16, INK)
			h.txt(pos, text_value, 16, Color(PAPER, 0.4) if ghost else PAPER)
	if number > 0:
		h.txt(rect.position + Vector2(5, 3), str(number), 10, Color(PAPER, 0.55))
	if enabled and not tag.is_empty():
		register(rect, tag, cell)

func inventory_square(origin: Vector2, side: float, index: int, slots: Array, quick := false) -> void:
	var cell: Dictionary = slots[index] if index < slots.size() else {}
	var selected: bool = index == int(game.state.get("selected_hotbar")) if quick else index == selected_slot
	square(Rect2(origin, Vector2.ONE * side), cell, ("hotbar:" if quick else "slot:") + str(index), selected, index + 1 if index < 9 else 0)

func draw_hotbar() -> void:
	var slots := display_slots()
	if slots.is_empty():
		return
	var origin := Vector2(362, 650)
	h.panel(Rect2(origin - Vector2(7, 7), Vector2(566, 70)), Color(INK, 0.84), Color(PAPER, 0.16), 2)
	for i in range(9):
		inventory_square(origin + Vector2(i * 62, 0), 56, i, slots, true)
	var selected: int = clampi(int(game.state.get("selected_hotbar")), 0, 8)
	var item := str(slots[selected].get("item", "")) if selected < slots.size() else ""
	if not item.is_empty() and game.toast_time <= 0:
		h.centered(Vector2(640, 623), Catalog.item_name(item), 15, PAPER)

func nav(origin: Vector2, width: float, mode: String) -> void:
	var names := [["bag", "Satchel"], ["craft", "Recipe book"], ["journal", "Journal"]]
	var each := (width - 16) / 3.0
	for i in range(3):
		f.action(Rect2(origin + Vector2(i * (each + 8), 0), Vector2(each, 48)), names[i][1], names[i][0], names[i][0] == mode)

func draw_inventory() -> void:
	var previous: bool = f.begin_surface(true)
	Art.draw_frame(h, Rect2(340, 16, 910, 686))
	h.centered(Vector2(795, 38), "THE SATCHEL", 27, Art.PAPER, true)
	f.label(Vector2(384, 112), "PACK LIGHT / MAKE YOUR OWN WAY", 12, RED)
	f.action(Rect2(1104, 62, 110, 52), "×  Close", "play")
	nav(Vector2(384, 136), 552, "bag")
	f.action(Rect2(964, 136, 250, 48), "Contents" if f.inventory_tab == "gear" else "Equipment", "inventory:supplies" if f.inventory_tab == "gear" else "inventory:gear", f.inventory_tab == "gear")
	draw_grid(Vector2(394, 204), 56, true)
	var slots := display_slots()
	f.label(Vector2(384, 384), "SATCHEL  /  27 SLOTS", 12, FAINT)
	if f.inventory_tab == "gear":
		draw_gear(slots)
	else:
		var pages := maxi(1, ceili(maxi(0, slots.size() - 9) / 27.0))
		f.inventory_page = clampi(f.inventory_page, 0, pages - 1)
		for row in range(3):
			for col in range(9):
				var index: int = 9 + int(f.inventory_page) * 27 + row * 9 + col
				inventory_square(Vector2(384 + col * 62, 410 + row * 62), 56, index, slots)
		f.label(Vector2(384, 592), "QUICK SLOTS", 10, FAINT)
		for i in range(9):
			inventory_square(Vector2(384 + i * 62, 610), 56, i, slots)
		if pages > 1:
			f.pager(Rect2(964, 538, 250, 48), int(f.inventory_page), slots.size() - 9, 27, "inventory")
	draw_details(Vector2(964, 210), 250)
	f.action(Rect2(964, 610, 250, 52), "Split half · ON" if split_mode else "Split half · OFF", "split", split_mode)
	f.end_surface(previous)

func draw_gear(_slots: Array) -> void:
	var ids: Array = ["fists"]
	for id in game.state.unlocked:
		if id != "fists" and Catalog.WEAPONS.has(id):
			ids.append(id)
	for id in game.state.upgrades:
		ids.append(id)
	for i in range(ids.size()):
		var item := str(ids[i])
		square(Rect2(384 + (i % 9) * 62, 410 + (i / 9) * 62, 56, 56), {"item": item, "amount": 1}, "item:" + item, f.selected_item == item)
	f.label(Vector2(384, 556), "Fitted gear stays with you. Tools can be moved in Contents.", 14, FAINT)
	f.action(Rect2(384, 610, 552, 52), "Back to all stacks", "inventory:supplies")

func choose_default_item() -> void:
	if not str(f.selected_item).is_empty():
		return
	for cell in display_slots():
		if not cell.is_empty():
			f.selected_item = str(cell.item)
			return

func draw_details(pos: Vector2, width: float) -> void:
	choose_default_item()
	var item := str(f.selected_item)
	f.label(pos, "SELECTED ITEM", 11, FAINT)
	if item.is_empty():
		f.paragraph(pos + Vector2(0, 31), "Tap a stack. Tap an empty square to move it, or drag it there.", width, 17, PAPER)
		return
	f.schematic(pos + Vector2(35, 66), item, 0.63, PAPER)
	var y: float = f.paragraph(pos + Vector2(78, 36), Catalog.item_name(item), width - 78, 21, PAPER)
	y = maxf(pos.y + 109, y + 8)
	var description := str(Catalog.ITEMS.get(item, {}).get("description", "Two dependable hands, always ready."))
	y = f.paragraph(Vector2(pos.x, y), description, width, 15, FAINT)
	var count := int(game.state.items.get(item, 0))
	var available: int = game.available_count(item) if game.has_method("available_count") else count
	if count > 0:
		f.fitted_label(Vector2(pos.x, y + 7), "%d available · %d in grid" % [available, count - available] if available < count else "%d in pack" % count, width, 14, CYAN)
	y = maxf(pos.y + 213, y + 41)
	var rect := Rect2(pos.x, y, width, 52)
	if Catalog.WEAPONS.has(item):
		f.action(rect, "Equipped" if game.state.equipment == item else "Equip", "equip:" + item, game.state.equipment == item)
	elif game.state.upgrades.has(item):
		f.action(rect, "Fitted", "", false, false)
	elif item in ["coffee", "roasted_marshmallow", "tonic", "mana_potion", "smore"]:
		f.action(rect, "Use one", "supply:" + item, true, available > 0)
	elif item == "camp_kit":
		f.action(rect, "Ready camp · place with B", "place_camp", true, count > 0)
	elif item == "crafting_table":
		f.action(rect, "Ready table · place with B", "place_workbench", true, count > 0)
	else:
		f.action(rect, "Hold in hand", "ready:" + item, false, available > 0)
	var reserved := false
	for cell in grid_cells():
		if not cell.is_empty(): reserved = true; break
	f.label(Vector2(pos.x, 584), "Clear grid before splitting." if reserved and split_mode else "Tap → tap, or drag to move.", 12, GOLD if reserved and split_mode else FAINT)

func draw_grid(origin: Vector2, side: float, compact := false) -> void:
	var size_value := grid_size()
	var cells := grid_cells()
	var pitch := side + 6
	var start := origin + Vector2((3 - size_value) * pitch * 0.5, (3 - size_value) * pitch * 0.5)
	var title := "TABLE  /  3 × 3" if size_value == 3 else "BY HAND  /  2 × 2"
	f.label(Vector2(origin.x, origin.y - 19), title, 12, CYAN if size_value == 3 else FAINT)
	for i in range(size_value * size_value):
		var cell: Dictionary = cells[i] if i < cells.size() else {}
		square(Rect2(start + Vector2((i % size_value) * pitch, (i / size_value) * pitch), Vector2.ONE * side), cell, "grid:" + str(i))
	var output_id := str(game.craft_output()) if game.has_method("craft_output") else ""
	var result: Dictionary = Catalog.RECIPES.get(output_id, {})
	var output: Dictionary = {} if result.is_empty() else {"item": str(result.get("output", output_id)), "amount": int(result.get("amount", 1))}
	var output_enabled: bool = not output.is_empty() and can_stage(output_id)
	var result_pos := origin + Vector2(224 if compact else 246, 55)
	var mid := origin + Vector2(203 if compact else 218, 91)
	h.draw_line(mid - Vector2(15, 0), mid + Vector2(7, 0), Art.BRASS, 2, true)
	h.draw_polyline(PackedVector2Array([mid + Vector2(0, -7), mid + Vector2(8, 0), mid + Vector2(0, 7)]), Art.BRASS, 2, true)
	square(Rect2(result_pos, Vector2(72, 72)), output, "craft_output", output_enabled, 0, not output.is_empty() and not output_enabled, output_enabled)
	var output_label := "TAKE OUTPUT" if output_enabled else "OUTPUT"
	if not output.is_empty() and not output_enabled:
		var station := str(result.get("station", "field"))
		output_label = "NEEDS CAMPFIRE" if station == "camp" and not game.near_camp() else ("NEEDS TABLE" if station == "bench" and not at_bench() else "UNAVAILABLE")
	var flash: float = clampf(game.craft_flash, 0, 1)
	if flash > 0 and output.is_empty():
		output_label = "ASSEMBLED!"
		h.draw_arc(result_pos + Vector2(36, 36), 43 + (1.0 - flash) * 12, 0, TAU, 48, Color(CYAN, flash), 2, true)
	f.center(result_pos + Vector2(36, 82), output_label, 11, CYAN if output_enabled or flash > 0 else FAINT)
	if compact:
		f.label(origin + Vector2(324, 8), "Materials are only spent", 14, PAPER)
		f.label(origin + Vector2(324, 30), "when you take the output.", 14, PAPER)
		f.label(origin + Vector2(324, 66), "Hand patterns anywhere." if size_value == 2 else "Crafting table in reach.", 13, FAINT)
		f.action(Rect2(origin + Vector2(324, 86), Vector2(196, 44)), "Remove cell" if not remove_mode else "Remove cell · ON", "grid_remove_mode", remove_mode)
		f.action(Rect2(origin + Vector2(324, 138), Vector2(196, 44)), "Clear grid", "grid_clear")
	else:
		f.action(Rect2(origin + Vector2(224, -24), Vector2(142, 44)), "Remove cell" if not remove_mode else "Remove · ON", "grid_remove_mode", remove_mode)
		f.action(Rect2(origin + Vector2(224, 165), Vector2(142, 44)), "Clear grid", "grid_clear")

func draw_craft() -> void:
	f.sheet("THE FIELD WORKSHOP", "MAKE EVERY PIECE COUNT / THE MAKER'S RECIPE BOOK")
	var categories: Array = ["all"]
	categories.append_array(Catalog.categories())
	var cw := 1120.0 / categories.size()
	for i in range(categories.size()):
		f.action(Rect2(80 + i * cw, 160, cw - 7, 48), str(categories[i]).capitalize(), "category:" + str(categories[i]), f.category == categories[i])
	var ids: Array = f.recipes()
	if not ids.has(f.selected_recipe):
		f.selected_recipe = str(ids[0]) if not ids.is_empty() else ""
	tick()
	f.recipe_page = clampi(int(f.recipe_page), 0, maxi(0, (ids.size() - 1) / 5))
	for i in range(int(f.recipe_page) * 5, mini(ids.size(), int(f.recipe_page) * 5 + 5)):
		var id := str(ids[i])
		var rect := Rect2(80, 226 + (i % 5) * 62, 298, 54)
		var affordable: bool = can_stage(id)
		Art.draw_button(h, rect, f.selected_recipe == id)
		var recipe: Dictionary = Catalog.RECIPES[id]
		f.schematic(rect.position + Vector2(29, 27), str(recipe.get("output", id)), 0.47, PAPER)
		h.txt(rect.position + Vector2(57, 9), f.fit_text(Catalog.recipe_name(id), 228, 16), 16, Art.PAPER if f.selected_recipe == id else Art.INK)
		h.draw_rect(Rect2(rect.position + Vector2(4, 5), Vector2(3, rect.size.y - 10)), Color("#236c62") if affordable else Art.BRASS)
		register(rect, "recipe:" + id)
	f.pager(Rect2(80, 548, 298, 48), int(f.recipe_page), ids.size(), 5, "recipes")
	h.draw_line(Vector2(406, 226), Vector2(406, 598), Color(Art.BRASS, 0.28), 1)
	draw_grid(Vector2(438, 242), 60)
	draw_pattern_details(Vector2(828, 224), 372)
	f.label(Vector2(438, 472), "INGREDIENT STACKS  /  TAP, THEN PLACE", 11, FAINT)
	var slots := display_slots()
	tray_page = clampi(tray_page, 0, maxi(0, (slots.size() - 1) / 18))
	for row in range(2):
		for col in range(9):
			var index := tray_page * 18 + row * 9 + col
			inventory_square(Vector2(438 + col * 60, 494 + row * 58), 56, index, slots)
	f.action(Rect2(1002, 494, 198, 48), "Split half · ON" if split_mode else "Split half · OFF", "split", split_mode)
	f.pager(Rect2(1002, 552, 198, 48), tray_page, slots.size(), 18, "tray")
	f.section_nav("craft")

func can_stage(id: String) -> bool:
	return game.state.can_craft(id, game.near_camp(), at_bench())

func recipe_reason(id: String) -> String:
	var recipe: Dictionary = Catalog.RECIPES.get(id, {})
	if str(recipe.get("station", "field")) == "bench" and not at_bench():
		return "Requires a crafting table · 3 × 3"
	if str(recipe.get("station", "field")) == "camp" and not game.near_camp():
		return "Requires a lit campfire"
	var output := str(recipe.get("output", id))
	if game.state.unlocked.has(output) or game.state.upgrades.has(output):
		return "Already assembled"
	return "Ready to craft" if can_stage(id) else "Need materials or satchel space"

func can_quick_craft(id: String, amount: int = 1) -> bool:
	if amount < 1 or amount > 5 or not Catalog.RECIPES.has(id) or not can_stage(id): return false
	if amount == 1: return true
	var preview = State.new()
	preview.items = game.state.items.duplicate(true)
	preview.unlocked = game.state.unlocked.duplicate(true)
	preview.upgrades = game.state.upgrades.duplicate(true)
	preview._slots = game.state.inventory_slots()
	for index in range(amount):
		if not preview.craft_recipe(id, game.near_camp(), at_bench()): return false
	return true

func draw_pattern_details(pos: Vector2, width: float) -> void:
	var id := str(f.selected_recipe)
	if id.is_empty():
		return
	var recipe: Dictionary = Catalog.RECIPES.get(id, {})
	var output := str(recipe.get("output", id))
	f.schematic(pos + Vector2(30, 24), output, 0.6, PAPER)
	f.fitted_label(pos + Vector2(70, 0), Catalog.recipe_name(id), width - 70, 22, PAPER, true)
	var repeatable := repeatable_recipe(id)
	var batches := batch_count() if repeatable else 1
	var preview_batches := maxi(1, batches)
	var size_value := int(recipe.get("size", 2))
	var cells: Array = Catalog.recipe_grid(id, size_value)
	var origin := pos + Vector2(0, 58)
	for i in range(size_value * size_value):
		var cell: Dictionary = cells[i] if i < cells.size() else {}
		square(Rect2(origin + Vector2((i % size_value) * 24, (i / size_value) * 24), Vector2(22, 22)), cell, "", false, 0, not can_stage(id), false)
	var y := pos.y + 56
	for item in recipe.get("needs", {}):
		var needed := int(recipe.needs[item]) * preview_batches
		var owned := int(game.state.items.get(item, 0))
		f.fitted_label(Vector2(pos.x + 100, y), "%s  %d / %d" % [Catalog.item_name(str(item)), owned, needed], width - 100, 13, CYAN if owned >= needed else RED)
		y += 25
	var total := int(recipe.get("amount", 1)) * preview_batches
	f.fitted_label(pos + Vector2(0, 136), "OUTPUT  %d × %s%s" % [total, Catalog.item_name(output), " / %d batch%s" % [preview_batches, "es" if preview_batches != 1 else ""] if repeatable else ""], width, 14, CYAN)
	f.fitted_label(pos + Vector2(0, 159), "Enter 1–5 batches" if repeatable and batches == 0 else recipe_reason(id), width, 12, FAINT if can_stage(id) else GOLD)
	if repeatable:
		f.label(pos + Vector2(0, 190), "Batches", 14, PAPER)
		f.action(Rect2(978, 404, 222, 44), "Make %d" % total if batches > 0 else "Enter 1–5", "craft_batch", true, batches > 0 and can_quick_craft(id, batches))
		f.action(Rect2(pos + Vector2(0, 226), Vector2(178, 44)), "Craft 1", "quick_craft:" + id + ":1", false, can_quick_craft(id))
		f.action(Rect2(pos + Vector2(190, 226), Vector2(width - 190, 44)), "Craft 5", "quick_craft:" + id + ":5", false, can_quick_craft(id, 5))
	else:
		f.action(Rect2(pos + Vector2(0, 197), Vector2(width, 48)), "Craft", "quick_craft:" + id + ":1", true, can_quick_craft(id))

func move_stack(from: int, to: int) -> bool:
	if not game.state.has_method("move_stack") or from == to:
		return false
	if split_mode:
		var raw := raw_slots()
		var shown := display_slots()
		if from < 0 or from >= raw.size() or raw[from] != shown[from]:
			return false
	var moved: bool = game.state.move_stack(from, to, split_mode)
	if moved:
		selected_slot = -1
		game.state.save_game()
	return moved

func activate_slot(index: int) -> void:
	var slots := display_slots()
	if index < 0 or index >= slots.size():
		return
	if selected_slot >= 0 and selected_slot != index:
		if move_stack(selected_slot, index):
			return
	var cell: Dictionary = slots[index]
	if not cell.is_empty():
		selected_slot = index if selected_slot != index else -1
		f.selected_item = str(cell.item)

func handle(tag: String) -> bool:
	var args := tag.split(":")
	if args.size() > 1:
		match args[0]:
			"quick_craft":
				selected_slot = -1
				if args.size() == 3 and game.has_method("quick_craft"): game.quick_craft(args[1], int(args[2]))
			"slot": activate_slot(int(args[1]))
			"hotbar":
				if game.has_method("activate_hotbar"):
					game.activate_hotbar(int(args[1]))
				var index := int(args[1])
				var slots := display_slots()
				if index == int(game.state.get("selected_hotbar")) and index >= 0 and index < slots.size():
					f.selected_item = str(slots[index].get("item", ""))
					selected_slot = -1
			"grid":
				selected_slot = -1
				var index := int(args[1])
				if remove_mode and game.has_method("grid_remove"):
					game.grid_remove(index)
				elif game.has_method("grid_place") and not str(f.selected_item).is_empty() and int(game.state.items.get(f.selected_item, 0)) > 0:
					game.grid_place(index, str(f.selected_item), 1)
				elif game.has_method("grid_remove"):
					game.grid_remove(index)
			"recipe":
				f.selected_recipe = args[1]
				selected_slot = -1
				if game.has_method("stage_recipe"):
					game.stage_recipe(args[1])
			"page":
				if args[1] != "tray":
					return false
				tray_page += int(args[2])
			_: return false
		return true
	match tag:
		"craft_batch":
			selected_slot = -1
			cancel_input()
			var id := str(f.selected_recipe)
			var batches := batch_count()
			if repeatable_recipe(id) and batches > 0 and game.has_method("quick_craft"):
				game.quick_craft(id, batches)
		"split": split_mode = not split_mode; selected_slot = -1
		"grid_remove_mode": remove_mode = not remove_mode; selected_slot = -1
		"grid_clear":
			selected_slot = -1
			if game.has_method("clear_craft_grid"):
				game.clear_craft_grid()
		"craft_output":
			selected_slot = -1
			if game.has_method("craft_current"):
				game.craft_current()
		"place_workbench":
			if game.has_method("place_workbench"):
				game.place_workbench()
		_: return false
	return true
