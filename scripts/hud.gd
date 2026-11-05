extends Control
var game
const Fieldbook = preload("res://scripts/fieldbook.gd")
const CameraGesture = preload("res://scripts/camera_gesture.gd")
const DevMenu = preload("res://scripts/dev_menu.gd")
const Art = preload("res://scripts/lantern_ledger_art.gd")
const DamageFeedback = preload("res://scripts/ui_damage_feedback.gd")
const VectorCache = preload("res://scripts/ui_vector_cache.gd")
var vector_cache
const HudContext = preload("res://scripts/ui_hud_context.gd")
var damage_feedback = DamageFeedback.new()
var hud_context = HudContext.new()
var paper_context := false
var new_journey_confirmation := false
var _last_ui_mode := ""
var _last_magic_signature := ""
var camera_gesture = CameraGesture.new()
var dev_menu
var fieldbook = Fieldbook.new()
const STICK_RADIUS := 122.0
const STICK_TRAVEL := 98.0
const STICK_THUMB_RADIUS := 34.0
const STICK_CAPTURE_RADIUS := 142.0
var action_fingers: Dictionary = {}
var pending_actions: Dictionary = {}
var menu_pointer: int = -999
var levitation_pointer: int = -999
const LEVITATION_SLIDER := Rect2(1200, 158, 66, 222)
const LEVITATION_TRACK_TOP := 211.0
const LEVITATION_TRACK_BOTTOM := 350.0
const LEVITATION_TRACK_X := 1233.0

const INK = Color("#15191e")
const IVORY = Color("#f7edd8")
const GOLD = Color("#c7b58d")
const MUTED = Color("#b9b3a7")
const SCARLET = Color("#db423c")
const CYAN = Color("#85e1e5")
const SLATE = Color("#262c33")
var title_font: Font = preload("res://assets/fonts/title.ttf")
var body_font: Font = preload("res://assets/fonts/body.ttf")
var buttons: Array = []
var joy_id: int = -1
var camera_id: int = -1
var joy_value: Vector2 = Vector2.ZERO
var joy_center: Vector2 = Vector2(158, 566)
var hold_buttons: Dictionary = {}
var mouse_camera: bool = false
var seed_entry: LineEdit
var mouse_pos: Vector2 = Vector2(-100, -100)
var clock: float = 0.0
var frame_dt: float = 1.0 / 60.0
var hover_values: Dictionary = {}
var press_values: Dictionary = {}
var drawing_offset: Vector2 = Vector2.ZERO
var displayed_health: int = 5
var health_flash: float = 0.0
var magic_ui
const Spellbook = preload("res://scripts/spellbook.gd")

func _ready() -> void:
	vector_cache = VectorCache.new()
	add_child(vector_cache)
	vector_cache.changed.connect(queue_redraw)
	fieldbook.setup(self)
	dev_menu = DevMenu.new()
	dev_menu.setup(self)
	if ResourceLoader.exists("res://scripts/spell_collection_ui.gd"):
		magic_ui = load("res://scripts/spell_collection_ui.gd").new()
		magic_ui.setup(self)
	title_font = Art.font(true)
	body_font = Art.font()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_entry = LineEdit.new()
	seed_entry.position = Vector2(98, 590)
	seed_entry.size = Vector2(392, 48)
	seed_entry.placeholder_text = "The world of Mr. Justice"
	seed_entry.editable = false
	seed_entry.max_length = 9
	seed_entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_entry.add_theme_font_override("font", body_font)
	seed_entry.add_theme_font_size_override("font_size", 16)
	seed_entry.add_theme_color_override("font_color", Art.INK)
	seed_entry.add_theme_color_override("font_placeholder_color", Color(Art.MUTED, 0.85))
	var style = StyleBoxFlat.new()
	style.bg_color = Art.PAPER.lightened(0.05)
	style.set_border_width_all(1)
	style.border_color = Art.BRASS
	style.content_margin_left = 12
	seed_entry.add_theme_stylebox_override("normal", style)
	seed_entry.add_theme_stylebox_override("focus", style)
	add_child(seed_entry)

var _redraw_parity := false
func _process(dt: float) -> void:
	if game == null or game.state == null: return
	if dev_menu != null: dev_menu.tick(dt)
	clock += dt
	frame_dt = dt
	for key in press_values.keys():
		press_values[key] = maxf(0, float(press_values[key]) - dt * 5.0)
	displayed_health = game.state.health
	health_flash = maxf(0, health_flash - dt * 2.5)
	damage_feedback.tick(dt)
	if game.mode in ["menu", "loading"]: damage_feedback.clear()
	if game.mode != _last_ui_mode:
		if game.mode == "play":
			hud_context.reveal_magic()
			hud_context.reveal_quest()
		if game.mode != "menu": new_journey_confirmation = false
		_last_ui_mode = game.mode
	if game.mode == "play" and "settings" in game.state:
		var signature := "%s|%s" % [game.state.active_spell_slot, game.state.equipment] if "active_spell_slot" in game.state else ""
		if signature != _last_magic_signature:
			_last_magic_signature = signature
			hud_context.reveal_magic()
		hud_context.tick(dt, tracked_request(), magic_is_relevant(), bool(game.state.settings.get("contextual_hud", true)), ui_motion_enabled())
	seed_entry.visible = false
	var ratio = get_viewport_rect().size / Vector2(1280, 720)
	seed_entry.position = (Vector2(428, 392) if new_journey_confirmation else Vector2(98, 590)) * ratio
	seed_entry.size = Vector2(424 if new_journey_confirmation else 392, 48)
	seed_entry.scale = ratio
	if magic_ui != null: magic_ui.tick(dt)
	if fieldbook.workshop.has_method("tick"): fieldbook.workshop.tick(dt)
	# The HUD is drawn immediate-mode, which is costly on phones. During gameplay it redraws
	# at half rate (the last drawing persists between redraws), but at full rate whenever a
	# finger is down so the joystick and buttons stay perfectly responsive.
	_redraw_parity = not _redraw_parity
	var touching: bool = joy_id != -1 or not hold_buttons.is_empty() or not pending_actions.is_empty()
	if game.mode != "play" or touching or _redraw_parity or frame_dt > 0.025:
		queue_redraw()

func text_color(color: Color) -> Color:
	if not paper_context: return color
	var base := Color(color, 1.0)
	if base.is_equal_approx(IVORY): return Color(Art.INK, color.a)
	if base.is_equal_approx(MUTED): return Color(Art.MUTED, color.a)
	if base.is_equal_approx(CYAN): return Color(Color("#396a63"), color.a)
	if base.is_equal_approx(GOLD): return Color(Art.BRASS.darkened(0.18), color.a)
	if base.is_equal_approx(SCARLET): return Color(Art.RED, color.a)
	return color

func txt(pos: Vector2, text: String, size_value: int = 20, color: Color = IVORY, serif: bool = false) -> void:
	draw_string(title_font if serif else body_font, pos + Vector2(0, size_value), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, text_color(color))

func centered(pos: Vector2, text: String, size_value: int = 20, color: Color = IVORY, serif: bool = false) -> void:
	var font = title_font if serif else body_font
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	txt(pos - Vector2(width * 0.5, 0), text, size_value, color, serif)

func paragraph(pos: Vector2, text: String, width: float, size_value: int = 18, color: Color = MUTED) -> float:
	var y = pos.y
	for line in text.split("\n"):
		var current = ""
		for word in line.split(" "):
			var candidate = current + (" " if current != "" else "") + word
			if body_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > width and current != "":
				txt(Vector2(pos.x, y), current, size_value, color)
				y += size_value * 1.48
				current = word
			else:
				current = candidate
		txt(Vector2(pos.x, y), current, size_value, color)
		y += size_value * 1.48
	return y

func panel(rect: Rect2, color: Color = Color(0.08, 0.1, 0.12, 0.97), border: Color = Color(0.97, 0.93, 0.85, 0.25), radius: int = 2, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var s = StyleBoxFlat.new()
	var base := Color(color, 1.0)
	var legacy_dark := base.is_equal_approx(INK) or base.is_equal_approx(SLATE) or base.is_equal_approx(Color(0.08, 0.1, 0.12))
	s.bg_color = Color(Art.PAPER.darkened(0.055), color.a) if paper_context and legacy_dark else color
	s.border_color = Color(Art.BRASS, 0.65) if paper_context else border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.005, 0.008, 0.012, 0.5)
	s.shadow_size = 6
	canvas.draw_style_box(s, rect)

func ornament(pos: Vector2, width: float) -> void:
	var line_color := Color(Art.BRASS, 0.45) if paper_context else Color(Art.SILVER, 0.3)
	draw_line(pos - Vector2(width / 2, 0), pos - Vector2(16, 0), line_color, 1, true)
	draw_line(pos + Vector2(16, 0), pos + Vector2(width / 2, 0), line_color, 1, true)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -5), pos + Vector2(5, 0), pos + Vector2(0, 5), pos + Vector2(-5, 0)]), Art.BRASS)

