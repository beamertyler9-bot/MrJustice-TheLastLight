extends Node3D
const Crafting = preload("res://scripts/crafting.gd")
var world
var collider: StaticBody3D
var mined := false
var hits_left := 3

func _ready() -> void:
	add_to_group("mineable")
	add_to_group("interactable")
	add_to_group("batch_dynamic")
	set_meta("kind", "rock")
	set_meta("label", "Mine " + Crafting.item_name(str(get_meta("item", "stone"))))

func hit(strength: int = 1) -> bool:
	if get_meta("kind", "") != "rock" or mined or strength <= 0 or world == null or Crafting.weapon_metadata(world.state.equipment).get("tool", "") != "pickaxe":
		return false
	var next := maxi(0, hits_left - strength)
	if next == 0:
		if not world.state.harvest(str(get_meta("id", "")), str(get_meta("item", "stone")), int(get_meta("amount", 4))):
			return false
		mined = true
		hits_left = 0
		remove_from_group("mineable")
		remove_from_group("interactable")
		if is_instance_valid(collider): collider.collision_layer = 0
		var guide = get_meta("ground_stone_art", false)
		if guide is WeakRef:
			var art = guide.get_ref()
			if is_instance_valid(art): art._hide(int(get_meta("ground_stone_index")))
		queue_free()
	else:
		hits_left = next
	return true
