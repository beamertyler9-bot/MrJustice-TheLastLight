extends Node3D
const Crafting = preload("res://scripts/crafting.gd")

var world
var felled: bool = false
var fall_time: float = 0.0
var fall_direction: float = 0.0
var collider: StaticBody3D

func hit(amount: int) -> bool:
	if felled or amount <= 0 or world == null:
		return false
	if Crafting.weapon_metadata(world.state.equipment).get("tool", "") != "axe":
		return false

	if not world.state.harvest(str(get_meta("id")), "wood", amount):
		return false
	var renderer = get_meta("chunk_renderer") if has_meta("chunk_renderer") else null
	if renderer is WeakRef and is_instance_valid(renderer.get_ref()): renderer.get_ref().release(self)
	felled = true
	remove_from_group("interactable")
	remove_from_group("harvestable")
	if collider != null:
		collider.collision_layer = 0
	set_process(true)
	return true

func _process(dt: float) -> void:
	if not felled:
		return
	fall_time += dt
	var progress = clampf(fall_time / 0.85, 0.0, 1.0)
	rotation = Vector3(cos(fall_direction), 0, sin(fall_direction)) * progress * progress * 1.48
	if fall_time > 1.5:
		scale = Vector3.ONE * maxf(0.001, 1.0 - (fall_time - 1.5) / 0.4)
	if fall_time >= 1.9:
		queue_free()
