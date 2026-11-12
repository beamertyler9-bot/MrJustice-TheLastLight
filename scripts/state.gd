extends RefCounted

const Crafting = preload("res://scripts/crafting.gd")
const Stacks = preload("res://scripts/stack_inventory.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const SpellCollection = preload("res://scripts/spell_collection.gd")
const MAX_ITEMS: int = 9999
const RETIRED_HAMMER_REFUND: Dictionary = {"stone": 7, "wood": 3, "stick": 2}
const MANA_POTION_RESTORE: float = 50.0
const INVENTORY_IDS: Array = ["mossbloom", "oak_resin", "cocoa_pod", "sugar_crystal", "wheat_sheaf", "wind_feather", "sunstone", "cactus_fruit", "obsidian", "ember_ore", "ghost_lily", "grave_silver", "prism_shard", "glow_moss", "hot_cocoa", "fish_stew", "cactus_water", "sugar_drop", "mossbloom_tonic", "string", "fishing_rod", "silver_trout", "reed_perch", "golden_carp", "moon_eel", "crystal_koi", "cola_carp", "fizzfin", "frost_char", "sunscale_bream", "lake_fish", "shard", "tonic", "mana_potion", "relic", "wood", "planks", "crafting_table", "stone", "stick", "iron", "crystal", "herb", "coffee_bean", "marshmallow", "camp_kit", "coffee", "roasted_marshmallow", "ancient_core", "chocolate_bar", "graham_cracker", "smore", "quest_seed_satchel", "quest_lost_spindle", "quest_market_manifest", "quest_forgotten_pattern", "quest_rowans_locket", "quest_tuning_fork", "quest_pantry_beans", "quest_forge_fuel", "quest_garden_wall", "quest_camp_supper", "quest_willow_remedy", "quest_hesters_alloy", "quest_warm_cups", "quest_core_for_bramm", "quest_provisions_for_the_pass", "quest_scrapper_voice_coil", "quest_scrapper_quarry_chime", "quest_scrapper_fen_whistle", "quest_scrapper_ash_musicbox"]

var seed_value: int = 64127
var world_id: String = ""
var terrain_revision: int = 35
var geography_revision: int = 1


var expanded_world: bool = false
var stamina: float = 100.0
var max_stamina: float = 100.0
var health: int = 5
var max_health: int = 5
var speed_bonus: float = 1.0
var items: Dictionary = _new_inventory()
var taken: Dictionary = {}
var world_loot: Array = []
var loot_epoch: int = 0
var shrines: Dictionary = {}
var upgrades: Dictionary = {}
var unlocked: Dictionary = {"grimoire": true}
var equipment: String = "fists"
var selected_hotbar: int = 0
var _slots: Array = []
var workbench_placed: bool = false
var workbench_position: Vector3 = Vector3(0, 4, 0)
var death_echo_active: bool = false
var death_echo_position: Vector3 = Vector3(0, 4, 0)
var death_echo_shards: int = 0
const CampGround = preload("res://scripts/camp_ground.gd")
var camp_clearings: Array = []
var camp_placed: bool = false
var camp_position: Vector3 = Vector3(0, 4, 0)
var settings: Dictionary = {"volume": 0.75, "music": 0.5, "quality": 1, "sensitivity": 0.75, "low_flash": false, "camera_shake": true, "ui_motion": true, "contextual_hud": true}
var player_position: Vector3 = Vector3(0, 4, 0)
var checkpoint: Vector3 = Vector3(0, 4, 0)
var journey_time: float = 0.0
var mana: float = Spellbook.MAX_MANA
var max_mana: float = Spellbook.MAX_MANA
var spellbook: Array = Spellbook.starters()
var spell_slots: Array = SpellCollection.starting_slots()
var active_spell_slot: int = 0

func spell_by_id(id: String) -> Dictionary:
	for spell in spellbook:
		if spell is Dictionary and spell.get("id", "") == id:
			return spell.duplicate(true)
	return SpellCollection.spell_by_id(id)

func collection_spells() -> Array:
	return SpellCollection.entries(spellbook)

func equipped_spell() -> Dictionary:
	if active_spell_slot < 0 or active_spell_slot >= spell_slots.size(): return {}
	return spell_by_id(str(spell_slots[active_spell_slot]))

func select_spell_slot(index: int) -> bool:
	if index < 0 or index >= Spellbook.SLOT_COUNT or index >= spell_slots.size() or spell_by_id(str(spell_slots[index])).is_empty(): return false
	active_spell_slot = index
	return true

func equip_spell(id: String, slot: int = -1) -> bool:
	if slot == -1: slot = active_spell_slot
	if slot < 0 or slot >= Spellbook.SLOT_COUNT or spell_by_id(id).is_empty() or spell_slots.size() != Spellbook.SLOT_COUNT: return false
	spell_slots[slot] = id
	return true

func save_spell(raw: Dictionary) -> bool:
	var clean := Spellbook.sanitize(raw)
	if clean.is_empty(): return false


	if SpellCollection.is_curated(str(clean.id)): return false
	for index in range(spellbook.size()):
		if spellbook[index].get("id", "") == clean.id:
			spellbook[index] = clean
			return true
	if spellbook.size() >= Spellbook.MAX_SPELLS: return false
	spellbook.append(clean)
	return true

func delete_spell(id: String) -> bool:
	if spellbook.size() <= 1: return false
	for index in range(spellbook.size()):
		if spellbook[index].get("id", "") != id: continue
		spellbook.remove_at(index)
		for slot in range(spell_slots.size()):
			if spell_slots[slot] == id: spell_slots[slot] = spellbook[0].id
		return true
	return false

## Developer toggle: spells cost nothing while it is on (kept with the other settings).
func infinite_mana() -> bool:
	return bool(settings.get("dev_infinite_mana", false))

func spend_mana(amount: float) -> bool:
	if infinite_mana():
		mana = max_mana
		return is_finite(amount) and amount >= 0
	if not is_finite(amount) or amount < 0 or not is_finite(mana) or mana < amount: return false
	mana -= amount
	return true

func recover_mana(_dt: float) -> void:

	pass

static func _new_inventory() -> Dictionary:
	var result: Dictionary = {}
	for id in INVENTORY_IDS:
		result[id] = 2 if id == "tonic" else 0
	return result

func spend_stamina(amount: float) -> bool:

	return is_finite(amount) and amount >= 0.0

func recover_stamina(_dt: float) -> void:
	pass

func collect(id: String, kind: String) -> bool:
	return harvest(id, kind, 1)

func add_world_drop(record: Dictionary) -> bool:
	var loot = preload("res://scripts/world_loot.gd")
	if not loot.valid_record(record, MAX_ITEMS) or world_loot.size() >= loot.LIMIT or taken.has(record.id): return false
	for row in world_loot:
		if row.id == record.id: return false
	world_loot.append(record.duplicate(true)); return true

func claim_world_drop(id: String) -> bool:
	for i in range(world_loot.size()):
		var row: Dictionary = world_loot[i]
		if row.id != id: continue
		if not harvest(id, str(row.item), int(row.amount)): return false
		world_loot.remove_at(i); return true
	return false

func award_reward(item: String, amount: int) -> int:


	if item not in INVENTORY_IDS or amount <= 0 or (Crafting.QuestItems.is_quest(item) and int(items.get(item, 0)) + amount > 1):
		return 0
	var granted := clampi(amount, 0, MAX_ITEMS - int(items.get(item, 0)))
	if granted > 0:
		items[item] = int(items.get(item, 0)) + granted
		_reconcile_slots()
	return granted

func harvest(id: String, item: String, amount: int) -> bool:
	if not _valid_id(id) or taken.has(id) or item not in INVENTORY_IDS or amount <= 0 or amount > MAX_ITEMS:
		return false
	if int(items.get(item, 0)) + amount > (1 if Crafting.QuestItems.is_quest(item) else MAX_ITEMS):
		return false
	_reconcile_slots()
	var next_items: Dictionary = items.duplicate()
	next_items[item] = int(items.get(item, 0)) + amount
	var layout: Array = Stacks.reconcile(_slots, _inventory_totals(next_items, unlocked, upgrades), false)
	if layout.is_empty():
		return false
	items = next_items
	_slots = layout
	taken[id] = true
	return true

func activate_shrine(id: String) -> bool:
	if id not in ["beam", "hook", "heart"] or shrines.has(id):
		return false
	shrines[id] = true
	refresh_stats()
	health = max_health
	return true

func has_ability(id: String) -> bool:


	if id in ["beam", "hook"]:
		return true
	return shrines.get(id, false) == true

func refresh_stats() -> void:
	max_health = 5
	for id in Crafting.UPGRADES:
		if upgrades.get(id, false) == true:
			max_health += int(Crafting.UPGRADES[id].get("health", 0))
	# Keepsakes from solving each region's trouble (see story.gd).
	var keepsakes: Dictionary = load("res://scripts/story.gd").keepsake_bonus(taken)
	max_health += int(keepsakes.health)
	max_stamina = 100.0 + float(keepsakes.stamina)
	speed_bonus = 1.0 + float(keepsakes.speed)
	max_mana = Spellbook.MAX_MANA + float(keepsakes.mana)
	# Armor and trinkets can also add mana and run speed.
	for id in Crafting.UPGRADES:
		if upgrades.get(id, false) == true:
			max_mana += float(Crafting.UPGRADES[id].get("mana", 0.0))
			speed_bonus += float(Crafting.UPGRADES[id].get("speed", 0.0))
	mana = clampf(mana, 0.0, max_mana)
	health = clampi(health, 0, max_health)
	stamina = clampf(stamina, 0.0, max_stamina)

func use_tonic() -> bool:
	return use_supply("tonic")

func use_supply(id: String) -> bool:
	if int(items.get(id, 0)) <= 0:
		return false
	if id == "mana_potion":
		if not is_finite(mana) or not is_finite(max_mana) or mana < 0.0 or mana >= max_mana:
			return false
		mana = minf(max_mana, mana + MANA_POTION_RESTORE)
	else:
		var Food = load("res://scripts/food.gd")
		if Food.is_food(id):
			# Treats with a boost can be eaten even at full health.
			if health >= max_health and Food.FOODS[id].boosts.is_empty(): return false
			health = mini(max_health, health + int(Food.FOODS[id].heal))
		else:
			if id not in ["coffee", "tonic"] or health >= max_health:
				return false
			var healing: int = 1 if id == "coffee" else 3
			health = mini(max_health, health + healing)
	items[id] = int(items[id]) - 1
	_reconcile_slots()
	return true

func can_craft(id: String, at_camp: bool = false, at_bench: bool = false) -> bool:
	return not _craft_transaction(id, at_camp, at_bench).is_empty()

func _craft_transaction(id: String, at_camp: bool, at_bench: bool) -> Dictionary:
	if not Crafting.RECIPES.has(id):
		return {}
	var recipe: Dictionary = Crafting.RECIPES[id]
	if (recipe.station == "camp" and not at_camp) or (recipe.station == "bench" and not at_bench):
		return {}
	var output: String = recipe.output
	if recipe.upgrade and upgrades.get(output, false) == true:
		return {}
	if Crafting.WEAPONS.has(output) and unlocked.get(output, false) == true:
		return {}
	if not recipe.upgrade and not Crafting.WEAPONS.has(output) and int(items.get(output, 0)) + int(recipe.amount) > MAX_ITEMS:
		return {}
	for item in recipe.needs:
		if int(items.get(item, 0)) < int(recipe.needs[item]):
			return {}
	_reconcile_slots()
	var next_items: Dictionary = items.duplicate()
	var next_unlocked: Dictionary = unlocked.duplicate()
	var next_upgrades: Dictionary = upgrades.duplicate()
	for item in recipe.needs:
		next_items[item] = int(next_items[item]) - int(recipe.needs[item])
	if recipe.upgrade:
		next_upgrades[output] = true
	elif Crafting.WEAPONS.has(output):
		next_unlocked[output] = true
	else:
		next_items[output] = int(next_items.get(output, 0)) + int(recipe.amount)
	var layout: Array = Stacks.reconcile(_slots, _inventory_totals(next_items, next_unlocked, next_upgrades), false)
	if layout.is_empty():
		return {}
	return {"items": next_items, "unlocked": next_unlocked, "upgrades": next_upgrades, "slots": layout}

func craft_recipe(id: String, at_camp: bool = false, at_bench: bool = false) -> bool:
	var transaction: Dictionary = _craft_transaction(id, at_camp, at_bench)
	if transaction.is_empty():
		return false
	items = transaction.items
	unlocked = transaction.unlocked
	upgrades = transaction.upgrades
	_slots = transaction.slots
	refresh_stats()
	return true

func craft_from_grid(grid: Array, size: int, at_camp: bool = false, at_bench: bool = false) -> String:
	var match: Dictionary = Crafting.match_grid(grid, size)
	if match.is_empty():
		return ""

	var reserved: Dictionary = {}
	for cell in grid:
		if not cell.is_empty():
			reserved[cell.item] = int(reserved.get(cell.item, 0)) + int(cell.amount)
	for item in reserved:
		if int(reserved[item]) > int(items.get(item, 0)):
			return ""
	if not craft_recipe(match.id, at_camp, at_bench):
		return ""
	for index in range(grid.size()):
		var consumed: int = int(match.consume[index])
		if consumed > 0:
			var left: int = int(grid[index].amount) - consumed
			grid[index] = {"item": grid[index].item, "amount": left} if left > 0 else {}
	return match.id

func buy_item(id: String) -> bool:
	if id not in INVENTORY_IDS or not Crafting.ITEMS.has(id):
		return false
	var price: int = int(Crafting.ITEMS[id].buy)
	if price <= 0 or int(items.shard) < price or int(items[id]) >= MAX_ITEMS:
		return false
	var next_items: Dictionary = items.duplicate()
	next_items.shard = int(items.shard) - price
	next_items[id] = int(items[id]) + 1
	return _replace_items_if_fit(next_items)

## Buying from a specialist at their price: goods, weapons/tools or armor upgrades.
func purchase(id: String, price: int) -> bool:
	if price <= 0 or int(items.get("shard", 0)) < price: return false
	var next_items: Dictionary = items.duplicate()
	var next_unlocked: Dictionary = unlocked.duplicate()
	var next_upgrades: Dictionary = upgrades.duplicate()
	next_items.shard = int(items.shard) - price
	if bool(Crafting.RECIPES.get(id, {}).get("upgrade", false)):
		if upgrades.get(id, false) == true: return false
		next_upgrades[id] = true
	elif Crafting.WEAPONS.has(id):
		if unlocked.get(id, false) == true: return false
		next_unlocked[id] = true
	else:
		if id not in INVENTORY_IDS or int(items.get(id, 0)) >= MAX_ITEMS: return false
		next_items[id] = int(items.get(id, 0)) + 1
	var layout: Array = Stacks.reconcile(_slots, _inventory_totals(next_items, next_unlocked, next_upgrades), false)
	if layout.is_empty(): return false
	items = next_items; unlocked = next_unlocked; upgrades = next_upgrades; _slots = layout
	refresh_stats()
	return true

func owns(id: String) -> bool:
	return upgrades.get(id, false) == true or unlocked.get(id, false) == true

func sell_item(id: String, price_override: int = -1) -> bool:
	if id not in INVENTORY_IDS or not Crafting.ITEMS.has(id):
		return false
	var price: int = int(Crafting.ITEMS[id].sell) if price_override < 0 else price_override
	if price <= 0 or int(items[id]) <= 0 or int(items.shard) + price > MAX_ITEMS:
		return false
	var next_items: Dictionary = items.duplicate()
	next_items[id] = int(items[id]) - 1
	next_items.shard = int(items.shard) + price
	return _replace_items_if_fit(next_items)

func _replace_items_if_fit(next_items: Dictionary) -> bool:
	_reconcile_slots()
	var layout: Array = Stacks.reconcile(_slots, _inventory_totals(next_items, unlocked, upgrades), false)
	if layout.is_empty():
		return false
	items = next_items
	_slots = layout
	return true

func equip_weapon(id: String) -> bool:
	if not Crafting.WEAPONS.has(id) or (id != "fists" and unlocked.get(id, false) != true):
		return false
	if id != "fists":
		_reconcile_slots()
		for index in range(_slots.size()):
			if _slots[index].get("item", "") == id:
				if index != selected_hotbar:
					var previous: Dictionary = _slots[selected_hotbar]
					_slots[selected_hotbar] = _slots[index]
					_slots[index] = previous
				break
	equipment = id
	return true

func _inventory_totals(counts: Dictionary, weapons: Dictionary, gear: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in INVENTORY_IDS:
		if id == "shard": continue
		result[id] = maxi(0, int(counts.get(id, 0)))
	for id in Crafting.WEAPONS:
		if id != "fists" and weapons.get(id, false) == true:
			result[id] = 1
	for id in Crafting.UPGRADES:
		if gear.get(id, false) == true:
			result[id] = 1
	return result

func _reconcile_slots() -> void:
	_slots = Stacks.reconcile(_slots, _inventory_totals(items, unlocked, upgrades))

func inventory_slots() -> Array:
	_reconcile_slots()
	return _slots.duplicate(true)

func selected_item() -> String:
	_reconcile_slots()
	return str(_slots[selected_hotbar].get("item", ""))

func ready_item(id: String) -> bool:
	_reconcile_slots()
	for index in range(_slots.size()):
		if _slots[index].get("item", "") != id:
			continue
		if index != selected_hotbar:
			var previous: Dictionary = _slots[selected_hotbar]
			_slots[selected_hotbar] = _slots[index]
			_slots[index] = previous
		_select_equipment()
		return true
	return false

func award_unique(id: String) -> bool:
	if id == "fists": return false
	if Crafting.WEAPONS.has(id):
		if unlocked.get(id, false) == true: return false
		unlocked[id] = true
	elif Crafting.UPGRADES.has(id):
		if upgrades.get(id, false) == true: return false
		upgrades[id] = true
	else:
		return false


	_reconcile_slots()
	refresh_stats()
	return true

func move_stack(from: int, to: int, split: bool = false) -> bool:
	_reconcile_slots()
	if not Stacks.move(_slots, from, to, split):
		return false
	_select_equipment()
	return true

func select_hotbar(index: int) -> bool:
	if index < 0 or index >= Stacks.HOTBAR_SLOTS:
		return false
	_reconcile_slots()
	selected_hotbar = index
	_select_equipment()
	return true

func _select_equipment() -> void:
	var id: String = str(_slots[selected_hotbar].get("item", ""))
	equipment = id if Crafting.WEAPONS.has(id) and unlocked.get(id, false) == true else "fists"

func register_defeat(point: Vector3) -> int:
	if not _valid_vector([point.x, point.y, point.z]):
		return 0
	var lost: int = 0
	death_echo_active = lost > 0
	death_echo_position = point
	death_echo_shards = lost
	_reconcile_slots()
	return lost

func recover_echo() -> bool:
	if not death_echo_active or death_echo_shards <= 0 or int(items.shard) + death_echo_shards > MAX_ITEMS:
		return false
	var next_items: Dictionary = items.duplicate()
	next_items.shard = int(items.shard) + death_echo_shards
	if not _replace_items_if_fit(next_items):
		return false
	death_echo_active = false
	death_echo_shards = 0
	return true

func save_game(path: String = "user://journey.json") -> bool:
	path = _profile_path(path)
	for id in Crafting.QuestItems.ITEMS:
		if int(items.get(id, 0)) < 0 or int(items.get(id, 0)) > 1: return false
	var magic := _validated_magic({"spellbook": spellbook, "spell_slots": spell_slots, "active_spell_slot": active_spell_slot, "mana": mana})
	if magic.is_empty() or not CampGround.valid(camp_clearings): return false
	if not preload("res://scripts/world_loot.gd").valid(world_loot, MAX_ITEMS) or loot_epoch < 0 or loot_epoch > 2147483647: return false
	_reconcile_slots()
	var data = {"version": 1, "seed": seed_value, "health": health, "max_health": max_health,
		"world_id": "mr-justice-world-01" if expanded_world else "legacy-valley",
		"terrain_revision": terrain_revision, "geography_revision": geography_revision if expanded_world else 0,
		"stamina": stamina, "max_stamina": max_stamina, "items": items, "taken": taken, "world_loot": world_loot, "loot_epoch": loot_epoch,
		"shrines": shrines, "settings": settings, "time": journey_time,
		"position": [player_position.x, player_position.y, player_position.z],
		"checkpoint": [checkpoint.x, checkpoint.y, checkpoint.z],
		"upgrades": upgrades, "unlocked": unlocked, "equipment": equipment,
		"camp_clearings": camp_clearings, "camp_placed": camp_placed, "camp_position": [camp_position.x, camp_position.y, camp_position.z],
		"slots": _slots, "selected_hotbar": selected_hotbar,
		"workbench_placed": workbench_placed, "workbench_position": [workbench_position.x, workbench_position.y, workbench_position.z],
		"death_echo_active": death_echo_active, "death_echo_position": [death_echo_position.x, death_echo_position.y, death_echo_position.z], "death_echo_shards": death_echo_shards}
	data.merge(magic, true)
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func save_title_settings() -> bool:


	var path = _profile_path("user://journey.json")
	if not FileAccess.file_exists(path) and expanded_world: path = "user://journey.json"
	var data: Variant = {}
	if FileAccess.file_exists(path): data = JSON.parse_string(FileAccess.get_file_as_string(path))
	else: path = "user://title-settings.json"
	if not data is Dictionary: return false
	if data.get("settings") == settings: return true
	data.settings = settings
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data)); file.flush(); file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func load_title_settings() -> bool:
	var path = "user://title-settings.json"
	if not FileAccess.file_exists(path): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("settings") is Dictionary: return false
	_apply_saved_settings(data.settings)
	return true