func button(rect: Rect2, label: String, tag: String, prominent: bool = false) -> void:
	var hover = rect.has_point(mouse_pos - drawing_offset)
	var amount = lerpf(float(hover_values.get(tag, 0)), 1.0 if hover else 0.0, 1.0 - exp(-frame_dt * 16))
	hover_values[tag] = amount
	var pressed = float(press_values.get(tag, 0))
	var motion := ui_motion_enabled()
	var drawn = rect.grow((amount * 1.0 - pressed * 1.1) if motion else 0.0)
	var dark_hud: bool = not paper_context and game.mode == "play" and tag == "dev:open"
	if dark_hud:
		Art.draw_frame(self, drawn, true)
	else:
		Art.draw_button(self, drawn, prominent, amount)
	var size_value := 18
	while size_value > 11 and body_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > rect.size.x - 18: size_value -= 1
	var color := Art.PAPER if prominent or dark_hud else Art.INK
	var width := body_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	draw_string(body_font, rect.get_center() + Vector2(-width * 0.5, size_value * 0.34 + (pressed if motion else 0.0)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)
	buttons.append({"rect": Rect2(rect.position + drawing_offset, rect.size), "tag": tag, "mode": game.mode})

func round_button(pos: Vector2, radius: float, tag: String, glyph: String, label: String = "", enabled: bool = true) -> void:
	var pressed = float(press_values.get(tag, 0))
	if tag == "ability" and game.player.ability_aiming:
		pressed = 0.8
	var accent := CYAN if tag in ["ability", "cycle"] or (tag == "jump" and game.player.beam_aim_toggled) else IVORY
	draw_circle(pos, radius + pressed * 3, Color(accent, 0.15 * pressed))
	draw_circle(pos, radius, Color(Art.NIGHT, 0.78 + pressed * 0.18))
	var bounds := Rect2(Vector2.ONE * -(radius + 3), Vector2.ONE * (radius + 3) * 2)
	var cache_key := "round:%s:%s:%s:%s" % [radius, glyph, accent.to_html(), enabled]
	if not _cached_vector(pos, bounds, cache_key, _draw_round_foreground.bind(radius, glyph, accent, enabled)):
		_draw_round_foreground(self, radius, glyph, accent, enabled, pos)
	if label != "":
		var width: float = body_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string_outline(body_font, pos + Vector2(-width * 0.5, radius + 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(INK, 0.85))
		centered(pos + Vector2(0, radius + 5), label, 11, Color(IVORY, 0.92))
	var hit_radius = maxf(radius, 30.0 if pos.y < 90 else 38.0)
	buttons.append({"rect": Rect2(pos - Vector2.ONE * hit_radius, Vector2.ONE * hit_radius * 2), "tag": tag, "mode": game.mode, "center": pos, "radius": hit_radius})

func _icon_centered(canvas: CanvasItem, pos: Vector2, text: String, size_value: int, color: Color, serif: bool = false) -> void:
	var font := title_font if serif else body_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	canvas.draw_string(font, pos + Vector2(-width * 0.5, size_value), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, text_color(color))

func _draw_round_foreground(canvas: CanvasItem, radius: float, glyph: String, accent: Color, enabled: bool, pos: Vector2 = Vector2.ZERO) -> void:
	canvas.draw_arc(pos, radius, 0, TAU, 48, Color(accent, 0.8 if enabled else 0.25), 1.6, true)
	canvas.draw_arc(pos, radius - 5, 0, TAU, 48, Color(accent, 0.12), 1, true)
	icon(pos, glyph, 0.85 if radius > 30 else 0.62, accent if enabled else Color(MUTED, 0.4), canvas)

func _draw_stick_base(canvas: CanvasItem, pos: Vector2 = Vector2.ZERO) -> void:
	canvas.draw_circle(pos, STICK_RADIUS, Color(0.04, 0.1, 0.11, 0.24))
	canvas.draw_arc(pos, STICK_RADIUS, 0, TAU, 64, Color(IVORY, 0.23), 1.5, true)
	canvas.draw_arc(pos, 68, 0, TAU, 64, Color(IVORY, 0.09), 1, true)

func _draw_reticle(canvas: CanvasItem, aiming: bool, pos: Vector2 = Vector2.ZERO) -> void:
	var aim_color := Color("#b4f6ec") if aiming else IVORY
	canvas.draw_circle(pos, 3.5, Color(INK, 0.9))
	canvas.draw_circle(pos, 2, Color(aim_color, 0.95 if aiming else 0.75))
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		canvas.draw_line(pos + dir * 7, pos + dir * 14, Color(INK, 0.9), 4, true)
		canvas.draw_line(pos + dir * 7, pos + dir * 14, Color(aim_color, 0.9 if aiming else 0.45), 1.5, true)

func _cached_vector(pos: Vector2, bounds: Rect2, key: String, paint: Callable) -> bool:
	if vector_cache == null or DisplayServer.get_name() == "headless": return false
	var ratio := get_viewport_rect().size / Vector2(1280, 720)
	var density := get_viewport().get_stretch_transform().get_scale() * ratio


	var origin := get_viewport().get_stretch_transform().origin
	var pixel_start := ((pos + bounds.position) * density + origin).floor()
	var pixel_end := ((pos + bounds.end) * density + origin).ceil()
	var aligned := Rect2((pixel_start - origin) / density - pos, (pixel_end - pixel_start) / density)
	key += ":%s:%s" % [aligned.position, aligned.size]
	vector_cache.prepare(key, aligned, density, paint)
	var texture = vector_cache.lookup(key)
	if texture == null: return false
	draw_texture_rect(texture, Rect2(pos + aligned.position, aligned.size), false)
	return true

func icon(pos: Vector2, kind: String, s: float = 1, color: Color = IVORY, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	match kind:
		"grimoire":
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(0, -11) * s, pos + Vector2(-14, -15) * s, pos + Vector2(-14, 11) * s, pos + Vector2(0, 15) * s, pos + Vector2(14, 11) * s, pos + Vector2(14, -15) * s, pos + Vector2(0, -11) * s, pos + Vector2(0, 15) * s]), color, 2 * s, true)
			for side in [-1, 1]:
				for y in [-5, 1, 7]:
					canvas.draw_line(pos + Vector2(4 * side, y) * s, pos + Vector2(10 * side, y - 1) * s, Color(color, color.a * 0.7), s, true)
		"magic":
			var star := PackedVector2Array()
			for i in range(9):
				star.append(pos + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (17 if i % 2 == 0 else 6) * s)
			canvas.draw_polyline(star, color, 2 * s, true)
			canvas.draw_circle(pos, 2 * s, color)
		"jump":
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(-13, 3) * s, pos + Vector2(0, -11) * s, pos + Vector2(13, 3) * s]), color, 3 * s, true)
			canvas.draw_line(pos + Vector2(0, -11) * s, pos + Vector2(0, 13) * s, color, 3 * s, true)
		"pause":
			canvas.draw_line(pos + Vector2(-6, -12) * s, pos + Vector2(-6, 12) * s, color, 4 * s, true)
			canvas.draw_line(pos + Vector2(6, -12) * s, pos + Vector2(6, 12) * s, color, 4 * s, true)
		"bag":
			panel(Rect2(pos + Vector2(-13, -8) * s, Vector2(26, 26) * s), Color(color, 0.12), color, 4, canvas)
			canvas.draw_arc(pos + Vector2(0, -8) * s, 7 * s, PI, TAU, 16, color, 2 * s, true)
			canvas.draw_line(pos + Vector2(-7, 4) * s, pos + Vector2(7, 4) * s, color, 2 * s)
		"climb":
			for x in [-9, 9]:
				canvas.draw_line(pos + Vector2(x, -15) * s, pos + Vector2(x, 15) * s, color, 2 * s, true)
			for y in [-10, 0, 10]:
				canvas.draw_line(pos + Vector2(-9, y) * s, pos + Vector2(9, y) * s, color, 2 * s, true)
		"hand":
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(-10, 0) * s, pos + Vector2(-10, 10) * s, pos + Vector2(8, 12) * s, pos + Vector2(11, -3) * s]), color, 2 * s, true)
			for i in range(4):
				canvas.draw_line(pos + Vector2(-9 + i * 6, 0) * s, pos + Vector2(-9 + i * 6, -11 - abs(1.5 - i) * -2) * s, color, 2 * s, true)
		"attack":
			panel(Rect2(pos + Vector2(-13, -9) * s, Vector2(24, 19) * s), Color(color, 0.15), color, 3, canvas)
			canvas.draw_line(pos + Vector2(-2, -9) * s, pos + Vector2(-2, 0) * s, color, 2 * s)
			canvas.draw_line(pos + Vector2(5, -9) * s, pos + Vector2(5, 0) * s, color, 2 * s)
		"evade":
			canvas.draw_arc(pos, 11 * s, -PI * 0.9, PI * 0.65, 28, color, 2 * s, true)
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(-16, -4) * s, pos + Vector2(-13, -14) * s, pos + Vector2(-4, -10) * s]), color, 2 * s, true)
			canvas.draw_line(pos + Vector2(-3, 3) * s, pos + Vector2(4, -3) * s, color, 3 * s, true)
		"lock":
			canvas.draw_arc(pos, 10 * s, 0, TAU, 28, color, 1.8 * s, true)
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				canvas.draw_line(pos + direction * 8 * s, pos + direction * 16 * s, color, 2 * s, true)
			canvas.draw_circle(pos, 2 * s, color)
		"beam":
			canvas.draw_circle(pos, 5 * s, color)
			for i in range(6):
				var dir = Vector2.from_angle(i * TAU / 6)
				canvas.draw_line(pos + dir * 9 * s, pos + dir * 17 * s, color, 2 * s, true)
		"hook":
			canvas.draw_line(pos + Vector2(5, -17) * s, pos + Vector2(5, 4) * s, color, 2.5 * s, true)
			canvas.draw_arc(pos + Vector2(-3, 4) * s, 8 * s, 0, PI * 1.25, 20, color, 2.5 * s, true)
		"run":
			canvas.draw_circle(pos + Vector2(3, -12) * s, 4 * s, color)
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(-10, 0) * s, pos + Vector2(0, -5) * s, pos + Vector2(8, 2) * s]), color, 3 * s, true)
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(-9, 15) * s, pos + Vector2(0, 5) * s, pos + Vector2(10, 15) * s]), color, 3 * s, true)
		_:
			if kind in ["A", "B"]:
				_icon_centered(canvas, pos - Vector2(0, 20), kind, 31, color, true)
			else:
				_icon_centered(canvas, pos - Vector2(0, 13), kind, 20, color)

