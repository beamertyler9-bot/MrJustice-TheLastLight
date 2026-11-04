extends RefCounted



const Index = preload("res://scripts/item_icon_catalog.gd")
const PAPER := Color("#f1e6cf")
const INK := Color("#26332f")
const MUTED := Color("#5c6054")
const RED := Color("#8d3029")
const BRASS := Color("#9f783f")
const SILVER := Color("#d7ded9")
const NIGHT := Color("#142b31")

const TEXTURES := {
	"frame": preload("res://assets/ui_lantern_ledger/frame.png"),
	"portrait": preload("res://assets/ui_lantern_ledger/portrait.svg"),
	"head": preload("res://assets/ui_lantern_ledger/head.svg"),
	"head_empty": preload("res://assets/ui_lantern_ledger/head_empty.svg"),
	"items": preload("res://assets/ui_lantern_ledger/painted-item-atlas.png"),
	"mana_potion": preload("res://assets/ui_lantern_ledger/mana-potion.png"),
	"spells": preload("res://assets/ui_lantern_ledger/painted-spell-atlas.png")
}
const BODY_FONT = preload("res://assets/ui_lantern_ledger/body.ttf")
const TITLE_FONT = preload("res://assets/ui_lantern_ledger/title.ttf")
const ITEM_CELL := 229
const ITEM_INSETS := {
	"tonic": Vector2(24, 0),
	"coffee": Vector2(17, 0),
	"herb": Vector2(27, 0),
	"marshmallow": Vector2(0, 15)
}
const SPELL_CELLS := {
	"basic_fireball": Vector2(0, 0),
	"basic_lightning_bolt": Vector2(1, 0),
	"basic_rock_throw": Vector2(2, 0),
	"basic_levitation": Vector2(0, 1),
	"v18_cinder_serpents": Vector2(1, 1),
	"v18_winter_crown": Vector2(2, 1)
}
static var _item_textures: Dictionary = {}
static var _spell_textures: Dictionary = {}

static func texture(key: String) -> Texture2D:
	return TEXTURES.get(key) as Texture2D

static func item_texture(id: String) -> AtlasTexture:
	if id == "shard": return preload("res://scripts/item_icons.gd").texture(id)
	if _item_textures.has(id):
		return _item_textures[id]
	if id == "mana_potion":
		var bottle := AtlasTexture.new()
		bottle.atlas = texture("mana_potion")
		bottle.region = Rect2(Vector2.ZERO, bottle.atlas.get_size())
		bottle.filter_clip = true
		_item_textures[id] = bottle
		return bottle
	var index: int = Index.IDS.find(id)
	if index < 0:
		return null
	var inset: Vector2 = ITEM_INSETS.get(id, Vector2.ZERO)
	var origin := Vector2(index % Index.COLUMNS, floori(float(index) / Index.COLUMNS)) * ITEM_CELL
	var picture := AtlasTexture.new()
	picture.atlas = texture("items")
	picture.region = Rect2(origin + inset, Vector2.ONE * ITEM_CELL - inset)

	picture.margin = Rect2(8, 8, 16, 16)
	picture.filter_clip = true
	_item_textures[id] = picture
	return picture

static func spell_texture(id: String) -> Texture2D:
	if _spell_textures.has(id):
		return _spell_textures[id]
	if not SPELL_CELLS.has(id):
		return null
	var cell: Vector2 = SPELL_CELLS[id]
	var picture := AtlasTexture.new()
	picture.atlas = texture("spells")
	picture.region = Rect2(cell * 512, Vector2(512, 512))
	picture.filter_clip = true
	_spell_textures[id] = picture
	return picture

static func font(is_title: bool = false) -> Font:
	return TITLE_FONT if is_title else BODY_FONT

static func fitted_rect(painting: Texture2D, rect: Rect2) -> Rect2:
	if painting == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	var extent := painting.get_size()
	if extent.x <= 0.0 or extent.y <= 0.0:
		return Rect2()
	var scale := minf(rect.size.x / extent.x, rect.size.y / extent.y)
	var size := extent * scale
	return Rect2(rect.position + (rect.size - size) * 0.5, size)

static func draw_fitted(canvas: CanvasItem, painting: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	var fitted := fitted_rect(painting, rect)
	if canvas != null and fitted.has_area():
		canvas.draw_texture_rect(painting, fitted, false, modulate)

static func draw_frame(canvas: CanvasItem, rect: Rect2, dark: bool = false) -> void:
	if canvas == null or not rect.has_area():
		return
	canvas.draw_rect(Rect2(rect.position + Vector2(0, 5), rect.size), Color(0.025, 0.045, 0.05, 0.48))
	if dark:
		canvas.draw_rect(rect, NIGHT)
		canvas.draw_rect(rect, Color(SILVER, 0.72), false, 1.5)
		if rect.size.x > 14 and rect.size.y > 14:
			canvas.draw_rect(rect.grow(-4), Color(BRASS, 0.66), false, 1.0)
			for corner in [rect.position + Vector2(8, 8), Vector2(rect.end.x - 8, rect.position.y + 8), rect.end - Vector2(8, 8), Vector2(rect.position.x + 8, rect.end.y - 8)]:
				canvas.draw_circle(corner, 1.6, BRASS)
		return


	var painting := texture("frame")
	var scale := minf(54.0, minf(rect.size.x * 0.15, rect.size.y * 0.22)) / 160.0
	var sx := PackedFloat32Array([0, 160, 1512, 1672])
	var sy := PackedFloat32Array([0, 160, 757, 941])
	var dx := PackedFloat32Array([rect.position.x, rect.position.x + 160 * scale, rect.end.x - 160 * scale, rect.end.x])
	var dy := PackedFloat32Array([rect.position.y, rect.position.y + 160 * scale, rect.end.y - 184 * scale, rect.end.y])
	for y in range(3):
		for x in range(3):
			var source := Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y])
			var destination := Rect2(dx[x], dy[y], dx[x + 1] - dx[x], dy[y + 1] - dy[y])
			canvas.draw_texture_rect_region(painting, destination, source)

static func draw_button(canvas: CanvasItem, rect: Rect2, prominent: bool = false, hover: float = 0.0) -> void:
	if canvas == null or not rect.has_area():
		return
	var focus := clampf(hover, 0.0, 1.0)
	var fill := RED if prominent else PAPER.darkened(0.055)
	fill = fill.lightened(focus * 0.1)
	var rim := BRASS.lightened(0.28 if prominent else 0.05)
	canvas.draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(NIGHT, 0.35))
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, rim, false, 1.5)
	if rect.size.x > 8 and rect.size.y > 8:
		canvas.draw_rect(rect.grow(-3), Color(PAPER if prominent else BRASS, 0.28 + focus * 0.15), false, 1.0)
		canvas.draw_line(rect.position + Vector2(4, 3), Vector2(rect.end.x - 4, rect.position.y + 3), Color(PAPER, 0.32), 1.0)
