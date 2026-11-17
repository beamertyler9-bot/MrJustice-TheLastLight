extends SceneTree
var game
var frame_index = 0
var output = OS.get_environment("MRJUSTICE_CAPTURE_OUTPUT")
func _initialize(): call_deferred("run")
func record_frame():
 for i in range(2):
  game.story.close_reading(); await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/frame_%04d.png" % frame_index); frame_index += 1
func run():
 root.size = Vector2i(960, 540); DirAccess.make_dir_recursive_absolute(output)
 game = load("res://scenes/main.tscn").instantiate(); game.defer_world_until_journey = true; root.add_child(game)
 await process_frame
 print("CAPTURE_START"); await game.start_journey(false); game.set_mode("play"); game.story.close_reading()
 var h: float = game.world.height_at(0, 0)
 var cam = Camera3D.new(); game.add_child(cam); cam.far = 3500; cam.fov = 44; cam.current = true
 var hover = Vector3(0, h + 140, 0); game.teleport_player(hover, "Brindlewick aerial", false, true)
 game.player.enable_light_flight(true); game.player.light_flight.active = true; game.player.light_flight.held = true; game.player.velocity = Vector3(0, 0.1, 0)
 game.world.stream_at(hover, true)
 for i in range(36):
  var t = float(i) / 35; cam.global_position = Vector3(112 - t * 12, h + 130, 138 - t * 12); cam.look_at(Vector3(-8, h, 0)); await record_frame()
 print("CAPTURE_OVERVIEW")
 game.player.stop_light_flight(); game.teleport_player(Vector3(0, h + 0.3, 24), "Brindlewick village green", false)
 cam.current = false; game.player.camera.current = true; game.player.yaw = 0; game.player.pitch = 0.1; game.player.cam_pivot_ready = false; game.player.control_move = Vector2(0, -0.7)
 for i in range(36): await record_frame()
 game.player.control_move = Vector2.ZERO; print("CAPTURE_WALK")
 game.teleport_player(Vector3(22, game.world.height_at(22, 22) + 0.3, 22), "Bramm's blacksmith", false)
 cam.current = true
 for i in range(36):
  var t = float(i) / 35; cam.global_position = Vector3(60 - t * 4, h + 4, 42); cam.look_at(Vector3(58, h + 1.3, 15)); await record_frame()
 print("CAPTURE_FORGE")
 var ward = game.world.society.live.get("brindlewick:0"); var shop = ward.get_node("Building_4")
 game.teleport_player(shop.get_node("BuildingEntry").global_position, "Provisions", false, true); game.interact_with(shop.get_node("BuildingEntry"))
 cam.current = false; game.player.camera.current = true; game.player.yaw = -PI / 2; game.player.pitch = 0.1; game.player.cam_pivot_ready = false
 for i in range(36): await record_frame()
 print("CAPTURE_COMPLETE ", frame_index); quit()
