extends RefCounted


const QuestItems = preload("res://scripts/quest_items.gd")
const ITEMS: Dictionary = {
	"string": {"name": "String", "description": "Braided cord for fishing tackle.", "buy": 3, "sell": 1, "glyph": "◎"},
	"fishing_rod": {"name": "Fishing rod", "description": "Craft from three timber planks and two string. Use at a fishing dock.", "buy": 0, "sell": 8, "glyph": "/"},
	"silver_trout": {"name": "Silver trout", "description": "A silver trout. Sell your catch to a merchant.", "buy": 0, "sell": 8, "glyph": "♓"},
	"reed_perch": {"name": "Reed perch", "description": "A reed perch. Sell your catch to a merchant.", "buy": 0, "sell": 10, "glyph": "♓"},
	"golden_carp": {"name": "Golden carp", "description": "A golden carp. Sell your catch to a merchant.", "buy": 0, "sell": 12, "glyph": "♓"},
	"moon_eel": {"name": "Moon eel", "description": "A moon eel. Sell your catch to a merchant.", "buy": 0, "sell": 14, "glyph": "♓"},
	"crystal_koi": {"name": "Crystal koi", "description": "A crystal koi. Sell your catch to a merchant.", "buy": 0, "sell": 16, "glyph": "♓"},
	"cola_carp": {"name": "Cola carp", "description": "A cola carp. Sell your catch to a merchant.", "buy": 0, "sell": 18, "glyph": "♓"},
	"fizzfin": {"name": "Fizzfin", "description": "A fizzfin. Sell your catch to a merchant.", "buy": 0, "sell": 20, "glyph": "♓"},
	"frost_char": {"name": "Frost char", "description": "A frost char. Sell your catch to a merchant.", "buy": 0, "sell": 22, "glyph": "♓"},
	"sunscale_bream": {"name": "Sunscale bream", "description": "A sunscale bream. Sell your catch to a merchant.", "buy": 0, "sell": 24, "glyph": "♓"},
	"lake_fish": {"name": "Lake bass", "description": "A fresh catch from a lakeside outpost. Wandering traders buy it for six Light Essence.", "buy": 0, "sell": 6, "glyph": "♓"},
	"quest_seed_satchel": {"name": "Juniper’s seed satchel", "description": "A stitched green seed pouch, tied with Juniper’s leaf clasp. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "satchel", "color": "#719951"},
	"quest_lost_spindle": {"name": "Lethiel’s silver spindle", "description": "A narrow silver spindle with her mother’s blue ribbon. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "spindle", "color": "#7dbbdd"},
	"quest_market_manifest": {"name": "Mara’s market ledger", "description": "A red leather ledger with numbered brass corners. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "book", "color": "#b9524d"},
	"quest_forgotten_pattern": {"name": "Ilyra’s pattern case", "description": "An indigo scroll tube holding winter sketches. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "tube", "color": "#777eb7"},
	"quest_rowans_locket": {"name": "Rowan’s copper locket", "description": "A heart shaped copper keepsake with a small portrait. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "locket", "color": "#d09164"},
	"quest_tuning_fork": {"name": "Ilyra’s tuning fork", "description": "A brass two pronged fork, wrapped in violet loom thread. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "fork", "color": "#c3a76b"},
	"quest_pantry_beans": {"name": "Rowan’s whistling kettle", "description": "A copper travel kettle lost on the north road; its whistle welcomes tired travelers. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "kettle", "color": "#b97a55"},
	"quest_forge_fuel": {"name": "Bramm’s hearth bellows", "description": "The smith’s red bellows, with the little forge stamp on its nozzle. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "bellows", "color": "#b04f3f"},
	"quest_garden_wall": {"name": "Tansy’s mason plumb", "description": "A brass plumb bob and waxed green cord for the village wall. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "plumb", "color": "#b1b96a"},
	"quest_camp_supper": {"name": "Nim’s star cake tin", "description": "A scalloped tin shaped like the baker’s festival star. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "star", "color": "#e1c58b"},
	"quest_willow_remedy": {"name": "Sable’s remedy press", "description": "A jade herb press that measures remedies safely for the watch. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "press", "color": "#6da58b"},
	"quest_hesters_alloy": {"name": "Hester’s alloy die", "description": "A square steel test die etched with a bright copper sun. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "die", "color": "#8eaab5"},
	"quest_warm_cups": {"name": "Pella’s dawn cup", "description": "A blue cup with a crescent handle, missing from the apprentices’ tray. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "cup", "color": "#7caec7"},
	"quest_core_for_bramm": {"name": "Bramm’s core tongs", "description": "Long iron tongs with a red insulated grip for old guardian cores. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "tongs", "color": "#bc7857"},
	"quest_provisions_for_the_pass": {"name": "Gorrin’s trail compass", "description": "A brass compass with a green north needle for the relief crew. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "compass", "color": "#9ab77b"},
	"quest_scrapper_voice_coil": {"name": "Stolen dawn voice coil", "description": "A glass sound spool holding the village dawn bell; Dissonance marked it for a drone. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "coil", "color": "#bb82df"},
	"quest_scrapper_quarry_chime": {"name": "Dori’s quarry chime", "description": "A three tube copper chime used to signal stonecutters home. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "chime", "color": "#daaf67"},
	"quest_scrapper_fen_whistle": {"name": "Juniper’s reed whistle", "description": "A green reed whistle with two finger holes, taken while the garden fell silent. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "whistle", "color": "#89bd82"},
	"quest_scrapper_ash_musicbox": {"name": "Pella’s ember music box", "description": "A blackened red music box with a brass winding key; a lullaby survived inside. Return only to its owner.", "buy": 0, "sell": 0, "glyph": "♫", "quest": true, "shape": "musicbox", "color": "#d47769"},
	"chocolate_bar": {"name": "Chocolate bar", "description": "Gathered from chocolate trees. One layer of a camp s'more.", "buy": 4, "sell": 1, "glyph": "▦"},
	"graham_cracker": {"name": "Graham cracker", "description": "Crisp fruit from a graham tree, ready for camp cooking.", "buy": 3, "sell": 1, "glyph": "▤"},
	"smore": {"name": "Camp s'more", "description": "Marshmallow and chocolate between graham crackers. Restores three health.", "buy": 12, "sell": 4, "glyph": "▰"},
	"grimoire": {"name": "Grimoire", "description": "Equip this living spellbook as your weapon. Browse the spell collection and assign four spells to your quick slots.", "buy": 0, "sell": 0, "glyph": "✦"},
	"shard": {"name": "Light Essence", "description": "A warm golden mote of light; the frontier's trading currency.", "buy": 0, "sell": 0, "glyph": "●"},
	"tonic": {"name": "Lantern Tonic", "description": "Restores three health. Brew two herbs beside a lit campfire.", "buy": 12, "sell": 5, "glyph": "+"},
	"mana_potion": {"name": "Mana Potion", "description": "Restores 50 mana. A familiar tonic bottle filled with blue liquid.", "buy": 12, "sell": 5, "glyph": "✦"},
	"relic": {"name": "Old relic", "description": "A fragment of the lost frontier.", "buy": 0, "sell": 20, "glyph": "◈"},
	"wood": {"name": "Timber", "description": "Fresh timber for shelters and handles.", "buy": 4, "sell": 1, "glyph": "▥"},
	"planks": {"name": "Timber planks", "description": "Cut boards for tables and sturdy handles.", "buy": 0, "sell": 1, "glyph": "▤"},
	"crafting_table": {"name": "Crafting table", "description": "Place a table to work on larger 3 by 3 recipes.", "buy": 0, "sell": 4, "glyph": "▦"},
	"makeshift_axe": {"name": "Makeshift axe", "description": "A stone and branch axe for felling timber.", "buy": 0, "sell": 0, "glyph": "⚒"},
	"stone_axe": {"name": "Stone axe", "description": "A sturdy axe that fells trees faster.", "buy": 0, "sell": 0, "glyph": "⚒"},
	"stone_pickaxe": {"name": "Stone pickaxe", "description": "Break solid rock and mine ore deposits.", "buy": 0, "sell": 0, "glyph": "⚒"},
	"stone": {"name": "Stone", "description": "A hard piece of frontier rock.", "buy": 3, "sell": 1, "glyph": "⬡"},
	"stick": {"name": "Stick", "description": "A straight branch for camp tools.", "buy": 2, "sell": 1, "glyph": "/"},
	"iron": {"name": "Iron ore", "description": "Useful metal from the mine.", "buy": 8, "sell": 3, "glyph": "▰"},
	"crystal": {"name": "Crystal", "description": "A clear conductor for old machinery.", "buy": 10, "sell": 4, "glyph": "◇"},
	"herb": {"name": "Herb", "description": "An aromatic healing sprig.", "buy": 4, "sell": 1, "glyph": "✣"},
	"coffee_bean": {"name": "Coffee beans", "description": "Brew two handfuls over a camp fire.", "buy": 3, "sell": 1, "glyph": "●"},
	"marshmallow": {"name": "Marshmallow", "description": "Ready to roast at a camp.", "buy": 3, "sell": 1, "glyph": "□"},
	"camp_kit": {"name": "Camp kit", "description": "Place on clear dry ground to make a camp.", "buy": 40, "sell": 10, "glyph": "△"},
	"coffee": {"name": "Camp coffee", "description": "Restores one health.", "buy": 10, "sell": 3, "glyph": "☕"},
	"roasted_marshmallow": {"name": "Roasted marshmallow", "description": "Restores two health.", "buy": 8, "sell": 2, "glyph": "♨"},
	"iron_blade": {"name": "Iron blade", "description": "A quick forged weapon with extra reach.", "buy": 0, "sell": 0, "glyph": "†"},
	"spring_boots": {"name": "Spring boots", "description": "Jump higher with a spring in every step.", "buy": 0, "sell": 0, "glyph": "↟"},
	"grapple_spool": {"name": "Grapple spool", "description": "Extends the reach of your grapple.", "buy": 0, "sell": 0, "glyph": "◎"},
	"plated_chest": {"name": "Plated chest", "description": "Adds two maximum health.", "buy": 0, "sell": 0, "glyph": "▣"},
	"stamina_coil": {"name": "Heart coil", "description": "Adds one maximum health.", "buy": 0, "sell": 0, "glyph": "♥"},
	"ancient_core": {"name": "Ancient core", "description": "A living crystal from the deep guardians. Forge it into Warden plate.", "buy": 0, "sell": 25, "glyph": "◈"},
	"dawn_blade": {"name": "Dawn blade", "description": "The Bellkeeper's legendary radiant sword. A swift cut with exceptional power and reach.", "buy": 0, "sell": 0, "glyph": "†"},
	"warden_plate": {"name": "Warden plate", "description": "Core-forged armor. Adds two maximum health, alongside your other fitted gear.", "buy": 0, "sell": 0, "glyph": "▣"}
}
const RECIPES: Dictionary = {
	"fishing_rod": {"name": "Fishing rod", "category": "Tools", "needs": {"planks": 3, "string": 2}, "output": "fishing_rod", "amount": 1, "upgrade": false, "description": "Fit a flexible timber rod with a cord line and reel.", "station": "field", "size": 2},
	"smore": {"name": "Camp s'more", "category": "Supplies", "needs": {"marshmallow": 1, "chocolate_bar": 1, "graham_cracker": 1}, "output": "smore", "amount": 1, "upgrade": false, "description": "Toast a marshmallow with chocolate and a graham cracker beside a lit campfire. Restores three health.", "station": "camp", "size": 2},
	"planks": {"name": "Timber planks", "category": "Materials", "needs": {"wood": 1}, "output": "planks", "amount": 4, "upgrade": false, "description": "Saw one timber into four boards.", "station": "field", "size": 2},
	"stick": {"name": "Sticks", "category": "Materials", "needs": {"planks": 2}, "output": "stick", "amount": 4, "upgrade": false, "description": "Stack two boards to cut four handles.", "station": "field", "size": 2},
	"crafting_table": {"name": "Crafting table", "category": "Camp", "needs": {"planks": 4}, "output": "crafting_table", "amount": 1, "upgrade": false, "description": "Join four boards into a portable workshop.", "station": "field", "size": 2},
	"makeshift_axe": {"name": "Makeshift axe", "category": "Tools", "needs": {"stone": 1, "stick": 1}, "output": "makeshift_axe", "amount": 1, "upgrade": false, "description": "Tie a stone diagonally above a branch.", "station": "field", "size": 2},
	"stone_axe": {"name": "Stone axe", "category": "Tools", "needs": {"stone": 3, "stick": 2}, "output": "stone_axe", "amount": 1, "upgrade": false, "description": "Build a broad stone head on a straight handle.", "station": "bench", "size": 3},
	"stone_pickaxe": {"name": "Stone pickaxe", "category": "Tools", "needs": {"stone": 3, "stick": 2}, "output": "stone_pickaxe", "amount": 1, "upgrade": false, "description": "Fit a three-stone mining head above a long handle.", "station": "bench", "size": 3},
	"camp_kit": {"name": "Camp kit", "category": "Camp", "needs": {"wood": 6, "stone": 4, "stick": 2}, "output": "camp_kit", "amount": 1, "upgrade": false, "description": "Assemble a tent, fire and kettle.", "station": "bench", "size": 3},
	"coffee": {"name": "Camp coffee", "category": "Supplies", "needs": {"coffee_bean": 2}, "output": "coffee", "amount": 1, "upgrade": false, "description": "Brew a warm drink at your camp. Restores one health.", "station": "camp", "size": 2},
	"tonic": {"name": "Lantern Tonic", "category": "Supplies", "needs": {"herb": 2}, "output": "tonic", "amount": 1, "upgrade": false, "description": "Simmer two herbs over a lit campfire. Restores three health.", "station": "camp", "size": 2},
	"mana_potion": {"name": "Mana Potion", "category": "Supplies", "needs": {"herb": 1, "crystal": 1}, "output": "mana_potion", "amount": 1, "upgrade": false, "description": "Infuse one herb with one crystal at a lit campfire. Restores 50 mana.", "station": "camp", "size": 2},
	"roasted_marshmallow": {"name": "Roasted marshmallow", "category": "Supplies", "needs": {"marshmallow": 1}, "output": "roasted_marshmallow", "amount": 1, "upgrade": false, "description": "Toast over the fire until golden.", "station": "camp", "size": 2},
	"plated_chest": {"name": "Plated chest", "category": "Gear", "needs": {"iron": 6, "wood": 2}, "output": "plated_chest", "amount": 1, "upgrade": true, "description": "Fit protective iron plates. +2 maximum health.", "station": "bench", "size": 3},
	"stamina_coil": {"name": "Heart coil", "category": "Gear", "needs": {"iron": 4, "crystal": 3}, "output": "stamina_coil", "amount": 1, "upgrade": true, "description": "Wire a protective heart coil. +1 maximum health.", "station": "bench", "size": 3},
	"spring_boots": {"name": "Spring boots", "category": "Gadgets", "needs": {"iron": 3, "crystal": 2, "herb": 2}, "output": "spring_boots", "amount": 1, "upgrade": true, "description": "Fit spring-loaded heels for higher jumps.", "station": "bench", "size": 3},
	"grapple_spool": {"name": "Grapple spool", "category": "Gadgets", "needs": {"iron": 4, "stick": 3, "crystal": 2}, "output": "grapple_spool", "amount": 1, "upgrade": true, "description": "Wind a longer grapple cable.", "station": "bench", "size": 3},
	"iron_blade": {"name": "Iron blade", "category": "Weapons", "needs": {"iron": 5, "wood": 2}, "output": "iron_blade", "amount": 1, "upgrade": false, "description": "Forge a keen blade for quick strikes.", "station": "bench", "size": 3},
	"warden_plate": {"name": "Warden plate", "category": "Gear", "needs": {"ancient_core": 3, "iron": 8, "crystal": 4}, "output": "warden_plate", "amount": 1, "upgrade": true, "description": "Forge the deep guardians' cores into legendary armor. +2 maximum health.", "station": "bench", "size": 3}
}
const SHOPS: Dictionary = {
	"general": ["string", "tonic", "mana_potion", "wood", "stone", "stick", "herb", "coffee_bean", "marshmallow", "chocolate_bar", "graham_cracker", "camp_kit"],
	"smith": ["string", "iron", "crystal", "stone", "wood"]
}
const WEAPONS: Dictionary = {
	"grimoire": {"name": "Grimoire", "damage": 0, "reach": 18.0, "speed": 1.0, "tool": "", "magic": true},
	"makeshift_axe": {"name": "Makeshift axe", "damage": 1, "reach": 2.2, "speed": 0.9, "tool": "axe"},
	"stone_axe": {"name": "Stone axe", "damage": 2, "reach": 2.2, "speed": 1.0, "tool": "axe"},
	"stone_pickaxe": {"name": "Stone pickaxe", "damage": 2, "reach": 2.3, "speed": 0.9, "tool": "pickaxe"},
	"fists": {"name": "Fists", "damage": 1, "reach": 1.9, "speed": 1.0, "tool": ""},
	"iron_blade": {"name": "Iron blade", "damage": 2, "reach": 2.5, "speed": 1.05, "tool": ""},
	"dawn_blade": {"name": "Dawn blade", "damage": 4, "reach": 2.85, "speed": 1.1, "tool": ""}
}
const UPGRADES: Dictionary = {
	"plated_chest": {"health": 2}, "stamina_coil": {"health": 1},
	"spring_boots": {"jump_multiplier": 1.2}, "grapple_spool": {"grapple_range": 8.0},
	"warden_plate": {"health": 2}
}

static func item_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", "Fists" if id == "fists" else id.capitalize()))

static func recipe_name(id: String) -> String:
	return str(RECIPES.get(id, {}).get("name", id.capitalize()))

static func categories() -> Array:
	return ["Materials", "Tools", "Camp", "Supplies", "Gear", "Gadgets", "Weapons"]

static func recipe_ids(category: String = "") -> Array:
	var result: Array = []
	for id in RECIPES:
		if category.is_empty() or RECIPES[id].category == category:
			result.append(id)
	return result

static func weapon_metadata(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS.fists).duplicate(true)

static func upgrade_metadata(id: String) -> Dictionary:
	return UPGRADES.get(id, {}).duplicate(true)



const PATTERNS: Dictionary = {
	"fishing_rod": {"rows": ["PP", "PS"], "cells": {"P": {"item": "planks", "amount": 1}, "S": {"item": "string", "amount": 2}}},
	"smore": {"rows": ["MC", "G."], "cells": {"M": {"item": "marshmallow", "amount": 1}, "C": {"item": "chocolate_bar", "amount": 1}, "G": {"item": "graham_cracker", "amount": 1}}},
	"planks": {"rows": ["W"], "cells": {"W": {"item": "wood", "amount": 1}}},
	"stick": {"rows": ["P", "P"], "cells": {"P": {"item": "planks", "amount": 1}}},
	"crafting_table": {"rows": ["PP", "PP"], "cells": {"P": {"item": "planks", "amount": 1}}},
	"makeshift_axe": {"rows": ["S.", ".T"], "cells": {"S": {"item": "stone", "amount": 1}, "T": {"item": "stick", "amount": 1}}},
	"stone_axe": {"rows": ["SS.", "ST.", ".T."], "cells": {"S": {"item": "stone", "amount": 1}, "T": {"item": "stick", "amount": 1}}},
	"stone_pickaxe": {"rows": ["SSS", ".T.", ".T."], "cells": {"S": {"item": "stone", "amount": 1}, "T": {"item": "stick", "amount": 1}}},
	"camp_kit": {"rows": ["W.W", ".T.", "S.S"], "cells": {"W": {"item": "wood", "amount": 3}, "T": {"item": "stick", "amount": 2}, "S": {"item": "stone", "amount": 2}}},
	"coffee": {"rows": ["B"], "cells": {"B": {"item": "coffee_bean", "amount": 2}}},
	"tonic": {"rows": ["HH"], "cells": {"H": {"item": "herb", "amount": 1}}},
	"mana_potion": {"rows": ["HC"], "cells": {"H": {"item": "herb", "amount": 1}, "C": {"item": "crystal", "amount": 1}}},
	"roasted_marshmallow": {"rows": ["M"], "cells": {"M": {"item": "marshmallow", "amount": 1}}},
	"plated_chest": {"rows": ["I.I", "III", "WIW"], "cells": {"I": {"item": "iron", "amount": 1}, "W": {"item": "wood", "amount": 1}}},
	"stamina_coil": {"rows": ["ICI", "CIC", ".I."], "cells": {"I": {"item": "iron", "amount": 1}, "C": {"item": "crystal", "amount": 1}}},
	"spring_boots": {"rows": ["I.I", "C.C", "HIH"], "cells": {"I": {"item": "iron", "amount": 1}, "C": {"item": "crystal", "amount": 1}, "H": {"item": "herb", "amount": 1}}},
	"grapple_spool": {"rows": ["ITI", "TCT", "I.I"], "cells": {"I": {"item": "iron", "amount": 1}, "T": {"item": "stick", "amount": 1}, "C": {"item": "crystal", "amount": 2}}},
	"iron_blade": {"rows": [".A.", ".B.", "W.W"], "cells": {"A": {"item": "iron", "amount": 2}, "B": {"item": "iron", "amount": 3}, "W": {"item": "wood", "amount": 1}}},
	"warden_plate": {"rows": ["ICI", "ACA", "IBI"], "cells": {"I": {"item": "iron", "amount": 2}, "C": {"item": "crystal", "amount": 2}, "A": {"item": "ancient_core", "amount": 1}, "B": {"item": "ancient_core", "amount": 1}}}
}

static func max_stack(id: String) -> int:
	if id == "fishing_rod" or QuestItems.is_quest(id): return 1
	if (WEAPONS.has(id) and id != "fists") or UPGRADES.has(id):
		return 1
	return 64 if ITEMS.has(id) else 0

static func recipe_grid(id: String, size: int) -> Array:
	if size not in [2, 3] or not PATTERNS.has(id) or size < int(RECIPES[id].size):
		return []
	var result: Array = []
	for i in range(size * size):
		result.append({})
	var pattern: Dictionary = PATTERNS[id]
	for y in range(pattern.rows.size()):
		for x in range(pattern.rows[y].length()):
			var symbol: String = pattern.rows[y][x]
			if symbol != ".":
				result[y * size + x] = pattern.cells[symbol].duplicate(true)
	return result

static func _valid_grid(grid: Array, size: int) -> bool:
	if size not in [2, 3] or grid.size() != size * size:
		return false
	for cell in grid:
		if not cell is Dictionary:
			return false
		if cell.is_empty():
			continue
		if cell.size() != 2 or not cell.get("item") is String or not cell.has("amount"):
			return false
		var amount = cell.amount
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floorf(float(amount)):
			return false
		if int(amount) < 1 or int(amount) > max_stack(cell.item):
			return false
	return true

static func match_grid(grid: Array, size: int) -> Dictionary:
	if not _valid_grid(grid, size):
		return {}
	for id in PATTERNS:
		if size < int(RECIPES[id].size):
			continue
		var pattern: Dictionary = PATTERNS[id]
		var height: int = pattern.rows.size()
		var width: int = pattern.rows[0].length()
		for mirror in [false, true]:
			for oy in range(size - height + 1):
				for ox in range(size - width + 1):
					var consume: Array[int] = []
					var matches: bool = true
					for index in range(size * size):
						var x: int = index % size - ox
						var y: int = index / size - oy
						var expected: Dictionary = {}
						if x >= 0 and x < width and y >= 0 and y < height:
							var symbol: String = pattern.rows[y][width - 1 - x if mirror else x]
							if symbol != ".":
								expected = pattern.cells[symbol]
						var cell: Dictionary = grid[index]
						if expected.is_empty():
							matches = matches and cell.is_empty()
							consume.append(0)
						else:
							matches = matches and cell.get("item", "") == expected.item and int(cell.get("amount", 0)) >= int(expected.amount)
							consume.append(int(expected.amount))
					if matches:
						return {"id": id, "consume": consume}
	return {}