func flame(pos: Vector2, size_value: float, color: Color) -> void:
	var pts = PackedVector2Array([Vector2(0, -1), Vector2(-0.1, -0.35), Vector2(-0.45, -0.05), Vector2(-0.5, 0.35), Vector2(-0.28, 0.68), Vector2(0, 0.8), Vector2(0.38, 0.55), Vector2(0.49, 0.12), Vector2(0.25, -0.45), Vector2(0.18, 0.08)])
	for i in range(pts.size()):
		pts[i] = pos + pts[i] * size_value
	draw_colored_polygon(pts, color)

func _draw() -> void:
	if game == null or game.state == null or (game.player == null and not game.is_title_context() and game.mode != "loading"):
		return
	buttons.clear()
	var ratio = get_viewport_rect().size / Vector2(1280, 720)
	drawing_offset = Vector2.ZERO
	draw_set_transform(Vector2.ZERO, 0, ratio)
	var mode = game.mode
	paper_context = false
	if mode == "menu":
		_draw_menu()
	elif mode == "loading":
		draw_rect(Rect2(0, 0, 1280, 720), Art.NIGHT)
		Art.draw_fitted(self, Art.texture("portrait"), Rect2(580, 154, 120, 120))
		centered(Vector2(640, 304), "The frontier is waking", 38, Art.PAPER, true)
		centered(Vector2(640, 369), game.loading_text, 18, Art.SILVER)
		draw_line(Vector2(452, 429), Vector2(828, 429), Color(Art.BRASS, 0.28), 4, true)
		var progress := 0.5 + sin(clock * 1.8) * 0.36 if ui_motion_enabled() else 0.5
		draw_line(Vector2(452, 429), Vector2(452 + 376 * progress, 429), Art.BRASS, 3, true)
		centered(Vector2(640, 495), "A NEW ROAD. THE SAME SMALL LIGHT.", 12, Art.SILVER)
	else:
		if mode == "play": damage_feedback.draw_edges(self)
		if not game.is_title_context():
			_draw_play(mode == "play")
		if mode == "bag":
			paper_context = true
			_draw_inventory()
		elif mode == "dev" and dev_menu != null:
			paper_context = true
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.02, 0.04, 0.65))
			dev_menu.draw()
		elif mode in ["grimoire", "spellforge"] and magic_ui != null:
			paper_context = true
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.02, 0.04, 0.6))
			magic_ui.draw(mode)
		elif mode in ["pause", "settings", "controls", "journal", "lore", "craft", "trade", "dialogue", "resource", "camp", "rest", "sleep"]:
			var ease = 1.0 - pow(1.0 - clampf(game.mode_age / (0.24 if ui_motion_enabled() else 0.1), 0, 1), 3)
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.02, 0.03, (0.08 if mode in ["camp", "rest", "sleep", "dialogue"] else 0.42) * ease))
			drawing_offset = Vector2(0, (1.0 - ease) * 12 if ui_motion_enabled() else 0.0)
			draw_set_transform(drawing_offset * ratio, 0, ratio)
			paper_context = mode not in ["camp", "rest", "sleep", "dialogue", "resource"]
			if mode in ["journal", "craft", "trade", "dialogue", "resource", "camp", "rest", "sleep"]:
				fieldbook.draw(mode)
			else:
				_draw_modal(mode)
			draw_set_transform(Vector2.ZERO, 0, ratio)
			drawing_offset = Vector2.ZERO
	paper_context = false

func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(Art.NIGHT, 0.24))
	Art.draw_frame(self, Rect2(40, 22, 508, 678))
	paper_context = true
	centered(Vector2(294, 40), "THE WORLD EXPEDITION" if game.state.expanded_world else "THE NEXT CHAPTER", 15, Art.PAPER, true)
	Art.draw_fitted(self, Art.texture("portrait"), Rect2(244, 114, 100, 100))
	centered(Vector2(294, 219), "MR. JUSTICE", 43, IVORY, true)
	centered(Vector2(294, 279), "A small light. A wide world.", 19, MUTED)
	ornament(Vector2(294, 322), 312)
	var y = 350.0
	if game.has_save:
		button(Rect2(98, y, 392, 56), "Continue the journey", "continue", true)
		y += 68
	button(Rect2(98, y, 392, 56), "Begin a new journey", "new", not game.has_save)
	y += 68
	button(Rect2(98, y, 188, 48), "Settings", "settings")
	button(Rect2(298, y, 192, 48), "How to play", "controls")
	txt(Vector2(98, 565), "ONE WORLD  /  SEVEN REGIONS", 12, MUTED)
	paper_context = false
	centered(Vector2(900, 610), "A little light for the longer road.", 22, Art.PAPER, true)
	centered(Vector2(1140, 672), str(ProjectSettings.get_setting("application/config/version", "")), 12, Art.SILVER)
	if new_journey_confirmation:
		buttons.clear()
		draw_rect(Rect2(0, 0, 1280, 720), Color(Art.NIGHT, 0.76))
		paper_context = true
		Art.draw_frame(self, Rect2(302, 178, 676, 402))
		centered(Vector2(640, 191), "A new road?", 29, Art.PAPER, true)
		paragraph(Vector2(370, 286), "Begin a fresh journey and replace the current journey's progress.", 540, 19, Art.INK)
		paragraph(Vector2(370, 365), "The map and its locations stay the same.", 540, 19, Art.MUTED)
		button(Rect2(366, 484, 262, 52), "Keep this journey", "new_cancel")
		button(Rect2(644, 484, 270, 52), "Begin anew", "new_confirm", true)
		paper_context = false

func halftone(rect: Rect2, spacing: int, color: Color) -> void:
	for x in range(int(rect.position.x), int(rect.end.x), spacing):
		for y in range(int(rect.position.y), int(rect.end.y), spacing):
			draw_circle(Vector2(x, y), 1.5, color)

func modal_header(rect: Rect2, eyebrow: String, title: String, close_tag: String = "play") -> void:
	Art.draw_frame(self, rect, not paper_context)
	if paper_context:
		var size_value := 30
		while size_value > 17 and title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > rect.size.x * 0.38: size_value -= 1
		var width := title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
		draw_string(title_font, Vector2(rect.get_center().x - width * 0.5, rect.position.y + 19 + size_value), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, Art.PAPER)
		txt(rect.position + Vector2(58, 89), eyebrow, 12, MUTED)
		button(Rect2(rect.end.x - 108, rect.position.y + 76, 52, 48), "×", close_tag)
	else:
		txt(rect.position + Vector2(30, 24), eyebrow, 12, Art.BRASS)
		txt(rect.position + Vector2(30, 47), title, 34, Art.PAPER, true)
		button(Rect2(rect.end.x - 150, rect.position.y + 28, 120, 52), "×  Close", close_tag)

