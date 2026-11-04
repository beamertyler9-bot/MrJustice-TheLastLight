extends Node3D

const B = preload("res://scripts/build.gd")
const Hand = preload("res://scripts/justice_hand.gd")
const Grapple = preload("res://scripts/grapple_hand.gd")
const Catalog = preload("res://scripts/crafting.gd")
const Workbench = preload("res://scripts/workbench.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const CapeCloth = preload("res://scripts/cape_cloth.gd")
const SupplyPour = preload("res://scripts/supply_pour.gd")
var supply_pour
var authored_climb = preload("res://scripts/hero_authored_climb.gd").new()
var rig: Node3D
var torso: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var hands: Array[Node3D] = []
var wrists: Array[Node3D] = []
var grapple = Grapple.new()
var aim_kind: String = "beam"
var mantle_contacts: Array[Vector3] = []
var mantle_progress: float = -1.0
var mantle_height: float = 0.9
var feet: Array[Node3D] = []
var finger_joints: Array = []
var thumb_joints: Array[Node3D] = []
var cape: MeshInstance3D
var backpack: Node3D
var lid: Node3D
var _bag_straps: Array = [[], []]
var _bag_hand_origins: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _bag_elbow_origins: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var flame: MeshInstance3D
var inner_flame: MeshInstance3D
var grip: Node3D
var lantern: OmniLight3D
var time: float = 0.0
var phase: float = 0.0
var bag_progress: float = 0.0
var bag_target: float = 0.0
var attack_time: float = 0.0
var carry_pose: bool = false
var carry_half_width: float = 0.52
var carry_half_height: float = 0.47
var carry_half_depth: float = 0.47
var aim_weight: float = 0.0
var aim_target: Vector3 = Vector3.FORWARD * 20
var aim_camera: Camera3D
var cape_material: Material
var weapon_id: String = "fists"
var charge_weight: float = 0.0:
	set(value):
		charge_weight = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
var dodge_progress: float = -1.0:
	set(value):
		dodge_progress = clampf(value, -1.0, 1.0) if is_finite(value) else -1.0
var dodge_direction: Vector3 = Vector3.FORWARD
var rest_pose: String = ""
var rest_target: Vector3 = Vector3.INF
var _weapon_mount: Node3D
var _weapons: Dictionary = {}
var held_item_id: String = ""
var _held_mount: Node3D
var _held_props: Dictionary = {}
var _camp_props: Node3D
var _cup: Node3D
var _roasting_stick: Node3D
var _rest_weight: float = 0.0
var _dodge_tuck: float = 0.0
var _dodge_surfaces: Array[MeshInstance3D] = []
var _grimoire: Node3D
var _grimoire_cover: Node3D
var _grimoire_page: Node3D
var _grimoire_rune: Node3D
var _grimoire_rune_material: StandardMaterial3D
var _grimoire_left: float = 0.0
var _grimoire_pose_weight: float = 0.0
var _grimoire_duration: float = 0.62
var _grimoire_origins: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
const TOOLS = ["makeshift_axe", "stone_axe", "stone_pickaxe"]
const EquipmentArt = preload("res://scripts/equipment_art.gd")



const STANDING_HEIGHT_METRES: float = 4.0 * 0.3048
const MODEL_NEUTRAL_HEIGHT: float = 2.6425
const MODEL_SCALE: float = STANDING_HEIGHT_METRES / MODEL_NEUTRAL_HEIGHT
const STEP: float = 1.0 / 120.0
const TORSO_PIVOT: float = 1.13
const THIGH_LENGTH: float = 0.42
const SHIN_LENGTH: float = 0.42
const WALK_STANCE: float = 0.62
const RUN_STANCE: float = 0.28
const THROW_DURATION: float = 1.3
const THROW_CONTACT: float = 11.0 / 15.0



static func strike_contact(id: String, variant: int = 0) -> float:
	if id == "stone_pickaxe":
		return 0.42
	if id == "stone_hammer":
		return 0.38
	if id in ["makeshift_axe", "stone_axe"]:
		return 0.34
	if id in ["iron_blade", "dawn_blade"]:
		return [0.24, 0.21, 0.28][posmod(variant, 3)] * (0.92 if id == "dawn_blade" else 1.0)
	match posmod(variant, 3):
		0: return 0.2
		1: return 0.22
	return 0.28

static func strike_duration(id: String, variant: int = 0) -> float:
	if id == "stone_pickaxe":
		return 1.04
	if id == "stone_hammer":
		return 0.96
	if id in ["makeshift_axe", "stone_axe"]:
		return 0.86
	if id in ["iron_blade", "dawn_blade"]:
		return [0.56, 0.55, 0.68][posmod(variant, 3)] * (0.92 if id == "dawn_blade" else 1.0)
	match posmod(variant, 3):
		0: return 0.54
		1: return 0.58
	return 0.66

var _accumulator: float = 0.0
var _has_context: bool = false
var _last_context_position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _grounded: bool = true
var _floor_normal: Vector3 = Vector3.UP
var _speed: float = 0.0
var _run: float = 0.0
var _locomotion: float = 0.0
var _weights: Dictionary = {"jump": 0.0, "climb": 0.0, "mantle": 0.0, "swim": 0.0, "beam": 0.0, "hook": 0.0}
var _foot_planted: Array[bool] = [false, false]
var _foot_anchors: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _swing_origins: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _swing_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _swing_start_phase: Array[float] = [0.0, 0.0]
var _swing_progress: Array[float] = [0.0, 0.0]
var _plant_lift: Array[float] = [0.0, 0.0]
var _foot_pitch: Array[float] = [0.0, 0.0]
var _was_walking: bool = false
var _settle_left: float = 0.0
var _settle_origins: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _footsteps: int = 0
var _foot_positions: Array[Vector3] = [Vector3(-0.19, 0.085, 0), Vector3(0.19, 0.085, 0)]
var _foot_world_positions: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _event_left: Dictionary = {"jump": 0.0, "land": 0.0, "hurt": 0.0, "beam": 0.0, "hook": 0.0}
var _event_strength: Dictionary = {"jump": 1.0, "land": 1.0, "hurt": 1.0, "beam": 1.0, "hook": 1.0}
var _strike_duration: float = 0.48
var _strike_variant: int = 0
var _punch_arm: int = 1
var _next_punch_arm: int = 1
var _punch_start_upper: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _punch_start_lower: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _strike_strength: float = 1.0
var _last_attack_time: float = 0.0
var _strike_origins: Array[Vector3] = [Vector3(-0.4, -0.25, -0.05), Vector3(0.43, -0.15, -0.25)]
var _strike_start_tool: Basis = Basis.IDENTITY
var _sword_last_orientation: Basis = Basis.IDENTITY
var _sword_last_wrist := Quaternion.IDENTITY
var _sword_free_start_upper := Quaternion.IDENTITY
var _sword_free_start_lower := Quaternion.IDENTITY
var _sword_free_start_wrist := Quaternion.IDENTITY
var _sword_free_upper := (Basis(Vector3.BACK, -PI * 0.25) * Basis(Vector3.RIGHT, -PI / 18.0)).get_rotation_quaternion()
var _sword_free_lower := Quaternion(Vector3.RIGHT, PI / 12.0)
var _throw_left: float = 0.0
var _throw_release_pending: bool = false
var _throw_released: bool = false
var _cape_shader: ShaderMaterial
var _cape_cloth: RefCounted
var _last_motion: String = "idle"
var _motion_age: float = 0.0
var _fall_age: float = 0.0
var _swim_phase: float = 0.0
var _climb_normal: Vector3 = Vector3.ZERO
var _climb_velocity: Vector3 = Vector3.ZERO
var _climb_query: Callable

func _ready() -> void:
	supply_pour = SupplyPour.new()
	scale = Vector3.ONE * MODEL_SCALE
	var silver = B.surface("silver", "#ccd3d6", 0.78)
	var highlight = B.surface("silver", "#eff1f2", 0.78)
	var dark = B.mat("#29393d", 0.55)
	var brass = B.mat("#b89965", 0.68)
	rig = Node3D.new()
	add_child(rig)
	torso = Node3D.new()
	rig.add_child(torso)
	B.beveled_box(torso, Vector3(0, 1.47, 0), Vector3(0.61, 0.64, 0.36), silver)

	B.beveled_box(torso, Vector3(0, 1.47, -0.19), Vector3(0.56, 0.58, 0.045), highlight)
	B.beveled_box(torso, Vector3(0, 1.06, 0), Vector3(0.45, 0.22, 0.31), silver)
	B.ball(torso, Vector3(0, 1.17, 0), Vector3(0.32, 0.16, 0.26), dark)
	B.cyl(torso, Vector3(0, 1.87, 0), 0.09, 0.19, dark)
	B.cyl(torso, Vector3(0, 1.82, 0), 0.12, 0.045, silver)
	B.cyl(torso, Vector3(0, 1.955, 0), 0.12, 0.04, silver)
	var core = B.cyl(torso, Vector3(0, 1.57, -0.242), 0.105, 0.06, dark)
	core.rotation.x = PI / 2
	B.ball(torso, Vector3(0, 1.57, -0.278), Vector3(0.15, 0.15, 0.045), B.mat("#86e3ec", 0.2, 0.65))
	head = Node3D.new()
	head.name = "RectangularLantern"
	head.position.y = 2.28
	torso.add_child(head)
	B.box(head, Vector3(0, -0.31, 0), Vector3(0.74, 0.11, 0.74), silver)
	B.box(head, Vector3(0, 0.31, 0), Vector3(0.74, 0.1, 0.74), silver)
	B.box(head, Vector3(0, 0.37, 0), Vector3(0.75, 0.075, 0.75), highlight)
	for x in [-0.32, 0.32]:
		for z in [-0.32, 0.32]:
			B.box(head, Vector3(x, 0, z), Vector3(0.1, 0.57, 0.1), silver)
	var glass = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.91, 0.96, 1.0, 0.065)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic_specular = 0.65
	var window = QuadMesh.new()
	window.size = Vector2(0.55, 0.51)
	for z in [-0.325, 0.325]:
		B.mesh(head, window, glass, Vector3(0, 0, z))
	for x in [-0.325, 0.325]:
		B.mesh(head, window, glass, Vector3(x, 0, 0)).rotation.y = PI / 2

	for level in [-0.31, 0.31]:
		for side in [-1.0, 1.0]:
			for edge in [-0.25, 0.25]:
				B.cyl(head, Vector3(edge, level, side * 0.376), 0.014, 0.008, dark).rotation.x = PI / 2
				B.cyl(head, Vector3(side * 0.376, level, edge), 0.014, 0.008, dark).rotation.z = PI / 2
	for side in [-1.0, 1.0]:
		B.ball(torso, Vector3(side * 0.23, 1.765, -0.19), Vector3(0.065, 0.065, 0.028), brass)
	B.cyl(head, Vector3(0, -0.24, 0), 0.12, 0.05, brass)
	flame = B.flame(head, Vector3(0, -0.045, 0), Vector3(0.21, 0.41, 0.2))


	flame.material_override = flame.material_override.duplicate()
	flame.material_override.set_shader_parameter("emission_strength", 1.6)
	inner_flame = B.ball(head, Vector3(0, -0.12, -0.045), Vector3(0.13, 0.24, 0.11), B.mat("#fff0ad", 0, 1.0))
	inner_flame.material_override = inner_flame.material_override.duplicate()
	inner_flame.material_override.emission_enabled = true
	inner_flame.material_override.emission = Color("#fff0ad")
	inner_flame.material_override.emission_energy_multiplier = 1.25
	lantern = OmniLight3D.new()
	lantern.name = "FlameLight"
	lantern.position = Vector3(0, 0, -0.1)
	lantern.light_color = Color("#ffd79b")
	lantern.light_energy = 2.3
	lantern.omni_range = 5.5
	lantern.omni_attenuation = 1.0
	lantern.light_specular = 0.8
	lantern.shadow_enabled = false
	head.add_child(lantern)
	for side in [-1.0, 1.0]:
		var arm = Node3D.new()
		arm.position = Vector3(side * 0.4, 1.73, 0)
		torso.add_child(arm)
		arms.append(arm)
		B.ball(arm, Vector3.ZERO, Vector3.ONE * 0.21, dark)
		B.beveled_box(arm, Vector3(0, -0.23, 0), Vector3(0.2, 0.39, 0.21), silver)
		B.beveled_box(arm, Vector3(0, -0.23, -0.115), Vector3(0.16, 0.3, 0.025), highlight)
		var elbow = Node3D.new()
		elbow.position.y = -0.46
		arm.add_child(elbow)
		forearms.append(elbow)
		B.ball(elbow, Vector3.ZERO, Vector3.ONE * 0.15, dark)
		B.beveled_box(elbow, Vector3(0, -0.19, 0), Vector3(0.18, 0.31, 0.2), silver)
		B.cyl(elbow, Vector3(0, -0.365, 0), 0.108, 0.07, dark)
		B.cyl(elbow, Vector3(0, -0.397, 0), 0.112, 0.025, silver)
		var wrist = Node3D.new()
		wrist.position.y = -0.41
		elbow.add_child(wrist)
		wrists.append(wrist)
		var hand = Hand.new()
		hand.side = side
		wrist.add_child(hand)
		hands.append(hand)
		finger_joints.append(hand.knuckles)
		thumb_joints.append(hand.thumb_base)
		var leg = Node3D.new()
		leg.position = Vector3(side * 0.17, 0.96, 0)
		rig.add_child(leg)
		legs.append(leg)
		B.ball(leg, Vector3.ZERO, Vector3.ONE * 0.17, dark)
		B.beveled_box(leg, Vector3(0, -0.21, 0), Vector3(0.18, 0.33, 0.19), silver)
		var knee = Node3D.new()
		knee.position.y = -0.42
		leg.add_child(knee)
		knees.append(knee)
		B.ball(knee, Vector3.ZERO, Vector3.ONE * 0.15, dark)
		B.beveled_box(knee, Vector3(0, -0.19, 0), Vector3(0.16, 0.31, 0.18), silver)
		var foot = Node3D.new()
		foot.position.y = -SHIN_LENGTH
		knee.add_child(foot)
		feet.append(foot)
		B.beveled_box(foot, Vector3(0, 0.0, -0.1), Vector3(0.24, 0.17, 0.43), silver)
		B.beveled_box(foot, Vector3(0, -0.045, -0.13), Vector3(0.25, 0.08, 0.44), dark)
		B.beveled_box(foot, Vector3(0, 0.05, -0.22), Vector3(0.23, 0.1, 0.18), highlight)
	_create_equipment()
	head.add_child(supply_pour)
	supply_pour.setup(self)
	_create_cape()
	backpack = Node3D.new()
	backpack.name = "Backpack"
	torso.add_child(backpack)
	var leather = B.surface("leather", "#79543a")


	for i in range(2):
		for link in range(4):
			var strap = B.box(torso, Vector3.ZERO, Vector3(0.055, 1.0, 0.022), leather)
			strap.name = "PackStrap%d_%d" % [i, link]
			_bag_straps[i].append(strap)

	for z in [-0.13, 0.13]:
		B.beveled_box(backpack, Vector3(0, 0, z), Vector3(0.5, 0.55, 0.03), leather)
	for x in [-0.235, 0.235]:
		B.beveled_box(backpack, Vector3(x, 0, 0), Vector3(0.03, 0.55, 0.26), leather)
	B.beveled_box(backpack, Vector3(0, -0.255, 0), Vector3(0.5, 0.04, 0.29), B.surface("leather", "#443328"))
	B.beveled_box(backpack, Vector3(0, -0.11, 0.17), Vector3(0.32, 0.23, 0.1), B.surface("leather", "#9a6f48"))
	for x in [-0.17, 0.17]:
		B.beveled_box(backpack, Vector3(x, 0, 0.16), Vector3(0.05, 0.56, 0.04), B.mat("#b19865"))
		B.beveled_box(backpack, Vector3(x, -0.01, 0.19), Vector3(0.09, 0.08, 0.025), brass)
	lid = Node3D.new()
	lid.position = Vector3(0, 0.25, -0.14)
	backpack.add_child(lid)
	B.beveled_box(lid, Vector3(0, 0.045, 0.14), Vector3(0.55, 0.1, 0.34), B.surface("leather", "#9d764d"))
	backpack.position = Vector3(0, 1.46, 0.46)

	torso.position.y = TORSO_PIVOT
	for child in torso.get_children():
		if child is Node3D:
			child.position.y -= TORSO_PIVOT
	grip = Node3D.new()
	grip.position = Vector3(0, 1.4, -0.82)
	rig.add_child(grip)
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2
		if mesh != cape:
			_dodge_surfaces.append(mesh)
	for mesh in arms[1].find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 4
	grapple.setup(hands[1], wrists[1])
	animate(STEP, "idle", 0)



