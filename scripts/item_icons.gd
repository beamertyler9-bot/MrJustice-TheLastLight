extends RefCounted

const Index = preload("res://scripts/item_icon_catalog.gd")
const ATLAS = preload("res://assets/items/item_atlas.png")
const PAINTED_ATLAS = preload("res://assets/ui_lantern_ledger/item-icons-padded.png")
const MANA_POTION = preload("res://assets/ui_lantern_ledger/mana-potion.png")
const LIGHT_ESSENCE = preload("res://assets/items/light-essence.svg")
const FOOD_ATLAS = preload("res://assets/items/camp-food.svg")
const FOOD_IDS = ["chocolate_bar", "graham_cracker", "smore"]
const QUEST_ATLAS = preload("res://assets/items/quest-keepsakes.svg")
const QUEST_IDS = ["quest_seed_satchel", "quest_lost_spindle", "quest_market_manifest", "quest_forgotten_pattern", "quest_rowans_locket", "quest_tuning_fork", "quest_pantry_beans", "quest_forge_fuel", "quest_garden_wall", "quest_camp_supper", "quest_willow_remedy", "quest_hesters_alloy", "quest_warm_cups", "quest_core_for_bramm", "quest_provisions_for_the_pass", "quest_scrapper_voice_coil", "quest_scrapper_quarry_chime", "quest_scrapper_fen_whistle", "quest_scrapper_ash_musicbox"]
static var _textures: Dictionary = {}

static func texture(id: String) -> AtlasTexture:
	if _textures.has(id): return _textures[id]
	if id in QUEST_IDS:
		var keepsake = AtlasTexture.new(); keepsake.atlas = QUEST_ATLAS; keepsake.region = Rect2(QUEST_IDS.find(id) * 128, 0, 128, 128); keepsake.filter_clip = true; _textures[id] = keepsake; return keepsake
	if id == "shard":
		var orb = AtlasTexture.new(); orb.atlas = LIGHT_ESSENCE; orb.region = Rect2(Vector2.ZERO, LIGHT_ESSENCE.get_size()); orb.filter_clip = true; _textures[id] = orb; return orb
	if id in FOOD_IDS:
		var food = AtlasTexture.new(); food.atlas = FOOD_ATLAS; food.region = Rect2(FOOD_IDS.find(id) * 128, 0, 128, 128); food.filter_clip = true; _textures[id] = food; return food
	if id == "mana_potion":
		var bottle = AtlasTexture.new()
		bottle.atlas = MANA_POTION
		bottle.region = Rect2(Vector2.ZERO, MANA_POTION.get_size())
		bottle.filter_clip = true
		_textures[id] = bottle
		return bottle
	var index: int = Index.IDS.find(id)
	if index < 0: return null
	var picture = AtlasTexture.new()
	picture.atlas = PAINTED_ATLAS if PAINTED_ATLAS != null else ATLAS
	picture.region = Rect2((index % Index.COLUMNS) * Index.CELL_SIZE, (index / Index.COLUMNS) * Index.CELL_SIZE, Index.CELL_SIZE, Index.CELL_SIZE)
	picture.filter_clip = true
	_textures[id] = picture
	return picture
