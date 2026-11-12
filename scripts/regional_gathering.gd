extends RefCounted
## Regional resources out in the land: two per region, found in patches beside the roads.
## Walk up and gather; a gathered patch grows back after a while (10 minutes of journey
## time). Each patch is small and only drawn up close, so they cost little.
##
## The same models are used for the item icons (see art()).

const B = preload("res://scripts/build.gd")
const A = preload("res://scripts/imported_assets.gd")
const Catalog = preload("res://scripts/crafting.gd")

const RESOURCES := {
	9: ["mossbloom", "oak_resin"], 10: ["cocoa_pod", "sugar_crystal"], 11: ["wheat_sheaf", "wind_feather"],
	12: ["sunstone", "cactus_fruit"], 13: ["obsidian", "ember_ore"], 14: ["ghost_lily", "grave_silver"], 15: ["prism_shard", "glow_moss"],
}
const PER_RESOURCE := 14
const REGROW := 600.0
const VISIBLE := 70.0

var game
var nodes: Dictionary = {}   # id -> Node3D
var _clock := 0.0


func setup(owner_game) -> void:
	game = owner_game
	var atlas = game.world.get("atlas")
	if atlas == null: return
	var rng := RandomNumberGenerator.new(); rng.seed = 7301
	var roads_by_region := {}
	for road in atlas.roads():
		var region: int = atlas.region_at((road.a + road.b) * 0.5)
		if not RESOURCES.has(region): continue
		if not roads_by_region.has(region): roads_by_region[region] = []
		roads_by_region[region].append(road)
	for region in RESOURCES:
		var roads: Array = roads_by_region.get(region, [])
		if roads.is_empty(): continue
		for resource in RESOURCES[region]:
			var placed := 0
			for attempt in range(PER_RESOURCE * 4):
				if placed >= PER_RESOURCE: break
				var road: Dictionary = roads[rng.randi() % roads.size()]
				var along: Vector2 = road.a.lerp(road.b, rng.randf_range(0.1, 0.9))
				var side: Vector2 = (road.b - road.a).normalized().orthogonal() * (rng.randf_range(7.0, 22.0) * (1.0 if rng.randf() < 0.5 else -1.0))
				var p: Vector2 = along + side
				if atlas.region_at(p) != region or atlas.reserved(p, 2.5): continue
				var height: float = game.world.surface_height_at(p.x, p.y)
				if height <= game.world.water_level + 0.8 or not preload("res://scripts/water_profile.gd").sample(p).is_empty(): continue
				if absf(game.world.surface_height_at(p.x + 0.8, p.y) - height) > 0.6: continue
				var id := "gather_%s_%d" % [resource, placed]
				_build(id, resource, Vector3(p.x, height, p.y), rng.randf() * TAU)
				placed += 1
	_refresh()


func _build(id: String, resource: String, point: Vector3, yaw: float) -> void:
	var node := Node3D.new(); node.name = id; node.position = point; node.rotation.y = yaw
	node.set_meta("id", id); node.set_meta("kind", "gather"); node.set_meta("resource", resource)
	node.set_meta("label", "Gather " + Catalog.item_name(resource).to_lower())
	node.add_to_group("interactable")
	game.world.add_child(node)
	art(node, resource)
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		child.visibility_range_end = VISIBLE
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodes[id] = node


static func _tinted(node: Node3D, color: Color, glow: float = 0.0) -> void:
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.5
	if glow > 0.0: material.emission_enabled = true; material.emission = color; material.emission_energy_multiplier = glow
	for mesh in node.find_children("*", "MeshInstance3D", true, false): mesh.material_override = material


