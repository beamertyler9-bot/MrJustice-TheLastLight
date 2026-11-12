extends RefCounted
## Specialist merchants. Each town has a few: the general store, a blacksmith, an
## alchemist, a grocer, an angler and a curio dealer (plus the caravan traders on the
## roads). Each one sells its own kind of goods, buys back the same kind of thing (often
## paying a little more than anyone else for it), and its prices depend on the region:
## what a land makes is cheap there, and what it lacks is dear.

const Catalog = preload("res://scripts/crafting.gd")

const SHOPS := {
	"general": {"title": "General Store", "blurb": "Timber, stone, rope and camp gear.",
		"sells": ["wood", "planks", "stone", "stick", "string", "crafting_table", "camp_kit", "coffee_bean", "herb"],
		"buys": ["wood", "planks", "stone", "stick", "string", "herb", "coffee_bean"]},
	"blacksmith": {"title": "Blacksmith", "blurb": "Weapons, armor and tools, and the iron to make them.",
		"sells": ["makeshift_axe", "stone_axe", "stone_pickaxe", "iron_blade", "plated_chest", "stamina_coil", "spring_boots", "grapple_spool", "iron", "stone"],
		"buys": ["iron", "stone", "crystal", "ancient_core"]},
	"alchemist": {"title": "Alchemist", "blurb": "Tonics, mana potions and what goes into them.",
		"sells": ["tonic", "mana_potion", "herb", "crystal", "coffee"],
		"buys": ["herb", "crystal", "tonic", "mana_potion"]},
	"grocer": {"title": "Grocer", "blurb": "Camp food, sweets and coffee. Buys fresh fish for the kitchen.",
		"sells": ["marshmallow", "chocolate_bar", "graham_cracker", "roasted_marshmallow", "smore", "coffee_bean", "coffee"],
		"buys": ["marshmallow", "chocolate_bar", "graham_cracker", "coffee_bean", "lake_fish", "silver_trout", "reed_perch"]},
	"angler": {"title": "Angler", "blurb": "Rods and line. Pays the best prices for every fish.",
		"sells": ["fishing_rod", "string", "coffee", "roasted_marshmallow"],
		"buys": ["lake_fish", "silver_trout", "reed_perch", "golden_carp", "moon_eel", "crystal_koi", "cola_carp", "fizzfin", "frost_char", "sunscale_bream", "string"]},
	"curio": {"title": "Curio Dealer", "blurb": "Rare and strange things from every corner of the land.",
		"sells": ["crystal", "relic", "ancient_core", "mana_potion"],
		"buys": ["relic", "ancient_core", "crystal", "golden_carp", "moon_eel", "crystal_koi"]},
	"trader": {"title": "Caravan Trader", "blurb": "A bit of everything for the road. Buys fish.",
		"sells": ["tonic", "coffee", "marshmallow", "camp_kit", "string", "wood"],
		"buys": ["lake_fish", "silver_trout", "reed_perch", "golden_carp", "wood", "herb"]},
}

## Prices for things the catalog doesn't sell by itself (tools, weapons, armor).
const PRICES := {
	"makeshift_axe": 14, "stone_axe": 28, "stone_pickaxe": 28, "iron_blade": 65, "fishing_rod": 22,
	"plated_chest": 140, "stamina_coil": 90, "spring_boots": 100, "grapple_spool": 100,
	"crafting_table": 16, "planks": 2, "relic": 45, "ancient_core": 90,
}

## What each land makes (cheap there) and lacks (dear there).
const REGIONS := {
	9: {"name": "Mosswake Valley", "cheap": ["wood", "planks", "stick", "herb", "silver_trout", "tonic"], "dear": ["crystal"]},
	10: {"name": "S'morewood", "cheap": ["marshmallow", "chocolate_bar", "graham_cracker", "roasted_marshmallow", "smore", "coffee", "cola_carp", "fizzfin"], "dear": ["iron", "stone_pickaxe"]},
	11: {"name": "Windbell Plains", "cheap": ["coffee_bean", "coffee", "string", "wood", "reed_perch", "spring_boots"], "dear": ["crystal", "mana_potion"]},
	12: {"name": "Sunspire Dunes", "cheap": ["crystal", "relic", "sunscale_bream"], "dear": ["herb", "wood", "tonic", "coffee"]},
	13: {"name": "Ashfall Caldera", "cheap": ["iron", "stone", "iron_blade", "plated_chest", "stamina_coil", "stone_axe", "stone_pickaxe"], "dear": ["herb", "marshmallow", "chocolate_bar", "graham_cracker"]},
	14: {"name": "Hollowmourn", "cheap": ["relic", "mana_potion", "moon_eel"], "dear": ["coffee", "smore", "tonic"]},
	15: {"name": "Prismere", "cheap": ["crystal", "mana_potion", "crystal_koi", "ancient_core"], "dear": ["iron", "wood"]},
}
const CHEAP := 0.75
const DEAR := 1.3
const SPECIALIST := 1.25


static func kind(shop: String) -> String:
	if shop == "smith": return "blacksmith"
	return shop if SHOPS.has(shop) else "general"


static func title(shop: String) -> String: return str(SHOPS[kind(shop)].title)
static func blurb(shop: String) -> String: return str(SHOPS[kind(shop)].blurb)


static func stock(shop: String) -> Array:
	return SHOPS[kind(shop)].sells.filter(func (id): return Catalog.ITEMS.has(id))


static func buys(shop: String, id: String) -> bool:
	return id in SHOPS[kind(shop)].buys and Catalog.ITEMS.has(id)


static func _regional(id: String, region: int) -> float:
	var info: Dictionary = REGIONS.get(region, {})
	if id in info.get("cheap", []): return CHEAP
	if id in info.get("dear", []): return DEAR
	return 1.0


static func buy_price(id: String, shop: String, region: int) -> int:
	var base := int(PRICES.get(id, int(Catalog.ITEMS.get(id, {}).get("buy", 0))))
	if base <= 0: return 0
	return maxi(1, roundi(base * _regional(id, region)))


static func sell_price(id: String, shop: String, region: int) -> int:
	var base := int(Catalog.ITEMS.get(id, {}).get("sell", 0))
	if base <= 0 or not buys(shop, id): return 0
	# A specialist pays more for their own trade's goods; a land pays more for what it lacks.
	var factor := SPECIALIST if kind(shop) in ["angler", "curio", "alchemist", "blacksmith"] else 1.0
	if id in REGIONS.get(region, {}).get("dear", []): factor *= DEAR
	return maxi(1, roundi(base * factor))


## One line on how this region's prices lean (for the shop screen).
static func region_note(region: int) -> String:
	var info: Dictionary = REGIONS.get(region, {})
	if info.is_empty(): return ""
	var cheap: Array = info.cheap.slice(0, 3).map(func (id): return Catalog.item_name(id).to_lower())
	var dear: Array = info.dear.slice(0, 2).map(func (id): return Catalog.item_name(id).to_lower())
	return "%s: %s are cheap here; %s are dear." % [info.name, ", ".join(cheap), " and ".join(dear)]
