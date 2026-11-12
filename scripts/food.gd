extends RefCounted
## Camp food you can eat, and the little boosts it gives.
##
## Raw treats heal a heart and give one boost each; a roasted marshmallow warms you; a
## s'more (marshmallow + chocolate + graham cracker, toasted at a lit campfire) heals the
## most and gives all three boosts at once. Treats with a boost can be eaten at full health.
## Eating: the treat lifts to the lantern and is swallowed by the flame, which flares; a
## card under the compass lists active boosts with their time left.

const ItemModels = preload("res://scripts/item_models.gd")

const BOOSTS := {
	"cocoa": {"name": "Cocoa Rush", "text": "+15% run speed", "color": Color("#c98a54")},
	"warmth": {"name": "Campfire Warmth", "text": "a heart back every 8 s", "color": Color("#ffb45e")},
	"grit": {"name": "Graham Grit", "text": "the next hit does 1 less damage", "color": Color("#e2c27a")},
}
const FOODS := {
	"marshmallow": {"heal": 1, "boosts": {"warmth": 12.0}},
	"chocolate_bar": {"heal": 1, "boosts": {"cocoa": 45.0}},
	"graham_cracker": {"heal": 1, "boosts": {"grit": 90.0}},
	"roasted_marshmallow": {"heal": 2, "boosts": {"warmth": 24.0}},
	"smore": {"heal": 3, "boosts": {"warmth": 40.0, "cocoa": 60.0, "grit": 120.0}},
	"hot_cocoa": {"heal": 1, "boosts": {"cocoa": 90.0}},
	"fish_stew": {"heal": 4, "boosts": {"warmth": 30.0}},
	"cactus_water": {"heal": 2, "boosts": {"grit": 90.0}},
	"sugar_drop": {"heal": 1, "boosts": {"cocoa": 30.0}},
	"mossbloom_tonic": {"heal": 4, "boosts": {"warmth": 20.0}},
}
const WARMTH_TICK := 8.0
const COCOA_SPEED := 1.15

var game
var active: Dictionary = {}   # boost id -> seconds left
var _warm_clock := 0.0


func setup(owner_game) -> void:
	game = owner_game


static func is_food(id: String) -> bool: return FOODS.has(id)


## What a food does, in words (for descriptions and toasts).
static func effect_text(id: String) -> String:
	if not FOODS.has(id): return ""
	var food: Dictionary = FOODS[id]
	var parts: Array = ["+%d heart%s" % [food.heal, "" if int(food.heal) == 1 else "s"]]
	for boost in food.boosts: parts.append("%s (%s, %ds)" % [BOOSTS[boost].name, BOOSTS[boost].text, int(food.boosts[boost])])
	return ", ".join(parts)


## Called once the treat has been eaten (state already healed and took the item).
func eaten(id: String, healed: int) -> void:
	if not FOODS.has(id): return
	var names: Array = []
	for boost in FOODS[id].boosts:
		active[boost] = maxf(float(active.get(boost, 0.0)), float(FOODS[id].boosts[boost]))
		names.append(BOOSTS[boost].name)
	_play(id)
	var line := preload("res://scripts/crafting.gd").item_name(id)
	if healed > 0: line += " · +%d heart%s" % [healed, "" if healed == 1 else "s"]
	if not names.is_empty(): line += " · " + ", ".join(names)
	game.toast(line, 4)


func speed_multiplier() -> float:
	return COCOA_SPEED if float(active.get("cocoa", 0.0)) > 0.0 else 1.0


## Graham Grit softens the next blow.
func soften(amount: int) -> int:
	if amount <= 0 or float(active.get("grit", 0.0)) <= 0.0: return amount
	active.erase("grit")
	if game.has_method("toast"): game.toast("Graham Grit softened the blow", 2)
	return maxi(0, amount - 1)


func tick(dt: float) -> void:
	if active.is_empty(): return
	for boost in active.keys():
		active[boost] = float(active[boost]) - dt
		if float(active[boost]) <= 0.0: active.erase(boost)
	if active.has("warmth"):
		_warm_clock += dt
		if _warm_clock >= WARMTH_TICK:
			_warm_clock = 0.0
			if game.state.health > 0 and game.state.health < game.state.max_health:
				game.state.health += 1
				if game.player != null: game.burst(game.player.global_position + Vector3.UP * 1.2, Color("#ffb45e"), 6)
	else: _warm_clock = 0.0


## The treat rises to the lantern and the flame swallows it with a flare.
func _play(id: String) -> void:
	var player = game.player
	if player == null or player.visual == null: return
	var lantern: Node3D = player.visual.lantern
	if lantern == null: return
	var holder := Node3D.new(); holder.top_level = true
	game.add_child(holder)
	var start: Vector3 = player.global_position + player.visual.global_basis.z * -0.35 + Vector3.UP * 0.7
	holder.global_position = start
	if ItemModels.supports(id): ItemModels.build(holder, id)
	holder.scale = Vector3.ONE * 1.4
	var tween := holder.create_tween()
	tween.tween_property(holder, "global_position", lantern.global_position + Vector3.UP * 0.05, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(holder, "rotation:y", TAU, 0.35)
	tween.tween_property(holder, "scale", Vector3.ONE * 0.05, 0.12)
	tween.tween_callback(func ():
		if is_instance_valid(holder): holder.queue_free()
		if is_instance_valid(lantern):
			game.burst(lantern.global_position, Color("#ffd27a"), 12)
			var flare := lantern.create_tween()
			var base: float = player.visual.lantern_gain
			flare.tween_property(player.visual, "lantern_gain", base + 0.8, 0.08)
			flare.tween_property(player.visual, "lantern_gain", base, 0.5))
	if game.audio != null: game.audio.cue("collect", 0.9)


## Active boosts for the HUD: [{name, seconds, color}].
func hud_list() -> Array:
	var result: Array = []
	for boost in active:
		result.append({"name": BOOSTS[boost].name, "seconds": int(ceil(float(active[boost]))), "color": BOOSTS[boost].color})
	return result