## The look of every new item, as a small model sitting on the ground at the origin.
static func art(parent: Node3D, id: String) -> void:
	var crystal := func (color: Color, size: float, glow: float = 0.3):
		var c := A.place(parent, "zappy_crystal", Vector3.ZERO, size); if c: _tinted(c, color, glow)
	match id:
		"mossbloom": A.place(parent, "qnat_flower_3_group", Vector3.ZERO, 0.55)
		"oak_resin":
			A.place(parent, "terrain_mdvl_nature_log_01", Vector3.ZERO, 0.35)
			crystal.call(Color("#d98c2b"), 0.32, 0.15)
		"cocoa_pod":
			var bush := A.place(parent, "qnat_bush_common", Vector3.ZERO, 0.6); if bush: _tinted(bush, Color("#4f6b32"))
			for i in range(3): B.ball(parent, Vector3(cos(i * 2.1) * 0.34, 0.3 + i * 0.06, sin(i * 2.1) * 0.34), Vector3(0.17, 0.26, 0.17), B.mat("#7b4526"))
		"sugar_crystal": crystal.call(Color("#f8d8ef"), 0.45, 0.25)
		"wheat_sheaf":
			var stalk := B.mat("#c9a24e"); var ear := B.mat("#e8c46a")
			for i in range(9):
				var lean := Vector3(cos(i * 2.4), 0, sin(i * 2.4)) * (0.03 + (i % 3) * 0.03)
				var piece := B.cyl(parent, Vector3(lean.x, 0.32, lean.z), 0.012, 0.64, stalk); piece.rotation = Vector3(lean.z * 2.5, 0, -lean.x * 2.5)
				B.ball(parent, Vector3(lean.x * 2.4, 0.68, lean.z * 2.4), Vector3(0.05, 0.14, 0.05), ear)
			B.cyl(parent, Vector3(0, 0.3, 0), 0.07, 0.05, B.mat("#8a5a32"))
		"wind_feather":
			var vane := B.ball(parent, Vector3(-0.02, 0.37, 0), Vector3(0.1, 0.5, 0.2), B.mat("#e8f2ff")); vane.rotation.z = 0.6
			var tip := B.ball(parent, Vector3(-0.15, 0.56, 0), Vector3(0.07, 0.16, 0.14), B.mat("#7aa7d8")); tip.rotation.z = 0.6
			var quill := B.box(parent, Vector3(0.2, 0.05, 0), Vector3(0.025, 0.22, 0.025), B.mat("#c9a35e")); quill.rotation.z = 0.6
		"sunstone":
			A.place(parent, "u29_survival_rock_sand_a", Vector3.ZERO, 0.3)
			crystal.call(Color("#ffb43a"), 0.38, 0.6)
		"cactus_fruit":
			var cactus := A.place(parent, "u29_nature_cactus_short", Vector3.ZERO, 0.8); if cactus: _tinted(cactus, Color("#5f9e4a"))
			for i in range(3): B.ball(parent, Vector3(cos(i * 2.0) * 0.16, 0.62 + i * 0.07, sin(i * 2.0) * 0.16), Vector3(0.1, 0.12, 0.1), B.mat("#e2557a"))
		"obsidian":
			var shard := A.place(parent, "nature_rock_04", Vector3.ZERO, 0.55); if shard: _tinted(shard, Color("#3a2f4f"), 0.05)
			for i in range(3): var spike := B.facet(parent, Vector3(cos(i * 2.1) * 0.25, 0.42, sin(i * 2.1) * 0.25), Vector3(0.12, 0.35, 0.12), B.mat("#4b3d66", 0.6)); spike.rotation.z = (i - 1) * 0.4
		"ember_ore":
			var ore := A.place(parent, "u29_survival_resource_stone", Vector3.ZERO, 0.55); if ore: _tinted(ore, Color("#5a2a1e"))
			for i in range(5): B.facet(parent, Vector3(cos(i * 1.3 + 0.4) * 0.3, 0.3 + (i % 2) * 0.12, sin(i * 1.3 + 0.4) * 0.3), Vector3(0.13, 0.13, 0.13), B.mat("#ff8a2a", 0.0, 1.4))
		"ghost_lily":
			var lily := A.place(parent, "u29_nature_flower_purplea", Vector3.ZERO, 0.6); if lily: _tinted(lily, Color("#c9f0ff"), 0.2)
		"grave_silver":
			var stone := A.place(parent, "nature_rock_02", Vector3.ZERO, 0.4); if stone: _tinted(stone, Color("#6d7180"))
			var bar := A.place(parent, "resource_iron_bar", Vector3(0, 0.12, 0), 0.12); if bar: _tinted(bar, Color("#dfe6f2"))
		"prism_shard": crystal.call(Color("#b48cff"), 0.5, 0.45)
		"glow_moss":
			var moss := A.place(parent, "terrain_mdvl_nature_rock_mossy_01", Vector3.ZERO, 0.5); if moss: _tinted(moss, Color("#5fd7a8"), 0.35)
		# Gear and treats (icons only).
		"iron_axe":
			var a := A.place(parent, "weapons_bearded_axe", Vector3.ZERO, 0.9)
			if a: _tinted(a, Color("#9aa3ad"))
		"iron_pickaxe":
			A.place(parent, "kaykit_pickaxe", Vector3.ZERO, 0.9)
		"obsidian_blade":
			var a := A.place(parent, "weapons_offset_sword", Vector3.ZERO, 1.0)
			if a: _tinted(a, Color("#2d2638"), 0.05)
		"sunsteel_sword":
			var a := A.place(parent, "weapons_arming_sword", Vector3.ZERO, 1.0)
			if a: _tinted(a, Color("#f0c55a"), 0.2)
		"prism_saber":
			var a := A.place(parent, "weapons_great_sword", Vector3.ZERO, 1.0)
			if a: _tinted(a, Color("#b48cff"), 0.35)
		"iron_shield":
			var a := A.place(parent, "rpg_shield_01", Vector3.ZERO, 0.8)
			if a: _tinted(a, Color("#8f98a5"))
		"ember_mail":
			B.beveled_box(parent, Vector3(0, 0.35, 0), Vector3(0.55, 0.65, 0.3), B.mat("#6b3424"))
			for y in [0.2, 0.38, 0.56]: B.box(parent, Vector3(0, y, 0.16), Vector3(0.5, 0.05, 0.02), B.mat("#ff8a2a", 0.0, 0.8))
		"grave_cloak":
			var cloth := B.mat("#3b3550")
			B.cyl(parent, Vector3(0, 0.35, 0), 0.32, 0.7, cloth, false, 0.1)
			B.ball(parent, Vector3(0, 0.74, -0.02), Vector3(0.24, 0.24, 0.24), cloth)
			B.ball(parent, Vector3(0, 0.72, 0.06), Vector3(0.15, 0.17, 0.12), B.mat("#14121c"))
			B.ball(parent, Vector3(0, 0.6, 0.11), Vector3(0.07, 0.07, 0.04), B.mat("#dfe6f2", 0.6))
		"wind_charm":
			var hoop := B.ring(parent, Vector3(0, 0.3, 0), 0.18, 0.025, B.mat("#c9a35e", 0.7)); hoop.rotation.x = PI / 2
			var vane := B.ball(parent, Vector3(0, 0.3, 0), Vector3(0.06, 0.3, 0.12), B.mat("#e8f2ff")); vane.rotation.z = 0.4
		"sunstone_amulet":
			var cord := B.ring(parent, Vector3(0, 0.42, 0), 0.2, 0.015, B.mat("#7a5a3a")); cord.rotation.x = PI / 2
			var disc := B.cyl(parent, Vector3(0, 0.16, 0), 0.13, 0.04, B.mat("#d9a53f", 0.8)); disc.rotation.x = PI / 2
			B.facet(parent, Vector3(0, 0.16, 0.04), Vector3(0.1, 0.1, 0.06), B.mat("#ffb43a", 0.0, 0.8))
		"prism_ring":
			var band := B.ring(parent, Vector3(0, 0.15, 0), 0.15, 0.035, B.mat("#c9c6d8", 0.8)); band.rotation.x = PI / 2
			B.facet(parent, Vector3(0, 0.32, 0), Vector3(0.12, 0.14, 0.12), B.mat("#b48cff", 0.0, 0.7))
		"lantern_charm":
			var brass := B.mat("#a8803e", 0.7)
			B.cyl(parent, Vector3(0, 0.03, 0), 0.15, 0.06, brass)
			B.cyl(parent, Vector3(0, 0.2, 0), 0.11, 0.28, B.mat("#5fd7a8", 0.0, 1.0))
			B.cyl(parent, Vector3(0, 0.37, 0), 0.15, 0.06, brass, false, 0.06)
			var handle := B.ring(parent, Vector3(0, 0.45, 0), 0.08, 0.015, brass); handle.rotation.x = PI / 2
		"hot_cocoa":
			B.cyl(parent, Vector3(0, 0.2, 0), 0.17, 0.4, B.mat("#e8e2d6"))
			B.cyl(parent, Vector3(0, 0.39, 0), 0.15, 0.03, B.mat("#5a2f1c"))
			B.ball(parent, Vector3(-0.04, 0.42, 0.02), Vector3(0.08, 0.06, 0.08), B.mat("#fff6ee"))
			var grip := B.ring(parent, Vector3(0.2, 0.22, 0), 0.08, 0.02, B.mat("#e8e2d6")); grip.rotation.x = PI / 2
		"fish_stew":
			A.place(parent, "zappy_bowl_05", Vector3.ZERO, 0.4)
			B.cyl(parent, Vector3(0, 0.33, 0), 0.36, 0.03, B.mat("#c98a4a"))
			B.ball(parent, Vector3(0.1, 0.36, 0.05), Vector3(0.12, 0.05, 0.08), B.mat("#f0e0c8"))
			B.ball(parent, Vector3(-0.1, 0.36, -0.06), Vector3(0.07, 0.05, 0.07), B.mat("#e07a3a"))
		"cactus_water":
			var a := A.place(parent, "potion_round_bottle", Vector3.ZERO, 0.6)
			if a: _tinted(a, Color("#8fe0a0"), 0.15)
		"sugar_drop":
			for i in range(5): B.ball(parent, Vector3(cos(i * 1.3) * 0.12, 0.06 + (i % 2) * 0.08, sin(i * 1.3) * 0.12), Vector3(0.09, 0.09, 0.09), B.mat(["#f7a1c9", "#ffffff", "#a8d8ff"][i % 3]))
		"mossbloom_tonic":
			var a := A.place(parent, "potion_heart_bottle", Vector3.ZERO, 0.6)
			if a: _tinted(a, Color("#6fdc8c"), 0.2)


