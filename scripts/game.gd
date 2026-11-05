extends Node3D

const State = preload("res://scripts/state.gd")
const PriorFixedGround = preload("res://scripts/prior_fixed_ground.gd")
const CompactGeography = preload("res://scripts/compact_geography.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const SpellWallPreview = preload("res://scripts/spell_wall_preview.gd")
var spell_wall_preview
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const DesktopControls = preload("res://scripts/desktop_controls.gd")
var desktop_controls
const Audio = preload("res://scripts/audio.gd")
const Enemy = preload("res://scripts/enemy.gd")
const B = preload("res://scripts/build.gd")
const Effects = preload("res://scripts/effects.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const Wildlife = preload("res://scripts/wildlife.gd")
const Crafting = preload("res://scripts/crafting.gd")
const Camp = preload("res://scripts/camp.gd")
const Workbench = preload("res://scripts/workbench.gd")
const Locations = preload("res://scripts/locations.gd")
const Placement = preload("res://scripts/placement_preview.gd")
const Expeditions = preload("res://scripts/expeditions.gd")
const DeepAdventure = preload("res://scripts/deep_adventure.gd")
const DevTools = preload("res://scripts/dev_tools.gd")
var state
var _prior_interior_seed: int = 0
var _prior_atlas_ground
var _saved_coordinates_compacted := false
var pending_supply = ""
var world
var player
var hud
var audio
var environment: WorldEnvironment
var sunlight: DirectionalLight3D
var sky_material: ShaderMaterial
var wildlife: Node3D
var comic_word: String = ""
var comic_time: float = 0.0
var comic_point: Vector3
var comic_color: Color = Color("#f4d887")
var mode: String = "menu"
var return_mode: String = "menu"
var has_save: bool = false
var toast_text: String = ""
var toast_time: float = 0.0
var lore_text: String = ""
var lore_title: String = ""
var region_text: String = ""
var region_time: float = 0.0
var region: int = -1
var damage_flash: float = 0.0
var clock: float = 0.0
var save_clock: float = 0.0
var rain: MultiMeshInstance3D
var rain_amount: float = 0.0
var motes: MultiMeshInstance3D
var _sandstorm_warned := false
var clouds: MultiMeshInstance3D
var effects: Node3D
var feel
var governor
var backdrop: MeshInstance3D
var modal_parents: Dictionary = {}
var mode_age: float = 0.0
var dialogue_name: String = ""
var dialogue_lines: Array = []
var dialogue_index: int = 0
var shop_id: String = ""
var vendor: Node3D
var resource_node: Node3D
var camp: Node3D
var camp_action: String = ""
var craft_last: String = ""
var craft_flash: float = 0.0
var tracked_location: String = "mine"
var sleep_left: float = 0.0
var rest_camera: Vector2
var rest_zoom := Vector2(3.5, 3.5)
var _camp_coffee_started := false
var _sleep_roll_started := false
const PICKUP_HOLD_TIME := 0.45
var pickup_progress: float = 0.0
var pickup_elapsed: float = 0.0
var pickup_target: Node3D
var context_kind: String = ""
var context_held: bool = false
var pickup_committed: bool = false
var craft_grid: Array = []
var placed_workbench: Node3D
var journey_save
var harvest_target: Node3D
var placement_preview: Node3D
var deep_adventure
var expeditions
var quests
var ecology
var magic
var wizard_tower
var dev_tools
var defer_world_until_journey: bool = OS.has_feature("mobile")
var title_backdrop: TextureRect
var world_ready = false
var loading_text = "Starting journey"
var loading_report = preload("res://scripts/loading_report.gd").new()
var render_loading
var travel_loading
var scrappers
signal travel_finished(success: bool)
var _loading_arrival = Vector3.ZERO
var _loot_nodes: Dictionary = {}
var _loot_clock = 0.0
var _loot_serial = 0
var _pending_loot_state

func _loading_stage(stage: String) -> void:
	loading_text = stage
	loading_report.mark(stage, get_tree().get_node_count())
	if is_instance_valid(render_loading): render_loading.request_frame()
	if hud != null: hud.queue_redraw()

func _stop_render_loading() -> void:
	if not is_instance_valid(render_loading): return
	render_loading.finish(); render_loading.queue_free(); render_loading = null

func _exit_tree() -> void:
	if _pending_loot_state == state: _flush_loot_save(state)
	_stop_render_loading()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 60
	get_tree().quit_on_go_back = false
	state = State.new()
	state.expanded_world = is_world_preview()
	has_save = state.load_game()
	var imported_valley = false
	if state.expanded_world and not has_save and FileAccess.file_exists("user://journey.json"):


		state.expanded_world = false
		has_save = state.load_game()
		state.expanded_world = true
		imported_valley = has_save
	if not has_save: state.load_title_settings()
	if state.expanded_world and has_save and state.world_id != "mr-justice-world-01": _prior_interior_seed = state.seed_value
	if state.expanded_world and has_save and not imported_valley and state.world_id != "mr-justice-world-01":
		_prior_atlas_ground = preload("res://scripts/legacy_atlas_ground.gd").new(state.seed_value)
	if state.expanded_world: state.seed_value = 64127
	_saved_coordinates_compacted = CompactGeography.migrate(state, _prior_interior_seed)
	if ResourceLoader.exists("res://scripts/soul_journey.gd"):
		journey_save = load("res://scripts/soul_journey.gd").new()
		journey_save.setup(self)
	_build_environment()
	audio = Audio.new()
	audio.state = state
	add_child(audio)
	effects = Effects.new()
	effects.configure(state.settings)
	add_child(effects)
	feel = preload("res://scripts/game_feel.gd").new()
	feel.setup(self)
	add_child(feel)
	if not defer_world_until_journey: build_world()
	if dev_tools == null:
		dev_tools = DevTools.new(); dev_tools.setup(self)
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	if defer_world_until_journey:
		title_backdrop = TextureRect.new(); title_backdrop.name = "TitleBackdrop"
		title_backdrop.texture = load("res://assets/ui_lantern_ledger/title-backdrop.png")
		title_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(title_backdrop); title_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Hud.new()
	hud.game = self
	canvas.add_child(hud)
	desktop_controls = DesktopControls.new(); desktop_controls.name = "DesktopControls"; desktop_controls.setup(self); add_child(desktop_controls)
	set_mode("menu")
	apply_settings()

func build_world() -> void:
	_clear_world()
	_create_world()
	_prepare_world()
	world.stream_at(world.get_spawn(), true)
	_finish_world()
	world_ready = true

func _clear_world() -> void:
	if is_instance_valid(travel_loading): travel_loading.cancel()
	_stop_render_loading()
	if _pending_loot_state == state: _flush_loot_save(state)
	else: _pending_loot_state = null
	_loot_nodes.clear(); _loot_clock = 0
	world_ready = false
	if dev_tools != null: dev_tools.clear_spawns()
	if is_instance_valid(magic): magic.free()
	magic = null
	wizard_tower = null
	if is_instance_valid(placement_preview): placement_preview.free()
	placement_preview = null
	deep_adventure = null
	expeditions = null
	quests = null
	ecology = null
	if effects != null:
		effects.clear_effects()
	if is_instance_valid(backdrop):
		backdrop.queue_free()
	backdrop = null
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player = null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	scrappers = null

func _create_world() -> void:
	if not state.expanded_world:
		backdrop = Backdrop.new(); backdrop.setup(state.seed_value); add_child(backdrop)
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.setup(state)
	add_child(world)
	if state.expanded_world:
		scrappers = preload("res://scripts/scrapper_world.gd").new()
		world.add_child(scrappers); world.scrappers = scrappers
		scrappers.setup(self)

func _prepare_world() -> void:
	migrate_saved_positions()
	world.build_landmarks()
	_prepare_wizard()
	_prepare_expeditions()
	_prepare_camp()

func _prepare_wizard() -> void:
	if ResourceLoader.exists("res://scripts/wizard_tower.gd"):
		wizard_tower = load("res://scripts/wizard_tower.gd").new()
		wizard_tower.setup(self)
		world.add_child(wizard_tower)

func _prepare_expeditions() -> void:
	expeditions = Expeditions.new()
	expeditions.setup(self)

func _prepare_camp() -> void:
	camp = null
	if state.camp_placed:
		restore_camp()

func _prepare_world_loading() -> void:
	_loading_stage("Finding your saved place")
	await get_tree().process_frame
	migrate_saved_positions()
	await world.build_landmarks_loading(_loading_stage)
	_loading_stage("Lighting the Wizard's Tower")
	await get_tree().process_frame
	_prepare_wizard()
	_loading_stage("Restoring roadside discoveries")
	await get_tree().process_frame
	_prepare_expeditions()
	_loading_stage("Preparing your camp")
	await get_tree().process_frame
	_prepare_camp()

func _finish_world() -> void:
	_create_player()
	_create_magic()
	_create_wildlife()
	setup_workbenches()
	_create_quests()
	_create_ecology()
	_bind_world_services()

func _create_player() -> void:
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.setup(state, world)
	player.game = self
	player.position = _loading_arrival if is_instance_valid(render_loading) else world.get_spawn()
	player.active = false
	add_child(player)
	player.visual.rotation.y = PI + 0.3

func _create_magic() -> void:
	if ResourceLoader.exists("res://scripts/magic.gd"):
		magic = load("res://scripts/magic.gd").new()
		magic.setup(self)
		add_child(magic)
	if not state.expanded_world:
		spawn_enemies()
		deep_adventure = DeepAdventure.new()
		deep_adventure.setup(self)

func _create_wildlife(prepare_later: bool = false) -> void:
	wildlife = Wildlife.new()
	wildlife.setup(self, prepare_later)
	world.add_child(wildlife)

func _create_wildlife_loading() -> void:
	_create_wildlife(true)
	await wildlife.populate_loading(_loading_stage, render_loading.draw_frame)

func _create_quests() -> void:
	if ResourceLoader.exists("res://scripts/quests.gd"):
		quests = load("res://scripts/quests.gd").new()
		quests.setup(self)

func _create_ecology() -> void:
	if ResourceLoader.exists("res://scripts/ecology.gd"):
		ecology = load("res://scripts/ecology.gd").new()
		ecology.setup(self)
		world.add_child(ecology)

func _bind_world_services() -> void:
	placement_preview = Placement.new()
	add_child(placement_preview)
	if journey_save != null: journey_save.restore_echo()
	if dev_tools == null: dev_tools = DevTools.new()
	dev_tools.setup(self)
	if world.mosswake != null: world.mosswake.bind_game(self)
	if world.regional != null: world.regional.bind_game(self)
	if world.society != null: world.society.bind_game(self)
	_refresh_world_loot()

func _world_drop(record: Dictionary) -> Node3D:
	var id = str(record.id)
	if _loot_nodes.has(id) and is_instance_valid(_loot_nodes[id]): return _loot_nodes[id]
	var node = Node3D.new(); node.name = "Dropped" + str(record.item).capitalize(); world.add_child(node)
	node.global_position = Vector3(float(record.position[0]), float(record.position[1]), float(record.position[2]))
	node.set_meta("id", id); node.set_meta("kind", "shard" if record.item == "shard" else "material"); node.set_meta("item", record.item); node.set_meta("amount", int(record.amount)); node.set_meta("world_drop", true); node.set_meta("loose_stone", record.item == "stone")
	node.set_meta("label", "Collect %d Light Essence" % int(record.amount) if record.item == "shard" else "Collect " + Crafting.item_name(str(record.item)))
	if record.has("rock_size"):
		# A big rock that was carried or levitated and set down: it stays a rock you can lift again.
		var size: Array = record.rock_size
		node.set_meta("rock_size", size); node.set_meta("label", "Lift rock")
		var rock = preload("res://scripts/imported_assets.gd").place(node, "qnat_rock_medium_" + str(1 + posmod(hash(id), 3)), Vector3(0, -0.14, 0), maxf(0.2, float(size[1])), float(posmod(hash(id), 628)) * 0.01)
		if rock == null: preload("res://scripts/item_models.gd").build(node, "stone").scale = Vector3.ONE * 2.0
		node.add_to_group("interactable"); _loot_nodes[id] = node
		return node
	var art = preload("res://scripts/item_models.gd").build(node, str(record.item)); art.scale = Vector3.ONE * (1.5 if record.item == "shard" else 1.2)
	node.set_meta("base_y", node.position.y); node.add_to_group("interactable"); node.add_to_group("float_pickup"); _loot_nodes[id] = node
	return node

func _loot_landing(at: Vector3, excluded: Array[RID] = []) -> Vector3:


	var query = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1, at - Vector3.UP * 2048, 1 | 8)
	query.exclude = excluded
	var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): return Vector3(at.x, hit.position.y + 0.14, at.z)
	if world.interior_at(at).is_empty(): return Vector3(at.x, world.surface_height_at(at.x, at.z) + 0.14, at.z)
	return at

func _barrel_drop_position(origin: Vector3, offset: Vector3, excluded: Array[RID]) -> Vector3:
	var query = PhysicsRayQueryParameters3D.create(origin, origin + offset, 1 | 8)
	query.exclude = excluded
	var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
	var point = origin + offset
	if not hit.is_empty(): point = origin + offset.normalized() * maxf(0, origin.distance_to(hit.position) - 0.12)
	return _loot_landing(point, excluded)

func _essence_drop_id(source_id: String) -> String:
	var key = source_id
	if key.begins_with("enemy_drop:"): key += ":life:" + str(state.loot_epoch)
	return "essence_" + key.sha256_text().substr(0, 32)

func can_drop_light_essence(source_id: String) -> bool:
	var id = _essence_drop_id(source_id)
	if state.taken.has(id): return true
	for record in state.world_loot:
		if record.id == id: return true
	if state.world_loot.size() < preload("res://scripts/world_loot.gd").LIMIT: return true
	toast("Collect some dropped supplies to make room for more.")
	return false

func can_break_barrel(barrel: Node3D) -> bool:
	var count = preload("res://scripts/world_loot.gd").barrel_items(str(barrel.get_meta("id", "")), state.seed_value).size() + 1
	if state.world_loot.size() + count <= preload("res://scripts/world_loot.gd").LIMIT: return true
	toast("Collect some dropped supplies before breaking more barrels.")
	return false

