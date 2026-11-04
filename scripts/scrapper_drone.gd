extends "res://scripts/enemy.gd"


const Art = preload("res://scripts/scrapper_drone_art.gd")
const DRONE_PROFILES = {
	"scout": {"name": "Dissonant scout drone", "model": "DissonantScout", "hp": 9, "speed": 2.75, "reach": 12.0, "windup": 0.82, "recovery": 0.55, "cooldown": 2.45, "damage": 1, "radius": 0.43, "height": 1.4, "attack": "ranged"},
	"blast": {"name": "Dissonant sound-blast drone", "model": "DissonantBlast", "hp": 18, "speed": 1.7, "reach": 12.0, "windup": 1.15, "recovery": 0.85, "cooldown": 3.15, "damage": 2, "radius": 0.57, "height": 1.55, "attack": "ranged"},
	"echo": {"name": "Dissonant echo drone", "model": "DissonantEcho", "hp": 12, "speed": 2.1, "reach": 10.5, "windup": 1.25, "recovery": 0.72, "cooldown": 2.85, "damage": 1, "radius": 0.55, "height": 1.45, "attack": "ranged"}
}
var drone_variant := "scout"
var walking := false
var camp_id := ""

func configure_drone(variant: String, walks: bool) -> void:
	if is_node_ready(): return
	drone_variant = variant if DRONE_PROFILES.has(variant) else "scout"
	walking = walks and drone_variant != "echo"
	species_id = "dissonant_" + drone_variant + ("_walker" if walking else "_hover")
	profile = DRONE_PROFILES[drone_variant].duplicate()
	if walking: profile.height = 1.65 if drone_variant == "blast" else 1.5
	display_name = str(profile.name) + (" walker" if walking else "")
	health = int(profile.hp)

func _ready() -> void:
	if not species_id.begins_with("dissonant_"): configure_drone(drone_variant, walking)
	super._ready()
	set_meta("id", id); set_meta("scrapper", true); set_meta("camp_id", camp_id); set_meta("drone", true)
	telegraph.material_override = B.mat("#ac8bd0", 0, 0.5)
	if game != null and not walking and not bool(get_meta("magic_held", false)) and not bool(get_meta("magic_stasis", false)):
		global_position.y = _surface_y() + 0.8
	_place_telegraph()

func _build_visual() -> void: Art.bind(self)
func _animate(dt: float, speed: float) -> void: Art.pose(self, dt, speed)
func _animate_creature(dt: float, speed: float) -> void: Art.pose(self, dt, speed)
func _contact_pose() -> void: Art.pose(self, 0.0, 0.0, true)

func _surface_y() -> float:
	if game == null: return global_position.y - (0.8 if not walking else 0.0)
	var world = game.world
	if world.has_method("surface_height_at"): return world.surface_height_at(global_position.x, global_position.z)
	return world.height_at(global_position.x, global_position.z)

func _place_telegraph() -> void:
	if telegraph != null and game != null: telegraph.global_position = Vector3(global_position.x, _surface_y() + 0.045, global_position.z)

func _physics_process(dt: float) -> void:
	var normal_tick: bool = game != null and game.mode == "play" and health > 0 and is_inside_tree() and not is_queued_for_deletion() and not bool(get_meta("magic_held", false)) and not bool(get_meta("magic_stasis", false))
	if not walking and normal_tick:


		global_position.y = _surface_y() + 0.8


		velocity.y = 19 * dt * float(get_meta("magic_gravity_scale", 1.0))
	super._physics_process(dt)
	if not is_inside_tree() or is_queued_for_deletion(): return
	if normal_tick and visible:
		if not walking:
			global_position.y = _surface_y() + 0.8
			velocity.y = 0
		_place_telegraph()

func _strike_clear(player: Node3D, reach: float) -> bool:
	var start: Vector3 = core.global_position
	var end: Vector3 = player.global_position + Vector3.UP * 0.95
	var flat := Vector3(end.x - start.x, 0, end.z - start.z)
	if flat.length() >= reach or start.distance_to(end) > reach + 1.0: return false
	var facing: Vector3 = -model.global_basis.z; facing.y = 0
	if flat.length() > 0.15 and facing.normalized().dot(flat.normalized()) < 0.35: return false
	var query = PhysicsRayQueryParameters3D.create(start, end, 1 | 8)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _launch_projectile() -> void:
	if projectiles.size() >= 3 or game == null: return
	var source: Vector3 = core.global_position
	var direction: Vector3 = (game.player.global_position + Vector3.UP * 0.95 - source).normalized()
	if direction.length_squared() < 0.5: direction = -model.global_basis.z
	if drone_variant == "echo":

		if not projectiles.is_empty():
			return
		for angle in [-0.2, 0.0, 0.2]:
			_spawn_sound_pulse(source, direction.rotated(Vector3.UP, angle))
	else:
		_spawn_sound_pulse(source, direction)

func _spawn_sound_pulse(source: Vector3, direction: Vector3) -> void:
	var sound = Node3D.new(); sound.name = "SoundPulse"; add_child(sound); sound.top_level = true; sound.global_position = source

	for i in range(3):
		var ring = B.ring(sound, Vector3(0, 0, float(i) * 0.085), 0.2 - float(i) * 0.035, 0.018, B.mat("#a27ac9" if i != 1 else "#aeb3bf", 0, 0.45))
		ring.rotation.x = PI * 0.5
	sound.look_at(source + direction, Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	projectiles.append({"node": sound, "direction": direction, "life": 2.4})

func take_damage(amount: int) -> void:
	var previous := health
	super.take_damage(amount)
	if previous > 0 and health <= 0 and game.get("scrappers") != null:
		game.scrappers.enemy_defeated(id, global_position, species_id)
