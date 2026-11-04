extends CharacterBody3D


const HURT_DURATION = 0.48
var health = 2
var hurt_timer = 0.0
var flee_timer = 0.0
var recoil = Vector3.ZERO
var defeated = false
var defeat_time = 0.0
var flinch_side = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 0
	collision_mask = 0
	add_to_group("wildlife_actor")
	add_to_group("damageable")

func prepare(family: String, body: Node3D) -> void:
	health = 4 if family in ["tortoise", "boar", "camel"] else 3 if family in ["deer", "antelope", "goat", "sheep"] else 2
	set_meta("health", health)


	var bounds = AABB(); var first = true
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		bounds = box if first else bounds.merge(box); first = false
	var shape = BoxShape3D.new()
	shape.size = Vector3(clampf(bounds.size.x, 0.22, 1.2), clampf(bounds.size.y, 0.22, 1.8), clampf(bounds.size.z, 0.25, 2.1))
	set_meta("damage_height", bounds.get_center().y)
	var hitbox = CollisionShape3D.new(); hitbox.name = "WildlifeHitbox"; hitbox.shape = shape; hitbox.position = bounds.get_center(); add_child(hitbox)

func set_active(active: bool) -> void:
	visible = active and not defeated
	collision_layer = 4 if visible else 0

func take_damage(amount: int) -> void:
	if amount <= 0 or defeated or not visible: return
	health = maxi(0, health - amount); set_meta("health", health)
	hurt_timer = HURT_DURATION; flee_timer = 4.2; flinch_side = -flinch_side
	if health == 0:
		defeated = true; flee_timer = 0.0; collision_layer = 0
		remove_from_group("damageable")

func receive_impulse(impulse: Vector3) -> void:
	if defeated or not visible or not impulse.is_finite(): return
	recoil += Vector3(impulse.x, 0, impulse.z).limit_length(8.0)
	recoil = recoil.limit_length(8.0); flee_timer = maxf(flee_timer, 2.4)

func advance_reaction(dt: float) -> void:
	hurt_timer = maxf(0.0, hurt_timer - dt)
	flee_timer = maxf(0.0, flee_timer - dt)
	recoil = recoil.move_toward(Vector3.ZERO, dt * 8.0)
	if defeated:
		defeat_time += dt
		if defeat_time >= 0.7: visible = false