func can_break_crate(crate: Node3D) -> bool:
	if state == null or not is_instance_valid(world) or not is_instance_valid(crate) or not crate.get_meta("breakable_crate", false): return false
	var source = str(crate.get_meta("id", ""))
	if source.is_empty() or state.taken.has("crate_loot_" + source.sha256_text().substr(0, 32)) or state.taken.get("broken_" + source, false): return false
	if not world.is_ancestor_of(crate) and (not is_instance_valid(player) or not player.is_ancestor_of(crate)): return false
	var count = preload("res://scripts/world_loot.gd").crate_items(source, state.seed_value).size() + 1
	if state.world_loot.size() + count > preload("res://scripts/world_loot.gd").LIMIT:
		toast("Collect some dropped supplies before breaking this crate."); return false
	return true

func break_crate(crate: Node3D) -> bool:
	if not can_break_crate(crate): return false
	var source = str(crate.get_meta("id", "")); var issued = "crate_loot_" + source.sha256_text().substr(0, 32)
	var old_flags = state.taken.duplicate(true); var old_loot = state.world_loot.duplicate(true); var old_slots = state.inventory_slots().duplicate(true)
	var items = preload("res://scripts/world_loot.gd").crate_items(source, state.seed_value)
	var records = []; var excluded: Array[RID] = []
	if crate is CollisionObject3D: excluded.append(crate.get_rid())
	if is_instance_valid(player): excluded.append(player.get_rid())
	for i in range(items.size() + 1):
		var angle = TAU * float(i) / float(items.size() + 1) + 0.4
		var at = _barrel_drop_position(crate.global_position, Vector3(cos(angle) * 0.65, 0.18, sin(angle) * 0.65), excluded)
		var row = {"id": issued + "_" + str(i), "item": items[i] if i < items.size() else "shard", "amount": 1 if i < items.size() else 2, "position": [at.x, at.y, at.z]}
		if not state.add_world_drop(row):
			state.world_loot = old_loot; state.taken = old_flags; state._slots = old_slots
			toast("The crate's supplies could not be stored. Nothing was broken."); return false
		records.append(row)
	state.taken[source] = true; state.taken["broken_" + source] = true; state.taken[issued] = true


	if not state.save_game():
		state.world_loot = old_loot; state.taken = old_flags; state._slots = old_slots
		toast("The crate could not be saved. Its supplies are still inside."); return false
	for row in records: _world_drop(row)
	burst(crate.global_position + Vector3.UP * 0.3, Color("#c19a68"))
	if audio != null: audio.cue("impact")
	toast("Supply crate broken · collect the scattered supplies and Light Essence")
	return true

func spawn_light_essence(at: Vector3, amount: int, source_id: String = "", excluded: Array[RID] = []) -> Node3D:
	if state == null or world == null or amount <= 0 or not at.is_finite(): return null
	_loot_serial += 1
	var key = source_id if not source_id.is_empty() else "%s:%s:%s" % [at, Time.get_ticks_usec(), _loot_serial]
	var id = _essence_drop_id(key)
	var landed = _loot_landing(at, excluded)
	var record = {"id": id, "item": "shard", "amount": mini(amount, State.MAX_ITEMS), "position": [landed.x, landed.y, landed.z]}
	if not state.add_world_drop(record): return _loot_nodes.get(id)
	var node = _world_drop(record)
	if world_ready: _queue_loot_save()
	return node

func _queue_loot_save() -> void:


	if _pending_loot_state == state: return
	_pending_loot_state = state; _flush_loot_save.call_deferred(state)
func _flush_loot_save(snapshot) -> void:
	if snapshot != state:
		if _pending_loot_state == snapshot: _pending_loot_state = null
		return
	if _pending_loot_state != snapshot: return
	_sync_stone_drops(); _pending_loot_state = null; snapshot.save_game()

func break_barrel(barrel: Node3D) -> void:
	if not is_instance_valid(barrel) or world == null: return
	var source = str(barrel.get_meta("id", "")); var issued = "barrel_loot_" + source.sha256_text().substr(0, 32)
	if state.taken.has(issued): return
	if not can_break_barrel(barrel): return
	state.taken[issued] = true
	var items = preload("res://scripts/world_loot.gd").barrel_items(source, state.seed_value)
	var origin = barrel.global_position
	for i in range(items.size()):
		var angle = TAU * float(i) / items.size() + 0.4
		var at = _barrel_drop_position(origin, Vector3(cos(angle) * 0.55, 0.18, sin(angle) * 0.55), [barrel.get_rid()])
		var record = {"id": issued + "_" + str(i), "item": items[i], "amount": 1, "position": [at.x, at.y, at.z]}
		if state.add_world_drop(record): _world_drop(record)
	spawn_light_essence(origin, 1 + int(items.size() > 1), "barrel:" + source, [barrel.get_rid()])
	burst(origin + Vector3.UP * 0.3, Color("#c19a68")); audio.cue("impact"); toast("Barrel broken · supplies and Light Essence")
	_queue_loot_save()

func _claim_world_loot(node: Node3D) -> bool:
	if not usable_node(node) or not node.get_meta("world_drop", false): return false
	var id = str(node.get_meta("id")); var item = str(node.get_meta("item")); var amount = int(node.get_meta("amount", 1))
	if not state.claim_world_drop(id): return false
	_loot_nodes.erase(id); burst(node.global_position, Color("#ffd36a") if item == "shard" else Color("#bcefc6")); node.queue_free(); audio.cue("collect")
	toast("+%d Light Essence" % amount if item == "shard" else "Gathered %d %s" % [amount, Crafting.item_name(item)])
	_queue_loot_save(); return true

func _refresh_world_loot() -> void:
	if world == null or player == null: return
	for id in _loot_nodes.keys():
		var node = _loot_nodes[id]
		if not is_instance_valid(node): _loot_nodes.erase(id)
		elif node.global_position.distance_squared_to(player.global_position) > 120 * 120:
			node.queue_free(); _loot_nodes.erase(id)
	for record in state.world_loot.duplicate():
		var lifted = _loot_nodes.get(record.id)
		if is_instance_valid(lifted) and lifted.get_meta("lifted_stone", false): _sync_stone_drop(record, lifted)
		var point = Vector3(float(record.position[0]), float(record.position[1]), float(record.position[2]))
		if point.distance_squared_to(player.global_position) > 110 * 110: continue
		var node = _world_drop(record)
		if mode == "play" and record.item == "shard" and point.distance_squared_to(player.global_position + Vector3.UP * 0.4) < 1.4 * 1.4:
			if player.ray(player.global_position + Vector3.UP * 0.65, point + Vector3.UP * 0.1, 1 | 8).is_empty(): _claim_world_loot(node)

func _sync_stone_drop(record: Dictionary, body: RigidBody3D, force: bool = false) -> void:


	if not is_instance_valid(body) or not body.is_inside_tree() or not world.is_inside_tree() or not player.is_inside_tree() or world.get_world_3d() == null: return
	var at = body.global_position; var previous = body.get_meta("last_loot_position", false)
	if force or not previous is Vector3 or at.distance_squared_to(previous) > 0.0016:
		var point = _loot_landing(at, [body.get_rid(), player.get_rid()])
		record.position = [point.x, point.y, point.z]; body.set_meta("last_loot_position", at)
	if not body.freeze and body.sleeping and not body.get_meta("stone_settled_saved", false):
		body.set_meta("stone_settled_saved", true); _queue_loot_save()

func _sync_stone_drops() -> void:
	if state == null or not is_instance_valid(world) or not is_instance_valid(player): return
	if not world.is_inside_tree() or not player.is_inside_tree() or world.get_world_3d() == null: return
	for record in state.world_loot:
		var body = _loot_nodes.get(record.id)
		if is_instance_valid(body) and body.get_meta("lifted_stone", false): _sync_stone_drop(record, body)

func stone_released(body: RigidBody3D) -> void:
	body.set_meta("stone_settled_saved", false)
	for record in state.world_loot:
		if record.id == body.get_meta("id"): _sync_stone_drop(record, body, true); break
	_queue_loot_save()

func _finish_world_loading() -> void:
	for step in [["Building Mr. Justice", _create_player], ["Preparing magic", _create_magic], ["Gathering wildlife", _create_wildlife], ["Placing crafting stations", setup_workbenches], ["Preparing quests", _create_quests], ["Preparing world activity", _create_ecology], ["Restoring travel tools", _bind_world_services]]:
		_loading_stage(step[0])
		if step[0] == "Gathering wildlife": await _create_wildlife_loading()
		else: step[1].call()
		if player != null: player.set_process(false); player.set_physics_process(false)
		await render_loading.draw_frame()

func _present_loaded_world() -> void:
	if not is_instance_valid(render_loading): return
	_loading_stage("Animating Mr. Justice")
	player._process(1.0 / 60.0)
	await render_loading.draw_frame()
	# Compile forest and spell shaders now, not on the first walk into the woods.
	_loading_stage("Preparing forests and magic")
	var warmup = preload("res://scripts/shader_warmup.gd").new()
	add_child(warmup); warmup.build(self, render_loading.camera)
	await render_loading.draw_frame()
	await render_loading.draw_frame()
	warmup.queue_free()
	_loading_stage("Opening the world view")
	await render_loading.draw_frame()
	loading_report.data["rendered_loading_frames"] = render_loading.drawn_frames
	_stop_render_loading()

	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw
	player.set_process(true); player.set_physics_process(true)

func _build_world_loading(continuing: bool) -> void:
	_clear_world()

	await get_tree().process_frame
	_loading_stage("Opening the world map")
	await get_tree().process_frame
	_create_world()
	render_loading = preload("res://scripts/render_loading.gd").new(); add_child(render_loading)
	render_loading.begin(get_viewport(), state.player_position if continuing else world.get_spawn(), 14000 if world.atlas != null else 220)
	await get_tree().process_frame
	await _prepare_world_loading()
	await get_tree().process_frame
	var arrival: Vector3 = state.player_position if continuing else world.get_spawn()
	_loading_arrival = arrival
	render_loading.position_at(arrival)
	_loading_stage("Preparing nearby ground and buildings")
	world.stream_at(arrival, false)
	var loading_slices = 0
	while not world.pending.is_empty() or not world.stream_job.is_empty() or not world.settlement_jobs.is_empty() or (world.society != null and (not world.society.jobs.is_empty() or not world.society.proxy_jobs.is_empty())) or (is_instance_valid(scrappers) and not scrappers.jobs.is_empty()):
		var deadline = Time.get_ticks_usec() + 4000
		if not world.settlement_jobs.is_empty(): Locations.step_settlement(world)
		if world.society != null and not world.society.jobs.is_empty(): world.society.step()
		if world.society != null and not world.society.proxy_jobs.is_empty(): world.society.step_proxy()
		if is_instance_valid(scrappers) and not scrappers.jobs.is_empty(): scrappers.step()
		while Time.get_ticks_usec() < deadline and (not world.pending.is_empty() or not world.stream_job.is_empty()): world.stream_step()
		if world.pending.is_empty() and world.stream_job.is_empty() and is_instance_valid(scrappers): scrappers.stream_at(arrival, false)
		loading_slices += 1
		if loading_slices % 64 == 0: await render_loading.draw_frame()
		await get_tree().process_frame


	world.stream_at(arrival, true)
	await get_tree().process_frame
	await _finish_world_loading()
	await get_tree().process_frame
	if is_instance_valid(title_backdrop): title_backdrop.queue_free(); title_backdrop = null

func _saved_ground_point(point: Vector3, footprint: float, planted: bool = false, uncached: bool = false) -> Vector3:


	if world.interior_at(point) != "":
		return load("res://scripts/interior_clearance.gd").rehome(world, point, footprint)
	if _prior_interior_seed != 0:
		var old_interior = preload("res://scripts/legacy_deep_envelopes.gd").interior_at(point, _prior_interior_seed)
		if not old_interior.is_empty(): return Locations.INTERIORS[old_interior] + Vector3(0, 0.24, 4)
	if world.atlas != null and Vector2(point.x, point.z).distance_to(world.atlas.nodes.brindlewick) < 1.35 and point.y < world.atlas.height_at(world.atlas.nodes.brindlewick) + 0.78:
		return world.get_spawn()
	var ground: float = world.surface_height_at(point.x, point.z, not uncached)


	var prior_point = Vector2(point.x, point.z)
	if _saved_coordinates_compacted: prior_point = CompactGeography.source(prior_point)
	var former_ground: float = _prior_atlas_ground.height_at(prior_point) if _prior_atlas_ground != null else world.legacy_height_at(point.x, point.z)
	var support_margin = 0.35 if _prior_atlas_ground is PriorFixedGround and not planted else 1.2
	var lost_support := (planted or _prior_atlas_ground != null) and ground < former_ground - 0.5 and absf(point.y - former_ground) < support_margin
	if point.y >= ground - 0.1 and not lost_support:
		return point
	var origin = Vector2(point.x, point.z)
	for ring in range(17):
		var samples = 1 if ring == 0 else 16
		for i in range(samples):
			var candidate = origin + Vector2.from_angle(float(i) * TAU / samples) * float(ring) * 2.0
			if Locations.reserved(candidate, footprint): continue
			if world.atlas != null and not world.atlas.liquid_at(candidate).is_empty(): continue
			var low := INF; var high := -INF
			for offset in [Vector2.ZERO, Vector2(-footprint, -footprint), Vector2(footprint, -footprint), Vector2(-footprint, footprint), Vector2(footprint, footprint)]:
				var height: float = world.surface_height_at(candidate.x + offset.x, candidate.y + offset.y, not uncached)
				low = minf(low, height); high = maxf(high, height)
			if low > world.water_level + 0.5 and high - low < 0.3:
				return Vector3(candidate.x, high + 0.035, candidate.y)

	return world.get_spawn()