func _apply_saved_settings(saved: Dictionary) -> void:
	settings = {"volume": 0.75, "music": 0.5, "quality": 1, "sensitivity": 0.75, "low_flash": false, "camera_shake": true, "ui_motion": true, "contextual_hud": true}
	for key in ["volume", "music", "sensitivity", "quality"]:
		var value = saved.get(key, settings[key])
		if _number(value):
			settings[key] = clampf(float(value), 0.2 if key == "sensitivity" else 0.0, 2.0 if key == "quality" else 1.0)
	for key in ["low_flash", "camera_shake", "ui_motion", "contextual_hud", "dev_infinite_mana"]:
		if saved.get(key) is bool: settings[key] = saved[key]

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 256

static func _valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not _number(component) or absf(float(component)) > 100000.0:
			return false
	return true

static func _flags(value: Variant, allowed: Array = []) -> bool:
	if not value is Dictionary or value.size() > 100000:
		return false
	for id in value:
		if not _valid_id(id) or not value[id] is bool or (not allowed.is_empty() and id not in allowed):
			return false
	return true

## 3: the 0.43 spell overhaul. Older saves drop the retired example spells (custom spells
## the player made are kept) and get the new starter spells in their quick slots.
const MAGIC_CATALOG := 3
const RETIRED_SPELLS := ["embercourt_spiral", "rimeglass_fan", "violet_constellation", "tempest_lance", "dawnward", "bloom_mend", "flash_step", "starfall_edict", "gentle_hand", "gravity_garden", "kindly_shove",
	"lanternwake", "gravity_requiem", "rimeglass_crown", "tempest_serpent", "sunforged_sentence", "verdant_familiar", "unfinished_second", "undertow_choir", "ink_between_stars", "iron_orchard", "stonewake", "kindly_catastrophe"]