func _create_equipment() -> void:
	_weapon_mount = Node3D.new()
	_weapon_mount.name = "WeaponMount"
	_weapon_mount.position = Vector3(0, -0.12, 0.12)
	_weapon_mount.rotation.z = PI * 0.5
	hands[1].add_child(_weapon_mount)
	for id in ["iron_blade", "dawn_blade"]:
		var weapon = Node3D.new()
		weapon.name = id
		_weapon_mount.add_child(weapon)
		_weapons[id] = weapon
		EquipmentArt.build_sword(weapon, id)
	for id in TOOLS:
		_create_tool(id)
	_held_mount = Node3D.new()
	_held_mount.name = "HeldItemMount"
	_held_mount.position = Vector3(0, -0.06, 0.09)
	_held_mount.rotation.x = PI * 0.5
	hands[1].add_child(_held_mount)
	_camp_props = Node3D.new()
	_camp_props.name = "CampProps"
	hands[1].add_child(_camp_props)
	_cup = Node3D.new()
	_cup.name = "CoffeeCup"
	_camp_props.add_child(_cup)
	_cup.position = Vector3(0, -0.035, 0.13)
	B.cyl(_cup, Vector3.ZERO, 0.09, 0.14, B.mat("#c9d9d3", 0.6))
	B.cyl(_cup, Vector3(0, 0.072, 0), 0.073, 0.008, B.mat("#392c24"))
	B.ring(_cup, Vector3(0.11, 0, 0), 0.055, 0.014, B.mat("#c9d9d3", 0.6)).rotation.z = PI * 0.5
	_roasting_stick = Node3D.new()
	_roasting_stick.name = "RoastingStick"
	_camp_props.add_child(_roasting_stick)
	_roasting_stick.position = Vector3(0, -0.04, 0.11)
	_roasting_stick.rotation.z = PI * 0.5
	B.cyl(_roasting_stick, Vector3(0, 0.35, 0), 0.014, 0.95, B.surface("leather", "#79543a"))
	B.beveled_box(_roasting_stick, Vector3(0, 0.78, 0), Vector3(0.13, 0.16, 0.13), B.mat("#f5deb0"))
	_create_grimoire()
	set_weapon(weapon_id)
	set_held_item(held_item_id)

func _create_grimoire() -> void:
	_grimoire = Node3D.new()
	_grimoire.name = "Grimoire"
	_grimoire.position = Vector3(0, -0.11, 0.14)
	_grimoire.rotation.x = PI * 0.5
	hands[0].add_child(_grimoire)
	var leather = B.surface("leather", "#553d5c")
	var gold = B.mat("#c8a768", 0.55)
	var paper = B.mat("#eadbb9")
	var ink = B.mat("#78617c")
	var O = load("res://scripts/world_overhaul.gd")
	var Details = load("res://scripts/household_details.gd")
	Details.place(_grimoire, "kaykit_journal_closed", Vector3(0.14, -0.014, 0), Vector3(0.3, 0.055, 0.4), Vector3(-PI * 0.5, 0, 0))
	_grimoire.set_meta("replacement_art", 29)
	B.box(_grimoire, Vector3(-0.005, 0.035, 0), Vector3(0.028, 0.08, 0.4), gold)
	_grimoire_cover = Node3D.new()
	_grimoire_cover.name = "Cover"
	_grimoire_cover.position.y = 0.07
	_grimoire.add_child(_grimoire_cover)
	O.fit(_grimoire_cover, "qprop_book_7", Vector3(0.14, -0.013, 0), Vector3(0.3, 0.026, 0.4))
	for z in [-0.14, 0.14]:
		B.box(_grimoire_cover, Vector3(0.14, 0.015, z), Vector3(0.25, 0.008, 0.018), gold)
	B.ring(_grimoire_cover, Vector3(0.14, 0.017, 0), 0.057, 0.008, gold)
	for z in [-0.12, -0.075, -0.03, 0.06, 0.105]:
		B.box(_grimoire, Vector3(0.14, 0.045, z), Vector3(0.17, 0.004, 0.007), ink)
		B.box(_grimoire_cover, Vector3(0.14, -0.025, z), Vector3(0.17, 0.004, 0.007), ink)
	_grimoire_page = Node3D.new()
	_grimoire_page.name = "TurningPage"
	_grimoire_page.position.y = 0.052
	_grimoire.add_child(_grimoire_page)
	Details.place(_grimoire_page, "kaykit_journal_open", Vector3(0.14, 0, 0), Vector3(0.265, 0.006, 0.355), Vector3(-PI * 0.5, 0, 0))
	_grimoire_rune_material = StandardMaterial3D.new()
	_grimoire_rune_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grimoire_rune_material.emission_enabled = true
	_grimoire_rune_material.emission_energy_multiplier = 0.6
	_grimoire_rune = Node3D.new()
	_grimoire_rune.name = "Rune"
	_grimoire_rune.position = Vector3(0, 0.2, 0)
	_grimoire.add_child(_grimoire_rune)
	B.ring(_grimoire_rune, Vector3.ZERO, 0.13, 0.008, _grimoire_rune_material)
	for i in range(4):
		var a = i * PI * 0.5
		var mark = B.box(_grimoire_rune, Vector3(cos(a) * 0.095, 0, sin(a) * 0.095), Vector3(0.055, 0.006, 0.012), _grimoire_rune_material)
		mark.rotation.y = -a + PI * 0.25
	_grimoire.visible = false
	_grimoire_rune.visible = false

func begin_grimoire_cast(color: Color, duration: float = 0.62) -> void:
	if _grimoire == null or not is_grimoire_equipped() or not held_item_id.is_empty() or _grimoire_blocked(_last_motion):
		cancel_grimoire_cast()
		return
	_grimoire_duration = clampf(duration, 0.3, 1.5) if is_finite(duration) else 0.62
	_grimoire_left = _grimoire_duration
	for i in range(2):
		_grimoire_origins[i] = torso.to_local(hands[i].global_position)
	_grimoire_rune_material.albedo_color = color
	_grimoire_rune_material.emission = color
	_grimoire_cover.rotation.z = 2.8
	_grimoire_page.rotation.z = 0.0
	_grimoire.visible = true
	_grimoire_rune.visible = false
	_weapon_mount.visible = false
	_held_mount.visible = false

func cancel_grimoire_cast() -> void:
	_grimoire_left = 0.0
	_refresh_grimoire(_last_motion)

func is_grimoire_equipped() -> bool:
	return weapon_id == "grimoire"



func _refresh_grimoire(motion: String) -> void:
	if _grimoire == null:
		return
	_grimoire.visible = is_grimoire_equipped() and held_item_id.is_empty() and not _grimoire_blocked(motion)
	if not is_grimoire_casting():
		_grimoire_rune.visible = false
		_grimoire_cover.rotation.z = 2.8
		_grimoire_page.rotation.z = 0.0

func _apply_grimoire_rest(dt: float) -> void:
	_solve_arm(0, Vector3(-0.44, 0.06, -0.46), _grimoire_pose_weight)
	_orient_palm(0, torso.basis.orthonormalized().inverse() * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), _grimoire_pose_weight)
	hands[0].set_pose(dt, 0.35, 0.55, 0.35, 0.25, 36.0)

func is_grimoire_casting() -> bool:
	return _grimoire_left > 0.0

func grimoire_release_time() -> float:
	return _grimoire_duration * 0.6

func _grimoire_blocked(motion: String) -> bool:
	return carry_pose or is_throwing() or attack_time > 0.0 or maxf(maxf(float(_event_left.jump), float(_event_left.hurt)), maxf(float(_event_left.beam), float(_event_left.hook))) > 0.0 or dodge_progress >= 0.0 or bag_progress > 0.01 or bag_target > 0.01 or grapple.active() or aim_weight > 0.01 or charge_weight > 0.01 or maxf(_weights.beam, _weights.hook) > 0.05 or maxf(_weights.climb, maxf(_weights.mantle, _weights.swim)) > 0.05 or motion in ["jump", "climb", "mantle", "swim", "beam", "hook"] or not rest_pose.is_empty()

func _apply_grimoire_pose(dt: float) -> void:
	var p = 1.0 - _grimoire_left / _grimoire_duration
	var weight = smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.78, 1.0, p))
	var angle = -PI * 0.5 + TAU * smoothstep(0.12, 0.6, p)
	var trace = Vector3(-0.02 + cos(angle) * 0.13, 0.25 + sin(angle) * 0.1, -0.59 + sin(angle) * 0.04)
	var release = smoothstep(0.48, 0.6, p)
	var right = trace.lerp(Vector3(0.22, 0.36, -0.71), release)
	_solve_arm(0, _grimoire_origins[0].lerp(Vector3(-0.44, 0.1, -0.49), weight), 1.0)
	_solve_arm(1, _grimoire_origins[1].lerp(right, weight), 1.0)
	_orient_palm(0, torso.basis.orthonormalized().inverse() * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), weight)
	var facing = Basis(Quaternion(Vector3.BACK, Vector3(0.12, 0.18, -1.0).normalized()))
	_orient_palm(1, torso.basis.orthonormalized().inverse() * facing, weight)
	hands[0].set_pose(dt, 0.35, 0.55, 0.35, 0.25, 60.0)
	hands[1].set_pose(dt, lerpf(0.18, 0.035, release), lerpf(0.3, 0.06, release), 0.08 * (1.0 - release), 0.75 + release * 0.25, 60.0)
	_grimoire_cover.rotation.z = 2.8 + 0.2 * smoothstep(0.03, 0.27, p) * (1.0 - smoothstep(0.73, 0.99, p))
	_grimoire_page.rotation.z = sin(smoothstep(0.16, 0.7, p) * PI) * 2.65
	_grimoire_rune.visible = p >= 0.16 and p <= 0.83
	_grimoire_rune.rotation.y = p * TAU * 0.7
	_grimoire_rune.scale = Vector3.ONE * (0.55 + sin(clampf(p, 0.0, 1.0) * PI) * 0.45)
	var attention = weight * (1.0 - exp(-dt * 14.0))
	head.rotation.x = lerp_angle(head.rotation.x, -0.14, attention)
	head.rotation.y = lerp_angle(head.rotation.y, 0.12, attention)

func _create_tool(id: String) -> void:
	var tool = Node3D.new()
	tool.name = id
	_weapon_mount.add_child(tool)
	_weapons[id] = tool
	EquipmentArt.build_tool(tool, id)
func _tool_head_mesh(id: String) -> ArrayMesh:
	var authored = EquipmentArt.head(id)
	if authored != null: return authored
	var key = "workshop_head:" + id
	if B.geometry_cache.has(key):
		return B.geometry_cache[key]


	var profile: PackedVector2Array
	if id == "makeshift_axe":
		profile = PackedVector2Array([Vector2(-0.1, 0.08), Vector2(-0.16, -0.22), Vector2(-0.095, -0.34), Vector2(0.13, -0.34), Vector2(0.18, -0.19), Vector2(0.09, 0.09)])
	elif id == "stone_axe":
		profile = PackedVector2Array([Vector2(-0.095, 0.095), Vector2(-0.19, -0.17), Vector2(-0.21, -0.37), Vector2(0.21, -0.37), Vector2(0.19, -0.17), Vector2(0.095, 0.095)])
	else:
		profile = PackedVector2Array([Vector2(-0.09, -0.46), Vector2(0.055, -0.32), Vector2(0.105, 0), Vector2(0.055, 0.32), Vector2(-0.09, 0.46), Vector2(-0.045, 0.25), Vector2(-0.035, 0), Vector2(-0.045, -0.25)])
	var front = PackedVector3Array()
	var back = PackedVector3Array()
	for p in profile:
		var thickness = lerpf(0.078, 0.012, smoothstep(0.06, 0.34 if id != "stone_pickaxe" else 0.46, absf(p.y)))
		front.append(Vector3(thickness, p.x, p.y))
		back.append(Vector3(-thickness, p.x, p.y))
	var faces: Array[PackedVector3Array] = []
	var triangles = Geometry2D.triangulate_polygon(profile)
	for i in range(0, triangles.size(), 3):
		faces.append(PackedVector3Array([front[triangles[i]], front[triangles[i + 1]], front[triangles[i + 2]]]))
		faces.append(PackedVector3Array([back[triangles[i + 2]], back[triangles[i + 1]], back[triangles[i]]]))
	for i in range(profile.size()):
		var j = (i + 1) % profile.size()
		faces.append(PackedVector3Array([front[i], back[i], back[j], front[j]]))
	B.geometry_cache[key] = B._flat_geometry(faces)
	return B.geometry_cache[key]