func migrate_saved_positions() -> void:
	if CompactGeography.migrate(state, _prior_interior_seed): _saved_coordinates_compacted = true
	if state.expanded_world and state.world_id == "mr-justice-world-01" and state.terrain_revision < 32 and _prior_atlas_ground == null: _prior_atlas_ground = PriorFixedGround.new()
	_migrate_castle_belongings()
	state.player_position = _building_entry_point(_castle_entry_point(_saved_ground_point(state.player_position, 0.4)))
	state.checkpoint = _building_entry_point(_castle_entry_point(_saved_ground_point(state.checkpoint, 0.55, true)))
	if state.camp_placed: state.camp_position = _saved_ground_point(state.camp_position, 2.6, true)
	if state.workbench_placed: state.workbench_position = _saved_ground_point(state.workbench_position, 0.95, true)
	if state.death_echo_active: state.death_echo_position = _building_entry_point(_castle_entry_point(_saved_ground_point(state.death_echo_position, 0.4, true)))
	state.terrain_revision = 32
	if _prior_atlas_ground is PriorFixedGround: _prior_atlas_ground = null
	CompactGeography.release_source()

func _migrate_castle_belongings() -> void:
	if not state.expanded_world or world.atlas == null: return
	var p: Vector2 = world.atlas.nodes.blackthornkeep; var base = Vector3(p.x, world.atlas.height_at(p), p.y)
	var castle = preload("res://scripts/gothic_castle.gd")
	var camp_local: Vector3 = state.camp_position - base
	var raised_approach = absf(camp_local.x) < 65 and camp_local.z > -80 and camp_local.z < 170 and state.camp_position.y < world.atlas.height_at(Vector2(state.camp_position.x, state.camp_position.z)) - 0.5
	if state.camp_placed and (castle.occupied(camp_local) or raised_approach):
		var old = state.camp_position; var target = base + Vector3(20, 0, 185)
		target.y = world.surface_height_at(target.x, target.z, false) + 0.025
		var offset = target - old
		if state.workbench_placed and state.workbench_position.distance_to(old) < 12: state.workbench_position += offset
		for record in state.camp_clearings:
			var at = Vector3(record.position[0], record.position[1], record.position[2])
			if Vector2(at.x - old.x, at.z - old.z).length() < 8:
				at += offset; record.position = [at.x, at.y, at.z]
		state.camp_position = target
	var bench_local: Vector3 = state.workbench_position - base
	var raised_bench = absf(bench_local.x) < 65 and bench_local.z > -80 and bench_local.z < 170 and state.workbench_position.y < world.atlas.height_at(Vector2(state.workbench_position.x, state.workbench_position.z)) - 0.5
	if state.workbench_placed and (castle.occupied(bench_local) or raised_bench):
		state.workbench_position = base + Vector3(14, 0, 185)
		state.workbench_position.y = world.surface_height_at(state.workbench_position.x, state.workbench_position.z, false) + 0.025

func _castle_entry_point(point: Vector3) -> Vector3:



	if not state.expanded_world or world.atlas == null or world.regional == null or not world.interior_at(point).is_empty(): return point
	var p: Vector2 = world.atlas.nodes.blackthornkeep
	var local = point - Vector3(p.x, world.atlas.height_at(p), p.y)
	if preload("res://scripts/gothic_castle.gd").occupied(local):
		return world.regional._return_point("haunted-d01")
	return point

func _building_entry_point(point: Vector3, only_house: Node3D = null) -> Vector3:


	if not point.is_finite() or not is_instance_valid(world): return point
	var shape = CapsuleShape3D.new(); shape.radius = Player.BODY_RADIUS + 0.02; shape.height = Player.HERO_HEIGHT
	var query = PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1 | 8; query.margin = 0.02
	if is_instance_valid(player): query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (Player.HERO_HEIGHT * 0.5 + 0.01))
	var space = world.get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 32):
		var blocker = hit.collider as Node3D
		if not is_instance_valid(blocker) or not blocker.is_in_group("building_door_blocker"): continue
		var house = blocker.get_node_or_null(blocker.get_meta("building_frame", NodePath("../.."))) as Node3D
		if not is_instance_valid(house) or (only_house != null and house != only_house) or not world.is_ancestor_of(house): continue
		var outside = house.to_local(point).z >= house.to_local(blocker.global_position).z
		var marker = house.get_node_or_null("BuildingEntry" if outside else "BuildingExit") as Node3D
		if not is_instance_valid(marker): continue
		query.collision_mask = 1 | 4 | 8
		for offset in [Vector3.ZERO, Vector3(-0.45, 0, 0), Vector3(0.45, 0, 0), Vector3(0, 0, 0.45 if outside else -0.45)]:
			var candidate = house.to_global(marker.position + offset)
			query.transform.origin = candidate + Vector3.UP * (Player.HERO_HEIGHT * 0.5 + 0.01)
			if space.intersect_shape(query, 1).is_empty(): return candidate
	return point

func _rehome_building_saved_positions(house: Node3D) -> void:
	if state == null or not is_instance_valid(world) or not is_instance_valid(house) or not world.is_ancestor_of(house): return
	var old_player: Vector3 = state.player_position
	var old_echo: Vector3 = state.death_echo_position
	state.player_position = _building_entry_point(old_player, house)
	var old_checkpoint: Vector3 = state.checkpoint
	state.checkpoint = _building_entry_point(old_checkpoint, house)
	if state.death_echo_active: state.death_echo_position = _building_entry_point(old_echo, house)
	if state.player_position != old_player and is_instance_valid(player) and player.global_position.distance_to(old_player) < 0.75:
		player.global_position = state.player_position; player.reset_motion()
	var echo_changed = state.death_echo_active and state.death_echo_position != old_echo
	if echo_changed and journey_save != null: journey_save.restore_echo()
	if state.player_position != old_player or state.checkpoint != old_checkpoint or echo_changed: state.save_game()

func spawn_enemies() -> void:
	for i in range(6):
		var id = "husk_%s" % i
		if state.taken.has(id):
			continue
		var pos = [Vector2(27, -37), Vector2(46, -20), Vector2(83, -48), Vector2(115, -70), Vector2(-63, -53), Vector2(-90, -94)][i]
		var enemy = Enemy.new()
		if enemy.has_method("configure_species"):
			enemy.configure_species(["moss_guardian", "glass_skitter", "thorn_wolf", "cinder_wisp", "frost_brute", "wild_boar"][i])
		enemy.game = self
		enemy.id = id
		enemy.position = Vector3(pos.x, world.height_at(pos.x, pos.y) + 0.2, pos.y)
		enemy.home = enemy.position
		world.add_child(enemy)
	for marker in get_tree().get_nodes_in_group("frontier_enemy_spawn"):
		if not world.is_ancestor_of(marker): continue
		var id = str(marker.get_meta("id", ""))
		if state.taken.has(id):
			continue
		var guardian = Enemy.new()
		guardian.game = self
		guardian.id = id
		guardian.position = marker.global_position
		guardian.home = guardian.position
		world.add_child(guardian)

func reset_enemies() -> void:
	state.loot_epoch += 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if world.is_ancestor_of(enemy):
			enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
	for i in range(6): state.taken.erase("husk_%d" % i)
	for marker in get_tree().get_nodes_in_group("frontier_enemy_spawn"):
		if world.is_ancestor_of(marker): state.taken.erase(str(marker.get_meta("id", "")))
	spawn_enemies()
	if deep_adventure != null: deep_adventure.reset_encounters()
	if is_instance_valid(scrappers): scrappers.reset_for_rest()

func on_player_death() -> void:
	if magic != null: magic.clear_effects()
	cancel_context_action()
	clear_craft_grid()
	if journey_save != null: journey_save.on_defeat()
	comic_time = 0.0
	resource_node = null
	vendor = null
	camp_action = ""

func start_journey(continuing: bool = false, seed_text: String = "") -> void:
	if mode == "loading": return
	world_ready = false
	loading_report.begin(continuing)
	loading_text = "Starting journey"
	set_mode("loading")
	await get_tree().process_frame
	if continuing and has_save:
		state.load_game()
		if state.expanded_world: state.seed_value = 64127
		_saved_coordinates_compacted = CompactGeography.migrate(state, _prior_interior_seed)
		if world == null:
			await _build_world_loading(true)
		else:
			migrate_saved_positions()
			if deep_adventure != null: deep_adventure.reset_encounters()
	else:
		var preferences = state.settings.duplicate()
		_prior_atlas_ground = null
		_prior_interior_seed = 0
		_saved_coordinates_compacted = false
		state = State.new()
		state.expanded_world = is_world_preview()
		state.settings = preferences
		state.seed_value = 64127 if state.expanded_world else int(seed_text) if seed_text.is_valid_int() else 64127
		audio.state = state
		if defer_world_until_journey: await _build_world_loading(false)
		else: build_world()
		state.checkpoint = world.get_spawn()
		state.player_position = state.checkpoint
	player.global_position = state.player_position + Vector3.UP * 0.15
	player.reset_motion()
	world.stream_at(player.position, true)
	if journey_save != null: journey_save.restore_echo()
	player.visual.rotation.y = 0
	player.yaw = -0.12
	player.pitch = 0.18
	player.update_camera(1)
	region = -1
	tracked_location = "bellcrown" if state.expanded_world else "mine"
	if quests != null: quests.restore_tracking()
	await _present_loaded_world()
	world_ready = true
	set_mode("play")
	toast("Your grimoire is in your satchel. Equip it to cast. Browse the spell collection to fill four quick slots. " + ("Use number keys for hotbar tonics and cooked food." if desktop_enabled() else "Tap a hotbar tonic or cooked food to use it."), 7)
	state.save_game()
	has_save = true
	loading_report.finish(get_tree().get_node_count())

func desktop_enabled() -> bool:
	return is_instance_valid(desktop_controls) and desktop_controls.enabled

func set_mode(next: String) -> void:

	if next == "spellforge": next = "grimoire"
	if next != "play" and effects != null: effects.suspend_feedback()
	cancel_context_action()
	if mode in ["grimoire", "spellforge"] and next not in ["grimoire", "spellforge"] and hud != null and hud.get("magic_ui") != null:
		hud.magic_ui.cancel_draft()
	if mode in ["bag", "craft"] and next not in ["bag", "craft"]:
		clear_craft_grid()
	if next in ["settings", "controls", "journal", "craft", "trade", "grimoire", "spellforge", "dev"] and mode != next:
		modal_parents[next] = mode if mode in ["menu", "pause", "bag", "play", "camp", "dialogue", "rest", "dev"] else modal_parents.get(mode, "pause")
	if player != null:
		var preserving_use = (next == "pause" and mode == "play") or (next == "play" and mode == "pause")
		player.clear_controls(not preserving_use)
		player.visual.supply_pour.paused = next == "pause"
		var was_bag = mode == "bag" or (mode in ["journal", "craft"] and modal_parents.get(mode, "") == "bag")
		var will_bag = next == "bag" or (next in ["journal", "craft"] and modal_parents.get(next, "") == "bag")
		if was_bag and not will_bag:
			player.begin_bag(false)
		if will_bag and not was_bag:
			player.begin_bag(true)
		if mode in ["rest", "sleep"] and next not in ["rest", "sleep"]:
			if is_instance_valid(camp):
				player.position = _camp_exit_point()
				if camp.sleep_pack != null: camp.sleep_pack.hide()
			player.visual.end_camp_pose()
			player.yaw = rest_camera.x; player.pitch = rest_camera.y
			player.camera_distance = rest_zoom.x; player.zoom_target = rest_zoom.y
			state.player_position = player.position
			sleep_left = 0.0
		player.active = next == "play"
	if next == "settings" or next == "controls":
		return_mode = "menu" if mode == "menu" else "pause"
	mode = next
	if next in ["bag", "craft"]: _ensure_craft_grid()
	mode_age = 0
	get_tree().paused = mode not in ["play", "rest", "sleep"]
	if next not in ["camp", "craft", "rest", "sleep"]:
		camp_action = ""
	elif next == "camp" and near_camp():
		camp_action = "camp"
	if hud != null and hud.has_method("release_pointers"):
		hud.release_pointers()
	if is_instance_valid(desktop_controls): desktop_controls.sync_mode()
	if next in ["pause", "bag", "menu", "camp"] and has_save:
		_save_current_state()

func navigate_back() -> bool:
	if mode == "menu" and hud != null and hud.new_journey_confirmation:
		hud.dispatch("new_cancel")
		hud.seed_entry.release_focus()
		return true
	if mode == "menu" or mode == "loading":
		return false
	if mode == "dev" and hud != null and hud.dev_menu != null:
		hud.dev_menu.dispatch("dev:close")
	elif mode == "spellforge":
		set_mode("grimoire")
	elif mode == "grimoire":
		set_mode("play")
	elif mode in ["settings", "controls", "journal", "craft", "trade"]:
		set_mode(str(modal_parents.get(mode, "pause")))
	elif mode in ["rest", "sleep"]:
		camp_command("leave")
	elif mode in ["pause", "bag", "lore", "dialogue", "resource", "camp"]:
		set_mode("play")
	elif mode == "play":
		set_mode("pause")
	return true

func is_title_context() -> bool:
	return mode == "menu" or (mode in ["settings", "controls"] and modal_parents.get(mode, "") == "menu")

func _build_environment() -> void:
	environment = WorldEnvironment.new()
	var env = Environment.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/comic_sky.gdshader")
	sky_material.set_shader_parameter("cloud_tex_01", preload("res://assets/imported/sky/clouds_1.tres"))
	sky_material.set_shader_parameter("cloud_tex_02", preload("res://assets/imported/sky/clouds_2.tres"))
	var sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a5c4d5")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("#7c9fa4")
	env.fog_density = 0.005
	env.fog_sky_affect = 0.15
	env.fog_height = -8
	env.fog_height_density = 0.035
	environment.environment = env
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-38, -40, 0)
	sunlight.light_color = Color("#ffe1b0")
	sunlight.light_energy = 0.86
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sunlight.directional_shadow_max_distance = 48
	sunlight.shadow_bias = 0.1
	sunlight.shadow_normal_bias = 2.0
	add_child(sunlight)
	rain = MultiMeshInstance3D.new()
	rain.multimesh = MultiMesh.new()
	rain.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var drop = BoxMesh.new()
	drop.size = Vector3(0.014, 0.55, 0.014)
	rain.multimesh.mesh = drop
	rain.multimesh.instance_count = 170
	var rainmat = StandardMaterial3D.new()
	rainmat.albedo_color = Color(0.7, 0.86, 0.87, 0.4)
	rainmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rainmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.material_override = rainmat
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	motes = MultiMeshInstance3D.new()
	motes.multimesh = MultiMesh.new()
	motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var speck = SphereMesh.new()
	speck.radius = 0.025
	speck.height = 0.05
	speck.radial_segments = 6
	speck.rings = 3
	motes.multimesh.mesh = speck
	motes.multimesh.instance_count = 30
	motes.material_override = B.mat("#e5d79a", 0, 0.5)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)

