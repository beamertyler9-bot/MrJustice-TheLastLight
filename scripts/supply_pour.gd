extends Node3D


const B = preload("res://scripts/build.gd")
const Items = preload("res://scripts/item_models.gd")
signal use_contact(id: String)
signal use_ended
const PLAYBACK := 1.25
const DURATION := 1.12 * PLAYBACK
const FINISH := 1.65 * PLAYBACK
const CONTACT := 0.39 * PLAYBACK
var contact_sent = false
var paused = false
var hero
var age: float = -1.0
var kind := ""
var waiting := false
var vessel_mount: Node3D
var vessel_model: Node3D
var vessels: Dictionary = {}
var stream: MeshInstance3D
var rivulets: Array[MeshInstance3D] = []
var drops: Array[MeshInstance3D] = []
var liquid: StandardMaterial3D
var film: ShaderMaterial
var _start_wrist := Vector3.ZERO
var _grip_basis := Basis(Vector3.FORWARD, 0.0)

func setup(character) -> void:
	hero = character
	name = "FacePour"
	liquid = StandardMaterial3D.new()
	liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.roughness = 0.09
	liquid.metallic_specular = 0.9
	liquid.cull_mode = BaseMaterial3D.CULL_DISABLED
	film = ShaderMaterial.new(); film.shader = load("res://shaders/face_liquid.gdshader")
	vessel_mount = Node3D.new(); vessel_mount.name = "PourVesselGrip"; hero.hands[1].add_child(vessel_mount)
	vessel_mount.position = Vector3(0, -0.13, 0.12)
	for id in ["tonic", "mana_potion", "coffee"]:
		var model = Items.build(vessel_mount, id)
		model.scale = Vector3.ONE * (0.5 if id == "coffee" else 0.55)
		model.position = -(model.basis * Items.grip_anchor(id)); model.hide(); vessels[id] = model
	var cylinder = CylinderMesh.new(); cylinder.top_radius = 0.009; cylinder.bottom_radius = 0.007; cylinder.height = 1.0; cylinder.radial_segments = 6
	stream = B.mesh(self, cylinder, liquid); stream.name = "PourStream"
	for i in range(6):
		var quad = QuadMesh.new(); quad.size = Vector2.ONE
		var node = B.mesh(self, quad, film); node.name = "GlassRivulet%d" % i; rivulets.append(node)
	var droplet = SphereMesh.new(); droplet.radius = 0.009; droplet.height = 0.025; droplet.radial_segments = 6; droplet.rings = 3
	for i in range(8):
		var node = B.mesh(self, droplet, liquid); node.name = "RunoffDrop%d" % i; drops.append(node)
	for node in [stream] + rivulets + drops: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cancel()

func active() -> bool:
	return age >= 0.0 and age < DURATION

func begin(id: String) -> bool:
	if id not in ["tonic", "mana_potion", "coffee"] or active(): return false
	contact_sent = false; paused = false
	kind = id; age = 0.0; waiting = hero.bag_progress > 0.005
	vessel_model = vessels[id]
	for key in vessels: vessels[key].visible = key == id
	_grip_basis = Basis(Vector3.BACK, PI * 0.5 - (0.28 if id == "coffee" else 0.42))
	vessel_mount.basis = _grip_basis
	liquid.albedo_color = Color(0.35, 0.78, 0.3, 0.8) if id == "tonic" else Color(0.29, 0.12, 0.045, 0.9)
	if id == "mana_potion": liquid.albedo_color = Color(0.16, 0.49, 0.86, 0.8)
	film.set_shader_parameter("liquid_tint", liquid.albedo_color)
	_start_wrist = hero.torso.to_local(hero.hands[1].global_position)
	for node in rivulets + drops: node.hide()
	stream.hide(); visible = not waiting; vessel_mount.visible = not waiting
	return true

func cancel() -> void:
	var was_started = age >= 0.0
	age = -1.0; waiting = false; paused = false; hide()
	if vessel_mount != null: vessel_mount.hide()
	if stream != null: stream.hide()
	for node in rivulets + drops: node.hide()
	if was_started: use_ended.emit()

