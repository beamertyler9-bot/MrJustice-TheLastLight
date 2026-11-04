extends "res://scripts/enemy.gd"


const Art = preload("res://scripts/scrapper_bandit_art.gd")
const SCRAPPER_PROFILES = {
	"scout": {"name": "Scrapper scout", "model": "ScrapperScout", "hp": 10, "speed": 3.35, "reach": 1.8, "windup": 0.6, "recovery": 0.48, "cooldown": 1.6, "damage": 2, "radius": 0.3, "height": 1.65},
	"bruiser": {"name": "Scrapper bruiser", "model": "ScrapperBruiser", "hp": 20, "speed": 1.85, "reach": 2.2, "windup": 1.05, "recovery": 0.85, "cooldown": 2.65, "damage": 3, "radius": 0.48, "height": 1.8},
	"slinger": {"name": "Scrapper slinger", "model": "ScrapperSlinger", "hp": 12, "speed": 2.5, "reach": 12.0, "windup": 0.95, "recovery": 0.65, "cooldown": 2.25, "damage": 2, "radius": 0.3, "height": 2.0, "attack": "ranged"}
}
var scrapper_kind := "scout"
var camp_id := ""
var patrol_route: Array = []
var patrol_index := 0

func configure_scrapper(kind: String) -> void:
	if is_node_ready(): return
	scrapper_kind = kind if SCRAPPER_PROFILES.has(kind) else "scout"
	species_id = "scrapper_" + scrapper_kind
	profile = SCRAPPER_PROFILES[scrapper_kind].duplicate()
	display_name = str(profile.name)
	health = int(profile.hp)

func _ready() -> void:

	if not species_id.begins_with("scrapper_"): configure_scrapper(scrapper_kind)
	super._ready()
	set_meta("id", id)
	set_meta("scrapper", true)
	set_meta("camp_id", camp_id)

func _build_visual() -> void: Art.bind(self, scrapper_kind)
func _animate(dt: float, speed: float) -> void: Art.pose(self, dt, speed)
func _animate_creature(dt: float, speed: float) -> void: Art.pose(self, dt, speed)
func _contact_pose() -> void: Art.pose(self, 0.0, 0.0, true)

func _physics_process(dt: float) -> void:
	if _can_patrol():
		_patrol(dt)
		return
	super._physics_process(dt)

func _can_patrol() -> bool:
	if patrol_route.is_empty() or game == null or not is_inside_tree() or is_queued_for_deletion() or health <= 0 or game.mode != "play": return false
	if windup > 0 or recovery > 0 or hurt_stagger_time > 0 or not projectiles.is_empty(): return false
	if bool(get_meta("magic_held", false)) or bool(get_meta("magic_stasis", false)): return false
	var player: Node3D = game.player
	if player.global_position.distance_to(home) > 80 or not _same_region(player): return false
	if Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < 14: return false
	var world = game.world
	return world.chunks.has(Vector2i(floori(home.x / world.CHUNK), floori(home.z / world.CHUNK))) and world.chunks.has(Vector2i(floori(global_position.x / world.CHUNK), floori(global_position.z / world.CHUNK)))

func _patrol(dt: float) -> void:
	visible = true
	var real_dt := dt
	var magic_scale := clampf(float(get_meta("magic_time_scale", 1.0)), 0.1, 1.0)
	dt *= magic_scale
	clock += dt; cooldown = maxf(0, cooldown - dt); _tick_hurt_reaction(dt); recoil *= exp(-dt * 9)
	patrol_index = posmod(patrol_index, patrol_route.size())
	var target: Vector3 = patrol_route[patrol_index]
	var from_home := target - home; from_home.y = 0
	if from_home.length() > 24: target = home + from_home.normalized() * 24
	var direction := target - global_position; direction.y = 0
	if direction.length() < 0.65:
		patrol_index = (patrol_index + 1) % patrol_route.size()
		direction = Vector3.ZERO
	var speed := minf(float(profile.speed) * 0.52, 1.55) if direction.length() > 0.1 else 0.0
	if speed > 0: model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), 1 - exp(-dt * 3.5))
	direction = direction.normalized()
	velocity.x = direction.x * speed * magic_scale + recoil.x; velocity.z = direction.z * speed * magic_scale + recoil.z
	velocity.y -= 19 * real_dt * float(get_meta("magic_gravity_scale", 1.0))
	move_and_slide()
	telegraph.visible = false
	core.material_override = hurt_glow if hurt_timer > 0 else normal_glow
	_animate(dt, speed)

func _launch_projectile() -> void:
	if projectiles.size() >= 3: return
	var junk = Node3D.new(); junk.name = "ScrapShot"; add_child(junk); junk.top_level = true
	var source: Vector3 = visual_rig.pouch.global_position if visual_rig.has("pouch") else global_position + Vector3.UP * 1.02
	var direction: Vector3 = (game.player.global_position + Vector3.UP * 0.95 - source).normalized() if game != null else attack_direction
	junk.global_position = source

	B.facet(junk, Vector3.ZERO, Vector3(0.23, 0.21, 0.28), B.mat("#a3a7ae", 0.6))
	var band = B.box(junk, Vector3.ZERO, Vector3(0.27, 0.065, 0.21), B.mat("#a33142")); band.rotation.z = 0.4
	junk.rotation.y = atan2(-direction.x, -direction.z)
	projectiles.append({"node": junk, "direction": direction, "life": 2.4})

func take_damage(amount: int) -> void:
	var previous := health
	super.take_damage(amount)
	if previous > 0 and health <= 0 and game.get("scrappers") != null:
		game.scrappers.enemy_defeated(id, global_position, species_id)