func _process(dt: float) -> void:
	if mode in ["play", "rest", "sleep", "loading"] or is_title_context():
		clock += dt
	craft_flash = maxf(0, craft_flash - dt * 1.4)
	if mode in ["rest", "sleep"]:
		state.journey_time += dt
		_tick_camp(dt)
	mode_age += dt
	toast_time = maxf(0, toast_time - dt)
	region_time = maxf(0, region_time - dt)
	damage_flash = maxf(0, damage_flash - dt)
	update_placement_preview()
	if mode == "play":
		_loot_clock += dt
		if _loot_clock >= 0.12: _loot_clock = 0; _refresh_world_loot()
		if state.expanded_world:
			discover_atlas_capitals()
			var liquid: Dictionary = world.atlas.liquid_at(Vector2(player.position.x, player.position.z))
			if not liquid.is_empty() and liquid.kind == "lava" and player.position.y < liquid.height + 0.35: player.take_damage(1)
		if magic != null: magic.tick(dt)
		_tick_context_action(dt)
		if expeditions != null: expeditions.tick(dt)
		if quests != null: quests.tick(dt)
		if deep_adventure != null: deep_adventure.tick(dt)
		comic_time = maxf(0.0, comic_time - dt)
		state.journey_time += dt
		save_clock += dt
		if save_clock > 25:
			save_clock = 0
			state.save_game()
		var interior = world.interior_at(player.position)
		var r = 102 if interior == "rootglow" else 103 if interior == "cedarwatch" else 100 if interior == "mine" else 101 if interior == "dungeon" else world.biome_at(player.position.x, player.position.z)
		if r != region:
			region = r
			region_text = world.region_names[r] if r < world.region_names.size() else "EMBERVEIN CAVE & MINE" if r == 100 else "THE BELLKEEPER'S CRYPT"
			if interior in ["rootglow", "cedarwatch"]: region_text = str(world.MosswakeLayouts.NAMES[interior]).to_upper()
			if not world.RegionSites.site(interior).is_empty(): region_text = str(world.RegionSites.site(interior).name).to_upper()
			region_time = 4.5
			if r > 0 and not state.taken.has("region_%s" % r):
				state.taken["region_%s" % r] = true
				var earned: int = state.award_reward("shard", 3)
				toast("A new place discovered  +%d Light Essence" % earned)
		for site in world.locations_near(Vector2(player.position.x, player.position.z)):
			if site.kind == "mountain" and absf(player.position.y - world.height_at(site.pos.x, site.pos.y)) > 4.0:
				continue
			if Vector2(player.position.x, player.position.z).distance_to(site.pos) < 17 and world.interior_at(player.position) == "":
				var id = "discovered_" + str(site.id)
				if not state.taken.has(id):
					state.taken[id] = true
					var earned: int = state.award_reward("shard", 3)
					region_text = str(site.name).to_upper()
					region_time = 4.5
					toast("Discovered " + str(site.name) + "  +%d Light Essence" % earned)
	if player != null and backdrop != null:
		backdrop.position.x = player.position.x
		backdrop.position.z = player.position.z
	_weather()

func _weather() -> void:
	if player == null:
		return
	rain_amount = smoothstep(0.25, 0.8, sin(clock / 38.0 - 1.0))
	var indoors = world.interior_at(player.position) != ""
	var protected = indoors or sheltered_at(player.position)
	rain.visible = rain_amount > 0.03 and not protected
	motes.visible = not protected
	var biome = world.biome_at(player.position.x, player.position.z) if world != null else 0
	if audio != null:
		audio.set_context(biome, rain_amount, protected)
	var cycle = TAU * fposmod(0.18 + state.journey_time / 540.0, 1.0)
	var height = sin(cycle)
	var daylight = smoothstep(-0.18, 0.22, height)
	var dusk = (1.0 - smoothstep(0.08, 0.42, absf(height))) * daylight
	var direction = Vector3(-0.6 * cos(cycle), height * 0.85, -0.75).normalized()
	sky_material.set_shader_parameter("world_time", clock)
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("cloud_cover", lerpf(0.35, 0.85, rain_amount))
	sky_material.set_shader_parameter("sun_direction", direction)
	var light_direction = direction if daylight > 0.15 else Vector3(-direction.x, maxf(0.18, -direction.y), -direction.z).normalized()
	sunlight.look_at(-light_direction, Vector3.UP)
	sunlight.light_color = Color("#a9d1ee").lerp(Color("#ffe2ac"), daylight)
	sunlight.light_color = sunlight.light_color.lerp(Color("#ffbb85"), dusk * 0.55)
	sunlight.light_energy = lerpf(0.15, 0.84, daylight) * lerpf(1.0, 0.65, rain_amount)
	environment.environment.ambient_light_energy = lerpf(0.22, 0.4, daylight)
	environment.environment.ambient_light_color = Color("#7f95bd").lerp(Color("#a5c4d5"), daylight)
	environment.environment.fog_density = lerpf(0.0018, 0.0052, rain_amount)
	environment.environment.fog_height_density = 0.0 if indoors else 0.035
	var fog_colors := ["#a3c6c3", "#91bac8", "#b9c6a1", "#92bcbe", "#d0dfea", "#d8bc89", "#93aea0", "#c3b18f", "#93acaa"]
	var fog_day = Color(fog_colors[clampi(biome, 0, fog_colors.size() - 1)])
	if state.expanded_world:
		fog_day = Color(["#a0b8aa", "#b3bc9b", "#b4c4b0", "#dac29b", "#8d7b7e", "#857c98", "#b1c8d5"][clampi(biome - 9, 0, 6)])
		environment.environment.fog_density = 0.0016 if biome == 14 else 0.00028 if biome == 13 else 0.00012
		environment.environment.fog_height_density = 0
		if biome in [12, 13]: rain.visible = false; rain_amount = 0
		if not indoors:
			if biome == 14:
				sky_material.set_shader_parameter("daylight", minf(daylight, 0.15)); sky_material.set_shader_parameter("cloud_cover", 0.94)
				sunlight.light_energy *= 0.24; environment.environment.ambient_light_energy = 0.2; environment.environment.ambient_light_color = Color("#79859b")
				environment.environment.fog_density = 0.0028; fog_day = Color("#645d77")

				var keep_distance = Vector2(player.position.x, player.position.z).distance_to(world.atlas.nodes.blackthornkeep)
				var keep_weight = 1 - smoothstep(180, 460, keep_distance)
				environment.environment.fog_density = lerpf(0.0028, 0.00072, keep_weight)
				sunlight.light_energy *= lerpf(1.0, 1.7, keep_weight)
				environment.environment.ambient_light_energy = lerpf(0.2, 0.3, keep_weight)
			elif biome == 13:
				sky_material.set_shader_parameter("daylight", daylight * 0.65); sky_material.set_shader_parameter("cloud_cover", 0.88)
				sunlight.light_energy *= 0.65
			elif biome == 12:
				var sand = smoothstep(0.45, 0.85, sin(clock / 55 - 0.8))
				environment.environment.fog_density = lerpf(0.00012, 0.0075, sand); sky_material.set_shader_parameter("cloud_cover", lerpf(0.3, 0.92, sand))
				if sand > 0.15 and not _sandstorm_warned: toast("A sandstorm is approaching. Follow the road markers and seek shelter.", 6); _sandstorm_warned = true
				if sand < 0.03: _sandstorm_warned = false
			motes.material_override = B.mat("#bca174", 0, 0.03) if biome == 12 else B.mat("#a79f9c", 0, 0.02) if biome == 13 else B.mat("#b2b4cf", 0, 0.08) if biome in [14, 15] else B.mat("#e5d79a", 0, 0.5)
	if not indoors and biome == 5:
		rain.visible = false
		rain_amount *= 0.18
		environment.environment.fog_density *= 0.65
	elif not indoors and biome == 6:
		environment.environment.fog_density *= 1.6
	fog_day = fog_day.lerp(Color("#c59b94"), dusk * 0.45)
	environment.environment.fog_light_color = Color("#485a80").lerp(fog_day, daylight)
	if indoors:
		sunlight.light_energy *= 0.06
		environment.environment.ambient_light_energy = 0.28
		environment.environment.ambient_light_color = Color("#718f9e")
		environment.environment.fog_density = 0.003
	_grade_lighting(daylight, height, indoors)
	if world.water != null:
		world.water.material_override.set_shader_parameter("world_time", clock)
	if rain.visible:
		for i in range(rain.multimesh.instance_count):
			var x = fposmod(i * 17.13, 30.0) - 15
			var z = fposmod(i * 13.73, 30.0) - 15
			var y = fposmod(i * 0.43 - clock * 12, 15.0)
			rain.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, -0.12).scaled(Vector3.ONE * rain_amount), player.global_position + Vector3(x, y, z)))
	for i in range(30):
		var p = player.global_position + Vector3(sin(i * 31.8 + clock * 0.04) * 12, 1.4 + sin(i * 3.1 + clock * 0.3) * 1.1, cos(i * 17.3 + clock * 0.07) * 12)
		var scale_value = 1.0
		if state.expanded_world and biome in [12, 13]:
			p = player.global_position + Vector3(fposmod(i * 7.7 + clock * (4.0 if biome == 12 else 0.5), 30) - 15, fposmod(i * 0.79 - clock * 0.35, 7), fposmod(i * 11.3 + clock * 0.4, 30) - 15)
			scale_value = 2.2 if biome == 12 else 1.3
		motes.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale_value), p))

## Lighting grade layered on top of the per-biome weather above: golden-hour warmth and
## sun-tinted fog when the sun is low, a cool moonlit night, and a hero lantern that only
## blooms when it is actually dark.
func _grade_lighting(daylight: float, sun_height: float, indoors: bool) -> void:
	var env: Environment = environment.environment
	var golden := (1.0 - smoothstep(0.06, 0.42, sun_height)) * smoothstep(-0.1, 0.04, sun_height)
	var night := 1.0 - smoothstep(-0.22, 0.06, sun_height)
	if not indoors:
		sunlight.light_color = sunlight.light_color.lerp(Color("#ff9d55"), golden * 0.7)
		sunlight.light_energy *= lerpf(1.0, 1.2, golden)
		sunlight.shadow_opacity = lerpf(1.0, 0.7, night)
		env.ambient_light_color = env.ambient_light_color.lerp(Color("#b08aa6"), golden * 0.45).lerp(Color("#56689f"), night * 0.35)
		env.fog_light_color = env.fog_light_color.lerp(Color("#eba06a"), golden * 0.4)
		env.fog_sun_scatter = lerpf(0.04, 0.5, golden)
	else:
		sunlight.shadow_opacity = 1.0
		env.fog_sun_scatter = 0.0
	if is_instance_valid(player) and player.visual != null and player.visual.get("lantern_gain") != null:
		var dark := clampf(1.0 - daylight + night * 0.3 + (0.55 if indoors else 0.0), 0.0, 1.0)
		player.visual.lantern_gain = lerpf(0.3, 1.15, dark)

func apply_settings() -> void:
	var quality = int(state.settings.quality)
	load("res://scripts/imported_assets.gd").set_quality(quality)
	if effects != null: effects.configure(state.settings)
	var cloth = load("res://scripts/cape_cloth.gd")
	cloth.STEP = 1.0 / 60.0 if quality == 2 else 1.0 / 30.0
	cloth.ITERATIONS = 3 if quality == 2 else 2
	sunlight.shadow_enabled = quality > 0
	# One shadow cascade on Balanced halves the shadow pass; High keeps two cascades.
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sunlight.directional_shadow_max_distance = [24.0, 24.0, 56.0][quality]
	sunlight.directional_shadow_fade_start = 0.75
	RenderingServer.directional_shadow_atlas_set_size(2048 if quality > 0 else 1024, true)
	# The governor lowers this when the GPU can't keep up and restores it when it can.
	if governor == null:
		governor = preload("res://scripts/frame_governor.gd").new(); add_child(governor)
	governor.set_ceiling([0.65, 0.8, 1.0][quality])
	get_viewport().msaa_3d = Viewport.MSAA_2X if quality == 2 else Viewport.MSAA_DISABLED
	# Coarser mesh LOD on phones' lower tiers: forests are thousands of tree triangles each.
	get_viewport().mesh_lod_threshold = [4.0, 2.5, 1.0][quality]
	# Low quality holds a steady 30 fps, which reads smoother on weak phones than a frame
	# rate bouncing between 30 and 50.
	Engine.max_fps = 30 if quality == 0 else 60
	# High quality: a soft glow so spell cores, lanterns and flames bloom slightly.
	var env: Environment = environment.environment
	env.glow_enabled = quality == 2
	env.glow_intensity = 0.55; env.glow_strength = 0.9; env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.92; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for detail in get_tree().get_nodes_in_group("world_detail"):
		detail.visibility_range_end = [40.0, 55.0, 85.0][quality]
	_save_current_state()

func _save_current_state() -> bool:
	if state == null: return false
	_sync_stone_drops()
	return state.save_game() if world_ready else state.save_title_settings()

