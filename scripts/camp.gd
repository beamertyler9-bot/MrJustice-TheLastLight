extends Node3D
const B = preload("res://scripts/build.gd")
const REST_SPOT = Vector3(0.92, 0, 0.69)
var sleep_pack: Node3D
var age: float = 0.0
var fire: Node3D
var glow: OmniLight3D
var embers: Array[MeshInstance3D] = []

func _ready() -> void:
	name = "TravelersCamp"
	set_meta("id", "travelers_camp")
	set_meta("kind", "camp")
	set_meta("label", "B · Rest at your camp")
	add_to_group("interactable")
	load("res://scripts/camp_art.gd").build(self)
	fire = Node3D.new(); fire.name = "LiveCampFlame"; fire.add_to_group("batch_dynamic"); add_child(fire)
	var flame = B.flame(fire, Vector3(0, 0.12, 0), Vector3(0.54, 0.9, 0.46))


	flame.position.y += 1.02 - (flame.transform * flame.mesh.get_aabb()).end.y
	glow = OmniLight3D.new(); glow.position.y = 0.8; glow.light_color = Color("#ffbd7f"); glow.light_energy = 1.2; glow.omni_range = 8; add_child(glow)
	for i in range(7):
		var ember = B.ball(self, Vector3.ZERO, Vector3.ONE * 0.035, B.mat("#ffe9ae", 0, 1)); embers.append(ember)

func _process(dt: float) -> void:
	age += dt
	fire.scale = Vector3(1 + sin(age * 7) * 0.06, 1 + sin(age * 9) * 0.1, 1 + cos(age * 6) * 0.06)
	fire.scale *= 0.65
	fire.rotation.y = sin(age * 2) * 0.15
	glow.light_energy = 1.15 + sin(age * 8.7) * 0.09
	for i in range(embers.size()):
		var t = fposmod(age * 0.5 + i * 0.14, 1)
		embers[i].position = Vector3(sin(i * 2.5 + t * 5) * t * 0.35, 0.7 + t * 1.7, cos(i * 1.7 + t * 4) * t * 0.3)
		embers[i].scale = Vector3.ONE * 0.035 * (1 - t)

func roast_target() -> Vector3:
	var top := 0.0
	for mesh in fire.get_children():
		if mesh is MeshInstance3D:
			for i in range(8): top = maxf(top, (mesh.transform * mesh.mesh.get_aabb().get_endpoint(i)).y)
	return global_position + Vector3.UP * (top * 0.65 * 1.1 + 0.35)

func stage_sleep_pack(hero) -> void:
	if sleep_pack == null:
		sleep_pack = hero.backpack.duplicate(); sleep_pack.name = "BedsideBackpack"; add_child(sleep_pack)
		sleep_pack.scale = Vector3.ONE * hero.MODEL_SCALE; sleep_pack.position = Vector3(-1.25, 0.13, -1.35); sleep_pack.rotation = Vector3(0, -0.2, 0)
	sleep_pack.hide()
