extends RefCounted

const Catalog = preload("res://scripts/crafting.gd")
const Workshop = preload("res://scripts/workshop_ui.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
const Locations = preload("res://scripts/locations.gd")
const Art = preload("res://scripts/lantern_ledger_art.gd")
const DialoguePortrait = preload("res://scripts/dialogue_portrait.gd")
var workshop = Workshop.new()
var dialogue_portrait
const PAPER := Art.PAPER
const DARK := Art.NIGHT
const SLATE := Color("#233c40")
const GOLD := Color("#d9bd7b")
const FAINT := Color("#bdc9bf")
const RED := Art.RED
const CYAN := Color("#91cdbb")
var paper_surface := false
var category := "all"
var selected_recipe := ""
var recipe_page := 0
var inventory_page := 0
var trade_page := 0
var journal_page := 0
var journal_tab := "routes"
var inventory_tab := "supplies"
var selected_item := ""
var trade_buy := true
var h
var game

func setup(hud) -> void:
	h = hud
	game = hud.game
	workshop.setup(self)
	dialogue_portrait = DialoguePortrait.new()
	dialogue_portrait.name = "DialoguePortrait"
	hud.add_child(dialogue_portrait)

func label(pos: Vector2, text: String, size_value := 17, color := PAPER, serif := false) -> void:
	h.txt(pos, text, size_value, text_color(color), serif)

func center(pos: Vector2, text: String, size_value := 17, color := PAPER, serif := false) -> void:
	h.centered(pos, text, size_value, text_color(color), serif)

func text_color(color: Color) -> Color:
	if paper_surface:
		if color == PAPER: return Art.INK
		if color == FAINT: return Art.MUTED
		if color == GOLD: return Art.BRASS
		if color == CYAN: return Color("#236c62")
	return color

func paragraph(pos: Vector2, text: String, width: float, size_value := 18, color := FAINT) -> float:
	return h.paragraph(pos, text, width, size_value, text_color(color))

func fit_text(text: String, width: float, size_value := 17, serif := false) -> String:
	var face: Font = Art.font(serif)
	var result := text
	while face.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > width and result.length() > 1:
		result = result.left(result.length() - 2) + "…"
	return result

func fitted_label(pos: Vector2, text: String, width: float, size_value := 17, color := PAPER, serif := false) -> void:
	label(pos, fit_text(text, width, size_value, serif), size_value, color, serif)

func begin_surface(paper := true) -> bool:
	paper_surface = paper

	var previous = h.get("paper_context")
	if previous != null: h.set("paper_context", false)
	return bool(previous)

func end_surface(previous: bool) -> void:
	if h.get("paper_context") != null: h.set("paper_context", previous)

func action(rect: Rect2, text: String, tag: String, active := false, enabled := true) -> void:
	var hover: bool = rect.has_point(h.mouse_pos - h.drawing_offset)
	Art.draw_button(h, rect, active and enabled, 1.0 if hover and enabled else 0.0)
	if not enabled: h.draw_rect(rect.grow(-2), Color(Art.PAPER, 0.4))
	var size_value := 17
	while Art.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > rect.size.x - 20 and size_value > 12:
		size_value -= 1
	h.centered(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - size_value * 0.56), fit_text(text, rect.size.x - 16, size_value), size_value, (Art.PAPER if active else Art.INK) if enabled else Art.MUTED)
	if enabled:
		h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": tag, "mode": game.mode})

func sheet(title: String, subtitle: String) -> void:
	paper_surface = true
	Art.draw_frame(h, Rect2(20, 16, 1240, 686))
	h.centered(Vector2(640, 38), fit_text(title, 530, 27, true), 27, Art.PAPER, true)
	label(Vector2(80, 112), subtitle, 13, Art.MUTED)
	action(Rect2(1076, 65, 124, 52), "×  Close", "play")
	h.draw_line(Vector2(80, 143), Vector2(1200, 143), Color(Art.BRASS, 0.26), 1, true)

func section_nav(active: String, compact := false) -> void:
	var start := Vector2(720, 603) if compact else Vector2(80, 614)
	var width := 494.0 if compact else 1120.0
	var tabs := [["bag", "Satchel"], ["craft", "Craft"], ["journal", "Journal"]]
	var gap := 8.0 if compact else 12.0
	var each := (width - gap * 2) / 3.0
	for i in range(3):
		action(Rect2(start + Vector2(i * (each + gap), 0), Vector2(each, 48)), tabs[i][1], tabs[i][0], active == tabs[i][0])

