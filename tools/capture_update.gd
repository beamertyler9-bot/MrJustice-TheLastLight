extends SceneTree
var game
var frame_index := 0
var output := OS.get_environment("MRJUSTICE_CAPTURE_OUTPUT")
func _initialize(): call_deferred("run")
func record_frame():
 for i in range(2):
  if game.story != null: game.story.close_reading()
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/frame_%04d.png" % frame_index)
 frame_index += 1
func run():
 if output.is_empty(): output = ProjectSettings.globalize_path("user://alderhaven-preview")
 root.size = Vector2i(960, 540); DirAccess.make_dir_recursive_absolute(output)
 game = load("res://scenes/main.tscn").instantiate(); game.defer_world_until_journey = true; root.add_child(game)
 await process_frame
 print("CAPTURE_START")
 await game.start_journey(false); game.set_mode("play"); game.story.close_reading()
 var site: Dictionary
 for entry in game.world.atlas.sites():
  if entry.id == "alderhaven": site = entry
 var p: Vector2 = site.pos + Vector2(0, 22)
 var landing = Vector3(p.x, game.world.height_at(p.x, p.y) + 0.22, p.y)
 assert(game.teleport_player(landing, "Alderhaven", false))
 var cam = Camera3D.new(); game.add_child(cam); cam.far = 3500; cam.fov = 42; cam.current = true

 var hover = Vector3(site.pos.x, landing.y + 140, site.pos.y + 22)
 game.teleport_player(hover, "Alderhaven aerial view", false, true)
 game.player.enable_light_flight(true); game.player.light_flight.active = true; game.player.light_flight.held = true
 game.player.velocity = Vector3(0, 0.1, 0)
 game.world.stream_at(hover, true)
 for i in range(36):
  var t = float(i) / 35
  cam.global_position = Vector3(site.pos.x + 155 - t * 20, game.world.height_at(site.pos.x, site.pos.y) + 160 - t * 15, site.pos.y + 190 - t * 15)
  cam.look_at(Vector3(site.pos.x - 5, landing.y + 2, site.pos.y - 3))
  await record_frame()
 print("CAPTURE_OVERVIEW")
 game.player.stop_light_flight()
 p = site.pos + Vector2(0, 36); landing = Vector3(p.x, game.world.height_at(p.x, p.y) + 0.22, p.y)
 assert(game.teleport_player(landing, "Graham Market", false))
 cam.current = false; game.player.camera.current = true; game.player.yaw = 0.0; game.player.pitch = 0.1; game.player.cam_pivot_ready = false
 game.player.control_move = Vector2(0, -0.8)
 var before: Vector3 = game.player.global_position
 for i in range(36): await record_frame()
 game.player.control_move = Vector2.ZERO
 print("CAPTURE_WALK_METRES ", before.distance_to(game.player.global_position))
 var ward = game.world.society.live.get("alderhaven:3")
 var shop = ward.get_node("Building_0")
 game.teleport_player(shop.get_node("BuildingEntry").global_position, "Provisions", false, true)
 game.interact_with(shop.get_node("BuildingEntry"))
 game.player.yaw = PI / 2; game.player.pitch = 0.08; game.player.cam_pivot_ready = false
 for i in range(36): await record_frame()
 print("CAPTURE_SHOP")
 p = site.pos + Vector2(-58, 45); landing = Vector3(p.x, game.world.height_at(p.x, p.y) + 0.22, p.y)
 assert(game.teleport_player(landing, "Cola Quays", false))
 cam.current = true
 for i in range(36):
  var t = float(i) / 35
  cam.global_position = Vector3(site.pos.x - 99 + t * 9, landing.y + 10, site.pos.y + 35 + t * 5)
  cam.look_at(Vector3(site.pos.x - 72, landing.y + 1, site.pos.y + 12))
  await record_frame()
 print("CAPTURE_COMPLETE ", frame_index)
 quit()