static func _validated_magic(data: Dictionary) -> Dictionary:
	var recipes: Variant = data.get("spellbook", Spellbook.starters())
	var migrate := int(data.get("magic_catalog", 0)) < MAGIC_CATALOG if _number(data.get("magic_catalog", 0)) else true
	if migrate and recipes is Array:
		recipes = recipes.filter(func (raw): return not (raw is Dictionary and str(raw.get("id", "")) in RETIRED_SPELLS))
		if recipes.is_empty(): recipes = Spellbook.starters()
	if not recipes is Array or recipes.is_empty() or recipes.size() > Spellbook.MAX_SPELLS: return {}
	var clean: Array = []
	var ids: Dictionary = {}
	for raw in recipes:
		var spell := Spellbook.sanitize(raw)
		if spell.is_empty() or ids.has(spell.id): return {}
		ids[spell.id] = true
		clean.append(spell)



	var remapped: Dictionary = {}
	for spell in clean:
		var old_id := str(spell.id)
		if not SpellCollection.is_curated(old_id): continue
		var base := ("legacy_" + old_id).left(48)
		var candidate := base
		var suffix := 2
		while ids.has(candidate) or SpellCollection.is_curated(candidate):
			var ending := "_%d" % suffix
			candidate = base.left(48 - ending.length()) + ending
			suffix += 1
		spell.id = candidate
		ids[candidate] = true
		remapped[old_id] = candidate
	var slots: Variant = data.get("spell_slots", SpellCollection.starting_slots() if not data.has("spellbook") else [clean[0].id, clean[0].id, clean[0].id, clean[0].id])
	if migrate: slots = SpellCollection.starting_slots()
	if not slots is Array or slots.size() != Spellbook.SLOT_COUNT: return {}
	var clean_slots: Array = []
	var fallback: Array = SpellCollection.starting_slots()
	for index in range(slots.size()):
		var id: Variant = slots[index]
		# A slot pointing at a spell that no longer exists falls back to that slot's starter.
		if not id is String or (not ids.has(id) and not SpellCollection.is_curated(id) and not remapped.has(id)): id = fallback[index]
		clean_slots.append(remapped.get(id, id))
	var active: Variant = data.get("active_spell_slot", 0)
	if not _number(active) or float(active) != floorf(float(active)) or float(active) < 0 or float(active) >= Spellbook.SLOT_COUNT: return {}
	var saved_mana: Variant = data.get("mana", Spellbook.MAX_MANA)
	if not _number(saved_mana) or float(saved_mana) < 0 or float(saved_mana) > Spellbook.MAX_MANA: return {}
	return {"spellbook": clean, "spell_slots": clean_slots, "active_spell_slot": int(active), "mana": float(saved_mana), "magic_catalog": MAGIC_CATALOG}