func interact_with(node: Node3D) -> void:
	if mode != "play" or not usable_node(node):
		return
	if is_instance_valid(scrappers) and scrappers.interact(node): return
	if expeditions != null and expeditions.interact(node): return
	if quests != null and quests.interact(node): return
	if is_instance_valid(deep_adventure) and deep_adventure.interact(node): return
	var kind = str(node.get_meta("kind", ""))
	var id = str(node.get_meta("id", ""))
	if kind == "spell_altar":
		open_spell_archive(node)
	elif kind == "carry" and str(node.get_meta("material", "")) != "":
		player.interact_node(node)
	elif kind == "material":
		_collect_resource(node)
	elif kind == "npc":
		state.taken["talked_" + id] = true
		vendor = node
		dialogue_name = str(node.get_meta("name", "Traveler"))
		dialogue_lines = node.get_meta("dialogue", ["A good road always leads to another story."]).duplicate()
		for i in range(dialogue_lines.size()): dialogue_lines[i] = str(dialogue_lines[i]).replace("light shards", "Light Essence").replace("light shard", "Light Essence")
		dialogue_index = 0
		shop_id = str(node.get_meta("shop", ""))
		set_mode("dialogue")
	elif kind == "entrance":
		var destination: Vector3 = node.get_meta("destination", Vector3.INF)
		if node.has_meta("destination_local"):
			var frame = node.get_node_or_null(NodePath(node.get_meta("destination_frame", NodePath("..")))) as Node3D
			if not is_instance_valid(frame): return
			destination = frame.to_global(node.get_meta("destination_local", Vector3.INF))
		if teleport_player(destination, str(node.get_meta("location_name", "The open road")), true, node.has_meta("destination_local")):
			var into = world.interior_at(destination)
			if into != "": state.taken["entered_" + into] = true
			state.save_game()
			audio.cue("bag")
	elif kind == "camp":
		camp_action = "camp"
		set_mode("camp")
	elif kind == "workbench":
		set_mode("craft")
	elif kind == "death_echo":
		if journey_save != null: journey_save.recover_echo(node)
	elif kind in ["tree", "rock"]:
		if has_harvest_tool(node):
			face_node(node)
			player.attack()
		else:
			toast("Equip an axe to chop this tree." if kind == "tree" else "Equip a pickaxe to mine this deposit.")
	elif kind in ["shard", "tonic"]:
		if node.get_meta("world_drop", false): _claim_world_loot(node)
		elif state.collect(id, kind):
			burst(node.global_position, Color("#f1d69b"))
			node.queue_free()
			audio.cue("collect")
	elif kind == "checkpoint":
		if journey_save != null:
			if journey_save.rest_at(player.position):
				audio.cue("shrine")
				toast("Lantern rested. Journey saved, strength restored, guardians awakened.")
			return
		state.checkpoint = player.global_position
		state.health = state.max_health
		state.save_game()
		audio.cue("collect")
		toast("Lantern kindled. Health restored. Journey saved.")
	elif kind == "regional_cache":
		if node.has_meta("site") and world.regional != null: world.regional.claim_cache(node)
		elif world.mosswake != null: world.mosswake.claim_cache(node)
	elif kind == "regional_mechanism":
		if world.regional != null: world.regional.operate(node)
	elif kind == "regional_discovery":
		world.atlas_scenery.Discoveries.claim(self, node)
	elif kind == "chest":
		preload("res://scripts/treasure_loot.gd").claim(self, node, id, preload("res://scripts/treasure_loot.gd").bundle(id))
	elif kind == "lore":
		lore_title = "A NOTE FOR THE LOST"
		lore_text = str(node.get_meta("text", ""))
		set_mode("lore")


func usable_node(node: Node3D, reach: float = 2.9) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or player.global_position.distance_to(node.global_position) > reach:
		return false
	if node.get_meta("ring_only", false):
		var offset = player.global_position - node.global_position
		if Vector2(offset.x, offset.z).length() > 0.95 or absf(offset.y) > 1.4: return false
	var target = node.global_position + Vector3.UP * float(node.get_meta("interaction_height", 0.9 if str(node.get_meta("kind", "")) in ["npc", "tree"] else 0.35))
	var hit = player.ray(player.global_position + Vector3.UP * 1.0, target, 1 | 8)
	return hit.is_empty() or hit.collider == node or node.is_ancestor_of(hit.collider)

func face_node(node: Node3D) -> void:
	var direction = node.global_position - player.global_position
	if Vector2(direction.x, direction.z).length() > 0.05:
		player.visual.rotation.y = atan2(-direction.x, -direction.z)

func combat_target() -> Node3D:
	var nearest: Node3D
	var distance = 2.8
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var offset = enemy.global_position - player.global_position
		if offset.length() < distance and absf(offset.y) < 1.6 and player.ray(player.position + Vector3.UP, enemy.global_position + Vector3.UP, 1 | 8).is_empty():
			nearest = enemy
			distance = offset.length()
	return nearest

func begin_context_action(prefer_interaction: bool = false) -> void:
	if mode != "play" or context_held or not player.active: return
	context_held = true; pickup_committed = false; pickup_elapsed = 0.0; pickup_progress = 0.0
	if placement_item() != "":
		commit_placement(); pickup_committed = true; return
	if magic != null and magic.has_levitated_object():
		context_kind = "magic"; pickup_target = magic.levitated_target(); return
	if is_instance_valid(player.held_body):
		context_kind = "carried"; pickup_target = player.held_body; return
	if not prefer_interaction and combat_target() != null:
		contextual_b(); pickup_committed = true; return
	var node = player.nearest_interaction()
	if usable_node(node):
		var kind = str(node.get_meta("kind", ""))
		if kind == "rock" and not has_harvest_tool(node) and preload("res://scripts/loose_stone_carry.gd").liftable(node):
			# No pickaxe in hand: hold to pick the rock up (a tap still explains mining).
			if player.climbing or player.mantle_time > 0 or player.visual.is_throwing() or player.visual.grapple_active():
				cancel_context_action(); return
			context_kind = "pickup"; pickup_target = node; return
		if kind in ["tree", "rock"]:
			if has_harvest_tool(node): harvest_target = node
			interact_with(node); return
		if kind in ["carry", "material"]:
			if player.climbing or player.mantle_time > 0 or player.visual.is_throwing() or player.visual.grapple_active():
				cancel_context_action(); return
			context_kind = "pickup"; pickup_target = node; return
	if prefer_interaction:
		if usable_node(node): interact_with(node); pickup_committed = true
		else: cancel_context_action()
		return
	contextual_b(); pickup_committed = true

func end_context_action(canceled: bool = false) -> void:
	if not context_held: return
	var kind := context_kind
	var target = pickup_target
	var committed := pickup_committed
	var valid_pickup := _context_target_valid() if kind == "pickup" else false
	cancel_context_action()
	if canceled or committed or mode != "play" or not player.active: return
	if kind == "magic":
		if magic != null and magic.has_levitated_object() and magic.levitated_target() == target: magic.release_levitated_object(true)
	elif kind == "carried":
		if is_instance_valid(target) and player.held_body == target: player.throw_held()
	elif valid_pickup:
		if target.get_meta("breakable_barrel", false): face_node(target); player.attack()
		elif str(target.get_meta("kind", "")) == "rock": interact_with(target)
		elif str(target.get_meta("kind", "")) == "carry" and str(target.get_meta("material", "")) == "": toast("Hold E to lift this object." if desktop_enabled() else "Hold B to lift this object.")
		else: _collect_resource(target)

func cancel_context_action() -> void:
	context_held = false; context_kind = ""; pickup_committed = false
	pickup_target = null; pickup_elapsed = 0.0; pickup_progress = 0.0; harvest_target = null

func _context_target_valid() -> bool:
	if not is_instance_valid(pickup_target): return false
	return mode == "play" and player.active and not player.climbing and player.mantle_time <= 0 and player.dodge_time <= 0 and not player.visual.is_throwing() and not player.visual.grapple_active() and not is_instance_valid(player.held_body) and usable_node(pickup_target) and combat_target() == null

func _tick_context_action(dt: float) -> void:
	if not context_held or pickup_committed: return
	if context_kind in ["magic", "carried"]:
		var valid: bool = mode == "play" and player.active and is_instance_valid(pickup_target)
		if context_kind == "magic": valid = valid and magic != null and magic.has_levitated_object() and magic.levitated_target() == pickup_target
		else: valid = valid and player.held_body == pickup_target and not player.throw_pending
		if not valid: cancel_context_action(); return
		pickup_elapsed += maxf(0.0, dt); pickup_progress = clampf(pickup_elapsed / PICKUP_HOLD_TIME, 0.0, 1.0)
		if pickup_elapsed >= PICKUP_HOLD_TIME:
			pickup_committed = true; pickup_progress = 0.0
			if context_kind == "magic": magic.release_levitated_object(false)
			else: player.release_held(false)
			toast("Gently released · tap E to throw next time." if desktop_enabled() else "Gently released · tap B to throw next time.")
		return
	if is_instance_valid(harvest_target):
		if not usable_node(harvest_target) or harvest_target.get_meta("kind", "") not in ["tree", "rock"] or not has_harvest_tool(harvest_target) or combat_target() != null or player.climbing or player.mantle_time > 0 or float(player.get("dodge_time")) > 0:
			cancel_context_action()
		elif player.attack_cooldown <= 0 and player.visual.attack_time <= 0:
			face_node(harvest_target); player.attack()
		return
	if not _context_target_valid(): cancel_context_action(); return
	pickup_elapsed += maxf(0.0, dt)
	var liftable := (pickup_target is RigidBody3D and str(pickup_target.get_meta("kind", "")) == "carry") or preload("res://scripts/loose_stone_carry.gd").liftable(pickup_target)
	pickup_progress = clampf(pickup_elapsed / PICKUP_HOLD_TIME, 0.0, 1.0) if liftable else 0.0
	if liftable and pickup_elapsed >= PICKUP_HOLD_TIME:
		pickup_committed = true; player.interact_node(pickup_target); pickup_progress = 0.0

func _collect_resource(node: Node3D) -> bool:
	if not usable_node(node):
		return false
	if node.get_meta("world_drop", false): return _claim_world_loot(node)
	if node.get_meta("regional_food", false): return gather_regional_food(node)
	var kind = str(node.get_meta("kind", ""))
	if kind not in ["carry", "material"]:
		return false
	var id = str(node.get_meta("id", ""))
	if id == "":
		return false
	var item = str(node.get_meta("material", "")) if kind == "carry" else str(node.get_meta("item", ""))
	if kind == "material" and item in ["stone", "iron", "crystal"] and not node.get_meta("loose_stone", false):
		toast("Use an equipped pickaxe to mine deposits.")
		return false
	var amount = 1 if kind == "carry" else int(node.get_meta("amount", 1))
	var reward_id = "gathered_" + id if kind == "carry" else id
	if not state.harvest(reward_id, item, amount):
		if item in State.INVENTORY_IDS and int(state.items.get(item, 0)) + amount > State.MAX_ITEMS:
			toast("Your satchel is full of " + Crafting.item_name(item) + ".")
		return false
	state.taken[id] = true
	burst(node.global_position + Vector3.UP * 0.4, Color("#bcefc6"))
	node.queue_free()
	audio.cue("collect")
	toast("Gathered %d %s" % [amount, Crafting.item_name(item)])
	state.save_game()
	return true

func gather_regional_food(node: Node3D) -> bool:
	if not usable_node(node) or not node.get_meta("regional_food", false) or node.is_queued_for_deletion(): return false
	var id = str(node.get_meta("id", "")); var item = str(node.get_meta("item", ""))
	if item not in ["marshmallow", "chocolate_bar", "graham_cracker"] or state.taken.has(id): return false
	var old_items: Dictionary = state.items.duplicate(true); var old_slots: Array = state.inventory_slots().duplicate(true); var old_flags: Dictionary = state.taken.duplicate(true)
	if not state.harvest(id, item, 1): return false
	if not state.save_game():
		state.items = old_items; state._slots = old_slots; state.taken = old_flags; toast("Could not save the harvest. The food was kept on the tree."); return false
	node.queue_free(); audio.cue("collect"); toast("Gathered " + Crafting.item_name(item) + ". Combine all three ingredients at a lit camp for a s'more."); return true

func contextual_b() -> void:
	if mode != "play":
		return
	if magic != null and magic.has_levitated_object():
		magic.release_levitated_object(true)
		return
	if placement_item() != "":
		commit_placement()
		return
	if is_instance_valid(player.held_body):
		player.throw_held()
		return
	var enemy = combat_target()
	if enemy != null:
		face_node(enemy)
		player.attack()
		return
	var node = player.nearest_interaction()
	if usable_node(node):
		if node.get_meta("kind", "") == "carry":
			player.interact_node(node)
		elif node.get_meta("kind", "") == "material":
			begin_context_action()
		else:
			interact_with(node)
	else:
		player.attack()

func context_label() -> String:
	if magic != null and magic.has_levitated_object(): return "THROW"
	if placement_item() != "": return "PLACE" if placement_solution(placement_item()).valid else "CANNOT PLACE"
	if is_instance_valid(player.held_body): return "THROW"
	if combat_target() != null: return "CAST" if player.grimoire_equipped() else "STRIKE"
	var n = player.closest
	if not is_instance_valid(n): return "CAST" if player.grimoire_equipped() else "STRIKE"
	if n.get_meta("breakable_barrel", false): return "BREAK · HOLD TO LIFT"
	return str({"npc": "TALK", "tree": "CHOP" if has_harvest_tool(n) else "AXE NEEDED", "rock": "MINE" if has_harvest_tool(n) else "PICKAXE NEEDED", "carry": "COLLECT", "material": "COLLECT", "workbench": "CRAFT", "spell_altar": "SPELL COLLECTION", "death_echo": "RECOVER", "camp": "REST", "entrance": "EXPLORE"}.get(str(n.get_meta("kind", "")), "INTERACT"))

func has_harvest_tool(node: Node3D) -> bool:
	if not is_instance_valid(node): return false
	var needed = "axe" if node.get_meta("kind", "") == "tree" else "pickaxe"
	return Crafting.weapon_metadata(state.equipment).get("tool", "") == needed

func choose_resource(action: String) -> void:
	if mode != "resource" or not usable_node(resource_node):
		return
	var node = resource_node
	resource_node = null
	set_mode("play")
	if action == "gather":
		var item = str(node.get_meta("material", ""))
		var id = str(node.get_meta("id", ""))


		if id != "" and state.harvest("gathered_" + id, item, 1):
			state.taken[id] = true
			audio.cue("collect")
			toast("Gathered " + Crafting.item_name(item))
			node.queue_free()
	elif action == "lift":
		player.interact_node(node)