func _draw_play(controls: bool) -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 118), Vector2(0, 118)]), PackedColorArray([Color(0.015, 0.04, 0.055, 0.55), Color(0.015, 0.04, 0.055, 0.55), Color(0.015, 0.04, 0.055, 0), Color(0.015, 0.04, 0.055, 0)]))
	_draw_lantern_health()
	_draw_compass()
	var boss = boss_status()
	if not boss.is_empty():
		_draw_boss_health(boss)
	if controls and not desktop_mode():
		round_button(Vector2(1104, 45), 24, "grimoire", "grimoire")
		round_button(Vector2(1170, 45), 24, "bag", "bag")
		round_button(Vector2(1236, 45), 24, "pause", "pause")
		button(Rect2(1188, 102, 68, 44), "DEV", "dev:open")
		_draw_tracked_request()
		var stick_bounds := Rect2(Vector2.ONE * -(STICK_RADIUS + 3), Vector2.ONE * (STICK_RADIUS + 3) * 2)
		if not _cached_vector(joy_center, stick_bounds, "stick-base", _draw_stick_base):
			_draw_stick_base(self, joy_center)
		draw_circle(joy_center + joy_value * STICK_TRAVEL, STICK_THUMB_RADIUS, Color(IVORY, 0.21))
		draw_arc(joy_center + joy_value * STICK_TRAVEL, STICK_THUMB_RADIUS, 0, TAU, 40, Color(IVORY, 0.5), 1, true)
		round_button(Vector2(1178, 589), 48, "jump", "beam" if game.player.beam_aim_toggled else "A", "A · FIRE" if game.player.beam_aim_toggled else "A · JUMP")
		var pickup_hint := context_pickup_hint()
		round_button(Vector2(1074, 631), 40, "attack", "B", "B · " + game.context_label())
		var progress_value = game.get("pickup_progress")
		var pickup_progress := clampf(float(progress_value), 0, 1) if progress_value != null else 0.0
		if pickup_progress > 0:
			draw_arc(Vector2(1074, 631), 47, -PI / 2, -PI / 2 + TAU * pickup_progress, 56, CYAN, 5, true)
		round_button(Vector2(1178, 473), 38, "ability", game.player.ability_id, ("AIM ON" if game.player.beam_aim_toggled else "TAP TO AIM") if game.player.ability_id == "beam" else ("RELEASE" if game.player.ability_aiming else "HOLD TO AIM"), game.state.has_ability(game.player.ability_id))
		if game.state.has_ability("hook"):
			round_button(Vector2(1231, 409), 21, "cycle", ">", "SWITCH")
		if game.player.ability_cooldown > 0:
			draw_arc(Vector2(1178, 473), 40, -PI / 2, -PI / 2 + TAU * minf(1, game.player.ability_cooldown / 1.6), 40, GOLD, 3, true)
		var aim_color = Color("#b4f6ec") if game.player.ability_aiming else IVORY
		if not _cached_vector(Vector2(640, 332), Rect2(-18, -18, 36, 36), "reticle:%s" % game.player.ability_aiming, _draw_reticle.bind(game.player.ability_aiming)):
			_draw_reticle(self, game.player.ability_aiming, Vector2(640, 332))
		if game.player.ability_aiming:
			panel(Rect2(514, 357, 252, 28), Color(INK, 0.75), Color(aim_color, 0.25), 4)
			var hint = "DRAG TO AIM / RELEASE TO CAST"
			if game.player.ability_id == "beam":
				hint = "LOCKED · HOLD A / RELEASE TO FIRE" if is_instance_valid(game.player.lock_target) else "TAP A: PULSE · HOLD: CHARGE · LOCK: TRACK"
			centered(Vector2(640, 362), "RECHARGING" if game.player.ability_cooldown > 0 else hint, 11, aim_color)
		if game.player.beam_charging:
			draw_arc(Vector2(1178, 589), 54, -PI / 2, -PI / 2 + TAU * clampf(game.player.beam_charge / 1.3, 0.01, 1), 56, Color("#b4f6ec"), 5, true)
		fieldbook.workshop.draw_hotbar()
		_draw_combat_controls()
		_draw_magic_controls()
		var nearest = game.player.closest
		if is_instance_valid(nearest) and not is_instance_valid(game.player.held_body):
			panel(Rect2(426, 510, 428, 64 if pickup_hint != "" else 42), Color(INK, 0.9), Color(IVORY, 0.3), 2)
			centered(Vector2(640, 519), str(nearest.get_meta("label", "Interact")), 17)
			if pickup_hint != "":
				centered(Vector2(640, 548), "HOLD TO PUT DOWN" if pickup_progress > 0 and game.context_kind in ["magic", "carried"] else "HOLD TO LIFT" if pickup_progress > 0 else pickup_hint, 12, CYAN)
	if controls and desktop_mode(): _draw_desktop_play()
	if game.region_time > 0 and controls:
		var alpha = clampf(game.region_time, 0, 1)
		var region_y = 158 if not boss.is_empty() else 126
		centered(Vector2(640, region_y), game.region_text, 24, Color(IVORY, alpha), true)
		ornament(Vector2(640, region_y + 45), 220)
	if controls and game.comic_time > 0 and not game.player.camera.is_position_behind(game.comic_point):
		var pos = design_position(game.player.camera.unproject_position(game.comic_point))
		pos.x = clampf(pos.x, 170, 1110)
		pos.y = clampf(pos.y - (0.55 - game.comic_time) * 68.0, 170, 480)
		var font_size = int(lerpf(32, 42, smoothstep(0.43, 0.55, game.comic_time)))
		var width = title_font.get_string_size(game.comic_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline = pos + Vector2(-width * 0.5, font_size)
		draw_string_outline(title_font, baseline, game.comic_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(Color("#102431"), minf(1.0, game.comic_time * 7.0)))
		draw_string(title_font, baseline, game.comic_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(game.comic_color, minf(1.0, game.comic_time * 7.0)))
	if game.toast_time > 0 and controls:
		panel(Rect2(352, 576, 576, 62), Color(0.025, 0.07, 0.08, 0.82), Color(GOLD, 0.3), 5)
		paragraph(Vector2(371, 587), game.toast_text, 540, 14, IVORY)

func context_pickup_hint() -> String:
	if game.magic != null and game.magic.has_levitated_object(): return "TAP B TO THROW · HOLD B TO DROP"
	if is_instance_valid(game.player.held_body): return "TAP B TO THROW · HOLD B TO PUT DOWN"
	if is_instance_valid(game.player.held_body) or not is_instance_valid(game.player.closest):
		return ""
	var target = game.player.closest
	if str(target.get_meta("kind", "")) == "rock" and not game.has_harvest_tool(target) and preload("res://scripts/loose_stone_carry.gd").liftable(target):
		return "HOLD B TO LIFT"
	if str(target.get_meta("kind", "")) == "material":
		return "TAP B TO COLLECT · HOLD B TO LIFT" if preload("res://scripts/loose_stone_carry.gd").liftable(target) else "TAP B TO COLLECT"
	if str(target.get_meta("kind", "")) == "carry":
		return "TAP B TO COLLECT · HOLD B TO LIFT" if str(target.get_meta("material", "")) != "" else "HOLD B TO LIFT"
	return ""

func _draw_compass() -> void:
	var center = Vector2(640, 36)
	draw_line(center - Vector2(157, 0), center + Vector2(157, 0), Color(IVORY, 0.25), 1, true)
	for i in range(4):
		var angle = wrapf(-i * PI / 2 - game.player.yaw, -PI, PI)
		if absf(angle) < 1.7:
			centered(center + Vector2(-angle * 90, -17), ["N", "E", "S", "W"][i], 12, Color(IVORY, 0.8))
	var target = tracked_destination()
	if not target.is_empty():
		var p: Vector2 = target.pos
		var offset = Vector2(p.x - game.player.position.x, p.y - game.player.position.z)
		var diff = wrapf(atan2(-offset.x, -offset.y) - game.player.yaw, -PI, PI)
		var x = center.x + clampf(-diff * 90, -148, 148)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 30), Vector2(x - 5, 41), Vector2(x + 5, 41)]), GOLD)
		centered(Vector2(640, 60), "%s  /  %d m" % [str(target.get("name", "Lost lantern")), int(offset.length())], 13, Color(IVORY, 0.8))
	else:
		centered(Vector2(640, 60), "Explore freely. Find mines, settlements and new roads.", 13, GOLD)

func tracked_destination() -> Dictionary:
	var selected: Dictionary = {}
	if game.tracked_location != "":
		if game.has_method("navigation_destination"): selected = game.navigation_destination(game.tracked_location)
		else:
			var destinations: Array = game.navigation_routes() if game.has_method("navigation_routes") else game.world.get_locations() + game.world.landmarks
			for destination in destinations:
				if str(destination.id) == game.tracked_location:
					selected = destination
					break
	var interior: String = game.world.interior_at(game.player.global_position) if game.world.has_method("interior_at") else ""
	if interior == "":
		return selected


	if not selected.is_empty() and str(selected.get("interior", "")) == interior:
		return selected
	if "deep_adventure" in game and is_instance_valid(game.deep_adventure) and game.deep_adventure.has_method("navigation_target"):
		var objective: Dictionary = game.deep_adventure.navigation_target(interior)
		if not objective.is_empty():
			return objective
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D and game.world.is_ancestor_of(node) and str(node.get_meta("kind", "")) == "entrance" and str(node.get_meta("id", "")) == "exit_" + interior:
			return {"id": "exit_" + interior, "name": "Cave exit" if interior == "mine" else "Crypt exit", "pos": Vector2(node.global_position.x, node.global_position.z), "interior": interior}
	return {}

func _draw_inventory() -> void:
	if game.player.visual.bag_progress < 0.78:
		centered(Vector2(640, 640), "OPENING THE SATCHEL", 20, IVORY, true)
		button(Rect2(1104, 62, 110, 52), "×  Close", "play")
		return
	fieldbook.draw_inventory()

