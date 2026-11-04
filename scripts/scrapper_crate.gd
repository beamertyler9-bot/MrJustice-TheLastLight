extends "res://scripts/breakable_barrel.gd"

const O = preload("res://scripts/world_overhaul.gd")
static func live_sources(owner_world, id: String) -> Array:
	if not is_instance_valid(owner_world) or not owner_world.is_inside_tree(): return []
	return owner_world.get_tree().get_nodes_in_group("breakable_crate").filter(func (box): return box.world == owner_world and str(box.get_meta("id", "")) == id and box.is_inside_tree() and not box.is_queued_for_deletion())
static func retire_source(owner_world, id: String) -> void:
	for box in live_sources(owner_world, id): box._retire()
func _retire() -> void:
	health = 0; set_meta("health", 0); broken = true
	for group in ["damageable", "carryable", "interactable", "breakable_crate", "breakable_barrel"]: remove_from_group(group)
	set_deferred("collision_layer", 0); visible = false; queue_free()
func _ready() -> void:
	freeze = true; mass = 3.5; collision_layer = 8; collision_mask = 1 | 4 | 8
	if not has_meta("crate_art_ready"):
		O.fit(self, "qprop_crate_wooden", Vector3(0, -0.48, 0), Vector3(1.12, 0.96, 1.02))
		var collision = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size = Vector3(1.12, 0.96, 1.02); collision.shape = shape; add_child(collision)
		set_meta("crate_art_ready", true)
	if source_id.is_empty(): source_id = str(get_meta("id", ""))
	if source_id.is_empty(): source_id = "scrapper_crate_%d_%d_%d" % [roundi(global_position.x * 32), roundi(global_position.y * 32), roundi(global_position.z * 32)]
	set_meta("breakable_crate", true); set_meta("kind", "carry"); set_meta("material", "wood"); set_meta("amount", 1); set_meta("label", "Supply crate · Tap B to break · Hold B to lift")
	super._ready()
	if is_queued_for_deletion() or not live_sources(world, source_id).is_empty():
		_retire(); return
	add_to_group("breakable_crate")
func take_damage(amount: int) -> void:
	if broken or health <= 0 or amount <= 0: return
	if amount < health:
		health -= amount; set_meta("health", health); return
	var game = _reward_owner()
	if game == null or not game.has_method("break_crate"): return
	if game.has_method("can_break_crate") and not game.can_break_crate(self): return
	if not game.break_crate(self): return
	retire_source(world, source_id)
func _reward_owner():
	if not is_instance_valid(world): return null
	var game = world.get_parent()
	while game != null and not game.has_method("break_crate"): game = game.get_parent()
	return game
