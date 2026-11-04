extends "res://scripts/enemy.gd"

const Art = preload("res://scripts/dissonance_art.gd")
var camp_id := "dissonance_stronghold"
var boss_active := false
var attack_kind := "blast"
var staff_muzzle: Node3D
var waiting_label: Label3D
func configure_dissonance() -> void:
	if is_node_ready(): return
	species_id = "dissonance"; display_name = "Dissonance"
	profile = {"name": "Dissonance", "model": "Dissonance", "hp": 140, "speed": 2.4, "reach": 16.0, "windup": 1.25, "recovery": 0.85, "cooldown": 2.8, "damage": 4, "radius": 0.38, "height": 2.05, "attack": "ranged", "boss": true}; health = 140
func _ready() -> void:
	if species_id != "dissonance": configure_dissonance()
	super._ready(); set_meta("id", id); set_meta("scrapper", true); set_meta("camp_id", camp_id); set_meta("boss_waiting", true)
	waiting_label = Label3D.new(); waiting_label.name = "GuardWard"; waiting_label.font_size = 32; waiting_label.pixel_size = 0.007; waiting_label.position.y = 2.48; waiting_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; waiting_label.modulate = Color("#ceb1e9"); add_child(waiting_label)
func _build_visual() -> void: Art.bind(self)
func _animate(dt: float, speed: float) -> void: Art.pose(self, dt, speed)
func _animate_creature(dt: float, speed: float) -> void: Art.pose(self, dt, speed)
func _contact_pose() -> void: Art.pose(self, 0, 0, true)
func _guards_remaining() -> int:
	if game == null or game.get("scrappers") == null: return -1
	return game.scrappers.bandits_remaining(camp_id)
func _activate() -> bool:
	if _guards_remaining() != 0: return false
	if not boss_active:
		boss_active = true; set_meta("boss_waiting", false); waiting_label.hide(); cooldown = 0.9
		if game.has_method("toast"): game.toast("Dissonance: ‘Fine. I will make you listen myself.’")
	return true
func _physics_process(dt: float) -> void:
	if game == null or game.mode != "play" or health <= 0 or not is_inside_tree() or is_queued_for_deletion(): return
	if not _activate():
		windup = 0; recovery = 0; charge_time = 0; telegraph.hide(); _clear_projectiles(); clock += dt; velocity.x = 0; velocity.z = 0
		waiting_label.text = "Dissonance waits · %d bandits remain" % maxi(0, _guards_remaining())
		if not bool(get_meta("magic_held", false)) and not bool(get_meta("magic_stasis", false)):
			velocity.y -= 19 * dt; move_and_slide()
		_animate(dt, 0); return
	if windup <= 0 and recovery <= 0:
		attack_kind = "slam" if global_position.distance_to(game.player.global_position) < 3.3 else "blast"
		profile.attack = "melee" if attack_kind == "slam" else "ranged"; profile.reach = 3.0 if attack_kind == "slam" else 16.0; profile.windup = 1.1 if attack_kind == "slam" else 1.25
	super._physics_process(dt)
func _launch_projectile() -> void:
	if game == null or projectiles.size() >= 3: return
	var start = staff_muzzle.global_position; var direction = (game.player.global_position + Vector3.UP * 0.95 - start).normalized()
	var pulse = Node3D.new(); pulse.name = "DissonanceSoundBlast"; add_child(pulse); pulse.top_level = true; pulse.global_position = start
	for i in range(4):
		var ring = B.ring(pulse, Vector3(0, 0, i * 0.11), 0.3 - i * 0.045, 0.025, B.mat("#b18adb" if i % 2 == 0 else "#bfc1ca", 0, 0.55)); ring.rotation.x = PI * 0.5
	pulse.look_at(start + direction, Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	projectiles.append({"node": pulse, "direction": direction, "life": 2.6})
func take_damage(amount: int) -> void:
	if health > 0 and not _activate(): return
	var previous = health; super.take_damage(amount)
	if previous > 0 and health <= 0 and game.get("scrappers") != null: game.scrappers.enemy_defeated(id, global_position, species_id)
func _drop_light_essence(_amount: int, legacy_credit := true) -> void: super._drop_light_essence(40, legacy_credit)