func _draw_modal(mode: String) -> void:
	var close_tag := "back" if game.is_title_context() else "play"
	if mode == "pause":
		modal_header(Rect2(96, 64, 1088, 592), "PAUSED · YOUR JOURNEY IS SAVED", "THE ROAD CAN WAIT")
		Art.draw_fitted(self, Art.texture("portrait"), Rect2(260, 238, 130, 130))
		centered(Vector2(325, 402), "Your light is safe.", 30, IVORY, true)
		centered(Vector2(325, 462), "The kettle can wait.", 18, MUTED)
		centered(Vector2(325, 492), "The road will still be there.", 18, MUTED)
		button(Rect2(608, 210, 528, 64), "BACK TO THE FRONTIER", "play", true)
		button(Rect2(608, 292, 256, 62), "Satchel", "bag")
		button(Rect2(880, 292, 256, 62), "Routes & journal", "journal")
		button(Rect2(608, 370, 256, 62), "Settings", "settings")
		button(Rect2(880, 370, 256, 62), "How to play", "controls")
		button(Rect2(608, 486, 256, 56), "Developer tools", "dev:open")
		button(Rect2(880, 486, 256, 56), "Return to title", "menu")
		centered(Vector2(872, 577), "A new chapter will be here when you are.", 15, MUTED)
	elif mode == "settings":
		modal_header(Rect2(120, 54, 1040, 612), "MAKE IT FEEL RIGHT", "SETTINGS", close_tag)
		var keys := ["volume", "music", "sensitivity", "quality"]
		var names := ["Sound", "Music", "Look sensitivity", "Visual quality"]
		var notes := ["Every footstep, page and spark", "The sound of the frontier", "Set the pace of your aim", "Balance detail and performance"]
		for i in range(4):
			var y := 183 + i * 65
			txt(Vector2(164, y), names[i], 23, IVORY, true)
			txt(Vector2(164, y + 30), notes[i], 14, MUTED)
			var value := float(game.state.settings[keys[i]])
			var value_label: String = ["LOW", "BALANCED", "HIGH"][int(value)] if i == 3 else "%d%%" % int(value * 100)
			button(Rect2(714, y + 2, 56, 48), "−", keys[i] + "_down")
			button(Rect2(1052, y + 2, 56, 48), "+", keys[i] + "_up")
			centered(Vector2(911, y + 5), value_label, 22, CYAN, true)
			for tick in range(10):
				var normalized := value / 2.0 if i == 3 else value
				draw_rect(Rect2(797 + tick * 24, y + 42, 18, 5), Color("#396a63") if float(tick) / 10.0 < normalized else Color(Art.BRASS, 0.23))
			if i < 3:
				draw_line(Vector2(164, y + 59), Vector2(1108, y + 59), Color(Art.BRASS, 0.22), 1)
		button(Rect2(164, 448, 442, 48), "Low flash: " + ("On" if game.state.settings.get("low_flash", false) else "Off"), "low_flash_toggle")
		button(Rect2(630, 448, 478, 48), "Camera shake: " + ("On" if game.state.settings.get("camera_shake", true) else "Off"), "camera_shake_toggle")
		button(Rect2(164, 504, 442, 48), "UI motion: " + ("On" if ui_motion_enabled() else "Reduced"), "ui_motion_toggle")
		button(Rect2(630, 504, 478, 48), "Contextual HUD: " + ("On" if game.state.settings.get("contextual_hud", true) else "Off"), "contextual_hud_toggle")
		button(Rect2(164, 560, 240, 48), "‹  Back", "back")
		button(Rect2(430, 560, 300, 48), "Copy loading report", "loading_report")
		txt(Vector2(766, 576), "CHANGES SAVE AS YOU GO", 12, MUTED)
	elif mode == "controls":
		modal_header(Rect2(64, 40, 1152, 640), "A FEW THINGS FOR THE ROAD", "HOW TO PLAY", close_tag)
		var cards := [
			["01  MOVE, LOOK & PINCH", "Move with the large left stick. Drag the world to look. Spread two world fingers to zoom in; pinch together to zoom out. The camera eases back when idle."],
			["02  A / FIRE & BEAM LOCK", "Tap Beam to aim. Tap A for a pulse; hold to charge, release to fire. Lock tracks a target; Next switches it while charging."],
			["03  B / TOOLS & PLACEMENT", "Tap B to collect; hold to lift. When carrying or levitating, tap B to throw; hold to put down. Trees need an axe; rocks need a pick. B places on a green outline."],
			["04  CLIMB & SWIM", "Explore without limits. Walk or jump into a wall to grip. Climb and swim freely. A leaps away or mantles a clear top."],
			["05  YOUR GRIMOIRE", "Equip your grimoire weapon, open the spell collection and fill four quick slots. Tap a slot, then Cast. Levitate: use the right-edge distance slider; tap B to throw or hold to release. Every spell is ready to equip."],
			["06  KEYBOARD & MOUSE", "WASD move · Space jump / hold-fire · E act\nF aim · Q switch · R dodge · Tab lock · T next\nV cast · G grimoire · X next spell · J journal\n1–9 items · I satchel · Esc back · Right-drag look"]]



		if desktop_mode():
			cards[0] = ["01  MOVE & LOOK", "W A S D moves. Move the mouse to look around. Scroll the wheel to adjust the camera distance."]
			cards[1] = ["02  ATTACK, CAST & AIM", "Left-click attacks, or casts the selected spell with your grimoire equipped. Hold right-click to aim. For the hand beam, hold left-click to charge and release to fire."]
			cards[2] = ["03  INTERACT & PLACE", "E is your interaction button. Tap to interact or collect, hold to lift. When carrying, tap E to throw or hold to put down. E places a prepared item on a green outline."]
			cards[3] = ["04  JUMP, CLIMB & SWIM", "Space jumps. Walk or jump into a climbable wall to grip. Space jumps away or mantles a clear top. R dodges."]
			cards[4] = ["05  INVENTORY & MAGIC", "Tab opens or closes your satchel. Equip your grimoire to cast with left-click. G opens the spell collection; X selects the next equipped spell. Mana potions restore mana."]
			cards[5] = ["06  KEYBOARD & MOUSE", "WASD move · E interact · Space jump\nLeft-click attack/cast · Hold right-click aim\nTab inventory · Escape menu/back\nF lock · T next · Q hand · 1–9 items"]



		for i in range(cards.size()):
			var pos := Vector2(98 + (i % 2) * 556, 180 + (i / 2) * 150)
			panel(Rect2(pos, Vector2(528, 133)), SLATE, Color(IVORY, 0.13), 2)
			txt(pos + Vector2(19, 14), cards[i][0], 18, CYAN if i in [1, 4] else SCARLET, true)
			paragraph(pos + Vector2(19, 45), cards[i][1], 488, 14 if i == 5 else (15 if i == 4 else 16), IVORY)
	elif mode == "lore":
		modal_header(Rect2(192, 88, 896, 544), "A STORY WORTH CARRYING", game.lore_title.to_upper())
		paragraph(Vector2(236, 245), game.lore_text, 800, 22, IVORY)
		button(Rect2(236, 516, 800, 56), "CARRY THE LIGHT ONWARD", "play", true)

func release_pointers() -> void:
	levitation_pointer = -999
	joy_id = -1
	camera_id = -1
	camera_gesture.clear()
	joy_value = Vector2.ZERO
	hold_buttons.clear()
	action_fingers.clear()
	pending_actions.clear()
	menu_pointer = -999
	mouse_camera = false
	if fieldbook.workshop.has_method("cancel_input"): fieldbook.workshop.cancel_input()
	if game != null and game.player != null:
		if game.has_method("cancel_context_action"):
			game.cancel_context_action()
		game.player.cancel_primary_action()
		game.player.end_ability_aim(false)
		game.player.control_move = Vector2.ZERO
		game.player.sprinting = false

func _input(event: InputEvent) -> void:
	if game == null or (game.player == null and not game.is_title_context()):
		return
	if dev_menu != null and dev_menu.handle_input(event): return
	if magic_ui != null and magic_ui.handle_input(event): return
	if fieldbook.workshop.has_method("handle_input") and fieldbook.workshop.handle_input(event): return
	if event is InputEventScreenTouch:
		if event.pressed:
			press(event.index, design_position(event.position))
		else:
			release(event.index, event.canceled, design_position(event.position))
	elif event is InputEventScreenDrag:
		var pos := design_position(event.position)
		if event.index == levitation_pointer:
			drag_levitation_distance(pos)
			get_viewport().set_input_as_handled()
			return
		if pending_actions.has(event.index):
			pending_actions[event.index].dragged = pos.distance_to(pending_actions[event.index].origin) > 12
			pending_actions[event.index].position = pos
		if game.mode in ["play", "rest", "sleep"]:
			if event.index == joy_id and game.mode == "play":
				joy_value = ((pos - joy_center) / STICK_TRAVEL).limit_length()
				game.player.control_move = joy_value
			elif camera_gesture.owns(event.index):
				var gesture: Dictionary = camera_gesture.drag(event.index, pos)
				if gesture.has("zoom"): game.player.adjust_zoom(float(gesture.zoom))
				elif gesture.has("look"): game.player.look(gesture.look)
			elif hold_buttons.get(event.index, "") in ["ability", "primary"] and camera_gesture.points.size() < 2:
				game.player.look(design_position(event.relative))
	elif event is InputEventMagnifyGesture:
		if game.mode in ["play", "rest", "sleep"] and is_finite(event.factor) and event.factor > 0:
			game.player.adjust_zoom(-log(event.factor) * 3.5)
	elif event is InputEventMouseMotion:
		mouse_pos = design_position(event.position)
		if levitation_pointer == -2:
			drag_levitation_distance(mouse_pos)
			get_viewport().set_input_as_handled()
			return
		if pending_actions.has(-2):
			pending_actions[-2].dragged = mouse_pos.distance_to(pending_actions[-2].origin) > 12
			pending_actions[-2].position = mouse_pos
		if (mouse_camera or hold_buttons.get(-2, "") in ["ability", "primary"]) and game.mode in ["play", "rest", "sleep"]:
			game.player.look(design_position(event.relative))
		if joy_id == -2:
			joy_value = ((design_position(event.position) - joy_center) / STICK_TRAVEL).limit_length()
			game.player.control_move = joy_value
	elif event is InputEventMouseButton:
		mouse_pos = design_position(event.position)
		if event.pressed and game.mode in ["play", "rest", "sleep"] and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			game.player.adjust_zoom(-0.6 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.6)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_camera = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not press(-2, design_position(event.position)) and game.mode == "play":
					begin_context_hold(-2)
			else:
				release(-2, false, design_position(event.position))

