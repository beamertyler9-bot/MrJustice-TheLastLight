extends Node3D
const B = preload("res://scripts/build.gd")
var player
var bobber: Node3D
var rod: Node3D
var crank: Node3D
var knob: Node3D
var line: MeshInstance3D
var mesh = ImmediateMesh.new()
var age = 0.0
var phase = "cast"
var fish: Node3D
var float_rest: Vector3
var origin: Vector3
var facing = 0.0
var grip = Vector3(0.1, -0.08, -0.42)
var reel_angle = 0.0
var left_grip = Vector3.ZERO
var caught_id = ""
var catch_start = Vector3.ZERO
var start_grip = Vector3.ZERO
var start_support = Vector3.ZERO
var reel_start = Vector3.ZERO
var saved_visible = {}
func setup(actor, at: Node3D):
 player = actor; bobber = at; origin = actor.global_position; float_rest = at.global_position; process_priority = 90
 var direction = float_rest - origin; facing = atan2(-direction.x, -direction.z)
 start_grip = player.visual.torso.to_local(player.visual.hands[1].palm_origin())
 start_support = player.visual.torso.to_local(player.visual.hands[0].palm_origin())
 rod = preload("res://scripts/item_models.gd").build(player.visual.torso, "fishing_rod")
 crank = Node3D.new(); rod.add_child(crank); crank.position = Vector3(0, 0.13, 0.13)
 B.cyl(crank, Vector3.ZERO, 0.015, 0.14, B.mat("#b4bbbc")).rotation.z = PI / 2
 knob = B.ball(crank, Vector3(0.07, 0, 0.025), Vector3(0.045, 0.045, 0.07), B.mat("#4b3930"))
 line = MeshInstance3D.new(); line.mesh = mesh; add_child(line); line.material_override = B.mat("#e9dfc1"); line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for key in ["_weapon_mount", "_grimoire", "_held_mount"]: saved_visible[key] = player.visual.get(key).visible
func caught(id: String):
 if phase not in ["wait", "cast"]: return
 phase = "reel"; age = 0; caught_id = id; reel_start = left_grip
 fish = preload("res://scripts/item_models.gd").build(player.visual.torso, id); fish.scale = Vector3.ONE * 1.35; fish.hide()
func _process(dt: float):
 if not is_instance_valid(player) or not is_instance_valid(bobber): queue_free(); return
 if player.global_position.distance_to(origin) > 1.3 or player.game.mode != "play": queue_free(); return
 age += dt
 var hero = player.visual; hero.rotation.y = facing
 for key in saved_visible: hero.get(key).hide()
 if phase == "cast" and age >= 1.05: phase = "wait"; age = 0
 if phase == "reel" and age >= 1.35: phase = "catch"; age = 0; catch_start = left_grip; fish.show(); line.hide(); bobber.hide()
 var pitch = -0.75; var roll = 0.0
 grip = Vector3(0.1, -0.08, -0.42)
 if phase == "cast":
  if age < 0.38:
   var t = smoothstep(0, 0.38, age); pitch = lerpf(-0.75, 0.6, t); grip = grip.lerp(Vector3(0.2, 0.12, -0.25), t)
  elif age < 0.7:
   var t = smoothstep(0.38, 0.7, age); pitch = lerpf(0.6, -1.18, t); grip = Vector3(0.2, 0.12, -0.25).lerp(Vector3(0.1, 0.02, -0.55), t)
  else:
   var t = smoothstep(0.7, 1.05, age); pitch = lerpf(-1.18, -0.75, t); grip = Vector3(0.1, 0.02, -0.55).lerp(grip, t)
 elif phase == "wait": pitch += sin(age * 1.6) * 0.025
 elif phase == "reel": pitch = -0.63 + sin(age * 8) * 0.035; reel_angle -= dt * 9
 elif phase == "catch":
  var t = smoothstep(0, 0.5, age); pitch = lerpf(-0.63, -0.45, t); roll = 0.75 * t; grip = grip.lerp(Vector3(0.43, -0.25, -0.25), t)
  if age >= 2.5: queue_free(); return
 if phase == "cast": grip = start_grip.lerp(grip, smoothstep(0, 0.22, age))
 var frame = Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, pitch)
 rod.basis = frame.scaled(Vector3(1, 1.8, 1)); rod.position = grip - rod.basis * Vector3(0, 0.14, 0)
 crank.rotation.z = reel_angle
 _hand(hero, 1, grip, hero._grasp_frame(frame.y, Vector3.BACK), dt)
 if phase == "catch":
  left_grip = catch_start.lerp(Vector3(-0.65, 0.9, -0.3), smoothstep(0, 0.5, age))
  var palm = Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT)
  _hand(hero, 0, left_grip, palm, dt)
  fish.rotation = Vector3(0, 2.5, sin(age * 8) * 0.035); fish.position = left_grip - fish.basis * Vector3(-0.22, 0.12, 0)
 else:
  left_grip = hero.torso.to_local(knob.global_position) if phase == "reel" else rod.position + rod.basis * Vector3(0, 0.01, 0)
  if phase == "cast": left_grip = start_support.lerp(left_grip, smoothstep(0, 0.22, age))
  if phase == "reel": left_grip = reel_start.lerp(left_grip, smoothstep(0, 0.22, age))
  _hand(hero, 0, left_grip, hero._grasp_frame(frame.y, Vector3.BACK), dt)
 var skin = hero.get_node_or_null("RigidSkinBatches")
 if skin != null: skin._sync()
 var tip = rod.to_global(Vector3(0, 1.4, 0)); var end = float_rest
 if phase == "cast":
  var release = smoothstep(0.48, 0.94, age); end = tip.lerp(float_rest, release) + Vector3.UP * sin(release * PI) * 1.3
 elif phase == "wait": end.y += sin(age * 3) * 0.025
 elif phase == "reel": end = float_rest.lerp(hero.hands[0].global_position, smoothstep(0, 1.35, age))
 bobber.global_position = end
 mesh.clear_surfaces(); mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
 for i in 17:
  var t = i / 16.0; var p = tip.lerp(end, t); p.y -= sin(t * PI) * (0.07 if phase == "reel" else 0.24); p.x += sin(t * PI) * sin(age * 3 + t * 5) * 0.015
  mesh.surface_add_vertex(to_local(p))
 mesh.surface_end()
func _hand(hero, index: int, point: Vector3, palm: Basis, dt: float):
 var target = point - palm * Vector3(0, 0, 0.09)
 hero._solve_arm(index, target, 1.0, Vector3(-0.65 if index == 0 else 0.65, -0.45, 0.15))
 hero._orient_palm(index, palm, 1.0)
 hero.hands[index].set_pose(dt, 1.0, 1.35, 0.9, 0, 60)
func _exit_tree():
 if is_instance_valid(bobber): bobber.global_position = float_rest; bobber.show()
 if is_instance_valid(player):
  for key in saved_visible: player.visual.get(key).visible = saved_visible[key]
  player.visual.set_weapon(player.state.equipment)
 if is_instance_valid(rod): rod.queue_free()
 if is_instance_valid(fish): fish.queue_free()