func set_weapon(id: String) -> void:
	if id != weapon_id:
		cancel_grimoire_cast()
	weapon_id = id if id in ["iron_blade", "dawn_blade", "grimoire"] or id in TOOLS else "fists"
	for key in _weapons:
		_weapons[key].visible = key == weapon_id
	_refresh_grimoire(_last_motion)
	if _weapon_mount:
		_weapon_mount.visible = _weapons.has(weapon_id) and held_item_id.is_empty() and not _hand_occupied()

func set_held_item(id: String) -> void:
	if id != held_item_id:
		cancel_grimoire_cast()
	held_item_id = id if Catalog.ITEMS.has(id) and not Catalog.WEAPONS.has(id) else ""
	if _held_mount == null:
		return
	if not held_item_id.is_empty() and not _held_props.has(held_item_id):
		var prop = Node3D.new()
		prop.name = held_item_id
		_held_mount.add_child(prop)
		_held_props[held_item_id] = prop
		_create_held_prop(prop, held_item_id)


		if not ItemModels.supports(held_item_id):
			prop.position.y -= _prop_floor(prop)
		for mesh in prop.find_children("*", "GeometryInstance3D", true, false):
			mesh.layers = 4
	for key in _held_props:
		_held_props[key].visible = key == held_item_id
	_held_mount.visible = not held_item_id.is_empty() and not _held_busy()
	_held_mount.position = Vector3(-0.14 if _held_two_hands() else 0.0, 0, 0.105) if _held_supporting() else Vector3(0, -0.13, 0.12)



	var roll := 0.42 if held_item_id in ["tonic", "mana_potion"] else 0.28
	_held_mount.rotation = Vector3(PI * 0.5, 0, 0) if _held_supporting() else Vector3(0, 0, PI * 0.5 - roll)
	_refresh_grimoire(_last_motion)
	if _weapon_mount:
		_weapon_mount.visible = _weapons.has(weapon_id) and held_item_id.is_empty() and not _hand_occupied()

func _held_busy() -> bool:
	return _hand_occupied() or attack_time > 0.0 or dodge_progress >= 0.0 or _last_motion == "jump" or float(_weights.jump) > 0.05

func _held_supporting() -> bool:
	return held_item_id not in ["herb", "tonic", "mana_potion", "coffee", "wood", "stick", "crystal", "shard", "marshmallow", "roasted_marshmallow", "chocolate_bar", "graham_cracker", "smore"]

func _held_two_hands() -> bool:
	return held_item_id in ["crafting_table", "camp_kit", "planks", "spring_boots", "plated_chest", "warden_plate"]

func _prop_floor(node: Node3D, relative: Transform3D = Transform3D.IDENTITY) -> float:
	var low = INF
	if node is MeshInstance3D and node.mesh != null:
		for corner in range(8): low = minf(low, (relative * node.mesh.get_aabb().get_endpoint(corner)).y)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		for instance in range(node.multimesh.instance_count):
			for corner in range(8): low = minf(low, (relative * node.multimesh.get_instance_transform(instance) * node.multimesh.mesh.get_aabb().get_endpoint(corner)).y)
	for child in node.get_children():
		if child is Node3D: low = minf(low, _prop_floor(child, relative * child.transform))
	return low



func _copy_prop_geometry(source: Node3D, parent: Node3D, relative: Transform3D = Transform3D.IDENTITY) -> void:
	if source is MeshInstance3D and source.get_meta("prepared_shadow_proxy", false):
		return
	if source is MeshInstance3D and source.mesh != null:
		B.mesh(parent, source.mesh, source.material_override).transform = relative
	elif source is MultiMeshInstance3D and source.multimesh != null:
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = source.multimesh
		batch.material_override = source.material_override
		batch.transform = relative
		parent.add_child(batch)
	for child in source.get_children():
		if child is Node3D and child.visible:
			_copy_prop_geometry(child, parent, relative * child.transform)

func _create_held_prop(n: Node3D, id: String) -> void:
	if ItemModels.supports(id):
		var resource = ItemModels.build(n, id)
		resource.scale = Vector3.ONE * (0.55 if id in ["tonic", "mana_potion"] else 0.5)
		resource.position = -(resource.basis * ItemModels.grip_anchor(id))
		return
	var timber = B.mat("#835b3e")
	var dark = B.mat("#29393d", 0.5)
	var silver = B.surface("silver", "#ccd3d6", 0.78)
	var gold = B.mat("#b89965", 0.6)
	match id:
		"coffee":
			_copy_prop_geometry(_cup, n)
			n.position.z = 0.025
		"crafting_table":
			var table = Workbench.new()
			table._ready()
			_copy_prop_geometry(table, n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.27), Vector3(0, -0.12, 0)))


			var carry = Transform3D(Basis.from_scale(Vector3(0.838, 1, 1)), Vector3(-0.0061, 0, -0.066))
			for part in n.get_children():
				if part is Node3D: part.transform = carry * part.transform
			table.free()
		"camp_kit":
			B.cyl(n, Vector3.ZERO, 0.13, 0.4, B.mat("#5d7c71")).rotation.z = PI * 0.5
			for x in [-0.13, 0.13]:
				B.ring(n, Vector3(x, 0, 0), 0.132, 0.015, B.mat("#694e40")).rotation.z = PI * 0.5
			B.cyl(n, Vector3(0, -0.09, 0.07), 0.025, 0.48, timber).rotation.z = PI * 0.5
			B.cyl(n, Vector3(0, -0.09, -0.07), 0.025, 0.48, timber).rotation.z = PI * 0.5
		"shard":
			B.facet(n, Vector3.ZERO, Vector3(0.15, 0.34, 0.15), B.mat("#f3d486", 0.2, 0.5))
		"wood", "stick":
			B.cyl(n, Vector3.ZERO, 0.07 if id == "wood" else 0.025, 0.5, B.mat("#75634d"), false, 0.055 if id == "wood" else 0.016).rotation.z = PI * 0.5
			if id == "wood":
				for x in [-0.253, 0.253]: B.cyl(n, Vector3(x, 0, 0), 0.055, 0.008, B.mat("#c49a66")).rotation.z = PI * 0.5
		"planks":
			for i in range(3):
				B.beveled_box(n, Vector3(i * 0.012, i * 0.045 - 0.045, 0), Vector3(0.42, 0.04, 0.17), timber)
		"crystal":
			B.ball(n, Vector3(0, -0.05, 0), Vector3(0.34, 0.18, 0.27), B.mat("#505d5d"))
			for i in range(3):
				B.facet(n, Vector3((i - 1) * 0.08, i * 0.025, 0), Vector3(0.085, 0.27, 0.105), B.mat("#9ee0d2", 0.4, 0.15))
		"coffee_bean":
			for i in range(3):
				var p = Vector3((i - 1) * 0.07, 0.02 if i == 1 else 0.0, 0)
				B.ball(n, p, Vector3(0.095, 0.065, 0.14), B.mat("#75492f"))
				B.branch(n, p + Vector3(0, 0.032, -0.05), p + Vector3(0.005, 0.032, 0.05), 0.006, B.mat("#33251f"))
		"marshmallow", "roasted_marshmallow":
			B.beveled_box(n, Vector3.ZERO, Vector3(0.17, 0.19, 0.17), B.mat("#f5deb0" if id == "roasted_marshmallow" else "#f2efe3"))
			if id == "roasted_marshmallow": B.ball(n, Vector3(0, 0.02, 0.085), Vector3(0.08, 0.11, 0.008), B.mat("#ae733f"))
		"relic":
			B.ring(n, Vector3.ZERO, 0.14, 0.03, gold).rotation.x = PI * 0.5
			for i in range(6):
				var a = i * TAU / 6
				B.beveled_box(n, Vector3(cos(a) * 0.15, sin(a) * 0.15, 0), Vector3(0.06, 0.065, 0.05), gold).rotation.z = a
			B.facet(n, Vector3.ZERO, Vector3(0.09, 0.13, 0.06), B.mat("#9ee0d2", 0.2, 0.3))
		"spring_boots":
			for i in range(2): _copy_prop_geometry(feet[i], n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.65), Vector3((i - 0.5) * 0.2, 0, 0)))
		"plated_chest":
			var base = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.45), Vector3(0, -0.16, 0))
			for child in torso.get_children():
				if child is MeshInstance3D and child != cape and child.position.y > 0.05 and child.position.y < 0.7:
					_copy_prop_geometry(child, n, base * child.transform)
		"warden_plate":
			B.beveled_box(n, Vector3.ZERO, Vector3(0.34, 0.33, 0.11), B.mat("#667b7f", 0.7))
			for x in [-0.16, 0.16]: B.beveled_box(n, Vector3(x, 0, 0), Vector3(0.025, 0.34, 0.13), gold)
			B.ball(n, Vector3(0, 0.04, 0.06), Vector3(0.085, 0.085, 0.025), B.mat("#86e3ec", 0.2, 0.5))
		"grapple_spool", "stamina_coil":
			B.cyl(n, Vector3.ZERO, 0.08, 0.24, dark)
			for y in [-0.14, 0.14]: B.cyl(n, Vector3(0, y, 0), 0.13, 0.035, silver)
			for y in [-0.09, -0.045, 0.0, 0.045, 0.09]: B.ring(n, Vector3(0, y, 0), 0.09, 0.012, gold if id == "grapple_spool" else B.mat("#86e3ec", 0.2, 0.3))
		"ancient_core":
			B.facet(n, Vector3.ZERO, Vector3(0.2, 0.3, 0.2), B.mat("#9ee0d2", 0.3, 0.35))
			for y in [-0.09, 0.09]: B.ring(n, Vector3(0, y, 0), 0.105, 0.015, gold)
			for x in [-0.07, 0.07]: B.box(n, Vector3(x, 0, 0.09), Vector3(0.012, 0.1, 0.015), gold)

func _hand_occupied() -> bool:
	return supply_pour.active() or carry_pose or is_throwing() or is_grimoire_casting() or bag_progress > 0.01 or bag_target > 0.01 or grapple.active() or aim_weight > 0.01 or charge_weight > 0.01 or maxf(_weights.beam, _weights.hook) > 0.05 or maxf(_weights.climb, maxf(_weights.mantle, _weights.swim)) > 0.05 or _last_motion in ["climb", "mantle", "swim"] or not rest_pose.is_empty()

func begin_supply_pour(id: String) -> bool:
	if id not in ["tonic", "mana_potion", "coffee"] or carry_pose or is_throwing() or attack_time > 0.0: return false
	cancel_grimoire_cast()
	return supply_pour.begin(id)

func set_motion_context(velocity: Vector3, grounded: bool, floor_normal: Vector3 = Vector3.UP) -> void:
	if not _has_context or global_position.distance_to(_last_context_position) > 2.5:
		_rebase_feet()
	_last_context_position = global_position
	_has_context = true
	_velocity = velocity if velocity.is_finite() else Vector3.ZERO
	_grounded = grounded
	_floor_normal = floor_normal.normalized() if floor_normal.is_finite() and floor_normal.length_squared() > 0.01 else Vector3.UP
	if not grounded:
		_footsteps = 0

func set_climb_context(normal: Vector3, velocity: Vector3, query: Callable) -> void:
	var usable = query.is_valid() and normal.is_finite() and normal.length_squared() > 0.1
	_climb_normal = normal.normalized() if usable else Vector3.ZERO
	_climb_velocity = velocity if usable and velocity.is_finite() else Vector3.ZERO
	_climb_query = query if usable else Callable()

func _leg_bend_direction(direction: Vector3, pole: Vector3) -> Vector3:
	var bend = pole.slide(direction)
	if bend.length_squared() < 0.0001:
		bend = Vector3.UP.slide(direction)
	if bend.length_squared() < 0.0001:
		bend = Vector3.RIGHT.slide(direction)
	return bend.normalized()


func _rebase_feet() -> void:

	_speed = 0.0
	_run = 0.0
	_locomotion = 0.0
	_was_walking = false
	_settle_left = 0.0
	_footsteps = 0
	phase = 0.0
	for i in range(2):
		var local = Vector3(-0.19 if i == 0 else 0.19, 0.085, 0)
		_foot_positions[i] = local
		_foot_world_positions[i] = to_global(local)
		_foot_anchors[i] = to_global(local - Vector3.UP * 0.085)
		_swing_origins[i] = _foot_world_positions[i]
		_swing_targets[i] = _foot_world_positions[i]
		_foot_planted[i] = true
		_foot_pitch[i] = 0.0
		_plant_lift[i] = 0.0

func trigger_action(kind: String, strength: float = 1.0, variant: int = 0) -> void:
	if kind in ["attack", "throw", "jump", "hurt", "beam", "hook"]: supply_pour.cancel()
	strength = clampf(strength, 0.0, 1.5)
	if kind in ["attack", "throw", "jump", "hurt", "beam", "hook"]:
		cancel_grimoire_cast()
	match kind:
		"attack":
			_capture_strike_start()
			_strike_variant = posmod(variant, 3)
			if weapon_id not in TOOLS and weapon_id not in ["iron_blade", "dawn_blade"]:
				_punch_arm = _next_punch_arm
				_next_punch_arm = 1 - _punch_arm
			_strike_strength = strength
			_strike_duration = strike_duration(weapon_id, _strike_variant)
			attack_time = _strike_duration
			_last_attack_time = attack_time
		"throw":
			_throw_left = THROW_DURATION
			_throw_release_pending = false
			_throw_released = false
			attack_time = 0.0
			_last_attack_time = 0.0
		"jump", "land", "hurt", "beam", "hook":
			_event_left[kind] = {"jump": 0.24, "land": 0.44, "hurt": 0.36, "beam": 0.32, "hook": 0.36}[kind]
			_event_strength[kind] = strength
	_refresh_grimoire(_last_motion)

