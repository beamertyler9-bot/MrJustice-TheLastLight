extends RefCounted
## Where every item comes from and what it's for, worked out from the catalog itself
## (recipes, merchants, food, gear), so the item screens can always say both.

const Catalog = preload("res://scripts/crafting.gd")
const Merchants = preload("res://scripts/merchants.gd")
const Food = preload("res://scripts/food.gd")
const Gathering = preload("res://scripts/regional_gathering.gd")

const REGION_NAMES := {9: "Mosswake Valley", 10: "S'morewood", 11: "Windbell Plains", 12: "Sunspire Dunes", 13: "Ashfall Caldera", 14: "Hollowmourn", 15: "Prismere"}

## How the older, everyday things are found out in the world.
const ORIGINS := {
	"wood": "Chop trees with an axe", "stick": "Picked up under trees; shaken loose when chopping",
	"stone": "Break boulders and rocks", "iron": "Mine ore veins with a pickaxe",
	"crystal": "Mine crystal clusters in caves and Prismere", "herb": "Picked from herb patches",
	"coffee_bean": "Picked from coffee bushes on the plains", "string": "Spun at a bench, found in chests",
	"marshmallow": "Found in S'morewood and camp chests", "chocolate_bar": "Found in S'morewood",
	"graham_cracker": "Found in S'morewood", "relic": "Ruins, dungeon chests and expedition rewards",
	"ancient_core": "Dropped by the deep guardians", "shard": "Light Essence from foes, chests and quests",
	"lake_fish": "Caught anywhere you fish", "silver_trout": "Caught in rivers and cold lakes",
	"reed_perch": "Caught in reedy lakes", "golden_carp": "A rare catch, best in S'morewood",
	"moon_eel": "Caught in Hollowmourn and Prismere", "crystal_koi": "Caught in Prismere's lakes",
	"cola_carp": "Caught in S'morewood's cola waters", "fizzfin": "Caught in S'morewood's cola waters",
	"frost_char": "Caught in Hollowmourn's cold waters", "sunscale_bream": "Caught in Prismere and warm lakes",
	"grimoire": "Yours from the start", "fists": "Your own two hands", "dawn_blade": "The Bellkeeper's sword, found deep in the Dawnbell's story",
}


static func _names(ids: Array) -> String:
	return ", ".join(ids.map(func (id): return Catalog.item_name(id)))


static func _shops(ids: Array) -> String:
	return ", ".join(ids.map(func (shop): return Merchants.title(shop)))


## "From: ..." — gathered, caught, crafted, sold by.
static func from_text(id: String) -> String:
	var parts: Array = []
	for region in Gathering.RESOURCES:
		if id in Gathering.RESOURCES[region]: parts.append("Gathered beside the roads of " + REGION_NAMES[region])
	if ORIGINS.has(id): parts.append(ORIGINS[id])
	for recipe_id in Catalog.RECIPES:
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if str(recipe.get("output", "")) == id:
			var station := str(recipe.get("station", ""))
			parts.append("Crafted" + (" at a camp" if station == "camp" else " at a workbench" if station == "bench" else " anywhere"))
			break
	var sellers: Array = []
	for shop in Merchants.SHOPS:
		if id in Merchants.SHOPS[shop].sells and not shop in sellers: sellers.append(shop)
	if not sellers.is_empty(): parts.append("Sold by the " + _shops(sellers))
	if id.begins_with("quest_"): parts.append("A quest keepsake")
	return "; ".join(parts)


## "Used for: ..." — crafting, eating, equipping, selling.
static func uses_text(id: String) -> String:
	var parts: Array = []
	if Food.is_food(id): parts.append("Eat: " + Food.effect_text(id))
	if Catalog.WEAPONS.has(id) or id in ["makeshift_axe", "stone_axe", "stone_pickaxe", "iron_blade", "dawn_blade", "fishing_rod"]: parts.append("Equip it from the satchel")
	if Catalog.UPGRADES.has(id): parts.append("Fit it as gear")
	var makes: Array = []
	for recipe_id in Catalog.RECIPES:
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if recipe.get("needs", {}).has(id):
			var out := str(recipe.get("output", recipe_id))
			if not out in makes: makes.append(out)
	if not makes.is_empty(): parts.append("Makes " + _names(makes.slice(0, 4)) + (" and more" if makes.size() > 4 else ""))
	var buyers: Array = []
	for shop in Merchants.SHOPS:
		if Merchants.buys(shop, id): buyers.append(shop)
	if not buyers.is_empty(): parts.append("Sell to the " + _shops(buyers.slice(0, 3)))
	elif int(Catalog.ITEMS.get(id, {}).get("sell", 0)) > 0: parts.append("Sells to any merchant")
	if id.begins_with("quest_"): parts.append("Bring it to whoever asked for it")
	if id == "shard": parts.append("The coin of the land: buy from any merchant and learn spells at the altars")
	return "; ".join(parts)


## The description plus the two lines, for item screens.
static func full_text(id: String) -> String:
	var text := str(Catalog.ITEMS.get(id, {}).get("description", ""))
	var from := from_text(id); var uses := uses_text(id)
	if from != "": text += "\nFrom: " + from + "."
	if uses != "": text += "\nUsed for: " + uses + "."
	return text.strip_edges()