func harvest_strike(origin: Vector3, facing: Vector3) -> void:
	for tree in get_tree().get_nodes_in_group("harvestable"):
		if not has_harvest_tool(tree): continue
		var delta = tree.global_position - origin
		if delta.length() < 2.6 and absf(delta.y) < 1.3 and facing.dot(delta.normalized()) > 0.2 and usable_node(tree):
			var left = int(tree.get_meta("chop_left", 3)) - (2 if state.equipment == "stone_axe" else 1)
			tree.set_meta("chop_left", maxi(1, left))
			burst(tree.global_position + Vector3.UP * 0.8, Color("#d0ab76"), 6)
			audio.cue("land", 1.2)
			if left <= 0 and tree.hit(4):
				toast("Tree felled  +4 timber")
				comic_impact("TIMBER!", tree.global_position + Vector3.UP * 2)
				state.save_game()
			return
	for rock in get_tree().get_nodes_in_group("mineable"):
		if not has_harvest_tool(rock): continue
		var delta = rock.global_position - origin
		if delta.length() < 2.6 and absf(delta.y) < 1.4 and facing.dot(delta.normalized()) > 0.2 and usable_node(rock):
			var point = rock.global_position + Vector3.UP * 0.45
			if rock.hit(1):
				burst(point, Color("#c3d1cb"), 8)
				audio.cue("impact", 1.25)
				comic_impact("CRACK!", point)
				if rock.mined:
					toast("Mined " + Crafting.item_name(str(rock.get_meta("item", "stone"))))
					state.save_game()
			else: toast("Make room in your satchel before mining more.")
			return

func advance_dialogue() -> void:
	if mode != "dialogue": return
	if dialogue_index + 1 < dialogue_lines.size():
		dialogue_index += 1
	elif shop_id != "":
		set_mode("trade")
	else:
		set_mode("play")

func trade_item(id: String, buying: bool) -> void:
	if mode != "trade" or not usable_node(vendor, 3.3) or not Crafting.SHOPS.has(shop_id): return
	if buying and id not in Crafting.SHOPS[shop_id]: return
	var success = state.buy_item(id) if buying else state.sell_item(id)
	if success:
		audio.cue("collect")
		state.save_game()
	else:
		toast("Not enough Light Essence or supplies for that trade.")

func near_camp() -> bool:
	return is_instance_valid(camp) and player.position.distance_to(camp.global_position) < 4.5

func near_workbench() -> bool:
	if player == null: return false
	for table in get_tree().get_nodes_in_group("workbench"):
		if world.is_ancestor_of(table) and usable_node(table, 3.4): return true
	return false

func crafting_size() -> int:
	return 3 if near_workbench() else 2

func _ensure_craft_grid() -> void:
	var cells = crafting_size() * crafting_size()
	if craft_grid.size() != cells:
		craft_grid.clear()
		for i in range(cells): craft_grid.append({})

func clear_craft_grid() -> void:
	craft_grid.clear()
	var size_value = crafting_size() if world != null and player != null else 2
	for i in range(size_value * size_value): craft_grid.append({})

func available_count(item: String) -> int:
	var total = int(state.items.get(item, 0))
	for cell in craft_grid:
		if cell.get("item", "") == item: total -= int(cell.get("amount", 0))
	return maxi(0, total)

func stage_recipe(id: String) -> bool:
	if mode not in ["bag", "craft"] or not Crafting.RECIPES.has(id): return false
	_ensure_craft_grid()
	var pattern = Crafting.recipe_grid(id, crafting_size())
	if pattern.is_empty():
		toast("This pattern needs a 3 × 3 crafting table.")
		return false
	if not state.can_craft(id, near_camp(), near_workbench()):
		toast("Gather the recipe ingredients and use its required station.")
		return false
	craft_grid.assign(pattern.duplicate(true))
	return true

func grid_place(index: int, item: String, amount: int = 1) -> bool:
	if mode not in ["bag", "craft"] or item not in State.INVENTORY_IDS or amount <= 0 or amount > 64: return false
	_ensure_craft_grid()
	if index < 0 or index >= craft_grid.size(): return false
	var old: Dictionary = craft_grid[index]
	var value = amount + (int(old.get("amount", 0)) if old.get("item", "") == item else 0)
	var available = available_count(item) + (int(old.get("amount", 0)) if old.get("item", "") == item else 0)
	if value > 64 or value > available: return false
	craft_grid[index] = {"item": item, "amount": value}
	return true

func grid_remove(index: int) -> void:
	if mode not in ["bag", "craft"]: return
	_ensure_craft_grid()
	if index >= 0 and index < craft_grid.size(): craft_grid[index] = {}

func craft_output() -> String:
	_ensure_craft_grid()
	var result = Crafting.match_grid(craft_grid, crafting_size())
	return str(result.get("id", ""))

func _craft_checkpoint() -> Dictionary:
	return {"items": state.items.duplicate(true), "unlocked": state.unlocked.duplicate(true),
		"upgrades": state.upgrades.duplicate(true), "slots": state.inventory_slots().duplicate(true),
		"health": state.health, "mana": state.mana, "stamina": state.stamina}

func _restore_craft(checkpoint: Dictionary) -> void:
	state.items = checkpoint.items
	state.unlocked = checkpoint.unlocked
	state.upgrades = checkpoint.upgrades
	state._slots = checkpoint.slots
	state.refresh_stats()
	state.health = checkpoint.health; state.mana = checkpoint.mana; state.stamina = checkpoint.stamina
	toast("Could not save this craft. Your ingredients are safe.")

func craft_current() -> bool:
	if mode not in ["bag", "craft"]: return false
	_ensure_craft_grid()
	var checkpoint := _craft_checkpoint()
	var reserved: Array = craft_grid.duplicate(true)
	var id = state.craft_from_grid(craft_grid, crafting_size(), near_camp(), near_workbench())
	if id == "":
		toast("Check the pattern, materials and crafting station.")
		return false
	if not state.save_game():
		_restore_craft(checkpoint)
		craft_grid = reserved
		return false
	craft_last = id
	craft_flash = 1
	audio.cue("collect")
	return true

func quick_craft(id: String, amount: int = 1) -> bool:
	if mode not in ["bag", "craft"] or amount < 1 or amount > 5 or not Crafting.RECIPES.has(id):
		return false
	var recipe: Dictionary = Crafting.RECIPES[id]
	var at_fire := near_camp()
	var at_table := near_workbench()
	if str(recipe.station) == "bench" and not at_table:
		toast("Bring this recipe to a crafting table.")
		return false
	if str(recipe.station) == "camp" and not at_fire:
		toast("Make this beside a lit campfire.")
		return false
	for item in recipe.needs:
		var missing := int(recipe.needs[item]) * amount - int(state.items.get(item, 0))
		if missing > 0:
			toast("Need %d more %s." % [missing, Crafting.item_name(str(item))])
			return false


	var checkpoint := _craft_checkpoint()
	var trial = State.new()
	trial.items = state.items.duplicate(true)
	trial.unlocked = state.unlocked.duplicate(true)
	trial.upgrades = state.upgrades.duplicate(true)
	trial._slots = state.inventory_slots().duplicate(true)
	trial.health = state.health
	for index in range(amount):
		if not trial.craft_recipe(id, at_fire, at_table):
			toast("Already made, or no room for the full batch. Your materials are safe.")
			return false
	state.items = trial.items
	state.unlocked = trial.unlocked
	state.upgrades = trial.upgrades
	state._slots = trial._slots
	state.refresh_stats()
	if not state.save_game():
		_restore_craft(checkpoint)
		return false
	clear_craft_grid()
	craft_last = id
	craft_flash = 1.0
	if audio != null: audio.cue("collect")
	toast("Made %d × %s" % [int(recipe.amount) * amount, Crafting.item_name(str(recipe.output))])
	return true

func activate_hotbar(index: int) -> void:
	if mode not in ["play", "bag", "craft"] or player.visual.supply_pour.active() or player.visual.is_throwing() or player.visual.grapple_active() or float(player.get("dodge_time")) > 0: return
	var slots: Array = state.inventory_slots()
	if index < 0 or index >= 9 or index >= slots.size(): return
	var item: String = str(slots[index].get("item", ""))
	var quick_use: bool = mode == "play" and item in ["tonic", "mana_potion", "coffee", "roasted_marshmallow", "smore"]
	if quick_use and not _quick_supply_hands_free():
		toast("Free your hands before using a supply.")
		return
	if state.select_hotbar(index):
		cancel_context_action()
		player.cancel_magic()
		player.end_ability_aim(false)
		player.cancel_beam()
		player.melee_contact = -1
		player.queued_strike = false
		var needs_supply: bool = state.mana < state.max_mana if item == "mana_potion" else state.health < state.max_health
		if quick_use and needs_supply:
			use_supply(item)
		else:
			if audio != null: audio.cue("ui")
			if quick_use: toast("%s is full · %s kept." % ["Mana" if item == "mana_potion" else "Health", Crafting.item_name(item)])
			state.save_game()
		update_placement_preview()

func _quick_supply_hands_free() -> bool:
	return player.active and state.health > 0 and not player.visual.supply_pour.active() and not player.climbing and not player.swimming and player.mantle_time <= 0.0 and player.visual.attack_time <= 0.0 and not is_instance_valid(player.held_body) and player.visual.bag_progress < 0.04 and (magic == null or not magic.has_levitated_object())

func setup_workbenches() -> void:
	placed_workbench = null
	for site in world.get_locations():
		if site.kind not in ["village", "town", "city"]: continue
		var table = Workbench.new()
		var p: Vector2 = site.pos + Vector2(-4.5, 5)
		table.position = Vector3(p.x, world.height_at(p.x, p.y), p.y)
		table.set_meta("id", str(site.id) + "_workbench")
		world.add_child(table)
	if state.workbench_placed: restore_workbench()

func restore_workbench() -> void:
	if is_instance_valid(placed_workbench): placed_workbench.queue_free()
	placed_workbench = Workbench.new()
	placed_workbench.position = state.workbench_position
	placed_workbench.set_meta("id", "travelers_workbench")
	world.add_child(placed_workbench)

func place_workbench() -> void:
	ready_item("crafting_table")

func selected_hand_item() -> String:
	return state.selected_item() if state.equipment == "fists" else ""

func ready_item(id: String) -> bool:
	if mode not in ["play", "bag", "craft"] or player.visual.is_throwing() or player.visual.grapple_active() or is_instance_valid(player.held_body):
		return false
	if not state.ready_item(id): return false
	player.cancel_melee()
	player.cancel_beam()
	player.end_ability_aim(false)
	set_mode("play")
	state.save_game()
	if id in ["camp_kit", "crafting_table"]:
		toast("Find a green outline, then press B to place. Select another quick slot to put it away.", 5)
	update_placement_preview()
	return true

func placement_item() -> String:
	var id: String = state.selected_item()
	return id if state.equipment == "fists" and id in ["camp_kit", "crafting_table"] and not is_instance_valid(player.held_body) else ""

func placement_solution(id: String) -> Dictionary:
	return Placement.solve(self, id)

func update_placement_preview() -> void:
	if player == null: return
	var wall_spell: Dictionary = state.equipped_spell() if state != null else {}
	var wall_active: bool = mode == "play" and player.grimoire_equipped() and not wall_spell.is_empty() and wall_spell.form == "wall" and magic != null and not player.climbing and not player.swimming
	if wall_active:
		if not is_instance_valid(spell_wall_preview):
			spell_wall_preview = SpellWallPreview.new(); add_child(spell_wall_preview); spell_wall_preview.setup(magic)
		var wall_aim: Dictionary = player.ability_target()
		spell_wall_preview.update_spell(wall_spell, wall_aim.point, true)
	elif is_instance_valid(spell_wall_preview): spell_wall_preview.visible = false
	if player.visual.has_method("set_held_item"):
		player.visual.set_held_item(selected_hand_item() if mode == "play" else "")
	if not is_instance_valid(placement_preview): return
	var id := placement_item()
	if mode != "play" or id == "" or player.ability_aiming or player.visual.is_throwing() or player.visual.grapple_active():
		placement_preview.visible = false
		return
	placement_preview.show_solution(placement_solution(id))

func commit_placement() -> bool:
	var id := placement_item()
	if id == "" or mode != "play": return false

	var solution := placement_solution(id)
	if not solution.valid:
		toast(str(solution.reason), 2)
		update_placement_preview()
		return false
	if id == "camp_kit":
		if not _place_camp_transaction(solution.point, bool(solution.get("terrain", false))): return false
	else:
		var previous = state.workbench_position; var was_placed = state.workbench_placed
		state.items[id] -= 1; state.workbench_position = solution.point; state.workbench_placed = true
		state.inventory_slots()
		if not state.save_game():
			state.items[id] += 1; state.workbench_position = previous; state.workbench_placed = was_placed; state.inventory_slots(); toast("Placement could not be saved. Your table was kept."); return false
		restore_workbench()
	audio.cue("collect")
	burst(solution.point + Vector3.UP * 0.5, Color("#8cf1b7"), 12)
	toast("Crafting table placed. B nearby opens the 3 × 3 grid." if id == "crafting_table" else "Camp ready. B at the fire to rest, brew, roast or sleep.")
	update_placement_preview()
	return true

func award_unique(id: String) -> bool:
	var awarded: bool = state.award_unique(id)
	if awarded:
		audio.cue("shrine")
		state.save_game()
	return awarded

func craft_recipe(id: String) -> void:
	if mode not in ["craft", "camp"]: return
	if state.craft_recipe(id, near_camp(), near_workbench()):
		craft_last = id
		craft_flash = 1
		audio.cue("collect")
		state.save_game()
	else:
		toast("Gather the listed materials" + (" and craft this at a camp." if Crafting.RECIPES.get(id, {}).get("station", "") == "camp" else " to assemble this."))