func draw(mode: String) -> void:
	var previous := begin_surface(mode not in ["camp", "rest", "sleep"])
	match mode:
		"craft": draw_craft()
		"trade": draw_trade()
		"dialogue": draw_dialogue()
		"resource": draw_resource()
		"camp", "rest", "sleep": draw_camp(mode)
		"journal": draw_journal()
	end_surface(previous)

func recipes() -> Array:
	return Catalog.recipe_ids("" if category == "all" else category)

func draw_craft() -> void:
	workshop.draw_craft()

func schematic(pos: Vector2, kind: String, scale_value: float, color: Color) -> void:
	var picture = Art.item_texture(kind)
	if picture == null: picture = ItemIcons.texture(kind)
	if picture == null or scale_value <= 0: return
	var size_value = Vector2.ONE * 88.0 * scale_value

	Art.draw_fitted(h, picture, Rect2(pos - size_value * 0.5, size_value), Color(1, 1, 1, color.a))

func pager(rect: Rect2, page: int, count: int, per_page: int, tag: String) -> void:
	var pages := maxi(1, ceili(float(count) / per_page))
	action(Rect2(rect.position, Vector2(56, rect.size.y)), "‹", "page:" + tag + ":-1", false, page > 0)
	center(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - 10), "%02d / %02d" % [page + 1, pages], 15, FAINT)
	action(Rect2(rect.position + Vector2(rect.size.x - 56, 0), Vector2(56, rect.size.y)), "›", "page:" + tag + ":1", false, page < pages - 1)

func inventory_ids() -> Array:
	if inventory_tab == "gear":
		var gear: Array = ["fists"]
		for id in game.state.unlocked:
			if id != "fists" and Catalog.WEAPONS.has(id): gear.append(id)
		for id in game.state.upgrades:
			gear.append(id)
		return gear
	var ids: Array = []
	for id in game.state.items:
		if int(game.state.items[id]) > 0:
			ids.append(id)
	ids.sort()
	return ids

func draw_inventory() -> void:
	workshop.draw_inventory()

func draw_trade() -> void:
	sheet("THE EXCHANGE", "HONEST GOODS / FAIR LIGHT")
	label(Vector2(80, 187), "YOUR LIGHT ESSENCE", 13, FAINT)
	label(Vector2(77, 207), "%03d" % int(game.state.items.get("shard", 0)), 52, CYAN, true)
	action(Rect2(80, 294, 145, 52), "Buy", "trade_side:buy", trade_buy)
	action(Rect2(237, 294, 145, 52), "Sell", "trade_side:sell", not trade_buy)
	schematic(Vector2(228, 433), "shard", 1.45, GOLD)
	paragraph(Vector2(80, 517), "One item. One fair price.\nGoods go straight into your satchel.", 302, 16, FAINT)

	action(Rect2(80, 610, 302, 48), "‹  Conversation", "dialogue")
	var ids: Array = Catalog.SHOPS.get(game.shop_id, []) if trade_buy else game.state.items.keys()
	if not trade_buy:
		ids = ids.filter(func (id): return Catalog.ITEMS.has(id) and int(game.state.items.get(id, 0)) > 0 and int(Catalog.ITEMS[id].get("sell", 0)) > 0)
	trade_page = clampi(trade_page, 0, maxi(0, (ids.size() - 1) / 6))
	label(Vector2(494, 177), "GOODS", 13, FAINT)
	label(Vector2(899, 177), "OWNED", 13, FAINT)
	label(Vector2(1051, 177), "LIGHT ESSENCE", 13, FAINT)
	for i in range(trade_page * 6, mini(ids.size(), trade_page * 6 + 6)):
		var id := str(ids[i])
		var y := 212 + i % 6 * 61
		var price := int(Catalog.ITEMS[id].get("buy" if trade_buy else "sell", 0))
		schematic(Vector2(459, y + 23), id, 0.36, PAPER)
		fitted_label(Vector2(494, y + 11), Catalog.item_name(id), 402, 20)
		label(Vector2(922, y + 12), str(int(game.state.items.get(id, 0))), 18, CYAN)
		var enabled: bool = price > 0 and (int(game.state.items.get("shard", 0)) >= price if trade_buy else int(game.state.items.get(id, 0)) > 0)
		action(Rect2(1022, y, 178, 50), ("Buy · " if trade_buy else "Sell · ") + str(price), ("buy:" if trade_buy else "sell:") + id, false, enabled)
		h.draw_line(Vector2(438, y + 57), Vector2(1200, y + 57), Color(Art.BRASS, 0.25), 1)
	if ids.is_empty():
		label(Vector2(494, 309), "Nothing to trade yet.", 24, FAINT)
	pager(Rect2(438, 610, 762, 48), trade_page, ids.size(), 6, "trade")