func _profile_path(path: String) -> String:
	return "user://world-expedition.json" if expanded_world and path == "user://journey.json" else path

func load_game(path: String = "user://journey.json") -> bool:
	path = _profile_path(path)
	if not FileAccess.file_exists(path):
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return false
	var data: Dictionary = parser.data
	for key in ["version", "seed", "position", "checkpoint", "items", "taken", "shrines", "settings"]:
		if not data.has(key):
			return false
	for key in ["position", "checkpoint"]:
		if not _valid_vector(data[key]):
			return false
	for key in ["version", "seed", "health", "stamina", "max_stamina", "time"]:
		if not _number(data.get(key, 0.0)):
			return false
	if float(data.version) != 1.0 or absf(float(data.seed)) > 2147483647 or float(data.seed) != floorf(float(data.seed)):
		return false
	var geography = data.get("geography_revision", 0)
	if not _number(geography) or float(geography) < 0 or float(geography) > 1 or float(geography) != floorf(float(geography)): return false
	var revision = data.get("terrain_revision", 31)
	if not _number(revision) or float(revision) < 1 or float(revision) > 10000 or float(revision) != floorf(float(revision)): return false
	if not data.items is Dictionary or not data.settings is Dictionary:
		return false
	for id in data.items:
		var value = data.items[id]
		if id not in INVENTORY_IDS or not _number(value) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > (1 if Crafting.QuestItems.is_quest(id) else MAX_ITEMS):
			return false
	if not _flags(data.taken) or not _flags(data.shrines, ["beam", "hook", "heart"]):
		return false
	var saved_loot = data.get("world_loot", [])
	if not preload("res://scripts/world_loot.gd").valid(saved_loot, MAX_ITEMS): return false
	var saved_epoch = data.get("loot_epoch", 0)
	if not _number(saved_epoch) or float(saved_epoch) < 0 or float(saved_epoch) > 2147483647 or float(saved_epoch) != floorf(float(saved_epoch)): return false
	for row in saved_loot:
		if data.taken.has(row.id): return false


	if not _flags(data.get("upgrades", {}), Crafting.UPGRADES.keys()) or not _flags(data.get("unlocked", {}), Crafting.WEAPONS.keys().filter(func (id): return id != "fists") + ["stone_hammer"]):
		return false
	var gear = data.get("equipment", "fists")
	if not gear is String or (not Crafting.WEAPONS.has(gear) and gear != "stone_hammer") or (gear != "fists" and data.get("unlocked", {}).get(gear, false) != true):
		return false
	if not data.get("camp_placed", false) is bool or not _valid_vector(data.get("camp_position", [0, 4, 0])):
		return false
	if data.get("camp_placed", false) and not data.has("camp_position"):
		return false
	if data.has("slots") and not Stacks.valid_slots(data.slots, {"stone_hammer": 1}):
		return false
	var selected = data.get("selected_hotbar", 0)
	if not _number(selected) or float(selected) != floorf(float(selected)) or int(selected) < 0 or int(selected) >= Stacks.HOTBAR_SLOTS:
		return false
	if not data.get("workbench_placed", false) is bool or not _valid_vector(data.get("workbench_position", [0, 4, 0])):
		return false
	if data.get("workbench_placed", false) and not data.has("workbench_position"):
		return false
	if not data.get("death_echo_active", false) is bool or not _valid_vector(data.get("death_echo_position", [0, 4, 0])):
		return false
	var echo_amount = data.get("death_echo_shards", 0)
	if not _number(echo_amount) or float(echo_amount) != floorf(float(echo_amount)) or int(echo_amount) < 0 or int(echo_amount) > MAX_ITEMS:
		return false
	if data.get("death_echo_active", false) and (not data.has("death_echo_position") or int(echo_amount) <= 0):
		return false
	if not data.get("death_echo_active", false) and int(echo_amount) != 0:
		return false
	var magic := _validated_magic(data)
	if magic.is_empty(): return false
	if not CampGround.valid(data.get("camp_clearings", [])): return false

	seed_value = int(data.seed)
	world_id = str(data.get("world_id", ""))
	terrain_revision = int(revision)
	geography_revision = int(geography)
	player_position = Vector3(float(data.position[0]), float(data.position[1]), float(data.position[2]))
	checkpoint = Vector3(float(data.checkpoint[0]), float(data.checkpoint[1]), float(data.checkpoint[2]))
	taken = data.taken.duplicate(true)
	world_loot = saved_loot.duplicate(true)
	loot_epoch = int(saved_epoch)
	shrines = _true_flags(data.shrines)
	upgrades = _true_flags(data.get("upgrades", {}))
	unlocked = _true_flags(data.get("unlocked", {}))
	var retire_hammer: bool = unlocked.get("stone_hammer", false) == true
	unlocked.erase("stone_hammer")


	unlocked["grimoire"] = true
	equipment = "fists" if gear == "stone_hammer" else gear
	camp_clearings = data.get("camp_clearings", []).duplicate(true)
	camp_placed = data.get("camp_placed", false)
	var camp: Array = data.get("camp_position", [0, 4, 0])
	camp_position = Vector3(float(camp[0]), float(camp[1]), float(camp[2]))
	selected_hotbar = int(selected)
	workbench_placed = data.get("workbench_placed", false)
	var bench: Array = data.get("workbench_position", [0, 4, 0])
	workbench_position = Vector3(float(bench[0]), float(bench[1]), float(bench[2]))
	death_echo_active = data.get("death_echo_active", false)
	death_echo_shards = int(echo_amount)
	if death_echo_shards > 0:
		items.shard = mini(MAX_ITEMS, int(items.shard) + death_echo_shards)
		death_echo_shards = 0
		death_echo_active = false
	var echo: Array = data.get("death_echo_position", [0, 4, 0])
	death_echo_position = Vector3(float(echo[0]), float(echo[1]), float(echo[2]))
	spellbook = magic.spellbook
	spell_slots = magic.spell_slots
	active_spell_slot = magic.active_spell_slot
	mana = magic.mana
	refresh_stats()
	stamina = clampf(float(data.get("stamina", max_stamina)), 0.0, max_stamina)
	health = clampi(int(data.get("health", 5)), 1, max_health)
	items = _new_inventory()
	for id in data.items:
		items[id] = int(data.items[id])
	if retire_hammer:


		for id in RETIRED_HAMMER_REFUND:
			items[id] = mini(MAX_ITEMS, int(items[id]) + RETIRED_HAMMER_REFUND[id])
	_slots = data.get("slots", []).duplicate(true)
	_reconcile_slots()
	if equipment != "fists":
		equip_weapon(equipment)
	_apply_saved_settings(data.settings)
	journey_time = clampf(float(data.get("time", 0)), 0.0, 1000000000.0)
	return true

static func _true_flags(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in value:
		if value[id] == true:
			result[id] = true
	return result