func is_throwing() -> bool:
	return _throw_left > 0.0

func consume_throw_release() -> bool:
	var ready = _throw_release_pending
	_throw_release_pending = false
	return ready

func cancel_throw() -> void:
	_throw_left = 0.0
	_throw_release_pending = false
	_throw_released = false

func cancel_hand_ability_pose() -> void:
	aim_weight = 0.0
	charge_weight = 0.0
	for kind in ["beam", "hook"]:
		_event_left[kind] = 0.0
		_weights[kind] = 0.0

func consume_footstep() -> bool:
	if _footsteps <= 0:
		return false
	_footsteps -= 1
	return true

func _capture_strike_start() -> void:
	if rig == null or hands.size() < 2:
		return
	for i in range(2):
		_strike_origins[i] = rig.to_local(hands[i].global_position) - Vector3.UP * TORSO_PIVOT
		_punch_start_upper[i] = arms[i].quaternion
		_punch_start_lower[i] = forearms[i].quaternion
	_strike_start_tool = rig.global_basis.orthonormalized().inverse() * _weapon_mount.global_basis.orthonormalized()
	_sword_last_orientation = _strike_start_tool
	_sword_last_wrist = wrists[1].quaternion
	_sword_free_start_upper = arms[0].quaternion
	_sword_free_start_lower = forearms[0].quaternion
	_sword_free_start_wrist = wrists[0].quaternion

func animate(dt: float, motion: String, speed: float) -> void:
	if rig == null or dt <= 0.0 or is_nan(dt) or is_inf(dt):
		return



	if _throw_release_pending:
		return

	if attack_time > _last_attack_time + 0.001:
		_capture_strike_start()
		_strike_duration = maxf(0.3, attack_time)
		_strike_variant = 0
		_strike_strength = 1.0
	_last_attack_time = attack_time


	_accumulator += dt
	while _accumulator + 1.0e-06 >= STEP:
		_accumulator -= STEP
		_advance_pose(STEP, motion, maxf(0.0, speed))
		if _throw_release_pending:
			_accumulator = 0.0
			break
	_last_attack_time = attack_time
	_update_secondary(dt)