func dialogue_layout(request := false) -> Dictionary:
	return {
		"panel": Rect2(56, 218 if request else 324, 1168, 462 if request else 356),
		"portrait": Rect2(80, 242 if request else 346, 218, 312 if request else 264),
		"name": Vector2(326, 242 if request else 350),
		"speech": Rect2(326, 300 if request else 420, 864, 76 if request else 132),
		"actions": Rect2(326, 606, 864, 54)
	}

func portrait(rect: Rect2) -> void:
	var card := Rect2(rect.position, rect.size + Vector2(0, 42))
	h.draw_rect(card, Art.NIGHT)
	h.draw_rect(card.grow(-4), Color(Art.BRASS, 0.7), false, 1)
	h.draw_circle(rect.get_center() - Vector2(0, rect.size.y * 0.12), rect.size.x * 0.42, Color("#344c49"))
	var picture: Texture2D = dialogue_portrait.texture_for(game.vendor)
	if picture != null: Art.draw_fitted(h, picture, rect.grow(-6))
	var role := "FRONTIER NEIGHBOR"
	if is_instance_valid(game.vendor):
		var race := str(game.vendor.get_meta("race", ""))
		var vocation = game.vendor.get("role")
		role = (race + " / " + str(vocation if vocation != null else "neighbor")).to_upper()

	h.centered(Vector2(card.get_center().x, rect.end.y + 10), fit_text(role, card.size.x - 18, 12), 12, Art.PAPER)

func dialogue_header(layout: Dictionary, request := false) -> void:
	var panel_rect: Rect2 = layout.panel
	h.panel(panel_rect, Art.PAPER, Art.BRASS, 5)
	h.draw_rect(Rect2(panel_rect.position, Vector2(7, panel_rect.size.y)), Art.RED)
	portrait(layout.portrait)
	fitted_label(layout.name, game.dialogue_name, 728, 30, RED, true)
	label(layout.name + Vector2(0, 38), "A REQUEST FROM THE FRONTIER" if request else "IN CONVERSATION", 11, FAINT)
	action(Rect2(1074, panel_rect.position.y + 16, 116, 48), "×  Close", "play")
	if not request: h.draw_line(Vector2(326, 591), Vector2(1190, 591), Color(Art.BRASS, 0.3), 1)

func draw_dialogue() -> void:
	var board = game.get("quests")
	var request: Dictionary = {}
	if board != null and is_instance_valid(game.vendor): request = board.offer_for(str(game.vendor.get_meta("id", "")))
	if not request.is_empty():
		draw_request_dialogue(request)
		return

	paper_surface = true
	var layout := dialogue_layout()
	dialogue_header(layout)
	if game.dialogue_index < game.dialogue_lines.size():
		paragraph(layout.speech.position, str(game.dialogue_lines[game.dialogue_index]), layout.speech.size.x, 24, PAPER)
	label(Vector2(326, 563), "LINE %02d / %02d" % [game.dialogue_index + 1, maxi(1, game.dialogue_lines.size())], 12, FAINT)
	action(Rect2(326, 606, 260, 54), "Continue", "dialogue_next", true)
	if game.shop_id != "": action(Rect2(600, 606, 260, 54), "Trade", "trade")
	action(Rect2(874, 606, 316, 54), "Farewell", "play")

