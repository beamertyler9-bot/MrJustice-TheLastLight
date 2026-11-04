extends CharacterBody3D

var health := 8
func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4 | 8 | 16
	add_to_group("magic_guardian")
	set_meta("temporary_magic", true)
	set_physics_process(false)
func take_damage(amount: int) -> void:
	health = maxi(0, health - maxi(0, amount))
	if health <= 0: queue_free()