func press(id: int, pos: Vector2) -> bool:
	if id == levitation_pointer or id == joy_id or id == camera_id or camera_gesture.owns(id) or hold_buttons.has(id) or action_fingers.has(id) or pending_actions.has(id):
		return true
	if game.mode == "play" and game.magic != null and game.magic.has_levitated_object() and LEVITATION_SLIDER.has_point(pos):
		if levitation_pointer == -999 and not camera_gesture.owns(id) and not hold_buttons.has(id):
			levitation_pointer = id
			drag_levitation_distance(pos)
		return true
	if id == joy_id or id == camera_id or hold_buttons.has(id) or action_fingers.has(id):
		return true
	var selected := button_at(pos)
	if not selected.is_empty():
		press_values[selected.tag] = 1.0
		if action_fingers.values().has(selected.tag) or hold_buttons.values().has(selected.tag):
			action_fingers[id] = "blocked"
			return true
		if game.mode != "play" or str(selected.tag).begins_with("hotbar:"):
			if menu_pointer != -999:
				action_fingers[id] = "blocked"
				return true
			menu_pointer = id
			action_fingers[id] = selected.tag
			pending_actions[id] = {"tag": selected.tag, "mode": game.mode, "origin": pos, "position": pos, "dragged": false}
			return true
		action_fingers[id] = selected.tag
		if selected.tag == "ability":
			begin_ability_hold(id)
		elif selected.tag == "jump":
			hold_buttons[id] = "primary"
			game.player.begin_primary_action()
		elif selected.tag == "attack":
			begin_context_hold(id)
		else:
			dispatch(selected.tag)
		return true
	if game.mode in ["rest", "sleep"] and camera_gesture.begin(id, pos):
		camera_id = camera_gesture.primary; return true
	if game.mode == "play":
		if pos.distance_to(joy_center) <= STICK_CAPTURE_RADIUS:
			if joy_id == -1:
				joy_id = id
				joy_value = ((pos - joy_center) / STICK_TRAVEL).limit_length()
				game.player.control_move = joy_value
			else:
				action_fingers[id] = "blocked"
			return true
		if pos.x > 365 and camera_gesture.begin(id, pos):
			camera_id = camera_gesture.primary
			return true
	return false

func button_at(pos: Vector2) -> Dictionary:
	var selected: Dictionary = {}
	var priority := INF
	for entry in buttons:
		if entry.get("mode", "") != game.mode:
			continue
		if entry.rect.has_point(pos):
			var distance: float = pos.distance_to(entry.center) / float(entry.radius) if entry.has("center") else 0.0
			if distance <= 1.0 and distance < priority:
				selected = entry
				priority = distance
	return selected

func design_position(pos: Vector2) -> Vector2:
	return pos * Vector2(1280, 720) / get_viewport_rect().size.max(Vector2.ONE)

func begin_ability_hold(id: int) -> void:
	if game.mode == "play" and game.player.ability_id == "beam":
		if not hold_buttons.values().has("beam_toggle"):
			hold_buttons[id] = "beam_toggle"
			game.player.toggle_beam_aim()
		return
	if game.mode == "play" and not hold_buttons.values().has("ability") and game.player.begin_ability_aim():
		hold_buttons[id] = "ability"
		press_values["ability"] = 1.0

func begin_context_hold(id: int) -> void:
	if game.mode != "play" or hold_buttons.values().has("context"):
		return
	hold_buttons[id] = "context"
	action_fingers[id] = "attack"
	if game.has_method("begin_context_action"):
		game.begin_context_action()
	else:
		game.contextual_b()

func release(id: int, canceled: bool = false, pos: Vector2 = Vector2(INF, INF)) -> void:
	if id == levitation_pointer:
		levitation_pointer = -999
		return
	if camera_gesture.owns(id):
		camera_gesture.end(id)
		camera_id = camera_gesture.primary
	if pending_actions.has(id):
		var pending: Dictionary = pending_actions[id]
		pending_actions.erase(id)
		if menu_pointer == id:
			menu_pointer = -999
		var target := button_at(pos)
		if not canceled and pending.mode == game.mode and not target.is_empty():
			if str(pending.tag).begins_with("slot:") and str(target.tag).begins_with("slot:") and bool(pending.dragged):
				fieldbook.workshop.move_stack(int(str(pending.tag).trim_prefix("slot:")), int(str(target.tag).trim_prefix("slot:")))
			elif target.tag == pending.tag:
				dispatch(pending.tag)
	action_fingers.erase(id)
	if id == joy_id:
		joy_id = -1
		joy_value = Vector2.ZERO
		game.player.control_move = Vector2.ZERO
	if hold_buttons.has(id):
		var kind: String = hold_buttons[id]
		hold_buttons.erase(id)
		if kind == "primary":
			game.player.end_primary_action(canceled or game.mode != "play")
		if kind == "ability":
			game.player.end_ability_aim(not canceled and game.mode == "play")
		if kind == "context" and game.has_method("end_context_action"):
			game.end_context_action(canceled or game.mode != "play")

func dispatch(tag: String) -> void:
	game.audio.cue("ui")
	if tag in ["cast_spell", "equip_grimoire", "ability", "cycle", "grimoire", "lock", "lock_cycle", "dodge"] or tag.begins_with("spellslot:"):
		hud_context.reveal_magic()
	if dev_menu != null and dev_menu.dispatch(tag): return
	if magic_ui != null and magic_ui.dispatch(tag): return
	if tag.begins_with("spellslot:"):
		game.select_spell_slot(int(tag.get_slice(":", 1)))
		return
	if fieldbook.handle(tag):
		return
	match tag:
		"new":
			seed_entry.release_focus()
			if game.has_save:
				new_journey_confirmation = true
			else:
				game.start_journey(false, seed_entry.text)
		"new_cancel": new_journey_confirmation = false
		"new_confirm":
			if new_journey_confirmation:
				new_journey_confirmation = false
				seed_entry.release_focus()
				game.start_journey(false, seed_entry.text)
		"quest:open": hud_context.reveal_quest()
		"quest:fold": hud_context.fold_quest()
		"continue": game.start_journey(true)
		"jump": game.player.begin_primary_action()
		"attack": game.contextual_b()
		"ability": game.player.use_ability()
		"climb": game.player.toggle_climb()
		"interact": game.player.interact()
		"cycle": game.cycle_ability()
		"equip_grimoire": game.ready_grimoire()
		"magic_place": game.magic.release_levitated_object(false)
		"magic_throw": game.magic.release_levitated_object(true)
		"magic_near": game.magic.adjust_levitation_distance(-0.6)
		"magic_far": game.magic.adjust_levitation_distance(0.6)
		"grimoire": game.open_grimoire()
		"cast_spell": game.player.cast_spell()
		"dodge":
			if game.player.has_method("dodge"):
				game.player.dodge()
		"lock":
			if game.player.has_method("toggle_lock_on"):
				game.player.toggle_lock_on()
		"lock_cycle":
			if game.player.has_method("cycle_lock_target"):
				game.player.cycle_lock_target()
		"play", "pause", "bag", "journal", "settings", "controls", "menu", "craft", "trade", "dialogue": game.set_mode(tag)
		"back": game.navigate_back()
		"loading_report":
			DisplayServer.clipboard_set(game.loading_report.text())
			game.toast("Loading report copied", 3)
		"low_flash_toggle":
			game.state.settings.low_flash = not bool(game.state.settings.get("low_flash", false))
			game.apply_settings()
		"camera_shake_toggle":
			game.state.settings.camera_shake = not bool(game.state.settings.get("camera_shake", true))
			game.apply_settings()
		"ui_motion_toggle":
			game.state.settings.ui_motion = not bool(game.state.settings.get("ui_motion", true))
			game.apply_settings()
		"contextual_hud_toggle":
			game.state.settings.contextual_hud = not bool(game.state.settings.get("contextual_hud", true))
			hud_context.reveal_magic()
			hud_context.reveal_quest()
			game.apply_settings()
		"heal":
			game.use_supply("tonic")
		_:
			for key in ["volume", "music", "sensitivity", "quality"]:
				if tag.begins_with(key):
					var amount = (1 if key == "quality" else 0.1) * (-1 if tag.ends_with("down") else 1)
					game.state.settings[key] = clampf(float(game.state.settings[key]) + amount, 0.2 if key == "sensitivity" else 0, 2 if key == "quality" else 1)
					game.apply_settings()