func draw_request_dialogue(request: Dictionary) -> void:
	paper_surface = true
	var layout := dialogue_layout(true)
	dialogue_header(layout, true)
	if game.dialogue_index < game.dialogue_lines.size():
		paragraph(layout.speech.position, str(game.dialogue_lines[game.dialogue_index]), layout.speech.size.x, 19, FAINT)
	h.draw_line(Vector2(326, 380), Vector2(1190, 380), Color(Art.BRASS, 0.2), 1)
	fitted_label(Vector2(326, 394), str(request.name), 864, 24, PAPER, true)
	var body_bottom := paragraph(Vector2(326, 435), str(request.text), 864, 19, PAPER)


	var objective_y := maxf(535.0, body_bottom + 4.0)
	var reward_y := maxf(566.0, objective_y + 28.0)
	var separator_y := maxf(591.0, reward_y + 21.0)
	fitted_label(Vector2(326, objective_y), str(request.objective), 864, 16, CYAN if request.ready else GOLD)
	fitted_label(Vector2(326, reward_y), "REWARD  " + str(request.reward_text), 864, 14, FAINT)
	h.draw_line(Vector2(326, separator_y), Vector2(1190, separator_y), Color(Art.BRASS, 0.3), 1)
	action(Rect2(326, 606, 160, 54), "Next line", "dialogue_next")
	var tag := "quest_claim:" if request.ready else "quest_accept:"
	action(Rect2(498, 606, 250, 54), "Return & claim" if request.ready else ("In progress" if request.accepted else "Accept request"), tag + str(request.id), true, not request.accepted or request.ready)
	action(Rect2(760, 606, 196, 54), "Track request", "quest_track:" + str(request.id), game.tracked_location == "quest_" + str(request.id))
	if game.shop_id != "": action(Rect2(968, 606, 108, 54), "Trade", "trade")
	action(Rect2(1088, 606, 102, 54), "Leave", "play")

func draw_resource() -> void:

	sheet("GATHER OR CARRY", "MATERIALS FOR THE ROAD")
	var material := "stone"
	if is_instance_valid(game.resource_node): material = str(game.resource_node.get_meta("material", "stone"))
	schematic(Vector2(292, 382), material, 2.0, PAPER)
	label(Vector2(530, 238), Catalog.item_name(material).to_upper(), 35, PAPER, true)
	paragraph(Vector2(530, 300), "In the world, tap B to collect a loose object. Hold B to lift it. While carrying, tap B to throw or hold B to put it down.", 616, 23, FAINT)
	action(Rect2(530, 472, 310, 60), "Gather", "resource:gather", true)
	action(Rect2(856, 472, 310, 60), "Lift & carry", "resource:lift")

func draw_camp(mode: String) -> void:
	paper_surface = false
	if mode in ["rest", "sleep"]:
		Art.draw_frame(h, Rect2(906, 470 if mode == "rest" else 426, 338, 216 if mode == "rest" else 260), true)
		label(Vector2(928, 490 if mode == "rest" else 447), "TAKE YOUR TIME" if mode == "rest" else "RESTING UNTIL MORNING", 12, GOLD)
		label(Vector2(928, 516 if mode == "rest" else 473), "By the embers" if mode == "rest" else "A softer adventure", 25, PAPER, true)
		paragraph(Vector2(928, 560 if mode == "rest" else 519), "A warm kettle. A quiet world. A little light of your own." if mode == "rest" else "Settling in. Recovery follows a complete rest.", 294, 15, FAINT)
		if mode == "sleep":
			var remaining = game.get("sleep_left")
			var progress := clampf(1.0 - float(remaining if remaining != null else 5.2) / 5.2, 0, 1)
			h.draw_rect(Rect2(928, 588, 294, 6), Color(PAPER, 0.18))
			h.draw_rect(Rect2(928, 588, 294 * progress, 6), CYAN)
		action(Rect2(922, 620, 304, 48), "Rise & continue", "camp:leave", true)
		h.panel(Rect2(36, 648, 310, 38), Color(DARK, 0.91), Color(Art.SILVER, 0.24), 2)
		label(Vector2(49, 657), "Drag to look around · pinch to zoom", 14, FAINT)
		return

	Art.draw_frame(h, Rect2(792, 68, 452, 580), true)
	center(Vector2(1004, 102), "A fire for the night", 28, PAPER, true)
	center(Vector2(1018, 143), "Kettle on. Boots off. Stars above.", 14, FAINT)
	action(Rect2(1180, 82, 48, 44), "×", "play")
	var rows := [["Brew coffee", "coffee", "2 beans · restores 1 health", "coffee"], ["Roast marshmallow", "roast", "1 marshmallow · restores health", "roasted_marshmallow"], ["Make a s'more", "smore", "Mallow + chocolate + graham · heals 3", "smore"], ["Sit by the fire", "sit", "A little time to mend", ""], ["Sleep until morning", "sleep", "Rest, recover & save", ""]]
	for i in range(rows.size()):
		var y := 187 + i * 66
		var rect := Rect2(816, y, 404, 60)
		var hover: bool = rect.has_point(h.mouse_pos - h.drawing_offset)
		h.draw_rect(rect, Color(Art.SILVER, 0.07 if hover else 0.025))
		h.draw_line(Vector2(816, y + 62), Vector2(1220, y + 62), Color(Art.BRASS, 0.35), 1)
		if rows[i][3] != "": schematic(Vector2(845, y + 32), rows[i][3], 0.55, PAPER)
		elif rows[i][1] == "sit": h.flame(Vector2(845, y + 31), 21, GOLD)
		else:
			h.draw_arc(Vector2(845, y + 32), 15, 0.5, 5.8, 24, GOLD, 1.5, true)
			h.draw_line(Vector2(840, y + 23), Vector2(848, y + 32), GOLD, 1.5, true)
		fitted_label(Vector2(880, y + 6), rows[i][0], 302, 22, PAPER, true)
		fitted_label(Vector2(880, y + 38), rows[i][2], 302, 13, FAINT)
		label(Vector2(1203, y + 22), "›", 19, GOLD)
		h.buttons.append({"rect": Rect2(rect.position + h.drawing_offset, rect.size), "tag": "camp:" + str(rows[i][1]), "mode": game.mode})
	action(Rect2(816, 549, 104, 48), "Craft", "craft")
	action(Rect2(932, 549, 160, 48), "Pack camp", "camp:pack")
	action(Rect2(1104, 549, 116, 48), "Leave", "camp:leave")

