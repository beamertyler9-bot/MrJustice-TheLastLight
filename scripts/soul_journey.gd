extends RefCounted

const B = preload("res://scripts/build.gd")
const CYAN = Color("#83f1ed")
var game
var echo: Node3D

func setup(owner_game) -> void:
	game = owner_game

func restore_echo() -> void:
	_retire_echo()
	if game == null or not is_instance_valid(game.world) or not game.state.death_echo_active:
		return
	var point: Vector3 = game.state.death_echo_position
	if not _valid_point(point):
		return
	echo = Node3D.new()
	echo.name = "LostLightEcho"
	echo.position = point + Vector3.UP * 0.2
	echo.set_meta("id", "lost_light_echo")
	echo.set_meta("kind", "death_echo")
	echo.set_meta("label", "Recover lost Light Essence")
	echo.set_meta("amount", game.state.death_echo_shards)
	game.world.add_child(echo)
	echo.add_to_group("interactable")
	var light = B.mat("#83f1ed", 0.15, 1.6)
	var dark = B.mat("#285f69", 0.25)
	B.ring(echo, Vector3.ZERO, 0.44, 0.035, light)
	B.ring(echo, Vector3(0, 0.1, 0), 0.25, 0.023, light)

	var crystal = B.cyl(echo, Vector3(0, 0.4, 0), 0.18, 0.64, light, false, 0.0)
	crystal.rotation.z = -0.13
	var base = B.cyl(echo, Vector3(0, 0.02, 0), 0.25, 0.08, dark, false, 0.19)
	base.rotation.y = 0.3
	for index in range(3):
		var angle: float = float(index) * TAU / 3.0 + 0.25
		var chip = B.cyl(echo, Vector3(cos(angle) * 0.29, 0.17 + index * 0.04, sin(angle) * 0.29), 0.07, 0.23, light, false, 0.0)
		chip.rotation.z = sin(angle) * 0.35

func rest_at(point: Vector3) -> bool:
	if game == null or not is_instance_valid(game.player) or not is_instance_valid(game.world):
		return false
	if game.mode not in ["play", "camp", "rest", "sleep"] or not _valid_point(point) or point.distance_to(game.player.global_position) > 1.5:
		return false
	if _busy() or not _valid_point(_ground_point(point, 1.1, false)):
		game.toast("Find firm, dry ground and finish your movement before resting.")
		return false
	if _near_threat():
		game.toast("Find a quiet moment away from danger before resting.")
		return false
	game.state.checkpoint = point
	game.state.player_position = point
	game.state.health = game.state.max_health
	game.state.stamina = game.state.max_stamina
	game.reset_enemies()
	game.state.save_game()
	_cue("collect")
	game.toast("Lantern kindled. Strength restored. Journey saved.")
	return true

func on_defeat() -> void:
	if game == null or not is_instance_valid(game.player) or not is_instance_valid(game.world):
		return
	var point: Vector3 = _ground_point(game.player.global_position, 6.0, false)
	if not _valid_point(point):
		point = _ground_point(game.player.last_grounded_position, 1.5, true)
	if not _valid_point(point):
		point = _ground_point(game.state.checkpoint, 1.5, true)
	if not _valid_point(point):
		point = _ground_point(game.world.get_spawn(), 1.5, true)
	if _valid_point(point):
		game.state.register_defeat(point)


	restore_echo()
	game.reset_enemies()

func recover_echo(node: Node3D) -> bool:
	if game == null or not is_instance_valid(node) or not is_instance_valid(echo) or node != echo or node.is_queued_for_deletion() or game.mode != "play":
		return false
	if not game.usable_node(node) or not game.state.recover_echo():
		return false
	game.burst(node.global_position + Vector3.UP * 0.25, CYAN, 14)
	_cue("collect")
	_retire_echo()
	game.state.save_game()
	game.toast("Lost Light Essence recovered.")
	return true

func _retire_echo() -> void:
	if is_instance_valid(echo):
		echo.remove_from_group("interactable")
		echo.hide()
		echo.queue_free()
	echo = null

func _cue(id: String) -> void:
	if game.audio != null:
		game.audio.cue(id)

func _busy() -> bool:
	var player = game.player
	return player.climbing or player.mantle_time > 0 or player.throw_pending or is_instance_valid(player.held_body) or player.hooking > 0 or player.dodge_time > 0 or player.cast_time > 0 or player.beam_contact >= 0 or player.beam_charging or player.ability_aiming or player.visual.attack_time > 0 or player.visual.is_throwing() or player.visual.grapple_active()

func _near_threat() -> bool:
	for enemy in game.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not game.world.is_ancestor_of(enemy) or not enemy.is_visible_in_tree() or int(enemy.health) <= 0:
			continue
		if enemy.global_position.distance_to(game.player.global_position) > 12.0:
			continue
		var hit: Dictionary = game.player.ray(game.player.global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1 | 8)
		if hit.is_empty() or hit.collider == enemy or enemy.is_ancestor_of(hit.collider):
			return true
	return false

func _ground_point(point: Vector3, distance: float, allow_terrain: bool) -> Vector3:
	if not _valid_point(point):
		return Vector3.INF
	var interior: bool = not str(game.world.interior_at(point)).is_empty()
	var hit: Dictionary = game.player.ray(point + Vector3.UP * 0.55, point - Vector3.UP * distance, 1 | 8)
	if not hit.is_empty() and hit.normal.y >= 0.65:
		var ground: Vector3 = hit.position
		if interior or ground.y > game.world.water_level + 0.35:
			return ground
	if allow_terrain and not interior:
		var height: float = game.world.height_at(point.x, point.z)
		if is_finite(height) and height > game.world.water_level + 0.35 and absf(height - point.y) <= 0.7:
			return Vector3(point.x, height, point.z)
	return Vector3.INF

static func _valid_point(point: Vector3) -> bool:
	return point.is_finite() and absf(point.x) <= 100000.0 and absf(point.y) <= 100000.0 and absf(point.z) <= 100000.0