func equip_weapon(id: String) -> void:
	if mode == "bag" and state.equip_weapon(id):
		player.cancel_magic()
		player.visual.set_weapon(id)
		audio.cue("grip")
		state.save_game()

func ready_grimoire() -> bool:
	if mode not in ["play", "bag", "grimoire"] or state.unlocked.get("grimoire", false) != true: return false
	cancel_context_action()
	player.clear_controls()
	if is_instance_valid(player.held_body): player.release_held(false)
	if not state.equip_weapon("grimoire"): return false
	player.visual.set_held_item("")
	player.visual.set_weapon("grimoire")
	state.save_game()
	if audio != null: audio.cue("grip")
	toast("Grimoire equipped. Choose a spell slot, then Cast.")
	return true

func teleport_player(point: Vector3, title: String = "", persist: bool = true, authored_landing: bool = false, menu_travel: bool = false) -> bool:
	var limit = 16000.0 if state.expanded_world else 10000.0
	if mode not in ["play", "pause", "dev", "journal"] or not is_instance_valid(player) or not is_instance_valid(world) or not point.is_finite() or point.length() > limit: return false
	return _place_teleport(point, title, persist, authored_landing, menu_travel)

func request_teleport(point: Vector3, title: String, completed: Callable = Callable()) -> bool:
	var limit = 16000.0 if state.expanded_world else 10000.0
	if is_instance_valid(travel_loading) or mode not in ["dev", "pause", "journal"] or not is_instance_valid(player) or not is_instance_valid(world) or not point.is_finite() or point.length() > limit: return false
	travel_loading = preload("res://scripts/travel_loading.gd").new()
	add_child(travel_loading)
	travel_loading.begin(self, _castle_entry_point(point), title, completed)
	return true

func _place_teleport(point: Vector3, title: String, persist: bool, authored_landing: bool, menu_travel: bool, prepared: bool = false) -> bool:


	point = _castle_entry_point(point)
	var original: Vector3 = player.global_position
	var saved_position: Vector3 = state.player_position
	var interior: String = world.interior_at(point)
	var elevated: bool = interior.is_empty() and point.y - world.surface_height_at(point.x, point.z) > 1.0
	if interior.is_empty() and not authored_landing: point.y = maxf(point.y, world.surface_height_at(point.x, point.z) + 0.2)
	cancel_context_action()
	player.reset_motion()
	if is_instance_valid(player.held_body): player.release_held(false)
	if magic != null: magic.clear_effects()
	if hud != null: hud.release_pointers()
	if not prepared: world.stream_at(point, true)
	if menu_travel: point = preload("res://scripts/travel_entrances.gd").building_point(self, point)
	point = _building_entry_point(point)
	var shape := CapsuleShape3D.new()
	shape.radius = Player.BODY_RADIUS + 0.02; shape.height = Player.HERO_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.collision_mask = 1 | 4 | 8
	query.exclude = [player.get_rid()]
	query.margin = 0.02
	var arrival := Vector3.INF


	for ring in range(1 if authored_landing else 5):
		for step in range(1 if ring == 0 else 12):
			var offset := Vector3(cos(float(step) * TAU / 12.0), 0, sin(float(step) * TAU / 12.0)) * float(ring) * 0.85
			var candidate := point + offset
			if interior.is_empty() and not authored_landing: candidate.y = maxf(point.y, world.surface_height_at(candidate.x, candidate.z) + 0.2) if elevated else world.surface_height_at(candidate.x, candidate.z) + 0.2
			elif world.interior_at(candidate) != interior: continue
			query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * (Player.HERO_HEIGHT * 0.5 + 0.01))
			if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				arrival = candidate
				break
		if arrival.is_finite(): break
	if not arrival.is_finite():
		if not prepared: world.stream_at(original, true)
		return false
	player.global_position = arrival
	state.player_position = arrival
	if state.health > 0 and persist and not state.save_game():
		player.global_position = original
		state.player_position = saved_position
		if not prepared: world.stream_at(original, true)
		toast("Could not save this arrival. Returned to your previous location.")
		return false
	player.yaw = 0.0; player.pitch = 0.1
	player.camera.global_position = arrival + Vector3(0, 2, player.camera_distance)
	player.update_camera(1.0)
	region = -1; region_text = title.to_upper(); region_time = 4.0
	return true

func is_world_preview() -> bool:
	return true

func discover_atlas_capitals() -> void:
	if world == null or world.atlas == null or not is_instance_valid(player): return
	for site in world.atlas.sites():
		if site.kind != "city" or state.taken.get("atlas_visited_" + site.id, false): continue
		if Vector2(player.position.x, player.position.z).distance_to(site.pos) < 95:
			state.taken["atlas_visited_" + site.id] = true
			toast(site.name + " discovered. Free travel is available in your journal.", 5)

func can_fast_travel_atlas(id: String) -> bool:
	return atlas_travel_reason(id).is_empty()

func atlas_travel_reason(id: String) -> String:
	if not state.expanded_world or world == null or world.atlas == null or not is_instance_valid(player) or state.health <= 0: return "Unavailable"
	if mode not in ["play", "pause", "journal"] or not state.taken.get("atlas_visited_" + id, false): return "Visit to unlock"
	if is_instance_valid(player.held_body): return "Set down the object"
	if player.climbing or player.mantle_time > 0 or absf(player.velocity.y) > 0.8: return "Land safely first"
	var departure = false
	for site in world.atlas.sites():
		if site.kind == "city" and state.taken.get("atlas_visited_" + site.id, false) and Vector2(player.position.x, player.position.z).distance_to(site.pos + Vector2(0, 67)) < 18: departure = true; break
	if not departure: return "Use a travel plaza"
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.get("health") != null and enemy.health > 0 and enemy.global_position.distance_to(player.global_position) < 22: return "Finish the encounter"
	for site in world.atlas.sites():
		if site.id == id and site.kind == "city": return ""
	return "Capital travel only"

func fast_travel_atlas(id: String) -> bool:
	if not can_fast_travel_atlas(id): return false
	for site in world.atlas.sites():
		if site.id != id: continue
		var original: Vector3 = player.global_position; var saved: Vector3 = state.player_position
		var arrival: Vector3 = preload("res://scripts/travel_entrances.gd").settlement_point(world, site)
		if not teleport_player(arrival, site.name, false, false, true): return false
		if not state.save_game():
			player.global_position = original; state.player_position = saved; player.reset_motion(); world.stream_at(original, true); player.update_camera(1)
			toast("The journey could not be saved. You stayed here.", 4); return false
		set_mode("play"); return true
	return false

func request_fast_travel_atlas(id: String) -> bool:
	if not can_fast_travel_atlas(id): return false
	for site in world.atlas.sites():
		if site.id == id:
			return request_teleport(preload("res://scripts/travel_entrances.gd").settlement_point(world, site), site.name)
	return false

func use_supply(id: String) -> bool:
	if mode not in ["bag", "play"] or state.health <= 0 or available_count(id) <= 0: return false
	if not pending_supply.is_empty() or player.visual.supply_pour.active(): return false
	if mode == "play" and not _quick_supply_hands_free(): return false
	if id not in ["tonic", "mana_potion", "coffee"]: return _commit_supply(id)
	if id == "mana_potion":
		if not is_finite(state.mana) or state.mana < 0 or state.mana >= state.max_mana: return false
	elif state.health >= state.max_health: return false
	if mode == "bag": set_mode("play")
	player.cancel_magic(); player.cancel_beam(); player.end_ability_aim(false)
	player.aim_blend = 0.0; player.visual.aim_weight = 0.0
	var action = player.visual.supply_pour
	if not action.use_contact.is_connected(_supply_contact): action.use_contact.connect(_supply_contact)
	if not action.use_ended.is_connected(_supply_ended): action.use_ended.connect(_supply_ended)
	if not player.visual.begin_supply_pour(id): return false
	pending_supply = id
	return true

func _supply_ended() -> void:
	pending_supply = ""

func _supply_contact(id: String) -> void:
	if pending_supply != id: return
	pending_supply = ""
	if state.health <= 0 or mode != "play" or not _commit_supply(id): player.visual.supply_pour.cancel()

func _commit_supply(id: String) -> bool:
	var previous_health: int = state.health
	var previous_mana: float = state.mana
	var previous_items: Dictionary = state.items.duplicate(true)
	var previous_slots: Array = state.inventory_slots()
	if not state.use_supply(id): return false
	if not state.save_game():
		state.health = previous_health; state.mana = previous_mana; state.items = previous_items; state._slots = previous_slots
		toast("The supply could not be saved. Your item was kept.")
		return false
	if audio != null: audio.cue("collect", 1.08)
	if mode == "play":
		burst(player.global_position + Vector3.UP * 0.65, Color("#65b8ff") if id == "mana_potion" else Color("#a6e2a4"), 10)
		if id == "mana_potion": toast("%s · restored %s mana" % [Crafting.item_name(id), String.num(state.mana - previous_mana, 1)])
		else: toast("%s · restored %d health" % [Crafting.item_name(id), state.health - previous_health])
	return true

func track_location(id: String) -> void:
	for site in navigation_routes():
		if str(site.id) == id:
			tracked_location = id
			return

func navigation_routes() -> Array:
	var result: Array = world.get_locations() + world.landmarks
	if is_instance_valid(wizard_tower) and not state.expanded_world: result.append(wizard_tower.destination())
	if expeditions != null: result.append_array(expeditions.routes())
	if quests != null: result.append_array(quests.destinations())
	return result

func navigation_destination(id: String) -> Dictionary:


	if world == null: return {}
	var selected: Dictionary = {}
	if world.has_method("navigation_location"): selected = world.navigation_location(id)
	else:
		for site in world.get_locations():
			if str(site.id) == id: selected = site.duplicate(true); break
	if not selected.is_empty(): return selected
	for site in world.landmarks:
		if str(site.id) == id: return site.duplicate(true)
	if is_instance_valid(wizard_tower) and not state.expanded_world:
		var tower = wizard_tower.destination()
		if str(tower.id) == id: return tower
	if expeditions != null:
		for site in expeditions.routes():
			if str(site.id) == id: return site.duplicate(true)
	if quests != null:
		for site in quests.destinations():
			if str(site.id) == id: return site.duplicate(true)
	return {}

func near_spell_altar() -> bool:
	if not is_instance_valid(wizard_tower) or not is_instance_valid(player) or not is_instance_valid(world): return false
	var altar = wizard_tower.get_altar()
	if not is_instance_valid(altar) or not world.is_ancestor_of(altar) or not altar.is_in_group("magic_altar"): return false
	return player.global_position.distance_to(altar.global_position) <= 2.9 and not player.climbing and player.mantle_time <= 0.0 and not is_instance_valid(player.held_body)

func open_grimoire() -> void:
	if mode not in ["play", "grimoire", "spellforge", "pause"]: return
	set_mode("grimoire")

func open_spellforge(_altar = null) -> bool:

	return false

func open_spell_archive(altar = null) -> bool:
	if mode not in ["play", "grimoire"] or not near_spell_altar(): return false
	if altar != null and altar != wizard_tower.get_altar(): return false
	open_grimoire()
	return mode == "grimoire"

func _restore_spell_snapshot(snapshot: Dictionary) -> void:
	state.spellbook = snapshot.book
	state.spell_slots = snapshot.slots
	state.active_spell_slot = snapshot.active

func _spell_snapshot() -> Dictionary:
	return {"book": state.spellbook.duplicate(true), "slots": state.spell_slots.duplicate(), "active": state.active_spell_slot}

func save_custom_spell(_raw: Dictionary) -> bool:
	return false

func delete_custom_spell(_id: String) -> bool:
	return false

func equip_custom_spell(id: String, slot: int = -1) -> bool:
	if mode not in ["grimoire", "spellforge"]: return false
	var previous := _spell_snapshot()
	if not state.equip_spell(id, slot): return false
	if not state.save_game():
		_restore_spell_snapshot(previous)
		return false
	return true

func select_spell_slot(index: int) -> void:
	if mode not in ["play", "grimoire", "spellforge"]: return
	if state.select_spell_slot(index):
		if audio != null: audio.cue("ui", 1.1)

func track_wizard_tower() -> void:
	tracked_location = "wizard_tower"
	toast("Wizard tower marked on your compass. Follow the violet roof west of the cave road.")

func restore_camp() -> void:
	if is_instance_valid(camp): camp.free()
	camp = Camp.new(); camp.position = state.camp_position; world.add_child(camp)

	if state.camp_placed:
		var found := false
		for record in state.camp_clearings:
			if Vector2(record.position[0] - camp.position.x, record.position[2] - camp.position.z).length() < 0.5 and float(record.packed_at) < 0: found = true
		if not found and absf(camp.position.y - world.surface_height_at(camp.position.x, camp.position.z)) < 0.4:
			var anchors = _camp_anchor_snapshot()
			world.prepare_camp(state.camp_position); _align_camp_anchors(anchors)

func _place_camp_transaction(point: Vector3, terrain_ground: bool = true) -> bool:
	if not point.is_finite() or int(state.items.camp_kit) <= 0: return false
	var previous = {"items": state.items.duplicate(true), "slots": state.inventory_slots(), "point": state.camp_position, "placed": state.camp_placed, "clearings": state.camp_clearings.duplicate(true), "checkpoint": state.checkpoint, "bench": state.workbench_position, "echo": state.death_echo_position, "position": state.player_position, "dirty": world.camp_ground.dirty_positions.duplicate(), "completed": world.camp_ground.completed.duplicate()}
	var anchors = _camp_anchor_snapshot()
	state.items.camp_kit -= 1
	if terrain_ground:
		world.camp_ground.place(point); world.fine_surface_grids.clear(); _align_camp_anchors(anchors)
	else:
		world.camp_ground.pack(); state.camp_position = point; state.camp_placed = true
	var committed_player = player.position if is_instance_valid(player) else state.player_position
	if terrain_ground and world.camp_ground.near_point(Vector2(committed_player.x, committed_player.z)):
		committed_player.y = world.surface_height_at(committed_player.x, committed_player.z) + 0.035
	state.player_position = committed_player
	state.inventory_slots()
	if not state.save_game():
		state.items = previous.items; state._slots = previous.slots; state.camp_position = previous.point; state.camp_placed = previous.placed; state.camp_clearings = previous.clearings; state.checkpoint = previous.checkpoint; state.workbench_position = previous.bench; state.death_echo_position = previous.echo; state.player_position = previous.position; world.camp_ground.dirty_positions = previous.dirty; world.camp_ground.completed = previous.completed; world.fine_surface_grids.clear()
		toast("Camp could not be saved. Your camp kit was kept."); return false
	if terrain_ground: world.refresh_camp_ground()
	restore_camp()
	if is_instance_valid(player): player.position = committed_player
	return true