func draw_journal() -> void:
	sheet("THE ROAD JOURNAL", "CHART THE FRONTIER / ROUTES & REQUESTS")
	label(Vector2(80, 184), "THE NEXT CHAPTER", 14, RED)
	paragraph(Vector2(80, 217), "Seven regions. Ten towns. Follow the roads, discover capitals and return here for free travel." if game.state.expanded_world else "Take the long road. Explore its hidden depths. Complete expeditions for supplies, ancient cores and rare gear.", 302, 20, PAPER)
	action(Rect2(444, 137, 180, 44), "Destinations", "journal_view:routes", journal_tab == "routes")
	action(Rect2(636, 137, 180, 44), "Quests", "journal_view:quests", journal_tab == "quests", game.get("quests") != null)
	action(Rect2(828, 137, 180, 44), "Expeditions", "journal_view:expeditions", journal_tab == "expeditions", game.get("expeditions") != null)
	var interior: String = game.world.interior_at(game.player.position)
	action(Rect2(1020, 137, 180, 44), "Local map" if interior != "" and game.state.expanded_world else "World map" if game.state.expanded_world else "Delve map", "journal_view:map", journal_tab == "map", interior != "" or game.state.expanded_world)
	var origin := Vector2(228, 438)
	h.draw_arc(origin, 65, 0, TAU, 64, Color(Art.BRASS, 0.65), 2, true)
	for i in range(8):
		var v := Vector2.from_angle(i * TAU / 8)
		h.draw_line(origin + v * 55, origin + v * (80 if i % 2 == 0 else 68), GOLD, 2, true)
	h.draw_colored_polygon(PackedVector2Array([origin + Vector2(0, -51), origin + Vector2(-14, 17), origin, origin + Vector2(14, 17)]), RED)
	center(origin + Vector2(0, -101), "N", 18, PAPER, true)
	label(Vector2(80, 552), "ONE WORLD · SEVEN REGIONS", 14, FAINT)
	label(Vector2(80, 577), "%d MINUTES WANDERED" % int(game.state.journey_time / 60), 13, FAINT)
	if journal_tab == "map" and game.state.expanded_world:
		draw_atlas_map(); section_nav("journal"); return
	if journal_tab == "quests" and game.get("quests") != null:
		draw_quests()
		section_nav("journal")
		return
	if journal_tab == "map" and interior != "":
		draw_delve_map(interior)
		section_nav("journal")
		return
	if journal_tab == "expeditions" and game.get("expeditions") != null:
		draw_expeditions()
		section_nav("journal")
		return
	var destinations: Array = game.navigation_routes() if game.has_method("navigation_routes") else game.world.get_locations().duplicate()
	journal_page = clampi(journal_page, 0, maxi(0, (destinations.size() - 1) / 5))
	for i in range(journal_page * 5, mini(destinations.size(), journal_page * 5 + 5)):
		var land: Dictionary = destinations[i]
		var y := 191 + i % 5 * 73
		var p: Vector2 = land.pos
		var distance := p.distance_to(Vector2(game.player.position.x, game.player.position.z))
		fitted_label(Vector2(444, y), str(land.name), 410 if game.state.expanded_world else 570, 22, PAPER, true)
		label(Vector2(445, y + 35), "%s / %d m" % [str(land.get("kind", "landmark")).capitalize(), int(distance)], 14, FAINT)
		action(Rect2(1036, y + 5, 164, 52), "Tracked" if game.tracked_location == land.id else "Track route", "track:" + str(land.id), game.tracked_location == land.id)
		if game.state.expanded_world and land.kind == "city":
			var reason = game.atlas_travel_reason(str(land.id))
			action(Rect2(854, y + 5, 170, 52), "Travel" if reason.is_empty() else reason, "atlas_travel:" + str(land.id), false, reason.is_empty())
		h.draw_line(Vector2(444, y + 66), Vector2(1200, y + 66), Color(Art.BRASS, 0.25), 1)
	pager(Rect2(444, 560, 756, 44), journal_page, destinations.size(), 5, "journal")
	section_nav("journal")

