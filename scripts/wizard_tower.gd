extends Node3D

const B = preload("res://scripts/build.gd")
const ANCHOR := Vector2(-20, -14)
const ENTRANCE := Vector3(0, 0, 2.93)
var game
var altar: Node3D
var preview: Node3D
var orbit: Node3D
var book: Node3D
var elapsed := 0.0
var built := false
var wizard_resident: Node3D

func destination() -> Dictionary:
	return {"id": "wizard_tower", "name": "The Wizard's Tower", "pos": Vector2(position.x, position.z), "kind": "tower"}

func setup(owner_game) -> void:
	game = owner_game
	if is_inside_tree(): _build()

func _ready() -> void:
	if game != null: _build()

func get_altar() -> Node3D:
	return altar

func _build() -> void:
	if built or game == null or not is_instance_valid(game.world): return
	built = true
	name = "WizardTower"
	var anchor: Vector2 = preload("res://scripts/fixed_world.gd").wizard_anchor() if game.world.get("atlas") != null else ANCHOR
	position = Vector3(anchor.x, game.world.surface_height_at(anchor.x, anchor.y), anchor.y)
	set_meta("location_id", "wizard_tower")
	set_meta("entrance_position", ENTRANCE)
	set_meta("door_position", ENTRANCE)
	set_meta("building_title", "The Wizard's Tower")
	add_to_group("wizard_tower")
	var dark_stone = B.world_surface("stone", "#536873")
	var amber = B.mat("#d9ae63", 0.45); var cyan = B.mat("#88e5e8", 0, 0.7); var purple = B.mat("#b39bff", 0, 0.6)
	load("res://scripts/landmark_art.gd").tower_shell(self)


	for side in [-1, 1]:
		var cheek = Node3D.new(); cheek.position = Vector3(side * 2.065, 1.55, 2.68); cheek.rotation.y = side * 0.67; add_child(cheek)
		B.box(cheek, Vector3.ZERO, Vector3(0.86, 3.1, 0.38), dark_stone, true)
	B.cyl(self, Vector3(0, -0.066, 0), 3.1, 0.2, dark_stone, true)
	_build_altar(cyan, purple, amber, dark_stone)
	_build_wizard()
	load("res://scripts/building_access.gd").attach_building(self, 6.5, 5.86, "wizard_tower", {"door_width": 3.1, "door_height": 3.1, "inside": Vector3(1.65, 0.2, 0.5)})
	var paths = load("res://scripts/building_paths.gd")
	paths.attach(self, game.world, paths.streets(game.world, {"pos": anchor, "kind": "tower"}), [])
	var title := _label(self, Vector3(0, 4.3, 3.32), "THE WIZARD'S TOWER", 28, Color("#f4db9c"))
	title.name = "TowerName"
	title.pixel_size = 0.009
	_label(self, Vector3(0, 3.4, 3.45), "SPELL ARCHIVE  ·  USE THE GREEN RING", 21, Color("#adedef")).pixel_size = 0.008

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.7, 2.1)
	light.light_color = Color("#ffdab0")
	light.light_energy = 0.55
	light.omni_range = 6
	light.shadow_enabled = false
	add_child(light)
	B.batch_static(self)
	for geometry in find_children("*", "GeometryInstance3D", true, false):
		geometry.visibility_range_end = minf(145, geometry.visibility_range_end) if geometry.visibility_range_end > 0 else 145
		geometry.visibility_range_end_margin = 8

func _build_altar(cyan: Material, purple: Material, amber: Material, dark_stone: Material) -> void:
	altar = Node3D.new()
	altar.name = "SpellAltar"
	altar.position = Vector3(0, 0.08, 1.3)
	altar.set_meta("id", "wizard_spell_altar")
	altar.set_meta("kind", "spell_altar")
	altar.set_meta("label", "Browse the spell collection")
	altar.set_meta("name", "Spell Archive")
	altar.set_meta("climbable", false)
	add_child(altar)
	altar.add_to_group("interactable")
	altar.add_to_group("magic_altar")


	B.ring(altar, Vector3(0, -0.04, 0), 1.03, 0.035, cyan)
	B.ring(altar, Vector3(0, -0.035, 0), 0.78, 0.025, amber)
	load("res://scripts/landmark_art.gd").module(altar, "ruin_altar", Vector3.ZERO, Vector3(1.4, 0.76, 1.1))
	book = Node3D.new()
	book.set_meta("batch_dynamic", true)
	book.position = Vector3(0, 0.89, 0)
	book.rotation.x = 0.22
	altar.add_child(book)
	load("res://scripts/household_details.gd").place(book, "kaykit_journal_open", Vector3.ZERO, Vector3(0.96, 0.13, 0.64), Vector3(-PI * 0.5, 0, 0))
	preview = Node3D.new()
	preview.name = "AltarConstellation"
	preview.set_meta("batch_dynamic", true)
	preview.position = Vector3(0, 1.65, 0)
	altar.add_child(preview)
	B.ball(preview, Vector3.ZERO, Vector3.ONE * 0.3, cyan)
	B.ring(preview, Vector3.ZERO, 0.35, 0.025, purple).rotation.x = 0.7
	orbit = Node3D.new()
	preview.add_child(orbit)
	for index in range(3):
		var angle := index * TAU / 3
		B.facet(orbit, Vector3(cos(angle) * 0.45, sin(angle * 2) * 0.15, sin(angle) * 0.45), Vector3.ONE * 0.12, amber)

func _build_wizard() -> void:


	var wizard = preload("res://scripts/resident.gd").new()
	wizard.name = "Wizard"
	wizard.position = Vector3(-1.65, 0, -0.2)
	wizard.race = "human"
	wizard.role = "wizard"
	wizard.set_meta("id", "oriel")
	wizard.set_meta("name", "Oriel the Spellwright")
	wizard.collision_layer = 0
	wizard.collision_mask = 0
	wizard.sync_to_physics = false
	add_child(wizard)
	wizard.make_visual("#575384", "hat")
	wizard.greeting.visible = false
	wizard_resident = wizard
	var title := _label(wizard, Vector3(0, 2.75, 0), "ORIEL THE SPELLWRIGHT", 19, Color("#f7e6bf"))
	title.name = "WizardName"
	title.pixel_size = 0.005
	_label(wizard, Vector3(0, 2.53, 0), "A spell for every strange little adventure.", 15, Color("#b7d8d3")).pixel_size = 0.004

func _label(parent: Node3D, pos: Vector3, value: String, size_value: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.position = pos
	label.text = value
	label.font = preload("res://assets/fonts/body.ttf")
	label.font_size = size_value
	label.modulate = color
	label.outline_modulate = Color("#17202a")
	label.outline_size = 4
	label.pixel_size = 0.007
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _process(dt: float) -> void:
	if not built or not is_instance_valid(preview): return
	elapsed += dt
	if is_instance_valid(wizard_resident):
		var step := clampf(dt, 0.0, 0.1)
		wizard_resident.clock += step
		wizard_resident.animate(step, false, false)
	preview.position.y = 1.65 + sin(elapsed * 1.5) * 0.08
	preview.rotation.y += dt * 0.35
	orbit.rotation.y -= dt * 0.8
	book.position.y = 0.89 + sin(elapsed * 1.2 + 0.7) * 0.022
