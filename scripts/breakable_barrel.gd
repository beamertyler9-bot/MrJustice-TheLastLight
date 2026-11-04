extends RigidBody3D

var world
var health = 2
var broken = false
var source_id = ""
var incoming_speed = 0.0
func configure(owner_world, id: String = "") -> void:
	world = owner_world; source_id = id
	if not id.is_empty(): set_meta("id", id)
func _ready() -> void:
	if not is_instance_valid(world):
		var parent = get_parent()
		while parent != null:
			if parent.get("state") != null and parent.has_method("surface_height_at"): world = parent; break
			parent = parent.get_parent()
	if source_id.is_empty(): source_id = str(get_meta("id", ""))
	if source_id.is_empty(): source_id = "barrel_decor_%d_%d_%d" % [roundi(global_position.x * 32), roundi(global_position.y * 32), roundi(global_position.z * 32)]
	set_meta("id", source_id); set_meta("health", health); set_meta("damage_height", 0.0); set_meta("breakable_barrel", true)
	if not has_meta("kind"): set_meta("kind", "carry"); set_meta("material", "wood"); set_meta("amount", 1); set_meta("label", "Tap B to break · Hold B to lift")
	add_to_group("interactable"); add_to_group("carryable")
	add_to_group("damageable"); add_to_group("breakable_barrel")
	contact_monitor = true; max_contacts_reported = 4
	body_entered.connect(_impact)
	if is_instance_valid(world) and world.get("state") != null and world.state.taken.has("broken_" + source_id): queue_free()
func _impact(_other: Node) -> void:
	if not freeze and maxf(incoming_speed, linear_velocity.length()) > 4.2: take_damage(health)
func _integrate_forces(physics: PhysicsDirectBodyState3D) -> void:
	var speed = physics.linear_velocity.length()
	if physics.get_contact_count() > 0 and maxf(speed, incoming_speed) > 4.2: take_damage.call_deferred(health)
	incoming_speed = speed
func take_damage(amount: int) -> void:
	if broken or health <= 0 or amount <= 0: return
	var game = _reward_owner()
	if amount >= health and game != null and game.has_method("can_break_barrel") and not game.can_break_barrel(self): return
	health = maxi(0, health - amount); set_meta("health", health)
	if health > 0: return
	broken = true; remove_from_group("damageable"); set_deferred("collision_layer", 0)
	if is_instance_valid(world) and world.get("state") != null:
		world.state.taken[source_id] = true; world.state.taken["broken_" + source_id] = true
		if game != null: game.break_barrel(self)
	visible = false; queue_free()
func _reward_owner():
	if not is_instance_valid(world): return null
	var game = world.get_parent()
	while game != null and not game.has_method("break_barrel"): game = game.get_parent()
	return game
func receive_impulse(impulse: Vector3) -> void:
	if not impulse.is_finite() or broken: return
	var renderer = get_meta("chunk_renderer") if has_meta("chunk_renderer") else null
	if renderer is WeakRef and is_instance_valid(renderer.get_ref()): renderer.get_ref().release(self)
	freeze = false; apply_central_impulse(impulse.limit_length(18))
