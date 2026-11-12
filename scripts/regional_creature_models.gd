extends RefCounted
const F = preload("res://scripts/creature_facets.gd")


const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/cast_art.gd")
const G = preload("res://scripts/creature_shape.gd")
const N = preload("res://scripts/creature_anatomy_mesh.gd")
const Animal = preload("res://scripts/regional_animal_anatomy.gd")
const Haunted = preload("res://scripts/haunted_creature_art.gd")
const Human = preload("res://scripts/humanoid_creature_art.gd")
const C = preload("res://scripts/creature_catalog.gd")
const Resources = preload("res://scripts/creature_resources.gd")
const SharedWildlife = preload("res://scripts/wildlife_models.gd")
static var wild_scenes: Dictionary = {}
static var enemy_scenes: Dictionary = {}

const WILD_PALETTES = {
	"craghorn_goat": ["#7e8887", "#e1d9c8", "#3b4148"], "riverglass_kingfisher": ["#26899b", "#e1a05c", "#354452"],
	"mallow_sheep": ["#edcfda", "#fff0e4", "#85616c"], "cocoa_chipmunk": ["#8c513b", "#ead7ae", "#543a35"],
	"fizz_frog": ["#64ad9b", "#d7efb1", "#457a81"], "graham_tortoise": ["#ac7947", "#eed49c", "#704d39"],
	"caramel_dormouse": ["#c58a56", "#ffe2b4", "#8a5d51"], "sugarwing_bee": ["#edbb72", "#fff0d8", "#6b4752"],
	"meadowhopper": ["#79a85c", "#d3df98", "#507c58"], "windtail_hare": ["#bc9272", "#f1deba", "#7c5b53"],
	"reedcrest_crane": ["#d4d9c4", "#f2e9cc", "#495760"], "goldmane_antelope": ["#b98a51", "#f2dcb3", "#544344"],
	"streamback_turtle": ["#5e8c7b", "#cbd9a6", "#41666a"], "sandshell_lizard": ["#bc9561", "#f2d9a1", "#8b654c"],
	"dune_jerboa": ["#cfaa78", "#fae9c8", "#986f5d"], "oasis_ibis": ["#eddfc5", "#5ab4b3", "#4d626e"],
	"amber_scarab": ["#a66d30", "#f0cd70", "#535454"], "shadeback_camel": ["#aa7954", "#e9cba0", "#674e43"],
	"ember_salamander": ["#4d5a61", "#e9a064", "#303b44"], "ash_moth": ["#7d788c", "#e2d3b9", "#453e54"],
	"basalt_beetle": ["#434c58", "#82959a", "#28333c"], "copperback_gecko": ["#a47555", "#d9ba86", "#5e524a"],
	"cinderfin_fish": ["#526f80", "#efab73", "#354457"], "ventwing_swift": ["#667080", "#dbd4c3", "#354351"],
	"ashen_raven": ["#3e4057", "#93899e", "#272b3e"], "pallid_moth": ["#c9bbc9", "#f0e7d9", "#6d5775"],
	"gravemoss_snail": ["#677f69", "#b8c39c", "#4c5a5b"], "prismhart": ["#9eafca", "#f2e9e3", "#69758f"],
	"opaline_otter": ["#719daf", "#e1d9d8", "#4d687f"], "chimewing_manta": ["#8a9dc7", "#dcd6ec", "#566d9b"],
	"geode_tortoise": ["#8d8aaf", "#c9d9d2", "#575f80"], "faceted_finch": ["#91bcb7", "#f3d3a8", "#626d94"],
	"quartz_hare": ["#becbd9", "#f3e9e5", "#9c91b0"]}
const ENEMY_COATS = {
	"cliffwarden": "#727e87", "stonejaw_wyrm": "#65776b", "fudge_golem": "#714335", "wrapper_mimic": "#a8678c", "pretzel_crawler": "#b98651",
	"cola_sloshback": "#87503b", "sugarspike_wasp": "#ccab70", "grand_confectioner": "#855d80", "windwhistle_stalker": "#aaa26f",
	"thistle_jackal": "#8c8362", "grassland_colossus": "#6e8567", "kiteclaw_raptor": "#8b795c", "stormhorn_matriarch": "#726347",
	"dune_maw": "#b99567", "sunken_sentinel": "#737f77", "sandwraith": "#b6a184", "obelisk_scorpion": "#615a55", "glass_anubid": "#536f77",
	"riftback": "#4a535e", "furnace_hound": "#474c59", "slag_crawler": "#6a5550", "ash_harpy": "#757381", "root_reaper": "#596362",
	"wraithhart": "#879493", "hollow_hound": "#655b79", "grave_creeper": "#657160", "veil_moth": "#9086a5", "thorn_widow": "#51445e",
	"mourning_knight": "#655973", "pale_watcher": "#a2a6b3", "blackthorn_regent": "#484c67", "shard_sentinel": "#849caf",
	"prismstalker": "#85a9b8", "geode_mimic": "#8d82aa", "resonance_wyrm": "#7886ae", "glasswing_reaver": "#9baecb", "aurora_custodian": "#a6bbcb"}
static func _joint(parent: Node3D, p: Vector3, label: String) -> Node3D:
	var node = Node3D.new(); node.position = p; node.name = label; node.set_meta("regional_joint", true); node.add_to_group("batch_dynamic"); parent.add_child(node); return node