func _draw_magic_controls() -> void:
	var spell: Dictionary = game.state.equipped_spell()
	if spell.is_empty(): return
	var tint := Color(str(spell.color))
	var alpha: float = hud_context.magic_alpha
	panel(Rect2(138, 111, 222, 8), Color(Art.NIGHT, 0.8 * alpha), Color(Art.SILVER, 0.45 * alpha), 3)
	draw_rect(Rect2(140, 113, 218 * clampf(game.state.mana / maxf(1.0, game.state.max_mana), 0, 1), 4), Color(Color("#77b5a0"), alpha))
	txt(Vector2(138, 122), "MANA  %d / %d" % [int(game.state.mana), int(game.state.max_mana)], 10, Color(Art.SILVER, alpha))
	for i in range(game.state.spell_slots.size()):
		var rect := Rect2(28 + i * 57, 162, 51, 44)
		var selected: bool = i == game.state.active_spell_slot
		var ready: Dictionary = game.state.spell_by_id(str(game.state.spell_slots[i]))
		var color := Color(str(ready.get("color", "#cccccc")))
		panel(rect, Color(Art.NIGHT, 0.9 * alpha), Color(Art.BRASS if selected else Art.SILVER, alpha * (0.95 if selected else 0.4)), 2)
		var painting := Art.spell_texture(str(ready.get("id", "")))
		if painting != null:
			Art.draw_fitted(self, painting, rect.grow(-4), Color(Color.WHITE, alpha))
		else:
			icon(rect.get_center(), "magic", 0.6, Color(color, alpha))
		txt(rect.position + Vector2(4, 2), str(i + 1), 10, Color(Art.PAPER, alpha))
		buttons.append({"rect": rect, "tag": "spellslot:%d" % i, "mode": game.mode})
	var title := str(spell.name)
	while title.length() > 1 and body_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > 224:
		title = title.left(title.length() - 1)
	if title != str(spell.name): title = title.left(maxi(1, title.length() - 1)) + "…"
	draw_string_outline(body_font, Vector2(28, 226), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(Art.NIGHT, 0.9 * alpha))
	txt(Vector2(28, 213), title, 13, Color(Art.PAPER, alpha))
	var runtime = game.get("magic")
	if desktop_mode():
		if game.player.grimoire_equipped():
			txt(Vector2(28, 238), "X  NEXT SPELL  ·  G  SPELLBOOK", 11, MUTED)
			if runtime != null and runtime.has_levitated_object():
				txt(Vector2(28, 259), "WHEEL  DISTANCE  ·  E  THROW / HOLD TO DROP", 10, CYAN)
			elif runtime != null and runtime.cooldown_remaining > 0:
				txt(Vector2(28, 259), "RECHARGING  %.1f s" % runtime.cooldown_remaining, 11, CYAN)
		else: txt(Vector2(28, 238), "TAB  ·  EQUIP YOUR GRIMOIRE TO CAST", 10, MUTED)
		return
	if not game.player.grimoire_equipped():
		round_button(Vector2(1076, 482), 35, "equip_grimoire", "grimoire", "EQUIP BOOK")
		return
	if runtime != null and runtime.has_levitated_object():
		_draw_levitation_distance()
	var cooldown: float = runtime.cooldown_remaining if runtime != null else 0.0
	var affordable: bool = game.state.mana >= Spellbook.cost(spell)
	round_button(Vector2(1076, 482), 35, "cast_spell", "magic", "CAST · %d" % int(Spellbook.cost(spell)), affordable and cooldown <= 0.0)
	if cooldown > 0.0:
		draw_arc(Vector2(1076, 482), 39, -PI * 0.5, -PI * 0.5 + TAU * clampf(cooldown / Spellbook.cooldown(spell), 0, 1), 32, tint, 3, true)
	if runtime != null and runtime.ward_strength > 0:
		txt(Vector2(28, 234), "WARD · %d protection" % runtime.ward_strength, 12, Color("#ffe3a0"))

func drag_levitation_distance(pos: Vector2) -> void:
	if game.mode != "play" or game.magic == null or not game.magic.has_levitated_object():
		levitation_pointer = -999
		return
	var bounds: Vector2 = game.magic.levitation_distance_limits()
	var fraction := clampf((LEVITATION_TRACK_BOTTOM - pos.y) / (LEVITATION_TRACK_BOTTOM - LEVITATION_TRACK_TOP), 0.0, 1.0)
	game.magic.set_levitation_distance(lerpf(bounds.x, bounds.y, fraction))

func _draw_levitation_distance() -> void:
	var runtime = game.magic
	var bounds: Vector2 = runtime.levitation_distance_limits()
	var distance: float = runtime.object_magic.hold_distance
	var fraction := inverse_lerp(bounds.x, bounds.y, distance) if bounds.y > bounds.x else 0.0
	panel(LEVITATION_SLIDER, Color(INK, 0.94), Color(CYAN, 0.45), 8)
	centered(Vector2(LEVITATION_TRACK_X, 169), "DISTANCE", 9, CYAN)
	centered(Vector2(LEVITATION_TRACK_X, 190), "FAR", 9, MUTED)
	var top := Vector2(LEVITATION_TRACK_X, LEVITATION_TRACK_TOP)
	var bottom := Vector2(LEVITATION_TRACK_X, LEVITATION_TRACK_BOTTOM)
	var thumb := bottom.lerp(top, fraction)
	draw_line(top, bottom, Color(IVORY, 0.2), 5, true)
	draw_line(bottom, thumb, CYAN, 5, true)
	draw_circle(thumb, 9, IVORY)
	draw_circle(thumb, 4, CYAN)
	centered(Vector2(LEVITATION_TRACK_X, 360), "NEAR", 9, MUTED)
	var value_rect := Rect2(Vector2(1124, thumb.y - 17), Vector2(64, 34))
	panel(value_rect, Color(INK, 0.94), Color(CYAN, 0.45), 6)
	centered(value_rect.position + Vector2(32, 9), "%.1f m" % distance, 12, IVORY)
	draw_line(Vector2(1188, thumb.y), Vector2(1215, thumb.y), Color(CYAN, 0.45), 1, true)
	centered(Vector2(640, 365), "LEVITATING · TAP B: THROW / HOLD B: DROP", 12, CYAN)

func _draw_combat_controls() -> void:
	var target = game.player.get("lock_target")
	var locked := is_instance_valid(target)
	round_button(Vector2(978, 555), 34, "dodge", "evade", "DODGE")
	round_button(Vector2(1000, 455), 30, "lock", "lock", "RELEASE" if locked else "LOCK ON")
	var dodge_value = game.player.get("dodge_time")
	var remaining := float(dodge_value) if dodge_value != null else 0.0
	if remaining > 0:
		var invulnerable: bool = game.player.has_method("dodge_invulnerable") and game.player.dodge_invulnerable()
		draw_arc(Vector2(978, 555), 40, -PI / 2, -PI / 2 + TAU * clampf(remaining / 0.62, 0.0, 1.0), 40, CYAN if invulnerable else GOLD, 3, true)
	if not locked:
		return
	round_button(Vector2(1050, 389), 22, "lock_cycle", ">", "NEXT TARGET")
	_draw_lock_target()

func _draw_lock_target() -> void:
	var target = game.player.get("lock_target")
	if not is_instance_valid(target): return
	var point: Vector3 = target.global_position + Vector3.UP * 1.85
	if game.player.camera.is_position_behind(point):
		return
	var pos := design_position(game.player.camera.unproject_position(point))
	pos.x = clampf(pos.x, 70, 1210)
	pos.y = clampf(pos.y, 115, 502)
	var diamond := PackedVector2Array([Vector2(0, -13), Vector2(13, 0), Vector2(0, 13), Vector2(-13, 0), Vector2(0, -13)])
	for i in range(diamond.size()):
		diamond[i] += pos
	draw_polyline(diamond, INK, 5, true)
	draw_polyline(diamond, CYAN, 2, true)
	draw_circle(pos, 2, CYAN)
	var health: float = float(target.get_meta("health", 1))
	var maximum: float = maxf(1.0, float(target.get_meta("max_health", health)))
	draw_rect(Rect2(pos + Vector2(-31, 23), Vector2(62, 4)), Color(INK, 0.9))
	draw_rect(Rect2(pos + Vector2(-30, 24), Vector2(60 * clampf(health / maximum, 0, 1), 2)), CYAN)

func boss_status() -> Dictionary:
	if game == null or not is_instance_valid(game.player) or not is_inside_tree():
		return {}
	var selected: Node3D
	var nearest = 32.0
	for node in get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not bool(node.get_meta("is_boss", false)) or not game.player.lock_target_alive(node):
			continue
		var distance: float = game.player.global_position.distance_to(node.global_position)
		if distance < nearest:
			selected = node
			nearest = distance
	if not is_instance_valid(selected):
		return {}
	var health = float(selected.get("health")) if "health" in selected else float(selected.get_meta("health", 1))
	var maximum = float(selected.get("max_health")) if "max_health" in selected else float(selected.get_meta("max_health", health))
	return {"node": selected, "name": str(selected.get_meta("display_name", "Guardian")), "health": health, "maximum": maxf(1.0, maximum)}

func _draw_boss_health(status: Dictionary) -> void:
	panel(Rect2(422, 91, 436, 47), Color(INK, 0.88), Color(GOLD, 0.5), 3)
	centered(Vector2(640, 96), str(status.name), 16, IVORY, true)
	draw_rect(Rect2(440, 121, 400, 7), SLATE)
	draw_rect(Rect2(440, 121, 400 * clampf(float(status.health) / float(status.maximum), 0.0, 1.0), 7), SCARLET)

func ui_motion_enabled() -> bool:
	return bool(game.state.settings.get("ui_motion", true)) if game != null and game.state != null and "settings" in game.state else true

func notify_damage(before: int, after: int, maximum: int) -> void:
	if game == null or game.mode != "play": return
	var low_flash := bool(game.state.settings.get("low_flash", false)) if "settings" in game.state else false
	if damage_feedback.notify_hit(before, after, maximum, low_flash or not ui_motion_enabled()):
		health_flash = 1.0 if not low_flash and ui_motion_enabled() else 0.0
		hud_context.reveal_magic()