func interact(node: Node3D) -> bool:
	if not is_instance_valid(node) or str(node.get_meta("kind", "")) != "gather": return false
	var id := str(node.get_meta("id", "")); var resource := str(node.get_meta("resource", ""))
	if not node.visible: return true
	var amount := 1 + int(hash(id + str(int(game.state.journey_time))) % 2)
	var got: int = game.state.award_reward(resource, amount)
	if got <= 0:
		game.toast("Your satchel has no room for more %s." % Catalog.item_name(resource).to_lower())
		return true
	game.state.taken[id] = game.state.journey_time
	node.visible = false; node.remove_from_group("interactable")
	game.audio.cue("collect")
	game.burst(node.global_position + Vector3.UP * 0.4, Color("#d8f0b0"), 8)
	game.toast("+%d %s" % [got, Catalog.item_name(resource)], 2)
	return true


func tick(dt: float) -> void:
	_clock += dt
	if _clock < 2.0: return
	_clock = 0.0
	_refresh()


func _refresh() -> void:
	var now: float = game.state.journey_time
	for id in nodes:
		var node: Node3D = nodes[id]
		if not is_instance_valid(node): continue
		var taken_at = game.state.taken.get(id, null)
		var ready: bool = taken_at == null or now - float(taken_at) >= REGROW or now < float(taken_at)
		if ready and not node.visible:
			node.visible = true; node.add_to_group("interactable")
			if taken_at != null: game.state.taken.erase(id)
		elif not ready and node.visible:
			node.visible = false; node.remove_from_group("interactable")