func draw_atlas_map() -> void:
	var interior: String = game.world.interior_at(game.player.position)
	if interior in ["mine", "dungeon"]: draw_delve_map(interior); return
	if game.world.regional != null and not game.world.regional.active_id.is_empty() and game.world.regional.active_id not in ["mine", "dungeon"]:
		draw_regional_map(); return
	if game.world.mosswake != null and not game.world.mosswake.active_id.is_empty():
		draw_mosswake_map()
		return
	var atlas = game.world.atlas
	var area = Rect2(449, 196, 740, 348)
	h.draw_rect(area, Color("#d7ccb2"))
	var left = atlas.point(Vector2(70, 150)); var extent = Vector2(1560, 960) * atlas.SCALE
	var scale_value = minf(area.size.x / extent.x, area.size.y / extent.y)
	var offset = area.get_center() - extent * scale_value * 0.5
	for region in atlas.regions:
		var polygon = PackedVector2Array()
		for p in region.polygon: polygon.append(offset + (p - left) * scale_value)
		h.draw_colored_polygon(polygon, Color(atlas.COLORS[region.id - 9]).lightened(0.23))
		h.draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color(Art.PAPER, 0.8), 1.5, true)
	for road in atlas.roads(): h.draw_line(offset + (road.a - left) * scale_value, offset + (road.b - left) * scale_value, Color("#775841"), 1.1, true)
	for site in game.world.RegionSites.catalog():
		var gate: Vector3
		if site.get("alias", "") in ["rootglow", "cedarwatch"]: gate = game.world.MosswakeLayouts.gate_point(atlas, site.alias)
		else: gate = game.world.RegionSites.gate_point(atlas, site.id)
		var at = offset + (Vector2(gate.x, gate.z) - left) * scale_value
		h.draw_circle(at, 1.7, Color("#527566" if site.kind == "cave" else "#776080"))
	for site in atlas.sites():
		var at = offset + (site.pos - left) * scale_value
		h.draw_circle(at, 4 if site.kind == "city" else 2.5, Art.RED)
		if site.kind == "city": label(at + Vector2(5, -14), site.name, 10, Art.INK)
	var player = offset + (Vector2(game.player.position.x, game.player.position.z) - left) * scale_value
	h.draw_circle(player, 5, Art.PAPER); h.draw_circle(player, 3, Art.RED)
	label(Vector2(449, 562), "5 CAPITALS  /  10 TOWNS  /  CONNECTING ROADS & WILDERNESS TRAILS", 12, Art.MUTED)
	paragraph(Vector2(449, 584), "52 natural caves · 40 built sites · 33 sky islands. Green marks caves; violet marks built sites. Visit capitals for free travel.", 736, 14, Art.INK)