func _advance_pose(dt: float, motion: String, speed: float) -> void:
	time += dt
	_fall_age = _fall_age + dt if motion == "jump" and not _grounded and _velocity.y < -0.45 else 0.0
	if motion in ["climb", "mantle", "swim"] or dodge_progress >= 0.0 or carry_pose or is_throwing() or grapple.active() or aim_weight > 0.01: supply_pour.cancel()
	supply_pour.tick(dt)
	if is_grimoire_casting():
		if _grimoire_blocked(motion):
			cancel_grimoire_cast()
		else:
			_grimoire_left = maxf(0.0, _grimoire_left - dt)
			if not is_grimoire_casting():
				cancel_grimoire_cast()
	if motion != _last_motion:
		_motion_age = 0.0
		_last_motion = motion
	else:
		_motion_age += dt
	bag_progress = move_toward(bag_progress, clampf(bag_target, 0.0, 1.0), dt * 0.8)
	attack_time = maxf(0.0, attack_time - dt)
	_throw_left = maxf(0.0, _throw_left - dt)
	for event in _event_left:
		_event_left[event] = maxf(0.0, float(_event_left[event]) - dt)
	var ease = 1.0 - exp(-dt * 14.0)
	var resting = rest_pose in ["sit", "coffee", "marshmallow", "sleep"] and motion == "idle" and not carry_pose and not is_throwing() and bag_progress < 0.04
	_rest_weight = lerpf(_rest_weight, 1.0 if resting else 0.0, 1.0 - exp(-dt * 7.0))
	_weapon_mount.visible = _weapons.has(weapon_id) and held_item_id.is_empty() and not _hand_occupied()
	_held_mount.visible = not held_item_id.is_empty() and not _held_busy()
	_cup.visible = resting and rest_pose == "coffee" and not supply_pour.active()
	_roasting_stick.visible = resting and rest_pose == "marshmallow"
	_refresh_grimoire(motion)
	if supply_pour.active(): _grimoire.hide()
	_grimoire_pose_weight = move_toward(_grimoire_pose_weight, 1.0 if _grimoire.visible else 0.0, dt * 6.0)
	var equipped = _weapon_mount.visible
	var charge = charge_weight * maxf(aim_weight, float(_weights.beam))
	var grounded = _grounded if _has_context else motion not in ["jump", "climb", "mantle", "swim", "hook"]
	var walking = motion in ["walk", "run"] and grounded and bag_progress < 0.04
	if walking and not _was_walking and _speed < 0.4:


		phase = TAU * 0.24
		for i in range(2):
			_foot_anchors[i] = to_global(_foot_positions[i] - Vector3.UP * 0.085)
			_swing_origins[i] = _foot_world_positions[i]
	elif not walking and _was_walking:
		_settle_left = 0.34
		for i in range(2):
			_settle_origins[i] = _foot_world_positions[i]
	_was_walking = walking
	_settle_left = maxf(0.0, _settle_left - dt)
	_speed = lerpf(_speed, speed if walking else 0.0, 1.0 - exp(-dt * 8.0))
	_run = lerpf(_run, 1.0 if motion == "run" else 0.0, 1.0 - exp(-dt * 7.0))
	_locomotion = lerpf(_locomotion, clampf(_speed / 1.4, 0.0, 1.0) if walking else 0.0, ease)
	for mode in _weights:
		var target = 1.0 if motion == mode else 0.0
		if mode in ["beam", "hook"] and float(_event_left[mode]) > 0.0:
			target = 1.0
		_weights[mode] = lerpf(float(_weights[mode]), target, ease)


	var stride = 0.5 * lerpf(0.25, 1.0, _locomotion)
	var model_scale = maxf(0.1, global_basis.get_scale().z)
	var stance = lerpf(WALK_STANCE, RUN_STANCE, _run)
	phase = fposmod(phase + dt * _speed * TAU * stance / (2.0 * maxf(stride, 0.28) * model_scale), TAU)
	var climb: float = _weights.climb
	var mantle: float = _weights.mantle
	var swim: float = _weights.swim
	var swim_speed = clampf((_velocity.length() if _has_context else speed) / 2.8, 0.0, 1.0)
	_swim_phase += dt * lerpf(1.45, 5.2, swim_speed)
	var jump: float = _weights.jump
	var beam: float = _weights.beam
	var hook: float = _weights.hook
	var land = _landing_weight()
	var takeoff_age = 0.24 - float(_event_left.jump)
	var takeoff = sin(takeoff_age * PI / 0.24) * float(_event_strength.jump) if _event_left.jump > 0.0 else 0.0
	var mantle_phase = mantle_progress if mantle_progress >= 0 else clampf(_motion_age / 0.56, 0.0, 1.0) if motion == "mantle" else 1.0
	var hurt_age = 0.36 - float(_event_left.hurt)
	var hurt = smoothstep(0.0, 0.045, hurt_age) * (1.0 - smoothstep(0.1, 0.36, hurt_age)) * clampf(sqrt(maxf(0.0, float(_event_strength.hurt))), 0.65, 1.35) if _event_left.hurt > 0.0 else 0.0
	var breathing = sin(time * 1.7) * 0.007
	var throw_age = THROW_DURATION - _throw_left
	var gathering = smoothstep(0.0, 0.12, throw_age) * (1.0 - smoothstep(0.14, 0.34, throw_age)) if is_throwing() else 0.0
	var overhead = smoothstep(0.28, 0.46, throw_age) * (1.0 - smoothstep(0.5, THROW_CONTACT, throw_age)) if is_throwing() else 0.0
	var driving = smoothstep(0.5, 0.78, throw_age) * (1.0 - smoothstep(0.86, THROW_DURATION, throw_age)) if is_throwing() else 0.0
	var support = _overhead_support()
	var shoulder_lift = 0.23 * smoothstep(0.12, 0.32, throw_age) * (1.0 - smoothstep(THROW_CONTACT, 0.9, throw_age)) if is_throwing() else 0.0
	var strike_p = 1.0 - attack_time / _strike_duration
	var striking = attack_time > 0.0 and bag_progress < 0.05
	var tool_striking = striking and equipped and (weapon_id in TOOLS or weapon_id == "stone_hammer")
	var sword_striking = striking and equipped and weapon_id in ["iron_blade", "dawn_blade"]
	var strike_age = _strike_duration - attack_time
	var working_weight = _tool_envelope(strike_age) if tool_striking or sword_striking else 0.0


	var body_ease = 1.0 if striking else ease


	var walk_y = -0.16 - cos(phase * 2.0) * 0.07
	var step_phase = fposmod(phase / PI, 1.0)
	var run_y: float
	if step_phase < 0.2:
		run_y = lerpf(-0.17, -0.195, smoothstep(0.0, 0.2, step_phase))
	elif step_phase < 0.56:
		run_y = lerpf(-0.195, -0.175, smoothstep(0.2, 0.56, step_phase))
	elif step_phase < 0.8:
		run_y = lerpf(-0.175, -0.13, smoothstep(0.56, 0.8, step_phase))
	else:
		run_y = lerpf(-0.13, -0.17, smoothstep(0.8, 1.0, step_phase))
	var body_y = breathing + lerpf(-0.045, lerpf(walk_y, run_y, _run), _locomotion) - land * 0.14 - gathering * 0.1 - driving * 0.025
	var cradle_load = (1.0 - smoothstep(0.0, 0.2, throw_age)) if is_throwing() else 1.0 if carry_pose else 0.0
	var load_size = smoothstep(0.22, 0.74, maxf(carry_half_height, carry_half_depth))
	body_y -= cradle_load * lerpf(0.012, 0.035, load_size)
	if tool_striking:
		body_y += _tool_curve(strike_age, 0.025, -0.095, -0.11) * working_weight
	elif sword_striking:
		body_y += _tool_curve(strike_age, 0.015, -0.065, -0.08) * working_weight
	elif striking:
		body_y += _strike_curve(strike_p, -0.035, -0.065, -0.045, _strike_duration) * _strike_envelope(strike_p)
	body_y = lerpf(body_y, -0.57, _rest_weight)
	var low_step = mantle_height < 0.65
	rig.position.y = lerpf(rig.position.y, body_y + swim * 0.65 + mantle * (-0.08 if low_step else 0.1), body_ease)


	rig.position.z = _tool_curve(strike_age, 0.025, -0.045, -0.065) * working_weight if tool_striking or sword_striking else 0.0
	if striking and not tool_striking and not sword_striking:
		rig.position.z = _strike_curve(strike_p, 0.025, -0.07, -0.085, _strike_duration) * _strike_envelope(strike_p)
	rig.rotation.x = lerp_angle(rig.rotation.x, -swim * lerpf(0.18, 1.12, swim_speed) + hook * 0.13, ease)
	rig.rotation.z = lerp_angle(rig.rotation.z, sin(phase) * lerpf(0.018, 0.009, _run) * _locomotion + swim * sin(time * 3.4) * 0.06, ease)
	var mantle_lean = 0.12 if low_step else lerpf(0.32, 0.08, smoothstep(0.55, 1.0, mantle_phase))
	var torso_x = -takeoff * 0.06 - _locomotion * lerpf(0.035, 0.13, _run) - climb * 0.12 - mantle * mantle_lean - land * 0.12 - hook * 0.18 + hurt * 0.33
	var torso_y = cos(phase) * 0.055 * _locomotion + swim * sin(time * 3.4) * 0.12 - hurt * 0.16
	var torso_z = sin(phase) * 0.015 * _locomotion - hurt * 0.12


	torso_x += cradle_load * lerpf(0.025, 0.075, load_size)
	torso_y *= 1.0 - cradle_load * 0.62
	var bag_release = smoothstep(0.15, 0.38, bag_progress) * (1.0 - smoothstep(0.54, 0.8, bag_progress))
	torso_y -= bag_release * 0.14
	torso_z += bag_release * 0.065
	torso_x -= sin(bag_progress * PI) * 0.025
	torso_x += charge * 0.06
	torso_y -= charge * 0.025
	torso_x = lerpf(torso_x, 0.24 if rest_pose == "sleep" else 0.08, _rest_weight)
	torso_x += -gathering * 0.12 + overhead * 0.19 - driving * 0.42
	torso_y += -overhead * 0.06 + driving * 0.08
	torso_z -= gathering * 0.025
	if tool_striking:
		var mining = weapon_id in ["stone_pickaxe", "stone_hammer"]
		torso_y += _tool_curve(strike_age, -0.1 if mining else -0.5, 0.1 if mining else 0.33, 0.15 if mining else 0.52) * working_weight
		torso_x += _tool_curve(strike_age, 0.16 if mining else 0.07, -0.28 if mining else -0.08, -0.34 if mining else -0.1) * working_weight
		torso_z += _tool_curve(strike_age, -0.035, 0.035, 0.055) * working_weight
	elif sword_striking:
		var cut_twist = [0.4, -0.4, -0.48][_strike_variant]
		torso_y += _tool_curve(strike_age, cut_twist, -cut_twist * 0.72, -cut_twist * 1.18) * working_weight
		torso_x += _tool_curve(strike_age, 0.035, -0.09, -0.12) * working_weight
	elif striking:
		var strike_side = -1.0 if _punch_arm == 0 else 1.0
		var twist = _strike_curve(strike_p, -0.3 if _strike_variant == 2 else -0.2, 0.4 if _strike_variant == 2 else 0.27, 0.46 if _strike_variant == 2 else 0.31, _strike_duration) * _strike_envelope(strike_p)
		torso_y += strike_side * twist * _strike_strength
		torso_x -= _strike_envelope(strike_p) * 0.055
		torso_z -= strike_side * _strike_envelope(strike_p) * (0.09 if _strike_variant == 2 else 0.035)

	var hip_turn = _strike_curve(strike_p, -0.08, 0.12, 0.15, _strike_duration) * _strike_envelope(strike_p) * (-1.0 if _punch_arm == 0 else 1.0) if striking and not tool_striking and not sword_striking else 0.0
	if tool_striking:
		hip_turn = _tool_curve(strike_age, -0.13, 0.15, 0.23) * working_weight * (0.3 if weapon_id in ["stone_pickaxe", "stone_hammer"] else 1.0)
	elif sword_striking:
		var turn_side = -1.0 if _strike_variant == 0 else 1.0
		hip_turn = _tool_curve(strike_age, -0.15, 0.14, 0.23) * working_weight * turn_side
	rig.rotation.y = lerp_angle(rig.rotation.y, hip_turn, body_ease)
	var weight_shift = _tool_curve(strike_age, 0.025, -0.035, -0.055) * working_weight if tool_striking or sword_striking else _strike_envelope(strike_p) * (-0.055 if _punch_arm == 0 else 0.055) if striking else 0.0
	if walking and not striking and not carry_pose:
		weight_shift -= cos(phase) * 0.035 * _run * _locomotion


	rig.position.x = lerpf(rig.position.x, weight_shift, body_ease)
	torso.rotation.x = lerp_angle(torso.rotation.x, torso_x, body_ease)
	torso.rotation.y = lerp_angle(torso.rotation.y, torso_y, body_ease)
	torso.rotation.z = lerp_angle(torso.rotation.z, torso_z, body_ease)
	head.rotation = head.rotation.lerp(Vector3(-torso.rotation.x * 0.45 + sin(time * 2.1) * 0.012 + land * 0.08 - hurt * 0.13, -torso.rotation.y * 0.65 + sin(time * 0.7) * 0.035, -rig.rotation.z * 0.5 + hurt * 0.14), ease)
	var local_velocity = global_basis.orthonormalized().inverse() * _velocity if _has_context else Vector3(0, 0, -speed)
	var direction = Vector3(local_velocity.x, 0.0, local_velocity.z).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	var floor_normal = global_basis.orthonormalized().inverse() * _floor_normal
	var rise = smoothstep(-3.0, 4.0, _velocity.y) if _has_context else 0.65
	var apex = 1.0 - smoothstep(0.5, 4.0, absf(_velocity.y)) if _has_context else 0.35
	if bag_progress < 0.01:
		for i in range(2):
			_bag_hand_origins[i] = torso.global_transform.affine_inverse() * hands[i].global_transform
			_bag_elbow_origins[i] = torso.to_local(forearms[i].global_position) - arms[i].position
	_update_bag(land)
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		arms[i].position.y = 1.73 - TORSO_PIVOT + shoulder_lift - cradle_load * 0.018 - (bag_release * 0.055 if i == 1 else 0.0)
		var wave = cos(phase + i * PI)
		var arm_x = 0.035 - wave * lerpf(0.34, 0.55, _run) * _locomotion
		var arm_y = -side * 0.025
		var arm_z = side * (0.08 + _run * _locomotion * 0.025)
		var elbow_x = 0.1 + _locomotion * (0.04 + _run * 1.1 + maxf(0.0, -wave) * lerpf(0.12, 0.07, _run))
		arm_x = lerpf(arm_x, lerpf(0.3, 0.94, rise) + takeoff * 0.16, jump)
		arm_z = lerpf(arm_z, side * (lerpf(0.22, 0.12, rise) + apex * 0.15), jump)
		elbow_x = lerpf(elbow_x, lerpf(0.28, 0.62, rise), jump)

		var pull = smoothstep(0.0, 0.78, mantle_phase)
		arm_x = lerpf(arm_x, lerpf(2.36, 1.32, pull), mantle)
		arm_z = lerpf(arm_z, side * 0.25, mantle)
		elbow_x = lerpf(elbow_x, lerpf(0.18, 1.28, pull), mantle)
		if low_step:

			arm_x = lerpf(arm_x, 0.35 + sin(mantle_phase * PI) * (0.18 if i == 1 else -0.12), mantle)
			elbow_x = lerpf(elbow_x, 0.36, mantle)
			arm_z = lerpf(arm_z, side * 0.24, mantle)
		var stroke = _swim_phase + i * PI
		arm_x = lerpf(arm_x, lerpf(0.55, 1.65, swim_speed) + sin(stroke) * lerpf(0.28, 1.35, swim_speed), swim)
		arm_z = lerpf(arm_z, side * (lerpf(0.65, 0.3, swim_speed) + maxf(0.0, cos(stroke)) * 0.32), swim)
		elbow_x = lerpf(elbow_x, 0.2 + maxf(0.0, -sin(stroke)) * lerpf(0.35, 0.85, swim_speed), swim)
		if equipped and i == 1:
			arm_x += 0.13
			elbow_x += 0.22
		if not striking and not carry_pose and not is_throwing() and maxf(climb, maxf(mantle, swim)) < 0.1 and aim_weight < 0.01 and charge_weight < 0.01:
			arm_x = lerpf(arm_x, 0.85 if i == 0 else 0.54, hurt)
			elbow_x = lerpf(elbow_x, 1.3 if i == 0 else 1.1, hurt)
			arm_z = lerpf(arm_z, side * 0.24, hurt)
		arm_x = lerpf(arm_x, 0.8 if rest_pose == "marshmallow" and i == 1 else 0.35, _rest_weight)
		elbow_x = lerpf(elbow_x, 0.95 if i == 1 else 0.55, _rest_weight)
		arm_z = lerpf(arm_z, side * 0.18, _rest_weight)
		if carry_pose:
			arm_x = 0.92 + sin(phase * 2.0) * _locomotion * 0.035
			elbow_x = 0.76
			arm_z = -side * 0.17
			arm_y = -side * 0.16


		var brace = maxf(maxf(beam, hook), maxf(aim_weight, charge_weight)) if i == 1 else 0.0
		arm_x = lerpf(arm_x, 1.58, brace)
		elbow_x = lerpf(elbow_x, 0.04, brace)
		arm_z = lerpf(arm_z, -0.055, brace)
		arm_y = lerpf(arm_y, 0.08, brace)
		if tool_striking:
			if i == 0:
				arm_x = lerpf(arm_x, 0.65, _tool_envelope(strike_age))
				elbow_x = lerpf(elbow_x, 1.3, _tool_envelope(strike_age))
		elif sword_striking:
			if i == 0:
				arm_x = lerpf(arm_x, 0.22, _tool_envelope(strike_age))
				elbow_x = lerpf(elbow_x, 0.42, _tool_envelope(strike_age))
		arm_x -= land * 0.12
		var arm_ease = 1.0 - exp(-dt * (46.0 if striking else 14.0))
		arms[i].rotation = Vector3(lerp_angle(arms[i].rotation.x, arm_x, arm_ease), lerp_angle(arms[i].rotation.y, arm_y, arm_ease), lerp_angle(arms[i].rotation.z, arm_z, arm_ease))
		forearms[i].rotation = Vector3(lerp_angle(forearms[i].rotation.x, elbow_x, arm_ease), lerp_angle(forearms[i].rotation.y, 0.0, arm_ease), lerp_angle(forearms[i].rotation.z, 0.0, arm_ease))


		var wrist = Vector3(0.0, -side * PI * 0.5, 0.0)
		var contact_palm = maxf(climb, 0.0 if low_step else mantle)
		wrist = wrist.lerp(Vector3(PI - arm_x - elbow_x, 0, 0), maxf(brace, contact_palm))
		wrists[i].rotation = Vector3(lerp_angle(wrists[i].rotation.x, wrist.x, ease), lerp_angle(wrists[i].rotation.y, wrist.y, ease), 0)
		var foot_target = _ground_foot(i, direction, stride, grounded and walking, floor_normal)
		var air_foot = Vector3(side * 0.19, 0.11 + rise * 0.1 + apex * (0.26 if i == 0 else 0.21), lerpf(-0.1, -0.24 if i == 0 else 0.15, rise) - apex * (0.14 if i == 0 else -0.08))
		foot_target = foot_target.lerp(rig.transform * air_foot, jump)
		var mantle_foot = rig.transform * Vector3(side * 0.23, 0.5 if i == 0 else 0.2, -0.37 if i == 0 else 0.12)
		if low_step:
			var lift = sin(clampf(mantle_phase / 0.65, 0, 1) * PI) if i == 0 else sin(clampf((mantle_phase - 0.35) / 0.65, 0, 1) * PI)
			var forward_step = smoothstep(0.2, 0.42, mantle_phase) * (1.0 - smoothstep(0.65, 1.0, mantle_phase))
			mantle_foot = Vector3(side * 0.2, 0.085 + maxf(0, lift) * (0.55 if i == 0 else 0.24), -0.42 * forward_step if i == 0 else 0.1 * (1.0 - smoothstep(0.6, 1.0, mantle_phase)))
		foot_target = foot_target.lerp(mantle_foot, mantle)
		foot_target = foot_target.lerp(rig.transform * Vector3(side * 0.18, 0.13 + sin(_swim_phase * 2.0 + i * PI) * lerpf(0.025, 0.09, swim_speed), sin(_swim_phase * 2.0 + i * PI) * lerpf(0.06, 0.27, swim_speed)), swim)
		foot_target = foot_target.lerp(rig.transform * Vector3(side * 0.21, 0.22 if i == 0 else 0.11, -0.25 if i == 0 else 0.14), hook)
		foot_target = foot_target.lerp(Vector3(side * 0.22, 0.085, -0.66), _rest_weight)
		_solve_leg(i, foot_target, floor_normal, 1.0 - maxf(jump, maxf(climb, maxf(mantle, maxf(swim, hook)))))
		_foot_world_positions[i] = feet[i].global_position
		var proximal = 0.13
		var distal = 0.2
		var fold = 0.08
		var spread = 0.0
		if i == 1 and (equipped or _cup.visible or _roasting_stick.visible):
			proximal = 0.95
			distal = 1.5
			fold = 0.8
			if equipped and weapon_id in TOOLS:
				proximal = 0.95
				distal = 1.5
		if i == 1 and _held_mount.visible:
			proximal = 0.42 if _held_supporting() else 0.95
			distal = 0.55 if _held_supporting() else 1.5
			fold = 0.3 if _held_supporting() else 0.8
		if carry_pose or bag_progress > 0.08:
			proximal = 0.78
			distal = 1.0
			fold = 0.6
		if is_throwing():
			var opening = smoothstep(THROW_CONTACT - 0.025, THROW_CONTACT + 0.055, throw_age)
			proximal = lerpf(0.82, 0.04, opening)
			distal = lerpf(1.1, 0.08, opening)
			fold = lerpf(0.6, 0.0, opening)
		if i == 1 and brace > 0.05:
			proximal = 0.035 if aim_kind == "beam" else 0.22
			distal = 0.06 if aim_kind == "beam" else 0.3
			fold = 0.0
			spread = 1.0
		if i == 1 and grapple.active():
			proximal = 0.38 if grapple.state == "latched" else 0.12
			distal = 0.72 if grapple.state == "latched" else 0.2
			fold = 0.4 if grapple.state == "latched" else 0.0
			spread = 0.55
		if tool_striking and i == 0:
			proximal = lerpf(proximal, 0.95, working_weight)
			distal = lerpf(distal, 1.5, working_weight)
			fold = lerpf(fold, 0.8, working_weight)
		elif striking and not (equipped and i == 1):
			proximal = 1.35
			distal = 1.75
			fold = 1.0
			spread = 0.0
		if not is_grimoire_casting():
			hands[i].set_pose(dt, proximal, distal, fold, spread, 60.0 if striking else 36.0)
		if i == 1 and equipped and weapon_id in TOOLS and not striking:


			_orient_palm(i, torso.basis.orthonormalized().inverse() * _tool_ready_orientation() * _weapon_mount.basis.inverse(), 1.0)
		if i == 1 and aim_weight > 0.001 and not striking and not carry_pose and bag_progress < 0.04:
			var aim_direction = (torso.to_local(aim_target) - arms[i].position).normalized()
			_solve_arm(i, _aim_arm_target(aim_direction), aim_weight)
			var palm_direction = (aim_target - hands[i].global_position).normalized()
			var facing = Grapple.facing(palm_direction)
			if is_instance_valid(aim_camera):


				var palm_right = (-aim_camera.global_basis.y).cross(palm_direction).normalized()
				if palm_right.length_squared() > 0.1:
					facing = Basis(palm_right, palm_direction.cross(palm_right).normalized(), palm_direction)
			_orient_palm(i, torso.global_basis.orthonormalized().inverse() * facing, aim_weight)
		if tool_striking and i == 1:


			var target = _strike_origins[1].lerp(_tool_hand_target(strike_age), working_weight)
			_solve_tool_arm(i, torso.transform.affine_inverse() * (target + Vector3.UP * TORSO_PIVOT), working_weight)
			var tool_basis = _strike_start_tool.slerp(_tool_orientation(strike_age), working_weight)
			_orient_palm(i, torso.basis.orthonormalized().inverse() * tool_basis * _weapon_mount.basis.inverse(), 1.0)
		elif sword_striking and i == 1:



			var left_gather = _strike_variant == 0 and _work_phase(strike_age).x < 0.5
			var target = _sword_hand_target(strike_age) if left_gather else _strike_origins[1].lerp(_sword_hand_target(strike_age), working_weight)
			_solve_sword_arm(i, torso.transform.affine_inverse() * (target + Vector3.UP * TORSO_PIVOT), working_weight)
			var tool_basis = _strike_start_tool.slerp(_sword_orientation(strike_age), working_weight)



			var previous := _sword_last_orientation.get_rotation_quaternion()
			var desired := tool_basis.get_rotation_quaternion()
			var turn := previous.angle_to(desired)
			tool_basis = Basis(previous.slerp(desired, minf(1.0, dt * 34.0 / maxf(0.001, turn))))
			_sword_last_orientation = tool_basis
			_orient_palm(i, torso.basis.orthonormalized().inverse() * tool_basis * _weapon_mount.basis.inverse(), 1.0)



			var wrist_turn = _sword_last_wrist.angle_to(wrists[i].quaternion)
			wrists[i].quaternion = _sword_last_wrist.slerp(wrists[i].quaternion, minf(1.0, dt * 46.0 / maxf(0.001, wrist_turn)))
			_sword_last_orientation = rig.global_basis.orthonormalized().inverse() * _weapon_mount.global_basis.orthonormalized()
			_sword_last_wrist = wrists[i].quaternion
		elif sword_striking:



			arms[0].quaternion = _sword_free_start_upper.slerp(_sword_free_upper, working_weight)
			forearms[0].quaternion = _sword_free_start_lower.slerp(_sword_free_lower, working_weight)
			wrists[0].quaternion = _sword_free_start_wrist.slerp(Quaternion.IDENTITY, working_weight)
		elif striking and not tool_striking:


			if i == _punch_arm:
				var target = _punch_hand_target(i, strike_age)
				target = _extended_impact_target(i, torso.transform.affine_inverse() * (target + Vector3.UP * TORSO_PIVOT), _punch_phase(strike_age))
				_solve_arm(i, target, 1.0, _punch_guard_upper(i) * Vector3.DOWN, 1.0, 0.87)
			else:
				var guard_weight = _strike_envelope(strike_p)
				arms[i].quaternion = _punch_start_upper[i].slerp(_punch_guard_upper(i), guard_weight)
				forearms[i].quaternion = _punch_start_lower[i].slerp(Quaternion(Vector3.RIGHT, PI * 2.0 / 3.0), guard_weight)
			_orient_palm(i, Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), _strike_envelope(strike_p))
		if mantle_contacts.size() == 2 and mantle > 0.05 and not low_step:
			var plant = smoothstep(0.0, 0.08, mantle_phase) * (1.0 - smoothstep(0.28, 0.55, mantle_phase))
			_solve_arm(i, torso.to_local(mantle_contacts[i]), plant)
			var down = torso.global_basis.orthonormalized().inverse() * Vector3.DOWN
			_orient_palm(i, Grapple.facing(down), plant)
		if (carry_pose or is_throwing()) and bag_progress < 0.04:
			var prop = _prop_center()



			var width = _carry_hand_width()
			var target = prop + _carry_palm_offset() + Vector3(side * width, 0, 0)
			var weight = 1.0 if carry_pose else 1.0 - smoothstep(0.86, THROW_DURATION, throw_age)
			var throw_blend = smoothstep(0.0, 0.14, throw_age) if is_throwing() else 0.0
			_solve_arm(i, target - Vector3.UP * TORSO_PIVOT, weight, Vector3(side * 0.3, -0.48, 0.1).lerp(Vector3(side, 0.08, 0.14), throw_blend))
			_orient_cradling_palm(i, weight, throw_blend, support)
		if i == 1 and _cup.visible:
			_solve_arm(i, Vector3(0.3, 0.06, -0.45), _rest_weight)
			_orient_palm(i, Basis.IDENTITY, _rest_weight)
		if i == 1 and _held_mount.visible:




			var hold_weight = 1.0 if _held_supporting() else 1.0 - _run * _locomotion
			_solve_arm(i, Vector3(0.25, 0.05, -0.55) if _held_two_hands() else Vector3(0.43, -0.02, -0.55), hold_weight)
			_orient_palm(i, _held_mount.basis.inverse(), 1.0)
		if bag_progress > 0.01:
			_aim_bag_hand(i, ease)
	if _held_mount.visible and _held_two_hands():
		var palm_basis := torso.global_basis.orthonormalized() * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
		var contact := _held_mount.to_global(Vector3(-0.14, 0, 0))
		var hand_target := contact - palm_basis.z * (0.105 * hands[0].global_basis.get_scale().abs().x)
		_solve_arm(0, torso.to_local(hand_target), 1.0, Vector3(-0.35, -0.48, 0.1))
		_orient_palm(0, Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), 1.0)
		hands[0].set_pose(dt, 0.42, 0.55, 0.3, 0.0, 36.0)
	if tool_striking:
		_apply_tool_support(strike_age, working_weight)
	authored_climb.pose(self, dt, climb * (1.0 - mantle))
	if is_grimoire_casting():
		_apply_grimoire_pose(dt)
	elif _grimoire.visible:
		_apply_grimoire_rest(dt)
	supply_pour.pose(dt)
	_dodge_tuck = 0.0
	if dodge_progress >= 0.0 and not _hand_occupied() and maxf(climb, mantle) < 0.1:
		_apply_dodge_pose(dodge_progress)
	grapple.tick(dt)
	if _roasting_stick.visible and rest_target.is_finite():
		var ember_direction = (rest_target - _roasting_stick.global_position).normalized()
		if ember_direction.length_squared() > 0.1:
			var hand_scale = hands[1].global_basis.get_scale().abs()
			var stick_length = maxf(hand_scale.y * 1.65, minf(2.0, rest_target.distance_to(_roasting_stick.global_position) / 0.78))
			_roasting_stick.global_basis = Basis(Quaternion(Vector3.UP, ember_direction)).scaled_local(Vector3(hand_scale.x, stick_length, hand_scale.z))

	var palms = (hands[0].global_position + hands[1].global_position) * 0.5
	var carry_target = rig.to_local(palms) - torso.basis * _carry_palm_offset()
	if carry_pose or is_throwing():
		grip.position = carry_target
		grip.basis = torso.basis
	else:
		grip.position = grip.position.lerp(Vector3(0, 1.4, -0.82), ease)
		grip.quaternion = grip.quaternion.slerp(Quaternion.IDENTITY, ease)

	if is_throwing() and throw_age + 1.0e-06 >= THROW_CONTACT and not _throw_released:
		_throw_released = true
		_throw_release_pending = true

