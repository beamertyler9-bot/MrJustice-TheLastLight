extends SceneTree
var game
var failures: Array[String] = []
func expect(ok: bool, label: String):
 if not ok: failures.append(label); print("FAIL: ", label)
func settle(n: int = 3):
 for i in range(n): await physics_frame
func _initialize():
 create_timer(240).timeout.connect(func (): print("FAIL: runtime timeout"); quit(1)); call_deferred("run")
func run():
 game = load("res://scenes/main.tscn").instantiate(); game.defer_world_until_journey = true; root.add_child(game)
 await process_frame
 await game.start_journey(false); game.set_mode("play"); game.story.close_reading()
 var world = game.world; var society = world.society
 var site: Dictionary = world.atlas.sites().filter(func (s): return s.id == "brindlewick")[0]
 var p = site.pos + Vector2(10, 25)
 expect(game.teleport_player(Vector3(p.x, world.height_at(p.x, p.y) + 0.25, p.y), "Brindlewick QA", false), "teleport")
 await settle()
 var ward = society.live.get("brindlewick:0")
 expect(ward != null, "town district exists")
 expect(society.get_node_or_null("BrindlewickBlueprintInfrastructure") != null, "approved infrastructure exists")
 if ward == null or society.get_node_or_null("BrindlewickBlueprintInfrastructure") == null: quit(1); return
 expect(world.locations.get_node_or_null("Brindlewick") == null, "no duplicate legacy settlement")
 var plots = load("res://scripts/locations.gd").city_plots(site, 64127)
 for plot in plots:
  var house = ward.get_node_or_null("Building_%d" % plot.index)
  expect(house != null, "building %d" % plot.index)
  if house == null: continue
  expect(house.get_meta("building_title") == plot.title, "title %d" % plot.index)
  expect(house.has_node("GroundedFoundation"), "foundation %d" % plot.index)
  expect(house.has_node("BuildingApproach"), "approach %d" % plot.index)
  var entry = house.get_node("BuildingEntry"); var exit = house.get_node("BuildingExit")
  game.teleport_player(entry.global_position, "Entry QA", false, true); game.interact_with(entry); await settle(1)
  expect(game.player.global_position.distance_to(house.to_global(entry.get_meta("destination_local"))) < 0.6, "enter %d" % plot.index)
  if not plot.shop.is_empty():
   var keepers = world.residents.filter(func (n): return is_instance_valid(n) and n.get_meta("shop_owner_id", "") == house.get_meta("plot_id"))
   expect(keepers.size() == 1, "one specialist %d" % plot.index)
   if not keepers.is_empty(): expect(keepers[0].get_meta("shop") == plot.shop, "stock %d" % plot.index)
  game.interact_with(exit); await settle(1)
  expect(game.player.global_position.distance_to(entry.global_position) < 0.6, "exit %d" % plot.index)
 var ids = ["merchant", "smith", "resident", "gardener", "mason", "baker", "weaver", "porter"]
 for id in ids:
  var people = world.residents.filter(func (n): return is_instance_valid(n) and n.get_meta("id", "") == "brindlewick_" + id)
  expect(people.size() == 1, "preserve quest giver " + id)
  if id == "smith" and not people.is_empty(): expect(people[0].get_meta("race") == "orc" and people[0].get_meta("name") == "Bramm Emberhand", "original orc smith")
 var art = society.get_node("BrindlewickBlueprintInfrastructure")
 expect(art.has_node("VillageGreen"), "central green")
 expect(art.has_node("VillageGreen/VillageNoticeboard/NoticeBoardSurface"), "visible noticeboard")
 expect(art.has_node("BlacksmithYard/CompactWorkingForge"), "working forge yard")
 expect(art.get_node("BlacksmithYard").position.x == 58, "forge yard on east side")
 var yard = art.get_node("BlacksmithYard")
 expect(yard.has_node("GroundedFoundation"), "yard foundation closes terrain gaps")
 for x in range(52, 65, 2):
  for z in range(9, 28, 2): expect(yard.global_position.y > world.surface_height_at(x, z) + 0.04, "forge platform clear of terrain at %d,%d" % [x, z])
 var forge = art.get_node("BlacksmithYard/brindlewick_yard_forge")
 game.teleport_player(forge.global_position + Vector3(0, 0.25, 0), "Forge QA", false, true)
 game.interact_with(forge); expect(game.mode == "craft", "forge opens crafting"); game.set_mode("play")

 p = site.pos + Vector2(22, -20); game.teleport_player(Vector3(p.x, world.height_at(p.x, p.y) + 0.25, p.y), "Lane QA", false)
 await settle(4); var begin: Vector3 = game.player.global_position
 game.player.yaw = PI; game.player.control_move = Vector2(0, -1)
 for i in range(200): await physics_frame
 game.player.control_move = Vector2.ZERO
 expect(game.player.global_position.distance_to(begin) > 12, "walk eastern service lane")

 var far = Vector3(site.pos.x, world.height_at(site.pos.x, site.pos.y) + 150, site.pos.y)
 game.teleport_player(far, "LOD QA", false, true); world.stream_at(far, true); await settle(2)
 var proxies = 0
 for proxy in society.proxy_live.values():
  if proxy.get_meta("site", "") == "brindlewick":
   proxies += 1; expect(proxy.has_node("GroundedFoundation"), "distant foundation %d" % proxy.get_meta("plot_index"))
 expect(proxies == 12, "all twelve far houses")
 p = site.pos + Vector2(10, 25); game.teleport_player(Vector3(p.x, world.height_at(p.x, p.y) + 0.25, p.y), "Return QA", false); await settle(3)
 expect(society.find_children("BrindlewickBlueprintInfrastructure", "Node3D", false, false).size() == 1, "one infrastructure after return")
 for id in ids: expect(world.residents.filter(func (n): return is_instance_valid(n) and n.get_meta("id", "") == "brindlewick_" + id).size() == 1, "one returning quest giver " + id)

 var away = Vector3(450, world.height_at(450, 450) + 0.3, 450)
 game.teleport_player(away, "Unload QA", false); await settle(3)
 expect(society.get_node_or_null("BrindlewickBlueprintInfrastructure") == null, "horizontal infrastructure unload")
 expect(not society.live.has("brindlewick:0"), "horizontal district unload")

 var old_bench = game.state.workbench_placed; var old_pos: Vector3 = game.state.workbench_position
 game.state.workbench_placed = true; game.state.workbench_position = Vector3(42, world.height_at(42, -49), -49)
 game.teleport_player(Vector3(10, world.height_at(10, 25) + 0.3, 25), "Occupied inn QA", false); await settle(3)
 expect(society.live["brindlewick:0"].get_node_or_null("Building_3") == null, "saved bench protects inn footprint")
 var inn_proxy = society.proxy_live.get("brindlewick_home_3")
 expect(inn_proxy == null or not inn_proxy.visible, "saved bench protects distant inn footprint")
 game.teleport_player(away, "Unload occupied QA", false); await settle(3)
 game.state.workbench_position = Vector3(49, world.height_at(49, 15), 15)
 game.teleport_player(Vector3(10, world.height_at(10, 25) + 0.3, 25), "Displaced smith QA", false); await settle(3)
 var displaced = world.residents.filter(func (n): return is_instance_valid(n) and n.get_meta("id", "") == "brindlewick_smith")
 expect(displaced.size() == 1, "displaced smith remains available")
 if not displaced.is_empty():
  var smith = displaced[0]
  expect(not load("res://scripts/world_occupancy.gd").conflicts(game.state, Rect2(Vector2(smith.global_position.x, smith.global_position.z) - Vector2.ONE, Vector2.ONE * 2)), "displaced smith stands clear of bench")
  expect(game.quests.offer_for("brindlewick_smith").get("id", "") == "forge_fuel", "displaced smith still offers original quest")
  game.teleport_player(smith.global_position + Vector3(1.8, 0.3, 0), "Smith trade QA", false, true); game.interact_with(smith)
  if game.mode != "dialogue" or load("res://scripts/merchants.gd").kind(game.shop_id) != "blacksmith":
   print("SMITH_DIAGNOSTIC mode=", game.mode, " shop=", game.shop_id, " usable=", game.usable_node(smith), " player=", game.player.global_position, " smith=", smith.global_position, " shop_meta=", smith.get_meta("shop"))
  expect(game.mode == "dialogue" and load("res://scripts/merchants.gd").kind(game.shop_id) == "blacksmith", "displaced smith trade interaction")
  game.set_mode("play")
 game.teleport_player(away, "Unload smith QA", false); await settle(3)
 game.state.workbench_position = Vector3(58, world.height_at(58, 18), 18)
 game.teleport_player(Vector3(10, world.height_at(10, 25) + 0.3, 25), "Occupied yard QA", false); await settle(3)
 expect(not society.get_node("BrindlewickBlueprintInfrastructure").has_node("BlacksmithYard"), "saved bench protects forge yard")
 game.teleport_player(away, "Restore QA", false); await settle(3)
 game.state.workbench_placed = old_bench; game.state.workbench_position = old_pos
 game.teleport_player(Vector3(10, world.height_at(10, 25) + 0.3, 25), "Final return QA", false); await settle(3)
 expect(society.get_node("BrindlewickBlueprintInfrastructure").has_node("BlacksmithYard"), "unoccupied yard restored")
 expect(society.live["brindlewick:0"].get_node_or_null("Building_3") != null, "unoccupied inn restored")
 if failures.is_empty(): print("BRINDLEWICK_RUNTIME_PASS portals=12 quest_givers=8 lod_houses=12"); quit(0)
 else: quit(1)