func tracked_request() -> Dictionary:
	if game == null or not "quests" in game or game.quests == null: return {}
	var id := str(game.tracked_location)
	if not id.begins_with("quest_"): return {}
	return game.quests.entry(id.trim_prefix("quest_"))

func magic_is_relevant() -> bool:
	if game == null or game.player == null: return false
	var player = game.player
	if player.ability_aiming or player.beam_aim_toggled or player.beam_charging or player.cast_time > 0.0 or is_instance_valid(player.lock_target): return true
	if float(damage_feedback.snapshot().edge_alpha) > 0.0: return true
	var runtime = game.get("magic")
	return runtime != null and (runtime.has_levitated_object() or runtime.cooldown_remaining > 0.0 or runtime.ward_strength > 0)

func quest_layout(levitating: bool = false) -> Dictionary:
	var right := 1180.0 if levitating else 1254.0
	return {"card": Rect2(right - 318, 158, 318, 112), "bookmark": Rect2(right - 66, 151, 66, 82)}

func _draw_tracked_request() -> void:
	var request := tracked_request()
	if request.is_empty(): return
	var layout := quest_layout(game.magic != null and game.magic.has_levitated_object())
	var rect: Rect2 = layout.card
	var hit: Rect2 = layout.bookmark
	var fold: float = hud_context.quest_fold_progress
	var eased := smoothstep(0.0, 1.0, fold)
	var card_alpha := 1.0 - smoothstep(0.0, 0.85, fold)
	if card_alpha > 0.001:
		var pivot := Vector2(rect.end.x - 34, rect.position.y + 4)
		_quest_draw_transform(pivot, Vector2(7, -10) * eased, Vector2(lerpf(1.0, 0.12, eased), lerpf(1.0, 0.65, eased)), -0.05 * eased)
		_draw_quest_card(rect, request, card_alpha)
	var bookmark_alpha := smoothstep(0.25, 0.8, fold)
	if bookmark_alpha > 0.001:
		var settle := smoothstep(0.3, 1.0, fold)
		var pivot := hit.position + Vector2(31, 7)
		_quest_draw_transform(pivot, Vector2(0, lerpf(-10.0, 0.0, settle)), Vector2.ONE * lerpf(0.84, 1.0, settle), lerpf(-0.15, 0.0, settle))
		_draw_quest_bookmark(hit, bookmark_alpha)


	var ratio := get_viewport_rect().size / Vector2(1280, 720)
	draw_set_transform(drawing_offset * ratio, 0, ratio)
	if hud_context.quest_folded:
		buttons.append({"rect": hit, "tag": "quest:open", "mode": game.mode})
	else:
		buttons.append({"rect": Rect2(rect.end.x - 44, 158, 44, 48), "tag": "quest:fold", "mode": game.mode})

func _quest_draw_transform(pivot: Vector2, offset: Vector2, scale_value: Vector2, rotation: float) -> void:
	var basis_x := Vector2.RIGHT.rotated(rotation) * scale_value.x
	var basis_y := Vector2.DOWN.rotated(rotation) * scale_value.y
	var origin := pivot + offset - basis_x * pivot.x - basis_y * pivot.y + drawing_offset
	var ratio := get_viewport_rect().size / Vector2(1280, 720)
	draw_set_transform_matrix(Transform2D(basis_x * ratio, basis_y * ratio, origin * ratio))

func _draw_quest_bookmark(hit: Rect2, alpha: float) -> void:
	var origin := hit.position + Vector2(9, 7)
	var cloth := PackedVector2Array([origin, origin + Vector2(44, 0), origin + Vector2(44, 67), origin + Vector2(22, 55), origin + Vector2(0, 67)])
	draw_colored_polygon(cloth, Color(Art.RED, alpha))
	cloth.append(origin)
	draw_polyline(cloth, Color(Art.BRASS.lightened(0.25), alpha), 1.4, true)
	for side in [5.0, 39.0]:
		for stitch in range(9, 51, 6):
			draw_line(origin + Vector2(side, stitch), origin + Vector2(side, stitch + 3), Color(Art.PAPER, 0.6 * alpha), 0.8, true)
	draw_line(origin + Vector2(1, 3), origin + Vector2(43, 3), Color(Art.SILVER, alpha), 3, true)
	icon(origin + Vector2(22, 29), "grimoire", 0.5, Color(Art.PAPER, alpha))

func _draw_quest_card(rect: Rect2, request: Dictionary, alpha: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Art.NIGHT, 0.88 * alpha)
	style.border_color = Color(Art.BRASS, 0.52 * alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.005, 0.008, 0.012, 0.5 * alpha)
	style.shadow_size = 6
	draw_style_box(style, rect)
	draw_line(rect.position + Vector2(2, 7), rect.position + Vector2(2, 105), Color(Art.BRASS, alpha), 2, true)
	txt(rect.position + Vector2(14, 10), "TRACKED REQUEST", 10, Color(Art.BRASS.lightened(0.5), alpha))
	var title := str(request.get("name", "A request for the road"))
	var size_value := 18
	while size_value > 12 and title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > 243: size_value -= 1
	if title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > 243:
		while title.length() > 1 and title_font.get_string_size(title + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x > 243: title = title.left(title.length() - 1)
		title += "…"
	txt(rect.position + Vector2(14, 29), title, size_value, Color(Art.PAPER, alpha), true)
	paragraph(rect.position + Vector2(14, 57), str(request.get("objective", "")), 282, 12, Color(Art.SILVER, alpha))
	icon(rect.position + Vector2(292, 25), "grimoire", 0.5, Color(Art.BRASS.lightened(0.4), alpha))


func health_layout(maximum: int, current: int) -> Dictionary:
	var pips: Array = []
	maximum = clampi(maximum, 1, 24)
	var columns := mini(maximum, 12)
	var side := minf(34.0, (336.0 - 7.0 * (columns - 1)) / columns)
	for i in range(maximum):
		var row := i / 12
		var origin := Vector2(112 + (i % 12) * (side + 7), 29 if maximum <= 12 else 23 + row * 31)
		pips.append({"rect": Rect2(origin, Vector2.ONE * side), "filled": i < current})
	return {"medallion": Rect2(22, 20, 86, 86), "pips": pips}

func _draw_lantern_health() -> void:
	var status := health_layout(game.state.max_health, game.state.health)
	var pips: Array = status.pips
	var end_x := 112.0
	for pip in pips: end_x = maxf(end_x, pip.rect.end.x)
	draw_colored_polygon(PackedVector2Array([Vector2(93, 23), Vector2(end_x + 20, 23), Vector2(end_x + 10, 54), Vector2(end_x + 20, 82), Vector2(93, 82)]), Color(Art.NIGHT, 0.9))
	draw_line(Vector2(102, 24), Vector2(end_x + 18, 24), Color(Art.SILVER, 0.7), 1.2, true)
	Art.draw_fitted(self, Art.texture("portrait"), status.medallion)
	var pulse: float = damage_feedback.snapshot().portrait_alpha
	if pulse > 0.0:
		draw_arc(status.medallion.get_center(), 44 + pulse * 5, 0, TAU, 64, Color(Art.RED, pulse), 2.0, true)
	for pip in pips:
		Art.draw_fitted(self, Art.texture("head" if pip.filled else "head_empty"), pip.rect)
	var shards := "%03d" % int(game.state.items.get("shard", 0))
	draw_string_outline(body_font, Vector2(138, 104), shards, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 3, Color(Art.NIGHT, 0.9))
	txt(Vector2(138, 87), shards, 17, Art.PAPER)
	txt(Vector2(187, 93), "LIGHT ESSENCE", 9, Art.SILVER)
	Art.draw_fitted(self, Art.item_texture("shard"), Rect2(107, 83, 31, 31))

func desktop_mode() -> bool:
	return game != null and game.has_method("desktop_enabled") and game.desktop_enabled()

func _draw_desktop_play() -> void:
	_draw_tracked_request()
	_draw_magic_controls()
	_draw_lock_target()
	fieldbook.workshop.draw_hotbar()
	_draw_reticle(self, game.player.ability_aiming, Vector2(640, 332))
	txt(Vector2(968, 32), "TAB  SATCHEL   ·   ESC  MENU", 13, IVORY)
	panel(Rect2(24, 620, 310, 80), Color(INK, 0.8), Color(IVORY, 0.18), 4)
	txt(Vector2(38, 630), "WASD  MOVE   ·   SPACE  JUMP", 12, IVORY)
	txt(Vector2(38, 652), "E  INTERACT   ·   TAB  SATCHEL   ·   ESC  MENU", 11, IVORY)
	txt(Vector2(38, 676), "LEFT ATTACK / CAST  ·  HOLD RIGHT AIM", 11, MUTED)
	if game.player.ability_aiming:
		var hint = "LEFT-CLICK TO CAST" if game.player.grimoire_equipped() else "LEFT-CLICK TO FIRE · HOLD TO CHARGE" if game.player.ability_id == "beam" else "LEFT-CLICK TO LAUNCH"
		centered(Vector2(640, 365), hint, 12, CYAN)
	var nearest = game.player.closest
	if is_instance_valid(nearest) and not is_instance_valid(game.player.held_body):
		panel(Rect2(426, 510, 428, 42), Color(INK, 0.9), Color(IVORY, 0.3), 2)
		centered(Vector2(640, 519), "E  ·  " + str(nearest.get_meta("label", "Interact")), 17)