func _tool_envelope(age: float) -> float:
	var contact = strike_contact(weapon_id, _strike_variant)



	var recovery_start = minf(contact + 0.2, _strike_duration - 0.1) if weapon_id in ["iron_blade", "dawn_blade"] else contact + 0.28
	return smoothstep(0.0, 0.075, age) * (1.0 - smoothstep(recovery_start, _strike_duration, age))




func _work_phase(age: float) -> Vector2:
	var contact = strike_contact(weapon_id, _strike_variant)
	var sword = weapon_id in ["iron_blade", "dawn_blade"]
	var drive_start = contact * (0.44 if sword else 0.64)
	if age < drive_start:
		return Vector2(0.0, smoothstep(0.0, contact * (0.44 if sword else 0.52), age))
	if age < contact + 0.033:
		var drive = clampf((age - drive_start) / (contact - drive_start - 0.017), 0.0, 1.0)
		return Vector2(1.0, drive * drive * drive * (drive * (drive * 6.0 - 15.0) + 10.0))
	if age < contact + 0.145:
		return Vector2(2.0, smoothstep(contact + 0.033, contact + 0.145, age))
	return Vector2(3.0, smoothstep(contact + 0.145, contact + 0.28, age))

func _work_vector(age: float, start: Vector3, windup: Vector3, contact: Vector3, follow: Vector3, rebound: Vector3) -> Vector3:
	var phase_key = _work_phase(age)
	if phase_key.x < 0.5:
		return start.lerp(windup, phase_key.y)
	if phase_key.x < 1.5:
		return windup.lerp(contact, phase_key.y)
	if phase_key.x < 2.5:
		return contact.lerp(follow, phase_key.y)
	return follow.lerp(rebound, phase_key.y)

func _tool_curve(age: float, windup: float, contact: float, follow: float) -> float:
	var phase_key = _work_phase(age)
	if phase_key.x < 0.5:
		return lerpf(0.0, windup, phase_key.y)
	if phase_key.x < 1.5:
		return lerpf(windup, contact, phase_key.y)
	if phase_key.x < 2.5:
		return lerpf(contact, follow, phase_key.y)
	return lerpf(follow, follow * 0.25, phase_key.y)

func _tool_hand_target(age: float) -> Vector3:
	var mining = weapon_id in ["stone_pickaxe", "stone_hammer"]
	var start = _strike_origins[1]
	var windup = Vector3(0.4, 0.7, -0.3) if mining else Vector3(0.24, 0.38, -0.4)
	var contact = Vector3(0.1, 0.22, -0.64) if mining else Vector3(0.08, 0.34, -0.6)
	var follow = Vector3(0.12, 0.12, -0.64) if mining else Vector3(-0.04, 0.25, -0.6)
	var rebound = Vector3(0.24, 0.1, -0.52) if mining else Vector3(0.36, 0.32, -0.46)
	var target = _work_vector(age, start, windup, contact, follow, rebound)
	var phase_key = _work_phase(age)
	if mining and phase_key.x > 0.5 and phase_key.x < 1.5:


		target.x += sin(phase_key.y * PI) * 0.12
	elif mining and phase_key.x > 2.5:


		target.y -= sin(phase_key.y * PI) * 0.12
	return target

func _tool_orientation(age: float) -> Basis:
	var mining = weapon_id in ["stone_pickaxe", "stone_hammer"]
	var windup = Vector3(0.5, 0.86, 0.1) if mining else Vector3(0.96, 0.04, 0.28)
	var contact = Vector3(0.5, 0.32, -0.85) if mining else Vector3(0.2, 0.08, -0.977)
	var follow = Vector3(-0.02, 0.16, -0.987) if mining else Vector3(-0.8, 0.08, -0.59)
	var rebound = Vector3(0.8, 0.55, -0.24) if mining else Vector3(0.25, 0.75, -0.61)
	var phase_key = _work_phase(age)
	var shaft = windup.normalized() if phase_key.x < 0.5 else _work_vector(age, _strike_start_tool.y, windup, contact, follow, rebound).normalized()
	var normal = (Vector3.RIGHT if mining else Vector3.DOWN).slide(shaft).normalized()
	var edge = shaft.cross(normal).normalized()


	var authored = Basis(normal, shaft, -edge)



	return _strike_start_tool.slerp(authored, phase_key.y) if phase_key.x < 0.5 else authored

func _tool_ready_orientation() -> Basis:



	var shaft = Vector3(0.25, -0.55, -0.8).normalized()
	var edge = Vector3.DOWN.slide(shaft).normalized()
	return Basis(shaft.cross(-edge).normalized(), shaft, -edge)

func _apply_tool_support(age: float, weight: float) -> void:
	var mining = weapon_id in ["stone_pickaxe", "stone_hammer"]
	var support_distance = _work_vector(age, Vector3(0.16, 0, 0), Vector3(0.23 if mining else 0.28, 0, 0), Vector3(0.14 if mining else 0.16, 0, 0), Vector3(0.14, 0, 0), Vector3(0.16 if mining else 0.23, 0, 0)).x



	var tool_basis = torso.global_basis.orthonormalized().inverse() * _weapon_mount.global_basis.orthonormalized()
	var palm_basis = tool_basis * _weapon_mount.basis.inverse()
	if mining:



		var contact = strike_contact(weapon_id, _strike_variant)
		var support_roll = smoothstep(contact + 0.033, contact + 0.145, age) * PI
		palm_basis = Basis(tool_basis.y, support_roll) * palm_basis
	var grasp = torso.to_local(_weapon_mount.to_global(Vector3(0, support_distance, 0)))
	var wrist = grasp - palm_basis * _weapon_mount.position


	var start = torso.transform.affine_inverse() * (_strike_origins[0] + Vector3.UP * TORSO_PIVOT)
	_solve_arm(0, start.lerp(wrist, weight), 1.0)
	_orient_palm(0, palm_basis, weight)

func _sword_hand_target(age: float) -> Vector3:




	var windup: Vector3 = [Vector3(0.1, 0.82, -0.7), Vector3(0.62, 0.82, -0.32), Vector3(0.62, 0.43, -0.35)][_strike_variant]
	var contact: Vector3 = [Vector3(0.46, 0.27, -0.73), Vector3(0.14, 0.27, -0.73), Vector3(0.05, 0.43, -0.7)][_strike_variant]
	var follow: Vector3 = [Vector3(0.64, 0.12, -0.6), Vector3(-0.14, 0.12, -0.6), Vector3(-0.2, 0.43, -0.56)][_strike_variant]
	var rebound: Vector3 = [Vector3(0.38, 0.34, -0.46), Vector3(0.38, 0.34, -0.46), Vector3(0.22, 0.34, -0.48)][_strike_variant]
	return _work_vector(age, _strike_origins[1], windup, contact, follow, rebound)

func _sword_ready_orientation() -> Basis:
	var shaft := Vector3(0.2, 0.81, -0.55).normalized()



	var normal := Vector3.RIGHT.slide(shaft).normalized()
	return Basis(shaft.cross(normal).normalized(), shaft, normal)

func _sword_shaft(age: float) -> Vector3:
	var windup: Vector3 = [Vector3(-0.55, 0.82, -0.16), Vector3(0.35, 0.94, -0.1), Vector3(0.85, 0, -0.3)][_strike_variant]
	var contact: Vector3 = [Vector3(0.4, -0.34, -0.85), Vector3(-0.4, -0.34, -0.85), Vector3(-0.45, 0, -0.89)][_strike_variant]
	var follow: Vector3 = [Vector3(0.78, -0.58, 0.03), Vector3(-0.78, -0.58, 0.03), Vector3(-0.9, 0, 0.04)][_strike_variant]


	var rebound = _strike_start_tool.y
	return _work_vector(age, _strike_start_tool.y, windup, contact, follow, rebound).normalized()

func _sword_orientation(age: float) -> Basis:
	var shaft := _sword_shaft(age)
	if _strike_variant == 2:


		var normal := Vector3.UP.slide(shaft).normalized()
		return Basis(shaft.cross(normal).normalized(), shaft, normal)
	var delta := 0.004


	var contact := strike_contact(weapon_id, _strike_variant)
	var plane_age := minf(age, contact - 0.023) if age < contact + 0.033 else age
	var before := maxf(0.0, plane_age - delta)
	var after := plane_age + delta
	var side := -1.0 if _strike_variant == 0 else 1.0
	var early_turn := _tool_curve(before, -0.15, 0.14, 0.23) * side
	var late_turn := _tool_curve(after, -0.15, 0.14, 0.23) * side
	var early_tip := Basis(Vector3.UP, early_turn) * (_sword_hand_target(before) + Vector3.UP * TORSO_PIVOT + _sword_shaft(before) * 1.06)
	var late_tip := Basis(Vector3.UP, late_turn) * (_sword_hand_target(after) + Vector3.UP * TORSO_PIVOT + _sword_shaft(after) * 1.06)
	var tangent := Basis(Vector3.UP, -rig.rotation.y) * (late_tip - early_tip)
	var reference := _sword_last_orientation.z.slide(shaft).normalized()
	if reference.length_squared() < 0.1: reference = Vector3.UP.slide(shaft).normalized()
	var normal := shaft.cross(tangent).normalized()
	if normal.length_squared() < 0.1: normal = reference.slide(shaft).normalized()
	if normal.dot(reference) < 0.0: normal = -normal
	return Basis(shaft.cross(normal).normalized(), shaft, normal)