func tick(dt: float) -> void:
	if age < 0.0 or paused: return
	if waiting:
		if hero.bag_progress > 0.005: return
		waiting = false; _start_wrist = hero.torso.to_local(hero.hands[1].global_position)
		show(); vessel_mount.show()
	age += dt
	if not contact_sent and age >= CONTACT:
		contact_sent = true; use_contact.emit(kind)
	if age >= FINISH: cancel()

func pose(dt: float) -> void:
	if age < 0.0 or waiting: return
	var sample_time = age / PLAYBACK
	var lift = smoothstep(0.0, 0.28, sample_time) * (1.0 - smoothstep(0.84, 1.12, sample_time))
	var tip = smoothstep(0.24, 0.42, sample_time) * (1.0 - smoothstep(0.76, 0.94, sample_time))
	vessel_mount.visible = active()
	if active():
		var item_basis = hero.head.global_basis.orthonormalized() * Basis(Vector3.RIGHT, 2.25 * tip)
		var palm_basis = item_basis * _grip_basis.inverse()
		var hand_scale: float = hero.hands[1].global_basis.get_scale().x
		var mouth = Vector3(0, 0.3, -0.14) if kind == "coffee" else Vector3(0, 0.489, 0)
		var scale_factor: float = 0.5 if kind == "coffee" else 0.55
		var lip_offset = palm_basis * (vessel_mount.position * hand_scale) + item_basis * ((mouth - Items.grip_anchor(kind)) * hand_scale * scale_factor)
		var lip_target = hero.head.to_global(Vector3(0.12, 0.15, -0.46))
		var wrist_target = hero.torso.to_local(lip_target - lip_offset)
		hero._solve_arm(1, _start_wrist.lerp(wrist_target, lift), 1.0, Vector3(0.65, 0.1, -0.25))
		hero._orient_palm(1, hero.torso.global_basis.orthonormalized().inverse() * palm_basis, 1.0)
		hero.hands[1].set_pose(dt, 0.95, 1.5, 0.8, 0.0, 48.0)
		var cork = vessel_model.get_node_or_null("Cork")
		if cork != null:
			cork.position.y = 0.12 * smoothstep(0.1, 0.21, sample_time); cork.visible = sample_time < 0.21
		var fill = vessel_model.get_node_or_null("Coffee" if kind == "coffee" else "HerbalLiquid")
		if fill != null: fill.visible = sample_time < 0.7
	var pouring = sample_time >= 0.39 and sample_time < 0.77
	stream.visible = pouring
	if pouring:
		var mouth = Vector3(0, 0.3, -0.14) if kind == "coffee" else Vector3(0, 0.489, 0)
		var start = to_local(vessel_model.to_global(mouth))
		var end = Vector3(0.08, 0.04, -0.345)
		var delta = end - start
		stream.position = (start + end) * 0.5
		stream.basis = Basis(Quaternion(Vector3.UP, delta.normalized())).scaled_local(Vector3(1, delta.length(), 1))
	for i in range(rivulets.size()):
		var node = rivulets[i]
		var flow = sample_time - 0.41 - float(i) * 0.025
		node.visible = flow > 0.0 and flow < 0.68
		if node.visible:
			var distance = 0.19 * flow + 0.55 * flow * flow
			var length = minf(0.16, 0.025 + flow * 0.18)
			node.position = Vector3(0.08 + (float(i) - 2.5) * 0.043 + sin(flow * 4.0 + float(i)) * 0.008, 0.04 - distance, -0.346 - float(i % 2) * 0.002)
			node.position.y = maxf(-0.25 + length * 0.5, node.position.y)
			node.scale = Vector3(0.01 + float(i % 3) * 0.003, length, 1)
	for i in range(drops.size()):
		var node = drops[i]
		var fall = sample_time - 1.03 - float(i) * 0.025
		node.visible = fall > 0.0 and fall < 0.4
		if node.visible: node.position = Vector3(0.08 + (float(i % 6) - 2.5) * 0.043, -0.275 - 0.25 * fall - 2.8 * fall * fall, -0.39 - fall * 0.12)
