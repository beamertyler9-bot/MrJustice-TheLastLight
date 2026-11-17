extends SceneTree
var game
var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
 if not value: failures.append(message); print("FAIL: ", message)
func check_foundation(house: Node3D, label: String):
 var foundation = house.get_node_or_null("GroundedFoundation")
 expect(foundation != null, "continuous foundation " + label)
 if foundation == null: return
 for sample in foundation.get_meta("terrain_samples"):
  expect(foundation.get_meta("bottom_world") < sample.y - 0.2, "foundation meets soil " + label)
 expect(is_equal_approx(foundation.get_meta("floor_world"), house.global_position.y), "foundation matches floor " + label)
func settle(n: int = 3):
 for i in range(n): await physics_frame
func _initialize():
 create_timer(240).timeout.connect(func (): print("FAIL: runtime test timeout"); quit(1))
 call_deferred("run")
func run():
 game = load("res://scenes/main.tscn").instantiate(); game.defer_world_until_journey = true; root.add_child(game)
 await process_frame
 await game.start_journey(false); game.set_mode("play"); game.story.close_reading()
 print("RUNTIME_WORLD_READY")
 var world = game.world; var society = world.society; var site: Dictionary
 for s in world.atlas.sites():
  if s.id == "alderhaven": site = s
 var data = society.plan(world.atlas, site)
 var count = 0
 for district in data.districts:
  var p: Vector2 = site.pos + district.p
  if district.index == 3: p = site.pos + Vector2(0, 22)
  var target = Vector3(p.x, world.surface_height_at(p.x, p.y) + 0.22, p.y)
  expect(game.teleport_player(target, "QA district", false), "teleport to district %d" % district.index)
  await settle()
  var ward = society.live.get("alderhaven:%d" % district.index)
  expect(is_instance_valid(ward), "stream district %d" % district.index)
  if not is_instance_valid(ward): continue
  for plot in data.plots:
   if plot.district != district.index: continue
   var house = ward.get_node_or_null("Building_%d" % plot.index)
   expect(is_instance_valid(house), "build plot %d" % plot.index)
   if not is_instance_valid(house): continue
   expect(house.get_meta("building_title") == plot.title, "title plot %d" % plot.index)
   expect(house.has_node("BuildingApproach"), "path plot %d" % plot.index)
   expect(house.has_node("BuildingEntry/EntranceRing"), "entry ring plot %d" % plot.index)
   check_foundation(house, "detailed plot %d" % plot.index)
   if plot.index == 2:
    expect(not house.has_node("CoveredForgeBay"), "smith stays inside approved footprint")
    expect(house.has_node("HouseholdInterior/CompactWorkingForge"), "smith has an internal working forge")
   var entry = house.get_node("BuildingEntry"); var exit = house.get_node("BuildingExit")
   game.teleport_player(entry.global_position, "QA entry", false, true)
   game.interact_with(entry)
   await settle(1)
   var expected: Vector3 = house.to_global(entry.get_meta("destination_local"))
   expect(game.player.global_position.distance_to(expected) < 0.6, "enter plot %d" % plot.index)
   if not str(plot.shop).is_empty():
    var owners = world.residents.filter(func (n): return is_instance_valid(n) and n.get_meta("shop_owner_id", "") == house.get_meta("plot_id"))
    expect(not owners.is_empty(), "specialist vendor plot %d" % plot.index)
    if not owners.is_empty(): expect(owners[0].get_meta("shop", "") == plot.shop, "specialist stock plot %d" % plot.index)
   game.interact_with(exit)
   await settle(1)
   expect(game.player.global_position.distance_to(entry.global_position) < 0.6, "exit plot %d" % plot.index)
   count += 1
  print("RUNTIME_DISTRICT_PASS ", district.name)
 expect(count == 36, "all 36 portals checked")
 var proxy_count = 0
 for proxy in society.proxy_live.values():
  if proxy.get_meta("site", "") != "alderhaven": continue
  check_foundation(proxy, "distant plot %d" % proxy.get_meta("plot_index")); proxy_count += 1
 expect(proxy_count == 36, "all 36 distant foundations checked")
 var pier = society.alderhaven_art.get_node("CargoPier")
 expect(not preload("res://scripts/water_profile.gd").sample(pier.get_meta("start")).is_empty(), "pier terminates over water")
 expect(society.alderhaven_art.find_children("CargoPierRamp*", "Node3D", false, false).size() == 1, "one shoreward pier ramp")
 var plaza = site.pos + Vector2(8, 0)
 game.teleport_player(Vector3(plaza.x, world.height_at(plaza.x, plaza.y) + 0.3, plaza.y), "QA plaza", false)
 await settle(5)
 game.state.taken["atlas_visited_alderhaven"] = true; game.state.taken["atlas_visited_bellcrown"] = true
 game.player.velocity = Vector3.ZERO; game.player.climbing = false
 expect(game.atlas_travel_reason("bellcrown") == "", "depart from Graham Market travel plaza")

 var start: Vector2 = site.pos + Vector2(-147, -40)
 game.teleport_player(Vector3(start.x, world.height_at(start.x, start.y) + 0.3, start.y), "QA bridge", false)
 await settle(5)
 game.player.yaw = -PI / 2; game.player.pitch = 0.18; game.player.control_move = Vector2(0, -1)
 var min_y = game.player.global_position.y
 for i in range(800):
  await physics_frame
  game.story.close_reading()
  min_y = minf(min_y, game.player.global_position.y)
  if game.player.global_position.x > site.pos.x - 106: break
 game.player.control_move = Vector2.ZERO
 expect(game.player.global_position.x > site.pos.x - 108, "walk across bridge")
 expect(min_y > 36.0, "stay on bridge above water")
 print("RUNTIME_BRIDGE ", game.player.global_position - Vector3(site.pos.x, 0, site.pos.y), " min_y ", min_y)

 var outside = site.pos + Vector2(410, 0)
 game.teleport_player(Vector3(outside.x, world.height_at(outside.x, outside.y) + 0.3, outside.y), "QA unload", false)
 await settle()
 expect(not is_instance_valid(society.alderhaven_art), "unload infrastructure")
 game.teleport_player(Vector3(site.pos.x, world.height_at(site.pos.x, site.pos.y + 22) + 0.3, site.pos.y + 22), "QA return", false)
 await settle()
 expect(is_instance_valid(society.alderhaven_art), "reload infrastructure")
 expect(society.get_children().filter(func (n): return n.name == "AlderhavenBlueprintInfrastructure").size() == 1, "no duplicate infrastructure")
 if failures.is_empty(): print("ALDERHAVEN_RUNTIME_PASS portals=", count); quit(0)
 else: print("ALDERHAVEN_RUNTIME_FAILED count=", failures.size()); quit(1)