func _apply_dodge_pose(progress: float) -> void:
	var tuck = smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.78, 1.0, progress))
	_dodge_tuck = tuck



	rig.position = Vector3.ZERO
	var direction := dodge_direction.slide(Vector3.UP).normalized() if dodge_direction.is_finite() else Vector3.FORWARD
	if direction.length_squared() < 0.1: direction = Vector3.FORWARD
	var roll_axis := Vector3.UP.cross(direction)
	var turn := TAU * smoothstep(0.12, 0.82, progress)
	rig.basis = Basis(roll_axis, turn) * Basis.from_euler(Vector3(0, sin(progress * TAU) * 0.1 * tuck, -sin(progress * PI) * 0.2))
	var pivot = Vector3(0, 1.62, 0)
	rig.position = pivot - rig.basis * pivot
	torso.rotation = Vector3(-0.3 * tuck, 0, 0.06 * tuck)
	head.rotation = Vector3(0.28 * tuck, 0, 0)
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var lead: float = sin(progress * PI) * tuck
		legs[i].rotation = Vector3((1.35 + side * 0.15 * lead) * tuck, 0, side * 0.2 * tuck)
		knees[i].rotation = Vector3((-2.3 + side * 0.16 * lead) * tuck, 0, 0)
		feet[i].rotation = Vector3(0.55 * tuck, 0, 0)
		_solve_arm(i, Vector3(side * 0.45, 0.12 + (0.09 if i == 0 else -0.05) * tuck, -0.32 + side * 0.15 * tuck), tuck)
		if i == 1 and _weapon_mount.visible:
			var shaft = Vector3(0.62, 0.77, 0.12).normalized()
			var edge = Vector3.FORWARD.slide(shaft).normalized()
			_orient_palm(i, Basis(shaft.cross(-edge).normalized(), shaft, -edge) * _weapon_mount.basis.inverse(), tuck)


	var low = INF
	for mesh in _dodge_surfaces:
		if not mesh.is_visible_in_tree():
			continue
		var relative = global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = mesh.mesh.get_aabb()
		for corner in range(8):
			low = minf(low, (relative * box.get_endpoint(corner)).y)
	if is_finite(low):
		rig.position.y += 0.035 - low

func _cradle_center() -> Vector3:



	var depth = maxf(0.06, carry_half_depth)
	var height = maxf(0.06, carry_half_height)
	var rear = smoothstep(0.28, 0.58, depth)
	var center_y = clampf(1.48 - height * 0.47, 1.12, 1.43)
	var center_z = -maxf(0.48, depth + lerpf(0.24, 0.42, rear))
	return Vector3(0, center_y + sin(phase * 2.0) * _locomotion * 0.01, center_z)

func _cradle_palm_offset() -> Vector3:
	var rear = smoothstep(0.28, 0.58, carry_half_depth)
	var low_support = minf(maxf(0.06, carry_half_height) * 0.62, 0.23)
	var rear_support = minf(maxf(0.06, carry_half_height) * 0.33, 0.12)
	return Vector3(0, -lerpf(low_support, rear_support, rear), lerpf(0.015, carry_half_depth + 0.025, rear))

func _carry_hand_width() -> float:
	var rest = clampf(carry_half_width * 0.78, 0.16, 0.43)
	if not is_throwing():
		return rest
	var age = THROW_DURATION - _throw_left
	var overhead = lerpf(carry_half_width, maxf(0.56, carry_half_width), _overhead_support())
	return lerpf(rest, overhead, smoothstep(0.0, 0.14, age))

func _prop_center() -> Vector3:


	var rear_load = smoothstep(0.47, 0.7, carry_half_depth)
	var rear_extra = (carry_half_depth + 0.015) * rear_load
	var rest = Vector3(0, 1.37 + sin(phase * 2.0) * _locomotion * 0.018, -0.74)
	if not is_throwing():
		return _cradle_center()
	var age = THROW_DURATION - _throw_left
	var gather = Vector3(0, 1.58, -0.96)
	var corner = Vector3(0, 3.19, -0.95)
	var loaded = Vector3(0, 3.23, -0.2)
	var release = Vector3(0, 2.65, -1.28)
	var point: Vector3
	if age < 0.14:
		point = rest.lerp(gather, smoothstep(0.0, 0.14, age))

		point.z = lerpf(rest.z, gather.z, smoothstep(0.0, 0.09, age))
	elif age < 0.36:
		point = gather.lerp(corner, smoothstep(0.14, 0.36, age))
	elif age < 0.5:
		point = corner.lerp(loaded, smoothstep(0.36, 0.5, age))
	elif age < THROW_CONTACT:


		var t = (age - 0.5) / (THROW_CONTACT - 0.5)
		var u = t * t * (2.0 - t)
		point = loaded.bezier_interpolate(Vector3(0, 3.4, -0.6), Vector3(0, 3.35, -0.95), release, u)
	else:
		point = release.lerp(Vector3(0, 1.43, -1.1), smoothstep(THROW_CONTACT, 0.94, age))

	var rear = _overhead_rear_support()
	point += Vector3(0, (carry_half_height - 0.47) * _overhead_support(), (0.47 - carry_half_depth) * rear - rear_extra * (1.0 - rear))
	return _cradle_center().lerp(point, smoothstep(0.0, 0.14, age))

func _overhead_support() -> float:
	if not is_throwing():
		return 0.0
	var age = THROW_DURATION - _throw_left
	return smoothstep(0.0, 0.34, age) * (1.0 - smoothstep(THROW_CONTACT, 0.94, age))

func _carry_palm_offset() -> Vector3:
	if not is_throwing():
		return _cradle_palm_offset()
	var support = _overhead_support()
	var rear = maxf(_overhead_rear_support(), smoothstep(0.47, 0.7, carry_half_depth))
	var overhead = Vector3(0, -lerpf(0.055, carry_half_height + 0.055, support), lerpf(0.02, carry_half_depth + 0.035, rear))
	return _cradle_palm_offset().lerp(overhead, smoothstep(0.0, 0.14, THROW_DURATION - _throw_left))

func _overhead_rear_support() -> float:
	if not is_throwing():
		return 0.0
	var age = THROW_DURATION - _throw_left
	return smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(THROW_CONTACT, 0.94, age))

func _aim_arm_target(direction: Vector3) -> Vector3:
	var ordinary = arms[1].position + direction * 0.83
	if not is_instance_valid(aim_camera) or grapple.active():
		return ordinary



	var ray_direction = (aim_camera.global_basis * Vector3(0.55, -0.3, -1.0)).normalized()
	var relative = aim_camera.global_position - arms[1].global_position
	var along = relative.dot(ray_direction)
	var reach = 0.83 * torso.global_basis.get_scale().abs().x
	var discriminant = along * along - relative.length_squared() + reach * reach
	if discriminant <= 0:
		return ordinary
	var distance = -along + sqrt(discriminant)
	if distance <= 0.05:
		return ordinary
	return torso.to_local(aim_camera.global_position + ray_direction * distance)

func _solve_tool_arm(i: int, target: Vector3, _weight: float) -> void:
	_solve_arm(i, target, 1.0)

func _solve_sword_arm(i: int, target: Vector3, _weight: float) -> void:
	_solve_arm(i, target, 1.0)

func _extended_impact_target(i: int, target: Vector3, phase_key: Vector2) -> Vector3:


	var extension = phase_key.y if phase_key.x > 0.5 and phase_key.x < 1.5 else 1.0 - phase_key.y if phase_key.x > 1.5 and phase_key.x < 2.5 else 0.0
	var delta = target - arms[i].position
	return arms[i].position + delta.normalized() * lerpf(delta.length(), 0.87, extension)

func _solve_arm(i: int, target: Vector3, weight: float, pole_override: Vector3 = Vector3.INF, hinge_weight: float = 1.0, maximum_reach: float = 0.865) -> void:
	var side = -1.0 if i == 0 else 1.0
	var delta = target - arms[i].position
	var reach = clampf(delta.length(), 0.1, maximum_reach)
	var direction = delta.normalized()
	target = arms[i].position + direction * reach
	var pole = pole_override if pole_override.is_finite() else Vector3(side, 0.08, 0.14)
	var bend_direction = (pole - direction * pole.dot(direction)).normalized()
	var elbow_distance = (0.46 * 0.46 + reach * reach - 0.41 * 0.41) / (2.0 * reach)
	var elbow = arms[i].position + direction * elbow_distance + bend_direction * sqrt(maxf(0.0, 0.46 * 0.46 - elbow_distance * elbow_distance))
	var upper = Basis(Quaternion(Vector3.DOWN, (elbow - arms[i].position).normalized()))
	var lower = Quaternion(Vector3.DOWN, upper.inverse() * (target - elbow).normalized())
	if pole_override.is_finite():


		var hinge = bend_direction.cross(direction).normalized() * side
		var upper_y = -(elbow - arms[i].position).normalized()
		upper = upper.slerp(Basis(hinge, upper_y, hinge.cross(upper_y).normalized()), hinge_weight)
		var lower_y = -(target - elbow).normalized()
		var lower_basis = Basis(Quaternion(Vector3.UP, lower_y)).slerp(Basis(hinge, lower_y, hinge.cross(lower_y).normalized()), hinge_weight)
		lower = (upper.inverse() * lower_basis).get_rotation_quaternion()
	arms[i].quaternion = arms[i].quaternion.slerp(upper.get_rotation_quaternion(), weight)
	forearms[i].quaternion = forearms[i].quaternion.slerp(lower, weight)

func _orient_cradling_palm(i: int, weight: float, throw_blend: float, support: float) -> void:
	var inward = Vector3.RIGHT if i == 0 else Vector3.LEFT
	var rear = smoothstep(0.28, 0.58, carry_half_depth)
	var normal = (inward * lerpf(0.58, 0.18, rear) + Vector3.UP * 0.82 + Vector3.FORWARD * rear * 0.62).normalized()
	var fingers = Vector3.BACK.slide(normal).normalized()
	var desired = Basis(fingers.cross(normal).normalized(), fingers, normal)
	var overhead = Basis(Vector3.UP.cross(inward), Vector3.UP, inward).slerp(Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP), support)
	_orient_palm(i, desired.slerp(overhead, throw_blend), weight)

func _orient_supporting_palm(i: int, weight: float, upward: float = 0.0) -> void:
	var inward = Vector3.RIGHT if i == 0 else Vector3.LEFT
	var desired = Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
	desired = desired.slerp(Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP), upward)
	var parent = (arms[i].basis * forearms[i].basis).orthonormalized()
	wrists[i].quaternion = wrists[i].quaternion.slerp((parent.inverse() * desired).get_rotation_quaternion(), weight)

func _landing_weight() -> float:
	if _event_left.land <= 0.0:
		return 0.0
	var age = 0.44 - float(_event_left.land)
	return smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.06, 0.44, age)) * float(_event_strength.land)



func _punch_phase(age: float) -> Vector2:
	var contact = strike_contact(weapon_id, _strike_variant)
	var gather = contact * 0.5
	if age < gather:
		return Vector2(0.0, smoothstep(0.0, gather, age))
	if age < contact + 0.025:
		return Vector2(1.0, smoothstep(gather, contact - 0.008, age))
	if age < contact + 0.1:
		return Vector2(2.0, smoothstep(contact + 0.025, contact + 0.1, age))
	return Vector2(3.0, smoothstep(contact + 0.1, _strike_duration - 0.045, age))

func _strike_envelope(progress: float) -> float:
	var age = progress * _strike_duration
	return smoothstep(0.0, 0.075, age) * (1.0 - smoothstep(_strike_duration - 0.14, _strike_duration, age))

func _strike_curve(progress: float, anticipation: float, contact: float, recovery: float, duration: float = 0.54) -> float:
	var phase_key = _punch_phase(progress * duration)
	if phase_key.x < 0.5: return lerpf(0.0, anticipation, phase_key.y)
	if phase_key.x < 1.5: return lerpf(anticipation, contact, phase_key.y)
	if phase_key.x < 2.5: return lerpf(contact, recovery, phase_key.y)
	return lerpf(recovery, 0.0, phase_key.y)

func _punch_guard_upper(i: int) -> Quaternion:
	return Quaternion(Vector3.BACK, (-1.0 if i == 0 else 1.0) * PI * 0.25)

func _punch_hand_target(i: int, age: float) -> Vector3:
	var side = -1.0 if i == 0 else 1.0
	var upper = _punch_guard_upper(i)
	var guard_local = arms[i].position + upper * Vector3.DOWN * 0.46 + (upper * Quaternion(Vector3.RIGHT, PI * 2.0 / 3.0)) * Vector3.DOWN * 0.41
	var guard = torso.transform * guard_local - Vector3.UP * TORSO_PIVOT
	var start = _strike_origins[i]
	var envelope = _strike_envelope(age / _strike_duration)
	var windup = guard
	var contact = Vector3(side * 0.32, 0.29, -0.83)
	var follow = Vector3(side * 0.27, 0.27, -0.77)
	if _strike_variant == 2:

		contact = Vector3(side * 0.32, 0.34, -0.82)
		follow = Vector3(side * 0.27, 0.3, -0.79)
	var phase_key = _punch_phase(age)
	var target: Vector3
	if phase_key.x < 0.5: target = start.lerp(windup, phase_key.y)
	elif phase_key.x < 1.5: target = windup.lerp(contact, phase_key.y)
	elif phase_key.x < 2.5: target = contact.lerp(follow, phase_key.y)
	else: target = follow.lerp(guard, phase_key.y)
	return start.lerp(target, envelope)

