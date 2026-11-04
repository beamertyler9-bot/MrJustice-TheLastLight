extends Node3D

const B = preload("res://scripts/build.gd")
var game
var trap_type := "spikes"
var phase := "idle"
var timer := 0.0
var windup_time := 1.15
var damage_radius := 2.25
var warning: MeshInstance3D
var spikes: Array[MeshInstance3D] = []
var pulse: MeshInstance3D
var struck := false

func _ready() -> void:
	add_to_group("deep_trap")
	add_to_group("batch_dynamic")
	var metal := B.mat("#776d58", 0.4)
	var mark := B.mat("#d4ac65", 0, 0.3)
	B.cyl(self, Vector3(0, -0.005, 0), damage_radius, 0.035, B.mat("#555b5b"))
	B.ring(self, Vector3(0, 0.035, 0), damage_radius, 0.08, metal)
	warning = B.ring(self, Vector3(0, 0.07, 0), damage_radius, 0.11, B.mat("#ffb36d", 0, 0.8))
	warning.visible = false
	pulse = B.cyl(self, Vector3(0, 0.07, 0), damage_radius, 0.04, B.mat("#ffe6a1", 0, 0.8))
	pulse.visible = false
	for i in range(8):
		var angle := float(i) * TAU / 8
		var p := Vector3(cos(angle) * damage_radius * 0.68, 0.02, sin(angle) * damage_radius * 0.68)
		B.box(self, p, Vector3(0.3, 0.04, 0.3), mark)
		if trap_type == "spikes":
			var source = load("res://scripts/equipment_art.gd")._fitted_head("weapons_spear", Vector3(0.28, 1.25, 0.28), Vector3.ZERO, Basis.IDENTITY, 0.72)
			source.set_meta("replacement_source", "weapons_spear")
			var spike := B.mesh(self, source, metal, p + Vector3.DOWN * 0.35)
			spikes.append(spike)
		elif trap_type == "embers":
			var ember := B.facet(self, p + Vector3.UP * 4.5, Vector3(0.22, 0.6, 0.25), B.mat("#e8ac63", 0, 0.55))
			spikes.append(ember)
		else:
			B.facet(self, p + Vector3.UP * 0.08, Vector3(0.16, 0.2, 0.16), B.mat("#91b9bd", 0, 0.3))
	reset()

func tick(dt: float) -> void:
	if game == null or game.mode != "play" or not is_instance_valid(game.player) or dt <= 0:
		return
	var offset: Vector3 = game.player.global_position - global_position
	var nearby := absf(offset.y) < 1.6 and Vector2(offset.x, offset.z).length() < damage_radius + 1.0
	if phase == "idle":
		if nearby and _clear_sight():
			phase = "warning"
			timer = windup_time
			struck = false
			game.audio.cue("bag")
	elif phase == "warning":
		timer = maxf(0, timer - dt)
		if timer <= 0:
			phase = "active"
			timer = 0.3
			_try_hit()
			game.audio.cue("impact")
	elif phase == "active":
		_try_hit()
		timer = maxf(0, timer - dt)
		if timer <= 0:
			phase = "recovery"
			timer = 2.6
	elif phase == "recovery":
		timer = maxf(0, timer - dt)
		if timer <= 0: phase = "idle"
	warning.visible = phase == "warning"
	pulse.visible = phase == "active"
	if warning.visible:
		var progress := 1.0 - timer / windup_time
		warning.scale = Vector3.ONE * (0.55 + 0.45 * progress)
		warning.rotation.y += dt * 1.8
	if pulse.visible: pulse.scale = Vector3(1, 1.0 + timer * 14, 1)
	for spike in spikes:
		if trap_type == "spikes":
			spike.position.y = 0.65 if phase == "active" else -0.6
			spike.visible = phase in ["warning", "active"]
		else:
			spike.visible = phase in ["warning", "active"]
			spike.position.y = 0.5 if phase == "active" else 4.5 - 2.0 * (1.0 - timer / windup_time)

func _try_hit() -> void:
	if struck or not _clear_sight(): return
	var offset: Vector3 = game.player.global_position - global_position
	if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < damage_radius:
		struck = true
		game.player.take_damage(1)

func _clear_sight() -> bool:
	var start := global_position + Vector3.UP * 0.6
	var finish: Vector3 = game.player.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1 | 8)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func reset() -> void:
	phase = "idle"
	timer = 0
	struck = false
	if is_instance_valid(warning): warning.visible = false
	if is_instance_valid(pulse): pulse.visible = false
	for spike in spikes: spike.visible = false