func draw_mosswake_map() -> void:
	var L = game.world.MosswakeLayouts
	var id: String = game.world.mosswake.active_id
	var area = Rect2(449, 196, 740, 348)
	h.draw_rect(area, Color("#d7ccb2"))
	var cells: Dictionary = L.cells(id)
	var bounds = Rect2(Vector2(cells.keys()[0]) * L.STEP, Vector2.ONE * L.STEP)
	for cell in cells: bounds = bounds.expand(Vector2(cell) * L.STEP).expand((Vector2(cell) + Vector2.ONE) * L.STEP)
	var factor = minf((area.size.x - 40) / bounds.size.x, (area.size.y - 40) / bounds.size.y)
	var offset = area.get_center() - bounds.get_center() * factor
	for cell in cells:
		var p = Vector2(cell) * L.STEP
		var color = Color("#628267" if id == "rootglow" else "#8d8068")
		if L.floor_height(id, p) < -1.2: color = color.lightened(0.22)
		h.draw_rect(Rect2(offset + p * factor, Vector2.ONE * (L.STEP * factor - 0.3)), color)
	for room in L.rooms(id):
		if room.name not in ["Root mouth", "Fungal pocket", "Low return", "Triangular court", "Barracks", "Lower armory"]: continue
		var p: Vector2 = offset + room.p * factor
		h.draw_circle(p, 3, Art.BRASS); label(p + Vector2(6, -9), room.name, 11, Art.INK)
	var local: Vector3 = game.player.position - L.ORIGINS[id]
	var at = offset + Vector2(local.x, local.z) * factor
	h.draw_circle(at, 5, Art.PAPER); h.draw_circle(at, 3, Art.RED)
	label(Vector2(449, 562), str(L.NAMES[id]).to_upper() + "  /  LOCAL EXPLORATION MAP", 12, Art.MUTED)
	paragraph(Vector2(449, 584), "Red marks your position. Pale areas lie lower. Follow the surface-return signs to leave.", 736, 14, Art.INK)

func draw_regional_map() -> void:
	var S = game.world.RegionSites; var id: String = game.world.regional.active_id
	var area = Rect2(449, 196, 740, 348); h.draw_rect(area, Color("#d7ccb2"))
	var cells: Dictionary = S.cells(id); var bounds = Rect2(Vector2(cells.keys()[0]) * S.STEP, Vector2.ONE * S.STEP)
	for cell in cells: bounds = bounds.expand(Vector2(cell) * S.STEP).expand((Vector2(cell) + Vector2.ONE) * S.STEP)
	var factor = minf((area.size.x - 40) / bounds.size.x, (area.size.y - 40) / bounds.size.y); var offset = area.get_center() - bounds.get_center() * factor
	for cell in cells: h.draw_rect(Rect2(offset + Vector2(cell) * S.STEP * factor, Vector2.ONE * (S.STEP * factor - 0.25)), Color("#74877c" if S.site(id).kind == "cave" else "#8a7f91"))
	var local: Vector3 = game.player.position - S.origin(id); var at = offset + Vector2(local.x, local.z) * factor
	h.draw_circle(at, 5, Art.PAPER); h.draw_circle(at, 3, Art.RED)
	var level = clampi(roundi(local.y / 7.5) + 2, 0, 6)
	label(Vector2(449, 562), str(S.site(id).name).to_upper() + ((" / LEVEL " + str(level - 2)) if S.layout(id).castle else " / LOCAL MAP"), 12, Art.MUTED)
	paragraph(Vector2(449, 584), "Red marks your position. Follow the surface-return sign to leave." + (" The eastern stair gallery connects all seven floors." if S.layout(id).castle else ""), 736, 14, Art.INK)

func draw_quests() -> void:
	var requests: Array = game.quests.entries()
	journal_page = clampi(journal_page, 0, maxi(0, (requests.size() - 1) / 3))
	for i in range(journal_page * 3, mini(requests.size(), journal_page * 3 + 3)):
		var request: Dictionary = requests[i]
		var y := 195 + (i % 3) * 117
		var tint := CYAN if request.completed or request.ready else (RED if request.accepted else GOLD)
		h.draw_rect(Rect2(444, y, 5, 102), tint)
		fitted_label(Vector2(464, y), str(request.name), 716, 20, PAPER, true)
		fitted_label(Vector2(465, y + 29), str(request.owner) + "  /  " + str(request.status).to_upper(), 716, 12, tint)
		paragraph(Vector2(465, y + 52), str(request.objective), 500, 14, FAINT)
		fitted_label(Vector2(465, y + 86), str(request.reward_text), 515, 12, GOLD)
		if not request.completed:
			action(Rect2(1000, y + 46, 200, 48), "Track owner" if not request.accepted or request.ready else "Track objective", "quest_track:" + str(request.id), game.tracked_location == "quest_" + str(request.id), request.available)
		else: label(Vector2(1038, y + 63), "RETURNED", 14, CYAN)
	pager(Rect2(444, 560, 756, 44), journal_page, requests.size(), 3, "journal")