func _ground_foot(i: int, direction: Vector3, stride: float, walking: bool, normal: Vector3) -> Vector3:
	var side = -1.0 if i == 0 else 1.0
	var cycle = fposmod(phase / TAU + i * 0.5, 1.0)
	var stance = lerpf(WALK_STANCE, RUN_STANCE, _run)
	var planted = cycle < stance
	var target = Vector3(side * 0.19, 0.085, 0.0)
	if walking and _speed > 0.15:
		var pitch: float
		if planted:
			var support = cycle / stance
			pitch = lerpf(0.16, 0.1, _run) * (1.0 - smoothstep(0.0, 0.22, support)) - lerpf(0.32, 0.28, _run) * smoothstep(0.52, 1.0, support)
			target += direction * lerpf(stride, -stride, support)
		else:
			var swing = (cycle - stance) / (1.0 - stance)
			pitch = lerpf(-lerpf(0.32, 0.28, _run), lerpf(0.16, 0.1, _run), smoothstep(0.1, 0.92, swing))
			target += direction * stride
		_foot_pitch[i] = move_toward(_foot_pitch[i], pitch, STEP * 5.0)
		var contact_height = 0.085 + maxf(0.0, sin(_foot_pitch[i])) * 0.09 + maxf(0.0, -sin(_foot_pitch[i])) * 0.34
		target.y = contact_height
		target.y -= (normal.x * target.x + normal.z * target.z) / maxf(0.35, normal.y)
		if planted:
			if not _foot_planted[i]:


				var sample = to_local(_foot_world_positions[i])
				var ground_y = -(normal.x * sample.x + normal.z * sample.z) / maxf(0.35, normal.y)
				_foot_anchors[i] = to_global(Vector3(sample.x, ground_y, sample.z))
				_plant_lift[i] = maxf(0.0, sample.y - ground_y - contact_height)
				if _locomotion > 0.35:
					_footsteps = mini(_footsteps + 1, 4)
			_plant_lift[i] = maxf(0.0, _plant_lift[i] - STEP * 2.5)
			target = to_local(_foot_anchors[i]) + Vector3.UP * (contact_height + _plant_lift[i])
		else:


			if _foot_planted[i]:
				_swing_origins[i] = _foot_world_positions[i]
			var swing = (cycle - stance) / (1.0 - stance)
			if _foot_planted[i]:
				_swing_start_phase[i] = swing
				_swing_progress[i] = 0.0
				_swing_targets[i] = to_global(target)



			_swing_targets[i] = _swing_targets[i].move_toward(to_global(target), STEP * (2.0 + _speed * 0.9))
			var progress = clampf((swing - _swing_start_phase[i]) / maxf(0.01, 1.0 - _swing_start_phase[i]), 0.0, 1.0)
			_swing_progress[i] = maxf(_swing_progress[i], progress)
			target = to_local(_swing_origins[i].lerp(_swing_targets[i], smoothstep(0.0, 1.0, _swing_progress[i])))
			target.y += sin(_swing_progress[i] * PI) * lerpf(0.18, 0.2, _run)
		_foot_planted[i] = planted
		_foot_positions[i] = target
	else:
		target.y -= (normal.x * target.x) / maxf(0.35, normal.y)
		if _settle_left > 0.0:
			var settle = clampf((0.34 - _settle_left - i * 0.08) / 0.24, 0.0, 1.0)
			var start = to_local(_settle_origins[i])
			var distance = Vector2(start.x - target.x, start.z - target.z).length()
			_foot_positions[i] = start.lerp(target, smoothstep(0.0, 1.0, settle))
			_foot_positions[i].y += sin(settle * PI) * minf(0.11, distance * 0.5)
		else:
			_foot_positions[i] = _foot_positions[i].lerp(target, 1.0 - exp(-STEP * 18.0))
		target = _foot_positions[i]
		_foot_pitch[i] = lerpf(_foot_pitch[i], 0.0, 1.0 - exp(-STEP * 18.0))
		_foot_planted[i] = true
		_foot_anchors[i] = to_global(target - Vector3.UP * 0.085)
	return target

func _solve_leg(i: int, target: Vector3, normal: Vector3, planted_weight: float) -> void:


	var rig_target = rig.transform.affine_inverse() * target
	var delta = rig_target - legs[i].position
	var reach = clampf(delta.length(), 0.12, THIGH_LENGTH + SHIN_LENGTH - 0.001)
	var direction = delta.normalized() if delta.length_squared() > 1.0e-06 else Vector3.DOWN
	rig_target = legs[i].position + direction * reach
	var bend_direction = _leg_bend_direction(direction, Vector3.FORWARD)
	var knee_position = legs[i].position + direction * reach * 0.5 + bend_direction * sqrt(maxf(0.0, THIGH_LENGTH * THIGH_LENGTH - reach * reach * 0.25))
	var upper = Basis(Quaternion(Vector3.DOWN, (knee_position - legs[i].position).normalized()))
	legs[i].basis = upper


	knees[i].quaternion = Quaternion(Vector3.DOWN, upper.inverse() * (rig_target - knee_position).normalized())
	var forward = Vector3.FORWARD.slide(normal).normalized()
	var planted_basis = Basis.looking_at(forward, normal) * Basis(Vector3.RIGHT, _foot_pitch[i])
	var airborne_basis = rig.basis * Basis(Vector3.RIGHT, 0.22)
	var desired_basis = airborne_basis.slerp(planted_basis, planted_weight)
	var parent_basis = (rig.basis * legs[i].basis * knees[i].basis).orthonormalized()
	feet[i].basis = parent_basis.inverse() * desired_basis

func _update_bag(land: float) -> void:



	var secondary = 1.0 - smoothstep(0.12, 0.24, bag_progress)
	var point = Vector3(0, 1.46, 0.46)
	if bag_progress < 0.34:
		point = point.lerp(Vector3(0.38, 1.53, 0.37), smoothstep(0.18, 0.34, bag_progress))
	elif bag_progress < 0.66:
		point = Vector3(0.38, 1.53, 0.37).bezier_interpolate(Vector3(0.84, 1.53, 0.22), Vector3(0.9, 1.45, -0.52), Vector3(0.42, 1.45, -0.62), smoothstep(0.34, 0.66, bag_progress))
	else:
		point = Vector3(0.42, 1.45, -0.62).lerp(Vector3(0, 1.45, -0.62), smoothstep(0.66, 0.82, bag_progress))
	backpack.position = point - Vector3.UP * TORSO_PIVOT
	backpack.position.y += secondary * (sin(phase * 2.0 - 0.5) * _locomotion * 0.012 - land * 0.025)
	var swing = smoothstep(0.3, 0.8, bag_progress)
	backpack.rotation = Vector3(-sin(swing * PI) * 0.1 + secondary * (sin(phase - 0.4) * _locomotion * 0.035 + land * 0.09), swing * PI, -sin(swing * PI) * 0.16 + secondary * sin(phase - 0.7) * _locomotion * 0.025)
	lid.rotation.x = -smoothstep(0.84, 1.0, bag_progress) * 1.55
	_update_bag_straps()

func _update_bag_straps() -> void:
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var release = smoothstep(0.23 if i == 0 else 0.17, 0.43 if i == 0 else 0.34, bag_progress)
		var x = side * 0.21
		var top = backpack.transform * Vector3(x, 0.2, -0.13)
		var bottom = backpack.transform * Vector3(x, -0.22, -0.13)
		var shoulder = Vector3(side * 0.29, 1.77 - TORSO_PIVOT, -0.015).lerp(backpack.transform * Vector3(x, 0.28, -0.24), release)
		var chest = Vector3(side * 0.29, 1.51 - TORSO_PIVOT, -0.25).lerp(backpack.transform * Vector3(x, 0.04, -0.31), release)
		var side_loop = Vector3(side * 0.37, 1.26 - TORSO_PIVOT, -0.035).lerp(backpack.transform * Vector3(x, -0.23, -0.25), release)
		var points = [top, shoulder, chest, side_loop, bottom]
		for link in range(4):
			var segment: MeshInstance3D = _bag_straps[i][link]
			var delta: Vector3 = points[link + 1] - points[link]
			segment.position = (points[link] + points[link + 1]) * 0.5
			segment.basis = Basis(Quaternion(Vector3.UP, delta.normalized())).scaled_local(Vector3(0.055, maxf(0.001, delta.length()), 0.022))

func _bag_hand_target(i: int) -> Vector3:
	if i == 0:


		var bottom = backpack.transform * Vector3(0.15, -0.345, -0.09)
		return Vector3(-0.27, 1.19 - TORSO_PIVOT, -0.39).lerp(bottom, smoothstep(0.6, 0.78, bag_progress))
	var strap = Vector3(0.31, 1.6 - TORSO_PIVOT, -0.25)
	var around_shoulder = Vector3(0.6, 1.56 - TORSO_PIVOT, -0.16)
	var pull = backpack.transform * Vector3(0.2, 0.18, -0.12)
	var target = strap.lerp(around_shoulder, smoothstep(0.16, 0.28, bag_progress))
	target = target.lerp(pull, smoothstep(0.28, 0.42, bag_progress))
	var flap = backpack.transform * lid.transform * Vector3(-0.18, 0.185, 0.13)
	return target.lerp(flap, smoothstep(0.6, 0.82, bag_progress))

func _aim_bag_hand(i: int, ease: float) -> void:
	var weight = smoothstep(0.0, 0.19, bag_progress) if i == 1 else smoothstep(0.56, 0.78, bag_progress)
	if weight < 0.001:
		return
	var target = _bag_hand_origins[i].origin.lerp(_bag_hand_target(i), weight)
	var pole = _bag_elbow_origins[i].lerp(Vector3(-0.55, -0.65, 0.12) if i == 0 else Vector3(0.55, -0.65, 0.1), weight)
	_solve_arm(i, target, 1.0, pole, weight)
	var support = Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP)
	if i == 1:
		var pull = Basis.IDENTITY.slerp(backpack.basis * Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), smoothstep(0.18, 0.4, bag_progress))
		var flap = backpack.basis * lid.basis * Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
		support = pull.slerp(flap, smoothstep(0.58, 0.84, bag_progress))
	_orient_palm(i, _bag_hand_origins[i].basis.orthonormalized().slerp(support, weight), 1.0)
	for finger in finger_joints[i]:
		finger.rotation.x = lerp_angle(finger.rotation.x, -0.48 if i == 0 else -0.65, ease * weight)

func _update_secondary(dt: float) -> void:
	flame.scale = Vector3(0.21 + sin(time * 6.0) * 0.014, 0.41 + sin(time * 10.0) * 0.03, 0.2)
	flame.rotation.z = sin(time * 5.0) * 0.1
	flame.rotation.x = sin(time * 4.2) * 0.055
	inner_flame.scale.y = 0.24 + sin(time * 12.0) * 0.018
	lantern.light_energy = 2.3 + sin(time * 8.0) * 0.1 + sin(time * 13.7) * 0.035
	cape.scale.y = lerpf(1.0, 0.43, _dodge_tuck)
	cape.rotation.x = _dodge_tuck * 0.22
	var body_frame := torso.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 1.46 - TORSO_PIVOT, 0))
	var collisions: Array = []
	var limb_bounds: Array = []
	var body_inverse := rig.global_transform.affine_inverse()
	for i in range(2):






		var thigh_frame := body_inverse * legs[i].global_transform
		var shin_frame := body_inverse * knees[i].global_transform
		for segment in [Vector2(-0.14, 0.235), Vector2(-0.275, 0.135), Vector2(-0.405, 0.13)]:
			limb_bounds.append(thigh_frame * AABB(Vector3(-0.1, segment.x, -0.11), Vector3(0.2, segment.y, 0.22)))
		for segment in [Vector2(-0.1, 0.185), Vector2(-0.23, 0.13), Vector2(-0.36, 0.13)]:
			limb_bounds.append(shin_frame * AABB(Vector3(-0.09, segment.x, -0.1), Vector3(0.18, segment.y, 0.2)))
		limb_bounds.append((body_inverse * feet[i].global_transform) * AABB(Vector3(-0.125, -0.085, -0.35), Vector3(0.25, 0.185, 0.465)))
	collisions.append({"kind": "lower_body", "transform": rig.global_transform, "half": Vector3.ONE, "parts": limb_bounds})

	collisions.append({"kind": "ellipsoid", "transform": body_frame, "half": Vector3(0.355, 0.385, 0.245)})
	collisions.append({"kind": "backpack", "transform": backpack.global_transform, "half": Vector3(0.285, 0.325, 0.175), "worn": bag_progress < 0.16})
	var velocity := _velocity if _has_context else -global_basis.orthonormalized().z * _speed
	_cape_cloth.advance(dt, cape.global_transform, velocity, collisions)



func cape_state() -> Dictionary:
	return {"vertices": _cape_cloth.local_vertices(cape.global_transform), "columns": CapeCloth.COLUMNS, "rows": CapeCloth.ROWS, "substeps": _cape_cloth.last_substeps, "resets": _cape_cloth.resets}

func reset_cape_motion() -> void:
	_cape_cloth.reset(cape.global_transform)

func _create_cape() -> void:
	var shader = Shader.new()
	shader.code = "\nshader_type spatial;\nrender_mode cull_disabled;\nuniform sampler2D cloth_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;\nvoid fragment() {\n\tALBEDO = mix(vec3(0.53, 0.028, 0.05), vec3(0.72, 0.045, 0.075), 0.5 + 0.5 * sin(UV.x * 25.0));\n\tALBEDO *= texture(cloth_detail, UV * vec2(3.0, 4.0)).rgb * 1.3;\n\tfloat edge = 1.0 - smoothstep(0.012, 0.030, min(UV.x, 1.0 - UV.x));\n\tfloat hem = smoothstep(0.975, 0.990, UV.y);\n\tALBEDO = mix(ALBEDO, vec3(0.32, 0.018, 0.035), max(edge, hem));\n\tROUGHNESS = 0.88;\n}\n"












	_cape_shader = ShaderMaterial.new()
	_cape_shader.shader = shader
	_cape_shader.set_shader_parameter("cloth_detail", B.Surfaces.texture("cloth"))
	cape_material = _cape_shader
	_cape_cloth = CapeCloth.new()
	cape = B.mesh(torso, _cape_cloth.mesh, cape_material, Vector3(0, 1.77, 0.2))



	cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cape.custom_aabb = _cape_cloth.mesh.custom_aabb

func _orient_palm(i: int, desired: Basis, weight: float) -> void:
	var parent = (arms[i].basis * forearms[i].basis).orthonormalized()
	wrists[i].quaternion = wrists[i].quaternion.slerp((parent.inverse() * desired).get_rotation_quaternion(), weight)

func launch_grapple(point: Vector3, normal: Vector3) -> bool:
	cancel_grimoire_cast()
	return grapple.launch(point, normal)

func update_grapple_anchor(point: Vector3, normal: Vector3) -> void:
	grapple.set_anchor(point, normal)

func grapple_active() -> bool:
	return grapple.active()

func grapple_latched() -> bool:
	return grapple.state == "latched"

func finish_grapple(immediate: bool = false) -> void:
	grapple.finish(immediate)

func palm_origin(i: int = 1) -> Vector3:
	return hands[i].palm_origin()