static func _finish(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is Node3D and not child is GeometryInstance3D: _finish(child)
	if parent.get_meta("regional_joint", false): parent.remove_from_group("batch_dynamic")
	A.finish(parent)
	if parent.get_meta("regional_joint", false): parent.add_to_group("batch_dynamic")
static func _paths(model: Node, value):
	if value is Node: return model.get_path_to(value)
	if value is Array:
		var array = []
		for item in value: array.append(_paths(model, item))
		return array
	if value is Dictionary:
		var data = {}
		for key in value: data[key] = _paths(model, value[key])
		return data
	return value
static func _own(node: Node, model: Node) -> void:
	if node != model: node.owner = model
	for group in node.get_groups(): node.remove_from_group(group); node.add_to_group(group, true)
	for child in node.get_children(): _own(child, model)
static func _scene(model: Node3D, rig: Dictionary, properties: Dictionary) -> PackedScene:
	model.set_meta("rig_bindings", _paths(model, rig)); model.set_meta("actor_properties", properties)
	model.set_meta("geometry_revision", "anatomical-cast-34")
	_own(model, model)
	var scene = PackedScene.new(); assert(scene.pack(model) == OK); return scene
static func _skin(region: int, light: bool = false) -> Material:
	var colors = ["#7e8265", "#a8815c", "#a6a782", "#b99b69", "#665a53", "#777286", "#a4b6c6"]
	return F.material("fur", Color(colors[clampi(region - 9, 0, 6)]).lightened(0.2 if light else 0))
static func _eyes(head: Node3D, width: float, y: float, z: float, size: float = 0.055, family: String = "fur", metallic: float = 0.0) -> void:
	F.eyes(head, width, y, z, size, F.material(family, Color("#b49a65"), metallic), family, metallic)
static func _ears(head: Node3D, rig: Dictionary, width: float, length: float, material: Material, lining: Material, kind: String = "pointed") -> void:
	for side in [-1.0, 1.0]:
		var rounded = kind == "round"
		var root_point = Vector3(side * width, 0.12, 0.025)
		var normal = Vector3(side * 0.7, 0.7, 0.12).normalized()
		var hit = F.surface_point(head.get_child(0), head, Vector3(side * width * 0.8, 0.075, 0.025) + normal * 0.3, -normal)
		if hit is Vector3: root_point = hit - normal * 0.018
		var ear = _joint(head, root_point, "EarLeft" if side < 0 else "EarRight"); ear.set_meta("side", side); rig.ears.append(ear)
		var angle = -side * (1.0 if kind == "lateral" else 0.2)
		var ear_size = Vector3(length * (0.82 if rounded else 0.55), length, 0.085 if rounded else 0.11)
		G.shape(ear, Vector3(side * 0.035, length * 0.36, 0), ear_size, material, "skull" if rounded else "ear", Vector3(0.08, 0, angle))
		G.shape(ear, Vector3(side * 0.035, length * 0.36, -0.044), ear_size * Vector3(0.56, 0.69, 0.28), lining, "skull" if rounded else "ear", Vector3(0.08, 0, angle))
static func _tail(parent: Node3D, rig: Dictionary, at: Vector3, length: float, width: float, material: Material, tip: Material = null) -> Node3D:
	var tail = _joint(parent, at, "Tail"); rig.tails.append(tail)
	var rows: Array[Vector4] = [Vector4(-0.025, width * 0.48, width * 0.44, -width * 0.44), Vector4(length * 0.2, width * 0.52, -length * 0.03 + width * 0.47, -length * 0.03 - width * 0.47), Vector4(length * 0.54, width * 0.36, -length * 0.11 + width * 0.34, -length * 0.11 - width * 0.34), Vector4(length * 0.82, width * 0.19, -length * 0.17 + width * 0.18, -length * 0.17 - width * 0.18), Vector4(length, width * 0.025, -length * 0.2 + width * 0.028, -length * 0.2 - width * 0.028)]
	N.z_loft(tail, rows.slice(0, 4) if tip != null else rows, material, "TaperedTail")
	if tip != null: N.z_loft(tail, rows.slice(3), tip, "TailTip")
	return tail
static func _horns(head: Node3D, material: Material, branches: bool = false, length: float = 0.62, style: String = "deer") -> void:
	for side in [-1.0, 1.0]:
		var p = Vector3(side * 0.12, 0.13, 0.06); var end = p + Vector3(side * 0.18, length, 0.15)
		var points = PackedVector3Array([p, p + Vector3(side * 0.1, length * 0.33, 0.04), p + Vector3(side * 0.17, length * 0.71, 0.09), end])
		if style == "goat": points = PackedVector3Array([p, p + Vector3(side * 0.09, length * 0.35, 0.02), p + Vector3(side * 0.1, length * 0.65, 0.18), p + Vector3(side * 0.06, length * 0.64, 0.37)])
		F.tube(head, points, PackedFloat32Array([0.065, 0.052, 0.03, 0.003]), material, 7)
		if branches:
			for i in range(3):
				var branch = p.lerp(end, 0.32 + i * 0.21)
				F.tube(head, PackedVector3Array([branch, branch + Vector3(side * 0.21, 0.22, -0.1)]), PackedFloat32Array([0.025, 0.001]), material, 6)
static func _legs(parent: Node3D, rig: Dictionary, height: float, width: float, length: float, material: Material, foot: Material, kind: String = "paw", count: int = 4) -> void:
	for i in range(count):
		var side = -1.0 if i % 2 == 0 else 1.0; var front = i < 2
		var z = (-length if front else length) * 0.32 if count == 4 else (float(i / 2) / maxf(1, count * 0.5 - 1) - 0.5) * length * 0.7
		var hip = Vector3(side * width, height, z)
		var leg = _joint(parent, hip, "Foreleg" + str(i) if front else "Hindleg" + str(i)); rig.legs.append(leg)
		var knee_point = Vector3(side * 0.08 if kind in ["splayed", "insect"] else 0, -height * 0.48, 0.045 if front else -0.1)
		if not front and kind in ["bound", "paw", "hoof"]: knee_point = Vector3(side * 0.025, -height * 0.31, -0.12 if kind == "bound" else -0.09)
		if kind in ["insect", "hopper"]: knee_point = Vector3(side * 0.25, -height * 0.23, 0)
		if kind == "hopper" and i >= 4: knee_point = Vector3(side * 0.15, 0.17, 0.18)
		if kind == "bird": knee_point = Vector3(0, -height * 0.47, 0.065)
		var thickness = maxf(0.055, width * 0.33) if kind != "hoof" else maxf(0.065, height * 0.11)
		if not front and kind != "insect": thickness *= 1.35
		if kind in ["insect", "hopper"]: thickness = 0.034
		if kind == "hopper" and i >= 4: thickness = 0.07
		if kind == "bird": thickness = 0.024
		N.segment(leg, Vector3(0, 0.045, 0), knee_point, thickness * 2.25, thickness * 1.2, thickness * 2.4, thickness * 1.15, material)
		var knee = _joint(leg, knee_point, "Knee"); rig.knees.append(knee)
		var ankle = Vector3(side * 0.1 if kind in ["insect", "hopper"] else 0, -height + 0.045, -0.16 if kind == "hopper" and i >= 4 else -0.02) - knee_point
		if not front and kind in ["paw", "hoof", "bound"]:
			var hock = Vector3(0, -height * 0.73, 0.105) - knee_point
			N.segment(knee, Vector3.ZERO, hock, thickness * 1.25, thickness * 0.72, thickness * 1.45, thickness * 0.8, material)
			N.segment(knee, hock, ankle, thickness * 0.72, thickness * 0.65, thickness * 0.8, thickness * 0.68, material)
		else: N.segment(knee, Vector3.ZERO, ankle, thickness * 1.2, thickness * 0.78, thickness * 1.15, thickness * 0.82, material)
		var toe = ankle + Vector3(0, -0.045, -0.02)
		if kind == "hoof":
			var toe_width = maxf(0.054, width * 0.18)
			for split in [-1.0, 1.0]: N.paw(knee, toe + Vector3(split * toe_width * 0.52, 0, 0), toe_width, 0.16, 0.08, foot)
		elif kind in ["insect", "hopper"]: N.segment(knee, ankle, ankle + Vector3(side * 0.09, -0.03, -0.07), 0.028, 0.012, 0.025, 0.012, foot)
		elif kind == "bird":
			for finger in range(3): N.segment(knee, ankle, Vector3((finger - 1) * 0.055, -height, -0.12) - knee_point, 0.018, 0.009, 0.015, 0.008, foot)
			N.segment(knee, ankle, Vector3(0, -height, 0.08) - knee_point, 0.015, 0.008, 0.015, 0.008, foot)
		else:
			var paw_width = maxf(0.12, thickness * 1.75)
			N.paw(knee, toe, paw_width, 0.29 if kind == "bound" and not front else 0.19, 0.08, foot)
			if kind == "paw":
				for digit in [-1.0, 0.0, 1.0]: N.paw(knee, toe + Vector3(digit * paw_width * 0.27, 0.003, -0.07), paw_width * 0.3, 0.09, 0.04, material)
			if kind == "splayed":
				for finger in range(3): G.span(knee, toe + Vector3((finger - 1) * 0.025, 0, -0.02), toe + Vector3((finger - 1) * 0.065, -0.016, -0.1), 0.025, 0.022, foot)
static func wildlife(parent: Node3D, id: String) -> Dictionary:
	if C.LEGACY_WILD.has(id): return SharedWildlife.build(parent, C.LEGACY_WILD[id])
	var path = "res://assets/creatures/regional_wild_" + id + ".scn"
	if not wild_scenes.has(id) and ResourceLoader.exists(path): wild_scenes[id] = load(path)
	if wild_scenes.has(id): return Resources.attach_packed(parent, wild_scenes[id]).rig
	return _author_wildlife(parent, id)

static func _author_wildlife(parent: Node3D, id: String) -> Dictionary:
	var entry = C.entry(id); var form: String = entry.form; var region: int = entry.region
	var palette: Array = WILD_PALETTES.get(id, ["#8b9c84", "#ddd6ba", "#514e4a"])
	var mat = F.material("fur", Color(palette[0])); var pale = F.material("fur", Color(palette[1])); var dark = F.material("fur", Color(palette[2])); var bone = F.material("bone", Color("#d8c7a2"))
	var rig = {"head": null, "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	parent.name = entry.name; parent.set_meta("species", id); parent.set_meta("anatomy", form)
	var y = 0.4; var size = Vector3(0.53, 0.55, 0.92); var head_at = Vector3(0, 0.58, -0.48)
	var leg_kind = "paw"
	match form:
		"deer", "goat", "antelope", "camel": y = 0.89; size = Vector3(0.65, 0.64, 1.27); head_at = Vector3(0, 1.24 if form != "camel" else 1.52, -0.64); leg_kind = "hoof"
		"sheep": y = 0.57; size = Vector3(0.76, 0.71, 1.06); head_at = Vector3(0, 0.71, -0.62); leg_kind = "hoof"
		"hare": y = 0.29; size = Vector3(0.4, 0.43, 0.62); head_at = Vector3(0, 0.48, -0.36); leg_kind = "bound"
		"rodent": y = 0.23; size = Vector3(0.34, 0.34, 0.55); head_at = Vector3(0, 0.34, -0.3); leg_kind = "bound" if id == "dune_jerboa" else "paw"
		"otter": y = 0.24; size = Vector3(0.39, 0.33, 0.92); head_at = Vector3(0, 0.34, -0.49)
		"lizard": y = 0.18; size = Vector3(0.39, 0.23, 0.8); head_at = Vector3(0, 0.21, -0.46); leg_kind = "splayed"
		"frog": y = 0.25; size = Vector3(0.57, 0.39, 0.62); head_at = Vector3(0, 0.32, -0.3); leg_kind = "bound"
		"tortoise": y = 0.23; size = Vector3(0.56, 0.32, 0.72); head_at = Vector3(0, 0.24, -0.44); leg_kind = "splayed"
		"beetle", "hopper": y = 0.25; size = Vector3(0.4, 0.35, 0.66); head_at = Vector3(0, 0.25, -0.37); leg_kind = "hopper" if form == "hopper" else "insect"
		"snail": y = 0.09; size = Vector3(0.39, 0.18, 0.95); head_at = Vector3(0, 0.21, -0.43)
		"bird": y = 0.45; size = Vector3(0.31, 0.36, 0.56); head_at = Vector3(0, 0.64, -0.26)
		"crane": y = 0.8; size = Vector3(0.37, 0.47, 0.64); head_at = Vector3(0, 1.14, -0.41)
		"moth", "bee": y = 0.38; size = Vector3(0.19, 0.19, 0.44); head_at = Vector3(0, 0.4, -0.24)
		"fish": y = 0.22; size = Vector3(0.22, 0.32, 0.66); head_at = Vector3(0, 0.23, -0.33)
		"manta": y = 0.36; size = Vector3(0.6, 0.13, 0.8); head_at = Vector3(0, 0.38, -0.32)
	Animal.body(parent, form, y, size, head_at, pale if form == "sheep" else mat)
	rig.head = _joint(parent, head_at, "Head")
	var head_size = Animal.head(rig.head, form, mat, pale, dark)
	if form in ["deer", "goat", "antelope", "camel", "sheep", "hare", "rodent", "otter"]:
		_ears(rig.head, rig, head_size.x * 0.4, 0.4 if form == "hare" or id == "dune_jerboa" else 0.18 if form != "otter" else 0.105, mat, F.material("fur", Color("#c7989b")) if form in ["hare", "rodent", "otter"] else pale, "round" if form == "otter" or form == "rodent" and id != "dune_jerboa" else "lateral" if form in ["goat", "antelope", "sheep", "camel"] else "pointed")
	if form not in ["moth", "bee", "fish", "manta", "snail", "bird", "crane"]:
		_legs(parent, rig, maxf(0.14, y - 0.07), size.x * 0.35, size.z, mat, dark, leg_kind, 6 if form in ["beetle", "hopper"] else 4)
	if form in ["bird", "crane"]:
		G.span(rig.head, Vector3(0, -0.08, -0.06), Vector3(0, -0.14, -0.46 if form == "crane" else -0.28), 0.07, 0.07, bone, "ear")
		if form == "crane": G.span(parent, Vector3(0, y, -0.22), head_at - Vector3(0, 0.04, 0), 0.12, 0.16, pale)
		_legs(parent, rig, y - 0.12, 0.09, 0.1, dark, dark, "bird", 2)
		_tail(parent, rig, Vector3(0, y, 0.22), 0.34, 0.12, mat)
	if form in ["moth", "bee", "bird", "crane", "manta"]:
		var kind = "moth" if form == "moth" else "bee" if form == "bee" else "manta" if form == "manta" else "bird"
		for side in [-1.0, 1.0]:
			var wing = _joint(parent, Vector3(side * size.x * 0.24, y, 0.015), "WingLeft" if side < 0 else "WingRight"); rig.wings.append(wing)
			var membrane = G.wing(wing, side, kind, pale); membrane.add_to_group("batch_dynamic"); rig.wing_meshes.append(membrane)
			for i in range(5):
				var p = Vector3(side * (0.12 + i * 0.11), 0.017, -0.08 + i * 0.045)
				G.span(wing, Vector3(side * 0.04, 0.016, -0.07), p + Vector3(side * 0.12, 0, 0.14), 0.014, 0.018, mat, "feather")
			if form in ["bird", "crane"]:
				for i in range(5): G.shape(wing, Vector3(side * (0.37 + i * 0.105), 0.01, 0.17 + i * 0.018), Vector3(0.16, 0.045, 0.35), mat, "body", Vector3(0, side * 0.32, 0))
			elif form == "moth":
				G.shape(wing, Vector3(side * 0.46, 0.026, -0.16), Vector3(0.17, 0.018, 0.18), dark)
				G.shape(wing, Vector3(side * 0.46, 0.038, -0.16), Vector3(0.1, 0.014, 0.11), bone)
				G.shape(wing, Vector3(side * 0.38, 0.026, 0.2), Vector3(0.09, 0.02, 0.11), mat)
		if form in ["bee", "moth"]:
			for side in [-1.0, 1.0]: F.tube(rig.head, PackedVector3Array([Vector3(side * 0.05, 0.08, 0), Vector3(side * 0.14, 0.21, -0.09), Vector3(side * 0.2, 0.23, -0.08)]), PackedFloat32Array([0.01, 0.007, 0.002]), dark, 5)
	if form in ["deer", "antelope", "goat"]: _horns(rig.head, dark if form == "antelope" else bone, form == "deer", 0.52 if form != "goat" else 0.4, form)
	if form == "sheep":


		for row in range(4):
			for side in [-1.0, 0.0, 1.0]:
				var hit = F.surface_point(parent.get_child(0), parent, Vector3(side * 0.19, 2, -0.3 + row * 0.18), Vector3.DOWN)
				if hit is Vector3: G.shape(parent, hit - Vector3.UP * 0.025, Vector3(0.24, 0.11, 0.26), pale, "plate")
		G.shape(rig.head, Vector3(0, 0.14, 0.025), Vector3(0.25, 0.1, 0.23), pale, "plate")
	if form in ["tortoise", "beetle", "snail"]:
		var shell = F.material("stone" if id == "geode_tortoise" else "bone", Color("#c5aa7c" if region in [10, 12] else "#8c9d89"))
		if form == "snail":
			_snail_shell(parent, shell, pale)
			for side in [-1.0, 1.0]:
				G.span(rig.head, Vector3(side * 0.1, 0.05, 0), Vector3(side * 0.14, 0.26, -0.08), 0.025, 0.025, mat)
				G.shape(rig.head, Vector3(side * 0.14, 0.26, -0.08), Vector3(0.045, 0.045, 0.045), dark)
		elif form == "beetle":


			N.z_loft(parent, [Vector4(-0.33, 0.11, y + 0.13, y - 0.09), Vector4(-0.24, 0.18, y + 0.2, y - 0.1), Vector4(-0.11, 0.15, y + 0.17, y - 0.09)], shell, "Pronotum")
			for side in [-1.0, 1.0]:
				var elytron = N.z_loft(parent, [Vector4(-0.12, 0.065, y + 0.17, y - 0.01), Vector4(0.03, 0.125, y + 0.25, y - 0.03), Vector4(0.24, 0.115, y + 0.22, y - 0.03), Vector4(0.36, 0.045, y + 0.1, y - 0.01)], mat, "WingCase")
				elytron.position.x = side * 0.105
			F.tube(parent, PackedVector3Array([Vector3(0, y + 0.17, -0.12), Vector3(0, y + 0.25, 0.03), Vector3(0, y + 0.22, 0.24), Vector3(0, y + 0.1, 0.36)]), PackedFloat32Array([0.006, 0.007, 0.007, 0.005]), dark, 4)
		else:
			var shell_mesh = N.z_loft(parent, [Vector4(-0.39, 0.15, y + 0.13, y - 0.05), Vector4(-0.24, 0.29, y + 0.29, y - 0.06), Vector4(0.02, 0.34, y + 0.35, y - 0.06), Vector4(0.26, 0.28, y + 0.28, y - 0.05), Vector4(0.43, 0.13, y + 0.12, y - 0.04)], shell, "DomedCarapace")
			N.segment(parent, Vector3(0, y, -0.25), head_at + Vector3(0, 0, 0.05), 0.16, 0.14, 0.14, 0.13, mat)
			for i in range(7):
				var point = F.surface_point(shell_mesh, parent, Vector3(cos(i * TAU / 7) * 0.18, 2, sin(i * TAU / 7) * 0.23), Vector3.DOWN)
				if point is Vector3: G.shape(parent, point - Vector3.UP * 0.013, Vector3(0.22, 0.045, 0.2), pale, "plate")

	if form in ["deer", "goat", "antelope", "camel", "sheep", "hare", "rodent", "otter", "lizard", "manta"]:
		_tail(parent, rig, Vector3(0, y, size.z * 0.39), 0.15 if form == "hare" else 0.25 if form in ["sheep", "deer"] else 0.58 if form in ["otter", "lizard", "manta"] else 0.4, 0.14 if form in ["hare", "sheep", "otter"] else 0.07, mat, pale if form in ["hare", "deer"] else null)
	if form == "fish":
		var tail = _tail(parent, rig, Vector3(0, y, 0.25), 0.25, 0.075, mat)
		for side in [-1.0, 1.0]: G.shape(tail, Vector3(0, side * 0.11, 0.23), Vector3(0.04, 0.24, 0.21), pale, "ear", Vector3(side * 0.45, 0, 0))
		for side in [-1.0, 1.0]: G.shape(parent, Vector3(side * 0.18, y, -0.04), Vector3(0.28, 0.025, 0.19), pale, "body", Vector3(0, side * 0.4, 0))
	_wild_traits(parent, rig, id, mat, pale)
	_wild_anatomy(parent, rig, form, id, size, y, mat, pale, dark)
	_eyes(rig.head, head_size.x * 0.38, 0.045, -head_size.z * 0.24, 0.041 if form in ["moth", "bee", "bird"] else 0.066 if form == "frog" else 0.055)
	_finish(parent); wild_scenes[id] = _scene(parent, rig, {})
	return rig
static func _snail_shell(parent: Node3D, shell: Material, spiral: Material) -> void:
	var outer = G.shape(parent, Vector3(0, 0.4, 0.11), Vector3(0.54, 0.68, 0.68), shell, "skull")
	var faces = outer.mesh.get_faces()
	for side in [-1.0, 1.0]:
		var points = PackedVector3Array(); var radii = PackedFloat32Array()
		for i in range(16):


			var f = float(i) / 15; var angle = f * TAU * 1.7; var radius = 0.26 * (1.0 - f * 0.91)
			var origin = Vector3(side, 0.4 + cos(angle) * radius, 0.11 + sin(angle) * radius)
			var point = origin; var distance = INF


			for j in range(0, faces.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(origin, Vector3(-side, 0, 0), outer.transform * faces[j], outer.transform * faces[j + 1], outer.transform * faces[j + 2])
				if hit is Vector3 and origin.distance_to(hit) < distance: distance = origin.distance_to(hit); point = hit
			points.append(point + Vector3(side * 0.005, 0, 0)); radii.append(0.018 - 0.006 * f)
		F.tube(parent, points, radii, spiral, 5)
static func _coat_ring(parent: Node3D, skin: MeshInstance3D, y: float, z: float, material: Material, width: float) -> void:
	var points = PackedVector3Array(); var radii = PackedFloat32Array()
	for i in range(9):
		var normal = Vector3(cos(i * TAU / 8), sin(i * TAU / 8), 0)
		var hit = F.surface_point(skin, parent, Vector3(0, y, z) + normal, -normal)
		if hit is Vector3: points.append(hit + normal * 0.002); radii.append(width)
	if points.size() == 9: F.tube(parent, points, radii, material, 5)
static func _wild_anatomy(parent: Node3D, rig: Dictionary, form: String, id: String, size: Vector3, y: float, coat: Material, pale: Material, dark: Material) -> void:
	if form in ["goat", "antelope", "deer", "camel"]:
		for side in [-1.0, 1.0]:
			var normal = Vector3(side * 0.32, 0.25, -0.91).normalized()
			var point = F.surface_point(rig.head.get_child(0), rig.head, Vector3(side * 0.095, 0.102, -0.137) + normal * 0.3, -normal)
			assert(point is Vector3, "Brow must meet the actual skull")
			G.shape(rig.head, point - normal * 0.012, Vector3(0.13, 0.035, 0.15), pale, "feather", Vector3(0.12, 0, side * 0.18))
	elif form == "frog":
		G.shape(rig.head, Vector3(0, -0.084, -0.15), Vector3(0.37, 0.026, 0.11), dark, "muzzle")
		G.shape(parent, Vector3(0, y - 0.08, -0.17), Vector3(0.46, 0.24, 0.43), pale, "body")
		for side in [-1.0, 1.0]:
			for i in range(3): G.shape(parent, Vector3(side * (0.19 - i * 0.02), y + 0.06, 0.11 + i * 0.065), Vector3(0.06, 0.045, 0.07), pale, "plate")
	elif form == "lizard":
		G.shape(rig.head, Vector3(0, -0.07, -0.15), Vector3(0.24, 0.025, 0.22), dark, "muzzle")
		for side in [-1.0, 1.0]:
			F.tube(parent, PackedVector3Array([Vector3(side * 0.13, y + 0.03, -0.25), Vector3(side * 0.17, y + 0.04, 0), Vector3(side * 0.12, y + 0.02, 0.26)]), PackedFloat32Array([0.013, 0.018, 0.009]), pale, 5)
	elif form in ["bird", "crane"]:
		G.shape(parent, Vector3(0, y - 0.035, -0.2), Vector3(size.x * 0.78, size.y * 0.8, 0.25), pale, "chest")
		for side in [-1.0, 1.0]: G.shape(rig.head, Vector3(side * 0.077, 0.075, -0.1), Vector3(0.1, 0.026, 0.12), pale, "feather", Vector3(0.1, 0, side * 0.2))
	elif form in ["hopper", "beetle"]:
		for side in [-1.0, 1.0]:
			F.tube(rig.head, PackedVector3Array([Vector3(side * 0.07, 0.07, -0.06), Vector3(side * 0.16, 0.14, -0.19), Vector3(side * 0.19, 0.18, -0.28)]), PackedFloat32Array([0.01, 0.007, 0.003]), dark, 5)
	elif form == "fish":
		G.shape(parent, Vector3(0, y + 0.14, 0.05), Vector3(0.04, 0.19, 0.33), pale, "ear", Vector3(0.25, 0, 0))
		for side in [-1.0, 1.0]: G.shape(rig.head, Vector3(side * 0.095, 0, -0.03), Vector3(0.021, 0.17, 0.08), dark, "plate", Vector3(0.1, 0, 0))
	if id in ["cocoa_chipmunk", "caramel_dormouse"]:
		G.shape(parent, Vector3(0, y - 0.055, -0.14), Vector3(size.x * 0.62, size.y * 0.64, 0.24), pale, "chest")
static func _wild_traits(parent: Node3D, rig: Dictionary, id: String, mat: Material, pale: Material) -> void:
	match id:
		"riverglass_kingfisher":
			G.shape(rig.head, Vector3(0, 0.16, 0.015), Vector3(0.16, 0.23, 0.2), F.material("fur", Color("#48858f")), "ear", Vector3(0.3, 0, 0))
		"reedcrest_crane":
			for i in range(4): G.span(rig.head, Vector3(0, 0.12, 0.02), Vector3((i - 1.5) * 0.05, 0.4, 0.1), 0.018, 0.022, pale, "feather")
		"oasis_ibis": F.tube(rig.head, PackedVector3Array([Vector3(0, -0.04, -0.12), Vector3(0, -0.14, -0.38), Vector3(0, -0.28, -0.46)]), PackedFloat32Array([0.032, 0.024, 0.003]), F.material("bone", Color("#60503d")), 6)
		"ashen_raven":
			for i in range(4): G.shape(rig.head, Vector3((i - 1.5) * 0.04, 0.15, 0.04), Vector3(0.06, 0.21, 0.16), mat, "feather", Vector3(0.5, 0, 0))
		"ventwing_swift":
			for side in [-1.0, 1.0]: G.shape(rig.tails[0], Vector3(side * 0.06, 0, 0.25), Vector3(0.1, 0.035, 0.36), mat, "body", Vector3(0, side * 0.35, 0))
		"faceted_finch":
			for wing in rig.wings:
				for i in range(3): G.shape(wing, Vector3((-0.25 if wing.position.x < 0 else 0.25) * (1 + i * 0.45), 0.035, 0.05), Vector3(0.16, 0.06, 0.23), F.material("fur", Color(["#b7cbd3", "#baa1c8", "#c3ceb0"][i])), "feather", Vector3(PI * 0.5, 0, 0))
		"sugarwing_bee":
			for i in range(4): G.shape(parent, Vector3(0, 0.383, 0.0 + i * 0.065), Vector3(0.19 - i * 0.015, 0.19 - i * 0.017, 0.032), F.material("fur", Color("#74563b")))
		"graham_tortoise":
			for i in range(9):
				var x = (i % 3 - 1) * 0.15; var z = (i / 3 - 1) * 0.17
				var shell_mesh = parent.get_node("DomedCarapace")
				var point = F.surface_point(shell_mesh, parent, Vector3(x, 2, z + 0.03), Vector3.DOWN)
				if point is Vector3: G.shape(parent, point - Vector3.UP * 0.01, Vector3(0.14, 0.045, 0.16), F.material("bone", Color("#c69b61")), "plate")
		"cocoa_chipmunk", "caramel_dormouse":
			for side in [-1.0, 1.0]:
				var points = PackedVector3Array(); var radii = PackedFloat32Array()
				for i in range(9):
					var f = float(i) / 8; var point = Vector3(side * lerpf(0.1, 0.08, f), 1, lerpf(-0.15, 0.22, f))
					var hit = F.surface_point(parent.get_child(0), parent, point, Vector3.DOWN)
					assert(hit is Vector3, "Coat stripe must meet the actual back")
					points.append(hit - Vector3.UP * 0.00075); radii.append(lerpf(0.019, 0.012, f))
				F.tube(parent, points, radii, pale, 5)
		"dune_jerboa":
			for knee in rig.knees.slice(2): G.shape(knee, Vector3(0, -0.06, -0.045), Vector3(0.12, 0.09, 0.28), pale, "paw")
		"craghorn_goat": N.y_loft(rig.head, [Vector4(-0.38, 0.008, -0.15, -0.13), Vector4(-0.26, 0.045, -0.18, -0.08), Vector4(-0.12, 0.065, -0.15, -0.04)], pale, "GoatBeard")
		"goldmane_antelope":
			for i in range(6): G.shape(parent, Vector3(0, 1.14, 0.35 - i * 0.13), Vector3(0.12, 0.26, 0.17), F.material("fur", Color("#ba9a5c")), "ear", Vector3(0.25, 0, 0))
		"ember_salamander", "copperback_gecko", "sandshell_lizard":
			for i in range(7):
				var point = F.surface_point(parent.get_child(0), parent, Vector3(sin(i * 2.4) * 0.12, 1, 0.24 - i * 0.09), Vector3.DOWN)
				assert(point is Vector3, "Coat spot must meet the actual body")
				G.shape(parent, point - Vector3.UP * 0.012, Vector3(0.09, 0.04, 0.12), F.material("bone", Color("#d39a65" if id == "ember_salamander" else "#bdac79")), "plate")
		"amber_scarab": G.span(rig.head, Vector3(0, 0.04, -0.09), Vector3(0, 0.26, -0.28), 0.09, 0.1, F.material("bone", Color("#d2a966")), "ear")
		"geode_tortoise":
			for i in range(5): B.facet(parent, Vector3((i - 2) * 0.075, 0.66, 0), Vector3(0.11, 0.23 + sin(i) * 0.07, 0.15), F.material("crystal", Color("#bda8cf"), 0.1, 0.06))
		"quartz_hare":
			for ear in rig.ears:
				var skin: MeshInstance3D = ear.get_child(0)
				B.facet(ear, skin.transform * Vector3(0, 0.28, 0), Vector3(0.1, 0.18, 0.11), F.material("crystal", Color("#c4dedc"), 0.1, 0.06)).rotation = skin.rotation
		"opaline_otter":
			for side in [-1.0, 1.0]:
				for i in range(3): G.span(rig.head, Vector3(side * 0.08, -0.05, -0.21), Vector3(side * 0.29, -0.04 + i * 0.025, -0.27), 0.007, 0.007, pale)
static func enemy(e) -> void:
	var path = "res://assets/creatures/regional_enemy_" + e.species_id + ".scn"
	if not enemy_scenes.has(e.species_id) and ResourceLoader.exists(path): enemy_scenes[e.species_id] = load(path)
	if enemy_scenes.has(e.species_id):
		var data = Resources.attach_packed(e.model, enemy_scenes[e.species_id])
		for key in data.rig:
			if e.get(key) is Array: e.get(key).assign(data.rig[key])
			else: e.set(key, data.rig[key])
		for key in data.properties: e.set(key, data.properties[key])
		return
	_author_enemy(e)

static func _author_enemy(e) -> void:
	var form: String = e.profile.get("form", "golem"); var region: int = e.profile.get("region", 9)
	var color = Color(ENEMY_COATS.get(e.species_id, "#829080"))
	var family = "metal" if form == "knight" else "crystal" if region == 15 else "bark" if region in [9, 14] else "stone"
	var stone = F.material(family, color, 0.32 if form == "knight" else 0.12 if region == 15 else 0)


	var accent = F.material(family if form in ["knight", "golem"] else "bone", Color("#b5a47f"), stone.metallic if form in ["knight", "golem"] else 0.04)
	var dark = F.material(family, color.darkened(0.35), stone.metallic); var pale = F.material(family, color.lightened(0.19), stone.metallic)
	var tall = form in ["golem", "knight", "reaper", "wraith"]
	var insect_winged = form == "winged" and e.species_id in ["sugarspike_wasp", "veil_moth", "glasswing_reaver"]
	var harpy = e.species_id == "ash_harpy"
	var rig = {"head": null, "wings": [], "wing_meshes": [], "legs": [], "knees": [], "ears": [], "tails": [], "features": {}}
	var y = 1.1 if tall else 0.6
	if tall:
		Human.build(e, rig, form, stone, dark, pale, accent)
		Haunted.guardians(e, rig, stone, dark, pale)
	else:
		var body_size = Vector3(0.75, 0.66, 1.38)
		if form == "cat": body_size = Vector3(0.65, 0.57, 1.44)
		elif form in ["boar", "armored"]: body_size = Vector3(0.91, 0.76, 1.44)
		elif form in ["spider", "crawler", "scorpion"]: y = 0.44; body_size = Vector3(0.75, 0.49, 1.23)
		elif form == "frog": y = 0.42; body_size = Vector3(0.94, 0.67, 1.03)
		elif form == "winged": y = 0.62; body_size = Vector3(0.55, 0.65, 1.12)
		elif form == "wyrm": y = 0.42; body_size = Vector3(0.79, 0.68, 1.26)
		if insect_winged:
			body_size = Vector3(0.37, 0.37, 1.04); Animal.body(e.model, "bee", y, body_size, Vector3(0, y + 0.05, -0.6), stone)
		elif harpy:
			N.y_loft(e.model, [Vector4(0.43, 0.14, -0.13, 0.12), Vector4(0.6, 0.17, -0.16, 0.14), Vector4(0.8, 0.24, -0.19, 0.16), Vector4(0.94, 0.24, -0.14, 0.12), Vector4(1.0, 0.09, -0.08, 0.08)], stone, "HarpyTorso")
		else: Animal.beast_body(e.model, form, y, body_size, stone)
		var head_at = Vector3(0, y + 0.12, -0.65)
		if form in ["spider", "crawler", "scorpion"]: head_at = Vector3(0, y, -0.54)
		if harpy: head_at = Vector3(0, 1.065, -0.045)
		rig.head = _joint(e.model, head_at, "Head")
		if harpy: rig.head.scale = Vector3.ONE * 0.7; Human.face(rig.head, stone, pale, dark)
		else: Animal.beast_head(rig.head, "spider" if insect_winged else form, stone, pale, dark)
		if form in ["hound", "cat", "boar", "deer", "armored"]:
			if form in ["hound", "cat"]:
				for side in [-1.0, 1.0]:
					var tooth_root = Vector3(side * 0.12, -0.14, -0.32)
					if form == "cat":
						var jaw_hit = F.surface_point(rig.head.get_child(0), rig.head, Vector3(side * 0.1, -0.125, -1), Vector3.BACK)
						if jaw_hit is Vector3: tooth_root = jaw_hit + Vector3.BACK * 0.015
					N.segment(rig.head, tooth_root, tooth_root + Vector3(-side * 0.01, -0.095, -0.02), 0.032, 0.008, 0.035, 0.01, F.material(family, accent.albedo_color, stone.metallic))
			_ears(rig.head, rig, 0.2, 0.34 if form in ["hound", "deer"] else 0.25, stone, pale)
			_tail(e.model, rig, Vector3(0, y, 0.6), 0.64 if form in ["cat", "hound"] else 0.28, 0.15 if form == "hound" else 0.075, stone, pale if form == "cat" else null)
			if form == "deer": _horns(rig.head, accent, true, 0.64)
			if form == "boar":
				for side in [-1.0, 1.0]: F.tube(rig.head, PackedVector3Array([Vector3(side * 0.2, -0.15, -0.25), Vector3(side * 0.31, -0.1, -0.43), Vector3(side * 0.29, 0.1, -0.48)]), PackedFloat32Array([0.055, 0.045, 0.001]), accent, 7)
			if form == "armored":
				for row in range(5): G.shape(e.model, Vector3(0, y + 0.29, 0.51 - row * 0.22), Vector3(0.98, 0.2, 0.32), pale, "plate", Vector3(PI * 0.5, 0, 0))
		if form != "wyrm":
			var leg_count = 8 if form == "spider" else 6 if form in ["crawler", "scorpion"] or insect_winged else 2 if form == "winged" else 4
			var leg_root = _joint(e.model, Vector3(0, 0.32, 0), "InsectLegRoots") if insect_winged else e.model
			_legs(leg_root, rig, 0.2 if insect_winged else y - 0.1, 0.12 if harpy else body_size.x * 0.39, 0.2 if harpy else body_size.z * 0.86, stone, dark, "insect" if leg_count > 4 else "bird" if form == "winged" else "bound" if form == "frog" else "hoof" if form in ["deer", "boar"] else "paw", leg_count)
			e.feet.assign(rig.legs); e.knees.assign(rig.knees)
		if form in ["spider", "crawler", "scorpion"]:
			for side in [-1.0, 1.0]:
				G.span(rig.head, Vector3(side * 0.15, -0.07, -0.2), Vector3(side * 0.27, -0.19, -0.43), 0.11, 0.1, accent)
				G.span(rig.head, Vector3(side * 0.27, -0.19, -0.43), Vector3(side * 0.14, -0.19, -0.51), 0.065, 0.065, accent)
		if form == "scorpion":
			var tail = _tail(e.model, rig, Vector3(0, y, 0.75), 0.8, 0.16, stone)
			tail.rotation.x = -1.35
			F.tube(tail, PackedVector3Array([Vector3(0, 0, 0.35), Vector3(0, -0.1, 0.8), Vector3(0, -0.4, 0.95), Vector3(0, -0.62, 0.7)]), PackedFloat32Array([0.1, 0.085, 0.06, 0.001]), accent, 7)
		if form == "wyrm":
			var previous = e.model
			for i in range(7):
				var segment = _joint(previous, Vector3(0, y, 0.53) if i == 0 else Vector3(0, -0.025, 0.33), "Tail" if i == 0 else "TailSegment")
				rig.tails.append(segment); G.shape(segment, Vector3(0, 0, 0.15), Vector3(0.72 - i * 0.075, 0.62 - i * 0.065, 0.55), stone, "body")
				G.shape(segment, Vector3(0, 0.27 - i * 0.025, 0.14), Vector3(0.16, 0.24, 0.24), accent, "ear", Vector3(0.5, 0, 0)); previous = segment
		if form == "frog":
			N.z_loft(rig.head, [Vector4(-0.3, 0.25, -0.14, -0.18), Vector4(-0.05, 0.37, -0.19, -0.24), Vector4(0.12, 0.24, -0.16, -0.19)], accent, "AmphibianJaw")
			for side in [-1.0, 1.0]: G.shape(e.model, Vector3(side * 0.42, 0.28, 0.32), Vector3(0.42, 0.44, 0.58), stone, "chest")
		if form == "mimic":
			var jaw = _joint(rig.head, Vector3(0, -0.16, -0.14), "Jaw"); rig.features.jaw = jaw
			N.z_loft(jaw, [Vector4(-0.43, 0.25, 0.025, -0.12), Vector4(-0.21, 0.35, 0.045, -0.17), Vector4(0.12, 0.23, 0.015, -0.13)], pale, "HingedMandible")
			N.z_loft(rig.head, [Vector4(-0.37, 0.22, -0.025, -0.13), Vector4(-0.24, 0.3, -0.02, -0.16)], dark, "MouthCavity")
			for i in range(7): N.segment(jaw, Vector3((i - 3) * 0.082, 0.015, -0.33), Vector3((i - 3) * 0.08, 0.125, -0.34), 0.055, 0.008, 0.055, 0.009, accent)
		if form == "winged":
			for side in [-1.0, 1.0]:
				var wing = _joint(e.model, Vector3(side * 0.09, y + 0.1, -0.2) if insect_winged else Vector3(side * 0.23, y + 0.23, 0.1), "Wing"); rig.wings.append(wing)
				G.wing(wing, side, "moth" if e.species_id == "veil_moth" else "bee" if e.species_id == "sugarspike_wasp" else "manta" if e.species_id == "glasswing_reaver" else "bird", pale).scale = Vector3(1.35, 1, 1.35)
				for i in range(4): N.segment(wing, Vector3.ZERO, Vector3(side * (0.35 + i * 0.16), -0.017, 0.15 + i * 0.05), 0.022 if insect_winged else 0.055, 0.009 if insect_winged else 0.03, 0.022 if insect_winged else 0.07, 0.009 if insect_winged else 0.025, stone)
				if harpy:
					for i in range(6): G.shape(wing, Vector3(side * (0.3 + i * 0.14), -0.008, 0.2 + i * 0.018), Vector3(0.17, 0.43, 0.035), stone, "feather", Vector3(PI * 0.5, 0, -side * 0.18))
			_tail(e.model, rig, Vector3(0, y, 0.13 if harpy else 0.45), 0.28 if harpy else 0.18 if insect_winged and e.species_id != "sugarspike_wasp" else 0.6, 0.1, stone)
	e.head = rig.head
	var core_at = Vector3(0, y + 0.13, -0.2 if form == "reaper" else -0.34)
	if tall or form == "winged":
		var chest_surface = e.model.get_child(0)
		if rig.features.has("design"): chest_surface = rig.features.design.get_child(0)
		var chest_hit = F.surface_point(chest_surface, e.model, Vector3(0, core_at.y, -2), Vector3.BACK)
		if chest_hit is Vector3: core_at = chest_hit + Vector3.FORWARD * 0.035
	e.core = G.shape(e.model, core_at, Vector3(0.15 if form == "reaper" else 0.19, 0.25, 0.13), e.normal_glow, "plate"); e.core.add_to_group("batch_dynamic")
	if form == "wraith":
		for i in range(7):
			var strip = _joint(e.model, Vector3(cos(i * TAU / 7) * 0.24, 0.85, sin(i * TAU / 7) * 0.17), "SpectralHem"); rig.tails.append(strip)
			G.shape(strip, Vector3(0, -0.39, 0), Vector3(0.19, 0.92, 0.13), stone, "ear", Vector3(0.13 * sin(i), 0, 0.12 * cos(i)))
	if e.profile.get("boss", false):
		for i in range(5): G.shape(e.head, Vector3(cos(i * TAU / 5) * 0.22, 0.35, sin(i * TAU / 5) * 0.18), Vector3(0.1, 0.34, 0.11), accent, "ear")
		e.rest_scale = Vector3.ONE * 1.2
	e.visual_rig = rig
	if e.species_id not in ["cliffwarden", "root_reaper", "shard_sentinel"]:
		_enemy_traits(e, stone, accent, y)
		_enemy_anatomy(e, form, y, stone, dark, pale, F.material(family, accent.albedo_color, stone.metallic))
	Haunted.haunted(e, rig, stone, dark, pale)
	if form != "knight":
		if tall or harpy: F.eyes(e.head, 0.104, 0.048, -0.15, 0.052, F.material(family, Color("#b49a65"), stone.metallic), family, stone.metallic, 0.22)
		else: _eyes(e.head, 0.14, 0.072, -0.13, 0.05 if form in ["hound", "cat", "boar", "deer", "armored"] else 0.064, family, stone.metallic)
	e.leaves.append_array(rig.wings); e.leaves.append_array(rig.tails)
	e.visual_rig = rig
	e.model.set_meta("anatomy", form); e.model.set_meta("species", e.species_id)
	_finish(e.model)
	var bindings = {"head": e.head, "core": e.core, "arms": e.arms, "forearms": e.forearms, "feet": e.feet, "knees": e.knees, "leaves": e.leaves, "visual_rig": rig}
	enemy_scenes[e.species_id] = _scene(e.model, bindings, {"rest_scale": e.rest_scale})
static func _enemy_anatomy(e, form: String, y: float, coat: Material, dark: Material, pale: Material, bone: Material) -> void:
	if form in ["hound", "cat", "boar", "armored", "deer"]:


		for side in [-1.0, 1.0]:
			var normal = Vector3(side * 0.35, 0.22, -0.91).normalized()
			var hit = F.surface_point(e.head.get_child(0), e.head, Vector3(side * 0.16, 0.13, -0.12) + normal * 0.5, -normal)
			if hit is Vector3: G.shape(e.head, hit - normal * 0.018, Vector3(0.16, 0.045, 0.19), pale, "plate", Vector3(0.2, 0, side * 0.2))
			if form in ["hound", "cat"]: G.shape(e.head, Vector3(side * 0.19, -0.09, 0.02), Vector3(0.18, 0.3, 0.24), coat, "ear", Vector3(0.2, 0, side * 0.42 + PI))
	elif form == "wyrm":
		G.shape(e.head, Vector3(0, -0.12, -0.24), Vector3(0.48, 0.19, 0.4), dark, "muzzle")
		G.shape(e.head, Vector3(0, -0.2, -0.21), Vector3(0.46, 0.1, 0.41), pale, "muzzle")
		for side in [-1.0, 1.0]:
			for i in range(3): G.span(e.head, Vector3(side * (0.17 - i * 0.045), -0.09, -0.33 - i * 0.018), Vector3(side * (0.16 - i * 0.045), -0.19, -0.34 - i * 0.018), 0.034, 0.04, bone, "ear")
	elif form == "reaper":
		for side in [-1.0, 1.0]:
			F.tube(e.model, PackedVector3Array([Vector3(side * 0.17, 0.73, -0.15), Vector3(side * 0.22, 1.03, -0.2), Vector3(side * 0.18, 1.36, -0.15), Vector3(side * 0.11, 1.54, -0.05)]), PackedFloat32Array([0.045, 0.06, 0.05, 0.025]), pale, 6)

	elif form in ["knight", "golem"]:
		for side in [-1.0, 1.0]:
			var plate = N.y_loft(e.model, [Vector4(1.15, 0.1, -0.224, -0.145), Vector4(1.32, 0.14, -0.245, -0.15), Vector4(1.43, 0.14, -0.18, -0.1)], pale, "PectoralPlate")
			plate.position.x = side * 0.18
	elif form == "winged":
		if e.species_id == "kiteclaw_raptor":
			F.tube(e.head, PackedVector3Array([Vector3(0, -0.04, -0.2), Vector3(0, -0.09, -0.43), Vector3(0, -0.21, -0.47)]), PackedFloat32Array([0.12, 0.07, 0.008]), bone, 6)
		elif e.species_id != "ash_harpy":
			for side in [-1.0, 1.0]: F.tube(e.head, PackedVector3Array([Vector3(side * 0.13, 0.14, -0.02), Vector3(side * 0.19, 0.34, -0.1), Vector3(side * 0.27, 0.39, -0.19)]), PackedFloat32Array([0.022, 0.014, 0.005]), dark, 5)
	elif form == "mimic" and e.species_id == "geode_mimic":
		for side in [-1.0, 1.0]:
			for i in range(3): B.facet(e.model, Vector3(side * 0.3, y + 0.22, 0.48 - i * 0.28), Vector3(0.35, 0.41, 0.4), pale).rotation.z = -side * 0.35
	if e.species_id == "glass_anubid":
		for ear in e.visual_rig.ears: ear.scale = Vector3(0.85, 1.35, 1.0)
		for i in range(5): G.shape(e.model, Vector3((i - 2) * 0.11, y - 0.02, -0.51), Vector3(0.1, 0.2, 0.08), bone, "plate", Vector3(0, 0, (i - 2) * 0.15))
static func _enemy_traits(e, stone: Material, accent: Material, y: float) -> void:
	match e.species_id:
		"cliffwarden":
			for i in range(2): B.facet(e.arms[i], Vector3(-0.02 if i == 0 else 0.02, 0, 0), Vector3(0.46, 0.39, 0.43), stone)
		"cola_sloshback":
			# A glossy amber bubble throat, fizz on its back and darker spots.
			var sac := F.material("crystal", Color("#d9863a"), 0.15, 0.12)
			var fizz := F.material("crystal", Color("#f7e6c6"), 0.1, 0.08)
			var spot := F.material("bark", Color("#4b2717"))
			B.ball(e.head, Vector3(0, -0.2, -0.1), Vector3(0.44, 0.3, 0.36), sac)
			var rng := RandomNumberGenerator.new(); rng.seed = 7
			for i in range(14):
				var at := Vector3(rng.randf_range(-0.38, 0.38), 2.0, rng.randf_range(-0.35, 0.45))
				var hit = F.surface_point(e.model.get_child(0), e.model, at, Vector3.DOWN)
				if not hit is Vector3: continue
				if i < 9: B.ball(e.model, hit + Vector3.UP * 0.02, Vector3.ONE * rng.randf_range(0.06, 0.11), fizz)
				else: G.shape(e.model, hit + Vector3.UP * 0.005, Vector3(0.16, 0.03, 0.14), spot, "plate")
		"fudge_golem":
			# Melting fudge: chocolate drips from the shoulders and head, sprinkles, a cherry.
			var fudge := F.material("crystal", Color("#4a2a1b"), 0.1, 0.0)
			var cherry := F.material("crystal", Color("#c3202d"), 0.1, 0.1)
			var colors := ["#f2c94c", "#eb5757", "#6fcf97", "#56ccf2", "#f2f2f2"]
			for k in range(9):
				var x := -0.42 + k * 0.105
				var hit = F.surface_point(e.model.get_child(0), e.model, Vector3(x, 3.0, -0.05), Vector3.DOWN)
				if hit is Vector3 and hit.y > 1.0:
					var drop := 0.12 + 0.12 * absf(sin(k * 1.7))
					F.tube(e.model, PackedVector3Array([hit + Vector3(0, 0.02, -0.12), hit + Vector3(0, -drop * 0.6, -0.17), hit + Vector3(0, -drop, -0.17)]), PackedFloat32Array([0.07, 0.04, 0.05]), fudge, 6)
					var sprinkle := B.box(e.model, hit + Vector3(0.03, 0.03, 0.04), Vector3(0.07, 0.02, 0.02), F.material("cloth", Color(colors[k % colors.size()])))
					sprinkle.rotation.y = k * 1.1
			var top = F.surface_point(e.head.get_child(0), e.head, Vector3(0, 3.0, 0), Vector3.DOWN)
			if top is Vector3:
				B.ball(e.head, top + Vector3(0, 0.07, 0), Vector3.ONE * 0.14, cherry)
				N.segment(e.head, top + Vector3(0, 0.13, 0), top + Vector3(0.05, 0.25, 0.03), 0.015, 0.01, 0.015, 0.01, F.material("bark", Color("#5b7a2e")))
				F.tube(e.head, PackedVector3Array([top + Vector3(-0.1, 0.0, -0.08), top + Vector3(-0.12, -0.12, -0.12), top + Vector3(-0.12, -0.2, -0.12)]), PackedFloat32Array([0.05, 0.03, 0.04]), fudge, 6)
			for row in range(3):
				for side in [-1, 1]:
					var hit = F.surface_point(e.model.get_child(0), e.model, Vector3(side * 0.145, 0.84 + row * 0.24, -2), Vector3.BACK)
					if hit is Vector3: F.beveled_box(e.model, hit + Vector3.FORWARD * 0.012, Vector3(0.23, 0.19, 0.07), F.material("stone", Color("#84533f")))
		"grassland_colossus":
			for i in range(12):
				var normal = Vector3(cos(i * 2.4), 0, sin(i * 2.4)); var origin = Vector3(normal.x * 0.8, 1.24 + sin(i) * 0.12, normal.z * 0.8)
				var hit = F.surface_point(e.model.get_child(0), e.model, origin, -normal)
				if hit is Vector3: N.segment(e.model, hit - normal * 0.025, hit + Vector3.UP * (0.2 + 0.13 * sin(i)) + normal * 0.09, 0.1, 0.015, 0.08, 0.012, F.material("bark", Color("#94a36d")))
		"wrapper_mimic":
			# A wrapped sweet: a foil-striped body with twisted, pleated ends.
			var foil := F.material("bone", Color("#e2bf72"), 0.35)
			var paper := F.material("cloth", Color("#d4708a"))
			var stripe := F.material("cloth", Color("#fff1e2"))
			F.beveled_box(e.model, Vector3(0, y + 0.1, 0), Vector3(1.1, 0.85, 1.2), foil)
			for i in range(3): F.beveled_box(e.model, Vector3(0, y + 0.1, -0.4 + i * 0.4), Vector3(1.13, 0.88, 0.12), stripe)
			for side in [-1.0, 1.0]:
				F.tube(e.model, PackedVector3Array([Vector3(side * 0.5, y + 0.12, 0), Vector3(side * 0.74, y + 0.14, 0), Vector3(side * 0.86, y + 0.16, 0), Vector3(side * 1.2, y + 0.2, 0)]), PackedFloat32Array([0.4, 0.09, 0.08, 0.44]), paper, 10)
				for k in range(6):
					var a := TAU * k / 6.0
					N.segment(e.model, Vector3(side * 0.88, y + 0.16, 0), Vector3(side * 1.2, y + 0.2 + sin(a) * 0.4, cos(a) * 0.4), 0.05, 0.02, 0.05, 0.02, stripe)
		"furnace_hound":
			for i in range(5):
				var hit = F.surface_point(e.model.get_child(0), e.model, Vector3(0, 2, 0.48 - i * 0.22), Vector3.DOWN)
				if hit is Vector3: N.y_loft(e.model, [Vector4(hit.y - 0.035, 0.09, hit.z - 0.08, hit.z + 0.08), Vector4(hit.y + 0.15, 0.065, hit.z - 0.06, hit.z + 0.06), Vector4(hit.y + 0.27, 0.008, hit.z - 0.015, hit.z + 0.015)], F.material("stone", Color("#c88858"), 0, 0.18), "FurnaceSpine")
		"hollow_hound":
			for side in [-1, 1]:
				for i in range(6): B.branch(e.model, Vector3(side * 0.28, 0.92, 0.5 - i * 0.15), Vector3(side * 0.4, 0.35, 0.5 - i * 0.15), 0.025, B.mat("#a49daa"), 1)
		"thistle_jackal", "windwhistle_stalker":
			for i in range(12):
				var normal = Vector3(cos(i * TAU / 12), sin(i * TAU / 12), 0)
				var hit = F.surface_point(e.head.get_child(0), e.head, Vector3(0, 0, 0.08) + normal * 0.8, -normal)
				if hit is Vector3: N.segment(e.head, hit - normal * 0.015, hit + normal * 0.2 + Vector3(0, 0, 0.035), 0.085, 0.008, 0.095, 0.008, F.material("stone", Color("#9aa174")))
		"prismstalker":
			for side in [-1, 1]:
				var hit = F.surface_point(e.head.get_child(0), e.head, Vector3(side * 0.12, 1, 0.03), Vector3.DOWN)
				if hit is Vector3: N.segment(e.head, hit - Vector3.UP * 0.025, hit + Vector3(side * 0.08, 0.3, 0.06), 0.13, 0.008, 0.13, 0.008, F.material("crystal", Color("#bbc8dd"), 0.25, 0.09)).name = "RootedPrism"
		"stonejaw_wyrm", "resonance_wyrm":
			var crystal: bool = e.species_id == "resonance_wyrm"
			var ridge := F.material("crystal", Color("#b9c8f2"), 0.2, 0.35) if crystal else F.material("stone", Color("#7d7a6c"))
			var moss := F.material("bark", Color("#6f8a45"))
			for i in range(e.visual_rig.tails.size()):
				var segment: Node3D = e.visual_rig.tails[i]
				F.ring(segment, Vector3(0, 0, 0.15), 0.3 - i * 0.031, 0.035, accent).rotation.x = PI * 0.5
				var shrink := 1.0 - i * 0.1
				if crystal:
					for side in [-1.0, 1.0]: B.facet(segment, Vector3(side * 0.17 * shrink, 0.32 - i * 0.03, 0.12), Vector3(0.14, 0.48, 0.14) * shrink, ridge).rotation.z = -side * 0.45
				else:
					B.facet(segment, Vector3(0, 0.3 - i * 0.03, 0.1), Vector3(0.34, 0.2, 0.34) * shrink, ridge).rotation.y = i * 0.7
					if i % 2 == 0: G.shape(segment, Vector3(0.1, 0.27 - i * 0.03, 0.25), Vector3(0.22, 0.05, 0.2) * shrink, moss, "plate")
			if not crystal:
				for side in [-1.0, 1.0]: B.facet(e.head, Vector3(side * 0.22, 0.12, 0.02), Vector3(0.24, 0.2, 0.3), ridge).rotation.z = side * 0.4
		"dune_maw":
			# A sandworm's round mouth, ringed with teeth, and rough sand plates down its back.
			var throat := F.material("stone", Color("#3a2218"))
			var tooth := F.material("bone", Color("#efe2c4"))
			var plate := F.material("stone", Color("#c9a56f"))
			var mouth := B.cyl(e.head, Vector3(0, -0.06, -0.42), 0.19, 0.06, throat); mouth.rotation.x = PI * 0.5
			for k in range(12):
				var a := TAU * k / 12.0
				var rim := Vector3(cos(a) * 0.21, -0.06 + sin(a) * 0.19, -0.42)
				N.segment(e.head, rim, rim * Vector3(0.45, 1.0, 1.0) + Vector3(0, -0.06 * (1.0 - 0.45), -0.12) + Vector3(0, sin(a) * -0.1, 0), 0.05, 0.008, 0.05, 0.008, tooth)
			F.ring(e.head, Vector3(0, -0.06, -0.4), 0.24, 0.05, plate).rotation.x = PI * 0.5
			for i in range(e.visual_rig.tails.size()):
				var segment: Node3D = e.visual_rig.tails[i]
				var shrink := 1.0 - i * 0.09
				for side in [-1.0, 0.0, 1.0]:
					B.facet(segment, Vector3(side * 0.18 * shrink, (0.27 - i * 0.025) - absf(side) * 0.05, 0.12), Vector3(0.22, 0.12, 0.28) * shrink, plate).rotation.z = side * 0.5
		"sunken_sentinel":
			B.branch(e.forearms[0], Vector3(0, 0.5, 0), Vector3(0, -1, -0.25), 0.045, accent, 1); B.facet(e.forearms[0], Vector3(0, 0.8, 0), Vector3(0.18, 0.5, 0.18), accent)
		"mourning_knight": N.y_loft(e.model, [Vector4(0.34, 0.34, 0.32, 0.36), Vector4(0.73, 0.35, 0.3, 0.34), Vector4(1.13, 0.31, 0.25, 0.29), Vector4(1.46, 0.27, 0.13, 0.17)], F.material("cloth", Color("#776184")), "MourningMantle")
		"shard_sentinel":
			for i in range(2): B.facet(e.arms[i], Vector3(-0.03 if i == 0 else 0.03, 0.12, 0), Vector3(0.38, 0.62, 0.39), F.material("crystal", Color("#a6b6d2"), 0.1, 0.12))
			F.beveled_box(e.forearms[0], Vector3(0, -0.5, -0.2), Vector3(0.6, 0.35, 0.5), accent)
		"pale_watcher": N.y_loft(e.head, [Vector4(-0.24, 0.075, -0.2, -0.13), Vector4(-0.15, 0.15, -0.24, -0.13), Vector4(0.04, 0.19, -0.25, -0.12), Vector4(0.23, 0.12, -0.19, -0.1)], F.material("bark", Color("#d0c9bf")), "WatchersMask")
		"sandwraith":
			for i in range(3): B.ring(e.model, Vector3(0, 0.2 + i * 0.25, 0), 0.3 + i * 0.12, 0.045, B.mat("#baa07a"))
		"slag_crawler":
			for i in range(4): B.cyl(e.model, Vector3((i - 1.5) * 0.2, 0.79, 0.1), 0.085, 0.45, F.material("stone", Color("#6f6662"))); B.cyl(e.model, Vector3((i - 1.5) * 0.2, 1.02, 0.1), 0.06, 0.02, F.material("stone", Color("#bd8b60"), 0, 0.1))
		"grave_creeper":
			for side in [-1, 1]: B.branch(e.model, Vector3(side * 0.2, 0.7, 0), Vector3(side * 1.3, 0.1, 0.9), 0.07, stone, 0.2)
		"sugarspike_wasp":
			for i in range(3): _coat_ring(e.model, e.model.get_child(0), y, 0.1 + i * 0.11, F.material("bone", Color("#c5a262")), 0.012)
		"kiteclaw_raptor":
			B.branch(e.model, Vector3(0, 0.7, 0.6), Vector3(0, 0.4, 1.8), 0.17, stone, 0.1)
			for foot in e.knees:
				for i in range(3): B.facet(foot, Vector3((i - 1) * 0.09, -0.2, -0.35), Vector3(0.07, 0.1, 0.35), accent)
		"ash_harpy":
			for i in range(7):
				var hit = F.surface_point(e.head.get_child(0), e.head, Vector3((i - 3) * 0.042, 1, 0.02), Vector3.DOWN)
				if hit is Vector3: N.segment(e.head, hit - Vector3.UP * 0.02, hit + Vector3((i - 3) * 0.026, 0.24, 0.12), 0.075, 0.008, 0.1, 0.008, stone)
		"veil_moth":
			for i in range(e.visual_rig.wings.size()):
				var side = -1.0 if i == 0 else 1.0; var wing = e.visual_rig.wings[i]
				G.shape(wing, Vector3(side * 0.62, 0.036, -0.17), Vector3(0.27, 0.024, 0.28), F.material("bark", Color("#d8c2c9")), "body")
				G.shape(wing, Vector3(side * 0.62, 0.049, -0.17), Vector3(0.14, 0.018, 0.16), F.material("bark", Color("#4b485b")), "body")
		"glasswing_reaver":
			for i in range(e.visual_rig.wings.size()):
				var side = -1.0 if i == 0 else 1.0
				B.facet(e.visual_rig.wings[i], Vector3(side * 0.73, 0.035, 0.1), Vector3(0.82, 0.09, 0.36), F.material("crystal", Color("#b3c5d7"), 0.2, 0.1)).rotation.y = -side * 0.2