func draw_expeditions() -> void:
	var goals: Array = game.expeditions.entries()
	journal_page = clampi(journal_page, 0, maxi(0, (goals.size() - 1) / 3))
	for i in range(journal_page * 3, mini(goals.size(), journal_page * 3 + 3)):
		var entry: Dictionary = goals[i]
		var y := 195 + (i % 3) * 117
		var complete := bool(entry.completed)
		h.draw_rect(Rect2(444, y, 5, 100), CYAN if complete else RED)
		fitted_label(Vector2(464, y), str(entry.name), 720, 21, CYAN if complete else PAPER, true)
		label(Vector2(465, y + 30), "COMPLETE" if complete else "%d / %d" % [entry.progress, entry.goal], 13, CYAN if complete else GOLD)
		paragraph(Vector2(465, y + 52), str(entry.text), 506, 15, FAINT)
		label(Vector2(1005, y + 31), "EARNED" if complete else "REWARD", 10, FAINT)
		paragraph(Vector2(1005, y + 48), str(entry.reward_text), 190, 13, CYAN if complete else GOLD)
		if str(entry.route) != "" and not complete:
			action(Rect2(1010, y + 70, 190, 44), "Track expedition", "track:" + str(entry.route), game.tracked_location == str(entry.route))
	pager(Rect2(444, 560, 756, 44), journal_page, goals.size(), 3, "journal")

func draw_delve_map(interior: String) -> void:
	var layout: Dictionary = Locations.deep_layout(interior, game.state.seed_value)
	var bounds := Rect2()
	var centers: Dictionary = {}
	for room in layout.rooms:
		var rect := Rect2(room.p - room.size * 0.5, room.size)
		bounds = rect if centers.is_empty() else bounds.merge(rect)
		centers[room.id] = room.p
	var area := Rect2(458, 198, 728, 330)
	Art.draw_frame(h, area.grow(10), true)
	var was_paper := paper_surface
	paper_surface = false
	var map_scale := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var origin := area.get_center() - bounds.get_center() * map_scale
	for link in layout.links:
		h.draw_line(origin + centers[link[0]] * map_scale, origin + centers[link[1]] * map_scale, Color(GOLD, 0.5), 5, true)
	for room in layout.rooms:
		var visited: bool = game.state.taken.get("visited_" + interior + "_" + str(room.id), false)
		var rect := Rect2(origin + (room.p - room.size * 0.5) * map_scale, room.size * map_scale)
		h.panel(rect, Color("#34433f") if visited else SLATE, CYAN if visited else Color(PAPER, 0.22), 1)
		center(rect.get_center() - Vector2(0, 7), str(room.id).capitalize() if visited else "?", 11, PAPER if visited else FAINT)
	var local: Vector3 = game.player.position - Locations.INTERIORS[interior]
	var point := origin + Vector2(local.x, local.z) * map_scale
	h.draw_circle(point, 7, RED)
	h.draw_arc(point, 10, 0, TAU, 32, PAPER, 1.5, true)
	paper_surface = was_paper
	label(Vector2(458, 552), "YOU  /  RED        EXPLORED  /  TEAL        UNCHARTED  /  ?", 12, FAINT)
	paragraph(Vector2(458, 577), "Paths join real rooms. Explore branches for seals, ore and hidden treasure.", 720, 15, GOLD)

func handle(tag: String) -> bool:
	if game.get("quests") != null and game.quests.handle(tag): return true
	if workshop.handle(tag):
		return true
	var args := tag.split(":")
	if args.size() > 1:
		match args[0]:
			"atlas_travel": game.request_fast_travel_atlas(args[1])
			"category": category = args[1]; recipe_page = 0; selected_recipe = ""
			"recipe": selected_recipe = args[1]
			"craft": game.craft_recipe(args[1])
			"equip": game.equip_weapon(args[1])
			"supply": game.use_supply(args[1])
			"buy": game.trade_item(args[1], true)
			"sell": game.trade_item(args[1], false)
			"resource": game.choose_resource(args[1])
			"camp": game.camp_command(args[1])
			"track": game.track_location(args[1])
			"ready": game.ready_item(args[1])
			"journal_view": journal_tab = args[1]; journal_page = 0
			"item": selected_item = args[1]
			"inventory": inventory_tab = args[1]; inventory_page = 0; selected_item = ""
			"trade_side": trade_buy = args[1] == "buy"; trade_page = 0
			"page":
				var step := int(args[2])
				match args[1]:
					"recipes": recipe_page += step
					"inventory": inventory_page += step
					"trade": trade_page += step
					"journal": journal_page += step
			_: return false
		return true
	if tag == "dialogue_next": game.advance_dialogue(); return true
	if tag == "place_camp": game.place_camp(); return true
	return false