func _camp_anchor_snapshot() -> Array:
	var result = []
	for pair in [["checkpoint", 0.4], ["workbench_position", 0.95], ["death_echo_position", 0.4]]:
		if pair[0] == "workbench_position" and not state.workbench_placed: continue
		if pair[0] == "death_echo_position" and not state.death_echo_active: continue
		var point: Vector3 = state.get(pair[0]); var old_height: float = world.surface_height_at(point.x, point.z)
		if absf(point.y - old_height) < 0.45: result.append({"key": pair[0], "point": point, "footprint": pair[1]})
	return result

func _align_camp_anchors(anchors: Array) -> void:
	for anchor in anchors:
		var point: Vector3 = anchor.point
		var horizontal = Vector2(point.x, point.z)
		var changed = world.camp_ground.near_point(horizontal, anchor.footprint) or world.camp_ground.dirty_positions.any(func (site): return horizontal.distance_to(site) <= World.CampGround.OUTER + anchor.footprint)
		if not changed: continue
		point.y = world.surface_height_at(point.x, point.z, false) - 1.0
		state.set(anchor.key, _saved_ground_point(point, anchor.footprint, true, true))

func place_camp() -> void: ready_item("camp_kit")

func _camp_exit_point() -> Vector3:
	var point = camp.position + Vector3(1.5, 0, 1.6)
	var support: Dictionary = player.ray(point + Vector3.UP * 0.8, point - Vector3.UP * 2, 1 | 8)
	point.y = support.position.y + 0.035 if not support.is_empty() and support.normal.y > 0.5 else world.surface_height_at(point.x, point.z) + 0.035
	return point

func camp_command(action: String) -> void:
	if action == "leave": set_mode("play"); return
	if not near_camp(): return
	if action == "pack": _pack_camp(); return
	if action not in ["coffee", "roast", "smore", "sit", "sleep"]: return
	if combat_target() != null or (journey_save != null and journey_save._near_threat()):
		toast("Find a quiet moment away from danger before resting."); return
	if action == "coffee" and not _brew_camp_coffee(): return
	if action == "roast" and not _roast_camp_marshmallow(): return
	if action == "smore": _make_camp_smore(); return
	if mode not in ["rest", "sleep"]:
		rest_camera = Vector2(player.yaw, player.pitch); rest_zoom = Vector2(player.camera_distance, player.zoom_target)
	set_mode("sleep" if action == "sleep" else "rest")
	camp_action = action; _camp_coffee_started = false; _sleep_roll_started = false
	player.position = camp.position + Camp.REST_SPOT
	player.visual.rotation = Vector3(0, atan2(Camp.REST_SPOT.x, Camp.REST_SPOT.z), 0)
	player.visual.begin_camp_pose(action); player.visual.roast_hover_target = camp.roast_target()
	player.visual.rest_target = camp.position + Vector3.UP * 0.63
	player.yaw = player.visual.rotation.y + PI - 0.45; player.pitch = 0.25
	player.camera_distance = 3.6; player.zoom_target = 3.6; player.camera_idle = 0
	if action == "sleep":
		player.position = camp.position + Vector3(-2, 0, -2) + Basis(Vector3.UP, -0.2) * Vector3(0, 0, 2)
		player.visual.rotation.y = -0.2; player.yaw = -0.2; player.pitch = 0.35; camp.stage_sleep_pack(player.visual); sleep_left = 5.2
	player.update_camera(1)
	state.player_position = _camp_exit_point()

func _tick_camp(dt: float) -> void:
	if not is_instance_valid(camp): set_mode("play"); return
	var age = mode_age + dt
	if camp_action == "coffee" and age >= 1.25 and not _camp_coffee_started:
		_camp_coffee_started = true; player.visual.begin_supply_pour("coffee")
	if mode != "sleep": return
	var z = lerpf(2.0, 0.05, smoothstep(0, 1.2, age))
	player.position = camp.position + Vector3(-2, 0, -2) + Basis(Vector3.UP, -0.2) * Vector3(0, 0, z)
	player.visual.rotation.y = -0.2 + PI * smoothstep(1.2, 1.65, age)
	if age >= 1.65 and not _sleep_roll_started:
		_sleep_roll_started = true; player.visual.start_sleep_roll()
	player.visual.head.position.z = -0.15 * player.visual.sleep_blend
	if camp.sleep_pack != null: camp.sleep_pack.visible = age >= 2.55
	sleep_left = maxf(0, 5.2 - age)
	if sleep_left <= 0: _finish_camp_sleep()

func _finish_camp_sleep() -> void:
	if combat_target() != null or (journey_save != null and journey_save._near_threat()):
		set_mode("camp"); toast("Something disturbed your rest."); return
	var arrival = _camp_exit_point()
	var previous = {"health": state.health, "stamina": state.stamina, "time": state.journey_time, "checkpoint": state.checkpoint, "position": state.player_position}
	state.journey_time = (floorf(state.journey_time / 540) + 1) * 540
	state.health = state.max_health; state.stamina = state.max_stamina; state.checkpoint = arrival; state.player_position = arrival
	if not state.save_game():
		state.health = previous.health; state.stamina = previous.stamina; state.journey_time = previous.time; state.checkpoint = previous.checkpoint; state.player_position = previous.position
		set_mode("camp"); toast("Rest could not be saved. Try sleeping again."); return
	reset_enemies(); set_mode("camp"); toast("Morning light. Strength restored and journey saved.")

func _pack_camp() -> bool:
	if mode not in ["camp", "rest"] or not is_instance_valid(camp) or not state.camp_placed: return false
	if int(state.items.camp_kit) >= State.MAX_ITEMS: toast("Make room for your camp kit first."); return false
	var previous = {"items": state.items.duplicate(true), "slots": state.inventory_slots(), "clearings": state.camp_clearings.duplicate(true)}
	state.camp_placed = false; world.camp_ground.pack(); state.award_reward("camp_kit", 1)
	if not state.save_game():
		state.items = previous.items; state._slots = previous.slots; state.camp_clearings = previous.clearings; state.camp_placed = true
		toast("Packing could not be saved. Your camp is still here."); return false
	set_mode("play"); camp.free(); camp = null
	world.ground_mat.set_shader_parameter("clearings", world.camp_ground.shader_records())
	preload("res://scripts/building_paths.gd").sync_material(world.ground_mat)
	toast("Camp packed. The old clearing will slowly grow green again."); return true

func _brew_camp_coffee() -> bool:
	if state.health >= state.max_health: toast("Health is full · coffee beans kept."); return false
	var previous = {"health": state.health, "items": state.items.duplicate(true), "slots": state.inventory_slots(), "position": state.player_position}
	if not state.craft_recipe("coffee", true): toast("Bring two coffee beans."); return false
	var used: bool = state.use_supply("coffee"); state.player_position = _camp_exit_point()
	if used and state.save_game(): return true
	state.health = previous.health; state.items = previous.items; state._slots = previous.slots; state.player_position = previous.position
	toast("Coffee could not be saved. Your beans were kept."); return false

func _roast_camp_marshmallow() -> bool:
	var previous = {"health": state.health, "items": state.items.duplicate(true), "slots": state.inventory_slots()}
	if not state.craft_recipe("roasted_marshmallow", true): toast("Bring a marshmallow to roast."); return false
	if state.health < state.max_health: state.use_supply("roasted_marshmallow")
	if state.save_game(): return true
	state.health = previous.health; state.items = previous.items; state._slots = previous.slots
	toast("Roasting could not be saved. Your marshmallow was kept."); return false

func _make_camp_smore() -> bool:
	var items: Dictionary = state.items.duplicate(true); var slots: Array = state.inventory_slots().duplicate(true)
	if not state.craft_recipe("smore", true): toast("Bring one marshmallow, one chocolate bar and one graham cracker."); return false
	if not state.save_game(): state.items = items; state._slots = slots; toast("Could not save the s'more. All ingredients were kept."); return false
	toast("Camp s'more made. Use it from your satchel or hotbar to restore three health."); return true

func toast(message: String, seconds: float = 4.0) -> void:
	toast_text = message
	toast_time = seconds

func beam(start: Vector3, end: Vector3, color: Color, width: float, duration: float) -> Node3D:
	comic_impact("FZZZT!", start + Vector3.UP * 0.45, Color("#b8fff0"))
	var node = effects.beam(start, end, color, width, duration)
	# Where a strong beam lands it blooms into the same contact star, shockwave and glow
	# every spell impact uses.
	if width >= 0.12 and magic != null and magic.get("presentation") != null:
		var palette := {"element": "light", "color": color.lerp(Color("1e8fff"), 0.7), "accent": color.lerp(Color("8ff0ff"), 0.6), "core_color": Color("e9fdff"), "size": 0.3, "intensity": 3}
		magic.presentation.glyph(end, palette, "impact", clampf(duration * 0.8, 0.3, 0.9), clampf(width * 3.0, 0.4, 1.6))
	return node

func comic_impact(word: String, point: Vector3, color: Color = Color("#f4d887")) -> void:
	comic_word = word
	comic_point = point
	comic_color = color
	comic_time = 0.55

func make_rope(start: Vector3, end: Vector3) -> MeshInstance3D:
	return effects.rope(start, end)

func swing_effect(pos: Vector3, direction: Vector3, variant: int) -> void:
	effects.swing(pos, direction, variant)

func foot_effect(pos: Vector3, water_contact: bool = false, strength: float = 0.25) -> void:
	effects.footfall(pos, water_contact, strength)

func sheltered_at(pos: Vector3) -> bool:


	for house in get_tree().get_nodes_in_group("settlement_building"):
		if not world.is_ancestor_of(house) or house.is_queued_for_deletion() or not house.has_meta("wooden_floor"): continue
		var half: Vector2 = house.get_meta("wooden_floor"); var local: Vector3 = house.to_local(pos)
		if absf(local.x) < half.x and absf(local.z) < half.y and local.y > -0.3 and local.y < float(house.get_meta("shelter_height", 3.6)): return true
	return false

func step_surface(pos: Vector3) -> String:
	var inside = world.interior_at(pos)
	if not inside.is_empty():
		return "stone"
	for house in get_tree().get_nodes_in_group("settlement_building"):
		if not world.is_ancestor_of(house) or not house.has_meta("wooden_floor"): continue
		var half: Vector2 = house.get_meta("wooden_floor"); var local: Vector3 = house.to_local(pos)
		if absf(local.x) < half.x and absf(local.z) < half.y and local.y > -0.3 and local.y < 0.6: return "wood"
	var biome = world.biome_at(pos.x, pos.z)
	if biome == 12: return "sand"
	if biome == 15 or biome == 1: return "glass"
	if biome in [13, 14] or world.path_distance(Vector2(pos.x, pos.z)) < 3: return "stone"
	return "grass"

func step_sound(pos: Vector3) -> void:
	if audio != null: audio.step(step_surface(pos))

func burst(pos: Vector3, color: Color, count: int = 9) -> void:
	effects.burst(pos, color, count)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and state != null:
		if not navigate_back():
			_save_current_state()
			get_tree().quit()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and is_inside_tree() and state != null:
		if hud != null:
			hud.release_pointers()
			if hud.dev_menu != null and is_instance_valid(hud.dev_menu.search_entry): hud.dev_menu.search_entry.release_focus()
			if hud.magic_ui != null: hud.magic_ui.cancel_draft()
		if mode in ["play", "rest", "sleep"]:
			set_mode("pause")
		_save_current_state()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if hud != null and hud.fieldbook != null and hud.fieldbook.workshop != null and hud.fieldbook.workshop.has_method("handle_input") and hud.fieldbook.workshop.handle_input(event): return
	if hud != null and hud.dev_menu != null and hud.dev_menu.handle_input(event): return
	if hud != null and hud.magic_ui != null and hud.magic_ui.handle_input(event): return
	if event.keycode == KEY_F:
		if event.pressed and mode == "play":
			hud.begin_ability_hold(-3)
		elif not event.pressed:
			hud.release(-3, mode != "play")
		return
	if event.keycode == KEY_SPACE:
		if event.pressed and mode == "play": player.begin_primary_action()
		elif not event.pressed and player != null: player.end_primary_action(mode != "play")
		return
	if event.keycode == KEY_E:
		if event.pressed and mode == "play": begin_context_action()
		elif not event.pressed: end_context_action(mode != "play")
		return
	if not event.pressed:
		return
	if mode == "play":
		if event.keycode == KEY_V:
			player.cast_spell()
			return
		if event.keycode == KEY_G:
			open_grimoire()
			return
		if event.keycode == KEY_X:
			select_spell_slot((state.active_spell_slot + 1) % 4)
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			activate_hotbar(int(event.keycode) - KEY_1)
			return
		if event.keycode == KEY_R:
			player.dodge()
			return
		if event.keycode == KEY_TAB:
			player.toggle_lock_on()
			return
		if event.keycode == KEY_T:
			player.cycle_lock_target()
			return
	if event.keycode == KEY_ESCAPE:
		navigate_back()
	elif event.keycode == KEY_I and mode in ["play", "bag"]:
		set_mode("bag" if mode == "play" else "play")
	elif mode == "play":
		match event.keycode:
			KEY_C: player.toggle_climb()
			KEY_Q: cycle_ability()
			KEY_J: set_mode("journal")

func cycle_ability() -> void:
	player.end_ability_aim(false)
	player.cancel_beam()
	if state.has_ability("hook"):
		player.ability_id = "hook" if player.ability_id == "beam" else "beam"
		audio.cue("ui")
	else:
		toast("The grappling hand sleeps in the eastern crystal grove.")
